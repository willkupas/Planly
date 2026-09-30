import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:planly/core/firebase/firebase_error_mapper.dart';
import 'package:planly/core/sync/sync_status.dart';
import 'package:planly/core/sync/write_failure_center.dart';
import 'package:planly/features/activity/data/activity_entry.dart';
import 'package:planly/features/lists/domain/list_models.dart';
import 'package:planly/features/lists/domain/list_repository.dart';

/// Quanto esperar pela confirmação do servidor antes de tratar a escrita como "salva neste
/// dispositivo". Offline, `commit()` só completa quando reconectar; a UI não pode travar.
const _ackGrace = Duration(seconds: 2);

/// Commit otimista: online, devolve erros reais (ex.: permission-denied) ao chamador; sem
/// resposta no prazo (offline), segue sem bloquear. Um erro que chegue depois do prazo não
/// chega mais ao chamador: o listener reverte o dado local (`SyncMeta` sem pendências) e o erro
/// vai para [onLateError] (canal central de escritas rejeitadas, T-021).
Future<void> commitOptimistic(Future<void> commit, {void Function(Object error)? onLateError}) async {
  try {
    await commit.timeout(_ackGrace);
  } on TimeoutException {
    unawaited(commit.catchError((Object e) => onLateError?.call(e)));
  } catch (e) {
    throw mapFirebaseError(e);
  }
}

/// Chamado quando o servidor recusa uma escrita que já tinha sido aplicada localmente.
typedef WriteRejectedCallback = void Function(WriteKind kind, String? title, Object error);

class FirestoreListRepository implements ListRepository {
  FirestoreListRepository({required FirebaseFirestore firestore, this.onRejected}) : _db = firestore;

  final FirebaseFirestore _db;
  final WriteRejectedCallback? onRejected;

  Future<void> _commit(Future<void> commit, WriteKind kind, String? title) =>
      commitOptimistic(commit, onLateError: (e) => onRejected?.call(kind, title, e));

  DocumentReference<Map<String, dynamic>> _household(String f, String h) =>
      _db.collection('families').doc(f).collection('households').doc(h);

  CollectionReference<Map<String, dynamic>> _lists(String f, String h) =>
      _household(f, h).collection('lists');

  CollectionReference<Map<String, dynamic>> _items(String f, String h, String l) =>
      _lists(f, h).doc(l).collection('items');

  CollectionReference<Map<String, dynamic>> _activity(String f, String h) =>
      _household(f, h).collection('activity');

  static SyncMeta _meta(SnapshotMetadata m) =>
      SyncMeta(hasPendingWrites: m.hasPendingWrites, isFromCache: m.isFromCache);

  static DateTime? _date(Object? v) => v is Timestamp ? v.toDate() : null;

  @override
  Stream<ListsSnapshot> watchLists(String familyId, String householdId) {
    // Igualdade simples em `deletedAt` usa só o índice automático; ordenação por nome no
    // cliente (no máximo 100 docs, limite exigido pelas Rules).
    final query = _lists(familyId, householdId).where('deletedAt', isNull: true).limit(listsQueryLimit);
    return query.snapshots(includeMetadataChanges: true).map((snap) {
      final items = [
        for (final d in snap.docs)
          TaskList(
            id: d.id,
            name: (d.data()['name'] as String?) ?? '',
            type: ListType.parse(d.data()['type']),
            createdBy: (d.data()['createdBy'] as String?) ?? '',
            hasPendingWrites: d.metadata.hasPendingWrites,
          ),
      ]..sort((a, b) {
          final c = a.name.toLowerCase().compareTo(b.name.toLowerCase());
          return c != 0 ? c : a.id.compareTo(b.id);
        });
      return ListsSnapshot(items, _meta(snap.metadata));
    }).handleError((Object e) => throw mapFirebaseError(e));
  }

  @override
  Stream<ItemsSnapshot> watchItems(String familyId, String householdId, String listId) {
    // Índice existente: items (deletedAt, completed, order).
    final query = _items(familyId, householdId, listId)
        .where('deletedAt', isNull: true)
        .orderBy('completed')
        .orderBy('order')
        .limit(itemsQueryLimit);
    return query.snapshots(includeMetadataChanges: true).map((snap) {
      final items = <ListItem>[
        for (final d in snap.docs)
          ListItem(
            id: d.id,
            name: (d.data()['name'] as String?) ?? '',
            completed: d.data()['completed'] == true,
            order: ((d.data()['order'] as num?) ?? 0).toDouble(),
            createdBy: (d.data()['createdBy'] as String?) ?? '',
            completedBy: d.data()['completedBy'] as String?,
            completedAt: _date(d.data()['completedAt']),
            hasPendingWrites: d.metadata.hasPendingWrites,
          ),
      ];
      // Garante pendentes antes de concluídos e desempate estável por id.
      items.sort((a, b) {
        if (a.completed != b.completed) return a.completed ? 1 : -1;
        final c = a.order.compareTo(b.order);
        return c != 0 ? c : a.id.compareTo(b.id);
      });
      return ItemsSnapshot(items, _meta(snap.metadata));
    }).handleError((Object e) => throw mapFirebaseError(e));
  }

  @override
  Future<int?> pendingCount(String familyId, String householdId, String listId) async {
    try {
      final agg = await _items(familyId, householdId, listId)
          .where('deletedAt', isNull: true)
          .where('completed', isEqualTo: false)
          .limit(itemsQueryLimit)
          .count()
          .get(source: AggregateSource.server)
          .timeout(const Duration(seconds: 5));
      return agg.count;
    } catch (_) {
      return null;
    }
  }

  @override
  Future<String> createList({
    required String familyId,
    required String householdId,
    required String name,
    required ListType type,
    required String actorId,
    required String actorName,
  }) async {
    final ref = _lists(familyId, householdId).doc();
    final title = name.trim();
    final batch = _db.batch()
      ..set(ref, {
        'name': title,
        'type': type.wire,
        'createdBy': actorId,
        'deletedAt': null,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'schemaVersion': 1,
      })
      ..set(
        _activity(familyId, householdId).doc(),
        activityEntry(
          type: ActivityType.listCreated,
          actorId: actorId,
          actorName: actorName,
          targetId: ref.id,
          targetTitle: title,
        ),
      );
    await _commit(batch.commit(), WriteKind.listCreate, title);
    return ref.id;
  }

  @override
  Future<void> renameList({
    required String familyId,
    required String householdId,
    required String listId,
    required String name,
  }) {
    return _commit(
      _lists(familyId, householdId).doc(listId).update({
        'name': name.trim(),
        'updatedAt': FieldValue.serverTimestamp(),
      }),
      WriteKind.listRename,
      name.trim(),
    );
  }

  @override
  Future<void> deleteList({
    required String familyId,
    required String householdId,
    required String listId,
    required String listName,
    required String actorId,
    required String actorName,
  }) {
    final batch = _db.batch()
      ..update(_lists(familyId, householdId).doc(listId), {
        'deletedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      })
      ..set(
        _activity(familyId, householdId).doc(),
        activityEntry(
          type: ActivityType.listDeleted,
          actorId: actorId,
          actorName: actorName,
          targetId: listId,
          targetTitle: listName,
        ),
      );
    return _commit(batch.commit(), WriteKind.listDelete, listName);
  }

  @override
  Future<String> addItem({
    required String familyId,
    required String householdId,
    required String listId,
    required String name,
    required double order,
    required String actorId,
    required String actorName,
  }) async {
    final ref = _items(familyId, householdId, listId).doc();
    final title = name.trim();
    final batch = _db.batch()
      ..set(ref, {
        'name': title,
        'completed': false,
        'completedBy': null,
        'completedAt': null,
        'createdBy': actorId,
        'order': order,
        'deletedAt': null,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'schemaVersion': 1,
      })
      ..set(
        _activity(familyId, householdId).doc(),
        activityEntry(
          type: ActivityType.itemAdded,
          actorId: actorId,
          actorName: actorName,
          targetId: ref.id,
          targetTitle: title,
        ),
      );
    await _commit(batch.commit(), WriteKind.itemAdd, title);
    return ref.id;
  }

  @override
  Future<void> setItemCompleted({
    required String familyId,
    required String householdId,
    required String listId,
    required String itemId,
    required String itemName,
    required bool completed,
    required String actorId,
    required String actorName,
  }) {
    final ref = _items(familyId, householdId, listId).doc(itemId);
    final batch = _db.batch()
      ..update(ref, {
        'completed': completed,
        'completedBy': completed ? actorId : null,
        'completedAt': completed ? FieldValue.serverTimestamp() : null,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    // Desmarcar não gera atividade: não existe tipo de cliente para isso (Rules).
    if (completed) {
      batch.set(
        _activity(familyId, householdId).doc(),
        activityEntry(
          type: ActivityType.itemCompleted,
          actorId: actorId,
          actorName: actorName,
          targetId: itemId,
          targetTitle: itemName,
        ),
      );
    }
    return _commit(batch.commit(), WriteKind.itemComplete, itemName);
  }

  @override
  Future<void> renameItem({
    required String familyId,
    required String householdId,
    required String listId,
    required String itemId,
    required String name,
  }) {
    return _commit(
      _items(familyId, householdId, listId).doc(itemId).update({
        'name': name.trim(),
        'updatedAt': FieldValue.serverTimestamp(),
      }),
      WriteKind.itemRename,
      name.trim(),
    );
  }

  @override
  Future<void> reorderItems({
    required String familyId,
    required String householdId,
    required String listId,
    required Map<String, double> orders,
  }) {
    final batch = _db.batch();
    orders.forEach((id, order) {
      batch.update(_items(familyId, householdId, listId).doc(id), {
        'order': order,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
    return _commit(batch.commit(), WriteKind.itemReorder, null);
  }

  @override
  Future<void> deleteItem({
    required String familyId,
    required String householdId,
    required String listId,
    required String itemId,
    required String itemName,
    required String actorId,
    required String actorName,
  }) {
    final batch = _db.batch()
      ..update(_items(familyId, householdId, listId).doc(itemId), {
        'deletedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      })
      ..set(
        _activity(familyId, householdId).doc(),
        activityEntry(
          type: ActivityType.itemDeleted,
          actorId: actorId,
          actorName: actorName,
          targetId: itemId,
          targetTitle: itemName,
        ),
      );
    return _commit(batch.commit(), WriteKind.itemDelete, itemName);
  }
}

import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:planly/core/firebase/firebase_error_mapper.dart';
import 'package:planly/core/sync/sync_status.dart';
import 'package:planly/features/activity/data/activity_entry.dart';
import 'package:planly/features/lists/domain/list_models.dart';
import 'package:planly/features/lists/domain/list_repository.dart';

/// Quanto esperar pela confirmação do servidor antes de tratar a escrita como "salva neste
/// dispositivo". Offline, `commit()` só completa quando reconectar; a UI não pode travar.
const _ackGrace = Duration(seconds: 2);

/// Commit otimista: online, devolve erros reais (ex.: permission-denied) ao chamador; sem
/// resposta no prazo (offline), segue sem bloquear. Um erro que chegue depois do prazo é
/// engolido aqui: o listener reverte o dado local e o `SyncMeta` deixa de ter pendências.
Future<void> commitOptimistic(Future<void> commit) async {
  try {
    await commit.timeout(_ackGrace);
  } on TimeoutException {
    unawaited(commit.catchError((Object _) {}));
  } catch (e) {
    throw mapFirebaseError(e);
  }
}

class FirestoreListRepository implements ListRepository {
  FirestoreListRepository({required FirebaseFirestore firestore}) : _db = firestore;

  final FirebaseFirestore _db;

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
    await commitOptimistic(batch.commit());
    return ref.id;
  }

  @override
  Future<void> renameList({
    required String familyId,
    required String householdId,
    required String listId,
    required String name,
  }) {
    return commitOptimistic(_lists(familyId, householdId).doc(listId).update({
      'name': name.trim(),
      'updatedAt': FieldValue.serverTimestamp(),
    }));
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
    return commitOptimistic(batch.commit());
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
    await commitOptimistic(batch.commit());
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
    return commitOptimistic(batch.commit());
  }

  @override
  Future<void> renameItem({
    required String familyId,
    required String householdId,
    required String listId,
    required String itemId,
    required String name,
  }) {
    return commitOptimistic(_items(familyId, householdId, listId).doc(itemId).update({
      'name': name.trim(),
      'updatedAt': FieldValue.serverTimestamp(),
    }));
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
    return commitOptimistic(batch.commit());
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
    return commitOptimistic(batch.commit());
  }
}

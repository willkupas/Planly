import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:planly/core/error/app_failure.dart';
import 'package:planly/core/firebase/callable_invoker.dart';
import 'package:planly/core/firebase/firebase_error_mapper.dart';
import 'package:planly/core/sync/sync_status.dart';
import 'package:planly/features/household/domain/household_models.dart';
import 'package:planly/features/household/domain/household_repository.dart';

/// Uma família tem poucas casas (plano Família: 3); 50 cobre casas excluídas recentes
/// (soft delete de 30 dias) que o owner ainda enxerga na query.
const _householdsLimit = 50;

class FirestoreHouseholdRepository implements HouseholdRepository {
  FirestoreHouseholdRepository({required FirebaseFirestore firestore, required CallableInvoker callable})
      : _db = firestore,
        _call = callable;

  final FirebaseFirestore _db;
  final CallableInvoker _call;

  CollectionReference<Map<String, dynamic>> _col(String familyId) =>
      _db.collection('families').doc(familyId).collection('households');

  @override
  Stream<HouseholdsSnapshot> watchHouseholds(String familyId, {required String uid, required bool isOwner}) {
    // Sem `where deletedAt == null` no servidor: combinar com array-contains exigiria índice
    // composto; o filtro é feito aqui (casa excluída tem accessUids vazio, ver data-model §8 #7).
    final Query<Map<String, dynamic>> query = isOwner
        ? _col(familyId).limit(_householdsLimit)
        : _col(familyId).where('accessUids', arrayContains: uid).limit(_householdsLimit);
    return query.snapshots(includeMetadataChanges: true).map((snap) {
      final items = <Household>[];
      for (final d in snap.docs) {
        final data = d.data();
        if (data['deletedAt'] != null) continue;
        final rawAccess = data['access'];
        final access = <String, HouseholdRole>{};
        if (rawAccess is Map) {
          rawAccess.forEach((k, v) {
            final role = HouseholdRole.parse(v);
            if (k is String && role != null) access[k] = role;
          });
        }
        items.add(Household(id: d.id, name: (data['name'] as String?) ?? '', access: access));
      }
      items.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      return HouseholdsSnapshot(
        items,
        SyncMeta(
          hasPendingWrites: snap.metadata.hasPendingWrites,
          isFromCache: snap.metadata.isFromCache,
        ),
      );
    }).handleError((Object e) => throw mapFirebaseError(e));
  }

  @override
  Future<void> rename({required String familyId, required String householdId, required String name}) async {
    try {
      await _col(familyId).doc(householdId).update({
        'name': name.trim(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw mapFirebaseError(e);
    }
  }

  @override
  Future<String> createHousehold({required String familyId, required String name}) async {
    final out = await _call('createHousehold', {'familyId': familyId, 'name': name.trim()});
    final id = out['householdId'];
    if (id is! String || id.isEmpty) throw const UnknownFailure();
    return id;
  }

  @override
  Future<void> deleteHousehold({required String familyId, required String householdId}) async {
    await _call('deleteHousehold', {'familyId': familyId, 'householdId': householdId});
  }

  @override
  Future<void> setHouseholdAccess({
    required String familyId,
    required String householdId,
    required String targetUid,
    required HouseholdRole? role,
  }) async {
    await _call('setHouseholdAccess', {
      'familyId': familyId,
      'householdId': householdId,
      'targetUid': targetUid,
      'role': role?.name,
    });
  }
}

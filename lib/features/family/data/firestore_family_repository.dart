import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:planly/core/error/app_failure.dart';
import 'package:planly/core/firebase/callable_invoker.dart';
import 'package:planly/core/firebase/firebase_error_mapper.dart';
import 'package:planly/features/family/domain/family_models.dart';
import 'package:planly/features/family/domain/family_repository.dart';

/// Limites defensivos das queries (as Rules de members/memberships não exigem limit, mas o
/// custo do app sim; uma família tem no máximo 8 membros ativos).
const _membershipsLimit = 50;
const _membersLimit = 50;

class FirestoreFamilyRepository implements FamilyRepository {
  FirestoreFamilyRepository({required FirebaseFirestore firestore, required CallableInvoker callable})
      : _db = firestore,
        _call = callable;

  final FirebaseFirestore _db;
  final CallableInvoker _call;

  Stream<T> _guard<T>(Stream<T> source) => source.handleError((Object e) => throw mapFirebaseError(e));

  @override
  Stream<List<FamilyMembership>> watchMemberships(String uid) {
    return _guard(
      _db.collection('users').doc(uid).collection('memberships').limit(_membershipsLimit).snapshots().map(
            (snap) => [
              for (final d in snap.docs)
                FamilyMembership(
                  familyId: d.id,
                  familyName: (d.data()['familyName'] as String?) ?? '',
                  role: FamilyRole.parse(d.data()['role']),
                  familyStatus: FamilyStatus.parse(d.data()['familyStatus']),
                  plan: PlanId.parse(d.data()['plan']),
                ),
            ],
          ),
    );
  }

  @override
  Stream<Family?> watchFamily(String familyId) {
    return _guard(_db.collection('families').doc(familyId).snapshots().map((d) {
      final data = d.data();
      if (!d.exists || data == null) return null;
      final pending = data['pendingTransfer'];
      return Family(
        id: d.id,
        name: (data['name'] as String?) ?? '',
        ownerId: (data['ownerId'] as String?) ?? '',
        status: FamilyStatus.parse(data['status']),
        plan: PlanId.parse(data['plan']),
        memberCount: (data['memberCount'] as num?)?.toInt() ?? 0,
        householdCount: (data['householdCount'] as num?)?.toInt() ?? 0,
        deleteAfter: (data['deleteAfter'] as Timestamp?)?.toDate(),
        pendingTransferToUid: pending is Map ? pending['toUid'] as String? : null,
      );
    }));
  }

  @override
  Stream<Entitlement?> watchEntitlement(String familyId) {
    return _guard(
      _db.collection('families').doc(familyId).collection('billing').doc('entitlement').snapshots().map((d) {
        final data = d.data();
        if (!d.exists || data == null) return null;
        final features = data['features'];
        return Entitlement(
          plan: PlanId.parse(data['plan']),
          maxMembers: (data['maxMembers'] as num?)?.toInt() ?? 1,
          maxHouseholds: (data['maxHouseholds'] as num?)?.toInt(),
          invitesEnabled: features is Map && features['invites'] == true,
          fullHistory: features is Map && features['fullHistory'] is bool
              ? features['fullHistory'] as bool
              : null,
        );
      }),
    );
  }

  @override
  Stream<List<FamilyMember>> watchMembers(String familyId) {
    return _guard(
      _db
          .collection('families')
          .doc(familyId)
          .collection('members')
          .where('status', isEqualTo: 'active')
          .limit(_membersLimit)
          .snapshots()
          .map(
            (snap) => [
              for (final d in snap.docs)
                FamilyMember(
                  uid: d.id,
                  role: FamilyRole.parse(d.data()['role']),
                  displayName: d.data()['displayName'] as String?,
                  photoUrl: d.data()['photoUrl'] as String?,
                ),
            ],
          ),
    );
  }

  @override
  Future<BootstrapResult> bootstrapUser({String? displayName, String? locale, String? timezone}) async {
    final out = await _call('bootstrapUser', {
      if (displayName != null && displayName.trim().isNotEmpty) 'displayName': displayName.trim(),
      'locale': ?locale,
      'timezone': ?timezone,
    });
    final familyId = out['familyId'];
    if (familyId is! String || familyId.isEmpty) throw const UnknownFailure();
    final householdId = out['householdId'];
    return BootstrapResult(familyId: familyId, householdId: householdId is String ? householdId : null);
  }

  @override
  Future<void> removeMember({required String familyId, required String targetUid}) async {
    await _call('removeMember', {'familyId': familyId, 'targetUid': targetUid});
  }

  @override
  Future<void> leaveFamily(String familyId) async {
    await _call('leaveFamily', {'familyId': familyId});
  }
}

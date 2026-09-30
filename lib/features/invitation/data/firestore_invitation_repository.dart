import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:planly/core/error/app_failure.dart';
import 'package:planly/core/firebase/callable_invoker.dart';
import 'package:planly/core/firebase/firebase_error_mapper.dart';
import 'package:planly/features/household/domain/household_models.dart';
import 'package:planly/features/invitation/domain/invitation_models.dart';
import 'package:planly/features/invitation/domain/invitation_repository.dart';

/// Teto de convites lidos do owner (o servidor limita pendentes a 100 e o TTL apaga os
/// antigos 7 dias após expirar).
const _invitationsLimit = 50;

class FirestoreInvitationRepository implements InvitationRepository {
  FirestoreInvitationRepository({required FirebaseFirestore firestore, required CallableInvoker callable})
      : _db = firestore,
        _call = callable;

  final FirebaseFirestore _db;
  final CallableInvoker _call;

  @override
  Stream<List<Invitation>> watchCreatedBy(String uid) {
    // As Rules exigem `where createdBy == uid`; sem orderBy (evita índice composto).
    return _db
        .collection('invitations')
        .where('createdBy', isEqualTo: uid)
        .limit(_invitationsLimit)
        .snapshots()
        .map((snap) {
      final out = <Invitation>[];
      for (final d in snap.docs) {
        final data = d.data();
        final expires = data['expiresAt'];
        final familyId = data['familyId'];
        if (expires is! Timestamp || familyId is! String) continue;
        final grants = <InviteGrant>[];
        final raw = data['grants'];
        if (raw is List) {
          for (final g in raw) {
            if (g is! Map) continue;
            final role = HouseholdRole.parse(g['role']);
            final hid = g['householdId'];
            if (role != null && hid is String) grants.add(InviteGrant(householdId: hid, role: role));
          }
        }
        final created = data['createdAt'];
        out.add(Invitation(
          code: d.id,
          familyId: familyId,
          grants: grants,
          status: InvitationStatus.parse(data['status']),
          expiresAt: expires.toDate(),
          createdAt: created is Timestamp ? created.toDate() : null,
        ));
      }
      return out;
    }).handleError((Object e) => throw mapFirebaseError(e));
  }

  @override
  Future<CreatedInvitation> createInvitation({
    required String familyId,
    required List<InviteGrant> grants,
  }) async {
    final out = await _call('createInvitation', {
      'familyId': familyId,
      'grants': [
        for (final g in grants) {'householdId': g.householdId, 'role': g.role.name},
      ],
    });
    final code = out['code'];
    final link = out['link'];
    final expires = out['expiresAt'] is String ? DateTime.tryParse(out['expiresAt'] as String) : null;
    if (code is! String || code.isEmpty || expires == null) throw const UnknownFailure();
    return CreatedInvitation(code: code, link: link is String ? link : '', expiresAt: expires);
  }

  @override
  Future<void> revokeInvitation(String code) async {
    await _call('revokeInvitation', {'code': code});
  }

  @override
  Future<AcceptedInvitation> acceptInvitation(String code) async {
    final out = await _call('acceptInvitation', {'code': code});
    final familyId = out['familyId'];
    if (familyId is! String || familyId.isEmpty) throw const UnknownFailure();
    final ids = out['householdIds'];
    return AcceptedInvitation(
      familyId: familyId,
      householdIds: ids is List ? [for (final i in ids) if (i is String) i] : const [],
    );
  }
}

import 'package:planly/core/error/app_failure.dart';
import 'package:planly/features/invitation/domain/invitation_models.dart';
import 'package:planly/features/invitation/domain/invitation_repository.dart';

import 'fake_backend.dart';

/// Repositório de convites em memória. Chamadas em [calls] (com o código como recebido).
class FakeInvitations implements InvitationRepository {
  final invitations = Live<List<Invitation>>();
  final calls = <String>[];
  final createdGrants = <List<InviteGrant>>[];

  AppFailure? nextFailure;

  CreatedInvitation createResult = CreatedInvitation(
    code: 'ABCDEFGHJK',
    link: 'https://planly.app/join/ABCDEFGHJK',
    expiresAt: DateTime.now().add(const Duration(hours: 24)),
  );

  AcceptedInvitation acceptResult = const AcceptedInvitation(familyId: 'f2', householdIds: ['h2']);

  void _maybeFail() {
    final f = nextFailure;
    if (f != null) {
      nextFailure = null;
      throw f;
    }
  }

  @override
  Stream<List<Invitation>> watchCreatedBy(String uid) {
    calls.add('watch:$uid');
    return invitations.stream;
  }

  @override
  Future<CreatedInvitation> createInvitation({
    required String familyId,
    required List<InviteGrant> grants,
  }) async {
    calls.add('create:$familyId');
    createdGrants.add(grants);
    _maybeFail();
    return createResult;
  }

  @override
  Future<void> revokeInvitation(String code) async {
    calls.add('revoke:$code');
    _maybeFail();
  }

  @override
  Future<AcceptedInvitation> acceptInvitation(String code) async {
    calls.add('accept:$code');
    _maybeFail();
    return acceptResult;
  }
}

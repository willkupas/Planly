import 'package:planly/features/invitation/domain/invitation_models.dart';

/// Convites (callables `createInvitation`/`revokeInvitation`/`acceptInvitation` e a lista do
/// owner). Falhas são lançadas como `AppFailure`.
abstract class InvitationRepository {
  /// Convites criados por [uid] (Rules: só `list` com `where createdBy == uid`; `get` negado).
  /// Com limite; a ordenação e o filtro por família são da camada application.
  Stream<List<Invitation>> watchCreatedBy(String uid);

  Future<CreatedInvitation> createInvitation({
    required String familyId,
    required List<InviteGrant> grants,
  });

  Future<void> revokeInvitation(String code);

  Future<AcceptedInvitation> acceptInvitation(String code);
}

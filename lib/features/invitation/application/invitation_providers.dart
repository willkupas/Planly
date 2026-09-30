import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:planly/app/session/session_phase.dart';
import 'package:planly/core/connectivity/online_only.dart';
import 'package:planly/core/error/app_failure.dart';
import 'package:planly/core/firebase/firebase_providers.dart';
import 'package:planly/features/auth/application/auth_providers.dart';
import 'package:planly/features/family/application/active_context.dart';
import 'package:planly/features/family/application/bootstrap_controller.dart';
import 'package:planly/features/family/application/family_providers.dart';
import 'package:planly/features/invitation/data/firestore_invitation_repository.dart';
import 'package:planly/features/invitation/domain/invitation_models.dart';
import 'package:planly/features/invitation/domain/invitation_repository.dart';

final invitationRepositoryProvider = Provider<InvitationRepository>((ref) {
  return FirestoreInvitationRepository(
    firestore: ref.watch(firestoreProvider),
    callable: ref.watch(callableInvokerProvider),
  );
});

/// Convites que o usuário criou para a família ativa, do mais novo para o mais antigo. Só
/// vive enquanto a tela de convites está aberta (autoDispose). As Rules só deixam listar
/// `createdBy == uid`; o filtro por família é aqui.
final familyInvitationsProvider = StreamProvider.autoDispose<List<Invitation>>((ref) {
  final uid = ref.watch(currentUidProvider);
  final familyId = ref.watch(activeFamilyIdProvider);
  if (uid == null || familyId == null) return const Stream.empty();
  return ref.watch(invitationRepositoryProvider).watchCreatedBy(uid).map((all) {
    final list = all.where((i) => i.familyId == familyId).toList();
    list.sort((a, b) => (b.createdAt ?? b.expiresAt).compareTo(a.createdAt ?? a.expiresAt));
    return list;
  });
});

/// Ações de convite (callables só-online). Lançam `AppFailure`; a UI mostra o texto i18n.
/// Nunca loga nem guarda o código.
class InvitationActions {
  InvitationActions(this._ref);

  final Ref _ref;

  InvitationRepository get _repo => _ref.read(invitationRepositoryProvider);

  Future<CreatedInvitation> create(String familyId, List<InviteGrant> grants) async {
    await ensureOnline(_ref);
    return _repo.createInvitation(familyId: familyId, grants: grants);
  }

  Future<void> revoke(String code) async {
    await ensureOnline(_ref);
    await _repo.revokeInvitation(normalizeInviteCode(code));
  }

  /// Aceita o convite e torna a família recebida (e a primeira casa concedida) o contexto
  /// ativo. Se o bootstrap da Free ainda não rodou (`/join` fica liberado antes dele), roda
  /// primeiro — o servidor exige `BOOTSTRAP_REQUIRED` antes de aceitar.
  Future<AcceptedInvitation> accept(String rawCode) async {
    await ensureOnline(_ref);
    if (_ref.read(sessionPhaseProvider) == SessionPhase.needsBootstrap) {
      final controller = _ref.read(bootstrapControllerProvider.notifier);
      await controller.run();
      final state = _ref.read(bootstrapControllerProvider);
      if (state.hasError) {
        final e = state.error;
        throw e is AppFailure ? e : const UnknownFailure();
      }
    }
    final result = await _repo.acceptInvitation(normalizeInviteCode(rawCode));
    final context = _ref.read(activeContextProvider.notifier);
    if (result.householdIds.isNotEmpty) {
      await context.selectHousehold(result.familyId, result.householdIds.first);
    } else {
      await context.selectFamily(result.familyId);
    }
    return result;
  }
}

final invitationActionsProvider = Provider<InvitationActions>(InvitationActions.new);

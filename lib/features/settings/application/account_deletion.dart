import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:planly/core/connectivity/online_only.dart';
import 'package:planly/core/error/app_failure.dart';
import 'package:planly/features/auth/application/auth_providers.dart';
import 'package:planly/features/family/application/family_providers.dart';
import 'package:planly/features/family/domain/family_models.dart';
import 'package:planly/features/settings/application/session_actions.dart';

/// O que a exclusão da conta afetaria, calculado com os dados já carregados das famílias
/// (a UI antecipa o bloqueio; o servidor continua sendo a autoridade: `OWNER_HAS_MEMBERS`).
class AccountDeletionPreview {
  const AccountDeletionPreview({
    required this.blockedFamilies,
    required this.deletedFamilies,
    required this.leftFamilies,
    required this.hasActivePaidFamily,
  });

  /// Famílias do usuário com outros participantes: a exclusão fica bloqueada.
  final List<FamilyMembership> blockedFamilies;

  /// Famílias só dele: serão apagadas junto (casas, tarefas, listas).
  final List<FamilyMembership> deletedFamilies;

  /// Famílias alheias: ele sai e o conteúdo segue sem o nome dele.
  final List<FamilyMembership> leftFamilies;

  /// Possui família de plano pago ativa: avisar para cancelar a assinatura na Play antes.
  final bool hasActivePaidFamily;

  bool get isBlocked => blockedFamilies.isNotEmpty;
}

/// Doc da família possuída (só enquanto a tela de exclusão está aberta).
final _ownedFamilyProvider = StreamProvider.autoDispose.family<Family?, String>((ref, familyId) {
  ref.watch(currentUidProvider);
  return ref.watch(familyRepositoryProvider).watchFamily(familyId);
});

/// `AsyncLoading` enquanto memberships/famílias possuídas não chegaram. Erro de leitura de uma
/// família não bloqueia a UI (vale a decisão do servidor): ela é tratada como "sem membros".
final accountDeletionPreviewProvider = Provider.autoDispose<AsyncValue<AccountDeletionPreview>>((ref) {
  final memberships = ref.watch(membershipsProvider);
  final list = memberships.value;
  if (list == null) {
    return memberships.hasError ? AsyncError(memberships.error!, memberships.stackTrace!) : const AsyncLoading();
  }
  final blocked = <FamilyMembership>[];
  final deleted = <FamilyMembership>[];
  final left = <FamilyMembership>[];
  var paid = false;
  for (final m in list) {
    if (!m.isOwner) {
      left.add(m);
      continue;
    }
    final family = ref.watch(_ownedFamilyProvider(m.familyId));
    if (family.isLoading && !family.hasValue && !family.hasError) return const AsyncLoading();
    if (m.plan != PlanId.free && m.familyStatus == FamilyStatus.active) paid = true;
    if ((family.value?.memberCount ?? 1) > 1) {
      blocked.add(m);
    } else {
      deleted.add(m);
    }
  }
  return AsyncData(AccountDeletionPreview(
    blockedFamilies: blocked,
    deletedFamilies: deleted,
    leftFamilies: left,
    hasActivePaidFamily: paid,
  ));
});

enum DeletionPhase {
  idle,
  deleting,

  /// O servidor pediu login recente: a UI oferece "Confirmar com Google".
  needsReauth,
  reauthenticating,
  done,
  failed,
}

class AccountDeletionState {
  const AccountDeletionState(this.phase, [this.failure]);

  final DeletionPhase phase;
  final AppFailure? failure;

  bool get busy => phase == DeletionPhase.deleting || phase == DeletionPhase.reauthenticating;

  /// O servidor recusou porque ainda há participantes em família do usuário.
  bool get blockedByServer =>
      failure is BusinessFailure && (failure as BusinessFailure).reason == 'OWNER_HAS_MEMBERS';
}

/// Orquestra a exclusão (T-025): online-only → callable → (login recente → reautentica →
/// repete uma vez) → limpeza local e logout. Nunca conhece SDK.
class AccountDeletionController extends Notifier<AccountDeletionState> {
  @override
  AccountDeletionState build() => const AccountDeletionState(DeletionPhase.idle);

  Future<void> submit() async {
    if (state.busy || state.phase == DeletionPhase.done) return;
    state = const AccountDeletionState(DeletionPhase.deleting);
    await _attempt(allowReauth: true);
  }

  /// Depois de `needsReauth`: refaz o login e repete a exclusão.
  Future<void> reauthenticateAndRetry() async {
    if (state.busy) return;
    state = const AccountDeletionState(DeletionPhase.reauthenticating);
    try {
      await ref.read(authRepositoryProvider).reauthenticate();
    } on CancelledFailure {
      if (ref.mounted) state = const AccountDeletionState(DeletionPhase.needsReauth);
      return;
    } on AppFailure catch (e) {
      if (ref.mounted) state = AccountDeletionState(DeletionPhase.failed, e);
      return;
    }
    if (!ref.mounted) return;
    state = const AccountDeletionState(DeletionPhase.deleting);
    // Uma única repetição: se o servidor ainda pedir login recente, é falha (sem laço).
    await _attempt(allowReauth: false);
  }

  Future<void> _attempt({required bool allowReauth}) async {
    try {
      await ensureOnline(ref);
      await ref.read(accountRepositoryProvider).deleteAccount();
    } on RequiresRecentLoginFailure catch (e) {
      if (!ref.mounted) return;
      state = allowReauth
          ? const AccountDeletionState(DeletionPhase.needsReauth)
          : AccountDeletionState(DeletionPhase.failed, e);
      return;
    } on AppFailure catch (e) {
      if (ref.mounted) state = AccountDeletionState(DeletionPhase.failed, e);
      return;
    } catch (_) {
      if (ref.mounted) state = const AccountDeletionState(DeletionPhase.failed, UnknownFailure());
      return;
    }
    // A conta já foi apagada no servidor. O logout derruba a tela (o router leva ao login) e
    // pode descartar este controller no meio: só lemos `ref` antes.
    final sessions = ref.read(sessionActionsProvider);
    await sessions.endSessionAfterAccountDeleted();
    if (ref.mounted) state = const AccountDeletionState(DeletionPhase.done);
  }
}

final accountDeletionControllerProvider =
    NotifierProvider.autoDispose<AccountDeletionController, AccountDeletionState>(
  AccountDeletionController.new,
);

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:planly/core/firebase/firebase_providers.dart';
import 'package:planly/core/sync/write_failure_center.dart';
import 'package:planly/features/auth/application/auth_providers.dart';
import 'package:planly/features/family/application/active_context.dart';
import 'package:planly/features/notifications/application/push_providers.dart';
import 'package:planly/features/reminders/application/reminder_providers.dart';

enum SignOutOutcome {
  done,

  /// Há escritas locais ainda não sincronizadas: a UI avisa e oferece "Sair mesmo assim".
  pendingWrites,
}

/// Logout (spec flutter-app §8.3, data-model §8 #16): avisa de escritas pendentes; ao sair,
/// limpa o contexto ativo, encerra a sessão e descarta o cache do Firestore.
class SessionActions {
  SessionActions(this._ref);

  final Ref _ref;

  Future<SignOutOutcome> signOut({bool force = false}) async {
    final local = _ref.read(localDataServiceProvider);
    if (!force && await local.hasPendingWrites()) return SignOutOutcome.pendingWrites;

    // O contexto é por uid: limpar antes de a sessão acabar.
    await _ref.read(activeContextProvider.notifier).clear();
    // Push (T-023): apaga o doc do aparelho (precisa da sessão ainda aberta) e invalida o token.
    await unregisterDevice(_ref, uid: _ref.read(currentUidProvider));
    // Encerrar a sessão invalida os providers que dependem de `currentUidProvider`
    // (todos os listeners), e só então o cache é descartado.
    await _ref.read(authRepositoryProvider).signOut();
    await local.clearLocalData();
    // Avisos de escritas recusadas pertencem à sessão que acabou.
    _ref.read(writeFailureCenterProvider.notifier).dismissAll();
    return SignOutOutcome.done;
  }

  /// Encerramento local depois que a Function `deleteAccount` apagou a conta (T-025). O
  /// usuário já não existe no Auth: sem aviso de escritas pendentes (não há para onde
  /// sincronizá-las). Cada passo é melhor-esforço e independente, para que uma falha de
  /// limpeza nunca deixe a sessão de uma conta apagada aberta: cancela os lembretes locais,
  /// limpa o contexto ativo, encerra a sessão local e descarta o cache do Firestore.
  Future<void> endSessionAfterAccountDeleted() async {
    Future<void> step(Future<void> Function() action) async {
      try {
        await action();
      } catch (_) {
        debugPrint('Exclusão de conta: falha numa etapa de limpeza local');
      }
    }

    final local = _ref.read(localDataServiceProvider);
    await step(() => _ref.read(reminderReconcilerProvider).cancelAll());
    await step(() => _ref.read(activeContextProvider.notifier).clear());
    // O servidor já apagou `devices`; só invalida o token FCM local.
    await step(() => unregisterDevice(_ref, uid: null, removeDoc: false));
    await step(() => _ref.read(authRepositoryProvider).signOut());
    await step(() => local.clearLocalData());
    _ref.read(writeFailureCenterProvider.notifier).dismissAll();
  }
}

final sessionActionsProvider = Provider<SessionActions>(SessionActions.new);

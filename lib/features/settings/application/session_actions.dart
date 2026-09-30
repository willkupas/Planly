import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:planly/core/firebase/firebase_providers.dart';
import 'package:planly/features/auth/application/auth_providers.dart';
import 'package:planly/features/family/application/active_context.dart';

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
    // Encerrar a sessão invalida os providers que dependem de `currentUidProvider`
    // (todos os listeners), e só então o cache é descartado.
    await _ref.read(authRepositoryProvider).signOut();
    await local.clearLocalData();
    return SignOutOutcome.done;
  }
}

final sessionActionsProvider = Provider<SessionActions>(SessionActions.new);

import 'package:planly/features/auth/domain/auth_provider_id.dart';
import 'package:planly/features/auth/domain/auth_state.dart';
import 'package:planly/features/auth/domain/auth_user.dart';

/// Contrato de autenticação. Falhas são lançadas como `AppFailure`.
abstract class AuthRepository {
  /// Emite `SignedOut`/`SignedIn` a cada mudança de sessão (o primeiro evento resolve o splash).
  Stream<AuthState> authStateChanges();

  AuthUser? get currentUser;

  /// Provedores disponíveis; a tela de login desenha um botão por item.
  Set<AuthProviderId> get availableProviders;

  Future<AuthUser> signIn(AuthProviderId provider);

  Future<void> signOut();

  /// Exclui a conta de autenticação. Lança `RequiresRecentLoginFailure` se precisar reautenticar.
  /// (O fluxo completo com Function `deleteAccount` é de tarefa futura.)
  Future<void> deleteAccount();

  Future<String?> getIdToken({bool forceRefresh = false});
}

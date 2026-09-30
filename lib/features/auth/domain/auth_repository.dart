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

  /// Refaz o login com o provedor da sessão atual (hoje Google) e confirma a identidade no
  /// Firebase, renovando o token. Usado quando uma operação sensível (excluir conta) exige
  /// login recente. Lança `CancelledFailure` se o usuário desistir e `AccountFailure` se
  /// escolher outra conta. A exclusão em si é da Function `deleteAccount` (que apaga o usuário
  /// no Auth); o cliente só precisa de `signOut()` depois. Não existe `deleteAccount()` aqui.
  Future<void> reauthenticate();

  Future<String?> getIdToken({bool forceRefresh = false});
}

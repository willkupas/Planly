import 'package:firebase_auth/firebase_auth.dart';
import 'package:planly/features/auth/domain/auth_provider_id.dart';

/// Obtém a credencial Firebase de um provedor. Novos provedores = nova implementação
/// registrada em `FirebaseAuthRepository`.
abstract class AuthProviderAdapter {
  AuthProviderId get id;

  /// Interage com o usuário (UI do provedor) e devolve a credencial. Lança `AppFailure`
  /// ou exceções do SDK (mapeadas pelo repository).
  Future<AuthCredential> obtainCredential();

  /// Encerra a sessão do provedor (ex.: Google), se houver.
  Future<void> signOut();
}

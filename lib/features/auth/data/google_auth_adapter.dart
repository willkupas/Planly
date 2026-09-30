import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:planly/core/error/app_failure.dart';
import 'package:planly/features/auth/data/auth_provider_adapter.dart';
import 'package:planly/features/auth/domain/auth_provider_id.dart';

/// Google Sign-In v7 (Credential Manager no Android). O `serverClientId` vem do
/// `default_web_client_id` gerado pelo plugin google-services a partir do
/// google-services.json do flavor; não há ID no código.
class GoogleAuthAdapter implements AuthProviderAdapter {
  GoogleAuthAdapter({GoogleSignIn? googleSignIn}) : _google = googleSignIn ?? GoogleSignIn.instance;

  final GoogleSignIn _google;
  Future<void>? _init;

  Future<void> _ensureInitialized() => _init ??= _google.initialize();

  @override
  AuthProviderId get id => AuthProviderId.google;

  @override
  Future<AuthCredential> obtainCredential() async {
    await _ensureInitialized();
    if (!_google.supportsAuthenticate()) {
      throw const ConfigurationFailure();
    }
    final account = await _google.authenticate();
    final idToken = account.authentication.idToken;
    if (idToken == null) {
      throw const AccountFailure();
    }
    return GoogleAuthProvider.credential(idToken: idToken);
  }

  @override
  Future<void> signOut() async {
    await _ensureInitialized();
    await _google.signOut();
  }
}

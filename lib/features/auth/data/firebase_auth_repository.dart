import 'package:firebase_auth/firebase_auth.dart';
import 'package:planly/core/error/app_failure.dart';
import 'package:planly/features/auth/data/auth_error_mapper.dart';
import 'package:planly/features/auth/data/auth_provider_adapter.dart';
import 'package:planly/features/auth/domain/auth_provider_id.dart';
import 'package:planly/features/auth/domain/auth_repository.dart';
import 'package:planly/features/auth/domain/auth_state.dart';
import 'package:planly/features/auth/domain/auth_user.dart';

class FirebaseAuthRepository implements AuthRepository {
  FirebaseAuthRepository({
    required FirebaseAuth auth,
    required Iterable<AuthProviderAdapter> adapters,
    // ignore: prefer_initializing_formals
  })  : _auth = auth,
        _adapters = {for (final a in adapters) a.id: a};

  final FirebaseAuth _auth;
  final Map<AuthProviderId, AuthProviderAdapter> _adapters;

  static AuthUser _toUser(User u) => AuthUser(
        uid: u.uid,
        displayName: u.displayName,
        email: u.email,
        photoUrl: u.photoURL,
      );

  @override
  Stream<AuthState> authStateChanges() => _auth
      .authStateChanges()
      .map((u) => u == null ? const SignedOut() : SignedIn(_toUser(u)));

  @override
  AuthUser? get currentUser {
    final u = _auth.currentUser;
    return u == null ? null : _toUser(u);
  }

  @override
  Set<AuthProviderId> get availableProviders => _adapters.keys.toSet();

  @override
  Future<AuthUser> signIn(AuthProviderId provider) async {
    final adapter = _adapters[provider];
    if (adapter == null) throw const ConfigurationFailure();
    try {
      final credential = await adapter.obtainCredential();
      final result = await _auth.signInWithCredential(credential);
      final user = result.user;
      if (user == null) throw const UnknownFailure();
      return _toUser(user);
    } catch (e) {
      throw mapAuthError(e);
    }
  }

  @override
  Future<void> signOut() async {
    try {
      await _auth.signOut();
    } catch (e) {
      throw mapAuthError(e);
    }
    // Melhor esforço: a sessão Firebase já foi encerrada.
    for (final adapter in _adapters.values) {
      try {
        await adapter.signOut();
      } catch (_) {}
    }
  }

  @override
  Future<void> deleteAccount() async {
    final user = _auth.currentUser;
    if (user == null) return;
    try {
      await user.delete();
    } catch (e) {
      throw mapAuthError(e);
    }
  }

  @override
  Future<String?> getIdToken({bool forceRefresh = false}) async {
    try {
      return await _auth.currentUser?.getIdToken(forceRefresh);
    } catch (e) {
      throw mapAuthError(e);
    }
  }
}

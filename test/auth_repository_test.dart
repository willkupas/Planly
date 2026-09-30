import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:planly/core/error/app_failure.dart';
import 'package:planly/features/auth/data/auth_error_mapper.dart';
import 'package:planly/features/auth/data/auth_provider_adapter.dart';
import 'package:planly/features/auth/data/firebase_auth_repository.dart';
import 'package:planly/features/auth/domain/auth_provider_id.dart';
import 'package:planly/features/auth/domain/auth_state.dart';

class _FakeAdapter implements AuthProviderAdapter {
  Object? error;
  int signOuts = 0;

  @override
  AuthProviderId get id => AuthProviderId.google;

  @override
  Future<AuthCredential> obtainCredential() async {
    if (error != null) throw error!;
    return GoogleAuthProvider.credential(idToken: 'fake-id-token');
  }

  @override
  Future<void> signOut() async => signOuts++;
}

void main() {
  group('FirebaseAuthRepository', () {
    late MockFirebaseAuth auth;
    late _FakeAdapter adapter;
    late FirebaseAuthRepository repo;

    setUp(() {
      auth = MockFirebaseAuth(
        mockUser: MockUser(uid: 'u1', displayName: 'Ana', email: 'ana@example.com'),
      );
      adapter = _FakeAdapter();
      repo = FirebaseAuthRepository(auth: auth, adapters: [adapter]);
    });

    test('expõe provedores disponíveis', () {
      expect(repo.availableProviders, {AuthProviderId.google});
    });

    test('authStateChanges: SignedOut -> signIn -> SignedIn -> signOut -> SignedOut', () async {
      final states = <AuthState>[];
      final sub = repo.authStateChanges().listen(states.add);
      await Future<void>.delayed(Duration.zero);

      final user = await repo.signIn(AuthProviderId.google);
      expect(user.uid, 'u1');
      expect(repo.currentUser?.email, 'ana@example.com');

      await repo.signOut();
      await Future<void>.delayed(Duration.zero);
      await sub.cancel();

      expect(states.first, isA<SignedOut>());
      expect(states.whereType<SignedIn>().single.user.uid, 'u1');
      expect(states.last, isA<SignedOut>());
      expect(adapter.signOuts, 1);
    });

    test('signIn mapeia erros do provedor para AppFailure', () async {
      adapter.error = const GoogleSignInException(code: GoogleSignInExceptionCode.canceled);
      await expectLater(repo.signIn(AuthProviderId.google), throwsA(isA<CancelledFailure>()));

      adapter.error = FirebaseAuthException(code: 'network-request-failed');
      await expectLater(repo.signIn(AuthProviderId.google), throwsA(isA<NetworkFailure>()));
    });

    test('getIdToken sem sessão devolve null', () async {
      expect(await repo.getIdToken(), isNull);
    });
  });

  group('mapAuthError', () {
    test('Google', () {
      GoogleSignInException g(GoogleSignInExceptionCode c) => GoogleSignInException(code: c);
      expect(mapAuthError(g(GoogleSignInExceptionCode.canceled)), isA<CancelledFailure>());
      expect(mapAuthError(g(GoogleSignInExceptionCode.interrupted)), isA<CancelledFailure>());
      expect(mapAuthError(g(GoogleSignInExceptionCode.clientConfigurationError)),
          isA<ConfigurationFailure>());
      expect(mapAuthError(g(GoogleSignInExceptionCode.unknownError)), isA<UnknownFailure>());
    });

    test('FirebaseAuth', () {
      AppFailure f(String code) => mapAuthError(FirebaseAuthException(code: code));
      expect(f('network-request-failed'), isA<NetworkFailure>());
      expect(f('requires-recent-login'), isA<RequiresRecentLoginFailure>());
      expect(f('user-disabled'), isA<AccountFailure>());
      expect(f('invalid-credential'), isA<AccountFailure>());
      expect(f('operation-not-allowed'), isA<ConfigurationFailure>());
      expect(f('qualquer-outro'), isA<UnknownFailure>());
    });

    test('desconhecido e AppFailure passam', () {
      expect(mapAuthError(StateError('x')), isA<UnknownFailure>());
      const n = NetworkFailure();
      expect(identical(mapAuthError(n), n), isTrue);
    });
  });
}

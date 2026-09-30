import 'package:flutter_test/flutter_test.dart';
import 'package:planly/app/router/guards.dart';
import 'package:planly/features/auth/domain/auth_state.dart';

import 'support/fake_auth_repository.dart';

void main() {
  const signedIn = SignedIn(testUser);

  group('resolveRedirect (spec §2.2, ordens 1-3)', () {
    test('1: auth resolvendo vai para /splash', () {
      expect(resolveRedirect(auth: const AuthLoading(), location: '/home'), '/splash');
      expect(resolveRedirect(auth: const AuthLoading(), location: '/login'), '/splash');
      expect(resolveRedirect(auth: const AuthLoading(), location: '/splash'), isNull);
    });

    test('2: deslogado vai para /login', () {
      expect(resolveRedirect(auth: const SignedOut(), location: '/home'), '/login');
      expect(resolveRedirect(auth: const SignedOut(), location: '/splash'), '/login');
      expect(resolveRedirect(auth: const SignedOut(), location: '/login'), isNull);
    });

    test('3: logado em /login ou /splash vai para /home', () {
      expect(resolveRedirect(auth: signedIn, location: '/login'), '/home');
      expect(resolveRedirect(auth: signedIn, location: '/splash'), '/home');
      expect(resolveRedirect(auth: signedIn, location: '/home'), isNull);
    });

    test('guards pós-auth só rodam logado e o primeiro destino vence', () {
      String? toBootstrap(SignedIn a, String l) => l == '/home' ? '/bootstrap' : null;
      String? other(SignedIn a, String l) => '/outro';
      expect(
        resolveRedirect(auth: signedIn, location: '/home', postAuthGuards: [toBootstrap, other]),
        '/bootstrap',
      );
      expect(
        resolveRedirect(auth: const SignedOut(), location: '/login', postAuthGuards: [other]),
        isNull,
      );
    });
  });
}

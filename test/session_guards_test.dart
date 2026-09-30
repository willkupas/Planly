import 'package:flutter_test/flutter_test.dart';
import 'package:planly/app/router/guards.dart';
import 'package:planly/app/session/session_phase.dart';
import 'package:planly/features/auth/domain/auth_state.dart';
import 'package:planly/features/family/domain/family_models.dart';

import 'support/fake_auth_repository.dart';

SessionPhase phase({
  bool profileLoading = false,
  bool profileError = false,
  bool membershipsLoading = false,
  bool membershipsError = false,
  bool hasFreeFamily = true,
  int membershipCount = 1,
  FamilyStatus? activeStatus = FamilyStatus.active,
  bool? hasHousehold = true,
}) =>
    computeSessionPhase(
      profileLoading: profileLoading,
      profileError: profileError,
      membershipsLoading: membershipsLoading,
      membershipsError: membershipsError,
      hasFreeFamily: hasFreeFamily,
      membershipCount: membershipCount,
      activeStatus: activeStatus,
      hasAccessibleHousehold: hasHousehold,
    );

void main() {
  group('computeSessionPhase', () {
    test('carregando enquanto perfil ou memberships não chegaram', () {
      expect(phase(profileLoading: true), SessionPhase.loading);
      expect(phase(membershipsLoading: true), SessionPhase.loading);
    });

    test('erro de leitura sem cache', () {
      expect(phase(profileError: true), SessionPhase.error);
      expect(phase(membershipsError: true), SessionPhase.error);
    });

    test('sem freeFamilyId e sem memberships precisa de bootstrap (spec §2.2 ordem 4)', () {
      expect(phase(hasFreeFamily: false, membershipCount: 0, activeStatus: null, hasHousehold: null),
          SessionPhase.needsBootstrap);
      // Com membership (ex.: convidado) não é bootstrap pendente.
      expect(phase(hasFreeFamily: false, membershipCount: 1), SessionPhase.ready);
    });

    test('família deleting ou sem casa acessível vai para no-access (ordens 5-6)', () {
      expect(phase(activeStatus: FamilyStatus.deleting), SessionPhase.noAccess);
      expect(phase(hasHousehold: false), SessionPhase.noAccess);
    });

    test('família frozen NÃO redireciona (modo leitura)', () {
      expect(phase(activeStatus: FamilyStatus.frozen), SessionPhase.ready);
    });

    test('casas ainda carregando não derrubam a sessão', () {
      expect(phase(hasHousehold: null), SessionPhase.ready);
    });
  });

  group('sessionGuard', () {
    test('loading segura na splash', () {
      expect(sessionGuard(SessionPhase.loading, '/home'), '/splash');
      expect(sessionGuard(SessionPhase.loading, '/splash'), '/splash');
    });

    test('bootstrap pendente: só /bootstrap, /join e /settings* passam', () {
      const p = SessionPhase.needsBootstrap;
      expect(sessionGuard(p, '/home'), '/bootstrap');
      expect(sessionGuard(p, '/family'), '/bootstrap');
      expect(sessionGuard(p, '/bootstrap'), '/bootstrap');
      expect(sessionGuard(p, '/settings'), '/settings');
      expect(sessionGuard(p, '/join'), '/join');
    });

    test('no-access: só rotas de conteúdo são redirecionadas', () {
      const p = SessionPhase.noAccess;
      expect(sessionGuard(p, '/home'), '/no-access');
      expect(sessionGuard(p, '/login'), '/no-access');
      expect(sessionGuard(p, '/family/members'), '/family/members');
      expect(sessionGuard(p, '/settings'), '/settings');
    });

    test('ready tira o usuário de /bootstrap e /no-access', () {
      expect(sessionGuard(SessionPhase.ready, '/bootstrap'), '/home');
      expect(sessionGuard(SessionPhase.ready, '/no-access'), '/home');
      expect(sessionGuard(SessionPhase.ready, '/family'), isNull);
    });
  });

  group('resolveRedirect com sessionGuard', () {
    const signedIn = SignedIn(testUser);
    List<PostAuthGuard> guardsFor(SessionPhase p) => [(a, l) => sessionGuard(p, l)];

    test('login recém-feito: loading permanece na splash, ready vai para /home', () {
      expect(
          resolveRedirect(
              auth: signedIn, location: '/login', postAuthGuards: guardsFor(SessionPhase.loading)),
          '/splash');
      expect(
          resolveRedirect(
              auth: signedIn, location: '/splash', postAuthGuards: guardsFor(SessionPhase.loading)),
          isNull);
      expect(
          resolveRedirect(
              auth: signedIn, location: '/splash', postAuthGuards: guardsFor(SessionPhase.ready)),
          '/home');
    });

    test('usuário novo vai para /bootstrap', () {
      expect(
          resolveRedirect(
              auth: signedIn, location: '/splash', postAuthGuards: guardsFor(SessionPhase.needsBootstrap)),
          '/bootstrap');
    });

    test('guards não rodam deslogado', () {
      expect(
          resolveRedirect(
              auth: const SignedOut(), location: '/login', postAuthGuards: guardsFor(SessionPhase.noAccess)),
          isNull);
    });
  });
}

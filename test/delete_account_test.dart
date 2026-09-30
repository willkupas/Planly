import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planly/core/error/app_failure.dart';
import 'package:planly/features/auth/data/callable_account_repository.dart';
import 'package:planly/features/auth/data/firebase_auth_repository.dart';
import 'package:planly/features/auth/data/auth_provider_adapter.dart';
import 'package:planly/features/auth/domain/auth_provider_id.dart';
import 'package:planly/features/auth/presentation/login_page.dart';
import 'package:planly/features/family/domain/family_models.dart';
import 'package:planly/features/family/presentation/members_page.dart';
import 'package:planly/features/household/domain/household_models.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:planly/features/reminders/domain/notification_gateway.dart';

import 'support/fake_backend.dart';
import 'support/harness.dart';

void main() {
  /// Owner de `f1` (auth = u1). `members > 1` = há outros participantes.
  Future<TestApp> ownerApp({PlanId plan = PlanId.free, int members = 1, Map<String, Object> prefs = const {}}) async {
    final app = await TestApp.create(prefs: prefs);
    app.backend
      ..profile.set(freeProfile)
      ..memberships.set([membership('f1', plan: plan, name: 'Casa Silva')])
      ..familyLive('f1').set(family('f1', plan: plan, members: members))
      ..entitlementLive('f1').set(plan == PlanId.free ? freeEntitlement : familyEntitlement)
      ..householdsLive('f1').set(HouseholdsSnapshot([Household(id: 'h1', name: 'Minha casa')]))
      ..membersLive('f1').set([
        const FamilyMember(uid: uidOwner, role: FamilyRole.owner, displayName: 'Teste'),
        if (members > 1) const FamilyMember(uid: uidMember, role: FamilyRole.member, displayName: 'Beto'),
      ]);
    return app;
  }

  void bigScreen(WidgetTester tester) {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
  }

  Future<void> openDeletePage(WidgetTester tester) async {
    await tester.tap(find.byKey(const Key('family-open-settings')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('delete-account')));
    await tester.tap(find.byKey(const Key('delete-account')));
    await tester.pumpAndSettle();
  }

  Future<void> typeWord(WidgetTester tester, String word) async {
    await tester.enterText(find.byKey(const Key('delete-confirm-field')), word);
    await tester.pump();
  }

  Future<void> goDeletePage(WidgetTester tester, TestApp app, {bool startOnline = true}) async {
    bigScreen(tester);
    await app.pump(tester, startOnline: startOnline);
    await tester.tap(find.byKey(const Key('nav-family')));
    await tester.pumpAndSettle();
    await openDeletePage(tester);
  }

  bool buttonEnabled(WidgetTester tester) =>
      tester.widget<FilledButton>(find.byKey(const Key('delete-account-button'))).onPressed != null;

  group('tela Excluir conta', () {
    testWidgets('explica o que será apagado e o que permanece; sem assinatura, sem aviso', (tester) async {
      final app = await ownerApp();
      await goDeletePage(tester, app);

      expect(find.text('O que será apagado'), findsOneWidget);
      expect(find.textContaining('Casa Silva'), findsOneWidget);
      expect(find.text('O que permanece'), findsOneWidget);
      expect(find.byKey(const Key('delete-subscription-warning')), findsNothing);
      expect(find.byKey(const Key('delete-blocked')), findsNothing);
    });

    testWidgets('membro de famílias alheias: lista de onde sai', (tester) async {
      final app = await TestApp.create();
      app.backend
        ..profile.set(freeProfile)
        ..memberships.set([membership('f2', role: FamilyRole.member, plan: PlanId.family, name: 'Família Ana')]);
      await goDeletePage(tester, app);

      expect(find.textContaining('Você sai de: Família Ana'), findsOneWidget);
      expect(find.byKey(const Key('delete-blocked')), findsNothing);
    });

    testWidgets('assinatura ativa: aviso e ajuda para cancelar na Play', (tester) async {
      final app = await ownerApp(plan: PlanId.family);
      await goDeletePage(tester, app);

      expect(find.byKey(const Key('delete-subscription-warning')), findsOneWidget);
      await tester.tap(find.byKey(const Key('delete-manage-subscription')));
      await tester.pumpAndSettle();
      expect(find.text('Como cancelar na Google Play'), findsOneWidget);
      await tester.tap(find.text('Entendi'));
      await tester.pumpAndSettle();
      expect(find.text('Como cancelar na Google Play'), findsNothing);
    });

    testWidgets('owner com participantes: bloqueia, explica e leva a Membros', (tester) async {
      final app = await ownerApp(plan: PlanId.family, members: 2);
      await goDeletePage(tester, app);

      expect(find.byKey(const Key('delete-blocked')), findsOneWidget);
      expect(find.textContaining('transfira ou remova os participantes'), findsOneWidget);
      expect(find.textContaining('Casa Silva'), findsWidgets);
      expect(find.byKey(const Key('delete-confirm-field')), findsNothing);
      expect(find.byKey(const Key('delete-account-button')), findsNothing);

      await tester.tap(find.byKey(const Key('delete-go-members')));
      await tester.pumpAndSettle();
      expect(find.byType(MembersPage), findsOneWidget);
      expect(app.account.deleteCalls, 0);
    });

    testWidgets('servidor responde OWNER_HAS_MEMBERS: passa a mostrar o bloqueio', (tester) async {
      final app = await ownerApp();
      app.account.failures.add(const BusinessFailure('OWNER_HAS_MEMBERS'));
      await goDeletePage(tester, app);

      await typeWord(tester, 'EXCLUIR');
      await tester.tap(find.byKey(const Key('delete-account-button')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('delete-blocked')), findsOneWidget);
      expect(find.byKey(const Key('delete-account-button')), findsNothing);
      expect(app.auth.signOutCalls, 0);
    });

    testWidgets('confirmação dupla: só habilita com a palavra', (tester) async {
      final app = await ownerApp();
      await goDeletePage(tester, app);

      expect(buttonEnabled(tester), isFalse);
      await typeWord(tester, 'EXCLUI');
      expect(buttonEnabled(tester), isFalse);
      await typeWord(tester, 'sim');
      expect(buttonEnabled(tester), isFalse);
      await typeWord(tester, ' excluir ');
      expect(buttonEnabled(tester), isTrue);
      expect(app.account.deleteCalls, 0);
    });

    testWidgets('offline: avisa, não chama o servidor e mostra erro de rede', (tester) async {
      final app = await ownerApp();
      await goDeletePage(tester, app, startOnline: false);

      expect(find.byKey(const Key('delete-offline')), findsOneWidget);
      await typeWord(tester, 'EXCLUIR');
      await tester.tap(find.byKey(const Key('delete-account-button')));
      await tester.pumpAndSettle();

      expect(app.account.deleteCalls, 0);
      expect(find.byKey(const Key('delete-error')), findsOneWidget);
      expect(find.text('Sem conexão. Verifique sua internet e tente de novo.'), findsWidgets);
      expect(buttonEnabled(tester), isTrue);
      expect(app.auth.signOutCalls, 0);
    });

    testWidgets('sucesso: limpa lembretes, contexto, cache, sai e volta ao login', (tester) async {
      final at = DateTime.utc(2030, 1, 1);
      final app = await ownerApp(prefs: {
        'activeContext.u1.familyId': 'f1',
        'activeContext.u1.householdId': 'h1',
      });
      app.notifications.scheduled[42] =
          ScheduledReminder(id: 42, title: 'x', body: 'y', fireAtUtc: at, payload: 'p');
      app.local.pending = true; // escritas pendentes não seguram a exclusão
      await goDeletePage(tester, app);

      await typeWord(tester, 'EXCLUIR');
      await tester.tap(find.byKey(const Key('delete-account-button')));
      await tester.pumpAndSettle();

      expect(app.account.deleteCalls, 1);
      expect(app.auth.signOutCalls, 1);
      expect(app.local.clearCalls, 1);
      expect(app.prefs.getString('activeContext.u1.familyId'), isNull);
      expect(app.prefs.getString('activeContext.u1.householdId'), isNull);
      expect(app.notifications.scheduled, isEmpty);
      expect(find.byType(LoginPage), findsOneWidget);
    });

    testWidgets('REQUIRES_RECENT_LOGIN: pede reautenticação, reautentica e repete', (tester) async {
      final app = await ownerApp();
      app.account.failures.add(const RequiresRecentLoginFailure());
      await goDeletePage(tester, app);

      await typeWord(tester, 'EXCLUIR');
      await tester.tap(find.byKey(const Key('delete-account-button')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('delete-reauth')), findsOneWidget);
      expect(app.account.deleteCalls, 1);
      expect(app.auth.signOutCalls, 0);

      await tester.tap(find.byKey(const Key('delete-reauth-button')));
      await tester.pumpAndSettle();

      expect(app.auth.reauthCalls, 1);
      expect(app.account.deleteCalls, 2);
      expect(app.auth.signOutCalls, 1);
      expect(find.byType(LoginPage), findsOneWidget);
    });

    testWidgets('reautenticação cancelada: continua na tela, sem nova exclusão', (tester) async {
      final app = await ownerApp();
      app.account.failures.add(const RequiresRecentLoginFailure());
      app.auth.nextReauthFailure = const CancelledFailure();
      await goDeletePage(tester, app);

      await typeWord(tester, 'EXCLUIR');
      await tester.tap(find.byKey(const Key('delete-account-button')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('delete-reauth-button')));
      await tester.pumpAndSettle();

      expect(app.account.deleteCalls, 1);
      expect(find.byKey(const Key('delete-reauth')), findsOneWidget);
      expect(app.auth.signOutCalls, 0);
    });

    testWidgets('servidor insiste em login recente após reautenticar: erro, sem laço', (tester) async {
      final app = await ownerApp();
      app.account.failures
        ..add(const RequiresRecentLoginFailure())
        ..add(const RequiresRecentLoginFailure());
      await goDeletePage(tester, app);

      await typeWord(tester, 'EXCLUIR');
      await tester.tap(find.byKey(const Key('delete-account-button')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('delete-reauth-button')));
      await tester.pumpAndSettle();

      expect(app.account.deleteCalls, 2);
      expect(app.auth.reauthCalls, 1);
      expect(find.byKey(const Key('delete-reauth')), findsNothing);
      expect(find.byKey(const Key('delete-error')), findsOneWidget);
      expect(app.auth.signOutCalls, 0);
    });

    testWidgets('erro de servidor: mostra mensagem, mantém a sessão e permite tentar de novo', (tester) async {
      final app = await ownerApp();
      app.account.failures.add(const UnknownFailure());
      await goDeletePage(tester, app);

      await typeWord(tester, 'EXCLUIR');
      await tester.tap(find.byKey(const Key('delete-account-button')));
      await tester.pumpAndSettle();

      expect(find.text('Algo deu errado. Tente de novo.'), findsOneWidget);
      expect(app.auth.signOutCalls, 0);
      expect(app.local.clearCalls, 0);

      await tester.tap(find.byKey(const Key('delete-account-button')));
      await tester.pumpAndSettle();
      expect(app.account.deleteCalls, 2);
      expect(find.byType(LoginPage), findsOneWidget);
    });
  });

  group('camada de dados', () {
    test('CallableAccountRepository chama `deleteAccount` sem dados pessoais', () async {
      String? name;
      Map<String, Object?>? data;
      Future<Map<String, dynamic>> invoker(String n, Map<String, Object?> d) async {
        name = n;
        data = d;
        return <String, dynamic>{'ok': true};
      }

      await CallableAccountRepository(callable: invoker).deleteAccount();
      expect(name, 'deleteAccount');
      expect(data, isEmpty);
    });

    test('FirebaseAuthRepository.reauthenticate refaz o login do provedor e mapeia falhas', () async {
      final auth = MockFirebaseAuth(mockUser: MockUser(uid: 'u1'), signedIn: true);
      final adapter = _Adapter();
      final repo = FirebaseAuthRepository(auth: auth, adapters: [adapter]);

      await repo.reauthenticate();
      expect(adapter.obtained, 1);

      adapter.error = const CancelledFailure();
      await expectLater(repo.reauthenticate(), throwsA(isA<CancelledFailure>()));

      await repo.signOut();
      await expectLater(repo.reauthenticate(), throwsA(isA<AccountFailure>()));
    });
  });
}

class _Adapter implements AuthProviderAdapter {
  int obtained = 0;
  Object? error;

  @override
  AuthProviderId get id => AuthProviderId.google;

  @override
  Future<AuthCredential> obtainCredential() async {
    if (error != null) throw error!;
    obtained++;
    return GoogleAuthProvider.credential(idToken: 'fake-id-token');
  }

  @override
  Future<void> signOut() async {}
}

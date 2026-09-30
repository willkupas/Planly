import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planly/core/error/app_failure.dart';
import 'package:planly/core/sync/sync_status.dart';
import 'package:planly/features/family/domain/family_models.dart';
import 'package:planly/features/household/domain/household_models.dart';

import 'support/fake_backend.dart';
import 'support/harness.dart';

/// Fluxos de T-014: primeiro acesso, guards de sessão, frozen, contexto ativo e logout.
void main() {
  group('primeiro acesso (bootstrap)', () {
    testWidgets('login -> bootstrap -> Family Free + casa inicial -> dashboard', (tester) async {
      final app = await TestApp.create();
      app.backend
        ..seedNewUser()
        ..bootstrapGate = Completer<void>();
      await app.pump(tester, settle: false);
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byKey(const Key('bootstrap-loading')), findsOneWidget);
      expect(find.text('Preparando sua casa'), findsOneWidget);
      expect(app.backend.calls.where((c) => c == 'bootstrapUser'), hasLength(1));

      app.backend.bootstrapGate!.complete();
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('bootstrap-loading')), findsNothing);
      expect(find.text('Minha casa'), findsOneWidget); // dashboard com a casa inicial
      // timezone IANA do aparelho foi enviado ao backend
      expect(app.backend.lastBootstrapTimezone, 'America/Sao_Paulo');
      // upsert dos campos de perfil do cliente após o bootstrap (pendência da T-011)
      expect(app.backend.calls, contains('upsertClientFields'));
      expect(app.backend.lastProfileUpsert!['locale'], 'pt-BR');
      expect(app.backend.lastProfileUpsert!['timezone'], 'America/Sao_Paulo');
      // contexto ativo persistido
      expect(app.prefs.getString('activeContext.u1.familyId'), 'f-new');
      expect(app.prefs.getString('activeContext.u1.householdId'), 'h-new');
    });

    testWidgets('sem internet: aviso claro, não chama a Function e segue ao reconectar', (tester) async {
      final app = await TestApp.create();
      app.backend.seedNewUser();
      await app.pump(tester, startOnline: false);

      expect(find.text('Precisa de internet'), findsOneWidget);
      expect(app.backend.calls, isNot(contains('bootstrapUser')));

      app.setOnline(true);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('bootstrap-retry')));
      await tester.pumpAndSettle();

      expect(app.backend.calls, contains('bootstrapUser'));
      expect(find.text('Minha casa'), findsOneWidget);
    });

    testWidgets('erro por reason (RATE_LIMITED) mostra mensagem i18n e permite tentar de novo',
        (tester) async {
      final app = await TestApp.create();
      app.backend
        ..seedNewUser()
        ..bootstrapFailures.add(const BusinessFailure('RATE_LIMITED'));
      await app.pump(tester);

      expect(find.text('Não foi possível preparar sua conta'), findsOneWidget);
      expect(find.textContaining('Muitas tentativas'), findsOneWidget);

      await tester.tap(find.byKey(const Key('bootstrap-retry')));
      await tester.pumpAndSettle();
      expect(find.text('Minha casa'), findsOneWidget);
    });

    testWidgets('usuário já configurado nunca vê o bootstrap', (tester) async {
      final app = await TestApp.create();
      app.backend.seedOwnerFree();
      await app.pump(tester);
      expect(app.backend.calls, isNot(contains('bootstrapUser')));
      expect(find.text('Minha casa'), findsOneWidget);
    });

    testWidgets('bootstrap permite sair (não prende o usuário)', (tester) async {
      final app = await TestApp.create();
      app.backend.seedNewUser();
      await app.pump(tester, startOnline: false);
      await tester.tap(find.byKey(const Key('bootstrap-sign-out')));
      await tester.pumpAndSettle();
      expect(app.auth.signOutCalls, 1);
      expect(find.text('Entrar com Google'), findsOneWidget);
    });
  });

  group('guards e estados do dashboard', () {
    testWidgets('membro sem casa vinculada cai em /no-access', (tester) async {
      final app = await TestApp.create();
      app.backend
        ..profile.set(null)
        ..memberships.set([membership('f2', role: FamilyRole.member, plan: PlanId.family)])
        ..familyLive('f2').set(family('f2', plan: PlanId.family, ownerId: 'outro'))
        ..householdsLive('f2').set(const HouseholdsSnapshot([]));
      await app.pump(tester);

      expect(find.text('Sem acesso a esta casa'), findsOneWidget);
      expect(find.textContaining('ainda não vinculou'), findsOneWidget);
      // Configurações continua acessível
      await tester.tap(find.byKey(const Key('no-access-settings')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('logout')), findsOneWidget);
    });

    testWidgets('família deleting cai em /no-access com aviso de exclusão', (tester) async {
      final app = await TestApp.create();
      app.backend
        ..profile.set(freeProfile)
        ..memberships.set([membership('f1', status: FamilyStatus.deleting)])
        ..familyLive('f1').set(family('f1', status: FamilyStatus.deleting))
        ..householdsLive('f1').set(HouseholdsSnapshot([Household(id: 'h1', name: 'Minha casa')]));
      await app.pump(tester);
      expect(find.text('Sem acesso a esta casa'), findsOneWidget);
      expect(find.textContaining('está sendo excluída'), findsOneWidget);
    });

    testWidgets('família frozen: NÃO redireciona, mostra banner e esconde ações de escrita',
        (tester) async {
      final app = await TestApp.create();
      final now = DateTime.utc(2026, 10, 1);
      app.backend
        ..seedOwnerFree()
        ..memberships.set([membership('f1', plan: PlanId.family, status: FamilyStatus.frozen)])
        ..familyLive('f1').set(family('f1',
            plan: PlanId.family, status: FamilyStatus.frozen, deleteAfter: now.add(const Duration(days: 10))))
        ..entitlementLive('f1').set(familyEntitlement);
      await app.pump(tester, now: now);

      // dashboard navega normalmente, em modo leitura
      expect(find.text('Minha casa'), findsOneWidget);
      expect(find.byKey(const Key('frozen-banner')), findsOneWidget);
      expect(find.text('Somente leitura — assinatura expirada. Exclusão em 10 dias.'), findsOneWidget);
      expect(find.textContaining('Reassine ou transfira'), findsOneWidget); // owner

      // Casas: sem FAB de criar, sem menu de renomear/excluir
      await tester.tap(find.byKey(const Key('nav-family')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('go-households')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('frozen-banner')), findsOneWidget);
      expect(find.byKey(const Key('add-household')), findsNothing);
      expect(find.byKey(const Key('household-menu-h1')), findsNothing);

      // Membros: convidar desabilitado
      await tester.tap(find.byKey(const Key('nav-family'))); // reabrir a aba volta ao hub
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('go-members')));
      await tester.pumpAndSettle();
      final invite = tester.widget<FilledButton>(find.byKey(const Key('invite-button')));
      expect(invite.onPressed, isNull);
    });

    testWidgets('frozen para membro: dica para avisar o dono', (tester) async {
      final app = await TestApp.create();
      app.backend
        ..profile.set(freeProfile)
        ..memberships.set([
          membership('f2', role: FamilyRole.member, plan: PlanId.family, status: FamilyStatus.frozen),
        ])
        ..familyLive('f2').set(family('f2', plan: PlanId.family, status: FamilyStatus.frozen, ownerId: 'outro'))
        ..householdsLive('f2').set(HouseholdsSnapshot([Household(id: 'h9', name: 'Casa da vó')]));
      await app.pump(tester);
      expect(find.text('Casa da vó'), findsOneWidget);
      expect(find.textContaining('Avise o dono'), findsOneWidget);
    });

    testWidgets('estado Loading (skeleton) enquanto as casas carregam', (tester) async {
      // perfil e memberships chegaram, mas a query de casas ainda não respondeu
      final backend = FakeBackend()
        ..profile.set(freeProfile)
        ..memberships.set([membership('f1')]);
      final app = await TestApp.create(backend: backend);
      await app.pump(tester);
      expect(find.bySemanticsLabel('Carregando'), findsWidgets);
      expect(find.byKey(const Key('dashboard-content')), findsNothing);
    });

    testWidgets('estado Empty: casas vazias vindas só do cache', (tester) async {
      final app = await TestApp.create();
      app.backend
        ..seedOwnerFree()
        ..householdsLive('f1').set(const HouseholdsSnapshot([], SyncMeta(isFromCache: true)));
      await app.pump(tester);
      expect(find.text('Nenhuma casa por aqui'), findsOneWidget);
    });

    testWidgets('estado Error com "Tentar de novo"', (tester) async {
      final app = await TestApp.create();
      app.backend
        ..seedOwnerFree()
        ..householdsLive('f1').fail(const NetworkFailure());
      await app.pump(tester);
      expect(find.text('Sem conexão. Verifique sua internet e tente de novo.'), findsOneWidget);
      expect(find.text('Tentar de novo'), findsOneWidget);
    });

    testWidgets('estado Offline: banner discreto, sem bloquear o conteúdo', (tester) async {
      final app = await TestApp.create();
      app.backend.seedOwnerFree();
      await app.pump(tester, startOnline: false);
      expect(find.textContaining('Sem conexão — alterações ficam salvas'), findsOneWidget);
      expect(find.byKey(const Key('dashboard-content')), findsOneWidget);
    });

    testWidgets('indicador de sync: salvo neste dispositivo quando há escrita pendente offline',
        (tester) async {
      final app = await TestApp.create();
      app.backend
        ..seedOwnerFree()
        ..householdsLive('f1').set(HouseholdsSnapshot(
          [Household(id: 'h1', name: 'Minha casa')],
          const SyncMeta(hasPendingWrites: true),
        ));
      await app.pump(tester, startOnline: false);
      expect(find.text('Salvo neste dispositivo'), findsOneWidget);
    });
  });

  group('contexto ativo e troca de família/casa', () {
    Future<TestApp> twoFamilies(WidgetTester tester, {Map<String, Object> prefs = const {}}) async {
      final app = await TestApp.create(prefs: prefs);
      app.backend
        ..seedOwnerFree()
        ..memberships.set([
          membership('f1', name: 'Minha família'),
          membership('f2', role: FamilyRole.member, plan: PlanId.family, name: 'Família da Ana'),
        ])
        ..familyLive('f2').set(family('f2', plan: PlanId.family, ownerId: 'ana', members: 2))
        ..entitlementLive('f2').set(familyEntitlement)
        ..householdsLive('f1').set(HouseholdsSnapshot([
          Household(id: 'h1', name: 'Minha casa'),
          Household(id: 'h1b', name: 'Casa da praia'),
        ]))
        ..householdsLive('f2').set(HouseholdsSnapshot([Household(id: 'h2', name: 'Casa da Ana')]));
      return app;
    }

    testWidgets('abre a família Free por padrão e troca pelo seletor, persistindo a escolha',
        (tester) async {
      final app = await twoFamilies(tester);
      await app.pump(tester);
      expect(find.text('Minha casa'), findsOneWidget);

      await tester.tap(find.byKey(const Key('household-selector')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('switch-family-f2')));
      await tester.pumpAndSettle();

      // contexto persistido e casa acessível da família escolhida
      expect(app.prefs.getString('activeContext.u1.familyId'), 'f2');
      expect(app.backend.calls, contains('watchHouseholds:f2:u1:member'));
      await tester.tap(find.byKey(const Key('switch-household-h2')));
      await tester.pumpAndSettle();
      expect(app.prefs.getString('activeContext.u1.householdId'), 'h2');
      expect(find.text('Casa da Ana'), findsOneWidget);
    });

    testWidgets('troca de casa dentro da família', (tester) async {
      final app = await twoFamilies(tester);
      await app.pump(tester);
      await tester.tap(find.byKey(const Key('household-selector')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('switch-household-h1b')));
      await tester.pumpAndSettle();
      expect(app.prefs.getString('activeContext.u1.householdId'), 'h1b');
      expect(find.text('Casa da praia'), findsOneWidget);
    });

    testWidgets('restaura o contexto salvo no próximo start', (tester) async {
      final app = await twoFamilies(tester, prefs: {
        'activeContext.u1.familyId': 'f2',
        'activeContext.u1.householdId': 'h2',
      });
      await app.pump(tester);
      expect(find.text('Casa da Ana'), findsOneWidget);
    });

    testWidgets('contexto salvo inválido (família removida) cai na Free', (tester) async {
      final app = await twoFamilies(tester, prefs: {
        'activeContext.u1.familyId': 'removida',
        'activeContext.u1.householdId': 'xx',
      });
      await app.pump(tester);
      expect(find.text('Minha casa'), findsOneWidget);
    });

    testWidgets('contexto de outro usuário não vaza', (tester) async {
      final app = await twoFamilies(tester, prefs: {
        'activeContext.outro.familyId': 'f2',
        'activeContext.outro.householdId': 'h2',
      });
      await app.pump(tester);
      expect(find.text('Minha casa'), findsOneWidget);
    });
  });

  group('configurações e logout', () {
    Future<void> openSettings(WidgetTester tester) async {
      await tester.tap(find.byKey(const Key('open-settings')));
      await tester.pumpAndSettle();
    }

    testWidgets('mostra a conta', (tester) async {
      final app = await TestApp.create();
      app.backend.seedOwnerFree();
      await app.pump(tester);
      await openSettings(tester);
      expect(find.text('Teste'), findsOneWidget);
      expect(find.text('teste@example.com'), findsOneWidget);
      expect(find.text('Português (Brasil)'), findsOneWidget);
    });

    testWidgets('sem pendências: sai direto, limpa contexto e cache local', (tester) async {
      final app = await TestApp.create(prefs: {
        'activeContext.u1.familyId': 'f1',
        'activeContext.u1.householdId': 'h1',
      });
      app.backend.seedOwnerFree();
      await app.pump(tester);
      await openSettings(tester);
      await tester.tap(find.byKey(const Key('logout')));
      await tester.pumpAndSettle();

      expect(app.auth.signOutCalls, 1);
      expect(app.local.clearCalls, 1);
      expect(app.prefs.getString('activeContext.u1.familyId'), isNull);
      expect(app.prefs.getString('activeContext.u1.householdId'), isNull);
      expect(find.text('Entrar com Google'), findsOneWidget);
    });

    testWidgets('com escritas pendentes: avisa; Cancelar mantém a sessão', (tester) async {
      final app = await TestApp.create();
      app.backend.seedOwnerFree();
      app.local.pending = true;
      await app.pump(tester);
      await openSettings(tester);
      await tester.tap(find.byKey(const Key('logout')));
      await tester.pumpAndSettle();

      expect(find.text('Alterações não sincronizadas'), findsOneWidget);
      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();
      expect(app.auth.signOutCalls, 0);
      expect(app.local.clearCalls, 0);
      expect(find.byKey(const Key('logout')), findsOneWidget);
    });

    testWidgets('com escritas pendentes: "Sair mesmo assim" sai e limpa a persistência', (tester) async {
      final app = await TestApp.create(prefs: {'activeContext.u1.familyId': 'f1'});
      app.backend.seedOwnerFree();
      app.local.pending = true;
      await app.pump(tester);
      await openSettings(tester);
      await tester.tap(find.byKey(const Key('logout')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Sair mesmo assim'));
      await tester.pumpAndSettle();

      expect(app.auth.signOutCalls, 1);
      expect(app.local.clearCalls, 1);
      expect(app.prefs.getString('activeContext.u1.familyId'), isNull);
      expect(find.text('Entrar com Google'), findsOneWidget);
    });
  });

  group('falha ao ler o contexto da sessão', () {
    testWidgets('erro sem cache mostra tela de erro com retry e sair', (tester) async {
      final app = await TestApp.create();
      app.backend
        ..profile.set(freeProfile)
        ..memberships.fail(const PermissionDeniedFailure());
      await app.pump(tester);
      expect(find.text('Você não tem permissão para fazer isso.'), findsOneWidget);
      expect(find.text('Tentar de novo'), findsOneWidget);
      expect(find.byKey(const Key('session-error-sign-out')), findsOneWidget);
    });
  });
}

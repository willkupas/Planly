import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planly/core/error/app_failure.dart';
import 'package:planly/core/sync/sync_status.dart';
import 'package:planly/features/family/domain/family_models.dart';
import 'package:planly/features/household/domain/household_models.dart';

import 'support/fake_backend.dart';
import 'support/harness.dart';

void main() {
  /// Owner de `f1` (auth = u1) com o plano/entitlement dados e N casas.
  Future<TestApp> ownerApp({
    PlanId plan = PlanId.free,
    Entitlement entitlement = freeEntitlement,
    List<Household>? households,
    int? householdCount,
  }) async {
    final app = await TestApp.create();
    final hs = households ?? [Household(id: 'h1', name: 'Minha casa')];
    app.backend
      ..profile.set(freeProfile)
      ..memberships.set([membership('f1', plan: plan)])
      ..familyLive('f1').set(family('f1', plan: plan, households: householdCount ?? hs.length, members: plan == PlanId.free ? 1 : 2))
      ..entitlementLive('f1').set(entitlement)
      ..householdsLive('f1').set(HouseholdsSnapshot(hs))
      ..membersLive('f1').set([
        const FamilyMember(uid: uidOwner, role: FamilyRole.owner, displayName: 'Teste'),
        const FamilyMember(uid: uidMember, role: FamilyRole.member, displayName: 'Beto'),
      ]);
    return app;
  }

  /// u1 é apenas membro de `f2` (dona: 'ana').
  Future<TestApp> memberApp() async {
    final app = await TestApp.create();
    app.backend
      ..profile.set(freeProfile)
      ..memberships.set([membership('f2', role: FamilyRole.member, plan: PlanId.family)])
      ..familyLive('f2').set(family('f2', plan: PlanId.family, ownerId: 'ana', members: 2))
      ..entitlementLive('f2').set(familyEntitlement)
      ..householdsLive('f2').set(HouseholdsSnapshot([Household(id: 'h2', name: 'Casa da Ana')]))
      ..membersLive('f2').set([
        const FamilyMember(uid: 'ana', role: FamilyRole.owner, displayName: 'Ana'),
        const FamilyMember(uid: uidOwner, role: FamilyRole.member, displayName: 'Teste'),
      ]);
    return app;
  }

  Future<void> goFamily(WidgetTester tester) async {
    await tester.tap(find.byKey(const Key('nav-family')));
    await tester.pumpAndSettle();
  }

  Future<void> goTo(WidgetTester tester, String key) async {
    await goFamily(tester);
    await tester.tap(find.byKey(Key(key)));
    await tester.pumpAndSettle();
  }

  group('hub da família', () {
    testWidgets('Free: plano, uso e upsell', (tester) async {
      final app = await ownerApp();
      await app.pump(tester);
      await goFamily(tester);

      expect(find.text('Grátis'), findsOneWidget);
      expect(find.text('1 de 1 pessoas'), findsOneWidget);
      expect(find.text('1 de 1 casas'), findsOneWidget);

      await tester.tap(find.byKey(const Key('see-plans')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('upsell-dialog')), findsOneWidget);
    });

    testWidgets('Família+: casas ilimitadas e sem upsell', (tester) async {
      final app = await ownerApp(plan: PlanId.familyPlus, entitlement: plusEntitlement);
      await app.pump(tester);
      await goFamily(tester);
      expect(find.text('Família+'), findsOneWidget);
      expect(find.text('1 casas (sem limite)'), findsOneWidget);
      expect(find.text('2 de 8 pessoas'), findsOneWidget);
      expect(find.byKey(const Key('see-plans')), findsNothing);
    });

    testWidgets('membro não vê o botão de planos', (tester) async {
      final app = await memberApp();
      await app.pump(tester);
      await goFamily(tester);
      expect(find.text('Família'), findsWidgets);
      expect(find.byKey(const Key('see-plans')), findsNothing);
    });
  });

  group('casas', () {
    testWidgets('Free no limite: criar abre upsell e NÃO chama a Function', (tester) async {
      final app = await ownerApp();
      await app.pump(tester);
      await goTo(tester, 'go-households');

      await tester.tap(find.byKey(const Key('add-household')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('upsell-dialog')), findsOneWidget);
      expect(find.textContaining('uma casa'), findsOneWidget);
      expect(app.backend.calls.where((c) => c.startsWith('createHousehold')), isEmpty);
    });

    testWidgets('plano pago abaixo do limite: cria via createHousehold e vira a casa ativa',
        (tester) async {
      final app = await ownerApp(plan: PlanId.family, entitlement: familyEntitlement);
      await app.pump(tester);
      await goTo(tester, 'go-households');

      await tester.tap(find.byKey(const Key('add-household')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Casa da praia');
      await tester.tap(find.text('Criar'));
      await tester.pumpAndSettle();

      expect(app.backend.calls, contains('createHousehold:f1:Casa da praia'));
      expect(find.text('Casa criada.'), findsOneWidget);
      expect(app.prefs.getString('activeContext.u1.householdId'), 'h-created');
    });

    testWidgets('plano pago no limite: mensagem de limite, sem chamar a Function', (tester) async {
      final app = await ownerApp(
        plan: PlanId.family,
        entitlement: familyEntitlement,
        households: [
          Household(id: 'h1', name: 'A'),
          Household(id: 'h2', name: 'B'),
          Household(id: 'h3', name: 'C'),
        ],
      );
      await app.pump(tester);
      await goTo(tester, 'go-households');
      await tester.tap(find.byKey(const Key('add-household')));
      await tester.pumpAndSettle();
      expect(find.text('O limite de casas do plano foi atingido.'), findsOneWidget);
      expect(app.backend.calls.where((c) => c.startsWith('createHousehold')), isEmpty);
    });

    testWidgets('backend recusa por reason (PLAN_LIMIT_HOUSEHOLDS): mostra texto i18n', (tester) async {
      final app = await ownerApp(plan: PlanId.family, entitlement: familyEntitlement);
      app.backend.nextActionFailure = const BusinessFailure('PLAN_LIMIT_HOUSEHOLDS');
      await app.pump(tester);
      await goTo(tester, 'go-households');
      await tester.tap(find.byKey(const Key('add-household')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Outra');
      await tester.tap(find.text('Criar'));
      await tester.pumpAndSettle();
      expect(find.text('O limite de casas do plano foi atingido.'), findsOneWidget);
    });

    testWidgets('criar offline: explica que precisa de internet e não chama a Function', (tester) async {
      final app = await ownerApp(plan: PlanId.family, entitlement: familyEntitlement);
      await app.pump(tester, startOnline: false);
      await goTo(tester, 'go-households');
      await tester.tap(find.byKey(const Key('add-household')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Offline');
      await tester.tap(find.text('Criar'));
      await tester.pumpAndSettle();
      expect(find.text('Sem conexão. Verifique sua internet e tente de novo.'), findsOneWidget);
      expect(app.backend.calls.where((c) => c.startsWith('createHousehold')), isEmpty);
    });

    testWidgets('renomear usa o update de name', (tester) async {
      final app = await ownerApp();
      await app.pump(tester);
      await goTo(tester, 'go-households');
      await tester.tap(find.byKey(const Key('household-menu-h1')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Renomear'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Apê');
      await tester.tap(find.text('Salvar'));
      await tester.pumpAndSettle();
      expect(app.backend.calls, contains('rename:f1:h1:Apê'));
    });

    testWidgets('excluir a última casa é bloqueado no cliente', (tester) async {
      final app = await ownerApp();
      await app.pump(tester);
      await goTo(tester, 'go-households');
      await tester.tap(find.byKey(const Key('household-menu-h1')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Excluir'));
      await tester.pumpAndSettle();
      expect(find.text('A família precisa ter pelo menos uma casa.'), findsOneWidget);
      expect(app.backend.calls.where((c) => c.startsWith('deleteHousehold')), isEmpty);
    });

    testWidgets('excluir com confirmação chama deleteHousehold', (tester) async {
      final app = await ownerApp(
        plan: PlanId.family,
        entitlement: familyEntitlement,
        households: [Household(id: 'h1', name: 'A'), Household(id: 'h2', name: 'B')],
      );
      await app.pump(tester);
      await goTo(tester, 'go-households');
      await tester.tap(find.byKey(const Key('household-menu-h2')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Excluir'));
      await tester.pumpAndSettle();
      expect(find.text('Excluir casa?'), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, 'Excluir'));
      await tester.pumpAndSettle();
      expect(app.backend.calls, contains('deleteHousehold:f1:h2'));
      expect(find.text('Casa excluída.'), findsOneWidget);
    });

    testWidgets('membro: só lista, sem criar/renomear/excluir', (tester) async {
      final app = await memberApp();
      await app.pump(tester);
      await goTo(tester, 'go-households');
      expect(find.text('Casa da Ana'), findsOneWidget);
      expect(find.byKey(const Key('add-household')), findsNothing);
      expect(find.byKey(const Key('household-menu-h2')), findsNothing);
    });

    testWidgets('estado Empty: membro sem casas (lista vinda do cache)', (tester) async {
      final app = await memberApp();
      app.backend.householdsLive('f2').set(const HouseholdsSnapshot([], SyncMeta(isFromCache: true)));
      await app.pump(tester);
      // dashboard já trata o vazio (cache) sem derrubar a sessão
      expect(find.text('Nenhuma casa por aqui'), findsOneWidget);
    });
  });

  group('membros', () {
    testWidgets('owner Free: convidar mostra upsell', (tester) async {
      final app = await ownerApp();
      await app.pump(tester);
      await goTo(tester, 'go-members');
      expect(find.text('Teste (você)'), findsOneWidget);
      expect(find.text('Beto'), findsOneWidget);
      await tester.tap(find.byKey(const Key('invite-button')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('upsell-dialog')), findsOneWidget);
    });

    testWidgets('owner em plano pago: convidar abre a tela de convite', (tester) async {
      final app = await ownerApp(plan: PlanId.family, entitlement: familyEntitlement);
      await app.pump(tester);
      await goTo(tester, 'go-members');
      await tester.tap(find.byKey(const Key('invite-button')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('upsell-dialog')), findsNothing);
      expect(find.byKey(const Key('invite-generate')), findsOneWidget);
    });

    testWidgets('owner remove membro (confirmação + removeMember)', (tester) async {
      final app = await ownerApp(plan: PlanId.family, entitlement: familyEntitlement);
      await app.pump(tester);
      await goTo(tester, 'go-members');
      await tester.tap(find.byKey(Key('member-menu-$uidMember')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Remover'));
      await tester.pumpAndSettle();
      expect(find.text('Remover da família?'), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, 'Remover'));
      await tester.pumpAndSettle();
      expect(app.backend.calls, contains('removeMember:f1:$uidMember'));
      expect(find.text('Membro removido.'), findsOneWidget);
    });

    testWidgets('owner não tem menu nem "sair" na própria linha', (tester) async {
      final app = await ownerApp(plan: PlanId.family, entitlement: familyEntitlement);
      await app.pump(tester);
      await goTo(tester, 'go-members');
      expect(find.byKey(const Key('leave-family')), findsNothing);
      expect(find.byKey(const Key('member-menu-$uidOwner')), findsNothing);
    });

    testWidgets('owner edita acesso por casa via setHouseholdAccess', (tester) async {
      final app = await ownerApp(
        plan: PlanId.family,
        entitlement: familyEntitlement,
        households: [
          Household(id: 'h1', name: 'Minha casa', access: const {uidMember: HouseholdRole.member}),
          Household(id: 'h2', name: 'Casa da praia'),
        ],
      );
      await app.pump(tester);
      await goTo(tester, 'go-members');
      await tester.tap(find.byKey(Key('member-menu-$uidMember')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Acesso às casas'));
      await tester.pumpAndSettle();

      expect(find.text('Acesso de Beto'), findsOneWidget);
      // h2: sem acesso -> Admin
      await tester.tap(find.descendant(of: find.byKey(const Key('access-h2')), matching: find.text('Admin')));
      await tester.pumpAndSettle();
      expect(app.backend.calls, contains('setHouseholdAccess:f1:h2:$uidMember:admin'));
      // h1: participante -> Nenhum (revoga)
      await tester.tap(find.descendant(of: find.byKey(const Key('access-h1')), matching: find.text('Nenhum')));
      await tester.pumpAndSettle();
      expect(app.backend.calls, contains('setHouseholdAccess:f1:h1:$uidMember:null'));
    });

    testWidgets('erro do backend ao remover vira mensagem i18n', (tester) async {
      final app = await ownerApp(plan: PlanId.family, entitlement: familyEntitlement);
      app.backend.nextActionFailure = const BusinessFailure('MEMBER_NOT_FOUND');
      await app.pump(tester);
      await goTo(tester, 'go-members');
      await tester.tap(find.byKey(Key('member-menu-$uidMember')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Remover'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Remover'));
      await tester.pumpAndSettle();
      expect(find.text('Não encontramos o item. Ele pode ter sido removido.'), findsOneWidget);
    });

    testWidgets('membro: vê lista, sem convidar/remover, e pode sair da família', (tester) async {
      final app = await memberApp();
      await app.pump(tester);
      await goTo(tester, 'go-members');

      expect(find.text('Ana'), findsOneWidget);
      expect(find.text('Dono da família'), findsOneWidget);
      expect(find.byKey(const Key('invite-button')), findsNothing);
      expect(find.byKey(const Key('member-menu-ana')), findsNothing);

      await tester.tap(find.byKey(const Key('leave-family')));
      await tester.pumpAndSettle();
      expect(find.text('Sair desta família?'), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, 'Sair da família'));
      await tester.pumpAndSettle();
      expect(app.backend.calls, contains('leaveFamily:f2'));
    });

    testWidgets('sair offline: aviso de internet e nenhuma chamada', (tester) async {
      final app = await memberApp();
      await app.pump(tester, startOnline: false);
      await goTo(tester, 'go-members');
      await tester.tap(find.byKey(const Key('leave-family')));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Sair da família'));
      await tester.pumpAndSettle();
      expect(app.backend.calls.where((c) => c.startsWith('leaveFamily')), isEmpty);
      expect(find.text('Sem conexão. Verifique sua internet e tente de novo.'), findsOneWidget);
    });

    testWidgets('estado Error na lista de membros, com retry', (tester) async {
      final app = await ownerApp();
      app.backend.membersLive('f1').fail(const PermissionDeniedFailure());
      await app.pump(tester);
      await goTo(tester, 'go-members');
      expect(find.text('Você não tem permissão para fazer isso.'), findsOneWidget);
      expect(find.text('Tentar de novo'), findsOneWidget);
    });
  });
}

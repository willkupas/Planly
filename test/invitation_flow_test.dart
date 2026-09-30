import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:planly/app/router/routes.dart';
import 'package:planly/core/error/app_failure.dart';
import 'package:planly/features/family/domain/family_models.dart';
import 'package:planly/features/household/domain/household_models.dart';
import 'package:planly/features/invitation/domain/invitation_models.dart';

import 'support/fake_backend.dart';
import 'support/harness.dart';

const _invalidMsg = 'Código inválido ou expirado. Confira e tente de novo, ou peça um novo convite.';

void main() {
  Future<TestApp> ownerApp({
    PlanId plan = PlanId.family,
    Entitlement entitlement = familyEntitlement,
    FamilyStatus status = FamilyStatus.active,
    List<Household>? households,
  }) async {
    final app = await TestApp.create();
    final hs = households ?? [Household(id: 'h1', name: 'Casa A'), Household(id: 'h2', name: 'Casa B')];
    app.backend
      ..profile.set(freeProfile)
      ..memberships.set([membership('f1', plan: plan, status: status)])
      ..familyLive('f1').set(family('f1', plan: plan, status: status, households: hs.length, members: 2))
      ..entitlementLive('f1').set(entitlement)
      ..householdsLive('f1').set(HouseholdsSnapshot(hs))
      ..membersLive('f1').set([
        const FamilyMember(uid: uidOwner, role: FamilyRole.owner, displayName: 'Teste'),
        const FamilyMember(uid: uidMember, role: FamilyRole.member, displayName: 'Beto'),
      ]);
    return app;
  }

  GoRouter routerOf(WidgetTester tester) => GoRouter.of(tester.element(find.byType(Scaffold).first));

  Future<void> goMembers(WidgetTester tester) async {
    await tester.tap(find.byKey(const Key('nav-family')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('go-members')));
    await tester.pumpAndSettle();
  }

  Future<void> goInvite(WidgetTester tester) async {
    await goMembers(tester);
    await tester.tap(find.byKey(const Key('invite-button')));
    await tester.pumpAndSettle();
  }

  group('convidar', () {
    testWidgets('escolhe casa + role, gera o código e compartilha', (tester) async {
      final app = await ownerApp();
      await app.pump(tester);
      await goInvite(tester);

      // Nada marcado: não gera.
      expect(tester.widget<FilledButton>(find.byKey(const Key('invite-generate'))).onPressed, isNull);
      expect(find.text('Escolha pelo menos uma casa.'), findsOneWidget);

      await tester.tap(find.byKey(const Key('invite-h-h1')));
      await tester.pumpAndSettle();
      await tester.tap(find.descendant(of: find.byKey(const Key('invite-role-h1')), matching: find.text('Admin')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('invite-h-h2')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('invite-generate')));
      await tester.pumpAndSettle();

      expect(app.invitations.calls, contains('create:f1'));
      expect(app.invitations.createdGrants.single, [
        const InviteGrant(householdId: 'h1', role: HouseholdRole.admin),
        const InviteGrant(householdId: 'h2', role: HouseholdRole.member),
      ]);
      expect(find.text('ABCDE-FGHJK'), findsOneWidget);
      expect(find.textContaining('Válido por 24 horas'), findsOneWidget);

      await tester.tap(find.byKey(const Key('invite-share')));
      await tester.pumpAndSettle();
      expect(app.shared.single, contains('ABCDE-FGHJK'));
      expect(app.shared.single, contains('https://planly.app/join/ABCDEFGHJK'));

      await tester.tap(find.byKey(const Key('invite-another')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('invite-generate')), findsOneWidget);
      expect(find.text('ABCDE-FGHJK'), findsNothing);
    });

    testWidgets('uma única casa já vem marcada', (tester) async {
      final app = await ownerApp(households: [Household(id: 'h1', name: 'Casa A')]);
      await app.pump(tester);
      await goInvite(tester);
      expect(tester.widget<CheckboxListTile>(find.byKey(const Key('invite-h-h1'))).value, isTrue);
      expect(tester.widget<FilledButton>(find.byKey(const Key('invite-generate'))).onPressed, isNotNull);
    });

    testWidgets('PLAN_LIMIT_MEMBERS: mensagem e continua no formulário', (tester) async {
      final app = await ownerApp(households: [Household(id: 'h1', name: 'Casa A')]);
      app.invitations.nextFailure = const BusinessFailure('PLAN_LIMIT_MEMBERS');
      await app.pump(tester);
      await goInvite(tester);
      await tester.tap(find.byKey(const Key('invite-generate')));
      await tester.pumpAndSettle();
      expect(find.text('O limite de pessoas do plano foi atingido.'), findsOneWidget);
      expect(find.byKey(const Key('invite-generate')), findsOneWidget);
      expect(find.byKey(const Key('invite-code')), findsNothing);
    });

    testWidgets('demais reasons: FAMILY_FROZEN, NOT_OWNER, HOUSEHOLD_NOT_FOUND, FEATURE_NOT_IN_PLAN',
        (tester) async {
      final app = await ownerApp(households: [Household(id: 'h1', name: 'Casa A')]);
      await app.pump(tester);
      await goInvite(tester);
      final expected = {
        'FAMILY_FROZEN': 'A família está somente leitura (assinatura expirada). Não é possível fazer alterações.',
        'NOT_OWNER': 'Você não tem permissão para fazer isso.',
        'HOUSEHOLD_NOT_FOUND': 'Não encontramos o item. Ele pode ter sido removido.',
        'FEATURE_NOT_IN_PLAN': 'Este recurso não está incluído no plano atual.',
      };
      for (final e in expected.entries) {
        app.invitations.nextFailure = BusinessFailure(e.key);
        await tester.tap(find.byKey(const Key('invite-generate')));
        await tester.pumpAndSettle();
        expect(find.text(e.value), findsOneWidget, reason: e.key);
      }
    });

    testWidgets('offline: explica e não chama a Function', (tester) async {
      final app = await ownerApp(households: [Household(id: 'h1', name: 'Casa A')]);
      await app.pump(tester);
      await goInvite(tester);
      app.setOnline(false);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('invite-generate')));
      await tester.pumpAndSettle();
      expect(find.text('Sem conexão. Verifique sua internet e tente de novo.'), findsWidgets);
      expect(app.invitations.calls.where((c) => c.startsWith('create')), isEmpty);
    });

    testWidgets('Free: upsell no botão e na rota direta; nunca chama a Function', (tester) async {
      final app = await ownerApp(plan: PlanId.free, entitlement: freeEntitlement);
      await app.pump(tester);
      await goMembers(tester);
      await tester.tap(find.byKey(const Key('invite-button')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('upsell-dialog')), findsOneWidget);
      await tester.tap(find.text('Entendi'));
      await tester.pumpAndSettle();

      routerOf(tester).push(Routes.familyInvite);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('invite-upsell')), findsOneWidget);
      expect(find.byKey(const Key('invite-generate')), findsNothing);
      expect(app.invitations.calls.where((c) => c.startsWith('create')), isEmpty);
    });

    testWidgets('família frozen: não gera convite', (tester) async {
      final app = await ownerApp(status: FamilyStatus.frozen, households: [Household(id: 'h1', name: 'Casa A')]);
      await app.pump(tester);
      await goMembers(tester);
      routerOf(tester).push(Routes.familyInvite);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('frozen-banner')), findsWidgets);
      expect(tester.widget<FilledButton>(find.byKey(const Key('invite-generate'))).onPressed, isNull);
    });
  });

  group('convites enviados', () {
    final now = DateTime.now();
    Invitation inv(String code, InvitationStatus s, {String family = 'f1', Duration ttl = const Duration(hours: 5)}) =>
        Invitation(
          code: code,
          familyId: family,
          grants: const [InviteGrant(householdId: 'h1', role: HouseholdRole.admin)],
          status: s,
          expiresAt: now.add(ttl),
          createdAt: now,
        );

    Future<void> openList(WidgetTester tester) async {
      await goMembers(tester);
      await tester.tap(find.byKey(const Key('invitations-button')));
      await tester.pumpAndSettle();
    }

    testWidgets('vazio', (tester) async {
      final app = await ownerApp();
      app.invitations.invitations.set(const []);
      await app.pump(tester);
      await openList(tester);
      expect(find.text('Nenhum convite enviado'), findsOneWidget);
    });

    testWidgets('lista mascarada, status e filtro por família; revoga pendente', (tester) async {
      final app = await ownerApp();
      app.invitations.invitations.set([
        inv('AAAAAAAA23', InvitationStatus.pending),
        inv('BBBBBBBB34', InvitationStatus.accepted),
        inv('CCCCCCCC45', InvitationStatus.revoked),
        inv('DDDDDDDD56', InvitationStatus.pending, ttl: const Duration(hours: -1)),
        inv('EEEEEEEE67', InvitationStatus.pending, family: 'outra'),
      ]);
      await app.pump(tester);
      await openList(tester);

      expect(find.byKey(const Key('invitation-AAAAAAAA23')), findsOneWidget);
      expect(find.byKey(const Key('invitation-EEEEEEEE67')), findsNothing);
      expect(find.text('•••••-•••23'), findsOneWidget);
      expect(find.textContaining('AAAAA'), findsNothing); // completo só no detalhe
      expect(find.text('Aceito'), findsOneWidget);
      expect(find.text('Revogado'), findsOneWidget);
      expect(find.text('Expirado'), findsOneWidget); // pendente vencido
      expect(find.textContaining('Pendente ·'), findsOneWidget);

      await tester.tap(find.byKey(const Key('invitation-BBBBBBBB34'))); // aceito: sem detalhe
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('invitation-detail-code')), findsNothing);

      await tester.tap(find.byKey(const Key('invitation-AAAAAAAA23')));
      await tester.pumpAndSettle();
      expect(find.text('AAAAA-AAA23'), findsOneWidget);
      expect(find.text('Casa A: Admin'), findsOneWidget);

      await tester.tap(find.byKey(const Key('invitation-revoke')));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Revogar convite'));
      await tester.pumpAndSettle();
      expect(app.invitations.calls, contains('revoke:AAAAAAAA23'));
      expect(find.text('Convite revogado.'), findsOneWidget);
    });

    testWidgets('revogar com erro mostra mensagem genérica', (tester) async {
      final app = await ownerApp();
      app.invitations.invitations.set([inv('AAAAAAAA23', InvitationStatus.pending)]);
      await app.pump(tester);
      await openList(tester);
      await tester.tap(find.byKey(const Key('invitation-AAAAAAAA23')));
      await tester.pumpAndSettle();
      app.invitations.nextFailure = const BusinessFailure('INVITE_NOT_FOUND');
      await tester.tap(find.byKey(const Key('invitation-revoke')));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Revogar convite'));
      await tester.pumpAndSettle();
      expect(find.text(_invalidMsg), findsOneWidget);
    });

    testWidgets('erro de leitura: estado de erro com retry', (tester) async {
      final app = await ownerApp();
      app.invitations.invitations.fail(const PermissionDeniedFailure());
      await app.pump(tester);
      await openList(tester);
      expect(find.text('Você não tem permissão para fazer isso.'), findsOneWidget);
      expect(find.text('Tentar de novo'), findsOneWidget);
    });

    testWidgets('membro (não owner) não vê o atalho de convites', (tester) async {
      final app = await TestApp.create();
      app.backend
        ..profile.set(freeProfile)
        ..memberships.set([membership('f2', role: FamilyRole.member, plan: PlanId.family)])
        ..familyLive('f2').set(family('f2', plan: PlanId.family, ownerId: 'ana', members: 2))
        ..entitlementLive('f2').set(familyEntitlement)
        ..householdsLive('f2').set(HouseholdsSnapshot([Household(id: 'h2', name: 'Casa da Ana')]))
        ..membersLive('f2').set([const FamilyMember(uid: 'ana', role: FamilyRole.owner, displayName: 'Ana')]);
      await app.pump(tester);
      await goMembers(tester);
      expect(find.byKey(const Key('invitations-button')), findsNothing);
    });
  });

  group('entrar com código', () {
    Future<void> openJoin(WidgetTester tester) async {
      await tester.tap(find.byKey(const Key('nav-family')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('go-join')));
      await tester.pumpAndSettle();
    }

    testWidgets('normaliza, aceita e troca o contexto ativo', (tester) async {
      final app = await ownerApp(plan: PlanId.free, entitlement: freeEntitlement);
      await app.pump(tester);
      await openJoin(tester);

      expect(tester.widget<FilledButton>(find.byKey(const Key('join-submit'))).onPressed, isNull);
      await tester.enterText(find.byKey(const Key('join-code')), 'abcde-fgh jk');
      await tester.pumpAndSettle();
      expect(find.text('ABCDEFGHJK'), findsOneWidget);

      await tester.tap(find.byKey(const Key('join-submit')));
      await tester.pumpAndSettle();

      expect(app.invitations.calls, contains('accept:ABCDEFGHJK'));
      expect(app.prefs.getString('activeContext.u1.familyId'), 'f2');
      expect(app.prefs.getString('activeContext.u1.householdId'), 'h2');
      expect(find.byKey(const Key('join-code')), findsNothing); // foi para o dashboard
      expect(find.text('Você entrou na família.'), findsOneWidget);
    });

    testWidgets('sem casas concedidas: só a família vira ativa', (tester) async {
      final app = await ownerApp(plan: PlanId.free, entitlement: freeEntitlement);
      app.invitations.acceptResult = const AcceptedInvitation(familyId: 'f2', householdIds: []);
      await app.pump(tester);
      await openJoin(tester);
      await tester.enterText(find.byKey(const Key('join-code')), 'ABCDEFGHJK');
      await tester.pump();
      await tester.tap(find.byKey(const Key('join-submit')));
      await tester.pumpAndSettle();
      expect(app.prefs.getString('activeContext.u1.familyId'), 'f2');
      expect(app.prefs.getString('activeContext.u1.householdId'), isNull);
    });

    testWidgets('?code= só preenche o campo (não envia)', (tester) async {
      final app = await ownerApp(plan: PlanId.free, entitlement: freeEntitlement);
      await app.pump(tester);
      routerOf(tester).push('${Routes.join}?code=abcde-fghjk');
      await tester.pumpAndSettle();
      expect(find.text('ABCDEFGHJK'), findsOneWidget);
      expect(app.invitations.calls.where((c) => c.startsWith('accept')), isEmpty);
    });

    testWidgets('erros: inexistente e expirado têm a mesma mensagem genérica', (tester) async {
      final app = await ownerApp(plan: PlanId.free, entitlement: freeEntitlement);
      await app.pump(tester);
      await openJoin(tester);
      await tester.enterText(find.byKey(const Key('join-code')), 'ABCDEFGHJK');
      await tester.pumpAndSettle();

      final expected = {
        'INVITE_NOT_FOUND': _invalidMsg,
        'INVITE_EXPIRED': _invalidMsg,
        'ALREADY_MEMBER': 'Você já faz parte desta família.',
        'PLAN_LIMIT_MEMBERS': 'Esta família atingiu o limite de pessoas. Fale com quem convidou.',
        'BOOTSTRAP_REQUIRED': 'Conclua a configuração inicial da conta antes de continuar.',
        'RATE_LIMITED': 'Muitas tentativas seguidas. Aguarde um pouco e tente de novo.',
      };
      for (final e in expected.entries) {
        app.invitations.nextFailure = BusinessFailure(e.key);
        await tester.tap(find.byKey(const Key('join-submit')));
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('join-error')), findsOneWidget, reason: e.key);
        expect(tester.widget<Text>(find.byKey(const Key('join-error'))).data, e.value, reason: e.key);
      }
      // continua na tela e sem mudar o contexto
      expect(find.byKey(const Key('join-code')), findsOneWidget);
      expect(app.prefs.getString('activeContext.u1.familyId'), isNull);
    });

    testWidgets('offline: não chama a Function', (tester) async {
      final app = await ownerApp(plan: PlanId.free, entitlement: freeEntitlement);
      await app.pump(tester);
      await openJoin(tester);
      app.setOnline(false);
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('join-code')), 'ABCDEFGHJK');
      await tester.pump();
      await tester.tap(find.byKey(const Key('join-submit')));
      await tester.pumpAndSettle();
      expect(find.text('Sem conexão. Verifique sua internet e tente de novo.'), findsWidgets);
      expect(app.invitations.calls.where((c) => c.startsWith('accept')), isEmpty);
    });

    testWidgets('antes do bootstrap: /join liberado e o aceite espera o bootstrap', (tester) async {
      final app = await TestApp.create();
      app.backend.seedNewUser();
      final gate = Completer<void>();
      app.backend.bootstrapGate = gate;
      await app.pump(tester, settle: false);
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byKey(const Key('bootstrap-join')), findsOneWidget);

      await tester.tap(find.byKey(const Key('bootstrap-join')));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byKey(const Key('join-code')), findsOneWidget);

      await tester.enterText(find.byKey(const Key('join-code')), 'ABCDEFGHJK');
      await tester.pump();
      await tester.tap(find.byKey(const Key('join-submit')));
      await tester.pump(const Duration(milliseconds: 300));
      expect(app.invitations.calls.where((c) => c.startsWith('accept')), isEmpty); // aguardando

      gate.complete();
      await tester.pumpAndSettle();
      expect(app.backend.calls.where((c) => c == 'bootstrapUser'), hasLength(1));
      expect(app.invitations.calls, contains('accept:ABCDEFGHJK'));
      expect(app.prefs.getString('activeContext.u1.familyId'), 'f2');
    });
  });
}

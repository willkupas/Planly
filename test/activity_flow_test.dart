import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planly/core/error/app_failure.dart';
import 'package:planly/core/widgets/state_widgets.dart';
import 'package:planly/features/activity/data/firestore_activity_repository.dart';
import 'package:planly/features/activity/domain/activity_models.dart';
import 'package:planly/features/activity/domain/activity_repository.dart';
import 'package:planly/features/family/domain/family_models.dart';
import 'package:planly/features/household/domain/household_models.dart';

import 'support/fake_backend.dart';
import 'support/harness.dart';

const _activityPath = 'families/f1/households/h1/activity';

/// "Agora" fixo dos testes (meio-dia local).
final _now = DateTime(2026, 9, 30, 12);

/// Repositório que delega a outro e falha a partir da N-ésima chamada.
class _FlakyRepo implements ActivityRepository {
  _FlakyRepo(
    this.inner, {
    required this.failFrom,
    this.failure = const UnknownFailure(),
  });

  final ActivityRepository inner;
  final int failFrom;
  final AppFailure failure;
  int calls = 0;
  bool recover = false;

  @override
  Future<ActivityPage> fetchPage({
    required String familyId,
    required String householdId,
    int limit = activityPageSize,
    Object? cursor,
    String? actorId,
    DateTime? since,
  }) async {
    calls++;
    if (!recover && calls >= failFrom) throw failure;
    return inner.fetchPage(
      familyId: familyId,
      householdId: householdId,
      limit: limit,
      cursor: cursor,
      actorId: actorId,
      since: since,
    );
  }
}

void main() {
  /// u1 = owner de f1 (Free por padrão), casa h1 com u2 como membro.
  Future<TestApp> app0({
    Entitlement entitlement = freeEntitlement,
    PlanId plan = PlanId.free,
  }) async {
    final app = await TestApp.create();
    app.backend
      ..profile.set(freeProfile)
      ..memberships.set([membership('f1', plan: plan)])
      ..familyLive('f1').set(family('f1', plan: plan, members: 2))
      ..entitlementLive('f1').set(entitlement)
      ..householdsLive('f1').set(
        HouseholdsSnapshot([
          Household(
            id: 'h1',
            name: 'Minha casa',
            access: {uidMember: HouseholdRole.member},
          ),
        ]),
      )
      ..membersLive('f1').set([
        const FamilyMember(
          uid: uidOwner,
          role: FamilyRole.owner,
          displayName: 'Teste',
        ),
        const FamilyMember(
          uid: uidMember,
          role: FamilyRole.member,
          displayName: 'Maria',
        ),
      ]);
    return app;
  }

  Future<void> seed(
    TestApp app,
    String id,
    DateTime at, {
    String type = 'task_completed',
    String actor = 'u1',
    String actorName = 'Teste',
    String title = 'Lavar louça',
    String targetType = 'task',
  }) {
    return app.listsDb.doc('$_activityPath/$id').set({
      'type': type,
      'actorId': actor,
      'actorName': actorName,
      'targetType': targetType,
      'targetId': 't-$id',
      'targetTitle': title,
      'createdAt': Timestamp.fromDate(at),
      'schemaVersion': 1,
    });
  }

  Future<void> goActivity(WidgetTester tester) async {
    await tester.tap(find.byKey(const Key('nav-activity')));
    await tester.pumpAndSettle();
  }

  Finder feed() => find.byKey(const Key('activity-view'));

  Future<void> scrollToEnd(WidgetTester tester, Finder target) async {
    await tester.scrollUntilVisible(
      target,
      300,
      scrollable: find.descendant(
        of: feed(),
        matching: find.byType(Scrollable),
      ),
    );
    await tester.pumpAndSettle();
  }

  group('tela Atividade', () {
    testWidgets('aba Atividade aparece no shell e mostra o vazio', (
      tester,
    ) async {
      final app = await app0();
      await app.pump(tester, now: _now);
      await goActivity(tester);
      expect(find.text('Nada por aqui ainda'), findsOneWidget);
      expect(find.textContaining('Minha casa'), findsWidgets);
      // Free: o vazio também explica o limite de 7 dias.
      expect(find.textContaining('últimos 7 dias'), findsOneWidget);
    });

    testWidgets('agrupa por dia: Hoje, Ontem e data', (tester) async {
      final app = await app0(
        entitlement: familyEntitlement,
        plan: PlanId.family,
      );
      await seed(app, 'a', DateTime(2026, 9, 30, 9));
      await seed(app, 'b', DateTime(2026, 9, 29, 20), title: 'Varrer');
      await seed(app, 'c', DateTime(2026, 9, 25, 8), title: 'Regar');
      await app.pump(tester, now: _now);
      await goActivity(tester);

      expect(find.text('Hoje'), findsOneWidget);
      expect(find.text('Ontem'), findsOneWidget);
      expect(
        find.textContaining('setembro'),
        findsOneWidget,
      ); // 25 de setembro de 2026
      expect(find.textContaining('25'), findsWidgets);
      // Ordem: Hoje acima de Ontem acima da data.
      final today = tester.getTopLeft(find.text('Hoje')).dy;
      final yesterday = tester.getTopLeft(find.text('Ontem')).dy;
      final older = tester.getTopLeft(find.textContaining('setembro')).dy;
      expect(today, lessThan(yesterday));
      expect(yesterday, lessThan(older));
    });

    testWidgets('textos por tipo, com snapshot e "Você" para o autor atual', (
      tester,
    ) async {
      final app = await app0(
        entitlement: familyEntitlement,
        plan: PlanId.family,
      );
      var m = 0;
      Future<void> add(
        String type, {
        String actor = 'u2',
        String name = 'Maria',
        String title = 'X',
        String tt = 'task',
      }) => seed(
        app,
        'e${m++}',
        _now.subtract(Duration(minutes: m)),
        type: type,
        actor: actor,
        actorName: name,
        title: title,
        targetType: tt,
      );

      await add('task_completed', title: 'Lavar louça');
      await add('item_added', title: 'Leite', tt: 'item');
      await add(
        'task_created',
        actor: 'u1',
        name: 'Teste',
        title: 'Comprar pão',
      );
      await add('task_assigned', title: 'Lixo');
      await add('task_reopened', title: 'Roupa');
      await add('task_updated', title: 'Banho');
      await add('task_deleted', title: 'Velha');
      await add('list_created', title: 'Mercado', tt: 'list');
      await add('list_deleted', title: 'Antiga', tt: 'list');
      await add('item_completed', title: 'Ovos', tt: 'item');
      await add('item_deleted', title: 'Sal', tt: 'item');
      await add(
        'member_joined',
        name: 'João',
        actor: 'u3',
        title: '',
        tt: 'member',
      );
      await add(
        'member_left',
        name: 'Ana',
        actor: 'u4',
        title: '',
        tt: 'member',
      );
      await add(
        'household_created',
        actor: 'u1',
        name: 'Teste',
        title: 'Casa nova',
        tt: 'household',
      );
      await add('tipo_novo', name: '', actor: 'u5', title: '');
      await app.pump(tester, now: _now);
      await goActivity(tester);

      // A lista é preguiçosa: aumenta a tela para montar todos os itens.
      tester.view.physicalSize = const Size(800, 4000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpAndSettle();

      for (final t in const [
        'Maria concluiu "Lavar louça"',
        'Maria adicionou "Leite" à lista',
        'Você criou a tarefa "Comprar pão"',
        'Maria atribuiu a tarefa "Lixo"',
        'Maria reabriu "Roupa"',
        'Maria editou a tarefa "Banho"',
        'Maria excluiu a tarefa "Velha"',
        'Maria criou a lista "Mercado"',
        'Maria excluiu a lista "Antiga"',
        'Maria concluiu o item "Ovos"',
        'Maria removeu "Sal" da lista',
        'João entrou na casa',
        'Ana saiu da casa',
        'Você criou a casa "Casa nova"',
        'Alguém fez uma alteração',
      ]) {
        expect(find.text(t), findsOneWidget, reason: t);
      }
    });

    testWidgets('sem ranking, contagem ou pontuação na tela', (tester) async {
      final app = await app0(
        entitlement: familyEntitlement,
        plan: PlanId.family,
      );
      await seed(app, 'a', _now.subtract(const Duration(hours: 1)));
      await app.pump(tester, now: _now);
      await goActivity(tester);
      expect(
        find.textContaining(
          RegExp('ranking|pontos|pontua|vencedor', caseSensitive: false),
        ),
        findsNothing,
      );
    });

    testWidgets(
      'filtro por pessoa recarrega só os eventos dela e volta para Todos',
      (tester) async {
        final app = await app0(
          entitlement: familyEntitlement,
          plan: PlanId.family,
        );
        await seed(
          app,
          'a',
          _now.subtract(const Duration(hours: 1)),
          title: 'Da Maria',
          actor: 'u2',
          actorName: 'Maria',
        );
        await seed(
          app,
          'b',
          _now.subtract(const Duration(hours: 2)),
          title: 'Do dono',
        );
        await app.pump(tester, now: _now);
        await goActivity(tester);

        expect(find.textContaining('Da Maria'), findsOneWidget);
        expect(find.textContaining('Do dono'), findsOneWidget);
        // O autor atual aparece como "Você" também no filtro.
        expect(
          find.descendant(
            of: find.byKey(const Key('activity-filter-u1')),
            matching: find.text('Você'),
          ),
          findsOneWidget,
        );

        await tester.tap(find.byKey(const Key('activity-filter-u2')));
        await tester.pumpAndSettle();
        expect(find.textContaining('Da Maria'), findsOneWidget);
        expect(find.textContaining('Do dono'), findsNothing);

        await tester.tap(find.byKey(const Key('activity-filter-all')));
        await tester.pumpAndSettle();
        expect(find.textContaining('Do dono'), findsOneWidget);

        await tester.tap(find.byKey(const Key('activity-filter-u1')));
        await tester.pumpAndSettle();
        expect(find.textContaining('Da Maria'), findsNothing);
        expect(find.textContaining('Do dono'), findsOneWidget);
      },
    );

    testWidgets('filtro sem resultados mostra vazio específico', (
      tester,
    ) async {
      final app = await app0(
        entitlement: familyEntitlement,
        plan: PlanId.family,
      );
      await seed(app, 'b', _now.subtract(const Duration(hours: 2)));
      await app.pump(tester, now: _now);
      await goActivity(tester);
      await tester.tap(find.byKey(const Key('activity-filter-u2')));
      await tester.pumpAndSettle();
      expect(
        find.text('Nenhuma atividade desta pessoa no período.'),
        findsOneWidget,
      );
    });

    testWidgets('sem outras pessoas na casa, o filtro nem aparece', (
      tester,
    ) async {
      final app = await app0();
      app.backend.membersLive('f1').set([
        const FamilyMember(
          uid: uidOwner,
          role: FamilyRole.owner,
          displayName: 'Teste',
        ),
      ]);
      app.backend
          .householdsLive('f1')
          .set(HouseholdsSnapshot([Household(id: 'h1', name: 'Minha casa')]));
      await app.pump(tester, now: _now);
      await goActivity(tester);
      expect(find.byKey(const Key('activity-filter')), findsNothing);
    });

    testWidgets('paginação: 20 por página + "Carregar mais" até acabar', (
      tester,
    ) async {
      final app = await app0(
        entitlement: familyEntitlement,
        plan: PlanId.family,
      );
      for (var i = 0; i < 25; i++) {
        await seed(
          app,
          'e${i.toString().padLeft(2, '0')}',
          _now.subtract(Duration(minutes: i + 1)),
          title: 'Tarefa ${i.toString().padLeft(2, '0')}',
        );
      }
      await app.pump(tester, now: _now);
      await goActivity(tester);

      final more = find.byKey(const Key('activity-load-more'));
      await scrollToEnd(tester, more);
      expect(find.textContaining('Tarefa 19'), findsOneWidget);
      expect(find.textContaining('Tarefa 20'), findsNothing);

      await tester.tap(more);
      await tester.pumpAndSettle();
      await scrollToEnd(tester, find.textContaining('Tarefa 24'));
      expect(find.textContaining('Tarefa 24'), findsOneWidget);
      expect(find.byKey(const Key('activity-load-more')), findsNothing);
      // Plano pago: sem nota de upsell.
      expect(find.byKey(const Key('activity-free-note')), findsNothing);
    });

    testWidgets(
      'falha ao carregar mais mantém a lista e permite tentar de novo',
      (tester) async {
        final app = await app0(
          entitlement: familyEntitlement,
          plan: PlanId.family,
        );
        for (var i = 0; i < 22; i++) {
          await seed(
            app,
            'e${i.toString().padLeft(2, '0')}',
            _now.subtract(Duration(minutes: i + 1)),
            title: 'Tarefa ${i.toString().padLeft(2, '0')}',
          );
        }
        final repo = _FlakyRepo(
          FirestoreActivityRepository(firestore: app.listsDb),
          failFrom: 2,
        );
        app.activityOverride = repo;
        await app.pump(tester, now: _now);
        await goActivity(tester);

        final more = find.byKey(const Key('activity-load-more'));
        await scrollToEnd(tester, more);
        await tester.tap(more);
        await tester.pumpAndSettle();
        await scrollToEnd(
          tester,
          find.byKey(const Key('activity-load-more-error')),
        );
        expect(
          find.text('Não foi possível carregar mais. Tente de novo.'),
          findsOneWidget,
        );
        expect(find.textContaining('Tarefa 19'), findsOneWidget);

        repo.recover = true;
        await tester.tap(more);
        await tester.pumpAndSettle();
        await scrollToEnd(tester, find.textContaining('Tarefa 21'));
        expect(find.byKey(const Key('activity-load-more-error')), findsNothing);
        expect(find.byKey(const Key('activity-load-more')), findsNothing);
      },
    );

    testWidgets('Free: só os últimos 7 dias + nota de upsell no fim', (
      tester,
    ) async {
      final app = await app0();
      await seed(
        app,
        'new',
        _now.subtract(const Duration(days: 3)),
        title: 'Recente',
      );
      await seed(
        app,
        'old',
        _now.subtract(const Duration(days: 8)),
        title: 'Antiga',
      );
      await app.pump(tester, now: _now);
      await goActivity(tester);
      expect(find.textContaining('Recente'), findsOneWidget);
      expect(find.textContaining('Antiga'), findsNothing);
      expect(find.byKey(const Key('activity-free-note')), findsOneWidget);
    });

    testWidgets(
      'plano com histórico completo vê eventos antigos e nenhuma nota',
      (tester) async {
        final app = await app0(
          entitlement: plusEntitlement,
          plan: PlanId.familyPlus,
        );
        await seed(
          app,
          'new',
          _now.subtract(const Duration(days: 3)),
          title: 'Recente',
        );
        await seed(
          app,
          'old',
          _now.subtract(const Duration(days: 40)),
          title: 'Antiga',
        );
        await app.pump(tester, now: _now);
        await goActivity(tester);
        expect(find.textContaining('Recente'), findsOneWidget);
        expect(find.textContaining('Antiga'), findsOneWidget);
        expect(find.byKey(const Key('activity-free-note')), findsNothing);
      },
    );

    testWidgets('permission-denied mostra mensagem amigável e tenta de novo', (
      tester,
    ) async {
      final app = await app0(
        entitlement: familyEntitlement,
        plan: PlanId.family,
      );
      await seed(
        app,
        'a',
        _now.subtract(const Duration(hours: 1)),
        title: 'Volta',
      );
      final repo = _FlakyRepo(
        FirestoreActivityRepository(firestore: app.listsDb),
        failFrom: 1,
        failure: const PermissionDeniedFailure(),
      );
      app.activityOverride = repo;
      await app.pump(tester, now: _now);
      await goActivity(tester);

      expect(
        find.text('Você não tem permissão para fazer isso.'),
        findsOneWidget,
      );
      repo.recover = true;
      await tester.tap(find.text('Tentar de novo'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Volta'), findsOneWidget);
    });

    testWidgets(
      'erro de rede no primeiro carregamento mostra Error com retry',
      (tester) async {
        final app = await app0(
          entitlement: familyEntitlement,
          plan: PlanId.family,
        );
        final repo = _FlakyRepo(
          FirestoreActivityRepository(firestore: app.listsDb),
          failFrom: 1,
          failure: const NetworkFailure(),
        );
        app.activityOverride = repo;
        await app.pump(tester, now: _now);
        await goActivity(tester);
        expect(find.byIcon(Icons.error_outline), findsOneWidget);
        expect(find.text('Tentar de novo'), findsOneWidget);
      },
    );

    testWidgets('offline: banner e o histórico (cache) continua visível', (
      tester,
    ) async {
      final app = await app0(
        entitlement: familyEntitlement,
        plan: PlanId.family,
      );
      await seed(
        app,
        'a',
        _now.subtract(const Duration(hours: 1)),
        title: 'Em cache',
      );
      await app.pump(tester, startOnline: false, now: _now);
      await goActivity(tester);
      expect(find.textContaining('Sem conexão'), findsOneWidget);
      expect(find.textContaining('Em cache'), findsOneWidget);
    });

    testWidgets('loading: skeleton enquanto a primeira página não chega', (
      tester,
    ) async {
      final app = await app0(
        entitlement: familyEntitlement,
        plan: PlanId.family,
      );
      app.activityOverride = _Gated(FirestoreActivityRepository(firestore: app.listsDb));
      await app.pump(tester, now: _now);
      await tester.tap(find.byKey(const Key('nav-activity')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.byType(LoadingSkeleton), findsOneWidget);
      expect(find.text('Nada por aqui ainda'), findsNothing);
    });

    testWidgets('voltar para a aba recarrega e mostra o que mudou', (
      tester,
    ) async {
      final app = await app0(
        entitlement: familyEntitlement,
        plan: PlanId.family,
      );
      await app.pump(tester, now: _now);
      await goActivity(tester);
      expect(find.text('Nada por aqui ainda'), findsOneWidget);

      await seed(
        app,
        'n',
        _now.subtract(const Duration(minutes: 5)),
        title: 'Nova',
      );
      await tester.tap(find.byKey(const Key('nav-home')));
      await tester.pumpAndSettle();
      await goActivity(tester);
      expect(find.textContaining('Nova'), findsOneWidget);
    });
  });
}


class _Gated implements ActivityRepository {
  _Gated(this.inner);
  final ActivityRepository inner;
  final _never = Completer<ActivityPage>();

  @override
  Future<ActivityPage> fetchPage({
    required String familyId,
    required String householdId,
    int limit = activityPageSize,
    Object? cursor,
    String? actorId,
    DateTime? since,
  }) {
    // Nunca completa: mantém a tela em Loading.
    return _never.future;
  }
}

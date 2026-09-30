import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planly/features/family/domain/family_models.dart';
import 'package:planly/features/household/domain/household_models.dart';

import 'support/fake_backend.dart';
import 'support/harness.dart';

const _listsPath = 'families/f1/households/h1/lists';

void main() {
  /// u1 = owner de f1 (casa h1).
  Future<TestApp> ownerApp({FamilyStatus status = FamilyStatus.active}) async {
    final app = await TestApp.create();
    app.backend
      ..profile.set(freeProfile)
      ..memberships.set([membership('f1', status: status)])
      ..familyLive('f1').set(family('f1', status: status))
      ..entitlementLive('f1').set(freeEntitlement)
      ..householdsLive('f1').set(HouseholdsSnapshot([Household(id: 'h1', name: 'Minha casa')]))
      ..membersLive('f1').set([const FamilyMember(uid: uidOwner, role: FamilyRole.owner, displayName: 'Teste')]);
    return app;
  }

  /// u1 e apenas membro (ou admin da casa) de f1, cuja dona e 'ana'.
  Future<TestApp> memberApp({HouseholdRole role = HouseholdRole.member}) async {
    final app = await TestApp.create();
    app.backend
      ..profile.set(freeProfile)
      ..memberships.set([membership('f1', role: FamilyRole.member, plan: PlanId.family)])
      ..familyLive('f1').set(family('f1', plan: PlanId.family, ownerId: 'ana', members: 2))
      ..entitlementLive('f1').set(familyEntitlement)
      ..householdsLive('f1').set(HouseholdsSnapshot([
        Household(id: 'h1', name: 'Casa da Ana', access: {uidOwner: role}),
      ]))
      ..membersLive('f1').set([
        const FamilyMember(uid: 'ana', role: FamilyRole.owner, displayName: 'Ana'),
        const FamilyMember(uid: uidOwner, role: FamilyRole.member, displayName: 'Teste'),
      ]);
    return app;
  }

  Future<void> seedList(TestApp app, String id, String name, {String createdBy = 'u1'}) {
    return app.listsDb.doc('$_listsPath/$id').set({
      'name': name,
      'type': 'shopping',
      'createdBy': createdBy,
      'deletedAt': null,
      'createdAt': Timestamp.now(),
      'updatedAt': Timestamp.now(),
      'schemaVersion': 1,
    });
  }

  Future<void> seedItem(
    TestApp app,
    String list,
    String id,
    String name,
    double order, {
    bool completed = false,
    String createdBy = 'u1',
  }) {
    return app.listsDb.doc('$_listsPath/$list/items/$id').set({
      'name': name,
      'completed': completed,
      'completedBy': completed ? 'u1' : null,
      'completedAt': completed ? Timestamp.now() : null,
      'createdBy': createdBy,
      'order': order,
      'deletedAt': null,
      'createdAt': Timestamp.now(),
      'updatedAt': Timestamp.now(),
      'schemaVersion': 1,
    });
  }

  Future<void> goLists(WidgetTester tester) async {
    await tester.tap(find.byKey(const Key('nav-lists')));
    await tester.pumpAndSettle();
  }

  Future<void> openList(WidgetTester tester, String id) async {
    await goLists(tester);
    await tester.tap(find.byKey(Key('list-$id')));
    await tester.pumpAndSettle();
  }

  Future<List<Map<String, dynamic>>> activityOf(TestApp app, String type) async {
    final snap = await app.listsDb
        .collection('families/f1/households/h1/activity')
        .where('type', isEqualTo: type)
        .get();
    return [for (final d in snap.docs) d.data()];
  }

  Future<void> addItem(WidgetTester tester, String name) async {
    await tester.enterText(find.byKey(const Key('item-add-field')), name);
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
  }

  group('tela Listas', () {
    testWidgets('vazio -> criar lista (nome + tipo) grava lista e activity', (tester) async {
      final app = await ownerApp();
      await app.pump(tester);
      await goLists(tester);
      expect(find.text('Nenhuma lista ainda'), findsOneWidget);

      await tester.tap(find.byKey(const Key('create-list-fab')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('list-name-field')), 'Mercado');
      await tester.tap(find.text('Geral'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('list-create-confirm')));
      await tester.pumpAndSettle();

      expect(find.text('Mercado'), findsOneWidget);
      expect(find.textContaining('Geral'), findsOneWidget); // subtitulo do tipo
      final docs = (await app.listsDb.collection(_listsPath).get()).docs;
      expect(docs.single.data()['type'], 'general');
      expect(docs.single.data()['createdBy'], 'u1');
      expect(await activityOf(app, 'list_created'), hasLength(1));
    });

    testWidgets('nome vazio nao cria', (tester) async {
      final app = await ownerApp();
      await app.pump(tester);
      await goLists(tester);
      await tester.tap(find.byKey(const Key('create-list-fab')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('list-create-confirm')));
      await tester.pumpAndSettle();
      expect((await app.listsDb.collection(_listsPath).get()).docs, isEmpty);
    });

    testWidgets('mostra contagem de pendentes (count agregado)', (tester) async {
      final app = await ownerApp();
      await seedList(app, 'l1', 'Mercado');
      await seedItem(app, 'l1', 'i1', 'Leite', 1);
      await seedItem(app, 'l1', 'i2', 'Pao', 2);
      await seedItem(app, 'l1', 'i3', 'Ovo', 3, completed: true);
      await app.pump(tester);
      await goLists(tester);
      expect(find.text('Compras · 2 pendentes'), findsOneWidget);
    });

    testWidgets('renomear e excluir (soft) pelo menu', (tester) async {
      final app = await ownerApp();
      await seedList(app, 'l1', 'Mercado');
      await app.pump(tester);
      await goLists(tester);

      await tester.tap(find.byKey(const Key('list-menu-l1')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Renomear'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Feira');
      await tester.tap(find.text('Salvar'));
      await tester.pumpAndSettle();
      expect(find.text('Feira'), findsOneWidget);

      await tester.tap(find.byKey(const Key('list-menu-l1')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Excluir'));
      await tester.pumpAndSettle();
      expect(find.text('Excluir lista?'), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, 'Excluir'));
      await tester.pumpAndSettle();

      expect(find.text('Feira'), findsNothing);
      expect(find.text('Nenhuma lista ainda'), findsOneWidget);
      final doc = await app.listsDb.doc('$_listsPath/l1').get();
      expect(doc.data()!['deletedAt'], isNotNull); // soft delete
      expect(await activityOf(app, 'list_deleted'), hasLength(1));
    });

    testWidgets('membro so gerencia lista propria; admin da casa gerencia todas', (tester) async {
      final app = await memberApp();
      await seedList(app, 'mine', 'Minha', createdBy: 'u1');
      await seedList(app, 'other', 'Da Ana', createdBy: 'ana');
      await app.pump(tester);
      await goLists(tester);
      expect(find.byKey(const Key('list-menu-mine')), findsOneWidget);
      expect(find.byKey(const Key('list-menu-other')), findsNothing);
    });

    testWidgets('admin da casa ve o menu de listas alheias', (tester) async {
      final app = await memberApp(role: HouseholdRole.admin);
      await seedList(app, 'other', 'Da Ana', createdBy: 'ana');
      await app.pump(tester);
      await goLists(tester);
      expect(find.byKey(const Key('list-menu-other')), findsOneWidget);
    });

    testWidgets('frozen: somente leitura, sem FAB e sem menu', (tester) async {
      final app = await ownerApp(status: FamilyStatus.frozen);
      await seedList(app, 'l1', 'Mercado');
      await app.pump(tester);
      await goLists(tester);
      expect(find.text('Mercado'), findsOneWidget);
      expect(find.byKey(const Key('create-list-fab')), findsNothing);
      expect(find.byKey(const Key('list-menu-l1')), findsNothing);
      expect(find.byKey(const Key('frozen-banner')), findsOneWidget);
    });
  });

  group('detalhe da lista', () {
    testWidgets('adiciona itens com Enter, mantem o foco e grava activity', (tester) async {
      final app = await ownerApp();
      await seedList(app, 'l1', 'Mercado');
      await app.pump(tester);
      await openList(tester, 'l1');
      expect(find.text('Lista vazia'), findsOneWidget);

      await addItem(tester, 'Leite');
      await addItem(tester, 'Pao');

      expect(find.text('Leite'), findsOneWidget);
      expect(find.text('Pao'), findsOneWidget);
      // Ordem de insercao preservada (order crescente).
      expect(tester.getTopLeft(find.text('Leite')).dy, lessThan(tester.getTopLeft(find.text('Pao')).dy));
      final field = tester.widget<EditableText>(find.descendant(
        of: find.byKey(const Key('item-add-field')),
        matching: find.byType(EditableText),
      ));
      expect(field.focusNode.hasFocus, isTrue);
      expect(field.controller.text, isEmpty);
      expect(await activityOf(app, 'item_added'), hasLength(2));
    });

    testWidgets('texto so com espacos nao adiciona', (tester) async {
      final app = await ownerApp();
      await seedList(app, 'l1', 'Mercado');
      await app.pump(tester);
      await openList(tester, 'l1');
      await addItem(tester, '   ');
      expect((await app.listsDb.collection('$_listsPath/l1/items').get()).docs, isEmpty);
    });

    testWidgets('marcar move para Concluidos e desmarcar volta; grava completedBy', (tester) async {
      final app = await ownerApp();
      await seedList(app, 'l1', 'Mercado');
      await seedItem(app, 'l1', 'a', 'Leite', 1);
      await seedItem(app, 'l1', 'b', 'Pao', 2);
      await app.pump(tester);
      await openList(tester, 'l1');
      expect(find.byKey(const Key('done-header')), findsNothing);

      await tester.tap(find.byKey(const Key('item-check-a')));
      await tester.pumpAndSettle();
      expect(find.text('1 concluído'), findsOneWidget);
      // Leite (concluido) agora fica depois de Pao (pendente).
      expect(tester.getTopLeft(find.text('Pao')).dy, lessThan(tester.getTopLeft(find.text('Leite')).dy));
      var doc = (await app.listsDb.doc('$_listsPath/l1/items/a').get()).data()!;
      expect(doc['completed'], true);
      expect(doc['completedBy'], 'u1');
      expect(doc['completedAt'], isNotNull);
      expect(await activityOf(app, 'item_completed'), hasLength(1));

      await tester.tap(find.byKey(const Key('item-check-a')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('done-header')), findsNothing);
      doc = (await app.listsDb.doc('$_listsPath/l1/items/a').get()).data()!;
      expect(doc['completed'], false);
      expect(doc['completedBy'], isNull);
      expect(doc['completedAt'], isNull);
      expect(await activityOf(app, 'item_completed'), hasLength(1));
    });

    testWidgets('editar nome do item', (tester) async {
      final app = await ownerApp();
      await seedList(app, 'l1', 'Mercado');
      await seedItem(app, 'l1', 'a', 'Leite', 1);
      await app.pump(tester);
      await openList(tester, 'l1');

      await tester.tap(find.text('Leite'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).last, 'Leite integral');
      await tester.tap(find.text('Salvar'));
      await tester.pumpAndSettle();

      expect(find.text('Leite integral'), findsOneWidget);
      final doc = (await app.listsDb.doc('$_listsPath/l1/items/a').get()).data()!;
      expect(doc['name'], 'Leite integral');
    });

    testWidgets('reordenar por arrastar grava so o order do item movido (ponto medio)', (tester) async {
      final app = await ownerApp();
      await seedList(app, 'l1', 'Mercado');
      await seedItem(app, 'l1', 'a', 'Item A', 1024);
      await seedItem(app, 'l1', 'b', 'Item B', 2048);
      await seedItem(app, 'l1', 'c', 'Item C', 3072);
      await app.pump(tester);
      await openList(tester, 'l1');

      // Arrasta C para cima de A.
      final g = await tester.startGesture(tester.getCenter(find.byKey(const Key('item-drag-c'))));
      await tester.pump(const Duration(milliseconds: 100));
      for (var i = 0; i < 12; i++) {
        await g.moveBy(const Offset(0, -16));
        await tester.pump(const Duration(milliseconds: 50));
      }
      await g.up();
      await tester.pumpAndSettle();

      double y(String t) => tester.getTopLeft(find.text(t)).dy;
      expect(y('Item C'), lessThan(y('Item A')));
      expect(y('Item A'), lessThan(y('Item B')));
      Future<num> order(String id) async =>
          (await app.listsDb.doc('$_listsPath/l1/items/$id').get()).data()!['order'] as num;
      expect(await order('c'), 1024 - 1024); // topo: primeiro order menos o passo
      expect(await order('a'), 1024); // vizinhos nao foram reescritos
      expect(await order('b'), 2048);
    });

    testWidgets('excluir item (soft) com activity; autor/owner veem o botao', (tester) async {
      final app = await ownerApp();
      await seedList(app, 'l1', 'Mercado');
      await seedItem(app, 'l1', 'a', 'Leite', 1, createdBy: 'ana');
      await app.pump(tester);
      await openList(tester, 'l1');

      await tester.tap(find.byKey(const Key('item-delete-a')));
      await tester.pumpAndSettle();
      expect(find.text('Leite'), findsNothing);
      final doc = (await app.listsDb.doc('$_listsPath/l1/items/a').get()).data()!;
      expect(doc['deletedAt'], isNotNull);
      expect(await activityOf(app, 'item_deleted'), hasLength(1));
    });

    testWidgets('membro: edita/completa item alheio, mas so exclui o proprio', (tester) async {
      final app = await memberApp();
      await seedList(app, 'l1', 'Da Ana', createdBy: 'ana');
      await seedItem(app, 'l1', 'theirs', 'Dela', 1, createdBy: 'ana');
      await seedItem(app, 'l1', 'mine', 'Meu', 2, createdBy: 'u1');
      await app.pump(tester);
      await openList(tester, 'l1');

      expect(find.byKey(const Key('item-delete-theirs')), findsNothing);
      expect(find.byKey(const Key('item-delete-mine')), findsOneWidget);
      // Colaborativo: completa o item de outra pessoa.
      await tester.tap(find.byKey(const Key('item-check-theirs')));
      await tester.pumpAndSettle();
      final doc = (await app.listsDb.doc('$_listsPath/l1/items/theirs').get()).data()!;
      expect(doc['completed'], true);
      expect(doc['completedBy'], 'u1');
      // Sem menu de lista (nao e autora nem admin).
      expect(find.byKey(const Key('list-detail-menu')), findsNothing);
    });

    testWidgets('admin da casa exclui item alheio', (tester) async {
      final app = await memberApp(role: HouseholdRole.admin);
      await seedList(app, 'l1', 'Da Ana', createdBy: 'ana');
      await seedItem(app, 'l1', 'theirs', 'Dela', 1, createdBy: 'ana');
      await app.pump(tester);
      await openList(tester, 'l1');
      expect(find.byKey(const Key('item-delete-theirs')), findsOneWidget);
      expect(find.byKey(const Key('list-detail-menu')), findsOneWidget);
    });

    testWidgets('frozen: sem adicionar, sem checkbox, sem arrastar, sem excluir', (tester) async {
      final app = await ownerApp(status: FamilyStatus.frozen);
      await seedList(app, 'l1', 'Mercado');
      await seedItem(app, 'l1', 'a', 'Leite', 1);
      await app.pump(tester);
      await openList(tester, 'l1');

      expect(find.text('Leite'), findsOneWidget);
      expect(find.byKey(const Key('item-add-field')), findsNothing);
      expect(find.byKey(const Key('item-drag-a')), findsNothing);
      expect(find.byKey(const Key('item-delete-a')), findsNothing);
      expect(find.byKey(const Key('list-detail-menu')), findsNothing);
      final check = tester.widget<Checkbox>(find.byKey(const Key('item-check-a')));
      expect(check.onChanged, isNull);
      await tester.tap(find.text('Leite'));
      await tester.pumpAndSettle();
      expect(find.text('Editar item'), findsNothing);
    });

    testWidgets('offline: banner aparece e a escrita continua funcionando', (tester) async {
      final app = await ownerApp();
      await seedList(app, 'l1', 'Mercado');
      await app.pump(tester);
      await openList(tester, 'l1');

      app.setOnline(false);
      await tester.pumpAndSettle();
      expect(find.textContaining('Sem conexão'), findsWidgets);

      await addItem(tester, 'Cafe');
      expect(find.text('Cafe'), findsOneWidget);
      expect((await app.listsDb.collection('$_listsPath/l1/items').get()).docs, hasLength(1));
    });

    testWidgets('lista excluida por outra pessoa mostra aviso', (tester) async {
      final app = await ownerApp();
      await seedList(app, 'l1', 'Mercado');
      await app.pump(tester);
      await openList(tester, 'l1');
      await app.listsDb.doc('$_listsPath/l1').update({'deletedAt': Timestamp.now()});
      await tester.pumpAndSettle();
      expect(find.text('Esta lista não existe mais.'), findsOneWidget);
      expect(find.byKey(const Key('item-add-field')), findsNothing);
    });

    testWidgets('excluir lista pelo detalhe volta para Listas', (tester) async {
      final app = await ownerApp();
      await seedList(app, 'l1', 'Mercado');
      await app.pump(tester);
      await openList(tester, 'l1');

      await tester.tap(find.byKey(const Key('list-detail-menu')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Excluir'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Excluir'));
      await tester.pumpAndSettle();
      expect(find.text('Nenhuma lista ainda'), findsOneWidget);
    });
  });
}

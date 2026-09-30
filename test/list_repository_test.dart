import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planly/core/error/app_failure.dart';
import 'package:planly/features/lists/data/firestore_list_repository.dart';
import 'package:planly/features/lists/domain/list_models.dart';

const f = 'f1';
const h = 'h1';

void main() {
  late FakeFirebaseFirestore db;
  late FirestoreListRepository repo;

  setUp(() {
    db = FakeFirebaseFirestore();
    repo = FirestoreListRepository(firestore: db);
  });

  CollectionReference<Map<String, dynamic>> lists() =>
      db.collection('families/$f/households/$h/lists');
  CollectionReference<Map<String, dynamic>> activity() =>
      db.collection('families/$f/households/$h/activity');
  CollectionReference<Map<String, dynamic>> items(String l) => lists().doc(l).collection('items');

  Future<String> newList([String name = 'Mercado']) => repo.createList(
        familyId: f,
        householdId: h,
        name: name,
        type: ListType.shopping,
        actorId: 'u1',
        actorName: 'Ana',
      );

  Future<String> newItem(String list, String name, double order) => repo.addItem(
        familyId: f,
        householdId: h,
        listId: list,
        name: name,
        order: order,
        actorId: 'u1',
        actorName: 'Ana',
      );

  Future<void> complete(String l, String id, String name, bool done, {String uid = 'u2'}) =>
      repo.setItemCompleted(
        familyId: f,
        householdId: h,
        listId: l,
        itemId: id,
        itemName: name,
        completed: done,
        actorId: uid,
        actorName: 'Beto',
      );

  test('createList grava so as chaves das Rules + activity list_created no mesmo batch', () async {
    final id = await newList('  Mercado  ');
    final doc = (await lists().doc(id).get()).data()!;
    expect(
      doc.keys.toSet(),
      {'name', 'type', 'createdBy', 'deletedAt', 'createdAt', 'updatedAt', 'schemaVersion'},
    );
    expect(doc['name'], 'Mercado');
    expect(doc['type'], 'shopping');
    expect(doc['createdBy'], 'u1');
    expect(doc['deletedAt'], isNull);
    expect(doc['schemaVersion'], 1);

    final act = (await activity().get()).docs.single.data();
    expect(act.keys.toSet(), {
      'type',
      'actorId',
      'actorName',
      'targetType',
      'targetId',
      'targetTitle',
      'createdAt',
      'schemaVersion',
    });
    expect(act['type'], 'list_created');
    expect(act['targetType'], 'list');
    expect(act['targetId'], id);
    expect(act['targetTitle'], 'Mercado');
  });

  test('watchLists ignora excluidas e ordena por nome', () async {
    await newList('banana');
    final b = await newList('Abacate');
    final c = await newList('Excluir');
    await repo.deleteList(
      familyId: f,
      householdId: h,
      listId: c,
      listName: 'Excluir',
      actorId: 'u1',
      actorName: 'Ana',
    );
    final snap = await repo.watchLists(f, h).first;
    expect(snap.items.map((l) => l.name), ['Abacate', 'banana']);
    expect(snap.items.first.id, b);
    final del = (await activity().where('type', isEqualTo: 'list_deleted').get()).docs.single.data();
    expect(del['targetId'], c);
    expect((await lists().doc(c).get()).data()!['deletedAt'], isNotNull);
  });

  test('renameList altera so name/updatedAt (sem activity)', () async {
    final id = await newList();
    await repo.renameList(familyId: f, householdId: h, listId: id, name: ' Feira ');
    expect((await lists().doc(id).get()).data()!['name'], 'Feira');
    expect((await activity().get()).docs, hasLength(1)); // so o list_created
  });

  test('addItem: chaves exatas, order e activity item_added', () async {
    final l = await newList();
    final id = await newItem(l, 'Leite', 1024);
    final doc = (await items(l).doc(id).get()).data()!;
    expect(doc.keys.toSet(), {
      'name',
      'completed',
      'completedBy',
      'completedAt',
      'createdBy',
      'order',
      'deletedAt',
      'createdAt',
      'updatedAt',
      'schemaVersion',
    });
    expect(doc['completed'], false);
    expect(doc['order'], 1024);
    final act = (await activity().where('type', isEqualTo: 'item_added').get()).docs.single.data();
    expect(act['targetType'], 'item');
    expect(act['targetId'], id);
    expect(act['targetTitle'], 'Leite');
  });

  test('watchItems: pendentes antes dos concluidos, cada grupo por order', () async {
    final l = await newList();
    final a = await newItem(l, 'A', 3000);
    final b = await newItem(l, 'B', 1000);
    final c = await newItem(l, 'C', 2000);
    await complete(l, b, 'B', true);
    final snap = await repo.watchItems(f, h, l).first;
    expect(snap.items.map((i) => i.name), ['C', 'A', 'B']);
    expect(snap.pending.map((i) => i.id), [c, a]);
    expect(snap.done.single.completedBy, 'u2');
    expect(snap.done.single.completedAt, isNotNull);
  });

  test('completar grava completedBy/At + activity; desmarcar zera e nao gera activity', () async {
    final l = await newList();
    final id = await newItem(l, 'Pao', 1024);
    await complete(l, id, 'Pao', true);
    var doc = (await items(l).doc(id).get()).data()!;
    expect(doc['completed'], true);
    expect(doc['completedBy'], 'u2');
    expect(doc['completedAt'], isA<Timestamp>());
    expect((await activity().where('type', isEqualTo: 'item_completed').get()).docs, hasLength(1));

    await complete(l, id, 'Pao', false);
    doc = (await items(l).doc(id).get()).data()!;
    expect(doc['completed'], false);
    expect(doc['completedBy'], isNull);
    expect(doc['completedAt'], isNull);
    expect((await activity().where('type', isEqualTo: 'item_completed').get()).docs, hasLength(1));
  });

  test('renameItem, reorderItems e deleteItem (soft) com activity item_deleted', () async {
    final l = await newList();
    final a = await newItem(l, 'A', 1024);
    final b = await newItem(l, 'B', 2048);
    await repo.renameItem(familyId: f, householdId: h, listId: l, itemId: a, name: ' Arroz ');
    await repo.reorderItems(familyId: f, householdId: h, listId: l, orders: {a: 3000});
    var snap = await repo.watchItems(f, h, l).first;
    expect(snap.items.map((i) => i.name), ['B', 'Arroz']);
    expect(snap.items.last.order, 3000);

    await repo.deleteItem(
      familyId: f,
      householdId: h,
      listId: l,
      itemId: b,
      itemName: 'B',
      actorId: 'u1',
      actorName: 'Ana',
    );
    snap = await repo.watchItems(f, h, l).first;
    expect(snap.items.map((i) => i.id), [a]);
    expect((await items(l).doc(b).get()).data()!['deletedAt'], isNotNull); // soft delete
    final del = (await activity().where('type', isEqualTo: 'item_deleted').get()).docs.single.data();
    expect(del['targetId'], b);
  });

  group('commitOptimistic', () {
    test('erro de Rules vira PermissionDeniedFailure', () async {
      final err = FirebaseException(plugin: 'cloud_firestore', code: 'permission-denied');
      await expectLater(commitOptimistic(Future<void>.error(err)), throwsA(isA<PermissionDeniedFailure>()));
    });

    test('offline (sem ack): devolve sem travar e engole erro tardio', () async {
      final c = Completer<void>();
      await commitOptimistic(c.future); // volta apos a tolerancia (~2 s), sem ack
      c.completeError(FirebaseException(plugin: 'cloud_firestore', code: 'permission-denied'));
      await Future<void>.delayed(Duration.zero); // sem excecao nao tratada
    });
  });
}

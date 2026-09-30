import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planly/features/activity/application/activity_grouping.dart';
import 'package:planly/features/activity/data/activity_entry.dart';
import 'package:planly/features/activity/data/firestore_activity_repository.dart';
import 'package:planly/features/activity/domain/activity_models.dart';

const f = 'f1';
const h = 'h1';

void main() {
  late FakeFirebaseFirestore db;
  late FirestoreActivityRepository repo;
  final base = DateTime(2026, 9, 30, 12);

  setUp(() {
    db = FakeFirebaseFirestore();
    repo = FirestoreActivityRepository(firestore: db);
  });

  Future<void> seed(
    String id,
    DateTime at, {
    String type = 'task_completed',
    String actor = 'u1',
  }) {
    return db.doc('families/$f/households/$h/activity/$id').set({
      'type': type,
      'actorId': actor,
      'actorName': 'Nome $actor',
      'targetType': 'task',
      'targetId': 't-$id',
      'targetTitle': 'Titulo $id',
      'createdAt': Timestamp.fromDate(at),
      'schemaVersion': 1,
    });
  }

  Future<void> seedMany(int n) async {
    for (var i = 0; i < n; i++) {
      await seed(
        'e${i.toString().padLeft(2, '0')}',
        base.subtract(Duration(minutes: i)),
      );
    }
  }

  test('ordena por createdAt desc e mapeia os snapshots', () async {
    await seed('a', base.subtract(const Duration(hours: 3)));
    await seed(
      'b',
      base.subtract(const Duration(hours: 1)),
      type: 'member_joined',
      actor: 'u2',
    );
    final page = await repo.fetchPage(familyId: f, householdId: h);
    expect(page.events.map((e) => e.id), ['b', 'a']);
    expect(page.events.first.type, ActivityEventType.memberJoined);
    expect(page.events.first.actorName, 'Nome u2');
    expect(page.events.last.targetTitle, 'Titulo a');
    expect(page.hasMore, isFalse);
  });

  test('tipo desconhecido vira unknown (sem quebrar)', () async {
    await seed('x', base, type: 'tipo_do_futuro');
    final page = await repo.fetchPage(familyId: f, householdId: h);
    expect(page.events.single.type, ActivityEventType.unknown);
  });

  test('todo tipo gravado pelo cliente e por Function tem mapeamento', () {
    for (final t in ActivityType.values) {
      expect(
        ActivityEventType.parse(t.wire),
        isNot(ActivityEventType.unknown),
        reason: t.wire,
      );
    }
    for (final w in ['member_joined', 'member_left', 'household_created']) {
      expect(
        ActivityEventType.parse(w),
        isNot(ActivityEventType.unknown),
        reason: w,
      );
    }
  });

  test('pagina por cursor sem repetir nem perder eventos', () async {
    await seedMany(25);
    final p1 = await repo.fetchPage(familyId: f, householdId: h, limit: 10);
    expect(p1.events, hasLength(10));
    expect(p1.hasMore, isTrue);
    final p2 = await repo.fetchPage(
      familyId: f,
      householdId: h,
      limit: 10,
      cursor: p1.cursor,
    );
    expect(p2.events, hasLength(10));
    expect(p2.hasMore, isTrue);
    final p3 = await repo.fetchPage(
      familyId: f,
      householdId: h,
      limit: 10,
      cursor: p2.cursor,
    );
    expect(p3.events, hasLength(5));
    expect(p3.hasMore, isFalse);
    final ids = [
      ...p1.events,
      ...p2.events,
      ...p3.events,
    ].map((e) => e.id).toList();
    expect(ids.toSet(), hasLength(25));
    expect(ids, [
      for (var i = 0; i < 25; i++) 'e${i.toString().padLeft(2, '0')}',
    ]);
  });

  test('exatamente uma página cheia nao anuncia mais', () async {
    await seedMany(10);
    final p = await repo.fetchPage(familyId: f, householdId: h, limit: 10);
    expect(p.events, hasLength(10));
    expect(p.hasMore, isFalse);
  });

  test('limit e limitado a 50 (Rules exigem <= 50)', () async {
    await seedMany(60);
    final p = await repo.fetchPage(familyId: f, householdId: h, limit: 500);
    expect(p.events, hasLength(50));
    expect(p.hasMore, isTrue);
  });

  test('filtro por pessoa usa actorId', () async {
    await seed('a', base, actor: 'u1');
    await seed('b', base.subtract(const Duration(minutes: 1)), actor: 'u2');
    await seed('c', base.subtract(const Duration(minutes: 2)), actor: 'u2');
    final p = await repo.fetchPage(familyId: f, householdId: h, actorId: 'u2');
    expect(p.events.map((e) => e.id), ['b', 'c']);
  });

  test('since descarta eventos mais antigos (janela Free)', () async {
    await seed('old', base.subtract(const Duration(days: 8)));
    await seed('edge', base.subtract(const Duration(days: 6)));
    await seed('new', base);
    final p = await repo.fetchPage(
      familyId: f,
      householdId: h,
      since: base.subtract(const Duration(days: 7)),
    );
    expect(p.events.map((e) => e.id), ['new', 'edge']);
  });

  test('filtro por pessoa combinado com since e cursor', () async {
    for (var i = 0; i < 6; i++) {
      await seed('u2-$i', base.subtract(Duration(hours: i)), actor: 'u2');
      await seed(
        'u1-$i',
        base.subtract(Duration(hours: i, minutes: 30)),
        actor: 'u1',
      );
    }
    final since = base.subtract(const Duration(hours: 4));
    final p1 = await repo.fetchPage(
      familyId: f,
      householdId: h,
      actorId: 'u2',
      since: since,
      limit: 2,
    );
    expect(p1.events.map((e) => e.id), ['u2-0', 'u2-1']);
    final p2 = await repo.fetchPage(
      familyId: f,
      householdId: h,
      actorId: 'u2',
      since: since,
      limit: 2,
      cursor: p1.cursor,
    );
    expect(p2.events.map((e) => e.id), ['u2-2', 'u2-3']);
    expect(p2.hasMore, isTrue);
    final p3 = await repo.fetchPage(
      familyId: f,
      householdId: h,
      actorId: 'u2',
      since: since,
      limit: 2,
      cursor: p2.cursor,
    );
    expect(p3.events.map((e) => e.id), ['u2-4']);
    expect(p3.hasMore, isFalse);
  });

  test('casa sem atividade: pagina vazia', () async {
    final p = await repo.fetchPage(familyId: f, householdId: h);
    expect(p.events, isEmpty);
    expect(p.hasMore, isFalse);
  });

  group('groupByDay', () {
    ActivityEvent ev(String id, DateTime? at) => ActivityEvent(
      id: id,
      type: ActivityEventType.taskCompleted,
      actorId: 'u1',
      actorName: 'A',
      targetType: 'task',
      targetId: id,
      targetTitle: id,
      createdAt: at,
    );

    test('agrupa por dia local preservando a ordem', () {
      final groups = groupByDay([
        ev('a', DateTime(2026, 9, 30, 10)),
        ev('b', DateTime(2026, 9, 30, 8)),
        ev('c', DateTime(2026, 9, 29, 23, 59)),
        ev('d', DateTime(2026, 9, 1)),
      ], base);
      expect(groups.map((g) => g.day), [
        DateTime(2026, 9, 30),
        DateTime(2026, 9, 29),
        DateTime(2026, 9, 1),
      ]);
      expect(groups.first.events.map((e) => e.id), ['a', 'b']);
    });

    test('evento pendente (sem createdAt) cai em hoje', () {
      final groups = groupByDay([ev('p', null)], base);
      expect(groups.single.day, DateTime(2026, 9, 30));
    });

    test('rotulos Hoje/Ontem/data, inclusive na virada de mes', () {
      expect(dayLabelFor(DateTime(2026, 9, 30), base), DayLabel.today);
      expect(dayLabelFor(DateTime(2026, 9, 29), base), DayLabel.yesterday);
      expect(dayLabelFor(DateTime(2026, 9, 28), base), DayLabel.date);
      final firstOfMonth = DateTime(2026, 10, 1, 9);
      expect(
        dayLabelFor(DateTime(2026, 9, 30), firstOfMonth),
        DayLabel.yesterday,
      );
    });
  });
}

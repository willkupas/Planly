import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planly/features/tasks/data/firestore_task_repository.dart';
import 'package:planly/features/tasks/domain/task_models.dart';

const _scope = TaskScope('f1', 'h1');
const _actor = TaskActor(uid: 'u1', name: 'Teste');

void main() {
  late FakeFirebaseFirestore db;
  late FirestoreTaskRepository repo;

  CollectionReference<Map<String, dynamic>> tasks() =>
      db.collection('families/f1/households/h1/tasks');
  CollectionReference<Map<String, dynamic>> activity() =>
      db.collection('families/f1/households/h1/activity');

  Future<Map<String, dynamic>> taskDoc(String id) async => (await tasks().doc(id).get()).data()!;

  Future<List<String>> activityTypes() async =>
      (await activity().get()).docs.map((d) => d.data()['type'] as String).toList()..sort();

  setUp(() {
    db = FakeFirebaseFirestore();
    repo = FirestoreTaskRepository(firestore: db);
  });

  group('criação', () {
    test('tarefa rápida grava exatamente as chaves que as Rules exigem + activity no mesmo batch', () async {
      final w = repo.create(
        _scope,
        const TaskDraft(title: '  Lavar louça  ', assignedTo: 'u1'),
        _actor,
      );
      await w.ack;

      final d = await taskDoc(w.id);
      // Rules: hasOnly(...) e hasAll(...) sem `description` (vazia => omitida).
      expect(
        d.keys.toSet(),
        {
          'title', 'createdBy', 'assignedTo', 'status', 'schedule', 'recurrence', 'notification',
          'completedAt', 'completedBy', 'deletedAt', 'createdAt', 'updatedAt', 'schemaVersion',
        },
      );
      expect(d['title'], 'Lavar louça');
      expect(d['createdBy'], 'u1');
      expect(d['assignedTo'], 'u1');
      expect(d['status'], 'pending');
      expect(d['schedule'], isNull);
      expect(d['recurrence'], isNull);
      expect(d['notification'], {'enabled': false, 'offsetMinutes': 0});
      expect(d['completedAt'], isNull);
      expect(d['completedBy'], isNull);
      expect(d['deletedAt'], isNull);
      expect(d['schemaVersion'], 1);
      expect(d['createdAt'], isA<Timestamp>());
      expect(d['updatedAt'], isA<Timestamp>());

      final a = (await activity().get()).docs.single.data();
      expect(a['type'], 'task_created');
      expect(a['targetType'], 'task');
      expect(a['targetId'], w.id);
      expect(a['targetTitle'], 'Lavar louça');
      expect(a['actorId'], 'u1');
      expect(a['actorName'], 'Teste');
    });

    test('com agenda, responsável nulo, descrição e notificação', () async {
      final at = DateTime.utc(2026, 3, 1, 11, 30);
      final w = repo.create(
        _scope,
        TaskDraft(
          title: 'Reunião',
          description: 'Levar documentos',
          schedule: TaskSchedule(scheduledAt: at, timezone: 'America/Sao_Paulo'),
          notification: const TaskNotification(enabled: true, offsetMinutes: 15),
        ),
        _actor,
      );
      await w.ack;
      final d = await taskDoc(w.id);
      expect(d['description'], 'Levar documentos');
      expect(d['assignedTo'], isNull);
      final s = d['schedule'] as Map<String, dynamic>;
      expect(s.keys.toSet(), {'type', 'scheduledAt', 'timezone'});
      expect(s['type'], 'datetime');
      expect((s['scheduledAt'] as Timestamp).toDate().toUtc(), at);
      expect(s['timezone'], 'America/Sao_Paulo');
      expect(d['notification'], {'enabled': true, 'offsetMinutes': 15});
    });

    test('id é gerado localmente (disponível antes do ack)', () {
      final w = repo.create(_scope, const TaskDraft(title: 'x'), _actor);
      expect(w.id, isNotEmpty);
    });
  });

  group('mutações', () {
    Future<Task> seed({String? assignedTo = 'u1', DateTime? at}) async {
      final w = repo.create(
        _scope,
        TaskDraft(
          title: 'Base',
          assignedTo: assignedTo,
          schedule: at == null ? null : TaskSchedule(scheduledAt: at, timezone: 'UTC'),
        ),
        _actor,
      );
      await w.ack;
      final snap = await repo.watchTask(_scope, w.id).first;
      await activity().get().then((s) async {
        for (final d in s.docs) {
          await d.reference.delete();
        }
      });
      return snap!;
    }

    test('concluir grava status/completedAt/completedBy/updatedAt e activity task_completed', () async {
      final t = await seed();
      await repo.complete(_scope, t, const TaskActor(uid: 'u2', name: 'Bia')).ack;
      final d = await taskDoc(t.id);
      expect(d['status'], 'done');
      expect(d['completedBy'], 'u2');
      expect(d['completedAt'], isA<Timestamp>());
      expect(await activityTypes(), ['task_completed']);
    });

    test('reabrir zera completedAt/completedBy e grava task_reopened', () async {
      final t = await seed();
      await repo.complete(_scope, t, _actor).ack;
      final done = (await repo.watchTask(_scope, t.id).first)!;
      await repo.reopen(_scope, done, _actor).ack;
      final d = await taskDoc(t.id);
      expect(d['status'], 'pending');
      expect(d['completedAt'], isNull);
      expect(d['completedBy'], isNull);
      expect(await activityTypes(), ['task_completed', 'task_reopened']);
    });

    test('soft delete: só deletedAt + updatedAt mudam; activity task_deleted', () async {
      final t = await seed();
      final before = await taskDoc(t.id);
      await repo.softDelete(_scope, t, _actor).ack;
      final after = await taskDoc(t.id);
      final changed = {
        for (final k in after.keys)
          if (after[k].toString() != before[k].toString()) k,
      };
      expect(changed, {'deletedAt', 'updatedAt'});
      expect(after['deletedAt'], isA<Timestamp>());
      expect(await activityTypes(), ['task_deleted']);
    });

    test('editar só o título: patch mínimo + task_updated (sem task_assigned)', () async {
      final t = await seed();
      await repo.update(_scope, t, const TaskDraft(title: 'Novo', assignedTo: 'u1'), _actor)!.ack;
      final d = await taskDoc(t.id);
      expect(d['title'], 'Novo');
      expect(d['assignedTo'], 'u1');
      expect(await activityTypes(), ['task_updated']);
    });

    test('mudar só o responsável: task_assigned (sem task_updated)', () async {
      final t = await seed();
      await repo.update(_scope, t, const TaskDraft(title: 'Base', assignedTo: 'u2'), _actor)!.ack;
      expect((await taskDoc(t.id))['assignedTo'], 'u2');
      expect(await activityTypes(), ['task_assigned']);
    });

    test('mudar responsável para "qualquer pessoa" grava null', () async {
      final t = await seed();
      await repo.update(_scope, t, const TaskDraft(title: 'Base'), _actor)!.ack;
      expect((await taskDoc(t.id))['assignedTo'], isNull);
      expect(await activityTypes(), ['task_assigned']);
    });

    test('mudar título e responsável: os dois tipos de activity', () async {
      final t = await seed();
      await repo.update(_scope, t, const TaskDraft(title: 'Outro', assignedTo: 'u3'), _actor)!.ack;
      expect(await activityTypes(), ['task_assigned', 'task_updated']);
    });

    test('agenda e notificação: grava map completo e limpa com null', () async {
      final t = await seed();
      final at = DateTime.utc(2026, 5, 2, 9);
      await repo
          .update(
            _scope,
            t,
            TaskDraft(
              title: 'Base',
              assignedTo: 'u1',
              schedule: TaskSchedule(scheduledAt: at, timezone: 'America/Sao_Paulo'),
              notification: const TaskNotification(enabled: true, offsetMinutes: 60),
            ),
            _actor,
          )!
          .ack;
      final d = await taskDoc(t.id);
      expect((d['schedule'] as Map)['timezone'], 'America/Sao_Paulo');
      expect(d['notification'], {'enabled': true, 'offsetMinutes': 60});

      final scheduled = (await repo.watchTask(_scope, t.id).first)!;
      expect(scheduled.schedule!.scheduledAt, at);
      await repo.update(_scope, scheduled, const TaskDraft(title: 'Base', assignedTo: 'u1'), _actor)!.ack;
      expect((await taskDoc(t.id))['schedule'], isNull);
    });

    test('sem mudanças: nenhuma escrita', () async {
      final t = await seed();
      expect(repo.update(_scope, t, const TaskDraft(title: 'Base', assignedTo: 'u1'), _actor), isNull);
      expect(await activityTypes(), isEmpty);
    });
  });

  group('queries', () {
    Future<void> put(String id, Map<String, Object?> extra) => tasks().doc(id).set({
          'title': id,
          'createdBy': 'u1',
          'assignedTo': null,
          'status': 'pending',
          'schedule': null,
          'recurrence': null,
          'notification': {'enabled': false, 'offsetMinutes': 0},
          'completedAt': null,
          'completedBy': null,
          'deletedAt': null,
          'schemaVersion': 1,
          ...extra,
        });

    Map<String, Object?> sched(DateTime utc) =>
        {'schedule': {'type': 'datetime', 'scheduledAt': Timestamp.fromDate(utc), 'timezone': 'UTC'}};

    test('agendadas: pendentes com data, ordenadas, sem apagadas/concluídas/sem data', () async {
      await put('b', sched(DateTime.utc(2026, 1, 2)));
      await put('a', sched(DateTime.utc(2026, 1, 1)));
      await put('done', {...sched(DateTime.utc(2026, 1, 1)), 'status': 'done'});
      await put('gone', {...sched(DateTime.utc(2026, 1, 1)), 'deletedAt': Timestamp.now()});
      await put('nodate', {});
      final snap = await repo.watchScheduled(_scope).first;
      expect(snap.items.map((t) => t.id), ['a', 'b']);
      expect(snap.items.first.schedule!.scheduledAt.isUtc, isTrue);
    });

    test('agendadas com filtro de responsável (minhas)', () async {
      await put('mine', {...sched(DateTime.utc(2026, 1, 1)), 'assignedTo': 'u1'});
      await put('other', {...sched(DateTime.utc(2026, 1, 1)), 'assignedTo': 'u2'});
      await put('anyone', sched(DateTime.utc(2026, 1, 1)));
      final snap = await repo.watchScheduled(_scope, assignedTo: 'u1').first;
      expect(snap.items.map((t) => t.id), ['mine']);
    });

    test('sem data: só pendentes com schedule null', () async {
      await put('n1', {});
      await put('n2', {'assignedTo': 'u1'});
      await put('dated', sched(DateTime.utc(2026, 1, 1)));
      await put('done', {'status': 'done'});
      final all = await repo.watchUnscheduled(_scope).first;
      expect(all.items.map((t) => t.id).toSet(), {'n1', 'n2'});
      final mine = await repo.watchUnscheduled(_scope, assignedTo: 'u1').first;
      expect(mine.items.map((t) => t.id), ['n2']);
    });

    test('concluídas recentes: mais recente primeiro e respeita o limit', () async {
      await put('old', {'status': 'done', 'completedAt': Timestamp.fromDate(DateTime.utc(2026, 1, 1)), 'completedBy': 'u1'});
      await put('new', {'status': 'done', 'completedAt': Timestamp.fromDate(DateTime.utc(2026, 2, 1)), 'completedBy': 'u1'});
      await put('mid', {'status': 'done', 'completedAt': Timestamp.fromDate(DateTime.utc(2026, 1, 15)), 'completedBy': 'u1'});
      await put('pending', {});
      final snap = await repo.watchRecentDone(_scope, limit: 2).first;
      expect(snap.items.map((t) => t.id), ['new', 'mid']);
      expect(snap.items.first.completedBy, 'u1');
    });

    test('watchTask devolve null para doc inexistente e mapeia campos', () async {
      expect(await repo.watchTask(_scope, 'nope').first, isNull);
      await put('x', {
        'description': 'd',
        'notification': {'enabled': true, 'offsetMinutes': 30},
        'assignedTo': 'u9',
      });
      final t = (await repo.watchTask(_scope, 'x').first)!;
      expect(t.description, 'd');
      expect(t.notification, const TaskNotification(enabled: true, offsetMinutes: 30));
      expect(t.assignedTo, 'u9');
      expect(t.isDone, isFalse);
    });
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:planly/features/reminders/application/reminder_reconciler.dart';
import 'package:planly/features/reminders/application/reminder_texts.dart';
import 'package:planly/features/reminders/domain/notification_gateway.dart';
import 'package:planly/features/reminders/domain/reminder_plan.dart';
import 'package:planly/features/tasks/domain/task_models.dart';

import 'support/fake_notifications.dart';
import 'support/harness.dart';

final _now = DateTime.utc(2026, 3, 10, 12);

Task _task(
  String id, {
  String title = 'Lavar louça',
  DateTime? at,
  int offset = 0,
  bool enabled = true,
  bool done = false,
  bool deleted = false,
  String? assignedTo,
}) =>
    Task(
      id: id,
      title: title,
      createdBy: 'u1',
      status: done ? TaskStatus.done : TaskStatus.pending,
      assignedTo: assignedTo,
      schedule: at == null ? null : TaskSchedule(scheduledAt: at, timezone: 'America/Sao_Paulo'),
      notification: TaskNotification(enabled: enabled, offsetMinutes: offset),
      deletedAt: deleted ? _now : null,
    );

List<ReminderPlan> _plans(List<Task> tasks, {String uid = 'u1', DateTime? now}) => computeReminderPlans(
      tasks: tasks,
      familyId: 'f1',
      householdId: 'h1',
      uid: uid,
      now: now ?? _now,
    );

void main() {
  group('computeReminderPlans', () {
    test('dispara offsetMinutes antes de scheduledAt, em UTC', () {
      final at = DateTime.utc(2026, 3, 10, 22);
      final p = _plans([_task('a', at: at, offset: 30)]).single;
      expect(p.fireAt, DateTime.utc(2026, 3, 10, 21, 30));
      expect(p.scheduledAt, at);
      expect(p.fireAt.isUtc, isTrue);
    });

    test('offset 0 dispara no horário; offset de 1 semana', () {
      final at = DateTime.utc(2026, 3, 20, 12);
      expect(_plans([_task('a', at: at)]).single.fireAt, at);
      expect(_plans([_task('a', at: at, offset: 10080)]).single.fireAt, DateTime.utc(2026, 3, 13, 12));
    });

    test('descarta o que já passou (disparo <= agora)', () {
      expect(_plans([_task('a', at: _now)]), isEmpty);
      expect(_plans([_task('a', at: DateTime.utc(2026, 3, 10, 12, 20), offset: 30)]), isEmpty);
      expect(_plans([_task('a', at: DateTime.utc(2026, 3, 10, 12, 31), offset: 30)]), hasLength(1));
    });

    test('ignora sem horário, sem notificação, concluídas e excluídas', () {
      final at = DateTime.utc(2026, 3, 11);
      expect(
        _plans([
          _task('sem-horario'),
          _task('desligada', at: at, enabled: false),
          _task('feita', at: at, done: true),
          _task('apagada', at: at, deleted: true),
        ]),
        isEmpty,
      );
    });

    test('só tarefas do usuário: atribuída a ele ou a qualquer pessoa', () {
      final at = DateTime.utc(2026, 3, 11);
      final ids = _plans([
        _task('minha', at: at, assignedTo: 'u1'),
        _task('livre', at: at),
        _task('dele', at: at, assignedTo: 'u2'),
      ]).map((p) => p.taskId);
      expect(ids, ['minha', 'livre']);
    });

    test('mudança de fuso não altera o instante (scheduledAt é UTC)', () {
      final a = TaskSchedule(scheduledAt: DateTime.utc(2026, 3, 11, 22), timezone: 'America/Sao_Paulo');
      final b = TaskSchedule(scheduledAt: DateTime.utc(2026, 3, 11, 22), timezone: 'Europe/Lisbon');
      Task t(TaskSchedule s) => Task(
            id: 'x',
            title: 'x',
            createdBy: 'u1',
            status: TaskStatus.pending,
            schedule: s,
            notification: const TaskNotification(enabled: true, offsetMinutes: 15),
          );
      expect(_plans([t(a)]).single.fireAt, _plans([t(b)]).single.fireAt);
    });

    test('título é limitado e normalizado', () {
      final long = 'a' * 200;
      final p = _plans([_task('a', at: DateTime.utc(2026, 3, 11), title: '  $long  ')]).single;
      expect(p.title.length, ReminderPlan.maxTitleLength);
      expect(p.title.endsWith('…'), isTrue);
      final two = _plans([_task('a', at: DateTime.utc(2026, 3, 11), title: 'a\n  b')]).single;
      expect(two.title, 'a b');
    });

    test('id da notificação é determinístico, positivo e distinto', () {
      expect(reminderNotificationId('abc'), reminderNotificationId('abc'));
      expect(reminderNotificationId('abc'), isNot(reminderNotificationId('abd')));
      for (final id in ['abc', 'Zx81qL0pWn3kT9', '', 'ção']) {
        expect(reminderNotificationId(id), inInclusiveRange(0, 0x7fffffff));
      }
    });
  });

  group('ReminderPayload', () {
    test('ida e volta só com ids', () {
      const p = ReminderPayload(familyId: 'f1', householdId: 'h1', taskId: 't9');
      final raw = p.encode();
      expect(raw, 'planly://task/t9?f=f1&h=h1');
      expect(ReminderPayload.parse(raw), p);
    });

    test('rejeita payloads inválidos', () {
      for (final raw in [
        null,
        '',
        'lixo',
        'https://task/t9?f=f1&h=h1',
        'planly://task/t9',
        'planly://task/t9?f=f1',
        'planly://task/?f=f1&h=h1',
        'planly://other/t9?f=f1&h=h1',
        'planly://task/a/b?f=f1&h=h1',
      ]) {
        expect(ReminderPayload.parse(raw), isNull, reason: '$raw');
      }
    });
  });

  group('ReminderReconciler', () {
    late FakeNotificationGateway gw;
    var now = _now;
    late ReminderReconciler rec;

    setUp(() {
      gw = FakeNotificationGateway();
      now = _now;
      rec = ReminderReconciler(gateway: gw, texts: FakeReminderTexts(), clock: () => now);
    });

    final at = DateTime.utc(2026, 3, 11, 10);

    test('agenda novos com id, título, payload e instante UTC', () async {
      await rec.reconcile(_plans([_task('a', at: at, offset: 60)]));
      final r = gw.scheduled.values.single;
      expect(r.id, reminderNotificationId('a'));
      expect(r.title, 'Lavar louça');
      expect(r.fireAtUtc, DateTime.utc(2026, 3, 11, 9));
      expect(ReminderPayload.parse(r.payload)?.taskId, 'a');
    });

    test('é idempotente: repetir não reagenda', () async {
      final plans = _plans([_task('a', at: at), _task('b', at: at.add(const Duration(hours: 1)))]);
      await rec.reconcile(plans);
      await rec.reconcile(plans);
      await rec.reconcile(_plans([_task('a', at: at), _task('b', at: at.add(const Duration(hours: 1)))]));
      expect(gw.scheduleCalls, hasLength(2));
      expect(gw.cancelCalls, isEmpty);
    });

    test('reagenda ao mudar horário, offset ou título', () async {
      await rec.reconcile(_plans([_task('a', at: at)]));
      await rec.reconcile(_plans([_task('a', at: at.add(const Duration(hours: 2)))]));
      await rec.reconcile(_plans([_task('a', at: at.add(const Duration(hours: 2)), offset: 10)]));
      await rec.reconcile(_plans([_task('a', at: at.add(const Duration(hours: 2)), offset: 10, title: 'Novo')]));
      expect(gw.scheduleCalls, hasLength(4));
      expect(gw.scheduled, hasLength(1));
      expect(gw.scheduled.values.single.title, 'Novo');
      expect(gw.cancelCalls, isEmpty); // mesmo id: o agendamento é substituído
    });

    test('cancela concluída, excluída, reatribuída e sem notificação', () async {
      Future<void> run(List<Task> tasks) => rec.reconcile(_plans(tasks));
      final all = [
        _task('done', at: at),
        _task('del', at: at),
        _task('re', at: at),
        _task('off', at: at),
        _task('keep', at: at),
      ];
      await run(all);
      expect(gw.scheduled, hasLength(5));

      await run([
        _task('done', at: at, done: true),
        _task('del', at: at, deleted: true),
        _task('re', at: at, assignedTo: 'u2'),
        _task('off', at: at, enabled: false),
        _task('keep', at: at),
      ]);
      expect(gw.scheduled.keys, [reminderNotificationId('keep')]);
      expect(gw.cancelCalls.toSet(), {
        for (final id in ['done', 'del', 're', 'off']) reminderNotificationId(id),
      });
    });

    test('descarta no passado (relógio avança) e nunca agenda no passado', () async {
      await rec.reconcile(_plans([_task('a', at: at)]));
      now = DateTime.utc(2026, 3, 11, 10, 0, 1);
      await rec.reconcile(_plans([_task('a', at: at)], now: DateTime.utc(2026, 3, 11)));
      expect(gw.scheduled, isEmpty);
      expect(gw.cancelCalls, [reminderNotificationId('a')]);
    });

    test('cancelAll limpa tudo (logout / lembretes desligados)', () async {
      await rec.reconcile(_plans([_task('a', at: at), _task('b', at: at)]));
      await rec.cancelAll();
      expect(gw.scheduled, isEmpty);
    });

    test('após reinício do app cancela o que sobrou no sistema e reagenda o desejado', () async {
      final stale = reminderNotificationId('velha');
      gw.scheduled[stale] = ScheduledReminder(id: stale, title: 'x', body: 'y', fireAtUtc: at, payload: 'p');
      await rec.reconcile(_plans([_task('a', at: at)]));
      expect(gw.cancelCalls, [stale]);
      expect(gw.scheduled.keys, [reminderNotificationId('a')]);
    });

    test('falha do plugin não derruba e tenta de novo na próxima', () async {
      gw.failSchedule = true;
      await rec.reconcile(_plans([_task('a', at: at)]));
      expect(gw.scheduled, isEmpty);
      gw.failSchedule = false;
      await rec.reconcile(_plans([_task('a', at: at)]));
      expect(gw.scheduled, hasLength(1));
    });

    test('chamadas concorrentes são serializadas (vence a última)', () async {
      final f1 = rec.reconcile(_plans([_task('a', at: at)]));
      final f2 = rec.reconcile(const []);
      await Future.wait([f1, f2]);
      expect(gw.scheduled, isEmpty);
    });
  });

  group('L10nReminderTexts.body', () {
    final texts = L10nReminderTexts();

    test('hoje, amanhã e data', () {
      final s = DateTime(2026, 3, 10, 19).toUtc();
      expect(texts.body(s, DateTime(2026, 3, 10, 18, 30).toUtc()), 'Hoje às 19:00');
      expect(texts.body(s, DateTime(2026, 3, 9, 19).toUtc()), 'Amanhã às 19:00');
      expect(texts.body(s, DateTime(2026, 3, 3, 19).toUtc()), '10/03 às 19:00');
    });
  });

  group('integração com o app', () {
    final future = DateTime.utc(2030, 1, 1, 15);

    Future<TestApp> seeded(List<Task> tasks) async {
      final app = await TestApp.create();
      app.backend.seedOwnerFree();
      tasks.forEach(app.tasks.seed);
      return app;
    }

    testWidgets('agenda ao abrir e cancela ao concluir / excluir', (tester) async {
      final app = await seeded([
        _task('a', at: future, offset: 15),
        _task('b', at: future),
        _task('sem', at: future, enabled: false),
      ]);
      await app.pump(tester, now: _now);

      final gw = app.notifications;
      expect(gw.scheduled.keys.toSet(), {reminderNotificationId('a'), reminderNotificationId('b')});
      expect(gw.initCalls, greaterThan(0));

      // Concluir e excluir por fora do fluxo de UI: o stream reconcilia.
      app.tasks.seed(_task('a', at: future, offset: 15, done: true));
      app.tasks.seed(_task('b', at: future, deleted: true));
      await tester.pumpAndSettle();
      expect(gw.scheduled, isEmpty);
    });

    testWidgets('toque na notificação abre a tarefa (mesma casa)', (tester) async {
      final app = await seeded([_task('a', at: future)]);
      await app.pump(tester, now: _now);

      app.notifications.tap(const ReminderPayload(familyId: 'f1', householdId: 'h1', taskId: 'a').encode());
      await tester.pumpAndSettle();

      final ctx = tester.element(find.byType(Scaffold).first);
      expect(GoRouter.of(ctx).state.matchedLocation, '/home/task/a');
      expect(find.text('Lavar louça'), findsWidgets);
    });

    testWidgets('payload inválido é ignorado', (tester) async {
      final app = await seeded(const []);
      await app.pump(tester, now: _now);
      app.notifications.tap('planly://task/x');
      await tester.pumpAndSettle();
      final ctx = tester.element(find.byType(Scaffold).first);
      expect(GoRouter.of(ctx).state.matchedLocation, '/home');
    });
  });

  group('Configurações > Lembretes', () {
    Future<TestApp> openSettings(WidgetTester tester, {NotificationPermission perm = NotificationPermission.granted}) async {
      final app = await TestApp.create();
      app.backend.seedOwnerFree();
      app.notifications.permissionState = perm;
      await app.pump(tester, now: _now);
      await tester.tap(find.byKey(const Key('open-settings')));
      await tester.pumpAndSettle();
      return app;
    }

    testWidgets('permitido: mostra estado e o switch liga/desliga e persiste', (tester) async {
      final app = await openSettings(tester);
      expect(find.text('Lembretes'), findsOneWidget);
      expect(find.text('Notificações permitidas'), findsOneWidget);
      expect(find.byKey(const Key('reminders-allow')), findsNothing);

      await tester.ensureVisible(find.byKey(const Key('reminders-switch')));
      await tester.tap(find.byKey(const Key('reminders-switch')));
      await tester.pumpAndSettle();
      expect(app.prefs.getBool('reminders.enabled'), isFalse);
    });

    testWidgets('negado: explica antes de pedir; conceder atualiza o estado', (tester) async {
      final app = await openSettings(tester, perm: NotificationPermission.denied);
      expect(find.text('Notificações bloqueadas'), findsOneWidget);

      await tester.ensureVisible(find.byKey(const Key('reminders-allow')));
      await tester.tap(find.byKey(const Key('reminders-allow')));
      await tester.pumpAndSettle();
      expect(find.text('Permitir notificações?'), findsOneWidget);
      expect(app.notifications.requestCalls, 0); // nada pedido antes da explicação

      await tester.tap(find.text('Continuar'));
      await tester.pumpAndSettle();
      expect(app.notifications.requestCalls, 1);
      expect(find.text('Notificações permitidas'), findsOneWidget);
    });

    testWidgets('negado de novo: passa a oferecer os ajustes do sistema, sem quebrar', (tester) async {
      final app = await openSettings(tester, perm: NotificationPermission.denied);
      app.notifications.requestResult = NotificationPermission.denied;

      await tester.ensureVisible(find.byKey(const Key('reminders-allow')));
      await tester.tap(find.byKey(const Key('reminders-allow')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Continuar'));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('reminders-allow')), findsNothing);
      await tester.ensureVisible(find.byKey(const Key('reminders-open-settings')));
      await tester.tap(find.byKey(const Key('reminders-open-settings')));
      await tester.pumpAndSettle();
      expect(app.notifications.openSettingsCalls, 1);
      expect(tester.takeException(), isNull);
    });
  });
}

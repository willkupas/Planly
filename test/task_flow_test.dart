import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planly/core/error/app_failure.dart';
import 'package:planly/features/family/domain/family_models.dart';
import 'package:planly/features/household/domain/household_models.dart';
import 'package:planly/features/tasks/domain/task_models.dart';

import 'support/fake_backend.dart';
import 'support/harness.dart';

// "Agora" em horário LOCAL do aparelho: "Hoje/Próximas" não dependem do fuso da máquina.
final _now = DateTime(2026, 1, 15, 12);
final _today = DateTime(2026, 1, 15, 18).toUtc();
final _overdue = DateTime(2026, 1, 14, 9).toUtc();
final _tomorrow = DateTime(2026, 1, 16, 9).toUtc();

Task _task(
  String id, {
  String? title,
  String createdBy = 'u1',
  String? assignedTo,
  DateTime? at,
  bool done = false,
  String? completedBy,
  DateTime? completedAt,
}) =>
    Task(
      id: id,
      title: title ?? 'Tarefa $id',
      createdBy: createdBy,
      assignedTo: assignedTo,
      status: done ? TaskStatus.done : TaskStatus.pending,
      schedule: at == null ? null : TaskSchedule(scheduledAt: at, timezone: 'America/Sao_Paulo'),
      completedBy: done ? (completedBy ?? 'u1') : null,
      completedAt: done ? (completedAt ?? DateTime.utc(2026, 1, 15, 10)) : null,
      createdAt: DateTime.utc(2026, 1, 10),
    );

Future<TestApp> _ownerApp({List<Task> tasks = const []}) async {
  final app = await TestApp.create();
  app.backend
    ..seedOwnerFree()
    ..householdsLive('f1').set(HouseholdsSnapshot([
      Household(id: 'h1', name: 'Minha casa', access: const {uidMember: HouseholdRole.member}),
    ]))
    ..membersLive('f1').set(const [
      FamilyMember(uid: uidOwner, role: FamilyRole.owner, displayName: 'Teste'),
      FamilyMember(uid: uidMember, role: FamilyRole.member, displayName: 'Beto'),
    ]);
  tasks.forEach(app.tasks.seed);
  return app;
}

/// u1 é membro (não owner) da família `f2` da Ana; papel na casa configurável.
Future<TestApp> _memberApp({
  HouseholdRole role = HouseholdRole.member,
  List<Task> tasks = const [],
}) async {
  final app = await TestApp.create();
  app.backend
    ..profile.set(freeProfile)
    ..memberships.set([membership('f2', role: FamilyRole.member, plan: PlanId.family)])
    ..familyLive('f2').set(family('f2', plan: PlanId.family, ownerId: 'ana', members: 3))
    ..entitlementLive('f2').set(familyEntitlement)
    ..householdsLive('f2').set(HouseholdsSnapshot([
      Household(id: 'h2', name: 'Casa da Ana', access: {uidOwner: role, 'u3': HouseholdRole.member}),
    ]))
    ..membersLive('f2').set(const [
      FamilyMember(uid: 'ana', role: FamilyRole.owner, displayName: 'Ana'),
      FamilyMember(uid: uidOwner, role: FamilyRole.member, displayName: 'Teste'),
      FamilyMember(uid: 'u3', role: FamilyRole.member, displayName: 'Carlos'),
    ]);
  tasks.forEach(app.tasks.seed);
  return app;
}

Finder _check(String id) => find.byKey(Key('task-check-$id'));

bool _checkEnabled(WidgetTester tester, String id) => tester.widget<Checkbox>(_check(id)).onChanged != null;

Future<void> _openTask(WidgetTester tester, String id) async {
  await tester.tap(find.byKey(Key('task-$id')));
  await tester.pumpAndSettle();
}

void main() {
  group('criar tarefa rápida', () {
    _test('+ -> texto -> ✓ em 2 toques: pending, sem agenda, responsável = eu, offline-first',
        (tester) async {
      final app = await _ownerApp();
      await app.pump(tester, now: _now);
      expect(find.text('Nenhuma tarefa por aqui'), findsOneWidget);

      await tester.tap(find.byKey(const Key('fab-add-task'))); // toque 1
      await tester.pumpAndSettle();
      // campo já focado: digitar direto
      await tester.enterText(find.byKey(const Key('quick-add-field')), 'Comprar pão');
      await tester.pump();
      await tester.tap(find.byKey(const Key('quick-add-submit'))); // toque 2
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('quick-add-field')), findsNothing); // sheet fechou
      final t = app.tasks.tasks.values.single;
      expect(t.title, 'Comprar pão');
      expect(t.status, TaskStatus.pending);
      expect(t.schedule, isNull);
      expect(t.assignedTo, uidOwner);
      expect(t.createdBy, uidOwner);
      expect(t.notification, TaskNotification.off);
      expect(app.tasks.activity, [('task_created', t.id)]);
      expect(app.tasks.scopes.every((s) => s == const TaskScope('f1', 'h1')), isTrue);
      // aparece na seção "Sem data"
      expect(find.text('Comprar pão'), findsOneWidget);
      expect(find.text('Sem data'), findsOneWidget);
    });

    _test('teclado "ok" também envia; título vazio não envia', (tester) async {
      final app = await _ownerApp();
      await app.pump(tester, now: _now);
      await tester.tap(find.byKey(const Key('fab-add-task')));
      await tester.pumpAndSettle();
      expect(tester.widget<IconButton>(find.byKey(const Key('quick-add-submit'))).onPressed, isNull);
      await tester.enterText(find.byKey(const Key('quick-add-field')), '   ');
      await tester.pump();
      expect(tester.widget<IconButton>(find.byKey(const Key('quick-add-submit'))).onPressed, isNull);

      await tester.enterText(find.byKey(const Key('quick-add-field')), 'Varrer');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      expect(app.tasks.tasks.values.single.title, 'Varrer');
    });

    _test('"Mais opções": descrição, data/hora (UTC + IANA), responsável e notificar',
        (tester) async {
      final app = await _ownerApp();
      await app.pump(tester, now: _now);
      await tester.tap(find.byKey(const Key('fab-add-task')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('quick-add-field')), 'Reunião da escola');
      await tester.pump();
      await tester.tap(find.byKey(const Key('quick-add-more')));
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(const Key('task-description')), 'Levar documentos');

      // notificar exige data
      expect(tester.widget<SwitchListTile>(find.byKey(const Key('task-notify'))).onChanged, isNull);
      await tester.tap(find.byKey(const Key('task-date')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('OK')); // data (hoje)
      await tester.pumpAndSettle();
      await tester.tap(find.text('OK')); // hora sugerida
      await tester.pumpAndSettle();
      expect(find.text('Sem data'), findsNothing);

      await tester.tap(find.byKey(const Key('task-notify')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('task-notify-offset')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('1 hora antes').last);
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('task-assignee')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Beto').last);
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('quick-add-submit')));
      await tester.pumpAndSettle();

      final t = app.tasks.tasks.values.single;
      expect(t.title, 'Reunião da escola');
      expect(t.description, 'Levar documentos');
      expect(t.assignedTo, uidMember);
      expect(t.schedule, isNotNull);
      expect(t.schedule!.scheduledAt.isUtc, isTrue);
      expect(t.schedule!.timezone, 'America/Sao_Paulo'); // do aparelho (override do harness)
      final local = t.schedule!.scheduledAt.toLocal();
      expect((local.year, local.month, local.day), (2026, 1, 15));
      expect(t.notification, const TaskNotification(enabled: true, offsetMinutes: 60));
    });

    _test('responsável "Qualquer pessoa" grava assignedTo null e lista só membros com acesso',
        (tester) async {
      final app = await _ownerApp();
      app.backend.membersLive('f1').set(const [
        FamilyMember(uid: uidOwner, role: FamilyRole.owner, displayName: 'Teste'),
        FamilyMember(uid: uidMember, role: FamilyRole.member, displayName: 'Beto'),
        FamilyMember(uid: 'u9', role: FamilyRole.member, displayName: 'Sem acesso'),
      ]);
      await app.pump(tester, now: _now);
      await tester.tap(find.byKey(const Key('fab-add-task')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('quick-add-field')), 'Qualquer um');
      await tester.pump();
      await tester.tap(find.byKey(const Key('quick-add-more')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('task-assignee')));
      await tester.pumpAndSettle();
      expect(find.text('Teste (você)'), findsWidgets); // owner atribuível
      expect(find.text('Beto'), findsOneWidget);
      expect(find.text('Sem acesso'), findsNothing);
      await tester.tap(find.text('Qualquer pessoa').last);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('quick-add-submit')));
      await tester.pumpAndSettle();
      expect(app.tasks.tasks.values.single.assignedTo, isNull);
    });

    _test('offline: cria sem ensureOnline, fecha a sheet e mostra ícone de pendente',
        (tester) async {
      final app = await _ownerApp();
      app.tasks.offline = true;
      await app.pump(tester, startOnline: false, now: _now);
      expect(find.text('Sem conexão — alterações ficam salvas neste dispositivo'), findsOneWidget);

      await tester.tap(find.byKey(const Key('fab-add-task')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('quick-add-field')), 'Sem internet');
      await tester.pump();
      await tester.tap(find.byKey(const Key('quick-add-submit')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('quick-add-field')), findsNothing);
      final t = app.tasks.tasks.values.single;
      expect(find.byKey(Key('task-pending-${t.id}')), findsOneWidget);
      expect(find.text('Salvo neste dispositivo'), findsOneWidget);
    });

    _test('servidor recusa depois (Rules): mensagem amigável, sem travar a UI', (tester) async {
      final app = await _ownerApp();
      app.tasks.ackFailure = const PermissionDeniedFailure();
      await app.pump(tester, now: _now);
      await tester.tap(find.byKey(const Key('fab-add-task')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('quick-add-field')), 'Vai falhar');
      await tester.pump();
      await tester.tap(find.byKey(const Key('quick-add-submit')));
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pumpAndSettle();

      expect(find.text('Você não tem permissão para fazer isso.'), findsOneWidget);
      await tester.pump(const Duration(seconds: 5)); // snackbar some
      await tester.pumpAndSettle();
      // a UI segue usável: novo toque no FAB abre a sheet
      await tester.tap(find.byKey(const Key('fab-add-task')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('quick-add-field')), findsOneWidget);
    });
  });

  group('dashboard', () {
    _test('seções Hoje (com atrasadas) / Próximas / Sem data / Concluídas recentes', (tester) async {
      final app = await _ownerApp(tasks: [
        _task('hoje', title: 'Tarefa de hoje', at: _today),
        _task('atrasada', title: 'Tarefa atrasada', at: _overdue),
        _task('amanha', title: 'Tarefa de amanhã', at: _tomorrow),
        _task('semdata', title: 'Tarefa sem data'),
        _task('feita', title: 'Tarefa feita', done: true),
      ]);
      await app.pump(tester, now: _now);

      Finder inSection(String key, String text) =>
          find.descendant(of: find.byKey(Key(key)), matching: find.text(text));
      expect(inSection('section-today', 'Tarefa de hoje'), findsOneWidget);
      expect(inSection('section-today', 'Tarefa atrasada'), findsOneWidget);
      expect(find.textContaining('Atrasada ·'), findsOneWidget);
      expect(inSection('section-upcoming', 'Tarefa de amanhã'), findsOneWidget);
      expect(inSection('section-unscheduled', 'Tarefa sem data'), findsOneWidget);
      expect(inSection('section-done', 'Tarefa feita'), findsOneWidget);
      // listas continuam placeholder (outro agente)
      expect(find.text('Listas'), findsWidgets);
    });

    _test('toggle "Minhas": só as atribuídas a mim (consulta filtrada no repositório)',
        (tester) async {
      final app = await _ownerApp(tasks: [
        _task('minha', title: 'Minha tarefa', assignedTo: uidOwner),
        _task('dele', title: 'Tarefa do Beto', assignedTo: uidMember),
        _task('minha-data', title: 'Minha com data', assignedTo: uidOwner, at: _today),
        _task('dele-data', title: 'Beto com data', assignedTo: uidMember, at: _today),
        _task('dele-feita', title: 'Feita do Beto', assignedTo: uidMember, done: true),
        _task('minha-feita', title: 'Minha feita', assignedTo: uidOwner, done: true),
      ]);
      await app.pump(tester, now: _now);
      expect(find.text('Tarefa do Beto'), findsOneWidget);

      await tester.tap(find.byKey(const Key('filter-mine')));
      await tester.pumpAndSettle();
      expect(find.text('Minha tarefa'), findsOneWidget);
      expect(find.text('Minha com data'), findsOneWidget);
      expect(find.text('Minha feita'), findsOneWidget);
      expect(find.text('Tarefa do Beto'), findsNothing);
      expect(find.text('Beto com data'), findsNothing);
      expect(find.text('Feita do Beto'), findsNothing);

      await tester.tap(find.byKey(const Key('filter-all')));
      await tester.pumpAndSettle();
      expect(find.text('Tarefa do Beto'), findsOneWidget);
    });

    _test('estado Empty no filtro "Minhas"', (tester) async {
      final app = await _ownerApp(tasks: [_task('dele', assignedTo: uidMember)]);
      await app.pump(tester, now: _now);
      await tester.tap(find.byKey(const Key('filter-mine')));
      await tester.pumpAndSettle();
      expect(find.text('Nenhuma tarefa sua por enquanto.'), findsOneWidget);
    });

    _test('estado Error com "Tentar de novo"', (tester) async {
      final app = await _ownerApp();
      app.tasks.streamError = const UnknownFailure();
      await app.pump(tester, now: _now);
      expect(find.text('Algo deu errado. Tente de novo.'), findsOneWidget);
      app.tasks.streamError = null;
      await tester.tap(find.text('Tentar de novo'));
      await tester.pumpAndSettle();
      expect(find.text('Nenhuma tarefa por aqui'), findsOneWidget);
    });

    _test('concluir e reabrir pelo checkbox, com activity', (tester) async {
      final app = await _ownerApp(tasks: [_task('a', title: 'Lavar roupa', assignedTo: uidOwner)]);
      await app.pump(tester, now: _now);

      await tester.tap(_check('a'));
      await tester.pumpAndSettle();
      var t = app.tasks.tasks['a']!;
      expect(t.status, TaskStatus.done);
      expect(t.completedBy, uidOwner);
      expect(t.completedAt, isNotNull);
      expect(app.tasks.activity, [('task_completed', 'a')]);
      expect(find.descendant(of: find.byKey(const Key('section-done')), matching: find.text('Lavar roupa')),
          findsOneWidget);

      await tester.tap(_check('a'));
      await tester.pumpAndSettle();
      t = app.tasks.tasks['a']!;
      expect(t.status, TaskStatus.pending);
      expect(t.completedAt, isNull);
      expect(t.completedBy, isNull);
      expect(app.tasks.activity, [('task_completed', 'a'), ('task_reopened', 'a')]);
    });
  });

  group('detalhe/edição', () {
    _test('editar título, descrição e responsável: salva só o que mudou', (tester) async {
      final app = await _ownerApp(tasks: [_task('a', title: 'Original', assignedTo: uidOwner)]);
      await app.pump(tester, now: _now);
      await _openTask(tester, 'a');
      expect(find.byKey(const Key('task-detail-content')), findsOneWidget);
      expect(find.byKey(const Key('task-save')), findsNothing); // sem mudanças

      await tester.enterText(find.byKey(const Key('task-title')), 'Editada');
      await tester.enterText(find.byKey(const Key('task-description')), 'Detalhes');
      await tester.pump();
      await tester.tap(find.byKey(const Key('task-assignee')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Beto').last);
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const Key('task-save')));
      await tester.tap(find.byKey(const Key('task-save')));
      await tester.pumpAndSettle();

      final t = app.tasks.tasks['a']!;
      expect(t.title, 'Editada');
      expect(t.description, 'Detalhes');
      expect(t.assignedTo, uidMember);
      expect(app.tasks.activity, [('task_updated', 'a'), ('task_assigned', 'a')]);
      expect(find.text('Alterações salvas.'), findsOneWidget);
      expect(find.byKey(const Key('task-save')), findsNothing); // não está mais "sujo"
    });

    _test('título vazio desabilita o salvar', (tester) async {
      final app = await _ownerApp(tasks: [_task('a')]);
      await app.pump(tester, now: _now);
      await _openTask(tester, 'a');
      await tester.enterText(find.byKey(const Key('task-title')), '');
      await tester.pump();
      expect(tester.widget<FilledButton>(find.byKey(const Key('task-save'))).onPressed, isNull);
    });

    _test('concluir/reabrir pelo detalhe', (tester) async {
      final app = await _ownerApp(tasks: [_task('a', assignedTo: uidOwner)]);
      await app.pump(tester, now: _now);
      await _openTask(tester, 'a');
      await tester.ensureVisible(find.byKey(const Key('task-toggle-done')));
      await tester.tap(find.byKey(const Key('task-toggle-done')));
      await tester.pumpAndSettle();
      expect(app.tasks.tasks['a']!.isDone, isTrue);
      expect(find.text('Reabrir tarefa'), findsOneWidget);
      expect(find.text('Concluída por Teste'), findsOneWidget);
      await tester.tap(find.byKey(const Key('task-toggle-done')));
      await tester.pumpAndSettle();
      expect(app.tasks.tasks['a']!.isDone, isFalse);
    });

    _test('excluir: confirma, faz soft delete, activity task_deleted e volta ao dashboard',
        (tester) async {
      final app = await _ownerApp(tasks: [_task('a', title: 'Apagar isto')]);
      await app.pump(tester, now: _now);
      await _openTask(tester, 'a');
      await tester.tap(find.byKey(const Key('task-delete')));
      await tester.pumpAndSettle();
      expect(find.text('Excluir tarefa?'), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, 'Excluir tarefa'));
      await tester.pumpAndSettle();

      expect(app.tasks.tasks['a']!.isDeleted, isTrue);
      expect(app.tasks.activity, [('task_deleted', 'a')]);
      expect(find.byKey(const Key('dashboard-content')), findsOneWidget);
      expect(find.text('Apagar isto'), findsNothing);
      expect(find.text('Tarefa excluída.'), findsOneWidget);
    });

    _test('cancelar a confirmação não exclui', (tester) async {
      final app = await _ownerApp(tasks: [_task('a')]);
      await app.pump(tester, now: _now);
      await _openTask(tester, 'a');
      await tester.tap(find.byKey(const Key('task-delete')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();
      expect(app.tasks.tasks['a']!.isDeleted, isFalse);
    });

    _test('tarefa inexistente/excluída mostra "não encontrada"', (tester) async {
      final app = await _ownerApp(tasks: [_task('a')]);
      await app.pump(tester, now: _now);
      await _openTask(tester, 'a');
      app.tasks.seed(Task(
        id: 'a',
        title: 'x',
        createdBy: 'u1',
        status: TaskStatus.pending,
        deletedAt: DateTime.utc(2026, 1, 15),
      ));
      await tester.pumpAndSettle();
      expect(find.text('Tarefa não encontrada'), findsOneWidget);
    });
  });

  group('permissões (espelham as Rules)', () {
    _test('member: atribuída a mim, criada por outro -> só conclui/reabre', (tester) async {
      final app = await _memberApp(tasks: [
        _task('a', title: 'Da Ana para mim', createdBy: 'ana', assignedTo: uidOwner),
      ]);
      await app.pump(tester, now: _now);
      expect(_checkEnabled(tester, 'a'), isTrue);
      await _openTask(tester, 'a');
      expect(tester.widget<TextField>(find.byKey(const Key('task-title'))).enabled, isFalse);
      expect(tester.widget<TextField>(find.byKey(const Key('task-description'))).enabled, isFalse);
      expect(find.byKey(const Key('task-save')), findsNothing);
      expect(find.byKey(const Key('task-delete')), findsNothing);
      expect(find.byKey(const Key('task-read-only')), findsOneWidget);
      await tester.ensureVisible(find.byKey(const Key('task-toggle-done')));
      await tester.tap(find.byKey(const Key('task-toggle-done')));
      await tester.pumpAndSettle();
      expect(app.tasks.tasks['a']!.isDone, isTrue);
      expect(app.tasks.tasks['a']!.completedBy, uidOwner);
    });

    _test('member: atribuída a outro -> não conclui nem edita', (tester) async {
      final app = await _memberApp(tasks: [
        _task('a', createdBy: 'ana', assignedTo: 'u3'),
      ]);
      await app.pump(tester, now: _now);
      expect(_checkEnabled(tester, 'a'), isFalse);
      await _openTask(tester, 'a');
      expect(find.byKey(const Key('task-toggle-done')), findsNothing);
      expect(find.byKey(const Key('task-delete')), findsNothing);
      expect(tester.widget<TextField>(find.byKey(const Key('task-title'))).enabled, isFalse);
    });

    _test('member: "qualquer pessoa" (null) pode ser concluída', (tester) async {
      final app = await _memberApp(tasks: [_task('a', createdBy: 'ana')]);
      await app.pump(tester, now: _now);
      expect(_checkEnabled(tester, 'a'), isTrue);
      await tester.tap(_check('a'));
      await tester.pumpAndSettle();
      expect(app.tasks.tasks['a']!.isDone, isTrue);
    });

    _test('member: edita e exclui o que criou', (tester) async {
      final app = await _memberApp(tasks: [
        _task('a', title: 'Minha criação', createdBy: uidOwner, assignedTo: 'u3'),
      ]);
      await app.pump(tester, now: _now);
      await _openTask(tester, 'a');
      expect(tester.widget<TextField>(find.byKey(const Key('task-title'))).enabled, isTrue);
      expect(find.byKey(const Key('task-delete')), findsOneWidget);
      // autor pode concluir mesmo atribuída a outro (taskEdit das Rules)
      expect(find.byKey(const Key('task-toggle-done')), findsOneWidget);
    });

    _test('admin da casa: edita, exclui e conclui tarefa alheia', (tester) async {
      final app = await _memberApp(role: HouseholdRole.admin, tasks: [
        _task('a', createdBy: 'ana', assignedTo: 'u3'),
      ]);
      await app.pump(tester, now: _now);
      expect(_checkEnabled(tester, 'a'), isTrue);
      await _openTask(tester, 'a');
      expect(tester.widget<TextField>(find.byKey(const Key('task-title'))).enabled, isTrue);
      expect(find.byKey(const Key('task-delete')), findsOneWidget);
    });

    _test('owner: tudo, inclusive tarefa criada por outro', (tester) async {
      final app = await _ownerApp(tasks: [
        _task('a', createdBy: uidMember, assignedTo: uidMember),
      ]);
      await app.pump(tester, now: _now);
      expect(_checkEnabled(tester, 'a'), isTrue);
      await _openTask(tester, 'a');
      expect(tester.widget<TextField>(find.byKey(const Key('task-title'))).enabled, isTrue);
      expect(find.byKey(const Key('task-delete')), findsOneWidget);
    });

    _test('família frozen: sem FAB, sem checkbox, campos desabilitados, banner', (tester) async {
      final app = await _ownerApp(tasks: [_task('a', assignedTo: uidOwner)]);
      app.backend
        ..memberships.set([membership('f1', plan: PlanId.family, status: FamilyStatus.frozen)])
        ..familyLive('f1').set(family('f1',
            plan: PlanId.family, status: FamilyStatus.frozen, deleteAfter: _now.add(const Duration(days: 10))))
        ..entitlementLive('f1').set(familyEntitlement);
      await app.pump(tester, now: _now);

      expect(find.byKey(const Key('frozen-banner')), findsOneWidget);
      expect(find.byKey(const Key('fab-add-task')), findsNothing);
      expect(_checkEnabled(tester, 'a'), isFalse);
      await _openTask(tester, 'a');
      expect(find.byKey(const Key('frozen-banner')), findsOneWidget);
      expect(tester.widget<TextField>(find.byKey(const Key('task-title'))).enabled, isFalse);
      expect(find.byKey(const Key('task-delete')), findsNothing);
      expect(find.byKey(const Key('task-toggle-done')), findsNothing);
      expect(find.byKey(const Key('task-save')), findsNothing);
      expect(find.text('Família somente leitura: não é possível alterar tarefas.'), findsOneWidget);
    });
  });
}

/// Tela alta (800x1600): ListView preguiçoso só constrói o que cabe na viewport.
void _test(String name, Future<void> Function(WidgetTester tester) body) {
  testWidgets(name, (tester) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await body(tester);
  });
}

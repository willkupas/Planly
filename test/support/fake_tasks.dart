import 'dart:async';

import 'package:planly/core/error/app_failure.dart';
import 'package:planly/core/sync/sync_status.dart';
import 'package:planly/features/tasks/domain/task_models.dart';
import 'package:planly/features/tasks/domain/task_repository.dart';

/// Repositório de tarefas em memória para testes de widget/fluxo. Reproduz o efeito local
/// imediato das escritas e registra a atividade que o repositório real gravaria.
class FakeTasks implements TaskRepository {
  final tasks = <String, Task>{};

  /// `(type, targetId)` na ordem em que foram "gravadas" no batch.
  final activity = <(String, String)>[];

  /// Escopos consultados (para asserts de contexto).
  final scopes = <TaskScope>[];

  var _seq = 0;
  final _changes = StreamController<void>.broadcast();

  /// Horário "do servidor" usado em createdAt/completedAt.
  DateTime serverNow = DateTime.utc(2026, 1, 15, 12);

  /// Se true, escritas ficam pendentes (`hasPendingWrites`) e o ack não completa (offline).
  bool offline = false;

  /// Falha a entregar no ack das próximas escritas (Rules negando depois).
  AppFailure? ackFailure;

  /// Erro a emitir nos streams de lista.
  Object? streamError;

  void seed(Task t) {
    tasks[t.id] = t;
    _changes.add(null);
  }

  Stream<T> _live<T>(T Function() read) => Stream<T>.multi((ctl) {
        void emit() {
          final e = streamError;
          if (e != null) {
            ctl.addError(e);
          } else {
            ctl.add(read());
          }
        }

        emit();
        final sub = _changes.stream.listen((_) => emit());
        ctl.onCancel = sub.cancel;
      });

  TasksSnapshot _snap(Iterable<Task> items) => TasksSnapshot(
        items.toList(),
        SyncMeta(hasPendingWrites: items.any((t) => t.hasPendingWrites)),
      );

  Iterable<Task> _alive() => tasks.values.where((t) => !t.isDeleted);

  @override
  Stream<TasksSnapshot> watchScheduled(TaskScope scope, {String? assignedTo, int limit = 100}) {
    scopes.add(scope);
    return _live(() {
      final l = _alive()
          .where((t) => !t.isDone && t.schedule != null && (assignedTo == null || t.assignedTo == assignedTo))
          .toList()
        ..sort((a, b) => a.schedule!.scheduledAt.compareTo(b.schedule!.scheduledAt));
      return _snap(l.take(limit));
    });
  }

  @override
  Stream<TasksSnapshot> watchUnscheduled(TaskScope scope, {String? assignedTo, int limit = 50}) {
    scopes.add(scope);
    return _live(() => _snap(_alive()
        .where((t) => !t.isDone && t.schedule == null && (assignedTo == null || t.assignedTo == assignedTo))
        .take(limit)));
  }

  @override
  Stream<TasksSnapshot> watchRecentDone(TaskScope scope, {int limit = 20}) {
    scopes.add(scope);
    return _live(() {
      final l = _alive().where((t) => t.isDone).toList()
        ..sort((a, b) => (b.completedAt ?? serverNow).compareTo(a.completedAt ?? serverNow));
      return _snap(l.take(limit));
    });
  }

  @override
  Stream<Task?> watchTask(TaskScope scope, String taskId) => _live(() => tasks[taskId]);

  TaskWrite _write(String id, Task? next, List<(String, String)> log) {
    if (next != null) tasks[id] = next;
    activity.addAll(log);
    _changes.add(null);
    final Future<void> ack;
    if (offline) {
      ack = Completer<void>().future; // nunca confirma
    } else if (ackFailure != null) {
      final f = ackFailure!;
      ackFailure = null;
      // Rules recusaram: o efeito local é desfeito.
      ack = Future<void>.delayed(const Duration(milliseconds: 1)).then((_) => throw f);
    } else {
      ack = Future<void>.value();
    }
    return TaskWrite(id, ack);
  }

  @override
  TaskWrite create(TaskScope scope, TaskDraft draft, TaskActor actor) {
    final id = 't${++_seq}';
    final t = Task(
      id: id,
      title: draft.title.trim(),
      description: draft.description.trim(),
      createdBy: actor.uid,
      status: TaskStatus.pending,
      assignedTo: draft.assignedTo,
      schedule: draft.schedule,
      notification: draft.notification,
      createdAt: serverNow,
      updatedAt: serverNow,
      hasPendingWrites: offline,
    );
    return _write(id, t, [('task_created', id)]);
  }

  @override
  TaskWrite? update(TaskScope scope, Task before, TaskDraft draft, TaskActor actor) {
    final cur = tasks[before.id] ?? before;
    final otherChanged = draft.title.trim() != cur.title ||
        draft.description.trim() != cur.description ||
        draft.schedule != cur.schedule ||
        draft.notification != cur.notification;
    final assignedChanged = draft.assignedTo != cur.assignedTo;
    if (!otherChanged && !assignedChanged) return null;
    final next = Task(
      id: cur.id,
      title: draft.title.trim(),
      description: draft.description.trim(),
      createdBy: cur.createdBy,
      status: cur.status,
      assignedTo: draft.assignedTo,
      schedule: draft.schedule,
      notification: draft.notification,
      completedAt: cur.completedAt,
      completedBy: cur.completedBy,
      createdAt: cur.createdAt,
      updatedAt: serverNow,
      hasPendingWrites: offline,
    );
    return _write(cur.id, next, [
      if (otherChanged) ('task_updated', cur.id),
      if (assignedChanged) ('task_assigned', cur.id),
    ]);
  }

  Task _copy(Task t, {TaskStatus? status, DateTime? completedAt, String? completedBy, bool clear = false, DateTime? deletedAt}) =>
      Task(
        id: t.id,
        title: t.title,
        description: t.description,
        createdBy: t.createdBy,
        status: status ?? t.status,
        assignedTo: t.assignedTo,
        schedule: t.schedule,
        notification: t.notification,
        completedAt: clear ? null : (completedAt ?? t.completedAt),
        completedBy: clear ? null : (completedBy ?? t.completedBy),
        deletedAt: deletedAt ?? t.deletedAt,
        createdAt: t.createdAt,
        updatedAt: serverNow,
        hasPendingWrites: offline,
      );

  @override
  TaskWrite complete(TaskScope scope, Task task, TaskActor actor) => _write(
        task.id,
        _copy(tasks[task.id] ?? task, status: TaskStatus.done, completedAt: serverNow, completedBy: actor.uid),
        [('task_completed', task.id)],
      );

  @override
  TaskWrite reopen(TaskScope scope, Task task, TaskActor actor) => _write(
        task.id,
        _copy(tasks[task.id] ?? task, status: TaskStatus.pending, clear: true),
        [('task_reopened', task.id)],
      );

  @override
  TaskWrite softDelete(TaskScope scope, Task task, TaskActor actor) => _write(
        task.id,
        _copy(tasks[task.id] ?? task, deletedAt: serverNow),
        [('task_deleted', task.id)],
      );
}

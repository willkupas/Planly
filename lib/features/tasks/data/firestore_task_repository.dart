import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:planly/core/firebase/firebase_error_mapper.dart';
import 'package:planly/core/sync/sync_status.dart';
import 'package:planly/features/activity/data/activity_entry.dart';
import 'package:planly/features/tasks/domain/task_models.dart';
import 'package:planly/features/tasks/domain/task_repository.dart';

/// Tarefas em `families/{f}/households/{h}/tasks/{id}` (client-direct, protegido pelas Rules).
///
/// Queries sempre com `limit` (as Rules negam list sem `limit <= 100`) e só com os índices de
/// `firebase/firestore.indexes.json`:
/// - agendadas: `deletedAt ==`, `status ==`, `orderBy schedule.scheduledAt` (+ `assignedTo ==`);
/// - sem data: igualdades apenas (merge de índices simples);
/// - concluídas: `deletedAt ==`, `status ==`, `orderBy completedAt desc`.
class FirestoreTaskRepository implements TaskRepository {
  FirestoreTaskRepository({required FirebaseFirestore firestore}) : _db = firestore;

  final FirebaseFirestore _db;

  DocumentReference<Map<String, dynamic>> _household(TaskScope s) =>
      _db.collection('families').doc(s.familyId).collection('households').doc(s.householdId);

  CollectionReference<Map<String, dynamic>> _tasks(TaskScope s) => _household(s).collection('tasks');

  CollectionReference<Map<String, dynamic>> _activity(TaskScope s) => _household(s).collection('activity');

  int _clamp(int limit) => limit.clamp(1, 100);

  Query<Map<String, dynamic>> _pending(TaskScope s, String? assignedTo) {
    var q = _tasks(s).where('deletedAt', isNull: true);
    if (assignedTo != null) q = q.where('assignedTo', isEqualTo: assignedTo);
    return q.where('status', isEqualTo: TaskStatus.pending.wire);
  }

  Stream<TasksSnapshot> _snapshots(Query<Map<String, dynamic>> query, {bool Function(Task)? keep}) {
    return query.snapshots(includeMetadataChanges: true).map((snap) {
      final items = <Task>[];
      for (final d in snap.docs) {
        final t = _toTask(d.id, d.data(), hasPendingWrites: d.metadata.hasPendingWrites);
        if (t.isDeleted) continue;
        if (keep != null && !keep(t)) continue;
        items.add(t);
      }
      return TasksSnapshot(
        items,
        SyncMeta(hasPendingWrites: snap.metadata.hasPendingWrites, isFromCache: snap.metadata.isFromCache),
      );
    }).handleError((Object e) => throw mapFirebaseError(e));
  }

  @override
  Stream<TasksSnapshot> watchScheduled(TaskScope scope, {String? assignedTo, int limit = 100}) {
    return _snapshots(
      _pending(scope, assignedTo).orderBy('schedule.scheduledAt').limit(_clamp(limit)),
      keep: (t) => t.schedule != null,
    );
  }

  @override
  Stream<TasksSnapshot> watchUnscheduled(TaskScope scope, {String? assignedTo, int limit = 50}) {
    return _snapshots(
      _pending(scope, assignedTo).where('schedule', isNull: true).limit(_clamp(limit)),
      keep: (t) => t.schedule == null,
    );
  }

  @override
  Stream<TasksSnapshot> watchRecentDone(TaskScope scope, {int limit = 20}) {
    return _snapshots(
      _tasks(scope)
          .where('deletedAt', isNull: true)
          .where('status', isEqualTo: TaskStatus.done.wire)
          .orderBy('completedAt', descending: true)
          .limit(_clamp(limit)),
    );
  }

  @override
  Stream<Task?> watchTask(TaskScope scope, String taskId) {
    return _tasks(scope)
        .doc(taskId)
        .snapshots(includeMetadataChanges: true)
        .map((d) {
          final data = d.data();
          if (!d.exists || data == null) return null;
          return _toTask(d.id, data, hasPendingWrites: d.metadata.hasPendingWrites);
        })
        .handleError((Object e) => throw mapFirebaseError(e));
  }

  // ---------------------------------------------------------------------------
  // Escritas (tarefa + atividade no mesmo batch)
  // ---------------------------------------------------------------------------

  Map<String, Object?>? _scheduleMap(TaskSchedule? s) => s == null
      ? null
      : {
          'type': 'datetime',
          'scheduledAt': Timestamp.fromDate(s.scheduledAt.toUtc()),
          'timezone': s.timezone,
        };

  Map<String, Object?> _notificationMap(TaskNotification n) => {
        'enabled': n.enabled,
        'offsetMinutes': n.offsetMinutes,
      };

  /// Dispara o commit na hora (efeito local imediato) e devolve o ack do servidor.
  Future<void> _commit(WriteBatch batch) async {
    try {
      await batch.commit();
    } catch (e) {
      throw mapFirebaseError(e);
    }
  }

  void _log(WriteBatch b, TaskScope s, ActivityType type, TaskActor actor, String id, String title) {
    b.set(
      _activity(s).doc(),
      activityEntry(type: type, actorId: actor.uid, actorName: actor.name, targetId: id, targetTitle: title),
    );
  }

  @override
  TaskWrite create(TaskScope scope, TaskDraft draft, TaskActor actor) {
    final ref = _tasks(scope).doc(); // id local: funciona offline
    final title = draft.title.trim();
    final description = draft.description.trim();
    final batch = _db.batch();
    batch.set(ref, {
      'title': title,
      if (description.isNotEmpty) 'description': description,
      'createdBy': actor.uid,
      'assignedTo': draft.assignedTo,
      'status': TaskStatus.pending.wire,
      'schedule': _scheduleMap(draft.schedule),
      'recurrence': null,
      'notification': _notificationMap(draft.notification),
      'completedAt': null,
      'completedBy': null,
      'deletedAt': null,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'schemaVersion': 1,
    });
    _log(batch, scope, ActivityType.taskCreated, actor, ref.id, title);
    return TaskWrite(ref.id, _commit(batch));
  }

  @override
  TaskWrite? update(TaskScope scope, Task before, TaskDraft draft, TaskActor actor) {
    final title = draft.title.trim();
    final description = draft.description.trim();
    final patch = <String, Object?>{};
    var otherChanged = false;
    if (title != before.title) {
      patch['title'] = title;
      otherChanged = true;
    }
    if (description != before.description) {
      patch['description'] = description;
      otherChanged = true;
    }
    if (draft.schedule != before.schedule) {
      patch['schedule'] = _scheduleMap(draft.schedule);
      otherChanged = true;
    }
    if (draft.notification != before.notification) {
      patch['notification'] = _notificationMap(draft.notification);
      otherChanged = true;
    }
    final assignedChanged = draft.assignedTo != before.assignedTo;
    if (assignedChanged) patch['assignedTo'] = draft.assignedTo;
    if (patch.isEmpty) return null;

    patch['updatedAt'] = FieldValue.serverTimestamp();
    final batch = _db.batch();
    batch.update(_tasks(scope).doc(before.id), patch);
    if (otherChanged) _log(batch, scope, ActivityType.taskUpdated, actor, before.id, title);
    if (assignedChanged) _log(batch, scope, ActivityType.taskAssigned, actor, before.id, title);
    return TaskWrite(before.id, _commit(batch));
  }

  @override
  TaskWrite complete(TaskScope scope, Task task, TaskActor actor) {
    final batch = _db.batch();
    batch.update(_tasks(scope).doc(task.id), {
      'status': TaskStatus.done.wire,
      'completedAt': FieldValue.serverTimestamp(),
      'completedBy': actor.uid,
      'updatedAt': FieldValue.serverTimestamp(),
    });
    _log(batch, scope, ActivityType.taskCompleted, actor, task.id, task.title);
    return TaskWrite(task.id, _commit(batch));
  }

  @override
  TaskWrite reopen(TaskScope scope, Task task, TaskActor actor) {
    final batch = _db.batch();
    batch.update(_tasks(scope).doc(task.id), {
      'status': TaskStatus.pending.wire,
      'completedAt': null,
      'completedBy': null,
      'updatedAt': FieldValue.serverTimestamp(),
    });
    _log(batch, scope, ActivityType.taskReopened, actor, task.id, task.title);
    return TaskWrite(task.id, _commit(batch));
  }

  @override
  TaskWrite softDelete(TaskScope scope, Task task, TaskActor actor) {
    final batch = _db.batch();
    // Rules: só `deletedAt` + `updatedAt`.
    batch.update(_tasks(scope).doc(task.id), {
      'deletedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    _log(batch, scope, ActivityType.taskDeleted, actor, task.id, task.title);
    return TaskWrite(task.id, _commit(batch));
  }
}

DateTime? _ts(Object? v) => v is Timestamp ? v.toDate() : null;

Task _toTask(String id, Map<String, dynamic> d, {required bool hasPendingWrites}) {
  TaskSchedule? schedule;
  final rawSchedule = d['schedule'];
  if (rawSchedule is Map) {
    final at = _ts(rawSchedule['scheduledAt']);
    if (at != null) {
      schedule = TaskSchedule(
        scheduledAt: at.toUtc(),
        timezone: (rawSchedule['timezone'] as String?) ?? 'UTC',
      );
    }
  }
  var notification = TaskNotification.off;
  final rawNotification = d['notification'];
  if (rawNotification is Map) {
    final offset = rawNotification['offsetMinutes'];
    notification = TaskNotification(
      enabled: rawNotification['enabled'] == true,
      offsetMinutes: offset is int ? offset : 0,
    );
  }
  return Task(
    id: id,
    title: (d['title'] as String?) ?? '',
    description: (d['description'] as String?) ?? '',
    createdBy: (d['createdBy'] as String?) ?? '',
    assignedTo: d['assignedTo'] as String?,
    status: TaskStatus.parse(d['status']),
    schedule: schedule,
    notification: notification,
    completedAt: _ts(d['completedAt']),
    completedBy: d['completedBy'] as String?,
    deletedAt: _ts(d['deletedAt']),
    createdAt: _ts(d['createdAt']),
    updatedAt: _ts(d['updatedAt']),
    hasPendingWrites: hasPendingWrites,
  );
}

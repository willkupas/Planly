import 'package:planly/core/sync/sync_status.dart';

/// Entidades de domínio de tarefas (data-model §3.9). Sem tipos de SDK.
enum TaskStatus {
  pending,
  done;

  static TaskStatus parse(Object? v) => v == 'done' ? TaskStatus.done : TaskStatus.pending;

  String get wire => name;
}

/// `schedule` = `{type: 'datetime', scheduledAt (UTC), timezone (IANA)}`.
class TaskSchedule {
  const TaskSchedule({required this.scheduledAt, required this.timezone});

  /// Sempre em UTC.
  final DateTime scheduledAt;
  final String timezone;

  @override
  bool operator ==(Object other) =>
      other is TaskSchedule && other.scheduledAt.isAtSameMomentAs(scheduledAt) && other.timezone == timezone;

  @override
  int get hashCode => Object.hash(scheduledAt.millisecondsSinceEpoch, timezone);
}

/// `notification` = `{enabled, offsetMinutes (0..10080)}`.
class TaskNotification {
  const TaskNotification({required this.enabled, required this.offsetMinutes});

  static const off = TaskNotification(enabled: false, offsetMinutes: 0);
  static const maxOffsetMinutes = 10080;

  final bool enabled;
  final int offsetMinutes;

  @override
  bool operator ==(Object other) =>
      other is TaskNotification && other.enabled == enabled && other.offsetMinutes == offsetMinutes;

  @override
  int get hashCode => Object.hash(enabled, offsetMinutes);
}

class Task {
  const Task({
    required this.id,
    required this.title,
    required this.createdBy,
    required this.status,
    this.description = '',
    this.assignedTo,
    this.schedule,
    this.notification = TaskNotification.off,
    this.completedAt,
    this.completedBy,
    this.deletedAt,
    this.createdAt,
    this.updatedAt,
    this.hasPendingWrites = false,
  });

  final String id;
  final String title;
  final String description;
  final String createdBy;

  /// `null` = qualquer pessoa.
  final String? assignedTo;
  final TaskStatus status;
  final TaskSchedule? schedule;
  final TaskNotification notification;
  final DateTime? completedAt;
  final String? completedBy;
  final DateTime? deletedAt;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  /// Escrita local ainda não confirmada pelo servidor (ícone "pendente" por item, spec §5.2).
  final bool hasPendingWrites;

  bool get isDone => status == TaskStatus.done;
  bool get isDeleted => deletedAt != null;
}

class TasksSnapshot {
  const TasksSnapshot(this.items, [this.meta = const SyncMeta()]);

  final List<Task> items;
  final SyncMeta meta;
}

/// Casa onde a tarefa vive: `families/{familyId}/households/{householdId}`.
class TaskScope {
  const TaskScope(this.familyId, this.householdId);

  final String familyId;
  final String householdId;

  @override
  bool operator ==(Object other) =>
      other is TaskScope && other.familyId == familyId && other.householdId == householdId;

  @override
  int get hashCode => Object.hash(familyId, householdId);
}

/// Quem executa a ação (vai para `activity.actorId/actorName`).
class TaskActor {
  const TaskActor({required this.uid, required this.name});

  final String uid;
  final String name;
}

/// Campos editáveis de uma tarefa (criação e edição).
class TaskDraft {
  const TaskDraft({
    required this.title,
    this.description = '',
    this.assignedTo,
    this.schedule,
    this.notification = TaskNotification.off,
  });

  final String title;
  final String description;
  final String? assignedTo;
  final TaskSchedule? schedule;
  final TaskNotification notification;

  static const maxTitle = 200;
  static const maxDescription = 5000;

  /// Validação de UI (as Rules repetem: título 1–200, descrição ≤ 5000).
  bool get isValid {
    final t = title.trim();
    return t.isNotEmpty && t.length <= maxTitle && description.length <= maxDescription;
  }
}

/// Resultado de uma escrita: [id] disponível na hora; [ack] completa quando o servidor
/// confirma (offline, só depois de reconectar) ou falha com `AppFailure` (ex.: Rules).
class TaskWrite {
  const TaskWrite(this.id, this.ack);

  final String id;
  final Future<void> ack;
}

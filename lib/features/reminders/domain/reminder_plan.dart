import 'package:planly/features/tasks/domain/task_models.dart';

/// Lembrete pessoal calculado a partir de uma tarefa (puro, sem plugin nem relógio global).
class ReminderPlan {
  const ReminderPlan({
    required this.taskId,
    required this.familyId,
    required this.householdId,
    required this.title,
    required this.scheduledAt,
    required this.fireAt,
  });

  final String taskId;
  final String familyId;
  final String householdId;

  /// Título já limitado por [ReminderPlan.maxTitleLength].
  final String title;

  /// Horário da tarefa (UTC).
  final DateTime scheduledAt;

  /// Instante do disparo, em UTC: `scheduledAt - offsetMinutes`.
  final DateTime fireAt;

  static const maxTitleLength = 80;

  /// Id da notificação, determinístico a partir do id da tarefa.
  int get notificationId => reminderNotificationId(taskId);

  ReminderPayload get payload => ReminderPayload(familyId: familyId, householdId: householdId, taskId: taskId);
}

/// Id inteiro positivo de 31 bits (FNV-1a sobre o id da tarefa): estável entre execuções, o
/// que permite reagendar/cancelar sem guardar mapeamento.
int reminderNotificationId(String taskId) {
  var hash = 0x811c9dc5;
  for (final unit in taskId.codeUnits) {
    hash ^= unit & 0xff;
    hash = (hash * 0x01000193) & 0xffffffff;
    if (unit > 0xff) {
      hash ^= (unit >> 8) & 0xff;
      hash = (hash * 0x01000193) & 0xffffffff;
    }
  }
  return hash & 0x7fffffff;
}

String _limitTitle(String raw) {
  final t = raw.trim().replaceAll(RegExp(r'\s+'), ' ');
  if (t.length <= ReminderPlan.maxTitleLength) return t;
  return '${t.substring(0, ReminderPlan.maxTitleLength - 1).trimRight()}…';
}

/// Tarefas que geram lembrete para [uid] em [now]: pendentes, não excluídas, com `schedule`,
/// notificação ligada, do usuário (`assignedTo == uid` ou "qualquer pessoa") e cujo disparo
/// (`scheduledAt - offsetMinutes`) ainda está no futuro.
List<ReminderPlan> computeReminderPlans({
  required Iterable<Task> tasks,
  required String familyId,
  required String householdId,
  required String uid,
  required DateTime now,
}) {
  final plans = <ReminderPlan>[];
  for (final t in tasks) {
    final schedule = t.schedule;
    if (schedule == null || t.isDeleted || t.isDone || !t.notification.enabled) continue;
    if (t.assignedTo != null && t.assignedTo != uid) continue;
    final offset = t.notification.offsetMinutes.clamp(0, TaskNotification.maxOffsetMinutes);
    final scheduledAt = schedule.scheduledAt.toUtc();
    final fireAt = scheduledAt.subtract(Duration(minutes: offset));
    if (!fireAt.isAfter(now.toUtc())) continue;
    plans.add(ReminderPlan(
      taskId: t.id,
      familyId: familyId,
      householdId: householdId,
      title: _limitTitle(t.title),
      scheduledAt: scheduledAt,
      fireAt: fireAt,
    ));
  }
  plans.sort((a, b) => a.fireAt.compareTo(b.fireAt));
  return plans;
}

/// Conteúdo do payload da notificação: só ids (nada de título/descrição).
class ReminderPayload {
  const ReminderPayload({required this.familyId, required this.householdId, required this.taskId});

  final String familyId;
  final String householdId;
  final String taskId;

  /// `planly://task/<taskId>?f=<familyId>&h=<householdId>`
  String encode() => Uri(
        scheme: 'planly',
        host: 'task',
        pathSegments: [taskId],
        queryParameters: {'f': familyId, 'h': householdId},
      ).toString();

  /// `null` se o payload não for de um lembrete de tarefa válido.
  static ReminderPayload? parse(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    final uri = Uri.tryParse(raw);
    if (uri == null || uri.scheme != 'planly' || uri.host != 'task') return null;
    if (uri.pathSegments.length != 1) return null;
    final taskId = uri.pathSegments.first;
    final f = uri.queryParameters['f'];
    final h = uri.queryParameters['h'];
    if (taskId.isEmpty || f == null || f.isEmpty || h == null || h.isEmpty) return null;
    return ReminderPayload(familyId: f, householdId: h, taskId: taskId);
  }

  @override
  bool operator ==(Object other) =>
      other is ReminderPayload &&
      other.familyId == familyId &&
      other.householdId == householdId &&
      other.taskId == taskId;

  @override
  int get hashCode => Object.hash(familyId, householdId, taskId);
}

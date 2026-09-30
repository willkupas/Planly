import 'package:planly/features/tasks/domain/task_models.dart';

/// Agrupamento do dashboard para tarefas pendentes COM data: "Hoje" inclui as atrasadas
/// (antes do fim do dia local de [now]); "Próximas", o resto. Preserva a ordem recebida
/// (já ordenada por `scheduledAt` no servidor).
class ScheduledGroups {
  const ScheduledGroups({required this.today, required this.upcoming});

  final List<Task> today;
  final List<Task> upcoming;

  bool get isEmpty => today.isEmpty && upcoming.isEmpty;
}

ScheduledGroups groupScheduled(List<Task> scheduled, DateTime now) {
  final local = now.toLocal();
  final startOfTomorrow = DateTime(local.year, local.month, local.day + 1);
  final today = <Task>[];
  final upcoming = <Task>[];
  for (final t in scheduled) {
    final at = t.schedule?.scheduledAt;
    if (at == null) continue;
    (at.toLocal().isBefore(startOfTomorrow) ? today : upcoming).add(t);
  }
  return ScheduledGroups(today: today, upcoming: upcoming);
}

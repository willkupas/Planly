import 'package:planly/features/activity/domain/activity_models.dart';

/// Eventos de um mesmo dia (calendário local), do mais recente para o mais antigo.
class ActivityDayGroup {
  const ActivityDayGroup(this.day, this.events);

  /// Meia-noite local do dia.
  final DateTime day;
  final List<ActivityEvent> events;
}

DateTime _dayOf(DateTime d) => DateTime(d.year, d.month, d.day);

/// Agrupa por dia local, preservando a ordem recebida (já vem `createdAt DESC`). Evento sem
/// `createdAt` (escrita pendente) conta como [now]. Dias nunca se repetem no resultado.
List<ActivityDayGroup> groupByDay(List<ActivityEvent> events, DateTime now) {
  final groups = <DateTime, ActivityDayGroup>{};
  for (final e in events) {
    final day = _dayOf((e.createdAt ?? now).toLocal());
    groups.putIfAbsent(day, () => ActivityDayGroup(day, [])).events.add(e);
  }
  return groups.values.toList();
}

enum DayLabel { today, yesterday, date }

/// Como rotular o grupo de [day] em relação a [now].
DayLabel dayLabelFor(DateTime day, DateTime now) {
  final today = _dayOf(now);
  if (day == today) return DayLabel.today;
  if (day == DateTime(today.year, today.month, today.day - 1)) {
    return DayLabel.yesterday;
  }
  return DayLabel.date;
}

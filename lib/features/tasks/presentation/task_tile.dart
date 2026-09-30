import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:planly/app/router/routes.dart';
import 'package:planly/core/time/clock.dart';
import 'package:planly/core/widgets/ui_actions.dart';
import 'package:planly/features/tasks/application/task_providers.dart';
import 'package:planly/features/tasks/domain/task_models.dart';
import 'package:planly/l10n/app_localizations.dart';

/// Linha de tarefa: checkbox (concluir/reabrir), título, horário e ícone de "pendente de
/// sincronização". Toque abre o detalhe.
class TaskTile extends ConsumerWidget {
  const TaskTile({super.key, required this.task});

  final Task task;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final access = ref.watch(taskAccessProvider);
    final canComplete = access.canComplete(task);
    final schedule = task.schedule;
    final now = ref.read(clockProvider)();
    final overdue = !task.isDone && schedule != null && schedule.scheduledAt.isBefore(now.toUtc());

    final parts = <String>[
      if (schedule != null)
        l10n.taskScheduleAt(schedule.scheduledAt.toLocal(), schedule.scheduledAt.toLocal()),
    ];

    return ListTile(
      key: Key('task-${task.id}'),
      leading: Checkbox(
        key: Key('task-check-${task.id}'),
        value: task.isDone,
        semanticLabel: task.isDone ? l10n.taskMarkPending(task.title) : l10n.taskMarkDone(task.title),
        onChanged: canComplete
            ? (_) => runUiAction(context, () {
                  final actions = ref.read(taskActionsProvider);
                  return task.isDone ? actions.reopen(task) : actions.complete(task);
                })
            : null,
      ),
      title: Text(
        task.title,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: task.isDone
            ? TextStyle(decoration: TextDecoration.lineThrough, color: theme.colorScheme.outline)
            : null,
      ),
      subtitle: parts.isEmpty && !overdue
          ? null
          : Text.rich(
              TextSpan(
                children: [
                  if (overdue)
                    TextSpan(
                      text: '${l10n.taskOverdue} · ',
                      style: TextStyle(color: theme.colorScheme.error, fontWeight: FontWeight.w600),
                    ),
                  TextSpan(text: parts.join()),
                ],
              ),
            ),
      trailing: task.hasPendingWrites
          ? Tooltip(
              message: l10n.taskPendingSync,
              child: Icon(Icons.schedule, key: Key('task-pending-${task.id}'), size: 18),
            )
          : null,
      onTap: () => context.push(Routes.taskPath(task.id)),
    );
  }
}

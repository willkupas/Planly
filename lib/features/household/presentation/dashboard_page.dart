import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:planly/app/router/routes.dart';
import 'package:planly/core/l10n_helpers/failure_message.dart';
import 'package:planly/core/sync/sync_status.dart';
import 'package:planly/core/time/clock.dart';
import 'package:planly/core/widgets/async_value_view.dart';
import 'package:planly/core/widgets/state_widgets.dart';
import 'package:planly/features/family/presentation/family_frozen_banner.dart';
import 'package:planly/features/household/application/household_providers.dart';
import 'package:planly/features/household/domain/household_models.dart';
import 'package:planly/features/household/presentation/switch_context_sheet.dart';
import 'package:planly/features/tasks/application/dashboard_groups.dart';
import 'package:planly/features/tasks/application/task_providers.dart';
import 'package:planly/features/tasks/domain/task_models.dart';
import 'package:planly/features/tasks/presentation/quick_add_sheet.dart';
import 'package:planly/features/tasks/presentation/task_tile.dart';
import 'package:planly/l10n/app_localizations.dart';

/// Dashboard (spec §1 #4): casa ativa + seletor, indicador de sync, tarefas (Hoje / Próximas /
/// Sem data / Concluídas recentes, com toggle "Minhas"), FAB `+` e atalho de listas.
class DashboardPage extends ConsumerWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final households = ref.watch(accessibleHouseholdsProvider);
    final active = ref.watch(activeHouseholdProvider);
    final canCreate = ref.watch(taskAccessProvider).canCreate;
    final meta = _syncMeta(ref, households.value?.meta);

    // Escrita já aplicada localmente que o servidor recusou depois (Rules): avisa, sem travar.
    ref.listen(taskWriteFailureProvider, (_, next) {
      if (next == null) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(failureMessage(l10n, next.error))));
    });

    return Scaffold(
      appBar: AppBar(
        title: InkWell(
          key: const Key('household-selector'),
          borderRadius: BorderRadius.circular(8),
          onTap: () => showSwitchContextSheet(context),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(child: Text(active?.name ?? l10n.homeTitle, overflow: TextOverflow.ellipsis)),
                const Icon(Icons.arrow_drop_down),
              ],
            ),
          ),
        ),
        actions: [
          if (meta != null) SyncIndicator(meta: meta),
          IconButton(
            key: const Key('open-settings'),
            tooltip: l10n.settingsTitle,
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => context.push(Routes.settings),
          ),
        ],
      ),
      floatingActionButton: canCreate && active != null
          ? FloatingActionButton(
              key: const Key('fab-add-task'),
              tooltip: l10n.taskFab,
              onPressed: () => showQuickAddSheet(context),
              child: const Icon(Icons.add),
            )
          : null,
      body: Column(
        children: [
          const OfflineBanner(),
          const FamilyFrozenBanner(),
          Expanded(
            child: AsyncValueView<HouseholdsSnapshot>(
              value: households,
              onRetry: () => ref.invalidate(accessibleHouseholdsProvider),
              isEmpty: (s) => s.items.isEmpty,
              empty: EmptyState(
                icon: Icons.home_outlined,
                title: l10n.dashboardNoHouseholdTitle,
                message: l10n.dashboardNoHouseholdMessage,
              ),
              data: (context, snap) => const _Content(),
            ),
          ),
        ],
      ),
    );
  }

  /// Sync do que a tela mostra: casas + tarefas (agendadas e sem data).
  SyncMeta? _syncMeta(WidgetRef ref, SyncMeta? households) {
    final metas = [
      households,
      ref.watch(scheduledTasksProvider).value?.meta,
      ref.watch(unscheduledTasksProvider).value?.meta,
    ].whereType<SyncMeta>().toList();
    if (metas.isEmpty) return null;
    return SyncMeta(
      hasPendingWrites: metas.any((m) => m.hasPendingWrites),
      isFromCache: metas.any((m) => m.isFromCache),
    );
  }
}

class _Content extends ConsumerWidget {
  const _Content();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final filter = ref.watch(taskFilterProvider);
    final scheduled = ref.watch(scheduledTasksProvider);
    final unscheduled = ref.watch(unscheduledTasksProvider);
    final done = ref.watch(recentDoneTasksProvider);
    final canCreate = ref.watch(taskAccessProvider).canCreate;
    final uid = ref.watch(taskAccessProvider).uid;

    final all = [scheduled, unscheduled, done];
    final error = all.where((v) => v.hasError && !v.hasValue).firstOrNull;
    final loading = all.any((v) => !v.hasValue && !v.hasError);

    Widget body;
    if (error != null) {
      body = ErrorState(
        message: failureMessage(l10n, error.error!),
        onRetry: () {
          ref.invalidate(scheduledTasksProvider);
          ref.invalidate(unscheduledTasksProvider);
          ref.invalidate(recentDoneTasksProvider);
        },
      );
    } else if (loading) {
      body = const LoadingSkeleton();
    } else {
      final groups = groupScheduled(scheduled.requireValue.items, ref.read(clockProvider)());
      final noDate = unscheduled.requireValue.items;
      // "Minhas": concluídas também só as minhas (a query de concluídas não filtra no servidor).
      final doneItems = [
        for (final t in done.requireValue.items)
          if (filter == TaskFilter.all || t.assignedTo == uid) t,
      ];
      final hasAny = !groups.isEmpty || noDate.isNotEmpty || doneItems.isNotEmpty;
      body = !hasAny
          ? EmptyState(
              icon: Icons.task_alt,
              title: filter == TaskFilter.mine ? l10n.taskEmptyMine : l10n.taskEmptyTitle,
              message: filter == TaskFilter.mine ? null : l10n.taskEmptyMessage,
              action: canCreate && filter == TaskFilter.all
                  ? FilledButton.icon(
                      key: const Key('empty-add-task'),
                      icon: const Icon(Icons.add),
                      label: Text(l10n.taskQuickAddSubmit),
                      onPressed: () => showQuickAddSheet(context),
                    )
                  : null,
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _TaskSection(sectionKey: 'section-today', title: l10n.dashboardToday, tasks: groups.today),
                _TaskSection(
                  sectionKey: 'section-upcoming',
                  title: l10n.dashboardUpcoming,
                  tasks: groups.upcoming,
                ),
                _TaskSection(
                  sectionKey: 'section-unscheduled',
                  title: l10n.taskSectionUnscheduled,
                  tasks: noDate,
                ),
                _TaskSection(sectionKey: 'section-done', title: l10n.taskSectionDone, tasks: doneItems),
              ],
            );
    }

    return ListView(
      key: const Key('dashboard-content'),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
      children: [
        Text(l10n.homeGreeting, style: theme.textTheme.headlineSmall),
        const SizedBox(height: 12),
        SegmentedButton<TaskFilter>(
          key: const Key('task-filter'),
          showSelectedIcon: false,
          segments: [
            ButtonSegment(
              value: TaskFilter.all,
              label: Text(l10n.taskFilterAll, key: const Key('filter-all')),
            ),
            ButtonSegment(
              value: TaskFilter.mine,
              label: Text(l10n.taskFilterMine, key: const Key('filter-mine')),
            ),
          ],
          selected: {filter},
          onSelectionChanged: (s) => ref.read(taskFilterProvider.notifier).select(s.first),
        ),
        const SizedBox(height: 8),
        body,
        const SizedBox(height: 8),
        const _ListsShortcut(),
      ],
    );
  }
}

class _TaskSection extends StatelessWidget {
  const _TaskSection({required this.sectionKey, required this.title, required this.tasks});

  final String sectionKey;
  final String title;
  final List<Task> tasks;

  @override
  Widget build(BuildContext context) {
    if (tasks.isEmpty) return const SizedBox.shrink();
    return Column(
      key: Key(sectionKey),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 12, bottom: 4),
          child: Text(title, style: Theme.of(context).textTheme.titleSmall),
        ),
        Card(
          margin: EdgeInsets.zero,
          child: Column(children: [for (final t in tasks) TaskTile(task: t)]),
        ),
      ],
    );
  }
}

/// Atalho para a aba Listas (o resumo de listas no dashboard é melhoria futura).
class _ListsShortcut extends StatelessWidget {
  const _ListsShortcut();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Card(
      child: ListTile(
        key: const Key('dashboard-lists-shortcut'),
        title: Text(l10n.dashboardLists),
        subtitle: Text(l10n.dashboardListsOpen),
        leading: const Icon(Icons.checklist),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => context.go(Routes.lists),
      ),
    );
  }
}

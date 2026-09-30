import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:planly/app/router/routes.dart';
import 'package:planly/core/time/device_timezone.dart';
import 'package:planly/core/widgets/async_value_view.dart';
import 'package:planly/core/widgets/state_widgets.dart';
import 'package:planly/core/widgets/write_failures_banner.dart';
import 'package:planly/core/widgets/ui_actions.dart';
import 'package:planly/features/family/application/family_providers.dart';
import 'package:planly/features/family/domain/family_models.dart';
import 'package:planly/features/family/presentation/family_frozen_banner.dart';
import 'package:planly/features/tasks/application/task_providers.dart';
import 'package:planly/features/tasks/domain/task_models.dart';
import 'package:planly/features/tasks/presentation/task_form.dart';
import 'package:planly/l10n/app_localizations.dart';

/// Detalhe/edição de tarefa (spec §1 #7). Campos habilitados conforme as Rules: autor,
/// admin da casa ou owner editam; quem é responsável (ou "qualquer pessoa") só conclui/reabre.
class TaskDetailPage extends ConsumerWidget {
  const TaskDetailPage({super.key, required this.taskId});

  final String taskId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final value = ref.watch(taskProvider(taskId));
    final task = value.value;
    final access = ref.watch(taskAccessProvider);
    final canDelete = task != null && access.canDelete(task);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.taskDetailTitle),
        actions: [
          if (canDelete)
            IconButton(
              key: const Key('task-delete'),
              tooltip: l10n.taskDelete,
              icon: const Icon(Icons.delete_outline),
              onPressed: () => _confirmDelete(context, ref, task),
            ),
        ],
      ),
      body: Column(
        children: [
          const OfflineBanner(),
          const WriteFailuresBanner(),
          const FamilyFrozenBanner(),
          Expanded(
            child: AsyncValueView<Task?>(
              value: value,
              onRetry: () => ref.invalidate(taskProvider(taskId)),
              isEmpty: (t) => t == null || t.isDeleted,
              empty: EmptyState(
                icon: Icons.search_off,
                title: l10n.taskNotFoundTitle,
                message: l10n.taskNotFoundMessage,
              ),
              data: (context, t) => _TaskEditor(key: ValueKey(t!.id), task: t),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref, Task task) async {
    final l10n = AppLocalizations.of(context);
    final ok = await confirmDialog(
      context,
      title: l10n.taskDeleteTitle,
      message: l10n.taskDeleteMessage,
      confirmLabel: l10n.taskDelete,
      destructive: true,
    );
    if (!ok || !context.mounted) return;
    final router = GoRouter.of(context);
    final done = await runUiAction(
      context,
      () => ref.read(taskActionsProvider).delete(task),
      successMessage: l10n.taskDeleted,
    );
    if (!done) return;
    if (router.canPop()) {
      router.pop();
    } else {
      router.go(Routes.home);
    }
  }
}

class _TaskEditor extends ConsumerStatefulWidget {
  const _TaskEditor({super.key, required this.task});

  final Task task;

  @override
  ConsumerState<_TaskEditor> createState() => _TaskEditorState();
}

class _TaskEditorState extends ConsumerState<_TaskEditor> {
  late final TaskFormController _form = TaskFormController(original: widget.task);

  @override
  void didUpdateWidget(_TaskEditor old) {
    super.didUpdateWidget(old);
    if (!identical(old.task, widget.task)) _form.rebase(widget.task);
  }

  @override
  void dispose() {
    _form.dispose();
    super.dispose();
  }

  Future<void> _save(AppLocalizations l10n) async {
    await runUiAction(context, () async {
      final tz = _form.when != null ? (await ref.read(deviceTimezoneProvider)() ?? 'UTC') : 'UTC';
      await ref.read(taskActionsProvider).update(widget.task, _form.toDraft(tz));
    }, successMessage: l10n.taskSaved);
  }

  String _nameOf(AppLocalizations l10n, List<FamilyMember>? members, String uid) {
    final m = members?.where((m) => m.uid == uid);
    final n = m != null && m.isNotEmpty ? m.first.displayName?.trim() : null;
    return (n == null || n.isEmpty) ? l10n.memberNoName : n;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final task = widget.task;
    final access = ref.watch(taskAccessProvider);
    final canEdit = access.canEdit(task);
    final canComplete = access.canComplete(task);
    final familyId = ref.watch(activeFamilyIdProvider);
    final members = familyId == null ? null : ref.watch(familyMembersProvider(familyId)).value;

    return ListView(
      key: const Key('task-detail-content'),
      padding: const EdgeInsets.all(16),
      children: [
        ListenableBuilder(
          listenable: _form,
          builder: (context, _) => TextField(
            key: const Key('task-title'),
            controller: _form.title,
            enabled: canEdit,
            maxLength: TaskDraft.maxTitle,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(labelText: l10n.taskTitleLabel),
          ),
        ),
        const SizedBox(height: 8),
        TaskFormFields(controller: _form, enabled: canEdit),
        const SizedBox(height: 8),
        if (!canEdit)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              access.familyWritable ? l10n.taskReadOnly : l10n.taskFrozenReadOnly,
              key: const Key('task-read-only'),
            ),
          ),
        Text(l10n.taskCreatedBy(_nameOf(l10n, members, task.createdBy))),
        if (task.createdAt != null) Text(l10n.taskDetailDate(task.createdAt!.toLocal())),
        if (task.isDone && task.completedBy != null)
          Text(l10n.taskCompletedBy(_nameOf(l10n, members, task.completedBy!))),
        const SizedBox(height: 16),
        ListenableBuilder(
          listenable: _form,
          builder: (context, _) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (canEdit && _form.isDirty)
                FilledButton(
                  key: const Key('task-save'),
                  onPressed: _form.hasValidTitle ? () => _save(l10n) : null,
                  child: Text(l10n.taskSave),
                ),
              if (canComplete) ...[
                const SizedBox(height: 8),
                FilledButton.tonalIcon(
                  key: const Key('task-toggle-done'),
                  icon: Icon(task.isDone ? Icons.undo : Icons.check_circle_outline),
                  label: Text(task.isDone ? l10n.taskReopen : l10n.taskComplete),
                  onPressed: () => runUiAction(context, () {
                    final actions = ref.read(taskActionsProvider);
                    return task.isDone ? actions.reopen(task) : actions.complete(task);
                  }),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

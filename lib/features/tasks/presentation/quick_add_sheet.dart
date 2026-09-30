import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:planly/core/time/device_timezone.dart';
import 'package:planly/core/widgets/ui_actions.dart';
import 'package:planly/features/auth/application/auth_providers.dart';
import 'package:planly/features/tasks/application/task_providers.dart';
import 'package:planly/features/tasks/domain/task_models.dart';
import 'package:planly/features/tasks/presentation/task_form.dart';
import 'package:planly/l10n/app_localizations.dart';

/// Criar tarefa rápida (spec §1 #5/#6): `+` -> texto (já focado) -> ✓. "Mais opções" expande
/// na mesma sheet. A escrita é otimista e funciona offline.
Future<void> showQuickAddSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => const QuickAddSheet(),
  );
}

class QuickAddSheet extends ConsumerStatefulWidget {
  const QuickAddSheet({super.key});

  @override
  ConsumerState<QuickAddSheet> createState() => _QuickAddSheetState();
}

class _QuickAddSheetState extends ConsumerState<QuickAddSheet> {
  late final TaskFormController _form = TaskFormController(
    defaultAssignee: ref.read(currentUidProvider),
  );
  bool _expanded = false;
  bool _busy = false;

  @override
  void dispose() {
    _form.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy || !_form.hasValidTitle) return;
    setState(() => _busy = true);
    final navigator = Navigator.of(context);
    final ok = await runUiAction(context, () async {
      final hasDate = _form.when != null;
      final tz = hasDate ? (await ref.read(deviceTimezoneProvider)() ?? 'UTC') : 'UTC';
      final TaskDraft draft = _form.toDraft(tz);
      await ref.read(taskActionsProvider).create(draft);
    });
    if (!mounted) return;
    if (ok) {
      navigator.pop();
    } else {
      setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: TextField(
                      key: const Key('quick-add-field'),
                      controller: _form.title,
                      autofocus: true,
                      maxLength: TaskDraft.maxTitle,
                      textInputAction: TextInputAction.done,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: InputDecoration(
                        hintText: l10n.taskQuickAddHint,
                        counterText: '',
                      ),
                      onSubmitted: (_) => _submit(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ListenableBuilder(
                    listenable: _form,
                    builder: (context, _) => IconButton.filled(
                      key: const Key('quick-add-submit'),
                      tooltip: l10n.taskQuickAddSubmit,
                      icon: const Icon(Icons.check),
                      onPressed: _busy || !_form.hasValidTitle ? null : _submit,
                    ),
                  ),
                ],
              ),
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: TextButton.icon(
                  key: const Key('quick-add-more'),
                  icon: Icon(_expanded ? Icons.expand_less : Icons.expand_more),
                  label: Text(_expanded ? l10n.taskLessOptions : l10n.taskMoreOptions),
                  onPressed: () => setState(() => _expanded = !_expanded),
                ),
              ),
              if (_expanded) TaskFormFields(controller: _form),
            ],
          ),
        ),
      ),
    );
  }
}

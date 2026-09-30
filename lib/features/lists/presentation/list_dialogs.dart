import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:planly/core/widgets/ui_actions.dart';
import 'package:planly/features/lists/application/list_providers.dart';
import 'package:planly/features/lists/domain/list_models.dart';
import 'package:planly/l10n/app_localizations.dart';

typedef NewListData = ({String name, ListType type});

Future<NewListData?> showCreateListDialog(BuildContext context) {
  return showDialog<NewListData>(context: context, builder: (_) => const _CreateListDialog());
}

class _CreateListDialog extends StatefulWidget {
  const _CreateListDialog();

  @override
  State<_CreateListDialog> createState() => _CreateListDialogState();
}

class _CreateListDialogState extends State<_CreateListDialog> {
  final _controller = TextEditingController();
  ListType _type = ListType.shopping;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _controller.text.trim();
    if (name.isEmpty) return;
    Navigator.pop<NewListData>(context, (name: name, type: _type));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(l10n.listsCreateTitle),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            key: const Key('list-name-field'),
            controller: _controller,
            autofocus: true,
            maxLength: listNameMaxLength,
            textInputAction: TextInputAction.done,
            decoration: InputDecoration(labelText: l10n.listsNameLabel),
            onSubmitted: (_) => _submit(),
          ),
          const SizedBox(height: 8),
          Text(l10n.listsTypeLabel, style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 8),
          SegmentedButton<ListType>(
            key: const Key('list-type-selector'),
            showSelectedIcon: false,
            segments: [
              ButtonSegment(value: ListType.shopping, label: Text(l10n.listsTypeShopping)),
              ButtonSegment(value: ListType.general, label: Text(l10n.listsTypeGeneral)),
            ],
            selected: {_type},
            onSelectionChanged: (s) => setState(() => _type = s.first),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(l10n.actionCancel)),
        FilledButton(key: const Key('list-create-confirm'), onPressed: _submit, child: Text(l10n.actionCreate)),
      ],
    );
  }
}

Future<void> renameListFlow(BuildContext context, WidgetRef ref, TaskList list) async {
  final l10n = AppLocalizations.of(context);
  final name = await textInputDialog(
    context,
    title: l10n.listsRenameTitle,
    label: l10n.listsNameLabel,
    confirmLabel: l10n.actionSave,
    initial: list.name,
    maxLength: listNameMaxLength,
  );
  if (name == null || name == list.name || !context.mounted) return;
  await runUiAction(context, () => ref.read(listActionsProvider).renameList(list, name));
}

/// Confirma e exclui (soft delete). Devolve true se excluiu.
Future<bool> deleteListFlow(BuildContext context, WidgetRef ref, TaskList list) async {
  final l10n = AppLocalizations.of(context);
  final ok = await confirmDialog(
    context,
    title: l10n.listsDeleteTitle,
    message: l10n.listsDeleteMessage(list.name),
    confirmLabel: l10n.listsMenuDelete,
    destructive: true,
  );
  if (!ok || !context.mounted) return false;
  return runUiAction(context, () => ref.read(listActionsProvider).deleteList(list));
}

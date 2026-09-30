import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:planly/core/widgets/async_value_view.dart';
import 'package:planly/core/widgets/state_widgets.dart';
import 'package:planly/core/widgets/write_failures_banner.dart';
import 'package:planly/core/widgets/ui_actions.dart';
import 'package:planly/features/family/application/family_providers.dart';
import 'package:planly/features/family/presentation/family_frozen_banner.dart';
import 'package:planly/features/lists/application/list_providers.dart';
import 'package:planly/features/lists/domain/list_models.dart';
import 'package:planly/features/lists/presentation/list_dialogs.dart';
import 'package:planly/l10n/app_localizations.dart';

/// Tela 9: itens da lista (pendentes antes dos concluídos), adicionar inline, marcar,
/// editar, reordenar por arrastar e excluir. Colaborativa; somente leitura se a família
/// não está ativa.
class ListDetailPage extends ConsumerWidget {
  const ListDetailPage({super.key, required this.listId});

  final String listId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final lists = ref.watch(householdListsProvider);
    final items = ref.watch(listItemsProvider(listId));
    final canWrite = ref.watch(familyWriteAccessProvider);

    TaskList? list;
    for (final l in lists.value?.items ?? const <TaskList>[]) {
      if (l.id == listId) list = l;
    }
    final listGone = lists.hasValue && list == null;
    final canManage = list != null && canWrite && ref.watch(canManageContentProvider(list.createdBy));
    final meta = items.value?.meta;

    return Scaffold(
      appBar: AppBar(
        title: Text(list?.name ?? l10n.listsTitle, overflow: TextOverflow.ellipsis),
        actions: [
          if (meta != null) SyncIndicator(meta: meta),
          if (canManage)
            PopupMenuButton<String>(
              key: const Key('list-detail-menu'),
              onSelected: (v) async {
                if (v == 'rename') {
                  await renameListFlow(context, ref, list!);
                } else if (await deleteListFlow(context, ref, list!) && context.mounted) {
                  context.pop();
                }
              },
              itemBuilder: (_) => [
                PopupMenuItem(value: 'rename', child: Text(l10n.listsMenuRename)),
                PopupMenuItem(value: 'delete', child: Text(l10n.listsMenuDelete)),
              ],
            ),
        ],
      ),
      body: Column(
        children: [
          const OfflineBanner(),
          const WriteFailuresBanner(),
          const FamilyFrozenBanner(),
          Expanded(
            child: listGone
                ? EmptyState(icon: Icons.search_off, title: l10n.listsNotFound)
                : AsyncValueView<ItemsSnapshot>(
                    value: items,
                    onRetry: () => ref.invalidate(listItemsProvider(listId)),
                    isEmpty: (s) => s.items.isEmpty,
                    empty: EmptyState(
                      icon: Icons.playlist_add,
                      title: l10n.itemsEmptyTitle,
                      message: canWrite ? l10n.itemsEmptyMessage : null,
                    ),
                    data: (context, snap) => _ItemsView(listId: listId, snap: snap, canWrite: canWrite),
                  ),
          ),
          if (canWrite && !listGone) _AddItemBar(listId: listId),
        ],
      ),
    );
  }
}

class _ItemsView extends ConsumerWidget {
  const _ItemsView({required this.listId, required this.snap, required this.canWrite});

  final String listId;
  final ItemsSnapshot snap;
  final bool canWrite;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final pending = snap.pending;
    final done = snap.done;

    return ListView(
      key: const Key('items-view'),
      children: [
        ReorderableListView.builder(
          key: const Key('pending-items'),
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          buildDefaultDragHandles: false,
          itemCount: pending.length,
          onReorderItem: (oldIndex, newIndex) => runUiAction(
            context,
            () => ref.read(listActionsProvider).reorder(listId, pending, oldIndex, newIndex),
          ),
          itemBuilder: (context, i) => _ItemTile(
            key: ValueKey(pending[i].id),
            listId: listId,
            item: pending[i],
            index: i,
            canWrite: canWrite,
          ),
        ),
        if (done.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
            child: Text(
              l10n.itemsDoneSection(done.length),
              key: const Key('done-header'),
              style: Theme.of(context).textTheme.labelLarge,
            ),
          ),
          for (final item in done)
            _ItemTile(key: ValueKey(item.id), listId: listId, item: item, index: -1, canWrite: canWrite),
        ],
      ],
    );
  }
}

class _ItemTile extends ConsumerWidget {
  const _ItemTile({
    super.key,
    required this.listId,
    required this.item,
    required this.index,
    required this.canWrite,
  });

  final String listId;
  final ListItem item;

  /// Posição entre os pendentes (arrastável); -1 = concluído.
  final int index;
  final bool canWrite;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final canDelete = canWrite && ref.watch(canManageContentProvider(item.createdBy));
    final actions = ref.read(listActionsProvider);

    return ListTile(
      key: Key('item-${item.id}'),
      leading: Checkbox(
        key: Key('item-check-${item.id}'),
        value: item.completed,
        onChanged: canWrite
            ? (v) => runUiAction(context, () => actions.setCompleted(listId, item, v ?? false))
            : null,
      ),
      title: Text(
        item.name,
        style: item.completed
            ? TextStyle(
                decoration: TextDecoration.lineThrough,
                color: Theme.of(context).colorScheme.outline,
              )
            : null,
      ),
      onTap: canWrite ? () => _edit(context, ref) : null,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (item.hasPendingWrites)
            Tooltip(message: l10n.itemPendingSync, child: const Icon(Icons.schedule, size: 16)),
          if (canDelete)
            IconButton(
              key: Key('item-delete-${item.id}'),
              tooltip: l10n.itemDeleteTooltip,
              icon: const Icon(Icons.delete_outline),
              onPressed: () => runUiAction(context, () => actions.deleteItem(listId, item)),
            ),
          if (canWrite && index >= 0)
            ReorderableDragStartListener(
              index: index,
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Icon(
                  Icons.drag_handle,
                  key: Key('item-drag-${item.id}'),
                  semanticLabel: l10n.itemReorderTooltip,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _edit(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context);
    final name = await textInputDialog(
      context,
      title: l10n.itemEditTitle,
      label: l10n.itemNameLabel,
      confirmLabel: l10n.actionSave,
      initial: item.name,
      maxLength: listNameMaxLength,
    );
    if (name == null || name == item.name || !context.mounted) return;
    await runUiAction(context, () => ref.read(listActionsProvider).renameItem(listId, item, name));
  }
}

/// Campo fixo no rodapé: Enter adiciona e mantém o foco para digitar o próximo.
class _AddItemBar extends ConsumerStatefulWidget {
  const _AddItemBar({required this.listId});

  final String listId;

  @override
  ConsumerState<_AddItemBar> createState() => _AddItemBarState();
}

class _AddItemBarState extends ConsumerState<_AddItemBar> {
  final _controller = TextEditingController();
  final _focus = FocusNode();

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _controller.text.trim();
    if (name.isEmpty) {
      _focus.requestFocus();
      return;
    }
    _controller.clear();
    // Sem await: escrita otimista; o campo já está livre para o próximo item.
    runUiAction(context, () => ref.read(listActionsProvider).addItem(widget.listId, name));
    _focus.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return SafeArea(
      top: false,
      child: Material(
        elevation: 4,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  key: const Key('item-add-field'),
                  controller: _controller,
                  focusNode: _focus,
                  maxLength: listNameMaxLength,
                  textInputAction: TextInputAction.done,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: InputDecoration(
                    hintText: l10n.itemAddHint,
                    counterText: '',
                    border: InputBorder.none,
                  ),
                  onSubmitted: (_) => _submit(),
                ),
              ),
              IconButton(
                key: const Key('item-add-button'),
                tooltip: l10n.itemAddAction,
                icon: const Icon(Icons.add_circle),
                onPressed: _submit,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

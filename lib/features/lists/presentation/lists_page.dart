import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:planly/app/router/routes.dart';
import 'package:planly/core/widgets/async_value_view.dart';
import 'package:planly/core/widgets/state_widgets.dart';
import 'package:planly/core/widgets/write_failures_banner.dart';
import 'package:planly/core/widgets/ui_actions.dart';
import 'package:planly/features/family/application/family_providers.dart';
import 'package:planly/features/family/presentation/family_frozen_banner.dart';
import 'package:planly/features/household/application/household_providers.dart';
import 'package:planly/features/lists/application/list_providers.dart';
import 'package:planly/features/lists/domain/list_models.dart';
import 'package:planly/features/lists/presentation/list_dialogs.dart';
import 'package:planly/l10n/app_localizations.dart';

/// Tela 8: listas da casa ativa (nome, tipo, contagem de pendentes).
class ListsPage extends ConsumerWidget {
  const ListsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final lists = ref.watch(householdListsProvider);
    final canWrite = ref.watch(familyWriteAccessProvider);
    final household = ref.watch(activeHouseholdProvider);
    final meta = lists.value?.meta;

    return Scaffold(
      appBar: AppBar(
        title: Text(household == null ? l10n.listsTitle : '${l10n.listsTitle} · ${household.name}'),
        actions: [if (meta != null) SyncIndicator(meta: meta)],
      ),
      floatingActionButton: canWrite && household != null
          ? FloatingActionButton.extended(
              key: const Key('create-list-fab'),
              icon: const Icon(Icons.add),
              label: Text(l10n.listsCreateAction),
              onPressed: () => _create(context, ref),
            )
          : null,
      body: Column(
        children: [
          const OfflineBanner(),
          const WriteFailuresBanner(),
          const FamilyFrozenBanner(),
          Expanded(
            child: AsyncValueView<ListsSnapshot>(
              value: lists,
              onRetry: () => ref.invalidate(householdListsProvider),
              isEmpty: (s) => s.items.isEmpty,
              empty: EmptyState(
                icon: Icons.checklist_outlined,
                title: l10n.listsEmptyTitle,
                message: l10n.listsEmptyMessage,
                action: canWrite
                    ? FilledButton.icon(
                        key: const Key('create-list-empty'),
                        icon: const Icon(Icons.add),
                        label: Text(l10n.listsCreateAction),
                        onPressed: () => _create(context, ref),
                      )
                    : null,
              ),
              data: (context, snap) => ListView.builder(
                key: const Key('lists-view'),
                padding: const EdgeInsets.only(bottom: 88),
                itemCount: snap.items.length,
                itemBuilder: (context, i) => _ListTile(list: snap.items[i]),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _create(BuildContext context, WidgetRef ref) async {
    final result = await showCreateListDialog(context);
    if (result == null || !context.mounted) return;
    await runUiAction(context, () => ref.read(listActionsProvider).createList(result.name, result.type));
  }
}

class _ListTile extends ConsumerWidget {
  const _ListTile({required this.list});

  final TaskList list;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final canWrite = ref.watch(familyWriteAccessProvider);
    final canManage = canWrite && ref.watch(canManageContentProvider(list.createdBy));
    final count = ref.watch(pendingCountProvider(list.id)).value;
    final typeLabel = list.type == ListType.shopping ? l10n.listsTypeShopping : l10n.listsTypeGeneral;

    return ListTile(
      key: Key('list-${list.id}'),
      leading: Icon(list.type == ListType.shopping ? Icons.shopping_cart_outlined : Icons.checklist),
      title: Text(list.name, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(count == null ? typeLabel : '$typeLabel · ${l10n.listsPendingCount(count)}'),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (list.hasPendingWrites)
            Tooltip(message: l10n.itemPendingSync, child: const Icon(Icons.schedule, size: 16)),
          if (canManage)
            PopupMenuButton<String>(
              key: Key('list-menu-${list.id}'),
              onSelected: (v) => v == 'rename' ? _rename(context, ref) : _delete(context, ref),
              itemBuilder: (_) => [
                PopupMenuItem(value: 'rename', child: Text(l10n.listsMenuRename)),
                PopupMenuItem(value: 'delete', child: Text(l10n.listsMenuDelete)),
              ],
            ),
        ],
      ),
      onTap: () async {
        await context.push(Routes.listDetail(list.id));
        // Itens podem ter mudado: recontar ao voltar.
        ref.invalidate(pendingCountProvider(list.id));
      },
    );
  }

  Future<void> _rename(BuildContext context, WidgetRef ref) => renameListFlow(context, ref, list);

  Future<void> _delete(BuildContext context, WidgetRef ref) => deleteListFlow(context, ref, list);
}

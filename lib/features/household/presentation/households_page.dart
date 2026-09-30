import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:planly/core/error/app_failure.dart';
import 'package:planly/core/l10n_helpers/failure_message.dart';
import 'package:planly/core/widgets/async_value_view.dart';
import 'package:planly/core/widgets/state_widgets.dart';
import 'package:planly/core/widgets/ui_actions.dart';
import 'package:planly/features/family/application/active_context.dart';
import 'package:planly/features/family/application/family_providers.dart';
import 'package:planly/features/family/presentation/family_frozen_banner.dart';
import 'package:planly/features/family/presentation/upsell_dialog.dart';
import 'package:planly/features/household/application/household_providers.dart';
import 'package:planly/features/household/domain/household_models.dart';
import 'package:planly/l10n/app_localizations.dart';

/// Casas da família (spec §1 #16). Owner: criar (respeita o limite do plano, com upsell no
/// Free), renomear, excluir. Demais membros: só listam as casas a que têm acesso.
class HouseholdsPage extends ConsumerWidget {
  const HouseholdsPage({super.key});

  Future<void> _create(BuildContext context, WidgetRef ref, String familyId, int currentCount) async {
    final l10n = AppLocalizations.of(context);
    final entitlement = ref.read(activeEntitlementProvider).value;
    final family = ref.read(activeFamilyProvider).value;
    final count = family?.householdCount ?? currentCount;

    // Só UX: o backend (`createHousehold`) é quem decide de verdade.
    if (entitlement != null && !entitlement.canAddHousehold(count)) {
      if (entitlement.isFree) {
        await showUpsellDialog(context, UpsellReason.households);
      } else {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(content: Text(failureMessage(l10n, const BusinessFailure('PLAN_LIMIT_HOUSEHOLDS')))),
          );
      }
      return;
    }

    final name = await textInputDialog(
      context,
      title: l10n.householdNew,
      label: l10n.householdNameLabel,
      confirmLabel: l10n.actionCreate,
    );
    if (name == null || !context.mounted) return;
    await runUiAction(
      context,
      () async {
        final id = await ref.read(householdActionsProvider).create(familyId, name);
        // A casa recém-criada vira a ativa.
        await ref.read(activeContextProvider.notifier).selectHousehold(familyId, id);
      },
      successMessage: l10n.householdCreated,
    );
  }

  Future<void> _rename(BuildContext context, WidgetRef ref, String familyId, Household h) async {
    final l10n = AppLocalizations.of(context);
    final name = await textInputDialog(
      context,
      title: l10n.householdRename,
      label: l10n.householdNameLabel,
      confirmLabel: l10n.actionSave,
      initial: h.name,
    );
    if (name == null || name == h.name || !context.mounted) return;
    await runUiAction(context, () => ref.read(householdActionsProvider).rename(familyId, h.id, name));
  }

  Future<void> _delete(BuildContext context, WidgetRef ref, String familyId, Household h, int total) async {
    final l10n = AppLocalizations.of(context);
    if (total <= 1) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(l10n.errorLastHousehold)));
      return;
    }
    final ok = await confirmDialog(
      context,
      title: l10n.householdDeleteTitle,
      message: l10n.householdDeleteMessage(h.name),
      confirmLabel: l10n.householdDelete,
      destructive: true,
    );
    if (!ok || !context.mounted) return;
    await runUiAction(
      context,
      () => ref.read(householdActionsProvider).delete(familyId, h.id),
      successMessage: l10n.householdDeleted,
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final familyId = ref.watch(activeFamilyIdProvider);
    final isOwner = ref.watch(isOwnerProvider);
    final canWrite = ref.watch(familyWriteAccessProvider);
    final households = ref.watch(accessibleHouseholdsProvider);
    final activeId = ref.watch(activeHouseholdProvider)?.id;
    final total = households.value?.items.length ?? 0;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.householdsTitle)),
      floatingActionButton: isOwner && canWrite && familyId != null
          ? FloatingActionButton.extended(
              key: const Key('add-household'),
              onPressed: () => _create(context, ref, familyId, total),
              icon: const Icon(Icons.add),
              label: Text(l10n.householdNew),
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
                icon: Icons.home_work_outlined,
                title: l10n.householdsEmpty,
                message: isOwner ? null : l10n.householdsEmptyMember,
              ),
              data: (context, snap) => ListView(
                padding: const EdgeInsets.only(bottom: 88),
                children: [
                  for (final h in snap.items)
                    ListTile(
                      key: Key('household-${h.id}'),
                      leading: Icon(h.id == activeId ? Icons.home : Icons.home_outlined),
                      title: Text(h.name),
                      subtitle: isOwner ? Text(l10n.householdAccessCount(h.access.length)) : null,
                      trailing: isOwner && canWrite && familyId != null
                          ? PopupMenuButton<String>(
                              key: Key('household-menu-${h.id}'),
                              tooltip: l10n.householdActions,
                              onSelected: (v) {
                                if (v == 'rename') _rename(context, ref, familyId, h);
                                if (v == 'delete') _delete(context, ref, familyId, h, snap.items.length);
                              },
                              itemBuilder: (_) => [
                                PopupMenuItem(value: 'rename', child: Text(l10n.householdRename)),
                                PopupMenuItem(value: 'delete', child: Text(l10n.householdDelete)),
                              ],
                            )
                          : null,
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

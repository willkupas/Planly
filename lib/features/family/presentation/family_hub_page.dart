import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:planly/app/router/routes.dart';
import 'package:planly/core/widgets/async_value_view.dart';
import 'package:planly/core/widgets/state_widgets.dart';
import 'package:planly/features/family/application/family_providers.dart';
import 'package:planly/features/family/domain/family_models.dart';
import 'package:planly/features/family/presentation/family_frozen_banner.dart';
import 'package:planly/features/family/presentation/upsell_dialog.dart';
import 'package:planly/l10n/app_localizations.dart';

String planLabel(AppLocalizations l10n, PlanId plan) => switch (plan) {
      PlanId.free => l10n.planFree,
      PlanId.family => l10n.planFamily,
      PlanId.familyPlus => l10n.planFamilyPlus,
    };

/// Hub da família (spec §1 #11): plano, uso e atalhos. Leitura funciona offline (cache).
class FamilyHubPage extends ConsumerWidget {
  const FamilyHubPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final family = ref.watch(activeFamilyProvider);
    final entitlement = ref.watch(activeEntitlementProvider).value;
    final isOwner = ref.watch(isOwnerProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(family.value?.name.isNotEmpty == true ? family.value!.name : l10n.familyTitle),
        actions: [
          IconButton(
            key: const Key('family-open-settings'),
            tooltip: l10n.settingsTitle,
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => context.push(Routes.settings),
          ),
        ],
      ),
      body: Column(
        children: [
          const OfflineBanner(),
          const FamilyFrozenBanner(),
          Expanded(
            child: AsyncValueView<Family?>(
              value: family,
              onRetry: () => ref.invalidate(activeFamilyProvider),
              isEmpty: (f) => f == null,
              empty: EmptyState(icon: Icons.group_off_outlined, title: l10n.familyNotFound),
              data: (context, f) => _Hub(family: f!, entitlement: entitlement, isOwner: isOwner),
            ),
          ),
        ],
      ),
    );
  }
}

class _Hub extends StatelessWidget {
  const _Hub({required this.family, required this.entitlement, required this.isOwner});

  final Family family;
  final Entitlement? entitlement;
  final bool isOwner;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final maxMembers = entitlement?.maxMembers;
    final maxHouseholds = entitlement?.maxHouseholds;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          key: const Key('plan-card'),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l10n.familyPlanLabel, style: theme.textTheme.labelMedium),
                Text(planLabel(l10n, family.plan), style: theme.textTheme.headlineSmall),
                const SizedBox(height: 12),
                Text(
                  maxMembers == null
                      ? l10n.familyUsageMembersNoLimit(family.memberCount)
                      : l10n.familyUsageMembers(family.memberCount, maxMembers),
                  key: const Key('usage-members'),
                ),
                const SizedBox(height: 4),
                Text(
                  entitlement == null
                      ? l10n.familyUsageHouseholdsNoLimit(family.householdCount)
                      : maxHouseholds == null
                          ? l10n.familyUsageHouseholdsUnlimited(family.householdCount)
                          : l10n.familyUsageHouseholds(family.householdCount, maxHouseholds),
                  key: const Key('usage-households'),
                ),
                if (isOwner && family.plan == PlanId.free) ...[
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    key: const Key('see-plans'),
                    onPressed: () => showUpsellDialog(context, UpsellReason.invites),
                    icon: const Icon(Icons.workspace_premium_outlined),
                    label: Text(l10n.familySeePlans),
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        ListTile(
          key: const Key('go-members'),
          leading: const Icon(Icons.people_outline),
          title: Text(l10n.membersTitle),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => context.go(Routes.familyMembers),
        ),
        ListTile(
          key: const Key('go-households'),
          leading: const Icon(Icons.home_work_outlined),
          title: Text(l10n.householdsTitle),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => context.go(Routes.familyHouseholds),
        ),
      ],
    );
  }
}

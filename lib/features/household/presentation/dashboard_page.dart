import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:planly/app/router/routes.dart';
import 'package:planly/core/widgets/async_value_view.dart';
import 'package:planly/core/widgets/state_widgets.dart';
import 'package:planly/features/family/presentation/family_frozen_banner.dart';
import 'package:planly/features/household/application/household_providers.dart';
import 'package:planly/features/household/domain/household_models.dart';
import 'package:planly/features/household/presentation/switch_context_sheet.dart';
import 'package:planly/l10n/app_localizations.dart';

/// Dashboard (spec §1 #4): casa ativa + seletor, indicador de sync e placeholders honestos —
/// as tarefas reais chegam na Sprint 3.
class DashboardPage extends ConsumerWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final households = ref.watch(accessibleHouseholdsProvider);
    final active = ref.watch(activeHouseholdProvider);
    final meta = households.value?.meta;

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
              data: (context, snap) => _Content(household: active),
            ),
          ),
        ],
      ),
    );
  }
}

class _Content extends StatelessWidget {
  const _Content({required this.household});

  final Household? household;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return ListView(
      key: const Key('dashboard-content'),
      padding: const EdgeInsets.all(16),
      children: [
        Text(l10n.homeGreeting, style: theme.textTheme.headlineSmall),
        const SizedBox(height: 4),
        Text(l10n.dashboardComingSoon),
        const SizedBox(height: 16),
        _Section(title: l10n.dashboardToday),
        _Section(title: l10n.dashboardUpcoming),
        _Section(title: l10n.dashboardLists),
      ],
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Card(
      child: ListTile(
        title: Text(title),
        subtitle: Text(l10n.dashboardSectionSoon),
        leading: const Icon(Icons.hourglass_empty),
      ),
    );
  }
}

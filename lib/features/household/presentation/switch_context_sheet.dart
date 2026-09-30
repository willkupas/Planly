import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:planly/features/family/application/active_context.dart';
import 'package:planly/features/family/application/family_providers.dart';
import 'package:planly/features/family/domain/family_models.dart';
import 'package:planly/features/household/application/household_providers.dart';
import 'package:planly/l10n/app_localizations.dart';

/// Troca de família/casa ativa (spec §1 #18). Famílias vêm das memberships; casas, da query
/// `accessUids array-contains uid` (ou todas, para o owner). Persiste em SharedPreferences.
Future<void> showSwitchContextSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => const SwitchContextSheet(),
  );
}

class SwitchContextSheet extends ConsumerWidget {
  const SwitchContextSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final memberships = ref.watch(membershipsProvider).value ?? const <FamilyMembership>[];
    final activeFamilyId = ref.watch(activeFamilyIdProvider);
    final households = ref.watch(accessibleHouseholdsProvider).value?.items ?? const [];
    final activeHouseholdId = ref.watch(activeHouseholdProvider)?.id;
    final notifier = ref.read(activeContextProvider.notifier);

    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.8),
        child: ListView(
          shrinkWrap: true,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
              child: Text(l10n.switchFamilies, style: theme.textTheme.titleSmall),
            ),
            for (final m in memberships)
              ListTile(
                key: Key('switch-family-${m.familyId}'),
                leading: Icon(m.familyId == activeFamilyId ? Icons.radio_button_checked : Icons.radio_button_off),
                title: Text(m.familyName.isEmpty ? l10n.familyTitle : m.familyName),
                subtitle: Text(m.isOwner ? l10n.roleOwner : l10n.roleMember),
                selected: m.familyId == activeFamilyId,
                onTap: () => notifier.selectFamily(m.familyId),
              ),
            const Divider(),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: Text(l10n.switchHouseholds, style: theme.textTheme.titleSmall),
            ),
            if (households.isEmpty)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(l10n.switchNoHouseholds),
              ),
            for (final h in households)
              ListTile(
                key: Key('switch-household-${h.id}'),
                leading: Icon(h.id == activeHouseholdId ? Icons.radio_button_checked : Icons.radio_button_off),
                title: Text(h.name),
                selected: h.id == activeHouseholdId,
                onTap: () async {
                  if (activeFamilyId == null) return;
                  await notifier.selectHousehold(activeFamilyId, h.id);
                  if (context.mounted) Navigator.pop(context);
                },
              ),
          ],
        ),
      ),
    );
  }
}

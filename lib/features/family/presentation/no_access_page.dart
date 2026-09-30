import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:planly/app/router/routes.dart';
import 'package:planly/features/family/application/family_providers.dart';
import 'package:planly/features/family/domain/family_models.dart';
import 'package:planly/features/household/application/household_providers.dart';
import 'package:planly/features/household/presentation/switch_context_sheet.dart';
import 'package:planly/l10n/app_localizations.dart';

/// "Sem acesso a esta casa" (spec §2.2 ordens 5–6): família em exclusão ou membro sem casa
/// vinculada. Sempre oferece um caminho: trocar de família, tentar de novo, configurações.
class NoAccessPage extends ConsumerWidget {
  const NoAccessPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final deleting = ref.watch(activeFamilyStatusProvider) == FamilyStatus.deleting;
    final canSwitch = (ref.watch(membershipsProvider).value?.length ?? 0) > 1;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Icon(Icons.lock_outline, size: 56),
                  const SizedBox(height: 16),
                  Text(
                    l10n.noAccessTitle,
                    style: Theme.of(context).textTheme.headlineSmall,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    deleting ? l10n.noAccessDeleting : l10n.noAccessNoHousehold,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  if (canSwitch)
                    FilledButton(
                      key: const Key('no-access-switch'),
                      onPressed: () => showSwitchContextSheet(context),
                      child: Text(l10n.noAccessSwitch),
                    ),
                  if (!deleting)
                    OutlinedButton(
                      key: const Key('no-access-retry'),
                      onPressed: () => ref.invalidate(accessibleHouseholdsProvider),
                      child: Text(l10n.actionRetry),
                    ),
                  TextButton(
                    key: const Key('no-access-settings'),
                    onPressed: () => context.push(Routes.settings),
                    child: Text(l10n.settingsTitle),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

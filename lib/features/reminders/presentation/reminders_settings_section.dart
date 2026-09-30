import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:planly/core/widgets/ui_actions.dart';
import 'package:planly/features/reminders/application/reminder_providers.dart';
import 'package:planly/features/reminders/domain/notification_gateway.dart';
import 'package:planly/l10n/app_localizations.dart';

/// Seção "Lembretes" das Configurações: liga/desliga local, estado da permissão do sistema e
/// atalhos para pedir a permissão (com explicação antes) ou abrir os ajustes do sistema.
class RemindersSettingsSection extends ConsumerStatefulWidget {
  const RemindersSettingsSection({super.key});

  @override
  ConsumerState<RemindersSettingsSection> createState() => _RemindersSettingsSectionState();
}

class _RemindersSettingsSectionState extends ConsumerState<RemindersSettingsSection>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Ao voltar dos ajustes do sistema, relê a permissão.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref.read(reminderPermissionProvider.notifier).refresh();
    }
  }

  Future<void> _allow() async {
    final l10n = AppLocalizations.of(context);
    final ok = await confirmDialog(
      context,
      title: l10n.remindersPermissionExplainTitle,
      message: l10n.remindersPermissionExplainMessage,
      confirmLabel: l10n.remindersPermissionContinue,
    );
    if (!ok || !mounted) return;
    final result = await ref.read(reminderPermissionProvider.notifier).request();
    if (!mounted || result == NotificationPermission.granted) return;
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(l10n.remindersPermissionStillDenied)));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final enabled = ref.watch(remindersEnabledProvider);
    final permission = ref.watch(reminderPermissionProvider).value;
    final denied = permission != null && !permission.granted;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
          child: Text(
            l10n.remindersSectionTitle,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(color: Theme.of(context).colorScheme.primary),
          ),
        ),
        SwitchListTile(
          key: const Key('reminders-switch'),
          secondary: const Icon(Icons.notifications_outlined),
          title: Text(l10n.remindersSwitchTitle),
          subtitle: Text(l10n.remindersSwitchSubtitle),
          value: enabled,
          onChanged: (v) => ref.read(remindersEnabledProvider.notifier).set(v),
        ),
        if (permission != null)
          ListTile(
            key: const Key('reminders-permission'),
            leading: Icon(denied ? Icons.notifications_off_outlined : Icons.check_circle_outline),
            title: Text(denied ? l10n.remindersPermissionDenied : l10n.remindersPermissionGranted),
            subtitle: denied ? Text(l10n.remindersPermissionDeniedHelp) : null,
          ),
        if (denied)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Align(
              alignment: Alignment.centerLeft,
              child: permission.asked
                  ? OutlinedButton(
                      key: const Key('reminders-open-settings'),
                      onPressed: () => ref.read(reminderPermissionProvider.notifier).openSystemSettings(),
                      child: Text(l10n.remindersPermissionOpenSettings),
                    )
                  : FilledButton(
                      key: const Key('reminders-allow'),
                      onPressed: _allow,
                      child: Text(l10n.remindersPermissionAllow),
                    ),
            ),
          ),
        const SizedBox(height: 8),
      ],
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:planly/app/router/routes.dart';
import 'package:planly/features/auth/application/auth_providers.dart';
import 'package:planly/features/reminders/presentation/reminders_settings_section.dart';
import 'package:planly/features/settings/presentation/sign_out_flow.dart';
import 'package:planly/l10n/app_localizations.dart';

/// Configurações mínimas (spec §1 #19): conta, idioma e sair. Timezone editável,
/// notificações e excluir conta entram em tarefas futuras.
class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  String _initial(String? name, String? email) {
    final source = (name?.trim().isNotEmpty ?? false) ? name! : (email ?? '');
    return source.isEmpty ? '?' : source.characters.first.toUpperCase();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final user = ref.watch(currentUserProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.settingsTitle)),
      body: ListView(
        children: [
          ListTile(
            leading: ExcludeSemantics(child: CircleAvatar(child: Text(_initial(user?.displayName, user?.email)))),
            title: Text(user?.displayName ?? l10n.settingsNoName),
            subtitle: user?.email == null ? null : Text(user!.email!),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.language),
            title: Text(l10n.settingsLanguage),
            subtitle: Text(l10n.settingsLanguagePt),
          ),
          const Divider(),
          const RemindersSettingsSection(),
          const Divider(),
          ListTile(
            key: const Key('logout'),
            leading: const Icon(Icons.logout),
            title: Text(l10n.logout),
            onTap: () => signOutWithWarning(context, ref),
          ),
          ListTile(
            key: const Key('delete-account'),
            leading: Icon(Icons.delete_forever_outlined, color: Theme.of(context).colorScheme.error),
            title: Text(l10n.deleteAccountEntry),
            subtitle: Text(l10n.deleteAccountEntrySubtitle),
            onTap: () => context.push(Routes.deleteAccount),
          ),
        ],
      ),
    );
  }
}

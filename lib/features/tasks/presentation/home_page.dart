import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:planly/features/auth/application/auth_providers.dart';
import 'package:planly/l10n/app_localizations.dart';

/// Placeholder do dashboard (`/home`). A tela real vem com a T-014.
class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.homeTitle),
        actions: [
          // Provisório até a tela de Configurações (spec §1 #19).
          IconButton(
            key: const Key('logout'),
            tooltip: l10n.logout,
            icon: const Icon(Icons.logout),
            onPressed: () => ref.read(signOutControllerProvider.notifier).signOut(),
          ),
        ],
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(l10n.homeGreeting, style: Theme.of(context).textTheme.headlineMedium),
              const SizedBox(height: 12),
              Text(l10n.homePlaceholder, textAlign: TextAlign.center),
            ],
          ),
        ),
      ),
    );
  }
}

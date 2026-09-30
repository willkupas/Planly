import 'package:flutter/material.dart';
import 'package:planly/l10n/app_localizations.dart';

/// Placeholder do dashboard (`/home`). A tela real vem com a T-014.
class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.homeTitle)),
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

import 'package:flutter/material.dart';
import 'package:planly/l10n/app_localizations.dart';

/// Enquanto a sessão é resolvida. O redirect do router tira o usuário daqui.
class SplashPage extends StatelessWidget {
  const SplashPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(l10n.appName, style: Theme.of(context).textTheme.displaySmall),
            const SizedBox(height: 24),
            Semantics(
              label: l10n.splashLoading,
              child: const CircularProgressIndicator(),
            ),
          ],
        ),
      ),
    );
  }
}

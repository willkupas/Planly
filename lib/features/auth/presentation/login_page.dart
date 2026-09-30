import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:planly/core/l10n_helpers/failure_message.dart';
import 'package:planly/features/auth/application/auth_providers.dart';
import 'package:planly/features/auth/domain/auth_provider_id.dart';
import 'package:planly/l10n/app_localizations.dart';

class LoginPage extends ConsumerWidget {
  const LoginPage({super.key});

  String _label(AppLocalizations l10n, AuthProviderId id) => switch (id) {
        AuthProviderId.google => l10n.loginWithGoogle,
      };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final providers = ref.watch(availableAuthProvidersProvider);
    final signIn = ref.watch(signInControllerProvider);
    final loading = signIn.isLoading;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    l10n.appName,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.displaySmall,
                  ),
                  const SizedBox(height: 8),
                  Text(l10n.loginSubtitle, textAlign: TextAlign.center),
                  const SizedBox(height: 32),
                  for (final id in providers)
                    FilledButton.icon(
                      key: Key('login-${id.name}'),
                      onPressed: loading ? null : () => ref.read(signInControllerProvider.notifier).signIn(id),
                      icon: loading
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.login),
                      label: Text(loading ? l10n.loginSigningIn : _label(l10n, id)),
                    ),
                  if (signIn.hasError) ...[
                    const SizedBox(height: 16),
                    Semantics(
                      liveRegion: true,
                      child: Text(
                        failureMessage(l10n, signIn.error!),
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Theme.of(context).colorScheme.error),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

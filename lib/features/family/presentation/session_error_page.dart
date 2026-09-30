import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:planly/core/l10n_helpers/failure_message.dart';
import 'package:planly/core/widgets/state_widgets.dart';
import 'package:planly/features/auth/application/user_profile_providers.dart';
import 'package:planly/features/family/application/family_providers.dart';
import 'package:planly/features/settings/presentation/sign_out_flow.dart';
import 'package:planly/l10n/app_localizations.dart';

/// Falha ao ler o contexto da sessão (perfil/memberships) sem cache: tentar de novo ou sair.
class SessionErrorPage extends ConsumerWidget {
  const SessionErrorPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final error = ref.watch(membershipsProvider).error ?? ref.watch(userProfileProvider).error;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ErrorState(
                message: failureMessage(l10n, error ?? Object()),
                onRetry: () {
                  ref.invalidate(membershipsProvider);
                  ref.invalidate(userProfileProvider);
                },
              ),
            ),
            TextButton(
              key: const Key('session-error-sign-out'),
              onPressed: () => signOutWithWarning(context, ref),
              child: Text(l10n.logout),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

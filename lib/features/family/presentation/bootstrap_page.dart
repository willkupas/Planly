import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:planly/core/connectivity/connectivity_provider.dart';
import 'package:planly/core/error/app_failure.dart';
import 'package:planly/core/l10n_helpers/failure_message.dart';
import 'package:planly/features/family/application/bootstrap_controller.dart';
import 'package:planly/features/settings/presentation/sign_out_flow.dart';
import 'package:planly/l10n/app_localizations.dart';

/// Primeiro acesso (spec §1 #3): cria a Family Free + casa inicial via `bootstrapUser`.
/// Só-online: sem internet mostra aviso claro e espera o usuário reconectar e tentar de novo.
class BootstrapPage extends ConsumerStatefulWidget {
  const BootstrapPage({super.key});

  @override
  ConsumerState<BootstrapPage> createState() => _BootstrapPageState();
}

class _BootstrapPageState extends ConsumerState<BootstrapPage> {
  @override
  void initState() {
    super.initState();
    // Dispara uma vez ao entrar; erros ficam no estado do controller.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ref.read(bootstrapControllerProvider.notifier).run();
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final state = ref.watch(bootstrapControllerProvider);
    final online = ref.watch(isOnlineProvider);
    final offline = !online || (state.hasError && state.error is NetworkFailure);

    final Widget content;
    if (state.hasError) {
      content = _Message(
        key: const Key('bootstrap-error'),
        icon: offline ? Icons.cloud_off : Icons.error_outline,
        title: offline ? l10n.bootstrapOfflineTitle : l10n.bootstrapErrorTitle,
        message: offline ? l10n.bootstrapOfflineMessage : failureMessage(l10n, state.error!),
        action: FilledButton(
          key: const Key('bootstrap-retry'),
          onPressed: () => ref.read(bootstrapControllerProvider.notifier).run(),
          child: Text(l10n.actionRetry),
        ),
      );
    } else if (!online && !state.isLoading) {
      content = _Message(
        key: const Key('bootstrap-offline'),
        icon: Icons.cloud_off,
        title: l10n.bootstrapOfflineTitle,
        message: l10n.bootstrapOfflineMessage,
        action: FilledButton(
          key: const Key('bootstrap-retry'),
          onPressed: () => ref.read(bootstrapControllerProvider.notifier).run(),
          child: Text(l10n.actionRetry),
        ),
      );
    } else {
      content = _Message(
        key: const Key('bootstrap-loading'),
        icon: Icons.home_outlined,
        title: l10n.bootstrapLoadingTitle,
        message: l10n.bootstrapLoadingMessage,
        action: Semantics(
          label: l10n.splashLoading,
          child: const CircularProgressIndicator(),
        ),
      );
    }

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(child: content),
            TextButton(
              key: const Key('bootstrap-sign-out'),
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

class _Message extends StatelessWidget {
  const _Message({super.key, required this.icon, required this.title, required this.message, required this.action});

  final IconData icon;
  final String title;
  final String message;
  final Widget action;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 56),
              const SizedBox(height: 16),
              Text(title, style: Theme.of(context).textTheme.headlineSmall, textAlign: TextAlign.center),
              const SizedBox(height: 8),
              Semantics(liveRegion: true, child: Text(message, textAlign: TextAlign.center)),
              const SizedBox(height: 24),
              action,
            ],
          ),
        ),
      ),
    );
  }
}

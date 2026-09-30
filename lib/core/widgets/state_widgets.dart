import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:planly/core/connectivity/connectivity_provider.dart';
import 'package:planly/core/sync/sync_status.dart';
import 'package:planly/l10n/app_localizations.dart';

/// Placeholder estático de carregamento (skeleton, sem spinner de tela cheia).
class LoadingSkeleton extends StatelessWidget {
  const LoadingSkeleton({super.key, this.rows = 3});

  final int rows;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.surfaceContainerHighest;
    return Semantics(
      label: AppLocalizations.of(context).splashLoading,
      child: ExcludeSemantics(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              for (var i = 0; i < rows; i++)
                Container(
                  height: 64,
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(12)),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class EmptyState extends StatelessWidget {
  const EmptyState({super.key, required this.icon, required this.title, this.message, this.action});

  final IconData icon;
  final String title;
  final String? message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 56, color: theme.colorScheme.outline),
            const SizedBox(height: 16),
            Text(title, style: theme.textTheme.titleMedium, textAlign: TextAlign.center),
            if (message != null) ...[
              const SizedBox(height: 8),
              Text(message!, textAlign: TextAlign.center),
            ],
            if (action != null) ...[const SizedBox(height: 16), action!],
          ],
        ),
      ),
    );
  }
}

class ErrorState extends StatelessWidget {
  const ErrorState({super.key, required this.message, this.onRetry});

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 48, color: Theme.of(context).colorScheme.error),
            const SizedBox(height: 12),
            Semantics(liveRegion: true, child: Text(message, textAlign: TextAlign.center)),
            if (onRetry != null) ...[
              const SizedBox(height: 16),
              FilledButton.tonal(onPressed: onRetry, child: Text(l10n.actionRetry)),
            ],
          ],
        ),
      ),
    );
  }
}

/// Faixa discreta quando não há rede; não bloqueia nada (spec §5.1).
class OfflineBanner extends ConsumerWidget {
  const OfflineBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (ref.watch(isOnlineProvider)) return const SizedBox.shrink();
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.secondaryContainer,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            Icon(Icons.cloud_off, size: 18, color: scheme.onSecondaryContainer),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                AppLocalizations.of(context).offlineBanner,
                style: TextStyle(color: scheme.onSecondaryContainer),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Indicador de sync (spec §5.2). "Sincronizado" some depois de ~2 s.
class SyncIndicator extends ConsumerStatefulWidget {
  const SyncIndicator({super.key, required this.meta});

  final SyncMeta meta;

  @override
  ConsumerState<SyncIndicator> createState() => _SyncIndicatorState();
}

class _SyncIndicatorState extends ConsumerState<SyncIndicator> {
  bool _showSynced = true;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _scheduleHide();
  }

  void _scheduleHide() {
    _timer?.cancel();
    _timer = Timer(const Duration(seconds: 2), () {
      if (mounted) setState(() => _showSynced = false);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  void didUpdateWidget(SyncIndicator old) {
    super.didUpdateWidget(old);
    if (old.meta != widget.meta) {
      _showSynced = true;
      _scheduleHide();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final status = syncStatusFor(widget.meta, online: ref.watch(isOnlineProvider));
    if (status == SyncStatus.synced && !_showSynced) return const SizedBox.shrink();
    final (icon, label) = switch (status) {
      SyncStatus.savedLocally => (Icons.save_outlined, l10n.syncSavedLocally),
      SyncStatus.syncing => (Icons.sync, l10n.syncSyncing),
      SyncStatus.synced => (Icons.cloud_done_outlined, l10n.syncSynced),
      SyncStatus.offline => (Icons.cloud_off, l10n.syncOffline),
    };
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Tooltip(
        message: label,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18),
            const SizedBox(width: 4),
            Text(label, style: Theme.of(context).textTheme.labelSmall),
          ],
        ),
      ),
    );
  }
}

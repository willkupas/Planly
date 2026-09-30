import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:planly/app/router/routes.dart';
import 'package:planly/core/connectivity/connectivity_provider.dart';
import 'package:planly/core/l10n_helpers/failure_message.dart';
import 'package:planly/core/widgets/state_widgets.dart';
import 'package:planly/features/family/domain/family_models.dart';
import 'package:planly/features/settings/application/account_deletion.dart';
import 'package:planly/l10n/app_localizations.dart';

/// Excluir conta (spec flutter-app §1 #20, §8.4; T-025). Explica o que será apagado e o que
/// permanece, avisa da assinatura, bloqueia se for owner de família com participantes e exige
/// a palavra de confirmação. Só online. Ao concluir, o logout local leva ao login.
class DeleteAccountPage extends ConsumerStatefulWidget {
  const DeleteAccountPage({super.key});

  @override
  ConsumerState<DeleteAccountPage> createState() => _DeleteAccountPageState();
}

class _DeleteAccountPageState extends ConsumerState<DeleteAccountPage> {
  final _word = TextEditingController();

  @override
  void dispose() {
    _word.dispose();
    super.dispose();
  }

  static String _names(List<FamilyMembership> list) => list.map((m) => m.familyName).join(', ');

  bool _confirmed(AppLocalizations l10n) =>
      _word.text.trim().toUpperCase() == l10n.deleteAccountConfirmWord.toUpperCase();

  void _showSubscriptionHelp(AppLocalizations l10n) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.deleteAccountManageSubscriptionHelpTitle),
        content: Text(l10n.deleteAccountManageSubscriptionHelp),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: Text(l10n.actionOk))],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final preview = ref.watch(accountDeletionPreviewProvider);
    final deletion = ref.watch(accountDeletionControllerProvider);
    final online = ref.watch(isOnlineProvider);
    final controller = ref.read(accountDeletionControllerProvider.notifier);

    final data = preview.value;
    final blocked = (data?.isBlocked ?? false) || deletion.blockedByServer;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.deleteAccountTitle)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(l10n.deleteAccountIntro, style: theme.textTheme.titleMedium),
          const SizedBox(height: 16),
          if (preview.isLoading && data == null)
            const LoadingSkeleton(rows: 2)
          else if (data == null)
            Text(l10n.deleteAccountLoadError, style: TextStyle(color: theme.colorScheme.error))
          else ...[
            _Section(
              title: l10n.deleteAccountWhatDeletedTitle,
              lines: [
                l10n.deleteAccountWhatDeletedAccount,
                data.deletedFamilies.isEmpty
                    ? l10n.deleteAccountWhatDeletedFamilies
                    : l10n.deleteAccountWhatDeletedFamiliesNamed(
                        data.deletedFamilies.length,
                        _names(data.deletedFamilies),
                      ),
              ],
            ),
            const SizedBox(height: 12),
            _Section(
              title: l10n.deleteAccountWhatStaysTitle,
              lines: [
                data.leftFamilies.isEmpty
                    ? l10n.deleteAccountWhatStays
                    : l10n.deleteAccountWhatStaysNamed(_names(data.leftFamilies)),
              ],
            ),
            if (data.hasActivePaidFamily) ...[
              const SizedBox(height: 12),
              Card(
                key: const Key('delete-subscription-warning'),
                color: theme.colorScheme.tertiaryContainer,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(l10n.deleteAccountSubscriptionTitle, style: theme.textTheme.titleSmall),
                      const SizedBox(height: 8),
                      Text(l10n.deleteAccountSubscriptionMessage),
                      const SizedBox(height: 8),
                      TextButton.icon(
                        key: const Key('delete-manage-subscription'),
                        onPressed: () => _showSubscriptionHelp(l10n),
                        icon: const Icon(Icons.info_outline),
                        label: Text(l10n.deleteAccountManageSubscription),
                      ),
                    ],
                  ),
                ),
              ),
            ],
            const SizedBox(height: 16),
            if (blocked)
              Card(
                key: const Key('delete-blocked'),
                color: theme.colorScheme.errorContainer,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(l10n.deleteAccountBlockedTitle, style: theme.textTheme.titleSmall),
                      const SizedBox(height: 8),
                      Text(l10n.deleteAccountBlockedMessage),
                      if (data.blockedFamilies.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(l10n.deleteAccountBlockedFamilies(_names(data.blockedFamilies))),
                      ],
                      const SizedBox(height: 8),
                      FilledButton.tonal(
                        key: const Key('delete-go-members'),
                        onPressed: () => context.go(Routes.familyMembers),
                        child: Text(l10n.deleteAccountGoToMembers),
                      ),
                    ],
                  ),
                ),
              )
            else ...[
              if (!online)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    key: const Key('delete-offline'),
                    children: [
                      const Icon(Icons.cloud_off),
                      const SizedBox(width: 8),
                      Expanded(child: Text(l10n.deleteAccountOffline)),
                    ],
                  ),
                ),
              if (deletion.phase == DeletionPhase.needsReauth ||
                  deletion.phase == DeletionPhase.reauthenticating)
                Card(
                  key: const Key('delete-reauth'),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(l10n.deleteAccountReauthTitle, style: theme.textTheme.titleSmall),
                        const SizedBox(height: 8),
                        Text(l10n.deleteAccountReauthMessage),
                        const SizedBox(height: 8),
                        FilledButton(
                          key: const Key('delete-reauth-button'),
                          onPressed: deletion.busy ? null : controller.reauthenticateAndRetry,
                          child: Text(l10n.deleteAccountReauthButton),
                        ),
                      ],
                    ),
                  ),
                )
              else ...[
                TextField(
                  key: const Key('delete-confirm-field'),
                  controller: _word,
                  enabled: !deletion.busy,
                  textCapitalization: TextCapitalization.characters,
                  autocorrect: false,
                  decoration: InputDecoration(
                    labelText: l10n.deleteAccountConfirmLabel(l10n.deleteAccountConfirmWord),
                    border: const OutlineInputBorder(),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 12),
                FilledButton(
                  key: const Key('delete-account-button'),
                  style: FilledButton.styleFrom(
                    backgroundColor: theme.colorScheme.error,
                    foregroundColor: theme.colorScheme.onError,
                  ),
                  onPressed: _confirmed(l10n) && !deletion.busy ? controller.submit : null,
                  child: Text(l10n.deleteAccountButton),
                ),
              ],
              if (deletion.busy)
                Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: Row(
                    key: const Key('delete-working'),
                    children: [
                      const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
                      const SizedBox(width: 12),
                      Expanded(child: Text(l10n.deleteAccountWorking)),
                    ],
                  ),
                ),
            ],
            if (deletion.phase == DeletionPhase.failed && !deletion.blockedByServer)
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: Text(
                  failureMessage(l10n, deletion.failure!),
                  key: const Key('delete-error'),
                  style: TextStyle(color: theme.colorScheme.error),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.lines});

  final String title;
  final List<String> lines;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: theme.textTheme.titleSmall),
            const SizedBox(height: 8),
            for (final line in lines)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('•  '),
                    Expanded(child: Text(line)),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:planly/core/share/share_service.dart';
import 'package:planly/core/time/clock.dart';
import 'package:planly/core/widgets/async_value_view.dart';
import 'package:planly/core/widgets/state_widgets.dart';
import 'package:planly/core/widgets/ui_actions.dart';
import 'package:planly/features/family/application/family_providers.dart';
import 'package:planly/features/family/presentation/family_frozen_banner.dart';
import 'package:planly/features/household/application/household_providers.dart';
import 'package:planly/features/household/domain/household_models.dart';
import 'package:planly/features/invitation/application/invitation_providers.dart';
import 'package:planly/features/invitation/domain/invitation_models.dart';
import 'package:planly/features/invitation/presentation/invite_formatting.dart';
import 'package:planly/l10n/app_localizations.dart';

String _statusLabel(AppLocalizations l10n, InvitationStatus s) => switch (s) {
      InvitationStatus.pending => l10n.invitationStatusPending,
      InvitationStatus.accepted => l10n.invitationStatusAccepted,
      InvitationStatus.expired => l10n.invitationStatusExpired,
      InvitationStatus.revoked => l10n.invitationStatusRevoked,
    };

/// Convites enviados pelo owner (pendentes/aceitos/expirados/revogados). O código aparece
/// mascarado na lista e completo só no detalhe de um convite pendente.
class InvitationsPage extends ConsumerWidget {
  const InvitationsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final isOwner = ref.watch(isOwnerProvider);
    final now = ref.watch(clockProvider)();

    final Widget body;
    if (!isOwner) {
      body = EmptyState(icon: Icons.lock_outline, title: l10n.errorPermissionDenied);
    } else {
      body = AsyncValueView<List<Invitation>>(
        value: ref.watch(familyInvitationsProvider),
        onRetry: () => ref.invalidate(familyInvitationsProvider),
        isEmpty: (l) => l.isEmpty,
        empty: EmptyState(
          icon: Icons.mail_outline,
          title: l10n.invitationsEmpty,
          message: l10n.invitationsEmptyMessage,
        ),
        data: (context, list) => ListView(
          children: [
            for (final inv in list) _InvitationTile(invitation: inv, now: now),
          ],
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text(l10n.inviteSentList)),
      body: Column(
        children: [
          const OfflineBanner(),
          const FamilyFrozenBanner(),
          Expanded(child: body),
        ],
      ),
    );
  }
}

class _InvitationTile extends StatelessWidget {
  const _InvitationTile({required this.invitation, required this.now});

  final Invitation invitation;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final status = invitation.effectiveStatus(now);
    final pending = status == InvitationStatus.pending;
    return ListTile(
      key: Key('invitation-${invitation.code}'),
      leading: Icon(switch (status) {
        InvitationStatus.pending => Icons.schedule_send_outlined,
        InvitationStatus.accepted => Icons.check_circle_outline,
        InvitationStatus.expired => Icons.timer_off_outlined,
        InvitationStatus.revoked => Icons.block,
      }),
      title: Text(maskInviteCode(invitation.code)),
      subtitle: Text(
        pending
            ? l10n.invitationPendingSubtitle(formatDateTimeShort(invitation.expiresAt))
            : _statusLabel(l10n, status),
      ),
      trailing: pending ? const Icon(Icons.chevron_right) : null,
      onTap: pending
          ? () => showModalBottomSheet<void>(
                context: context,
                isScrollControlled: true,
                showDragHandle: true,
                builder: (_) => _InvitationDetail(invitation: invitation),
              )
          : null,
    );
  }
}

class _InvitationDetail extends ConsumerWidget {
  const _InvitationDetail({required this.invitation});

  final Invitation invitation;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final canWrite = ref.watch(familyWriteAccessProvider);
    final households = ref.watch(accessibleHouseholdsProvider).value?.items ?? const <Household>[];
    final names = {for (final h in households) h.id: h.name};
    final code = formatInviteCode(invitation.code);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l10n.invitationDetailTitle, style: theme.textTheme.titleMedium),
            const SizedBox(height: 12),
            Center(
              child: SelectableText(
                code,
                key: const Key('invitation-detail-code'),
                style: theme.textTheme.headlineSmall?.copyWith(letterSpacing: 2),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              l10n.inviteValidUntil(formatDateTimeShort(invitation.expiresAt)),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            for (final g in invitation.grants)
              if (names[g.householdId] != null)
                Text(
                  l10n.invitationRoleIn(
                    names[g.householdId]!,
                    g.role == HouseholdRole.admin ? l10n.accessAdmin : l10n.accessMember,
                  ),
                ),
            const SizedBox(height: 16),
            FilledButton.icon(
              key: const Key('invitation-detail-share'),
              icon: const Icon(Icons.share),
              label: Text(l10n.inviteShare),
              onPressed: () => runUiAction(
                context,
                () => ref.read(shareTextProvider)(
                  l10n.inviteShareMessage(code, '').trim(),
                  subject: l10n.inviteShareSubject,
                ),
              ),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              key: const Key('invitation-revoke'),
              icon: const Icon(Icons.block),
              label: Text(l10n.invitationRevoke),
              onPressed: canWrite
                  ? () async {
                      final ok = await confirmDialog(
                        context,
                        title: l10n.invitationRevokeTitle,
                        message: l10n.invitationRevokeMessage,
                        confirmLabel: l10n.invitationRevoke,
                        destructive: true,
                      );
                      if (!ok || !context.mounted) return;
                      final done = await runUiAction(
                        context,
                        () => ref.read(invitationActionsProvider).revoke(invitation.code),
                        successMessage: l10n.invitationRevoked,
                      );
                      if (done && context.mounted) Navigator.pop(context);
                    }
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}

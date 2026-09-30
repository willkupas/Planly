import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:planly/app/router/routes.dart';
import 'package:planly/core/widgets/async_value_view.dart';
import 'package:planly/core/widgets/state_widgets.dart';
import 'package:planly/core/widgets/ui_actions.dart';
import 'package:planly/features/auth/application/auth_providers.dart';
import 'package:planly/features/family/application/family_actions.dart';
import 'package:planly/features/family/application/family_providers.dart';
import 'package:planly/features/family/domain/family_models.dart';
import 'package:planly/features/family/presentation/family_frozen_banner.dart';
import 'package:planly/features/household/presentation/member_access_sheet.dart';
import 'package:planly/features/family/presentation/upsell_dialog.dart';
import 'package:planly/l10n/app_localizations.dart';

/// Membros da família (spec §1 #13). Owner: convidar (T-015), remover, editar acesso por casa.
/// Membro: sair da família.
class MembersPage extends ConsumerWidget {
  const MembersPage({super.key});

  Future<void> _invite(BuildContext context, WidgetRef ref) async {
    final entitlement = ref.read(activeEntitlementProvider).value;
    if (entitlement == null || !entitlement.invitesEnabled) {
      await showUpsellDialog(context, UpsellReason.invites);
      return;
    }
    await context.push(Routes.familyInvite);
  }

  Future<void> _remove(BuildContext context, WidgetRef ref, String familyId, FamilyMember m) async {
    final l10n = AppLocalizations.of(context);
    final name = m.displayName ?? l10n.memberNoName;
    final ok = await confirmDialog(
      context,
      title: l10n.memberRemoveTitle,
      message: l10n.memberRemoveMessage(name),
      confirmLabel: l10n.memberRemove,
      destructive: true,
    );
    if (!ok || !context.mounted) return;
    await runUiAction(
      context,
      () => ref.read(familyActionsProvider).removeMember(familyId, m.uid),
      successMessage: l10n.memberRemoved,
    );
  }

  Future<void> _leave(BuildContext context, WidgetRef ref, String familyId) async {
    final l10n = AppLocalizations.of(context);
    final ok = await confirmDialog(
      context,
      title: l10n.leaveFamilyTitle,
      message: l10n.leaveFamilyMessage,
      confirmLabel: l10n.leaveFamily,
      destructive: true,
    );
    if (!ok || !context.mounted) return;
    final router = GoRouter.of(context);
    final done = await runUiAction(context, () => ref.read(familyActionsProvider).leaveFamily(familyId));
    // A membership some via stream; o contexto ativo cai para outra família automaticamente.
    if (done) router.go(Routes.home);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final familyId = ref.watch(activeFamilyIdProvider);
    final isOwner = ref.watch(isOwnerProvider);
    final canWrite = ref.watch(familyWriteAccessProvider);
    final myUid = ref.watch(currentUidProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.membersTitle),
        actions: [
          if (isOwner)
            IconButton(
              key: const Key('invitations-button'),
              tooltip: l10n.inviteSentList,
              icon: const Icon(Icons.mail_outline),
              onPressed: () => context.push(Routes.familyInvitations),
            ),
        ],
      ),
      body: familyId == null
          ? const LoadingSkeleton()
          : Column(
              children: [
                const OfflineBanner(),
                const FamilyFrozenBanner(),
                Expanded(
                  child: AsyncValueView<List<FamilyMember>>(
                    value: ref.watch(familyMembersProvider(familyId)),
                    onRetry: () => ref.invalidate(familyMembersProvider(familyId)),
                    isEmpty: (list) => list.isEmpty,
                    empty: EmptyState(icon: Icons.people_outline, title: l10n.membersEmpty),
                    data: (context, members) => ListView(
                      children: [
                        for (final m in members)
                          _MemberTile(
                            member: m,
                            isMe: m.uid == myUid,
                            trailing: _trailing(context, ref, familyId, m,
                                isOwner: isOwner, canWrite: canWrite, isMe: m.uid == myUid),
                          ),
                        if (isOwner)
                          Padding(
                            padding: const EdgeInsets.all(16),
                            child: FilledButton.icon(
                              key: const Key('invite-button'),
                              onPressed: canWrite ? () => _invite(context, ref) : null,
                              icon: const Icon(Icons.person_add_alt_1),
                              label: Text(l10n.inviteButton),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget? _trailing(
    BuildContext context,
    WidgetRef ref,
    String familyId,
    FamilyMember m, {
    required bool isOwner,
    required bool canWrite,
    required bool isMe,
  }) {
    final l10n = AppLocalizations.of(context);
    if (isOwner && !m.isOwner) {
      return PopupMenuButton<String>(
        key: Key('member-menu-${m.uid}'),
        tooltip: l10n.memberActions,
        onSelected: (v) {
          if (v == 'access') showMemberAccessSheet(context, m);
          if (v == 'remove') _remove(context, ref, familyId, m);
        },
        itemBuilder: (_) => [
          PopupMenuItem(value: 'access', enabled: canWrite, child: Text(l10n.memberAccess)),
          PopupMenuItem(value: 'remove', child: Text(l10n.memberRemove)),
        ],
      );
    }
    if (isMe && !isOwner) {
      return TextButton(
        key: const Key('leave-family'),
        onPressed: () => _leave(context, ref, familyId),
        child: Text(l10n.leaveFamily),
      );
    }
    return null;
  }
}

class _MemberTile extends StatelessWidget {
  const _MemberTile({required this.member, required this.isMe, this.trailing});

  final FamilyMember member;
  final bool isMe;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final name = member.displayName?.trim().isNotEmpty == true ? member.displayName! : l10n.memberNoName;
    return ListTile(
      key: Key('member-${member.uid}'),
      leading: ExcludeSemantics(child: CircleAvatar(child: Text(name.characters.first.toUpperCase()))),
      title: Text(isMe ? l10n.memberYou(name) : name),
      subtitle: Text(member.isOwner ? l10n.roleOwner : l10n.roleMember),
      trailing: trailing,
    );
  }
}

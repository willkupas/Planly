import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:planly/app/router/routes.dart';
import 'package:planly/core/share/share_service.dart';
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

/// Convidar (spec §1 #14): owner de plano pago escolhe casas + papel, gera o código (24h) e
/// compartilha. O Free nunca chega a chamar a Function (upsell). O código só existe em memória
/// nesta tela.
class InvitePage extends ConsumerStatefulWidget {
  const InvitePage({super.key});

  @override
  ConsumerState<InvitePage> createState() => _InvitePageState();
}

class _InvitePageState extends ConsumerState<InvitePage> {
  final Map<String, HouseholdRole> _selected = {};
  bool _selectionSeeded = false;
  bool _busy = false;
  CreatedInvitation? _created;

  Future<void> _generate(String familyId, List<Household> households) async {
    // Mantém a ordem da lista de casas.
    final grants = [
      for (final h in households)
        if (_selected.containsKey(h.id)) InviteGrant(householdId: h.id, role: _selected[h.id]!),
    ];
    if (grants.isEmpty) return;
    setState(() => _busy = true);
    CreatedInvitation? created;
    await runUiAction(context, () async {
      created = await ref.read(invitationActionsProvider).create(familyId, grants);
    });
    if (!mounted) return;
    setState(() {
      _busy = false;
      _created = created;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final familyId = ref.watch(activeFamilyIdProvider);
    final isOwner = ref.watch(isOwnerProvider);
    final entitlement = ref.watch(activeEntitlementProvider);

    final Widget body;
    if (familyId == null || entitlement.isLoading && !entitlement.hasValue) {
      body = const LoadingSkeleton();
    } else if (!isOwner) {
      body = EmptyState(icon: Icons.lock_outline, title: l10n.errorPermissionDenied);
    } else if (entitlement.value?.invitesEnabled != true) {
      body = EmptyState(
        key: const Key('invite-upsell'),
        icon: Icons.workspace_premium_outlined,
        title: l10n.upsellTitle,
        message: l10n.upsellInvitesMessage,
      );
    } else if (_created != null) {
      body = _Result(
        created: _created!,
        onAnother: () => setState(() {
          _created = null;
          _selected.clear();
          _selectionSeeded = false;
        }),
      );
    } else {
      body = _Form(
        selected: _selected,
        busy: _busy,
        onChanged: () => setState(() {}),
        onSeed: (id) {
          if (_selectionSeeded) return;
          _selectionSeeded = true;
          _selected[id] = HouseholdRole.member;
        },
        onGenerate: (households) => _generate(familyId, households),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text(l10n.inviteTitle)),
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

class _Form extends ConsumerWidget {
  const _Form({
    required this.selected,
    required this.busy,
    required this.onChanged,
    required this.onSeed,
    required this.onGenerate,
  });

  final Map<String, HouseholdRole> selected;
  final bool busy;
  final VoidCallback onChanged;
  final void Function(String householdId) onSeed;
  final void Function(List<Household> households) onGenerate;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final canWrite = ref.watch(familyWriteAccessProvider);
    return AsyncValueView<HouseholdsSnapshot>(
      value: ref.watch(accessibleHouseholdsProvider),
      onRetry: () => ref.invalidate(accessibleHouseholdsProvider),
      isEmpty: (s) => s.items.isEmpty,
      empty: EmptyState(icon: Icons.home_work_outlined, title: l10n.inviteNoHouseholds),
      data: (context, snap) {
        // Com uma única casa, já vem marcada (caso mais comum).
        if (snap.items.length == 1) onSeed(snap.items.first.id);
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(l10n.inviteIntro),
            const SizedBox(height: 16),
            Text(l10n.inviteHouseholdsLabel, style: Theme.of(context).textTheme.titleSmall),
            for (final h in snap.items) ...[
              CheckboxListTile(
                key: Key('invite-h-${h.id}'),
                contentPadding: EdgeInsets.zero,
                value: selected.containsKey(h.id),
                title: Text(h.name),
                onChanged: busy
                    ? null
                    : (v) {
                        if (v == true) {
                          selected[h.id] = HouseholdRole.member;
                        } else {
                          selected.remove(h.id);
                        }
                        onChanged();
                      },
              ),
              if (selected.containsKey(h.id))
                Padding(
                  padding: const EdgeInsets.only(left: 8, bottom: 8),
                  child: SegmentedButton<HouseholdRole>(
                    key: Key('invite-role-${h.id}'),
                    showSelectedIcon: false,
                    segments: [
                      ButtonSegment(value: HouseholdRole.member, label: Text(l10n.accessMember)),
                      ButtonSegment(value: HouseholdRole.admin, label: Text(l10n.accessAdmin)),
                    ],
                    selected: {selected[h.id]!},
                    onSelectionChanged: busy
                        ? null
                        : (s) {
                            selected[h.id] = s.first;
                            onChanged();
                          },
                  ),
                ),
            ],
            const SizedBox(height: 16),
            if (selected.isEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  l10n.inviteSelectAtLeastOne,
                  style: TextStyle(color: Theme.of(context).colorScheme.outline),
                ),
              ),
            FilledButton(
              key: const Key('invite-generate'),
              onPressed: busy || !canWrite || selected.isEmpty ? null : () => onGenerate(snap.items),
              child: busy
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : Text(l10n.inviteGenerate),
            ),
          ],
        );
      },
    );
  }
}

class _Result extends ConsumerWidget {
  const _Result({required this.created, required this.onAnother});

  final CreatedInvitation created;
  final VoidCallback onAnother;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final code = formatInviteCode(created.code);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(l10n.inviteCodeLabel, style: theme.textTheme.labelLarge),
        const SizedBox(height: 8),
        Card(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
            child: Center(
              child: SelectableText(
                code,
                key: const Key('invite-code'),
                style: theme.textTheme.headlineMedium?.copyWith(letterSpacing: 2),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(l10n.inviteValidUntil(formatDateTimeShort(created.expiresAt)), key: const Key('invite-valid')),
        const SizedBox(height: 16),
        FilledButton.icon(
          key: const Key('invite-share'),
          icon: const Icon(Icons.share),
          label: Text(l10n.inviteShare),
          onPressed: () async {
            final message = l10n.inviteShareMessage(code, created.link);
            await runUiAction(
              context,
              () => ref.read(shareTextProvider)(message, subject: l10n.inviteShareSubject),
            );
          },
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          key: const Key('invite-copy'),
          icon: const Icon(Icons.copy),
          label: Text(l10n.inviteCopy),
          onPressed: () async {
            final messenger = ScaffoldMessenger.of(context);
            await Clipboard.setData(ClipboardData(text: code));
            messenger
              ..hideCurrentSnackBar()
              ..showSnackBar(SnackBar(content: Text(l10n.inviteCopied)));
          },
        ),
        const SizedBox(height: 24),
        TextButton(
          key: const Key('invite-another'),
          onPressed: onAnother,
          child: Text(l10n.inviteAnother),
        ),
        TextButton(
          key: const Key('invite-view-list'),
          onPressed: () => context.pushReplacement(Routes.familyInvitations),
          child: Text(l10n.inviteSentList),
        ),
      ],
    );
  }
}

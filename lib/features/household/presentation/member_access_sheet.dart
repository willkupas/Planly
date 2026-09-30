import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:planly/core/widgets/async_value_view.dart';
import 'package:planly/core/widgets/state_widgets.dart';
import 'package:planly/core/widgets/ui_actions.dart';
import 'package:planly/features/family/application/family_providers.dart';
import 'package:planly/features/family/domain/family_models.dart';
import 'package:planly/features/household/application/household_providers.dart';
import 'package:planly/features/household/domain/household_models.dart';
import 'package:planly/l10n/app_localizations.dart';

/// Acesso por casa de um membro (spec §1 #17, reduzido a uma sheet): o owner escolhe, por
/// casa, sem acesso / participante / admin. Cada mudança chama `setHouseholdAccess`.
Future<void> showMemberAccessSheet(BuildContext context, FamilyMember member) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => MemberAccessSheet(member: member),
  );
}

enum _Access { none, member, admin }

_Access _of(HouseholdRole? r) => switch (r) {
      null => _Access.none,
      HouseholdRole.member => _Access.member,
      HouseholdRole.admin => _Access.admin,
    };

HouseholdRole? _role(_Access a) => switch (a) {
      _Access.none => null,
      _Access.member => HouseholdRole.member,
      _Access.admin => HouseholdRole.admin,
    };

class MemberAccessSheet extends ConsumerWidget {
  const MemberAccessSheet({super.key, required this.member});

  final FamilyMember member;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final familyId = ref.watch(activeFamilyIdProvider);
    final canWrite = ref.watch(familyWriteAccessProvider);
    final households = ref.watch(accessibleHouseholdsProvider);
    final name = member.displayName?.trim().isNotEmpty == true ? member.displayName! : l10n.memberNoName;

    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Text(l10n.memberAccessTitle(name), style: Theme.of(context).textTheme.titleMedium),
            ),
            Flexible(
              child: AsyncValueView<HouseholdsSnapshot>(
                value: households,
                onRetry: () => ref.invalidate(accessibleHouseholdsProvider),
                isEmpty: (s) => s.items.isEmpty,
                empty: EmptyState(icon: Icons.home_work_outlined, title: l10n.householdsEmpty),
                data: (context, snap) => ListView(
                  shrinkWrap: true,
                  children: [
                    for (final h in snap.items)
                      Padding(
                        key: Key('access-${h.id}'),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(h.name, style: Theme.of(context).textTheme.bodyLarge),
                            const SizedBox(height: 4),
                            SegmentedButton<_Access>(
                              showSelectedIcon: false,
                              segments: [
                                ButtonSegment(value: _Access.none, label: Text(l10n.accessNone)),
                                ButtonSegment(value: _Access.member, label: Text(l10n.accessMember)),
                                ButtonSegment(value: _Access.admin, label: Text(l10n.accessAdmin)),
                              ],
                              selected: {_of(h.access[member.uid])},
                              onSelectionChanged: !canWrite || familyId == null
                                  ? null
                                  : (sel) => runUiAction(
                                        context,
                                        () => ref
                                            .read(householdActionsProvider)
                                            .setAccess(familyId, h.id, member.uid, _role(sel.first)),
                                      ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

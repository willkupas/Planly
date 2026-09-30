import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:planly/core/time/clock.dart';
import 'package:planly/features/family/application/family_providers.dart';
import 'package:planly/features/family/domain/family_models.dart';
import 'package:planly/l10n/app_localizations.dart';

/// Faixa fixa "Somente leitura" quando a família ativa está `frozen` (spec §1 #21, §2.3).
/// CTAs reais (reassinar/transferir) dependem de billing/transferência: por ora só informa.
class FamilyFrozenBanner extends ConsumerWidget {
  const FamilyFrozenBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (ref.watch(activeFamilyStatusProvider) != FamilyStatus.frozen) return const SizedBox.shrink();

    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final deleteAfter = ref.watch(activeFamilyProvider).value?.deleteAfter;
    final isOwner = ref.watch(isOwnerProvider);

    String headline = l10n.frozenBannerNoDate;
    if (deleteAfter != null) {
      final diff = deleteAfter.difference(ref.read(clockProvider)());
      final days = diff.isNegative ? 0 : (diff.inHours / 24).ceil();
      headline = l10n.frozenBanner(days);
    }

    return Material(
      key: const Key('frozen-banner'),
      color: scheme.errorContainer,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.lock_outline, size: 20, color: scheme.onErrorContainer),
            const SizedBox(width: 10),
            Expanded(
              child: DefaultTextStyle.merge(
                style: TextStyle(color: scheme.onErrorContainer),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(headline, style: const TextStyle(fontWeight: FontWeight.w600)),
                    Text(isOwner ? l10n.frozenBannerOwnerHint : l10n.frozenBannerMemberHint),
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

import 'package:flutter/material.dart';
import 'package:planly/l10n/app_localizations.dart';

enum UpsellReason { invites, households }

/// Upsell do plano Free (spec §1 #12/#14). Sem preços nem limites fixos: a compra entra na
/// Sprint 8 (Play Billing) e os valores virão do entitlement/Play.
Future<void> showUpsellDialog(BuildContext context, UpsellReason reason) {
  final l10n = AppLocalizations.of(context);
  final message = switch (reason) {
    UpsellReason.invites => l10n.upsellInvitesMessage,
    UpsellReason.households => l10n.upsellHouseholdsMessage,
  };
  return showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      key: const Key('upsell-dialog'),
      icon: const Icon(Icons.workspace_premium_outlined),
      title: Text(l10n.upsellTitle),
      content: Text(message),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: Text(l10n.actionOk))],
    ),
  );
}

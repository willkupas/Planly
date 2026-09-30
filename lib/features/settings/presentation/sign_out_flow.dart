import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:planly/core/widgets/ui_actions.dart';
import 'package:planly/features/settings/application/session_actions.dart';
import 'package:planly/l10n/app_localizations.dart';

/// Logout com aviso de escritas pendentes e opção "Sair mesmo assim" (data-model §8 #16).
/// Ao terminar, o router leva ao login (auth state muda).
Future<void> signOutWithWarning(BuildContext context, WidgetRef ref) async {
  final l10n = AppLocalizations.of(context);
  final actions = ref.read(sessionActionsProvider);

  var outcome = SignOutOutcome.done;
  final ok = await runUiAction(context, () async {
    outcome = await actions.signOut();
  });
  if (!ok || outcome == SignOutOutcome.done || !context.mounted) return;

  final force = await confirmDialog(
    context,
    title: l10n.signOutPendingTitle,
    message: l10n.signOutPendingMessage,
    confirmLabel: l10n.signOutAnyway,
    destructive: true,
  );
  if (!force || !context.mounted) return;
  await runUiAction(context, () async {
    await actions.signOut(force: true);
  });
}

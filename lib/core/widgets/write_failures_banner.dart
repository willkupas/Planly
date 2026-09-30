import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:planly/core/l10n_helpers/failure_message.dart';
import 'package:planly/core/sync/write_failure_center.dart';
import 'package:planly/l10n/app_localizations.dart';

/// Descrição amigável da escrita recusada ("Criar tarefa “X”").
String writeFailureLabel(AppLocalizations l10n, WriteFailure f) {
  final t = f.title ?? '';
  return switch (f.kind) {
    WriteKind.taskCreate => l10n.writeKindTaskCreate(t),
    WriteKind.taskUpdate => l10n.writeKindTaskUpdate(t),
    WriteKind.taskComplete => l10n.writeKindTaskComplete(t),
    WriteKind.taskReopen => l10n.writeKindTaskReopen(t),
    WriteKind.taskDelete => l10n.writeKindTaskDelete(t),
    WriteKind.listCreate => l10n.writeKindListCreate(t),
    WriteKind.listRename => l10n.writeKindListRename(t),
    WriteKind.listDelete => l10n.writeKindListDelete(t),
    WriteKind.itemAdd => l10n.writeKindItemAdd(t),
    WriteKind.itemComplete => l10n.writeKindItemComplete(t),
    WriteKind.itemRename => l10n.writeKindItemRename(t),
    WriteKind.itemDelete => l10n.writeKindItemDelete(t),
    WriteKind.itemReorder => l10n.writeKindItemReorder,
  };
}

/// Aviso global discreto de escritas que o servidor recusou ao sincronizar (T-021). Não
/// aparece quando não há falhas; "Ver" abre a lista com "Descartar" por item e "Descartar tudo".
class WriteFailuresBanner extends ConsumerWidget {
  const WriteFailuresBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final failures = ref.watch(writeFailureCenterProvider);
    if (failures.isEmpty) return const SizedBox.shrink();
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    return Material(
      key: const Key('write-failures-banner'),
      color: scheme.errorContainer,
      child: Padding(
        padding: const EdgeInsets.only(left: 16, right: 8, top: 4, bottom: 4),
        child: Row(
          children: [
            Icon(Icons.sync_problem, size: 18, color: scheme.onErrorContainer),
            const SizedBox(width: 8),
            Expanded(
              child: Semantics(
                liveRegion: true,
                child: Text(
                  l10n.writeFailureBannerTitle(failures.length),
                  style: TextStyle(color: scheme.onErrorContainer),
                ),
              ),
            ),
            TextButton(
              key: const Key('write-failures-view'),
              onPressed: () => showWriteFailuresSheet(context),
              child: Text(l10n.writeFailureBannerView),
            ),
          ],
        ),
      ),
    );
  }
}

Future<void> showWriteFailuresSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => const _WriteFailuresSheet(),
  );
}

class _WriteFailuresSheet extends ConsumerWidget {
  const _WriteFailuresSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final failures = ref.watch(writeFailureCenterProvider);
    final center = ref.read(writeFailureCenterProvider.notifier);
    // Sem falhas (todas descartadas): fecha sozinho.
    if (failures.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted && Navigator.of(context).canPop()) Navigator.of(context).pop();
      });
    }
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l10n.writeFailureSheetTitle, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(l10n.writeFailureSheetExplain),
            const SizedBox(height: 8),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [
                  for (final f in failures)
                    ListTile(
                      key: Key('write-failure-${f.id}'),
                      contentPadding: EdgeInsets.zero,
                      title: Text(writeFailureLabel(l10n, f)),
                      subtitle: Text(failureMessage(l10n, f.error)),
                      trailing: TextButton(
                        key: Key('write-failure-dismiss-${f.id}'),
                        onPressed: () => center.dismiss(f.id),
                        child: Text(l10n.writeFailureDismiss),
                      ),
                    ),
                ],
              ),
            ),
            if (failures.length > 1)
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  key: const Key('write-failures-dismiss-all'),
                  onPressed: center.dismissAll,
                  child: Text(l10n.writeFailureDismissAll),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

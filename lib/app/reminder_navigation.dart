import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:planly/app/router/app_router.dart';
import 'package:planly/app/router/routes.dart';
import 'package:planly/app/session/session_phase.dart';
import 'package:planly/features/family/application/active_context.dart';
import 'package:planly/features/reminders/application/reminder_providers.dart';

/// Abre a tarefa de uma notificação de lembrete (app aberto ou cold start).
///
/// Espera a sessão ficar `ready` (senão os guards mandariam para a splash e perderiam o alvo),
/// ajusta a casa ativa se a tarefa for de outra casa e navega para `/home/task/:taskId`.
final reminderNavigationProvider = Provider<void>((ref) {
  ref.watch(reminderTapProvider);
  final request = ref.watch(reminderOpenRequestProvider);
  final phase = ref.watch(sessionPhaseProvider);
  if (request == null || phase != SessionPhase.ready) return;

  // Fora do ciclo de build do provider: altera outros providers.
  scheduleMicrotask(() async {
    if (!ref.mounted) return;
    ref.read(reminderOpenRequestProvider.notifier).clear();
    final current = ref.read(activeContextProvider);
    if (current.familyId != request.familyId || current.householdId != request.householdId) {
      await ref.read(activeContextProvider.notifier).selectHousehold(request.familyId, request.householdId);
    }
    if (!ref.mounted) return;
    ref.read(routerProvider).go(Routes.taskPath(request.taskId));
  });
});

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:planly/app/router/app_router.dart';
import 'package:planly/app/router/routes.dart';
import 'package:planly/app/session/session_phase.dart';
import 'package:planly/features/family/application/active_context.dart';
import 'package:planly/features/notifications/application/push_providers.dart';

/// Abre o destino de um push de atividade (tarefa ou lista) ao tocar na notificação.
///
/// Espera a sessão ficar `ready`, ajusta a casa ativa se o evento for de outra casa e navega
/// (`/home/task/:id` ou `/lists/:id`), como `reminderNavigationProvider` faz para lembretes.
final pushNavigationProvider = Provider<void>((ref) {
  ref.watch(pushTapProvider);
  final request = ref.watch(pushOpenRequestProvider);
  final phase = ref.watch(sessionPhaseProvider);
  if (request == null || phase != SessionPhase.ready) return;

  scheduleMicrotask(() async {
    if (!ref.mounted) return;
    ref.read(pushOpenRequestProvider.notifier).clear();
    final current = ref.read(activeContextProvider);
    if (current.familyId != request.familyId || current.householdId != request.householdId) {
      await ref.read(activeContextProvider.notifier).selectHousehold(request.familyId, request.householdId);
    }
    if (!ref.mounted) return;
    ref.read(routerProvider).go(
          request.type.targetsList ? Routes.listDetail(request.targetId) : Routes.taskPath(request.targetId),
        );
  });
});

import 'package:planly/features/activity/domain/activity_models.dart';

/// Máximo de eventos por consulta (as Rules exigem `limit <= 50`).
const activityMaxPageSize = 50;

/// Tamanho padrão de página (spec flutter-app §7).
const activityPageSize = 20;

/// Leitura do histórico da casa. A escrita acontece nos batches de tarefas/listas
/// (`activity_entry.dart`) e nas Functions.
abstract interface class ActivityRepository {
  /// Página de eventos por `createdAt` DESC. [cursor] = `ActivityPage.cursor` da página anterior.
  /// [actorId] filtra por pessoa; [since] limita ao período (Free: últimos 7 dias).
  Future<ActivityPage> fetchPage({
    required String familyId,
    required String householdId,
    int limit = activityPageSize,
    Object? cursor,
    String? actorId,
    DateTime? since,
  });
}

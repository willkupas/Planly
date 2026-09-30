/// Tipos de evento de atividade (data-model §3.11): os do cliente e os de Function.
enum ActivityEventType {
  taskCreated('task_created'),
  taskAssigned('task_assigned'),
  taskCompleted('task_completed'),
  taskReopened('task_reopened'),
  taskUpdated('task_updated'),
  taskDeleted('task_deleted'),
  listCreated('list_created'),
  listDeleted('list_deleted'),
  itemAdded('item_added'),
  itemCompleted('item_completed'),
  itemDeleted('item_deleted'),
  memberJoined('member_joined'),
  memberLeft('member_left'),
  householdCreated('household_created'),

  /// Tipo desconhecido (versão futura): exibido com texto genérico.
  unknown('');

  const ActivityEventType(this.wire);

  final String wire;

  static ActivityEventType parse(Object? v) {
    for (final t in values) {
      if (t != unknown && t.wire == v) return t;
    }
    return unknown;
  }
}

/// Um registro de `families/{f}/households/{h}/activity/{id}` (append-only). `actorName` e
/// `targetTitle` são snapshots: a tela não faz leituras extras.
class ActivityEvent {
  const ActivityEvent({
    required this.id,
    required this.type,
    required this.actorId,
    required this.actorName,
    required this.targetType,
    required this.targetId,
    required this.targetTitle,
    this.createdAt,
    this.hasPendingWrites = false,
  });

  final String id;
  final ActivityEventType type;
  final String actorId;
  final String actorName;
  final String targetType;
  final String targetId;
  final String targetTitle;

  /// `null` enquanto o servidor não confirmou o timestamp (escrita local pendente).
  final DateTime? createdAt;
  final bool hasPendingWrites;
}

/// Uma página do histórico. [cursor] é opaco para o domínio (a implementação o entende).
class ActivityPage {
  const ActivityPage({
    required this.events,
    required this.hasMore,
    this.cursor,
  });

  final List<ActivityEvent> events;
  final bool hasMore;
  final Object? cursor;
}

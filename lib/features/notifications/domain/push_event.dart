/// Tipos de push de eventos compartilhados (contrato com as Functions, T-023).
enum PushEventType {
  taskCreated('task_created'),
  taskAssigned('task_assigned'),
  taskCompleted('task_completed'),
  listItemAdded('list_item_added');

  const PushEventType(this.wire);

  /// Valor enviado no payload FCM.
  final String wire;

  static PushEventType? fromWire(String? v) {
    for (final t in values) {
      if (t.wire == v) return t;
    }
    return null;
  }

  /// `targetId` é uma lista (e não uma tarefa).
  bool get targetsList => this == listItemAdded;
}

/// Evento recebido por push: só ids e tipo (nenhum conteúdo; o texto vem do ARB).
class PushEvent {
  const PushEvent({
    required this.type,
    required this.familyId,
    required this.householdId,
    required this.targetId,
  });

  final PushEventType type;
  final String familyId;
  final String householdId;
  final String targetId;

  /// `null` se o payload FCM (`data`) estiver incompleto ou com tipo desconhecido.
  static PushEvent? fromData(Map<String, dynamic> data) {
    final type = PushEventType.fromWire(data['type'] as String?);
    final f = data['familyId'];
    final h = data['householdId'];
    final t = data['targetId'];
    if (type == null || f is! String || h is! String || t is! String) return null;
    if (f.isEmpty || h.isEmpty || t.isEmpty) return null;
    return PushEvent(type: type, familyId: f, householdId: h, targetId: t);
  }

  /// Payload da notificação local: `planly://event/<type>/<targetId>?f=<familyId>&h=<householdId>`.
  String encode() => Uri(
        scheme: 'planly',
        host: 'event',
        pathSegments: [type.wire, targetId],
        queryParameters: {'f': familyId, 'h': householdId},
      ).toString();

  static PushEvent? parse(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    final uri = Uri.tryParse(raw);
    if (uri == null || uri.scheme != 'planly' || uri.host != 'event') return null;
    if (uri.pathSegments.length != 2) return null;
    return fromData({
      'type': uri.pathSegments[0],
      'targetId': uri.pathSegments[1],
      'familyId': uri.queryParameters['f'],
      'householdId': uri.queryParameters['h'],
    });
  }

  /// Id estável da notificação: eventos do mesmo tipo/alvo substituem o anterior (vários
  /// itens adicionados à mesma lista não empilham).
  int get notificationId {
    var hash = 0x811c9dc5;
    for (final unit in '${type.wire}:$targetId'.codeUnits) {
      hash ^= unit & 0xff;
      hash = (hash * 0x01000193) & 0xffffffff;
    }
    return hash & 0x7fffffff;
  }

  @override
  bool operator ==(Object other) =>
      other is PushEvent &&
      other.type == type &&
      other.familyId == familyId &&
      other.householdId == householdId &&
      other.targetId == targetId;

  @override
  int get hashCode => Object.hash(type, familyId, householdId, targetId);
}

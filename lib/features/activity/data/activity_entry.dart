import 'package:cloud_firestore/cloud_firestore.dart';

/// Tipos de atividade que o CLIENTE pode gravar (Rules: `firebase/firestore.rules`, activity).
/// `member_joined`, `member_left` e `household_created` são escritos só por Function.
enum ActivityType {
  taskCreated('task_created', 'task'),
  taskAssigned('task_assigned', 'task'),
  taskCompleted('task_completed', 'task'),
  taskReopened('task_reopened', 'task'),
  taskUpdated('task_updated', 'task'),
  taskDeleted('task_deleted', 'task'),
  listCreated('list_created', 'list'),
  listDeleted('list_deleted', 'list'),
  itemAdded('item_added', 'item'),
  itemCompleted('item_completed', 'item'),
  itemDeleted('item_deleted', 'item');

  const ActivityType(this.wire, this.targetType);

  /// Valor gravado em `type`.
  final String wire;

  /// Valor gravado em `targetType` (as Rules exigem coerência com o prefixo do tipo).
  final String targetType;
}

/// Monta o documento de `families/{f}/households/{h}/activity/{id}` (data-model §3.11).
///
/// Deve ir no MESMO `WriteBatch` da ação que o originou (atômico e funciona offline).
/// As Rules exigem: `actorId == auth.uid`, `createdAt == request.time` (serverTimestamp),
/// `schemaVersion == 1`, nomes/títulos com até 200 caracteres e nenhum campo extra.
Map<String, Object?> activityEntry({
  required ActivityType type,
  required String actorId,
  required String actorName,
  required String targetId,
  required String targetTitle,
}) {
  return {
    'type': type.wire,
    'actorId': actorId,
    'actorName': _clip(actorName),
    'targetType': type.targetType,
    'targetId': targetId,
    'targetTitle': _clip(targetTitle),
    'createdAt': FieldValue.serverTimestamp(),
    'schemaVersion': 1,
  };
}

String _clip(String s) => s.length <= 200 ? s : s.substring(0, 200);

import 'package:planly/core/sync/sync_status.dart';

enum ListType {
  shopping('shopping'),
  general('general');

  const ListType(this.wire);

  final String wire;

  static ListType parse(Object? v) => v == 'general' ? ListType.general : ListType.shopping;
}

/// `families/{f}/households/{h}/lists/{id}` (data-model §3.10).
class TaskList {
  const TaskList({
    required this.id,
    required this.name,
    required this.type,
    required this.createdBy,
    this.hasPendingWrites = false,
  });

  final String id;
  final String name;
  final ListType type;
  final String createdBy;
  final bool hasPendingWrites;
}

/// `.../lists/{id}/items/{id}`: documento próprio por item (nunca array), colaborativo.
class ListItem {
  const ListItem({
    required this.id,
    required this.name,
    required this.completed,
    required this.order,
    required this.createdBy,
    this.completedBy,
    this.completedAt,
    this.hasPendingWrites = false,
  });

  final String id;
  final String name;
  final bool completed;
  final double order;
  final String createdBy;
  final String? completedBy;
  final DateTime? completedAt;
  final bool hasPendingWrites;
}

class ListsSnapshot {
  const ListsSnapshot(this.items, [this.meta = const SyncMeta()]);

  final List<TaskList> items;
  final SyncMeta meta;
}

class ItemsSnapshot {
  const ItemsSnapshot(this.items, [this.meta = const SyncMeta()]);

  /// Pendentes primeiro (por `order`), depois concluídos (por `order`).
  final List<ListItem> items;
  final SyncMeta meta;

  List<ListItem> get pending => items.where((i) => !i.completed).toList();
  List<ListItem> get done => items.where((i) => i.completed).toList();
}

/// Limites das Rules: lists ≤ 100, items ≤ 200 por query; nome 1–200.
const listsQueryLimit = 100;
const itemsQueryLimit = 200;
const listNameMaxLength = 200;

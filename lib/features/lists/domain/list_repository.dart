import 'package:planly/features/lists/domain/list_models.dart';

/// Acesso às listas/itens de uma casa. Escritas são client-direct (Rules) e offline-first:
/// completam assim que o write local é aceito; o servidor confirma depois (`SyncMeta`).
/// Toda mutação grava a `activity` correspondente no MESMO batch.
abstract class ListRepository {
  Stream<ListsSnapshot> watchLists(String familyId, String householdId);

  /// Itens não excluídos, pendentes antes dos concluídos.
  Stream<ItemsSnapshot> watchItems(String familyId, String householdId, String listId);

  /// Quantidade de itens pendentes via `count()` no servidor (1 leitura por 1000 entradas de
  /// índice; não lê os itens). `null` se indisponível (offline).
  Future<int?> pendingCount(String familyId, String householdId, String listId);

  Future<String> createList({
    required String familyId,
    required String householdId,
    required String name,
    required ListType type,
    required String actorId,
    required String actorName,
  });

  Future<void> renameList({
    required String familyId,
    required String householdId,
    required String listId,
    required String name,
  });

  Future<void> deleteList({
    required String familyId,
    required String householdId,
    required String listId,
    required String listName,
    required String actorId,
    required String actorName,
  });

  Future<String> addItem({
    required String familyId,
    required String householdId,
    required String listId,
    required String name,
    required double order,
    required String actorId,
    required String actorName,
  });

  Future<void> setItemCompleted({
    required String familyId,
    required String householdId,
    required String listId,
    required String itemId,
    required String itemName,
    required bool completed,
    required String actorId,
    required String actorName,
  });

  Future<void> renameItem({
    required String familyId,
    required String householdId,
    required String listId,
    required String itemId,
    required String name,
  });

  /// Atualiza só o `order` dos itens informados (`itemId -> order`).
  Future<void> reorderItems({
    required String familyId,
    required String householdId,
    required String listId,
    required Map<String, double> orders,
  });

  Future<void> deleteItem({
    required String familyId,
    required String householdId,
    required String listId,
    required String itemId,
    required String itemName,
    required String actorId,
    required String actorName,
  });
}

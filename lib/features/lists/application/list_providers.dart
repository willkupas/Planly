import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:planly/core/error/app_failure.dart';
import 'package:planly/core/firebase/firebase_providers.dart';
import 'package:planly/features/auth/application/auth_providers.dart';
import 'package:planly/features/family/application/family_providers.dart';
import 'package:planly/features/household/application/household_providers.dart';
import 'package:planly/features/household/domain/household_models.dart';
import 'package:planly/features/lists/data/firestore_list_repository.dart';
import 'package:planly/features/lists/domain/item_order.dart';
import 'package:planly/features/lists/domain/list_models.dart';
import 'package:planly/features/lists/domain/list_repository.dart';

final listRepositoryProvider = Provider<ListRepository>((ref) {
  return FirestoreListRepository(firestore: ref.watch(firestoreProvider));
});

/// Família + casa ativas (validadas). `null` enquanto não resolvem.
typedef ContentScope = ({String familyId, String householdId});

final listsScopeProvider = Provider<ContentScope?>((ref) {
  final familyId = ref.watch(activeFamilyIdProvider);
  final household = ref.watch(activeHouseholdProvider);
  if (familyId == null || household == null) return null;
  return (familyId: familyId, householdId: household.id);
});

/// Listas da casa ativa. Só vive com a tela de listas/detalhe aberta (autoDispose).
final householdListsProvider = StreamProvider.autoDispose<ListsSnapshot>((ref) {
  ref.watch(currentUidProvider);
  final scope = ref.watch(listsScopeProvider);
  if (scope == null) return const Stream.empty();
  return ref.watch(listRepositoryProvider).watchLists(scope.familyId, scope.householdId);
});

/// Itens de uma lista, só com a tela de detalhe aberta (spec §7).
final listItemsProvider = StreamProvider.autoDispose.family<ItemsSnapshot, String>((ref, listId) {
  ref.watch(currentUidProvider);
  final scope = ref.watch(listsScopeProvider);
  if (scope == null) return const Stream.empty();
  return ref.watch(listRepositoryProvider).watchItems(scope.familyId, scope.householdId, listId);
});

/// Contagem de pendentes por `count()` (1 leitura agregada por lista, sem ler itens). `null`
/// = indisponível (offline): a UI simplesmente não mostra o número. Quem altera itens
/// invalida este provider ao voltar para a tela de listas.
final pendingCountProvider = FutureProvider.autoDispose.family<int?, String>((ref, listId) {
  final scope = ref.watch(listsScopeProvider);
  if (scope == null) return null;
  return ref.watch(listRepositoryProvider).pendingCount(scope.familyId, scope.householdId, listId);
});

/// Admin da casa ou owner da família (espelha `isHouseholdAdmin` das Rules).
final isHouseholdModeratorProvider = Provider<bool>((ref) {
  if (ref.watch(isOwnerProvider)) return true;
  final uid = ref.watch(currentUidProvider);
  final household = ref.watch(activeHouseholdProvider);
  return uid != null && household?.access[uid] == HouseholdRole.admin;
});

/// Quem pode renomear/excluir um objeto criado por [createdBy] (lista e soft delete de
/// item): o autor, admin da casa ou owner. Renomear/completar/reordenar item é livre.
final canManageContentProvider = Provider.family<bool, String>((ref, createdBy) {
  return ref.watch(currentUidProvider) == createdBy || ref.watch(isHouseholdModeratorProvider);
});

/// Ações de listas/itens. Escrita otimista (funciona offline): nunca usa `ensureOnline`.
class ListActions {
  ListActions(this._ref);

  final Ref _ref;

  ListRepository get _repo => _ref.read(listRepositoryProvider);

  ({ContentScope scope, String uid, String name}) _ctx() {
    // Modo leitura (família frozen/deleting): as Rules negariam; falha cedo com mensagem.
    if (!_ref.read(familyWriteAccessProvider)) throw const BusinessFailure('FAMILY_FROZEN');
    final scope = _ref.read(listsScopeProvider);
    final user = _ref.read(currentUserProvider);
    if (scope == null || user == null) throw const PermissionDeniedFailure();
    return (scope: scope, uid: user.uid, name: user.displayName ?? '');
  }

  Future<String> createList(String name, ListType type) {
    final c = _ctx();
    return _repo.createList(
      familyId: c.scope.familyId,
      householdId: c.scope.householdId,
      name: name,
      type: type,
      actorId: c.uid,
      actorName: c.name,
    );
  }

  Future<void> renameList(TaskList list, String name) {
    final c = _ctx();
    return _repo.renameList(
      familyId: c.scope.familyId,
      householdId: c.scope.householdId,
      listId: list.id,
      name: name,
    );
  }

  Future<void> deleteList(TaskList list) {
    final c = _ctx();
    return _repo.deleteList(
      familyId: c.scope.familyId,
      householdId: c.scope.householdId,
      listId: list.id,
      listName: list.name,
      actorId: c.uid,
      actorName: c.name,
    );
  }

  Future<void> addItem(String listId, String name) {
    final c = _ctx();
    final existing = _ref.read(listItemsProvider(listId)).value?.items ?? const <ListItem>[];
    return _repo.addItem(
      familyId: c.scope.familyId,
      householdId: c.scope.householdId,
      listId: listId,
      name: name,
      order: nextOrder(existing.map((i) => i.order)),
      actorId: c.uid,
      actorName: c.name,
    );
  }

  Future<void> setCompleted(String listId, ListItem item, bool completed) {
    final c = _ctx();
    return _repo.setItemCompleted(
      familyId: c.scope.familyId,
      householdId: c.scope.householdId,
      listId: listId,
      itemId: item.id,
      itemName: item.name,
      completed: completed,
      actorId: c.uid,
      actorName: c.name,
    );
  }

  Future<void> renameItem(String listId, ListItem item, String name) {
    final c = _ctx();
    return _repo.renameItem(
      familyId: c.scope.familyId,
      householdId: c.scope.householdId,
      listId: listId,
      itemId: item.id,
      name: name,
    );
  }

  /// [pending] = itens pendentes na ordem exibida; índices no padrão do `ReorderableListView`.
  Future<void> reorder(String listId, List<ListItem> pending, int oldIndex, int newIndex) {
    final c = _ctx();
    final plan = planReorder(pending.map((i) => i.order).toList(), oldIndex, newIndex);
    if (plan.isEmpty) return Future.value();
    return _repo.reorderItems(
      familyId: c.scope.familyId,
      householdId: c.scope.householdId,
      listId: listId,
      orders: {for (final e in plan.entries) pending[e.key].id: e.value},
    );
  }

  Future<void> deleteItem(String listId, ListItem item) {
    final c = _ctx();
    return _repo.deleteItem(
      familyId: c.scope.familyId,
      householdId: c.scope.householdId,
      listId: listId,
      itemId: item.id,
      itemName: item.name,
      actorId: c.uid,
      actorName: c.name,
    );
  }
}

final listActionsProvider = Provider<ListActions>(ListActions.new);

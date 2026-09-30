import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:planly/core/error/app_failure.dart';
import 'package:planly/core/firebase/firebase_providers.dart';
import 'package:planly/core/sync/write_failure_center.dart';
import 'package:planly/features/auth/application/auth_providers.dart';
import 'package:planly/features/family/application/family_providers.dart';
import 'package:planly/features/family/domain/family_models.dart';
import 'package:planly/features/household/application/household_providers.dart';
import 'package:planly/features/household/domain/household_models.dart';
import 'package:planly/features/tasks/data/firestore_task_repository.dart';
import 'package:planly/features/tasks/domain/task_models.dart';
import 'package:planly/features/tasks/domain/task_repository.dart';

final taskRepositoryProvider = Provider<TaskRepository>((ref) {
  return FirestoreTaskRepository(firestore: ref.watch(firestoreProvider));
});

/// Casa ativa validada (família + casa), ou `null` enquanto não há contexto.
final taskScopeProvider = Provider<TaskScope?>((ref) {
  final familyId = ref.watch(activeFamilyIdProvider);
  final householdId = ref.watch(activeHouseholdProvider)?.id;
  if (familyId == null || householdId == null) return null;
  return TaskScope(familyId, householdId);
});

/// Toggle do dashboard: todas as tarefas da casa ou só as minhas.
enum TaskFilter { all, mine }

class TaskFilterNotifier extends Notifier<TaskFilter> {
  @override
  TaskFilter build() => TaskFilter.all;

  void select(TaskFilter f) => state = f;
}

final taskFilterProvider = NotifierProvider<TaskFilterNotifier, TaskFilter>(TaskFilterNotifier.new);

String? _assigneeFilter(Ref ref) =>
    ref.watch(taskFilterProvider) == TaskFilter.mine ? ref.watch(currentUidProvider) : null;

/// Listeners do dashboard (spec §7: tarefas da casa ativa enquanto montado; autoDispose).
final scheduledTasksProvider = StreamProvider.autoDispose<TasksSnapshot>((ref) {
  final scope = ref.watch(taskScopeProvider);
  final assignee = _assigneeFilter(ref);
  if (scope == null) return const Stream.empty();
  return ref.watch(taskRepositoryProvider).watchScheduled(scope, assignedTo: assignee);
});

final unscheduledTasksProvider = StreamProvider.autoDispose<TasksSnapshot>((ref) {
  final scope = ref.watch(taskScopeProvider);
  final assignee = _assigneeFilter(ref);
  if (scope == null) return const Stream.empty();
  return ref.watch(taskRepositoryProvider).watchUnscheduled(scope, assignedTo: assignee);
});

final recentDoneTasksProvider = StreamProvider.autoDispose<TasksSnapshot>((ref) {
  final scope = ref.watch(taskScopeProvider);
  if (scope == null) return const Stream.empty();
  return ref.watch(taskRepositoryProvider).watchRecentDone(scope);
});

/// Só enquanto o detalhe está aberto.
final taskProvider = StreamProvider.autoDispose.family<Task?, String>((ref, taskId) {
  final scope = ref.watch(taskScopeProvider);
  if (scope == null) return const Stream.empty();
  return ref.watch(taskRepositoryProvider).watchTask(scope, taskId);
});

/// Permissões de UI, espelhando as Rules (as Rules continuam sendo a barreira real).
///
/// - criar: qualquer acesso à casa com família `active`;
/// - editar/excluir: autor, admin da casa ou owner;
/// - concluir/reabrir: quem pode editar, ou tarefa atribuída a mim / a "qualquer pessoa".
class TaskAccess {
  const TaskAccess({required this.familyWritable, required this.uid, required this.isAdmin});

  final bool familyWritable;
  final String? uid;
  final bool isAdmin;

  bool get canCreate => familyWritable && uid != null;

  bool canEdit(Task t) => canCreate && !t.isDeleted && (t.createdBy == uid || isAdmin);

  bool canDelete(Task t) => canEdit(t);

  bool canComplete(Task t) =>
      canCreate && !t.isDeleted && (canEdit(t) || t.assignedTo == null || t.assignedTo == uid);
}

final taskAccessProvider = Provider<TaskAccess>((ref) {
  final uid = ref.watch(currentUidProvider);
  final membership = ref.watch(activeMembershipProvider);
  final household = ref.watch(activeHouseholdProvider);
  final isAdmin = (membership?.isOwner ?? false) ||
      (uid != null && household?.access[uid] == HouseholdRole.admin);
  return TaskAccess(
    familyWritable: ref.watch(familyWriteAccessProvider),
    uid: uid,
    isAdmin: isAdmin,
  );
});

/// Quem pode ser responsável: owner (acesso implícito) e membros com acesso à casa ativa.
/// Só enquanto a sheet/detalhe estão abertos.
final assigneeCandidatesProvider = StreamProvider.autoDispose<List<FamilyMember>>((ref) async* {
  final familyId = ref.watch(activeFamilyIdProvider);
  final household = ref.watch(activeHouseholdProvider);
  if (familyId == null || household == null) return;
  await for (final members in ref.watch(familyRepositoryProvider).watchMembers(familyId)) {
    yield [
      for (final m in members)
        if (m.isOwner || household.access.containsKey(m.uid)) m,
    ];
  }
});

/// Ações de tarefa (escrita otimista/offline: NÃO usa `ensureOnline`). O `Future` devolvido
/// completa quando a escrita LOCAL foi enfileirada; a confirmação do servidor é acompanhada em
/// segundo plano pelo [writeFailureCenterProvider] (erro de Rules vira "não sincronizado").
class TaskActions {
  TaskActions(this._ref);

  final Ref _ref;

  TaskRepository get _repo => _ref.read(taskRepositoryProvider);

  (TaskScope, TaskActor) _context({required bool Function(TaskAccess) allowed}) {
    final scope = _ref.read(taskScopeProvider);
    final user = _ref.read(currentUserProvider);
    if (scope == null || user == null || !allowed(_ref.read(taskAccessProvider))) {
      throw const PermissionDeniedFailure();
    }
    return (scope, TaskActor(uid: user.uid, name: user.displayName ?? ''));
  }

  /// Entrega o ack ao canal central de escritas rejeitadas, sem segurar quem chamou.
  void _track(TaskWrite? w, WriteKind kind, String title) {
    if (w == null) return;
    _ref.read(writeFailureCenterProvider.notifier).track(w.ack, kind: kind, title: title);
  }

  /// Cria e devolve o id (gerado localmente).
  Future<String> create(TaskDraft draft) async {
    if (!draft.isValid) throw const UnknownFailure();
    final (scope, actor) = _context(allowed: (a) => a.canCreate);
    final w = _repo.create(scope, draft, actor);
    _track(w, WriteKind.taskCreate, draft.title.trim());
    return w.id;
  }

  Future<void> update(Task before, TaskDraft draft) async {
    if (!draft.isValid) throw const UnknownFailure();
    final (scope, actor) = _context(allowed: (a) => a.canEdit(before));
    _track(_repo.update(scope, before, draft, actor), WriteKind.taskUpdate, draft.title.trim());
  }

  Future<void> complete(Task task) async {
    final (scope, actor) = _context(allowed: (a) => a.canComplete(task));
    _track(_repo.complete(scope, task, actor), WriteKind.taskComplete, task.title);
  }

  Future<void> reopen(Task task) async {
    final (scope, actor) = _context(allowed: (a) => a.canComplete(task));
    _track(_repo.reopen(scope, task, actor), WriteKind.taskReopen, task.title);
  }

  Future<void> delete(Task task) async {
    final (scope, actor) = _context(allowed: (a) => a.canDelete(task));
    _track(_repo.softDelete(scope, task, actor), WriteKind.taskDelete, task.title);
  }
}

final taskActionsProvider = Provider<TaskActions>(TaskActions.new);

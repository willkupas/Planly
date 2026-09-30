import 'package:planly/features/tasks/domain/task_models.dart';

/// Acesso a tarefas. Streams emitem erros como `AppFailure`. Toda mutação grava a tarefa e a
/// atividade no MESMO `WriteBatch`; o efeito local é imediato (offline-first) e o `ack` do
/// [TaskWrite] só completa com a confirmação do servidor (nunca dar `await` nele na UI).
abstract class TaskRepository {
  /// Pendentes COM data, ordenadas por `schedule.scheduledAt` (índices do data-model §5).
  /// [assignedTo] != null filtra "minhas tarefas" no servidor.
  Stream<TasksSnapshot> watchScheduled(TaskScope scope, {String? assignedTo, int limit = 100});

  /// Pendentes SEM data (`schedule == null`), sem ordenação no servidor.
  Stream<TasksSnapshot> watchUnscheduled(TaskScope scope, {String? assignedTo, int limit = 50});

  /// Concluídas mais recentes (`completedAt` desc).
  Stream<TasksSnapshot> watchRecentDone(TaskScope scope, {int limit = 20});

  /// Uma tarefa (inclusive apagada: quem decide é a UI). `null` se o doc não existe.
  Stream<Task?> watchTask(TaskScope scope, String taskId);

  TaskWrite create(TaskScope scope, TaskDraft draft, TaskActor actor);

  /// Grava só os campos que mudaram em relação a [before]. Sem mudanças = sem escrita.
  /// Mudou o responsável => activity `task_assigned`; mudou o resto => `task_updated`.
  TaskWrite? update(TaskScope scope, Task before, TaskDraft draft, TaskActor actor);

  TaskWrite complete(TaskScope scope, Task task, TaskActor actor);

  TaskWrite reopen(TaskScope scope, Task task, TaskActor actor);

  TaskWrite softDelete(TaskScope scope, Task task, TaskActor actor);
}

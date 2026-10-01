import "../config";
import { onDocumentCreated, onDocumentUpdated } from "firebase-functions/v2/firestore";
import { REGION } from "../config";
import { dispatchPush } from "./pushDispatch";

const TASK = "families/{familyId}/households/{householdId}/tasks/{taskId}";
const ITEM = "families/{familyId}/households/{householdId}/lists/{listId}/items/{itemId}";

const str = (v: unknown): string | undefined => (typeof v === "string" && v.length > 0 ? v : undefined);

/**
 * Tarefa criada: o responsável (se for outra pessoa) recebe `task_assigned`; os demais
 * `task_created`. O autor nunca recebe. Tarefa rápida (responsável = autor): só `task_created`.
 */
export const pushOnTaskCreated = onDocumentCreated({ document: TASK, region: REGION }, async (event) => {
  const d = event.data?.data();
  const { familyId, householdId, taskId } = event.params;
  const actorId = str(d?.createdBy);
  if (!d || !actorId || d.deletedAt != null) return;
  const assignee = str(d.assignedTo);
  const base = { familyId, householdId, targetId: taskId, actorId };

  if (assignee && assignee !== actorId) {
    await dispatchPush({ ...base, type: "task_assigned", onlyUids: [assignee] });
  }
  await dispatchPush({ ...base, type: "task_created", excludeUids: assignee ? [assignee] : [] });
});

/**
 * Tarefa atualizada: concluída (pending para done; autor = `completedBy`) e reatribuída.
 *
 * Limitação conhecida: o doc não guarda quem editou. Em reatribuição o autor é aproximado por
 * `createdBy` (caso comum: o criador atribuindo a si mesmo não gera push para ele). Se
 * `updatedBy` for adicionado ao modelo, trocar aqui.
 */
export const pushOnTaskUpdated = onDocumentUpdated({ document: TASK, region: REGION }, async (event) => {
  const before = event.data?.before.data();
  const after = event.data?.after.data();
  const { familyId, householdId, taskId } = event.params;
  if (!before || !after || after.deletedAt != null) return;
  const base = { familyId, householdId, targetId: taskId };

  if (before.status !== "done" && after.status === "done") {
    const actorId = str(after.completedBy);
    if (actorId) await dispatchPush({ ...base, type: "task_completed", actorId });
  }

  const assignee = str(after.assignedTo);
  const createdBy = str(after.createdBy);
  if (assignee && assignee !== before.assignedTo && createdBy && assignee !== createdBy) {
    await dispatchPush({ ...base, type: "task_assigned", actorId: createdBy, onlyUids: [assignee] });
  }
});

/** Item adicionado a uma lista (`targetId` = id da lista). */
export const pushOnListItemAdded = onDocumentCreated({ document: ITEM, region: REGION }, async (event) => {
  const d = event.data?.data();
  const { familyId, householdId, listId } = event.params;
  const actorId = str(d?.createdBy);
  if (!d || !actorId || d.deletedAt != null) return;
  await dispatchPush({ type: "list_item_added", familyId, householdId, targetId: listId, actorId });
});

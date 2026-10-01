/** Tipos de push de eventos compartilhados (T-023). O app monta o texto por `type` (i18n). */
export type PushType = "task_created" | "task_assigned" | "task_completed" | "list_item_added";

export const PUSH_TYPES: readonly PushType[] = [
  "task_created",
  "task_assigned",
  "task_completed",
  "list_item_added",
];

/** Evento a notificar. `targetId` = taskId, ou listId para `list_item_added`. */
export interface PushEvent {
  type: PushType;
  familyId: string;
  householdId: string;
  targetId: string;
  /** Autor da ação: nunca recebe o push. */
  actorId: string;
  /** Se informado, só estes uids (ex.: o novo responsável); ainda filtrados por acesso e autor. */
  onlyUids?: string[];
  /** Uids que não devem receber (ex.: quem já recebeu `task_assigned`). */
  excludeUids?: string[];
}

export interface PushMessage {
  token: string;
  /** Só `{type, familyId, householdId, targetId}`: nenhum conteúdo de tarefa/lista. */
  data: Record<string, string>;
  collapseKey: string;
}

export interface SendResult {
  success: boolean;
  /** Código do FCM (ex.: `messaging/registration-token-not-registered`). */
  errorCode?: string;
}

export interface PushSender {
  send(messages: PushMessage[]): Promise<SendResult[]>;
}

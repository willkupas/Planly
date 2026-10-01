import * as logger from "firebase-functions/logger";

/**
 * Log estruturado (cloud-functions.md §1.2). Só campos de uma lista fixa:
 * NUNCA e-mail, tokens, purchaseToken, conteúdo de tarefas ou mensagens de erro livres.
 */
export interface LogFields {
  function: string;
  uid?: string;
  familyId?: string;
  householdId?: string;
  operation?: string;
  result: "ok" | "error";
  errorReason?: string;
  durationMs: number;
  /** Contadores opcionais (push, T-023): nunca ids de aparelho/token. */
  recipients?: number;
  sent?: number;
  failed?: number;
  removedTokens?: number;
}

export function logCall(f: LogFields): void {
  const entry: LogFields = {
    function: f.function,
    uid: f.uid,
    familyId: f.familyId,
    householdId: f.householdId,
    operation: f.operation,
    result: f.result,
    errorReason: f.errorReason,
    durationMs: f.durationMs,
    recipients: f.recipients,
    sent: f.sent,
    failed: f.failed,
    removedTokens: f.removedTokens,
  };
  if (f.result === "ok") logger.info("callable", entry);
  else logger.warn("callable", entry);
}

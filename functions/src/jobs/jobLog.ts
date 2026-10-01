import * as logger from "firebase-functions/logger";

/**
 * Log estruturado dos jobs. Allowlist fixa: ids opacos e contadores. NUNCA e-mail, nome,
 * token, conteúdo de tarefas ou mensagem de erro livre (só `errorReason` curto/constante).
 */
export interface JobLogFields {
  function: string;
  operation: string;
  result: "ok" | "error";
  familyId?: string;
  errorReason?: string;
  counts?: Record<string, number>;
  durationMs?: number;
}

export function logJob(f: JobLogFields): void {
  const entry: JobLogFields = {
    function: f.function,
    operation: f.operation,
    result: f.result,
    familyId: f.familyId,
    errorReason: f.errorReason,
    counts: f.counts,
    durationMs: f.durationMs,
  };
  if (f.result === "ok") logger.info("job", entry);
  else logger.warn("job", entry);
}

/** Motivo curto e seguro a partir de um erro (código do Firestore ou "unknown"). */
export function safeReason(e: unknown): string {
  const code = (e as { code?: unknown } | null)?.code;
  return typeof code === "string" || typeof code === "number" ? String(code).slice(0, 40) : "unknown";
}

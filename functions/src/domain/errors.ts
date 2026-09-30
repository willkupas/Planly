import { FunctionsErrorCode, HttpsError } from "firebase-functions/v2/https";

/**
 * Motivos estáveis (`details.reason`) que o app traduz via i18n.
 * Mapeamento reason -> code conforme docs/specs/cloud-functions.md §1.1.
 */
const REASON_CODES = {
  NOT_OWNER: "permission-denied",
  NOT_MEMBER: "permission-denied",
  FAMILY_FROZEN: "failed-precondition",
  FEATURE_NOT_IN_PLAN: "failed-precondition",
  PLAN_LIMIT_MEMBERS: "failed-precondition",
  PLAN_LIMIT_HOUSEHOLDS: "failed-precondition",
  OWNER_HAS_MEMBERS: "failed-precondition",
  LAST_HOUSEHOLD: "failed-precondition",
  OWNER_CANNOT_LEAVE: "failed-precondition",
  TRANSFER_PENDING: "failed-precondition",
  BOOTSTRAP_REQUIRED: "failed-precondition",
  REQUIRES_RECENT_LOGIN: "failed-precondition",
  FAMILY_NOT_FOUND: "not-found",
  HOUSEHOLD_NOT_FOUND: "not-found",
  INVITE_NOT_FOUND: "not-found",
  MEMBER_NOT_FOUND: "not-found",
  ALREADY_MEMBER: "already-exists",
  INVITE_EXPIRED: "deadline-exceeded",
  TRANSFER_EXPIRED: "deadline-exceeded",
  RATE_LIMITED: "resource-exhausted",
} as const satisfies Record<string, FunctionsErrorCode>;

export type ErrorReason = keyof typeof REASON_CODES;

/** Erro de regra de negócio/autorização com `reason` estável. */
export function domainError(reason: ErrorReason, extra: Record<string, unknown> = {}): HttpsError {
  return new HttpsError(REASON_CODES[reason], reason, { ...extra, reason });
}

/** `invalid-argument`: o `reason` é o nome do campo inválido. */
export function invalidArgument(field: string): HttpsError {
  return new HttpsError("invalid-argument", `Campo inválido: ${field}`, { reason: field });
}

export function unauthenticated(): HttpsError {
  return new HttpsError("unauthenticated", "Login necessário.");
}

/** Extrai o reason de qualquer erro (para log); `INTERNAL` se não for HttpsError. */
export function reasonOf(e: unknown): string {
  if (e instanceof HttpsError) {
    const d = e.details as { reason?: unknown } | undefined;
    return typeof d?.reason === "string" ? d.reason : e.code;
  }
  return "INTERNAL";
}

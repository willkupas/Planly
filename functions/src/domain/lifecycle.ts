import { Entitlement, PLANS, PlanId } from "./plans";

/**
 * Regras puras do ciclo de vida da Family (data-model §4/§8, cloud-functions §4.1).
 * Sem Firestore: tudo em milissegundos para ser testável com relógio injetado.
 */
export const DAY_MS = 24 * 60 * 60 * 1000;
export const FROZEN_RETENTION_DAYS = 90;
export const REGULARIZE_DAYS = 30;
export const EXPIRY_WARNING_DAYS = 7;

export type SubscriptionState = "active" | "grace" | "on_hold" | "canceled" | "expired";

export interface SubscriptionView {
  state: SubscriptionState;
  expiresAtMs: number | null;
}

/**
 * Assinatura "expirada" para fins de ciclo de vida: `expired` (a Play já passou grace/hold)
 * ou `canceled` (renovação desligada) cujo período pago acabou. `active/grace/on_hold` nunca
 * expiram aqui: quem os muda é o billing (RTDN/reconcile), não este job.
 */
export function isSubscriptionExpired(sub: SubscriptionView | null, nowMs: number): boolean {
  if (!sub) return false;
  if (sub.state === "expired") return true;
  return sub.state === "canceled" && sub.expiresAtMs !== null && sub.expiresAtMs <= nowMs;
}

/** Assinatura que ainda dá direito ao plano (impede congelar/excluir). */
export function isSubscriptionLive(sub: SubscriptionView | null, nowMs: number): boolean {
  if (!sub) return false;
  if (sub.state === "active" || sub.state === "grace" || sub.state === "on_hold") return true;
  return sub.state === "canceled" && sub.expiresAtMs !== null && sub.expiresAtMs > nowMs;
}

export type ExpiryOutcome = "downgrade_free" | "freeze";

/** data-model §8 #17: só owner e <= 1 casa -> Free; senão frozen. */
export function expiryOutcome(usage: { activeMembers: number; households: number }): ExpiryOutcome {
  return usage.activeMembers <= 1 && usage.households <= 1 ? "downgrade_free" : "freeze";
}

export function deleteAfterMs(frozenAtMs: number): number {
  return frozenAtMs + FROZEN_RETENTION_DAYS * DAY_MS;
}

export function regularizeByMs(nowMs: number): number {
  return nowMs + REGULARIZE_DAYS * DAY_MS;
}

/** Uso acima do limite do plano atual (null = ilimitado). */
export function isOverLimit(
  usage: { activeMembers: number; households: number },
  limits: Pick<Entitlement, "maxMembers" | "maxHouseholds">,
): boolean {
  return (
    usage.activeMembers > limits.maxMembers ||
    (limits.maxHouseholds !== null && usage.households > limits.maxHouseholds)
  );
}

export function limitsFor(plan: PlanId, entitlement?: Partial<Entitlement> | null) {
  const base = PLANS[plan] ?? PLANS.free;
  return {
    maxMembers: typeof entitlement?.maxMembers === "number" ? entitlement.maxMembers : base.maxMembers,
    maxHouseholds:
      entitlement && "maxHouseholds" in entitlement && entitlement.maxHouseholds !== undefined
        ? (entitlement.maxHouseholds ?? null)
        : base.maxHouseholds,
  };
}

/** Avisos de exclusão: dias antes de `deleteAfter`. Ordem decrescente. */
export const DELETION_WARNINGS = [
  { type: "delete_d60", daysBefore: 60 },
  { type: "delete_d30", daysBefore: 30 },
  { type: "delete_d7", daysBefore: 7 },
  { type: "delete_d1", daysBefore: 1 },
] as const;

export type DeletionWarningType = (typeof DELETION_WARNINGS)[number]["type"];

/**
 * Qual aviso de exclusão enviar agora. Se o job ficou parado e mais de um marco venceu,
 * envia só o mais recente (o mais urgente) e marca todos os vencidos para não repetir.
 * Depois de `deleteAfter` não há aviso (a família segue para `deleting`).
 */
export function dueDeletionWarning(
  deleteAfterMsValue: number,
  nowMs: number,
  alreadyNotified: ReadonlySet<string>,
): { send: DeletionWarningType | null; markAll: DeletionWarningType[] } {
  if (nowMs >= deleteAfterMsValue) return { send: null, markAll: [] };
  const due = DELETION_WARNINGS.filter(
    (w) => deleteAfterMsValue - w.daysBefore * DAY_MS <= nowMs && !alreadyNotified.has(w.type),
  );
  if (due.length === 0) return { send: null, markAll: [] };
  return { send: due[due.length - 1].type, markAll: due.map((w) => w.type) };
}

/**
 * Aviso D-7 de expiração: assinatura sem renovação (canceled) que vence em <= 7 dias e ainda
 * não venceu. `lastNotifiedMs` é o `notifiedAt.expiry_d7` anterior; um aviso de ciclo anterior
 * (anterior ao início da janela atual) não conta, então renovar e cancelar de novo avisa de novo.
 */
export function isExpiryWarningDue(
  sub: SubscriptionView | null,
  nowMs: number,
  lastNotifiedMs: number | null,
): boolean {
  if (!sub || sub.state !== "canceled" || sub.expiresAtMs === null) return false;
  if (sub.expiresAtMs <= nowMs) return false;
  const windowStart = sub.expiresAtMs - EXPIRY_WARNING_DAYS * DAY_MS;
  if (nowMs < windowStart) return false;
  return lastNotifiedMs === null || lastNotifiedMs < windowStart;
}

/** Aparelho sem uso há mais de 90 dias. */
export const DEVICE_STALE_DAYS = 90;
export const RATE_LIMIT_STALE_MS = DAY_MS;

/**
 * Fonte única dos planos (data-model §3.7). Preços NÃO vivem aqui (vêm da Play).
 * `maxHouseholds: null` = ilimitado.
 */
export type PlanId = "free" | "family" | "family_plus";

export interface Entitlement {
  plan: PlanId;
  maxMembers: number;
  maxHouseholds: number | null;
  features: {
    invites: boolean;
    recurringTasks: boolean;
    fullHistory: boolean;
  };
}

export const PLANS: Readonly<Record<PlanId, Entitlement>> = {
  free: {
    plan: "free",
    maxMembers: 1,
    maxHouseholds: 1,
    features: { invites: false, recurringTasks: false, fullHistory: false },
  },
  family: {
    plan: "family",
    maxMembers: 4,
    maxHouseholds: 3,
    features: { invites: true, recurringTasks: true, fullHistory: true },
  },
  family_plus: {
    plan: "family_plus",
    maxMembers: 8,
    maxHouseholds: null,
    features: { invites: true, recurringTasks: true, fullHistory: true },
  },
};

export function isPlanId(v: unknown): v is PlanId {
  return v === "free" || v === "family" || v === "family_plus";
}

/** Cópia mutável do entitlement do plano (segura para gravar). */
export function entitlementFor(plan: PlanId): Entitlement {
  const p = PLANS[plan];
  return { ...p, features: { ...p.features } };
}

/** Há vaga para mais uma casa? */
export function canAddHousehold(limits: Pick<Entitlement, "maxHouseholds">, current: number): boolean {
  return limits.maxHouseholds === null || current < limits.maxHouseholds;
}

/** Há vaga para mais um membro (contando reservas, p.ex. convites pendentes)? */
export function canAddMember(
  limits: Pick<Entitlement, "maxMembers">,
  current: number,
  reserved = 0,
): boolean {
  return current + reserved < limits.maxMembers;
}

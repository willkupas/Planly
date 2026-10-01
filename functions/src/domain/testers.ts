import type { Transaction } from "firebase-admin/firestore";
import { TESTER_PLANS_ENABLED } from "../config";
import { db } from "../lib/db";
import { isPlanId, type PlanId } from "./plans";

/**
 * Lista de testadores (só dev/emulador): `_testers/{email em minúsculas}` com `{ plan }`.
 * Escrita só pelo console/Admin (as Rules negam tudo fora do que está liberado). Concede apenas
 * plano; não dá acesso a famílias nem casas (isso continua por UID). Só vale para e-mail verificado.
 */
const RANK: Record<PlanId, number> = { free: 0, family: 1, family_plus: 2 };

export function planRank(plan: PlanId): number {
  return RANK[plan];
}

/** Plano de teste configurado para o e-mail (ou null). Chamar antes de qualquer escrita da transação. */
export async function testerPlanFor(
  tx: Transaction,
  email: string | null,
  emailVerified: boolean,
): Promise<PlanId | null> {
  if (!TESTER_PLANS_ENABLED || !email || !emailVerified) return null;
  const snap = await tx.get(db().doc(`_testers/${email.trim().toLowerCase()}`));
  const plan = snap.get("plan");
  return isPlanId(plan) && plan !== "free" ? plan : null;
}

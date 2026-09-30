import { Timestamp, Transaction } from "firebase-admin/firestore";
import { domainError } from "../domain/errors";
import { paths } from "./db";

/**
 * Rate limit por (uid, função) em `_rateLimits/{uid}_{fn}` (spec §1.3).
 * Duas fases porque transações exigem todas as leituras antes das escritas:
 * `prepareRateLimit` lê e lança RATE_LIMITED; `apply()` agenda a escrita do contador.
 */
export async function prepareRateLimit(
  tx: Transaction,
  uid: string,
  fn: string,
  max: number,
  windowMs: number,
): Promise<{ apply: () => void }> {
  const ref = paths.rateLimit(uid, fn);
  const snap = await tx.get(ref);
  const now = Date.now();
  const start = snap.get("windowStart") as Timestamp | undefined;
  const inWindow = start !== undefined && now - start.toMillis() < windowMs;
  const count = inWindow ? (snap.get("count") as number) : 0;
  if (count >= max) throw domainError("RATE_LIMITED");
  return {
    apply: () =>
      tx.set(ref, {
        count: count + 1,
        windowStart: inWindow ? start : Timestamp.fromMillis(now),
      }),
  };
}

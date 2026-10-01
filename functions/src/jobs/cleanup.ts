import { FieldValue, Timestamp } from "firebase-admin/firestore";
import { DAY_MS, DEVICE_STALE_DAYS, RATE_LIMIT_STALE_MS } from "../domain/lifecycle";
import { Clock, systemClock } from "../lib/clock";
import { db, paths } from "../lib/db";
import { deleteRefs } from "./cascade";
import { logJob, safeReason } from "./jobLog";
import { JobDeps } from "./lifecycle";
import { forEachPage } from "./paging";

const PAGE = 200;
const FN = "cleanupJob";

export interface CleanupResult {
  invitationsExpired: number;
  rateLimitsDeleted: number;
  devicesDeleted: number;
  errors: number;
}

/**
 * cloud-functions §4.3. (a) convites `pending` vencidos -> `expired` (a política TTL em
 * `purgeAt` apaga depois); (b) `_rateLimits` com janela de mais de 24h (a maior janela usada
 * é 1h); (c) `devices` sem `lastSeenAt` há mais de 90 dias.
 * `devices` usa collection group (override de índice em firebase/firestore.indexes.json).
 */
export async function runCleanup(deps: Pick<JobDeps, "clock"> = {}): Promise<CleanupResult> {
  const clock: Clock = deps.clock ?? systemClock;
  const start = clock.nowMs();
  const nowTs = Timestamp.fromMillis(start);
  const res: CleanupResult = { invitationsExpired: 0, rateLimitsDeleted: 0, devicesDeleted: 0, errors: 0 };

  // (a) Convites. Query só por expiresAt (sem composta); status filtrado na transação.
  await forEachPage(paths.invitations().where("expiresAt", "<=", nowTs), PAGE, async (d) => {
    try {
      const changed = await db().runTransaction(async (tx) => {
        const s = await tx.get(d.ref);
        if (!s.exists || s.get("status") !== "pending") return false;
        const exp = s.get("expiresAt") as Timestamp;
        if (exp.toMillis() > clock.nowMs()) return false;
        tx.update(d.ref, { status: "expired", expiredAt: FieldValue.serverTimestamp() });
        return true;
      });
      if (changed) res.invitationsExpired++;
    } catch (e) {
      res.errors++;
      logJob({ function: FN, operation: "expire_invitation", result: "error", errorReason: safeReason(e) });
    }
  });

  // (b) Rate limits antigos.
  const rlCutoff = Timestamp.fromMillis(start - RATE_LIMIT_STALE_MS);
  await sweep(db().collection("_rateLimits").where("windowStart", "<", rlCutoff), "rate_limits", (n) => (res.rateLimitsDeleted += n), res);

  // (c) Aparelhos sem uso.
  const devCutoff = Timestamp.fromMillis(start - DEVICE_STALE_DAYS * DAY_MS);
  await sweep(db().collectionGroup("devices").where("lastSeenAt", "<", devCutoff), "devices", (n) => (res.devicesDeleted += n), res);

  logJob({
    function: FN,
    operation: "run",
    result: res.errors === 0 ? "ok" : "error",
    counts: { ...res },
    durationMs: clock.nowMs() - start,
  });
  return res;
}

async function sweep(
  query: FirebaseFirestore.Query,
  operation: string,
  add: (n: number) => void,
  res: CleanupResult,
): Promise<void> {
  let batch: FirebaseFirestore.DocumentReference[] = [];
  const flush = async () => {
    if (batch.length === 0) return;
    const refs = batch;
    batch = [];
    try {
      await deleteRefs(refs);
      add(refs.length);
    } catch (e) {
      res.errors++;
      logJob({ function: FN, operation, result: "error", errorReason: safeReason(e) });
    }
  };
  await forEachPage(query, PAGE, async (d) => {
    batch.push(d.ref);
    if (batch.length >= PAGE) await flush();
  });
  await flush();
}

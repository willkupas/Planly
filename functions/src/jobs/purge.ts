import { Timestamp } from "firebase-admin/firestore";
import { DAY_MS } from "../domain/lifecycle";
import { HOUSEHOLD_RETENTION_DAYS } from "../domain/model";
import { Clock, systemClock } from "../lib/clock";
import { db, paths } from "../lib/db";
import { hardDeleteFamily, recursiveDeleteRef } from "./cascade";
import { logJob, safeReason } from "./jobLog";
import { JobDeps } from "./lifecycle";
import { forEachPage } from "./paging";

const PAGE = 100;
const FN = "purgeJob";

export interface PurgeResult {
  households: number;
  tasks: number;
  lists: number;
  items: number;
  families: number;
  errors: number;
}

/**
 * cloud-functions §4.2. Hard delete de (a) casas soft-deleted há 30 dias, (b) tasks/lists/items
 * soft-deleted há 30 dias e (c) famílias `deleting`, em cascata. Idempotente e retomável: uma
 * falha por item é registrada e não interrompe os demais; na próxima execução o que sobrou
 * ainda satisfaz a query. Usa consultas de collection group por `deletedAt` (precisam dos
 * overrides de índice em firebase/firestore.indexes.json).
 */
export async function runPurge(deps: Pick<JobDeps, "clock"> = {}): Promise<PurgeResult> {
  const clock: Clock = deps.clock ?? systemClock;
  const start = clock.nowMs();
  const cutoff = Timestamp.fromMillis(start - HOUSEHOLD_RETENTION_DAYS * DAY_MS);
  const res: PurgeResult = { households: 0, tasks: 0, lists: 0, items: 0, families: 0, errors: 0 };

  const purgeGroup = async (group: "households" | "tasks" | "lists" | "items", key: keyof PurgeResult) => {
    await forEachPage(db().collectionGroup(group).where("deletedAt", "<=", cutoff), PAGE, async (d) => {
      try {
        await recursiveDeleteRef(d.ref);
        res[key]++;
      } catch (e) {
        res.errors++;
        logJob({ function: FN, operation: `purge_${group}`, result: "error", errorReason: safeReason(e) });
      }
    });
  };

  // Casas primeiro (levam o conteúdo junto); depois o que sobrou solto em casas vivas.
  await purgeGroup("households", "households");
  await purgeGroup("tasks", "tasks");
  await purgeGroup("lists", "lists");
  await purgeGroup("items", "items");

  await forEachPage(paths.families().where("status", "==", "deleting"), 50, async (d) => {
    try {
      await hardDeleteFamily(d.id);
      res.families++;
    } catch (e) {
      res.errors++;
      logJob({ function: FN, operation: "purge_family", result: "error", familyId: d.id, errorReason: safeReason(e) });
    }
  });

  logJob({
    function: FN,
    operation: "run",
    result: res.errors === 0 ? "ok" : "error",
    counts: { ...res },
    durationMs: clock.nowMs() - start,
  });
  return res;
}

import "../config";
import { onSchedule } from "firebase-functions/v2/scheduler";
import { REGION } from "../config";
import { runCleanup } from "./cleanup";
import { runLifecycle } from "./lifecycle";
import { runPurge } from "./purge";

const TZ = "America/Sao_Paulo";
const BASE = { region: REGION, timeZone: TZ, retryCount: 0, timeoutSeconds: 540, memory: "512MiB" as const };

/** Diário 03:00 (cloud-functions §4.1). Requer Blaze (Cloud Scheduler). */
export const lifecycleJob = onSchedule({ ...BASE, schedule: "0 3 * * *" }, async () => {
  await runLifecycle();
});

/** Diário 04:00, depois do ciclo de vida (que marca famílias `deleting`). */
export const purgeJob = onSchedule({ ...BASE, schedule: "0 4 * * *" }, async () => {
  await runPurge();
});

/** Diário 05:00. */
export const cleanupJob = onSchedule({ ...BASE, schedule: "0 5 * * *" }, async () => {
  await runCleanup();
});

import "../config";
import { onRequest } from "firebase-functions/v2/https";
import { REGION } from "../config";
import { fixedClock } from "../lib/clock";
import { runCleanup } from "./cleanup";
import { runLifecycle } from "./lifecycle";
import { runPurge } from "./purge";

/**
 * Endpoint de TESTE para rodar os jobs no emulador (o Scheduler não dispara sozinho lá).
 * Só é carregado por `index.ts` quando `FUNCTIONS_EMULATOR === "true"` e ainda recusa se a
 * variável não estiver ligada: na nuvem não existe e nenhum cliente consegue invocar os jobs.
 * Corpo: `{ job: "lifecycle" | "purge" | "cleanup", nowMs?: number }` (relógio simulado).
 */
export const runScheduledJob = onRequest({ region: REGION }, async (req, res) => {
  if (process.env.FUNCTIONS_EMULATOR !== "true") {
    res.status(404).send("not found");
    return;
  }
  if (req.method !== "POST") {
    res.status(405).send("method not allowed");
    return;
  }
  const body = (req.body ?? {}) as { job?: unknown; nowMs?: unknown };
  const clock = typeof body.nowMs === "number" ? fixedClock(body.nowMs) : undefined;
  switch (body.job) {
    case "lifecycle":
      res.json({ ok: true, result: await runLifecycle({ clock }) });
      return;
    case "purge":
      res.json({ ok: true, result: await runPurge({ clock }) });
      return;
    case "cleanup":
      res.json({ ok: true, result: await runCleanup({ clock }) });
      return;
    default:
      res.status(400).json({ ok: false, error: "unknown job" });
  }
});

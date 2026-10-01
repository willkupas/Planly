import { db, paths } from "../lib/db";
import { logCall } from "../lib/logger";
import { filterByPreferences } from "./pushPreferences";
import { INVALID_TOKEN_CODES, defaultPushSender } from "./pushSender";
import { PushEvent, PushMessage, PushSender } from "./pushTypes";

interface DeviceRef {
  uid: string;
  path: string;
  token: string;
}

/** Limite de aparelhos por usuário considerados no envio (custo/abuso). */
const MAX_DEVICES_PER_USER = 10;

/**
 * Destinatários de um evento: `accessUids ∪ owner` da casa, menos o autor (e exclusões).
 * Casa/família inexistente ou casa excluída resulta em ninguém.
 */
export async function resolveRecipients(e: PushEvent): Promise<string[]> {
  const [house, fam] = await Promise.all([
    paths.household(e.familyId, e.householdId).get(),
    paths.family(e.familyId).get(),
  ]);
  if (!house.exists || !fam.exists) return [];
  if (house.get("deletedAt") != null) return [];

  const all = new Set<string>((house.get("accessUids") as string[] | undefined) ?? []);
  const owner = fam.get("ownerId") as string | undefined;
  if (owner) all.add(owner);

  const only = e.onlyUids ? new Set(e.onlyUids) : undefined;
  const excluded = new Set(e.excludeUids ?? []);
  excluded.add(e.actorId);
  return [...all].filter((u) => !excluded.has(u) && (!only || only.has(u)));
}

async function loadDevices(uids: string[]): Promise<DeviceRef[]> {
  const snaps = await Promise.all(
    uids.map((uid) => db().collection(`users/${uid}/devices`).limit(MAX_DEVICES_PER_USER).get()),
  );
  const out: DeviceRef[] = [];
  snaps.forEach((s, i) => {
    for (const d of s.docs) {
      const token = d.get("fcmToken");
      if (typeof token === "string" && token.length > 0) {
        out.push({ uid: uids[i], path: d.ref.path, token });
      }
    }
  });
  return out;
}

export interface DispatchResult {
  recipients: number;
  sent: number;
  failed: number;
  removedTokens: number;
}

/**
 * Envia o push de um evento compartilhado. Payload só com ids e tipo; remove os devices cujo
 * token o FCM recusou como inválido; logs só com contadores (sem tokens nem conteúdo).
 */
export async function dispatchPush(
  e: PushEvent,
  sender: PushSender = defaultPushSender(),
): Promise<DispatchResult> {
  const started = Date.now();
  const empty: DispatchResult = { recipients: 0, sent: 0, failed: 0, removedTokens: 0 };
  try {
    const candidates = await resolveRecipients(e);
    const uids = await filterByPreferences(candidates, e.type);
    if (uids.length === 0) return empty;

    const devices = await loadDevices(uids);
    const data = {
      type: e.type,
      familyId: e.familyId,
      householdId: e.householdId,
      targetId: e.targetId,
    };
    const messages: PushMessage[] = devices.map((d) => ({
      token: d.token,
      data,
      collapseKey: `${e.type}:${e.targetId}`,
    }));
    const results = messages.length > 0 ? await sender.send(messages) : [];

    let sent = 0;
    let failed = 0;
    const toRemove: string[] = [];
    results.forEach((r, i) => {
      if (r.success) sent++;
      else {
        failed++;
        if (r.errorCode && INVALID_TOKEN_CODES.has(r.errorCode)) toRemove.push(devices[i].path);
      }
    });
    await Promise.all(toRemove.map((p) => db().doc(p).delete()));

    const res = { recipients: uids.length, sent, failed, removedTokens: toRemove.length };
    logCall({
      function: "push",
      familyId: e.familyId,
      householdId: e.householdId,
      operation: e.type,
      result: "ok",
      durationMs: Date.now() - started,
      ...res,
    });
    return res;
  } catch (err) {
    logCall({
      function: "push",
      familyId: e.familyId,
      householdId: e.householdId,
      operation: e.type,
      result: "error",
      errorReason: err instanceof Error ? err.name : "unknown",
      durationMs: Date.now() - started,
    });
    return empty;
  }
}

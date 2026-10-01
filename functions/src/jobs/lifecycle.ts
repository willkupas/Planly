import { FieldValue, Timestamp } from "firebase-admin/firestore";
import {
  SubscriptionState,
  SubscriptionView,
  deleteAfterMs,
  dueDeletionWarning,
  expiryOutcome,
  isExpiryWarningDue,
  isOverLimit,
  isSubscriptionExpired,
  isSubscriptionLive,
  limitsFor,
} from "../domain/lifecycle";
import { FamilyStatus } from "../domain/model";
import { PlanId, entitlementFor, isPlanId } from "../domain/plans";
import { Clock, systemClock } from "../lib/clock";
import { db, paths } from "../lib/db";
import { logJob, safeReason } from "./jobLog";
import { JobNotification, Notifier, defaultNotify } from "./notify";
import { forEachPage } from "./paging";

const PAGE = 100;
const FN = "lifecycleJob";

export interface JobDeps {
  clock?: Clock;
  notify?: Notifier;
}

export interface LifecycleResult {
  downgraded: number;
  frozen: number;
  regularizeCleared: number;
  deleting: number;
  warned: number;
  transfersCleared: number;
  errors: number;
}

interface FamilyData {
  status: FamilyStatus;
  plan: PlanId;
  ownerId: string;
  frozenAt?: Timestamp | null;
  deleteAfter?: Timestamp | null;
  regularizeBy?: Timestamp | null;
  notifiedAt?: Record<string, Timestamp>;
  pendingTransfer?: { toUid: string; expiresAt: Timestamp } | null;
}

type Outcome = "downgraded" | "frozen" | "regularizeCleared" | "deleting" | "warned" | "skip";
interface Decision {
  outcome: Outcome;
  notifications: JobNotification[];
}

/**
 * cloud-functions §4.1. Idempotente: cada decisão é tomada numa transação que relê a família,
 * então rodar duas vezes (ou em paralelo) não repete efeitos nem avisos (`notifiedAt`).
 * Passos de exclusão (`deleting`) só marcam; a cascata é do `purgeJob`.
 * Avisos: grava a flag in-app (`notifiedAt`) na mesma transação e chama o gancho `notify`
 * depois do commit (falha do gancho não desfaz a flag: sem repetição).
 */
export async function runLifecycle(deps: JobDeps = {}): Promise<LifecycleResult> {
  const clock = deps.clock ?? systemClock;
  const notify = deps.notify ?? defaultNotify;
  const start = clock.nowMs();
  const res: LifecycleResult = {
    downgraded: 0,
    frozen: 0,
    regularizeCleared: 0,
    deleting: 0,
    warned: 0,
    transfersCleared: 0,
    errors: 0,
  };

  const handle = async (familyId: string, fn: () => Promise<Decision>) => {
    try {
      const d = await fn();
      if (d.outcome === "downgraded") res.downgraded++;
      else if (d.outcome === "frozen") res.frozen++;
      else if (d.outcome === "regularizeCleared") res.regularizeCleared++;
      else if (d.outcome === "deleting") res.deleting++;
      else if (d.outcome === "warned") res.warned++;
      for (const n of d.notifications) {
        try {
          await notify(n);
        } catch (e) {
          logJob({ function: FN, operation: "notify", result: "error", familyId, errorReason: safeReason(e) });
        }
      }
    } catch (e) {
      res.errors++;
      logJob({ function: FN, operation: "family", result: "error", familyId, errorReason: safeReason(e) });
    }
  };

  // 1. Famílias pagas ativas (expiração, regularização, aviso D-7).
  await forEachPage(
    paths.families().where("status", "==", "active").where("plan", "in", ["family", "family_plus"]),
    PAGE,
    (d) => handle(d.id, () => processPaidActive(d.id, clock)),
  );

  // 2. Famílias frozen (avisos de exclusão; deleteAfter atingido -> deleting).
  await forEachPage(paths.families().where("status", "==", "frozen"), PAGE, (d) =>
    handle(d.id, () => processFrozen(d.id, clock)),
  );

  // 3. Transferências pendentes expiradas.
  const nowTs = Timestamp.fromMillis(clock.nowMs());
  await forEachPage(paths.families().where("pendingTransfer.expiresAt", "<=", nowTs), PAGE, async (d) => {
    try {
      const cleared = await db().runTransaction(async (tx) => {
        const s = await tx.get(d.ref);
        const f = s.data() as FamilyData | undefined;
        if (!f || f.status === "deleting") return false;
        const exp = f.pendingTransfer?.expiresAt;
        if (!exp || exp.toMillis() > clock.nowMs()) return false;
        tx.update(d.ref, { pendingTransfer: null, updatedAt: FieldValue.serverTimestamp() });
        return true;
      });
      if (cleared) res.transfersCleared++;
    } catch (e) {
      res.errors++;
      logJob({ function: FN, operation: "pendingTransfer", result: "error", familyId: d.id, errorReason: safeReason(e) });
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

function parseSub(data: Record<string, unknown> | undefined): SubscriptionView | null {
  if (!data) return null;
  const state = data.state as SubscriptionState | undefined;
  if (!state) return null;
  const exp = data.expiresAt as Timestamp | undefined;
  return { state, expiresAtMs: exp ? exp.toMillis() : null };
}

const SKIP: Decision = { outcome: "skip", notifications: [] };

async function processPaidActive(familyId: string, clock: Clock): Promise<Decision> {
  return db().runTransaction(async (tx): Promise<Decision> => {
    const now = clock.nowMs();
    const nowTs = Timestamp.fromMillis(now);
    const famRef = paths.family(familyId);
    const famSnap = await tx.get(famRef);
    const f = famSnap.data() as FamilyData | undefined;
    if (!f || f.status !== "active" || !isPlanId(f.plan) || f.plan === "free") return SKIP;

    const subRef = famRef.collection("billing").doc("subscription");
    const [subSnap, entSnap, membersSnap, hhSnap] = await Promise.all([
      tx.get(subRef),
      tx.get(paths.entitlement(familyId)),
      tx.get(famRef.collection("members").where("status", "==", "active").limit(100)),
      tx.get(paths.households(familyId).where("deletedAt", "==", null)),
    ]);
    const sub = parseSub(subSnap.data());
    const usage = { activeMembers: membersSnap.size, households: hhSnap.size };
    const memberUids = membersSnap.docs.map((m) => m.id);
    const mirrorRefs = memberUids.map((u) => paths.membership(u, familyId));
    const mirrors = mirrorRefs.length > 0 ? await tx.getAll(...mirrorRefs) : [];
    const liveMirrors = mirrors.filter((m) => m.exists).map((m) => m.ref);
    const server = FieldValue.serverTimestamp();

    const freeze = (): Decision => {
      tx.update(famRef, {
        status: "frozen",
        frozenAt: nowTs,
        deleteAfter: Timestamp.fromMillis(deleteAfterMs(now)),
        regularizeBy: FieldValue.delete(),
        notifiedAt: { frozen_d0: nowTs },
        updatedAt: server,
      });
      for (const r of liveMirrors) tx.update(r, { familyStatus: "frozen", updatedAt: server });
      return { outcome: "frozen", notifications: [{ type: "frozen_d0", familyId, recipientUids: memberUids }] };
    };

    if (isSubscriptionExpired(sub, now)) {
      if (expiryOutcome(usage) === "downgrade_free") {
        tx.update(famRef, {
          plan: "free",
          regularizeBy: FieldValue.delete(),
          notifiedAt: FieldValue.delete(),
          updatedAt: server,
        });
        tx.set(paths.entitlement(familyId), { ...entitlementFor("free"), source: "default", updatedAt: server });
        tx.delete(subRef);
        for (const r of liveMirrors) tx.update(r, { plan: "free", updatedAt: server });
        return { outcome: "downgraded", notifications: [] };
      }
      return freeze();
    }

    if (f.regularizeBy && f.regularizeBy.toMillis() <= now) {
      const limits = limitsFor(f.plan, entSnap.data());
      if (isOverLimit(usage, limits)) return freeze();
      tx.update(famRef, { regularizeBy: FieldValue.delete(), updatedAt: server });
      return { outcome: "regularizeCleared", notifications: [] };
    }

    const last = f.notifiedAt?.expiry_d7;
    if (isExpiryWarningDue(sub, now, last ? last.toMillis() : null)) {
      tx.update(famRef, { "notifiedAt.expiry_d7": nowTs, updatedAt: server });
      return { outcome: "warned", notifications: [{ type: "expiry_d7", familyId, recipientUids: memberUids }] };
    }
    return SKIP;
  });
}

async function processFrozen(familyId: string, clock: Clock): Promise<Decision> {
  return db().runTransaction(async (tx): Promise<Decision> => {
    const now = clock.nowMs();
    const nowTs = Timestamp.fromMillis(now);
    const famRef = paths.family(familyId);
    const famSnap = await tx.get(famRef);
    const f = famSnap.data() as FamilyData | undefined;
    if (!f || f.status !== "frozen") return SKIP;

    const subSnap = await tx.get(famRef.collection("billing").doc("subscription"));
    const membersSnap = await tx.get(famRef.collection("members").where("status", "==", "active").limit(100));
    const memberUids = membersSnap.docs.map((m) => m.id);
    const mirrorRefs = memberUids.map((u) => paths.membership(u, familyId));
    const mirrors = mirrorRefs.length > 0 ? await tx.getAll(...mirrorRefs) : [];
    const server = FieldValue.serverTimestamp();

    let deleteAfter = f.deleteAfter?.toMillis();
    if (deleteAfter === undefined) {
      // Dado incompleto: reconstrói a partir de frozenAt (ou agora) em vez de nunca excluir.
      deleteAfter = deleteAfterMs(f.frozenAt?.toMillis() ?? now);
      tx.update(famRef, { deleteAfter: Timestamp.fromMillis(deleteAfter), updatedAt: server });
    }

    if (deleteAfter <= now) {
      // Assinatura vigente (reassinatura em curso) nunca é excluída.
      if (isSubscriptionLive(parseSub(subSnap.data()), now)) return SKIP;
      tx.update(famRef, { status: "deleting", updatedAt: server });
      for (const m of mirrors) if (m.exists) tx.update(m.ref, { familyStatus: "deleting", updatedAt: server });
      return { outcome: "deleting", notifications: [] };
    }

    const due = dueDeletionWarning(deleteAfter, now, new Set(Object.keys(f.notifiedAt ?? {})));
    if (!due.send) return SKIP;
    const upd: Record<string, unknown> = { updatedAt: server };
    for (const t of due.markAll) upd[`notifiedAt.${t}`] = nowTs;
    tx.update(famRef, upd);
    return { outcome: "warned", notifications: [{ type: due.send, familyId, recipientUids: memberUids }] };
  });
}

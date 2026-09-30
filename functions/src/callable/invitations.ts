import { FieldPath, FieldValue, Timestamp } from "firebase-admin/firestore";
import { INVITE_LINK_BASE } from "../config";
import { domainError, invalidArgument } from "../domain/errors";
import {
  INVITE_PURGE_AFTER_MS,
  INVITE_TTL_MS,
  MAX_GRANTS,
  generateCode,
  normalizeCode,
} from "../domain/invitations";
import { FamilyDoc, HouseholdDoc, HouseholdRole, MemberDoc, SCHEMA_VERSION } from "../domain/model";
import { Entitlement, PLANS, canAddMember, isPlanId } from "../domain/plans";
import { writeActivity } from "../lib/activity";
import { loadFamilyContext, loadLimits, requireActive, requireOwner } from "../lib/authz";
import { defineCallable } from "../lib/callable";
import { db, paths } from "../lib/db";
import { prepareRateLimit } from "../lib/rateLimit";
import { asObject, reqId, reqString } from "../lib/validate";

const HOUR_MS = 60 * 60 * 1000;
const MAX_CODE_ATTEMPTS = 5;

interface Grant {
  householdId: string;
  role: HouseholdRole;
}

interface InvitationDoc {
  familyId: string;
  grants: Grant[];
  createdBy: string;
  status: "pending" | "accepted" | "revoked" | "expired";
  expiresAt: Timestamp;
  acceptedBy?: string;
}

function parseGrants(data: Record<string, unknown>): Grant[] {
  const raw = data.grants;
  if (!Array.isArray(raw) || raw.length < 1 || raw.length > MAX_GRANTS) throw invalidArgument("grants");
  const seen = new Set<string>();
  return raw.map((g) => {
    if (typeof g !== "object" || g === null || Array.isArray(g)) throw invalidArgument("grants");
    const o = g as Record<string, unknown>;
    const householdId = reqId(o, "householdId");
    if (o.role !== "admin" && o.role !== "member") throw invalidArgument("grants");
    if (seen.has(householdId)) throw invalidArgument("grants");
    seen.add(householdId);
    return { householdId, role: o.role };
  });
}

/**
 * Código vindo do cliente. Tipo errado = invalid-argument; formato que não é de um código
 * = `null` (tratado como INVITE_NOT_FOUND, sem distinguir "inexistente" de "já usado").
 */
function parseCode(data: Record<string, unknown>): string | null {
  return normalizeCode(reqString(data, "code", 1, 64));
}

/** §2.5 — owner cria convite (Free bloqueado). O código NUNCA é logado. */
export const createInvitation = defineCallable("createInvitation", async (ctx, input) => {
  const data = asObject(input);
  const familyId = reqId(data, "familyId");
  const grants = parseGrants(data);
  ctx.familyId = familyId;

  for (let attempt = 0; attempt < MAX_CODE_ATTEMPTS; attempt++) {
    const code = generateCode();
    const expiresAtMs = Date.now() + INVITE_TTL_MS;

    const outcome = await db().runTransaction(async (tx) => {
      const c = await loadFamilyContext(tx, familyId, ctx.uid);
      requireOwner(c);
      requireActive(c.family);
      const rl = await prepareRateLimit(tx, familyId, "createInvitation", 20, HOUR_MS);

      const entSnap = await tx.get(paths.entitlement(familyId));
      const ent = entSnap.exists ? (entSnap.data() as Entitlement) : undefined;
      const plan = isPlanId(c.family.plan) ? c.family.plan : "free";
      const invitesAllowed = ent?.features?.invites ?? PLANS[plan].features.invites;
      if (invitesAllowed !== true) throw domainError("FEATURE_NOT_IN_PLAN");
      const limits = await loadLimits(tx, familyId, c.family);

      // Só igualdade (sem índice composto); expiração filtrada em memória.
      const pendingSnap = await tx.get(
        paths.invitations().where("familyId", "==", familyId).where("status", "==", "pending").limit(100),
      );
      const nowMs = Date.now();
      const pending = pendingSnap.docs.filter((d) => (d.get("expiresAt") as Timestamp).toMillis() > nowMs).length;
      if (!canAddMember(limits, c.family.memberCount, pending)) throw domainError("PLAN_LIMIT_MEMBERS");

      // Todas as casas devem existir na família e estar vivas.
      const hSnaps = await Promise.all(grants.map((g) => tx.get(paths.household(familyId, g.householdId))));
      for (const s of hSnaps) {
        if (!s.exists || (s.data() as HouseholdDoc).deletedAt != null) throw domainError("HOUSEHOLD_NOT_FOUND");
      }

      const ref = paths.invitation(code);
      if ((await tx.get(ref)).exists) return "collision" as const;

      rl.apply();
      tx.create(ref, {
        familyId,
        grants,
        createdBy: ctx.uid,
        status: "pending",
        expiresAt: Timestamp.fromMillis(expiresAtMs),
        purgeAt: Timestamp.fromMillis(expiresAtMs + INVITE_PURGE_AFTER_MS), // TTL do Firestore
        createdAt: FieldValue.serverTimestamp(),
        schemaVersion: SCHEMA_VERSION,
      });
      return "ok" as const;
    });

    if (outcome === "ok") {
      return {
        code,
        link: `${INVITE_LINK_BASE}/${code}`,
        expiresAt: new Date(expiresAtMs).toISOString(),
      };
    }
  }
  throw new Error("colisões repetidas ao gerar código de convite");
});

/** §2.5 — revoga convite pendente. Só o owner criador (senão INVITE_NOT_FOUND, sem vazar existência). */
export const revokeInvitation = defineCallable("revokeInvitation", async (ctx, input) => {
  const data = asObject(input);
  const code = parseCode(data);
  if (code === null) throw domainError("INVITE_NOT_FOUND");

  await db().runTransaction(async (tx) => {
    const ref = paths.invitation(code);
    const snap = await tx.get(ref);
    if (!snap.exists) throw domainError("INVITE_NOT_FOUND");
    const inv = snap.data() as InvitationDoc;
    if (inv.createdBy !== ctx.uid) throw domainError("INVITE_NOT_FOUND");
    const famSnap = await tx.get(paths.family(inv.familyId));
    if (!famSnap.exists || (famSnap.data() as FamilyDoc).ownerId !== ctx.uid) throw domainError("INVITE_NOT_FOUND");
    ctx.familyId = inv.familyId;
    if (inv.status === "revoked") return; // idempotente
    if (inv.status !== "pending") throw domainError("INVITE_NOT_FOUND");
    tx.update(ref, { status: "revoked", revokedAt: FieldValue.serverTimestamp() });
  });
  return {};
});

type AcceptOutcome = { kind: "ok"; familyId: string; householdIds: string[] } | { kind: "expired" };

/** §2.6 — aceita convite. Transação única; rate limit em transação à parte (conta também as falhas). */
export const acceptInvitation = defineCallable("acceptInvitation", async (ctx, input) => {
  const data = asObject(input);
  const code = parseCode(data);
  const uid = ctx.uid;

  // Rate limit 10/h por uid, contando TODA tentativa (inclusive inválidas) para frear sondagem.
  // Fica fora da transação principal porque um erro lá desfaria o incremento.
  await db().runTransaction(async (tx) => {
    const rl = await prepareRateLimit(tx, uid, "acceptInvitation", 10, HOUR_MS);
    rl.apply();
  });

  const outcome = await db().runTransaction(async (tx): Promise<AcceptOutcome> => {
    const userSnap = await tx.get(paths.user(uid));
    if (!userSnap.exists || !userSnap.get("freeFamilyId")) throw domainError("BOOTSTRAP_REQUIRED");
    if (code === null) throw domainError("INVITE_NOT_FOUND");

    const invRef = paths.invitation(code);
    const invSnap = await tx.get(invRef);
    if (!invSnap.exists) throw domainError("INVITE_NOT_FOUND");
    const inv = invSnap.data() as InvitationDoc;
    const familyId = inv.familyId;

    const famRef = paths.family(familyId);
    const memRef = paths.member(familyId, uid);
    const [famSnap, memSnap] = await Promise.all([tx.get(famRef), tx.get(memRef)]);
    const member = memSnap.exists ? (memSnap.data() as MemberDoc) : undefined;

    // Repetição pelo mesmo uid (retry de rede): sucesso sem duplicar efeitos.
    if (inv.status === "accepted" && inv.acceptedBy === uid && member?.status === "active") {
      return { kind: "ok", familyId, householdIds: inv.grants.map((g) => g.householdId) };
    }
    if (inv.status !== "pending") throw domainError("INVITE_NOT_FOUND"); // usado/revogado/expirado = igual a inexistente
    if (inv.expiresAt.toMillis() <= Date.now()) {
      tx.update(invRef, { status: "expired" });
      return { kind: "expired" }; // lançar aqui desfaria o update
    }
    if (!famSnap.exists) throw domainError("INVITE_NOT_FOUND");
    const family = famSnap.data() as FamilyDoc;
    requireActive(family);
    if (member?.status === "active") throw domainError("ALREADY_MEMBER");
    const limits = await loadLimits(tx, familyId, family);
    if (!canAddMember(limits, family.memberCount)) throw domainError("PLAN_LIMIT_MEMBERS");

    // Casas excluídas desde a criação do convite são ignoradas (restritivo: sem acesso).
    const hSnaps = await Promise.all(inv.grants.map((g) => tx.get(paths.household(familyId, g.householdId))));
    const live = inv.grants.filter((_, i) => hSnaps[i].exists && (hSnaps[i].data() as HouseholdDoc).deletedAt == null);

    // ---- escritas ----
    const now = FieldValue.serverTimestamp();
    const displayName =
      (userSnap.get("displayName") as string | undefined) || (ctx.token.name as string | undefined) || "";
    const photoUrl = (userSnap.get("photoUrl") as string | null | undefined) ?? null;
    tx.set(memRef, {
      role: "member",
      status: "active",
      displayName,
      photoUrl,
      joinedAt: now,
      invitedBy: inv.createdBy,
      createdAt: member ? (memSnap.get("createdAt") ?? now) : now,
      updatedAt: now,
      schemaVersion: SCHEMA_VERSION,
    });
    tx.set(paths.membership(uid, familyId), {
      familyName: family.name,
      role: "member",
      familyStatus: family.status,
      plan: family.plan,
      joinedAt: now,
      updatedAt: now,
    });
    tx.update(famRef, { memberCount: FieldValue.increment(1), updatedAt: now });
    for (const g of live) {
      tx.update(
        paths.household(familyId, g.householdId),
        new FieldPath("access", uid),
        g.role,
        "accessUids",
        FieldValue.arrayUnion(uid),
        "updatedAt",
        now,
      );
      writeActivity(tx, familyId, g.householdId, {
        type: "member_joined",
        actorId: uid,
        actorName: displayName,
        targetType: "member",
        targetId: uid,
        targetTitle: displayName,
      });
    }
    tx.update(invRef, { status: "accepted", acceptedBy: uid, acceptedAt: now });
    return { kind: "ok", familyId, householdIds: live.map((g) => g.householdId) };
  });

  if (outcome.kind === "expired") throw domainError("INVITE_EXPIRED");
  ctx.familyId = outcome.familyId;
  return { familyId: outcome.familyId, householdIds: outcome.householdIds };
});

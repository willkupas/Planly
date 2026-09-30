import { FieldPath, FieldValue, Timestamp } from "firebase-admin/firestore";
import { domainError, invalidArgument } from "../domain/errors";
import { HOUSEHOLD_RETENTION_DAYS, HouseholdDoc, HouseholdRole, SCHEMA_VERSION } from "../domain/model";
import { canAddHousehold } from "../domain/plans";
import { writeActivity } from "../lib/activity";
import { loadFamilyContext, loadLimits, requireActive, requireOwner } from "../lib/authz";
import { defineCallable } from "../lib/callable";
import { db, paths } from "../lib/db";
import { asObject, reqId, reqString } from "../lib/validate";

const DAY_MS = 24 * 60 * 60 * 1000;

/** §2.2 — owner cria casa; limite via entitlement (null = ilimitado). */
export const createHousehold = defineCallable("createHousehold", async (ctx, input) => {
  const data = asObject(input);
  const familyId = reqId(data, "familyId");
  const name = reqString(data, "name", 1, 100);
  ctx.familyId = familyId;

  const householdId = await db().runTransaction(async (tx) => {
    const c = await loadFamilyContext(tx, familyId, ctx.uid);
    requireOwner(c);
    requireActive(c.family);
    const limits = await loadLimits(tx, familyId, c.family);
    if (!canAddHousehold(limits, c.family.householdCount)) throw domainError("PLAN_LIMIT_HOUSEHOLDS");

    const ref = paths.households(familyId).doc();
    const now = FieldValue.serverTimestamp();
    tx.set(ref, {
      name,
      access: {},
      accessUids: [],
      createdBy: ctx.uid,
      deletedAt: null,
      createdAt: now,
      updatedAt: now,
      schemaVersion: SCHEMA_VERSION,
    });
    tx.update(c.ref, { householdCount: FieldValue.increment(1), updatedAt: now });
    writeActivity(tx, familyId, ref.id, {
      type: "household_created",
      actorId: ctx.uid,
      actorName: c.member?.displayName ?? "",
      targetType: "household",
      targetId: ref.id,
      targetTitle: name,
    });
    return ref.id;
  });

  ctx.householdId = householdId;
  return { householdId };
});

/**
 * §2.3 — soft delete. Copia `access` para `deletedAccess` e zera access/accessUids.
 * Idempotente: casa já excluída devolve sucesso sem efeito.
 */
export const deleteHousehold = defineCallable("deleteHousehold", async (ctx, input) => {
  const data = asObject(input);
  const familyId = reqId(data, "familyId");
  const householdId = reqId(data, "householdId");
  ctx.familyId = familyId;
  ctx.householdId = householdId;

  await db().runTransaction(async (tx) => {
    const c = await loadFamilyContext(tx, familyId, ctx.uid);
    requireOwner(c);
    requireActive(c.family);
    const hRef = paths.household(familyId, householdId);
    const hSnap = await tx.get(hRef);
    if (!hSnap.exists) throw domainError("HOUSEHOLD_NOT_FOUND");
    const h = hSnap.data() as HouseholdDoc;
    if (h.deletedAt != null) return; // já excluída
    if (c.family.householdCount <= 1) throw domainError("LAST_HOUSEHOLD");

    const now = FieldValue.serverTimestamp();
    tx.update(hRef, {
      deletedAt: now,
      deletedAccess: h.access ?? {},
      access: {},
      accessUids: [],
      updatedAt: now,
    });
    tx.update(c.ref, { householdCount: FieldValue.increment(-1), updatedAt: now });
  });
  return {};
});

/**
 * §2.3 — restaura dentro de 30 dias; revalida maxHouseholds e recompõe o acesso.
 * Idempotente: casa não excluída devolve sucesso.
 */
export const restoreHousehold = defineCallable("restoreHousehold", async (ctx, input) => {
  const data = asObject(input);
  const familyId = reqId(data, "familyId");
  const householdId = reqId(data, "householdId");
  ctx.familyId = familyId;
  ctx.householdId = householdId;

  await db().runTransaction(async (tx) => {
    const c = await loadFamilyContext(tx, familyId, ctx.uid);
    requireOwner(c);
    requireActive(c.family);
    const hRef = paths.household(familyId, householdId);
    const hSnap = await tx.get(hRef);
    if (!hSnap.exists) throw domainError("HOUSEHOLD_NOT_FOUND");
    const h = hSnap.data() as HouseholdDoc;
    if (h.deletedAt == null) return; // já ativa
    const limit = h.deletedAt.toMillis() + HOUSEHOLD_RETENTION_DAYS * DAY_MS;
    if (limit <= Timestamp.now().toMillis()) throw domainError("HOUSEHOLD_NOT_FOUND"); // janela vencida
    const limits = await loadLimits(tx, familyId, c.family);
    if (!canAddHousehold(limits, c.family.householdCount)) throw domainError("PLAN_LIMIT_HOUSEHOLDS");

    const access = h.deletedAccess ?? {};
    const now = FieldValue.serverTimestamp();
    tx.update(hRef, {
      deletedAt: null,
      access,
      accessUids: Object.keys(access),
      deletedAccess: FieldValue.delete(),
      updatedAt: now,
    });
    tx.update(c.ref, { householdCount: FieldValue.increment(1), updatedAt: now });
  });
  return {};
});

/**
 * §2.4 — owner concede/altera/revoga acesso de um membro a uma casa.
 * `access[uid]` e `accessUids` só mudam por FieldPath + arrayUnion/arrayRemove (nunca set do array).
 */
export const setHouseholdAccess = defineCallable("setHouseholdAccess", async (ctx, input) => {
  const data = asObject(input);
  const familyId = reqId(data, "familyId");
  const householdId = reqId(data, "householdId");
  const targetUid = reqId(data, "targetUid");
  const role = data.role;
  if (role !== null && role !== "admin" && role !== "member") throw invalidArgument("role");
  ctx.familyId = familyId;
  ctx.householdId = householdId;

  await db().runTransaction(async (tx) => {
    const c = await loadFamilyContext(tx, familyId, ctx.uid);
    requireOwner(c);
    requireActive(c.family);
    if (targetUid === c.family.ownerId) throw invalidArgument("targetUid"); // owner é implícito
    const [tSnap, hSnap] = await Promise.all([
      tx.get(paths.member(familyId, targetUid)),
      tx.get(paths.household(familyId, householdId)),
    ]);
    if (!tSnap.exists || tSnap.get("status") !== "active") throw domainError("MEMBER_NOT_FOUND");
    if (!hSnap.exists || hSnap.get("deletedAt") != null) throw domainError("HOUSEHOLD_NOT_FOUND");

    const now = FieldValue.serverTimestamp();
    const field = new FieldPath("access", targetUid);
    if (role === null) {
      tx.update(hSnap.ref, field, FieldValue.delete(), "accessUids", FieldValue.arrayRemove(targetUid), "updatedAt", now);
    } else {
      tx.update(hSnap.ref, field, role as HouseholdRole, "accessUids", FieldValue.arrayUnion(targetUid), "updatedAt", now);
    }
  });
  return {};
});

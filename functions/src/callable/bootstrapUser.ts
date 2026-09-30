import { FieldValue } from "firebase-admin/firestore";
import { invalidArgument } from "../domain/errors";
import { SCHEMA_VERSION } from "../domain/model";
import { entitlementFor } from "../domain/plans";
import { writeActivity } from "../lib/activity";
import { defineCallable } from "../lib/callable";
import { db, paths } from "../lib/db";
import { prepareRateLimit } from "../lib/rateLimit";
import { asOptionalObject, isValidTimeZone, optString } from "../lib/validate";

const DEFAULT_FAMILY_NAME = "Minha família";
const DEFAULT_HOUSEHOLD_NAME = "Minha casa";
const DEFAULT_LOCALE = "pt-BR";
const DEFAULT_TIMEZONE = "America/Sao_Paulo";
const HOUR_MS = 60 * 60 * 1000;

/**
 * §2.1 — cria (uma única vez) users/{uid} + Family Free + primeira casa. Idempotente:
 * se `users.freeFamilyId` já existe devolve os ids existentes. Rate limit 5/h.
 */
export const bootstrapUser = defineCallable("bootstrapUser", async (ctx, input) => {
  const data = asOptionalObject(input);
  const uid = ctx.uid;
  const tokenName = typeof ctx.token.name === "string" ? ctx.token.name.trim().slice(0, 100) : "";
  const displayName = optString(data, "displayName", 1, 100) ?? tokenName;
  const locale = optString(data, "locale", 1, 10) ?? DEFAULT_LOCALE;
  const timezone = optString(data, "timezone", 1, 64) ?? DEFAULT_TIMEZONE;
  if (!isValidTimeZone(timezone)) throw invalidArgument("timezone");
  const householdName = optString(data, "householdName", 1, 100) ?? DEFAULT_HOUSEHOLD_NAME;
  const email = ctx.token.email ?? null;
  const photoUrl = typeof ctx.token.picture === "string" ? ctx.token.picture.slice(0, 2048) : null;

  const result = await db().runTransaction(async (tx) => {
    const rl = await prepareRateLimit(tx, uid, "bootstrapUser", 5, HOUR_MS);
    const userRef = paths.user(uid);
    const userSnap = await tx.get(userRef);
    const existingFamilyId = userSnap.get("freeFamilyId") as string | undefined;

    if (existingFamilyId) {
      const famSnap = await tx.get(paths.family(existingFamilyId));
      if (famSnap.exists) {
        // Sem orderBy composto (evita índice): ordena/filtra em memória.
        const hh = await tx.get(paths.households(existingFamilyId).orderBy("createdAt").limit(50));
        const live = hh.docs.find((d) => d.get("deletedAt") == null);
        rl.apply();
        tx.update(userRef, { updatedAt: FieldValue.serverTimestamp() });
        return { familyId: existingFamilyId, householdId: live?.id ?? null };
      }
    }

    // --- Criação (primeiro acesso) ---
    const familyRef = paths.families().doc();
    const householdRef = paths.household(familyRef.id, paths.households(familyRef.id).doc().id);
    const now = FieldValue.serverTimestamp();
    rl.apply();

    tx.set(
      userRef,
      {
        displayName,
        email,
        photoUrl,
        locale,
        timezone,
        freeFamilyId: familyRef.id,
        deletedAt: null,
        ...(userSnap.exists ? {} : { createdAt: now, schemaVersion: SCHEMA_VERSION }),
        updatedAt: now,
      },
      { merge: true },
    );
    tx.set(familyRef, {
      name: DEFAULT_FAMILY_NAME,
      ownerId: uid,
      status: "active",
      plan: "free",
      memberCount: 1,
      householdCount: 1,
      frozenAt: null,
      deleteAfter: null,
      pendingTransfer: null,
      deletedAt: null,
      createdAt: now,
      updatedAt: now,
      schemaVersion: SCHEMA_VERSION,
    });
    tx.set(paths.member(familyRef.id, uid), {
      role: "owner",
      status: "active",
      displayName,
      photoUrl,
      joinedAt: now,
      invitedBy: null,
      createdAt: now,
      updatedAt: now,
      schemaVersion: SCHEMA_VERSION,
    });
    tx.set(paths.membership(uid, familyRef.id), {
      familyName: DEFAULT_FAMILY_NAME,
      role: "owner",
      familyStatus: "active",
      plan: "free",
      joinedAt: now,
      updatedAt: now,
    });
    tx.set(paths.entitlement(familyRef.id), {
      ...entitlementFor("free"),
      source: "default",
      updatedAt: now,
    });
    tx.set(householdRef, {
      name: householdName,
      access: {},
      accessUids: [],
      createdBy: uid,
      deletedAt: null,
      createdAt: now,
      updatedAt: now,
      schemaVersion: SCHEMA_VERSION,
    });
    writeActivity(tx, familyRef.id, householdRef.id, {
      type: "household_created",
      actorId: uid,
      actorName: displayName,
      targetType: "household",
      targetId: householdRef.id,
      targetTitle: householdName,
    });
    return { familyId: familyRef.id, householdId: householdRef.id as string | null };
  });

  ctx.familyId = result.familyId;
  if (result.householdId) ctx.householdId = result.householdId;
  return result;
});

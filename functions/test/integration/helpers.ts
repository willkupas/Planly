import assert from "node:assert/strict";
import { randomUUID } from "node:crypto";
import { getApps, initializeApp } from "firebase-admin/app";
import { FieldValue, Firestore, Timestamp, getFirestore } from "firebase-admin/firestore";
import { PlanId, entitlementFor } from "../../src/domain/plans";

export const PROJECT = "demo-planly-functions";
const REGION = "southamerica-east1";
const FUNCTIONS = `http://127.0.0.1:5001/${PROJECT}/${REGION}`;
const AUTH = "http://127.0.0.1:9099";

// Admin SDK do teste fala com o emulador (FIRESTORE_EMULATOR_HOST vem do emulators:exec).
if (getApps().length === 0) initializeApp({ projectId: PROJECT });
export const adminDb: Firestore = getFirestore();

const b64 = (o: object) => Buffer.from(JSON.stringify(o)).toString("base64url");
/** JWT não assinado; só serve ao emulador (skipTokenVerification). */
const FAKE_APPCHECK = `${b64({ alg: "none", typ: "JWT" })}.${b64({ sub: "1:1:android:test", aud: [PROJECT] })}.x`;

export interface TestUser {
  uid: string;
  token: string;
  email: string;
}

/** Cria usuário no Auth Emulator (credenciais aleatórias, só existem no emulador). */
export async function createUser(): Promise<TestUser> {
  const email = `u-${randomUUID()}@test.invalid`;
  const res = await fetch(`${AUTH}/identitytoolkit.googleapis.com/v1/accounts:signUp?key=fake-key`, {
    method: "POST",
    headers: { "content-type": "application/json" },
    body: JSON.stringify({ email, password: randomUUID(), displayName: "Teste", returnSecureToken: true }),
  });
  assert.equal(res.status, 200);
  const j = (await res.json()) as { localId: string; idToken: string };
  return { uid: j.localId, token: j.idToken, email };
}

/** Como createUser, mas com e-mail verificado no token (como o login Google real). */
export async function createVerifiedUser(): Promise<TestUser> {
  const email = `v-${randomUUID()}@test.invalid`;
  const res = await fetch(`${AUTH}/identitytoolkit.googleapis.com/v1/accounts:signUp?key=fake-key`, {
    method: "POST",
    headers: { "content-type": "application/json" },
    body: JSON.stringify({ email, password: randomUUID(), displayName: "Teste", returnSecureToken: true }),
  });
  assert.equal(res.status, 200);
  const j = (await res.json()) as { localId: string; refreshToken: string };
  const upd = await fetch(`${AUTH}/identitytoolkit.googleapis.com/v1/accounts:update`, {
    method: "POST",
    headers: { "content-type": "application/json", authorization: "Bearer owner" },
    body: JSON.stringify({ localId: j.localId, emailVerified: true }),
  });
  assert.equal(upd.status, 200);
  const ref = await fetch(`${AUTH}/securetoken.googleapis.com/v1/token?key=fake-key`, {
    method: "POST",
    headers: { "content-type": "application/x-www-form-urlencoded" },
    body: `grant_type=refresh_token&refresh_token=${encodeURIComponent(j.refreshToken)}`,
  });
  assert.equal(ref.status, 200);
  const r = (await ref.json()) as { id_token: string };
  return { uid: j.localId, token: r.id_token, email };
}

export interface CallResult {
  status: number;
  ok: boolean;
  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  data?: Record<string, any>;
  code?: string; // ex.: FAILED_PRECONDITION
  reason?: string;
}

/** Chama uma callable via protocolo HTTP do emulador. */
export async function call(fn: string, data: unknown, user?: TestUser): Promise<CallResult> {
  const headers: Record<string, string> = {
    "content-type": "application/json",
    // O emulador NÃO ignora enforceAppCheck: exige o header (decodifica sem verificar).
    "x-firebase-appcheck": FAKE_APPCHECK,
  };
  if (user) headers.authorization = `Bearer ${user.token}`;
  const res = await fetch(`${FUNCTIONS}/${fn}`, {
    method: "POST",
    headers,
    body: JSON.stringify({ data: data === undefined ? null : data }),
  });
  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  const body = (await res.json()) as any;
  if (res.status === 200) return { status: 200, ok: true, data: body.result };
  return {
    status: res.status,
    ok: false,
    code: body?.error?.status,
    reason: body?.error?.details?.reason,
  };
}

export function assertOk(r: CallResult): Record<string, any> {
  assert.ok(r.ok, `esperava ok, veio ${r.code}/${r.reason}`);
  assert.equal(r.data?.ok, true);
  return r.data as Record<string, any>;
}

export function assertFails(r: CallResult, code: string, reason?: string): void {
  assert.equal(r.ok, false, "esperava erro");
  assert.equal(r.code, code);
  if (reason !== undefined) assert.equal(r.reason, reason);
}

export async function bootstrap(user: TestUser, data: Record<string, unknown> = {}) {
  const d = assertOk(await call("bootstrapUser", data, user));
  return { familyId: d.familyId as string, householdId: d.householdId as string };
}

/** Promove a família para um plano pago direto no Firestore (simula o billing futuro). */
export async function setPlan(familyId: string, plan: PlanId): Promise<void> {
  const ent = entitlementFor(plan);
  await adminDb.doc(`families/${familyId}`).update({ plan });
  await adminDb.doc(`families/${familyId}/billing/entitlement`).set({ ...ent, source: "subscription" });
}

export async function setStatus(familyId: string, status: "active" | "frozen" | "deleting"): Promise<void> {
  await adminDb.doc(`families/${familyId}`).update({ status });
}

/** Adiciona membro ativo (simula o aceite de convite, que é da T-015). */
export async function addMember(familyId: string, uid: string, displayName = "Membro"): Promise<void> {
  const now = Timestamp.now();
  await adminDb.doc(`families/${familyId}/members/${uid}`).set({
    role: "member",
    status: "active",
    displayName,
    photoUrl: null,
    joinedAt: now,
    createdAt: now,
    updatedAt: now,
    schemaVersion: 1,
  });
  await adminDb.doc(`users/${uid}/memberships/${familyId}`).set({
    familyName: "x",
    role: "member",
    familyStatus: "active",
    plan: "free",
    joinedAt: now,
    updatedAt: now,
  });
  await adminDb.doc(`families/${familyId}`).update({ memberCount: FieldValue.increment(1) });
}

export async function getDoc(path: string): Promise<Record<string, any> | undefined> {
  const s = await adminDb.doc(path).get();
  return s.exists ? (s.data() as Record<string, any>) : undefined;
}

/** Owner de família paga com `extraHouseholds` casas adicionais criadas via callable. */
export async function paidFamily(plan: PlanId = "family", extraHouseholds = 0) {
  const owner = await createUser();
  const { familyId, householdId } = await bootstrap(owner);
  await setPlan(familyId, plan);
  const householdIds = [householdId];
  for (let i = 0; i < extraHouseholds; i++) {
    const d = assertOk(await call("createHousehold", { familyId, name: `Casa ${i + 2}` }, owner));
    householdIds.push(d.householdId as string);
  }
  return { owner, familyId, householdIds };
}

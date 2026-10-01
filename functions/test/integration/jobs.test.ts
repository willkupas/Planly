import assert from "node:assert/strict";
import { describe, it } from "node:test";
import { Timestamp } from "firebase-admin/firestore";
import { DAY_MS } from "../../src/domain/lifecycle";
import { PROJECT, addMember, adminDb, createUser, getDoc, paidFamily } from "./helpers";

const URL = `http://127.0.0.1:5001/${PROJECT}/southamerica-east1/runScheduledJob`;
const ts = (ms: number) => Timestamp.fromMillis(ms);

/** Roda um job no emulador com o relogio simulado em `nowMs`. */
async function runJob(job: "lifecycle" | "purge" | "cleanup", nowMs: number): Promise<Record<string, number>> {
  const res = await fetch(URL, {
    method: "POST",
    headers: { "content-type": "application/json" },
    body: JSON.stringify({ job, nowMs }),
  });
  assert.equal(res.status, 200);
  const j = (await res.json()) as { ok: boolean; result: Record<string, number> };
  assert.equal(j.ok, true);
  assert.equal(j.result.errors, 0);
  return j.result;
}

async function setSub(familyId: string, state: string, expiresAtMs: number) {
  await adminDb.doc(`families/${familyId}/billing/subscription`).set({
    provider: "google_play",
    state,
    autoRenewing: state === "active",
    expiresAt: ts(expiresAtMs),
    purchasedBy: "x",
  });
}

describe("lifecycleJob", () => {
  it("assinatura expirada, so owner e 1 casa -> downgrade Free (sem frozen)", async () => {
    const { owner, familyId } = await paidFamily("family");
    const now = Date.now();
    await setSub(familyId, "expired", now - DAY_MS);
    await adminDb.doc(`users/${owner.uid}/memberships/${familyId}`).set({ plan: "family", familyStatus: "active" }, { merge: true });
    await runJob("lifecycle", now);
    const f = await getDoc(`families/${familyId}`);
    assert.equal(f?.status, "active");
    assert.equal(f?.plan, "free");
    assert.equal((await getDoc(`families/${familyId}/billing/entitlement`))?.maxMembers, 1);
    assert.equal(await getDoc(`families/${familyId}/billing/subscription`), undefined);
    assert.equal((await getDoc(`users/${owner.uid}/memberships/${familyId}`))?.plan, "free");
    // idempotente: a familia agora e Free e nao e mais processada
    await runJob("lifecycle", now);
    assert.equal((await getDoc(`families/${familyId}`))?.plan, "free");
  });

  it("expirada com membro -> frozen (+90d), aviso frozen_d0, espelhos; D-60 sem repeticao; deleteAfter -> deleting; purge apaga tudo", async () => {
    const { owner, familyId, householdIds } = await paidFamily("family");
    const m = await createUser();
    await addMember(familyId, m.uid, "Bia");
    const now = Date.now();
    await setSub(familyId, "expired", now - DAY_MS);
    await adminDb.doc(`families/${familyId}/households/${householdIds[0]}/tasks/t1`).set({ title: "x", createdBy: owner.uid });

    const r1 = await runJob("lifecycle", now);
    assert.ok(r1.frozen >= 1);
    const f = await getDoc(`families/${familyId}`);
    assert.equal(f?.status, "frozen");
    assert.equal(f?.frozenAt.toMillis(), now);
    assert.equal(f?.deleteAfter.toMillis(), now + 90 * DAY_MS);
    assert.ok(f?.notifiedAt.frozen_d0);
    assert.equal((await getDoc(`users/${m.uid}/memberships/${familyId}`))?.familyStatus, "frozen");

    // D-60 (30 dias apos congelar): grava a flag; repetir nao muda.
    const d60 = now + 30 * DAY_MS;
    await runJob("lifecycle", d60);
    const flag = (await getDoc(`families/${familyId}`))?.notifiedAt.delete_d60.toMillis();
    assert.equal(flag, d60);
    await runJob("lifecycle", d60 + DAY_MS);
    assert.equal((await getDoc(`families/${familyId}`))?.notifiedAt.delete_d60.toMillis(), flag);

    // deleteAfter atingido -> deleting; purge faz a cascata.
    const del = now + 90 * DAY_MS;
    await runJob("lifecycle", del);
    assert.equal((await getDoc(`families/${familyId}`))?.status, "deleting");
    await runJob("purge", del);
    assert.equal(await getDoc(`families/${familyId}`), undefined);
    assert.equal(await getDoc(`families/${familyId}/members/${owner.uid}`), undefined);
    assert.equal(await getDoc(`families/${familyId}/households/${householdIds[0]}/tasks/t1`), undefined);
    assert.equal(await getDoc(`users/${m.uid}/memberships/${familyId}`), undefined);
    // idempotente / retomavel: nova rodada sem erro
    await runJob("purge", del);
  });

  it("frozen com assinatura vigente nunca vira deleting", async () => {
    const { familyId } = await paidFamily("family");
    const now = Date.now();
    await adminDb.doc(`families/${familyId}`).update({ status: "frozen", frozenAt: ts(now - 91 * DAY_MS), deleteAfter: ts(now - DAY_MS) });
    await setSub(familyId, "active", now + 10 * DAY_MS);
    await runJob("lifecycle", now);
    assert.equal((await getDoc(`families/${familyId}`))?.status, "frozen");
  });

  it("regularizeBy vencido: acima do limite -> frozen; dentro do limite -> so limpa", async () => {
    const over = await paidFamily("family");
    for (let i = 0; i < 4; i++) await addMember(over.familyId, (await createUser()).uid); // 5 membros > 4
    const ok = await paidFamily("family");
    const now = Date.now();
    for (const id of [over.familyId, ok.familyId]) {
      await adminDb.doc(`families/${id}`).update({ regularizeBy: ts(now - DAY_MS) });
      await setSub(id, "active", now + 10 * DAY_MS);
    }
    await runJob("lifecycle", now);
    assert.equal((await getDoc(`families/${over.familyId}`))?.status, "frozen");
    const f = await getDoc(`families/${ok.familyId}`);
    assert.equal(f?.status, "active");
    assert.equal(f?.regularizeBy, undefined);
  });

  it("aviso D-7 de expiracao: grava a flag uma unica vez", async () => {
    const { familyId } = await paidFamily("family");
    const now = Date.now();
    await setSub(familyId, "canceled", now + 5 * DAY_MS);
    await runJob("lifecycle", now);
    const first = (await getDoc(`families/${familyId}`))?.notifiedAt.expiry_d7.toMillis();
    assert.equal(first, now);
    await runJob("lifecycle", now + DAY_MS);
    assert.equal((await getDoc(`families/${familyId}`))?.notifiedAt.expiry_d7.toMillis(), first);
    assert.equal((await getDoc(`families/${familyId}`))?.status, "active");
  });

  it("transferencia pendente expirada e limpa; vigente permanece", async () => {
    const a = await paidFamily("family");
    const b = await paidFamily("family");
    const now = Date.now();
    await adminDb.doc(`families/${a.familyId}`).update({ pendingTransfer: { toUid: "u", createdAt: ts(now - 8 * DAY_MS), expiresAt: ts(now - DAY_MS) } });
    await adminDb.doc(`families/${b.familyId}`).update({ pendingTransfer: { toUid: "u", createdAt: ts(now), expiresAt: ts(now + DAY_MS) } });
    await runJob("lifecycle", now);
    assert.equal((await getDoc(`families/${a.familyId}`))?.pendingTransfer, null);
    assert.ok((await getDoc(`families/${b.familyId}`))?.pendingTransfer);
  });
});

describe("purgeJob", () => {
  it("casa soft-deleted ha 30d+ some com o conteudo; recente e itens antigos soltos tratados", async () => {
    const { owner, familyId, householdIds } = await paidFamily("family", 1);
    const [live, old] = householdIds;
    const now = Date.now();
    const base = (id: string) => `families/${familyId}/households/${id}`;
    await adminDb.doc(base(old)).update({ deletedAt: ts(now - 31 * DAY_MS) });
    await adminDb.doc(`${base(old)}/tasks/t1`).set({ title: "x", createdBy: owner.uid });
    await adminDb.doc(`${base(old)}/lists/l1/items/i1`).set({ name: "x", createdBy: owner.uid });
    await adminDb.doc(`${base(live)}/tasks/old`).set({ title: "x", createdBy: owner.uid, deletedAt: ts(now - 31 * DAY_MS) });
    await adminDb.doc(`${base(live)}/tasks/recent`).set({ title: "x", createdBy: owner.uid, deletedAt: ts(now - 5 * DAY_MS) });
    await adminDb.doc(`${base(live)}/tasks/alive`).set({ title: "x", createdBy: owner.uid, deletedAt: null });
    await runJob("purge", now);
    assert.equal(await getDoc(base(old)), undefined);
    assert.equal(await getDoc(`${base(old)}/tasks/t1`), undefined);
    assert.equal(await getDoc(`${base(old)}/lists/l1/items/i1`), undefined);
    assert.equal(await getDoc(`${base(live)}/tasks/old`), undefined);
    assert.ok(await getDoc(`${base(live)}/tasks/recent`));
    assert.ok(await getDoc(`${base(live)}/tasks/alive`));
    assert.ok(await getDoc(base(live)));
  });
});

describe("cleanupJob", () => {
  it("convite pending vencido -> expired; rate limit e device antigos apagados", async () => {
    const owner = await createUser();
    const now = Date.now();
    const code = `ZZ${Math.floor(Math.random() * 1e8)}`;
    const keep = `YY${Math.floor(Math.random() * 1e8)}`;
    await adminDb.doc(`invitations/${code}`).set({ familyId: "f", status: "pending", expiresAt: ts(now - 1000), purgeAt: ts(now + 6 * DAY_MS) });
    await adminDb.doc(`invitations/${keep}`).set({ familyId: "f", status: "pending", expiresAt: ts(now + DAY_MS), purgeAt: ts(now + 8 * DAY_MS) });
    await adminDb.doc(`_rateLimits/${owner.uid}_old`).set({ count: 1, windowStart: ts(now - 2 * DAY_MS) });
    await adminDb.doc(`_rateLimits/${owner.uid}_new`).set({ count: 1, windowStart: ts(now - 1000) });
    await adminDb.doc(`users/${owner.uid}/devices/old`).set({ fcmToken: "t", lastSeenAt: ts(now - 91 * DAY_MS) });
    await adminDb.doc(`users/${owner.uid}/devices/new`).set({ fcmToken: "t", lastSeenAt: ts(now - DAY_MS) });
    await runJob("cleanup", now);
    assert.equal((await getDoc(`invitations/${code}`))?.status, "expired");
    assert.equal((await getDoc(`invitations/${keep}`))?.status, "pending");
    assert.equal(await getDoc(`_rateLimits/${owner.uid}_old`), undefined);
    assert.ok(await getDoc(`_rateLimits/${owner.uid}_new`));
    assert.equal(await getDoc(`users/${owner.uid}/devices/old`), undefined);
    assert.ok(await getDoc(`users/${owner.uid}/devices/new`));
  });
});

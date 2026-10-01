import assert from "node:assert/strict";
import { randomUUID } from "node:crypto";
import { describe, it } from "node:test";
import { Timestamp } from "firebase-admin/firestore";
import { addMember, adminDb, assertOk, call, createUser, getDoc, paidFamily } from "./helpers";

const sleep = (ms: number) => new Promise((r) => setTimeout(r, ms));

async function outboxFor(token: string) {
  const s = await adminDb.collection("_pushOutbox").where("token", "==", token).get();
  return s.docs.map((d) => d.data());
}

/** Espera até haver `n` mensagens para o token (ou estoura em ~15s). */
async function waitFor(token: string, n = 1) {
  for (let i = 0; i < 75; i++) {
    const m = await outboxFor(token);
    if (m.length >= n) return m;
    await sleep(200);
  }
  return outboxFor(token);
}

async function addDevice(uid: string, token: string) {
  const now = Timestamp.now();
  const id = `dev-${randomUUID().slice(0, 8)}`;
  await adminDb.doc(`users/${uid}/devices/${id}`).set({
    fcmToken: token,
    platform: "android",
    lastSeenAt: now,
    createdAt: now,
  });
  return id;
}

async function setup() {
  const f = await paidFamily("family");
  const householdId = f.householdIds[0];
  const a = await createUser();
  const b = await createUser();
  await addMember(f.familyId, a.uid, "Ana");
  await addMember(f.familyId, b.uid, "Beto");
  // A tem acesso à casa; B é da família mas NÃO da casa.
  assertOk(await call("setHouseholdAccess", { familyId: f.familyId, householdId, targetUid: a.uid, role: "member" }, f.owner));
  const tok = { owner: `tok-${randomUUID()}`, a: `tok-${randomUUID()}`, b: `tok-${randomUUID()}` };
  await addDevice(f.owner.uid, tok.owner);
  await addDevice(a.uid, tok.a);
  await addDevice(b.uid, tok.b);
  const tasks = `families/${f.familyId}/households/${householdId}/tasks`;
  return { ...f, householdId, a, b, tok, tasks };
}

const baseTask = (createdBy: string, assignedTo: string | null) => ({
  title: "Segredo: nao pode vazar",
  description: "conteudo sensivel",
  createdBy,
  assignedTo,
  status: "pending",
  schedule: null,
  recurrence: null,
  notification: { enabled: false, offsetMinutes: 0 },
  completedAt: null,
  completedBy: null,
  deletedAt: null,
  createdAt: Timestamp.now(),
  updatedAt: Timestamp.now(),
  schemaVersion: 1,
});

function noSensitive(msgs: Record<string, any>[]) {
  for (const m of msgs) {
    assert.deepEqual(Object.keys(m.data).sort(), ["familyId", "householdId", "targetId", "type"]);
    assert.equal(JSON.stringify(m).includes("Segredo"), false);
    assert.equal(JSON.stringify(m).includes("sensivel"), false);
  }
}

describe("push de eventos compartilhados", () => {
  it("tarefa criada: avisa quem tem acesso (owner), exceto autor e quem não tem acesso à casa", async () => {
    const s = await setup();
    const ref = adminDb.collection(s.tasks).doc();
    await ref.set(baseTask(s.a.uid, s.a.uid));
    const got = await waitFor(s.tok.owner);
    assert.equal(got.length, 1);
    assert.equal(got[0].data.type, "task_created");
    assert.equal(got[0].data.familyId, s.familyId);
    assert.equal(got[0].data.householdId, s.householdId);
    assert.equal(got[0].data.targetId, ref.id);
    noSensitive(got);
    await sleep(1500);
    assert.equal((await outboxFor(s.tok.a)).length, 0, "autor não recebe");
    assert.equal((await outboxFor(s.tok.b)).length, 0, "sem acesso à casa não recebe");
  });

  it("tarefa atribuída a outra pessoa: o responsável recebe task_assigned (uma vez) e os demais task_created", async () => {
    const s = await setup();
    const ref = adminDb.collection(s.tasks).doc();
    await ref.set(baseTask(s.owner.uid, s.a.uid));
    const a = await waitFor(s.tok.a);
    assert.deepEqual(a.map((m) => m.data.type), ["task_assigned"]);
    noSensitive(a);
    await sleep(1500);
    assert.equal((await outboxFor(s.tok.a)).length, 1);
    assert.equal((await outboxFor(s.tok.owner)).length, 0, "autor não recebe");
  });

  it("reatribuição e conclusão disparam push; autor da conclusão não recebe", async () => {
    const s = await setup();
    const ref = adminDb.collection(s.tasks).doc();
    await ref.set(baseTask(s.a.uid, null));
    await waitFor(s.tok.owner); // task_created
    await ref.update({ assignedTo: s.owner.uid, updatedAt: Timestamp.now() });
    const own = await waitFor(s.tok.owner, 2);
    assert.deepEqual(own.map((m) => m.data.type).sort(), ["task_assigned", "task_created"]);

    await ref.update({ status: "done", completedBy: s.owner.uid, completedAt: Timestamp.now(), updatedAt: Timestamp.now() });
    const a = await waitFor(s.tok.a);
    assert.deepEqual(a.map((m) => m.data.type), ["task_completed"]);
    assert.equal(a[0].data.targetId, ref.id);
    await sleep(1500);
    assert.equal((await outboxFor(s.tok.owner)).length, 2, "quem concluiu não recebe");
  });

  it("item adicionado: targetId é a lista; autor excluído", async () => {
    const s = await setup();
    const list = adminDb.collection(`families/${s.familyId}/households/${s.householdId}/lists`).doc();
    await list.set({ name: "Mercado", type: "shopping", createdBy: s.owner.uid, deletedAt: null, createdAt: Timestamp.now(), updatedAt: Timestamp.now() });
    await list.collection("items").doc().set({
      name: "Segredo: leite",
      completed: false,
      createdBy: s.owner.uid,
      order: 1,
      deletedAt: null,
      createdAt: Timestamp.now(),
      updatedAt: Timestamp.now(),
    });
    const a = await waitFor(s.tok.a);
    assert.equal(a.length, 1);
    assert.equal(a[0].data.type, "list_item_added");
    assert.equal(a[0].data.targetId, list.id);
    noSensitive(a);
    await sleep(1000);
    assert.equal((await outboxFor(s.tok.owner)).length, 0);
  });

  it("remove o device cujo token o FCM recusa; mantém os válidos", async () => {
    const s = await setup();
    const bad = await addDevice(s.owner.uid, `invalid-${randomUUID()}`);
    await adminDb.collection(s.tasks).doc().set(baseTask(s.a.uid, s.a.uid));
    await waitFor(s.tok.owner);
    for (let i = 0; i < 50 && (await getDoc(`users/${s.owner.uid}/devices/${bad}`)); i++) await sleep(200);
    assert.equal(await getDoc(`users/${s.owner.uid}/devices/${bad}`), undefined);
    assert.equal((await adminDb.collection(`users/${s.owner.uid}/devices`).get()).size, 1);
  });

  it("tarefa excluída (soft delete) na criação não notifica", async () => {
    const s = await setup();
    const t = { ...baseTask(s.a.uid, s.a.uid), deletedAt: Timestamp.now() };
    await adminDb.collection(s.tasks).doc().set(t);
    await sleep(2500);
    assert.equal((await outboxFor(s.tok.owner)).length, 0);
  });
});


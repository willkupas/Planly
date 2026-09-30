import assert from "node:assert/strict";
import { describe, it } from "node:test";
import { addMember, adminDb, assertFails, assertOk, call, createUser, getDoc, paidFamily, setStatus } from "./helpers";

async function setup() {
  const f = await paidFamily("family", 1); // 2 casas
  const [h1, h2] = f.householdIds;
  const m = await createUser();
  await addMember(f.familyId, m.uid, "Bia");
  assertOk(await call("setHouseholdAccess", { familyId: f.familyId, householdId: h1, targetUid: m.uid, role: "member" }, f.owner));
  assertOk(await call("setHouseholdAccess", { familyId: f.familyId, householdId: h2, targetUid: m.uid, role: "admin" }, f.owner));
  return { ...f, m, h1, h2 };
}

async function assertRemoved(familyId: string, uid: string, householdIds: string[], memberCount: number) {
  const mem = await getDoc(`families/${familyId}/members/${uid}`);
  assert.equal(mem?.status, "removed");
  assert.equal(await getDoc(`users/${uid}/memberships/${familyId}`), undefined);
  assert.equal((await getDoc(`families/${familyId}`))?.memberCount, memberCount);
  for (const h of householdIds) {
    const doc = await getDoc(`families/${familyId}/households/${h}`);
    assert.equal(uid in (doc?.access ?? {}), false);
    assert.equal((doc?.accessUids ?? []).includes(uid), false);
  }
}

describe("removeMember", () => {
  it("owner remove: sai de todas as casas, espelho apagado, contador--, activity member_left", async () => {
    const { owner, familyId, m, h1, h2 } = await setup();
    assert.equal((await getDoc(`families/${familyId}`))?.memberCount, 2);
    assertOk(await call("removeMember", { familyId, targetUid: m.uid }, owner));
    await assertRemoved(familyId, m.uid, [h1, h2], 1);
    for (const h of [h1, h2]) {
      const act = await adminDb.collection(`families/${familyId}/households/${h}/activity`).where("type", "==", "member_left").get();
      assert.equal(act.size, 1);
      assert.equal(act.docs[0].get("targetId"), m.uid);
      assert.equal(JSON.stringify(act.docs[0].data()).includes("@"), false);
    }
  });

  it("remove também de casas excluídas (deletedAccess) para não voltar na restauração", async () => {
    const { owner, familyId, m, h2 } = await setup();
    assertOk(await call("deleteHousehold", { familyId, householdId: h2 }, owner));
    assertOk(await call("removeMember", { familyId, targetUid: m.uid }, owner));
    assert.deepEqual((await getDoc(`families/${familyId}/households/${h2}`))?.deletedAccess, {});
    assertOk(await call("restoreHousehold", { familyId, householdId: h2 }, owner));
    assert.deepEqual((await getDoc(`families/${familyId}/households/${h2}`))?.accessUids, []);
  });

  it("idempotente: remover quem já saiu é sucesso e não decrementa de novo", async () => {
    const { owner, familyId, m } = await setup();
    assertOk(await call("removeMember", { familyId, targetUid: m.uid }, owner));
    assertOk(await call("removeMember", { familyId, targetUid: m.uid }, owner));
    assert.equal((await getDoc(`families/${familyId}`))?.memberCount, 1);
  });

  it("concorrência: remoções simultâneas do mesmo membro decrementam uma vez", async () => {
    const { owner, familyId, m } = await setup();
    const rs = await Promise.all([1, 2, 3].map(() => call("removeMember", { familyId, targetUid: m.uid }, owner)));
    rs.forEach(assertOk);
    assert.equal((await getDoc(`families/${familyId}`))?.memberCount, 1);
  });

  it("permitido com família frozen", async () => {
    const { owner, familyId, m, h1, h2 } = await setup();
    await setStatus(familyId, "frozen");
    assertOk(await call("removeMember", { familyId, targetUid: m.uid }, owner));
    await assertRemoved(familyId, m.uid, [h1, h2], 1);
  });

  it("limpa pendingTransfer se o destinatário for removido", async () => {
    const { owner, familyId, m } = await setup();
    await adminDb.doc(`families/${familyId}`).update({ pendingTransfer: { toUid: m.uid } });
    assertOk(await call("removeMember", { familyId, targetUid: m.uid }, owner));
    assert.equal((await getDoc(`families/${familyId}`))?.pendingTransfer, null);
  });

  it("erros", async () => {
    const { owner, familyId, m } = await setup();
    const other = await createUser();
    await addMember(familyId, other.uid);
    const s = await createUser();
    assertFails(await call("removeMember", { familyId, targetUid: m.uid }), "UNAUTHENTICATED");
    assertFails(await call("removeMember", { familyId, targetUid: m.uid }, other), "PERMISSION_DENIED", "NOT_OWNER");
    assertFails(await call("removeMember", { familyId, targetUid: m.uid }, s), "PERMISSION_DENIED", "NOT_MEMBER");
    assertFails(await call("removeMember", { familyId, targetUid: owner.uid }, owner), "FAILED_PRECONDITION", "OWNER_CANNOT_LEAVE");
    assertFails(await call("removeMember", { familyId, targetUid: s.uid }, owner), "NOT_FOUND", "MEMBER_NOT_FOUND");
    assertFails(await call("removeMember", { familyId: "nao-existe", targetUid: m.uid }, owner), "NOT_FOUND", "FAMILY_NOT_FOUND");
    assertFails(await call("removeMember", { familyId }, owner), "INVALID_ARGUMENT", "targetUid");
  });
});

describe("leaveFamily", () => {
  it("membro sai: mesmo efeito atômico da remoção", async () => {
    const { familyId, m, h1, h2 } = await setup();
    assertOk(await call("leaveFamily", { familyId }, m));
    await assertRemoved(familyId, m.uid, [h1, h2], 1);
  });

  it("idempotente e permitido em frozen", async () => {
    const { familyId, m } = await setup();
    await setStatus(familyId, "frozen");
    assertOk(await call("leaveFamily", { familyId }, m));
    assertOk(await call("leaveFamily", { familyId }, m));
    assert.equal((await getDoc(`families/${familyId}`))?.memberCount, 1);
  });

  it("owner -> OWNER_CANNOT_LEAVE; estranho -> NOT_MEMBER; inexistente -> FAMILY_NOT_FOUND; sem auth", async () => {
    const { owner, familyId } = await setup();
    const s = await createUser();
    assertFails(await call("leaveFamily", { familyId }, owner), "FAILED_PRECONDITION", "OWNER_CANNOT_LEAVE");
    assertFails(await call("leaveFamily", { familyId }, s), "PERMISSION_DENIED", "NOT_MEMBER");
    assertFails(await call("leaveFamily", { familyId: "zzz" }, s), "NOT_FOUND", "FAMILY_NOT_FOUND");
    assertFails(await call("leaveFamily", { familyId }), "UNAUTHENTICATED");
  });

  it("membro que saiu não consegue mais agir como membro (NOT_MEMBER em setHouseholdAccess)", async () => {
    const { familyId, m, h1 } = await setup();
    assertOk(await call("leaveFamily", { familyId }, m));
    assertFails(
      await call("setHouseholdAccess", { familyId, householdId: h1, targetUid: m.uid, role: "member" }, m),
      "PERMISSION_DENIED",
      "NOT_MEMBER",
    );
  });
});

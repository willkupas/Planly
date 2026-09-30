import assert from "node:assert/strict";
import { describe, it } from "node:test";
import { Timestamp } from "firebase-admin/firestore";
import {
  addMember, adminDb, assertFails, assertOk, bootstrap, call, createUser, getDoc, paidFamily, setPlan, setStatus,
} from "./helpers";

describe("createHousehold", () => {
  it("Free: já tem 1 casa -> PLAN_LIMIT_HOUSEHOLDS", async () => {
    const u = await createUser();
    const { familyId } = await bootstrap(u);
    assertFails(await call("createHousehold", { familyId, name: "Nova" }, u), "FAILED_PRECONDITION", "PLAN_LIMIT_HOUSEHOLDS");
  });

  it("Família: cria até 3 casas e a 4ª falha; contador e activity corretos", async () => {
    const { owner, familyId } = await paidFamily("family");
    const a = assertOk(await call("createHousehold", { familyId, name: "  Praia  " }, owner));
    assertOk(await call("createHousehold", { familyId, name: "Sítio" }, owner));
    assertFails(await call("createHousehold", { familyId, name: "Quarta" }, owner), "FAILED_PRECONDITION", "PLAN_LIMIT_HOUSEHOLDS");
    const fam = await getDoc(`families/${familyId}`);
    assert.equal(fam?.householdCount, 3);
    const h = await getDoc(`families/${familyId}/households/${a.householdId}`);
    assert.equal(h?.name, "Praia"); // trim
    assert.deepEqual(h?.access, {});
    assert.equal(h?.createdBy, owner.uid);
    const act = await adminDb.collection(`families/${familyId}/households/${a.householdId}/activity`).get();
    assert.equal(act.size, 1);
  });

  it("Família+: ilimitado (maxHouseholds null)", async () => {
    const { owner, familyId } = await paidFamily("family_plus", 4);
    assert.equal((await getDoc(`families/${familyId}`))?.householdCount, 5);
    assertOk(await call("createHousehold", { familyId, name: "Mais uma" }, owner));
  });

  it("concorrência: 2 createHousehold no último slot -> só 1 vence", async () => {
    const { owner, familyId } = await paidFamily("family", 1); // 2 de 3
    const rs = await Promise.all([
      call("createHousehold", { familyId, name: "A" }, owner),
      call("createHousehold", { familyId, name: "B" }, owner),
    ]);
    const okCount = rs.filter((r) => r.ok).length;
    assert.equal(okCount, 1);
    const fail = rs.find((r) => !r.ok);
    assertFails(fail!, "FAILED_PRECONDITION", "PLAN_LIMIT_HOUSEHOLDS");
    const fam = await getDoc(`families/${familyId}`);
    assert.equal(fam?.householdCount, 3);
    const hh = await adminDb.collection(`families/${familyId}/households`).get();
    assert.equal(hh.size, 3);
  });

  it("erros de autorização e estado", async () => {
    const { owner, familyId } = await paidFamily("family");
    const member = await createUser();
    await addMember(familyId, member.uid);
    const stranger = await createUser();

    assertFails(await call("createHousehold", { familyId, name: "X" }), "UNAUTHENTICATED");
    assertFails(await call("createHousehold", { familyId, name: "X" }, member), "PERMISSION_DENIED", "NOT_OWNER");
    assertFails(await call("createHousehold", { familyId, name: "X" }, stranger), "PERMISSION_DENIED", "NOT_MEMBER");
    assertFails(await call("createHousehold", { familyId: "nao-existe", name: "X" }, owner), "NOT_FOUND", "FAMILY_NOT_FOUND");
    assertFails(await call("createHousehold", { familyId, name: "" }, owner), "INVALID_ARGUMENT", "name");
    assertFails(await call("createHousehold", { familyId, name: "x".repeat(101) }, owner), "INVALID_ARGUMENT", "name");
    assertFails(await call("createHousehold", { familyId: "a/b", name: "X" }, owner), "INVALID_ARGUMENT", "familyId");

    await setStatus(familyId, "frozen");
    assertFails(await call("createHousehold", { familyId, name: "X" }, owner), "FAILED_PRECONDITION", "FAMILY_FROZEN");
    await setStatus(familyId, "deleting");
    assertFails(await call("createHousehold", { familyId, name: "X" }, owner), "FAILED_PRECONDITION", "FAMILY_FROZEN");
  });
});

describe("deleteHousehold / restoreHousehold", () => {
  it("LAST_HOUSEHOLD na única casa", async () => {
    const u = await createUser();
    const { familyId, householdId } = await bootstrap(u);
    assertFails(await call("deleteHousehold", { familyId, householdId }, u), "FAILED_PRECONDITION", "LAST_HOUSEHOLD");
  });

  it("soft delete: guarda deletedAccess, zera access, decrementa; idempotente", async () => {
    const { owner, familyId, householdIds } = await paidFamily("family", 1);
    const [h1, h2] = householdIds;
    const m = await createUser();
    await addMember(familyId, m.uid);
    assertOk(await call("setHouseholdAccess", { familyId, householdId: h2, targetUid: m.uid, role: "admin" }, owner));

    assertOk(await call("deleteHousehold", { familyId, householdId: h2 }, owner));
    const h = await getDoc(`families/${familyId}/households/${h2}`);
    assert.ok(h?.deletedAt);
    assert.deepEqual(h?.deletedAccess, { [m.uid]: "admin" });
    assert.deepEqual(h?.access, {});
    assert.deepEqual(h?.accessUids, []);
    assert.equal((await getDoc(`families/${familyId}`))?.householdCount, 1);

    // repetir: sucesso sem decrementar de novo
    assertOk(await call("deleteHousehold", { familyId, householdId: h2 }, owner));
    assert.equal((await getDoc(`families/${familyId}`))?.householdCount, 1);
    // a outra ainda é a última
    assertFails(await call("deleteHousehold", { familyId, householdId: h1 }, owner), "FAILED_PRECONDITION", "LAST_HOUSEHOLD");
  });

  it("erros: NOT_OWNER, NOT_MEMBER, HOUSEHOLD_NOT_FOUND, FAMILY_FROZEN", async () => {
    const { owner, familyId, householdIds } = await paidFamily("family", 1);
    const m = await createUser();
    await addMember(familyId, m.uid);
    const s = await createUser();
    const h = householdIds[1];
    assertFails(await call("deleteHousehold", { familyId, householdId: h }, m), "PERMISSION_DENIED", "NOT_OWNER");
    assertFails(await call("deleteHousehold", { familyId, householdId: h }, s), "PERMISSION_DENIED", "NOT_MEMBER");
    assertFails(await call("deleteHousehold", { familyId, householdId: "zzz" }, owner), "NOT_FOUND", "HOUSEHOLD_NOT_FOUND");
    await setStatus(familyId, "frozen");
    assertFails(await call("deleteHousehold", { familyId, householdId: h }, owner), "FAILED_PRECONDITION", "FAMILY_FROZEN");
  });

  it("restore: recompõe access/accessUids e incrementa; idempotente", async () => {
    const { owner, familyId, householdIds } = await paidFamily("family", 1);
    const h2 = householdIds[1];
    const m = await createUser();
    await addMember(familyId, m.uid);
    assertOk(await call("setHouseholdAccess", { familyId, householdId: h2, targetUid: m.uid, role: "member" }, owner));
    assertOk(await call("deleteHousehold", { familyId, householdId: h2 }, owner));

    assertOk(await call("restoreHousehold", { familyId, householdId: h2 }, owner));
    const h = await getDoc(`families/${familyId}/households/${h2}`);
    assert.equal(h?.deletedAt, null);
    assert.deepEqual(h?.access, { [m.uid]: "member" });
    assert.deepEqual(h?.accessUids, [m.uid]);
    assert.equal(h?.deletedAccess, undefined);
    assert.equal((await getDoc(`families/${familyId}`))?.householdCount, 2);
    assertOk(await call("restoreHousehold", { familyId, householdId: h2 }, owner));
    assert.equal((await getDoc(`families/${familyId}`))?.householdCount, 2);
  });

  it("restore revalida maxHouseholds (PLAN_LIMIT_HOUSEHOLDS) e respeita 30 dias", async () => {
    const { owner, familyId, householdIds } = await paidFamily("family", 2); // 3/3
    const h3 = householdIds[2];
    assertOk(await call("deleteHousehold", { familyId, householdId: h3 }, owner)); // 2/3
    assertOk(await call("createHousehold", { familyId, name: "Ocupa o slot" }, owner)); // 3/3
    assertFails(await call("restoreHousehold", { familyId, householdId: h3 }, owner), "FAILED_PRECONDITION", "PLAN_LIMIT_HOUSEHOLDS");

    // janela vencida
    assertOk(await call("deleteHousehold", { familyId, householdId: householdIds[1] }, owner)); // 2/3
    await adminDb
      .doc(`families/${familyId}/households/${householdIds[1]}`)
      .update({ deletedAt: Timestamp.fromMillis(Date.now() - 31 * 24 * 3600 * 1000) });
    assertFails(await call("restoreHousehold", { familyId, householdId: householdIds[1] }, owner), "NOT_FOUND", "HOUSEHOLD_NOT_FOUND");
  });

  it("restore: NOT_OWNER e FAMILY_FROZEN", async () => {
    const { owner, familyId, householdIds } = await paidFamily("family", 1);
    const m = await createUser();
    await addMember(familyId, m.uid);
    assertOk(await call("deleteHousehold", { familyId, householdId: householdIds[1] }, owner));
    assertFails(await call("restoreHousehold", { familyId, householdId: householdIds[1] }, m), "PERMISSION_DENIED", "NOT_OWNER");
    await setStatus(familyId, "frozen");
    assertFails(await call("restoreHousehold", { familyId, householdId: householdIds[1] }, owner), "FAILED_PRECONDITION", "FAMILY_FROZEN");
  });
});

describe("setHouseholdAccess", () => {
  it("concede, altera papel e revoga (access + accessUids consistentes)", async () => {
    const { owner, familyId, householdIds } = await paidFamily("family");
    const h = householdIds[0];
    const a = await createUser();
    const b = await createUser();
    await addMember(familyId, a.uid);
    await addMember(familyId, b.uid);
    const path = `families/${familyId}/households/${h}`;

    assertOk(await call("setHouseholdAccess", { familyId, householdId: h, targetUid: a.uid, role: "member" }, owner));
    assertOk(await call("setHouseholdAccess", { familyId, householdId: h, targetUid: b.uid, role: "admin" }, owner));
    let doc = await getDoc(path);
    assert.deepEqual(doc?.access, { [a.uid]: "member", [b.uid]: "admin" });
    assert.deepEqual([...doc?.accessUids].sort(), [a.uid, b.uid].sort());

    assertOk(await call("setHouseholdAccess", { familyId, householdId: h, targetUid: a.uid, role: "admin" }, owner));
    doc = await getDoc(path);
    assert.equal(doc?.access[a.uid], "admin");
    assert.equal(doc?.accessUids.filter((x: string) => x === a.uid).length, 1); // sem duplicar

    assertOk(await call("setHouseholdAccess", { familyId, householdId: h, targetUid: a.uid, role: null }, owner));
    doc = await getDoc(path);
    assert.deepEqual(doc?.access, { [b.uid]: "admin" });
    assert.deepEqual(doc?.accessUids, [b.uid]);
    // revogar de novo é inofensivo
    assertOk(await call("setHouseholdAccess", { familyId, householdId: h, targetUid: a.uid, role: null }, owner));
  });

  it("concorrência: concessões simultâneas a membros distintos não se perdem", async () => {
    const { owner, familyId, householdIds } = await paidFamily("family_plus");
    const h = householdIds[0];
    const users = await Promise.all([1, 2, 3, 4].map(() => createUser()));
    for (const u of users) await addMember(familyId, u.uid);
    const rs = await Promise.all(
      users.map((u) => call("setHouseholdAccess", { familyId, householdId: h, targetUid: u.uid, role: "member" }, owner)),
    );
    rs.forEach(assertOk);
    const doc = await getDoc(`families/${familyId}/households/${h}`);
    assert.equal(Object.keys(doc?.access).length, 4);
    assert.equal(doc?.accessUids.length, 4);
  });

  it("erros", async () => {
    const { owner, familyId, householdIds } = await paidFamily("family", 1);
    const [h1, h2] = householdIds;
    const m = await createUser();
    await addMember(familyId, m.uid);
    const s = await createUser();
    const base = { familyId, householdId: h1, targetUid: m.uid, role: "member" };

    assertFails(await call("setHouseholdAccess", base), "UNAUTHENTICATED");
    assertFails(await call("setHouseholdAccess", base, m), "PERMISSION_DENIED", "NOT_OWNER");
    assertFails(await call("setHouseholdAccess", base, s), "PERMISSION_DENIED", "NOT_MEMBER");
    assertFails(await call("setHouseholdAccess", { ...base, role: "owner" }, owner), "INVALID_ARGUMENT", "role");
    assertFails(await call("setHouseholdAccess", { ...base, role: undefined }, owner), "INVALID_ARGUMENT", "role");
    assertFails(await call("setHouseholdAccess", { ...base, targetUid: owner.uid }, owner), "INVALID_ARGUMENT", "targetUid");
    assertFails(await call("setHouseholdAccess", { ...base, targetUid: s.uid }, owner), "NOT_FOUND", "MEMBER_NOT_FOUND");
    assertFails(await call("setHouseholdAccess", { ...base, householdId: "zzz" }, owner), "NOT_FOUND", "HOUSEHOLD_NOT_FOUND");

    // membro removido não recebe acesso
    await adminDb.doc(`families/${familyId}/members/${m.uid}`).update({ status: "removed" });
    assertFails(await call("setHouseholdAccess", base, owner), "NOT_FOUND", "MEMBER_NOT_FOUND");
    await adminDb.doc(`families/${familyId}/members/${m.uid}`).update({ status: "active" });

    // casa excluída
    assertOk(await call("deleteHousehold", { familyId, householdId: h2 }, owner));
    assertFails(await call("setHouseholdAccess", { ...base, householdId: h2 }, owner), "NOT_FOUND", "HOUSEHOLD_NOT_FOUND");

    await setStatus(familyId, "frozen");
    assertFails(await call("setHouseholdAccess", base, owner), "FAILED_PRECONDITION", "FAMILY_FROZEN");
  });

  it("sanidade: setPlan auxiliar não quebra Free (owner em Free segue com 1 casa)", async () => {
    const u = await createUser();
    const { familyId } = await bootstrap(u);
    await setPlan(familyId, "free");
    assertFails(await call("createHousehold", { familyId, name: "Y" }, u), "FAILED_PRECONDITION", "PLAN_LIMIT_HOUSEHOLDS");
  });
});

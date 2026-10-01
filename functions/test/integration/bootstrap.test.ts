import assert from "node:assert/strict";
import { describe, it } from "node:test";
import { adminDb, assertFails, assertOk, call, createUser, createVerifiedUser, getDoc } from "./helpers";

describe("bootstrapUser", () => {
  it("sem auth -> UNAUTHENTICATED", async () => {
    assertFails(await call("bootstrapUser", {}), "UNAUTHENTICATED");
  });

  it("enforceAppCheck: sem token de App Check a chamada é recusada", async () => {
    const u = await createUser();
    const res = await fetch("http://127.0.0.1:5001/demo-planly-functions/southamerica-east1/bootstrapUser", {
      method: "POST",
      headers: { "content-type": "application/json", authorization: `Bearer ${u.token}` },
      body: JSON.stringify({ data: {} }),
    });
    assert.equal(res.status, 401);
    assert.equal(await getDoc(`users/${u.uid}`), undefined);
  });

  it("caminho feliz: cria user, Family Free, member owner, membership, entitlement e casa", async () => {
    const u = await createUser();
    const d = assertOk(await call("bootstrapUser", { displayName: "Ana", householdName: "Apê", timezone: "America/Sao_Paulo" }, u));
    assert.ok(d.familyId && d.householdId);

    const user = await getDoc(`users/${u.uid}`);
    assert.equal(user?.freeFamilyId, d.familyId);
    assert.equal(user?.email, u.email);
    assert.equal(user?.displayName, "Ana");
    assert.equal(user?.timezone, "America/Sao_Paulo");
    assert.equal(user?.schemaVersion, 1);

    const fam = await getDoc(`families/${d.familyId}`);
    assert.equal(fam?.ownerId, u.uid);
    assert.equal(fam?.plan, "free");
    assert.equal(fam?.status, "active");
    assert.equal(fam?.memberCount, 1);
    assert.equal(fam?.householdCount, 1);

    const mem = await getDoc(`families/${d.familyId}/members/${u.uid}`);
    assert.equal(mem?.role, "owner");
    assert.equal(mem?.status, "active");

    const ms = await getDoc(`users/${u.uid}/memberships/${d.familyId}`);
    assert.equal(ms?.role, "owner");

    const ent = await getDoc(`families/${d.familyId}/billing/entitlement`);
    assert.equal(ent?.plan, "free");
    assert.equal(ent?.maxMembers, 1);
    assert.equal(ent?.maxHouseholds, 1);
    assert.equal(ent?.features.invites, false);

    const h = await getDoc(`families/${d.familyId}/households/${d.householdId}`);
    assert.equal(h?.name, "Apê");
    assert.deepEqual(h?.access, {});
    assert.deepEqual(h?.accessUids, []);
    assert.equal(h?.deletedAt, null);

    const act = await adminDb.collection(`families/${d.familyId}/households/${d.householdId}/activity`).get();
    assert.equal(act.size, 1);
    assert.equal(act.docs[0].get("type"), "household_created");
    // nenhum e-mail espalhado em activity/members
    assert.equal(JSON.stringify(act.docs[0].data()).includes("@"), false);
    assert.equal(JSON.stringify(mem).includes("@"), false);
  });

  it("defaults: casa 'Minha casa' e locale pt-BR", async () => {
    const u = await createUser();
    const d = assertOk(await call("bootstrapUser", undefined, u));
    const h = await getDoc(`families/${d.familyId}/households/${d.householdId}`);
    assert.equal(h?.name, "Minha casa");
    assert.equal((await getDoc(`users/${u.uid}`))?.locale, "pt-BR");
  });

  it("idempotente: segunda chamada devolve os mesmos ids e não duplica", async () => {
    const u = await createUser();
    const a = assertOk(await call("bootstrapUser", {}, u));
    const b = assertOk(await call("bootstrapUser", { householdName: "Outra" }, u));
    assert.equal(a.familyId, b.familyId);
    assert.equal(a.householdId, b.householdId);
    const fams = await adminDb.collection("families").where("ownerId", "==", u.uid).get();
    assert.equal(fams.size, 1);
    const hh = await adminDb.collection(`families/${a.familyId}/households`).get();
    assert.equal(hh.size, 1);
  });

  it("concorrência: 3 chamadas simultâneas criam exatamente 1 Family", async () => {
    const u = await createUser();
    const rs = await Promise.all([1, 2, 3].map(() => call("bootstrapUser", {}, u)));
    const oks = rs.filter((r) => r.ok);
    assert.ok(oks.length >= 1);
    assert.equal(new Set(oks.map((r) => r.data?.familyId)).size, 1);
    const fams = await adminDb.collection("families").where("ownerId", "==", u.uid).get();
    assert.equal(fams.size, 1);
  });

  it("entrada inválida -> INVALID_ARGUMENT com reason = campo", async () => {
    const u = await createUser();
    assertFails(await call("bootstrapUser", { timezone: "Mars/Phobos" }, u), "INVALID_ARGUMENT", "timezone");
    assertFails(await call("bootstrapUser", { householdName: "x".repeat(101) }, u), "INVALID_ARGUMENT", "householdName");
    assertFails(await call("bootstrapUser", { displayName: 42 }, u), "INVALID_ARGUMENT", "displayName");
    assertFails(await call("bootstrapUser", "texto", u), "INVALID_ARGUMENT", "data");
  });

  it("rate limit: 6ª chamada na janela -> RATE_LIMITED", async () => {
    const u = await createUser();
    for (let i = 0; i < 5; i++) assertOk(await call("bootstrapUser", {}, u));
    assertFails(await call("bootstrapUser", {}, u), "RESOURCE_EXHAUSTED", "RATE_LIMITED");
    const rl = await getDoc(`_rateLimits/${u.uid}_bootstrapUser`);
    assert.equal(rl?.count, 5);
  });

  describe("lista de testadores (_testers, só dev/emulador)", () => {
    it("e-mail verificado na lista: a família já nasce com o plano", async () => {
      const u = await createVerifiedUser();
      await adminDb.doc(`_testers/${u.email}`).set({ plan: "family_plus" });
      const d = assertOk(await call("bootstrapUser", {}, u));
      const fam = await getDoc(`families/${d.familyId}`);
      assert.equal(fam?.plan, "family_plus");
      const ent = await getDoc(`families/${d.familyId}/billing/entitlement`);
      assert.equal(ent?.plan, "family_plus");
      assert.equal(ent?.maxMembers, 8);
      assert.equal(ent?.source, "tester");
      assert.equal(ent?.features.invites, true);
      const ms = await getDoc(`users/${u.uid}/memberships/${d.familyId}`);
      assert.equal(ms?.plan, "family_plus");
    });

    it("e-mail NÃO verificado na lista: continua Free", async () => {
      const u = await createUser();
      await adminDb.doc(`_testers/${u.email}`).set({ plan: "family_plus" });
      const d = assertOk(await call("bootstrapUser", {}, u));
      assert.equal((await getDoc(`families/${d.familyId}`))?.plan, "free");
    });

    it("fora da lista ou plano inválido: Free", async () => {
      const a = await createVerifiedUser();
      assert.equal((await getDoc(`families/${assertOk(await call("bootstrapUser", {}, a)).familyId}`))?.plan, "free");
      const b = await createVerifiedUser();
      await adminDb.doc(`_testers/${b.email}`).set({ plan: "ouro" });
      assert.equal((await getDoc(`families/${assertOk(await call("bootstrapUser", {}, b)).familyId}`))?.plan, "free");
    });

    it("quem já tinha entrado como Free sobe de plano no próximo bootstrap", async () => {
      const u = await createVerifiedUser();
      const d = assertOk(await call("bootstrapUser", {}, u));
      assert.equal((await getDoc(`families/${d.familyId}`))?.plan, "free");
      await adminDb.doc(`_testers/${u.email}`).set({ plan: "family" });
      assertOk(await call("bootstrapUser", {}, u));
      assert.equal((await getDoc(`families/${d.familyId}`))?.plan, "family");
      assert.equal((await getDoc(`families/${d.familyId}/billing/entitlement`))?.maxHouseholds, 3);
      assert.equal((await getDoc(`users/${u.uid}/memberships/${d.familyId}`))?.plan, "family");
    });

    it("não sobrepõe assinatura real nem rebaixa", async () => {
      const u = await createVerifiedUser();
      const d = assertOk(await call("bootstrapUser", {}, u));
      await adminDb.doc(`families/${d.familyId}`).update({ plan: "family_plus" });
      await adminDb.doc(`families/${d.familyId}/billing/entitlement`).set({ plan: "family_plus", maxMembers: 8, maxHouseholds: null, features: { invites: true, recurringTasks: true, fullHistory: true }, source: "subscription" });
      await adminDb.doc(`_testers/${u.email}`).set({ plan: "family" });
      assertOk(await call("bootstrapUser", {}, u));
      assert.equal((await getDoc(`families/${d.familyId}`))?.plan, "family_plus");
      assert.equal((await getDoc(`families/${d.familyId}/billing/entitlement`))?.source, "subscription");
    });
  });
});

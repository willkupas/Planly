import assert from "node:assert/strict";
import { describe, it } from "node:test";
import { Timestamp } from "firebase-admin/firestore";
import {
  TestUser,
  addMember,
  adminDb,
  assertFails,
  assertOk,
  bootstrap,
  call,
  createUser,
  getDoc,
  paidFamily,
  setPlan,
  setStatus,
} from "./helpers";

async function setup(plan: "family" | "family_plus" = "family") {
  const f = await paidFamily(plan, 1); // 2 casas
  const guest = await createUser();
  await bootstrap(guest);
  return { ...f, guest, h1: f.householdIds[0], h2: f.householdIds[1] };
}

type F = { owner: TestUser; familyId: string; h1: string; h2: string };

async function invite(f: F, grants?: unknown) {
  const d = assertOk(
    await call(
      "createInvitation",
      {
        familyId: f.familyId,
        grants: grants ?? [
          { householdId: f.h1, role: "member" },
          { householdId: f.h2, role: "admin" },
        ],
      },
      f.owner,
    ),
  );
  return d.code as string;
}

const one = (f: F) => ({ familyId: f.familyId, grants: [{ householdId: f.h1, role: "member" }] });

describe("createInvitation", () => {
  it("caminho feliz: código, link, expiração 24h, purgeAt, doc pending", async () => {
    const f = await setup();
    const d = assertOk(await call("createInvitation", one(f), f.owner));
    assert.match(d.code, /^[2-9A-HJKMNP-Z]{10}$/);
    assert.equal(d.link, `https://planly.app/join/${d.code}`);
    const inv = await getDoc(`invitations/${d.code}`);
    assert.equal(inv?.status, "pending");
    assert.equal(inv?.createdBy, f.owner.uid);
    assert.equal(inv?.familyId, f.familyId);
    assert.deepEqual(inv?.grants, [{ householdId: f.h1, role: "member" }]);
    const exp = (inv?.expiresAt as Timestamp).toMillis();
    const purge = (inv?.purgeAt as Timestamp).toMillis();
    assert.ok(Math.abs(exp - Date.now() - 24 * 3600 * 1000) < 60_000);
    assert.equal(purge - exp, 7 * 24 * 3600 * 1000);
    assert.equal(new Date(d.expiresAt).getTime(), exp);
  });

  it("Free bloqueado (FEATURE_NOT_IN_PLAN)", async () => {
    const owner = await createUser();
    const { familyId, householdId } = await bootstrap(owner);
    assertFails(
      await call("createInvitation", { familyId, grants: [{ householdId, role: "member" }] }, owner),
      "FAILED_PRECONDITION",
      "FEATURE_NOT_IN_PLAN",
    );
  });

  it("NOT_OWNER (membro) e NOT_MEMBER (estranho); sem auth; família frozen", async () => {
    const f = await setup();
    const m = await createUser();
    await addMember(f.familyId, m.uid);
    assertFails(await call("createInvitation", one(f), m), "PERMISSION_DENIED", "NOT_OWNER");
    assertFails(await call("createInvitation", one(f), f.guest), "PERMISSION_DENIED", "NOT_MEMBER");
    assertFails(await call("createInvitation", one(f)), "UNAUTHENTICATED");
    await setStatus(f.familyId, "frozen");
    assertFails(await call("createInvitation", one(f), f.owner), "FAILED_PRECONDITION", "FAMILY_FROZEN");
  });

  it("limite de membros conta pendentes (PLAN_LIMIT_MEMBERS); revogar libera a vaga", async () => {
    const f = await setup("family"); // max 4, owner = 1
    const codes: string[] = [];
    for (let i = 0; i < 3; i++) codes.push(await invite(f));
    assertFails(await call("createInvitation", one(f), f.owner), "FAILED_PRECONDITION", "PLAN_LIMIT_MEMBERS");
    assertOk(await call("revokeInvitation", { code: codes[0] }, f.owner));
    await invite(f); // vaga liberada
  });

  it("limite de membros conta membros atuais + pendentes", async () => {
    const f = await setup("family");
    for (let i = 0; i < 2; i++) await addMember(f.familyId, (await createUser()).uid);
    await invite(f); // 1 + 2 + 1 pendente = 4
    assertFails(await call("createInvitation", one(f), f.owner), "FAILED_PRECONDITION", "PLAN_LIMIT_MEMBERS");
  });

  it("convite pendente já expirado não conta no limite", async () => {
    const f = await setup("family");
    for (let i = 0; i < 2; i++) await addMember(f.familyId, (await createUser()).uid);
    const code = await invite(f);
    await adminDb.doc(`invitations/${code}`).update({ expiresAt: Timestamp.fromMillis(Date.now() - 1000) });
    await invite(f);
  });

  it("grants: casa de outra família / inexistente / excluída -> HOUSEHOLD_NOT_FOUND", async () => {
    const f = await setup();
    const other = await paidFamily("family", 0);
    const mk = (householdId: string) => [{ householdId, role: "member" }];
    const go = (g: unknown) => call("createInvitation", { familyId: f.familyId, grants: g }, f.owner);
    assertFails(await go(mk(other.householdIds[0])), "NOT_FOUND", "HOUSEHOLD_NOT_FOUND");
    assertFails(await go(mk("nao-existe")), "NOT_FOUND", "HOUSEHOLD_NOT_FOUND");
    assertFails(await go([...mk(f.h1), ...mk(other.householdIds[0])]), "NOT_FOUND", "HOUSEHOLD_NOT_FOUND");
    assertOk(await call("deleteHousehold", { familyId: f.familyId, householdId: f.h2 }, f.owner));
    assertFails(await go(mk(f.h2)), "NOT_FOUND", "HOUSEHOLD_NOT_FOUND");
  });

  it("validação de entrada", async () => {
    const f = await setup();
    const go = (d: unknown) => call("createInvitation", d, f.owner);
    assertFails(await go({ familyId: f.familyId }), "INVALID_ARGUMENT", "grants");
    assertFails(await go({ familyId: f.familyId, grants: [] }), "INVALID_ARGUMENT", "grants");
    assertFails(await go({ familyId: f.familyId, grants: [{ householdId: f.h1, role: "owner" }] }), "INVALID_ARGUMENT", "grants");
    assertFails(
      await go({ familyId: f.familyId, grants: [{ householdId: f.h1, role: "member" }, { householdId: f.h1, role: "admin" }] }),
      "INVALID_ARGUMENT",
      "grants",
    );
    assertFails(await go({ grants: [{ householdId: f.h1, role: "member" }] }), "INVALID_ARGUMENT", "familyId");
    assertFails(await go({ familyId: "nao-existe", grants: [{ householdId: f.h1, role: "member" }] }), "NOT_FOUND", "FAMILY_NOT_FOUND");
  });

  it("rate limit: 20/h por família", async () => {
    const f = await setup("family_plus");
    await adminDb.doc(`_rateLimits/${f.familyId}_createInvitation`).set({ count: 20, windowStart: Timestamp.now() });
    assertFails(await call("createInvitation", one(f), f.owner), "RESOURCE_EXHAUSTED", "RATE_LIMITED");
  });
});

describe("revokeInvitation", () => {
  it("owner criador revoga; repetir é idempotente; aceitar depois falha", async () => {
    const f = await setup();
    const code = await invite(f);
    assertOk(await call("revokeInvitation", { code }, f.owner));
    assertOk(await call("revokeInvitation", { code }, f.owner));
    assert.equal((await getDoc(`invitations/${code}`))?.status, "revoked");
    assertFails(await call("acceptInvitation", { code }, f.guest), "NOT_FOUND", "INVITE_NOT_FOUND");
  });

  it("outro usuário, inexistente, aceito ou formato inválido -> INVITE_NOT_FOUND", async () => {
    const f = await setup();
    const code = await invite(f);
    assertFails(await call("revokeInvitation", { code }, f.guest), "NOT_FOUND", "INVITE_NOT_FOUND");
    assertFails(await call("revokeInvitation", { code: "ZZZZZZZZZZ" }, f.owner), "NOT_FOUND", "INVITE_NOT_FOUND");
    assertFails(await call("revokeInvitation", { code: "x" }, f.owner), "NOT_FOUND", "INVITE_NOT_FOUND");
    assertFails(await call("revokeInvitation", { code }), "UNAUTHENTICATED");
    assertOk(await call("acceptInvitation", { code }, f.guest));
    assertFails(await call("revokeInvitation", { code }, f.owner), "NOT_FOUND", "INVITE_NOT_FOUND");
    assertFails(await call("revokeInvitation", {}, f.owner), "INVALID_ARGUMENT", "code");
  });
});

describe("acceptInvitation", () => {
  it("caminho feliz: membro, espelho, contador, grants, activity, convite accepted", async () => {
    const f = await setup();
    const code = await invite(f);
    const d = assertOk(await call("acceptInvitation", { code }, f.guest));
    assert.equal(d.familyId, f.familyId);
    assert.deepEqual([...d.householdIds].sort(), [f.h1, f.h2].sort());

    const mem = await getDoc(`families/${f.familyId}/members/${f.guest.uid}`);
    assert.equal(mem?.role, "member");
    assert.equal(mem?.status, "active");
    assert.equal(mem?.invitedBy, f.owner.uid);
    assert.equal(JSON.stringify(mem).includes("@"), false);
    const ms = await getDoc(`users/${f.guest.uid}/memberships/${f.familyId}`);
    assert.equal(ms?.role, "member");
    assert.equal(ms?.plan, "family");
    assert.equal((await getDoc(`families/${f.familyId}`))?.memberCount, 2);
    const h1 = await getDoc(`families/${f.familyId}/households/${f.h1}`);
    const h2 = await getDoc(`families/${f.familyId}/households/${f.h2}`);
    assert.equal(h1?.access[f.guest.uid], "member");
    assert.equal(h2?.access[f.guest.uid], "admin");
    assert.ok(h1?.accessUids.includes(f.guest.uid) && h2?.accessUids.includes(f.guest.uid));
    const inv = await getDoc(`invitations/${code}`);
    assert.equal(inv?.status, "accepted");
    assert.equal(inv?.acceptedBy, f.guest.uid);
    assert.ok(inv?.acceptedAt);
    for (const h of [f.h1, f.h2]) {
      const act = await adminDb
        .collection(`families/${f.familyId}/households/${h}/activity`)
        .where("type", "==", "member_joined")
        .get();
      assert.equal(act.size, 1);
      assert.equal(act.docs[0].get("actorId"), f.guest.uid);
    }
  });

  it("código normalizado: minúsculas, hífen e espaço", async () => {
    const f = await setup();
    const code = await invite(f);
    const messy = ` ${code.slice(0, 5).toLowerCase()}-${code.slice(5).toLowerCase()} `;
    assertOk(await call("acceptInvitation", { code: messy }, f.guest));
    assert.equal((await getDoc(`invitations/${code}`))?.status, "accepted");
  });

  it("idempotente para o mesmo uid; outro usuário recebe INVITE_NOT_FOUND", async () => {
    const f = await setup();
    const code = await invite(f);
    assertOk(await call("acceptInvitation", { code }, f.guest));
    const again = assertOk(await call("acceptInvitation", { code }, f.guest));
    assert.equal(again.familyId, f.familyId);
    assert.equal((await getDoc(`families/${f.familyId}`))?.memberCount, 2);
    const other = await createUser();
    await bootstrap(other);
    assertFails(await call("acceptInvitation", { code }, other), "NOT_FOUND", "INVITE_NOT_FOUND");
  });

  it("expirado: INVITE_EXPIRED e marca expired", async () => {
    const f = await setup();
    const code = await invite(f);
    await adminDb.doc(`invitations/${code}`).update({ expiresAt: Timestamp.fromMillis(Date.now() - 1000) });
    assertFails(await call("acceptInvitation", { code }, f.guest), "DEADLINE_EXCEEDED", "INVITE_EXPIRED");
    assert.equal((await getDoc(`invitations/${code}`))?.status, "expired");
    assert.equal((await getDoc(`families/${f.familyId}`))?.memberCount, 1);
    // depois de marcado, não distingue de inexistente
    assertFails(await call("acceptInvitation", { code }, f.guest), "NOT_FOUND", "INVITE_NOT_FOUND");
  });

  it("inexistente e formato inválido dão o mesmo erro; tipo errado é invalid-argument", async () => {
    const f = await setup();
    assertFails(await call("acceptInvitation", { code: "ZZZZZZZZZZ" }, f.guest), "NOT_FOUND", "INVITE_NOT_FOUND");
    assertFails(await call("acceptInvitation", { code: "abc" }, f.guest), "NOT_FOUND", "INVITE_NOT_FOUND");
    assertFails(await call("acceptInvitation", { code: "AAAA/AAAAA" }, f.guest), "NOT_FOUND", "INVITE_NOT_FOUND");
    assertFails(await call("acceptInvitation", { code: 123 }, f.guest), "INVALID_ARGUMENT", "code");
    assertFails(await call("acceptInvitation", { code: "ZZZZZZZZZZ" }), "UNAUTHENTICATED");
  });

  it("BOOTSTRAP_REQUIRED sem users/{uid}.freeFamilyId", async () => {
    const f = await setup();
    const code = await invite(f);
    const raw = await createUser(); // sem bootstrap
    assertFails(await call("acceptInvitation", { code }, raw), "FAILED_PRECONDITION", "BOOTSTRAP_REQUIRED");
    assert.equal((await getDoc(`invitations/${code}`))?.status, "pending");
  });

  it("ALREADY_MEMBER (owner e membro ativo); membro removido pode voltar", async () => {
    const f = await setup();
    const code = await invite(f);
    assertFails(await call("acceptInvitation", { code }, f.owner), "ALREADY_EXISTS", "ALREADY_MEMBER");
    const m = await createUser();
    await bootstrap(m);
    await addMember(f.familyId, m.uid);
    assertFails(await call("acceptInvitation", { code }, m), "ALREADY_EXISTS", "ALREADY_MEMBER");
    assertOk(await call("removeMember", { familyId: f.familyId, targetUid: m.uid }, f.owner));
    assertOk(await call("acceptInvitation", { code }, m));
    assert.equal((await getDoc(`families/${f.familyId}/members/${m.uid}`))?.status, "active");
    assert.equal((await getDoc(`families/${f.familyId}`))?.memberCount, 2);
  });

  it("família frozen -> FAMILY_FROZEN; limite caiu -> PLAN_LIMIT_MEMBERS", async () => {
    const f = await setup();
    const code = await invite(f);
    await setStatus(f.familyId, "frozen");
    assertFails(await call("acceptInvitation", { code }, f.guest), "FAILED_PRECONDITION", "FAMILY_FROZEN");
    await setStatus(f.familyId, "active");
    await setPlan(f.familyId, "free");
    assertFails(await call("acceptInvitation", { code }, f.guest), "FAILED_PRECONDITION", "PLAN_LIMIT_MEMBERS");
  });

  it("casa excluída entre criar e aceitar é ignorada nos grants", async () => {
    const f = await setup();
    const code = await invite(f);
    assertOk(await call("deleteHousehold", { familyId: f.familyId, householdId: f.h2 }, f.owner));
    const d = assertOk(await call("acceptInvitation", { code }, f.guest));
    assert.deepEqual(d.householdIds, [f.h1]);
    assert.deepEqual((await getDoc(`families/${f.familyId}/households/${f.h2}`))?.accessUids, []);
  });

  it("rate limit: 10/h por uid, conta também tentativas inválidas", async () => {
    const f = await setup();
    for (let i = 0; i < 10; i++) {
      assertFails(await call("acceptInvitation", { code: "ZZZZZZZZZZ" }, f.guest), "NOT_FOUND", "INVITE_NOT_FOUND");
    }
    assertFails(await call("acceptInvitation", { code: "ZZZZZZZZZZ" }, f.guest), "RESOURCE_EXHAUSTED", "RATE_LIMITED");
  });

  it("concorrência: mesmo código, dois usuários -> só um entra", async () => {
    const f = await setup();
    const code = await invite(f);
    const b = await createUser();
    await bootstrap(b);
    const rs = await Promise.all([call("acceptInvitation", { code }, f.guest), call("acceptInvitation", { code }, b)]);
    assert.equal(rs.filter((r) => r.ok).length, 1);
    assert.equal((await getDoc(`families/${f.familyId}`))?.memberCount, 2);
  });

  it("concorrência: dois convites distintos no último slot -> um vence, outro PLAN_LIMIT_MEMBERS", async () => {
    const f = await setup("family"); // max 4
    for (let i = 0; i < 2; i++) await addMember(f.familyId, (await createUser()).uid); // 3 membros
    const code1 = await invite(f);
    // segundo convite criado direto (o callable barraria por conta dos pendentes)
    const code2 = "ABCDEFGHJK";
    await adminDb.doc(`invitations/${code2}`).set({
      familyId: f.familyId,
      grants: [{ householdId: f.h1, role: "member" }],
      createdBy: f.owner.uid,
      status: "pending",
      expiresAt: Timestamp.fromMillis(Date.now() + 3600_000),
      purgeAt: Timestamp.fromMillis(Date.now() + 7 * 86400_000),
      createdAt: Timestamp.now(),
    });
    const b = await createUser();
    await bootstrap(b);
    const rs = await Promise.all([
      call("acceptInvitation", { code: code1 }, f.guest),
      call("acceptInvitation", { code: code2 }, b),
    ]);
    const wins = rs.filter((r) => r.ok);
    const losses = rs.filter((r) => !r.ok);
    assert.equal(wins.length, 1);
    assert.equal(losses.length, 1);
    assert.equal(losses[0].reason, "PLAN_LIMIT_MEMBERS");
    assert.equal((await getDoc(`families/${f.familyId}`))?.memberCount, 4);
  });
});

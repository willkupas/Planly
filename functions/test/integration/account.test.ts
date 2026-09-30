import assert from "node:assert/strict";
import { describe, it } from "node:test";
import { getAuth } from "firebase-admin/auth";
import { Timestamp } from "firebase-admin/firestore";
import {
  PROJECT,
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
} from "./helpers";

const b64 = (o: object) => Buffer.from(JSON.stringify(o)).toString("base64url");

/** Token não assinado (só vale no emulador) com auth_time antigo. */
function staleToken(u: TestUser): TestUser {
  const now = Math.floor(Date.now() / 1000);
  const payload = {
    iss: `https://securetoken.google.com/${PROJECT}`,
    aud: PROJECT,
    auth_time: now - 3600,
    user_id: u.uid,
    sub: u.uid,
    iat: now,
    exp: now + 3600,
    firebase: { identities: {}, sign_in_provider: "password" },
  };
  return { ...u, token: `${b64({ alg: "none", typ: "JWT" })}.${b64(payload)}.` };
}

async function authExists(uid: string): Promise<boolean> {
  try {
    await getAuth().getUser(uid);
    return true;
  } catch (e) {
    if ((e as { code?: string }).code === "auth/user-not-found") return false;
    throw e;
  }
}

async function seedContent(familyId: string, householdId: string, uid: string) {
  const h = `families/${familyId}/households/${householdId}`;
  await adminDb.doc(`${h}/tasks/t1`).set({ title: "x", createdBy: uid });
  await adminDb.doc(`${h}/lists/l1`).set({ name: "x", createdBy: uid });
  await adminDb.doc(`${h}/lists/l1/items/i1`).set({ title: "x", createdBy: uid });
  await adminDb.doc(`${h}/activity/manual`).set({
    type: "task_created",
    actorId: uid,
    actorName: "Fulano",
    targetType: "task",
    targetId: "t1",
    targetTitle: "x",
    createdAt: Timestamp.now(),
  });
}

async function exists(path: string) {
  return (await adminDb.doc(path).get()).exists;
}

describe("deleteAccount", () => {
  it("owner solo: cascata completa, users/*, rate limits e Auth apagados; outro usuário intacto", async () => {
    const u = await createUser();
    const { familyId, householdId } = await bootstrap(u);
    await seedContent(familyId, householdId, u.uid);
    await adminDb.doc(`users/${u.uid}/devices/d1`).set({ fcmToken: "fcm-falso", updatedAt: Timestamp.now() });
    await adminDb.doc(`invitations/CODE${u.uid.slice(0, 6)}`).set({ familyId, createdBy: u.uid, status: "pending" });
    const other = await createUser();
    const o = await bootstrap(other);
    await seedContent(o.familyId, o.householdId, other.uid);

    const r = assertOk(await call("deleteAccount", {}, u));
    assert.equal(r.deletedFamilies, 1);
    assert.equal(r.leftFamilies, 0);

    assert.equal(await exists(`families/${familyId}`), false);
    for (const c of ["households", "members", "billing"]) {
      assert.equal((await adminDb.collection(`families/${familyId}/${c}`).get()).size, 0, c);
    }
    assert.equal(await exists(`families/${familyId}/households/${householdId}/tasks/t1`), false);
    assert.equal(await exists(`families/${familyId}/households/${householdId}/lists/l1/items/i1`), false);
    assert.equal((await adminDb.collection(`families/${familyId}/households/${householdId}/activity`).get()).size, 0);
    assert.equal((await adminDb.collection("invitations").where("familyId", "==", familyId).get()).size, 0);
    assert.equal(await exists(`users/${u.uid}`), false);
    assert.equal((await adminDb.collection(`users/${u.uid}/devices`).get()).size, 0);
    assert.equal((await adminDb.collection(`users/${u.uid}/memberships`).get()).size, 0);
    assert.equal((await adminDb.collection("_rateLimits").get()).docs.some((d) => d.id.startsWith(`${u.uid}_`)), false);
    assert.equal(await authExists(u.uid), false);

    // Outro usuário intacto.
    assert.equal(await authExists(other.uid), true);
    assert.equal(await exists(`families/${o.familyId}`), true);
    assert.equal(await exists(`families/${o.familyId}/households/${o.householdId}/tasks/t1`), true);
    assert.equal((await adminDb.collection(`families/${o.familyId}/households/${o.householdId}/activity`).get()).size >= 2, true);
    assert.equal(await exists(`users/${other.uid}`), true);
  });

  it("owner de Free + família paga sem outros membros apaga todas", async () => {
    const f = await paidFamily("family", 1);
    const free = await bootstrap(f.owner); // idempotente: devolve a Free (a mesma da paidFamily)
    const r = assertOk(await call("deleteAccount", {}, f.owner));
    assert.equal(r.deletedFamilies >= 1, true);
    assert.equal(await exists(`families/${f.familyId}`), false);
    assert.equal(await exists(`families/${free.familyId}`), false);
    assert.equal(await authExists(f.owner.uid), false);
  });

  it("várias famílias próprias: todas removidas", async () => {
    const f = await paidFamily("family", 0);
    const second = `fam-extra-${f.owner.uid.slice(0, 8)}`;
    await adminDb.doc(`families/${second}`).set({ name: "Extra", ownerId: f.owner.uid, status: "active", plan: "family", memberCount: 1, householdCount: 0 });
    await adminDb.doc(`families/${second}/members/${f.owner.uid}`).set({ role: "owner", status: "active" });
    assertOk(await call("deleteAccount", {}, f.owner));
    assert.equal(await exists(`families/${f.familyId}`), false);
    assert.equal(await exists(`families/${second}`), false);
    assert.equal(await exists(`families/${second}/members/${f.owner.uid}`), false);
  });

  it("owner com membros ativos: OWNER_HAS_MEMBERS com familyIds e nada é apagado", async () => {
    const f = await paidFamily("family", 0);
    const m = await createUser();
    await addMember(f.familyId, m.uid);
    const r = await call("deleteAccount", {}, f.owner);
    assertFails(r, "FAILED_PRECONDITION", "OWNER_HAS_MEMBERS");
    const fam = await getDoc(`families/${f.familyId}`);
    assert.equal(fam?.status, "active");
    assert.equal(await exists(`families/${f.familyId}/households/${f.householdIds[0]}`), true);
    assert.equal(await exists(`users/${f.owner.uid}`), true);
    assert.equal(await authExists(f.owner.uid), true);
    assert.equal(await exists(`families/${f.familyId}/members/${m.uid}`), true);
  });

  it("membro removido (status removed) não bloqueia", async () => {
    const f = await paidFamily("family", 0);
    const m = await createUser();
    await addMember(f.familyId, m.uid);
    assertOk(await call("removeMember", { familyId: f.familyId, targetUid: m.uid }, f.owner));
    assertOk(await call("deleteAccount", {}, f.owner));
    assert.equal(await exists(`families/${f.familyId}`), false);
  });

  it("membro de família alheia: sai, anonimiza nomes e activity, mantém tarefas e eventos; só a Free dele é apagada", async () => {
    const f = await paidFamily("family", 0);
    const hid = f.householdIds[0];
    const m = await createUser();
    const mine = await bootstrap(m);
    await addMember(f.familyId, m.uid, "Bia Secreta");
    assertOk(await call("setHouseholdAccess", { familyId: f.familyId, householdId: hid, targetUid: m.uid, role: "member" }, f.owner));
    await seedContent(f.familyId, hid, m.uid);
    await adminDb.doc(`families/${f.familyId}`).update({ pendingTransfer: { toUid: m.uid } });

    const r = assertOk(await call("deleteAccount", {}, m));
    assert.equal(r.leftFamilies, 1);
    assert.equal(r.deletedFamilies, 1);

    const mem = await getDoc(`families/${f.familyId}/members/${m.uid}`);
    assert.equal(mem?.status, "removed");
    assert.equal(mem?.displayName, "Usuário removido");
    assert.equal(mem?.photoUrl, null);
    const fam = await getDoc(`families/${f.familyId}`);
    assert.equal(fam?.memberCount, 1);
    assert.equal(fam?.pendingTransfer, null);
    const household = await getDoc(`families/${f.familyId}/households/${hid}`);
    assert.equal((household?.accessUids ?? []).includes(m.uid), false);
    // Conteúdo permanece; createdBy (uid) não é alterado.
    assert.equal((await getDoc(`families/${f.familyId}/households/${hid}/tasks/t1`))?.createdBy, m.uid);
    const acts = await adminDb.collection(`families/${f.familyId}/households/${hid}/activity`).get();
    assert.equal(acts.docs.some((d) => d.get("actorId") === m.uid), true);
    for (const d of acts.docs) {
      if (d.get("actorId") === m.uid) assert.equal(d.get("actorName"), "Usuário removido");
      if (d.get("targetId") === m.uid) assert.equal(d.get("targetTitle"), "Usuário removido");
    }
    const dump = JSON.stringify(acts.docs.map((d) => d.data()));
    assert.equal(dump.includes("Bia Secreta"), false);
    assert.equal(dump.includes("Fulano"), false);
    // Família alheia intacta, Free do membro apagada, Auth apagado.
    assert.equal(await exists(`families/${f.familyId}`), true);
    assert.equal(await exists(`families/${mine.familyId}`), false);
    assert.equal(await authExists(m.uid), false);
    assert.equal(await exists(`users/${m.uid}`), false);
    assert.equal(await authExists(f.owner.uid), true);
  });

  it("idempotente e retomável: estado parcial (família deleting meio apagada) é concluído; repetir não falha", async () => {
    const u = await createUser();
    const { familyId, householdId } = await bootstrap(u);
    await seedContent(familyId, householdId, u.uid);
    // Simula queda após apagar parte da cascata.
    await adminDb.doc(`families/${familyId}`).update({ status: "deleting" });
    await adminDb.recursiveDelete(adminDb.collection(`families/${familyId}/members`));
    await adminDb.doc(`families/${familyId}/households/${householdId}/tasks/t1`).delete();

    assertOk(await call("deleteAccount", {}, u));
    assert.equal(await exists(`families/${familyId}`), false);
    assert.equal(await exists(`families/${familyId}/households/${householdId}/lists/l1/items/i1`), false);
    assert.equal(await authExists(u.uid), false);
    // Repetição após concluir.
    assertOk(await call("deleteAccount", {}, u));
  });

  it("retomada: Auth já apagado e user doc já removido, mas ainda em família alheia", async () => {
    const f = await paidFamily("family", 0);
    const m = await createUser();
    await bootstrap(m);
    await addMember(f.familyId, m.uid, "Bia");
    await getAuth().deleteUser(m.uid); // queda simulada depois do Auth; o token emitido ainda decodifica no emulador
    assertOk(await call("deleteAccount", {}, m));
    assert.equal((await getDoc(`families/${f.familyId}/members/${m.uid}`))?.status, "removed");
    assert.equal(await exists(`users/${m.uid}`), false);
  });

  it("durante a exclusão a família (deleting) não aceita convites pendentes", async () => {
    const f = await paidFamily("family", 0);
    const inv = assertOk(
      await call("createInvitation", { familyId: f.familyId, grants: [{ householdId: f.householdIds[0], role: "member" }] }, f.owner),
    );
    const invitee = await createUser();
    await bootstrap(invitee);
    await adminDb.doc(`families/${f.familyId}`).update({ status: "deleting" });
    assertFails(await call("acceptInvitation", { code: inv.code }, invitee), "FAILED_PRECONDITION", "FAMILY_FROZEN");
    // E o owner (sem membros) conclui a exclusão, apagando também o convite.
    assertOk(await call("deleteAccount", {}, f.owner));
    assert.equal(await exists(`invitations/${inv.code}`), false);
  });

  it("REQUIRES_RECENT_LOGIN com auth_time antigo; nada é apagado", async () => {
    const u = await createUser();
    const { familyId } = await bootstrap(u);
    assertFails(await call("deleteAccount", {}, staleToken(u)), "FAILED_PRECONDITION", "REQUIRES_RECENT_LOGIN");
    assert.equal(await exists(`families/${familyId}`), true);
    assert.equal(await authExists(u.uid), true);
  });

  it("sem login: UNAUTHENTICATED", async () => {
    assertFails(await call("deleteAccount", {}), "UNAUTHENTICATED");
  });

  it("rate limit: 3 por hora por uid", async () => {
    const f = await paidFamily("family", 0);
    const m = await createUser();
    await addMember(f.familyId, m.uid);
    for (let i = 0; i < 3; i++) assertFails(await call("deleteAccount", {}, f.owner), "FAILED_PRECONDITION", "OWNER_HAS_MEMBERS");
    assertFails(await call("deleteAccount", {}, f.owner), "RESOURCE_EXHAUSTED", "RATE_LIMITED");
  });
});

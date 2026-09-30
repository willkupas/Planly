import { getAuth } from "firebase-admin/auth";
import { FieldPath, FieldValue } from "firebase-admin/firestore";
import { domainError } from "../domain/errors";
import { FamilyDoc, MemberDoc } from "../domain/model";
import { loadFamilyContext } from "../lib/authz";
import { defineCallable } from "../lib/callable";
import { db, paths } from "../lib/db";
import { REMOVED_USER_NAME, removeMemberTx } from "../lib/membership";
import { prepareRateLimit } from "../lib/rateLimit";

const MAX_OWNED_FAMILIES = 200;
const RECENT_LOGIN_MS = 5 * 60 * 1000;
const HOUR_MS = 60 * 60 * 1000;

/**
 * §2.10 — exclusão de conta (LGPD, M11). Online-only, idempotente e retomável:
 * cada fase só apaga o que ainda existe e o Auth é apagado por último; se a função
 * cair no meio, uma nova chamada conclui (famílias `deleting` continuam sendo do owner
 * até o doc da família sumir, e as famílias alheias são percorridas pelo espelho
 * `users/{uid}/memberships`, que só é apagado junto com a saída).
 *
 * Privacidade: `createdBy`/`actorId` (uid, não PII direta) permanecem em tarefas,
 * listas e eventos de famílias alheias; nomes (`displayName`, `photoUrl`, `actorName`,
 * `targetTitle` de eventos de membro) são anonimizados. Sem e-mail em nenhum log.
 */
export const deleteAccount = defineCallable("deleteAccount", async (ctx) => {
  const uid = ctx.uid;

  // auth_time em segundos (Unix). Ausente/antigo = exige reautenticação (restritivo).
  const authTime = Number((ctx.token as { auth_time?: unknown }).auth_time);
  if (!Number.isFinite(authTime) || Date.now() - authTime * 1000 > RECENT_LOGIN_MS) {
    throw domainError("REQUIRES_RECENT_LOGIN");
  }

  await db().runTransaction(async (tx) => {
    const rl = await prepareRateLimit(tx, uid, "deleteAccount", 3, HOUR_MS);
    rl.apply();
  });

  // 1. Bloqueio + marca `deleting` (fecha aceite de convites) numa única transação.
  const ownedIds = await db().runTransaction(async (tx) => {
    const owned = await tx.get(paths.families().where("ownerId", "==", uid).limit(MAX_OWNED_FAMILIES));
    const memberSnaps = await Promise.all(owned.docs.map((f) => tx.get(f.ref.collection("members").where("status", "==", "active").limit(2))));
    const blocking = owned.docs.filter((_, i) => memberSnaps[i].docs.some((m) => m.id !== uid)).map((f) => f.id);
    if (blocking.length > 0) throw domainError("OWNER_HAS_MEMBERS", { familyIds: blocking });
    for (const f of owned.docs) {
      if ((f.data() as FamilyDoc).status !== "deleting") {
        tx.update(f.ref, { status: "deleting", updatedAt: FieldValue.serverTimestamp() });
      }
    }
    return owned.docs.map((f) => f.id);
  });

  // 2. Cascata nas famílias próprias (subcoleções primeiro; o doc da família por último,
  // para que uma retomada ainda o encontre pela query de ownerId).
  for (const familyId of ownedIds) {
    const famRef = paths.family(familyId);
    for (const col of await famRef.listCollections()) await db().recursiveDelete(col);
    const inv = await paths.invitations().where("familyId", "==", familyId).select().get();
    await deleteRefs(inv.docs.map((d) => d.ref));
    await famRef.delete();
  }

  // 3. Famílias alheias: anonimiza o histórico (antes de sair, para a retomada achar a
  // família pelo espelho) e sai como leaveFamily.
  const memberships = await paths.user(uid).collection("memberships").get();
  let left = 0;
  for (const m of memberships.docs) {
    const familyId = m.id;
    if (ownedIds.includes(familyId)) continue;
    await anonymizeActivity(familyId, uid);
    await db().runTransaction(async (tx) => {
      const famSnap = await tx.get(paths.family(familyId));
      if (!famSnap.exists) {
        tx.delete(m.ref);
        return;
      }
      const c = await loadFamilyContext(tx, familyId, uid);
      const memSnap = await tx.get(c.memberRef);
      const member = memSnap.exists ? (memSnap.data() as MemberDoc) : undefined;
      if (!member || member.status === "removed") {
        tx.delete(m.ref); // espelho órfão
        return;
      }
      await removeMemberTx(tx, familyId, c, uid, member, { anonymize: true });
    });
    left++;
  }

  // 4. Dados do usuário e rate limits dele.
  await db().recursiveDelete(paths.user(uid));
  const rls = await db()
    .collection("_rateLimits")
    .where(FieldPath.documentId(), ">=", `${uid}_`)
    .where(FieldPath.documentId(), "<", `${uid}_`)
    .select()
    .get();
  await deleteRefs(rls.docs.map((d) => d.ref));

  // 5. Auth por último. Já removido = sucesso (retomada).
  try {
    await getAuth().deleteUser(uid);
  } catch (e) {
    if ((e as { code?: string }).code !== "auth/user-not-found") throw e;
  }
  return { deletedFamilies: ownedIds.length, leftFamilies: left };
});

async function deleteRefs(refs: FirebaseFirestore.DocumentReference[]): Promise<void> {
  const writer = db().bulkWriter();
  for (const r of refs) writer.delete(r).catch(() => undefined);
  await writer.close();
}

/** actorName/targetTitle → "Usuário removido" nos eventos do uid (não apaga os eventos). */
async function anonymizeActivity(familyId: string, uid: string): Promise<void> {
  const households = await paths.households(familyId).select().get();
  const writer = db().bulkWriter();
  for (const h of households.docs) {
    const col = paths.activity(familyId, h.id);
    const [asActor, asTarget] = await Promise.all([
      col.where("actorId", "==", uid).get(),
      col.where("targetId", "==", uid).get(),
    ]);
    for (const d of asActor.docs) {
      const upd: Record<string, unknown> = { actorName: REMOVED_USER_NAME };
      if (d.get("targetType") === "member" && d.get("targetId") === uid) upd.targetTitle = REMOVED_USER_NAME;
      writer.update(d.ref, upd).catch(() => undefined);
    }
    for (const d of asTarget.docs) {
      if (d.get("targetType") === "member" && d.get("actorId") !== uid) {
        writer.update(d.ref, { targetTitle: REMOVED_USER_NAME }).catch(() => undefined);
      }
    }
  }
  await writer.close();
}

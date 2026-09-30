import { FieldPath, FieldValue, Transaction } from "firebase-admin/firestore";
import { domainError } from "../domain/errors";
import { FamilyDoc, HouseholdDoc, MemberDoc } from "../domain/model";
import { writeActivity } from "../lib/activity";
import { FamilyContext, loadFamilyContext, requireMember, requireOwner } from "../lib/authz";
import { defineCallable } from "../lib/callable";
import { db, paths } from "../lib/db";
import { asObject, reqId } from "../lib/validate";

/**
 * Remoção atômica (data-model §8 #3): members.status=removed, sai de access/accessUids
 * (e de deletedAccess das casas excluídas, para não voltar numa restauração),
 * apaga o espelho memberships, memberCount--, activity member_left.
 * Idempotente: membro já removido = sucesso sem efeito. NÃO exige família active
 * (sair/remover nunca é bloqueado por frozen).
 */
async function removeMemberTx(tx: Transaction, familyId: string, c: FamilyContext, targetUid: string, targetSnapData: MemberDoc | undefined) {
  if (!targetSnapData) throw domainError("MEMBER_NOT_FOUND");
  if (targetSnapData.status === "removed") return;
  if (targetSnapData.role === "owner") throw domainError("OWNER_CANNOT_LEAVE");

  // Todas as leituras antes das escritas.
  const households = await tx.get(paths.households(familyId));
  const now = FieldValue.serverTimestamp();
  const name = targetSnapData.displayName ?? "";
  const family: FamilyDoc = c.family;

  tx.update(paths.member(familyId, targetUid), { status: "removed", removedAt: now, updatedAt: now });
  for (const doc of households.docs) {
    const h = doc.data() as HouseholdDoc;
    if (h.deletedAt != null) {
      if (h.deletedAccess && targetUid in h.deletedAccess) {
        tx.update(doc.ref, new FieldPath("deletedAccess", targetUid), FieldValue.delete(), "updatedAt", now);
      }
    } else if (h.accessUids?.includes(targetUid) || (h.access && targetUid in h.access)) {
      tx.update(
        doc.ref,
        new FieldPath("access", targetUid),
        FieldValue.delete(),
        "accessUids",
        FieldValue.arrayRemove(targetUid),
        "updatedAt",
        now,
      );
      writeActivity(tx, familyId, doc.id, {
        type: "member_left",
        actorId: targetUid,
        actorName: name,
        targetType: "member",
        targetId: targetUid,
        targetTitle: name,
      });
    }
  }
  tx.delete(paths.membership(targetUid, familyId));
  const update: Record<string, unknown> = {
    memberCount: Math.max(0, (family.memberCount ?? 1) - 1),
    updatedAt: now,
  };
  if (family.pendingTransfer?.toUid === targetUid) update.pendingTransfer = null;
  tx.update(c.ref, update);
}

/** §2.7 — owner remove outro membro. */
export const removeMember = defineCallable("removeMember", async (ctx, input) => {
  const data = asObject(input);
  const familyId = reqId(data, "familyId");
  const targetUid = reqId(data, "targetUid");
  ctx.familyId = familyId;

  await db().runTransaction(async (tx) => {
    const c = await loadFamilyContext(tx, familyId, ctx.uid);
    requireOwner(c);
    if (targetUid === ctx.uid) throw domainError("OWNER_CANNOT_LEAVE");
    const tSnap = await tx.get(paths.member(familyId, targetUid));
    await removeMemberTx(tx, familyId, c, targetUid, tSnap.exists ? (tSnap.data() as MemberDoc) : undefined);
  });
  return {};
});

/**
 * §2.7 — membro sai da família. Owner recebe OWNER_CANNOT_LEAVE (deve transferir).
 * Quem já saiu (status removed) recebe sucesso idempotente.
 */
export const leaveFamily = defineCallable("leaveFamily", async (ctx, input) => {
  const data = asObject(input);
  const familyId = reqId(data, "familyId");
  ctx.familyId = familyId;

  await db().runTransaction(async (tx) => {
    const c = await loadFamilyContext(tx, familyId, ctx.uid);
    if (c.member?.status === "removed") return; // idempotente
    requireMember(c);
    if (c.isOwner) throw domainError("OWNER_CANNOT_LEAVE");
    await removeMemberTx(tx, familyId, c, ctx.uid, c.member);
  });
  return {};
});

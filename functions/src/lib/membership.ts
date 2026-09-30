import { FieldPath, FieldValue, Transaction } from "firebase-admin/firestore";
import { domainError } from "../domain/errors";
import { FamilyDoc, HouseholdDoc, MemberDoc } from "../domain/model";
import { writeActivity } from "./activity";
import { FamilyContext } from "./authz";
import { paths } from "./db";

/** Nome exibido no lugar de quem excluiu a conta (LGPD, M11). */
export const REMOVED_USER_NAME = "Usuário removido";

/**
 * Remoção atômica (data-model §8 #3): members.status=removed, sai de access/accessUids
 * (e de deletedAccess das casas excluídas, para não voltar numa restauração),
 * apaga o espelho memberships, memberCount--, activity member_left.
 * Idempotente: membro já removido = sucesso sem efeito. NÃO exige família active
 * (sair/remover nunca é bloqueado por frozen).
 * `anonymize` (exclusão de conta): limpa displayName/photoUrl do doc de membro e grava
 * o member_left com nome anonimizado.
 */
export async function removeMemberTx(
  tx: Transaction,
  familyId: string,
  c: FamilyContext,
  targetUid: string,
  targetSnapData: MemberDoc | undefined,
  opts: { anonymize?: boolean } = {},
) {
  if (!targetSnapData) throw domainError("MEMBER_NOT_FOUND");
  if (targetSnapData.status === "removed") return;
  if (targetSnapData.role === "owner") throw domainError("OWNER_CANNOT_LEAVE");

  // Todas as leituras antes das escritas.
  const households = await tx.get(paths.households(familyId));
  const now = FieldValue.serverTimestamp();
  const name = opts.anonymize ? REMOVED_USER_NAME : (targetSnapData.displayName ?? "");
  const family: FamilyDoc = c.family;

  tx.update(paths.member(familyId, targetUid), {
    status: "removed",
    removedAt: now,
    updatedAt: now,
    ...(opts.anonymize ? { displayName: REMOVED_USER_NAME, photoUrl: null } : {}),
  });
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

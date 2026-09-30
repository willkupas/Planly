import { domainError } from "../domain/errors";
import { MemberDoc } from "../domain/model";
import { loadFamilyContext, requireMember, requireOwner } from "../lib/authz";
import { defineCallable } from "../lib/callable";
import { db, paths } from "../lib/db";
import { removeMemberTx } from "../lib/membership";
import { asObject, reqId } from "../lib/validate";

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

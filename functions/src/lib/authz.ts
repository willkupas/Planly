import { DocumentReference, Transaction } from "firebase-admin/firestore";
import { domainError } from "../domain/errors";
import { FamilyDoc, MemberDoc } from "../domain/model";
import { Entitlement, PLANS, isPlanId } from "../domain/plans";
import { paths } from "./db";

export interface FamilyContext {
  ref: DocumentReference;
  family: FamilyDoc;
  member: MemberDoc | undefined;
  memberRef: DocumentReference;
  isOwner: boolean;
}

/** Lê família + doc de membro do chamador (leituras apenas). FAMILY_NOT_FOUND se não existe. */
export async function loadFamilyContext(tx: Transaction, familyId: string, uid: string): Promise<FamilyContext> {
  const ref = paths.family(familyId);
  const memberRef = paths.member(familyId, uid);
  const [famSnap, memSnap] = await Promise.all([tx.get(ref), tx.get(memberRef)]);
  if (!famSnap.exists) throw domainError("FAMILY_NOT_FOUND");
  const family = famSnap.data() as FamilyDoc;
  const member = memSnap.exists ? (memSnap.data() as MemberDoc) : undefined;
  return { ref, family, member, memberRef, isOwner: family.ownerId === uid };
}

/**
 * Autorização só por UID -> membership -> role (nunca e-mail).
 * Não-membro = NOT_MEMBER; membro não-owner = NOT_OWNER.
 */
export function requireOwner(c: FamilyContext): void {
  if (c.member?.status !== "active") throw domainError("NOT_MEMBER");
  if (!c.isOwner) throw domainError("NOT_OWNER");
}

export function requireMember(c: FamilyContext): void {
  if (c.member?.status !== "active") throw domainError("NOT_MEMBER");
}

/** Escrita de estrutura exige `active` (frozen E deleting bloqueiam). */
export function requireActive(family: FamilyDoc): void {
  if (family.status !== "active") throw domainError("FAMILY_FROZEN");
}

/** Limites vêm do entitlement; se o doc faltar/estiver inválido, cai no plano da família. */
export async function loadLimits(
  tx: Transaction,
  familyId: string,
  family: FamilyDoc,
): Promise<Pick<Entitlement, "maxMembers" | "maxHouseholds">> {
  const snap = await tx.get(paths.entitlement(familyId));
  if (snap.exists) {
    const d = snap.data() as Entitlement;
    if (typeof d.maxMembers === "number" && (d.maxHouseholds === null || typeof d.maxHouseholds === "number")) {
      return { maxMembers: d.maxMembers, maxHouseholds: d.maxHouseholds };
    }
  }
  return PLANS[isPlanId(family.plan) ? family.plan : "free"];
}

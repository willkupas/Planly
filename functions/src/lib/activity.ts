import { DocumentReference, FieldValue, Transaction } from "firebase-admin/firestore";
import { SCHEMA_VERSION } from "../domain/model";
import { paths } from "./db";

export type SystemActivityType = "household_created" | "member_joined" | "member_left";

/**
 * Activity de sistema (só Function escreve; data-model §3.11). Snapshots de nome,
 * sem e-mail. Agenda a escrita na transação (chamar só após todas as leituras).
 */
export function writeActivity(
  tx: Transaction,
  familyId: string,
  householdId: string,
  a: {
    type: SystemActivityType;
    actorId: string;
    actorName: string;
    targetType: "household" | "member";
    targetId: string;
    targetTitle: string;
  },
): DocumentReference {
  const ref = paths.activity(familyId, householdId).doc();
  tx.set(ref, { ...a, createdAt: FieldValue.serverTimestamp(), schemaVersion: SCHEMA_VERSION });
  return ref;
}

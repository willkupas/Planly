import { BulkWriter } from "firebase-admin/firestore";
import { db, paths } from "../lib/db";

/**
 * Exclusão em cascata de uma Family (mesma estratégia da fase 2 do `deleteAccount`, estendida
 * a todos os membros). Idempotente e retomável: cada passo só apaga o que ainda existe e o doc
 * da família vai por último, então uma nova execução continua de onde parou (a família segue
 * `deleting` e é achada de novo pela query do purgeJob).
 *
 * Ordem: espelhos `users/{uid}/memberships/{familyId}` de todos os membros (lidos de
 * `members`, ainda presente) -> subcolunas (casas e conteúdo, members, billing) -> convites da
 * família -> doc da família.
 */
export async function hardDeleteFamily(familyId: string): Promise<void> {
  const famRef = paths.family(familyId);

  const members = await famRef.collection("members").select().get();
  await deleteRefs(members.docs.map((m) => paths.membership(m.id, familyId)));

  for (const col of await famRef.listCollections()) await db().recursiveDelete(col);

  const inv = await paths.invitations().where("familyId", "==", familyId).select().get();
  await deleteRefs(inv.docs.map((d) => d.ref));

  await famRef.delete();
}

export async function deleteRefs(refs: FirebaseFirestore.DocumentReference[]): Promise<void> {
  const writer = db().bulkWriter();
  let failed = false;
  for (const r of refs) {
    writer.delete(r).catch(() => {
      failed = true;
    });
  }
  await writer.close();
  if (failed) throw new Error("bulk delete failed");
}

/** Apaga um doc e tudo abaixo dele (subcoleções) com um BulkWriter compartilhado. */
export async function recursiveDeleteRef(
  ref: FirebaseFirestore.DocumentReference,
  writer?: BulkWriter,
): Promise<void> {
  await db().recursiveDelete(ref, writer);
}

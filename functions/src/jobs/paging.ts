import { DocumentSnapshot, Query } from "firebase-admin/firestore";

/**
 * Percorre uma query em páginas com cursor por snapshot (não depende de os docs continuarem
 * satisfazendo a query após serem processados, então sempre termina). `maxPages` é um
 * teto de segurança contra loops.
 */
export async function forEachPage(
  query: Query,
  pageSize: number,
  fn: (doc: DocumentSnapshot) => Promise<void>,
  maxPages = 1000,
): Promise<number> {
  let cursor: DocumentSnapshot | undefined;
  let total = 0;
  for (let i = 0; i < maxPages; i++) {
    const snap = await (cursor ? query.startAfter(cursor) : query).limit(pageSize).get();
    if (snap.empty) break;
    for (const d of snap.docs) {
      await fn(d);
      total++;
    }
    cursor = snap.docs[snap.docs.length - 1];
    if (snap.size < pageSize) break;
  }
  return total;
}

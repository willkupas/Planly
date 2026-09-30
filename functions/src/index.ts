import { initializeApp } from "firebase-admin/app";
import { setGlobalOptions } from "firebase-functions/v2";
import { HttpsError, onCall } from "firebase-functions/v2/https";

// Região do Firestore; Functions com trigger de Firestore precisam estar na mesma.
setGlobalOptions({ region: "southamerica-east1", maxInstances: 10 });

initializeApp();

/**
 * Verificação de saúde usada para validar o ambiente (emulador e deploy).
 * Exige usuário autenticado; as Functions reais (bootstrapUser etc.) vêm na T-013,
 * conforme docs/specs/cloud-functions.md.
 */
export const healthCheck = onCall((request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Login necessário.");
  }
  return { ok: true };
});

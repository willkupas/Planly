import "./config";
import { HttpsError, onCall } from "firebase-functions/v2/https";
import { REGION } from "./config";

export { bootstrapUser } from "./callable/bootstrapUser";
export { createHousehold, deleteHousehold, restoreHousehold, setHouseholdAccess } from "./callable/households";
export { deleteAccount } from "./callable/account";
export { leaveFamily, removeMember } from "./callable/members";
export { acceptInvitation, createInvitation, revokeInvitation } from "./callable/invitations";

/**
 * Verificação de saúde usada para validar o ambiente (emulador e deploy).
 * Exige usuário autenticado.
 */
export const healthCheck = onCall({ region: REGION }, (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Login necessário.");
  }
  return { ok: true };
});

import "./config";
import { HttpsError, onCall } from "firebase-functions/v2/https";
import { REGION } from "./config";

export { bootstrapUser } from "./callable/bootstrapUser";
export { createHousehold, deleteHousehold, restoreHousehold, setHouseholdAccess } from "./callable/households";
export { deleteAccount } from "./callable/account";
export { leaveFamily, removeMember } from "./callable/members";
export { acceptInvitation, createInvitation, revokeInvitation } from "./callable/invitations";
export { cleanupJob, lifecycleJob, purgeJob } from "./jobs/scheduled";

// Endpoint de teste dos jobs: só existe no emulador (nunca exportado na nuvem).
if (process.env.FUNCTIONS_EMULATOR === "true") {
  // eslint-disable-next-line @typescript-eslint/no-require-imports
  exports.runScheduledJob = require("./jobs/testEndpoints").runScheduledJob;
}
export { pushOnListItemAdded, pushOnTaskCreated, pushOnTaskUpdated } from "./triggers/sharedEvents";

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

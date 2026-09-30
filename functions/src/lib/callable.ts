import { ENFORCE_APP_CHECK, REGION } from "../config";
import { DecodedIdToken } from "firebase-admin/auth";
import { HttpsError, onCall } from "firebase-functions/v2/https";
import { reasonOf, unauthenticated } from "../domain/errors";
import { logCall } from "./logger";

export interface CallContext {
  fn: string;
  uid: string;
  token: DecodedIdToken;
  familyId?: string;
  householdId?: string;
  operation?: string;
}

/**
 * Define uma callable com: App Check obrigatório na nuvem (opcional no emulador, ver
 * `ENFORCE_APP_CHECK`), auth obrigatória, log estruturado e envelope `{ok: true, ...}`.
 * Erros não-HttpsError viram `internal` sem vazar detalhes.
 */
export function defineCallable<R extends object>(
  name: string,
  handler: (ctx: CallContext, input: unknown) => Promise<R>,
) {
  return onCall({ region: REGION, enforceAppCheck: ENFORCE_APP_CHECK }, async (request) => {
    const start = Date.now();
    const ctx: Partial<CallContext> & { fn: string } = { fn: name, operation: name };
    const finish = (result: "ok" | "error", errorReason?: string) =>
      logCall({
        function: name,
        uid: ctx.uid,
        familyId: ctx.familyId,
        householdId: ctx.householdId,
        operation: ctx.operation,
        result,
        errorReason,
        durationMs: Date.now() - start,
      });
    try {
      if (!request.auth) throw unauthenticated();
      ctx.uid = request.auth.uid;
      ctx.token = request.auth.token;
      const out = await handler(ctx as CallContext, request.data);
      finish("ok");
      return { ok: true, ...out };
    } catch (e) {
      finish("error", reasonOf(e));
      if (e instanceof HttpsError) throw e;
      throw new HttpsError("internal", "Erro interno.");
    }
  });
}

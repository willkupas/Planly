import { getMessaging } from "firebase-admin/messaging";
import { db } from "../lib/db";
import { PushMessage, PushSender, SendResult } from "./pushTypes";

/** Códigos do FCM que significam "este token não serve mais" (o doc do device é removido). */
export const INVALID_TOKEN_CODES: ReadonlySet<string> = new Set([
  "messaging/registration-token-not-registered",
  "messaging/invalid-registration-token",
  "messaging/invalid-argument",
]);

/** Envio real via FCM (HTTP v1). Só dados (sem bloco `notification`): o app monta o texto. */
export class FcmPushSender implements PushSender {
  async send(messages: PushMessage[]): Promise<SendResult[]> {
    const out: SendResult[] = [];
    for (let i = 0; i < messages.length; i += 500) {
      const chunk = messages.slice(i, i + 500);
      const res = await getMessaging().sendEach(
        chunk.map((m) => ({
          token: m.token,
          data: m.data,
          android: { priority: "high" as const, collapseKey: m.collapseKey },
        })),
      );
      for (const r of res.responses) {
        out.push({ success: r.success, errorCode: r.error?.code });
      }
    }
    return out;
  }
}

/**
 * Remetente falso SÓ para o emulador (o FCM não é emulado): grava cada mensagem em
 * `_pushOutbox` (negada a clientes pelas Rules) para os testes inspecionarem. Tokens que
 * começam com `invalid-` simulam token não registrado.
 */
export class OutboxPushSender implements PushSender {
  async send(messages: PushMessage[]): Promise<SendResult[]> {
    const results: SendResult[] = [];
    for (const m of messages) {
      await db().collection("_pushOutbox").add({ token: m.token, data: m.data, collapseKey: m.collapseKey });
      const invalid = m.token.startsWith("invalid-");
      results.push({
        success: !invalid,
        errorCode: invalid ? "messaging/registration-token-not-registered" : undefined,
      });
    }
    return results;
  }
}

export function defaultPushSender(): PushSender {
  if (process.env.FUNCTIONS_EMULATOR === "true" && process.env.PUSH_FAKE_IN_EMULATOR === "true") {
    return new OutboxPushSender();
  }
  return new FcmPushSender();
}

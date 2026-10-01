import { PushType } from "./pushTypes";

/**
 * GANCHO de preferências por tipo de notificação (T-023).
 *
 * Hoje NÃO existe tela/campo de preferências: todos os tipos são enviados. Quando existir
 * (ex.: `users/{uid}.notificationPrefs.{type} == false` desliga o tipo), implementar aqui a
 * leitura (em lote, no máximo 1 leitura por destinatário) e devolver só os uids que aceitam
 * `type`. O restante do fluxo (dispatchPush) já chama este ponto único.
 */
export async function filterByPreferences(uids: string[], _type: PushType): Promise<string[]> {
  return uids;
}

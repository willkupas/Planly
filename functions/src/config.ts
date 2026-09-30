import { getApps, initializeApp } from "firebase-admin/app";
import { setGlobalOptions } from "firebase-functions/v2";

/**
 * Configuração global. Deve ser importada ANTES de qualquer definição de função
 * (imports ES viram require em ordem; lib/callable importa este módulo primeiro).
 */
export const REGION = "southamerica-east1";

setGlobalOptions({ region: REGION, maxInstances: 10 });

/**
 * App Check obrigatório nas callables. Na nuvem (dev/staging/prod) é SEMPRE exigido.
 * No emulador fica desligado por padrão: o app em dev contra emuladores não consegue obter
 * token sem registrar o token de debug no console. Os testes de integração ligam com
 * ENFORCE_APP_CHECK_IN_EMULATOR=true para provar a recusa sem token.
 */
export const ENFORCE_APP_CHECK =
  process.env.FUNCTIONS_EMULATOR !== "true" ||
  process.env.ENFORCE_APP_CHECK_IN_EMULATOR === "true";

if (getApps().length === 0) {
  initializeApp();
}

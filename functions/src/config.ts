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
const IN_EMULATOR = process.env.FUNCTIONS_EMULATOR === "true";

/**
 * Projeto Firebase de desenvolvimento NA NUVEM. É o único onde:
 *  - o App Check não é exigido (testadores instalam APKs fora da Play, que não passam no Play Integrity);
 *  - a lista de testadores (`_testers`) concede plano. Staging e prod nunca abrem mão de nenhum dos dois.
 */
export const DEV_PROJECT_ID = "planly-dev-d8533";
export const IS_DEV_CLOUD = !IN_EMULATOR && process.env.GCLOUD_PROJECT === DEV_PROJECT_ID;

export const ENFORCE_APP_CHECK = IN_EMULATOR
  ? process.env.ENFORCE_APP_CHECK_IN_EMULATOR === "true"
  : !IS_DEV_CLOUD;

/** Planos de teste por lista de e-mails: só no emulador e no dev na nuvem. */
export const TESTER_PLANS_ENABLED = IN_EMULATOR || IS_DEV_CLOUD;

if (getApps().length === 0) {
  initializeApp();
}

/**
 * Base do link de convite (`<base>/<code>`). PLACEHOLDER: o domínio real ainda não existe
 * (deep links/Android App Links ficam para depois; no MVP o app usa o código + share sheet).
 * Pode ser sobrescrito por variável de ambiente `INVITE_LINK_BASE` por ambiente (dev/staging/prod).
 */
export const INVITE_LINK_BASE = process.env.INVITE_LINK_BASE ?? "https://planly.app/join";

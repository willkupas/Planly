import { randomInt } from "node:crypto";

/**
 * Alfabeto sem caracteres ambíguos (sem 0/O/1/I/L): 2-9 e A-Z exceto I, L, O = 31 símbolos.
 * 10 chars => ~49,5 bits (spec pede "base32 ~50 bits"; 31 símbolos em vez de 32 por excluir
 * os ambíguos). Sorteio uniforme via `crypto.randomInt` (CSPRNG, sem viés de módulo).
 */
export const CODE_ALPHABET = "23456789ABCDEFGHJKMNPQRSTUVWXYZ";
export const CODE_LENGTH = 10;
export const INVITE_TTL_MS = 24 * 60 * 60 * 1000;
/** Retenção após expirar, até a política TTL do Firestore apagar (campo `purgeAt`). */
export const INVITE_PURGE_AFTER_MS = 7 * 24 * 60 * 60 * 1000;
export const MAX_GRANTS = 20;

export function generateCode(): string {
  let out = "";
  for (let i = 0; i < CODE_LENGTH; i++) out += CODE_ALPHABET[randomInt(CODE_ALPHABET.length)];
  return out;
}

/**
 * Normaliza a entrada do usuário: maiúsculas, sem hífen/espaço. Devolve `null` se o formato
 * não for de um código válido (o chamador trata como INVITE_NOT_FOUND, sem distinguir).
 */
export function normalizeCode(raw: string): string | null {
  const c = raw.toUpperCase().replace(/[\s-]/g, "");
  if (c.length !== CODE_LENGTH) return null;
  for (const ch of c) if (!CODE_ALPHABET.includes(ch)) return null;
  return c;
}

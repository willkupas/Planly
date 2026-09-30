import { invalidArgument } from "../domain/errors";

export type Input = Record<string, unknown>;

export function asObject(v: unknown): Input {
  if (typeof v !== "object" || v === null || Array.isArray(v)) throw invalidArgument("data");
  return v as Input;
}

export function asOptionalObject(v: unknown): Input {
  return v === undefined || v === null ? {} : asObject(v);
}

export function reqString(o: Input, field: string, min: number, max: number): string {
  const v = o[field];
  if (typeof v !== "string") throw invalidArgument(field);
  const t = v.trim();
  if (t.length < min || t.length > max) throw invalidArgument(field);
  return t;
}

export function optString(o: Input, field: string, min: number, max: number): string | undefined {
  if (o[field] === undefined || o[field] === null) return undefined;
  return reqString(o, field, min, max);
}

/** IDs de documento: sem `/`, tamanho limitado. */
export function reqId(o: Input, field: string): string {
  const v = o[field];
  if (typeof v !== "string" || v.length < 1 || v.length > 128 || v.includes("/") || v === "." || v === "..") {
    throw invalidArgument(field);
  }
  return v;
}

export function isValidTimeZone(tz: string): boolean {
  try {
    new Intl.DateTimeFormat("en", { timeZone: tz });
    return true;
  } catch {
    return false;
  }
}

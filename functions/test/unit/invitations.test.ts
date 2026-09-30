import assert from "node:assert/strict";
import { describe, it } from "node:test";
import { CODE_ALPHABET, CODE_LENGTH, generateCode, normalizeCode } from "../../src/domain/invitations";

describe("domain/invitations", () => {
  it("alfabeto sem caracteres ambíguos", () => {
    for (const ch of "01OIL") assert.equal(CODE_ALPHABET.includes(ch), false);
    assert.equal(new Set(CODE_ALPHABET).size, CODE_ALPHABET.length);
  });

  it("gera códigos de 10 chars só com o alfabeto, sem repetição em amostra grande", () => {
    const seen = new Set<string>();
    for (let i = 0; i < 2000; i++) {
      const c = generateCode();
      assert.equal(c.length, CODE_LENGTH);
      assert.match(c, /^[2-9A-HJKMNP-Z]{10}$/);
      seen.add(c);
    }
    assert.equal(seen.size, 2000);
  });

  it("normaliza: maiúsculas, sem hífen/espaço", () => {
    assert.equal(normalizeCode("abcde-fghjk"), "ABCDEFGHJK");
    assert.equal(normalizeCode(" abcde fghjk "), "ABCDEFGHJK");
  });

  it("formato inválido => null", () => {
    assert.equal(normalizeCode("abc"), null);
    assert.equal(normalizeCode("ABCDEFGHJ0"), null); // 0 fora do alfabeto
    assert.equal(normalizeCode("ABCDEFGHJK/"), null);
    assert.equal(normalizeCode("ABCDEFGHJKM"), null);
  });
});

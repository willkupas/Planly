import assert from "node:assert/strict";
import { describe, it } from "node:test";
import { domainError, invalidArgument, reasonOf } from "../../src/domain/errors";
import { PLANS, canAddHousehold, canAddMember, entitlementFor, isPlanId } from "../../src/domain/plans";

describe("domain/plans", () => {
  it("define os três planos com os limites do data-model", () => {
    assert.equal(PLANS.free.maxMembers, 1);
    assert.equal(PLANS.free.maxHouseholds, 1);
    assert.equal(PLANS.free.features.invites, false);
    assert.equal(PLANS.family.maxMembers, 4);
    assert.equal(PLANS.family.maxHouseholds, 3);
    assert.equal(PLANS.family.features.invites, true);
    assert.equal(PLANS.family_plus.maxMembers, 8);
    assert.equal(PLANS.family_plus.maxHouseholds, null);
  });

  it("cada entrada tem `plan` igual à sua chave", () => {
    for (const [k, v] of Object.entries(PLANS)) assert.equal(v.plan, k);
  });

  it("isPlanId valida", () => {
    assert.ok(isPlanId("free"));
    assert.ok(isPlanId("family_plus"));
    assert.ok(!isPlanId("gold"));
    assert.ok(!isPlanId(undefined));
  });

  it("entitlementFor devolve cópia (não muta PLANS)", () => {
    const e = entitlementFor("family");
    e.maxMembers = 99;
    e.features.invites = false;
    assert.equal(PLANS.family.maxMembers, 4);
    assert.equal(PLANS.family.features.invites, true);
  });

  it("canAddHousehold respeita limite e ilimitado", () => {
    assert.ok(canAddHousehold(PLANS.free, 0));
    assert.ok(!canAddHousehold(PLANS.free, 1));
    assert.ok(canAddHousehold(PLANS.family, 2));
    assert.ok(!canAddHousehold(PLANS.family, 3));
    assert.ok(canAddHousehold(PLANS.family_plus, 10_000));
  });

  it("canAddMember considera reservas (convites pendentes)", () => {
    assert.ok(!canAddMember(PLANS.free, 1));
    assert.ok(canAddMember(PLANS.family, 3));
    assert.ok(!canAddMember(PLANS.family, 3, 1));
    assert.ok(canAddMember(PLANS.family_plus, 5, 2));
    assert.ok(!canAddMember(PLANS.family_plus, 6, 2));
  });
});

describe("domain/errors", () => {
  it("mapeia reason -> code conforme o spec §1.1", () => {
    const cases: Array<[Parameters<typeof domainError>[0], string]> = [
      ["NOT_OWNER", "permission-denied"],
      ["NOT_MEMBER", "permission-denied"],
      ["FAMILY_FROZEN", "failed-precondition"],
      ["PLAN_LIMIT_HOUSEHOLDS", "failed-precondition"],
      ["LAST_HOUSEHOLD", "failed-precondition"],
      ["OWNER_CANNOT_LEAVE", "failed-precondition"],
      ["FAMILY_NOT_FOUND", "not-found"],
      ["MEMBER_NOT_FOUND", "not-found"],
      ["ALREADY_MEMBER", "already-exists"],
      ["RATE_LIMITED", "resource-exhausted"],
    ];
    for (const [reason, code] of cases) {
      const e = domainError(reason);
      assert.equal(e.code, code);
      assert.equal(reasonOf(e), reason);
    }
  });

  it("invalidArgument usa o campo como reason; erro genérico vira INTERNAL", () => {
    const e = invalidArgument("name");
    assert.equal(e.code, "invalid-argument");
    assert.equal(reasonOf(e), "name");
    assert.equal(reasonOf(new Error("x")), "INTERNAL");
  });
});

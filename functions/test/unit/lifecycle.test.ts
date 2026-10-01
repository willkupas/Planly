import assert from "node:assert/strict";
import { describe, it } from "node:test";
import {
  DAY_MS,
  deleteAfterMs,
  dueDeletionWarning,
  expiryOutcome,
  isExpiryWarningDue,
  isOverLimit,
  isSubscriptionExpired,
  isSubscriptionLive,
  limitsFor,
} from "../../src/domain/lifecycle";
import { fixedClock } from "../../src/lib/clock";

const T0 = Date.UTC(2026, 0, 1);

describe("domain/lifecycle", () => {
  it("relógio injetável avança e redefine", () => {
    const c = fixedClock(T0);
    assert.equal(c.nowMs(), T0);
    c.advance(DAY_MS);
    assert.equal(c.nowMs(), T0 + DAY_MS);
    c.set(5);
    assert.equal(c.nowMs(), 5);
  });

  it("assinatura expirada: expired ou canceled vencida; active/grace/on_hold nunca", () => {
    assert.equal(isSubscriptionExpired(null, T0), false);
    assert.equal(isSubscriptionExpired({ state: "expired", expiresAtMs: null }, T0), true);
    assert.equal(isSubscriptionExpired({ state: "canceled", expiresAtMs: T0 }, T0), true);
    assert.equal(isSubscriptionExpired({ state: "canceled", expiresAtMs: T0 + 1 }, T0), false);
    for (const state of ["active", "grace", "on_hold"] as const) {
      assert.equal(isSubscriptionExpired({ state, expiresAtMs: T0 - DAY_MS }, T0), false);
      assert.equal(isSubscriptionLive({ state, expiresAtMs: null }, T0), true);
    }
    assert.equal(isSubscriptionLive({ state: "expired", expiresAtMs: null }, T0), false);
  });

  it("downgrade só com owner e <= 1 casa; senão congela", () => {
    assert.equal(expiryOutcome({ activeMembers: 1, households: 1 }), "downgrade_free");
    assert.equal(expiryOutcome({ activeMembers: 1, households: 0 }), "downgrade_free");
    assert.equal(expiryOutcome({ activeMembers: 2, households: 1 }), "freeze");
    assert.equal(expiryOutcome({ activeMembers: 1, households: 2 }), "freeze");
  });

  it("deleteAfter = frozenAt + 90 dias", () => {
    assert.equal(deleteAfterMs(T0), T0 + 90 * DAY_MS);
  });

  it("limites: entitlement manda, plano é o fallback, null = ilimitado", () => {
    assert.deepEqual(limitsFor("family", null), { maxMembers: 4, maxHouseholds: 3 });
    assert.deepEqual(limitsFor("family", { maxMembers: 2, maxHouseholds: 1 }), { maxMembers: 2, maxHouseholds: 1 });
    assert.equal(limitsFor("family_plus", { maxMembers: 8, maxHouseholds: null }).maxHouseholds, null);
    assert.equal(isOverLimit({ activeMembers: 5, households: 1 }, { maxMembers: 4, maxHouseholds: 3 }), true);
    assert.equal(isOverLimit({ activeMembers: 4, households: 9 }, { maxMembers: 4, maxHouseholds: null }), false);
    assert.equal(isOverLimit({ activeMembers: 4, households: 4 }, { maxMembers: 4, maxHouseholds: 3 }), true);
  });

  it("avisos de exclusão: marcos D-60/-30/-7/-1, sem repetição, só o mais recente se vários venceram", () => {
    const del = T0 + 90 * DAY_MS;
    const none = new Set<string>();
    assert.equal(dueDeletionWarning(del, del - 61 * DAY_MS, none).send, null);
    assert.equal(dueDeletionWarning(del, del - 60 * DAY_MS, none).send, "delete_d60");
    const seen = new Set(["delete_d60"]);
    assert.equal(dueDeletionWarning(del, del - 59 * DAY_MS, seen).send, null);
    assert.equal(dueDeletionWarning(del, del - 30 * DAY_MS, seen).send, "delete_d30");
    // job parado: venceram d60 e d30 e d7 de uma vez -> envia d7, marca os três
    const late = dueDeletionWarning(del, del - 6 * DAY_MS, none);
    assert.equal(late.send, "delete_d7");
    assert.deepEqual(late.markAll, ["delete_d60", "delete_d30", "delete_d7"]);
    assert.equal(dueDeletionWarning(del, del - 12 * 60 * 60 * 1000, new Set(["delete_d60", "delete_d30", "delete_d7"])).send, "delete_d1");
    assert.equal(dueDeletionWarning(del, del, none).send, null);
  });

  it("aviso D-7 de expiração: só canceled na janela, uma vez por ciclo", () => {
    const exp = T0 + 30 * DAY_MS;
    const sub = { state: "canceled" as const, expiresAtMs: exp };
    assert.equal(isExpiryWarningDue(sub, exp - 8 * DAY_MS, null), false);
    assert.equal(isExpiryWarningDue(sub, exp - 7 * DAY_MS, null), true);
    assert.equal(isExpiryWarningDue(sub, exp - 3 * DAY_MS, exp - 7 * DAY_MS), false);
    // aviso de um ciclo anterior não conta
    assert.equal(isExpiryWarningDue(sub, exp - 3 * DAY_MS, exp - 40 * DAY_MS), true);
    assert.equal(isExpiryWarningDue(sub, exp, null), false);
    assert.equal(isExpiryWarningDue({ state: "active", expiresAtMs: exp }, exp - DAY_MS, null), false);
    assert.equal(isExpiryWarningDue(null, exp - DAY_MS, null), false);
  });
});

import { readdirSync, readFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";
import { describe, expect, it } from "vitest";
import { computeBalances } from "../src/lib/balances.ts";
import { assertMembersExist, assertPayersSum, assertSplitsSum } from "../src/lib/validation.ts";
import type { Expense, ExpensePayment, ExpenseSplit, Member } from "../src/lib/types.ts";

// The shared split scenarios (`test-fixtures/splits/`, format in
// `test-fixtures/README.md`). PalanceKit's `SplitScenarioTests` runs each one
// from form input through `ExpenseDraft` to balances; here the *expected*
// payers + splits — exactly what the client sends — must pass the server's own
// validators and produce the same balances in the TypeScript balance math.

const scenariosDir = join(dirname(fileURLToPath(import.meta.url)), "..", "..", "test-fixtures", "splits");

interface Scenario {
  name: string;
  story: string;
  members: string[];
  currency: string;
  expect: {
    cannotSave?: boolean;
    payers?: Record<string, number>;
    splits?: Record<string, number>;
    balances?: Record<string, number>;
  };
}

const scenarios: Scenario[] = readdirSync(scenariosDir)
  .filter((f) => f.endsWith(".json"))
  .sort()
  .map((f) => JSON.parse(readFileSync(join(scenariosDir, f), "utf8")) as Scenario);

/** Map → wire array, in the group's member order (the order the client sends). */
function inMemberOrder(members: string[], amounts: Record<string, number>): { memberId: string; amountMinor: number }[] {
  return members.filter((id) => id in amounts).map((id) => ({ memberId: id, amountMinor: amounts[id]! }));
}

describe("split scenarios (shared with PalanceKitTests/SplitScenarioTests)", () => {
  it("there are scenarios to run", () => {
    expect(scenarios.length).toBeGreaterThanOrEqual(12);
  });

  for (const s of scenarios.filter((s) => !s.expect.cannotSave)) {
    it(s.name, () => {
      const payers: ExpensePayment[] = inMemberOrder(s.members, s.expect.payers!);
      const splits: ExpenseSplit[] = inMemberOrder(s.members, s.expect.splits!);
      const amountMinor = payers.reduce((sum, p) => sum + p.amountMinor, 0);
      const memberIds = new Set(s.members);

      // The server accepts exactly what the client produced.
      expect(() => assertPayersSum(amountMinor, payers)).not.toThrow();
      expect(() => assertSplitsSum(amountMinor, splits)).not.toThrow();
      expect(() => assertMembersExist([...payers, ...splits].map((x) => x.memberId), memberIds)).not.toThrow();

      const members: Member[] = s.members.map((id) => ({ id, displayName: id, isClaimed: false }));
      const expense: Expense = {
        id: "e",
        payers,
        amountMinor,
        currency: s.currency,
        description: s.name,
        date: "2026-01-01T00:00:00Z",
        splitType: "equal",
        splits,
      };
      const balances = computeBalances(members, [expense], []);
      const byMember = Object.fromEntries(balances.filter((b) => b.netMinor !== 0).map((b) => [b.memberId, b.netMinor]));
      expect(byMember).toEqual(s.expect.balances);
    });
  }
});

/// <reference types="vite/client" />
import { SELF } from "cloudflare:test";
import { describe, expect, it } from "vitest";

// End-to-end over the shared split scenarios (`test-fixtures/splits/`,
// `CHECKLIST.md` "Test framework rebuild" step 5): for each one, create a real
// group through the router, add its members, POST the expense exactly as the
// app would send it (payers + splits, plus items/tax/tip or share weights for
// those split types), then read the group back over HTTP and compare its
// balances to the scenario's hand-worked numbers.
//
// The Workers runtime has no filesystem, so the fixtures are inlined at build
// time by Vite's `import.meta.glob`.

const BASE = "https://api.test";

interface Scenario {
  name: string;
  members: string[];
  currency: string;
  split: {
    type: "equal" | "exact" | "percentage" | "shares" | "itemized";
    weights?: Record<string, string>;
    percents?: Record<string, string>;
    items?: { name: string; amount: string; for: string[] }[];
    tax?: string;
    tip?: string;
  };
  expect: {
    cannotSave?: boolean;
    payers?: Record<string, number>;
    splits?: Record<string, number>;
    balances?: Record<string, number>;
  };
}

const files = import.meta.glob<Scenario>("../../test-fixtures/splits/*.json", { eager: true, import: "default" });
const scenarios = Object.keys(files)
  .sort()
  .map((path) => files[path]!);

/** A plain decimal as typed in a fixture ("30", "2000.02") → minor units. */
function minor(text: string): number {
  const [whole, frac = ""] = text.trim().split(".");
  return Number(whole) * 100 + Number(frac.padEnd(2, "0").slice(0, 2));
}

async function call(method: string, path: string, token: string | undefined, body?: unknown) {
  const url = `${BASE}${path}${token ? `${path.includes("?") ? "&" : "?"}token=${token}` : ""}`;
  const res = await SELF.fetch(url, { method, body: body === undefined ? undefined : JSON.stringify(body) });
  const text = await res.text();
  return { status: res.status, json: (text ? JSON.parse(text) : {}) as Record<string, any> };
}

describe("split scenarios end to end (router → Durable Object → balances)", () => {
  it("there are scenarios to run", () => {
    expect(scenarios.length).toBeGreaterThanOrEqual(12);
  });

  for (const s of scenarios.filter((s) => !s.expect.cannotSave)) {
    it(s.name, async () => {
      // Group + members, recording each fixture name's server-side id.
      const created = await call("POST", "/api/groups", undefined, {
        name: s.name.slice(0, 60),
        currency: s.currency,
        creatorDisplayName: s.members[0],
      });
      expect(created.status).toBe(201);
      const groupId: string = created.json.groupId;
      const token: string = created.json.group.accessToken;
      const idOf: Record<string, string> = { [s.members[0]!]: created.json.member.id };
      for (const name of s.members.slice(1)) {
        const joined = await call("POST", `/api/groups/${groupId}/members`, token, { displayName: name });
        expect(joined.status).toBe(201);
        idOf[name] = joined.json.member.id;
      }
      const nameOf = Object.fromEntries(Object.entries(idOf).map(([name, id]) => [id, name]));
      const wire = (amounts: Record<string, number>) =>
        s.members.filter((n) => n in amounts).map((n) => ({ memberId: idOf[n]!, amountMinor: amounts[n]! }));

      const payers = wire(s.expect.payers!);
      const amountMinor = payers.reduce((sum, p) => sum + p.amountMinor, 0);
      const body: Record<string, unknown> = {
        payers,
        amountMinor,
        currency: s.currency,
        description: s.name.slice(0, 60),
        date: "2026-01-01T12:00:00Z",
        splitType: s.split.type,
        splits: wire(s.expect.splits!),
      };
      if (s.split.type === "shares") {
        body.shares = s.members
          .filter((n) => Number(s.split.weights?.[n] ?? 0) > 0)
          .map((n) => ({ memberId: idOf[n], weight: Number(s.split.weights![n]) }));
      }
      // A percentage expense also sends the percents as typed (schema v15).
      const percentages =
        s.split.type === "percentage"
          ? s.members
              .filter((n) => Number(s.split.percents?.[n] ?? 0) > 0)
              .map((n) => ({ memberId: idOf[n]!, percent: Number(s.split.percents![n]) }))
          : undefined;
      if (percentages) body.percentages = percentages;
      if (s.split.type === "itemized") {
        body.items = s.split.items!.map((item, i) => ({
          id: `item-${i}`,
          name: item.name,
          amountMinor: minor(item.amount),
          participantIds: s.members.filter((n) => item.for.includes(n)).map((n) => idOf[n]),
        }));
        if (s.split.tax) body.taxMinor = minor(s.split.tax);
        if (s.split.tip) body.tipMinor = minor(s.split.tip);
      }

      const added = await call("POST", `/api/groups/${groupId}/expenses`, token, body);
      expect(added.status, JSON.stringify(added.json)).toBe(201);

      const state = await call("GET", `/api/groups/${groupId}`, token);
      expect(state.status).toBe(200);
      if (percentages) expect(state.json.expenses[0].percentages).toEqual(percentages);
      const balances = Object.fromEntries(
        (state.json.balances as { memberId: string; netMinor: number }[])
          .filter((b) => b.netMinor !== 0)
          .map((b) => [nameOf[b.memberId], b.netMinor]),
      );
      expect(balances).toEqual(s.expect.balances);
    });
  }
});

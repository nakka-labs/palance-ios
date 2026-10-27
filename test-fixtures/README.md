# Shared golden test fixtures

Language-neutral test vectors consumed by **both** implementations so they
can't drift. Two catalogues: `splits/` (form input → splits → balances,
written to be hand-authored) and `balances/` (ledger → balances → settle-up
plan). The balance vectors are consumed by:

- `PalanceKit` — `PalanceKitTests/GoldenParityTests.swift`
- `worker/` — `worker/test/logic.test.ts`

If you change `Balances`/`Simplify` in one language, the other's CI fails until
it matches (or until the fixture is deliberately updated).

## `balances/*.json`

```jsonc
{
  "name": "human-readable case name",
  "members":     [{ "id", "displayName" }],
  "expenses":    [{ "id", "payerId", "amountMinor", "currency", "description", "date",
                    "splitType": "equal" | "exact" | "percentage",
                    "splits": [{ "memberId", "amountMinor" }],
                    "category"?, "categoryIcon"?     // optional; ignored by the math
                  }],
  "settlements": [{ "id", "fromId", "toId", "amountMinor", "currency", "date" }],

  "expectedBalances":   [{ "memberId", "currency", "netMinor" }],
  "expectedSimplified": [{ "fromId", "toId", "amountMinor", "currency" }]
}
```

All amounts are integer minor units. `date` is ISO 8601 and does not affect the
math.

Balances and the settle-up plan are **partitioned by currency** — never blended
(no FX). `expectedBalances` lists only the (member, currency) pairs that net to
nonzero, ordered by currency in first-appearance order (across the combined
expenses-then-settlements stream) then `members` order; each currency bucket
sums to zero. `expectedSimplified` runs the greedy match once per currency and
concatenates in the same currency order.

`splitType` is only a label — `percentage` splits reach the ledger already
resolved to exact minor-unit shares (the client does the division, like
`equal`'s remainder), so the balance math is identical for all three types.

## `splits/*.json` — split scenarios (add your own)

One real-world expense per file, written the way a person would describe it.
`PalanceKit`'s `SplitScenarioTests` fills in the Add Expense form from it
(`ExpenseDraft`), resolves it, and checks the payers, splits, and balances;
`worker/test/splits.test.ts` checks the server accepts those exact payers and
splits and computes the same balances. **Work the expected numbers out by
hand** — copying them from the app's output would only test the app against
itself.

```jsonc
{
  "name": "Dinner for five, one skipped",            // shown as the test name
  "story": "Chen paid ₹2,000.02; everyone but Eli ate.",
  "members": ["asha", "ben", "chen", "dev", "eli"],  // group order — it matters
  "currency": "INR",
  "amount": "2000.02",                               // as typed; "12 + 8.50" works

  "paidBy": "chen",                                  // one payer, or instead:
  // "payers": { "asha": "60", "ben": "40" },        // several, as typed

  "split": { "type": "equal", "only": ["asha", "ben", "chen", "dev"] }
  //   "only" is optional — everyone is included by default
  // { "type": "exact",      "amounts":  { "asha": "70", "ben": "30" } }
  // { "type": "percentage", "percents": { "asha": "50", "ben": "50" } }
  // { "type": "shares",     "weights":  { "asha": "2",  "ben": "1"  } }
  // { "type": "itemized",   "items": [{ "name": "Pizza", "amount": "30", "for": ["asha", "ben"] }],
  //   "tax": "5", "tip": "2" }                      // tax/tip optional

  "expect": {                                        // integer paise (minor units)
    "payers":   { "chen": 200002 },
    "splits":   { "asha": 50000, "ben": 50000, "chen": 50002, "dev": 50000 },
    "balances": { "asha": -50000, "ben": -50000, "chen": 150000, "dev": -50000 }
  }                                                  // balances: nonzero members only
  // or, for input the app must refuse:  "expect": { "cannotSave": true }
}
```

Rules worth knowing when working numbers out: a leftover paisa from an
uneven division goes to the payer (with several payers, the one who paid
most; ties go to whoever is earlier in `members`), or — if the payer isn't
part of the split — to the first included member. Itemized tax/tip is
shared in proportion to what each person's items cost. Percentages must add
up to exactly 100.

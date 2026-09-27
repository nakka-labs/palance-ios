# Nakka-Labs — Dev Process Guide

> Status: the one file to read before starting (or resuming) any portfolio
> app's *engineering/agent-handoff process* — the execution-phase
> counterpart to `PLAN_BIBLE.md` (the planning-phase philosophy: brainstorm
> honestly, lock decisions, tag CLI vs. Owner work) and `DESIGN_BIBLE.md`
> (visual identity). Each repo's own `CHECKLIST.md` stays what's left/done
> on that app specifically. Lives in `palance-ios` for now, same reason the
> other two Bibles do — only connected repo, most advanced app — belongs
> at the portfolio level once a `nakka-labs` org repo exists.
>
> **Ratified: pending owner confirmation** (drafted 2026-09-17). Treat as
> binding once confirmed — this file follows its own P1: it's a process
> decision, and process decisions get an explicit owner sign-off before
> they're load-bearing, same as any `Dn`.
>
> **Reference it, don't copy it.** A copy in every app repo is exactly the
> doc-sprawl this file argues against in P2 — two copies drift the moment
> either gets edited and nobody notices. Until a shared repo exists, a new
> app repo's own `AGENTS.md` should point at this file by path
> (`../palance-ios/DEV_PROCESS.md` or the GitHub URL), not paste it in.
>
> Every rule below exists because it was learned the expensive way on
> Palance. Cited incidents are in that repo's own history/project memory —
> re-read them before arguing a rule is overkill.

## The pipeline

```
Idea → Cowork brainstorm (critical, D-labeled decisions)
     → Cowork writes CHECKLIST.md (F-labeled items, step-wise, token-budgeted)
     → CLI agent (Claude Code or Antigravity) executes one F-item at a time
     → Verification (real device/toolchain — see P5) before marking done
     → Owner-only steps flagged separately, not silently skipped
     → Back to Cowork only for the next decision point
```

Cowork/chat is for *thinking*: ideation, critical brainstorming, locking
decisions, writing the plan. The CLI agent is for *doing*: mechanical
execution against an already-decided checklist. Don't let Cowork drift
into writing code, and don't let a CLI session make an undocumented
design call mid-task — if it hits one, it stops and the decision comes
back to Cowork as a new `Dn`.

**Antigravity — open, not yet decided.** You run Antigravity and Claude
Code side by side on the same repos; this doc doesn't yet say which task
types go where. Pin this down before the next app starts, not mid-build —
P13 covers the concurrency risk in the meantime, but "which agent owns
what" is still an unmade `Dn`.

## Operating principles

`P1`–`P14` below are mechanics. This is *why* — read it when a situation
isn't covered by a specific rule.

- **O1 — Brutally honest, in both directions.** A Cowork brainstorm
  pushes back on the idea, not just the code. The same standard points
  back at you: if a request trades app quality for speed or optics, that
  gets said before it gets executed, not quietly complied with. Neither
  side gets a pass for being the one not holding the keyboard.
- **O2 — The app's actual interest is the tie-breaker.** When a call is
  ambiguous — ship now vs. verify first, patch vs. revert, add scope vs.
  hold the line — the answer is whichever serves the app real users will
  use, never whichever makes a session look more productive or a
  checklist look more complete. Padding `CHECKLIST.md` with busywork and
  marking something "done" to dodge an awkward "not actually verified
  yet" both fail this test.
- **O3 — Two failed attempts, then escalate.** If the same bug survives
  two fix attempts (P6), stop patching blind and take it back to
  Cowork/the owner with what was tried and why it didn't work. A third
  guess with no new information is how the delete-dialog regression
  happened the first time.

## P1 — Decisions get locked before code, and locked hard

Same rule as `PLAN_BIBLE.md` §1/§2 — restated here because it's the gate
this whole file's mechanics sit behind. Before writing a line of
implementation, run a *critical* brainstorm (not a rubber-stamp one) and
produce a short decision list: each item labeled `Dn`, a real yes/no plus
one-line why, no "TBD" left in as if it were settled. Palance's
monetization call (`D`: free, no IAP — 2026-09-10) is the model: it was
reasoned from the competitive set and the revenue math, not picked and
moved on from.

## P2 — One master checklist, not a doc per feature

Palance accumulated a dozen overlapping plan docs (see `CHECKLIST.md`'s
own header for the exact, authoritative list — don't re-copy that list
here, it'll drift the way this section's own doc-count already had:
three different numbers were floating across three files before this
sentence stopped restating one). All of them got deleted and merged into
one `CHECKLIST.md`. Start with the one file.
Technical contract goes in `DESIGN.md`, visual contract in
`DESIGN_BIBLE.md`, *what's left and what's done* goes in `CHECKLIST.md`
— nothing else gets a plan doc of its own.

The same discipline applies to anything a checklist item *points to*:
if `F7` says "see `docs/csv-import-formats.md`," that doc has to be
current at handoff time. If it's gone stale, the item says so explicitly
— never leave the next reader to trust a link that's quietly wrong.

## P3 — Checklist items are CLI-sized, not feature-sized

Each `CHECKLIST.md` item: a rough token budget, 2-4 concrete steps, sized
so one CLI turn can do it without holding the whole feature in its head.
Items needing a human (an account, a click, a decision only you can
make) get no token budget and get flagged as such — see `PLAN_BIBLE.md`
§4 for the CLI-vs-Owner distinction itself; this is just the token-budget
consequence of it.

## P4 — Every addressable thing gets a stable short ID

Decisions are `Dn`, checklist items are `Fn`, process rules are `Pn`,
operating principles are `On` (or reuse a repo's own scheme — Palance
already does this with `D9`–`D14` for open UX findings and `Track 1` for
domain-wiring steps). Assign the ID the first time something is written
down, never renumber it once anything else references it. This is what
lets you say "kill D14" or "redo F7" and have it land on the right thing
without re-describing it — worthless if IDs get reused or shuffled.

## P5 — Probe before you trust, then state how a claim was verified

Before running any check command, confirm the tool actually exists
(`which swift xcodegen gh …`) and say so — don't assume a shell has a
toolchain just because a previous session's did. That assumption is
exactly what produced the failures below. Cloud sessions working on
these repos generally have **no Swift/Xcode toolchain** in their shell
(confirmed: no `swift`, `xcodegen`, `gh`, and installing one is blocked
by sandbox egress). A commit or handoff note that says "make check
green" or "iOS build green" from a cloud session is a self-report, not
proof — `make check` runs through `.githooks/pre-push`, which needs the
real toolchain.

Rule: every verification claim states its method — `verified: real
device`, `verified: unit test only`, `unverified — logic re-implemented
in Python and checked by hand`, `unverified — hypothesis`. "Not yet
confirmed against a real device" is a flag to treat the fix as unproven,
not a footnote to skim past.

Concretely this happened twice on Palance: the Splid CSV-import fix
shipped with an honest "never compiled" caveat and a re-implementation
cross-check instead of a false "tests pass"; the Insights-tab removal
shipped grep-verified but build-unverified, correctly flagged as such.
Both are the right pattern — the failure mode this rule prevents is the
*unflagged* version.

## P6 — A plausible fix is not a confirmed fix (and isn't a reason to skip reverting)

Same-day churn on Palance (build 13 shipped an Insights tab fully broken;
a same-day "race condition" fix was marked as the cause without
confirming it against the actual reported bug; a delete-dialog fix broke
delete entirely on a real device and had to be reverted same day) came
from treating a fix that addresses a plausible cause as done. A fix stays
labeled a hypothesis until it's reproduced-then-fixed in the environment
that matters (real device, not simulator, when the bug was device-only).

When something shipped is actively broken for the owner *right now*,
revert first and re-diagnose second. Don't patch forward on top of a
live breakage hoping the next guess is the one that works — that's the
same ship→break→second-guess churn this rule already names. Reverting
buys the time to diagnose properly instead of compounding guesses in
production; see O3 for when to stop guessing entirely and escalate.

## P7 — Parse real files before writing a parser

The Splid CSV import shipped "working" against synthetic test cases and
failed on the first real export (wrong encoding assumption — UTF-16LE
with BOM, not UTF-8 — plus a rounding quirk only visible in real data,
~6% of rows off by 1 paisa). Any code that ingests outside-world input
(import formats, third-party API responses, user file uploads) needs at
least one real sample before the parser is called done, not just
hand-constructed fixtures.

## P8 — Token efficiency is a scheduling problem, not a prose problem

Front-load reading: one pass through the relevant docs (`DESIGN.md`,
`CHECKLIST.md`, this file) before opening any code. Hand the CLI agent a
self-contained prompt against a specific `Fn` item so it doesn't need a
back-and-forth to figure out scope. Keep Cowork/chat rounds for decisions
and review, not for narrating implementation the CLI already did — the
checklist item's own "done" writeup (P14) is what that's for.

## Agent-agnostic handoff

The goal: a checklist item written by Cowork should be pickable up by
Claude Code *or* Antigravity *or* whichever agent comes next, without a
human re-explaining state. That needs more than plain English — it needs
the handoff to not depend on either agent's own memory of the work.

- **P9 — One rules file, loaded by both.** `AGENTS.md` is the single
  source of truth for commands, architecture rules, and non-goals.
  Antigravity reads it natively. Claude Code only reads `CLAUDE.md` — so
  every repo needs a `CLAUDE.md` whose first line is `@AGENTS.md` (the
  official import syntax), nothing duplicated by hand. Without this file,
  Claude Code silently never sees `AGENTS.md` at all — confirmed missing
  in this repo until 2026-09-17, now fixed.
- **P10 — Watch the 12,000-character ceiling.** Antigravity caps a rules
  file at 12,000 characters and (as far as documented) truncates rather
  than erroring past it. `AGENTS.md` is ~7,750 chars now. Before adding a
  new Architecture Rule or Non-Goal, check `wc -c AGENTS.md`; past ~10,000
  chars, split the newest/least-referenced material into a linked doc
  (`DESIGN.md`, a new `docs/*.md`) instead of growing this file further.
- **P11 — State lives in git, not in an agent's head.** If an agent stops
  mid-item, the next agent (same tool or different) must be able to tell
  exactly where things stand from `git status` + `git diff` + the
  `CHECKLIST.md` checkbox alone — never from continuing a chat thread.
  Concretely: commit at resumable points instead of holding a whole
  feature uncommitted, and when you do stop with uncommitted changes,
  say so explicitly in the handoff note (P14) rather than leaving the
  next session to guess, the way `insights_tab_removal_flow_audit` had to
  flag "don't assume either state, check."
- **P12 — No tool-specific assumptions in a checklist item.** Verification
  steps are plain shell (`make check`, `swift test …`) that any agent
  with a terminal can run — never "use Claude Code's X skill" or an
  Antigravity-only feature inside a checklist item's steps. Keep those
  tool-specific conveniences in how *you* drive the session, not in what
  gets written down for the next one to read.
- **P13 — Don't run two agents on the same repo at once.** Side-by-side
  usage (Claude Code + Antigravity on the same codebase) is a sequential
  handoff pattern, not a parallel one — one agent works, commits or
  clearly flags its stopping state, then the next picks up. Concurrent
  edits on the same files from two agents is how you get silent conflicts
  neither one's diff view will explain.
- **P14 — End every session with a handoff note, not just a commit.** One
  short paragraph per touched checklist item: what changed, how it was
  verified (P5) and by what method, git state (committed vs. still
  dirty), and the next concrete step. This is exactly the pattern already
  used in this project's own retrospective notes (`csv_import_splid_fix`,
  `insights_tab_removal_flow_audit`) — formalize it as a habit for every
  session, not just the ones that happened to get written up afterward.

- Cloud `device_bash` sessions can't `rm`/`unlink` files in a connected
  folder — including git's own lock/tmp files — until the owner grants
  delete permission for that session, and that grant only reaches the
  owner as a real prompt while they're actively present; requesting it
  while they're away gets auto-declined outright. A stale `.git/index.lock`
  from an interrupted commit will keep blocking every future commit until
  someone with the toolchain (or a present owner granting delete
  permission) clears it — confirmed 2026-09-17 after 15+ stale
  `index.lock.bak*` files had piled up silently since 2026-09-05. `mv`
  (rename) works without the grant as a stopgap; it just doesn't clean
  anything up.

## Known toolchain gaps (update as they change)

- No Swift/Xcode/xcodegen/gh on the cloud `device_bash` shell for this
  repo — anything needing a real compile or `make check` runs on the
  actual Mac (owner's terminal, or full computer control), not from here.

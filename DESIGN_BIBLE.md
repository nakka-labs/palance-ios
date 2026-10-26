# Nakka-Labs — Design Bible

> Status: the one file to read before starting any new app's visual
> identity. Replaces `DESIGN_LANGUAGE.md` (same content, consolidated and
> tightened). Lives in `palance-ios` for now since it's the only connected
> repo and the most advanced app; belongs at the portfolio level (a
> `nakka-labs` org profile repo, or `tiny-tools`'s shared design system)
> once one of those exists. Every rule below is portfolio-wide — decided
> once, applied to all four apps — even though only Palance is built out
> enough to show it yet.
>
> For a minimalist, flat, system-font portfolio, almost everything below
> reduces to two decisions: **the font treatment** (§1) and **the color
> formula** (§2). Everything after that is reinforcement, not identity.
> A visual reference canvas applying all of this to all four apps exists
> at https://claude.ai/code/artifact/ef84d6ca-6134-448a-b057-9127197e2df7
> — optional, not required reading; this file is the source of truth.

## Why a shared language, not shared assets

Native iOS apps (Palance, LoopTimer, Habit Tracker) can't literally share
a font bundle or component library across separate Xcode projects without
real plumbing, and the PWAs in `tiny-tools` already have their own shared
design system per the stack decision. What *can* be shared for free is a
small set of construction rules applied consistently per-repo — the same
reason Apple's own first-party apps look related without sharing pixels.

## 1. Typography — the identity

System fonts only for body text and chrome: SF Pro (iOS) / system-ui or
Inter (web). Zero cost, zero maintenance, no bundling or licensing for
the 95% of the UI that's reading, not signature.

One deliberate, portfolio-wide exception — the single highest-leverage
move in this document: a **distinct display typeface**, used only for
each app's wordmark and its hero numerals (Palance's Insights total and
recap card, LoopTimer's countdown, Habit Tracker's streak count,
PitchLab's detected pitch). Free and self-hosted (a Google Fonts family,
not a paid license), same face across all four apps so it reads as one
portfolio's signature rather than four unrelated choices. (Palance's
Group Home balance is the one carve-out: Space Grotesk's ₹ and geometric
digits read a touch calculator-ish there, so it stays on SF Rounded —
an owner call, revisit if the face changes.) This supersedes the earlier "`ui-rounded` (SF
Rounded) for hero numerals" rule — same instinct (numbers-first apps
deserve a felt signature), stronger execution: a genuinely distinct face
reads as designed, where a system font at a different weight reads as a
tweak. Touches nothing else — not body text, not chrome, not iconography.

**Number formatting is part of the signature, not an afterthought.**
Every hero numeral uses tabular (fixed-width, non-proportional) figures —
so a value that updates in place doesn't jiggle the layout around it —
and one consistent thousands-separator/decimal style across all four
apps. Cheap (a font-feature flag, not new design work) and it's the kind
of detail that reads as "an app, not a tutorial project" the moment a
number changes on screen.

## 2. Color — one formula, one hue per app

`oklch(55% 0.16 H)` — lightness and chroma fixed, hue (`H`) varies per
app. Current assignments: **Palance** 250 (blue), **LoopTimer** 35
(orange), **Habit Tracker** 150 (green), **PitchLab** 305 (magenta).
Picking a hue for the next app: use the same formula, pick whichever
unused hue angle best fits that app's feel — don't eyeball a new color
from scratch. That's it; this isn't a bigger system than that.

The same construction generalizes past app-level branding: within an app
that has many like things a person needs to tell apart at a glance, hash a
stable identifier to a hue and reuse the formula at a different
lightness/chroma band per use, rather than hand-picking colors one at a
time. Palance's per-category colors (`CategoryColor`, pastel band) and
per-member identity colors (`MemberColor`, a higher-chroma band) are the
same formula at two bands, not two separate systems — treat any future
"N things need distinct colors" problem in any app the same way before
reaching for anything hand-picked.

**Surfaces sit on a short elevation scale, not two flat tones.** One
named set of greys — recessed *well* → *canvas* → *card* → *raised* —
resolved per light/dark, rather than scattered `secondary.opacity(…)`
guesses. Palance's is `App/Palance/Surface.swift`.

**Neutrals are tinted, never pure greyscale.** Body text, chrome, and
those surface tones mix in a little of the app's own hue rather than
sitting at true `oklch(L% 0 0)` grey. The same trick Linear/Arc use to
make a "monochrome" UI not read as a default system theme — barely
perceptible on its own, felt as soon as it's missing. Palance's
`Surface.swift` tiers carry a fixed `chroma 0.007` at 250° (about 4% of
the accent's `0.16` — the "10-15% of the hue" figure clips ugly at the
near-white tiers, so it landed lower); the brightest light tiers are
pulled just off pure white so the tint has room to show. System
semantic text colours (`.secondary` etc.) are left alone — tinting
those app-wide fights the system controls they sit beside.

## 3. App icons

Flat, geometric, single strong silhouette, legible at 40px, no baked-in
text, no photoreal, no drop shadow/3D bevel. One deliberate, portfolio-
wide exception: a tasteful two-stop gradient using the app's own hue
(§2) at two points on the same lightness/chroma formula — never a second,
unrelated color — scoped to the app icon itself and to in-app hero
moments that leave the app as an image (Palance's shareable recap
card), never to in-app UI — flat color everywhere on screen (§9 rule 1,
narrowed 2026-10-26; this used to also cover Palance's balance hero
card). What varies per app is the **motif** (what the shape is) and
whether that app leans on the gradient or stays fully flat — never the
construction style itself, and never more than the one gradient per icon.

**Generation workflow** (the same process for every app's icon — only the
concept/motif changes per app):

> A minimalist, flat vector app icon for "[App Name]," a [one-line app
> description]. Concept: [the app-specific motif — a single strong,
> literal-but-not-clichéd shape tied to what the app does]. Two-tone (or,
> where the gradient exception above is used, two-stop-gradient) palette
> built from the app's own `oklch(55% 0.16 H)` hue — a confident
> background with a crisp light mark. No gradients beyond the one
> sanctioned stop-pair, no drop shadows, no 3D bevel, no photorealism, no
> text or letters. Square 1024×1024 canvas, full-bleed flat background, no
> transparency (a transparent icon is an App Store rejection), no rounded
> corners baked in (iOS applies its own mask). Generous padding,
> confident negative space, single strong silhouette that reads clearly
> at 60×60px. Style reference: modern iOS utility-app icons (Things 3,
> Bear, Fantastical) — clean, geometric, not cartoonish, not
> generic-fintech/generic-utility. Avoid whatever's overused in that
> app's specific category (for Palance: dollar signs, piggy banks,
> wallets, scales/balance-beams, pie charts, overlapping-people icons).

Palance's own instance of this, kept as the worked example: a bold
geometric equals sign ("="), evolving the app's placeholder icon and
established blue, symbolizing settling a balance rather than money
itself. The background is this app's instance of the sanctioned two-stop
gradient — `oklch(60% 0.15 250)` at the top to `oklch(40% 0.14 250)` at
the bottom, interpolated in OKLCH so the midtones stay on-hue — the same
stop-pair as the in-app hero moments (`RecapCard.brandGradient`). Crisp
near-white mark (`#FAFBFD`). Alternate motifs considered: a tab/flag
shape split down the center (literal "clan tab"), or three dots
converging into one line (small-group-settling-into-one). Regenerated
by `docs/branding/make-app-icon.py` (geometry frozen from the prior flat
icon); installed at
`App/Palance/Assets.xcassets/AppIcon.appiconset/icon-1024.png`.

**Distinctiveness check** (run before finalizing any app's icon — not
just eyeballing it next to a couple of competitors):

1. **Visual competitor survey.** Pull current App Store icons for the
   category's real players (for Palance: Splitwise, Settle Up, Tricount,
   Spliit, Kittysplit, plus adjacent fintech — Venmo, Cash App, PayPal).
   Verify live; icons refresh over time. The bar is a distinct *shape*,
   not a distinct *color* — a shared hue family (most fintech sits in
   blue/green/purple) is common territory in every category.
2. **Reverse image search** each generated candidate (Google Lens or
   TinEye) before finalizing — catches an accidental near-duplicate the
   model pulled from training data, more common than expected with
   generic "minimalist flat icon" prompts.
3. **Trademark search** — USPTO TESS / TMview for design marks in
   software/financial-app classes (9, 36, 42) that could read as
   confusingly similar. Real legal exposure, separate from "looks kind of
   alike."
4. **Small-size confusability test — the actual bar.** Render the
   candidate at real iOS sizes (180/120/60/40px) next to 3-4 competitor
   icons at the same size, on both light and dark home screens. A
   full-size side-by-side is the wrong test — nobody sees the icon at
   full size except the person picking it, once, at generation time.

Palance's own check: legibility re-confirmed at 180/120/60/40px on light
and dark after the gradient was added — the "=" stays crisp, the
gradient reads as subtle depth, not muddiness. The motif is unchanged
from the flat version, so the shape-distinctiveness reasoning carries
over (a bold "=" is distinct from Splitwise's split-S, Settle Up,
Tricount, Venmo, Cash App, PayPal — all a different mark; shared blue
hue is common category territory). Reverse-image and trademark search
still need tools this environment doesn't have (Google Lens/TinEye,
USPTO TESS) — run those before submitting to the App Store.

## 4. In-app iconography — SF Symbols only, with one named exception

No custom icon sets, ever, for *functional* UI: buttons, nav, category
glyphs — all SF Symbols. Free, automatically themed, automatically
Dynamic-Type- and VoiceOver-correct. Not really a brand choice — a "don't
reinvent free infrastructure" rule, stated so nobody reaches for a custom
icon pack mid-project.

One deliberate, portfolio-wide exception: a single custom empty-state
illustration per app, reused everywhere that app shows a genuine
zero-state (Palance's "no groups yet" / "no expenses yet"; the equivalent
first-run zero-state in each other app). One asset per app, not per
screen or per state — this is a branding moment (the first thing a new
user sees), not functional chrome, so it sits outside the
infrastructure-reuse reasoning above rather than contradicting it.

Palance's own instance: an empty rounded "tab" (outline, not filled —
nothing in it yet) holding the app's "=" mark. A template image
(`EmptyStateGlyph`, generated by `docs/branding/make-empty-state.py`),
tinted `.secondary` so it themes automatically. Shared across every
genuine "nothing here yet" state — no groups, no expenses, nothing to
chart, no recurring reminders, empty bin. The transient/positive
outcome states ("Nothing Matches" on a filtered feed, "All Square" on
Settle Across Groups) keep a plain SF Symbol — they aren't zero-state
branding moments.

## 5. Motion & sound — confirm, don't decorate

A light haptic on every state-confirming action (a timer completing, a
habit checked off, an expense settled), never on navigation or routine
taps — Palance's existing `.sensoryFeedback` pattern, made the portfolio
rule. Cheap, consistent, and a felt quality signal even to someone who
never consciously registers the shared icon construction rule.

One deliberate, portfolio-wide addition: a short, custom confirmation
sound, played alongside the haptic — never instead of it, so the silent-
switch/Do Not Disturb case still gets a correct confirmation — on the
single most significant confirming action per app (Palance: settled up;
LoopTimer: timer complete; Habit Tracker: streak milestone; PitchLab:
pitch matched). One sound design, reused across all four apps at the same
moment-class, not a bespoke sound per app — same instinct as the color
formula: one system, applied consistently, rather than four separate
creative decisions.

Palance's own instance: `settled.caf` — a short rising perfect fifth
(C6→G6) on a gentle exponential decay, peak ~0.32 so it sits under
speech, ~0.35s of audible content. Synthesised by
`docs/branding/make-confirmation-sound.py` (16-bit mono → `afconvert` to
`.caf`). Played via `ConfirmationSound.play()` (`AudioServicesPlaySystemSound`,
so it honours the ring/silent switch) in `SettleUpView`'s "Mark as Paid"
handler, alongside the existing `.sensoryFeedback(.success)` haptic —
never the add-expense confirm, only settling up.

**One named spring curve for every confirm-moment transition.** A single
response/dampingFraction pair (name it — e.g. the "`.claimSettle`
spring") reused for every matched-geometry/spring-based transition tied
to a confirming action, across all four apps, the same way the haptic and
sound are one system rather than four. A shared *feel*, not just a shared
rule — the thing that makes four different apps register as the same
hand having built them.

Palance's own instance: `Animation.claimSettle` in `App/Palance/Motion.swift`
— `spring(response: 0.4, dampingFraction: 0.85)`, settled with a touch of
give. Applied to the delete/undo toast on Group Home; the next
confirm-moment transitions to land (a settle-up animation, the deferred
open-a-group hero) use it in place of `.default`.

## 6. Naming

Short, compound, coined names. No articles, no punctuation, hints at
function: Palance, LoopTimer, PitchLab. "Habit Tracker" is the current
outlier — two literal words, not a coined compound. Not urgent enough to
force a rename; worth keeping in mind on that app's next polish pass.

## 7. Portfolio credit, in-app

A small, consistent "Nakka-Labs" line on each app's Settings/About
screen only — never on the icon, never on primary UI.

## 8. README / repo presentation

The goal is a hiring portfolio, not app-store growth — README structural
consistency across repos is probably higher-leverage than in-app pixel
consistency. Same section order in every repo: badges → screenshots
table → architecture diagram → tech stack table. Same screenshot device
frame and background, same mermaid diagram style. Someone clicking
through 3-4 of these repos in one sitting notices structure before they
notice whether two accent blues are the exact same hex.

## 9. Restraint — how a screen is built

> **Approved by the owner 2026-10-26** (all four open calls taken as
> drafted: flat hero, carousel → rows, plain destructive rows, profile
> cover band). Applied screen by screen per `CHECKLIST.md` "Ground-up
> rename" → visual identity pass — exemplar batch first. Written against the current build's
> Group Home, Settings, and Member Profile, with a competitor's flat,
> low-density screens as the reference for *restraint* — not for layout,
> not for color, and not copied.

§1-§8 say what the pieces are. This section says how few of them a screen
gets to use at once. The current app's problem isn't any single wrong
choice — it's that every screen spends a little of everything: a gradient
here, a glow shadow there, a tinted icon, a blue text button, a caption
under a row. Each was reasonable alone; together they read as busy.
Restraint is a budget, not a style.

**1. One focal point per screen, and it's flat.** Each screen has at most
one thing that's visually louder than a list row (Group Home: the
balance; Member Profile: the person; Settings: nothing). That focal
surface is a flat fill — `Surface.raised` or the group's accent at a
low-chroma band of the §2 formula — with no gradient wash, no pattern,
and no shadow. This narrows §3's gradient exception to the app icon and
the shareable recap card only (an exported image, not in-app chrome);
the Group Home balance hero loses its wash and glow.

**2. Elevation only for things that float.** Shadows belong to what
genuinely sits above the content — a toast, a floating button, a sheet.
Nothing in the scrolling flow gets a shadow or a custom card shape; the
system list/form grouping is the only container.

**3. A four-step type scale, and nothing between.**

| Role | Style | Used for |
|---|---|---|
| Hero | SF Rounded 28 bold, tabular (§1) | the one focal number |
| Title | `.title2` semibold | the screen's subject (a person's name, a group's name) — once per screen |
| Body | `.body` | every row label and row value |
| Secondary | `.subheadline` / `.footnote`, `.secondary` | labels *above* a hero number, section footers, timestamps |

No `.title3`, no semibold body, no ad-hoc point sizes in screen code. The
label above a hero number is *smaller* than body, not bigger — "You owe"
whispers, the amount speaks.

**4. The row standard — one shape for every menu-like row.** A leading
SF Symbol in a fixed 28pt frame, monochrome `.secondary` (never
accent-tinted, never multicolor); a `.body` label; an optional trailing
value in `.secondary`; a chevron if it navigates. Actions are rows of the
same shape, not bare blue text buttons floating in a form. Every row on a
menu-like screen has an icon, or none do — never a mix.

**5. Key-value rows for facts.** Facts about a thing (a member's UPI ID,
a group's currency, the app version) are label-left (`.secondary`),
value-right (`.primary`), one per row, hairline-separated. No icon, no
caption beneath.

**6. Color is spent on meaning only.**
- The accent appears on at most: the one primary action on the screen,
  selected/active states, and navigation tint.
- Green/red appear only on money amounts — never on labels, icons, or
  headers ("Danger Zone" doesn't get a red header; see 8). Two
  exceptions, both meaning rather than decoration: a destructive
  action's label (8, `RowLabelStyle`'s `.destructiveRow`) and error
  messages.
- Member identity colors (§2) appear only on avatars/initials.

**7. One fact per row; explanations go in footers.** A row never carries
a stacked caption. If a row needs explaining, the explanation is the
section's footer, written once. Feed rows (an activity item, a
comment, a reminder) are content, not menu rows: they may carry one
Secondary line of *who/when/what* — never an explanation.

**8. Destructive actions: last, plain, red label.** The final section of
the screen, a single row whose label is red, with the consequence in
that section's footer and the real friction in the confirmation dialog —
not in a red header, an icon badge, or a custom "danger" row component.
(This replaces `DangerZoneRow`'s treatment in both `SettingsView` and
`GroupSettingsView` — UX audit fresh-eyes [3]
added it to give Delete Account more weight than a bare red link; the
dialog and the footer carry that weight now, without the chrome.)

**9. The profile layout.** A member's (or your own) profile is:
full-width cover band at the top — their photo if they have one,
otherwise a flat fill in their member color with large initials — then
their name as the screen's Title, then plain key-value and row-standard
sections. No avatar-plus-name header card, no floating circle over a
banner.

### What this changes on the exemplar screens

| Screen | Today | Under §9 |
|---|---|---|
| Group Home hero (`BalanceHeroView`) | raised card, group gradient wash, accent glow shadow, `.title3` semibold label | flat fill, no shadow; label drops to Secondary; Settle Up stays as the one accent action inside it |
| Group Home hero carousel | a 3-page swipe `TabView` (hero → bubbles → Insights preview card) with page dots, a permanent chevron, and a coach mark to make the swipe discoverable | the hero stands alone; bubbles and Insights become two row-standard rows directly below it ("Who Owes Whom", "Spending Insights"), each opening its own screen/sheet; the page dots, chevron, and coach mark go |
| Balance bubbles (`BalanceBubbleView`) | stays — it's data, not decoration | money labels follow 3 (no 9pt text); only member colors on the circles |
| Settings | mixed rows: an icon'd status line, an avatar row, blue text buttons, a Danger Zone header with a caption row | your profile as a row at the top (avatar + name → your profile screen); every other row follows 4; Delete Account per 8 |
| Member Profile | 56pt avatar + name in a header row, colored balance section | cover band + Title per 9; balance as key-value rows (amounts keep green/red per 6) |

### What this does *not* change

§1's display face, §2's color formula and `Surface` tiers, §4's SF
Symbols rule, §5's motion/sound — all stand. This section only limits
how much of them any one screen spends.

### Review checklist (per screen, before it ships)

- [ ] At most one focal surface, flat, no shadow.
- [ ] Only the four type roles; no ad-hoc sizes.
- [ ] Every menu-like row follows the row standard; no bare text buttons.
- [ ] Accent used only for the primary action / selection / nav.
- [ ] Green/red only on money.
- [ ] No captions under rows; explanations in footers.
- [ ] Destructive action last, plain red label, consequence in footer.
- [ ] Light + dark + largest Dynamic Type checked.

## Explicitly not doing (yet)

- No shared component library or design-token file across native repos —
  premature before a second native app is actively being built alongside
  Palance.
- No paid or licensed fonts — the §1 display face and all system fonts
  stay free.
- No design-tool subscription, no re-running a visual design tool to
  illustrate a decision this file already states in words.

## When to actually reach for a design tool again

Only when there's a genuinely *open* visual question — prototyping a
real screen's layout, choosing between actually different directions for
something new. Not to re-illustrate a rule that's already settled here in
one sentence. Read this file, pick the numbers §1-§2 give you, build.

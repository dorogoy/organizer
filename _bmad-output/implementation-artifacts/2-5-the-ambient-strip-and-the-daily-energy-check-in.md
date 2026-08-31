---
title: 'The ambient strip and the daily energy check-in'
type: 'feature'
created: '2026-08-31'
status: 'done'
review_loop_iteration: 0
baseline_commit: '9e9770a08646744d89edfedf243ad22fcfe25e7d'
context: ['FR-4', 'FR-10', 'UX-DR4', 'UX-DR9', 'UX-DR20', 'UX-DR22', 'UX-DR41', 'AD-3', 'AD-4', 'AD-6', 'AD-23', 'NFR5']
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** FR-4's check-in has no surface and no storage: `energy_set` does not exist, `deriveLivePoolEnergy` still reads `const []` (energy.dart:86-87), low energy only drops the Focus Chunk while 3-min upkeep still deals (weave.dart:309-317, 526-529), and the `ambient-strip` — the surface every future ambient ask lives in — does not exist anywhere.

**Approach:** Land the `energy_set` kind (tenth, new nullable column, schema v4) with a single minter command; map stored rows at the one seam energy.dart:80-87 already reserves; add the low-energy admission (estimate ≤ 60 s) inside `_resolveDay` so every consumer inherits it; and build the strip in `core/derive` (resident precedence, check-in eligibility) plus its shell surface below the card — three `BatteryGlyph` taps, ✕ dismissal, bare chrome.

## Boundaries & Constraints

**Always:**
- The strip sits below the `dispenser-card` inside `_frame`'s scroll region: sentence in support type and ink-secondary, at most one resident visible, ✕ dismissal at 48dp, tappable where an accept action exists and never a primary action; the check-in is bare (ephemeral resident, UX-DR22).
- The check-in carries `energyCheckInQuestion` verbatim (pre-seeded, app_es.arb:281-284) with three battery marks as direct tap targets and nothing else; llena pre-marked selected; selected = `icon-mass-blue` charge + `ink-primary` casing, unselected neutral/secondary — `BatteryGlyph` already implements all of it (battery_glyph.dart).
- Energy stays day-scoped per the existing derivation: last `energy_set` of the current day in each row's own offset, defaulting llena at each boundary, derived never written — no synthetic rows, no decay.
- Only baja narrows: admission is `estimateSeconds <= lowEnergyMaxEstimateSeconds` (60) applied inside `_resolveDay`'s draw lists/admission so `nextDeal`, `composeDay` and `dealExistsIgnoringPocket` cannot drift; the standing unanswered card is never withdrawn — the filter applies to the next deal (FR-4/FR-10 grammar).
- Check-in eligibility is pure over the log: due iff no `energy_set` row in the current day AND the day's first opening is underway — no `app_opened` row in today (the crossing case, whose next resolution is the crossed-into day's first opening), or exactly one `app_opened` that is the day's earliest row with no unended prior-day `session_started` (the kill-during-crossing marker). Answered or dismissed, gone for the day; a dismissal writes nothing and lives in shell state until the opening ends.
- Writes: one `energy_set` row per tap through the single sanctioned minter (`setting_changed`'s shape — pure, no log read, refusal is silence); instants minted in the shell at entry; the check-in never deals a card.
- The kind and column land additively (AD-23): schema v4 by ALTER TABLE only, stable level ints 0/1/2 pinned by test; absent or out-of-range `energy_level` excludes the row at the read boundary.
- The precedence derivation lives in `core/derive` (AD-6 carve-out, `warmReturnDue`/checkpoint precedent): one ordered resident list — first-run curation, quarantine follow-up, seasonal suggestion, snowball, weekly self-report, check-in; ties by earliest-eligible instant then stable id — with the check-in as the only implemented resident, and it defines no item-window predicate (AD-24's `EligibleDay` monopoly untouched).
- Census/proofs land with the kind: freeze `EnergySetEntry` + the `LogEntryRecord`/`LogEntryContent` growth, a mint-site family on the setting_changed template, shell census append-sites 5→6, `bannedWireNames` += `energy_set`, `energySet` invocation pinned ×1.
- Four new ARB keys (llena/media/baja labels + the ✕ label) with `Semantics(button/selected + label)` per the ladder-pill precedent (dispenser_screen.dart:839-845).

**Ask First:** The first-opening predicate and the dismissal-as-shell-state reading have no verbatim upstream pin — FR-4 says "first opening" but never in log terms — they land as code-doc plus this record, and a spine edit to host them is the human's call (2.4's precedent). The four ARB additions + semantics labels knowingly extend the interim no-custom-semantics convention (UX-DR48 [OPEN]).

**Never:** No energy control outside the strip — no mid-session relief (Rescue Mode's, Epic 4) and nothing displays the level after the strip leaves (the narrower deal is the display); no media/baja filter marker, no pending styling, no nag. No new facade functions (pinned single-function, facade_test.dart:599-615). No Timer, scheduled write or wall-clock in core; no decay toward media. No Settings row or `setting_changed` key for energy. No self-report surface or other residents (2.6/Epics 5-7 add them as data); no rescue/purge special-casing (their ≤ 60 s steps pass the estimate filter by construction). No golden tests.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Behavior | Error Handling |
|----------|---------------|-------------------|-----------------|
| First opening, unanswered | day's first read, no `energy_set` today | check-in resident below the card, llena pre-marked | N/A |
| Tap baja, card in progress | standing unanswered card | card stays finishable; one `energy_set{low}` row; next deal instant-tier only | N/A |
| Tap media / tap llena explicitly | any | one row lands; pool unchanged (media filters nothing); strip gone for the day | N/A |
| ✕ dismissal | check-in visible | no write; strip hidden for the rest of the opening; later openings hidden by the derivation | N/A |
| Re-open same day | second `app_opened` row today | not due — never re-shown, never styled as pending | N/A |
| Session crossing 04:00 | no `app_opened` row in the crossed-into day | the next strip resolution after the boundary is that day's first opening — shown once if unresolved | N/A |
| Crossing ended, then return | rows precede today's `app_opened`, or a prior-day session dangles unended | not due — the first opening was consumed | N/A |
| Day boundary | yesterday's `energy_set` only | level defaults llena; no synthetic row; check-in due again | N/A |
| Corrupt row | `energy_level` absent/out-of-range | row excluded at the read boundary; day derives as unanswered, level defaults | quiet |
| Failing append | store throws on `setEnergy` | nothing lands; strip stands; queue recovers (declare precedent) | quiet |
| Low-energy pool | maintenance 180 s / focus 900 s / instant 30 s candidates | instant-tier only across `nextDeal`, `composeDay`, the probe | N/A |
| Low-energy close-continue | pocket elapsed on a baja day | `Quiero seguir` offered only while an instant-tier deal exists | N/A |
| 200% font scale | strip with question + three marks + ✕ | grows and scrolls, nothing truncated, targets ≥ 48dp | N/A |

</frozen-after-approval>

## Code Map

- `packages/core/lib/energy/energy.dart:80-87` -- the one seam: `deriveLivePoolEnergy` gains the entries input, maps `EnergySetEntry`→`EnergyObservation`; renegotiate the "Story 2.5's" doc lines (:5-11); derivation itself (:55-78) untouched
- `packages/core/lib/log/log_entry.dart:36-57,242-252,257-301,333-509` -- tenth kind `energySet` + `EnergySetEntry{kind, level}`; flaw `energyLevelAbsent`; stable int mapping; parse/convert + classifiers (a known kind the boundary cannot classify is dropped, :273-278 — extend in the same pass); 2-4's additive pattern :167-193
- `packages/core/lib/ports/store_port.dart:39-50` + `lib/store/substrate.dart:24-49` + `lib/store/drift_store.dart:41-108` -- nullable `energy_level INTEGER NULL` column, schemaVersion 4 by ALTER TABLE (v2/v3 pattern), `Value(...)` insert + `asNameMap` decode
- `packages/core/lib/commands/energy_commands.dart` (new) -- `energySet({required EnergyLevel level})` → one `LogEntryContent`; shape precedent `lib/.../settings_commands.dart:29-49`; `LogEntryContent` typedef grows the column (session_commands.dart:66-74)
- `packages/core/lib/weave/weave.dart:47-52,309-317,335-410,422-491,550-572` -- `lowEnergyMaxEstimateSeconds = 60` beside `focusChunkLeastBagMinutes`; the low-energy admission inside `_resolveDay` (draw lists + admission closure, `pocketAllows` composition :377-390); `_chunkComposes` already drops the chunk at low
- Seam threading (mechanical, log already in scope): `packages/core/lib/commands/session_commands.dart:160,278,426` + `packages/core/lib/facade/read_facade.dart:58` + `lib/dispenser/dispenser_controller.dart:140-143,171-174`
- `packages/core/lib/derive/strip.dart` (new) + `read_facade.dart:1-10` arrival line -- resident precedence (ordered list, tie rules) + check-in eligibility; structural template `derive/checkpoint.dart`; NOT an `EligibleDay` window predicate (ARCHITECTURE-SPINE.md:207)
- `lib/dispenser/dispenser_controller.dart:22-68,122-188,288-317` -- strip state rides `read()`'s queue-consistent snapshot (base-class field on the sealed `DispenserView`, the pocketMinutes precedent); `setEnergy` in `declarePocket`'s write-then-read-back shape; dismissal state keyed by (day, opening marker)
- `lib/ui/dispenser/ambient_strip.dart` (new) -- the strip + check-in resident: question sentence (support role = `bodySmall`, ack precedent dispenser_screen.dart:689-706), three `BatteryGlyph` taps at 48dp (`lib/ui/glyphs/battery_glyph.dart` — complete, tested), ✕ as an inline line-only painter at 48dp (not a glyph-set member), bare chrome
- `lib/ui/dispenser/dispenser_screen.dart:352-416,771-797` -- mount below the view inside `_frame`; short-surface floor inherited; `SecondaryTextAction` grammar reference `task_card.dart:90-124`
- `lib/l10n/app_es.arb:281-284` + `make codegen` -- READ ONLY for `energyCheckInQuestion`; add the four keys (level labels + ✕ label) with descriptions
- Core tests: `packages/core/test/log_test.dart:29-53,530-595` (ten kinds + energy payload group), `energy_test.dart` (seam mapping), `strip_test.dart` (new — every matrix row above), `weave_test.dart:1154-1183` (low filter flips to instant-only; standing-card pin), `energy_commands_test.dart` (new), `no_lateness_proof_test.dart:809-848,886-944,1161-1248` (freezes + census + mint-site family), `test/store/substrate_test.dart` (v4 pins)
- Shell tests: `test/no_lateness_proof_test.dart:195-208,321-344` (census 5→6, wire name, `energySet` ×1), `test/dispenser/dispenser_controller_test.dart` + `test/ui/dispenser/` (reuse `_RecordingStore`, `_FailNextAppendStore`, `launchAndCommit`, `_fixedClock`, `_censusOf`; screen pins: question via `find.text`, three marks, tap→row→re-deal, ✕ hides within opening, 200% floor)

## Tasks & Acceptance

**Execution:**
- [x] `packages/core/lib/log/log_entry.dart` + `packages/core/lib/ports/store_port.dart` + `lib/store/substrate.dart` + `lib/store/drift_store.dart` -- tenth kind, `EnergySetEntry`, nullable column, schema v4 -- additive (AD-23)
- [x] `packages/core/lib/energy/energy.dart` -- the seam maps stored rows; the six call sites thread the log -- one seam, never per-caller
- [x] `packages/core/lib/commands/energy_commands.dart` (new) -- the single minter; refusal is silence
- [x] `packages/core/lib/weave/weave.dart` -- the 60 s low-energy admission inside `_resolveDay` -- every consumer inherits it (FR-4)
- [x] `packages/core/lib/derive/strip.dart` (new) + `read_facade.dart` doc -- precedence order + check-in eligibility
- [x] Core tests (`log_test`, `energy_test`, `strip_test` new, `weave_test`, `energy_commands_test` new, `no_lateness_proof_test`, `substrate_test`) -- every matrix row, the ten-kind pin, freezes, census, mint-site family
- [x] `lib/l10n/app_es.arb` + codegen -- four keys with descriptions
- [x] `lib/dispenser/dispenser_controller.dart` -- `setEnergy` + strip state in `read()` + dismissal state
- [x] `lib/ui/dispenser/ambient_strip.dart` (new) + `dispenser_screen.dart` -- the strip surface below the card (UX-DR20/22)
- [x] `test/no_lateness_proof_test.dart` + `test/dispenser/dispenser_controller_test.dart` + `test/ui/dispenser/` -- census, controller matrix, screen flows, 200% floor

**Acceptance Criteria:**
- Given the day's first opening with no `energy_set` row, when the strip resolves, then the check-in is the resident — question verbatim, three direct taps, llena pre-marked — and no second resident can be visible (UX-DR22)
- Given a tap on any mark, when the write lands, then exactly one `energy_set` row exists from this surface, the strip is gone for the day, and on baja the next deal is instant-tier only while a card in progress stays finishable (FR-4)
- Given the check-in answered or dismissed, when any later same-day resolution runs, then it does not reappear — and a session crossing 04:00 makes the next resolution the crossed-into day's first opening, shown once if unresolved (FR-4)
- Given any day boundary, when energy derives, then it defaults llena with no synthetic row, and nothing outside the strip displays or sets the level (FR-4, AD-4)
- Given more than one resident eligible at one opening, when the strip resolves, then the one total precedence order decides and a displaced resident is neither consumed nor dismissed (UX-DR22 — exercised as data, one resident implemented)
- Given the completion gate, then `make codegen-check`, `make check`, `make test-core` and `make gate` are green

## Design Notes

- **Why estimate-based, not size-based.** With today's catalogue ≤ 60 s ≡ `Size.instant`, but FR-5's rescue steps (≤ 60 s) and Epic 6's purge steps must stay eligible on a baja day — an estimate threshold admits them by construction, exactly the epic's cross-dependency line.
- **Why the first-opening predicate has three clauses.** `app_opened` rows are the only opening delimiters (every departure+return appends one; a pause never does). "No `app_opened` today" is the crossing case the AC names; "exactly one and it is the day's earliest row" separates a true first open from a return-after-crossing (whose earlier rows — a departure's `session_ended`, crossing card acts — betray the consumed opening); "no unended prior-day `session_started`" catches the one remaining liar: a kill during a crossing opening that left zero rows in today. A day that still loses its check-in to an unresolvable edge owes nothing — the llena default carries it (FR-4's own clause).
- **Why dismissal writes nothing.** AD-21's vocabulary has no dismissal kind and a synthetic `energy_set` is forbidden; within the opening, shell state hides it; across openings, the predicate above already has. The strip renders, it never writes (AD-3).
- **Why schema v4.** Unlike 2-4's column reuse, no existing payload column can carry a level (`pocketMinutes`/setting columns trip their flaws, log_entry.dart:288-300) — one new nullable column on the v2/v3 ALTER pattern is the sealed store's only additive path.

## Verification

**Commands:**
- `devbox run -- make codegen` -- expected: the four accessors generated; then `make codegen-check` clean with the churn committed
- `devbox run -- make check` -- expected: purity, vocabulary (`due` suffix legal, nothing else new), string audit, freeze suite green with the tenth kind and grown records registered
- `devbox run -- make test-core` -- expected: strip/energy/weave/log/substrate matrices green
- `devbox run -- make gate` -- expected: test, format, analyze all green

**Manual checks (if no CLI):**
- On a device: first open shows the check-in below the card; baja re-filters the next deal in under 500 ms; ✕ removes it for the day; a re-open shows nothing; at 200% the strip grows and scrolls with all targets ≥ 48dp.

### Review Findings

- [x] [Review][Patch] The dismissal marker `({Day day, int opens})` lapsed: a ✕ taken during a 0-`app_opened` read (crossing or paused-overnight-idle) stopped matching once the day's first `app_opened` landed and the derivation re-armed — the strip re-showed after a dismissal, violating skip-for-today. The marker is now `Day` alone: a dismissal is skip-for-TODAY, suppressed across every same-day read, re-arming only at the boundary (pinned by a mutable-`nowOf` day-boundary test). [`lib/dispenser/dispenser_controller.dart`]
- [x] [Review][Patch] `deriveStrip` hardcoded the check-in and never walked `stripResidentPrecedence` — the documented total order was inert. The walk now iterates the list through a per-resident eligibility switch (five future residents derive false, each naming its story); the order is load-bearing for 2.6 and Epics 5-7. [`packages/core/lib/derive/strip.dart`]
- [x] [Review][Patch] A failed `setEnergy` blanked the frame while the frozen matrix row says "strip stands; queue recovers" — the catch now runs a recovery read (nothing landed, so the standing surface returns) and only a second failure blanks; comments aligned; the failing-append test now asserts the strip still resolves between failure and retry. [`lib/ui/dispenser/dispenser_screen.dart`]
- [x] [Review][Patch] `_DismissPainter` pre-compensated the canvas scale (`1.5 * 24 / size.width`), forcing a constant 1.5 px stroke — ~33% heavier than the glyph discipline at the mark's box — and divided into Infinity on a zero-width layout. Stroke is now 1.5 in viewBox units behind a zero-size guard. [`lib/ui/dispenser/ambient_strip.dart`]
- [x] [Review][Patch] The `lowEnergyAdmits` doc overclaimed "estimate-based by construction" while reading `estimateSecondsOf(size)` — the comment now states the estimate derives from taxonomy size today (the catalogue's only source) and that transient steps carrying own estimates (FR-5, Epic 6) meet the same ceiling when they arrive. [`packages/core/lib/weave/weave.dart`]
- [x] [Review][Patch] The strip harness omitted `sessionSettled` (launch frame could be the pre-session close, so "below the card" was never asserted) and duplicated an `@override`; the harness threads the settle future, the first test pins card-above-strip geometry, and a new test pins the strip below the rest offer. [`test/ui/dispenser/ambient_strip_test.dart`]
- [x] [Review][Patch] Matrix row "Low-energy close-continue" was verified only at the core boundary with hand-fed energy — the seam threading to the probe was unpinned. New controller test: baja day + spent instant tier behind an elapsed pocket reads `DispenserClosed.continueOffered == false` through `read()`. [`test/dispenser/dispenser_controller_test.dart`]
- [x] [Review][Patch] The two new strip handlers had no stale-read race pin (siblings pause/continue do): a queued-read fake now drives the ✕-vs-stale-`checkInShown: true`-read race and pins the `_readGeneration` refusal — a dismissed strip cannot resurrect within the opening. [`test/ui/dispenser/ambient_strip_test.dart`]

## Suggested Review Order

**The derivation — the design's heart**

- The total order as data: six residents, rarest first, the walk takes the first eligible
  [`strip.dart:69`](../../packages/core/lib/derive/strip.dart#L69)

- Per-resident eligibility: the check-in real, five future residents false, each naming its story
  [`strip.dart:94`](../../packages/core/lib/derive/strip.dart#L94)

- The fold itself: unanswered day ∧ first-opening predicate, pure over the log
  [`strip.dart:208`](../../packages/core/lib/derive/strip.dart#L208)

- The three-clause first-opening reading (crossing / earliest-row / dangling start), recorded as code-doc
  [`strip.dart:124`](../../packages/core/lib/derive/strip.dart#L124)

**The seam and the kind**

- The one seam 1.4 reserved: stored rows → observations, never per-caller
  [`energy.dart:103`](../../packages/core/lib/energy/energy.dart#L103)

- The tenth kind and its entry; absent/out-of-range levels exclude at the boundary
  [`log_entry.dart:48`](../../packages/core/lib/log/log_entry.dart#L48)

- Schema v4 by ALTER TABLE alone, the v2/v3 pattern
  [`substrate.dart:46`](../../lib/store/substrate.dart#L46)

- The single sanctioned minter — one row, no log read, refusal is silence
  [`energy_commands.dart:28`](../../packages/core/lib/commands/energy_commands.dart#L28)

**The baja filter**

- The 60 s ceiling as a named constant beside the chunk's bag floor
  [`weave.dart:64`](../../packages/core/lib/weave/weave.dart#L64)

- The admission inside `_resolveDay` — one filter every consumer inherits
  [`weave.dart:373`](../../packages/core/lib/weave/weave.dart#L373)

**The shell**

- The write-then-read-back answer and the skip-for-TODAY dismissal marker
  [`dispenser_controller.dart:486`](../../lib/dispenser/dispenser_controller.dart#L486)

- The strip surface: question verbatim, three battery taps, ✕ at 48dp, bare chrome
  [`ambient_strip.dart:166`](../../lib/ui/dispenser/ambient_strip.dart#L166)

- The mount below the card inside `_frame`, and the two handlers' race guards
  [`dispenser_screen.dart:459`](../../lib/ui/dispenser/dispenser_screen.dart#L459)

- Four keys: three level labels plus the ✕ label
  [`app_es.arb:286`](../../lib/l10n/app_es.arb#L286)

**The proofs**

- Every matrix row of the I/O table, plus the precedence order pin
  [`strip_test.dart`](../../packages/core/test/strip_test.dart)

- The probe agrees at low energy — spent instant tier, dead continue refused
  [`dispenser_controller_test.dart`](../../test/dispenser/dispenser_controller_test.dart)

- Screen flows, geometry below card and offer, the ✕ race, the 200% floor
  [`ambient_strip_test.dart`](../../test/ui/dispenser/ambient_strip_test.dart)



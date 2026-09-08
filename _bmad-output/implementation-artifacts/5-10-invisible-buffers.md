---
title: 'Story 5.10: Invisible buffers'
type: 'feature'
created: '2026-09-08'
status: 'done'
review_loop_iteration: 0
baseline_commit: 'aad6316282ddf1e5dcc55e3a0cb61f991821830b'
context:
  - '{project-root}/_bmad-output/implementation-artifacts/epic-5-context.md'
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** Epics now land and deal (5.9), but the system they land into has no slack anywhere: FR-13's buffer — the derived target that absorbs deferrals and absences — exists as no code (AD-1 names "an Epic's buffered target date" among the derivations; `packages/core/lib/weave/weave.dart` has no such function), and the app-level seven-day-absence proof's milestone limb is recorded as vacuous until buffers land (`test/ui/dispenser/dispenser_screen_test.dart:3391`).

**Approach:** The buffer is a pure derivation, not a mechanism — FR-14's Silent Rescheduler is "not code" for exactly this reason (AD-1). One new function, `epicBufferedTargets`, computes each active Epic's completion horizon under the v1 rule — derivation-day start + **2 × remaining steps** whole domestic days (one serving day plus one slack day per step) — recomputed on every derivation, so a deferral, a skip or seven days of absence moves it silently later and nothing else: nothing is stored, nothing is re-planned, no deal changes. The proofs then make the invisibility real: the core gains the buffer group, the app-level absence test gains the epic limb, and a new masked scan pins that slack appears on no surface.

## Boundaries & Constraints

**Always:**
- A pure function of `(pool facts, log facts, day)` — no log row, no column, no `Random`, no wall clock; the target is returned as a UTC-µs instant (`Map<String, int>`, stable id → horizon instant), raw arithmetic over `Day`'s fixed 24 h frame (`packages/core/lib/day/calendar.dart:60-90`) — never a constructed `Day`, which is `Calendar`'s alone (AD-4).
- **The v1 rule, frozen:** `target = day.startUtcMicros + remainingSteps × 2 × 24 h µs`; `remainingSteps` = the group's steps not in `answeredItemIds` — the head rule's own answered set, so skip- and supersession-excluded steps still count (neither retires work), and no second definition of "done" is born.
- **Active-only, forward-only:** dormant Epics and all-answered Epics derive no entry — no obligation either way (AD-21's spirit); the anchor is the derivation day's start, so the target can only move later. "Rebalances" is recomputation, never repair.
- Grouping is exactly `epicCandidates`' key (`origin ∈ {cloud, local} ∧ rescueOf == null ∧ stepText != null`, grouped by `(instantUtcMicros, originContext)`, stable id = first fact id, `weave.dart:364-411`); extract that fold into one private helper both functions read, so the derivations cannot drift — a mechanical extraction; 5.9's pins stay green.
- Invisibility is pinned, not promised: a masked scan (1-11's scanner discipline — strings lexed, comments stripped, vacuous-pass guards) proves no surface vocabulary exists: segments `buffer|slack|holgura|restante|quedan|daysRemaining|vencid|atrasad` over `lib/ui/**/*.dart` and the raw `lib/l10n/*.arb`. Every segment is verified zero today.
- Kind census stays 21, the 1-11 shape freezes stay untouched (the function adds no top-level data shape), the ARB gains no key, the schema and store seal do not move (AD-21, AD-23).

**Ask First:**
- Any multiplier other than 2, or any anchor other than the derivation-day start.
- Any change to the chunk tiers, gates or candidate order (`_chunkCandidateOf`, `_chunkComposes`, the `_resolveDay` spread — 5.9's landed behavior).
- Any new public type, any facade export, any surface that reads the derivation, any ARB edit, any store write.
- Any weakening of a 1-11 freeze — renegotiation may only add pins.
- Any pace or rest-cadence rule in the weave: the buffer must not be felt, and a visible rhythm is a visible buffer.

**Never:**
- No overdue/late/debt state, no days-remaining, no bar, no percentage, no Settings row, no configuration — slack the user cannot see, cannot configure and cannot spend (FR-13, §1.1 P4, §7).
- No adaptive or ML buffer learning — rule-based in v1, calibration deferred (§5.1).
- No stored target, no future assignment, no re-planning code (AD-1, FR-14).
- No dormant-Epic obligations, no seasonal suggestion, no curation surfaces (5.11–5.13, FR-15).
- No deal in this story changes: composition stays byte-identical to 5.9's landed behavior.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Active Epic, R unanswered steps | slice landed + `epic_activated` | one entry: stable id → `day.startUtcMicros + 2R × 24 h µs`; horizon ≥ 2R days out — slack included by construction | — |
| Seven days of total absence | no rows written in the gap; derive at day 8 | same remaining count, horizon 8 days later than the day-0 derivation — silently rebalanced; the head composes at return exactly as on a normal day | zero rows written for the gap |
| Deferred Focus Chunk | bag < 10 min or 🔴 on day N — head not dealt | next composition offers the same head; the horizon re-anchors one day later; no rows for the deferral | — |
| Dormant Epic | steps landed, no activation row | no entry — dormancy asserts nothing | — |
| All steps answered | last `card_done` of the group | no entry — nothing owed, no completion row minted | — |
| Skipped / superseded steps in group | head skipped today, or rescue parent superseded | still counted in `remainingSteps` — neither retires work | — |
| Orphan activation row | activation names an unknown stable id | no entry — fail-safe, mirrors 5.9's orphan pin | — |
| Two active Epics | both hold unanswered steps | one entry each, keyed by stable id | — |

</frozen-after-approval>

## Code Map

- `packages/core/lib/weave/weave.dart` -- the story's whole production delta: the shared grouping fold `_epicStepsByGroupKey` (:335-359, extracted from `epicCandidates`), `epicCandidates` now reading it (:392), and NEW `epicBufferedTargets` (:472-540) returning `Map<String, int>` under the frozen rule. Read-only evidence: the epic tier and `_chunkComposes` are untouched; `_resolveDay`'s candidate spread does not call the new function.
- `packages/core/lib/day/calendar.dart:49-90` -- read-only: `Day`'s fixed 24 h frame (`startUtcMicros`/`endUtcMicros` always exactly 24 h apart) is what makes whole-day µs arithmetic exact without a `Calendar`.
- `packages/core/test/weave_test.dart` -- the "Invisible buffers" group (:4654, 12 tests), on the 5.9 builders: the whole matrix, the slack pin, the seven-day gap zero-rows assertion, the group-key discrimination pair, the all-skipped extreme, the three-offset anchor pin, and the never-earlier transition pin.
- `test/ui/dispenser/dispenser_screen_test.dart:3597` -- the epic-limb sibling absence test: an active Epic mid-plan across the same seven-day gap machinery — the standing card at return is the Epic's **next** step's own words, the census diff against a no-gap control is the greeting alone, rendering writes nothing. The former :3391 vacuous-limb comment now points at this sibling.
- `test/no_lateness_proof_test.dart:187` -- the masked surface-invisibility scan: stem segments `buffer|slack|holgura|restan|quedan|faltan|plazo|venc|atras|remaining|deadline` over `lib/ui/**/*.dart` (strings lexed, comments stripped) and the `lib/l10n/*.arb` table parsed — keys and rendered values scanned, `@`-translator prose exempt (it is where the vocabulary law is *stated*, e.g. `@pocketTrigger`'s "never remaining minutes") — with vacuous-pass guards and per-family positive controls. Documented exclusions: `progreso|progress` (AD-26's achievement figures) and `horizonte|horizon` (a neutral word the achievement surfaces may someday own); the core's own `epicBufferedTargets` is invisible-by-position, not unnameable.
- `packages/core/test/no_lateness_proof_test.dart` -- VERIFY untouched: the new function adds no top-level declaration shape (`Map<String, int>` over frozen types), so the 16-shape census, the exhaustiveness pin and the kind-name segment pin all stand unrenegotiated. Only run them, never edit.
- `packages/core/lib/log/log_entry.dart` -- read-only: census stays 21 (`log_test.dart:91` already pins it); no kind mints, nothing to add.
- `AGENTS.md` (Android emulation recipe) + `_bmad-output/implementation-artifacts/2-7-warm-return.md` -- the manual check's machinery: local-stub slice, `adb root` date synthesis, substrate pull.

## Tasks & Acceptance

**Execution:**
- [x] `packages/core/lib/weave/weave.dart` -- extract the shared grouping fold; add `epicBufferedTargets` with the frozen v1 rule -- the buffer lands as the derivation AD-1 already named
- [x] `packages/core/test/weave_test.dart` -- the "Invisible buffers" group: matrix, slack pin, seven-day gap zero-rows, never-earlier pin -- FR-13's core laws
- [x] `test/ui/dispenser/dispenser_screen_test.dart` -- the epic-limb sibling absence test + comment renegotiation -- the 1-11 vacuous limb closes for real
- [x] `test/no_lateness_proof_test.dart` -- the surface-invisibility masked scan -- AC5 as a standing guard, not a claim

**Acceptance Criteria:**
- Given any composed day, before and after this story, when the deals are compared, then they are identical — the buffer derivation changes no deal, no tier, no gate (FR-12, AD-20).
- Given any surface or the string table, when the masked scan runs, then slack appears nowhere — no bar, no percentage, no days-remaining, no configuration row (FR-13, §1.1 P4).
- Given the derivation, when any non-completion state change occurs (skip, deferral, absence, epoch churn), then the horizon moves later or stays — never earlier, never into a state any surface could read.
- Given seven days of total absence with an active Epic mid-plan, when the app next opens, then the standing card is the Epic's next step and nothing renders an obligation (FR-13, FR-6, UJ-3).
- Given the substrate after all of the above, when it is pulled, then the buffer wrote nothing: no new kind, column, ARB key or row (AD-1, AD-21, AD-23).

### Review Findings

<!-- bmad:code-review 2026-09-08 — layers: blind-hunter, edge-case-hunter, verification-gap -->

- [x] [Review][Patch] Never-earlier pin was vacuous for state changes — the loop re-derived one frozen log, proving only monotonicity in the anchor; restructured as a transition test (a `card_skipped` appended between compared derivations: R unchanged, horizon moves exactly with the anchor) and the `card_done` shortening is now pinned relative to the same-day pre-completion horizon (exactly two days shorter), not only absolutely. [packages/core/test/weave_test.dart]
- [x] [Review][Patch] False and imprecise doc sentences — `_epicStepsByGroupKey` claimed "the buffer counts exactly the steps the head rule walks" (the head excludes skipped/superseded; the buffer counts them; now "both walk the same groups"), and `epicBufferedTargets` claimed "the horizon can only move later" as a clock law (now: later across appended rows for a non-regressing day; the day is an input, replay is deterministic — AD-3). [packages/core/lib/weave/weave.dart]
- [x] [Review][Patch] Surface-scan vocabulary evasions — `restante|vencid|atrasad` missed «restan/vence/vencimiento/atraso»; widened to stems `restan|faltan|plazo|venc|atras|remaining|deadline` with per-family positive controls so an emptied RegExp cannot pass vacuously. The `remaining` control immediately caught a real premise error in the pin itself: the ARB's `@pocketTrigger` translator prose says "never remaining minutes" — metadata is where the law is stated, never rendered — so the ARB leg now parses the table and scans keys and rendered values only, exempting `@`-prose. [test/no_lateness_proof_test.dart:187]
- [x] [Review][Patch] Three unpinned edges — all-steps-skipped-today (no head on any draw, full-R entry stands), nonzero domestic offsets (the anchor is each offset's own 04:00-local day start; ± symmetric frames coincide, the zero-offset anchor stands apart), and group-key discrimination (same context + different instants, and same instant + different contexts, each two entries). [packages/core/test/weave_test.dart:4654]
- [x] [Review][Patch] Code Map stale against the landed code — anchors refreshed to landed lines. [_bmad-output/implementation-artifacts/5-10-invisible-buffers.md]
- [Review][Reject] Duplicate-fact-id collisions across groups (ids are the substrate's primary key — unreachable from the shell's UUIDv7 minter); `originContext` null-vs-"null" key collision (pre-existing 5.9 key expression, unchanged here); scanning beyond `lib/ui` (the no-literal-strings lint plus the codegen check make the ARB the only copy source); census widget-type brittleness (the 1-11 census discipline itself); masking ARB metadata (the metadata is part of the table under the same law); the unit-level `log`-immutability expects (decorative alone, but the store-boundary sibling owns the real pin).
<!-- bmad:code-review 2026-09-08 — layers: blind-hunter, edge-case-hunter, verification-gap, acceptance-auditor -->

- [x] [Review][Patch] Add an executable `Origin.local` Epic fixture through `composeDay`/`nextDeal` and `epicBufferedTargets`; the shared grouping predicate admits local facts, but all current buffer/compose fixtures use `_scanStep`'s `Origin.cloud` default, so the local path can regress unobserved. [packages/core/test/weave_test.dart:4717]
- [x] [Review][Patch] Make the masked surface scan's anti-vacuity guard cover every forbidden regex alternative (`buffer`, `slack`, `quedan`, `faltan`, `plazo`, and `atras` are currently unpinned); removing one alternative leaves the test green while that vocabulary can reach a surface. [test/no_lateness_proof_test.dart:245]

## Spec Change Log

## Design Notes

- **Why a derivation and not a mechanism.** FR-13 says the *system* spreads steps with slack, but the substrate already guarantees the felt half: nothing is dated, so nothing can be overdue and no deferral needs repair (FR-14's rescheduler is "not code", AD-1). What does not exist is the target the FR and AD-1 both name — the arithmetic that makes "silently rebalanced" checkable rather than vacuous. A pace rule (rest cadence in the tier) would be *felt* — a rhythm change is a visible buffer — and would renegotiate 5.9's landed tiering. The buffer therefore lands as one pure function plus proofs.
- **Why ×2, anchored at the derivation day.** The chunk tier answers at most one Focus Chunk per day (AD-20's occupancy), so one serving day plus one slack day per step is the smallest whole-number buffer that tolerates every-other-day engagement standing still — half the week can vanish and the horizon never tightens. Anchoring anywhere in the past (activation, last serving) would let an absence blow through the target — the target *survives* absence precisely because it recomputes from now. Whole-day `int` µs arithmetic; no fractions, no `Calendar`.
- **Why `remainingSteps` reuses the answered set.** The head rule already owns the only definition of "done" for Epic material (`answeredItemIds`, all-time). A second, buffer-local notion would drift the first time someone redefines one. Skipped-today and superseded steps stay counted: neither retires work, and the buffer must not invent retirements the substrate forbids (AD-25's no-synthetic-completion).
- **Naming.** `buffer` and `target` are outside the nine banned tokens (`tool/check_forbidden_vocabulary.dart:17-28`) and the kind-name segment pin (`packages/core/test/no_lateness_proof_test.dart:2383` bans assign/schedul/defer/plan/overdue/late/missed/due/postpon — kind names only; this adds no kind). The scan scope keeps the words legal in core and illegal on surfaces — which is the entire doctrine of this story.
- **Golden example.** Steps 1–5 landed Monday, activated, step 1 answered Monday. Tuesday's derivation: R = 4, horizon = Tue 04:00 + 8 days. Seven silent days: the next Tuesday's derivation: R = 4, horizon = Tue-next 04:00 + 8 days — seven days later, zero rows written, and the standing card is step 2's own words.

## Verification

**Commands:**
- `devbox run -- make gate` -- expected: green (format, analyze, root suite incl. the new sibling and the new masked scan)
- `devbox run -- make check` -- expected: green — ARB byte-identical, egress and store seals unchanged, codegen fresh (no schema change)
- `devbox run -- make test-core` -- expected: green — weave suite incl. the "Invisible buffers" group; the 1-11 core freezes untouched and passing
- `devbox run -- flutter test test/ui/dispenser/dispenser_screen_test.dart test/no_lateness_proof_test.dart` -- expected: exit 0

**Manual checks (device, AGENTS.md recipe):**
- The absence round-trip: debug build `--dart-define=ORGANIZER_LOCAL_SLICER=true` → `Nuevo proyecto` → type → `Analizar` → `Hecho` on the first step; then `adb root` + device-clock +8 days (computed from the **device** clock, never the host's) → reopen: the warm open renders and the standing card is the plan's **second step in its own words** — no overdue, no counter, no remaining-count anywhere.
- The substrate: pulled `organizer_substrate.sqlite` shows zero rows with instants inside the gap and no new kind beyond the 21-census vocabulary.

## Suggested Review Order

**The derivation — the story's whole production delta**

- The frozen v1 rule itself: derivation-day start + 2 × remaining steps, pure, stored nowhere, called by nothing.
  [`weave.dart:512`](../../packages/core/lib/weave/weave.dart#L512)

- The one grouping fold behind both Epic derivations — extracted from `epicCandidates`, behavior byte-identical.
  [`weave.dart:349`](../../packages/core/lib/weave/weave.dart#L349)

- The anchor's frame: `Day`'s fixed 24 h windows are what make whole-day µs arithmetic exact without a `Calendar`.
  [`calendar.dart:49`](../../packages/core/lib/day/calendar.dart#L49)

**The proofs — FR-13's laws, pinned**

- The group: matrix, slack pin, seven-day gap zero-rows, group-key discrimination, offsets, the never-earlier transition.
  [`weave_test.dart:4654`](../../packages/core/test/weave_test.dart#L4654)

- The transition pin: a skip appended between derivations moves nothing but the anchor; only a `card_done` shortens.
  [`weave_test.dart:5183`](../../packages/core/test/weave_test.dart#L5183)

- The 1-11 vacuous limb closed for real: an Epic mid-plan across seven silent days, census-diffed against a control.
  [`dispenser_screen_test.dart:3597`](../../test/ui/dispenser/dispenser_screen_test.dart#L3597)

**The invisibility guard — slack on no surface**

- The masked scan: stems over `lib/ui` and the parsed string table, positive controls per family, `@`-prose exempt.
  [`no_lateness_proof_test.dart:188`](../../test/no_lateness_proof_test.dart#L188)

---
title: 'Story 5.13: The gentle seasonal suggestion'
type: 'feature'
created: '2026-09-09'
status: 'done'
review_loop_iteration: 0
baseline_commit: '0c139de7c7776e7bcc8ded4c3b09603a6d4d72b2'
context:
  - '{project-root}/_bmad-output/implementation-artifacts/epic-5-context.md'
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** FR-15's seasonal suggestion does not exist. A dormant Epic Project (a landing that died before its `epic_activated` row — the only way dormancy arises, 5.9's derivation) is invisible forever, and the strip's `seasonalSuggestion` slot returns `false`: the app never mentions the closet switch when spring arrives.

**Approach:** Implement the resident end to end on shipped machinery. The eligibility: at the day's first opening, while at least one dormant Epic stands, the deterministic pick (earliest group instant, then stable id) has no live `suggestion_dismissed` row in the current meteorological season — once per season per project, every boundary from the one `Calendar` (AD-4). The vocabulary: the twenty-third kind `suggestion_dismissed`, a user act on the item-act shape naming the dismissed Epic — and nothing else anywhere reads it (warm return in particular never counts it as contact). The surface: one bare-chrome strip sentence proposing a minutes-per-day plan, ✕ dismisses in one tap (the row), tap accepts by activating the dormant Epic through the existing `epic_activated` minter — after which the resident is gone by derivation, no longer dormant.

## Boundaries & Constraints

**Always:**
- Season identity is only `Calendar.seasonOf` over each row's own stored offset (AD-4) — `SeasonKind` + anchor year; rows after the read instant excluded, exactly `_appOpenedBefore`'s discipline.
- Dismissal costs one ✕ tap and appends exactly one `suggestion_dismissed` row naming the project the user was **shown** (the `_askedReportWeek` grammar — never re-derived at tap time), through the single sanctioned minter, riding the controller's shared content copier so the append census stays unchanged.
- The dismissal row's only reader is the strip's own eligibility — no metric, streak, warm return, energy, weave or composition may change on a decline (FR-15's testable consequence). Warm return must not count it as contact: the `consent_declined`/`scan_abandoned` precedent, made load-bearing here.
- Acceptance is one tap minting exactly one `epic_activated` row via the existing minter from one new pinned call site; the Epic then enters the weave's arbitration by construction, and no "plan" is configured or stored anywhere — the buffered pace 5.10 already derives is the plan.
- Eligibility gates: day's first opening ∧ a dormant Epic ∧ the pick undismissed-this-season. Dismissing project A may surface project B in the same opening — per-project is the declared rate limit (FR-15); the handoff to the report/check-in is the strip's deterministic seam.
- Precedence slot 3 stands (UX-DR22): beats report and check-in, loses to `firstRunCuration` (a first-ever opening cannot be in-season — a fresh install holds no dormant Epic); a displaced resident is neither consumed nor dismissed.
- Bare chrome (ephemeral resident), sentence in the support role / ink-secondary, whole-sentence ≥ 48 dp opaque `Semantics(button)` target, `_DismissMark` ✕ — `CurationOfferStrip`'s grammar, including 5.12's review pins (padding-band tap accepts; styling pinned).
- Copy through the ARB + `make codegen`, description + `x-signoff` (UX-DR52 register).
- Schema stays v11 — the item pair carries the whole payload, no new columns; the kind census pin moves 22 → 23.

**Ask First:**
- The tap's behaviour — proposal: one tap **activates** the dormant Epic (the FR-23 snowball precedent: a suggestion's accept does the thing it proposes); alternative: a dismissal-only resident whose sentence is not tappable. No AC pins acceptance either way.
- The sentence — proposal: `seasonalSuggestion` = **"¿Unos minutos al día para {description}?"** with `{description}` = the Epic's Origin Context (the space description); alternatives: "¿Retomar {description} con unos minutos al día?" or a generic string not naming the project.

**Never:**
- No configuration surface of any kind for the suggestion engine (UX-DR59, PRD OQ-6 — defaults-only is a standing position, not a decision to make here).
- No second season/period computation anywhere outside the one `Calendar`; no stored eligibility, dismissal flag, setting key or schema column (AD-21).
- No re-ask of a dismissed project within its season; dormant Epics appear in no default view except this strip resident (FR-11); no per-step, count or catalogue surface (NL-1).
- No change to the precedence list, the other residents' eligibility or dismissal scopes, the landing paths' activation minting, warm return's semantics beyond the one carve-out, or the censuses beyond the declared additions (kind census +1, append census unchanged, two new ×1 invocation pins).

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| First opening, one dormant Epic | `app_opened` today, facts with no `epic_activated` | Strip shows the suggestion naming the Epic; report/check-in displaced | quiet: no dormant list → nothing |
| Dismiss (✕) | one tap | exactly one `suggestion_dismissed` row (shown id + origin); slot hands to report/check-in this opening; that project silent rest of season | read failure: quiet, no row, resident stands |
| Accept (tap) | one tap on the sentence | exactly one `epic_activated` row; resident gone by derivation; Epic active in the weave | read failure: row written, quiet refresh |
| Stale tap | handler fires after a read that showed no suggestion | no write, quiet (the `dismissCheckIn` grammar) | — |
| No dormant Epic | every landing activated / empty pool | never eligible | — |
| Dismissed last season | dismissal row's own season ≠ current | eligible again this season | — |
| Two dormant Epics | A (earlier) and B | A shows; after A dismissed, B may show same opening | — |
| Season boundary at 04:00 | dismissal stored 03:59 own-offset, read after crossing | prior season's dismissal no longer suppresses | — |
| Activation exists | `epic_activated` names the group | not dormant, never suggested | — |

</frozen-after-approval>

## Code Map

**Core — the eligibility, the kind, the carve-out:**

- `packages/core/lib/derive/strip.dart` -- `StripResident.seasonalSuggestion` (:57, stale "Epic 6's data" doc — this story owns it); `stripResidentPrecedence` (:85, slot 3, unchanged); `StripState` (:98 — gains the suggestion record, non-null exactly on this resident, `reportWeekOrdinal`'s grammar); `_residentEligible` (:176 — the `return false` branch to replace); `deriveStrip` (:271 — gains `dormantEpics` param (default `const []`, existing tests stay green) + the pick fold); `_firstOpeningUnderway` (:188) and `_appOpenedBefore` (:281 — the own-offset, read-instant discipline to mirror for the season fold).
- `packages/core/lib/log/log_entry.dart` -- `LogKind` constants (:178-260, 22 today) + `knownByName` (:262): add `suggestionDismissed` = `'suggestion_dismissed'`; `_isItemAct` (:700 — the family gate; the generic item-act read branch converts the pair, no boundary edit); `ItemActEntry` (:232); the vocabulary doc (:1-60, add the twenty-third kind's paragraph).
- `packages/core/lib/derive/warm_return.dart` -- `_isUserAct` (:77): `ItemActEntry` currently unconditional contact — split so `suggestion_dismissed` is not (the `consent_declined` precedent; FR-15's zero-side-effects consequence).
- `packages/core/lib/weave/weave.dart` -- `_epicStepsByGroupKey` (:349, private — the one grouping fold, reuse); `epicCandidates`' dormancy check (:401); ADD public `dormantEpicProjects(poolFacts, entries, instantUtcMicros)` → ordered `({String stableId, Origin origin, String description})` records (earliest group instant, then stable id; `originContext ?? stepText ?? ''` as description; activation rows after the read instant ignored). Weave already imports derive — strip.dart must NOT import weave (cycle); the record type is structural, no shared import.
- `packages/core/lib/commands/suggestion_commands.dart` -- NEW: `suggestionDismissed({itemId, origin})`, the kind's single sanctioned minter — `epicActivated` (scan_commands.dart:265) verbatim in shape; `curation_commands.dart` is the new-domain-file precedent.

**Shell — the read, the two paths, the surface:**

- `lib/dispenser/dispenser_controller.dart` -- strip assembly (:378-393): compute `dormantEpicProjects` over the queue-consistent pool + log, pass to `deriveStrip`; `_askedReportWeek` grammar (:315/:415) twins as `_shownSuggestion`; view plumbing `reportWeekOrdinal` (:56/:73 + ctors :114/:152/:173 + constructions :466/:481) twins for the suggestion record; `_appendContent` (:742 — the shared copier both new rows ride); `dismissCheckIn` (:894 — the queued read-refresh grammar); ADD `dismissSeasonalSuggestion`/`acceptSeasonalSuggestion` (stale-tap guard, zero other writes).
- `lib/ui/dispenser/ambient_strip.dart` -- `CurationOfferStrip` (:179) the widget to mirror as `SeasonalSuggestionStrip`; `_DismissMark` (:82).
- `lib/ui/dispenser/dispenser_strip_layer.dart` -- params (:47-79) + switch (:103): new case + `onAcceptSuggestion`/`onDismissSuggestion`.
- `lib/ui/dispenser/dispenser_screen.dart` -- `StripLayer` wiring (:737-744); handlers `_onDismissCurationOffer` (:976)/`_onAcceptCuration` (:1012) twin, including the read-generation stale-race discipline (5.12's review pins).
- `lib/l10n/app_es.arb` -- ADD `seasonalSuggestion` + `{description}` placeholder (pattern :199) beside `curationHouseGroups` (:409); `make codegen` (Makefile:41-45; freshness in `make check`).

**Tests and pins:**

- `packages/core/test/strip_test.dart` -- harness (:69 — gains the `dormantEpics` param); the 5.12 group (:722) the grammar. ADD the seasonal group: eligible / no-dormant / dismissed-this-season (own-offset scoping) / dismissed-prior-season / per-project / boundary-04:00 crossing / beats report + check-in / loses to firstRunCuration / handoff after ✕ / seam exclusion / activated-not-dormant / two-dormant ordering.
- `packages/core/test/log_test.dart` -- kind census (:98, `hasLength(22)` → 23); conversion pins: the pair required, foreign payload excluded (the family's existing shape tests).
- `packages/core/test/warm_return_test.dart` -- ADD: a dismissal as latest row leaves a deserved warm return due (the carve-out's pin).
- `packages/core/test/weave_test.dart` -- ADD `dormantEpicProjects` unit pins: ordering, activation-after-read-instant ignored, description fallback.
- `test/no_lateness_proof_test.dart` -- append census (:581-660): controller stays 1 site — unchanged; ADD ×1 pins `suggestionDismissed(` and `epicActivated(` in the dispenser source; banned wire-name list (:323) may take `'suggestion_dismissed'` (strongest) — fence-by-pin also legal, 5.9's pattern; pick one and record why.
- `test/dispenser/dispenser_controller_test.dart` -- dismissal-scope grammar (:2245+). ADD: ✕ writes exactly one row naming the shown project; stale tap writes nothing; accept writes exactly one `epic_activated`; zero collateral rows (energy/session/report); weave deal identical after dismissal.
- `test/ui/dispenser/ambient_strip_test.dart` -- `_RecordingStore` (:46); ✕-writes-nothing precedent (:415); 5.12's styling/padding-band pins (:1252). ADD the suggestion strip's group, pins included.
- `test/ui/dispenser/dispenser_screen_test.dart` -- tap→surface grammar (:6109). ADD: tap → activation row + strip gone; ✕ → row + handoff to check-in; stale-read race.

## Tasks & Acceptance

**Execution:**
- [x] `packages/core/lib/log/log_entry.dart` -- the twenty-third kind `suggestionDismissed` on the item-act shape, `knownByName` + `_isItemAct` + the vocabulary doc -- no new columns, v11 stands
- [x] `packages/core/lib/derive/warm_return.dart` -- the `_isUserAct` carve-out: a dismissal is never contact -- FR-15's zero-side-effects consequence, the `consent_declined` precedent
- [x] `packages/core/lib/weave/weave.dart` -- public `dormantEpicProjects` beside the private grouping fold -- the one dormancy derivation, ordered, read-instant-safe
- [x] `packages/core/lib/commands/suggestion_commands.dart` -- the single sanctioned minter -- `epicActivated`'s shape verbatim
- [x] `packages/core/lib/derive/strip.dart` -- the seasonal eligibility (first-opening gate ∧ dormant pick ∧ no live same-season dismissal, own-offset season scoping), `StripState.suggestion`, the pick fold in `deriveStrip`, stale comments fixed -- AC 1/2/3/5 as derivation
- [x] `lib/dispenser/dispenser_controller.dart` -- dormant fold into the read, `_shownSuggestion`, view plumbing, `dismissSeasonalSuggestion`/`acceptSeasonalSuggestion` through the shared copier -- the two one-tap paths, zero collateral writes
- [x] `lib/ui/dispenser/ambient_strip.dart` + `lib/ui/dispenser/dispenser_strip_layer.dart` + `lib/ui/dispenser/dispenser_screen.dart` -- `SeasonalSuggestionStrip` (bare chrome, sentence target, ✕), the layer case, the screen's two handlers with the stale-race discipline -- the surface
- [x] `lib/l10n/app_es.arb` + `make codegen` -- `seasonalSuggestion` with description + x-signoff per checkpoint -- the one authored string
- [x] `packages/core/test/strip_test.dart` + `packages/core/test/log_test.dart` + `packages/core/test/warm_return_test.dart` + `packages/core/test/weave_test.dart` -- the eligibility matrix, census 23, the carve-out pin, the fold pins -- the core ACs as proof
- [x] `test/no_lateness_proof_test.dart` + `test/dispenser/dispenser_controller_test.dart` + `test/ui/dispenser/ambient_strip_test.dart` + `test/ui/dispenser/dispenser_screen_test.dart` -- census/pin updates (append census unchanged), write-path proofs, surface pins -- the shell ACs end to end

**Acceptance Criteria:**
- Given a dormant Epic and the day's first opening, when the strip resolves, then the suggestion shows — bare chrome, one sentence proposing a minutes-per-day plan naming the project (FR-15, UX-DR22).
- Given a season boundary, when computed, then it is the meteorological quarter of the one `Calendar` on domestic-day boundaries, each row in its own stored offset — nowhere else (AD-4).
- Given the suggestion dismissed, when any later read of the same season runs, then it never repeats for that project — and every other derivation, warm return included, is unchanged (FR-15, AD-21).
- Given the suggestion accepted, when the write lands, then exactly one `epic_activated` row exists, the resident is gone by derivation, and the Epic's head competes in the weave like any active Epic (FR-11, AD-20).
- Given the suggestion eligible beside the report or check-in, when both stand, then only the suggestion is visible — and beside the first-run curation offer, only the offer (UX-DR22, FR-4).
- Given any Settings or configuration surface, when searched, then the suggestion engine has none (UX-DR59, PRD OQ-6).
- Given `make check`, when it runs, then the append census is unchanged, the kind census is 23, and both new ×1 invocation pins hold.

## Spec Change Log

### Review Findings

- [x] [Review][Decision] Sergio approved both Ask-First proposals at the planning checkpoint, 2026-09-09: the tap activates the dormant Epic (one `epic_activated` row, the FR-23 snowball precedent) and `seasonalSuggestion` = "¿Unos minutos al día para {description}?" with the Epic's Origin Context as {description} — the ARB's `x-signoff` records the same [`lib/l10n/app_es.arb`, `lib/dispenser/dispenser_controller.dart:acceptSeasonalSuggestion`]
- [x] [Review][Patch] The boundary-tap doc claim ("a dismissal can only name the season that showed it") was false at the 04:00 season turn — a suggestion shown in season S can be ✕-tapped after the turn, landing a row scoped to S+1; behavior verified correct and benign (S is historical, its suppression moot), docs corrected to the real invariant (the row scopes to the season the TAP happened in) and a boundary-tap strip pin added [`packages/core/lib/log_entry.dart`, `packages/core/test/strip_test.dart`]
- [x] [Review][Patch] `SeasonalSuggestionStrip` shipped without the 200% text-scale pin every sibling resident carries — added over a long Origin Context description (the longest copy any resident shows), plus the null-shown-record arm pin (renders nothing, no fallback sentence) [`test/ui/dispenser/ambient_strip_test.dart`]
- [x] [Review][Patch] The accept path's failure arms were untested (the ✕ sibling had the pin) — added the controller-level twin: a failed `epic_activated` append lands nothing, no other row exists, the resident stands [`test/dispenser/dispenser_controller_test.dart`]
- [x] [Review][Patch] "The row's only reader is the strip's own eligibility" was asserted but unpinned — added the walk-inert pin in the setting/report idiom, worst case: a dismissal naming the standing dealt card's own id moves no fact (deal state, activation map, answered set, dormancy) [`packages/core/test/weave_test.dart`]
- [x] [Review][Patch] Overlapping one-tap calls could double-mint at the controller level (the screen's in-flight guard was the only defence) — both paths now consume the shown record at entry; a second call mints nothing [`lib/dispenser/dispenser_controller.dart`]
- [x] [Review][Patch] The shell no-lateness scan dropped its `missed` token entirely (leaned on the vocabulary lint) — restored independent coverage as the word-bounded `\bmissed\b` alternative, which never trips on `dismissed`; the core scan's vetted-name exemption scoped to the `missed` segment alone [`test/no_lateness_proof_test.dart`, `packages/core/test/no_lateness_proof_test.dart`]
- [x] [Review][Patch] The strip layer's header comment was mangled by the story's insertion (broken sentence, dropped FR-4 reference, "Either resolution" orphaned) — rewritten with every original claim intact; the ambient strip header's stale "both residents" count fixed [`lib/ui/dispenser/dispenser_strip_layer.dart`, `lib/ui/dispenser/ambient_strip.dart`]
- [x] [Review][Defer] Extract the screen's shared write-path helper — `_seasonalSuggestionWrite` is a fourth copy of the family's write-then-read mechanics → `deferred-work.md`
- [x] [Review][Defer] Shared dormant-Epic test fixture across the three suites (controller/ambient/screen each hand-roll one) → `deferred-work.md`
- [x] [Review][Defer] Pre-existing silent `_DelegatingStore.appendPoolFact` no-op in the controller suite → `deferred-work.md`
- [x] [Review][Record] Rejected after verification: the `?? ''` description arm is unconstructible (the grouping fold requires `stepText != null` on every member fact); the `tapTime`/`tappedAt` split follows the family's own convention (dismissals `tapTime`, answers `tappedAt`); the `dormantEpics` default `const []` is the spec's own decision (existing call sites stay green); spec "expected:" verification entries are the house convention

## Design Notes

- **Why the pick is "first dormant in creation order", not most-recent:** AD-3's discipline — a deterministic total order over facts that exist, no recency heuristic to tune. The `epicCandidates` arbitration (least-recently-served) is for ACTIVE Epics' deals; the suggestion proposes dormant material, and the earliest-created dormant Epic is the one the user has waited longest to be reminded of.
- **Why the dismissal rides the item-act shape and still is not contact:** the pair names the project (AD-14, `epic_activated`'s precedent), but the warm-return fold classifies by meaning, not shape — `slice_failed` already splits inside `SliceEntry`, and `consent_declined`'s doc states the principle: a decline is never contact. FR-15's "zero side effects on any metric" makes that principle load-bearing for this row.
- **Why no season column on the row:** the suppression scopes to the season the TAP happened in — derived from the row's own instant + offset (the check-in's day-scoping discipline) — and that is the only season it can affect: the eligibility evaluates only the current season, so a season that ended is moot whatever its rows say. The one boundary shape: a suggestion shown in season S, ✕-tapped after the 04:00 turn, lands a row scoped to S+1 — suppressing the season the tap landed in, never S; benign by the same mootness (S is historical). `report_answered` carries its week only because persistence lets an answer outlive its week; a dismissal's suppression cannot outlive its season.
- **Golden example:** March 2, first opening. An interrupted February landing left facts with no activation row → the strip shows "¿Unos minutos al día para el trastero del fondo?" above nothing else (the check-in displaced, re-offers tomorrow). ✕ → one `suggestion_dismissed` row; the check-in takes the slot this opening; the trastero silent until June 1. Tap instead → one `epic_activated` row; the strip empties; the next deal may be the Epic's head step.

## Verification

**Commands:**
- `devbox run -- make gate` -- expected: green (format, analyze, full suite)
- `devbox run -- make check` -- expected: green (codegen fresh, append census unchanged, kind census 23, ×1 pins, no-literal-strings + vocabulary clean)
- `devbox run -- make test-core` -- expected: green (strip seasonal group, warm-return carve-out, weave fold, log census)
- `devbox run -- flutter test test/ui/dispenser test/dispenser` -- expected: exit 0

**Manual checks (device, AGENTS.md recipe):**
- Seed a dormant Epic directly into `organizer_substrate.sqlite` (adb root + sqlite3: Epic-shaped facts — `cloud`/`local` origin, `rescue_of` null, `step_text` set, one shared instant + `origin_context` — with NO `epic_activated` row). First opening in-season: the suggestion shows; ✕ → row appended, silent for the season; `date -s` across the season boundary → re-offers; tap → `epic_activated` row, strip gone.
- Pull the substrate after each path: only the expected row each time; schema still v11; energy/report/session tables untouched by the decline.

## Suggested Review Order

**The eligibility — the story's keystone**

- The seasonal branch: first opening ∧ the pick handed in — the `return false` era ends.
  [`strip.dart:202`](../../packages/core/lib/derive/strip.dart#L202)

- The pick fold: own-offset season scoping, read-instant exclusion, per-project rate limit.
  [`strip.dart:367`](../../packages/core/lib/derive/strip.dart#L367)

- The shown record both one-tap paths act on — `reportWeekOrdinal`'s grammar, structural type, no cycle.
  [`strip.dart:134`](../../packages/core/lib/derive/strip.dart#L134)

- The dormant fold handed in at the call site — `dormantEpics` with the `const []` default.
  [`strip.dart:428`](../../packages/core/lib/derive/strip.dart#L428)

**The vocabulary and the zero-side-effects consequence**

- The twenty-third kind on the item-act shape — no columns, v11 stands; the boundary-tap invariant stated honestly.
  [`log_entry.dart:155`](../../packages/core/lib/log/log_entry.dart#L155)

- The carve-out: a dismissal is never contact — `consent_declined`'s register, FR-15 load-bearing.
  [`warm_return.dart:90`](../../packages/core/lib/derive/warm_return.dart#L90)

- The single sanctioned minter — `epicActivated`'s shape verbatim.
  [`suggestion_commands.dart:33`](../../packages/core/lib/commands/suggestion_commands.dart#L33)

**The one dormancy derivation**

- `dormantEpicProjects` beside the private grouping fold — ordered, read-instant-safe, structural records.
  [`weave.dart:495`](../../packages/core/lib/weave/weave.dart#L495)

**The two one-tap paths**

- The ✕: one `suggestion_dismissed` row naming the shown project, consumed at entry.
  [`dispenser_controller.dart:1023`](../../lib/dispenser/dispenser_controller.dart#L1023)

- The tap: one `epic_activated` row from the new pinned site — activation IS the plan.
  [`dispenser_controller.dart:1063`](../../lib/dispenser/dispenser_controller.dart#L1063)

- The shown record rides the read — never re-derived at tap time.
  [`dispenser_controller.dart:451`](../../lib/dispenser/dispenser_controller.dart#L451)

**The surface**

- The strip widget: sentence verbatim, ≥48dp opaque button, `_DismissMark`, bare chrome.
  [`ambient_strip.dart:246`](../../lib/ui/dispenser/ambient_strip.dart#L246)

- The two handlers over one shared write — in-flight guard, generation bump, recovery read.
  [`dispenser_screen.dart:1007`](../../lib/ui/dispenser/dispenser_screen.dart#L1007)

- The one authored string, signoff'd — the minutes-per-day proposal naming the Epic.
  [`app_es.arb:415`](../../lib/l10n/app_es.arb#L415)

**Proofs**

- The eligibility matrix: 12 tests incl. boundary-tap, own-offset, per-project, precedence.
  [`strip_test.dart:907`](../../packages/core/test/strip_test.dart#L907)

- The walk-inert pin — the dismissal moves no fact, dormancy included.
  [`weave_test.dart:4767`](../../packages/core/test/weave_test.dart#L4767)

- The write paths end to end: exactly-one rows, stale taps, failure arms, deal identical.
  [`dispenser_controller_test.dart:3230`](../../test/dispenser/dispenser_controller_test.dart#L3230)

- The surface pins incl. the 200% long-description scale test and the null arm.
  [`ambient_strip_test.dart:1782`](../../test/ui/dispenser/ambient_strip_test.dart#L1782)

- Tap and ✕ through the real screen harness — activation, handoff, stale-refresh race.
  [`dispenser_screen_test.dart:6272`](../../test/ui/dispenser/dispenser_screen_test.dart#L6272)

- The fences: ×1 minter pins, the eighteen-name ban list, the census unchanged.
  [`no_lateness_proof_test.dart:594`](../../test/no_lateness_proof_test.dart#L594)

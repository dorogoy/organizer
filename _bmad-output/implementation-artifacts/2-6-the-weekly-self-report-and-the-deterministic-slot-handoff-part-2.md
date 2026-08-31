---
title: 'The weekly self-report derivation (2-6, part 2)'
type: 'feature'
created: '2026-08-31'
status: 'done'
review_loop_iteration: 0
baseline_commit: 'da61b1dd9921a18abb5df02c8b8e048f759095f1'
context: ['SM-2', 'FR-4', 'AD-21', 'AD-23', 'UX-DR22']
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** SM-2's report is mintable and round-trips (part 1) but never shows: `weeklySelfReport`'s eligibility is a `false` stub, so the strip cannot offer the weekly question, and the deterministic report→check-in slot handoff has no derivation to hand off.

**Approach:** Replace the stub with the pure fold over the log — due week is `weekOf(today).weekOrdinal` minus 0 on Sunday (weekday 7) / 1 on Mon–Sat (the latest week whose Sunday has arrived), unanswered iff no accepted `report_answered` row carries that ordinal (rows after the read instant excluded), gated by the existing first-opening fold. Persistence, supersession and at-most-one-pending are emergent — no stored pending state. `StripState` gains `int? reportWeekOrdinal`; `deriveStrip` gains `Set<StripResident> excludeResidents = const {}` skipped by the walk — the seam part 3's opening-scoped dismissal reuses.

## Boundaries & Constraints

**Always:**
- The due-week arithmetic is exactly `weekOf(today).weekOrdinal - (today.weekday == 7 ? 0 : 1)` (ISO weekday, `Day`'s own); the read instant's frame decides `today`, as the check-in already does (AD-4).
- The answer match is the row's carried `week` field — never the answer's own instant re-derived; a row answers the due week iff its instant is ≤ the read instant and its week equals the due ordinal (energy.dart:80-95's rules). An answer on any later day counts; a foreign-week or future-dated row counts for nothing.
- The report's gate is the existing `_firstOpeningUnderway` fold unchanged (strip.dart:151-207) — re-offered at each day's first opening until answered.
- `StripState.reportWeekOrdinal` is non-null exactly when the resident is `weeklySelfReport`; every other resident carries null. No dismissal flag, no answered marker (AD-21).
- The seam: `excludeResidents` is skipped by the precedence walk, writes nothing, and is read-scoped — the same log without it resolves the same resident.
- **Register correction (deferred-work.md:149):** the shell does NOT stay untouched. The controller's resident-blind `checkInShown = strip != null` (dispenser_controller.dart:188) would flip the after-answer pins (`dispenser_controller_test.dart:2013,2045,2096,2193-2194`) — a pending report makes every post-`setEnergy` read non-null. Part 2 passes `excludeResidents: const {StripResident.weeklySelfReport}` at the one call site (dispenser_controller.dart:183-187) with a code-doc naming part 3 as its remover; the derivation minus the report is exactly 2-5's, so every shell pin holds verbatim and no shell test changes.

**Ask First:** None — the register's "shell stays untouched" claim is disproven by the pins above; the one-line exclusion is the minimal honest fix (the alternative — gating the report on `!answeredToday` inside the core — would encode interim shell sequencing into the pure derivation and is rejected).

**Never:** No view, ARB, minter, substrate, schema or migration change; no reader/trend derivation (SM-2 reads rows at analysis time); no notification path (FR-24); no stored pending/dismissal state; the 2-5 check-in matrix keeps its assertions — only its wrapper switches to the excluded read; no golden tests.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Behavior | Error Handling |
|----------|---------------|-------------------|-----------------|
| Sunday first opening | Sun 2026-08-30 12:00 UTC, opening rows, no answer | report wins, `reportWeekOrdinal` = 1390 (the Sunday's own week) | N/A |
| Weekday persistence | Sat 2026-08-29 / Mon 2026-08-31 first openings | report carries 1389 (Sat) / 1390 (Mon) — the latest week whose Sunday arrived | N/A |
| Next-Sunday supersession | week 1389 unanswered into Sun 2026-08-30 | due becomes 1390; at most one pending ever; 1389 has no data point | N/A |
| Displaced check-in | both eligible at one first opening | report wins; its answer landing re-reads the check-in into the slot in the same opening (delay, never day-displacement) | N/A |
| Future-dated answer | answer row instant > read instant, week matches | still pending — the row is excluded | quiet |
| Foreign-week answer | answer carries another ordinal (e.g. 1387) | still pending — the carried week is the whole match | quiet |
| Own-offset read | 2026-08-30 02:30 UTC read: +02:00 vs 00:00 | 1390 (wall 04:30 Sunday) vs 1389 (wall 02:30, day Sat) — the read frame decides | N/A |
| Crossing 04:00 | crossing read, no `app_opened` today | report shows once (clause 1); answered during the crossing → gone | N/A |
| Second opening | later same-day opening | report hidden by the gate; returns at the next day's first opening | N/A |
| Pre-open answer row | an answer is today's earliest row | betrays the consumed opening — the report waits for the next day | N/A |
| Exclusion seam | `excludeResidents` holds the report | walk skips it — check-in takes the slot; both excluded → null; nothing written | N/A |

</frozen-after-approval>

## Code Map

- `packages/core/lib/derive/strip.dart:1-47,95-164,270-324` -- library contract; `StripState.reportWeekOrdinal`; report eligibility (`!answeredDueWeek && firstOpening`); due-week and answer folds; `excludeResidents` skip; resident-specific state construction
- `packages/core/lib/derive/strip.dart:168-244` -- READ ONLY (the existing first-opening gate; the `ReportAnsweredEntry` no-op arm remains at :222)
- `packages/core/lib/day/calendar.dart:135-141,215-248` -- READ ONLY (`weekOrdinal`, `dayOf`, `weekOf`; `Day.weekday` ISO Mon=1..Sun=7; the week anchored Mon 2026-08-24 = 1390 (weave_test.dart:1411), so Mon 2026-08-31 = 1391, Sun 2026-08-30's week = 1390, Sat 08-29's due = 1389)
- `packages/core/lib/log/log_entry.dart:304-328` -- READ ONLY (`ReportAnsweredEntry{value, week}`)
- `packages/core/lib/energy/energy.dart:80-95` -- READ ONLY (the seam rules the answer fold copies)
- `lib/dispenser/dispenser_controller.dart:183-196` -- the interim exclusion + code-doc (part 3's remover)
- `packages/core/test/strip_test.dart:59-80,82-347,349-710` -- `resolve` gains the exclusion param; 2-5 groups use the report-excluding wrapper with assertions unchanged; `the weekly self-report eligibility (matrix rows, SM-2, FR-4)` covers every matrix row on Saturday, Sunday and later-week clocks
- `packages/core/test/no_lateness_proof_test.dart:918-932` -- StripState freeze → `['resident', 'reportWeekOrdinal']` + revised comment

## Tasks & Acceptance

**Execution:**
- [x] `packages/core/lib/derive/strip.dart` -- the due-week fold, the answer fold, `reportWeekOrdinal`, the `excludeResidents` seam, docs
- [x] `lib/dispenser/dispenser_controller.dart` -- pass the interim exclusion at the one `deriveStrip` call
- [x] `packages/core/test/strip_test.dart` -- wrapper switch for 2-5 groups; the report matrix group replacing the stub-pinning group
- [x] `packages/core/test/no_lateness_proof_test.dart` -- the freeze update

**Acceptance Criteria:**
- Given Sunday's first opening with the due week unanswered, when the strip resolves, then `StripState(resident: weeklySelfReport, reportWeekOrdinal: the week's ordinal)` and the check-in is displaced, not consumed
- Given the due week's answer landing mid-opening, when the strip re-resolves, then the check-in takes the slot in that same opening
- Given the next Sunday arriving with the prior week unanswered, then the due week advances — never two pending, the superseded week simply unanswered
- Given the shell's interim read, then `checkInShown` behaves exactly as 2-5 shipped (every shell test green, untouched)
- Given rows after the read instant or carrying a foreign week, then the report stays pending, quietly
- Given the completion gate, then `make test-core`, `make check` and `make gate` are green

### Review Findings

- [x] [Review][Patch] An energy-answered day never silences the report — unpinned (the report is not energy-gated) [packages/core/test/strip_test.dart]
- [x] [Review][Patch] Crossing into Sunday asks the Sunday's own week — the −0 arm at a 04:00 crossing, unpinned [packages/core/test/strip_test.dart]
- [x] [Review][Patch] The bare-log clause-1 read resolving the report, unpinned after the 2-5 pin went excluded [packages/core/test/strip_test.dart]
- [x] [Review][Patch] The `<=` read-instant boundary for an answer row, unpinned [packages/core/test/strip_test.dart]
- [x] [Review][Patch] Stale "every 2-5 test" scoping comment on the base clock [packages/core/test/strip_test.dart]
- [x] [Review][Reject] Install-week gate, `StripState` assert, negative-epoch due week, seam dual justification, signature acretion, eager folds, terminology — no requirement names them; idiom or unreachability decides
- [x] [Review][Human] Frozen-matrix week literals were off by one vs `calendar.dart` (1389/1388 → 1390/1389/1390) — human sanctioned the correction; the frozen formula was exact throughout
- [x] [Review][Patch] The whole Story 2.6 is marked `review` although part 3 remains explicitly unimplemented [_bmad-output/implementation-artifacts/sprint-status.yaml:58]
- [x] [Review][Patch] The pre-open-answer matrix test is satisfied by the answer fold and therefore does not prove that the earlier row consumed the opening [packages/core/test/strip_test.dart:646]
- [x] [Review][Patch] The mid-week persistence fixture reads on Thursday without a current-day opening while claiming a Friday same-opening handoff [packages/core/test/strip_test.dart:420]
- [x] [Review][Patch] Code Map ranges point to the pre-expansion locations rather than the landed derivation and report matrix [_bmad-output/implementation-artifacts/2-6-the-weekly-self-report-and-the-deterministic-slot-handoff-part-2.md:53]

## Spec Change Log

## Design Notes

- **Why −0/−1 makes everything emergent.** The due week is a pure function of `today`: on Sunday it is the running week, on Mon–Sat the one before. Persistence on any later day (the week stays due until its ordinal is answered), supersession at the next Sunday (the target advances, the old ordinal never matches again) and at-most-one-pending all fall out of one comparison — no pending state exists to store, which is the only AD-21-legal shape.
- **Why the controller exclusion, not a core gate.** The failing pins are post-`setEnergy` reads: resident-blind `strip != null` would resurrect the check-in pixels while the report "won". The seam says truthfully "this reader cannot render that resident yet"; a core `!answeredToday` gate would bake the interim into the permanent derivation and read as a suppression rule no requirement states. Part 3 deletes the one line when the view widens.
- **Why the carried week is the whole match.** Part 1's `week` field exists precisely because persistence lets an answer fall outside the reported week; deriving the week from the answer's instant would re-derive what the row already states.

## Verification

**Commands:**
- `devbox run -- make test-core` -- expected: strip matrix green incl. the report group; shell controller group untouched and green
- `devbox run -- make check` -- expected: purity + string audit green (no new literals)
- `devbox run -- make gate` -- expected: test, format, analyze all green

## Suggested Review Order

**The fold — the design's heart**

- One comparison decides the due week: the running week on Sunday, the one before on Mon–Sat
  [`strip.dart:293`](../../packages/core/lib/derive/strip.dart#L293)

- The answer fold on the energy seam's rules: the carried week is the whole match, future rows excluded
  [`strip.dart:295`](../../packages/core/lib/derive/strip.dart#L295)

- The report's eligibility — due week unanswered ∧ the day's first opening, one slot above the check-in
  [`strip.dart:152`](../../packages/core/lib/derive/strip.dart#L152)

- `StripState` grows the pending week — non-null exactly for the report, never a stored marker
  [`strip.dart:112`](../../packages/core/lib/derive/strip.dart#L112)

**The seam and the interim read**

- The walk skips excluded residents before eligibility is asked — read-scoped, writing nothing
  [`strip.dart:309`](../../packages/core/lib/derive/strip.dart#L309)

- The ternary construction — the ordinal rides only the report's state
  [`strip.dart:322`](../../packages/core/lib/derive/strip.dart#L322)

- The interim exclusion, one call site — part 3's remover, every 2-5 shell pin holding verbatim
  [`dispenser_controller.dart:195`](../../lib/dispenser/dispenser_controller.dart#L195)

**The matrix — every row a test**

- The report group: eleven rows on the Saturday base clock plus Sunday/Monday clocks
  [`strip_test.dart:349`](../../packages/core/test/strip_test.dart#L349)

- Persistence — Sat 1389, Mon/Sep-5 1390: the −1 arm holding, never stored state
  [`strip_test.dart:390`](../../packages/core/test/strip_test.dart#L390)

- Supersession — the Sunday advances the target; the superseded week simply has no data point
  [`strip_test.dart:437`](../../packages/core/test/strip_test.dart#L437)

- The slot handoff — the answer lands mid-opening and the check-in takes the slot at once
  [`strip_test.dart:471`](../../packages/core/test/strip_test.dart#L471)

- The instruments gate independently — an energy answer never silences the report
  [`strip_test.dart:494`](../../packages/core/test/strip_test.dart#L494)

- The `<=` boundary — an answer at exactly the read instant counts
  [`strip_test.dart:526`](../../packages/core/test/strip_test.dart#L526)

- Crossing into Sunday — the same sitting asks the week the Sunday closes (−0 arm)
  [`strip_test.dart:604`](../../packages/core/test/strip_test.dart#L604)

- The exclusion seam — skipped, read-scoped, both-excluded → null, nothing written
  [`strip_test.dart:681`](../../packages/core/test/strip_test.dart#L681)

**The proofs**

- The freeze — two facts and no more: the resident, and (for the report) its week
  [`no_lateness_proof_test.dart:918`](../../packages/core/test/no_lateness_proof_test.dart#L918)

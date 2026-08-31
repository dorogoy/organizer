---
title: 'The weekly self-report surface and the deterministic slot handoff (2-6, part 3)'
type: 'feature'
created: '2026-08-31'
status: 'done'
review_loop_iteration: 0
baseline_commit: '4e2550ac826de68aa674bbda8ddd2f139eb262f8'
context: ['SM-2', 'FR-4', 'FR-24', 'AD-15', 'AD-21', 'UX-DR22']
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** SM-2's report derives (part 2) but the shell cannot show it: `DispenserView.checkInShown` is resident-blind, `read()` excludes the report as an interim seam, and no view renders the question — so the weekly answer never lands and the deterministic check-in handoff never happens.

**Approach:** Widen the view to carry the resident (`StripResident? stripResident` + `int? reportWeekOrdinal`), delete the interim exclusion, and pass both dismissals as `deriveStrip` exclusions — the check-in's skip-for-today `Day` marker unchanged, the report's new opening-scoped `({Day day, int opens})` marker. Render the hairlined resident in `ambient_strip.dart` (question verbatim, 1–5 digits as 48dp tap targets through one ARB placeholder, visible end labels, ✕ reuse), mint `reportAnswered(value, week: the pending week from the last queue read)` in `setEnergy`'s write-then-read shape, and grow the shell proofs (register: deferred-work.md DW-150-152).

## Boundaries & Constraints

**Always:**
- All three `DispenserView` variants carry `StripResident? stripResident` + `int? reportWeekOrdinal` (ordinal non-null exactly when the resident is the report); the screen gates and switches on the resident. The 2-5 controller-group assertions translate mechanically (`checkInShown isFalse` → `stripResident isNull`; `isTrue` → `stripResident == energyCheckIn`), semantics unchanged; the check-in widget and its tests stay as they are.
- `read()`: delete the interim exclusion; `excludeResidents` composes (a) `energyCheckIn` when `_checkInDismissMarker == today` and (b) `weeklySelfReport` when `_reportDismissMarker` matches — `opens` = today's `app_opened` rows counted over the same queue-consistent log, each row in its own offset; the marker re-arms when a new opening lands or the day turns. Never a write, never a stored pending.
- `answerReport({value, tappedAt})`: `setEnergy`'s shape — instant minted at entry, exactly one `report_answered` row through the core minter, write-then-read. The week is the pending week from the last queue read (a controller field each read updates): the row answers the week the user was asked, even when the tap lands past a boundary. A null pending week mints nothing (refusal-as-silence, never an error).
- `dismissReport({tapTime})`: writes nothing; sets the opening-scoped marker (day from the tap's own instant, opens counted inside the queue). A dismissal frees the slot for that opening only — the check-in takes it in the same opening; the report returns at the next opening the derivation judges first (next day's first opening, or the crossing case's later `app_opened`), never dismissed for the week.
- The resident widget (a sibling of `AmbientStrip` in ambient_strip.dart): question `weeklySelfReportQuestion` verbatim (app_es.arb:99); digits 1–5 each `Semantics(button: true)` over an opaque ≥48dp target (the `_BatteryMark` grammar), the digit text through one new ARB key `selfReportScaleValue` = `"{value}"` (int placeholder — digits are not string literals, AD-15); end labels `selfReportScaleLow`/`selfReportScaleHigh` visible below the digits, fixing the scale's direction; ✕ reuses `_DismissMark`/`ambientStripDismiss`; a 1px `colorScheme.outline` hairline with `radiusDefault` on the resident's own wrapper, never the container; digits in the figure role (`TypeRoles.metricNumeral`), question and labels in support (`bodySmall`); mockup §1C/§3's anatomy — question+✕ row, digits row, labels row.
- The screen: `_withAmbientStrip` switches on `view.stripResident`; the report's two handlers copy the 2-5 shape exactly (shared `_writeInFlight` guard, `tappedAt` minted at entry, `_readGeneration++`, `sessionSettled` await, committed view via setState, recovery read on failed append, empty frame only if that fails too).
- Proofs: dispenser append census 6→7 (call counts and content counts); `reportAnswered(` invocation ×1 beside `energySet` ×1; `report_answered` is already in `bannedWireNames` (verify, don't re-add). gen-l10n accessors regenerated and committed.

**Ask First:** None — the register (DW-150-152) sanctioned this shape at the split; the digit type role (`metricNumeral` over the mockup's raw 15px) and the labels' row below the digits are ours, landing as code-doc plus this record.

**Never:** No core change of any kind (strip.dart, report_commands.dart, schema, migrations — all read-only); no new log kind, no stored pending or dismissal row (AD-21); no notification path (FR-24 — none exists, nothing added); no trend reader (SM-2 reads rows at analysis time); no golden tests; no check-in surface change beyond the mechanical field translation.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Behavior | Error Handling |
|----------|---------------|-------------------|-----------------|
| Sunday first read | Sun 2026-08-30 12:00 UTC, one `app_opened`, no answer | `stripResident == weeklySelfReport`, `reportWeekOrdinal` 1390; check-in displaced, not consumed | N/A |
| Answer lands | digit 3 tapped mid-opening | one `report_answered` row `{value: 3, week: 1390}`; same-opening re-read: `stripResident == energyCheckIn` | N/A |
| ✕ dismissal | ✕ at the opening | marker set, no row; check-in takes the slot; report hidden this opening | N/A |
| Re-arm at a crossing | dismissed during a 04:00 crossing (opens = 0), then the day's `app_opened` lands | opens = 1 ≠ marker → the report re-offers at that first opening | N/A |
| Day-scope of dismissal | next day's first opening | the report is offered again | N/A |
| Refusal guard | value outside 1–5 or pending week null | nothing written; the fresh read returns | silence |
| Failed append | store fails the row | recovery read: the report still stands | quiet |
| Tap across 04:00 | view shown Sunday, tap lands past the boundary | row instant = the tap's; week = the asked week | N/A |
| Supersession | week 1390 unanswered into Sun 2026-09-06 | due week 1391; at most one pending ever | N/A |
| Check-in never shown | the day ends with the report unresolved | energy carries the llena default, owes nothing | N/A |
| 200% font scale | textScaleFactor 2.0 | the hairlined resident grows inside the scroll; every digit target ≥48dp; labels wrap, nothing truncates | N/A |

</frozen-after-approval>

## Code Map

- `lib/dispenser/dispenser_controller.dart:33-88` -- the three variants and the field being widened; `:132-143` the skip-for-today marker (unchanged semantics); `:166-264` the queue read with the interim exclusion at `:183-197` (the remover) and the variant constructions at `:244,256,262`; `:505-530` setEnergy (answerReport's template); `:540-546` dismissCheckIn; `:554-557` `_dayOf`
- `packages/core/lib/derive/strip.dart:57-113,264-325` -- READ ONLY (`StripResident`, `StripState.reportWeekOrdinal`, the `excludeResidents` seam's read-scoped contract, precedence with the report above the check-in)
- `packages/core/lib/commands/report_commands.dart:36-54` -- READ ONLY (the minter; bounds `reportScaleLeast/Most` at log_entry.dart:284-285)
- `packages/core/lib/log/log_entry.dart:137-158` -- READ ONLY (`MomentEntry` carries `app_opened`; the opens census counts these)
- `lib/ui/dispenser/ambient_strip.dart` (230 lines) -- the resident lands here beside `AmbientStrip`; `_DismissMark` :72-102 (reuse verbatim), `_BatteryMark` :109-156 (the tap-target grammar), header chrome rule :1-8 (bare vs hairline)
- `lib/ui/dispenser/dispenser_screen.dart:440-462` (`_withAmbientStrip` gates at :451), `:464-522` (`_onSetEnergy`), `:524-559` (`_onDismissCheckIn`) -- the resident switch and the two handlers' templates
- `lib/l10n/app_es.arb:99-102` (question), `:300-314` (dismiss label + end labels) -- add `selfReportScaleValue`; regenerate `lib/strings/*` via `make codegen` and commit (check_no_literal_strings byte-compares)
- `lib/ui/tokens.dart:35,78` (borderHairline, wired as `colorScheme.outline` at theme.dart:47), `:166-173` (metricNumeral), `:192` (radiusDefault); `lib/ui/dispenser/task_card.dart:144-152` (the 1px hairline precedent)
- `test/no_lateness_proof_test.dart:199-210` (bannedWireNames — `report_answered` already 10th), `:295-301` (invocation census), `:303-354` (append census 6→7 in both maps)
- `test/dispenser/dispenser_controller_test.dart:1965-2341` -- the 2-5 group to translate; `_FailNextAppendStore` :114-130, `_fixedClock` :254, mutable-`nowOf` precedent for the re-arm tests
- `test/ui/dispenser/ambient_strip_test.dart:141-182` (harness), `:318` (failed append restore), `:464-505` (✕ vs stale-read race), `:507-549` (200% floor) -- the widget suite's templates
- `_bmad-output/planning-artifacts/ux-designs/ux-organizer-2026-08-21/mockups/dispenser-canonical-1.html` §1C, §3 -- the resident's anatomy and the hairline/labels grammar

## Tasks & Acceptance

**Execution:**
- [x] `lib/dispenser/dispenser_controller.dart` -- widen `DispenserView`; delete the interim exclusion; compose both dismissals as exclusions; the opening-scoped marker + opens census; `answerReport` + `dismissReport`; the pending-week field with docs
- [x] `lib/l10n/app_es.arb` + `make codegen` -- `selfReportScaleValue` = `"{value}"` with an honest description; committed regenerated accessors
- [x] `lib/ui/dispenser/ambient_strip.dart` -- the hairlined report resident (sibling widget; `AmbientStrip` itself unchanged)
- [x] `lib/ui/dispenser/dispenser_screen.dart` -- resident switch in `_withAmbientStrip`; `_onAnswerReport` + `_onDismissReport` in the 2-5 handler shape
- [x] `test/no_lateness_proof_test.dart` -- append census 6→7; `reportAnswered(` ×1 pin
- [x] `test/dispenser/dispenser_controller_test.dart` -- the 2-5 translation; the 2-6 matrix (Sunday clock `DateTime.utc(2026, 8, 30, 12)`, same-opening handoff on answer and on ✕, crossing re-arm via mutable `nowOf`, next-Sunday supersession, failed append, tap across 04:00, llena default)
- [x] `test/ui/dispenser/ambient_strip_test.dart` -- rendering pins (question verbatim, hairline, labels), digit tap → row → handoff, ✕ vs stale read, 200% floor over the 5×48dp row

**Acceptance Criteria:**
- Given Sunday's first opening with the due week unanswered, when the read commits, then the strip holds the hairlined report with the question verbatim and `reportWeekOrdinal` 1390, the check-in displaced not consumed
- Given a digit tap, when the write lands, then exactly one `report_answered` row carries `{value, the asked week}` and the same opening's read hands the slot to the check-in
- Given ✕, when the dismissal commits, then nothing is written, the check-in takes the slot in that opening, and the report returns at the next day's first opening
- Given the 2-5 shell matrix, when the field translation lands, then every behaviour pin holds with unchanged semantics
- Given the completion gate, then `make codegen-check`, `make check`, `make test` and `make gate` are green

### Review Findings

- [x] [Review][Patch] The failed-append recovery read of `_onAnswerReport` unverified at the screen — the check-in's `:354` widget twin added [test/ui/dispenser/ambient_strip_test.dart]
- [x] [Review][Patch] The report paths' in-flight guard unverified — the `:393` pending-write twin added (✕ pending, stale digit tap refused, zero rows) [test/ui/dispenser/ambient_strip_test.dart]
- [x] [Review][Patch] `_onAnswerReport`'s generation bump unverified — the `:783` stale-read twin added over a controllable `answerReport` [test/ui/dispenser/ambient_strip_test.dart]
- [x] [Review][Patch] Same-day second `app_opened` after a dismissal: the marker lifts and the derivation hides anyway — the layering unpinned [test/dispenser/dispenser_controller_test.dart]
- [x] [Review][Defer] `_appOpensOn` re-implements the core's opening-census convention across the shell boundary — deferred, core read-only this story [lib/dispenser/dispenser_controller.dart]
- [x] [Review][Reject] Asked-week capture vs interleaved stale reads, dismissal not clearing the ask, double-answer idempotence — the spec's frozen field shape (sanctioned at the register), surface-guarded windows, refusal-as-silence semantics
- [x] [Review][Reject] Check-in-✕→report handoff direction (unreachable: the report outranks and holds the slot while eligible), future-resident fallthrough assert, dismissal failure-path asymmetry (2-5's verbatim shape), bare-numeral semantics grouping (self-labeled text, ladder-pill precedent), test-literal/seed style points (the file's established conventions), reflow label↔digit correspondence (direction preserved), report-below-offer/close pin (mounting shared and pinned), clock-rollback census drift (the derivation's own recorded convention)

## Spec Change Log

## Design Notes

- **Why the pending week is read-carried.** The row must answer the week the user was asked (AD-21's explicit target week); re-deriving the week at tap time would answer a different question after a boundary. The write-then-read queue makes the last read's ordinal race-free.
- **Why two marker scopes.** FR-4 fixes each: the check-in dismissal is skip-for-today; the report dismissal frees the opening only. The `app_opened` census keys the report's re-arm without storing any pending state — the derivation still decides on its own rows.
- **Why exclusions-in-derivation.** One derivation call stays the whole read; suppression never mutates the log, so the same log without the markers resolves identically (the seam's read-scoped contract, strip.dart:264-269).

## Verification

**Commands:**
- `devbox run -- make codegen` -- expected: gen-l10n accessors regenerated; then `make codegen-check` clean with churn committed
- `devbox run -- make check` -- expected: purity, string audit (digits through the ARB placeholder, no literals), text scaling, census proofs green
- `devbox run -- make test` -- expected: controller and widget suites green, incl. the 2-6 matrix and the translated 2-5 group
- `devbox run -- make gate` -- expected: test, format, analyze all green

## Suggested Review Order

**The controller — the widened read and its two marker scopes**

- The view carries the resident and, for the report, the asked week — the minter's fact
  [`dispenser_controller.dart:35`](../../lib/dispenser/dispenser_controller.dart#L35)

- The interim exclusion deleted; both dismissals composed as read-scoped derivation exclusions
  [`dispenser_controller.dart:233`](../../lib/dispenser/dispenser_controller.dart#L233)

- The opening-scoped marker — skip-for-this-opening, the re-arm keyed by the `app_opened` census
  [`dispenser_controller.dart:171`](../../lib/dispenser/dispenser_controller.dart#L171)

- The asked week travels with the read — the row answers the week the user was shown
  [`dispenser_controller.dart:181`](../../lib/dispenser/dispenser_controller.dart#L181)

- `answerReport` — one row in setEnergy's shape; null asked week or out-of-scale mints nothing
  [`dispenser_controller.dart:622`](../../lib/dispenser/dispenser_controller.dart#L622)

- `dismissReport` — writes nothing; the census read inside the queue
  [`dispenser_controller.dart:667`](../../lib/dispenser/dispenser_controller.dart#L667)

- The census itself — the derivation's own conventions, per-row offset, post-instant exclusion
  [`dispenser_controller.dart:700`](../../lib/dispenser/dispenser_controller.dart#L700)

**The resident — UX-DR22's persistent chrome**

- The hairlined report resident: question verbatim, digits, end labels, ✕ reuse
  [`ambient_strip.dart:296`](../../lib/ui/dispenser/ambient_strip.dart#L296)

- One numeral as a 48dp direct tap target through the ARB placeholder, figure role
  [`ambient_strip.dart:247`](../../lib/ui/dispenser/ambient_strip.dart#L247)

**The screen — mounting by resident**

- The switch: check-in bare, report hairlined; the four later residents unreachable
  [`dispenser_screen.dart:469`](../../lib/ui/dispenser/dispenser_screen.dart#L469)

- The answer handler — 2-5's mechanics verbatim, recovery read on the failed append
  [`dispenser_screen.dart:598`](../../lib/ui/dispenser/dispenser_screen.dart#L598)

- The dismissal handler — the ✕'s shape, no write, empty frame only on a failed read
  [`dispenser_screen.dart:656`](../../lib/ui/dispenser/dispenser_screen.dart#L656)

**The string table**

- The one new key — digits are not literals (AD-15), the duration format's precedent
  [`app_es.arb:316`](../../lib/l10n/app_es.arb#L316)

**The proofs and tests**

- The append census 6→7 and the single `reportAnswered` invocation
  [`no_lateness_proof_test.dart:342`](../../test/no_lateness_proof_test.dart#L342)

- The controller matrix — eleven rows, Sunday clock to supersession
  [`dispenser_controller_test.dart:2392`](../../test/dispenser/dispenser_controller_test.dart#L2392)

- The same-day second opening — the marker lifts, the derivation hides anyway
  [`dispenser_controller_test.dart:2592`](../../test/dispenser/dispenser_controller_test.dart#L2592)

- The widget suite — render, tap→row→handoff, failed append, in-flight guard, stale read, 200%
  [`ambient_strip_test.dart:627`](../../test/ui/dispenser/ambient_strip_test.dart#L627)

---
title: '6-6: The blind six-month follow-up'
type: 'feature'
created: '2026-09-10'
status: 'done'
review_loop_iteration: 0
baseline_commit: 'ed467e6324766364a5bc6948b405f194a3bf4ead'
context: ['_bmad-output/implementation-artifacts/epic-6-context.md']
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** 6-5 mints dated boxes but nothing ever comes back to them — the reserved `StripResident.quarantineFollowUp` (strip.dart:67) is hardcoded ineligible, so the box's date never knocks and hesitation never closes itself (FR-21 unstarted).

**Approach:** Make the knock purely derived: `Calendar` (the only period authority) gains month arithmetic; the strip's eligibility flip decides "today is a non-empty box's six-months-later day" from `deriveQuarantine` and the row instants alone — no stored date, no new log kind, no payload. The resident renders one static date-anchored sentence with the shared ✕; dismissal is the check-in's day-scoped shell marker grammar (no write at all), and the story carries the Epic 5 F-D2 extraction so the new handler is not a fifth copy of the screen's write-path family.

## Boundaries & Constraints

**Always:** Eligibility is `plusMonths(dayOf(box.instantUtcMicros, box.offsetSeconds), 6) == today` for at least one box from `deriveQuarantine` with non-empty contents — empty (orphan/failed-act) boxes never knock. `Calendar.plusMonths(Day, int)` is public on `Calendar` (calendar.dart:204), clamps month-end (Aug 31 + 6 → Feb 28/29), and is the only new core date math. The strip resident carries **no `StripState` payload** — the copy is a single static ARB sentence, date-relative ("hace seis meses"), so no field, no box id, no due-date crossing the read→tap boundary. Dismissal mirrors `dismissCheckIn` exactly: day minted at entry from the tap instant, no log read, no write, marker keyed by `Day`; `read()` adds the resident to `excludeResidents` when the marker is today (dispenser_controller.dart:425 grammar). The strip widget is the `SelfReportStrip` wrapper minus the numerals: hairlined (it persists across openings within its day), one ≥48dp sentence in the support role ink-secondary, `_DismissMark` reusing `ambientStripDismiss`. One new ARB key `quarantineFollowUpCopy` with copy `Hace seis meses fechaste una caja. Hoy es un buen día para donarla.` (proposed — date-anchored, suggests donation per FR-21, claims nothing about contents or use, ADR-12). F-D2: extract the screen's strip-act mechanics (in-flight guard → generation bump → settle → controller call → commit/recovery → release) into one seam with the two failure policies (recovery-read vs empty-frame) and route `_onSetEnergy`, `_onDismissCheckIn`, `_onAnswerReport`, `_onDismissReport`, `_seasonalSuggestionWrite` **and** the new dismiss through it — existing screen tests pin all five and must stay green.

**Ask First:** None — the once-only shape follows the AC pair ("no side effects" + "never returns") which only the day-window derivation satisfies; renegotiate the ARB copy or the empty-box exclusion before inventing any persisted dismissal.

**Never:** No new `LogKind`, no dismissal row, no stored follow-up date, no tombstone (AD-1, AD-21, AD-25; spine line 334). No accept/answer path on the resident — the donation suggestion is the copy's whole job; acting on the physical box is the user's. No box-contents surface, no date picker, no per-box targeting (multiple same-day boxes are one resident and one knock). No change to `stripResidentPrecedence` or other residents' eligibility. No volume/count figure on any surface (6.7). No fifth write-path copy (F-D2, epic-5 retro :95 — mandated by the epic re-partition).

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Due day, app opened | Non-empty box; today == box date + 6 months | Resident shows (precedence slot 2), static copy, hairline | N/A |
| Dismissal | ✕ tapped on the due day | Marker day set; resident hidden; zero store writes, zero log rows | N/A |
| Day after due | Read on any later day | Resident never eligible again — window derived-closed, nothing stored | N/A |
| App unopened on due day | No open that day | Knock silently missed — "at most once" allows zero (honest abandonment) | N/A |
| Displaced by rarer resident | Curation offer live on the due day | Follow-up not shown, not consumed; re-offers at next opening same day (UX-DR22 displacement) | N/A |
| Empty/orphan box due | `box_created` with no linked quarantine rows | No knock — contents-empty boxes are write-failure artifacts, not decisions | N/A |
| Two boxes, same due day | Both non-empty, due today | One resident, one static copy — no per-box surface | N/A |
| Process death after dismiss | Marker lost, same due day, app reopened | Re-offer within that day only (the `_checkInDismissMarker` family's accepted shape); never from the next day on | N/A |
| Month-end box | Box dated local Aug 31 | Due Feb 28 (29 in a leap year) — `plusMonths` clamp | N/A |
| 4am boundary | Box created 02:00 local | Its day is the previous civil day (Calendar's `_fourAmLocal`) — due day computed from that | N/A |

</frozen-after-approval>

## Code Map

- `packages/core/lib/day/calendar.dart:204` -- `Calendar`, the only period authority; `dayOf`, `_fourAmLocal`. Add `plusMonths(Day, int)` (DateTime.utc month add + end-of-month clamp); pin in `calendar_test.dart`.
- `packages/core/lib/derive/strip.dart` -- `StripResident` (:60, `quarantineFollowUp` :67 doc'd "Epic 7's once-per-box follow-up" — stale doc, fix to 6.6), precedence slot 2 (:98, untouched), `_residentEligible` case `quarantineFollowUp: return false` (:203 — the flip site; reuse `deriveQuarantine` — same package, no weave cycle), `deriveStrip` (:430) already takes `instantUtcMicros`/`offsetSeconds`/`excludeResidents` — no signature change.
- `packages/core/lib/derive/quarantine.dart:42,56` -- `QuarantineBox` (id, instantUtcMicros, offsetSeconds, contents), `deriveQuarantine`. The eligibility input; its doc already says "6.6's derivation, computed from `instantUtcMicros`, never stored".
- `lib/dispenser/dispenser_controller.dart` -- `_checkInDismissMarker` (:326, the grammar to mirror incl. its doc rationale), `read()`'s `excludeResidents` composition (:425-433), `dismissCheckIn` (:1104, the mirror body: day at entry, no read, return `read()`). Add `_quarantineFollowUpDismissDay` + `dismissQuarantineFollowUp` + the exclude line.
- `lib/ui/dispenser/ambient_strip.dart` -- `_DismissMark` (:88, shared ✕, 48dp, `ambientStripDismiss`), `SelfReportStrip` (:446 — the hairlined wrapper: `surfaceContainerHighest` + 1px `outline` + `radiusDefault`); `QuarantineFollowUpStrip` joins them (~line 500, file is 523 lines).
- `lib/ui/dispenser/dispenser_strip_layer.dart:141` -- the `quarantineFollowUp || snowball => child` placeholder branch — becomes `quarantineFollowUp => QuarantineFollowUpStrip(onDismiss: …)`, `snowball => child` alone with its comment fixed.
- `lib/ui/dispenser/dispenser_screen.dart` -- the F-D2 family: `_onSetEnergy` (:952), `_onDismissCheckIn` (:1008), `_onAnswerReport` (:1050), `_onDismissReport` (:1110), `_seasonalSuggestionWrite` (:1176); shared primitives `_writeInFlight` (:266), `_releaseWriteAfterRefreshFrame` (:372), the wiring block (:907-910). One extracted seam; new `_onDismissQuarantineFollowUp` through it.
- `lib/l10n/app_es.arb:526` -- `ambientStripDismiss` ("Cerrar") reused; `quarantineFollowUpCopy` lands in the strip-keys neighborhood (:464-541) with its `@` description.
- `packages/core/test/` -- `calendar_test.dart`, strip/quarantine derive tests — eligibility pins.
- `test/dispenser/dispenser_controller_test.dart:41` -- `_RecordingStore` (+ failure stores :65-297) — no-write and exclusion pins.
- `test/ui/dispenser/ambient_strip_test.dart:44,285` -- `_RecordingStore`/`_harness` — render/dismiss/hairline pins.
- `test/ui/dispenser/dispenser_screen_test.dart:69` -- `_RecordingStore`; strip groups :6298-7025 — F-D2 regression cover (the five families' pins stay green).
- `_bmad-output/implementation-artifacts/deferred-work.md:313` -- the F-D2 entry this story resolves; mark it resolved (edit in place, do not delete).

## Tasks & Acceptance

**Execution:**
- [x] `packages/core/lib/day/calendar.dart` -- `plusMonths(Day day, int months)`: pure month arithmetic on `DateTime.utc`, end-of-month clamp, doc'd as the period authority's only month math -- the six-month compute needs it and nothing else may grow one.
- [x] `packages/core/lib/derive/strip.dart` -- flip `_residentEligible`'s `quarantineFollowUp` to the due-day fold over `deriveQuarantine` (non-empty boxes only); fix the enum doc's "Epic 7" provenance; no payload on `StripState` -- AD-1/AD-21.
- [x] `lib/dispenser/dispenser_controller.dart` -- `_quarantineFollowUpDismissDay` marker + `dismissQuarantineFollowUp({DateTime? tapTime})` mirroring `dismissCheckIn`; the `excludeResidents` line in `read()` -- write-free dismissal.
- [x] `lib/ui/dispenser/ambient_strip.dart` -- `QuarantineFollowUpStrip`: hairlined wrapper, one static sentence (support role, ink-secondary, ≥48dp target), `_DismissMark` ✕, no accept path -- FR-21/UX-DR22.
- [x] `lib/ui/dispenser/dispenser_strip_layer.dart` -- the resident's render branch; `snowball` keeps the placeholder alone.
- [x] `lib/ui/dispenser/dispenser_screen.dart` -- F-D2 extraction: one strip-act seam (guard, generation bump, settle, controller call, commit, release; recovery-read vs empty-frame policy), route the five existing handlers and the new `_onDismissQuarantineFollowUp` through it -- no fifth copy.
- [x] `lib/l10n/app_es.arb` -- `quarantineFollowUpCopy` + `@` description -- AD-15 single table.
- [x] Tests: `plusMonths` pins (same-day, month-end clamp, leap Feb); eligibility pins (due today / not yet / window closed / empty box / two boxes one resident / displacement-not-consumption); controller no-write + exclusion + day-turn pins; strip render/dismiss/hairline pins; the five F-D2 families' existing suites green -- cover the matrix.
- [x] `_bmad-output/implementation-artifacts/deferred-work.md` -- mark the F-D2 entry (:313) resolved by this story.

**Acceptance Criteria:**
- Given a non-empty box six months old today, when the dispenser reads, then the follow-up resident appears on the ambient strip with copy phrased on the date alone — no contents or use claim anywhere in the ARB sentence.
- Given the ✕ tap, when the store and log are inspected, then nothing was written and the resident is hidden for that day — and no read on any later day can make it eligible again for that box.
- Given an empty box (no linked quarantine rows) at its six-month mark, when the strip derives, then no follow-up appears.
- Given the five pre-existing strip handlers and the new dismiss, when the screen is audited, then all six route through one extracted seam and none of the six repeats the guard/bump/settle/commit/release mechanics — the curation pair's push-after-commit copy stays out of scope (its mechanics differ), as the Boundary's five-handler list already fixes.

### Review Findings

- [x] [Review][Patch] `_stripAct`'s two blanking catch sites lacked the success path's supersession guard — a stale failed act could blank a view a newer refresh committed; `mounted && generation == _readGeneration` added to both
- [x] [Review][Patch] Stale double doc blocks on `_onSetEnergy`/`_onAnswerReport`/`_onDismissReport` left by the extraction (one still claiming "mechanics verbatim") — rewritten to single truthful blocks
- [x] [Review][Patch] `plusMonths` doc claimed totality/symmetric negatives while `~/` truncates them — doc now states the real domain (non-negative months, real-instant `Day`s); no range guard added (out of domain)
- [x] [Review][Patch] The `month + 1 == 13` normalization branch was never executed — June-sealed pin added
- [x] [Review][Patch] The no-accept-path Semantics check was vacuous (loop over explicit Semantics ancestors that plain Text never has) — replaced by a merged-semantics probe, mutation-verified to fail on `Semantics(button: true)`
- [x] [Review][Patch] Leftover scaffolding comment in `ambient_strip_test.dart` deleted
- [x] [Review][Patch] Hand-rolled 20-field box `LogEntryRecord`s (×3 across two app test files) compacted into group-local `boxRow`/`intoBoxRow` helpers (the `strip_test` pattern)
- [x] [Review][Patch] The follow-up ✕ lacked the family's stale-read/in-flight interleave pin — added
- [x] [Review][Patch] "A later day never re-offers" pinned the standing resident explicitly instead of `isNot(quarantineFollowUp)`
- [x] [Review][Patch] `_quarantineFollowUpDue`'s deliberate full-fold cost (false ~179/180 days) now stated in its doc
- [x] [Review][Patch] The seam's empty-frame failure arm (`recoverOnFailure: false`) was unreachable by any test through a seam-routed dismissal — `_FailReadWhileArmedStore` ✕ test added (quiet empty frame, zero rows, healed re-read); the 5-12 deferral it closes marked resolved in `deferred-work.md`
- [Reject] ARB verb `fechaste` — the copy is the human-approved frozen intent ("the box I dated" is the epic's own language); reviewer lacked that context
- [Reject] `RangeError` guard for ±271821-year overflow — out of the function's real domain
- Given a log containing boxes, when `deriveStrip` runs twice with the same entries and instants, then the result is identical — no state outside the inputs (purity, AD-1).

## Spec Change Log

## Design Notes

Why the day-window (and not a persisted dismissal): the AC pair is "dismissal has no side effects" **and** "it never returns for that box" — under an insert-only log with no tombstones (AD-25), the only shape satisfying both is eligibility that expires by derivation: the knock's lifetime is the due day itself. Dismissal is then the check-in's day marker (in-memory, zero writes), and tomorrow the window is closed regardless of any stored fact. The cost is honest and bounded: a process death after dismissing, within the due day, re-offers once — the exact shape the check-in already accepts (`_checkInDismissMarker` doc, dispenser_controller.dart:315-326); and a displacement by a rarer resident (or an unopened day) silently consumes the knock — "at most once" is the PRD's own phrasing for this. Writing a `*_dismissed` row instead would buy permanence by violating the AC's zero-side-effect clause (the seasonal suggestion may write its row because nothing forbids it there; FR-21 does here).

Why non-empty boxes only: an empty box is a 6-5 partial-write artifact (the failed-retry orphan the derivation honestly reconstructs as empty) — the user never completed quarantining anything into it, so knocking about it six months later is noise about a non-decision.

Why no payload on `StripState`: the copy says "hace seis meses", which is today-relative by construction — the due day *is* today. No box id, no date string crosses the read→tap boundary, so there is no staleness surface and nothing for a tap to act on (there is no accept path).

Why `plusMonths` on `Calendar`: AD spine makes `Calendar` the only period authority; month math elsewhere would grow a second. Same-day semantics use the 4am-bounded `Day` throughout, so a 02:00 box belongs to the previous day — consistent with every other day judgement in the app.

F-D2 scope is the screen family only (the five handlers' shared mechanics); the controller's `_enqueueWrite`/`_appendContent` primitives are already single-path and untouched.

## Verification

**Commands:**
- `devbox run -- make gate` -- expected: `flutter test`, format, analyze and repository checks green, including the new calendar/eligibility/no-write/F-D2 pins and the five families' existing suites.

## Suggested Review Order

**The derived knock (AD-1 made visible)**

- The whole eligibility in one function: due iff a non-empty box's day + 6 months is today — no stored date.
  [`strip.dart:283`](../../packages/core/lib/derive/strip.dart#L283)

- The flip site: the reserved case stops returning false; doc provenance fixed to 6.6.
  [`strip.dart:233`](../../packages/core/lib/derive/strip.dart#L233)

- The period authority's only month math: end-of-month clamp, non-negative domain doc'd.
  [`calendar.dart:297`](../../packages/core/lib/day/calendar.dart#L297)

**The write-free dismissal**

- The day marker + its exclusion line — the check-in grammar, zero writes.
  [`dispenser_controller.dart:1146`](../../lib/dispenser/dispenser_controller.dart#L1146), [`dispenser_controller.dart:444`](../../lib/dispenser/dispenser_controller.dart#L444)

**The resident surface**

- The one-sentence hairlined strip: no accept path, shared ✕.
  [`ambient_strip.dart:401`](../../lib/ui/dispenser/ambient_strip.dart#L401)

- The render branch; snowball keeps the placeholder alone.
  [`dispenser_strip_layer.dart:154`](../../lib/ui/dispenser/dispenser_strip_layer.dart#L154)

- The authored string, verbatim — date alone, donation suggestion.
  [`app_es.arb:531`](../../lib/l10n/app_es.arb#L531)

**F-D2: the extracted seam**

- One `_stripAct` for guard/bump/settle/act/commit/release, with the recovery-read vs empty-frame policy and the supersession-guarded catch arms.
  [`dispenser_screen.dart:974`](../../lib/ui/dispenser/dispenser_screen.dart#L974)

- The new dismiss — a one-line delegation, the no-fifth-copy proof.
  [`dispenser_screen.dart:1139`](../../lib/ui/dispenser/dispenser_screen.dart#L1139)

- The deferral this closes, marked resolved in place.
  [`deferred-work.md:312`](deferred-work.md#L312)

**Verification**

- Eligibility pins: due today / not yet / window closed / empty box / two boxes / displacement.
  [`strip_test.dart`](../../packages/core/test/strip_test.dart)

- The December clamp branch, executed at last.
  [`day_test.dart:516`](../../packages/core/test/day_test.dart#L516)

- The ✕ over a failing store: quiet empty frame, zero rows, healed re-read.
  [`ambient_strip_test.dart:2249`](../../test/ui/dispenser/ambient_strip_test.dart#L2249)

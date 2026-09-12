---
title: 'Story 7.5: The snowball — the comfortable-day run and the Time Bag suggestion'
type: 'feature'
created: '2026-09-12'
status: 'in-progress'
review_loop_iteration: 0
baseline_commit: '493d3177a1f80c1d9bc1584506b7c915de3ae77a'
context: []
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** FR-23's snowball has no data: the log already holds every `session_started` (with its original pocket), `session_extended`, `session_ended` and `card_done` row needed to judge comfortable days, but nothing derives the run — so the earned offer of a bigger Time Bag can never appear, and the strip's snowball slot is a stub that can never fire.

**Approach:** One pure derivation of the comfortable-day run (`derive/comfortable_day.dart`), consumed by the strip's existing snowball slot as a **crossing-day window**: eligible exactly on the day the run first reaches ten (chain of consecutive comfortable days ending yesterday == 10), while the bag sits below its top, with no `time_bag` change row that day. One bare-chrome strip resident (`SnowballStrip`) whose sentence offers the raised bag; the tap accepts through the existing `settingChanged` minter (one row, the shown value), the ✕ dismisses into a shell day-marker that writes nothing. No new LogKind, no schema change, no stored counters anywhere.

## Boundaries & Constraints

**Always:**
- The run is **internal** (§1.1 P2, AD-26): no count, day-total, chain length or run name appears in any copy, surface, or fact that crosses to the shell — the crossing fact the strip carries is the **proposed bag minutes** (`bag + 5`), nothing else.
- A comfortable day = ≥ 1 session belonging to that domestic day + ≥ 1 `card_done` charged to that day (the walk's `_chargedDayOf` attribution: the session's own start day) + **no marathon session that day**; a session belongs to the day of its **own start instant** (AD-19), day identity from the one `Calendar` (AD-4).
- The marathon judgment reads each session's **original** pocket (`SessionStartEntry.pocketMinutes`) **plus that session's own `session_extended` rows** — a chosen extension is never a marathon; the judgment is span (`session_ended.instant − session_started.instant`; the still-open session judged to the read instant) strictly beyond that sum, with **no grace** — the audit stays literal against FR-26 series (a) durations; a start row with no pocket (tolerated import) can fire no marathon (AD-23).
- The run counts **consecutive** comfortable days **ending the day before the read instant** — today never counts until it is over; any non-comfortable day (absence included) breaks the chain; days before the log's first row end the walk.
- Eligibility is the **crossing day exactly**: run length == 10, never ≥ (a chain is 10 on one day only — the window is that day, the 6-6 knock's own pattern: "nothing is stored, no dismissal row exists (AD-21)" and a fully displaced or unopened day misses it, "at most once allows zero").
- Not first-opening-gated (the quarantine follow-up's day-window pattern, not the seasonal's): a rarer resident displacing the first opening re-offers the snowball at the next opening of the same crossing day.
- Suppressed at the top: `deriveTimeBagMinutes < timeBagMostMinutes`, and no `time_bag` `SettingEntry` whose own civil day == today — the accept's own row (and a manual bag change) consumes the window for the day.
- The accept mints from the **shown** fact, never re-derived at tap time (the `reportWeekOrdinal`/`StripSuggestion` grammar); the row rides `settingChanged({key: timeBagSettingKey, value: shown})` — the kind's single sanctioned minter, one row, `_appendContent`'s shared copier.
- Rows after the read instant are skipped (the readers' convention); every value is derived from log facts, nothing stored (AD-1).

**Ask First:** None — every decision is pinned by FR-23/FR-26(a), AD-1/4/19/21/23/26, UX-DR22/52, the epics text and the 6-6/5-13 precedents. The three judgement calls this spec makes — the crossing-day window, the no-grace marathon span, and the authored sentence — are called out in Design Notes for the human's eye at approval.

**Never:** No new LogKind, schema column, minter or write path beyond the reused `settingChanged` (the store seal and vocabulary stand untouched); no dismissal row of any kind (declining has no effect — FR-23 literal); no streak/count surfacing anywhere; no `seguir` variant or continuation prompt; no new chrome (bare strip grammar, ✕ at `touchTargetMin`); no Time Bag accumulator or wallet arithmetic (2-3's ban); no walk change (`walkLog` untouched — the fold pairs sessions the same way but lives beside it); no change to any other resident's eligibility or precedence; no warm-return contact change (nothing new is written on dismiss); the bag raise never exceeds `timeBagMostMinutes` (minter range + eligibility guarantee `bag + 5 ≤ 30`).

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Crossing day, bag < 30 | chain ending yesterday == 10; no `time_bag` row today; not excluded | Snowball holds the slot (if no rarer resident stands), sentence offering `bag + 5`, shown fact carried in `StripState` | — |
| Run of 9 or 11 | chain == 9; or a later day of a chain past 10 (window consumed/passed) | Not eligible, nothing renders | — |
| Bag at top on crossing day | `deriveTimeBagMinutes == 30` | Not eligible — nothing left to suggest (FR-23) | — |
| Accept (tap sentence) | shown fact at entry | Exactly one `setting_changed` row (`time_bag`, shown value); resident gone by derivation (row-today guard); later same-day openings show nothing; next suggestion needs a fresh chain (window + `== 10` reset it structurally) | Failed append: nothing lands, suggestion stands next read |
| Dismiss (✕) | one tap | Zero rows; day-marker hides for the day; slot hands to the next resident in the same opening; never returns for this run | — |
| Same-day reopen after accept or manual bag change | `time_bag` row whose day == today | Not eligible | — |
| Marathon day | some session's span > its original pocket + its extensions | Day not comfortable; chain breaks there | — |
| Extended session | span ≤ original + extensions (the user chose them) | Comfortable on that axis — the extension never a marathon (AD-19) | — |
| Open session at read | no matching `session_ended` | Judged span-so-far vs pocket; its day is its start day; today never counts anyway | — |
| Unbounded sitting | start row with null pocket | Session and dones count; no marathon can fire (AD-23 tolerance) | — |
| Superseded session | new start while one open | Pairing and extension attribution mirror `walkLog`'s supersede discipline | — |
| Rarer resident on the crossing day | seasonal/report/curation/follow-up eligible | Rarer resident holds the slot; snowball re-offers at the next same-day opening; a fully displaced day misses the run (6-6 precedent) | — |
| Stale accept tap | tap after a newer read replaced the view | Shown fact consumed at entry; no row mints | — |
| Rows after read instant | future-dated/flawed rows | Skipped by the fold | quiet |

</frozen-after-approval>

## Code Map

- `packages/core/lib/derive/strip.dart:93,113-120,256-258,501-545` -- the slot exists: `StripResident.snowball`, its precedence place, the `return false` stub, and `deriveStrip`'s signature (already receives `entries`, `instantUtcMicros`, `offsetSeconds`, `excludeResidents` — everything the fold needs). `_residentEligible`'s snowball branch becomes the eligibility conjunction; the doc comment at :178-186 and the enum doc at :93-94 update to name the sixth implemented resident.
- `packages/core/lib/derive/strip.dart:125-160` -- `StripState` gains `snowballProposedMinutes` (`int?`, non-null exactly when `resident == snowball`) — the shown fact both one-tap paths carry, the `suggestion` field's own grammar.
- NEW `packages/core/lib/derive/comfortable_day.dart` -- `comfortableDayRunLength({required entries, required instantUtcMicros, required offsetSeconds}) → int`: pairs sessions and attributes `card_done` exactly as the walk does (`packages/core/lib/weave/session.dart:240` `_chargedDayOf`; supersede discipline per `session_test.dart:632-650`), judges each session by its original pocket + own extensions (`log_entry.dart:427-470` — the start row keeps the original, the extend rows their added minutes), folds per-`Day` comfort, then counts consecutive comfortable days back from yesterday. The AD-26 crossing surface: one length, no per-day detail leaves the file.
- `packages/core/lib/settings/settings.dart:16-43,121` -- `timeBagLeastMinutes`/`timeBagMostMinutes`/`timeBagSettingKey`/`deriveTimeBagMinutes` consumed verbatim; no edit.
- `packages/core/lib/commands/settings_commands.dart:37-79` -- `settingChanged({key, value})`, the single sanctioned minter the accept reuses; no edit.
- `lib/dispenser/dispenser_controller.dart:372,462-476,512,1299-1380` -- the pattern donors: `_shownSuggestion`'s read-carried grammar, the `excludeResidents` composition, `:512`'s stash site, `dismissSeasonalSuggestion`/`acceptSeasonalSuggestion`'s consume-at-entry shapes. Add `_shownSnowballMinutes`, `acceptSnowball({DateTime? tappedAt})`, `dismissSnowball({DateTime? tapTime})` (the `_checkInDismissMarker` day-marker shape at :327/:1195 — no write), and the marker's line in `read()`'s exclusion list.
- `lib/ui/dispenser/ambient_strip.dart:100-110,255-350` -- `_DismissMark` (its semantics label becomes overridable — the snowball passes `snowballDismissAcknowledgement`, UX-DR52's `Está bien así.`) and `SeasonalSuggestionStrip` — the exact skeleton `SnowballStrip` copies: support sentence `bodySmall`/ink-secondary, `Semantics(button)` + opaque `GestureDetector` + `minHeight: Spacing.touchTargetMin`, null fact renders `SizedBox.shrink`, bare chrome.
- `lib/ui/dispenser/dispenser_strip_layer.dart:157-160` -- the `snowball => child` placeholder becomes the `SnowballStrip` wiring (suggestion + callbacks params, the quarantine/seasonal arms' shape).
- `lib/ui/dispenser/dispenser_screen.dart:989,1059` -- the mount site (`resident:` + per-resident callbacks) and `_stripAct`'s write-then-read + generation bump the two new callbacks ride.
- `lib/l10n/app_es.arb:662-665` -- `snowballDismissAcknowledgement` already shipped ("Está bien así.", description "Snowball suggestion dismissal."), currently unused — this story wires it, no rewording. NEW `snowballSuggestion(minutes)`: `¿Subimos la bolsa de tiempo a {minutes} minutos?` with an `@` description carrying FR-23 + the no-count/no-deficit rule + the atomic-numeral note; then `make codegen`.
- NEW `packages/core/test/derive/comfortable_day_test.dart` -- machine-side matrix on the `impact_test.dart` convention (`test/derive/impact_test.dart:35-104` builders): comfortable day, missing session, missing done, marathon (strict span), extension excused, open session, unbounded sitting, supersede, absence breaks the chain, today never counts, pre-log days stop the walk, rows after read instant.
- `packages/core/test/strip_test.dart:116` -- the never-eligible pin flips; add the eligibility matrix (== 10 crossing, 9, 11, bag top, `time_bag` row today, exclusion marker, precedence below seasonal, the carried `snowballProposedMinutes`).
- `test/ui/dispenser/ambient_strip_test.dart:50-320` -- the harness/fakes convention; add the snowball arm: sentence + numeral rendering, accept appends exactly one `setting_changed` row naming the shown value, stale-tap guard, dismiss writes nothing and hands the slot to the next resident in the same opening, ✕ semantics label, 200 % scale touch-target sweep, displacement re-offer at a later same-day opening.
- `test/dispenser/dispenser_controller_test.dart` + `packages/core/test/no_lateness_proof_test.dart:581-660` -- controller unit pins for the two paths; the append census gains the one new `settingChanged(` site pin (5-13's pattern).

## Tasks & Acceptance

**Execution:**
- [ ] NEW `packages/core/lib/derive/comfortable_day.dart` -- the run derivation, session pairing and original-pocket judgment mirroring the walk.
- [ ] `packages/core/lib/derive/strip.dart` -- the eligibility conjunction, `StripState.snowballProposedMinutes`, the resident/enum docs.
- [ ] NEW `packages/core/test/derive/comfortable_day_test.dart` + `packages/core/test/strip_test.dart` edits -- the machine-side matrix.
- [ ] `lib/dispenser/dispenser_controller.dart` -- `_shownSnowballMinutes`, `acceptSnowball`, `dismissSnowball`, the exclusion line.
- [ ] `lib/ui/dispenser/ambient_strip.dart` + `lib/ui/dispenser/dispenser_strip_layer.dart` + `lib/ui/dispenser/dispenser_screen.dart` -- `SnowballStrip`, the ✕ label override, the wiring.
- [ ] `lib/l10n/app_es.arb` + `make codegen` -- `snowballSuggestion(minutes)`, generated files committed.
- [ ] `test/ui/dispenser/ambient_strip_test.dart` + `test/dispenser/dispenser_controller_test.dart` + `no_lateness_proof_test.dart` -- the widget/unit/census pins.

**Acceptance Criteria:**
- Given ten consecutive comfortable days ending yesterday and a bag below its top, when the strip derives, then the snowball holds the slot unless a rarer resident stands, carrying exactly `bag + 5` as the shown fact — and on no other day of that run (FR-23).
- Given the comfortable-day run, when any surface or copy is audited, then no count, chain length or run name exists anywhere — the offer's grounding is the moment, never a number (§1.1 P2, AD-26).
- Given the Time Bag already at 30, when eligibility derives, then the suggestion does not appear — nothing left to suggest (FR-23).
- Given accept, when the row lands, then the bag rises by exactly 5 minutes capped at 30 via one `setting_changed` row, and no later day of the same run shows the suggestion — the next one is earned by a fresh ten after a break (FR-23, AD-1).
- Given dismiss, when its scope is evaluated, then zero rows were written, the resident is hidden for the day, and it never returns for this run — dismissal is no permanent loss and never a nag (FR-23, UX-DR52).
- Given a session the user chose to extend, when the predicate reads its pocket, then it reads the original plus that session's own extensions — the extension is never scored as a marathon (AD-19).
- Given the ✕, when voiced by semantics, then it speaks `Está bien así.` — the authored dismissal (UX-DR52).
- Given `make gate`, when it runs, then all targets pass — no seal edits, no forbidden-vocabulary hits, string-table audit and codegen green.

## Spec Change Log

## Design Notes

- **Why a crossing-day window, not standing eligibility with a persisted dismissal:** the user story says "offered once, after ten comfortable days, and never otherwise" — eligibility `== 10` (the chain is 10 on exactly one day) makes once-ness, the accept's run reset, and dismissal's no-nag scope all **structural**: nothing stored (AD-21), declining writes literally nothing (FR-23's "declining has no effect" in its purest form), and the 6-6 quarantine knock is the house's own blessed precedent for a one-day window closed by derivation alone. The alternative (eligible while `≥ 10` + a new `snowball_dismissed` LogKind scoped to the run) buys re-offering after a manual bag change at the cost of a new kind, a run-scoped suppression fold, and an accept-reset mechanism — machinery the once-offer reading does not need. The trade: a crossing day fully displaced by a rarer resident misses the run ("at most once allows zero") — accepted, rare, invisible, and cheaper than the alternative's whole vocabulary.
- **Why no grace on the marathon span:** durations are FR-26 series (a) facts and the comfort audit must read literally from them; a grace band invents a second threshold the export cannot audit. False marathons (a process death hanging the session open, a late foreground notice) are rare, invisible, and cost only a later suggestion — the count may only err against appearing, never toward nagging.
- **Why the sentence names the destination, not the step:** `¿Subimos la bolsa de tiempo a {minutes} minutos?` shows the concrete bag the tap produces (the Settings surface's own name, "bolsa de tiempo"), keeps one decision, and grounds nothing in a count; the offer's being *earned* is the moment it appears, not prose about it.
- **Why not first-opening-gated:** the seasonal chose the day's first opening; the quarantine chose the whole day. The snowball's window is one day and it is the run's only one — the whole-day pattern maximizes it and re-offers after a rarer resident resolves within the day, the same displacement rule 6-6 recorded.

## Verification

**Commands:**
- `devbox run -- make gate` -- expected: check (incl. text-scaling, no-literal-strings, string-table audit, forbidden vocabulary), test, format-check, analyze all green.
- `wc -c` on this spec ≤ 24576 bytes at review presentation.

**Manual checks (if no CLI):**
- On the emulator per the AGENTS.md recipe, seed ten consecutive comfortable days (per day: `session_started{pocket}` + `card_done` + `session_ended` inside the pocket) plus an eleventh day's facts — the crossing day shows the sentence with `bag + 5`; tap → the bag reads +5 in a pulled-substrate `setting_changed` row and the strip is quiet; a re-seeded dismiss day appends no row; the day after the crossing shows nothing.

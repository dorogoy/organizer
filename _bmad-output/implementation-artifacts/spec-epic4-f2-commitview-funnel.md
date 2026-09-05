---
title: 'Epic 4 F2: funnel non-answer write-path commits through _commitView'
type: 'bugfix'
created: '2026-09-05'
status: 'done'
baseline_commit: 'abb23ce224afaabe573b27dc1aa28f8584e78420'
review_loop_iteration: 0
context:
  - '{project-root}/_bmad-output/implementation-artifacts/epic-4-retro-2026-09-05.md'
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** The FR-5 auto-rescue heuristic fires only for deals committed via `_commitView` (launch/resume/Hecho/skip paths); nine non-answer write sites (pocket declare, energy answer, report answer, pause, extend, both dismissals, plus two recovery reads) commit views directly, so a warranted deal minted or refreshed by those controls never auto-fires — FR-5's promise silently depends on which control produced the deal.

**Approach:** Replace each site's `_endRescueMarkersIfDealEnded(view); setState(() => _view = view);` pair with `_commitView(view)` at the same position (inside the generation-checked block, before the site's post-frame release bookkeeping), making `_commitView` the single commit owner; add the missing test pins for declare- and extend-minted warranted deals.

## Boundaries & Constraints

**Always:** keep each site's `releaseAfterRefresh = true; _releaseWriteAfterRefreshFrame();` and `_readGeneration` bookkeeping untouched; the only behavior change allowed is the heuristic firing (plus marker handling already inside `_commitView`); run the completion gate inside devbox.

**Ask First:** any discovered behavioral delta beyond the heuristic (e.g. the ack latch proving non-inert at a site); any edit to `_commitView`, `_onRescue`, controller, or core code.

**Never:** no marker re-keying to deal identity (known theoretical gap, retro F1 note — out of scope); no view-arm split of `dispenser_screen.dart` (separate wagon); no new user-facing strings; no changes to empty-frame `setState(() => _view = null)` catch paths.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|---------------|----------------------------|----------------|
| Declare-minted warranted deal | log has ≥3 distinct eligible decline days for the item; nothing standing; user taps pocket ladder | `declarePocket` read bundles first `card_dealt`; heuristic fires exactly once (`slice_requested` +1) | N/A |
| No refire while deal stands | later lifecycle refresh after the fire above | no additional `slice_requested` (fire-marker + activation counter hold) | N/A |
| Strip write over warranted standing deal | warranted card standing; user taps energy numeral or a ✕ dismissal | heuristic fires once at that commit | N/A |
| Non-warranted deal | same write paths, <3 decline days | no fire; behavior identical to today | N/A |
| Rescue already in flight | heuristic fires while `_rescueFlightDealId` set | `_onRescue` no-ops; no second flight | flight guard |
| Failed write → recovery read | controller write throws; catch commits `read()` | same funnel; standing surface restored as today | existing catch |
| Completion-ack interaction | `_completionAckWaiting` set only by `_onDone`, which holds `_writeInFlight` while these sites early-return | ack state inert at all nine sites; funneling must not surface the ack | N/A |

</frozen-after-approval>

## Code Map

Line anchors are pre-implementation; after the F2 edit the nine sites sit 1–6 lines above their cited positions.

- `lib/ui/dispenser/dispenser_screen.dart` -- `_commitView` :608-647 (ack latch :609-626 — inert at the sites; heuristic :627-637 fires when `view is DispenserDealt && view.autoRescueDue && !view.rescueStep && _autoRescueFiredForDeal != view.card.id` → `unawaited(_onRescue(view))`; marker-end :646 runs after the heuristic). Nine sites to funnel (current lines, post-f56b47a): `_onSetEnergy` :801 and catch :816, `_onDismissCheckIn` :856, `_onAnswerReport` :903 and catch :918, `_onDismissReport` :959, `_onDeclarePocket` :1133, `_onPause` :1180, `_onExtend` :1231 — each currently the two-line pattern followed by release bookkeeping. `_onRescue` :448-534 (flight guard :449; F1 deal-stands guards :473-478 and :494-499; auto-decline marker :517). Site doc comments (:1117, :1163-1164, :1215) state ack inertness — keep truthful.
- `lib/dispenser/dispenser_controller.dart` -- read-only seam: writes return fresh reads (`declarePocket` :728, `pause` :761, `extend` :793, `setEnergy` :825, `dismissCheckIn` :846, `answerReport` :869, `dismissReport` :900); `autoRescueDue` computed at read time :458-468.
- `packages/core/lib/derive/rescue.dart` -- warrant source of truth, read-only: `rescueWarranted` :172-187, `rescueDeclineDays` :130-163, threshold `captureDealWindowEligibleDays = 3` (`packages/core/lib/derive/eligible_day.dart:67`).
- `test/ui/dispenser/dispenser_screen_test.dart` -- pin patterns to mirror: launch-borne pin :2771 (seed 3 decline days :2811-2829, row assertions :2846-2852), per-deal marker pin :2873, declined-count pin :2989 with `_CountingDecliningController` :279-295; F1 regression :2509 with `_IndependentSlicer` :656-664; helpers `_RecordingStore` :60, `_harness` :632-650, `buildController` :669-679.
- `_bmad-output/planning-artifacts/prds/prd-organizer-2026-08-20/prd.md` -- FR-5 wording :165-172.

## Tasks & Acceptance

**Execution:**

- [x] `lib/ui/dispenser/dispenser_screen.dart` -- at the nine sites, replace the `_endRescueMarkersIfDealEnded(view); setState(() => _view = view);` pair with `_commitView(view)` at the same spot; confirm each site's doc comment stays truthful; no other edits to the file.
- [x] `test/ui/dispenser/dispenser_screen_test.dart` -- add pin: "the auto-heuristic fires at a deal minted by a non-answer write — pocket declare (FR-5)" — seed 3 decline days, nothing standing, tap the ladder, assert exactly one `slice_requested` after the deal's `session_started`/`card_dealt` pair and no refire on a later refresh; add the same-shape pin for an extend-bundled close-continue deal.

**Acceptance Criteria:**

- Given 3 distinct eligible decline days and no standing card, when the user declares a pocket that mints the warranted item's deal, then exactly one rescue flight starts at commit and none repeats on later refresh.
- Given a warranted standing deal whose fire-marker is already set, when any of the nine writes commits, then no second flight starts.
- Given all suites at HEAD plus the new pins, when the completion gate runs inside devbox, then everything is green.

## Spec Change Log

## Design Notes

Funnel rather than replicate: `_commitView` becomes the single commit owner, and the heuristic must run before `_endRescueMarkersIfDealEnded` (a stale marker keyed to a different card must not block a warranted new deal). Ack inertness is provable: `_completionAckWaiting` is set only by `_onDone`, which holds `_writeInFlight` through its refresh commit, and every funneled site early-returns under that guard. Interleaving: `_onRescue` deliberately ignores `_writeInFlight`; both it and the site set/release the flag post-frame, idempotently — the same shape as today's tap path; commit at the same position so the site's generation check still governs.

**Ack race (accepted at review, deferred):** `_onDone` releases `_writeInFlight` post-frame without awaiting the refresh whose commit consumes the waiting ack — a write tapped inside that sub-frame window now surfaces the ack at its own commit. Pre-funnel HEAD leaks the same ack to an arbitrary later commit; the funnel does not create the race, only bounds where it lands. Human decision 2026-09-05; deliberate fix (ack-owner token) recorded in `deferred-work.md`.

## Verification

**Commands:**

- `devbox run -- flutter test test/ui/dispenser/dispenser_screen_test.dart` -- expected: all pass, including the two new pins
- `devbox run -- make gate` -- expected: full suite, checks, format and analyze green

**Results (2026-09-05):** focused suite 88/88; `make gate` green — 833 tests, `dart format --set-exit-if-changed` 0 changed, `flutter analyze` clean. Re-verified after review patches (same numbers).

## Suggested Review Order

**The funnel — one commit owner**

- `_commitView` owns every commit: ack latch, FR-5 heuristic, marker-end. Read this first.
  [`dispenser_screen.dart:614`](../../lib/ui/dispenser/dispenser_screen.dart#L614)

- Deal-minting write now commits through the owner — the declare pin's target path.
  [`dispenser_screen.dart:1137`](../../lib/ui/dispenser/dispenser_screen.dart#L1137)

- Close-continue extension, the other deal-minting write — the second pin's path.
  [`dispenser_screen.dart:1233`](../../lib/ui/dispenser/dispenser_screen.dart#L1233)

- Energy answer — representative of the five strip/answer sites (:807, :862, :908, :964, :1183).
  [`dispenser_screen.dart:807`](../../lib/ui/dispenser/dispenser_screen.dart#L807)

**Recovery-read safety (review patch)**

- Failed-write recovery read now generation-guarded — a stale read can no longer overwrite a newer commit or fire on a superseded deal.
  [`dispenser_screen.dart:822`](../../lib/ui/dispenser/dispenser_screen.dart#L822)

- The report path's twin guard.
  [`dispenser_screen.dart:923`](../../lib/ui/dispenser/dispenser_screen.dart#L923)

**Pins**

- Declare-minted warranted deal: one fire, no refire, slicer-request count survives the refresh.
  [`dispenser_screen_test.dart:3084`](../../test/ui/dispenser/dispenser_screen_test.dart#L3084)

- Extension-minted twin, same shape.
  [`dispenser_screen_test.dart:3211`](../../test/ui/dispenser/dispenser_screen_test.dart#L3211)

**Records**

- Two deferrals from review: the pre-existing ack race and the `_onRescue` landing bypass.
  [`deferred-work.md`](deferred-work.md)
- Results 2026-09-05: focused suite 88/88; `make gate` green -- 833 tests passed, format 0 changed, analyze clean.

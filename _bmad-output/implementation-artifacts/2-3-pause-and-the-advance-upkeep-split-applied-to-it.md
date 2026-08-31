---
title: 'Pause, and the advance/upkeep split applied to it'
type: 'feature'
created: '2026-08-30'
status: 'done'
review_loop_iteration: 1
baseline_commit: 'd2ee82c8d1a26606fb2bfda3db63cd0b69705356'
context: ['FR-9', 'FR-7', 'FR-12', 'AD-1', 'AD-19', 'AD-20', 'UX-DR41', 'UX-DR43', 'NFR9']
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** Stopping mid-session has no dedicated emission — the only user-stops are backgrounding and the declare supersede — and the read model can propose a card no command can answer: `nextDeal` deals sessionless (pinned at `weave_test.dart:276`) while `cardDone` no-ops without an open session (`session_commands.dart:308`), so a paused Dispenser would show a dead card. FR-9's rollback clause also lacks its declared reading, inviting a later Time Bag accumulator.

**Approach:** A quiet always-visible stop control (`Quiero parar`, action-secondary grammar) emitting AD-19's first closing cause through the existing `sessionEnd` command; the resolver's contract aligned with its own doc — no deal exists outside an open session — so the post-pause surface is the standing warm close with the pocket chip as the way back in; the Time Bag's vacuous-rollback reading recorded in the AD-17/AD-20 style and proven by three worked ledger cases.

## Boundaries & Constraints

**Always:**
- One tap, any moment, any reason (UX-DR43): the stop control renders in the Dispenser chrome on BOTH the dealt and closed views, never disabled, never suggested; a tap when no session is open appends nothing (`sessionEnd` no-op) — an accepted quiet no-op, the `PocketTriggerChip` precedent.
- The pause appends exactly one `session_ended` moment row through `DispenserController.pause()` in the `declarePocket` write shape (mint `now` at entry, `_enqueueWrite`, one minted instant, v7 id per row; no catalogue needed — `sessionEnd` reads only the log). The screen's `_onPause` is `_onDeclarePocket`'s mechanics verbatim: `_writeInFlight` guard, `_readGeneration++`, await `sessionSettled`, commit the returned view, release after the refresh frame, absorb a failed write into the empty frame.
- `nextDeal` returns null when no session is open — deals exist only inside sittings, as its own doc already states; `sessionStart`'s bundled first deal (synthesized start present) and `_answered`'s bundle are unaffected. Return after pause: `appOpen` → `sessionStart` deals the next Micro-task directly — no resume menu, no summary, nothing about the past (UX-DR41).
- The declared reading, recorded: the Time Bag is a daily ceiling derived from the setting, never a depleting wallet — FR-9's rollback is satisfied vacuously, nothing was ever subtracted so nothing returns; the accumulator is the rejected alternative, for it would make debt expressible (NFR9). It lands beside 2.1's ceiling text in `settings.dart`'s doc, and the derivation is proven to ignore every non-`setting_changed` row.
- Three worked cases pin the advance/upkeep split (FR-7, FR-12): bag 15 + pocket 10 — the chunk (900 s) waits, upkeep and habits deal within the pocket, and a fuller same-day pocket deals the chunk (slot still open); bag 5 — no chunk exists at all, silently, no debt, no mention; bag 30 — exactly one chunk, the surplus buys nothing, upkeep and habits charged nowhere.
- A session crossing 04:00 paused after the boundary charges its whole ledger to its own start day; the crossed-into day's Focus slot stays untouched (AD-19 — the pause-path variant of the standing `_chargedDayOf` pin).
- The post-pause surface is the standing warm close (`poolExhaustedClose`) with the trigger chip defaulting to 15 (no open session, no pocket fact); recalculation is silent by construction — no toast, banner or announcement; no interrupted, incomplete or overdue state exists in either language (NFR9 lint holds; pause names stay off the forbidden vocabulary).
- The label lands in `app_es.arb` as `actionStop` = `Quiero parar` — the first-person mirror of 2.4's `Quiero seguir` — with a description; accessors regenerated. Text-only, ink-secondary, 48dp opaque target, wrapping (never truncating) at 200% in the footer band beside `Nuevo proyecto`.

**Ask First:** Any second user-visible string or any glyph (the set is pinned at ten); any close-cause payload on the `session_ended` row; any eager close beyond the sanctioned sites; any edit to ARCHITECTURE-SPINE.md to host the reading (code-doc + spec record is 2.1's precedent — a spine edit is the human's call).

**Never:** No `session_extended`, checkpoint surface, interval reading, or `Nada más por el momento` / `Quiero seguir` wiring (2.4); no new LogKind — the pause reuses `session_ended` and mints only through core `sessionEnd`; no resume menu, session summary or pause-state surface; no wallet/accumulator arithmetic on the bag; no walk change to sessionless-deal tolerance (imported rows stay tolerated — only the resolver stops proposing); no shell timer or scheduled write.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Behavior | Error Handling |
|----------|---------------|-------------------|-----------------|
| Pause, card standing | open session, dealt-unanswered card | `[session_ended]` (one row); read → warm close; chip defaults 15 | N/A |
| Pause, closed view | lingering open session (spent pocket / exhausted pool) | `[session_ended]`; surface already the close, unchanged | N/A |
| Pause, nothing open | repeat tap after a pause | no rows, no state change — accepted no-op | silent |
| Return after pause | next `app_opened` handled | `[app_opened, session_started, card_dealt]` — next Micro-task directly | N/A |
| Sessionless read | `read()` with no open session, eligible day | `nextDeal` null → `DispenserClosed`; never a dead card | N/A |
| Failing append | store throws on the pause write | nothing lands; empty frame stands; queue recovers on the next write | quiet |
| Crosses 04:00, paused after | start 03:40, pause 04:10 | ledger charged to the start day; crossed-into slot untouched | N/A |
| Bag invariance | `card_done` / `card_skipped` / session rows appended | `deriveTimeBagMinutes` unchanged — rollback vacuous | N/A |

</frozen-after-approval>

## Code Map

- `packages/core/lib/weave/weave.dart:441-496` -- `nextDeal` gains the no-open-session null; its doc's closing sentence renegotiated (the pause tap joins the sanctioned sites)
- `packages/core/test/weave_test.dart:256-298` -- the `afterEnd` pin flips: post-`session_ended` resolves null; the freed resolver proven via a fresh `sessionStart` bundle; audit every `nextDeal(` site in core tests (~46 in weave_test alone, plus facade/session_commands tests) for sessionless reliance (bag<10 group included)
- `packages/core/lib/commands/session_commands.dart:186-197` -- `sessionEnd` itself unchanged; its doc renegotiated — cause 1 (the user stopping) now carries the pause tap beside the declare supersede; phrase it as "no fourth closing cause and no emission outside the three causes' sites" (the shell append census counts sites and does go to 4 — the doc must not read as forbidding it)
- `packages/core/lib/settings/settings.dart:13-17,74-84` -- the declared vacuous-rollback reading lands beside 2.1's ceiling text
- `packages/core/test/weave_test.dart:549-831` + `packages/core/test/session_test.dart` -- the three worked cases (chunk-waits under pocket 10, bag 5 silent, bag 30 one-chunk-surplus-buys-nothing), the 04:00 pause-path ledger, the bag-invariance proof (no_lateness_proof style: acts appended, derivation unchanged)
- `packages/core/lib/facade/read_facade.dart:44` + `packages/core/test/facade_test.dart` -- sessionless facade reads flip to null; audit pins (shape stays one function); doc-only on the lib side: `nextCard`'s doc states the sessionless-null contract
- `lib/dispenser/dispenser_controller.dart:87-118,218-280` -- `pause()` in the declare shape minus the catalogue (lands after `declarePocket`, ~line 249); `read()` unchanged
- `lib/ui/dispenser/dispenser_screen.dart:318-365,438-501` -- stop control in the footer band on both views; `_onPause` = `_onDeclarePocket` mechanics; the band respects the short-surface floor (see Tasks) — pinned chrome never outranks the accessibility floor
- `lib/ui/dispenser/task_card.dart:75-109` -- `SecondaryTextAction` reused as-is via the label seam
- `lib/l10n/app_es.arb` + regenerated `lib/strings/app_strings*.dart` -- `actionStop`
- `test/no_lateness_proof_test.dart:308-331` -- shell census renegotiation: dispenser append sites 3→4, contentCounts 3→4; wire names unchanged
- `test/ui/dispenser/dispenser_screen_test.dart:422-475` -- `_censusOf` is diff-based (two live surfaces both carrying the stop text), so snapshots need NO edit; presence pins land as `find.text('Quiero parar')` in the parametrized dealt/closed surface tests; new flows: pause→close commit, repeat-tap no-op, silence (no toast/banner types), return-deals-directly via lifecycle faking, stop present on the empty frame, 200% footer wrap with both texts whole, and the short-surface pin at 320×220 (never retargeted)
- `test/dispenser/dispenser_controller_test.dart:974-1249` -- pause matrix mirroring the declare group (reuse the pocket group's `buildFor`, do not duplicate it): `[session_ended]` sequence, no-op when closed, failing store via `_FailNextAppendStore` (nothing lands, chain recovers), post-pause read closed, lingering exhausted-POOL pause, pocketed-unelapsed mid-pause with the card standing
- Test doubles to reuse: `_RecordingStore`, `_FailNextAppendStore`, `launchAndCommit`, `_censusOf`, lifecycle faking `tester.binding.handleAppLifecycleStateChanged`, fixed clock + weave builders `_sessionStarted(micros, {pocketMinutes})`

## Tasks & Acceptance

**Execution:**
- [x] `packages/core/lib/weave/weave.dart` -- no-open-session null in `nextDeal` + doc renegotiation -- the resolver stops proposing unanswerable cards
- [x] `packages/core/lib/commands/session_commands.dart` -- `sessionEnd` doc renegotiation (cause 1's two taps) -- the closing-sites pin stays honest
- [x] `packages/core/lib/settings/settings.dart` -- the declared vacuous-rollback reading -- no later reader implements an accumulator
- [x] `lib/dispenser/dispenser_controller.dart` -- `pause()` write seam -- the one-row user-stop emission
- [x] `lib/ui/dispenser/dispenser_screen.dart` + `lib/l10n/app_es.arb` + regenerated accessors -- stop control + `actionStop` -- one tap, any moment (UX-DR43)
- [x] `packages/core/test/weave_test.dart` + `packages/core/test/session_test.dart` + `packages/core/test/facade_test.dart` -- afterEnd flip, sessionless nulls, three worked cases, 04:00 pause-path, bag invariance
- [x] `test/no_lateness_proof_test.dart` -- dispenser census 3→4
- [x] `test/dispenser/dispenser_controller_test.dart` + `test/ui/dispenser/dispenser_screen_test.dart` -- pause matrix + screen flows + census updates
- [x] `lib/ui/dispenser/dispenser_screen.dart` -- the short-surface floor: the Dispenser lays out with ZERO RenderFlex overflow on the 320×220 @200% class Story 2.2 pinned — when the pinned chrome cannot fit, the chip and footer band join the scroll region together; the accessibility floor outranks pinned chrome (UX-DR45's pin is a comfort, not a truncation license)
- [x] `test/ui/dispenser/dispenser_screen_test.dart` -- the short-surface pin RESTORED at 320×220 @200% asserting `tester.takeException()` is null and both footer tap targets lay out inside the viewport; the pin is never retargeted to match the code
- [x] `test/ui/dispenser/dispenser_screen_test.dart` -- stop present on the empty frame (post-failed-write `_view = null`): the control renders and taps serialize through the guard
- [x] `test/ui/dispenser/dispenser_screen_test.dart` + `test/dispenser/dispenser_controller_test.dart` -- pause race pins mirroring the ack-generation and declare-interleave patterns: a stale launch/foreground read cannot overwrite the committed close (`_readGeneration`), and a pause enqueued behind a completion lands coherently through the shared queue
- [x] `test/dispenser/dispenser_controller_test.dart` -- the two untested matrix rows: pausing a lingering exhausted-POOL session (surface already the close, `[session_ended]` lands), and a pocketed-unelapsed mid-pause with the card standing (chip reads the declared pocket before, 15 after)

### Review Findings

- [x] [Review][Patch] Reflow all Dispenser chrome when it cannot fit [lib/ui/dispenser/dispenser_screen.dart:354]
- [x] [Review][Defer] Separate a successful write from a failed read-back [lib/ui/dispenser/dispenser_screen.dart:550] -- deferred, pre-existing
- [x] [Review][Defer] Recover the Dispenser write guard from a permanently pending dependency [lib/ui/dispenser/dispenser_screen.dart:539] -- deferred, pre-existing

**Acceptance Criteria:**
- Given any rendered Dispenser state, when the surface is inspected, then the stop control is present, tappable and never disabled, and a tap costs exactly one interaction with no confirmation (FR-9, UX-DR43)
- Given a pause tap, when the write lands, then exactly one `session_ended` row appends and the committed view is the warm close with the chip at 15 — nothing else appears (FR-9)
- Given a return after pausing, when `app_opened` is handled, then the Dispenser deals the next Micro-task directly — no resume menu, no summary, no past-facing surface (FR-9, UX-DR41)
- Given the Time Bag, when its derivation is inspected over logs bearing acts, then it reads from `setting_changed` rows alone, the three worked cases hold, and no accumulator exists anywhere (FR-7, FR-9, FR-12)
- Given the 2.2-pinned short surface (320×220) at 200% font scale, when the Dispenser lays out, then no overflow exception occurs and both footer controls lay out inside the viewport — the accessibility floor outranks pinned chrome
- Given the completion gate, then `make check`, `make test-core` and `make gate` are green

## Spec Change Log

### 1 — Review loop 1 (2026-08-30)

- **Trigger:** verification-gap + blind-hunter — a proven 78 px `RenderFlex` overflow on the 320×220 @200% class 2.2 pinned, after the two-control footer band landed as pinned chrome; the one test pinning that surface was retargeted 220→300 inside the same diff, so every gate stayed green while the accessibility floor regressed.
- **Amended:** Tasks/AC add the short-surface floor (the band joins the scroll region — or an equivalent explicit reflow — when pinned chrome cannot fit; the 320×220 pin is restored and never retargeted); tasks added for stop-on-empty-frame presence, pause race/interleave pins, and the two untested matrix rows (exhausted-pool linger, pocketed-unelapsed mid-pause); Code Map corrected (census diffs need no snapshot edits — presence pins are `find.text`; the `nextDeal` audit covers ~46 weave sites plus facade/command tests; `pause()`'s anchor; `read_facade` is doc-only); the `sessionEnd` doc task now demands wording that does not read as forbidding the four-site append census.
- **Known-bad avoided:** an accessibility-floor regression shipping silently because the pin that guarded it was moved to match the code.
- **KEEP:** the `nextDeal` sessionless-null contract and the flipped `afterEnd` pin; the three worked ledger cases and the bag-invariance proof; census 3→4; the controller pause matrix incl. failing-store recovery and return-deals-directly; `_onPause` as `_onDeclarePocket` mechanics verbatim; `actionStop` = `Quiero parar`; the 04:00 pause-path pins; the repeat-tap no-op pins; the silence and 200%-wrap screen tests at their correct surfaces.

## Design Notes

- **Why the resolver change is the pause's other half.** `cardDone`'s side-door guard already refuses sessionless answers, so a sessionless `nextDeal` displays a card no command can answer — a dead surface. Aligning the resolver to its own doc ("what the answering command — or `session_started` — appends") closes the gap once, in the core, instead of per-surface. This decides the deferred scope question (deferred-work's spec-1-7 entry) deliberately: the resolver never proposes sessionless deals; imported rows stay tolerated by the walk, unchanged.
- **The warm close is the stop's presentation.** AD-19: "the warm close presents the stop" — post-pause the standing close surface appears with the chip as the way back in (declare → supersede → next card), exactly the spent-pocket loop 2.2 shipped. Pause needs no surface of its own, which is why recalculation is silent by construction.
- **`Quiero parar`.** No drawn control exists ("solo spine", key-screens-1 §7) and the glyph set is pinned at ten; the label follows the first-person utterance register (`Tengo 15 minutos ahora`, `Quiero seguir`) as that string's direct mirror — 2.4's checkpoint pair keeps its own surfaces and strings. Chrome-level placement (footer band, both views) keeps the card's "one recommended action plus a way out" invariant untouched.
- **Pinned chrome is a comfort, not a license.** UX-DR45 pins chip-above/footer-below so they "never scroll away" — but the floor ("nothing truncated at 200%; surfaces grow and scroll") outranks it: when a short viewport cannot hold the grown chrome, the footer band reflows into the scroll region rather than overflowing. The pin guards the common surface, the floor guards every surface.
- **Known deferred, not re-opened:** multi-row bundle transactionality and the lost-`session_ended` handset wedge (deferred-work 1-6/1-9/1-10/2-2 entries) — the pause row is single-row and atomic; the wedge stays a durability question outside this story's ACs.

## Verification

**Commands:**
- `devbox run -- make codegen` -- expected: l10n regeneration clean, `make codegen-check` green
- `devbox run -- make check` -- expected: purity, forbidden vocabulary (pause naming clean), string-table audit with `actionStop`, text scaling all green
- `devbox run -- make test-core` -- expected: core suites green including the flipped pins and the worked cases
- `devbox run -- make gate` -- expected: test, format, analyze all green

**Manual checks (if no CLI):**
- On a device: pause with a card standing — the close appears, no toast; re-open the app — the next Micro-task deals directly; repeat-tap stop on the close — nothing happens, quietly; both footer texts whole at 200%.

## Suggested Review Order

**The resolver contract — the pause's other half**

- No session open, no deal: the core change everything else hangs off
  [`weave.dart:466`](../../packages/core/lib/weave/weave.dart#L466)

- Why: a sessionless proposal would be a card no command can answer
  [`weave.dart:446`](../../packages/core/lib/weave/weave.dart#L446)

- The facade's doc states the flipped contract (doc-only)
  [`read_facade.dart:44`](../../packages/core/lib/facade/read_facade.dart#L44)

**The stop emission**

- The closing-sites doc: three causes, cause 1 now carries two taps
  [`session_commands.dart:196`](../../packages/core/lib/commands/session_commands.dart#L196)

- `pause()` — the declare write shape minus the catalogue, one row
  [`dispenser_controller.dart:262`](../../lib/dispenser/dispenser_controller.dart#L262)

- `_onPause` — the declare tap's mechanics, verbatim
  [`dispenser_screen.dart:529`](../../lib/ui/dispenser/dispenser_screen.dart#L529)

**The surface**

- The reflow constant — pinned chrome vs the accessibility floor
  [`dispenser_screen.dart:94`](../../lib/ui/dispenser/dispenser_screen.dart#L94)

- The footer band — `Quiero parar` above `Nuevo proyecto`, both views
  [`dispenser_screen.dart:575`](../../lib/ui/dispenser/dispenser_screen.dart#L575)

- The one new string, with its description
  [`app_es.arb:226`](../../lib/l10n/app_es.arb#L226)

**The ledger reading**

- The declared vacuous-rollback reading beside 2.1's ceiling text
  [`settings.dart:13`](../../packages/core/lib/settings/settings.dart#L13)

- The three worked cases: pocket-10 waits, bag-5 silent, bag-30 surplus buys nothing
  [`weave_test.dart:907`](../../packages/core/test/weave_test.dart#L907)

- The bag-invariance proof — acts appended, ceiling unmoved
  [`weave_test.dart:2014`](../../packages/core/test/weave_test.dart#L2014)

**The proofs**

- The 04:00 pause path — the ledger charges the start day
  [`session_test.dart:107`](../../packages/core/test/session_test.dart#L107)

- Mint-at-entry pinned at runtime — the row describes the tap
  [`dispenser_controller_test.dart:1420`](../../test/dispenser/dispenser_controller_test.dart#L1420)

- The reflow boundary pinned at 320/319 — the constant cannot drift silently
  [`dispenser_screen_test.dart:3059`](../../test/ui/dispenser/dispenser_screen_test.dart#L3059)

- The warm close keeps both footer texts on a short surface
  [`dispenser_screen_test.dart:3139`](../../test/ui/dispenser/dispenser_screen_test.dart#L3139)

- The shell census — the Dispenser's four user-act sites
  [`no_lateness_proof_test.dart:308`](../../test/no_lateness_proof_test.dart#L308)

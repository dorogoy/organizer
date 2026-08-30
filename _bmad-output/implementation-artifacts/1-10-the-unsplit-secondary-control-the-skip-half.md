---
title: 'The unsplit secondary control — the skip half'
type: 'feature'
created: '2026-08-30'
status: 'done'
review_loop_iteration: 0
baseline_commit: '729668bb9267e3b97afa1062db66f8755cad744b'
context: ['FR-3', 'FR-26', 'AD-3', 'AD-20', 'UX-DR17']
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** `SecondaryTextAction` renders final but its tap is an accepted no-op — passing on a card is impossible, so the epic's "complete it or pass on it" loop is half-built: only `Hecho` writes.

**Approach:** Wire the skip half. `DispenserController` gains a serialized `skip(card)` that runs the existing core `cardSkipped` command (`card_skipped` + the bundled next `card_dealt`, one minted instant per batch). The screen refreshes from the answered log; the resolver deals the different candidate by re-ranking (never exclusion), and pool exhaustion lands on the already-shipped warm close.

## Boundaries & Constraints

**Always:**
- One tap, no confirmation: `_onSkip(dealt)` mirrors `_onDone`'s mechanics minus all feedback — no haptic, no acknowledgement, nothing celebration-shaped; `await skip(dealt)`, then `_refresh()`.
- `skip(dealt)`: mint `now` at entry before any await; catalogue via the existing memo; read log; core `cardSkipped(itemId: card.id, origin: card.origin, catalogue:, log:, instantUtcMicros:, offsetSeconds:)` with its `bagMinutes`/energy defaults; append every returned row sequentially with one minted instant and a v7 id per row — `complete()` verbatim. Serialization through the existing `_enqueueWrite` chain, so a rapid second skip (or a skip racing a `Hecho`) reads the post-answer log and the core guard appends nothing.
- Share `_writeInFlight` so a skip and a completion can never interleave at the surface.
- A skip touches no completion state — `_completionAckWaiting` stays completion-only.
- Exhaustion: when the skipped card was the day's last candidate, `cardSkipped` returns only the answer row and the refresh lands on `DispenserClosed`, rendering the shipped `poolExhaustedClose` string — no new close path, never an error, never absence styled as debt.
- `SecondaryTextAction` gains a nullable `onTap`; absent, the tap stays the accepted no-op (`onTap ?? () {}`, never a disabled control). The text-only anatomy is untouched: `GestureDetector` with opaque hit behavior, 48dp min-height target, `inkSecondary`, centered, the one-piece `actionRescueOrSkip` string.

**Ask First:** None.

**Never:** No core changes (commands, weave, facade, calendar untouched — `cardSkipped` consumed as-is); no new ARB keys or codegen; no new log kinds; no skip counter, total or aggregate anywhere (`skippedCount` is lint-banned; a per-event `card_skipped` row is the only record); no haptic, sound, animation or ack on skip; no exclusion of the skipped card from the pool (re-ranking is the mechanism — a lone candidate re-deals by design); no wiring of `Otra más fácil`'s re-slice (Epic 4, FR-5); no session-controller behavior changes; no new `tool/` checks or Makefile targets; the string is never split, shortened, ellipsized, hard-broken or non-breaking-spaced.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Behavior | Error Handling |
|----------|---------------|-------------------|-----------------|
| Happy path | dealt card, tap `Otra más fácil / Ahora no` | `card_skipped` + next `card_dealt` appended (one minted instant, v7 ids); a different candidate commits | N/A |
| Focus-size skip | `Ahora no` on a focus-size deal | the chunk slot stays open (only `card_done` closes it); the next deal re-resolves identity — a different candidate that may itself be chunk-classed (respecting budget/energy), non-chunk, or none — the day's chunk remains available | N/A |
| Day's last candidate | skip exhausts the day | only the `card_skipped` row appends; next view is the warm close string | N/A |
| Lone candidate | skip when it is the only eligible candidate left, day not exhausted | the same card re-deals (re-ranked, not excluded) — repetition accepted, never an empty day mid-budget | N/A |
| Rapid double tap | two skip taps before refresh | serialization: second `skip()` sees the answered log, guard appends nothing — exactly one `card_skipped` | N/A |
| Skip racing `Hecho` | skip then complete (either order) before refresh | shared write chain + `_writeInFlight`: the later act's `(itemId, origin)` no longer matches the standing deal — guard appends nothing | N/A |
| Write failure | `appendLogEntry` throws | controller rethrows; screen catches → empty frame stands, no crash surfaced; foreground retry heals | quiet, deliberate |
| 200% font scale | control at 2× | the fold is accepted: the string renders whole or folded, never split or truncated | N/A |

</frozen-after-approval>

## Code Map

- `packages/core/lib/commands/session_commands.dart:105-124` -- `cardSkipped(...)`: the command `skip()` runs; same shape as `cardDone`, returns `[answerRow, nextDealRow?]` via shared `_answered` :136-186 (side-door guard :146-156 — no open session, no standing deal, or `(itemId, origin)` mismatch appends `const []`). Read-only — pinned by `packages/core/test/session_commands_test.dart:112-139` (exhausted day → answer row alone) and :141-212 (guards).
- `packages/core/lib/weave/session.dart:95-181` -- `walkLog`: a skip clears `dealtUnanswered` :160-165, never enters `answeredItemIds` :154-155, never closes the chunk slot :154-158 ("a skip consumes nothing", AD-20). Read-only evidence — `packages/core/test/session_test.dart:180-216, 294-306`.
- `packages/core/lib/weave/weave.dart:224-248, 445-461` -- `_resolverOrder` re-ranks by least-recently-dealt (the just-skipped card sorts last; a lone candidate re-deals — `packages/core/test/weave_test.dart:1226-1228`); `nextDeal` → `null` on exhaustion; the day-budget check counts dealt rows, so the bundled deal is load-bearing.
- `packages/core/lib/facade/read_facade.dart:22-47` -- `nextCard` falls through to the resolver once the skip cleared the standing deal; writes nothing (`packages/core/test/facade_test.dart:96,129,168`). No controller or screen change needed for the read.
- `lib/dispenser/dispenser_controller.dart:106-139` -- extend: serialized `skip(DispenserDealt)` mirroring `complete` — mint-at-entry :107, catalogue memo :87/:141-154, core `cardSkipped`, append loop :119-129 (one instant per batch, `idMinter.v7()` per row), `_enqueueWrite` chain :133-139.
- `lib/ui/dispenser/task_card.dart:63-94` -- `SecondaryTextAction`: hardcoded no-op at :76 → nullable `onTap` param (mirror `HechoButton` :27-29 and its `onTap ?? () {}` :44); `TaskCard` :102-106,133 threads it beside `onDone`.
- `lib/ui/dispenser/dispenser_screen.dart:129-161` -- `_onDone` is the tap-handler template; `_onSkip` mirrors its guard/await/mounted/refresh shape minus haptic :134 and ack flag :140; share `_writeInFlight` :119-133; the catch :142-157 leaves the quiet empty frame (no ack flags exist to clear).
- `lib/ui/dispenser/dispenser_screen.dart:220-228, 260-267` -- the `DispenserDealt` arm wires `onSkip`; the `DispenserClosed` arm + `_closeText` already render the exhaustion close a skip can produce — unchanged.
- `lib/l10n/app_es.arb:14-17` -- `actionRescueOrSkip` = `'Otra más fácil / Ahora no'` (one key, never split); `:139-142` `poolExhaustedClose`. Both shipped in 1.2 — no ARB edit, no codegen.
- Test doubles to reuse: `_RecordingStore` (`test/ui/dispenser/dispenser_screen_test.dart:40-55`), `_QueuedReadController` :257-266, entry lookup by kind `dealtEntryOf`/`latestDealtEntryOf` :374-390, harness `launchAndCommit` :795-805; advancing-clock pattern (`test/dispenser/dispenser_controller_test.dart:112-133, 465-507`); write-failure heal pattern (`dispenser_screen_test.dart:895-942`).
- `tool/check_forbidden_vocabulary.dart:42-52` -- `skippedCount` banned, `cardSkipped` documented as passing :15-16,61-62; `tool/check_text_scaling.dart` -- min-heights legal, `maxLines`/ellipsis banned. `Makefile:42-52,72-75` -- `make check` (nine tool checks + codegen-check), `make gate` (test/format/analyze), under `./tool/env.sh` (devbox).

## Tasks & Acceptance

**Execution:**
- [x] `lib/dispenser/dispenser_controller.dart` -- add serialized `skip(dealt)`: mint-before-await, catalogue memo, core `cardSkipped`, sequential appends mirroring `complete` -- the story's one write path
- [x] `lib/ui/dispenser/task_card.dart` -- `SecondaryTextAction({onTap})`, `TaskCard` threads it as `onSkip` -- the 1.8 component gains only the callback; absent stays the accepted no-op
- [x] `lib/ui/dispenser/dispenser_screen.dart` -- `_onSkip(card)`: `skip` + `_refresh` under the shared `_writeInFlight`, no haptic, no ack; write failure → the existing quiet empty frame -- the AC surface
- [x] `test/dispenser/dispenser_controller_test.dart` -- NEW: appended rows (`card_skipped` + deal, one instant, v7 ids), exhausted-day single row, double-tap guard, skip-racing-complete guard, store-failure propagation, mint-at-entry stamp -- pin the matrix's write rows
- [x] `test/ui/dispenser/dispenser_screen_test.dart` -- tap → different candidate, exhaustion → warm close, focus-size skip → slot open with the re-resolved next deal (may be chunk-classed), double tap → one `card_skipped`, write failure → empty frame + heal, 200% fold intact, no haptic and no ack on skip -- pin the matrix's UI rows
- [x] `test/ui/dispenser/task_card_test.dart` -- `onTap` invoked on tap; replace the 1.8 tap-is-no-op pin (:349-354) with the absent-callback no-op; existing anatomy pins stay green

**Acceptance Criteria:**
- Given a dealt card, when the secondary is tapped, then `card_skipped` and the next `card_dealt` are appended (one minted instant, v7 ids) and a different candidate is on screen — or the warm close when the day is exhausted
- Given a skip, when any state or log row is inspected, then no counter, no failure record and no cumulative total exists anywhere — only the per-event `card_skipped` row
- Given a skip, when the alternative resolves, then it respects the day's remaining budget and derived energy, consumes no rotation, and leaves the Focus Chunk slot open
- Given the day's last candidate, when it is skipped, then the session closes early on the warm close string — never an error, never styled as absence or debt
- Given the control, when rendered at any font scale, then it stays text-only (no box, fill, underline or animation) in `inkSecondary` with its 48dp target and the one-piece string — fold at 200% accepted, never split or shortened
- Given the completion gate, then `make check` and `make gate` are green

### Review Findings

- [x] [Review][Patch] Medium: a skip during a visible completion ack had no pin — copying `_onDone`'s ack-flag clears into `_onSkip`'s catch left the whole suite green (demonstrated empirically); two new screen tests pin the invariant: the ack stands above the skip-committed alternative and the original window — never a restart — clears it, and a failed skip leaves the ack for the healed commit [test/ui/dispenser/dispenser_screen_test.dart]
- [x] [Review][Patch] Medium: the skip mint-at-entry ticking test was self-referential (rows == mints[1] — a mint moved after the store reads passed green, demonstrated) and the source-scan pin was brittle — the behavioral test now captures the minute immediately before `skip()` so a late mint is observably late; the source-scan test is deleted [test/dispenser/dispenser_controller_test.dart]
- [x] [Review][Patch] Low: the no-haptic assertions matched only `lightImpact` — every skip test now asserts zero `HapticFeedback.vibrate` calls of any type, including the exhaustion test which previously asserted none [test/ui/dispenser/dispenser_screen_test.dart]
- [x] [Review][Patch] Low: the matrix's Lone-candidate row was unpinned at the app level — a single-entry fixture catalogue pins the same card re-dealing (`[card_skipped, card_dealt]` with the same itemId): never exclusion, never an empty day mid-budget [test/dispenser/dispenser_controller_test.dart]
- [x] [Review][Patch] Low: the controller `_GatedBundledDealStore` stayed `card_done`-only (silently diverged from the screen suite's `answerKind` copy) while `read()`'s doc claimed `card_skipped` half-written coverage — the double is generalized by answer kind and a mid-skip-batch read-gating test pins the claim [test/dispenser/dispenser_controller_test.dart]
- [x] [Review][Patch] Low: stale completion-only comments (`_writeInFlight` doc, file header) now cover both answers — a completion or a skip [lib/ui/dispenser/dispenser_screen.dart]
- [x] [Review][Patch] Low: sprint-status lagged the story file — 1-10 synced to `review` [_bmad-output/implementation-artifacts/sprint-status.yaml]
- [ ] [Review][Defer] The two-row skip batch's store atomicity — a mid-batch append failure orphans the `card_skipped` row without its bundled `card_dealt`, diverging day budget and ranking; extends 1.9's `card_done` deferral, needs a batch port or core command variant outside this story's no-core-change boundary — recorded in deferred-work.md
- [ ] [Review][Defer] 1.9's `complete` ticking test shares the same self-referential mint expectation this story fixed in skip's (rows == mints[1], a late mint passes green) — recorded in deferred-work.md
- [ ] [Review][Reject] Deduplicating `skip`/`complete` (and the fail-first test doubles) into shared helpers — the repo's decided stance keeps local duplication loud (1-7/1-8/1-9 rejection precedent)
- [ ] [Review][Reject] `Semantics`/button role for `SecondaryTextAction` — the decided interim posture is "no custom semantics, platform traversal order" (1.8/1.9 rejection precedent)

## Spec Change Log

## Design Notes

- **Re-ranking, not exclusion.** The skipped card keeps its dealt row and re-ranks last by least-recently-dealt: with another candidate the next deal differs; alone, it re-deals. Exclusion would be a hidden debt mechanism — a skip consumes nothing (AD-20), and core pins the repetition deliberately. The AC's "different candidate" holds whenever a second candidate exists.
- **No feedback on skip, deliberately.** The PRD ties haptic + warm copy to completion (FR-2); FR-3 promises only "deals an alternative without recording failure" — the different card *is* the answer. Revisitable on a real handset without touching structure.
- **The bundled deal is load-bearing.** `nextCard` never writes; without the command-appended `card_dealt`, draw accounting, the day budget and least-recently-dealt would silently diverge. `skip()` must append every row the command returns, exactly as `complete()` does.

## Verification

**Commands:**
- `devbox run -- make check` -- expected: all checks green (no ARB/codegen needed this story)
- `devbox run -- make gate` -- expected: test, format, analyze all green
- `devbox run -- flutter test test/dispenser test/ui/dispenser` -- expected: new and existing suites green

**Manual checks (if no CLI):**
- Real handset, light and dark, normal and maximum font scale: the control reads text-only, the tap deals the alternative without hesitation, and the 200% fold leaves the string whole-or-folded — never split, never ellipsized

## Suggested Review Order

**The write path — the core command consumed, nothing new in `packages/core`**

- The story's one write path: mint-at-entry, core `cardSkipped` with its defaults, one instant and a v7 id per row
  [`dispenser_controller.dart:149`](../../lib/dispenser/dispenser_controller.dart#L149)

- The consumed command (read-only): `cardSkipped` shares `_answered` with `cardDone` — the bundled next deal and the side-door guard
  [`session_commands.dart:105`](../../packages/core/lib/commands/session_commands.dart#L105)

- Reads never derive from a half-written skip batch — `read()` awaits the settled write chain
  [`dispenser_controller_test.dart:780`](../../test/dispenser/dispenser_controller_test.dart#L780)

**The surface — one tap, no feedback, quiet failure**

- The skip is `_onDone`'s mechanics minus all feedback: shared `_writeInFlight`, no haptic, no ack, quiet empty frame on failure
  [`dispenser_screen.dart:189`](../../lib/ui/dispenser/dispenser_screen.dart#L189)

- The 1.8 component gains only the callback; absent, the tap stays the accepted no-op
  [`task_card.dart:81`](../../lib/ui/dispenser/task_card.dart#L81)

- The wiring: `TaskCard` threads `onSkip` beside `onDone`
  [`dispenser_screen.dart:271`](../../lib/ui/dispenser/dispenser_screen.dart#L271)

**Peripherals — the proofs**

- The happy path end to end: different candidate commits, zero haptics of any type, nothing ack-shaped
  [`dispenser_screen_test.dart:1343`](../../test/ui/dispenser/dispenser_screen_test.dart#L1343)

- The exhaustion close: the day's last candidate skipped lands on the warm close string
  [`dispenser_screen_test.dart:1426`](../../test/ui/dispenser/dispenser_screen_test.dart#L1426)

- The review patches' pins: the ack outlives a skip inside its window (and a failed skip), and the lone candidate re-deals
  [`dispenser_screen_test.dart:1682`](../../test/ui/dispenser/dispenser_screen_test.dart#L1682)
  [`dispenser_screen_test.dart:1732`](../../test/ui/dispenser/dispenser_screen_test.dart#L1732)
  [`dispenser_controller_test.dart:846`](../../test/dispenser/dispenser_controller_test.dart#L846)

- The row-level pins: one minted instant, v7 ids, and the behavioral mint-at-entry stamp
  [`dispenser_controller_test.dart:552`](../../test/dispenser/dispenser_controller_test.dart#L552)
  [`dispenser_controller_test.dart:726`](../../test/dispenser/dispenser_controller_test.dart#L726)

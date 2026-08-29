---
title: 'Hecho'
type: 'feature'
created: '2026-08-29'
status: 'done'
review_loop_iteration: 0
baseline_commit: '52519c8c3ab47b6c1f48d3dd3e28b79de77b37a5'
context: ['FR-2', 'NFR5', 'NFR6', 'AD-3', 'AD-19', 'AD-20', 'UX-DR38', 'UX-DR39', 'UX-DR51']
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** `HechoButton` renders final but its tap is an accepted no-op — completion appends nothing, gives no feedback, and the surface refreshes only on a return to foreground. The epic's core loop (deal → answer → next deal) has no write path.

**Approach:** Wire the tap. `DispenserController` gains a serialized `complete(card)` that runs the core `cardDone` command (`card_done` + the bundled next `card_dealt`, one minted instant per batch). The screen fires a haptic immediately, awaits the write, refreshes from the answered log, and acknowledges completion with the already-shipped `completionAcknowledgement` («¡Buen trabajo!») shown for a fixed window above whatever view commits next.

## Boundaries & Constraints

**Always:**
- One tap, no confirmation, no undo, no modal (UX-DR43). Tap order: `HapticFeedback.lightImpact` fired immediately (never awaited); `await complete(card)`; `_refresh()`; ack appears only when the post-completion view commits.
- `complete(dealt)`: mint `now` at entry before any await; catalogue via the existing memo; read log; core `cardDone(itemId: card.id, origin: card.origin)` with its `bagMinutes`/energy defaults; append rows sequentially with one minted instant and a v7 id per row — `SessionController._appendAll` verbatim. Calls serialize through a failure-recoverable chain (`_enqueue` pattern), so a rapid second `complete()` reads the post-answer log and the core guard appends nothing.
- The ack: `AppStrings…completionAcknowledgement` only, quiet support register (the wired support text style), centered, inside the scroll column above the committed view (next card or the warm close string); a fixed 2000 ms window, then plain removal — no motion, no glyph, no fill, identical every time; a later completion restarts the window; the timer is cancelled on dispose.
- The completed card exits the tree entirely via the existing refresh clear — never toward a counter, pile or badge, and with **no trajectory animation** (the spine's departure OQ stays unconfirmed; removal chooses no motion).
- The next card is never gated: nothing celebration-related is awaited; the only awaits between tap and next-view commit are the store round-trips of `complete()` + `read()`.
- `HechoButton` gains an `onTap` callback; `TaskCard` threads it. The secondary stays a no-op (1.10's).

**Ask First:** None.

**Never:** No core changes (commands, weave, facade, calendar untouched — consumed only); no new ARB keys or codegen (`completionAcknowledgement` shipped in 1.2); no new log kinds; no `cardSkipped` wiring; no session-controller behavior changes; no counter, streak, badge, rating prompt, sound or loud audio; no `AnimationController`/`Ticker`/implicit animations; no new `tool/` checks or Makefile targets; haptics never the sole completion signal.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Behavior | Error Handling |
|----------|---------------|-------------------|-----------------|
| Happy path | dealt card, tap `Hecho` | haptic dispatched; `card_done` + next `card_dealt` appended (one instant); next card committed; «¡Buen trabajo!» above it; gone after 2 s | N/A |
| Last card of the day | answer exhausts the day | only the answer row appends; next view is the warm close string; the ack still shows above it | N/A |
| Focus chunk completed | `Hecho` on a focus-size deal | the day's chunk slot closes before the bundled next deal resolves — next view is non-chunk or closed | N/A |
| Rapid double tap | two taps before refresh | serialization: second `complete()` sees the answered log, guard appends nothing — exactly one `card_done` | N/A |
| Write failure | `appendLogEntry` throws | controller rethrows; screen catches → empty frame stands, no ack, no crash surfaced; foreground retry heals (the log stayed consistent either way) | quiet, deliberate |
| 200% font scale | ack + next card at 2× | ack wraps inside the scroll column, nothing truncated, screen scrolls | N/A |

</frozen-after-approval>

## Code Map

- `packages/core/lib/commands/session_commands.dart:79-98` -- `cardDone(...)`: the command `complete()` runs; returns `[answerRow, nextDealRow?]`; side-door guard `_answered` :136-186. Read-only — pinned by `packages/core/test/session_commands_test.dart:141-190`.
- `packages/core/lib/weave/session.dart:95-181` -- `walkLog` chunk-slot closure (`focusSlotClosedDays`, the session-start-day charge rule `_chargedDayOf` :69-80). Read-only evidence — pinned by `packages/core/test/session_test.dart`.
- `packages/core/lib/facade/read_facade.dart:22-47` -- `nextCard`'s dealt-unanswered → resolver fall-through: the post-answer read needs no change.
- `lib/dispenser/dispenser_controller.dart:47-90` -- extend: `idMinter` injectable (`Uuid`, default `const Uuid()` — uuid 4.6.0 already a dep, so `lib/main.dart:35` needs no edit) + serialized `complete(DispenserDealt)`.
- `lib/session/session_controller.dart:83-90,174-186` -- the `_enqueue` chain and `_appendAll` to mirror.
- `lib/ui/dispenser/task_card.dart:26-57` -- `HechoButton`: no-op `onTap` at :40 becomes a callback; `TaskCard` :123 threads it; `SecondaryTextAction` untouched.
- `lib/ui/dispenser/dispenser_screen.dart:79-102` -- reuse `_refresh`/generation on tap; ack state + `Timer` here; the empty-frame catch absorbs write failures.
- `lib/l10n/app_es.arb:9-12` / `lib/strings/app_strings.dart:108` -- `completionAcknowledgement` already generated; no ARB edit, no codegen.
- `lib/ui/tokens.dart`, `lib/ui/theme.dart` -- the wired support text style and `Spacing` gaps for the ack line.
- Test doubles to copy: `_RecordingStore` (`test/ui/dispenser/dispenser_screen_test.dart:36`), `_FakeBundle` :55, `_QueuedReadController` :161; `test/session/session_controller_test.dart:24-82`.
- Haptics: `HapticFeedback.lightImpact` from `flutter/services.dart` (first use in `lib/`); assert via a mock method-call handler on `SystemChannels.platform`.

## Tasks & Acceptance

**Execution:**
- [x] `lib/dispenser/dispenser_controller.dart` -- add `idMinter` + serialized `complete(dealt)`: mint-before-await, catalogue memo, `cardDone`, sequential appends mirroring `_appendAll` -- the story's one write path
- [x] `lib/ui/dispenser/task_card.dart` -- `HechoButton({onTap})`, `TaskCard` threads it as `onDone` -- the 1.8 component gains only the callback
- [x] `lib/ui/dispenser/dispenser_screen.dart` -- `_onDone(card)`: haptic + `complete` + `_refresh` + the ack window (2 s, dispose-safe, restart on later completions); write failure → the existing quiet empty frame -- the AC surface
- [x] `test/dispenser/dispenser_controller_test.dart` -- NEW: appended rows (answer + deal, one instant, v7 ids), exhausted-day single row, double-tap guard, store-failure propagation -- pin the matrix's write rows
- [x] `test/ui/dispenser/dispenser_screen_test.dart` -- tap → next card + ack above it, haptic dispatched via mock platform channel, ack gone after 2 s, write failure → empty frame with no ack, double tap → one `card_done`, chunk completion → next view non-chunk-or-close, 200% wraps -- pin the matrix's UI rows
- [x] `test/ui/dispenser/task_card_test.dart` -- `onTap` invoked on tap; existing anatomy pins stay green

**Acceptance Criteria:**
- Given a dealt card, when `Hecho` is tapped, then `card_done` and the next `card_dealt` are appended and the next card is on screen with nothing celebration-related awaited before it
- Given a committed completion, when feedback renders, then the haptic fired and «¡Buen trabajo!» is visible — never the haptic alone, never modal, identical every time
- Given the acknowledgement, when 2 s pass, then it is gone and nothing else on the surface changed
- Given a `Hecho` on a Focus Chunk, when the next view resolves, then no second chunk composes for that session's day
- Given the day's last card, when completed, then the warm close string shows with the ack above it
- Given the completion gate, then `make check` and `make gate` are green

### Review Findings

- [x] [Review][Patch] Medium: a lifecycle read could derive from a half-written completion batch — `read()` now awaits the settled write chain (never-failing, `catchError`-cleared) after the entry mint, and a gated-bundled-deal store pins the mid-batch read resolving only after the gate, returning the bundled card [lib/dispenser/dispenser_controller.dart, test/dispenser/dispenser_controller_test.dart]
- [x] [Review][Patch] Medium: `_onDone`'s success branch lacked a `mounted` check after its await, and a rapid second tap fired a second haptic plus a redundant refresh over a guard no-op — a synchronous in-flight guard (cleared in `finally`) and the mounted check close both; the double-tap test now pins `lightImpacts == 1` [lib/ui/dispenser/dispenser_screen.dart, test/ui/dispenser/dispenser_screen_test.dart]
- [x] [Review][Patch] Medium: a failed post-write read left `_completionAckWaiting` set (the ack could attach to a much later, unrelated commit) and the write-failure path left the ack flags/timer stale — both failure paths now clear their state (generation-scoped for reads), pinned by a fail-read-after-successful-write test whose foreground heal shows no stale ack [lib/ui/dispenser/dispenser_screen.dart, test/ui/dispenser/dispenser_screen_test.dart]
- [x] [Review][Patch] Low: the ack-window restart on a later completion had no test — deleting `_commitView`'s timer cancel kept the suite green; a two-completion fake-clock test (zero-duration pumps, mutation-verified) now pins the restart [test/ui/dispenser/dispenser_screen_test.dart]
- [x] [Review][Patch] Low: `complete`'s mint-at-entry was pinned only by source text — a runtime advancing-clock test (each log read ticks the clock) now stamps both rows with the entry mint [test/dispenser/dispenser_controller_test.dart]
- [ ] [Review][Defer] The two-row answer batch's store atomicity (orphaned `card_done` → unanswerable fall-through card) — recorded in deferred-work.md; needs a batch port or core command variant, outside this story's no-core-change boundary
- [ ] [Review][Defer] Shared serialization for `complete` vs the session lifecycle (or pinning the "only dealt cards are shown" invariant) — recorded in deferred-work.md; ms-wide window, insert-only substrate tolerates the orphan rows
- [ ] [Review][Reject] Missing `uuid` dependency / ARB key / `dart:async`-`services` imports — false positives: `uuid 4.6.0`, `completionAcknowledgement` (shipped 1.2) and both imports already exist; `make check`/`make gate` green
- [ ] [Review][Reject] Observability for silently-swallowed write failures — the repo's established quietness stance (1.8's rejection precedent: lifecycle errors are deliberately silent)
- [ ] [Review][Reject] The ack's insertion shifting the card vertically — in-flow-above-the-view is the approved spec's chosen form; a reserved fixed-height slot is banned by the text-scaling lint, and no decided rule forbids the shift
- [ ] [Review][Reject] Accessibility semantics for the ack / `onTap: null` button state — the decided interim posture is "no custom semantics, platform traversal order" (1.8's rejection precedent)
- [ ] [Review][Reject] Extracting a shared `_appendAll` helper across controllers — the repo's decided stance keeps local duplication loud (1-7/1-8 rejection precedent)

## Spec Change Log

## Design Notes

- **Exit = removal, deliberately.** The spine leaves the departure trajectory an open question; animating one now would confirm what no one confirmed. Removal already is the surface's every-refresh behavior — consistent, and it satisfies "exits the screen entirely" without motion.
- **Ack after commit, not on tap.** Showing «¡Buen trabajo!» for a write that failed would be a lie; the haptic taps immediately (it acknowledges the *act*), the visible line confirms the *recorded* completion. On failure: quiet frame, no ack, foreground retry heals.
- **`lightImpact`** reads as the decided "subtle haptic buzz / small warm acknowledgement"; revisitable on a real handset without touching structure.
- **2 000 ms** is calm and far from the 500 ms budget it must never gate — the next card is already committed underneath it.

## Verification

**Commands:**
- `devbox run -- make check` -- expected: all checks green (no ARB/codegen needed this story)
- `devbox run -- make gate` -- expected: test, format, analyze all green
- `devbox run -- flutter test test/dispenser test/ui/dispenser` -- expected: new and existing suites green

**Manual checks (if no CLI):**
- Real handset, light and dark: the haptic register reads warm (not a harsh buzz) and «¡Buen trabajo!» is visible beside/above the next card at normal and maximum font scale

## Suggested Review Order

**The write path — the core command consumed, nothing new in `packages/core`**

- The story's one write path: mint-at-entry, core `cardDone` with its defaults, one instant and a v7 id per row
  [`dispenser_controller.dart:106`](../../lib/dispenser/dispenser_controller.dart#L106)

- Reads never derive from a half-written batch — `read()` awaits the settled write chain after the entry mint
  [`dispenser_controller.dart:86`](../../lib/dispenser/dispenser_controller.dart#L86)

- The serialized chain: a rapid second `complete` reads the post-answer log and the core guard appends nothing
  [`dispenser_controller.dart:133`](../../lib/dispenser/dispenser_controller.dart#L133)

**The surface — tap, exit, acknowledgement**

- One tap, no confirmation: the light haptic fires first (never awaited, never the sole signal), then the write, then the refresh
  [`dispenser_screen.dart:129`](../../lib/ui/dispenser/dispenser_screen.dart#L129)

- The ack window starts at commit and a later completion restarts it — the 500 ms budget is never gated
  [`dispenser_screen.dart:188`](../../lib/ui/dispenser/dispenser_screen.dart#L188)

- «¡Buen trabajo!» in the quiet support register, centered, above whatever view commits — card or warm close
  [`dispenser_screen.dart:235`](../../lib/ui/dispenser/dispenser_screen.dart#L235)

- The 1.8 button gains only the callback; absent, the tap stays the anatomy harness's no-op
  [`task_card.dart:29`](../../lib/ui/dispenser/task_card.dart#L29)

**Peripherals — the proofs**

- The happy path end to end: haptic dispatched, rows appended, next card committed, ack above it
  [`dispenser_screen_test.dart:773`](../../test/ui/dispenser/dispenser_screen_test.dart#L773)

- The review patches' pins: mid-batch reads, double-tap serialization, failed writes with no ack, no stale ack on the healed commit
  [`dispenser_controller_test.dart:403`](../../test/dispenser/dispenser_controller_test.dart#L403)
  [`dispenser_screen_test.dart:881`](../../test/ui/dispenser/dispenser_screen_test.dart#L881)
  [`dispenser_screen_test.dart:1037`](../../test/ui/dispenser/dispenser_screen_test.dart#L1037)

- The window-restart pin — deleting `_commitView`'s timer cancel fails exactly here — and the runtime mint-at-entry stamp
  [`dispenser_screen_test.dart:1082`](../../test/ui/dispenser/dispenser_screen_test.dart#L1082)
  [`dispenser_controller_test.dart:463`](../../test/dispenser/dispenser_controller_test.dart#L463)

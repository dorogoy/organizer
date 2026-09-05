---
title: 'Wagon 0: split the Dispenser view arms'
type: 'refactor'
created: '2026-09-05'
status: 'done'
review_loop_iteration: 0
baseline_commit: 0b4bb85874712f206f5cf07630558c7525cb60ce
context: ['{project-root}/_bmad-output/implementation-artifacts/choir-pilot-protocol.md']
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** `lib/ui/dispenser/dispenser_screen.dart` (1,539 lines) is the repo's highest-collision file — one State class holding every view arm (dealt, rest-offer/checkpoint, closed, strip layers, chrome). Epic 5 adds scan/genesis arms to this surface; epic-4 retro F7 ordered the split before they land.

**Approach:** Pure refactor — extract the view-construction code into per-arm widget files following the sibling conventions (`task_card.dart` et al.); the State keeps the read/commit spine and every handler. Zero behavior change; existing tests green and unmodified. This is wagon 0 of the pre-Epic-5 train and doubles as the choir orchestrator's warm-up (choir-pilot-protocol §6 — orchestrated, timed, not counted).

## Boundaries & Constraints

**Always:**
- Zero behavior change. Existing test files stay byte-identical — `test/ui/dispenser/dispenser_screen_test.dart` (85 `testWidgets` + 3 `test`) plus the app/capture/settings/slicer_access/ambient_strip/no_slicer_surface suites that pump this screen.
- Public surface of `dispenser_screen.dart` unchanged: class `DispenserScreen` (same 5 constructor params) and `pocketLadderOptions` importable from it (a re-export is acceptable if the const moves with the ladder UI).
- The `NoSlicerSurface` import and push (`_openNoSlicerSurface`, :541-553) stay textually in `dispenser_screen.dart` — the census pin `test/ui/dispenser/no_slicer_surface_test.dart:553-559` asserts one referer has a path ending `lib/ui/dispenser/dispenser_screen.dart`.
- New files: zero string literals (resolve via `AppStrings.of(context)` in `build`); no banned vocabulary (`overdue/late/missed/pending/debt/streak/skippedCount/dueDate/backlog`); no `maxLines`, `TextOverflow.ellipsis`, `FittedBox`, or fixed-height text containers; `snake_case.dart` files; one or two public `StatelessWidget`s per file with `const` constructors taking data + `VoidCallback?` callbacks (default accepted no-op, `onTap ?? () {}`); theme via `Theme.of(context)`, tokens from `../tokens.dart`; `Semantics(button: true …)` on tappable masses; the long prose headers citing story provenance move with their code.
- The State keeps ALL async machinery: read spine (`_refresh`, `_readAfterSessionSettles`), `_commitView`, `_endRescueMarkersIfDealEnded`, rescue markers/flight ids, every `_on*` handler, timers, `WidgetsBindingObserver`.

**Ask First:** editing any file under `test/` or `tool/`; moving the `NoSlicerSurface` push; changing `tool/check_no_literal_strings.dart` allowlists; creating subdirectories under `lib/ui/`.

**Never:** no UI, behavior, string-table, controller, or substrate changes; no new features; no renames of public symbols; no golden tests; no moving State machinery out of the State.

</frozen-after-approval>

## Code Map

- `lib/ui/dispenser/dispenser_screen.dart` — the target. Dispatch `_viewContent` :701-734 switches on the sealed `DispenserView` (`lib/dispenser/dispenser_controller.dart:48`): Dealt :704-715, RestOffer :716-720 → `_restOffer` :1370-1383, Closed :721-728 → `_closeText` :1352-1359 / `_closeWithContinue` :1393-1405. Wrappers: `_withAmbientStrip` :743-776 (→ `AmbientStrip`/`SelfReportStrip`), `_withCompletionAck` :1304-1321 (reads `_completionAckVisible`), `_withWarmReturnGreeting` :1333-1347. Chrome: `_standingPocketMinutes` :986-993, `_pocketTrigger` :1003-1054, `_openPocketLadder` :1080, `_footerActions` :1257-1284, `_pinnedFooterBand` :1289, `_frame` :1412-1438. Private types `_LapizEntry` :1447-1470, `_PocketLadderOption` :1480-1539; public const `pocketLadderOptions` :152. `build()` :655-699 (LayoutBuilder `chromePinned`). Stays in the State: fields+spine :196-653, `_onDone` :268, `_onSkip` :326, `_onSecondaryAction` :414, `_onRescue` :448-534, `_commitView` :614-653, remaining `_on*` :791-1222, ladder/pocket handlers :1061-1109.
- `lib/ui/dispenser/task_card.dart`, `ambient_strip.dart`, `duration_chip.dart`, `zone_marker.dart` — sibling conventions to copy (header prose, const ctors, `AppStrings`, tokens).
- `tool/check_no_literal_strings.dart` :66-233 — per-file allowlists keyed by exact path; `tool/check_text_scaling.dart`, `tool/check_forbidden_vocabulary.dart` — auto-scope every new lib file.
- `lib/main.dart:19,184-190` — sole external constructor consumer.
- `_bmad-output/implementation-artifacts/choir-pilot-protocol.md` §6 — wagon 0 = orchestrator warm-up.

## Tasks & Acceptance

**Execution:**
- [x] `lib/ui/dispenser/dispenser_closed_view.dart` — extract ClosedView (close text; close-with-continue) taking the closed-view data + `onContinue` callback.
- [x] `lib/ui/dispenser/dispenser_rest_offer_view.dart` — extract RestOfferView (checkpoint stop/continue controls).
- [x] `lib/ui/dispenser/dispenser_dealt_view.dart` — extract DealtView (TaskCard wiring) plus the completion-ack layer.
- [x] `lib/ui/dispenser/dispenser_strip_layer.dart` — extract the ambient-strip and warm-return layers (all-arm wrappers).
- [x] `lib/ui/dispenser/dispenser_chrome.dart` — extract pocket trigger + ladder sheet (`_PocketLadderOption` moves; `pocketLadderOptions` re-exported from `dispenser_screen.dart`), footer actions, pinned band, frame.
- [x] `lib/ui/dispenser/dispenser_screen.dart` — rewire `_viewContent`/`build` to compose the new widgets; move provenance headers along; keep spine, handlers, `NoSlicerSurface` push. Exact grouping of the new files may shift as long as every hazard and convention above holds.

**Acceptance Criteria:**
- Given the full suite at HEAD, when the refactor lands, then `devbox run -- make gate` is green and `git diff --stat -- test/ tool/` is empty.
- Given the string-table and lint checks walk the new files, when `devbox run -- make check` runs, then they pass with no allowlist edits.
- Given tests import `pocketLadderOptions` from `dispenser_screen.dart`, when the ladder UI moves, then that import still resolves.
- Given `git grep -n NoSlicerSurface lib/`, when the split is done, then the only `lib/ui/dispenser` hit is `dispenser_screen.dart`.

## Design Notes

Rationale: the arms are thin by design (the TaskCard `onDone`/`onSkip` model) — widgets take data + callbacks; everything asynchronous stays State-bound, so extraction cannot change behavior. Epic 5 then adds each new arm as a new file plus one dispatch line in `_viewContent`. Extraction hazards, in order of bite: the census pin, the per-path literal allowlists, and handler closures over State. Choir note: trozos follow the execution tasks; worker scopes must stay disjoint (sequential integration, gate green after each merge).

## Verification

**Commands:**
- `devbox run -- make gate` — all green (tests, analyze, format).
- `git diff --stat -- test/ tool/` — empty.
- `wc -l lib/ui/dispenser/dispenser_screen.dart` — reported; expect a meaningful reduction from 1,539 (arms + chrome out).

**Manual checks (if no CLI):**
- `git grep -n NoSlicerSurface lib/` — single dispenser file hit, push unchanged.

## Suggested Review Order

**Composition — the design**

- Entry point: thin arm dispatch plus the layer order as a pinned contract.
  [`dispenser_screen.dart:657`](../../lib/ui/dispenser/dispenser_screen.dart#L657)

- Chrome dispatch: LayoutBuilder picks pinned vs in-frame branches.
  [`dispenser_screen.dart:609`](../../lib/ui/dispenser/dispenser_screen.dart#L609)

- The re-export that keeps tests importing `pocketLadderOptions` from the screen.
  [`dispenser_screen.dart:84`](../../lib/ui/dispenser/dispenser_screen.dart#L84)

**The arms**

- Dealt arm: TaskCard wiring, callbacks threaded to the handlers.
  [`dispenser_dealt_view.dart:21`](../../lib/ui/dispenser/dispenser_dealt_view.dart#L21)

- Closed arm: warm close, conditional checkpoint continue.
  [`dispenser_closed_view.dart:19`](../../lib/ui/dispenser/dispenser_closed_view.dart#L19)

- Rest-offer arm: the checkpoint's two actions and nothing else.
  [`dispenser_rest_offer_view.dart:27`](../../lib/ui/dispenser/dispenser_rest_offer_view.dart#L27)

**All-arm layers**

- Ambient strip layer: resident switch, four callbacks threaded.
  [`dispenser_strip_layer.dart:51`](../../lib/ui/dispenser/dispenser_strip_layer.dart#L51)

- Completion ack — moved here at review (wraps every arm, not just dealt).
  [`dispenser_strip_layer.dart:126`](../../lib/ui/dispenser/dispenser_strip_layer.dart#L126)

- Warm return greeting: derivation-driven, no state.
  [`dispenser_strip_layer.dart:167`](../../lib/ui/dispenser/dispenser_strip_layer.dart#L167)

**Chrome**

- Pocket trigger band with the Lápiz entry overlay.
  [`dispenser_chrome.dart:73`](../../lib/ui/dispenser/dispenser_chrome.dart#L73)

- Ladder sheet; `pocketLadderOptions` moved here (canonical home).
  [`dispenser_chrome.dart:159`](../../lib/ui/dispenser/dispenser_chrome.dart#L159)

- Footer band: pinned vs in-frame in one widget.
  [`dispenser_chrome.dart:203`](../../lib/ui/dispenser/dispenser_chrome.dart#L203)

- The shared frame: scroll/center/max-width bound.
  [`dispenser_chrome.dart:259`](../../lib/ui/dispenser/dispenser_chrome.dart#L259)

**Choir evidence (warm-up, aborted by Sergio — not counted)**

- Worker reports: trozo A (flash worker, integrated) and trozo B (inline finish).
  [`REPORT-ta.md`](wagon0/REPORT-ta.md)
  [`REPORT-tb.md`](wagon0/REPORT-tb.md)

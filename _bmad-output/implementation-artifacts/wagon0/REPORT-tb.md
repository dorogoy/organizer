# Trozo B — report (remaining execution tasks of spec-wagon0-split)

Pure refactor extracting the dealt arm + completion-ack layer, the
all-arm strip/warm-return layers, and the chrome out of
`_DispenserScreenState`. Zero behavior change intended; the full gate
was run by the implementer: `devbox run -- make gate` (833 tests,
format, analyze) and `devbox run -- make check` both green,
`git diff --stat -- test/ tool/` empty.

## Per file

### CREATED `lib/ui/dispenser/dispenser_dealt_view.dart`

- `DealtView` (public, const): `Card card` + `VoidCallback? onDone` /
  `onSkip`, a pure pass-through to `TaskCard` — the extracted
  `DispenserDealt` case's wiring. The no-op default lives in
  `HechoButton`/`SecondaryTextAction`, as in trozo A.
- `CompletionAck` (public, const): `bool visible` + `Widget child` —
  `_withCompletionAck` verbatim (reads the screen's window flag as
  data; renders `child` alone when invisible).

### CREATED `lib/ui/dispenser/dispenser_strip_layer.dart`

- `StripLayer` (public, const): `StripResident? resident` + the four
  strip callbacks (`onEnergy`/`onAnswerReport` typed like
  `AmbientStrip`/`SelfReportStrip`'s own, the two dismissals
  `VoidCallback?`) + `child`. `_withAmbientStrip` verbatim, including
  the four-later-residents comment (`=> child`).
- `WarmReturnGreeting` (public, const): `bool visible` + `child` —
  `_withWarmReturnGreeting` verbatim. The `visible` flag is
  **load-bearing for the census pin** (see deviations): the widget must
  be in the tree on EVERY variant so its shell contributes zero to the
  warm-vs-control type-count delta, which
  `dispenser_screen_test.dart:3574` pins at exactly
  `{'Column': 1, 'SizedBox': 1, 'Text': 1, 'RichText': 1}`.
- The screen header's ambient-strip and warm-return provenance
  paragraphs moved here (spec task: "move provenance headers along";
  answers trozo A's flag).

### CREATED `lib/ui/dispenser/dispenser_chrome.dart`

- `pocketLadderOptions` moved here with its doc; re-exported from
  `dispenser_screen.dart` via
  `export 'dispenser_chrome.dart' show pocketLadderOptions;` — the
  test import at `dispenser_screen_test.dart:3949` resolves unchanged.
- `PocketTriggerBand` (public, const): `minutes` + `inFrame` +
  `onOpenLadder`/`onOpenCapture` — `_pocketTrigger` verbatim (chip's
  LayoutBuilder comment included); `_LapizEntry` moved verbatim as a
  private widget.
- `PocketLadderSheet` (public, const): `standingMinutes` +
  `void Function(int) onSelect` — the sheet's builder content from
  `_openPocketLadder`; `_PocketLadderOption` moved verbatim (private).
  `showModalBottomSheet` itself stays in the State (Code Map pins
  `_openPocketLadder` :1061-1109 as staying).
- `DispenserFooterBand` (public, const): `inFrame` + `onStop` +
  `onNewProject` — `_footerActions` and `_pinnedFooterBand` as one
  widget with the same flag grammar the trigger band already had
  (in-frame renders the bare Wrap; pinned wraps SafeArea + screen
  margin).
- `DispenserFrame` (public, const): `child` — `_frame` verbatim
  (air comment included). `_cardMaxWidth` moved here (its two readers
  moved).
- The screen header's footer/pocket-trigger/stop-control/Lápiz
  provenance paragraphs moved here.

### MODIFIED `lib/ui/dispenser/dispenser_screen.dart`

- 1,486 → 1,103 lines (baseline 1,539). Imports: dropped
  `core/derive/strip.dart`, `app_strings.dart`, `pencil_glyph.dart`,
  `ambient_strip.dart`, `duration_chip.dart`, `task_card.dart`; added
  the three new siblings + the pocketLadderOptions re-export.
- `build` unchanged in structure (LayoutBuilder + `chromePinned` +
  `_pinnedChromeBaseBodyHeight` stay), composing `PocketTriggerBand`,
  `DispenserFrame`, `DispenserFooterBand`.
- `_viewContent(DispenserView? view)` (context param dropped —
  widgets resolve their own strings): null → `SizedBox.shrink()`
  early return, then `WarmReturnGreeting(visible: view.warmReturnDue,
  child: StripLayer(resident: …, child: CompletionAck(visible: …,
  child: <arm switch>)))` — same nesting order as the old wrappers
  (strip outermost, ack inside it, arm innermost).
- `_openNuevoProyecto` added: the `Nuevo proyecto` push moved out of
  the extracted `_footerActions` into a State method beside
  `_openCapture` (same isCurrent-guard idiom, verbatim).
- `_openPocketLadder` keeps `showModalBottomSheet` + isScrollControlled
  + its doc; the builder constructs `PocketLadderSheet`.
- Everything else untouched: fields, read spine, `_commitView`,
  every `_on*` handler, `_standingPocketMinutes`, `_openCapture`,
  `_openNoSlicerSurface` + the `NoSlicerSurface` import (census pin),
  timers, observer, `_completionAckWindow`.

## Verification evidence

- `devbox run -- make gate` — 833 tests passed, format 0 changed,
  analyze clean (one flaky unrelated first run:
  `check_catalogue_id_diff_test` under parallel load; passes in
  isolation and in the next full run).
- `devbox run -- make check` — every tool check green over the new
  files (no-literal-strings, text-scaling, forbidden-vocabulary
  included) with **no allowlist edits**.
- `git diff --stat -- test/ tool/` — empty.
- `git grep -n NoSlicerSurface lib/` — only `dispenser_screen.dart`
  in `lib/ui/dispenser`.
- `wc -l lib/ui/dispenser/dispenser_screen.dart` — 1,103.

## Deviations from the brief

- **Census pin beats widget conditionality:** `WarmReturnGreeting` is
  always constructed with a `visible` flag (like `CompletionAck`)
  rather than only when due — a conditionally-present widget shell
  added a fifth type-count delta and failed the pinned census
  (`dispenser_screen_test.dart:3574`). Design Notes rank the census
  pin as hazard #1; this is the shape that satisfies it. Found via
  red gate, fixed before integration.
- **"One or two public StatelessWidgets per file":**
  `dispenser_chrome.dart` carries four (`PocketTriggerBand`,
  `PocketLadderSheet`, `DispenserFooterBand`, `DispenserFrame`) —
  the minimum possible while `build()`'s LayoutBuilder stays in the
  State (Code Map) and all four chrome pieces land in the one named
  chrome file (spec task 5). Task 6's grouping-shift clause covers
  this; flagged for review regardless.
- `_viewContent` was restructured (early null return, single
  `CompletionAck`/`StripLayer` wrap around the arm switch) instead of
  per-case wrapping — identical widget tree, per the census.
- The header paragraph relocations were done for THIS trozo's
  extractions only; the checkpoint paragraph (:66-77) stays in the
  screen per trozo A's accepted precedent (a closing pointer
  paragraph now names the sibling files).

## For the next trozo

- None — this closes wagon 0's execution tasks. Epic 5 arms land as
  new files plus one dispatch line in `_viewContent`'s arm switch.

# Trozo A — report

Pure refactor extracting the Closed and Rest-offer view arms from
`_DispenserScreenState` into widget files. No behavior change intended;
no toolchain command was run (the orchestrator owns the gate:
`flutter test`, `dart format --set-exit-if-changed .`, `flutter analyze`,
plus `tool/check_no_literal_strings.dart`).

## Per file

### CREATED `lib/ui/dispenser/dispenser_closed_view.dart`

- `ClosedView`, public `StatelessWidget`, `const` constructor.
- Parameters: `bool continueOffered` (the one fact the `DispenserClosed`
  arm reads — `pocketMinutes` is chrome data and stays with the screen)
  and `VoidCallback? onExtend` (threaded to the continue control).
- `build` keeps the original dispatch shape verbatim:
  `continueOffered ? _closeWithContinue(context) : _closeText(context)`.
  Both private helpers moved word-for-word from the screen, including
  their doc comments; copy resolves through `AppStrings.of(context)`
  inside `build`; theme via `Theme.of(context)`; the only token is
  `Spacing.actionGap` from `../tokens.dart`.
- Zero string literals in code (the file's only quoted text sits in
  comments and import URIs, both exempt per the scanner).
- No `Semantics` existed in the closed arm before; none added.

### CREATED `lib/ui/dispenser/dispenser_rest_offer_view.dart`

- `RestOfferView`, public `StatelessWidget`, `const` constructor.
- Parameters: `VoidCallback? onPause` (the screen's `_onPause`, the
  checkpoint stop) and `VoidCallback? onExtend` (the screen's
  `_onExtend`, the silent continue). The `DispenserRestOffer` variant
  carries no field the arm itself reads.
- `_restOffer`'s body moved verbatim, including its doc comment;
  `HechoButton(label: strings.checkpointStop, onTap: onPause)` and
  `SecondaryTextAction(label: strings.checkpointContinue,
  onTap: onExtend)` with the same `Spacing.actionGap` between.
- Zero string literals in code; no `Semantics` existed in the arm
  before; none added.

### MODIFIED `lib/ui/dispenser/dispenser_screen.dart`

- Two imports added (alphabetical, sibling group):
  `dispenser_closed_view.dart`, `dispenser_rest_offer_view.dart`.
- `_viewContent`'s `DispenserRestOffer` and `DispenserClosed` cases are
  now thin constructions:
  `RestOfferView(onPause: _onPause, onExtend: _onExtend)` and
  `ClosedView(continueOffered: continueOffered, onExtend: _onExtend)`,
  wrapped exactly as before by `_withAmbientStrip` +
  `_withCompletionAck`, and still under `_withWarmReturnGreeting`.
- Removed `_closeText`, `_restOffer`, `_closeWithContinue` (moved with
  their doc comments). Everything else untouched: `_commitView`, all
  `_on*` handlers, the read spine, timers, observers, wrappers, chrome,
  the `NoSlicerSurface` import and `_openNoSlicerSurface`, the
  `DispenserDealt` case.

## Contract notes

- Callbacks: the new widgets declare `VoidCallback?` and pass through
  to `HechoButton`/`SecondaryTextAction`, which already apply the
  accepted-default `onTap ?? () {}` — the same arrangement as
  `TaskCard` (the copied sibling), so nothing is duplicated and a null
  callback still renders the accepted no-op, never a disabled control.
- Formatting: one line in `dispenser_rest_offer_view.dart`
  (`SecondaryTextAction(label: strings.checkpointContinue, onTap: onExtend),`)
  is exactly 80 columns and is the formatter's collapsed form (the page
  width is inclusive; the repo already carries exactly-80 lines, e.g.
  `dispenser_screen.dart`'s `setEnergy` line).

## Deviations from the brief

- "Move any prose header comment that documents these arms": I moved
  the three method-level doc comments verbatim. The top-of-file prose
  header of `dispenser_screen.dart` also contains a paragraph about the
  checkpoint offer (and mentions of the warm close); I left the
  screen's file header intact because it documents the whole surface's
  contract (reads, commits, wrappers, chrome) rather than the extracted
  widget code, and rewriting it would edit prose pinned to code that
  stays. The new files carry their own short headers citing origin.
  Flagging in case the orchestrator wants those paragraphs relocated in
  a later trozo.

## For the next trozo

- The extracted-arm pattern is established: data = the fields the arm
  reads from its `DispenserView` variant; controls = `VoidCallback?`
  threaded from the screen's `_on*` handlers; copy only through
  `AppStrings.of(context)` inside `build` (the literal scanner keys its
  allowlist by exact file path — a new file has none); tokens from
  `../tokens.dart`; reuse `HechoButton`/`SecondaryTextAction` from
  `task_card.dart` rather than re-styling.
- Still in the screen for later trozos: the `DispenserDealt` case (its
  `TaskCard` construction plus the `_degradedRescueDealId` /
  `_autoRescueFiredForDeal` / `_rescueFlightDealId` keyed logic lives in
  the handlers, not the arm), and the three wrappers
  (`_withCompletionAck`, `_withAmbientStrip`, `_withWarmReturnGreeting`)
  the arms are threaded through.
- `_onPause` and `_onExtend` are `Future<void> Function()` tear-offs
  passed as `VoidCallback?` — the same assignability the old inline
  wiring relied on; keep that when more arms move.

---
title: 'Manual Capture — one line, three sizes, and a frame instead of a rule'
type: 'feature'
created: '2026-09-01'
status: 'done'
review_loop_iteration: 0
baseline_commit: '3671fa31c372d4057f89dcf65fb83b289b30b0cd'
context:
  - '{project-root}/_bmad-output/implementation-artifacts/epic-3-context.md'
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** The pool has no manual-capture writer: the Dispenser carries no Lápiz entry, the Manual Capture surface (FR-27) does not exist, and a `PoolFact` cannot yet hold an Origin Context — so nothing the user promised by hand can enter the app, and 3.3 (how the capture comes back) has no fact to read.

**Approach:** Add the capture surface (`lib/ui/capture`) reachable in one tap from a new top-right Lápiz entry on the Dispenser; on `Guardar`, a new pure core command (`core/commands/capture_commands.dart`) returns the pool-fact content — origin `manual`, the chosen 1-3-5 size, Origin Context = its own single trimmed line — plus a `capture_created` log row; the shell mints one instant and one v7 id per row and appends through the shared `LogWriteQueue`. Persisted via schema v6: one additive nullable column `pool_facts.origin_context`.

## Boundaries & Constraints

**Always:**
- One tap from the Dispenser: Lápiz entry top-right, 24px `PencilGlyph` inside a 48dp target, `icon-mass-neutral`, present in both chrome branches (pinned and in-frame).
- Exactly two fields: one single-line text field + one size from exactly three `size-option` pills. Nothing else is asked — no project, category, date, priority, tags, recurrence, no confirmation screen. Copy says nothing about dates.
- Pills show durations `30 s` · `3 min` · `10–15 min` (en dash + NBSP, `{formats.duration}`), never internal taxonomy names; single-selection, always populated (`maintenance` preselected, per the canonical mockup), no empty state, no "none of these". Selected = accent-soft; unselected = surface-raised + 1px hairline; no glyph on any option; ≥48dp; `Semantics(button:, selected:)`.
- Copy in order: `captureTitle` → `captureHelper` → `captureExample` (verbatim ARB strings). The example is a rendered line in the Lora content register, not the field's hint; the field hint is `captureFieldPlaceholder`.
- Non-spatial lines are accepted in silence: no validation, no error state, no red edge, no corrective message or gentle equivalent; no second version of the screen exists.
- `Guardar` stays disabled until the trimmed line holds text — same accent-soft pill at reduced opacity (mockup `.save.dis` ≈ 0.45), not tappable, `Semantics(enabled: false)`. One secondary only: `Descartar`, which is also the exit; the system back gesture behaves as `Descartar`; no `Cancelar`.
- On `Guardar`: append the pool fact, then the `capture_created` entry (item pair = the fact's id + `Origin.manual`, nothing else); one minted instant for the batch, one v7 id per row; the write is serialized through the shared `LogWriteQueue`; the awaited write completes, then the route pops.
- Refusal is silence: the core command returns no content for a line that is blank after trimming (unreachable from the UI; the boundary's own shape).
- 200% floor: the surface scrolls (`SingleChildScrollView`), never ellipsizes (`maxLines`/`FittedBox`/textScaler overrides are banned by `check_text_scaling`); every target ≥48dp; all copy through `AppStrings` (no literals).

**Ask First:**
- Anything that would add a field, a confirmation step, validation, an error surface, a second exit, or any list/count of captures.
- If the schema change cannot stay additive (needs a table rebuild).

**Never:**
- No dictation: no mic capsule, no `Escuchando…`, no permission, no `Recognizer` port — story 3.4.
- No weave/resolver/read-facade change: a capture is not a candidate yet (3.3); `CandidatePrecedence` untouched; the read facade gains nothing.
- No UPDATE/DELETE anywhere; schema v6 is additive-only (`ALTER TABLE pool_facts ADD COLUMN origin_context TEXT NULL`); no new payload flags on existing kinds; `capture_created` rides the existing item-pair shape.
- No string authoring or re-wording: the seven capture strings already ship in the ARB; the only new key is the focus duration label.
- Core stays pure Dart (no Flutter/drift imports); ids and instants are minted in the shell only.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Happy path | Line `llamar al dentista`, size `focus`, `Guardar` | Exactly 1 pool fact (origin `manual`, size `focus`, `origin_context` = trimmed line) + 1 `capture_created` (itemId = fact id, itemOrigin `manual`); route pops | N/A |
| Blank line | Empty or whitespace-only line | `Guardar` disabled; a tap does nothing; command returns null | N/A |
| Non-spatial line | Any text | Accepted in silence — same writes, no error widget ever | N/A |
| `Descartar` / back | Any state | No writes; route pops with no confirmation | N/A |
| Rapid double-tap `Guardar` | Two taps before the write settles | In-flight guard: exactly one fact + one entry | Quiet |
| Store append throws | Failing store | Surface stays with the line intact, nothing surfaced, retry possible | Quiet absorption |
| v5 install upgrade | Old database | `origin_context` added NULL; existing rows unchanged | N/A |

</frozen-after-approval>

## Code Map

- `packages/core/lib/pool/pool_fact.dart` -- `Origin` (L14, `manual` L19) and `Size` (L33: `instant`≈30 s, `maintenance`≈2–3 min, `focus`≈10–15 min) exist; `PoolFact` (L50) gains nullable `originContext` (AD-14: the single line; null for origins whose context lives elsewhere).
- `packages/core/lib/log/log_entry.dart` -- add `LogKind.captureCreated` to the statics + `knownByName` (L54); `capture_created` joins the `ItemActEntry` (L112) family: extend its doc and `_isItemAct` (L430) so `convertLogEntryRecord` (L459) accepts the full item pair and nothing else — existing flaws `halfItemPair`/`itemPairAbsent`/`itemOnNonItemKind` then cover it with no new flaw members.
- `packages/core/lib/commands/session_commands.dart` -- `LogEntryContent` typedef (L68) reused verbatim.
- `packages/core/lib/commands/capture_commands.dart` -- NEW, the `energy_commands.dart` single-minter pattern: `CaptureContent? captureCreate({required String factId, required String line, required Size size})` returning `(fact: (origin, size, trimmedLine), entry: LogEntryContent)`.
- `packages/core/lib/ports/store_port.dart` -- `PoolFactRecord` (L22) gains `String? originContext`.
- `lib/store/substrate.drift` + `lib/store/substrate.dart` -- schema v6: drift column + `poolFactsOriginContextUpgrade` const on the v2→v5 pattern (L24–59), `schemaVersion => 6` (L71), `onUpgrade` `from < 6` step (L91).
- `lib/store/drift_store.dart` -- `appendPoolFact` (L26) writes the column; `readPoolFacts` (L64) returns it.
- `lib/l10n/app_es.arb` -- the seven capture strings ship at :326–359; add `durationFocusRange` = `10–15\xa0min` with an `@` description (audit requires it only for pinned no-Slicer keys).
- `lib/ui/dispenser/duration_chip.dart` -- `durationLabel` (L22) covers `30 s`/`3 min`; add `sizeOptionLabel(Size, AppStrings)` mapping instant/maintenance/focus.
- `lib/ui/dispenser/dispenser_screen.dart` -- top chrome band `_pocketTrigger` (L722) renders in both branches (L400–421): the Lápiz target joins it, top-right, without displacing the centred chip (band Row/Stack; chip keeps screen-centre). Push precedent with `ModalRoute.isCurrent` guard: L940–948. Pill precedent `_PocketLadderOption` L1117. `_cardMaxWidth` L125.
- `lib/ui/dispenser/task_card.dart` -- `HechoButton` (L29, `label` param) and `SecondaryTextAction` (L90) are the Guardar/Descartar registers.
- `lib/capture/capture_controller.dart` -- NEW, `DispenserController.complete` pattern (dispenser_controller.dart L370–404): `nowOf()` at entry, `_enqueueWrite` over the shared `LogWriteQueue` (lib/session/log_write_queue.dart), append fact then entry.
- `lib/ui/capture/capture_screen.dart` -- NEW surface; DOM order per `mockups/mic-manual-capture-1.html` §3 (heading → helper → example → field → sizes → save → discard; the mic capsule is 3.4 — field renders full-width). Scaffold/SafeArea/scroll precedents: `nuevo_proyecto_screen.dart`, `settings_screen.dart` (:104–107). Registers (theme.dart L73–82): title `headlineSmall`, helper `bodySmall`, example `headlineMedium` (Lora), field text Lora with Lexend hint, pills `titleSmall`, Guardar `bodyLarge`, Descartar `bodyMedium`. Field: raised fill, 1px hairline, radius 14, min-height 48.
- `lib/main.dart` -- wire `CaptureController` (store, shared `logWrites`, `nowOf`, `Uuid`) as `OrganizerApp.capture` → `DispenserScreen`, threaded like `settings` (optional = test seam).
- Tests: core golden pattern `packages/core/test/energy_commands_test.dart` (content rows + round-trip through `convertLogEntryRecord`), `test_util.dart` `utcMicros`; shell `test/store/substrate_test.dart` (migration pinning, `_fact()` factory L14); widget harness `test/ui/settings/settings_screen_test.dart` (`_RecordingStore`, `textsOf` census).

## Tasks & Acceptance

**Execution:**
- [x] `packages/core/lib/pool/pool_fact.dart` + `packages/core/lib/ports/store_port.dart` -- add nullable `originContext` to `PoolFact` and `PoolFactRecord` (AD-14 single line) -- the fact's one payload this story.
- [x] `packages/core/lib/log/log_entry.dart` -- add `captureCreated` kind; classify it as an item act (doc + `_isItemAct` + conversion branch) -- a new kind is a new kind, never a flag.
- [x] `packages/core/lib/commands/capture_commands.dart` -- NEW `captureCreate` -- the single sanctioned minter of `capture_created` rows and manual pool facts.
- [x] `lib/store/substrate.drift` + `lib/store/substrate.dart` + `lib/store/drift_store.dart` + regenerated `lib/store/substrate.g.dart` (`make codegen`) -- schema v6 additive column, migration step, append/read -- old installs upgrade in place.
- [x] `lib/l10n/app_es.arb` + regenerated strings (`make codegen`) -- add `durationFocusRange` -- the one label the duration format family lacks.
- [x] `lib/ui/dispenser/duration_chip.dart` -- add `sizeOptionLabel(Size, AppStrings)` -- durations, never taxonomy names.
- [x] `lib/capture/capture_controller.dart` -- NEW `save(line, size)` write path over the shared queue -- one instant per batch, fact before the entry referencing it.
- [x] `lib/ui/capture/capture_screen.dart` -- NEW surface per the Code Map order; disabled-`Guardar` variant of the Hecho register; `Descartar` = `SecondaryTextAction`; in-flight guard; quiet failure absorption -- the story's whole UI.
- [x] `lib/ui/dispenser/dispenser_screen.dart` + `lib/main.dart` -- top-right Lápiz entry in both chrome branches, guarded push, `CaptureController` wiring -- the one-tap reachability.
- [x] `packages/core/test/capture_commands_test.dart` (flat, the repo's core-test convention — the spec's `test/commands/` path does not exist) + `log_test.dart` additions + record-field updates across core tests -- golden minter test, blank refusal, conversion round-trip, item-pair flaws cover the new kind.
- [x] `test/store/substrate_test.dart` -- v5→v6 migration pin + `origin_context` round-trip; update `_fact()` and shell test fakes (`_RecordingStore` etc.) for the record field.
- [x] `test/ui/capture/capture_screen_test.dart` -- NEW: one-tap entry; exactly two fields; pill labels/selection/preselection; copy order; disabled `Guardar` appends nothing; `Guardar` writes fact+entry then pops; `Descartar`/back write nothing; non-spatial silence via the `textsOf` census.

**Acceptance Criteria:**
- Given the Dispenser, when rendered, then a Lápiz entry sits top-right at ≥48dp and one tap opens Manual Capture.
- Given the capture surface, when audited, then it holds exactly two fields, its copy read in order names a place, touchable things and a spatial-verb example, and nothing on it mentions dates.
- Given the three size pills, when rendered, then they show the three durations with one preselected and no empty state, and no internal taxonomy name renders.
- Given the surface's controls, when counted, then there is one primary (`Guardar`) and one secondary (`Descartar`, also the exit) and no `Cancelar`.
- Given the store after a completed capture, when read, then exactly one manual pool fact and one `capture_created` entry exist, sharing the batch instant, the entry's item pair naming the fact.
- Given the user has left the surface by any exit, when they look for the captured line, then no correction or discard path exists anywhere — the only path back to it is being dealt (3.3).

### Review Findings

- [x] [Review][Patch] Lápiz unlabeled for TalkBack — authorized copy `Lápiz - anotar` [lib/ui/dispenser/dispenser_screen.dart:1191]
- [x] [Review][Patch] Guardar test never pins the batch instant to `nowOf()` [test/ui/capture/capture_screen_test.dart:504]
- [x] [Review][Patch] Padded non-blank line never asserted on the persist path [test/ui/capture/capture_screen_test.dart:487]
- [x] [Review][Patch] Persisted size only asserted after tapping the focus pill [test/ui/capture/capture_screen_test.dart:493]
- [x] [Review][Defer] Two-append capture batch is not atomic [lib/capture/capture_controller.dart:53] — deferred, pre-existing

## Spec Change Log

## Design Notes

- The line lives on `pool_facts`, not the log: 3.3 reads `readPoolFacts()` to name the dealt card, Rescue Mode later re-slices the Origin Context, and the log stays payload-minimal (item pair only) — the AD-23 shape every other kind follows.
- `factId` goes into the command so the shell stays a verbatim copier (the `cardDone` precedent: commands receive item ids, they never mint them); minting a v7 id for a refused blank capture names nothing and appends nothing.
- `Guardar` is the app's first true disabled control: opacity ≈0.45 over the same accent-soft pill + `IgnorePointer` + `Semantics(enabled:)`. The house `onTap: () {}` no-op pattern is for accepted no-ops — a disabled `Guardar` must refuse the tap, not accept it silently.
- Size→pill: `instant`→`30 s`, `maintenance`→`3 min` (preselected), `focus`→`10–15 min`; preselection is what "always populated" means with no empty state.

## Verification

**Commands:**
- `devbox run -- make gate` -- expected: green (flutter test, format check, analyze).
- `devbox run -- make check` -- expected: green (core purity, no-literal-strings, string-table audit with the new `@durationFocusRange` block, text scaling, forbidden vocabulary, store seal, codegen freshness for `substrate.g.dart` + strings).

## Suggested Review Order

**The minter — one pure function owns the capture's whole meaning**

- The single sanctioned minter: fact payload + `capture_created` row; blank-after-trim returns nothing
  [`capture_commands.dart:55`](../../packages/core/lib/commands/capture_commands.dart#L55)

- The twelfth kind — a new kind, never a flag; rides the item-pair shape
  [`log_entry.dart:53`](../../packages/core/lib/log/log_entry.dart#L53)

- `capture_created` joins the ItemActEntry family at the read boundary
  [`log_entry.dart:439`](../../packages/core/lib/log/log_entry.dart#L439)

- The Origin Context: the single trimmed line, nullable, written once (AD-14)
  [`pool_fact.dart:83`](../../packages/core/lib/pool/pool_fact.dart#L83)

**Persistence — schema v6, additive only**

- One named ALTER adds `origin_context`; `schemaVersion => 6`
  [`substrate.dart:67`](../../lib/store/substrate.dart#L67)

- The adapter writes and reads the column verbatim
  [`drift_store.dart:36`](../../lib/store/drift_store.dart#L36)

**The surface — two fields, a frame, and a first disabled control**

- The whole surface in one read: copy order, field, pills, save, discard
  [`capture_screen.dart:50`](../../lib/ui/capture/capture_screen.dart#L50)

- `Guardar`'s write path: blank re-guard, awaited write, pop after landing
  [`capture_screen.dart:101`](../../lib/ui/capture/capture_screen.dart#L101)

- The exit gate: Descartar and system back refuse while a save is in flight
  [`capture_screen.dart:155`](../../lib/ui/capture/capture_screen.dart#L155)

- The one-line field: Lora content, Lexend hint, single-line formatter
  [`capture_screen.dart:227`](../../lib/ui/capture/capture_screen.dart#L227)

- The first true disabled control: opacity + IgnorePointer + Semantics(enabled: false)
  [`capture_screen.dart:287`](../../lib/ui/capture/capture_screen.dart#L287)

- The Lápiz entry joins the top band, top-right, both chrome branches
  [`dispenser_screen.dart:787`](../../lib/ui/dispenser/dispenser_screen.dart#L787)

- Durations only, never taxonomy names — the one label source for the pills
  [`duration_chip.dart:40`](../../lib/ui/dispenser/duration_chip.dart#L40)

- The one new string, with its `@` description
  [`app_es.arb:79`](../../lib/l10n/app_es.arb#L79)

**The write seam — shell mints, core decides**

- `save`: one instant per batch, fact before the entry that names it, shared queue
  [`capture_controller.dart:50`](../../lib/capture/capture_controller.dart#L50)

- Wiring: same store, same shared write queue as the Dispenser
  [`main.dart:52`](../../lib/main.dart#L52)

**Evidence**

- Ten widget tests: entry, census, pills, disabled save, writes, races, silence
  [`capture_screen_test.dart`](../../test/ui/capture/capture_screen_test.dart)

- Golden minter test: content rows, trimming, refusal, round-trip
  [`capture_commands_test.dart:10`](../../packages/core/test/capture_commands_test.dart#L10)

- v5→v6 upgrade pinned in place
  [`substrate_test.dart:1455`](../../test/store/substrate_test.dart#L1455)

- The twelfth kind now pins Warm Return contact
  [`warm_return_test.dart:212`](../../packages/core/test/warm_return_test.dart#L212)

- And the weave walk's inertness to capture rows
  [`weave_test.dart:2221`](../../packages/core/test/weave_test.dart#L2221)

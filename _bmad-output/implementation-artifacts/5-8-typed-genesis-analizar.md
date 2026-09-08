---
title: 'Story 5.8: Typed genesis — Analizar'
type: 'feature'
created: '2026-09-07'
status: 'done'
review_loop_iteration: 0
baseline_commit: '8b7f15907592bb35639d33b9a21968c82bbdd371'
context:
  - '{project-root}/_bmad-output/implementation-artifacts/epic-5-context.md'
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** The surface behind `Nuevo proyecto` is still 2.1's honest intermediate — an empty carrier whose only content is the `Ajustes` way-out — so typed genesis (FR-11's second entrance, FR-25) does not exist: a project described in words has no way into the Slicer, while the `GenesisSliceRequest` port shape, the `ProjectGenesisText` egress payload and the ARB keys `genesisAnalyze`/`genesisBack` all sit declared and unused.

**Approach:** Grow `nuevo_proyecto_screen.dart` in place into the typed genesis surface — description field, `Analizar` as the consent action (disabled until text, `Guardar`'s mirror), body copy stating analysis→tasks with no provider name, quiet `Volver` + `Ajustes` bottom row — plus a `GenesisController` mirroring the scan channel's discipline minus camera/face/cache/token: fail-closed provider read, `consent_granted` at `Analizar`, the unbounded wait (`Creando tareas` + pencil), `slice_failed{cause}` on failure, `scan_abandoned` on mid-wait departure, and 5.7's landing verbatim (`parseScanSlice` → `scanSliceLanded` seeds → per-fact appends). The Local stub gets its genesis branch; the one NoSlicer string that names only the photo half is reworded to name both.

## Boundaries & Constraints

**Always:**
- `Analizar` is the consent act itself — the send IS the consent: no separate dialog, no provider name anywhere on the surface (FR-25, NFR4 — destination stated, provider unnamed). Disabled until `trim().isNotEmpty` behind `IgnorePointer` + reduced opacity + `Semantics(enabled: false)` — the `_canSave` idiom (`capture_screen.dart:189`).
- Instrumentation reuses the scan channel's vocabulary verbatim — `consent_granted` (Analizar tap), `slice_failed{cause}` (both failure arms), `scan_abandoned` (mid-wait departure), landed facts as the plan's record — the same single-sanctioned minters (`scan_commands.dart`); kind census stays 20; "the text path is instrumented like the photo path" (FR-26 b).
- The wait rides 5.6's semantics unchanged: uncapped, `Creando tareas` + `WritingPencil` (existing key, illustration register), lifecycle `hidden/paused/detached` or dispose → close → exactly one `scan_abandoned` + discard; the epoch guard folds late resolutions to stale (no landing, no rows).
- Failure routing is the existing map: `SlicerFailed(cause)` → `scanSliceFailed(cause)` → `NoSlicerSurface(noSlicerCauseFromFailure(cause))`; a body that parses but violates the step contract → the one declared `malformedResponse` fold. Never an eighth cause, never a new degradation surface.
- The genesis prompt is shell-side non-ARB prose (the `_scanPrompt` precedent, `scan_controller.dart:807`) composing instruction + the user's description + the scan JSON contract, wire names interpolated from `scan_steps.dart` — so `parseScanSlice` parses the answer unchanged; parity pinned test-side (prompt ↔ parse ↔ stub).
- The provider read is fail-closed BEFORE any row or dispatch: selected null or not allowlisted → `pushReplacement(NoSlicerSurface(cause: noKey))` — `_continueToConsent`'s mirror (`scan_screen.dart:294-332`: `readSelectedProvider`, `allowlistEntryById`).

**Ask First:**
- Any string edit beyond the two new keys and the one declared `noSlicerNoKey` reword; any egress/cap/token/`ScanConsent*`/`SlicerRequest`/`EgressPayload` change; any new log kind.
- Any weave candidacy for the landed facts, one-card surface, or Epic Project/activation seam (all 5.9's).

**Never:**
- No `ScanConsent` minting on this path — the token binds to scan cache identities only; the typed dispatch structurally rides `ProjectGenesisText` token-free (`egress_dispatch.dart:57-92`).
- No camera, face gate, cache subdir, sweep, or image anything.
- No timeout, queue, retry or second dispatch; no `PopScope` on the compose state; no new route beyond the surface's own file.
- No template list, curation row, buffers or suggestion — 5.9–5.13.
- No provider-id binding fix for 5.5's deferred finding (`deferred-work.md:303-307`) — recorded for the Epic 5 retro, not solved here.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Empty description | field blank / whitespace | `Analizar` stays disabled (`Guardar` mirror) | Tap refused, never a silent no-op |
| No key at `Analizar` | selected provider null / not allowlisted | `NoSlicerSurface(noKey)` before any row or call | Reworded string names both halves |
| Happy path | description + reachable provider | `consent_granted` → dispatch → wait → delivered → parse ok → N facts (origin cloud / local) → pop to Dispenser | Quiet store-failure absorption |
| Violation body | parses, breaks the step contract | `slice_failed(malformedResponse)` + NoSlicer unreachable string | The declared fold |
| Failed dispatch | `SlicerFailed(cause)` | `slice_failed{cause verbatim}` + NoSlicer mapped cause | Existing seven-cause surface |
| Dispatch throws | port throws | `slice_failed(providerUnreachable)` + NoSlicer | Scan's throw-arm mirror |
| Mid-wait departure | lifecycle / dispose during wait | One `scan_abandoned`, discard, no landing | Quiet |
| Stale resolution | resolution after close | No landing, no rows — the abandonment stands | Quiet |
| Local stub | `ORGANIZER_LOCAL_SLICER` debug build | Genesis branch returns the scan-contract canned body; facts origin `local` | Parity: prompt ↔ parse ↔ stub |

</frozen-after-approval>

## Code Map

- `lib/genesis/genesis_controller.dart` -- NEW: the typed channel. Mirror `scan_controller.dart`'s composition and discipline (slicer + store + shared write queue, `_epoch` guard, the scan precedent's surface-driven phases (no notifier — the surface owns its `_waiting` state)) minus camera/gate/cache/token. `analyze(description)` guards non-empty, mints `consentGranted()`, dispatches `GenesisSliceRequest(text: _genesisPrompt(description))` once; delivered → `parseScanSlice(responseBody)` → `scanSliceLanded` seeds → per-fact `appendPoolFact` (origin `slicer is LocalSlicer ? Origin.local : Origin.cloud`); violation / `SlicerFailed` arms → `_appendGenesisSliceFailed` (the `_appendScanSliceFailed` shape, `scan_controller.dart:745`); throw arm → `providerUnreachable`; `close()` mid-flight → `scanAbandoned()`. `_genesisPrompt` — one-line non-ARB instruction + interpolated description + the scan JSON contract from `scan_steps.dart` wire consts (literal-ban allowance per declaration).
- `lib/ui/settings/nuevo_proyecto_screen.dart` -- the surface's home; grow in place (keep no-heading surfaceBase, the safe-area footer idiom, the `Ajustes` push + rapid-tap guard). Becomes stateful: body copy, description field, `Analizar` (recommended action, the `Guardar` pill register), `Volver` (pop) beside `Ajustes` in the quiet bottom row; wait state replaces compose (`Creando tareas` + `WritingPencil`, field/actions gone); fail-closed provider read at the `Analizar` tap; `WidgetsBindingObserver` closes the controller in wait (`consent_gate_screen.dart:104-139` mirror).
- `lib/egress/local_slicer.dart` -- the genesis branch: `ScanSliceRequest || GenesisSliceRequest → _scanCannedBody()`; the header's "genesis rides the rescue shape until 5.8 authors its own" retires.
- `lib/l10n/app_es.arb` (+ `make codegen`) -- NEW `genesisBody` ("La descripción se analizará para crear las tareas.") and `genesisFieldHint` ("Describe el proyecto"), each with `@description`; REWORD pinned `noSlicerNoKey` (:154) — "Crear un proyecto con una foto o con una descripción necesita una" — x-signoff refreshed.
- `lib/main.dart` + `lib/ui/dispenser/dispenser_screen.dart:1004-1021` -- compose `GenesisController` at the root (`ScanController`'s pattern, `main.dart:96`), thread through `OrganizerApp` → `DispenserScreen` → the `_openNuevoProyecto` push.
- Read-only: `packages/core/lib/commands/scan_commands.dart` (minters reused verbatim), `packages/core/lib/slicer/scan_steps.dart` (`parseScanSlice` + wire consts), `lib/egress/egress_dispatch.dart` + `byok_slicer.dart:110-121` (genesis rides `ProjectGenesisText` untouched), `packages/core/lib/ports/no_slicer_cause.dart`, `lib/ui/no_slicer/no_slicer_surface.dart`, `lib/derive/warm_return.dart:93` (kind rules carry genesis rows automatically).
- Tests: NEW `test/genesis/genesis_controller_test.dart` (the full I/O matrix, on `scan_controller_test.dart`'s group shapes); NEW `test/ui/settings/nuevo_proyecto_screen_test.dart` (disabled-until-text, `Volver`/`Ajustes`, no-key routing, wait copy, lifecycle abandon — `consent_gate_screen_test.dart`'s mirror); RENEGOTIATE `test/no_lateness_proof_test.dart` (per-file census maps grow the genesis file; `appendPoolFact` sites 3 → 4; invocation pins), `test/ui/settings/settings_screen_test.dart:263-284,668,741,1236` (the surface is no longer empty), the local-slicer parity test (genesis branch parses via `parseScanSlice`), `tool/check_no_literal_strings.dart` allowance for `_genesisPrompt`.

## Tasks & Acceptance

**Execution:**
- [x] `lib/genesis/genesis_controller.dart` -- NEW controller: analyze / wait / abandon / land on the scan discipline minus the photo mechanics -- the typed channel's one home
- [x] `lib/ui/settings/nuevo_proyecto_screen.dart` -- grow the surface: field, body copy, `Analizar` / `Volver` / `Ajustes`, wait state, provider read, lifecycle -- the surface ACs' home
- [x] `lib/main.dart` + `dispenser_screen.dart` -- compose and thread the controller -- the channel reaches its ports
- [x] `lib/egress/local_slicer.dart` -- genesis branch → scan-contract canned body -- the stub stops answering genesis in rescue dialect
- [x] `lib/l10n/app_es.arb` (+ codegen) -- two new keys + one reword with refreshed signoff -- the consent copy and the both-halves naming
- [x] Tests -- the renegotiation list in the Code Map, incl. the two NEW suites -- the matrix pinned

**Acceptance Criteria:**
- Given the `Nuevo proyecto` surface, when opened, then typed entry is its one recommended action (`Analizar`), `Volver` its quiet exit and `Ajustes` its Settings way-out — principle 1's arithmetic, E2 stays dissolved (FR-11, UX-DR25).
- Given the two genesis entrances, when compared, then the photo path is the Dispenser's own Cámara entry and the typed path sits behind `Nuevo proyecto` — neither a precondition for the other, manual entry one tap asking for nothing (FR-11).
- Given the surface, when read, then it states in plain Spanish that the description will be analysed to create tasks — no provider name, no separate dialog; `Analizar` is the consent (FR-25, NFR4, UX-DR52).
- Given no reachable Slicer, when genesis is attempted by either entrance, then FR-29 degradation holds and the no-key copy names both halves — the photo path never steals the typed path's diagnosis (FR-11, FR-29).
- Given a text-genesis call, when instrumented, then it is recorded on the photo scan's own terms — consent_granted / facts / slice_failed / scan_abandoned, kind census 20, none inferred from absence (FR-26 b).

## Spec Change Log

## Design Notes

- **Why the same kinds, not a parallel genesis vocabulary.** FR-26 b's "on the same terms" is literal: a different kind per row would instrument the text path differently from the photo path and renegotiate the spine's naming table for zero information gain. The minters are kind-scoped, not scan-scoped; `scan_abandoned`'s name is the photo channel's accident — its rule ("the unbounded wait's one honest resolution the user's own departure caused") is exactly the typed wait's rule.
- **Why the prompt carries the contract.** Genesis rides `ProjectGenesisText` schema-less by design — the sealed shapes cannot grow a field (`deferred-work.md:303-307`). Composing instruction + description + JSON shape at the controller seam makes the answer parseable by `parseScanSlice` unchanged: one parser, one landing, one Origin Context rule for both entrances.
- **Why `Volver` and `Ajustes` coexist.** EXPERIENCE.md:35 pins `Volver` as the quiet exit; :52 pins Settings as quiet text *inside* the affordance's surface — the load-bearing consequence of dissolving the Ajustes glyph (without it, Settings loses its documented route from the Dispenser). Both are quiet text, neither recommended: one recommended action plus ways out, the Dispenser footer band's own grammar (`Quiero parar` + `Nuevo proyecto`).
- **Partial-visibility honesty, inherited from 5.7.** A successful typed genesis lands facts no surface deals yet — 5.9 owns the one-card landing. Manual verification reads the substrate, not the screen.

## Verification

**Commands:**
- `devbox run -- make gate` -- expected: green (format, analyze, all tests incl. the two new suites and the renegotiated censuses)
- `devbox run -- make check` -- expected: green — ARB audit + signoff fresh, literal-ban allowance updated, codegen clean
- `devbox run -- flutter test test/genesis/ test/ui/settings/ test/scan/` -- expected: exit 0

**Manual checks (device, AGENTS.md recipe):**
- No-key path: fresh state → `Nuevo proyecto` → type → `Analizar` → NoSlicer surface with the reworded both-halves string; pulled substrate shows zero new rows (the call never happened).
- Success path: debug build `--dart-define=ORGANIZER_LOCAL_SLICER=true` → `Nuevo proyecto` → type → `Analizar` → `Creando tareas` → Dispenser; substrate shows `consent_granted` + N pool facts (origin `local`, estimates 180–300, `origin_context` = the canned description).
- Departure: `Analizar` → wait → home button → return → substrate shows one `scan_abandoned`, no facts, no queued retry.

## Suggested Review Order

**The typed channel — the story's heart**

- One `consent_granted`, one token-free dispatch, 5.7's landing verbatim, epoch-guarded wait.
  [`genesis_controller.dart:154`](../../lib/genesis/genesis_controller.dart#L154)

- The genesis prompt: instruction + description + the shared JSON contract.
  [`_genesisPromptHead:367`](../../lib/genesis/genesis_controller.dart#L367)

- Both failure arms + the throw fold — the scan's single-writer shapes.
  [`_appendGenesisSliceFailed:225`](../../lib/genesis/genesis_controller.dart#L225)

- `close()` mid-flight mints the wait's one honest resolution.
  [`close:247`](../../lib/genesis/genesis_controller.dart#L247)

**The surface — `Analizar` is the consent**

- The tap: fail-closed read before any row, pre-dispatch aborts (route lost / departure).
  [`_onAnalyze:199`](../../lib/ui/settings/nuevo_proyecto_screen.dart#L199)

- The field: one line, capped at the contract's description bound, Done submits.
  [`_field:411`](../../lib/ui/settings/nuevo_proyecto_screen.dart#L411)

- The pill: disabled until text (`Guardar`'s mirror), never a silent no-op.
  [`_analyzeAction:462`](../../lib/ui/settings/nuevo_proyecto_screen.dart#L462)

- The departure flag: no egress ever rides a departure.
  [`_departed:169`](../../lib/ui/settings/nuevo_proyecto_screen.dart#L169)

**One contract, both entrances**

- The shared response-contract const — no phrasing drift between scan and genesis prompts.
  [`scanResponseContract:87`](../../packages/core/lib/slicer/scan_steps.dart#L87)

- The scan prompt composes it, byte-identical.
  [`_scanPrompt:810`](../../lib/scan/scan_controller.dart#L810)

**The stub & the copy**

- Genesis answers in the scan dialect now — the declared debt retired.
  [`local_slicer.dart:61`](../../lib/egress/local_slicer.dart#L61)

- Two new keys, no provider name; `noSlicerNoKey` names both halves.
  [`app_es.arb:154`](../../lib/l10n/app_es.arb#L154)

**The threading — and its pin**

- Composed at the root, the scan seam's sibling.
  [`main.dart:111`](../../lib/main.dart#L111)

- The third hop: the footer's quiet departure carries the same controller.
  [`dispenser_screen.dart:1029`](../../lib/ui/dispenser/dispenser_screen.dart#L1029)

- The seam pin: dropping any link fails here with every suite otherwise green.
  [`app_test.dart:325`](../../test/ui/app_test.dart#L325)

**The pins**

- The landing matrix + prompt parity, controller-side.
  [`genesis_controller_test.dart:216`](../../test/genesis/genesis_controller_test.dart#L216)

- The pre-dispatch aborts, pinned surface-side.
  [`nuevo_proyecto_screen_test.dart:301`](../../test/ui/settings/nuevo_proyecto_screen_test.dart#L301)

- Scan's prompt ends with the same shared sentence.
  [`scan_controller_test.dart:826`](../../test/scan/scan_controller_test.dart#L826)

### Review Findings

- [x] [Review][Patch] Restore the opening object brace in `scanResponseContract`; the shared contract sent by both scan and genesis prompts is not valid JSON as written [`packages/core/lib/slicer/scan_steps.dart:87`](../../packages/core/lib/slicer/scan_steps.dart#L87)
- [x] [Review][Patch] Clear `_departed` when the surface resumes; after an idle pause or background transition, the screen can appear active while every later `Analizar` attempt is silently abandoned [`lib/ui/settings/nuevo_proyecto_screen.dart:156`](../../lib/ui/settings/nuevo_proyecto_screen.dart#L156)
- [x] [Review][Patch] Keep the abandonment guard active through terminal parsing and persistence; `close()` can otherwise miss `scan_abandoned` and allow terminal facts or failure rows after departure [`lib/genesis/genesis_controller.dart:185`](../../lib/genesis/genesis_controller.dart#L185)
- [x] [Review][Patch] Snapshot the consented description at tap time; the dispatch currently reads the mutable text field after awaiting the provider lookup [`lib/ui/settings/nuevo_proyecto_screen.dart:212`](../../lib/ui/settings/nuevo_proyecto_screen.dart#L212)
- [x] [Review][Patch] Align the input limit with the parser's UTF-16 code-unit bound; `LengthLimitingTextInputFormatter` counts grapheme clusters and can admit more than 400 code units [`lib/ui/settings/nuevo_proyecto_screen.dart:428`](../../lib/ui/settings/nuevo_proyecto_screen.dart#L428)

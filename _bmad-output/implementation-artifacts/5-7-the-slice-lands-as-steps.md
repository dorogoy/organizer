---
title: 'Story 5.7: The slice lands as steps'
type: 'feature'
created: '2026-09-07'
status: 'done'
review_loop_iteration: 0
baseline_commit: '306eb7d3ce9079edbd92753d506db525d0c93856'
context:
  - '{project-root}/_bmad-output/implementation-artifacts/epic-5-context.md'
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** The delivered arm is still 5.5's interim discard (`consent_gate_screen.dart:211-214` — "5.7 replaces exactly this arm"): `SlicerDelivered` carries only an opaque `responseBody` (`slicer_port.dart:151`), so a successful scan lands nothing — no steps, no pool facts, no Origin Context — while the image is unlinked and the space's diagnosis is lost with it. The product also has no single duration→size rule: rescue hardcodes `Size.instant` in two places, one derivation reads the size bucket where it should read the estimate, and nothing pins the estimate-vs-size jurisdiction.

**Approach:** Parse the delivered body in pure core on the `parseRescueSteps` precedent and land each step as a pool fact — estimate verbatim (minutes × 60), size from the ONE fixed banding (≤ 60 s → instant, 61 s–9 min → maintenance, ≥ 10 min → focus), `originContext` = the Slicer's space description (FR-16's letter), the step's own words in one new additive `stepText` column, origin `cloud` (BYOK) / `local` (debug stub). A body that parses but violates the step contract folds into `slice_failed` under the existing `malformedResponse` cause — surfaced by the existing provider-unresponsive string, never an eighth cause. Scan-side failed dispatches mint the same row, closing FR-26 series (b)'s outcome vocabulary.

## Boundaries & Constraints

**Always:**
- The banding is the product's ONLY duration→size rule: one core function beside `Size` (`pool_fact.dart`), rescue's two landing sites route through it (behavior byte-identical: 1–60 s → instant), and size governs only same-size precedence and 1-3-5 shape counting. Every duration-consuming rule reads the estimate — pocket (`weave.dart:626`), 🔴 filter (`weave.dart:559`), session charging (`session.dart:385-386`) already do; the one size-only site (`eligible_day.dart:119-120`) switches to the fact's effective estimate (`estimateSeconds ?? estimateSecondsOf(size)`).
- The parse is pure core, mirrors `rescue_steps.dart` discipline: bounds re-enforced whatever the wire dropped, unknown extra keys tolerated, nothing repaired or truncated; one fold — ANY contract violation (non-JSON, missing/empty description, step count outside the bound, empty/oversize text, `duration_minutes` not an integer 3–5) is the one declared mapping to `SlicerFailed(malformedResponse)` → the existing NoSlicer provider-unresponsive routing.
- Estimate verbatim: `duration_minutes × 60`; the store read clamp (`store_port.dart` `poolFactsOf`) widens from the rescue band to the UNION of the two slicer contracts (1–60 ∪ 180–300 s, constants imported from the two parsers); anything else still reads absent — quiet tolerance, never a repair write.
- A Manual Capture's estimate IS its size's canonical value BY RULE — the existing `?? estimateSecondsOf(size)` fallback every reader already applies. Nothing is stored on the capture path and the capture path does not change.
- Facts are minted core-side (`scanSliceLanded` seeds carry origin, size-from-banding, stepText, originContext, estimateSeconds); the shell mints only id/instant/offset and rides the shared `LogWriteQueue` / `appendPoolFact`, quiet on store failure. Per-fact appends, no cross-fact transaction — the substrate is insert-only and a partial plan derives fine.
- Scan-side `slice_failed` rows are minted after the resolution survives the existing epoch checks, on the `_appendScanAbandoned` wrapper shape (no in-closure epoch re-check — the resolution is what makes the row true), for BOTH the violation arm and the plain `SlicerFailed` arm. No new log kind: the census stays 20; `SliceEntry` renegotiates to an optional item pair (scan rows carry cause only).
- Zero new ARB keys, zero surface changes: delivered still pops to the Dispenser (the one-card landing is 5.9's); failure routing is the existing `ScanConsentFailed` → `NoSlicerSurface` chain.

**Ask First:**
- Any string/ARB edit; any egress, cap, mime, token or `ScanConsent` change; any new log kind; any change to the `ScanConsent*` outcome types.
- Any Epic Project/entity/activation surface (5.9's), any weave candidacy for scan facts, any one-card surface.
- Any prompt change beyond adding the description clause; any bound other than the declared parse-owned constants.
- If any census (`appendPoolFact` sites, invocation pins, kind census) cannot renegotiate additively.

**Never:**
- No scan-side `slice_requested`/`slice_returned` rows — rescue's vocabulary stays rescue's; the plan's record is the landed facts themselves (`consent_granted` + facts = series (b)'s "plan" outcome).
- No estimate stored on manual captures; no re-banding of a size by an estimate or re-deriving an estimate from a size.
- No timeout, queue, retry or second dispatch; no `PopScope`; no new route/surface file.
- Scan facts stay invisible to the weave: `captureCandidates` filters `origin == manual` (`weave.dart:262`) and 5.7 does not touch it — 5.9 wires Epic material under the one resolver, with Focus-slot eligibility by candidate class, never size (recorded in the banding's doc as 5.9's rule).
- Egress byte-untouched: the parse reads the delivered body AFTER the port returns; the port still promises only a non-empty extraction.
- No face-gate, camera, cache or sweep changes.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Delivered, parses | body = `{"description": …, "steps": [{"text", "duration_minutes": 3–5}]}` | N facts landed: origin cloud (BYOK) / local (stub), size = banding(estimate) = maintenance, estimate = min×60, originContext = description, stepText = text, rescueOf/dictated null; existing unlink+pop | Quiet store-failure absorption |
| Delivered, violates | tag ∉ 3–5 / empty text / count wall / absent description / shape wrong | One `slice_failed` row (cause `malformedResponse`, no item pair) + `ScanConsentFailed(malformedResponse)` → NoSlicer provider-unresponsive string + unlink; nothing dealt | Declared mapping, never an eighth cause |
| Failed dispatch | `SlicerFailed(cause)` | One `slice_failed` row (cause verbatim) + existing NoSlicer routing + unlink | Existing seven-cause surface |
| Close raced resolution | resolution after close | Existing stale arm: no landing, no row; the close's `scan_abandoned` stands | Quiet |
| Local stub delivers | rewritten canned body (scan shape) | Facts with origin `local`; parity test pins prompt field names ↔ parse ↔ stub body | N/A |
| Read boundary | stored estimate 180–300 | Survives `poolFactsOf`; 61–179 or > 300 reads absent (canonical fallback) | Quiet tolerance |
| 🔴 eligibility | synthetic maintenance fact, estimate ≤ 60 | Admitted — the estimate is read, not the size canonical | N/A |
| Rescue regression | step 1–60 s | Size instant VIA the banding, both landing sites — behavior identical | N/A |

</frozen-after-approval>

## Code Map

- `packages/core/lib/slicer/scan_steps.dart` -- NEW: the scan parse. Mirror `rescue_steps.dart` wholesale (library doc, wire-name consts with shell-side parity, bounds as the parse's own law): `scanWireDescriptionField`/`steps`/`text`/`duration_minutes`; `scanStepMinutesLeast/Most = 3/5`, `scanStepSecondsLeast/Most = 180/300`, `scanStepsLeast/Most = 1/6` (the parse's own wall bound), `scanStepTextMost = 160`, `scanDescriptionTextMost = 400`; `ScanStep = ({String text, int durationMinutes})`, `ScanSlice = ({String description, List<ScanStep> steps})`, `parseScanSlice(String body) → ScanSlice?`.
- `packages/core/lib/pool/pool_fact.dart` -- the banding's home: `sizeOfEstimateSeconds(int)` + `bandInstantMostSeconds = 60`, `bandMaintenanceMostSeconds = 599` (focus ≥ 600; the 9:00–9:59 seam reads maintenance — totality, declared). Doc states the one-rule jurisdiction incl. Focus-slot-by-class (5.9). `PoolFact` gains `stepText?`; `estimateSeconds` doc renegotiates to "non-null exactly on Slicer-authored steps (rescue 1–60, scan 180–300)".
- `packages/core/lib/ports/store_port.dart` -- `PoolFactRecord` + `poolFactsOf`: clamp widens to the union of the two contracts (import both parsers' consts); `stepText` passes through (trim-empty → null, the `rescueOf` precedent).
- `packages/core/lib/commands/scan_commands.dart` -- NEW minters + header sentences: `scanSliceLanded({origin, description, steps}) → List<ScanSliceFactSeed>` (seed = origin, size via banding, stepText, originContext = description, estimateSeconds = minutes×60); `scanSliceFailed({cause}) → [LogEntryContent]` (kind `slice_failed`, `sliceCause` only, no pair — the scan's single sanctioned failure writer).
- `packages/core/lib/log/log_entry.dart` -- `SliceEntry` (`:475-507`): `itemId`/`itemOrigin` nullable — non-null on rescue slices (the parent), null ONLY on scan `slice_failed` rows (no item exists; the scan died before any fact). Conversion (`:1072-1090`): pair-or-cause-only-on-`slice_failed`; `slice_requested`/`slice_returned` still require the pair; census stays 20. Guard every `SliceEntry` consumer that dereferences `itemId` (grep `SliceEntry` in `derive/rescue.dart`, `dispenser`, walk) to skip null-pair rows.
- `packages/core/lib/derive/eligible_day.dart` -- `_sizeNotExcludedAtStart` (`:97-122`) takes the fact's effective estimate instead of `Size`; caller `:169` passes `fact.estimateSeconds ?? estimateSecondsOf(fact.size)`.
- `packages/core/lib/commands/rescue_commands.dart` -- `rescueReturned` (`:230-293`): seeds gain `size: sizeOfEstimateSeconds(...)`; the "law, not data" comment cites the banding. `dispenser_controller.dart:680-692` consumes the seed's size, dropping its own `pool.Size.instant` hardcode.
- `lib/store/substrate.dart` + `substrate.drift` + `drift_store.dart` -- schema v10: `poolFactsStepTextUpgrade` on the v9 pattern (named const, no rebuild), `step_text` column, record mapping; regenerate `substrate.g.dart`.
- `lib/scan/scan_controller.dart` -- the landing. In `grantConsent()` after the resolution checks (`:635-643`): `SlicerDelivered(:final responseBody)` → `parseScanSlice(responseBody)`; null → `_appendScanSliceFailed(malformedResponse)` + `ScanConsentFailed(malformedResponse)`; ok → enqueue `store.appendPoolFact` per `scanSliceLanded` seed (origin `slicer is LocalSlicer ? Origin.local : Origin.cloud`), return `ScanConsentDelivered()`. `SlicerFailed(cause)` arm → `_appendScanSliceFailed(cause)` before the existing return. `_appendScanSliceFailed` mirrors `_appendScanAbandoned` (no in-closure epoch re-check). `_scanPrompt` (`:700-701`) gains the description clause: respond ONLY with `{"description": "…", "steps": [{"text": "…", "duration_minutes": 4}]}` — description = una frase que describa el espacio tal como está.
- `lib/egress/local_slicer.dart` -- canned body rewritten to the scan contract (description string + `duration_minutes` 3–5; the seconds consts become minutes). Gated `bool.fromEnvironment('ORGANIZER_LOCAL_SLICER') && kDebugMode` (`slicer_factory.dart`) — device-drivable via `--dart-define`.
- `lib/ui/scan/consent_gate_screen.dart` -- comment-only (`:211-214`): the interim discard marker becomes the landed-facts marker; routing untouched.
- Read-only: `lib/egress/*` (the seal), `weave.dart` sources/tiers (estimate-first already; `captureCandidates`' manual filter is 5.9's seam), `session.dart:27-38` (canonicals stay), `warm_return.dart:93` (slice kinds' classification unchanged — scan rows inherit the kind's rule).
- Tests to renegotiate: NEW `packages/core/test/slicer/scan_steps_test.dart` (full parse matrix incl. tolerance of unknown keys); `scan_commands_test.dart` (seed shapes, failure row, payload exclusion); `log_test.dart` (SliceEntry scan shape; census stays `hasLength(20)`); `store_port`/`poolFactsOf` suite (union clamp); `substrate_test.dart` (v10 migration, `step_text` round-trip); `eligible_day_test.dart` (synthetic estimate pin); `rescue_commands_test.dart` + dispenser tests (banding regression, byte-identical); `test/scan/scan_controller_test.dart` (landing matrix: parse ok → N expected `appendPoolFact` records + delivered; violation → row + failed; `SlicerFailed` → row with raw cause; stale unchanged); `test/ui/scan/consent_gate_screen_test.dart` (delivered pops; failure routing pins unchanged); root `test/no_lateness_proof_test.dart` (`appendPoolFact` census grows to 3 sites — capture, dispenser, scan; `scanSliceFailed(` invocation pin ×1; append/content censuses otherwise unchanged — the row rides `_appendContent`); local-slicer parity test (stub body parses via `parseScanSlice`; prompt field names match).
- Planning anchors: PRD `prd.md:96` (Origin Context one-line shape), `:285-292` (FR-16), `:164-171` (FR-5 re-slice via Origin Context); spine naming table (`ARCHITECTURE-SPINE.md:225`) — `slice_failed` is the failure vocabulary, no eighth cause; `epics.md:2033-2060` (the four ACs); `sprint-change-proposal-2026-09-05.md` §4.2 (5.7's row); `EXPERIENCE.md:309` (one card is 5.9's, per `epics.md:2119`).

## Tasks & Acceptance

**Execution:**
- [x] `packages/core/lib/slicer/scan_steps.dart` -- NEW parse + contract consts on the rescue discipline -- AC1/AC3's structural line, core-pure (AD-5)
- [x] `packages/core/lib/pool/pool_fact.dart` -- `sizeOfEstimateSeconds` banding + `stepText` field + estimate doc renegotiation -- the product's one duration→size rule
- [x] `packages/core/lib/ports/store_port.dart` -- record + clamp union + stepText pass-through -- scan estimates survive reads, corrupt ones still vanish
- [x] `lib/store/substrate.dart` + `substrate.drift` + `drift_store.dart` -- schema v10 `step_text` migration -- additive-only evolution (AD-23)
- [x] `packages/core/lib/commands/scan_commands.dart` -- `scanSliceLanded` seeds + `scanSliceFailed` minter + header sentences -- single sanctioned writers
- [x] `packages/core/lib/log/log_entry.dart` -- `SliceEntry` optional pair + conversion rules + consumer guards -- the scan's `slice_failed` converts instead of vanishing
- [x] `packages/core/lib/derive/eligible_day.dart` -- effective-estimate read -- the last size-only duration site
- [x] `packages/core/lib/commands/rescue_commands.dart` + `lib/dispenser/dispenser_controller.dart` -- both rescue landing sites route through the banding -- one rule, not three
- [x] `lib/scan/scan_controller.dart` -- delivered-arm landing + failure rows + prompt description clause -- the story's heart; epoch semantics unchanged
- [x] `lib/egress/local_slicer.dart` -- canned body to the scan contract -- the stub stops speaking rescue
- [x] `lib/ui/scan/consent_gate_screen.dart` -- comment-only marker update -- the interim-discard comment retires
- [x] Tests -- the renegotiation list in the Code Map, incl. the NEW parse matrix suite -- the I/O matrix pinned

**Acceptance Criteria:**
- Given a successful slice, when the steps are returned, then each landed fact carries an estimate of `duration_minutes × 60` with the tag an integer 3–5, and a size from the one fixed banding — the banding being the only duration→size rule in the product, with the pocket, the 🔴 filter and the session/bag ceiling reading the estimate and the size governing only same-size precedence and 1-3-5 counting (FR-16, FR-12, FR-27, AD-23).
- Given a response that parses but violates the step contract, when the outcome is recorded, then it is one `slice_failed` row under the declared `malformedResponse` mapping, surfaced by the existing provider-unresponsive string — never dealt as-is, never an eighth cause (FR-16, FR-29, AD-21).
- Given a successful slice, when the scan's data is handled, then every step fact retains the space description as its Origin Context and its own words as `stepText`, and the image is discarded by the existing unlink (FR-16, FR-25, FR-5).
- Given a failed dispatch, when it resolves, then one `slice_failed` row carries the raw cause — FR-26 series (b)'s scan outcomes are consent_granted / facts / slice_failed / scan_abandoned, none inferred from absence.
- Given the diff, when the seals are inspected, then egress/cap/token are byte-untouched, the ARB is byte-identical, the kind census stays 20, rescue deals byte-identical, and no scan fact is a weave candidate.

## Spec Change Log

## Design Notes

- **Why `stepText` is a new column and the description is the Origin Context.** PRD:96 fixes Origin Context's shape as one line of retained source text; FR-16's AC says the space description IS the retained Origin Context. The step's own words are a different payload (the task, not the source) and need their own nullable additive column — exactly how `estimate_seconds` arrived in v9. FR-5's re-slice composes `rescuePromptFor(originContext, task)` (`rescue_contract.dart:51`): a future re-slice of a scan step gets description-as-context and step-words-as-task with zero joins. `cardForItem` naming (`originContext ?? ''`) is deliberately untouched — scan facts cannot be dealt until 5.9, which owns Epic-step naming; changing it now would be untestable dead code.
- **Why scan-side `slice_failed` also fires on plain failures.** AC3 names the violation case; FR-26 series (b) wants every call's outcome, and AD-21 bans asserting absence — without a failure row, "failed" is only ever inferrable from missing facts. One minter, two call arms, no new kind; the naming table already forbids an eighth cause.
- **Why no success row.** The landed facts ARE the plan's record; `slice_returned` is the rescue flow's vocabulary (parent-referencing by shape). A scan success row would duplicate what the facts say.
- **Why the banding's seam is 599/600.** "61 s–9 min → 3 min, ≥ 10 min → 10–15 min" leaves 9:00–9:59 unmapped; totality assigns it maintenance (closer to 9 min than to 10). No producible estimate sits there (rescue ≤ 60, scan 180–300) — the seam is declared, not exercised.
- **Why landing is per-fact with no transaction.** Insert-only substrate, quiet-failure queue, steps are independent facts; a crash mid-landing leaves a shorter plan, which derives honestly. The write-queue discipline is the house pattern.
- **Partial-visibility honesty.** In 5.7 a successful scan lands facts no surface shows yet (origin `cloud`/`local` facts are not candidates). That is the partition's intent (CP §4.2): the data seams land here, the card lands in 5.9. Manual verification therefore reads the substrate, not the screen.

## Verification

**Commands:**
- `devbox run -- make gate` -- expected: green (format, analyze, all tests incl. the new parse matrix and the renegotiated censuses)
- `devbox run -- make check` -- expected: green — ARB byte-identical, egress seals untouched, string-table audit unchanged
- `devbox run -- flutter test test/scan/ packages/core/test/slicer/ packages/core/test/scan_commands_test.dart packages/core/test/log_test.dart test/store/` -- expected: exit 0

**Manual checks (device, AGENTS.md recipe):**
- Failure path: bogus-key provider → consent → wait resolves failed → NoSlicer surface with the provider-unresponsive string; pulled substrate shows `consent_granted` then one `slice_failed` (cause `invalidKey`), no pool facts, cache dir gone.
- Success path: debug build with `--dart-define=ORGANIZER_LOCAL_SLICER=true` → scan → stub delivers → Dispenser; substrate shows N new pool facts (origin `local`, size `maintenance`, estimate 180–300, `origin_context` = description, `step_text` per step), no image files remain.

## Completed Verification (2026-09-07)

**CLI (all green, devbox):**
- `make gate`: 1,004 root tests pass (1,002 + 2 added by the review patches: the landing's store-order pin and the throwing-store landing absorption), core suite 671 (669 + 2: the banding↔🔴 cross-pin and the empty-itemId conversion pin); `dart format --set-exit-if-changed` clean, `flutter analyze` clean.
- `make check`: all 16 tool checks pass — ARB byte-identical, egress seals untouched, codegen fresh; the literal-ban scan unchanged (the prompt's interpolated wire names and the stub's rescue body stay inside the per-declaration allowances).
- Focused command (`test/scan/`, `packages/core/test/slicer/`, `packages/core/test/scan_commands_test.dart`, `packages/core/test/log_test.dart`, `test/store/`): exit 0.

**Device (emulator organizer36, AGENTS.md recipe):**
- Success path, debug build with `--dart-define=ORGANIZER_LOCAL_SLICER=true`: Cámara → shoot → gate pass → `Enviar la foto` → stub scan delivered → Dispenser; pulled substrate shows 2 new pool facts (origin `local`, size `maintenance`, estimates 180/300, `origin_context` = the canned description, `step_text` per step), cache dir gone.
- Failure path not driven on device (the settings surface stalled under swiftshader before a bogus key could be installed) — pinned by the controller tests (`SlicerFailed` arm: one `slice_failed` row, cause verbatim, nothing landed) and the consent-gate UI routing tests.

## Suggested Review Order

**The landing — the story's heart**

- The delivered arm: parse after the port, the violation fold, nothing dealt.
  [`scan_controller.dart:667`](../../lib/scan/scan_controller.dart#L667)

- The fact writer: core seeds, one instant, per-fact ids, queue-serialized, quiet failure.
  [`_appendScanLanded:765`](../../lib/scan/scan_controller.dart#L765)

- The failure row: `_appendScanAbandoned`'s shape — the resolution makes it true.
  [`_appendScanSliceFailed:745`](../../lib/scan/scan_controller.dart#L745)

**The parse — core-pure, the rescue discipline**

- `parseScanSlice`: bounds re-enforced, unknown keys tolerated, one null fold.
  [`scan_steps.dart:103`](../../packages/core/lib/slicer/scan_steps.dart#L103)

- The one-fold catch: a hostile deeply-nested body cannot crash the wait.
  [`scan_steps.dart:on-Object`](../../packages/core/lib/slicer/scan_steps.dart#L103)

- The prompt: wire names interpolated from core — no copy can drift.
  [`_scanPrompt:807`](../../lib/scan/scan_controller.dart#L807)

**The one duration→size rule**

- The banding: ≤ 60 → instant, ≤ 599 → maintenance, ≥ 600 → focus; jurisdiction documented.
  [`sizeOfEstimateSeconds:72`](../../packages/core/lib/pool/pool_fact.dart#L72)

- Rescue routes through it at both landing sites — one rule, not three.
  [`rescue_commands.dart:254`](../../packages/core/lib/commands/rescue_commands.dart#L254)

- The last size-only site reads the effective estimate.
  [`rescue.dart:69`](../../packages/core/lib/derive/rescue.dart#L69)

**The read boundary — corrupt data stays honest**

- The union clamp: rescue 1–60 ∪ scan 180–300, else absent.
  [`_inSlicerBand:145`](../../packages/core/lib/ports/store_port.dart#L145)

- The pairless scan `slice_failed` converts; empty counts as absent.
  [`carriesItem:1067`](../../packages/core/lib/log/log_entry.dart#L1067)

**Substrate & stub**

- Schema v10: `step_text`, ALTER-only, the v9 pattern.
  [`substrate.dart:126`](../../lib/store/substrate.dart#L126)

- The rowid tiebreak IS the landing-order contract 5.9 consumes.
  [`drift_store.dart:77`](../../lib/store/drift_store.dart#L77)

- The stub speaks both contracts — scan and rescue flights both drivable.
  [`local_slicer.dart:60`](../../lib/egress/local_slicer.dart#L60)

**The pins**

- The landing matrix: facts, estimates, nothing dealt, no extra rows.
  [`scan_controller_test.dart:800`](../../test/scan/scan_controller_test.dart#L800)

- Store order IS step order — the 5.9 "first step" seam.
  [`order pin:882`](../../test/scan/scan_controller_test.dart#L882)

- A throwing `appendPoolFact` mid-landing: delivered still resolves, quietly.
  [`_ThrowingFactStore:92`](../../test/scan/scan_controller_test.dart#L92)

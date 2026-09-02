---
title: 'The model-evaluation harness and provider selection'
type: 'feature'
created: '2026-09-02'
status: 'done'
review_loop_iteration: 0
baseline_commit: '5cddd40c143787d453882e8fba577ee7e6254039'
context:
  - '{project-root}/_bmad-output/implementation-artifacts/epic-4-context.md'
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** Epic 4 wires BYOK, egress and Rescue Mode against a provider, prompt and structured-output schema that do not exist yet — provider choice must rest on evidence (structured-output reliability on real photos), and PRD OQ-1's quality half is still open.

**Approach:** One harness as a standalone Dart package `eval/` at the repo root (outside `lib/` and `tool/` — a second HTTP opener as app code would breach AD-7/AD-12's closed egress map), run manually on the development machine: identical corpus, prompt, schema and pre-confirmed written pass bar for all five candidates, cascade running order, recorded outputs, and OQ-1's answer reported as PRD/spine updates.

## Boundaries & Constraints

**Always:**
- Harness lives in `eval/` as its own pub package (`packages/core` pattern: own `pubspec.yaml` + `analysis_options.yaml`, `dart pub get` added to `make deps`) so the gate stays green: `dart format .` sweeps it, `flutter analyze` gives it its own context, `flutter test` never touches it.
- Five candidates — `e2b_local`, `e4b_local` (Lemonade's OpenAI-compatible endpoint), `gemini`, `openai`, `anthropic` — all receive byte-identical corpus, prompt (`eval/prompt.md`), schema (`eval/schema.json`) and bar (`eval/PASS-BAR.md`).
- The bar is written and builder-confirmed (dated marker in the file) before the first scored run; `eval-run` refuses to score without it. Bar content: the five per-photo limbs, the 8-of-10 threshold, the cascade, kill/provisional rules.
- Exactly ONE request per photo — no retry, no repair, transport error included. Per-photo pass requires all five limbs: parses against the schema on the first attempt; every duration tag within 3–5 minutes; ≥4 steps; every step a real action on objects the photo contains; workable order (nothing put away before its surface is cleared).
- Scored corpus is exactly 10 photos spanning ≥4 space types. Cascade: E2B first; only its failure runs E4B; only both local failures run the three cloud candidates (all three, scored; best ≥8/10 proposed). Desktop fail kills a candidate outright; a local desktop pass is provisional (handset re-verify deferred to Epic 5, AD-9).
- Local image input is confirmed by `eval-probe` before any local candidate runs.
- Keys only via env vars (`EVAL_GEMINI_API_KEY`, `EVAL_OPENAI_API_KEY`, `EVAL_ANTHROPIC_API_KEY`); Lemonade URL and model ids via flags with defaults. Photos (`eval/corpus/photos/`) and raw responses (`eval/results/raw/`) are gitignored — never committed.
- OQ-1's answer lands as a PRD §9 update + Changelog entry plus spine updates (Stack table E2B Android size read off the model card; Deferred OQ-1 bullet) — never absorbed silently.

**Ask First:**
- Builder confirmation of prompt + schema + bar before the first scored run.
- Builder supplies the corpus: 10 photos, ≥4 space types, plus per-photo ground-truth object lists (manifest committed, photos gitignored).
- Scoring cloud candidates when a local candidate already passed (default: not run).
- Re-running a whole candidate after an infrastructure-voided run (fresh run, superseding, noted in the report).

**Never:**
- No app-code changes: `lib/`, `tool/`, `android/`, `packages/core/`, app `pubspec.yaml` untouched; no egress-check creation (Story 4.2's); no `devbox.json` changes (Lemonade is a machine-local app, not devbox state).
- No photo, key or raw HTTP response ever committed; no per-photo retry or repair; no handset runs — storage, peak memory, latency, thermals stay deferred.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Probe, image-capable endpoint | Lemonade up | One photo answered in-schema; local route open | Non-zero exit + reason if not |
| Probe, text-only endpoint | Image rejected | Desktop local route invalid — HALT to builder; nothing else planned around it | Exit 2 |
| Run without confirmed bar | Missing dated marker | Refuses to score | Exit 2 |
| Invalid manifest | ≠10 photos, <4 types, missing file | Refuses, listing every failure | Exit 2 |
| First-attempt parse failure | Malformed/wrapped JSON | Photo failed with reason recorded; corpus continues | Recorded, no retry |
| Transport error on a photo | Network/API error | Photo failed with reason recorded | Recorded, no retry |
| Candidate totals <8/10 | Score tallied | Killed outright (local) / recorded fail (cloud) | N/A |
| E2B totals ≥8/10 | Cascade decision | E2B selected provisionally; E4B and cloud not run | N/A |

</frozen-after-approval>

## Code Map

- `eval/pubspec.yaml` + `eval/analysis_options.yaml` -- NEW dart-only package (deps: `http`, `args`; dev: `lints`, `test`); `packages/core/pubspec.yaml` is the template.
- `eval/bin/harness.dart` -- subcommands: `probe`, `run --candidate <id>`, `judge`, `report`.
- `eval/lib/candidates.dart` -- five adapters mapping canonical prompt+schema+photo to each provider's native request/response (OpenAI-compatible chat completions with base64 image parts for the local pair; OpenAI structured outputs; Gemini `generateContent` + `responseSchema`; Anthropic messages with a tool-borne schema) — one request each.
- `eval/lib/verdict.dart` -- machine limbs (strict first-attempt parse vs schema, 3–5 duration tags, ≥4 steps), score tally, cascade proposal, manifest + bar validation.
- `eval/prompt.md` / `eval/schema.json` / `eval/PASS-BAR.md` -- the three shared immutable inputs; minimal schema: `steps[]` of `{text, duration_minutes}`.
- `eval/corpus/manifest.json` -- committed metadata: id, filename, space type, ground-truth objects; photos gitignored.
- `eval/results/` -- committed `report.md`, `scores.json`, `costs.json`, `runs/`, `verdicts/`; gitignored `raw/`.
- `Makefile` -- `eval-probe`, `eval-run CANDIDATE=`, `eval-judge`, `eval-report` (`. ./tool/env.sh` + `cd eval && dart run bin/harness.dart …`); `deps` += eval pub get; `check` += `cd eval && dart test` (pure-logic tests only).
- `.gitignore` -- += `eval/corpus/photos/`, `eval/results/raw/`.
- `eval/test/` -- pure-Dart unit tests of the I/O matrix's machine-checkable rows (parse/transport failures, tally at 7 vs 8, cascade order, manifest/bar validation) — no network.
- `_bmad-output/planning-artifacts/prds/prd-organizer-2026-08-20/prd.md` -- §9 OQ-1 at L579 (open; the 2026-08-27 bolded partial-close paragraph inside is the formatting precedent) + Changelog at end (dated-entry convention, e.g. L667).
- `_bmad-output/planning-artifacts/architecture/architecture-organizer-2026-08-26/ARCHITECTURE-SPINE.md` -- Stack table Gemma rows L268–269 (E2B Android size "not yet recorded"), Deferred OQ-1 bullet L378; AD-7 L86–90, AD-9 L98–102, AD-12 L116–120 are the rules the out-of-app placement respects.
- Gate facts -- root `analysis_options.yaml` excludes only `build/**`+`android/**`, so `eval/` needs its own package context (precedent: `packages/core/`); `dart format .` sweeps `eval/` unconditionally; `flutter test` runs only `test/**`.

## Tasks & Acceptance

**Execution:**
- [x] `eval/` skeleton + `Makefile` + `.gitignore` -- package files, harness arg wiring, four targets, ignores, `deps`/`check` wiring -- gate and check stay green with `eval/` present.
- [x] `eval/prompt.md` + `eval/schema.json` + `eval/PASS-BAR.md` -- Spanish photo→plan prompt, minimal schema, bar verbatim from the five limbs + 8/10 + cascade + kill/provisional rules -- builder confirms all three (dated marker) before any scored run.
- [x] `eval/lib/candidates.dart` + `eval/lib/verdict.dart` + `eval/bin/harness.dart` + `eval/test/` -- adapters (single request per photo), machine verdicts, four commands with bar/manifest enforcement -- unit tests green.
- [x] `eval/corpus/` -- builder supplies 10 photos over ≥4 space types into gitignored `photos/` with ground truth in committed `manifest.json`; validation enforces it.
- [x] Run the cascade -- `eval-probe` gates the local route; then E2B → (fail) E4B → (both fail) cloud trio; builder judges the two human limbs per photo via `eval-judge`; `eval-report` writes committed `report.md` + `scores.json` with the selection proposal and OQ-1 answer draft. (Executed 2026-09-02: E2B 3/10 killed, E4B 2/10 killed, cloud via the OpenRouter route — gemini 9/10, openai 9/10, anthropic 6/10; gemini proposed on the cascade tie-break; builder judged all limbs; report + scores.json + costs.json written.)
- [x] PRD + spine updates -- OQ-1 §9 entry + Changelog bullet per repo convention (strike+close if quality is settled, else a further dated bolded paragraph); spine Stack table E2B Android size, Deferred OQ-1 bullet, AD-9 binds tag if OQ-1 closes. (Done 2026-09-02: OQ-1 struck and closed with a dated final ruling; PRD Changelog entry added; spine Gemma rows record the kills, Deferred bullet records the closure, AD-9's rule carries the binding selection — gemini via direct API, OpenRouter a candidate fourth entry pending the FR-28 terms gate.)

**Acceptance Criteria:**
- Given the harness location, when checked, then every file lives under `eval/`, nothing in `lib/`, `tool/` or the app pubspec references it, and the only HTTP-client import in the repo is inside `eval/`.
- Given the first scored run, when it starts, then `PASS-BAR.md` already carries the builder's dated confirmation and the run would have refused without it.
- Given any candidate, when it runs, then corpus, prompt and schema are byte-identical to every other candidate's, exactly one request per photo is sent, and per-photo limb verdicts with failure reasons are recorded.
- Given E2B at ≥8/10, when the cascade decides, then E2B is selected provisionally and E4B and the cloud candidates are not run; given both locals below 8/10, then all three cloud candidates run and the best ≥8/10 is proposed.
- Given the harness completed, when outputs are checked, then `eval/results/report.md` + `scores.json` record the selected provider, the prompt, the schema, the per-candidate scores and the OQ-1 answer, and `prd.md` + the spine carry that answer as dated updates.
- Given the repo, when `make gate` and `make check` run, then both are green.

## Spec Change Log

- **2026-09-02 — review-pass hardening (step-04 patches).** The adversarial review's patch-class findings, applied and tested: (1) the prompt sent to every candidate is now the text below `prompt.md`'s `---` marker, never the file's documentation header — the recorded 2026-09-02 runs sent the whole file uniformly to all five candidates (comparison validity intact; the discrepancy is recorded here, and the report notes the sent form); (2) re-running an already-scored candidate is now an Ask-First refusal without `--force`; (3) `eval-report` refuses on a no-longer-valid manifest or missing prompt/schema instead of crashing, renders each run's `via` (the OpenRouter route is now visible in the evidence file), and refuses on cross-candidate prompt/schema digest mismatch — digests are recorded per run from this amendment on, with the pre-amendment 2026-09-02 runs noted as digest-less rather than refused; (4) `_evidenceCostOf` tolerates transport-failed raw records (no `responseBody`); (5) `postJson` wraps `Error` as well as `Exception`, `defaultTransport` carries a 5-minute timeout, malformed base URLs fail as transport errors, the local pair refuses `--via openrouter` with exit 2, the probe's failure message names the actual failed limbs (never `null`), a stripped fence's payload error (not the outer text's) is the recorded reason, report tables sort photo ids naturally and use a real markdown line break; (6) the manifest validator refuses ids/filenames with path separators or duplicate filenames. New tests: judge end-to-end (auto-record + prompts + score), report over transport-failed raws, re-run refusal, below-marker prompt assertion, local-pair route refusal, manifest duplicate/path cases, `promptTextOf`/`comparePhotoIds` units.
- **2026-09-02 — tie-break recorded as a bar amendment.** The scored cascade ended gemini/openai tied at 9/10 and the winner was decided by cascade order — a rule the original bar never wrote. `eval/PASS-BAR.md` → Amendments now records it (builder confirmed in session): ties between bar-passing cloud candidates break in cascade order (gemini → openai → anthropic).
- **2026-09-02 — OpenRouter added as a serving route for the cloud trio.** Builder direction after both locals were killed (E2B 3/10, E4B 2/10): the cascade's cloud candidates run via OpenRouter for now, so one key serves all three. Added `--via native|openrouter` to `eval-run` (default `native` keeps the per-provider adapters and their `EVAL_GEMINI_API_KEY`/`EVAL_OPENAI_API_KEY`/`EVAL_ANTHROPIC_API_KEY` untouched as an option); the `openrouter` route is OpenAI-compatible chat completions at `https://openrouter.ai/api/v1` with a strict `json_schema`, one shared `EVAL_OPENROUTER_API_KEY`, and per-candidate slugs chosen by the builder: `google/gemini-3.5-flash-lite`, `openai/gpt-5.6-luna`, `anthropic/claude-haiku-4.5`. The route is recorded in `results/runs/<id>.json` (`via`) and printed by the run. Harness: `eval/lib/candidates.dart` (spec slugs + `ChatCompletionsCandidate.openRouter` + `buildCandidate(via:)`), `eval/bin/harness.dart` (`--via`, shared-key resolution, run meta), `Makefile` (`VIA=`); tests in `eval/test/candidates_test.dart` + `eval/test/harness_cli_test.dart`.

- **2026-09-02 — bar amendment: single markdown fence tolerated, recorded.** After `eval-probe` failed on a fenced response (image input confirmed working; Lemonade accepts `response_format` but silently ignores it — not in its documented parameter surface — and the confirmed prompt's explicit no-code-blocks rule does not stop the local models from fencing), the builder renegotiated the parse limb before any scored run: exactly one markdown fence around the JSON is stripped once and recorded per photo (`fenceStripped`), counted per candidate in `report.md` + `scores.json`. Rationale (builder): Lemonade is an eventual test tool, not the product surface; handset verification of the same behavior stays deferred to Epic 5 (AD-9). Unchanged: prose around JSON, repeated fences, unclosed fences, invalid JSON inside the fence, one-request-per-photo, no retry. Recorded in `eval/PASS-BAR.md` → Amendments + updated confirmation line. Harness: `eval/lib/verdict.dart` (amended limb + flag), `eval/bin/harness.dart` (fence counts in report/scores); tests updated in `eval/test/verdict_test.dart` + `eval/test/harness_cli_test.dart`.
- **2026-09-02 — corpus supplied by the builder.** 10 photos (10 distinct space types) in gitignored `eval/corpus/photos/` with ground truth transcribed into the committed `eval/corpus/manifest.json` from the builder's `descripciones.txt`.
- **2026-09-02 — run cost recorded per candidate.** Builder direction: the price of each cloud model over the 10-photo run must be on record. Committed `eval/results/costs.json` carries the builder-supplied OpenRouter-dashboard totals (gemini $0.00757, openai $0.00931, anthropic $0.0278); `eval-report` additionally sums `usage.cost_details.upstream_inference_cost` from the recorded raw responses and renders both columns in `report.md` plus `costBuilderUsd`/`costEvidenceUsd` in `scores.json` — the third-decimal disagreement on openai (0.00931 vs 0.00941) and anthropic (0.0278 vs 0.02807) stays visible as dashboard rounding.
- **2026-09-02 — report rationale leak fixed.** `cascadeProposal`'s rationale interpolated the `_scoresOf` function reference instead of calling it (`$_scoresOf(...)` vs `${_scoresOf(...)}`), leaking a Dart `Closure:` string into `report.md`; fixed in `eval/lib/verdict.dart` (both call sites), report regenerated.

## Design Notes

- Minimal schema, separate limbs: `schema.json` does not encode `minItems` or 3–5 bounds — the verifier checks those as distinct limbs so a failure records which limb broke, and the schema stays exactly what the app will enforce at runtime.
- The adapter maps the canonical schema onto each provider's native structured-output mechanism (OpenAI `json_schema`, Gemini `responseSchema`, Anthropic tool schema, OpenAI-compatible `response_format` where Lemonade supports it, else prompt-borne) — mechanism mapping is part of what reliability means, so it is code per candidate, not configuration.
- A transport error is a failed photo, same as a parse failure — one attempt is the bar. A run voided by infrastructure may only be re-run whole, superseding the earlier run and noted in the report.
- `eval-judge` shows photo path + ground truth + returned steps and records only the two human limbs (real actions, workable order); machine limbs never prompt.
- Exactly-10 scored corpus keeps the 8-of-10 bar exact rather than proportional.

## Verification

**Commands:**
- `devbox run -- make gate` -- expected: green (format sweeps `eval/`; analyze resolves it in its own context; flutter test untouched).
- `devbox run -- make check` -- expected: green, including the new eval unit tests.
- `devbox run -- make eval-run CANDIDATE=e2b_local` (builder machine, Lemonade up) -- expected: 10 per-photo verdict records + raw responses under `eval/results/`.

**Manual checks (if no CLI):**
- The run is builder-in-the-loop by design: bar/prompt/schema confirmation, corpus supply and human-limb judging are manual gates; `report.md`'s selection and OQ-1 paragraph are reviewed by the builder before the PRD/spine edit lands.

## Suggested Review Order

**The measurement and its record**

- The evidence file the whole story produced: scores, cascade, costs, OQ-1 draft — start here.
  [`report.md:1`](../../eval/results/report.md#L1)

- The two dated bar amendments the run relied on: single-fence tolerance and the recorded tie-break.
  [`PASS-BAR.md:56`](../../eval/PASS-BAR.md#L56)

- The builder-supplied corpus ground truth the human limbs were judged against.
  [`manifest.json:1`](../../eval/corpus/manifest.json#L1)

**The verdict engine**

- The amended parse limb: one fence, stripped once, recorded — plus the machine limbs.
  [`verdict.dart:183`](../../eval/lib/verdict.dart#L183)

- The fence matcher itself — anchored, exactly one fence, nothing more.
  [`verdict.dart:176`](../../eval/lib/verdict.dart#L176)

- Manifest validation hardened: bare unique names, no path separators, no shared files.
  [`verdict.dart:670`](../../eval/lib/verdict.dart#L670)

- Prompt extraction (below the `---` marker) and natural photo-id order.
  [`verdict.dart:761`](../../eval/lib/verdict.dart#L761)

**The serving routes**

- Five candidates, two routes: Lemonade locals plus native adapters and the OpenRouter slugs.
  [`candidates.dart:103`](../../eval/lib/candidates.dart#L103)

- The OpenRoute adapter — one shared key, strict `json_schema`, candidate's own id and slug.
  [`candidates.dart:309`](../../eval/lib/candidates.dart#L309)

**The CLI gates**

- Run guards: cascade Ask-Firsts, the re-run refusal, route/key resolution.
  [`harness.dart:265`](../../eval/bin/harness.dart#L265)

- The judge: prompts only the two human limbs; machine failures auto-record.
  [`harness.dart:572`](../../eval/bin/harness.dart#L572)

- The report: manifest/digest refusals, route visibility, cost evidence.
  [`harness.dart:729`](../../eval/bin/harness.dart#L729)

- Cost loading: builder dashboard figures plus the raw-response evidence sum.
  [`harness.dart:483`](../../eval/bin/harness.dart#L483)

**Downstream decisions**

- OQ-1 struck and closed: scores, ruling, OpenRouter admitted as fourth candidate.
  [`prd.md:579`](../../_bmad-output/planning-artifacts/prds/prd-organizer-2026-08-20/prd.md#L579)

- AD-9 now binds: reference provider gemini, direct API, model class pinned.
  [`ARCHITECTURE-SPINE.md:102`](../../_bmad-output/planning-artifacts/architecture/architecture-organizer-2026-08-26/ARCHITECTURE-SPINE.md#L102)

- The Gemma rows record the kills instead of chasing a dead size question.
  [`ARCHITECTURE-SPINE.md:268`](../../_bmad-output/planning-artifacts/architecture/architecture-organizer-2026-08-26/ARCHITECTURE-SPINE.md#L268)

**Peripherals**

- Four eval targets plus `VIA=` wiring; `deps`/`check` integration.
  [`Makefile:76`](../../Makefile#L76)

- 94 pure-Dart tests: adapters, limbs, CLI end-to-end including judge and cost.
  [`harness_cli_test.dart:1`](../../eval/test/harness_cli_test.dart#L1)

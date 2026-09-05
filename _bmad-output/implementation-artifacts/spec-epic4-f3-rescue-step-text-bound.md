---
title: 'Epic 4 F3: bound rescue step text in parseRescueSteps'
type: 'bugfix'
created: '2026-09-05'
status: 'done'
baseline_commit: '8ba5ee21e455a89a2fc0d0fa884b468549be4192'
review_loop_iteration: 0
context:
  - '{project-root}/_bmad-output/implementation-artifacts/epic-4-retro-2026-09-05.md'
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** `parseRescueSteps` enforces non-empty step text but no upper bound; provider text is stored verbatim as `originContext` and rendered as the card name (`task_card.dart:162`, no `maxLines`), so a verbose provider answer becomes a wall of text on the one-card surface and rides the log/export forever.

**Approach:** Add a named upper bound `rescueStepTextMost` beside the sibling constants; after trim, step text longer than the bound rejects the whole body as malformed (`null`), exactly as the near-miss folds today — rejection, never truncation, so verbatim-ness is preserved. Proposed value **120 chars** (corpus-informed: eval photo-plans, unconstrained, run 30–167 with ≥120 at 11/209; the rescue prompt pulls shorter); **160** is the looser alternative if false rejects matter more than walls of text.

## Boundaries & Constraints

**Always:** bound measured on the trimmed text via Dart `.length` (UTF-16 code units), checked after the existing empty-check; constant named in the library's own convention (`rescueStepsLeast`/`rescueStepSecondsMost` style) and cited in the library doc comment; run both `make test-core` and `make gate` inside devbox (the gate does not run the core suite).

**Ask First:** changing the bound's numeric value after approval; any edit outside `packages/core/lib/slicer/rescue_steps.dart` and `packages/core/test/slicer/rescue_steps_test.dart`.

**Never:** no truncation or repair of provider text (verbatim-or-reject); no wire-contract, schema or tool-string changes (`rescue_contract.dart`, `byok_wire.dart` — the F7 drift zone); no UI changes (`task_card.dart` stays); no new user-facing strings — the rejection lands on the existing calm-degradation path.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|---------------|----------------------------|----------------|
| At-bound step | step text trims to exactly the bound | parse succeeds; trimmed text stored | N/A |
| One over the bound | any step's trimmed text exceeds the bound | whole body rejects `null` → `malformedResponse` → existing calm surface, deal degrades skip-only | existing path |
| One bad step spoils | one over-long step among otherwise valid ones | whole body `null` (same fold as empty-text today) | existing path |
| Unicode text | Spanish accents, emoji | `.length` counts UTF-16 units; char-count bound, not bytes — deterministic | N/A |
| Regression noise | Local stub text (17 chars), all existing suites | unaffected; constants test gains the new literal | N/A |

</frozen-after-approval>

## Code Map

- `packages/core/lib/slicer/rescue_steps.dart` -- the parse: `:66-110`; step-count consts `:27-31`, seconds consts `:34-38`, wire consts `:42-48`; non-empty check `:88-95` (trim applied and stored `:92, :107`); every failure clause answers `null` — one cause, `malformedResponse` (`:59-61`); library doc already names the parse as where bounds hold (`:16-19`). New const + check slot beside `:93-95`.
- `packages/core/lib/commands/rescue_commands.dart` -- read-only: cites the contract in doc `:169`; step text → `originContext` `:250, :269`.
- `lib/dispenser/dispenser_controller.dart` -- read-only: sole production caller `:616`; `null` → `_appendRescueFailure(malformedResponse)` `:618-623`, one `slice_failed` row, no facts; outcome → calm surface via `noSlicerCauseFromFailure` (`packages/core/lib/ports/no_slicer_cause.dart:74-81`, `unreachable` → `noSlicerUnreachable` string).
- `packages/core/test/slicer/rescue_steps_test.dart` -- helpers `body()`/`step()` `:8-13`; constants test `:17-22` (gains the literal); empty/whitespace rejects `:134-151`; duration boundary pattern to mirror (at-bound + one-over, with `reason:`) `:173-186`; one-bad-step-spoils `:189-203`.
- `test/egress/byok_slicer_test.dart` -- shell parity pin `:926-1046` (derived field names, edge folds) — must stay green untouched; Local stub text 17 chars `:943, :952`.
- `packages/core/test/no_lateness_proof_test.dart` -- `RescueStep` record-shape pins `:1039, :1133` — unaffected (const + check only).

## Tasks & Acceptance

**Execution:**

- [x] `packages/core/lib/slicer/rescue_steps.dart` -- add `rescueStepTextMost` const (= 120, ratified at approval) beside the siblings; after the trim/empty check, over-long trimmed text returns `null` (whole body rejects); cite the bound in the library doc comment.
- [x] `packages/core/test/slicer/rescue_steps_test.dart` -- constants test gains the literal; at-bound passes + one-over rejects (mirror the duration boundary pattern with `reason:`); one over-long step among valid ones spoils the body.

**Acceptance Criteria:**

- Given a body whose every step text trims to at most the bound, when parsed, then it succeeds and stores the trimmed text.
- Given a body with any step text one char over the bound, when parsed, then the whole body rejects as malformed — the same fold, cause and calm surface as empty-text today.
- Given both suites at HEAD plus the new tests, when `make test-core` and `make gate` run inside devbox, then everything is green.

## Spec Change Log

## Design Notes

Rejection, not truncation: the taxonomy's honesty rests on verbatim provider text (AD-23 note at `:59-65`); a wall of text is better refused than silently edited — and the refusal is an established, calm, fully-built path (`malformedResponse` → `noSlicerUnreachable` → skip-only for the rest of the deal), so this fix needs zero new user-facing surface. The bound holds at the parse, not the wire: the wire contract's schema is bare `"type":"string"` and the Gemini dialect drops bounds anyway (`byok_wire.dart:535-536`) — touching it would enter the F7 duplication drift zone. The eval corpus is a different contract (3–5 min photo plans, no text instruction) used only as the tail-length evidence for the value.

## Verification

**Commands:**

- `devbox run -- make test-core` -- expected: core suite green including the new boundary tests
- `devbox run -- make gate` -- expected: full app suite, checks, format and analyze green (parity pin untouched)

**Results (2026-09-05):** `make test-core` 606/606; `make gate` green — 833 tests, format 0 changed, analyze clean. Re-verified after review patches.

## Suggested Review Order

**The bound**

- The named constant — measure, least-pair convention, per-step rationale, verbatim-or-reject citation.
  [`rescue_steps.dart:55`](../../packages/core/lib/slicer/rescue_steps.dart#L55)

- The check itself: after trim, over-long rejects the whole body — one fold with every near-miss.
  [`rescue_steps.dart:114`](../../packages/core/lib/slicer/rescue_steps.dart#L114)

**The pins**

- Boundary arithmetic: at-bound passes, one-over rejects, surrogate pairs, trim-inverse with Spanish accents.
  [`rescue_steps_test.dart:155`](../../packages/core/test/slicer/rescue_steps_test.dart#L155)

- One over-long step among valid ones spoils the body.
  [`rescue_steps_test.dart:245`](../../packages/core/test/slicer/rescue_steps_test.dart#L245)

**Peripherals**

- The citing command's doc now names the ceiling too (comment-only).
  [`rescue_commands.dart:169`](../../packages/core/lib/commands/rescue_commands.dart#L169)

- Three deferrals from review: wire/prompt-side bound communication (F7 zone), field observability + revisit criterion.
  [`deferred-work.md`](deferred-work.md)
- Results (2026-09-05): `make test-core` 606/606; `make gate` green -- 833 tests, format 0 changed, analyze clean.

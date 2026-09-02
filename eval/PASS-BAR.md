# Pass bar — model evaluation (story 4.1)

Written and confirmed before the first scored run. One bar, byte-identical, for
all five candidates (`e2b_local`, `e4b_local`, `gemini`, `openai`,
`anthropic`): same corpus (`eval/corpus/`), same prompt (`eval/prompt.md`),
same schema (`eval/schema.json`). `eval-run` refuses to score while this file
carries no dated confirmation in its Builder confirmation section.

## Per-photo pass — all five limbs required

1. **Parse, first attempt only.** The response parses against
   `eval/schema.json` on the first attempt — no retry, no repair, no
   fence-stripping. Exactly one request per photo; a transport error (network
   error, HTTP non-200, API error) fails the photo exactly like a parse
   failure.
2. **Durations.** Every step's `duration_minutes` is an integer within 3–5.
3. **Step count.** At least 4 steps.
4. **Real actions.** Every step is a real action on objects the photo
   contains — no invented objects. Judged by the builder against the
   manifest's ground-truth object list (`eval-judge`; the machine limbs never
   prompt).
5. **Workable order.** Nothing is put away before its surface is cleared.
   Judged by the builder (`eval-judge`).

## Candidate pass — 8 of 10

- The scored corpus is exactly 10 photos spanning at least 4 space types.
- A candidate passes at **≥ 8 of 10 photos** (each photo needs all five
  limbs).
- Below 8/10: a local candidate is killed outright; a cloud candidate records
  the fail.

## Cascade — running order

- `e2b_local` runs first. Only its failure runs `e4b_local`. Only both local
  failures run the three cloud candidates — all three, scored.
- The best cloud candidate at ≥ 8/10 is proposed if the locals failed.
- Scoring cloud candidates while a local already passed is an Ask-First: not
  run by default (`eval-run` refuses without `--force`).

## Kill / provisional rules

- A local candidate's desktop failure kills it outright — the Android
  artifact is more aggressively quantized, so the phone build cannot do
  better.
- A local candidate's desktop pass is **provisional**: handset re-verification
  is deferred to Epic 5 (AD-9).
- Storage, peak memory, inference latency and thermals stay deferred (handset
  questions).
- A run voided by infrastructure may only be re-run whole — a fresh run
  superseding the earlier one, noted in the report.

## Builder confirmation (Ask-First — required before the first scored run)

Replace the placeholder below with a real dated line; the harness looks for
`Confirmed: YYYY-MM-DD` and refuses to score without it.

Confirmed: 2026-09-02 — the builder (prompt, schema and bar approved in session)

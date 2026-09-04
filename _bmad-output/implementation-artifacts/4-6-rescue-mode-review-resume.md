# Resume: code review of 4-6 Rescue Mode

Paused 2026-09-04. Resume **exactly** here — do not re-run group 1 or re-litigate the group 2 product call.

## How to pick this up

1. Open this file, then `_bmad-output/implementation-artifacts/4-6-rescue-mode.md` → **Review Findings**.
2. Invoke `/bmad-code-review @_bmad-output/implementation-artifacts/4-6-rescue-mode.md` (or continue in this conversation).
3. **Do not** start from step 1 of the skill as a blank slate. The review is chunked; group 1 is done; group 2 is reviewed and decided; patches for group 2 are **not** applied.
4. First question to the user (already asked, unanswered because we stopped):

> How would you like to handle the 4 group-2 `patch` findings?
> 1. Apply every patch
> 2. Leave as action items
> 3. Walk through each patch

If they say **1**, implement the four patches below, check them off in the story, run `flutter test` + `dart format --set-exit-if-changed .` + `flutter analyze` inside `devbox` / `. ./tool/env.sh`, then start **group 3**.

## Workflow coordinates

| | |
|---|---|
| Skill | `bmad-code-review` (step 4 — Present and Act) |
| Spec | `_bmad-output/implementation-artifacts/4-6-rescue-mode.md` |
| Context | `_bmad-output/implementation-artifacts/epic-4-context.md` |
| `review_mode` | `full` |
| Baseline | `37acb1c` (`feat: story 4-5 — honest degradation…`) |
| HEAD (committed) | `a008382` (`fix: pin RescueStepSeed in the NFR9 freeze census`) |
| Branch | `dorogoy/4-6-rescue-mode` |
| Communication | Spanish |
| Story status | `done` (do **not** flip to done for the whole review until groups 2–5 finish) |
| Sprint sync | skipped — `story_key` was never set from `sprint-status.yaml` |

Layers (all four ran on groups 1 and 2): Blind Hunter, Edge Case Hunter, Verification Gap, Acceptance Auditor.

## Chunking (agreed)

Diff vs `37acb1c` is ~9906 lines / 58 files. Review is **by group**:

| # | Group | Files | Status |
|---|---|---|---|
| 1 | Core | log, pool, rescue commands, eligible_day, derive/rescue, rescue_steps, command `sliceCause: null` plumbing | **Done** — 4 patches applied, gate green |
| 2 | Weave / session | `weave.dart`, `session.dart`, `warm_return.dart` | **Reviewed + decided. 4 patches pending apply** |
| 3 | Store | `substrate.dart/.drift/.g.dart`, `drift_store.dart`, `store_port.dart` | Not started |
| 4 | Shell | dispenser controller/screen, `main.dart`, small controller +1s, `tool/check_no_literal_strings.dart` | Not started |
| 5 | Tests + artifacts | `packages/core/test`, `test/`, `_bmad-output` | Not started |

For each remaining group: `git diff 37acb1c -- <paths>` → four layers → triage → present → act. Do not complain that other groups are missing from that chunk.

## Group 1 — applied (uncommitted)

Working tree (this session):

- `packages/core/lib/derive/rescue.dart`
- `packages/core/lib/log/log_entry.dart`
- `packages/core/test/derive/rescue_test.dart`
- `packages/core/test/log_test.dart`
- `_bmad-output/implementation-artifacts/4-6-rescue-mode.md`

**What landed:**

1. Refusal counter no longer rebinds EligibleDay genesis to `slice_requested`. Genesis stays fact creation / catalogue unbounded. Activation filters `card_skipped` rows at-or-before the last `slice_requested` **by append order**. Same-sitting skip after failure counts; pre-activation same-day skip does not leak.
2. `slicerFailureCauseByName` is `final` and derived from `SlicerFailureCause.values` (`const` + collection-for is not a constant expression in this Dart).
3. Slice extra-payload exclusion tests (stack/setting/pocket/energy/report/permission) on `slice_requested` and `slice_failed`.
4. Catalogue-anchor energy test (`zona-z1-a` + 🔴 sitting) plus same-sitting / leak / append-order tests.

Gate after group 1: `flutter test`, `dart format --set-exit-if-changed .`, `flutter analyze` — all green. Also `packages/core` `dart test` green.

**Do not re-open** the group 1 counter design. Spec I/O row “Second tap after failure” is implemented as skip-filter, not as a second EligibleDay genesis.

## Group 2 — halt point

Acceptance Auditor: **zero AC violations** in weave/session (head-only, precedence, verbatim estimate, retirement, slot close, Warm Return, done-by-derivation, dissolution has no slot effects).

### Product call (already made — do not re-ask)

Rescue heads are `Size.instant`, so they also filled `instantHabits[0]`. A pocket miss of the live head re-offered the **same** card and warm-closed; `composeDay` listed the head as a habit.

Sergio chose **option 2 — fall through**:

- Exclude `CandidatePrecedence.rescue` from size-based `_draw` (instant **and** maintenance).
- Rescue stays its own tier in `_guardedTierDealOf`.
- If `allows(rescueHeads[0])` is false, fall through to chunk / upkeep / habits that fit.
- `composeDay` must not list the head as a habit.
- FIFO still deals only `rescueHeads[0]` first when it **does** fit; do **not** try later heads (leapfrog dismissed).

Converted from `[Review][Decision]` to `[Review][Patch]` in the story. Unchecked.

### Four patches to apply (all unchecked)

**P2.1** `packages/core/lib/weave/weave.dart` ~653 — exclude rescue from `_draw`:

```dart
instantHabits: _draw(
  candidates
      .where(
        (candidate) =>
            candidate.size == Size.instant &&
            candidate.precedence != CandidatePrecedence.rescue,
      )
      .toList(),
  facts,
  instantDrawsPerDay,
),
```

Same `precedence != rescue` filter on the maintenance `_draw`. Add a weave test: pocket remaining in `[30, headEstimate)` deals `hab-a` (or whichever catalogue instant still fits), not null. Mirror `weave_test.dart:3285` / the chunk fall-through at `:793`.

**P2.2** `packages/core/lib/weave/weave.dart:223` — repair dartdoc. `supersededParentIds` was spliced into the middle of `captureCandidates`' comment (the sentence currently ends `the fact's [Size] rides straight through, no` then jumps to “The parents a chain stands behind”). Restore `captureCandidates`' contract, then give `supersededParentIds` its own docblock.

**P2.3** Test, `packages/core/lib/weave/session.dart:415` — non-focus parent (`cap-maint`): `card_dealt` + matching `slice_returned` + all steps done → `focusSlotCarriedDays` empty and that day's `composeDay.focus` still composes. Existing non-focus test at `weave_test.dart:3142` never appends `slice_returned`.

**P2.4** Test, `packages/core/lib/weave/session.dart:372` — focus-parent chain, only first of two steps `card_done` on a later day → that day is **not** in `focusSlotClosedDays`, and `composeDay.focus` that day is still present.

### Group 2 dismissed (do not resurrect)

- Trying later rescue heads when `[0]` misses the pocket (FIFO: a chain never leapfrogs).
- `focusSlotCarriedDays` only when `slice_returned` matches open `dealtUnanswered` (session-closed-in-flight).
- Chain FIFO using current head instant (all steps minted together).
- Nested `rescueOf` / leftover steps after parent answered (depth cap + `rescueReturned` discard).
- Unbounded `walkLog` vs time-bounded dissolution (existing walk convention).
- Spending Monday's “1” on conversion **and** Tuesday's “1” on completion (both specified).
- New chunk composing on a later day while a chain is live (`nextDeal` still deals the head first).
- File-level comments that merely lag (except the spliced dartdoc, which is P2.2).

## Groups 3–5 (not started)

Same baseline `37acb1c`. After group 2 patches + gate, continue the skill at step 1-style chunk: build that group's diff, four layers, triage, present.

Approximate sizes from the first split:

| Group | Files | + / − |
|---|---|---|
| 3 Store | 5 | +318 / −19 | **Done 2026-09-04 — clean (4 layers, 13 findings, all dismissed)** |
| 4 Shell | 9 | +527 / −124 | **Done 2026-09-04 — 2 decisions resolved (D1 quiet, D2 keep), 3 patches applied, gate green** |
| 5 Tests + artifacts | 27 | +4560 / −170 | **5a core tests done (9 patches, 1 dropped, gate green); 5b weave+lateness done (10 weave tests + separation asserts); 5c shell done (capture/auto/catalogue/parity/v9/const/empty-DB + 3 widget tests); 5d artifacts verified clean (sprint-status `review` matches; deferred-work out-of-band untouched)** |

## Other working-tree noise

`_bmad-output/implementation-artifacts/deferred-work.md` is also modified (+5 lines): two bullets under `## Deferred from: code review of 4-6-rescue-mode (2026-09-04)` about non-atomic rescue landing and the manual Local-Slicer emulator pass. **This session's group 1/2 triage deferred nothing.** Treat that file as out-of-band unless the user says otherwise. Do not revert it blindly.

## Next-step script (when they return)

```
Grupo 2: 4 parches pendientes (decisión fall-through ya tomada).
¿Los aplico todos ahora?  1 apply / 2 leave / 3 walk through
```

Then group 3 Store.

---
title: 'Rescue Mode'
type: 'feature'
created: '2026-09-04'
status: 'done'
review_loop_iteration: 0
baseline_commit: '37acb1c081e2c08bfccd2e6455ce7c57834b2ee2'
context:
  - '{project-root}/_bmad-output/implementation-artifacts/epic-4-context.md'
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** The Slicer, egress, vault and the calm no-Slicer surface all ship, but nothing calls them: `Otra más fácil` still only skips, a task passed over for days keeps returning unchanged, and FR-5 has no mechanics — no `slice_*` log kinds, no refusal counter, no chain weaving, no dissolution.

**Approach:** Core-first mechanics — three new log kinds, two additive `PoolFact` fields (`rescueOf`, `estimateSeconds`), a derived refusal counter over the one `EligibleDay` predicate, a rescue candidate source offering only the head step of each live chain, parent-done-by-derivation and atomic dissolution as pure derivations, and a `rescueRequested`/`rescueReturned`/`rescueFailed` command triple — plus the shell wiring: the secondary control's rescue half, the auto-heuristic at deal, and the 4-5 surface on failure.

## Boundaries & Constraints

**Always:**
- One control, resolved by card state: a **step card's tap skips** (depth cap 1 — the core command itself refuses items with `rescueOf != null`; no refusal surface, no error); a **normal card's tap requests the re-slice** (any dealt card, any moment, no counter needed); after a failed attempt the control is **skip-only for the rest of that deal** (ephemeral shell state, nothing persisted).
- Auto-heuristic: when the resolver deals an item declined on ≥ 3 eligible days since its last activation (or, for catalogue items, ever), the shell requests the re-slice while the dealt card stands. **Activation resets the counter, success, failure or degradation alike** — a failed rescue cannot re-fire on every deal; the tap path stays available at any moment.
- Every rescue sends `RescueSliceRequest{originContext, task}` through the existing BYOK path. Origin context: the capture's own single line, or the shipped entry's Spanish catalogue name (already resolved on the `Card` — no catalogue field, no new loader machinery). No new photo, no per-call dialog.
- `slice_requested` / `slice_returned` / `slice_failed` append on the same terms as existing kinds (AD-21; FR-26 series (b)). The delivered text is parsed **in core** against the 2–4 steps × 1–60 s contract; an unparsable body is `malformedResponse` → `slice_failed` → the 4-5 calm surface (the recorded `unreachable` fold).
- Steps enter as pool facts: **origin inherited from the parent** (AD-14), **size `instant`** (the ≤ 60 s band), **`estimateSeconds` verbatim from the Slicer tag** — every duration-consuming rule (🔴 ceiling, pocket) reads the estimate; size governs only same-size precedence and shape counting.
- Weaving: a rescue candidate source offers **only the first not-yet-answered step** of each live chain, precedence above captures (a new `CandidatePrecedence` member, never a flag); the parent never returns as a candidate from activation onward; all-steps-done retires the parent **by derivation** (no synthetic `card_done`, AD-25); chain steps declined on ≥ 3 eligible days **dissolve parent + pending steps atomically** (no tombstone).
- Slot arithmetic (AD-19/AD-20 as amended by ADV-10): a completed **focus-parent** chain closes the focus slot of — and consumes rotation on — the day of the session that dealt its **last `card_done`**, and no other day (a completion crossing 04:00 charges the session's own day; the crossed-into day stays free), regardless of that day's energy; non-focus parents close nothing. A rescue activation on the day's dealt focus card **satisfies the day's "1"** (no new chunk composes that day — the chain carries the advance); a plain skip still re-resolves a new chunk (AD-20's recorded override); dissolution carries no slot effects.
- Skips feed only these counters — **no cumulative skip total is stored anywhere**.

**Ask First:**
- Tap = ask-first on normal cards (failure states the cause once via the calm surface; the control then skips for that deal) — confirm this reading of the one-control design.
- Rescue activation *satisfies* the dealing day's chunk composition (FR-7's "or its rescue steps" read as conversion, not closure) — confirm.
- Auto-heuristic fires **at deal-time** of a warranted item (not at the 3rd decline itself) — confirm.

**Never:**
- No rescue of a rescue step; no retry, queue or persisted pending state; no cumulative skip storage; no tombstone; no synthetic completion; no new photo path; no per-call consent dialog; no Dispenser mention of key/quota/provider/network beyond the 4-5 surface; no new egress code (port, prompt, schema and transport all ship from 4-4); no new ARB strings; no half-wired control anywhere.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Tap, normal card, success | reachable Slicer, valid body | `slice_requested` → step facts + `slice_returned` → standing card superseded, next deal is the head step | N/A |
| Tap, normal card, failure | any of the 7 causes | `slice_failed` + calm surface with the mapped cause; card stands; control skip-only for this deal | nothing queued; exit works offline |
| Tap, step card | any state | plain skip (`card_skipped`), no ask | no surface, no refusal, no error |
| Second tap after failure | degraded control | `card_skipped` → next deal; decline-day counts toward a fresh cycle | quiet |
| Auto-heuristic | deal of an item at ≥ 3 decline-days | request fires while the card stands; same success/failure flows; counter reset on activation | no loop on later deals |
| Delivered body invalid | steps ∉ [2,4], seconds ∉ [1,60], empty text | `malformedResponse`: `slice_failed` + surface | original stays dealable |
| Parent answered during flight | `card_done` lands before `slice_returned` | `slice_returned` logs; steps discarded; no supersede | quiet |
| Chain completes | last step `card_done`, focus parent | slot + rotation charged to that session's day (crossing-safe, energy-override); parent retired done-by-derivation | no synthetic `card_done` |
| Chain dissolves | chain steps declined on 3 eligible days | parent + pending steps leave the pool atomically, silently | history survives in log + export |
| 🔴 day, live chain | low energy | head step still deals — estimate ≤ 60 s passes the ceiling | N/A |

</frozen-after-approval>

## Code Map

- `packages/core/lib/log/log_entry.dart:60-115,147-166,567,85-99` -- `LogKind` + `ItemActEntry` + conversion; add the three `slice_*` kinds, a `SliceEntry` subtype (item id, origin, cause?), classification (additive-only, AD-23).
- `packages/core/lib/pool/pool_fact.dart:51-95` -- `PoolFact`; add `rescueOf?` (parent item id) and `estimateSeconds?` (verbatim); origin-inheritance doc already at `:14`.
- `packages/core/lib/commands/session_commands.dart:236-257,427-494` -- `_answered`'s supersede-pair grammar (answer row + bundled next `card_dealt`) for `rescueReturned` to mirror.
- `packages/core/lib/derive/eligible_day.dart:113-178` -- the one `EligibleDay` predicate and the `captureDealWindowConsumedDays` fold to copy for both counters; needs a fact-less anchor for catalogue items (size + unbounded start) — a refactor of the helper, not a second predicate (AD-24).
- `packages/core/lib/weave/weave.dart:134-205,289-325,436-539,645-682,731-762` -- `CandidatePrecedence` (rescue joins as member), candidate-source block in `_resolveDay`, `_resolverOrder`, tier ladder, `cardForItem` (estimate override reads the fact).
- `packages/core/lib/weave/session.dart:30-39,43-113,177-339` -- `estimateSecondsOf`, `LogFacts`, `walkLog`: `SliceEntry` case (a `slice_returned` naming the standing item clears `dealtUnanswered`), `focusSlotClosedDays` gains chain completion (parent-size aware, session-day charged).
- `packages/core/lib/ports/slicer_port.dart:59-67,107-139` -- `RescueSliceRequest`, `SlicerOutcome`; the parse of delivered text belongs to core (AD-5).
- `packages/core/lib/ports/no_slicer_cause.dart:74-83` -- total failure→cause map feeding the surface.
- `lib/egress/rescue_contract.dart:51-165` -- the prompt/schema of record; core's parser must agree — pin parity from a shell test (`test/egress/byok_slicer_test.dart:142` left the canned rescue body for exactly this).
- `lib/main.dart:61-65,110-112,156-160` -- slicer built, threaded and unread; this story carries it into the Dispenser.
- `lib/dispenser/dispenser_controller.dart:319-349,432-468` -- `_onSkip`/`_writeInFlight`/`skip` grammar for the rescue flow; log+facts load idiom.
- `lib/ui/dispenser/dispenser_screen.dart:460-464,808-819` -- secondary-control wiring; the push idiom (isCurrent guard) for `NoSlicerSurface`.
- `lib/ui/no_slicer/no_slicer_surface.dart:50-66` -- the failure surface (`cause` + threaded capture/dictation controllers).
- `lib/ui/dispenser/task_card.dart:90-124` -- `SecondaryTextAction`; the string is unchanged (`actionRescueOrSkip`).
- `lib/store/substrate.dart` + `make codegen` -- drift tables `PoolFacts`/`LogEntries` take the additive nullable columns; schema migration on install-on-top (AD-18).
- Test idioms: `packages/core/test/eligible_day_test.dart` (row builders + `test_util.dart`), `packages/core/test/weave_test.dart:2471-2509` (done-once retirement pin), `test/dispenser/dispenser_controller_test.dart`, `test/ui/no_slicer/no_slicer_surface_test.dart`.

## Tasks & Acceptance

**Execution:**
- [x] `packages/core/lib/log/log_entry.dart` + `lib/store/substrate.dart` (+ `make codegen`) -- the three kinds, `SliceEntry`, additive store columns with defaults; unknown-kind tolerance untouched.
- [x] `packages/core/lib/slicer/rescue_steps.dart` + `packages/core/test/slicer/rescue_steps_test.dart` -- the core parser/validator (2–4 steps, non-empty text, 1–60 s each); parity with `rescue_contract.dart` pinned by a shell-side test feeding its canned body through the core parser.
- [x] `packages/core/lib/derive/rescue.dart` + `packages/core/test/derive/rescue_test.dart` -- decline counter over `eligibleDay` (catalogue anchor; reset on activation; absence/non-dealt/energy-neutral by construction), warrant predicate, chain completion, chain-level atomic dissolution.
- [x] `packages/core/lib/commands/rescue_commands.dart` + tests -- `rescueRequested` (refuses steps: the depth cap lives in core), `rescueReturned` (steps facts + supersede pair; discards when the parent was answered in flight), `rescueFailed`.
- [x] `packages/core/lib/weave/` (weave.dart, session.dart, pool source) + tests -- rescue candidate source (head-only, precedence above capture), estimate override through `Candidate`/`Card`/pocket/🔴 ceiling, parent/step retirement from all sources, slot closure + rotation on focus-chain completion (session-day, crossing-safe, energy-override), activation satisfies the dealing day's "1".
- [x] `lib/main.dart`, `lib/dispenser/dispenser_controller.dart`, `lib/ui/dispenser/dispenser_screen.dart` + controller/widget tests -- slicer threaded to the Dispenser; tap resolution (step → skip; degraded-this-deal → skip; normal → ask), in-flight guard, auto-heuristic at deal, failure pushes `NoSlicerSurface` with the mapped cause and threaded controllers.
- [x] `devbox run -- make gate` + `make check` + `make codegen-check` -- all green.

**Acceptance Criteria:**
- Given the same Micro-task declined on 3 different eligible days, when it is next dealt, then a re-slice is attempted — days of absence, non-dealt days and energy filtering neither increment nor reset the count (AD-24).
- Given any dealt card at any moment, when the control is tapped, then a re-slice is requested through the Origin Context and the FR-28 path — no new photo, no per-call dialog.
- Given a shipped parent, when rescued, then the origin context is its Spanish catalogue name (no catalogue field added, steps inherit `shipped`, nothing enters the catalogue — FR-31 stands entire) and the steps are transient pool facts.
- Given a successful re-slice, when the steps enter, then they are 2–4 × ≤ 60 s, estimate verbatim + instant size, woven one at a time, tonally indistinguishable from any other Micro-task.
- Given all steps done, when the parent is evaluated, then it is done by derivation — no synthetic `card_done`; completion counts count user acts only (AD-25).
- Given a focus-parent chain completing, when the last `card_done` lands, then the slot closes and rotation is consumed on that session's day and no other, regardless of that day's energy; a completion crossing 04:00 never closes the crossed-into day.
- Given chain steps declined on 3 different eligible days, when dissolution runs, then the original and every not-yet-completed step retire atomically in one derivation, silently — no tombstone; history survives in the FR-26 series and the export.
- Given a rescue activation, when the refusal counter is evaluated, then it resets — success, failure or no-Slicer degradation alike.
- Given a rescue step, when the control is tapped, then it skips — no second re-slice, no refusal surface, no error, no half-wired control anywhere.
- Given no reachable Slicer, when a rescue is attempted, then the original stays dealable as-is, nothing is queued, and the 4-5 calm surface states the cause plainly.
- Given any skip, when storage is inspected, then skips feed only this counter and no cumulative skip total exists anywhere.

## Spec Change Log

## Design Notes

- The three Ask-First rows are the interpretive calls; rationale: (1) AC 4-6 says the tap on any dealt card *requests a re-slice* and 4-5's surface exists as rescue's failure statement, so ask-first with a once-per-deal degrade keeps FR-3's skip reachable everywhere (a success supersedes = passes the card; a failure states once, then the second tap passes it); (2) FR-7's "or its rescue steps" read as conversion keeps the anti-wall override intact (skips re-resolve; rescues convert) and delivers step 1 promptly (no new chunk buries it); (3) epics' "a failed rescue does not re-trigger on every subsequent deal" names deal-time as the auto-trigger's moment.
- "Dealing session" of a completion = the session of the chain's last `card_done` (the epics' own idiom, lines 673/795; ADV-10's resolution) — hence crossing-safe charging.
- Dissolution is chain-level: declines of any chain steps on ≥ 3 distinct eligible days retire the whole chain — the rescue, not one step, is the refused thing; per-step was rejected because a surviving sibling would be a fragment re-woven forever.
- Catalogue parents have no pool fact, so their counter anchors at "no earlier than" = unbounded and their size comes from the entry — the same single predicate, one fact-less adapter.

## Verification

**Commands:**
- `devbox run -- make gate` -- expected: green (tests, format, analyze).
- `devbox run -- make check` -- expected: green (all seals; string table untouched).
- `devbox run -- make codegen && devbox run -- make codegen-check` -- expected: regenerated store code committed, no diff.

**Manual checks (if no CLI):**
- Debug emulator with the canned Local Slicer (`ORGANIZER_LOCAL_SLICER`): rescue a dealt card end-to-end — steps arrive, the head step deals, `Hecho` × N retires the parent, no synthetic completion in the log. Airplane mode: tap shows the calm surface, back leaves the card standing, the second tap skips it.

## Suggested Review Order

**The one control — tap resolution and the rescue flight**

- The tap's whole grammar: step card → skip, degraded-this-deal → skip, otherwise ask.
  [`dispenser_screen.dart:414`](../../lib/ui/dispenser/dispenser_screen.dart#L414)

- The flight: a deal-scoped guard only — Hecho still lands mid-provider-latency, the landing discards.
  [`dispenser_screen.dart:439`](../../lib/ui/dispenser/dispenser_screen.dart#L439)

- The auto-heuristic at commit — fires once per warranted deal, marker per-deal.
  [`dispenser_screen.dart:602`](../../lib/ui/dispenser/dispenser_screen.dart#L602)

- The controller flow: activation row, outcome branches, cause-to-surface state.
  [`dispenser_controller.dart:570`](../../lib/dispenser/dispenser_controller.dart#L570)

- Every deal-end site clears the degrade/auto markers — "that deal" means that deal.
  [`dispenser_screen.dart:554`](../../lib/ui/dispenser/dispenser_screen.dart#L554)

**Core commands — the `slice_*` triple**

- The activation: depth cap and no-second-chain refusals live in core, not the shell.
  [`rescue_commands.dart:117`](../../packages/core/lib/commands/rescue_commands.dart#L117)

- The landing: steps + supersede pair; any in-flight answer of the parent discards.
  [`rescue_commands.dart:171`](../../packages/core/lib/commands/rescue_commands.dart#L171)

- The terminal failure: one cause row, nothing queued.
  [`rescue_commands.dart:271`](../../packages/core/lib/commands/rescue_commands.dart#L271)

**Derivations — counter, warrant, dissolution**

- Decline days over the one `EligibleDay` predicate, anchored (reset) at activation.
  [`rescue.dart:101`](../../packages/core/lib/derive/rescue.dart#L101)

- The warrant the deal-time heuristic reads.
  [`rescue.dart:145`](../../packages/core/lib/derive/rescue.dart#L145)

- Chain-level atomic dissolution — the rescue, not one step, is the refused thing.
  [`rescue.dart:171`](../../packages/core/lib/derive/rescue.dart#L171)

**The substrate — kinds, flaws, pool pair**

- `SliceEntry` plus the two new read-boundary flaws, cause-checked across every branch.
  [`log_entry.dart:448`](../../packages/core/lib/log/log_entry.dart#L448)

- The rescue pair on facts, sanitized at the read boundary (AD-23 tolerance).
  [`pool_fact.dart:106`](../../packages/core/lib/pool/pool_fact.dart#L106)

- Warm-return contact: `slice_failed` is a system event and never resets the clock.
  [`warm_return.dart:77`](../../packages/core/lib/derive/warm_return.dart#L77)

**The weave — chain candidacy and slot arithmetic**

- Head-only candidacy, precedence above captures — one step at a time.
  [`weave.dart:292`](../../packages/core/lib/weave/weave.dart#L292)

- Source integration plus the one shared superseded-parent fold.
  [`weave.dart:581`](../../packages/core/lib/weave/weave.dart#L581)

- The walk's slice case: supersede clears the standing card; the carried day lands.
  [`session.dart:397`](../../packages/core/lib/weave/session.dart#L397)

- The parser: 2–4 steps × 1–60 s, estimate verbatim for the fact.
  [`rescue_steps.dart:66`](../../packages/core/lib/slicer/rescue_steps.dart#L66)

**Peripherals — tests and store**

- Command-triple matrices, including both in-flight interleavings.
  [`rescue_commands_test.dart:122`](../../packages/core/test/rescue_commands_test.dart#L122)

- Counter and dissolution derivations over synthetic logs.
  [`rescue_test.dart:149`](../../packages/core/test/derive/rescue_test.dart#L149)

- Slot charging: crossing-safe, energy-override, non-focus closes nothing.
  [`weave_test.dart:3084`](../../packages/core/test/weave_test.dart#L3084)

- Screen interleavings: Hecho-during-flight, failing store, per-deal markers.
  [`dispenser_screen_test.dart:2349`](../../test/ui/dispenser/dispenser_screen_test.dart#L2349)

- The v8→v9 additive-only migration group.
  [`substrate_test.dart:2153`](../../test/store/substrate_test.dart#L2153)

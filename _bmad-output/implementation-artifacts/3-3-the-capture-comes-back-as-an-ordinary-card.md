---
title: 'The capture comes back as an ordinary card'
type: 'feature'
created: '2026-09-01'
status: 'done'
review_loop_iteration: 0
baseline_commit: 'd9b6df5b5a72cd447180e81fffc8eef958a41bcb'
context:
  - '{project-root}/_bmad-output/implementation-artifacts/epic-3-context.md'
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** Story 3-2 writes manual pool facts (origin `manual`, a taxonomy `Size`, `originContext` = the single line), but nothing reads them back: the weave's only candidate source is the catalogue, `walkLog` cannot size a manual id (so its deals charge nothing and its `card_done` closes no chunk slot), `cardForItem` cannot re-materialize a dealt capture, and AD-24's one `EligibleDay(item, day)` predicate — the base of the capture's three-eligible-day deal window — does not exist as code.

**Approach:** Make `Origin.manual` pool facts the second candidate source: a `capture` member ahead of `catalogue` in `CandidatePrecedence`, FIFO by the fact's recorded creation instant, a capture-first tier in the chunk resolver, done-once retirement at the source. Mint `EligibleDay` in `core/derive` per AD-24 verbatim plus the three-eligible-day window derivation over it. Thread pool facts through `walkLog`, the weave's entry points, the session commands, the read facade and the two controllers. No schema change, no strings, no UI file changes.

## Boundaries & Constraints

**Always:**
- The three capture sizes ARE the 1-3-5 taxonomy — no conversion: candidates carry their fact `Size`; draw caps, budget arithmetic and pocket charging are unchanged, and a dealt capture charges its size's daily count exactly like a catalogue deal.
- Captures take precedence over same-size Evergreen material, offered as candidates only — `core/weave` stays the only deal emitter.
- Same-size captures order oldest-first (FIFO) by the fact's recorded creation instant, never id bit patterns; a skip keeps the capture's FIFO place (the day is consumed, never extended).
- A not-yet-answered `focus` capture is the chunk tier ahead of the zone tier, composing even with no active zone, still gated by the existing chunk gate (bag ≥ 10, energy ≠ low, slot open); the day never holds a second large item beside it.
- The deal window is expressed over the one `EligibleDay` predicate — no second definition: `captureDealWindowEligibleDays = 3` as a named const; a day consumes a unit iff it is an eligible day of the capture AND a `card_dealt` for it is charged to that day (answered or skipped); 🔴 days exclude `focus`/`maintenance` by size and absence days have no session, so neither can consume; resume falls out of recomputation (nothing stored); no expiry, no cap, nothing deleted.
- `EligibleDay` per AD-24 verbatim: a domestic day on which at least one session started — by start instant, no earlier than the item's pool-fact creation, and a session outliving its day does not make the later day eligible — and at whose start at least one of that day's sessions found the item's size not excluded; energy at a session's start is the last `energy_set` of that session's own domestic day at or before its start instant, defaulting 🟢.
- Indistinguishability is structural: the dealt capture renders through the existing `Card`/`TaskCard` with `name = originContext` and `zone = null`; origin never renders; no badge, icon or copy.
- Done-once: a capture with a `card_done` is retired from candidacy (the retirement derivation lives at the candidate source, AD-25); a skipped capture stays a candidate.
- Every shell snapshot that resolves or mints a deal reads `readPoolFacts()` inside the same queued operation as the log read; the core receives facts as handed-in inert data.
- Guard hygiene: the new derive file reads entry TYPES (`SessionStartEntry`, `EnergySetEntry`), never kind identifiers or wire-name literals; all new identifiers avoid the nine banned vocabulary tokens (incl. `pending`).

**Ask First:**
- Anything that would create a second eligibility definition, a stored window state, or a precedence expiry.
- Any UI copy, string-table or schema change (none expected).
- Any surface or facade function that lists, counts, filters or browses captures.

**Never:**
- No facade function returns a collection of work items; the read facade gains nothing but the facts input to `nextCard`.
- The window never gates candidacy: precedence persists while the capture is unanswered — "dealt within three eligible days" holds by construction (precedence + FIFO + daily draw counts), and the window derivation exists to be pinned now and read later (FR-5, FR-26).
- No new `LogKind`, no schema change, no UPDATE/DELETE; the walk stays inert to `capture_created` rows (candidacy reads pool facts, never the kind constant).
- No dictation (3.4), no rescue (FR-5), no origin arithmetic change, no epic/cluster concepts on captures.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Happy path | Manual fact in pool, session starts | First deal is the capture; card name = its line; charges its size's daily count | N/A |
| FIFO | Two same-size captures | Oldest fact dealt first; after a skip the same capture re-offers (place kept) | N/A |
| Focus capture | Not-yet-answered `focus` fact, bag ≥ 10, 🟢 | Capture is the chunk (no active zone needed); no second large item composes | N/A |
| Done capture | `cardDone` on a dealt capture | Never dealt again (retired); a `focus` capture's done closes the day's chunk slot | N/A |
| 🔴 day | Energy low | Focus/maintenance captures reach no draw (existing ceiling); window consumes nothing | N/A |
| Absence | Days with no session start ≥ creation | Not eligible; window frozen; nothing expires | N/A |
| Mid-session capture | Fact created inside an open session | That session's day is not eligible (its start precedes creation); a later same-day session start makes it eligible | N/A |
| Store read throws | Failing store | Existing quiet-absorption paths unchanged | Quiet |

</frozen-after-approval>

## Code Map

- `packages/core/lib/derive/eligible_day.dart` -- NEW, the `warm_return.dart` grammar (pure, one pass, rows-after-read skipped): `eligibleDay(...)`, `captureDealWindowEligibleDays`, the consumed-days derivation. Types only.
- `packages/core/lib/weave/session.dart` -- `walkLog` L157: `sizeByItemId` L159 gains fact sizes from a new optional `poolFacts` param ("later sources extend exactly here", L133); new `LogFacts.dealtDaysByItemId` (charged day per `card_dealt`, unconditional in the item's id — the kind stays readable only here); `_chargedDayOf` L109 is the attribution rule.
- `packages/core/lib/weave/weave.dart` -- `CandidatePrecedence` L132 (new `capture` member before `catalogue` — index decides at L238); `Candidate` L140 gains the creation instant (FIFO key); new `captureCandidates(poolFacts, answeredItemIds)` beside `shippedCandidates` L171 (done-once retirement lives here); `_resolverOrder` L233: same-precedence captures compare fact instants, tie stable id; `_chunkCandidateOf` L288: capture tier BEFORE the `activeZone == null` exit L293, filtered to not-yet-answered; `_resolveDay` L347 (candidates L376–382, chunk L383–395) threads facts; `composeDay` L460, `nextDeal` L510, `dealExistsIgnoringPocket` L588, `cardForItem` L615 (catalogue first, then facts: name `originContext`, size from fact, zone null) all gain `List<PoolFact> poolFacts = const []`.
- `packages/core/lib/commands/session_commands.dart` -- `sessionStart` L149, `cardDone` L188, `cardSkipped` L214, `sessionDeclare`, `appOpen`, `_answered` L397: same defaulted `poolFacts` param, threaded to `walkLog` + `nextDeal` (sites L171/289/437).
- `packages/core/lib/ports/store_port.dart` -- `PoolFactRecord` L25, `readPoolFacts` L78; add `poolFactsOf(List<PoolFactRecord>)` HERE (import cycle forbids `pool_fact.dart` hosting it; `logEntriesOf`'s inverted precedent, log_entry.dart:755).
- `packages/core/lib/facade/read_facade.dart` -- `nextCard` L37: read facts once, pass to `cardForItem` L48 and `nextDeal` L54. Nothing else exposes.
- `lib/dispenser/dispenser_controller.dart` -- `read` L237 (`nextDeal` L289, `cardForItem` L301, `dealExistsIgnoringPocket` L321), `complete` L370, skip (`cardSkipped`) L425, declare L470, extend L561: read `store.readPoolFacts()` inside each queued op, thread through.
- `lib/session/session_controller.dart` -- `handleAppOpen` L105–123 (`appOpen` L114): same threading.
- `packages/core/test/no_lateness_proof_test.dart` -- reader sets L1112 (`cardDone`/`cardDealt`), L1501–1591 (`captureCreated`), L1608 (session kinds): the new derive file stays outside all of them by reading types/facts only; `tool/check_forbidden_vocabulary.dart` bans `pending`/`late`/`overdue`/`backlog`… in identifiers.
- Tests: `weave_test.dart` harness (builders L82–130, `_catalogue` L52; the walk's inertness pin L2231 STAYS TRUE — facts, not rows); `warm_return_test.dart` builder pattern for the new derive test; `facade_test.dart`, `session_commands_test.dart`, `session_test.dart`; shell `test/dispenser/dispenser_controller_test.dart` (`_RecordingStore` gains pool facts).

## Tasks & Acceptance

**Execution:**
- [x] `packages/core/lib/derive/eligible_day.dart` -- NEW: the AD-24 predicate, the window const, the consumed-days derivation over `LogFacts.dealtDaysByItemId` -- the story's derived law, pinned by tests.
- [x] `packages/core/lib/weave/session.dart` -- `poolFacts` sizing + `dealtDaysByItemId` fact in `walkLog` -- manual ids charge counts, close chunk slots, and expose dealt days.
- [x] `packages/core/lib/weave/weave.dart` -- precedence member, FIFO key, `captureCandidates` with done-once retirement, chunk capture tier, `poolFacts` on the five entry points -- the candidacy itself.
- [x] `packages/core/lib/commands/session_commands.dart` + `packages/core/lib/ports/store_port.dart` -- `poolFacts` param on the six commands; `poolFactsOf` converter -- bundled deals see captures.
- [x] `packages/core/lib/facade/read_facade.dart` + `lib/dispenser/dispenser_controller.dart` + `lib/session/session_controller.dart` -- read facts in each queued snapshot and thread -- the shell seam.
- [x] `packages/core/test/eligible_day_test.dart` -- NEW: predicate clauses (witness ≥ creation, outliving session, own-day energy, 🟢 default, size exclusion) + window matrix (consumed answered/skipped, 🔴 freeze, absence freeze, resume, no expiry, instant-on-🔴 eligible).
- [x] `packages/core/test/weave_test.dart` + `session_test.dart` + `facade_test.dart` + `session_commands_test.dart` -- precedence over same-size catalogue, FIFO + skip-keeps-place, chunk tier (incl. no active zone), done-once retirement, draw-count charging, standing-capture re-materialization; walk stays inert to `capture_created` rows.
- [x] `test/dispenser/dispenser_controller_test.dart` -- read deals the capture by its line; complete closes the chunk slot for a `focus` capture; skip re-bundles; fakes carry facts.

**Acceptance Criteria:**
- Given a pool holding a manual capture and an open session, when the resolver runs, then the capture is dealt before any same-size catalogue candidate and the dealt card's name is the capture's own line.
- Given several same-size captures, when they are ordered, then they deal oldest-first by recorded fact instants, never id bit patterns, and a skip preserves the order.
- Given a not-yet-answered 10–15 min capture and a composing day, when the chunk resolves, then the capture is the day's "1" and no second large item composes beside it.
- Given a dealt capture, when it is answered, then it never deals again; when it is skipped, then it remains a candidate with its FIFO place.
- Given the window derivation over any log, when it is evaluated, then it counts exactly the capture's eligible dealt days (answered or skipped), freezes across 🔴-excluded and absent days, resumes with no expiry, and no second eligibility definition exists anywhere.
- Given any screen or the read facade, when audited, then nothing lists, counts, filters or browses captures, and a dealt capture's origin never reaches the Dispenser.

### Review Findings

- [x] [Review][Patch] Focus capture is untested against the bag half of the chunk gate [`packages/core/lib/weave/weave.dart:479`]
- [x] [Review][Patch] Launch path does not pin pool-fact threading [`test/session/session_controller_test.dart:34`]
- [x] [Review][Patch] Read-facade header still says derive holds two residents [`packages/core/lib/facade/read_facade.dart:6`]

## Spec Change Log

## Design Notes

- The window is derived law, not a gate. Precedence persists while a capture is unanswered; "dealt within three eligible days" is guaranteed by construction (precedence + FIFO + the daily draw counts). The derivation exists so AD-24's semantics are executable and pinnable now — FR-5's counter and FR-26's instrumentation read it later. This reading follows the PRD's own analogy ("freezes… exactly as FR-5 freezes its own counter", whose count increments only on dealt-and-declined days).
- Consumption attributes a deal to its charged day (AD-19's session-day rule, the same rule `dealtCountsByDay` uses). Eligibility requires a session starting no earlier than the fact's creation, so a capture created mid-session and dealt before any new session start consumes nothing — rare, literal, pinned by test.
- An `instant` capture on a 🔴 day is eligible (30 s ≤ the 60 s ceiling, so its size is not excluded) and a deal consumes — AD-24's size-exclusion is the canonical freeze mechanics; the epic's "🔴 freezes" prose is the chunk/maintenance reading.
- `cardForItem` reads facts so the dealt-but-unanswered capture survives reads exactly as a catalogue card does — the standing-card path never depends on candidacy.

## Verification

**Commands:**
- `devbox run -- make gate` -- expected: green (flutter test, format check, analyze).
- `devbox run -- make check` -- expected: green (core purity, no-literal-strings, string-table audit, text scaling, forbidden vocabulary — no `pending`-shaped identifiers — store seal, codegen freshness).

## Suggested Review Order

**The law — AD-24 becomes executable**

- The window's width, stated once — never a threshold the resolver consults
  [`eligible_day.dart:67`](../../packages/core/lib/derive/eligible_day.dart#L67)

- The one eligibility predicate: session-start witness, own-day energy, size exclusion
  [`eligible_day.dart:113`](../../packages/core/lib/derive/eligible_day.dart#L113)

- The consumed-days fold — read-bounded, no second attribution rule, no clamp
  [`eligible_day.dart:155`](../../packages/core/lib/derive/eligible_day.dart#L155)

**The candidacy — captures as a second source**

- The second precedence member: index is the arbitration, captures ahead of Evergreen
  [`weave.dart:135`](../../packages/core/lib/weave/weave.dart#L135)

- The capture source: done-once retirement lives here, dedupe, name = the line
  [`weave.dart:221`](../../packages/core/lib/weave/weave.dart#L221)

- The FIFO branch: fact instants order captures; deal history never re-orders them
  [`weave.dart:298`](../../packages/core/lib/weave/weave.dart#L298)

- The chunk's capture tier — ahead of every zone tier, no active zone needed
  [`weave.dart:373`](../../packages/core/lib/weave/weave.dart#L373)

- The pipeline seam: both sources feed the one resolver, 🔴 ceiling included
  [`weave.dart:473`](../../packages/core/lib/weave/weave.dart#L473)

- The standing capture re-materializes from facts — reads never depend on candidacy
  [`weave.dart:749`](../../packages/core/lib/weave/weave.dart#L749)

**The walk — sizing and dealt days**

- Facts size their ids at the walk's own seam, catalogue precedence, fill-only-absent
  [`session.dart:196`](../../packages/core/lib/weave/session.dart#L196)

- The window's input fact: charged days per `card_dealt`, unconditional in the id
  [`session.dart:208`](../../packages/core/lib/weave/session.dart#L208)

**The shell seam — one snapshot, both stores**

- The facade reads facts beside the log; `nextCard` stays the only surface
  [`read_facade.dart:52`](../../packages/core/lib/facade/read_facade.dart#L52)

- All five dispenser ops read facts inside the same queued operation
  [`dispenser_controller.dart:249`](../../lib/dispenser/dispenser_controller.dart#L249)

- The records→facts converter, the `logEntriesOf`-inverted home
  [`store_port.dart:72`](../../packages/core/lib/ports/store_port.dart#L72)

**Evidence**

- Predicate + window matrix: witness, freeze, resume, boundaries, rows-after-read
  [`eligible_day_test.dart:115`](../../packages/core/test/eligible_day_test.dart#L115)

- Candidacy pins: precedence, FIFO, skip-keeps-place, chunk tier, retirement
  [`weave_test.dart:2348`](../../packages/core/test/weave_test.dart#L2348)

- The walk stays inert to `capture_created` rows — facts, never the kind
  [`weave_test.dart:2274`](../../packages/core/test/weave_test.dart#L2274)

- FIFO through the record seam — `poolFactsOf`'s instant mapping pinned
  [`facade_test.dart:757`](../../packages/core/test/facade_test.dart#L757)

- The controller round: deal-by-line, Hecho closes the slot, declare/extend thread facts
  [`dispenser_controller_test.dart:3090`](../../test/dispenser/dispenser_controller_test.dart#L3090)

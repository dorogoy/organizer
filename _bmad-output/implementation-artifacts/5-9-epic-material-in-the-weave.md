---
title: 'Story 5.9: Epic material in the weave'
type: 'feature'
created: '2026-09-08'
status: 'done'
review_loop_iteration: 0
baseline_commit: '8ad91b7f1e965ddf7cf373b52a54044065bf3cb7'
context:
  - '{project-root}/_bmad-output/implementation-artifacts/epic-5-context.md'
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** Stories 5.7 and 5.8 land a slice as pool facts that nothing can deal: a fact with `origin ∈ {cloud, local}` and `rescueOf == null` matches none of the three candidate sources (`weave.dart:574-587`), no Epic Project exists anywhere in the code (no entity, no `epic_activated` kind, no arbitration, no precedence member), and `cardForItem` still names a fact by its Origin Context — so the user consents, waits through the uncapped wait, and is returned to the same card that stood before.

**Approach:** An Epic Project is a **derivation, not a stored entity**: one slice's facts already share one resolution instant and one Origin Context, and that pair is the insert-only grouping key — the Epic's stable id is its first step's fact id, in the snapshot order 5.7 declared as the plan's order. A new `epic_activated` log kind, minted once at a successful landing, makes an Epic active; its absence *is* dormancy. A fourth candidate source offers one head step per active Epic at a new `CandidatePrecedence.epic`, entering the Focus slot **by candidate class rather than size** (`pool_fact.dart:66`'s forward declaration), tiered after the capture tier and before the zone ring, arbitrated least-recently-served → activation order → stable id. The step's own words finally become the card's name.

## Boundaries & Constraints

**Always:**
- **Epic identity is derived, never stored** — no column, no table, no schema version bump. Group key: facts with `origin ∈ {cloud, local} ∧ rescueOf == null ∧ stepText != null` sharing `(instantUtcMicros, originContext)`; the Epic's **stable id** is the group's first fact in snapshot order (`readPoolFacts`' instant-then-rowid tiebreak, `drift_store.dart:71-83`).
- **Dormant = no `epic_activated` row naming the stable id.** A dormant Epic reaches no candidate source, no draw, no chunk, no count and no card — invisible by construction, never by a guard, so a landing that crashed mid-plan (5.7's per-fact, transaction-free append) derives honestly as dormant.
- `epic_activated` is a **user act** (AD-21) in the existing item-act shape: `itemId` = the stable id, `itemOrigin` = the Epic's origin (AD-14 — every entry referencing an item carries it). Exactly one row per successful landing, minted only when at least one fact landed, from the two landing paths and nowhere else. Kind census 20 → 21; no new entry subtype, no new `LogRecordFlaw`, no eighth degradation cause.
- **Focus-slot eligibility is by candidate class, never size** (`pool_fact.dart:66`): an Epic head enters the chunk pool although it bands `maintenance` (180–300 s), and is excluded from the maintenance and instant draws exactly as `rescue` is (`weave.dart:651,662`) — a step is the day's "1" or nothing.
- Chunk tiers in order: capture → **epic** → active zone → `fondo` → below-floor fallback. The epic tier sits **before** `_chunkCandidateOf`'s `activeZone == null` return (`weave.dart:474`), so FR-11's empty ring still deals an Epic.
- **Arbitration (AD-20)**: least-recently-served active Epic — the maximum `lastDealtInstantByItemId` over its steps, never-served first — then activation order (the `epic_activated` append order), then the stable id. Inside one Epic the head is plan order: the first step **neither answered all-time, nor skipped on the resolution day, nor superseded through Rescue Mode**.
- Origin is unchanged and immutable: `cloud` on BYOK, `local` on the debug stub, set at the landing (`scan_controller.dart:682`, `genesis_controller.dart:227`), never surfaced in the Dispenser (AD-14).
- Purity holds: the activation fold belongs in `walkLog` beside every other log fold; `epicCandidates` reads `LogFacts` and never the log — no second walk, no wall clock, no `Random` (AD-3, AD-5).

**Ask First:**
- Any pool-fact column, schema version, new table, or a second grouping key.
- Any new log kind beyond `epic_activated`; any change to the scan/genesis payload shapes, the egress seals or the seven no-Slicer causes.
- Any string change — no new ARB key is expected on this story.
- Any change to `_chunkComposes`' bag/energy gate (a 3–5 min Epic step under a 10-minute bag composes no "1" — FR-7's rule, deliberately kept).

**Never:**
- No template, catalogue entry, curation cluster or E1 surface may create an Epic Project (FR-11).
- No invisible buffers, target dates, slack, milestones, purge injection, seasonal suggestion or curation row — 5.10–5.13 and Epic 6.
- No surface that enumerates, counts, previews or shows progress on an Epic's remaining steps (NL-1); no ordinal column; no plan view.
- No Dispenser surface work: `didPopNext` already re-derives on the pop (`dispenser_screen.dart:220`).

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Landing, ≥ 1 fact | successful scan or typed slice | N facts, then one `epic_activated` (first fact id, the landing's origin) | Store failure absorbed quietly — the house write-queue discipline |
| Landing crashed mid-plan | k < N facts, no activation row | Epic dormant: no candidate, no draw, no card, no count | Derives honestly, no repair path |
| One active Epic, full day | bag ≥ 10 min, energy not low | Chunk = the Epic's first unanswered step, named by its `stepText` | — |
| Head skipped today | `card_skipped` on the head, same domestic day | The next unskipped step becomes the head; last step skipped → the Epic offers nothing today and the zone tier composes | Never the same card twice (AD-20) |
| Two active Epics | both hold unanswered steps | Least-recently-served wins; both never served → activation order; identical → stable id | Deterministic, replay-stable |
| Step answered | `card_done` all-time | Retired at the source; next step is the head; all answered → the Epic offers nothing | — |
| 🔴 day | derived energy low | The head's 180–300 s estimate fails `lowEnergyAdmits` (≤ 60 s) → no Epic in any draw | The day composes upkeep and habits |
| Standing Epic card | dealt-but-unanswered step re-read | `cardForItem` names it by `stepText`, same estimate as its deal | Absent when no source knows the id |
| Live rescue chain + active Epic | both offer candidates | The rescue head still deals first — `_guardedTierDealOf`'s ladder unchanged | — |

</frozen-after-approval>

## Code Map

- `packages/core/lib/log/log_entry.dart` -- add `LogKind.epicActivated` to the constant block (:107-126) and to `knownByName` (:129), and to `_isItemAct` (:658) so it converts to the existing `ItemActEntry` (:199) carrying the `(itemId, itemOrigin)` pair. No new subtype, no new `LogRecordFlaw` — the item pair's flaws already exist. Verify no other classifier or fold in the conversion (`convertLogEntryRecord:713`) needs a branch.
- `packages/core/lib/commands/scan_commands.dart` -- NEW `epicActivated({required String itemId, required Origin origin})` → one `LogEntryContent`, on `consentGranted`'s shape (:76). The slice channel's own file, shared by both entrances; the kind's single sanctioned minter.
- `packages/core/lib/weave/session.dart` -- the activation fold in `walkLog` (:218, beside `lastDealtInstantByItemId`'s branch at :365): a new insertion-ordered `LogFacts` field (:153) mapping each activated Epic's stable id to its activation instant — append order **is** activation order (AD-3). Confirm the new item-act kind disturbs no existing fold (`answeredItemIds:98`, `skippedDaysByItemId:93` key on their own kinds).
- `packages/core/lib/weave/weave.dart` -- the story's heart:
  - `CandidatePrecedence.epic` between `capture` and `catalogue` (:151) — a member, never a flag (the enum's own doc rule).
  - NEW `epicCandidates(List<PoolFact>, LogFacts, Day, Set<String> supersededParents)` beside `rescueCandidates` (:364): the grouping fold (`rescueCandidates`' `headsByParent` shape), the head rule, and the AD-20 arbitration expressed as the returned order; `name: fact.stepText ?? fact.originContext ?? ''`, `estimateSeconds: fact.estimateSeconds`, `zone: null`, `createdInstantUtcMicros: fact.instantUtcMicros`.
  - the spread in `_resolveDay`'s candidate list (:728), after `captureCandidates`.
  - the chunk pool filter (:744): `size == Size.focus || precedence == CandidatePrecedence.epic`.
  - the epic tier in `_chunkCandidateOf` (:611) — after the capture tier's return (:604), **before** the `activeZone == null` return (:618); it takes the source's first epic candidate, the source owning the Epic arbitration inside `core/weave` (AD-20's "the resolver's too").
  - the two draw exclusions (:803, :815): `precedence != rescue && precedence != epic`.
  - `cardForItem`'s naming (:1049): `fact.stepText ?? fact.originContext ?? ''` — one expression for the candidate and the standing card.
- `lib/scan/scan_controller.dart` -- `_appendScanLanded` (:769): keep the first minted fact id and append the `epicActivated` row after the fact loop (:795), inside the same queued closure; nothing else on the path moves.
- `lib/genesis/genesis_controller.dart` -- `_appendGenesisLanded` (:369): the same addition (:405-412), the epoch re-checks (:377, :386) unchanged.
- Read-only evidence: `lib/store/drift_store.dart:75-87` (the order contract this story consumes), `packages/core/lib/pool/pool_fact.dart:66` (the class-not-size declaration), `packages/core/lib/commands/scan_commands.dart:187` (`scanSliceLanded`, untouched), `lib/ui/dispenser/dispenser_screen.dart:222` (`didPopNext` already re-derives), `packages/core/lib/weave/weave.dart:931` (`_guardedTierDealOf`'s ladder, untouched).
- Tests: NEW group in `packages/core/test/weave_test.dart` ("Epic material in the weave", on the rescue-chain group's shapes at :2888; the group itself at :4172) covering the whole matrix; NEW fold pins in `packages/core/test/session_test.dart` (:660); RENEGOTIATE `packages/core/test/log_test.dart:43-92` (sorted names + census 21; the conversion pin :229), `test/no_lateness_proof_test.dart:479-504` and `:508-518` (`appendLogEntry` census: scan 1 → 2, genesis 1 → 2), `test/scan/scan_controller_test.dart` (:824) + `test/genesis/genesis_controller_test.dart` (:246) (one activation row per landing, none when nothing landed). VERIFY unchanged: `packages/core/test/no_lateness_proof_test.dart:2383` (the kind-name vocabulary ban — `epic_activated` passes) and `:1227` (frozen-type census — no new type), `test/weave/rotation_asset_test.dart` (no Epic facts in the asset runs, so the counts must not move).

## Tasks & Acceptance

**Execution:**
- [x] `packages/core/lib/log/log_entry.dart` -- the kind, its registry entry and the item-act classifier -- the vocabulary AD-21 requires
- [x] `packages/core/lib/commands/scan_commands.dart` -- the `epicActivated` minter -- one sanctioned writer for the row
- [x] `packages/core/lib/weave/session.dart` -- the activation fold on `LogFacts` -- "active" becomes a derivation, purely
- [x] `packages/core/lib/weave/weave.dart` -- precedence member, `epicCandidates`, the spread, the chunk pool, the epic tier, the draw exclusions, `stepText` naming -- Epic material enters the weave under the one resolver
- [x] `lib/scan/scan_controller.dart` + `lib/genesis/genesis_controller.dart` -- append the activation row at each landing -- both entrances activate on the same terms
- [x] Tests -- the matrix plus the renegotiation list in the Code Map -- the laws pinned

**Acceptance Criteria:**
- Given any template, archetype, catalogue entry or curation cluster, when an Epic Project is sought, then no path creates one — Epic material exists only where the Slicer landed it, from input the user supplied (FR-11).
- Given a created Epic Project, when its lifecycle is inspected, then it is dormant until activated and appears in no default view while dormant — not listed, not counted, not previewed — and activation is one `epic_activated` entry and nothing else (FR-11, AD-21).
- Given the composed day, when a chunk is emitted, then `core/weave` is still the only code that emits a deal: the Epic source returns candidates with precedence and never a card (AD-20).
- Given a sliced Epic step, when its provenance is read, then its origin is `cloud` on the BYOK path, set once at genesis, immutable, and rendered by no surface (AD-14).
- Given a successful slice, when the user returns to the Dispenser, then exactly one card stands — the plan's first step, in its own words — and nothing enumerates, counts or previews the rest (FR-1, UJ-2, NL-1).

### Review Findings

<!-- bmad:code-review 2026-09-08 — layers: blind-hunter, edge-case-hunter, verification-gap, acceptance-auditor -->

- [x] [Review][Patch] Activation-order tie-break must be append order, not instant-then-stable-id (decision 2026-09-08: align to the frozen constraint) — rank `epicCandidates`' comparator by `epicActivatedInstantByStableId`'s key iteration order (the fold's insertion order — a total order, no ties), update the comparator's comment, and rewrite the tied-instant test pin (append order wins: `e2s1`, not lexicographic `e1s1`); the two `session.dart` doc comments already describe this rule and stay. [packages/core/lib/weave/weave.dart:435-443, packages/core/test/weave_test.dart:4354-4365]
- [x] [Review][Patch] Ratify the head rule's supersession conjunct (decision 2026-09-08: renegotiate the frozen sentence) — extend the frozen head-rule definition from "neither answered all-time nor skipped on the resolution day" to include "nor superseded through Rescue Mode", matching the implemented and pinned behavior (`weave.dart:396`: the Epic's next step becomes the head instead of the whole Epic vanishing from every draw); record the renegotiation in the Spec Change Log. Code and tests stay as landed. [_bmad-output/implementation-artifacts/5-9-epic-material-in-the-weave.md:26]
- [x] [Review][Patch] Empty-ring composition unpinned — no test composes a day with `activeClusters: const {}` plus an active Epic, so the epic tier's placement before `_chunkCandidateOf`'s `activeZone == null` return (`weave.dart:611-620`) — the design note's central claim (FR-11's empty ring still deals an Epic) — can be reordered to strand every active Epic on ring-empty days with the whole suite green. Mirror the capture tier's own pin shape (`weave_test.dart:2530-2541`). [packages/core/test/weave_test.dart:4172+]
- [x] [Review][Patch] Local-path activation row unpinned — the `epic_activated` row's presence, `itemOrigin == Origin.local` and stable-id naming are pinned only on cloud paths (`scan_controller_test.dart:827-874`, `genesis_controller_test.dart:230-253`); both Local-stub tests (`scan_controller_test.dart:972-987`, `genesis_controller_test.dart:249-272`) assert only the facts, so hardcoding `Origin.cloud` into the append or guarding it on cloud origin survives green — AD-14's provenance pair unverified on the debug path. Extend both with the cloud-path entry-assertion shape. [test/scan/scan_controller_test.dart:972, test/genesis/genesis_controller_test.dart:249]
- [x] [Review][Patch] Epic-vs-`fondo` and below-floor tier order unpinned — capture-vs-epic and rescue-vs-epic are pinned; the ladder positions "epic beats seasonal focus" and "epic beats the below-floor fallback" are exercised by no test. [packages/core/test/weave_test.dart:4172+]
- [x] [Review][Patch] Orphan `epic_activated` row unpinned — an activation naming a stable id with no pool facts is kept by the fold and must derive as no-candidate (fail-safe dormancy); no test pins it. [packages/core/test/weave_test.dart:4172+]
- [x] [Review][Patch] Code Map stale against the landed code — `epicCandidates`' prescribed signature `epicCandidates(List<PoolFact>, LogFacts)` gained `Day` and `Set<String> supersededParents`; and the Code Map's pre-change line refs (e.g. `:136`, `:292`, `:456`) conflict with the Suggested Review Order's post-change refs for the same hunks. Align the non-frozen Code Map to the landed code. [_bmad-output/implementation-artifacts/5-9-epic-material-in-the-weave.md:56-77]
- [x] [Review][Patch] `sprint-status.yaml` `last_updated` drops the time component (`09-07-2026 23:52` → `09-08-2026`), inconsistent with the file's own `generated` stamp and every prior value. [_bmad-output/implementation-artifacts/sprint-status.yaml:32]
- [x] [Review][Defer] Scan/genesis epoch asymmetry around the activation append — `ScanController._appendScanLanded` never re-checks `_epoch` while `GenesisController._appendGenesisLanded` re-checks before the `epic_activated` append, diverging the two entrances on a documented safety property — deferred, pre-existing (already recorded in `deferred-work.md` under the 5-9 code-review heading, 2026-09-08; both landing methods inherited their own pre-existing epoch convention)

## Spec Change Log

- **2026-09-08, code review (ratified by Sergio):** the frozen Arbitration (AD-20) head rule gained its third conjunct — "nor superseded through Rescue Mode" — ratifying the implemented and pinned behavior (`epicCandidates`' source-side exclusion): an Epic whose head is being rescued advances to its next step instead of vanishing from every draw for the day. The two-conjunct sentence had been left unrenegotiated when the supersession fix landed inside this story.

## Design Notes

- **Why derivation, not a column.** The 5.7 landing declared the contract this story reads: *"the plan's ORDER is the store's snapshot order … no ordinal column exists by design"* (`scan_controller.dart:751`, `drift_store.dart:74`). One slice's facts already share one resolution instant and one Origin Context, so that pair is a total, insert-only grouping key — an Epic needs no schema version, no migration and no third table, and AD-23's additive-only budget stays unspent. The stable id AD-20 asks for is the group's first fact id, a value the shell already mints.
- **Why activation is a row and dormancy is its absence.** AD-21 forbids an entry that asserts an absence, so "dormant" cannot be logged — it can only be the state in which no activation row names the Epic. That makes the invariant free rather than guarded: every reader that needs *active* reads the log, and 5.7's transaction-free per-fact landing is dormant by construction when it dies halfway.
- **Why the epic tier sits after capture and before the ring.** FR-12 orders the slot's sources "the active Epic Project, the active zone, or `fondo`", while AD-20's *Prevents* names the pending 10–15 min capture's precedence as the conflict the resolver must settle — the capture tier already settles it. Placing the epic tier before `_chunkCandidateOf`'s `activeZone == null` return is what lets an Epic compose on FR-11's empty ring.
- **Why a skipped head steps aside for the day.** AD-20: identity re-resolves on each deal, so a skip must yield a *different* candidate. A head-only source with one active Epic has no ordering escape — the capture source's demotion-by-`lastDealt` cannot apply when the group offers exactly one candidate — so the head rule reads "neither answered all-time nor skipped on this day", reusing `skippedDaysByItemId` (`session.dart:91`) verbatim. With its last step skipped the Epic is silent for the day and the zone tier composes: nothing is owed, and no wall appears.
- **Why `stepText` finally becomes the name.** 5.7 left `cardForItem`'s `originContext ?? ''` untouched on purpose — *"scan facts cannot be dealt until 5.9, which owns Epic-step naming"*. One expression, `stepText ?? originContext ?? ''`, serves both the candidate and the standing card: the step's own words name the card while the space description stays the Origin Context a future re-slice composes from (FR-5).

## Verification

**Commands:**
- `devbox run -- make gate` -- expected: green (format, analyze, root and core suites incl. the new weave group and the renegotiated censuses)
- `devbox run -- make check` -- expected: green — ARB byte-identical, egress seals untouched, store seal unchanged, codegen fresh (no schema change)
- `devbox run -- make test-core` and `devbox run -- flutter test test/scan/ test/genesis/ test/no_lateness_proof_test.dart test/weave/` -- expected: exit 0

**Manual checks (device, AGENTS.md recipe):**
- One card, not a plan: debug build `--dart-define=ORGANIZER_LOCAL_SLICER=true` → `Nuevo proyecto` → type → `Analizar` → `Creando tareas` → the Dispenser stands with **one** card whose line is the slice's **first step's own words**; nothing on screen enumerates or counts the rest.
- The substrate: pulled `organizer_substrate.sqlite` shows N pool facts (origin `local`, `step_text` per step, shared `origin_context` and instant) and exactly **one** `epic_activated` row whose `item_id` equals the first fact's id.
- Answer and skip: `Hecho` → the plan's second step stands next; on a fresh slice, `Skip` on the head → a different card, and the substrate shows one `card_skipped` and no second activation row.

## Suggested Review Order

**The grouping and arbitration — the story's heart**

- `epicCandidates`: the derivation (group by shared instant + Origin Context, stable id = first fact), the head rule (unanswered, unskipped-today, unsuperseded), and the AD-20 arbitration order it returns pre-sorted.
  [`weave.dart:364`](../../packages/core/lib/weave/weave.dart#L364)

- The precedence member — a member, never a flag, between capture and catalogue.
  [`weave.dart:151`](../../packages/core/lib/weave/weave.dart#L151)

- The assembly: the epic source spread into `_resolveDay`'s candidate list, behind captures, with the same `supersededParents` fold `captureCandidates` reads.
  [`weave.dart:728`](../../packages/core/lib/weave/weave.dart#L728)

**The Focus Chunk slot — eligibility by class, not size**

- The epic tier: checked after capture, before the empty-ring return, taking `epicCandidates`' own order directly.
  [`_chunkCandidateOf:589`](../../packages/core/lib/weave/weave.dart#L589)

- The chunk pool's admission: `size == focus || precedence == epic`.
  [`weave.dart:744`](../../packages/core/lib/weave/weave.dart#L744)

- The card's name, finally the step's own words.
  [`weave.dart:1049`](../../packages/core/lib/weave/weave.dart#L1049)

**Dormancy — a derivation from a row's absence, never a flag**

- The kind itself, on the existing item-act shape (AD-21's naming table, entry twenty-one).
  [`log_entry.dart:126`](../../packages/core/lib/log/log_entry.dart#L126)

- The kind's single sanctioned minter, naming the group's first landed fact as the stable id.
  [`scan_commands.dart:255`](../../packages/core/lib/commands/scan_commands.dart#L255)

- The activation fold: append order becomes the arbitration's own activation-order tie-break.
  [`session.dart:354`](../../packages/core/lib/weave/session.dart#L354)

- The scan channel's own append, after the fact loop, inside the same queued closure.
  [`scan_controller.dart:795`](../../lib/scan/scan_controller.dart#L795)

- The genesis channel's mirror, epoch-guarded through the tail.
  [`genesis_controller.dart:408`](../../lib/genesis/genesis_controller.dart#L408)

**The pins**

- The whole matrix, dormancy through rescue-vs-epic and capture-vs-epic precedence, and the review's own supersession fix.
  [`weave_test.dart:4172`](../../packages/core/test/weave_test.dart#L4172)

- The activation fold's own pins — insertion order, duplicates, disturbing no other fold.
  [`session_test.dart:660`](../../packages/core/test/session_test.dart#L660)

- The kind census, twenty-one, and the conversion pin.
  [`log_test.dart:586`](../../packages/core/test/log_test.dart#L586)

- The landing paths' own row assertions — one activation row, or none on a crashed landing.
  [`scan_controller_test.dart:824`](../../test/scan/scan_controller_test.dart#L824)

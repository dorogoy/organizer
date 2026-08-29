---
title: 'The 1-3-5 weave and the Focus Chunk slot'
type: 'feature'
created: '2026-08-29'
status: 'done'
review_loop_iteration: 1
baseline_commit: '5398987602f1bf10248957da6ed31191f574efbd'
context: []
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** Nothing composes the day. Catalogue, substrate and calendar exist, but no code turns them into today's work — no weave, no resolver, no read facade, no session lifecycle; the app boots to an empty home and the log holds only crash entries.

**Approach:** Add pure-Dart `core/weave` (the 1-3-5 composition and AD-20's single resolver), a read facade whose only work surface is `nextCard()`, pure command functions producing the session/card lifecycle rows, a `StorePort` read surface with validated record parsing, and shell lifecycle wiring (open → `app_opened` + `session_started` + first `card_dealt`; backgrounding → `session_ended`) as the catalogue loader's first consumer.

## Boundaries & Constraints

**Always:**
- Composition is a pure function of `(catalogue, pool facts, log, day, session)`; nothing derived is stored (AD-1). `core/weave` stays deterministic — no `Random`, wall-clock or `dart:io` (the purity check already guards).
- `core/weave` is the only code that may emit a deal; every other work source returns candidates with precedence (AD-20). 1.6's only candidate source is the shipped catalogue — zone precedence, `fondo`, captures, rescue and purge arrive in later stories as candidate providers.
- Shipped candidates are catalogue entries as `Origin.shipped` items (id = the permanent catalogue id) handed to the core as inert data, never materialized as `pool_facts` rows; `card_*` rows reference catalogue ids with `itemOrigin = shipped`.
- Slot eligibility: size `focus` AND cadence non-daily (daily focus is Baseline Upkeep and never occupies the slot — FR-12). The "3" draws from `maintenance`-size entries, the "5" from `instant`-size entries.
- Ties break by least-recently-dealt — recorded `card_dealt` instants, never-dealt first — then by stable id order; never id bit patterns (AD-3).
- Occupancy is once per domestic day: at most one focus `card_done`, and only `card_done` closes the slot. The day is the **dealing session's own day** — a session is the latest `session_started` with no matching `session_ended`, and one crossing 04:00 charges every `card_*` to its start day (AD-19). A skip re-resolves identity, leaves the slot open and consumes no rotation. `nextCard()` writes nothing; an unanswered card never produces a second `card_dealt`.
- Scaling: the chunk is composed only when bag ≥ 10 min and derived energy ≠ low; otherwise the day composes without the "1", silently — no debt, no mention (FR-7, FR-12, FR-4). Bag default 15 min is a named core constant; energy comes from `deriveLivePoolEnergy` (no observations → full). Scaling drops counts, never shrinks an estimate; upkeep and habits are never charged to the bag.
- `StorePort` gains ordered read snapshots returning inert records; a core-side boundary converts records to domain entries with shape validation — itemId/itemOrigin travel as a pair, `stack` only on `crash_recorded`, kind/payload consistency, unknown kinds tolerated and ignored (AD-23). This is 1-3's recorded deferred item landing here.
- Shell wiring follows `crash.dart`'s pattern exactly: the shell mints UUIDv7 + instant + offset and appends; the core decides content and never mints. `app_opened` on open; `session_started` — appending the session's first `card_dealt` — only when no session is open; `session_ended` on backgrounding.
- Facade: no function returns a collection of work items; derived signals are named as facts, never verbs (AD-6). `nextCard()` returns at most one card — id, size, resolved Spanish name, origin, per-size duration estimate (seconds). Any period arithmetic the weave needs lands on `Calendar`, never beside it (1-4's deferred rule). Mind the forbidden-vocabulary lint when naming the facade-shape test.

**Ask First:** None.

**Never:** No UI — no card widget, Dispenser or close surface (1.8–1.10); home stays `SizedBox.shrink`. No zone rotation, `fondo` fill, below-floor fallback, 🔴 rotation freeze, 28-deal test or curation timing (1.7); no capture/rescue/purge candidates or epic arbitration (later epics). No `energy_set` writer, Time Bag setter or settings surface (2.5/Epic 2). No new log kinds, no new ports (reads join `store_port.dart`; the two-file pin stands), no `pool_facts` writes, no new ARB keys, no new dependencies, no stored plan, counter or derived state of any kind.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|---------------|---------------------------|----------------|
| Fresh install | empty log, defaults (15 min, 🟢), 85-entry catalogue | composition 1+3+5; `session_started` appends the first `card_dealt` | N/A |
| Re-read without answer | `nextCard()` after a deal, no user act | same card, no second `card_dealt` | N/A |
| Tie, never dealt | two eligible same-size candidates, no `card_dealt` rows | stable id order decides | N/A |
| Skip on chunk | `card_skipped` on a focus card | next deal resolves a different candidate; slot open; no rotation consumed | N/A |
| `Hecho` on chunk | `card_done`, later deal same day | no second chunk that day; upkeep/habits only | N/A |
| Session crosses 04:00 | `session_started` 03:40, acts at 04:10 | `card_*` charged to the start day; crossed-into day's slot untouched | N/A |
| Scaling gate | bag 9 min, or derived energy low | composition has no chunk, silently; 🟡 changes nothing | N/A |
| Backgrounding | app lifecycle → backgrounded | `session_ended`; re-open starts a new session; a closed slot stays closed | N/A |
| Malformed log row | half item pair, `stack` on a non-crash kind, unknown kind | row excluded from derivations, composition never crashes | surfaced distinctly, never coerced |

</frozen-after-approval>

## Code Map

- `packages/core/lib/catalogue/catalogue.dart` -- `CatalogueEntry` :43, `Cadence` :26; the candidate source, name already resolved per entry.
- `packages/core/lib/pool/pool_fact.dart` -- `Origin` :14 (`shipped`), `Size` :33, `PoolFact` :50; shipped candidates reuse ids+origin, never rows.
- `packages/core/lib/log/log_entry.dart` -- all seven Epic-1 `LogKind`s exist :25-31; `ItemActEntry` :88 / `MomentEntry` :111 / `CrashEntry` :126 / `UnknownEntry` :143; `LogKind.parse` :46. Extend here with the validated record→entry conversion.
- `packages/core/lib/day/calendar.dart` -- `Calendar.dayOf` :198 (`[04:00, next 04:00)`); any period math the weave needs grows here.
- `packages/core/lib/energy/energy.dart` -- `deriveEnergyForLivePool` :55; day-scoped, defaults full.
- `packages/core/lib/ports/store_port.dart` -- two write methods :47-50; its doc :5-7 names 1.6 as the read surface's owner. `packages/core/test/ports_test.dart:30` pins two files — reads join `store_port.dart`.
- `lib/store/drift_store.dart` + `lib/store/substrate.drift` -- append mapping :15/:30; add ordered selects; the insert-only triggers :35-50 stay untouched.
- `lib/crash.dart:32-55` -- the legal shell-mint pattern (UUIDv7 + now + offset → record → port) the session wiring copies.
- `lib/catalogue/loader.dart` -- `loadEvergreenCatalogue` :34; its doc names the weave as first consumer — wire it now.
- `lib/main.dart` -- `home: SizedBox.shrink()` :39 stays; install lifecycle wiring beside the crash guard.
- `test/ui/crash_test.dart:7` -- `_RecordingStore implements StorePort` fake pattern for lifecycle tests; `test/catalogue/loader_test.dart:22` -- `_FakeBundle` for loader injection.
- `tool/check_forbidden_vocabulary.dart:42` -- nine banned tokens; applies to every new identifier.

## Tasks & Acceptance

**Execution:**
- [x] `packages/core/lib/log/log_entry.dart` -- add validated record→entry conversion (item pair, stack-only-on-crash, kind/payload consistency, unknown kinds → `UnknownEntry`) -- the read boundary 1.3 deferred to this story
- [x] `packages/core/lib/ports/store_port.dart` -- add ordered read snapshots (pool facts, log entries) as inert records -- derivations need replayable inputs
- [x] `packages/core/lib/weave/weave.dart` -- NEW: 1-3-5 composition with scaling gates, candidate model (catalogue → `Origin.shipped` items), the single resolver, `Card`, named bag/estimate/energy defaults
- [x] `packages/core/lib/weave/session.dart` -- NEW: session derivation, day attribution, slot occupancy, least-recently-dealt index (fold into `weave.dart` if separate files are artificial)
- [x] `packages/core/lib/facade/read_facade.dart` -- NEW: `nextCard()` returning at most one card; fact-named signals only; no collections of work items
- [x] `packages/core/lib/commands/session_commands.dart` -- NEW: pure commands returning the records to append for app-open, session-start (+first deal), done, skip, session-end
- [x] `lib/store/drift_store.dart` -- implement the read selects
- [x] `lib/session/session_controller.dart` -- NEW: `WidgetsBindingObserver` wiring — mints ids/instants like `crash.dart`, runs commands, loads the catalogue once
- [x] `lib/main.dart` -- install the session controller beside the crash guard
- [x] `packages/core/test/weave_test.dart` + `packages/core/test/session_test.dart` + `packages/core/test/session_commands_test.dart` -- NEW: pin every matrix row, both 04:00-crossing directions, determinism (same inputs → same composition), commands contracts, and read-purity (repeated `nextCard()` writes nothing)
- [x] `packages/core/test/facade_test.dart` -- NEW: pin the facade shape — single-card surface, no collection-returning function — without using banned tokens
- [x] `test/store/substrate_test.dart` -- extend (or add `read_test.dart`): append→read round-trip including a malformed row
- [x] `test/session/session_controller_test.dart` -- NEW: recording store + fake bundle; open→background→reopen cycle appends the exact lifecycle kinds, registration test, offset test

**Acceptance Criteria:**
- Given a pool, a log and a domestic day, when the day composes, then `core/weave` returns 1 Focus Chunk + 3 Micro-maintenance + 5 Instant Habits scaled to the defaults, and no plan is stored anywhere
- Given the read facade's surface, when inspected, then no function returns a collection of work items, `nextCard()` returns at most one card, and derived signals are named as facts
- Given app entry, when handled, then `app_opened` and `session_started` append, the session's first `card_dealt` is written with it, and backgrounding appends `session_ended`
- Given a dealt card never answered, when the surface renders again, then no second `card_dealt` exists
- Given a tie, when the resolver orders it, then least-recently-dealt then stable id decides, reading recorded act instants
- Given any future work source, when it offers work, then it returns candidates with precedence and `core/weave` stays the only deal emitter
- Given a chunk answered `Hecho`, when a further deal is requested that day, then no second chunk is dealt — occupancy is once per the dealing session's domestic day, closed only by `card_done`
- Given a skipped chunk, when the next deal resolves, then identity re-resolves, the slot stays open, no rotation is consumed
- Given a bag below 10 minutes, when the day composes, then it composes with no chunk, silently
- Given Baseline Upkeep that fits the chunk's size, when the slot resolves, then it never occupies it
- Given the completion gate, then `make check`, `make test-core` and `make gate` are green

### Review Findings

- [x] [Review][Patch] High: lifecycle handling was unserialized — overlapping transitions could both observe "no session open" and mint duplicate `session_started` + first `card_dealt`; all handling now flows through one in-flight queue [lib/session/session_controller.dart]
- [x] [Review][Patch] High: the composition root's wiring was verifiable by nothing — deleting the observer registration kept every test green; wiring extracted into injectable `installSessionController` (the crash guard's pattern) with a registration + launch-open test [lib/main.dart, lib/session/session_controller.dart]
- [x] [Review][Patch] High: `cardDone`/`cardSkipped` never checked the answered item against the open session's dealt-but-unanswered card — a duplicate Hecho appended a second `card_done` plus a bundled deal, and a Hecho naming a never-dealt focus id closed the day's slot; answers now require the exact (itemId, origin) match [packages/core/lib/commands/session_commands.dart]
- [x] [Review][Patch] Medium: a spurious launch-time `resumed` would double the cold-start `app_opened`; `resumed` now re-opens only after a real exit-foreground transition [lib/session/session_controller.dart]
- [x] [Review][Patch] Medium: event instants were minted after the catalogue load and log read; the instant is now captured at handler entry, before any awaits [lib/session/session_controller.dart]
- [x] [Review][Patch] Medium: a failed catalogue load was memoized, bricking session recording for the process lifetime; failures now clear the memo so the next event retries [lib/session/session_controller.dart]
- [x] [Review][Patch] Medium: `assert(_isMoment(kind))` in the record→entry conversion let an unmapped future kind silently become a `MomentEntry` with asserts stripped; the dispatch is now explicit with a distinct `unclassifiedKind` flaw (structural — unconstructible today) [packages/core/lib/log/log_entry.dart]
- [x] [Review][Patch] Medium: the rowid tie-break tests could not distinguish append order from id order (AD-3's banned reading stayed green); reverse-lexicographic same-instant tie tests added for both read snapshots [test/store/substrate_test.dart]
- [x] [Review][Patch] Medium: the nothing-left-to-deal guards were unexercised; exhausted-day fixtures now pin the bare session open and answer-only rows [packages/core/test/session_commands_test.dart]
- [x] [Review][Patch] Medium: end-of-session appends on hidden/detached were fire-and-forget; they now run awaited inside the serialized step — best-effort, no synchronous channel invented [lib/session/session_controller.dart]
- [x] [Review][Patch] Low: empty-string `itemId`/`stack` passed the boundary as valid; empty now counts as malformed [packages/core/lib/log/log_entry.dart]
- [x] [Review][Patch] Low: the 🟢 default was written at three call sites; one named `deriveLivePoolEnergy` seam is 2.5's single landing point [packages/core/lib/energy/energy.dart]
- [x] [Review][Patch] Low: `anchorDayOf` duplicated the walk's session-day rule; one shared `_chargedDayOf` [packages/core/lib/weave/session.dart]
- [x] [Review][Patch] Low: hand-built duplicate catalogue ids read last-wins in the walk; the map build now throws naming the id [packages/core/lib/weave/session.dart]
- [x] [Review][Patch] Low: the shell path never exercised a nonzero UTC offset; a 03:40-local open→deal test charges the session to the previous domestic day (Dart cannot force an artificial zone on `DateTime`, so the literal offset case is pinned in the core suite) [test/session/session_controller_test.dart, packages/core/test/session_test.dart]
- [ ] [Review][Defer] Batch atomicity and detach durability for lifecycle rows — recorded in _bmad-output/implementation-artifacts/deferred-work.md (transactional batch-append decision)
- [ ] [Review][Defer] composeDay/nextDeal policy unification — recorded in _bmad-output/implementation-artifacts/deferred-work.md (lands with 1.7's precedence restructure)
- [ ] [Review][Defer] Pool-read flaw surfacing symmetric with `LogRecordFlaw` — recorded in _bmad-output/implementation-artifacts/deferred-work.md (first pool writer / restore)
- [ ] [Review][Defer] Skip-on-upkeep draw-slot semantics — recorded in _bmad-output/implementation-artifacts/deferred-work.md (1.10 inherits)
- [ ] [Review][Reject] `nextCard` falling through to `nextDeal` when the unanswered card's id is absent from the catalogue — ids are permanent (AD-23, id-diff check) and the proposed fall-through would itself violate AD-3's unanswered-card rule
- [ ] [Review][Reject] Capping the chunk branch by the day's focus dealt count — AD-20 deliberately overrides FR-7's literal "dealt" with "answered Hecho", so a skip must leave the slot open to re-resolve
- [ ] [Review][Reject] `readPoolFacts` as speculative surface — the spec's port task names both snapshots; the port doc reserved reads for this story
- [ ] [Review][Reject] `composeDay` lacking a production caller — it is the composition AC's tested surface; the Dispenser (1.8) consumes `nextCard` by design

## Spec Change Log

- **2026-08-29 (Review Iteration 1):**
  - Updated energy derivation reference from `deriveEnergyForLivePool` to `deriveLivePoolEnergy`.
  - Qualified `deferred-work.md` citations to `_bmad-output/implementation-artifacts/deferred-work.md`.
  - Added explicit execution task entries for `session_commands_test.dart` and `session_controller_test.dart`.
  - Completed review loop across Adversarial, Edge-Case Hunter, Editorial Structure, and Prose lenses; all 14 review patches verified and gate passed.

## Design Notes

- **Shipped work is data, not rows.** Materializing 85 `pool_facts` would copy the asset into the store, bloat the export and force retirement derivations for curation that 1.7 handles by precedence instead. `card_*` rows carry catalogue ids with `Origin.shipped`, so the tie-break and rotation read the same id discipline captured items will use later.
- **Session attribution** is one ordered walk: entries in instant order; `session_started` opens, the matching `session_ended` closes; every `card_*` inside belongs to that session's start day (AD-19). Occupancy and the least-recently-dealt index fall out of the same walk.
- **Commands return records, not appends:** the core cannot mint ids or read the clock (AD-3/AD-5), so commands compute *what* to append — including the first deal, which needs the weave — and the shell does the minting and appending: the crash path's division of labour, generalized.
- **The ≤ 2 s cold start is a derivation property here** — the composition reads only the log slice its periods need; the surface timing assertion lands with 1.8's card.

## Verification

**Commands:**
- `devbox run -- make test-core` -- expected: green, including the new weave/session/facade/boundary suites
- `devbox run -- make check` -- expected: all registered checks green; nothing new to register
- `devbox run -- make gate` -- expected: `flutter test`, format check, analyze all green
- `devbox run -- flutter test test/session test/store` -- expected: new shell suites green

## Suggested Review Order

**The weave and the single resolver (AD-20)**

- The composition itself — pure 1-3-5 behind the scaling gates
  [`weave.dart:227`](../../packages/core/lib/weave/weave.dart#L227)

- The resolver — the only deal emitter; chunk-first while open and gated
  [`weave.dart:272`](../../packages/core/lib/weave/weave.dart#L272)

- The candidate model — catalogue entries as inert `Origin.shipped` items, daily focus excluded
  [`weave.dart:131`](../../packages/core/lib/weave/weave.dart#L131)

- The card 1.8 will render — a value type
  [`weave.dart:55`](../../packages/core/lib/weave/weave.dart#L55)

**The one log walk (AD-19)**

- Every session fact from a single ordered pass
  [`session.dart:89`](../../packages/core/lib/weave/session.dart#L89)

- The session-day rule, defined exactly once
  [`session.dart:63`](../../packages/core/lib/weave/session.dart#L63)

- Composing for the open session's own day
  [`session.dart:176`](../../packages/core/lib/weave/session.dart#L176)

**The read boundary (1.3's deferred item)**

- Validated record→entry conversion with distinct, non-coercing flaws
  [`log_entry.dart:213`](../../packages/core/lib/log/log_entry.dart#L213)

- The flaw vocabulary — half pairs, off-kind stacks, unclassified kinds
  [`log_entry.dart:165`](../../packages/core/lib/log/log_entry.dart#L165)

- Derivations consume accepted entries only
  [`log_entry.dart:296`](../../packages/core/lib/log/log_entry.dart#L296)

- The port's ordered read snapshots — inert records out
  [`store_port.dart:59`](../../packages/core/lib/ports/store_port.dart#L59)

**The commands (AD-3)**

- What the shell appends — content records, never minted here
  [`session_commands.dart:27`](../../packages/core/lib/commands/session_commands.dart#L27)

- `session_started` appends the session's first deal
  [`session_commands.dart:51`](../../packages/core/lib/commands/session_commands.dart#L51)

- Answers require the dealt-unanswered pair; the bundled deal sees its own answer
  [`session_commands.dart:136`](../../packages/core/lib/commands/session_commands.dart#L136)

**The facade (AD-6)**

- One function, at most one card, writes nothing
  [`read_facade.dart:22`](../../packages/core/lib/facade/read_facade.dart#L22)

**Shell wiring**

- Serialized lifecycle handling — no interleaved read→compute→append
  [`session_controller.dart:77`](../../lib/session/session_controller.dart#L77)

- The observer — re-open only after a real exit-foreground transition
  [`session_controller.dart:123`](../../lib/session/session_controller.dart#L123)

- Injectable bootstrap; `main()` stays declarative
  [`session_controller.dart:18`](../../lib/session/session_controller.dart#L18), [`main.dart:24`](../../lib/main.dart#L24)

- The read selects — replay order by instant then append sequence
  [`drift_store.dart:81`](../../lib/store/drift_store.dart#L81)

**Peripherals**

- The 🟢 seam 2.5 replaces in one place
  [`energy.dart:86`](../../packages/core/lib/energy/energy.dart#L86)

- Composition, scaling, slot semantics, ties, both 04:00 directions
  [`weave_test.dart:91`](../../packages/core/test/weave_test.dart#L91)

- Day attribution through stored offsets
  [`session_test.dart:65`](../../packages/core/test/session_test.dart#L65)

- Command contracts incl. the exhausted day and answer guards
  [`session_commands_test.dart:51`](../../packages/core/test/session_commands_test.dart#L51)

- The single-card shape pin
  [`facade_test.dart:171`](../../packages/core/test/facade_test.dart#L171)

- Append-order tie proofs for both snapshots
  [`substrate_test.dart:321`](../../test/store/substrate_test.dart#L321)

- Lifecycle wiring — launch open, background close, retry after asset failure
  [`session_controller_test.dart:1`](../../test/session/session_controller_test.dart#L1)

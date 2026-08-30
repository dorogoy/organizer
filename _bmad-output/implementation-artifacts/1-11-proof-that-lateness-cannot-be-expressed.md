---
title: 'Proof that lateness cannot be expressed'
type: 'chore'
created: '2026-08-30'
status: 'done'
review_loop_iteration: 1
baseline_commit: '5cbd529a4920499c2c4417972bbc65fc856e178f'
context: ['NFR9', 'FR-6', 'FR-13', 'FR-14', 'AD-1', 'AD-21', 'AD-25']
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** The no-overdue property (NFR9, §7) holds of the substrate by construction, but only parts of it are machine-checked: the identifier lint and the exact-column audit exist, while the derived read models' shapes, the single-minter property of `card_done`/`card_dealt`, a deferred Focus Chunk across the day boundary, and the seven-day absence at app level have no pin. The next person to touch the schema inherits promises, not proofs.

**Approach:** Proof-only story, zero production code. Freeze the exact field set of every persisted and derived shape by source-shape test; pin where the answer/deal kinds may be minted and that no rescheduling identifier exists; add the two missing behavioral proofs — a deferred Focus Chunk across the day boundary (core), and a seven-day absence at screen level (app) proving the opening writes and renders exactly what a normal day writes and renders.

## Boundaries & Constraints

**Always:**
- Shape freezes via source-scan tests (house precedent: `facade_test.dart` reads its own source). Extraction regexes may be naive — `dart format` (in the gate) is the stability guarantee. Each frozen list carries a one-line comment naming the property it protects; a failing freeze is a deliberate renegotiation, never a test to bend.
- Frozen lists must match today's code exactly (field sets enumerated in the Code Map).
- The mint/read pin asserts kind references in core lib: `card_done` and `card_dealt` minted only in `session_commands.dart`, read only in `weave/session.dart` (and defined in `log_entry.dart`) — no second minter, so no synthetic-completion writer can appear silently.
- The Silent-Rescheduler search is a masked-source scan (reusing `tool/check_core_purity.dart`'s `maskCommentsAndStrings`) of `lib/` + `packages/core/lib/` for identifier segments `reschedul`/`scheduler` — zero findings.
- Deferred-chunk core test: skip the dealt chunk on day N; compose day N+1 in the same week; assert the chunk slot is open, a chunk still composes, the deferred id re-deals within the run, and the gap between the days added zero log rows.
- Seven-day-absence screen test: seed one completed day (app_opened, session_started, card_dealt, card_done, session_ended) seven days before the fixed clock; launch; assert a TaskCard deals and the rows appended after launch are exactly the normal opening kinds; assert the visible furniture (buttons, chips, marker — task text excluded) is identical to a no-gap control launch in the same test.

**Ask First:** Any production-code edit the proofs seem to demand — a failing freeze means the schema changed, not that the proof should be loosened.

**Never:** No production-code changes in `lib/` or `packages/core/lib/`; no new `tool/` checks or Makefile targets (the forbidden-vocabulary lint already owns NFR9's identifier layer); no new log kinds, ARB keys or strings; no weakening or deletion of an existing test; no milestone-overdue assertion — that AC clause is vacuous until Epic Projects exist (Story 5.5 tests it for real) and is noted, not faked.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Behavior | Error Handling |
|----------|---------------|-------------------|-----------------|
| Shape freeze | source of the 11 frozen shapes | exact field lists match; any added/renamed field fails the named test | N/A |
| Mint/read distribution | core lib scan for `cardDone`/`cardDealt` kind references | minted only in `session_commands.dart`; reads only in `weave/session.dart`; definition in `log_entry.dart` | N/A |
| Rescheduler search | masked `lib/` + `packages/core/lib/` scan for `reschedul`/`scheduler` segments | zero findings | N/A |
| Deferred Focus Chunk | chunk dealt and skipped day N; compose day N+1 | slot open, a chunk composes, deferred id re-deals in-run, zero rows in the gap | N/A |
| 7-day absence (rows) | history completed 7 days before the clock; app launch | a card deals; appended rows are exactly the normal opening kinds, nothing gap-shaped | N/A |
| 7-day absence (screen) | same seed; rendered frame | exactly one TaskCard; furniture identical to the no-gap control | N/A |

</frozen-after-approval>

## Code Map

- `packages/core/lib/pool/pool_fact.dart:50-74` -- freeze `PoolFact` = {id, origin, size, instantUtcMicros, offsetSeconds}; doc :7-8 already states "no assignment to a future day"
- `packages/core/lib/log/log_entry.dart:22-160` -- seven known kinds :32-38; freeze base `LogEntry` {id, instantUtcMicros, offsetSeconds} + subtypes `ItemActEntry`{kind, itemId, itemOrigin}, `MomentEntry`{kind}, `CrashEntry`{kind, stack}, `UnknownEntry`{kind}
- `packages/core/lib/weave/session.dart:23-62` -- freeze `LogFacts` = {lastDealtInstantByItemId, focusSlotClosedDays, dealtCountsByDay, answeredItemIds, openSessionStart, dealtUnanswered}; walkLog :95-181; a skip never closes the slot :160-165
- `packages/core/lib/weave/weave.dart` -- freeze `Card` :69-117 = {id, size, name, origin, zone, estimateSeconds}; `DayComposition` :204-219 = {focus, maintenance, instantHabits}; `Candidate` :131-152 = {itemId, size, name, origin, zone, precedence}; composeDay :392-415
- `packages/core/lib/ports/store_port.dart:22-44` -- freeze DTOs `PoolFactRecord`, `LogEntryRecord` (field-identical to domain types)
- `packages/core/lib/commands/session_commands.dart:27-32` -- freeze `LogEntryContent` = {kind, itemId, itemOrigin, stack}; the only mint site of `card_done`/`card_dealt`
- `packages/core/lib/energy/energy.dart:34-38`, `packages/core/lib/curation/curation.dart:79-84` -- freeze `EnergyObservation`, `CurationObservation` (future-kind payloads, the remaining derived-input records)
- `packages/core/lib/catalogue/catalogue.dart:43-80` -- freeze `CatalogueEntry` = {id, size, cadence, zone, name} and `Catalogue` = {version, entries} — read models the 11-shape list missed
- `packages/core/lib/day/calendar.dart:49-103,111-151,162-198` -- freeze `Day` = {year, month, day, weekday, offsetSeconds, startUtcMicros, endUtcMicros}, `Week` = {monday, endUtcMicros}, `Season` = {kind, anchorYear, offsetSeconds, startUtcMicros, endUtcMicros} — `Day` is the most natural home of a date-only target field; AD-1 forbids it
- `lib/session/session_controller.dart:174-186`, `lib/dispenser/dispenser_controller.dart:108-174` -- the shell's only sanctioned `LogEntryRecord` construction sites (the `_appendAll`/append loops over core `LogEntryContent`); a third construction site is a candidate silent minter
- Source-scan precedents: `packages/core/test/facade_test.dart:171` (reads own source), `test/store/substrate_test.dart:476-508` (exact column sets), `packages/core/test/log_test.dart:23` (exactly seven kinds), source-ordering scans `test/dispenser/dispenser_controller_test.dart:434`
- Core fixtures: `packages/core/test/weave_test.dart` -- `_catalogue` :49, `_day` :125, entry builders :79-118, `chunkOn` loop pattern :359; the week-gap weave pin already exists at :822 (not duplicated here)
- App fixtures: `_RecordingStore`, `_FakeBundle`, `_fixedClock` (`DateTime.utc(2026, 8, 29, 12)`), `launchAndCommit` harness -- `test/ui/dispenser/dispenser_screen_test.dart:45,194,375,856`
- `tool/check_core_purity.dart:95` -- `maskCommentsAndStrings`, imported by app-level tests per the `test/tool/` precedent

## Tasks & Acceptance

**Execution:**
- [x] `packages/core/test/no_lateness_proof_test.dart` -- NEW: the 16 shape freezes (the 11 original shapes plus `CatalogueEntry`, `Catalogue`, `Day`, `Week`, `Season`) with exact field lists; an exhaustiveness pin that every top-level class and record typedef under core lib is either frozen or named in the test's own exemption list; the `cardDone`/`cardDealt` mint/read distribution pin extended to the `'card_done'`/`'card_dealt'` wire-name string literals; an enumeration pin that no known kind name contains assign/schedul/defer/plan/overdue/late/missed/due/postpon segments, with a non-empty registry guard
- [x] `packages/core/test/weave_test.dart` -- deferred-chunk-across-day-boundary test: skip the dealt chunk day N, compose day N+1 same week — slot open, chunk composes, deferred id re-deals in-run, and the day-6 deal crosses the week boundary to the next zone (the deferred target never carries over)
- [x] `test/no_lateness_proof_test.dart` -- NEW: masked scan of `lib/` + `packages/core/lib/` for `reschedul`/`scheduler`/`postpon` identifier segments, zero findings (FR-14 discharged by shape); plus the shell mint scan — `'card_done'`/`'card_dealt'` string literals appear nowhere in `lib/`, and `LogEntryRecord` is constructed only in the two sanctioned append sites; every scan guards against the vacuous pass (roots exist, a non-trivial number of files scanned)
- [x] `test/ui/dispenser/dispenser_screen_test.dart` -- 7-day absence: seeded completed day 7 days before `_fixedClock`; launch deals a TaskCard; appended rows are exactly the normal opening kinds; visible furniture equals the no-gap control launch (task text excluded); the census covers the whole widget tree (runtime types) plus every text bearer (`Text.data` and `RichText` plain text); the control's own appended rows are asserted too; the store is re-checked after `pumpAndSettle` (the UI writes nothing on render); both launches' deals resolve to catalogue entries of the same size (a chunk still leads the day)

### Review Findings

- [x] [Review][Loopback — iteration 1] Seven requirement-level gaps (11-of-16 shapes frozen, extractor blind to declaration forms, mint pin blind to wire literals and the shell, opt-in census, unasserted control rows, narrow segments, unpinned boundary) — spec amended via the Spec Change Log, code reverted and re-derived
- [x] [Review][Patch] Extractor still blind to uninitialized/record-typed/function-typed/multi-declarator/wrapped declarations (empirically probed) — rewritten walk + a `KitchenSink` self-test freezing every declaration form so the completeness claim is itself pinned [packages/core/test/no_lateness_proof_test.dart]
- [x] [Review][Patch] Exhaustiveness census saw only classes and record typedefs — extended to enum/mixin/extension/positional-typedef declarations keyed by (path, name); all nine core enums exempted with reasons under the dead-exemption guard [packages/core/test/no_lateness_proof_test.dart]
- [x] [Review][Patch] Mint census file-granular, constant-idiom and store-module paths unguarded — exact per-file call-site counts + tear-off counting; `LogKind.card*` identifier census over `lib/` pinning the sanctioned command invocations (the zero premise was false — reality pinned instead); wire ban widened to all card+moment kinds; `LogEntriesCompanion` census inside `lib/store/`; zero `appendPoolFact` call sites in `lib/` [test/no_lateness_proof_test.dart]
- [x] [Review][Patch] Census missed Tooltip/Semantics/EditableText/Icon channels; gap-vs-control comparison unsound (different exclusions, unrelatable deals) — channels added, `gapDeal.itemId == controlDeal.itemId` asserted with one shared exclusion [test/ui/dispenser/dispenser_screen_test.dart]
- [x] [Review][Patch] Segment seams and Spanish blind spot — masked scan extended (overdue/missed/defer/assign + atrasad/vencid/aplazad/retras, each verified zero; `plan` dropped — trips on Spanish *planta*; `late`/`due` omitted with documented reasons); `dealOn` null-checks now carry run-day reasons [test/no_lateness_proof_test.dart, packages/core/test/weave_test.dart]
- [ ] [Review][Defer] A deferral crossing the 04:00 domestic boundary (pre-04:00 vs post-04:00 deferral, session spanning 04:00 holding a deferred chunk) — the 04:00 slot/charging semantics are already pinned in session/weave suites; the deferral-specific variant recorded in deferred-work.md
- [ ] [Review][Reject] Reusing `identifierIsBanned` for the masked scan — substring false positives (e.g. a future `SchedulerBinding`) fail loud and force renegotiation, which is the freeze's philosophy; single-sourcing the helpers triplicated across the two proof files — local duplication stays loud per the 1-7/1-8/1-9 repo precedent

**Acceptance Criteria:**
- Given the whole persisted schema and every derived read model, when the freeze tests run, then each field set matches its frozen list exactly — any addition anywhere in the substrate surfaces as a named failure
- Given core lib, when kind references are scanned, then `card_done` and `card_dealt` are minted in exactly one file — no second minter and no synthetic-completion writer can appear silently
- Given the codebase, when a masked search for a rescheduler is made, then none exists — nothing was assigned to a future day
- Given a dealt-then-skipped chunk on day N, when day N+1 composes, then the slot is open, a chunk composes, and the deferred id is simply a candidate again
- Given a 7-day absence, when the app next opens, then the day composes normally with the normal opening rows and the normal card furniture — no element or string references the missed days
- Given the completion gate, then `make check` and `make gate` are green

## Spec Change Log

- **[Iteration 1 — bad_spec loopback, review findings 1-11]** Three review layers (blind, edge-case, verification-gap) converged on requirement-level gaps the Code Map and task boundaries should have carried. **Amended:** (1) the frozen-shape inventory grows from 11 to 16 — `CatalogueEntry`, `Catalogue`, `Day`, `Week`, `Season` were derived shapes the enumeration missed — and gains an exhaustiveness pin so a new shape cannot be born unfrozen; (2) the extractor now has a completeness requirement (see Design Notes): naivety about formatting is allowed, blindness to declaration forms is not — a `final Map<String, int> missedDays = {}` must fail the freeze; (3) the single-minter pin extends to wire-name string literals and to the shell's `LogEntryRecord` construction sites; (4) the kind-name segment list grows to include the lint's own vocabulary (overdue, late, missed, due, postpon) with a non-empty registry guard; (5) the rescheduler scan adds `postpon` and vacuous-pass guards; (6) the furniture census becomes whole-tree (all runtime types + `RichText` plain text), the control launch's rows are asserted, the store is re-checked after settle, and both deals pin to the same catalogue size; (7) the deferred-chunk run pins the day-6 boundary crossing, and the vacuous `hasLength` assertion is dropped in favor of citing the facade no-write pin. **Known-bad state avoided:** proofs that pass while a generic-typed tally field, a wire-string minter, a `Text.rich` apology, or a `Day.dueDay` field lands silently — each demonstrated constructible by the reviewers. **KEEP (worked well, must survive re-derivation):** the dual-root `_libRoot` resolution (runs green under both `dart test` in packages/core and root `flutter test`); the mint-vs-read position assertions (`kind:` vs `==` counts); the two-launch control comparison in one screen test; `seedRow` deriving the seed chunk from `nextDeal` itself; the `dealOn` loop; per-freeze comments naming the protected property.

## Design Notes

- **Source-scan freeze, not reflection:** the house already proves structure by reading source (`facade_test.dart:171`, the column audit, the ordering scans); mirrors are unavailable under `flutter test` AOT and the naive-regex fragility is bounded by `dart format` running in the same gate. The freeze's brittleness is the feature — the story's "so that" is precisely that the next schema-touch fails a named test.
- **Extractor completeness (the iteration-1 lesson):** the field extraction must catch every declaration form a field can take — `this.x` constructor parameters, initialized and uninitialized `final` fields of any type shape (lowercase primitives, generics, nullable), `late final`, mutable instance fields, and constructor initializer-list assignments. Naivety about whitespace and formatting is fine (the gate's `dart format` bounds it); blindness to a declaration style is a hole in the proof. The brace-range scan strips comments (line and block) before matching, and fails loudly on unbalanced braces rather than scanning to end-of-file.
- **Vacuous assertions are documentation posing as tests:** a pure function cannot mutate its input list, so asserting the caller's list length after `composeDay` proves nothing — the no-write property's real pins are the facade tests (`nextCard` writes nothing) and the screen-level store counts. Write assertions that can fail.
- **Census strength:** "no UI element or string references the missed days" is only as strong as the census is total — six named widget types plus `Text.data` misses `Text.rich`, icons and tooltips. The census is the whole widget tree's runtime types plus every text bearer's content.
- **Absence at weave level is already pinned** (`weave_test.dart:822`, a whole week with no session composes without catch-up); this story adds the vertical — the app opening — and does not re-pin the weave.
- **The milestone limb of the absence AC is vacuous** until Epic Projects exist; Story 5.5 tests the same property for real once buffers land. Recorded here so the pass is not mistaken for evidence about buffers.
- **No-strings limb discharged structurally:** the story adds no strings, the string-table audit owns key review, and the furniture-control assertion pins the rendered reality of an absence day.
- **Core tests sit outside `make gate`** (root `flutter test` discovers only `test/`; core runs via `make test-core`): a pre-existing property of the Makefile, recorded as deferred work — the completion gate for this story still executes the core proofs through the Verification section's explicit paths.

## Verification

**Commands:**
- `devbox run -- make check` -- expected: all nine tool checks + codegen-check green (no new tool check this story)
- `devbox run -- make gate` -- expected: test, format, analyze all green
- `devbox run -- make test-core` -- expected: core suites including the freezes and the deferred-chunk proof green (core sits outside `make gate` — see Design Notes)
- `devbox run -- flutter test test/no_lateness_proof_test.dart test/ui/dispenser/dispenser_screen_test.dart` -- expected: the shell scan and the absence proof green

## Suggested Review Order

**The freeze — the story's spine: every shape's exact field list, proven against its own source**

- The extractor rewritten for completeness: every declaration form, string-safe depth, alias refusal
  [`no_lateness_proof_test.dart:267`](../../packages/core/test/no_lateness_proof_test.dart#L267)

- The self-test that pins the extractor itself — every declaration form, including the traps
  [`no_lateness_proof_test.dart:469`](../../packages/core/test/no_lateness_proof_test.dart#L469)

- The 16 freezes, each with its protected-property comment
  [`no_lateness_proof_test.dart:533`](../../packages/core/test/no_lateness_proof_test.dart#L533)

- The exhaustiveness census: enums/mixins/extensions/typedefs keyed by (path, name), exemptions guarded
  [`no_lateness_proof_test.dart:744`](../../packages/core/test/no_lateness_proof_test.dart#L744)

- The single-minter pin: `kind:` positions mint, `==` positions read, wire literals quoted only in the definition
  [`no_lateness_proof_test.dart:584`](../../packages/core/test/no_lateness_proof_test.dart#L584)

**The behavioral proofs — deferral and absence**

- The deferred chunk across the boundary: slot open, re-deal in-week, next zone after the boundary
  [`weave_test.dart:386`](../../packages/core/test/weave_test.dart#L386)

- The seven-day absence: exact opening rows, whole-tree census vs a no-gap control, same deal by id
  [`dispenser_screen_test.dart:1872`](../../test/ui/dispenser/dispenser_screen_test.dart#L1872)

- The total census helper: runtime types, every text bearer, tooltips, semantics, icon codepoints
  [`dispenser_screen_test.dart:389`](../../test/ui/dispenser/dispenser_screen_test.dart#L389)

**The searches — FR-14 discharged by shape**

- The masked rescheduler scan plus the extended vocabulary (Spanish stems included, omissions documented)
  [`no_lateness_proof_test.dart:80`](../../test/no_lateness_proof_test.dart#L80)

- The shell mint census: exact append counts, `LogKind.card*` anchors, companion census, zero pool writes
  [`no_lateness_proof_test.dart:214`](../../test/no_lateness_proof_test.dart#L214)

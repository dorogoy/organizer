---
title: 'The insert-only substrate'
type: 'feature'
created: '2026-08-28'
status: 'done'
review_loop_iteration: 0
baseline_commit: '7d124eb64f803252a8864a908768129e1dae8d18'
context: []
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** The no-overdue guarantee currently rests on nothing — no persistence layer exists, and once one arrives, SQLite puts `UPDATE` and `DELETE` one keyword away on both tables (AD-2); the log vocabulary, id stamping and crash diagnostics also have no home yet.

**Approach:** Add the drift substrate — exactly two tables (task pool, event log) with database-level triggers declared in a `.drift` file that raise on `UPDATE`/`DELETE` — grow the core's `Store` port and `log`/`pool` vocabulary types, install the shell crash handler that appends `crash_recorded`, and add two `tool/` build-time checks (forbidden vocabulary, store seal) wired into `make check`.

## Boundaries & Constraints

**Always:**
- Exactly two tables, created by the initial migration (schemaVersion 1); each carries `.drift`-declared triggers raising on `UPDATE` and on `DELETE`. Stack: drift 2.34.3 + drift_flutter 0.3.1 + uuid 4.6.0 (deps in the **root** pubspec only; drift_dev/build_runner as dev deps).
- Every row on both tables carries a shell-minted UUIDv7 id, a UTC instant **plus the local offset in force**. Pool rows: origin (`shipped`/`manual`/`local`/`cloud`) + size (three-member 1-3-5 taxonomy enum — ~30 s, 2–3 min, 10–15 min — never free minutes). Log rows: kind +, where a pool item is referenced, that item's id and origin. **No date-only column, no owner column, no third table.**
- The log vocabulary holds this epic's kinds: `card_dealt`, `card_done`, `card_skipped`, `session_started`, `session_ended`, `app_opened`, `crash_recorded`. Unknown kinds are carried and skipped — never coerced, never fatal (AD-23).
- The crash payload is stack + timestamp (+ id/offset) **and nothing else** — structural: the entry type offers no other fields, so no task text, image path, prompt or URL can ride along. The handler is installed at startup, is the build's only diagnostics destination, and swallows its own write failures.
- `packages/core` stays pure (existing check enforces); adapters return inert DTOs, only the core constructs domain objects; the port grows **append-only** operations — reads wait for their first consumer (Story 1.6+).
- New `tool/` checks follow `tool/check_core_purity.dart`'s Finding/`file:line`/exit-1 pattern (its `maskCommentsAndStrings` is importable), register under the Makefile's `check` target, and carry suites under `test/tool/` with fixtures under `test/fixtures/`.
- Store seal: persistence-package imports (drift\*, sqlite3\*, sqflite\*, shared_preferences\*, plus a named denylist) are legal **only inside `lib/store/`**; anywhere else in `lib/`, `packages/core/`, `tool/`, `test/` fails the build. The allowlist is a named constant grown only by explicit decision.
- Forbidden-vocabulary check: segment-aware identifier scan (camelCase/snake_case split) so `translate`/`related` pass while `overdue`, `late`, `missed`, `pending`, `debt`, `streak`, `skippedCount`, `dueDate`, `backlog` fail; `Due` as a derived-fact suffix (`captureIsDue`, `warmReturnDue`) passes; strings and comments masked. Scope: `lib/`, `packages/core/lib`, `tool/`, `test/`.
- Toolchain additions (e.g. host `libsqlite3` for drift's in-memory tests) go through `devbox.json` + re-lock in the same pass.

**Ask First:** None.

**Never:** No mutable replayable store (no preferences, side files, second database); no update/delete helpers anywhere — the database itself refuses; no owner or date-only columns; no reads or collections added to the port speculatively; no flutter/drift import in core; no logging/print channel beside the crash entry; no user-facing strings (no ARB changes).

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| UPDATE on either table | Row exists; update attempted from any path | Statement raises; row unchanged | N/A |
| DELETE on either table | Row exists; delete attempted | Statement raises; row unchanged | N/A |
| Unknown log kind read back | Row written with kind `future_kind` | Parses to an unknown-kind entry; derivations skip it; nothing throws | N/A |
| Uncaught Flutter/platform error | Throw during build or in a zone | Exactly one `crash_recorded` appended: stack + timestamp only | Store write failure swallowed; handler never re-throws |
| Fresh install, first open | Empty database | Migration leaves exactly two tables and the four triggers | N/A |
| Persistence import outside `lib/store/` | e.g. drift import under `lib/ui/` | `make check` fails, names `file:line` | N/A |
| Banned identifier | `int skippedCount = 0;` in scope | `make check` fails, names `file:line` | N/A |
| Innocent identifier | `translate`, `related`, `captureIsDue` | Pass | N/A |

</frozen-after-approval>

## Code Map

- `packages/core/lib/ports/store_port.dart` -- sealed empty `StorePort`, doc says it grows with Story 1.3; grow **in-file** so `packages/core/test/ports_test.dart`'s exactly-two-files pin stays true.
- `packages/core/lib/log/`, `packages/core/lib/pool/` -- NEW vocabulary and pool-fact types (pure Dart, no annotations).
- `lib/store/` -- NEW adapter module (spine L343: "drift schema, .drift triggers, migrations"); `DriftStore implements StorePort`; the only module where persistence APIs are legal.
- `lib/main.dart:8-31` -- `ProviderScope` + `MaterialApp`; crash guard installs here, before `runApp`.
- `tool/check_core_purity.dart:8-17,95-265` -- Finding contract + mask both new checks copy (`check_text_scaling.dart` shows the import pattern); `Makefile:42-46` (`check`) is the registration point, picked up by CI.
- `tool/check_no_literal_strings.dart:189,199` -- generated-code exemption; must cover drift's generated outputs (`*.g.dart` / `*.drift.dart`) or `make check` fails on generated SQL literals.
- `test/tool/check_core_purity_test.dart` + `test/fixtures/core_purity/` -- the check-test + fixture pattern to follow.
- `ARCHITECTURE-SPINE.md` -- AD-2 (L46), AD-21 (L182), AD-23 (L194); conventions L225-231 (log naming, forbidden vocabulary, ids, time); stack L255 (drift versions, triggers-in-`.drift`).
- `pubspec.yaml` (root) -- deps land here; `packages/core/pubspec.yaml` stays drift-free (already enforced at three layers).

## Tasks & Acceptance

**Execution:**
- [x] `pubspec.yaml` -- add `drift` 2.34.3, `drift_flutter` 0.3.1, `uuid` 4.6.0; dev: `drift_dev`, `build_runner` -- substrate deps, root only
- [x] `packages/core/lib/log/log_entry.dart` -- `LogEntry` + `LogKind` with this epic's kinds and an unknown-kind carrier -- the vocabulary (AD-21, AD-23)
- [x] `packages/core/lib/pool/pool_fact.dart` -- `PoolFact` + `Origin` (4 values) + `Size` (3 taxonomy values) -- pool-fact contract (AD-14)
- [x] `packages/core/lib/ports/store_port.dart` -- grow in-file: inert record DTOs (primitives/enums) + `appendPoolFact`/`appendLogEntry` -- the port's first real surface, append-only
- [x] `lib/store/` (schema `.drift` + `DriftStore` + generated code) -- two tables: text UUIDv7 PK, instant + offset columns, nullable item id + origin on the log; UPDATE/DELETE triggers per table declared in the `.drift` file; schemaVersion 1, `onCreate` installs everything
- [x] `lib/crash.dart` + `lib/main.dart` -- install `FlutterError.onError` + `PlatformDispatcher.instance.onError`; build the `crash_recorded` entry (uuid-minted id, `DateTime.now()` + offset — shell may read the clock); append via the store port; try/catch swallow; wire `DriftStore` (driftDatabase) before `runApp`
- [x] `test/store/substrate_test.dart` -- in-memory `NativeDatabase`: inserts succeed; UPDATE/DELETE raise and leave rows unchanged on both tables; exactly two tables; triggers present post-migration; column audit (no owner, no date-only)
- [x] `packages/core/test/log_test.dart` + `pool_fact_test.dart` -- vocabulary membership; unknown kind carried and skipped; enum shape
- [x] `test/ui/crash_test.dart` -- handler output is exactly stack + timestamp; write failure swallowed
- [x] `tool/check_forbidden_vocabulary.dart` + Makefile wiring + `test/tool/` suite + fixtures -- NFR9's lint
- [x] `tool/check_store_seal.dart` + Makefile wiring + `test/tool/` suite + fixtures -- AD-21's seal
- [x] `tool/check_no_literal_strings.dart` -- extend the generated-file exemption to drift's generated outputs

**Acceptance Criteria:**
- Given the initial migration has run, then exactly two tables exist and each carries UPDATE and DELETE triggers declared in a `.drift` file
- Given an `UPDATE` or `DELETE` attempted by any code path, then the statement raises and the row is unchanged
- Given a pool fact insert, then it carries a shell-minted UUIDv7 id, an origin, a taxonomy size, and its creation instant plus the local offset in force
- Given a log entry referencing a pool item, then it carries its kind, instant plus offset, and that item's origin
- Given an uncaught Flutter or platform error, then one `crash_recorded` entry is appended carrying the stack and timestamp and nothing else, via a startup-installed handler that is the only diagnostics destination
- Given a derivation meeting an unknown log kind, then it skips that entry and continues
- Given any identifier in scope, then the forbidden-vocabulary check fails on the nine banned tokens and permits the `Due` derived-fact suffix
- Given either table's columns, then neither carries an owner column
- Given a persistence API call outside `lib/store/`, then the store seal fails the build

### Review Findings

- [x] [Review][Patch] High: ALL-CAPS identifiers evade the forbidden-vocabulary segmentation (`PENDING_QUEUE` split into single letters) [tool/check_forbidden_vocabulary.dart:70]
- [x] [Review][Patch] Medium: the `PlatformDispatcher.instance.onError` half of the crash guard had no test [test/ui/crash_test.dart]
- [x] [Review][Patch] Medium: the crash-shaped production write (stack + null item pair) never round-tripped the real `DriftStore` [test/store/substrate_test.dart]
- [x] [Review][Patch] Medium: the amended `check_no_literal_strings` exemption logic (marker gate, named-constant allowance) shipped untested [test/tool/check_no_literal_strings_test.dart]
- [x] [Review][Patch] Low: trigger tests accepted any exception (`throwsA(anything)`); now pin `SqliteException` + the AD-2 refusal message [test/store/substrate_test.dart]
- [x] [Review][Patch] Low: DST window in the crash offset assertion; orphaned doc comment; non-banned `queuedItems` fixture; vacuous pass when no scope root exists; wrapped-declaration allowance lookup; no-FK/no-CHECK and seal-scope decisions undocumented [tool/check_forbidden_vocabulary.dart, tool/check_store_seal.dart, tool/check_no_literal_strings.dart, lib/store/substrate.drift, test/fixtures/forbidden_vocabulary/banned.dart]
- [ ] [Review][Defer] Log-record shape validation (item pair, stack-only-on-crash, kind-subtype consistency) belongs to the 1.6 read/parse boundary — recorded in `deferred-work.md`
- [x] [Review][Reject] Exception message in the crash payload (AD-12 forbids anything beyond stack + timestamp); FK/CHECK constraints (break AD-23 import tolerance); provider wiring for `DriftStore` (no consumer until 1.6); `main()` bootstrap-seam refactor (guard itself is tested; wiring is four reviewable lines)
- [x] [Review][Patch] `INSERT OR REPLACE` can rewrite an existing row without firing the DELETE refusal trigger [lib/store/substrate.drift:17]
- [x] [Review][Patch] Public drift database APIs let code outside `lib/store/` issue raw persistence calls without tripping the store seal [lib/store/substrate.dart:16]
- [x] [Review][Patch] A Flutter error with no supplied stack writes a `crash_recorded` entry without its required stack payload [lib/crash.dart:15]
- [x] [Review][Patch] Forbidden-vocabulary identifiers can evade a banned token by appending digits [tool/check_forbidden_vocabulary.dart:60]
- [x] [Review][Patch] Forbidden-vocabulary scan treats directive URIs as identifiers despite its strings-masked contract [tool/check_forbidden_vocabulary.dart:141]
- [x] [Review][Patch] Both source checks exclude any directory named `fixtures`, including valid production paths under `lib/` [tool/check_forbidden_vocabulary.dart:168]
- [x] [Review][Patch] Store-seal directives must begin a physical line, so valid same-line imports can bypass the check [tool/check_store_seal.dart:75]

## Spec Change Log

## Design Notes

- **Append-only port, on purpose.** Reads (log/pool snapshots) arrive with their first consumer — weave (1.6) and export (9.x); a speculative read surface now would invite the collection-shaped reads AD-6 exists to prevent.
- **Only `crash_recorded` gets a writer here.** `card_*`, `session_*` and `app_opened` are vocabulary-only until their surfaces exist (1.8+).
- **Instant + offset storage format is the implementer's** (e.g. epoch-µs + offset-seconds ints, or ISO-8601 text) as long as both components are stored and no bare-date column appears.
- **Migration mechanism vs outcome:** if drift's `Migrator.createAll()` does not install `.drift`-declared triggers, `onCreate` issues them explicitly; the test pins the outcome (triggers exist after first open), not the mechanism.
- **uuid v7 monotonicity is not relied on** — conventions forbid ordering by id bits; ordering reads recorded act instants.
- If the devbox shell lacks `libsqlite3` for host-side drift tests, add nixpkgs `sqlite` to `devbox.json` and re-commit the lock in the same pass. `drift_flutter` already brings `sqlite3_flutter_libs` for Android.
- **`Size` members are named `instant` / `maintenance` / `focus`** (Instant Habit "5", Micro-maintenance "3", Focus Chunk size "1"), not by the composition digits — the first draft's `one`/`three`/`five` inverted the PRD's numbering (Focus Chunk *is* the "1"); semantic names cannot be re-inverted by a later reader.
- **Store-seal allowlist also carries `test/store/`** — the adapter's own in-memory drift tests exercise the substrate and are part of its surface; recorded as an explicit entry in the named constant, not a wildcard. `check_no_literal_strings` likewise gained two named infrastructure constants (`substrateSchemaFile`, `substrateFileName`) on the tokens.dart pattern — file references, never widget copy.
- **Review round 1 resolutions recorded:** the crash payload deliberately omits the exception message (AD-12's "stack and timestamp and nothing else" is the contract — a message could carry a path); no provider exposes `DriftStore` yet (no consumer exists until 1.6; wiring one now would be the speculative surface the spec forbids), and drift's connection is lazy, so nothing can throw in `main()` before the guard is installed; no FK/CHECK constraints in the schema (recorded in `substrate.drift`) because they would reject AD-23's forward-only import tolerance — record-shape validation is deferred to the 1.6 read/parse boundary (see `deferred-work.md`). The `Size` taxonomy's semantic member names and the ALL-CAPS-safe forbidden-vocabulary segmentation are pinned by tests.

## Verification

**Commands:**
- `devbox run -- make check` -- expected: six checks green (four existing + forbidden vocabulary + store seal)
- `devbox run -- make gate` -- expected: `flutter test`, `dart format --set-exit-if-changed .`, `flutter analyze` all green
- `devbox run -- make test-core` -- expected: core suite green incl. the new vocabulary/pool tests
- `devbox run -- flutter test test/store/substrate_test.dart` -- expected: both tables refuse rewrite; schema audit passes

## Suggested Review Order

**The database's own refusal (AD-2) — start here, the story's core guarantee**

- Two tables, four `RAISE(ABORT)` triggers, no FK/CHECK by AD-23 design — the whole substrate in 50 lines of SQL
  [`substrate.drift:10`](../../lib/store/substrate.drift#L10)

- `schemaVersion` 1; `createAll()` installs the `.drift`-declared triggers in the initial migration
  [`substrate.dart:16`](../../lib/store/substrate.dart#L16)

- The adapter: append-only by construction, no update/delete method exists to reach for
  [`drift_store.dart:9`](../../lib/store/drift_store.dart#L9)

**The core vocabulary (AD-21, AD-23, AD-14)**

- `LogKind`: the epic's seven kinds plus the unknown-kind carrier every forward-only reader tolerates
  [`log_entry.dart:15`](../../packages/core/lib/log/log_entry.dart#L15)

- Sealed entry shapes — `CrashEntry` offers stack + timestamp and structurally nothing else
  [`log_entry.dart:126`](../../packages/core/lib/log/log_entry.dart#L126)

- `Origin` (4 genesis paths) and `Size` (`instant`/`maintenance`/`focus` — semantic names, digits avoided)
  [`pool_fact.dart:14`](../../packages/core/lib/pool/pool_fact.dart#L14)

- The port's first real surface: inert records + two appends, reads deferred to 1.6
  [`store_port.dart:45`](../../packages/core/lib/ports/store_port.dart#L45)

**The diagnostics channel (AD-12, NFR13)**

- Both handlers installed at startup — the build's only diagnostics destination
  [`crash.dart:13`](../../lib/crash.dart#L13)

- The one production write: crash payload, id minted in shell, clock read in shell, failures swallowed
  [`crash.dart:28`](../../lib/crash.dart#L28)

- Substrate wired and guard installed before `runApp`
  [`main.dart:18`](../../lib/main.dart#L18)

**The two new build-time guards**

- Segment-aware identifier split — review round 1's high finding fixed: ALL-CAPS cannot evade
  [`check_forbidden_vocabulary.dart:60`](../../tool/check_forbidden_vocabulary.dart#L60)

- The store seal's allowlist: persistence imports legal only in `lib/store/` (+ the adapter's tests)
  [`check_store_seal.dart:31`](../../tool/check_store_seal.dart#L31)

- The literal-ban's new exemption surface: marker-gated generated files + two named infrastructure constants
  [`check_no_literal_strings.dart:39`](../../tool/check_no_literal_strings.dart#L39)

- Registration: all six checks reachable from `make check`
  [`Makefile:42`](../../Makefile#L42)

**Peripherals**

- libsqlite3 resolved from the devbox package — deterministic loader path for drift's host tests
  [`env.sh:61`](../../tool/env.sh#L61)

- Trigger refusal pinned to `SqliteException` + the AD-2 message; crash-shaped write round-trips
  [`substrate_test.dart:117`](../../test/store/substrate_test.dart#L117)

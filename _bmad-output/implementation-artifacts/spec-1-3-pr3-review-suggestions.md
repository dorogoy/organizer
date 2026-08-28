---
title: 'PR 3 review suggestions — guard symmetry, per-connection pragma, codegen freshness'
type: 'chore'
created: '2026-08-29'
status: 'done'
review_loop_iteration: 0
baseline_commit: 'b0778f3d660d63512a8898a24341a9ecefa60599'
context: []
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** The Goose review on PR 3 left five accepted-worthy notes: the forbidden-vocabulary guard scans `packages/core/lib` but not `packages/core/test` (asymmetric with the store seal); `PRAGMA recursive_triggers` is applied once per database open instead of per underlying connection (a future pooled/parallel setup would reopen rows to silent `INSERT OR REPLACE` rewrites); the crash guard's fire-and-forget durability trade-off is undocumented; `main()` is `async` for no reason; and nothing fails a stale `substrate.g.dart` against `substrate.drift`.

**Approach:** Widen the vocabulary guard's scope by one root, move the pragma to a per-connection `setup` callback while keeping `beforeOpen`, add the two one-line documentation notes, drop the needless `async`, and register a `make codegen-check` target in the Makefile and CI.

## Boundaries & Constraints

**Always:**
- Both source guards end symmetric over `packages/core` — the vocabulary scan covers `lib/`, `packages/core/lib`, `packages/core/test`, `tool/`, `test/`.
- The pragma must run on **every** underlying native connection: `driftDatabase(..., setup:)` in `lib/store/connection.dart` (top-level function — drift sends it across isolates; closures are unsendable) **and** the existing `beforeOpen` statement in `lib/store/substrate.dart` (covers any executor, including the tests' `NativeDatabase.memory()`). Both idempotent.
- `codegen-check` runs `build_runner build --delete-conflicting-outputs` and fails non-zero when `lib/store/substrate.g.dart` differs from the committed bytes; CI runs it right after `make deps`.

**Ask First:** None.

**Never:** No removal of the `beforeOpen` pragma; no new dependencies; no behavior change to insert-only refusals, the crash channel, or any check's finding format; no re-opening of the story's frozen intent.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Banned identifier in a core test | `lateSession` in `packages/core/test/**` of a fixture tree | Executable exits 1, names `file:line` | N/A |
| Repo's own core tests scanned | `make check` after scope widening | Passes — no banned identifiers exist there today | N/A |
| Stale generated schema | Edit `substrate.drift`, skip build_runner | `make codegen-check` exits non-zero naming `substrate.g.dart` | N/A |
| Fresh generated schema | Committed `substrate.g.dart` up to date | Exit 0, no tree modification | N/A |
| Unrelated work-in-progress in tree | Other files modified, generated file fresh | `codegen-check` exits 0 (diff scoped to the generated file only) | N/A |

</frozen-after-approval>

## Code Map

- `tool/check_forbidden_vocabulary.dart:189` — `scopeRoots` constant; add `'packages/core/test'`.
- `test/tool/check_forbidden_vocabulary_test.dart:172` — executable fixture group; add a core-test-scope case beside `test/fixtures is excluded`.
- `lib/store/connection.dart:12` — `connectSubstrate()`; add `setup:` argument + top-level `_configureConnection`; import the pragma constant from `substrate.dart`.
- `lib/store/substrate.dart:33` — `beforeOpen` keeps its pragma; extend the constant's doc to name both layers.
- `lib/crash.dart:13` — `installCrashGuard` doc; add the fire-and-forget/lost-entry trade-off line.
- `lib/main.dart:11` — `Future<void> main() async` → `void main()`.
- `Makefile:42` — `check` target; add `codegen-check` target + `.PHONY` entry, mirroring the env-sourcing pattern.
- `.github/workflows/ci.yml:18` — insert `devbox run -- make codegen-check` after `make deps`.
- `_bmad-output/implementation-artifacts/1-3-the-insert-only-substrate.md:115` — Verification section; add the `codegen-check` command.
- `/home/sergio/.pub-cache/hosted/pub.dev/drift_flutter-0.3.1/lib/src/native.dart:158` — evidence: `setup` is forwarded to every `NativeDatabase` the isolate opens.

## Tasks & Acceptance

**Execution:**
- [x] `tool/check_forbidden_vocabulary.dart` — add `'packages/core/test'` to `scopeRoots` — guard symmetry with the store seal
- [x] `test/tool/check_forbidden_vocabulary_test.dart` — executable test: a banned identifier under `packages/core/test/` of a fixture root exits 1 — pins the widened scope
- [x] `lib/store/connection.dart` — pass `setup: _configureConnection` executing the pragma; document the per-connection guarantee — closes the pooled-connection loophole
- [x] `lib/store/substrate.dart` — extend the pragma constant's doc: `beforeOpen` + `setup` are the two idempotent layers — records the assumption
- [x] `lib/crash.dart` — doc line on `installCrashGuard`: fire-and-forget may drop the entry on hard process death; blocking the error path is worse — decision, not surprise
- [x] `lib/main.dart` — `void main()` — needless async
- [x] `Makefile` + `.github/workflows/ci.yml` — `codegen-check` target (build_runner + scoped `git diff --exit-code` on `substrate.g.dart`), CI step after `deps` — stale-schema tripwire
- [x] `1-3-the-insert-only-substrate.md` — add `devbox run -- make codegen-check` to Verification — the story documents its new check

**Acceptance Criteria:**
- Given `make check` after the change, then the vocabulary scan covers `packages/core/test` and the repo passes clean.
- Given a fixture tree with a banned identifier only under `packages/core/test/`, then the vocabulary executable exits 1 naming that file and line.
- Given `connectSubstrate()`, then the setup callback is a top-level function executing `PRAGMA recursive_triggers = ON`, and `beforeOpen` still executes it.
- Given a deliberately stale `substrate.g.dart`, then `make codegen-check` fails non-zero; with the committed file, it passes without touching the tree.

## Spec Change Log

## Design Notes

- The `setup` callback must be a top-level (or static) function: drift_flutter sends `DriftNativeOptions.setup` across isolates when spawning the database host (`native.dart:158`), and closures cannot cross isolate boundaries. A closure here would crash at startup, not at analysis time.
- `beforeOpen` is kept, not replaced: the unit tests construct `SubstrateDatabase(NativeDatabase.memory())` directly, bypassing `driftDatabase`'s options entirely — the INSERT OR REPLACE regression tests pin the refusal through exactly that path. Two idempotent applications of the same PRAGMA are harmless; one missing layer is the bug this closes.
- `codegen-check` diffs only `lib/store/substrate.g.dart` (not the whole tree) so a developer's unrelated uncommitted work never produces a false failure. build_runner output is deterministic (no timestamps), so a clean run diffs empty.

## Verification

**Commands:**
- `devbox run -- make check` -- expected: six checks green, vocabulary scan now covering `packages/core/test`
- `devbox run -- make codegen-check` -- expected: build_runner no-op, exit 0
- `devbox run -- make gate` -- expected: flutter test, format check, analyze green
- `devbox run -- flutter test test/store/substrate_test.dart` -- expected: INSERT OR REPLACE refusals still pinned

## Suggested Review Order

**The per-connection pragma (AD-2 hardening)**

- The setup callback drift sends to every native connection — top-level so it crosses isolates
  [`connection.dart:29`](../../lib/store/connection.dart#L29)

- Wired into the production host's native options
  [`connection.dart:37`](../../lib/store/connection.dart#L37)

- The other idempotent layer: `beforeOpen` covers any executor, tests included
  [`substrate.dart:37`](../../lib/store/substrate.dart#L37)

**The codegen freshness tripwire**

- The target: build_runner, then a HEAD-scoped diff with a pass/FAILED contract
  [`Makefile:51`](../../Makefile#L51)

- CI runs it right after deps, before the gate
  [`ci.yml:21`](../../.github/workflows/ci.yml#L21)

- Reachable from `make check` (NFR20's registration rule) — seven checks now
  [`Makefile:42`](../../Makefile#L42)

**Guard symmetry**

- `packages/core/test` joins the vocabulary scan's scope roots
  [`check_forbidden_vocabulary.dart:222`](../../tool/check_forbidden_vocabulary.dart#L222)

**Documentation as decisions**

- Fire-and-forget crash-write trade-off, stated at the guard
  [`crash.dart:14`](../../lib/crash.dart#L14)

- Both pragma layers named in the constant's doc
  [`substrate.dart:13`](../../lib/store/substrate.dart#L13)

- `main` is sync again — nothing awaited
  [`main.dart:9`](../../lib/main.dart#L9)

**Peripherals (pins and reviews)**

- Source-wiring pin: dropping `setup:` now fails the suite
  [`connection_wiring_test.dart:11`](../../test/store/connection_wiring_test.dart#L11)

- Executable pin: a banned identifier under `packages/core/test` exits 1
  [`check_forbidden_vocabulary_test.dart:195`](../../test/tool/check_forbidden_vocabulary_test.dart#L195)

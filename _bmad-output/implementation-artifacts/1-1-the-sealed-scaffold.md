# Story 1.1: The sealed scaffold

Status: ready-for-dev

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a builder,
I want the project to stand up as a pure-Dart core inside a Flutter shell with the core's purity enforced by a machine check,
so that every invariant the product rests on is checkable from the first commit instead of trusted to review.

## Acceptance Criteria

1. **Given** a fresh clone **When** `dart test` is run inside `packages/core` **Then** it executes with no emulator **And** no `flutter`, `drift` or plugin dependency is resolved for that package.
2. **Given** any file under `packages/core/lib/` **When** a commit adds an import of `package:flutter/…`, `drift` or any plugin **Then** the `tool/` core-purity check fails the build and **names the offending file** (AD-5).
3. **Given** any file under `packages/core/lib/` **When** a commit introduces `Random`, a wall-clock read, `dart:io` or ambient state **Then** the same check fails the build (AD-3, NFR16).
4. **Given** the port declarations **When** `packages/core/lib/ports/` is inspected **Then** exactly two ports exist — `Clock` and `Store` — each named with the `Port` suffix **And** no adapter type is named anywhere inside the core (AD-5).
5. **Given** the Android configuration **When** the app is assembled **Then** `minSdk` is 33, `targetSdk` is 36 **And** `abiFilters` excludes every 32-bit ABI (NFR12).
6. **Given** `pubspec.yaml` **When** its dependencies are read **Then** the environment's Flutter SDK is the latest stable patch of the 3.47 line (Dart 3.13.x) and the pinned versions of the Stack table are used **And** neither `material_ui` nor `cupertino_ui` is added.
7. **Given** the test strategy **When** it is set up **Then** core invariants run under `dart test` on the machine with no emulator; widget tests exist **only where a surface consumes the read facade or a command**; and **no golden tests are written** — visual and behavioural verification is manual on the three validation handsets (NFR18).
8. **Given** the repository root **When** it is listed **Then** a `Makefile` exists carrying every command needed to work on the app in development, and no development operation requires a remembered incantation (NFR20).
9. **Given** the `Makefile` **When** `make help` is run **Then** it lists every target with a one-line description, and it is the default target so a bare `make` is never destructive.
10. **Given** the `Makefile` **When** `make gate` is run **Then** it runs exactly `flutter test`, `dart format --set-exit-if-changed .` and `flutter analyze`, failing on the first that fails **And** it is the single command that answers NFR17's story completion gate.
11. **Given** the development loop **When** the targets available at this story are used **Then** `make deps`, `make test`, `make test-core` (pure `dart test` over the core, no emulator), `make format`, `make format-check`, `make analyze`, `make check` (the `tool/` checks that exist), `make run` and `make clean` all work.
12. **Given** CI **When** it verifies a commit **Then** it invokes the same `Makefile` targets rather than duplicating their command lines, so a green `make gate` locally means a green CI.
13. **Given** a later story that introduces a `tool/` check or a build-time guard **When** that story is complete **Then** its target is registered in the `Makefile` and reachable from `make check` in the same pass (NFR20).
14. **Given** the story is complete **When** the completion gate runs **Then** `flutter test`, `dart format --set-exit-if-changed .` and `flutter analyze` are all green (NFR17).
15. **Given** the repository root **When** `devbox shell` is entered and `flutter --version` / `java -version` are read **Then** the line-pinned Flutter SDK (3.47.x, Dart 3.13.x) and the current JDK LTS are on `PATH` from the devbox environment, `devbox.json` and `devbox.lock` are committed **And** that SDK is the official tarball of the 3.47 line — the nixpkgs `flutter` package is not used (NFR21).

## Tasks / Subtasks

- [ ] **Task 0 — Verify the toolchain inside devbox before writing anything** (AC: 6, 14, 15) — *see Blocking Environment Prerequisites; do not proceed past this task until the checks pass*
  - [ ] Devbox CLI present (`devbox version`; 0.18.0 verified on this machine). **Every check below and every later task runs inside `devbox shell`**, never against the host toolchain (NFR21).
  - [ ] Inside the shell, `flutter --version` reports the **latest stable patch of the 3.47 line** (Dart 3.13.x; 3.47.2 at the time of writing). Neither binary is on the host `PATH` today — the SDK arrives with Task 1's devbox environment. Do **not** jump lines (3.46, 3.48) and do **not** "fix" the pubspec to match an installed SDK. **Never `devbox add flutter`** — nixpkgs lags the line's patches (3.47.0 while stable is 3.47.2, 2026-08-27) and is not the official SDK.
  - [ ] Inside the shell, `java -version` reports a **current LTS — 21** (devbox `jdk21`), or **25** if the template's Gradle is 9.1+ (check `android/gradle/wrapper/gradle-wrapper.properties`; Gradle needed 9.1 for Java 25). 17 is the *minimum* the 3.47 toolchain verifies against, not a pin — the build JVM takes a current LTS, the emitted bytecode stays at 17 (Task 3), and a non-LTS (the host's 26) is never used. The host's JDK 26 is irrelevant inside the shell; set `org.gradle.java.home` or `flutter config --jdk-dir` only if Gradle still resolves the host JDK.
  - [ ] `make build` / `make run` additionally need Android SDK platform 36 — verify the devbox package that provides it (`devbox search android-sdk`) or expose an existing SDK via `ANDROID_HOME` in `devbox.json`. The gate itself needs no Android SDK.
  - [ ] If any of the above cannot be satisfied, **stop and report** — a story cannot be closed with the NFR17 gate unrun (`project-context.md`, `AGENTS.md` → Policy).

- [ ] **Task 1 — Create the devbox environment** (AC: 15)
  - [ ] `devbox.json` at the repository root: nixpkgs `jdk21` (the current LTS chosen in Task 0 — 25 if the template's Gradle is 9.1+; verify the attr with `devbox search jdk`, where plain `jdk` is JDK 8 and **must not be used**), `make`, `git`, and the Android SDK tooling verified in Task 0. **No `flutter` package** — nixpkgs lags the 3.47 line's patches and is not the official SDK; see *The devbox environment* in Dev Notes.
  - [ ] A bootstrap (a run-once-guarded devbox `init_hook`, or the first step of `make deps`) downloads the official `flutter_linux_3.47.x-stable.tar.xz` — the line's current stable patch — **verifies its sha256**, unpacks it under a gitignored `.toolchain/flutter/`, and puts `.toolchain/flutter/bin` on `PATH` inside the shell. `dart` 3.13.x ships inside that SDK — nothing pins it separately. A patch bump within the line is exactly two edited values here (version, sha256) plus a re-lock and the gate; nothing else changes.
  - [ ] Generate and **commit `devbox.json` and `devbox.lock`**; `.gitignore` (created here if Task 2 has not yet) gains `.toolchain/`.
  - [ ] Proof of AC 15: inside `devbox shell`, `flutter --version` → 3.47.x (the recorded patch) / Dart 3.13.x, `java -version` → the chosen LTS (21, or 25).
  - [ ] This file is the environment of record: a later story needing a toolchain piece adds it here and re-commits the lock in the same pass (NFR21), mirroring AC 13's Makefile rule.

- [ ] **Task 2 — Create the Flutter shell app at the repository root** (AC: 5, 6)
  - [ ] Inside `devbox shell`: `flutter create` into the existing repo root with `--platforms=android --org <reverse-dns>`, then **delete every generated artefact this story does not need**: the sample counter widget, the sample widget test, `README.md` boilerplate, iOS/web/desktop folders if any slipped in. Android only (SPEC Non-goals).
  - [ ] Do not touch `_bmad/`, `_bmad-output/`, `.claude/`, `.agents/`, `.opencode/`, `AGENTS.md`, `project-context.md`.
  - [ ] `pubspec.yaml`: `environment: sdk: ^3.13.0`; dependencies `flutter` (sdk) and `flutter_riverpod: 3.4.2` only; path dependency on `packages/core`. **Add nothing else** — see *Dependency scope ruling*.
  - [ ] Assert absence: neither `material_ui` nor `cupertino_ui` appears. `package:flutter/material.dart` still ships with the SDK and needs no dependency (Stack table).
  - [ ] `lib/main.dart`: root widget wrapped in `ProviderScope` (Riverpod is shell-only, Consistency Conventions → *State — Dart state management*). No surface, no strings — 1.2 owns tokens and the ARB, 1.8 owns the Dispenser.
  - [ ] `analysis_options.yaml` at the root (and one in `packages/core`), so `flutter analyze` and `dart analyze` have a configuration to read. Story 1.2's custom lints extend these files rather than replacing them.
  - [ ] `.gitignore` covering the Flutter/Dart/Gradle artefacts (`.dart_tool/`, `build/`, `.flutter-plugins*`, `android/.gradle/`, `*.iml`, `local.properties`). The repo has none today; without it the first `flutter pub get` stages generated files.

- [ ] **Task 3 — Configure Android to the stack** (AC: 5)
  - [ ] `android/app/build.gradle.kts`: `compileSdk = 36`, `targetSdk = 36`, `minSdk = 33`. Do not use `flutter.minSdkVersion`.
  - [ ] `ndk { abiFilters += listOf("arm64-v8a", "x86_64") }` — every 32-bit ABI excluded (`armeabi-v7a`, `x86`). This is also the 16 KB page-size condition and Story 5.1's ML Kit precondition (NFR12, Stack table → `google_mlkit_face_detection`).
  - [ ] Java 17 source/target compatibility and Kotlin jvmTarget 17 — this is the **bytecode** level, the stack's verified minimum, and it does not move when the build JVM is a newer LTS. Kotlin 2.4.0 comes from the Flutter Android template — do not pin it yourself (Stack table).
  - [ ] `AndroidManifest.xml`: **declare no permission at all in this story.** AD-17's three runtime permissions and `RECEIVE_BOOT_COMPLETED` arrive with their features. AD-7's manifest allowlist check (Epic 4) will read this file — an early speculative permission is a defect there.

- [ ] **Task 4 — Create `packages/core` as a separate, sealed, pure-Dart package** (AC: 1, 4)
  - [ ] `packages/core/pubspec.yaml`: `environment: sdk: ^3.13.0`; **no `flutter:` key, no `flutter` dependency, no `drift`, no plugin**. `dev_dependencies`: `test` and a lints package only.
  - [ ] Create the directory skeleton this story needs and no more: `packages/core/lib/ports/`. The remaining core directories (`day/`, `pool/`, `log/`, `weave/`, `derive/`, `export/`) arrive with their first consumer — 1.3 through 1.7. Do not pre-create empty folders.
  - [ ] `packages/core/lib/ports/clock_port.dart` → `abstract interface class ClockPort` returning an instant to the core. `packages/core/lib/ports/store_port.dart` → `abstract interface class StorePort`. `snake_case.dart` filenames, plain Dart types, **no annotations** (Consistency Conventions → *Naming — files & types*).
  - [ ] Both ports are declared here and consumed later; keep their surfaces minimal — a port grows with its consumer, and 1.3/1.4 own `StorePort`'s and `ClockPort`'s real shape.
  - [ ] **Exactly two ports.** The other five (`Slicer`, `Notifier`, `Recognizer`, `Folder`, `Files`) are named in the spine's Structural Seed but arrive with their first consumer (Epic 1 scope note). Declaring them now fails AC 4.
  - [ ] No adapter type name (`DriftStore`, `SafFolder`, `ByokSlicer`, …) appears anywhere in the core (AD-5).
  - [ ] `packages/core/test/` holds the core suite. Add one real test now so `make test-core` is not vacuous — e.g. asserting the ports package exports exactly the two port types.

- [ ] **Task 5 — Write the `tool/` core-purity check** (AC: 2, 3)
  - [ ] `tool/check_core_purity.dart` — a plain Dart script (no Flutter import; it must run under `dart run`). It walks `packages/core/lib/**.dart`.
  - [ ] **Import bans:** any `package:flutter/…`, `package:drift…`, `dart:io`, `dart:ui`, `dart:isolate`, and any package not declared in `packages/core/pubspec.yaml`'s `dependencies`. Deriving the allowlist from that pubspec — rather than hard-coding a plugin list — is what makes the check survive a future plugin nobody thought to name.
  - [ ] **Determinism bans (AD-3, NFR16):** `Random` (`dart:math`'s `Random`, including `Random.secure()`), `DateTime.now()`, `Stopwatch`, `Timer`, `clock.now()`, `Process`, `File`, `Directory`, and mutable top-level or static state (a non-`final`/non-`const` top-level variable or static field).
  - [ ] **Dependency-graph ban (AC 1):** additionally assert that `packages/core/pubspec.yaml` declares no `flutter` key and that its resolved dependency closure contains no `flutter`, `drift` or plugin package. A source-only scan misses a transitive pull-in; this closes it.
  - [ ] **Output contract:** on failure the script prints **the offending file path and the offending line**, one per finding, and exits non-zero. AC 2 says "names the offending file" — a bare non-zero exit fails the AC.
  - [ ] Register it in `make check`.

- [ ] **Task 6 — Prove the check works** (AC: 2, 3, 7, 14)
  - [ ] `test/tool/check_core_purity_test.dart` — a **plain Dart unit test** (no `flutter_test` widget harness) that runs the checker against fixture files under `test/fixtures/core_purity/`: a clean file (passes), a file importing `package:flutter/material.dart` (fails, names the file), a file using `DateTime.now()` (fails), a file with a mutable static (fails).
  - [ ] This test is deliberately **not** a widget test and **not** a golden test, so NFR18 holds; and it is what keeps `flutter test` green and non-vacuous at a story with no surfaces. See *Testing rulings*.

- [ ] **Task 7 — Write the root `Makefile`** (AC: 8, 9, 10, 11, 13)
  - [ ] `help` is the **first and default** target (`.DEFAULT_GOAL := help`), self-documenting from `##` comments on each target. A bare `make` prints help and changes nothing.
  - [ ] `gate` runs **exactly** `flutter test`, then `dart format --set-exit-if-changed .`, then `flutter analyze`, failing on the first failure. No extra commands, no reordering — this target *is* NFR17.
  - [ ] Targets that must work at this story: `deps`, `test`, `test-core`, `format`, `format-check`, `analyze`, `check`, `run`, `clean`, plus `help` and `gate`.
    - `test-core` = `cd packages/core && dart test` — pure Dart, **no emulator**.
    - `test` = `flutter test` (root shell suite).
    - `check` = the `tool/` checks that exist today: core purity, and nothing else.
    - `build` = `flutter build apk --debug`. Release signing is owed by Epic 9 under AD-18 and is not this story's.
  - [ ] Do **not** create `l10n`, `check-catalogue`, `check-egress` or any other target whose script does not exist — the epic scope note forbids invoking checks that do not exist yet. 1.2 registers `l10n`; 1.5 registers the catalogue checks; Epic 4 registers the egress seals.
  - [ ] Add a short header comment stating AC 13's rule verbatim, so the next story's agent registers its own target without needing to be told.
  - [ ] `PHONY` every target. No identifier in this file may use the forbidden vocabulary (NFR9).
  - [ ] The Makefile stays **plain** — no target wraps its commands in `devbox …`; the environment contract is devbox's ("inside `devbox shell`", NFR21). `make deps` may begin with Task 1's idempotent SDK-bootstrap check, and must be a no-op offline once the tarball is fetched.

- [ ] **Task 8 — CI that calls the Makefile through devbox** (AC: 12, 15)
  - [ ] `.github/workflows/ci.yml` — the remote is `github.com/dorogoy/organizer`, so GitHub Actions is the provider.
  - [ ] Steps: checkout → `jetify-com/devbox-install-action` (version-pinned) → `devbox run -- make deps` → `devbox run -- make gate` → `devbox run -- make check` → `devbox run -- make test-core`. **No `actions/setup-java`, no `subosito/flutter-action`** — the workflow resolves the same `devbox.lock` as every local machine, so local green means CI green at the toolchain level too, and CI becomes the regression test for `devbox.json` itself (NFR21).
  - [ ] Every step invokes a `make` target. **No workflow step may spell out `flutter test`, `dart format …` or `flutter analyze` directly** — duplicating a command line is what AC 12 forbids.

- [ ] **Task 9 — Run the completion gate** (AC: 14)
  - [ ] Inside `devbox shell`: `make gate` green — `flutter test`, `dart format --set-exit-if-changed .`, `flutter analyze`.
  - [ ] `make check` and `make test-core` green.
  - [ ] Record the exact resolved Flutter/Dart/Java versions **and the devbox version and lock hash** in the Completion Notes.

## Dev Notes

### Blocking environment prerequisites

Verified on this machine on 2026-08-27:

| Requirement | Required | Present | Action |
| --- | --- | --- | --- |
| Devbox | 0.18.0 verified | `/usr/local/bin/devbox` 0.18.0 | — |
| Flutter | 3.47.x — the line's latest stable patch (3.47.2 today) | **not on host `PATH`** | Task 1's bootstrap: sha256-pinned official tarball. **Never `devbox add flutter`** — nixpkgs lags the line (3.47.0) |
| Dart | 3.13.x (ships with Flutter) | **not on host `PATH`** | as above |
| JDK | **current LTS for the build JVM** — 21, or 25 if the template's Gradle is 9.1+; 17 is the *minimum*, not the pin; bytecode target stays 17 | host has **26.0.2** (non-LTS — never used) | devbox package `jdk21` / `jdk25` (Task 1) |
| Android SDK | compile/target **36** | unverified | devbox package (`devbox search android-sdk`) or `ANDROID_HOME`; needed by `make build` / `make run`, not by the gate |

The story completion gate (`flutter test`, `dart format --set-exit-if-changed .`, `flutter analyze`) cannot be run without the first two, and it runs **inside `devbox shell`** (NFR21). **Never present this story as done with the gate unrun** — that is the one policy in `AGENTS.md` and `project-context.md`.

### The devbox environment, and why the Flutter SDK is not a nix package

NFR21 makes devbox the environment of record: `devbox.json` plus a committed `devbox.lock` provision the JDK LTS, the Android SDK tooling and `make`; CI installs devbox and runs the same `make` targets through `devbox run --`. Devbox is development-time tooling only — nothing it manages ships inside the app, so AD-12's and NFR13's no-network-SDK rule is untouched.

The one thing devbox must **not** provide is the Flutter SDK. The Stack pins the **line**, not the patch — 3.47.x, latest stable patch — because patch releases are fixes this project wants, and freezing one patch forever would refuse them (3.47.2 shipped within two weeks of 3.47.0). But nixpkgs `flutter` sits at 3.47.0 (`devbox search flutter`, 2026-08-27; the nixhub web index lags further), so `devbox add flutter` would both freeze the line's oldest patch and substitute a derivation that is not the official SDK. Hence: the bootstrap fetches the official `flutter_linux_3.47.x-stable.tar.xz` — version and sha256 recorded in the repo — so every checkout is exact and reproducible while a patch bump remains a two-value edit, a re-lock and the gate. The JDK has no nixpkgs gap, but it has a policy trap the first draft fell into: 17 is the toolchain's **minimum**, and pinning to an aging minimum buys nothing — its premier support ends 2026-09. The build JVM is a **current LTS** (`jdk21` today; 25 once the template's Gradle is 9.1+, because Gradle needed 9.1 for Java 25), a non-LTS like the host's 26 is never used, and the **emitted bytecode stays at 17** (`sourceCompatibility` / `targetCompatibility`, Kotlin `jvmTarget`) so the desugaring surface is exactly what the stack verifies. Adopting a newer LTS is a routine bump — change the devbox package, re-lock, gate.

### What this story is, and what it is not

This is the greenfield scaffold. The repository today contains **only planning documents** — no `pubspec.yaml`, no `lib/`, no `android/`, no `Makefile`, no `devbox.json`, no CI. Every file in the task list is a **NEW** file; there is nothing to read for current-state behaviour and nothing to regress.

It is a scaffold story, **not a template clone** (this was checked explicitly in the epics' Step-4 validation record). Resist `flutter create`'s defaults: the sample counter app, its widget test and the multi-platform folders are all deleted, not kept.

### The paradigm this scaffold is built to make checkable

**Functional core / imperative shell, arranged as hexagonal ports & adapters.** The core is pure Dart with no Flutter, no drift and no plugin imports. It holds the whole product; it performs no I/O, reads no clock it was not handed, and returns no randomness. The shell is Flutter plus adapters and exists only to carry facts in and effects out.

That is not decoration. `§7`'s *"no field, flag or derived value anywhere may express lateness"* and P2's *"they count only what the user did, never what they didn't"* are statements about a **data substrate**; they hold or fail in the core, which is exercised with `dart test`, on the machine, with no emulator. **The purity check in Task 5 is the thing that keeps every later invariant checkable.** If it is weak, every AD in Epics 2–9 degrades to a review convention.

### Rulings this story makes, so no later story has to re-decide them

These are judgment calls the epic left open. They are settled here deliberately; a later story may extend them additively but should not reverse them without saying so.

1. **Dependency scope.** `pubspec.yaml` adds only what the scaffold needs to build and run: `flutter`, `flutter_riverpod: 3.4.2`, and the `packages/core` path dependency. AC 6's *"the pinned versions of the Stack table are used"* is a **conformance rule on whatever is added**, not an instruction to add the whole table. `drift` arrives in 1.3, `uuid` in 1.3, `flutter_localizations`/`gen_l10n` in 1.2, `camera`/`google_mlkit_face_detection` in Epic 5, `saf_util`/`saf_stream` in Epic 9. Adding them early would put unused plugins inside AD-7's Gradle allowlist scope before anything justifies them.
   - `flutter_riverpod` is included now, and the root wrapped in `ProviderScope`, so no later story re-plumbs the app root. It is the declared shell state manager (Consistency Conventions).
   - `flutter_lints` (or the SDK template's default lints package) is permitted as a dev dependency and is not a Stack-table omission — that table enumerates product dependencies, not analyzer configuration.

2. **Testing shape at a story with no surfaces.** NFR18 permits widget tests *only* where a surface consumes the read facade or a command; at 1.1 no such surface exists, so **no widget test is written**. `flutter test` must still be green and must not be vacuous, so the root suite holds Task 6's **plain Dart unit test of the purity checker itself**. This satisfies NFR18 exactly, keeps the gate meaningful, and verifies AC 2/AC 3 rather than asserting them.
   - Core tests live in `packages/core/test/`, run by `make test-core` under `dart test`.
   - Root `test/` holds shell-side tests, run by `make test` under `flutter test`.
   - **No golden tests, ever** (NFR18). Visual and behavioural verification is manual on the three validation handsets.

3. **CI provider = GitHub Actions**, from the configured remote `github.com/dorogoy/organizer`.

4. **`make build` = debug APK.** Release signing is AD-18's single-keystore ritual and belongs to Epic 9, where the export and import it drives actually land.

5. **The toolchain comes from devbox, not the host.** `devbox.json` + committed `devbox.lock` provision the JDK LTS, the Android SDK tooling and `make`; the Flutter SDK is the sha256-pinned official tarball of the 3.47.x line, never the nixpkgs `flutter` package (NFR21, see *The devbox environment*). This also settles CI mechanics inside ruling 3's provider: the workflow uses `jetify-com/devbox-install-action` and `devbox run -- make …`, so the runner resolves the identical lockfile — and CI doubles as the regression test for the environment of record.

### The two ports, and why only two

The spine's Structural Seed names seven ports — `Store`, `Slicer`, `Clock`, `Notifier`, `Recognizer`, `Folder`, `Files`. **Epic 1 declares only the two it consumes.** The remaining five arrive with their first consumer, per the create-only-what-the-story-needs principle stated in the epic's scope notes. AC 4 is written to fail if you declare more.

Two rules govern their shape, both from AD-5:
- **Ports end in `Port`;** adapters name their technology (`DriftStore`, `SafFolder`, `ByokSlicer`) and are never named inside the core.
- **Adapters return inert DTOs and never domain objects** — only the core constructs a pool item, a log event or a period. Without this, an adapter holding a Slicer response would tag origin by *how the data arrived* while the core tags it by *lineage*, and AD-14's inheritance rule would lose silently. Keep `StorePort` returning inert row shapes from the first line.

`ClockPort` exists because AD-3 forbids a wall-clock read inside the core and AD-4 makes `Calendar` (Story 1.4) the only instant→period conversion. The core never reads a clock; it is handed an instant.

### Naming rules that bind from the first commit

- **Forbidden vocabulary (NFR9, Consistency Conventions).** No identifier anywhere may contain `overdue`, `late`, `missed`, `pending`, `debt`, `streak`, `skippedCount`, `dueDate` or `backlog`. The lint that enforces it lands later in Epic 1 — **do not introduce a violation this story that a later lint will have to chase.** `failed` is permitted only in `slice_failed` and the crash path.
- **Files and types.** `snake_case.dart`; core types are plain Dart with **no annotations**.
- **No logging framework and no log destination** (AD-12). Do not add one to the scaffold. Diagnostics are `crash_recorded` events (Story 1.3) and nothing more.
- **No third-party SDK that opens a network destination, for any reason** (AD-12, NFR13) — including in CI-adjacent tooling that ships in the app.

### Source tree this story creates

Only the parts the scaffold needs. The rest of the spine's tree is created by the story that first needs it.

```text
organizer/
  devbox.json                       # NEW — the environment of record (NFR21)
  devbox.lock                       # NEW — committed
  Makefile                          # NEW — the development loop (NFR20)
  pubspec.yaml                      # NEW
  analysis_options.yaml             # NEW
  .github/workflows/ci.yml          # NEW — installs devbox, calls make targets only
  .toolchain/flutter/               # NEW, gitignored — the sha256-pinned 3.47.x tarball
  packages/core/                    # NEW — pure Dart, no flutter/drift/plugins
    pubspec.yaml
    lib/ports/clock_port.dart
    lib/ports/store_port.dart
    test/
  lib/                              # NEW — the Flutter shell
    main.dart                       # ProviderScope root, no surface
  tool/
    check_core_purity.dart          # NEW — AD-3 + AD-5, names the offending file
  test/
    tool/check_core_purity_test.dart
    fixtures/core_purity/
  android/                          # NEW — minSdk 33, targetSdk 36, 64-bit only
```

Untouched: `_bmad/`, `_bmad-output/`, `.claude/`, `.agents/`, `.opencode/`, `AGENTS.md`, `project-context.md`.

### Stack pins — authoritative; the Flutter line, not the patch

The spine's Stack table was **verified against the live web on 2026-08-26 by an independent reviewer**, and where the first draft was wrong the correction is what the table carries. Treat it as the pin of record. **Flutter is pinned by line, not by patch**: 3.47.x, the latest stable patch — patch bumps are routine (two edited values in Task 1's bootstrap, a re-lock, the gate) and only a line jump (3.48+) is a decision that reopens this table. Do not let `flutter pub upgrade` move product dependencies, and do not "modernise" a line because a newer one exists.

| Name | Version | Note relevant to this story |
| --- | --- | --- |
| Flutter | **3.47.x (line)** | Dart 3.13.x (`^3.13.0`). Brings **Java 17** and a Flutter-side minimum of Android API 24. The patch floats within the line; the bootstrap records the exact one |
| Android targetSdk | **36** | Play requires 36 from 2026-08-31; API 37 is a known follow-up, deferred |
| Android minSdk | **33** | Set by `POST_NOTIFICATIONS` and by `checkRecognitionSupport()`/`triggerModelDownload()` — **not** by the on-device recognizer, which is API 31 |
| `flutter_riverpod` | **3.4.2** | shell-only |
| `material` / `cupertino` | **not a dependency** | Material/Cupertino left the core in 3.47 as opt-in `material_ui` / `cupertino_ui`; the SDK still ships the libraries and `package:flutter/material.dart` is only *scheduled* for deprecation in the November 2026 stable. **Nothing to add to the pubspec** — adding `material_ui` fails AC 6 |
| Kotlin | 2.4.0 | comes from the Flutter Android template; not ours to choose |

Not added by this story, listed so nobody adds them early: `drift` 2.34.3 + `drift_flutter` 0.3.1 (1.3), `uuid` 4.6.0 (1.3), `flutter_localizations`/`gen_l10n` (1.2), `camera` 0.12.0+2, `google_mlkit_face_detection` 0.15.1, `saf_util` 3.1.0, `saf_stream` 4.0.1.

### What later stories will bolt onto this scaffold

Build the Makefile and `tool/` so these land as registrations, not rewrites:

| Arrives in | What it registers |
| --- | --- |
| 1.2 | `make l10n`; the no-literal-strings lint; the text-scaling lint; `lib/l10n/app_es.arb`, `lib/strings/`, `lib/ui/tokens.dart` |
| 1.3 | drift, the `.drift` insert-only triggers, the initial migration, AD-21's store seal, the forbidden-vocabulary lint |
| 1.4 | `packages/core/lib/day/` — the one `Calendar` |
| 1.5 | `assets/evergreen/`, the catalogue-floor check, the catalogue id-diff check |
| Epic 4 | AD-7's three egress seals (Dart imports, Gradle graph, merged manifest) |
| Epic 9 | AD-18's release ritual targets (build, install-on-top, export, import) |

A `tool/` id-coverage check over the story sections is also owed to NFR20 once the scaffold lands — noted, not this story's.

### Project Structure Notes

- The repository root is simultaneously the Flutter app root and the workspace root holding `packages/core`. There is no `melos`/pub-workspace requirement in the spine; a plain path dependency is enough and keeps `packages/core` resolvable by `dart pub get` alone — which is what makes AC 1's "no emulator" claim true.
- `dart format --set-exit-if-changed .` from the root traverses `packages/core` too. Format both.
- `flutter analyze` from the root does not analyze `packages/core` under a path dependency in every configuration. If it does not, add the core's analysis to `make analyze` explicitly (`cd packages/core && dart analyze`) — **but keep `make gate` to exactly its three commands** (AC 10). The extra core analysis belongs in `make analyze`'s own body, invoked by `gate`'s third command only if `flutter analyze` genuinely covers it; otherwise register it under `make check`.
- No conflict with existing structure was found — the repo carries no code.

### Previous Story Intelligence

None — this is the first story of the first epic. Two things from the repository's history are worth carrying:

- **Commit convention in use:** Conventional Commits with a scope, e.g. `docs(planning): …`, `docs(arch): …`, `docs(spec): …`. Use `feat(scaffold):` or `chore(scaffold):` for this story's commits.
- **All five planning documents are at `status: final`, updated 2026-08-27**, with four upstream debts paid the same day. There is no pending planning question that blocks this story.

### References

- [Source: _bmad-output/planning-artifacts/epics.md#Story 1.1: The sealed scaffold] — acceptance criteria
- [Source: _bmad-output/planning-artifacts/epics.md#Epic 1: The Day That Deals Itself] — scope notes: ports by first consumer, the Makefile grows additively, Epic 1 runs on defaults
- [Source: _bmad-output/planning-artifacts/epics.md#NonFunctional Requirements] — NFR9, NFR12, NFR13, NFR16, NFR17, NFR18, NFR20, NFR21
- [Source: _bmad-output/planning-artifacts/architecture/architecture-organizer-2026-08-26/ARCHITECTURE-SPINE.md#Design Paradigm]
- [Source: …/ARCHITECTURE-SPINE.md#AD-3 — Derivation is deterministic, and "dealt" is written by a command, never by a read]
- [Source: …/ARCHITECTURE-SPINE.md#AD-5 — Dependency direction is one-way and the core is sealed]
- [Source: …/ARCHITECTURE-SPINE.md#AD-12 — The egress map is a closed list; no SDK enters on "it isn't analytics"]
- [Source: …/ARCHITECTURE-SPINE.md#Consistency Conventions] — naming, forbidden vocabulary, state management, testing, where the guards live
- [Source: …/ARCHITECTURE-SPINE.md#Stack] — pinned versions, verified 2026-08-26
- [Source: …/ARCHITECTURE-SPINE.md#Structural Seed] — the source tree and the seven ports
- [Source: _bmad-output/specs/spec-organizer/SPEC.md#Constraints] — Android-only, pure-Dart core, the three-command completion gate
- [Source: project-context.md] and [Source: AGENTS.md#Policy] — the story completion gate and the devbox environment rule (NFR21)

## Dev Agent Record

### Agent Model Used

{{agent_model_name_version}}

### Debug Log References

### Completion Notes List

### File List

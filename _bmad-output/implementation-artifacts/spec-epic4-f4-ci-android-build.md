---
title: 'CI compiles the Android/Kotlin half (epic-4 retro F4)'
type: 'chore'
created: '2026-09-05'
status: 'done'
review_loop_iteration: 0
baseline_commit: '7378e5a8718aad555f89577343a0f3949b304ffa'
context:
  - '{project-root}/project-context.md'
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** CI never compiles the Android/Kotlin half: `.github/workflows/ci.yml` runs deps, codegen-check, gate, check, test-core — no `flutter build` — so a Kotlin syntax error in `CredentialKeystore.kt`/`CredentialsChannel.kt` (the crypto contract holding every credential) ships unnoticed (epic-4 retro F4).

**Approach:** Add one step to the existing `gate` job running the established `make build` target (debug APK) through `devbox run --`, so the Kotlin sources compile on every push/PR.

## Boundaries & Constraints

**Always:**
- The step runs `devbox run -- make build` — `make build` stays the single definition of the build; never an inline `flutter build` in ci.yml (NFR20/NFR21 conventions: every CI command through `devbox run --`).
- Match the workflow's existing step-naming style (short name + parenthetical reason).

**Ask First:**
- Any change beyond adding the one step (reordering existing steps, new cache config, job splits).

**Never:**
- No emulator / instrumented-test job — the androidTest round-trip + fold matrix is deferred (deferred-work.md, source_spec: none, 2026-09-05).
- No release build or signing (AD-18, Epic 9).
- No Makefile changes — `make build` already exists and is the emulator-setup reference path.
- No deferred CI hardening (timeouts, action SHA pinning, concurrency, `BOOTSTRAP_ANDROID=0`) — owned by the 1-1 deferred entry.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Push/PR runs CI | Provisioned deps (Flutter + Android SDK via `make deps`), Gradle caches restored | `make build` produces the debug APK; job stays green | N/A |
| Kotlin syntax error at HEAD | e.g. broken `CredentialKeystore.kt` | `flutter build apk --debug` fails non-zero; the step (and job) goes red | Build stderr surfaces in the Actions log |

</frozen-after-approval>

## Code Map

- `.github/workflows/ci.yml` -- the only file to edit: single `gate` job (ubuntu-latest), checkout → devbox-install-action@v0.15.0 → `make deps` → Gradle caches (`~/.gradle/caches` + wrapper, keyed on `gradle-wrapper.properties`) → `make codegen-check` → `make gate` → `make check` → `make test-core`. New step goes last (fast checks fail first; the build is the slowest step).
- `Makefile:109-110` -- `build` target: `. ./tool/env.sh && flutter build apk --debug`. Read-only; the step wraps it, not bypasses it.
- `tool/env.sh:39-45` -- resolves `ANDROID_HOME`/`ANDROID_SDK_ROOT` from `.toolchain/android-sdk` (provisioned by `make deps` in the same job); `:47-53` resolves `JAVA_HOME` from the devbox JDK. Read-only — why the step needs no extra env.
- `tool/bootstrap.sh` -- `make deps` provisions the pinned Flutter tarball plus Android SDK (platform 36, build-tools 36.0.0) and injects the Gradle wrapper; already a CI step. Read-only.
- `android/app/src/main/kotlin/dev/dorogoy/organizer/*.kt` -- the five Kotlin sources the step starts compiling in CI (`CredentialKeystore`, `CredentialsChannel`, `DictateChannel`, `DictateRecognizer`, `MainActivity`). Read-only.
- `_bmad-output/implementation-artifacts/epic-4-retro-2026-09-05.md` -- finding F4 and action item 4 (intent source).
- `_bmad-output/implementation-artifacts/deferred-work.md` (first entry, source_spec `1-1-the-sealed-scaffold.md`) -- the CI-hardening deferral the Never clause defers to (timeout-minutes, action SHA pinning, concurrency, `BOOTSTRAP_ANDROID=0`); the androidTest deferral added by this spec sits in the same file.

## Tasks & Acceptance

**Execution:**
- [x] `.github/workflows/ci.yml` -- add a final step to the `gate` job: name it `Android debug build (Kotlin half compiles in CI — epic-4 retro F4)`, run `devbox run -- make build` -- the retro's fix: compilation coverage for the Kotlin half on every push/PR.

**Acceptance Criteria:**
- Given a push to `main` or a PR, when CI runs, then the new step executes `devbox run -- make build` after `test-core` and the job stays green at HEAD.
- Given a Kotlin syntax error in any `android/app/src/main/kotlin/dev/dorogoy/organizer/*.kt`, when `make build` runs, then it exits non-zero (proven locally by transient injection + revert; CI inherits the chain).
- Given the existing Gradle cache step, when the build runs, then it consumes the restored `~/.gradle` caches — no new cache configuration added.

## Verification

**Commands:**
- `devbox run -- make build` -- expected: exit 0, `build/app/outputs/flutter-apk/app-debug.apk` produced.
- Inject a transient syntax error into `CredentialKeystore.kt` → `devbox run -- make build` -- expected: non-zero exit naming the Kotlin failure; then revert and rebuild green.
- `devbox run -- make gate` -- expected: test/format/analyze all green (no Dart changes; story completion gate per AGENTS.md Policy).

**Manual checks (if no CLI):**
- After push, the GitHub Actions run shows the new step green on `main` (the ultimate check; the local `make build` drill proves the same chain the step runs).
- In the same Actions run, the "Gradle caches" step reports a restore (hit or partial via restore-keys) before the build step runs — AC-3's observability; the diff itself adds no cache configuration.

## Suggested Review Order

**The CI step (the whole change)**

- Entry point: the new final step of the `gate` job — one step, the established target, nothing else touched
  [`ci.yml:45`](../../.github/workflows/ci.yml#L45)

- The step's run line wraps `make build` through `devbox run --` per NFR20/NFR21 — no inline flutter build
  [`ci.yml:46`](../../.github/workflows/ci.yml#L46)

**The scope split's paper trail**

- The deferred androidTest half (round-trip + fold matrix, emulator provisioning prerequisites, lineage anchors)
  [`deferred-work.md:235`](deferred-work.md#L235)

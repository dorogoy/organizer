# Project context — organizer

Loaded automatically by BMad skills as persistent facts. Canonical agent instructions live in `AGENTS.md` (repo root).

## Story completion gate

- Every story (bmad-build) ends with `flutter test`, `dart format --set-exit-if-changed .` and `flutter analyze` all green, before the spec is presented for review. Full rule: `AGENTS.md` → Policy.

## Story size budget

- Every story spec measures **≤ 24 KB** (the spec file, `wc -c`, measured cold at review presentation). Over budget → the story is split at review, **before** implementation; the gate is numeric and never argued per case. Decided 2026-09-05 (epic-4 retro + correct-course); evidence: the three outliers — 42.4 / 32.5 / 31.6 KB — are the three that exhausted coding sessions; the completed range sits at 12–25 KB.
- Canon: *"una story que no cabe en una sesión no cabe en la máquina"*.
- Applies to the spec only. The choir pilot's worker briefs stay small by design and are governed by the pilot protocol, not by this gate.

## Honest functioning vs anti-frustration

- Failures that prevent the app from working, or that change the result the user perceives of that working, are **communicated**. Never a quiet close that reads as success. Never folded into the user's refusal (`permission_refused` / `face_refused` are user acts, not a costume for a plugin crash).
- Anti-frustration is the spirit of the *household tasks* the app proposes (no nag, no "¿seguimos?", no backup guilt, checkpoint not a wall). It is **not** a license to hide OS, plugin, hardware, or product errors.
- Decided 2026-09-09 (Epic 5 retrospective party). Lineage: 5.2 lost CAMERA at shutter → `scanOpenFailed`; detector-error and missed shot join that notice, not a silent pop.

## Face gate — courtesy, not load-bearing

- On-device face refusal is **nice to have**: if a face is found, tell the user and offer the reframe (`personInFrame`). It is **not** indispensable and must **not** grow the APK (no pose/object packs, no composition reopen, no AD-11 promotion *for this*). That would be bloatware relative to what the app is.
- The load-bearing send control is **per-scan consent** (and the BYOK token). Accepting a third-party credential already implies the send clause; the face gate does not get to hold the product hostage over residual false negatives.
- Decided 2026-09-09 (Epic 5 retrospective party). Residual 4 FN/12 on the face-only interim gate stays accepted; do not re-escalate it as a blocking privacy finding.

## Development environment — devbox

- The development toolchain is owned by **devbox** (`/usr/local/bin/devbox`, 0.18.0). `devbox.json` and a committed `devbox.lock` live at the repository root (created by Story 1.1); they are the single definition of the environment for every machine and for CI.
- Toolchain commands (`flutter`, `dart`, `java`, every `make` target — the completion gate included) run **inside `devbox shell`** or through `devbox run --`. Do not install Flutter or the JDK globally, and do not run the gate against the host toolchain.
- **Build JVM: a current JDK LTS from devbox** (nixpkgs `jdk21` today; 25 once the template's Gradle is 9.1+ — Gradle needed 9.1 for Java 25). 17 is the toolchain's *minimum*, not a pin — pinning to an aging minimum buys nothing; a non-LTS is never used. The Java/Kotlin **bytecode level** is the Flutter template's own setting (17 today), not ours to choose — inherited like the template's Kotlin version; a story needing a newer language feature raises it and verifies D8 desugars it. Beware in devbox: the plain nixpkgs `jdk` package is JDK 8.
- **Flutter is pinned by line, not by patch: 3.47.x, the latest stable patch** (Dart 3.13.x, `^3.13.0` in the pubspec). The SDK is the official tarball with version and sha256 recorded in the repo, fetched by the devbox bootstrap — **`devbox add flutter` is never used** (nixpkgs lags the line — 3.47.0 while stable is 3.47.2, 2026-08-27 — and its derivation is not the official SDK). A patch bump within the line is a two-value edit plus re-lock plus the gate; 3.48+ is a decision.

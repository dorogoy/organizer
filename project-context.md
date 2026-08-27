# Project context — organizer

Loaded automatically by BMad skills as persistent facts. Canonical agent instructions live in `AGENTS.md` (repo root).

## Story completion gate

- Every story (bmad-build) ends with `flutter test`, `dart format --set-exit-if-changed .` and `flutter analyze` all green, before the spec is presented for review. Full rule: `AGENTS.md` → Policy.

## Development environment — devbox

- The development toolchain is owned by **devbox** (`/usr/local/bin/devbox`, 0.18.0). `devbox.json` and a committed `devbox.lock` live at the repository root (created by Story 1.1); they are the single definition of the environment for every machine and for CI.
- Toolchain commands (`flutter`, `dart`, `java`, every `make` target — the completion gate included) run **inside `devbox shell`** or through `devbox run --`. Do not install Flutter or the JDK globally, and do not run the gate against the host toolchain.
- **Build JVM: a current JDK LTS from devbox** (nixpkgs `jdk21` today; 25 once the template's Gradle is 9.1+ — Gradle needed 9.1 for Java 25). 17 is the toolchain's *minimum*, not a pin — pinning to an aging minimum buys nothing; a non-LTS is never used. The Java/Kotlin **bytecode level** is the Flutter template's own setting (17 today), not ours to choose — inherited like the template's Kotlin version; a story needing a newer language feature raises it and verifies D8 desugars it. Beware in devbox: the plain nixpkgs `jdk` package is JDK 8.
- **Flutter is pinned by line, not by patch: 3.47.x, the latest stable patch** (Dart 3.13.x, `^3.13.0` in the pubspec). The SDK is the official tarball with version and sha256 recorded in the repo, fetched by the devbox bootstrap — **`devbox add flutter` is never used** (nixpkgs lags the line — 3.47.0 while stable is 3.47.2, 2026-08-27 — and its derivation is not the official SDK). A patch bump within the line is a two-value edit plus re-lock plus the gate; 3.48+ is a decision.

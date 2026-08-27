<!-- bmad:context -->
<!-- Verified 2026-08-27 against f30667c. Managed by bmad-project-context; edits inside this block are replaced on refresh. Keep anything you want preserved outside the markers. -->

## organizer

Anti-overwhelm mobile task organizer, validation build: single-user Android app, local-first, no backend. Flutter/Dart with a pure-Dart functional core (no Flutter imports in core). Greenfield — no code yet; the stack and its invariants are decided in the architecture spine: `_bmad-output/planning-artifacts/architecture/architecture-organizer-2026-08-26/ARCHITECTURE-SPINE.md`.

## Policy

- A story (or any implementation unit) is not done until all three pass: `flutter test`, `dart format --set-exit-if-changed .`, `flutter analyze`. Never present work with one of them red or unrun.
- Invocations are the canonical Flutter toolchain for the decided stack (Flutter 3.47 / Dart 3.13); no project exists yet — verify them on the first refresh once `pubspec.yaml` lands, and prefer a CI check over this line when CI exists.
- The development environment is devbox: `devbox shell` before any toolchain command, locally and in CI; `devbox.json` + `devbox.lock` are committed. The build JVM is a current JDK LTS from devbox (21, or 25 once the template's Gradle is 9.1+ — never the 17 minimum, never a non-LTS); the Java/Kotlin bytecode level is the Flutter template's own (17 today), not ours to choose. The Flutter SDK is the official tarball of the pinned 3.47.x line with version and sha256 recorded — never `devbox add flutter` (nixpkgs lags the line's patches and is not the official bits). Full rule: `project-context.md` → Development environment.

<!-- /bmad:context -->

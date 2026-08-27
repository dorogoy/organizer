<!-- bmad:context -->
<!-- Verified 2026-08-27 against f30667c. Managed by bmad-project-context; edits inside this block are replaced on refresh. Keep anything you want preserved outside the markers. -->

## organizer

Anti-overwhelm mobile task organizer, validation build: single-user Android app, local-first, no backend. Flutter/Dart with a pure-Dart functional core (no Flutter imports in core). Greenfield — no code yet; the stack and its invariants are decided in the architecture spine: `_bmad-output/planning-artifacts/architecture/architecture-organizer-2026-08-26/ARCHITECTURE-SPINE.md`.

## Policy

- A story (or any implementation unit) is not done until all three pass: `flutter test`, `dart format --set-exit-if-changed .`, `flutter analyze`. Never present work with one of them red or unrun.
- Invocations are the canonical Flutter toolchain for the decided stack (Flutter 3.47 / Dart 3.13); no project exists yet — verify them on the first refresh once `pubspec.yaml` lands, and prefer a CI check over this line when CI exists.

<!-- /bmad:context -->

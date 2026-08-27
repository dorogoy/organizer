# Project context — organizer

Loaded automatically by BMad skills as persistent facts. Canonical agent instructions live in `AGENTS.md` (repo root).

## Story completion gate

- Every story (bmad-build) ends with `flutter test`, `dart format --set-exit-if-changed .` and `flutter analyze` all green, before the spec is presented for review. Full rule: `AGENTS.md` → Policy.

# Project context — organizer

Loaded automatically by BMad skills as persistent facts. Canonical agent instructions live in `AGENTS.md` (repo root).

## Story completion gate

- Every story (bmad-build) ends with `flutter test`, `dart format --set-exit-if-changed .` and `flutter analyze` all green, before the spec is presented for review. Full rule: `AGENTS.md` → Policy.

## Development environment — devbox

- The development toolchain is owned by **devbox** (`/usr/local/bin/devbox`, 0.18.0). `devbox.json` and a committed `devbox.lock` live at the repository root (created by Story 1.1); they are the single definition of the environment for every machine and for CI.
- Toolchain commands (`flutter`, `dart`, `java`, every `make` target — the completion gate included) run **inside `devbox shell`** or through `devbox run --`. Do not install Flutter or the JDK globally, and do not run the gate against the host toolchain.
- **JDK 17** comes from devbox (nixpkgs `jdk17`). **Flutter 3.47.1 / Dart 3.13.1 does not come from nixpkgs**: `devbox search flutter` tops out at 3.47.0 (verified 2026-08-27), and the spine forbids both substituting a version and moving the pin. The SDK is the official 3.47.1 stable tarball, sha256-pinned, fetched by the devbox bootstrap — **`devbox add flutter` is never used**.

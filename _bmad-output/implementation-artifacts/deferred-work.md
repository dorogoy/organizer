# Deferred Work

- source_spec: `_bmad-output/implementation-artifacts/1-1-the-sealed-scaffold.md`
  summary: Harden CI — add devbox/download caching, timeout-minutes, concurrency cancel, commit-SHA-pinned actions, a top-level permissions block, and a `BOOTSTRAP_ANDROID=0` knob so the gate-only job skips provisioning the Android SDK it never uses.
  evidence: `.github/workflows/ci.yml` re-downloads the ~1 GB Flutter tarball and the full Android SDK on every run with no timeout or cancel-on-new-commit; actions are pinned by mutable tags while the repo sha256-verifies every tarball; the bootstrap header itself says the gate never needs the Android SDK, yet `make deps` in CI installs it.

- source_spec: `_bmad-output/implementation-artifacts/1-1-the-sealed-scaffold.md`
  summary: Make the NFR12 64-bit-only APK contract rerunnable — a `tool/` guard (registered per AC-13) that builds the debug APK and asserts its `lib/` holds exactly `arm64-v8a` and `x86_64`.
  evidence: `disable-abi-filtering=true` is the only thing keeping the Flutter Gradle plugin from re-adding 32-bit ABIs; today's verification is a one-time manual `unzip -l` noted in the story's Completion Notes, so a toolchain bump can silently regress NFR12 (Story 5.1's ML Kit precondition) with every gate green.

- source_spec: `_bmad-output/implementation-artifacts/1-2-both-palettes-the-glyph-set-and-the-single-string-table.md`
  summary: Add a `tool/` token-literal lint so "no literal colour/type/spacing/radius value outside `tokens.dart`" (UX-DR1) is machine-enforced like AD-15's string ban, not inspection-only.
  evidence: The story ships three lints (strings, text-scaling, audit); `Color(0xFF9EC3B5)`, a raw `fontSize: 26`, or `SizedBox(width: 24)` anywhere in `lib/` passes `make check` today — AC 1's "no literal duplicated elsewhere" rests entirely on review.

- source_spec: `_bmad-output/implementation-artifacts/1-2-both-palettes-the-glyph-set-and-the-single-string-table.md`
  summary: Detect generated-accessor drift — either gitignore `lib/strings/` or add a check that `flutter gen-l10n` is a no-op against the committed accessors.
  evidence: `lib/strings/*.dart` are committed and load-bearing, but nothing in `make check`/`make gate` regenerates and compares; an ARB edit can ship with stale accessors and every check stays green.

- source_spec: `_bmad-output/implementation-artifacts/1-2-both-palettes-the-glyph-set-and-the-single-string-table.md`
  summary: Fold `make check` into `make gate` (or have CI run both), and pin the Makefile's check registration with a test asserting every `tool/check_*.dart` is reachable from the `check` target (NFR20).
  evidence: The gate (NFR17) runs only test+format+analyze, so this story's three lints sit outside the completion gate; deleting a `check`-target line also ships silently — the tool tests invoke the scripts directly, never through the Makefile.

- source_spec: `_bmad-output/implementation-artifacts/1-2-both-palettes-the-glyph-set-and-the-single-string-table.md`
  summary: Cover every remaining TextTheme slot from TypeRoles (labelLarge, display/headline/label variants) so no widget resolving an unwired slot falls through to Material defaults.
  evidence: `OrganizerTheme._textTheme` wires eight slots; `Theme.of(context).textTheme.labelLarge` (buttons) still returns Material 2021 defaults — un-tokened sizes/weights the day a surface uses them.

- source_spec: `_bmad-output/implementation-artifacts/1-2-both-palettes-the-glyph-set-and-the-single-string-table.md`
  summary: Test the glyph ink guard-rails the comments claim — destination-trio equal mass weight and Reloj's 211.2u² note — via path-area computation on the authored geometry.
  evidence: `box_glyph.dart`/`clock_glyph.dart` cite mass-area figures ("2.5× the seed", "the row's raw ink guard-rail holds") but no test computes path areas, so a redrawn mass can drift past the equal-weight rule with goldens only catching gross changes.

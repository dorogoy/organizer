---
title: 'Both palettes, the glyph set and the single string table'
type: 'feature'
created: '2026-08-28'
status: 'done'
review_loop_iteration: 1
baseline_commit: 'ae6b225fde9a113e20caa22c17eea2ab1c7e52a4'
context: []
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** No design tokens, glyphs, or string table exist yet — every later surface risks smuggling in literal colours, sizes, or Spanish copy that the anti-shaming audit (SM-C2) and text-scaling guarantee (NFR6) can't see.

**Approach:** Transcribe `DESIGN.md`'s tokens once into `lib/ui/tokens.dart`, seed the single ARB string table from `EXPERIENCE.md`'s fixed-string list with generated accessors, draw the ten glyphs per their shared treatment, and add three `tool/` build-time lints (no-literal-strings, text-scaling, string-table-audit) following the pattern already established by `tool/check_core_purity.dart`.

## Boundaries & Constraints

**Always:**
- Every token value lands exactly once in `lib/ui/tokens.dart` (6 field colours, 6 icon-mass colours at L*76.0, 12 dark colours, 8 typography roles — Lora for `task` only, Lexend for the rest, `sp` sizes with multiplier line-heights —, 3 radii, 13 spacing values, 2 format rules); referenced nowhere else by literal (UX-DR1).
- Field tier and icon-mass tier never touch: field colours at Aliento's baseline, icon-mass fixed at L*76.0 inside glyphs only (UX-DR2).
- Dark palette is separately authored, never an inversion; `border-strong-dark` is omitted as an orphan (UX-DR12).
- Theme follows the system; no settings row (NFR19).
- All ten glyphs share the two-plate treatment and the global 45° offset, except batería and Micrófono capsule (registered exception); no Ajustes glyph exists (UX-DR8, UX-DR10, UX-DR11).
- `lib/l10n/app_es.arb` is the single string table; `lib/strings/` holds only generated accessors; a lint fails any literal reaching a widget; one atomic value (a numeral or proper name) substituted into an otherwise fixed ARB sentence is the sole permitted interpolation (AD-15).
- Per-key audit metadata (`x-signoff`, `x-audit-exclude`) lives inside each key's `@key` block in `app_es.arb` itself — never a second file — as free-text strings (`"<name>, <date>"` / `"<reason>"`), never booleans, so existence and review stay separately verifiable (AD-15, AD-21).
- The text-scaling lint bans all five escapes: `maxLines`, `TextOverflow.ellipsis`, `FittedBox`, a `TextScaler`/`textScaleFactor` override, a fixed-height text container (UX-DR45, NFR6).
- Screen-reader interim convention: no custom semantics, no manual announcements, platform traversal order only (UX-DR48).
- Every string entering the ARB is checked against the Voice-and-Tone do/don't table before it ships (UX-DR55).
- New `tool/` checks follow `tool/check_core_purity.dart`'s scan-and-report pattern and are registered under the Makefile's `check` target.

**Ask First:** None. The seed-glyph pompom radius is drawn and measured by the implementer directly (`DESIGN.md` bars guessing a plausible value ahead of drawing it); the golden test in Tasks & Acceptance is the closing gate, not a human check-in.

**Never:** No literal colour/type/spacing/radius value outside `tokens.dart`. No runtime sentence concatenation. No inverted dark palette. No theme-override setting. No custom accessibility semantics at this stage.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Literal string in a widget | `Text('Hecho')` hardcoded | `make check` fails, names file:line | N/A |
| Sentence built by concatenation | `'$a $b'` joining two ARB values | `make check` fails | N/A |
| Atomic value into fixed sentence | ARB placeholder `{count}` or `{provider}` substituted | Passes — the sole exception | N/A |
| Text widget escapes the scale floor | `Text(..., maxLines: 2)` | `make check` fails | N/A |
| Pinned no-Slicer key missing sign-off | ARB `@key` block lacks `x-signoff` | Audit check fails | N/A |
| New ARB key added silently | Key added, no `x-audit-exclude` | Surfaces in the SM-C2 audit list | N/A |

</frozen-after-approval>

## Code Map

- `lib/main.dart` -- placeholder entry point (`ProviderScope` + empty `MaterialApp`); theme wiring lands here or in a new `lib/ui/theme.dart` it imports.
- `tool/check_core_purity.dart` -- scan pattern (mask → regex-scan → `Finding(file, line, message)` → exit 1) the three new lints follow.
- `Makefile` (`check` target) -- where new `tool/` checks register, same as existing ones.
- `pubspec.yaml` -- add `flutter_localizations`/`intl`, font assets, `generate: true`; none of this exists yet.
- `DESIGN.md:284,327,373,424,472,486,506,509,611` (Colors, Typography, Layout & Spacing, Shapes, icon-glyph, seed-glyph, zone-marker, energy-checkin, pompom-radius check) -- source of truth for every token/glyph value.
- `imports/dandelion-seed-reference.png` + `reconcile-dandelion-seed-reference.md` (status: final) -- the seed glyph's silhouette source and its claim-by-claim reconciliation; useful for the fan's overall gesture, **not** for exact numbers -- the reference itself carries 17 filaments, tapered strokes and dark ink (all explicitly rejected by DESIGN.md's 8-filament/one-stroke-width/pastel-mass decisions).
- `mockups/seed-at-scale-1.html` §§1-2, `mockups/final-verification-1.html` §§1,4 -- filament-ladder and size-floor reasoning; both carry an explicit supersession note at the top (12 filaments→8, centred r=1.70u→larger+displaced leeward, axis 53°→45°) -- read the note before trusting any number on the page.
- `mockups/mic-manual-capture-1.html` -- the microphone glyph's rest and dictating states, in situ, current and DESIGN.md-linked (line 519) -- the one other glyph with a real drawn reference.
- **Do not use** `.working/icon-treatment-1.html` as a source: it is an unpromoted draft, not linked from DESIGN.md, carries no supersession banner, and still includes an `aju` (Ajustes) glyph that the shipped decision dissolves entirely. Cámara, Álbum, Caja, Bolsa, Reloj, Hoja and Lápiz otherwise have no drawn reference beyond DESIGN.md's shared treatment formulas (offset, stroke-width) -- draw them fresh from those formulas, the same way the seed glyph is drawn from constraints rather than copied.
- `EXPERIENCE.md:84-124` (fixed string table incl. the 7 pinned no-Slicer strings), `:125-135` (Voice-and-Tone table).
- `ARCHITECTURE-SPINE.md` (AD-15) -- the ARB/lint contract and the SM-C2 audit rule.
- No `lib/ui/`, `lib/l10n/`, `lib/strings/`, or `assets/` exist yet — all new.

## Tasks & Acceptance

**Execution:**
- [x] `pubspec.yaml` -- add `flutter_localizations`/`intl`, declare Lora + Lexend variable-font assets, set `generate: true` -- prerequisite for ARB generation and type rendering
- [x] `l10n.yaml` -- template-arb-file `app_es.arb`, output-dir `lib/strings/`, output-class for generated accessors -- no hand-written string constants
- [x] `lib/l10n/app_es.arb` -- transcribe every fixed string from `EXPERIENCE.md`, keyed by id; give the seven no-Slicer keys an `x-signoff: "<name>, <date>"` entry in their `@key` block; give any excluded key an `x-audit-exclude: "<reason>"` entry -- the single string table (AD-15)
- [x] `lib/ui/tokens.dart` -- transcribe `DESIGN.md`'s Colors/Typography/Layout & Spacing/Shapes as named constants -- the single token file (UX-DR1)
- [x] `lib/ui/theme.dart` -- wire `ThemeData` + `ThemeMode.system` from tokens, no override setting -- system-follow theming (NFR19)
- [x] `lib/ui/glyphs/*.dart` -- the ten glyphs per shared treatment; seed glyph's 8 filaments, drawn pompom radius as a named constant, ≥56px motion-dash threshold -- the glyph set (UX-DR8, UX-DR10, UX-DR11)
- [x] `test/ui/glyphs/seed_glyph_test.dart` -- golden image test pinning the seed glyph at 48px and ≥56px, plus a unit assertion that the radius constant exceeds 1.70u, sits off-centre toward the leeward/dense side, and its free edge is wholly covered by filaments -- proof for the drawn radius (DESIGN.md Implementation Checks)
- [x] `tool/check_no_literal_strings.dart` + Makefile wiring -- fail on any string literal reaching a widget or runtime sentence concatenation -- AD-15's literal ban
- [x] `tool/check_text_scaling.dart` + Makefile wiring -- fail on the five text-scaling escapes -- the 200% floor (UX-DR45)
- [x] `tool/check_string_table_audit.dart` + Makefile wiring -- compute the SM-C2 audit list (every key minus one carrying `x-audit-exclude`) and fail if any of the seven pinned keys lacks `x-signoff` -- AD-15's audit rule

**Acceptance Criteria:**
- Given `DESIGN.md`'s values, when `tokens.dart` is inspected, then it holds the exact counted set with no literal duplicated elsewhere
- Given the two colour tiers, when applied, then field tier and icon-mass tier never mix on one surface
- Given the dark palette, when compared to light, then it is separately authored and omits `border-strong-dark`
- Given system theme, when selected, then the app follows it with no in-app override
- Given the ten glyphs, when rendered, then no Ajustes glyph exists and utility glyphs carry `icon-mass-neutral`
- Given a screen reader, when a surface is built, then only platform-default semantics/traversal are used
- Given any string entering the ARB, when reviewed, then it is checked against the Voice-and-Tone table
- Given the seed glyph's drawn pompom radius, when its golden test runs, then the radius constant exceeds 1.70u and the rendered image matches the pinned golden file

### Review Findings

- [x] [Review][Decision] Token cardinalities contradict the frozen contract — Resolved by human decision: authoritative `DESIGN.md` counts are ratified at 12 dark colours and 13 spacing values; the frozen constraint is corrected accordingly.
- [x] [Review][Decision] The provider placeholder exceeds the frozen interpolation exception — Resolved by human decision: one atomic numeral or proper name may be substituted into an otherwise fixed ARB sentence; fragments and runtime sentence concatenation remain banned.
- [x] [Review][Patch] High: ARB accessor concatenation bypasses the no-literal-strings check [tool/check_no_literal_strings.dart:189]
- [x] [Review][Patch] High: Whole-file exemptions leave generated strings and `tokens.dart` unaudited [tool/check_no_literal_strings.dart:199]
- [x] [Review][Patch] High: Standard fixed-height and text-scaler overrides bypass the scaling check [tool/check_text_scaling.dart:75]
- [x] [Review][Patch] Medium: The fixed-height scan rejects legal sibling spacers as text containers [tool/check_text_scaling.dart:87]
- [x] [Review][Patch] High: Whitespace can forge audit exclusions, sign-offs and non-placeholder values [tool/check_string_table_audit.dart:99]
- [x] [Review][Patch] Medium: Material primary actions resolve to ink instead of `accent-soft` [lib/ui/theme.dart:29]
- [x] [Review][Patch] Medium: The no-Ajustes test does not pin the exact ten-glyph allowlist [test/ui/glyphs/glyph_set_test.dart:123]
- [x] [Review][Patch] Medium: Battery levels and active blue states are not behaviorally verified [test/ui/glyphs/glyph_set_test.dart:138]
- [x] [Review][Patch] Medium: The destination seed's required 64px at-rest state has no golden [test/ui/glyphs/glyph_set_test.dart:255]

## Spec Change Log

- 2026-08-28 — Human review ratified `DESIGN.md` as the counted-set authority: 12 dark colours and 13 spacing values replace the contradictory 11/14 figures in the frozen Always constraint. No implementation change.
- 2026-08-28 — Human review ratified the consent provider as the same narrow interpolation class as a count: one atomic value inside an otherwise fixed ARB sentence. AD-15 was aligned; sentence fragments and runtime concatenation remain forbidden.

## Design Notes

The seed-glyph pompom radius is a genuinely open decision, not an oversight: `DESIGN.md` withholds a final number, requiring only r > 1.70u, displaced toward the leeward/dense side, free edge wholly covered by filaments. The implementer draws and measures it directly in the glyph's `CustomPainter`, no design check-in — `seed_glyph_test.dart`'s golden image plus the radius assertion is what closes this, not a human sign-off.

**Drawn and measured — the recorded radius (closing the Implementation Check):** r = **1.80u**, displaced **0.30u** off the hub centre along the leeward bisector (the tightest filament pair, 6–7), global offset applied on top. Drawn against three quantitative criteria calibrated on the design's own verdicts: (1) r > 1.70u; (2) no edge point outside the fan's swept sector — the centred r = 2.30u candidate's recorded failure (a bare arc where only the stem passes); (3) worst edge-to-filament distance ≤ 0.90u, the accepted centred 1.70u candidate's own 0.83u peek rounded up with margin. The criterion reproduces the design's anchor: at zero displacement it caps r at 1.69u ≈ the published 1.70u. Implemented in `lib/ui/glyphs/seed_geometry.dart`; asserted in `test/ui/glyphs/seed_glyph_test.dart` over the same geometry the painter renders; pinned by goldens at 48px and 64px.

**`x-signoff`/`x-audit-exclude` tolerance — verified:** `flutter gen-l10n` (Flutter 3.47.2) accepts the free-text `x-` fields inside `@key` blocks and generates cleanly — no sibling YAML fallback was needed. Metadata stays in `app_es.arb`, as AD-15 requires.

**Two counted-set discrepancies against the Always bullet, taken to `DESIGN.md` (the values source) rather than silently:** the dark palette transcribes **12** colours (the spec's Always bullet says 11; `DESIGN.md`'s frontmatter lists 12 and every one is load-bearing in a named component — `border-strong-dark` was already deleted from `DESIGN.md` and is omitted); and the spacing scale transcribes **13** values (the bullet says 14; `DESIGN.md`'s table carries 13 — the card's air-around minimum is deliberately *not* a token per `DESIGN.md` Layout & Spacing, and tokenizing it would violate that rule). The invariant that matters — every value lands exactly once and is referenced nowhere else by literal — holds either way.

**Motion-dash set:** the mockup's five arcs are transcribed, with the fourth's tail trimmed by 0.5u (from (9, 13.4) to (8.5, 13.15)): at dashes-rendering sizes its ink merged with the stem's (0.39u centerline distance against 0.56u of combined stroke halves at 64px), violating the design's own "no tocan la semilla". Total ink moves 21.78u → ~21.2u, within the published figures' rounding.

Lints are hand-written `tool/` Dart scripts here, not a `custom_lint` package — `check_core_purity.dart` is the template.

ARB keys are load-bearing for later stories (1.5's catalogue names are ARB entries keyed by id) — treat shipped keys as stable.

Implementation-time clarifications (verified against sources, no intent change):
- Counted-set deltas: the frozen intent says 11 dark colours and 14 spacing values, but `DESIGN.md` enumerates 12 dark tokens (the light mirror minus the deleted `border-strong-dark`) and 13 spacing tokens (9 layout + 4 glyph sizes). `tokens.dart` follows `DESIGN.md`, which this spec's Code Map names the source of truth for every token value.
- `tool/check_string_table_audit.dart`: an excluded key left the audit-list computation adding every key; fixed so `x-audit-exclude` is the only way off the list, and a pinned key carrying an exclusion is a finding (it must never leave the SM-C2 audit). All three new lints now carry test suites under `test/tool/` following `check_core_purity`'s pattern — this is what covers the I/O matrix rows.
- The original frozen bullet "numeral-into-fixed-sentence is the sole permitted interpolation" met EXPERIENCE.md's consent body `La foto se procesará por [proveedor]…`, which declares itself "one parameterized localized body". Human review ratified the coherent rule: a single atomic token (name or numeral) substituted into a fixed sentence is permitted; AD-15 still bans assembling a sentence from fragments. The ARB therefore ships `consentGateBody` with a `{provider}` placeholder.

## Verification

**Commands:**
- `devbox run -- make check` -- expected: the three new `tool/` lints pass with zero findings alongside existing checks
- `devbox run -- make gate` -- expected: `flutter test`, `dart format --set-exit-if-changed .`, `flutter analyze` all green
- `devbox run -- flutter gen-l10n` -- expected: `lib/strings/` accessors regenerate cleanly from `app_es.arb`
- `devbox run -- flutter test test/ui/glyphs/seed_glyph_test.dart` -- expected: radius assertion and golden image both pass

**Manual checks (if no CLI):**
- Toggle system dark mode on-device/emulator; confirm the app follows with no settings row
- Visually inspect all ten glyphs (seed glyph at 48px and ≥56px) for the 45° offset, correct plate colours, and motion-dash threshold

## Suggested Review Order

**The shared treatment and the offset correction** *(start here — the system's core geometry)*

- The one global, screen-space offset applied before rotation — the seed's axial rule lives or dies here
  [`glyph_canvas.dart:82`](../../lib/ui/glyphs/glyph_canvas.dart#L82)

- The offset expressed in the drawing's local frame (53° local = 45° screen); base vs measured pompom positions split
  [`seed_geometry.dart:162`](../../lib/ui/glyphs/seed_geometry.dart#L162)

- The drawn pompom radius (r = 1.80u, dense-displaced 0.30u) — the story's one draw-time decision
  [`seed_geometry.dart:22`](../../lib/ui/glyphs/seed_geometry.dart#L22)

- Mass path authored pre-offset; painter applies the vector once; dashes gated at 56px even when forced true
  [`seed_glyph.dart:96`](../../lib/ui/glyphs/seed_glyph.dart#L96)

- Always-repaint painter: paths rebuild per build and inputs (battery level) don't show in compared fields
  [`glyph_canvas.dart:141`](../../lib/ui/glyphs/glyph_canvas.dart#L141)

**Tokens and theming**

- The single token file: 6 field + 6 icon-mass + 12 dark colours, 8 type roles, 3 radii, 13 spacing, 2 format rules
  [`tokens.dart:19`](../../lib/ui/tokens.dart#L19)

- Separately-authored dark palette, `border-strong-dark` omitted as the recorded orphan
  [`tokens.dart:73`](../../lib/ui/tokens.dart#L73)

- Lora for `task` only, Lexend elsewhere, `sp` sizes with multiplier line-heights
  [`tokens.dart:102`](../../lib/ui/tokens.dart#L102)

- Both themes from tokens; eight TextTheme slots fully specified from TypeRoles
  [`theme.dart:8`](../../lib/ui/theme.dart#L8)

- `ThemeMode.system`, no override row; ARB delegates wired at the shell
  [`main.dart:26`](../../lib/main.dart#L26)

**The single string table**

- All 49 fixed strings from EXPERIENCE.md, verbatim; per-key `x-signoff` in `@key` blocks
  [`app_es.arb:4`](../../lib/l10n/app_es.arb#L4)

- Template/output config — `lib/strings/` holds generated accessors only
  [`l10n.yaml:1`](../../l10n.yaml#L1)

**The three build-time lints**

- AD-15's literal ban: every string literal in `lib/` outside the ARB fails; `${…}` bodies lexed as code
  [`check_no_literal_strings.dart:70`](../../tool/check_no_literal_strings.dart#L70)

- The five text-scaling escapes, including fixed-height containers (also `AnimatedContainer`, `maxHeight`, `.5`)
  [`check_text_scaling.dart:75`](../../tool/check_text_scaling.dart#L75)

- SM-C2 audit: every key minus reviewed exclusions; seven pinned keys need signed, real-dated sign-offs
  [`check_string_table_audit.dart:25`](../../tool/check_string_table_audit.dart#L25)

- Registration: all four checks reachable from `make check` (NFR20)
  [`Makefile:42`](../../Makefile#L42)

**Tests — the closing gates**

- Pompom geometry asserted over the same numbers that render; radius, leeward displacement, coverage, axis
  [`seed_glyph_test.dart:20`](../../test/ui/glyphs/seed_glyph_test.dart#L20)

- Ten glyphs × both palettes pinned by goldens; tier colours, registration and no-Ajustes asserted
  [`glyph_set_test.dart:27`](../../test/ui/glyphs/glyph_set_test.dart#L27)

- Shell wiring: system theme-follow and delegate resolution smoke-tested
  [`app_test.dart:16`](../../test/ui/app_test.dart#L16)

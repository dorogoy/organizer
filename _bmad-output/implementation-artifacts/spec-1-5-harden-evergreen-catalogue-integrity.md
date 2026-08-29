---
title: 'Harden Evergreen catalogue integrity'
type: 'feature'
created: '2026-08-29'
status: 'done'
review_loop_iteration: 0
baseline_commit: '79aa3ed7626b81a5b96a9010667bbb9e6904a4ca'
context:
  - '{project-root}/_bmad-output/implementation-artifacts/1-5-the-shipped-evergreen-catalogue.md'
  - '{project-root}/_bmad-output/implementation-artifacts/epic-1-context.md'
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** Story 1.5's current checks validate the shipped snapshot but leave several drift paths open: shallow generator input, weak ARB metadata checks, stale localization accessors, incomplete immutable snapshots, and an asset-registration parser that can accept non-Flutter YAML. The catalogue's stated tuple derivation also cannot reproduce A12's `plantas` and `coche` authorial groups.

**Approach:** Strengthen every catalogue boundary around one authoritative four-field asset and ARB names, pin the full authored v1 data in test-only fixtures, and make codegen, continuity, bundle, and CI guards reject drift. Renegotiate cluster curation to expose only groups derivable from the frozen tuple rather than storing a fifth field or a second runtime catalogue asset.

## Boundaries & Constraints

**Always:** `catalogue.json` remains the sole runtime catalogue asset and every entry still carries exactly `id`, `size`, `cadence`, and optional weekly `zone`; names remain only in ARB. The core stays pure Dart with no dependency changes. Reject duplicate JSON members before any catalogue, baseline, or ARB validation uses the value. The generator validates the complete asset contract, rejects blank ARB values and missing or blank `@key.description`, and never emits partial output. Codegen regenerates and scopes all committed generated outputs: Drift, localization accessors, and catalogue lookup. Continuity freezes every shipped id's size, cadence, zone-or-none, and Spanish name; additions remain legal. The test oracle pins the complete ordered A12 v1 tuple and exclusions. Tests load the production `rootBundle`, not only a file-backed fake. The published curation groups are only `anclas`, `sostén`, `z1` through `z5`, and `fondo`; `plantas` and `coche` remain non-curatable authorial annotations.

**Ask First:** Adding a runtime id-to-cluster projection, reintroducing individually switchable `plantas` or `coche`, changing a shipped baseline tuple or name, or changing any frozen A12 entry requires a new human-approved catalogue-evolution record.

**Never:** Do not add a fifth catalogue field, a second runtime asset, a core Flutter/YAML dependency, a network API, runtime ARB-key assembly, or UI work. Do not weaken existing structural, floor, or no-literal-string checks. Do not rewrite historical baselines to conceal a removal, reclassification, zone reassignment, or renamed entry.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|---------------|---------------------------|----------------|
| Duplicate JSON member | Asset, baseline, or ARB repeats a key | Validation identifies the duplicate and its source line | Exit 1 / `FormatException` |
| Invalid bundle declaration | Nested, slashless, malformed, or non-list `flutter.assets` | Floor check rejects it; quoted valid paths still pass | Exit 1 |
| Incomplete catalogue copy | Blank name or missing/blank description for a derived key | Lookup generation names the entry/key and writes nothing | Exit 1 |
| Full-contract drift | Version, field set, token, cadence-zone coupling, or A12 distribution changes | Generator/checks fail before generated output is accepted | Exit 1 |
| Immutable tuple drift | Existing id changes cadence, zone, or Spanish name | Continuity check names old and new values | Exit 1 |
| Localization drift | ARB changes without regenerated accessors | `make codegen-check` regenerates and reports scoped generated-file drift | Exit 1 |
| Packaged load | Flutter test uses default loader/bundle | All 85 named entries resolve from the registered asset | Test failure |

</frozen-after-approval>

## Code Map

- `packages/core/lib/catalogue/catalogue.dart:103-225` -- pure asset authority; replace its `jsonDecode` boundary with a duplicate-aware decoder without changing the public parser API.
- `packages/core/lib/catalogue/strict_json.dart` -- NEW core-only decoder/diagnostics shared by the parser; no Flutter or `dart:io` import.
- `tool/catalogue_shared.dart` -- shared source-line helpers for core-parser and tooling findings; extend rather than duplicating offset lookup.
- `tool/check_catalogue_floor.dart:38-91` -- replace indentation regex registration detection with YAML-aware `flutter.assets` validation while retaining `file:line` findings.
- `tool/gen_catalogue_lookup.dart:54-157` -- validate through `parseCatalogue`; enforce derived ARB value and metadata quality before static-table emission.
- `tool/check_catalogue_id_diff.dart:42-147` and `tool/catalogue_baseline.json` -- evolve the snapshot from id-to-size to a full immutable tuple, preserving fixture-call ergonomics.
- `Makefile:53-68`, `l10n.yaml`, `lib/strings/app_strings*.dart` -- `flutter gen-l10n` owns the committed accessor pair; codegen freshness scopes them with Drift and lookup output.
- `test/catalogue/loader_test.dart` -- existing fake bundle proves isolated loader paths; add default `rootBundle` coverage here.
- `test/fixtures/catalogue/a12_v1_manifest.json` and `test/catalogue/a12_manifest_test.dart` -- NEW test-only immutable ordered A12 oracle; do not consume it at runtime.
- `test/tool/check_catalogue_floor_test.dart`, `test/tool/gen_catalogue_lookup_test.dart`, `test/tool/check_catalogue_id_diff_test.dart`, and `packages/core/test/catalogue_test.dart` -- follow existing mutant and `file:line` conventions for every matrix failure.
- `.github/workflows/ci.yml` and a focused `tool/` check -- require a reviewed catalogue-evolution record whenever protected catalogue inputs change together.
- `_bmad-output/implementation-artifacts/1-5-the-shipped-evergreen-catalogue.md`, `deferred-work.md`, `planning-artifacts/epics.md`, `planning-artifacts/prds/prd-organizer-2026-08-20/prd.md`, and `planning-artifacts/architecture/architecture-organizer-2026-08-26/ARCHITECTURE-SPINE.md` -- human-authorized correction of the impossible tuple-to-`plantas`/`coche` derivation and related curation promises.

## Tasks & Acceptance

**Execution:**
- [x] `packages/core/lib/catalogue/strict_json.dart`, `catalogue.dart`, and `packages/core/test/catalogue_test.dart` -- add duplicate-member-safe decoding and parser mutants.
- [x] `pubspec.yaml`, `tool/check_catalogue_floor.dart`, and floor tests -- use YAML-aware, exact Flutter asset registration validation.
- [x] `tool/gen_catalogue_lookup.dart` and generator tests -- validate full asset shape and require nonblank name/description metadata.
- [x] `tool/check_catalogue_id_diff.dart`, baseline/fixtures, and id-diff tests -- freeze the complete immutable tuple and name.
- [x] `test/fixtures/catalogue/a12_v1_manifest.json`, manifest test, and loader test -- pin all authored records/exclusions and exercise the real Flutter bundle.
- [x] `Makefile`, generated accessors, CI/check tooling, and tests -- add localization freshness and an explicit catalogue-evolution approval guard.
- [x] Catalogue planning/implementation records -- record the authorized cluster-contract correction and edit the resolved review artifact for clarity.

**Acceptance Criteria:**
- Given malformed or duplicated catalogue JSON, ARB, or baseline input, when any parser or guard reads it, then it fails with a source-specific diagnostic before accepting data.
- Given an invalid `flutter.assets` shape, blank derived name, or missing description, when checks run, then `make check` fails; valid quoted file and directory registrations pass.
- Given an ARB edit without regenerated accessors, when `make codegen-check` runs, then it fails with only localization outputs in its generated-file diff scope.
- Given a change to any existing A12 id's size, cadence, zone, name, order, or exclusion set, when the catalogue suite runs, then the precise drift fails; a new id remains an explicit evolution path.
- Given the test app bundle, when `loadEvergreenCatalogue(AppStringsEs())` uses its default bundle, then all 85 resolved records load offline.
- Given later curation, when it groups shipped entries, then only tuple-derivable groups are available and no code or planning promise implies `plantas` or `coche` can be derived.

## Design Notes

- The immutable baseline and the A12 manifest have different jobs: the baseline permits reviewed additions while protecting shipped ids; the manifest pins the original authored order and values.
- The localization generator remains Flutter-owned. `make codegen` invokes it and the existing scoped-diff guard detects stale committed accessors.
- The cluster correction preserves the four-field runtime contract. It intentionally removes unsupported curation rather than adding hidden id metadata under another name.

## Verification

**Commands:**
- `devbox run -- make check` -- expected: all catalogue, localization, and existing checks pass.
- `devbox run -- make codegen-check` -- expected: Drift, localization, and lookup outputs regenerate with no scoped diff.
- `devbox run -- make gate` -- expected: Flutter tests, formatting, and analysis pass.
- `devbox run -- make test-core` -- expected: strict catalogue parser tests pass in the pure-Dart package.

## Suggested Review Order

**Strict Data Boundaries**

- Reject duplicate members before maps can silently overwrite authored content.
  [`strict_json.dart:29`](../../packages/core/lib/catalogue/strict_json.dart#L29)

- Keep the parser as the sole asset-shape authority for runtime and tooling.
  [`catalogue.dart:103`](../../packages/core/lib/catalogue/catalogue.dart#L103)

- Validate asset and copy together before emitting the static resolver.
  [`gen_catalogue_lookup.dart:59`](../../tool/gen_catalogue_lookup.dart#L59)

**Immutable Catalogue Evolution**

- Freeze every shipped tuple and resolved Spanish name, not size alone.
  [`check_catalogue_id_diff.dart:31`](../../tool/check_catalogue_id_diff.dart#L31)

- Require a structured approval record for coordinated protected changes.
  [`check_catalogue_evolution.dart:27`](../../tool/check_catalogue_evolution.dart#L27)

- Pin A12's ordered authored source separately from the additive baseline.
  [`a12_manifest_test.dart:1`](../../test/catalogue/a12_manifest_test.dart#L1)

**Build And Bundle Guards**

- Parse Flutter asset registration as YAML, never by indentation lookalike.
  [`check_catalogue_floor.dart:38`](../../tool/check_catalogue_floor.dart#L38)

- Regenerate every committed output before scoped freshness comparison.
  [`Makefile:54`](../../Makefile#L54)

- Load the asset through Flutter's registered production bundle.
  [`loader_test.dart:107`](../../test/catalogue/loader_test.dart#L107)

**Contract Correction And Peripherals**

- Limit curation promises to groups derivable from the four-field contract.
  [`epics.md:635`](../../_bmad-output/planning-artifacts/epics.md#L635)

- Exercise malformed-input, continuity, and Git-range guard paths.
  [`catalogue_test.dart:174`](../../packages/core/test/catalogue_test.dart#L174)

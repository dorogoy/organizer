---
title: 'The shipped Evergreen catalogue'
type: 'feature'
created: '2026-08-29'
status: 'done'
review_loop_iteration: 0
baseline_commit: '353ed38cbe40194a0ff03c195aa4d10825a4310c'
context:
  - '{project-root}/_bmad-output/planning-artifacts/prds/prd-organizer-2026-08-20/addendum.md'
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** The app boots to an empty world — no shipped work exists, so FR-11's promise (a varied day on a keyless, offline, model-less install) has no content behind it and 1.6's weave would have nothing to weave.

**Approach:** Ship the authored A12 catalogue (85 entries) as a versioned read-only JSON asset with exactly four fields per entry; put every Spanish name in the ARB table keyed by entry id; add a pure core parser plus a named shell loader that resolves names at load time and hands inert data over; guard the catalogue with two new `tool/` checks — coverage floor and id-set diff, the latter self-tested against a mutated v0 fixture — registered in the Makefile.

## Boundaries & Constraints

**Always:**
- `assets/evergreen/catalogue.json`: top-level `{"version": 1, "entries": [...]}`; each entry exactly `id`, `size`, `cadence`, `zone` — `id` a kebab-case Spanish slug (permanent once shipped), `size` ∈ `instant|maintenance|focus` (core `Size` tokens, FR-27), `cadence` ∈ `daily|weekly|seasonal`, `zone` ∈ `z1..z5` or absent. The name is not in the asset (AD-16).
- Content = addendum A12 verbatim: 34 daily (14 `instant` + 14 `maintenance` + 6 `focus`), 36 weekly (Z1 8, Z2–Z5 7 each; 20 `focus` + 16 `maintenance`), 15 seasonal (12 `focus` + 3 `maintenance`) — 85 entries, floor math 32 ≥ 28. A12.6's absent list stays absent.
- Core `packages/core/lib/catalogue/catalogue.dart`: `Cadence`, `Zone`, `CatalogueEntry` (four fields + resolved `name`), pure `parseCatalogue(String json, {required String Function(String id) nameOf})` — validates field set, token domains, id uniqueness; `FormatException` names entry id + field. `dart:convert` only, zero new deps.
- Names: 85 ARB keys `catalogue<Pascal(id)>` (`regar-una-planta` → `catalogueRegarUnaPlanta`) with `@` descriptions; audited like all copy — no `x-audit-exclude`.
- `tool/gen_catalogue_lookup.dart` reads asset + ARB, fails on any missing derived key, emits `lib/catalogue/catalogue_names.g.dart`: static id→`AppStrings` getter table + asset-path constant. No runtime key assembly (SPINE:237); generated `*.g.dart` is exempt from the literal-strings check.
- Named shell loader `lib/catalogue/loader.dart`: `rootBundle` only (offline by construction) → `parseCatalogue` with the generated resolver → inert core data. Lazy — no boot wiring; 1.6's weave is its first consumer.
- `tool/check_catalogue_floor.dart`: asset shape, all three cadences populated, ≥ 28 distinct `focus` non-daily entries (`maintenance` never counts, `daily` excluded), and `pubspec.yaml` `assets:` registration.
- `tool/check_catalogue_id_diff.dart` + `tool/catalogue_baseline.json` (id→size snapshot; greenfield = current set): fails naming the id on disappearance or size change; additions pass. Baseline updated only in a commit deliberately evolving the catalogue.
- Both checks under `make check`, generator under `make codegen-check`, same pass (NFR20); findings `file:line: message`, exit 1.

**Ask First:** None.

**Never:** No fifth field — cluster tags (`anclas`/`sostén`/`fondo`/`plantas`/`coche`) are A12 authorial groupings, not asset data; clusters derive from (cadence, zone, size). No UI change, no screen enumerating entries; no pool writes or `Origin.shipped` instantiation (1.6's weave); no new core port (`ports_test.dart` pins two files); no edits to `day/`, `energy/`, `pool/`, `log/`, `ports/`; no network API anywhere; no hand-maintained id→key map outside the generated file; never update the baseline to smuggle a removal or re-size.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|---------------|---------------------------|----------------|
| Happy path | real asset + generated resolver | 85 named inert entries parsed | N/A |
| Extra field | entry carries a fifth key | parse + floor fail naming entry id + key | FormatException / exit 1 |
| Missing/unknown token | absent `cadence`; `size: "10min"`; `zone: "z6"` | parse/check fail naming entry + field | FormatException / exit 1 |
| Duplicate id | two entries share an id | parse + floor fail naming the id | exit 1 |
| Floor breach | 27 eligible entries | floor check exits 1 | N/A |
| Exclusion mutants | 28th eligible is `maintenance`, or flipped to `daily` | count drops → floor fails | N/A |
| id-diff removal | baseline id absent from asset | exit 1 naming the id | N/A |
| id-diff re-size | size differs from baseline | exit 1 naming id + both sizes | N/A |
| id-diff addition | new id vs baseline | passes | N/A |
| Greenfield self-test | v0 fixture + mutated copies | check fails naming the mutated id | N/A |
| Airplane mode | offline first open | library loads from the bundle; no network touched | N/A |
| Unregistered asset | pubspec lacks `assets/evergreen/` | floor check fails | N/A |

</frozen-after-approval>

## Code Map

- `assets/evergreen/catalogue.json` -- NEW; addendum A12 (frontmatter context) is the authored source of names and counts.
- `packages/core/lib/pool/pool_fact.dart:33-43` -- the `Size` enum the asset tokens map onto.
- `packages/core/test/ports_test.dart:30-43` -- pins `lib/ports/` to exactly two files: the catalogue module lives outside `ports/`.
- `tool/check_core_purity.dart` -- bans flutter/drift/`dart:io` in `packages/core/lib`: the parser takes a String; the shell loader owns the bundle.
- `tool/check_no_literal_strings.dart:30,39-46` -- generated `*.g.dart` exempt (why the path constant lives in the generated table); `namedConstantAllowance` is the fallback, as a named decision.
- `lib/crash.dart:32-55`, `lib/store/bootstrap.dart:8` -- the legal named shell-loader pattern: shell reads ambient sources, hands inert records to core.
- `lib/l10n/app_es.arb` + `l10n.yaml` -- single string table, lowerCamelCase keys, `@` metadata; `lib/strings/app_strings_es.dart` lets tests construct `AppStringsEs()` directly.
- `tool/check_forbidden_vocabulary.dart:42-52` -- nine banned identifier tokens; mind them when naming loader/check symbols.
- `test/tool/check_store_seal_test.dart` + `test/fixtures/store_seal/` -- the fixture self-test pattern (clean + violating files) both new check tests follow; fixtures must stay under `test/fixtures/`.
- `Makefile:42-58` -- `check` list and `codegen-check` (regenerate + git diff) that the two checks and the generator register into.

## Tasks & Acceptance

**Execution:**
- [x] `assets/evergreen/catalogue.json` -- NEW: transcribe A12 (85 entries, counts per Always); slug ids from the Spanish names
- [x] `packages/core/lib/catalogue/catalogue.dart` -- NEW: `Cadence`, `Zone`, `CatalogueEntry`, `parseCatalogue` (four-field validation, token domains, unique ids, injectable name resolver)
- [x] `packages/core/test/catalogue_test.dart` -- NEW: pin every I/O-matrix parse row on inline fixtures
- [x] `lib/l10n/app_es.arb` -- add 85 `catalogue*` keys + `@` descriptions (values = A12 Spanish names); regenerate strings
- [x] `tool/gen_catalogue_lookup.dart` -- NEW: asset ids × ARB keys → verified static table; emits `lib/catalogue/catalogue_names.g.dart` (id→getter map + asset-path constant)
- [x] `lib/catalogue/loader.dart` -- NEW: named loader — `rootBundle.loadString` → `parseCatalogue` with the generated resolver → inert `Catalogue`
- [x] `test/catalogue/loader_test.dart` -- NEW: fake bundle + real asset file + `AppStringsEs()` → 85 named entries, fully offline
- [x] `tool/check_catalogue_floor.dart` -- NEW: shape, cadence population, ≥28 distinct focus non-daily, pubspec registration; `file:line:` findings
- [x] `tool/check_catalogue_id_diff.dart` + `tool/catalogue_baseline.json` -- NEW: baseline diff with `runCheck(baselinePath, assetPath)` exposed for tests; baseline = current 85-id set
- [x] `test/tool/check_catalogue_floor_test.dart` + `test/fixtures/catalogue_floor/` -- NEW: clean + each violating mutant (27-eligible, maintenance-28th, daily-flip, extra field, dup id)
- [x] `test/tool/check_catalogue_id_diff_test.dart` + `test/fixtures/catalogue_id_diff/` -- NEW: green against the real pair; v0 fixture + mutated copies (removed id, re-sized id) fail naming the mutated id
- [x] `pubspec.yaml` -- register `assets/evergreen/`
- [x] `Makefile` -- add both checks to `check` (help text: nine checks); add the generator to `codegen-check` as a second git-diff guard
- [x] `_bmad-output/implementation-artifacts/deferred-work.md` -- append: cluster tags are not asset data; Epic 5 curation derives clusters from (cadence, zone, size) or renegotiates AD-16

**Acceptance Criteria:**
- Given the build, when `assets/evergreen/` is read, then it holds one versioned read-only file whose entries each carry exactly the four fields
- Given a catalogue entry's Spanish name, when it is needed, then it resolves through an ARB key derived from the id via the generated static table — never runtime assembly, never the asset
- Given the three cadences, when counted, then all are populated with A12's 34/36/15
- Given the floor check, when it counts distinct 10–15 min non-daily entries, then it fails below 28 and 3-minute or daily entries never count
- Given any entry, when inspected, then it carries no hour, mealtime or cross-task dependency
- Given the id-diff check, when an id disappeared or its size changed, then the build fails naming the id — and the greenfield self-test proves both failure modes against the mutated v0 fixture
- Given an offline first open, when the loader runs, then the whole library arrives from the asset bundle and no network is touched
- Given the completion gate, then `make check` (nine checks), `make codegen-check`, `make gate` and `make test-core` are green

### Review Findings

- [x] [Review][Patch] High: the parser's docs promised the weekly⇔zone coupling but no cross-field check existed — a weekly entry without a zone and a zoned daily/seasonal entry both parsed clean; coupling now validated (FormatException naming id + field) with tests both directions [packages/core/lib/catalogue/catalogue.dart, packages/core/test/catalogue_test.dart]
- [x] [Review][Patch] High: the loader's `catalogueNameOf[id]!` died as a bare null-check crash on stale-codegen drift; the missing id now throws a FormatException naming it, and asset-read failures wrap with catalogue context [lib/catalogue/loader.dart, test/catalogue/loader_test.dart]
- [x] [Review][Patch] High: the kebab-case id grammar was asserted in prose but never validated, and two distinct ids could derive one ARB key (silent name sharing); grammar now enforced in the parser and collisions fail the generator naming both ids [packages/core/lib/catalogue/catalogue.dart, tool/gen_catalogue_lookup.dart]
- [x] [Review][Patch] Medium: the generator was the only tool/ script without a test suite; `gen_catalogue_lookup_test.dart` added (derivation, missing key, collision, orphan, malformed, determinism) [test/tool/gen_catalogue_lookup_test.dart]
- [x] [Review][Patch] Medium: orphaned `catalogue*` ARB keys after an id disappears accumulated silently; the generator now fails naming key + line [tool/gen_catalogue_lookup.dart]
- [x] [Review][Patch] Medium: `Catalogue.entries` and the generated `catalogueNameOf` were mutable; both unmodifiable, mutation tests added [packages/core/lib/catalogue/catalogue.dart, lib/catalogue/catalogue_names.g.dart]
- [x] [Review][Patch] Medium: nothing required every zone z1..z5 populated — emptying a zone passed `make check`; the floor check now fails on an empty zone [tool/check_catalogue_floor.dart]
- [x] [Review][Patch] Medium: the id-diff baseline accepted non-object JSON and unvalidated size tokens, and re-implemented the asset read; baseline type/token validation added and the asset side now delegates to `parseCatalogue` [tool/check_catalogue_id_diff.dart]
- [x] [Review][Patch] Medium: `_FakeBundle` built bytes from UTF-16 code units (ASCII-only correctness); now `utf8.encode` [test/catalogue/loader_test.dart]
- [x] [Review][Patch] Medium: the pubspec registration regex matched across newlines and outside the `flutter:` block; now `[ \t]`-scoped to the block [tool/check_catalogue_floor.dart]
- [x] [Review][Patch] Medium: an untracked generated table bypassed codegen-check's HEAD diff; the guard now fails on truly-untracked files, and a plain `make codegen` target gives regeneration an entry point [Makefile]
- [x] [Review][Patch] Medium: unknown top-level JSON keys shipped silently; the parser rejects them naming the key [packages/core/lib/catalogue/catalogue.dart]
- [x] [Review][Patch] Low: the tooling's line-locating regexes coupled to the parser's message wording implicitly; the `entry "<id>":` prefix is now a documented contract pinned by test, and the duplicated line helpers consolidated into `tool/catalogue_shared.dart` [packages/core/lib/catalogue/catalogue.dart, tool/catalogue_shared.dart]
- [ ] [Review][Reject] Monthly-vs-seasonal rotation granularity is unexpressible in the four-field asset — restates AD-16's deliberate freeze; the renegotiation path is already recorded in deferred-work (cluster derivation)
- [ ] [Review][Reject] Floor check passes at 28 while the loader test pins 32 — the floor is FR-31's minimum and the authored content is the test's job; both layers are doing their designed work

## Spec Change Log

## Design Notes

- **The id scheme is the one permanent choice**: kebab-case slugs read well in future `card_dealt` rows; ARB keys derive at generation time (`regar-una-planta` → `catalogueRegarUnaPlanta`). Once shipped, ids never change (AD-23) — typos are locked, which is the point.
- **Baseline honesty**: the diff guards accidental drift; a coordinated asset+baseline edit can only be caught in review — AD-23 renegotiation is a human act. Release tags (Epic 9) can later replace the checked-in snapshot as the diff source.
- **Lazy by omission**: no `main.dart` wiring — 1.6's weave becomes the loader's first caller. `parseCatalogue` accepting the resolver keeps ARB knowledge shell-side while the entry the core receives already carries its resolved name (AD-16's "alongside the four fields").

## Verification

**Commands:**
- `devbox run -- make check` -- expected: nine checks green (seven existing + catalogue floor + catalogue id diff)
- `devbox run -- make codegen-check` -- expected: build_runner + catalogue lookup regenerate with no diff
- `devbox run -- make gate` -- expected: `flutter test`, format check, analyze all green
- `devbox run -- make test-core` -- expected: green, including `catalogue_test.dart`
- `devbox run -- flutter test test/tool test/catalogue` -- expected: new suites green

## Suggested Review Order

**The four-field contract — start here, the story's whole point**

- One pure parser: exact field set, token domains, id grammar, weekly⇔zone coupling — the single authority on what a catalogue entry is
  [`catalogue.dart:103`](../../packages/core/lib/catalogue/catalogue.dart#L103)

- The shipped content itself: 85 A12 entries, four fields each, name nowhere in it
  [`catalogue.json:1`](../../assets/evergreen/catalogue.json#L1)

- The taxonomy the asset tokens map onto — `Cadence`, `Zone`, the 1-3-5 `Size` reuse
  [`catalogue.dart:24`](../../packages/core/lib/catalogue/catalogue.dart#L24)

**Names live outside the asset (AD-16)**

- Catalogue copy as ordinary ARB entries keyed by id — audited like every other string
  [`app_es.arb:261`](../../lib/l10n/app_es.arb#L261)

- The generator: key derivation plus collision and orphan guards; fails rather than guessing
  [`gen_catalogue_lookup.dart:31`](../../tool/gen_catalogue_lookup.dart#L31)

- The generated static lookup — every key statically present, none assembled at runtime
  [`catalogue_names.g.dart:16`](../../lib/catalogue/catalogue_names.g.dart#L16)

- The named shell loader: rootBundle only, hands the core named inert data, lazy
  [`loader.dart:34`](../../lib/catalogue/loader.dart#L34)

**The build-time guards (AD-16, AD-23)**

- The floor check: shape via the core parser, every zone populated, ≥ 28 distinct focus non-daily
  [`check_catalogue_floor.dart:101`](../../tool/check_catalogue_floor.dart#L101)

- The id-diff: disappearance or re-size fails naming the id, additions pass
  [`check_catalogue_id_diff.dart:45`](../../tool/check_catalogue_id_diff.dart#L45)

- The greenfield baseline — the previous-release id→size snapshot the diff reads
  [`catalogue_baseline.json:1`](../../tool/catalogue_baseline.json#L1)

- Both checks and the generator registered in the same pass, codegen staleness + untracked guarded
  [`Makefile:42`](../../Makefile#L42)

**Peripherals**

- The parse matrix: every I/O row, message-contract pin, unmodifiability
  [`catalogue_test.dart:1`](../../packages/core/test/catalogue_test.dart#L1)

- The offline proof: real asset bytes + real Spanish strings, no network in sight
  [`loader_test.dart:1`](../../test/catalogue/loader_test.dart#L1)

- The greenfield self-test: mutated v0 fixtures fail naming the mutated id
  [`check_catalogue_id_diff_test.dart:1`](../../test/tool/check_catalogue_id_diff_test.dart#L1)

- Floor mutants: 27-eligible, maintenance-28th, daily-flip, extra field, dup id, empty zone
  [`check_catalogue_floor_test.dart:1`](../../test/tool/check_catalogue_floor_test.dart#L1)

- The generator's own suite — the convention every other tool script already followed
  [`gen_catalogue_lookup_test.dart:1`](../../test/tool/gen_catalogue_lookup_test.dart#L1)

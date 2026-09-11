---
title: '6-7: The cumulative declutter metric'
type: 'feature'
created: '2026-09-11'
status: 'done' # draft | ready-for-dev | in-progress | in-review | done
review_loop_iteration: 0 # incremented by step-04 before each review loopback
baseline_commit: '6b933ef74462e15048a4f60424d1aa998417662c'
context: ['_bmad-output/implementation-artifacts/epic-6-context.md']
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** 6.3's `item_triaged` rows accumulate the letting-go trace but nothing can read it: the log has no derivation turning taps into the cumulative achievement figures (per-destination item counts, liberated volume) that FR-22 names and Epic 7's dashboard (7.3) consumes — every future consumer would grow its own fold and its own "what liberates" rule.

**Approach:** One pure derivation in the core, `deriveDeclutterMetric` over the log snapshot, mirroring `deriveQuarantine`: per-destination item counts plus coarse tag tallies over liberated rows only, as an immutable counts-only record. No surface and no shell change in this story — the figures become available for 7.3 to cross onto the FR-23 dashboard as achievement figures (AD-26).

## Boundaries & Constraints

**Always:** Pure single-pass fold over the entries it is given (the caller supplies read-visible rows — `deriveQuarantine`'s contract); same input → identical record; zero rows → every count zero, never null (zero is the honest cumulative). Counts only: every field is an int, so a percentage, rate, average or denominator is unrepresentable by construction (FR-22, AD-26). Only `donate_sell` and `trash_recycle` liberate: `liberatedItems` is their sum and the tag tallies count tags on their rows alone — a kept object liberates nothing, the same grammar the minter already asserts for quarantine (`triage_commands.dart`: "a quarantined object liberates nothing"). Vocabulary is the closed `TriageDestination`/`CoarseVolumeTag` enums (unknown wire names never reach the fold — AD-23 excludes them at the read boundary). New docs cite FR-22/AD-26/UX-DR49.

**Ask First:** None anticipated. If execution seems to need a surface, a shell write path, or an equivalence table between volume tags — HALT: this story excludes all three.

**Never:** No UI, no shell/controller/facade wiring (no consumer exists until 7.3; dead code is not a crossing). No ARB edit — the authored literal `liberatedVolume` stays verbatim; its parameterization is 7.3's decision under UX-DR49. No bolsa→caja equivalence (a conversion table is a numeric volume in disguise, which FR-22 forbids and the enum makes unrepresentable). No new LogKind, schema column, store or minter change. Nothing inferred from photographs or from any kind but `item_triaged`.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Empty log | no `item_triaged` rows | metric with every count zero | N/A |
| Untagged liberated row | `donate_sell`, no tag | donateSellCount +1, liberatedItems +1, no tag tally | N/A |
| Tagged liberated row | `trash_recycle` + `caja` | trashRecycleCount +1, liberatedItems +1, caja tally +1 | N/A |
| Tagged kept row | `keep` + `caja` | keepCount +1 only — the tag contributes to no volume | N/A |
| Quarantine row | `quarantine` (minter: never tagged) | quarantineCount +1, never liberated, no tally | N/A |
| Purity | same entries, two calls | identical records | N/A |
| Later append | more rows visible at a later read | counts grow monotonically — cumulative, never reset | N/A |

</frozen-after-approval>

## Code Map

- `packages/core/lib/derive/declutter_metric.dart` -- NEW. `DeclutterMetric` typedef record (keepCount / donateSellCount / trashRecycleCount / quarantineCount, `liberatedItems`, and per-tag liberated tallies bolsa / caja / cajaGrande / mueble) + `deriveDeclutterMetric(List<LogEntry>)`.
- `packages/core/lib/derive/quarantine.dart:48` -- the fold to mirror: single pass, `is TriageEntry` filter, immutable record return, reference-equality caveats documented.
- `packages/core/lib/log/log_entry.dart:144,188,702` -- `TriageDestination`, `CoarseVolumeTag` (closed enums, wire maps), `TriageEntry` (`destination`, `volumeTag?`, `boxId?`) — the fold's whole input vocabulary; the :744 doc already names "6.7's metric".
- `packages/core/lib/commands/triage_commands.dart:34` -- the single minter whose no-tag-on-quarantine assert this derivation generalizes to keep.
- `packages/core/lib/derive/strip.dart:300` -- precedent for consuming triage rows with the caller-supplied visibility contract.
- `packages/core/test/derive/quarantine_test.dart:11-26` -- the local `box()`/`triage()` builder pattern the new test mirrors.
- `lib/l10n/app_es.arb:159` -- `liberatedVolume` authored literal; read-only for this story.

## Tasks & Acceptance

**Execution:**
- [x] `packages/core/lib/derive/declutter_metric.dart` -- add the record + derivation per the Boundaries -- the one fold every future consumer reads.
- [x] `packages/core/test/derive/declutter_metric_test.dart` -- mirror quarantine_test's builders; pin every matrix row plus the counts-only shape, FR citations in test names.

**Acceptance Criteria:**
- Given a log with tagged and untagged rows across all four destinations, when the metric derives, then per-destination counts count every row, `liberatedItems` equals donate_sell + trash_recycle only, and tag tallies count tags on liberated rows alone.
- Given the record's public shape, when it is audited, then every field is an integer count — no percentage, rate, average or denominator is representable (FR-22, AD-26).
- Given two derivations over the same snapshot, when compared, then the records are equal and nothing was written (purity, AD-1).
- Given the ARB table, when the story closes, then `liberatedVolume`'s literal is untouched (UX-DR49; rendering is 7.3's).

### Review Findings

- [x] [Review][Patch] `liberates` computed by boolean `==` was a second, unguarded encoding of the destination vocabulary — replaced with an exhaustive switch expression, so a future forward-only destination member is a compile error, never a silent non-liberator [packages/core/lib/derive/declutter_metric.dart]
- [x] [Review][Patch] The doc's AD-23 sentence conflated two tolerances — unknown kinds ride as `UnknownEntry` and the type filter skips them; the read boundary excludes unknown payload wire names. Rewritten to name the real mechanism [packages/core/lib/derive/declutter_metric.dart]
- [x] [Review][Patch] Duplicate-id contract undocumented — one doc sentence now states the fold counts every row exactly once, no id-dedup, per AD-23's no-repair grammar (the dedup guard itself was rejected: it would mask a corrupted read) [packages/core/lib/derive/declutter_metric.dart]
- [x] [Review][Patch] Read-boundary pairings the minter refuses (quarantine+tag, donate+boxId) were unpinned — test added: the tagged quarantine row tallies nothing, the boxed donate row still liberates (AD-23 tolerance) [packages/core/test/derive/declutter_metric_test.dart]
- [x] [Review][Patch] `UnknownEntry` joined the purity test's mixed list (an actually-unknown kind via `LogKind.parse`, not a known one disguised) [packages/core/test/derive/declutter_metric_test.dart]
- [x] [Review][Patch] Monotonicity test now covers all nine fields — growth where the appends move, explicit invariance where they do not [packages/core/test/derive/declutter_metric_test.dart]
- [x] [Review][Patch] Order-independence pinned — a permuted snapshot derives the identical record, so 7.3 cannot cargo-cult the quarantine fold's replay-order sensitivity [packages/core/test/derive/declutter_metric_test.dart]
- [x] [Review][Patch] The `isA<int>` chain was tautological (could never fail) — deleted; the counts-only shape is compile-pinned by the full-record const literals, and a comment names that enforcement [packages/core/test/derive/declutter_metric_test.dart]
- [x] [Review][Patch] The item_triaged census title said "no derivation consumes the substrate yet" — stale since 6.5. Title fixed and a stated-reader pin added: the `TriageDestination`/`CoarseVolumeTag` vocabulary appears in exactly five core files over stripped source (definition, payload plumbing, minter, the two folds) — `ports/store_port.dart` names it in doc comments alone, and comment-stripping rightly ignores prose; a sixth fails [packages/core/test/no_lateness_proof_test.dart]
- [Defer] No automated pin that the 26 authored fixed strings (UX-DR49, `liberatedVolume` among them) stay verbatim in the ARB table — recorded in `deferred-work.md`
- [Reject] `_recordFields` freeze for `DeclutterMetric` — the 6.5 precedent (`QuarantineBox`) is census-only, and the tests' full-record const literals already fail compilation on any shape change; a second mechanism for the same invariant is redundancy
- [Reject] Dedup-by-id guard in the fold — sanctioned writers mint UUIDv7 ids; a guard would silently repair (mask) a corrupted caller snapshot instead of counting it honestly
- [x] [Review][Patch] Stale file count in Suggested Review Order — align 'six core files; a seventh fails' with five files / sixth fails proof test [_bmad-output/implementation-artifacts/6-7-the-cumulative-declutter-metric.md:111]
- [x] [Review][Patch] Pin duplicate-id contract in test suite — verify deriveDeclutterMetric counts every row without deduplication [packages/core/test/derive/declutter_metric_test.dart:255]
- [x] [Review][Patch] Add missing dated section heading in deferred-work.md before Story 6.7 deferred item [_bmad-output/implementation-artifacts/deferred-work.md:356]

## Spec Change Log

## Design Notes

Why a `liberatedItems` subtotal in core: the "which destinations liberate" rule then lives in exactly one place — 7.3 cannot re-derive it wrong. Same reasoning for tags-on-liberated-rows-only volume.

Why no crossing yet: AD-26 lets achievement figures cross as numbers into the FR-23 dashboard only; with no dashboard until 7.3, shell wiring now is dead code. The crossing is 7.3 importing this derivation over the queue-consistent read (the `deriveStrip`/`deriveQuarantine` consumer pattern, `lib/dispenser/dispenser_controller.dart:455`).

Why per-tag tallies and not one volume figure: FR-22 forbids numeric volume, and collapsing bolsa/caja/caja grande/mueble into one number requires an equivalence table — a numeric volume in disguise. The tally per unit word is the honest shape; 7.3 renders it as the authored approximation sentence.

## Verification

**Commands:**
- `devbox run -- make gate` -- expected: `flutter test`, format, analyze and repository checks green, including the new derive tests.

## Suggested Review Order

**The derivation (FR-22 in one fold)**

- The counts-only record — nine int fields; a percentage, rate or denominator is unrepresentable.
  [`declutter_metric.dart:51`](../../packages/core/lib/derive/declutter_metric.dart#L51)

- The fold itself — single pass, `TriageEntry` filter, the two stated reader rules in one place.
  [`declutter_metric.dart:77`](../../packages/core/lib/derive/declutter_metric.dart#L77)

- The liberation rule as an exhaustive switch — a future destination member is a compile error, never a silent non-liberator.
  [`declutter_metric.dart:97`](../../packages/core/lib/derive/declutter_metric.dart#L97)

- The caller contract — read-visible rows, no id-dedup, unknown kinds carried not repaired (AD-23).
  [`declutter_metric.dart:69`](../../packages/core/lib/derive/declutter_metric.dart#L69)

**The substrate's audience, pinned**

- The stated-reader pin — the destination/tag vocabulary appears in exactly five core files; a sixth fails.
  [`no_lateness_proof_test.dart:2629`](../../packages/core/test/no_lateness_proof_test.dart#L2629)

- The frozen-shapes census registration — the record joins the no-overdue proof's accounting.
  [`no_lateness_proof_test.dart:1318`](../../packages/core/test/no_lateness_proof_test.dart#L1318)

**Verification**

- The minter-refused pairings a restored log can still carry — tolerated and counted by facts alone.
  [`declutter_metric_test.dart:115`](../../packages/core/test/derive/declutter_metric_test.dart#L115)

- Purity over a mixed list including an unknown kind; order-independence; the compile-pin note on the shape.
  [`declutter_metric_test.dart:212`](../../packages/core/test/derive/declutter_metric_test.dart#L212), [`declutter_metric_test.dart:233`](../../packages/core/test/derive/declutter_metric_test.dart#L233), [`declutter_metric_test.dart:294`](../../packages/core/test/derive/declutter_metric_test.dart#L294)

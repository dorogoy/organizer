---
title: 'Zone rotation, `fondo` fill and the below-floor fallback'
type: 'feature'
created: '2026-08-29'
status: 'done'
review_loop_iteration: 0
baseline_commit: '332bb867e3b8526498e6ab5bb050b29f4004727f'
context: []
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** The resolver treats the catalogue as one flat pool — no weekly zone rotation, no `fondo` fill before repetition, no below-floor fallback, no curation timing — so chunks can repeat zone entries while new ones remain, and none of FR-11/FR-31/AD-16/AD-20's rotation semantics exist.

**Approach:** Core-only restructure of the Focus Chunk resolution into ordered tiers (active zone → `fondo` → least-recently-dealt regardless of zone), a Monday-anchored weekly zone rotation over active clusters derived from a new Calendar week ordinal, an inert curation-observation model with the weekly-vs-immediate timing split (the `EnergyObservation` pattern), and the 28-deal no-repeat test over the default all-active state, against a core fixture and the shipped asset.

## Boundaries & Constraints

**Always:**
- Chunk tiers, in order (AD-20): (1) the active zone's non-daily focus entries never **answered** (`card_done`) all-time; (2) `fondo` (seasonal focus) never answered; (3) least-recently-dealt eligible entry regardless of zone — repetition accepted, never an empty day while any eligible entry exists. Ties within tiers: least-recently-dealt then stable id.
- Active-zone rule: exactly one zone per domestic week — nominal ring position `Zone.values[weekOrdinal mod 5]`, then the first active zone at-or-after it cyclically (a disabled zone's week passes to the next active zone). No active zone → chunk tiers empty; the 3/5 draws are unaffected.
- Consumption = `card_done` rows only: a skip re-resolves identity and consumes nothing; a 🔴 day deals no chunk (existing energy gate) and consumes nothing — the floor counts answered deals, not calendar days.
- The week comes from `weekOf(anchorDayOf(...))` — the dealing session's own day (AD-19); the week ordinal grows on the one `Calendar`, never beside it.
- Curation mirrors `EnergyObservation`: inert `CurationObservation` records (cluster, enabled, instant, offset) and one pure derivation of the effective active-cluster set. Weekly-zone changes take effect at the start of the week **after** the observation's domestic week (an instant exactly on a boundary belongs to the new week, half-open); `anclas`/`sostén`/`fondo` changes take effect on their own domestic day; last observation per cluster wins; default (none) = all active. Clusters derive only from the tuple: `anclas` = daily+instant, `sostén` = daily+maintenance/focus, `z1..z5` = weekly by zone, `fondo` = seasonal.
- `composeDay`/`nextDeal` take the resolved active-cluster set with an all-active default (facades/commands unchanged in 1.7); weekly rotation gates only the chunk tier — the 3/5 draws stay size-based; cluster filtering applies to every candidate.
- `Candidate`/`Card` gain the entry's `Zone?` (data for 1.8's zone-marker; no zone-name strings). `composeDay`/`nextDeal` share one policy pipeline — the 1.6 deferred unification lands here.

**Ask First:** None.

**Never:** No UI, zone-marker or close surface (1.8–1.10). No new log kinds — the `cluster_curation_changed` writer is Epic 5's. No new ports, no stored curation state, no ARB keys, no asset or codegen changes, no capture/rescue/purge/epic candidates, no energy or Time-Bag surfaces, no pool_facts writes.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Behavior |
|----------|---------------|-------------------|
| Zone exhausted in-week | zone's entries all answered, day 6 of its week | `fondo` fills — no repetition |
| Below floor | curation leaves < 28 eligible | tier-3 LRD deal — repetition, never an empty day while eligible entries exist |
| 28 answered chunks | default state, 28 days × deal+answer | 28 distinct ids (fixture and shipped asset) |
| 🔴 day / skipped chunk | energy low / `card_skipped` on a zone entry | no chunk, nothing consumed; skip re-resolves to a different candidate, entry stays in its tier |
| Weekly curation mid-week | zone disabled on a Wednesday | effective next Monday 04:00; that week keeps its zone; a boundary-exact instant belongs to the new week |
| Daily/`fondo` curation | `anclas`/`sostén`/`fondo` disabled | effective that same domestic day — entries leave all draws |
| Every cluster disabled | all clusters off | empty composition; `nextDeal` null; session start appends no `card_dealt` |

</frozen-after-approval>

## Code Map

- `packages/core/lib/weave/weave.dart` -- restructure site: `shippedCandidates` :131 (cluster filter + zone flow), `_resolverOrder` :169, `_chunkComposes` :210 (gate stays), `composeDay` :227, `nextDeal` focus branch :285-294 (tier pipeline), `Card` :55 / `Candidate` :109 (gain `Zone?`), `CandidatePrecedence` :101 (no new member).
- `packages/core/lib/weave/session.dart` -- `walkLog` :89: add an answered-item index (pattern of `focusSlotClosedDays` :147-149); `anchorDayOf` :176 feeds `weekOf`.
- `packages/core/lib/day/calendar.dart` -- `weekOf` :216: add the week ordinal; doc :23-26 reserves zone rotation for the Calendar.
- `packages/core/lib/catalogue/catalogue.dart` -- `Zone` :38 (z1..z5), `Cadence` :26 (`seasonal` = `fondo`), `zone` :64 (iff weekly, validated :197-207).
- `packages/core/lib/curation/curation.dart` -- NEW: cluster enum, observation record, tuple mapping, timing derivation.
- `packages/core/lib/facade/read_facade.dart` :22 -- unchanged; `facade_test.dart:171` pins the no-collection shape — zone data rides on `Card`.
- `packages/core/lib/commands/session_commands.dart` -- unchanged; answer guard :136-186 feeds the answered index.
- Tests: `packages/core/test/weave_test.dart` builders :10-79; `test/catalogue/loader_test.dart:22` `_FakeBundle`; `tool/check_forbidden_vocabulary.dart:42` banned tokens (rotation, fondo, cluster are safe).
- `Makefile` -- `check` :42, `test-core` :30, `gate` :72; nothing new to register.

## Tasks & Acceptance

**Execution:**
- [x] `packages/core/lib/day/calendar.dart` -- add a deterministic week ordinal (weeks since a fixed epoch Monday) -- rotation arithmetic belongs to the one Calendar
- [x] `packages/core/lib/curation/curation.dart` -- NEW: `CurationCluster`, `CurationObservation`, tuple→cluster mapping, `activeClustersAt` with the weekly/immediate timing split and all-active default
- [x] `packages/core/lib/weave/session.dart` -- `walkLog` accumulates the answered-item index (`card_done` rows only)
- [x] `packages/core/lib/weave/weave.dart` -- chunk tier pipeline (zone → `fondo` → LRD regardless of zone), active-zone ring, cluster filtering, `Zone?` on `Candidate`/`Card`, `activeClusters` param (all-active default), `composeDay`/`nextDeal` unified on one policy pipeline
- [x] `packages/core/test/curation_test.dart` -- NEW: timing split (mid-week, boundary-exact, Sunday change), last-wins, default all-active, tuple mapping
- [x] `packages/core/test/weave_test.dart` -- extend: tier order, `fondo` fill, below-floor fallback, disabled-zone pass-through, all-disabled empty day, 🔴 and skip consume nothing, zone change at the week boundary, 28-deal distinct on a fixture mirroring the shipped arithmetic (5/3/4/5/3 zone focus + 12 fondo)
- [x] `test/weave/rotation_asset_test.dart` -- NEW: 28-deal derivation against the shipped asset via the loader pattern

**Acceptance Criteria:**
- Given a domestic week, when the active zone is derived over the active clusters, then exactly one zone is active — nominal ring position, disabled zones passed to the next active one
- Given an active zone whose never-answered entries run out within its week, when the slot resolves, then `fondo` fills the gap before any repetition
- Given curation below the floor, when the slot resolves, then the stated fallback order holds and the day is never empty while an eligible entry exists
- Given the default state, when 28 chunks are dealt and answered, then no Micro-task repeats — against a core fixture and the shipped asset
- Given a 🔴 day, when the day composes, then no chunk is dealt and no rotation is consumed
- Given a cluster curation change, when it takes effect, then weekly zones change at the next week boundary and daily and `fondo` clusters change immediately
- Given every cluster disabled, when the day composes, then no deals exist and a session start appends no `card_dealt` (the warm-string close surface is 1.8's)
- Given the completion gate, then `make check`, `make test-core` and `make gate` are green

### Review Findings

- [x] [Review][Patch] High: `nextDeal` resolved a second card while the open session held a dealt-but-unanswered deal — a latent AD-3 violation at the single-resolver level (every caller guarded it); the resolver now returns null while a deal is outstanding, freed by the answer or session close [packages/core/lib/weave/weave.dart]
- [x] [Review][Patch] Medium: the curation derivation was never composed with the weave — `activeClustersAt` output is now fed into `composeDay`/`nextDeal` in a test (mid-week disable keeps the zone through Sunday, Monday follows the new set) — the Epic-5 seam [packages/core/test/weave_test.dart]
- [x] [Review][Patch] Medium: an open session crossing Monday 04:00 kept no pinned zone — now tested: the session anchors to its start week's zone until it closes (AD-19 × ring) [packages/core/test/weave_test.dart]
- [x] [Review][Patch] Medium: `Week.weekOrdinal` had no invariant or pre-epoch coverage — consecutive-weeks-differ-by-one and negative-ordinal ring resolution now pinned [packages/core/test/day_test.dart, packages/core/test/weave_test.dart]
- [x] [Review][Patch] Medium: pre-04:00 daily/`fondo` curation observations were untested — a 02:00 change now pinned to its previous domestic day's 04:00 opening [packages/core/test/curation_test.dart]
- [x] [Review][Patch] Medium: skip-consumes-nothing was proven for tier 1 only — a skipped `fondo` entry now pinned to re-resolve within tier 2 [packages/core/test/weave_test.dart]
- [x] [Review][Patch] Medium: the rotation never reached z5 at deal level — a z5 week composition/deal now pinned [packages/core/test/weave_test.dart]
- [x] [Review][Patch] Low: `curationClusterOfEntry` crashed on a bare null assertion for a hand-built weekly-without-zone entry — now a named `StateError`, mirroring `walkLog`'s duplicate-id discipline [packages/core/lib/curation/curation.dart]
- [x] [Review][Patch] Low: `Card.toString()` omitted `zone` though it participates in equality [packages/core/lib/weave/weave.dart]
- [ ] [Review][Defer] Origin-scoping `answeredItemIds` — recorded in _bmad-output/implementation-artifacts/deferred-work.md (first second-origin writer / restore)
- [ ] [Review][Reject] Below-floor fallback against the real asset — the fixture/asset arithmetic equivalence is pinned by the asset test's precondition asserts (5/3/4/5/3, 32 eligible)
- [ ] [Review][Reject] Deduplicating test helpers across `packages/core/test` and root `test/` — the epoch literals are deliberate loud pins and the packages are structurally separate

## Spec Change Log

- **2026-08-29 (Review Iteration 1):**
  - Completed review loop across Blind Hunter, Edge-Case Hunter and Verification-Gap lenses; 9 patches applied and verified (154 core tests, gate green), 1 deferral recorded, 4 findings rejected with rationale.
  - Verification-gap lens independently confirmed every changed surface is consumed/pinned; no gaps.
## Design Notes

- **All-time answered exclusion, not per-week windows.** Tiers 1-2 exclude entries ever answered: 20 zone + 12 `fondo` = 32 ≥ 28, so the floor holds over the combined pool by construction — each answered deal removes its entry from future tiers, and repetition enters only via tier 3, whose LRD order surfaces never-dealt entries first. Per-week windows would repeat week-old entries while new ones remain elsewhere. AC2's "exhausted within its week" is the fresh-run manifestation (a zone's ~5 entries cannot fill 7 days), not the window semantics.
- **Resolved-set parameter, not observation threading:** the timing derivation runs once per evaluation in the curation module (the `deriveLivePoolEnergy` precedent — shipped in 1.4 with no row source until 2.5); Epic 5's writer maps rows to observations and passes the derived set. One timing implementation, no facade/commands growth, existing call sites stay green via the default.
- **Ring rule:** `active = firstActiveAtOrAfter(Zone.values[weekOrdinal mod 5])` cyclically — plain rotation when all active; a disabled zone hands its week to the next active one as FR-11 words it.
- **The unification closes 1.6's deferred item:** one shared eligibility+tier+cap pipeline feeds `composeDay` and `nextDeal`, so they can no longer drift.

## Verification

**Commands:**
- `devbox run -- make test-core` -- expected: green, including the curation and extended weave suites
- `devbox run -- make check` -- expected: all registered checks green; nothing new to register
- `devbox run -- make gate` -- expected: test, format, analyze all green
- `devbox run -- flutter test test/weave` -- expected: the shipped-asset 28-deal test green

## Suggested Review Order

**The tier pipeline — the story's heart (AD-20)**

- The chunk tiers: zone never-answered → `fondo` never-answered → LRD any, repetition only at tier 3
  [`weave.dart:279`](../../packages/core/lib/weave/weave.dart#L279)

- The resolver holds the AD-3 line itself — null while a deal is outstanding
  [`weave.dart:440`](../../packages/core/lib/weave/weave.dart#L440)

- The active-zone ring: nominal ordinal position, first-active-at-or-after, disabled weeks pass on
  [`weave.dart:187`](../../packages/core/lib/weave/weave.dart#L187)

- One shared policy feeds `composeDay` and `nextDeal` — the 1.6 unification
  [`weave.dart:335`](../../packages/core/lib/weave/weave.dart#L335)

- Cluster filtering at the candidate source — every draw respects curation
  [`weave.dart:162`](../../packages/core/lib/weave/weave.dart#L162)

**Rotation inputs (Calendar + consumption ledger)**

- The week ordinal — the one number the ring may read, owned by the one Calendar
  [`calendar.dart:135`](../../packages/core/lib/day/calendar.dart#L135)

- `answeredItemIds`: `card_done` rows only, all-time — what tiers exclude
  [`session.dart:50`](../../packages/core/lib/weave/session.dart#L50)

**The curation model (the Epic-5 seam)**

- Cluster vocabulary + tuple→cluster mapping — `anclas`, `sostén`, `z1..z5`, `fondo`
  [`curation.dart:34`](../../packages/core/lib/curation/curation.dart#L34)

- The timing derivation: weekly at next week boundary, daily/`fondo` immediate, newest-effective wins
  [`curation.dart:150`](../../packages/core/lib/curation/curation.dart#L150)

**Peripherals — the proofs**

- 28 answered chunks never repeat, pinned day-by-day on the shipped arithmetic
  [`weave_test.dart:1045`](../../packages/core/test/weave_test.dart#L1045)

- The same property against the real asset via the loader
  [`rotation_asset_test.dart:112`](../../test/weave/rotation_asset_test.dart#L112)

- The Epic-5 seam proven: `activeClustersAt` output rides into the weave
  [`weave_test.dart:816`](../../packages/core/test/weave_test.dart#L816)

- AD-19 × ring: an open session keeps its start week's zone
  [`weave_test.dart:776`](../../packages/core/test/weave_test.dart#L776)

- Timing edges: boundary-exact, Sunday change, pre-04:00 observations
  [`curation_test.dart:94`](../../packages/core/test/curation_test.dart#L94)

- Ordinal invariants: consecutive weeks, epoch anchor, pre-epoch ring
  [`day_test.dart:263`](../../packages/core/test/day_test.dart#L263)

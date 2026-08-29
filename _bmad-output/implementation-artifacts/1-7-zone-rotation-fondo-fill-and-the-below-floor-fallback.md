---
title: 'Zone rotation, `fondo` fill and the below-floor fallback'
type: 'feature'
created: '2026-08-29'
status: 'done'
review_loop_iteration: 2
baseline_commit: '332bb867e3b8526498e6ab5bb050b29f4004727f'
context: ['FR-11', 'FR-31', 'AD-16', 'AD-19', 'AD-20']
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
| Weekly curation observed at the boundary | zone disabled exactly at Monday 04:00 | the boundary's own week keeps its zone; the change lands at the next week boundary |
| Daily-cluster curation through the seam | `fondo` disabled mid-day, derived set fed to the weave | `fondo` leaves the chunk tiers that same domestic day |
| Below floor, ring advancing | z1+z2 active — 20 eligible < 28; 21 days | the ring advances across weeks; 20 distinct deals then the day-21 tier-3 repetition — never an empty day |
| Whole week with no session | a zone's week passes with no log rows | no catch-up — the new week's zone deals first |
| Shipped-asset z5 week | all-active default, the week anchored Monday 2026-09-21, 7 days × deal+answer | the asset's three z5 entries deal, then `fondo` fills the week's rest — ids by capture |
| Shipped-asset below floor | `{z1, fondo}` active — 17 eligible < 28; 18 days × deal+answer | 17 distinct deals then the first id's tier-3 repetition — never an empty day, ids by capture |
| Daily/`fondo` curation | `anclas`/`sostén`/`fondo` disabled | effective that same domestic day — entries leave all draws |
| Every cluster disabled | all clusters off | empty composition; `nextDeal` null; session start appends no `card_dealt` |

</frozen-after-approval>

## Code Map

- `packages/core/lib/weave/weave.dart` -- restructure site: `shippedCandidates` :162 (cluster filter + zone flow), `_resolverOrder` :224, `_chunkComposes` :312 (gate stays), `_resolveDay` :337 (the shared pipeline; its AD-3 outstanding-deal guard :351), `composeDay` :392, `nextDeal` focus branch :427-464 (tier pipeline), `Card` :69 / `Candidate` :131 (gain `Zone?`), `CandidatePrecedence` :123 (no new member).
- `packages/core/lib/weave/session.dart` -- `walkLog` :95: add an answered-item index (pattern of `focusSlotClosedDays` :156-158); the outstanding-deal clear origin-matched at :160-165; `anchorDayOf` :189 feeds `weekOf`.
- `packages/core/lib/day/calendar.dart` -- `weekOrdinal` :135: add the week ordinal; `weekOf` :235; doc :23-26 reserves zone rotation for the Calendar.
- `packages/core/lib/catalogue/catalogue.dart` -- `Zone` :38 (z1..z5), `Cadence` :26 (`seasonal` = `fondo`), `zone` :64 (iff weekly, validated :197-207).
- `packages/core/lib/curation/curation.dart` -- NEW: cluster enum :34, observation record :79, tuple mapping :94, timing derivation `activeClustersAt` :160.
- `packages/core/lib/facade/read_facade.dart` :22 -- unchanged; `facade_test.dart:171` pins the no-collection shape — zone data rides on `Card`.
- `packages/core/lib/commands/session_commands.dart` -- unchanged; answer guard :136-186 feeds the answered index.
- Tests: `packages/core/test/weave_test.dart` builders :12-126; `test/catalogue/loader_test.dart:19` `_FakeBundle`; `tool/check_forbidden_vocabulary.dart:42` banned tokens (rotation, fondo, cluster are safe).
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
- [ ] [Review][Defer] Origin-scoping `answeredItemIds` (`Set<String>` to origin-scoped representation when multi-origin captures arrive) — recorded in _bmad-output/implementation-artifacts/deferred-work.md (first second-origin writer / restore)
- [ ] [Review][Reject] Below-floor fallback against the real asset — the fixture/asset arithmetic equivalence is pinned by the asset test's precondition asserts (5/3/4/5/3, 32 eligible) — superseded in iteration 2 by the asset's below-floor run
- [ ] [Review][Reject] Deduplicating test helpers across `packages/core/test` and root `test/` — the epoch literals are deliberate loud pins and the packages are structurally separate

Review iteration 2 (2026-08-29):

- [x] [Review][Patch] High: `composeDay` composed a phantom chunk while the open session held a dealt-but-unanswered card — the AD-3 hole `nextDeal`'s guard had closed at the deal level only; the outstanding-deal check now lives in the shared `_resolveDay` pipeline (upkeep and habit plans still compose, `nextDeal` still null outright), so one policy feeds both surfaces and the "cannot drift" claim is true [packages/core/lib/weave/weave.dart]
- [x] [Review][Patch] Medium: `walkLog` cleared the outstanding deal on a bare id match — a `card_done` under a foreign origin freed a deal it never answered; the clear now matches the (itemId, itemOrigin) pair, the same line the command layer's answer guard already holds [packages/core/lib/weave/session.dart]
- [x] [Review][Patch] Medium: `curationClusterOfEntry` accepted a hand-built non-weekly entry carrying a zone, silently misclustering it — now a named `StateError` mirroring `_weeklyZoneOf`'s discipline; `parseCatalogue` already rejects the shape on the asset path [packages/core/lib/curation/curation.dart]
- [x] [Review][Patch] Low: `Card.toString()` rendered the literal `null` for an absent zone though `zone` participates in equality — absent now renders `-` [packages/core/lib/weave/weave.dart]
- [x] [Review][Patch] Medium: weekly curation was never observed from the boundary itself — an observation made exactly at Monday 04:00 now pinned to its own week's rotation, turning away only at the next boundary [packages/core/test/curation_test.dart]
- [x] [Review][Patch] Medium: the Epic-5 seam's daily-cluster half was untested — a mid-day `fondo` disable now pinned riding `activeClustersAt` into the weave the same domestic day [packages/core/test/weave_test.dart]
- [x] [Review][Patch] Medium: below-floor was proven only under a wrapped ring — now pinned under an advancing ring (z1+z2 active: 20 distinct deals, then the day-21 tier-3 repetition, never an empty day) [packages/core/test/weave_test.dart]
- [x] [Review][Patch] Medium: missed-week semantics were unpinned — a whole week with no session now pinned to pass without catch-up (the new week's zone deals first, AD-19 × FR-11) [packages/core/test/weave_test.dart]
- [x] [Review][Patch] Medium: the shipped asset carried no z5 or below-floor proof — a z5-week run dealing the asset's z5 entries and a below-floor run ({z1, fondo}: 17 distinct then the first id's repetition) now pinned, ids by capture, superseding iteration 1's rejection [test/weave/rotation_asset_test.dart]
- [x] [Review][Patch] Low: `Card.zone` had no value-contract pin — two cards differing only in zone now pinned unequal with distinct hashes, `toString` rendering the zone and never `null` [packages/core/test/weave_test.dart]
- [x] [Review][Patch] Low: the compose-level consequence of the AD-3 pipeline guard was pinned nowhere — the phantom-chunk pin re-stated (upkeep and habits stand while a deal stands; the slot proves open after the session closes) [packages/core/test/session_commands_test.dart, packages/core/test/weave_test.dart]
- [ ] [Review][Reject] Demoting a skipped zone entry to tier 2 so it cannot re-deal within its week — the frozen intent reads a skip as consuming nothing while the entry stays in its tier, and the pinned consequence (`weave_test.dart`: the one-entry zone that re-deals before `fondo` once its zone-mates are answered) is exactly that reading; demotion would contradict both

## Spec Change Log

- **2026-08-29 (Review Iteration 1):**
  - Completed review loop across Blind Hunter, Edge-Case Hunter and Verification-Gap lenses; 9 patches applied and verified (154 core tests, gate green), 1 deferral recorded, 2 findings rejected with rationale.
  - Verification-gap lens independently confirmed every changed surface is consumed/pinned; no gaps.
- **2026-08-29 (Review Iteration 2):**
  - Second review loop over the done state: 18 findings — 11 patched (4 code: the AD-3 pipeline guard, the origin-matched `walkLog` clear, the non-weekly-with-zone fail-fast, `Card.toString`'s `-`; 7 verification: boundary-exact weekly curation, the seam's daily-cluster half, below-floor under an advancing ring, missed-week semantics, `Card.zone`'s value contract, the compose-level AD-3 re-pin, and the z5 + below-floor runs against the shipped asset), 1 rejected with rationale (the singleton-skip demotion), and 6 bookkeeping dispositions: sprint-status 1-7 → done; `deferred-work.md` retirement of the landed 1.6 composeDay/nextDeal unification entry; `deferred-work.md` append of the tier-2 null-zone contract; the five new Matrix rows; the Code Map `_FakeBundle` pointer fix (`:22` → `:19`) with the line-number refresh; this review-fix spec artifact itself. Verified green: 162 core tests, `make check`, `make gate`, `flutter test test/weave`.
  - One iteration-1 pin re-stated, not reverted: `session_commands_test.dart` had pinned the phantom chunk (composeDay composing while a deal stood); it now pins the AD-3 pipeline line.
## Design Notes

- **All-time answered exclusion, not per-week windows.** Tiers 1-2 exclude entries ever answered: 20 zone + 12 `fondo` = 32 ≥ 28, so the floor holds over the combined pool by construction — each answered deal removes its entry from future tiers, and repetition enters only via tier 3, whose LRD order surfaces never-dealt entries first. Per-week windows would repeat week-old entries while new ones remain elsewhere. AC2's "exhausted within its week" is the fresh-run manifestation (a zone's ~5 entries cannot fill 7 days), not the window semantics.
- **Resolved-set parameter, not observation threading:** the timing derivation runs once per evaluation in the curation module (the `deriveLivePoolEnergy` precedent — shipped in 1.4 with no row source until 2.5); Epic 5's writer maps rows to observations and passes the derived set. One timing implementation, no facade/commands growth, existing call sites stay green via the default.
- **Ring rule:** `active = firstActiveAtOrAfter(Zone.values[weekOrdinal mod 5])` cyclically — plain rotation when all active; a disabled zone hands its week to the next active one as FR-11 words it.
- **The unification closes 1.6's deferred item:** one shared eligibility+tier+cap pipeline feeds `composeDay` and `nextDeal`, so they can no longer drift.
- **The AD-3 line lives in the shared pipeline now (iteration 2).** `_resolveDay` composes no chunk while the open session holds a dealt-but-unanswered card — upkeep and habit plans stand, `nextDeal` still returns null outright — so iteration 1's "cannot drift" claim is true at the compose level too, not only at the deal level; `nextDeal`'s own guard remains as the deal-level gate over maintenance and habit draws.
- **The ring has no catch-up (iteration 2).** A whole week with no session simply passes: the new week's zone deals first and the missed week's untouched entries wait for the tiers that follow — calendar-driven rotation, per AD-19 × FR-11. There is no backlog to repay and no ordinal to rewind.
- **Tier 2's null-zone discriminator is a contract to watch (iteration 2).** `fondo` is identified by `zone == null` on a focus candidate; when captured focus entries arrive (Epic 3) that membership contract needs deciding — recorded in `deferred-work.md`.

## Verification

**Commands:**
- `devbox run -- make test-core` -- expected: green, including the curation and extended weave suites
- `devbox run -- make check` -- expected: all registered checks green; nothing new to register
- `devbox run -- make gate` -- expected: test, format, analyze all green
- `devbox run -- flutter test test/weave` -- expected: the shipped-asset proofs green — the 28-deal run, the z5 week and the below-floor run

## Suggested Review Order

**The tier pipeline — the story's heart (AD-20)**

- The chunk tiers: zone never-answered → `fondo` never-answered → LRD any, repetition only at tier 3
  [`packages/core/lib/weave/weave.dart:279`](packages/core/lib/weave/weave.dart#L279)

- The resolver holds the AD-3 line itself — null while a deal is outstanding
  [`packages/core/lib/weave/weave.dart:445`](packages/core/lib/weave/weave.dart#L445)

- The active-zone ring: nominal ordinal position, first-active-at-or-after, disabled weeks pass on
  [`packages/core/lib/weave/weave.dart:187`](packages/core/lib/weave/weave.dart#L187)

- One shared policy feeds `composeDay` and `nextDeal` — the 1.6 unification, the AD-3 line included (iteration 2)
  [`packages/core/lib/weave/weave.dart:337`](packages/core/lib/weave/weave.dart#L337)

- Cluster filtering at the candidate source — every draw respects curation
  [`packages/core/lib/weave/weave.dart:162`](packages/core/lib/weave/weave.dart#L162)

**Rotation inputs (Calendar + consumption ledger)**

- The week ordinal — the one number the ring may read, owned by the one Calendar
  [`packages/core/lib/day/calendar.dart:135`](packages/core/lib/day/calendar.dart#L135)

- `answeredItemIds`: `card_done` rows only, all-time — what tiers exclude
  [`packages/core/lib/weave/session.dart:50`](packages/core/lib/weave/session.dart#L50)

**The curation model (the Epic-5 seam)**

- Cluster vocabulary + tuple→cluster mapping — `anclas`, `sostén`, `z1..z5`, `fondo`
  [`packages/core/lib/curation/curation.dart:34`](packages/core/lib/curation/curation.dart#L34)
- The mapping itself, fail-fast on drifted hand-built fixtures — `curationClusterOfEntry`
  [`packages/core/lib/curation/curation.dart:94`](packages/core/lib/curation/curation.dart#L94)

- The timing derivation: weekly at next week boundary, daily/`fondo` immediate, newest-effective wins
  [`packages/core/lib/curation/curation.dart:160`](packages/core/lib/curation/curation.dart#L160)

**Peripherals — the proofs**

- 28 answered chunks never repeat, pinned day-by-day on the shipped arithmetic
  [`packages/core/test/weave_test.dart:1289`](packages/core/test/weave_test.dart#L1289)

- The same property against the real asset via the loader
  [`test/weave/rotation_asset_test.dart:113`](test/weave/rotation_asset_test.dart#L113)

- The Epic-5 seam proven: `activeClustersAt` output rides into the weave
  [`packages/core/test/weave_test.dart:952`](packages/core/test/weave_test.dart#L952)

- AD-19 × ring: an open session keeps its start week's zone
  [`packages/core/test/weave_test.dart:912`](packages/core/test/weave_test.dart#L912)

- Timing edges: boundary-exact, Sunday change, pre-04:00 observations
  [`packages/core/test/curation_test.dart:175`](packages/core/test/curation_test.dart#L175)

- Ordinal invariants: consecutive weeks, epoch anchor, pre-epoch ring
  [`packages/core/test/day_test.dart:257`](packages/core/test/day_test.dart#L257)

**Iteration-2 additions**

- The pipeline holds the AD-3 line too: a dealt-but-unanswered card composes no chunk
  [`packages/core/test/weave_test.dart:296`](packages/core/test/weave_test.dart#L296)

- The AD-3 guard covers a maintenance deal too — the guard is size-agnostic
  [`packages/core/test/weave_test.dart:327`](packages/core/test/weave_test.dart#L327)

- `Card.zone`'s value contract: equality, hashCode, `toString` never `null`
  [`packages/core/test/weave_test.dart:700`](packages/core/test/weave_test.dart#L700)

- Missed week: no catch-up — the new week's zone deals first
  [`packages/core/test/weave_test.dart:823`](packages/core/test/weave_test.dart#L823)

- The seam's daily-cluster half: a mid-day `fondo` disable lands the same day
  [`packages/core/test/weave_test.dart:999`](packages/core/test/weave_test.dart#L999)

- Below-floor under an advancing ring: 20 distinct deals, then the repetition
  [`packages/core/test/weave_test.dart:1244`](packages/core/test/weave_test.dart#L1244)

- The shipped asset's z5 week and below-floor run, ids by capture
  [`test/weave/rotation_asset_test.dart:192`](test/weave/rotation_asset_test.dart#L192)

- The cross-origin clear guard at the walk level
  [`packages/core/test/session_test.dart:233`](packages/core/test/session_test.dart#L233)

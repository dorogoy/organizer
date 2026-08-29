---
title: 'Story 1.7 review iteration 2 — resolving the 18 review findings'
type: 'bugfix'
created: '2026-08-29'
status: 'done'
review_loop_iteration: 0
baseline_commit: '759200aab578173987edae7e899c3a874b4c609b'
context: ['_bmad-output/implementation-artifacts/1-7-zone-rotation-fondo-fill-and-the-below-floor-fallback.md']
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** The bmad-review pass over the done Story 1.7 artifact found 18 issues: one latent AD-3 hole (`composeDay` composes a phantom chunk while a deal stands unanswered), an origin-unchecked `walkLog` clear, a missing fail-fast on hand-built non-weekly entries carrying a zone, `Card.toString()` rendering the literal `null`, and eleven verification/doc gaps (boundary-exact weekly curation, the Epic-5 seam's daily-cluster half, below-floor under an advancing ring, missed-week semantics, z5 and below-floor against the shipped asset, `Card.zone` equality, plus tracker/registry/artifact bookkeeping).

**Approach:** Patch the four code sites, add the missing tests, extend the shipped-asset proofs, and reconcile the artifact (`matrix rows`, `Code Map`, `Review Findings`, `Design Notes`, `Spec Change Log`), `deferred-work.md` and `sprint-status.yaml` — the gate green throughout.

## Boundaries & Constraints

**Always:**
- The AD-3 outstanding-deal line moves into the shared policy pipeline: `composeDay` composes no chunk while a dealt-but-unanswered card stands (upkeep/habit plans still compose; `nextDeal` still returns null outright). The Design Note's "cannot drift" claim becomes true.
- `walkLog` clears `dealtUnanswered` only on an (itemId, itemOrigin) match — the command layer already holds this line; the walk now does too.
- `curationClusterOfEntry` fails fast, named, on a hand-built non-weekly entry carrying a zone — mirroring `_weeklyZoneOf`'s discipline. Parsed catalogues are unaffected (the parser already rejects the shape).
- `Card.toString()` renders an absent zone as `-`, never the literal `null`.
- Every new core test mirrors the house fixture arithmetic (5/3/4/5/3 zone focus + 12 fondo); the asset tests assert structure and ids-by-capture only, never hardcoded shipped ids.
- The 1.7 artifact's frozen block stays untouched; its `Review Findings`, `Design Notes`, `Spec Change Log`, `I/O & Edge-Case Matrix`, `Code Map` and `review_loop_iteration` (→ 2) are updated to record this iteration.

**Ask First:** None.

**Never:** No change to the pinned singleton-tier skip semantics — a skipped entry stays in its tier and re-deals before lower tiers (`weave_test.dart:296-324`); the edge-case finding against it is **rejected with rationale**, not patched. No new log kinds, ports, ARB keys, UI, asset or codegen changes, no new `tool/` scripts, no edits to the 1.7 frozen block, no `pool_facts` writes.

</frozen-after-approval>

## Code Map

- `packages/core/lib/weave/weave.dart` -- `_resolveDay` :335-377 (add the outstanding-deal chunk guard), `nextDeal` guard :440-445 (stays), tier pipeline :279-310 (unchanged semantics), `Card.toString` :113-116 (`-` rendering), `Card.==`/`hashCode` :99-111 (zone already participates).
- `packages/core/lib/weave/session.dart` -- `walkLog` clear :160-163 (add `itemOrigin` match; record has the pair :61).
- `packages/core/lib/curation/curation.dart` -- `curationClusterOfEntry` :92-100 (non-weekly-with-zone StateError); `_weeklyZoneOf` :102-111 is the error-message template to mirror.
- `packages/core/test/weave_test.dart` -- builders :12-126; tier/skip tests :228-324 (the pinned singleton re-deal at :296-324 is the rejection's anchor); ring group :640-919 (seam test :816-861, AD-19×ring :776); tier group :921-1099 (below-floor :1002, 28-deal :1045). New tests join these groups.
- `packages/core/test/curation_test.dart` -- helpers :9-19; weekly group :122-170 (add the boundary-exact observation test); tuple-mapping test :43-91 (extend with the throw).
- `packages/core/test/session_test.dart` -- `dealtUnanswered` tests :203-232 (add the cross-origin guard test).
- `test/weave/rotation_asset_test.dart` -- precondition block :116-137, 28-deal run :139-189 (add z5-week run and the below-floor run; ids by capture).
- `_bmad-output/implementation-artifacts/1-7-zone-rotation-fondo-fill-and-the-below-floor-fallback.md` -- Review Findings :81-94, Spec Change Log :96-99, Design Notes :101-106, Matrix :36-44, Code Map :57 (pointer `loader_test.dart:22` → `:19`).
- `_bmad-output/implementation-artifacts/deferred-work.md` -- retire the 1.6 unification entry (landed); append the null-zone tier-2 contract entry.
- `_bmad-output/implementation-artifacts/sprint-status.yaml` :45 -- `1-7-...` → `done`.
- `Makefile` -- `check` :42, `test-core` :30, `gate` :72; nothing new to register.

## Tasks & Acceptance

**Execution:**
- [x] `packages/core/lib/weave/weave.dart` -- suppress the chunk in `_resolveDay` while `facts.dealtUnanswered != null`; `toString` renders `zone?.name ?? '-'`; update the pipeline/composeDay docs -- the AD-3 line lives in the shared pipeline now
- [x] `packages/core/lib/weave/session.dart` -- clear `dealtUnanswered` only on (itemId, itemOrigin) match
- [x] `packages/core/lib/curation/curation.dart` -- named StateError for a non-weekly entry carrying a zone, mirroring `_weeklyZoneOf`
- [x] `packages/core/test/weave_test.dart` -- new tests: outstanding-deal composes no chunk; AD-3 guard with a maintenance card outstanding; `Card.zone` equality/hashCode/toString contract; the daily-cluster (fondo) seam riding `activeClustersAt` into the weave same-day; below-floor under an advancing ring (z1+z2 active, 20 distinct then day-21 repetition); a skipped full week — no catch-up
- [x] `packages/core/test/curation_test.dart` -- weekly observation exactly at Monday 04:00 (active through the boundary's week, away the week after); non-weekly-with-zone throw
- [x] `packages/core/test/session_test.dart` -- cross-origin `card_done` leaves a shipped-origin outstanding deal standing
- [x] `test/weave/rotation_asset_test.dart` -- a z5-week run dealing the asset's z5 entries; a below-floor run ({z1, fondo} active: 17 distinct then repetition of day 1's id, by capture)
- [x] `_bmad-output/implementation-artifacts/1-7-zone-rotation-fondo-fill-and-the-below-floor-fallback.md` -- five new Matrix rows; `Code Map` pointer fix; Review Findings entries for iteration 2 (patched x, rejected x); Spec Change Log entry; Design Notes (pipeline guard, missed-week no-catch-up, null-zone tier-2 contract pointer); `review_loop_iteration: 2`
- [x] `_bmad-output/implementation-artifacts/deferred-work.md` -- retire the 1.6 unification entry; append the null-zone tier-2 contract entry
- [x] `_bmad-output/implementation-artifacts/sprint-status.yaml` -- mark 1-7 `done`

**Acceptance Criteria:**
- Given an open session holding a dealt-but-unanswered card, when the day composes, then no chunk is composed while the upkeep/habit plans stand, and `nextDeal` still yields null
- Given a walkLog over a `card_done` row whose origin differs from the outstanding deal's, when the facts derive, then `dealtUnanswered` stands
- Given a hand-built non-weekly entry carrying a zone, when its cluster derives, then a named `StateError` names the entry
- Given a weekly observation made exactly at Monday 04:00, when the derivation evaluates at that boundary and beyond, then the zone stays active for the boundary's week and turns away only at the next week boundary
- Given a `fondo` disable observed mid-day, when the weave composes that same day, then `fondo` entries leave the chunk tiers immediately
- Given curation leaving fewer than 28 eligible with z1 and z2 active, when 21 days run, then the ring advances across weeks and 20 distinct deals precede the day-21 tier-3 repetition — never an empty day
- Given a whole week with no session, when the next week composes, then the new week's zone deals first — no catch-up
- Given the shipped asset, when a z5-week run deals, then the asset's z5 entries deal; and given the below-floor active set, when 18 days run, then 17 distinct deals precede the repetition
- Given two cards differing only in zone, then they compare unequal and `toString` renders the zone — and never `null`
- Given the completion gate, then `make check`, `make test-core`, `make gate` and `flutter test test/weave` are green

## Spec Change Log

## Design Notes

- **The singleton-skip finding is rejected, not patched.** The frozen intent says a skip consumes nothing and the entry stays in its tier; `weave_test.dart:356-384` pins the consequence — the skipped entry re-deals before `fondo` once its zone-mates are answered. The finding's "demote to tier 2" would contradict both.
- **The pipeline guard closes the drift the unification claimed.** With the outstanding-deal check inside `_resolveDay`, `composeDay` and `nextDeal` read one policy; `nextDeal`'s guard remains as the deal-level gate over maintenance/habit draws.
- **The ring has no catch-up:** a week with no session simply passes — the new week's zone deals first. Calendar-driven rotation, per AD-19 × FR-11.

## Verification

**Commands:**
- `devbox run -- make test-core` -- expected: the core suite green, including every new pin
- `devbox run -- make check` -- expected: all registered checks green; nothing new to register
- `devbox run -- make gate` -- expected: test, format, analyze all green
- `devbox run -- flutter test test/weave` -- expected: the extended shipped-asset tests green

## Suggested Review Order

**The AD-3 pipeline line — the change's heart**

- The outstanding-deal check inside the shared pipeline: composeDay and nextDeal read one policy
  [`weave.dart:351`](../../packages/core/lib/weave/weave.dart#L351)

- The deal-level twin stays: null outright while a deal stands
  [`weave.dart:445`](../../packages/core/lib/weave/weave.dart#L445)

- The compose-level pin: no chunk over a standing deal, upkeep and habits stand
  [`weave_test.dart:296`](../../packages/core/test/weave_test.dart#L296)

- The guard is size-agnostic: a maintenance deal holds the line too
  [`weave_test.dart:327`](../../packages/core/test/weave_test.dart#L327)

- The command-level re-pin: the foreign-Hecho flow under the new reality
  [`session_commands_test.dart:153`](../../packages/core/test/session_commands_test.dart#L153)

**The walk's pair-scoped clear**

- The clear matches (itemId, itemOrigin) — the command layer's line, now the walk's
  [`session.dart:163`](../../packages/core/lib/weave/session.dart#L163)

- Cross-origin done: the deal stands, the answer still lands all-time, the slot still closes
  [`session_test.dart:233`](../../packages/core/test/session_test.dart#L233)

**Curation's fail-fast widened**

- A non-weekly entry carrying a zone fails named, cadence-wide
  [`curation.dart:95`](../../packages/core/lib/curation/curation.dart#L95)

- Both rejected shapes pinned: daily-with-zone and seasonal-with-zone
  [`curation_test.dart:108`](../../packages/core/test/curation_test.dart#L108)

**The Card value contract**

- Absent zone renders `-`, never the literal null
  [`weave.dart:114`](../../packages/core/lib/weave/weave.dart#L114)

- Exact-string pins on a hyphen-free card; equality and equal-hash, no hash-distinctness claims
  [`weave_test.dart:700`](../../packages/core/test/weave_test.dart#L700)

**The seam and the timing edges**

- The daily-cluster half of the Epic-5 seam: a mid-day fondo disable lands same-day
  [`weave_test.dart:1029`](../../packages/core/test/weave_test.dart#L1029)

- The weekly observation made exactly at the boundary: its own week keeps the zone
  [`curation_test.dart:197`](../../packages/core/test/curation_test.dart#L197)

**The rotation semantics pinned**

- Missed week: no catch-up — 27 non-z1 deals, then the ring's return deals z1-a
  [`weave_test.dart:822`](../../packages/core/test/weave_test.dart#L822)

- Below-floor under an advancing ring: 20 distinct, then the day-21 repetition
  [`weave_test.dart:1274`](../../packages/core/test/weave_test.dart#L1274)

**Peripherals — the shipped asset and the registries**

- The asset's z5 week deals its own entries, ids by capture
  [`rotation_asset_test.dart:192`](../../test/weave/rotation_asset_test.dart#L192)

- The asset's below-floor run: 17 distinct, then the first id's repetition
  [`rotation_asset_test.dart:243`](../../test/weave/rotation_asset_test.dart#L243)

- The 18-finding ledger: 11 patched, 1 rejected, 6 bookkeeping — iteration 2
  [`1-7-zone-rotation-fondo-fill-and-the-below-floor-fallback.md`](1-7-zone-rotation-fondo-fill-and-the-below-floor-fallback.md)

- The deferred contract notes: tier-2 membership and the session-scoped fact
  [`deferred-work.md`](deferred-work.md)

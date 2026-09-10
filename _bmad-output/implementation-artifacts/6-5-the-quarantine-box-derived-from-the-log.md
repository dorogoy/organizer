---
title: '6-5: The Quarantine Box, derived from the log'
type: 'feature'
created: '2026-09-10'
status: 'done'
review_loop_iteration: 0
baseline_commit: '1af5c2e98c671447cdaec5c00815c6736aad5403'
context: ['_bmad-output/implementation-artifacts/epic-6-context.md']
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** 6-4's flow closes the letting-go decision with exactly three destinations — the hesitated item has nowhere to go, so hesitation reopens the decision every visit (FR-21 unstarted: no `box_created`, no `quarantine` destination value, no box linkage).

**Approach:** Add the quarantine act end to end: the destination vocabulary gains the additive `quarantine` value (AD-23); the flow gains one quiet text affordance below the trio whose tap appends `box_created` (the box's date is the row's own instant, AD-4) plus an `item_triaged` row carrying `quarantine` and linked to that box's pre-minted id, completing the purge card in the same one-instant queued write; a pure core derivation reconstructs boxes from those two kinds alone — no quarantine table, no stored follow-up date (AD-1).

## Boundaries & Constraints

**Always:** `quarantine` joins `TriageDestination` additively (wire name `quarantine`); `box_created` joins `LogKind` (wire `box_created`) with **no payload columns** — the row's instant is the box's date and its id is the link target. The `item_triaged` payload gains one nullable additive column `triage_box_id` (schema v13, named ALTER const, the v2→v11 pattern — no rebuild, no data migration). The box id is pre-minted v7 before the appends (the rescue-seeds precedent) so the triage row can link it. Act order in one queued write, one act instant, staleness guard decided before any append: `box_created` → `item_triaged(quarantine, boxId)` → `card_done` → bundled `card_dealt`. The handed-off volume tag does **not** ride the quarantine row (a quarantined item liberates nothing — FR-22/AD-26 honesty). The derivation is a pure fold in `packages/core/lib/derive/`: boxes from `box_created` rows in log order, contents from `item_triaged` rows whose destination is `quarantine` and whose `boxId` matches; orphans (missing/unmatched link) are skipped, never invented into boxes. The entry affordance on the flow is **text-only** in the support role below the trio — no glyph (silhouette differentiation is load-bearing among the trio; the Caja silhouette already means keep), not constructionally a fourth destination row, ≥48dp target, label wraps at 200%, Semantics button, and it shares the rows' one-shot guard and pop-only-on-success path. One new ARB key `destinationQuarantine` with copy `Todavía no lo decido` (proposed — the hesitation in the user's own voice, a valid outcome, no shame register). 6.3's absence pins flip: `quarantine` joins the wire map and leaves the unknown-name list, which keeps a still-unknown name to pin AD-23 tolerance.

**Ask First:** None — the entry's shape follows FR-20's three-equal-rows invariant plus the surface map siting; renegotiate the ARB copy or the affordance's form before inventing any further surface (no box-contents view, no date picker).

**Never:** No quarantine table, box-contents surface, or stored follow-up date anywhere (AD-1 — six-month logic is 6.6, which consumes `StripResident.quarantineFollowUp`, already reserved and staying unreachable here). No change to the trio rows' construction, order or equal weight (FR-20, UX-DR27). No new glyph. No metric, count or volume figure on any surface (6.7). No numeric volume on the row. No multi-item box UI — each act mints its own `box_created` (AC-literal); same-date boxes stay distinct rows, and any date-collapse is 6.6's derivation concern.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Quarantine tap | Flow current, affordance tapped | `box_created` + `item_triaged(quarantine, boxId)` + `card_done` + next `card_dealt`, all one act instant (UTC + offset); flow pops; next card dealt; purge id retired | Quiet catch; flow stands; guard re-arms |
| Tagged batch hesitates | Protocol handed off a volume tag | Quarantine row carries **no** tag; tag writes nothing | N/A |
| Back from flow | System back before any tap | Nothing written; purge card stands (unchanged) | N/A |
| Mid-batch failure | Append throws after the box row | Earlier rows stand (the tolerated partial-act class); retry appends a fresh box beside them | Quiet; re-entry retries |
| Stale double act | Card already answered | Nothing appended — guard decided before any append, box row included | N/A |
| Orphan at derive | Quarantine row's `boxId` matches no `box_created` | Row skipped from contents; no box invented | Tolerated, forward-only |
| Reconstruction | Log with several boxes + linked rows | Boxes in log order, contents by link only — no other source consulted | N/A |
| Pre-6.5 build reads new log | `quarantine` destination row on the wire | Excluded at that build's read boundary (flaw) — the 6.3 tolerance pin, re-pinned with a still-unknown name | Never coerced |

</frozen-after-approval>

## Code Map

- `packages/core/lib/log/log_entry.dart` -- the whole substrate seam: `TriageDestination` (:134) + closed wire map `triageDestinationByName` (:152); `LogKind` (:204), kind constants (:243), `knownByName` (:246), unknown-name-tolerant `parse` (:288); `TriageEntry` (:697); `convertLogEntryRecord` (:1505) with the per-kind foreign-column discipline; `LogEntry` shape (:294: `id` v7, `instantUtcMicros`, `offsetSeconds`). Add `quarantine`, `boxCreated`, `TriageEntry.boxId`, `BoxCreatedEntry`, the convert branch, the record field.
- `packages/core/lib/commands/triage_commands.dart:31` -- `triageItem`, the sanctioned minter; grows optional `boxId`. Add the `boxCreated()` minter beside it (kind-only content).
- `packages/core/lib/ports/store_port.dart:86` -- `LogEntryRecord`, the wire typedef; grows `triageBoxId`.
- `lib/store/substrate.dart:189-204` -- the v12 additive pattern (named ALTER consts `logEntriesTriageDestinationUpgrade`/`…VolumeTagUpgrade`, `schemaVersion`): v13 = same shape, `triage_box_id TEXT NULL`, drift column wired.
- `lib/dispenser/dispenser_controller.dart` -- `triageAndComplete` (:630) and `_enqueueCompleteWrite` (:653: staleness guard before any append, triage prelude :683, completion :687) are the act's template; `_appendContent` (:881) mints the id per row — the box row needs the pre-minted id threaded (rescue seeds precedent :840-844).
- `lib/ui/destinations/destination_flow_screen.dart` -- trio hardcoded in `build` (row keys :30-32, callback seam :43, one-shot `_handOff` :65, row builder :124); the affordance slots after the third row and reuses `_handOff`'s guard/pop via its own callback seam.
- `lib/ui/dispenser/dispenser_screen.dart:646` -- `_onDestinationTap` (guard, quiet catch, bool answer) and its call site :659 — `_onQuarantineTap` mirrors it; push grammar :606.
- `lib/ui/tokens.dart:144` -- the `support` role the affordance's label takes; destination spacing :240/:246 stays the trio's own.
- `packages/core/lib/derive/` -- the house derivation pattern (pure folds over `List<LogEntry>`: `deriveStrip` strip.dart:429, `warmReturnDue`); new `quarantine.dart` joins them. `StripResident.quarantineFollowUp` (strip.dart:67) stays reserved and unreachable — 6.6's consumer.
- `lib/l10n/app_es.arb:139-152` -- the destination keys' neighborhood; `destinationQuarantine` lands beside them with its `@` description.
- `packages/core/test/log_test.dart:2026-2138` -- 6.3's absence pins that flip verbatim expectations (wire map gains `quarantine`, `hasLength(4)`, `'quarantine'` leaves the unknown-destination list).
- `test/dispenser/dispenser_controller_test.dart:40` -- `_RecordingStore` (+ failure wrappers) for act-order pins.
- `test/ui/dispenser/dispenser_screen_test.dart:6666` -- `purgeStore()` end-to-end purge scaffolding.
- `test/ui/destinations/destination_flow_screen_test.dart` -- `pumpFlow` host; the exactly-three-rows pins gain the affordance's distinctness pin.

## Tasks & Acceptance

**Execution:**
- [x] `packages/core/lib/log/log_entry.dart` -- `quarantine` destination, `boxCreated` kind + `BoxCreatedEntry`, `TriageEntry.boxId`, convert branch + record field, foreign-column discipline — AD-23 additive, FR-21, AD-21.
- [x] `packages/core/lib/commands/triage_commands.dart` -- `triageItem` optional `boxId`; `boxCreated()` minter — one sanctioned minter per kind.
- [x] `lib/store/substrate.dart` -- schema v13: named `triage_box_id` ALTER const + drift column, old rows unchanged — the v12 pattern.
- [x] `packages/core/lib/derive/quarantine.dart` (new) -- `deriveQuarantine`: pure fold, boxes in log order, contents by link, orphans skipped — AD-1.
- [x] `lib/dispenser/dispenser_controller.dart` -- `quarantineAndComplete`: pre-minted box id, box row + triage row prelude inside `_enqueueCompleteWrite`'s guarded write, no tag — one instant, AD-3/AD-21.
- [x] `lib/ui/destinations/destination_flow_screen.dart` -- the quiet text affordance below the trio, own callback seam, shared one-shot guard — FR-20 equality untouched.
- [x] `lib/ui/dispenser/dispenser_screen.dart` -- `_onQuarantineTap` mirroring `_onDestinationTap` — the only act path.
- [x] `lib/l10n/app_es.arb` -- `destinationQuarantine` + description — AD-15.
- [x] Tests: flip `packages/core/test/log_test.dart:2026-2138`; new derive pins; controller act-order/no-tag/stale/partial-failure pins; flow-affordance pins; end-to-end `purgeStore()` pin — cover the matrix.

**Acceptance Criteria:**
- Given a quarantine tap, when the log is read, then `box_created` precedes `item_triaged` carrying `quarantine` and the box's id, then `card_done` + `card_dealt`, all stamped from one act instant — and the row carries no volume tag even when the visit handed one off.
- Given the log, when `deriveQuarantine` runs, then boxes and their contents come from `box_created` and linked `item_triaged` rows alone, in log order — and no schema field anywhere stores a follow-up date or box membership.
- Given the flow rendered, when audited, then the three destination rows remain constructionally identical and the quarantine affordance carries no glyph and no destination-label role — not readable as a fourth equal choice.
- Given a pre-6.5 log and a post-6.5 log, when both are read, then every existing row converts identically and the v13 column is additive only.

### Review Findings

- [x] [Review][Patch] `triageItem` could mint a tag beside a box link (and a box link on a non-quarantine row) while its docs claimed otherwise — the minter now asserts the shape by construction; violations pinned
- [x] [Review][Patch] `_enqueueCompleteWrite` accepted both preludes at once — mutual-exclusivity assert added (the one-prelude act shape)
- [x] [Review][Patch] `_onQuarantineTap` was a ~60-line verbatim copy of `_onDestinationTap` — shared body extracted into `_runCompletionAct` [dispenser_screen.dart:647]
- [x] [Review][Patch] Warm-return contact for `box_created` and quarantine `item_triaged` rows was unpinned — anchor-moves test extended (incl. the lone-box partial-act shape) [warm_return_test.dart]
- [x] [Review][Patch] The affordance's 200% wrap pin was vacuous (`didExceedMaxLines` can never be true without maxLines) — real wrap assertion via line-top counting
- [x] [Review][Patch] `Spacing.touchTargetMin` (a platform constant) repurposed as the below-trio gap — named `Spacing.destinationAsideGap = 48` token
- [x] [Review][Patch] No screen-level test drove `_onQuarantineTap`'s failure path — `_FailFirstBoxStore` pin: quiet catch, guard released, in-place retry lands the fresh-box act
- [x] [Review][Patch] The between-rows partial (fail after `box_created`, before `item_triaged`) was untested at controller level — `_FailAfterBoxStore` pin: orphan box read back as an honest empty box, retry appends a fresh one
- [x] [Review][Patch] `QuarantineBox` record `==` is reference-equal on `contents` — identity semantic documented in the typedef (compare per-field or by id)
- [x] [Review][Patch] `_handOff`'s doc said "re-entry is the retry" while the code re-arms in place — comment fixed to match the pinned behavior
- [Defer] Sprint-status drift: 6-3 reads `review` in sprint-status while its artifact is `done` — deferred-work.md
- [Reject] Verification-evidence recording (step-05 presentation is the mechanism); brittle-in-index test pins (local fixtures)

## Spec Change Log

## Design Notes

Why text-only: FR-20/UX-DR27 pin the flow as three equal rows and nothing else — a fourth glyph row would either break the trio's equality or need a new authored glyph, and the ten-glyph register already spends the Caja silhouette on keep. The quiet text affordance reads as a way-out (the Settings quiet-text register), which is what hesitation is here: a valid outcome, not a fourth destination. Proposed copy `Todavía no lo decido` keeps the first-person, anti-shame register and claims nothing about any box.

One `box_created` per act is AC-literal ("a `box_created` entry is appended") and the only insert-only shape: box membership exists only as the link on the triage row, so a box with no members is simply a `box_created` row (a failed retry's orphan box reconstructs as an empty box — honest, coarse). Six-month follow-up derivation (6.6) may collapse same-date boxes; that decision stays 6.6's.

## Verification

**Commands:**
- `devbox run -- make gate` -- expected: `flutter test`, format, analyze and repository checks green, including the flipped 6.3 pins, the derive pins, and the act-order pins.

## Suggested Review Order

**The derivation (AD-1 made visible)**

- The whole story in one function: boxes from `box_created` alone, contents by link, orphans skipped, no stored date.
  [`quarantine.dart:56`](../../packages/core/lib/derive/quarantine.dart#L56)

- The identity-semantic doc: record `==` is reference-equal on `contents` — compare per-field or by id.
  [`quarantine.dart:26`](../../packages/core/lib/derive/quarantine.dart#L26)

**The substrate (additive vocabulary)**

- `quarantine` joins the closed wire map — the AD-23 additive value 6.3 reserved.
  [`log_entry.dart:171`](../../packages/core/lib/log/log_entry.dart#L171)

- The new kind, payload-less by design: the row's instant is the box's date, its id the link target.
  [`log_entry.dart:264`](../../packages/core/lib/log/log_entry.dart#L264)

- `TriageEntry.boxId` — the one additive link field, read by the empty-is-not-a-value rule.
  [`log_entry.dart:760`](../../packages/core/lib/log/log_entry.dart#L760)

- The minter's by-construction guard: a box link rides only a tagless quarantine row.
  [`triage_commands.dart:53`](../../packages/core/lib/commands/triage_commands.dart#L53)

**Schema v13**

- One nullable `triage_box_id` column, ALTER-only on the v12 pattern; version 13.
  [`substrate.dart:175`](../../lib/store/substrate.dart#L175)

**The act**

- Pre-minted box id at entry, then box row → linked triage row → completion inside the guarded write, one instant.
  [`dispenser_controller.dart:668`](../../lib/dispenser/dispenser_controller.dart#L668)

- The one-prelude shape asserted: `triage` and `quarantineBoxId` never both.
  [`dispenser_controller.dart:689`](../../lib/dispenser/dispenser_controller.dart#L689)

**The entry surface**

- The hesitation affordance: text alone in the support role below the trio — not a fourth equal choice.
  [`destination_flow_screen.dart:170`](../../lib/ui/destinations/destination_flow_screen.dart#L170)

- Its separation token: the aside gap, not the touch-target floor.
  [`tokens.dart:246`](../../lib/ui/tokens.dart#L246)

- The authored string, verbatim.
  [`app_es.arb:154`](../../lib/l10n/app_es.arb#L154)

- Both taps' shared completion body — one implementation, no mirrored copy.
  [`dispenser_screen.dart:647`](../../lib/ui/dispenser/dispenser_screen.dart#L647)

**Verification**

- The derivation's own pins: log order, link-only contents, orphans, empty box, purity.
  [`quarantine_test.dart:44`](../../packages/core/test/derive/quarantine_test.dart#L44)

- The end-to-end act: tag handed off, quarantine row carries none; quartet order, one instant.
  [`dispenser_screen_test.dart:7025`](../../test/ui/dispenser/dispenser_screen_test.dart#L7025)

- The two partial-act pins: fail-before-triage at the screen, fail-between-rows at the controller.
  [`dispenser_screen_test.dart:7205`](../../test/ui/dispenser/dispenser_screen_test.dart#L7205), [`dispenser_controller_test.dart:186`](../../test/dispenser/dispenser_controller_test.dart#L186)

- The flipped 6.3 pins: four-member map, `quarantine` converts, unknown stays excluded.
  [`log_test.dart:2026`](../../packages/core/test/log_test.dart#L2026)

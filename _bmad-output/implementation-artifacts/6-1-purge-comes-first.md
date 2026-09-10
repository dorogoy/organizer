---
title: '6-1: Purge comes first'
type: 'feature'
created: '2026-09-09'
status: 'done'
review_loop_iteration: 0
baseline_commit: '99ecd65374c201f937cafe00c24d9e3db942fe3b'
context: ['_bmad-output/implementation-artifacts/epic-6-context.md']
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** Organizing Epic Projects (Epic 5) deal their organization steps from the moment they activate, so the user can spend a session arranging what they should have let go of first. FR-19: purge Micro-tasks are prepended before any organization step; the first dealt Micro-task of a newly activated project is always a purge step (PRD UJ-2: "before step 1, the Decluttering Protocol injects a pre-clean purge micro-step").

**Approach:** One derived purge Micro-task per activated organizing group, joined as a new candidate source with precedence directly above `epic` — never a special case in the weave (AD-20: the resolver stays the only deal emitter). The purge card renders as an ordinary dispenser-card; its `Hecho` enters a minimal Decluttering Protocol surface frame reached only from that card (UX-DR31). The protocol's questions and destinations are later stories (6.2/6.4); this story ships the injection and the entry route only.

## Boundaries & Constraints

**Always:**
- Purge injection is a candidate-precedence rule: `core/weave` remains the only code that emits a deal; purge steps return candidates like every other source.
- One purge step per activated group, prepended before that group's organization steps; synthetic stable id `purge:{groupStableId}`; estimate ≤ 60 s so it passes the 🔴 exclusion and pocket filters by construction.
- Purge state is derived, never stored (AD-1): pending iff the group is activated and no terminal act (`card_done`/`card_skipped`) names its purge id.
- The purge card is an ordinary `dispenser-card`: same furniture (DurationChip, `Hecho`, secondary control, ZoneMarker iff zone), no distinct style, frame or announcement (FR-1).
- Every new string lands in the flat ARB table with an `@` block and joins the SM-C2 audit; no literals in code (AD-15).
- Completion gate: `flutter test`, `dart format --set-exit-if-changed .`, `flutter analyze` — all green inside `devbox shell`.

**Ask First:**
- The purge card's authored task-text wording (proposed: `purgeStepText` = "Elegir un objeto del espacio y decidir sobre él") — SM-C2 copy is human-owned; reword freely at review.
- Any need for a new log kind, new append site, or string-table audit exception — none is expected.

**Never:**
- No detachment questions, destination flow, glyphs, quarantine or triage recording — stories 6.2–6.5.
- No new log kinds or append sites: `card_done`/`card_skipped` via the existing complete/skip paths carry the purge terminal acts.
- No menu, list, or second entry to the Decluttering Protocol — the dealt purge card is the only way in (UX-DR31).
- No stored purge state, no quarantine table, no re-dealing after skip (a skipped purge closes it — the app does not nag; FR-19's first-dealt guarantee already holds).
- Rescue and capture keep their in-flight priority above purge; `epic` and `catalogue` stay below.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Fresh activation | Group activated, nothing else pending | Next deal for that group is its purge candidate, before any of its steps | N/A |
| Capture in flight | Pending capture when project activates | Capture deals first (in-flight), then purge, then steps | N/A |
| Purge done | `card_done` names `purge:{id}` | Purge candidate gone; the group's steps become eligible | N/A |
| Purge skipped | `card_skipped` names `purge:{id}` | Purge closes — no re-deal, no nagging; steps eligible | N/A |
| Two un-purged groups | Both activated, neither purged | Purge candidates arbitrate LRS like epic material; each group's own first dealt is its purge | N/A |
| Low energy / small pocket | 🔴 day or sub-10-min bag | Purge still deals (≤ 60 s passes the estimate filters) | N/A |
| Rapid tap on Hecho | Purge card, double tap | Existing `isCurrent` navigation guard applies | N/A |

</frozen-after-approval>

## Code Map

- `packages/core/lib/weave/weave.dart:136` — `CandidatePrecedence`; its doc (:134) already reserves purge as "a member, never a flag".
- `packages/core/lib/weave/weave.dart:392` — `epicCandidates` (grouping :349, head selection, LRS arbitration :428-457): the supplier `purgeCandidates()` sits beside, deriving from the same group walk.
- `packages/core/lib/weave/weave.dart:868-880` — the one candidate list in `_resolveDay`; 🔴 filter :853 (comment :849 names Epic 6's purge, ≤ 60 s); chunk-pool filter :889; maintenance/instant draw exclusions :953-954/:965-966 — purge mirrors `epic`'s treatment everywhere.
- `packages/core/lib/weave/weave.dart:1081` — `_guardedTierDealOf` deal ladder: purge tier sits directly above epic; entry `nextDeal` :1051.
- `packages/core/lib/weave/session.dart:354-360` — `epicActivatedInstantByStableId` fold: activation input; terminal-act lookup for the synthetic id reuses the answered/skipped folds the head selection already reads.
- `packages/core/lib/pool/pool_fact.dart:26,:79` — `Size` and banding for the ≤ 60 s estimate.
- `lib/dispenser/dispenser_controller.dart:121-146` — `DispenserDealt` fields; `rescueStep` flag derived in `read()` ~:528-553 is the exact pattern for a `purgeStep` discriminator.
- `lib/ui/dispenser/dispenser_screen.dart:415-434` — `_onSecondaryAction`'s flag-branch pattern; `_onRescue` :453 pushes a surface; entry precedents `_openScan` :1189 (Navigator.push + isCurrent guard).
- `lib/ui/dispenser/task_card.dart:132` — ordinary card furniture the purge card reuses unchanged.
- `lib/l10n/app_es.arb` — flat table + `@` blocks; register: concrete household actions (`catalogueRecoger3CosasDelSuelo` :569).
- `lib/ui/glyphs/box_glyph.dart` — destination trio glyphs exist (1.2); untouched here.

## Tasks & Acceptance

**Execution:**
- [x] `packages/core/lib/weave/weave.dart` -- add `CandidatePrecedence.purge` (between `capture` and `epic`); add `purgeCandidates()` deriving one synthetic candidate (`purge:{groupStableId}`, ≤ 60 s estimate, authored text) per activated group lacking a terminal act on that id; join it in `_resolveDay`'s list; place its tier above `epic` in `_guardedTierDealOf`; mirror `epic`'s treatment in the maintenance/instant draw exclusions and chunk-pool filter -- FR-19 + AD-20.
- [x] `packages/core/lib/weave/session.dart` -- expose the terminal-act-by-itemId lookup the purge derivation needs, reusing the existing answered/skipped folds -- derivation input, no stored state (AD-1).
- [x] `lib/l10n/app_es.arb` -- add `purgeStepText` + `@` block; run `make codegen` -- AD-15, SM-C2 audit.
- [x] `lib/dispenser/dispenser_controller.dart` -- derive a `purgeStep` discriminator on `DispenserDealt` in `read()`, `rescueStep`'s pattern -- the shell's only signal for routing.
- [x] `lib/ui/destinations/decluttering_protocol_screen.dart` -- NEW: minimal protocol frame (surface-base, one `Hecho` that funnels to the existing complete path appending `card_done` on the purge id, then closes); no copy of its own yet -- UX-DR31's surface, entered only from the purge card.
- [x] `lib/ui/dispenser/dispenser_screen.dart` -- `Hecho` on a purge card routes to the protocol frame (`_openScan`'s Navigator pattern, isCurrent guard) instead of completing directly; skip stays the ordinary path -- UX-DR31.
- [x] `packages/core/test/weave_test.dart` -- new purge group: fresh-activation first-dealt, purge-before-steps, done/skip closure, two-group LRS, capture-outranks-purge, 🔴/pocket admission -- pin FR-19.
- [x] `test/no_lateness_proof_test.dart` -- renegotiate the frozen declaration census for the new `CandidatePrecedence` member (:1357); no other census changes (no new kinds or append sites) -- keep the fence honest. *(Verified: no renegotiation needed — the census is keyed by declaration name and already exempts `CandidatePrecedence`; the member addition is invisible to it.)*
- [x] `test/dispenser/dispenser_controller_test.dart` + the dispenser widget suite -- pin: purge card renders with ordinary furniture; `Hecho` routes to the protocol frame; frame `Hecho` appends `card_done` and closes; skip appends `card_skipped` -- FR-1 + UX-DR31.

**Acceptance Criteria:**
- Given a newly activated organizing project, when its first Micro-task is dealt, then it is always the purge step.
- Given a pending purge, when the resolver runs, then no organization step of that group deals before it, and the deal still comes only from `core/weave`.
- Given the dealt purge card, when it renders, then it is indistinguishable in furniture and styling from an ordinary step card.
- Given the dealt purge card, when `Hecho` is tapped, then the Decluttering Protocol surface opens — and no menu, list or other route to it exists.
- Given the protocol frame, when its `Hecho` completes, then one `card_done` names the purge id and the dispenser returns to the next deal.

## Spec Change Log

## Design Notes

- Precedence reading: FR-19 scopes to "before any organization step" — captures (pending user material) and rescue (re-slices of in-flight steps) are commitments, not organization steps, so they keep priority; purge sits directly above `epic`. The enum's index order is the arbitration — no tiebreak code beyond it.
- The protocol frame completing via the existing complete path (not a new append site) is what keeps `no_lateness_proof`'s append census untouched; 6.2+ replace the frame's body, never its completion plumbing.
- Synthetic-id + terminal-act closure mirrors how shipped catalogue candidates work today — no new mechanism.

*As-built addenda (implementation):*
- Ladder reading: the purge tier lives in `_guardedTierDealOf` directly below the chunk and above every epic door, PLUS a purge tier inside `_chunkCandidateOf` (the chunk pool) above the epic tier — the unique arrangement satisfying all pinned constraints at once (rescue/capture above purge; no organization step before its purge; the purge still deals on days the chunk does not compose, e.g. 🔴 or a sub-floor bag).
- `purgeStepText` is a nullable seam through `nextDeal`/`composeDay`/`dealExistsIgnoringPocket`/`cardForItem`: null (the default) derives no purge candidate — every pre-existing core test's world stays unchanged, and production callers thread the ARB string on every path. No caller may ship null.
- One pre-existing 5.10 **widget-suite** fixture (seven-day absence, Epic mid-plan) now seeds a terminal purge act — its mid-plan intent requires the purge answered in 6.1's world.
- `autoRescueDue` never derives true on a purge card (the synthetic id is never a re-slice candidate; its skip is terminal).

## Verification

**Commands:**
- `devbox run -- make gate` -- expected: test, format, analyze, and the `tool/` checks (store seal, string-table audit) all green.
- `devbox run -- make codegen` -- expected: `purgeStepText` generated into `lib/strings/app_strings.dart`.

**Manual checks (if no CLI):**
- On the emulator: activate a project (genesis or seeded), confirm the dealt card is the purge card with ordinary furniture; `Hecho` opens the protocol frame; completing returns to the dispenser with the project's first step dealt next.

**Manual Verification (emulator pass, 2026-09-10, Android 36 `organizer36`, seeded `man-epic-6-1-a` world):**

- [x] The seeded walk **found a real defect**: `cardDone` accepted `purgeStepText` and dropped it at its `_answered` delegation — a `Hecho` on any card bundled a shipped maintenance draw instead of the pending purge (FR-19 broken on the completion path; skip/declare/extend were threaded). Fixed (one-line forward) + pinned by two `session_commands_test` cases (complete and skip both bundle the purge). The controller tests had missed it because they completed the purge itself, never a non-purge card with a purge pending.
- [x] After the fix: `Hecho` on the standing shipped card deals `card_dealt(purge:man-epic-6-1-a)` — the card renders ordinary (authored text verbatim, `1 min` chip, unsplit secondary).
- [x] The purge card's `Hecho` opens the Decluttering Protocol frame: full-screen surfaceBase, no copy of its own, one `Hecho` — the only entry.
- [x] The frame's `Hecho` appends exactly one `card_done` naming the purge id and returns to the dispenser; the next deal is a maintenance draw (the day's focus slot was already consumed) — no organization step of the group dealt before the purge.
- [x] Final census: `app_opened, session_started, card_dealt(shipped), epic_activated, app_opened, card_done(shipped), card_dealt(purge:…), card_done(purge:…), card_dealt(shipped)` — no spurious rows.

## Suggested Review Order

**Purge injection as a candidate source (the core design)**

- Entry point: the new precedence member, directly above `epic` — the whole rule is one enum slot.
  [`weave.dart:134`](../../packages/core/lib/weave/weave.dart#L134)

- The derivation: one synthetic candidate per activated group, closed by a terminal act, LRS-arbitrated via the shared comparator.
  [`weave.dart:534`](../../packages/core/lib/weave/weave.dart#L534)

- The chunk pool's purge tier: no organization step composes while a purge stands.
  [`weave.dart:868`](../../packages/core/lib/weave/weave.dart#L868)

- The ladder's purge tier: the purge still deals when the chunk doesn't (🔴 day, sub-floor bag).
  [`weave.dart:1273`](../../packages/core/lib/weave/weave.dart#L1273)

**Charging the synthetic card (AD-1: derived, never stored)**

- Purge-aware size/estimate resolvers: a dealt purge charges one instant slot; an answered one charges 60 s, never the 30 s size default.
  [`session.dart:350`](../../packages/core/lib/weave/session.dart#L350)

**Shell routing (UX-DR31: the card is the only door)**

- The discriminator: prefix-derived on `DispenserDealt`, the shell's only routing signal.
  [`dispenser_controller.dart:162`](../../lib/dispenser/dispenser_controller.dart#L162)

- The purge `Hecho` opens the protocol frame, guarded like every entrance (in-flight + isCurrent).
  [`dispenser_screen.dart:573`](../../lib/ui/dispenser/dispenser_screen.dart#L573)

- The skip half: a purge card's secondary is the plain terminal skip, never the rescue ask.
  [`dispenser_screen.dart:422`](../../lib/ui/dispenser/dispenser_screen.dart#L422)

- The new surface frame: one `Hecho` funnelling to the existing complete path — no copy of its own yet.
  [`decluttering_protocol_screen.dart:32`](../../lib/ui/destinations/decluttering_protocol_screen.dart#L32)

**Authored copy (SM-C2, Ask-First pending your word)**

- The purge card's task text — reword freely; the key stays.
  [`app_es.arb:34`](../../lib/l10n/app_es.arb#L34)

**Peripherals — the pins**

- Core matrix: fresh-activation first-dealt, closure, LRS, tiers, 🔴/pocket, cardForItem branch, namespace census.
  [`weave_test.dart:4656`](../../packages/core/test/weave_test.dart#L4656)

- Controller paths: launch, standing read, complete, skip, declarePocket (5-min and 1-min pockets).
  [`dispenser_controller_test.dart:4481`](../../test/dispenser/dispenser_controller_test.dart#L4481)

- Widget pins: ordinary furniture, the one entry, frame completion, back gesture, rapid double-Hecho.
  [`dispenser_screen_test.dart:6537`](../../test/ui/dispenser/dispenser_screen_test.dart#L6537)

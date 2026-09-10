---
title: '6-3: The triage act — item_triaged with destination and coarse volume'
type: 'feature'
created: '2026-09-10'
status: 'done'
baseline_commit: '3c9263a13abd48840f19d79aafce8b8730ce0876'
review_loop_iteration: 0
context: ['_bmad-output/implementation-artifacts/epic-6-context.md']
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** Stories 6.1–6.2 open the Decluttering Protocol and collect the two detachment answers, but a letting-go decision still leaves no trace: the log has no `item_triaged` kind, no destination vocabulary, and no coarse volume tag — the substrate Epic 6's Quarantine Box (6.5) and the declutter metric (6.7, Epic 7) derive from does not exist.

**Approach:** Land the substrate in the pure core (new `item_triaged` kind carrying a required destination and an optional coarse volume tag, the destination vocabulary as forward-only data, schema v12 columns, a pure triage command) and design the minimal tagging act the UX spine leaves undrawn: an optional batch-volume block on the existing protocol surface, offered after both detachment answers, where picking a tag or declining are one-tap equal outcomes and declining writes nothing.

## Boundaries & Constraints

**Always:** `item_triaged` carries exactly one destination from `TriageDestination` (`keep` / `donate_sell` / `trash_recycle` wire names — `quarantine` arrives additively in 6.5, never in this story) and an optional `CoarseVolumeTag` from exactly `bolsa` / `caja` / `caja_grande` / `mueble`; a numeric volume is unrepresentable (enum payload, TEXT column, closed wire map). Kind census, wire names and the single-mint-site rule (as `no_lateness_proof_test` enforces for existing kinds) hold for the new literals. Every entry keeps UTC instant + local offset via the existing `LogEntry` base; nothing else about the write path changes. Unknown destination/tag wire names at the read boundary surface as `LogRecordFlaw`s, never coerced (AD-23 house pattern). The tagging block appears only after both detachment answers stand; tag and decline are one-tap, equal-weight, ≥48dp, no preselection, with the detachment answers still revisable while the block is visible; the handoff stays one-shot per visit and the route pops immediately after. System back from anywhere discards everything transient and leaves the purge card standing (6.2 behavior preserved). All copy is Spanish from the single ARB table, never concatenated (AD-15), in the anti-shaming register; the tag question implies no obligation and declining carries no guilt. Text grows and scrolls at 200% — no maxLines, ellipsis, FittedBox or fixed-height text containers.

**Ask First:** None — the copy below and the minimal-form placement are the approved design; renegotiate with the human before inventing any further surface.

**Never:** No shell append of `item_triaged` in this story — the destination choice that completes a triage act arrives in 6.4; the substrate is exercised by core tests only. No destination glyphs, tiles, hues or destination-flow surface (6.4); no `box_created`, quarantine value, box linkage column (6.5); no surface renders triage counts or volume (Epic 7 dashboard, AD-26). No numeric volume anywhere, no denominator framing. Do not complete the purge card (`card_done`) from the protocol. Do not edit generated localization/drift files by hand.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Tag block appears | Both detachment answers stand | Optional volume block renders below the questions: one question, four tag choices, one decline action; nothing written | N/A |
| Tag tapped | Tag block visible, one tag tapped | Handoff fires once with (answers, tag); route pops; no log append; purge card stands | N/A |
| Decline tapped | Tag block visible, decline tapped | Handoff fires once with (answers, null); route pops; no log append, no tag recorded anywhere | N/A |
| Back from tag block | System back before any tag/decline tap | Transient answers and visibility discarded; no event; re-opening starts unanswered | N/A |
| Core round-trip | `item_triaged` row with destination (+/- tag) | Converts back to the same entry; census counts 24 kinds | N/A |
| Unknown wire at read | Row with unmapped destination or tag wire name | Entry surfaces with a `LogRecordFlaw`; value never coerced or silently dropped when load-bearing | Flaw, not crash |
| Payload on wrong kind | Tag/destination columns set on a non-triage kind | `LogRecordFlaw` per the curation precedent | Flaw, not crash |
| Large text | Font scale 200% | Copy wraps, route scrolls, all six targets ≥48dp | N/A |

</frozen-after-approval>

## Code Map

- `packages/core/lib/log/log_entry.dart` -- the whole vocabulary: `LogKind` value class (~119-199), sealed `LogEntry` (~236-285), `Permission` enum + `permissionByName` wire map (:72-99, the closed-vocabulary precedent), `LogRecordFlaw` (:619-1105), `convertLogEntryRecord` (:759-1350). Add `LogKind.itemTriaged`, a `TriageEntry` subtype on the `ClusterCurationChangedEntry` precedent (destination + optional tag; it references no pool item — the object is physical, AD-14 does not apply), both enums + wire maps, new flaws, new conversion arms.
- `packages/core/lib/ports/store_port.dart` -- `LogEntryRecord` typedef (:96-122): two new nullable String fields (`triageDestination`, `triageVolumeTag`), additive.
- `packages/core/lib/commands/session_commands.dart` -- `LogEntryContent` typedef (:77-94): same two fields; the minter goes in a new `packages/core/lib/commands/triage_commands.dart` (`List<LogEntryContent> triageItem({required TriageDestination destination, CoarseVolumeTag? volumeTag})` — pure content, no id/instant).
- `lib/store/substrate.drift` + `lib/store/substrate.dart` -- `log_entries` table gains two nullable TEXT columns; `schemaVersion => 12` with the idempotent additive `ALTER TABLE` migration (:38-238); regenerate via `make codegen`.
- `lib/ui/destinations/decluttering_protocol_screen.dart` -- 6.2's surface (260 lines): extend the state machine — when both answers stand, render the volume block; tag/decline tap fires the one-shot handoff (now `(DetachmentAnswers, CoarseVolumeTag?)`) and pops the route. No tag selection state is needed (tap = handoff). Reuse `_answerButton` (:123-163), the module-level keys, the scroll/max-width scaffolding (:197-258).
- `lib/ui/dispenser/dispenser_screen.dart` -- `_onDetachmentAnswers` (:591-592): widen the sink signature; it stays deliberately side-effect free — destination and completion are 6.4's.
- `lib/l10n/app_es.arb` -- six new keys with `@` metadata: `volumeTagQuestion` ("¿Cuánto era?"), `volumeTagBolsa` ("Bolsa"), `volumeTagCaja` ("Caja"), `volumeTagCajaGrande` ("Caja grande"), `volumeTagMueble` ("Mueble"), `volumeTagSkip` ("Sin etiqueta").
- `packages/core/test/log_test.dart` -- census `hasLength(23)` → 24 (:44-87); add round-trip, flaw and unknown-wire cases per the matrix.
- `packages/core/test/triage_commands_test.dart` (new) -- command returns the content pair; tag optional; never a number by construction.
- `test/ui/destinations/decluttering_protocol_screen_test.dart` -- 6.2's pins move: handoff now fires on tag/decline, not on the second answer; add tag-block, decline, back-from-block, one-shot and 200% rows.
- `test/ui/dispenser/dispenser_screen_test.dart` -- purge group (:6549-6860): update the handoff pins to the widened signature; entry route and no-write pins stand.

## Tasks & Acceptance

**Execution:**
- [x] `packages/core/lib/log/log_entry.dart` -- add `itemTriaged` kind, `TriageEntry`, `TriageDestination` + `CoarseVolumeTag` with wire maps, flaws and conversion arms -- FR-22, AD-21, AD-23.
- [x] `packages/core/lib/ports/store_port.dart` and `packages/core/lib/commands/session_commands.dart` -- extend `LogEntryRecord`/`LogEntryContent` additively; new `triage_commands.dart` minter -- AD-2, AD-3.
- [x] `lib/store/substrate.drift` + `lib/store/substrate.dart` -- schema v12 columns + migration; run codegen -- AD-23.
- [x] `lib/ui/destinations/decluttering_protocol_screen.dart` -- volume block after both answers; one-tap tag/decline handoff + pop -- FR-22, UX-DR31 register.
- [x] `lib/ui/dispenser/dispenser_screen.dart` -- widen the inert sink to carry the optional tag -- 6.4 seam.
- [x] `lib/l10n/app_es.arb` -- six audited Spanish keys; regenerate -- AD-15.
- [x] `packages/core/test/log_test.dart`, `packages/core/test/triage_commands_test.dart`, `test/ui/destinations/decluttering_protocol_screen_test.dart`, `test/ui/dispenser/dispenser_screen_test.dart` -- cover the matrix.

**Acceptance Criteria:**
- Given the destination vocabulary, when its census is taken, then it holds exactly keep, donate-sell and trash-recycle as data, with no quarantine member and unknown future wire values tolerated as flaws at read.
- Given a triage decision handed to the core command, when the content is appended and read back, then the `item_triaged` entry carries the destination and the tag exactly when one was given, and no field of it can hold a number.
- Given the volume block, when copy and weighting are audited, then tag and decline read as equal one-tap outcomes with no pressure, preselection or judgement framing.
- Given a declined tag, when the visit ends, then nothing was written for volume and the purge card remains eligible.

### Review Findings

- [x] [Review][Patch] Warm-return `TriageEntry`-as-contact classification unpinned — added to the payload-carrying sweep in `warm_return_test.dart` (flipping `_isUserAct` now fails the suite)
- [x] [Review][Patch] v11→v12 upgrade group lacked the half-upgraded and empty-database variants every earlier step pins — both added to `substrate_test.dart`
- [x] [Review][Patch] `constant_identifier_names` suppressed file-wide in `log_entry.dart` — scoped to the three snake_case members; justification comment corrected
- [x] [Review][Patch] Decline button rendered full-width below the tag chips, weighting it above the tags — moved into the `Wrap` as a fifth equal chip
- [x] [Review][Patch] `pop()` after a synchronous callback without a `mounted` guard — guarded in `_handOff`
- [x] [Review][Patch] Minter→wire→read-boundary seam never exercised end to end — minter-driven round-trip added to `triage_commands_test.dart`
- [ ] [Review][Human] The frozen matrix and Design Notes say "six targets"; the volume block has five (four tags + decline; nine buttons with the answers) — code and tests are correct; frozen text is the human's to amend

## Spec Change Log

## Design Notes

The tag block lives on the protocol surface because the 3-Destination Flow must stay "three choices and nothing else" (6.4, UX-DR27) — the protocol is the only container the flow already owns. Tap-is-handoff (no confirm step, no selection state) matches the house one-tap-acts grammar (`Hecho` completes on one tap) and keeps the form minimal: four choices + decline, six targets, done. Popping after the handoff is the honest 6.3 intermediate state — 6.4 replaces the pop with the destination flow. The decline action is a first-class outcome ("Sin etiqueta"), not a dismiss-gesture leftover: FR-22 makes absent tags simply not contribute.

## Verification

**Commands:**
- `devbox run -- make codegen` -- expected: schema and string artifacts regenerate with the two columns and six keys.
- `devbox run -- make gate` -- expected: `flutter test`, format, analyze and repository checks green, including the 24-kind census and single-mint-site checks.

## Suggested Review Order

**The triage vocabulary (entry point)**

- The 24th kind and its entry: destination required, tag optional, no item pair — the whole substrate in one type.
  [`log_entry.dart:697`](../../packages/core/lib/log/log_entry.dart#L697)

- The destination enum as forward-only data — exactly three members, `quarantine` deliberately absent until 6.5.
  [`log_entry.dart:134`](../../packages/core/lib/log/log_entry.dart#L134)

**Schema v12**

- Two nullable TEXT columns on `log_entries` — additive, no CHECK, no FK (forward-only evolution).
  [`substrate.drift:118`](../../lib/store/substrate.drift#L118)

- The version bump and idempotent `ALTER TABLE` migration — half-upgraded and empty databases re-upgrade clean.
  [`substrate.dart:204`](../../lib/store/substrate.dart#L204)

**The single sanctioned minter**

- Pure content, no id/instant/offset — the shell's only legal way to write a triage row (AD-3).
  [`triage_commands.dart:31`](../../packages/core/lib/commands/triage_commands.dart#L31)

- The record DTO gains the two wire fields — primitives only, additive.
  [`store_port.dart:105`](../../packages/core/lib/ports/store_port.dart#L105)

**The tagging act (the story's one surface)**

- The volume block: question, four chips and the decline as a fifth equal chip — tap is the act.
  [`decluttering_protocol_screen.dart:251`](../../lib/ui/destinations/decluttering_protocol_screen.dart#L251)

- The one-shot handoff with the `mounted` guard, then the pop — 6.4 replaces the pop with the destination flow.
  [`decluttering_protocol_screen.dart:129`](../../lib/ui/destinations/decluttering_protocol_screen.dart#L129)

- The widened, still-inert dispenser sink — the seam 6.4 will wire.
  [`dispenser_screen.dart:587`](../../lib/ui/dispenser/dispenser_screen.dart#L587)

- Six audited Spanish keys, flat in the single table.
  [`app_es.arb:59`](../../lib/l10n/app_es.arb#L59)

**Verification matrix**

- Kind census at 24 plus the full payload group — round-trips, flaws, foreign-kind exclusion.
  [`log_test.dart:2024`](../../packages/core/test/log_test.dart#L2024)

- The minter-driven end-to-end seam — `.name` wires through the read boundary, every destination/tag pair.
  [`triage_commands_test.dart:76`](../../packages/core/test/triage_commands_test.dart#L76)

- The v11→v12 upgrade group — clean, half-upgraded and empty takeovers.
  [`substrate_test.dart:3463`](../../test/store/substrate_test.dart#L3463)

- The triage act pinned as warm-return contact — the sweep a flip of `_isUserAct` now fails.
  [`warm_return_test.dart:306`](../../packages/core/test/warm_return_test.dart#L306)

- The protocol state machine — reveal, handoff, back-discard and the 200% row.
  [`decluttering_protocol_screen_test.dart:155`](../../test/ui/destinations/decluttering_protocol_screen_test.dart#L155)

- The dispenser purge group — route, guards and no-write pins preserved through the seam change.
  [`dispenser_screen_test.dart:6613`](../../test/ui/dispenser/dispenser_screen_test.dart#L6613)

---
title: '6-4: Three destinations of equal weight'
type: 'feature'
created: '2026-09-10'
status: 'done'
review_loop_iteration: 0
baseline_commit: 'a709a1e9b3bd9cf3ef3c9bc5218278d60919efd2'
context: ['_bmad-output/implementation-artifacts/epic-6-context.md']
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** 6.3 hands off (detachment answers + optional volume tag) into an inert sink and pops — the letting-go decision still has no surface, so no `item_triaged` row is ever written from the shell and the purge card never completes through the protocol.

**Approach:** Land the 3-Destination Flow: one full-screen decision rendering the already-built destination glyphs (box/bag/seed at 64px), pushed by the dispenser sink that 6.3 left inert; a destination tap appends the triage row and completes the purge card in one act, returning the user to the next dealt card.

## Boundaries & Constraints

**Always:** Exactly three rows, constructionally identical — glyph at `Spacing.glyphDestination` (64) beside its label in `TypeRoles.destinationLabel` on the flow ground, `Spacing.destinationRowGap` (32) between rows; order fixed `Quedármelo`·`Donar o vender`·`Tirar o soltar` (box·bag·seed; `destinationKeep/Donate/Release` ARB keys, verbatim). Tap is the act — one-shot, no selection state, no confirm; every row target ≥48dp; text grows and scrolls at 200% (no maxLines/ellipsis/FittedBox/fixed-height text). Background is the raised ground (DES token `background: surface-raised` → `colorScheme.surfaceContainerHighest`), no AppBar, SafeArea + scroll + max-width-480 scaffolding per the house full-screen pattern. Dark mode keeps the light form: plates via `glyphPlates`, dark destination masses + `ink-primary-dark` line (UX-DR13). Hue lives only inside glyphs — no tile, field, bar or band; no default, preselection or ordering signal (FR-20, UX-DR27, UX-DR47). The act appends `item_triaged` (destination + the tag handed off, when present) then completes the card via the existing `cardDone` path — one queued controller write, one captured `now` for the whole act, mirroring `_onDone`'s in-flight guard, quiet failure handling and post-write cleanup. System back from the flow (before any tap) writes nothing and leaves the purge card standing.

**Ask First:** None — the flow's shape is fully specified by FR-20/UX-DR27/DES `destination-flow`; renegotiate before inventing any further surface, copy or celebration.

**Never:** No quarantine value, `box_created`, box linkage or Quarantine Box entry (6.5 — even though the surface map sites it on this flow). No core, schema or codegen changes — the 6.3 substrate is complete; no new ARB keys (the three labels shipped in 1.2; the authored register holds no flow question, so none is rendered — nothing else may be invented). No counts, totals or volume figures on any surface (AD-26). No completion from the protocol itself (the destination tap is the only completion path). No motion dashes on the seed at any size.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Protocol handoff | Tag or decline tapped | Sink pops the protocol and pushes the flow — flow is the current route, protocol gone; nothing written | N/A |
| Destination tapped | Flow current, one row tapped | `item_triaged` (destination + tag if present), then `card_done` on the purge id + bundled next `card_dealt`, all from one act instant; flow pops; dispenser shows the next card; purge id retired | N/A |
| Back from flow | System back before any tap | Nothing written; purge card stands on the dispenser; protocol answers discarded | N/A |
| Tap during write | Second tap while act in flight | Ignored (flow one-shot + `_writeInFlight`) | Quiet, no double write |
| Write failure | Controller throws mid-act | Flow stays standing, nothing surfaced, card remains eligible — mirrors `_onDone`'s quiet catch | Log consistent; re-entry retries |
| Dark mode | System theme dark | Light form kept: dark masses + `ink-primary-dark` line, labels in dark `inkPrimary` | N/A |
| Large text | Font scale 200% | Labels wrap (esp. `Donar o vender`), screen scrolls, rows still ≥48dp | N/A |

</frozen-after-approval>

## Code Map

- `lib/ui/destinations/destination_flow_screen.dart` (new) -- the flow: three tappable rows (glyph + label), module-level keys like the protocol's, one-shot `_handOff` (guarded, awaits the sink callback, pops itself only on success). House scaffolding: no AppBar, SafeArea, SingleChildScrollView, max width 480.
- `lib/ui/glyphs/box_glyph.dart` / `bag_glyph.dart` / `seed_glyph.dart` -- the trio, already drawn with destination masses and dark variants via `glyphPlates(context, lightMass:, darkMass:)` (`glyph_canvas.dart:27`). First surface render — no glyph edits.
- `lib/ui/tokens.dart` -- `Spacing.glyphDestination` (:246), `Spacing.destinationRowGap` (:240), `TypeRoles.destinationLabel` (:177, wired to `titleLarge`); destination masses + dark masses (:48-54, :83-85).
- `lib/ui/destinations/decluttering_protocol_screen.dart` -- `_handOff` (:129-145): drop the self-pop (and its mounted guard) — 6.4's sink owns navigation; callback contract (`DetachmentAnswersCallback`, :78) unchanged. 6.3's "6.4 replaces the pop with the destination flow".
- `lib/ui/dispenser/dispenser_screen.dart` -- `_onDetachmentAnswers` (:594-599, the inert sink): fill it — pop the protocol, push the flow carrying `(dealt, answers, volumeTag)`, await the push, then `_refresh()`; the flow's tap callback runs the guarded act mirroring `_onDone` (:275-313: `_writeInFlight`, haptic, rescue-marker clears, quiet catch). `_openDeclutteringProtocol` (:567-588) shows the push grammar.
- `lib/dispenser/dispenser_controller.dart` -- new `triageAndComplete` beside `complete()` (:604-627): both route through one shared `_enqueueCompleteWrite` (the repo census pins exactly one `cardDone` invocation site, so the act reuses `complete`'s) — one `_enqueueWrite` (:1044) capturing `now` once: append the `triageItem` content via `_appendContent` (:818-845, already 6.3-widened) first, then the `cardDone` contents (answered-guard + bundled next deal; contents-empty is a full no-op).
- `packages/core/lib/commands/triage_commands.dart:31` -- `triageItem({required TriageDestination destination, CoarseVolumeTag? volumeTag})` — the sanctioned minter, read-only here.
- `lib/l10n/app_es.arb:139-152` -- `destinationKeep` / `destinationDonate` / `destinationRelease`, read-only.
- `test/ui/destinations/decluttering_protocol_screen_test.dart` -- pins move: handoff fires the callback once; the pop pin becomes the sink's (route lifecycle is no longer the protocol's act).
- `test/ui/dispenser/dispenser_screen_test.dart` -- purge group (:6613-6990): `_RecordingStore`, `purgeStore()`, `protocolAnswer`/`cardHecho` finders; the 6.3 no-write pin (:6815-6828) moves to the flow: handoff writes nothing, destination tap writes the ordered trio, back-from-flow writes nothing.
- `test/dispenser/dispenser_controller_test.dart` -- add the act-order pins (triage → card_done → card_dealt, one instant, tag passthrough, stale double-complete no-op).

## Tasks & Acceptance

**Execution:**
- [x] `lib/ui/destinations/destination_flow_screen.dart` -- new surface: three equal rows, glyphs + verbatim labels, one-shot tap handoff, dark mode, 200% floor -- FR-20, UX-DR27, UX-DR47, UX-DR49.
- [x] `lib/ui/destinations/decluttering_protocol_screen.dart` -- `_handOff` stops popping; sink owns navigation -- 6.3 seam contract.
- [x] `lib/dispenser/dispenser_controller.dart` -- triage-and-complete as one queued write, one `now` -- AD-3, AD-21.
- [x] `lib/ui/dispenser/dispenser_screen.dart` -- fill `_onDetachmentAnswers`: pop + push + await + refresh; tap callback with `_onDone`'s guards -- the only act path.
- [x] `test/ui/destinations/destination_flow_screen_test.dart` (new), `decluttering_protocol_screen_test.dart`, `test/ui/dispenser/dispenser_screen_test.dart`, `test/dispenser/dispenser_controller_test.dart` -- cover the matrix.

**Acceptance Criteria:**
- Given a completed triage act, when the log is read, then `item_triaged` (destination, tag when present) precedes `card_done` on the purge id and the bundled next `card_dealt`, all stamped from one act instant.
- Given the flow rendered, when its strings and weighting are audited, then exactly the three existing ARB destination keys appear verbatim and the rows are constructionally identical — no tile, default, preselection or ordering signal, hue only inside glyphs.
- Given the diff, when inspected, then `packages/core`, the drift schema and generated artifacts are untouched and no ARB key is added.

### Review Findings

- [x] [Review][Patch] Guard release after a destination act was never observed by any test — success test now taps the next card's Hecho and asserts its `card_done` lands; breaking `_releaseWriteAfterRefreshFrame` fails the suite
- [x] [Review][Patch] Retry-after-failure unpinned — the `_FailFirstTriageStore` test now re-walks the protocol and lands the trio on the retry
- [x] [Review][Patch] The declined (null-tag) act was never tapped through at screen level — new pin: decline → tap → `triageVolumeTag` null (a `volumeTag ?? default` regression fails it)
- [x] [Review][Patch] Mid-batch failure semantics unpinned — `_FailAfterTriageStore` controller test pins the orphan triage row standing and the retry appending a second (FR-22 approximate counts absorb the double)
- [x] [Review][Patch] Controller doc overclaimed "no orphan triage row can outlive the completion" — corrected: the stale guard covers the pre-append case only; mid-batch failure orphans, same partial-act class as every multi-row act
- [x] [Review][Patch] Spec Code Map said "No other controller changes" — amended to the census-forced shared `_enqueueCompleteWrite` extraction
- [x] [Review][Patch] Reset the destination flow's one-shot guard after a failed write so the user can retry in place, matching `Hecho`'s failure behavior [destination_flow_screen.dart:72]
- [x] [Review][Patch] Design Notes overclaim that a queued write prevents partial state [6-4-three-destinations-of-equal-weight.md:84]
- [x] [Review][Patch] System back while a destination write is pending can let the late success pop the dispenser route [destination_flow_screen.dart:80]
- [Defer] Transactional/batched multi-row log acts (orphan exposure class, house-wide — `complete`'s answer+deal pair is sequential too) — deferred-work.md

## Spec Change Log

## Design Notes

No question/object line is rendered: the authored fixed-string register (UX-DR49) holds only the three labels for this flow, and AD-15 forbids unaudited sentence assembly — the flow is three rows and nothing else, per its AC. Tap-is-handoff (no selection state) matches the volume-block grammar. The sink owns navigation because a push from the synchronous callback followed by the protocol's own `pop()` would pop the new route: deterministic shape is sink-pops-then-pushes, which is also what 6.3's "6.4 replaces the pop with the destination flow" names. The act is one queued controller write (triage + completion), so concurrent shell acts cannot interleave; its multi-row appends remain non-transactional and can therefore leave partial state on a mid-batch failure. `cardDone`'s answered-guard already makes a stale double complete a no-op.

## Verification

**Commands:**
- `devbox run -- make gate` -- expected: `flutter test`, format, analyze and repository checks green, including the moved protocol pins, the purge-group write pins and the act-order controller pins.

## Suggested Review Order

**The surface (entry point)**

- The three constructionally identical rows — glyph 64px beside the verbatim label, raised ground, nothing else on screen.
  [`destination_flow_screen.dart:124`](../../lib/ui/destinations/destination_flow_screen.dart#L124)

- The one-shot tap: awaits the sink's act, pops only on success — failure leaves the decision standing.
  [`destination_flow_screen.dart:72`](../../lib/ui/destinations/destination_flow_screen.dart#L72)

- The `Future<bool>` seam that lets the surface stay ignorant of the store.
  [`destination_flow_screen.dart:43`](../../lib/ui/destinations/destination_flow_screen.dart#L43)

**Navigation ownership (the 6.3 seam contract)**

- The protocol's `_handOff` fires once and pops nothing — a pop here would pop the flow the sink just pushed.
  [`decluttering_protocol_screen.dart:133`](../../lib/ui/destinations/decluttering_protocol_screen.dart#L133)

- The filled sink: pop the protocol, push the flow, await its pop, then refresh.
  [`dispenser_screen.dart:606`](../../lib/ui/dispenser/dispenser_screen.dart#L606)

**The act**

- `_onDone`'s mechanics fired from the flow's route: shared guard, haptic, rescue-marker clears, quiet catch answering `false`.
  [`dispenser_screen.dart:647`](../../lib/ui/dispenser/dispenser_screen.dart#L647)

- The act's one queued write: triage row prepended to `complete`'s, one instant, stale no-op pre-append.
  [`dispenser_controller.dart:630`](../../lib/dispenser/dispenser_controller.dart#L630)

- The shared completion path behind both `complete` and the destination act (the census's single `cardDone` site).
  [`dispenser_controller.dart:653`](../../lib/dispenser/dispenser_controller.dart#L653)

**Verification matrix**

- The flow's own pins: equality, order, pitch, ground, no tiles, semantics, one-shot, dark, 200%, source audit.
  [`destination_flow_screen_test.dart:58`](../../test/ui/destinations/destination_flow_screen_test.dart#L58)

- The end-to-end act: ordered trio, one instant, tag rides, guard release observed by the next card's Hecho.
  [`dispenser_screen_test.dart:6892`](../../test/ui/dispenser/dispenser_screen_test.dart#L6892)

- Quiet failure with in-flight retry re-walked to a landing.
  [`dispenser_screen_test.dart:7017`](../../test/ui/dispenser/dispenser_screen_test.dart#L7017)

- The FR-22 decline contract at the wiring level: null tag lands null.
  [`dispenser_screen_test.dart:7066`](../../test/ui/dispenser/dispenser_screen_test.dart#L7066)

- The act-order and mid-batch orphan/retry semantics at the controller seam.
  [`dispenser_controller_test.dart:4687`](../../test/dispenser/dispenser_controller_test.dart#L4687), [`:4804`](../../test/dispenser/dispenser_controller_test.dart#L4804)

---
title: 'Story 5.11: The curation-row and its Settings home'
type: 'feature'
created: '2026-09-08'
status: 'done'
review_loop_iteration: 0
baseline_commit: 'c0d81957db4feec15aa485983b8a30a9c1a95a7c'
context:
  - '{project-root}/_bmad-output/implementation-artifacts/epic-5-context.md'
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** Cluster curation exists as read-side core landed forward in 1.7 — `packages/core/lib/curation/curation.dart` derives the active set with exactly AD-16's two speeds, and the weave threads `activeClusters` through composition and the below-floor fallback — but nothing feeds it: no `cluster_curation_changed` log kind exists (census 21), no persisted state, no switch anywhere. Settings has no `Contenido de la casa` group (UX-DR33's second of five; today there are two), so the user cannot turn off the parts of the house they do not have.

**Approach:** Close the loop end to end. One new log kind — the 22nd, `cluster_curation_changed`, carrying cluster wire-name + enabled bit on its **own** schema columns (v11, additive) — one sanctioned minter, one pure fold from log rows to `CurationObservation`s, and `_resolveDay` deriving its default active set from the log it already holds, so daily/`fondo` flips take effect immediately and weekly zones at the next week boundary with zero call-site changes. On top: the `Contenido de la casa` group in Settings with one entry row pushing a sub-screen of eight `CurationRow`s — one shared public row widget (5.12's two other homes reuse it verbatim), a twin of the camera row with a cadence line.

## Boundaries & Constraints

**Always:**
- The payload rides its own kind: new nullable columns (cluster wire-name, enabled bit) on `log_entries`; never `settingKey`/`settingValue` reuse; additive-only ALTER, migration block, unknown kinds still tolerated (AD-23, house payload discipline).
- State is the fold, nothing else: `curationObservationsOf(log)` pure, then `activeClustersAt(observations, day.startUtcMicros)`; no mutable record, no SETTINGS cache, rebuilt per read (AD-1). The explicit `activeClusters` param on `_resolveDay` stays as the test override; the default becomes log-derived.
- Exactly eight rows: `anclas`, `sostén`, `z1`–`z5`, `fondo` — cluster level only (AD-16's tuple; `plantas`/`coche` are not switchable).
- Cadence is the row's only description — `diaria` (anclas, sostén), `semanal` (z1–z5), `mensual-estacional` (fondo) — in the support role (`bodySmall`); no counts, no volume, no task-level rows (FR-31, UX-DR23).
- Feedback is none beyond the switch: no snackbar, no summary, no copy; exactly one `cluster_curation_changed` row per flip (AD-21, FR-31).
- The row twins `_CameraRow`: whole band tappable through one shared handler, merged `Semantics(button, label, toggled)` node, bare `Switch` on theme defaults, label `bodyMedium`, minHeight `Spacing.touchTargetMin`, grows under text scaling (no maxLines/ellipsis/fixed heights).
- All writes flow through the existing `SettingsController._appendContent`/`_enqueueWrite` funnel (write-path census stays at one append site in `lib/`); no wire-name literals in `lib/`; no drift import outside `lib/store`.
- Zone rows reuse the canonical `zoneZ1`–`zoneZ5` ARB names; ARB additions go through `make codegen`.

**Ask First:**
- Any change to the three authored strings beyond checkpoint approval: `Grupos de tareas` (entry row + sub-screen header), `Hábitos instantáneos` (anclas), `Mantenimiento base` (sostén), `Cuidados de fondo` (fondo).
- Any effect-timing semantics other than `activeClustersAt`'s existing derivation (1.7's timing is frozen; this story only feeds it).
- Any surface beyond the Settings group + sub-screen; anything visible from or near the Dispenser (FR-31, NFR3).
- Any renegotiation of a census/pin by anything other than additive extension (log census 21→22, the ~10 `schemaVersion` pins 10→11, the settings text-census set gaining the new group's strings).
- Batch writes (one flip = one row stands; no multi-switch transactions).

**Never:**
- No catalogue enumeration anywhere: no task names, no per-entry rows, no counts, no browse (FR-31, NL-1).
- No curation from the Dispenser or onboarding in this story — 5.12 owns the E1 surface and the one-time strip; `curationInvitation` stays referenced nowhere.
- No second new kind, no flag on an old one; census moves 21→22 only.
- No change to zone rotation (`activeZoneOf`), chunk tiers (`_chunkCandidateOf`), the 1.7 fallback, or the below-floor behavior — curation only shrinks the pool feeding them; existing weave cluster tests (`weave_test.dart:1473-2142`) stay green unedited.
- No renegotiation of the kind-name segment pin (verified: `cluster_curation_changed` carries none of the nine banned segments).

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Flip a daily cluster | tap anclas row on→off | one `cluster_curation_changed{anclas, 0}` row; anclas entries excluded from the very next composition, same day | quiet failure: nothing written, switch returns to derived state on re-read |
| Flip a weekly zone mid-week | tap z3 row Wednesday 10:00 | row `{z3, 0}`; this week's compositions still serve z3; exclusion effective from `weekOf(observedDay).endUtcMicros` (next Monday 04:00) | same |
| Flip `fondo` | tap fondo row | immediate exclusion, like daily | same |
| Everything off | all eight flipped | already-shipped all-off behavior: zone tiers empty, 3/5-draws stand on what remains (captures/Epic material unaffected) — pinned by existing weave tests, not renegotiated | never crashes, never an empty crash-screen |
| Old v10 substrate | app opens on pre-v11 db | additive ALTER to v11; legacy rows read with null cluster/enabled; a non-null cluster on any other kind, or a malformed wire-name, is a read flaw per the `permission` column discipline | unknown kinds tolerated as ever |
| Rapid double-flip | on→off→on before re-read | two rows serialized through the write queue; derived state = last row wins | — |
| Equal-value tap | switch already off, tapped again | no row written | — |
| Unread window | sub-screen opened, row tapped before first read resolves | renders all-active default (no off-flash); pre-read tap writes nothing (camera-row idiom) | — |
| No rows at all | fresh install | every cluster active; first composed day never empty (FR-31) | — |

</frozen-after-approval>

## Code Map

**Core (read-side shipped in 1.7 — this story adds the write-side and the wiring):**

- `packages/core/lib/curation/curation.dart` -- the whole derivation already exists: `CurationCluster` (:30), `allCurationClusters` (:58), `curationClusterOfEntry` (:94), `CurationObservation` {cluster, enabled, instantUtcMicros, offsetSeconds} (:77), `activeClustersAt` (:139), `_observationIsEffective` (:186: weekly → `weekOf(observedDay).endUtcMicros`, else own day start). ADD here: the pure fold from log entries to observations (+ the wire-name parse the store round-trip needs).
- `packages/core/lib/weave/weave.dart` -- `_resolveDay` (:754): `activeClusters` param (:761, all-active default :767), filter applied once at `shippedCandidates` (:210-227); `activeZoneOf` ring (:543); `_chunkCandidateOf` fallback tiers (:669). Only change: the default becomes log-derived. Read-only: rotation, tiers, fallback.
- `packages/core/lib/log/log_entry.dart` -- `LogKind` constants (:104-126), `knownByName` (:128-152), `convertLogEntryRecord` (~:590) with `LogRecordFlaw` per-kind payload discipline (`permission` TEXT column is the precedent); header kind-count prose (:12-40). ADD: kind, registry entry, `ClusterCurationChangedEntry`, conversion branch, flaws.
- `packages/core/lib/ports/store_port.dart` -- `LogEntryRecord` (:69) gains the two nullable fields; `appendLogEntry` (:143) is the one funnel.
- `packages/core/lib/commands/session_commands.dart` -- `LogEntryContent` typedef (:76, frozen-census'd); every minter/copier gains the new null fields (also `_moment/_start/_deal/_extend` copiers here; `settings_commands`, energy/report/permission/scan/rescue/capture minters).
- `packages/core/lib/commands/scan_commands.dart:255` -- `epicActivated` minter: the single-sanctioned-minter precedent to copy (5.9).
- `packages/core/lib/day/calendar.dart` -- `dayOf` (:167), `weekOf` (:194): read-only; the timing derivation already uses them.

**Shell:**

- `lib/store/substrate.dart` -- `schemaVersion` 10 (:217) → 11, additive-ALTER + `migration` block; edit `substrate.drift` sibling; regenerate.
- `lib/store/drift_store.dart` -- `appendLogEntry`/`readLogEntries` (:43/:81) gain the column mapping.
- `lib/settings/settings_controller.dart` -- the funnel: `_appendContent` (:241-263, mints id/instant/offset), `_enqueueWrite` (:265-273); camera read/write lifecycle (:157-185) is the idiom for `readCurationState`/`writeClusterCuration`.
- `lib/ui/settings/settings_screen.dart` -- flat `ListView` (:248-256); group header idiom (:255-259); `_CameraRow` (:433-493 — the row to twin, incl. `Semantics` + opaque `GestureDetector` + shared handler); `_ReactivationRow` (:385-431); camera state lifecycle (:75-124, :191-241).
- `lib/ui/settings/nuevo_proyecto_screen.dart:376-386` -- the push idiom (`MaterialPageRoute` behind `ModalRoute.isCurrent` guard) for the sub-screen.
- `lib/l10n/app_es.arb` -- `zoneZ1`–`zoneZ5` (:34-55, reuse as zone row names); `curationInvitation` (:360, stays unused — 5.12's); camera keys with `x-signoff` (:267) show the metadata shape. Then `make codegen` (Makefile:41-45; freshness gate :73-90).
- `lib/ui/tokens.dart:139-147` + `lib/ui/theme.dart:74-91` -- support role wiring (`bodySmall`); screens never touch `TypeRoles` directly.
- `lib/ui/settings/slicer_access_section.dart:42-49` -- `providerNameOf`: the enum→string total-map precedent for cluster/cadence labels.

**Tests and pins (renegotiate vs leave):**

- `packages/core/test/log_test.dart:43-90` -- census 21→22 + name list; conversion/flaw tests beside siblings.
- `packages/core/test/no_lateness_proof_test.dart:1228-1365` -- frozen declaration census: new core top-level shapes (entry class, minter file) must join the map (`CurationObservation` already frozen :1276, `CurationCluster` exempt :1342). Segment pin :2382 — verified clean, leave.
- `packages/core/test/curation_test.dart` + `packages/core/test/weave_test.dart:1473-2142` -- timing semantics already encoded against hand-built observations; ADD the log-derived path (fold + `_resolveDay` default) so the shipped semantics are proven end to end from rows.
- `test/store/substrate_test.dart` -- `schemaVersion == 10` pinned at ~10 sites (:890, :1041, :1123, :1288, :1458, :1626, :1761, :2003, :2155, :2233) → 11, plus a v11 migration test.
- `test/no_lateness_proof_test.dart` -- write-path census (:455-496: `settings_controller` stays at one append site); `bannedWireNames` (:354-373); slack-vocabulary scan (:139-237 — cadence words verified clean).
- `test/ui/settings/settings_screen_test.dart` -- settings-tree text census (:344-421, the 19-string set :381-404 gains the group header + entry row); nav-chain (:265-313, sub-screen pops via `handlePopRoute`); camera-row group (:1069-1326) is the test grammar to clone; helpers `useTallSurface` (:189), `harnessFor`/`openSettings`/`textsOf` (:200-254), `_RecordingStore` (:41).
- `tool/check_no_literal_strings.dart`, `tool/check_string_table_audit.dart`, `tool/check_forbidden_vocabulary.dart` -- gates the new strings/identifiers must pass; `cluster`/`enabled`/`curation` and the cadence words verified clean.

## Tasks & Acceptance

**Execution:**
- [x] `packages/core/lib/log/log_entry.dart` -- add the `clusterCurationChanged` kind, registry entry, `ClusterCurationChangedEntry`, conversion branch and flaws (absent cluster on the kind, cluster on a wrong kind, malformed wire-name) -- the 22nd kind rides its own columns
- [x] `packages/core/lib/ports/store_port.dart` + `packages/core/lib/commands/curation_commands.dart` (new) -- record fields, the log→observation mapping, and the single sanctioned minter; thread the new null fields through `LogEntryContent` and every existing minter/copier -- one funnel, one minter, census disciplines preserved
- [x] `packages/core/lib/curation/curation.dart` + `packages/core/lib/weave/weave.dart` -- the pure fold and the `_resolveDay` log-derived default (day-start query instant; param stays override) -- AD-16's two speeds become real from rows, no call-site changes
- [x] `lib/store/substrate.dart` + `substrate.drift` + `lib/store/drift_store.dart` -- schema v11 additive columns + migration + read/write mapping -- AD-23 evolution
- [x] `lib/settings/settings_controller.dart` -- `readCurationState`/`writeClusterCuration` through the existing `_appendContent`/`_enqueueWrite` funnel -- write-path census stays at 1
- [x] `lib/l10n/app_es.arb` + `make codegen` -- `Contenido de la casa` header, `Grupos de tareas` (entry row + sub-screen header), three cluster names (`Hábitos instantáneos`/`Mantenimiento base`/`Cuidados de fondo`), three cadence words -- the authored copy set
- [x] `lib/ui/settings/curation_screen.dart` (new) -- the sub-screen: flat `ListView` of the eight rows; `CurationRow` a **public** widget (5.12 reuses it in two more homes); camera-row lifecycle grammar (generation counter, quiet failures, unread-window default, equal-value no-op)
- [x] `lib/ui/settings/settings_screen.dart` -- `Contenido de la casa` group between `Tu día` and `IA y voz`, one entry row pushing the sub-screen behind the `isCurrent` guard
- [x] `packages/core/test/log_test.dart` + `packages/core/test/no_lateness_proof_test.dart` -- census 21→22 + name list; conversion/flaw tests; frozen-census additions for the new shapes
- [x] `packages/core/test/curation_test.dart` + `packages/core/test/weave_test.dart` -- the log-derived path: fold round-trip, immediate daily/fondo, weekly-at-boundary, below-floor fallback through `_resolveDay`, default-all-active -- the story's timing ACs as executable proof
- [x] `test/store/substrate_test.dart` -- the ~10 version pins → 11 + v11 migration test (legacy rows null-clean)
- [x] `test/ui/settings/settings_screen_test.dart` + `test/ui/settings/curation_screen_test.dart` (new) -- renegotiated text census + nav-chain arm; new group cloned from the camera-row grammar: tap-anywhere flips exactly one row, switch follows derivation, cadence-only description, no feedback copy, pre-read tap writes nothing, Dispenser surfaces unchanged

**Acceptance Criteria:**
- Given the Settings tree, when rendered, then `Contenido de la casa` sits between `Tu día` and `IA y voz` holding one entry row that pushes the sub-screen, and nothing curation-related renders anywhere else in the tree (UX-DR33).
- Given the sub-screen, when rendered, then exactly eight rows — `anclas`, `sostén`, `z1`–`z5`, `fondo` — each carrying cluster name, cadence in the support role as the only description, and a platform switch, the whole row tappable (UX-DR23, FR-31).
- Given a flip, when the substrate is pulled, then exactly one `cluster_curation_changed` row exists for it and no other write occurred; the surface shows no count, summary or copy beyond the switch (AD-21, FR-31).
- Given a daily or `fondo` flip, when the next composition runs, then that cluster's entries are already excluded (AD-16 immediate).
- Given a weekly-zone flip mid-week, when this week composes, then the zone still serves; when next week composes, then it is excluded (AD-16 next week boundary).
- Given curation that drops the eligible pool below the floor, when the Focus Chunk slot resolves, then 1.7's fallback governs — zone's own entries, then `fondo`, then least-recently-dealt eligible — proven through the log-derived path (AD-16, AD-20).
- Given the Dispenser surface, when curation is looked for, then it is absent — no route, no string, nothing changed behind `Nuevo proyecto` (FR-31, NFR3).
- Given a pre-v11 substrate, when the app opens, then migration is additive and legacy rows read clean (AD-23).
- Given no curation rows at all, when a day composes, then every cluster is active and the day is never empty (FR-31).

### Review Findings

- [x] [Review][Patch] Screen-wide `_writing` drops a second cluster flip while another is in flight [`lib/ui/settings/curation_screen.dart:131`]
- [x] [Review][Patch] Successful write then failed re-read leaves the switch stuck on pre-write state [`lib/ui/settings/curation_screen.dart:138`]
- [x] [Review][Patch] Settings file header and `IA y voz` block still describe a two-group tree [`lib/ui/settings/settings_screen.dart:3`]
- [x] [Review][Patch] UX-DR33 numbering calls Contenido “third” while the design’s second-of-five sits as the second group [`lib/ui/settings/settings_screen.dart:31`]
- [x] [Review][Patch] `_appendContent` still says three `setting_changed` writers and omits the curation copier [`lib/settings/settings_controller.dart:337`]
- [x] [Review][Patch] v10→v11 half-upgraded case seeds both columns; no crash between the two ALTERs [`test/store/substrate_test.dart:3149`]
- [x] [Review][Patch] Settings nav-chain never asserts the pushed `CurationScreen` is wired to the controller [`test/ui/settings/settings_screen_test.dart:1318`]
- [x] [Review][Patch] `writeClusterCuration` equal-value guard is untested on a mid-week zone re-enable [`test/ui/settings/curation_screen_test.dart:562`]
- [x] [Review][Patch] Curation foreign-payload exclusions only assert `flaw isNotNull`, not the specific family [`packages/core/test/log_test.dart:1830`]

## Spec Change Log

## Design Notes

- **Why derive inside `_resolveDay`:** the day derivation already holds the log, so folding there means zero call-site changes across `nextCard`, session/rescue commands and the Dispenser controller — and replay determinism holds by construction (same log + day → same active set). The explicit param survives as the override the existing weave tests already use.
- **Why `day.startUtcMicros` as the query instant:** daily/`fondo` observations are effective from their own day's start, so a same-day flip is already effective for that day's compositions; weekly observations from `weekOf(observedDay).endUtcMicros`. Comparing against the composed day's start yields exactly AD-16's two speeds, identically live or replayed.
- **Why own columns and not `setting_changed`:** house payload discipline — every payload column rides its own kind — and AD-21's vocabulary split: `cluster_curation_changed` is a user act, not a settings-cache event; the cluster payload is not a setting.
- **Copy provenance:** zones reuse the canonical `zoneZ1`–`zoneZ5` ARB names; the cadence triple is DESIGN-declared (`diaria` / `semanal` / `mensual-estacional`); the four authored strings (`Grupos de tareas`, `Hábitos instantáneos`, `Mantenimiento base`, `Cuidados de fondo`) are this spec's proposal, flagged for checkpoint approval — A12's English glosses (`Instant Habits`, `Baseline Upkeep`, monthly/seasonal) are their source.
- **Golden example:** flip `z3` off Wednesday 10:00 → one row `{z3, 0}`; Wednesday's compositions still serve z3 (effective instant is next Monday 04:00); from Monday 04:00 z3 leaves `shippedCandidates` and `activeZoneOf`'s ring skips to the next active zone — both behaviors already shipped and tested in 1.7; this story makes rows reach them.

## Verification

**Commands:**
- `devbox run -- make gate` -- expected: green (format, analyze, root suite incl. renegotiated censuses and the new tests)
- `devbox run -- make check` -- expected: green (ARB/codegen fresh after `make codegen`, store + egress seals unchanged)
- `devbox run -- make test-core` -- expected: green (log census 22, curation/weave log-derived group, 1-11 freezes passing with the additive map entries)
- `devbox run -- flutter test test/ui/settings/` -- expected: exit 0 (renegotiated settings census, nav chain, the new curation screen group)

**Manual checks (device, AGENTS.md recipe):**
- `Ajustes` → `Contenido de la casa` → `Grupos de tareas`: eight rows, each name + cadence + switch, whole row toggles; flip two rows, reopen the app — switches follow the persisted derivation, no feedback copy anywhere.
- Pull `organizer_substrate.sqlite`: exactly the two `cluster_curation_changed` rows (cluster wire-name + enabled), schema version 11, nothing else written.

## Suggested Review Order

**The seam that closes the loop**

- The whole story's keystone: `_resolveDay` now derives its default active set from the log it already holds — zero call-site changes, replay-deterministic.
  [`weave.dart:779`](../../packages/core/lib/weave/weave.dart#L779)

- Where the filter actually bites: one call site in `shippedCandidates` — disabled clusters are never candidates, so every draw and tier inherits it.
  [`weave.dart:210`](../../packages/core/lib/weave/weave.dart#L210)

**The 22nd kind — the write side**

- The kind, its registry entry, and the payload discipline it rides (own columns, own flaws).
  [`log_entry.dart:135`](../../packages/core/lib/log/log_entry.dart#L135)

- The entry subtype — cluster as the core enum, never a free-form string.
  [`log_entry.dart:550`](../../packages/core/lib/log/log_entry.dart#L550)

- The single sanctioned minter: one function, one row per flip, nothing else may write the kind.
  [`curation_commands.dart:31`](../../packages/core/lib/commands/curation_commands.dart#L31)

- Schema v11: two additive ALTERs, the migration block, the version bump — AD-23's evolution pattern, tenth time.
  [`substrate.dart:137`](../../lib/store/substrate.dart#L137)

**The read side — one fold, two speeds, two readers**

- The pure fold: stored rows become observations; the derivations never see the log directly.
  [`curation.dart:174`](../../packages/core/lib/curation/curation.dart#L174)

- The control surface's own read: latest declaration per cluster, timing aside — the switch never springs back; AD-16's two speeds stay in composition.
  [`curation.dart:229`](../../packages/core/lib/curation/curation.dart#L229)

- The one shared last-wins fold both reads use — tie discipline by sharing, not mirroring.
  [`curation.dart:244`](../../packages/core/lib/curation/curation.dart#L244)

- The controller seam 5.12's homes will cross: read declared, write once, guard equal-values at the shared boundary.
  [`settings_controller.dart:297`](../../lib/settings/settings_controller.dart#L297)

**The surface**

- The row itself — public on purpose (5.12 reuses it in two more homes), `MergeSemantics` so name and cadence speak as one button.
  [`curation_screen.dart:194`](../../lib/ui/settings/curation_screen.dart#L194)

- The sub-screen: eight rows, camera-row lifecycle grammar — generation counter, quiet failures, unread-window default, in-flight guard.
  [`curation_screen.dart:61`](../../lib/ui/settings/curation_screen.dart#L61)

- The Settings home: the group header between `Tu día` and `IA y voz`, one entry row, the guarded push.
  [`settings_screen.dart:295`](../../lib/ui/settings/settings_screen.dart#L295)

- The authored copy set — four signoff'd strings, three DESIGN-declared cadence words, canonical zone names reused.
  [`app_es.arb:279`](../../lib/l10n/app_es.arb#L279)

**Pins and proofs**

- Kind census 21→22 plus the exhaustive foreign-payload map — every kind, not nine of them.
  [`log_test.dart:48`](../../packages/core/test/log_test.dart#L48)

- The log-derived timing group: immediate daily/`fondo`, weekly at the boundary, from rows.
  [`curation_test.dart:409`](../../packages/core/test/curation_test.dart#L409)

- The declared read's own unit pin, including the nonzero-offset stored-frame arm.
  [`curation_test.dart:535`](../../packages/core/test/curation_test.dart#L535)

- Composition end to end: rows through `_resolveDay` — default, immediate, fallback, all-off.
  [`weave_test.dart:5321`](../../packages/core/test/weave_test.dart#L5321)

- The v10→v11 migration group: empty, seeded, half-upgraded — all additive.
  [`substrate_test.dart:2953`](../../test/store/substrate_test.dart#L2953)

- The warm-return classification pin: a curation flip is contact, and cannot silently stop being one.
  [`warm_return_test.dart:207`](../../packages/core/test/warm_return_test.dart#L207)

- The surface suite: row grammar, tap-anywhere, no feedback copy, in-flight guard, spoken semantics.
  [`curation_screen_test.dart:161`](../../test/ui/settings/curation_screen_test.dart#L161)

- The Settings tree: census renegotiated, nav chain, nothing curation on the Dispenser or behind `Nuevo proyecto`.
  [`settings_screen_test.dart:1317`](../../test/ui/settings/settings_screen_test.dart#L1317)

---
title: 'Story 7.1: The Before/After reward'
type: 'feature'
created: '2026-09-11'
status: 'done'
review_loop_iteration: 0
baseline_commit: '3db64a62d6e9ceb10cf3362c2c2bae5f891602d5'
context: []
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** FR-17 — the validation build's differentiating hook — does not exist. Completed work on a scanned space produces no reward: no Before is ever persisted (FR-25/AD-8 unlink the scan's frame on every terminal path), no After can be shot, no diff is seen, nothing reaches the album.

**Approach:** Two moments, both camera-in-hand. (1) At scan delivery — today a silent pop to the Dispenser — one quiet offer to shoot the space's **Before**, persisted as a content-addressed blob in the Files `album` scope plus a `before_saved` act naming the scan group. (2) At a milestone over a slicer-origin space — the `card_done` that retires the group's last step (project milestone), or session end after completing ≥ 1 of its steps (session milestone) — a pushed full-screen reward: with a Before, shoot the After and see the equal side-by-side pair, auto-saved via `album_entry_added`; without one, `Un trabajo estupendo`. Secondary control is always `Cerrar`.

## Boundaries & Constraints

**Always:**
- FR-25/AD-8 untouched: the scan cache unlink lifecycle is unchanged; the Before is a separate deliberate shot, never the uploaded frame.
- Album bytes are content-addressed (sha256 hex name) in app-private Files storage, `album` scope; album mutation is log acts (AD-13/AD-21): new kinds `before_saved` and `album_entry_added`, never flags on old kinds.
- Core stays pure (no Flutter/drift/plugin/`dart:io` imports, no wall-clock, no `Random`); milestone/before derivations live in `core/derive`, named as facts; they may cross to the shell on the `warmReturnDue` precedent (non-work surface, AD-6).
- Equal plates: same size, same height, same corner, 16dp apart, `photo-frame` 3:4, 1px hairline, labels `Antes`/`Después` outside the frame; empty frame of the right shape on `surface-base` while loading or when bytes fail — no spinner, no shimmer, no gradient (UX-DR29/DR40).
- Copy carries no adjective about the result (`mejor`, `más despejado`, `casi` are banned); the pair has no caption and no share action; the secondary control closes — `Cerrar`, never a *seguir* variant (UX-DR39/DR40).
- Every shoot action follows the Cámara entry rule (UX-DR24): `cameraEntryVisible` gates it — absent never greyed, no dead button. When the shoot action is absent, the reward degrades to the `Un trabajo estupendo` presentation.
- Reward photos never upload → no face gate, no consent, no egress-seam involvement for them.

**Ask First:**
- Any change to the two approved product decisions: Before-shot at scan delivery (not later), and the milestone trigger definitions below.

**Never:**
- No retaining the scan photo, no album table, no new glyph, no denominators or counts on the reward surface, no re-offer nag (declining or closing a reward has zero side effects), no `Un trabajo estupendo` one-plate diff or placeholder plate, no strings outside the single ARB table.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Plan lands, camera standing | `ScanConsentDelivered` | Before-offer: one recommended shoot action + `Cerrar`; shooting writes the blob, appends `before_saved` (group id + blob name), pops to Dispenser | Decline (`Cerrar`) pops with zero writes; offer never repeats for that group |
| Before-offer, camera rule blocks | camera disabled/refused | Offer's shoot action absent — `Cerrar` only, pop; no act; space is a no-Before space | Never a dead button |
| Project milestone, Before exists | `card_done` retires group's last step | Reward route: Before plate shown, shoot-After primary → pair → `album_entry_added` (both blob names + group id), `Cerrar` | — |
| Session milestone, Before exists | `session_ended` with ≥ 1 completed step of that space, group not retired within this session | Same reward route for the space with the most completions | — |
| Milestone, no Before ever | group has no `before_saved` (declined, camera-blocked, or typed-genesis space) | `Un trabajo estupendo` + `Cerrar`; no shoot prompt, no pair; milestone still derivable for FR-26 series (c) | — |
| Reward shoot, camera blocked/lost mid-flow | `cameraEntryVisible` false, or `open()`/`takePicture()` fails or `AccessLost` | Degrade to `Un trabajo estupendo` presentation; nothing written | No error dead-end, no retry loop |
| User closes reward before shooting | back / `Cerrar` | No act, no album entry, no blob for the After; reward not re-offered for that milestone | Zero side effects |
| Before blob unreadable at display | Files read fails / bytes undecodable | That plate renders the empty right-shape frame on `surface-base` | No crash, no error surface |

</frozen-after-approval>

## Code Map

- `lib/ui/scan/consent_gate_screen.dart:214` -- the `ScanConsentDelivered` pop; the Before-offer replaces the bare pop (delivery → offer → pop).
- `packages/core/lib/commands/scan_commands.dart` -- landing minter pattern (`scanSliceLanded`, `epicActivated` :280); new single-sanctioned minters for `before_saved`/`album_entry_added` follow it (pure `List<LogEntryContent>`).
- `packages/core/lib/log/log_entry.dart:208-296` -- `LogKind` vocabulary (`knownByName`/`parse`, census 25), `:315` sealed `LogEntry`, `convertLogEntryRecord`/`LogRecordFlaw`; add 2 kinds + subtypes + payload fields.
- `packages/core/lib/log/log_entry.dart:74` (approx, `LogEntryContent` typedef) -- needs two new nullable String fields (before/after blob names).
- `packages/core/lib/ports/store_port.dart:167` -- `appendLogEntry`/record typedefs, both gain the new columns.
- `lib/store/substrate.drift` + `lib/store/substrate.dart` (`schemaVersion` 13 → 14) + `lib/store/drift_store.dart:46` -- two additive nullable columns, migration, conversion wiring; then `make codegen`.
- `packages/core/lib/weave/weave.dart:341` -- `_epicStepsByGroupKey`: the group fold (stable id = first fact id); retirement must reuse the same answered/superseded fold the weave uses — no second definition.
- `packages/core/lib/derive/camera_entry.dart` -- `cameraEntryVisible(entries)`; reuse verbatim for both shoot actions.
- NEW `packages/core/lib/derive/reward.dart` -- `retiringGroupId(pool, log)` (does this `card_done` retire its group), `sessionMilestoneGroupId(pool, log, session)` (most-completed space, excluding groups retired within the session), `spaceBeforeName(log, groupId)` (latest `before_saved` blob name).
- `packages/core/lib/ports/files_port.dart` -- `FilesPort`; doc already reserves scope `album`. `lib/files/app_files.dart` -- adapter (staging+rename atomicity); add content-addressed album write (sha256 name) — hashing in the shell via `crypto` (new pure-Dart dep, root pubspec only; AD-13 requires it and Epic 9's manifests reuse it).
- `lib/plugins/camera/camera_shell.dart` -- `CameraShell.open()/takePicture()/buildPreview()`; outcomes `granted/denied/interrupted/unavailable`, `Captured(bytes)/None/AccessLost`. Reuse directly, with the viewfinder+shutter framing step of `lib/ui/scan/scan_screen.dart` — no face gate (photos never upload).
- `lib/dispenser/dispenser_controller.dart:698-769` -- `complete`/`_enqueueCompleteWrite`: the `card_done` append site; project-milestone hook follows the enqueue. `:481,553` -- camera-flag threading into views.
- `lib/session/session_controller.dart:152,283` / `lib/dispenser/dispenser_controller.dart:1039` -- `handleSessionEnd`/`pause`: session-milestone hook beside `session_ended`.
- `lib/ui/dispenser/dispenser_view_layers.dart:26` -- `CompletionAck` (tier one, closes never gates); tier two layers on top without touching it.
- `lib/ui/tokens.dart` -- `Radii.radiusDefault`(14)/`radiusThumb`(4), `Spacing.photoPairGap`(16), `FieldPalette.surfaceBase`/`borderHairline` — all exist.
- `lib/ui/dispenser/task_card.dart:29,90` -- `HechoButton` (primary pattern) and `SecondaryTextAction` (48dp, `Cerrar`).
- `lib/ui/scan/consent_gate_screen.dart`, `lib/ui/no_slicer/no_slicer_surface.dart` -- the shared full-screen register (Scaffold→SafeArea→scroll→maxWidth 480 + screenMargin) the reward surface follows.
- NEW `lib/ui/reward/reward_screen.dart` + NEW `lib/ui/photo_frame.dart` -- the reward surface and the `photo-frame` widget (3:4, radius param, hairline, `Image.memory` over `FilesPort.read`, empty-base on loading/failure).
- `lib/l10n/app_es.arb` -- `rewardWithoutPhoto`/`rewardLabelBefore`/`rewardLabelAfter` exist (:486-499); add reward-scoped `Cerrar`, the Before-offer copy (title + shoot label), and the shoot-After label, each with `@key` description; SM-C2 audit applies.
- Tests: `packages/core/test/log_test.dart` (census 25→27 + conversion), `test/no_lateness_proof_test.dart:479-518` (appendLogEntry census — new writers), `test/scan/scan_controller_test.dart` (`_FakeCamera` :168) and `test/ui/scan/scan_screen_test.dart` (before-offer widget), `_RecordingFiles`/`AppFiles(rootOf:)` temp-dir pattern (`test/files/app_files_test.dart`), NEW `packages/core/test/reward_test.dart`, NEW `test/ui/reward/reward_screen_test.dart`.

## Tasks & Acceptance

**Execution:**
- [x] `packages/core/lib/log/log_entry.dart` + `packages/core/lib/ports/store_port.dart` + `lib/store/substrate.drift` + `lib/store/substrate.dart` + `lib/store/drift_store.dart` -- add kinds `before_saved`, `album_entry_added` and two nullable String payload fields (before/after blob names; group id rides `itemId` + `itemOrigin`); drift schema v14 additive migration; regenerate via `make codegen` -- the substrate pair, per the established one-kind-one-minter pattern.
- [x] `packages/core/lib/commands/scan_commands.dart` (or a sibling in `commands/`) -- single-sanctioned minters `beforeSaved(...)` and `albumEntryAdded(...)` returning pure content lists -- no second writer can appear silently.
- [x] NEW `packages/core/lib/derive/reward.dart` -- the three fact derivations (retirement, session milestone, before lookup), reusing the weave's group fold; plus its test file -- milestone facts stay pure and named as facts.
- [x] `packages/core/test/log_test.dart` + `test/no_lateness_proof_test.dart` -- renegotiate kind census (25→27) and appendLogEntry census for the two new writer sites -- the frozen pins must name the new reality.
- [x] Root `pubspec.yaml` + `lib/files/app_files.dart` -- add `crypto` (pure Dart, shell only) and the content-addressed album write/read (sha256 hex name, `.jpg`, `album` scope) -- AD-13's blob naming, with a test over `AppFiles(rootOf:)`.
- [x] NEW `lib/ui/photo_frame.dart` -- the `photo-frame` widget (3:4, radius default 14 / thumb 4, 1px hairline, `surface-base` empty state; `Image.memory`, never a pastel stand-in) with a widget test -- the app's first image surface, shared with 7.2/7.3.
- [x] `lib/l10n/app_es.arb` -- add the four new keys (reward `Cerrar`, Before-offer title + shoot label, shoot-After label) with descriptions; run the string-table audit -- copy enters the single table audited flat (AD-15).
- [x] `lib/ui/scan/consent_gate_screen.dart` (+ `lib/scan/scan_controller.dart` as needed) -- the Before-offer on `ScanConsentDelivered`: gated by `cameraEntryVisible`, one shoot action + `Cerrar`, writes blob + `before_saved`, then pops; decline pops with zero writes -- the approved Before moment.
- [x] NEW `lib/ui/reward/reward_screen.dart` (+ a small controller) -- the reward surface: pair flow (Before plate → shoot After → pair → `album_entry_added` → `Cerrar`) and the `Un trabajo estupendo` arm; camera-rule degrade; back/`Cerrar` before shooting writes nothing.
- [x] `lib/dispenser/dispenser_controller.dart` + `lib/session/session_controller.dart` (+ `lib/ui/dispenser/dispenser_screen.dart` push site) -- hook the two milestone derivations at the retiring `card_done` and at session end; dedupe (session milestone excludes groups already retired within the session); single reward per session (most completions) -- the approved trigger design.
- [x] `test/ui/reward/reward_screen_test.dart` + before-offer cases in `test/ui/scan/scan_screen_test.dart` -- drive the I/O matrix with `_FakeCamera` and `_RecordingFiles` fakes; equal-plate layout pinned by test (same size, gap 16, labels outside, loading empty-base).

**Acceptance Criteria:**
- Given the pair layout, when rendered, then both plates are equal size at equal height with the same corner, 16dp apart, 3:4 with a 1px hairline, labels outside the frames (UX-DR29/DR40).
- Given the reward copy, when audited, then no adjective about the result exists anywhere on the surface; the pair carries only `Antes` and `Después` (FR-17, UX-DR40).
- Given a frame whose image is loading or failed, when rendered, then it shows an empty right-shape frame on `surface-base` — no spinner, shimmer or gradient (UX-DR29).
- Given the reward's secondary control, when labelled, then it reads `Cerrar` — never a *seguir* variant (UX-DR39/DR40).
- Given a completed diff, when saved, then an `album_entry_added` act with both blob names and the group id is appended, automatically, in the same flow (FR-17, AD-21).
- Given a no-Before milestone (declined offer, camera-blocked, or typed-genesis space), when the reward is offered, then it shows `Un trabajo estupendo` with no shoot prompt and no pair (UX-DR57).
- Given a no-Before milestone, when FR-26 series (c) is derived later (Epic 9), then the milestone remains countable from pool + log alone — this story adds no requirement of a pair for visibility.
- Given any shoot action (Before-offer, After), when the camera entry rule blocks it, then the action is absent or the flow degrades to the no-photo presentation — never a dead button (FR-16/FR-29, UX-DR24).
- Given the whole flow, when the egress seal and store seal run, then no new permission, socket, egress payload, or persistence outside Store/Files appears (AD-7/AD-21).

### Review Findings

- [x] [Review][Patch] Degrade system camera failures from the reward to the no-photo presentation [lib/ui/photo_shoot_screen.dart:189]
- [x] [Review][Patch] Roll back a newly written album blob when its log act cannot be appended [lib/reward/reward_controller.dart:117; lib/scan/scan_controller.dart:973]
- [x] [Review][Patch] Invalidate the Before offer when a real lifecycle departure closes its scan [lib/ui/scan/consent_gate_screen.dart:145; lib/scan/scan_controller.dart:967]
- [x] [Review][Patch] Attribute session completions by log order, not device-clock order [packages/core/lib/derive/reward.dart:127]
- [x] [Review][Patch] Cover local slicer-origin spaces in the reward derivations [packages/core/test/reward_test.dart:16]
- [x] [Review][Patch] Serialize an album blob's write, append and rollback as one shared queue operation [lib/reward/reward_controller.dart:116; lib/scan/scan_controller.dart:986]
- [x] [Review][Patch] Preserve an already referenced album blob when a later same-content append fails [test/ui/reward/reward_screen_test.dart:368]
- [x] [Review][Patch] Exercise a v13→v14 recovery after only the first blob-column ALTER landed [test/store/substrate_test.dart:4042]
- [x] [Review][Patch] Align Epic 7's camera-blocked reward fallback with the approved no-photo presentation [_bmad-output/implementation-artifacts/epic-7-context.md:43]
- [x] [Review][Patch] Pin OrganizerApp's reward controller and session-milestone callback wiring [test/ui/app_test.dart:136]

## Spec Change Log

## Design Notes

- **Approved product decisions (2026-09-11):** (1) the Before is shot at scan delivery — the user is still in front of the space, camera in hand; FR-25/AD-8 make every alternative either illegal or meaningless. (2) Triggers: project milestone = the retiring `card_done`; session milestone = `session_ended` with ≥ 1 completed step of that space, deduped against in-session retirements, one space per session. (3) Typed-genesis spaces fire milestones too and always get `Un trabajo estupendo` — they are indistinguishable from scans in the substrate, and the `before_saved` act is the discriminator, which is exactly "Before photos exist only for scanned spaces".
- The before-offer declines permanently for its group — a re-scan of the same corner is a new group with a fresh offer; `Ahora no` would promise a later that never comes, hence `Cerrar`.
- Session-milestone exclusions reuse the weave's own answered/superseded fold; defining a second retirement predicate would let the reward and the weave disagree about what "done" means.
- Tier-one `CompletionAck` is untouched: tier one stays small so tier two means anything (EXPERIENCE.md's two-tier rule).
- Blob bytes are stored verbatim (no re-encode, no EXIF strip): they never upload; export is user-initiated (NFR4) and Epic 9 owns the export seam. `ponytail:` if album storage ever needs a cap, cap at write time in `AppFiles`, never in the core.

## Verification

**Commands:**
- `devbox run -- make test` -- expected: all suites green, including the new core derivation tests and reward widget tests.
- `devbox run -- make test-core` -- expected: core suite green (pure derivations).
- `devbox run -- make check` -- expected: every tool/ check green — string-table audit (new keys), store seal (crypto via Files only), forbidden vocabulary, egress seals untouched, codegen freshness (drift v14).
- `devbox run -- make format-check` && `devbox run -- make analyze` -- expected: clean.
- `wc -c` on this spec ≤ 24576 bytes at review presentation (project story-size gate).

## Suggested Review Order

**The reward surface (entry point)**

- The pair arm and the `Un trabajo estupendo` arm of FR-17 — equal plates, auto-save, degrade.
  [`reward_screen.dart:45`](../../lib/ui/reward/reward_screen.dart#L45)

- The shared framing pipeline: open → viewfinder + shutter → blob → queued append, both photo moments.
  [`photo_shoot_screen.dart:76`](../../lib/ui/photo_shoot_screen.dart#L76)

**The two moments**

- The Before-offer at scan delivery — gate resolved before the offer renders; decline is never latency.
  [`consent_gate_screen.dart:118`](../../lib/ui/scan/consent_gate_screen.dart#L118)

- Milestone hooks: the retiring `card_done` stashes with the just-answered id passed explicitly.
  [`dispenser_controller.dart:803`](../../lib/dispenser/dispenser_controller.dart#L803)

- Guard-before-drain: a covered navigator keeps the milestone stashed for the next commit.
  [`dispenser_screen.dart:856`](../../lib/ui/dispenser/dispenser_screen.dart#L856)

**Core substrate and derivations**

- The two new kinds — vocabulary, read boundary, foreign-photo guards on every kind branch.
  [`log_entry.dart:277`](../../packages/core/lib/log/log_entry.dart#L277)

- Single-sanctioned minters for `before_saved` / `album_entry_added`.
  [`reward_commands.dart:4`](../../packages/core/lib/commands/reward_commands.dart#L4)

- The three fact derivations — retirement, session milestone (dedupe, most completions), before lookup.
  [`reward.dart:55`](../../packages/core/lib/derive/reward.dart#L55)

- Content-addressed album bytes — sha256 name over the port's atomic write, `album` scope.
  [`app_files.dart:64`](../../lib/files/app_files.dart#L64)

- Drift v14 — two additive nullable columns, ALTER-only migration (AD-23).
  [`substrate.dart:214`](../../lib/store/substrate.dart#L214)

**The image widget**

- `photo-frame`: 3:4, radii, hairline, generation-guarded read, empty plate on failure.
  [`photo_frame.dart:25`](../../lib/ui/photo_frame.dart#L25)

**Peripherals**

- The four new ARB keys, no adjective about the result anywhere.
  [`app_es.arb:501`](../../lib/l10n/app_es.arb#L501)

- Equal-plate layout pinned by measurement; pair, degrade, and zero-side-effect close.
  [`reward_screen_test.dart:201`](../../test/ui/reward/reward_screen_test.dart#L201)

- Warm-return contact polarity: both photo kinds as user acts, pinned.
  [`warm_return_test.dart:347`](../../packages/core/test/warm_return_test.dart#L347)

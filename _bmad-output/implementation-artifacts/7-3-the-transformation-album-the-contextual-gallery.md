---
title: 'Story 7.3: The Transformation Album — the contextual gallery'
type: 'feature'
created: '2026-09-12'
status: 'done'
review_loop_iteration: 0
baseline_commit: 'd6277df8422958a35a36106506ceb8013588872f'
context: []
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** FR-18's album has a substrate (7.2: read model, `AlbumController.read/deleteEntry/purge`) but no surface — the pairs exist, are never seen again, and can never be deleted or purged by the user. The reward (7.1) also offers no way onward when a transformation completes.

**Approach:** One new screen, `AlbumScreen`, reached only from the reward's pair-landed arm via a quiet text affordance — contextual navigation, never a permanent destination. Newest-first column of Before/After thumbnail pairs (`PhotoFrame` at `Radii.radiusThumb`, labels outside), a one-tap delete per entry, a one-tap purge for the whole album — both invoking 7.2's controller verbatim. No empty state: an empty read pops the surface.

## Boundaries & Constraints

**Always:**
- Entry point: the affordance appears **only in the reward screen's pair-landed arm** (`_afterName != null` — the transformation-completed moment); never on the shoot-offered or no-Before arms, never anywhere else in the app. Tapping pushes `AlbumScreen` guarded by the rapid-tap `ModalRoute.of(context)?.isCurrent` idiom.
- Screen skeleton mirrors `reward_screen.dart`: `Scaffold → SafeArea → SingleChildScrollView → Center → ConstrainedBox(maxWidth: registerMaxWidth) → Column` — scrolls so the 200% floor holds; no `maxLines`/ellipsis/FittedBox.
- Entries render newest-first (reverse of the fold's log order), each a `Row` of two `Expanded` `PhotoFrame`s at `radius: Radii.radiusThumb`, `Spacing.photoPairGap` apart, labels `Antes`/`Después` below via the existing ARB keys — no captions, no dates, no counts (UX-DR40; the gallery shows no number of any kind, AD-26).
- Delete and purge are **one tap each, no confirmation** (FR-18 "one action"; interaction primitives: nothing important costs two). Both call the controller, then a fresh `read()` re-renders truth; an empty result pops the screen (UX-DR51 — no empty state, no copy).
- Failures: a read failure leaves the quiet pending state (never an empty-album reading, never a pop); a mutation failure is caught, followed by the same fresh `read()` — the surface shows the log's truth, no error chrome, no success-reading toast (offline is never an error; honest functioning = the visible state is the real state).
- All copy through `AppStrings.of(context)`; the four new ARB keys carry `@` descriptions. No string literals in the new file (AD-15). Colors only via `Theme.of(context)` (dark mode follows).

**Ask First:**
- Any second entry point to the album, any confirmation dialog before delete/purge, any date or place caption on gallery entries, any Settings purge row (that home belongs to a later story's surface).

**Never:**
- No core changes (the read model and controller are done — 7.2); no new log kinds, no FilesPort changes, no egress path.
- No empty-state copy, no GridView, no nav bar/destination list, no AppBar (close is a `SecondaryTextAction` `Cerrar`).
- No spinner/shimmer/gradient while photos load (`PhotoFrame`'s empty right-shape plate is the loading state).

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Open from reward | pair landed, album non-empty | `AlbumScreen` pushed; entries newest-first, two thumb frames per entry | — |
| Delete one entry | tap `Borrar` under an entry | `album_entry_deleted` + unlink via controller; fresh read; entry gone, rest intact | On throw: fresh read; entry shows truth |
| Delete last entry | album held one entry | Fresh read empty → screen pops | — |
| Purge | tap `Borrar todo` | `album_purged` + sweep via controller; screen pops | On throw: fresh read; truth shown |
| Empty read on open | stale reward affordance after an earlier purge | Screen reads empty → pops itself (unreachable-by-construction; no empty state) | Read throws → stay quiet-pending, `Cerrar` works |
| Reward arms | shoot-offered / no-Before | No album affordance rendered | — |

</frozen-after-approval>

## Code Map

- NEW `lib/ui/album/album_screen.dart` -- `AlbumScreen({this.album})`, StatefulWidget on the reward screen's pattern (one-shot read in initState, generation-guarded setState); State: `_entries`, `_read()`→pop-if-empty, `_delete(entry)`, `_purge()`; frames from `album.files`.
- `lib/ui/reward/reward_screen.dart:182-207` -- pair-landed arm gains `SecondaryTextAction(label: strings.rewardOpenAlbum, onTap: _openAlbum)` above the close (`:245-250`); `_openAlbum` pushes `AlbumScreen` under the `ModalRoute.isCurrent` guard; new nullable `this.album` param (`AlbumController?`, the test seam) — `AlbumScreen` reads `files` off `album.files` (public field), the same source reward uses via `controller.files`.
- `lib/ui/dispenser/dispenser_screen.dart:871-897` -- `_maybePushReward` passes `album: widget.album` into `RewardScreen`; new nullable `album` field on `DispenserScreen`.
- `lib/main.dart:196,277,312-322` -- thread the already-constructed `AlbumController` (root field `album`, "held at the root, unread until 7.3's gallery surface claims it") into `DispenserScreen`.
- `lib/ui/photo_frame.dart:33` -- `PhotoFrame(files:, name:, radius: Radii.radiusThumb)` reused unchanged; `lib/ui/tokens.dart:199` -- `Radii.radiusThumb = 4`.
- `lib/ui/dispenser/task_card.dart:90-131` -- `SecondaryTextAction` reused for affordance/delete/purge/close.
- `lib/album/album_controller.dart:73,88,172` -- `read()/deleteEntry(AlbumEntry)/purge()` invoked verbatim; no controller edits.
- `packages/core/lib/derive/album.dart:40` -- `AlbumEntry` record (`groupId, origin, beforeName, afterName, addedUtcMicros`); read-only.
- `lib/l10n/app_es.arb` -- +4 keys after the reward register (~L518): `albumTitle` "Tu álbum", `rewardOpenAlbum` "Ver el álbum", `albumEntryDelete` "Borrar", `albumPurge` "Borrar todo"; each with `@` description (contextual-only rule, one-tap no-confirmation, no-numbers). Then `make codegen`.
- `test/ui/reward/reward_screen_test.dart` -- per-file fakes (`_RecordingStore`/`_RecordingFiles`) extended: affordance appears in pair-landed arm only; tap pushes `AlbumScreen`.
- NEW `test/ui/album/album_screen_test.dart` -- same per-file fake convention; drives the whole I/O matrix.

## Tasks & Acceptance

**Execution:**
- [x] `lib/l10n/app_es.arb` + `make codegen` -- four keys with descriptions, generated files committed.
- [x] NEW `lib/ui/album/album_screen.dart` -- the gallery: title, newest-first pairs at thumb radius, per-entry `Borrar`, `Borrar todo`, `Cerrar`; read/mutate/pop flow per Boundaries.
- [x] `lib/ui/reward/reward_screen.dart` + `lib/ui/dispenser/dispenser_screen.dart` + `lib/main.dart` -- affordance in the pair-landed arm only; `AlbumController` threaded root → Dispenser → Reward → AlbumScreen.
- [x] NEW `test/ui/album/album_screen_test.dart` + `test/ui/reward/reward_screen_test.dart` -- the I/O matrix + affordance gating.

**Acceptance Criteria:**
- Given the reward with a landed pair, when the arm renders, then exactly one album affordance appears as quiet prose, and it is the app's only way into the gallery (UX-DR31/32).
- Given gallery thumbnails, when measured, then every frame is `PhotoFrame` at 4px radius with labels outside (UX-DR7/29).
- Given an entry delete, when it completes, then the surface invoked 7.2's single deletion operation and the entry left the gallery (FR-18, AD-13).
- Given the album, when the user purges, then one action invoked 7.2's purge and no confirmation intervened (FR-18).
- Given any empty album read, when the screen would render, then no empty state or copy exists — the surface pops (UX-DR51).
- Given `make gate`, when it runs, then all targets pass with no seal edits, no forbidden-vocabulary hits, and the string-table audit green.

## Spec Change Log

## Design Notes

- **Why pop-on-empty instead of an empty screen:** UX-DR51 pins "no empty state or copy"; a screen that closes itself when it has nothing is the only rendering of that rule. The stale-affordance path (purge → back → tap `Ver el álbum`) degrades to open-then-pop — accepted, rare, self-correcting.
- **Why re-read after every mutation:** the log is the only truth (AD-13); one code path (read → render-or-pop) covers success, failure and idempotent double-taps. The fold is O(log) with no index — fine at album scale (`ponytail:` noted in 7.2).
- **Why labels reuse the reward ARB keys:** `Antes`/`Después` are "the only labels on a Before/After pair" — pair vocabulary, not reward-specific; one string table, no duplicates.

## Verification

**Commands:**
- `devbox run -- make gate` -- expected: check (incl. string-table audit, no-literal-strings, text-scaling, vocabulary), test, format-check, analyze all green.
- `wc -c` on this spec ≤ 24576 bytes at review presentation.

**Manual checks (if no CLI):**
- On emulator: complete a transformation → reward shows `Ver el álbum` only after the pair lands; gallery thumbs at 4px radius; delete and purge remove bytes (log inspection per AGENTS.md emulator recipe); 200% font scale scrolls.

## Suggested Review Order

**The gallery — the story's heart (entry point)**

- The one commit path: read, render or pop — no empty state, guarded pops, honest failures.
  [`album_screen.dart:71`](../../lib/ui/album/album_screen.dart#L71)

- The rendering: newest-first pairs, the deliberate air before the irreversible purge, shared close.
  [`album_screen.dart:188`](../../lib/ui/album/album_screen.dart#L188)

- One entry: the pair grammar at thumb radius — two frames, labels outside, one `Borrar`.
  [`album_screen.dart:229`](../../lib/ui/album/album_screen.dart#L229)

**The one entry point — contextual navigation**

- The push under the rapid-tap guard; the app's only way into the gallery.
  [`reward_screen.dart:165`](../../lib/ui/reward/reward_screen.dart#L165)

- The affordance sited in the pair-landed arm alone — never a permanent destination.
  [`reward_screen.dart:261`](../../lib/ui/reward/reward_screen.dart#L261)

- The seam hand-down the whole feature hangs on: root controller → Dispenser → Reward.
  [`dispenser_screen.dart:894`](../../lib/ui/dispenser/dispenser_screen.dart#L894)

**Copy — the single string table**

- Four keys, each with its rule in the description: contextual-only, one tap, no numbers.
  [`app_es.arb:521`](../../lib/l10n/app_es.arb#L521)

**Peripherals — the pins**

- The seam pins: composition reaches the Dispenser and the pushed Reward verbatim.
  [`app_test.dart:306`](../../test/ui/app_test.dart#L306)

- The I/O matrix driven end-to-end: purge failure, stale reads, empty-pop, quiet pending.
  [`album_screen_test.dart:450`](../../test/ui/album/album_screen_test.dart#L450)

- Affordance gating on every arm, double-tap, and the return leg with the stale path.
  [`reward_screen_test.dart:283`](../../test/ui/reward/reward_screen_test.dart#L283)

## Manual Verification (Android emulator, 2026-09-12)

**Environment:** AVD `organizer36` (Pixel 6, API 36 `google_apis` x86_64, KVM), debug `app-debug.apk` @ `6582c3f`, driven over adb; UI read via `screencap` + OCR, every observation cross-checked against the pulled substrate DB. State synthesized by direct substrate seeding (the 2-7 precedent): two single-step `local`-origin epic groups (`scan-alpha`/`scan-beta` contexts) + `epic_activated` + `before_saved` rows + two content-addressed JPEGs pushed into `files/album/`. Two machine-local pitfalls hit and worked around: pushed files land root-owned (app uid cannot write — chown before launch), and the WAL-less push must replace a force-stopped app. Day 2 synthesized via clock +25 h (`adb root` + `date -s`); the day-2 focus chunk needed a fresh pocket that could hold the 10-min step.

| Check | Observed |
|---|---|
| Contextual entry | `Ver el álbum` absent on the shoot-offered arm; appears the moment the pair lands (both days) ✓ |
| Pair grammar | Two equal plates (452×600 px, ~44 px gap), labels `Antes`/`Después` outside the frames ✓ |
| Gallery render | `Tu álbum` title; thumbnails at the small cut-edge radius with 1 px hairline; newest-first (day-2 entry above day-1's); one `Borrar` per entry ✓ |
| Delete one entry | `album_entry_deleted|step-b1` appended; gallery re-read shows the other entry intact ✓ |
| Purge | One tap, no confirmation: `album_purged` appended, `files/album/` swept to 0 files, screen popped ✓ |
| No empty state | Post-purge tap on the stale reward affordance: gallery opens, reads empty, pops itself — back on the reward, no empty copy ✓ |
| 200 % font scale | Gallery renders complete (title, pair, all controls), nothing truncated or overlapping ✓ |
| Log truth | Final album rows: `album_entry_added`×2, `album_entry_deleted`×1, `album_purged`×1 — matching every UI act ✓ |

Also exercised incidentally: the 6.1 purge cards dealt ahead of each group's steps (skip closes them), the Sunday self-report holding the strip, and the pocket ladder declaring the day-2 session.

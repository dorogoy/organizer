---
title: 'Story 7.2: The album substrate — the derived read model and the deletion acts'
type: 'feature'
created: '2026-09-12'
status: 'done'
review_loop_iteration: 0
baseline_commit: 'd60e908669c4b85ee53fff93e2a8af510c24399f'
context: []
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** FR-18's album has writers but no readers or deleters — 7.1 appends `album_entry_added` and writes content-addressed blobs, yet nothing derives the album's contents, an entry can never be deleted, the album can never be purged, and a Before blob shot at scan delivery lives forever once its transformation is declined. The substrate 7.3 (gallery) and 7.4 (dashboard) must sit on does not exist.

**Approach:** Core-side substrate, no drawn surface. Two new log kinds — `album_entry_deleted` (carries the deleted entry's before/after blob names, reusing the v14 columns) and `album_purged` (no payload) — each with a single sanctioned minter. A pure read model in `core/derive/album.dart` folds acts into live album entries and into the set of blob names pinned by effective acts; deletion and purge unlink exactly the unpinned names. A small `AlbumController` joins the root-owned write queue and performs unlink + append as one serialized operation (unlink first — privacy beats reversibility), exposing `deleteEntry`/`purge` for 7.3's surface to invoke.

## Boundaries & Constraints

**Always:**
- No album table (AD-13): the read model is derived over log acts and the content-addressed Files blobs; no drift migration, `schemaVersion` stays 14.
- Deletion is one operation on the shared `LogWriteQueue`: compute pinned names from a fresh log read inside the queued closure, unlink the entry's unpinned names via `FilesPort.delete`, then append `album_entry_deleted`. Purge: `sweepAlbum()` then append `album_purged`.
- Pin principle (one fold, no second definition): a blob name is pinned iff an effective act references it — `before_saved` (dead once any later `album_purged` exists), `album_entry_added` (dead once a later `album_entry_deleted` with the same before/after pair or any later `album_purged` exists). An entry's before blob stays pinned by its `before_saved`; deletion unlinks the after blob unless another live entry shares its name.
- `spaceBeforeName` folds `album_purged`: a Before saved before the last purge is dead, so a post-purge milestone degrades to `Un trabajo estupendo` — no pair flow against swept bytes, no act referencing files that cannot exist.
- Unlink ordering is privacy-first: bytes go first, the act second. An append failure leaves files already gone and the failure surfaces to the caller (honest functioning) — never a quiet success that reads as deleted-while-bytes-linger, and never the reverse order (an act asserting a deletion that did not happen).
- Album bytes never leave the device here: no egress code touched; exports are Epic 9's seam. Unlink/sweep touch only the `album` scope inside app-private storage (user-initiated exports land outside it, in the user's chosen folder — structurally unreachable by the sweep).
- Core stays pure (no Flutter/drift/plugin/`dart:io` imports, no wall-clock, no `Random`); new derivations are named as facts; minters return pure `List<LogEntryContent>`.

**Ask First:**
- Any change to the pin principle (e.g. making entry deletion also unlink the before blob) or to the unlink-before-append ordering.

**Never:**
- No drawn surface, no ARB keys, no widget screens (7.3/7.4 own them); no listing/search/watch on Files scopes (the port bans it — purge is a blind sweep); no `album_entry_deleted`/`album_purged` flags retrofitted onto existing kinds; no new FilesPort read methods; no un-append of log acts (append-only substrate).

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Delete live entry | entry with exclusive after, before shared by its group's `before_saved` | `album_entry_deleted` appended (pair names + group id); after blob unlinked; before blob kept (still pinned) | — |
| Delete entry with shared after name | another live entry pins the same content-addressed after name | Act appended; no file unlinked; the other entry and its bytes intact | — |
| Purge | entries + orphaned Before blobs on disk | `album_purged` appended; every file in the `album` scope swept, scope dir survives | — |
| Append fails after unlink | store write error post-unlink | Files stay deleted; the operation rethrows to the caller; no silent success | Retry = invoke again (delete is idempotent, sweep is blind) |
| Delete of an already-dead entry | double invocation / stale entry | Files already absent (quiet idempotent delete); act still appended; fold no-ops | — |
| Post-purge milestone | group whose Before predates the purge | `spaceBeforeName` → null → `Un trabajo estupendo`; a Before saved after the purge is effective | — |
| Concurrent save vs delete | reward writer and album deleter race | Serialized by the shared queue; each op reads the log inside its closure, so the fold never sees a torn state | — |

</frozen-after-approval>

## Code Map

- `packages/core/lib/log/log_entry.dart:277-308` -- `LogKind` census 27 → 29: constants + `knownByName` entries for `albumEntryDeleted`/`albumPurged`, following the exact wiring of `albumEntryAdded` (:278).
- `packages/core/lib/log/log_entry.dart:865,1157,1853,1913` -- sealed subtypes `AlbumEntryDeletedEntry` (itemId/itemOrigin + beforeName/afterName, mirroring `AlbumEntryAddedEntry`) and `AlbumPurgedEntry` (no payload); `convertLogEntryRecord` branches + `LogRecordFlaw` cases (`photoNameOnNonPhotoKind` family: deleted requires the pair, purged forbids both) + `carriesPhoto` (:1303) + the foreign-column guard on every existing branch.
- `packages/core/lib/commands/session_commands.dart:77` -- `LogEntryContent` (21 fields): both new kinds ride existing columns (`beforeName`/`afterName`, `itemId`/`itemOrigin`); no field added.
- `packages/core/lib/commands/reward_commands.dart:22,60` -- single-sanctioned minters `albumEntryDeleted({groupId, origin, beforeName, afterName})` and `albumPurged()` beside `beforeSaved`/`albumEntryAdded`.
- NEW `packages/core/lib/derive/album.dart` -- `albumEntries(log)` → live entries in log order (record: groupId, origin, beforeName, afterName, addedUtcMicros); `albumPinnedNames(log)` → the pin fold. This is the one place Epic 9's retained generations will join as claimants.
- `packages/core/lib/derive/reward.dart:189+` -- `spaceBeforeName`: add the `album_purged` fold (last purge kills earlier `before_saved` matches).
- `packages/core/lib/ports/files_port.dart:60` -- `FilesPort` gains `sweepAlbum()` (void, blind mass-unlink of the `album` scope, mirroring `sweepScanCache()`); doc note in the scope list.
- `lib/files/app_files.dart:417-455` -- `sweepAlbum` implementation reusing the `sweepScanCache` sweep body over the flat album dir; `delete` (:261) and `albumPhotoName` (:56) reused as-is.
- NEW `lib/album/album_controller.dart` -- `AlbumController(store, files, writeQueue, idMinter, nowOf)` on the `RewardController` (:37-152) constructor pattern; `read()` → live entries; `deleteEntry(...)`/`purge()` enqueue unlink-then-append closures on the shared queue.
- `lib/main.dart:121-180` -- wire `AlbumController` beside `RewardController` with the same store, shared `logWrites` queue, files.
- `lib/session/log_write_queue.dart` -- `LogWriteQueue.enqueue` reused unmodified.
- Tests: `packages/core/test/log_test.dart:119` (census 27→29 + conversion/flaw cases), `test/no_lateness_proof_test.dart:646-743` (appendLogEntry census: `lib/album/album_controller.dart: 2`; kind counts +2), NEW `packages/core/test/album_test.dart` (fold + pins, `reward_test.dart` fixture pattern :16-68), NEW `test/album/album_controller_test.dart` (real temp-dir `AppFiles(rootOf:)` + fake store: matrix rows, ordering, queue serialization), `test/files/app_files_test.dart:434+` (sweepAlbum: empties scope, dir survives, other scope untouched).
- `test/scan/scan_controller_test.dart:122` + `test/ui/reward/reward_screen_test.dart:55` -- `_RecordingFiles` fakes grow `sweepAlbum` (no-op) — the interface price of one port method.

## Tasks & Acceptance

**Execution:**
- [x] `packages/core/lib/log/log_entry.dart` -- kinds `albumEntryDeleted`/`albumPurged`: constants, map, sealed subtypes, conversion branches, flaw cases, `carriesPhoto`, foreign-column guards on every branch -- the substrate pair's third act, per the one-kind-one-minter pattern.
- [x] `packages/core/lib/commands/reward_commands.dart` -- minters `albumEntryDeleted`/`albumPurged` returning pure content lists -- no second writer can appear silently.
- [x] NEW `packages/core/lib/derive/album.dart` -- `albumEntries` fold (tombstoning by pair-match delete and by purge) + `albumPinnedNames` pin fold -- the read model, named as facts.
- [x] `packages/core/lib/derive/reward.dart` -- `spaceBeforeName` folds `album_purged` -- post-purge milestones degrade to the no-Before arm.
- [x] `packages/core/lib/ports/files_port.dart` + `lib/files/app_files.dart` -- `sweepAlbum()` port + blind sweep implementation -- purge's unlink, without listing (banned by the port's contract).
- [x] NEW `lib/album/album_controller.dart` + `lib/main.dart` -- `read`/`deleteEntry`/`purge` on the shared write queue, unlink-first ordering, honest failure rethrow; wired beside RewardController -- the operation 7.3's surface invokes.
- [x] `packages/core/test/log_test.dart` + `test/no_lateness_proof_test.dart` + `test/scan/scan_controller_test.dart` + `test/ui/reward/reward_screen_test.dart` -- renegotiate censes (kinds 29, writer site +2, fakes grow `sweepAlbum`) -- frozen pins name the new reality.
- [x] NEW `packages/core/test/album_test.dart` + NEW `test/album/album_controller_test.dart` + `test/files/app_files_test.dart` -- drive the I/O matrix: fold semantics, pin decisions, unlink ordering, sweep isolation, queue serialization.

**Acceptance Criteria:**
- Given the album, when its storage is inspected, then every blob lives in app-private Files storage under the `album` scope and no egress path is added or touched — bytes leave only via user-initiated export into a user-chosen folder (FR-18, NFR4; egress/store seals green with no seal edits).
- Given the album, when its read model is inspected, then it is derived from log acts + Files blobs with no album table and no manifest record (AD-13).
- Given an entry deletion, when the operation completes, then `album_entry_deleted` is appended and the entry's unpinned source files are unlinked within the same queued operation (FR-18, AD-13).
- Given the album, when purge runs, then one operation sweeps every `album`-scope file and appends `album_purged` (FR-18).
- Given a committed export generation, when a source file is deleted or purged, then the export stays valid: unlink decisions route through `albumPinnedNames` (the seam retained generations join), and exports live outside the swept scope (AD-13).
- Given a Before saved before a purge, when a later milestone fires, then the reward degrades to `Un trabajo estupendo` — the fold never offers a pair whose bytes cannot exist.

## Spec Change Log

## Design Notes

- **Why unlink-first:** the log is append-only, so 7.1's rollback pattern cannot transfer — an act cannot be un-appended. Between "bytes linger after promised deletion" (privacy betrayal, invisible) and "entry shows while its bytes are gone" (visible, retryable, degrades to the empty frame), the second is the survivable failure. The queue keeps the two steps from interleaving with concurrent writers; that is the strongest atomicity the two stores admit.
- **Why the before blob survives entry deletion:** it is pinned by its own `before_saved` — the deliberate shot for the space, per FR-25. A later session milestone for the same unretired group re-offers a real pair. Purge is the act that clears it; after a purge the space behaves as a no-Before space. Content-addressing makes the pin check name equality, nothing more.
- **Pair-match is group-scoped (review refinement, 2026-09-12):** an `album_entry_deleted` tombstones an `album_entry_added` only when the group pair (itemId+origin) AND the before/after names all match. FR-18 deletes entries *individually*; a byte-identical content-addressed pair in another group is that group's own transformation, and the delete act carries the group pair precisely to name its entry. For every non-pathological log this is the same rule the pin principle states.
- **Epic 9 seam:** `albumPinnedNames(log)` is deliberately the only unlink oracle. When export generations land, their manifests join this fold as claimants — no other code changes shape. `ponytail:` the fold is O(log) per query with no index; fine at album scale, revisit only if a profile says otherwise.
- **Purge act shape:** one `album_purged` (not N per-entry deletes) because the user fact is "the album was purged", and because per-entry deletes would leave orphaned Before blobs' claims live while their bytes are swept — drift.

## Verification

**Commands:**
- `devbox run -- make test` -- expected: all suites green, including the new core fold tests and album controller tests.
- `devbox run -- make test-core` -- expected: core suite green (pure derivations).
- `devbox run -- make check` -- expected: every tool/ check green with no seal-weakening edits — store seal (no new persistence), egress seals (album bytes never sent), forbidden vocabulary, codegen freshness (schema still v14 — no codegen delta). The AD-15 no-literal-strings allowlist grows by the controller's three named diagnostic constants (`albumBlobSurvivedDeleteTemplate`/`albumBlobSurvivedPurgeTemplate`/`albumBlobNameSlot`) — the sanctioned named-constant mechanism, the same register `albumFilesScope` uses.
- `devbox run -- make format-check` && `devbox run -- make analyze` -- expected: clean.
- `wc -c` on this spec ≤ 24576 bytes at review presentation (project story-size gate).

**Run evidence (2026-09-12, post-review patches):** make check 16/16 · make test 1265 passed · make test-core 892 passed · format-check 0 changed · analyze clean.

## Suggested Review Order

**The read model — the story's heart (entry point)**

- The live fold: add, tombstone by group+pair, purge-clear — log order, no table.
  [`album.dart:61`](../../packages/core/lib/derive/album.dart#L61)

- The pin fold — the one unlink oracle; Epic 9's generations join here as claimants.
  [`album.dart:102`](../../packages/core/lib/derive/album.dart#L102)

- The unlink oracle: the delete synthesized onto the log, no shell-side domain object.
  [`album.dart:181`](../../packages/core/lib/derive/album.dart#L181)

**The two acts — substrate, schema stays v14**

- Kinds 28–29 wired beside 7.1's pair.
  [`log_entry.dart:288`](../../packages/core/lib/log/log_entry.dart#L288)

- Sealed subtypes: deleted mirrors added (group pair + blob names); purged is payload-less.
  [`log_entry.dart:928`](../../packages/core/lib/log/log_entry.dart#L928)

- Single-sanctioned minters — no second writer can appear silently.
  [`reward_commands.dart:115`](../../packages/core/lib/commands/reward_commands.dart#L115)

**The degrade — a Before cannot outlive its bytes**

- `spaceBeforeName` folds the purge: post-purge milestones get `Un trabajo estupendo`.
  [`reward.dart:189`](../../packages/core/lib/derive/reward.dart#L189)

**The operations — unlink first, act second, one queue**

- `deleteEntry`: fresh log read inside the closure, unlink, read-back verify, append.
  [`album_controller.dart:88`](../../lib/album/album_controller.dart#L88)

- `purge`: blind sweep, then every act-referenced name verified gone before the act.
  [`album_controller.dart:172`](../../lib/album/album_controller.dart#L172)

- The port's blind mass-unlink — listing stays banned; the doc names both roles.
  [`files_port.dart:124`](../../packages/core/lib/ports/files_port.dart#L124)

- The adapter sweep, shared `_sweepScope` body with the scan cache.
  [`app_files.dart:422`](../../lib/files/app_files.dart#L422)

- Wired beside RewardController on the shared store, queue and Files.
  [`main.dart:137`](../../lib/main.dart#L137)

**Cross-cutting — the new acts as user contact**

- Deleting an entry or purging is using the app: the 48 h anchor moves.
  [`warm_return.dart:105`](../../packages/core/lib/derive/warm_return.dart#L105)

**Peripherals**

- Kind census 29 + the pair's conversion/flaw tests.
  [`log_test.dart:124`](../../packages/core/test/log_test.dart#L124)

- The append census: two writer sites, both maps.
  [`no_lateness_proof_test.dart:736`](../../test/no_lateness_proof_test.dart#L736)

- Fold semantics: shared-after, re-save re-pins, cross-group identical pairs.
  [`album_test.dart:1`](../../packages/core/test/album_test.dart#L1)

- The controller matrix: exclusive/shared delete, ordering, refusal, serialization.
  [`album_controller_test.dart:227`](../../test/album/album_controller_test.dart#L227)

- The concurrency pin: a real RewardController writer shares the queue.
  [`album_controller_test.dart:488`](../../test/album/album_controller_test.dart#L488)

- Warm-return sweep rows for both new kinds — the flip now fails the suite.
  [`warm_return_test.dart:369`](../../packages/core/test/warm_return_test.dart#L369)

- Sweep isolation: empties the scope, dir survives, other scopes untouched.
  [`app_files_test.dart:479`](../../test/files/app_files_test.dart#L479)

- AD-15 allowlist: the three named diagnostic constants (the sanctioned register).
  [`check_no_literal_strings.dart:208`](../../tool/check_no_literal_strings.dart#L208)

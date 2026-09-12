// The album channel's shell half (Story 7.2, FR-18): the substrate's
// own controller — the read model's reader and the two deletion acts
// 7.3's surface will invoke. The folds live in the core
// (`core/derive/album.dart`); this controller owns the operations:
// one queued closure per act on the shell's shared `LogWriteQueue`,
// each reading the log fresh inside the closure so the fold never
// sees a torn state, unlinking through the pin fold's answer, then
// appending the act through the kind's single sanctioned minter.
//
// Unlink ordering is privacy-first: the bytes die before the act that
// promises their death lands. The log is append-only — an act cannot
// be un-appended — so between "bytes linger after promised deletion"
// (a privacy betrayal, invisible) and "the entry shows while its
// bytes are gone" (visible, retryable, degrades to the empty frame),
// the second is the survivable failure. And because the port's
// delete is quiet by contract, the controller VERIFIES each unlink
// with a read-back before any act lands: a name still readable after
// its delete throws before the append — never an act asserting a
// deletion that did not happen. An append failure after the unlink
// rethrows to the caller — honest functioning, never a quiet success
// that reads as deleted-while-bytes-linger. Retry is invocation: the
// delete is idempotent and the sweep is blind.
import 'package:core/commands/reward_commands.dart';
import 'package:core/derive/album.dart';
import 'package:core/log/log_entry.dart';
import 'package:core/ports/files_port.dart';
import 'package:core/ports/store_port.dart';
import 'package:uuid/uuid.dart';

import '../files/app_files.dart';
import '../session/log_write_queue.dart';

/// The delete's read-back failure template (Story 7.2): crash-path
/// diagnostics naming the blob that survived its unlink — a named
/// decision on the catalogue loader's own terms, never widget copy.
const String albumBlobSurvivedDeleteTemplate =
    'album blob {blob} survived its deletion — no act landed';

/// The purge's read-back failure template (Story 7.2): the same
/// register over the sweep.
const String albumBlobSurvivedPurgeTemplate =
    'album blob {blob} survived the purge sweep — no act landed';

/// The templates' blob-name slot.
const String albumBlobNameSlot = '{blob}';

/// The album channel's shell half (Story 7.2, FR-18): see the library
/// comment. The injectables follow `RewardController`'s — the shell
/// may read the clock and mint ids, the core never does. The write
/// queue is required, never defaulted: this story's core contract is
/// the SHARED queue, and a construction site that omits it must not
/// compile.
class AlbumController {
  AlbumController({
    required this.store,
    required this.files,
    required this.writeQueue,
    this.idMinter = const Uuid(),
    this.nowOf = DateTime.now,
  });

  final StorePort store;
  final FilesPort files;
  final LogWriteQueue writeQueue;
  final Uuid idMinter;
  final DateTime Function() nowOf;

  /// The album's live entries over one log read (`albumEntries`, the
  /// read model's own fold) — the list 7.3's gallery renders. A
  /// failing read rethrows: a transient store error must not read as
  /// an empty album on a photo surface — the album has no empty
  /// state, so 7.3 must see the difference.
  Future<List<AlbumEntry>> read() async {
    return albumEntries(logEntriesOf(await store.readLogEntries()));
  }

  /// Deletes one album entry (Story 7.2, FR-18, AD-13): one queued
  /// operation — compute the pinned names over a fresh log read with
  /// the delete act synthesized onto it (the entry's own claim dies,
  /// every other live claim stands), unlink the entry's unpinned
  /// names, then append exactly one `album_entry_deleted` row through
  /// the kind's single sanctioned minter. The entry's before blob
  /// stays when its `before_saved` still pins it — the deliberate
  /// shot for the space (FR-25); a shared after name stays while
  /// another live entry claims it. A failing append leaves the files
  /// already gone and rethrows — retry is invocation, and the fold
  /// no-ops on an already-dead entry.
  Future<void> deleteEntry(AlbumEntry entry) {
    return writeQueue.enqueue(() async {
      // The commit-time instant, minted inside the queued closure
      // (`saveAfterBlob`'s own precedent — the shell mints ids,
      // instants and offsets at the commit of each act, and a queued
      // operation must not wear an enqueue-time stamp).
      final now = nowOf();
      final log = logEntriesOf(await store.readLogEntries());
      // The unlink answer comes from the pin fold over the log as it
      // will be once the delete act lands (the core's own synthesis
      // — the shell constructs no domain object, AD-5): the entry's
      // own claim dies, every other live claim stands.
      final unlinked = albumUnlinkedByDelete(
        log,
        groupId: entry.groupId,
        origin: entry.origin,
        beforeName: entry.beforeName,
        afterName: entry.afterName,
        instantUtcMicros: now.microsecondsSinceEpoch,
        offsetSeconds: now.timeZoneOffset.inSeconds,
      );
      // Bytes first — privacy beats reversibility, and each unlink
      // is verified before any act may land: the port's delete is
      // quiet by contract, so a name still readable after its delete
      // throws — never an act asserting a deletion that did not
      // happen.
      for (final name in unlinked) {
        await files.delete(albumFilesScope, name);
        if (await files.read(albumFilesScope, name) != null) {
          throw StateError(
            albumBlobSurvivedDeleteTemplate.replaceFirst(
              albumBlobNameSlot,
              name,
            ),
          );
        }
      }
      for (final content in albumEntryDeleted(
        groupId: entry.groupId,
        origin: entry.origin,
        beforeName: entry.beforeName,
        afterName: entry.afterName,
      )) {
        await store.appendLogEntry((
          id: idMinter.v7(),
          kind: content.kind.name,
          instantUtcMicros: now.microsecondsSinceEpoch,
          offsetSeconds: now.timeZoneOffset.inSeconds,
          itemId: content.itemId,
          itemOrigin: content.itemOrigin,
          stack: content.stack,
          settingKey: content.settingKey,
          settingValue: content.settingValue,
          settingTextValue: content.settingTextValue,
          pocketMinutes: content.pocketMinutes,
          energyLevel: content.energyLevel,
          reportValue: content.reportValue,
          reportWeek: content.reportWeek,
          permission: content.permission?.name,
          sliceCause: content.sliceCause,
          cluster: content.cluster?.name,
          enabled: content.enabled,
          triageDestination: content.triageDestination?.name,
          triageVolumeTag: content.triageVolumeTag?.name,
          triageBoxId: content.triageBoxId,
          beforeName: content.beforeName,
          afterName: content.afterName,
        ));
      }
    });
  }

  /// Purges the album (Story 7.2, FR-18): one queued operation — the
  /// Files port's blind `sweepAlbum` (every album-scope blob dies,
  /// the scope directory remains, no child is ever named), the same
  /// read-back verification over every album blob name any act in
  /// the fresh log read references, then exactly one `album_purged`
  /// row through the kind's single sanctioned minter. The act's
  /// position in the log is its whole claim: every earlier
  /// `before_saved` and `album_entry_added` dies before it, so a
  /// post-purge milestone degrades to the no-Before arm until a
  /// fresh Before lands. A refused sweep or a failing append leaves
  /// the bytes already gone and rethrows — retry is invocation, and
  /// the sweep is blind to what already went.
  Future<void> purge() {
    return writeQueue.enqueue(() async {
      // The commit-time instant, inside the closure — `deleteEntry`'s
      // own terms.
      final now = nowOf();
      // Bytes first — the blind sweep, then the same read-back
      // verification over every album blob name any act references:
      // a blob still readable after the sweep throws before the act
      // lands, so the `album_purged` row never asserts a sweep that
      // did not happen.
      await files.sweepAlbum();
      final log = logEntriesOf(await store.readLogEntries());
      for (final entry in log) {
        switch (entry) {
          case BeforeSavedEntry():
            await _verifyGone(entry.blobName);
          case AlbumEntryAddedEntry():
            await _verifyGone(entry.beforeName);
            await _verifyGone(entry.afterName);
          case AlbumEntryDeletedEntry():
            await _verifyGone(entry.beforeName);
            await _verifyGone(entry.afterName);
          default:
            break;
        }
      }
      for (final content in albumPurged()) {
        await store.appendLogEntry((
          id: idMinter.v7(),
          kind: content.kind.name,
          instantUtcMicros: now.microsecondsSinceEpoch,
          offsetSeconds: now.timeZoneOffset.inSeconds,
          itemId: content.itemId,
          itemOrigin: content.itemOrigin,
          stack: content.stack,
          settingKey: content.settingKey,
          settingValue: content.settingValue,
          settingTextValue: content.settingTextValue,
          pocketMinutes: content.pocketMinutes,
          energyLevel: content.energyLevel,
          reportValue: content.reportValue,
          reportWeek: content.reportWeek,
          permission: content.permission?.name,
          sliceCause: content.sliceCause,
          cluster: content.cluster?.name,
          enabled: content.enabled,
          triageDestination: content.triageDestination?.name,
          triageVolumeTag: content.triageVolumeTag?.name,
          triageBoxId: content.triageBoxId,
          beforeName: content.beforeName,
          afterName: content.afterName,
        ));
      }
    });
  }

  /// The purge's read-back verification: a name any act references
  /// that is still readable after the sweep throws — the honest
  /// failure, before any act lands.
  Future<void> _verifyGone(String name) async {
    if (await files.read(albumFilesScope, name) != null) {
      throw StateError(
        albumBlobSurvivedPurgeTemplate.replaceFirst(albumBlobNameSlot, name),
      );
    }
  }
}

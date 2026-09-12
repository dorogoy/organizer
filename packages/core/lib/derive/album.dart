/// The album's derived read model (Story 7.2, FR-18, AD-13, AD-21):
/// pure folds over the log's album acts, named as facts and writing
/// nothing (AD-3). There is no album table and no manifest record —
/// the album's membership reconstructs from `before_saved`,
/// `album_entry_added`, `album_entry_deleted` and `album_purged`
/// rows alone, and the bytes live in the Files `album` scope under
/// the names those rows carry (AD-1, AD-13).
///
/// Two facts, one pin principle:
///
/// - **Live entries** — `albumEntries` folds the acts in store read
///   order: an add appends, a delete tombstones the matching add, a
///   purge clears everything before it. This is the list 7.3's
///   gallery renders.
/// - **Pinned names** — `albumPinnedNames` answers the one question
///   every unlink routes through: which blob names does an effective
///   act still claim? A `before_saved` is dead once any later
///   `album_purged` exists; an `album_entry_added` is dead once a
///   later `album_entry_deleted` naming the same group AND the same
///   before/after pair, or any later `album_purged`, exists — the
///   match is group-scoped because FR-18 deletes entries
///   individually, and a byte-identical pair in another group is
///   that group's own transformation, never this deletion's target. An entry's before blob stays
///   pinned by its own `before_saved` — the deliberate shot for the
///   space (FR-25) — so deletion unlinks the after blob unless
///   another live entry shares its name. This is deliberately the
///   ONLY unlink oracle: when Epic 9's export generations land, their
///   manifests join this fold as claimants and no other code changes
///   shape.

library;

import 'package:core/log/log_entry.dart';
import 'package:core/pool/pool_fact.dart';

/// One live album entry (Story 7.2): the group pair and both blob
/// names of an `album_entry_added` act no later delete or purge has
/// killed, plus the act's own instant and civil-day offset — the fact
/// 7.3's surface renders and hands back to
/// `AlbumController.deleteEntry`. Keeping the offset beside the live
/// entry preserves the add row's identity when two entries share a
/// group and instant.
typedef AlbumEntry = ({
  String groupId,
  Origin origin,
  String beforeName,
  String afterName,
  int addedUtcMicros,
  int offsetSeconds,
});

/// The album's live entries, in log order (Story 7.2, FR-18): an
/// `album_entry_added` act appends the entry it names; a later
/// `album_entry_deleted` naming the same group and the same
/// before/after pair tombstones exactly the act the surface named
/// (a delete of an already-dead entry no-ops, and a byte-identical
/// pair in another group stays live — FR-18 deletes entries
/// individually); an `album_purged`
/// clears everything before it, so an add after a purge lives. The
/// bytes are not read here — content addressing makes the names the
/// whole identity.
// ponytail: O(log) per query with no index, and the delete match is a
// linear scan per act — fine at album scale, revisit only if a profile
// says otherwise.
List<AlbumEntry> albumEntries(List<LogEntry> log) {
  final live = <AlbumEntry>[];
  for (final entry in log) {
    switch (entry) {
      case AlbumEntryAddedEntry():
        live.add((
          groupId: entry.itemId,
          origin: entry.itemOrigin,
          beforeName: entry.beforeName,
          afterName: entry.afterName,
          addedUtcMicros: entry.instantUtcMicros,
          offsetSeconds: entry.offsetSeconds,
        ));
      case AlbumEntryDeletedEntry():
        live.removeWhere(
          (liveEntry) =>
              liveEntry.groupId == entry.itemId &&
              liveEntry.origin == entry.itemOrigin &&
              liveEntry.beforeName == entry.beforeName &&
              liveEntry.afterName == entry.afterName,
        );
      case AlbumPurgedEntry():
        live.clear();
      default:
        break;
    }
  }
  return live;
}

/// The blob names an effective act still claims (Story 7.2, FR-18,
/// AD-13): the pin fold, stated once — a `before_saved` claims its
/// Before name until any later `album_purged`; an
/// `album_entry_added` claims both its names until a later
/// `album_entry_deleted` naming the same group and the same
/// before/after pair, or any later `album_purged`, exists — the
/// match group-scoped, exactly as the live fold's tombstone is
/// (one rule, no second definition). A `album_entry_deleted` row
/// claims nothing
/// — it is the killer, never a claimant. Every unlink decision
/// routes through this fold: a name outside the answer is bytes no
/// act can surface, and a name inside it is somebody's photo.
Set<String> albumPinnedNames(List<LogEntry> log) {
  // Pass one — the killers and their positions: a delete kills only
  // the adds before it that name the same group and the same pair
  // (a re-saved pair after a delete lives, and another group's
  // byte-identical pair is never the target), and a
  // purge kills every photo claim before it while claiming nothing
  // itself.
  final deletes =
      <
        ({
          int index,
          String itemId,
          Origin origin,
          String beforeName,
          String afterName,
        })
      >[];
  var lastPurgeIndex = -1;
  for (var i = 0; i < log.length; i++) {
    final entry = log[i];
    switch (entry) {
      case AlbumEntryDeletedEntry():
        deletes.add((
          index: i,
          itemId: entry.itemId,
          origin: entry.itemOrigin,
          beforeName: entry.beforeName,
          afterName: entry.afterName,
        ));
      case AlbumPurgedEntry():
        lastPurgeIndex = i;
      default:
        break;
    }
  }
  // Pass two — the claims: an act is effective exactly when no
  // killer stands after it.
  final pinned = <String>{};
  for (var i = 0; i < log.length; i++) {
    if (i <= lastPurgeIndex) {
      continue;
    }
    final entry = log[i];
    switch (entry) {
      case BeforeSavedEntry():
        pinned.add(entry.blobName);
      case AlbumEntryAddedEntry():
        final killed = deletes.any(
          (delete) =>
              delete.index > i &&
              delete.itemId == entry.itemId &&
              delete.origin == entry.itemOrigin &&
              delete.beforeName == entry.beforeName &&
              delete.afterName == entry.afterName,
        );
        if (!killed) {
          pinned
            ..add(entry.beforeName)
            ..add(entry.afterName);
        }
      default:
        break;
    }
  }
  return pinned;
}

/// The blob names the deletion of the entry carrying [beforeName]/
/// [afterName] for [groupId] unlinks once its act lands (Story 7.2,
/// FR-18): the pin fold over the log with the pending delete act
/// synthesized onto it — `_answered`'s own synthesis pattern, so the
/// synthesized row's [groupId]/[origin] participate in the kill
/// match and the entry's own claim dies while every other live
/// claim stands (another group's byte-identical pair included). No
/// derivation reads the synthesized act's id, and the caller's own
/// [instantUtcMicros]/[offsetSeconds] ride it so the fold's input is
/// the log as it will stand; the names in the answer are exactly the
/// bytes no effective act can surface. The deletion's own minter
/// still lands the real act — this fold only decides the unlink.
Set<String> albumUnlinkedByDelete(
  List<LogEntry> log, {
  required String groupId,
  required Origin origin,
  required String beforeName,
  required String afterName,
  required int instantUtcMicros,
  required int offsetSeconds,
}) {
  final pinned = albumPinnedNames([
    ...log,
    AlbumEntryDeletedEntry(
      id: '',
      instantUtcMicros: instantUtcMicros,
      offsetSeconds: offsetSeconds,
      itemId: groupId,
      itemOrigin: origin,
      beforeName: beforeName,
      afterName: afterName,
    ),
  ]);
  return {beforeName, afterName}.difference(pinned);
}

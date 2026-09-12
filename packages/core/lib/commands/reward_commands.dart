/// The reward commands (Stories 7.1/7.2, FR-17, FR-18, AD-13,
/// AD-21): pure functions that compute *what* to append — never ids,
/// instants or offsets, which the shell mints at the commit of each
/// act. `beforeSaved`, `albumEntryAdded`, `albumEntryDeleted` and
/// `albumPurged` are their kinds' single
/// sanctioned minters, so no second album-mutation writer can appear
/// silently: album membership is log acts (AD-21), each row naming
/// the scan group's stable id — the same id the group's
/// `epic_activated` row names — and the album blob's
/// content-addressed name (AD-13). The bytes themselves never touch
/// the log: they live in the Files `album` scope, and the reward
/// photos never upload (no face gate, no consent, no egress seam).
///
/// There is no shape here to reach: the shell completes each row —
/// minting the UUIDv7 id, the instant and the offset in force —
/// before the port sees it, and the append rides the shared
/// `LogWriteQueue` like every other write the shell owns.

library;

import 'package:core/commands/session_commands.dart';
import 'package:core/log/log_entry.dart';
import 'package:core/pool/pool_fact.dart';

/// `before_saved` — exactly one content row, the kind's single
/// sanctioned minter (Story 7.1, FR-17, FR-25, AD-13, AD-21): the
/// deliberate Before shot a delivered scan's offer took, naming the
/// group's stable id and own origin on the existing item-act shape
/// (AD-14) plus the album blob's content-addressed name on the row's
/// own v14 column. A declined offer writes nothing — the space
/// derives as a no-Before space by absence, never by a row that
/// asserts one.
List<LogEntryContent> beforeSaved({
  required String groupId,
  required Origin origin,
  required String blobName,
}) {
  return [
    (
      kind: LogKind.beforeSaved,
      itemId: groupId,
      itemOrigin: origin,
      stack: null,
      settingKey: null,
      settingValue: null,
      settingTextValue: null,
      pocketMinutes: null,
      energyLevel: null,
      reportValue: null,
      reportWeek: null,
      permission: null,
      sliceCause: null,
      cluster: null,
      enabled: null,
      triageDestination: null,
      triageVolumeTag: null,
      triageBoxId: null,
      beforeName: blobName,
      afterName: null,
    ),
  ];
}

/// `album_entry_added` — exactly one content row, the kind's single
/// sanctioned minter (Story 7.1, FR-17, AD-13, AD-21): the saved
/// Before/After pair, appended automatically the moment the reward's
/// After shot lands — never a share button, never a manual save. The
/// row names the same group id and origin the `before_saved` row
/// named, plus BOTH blob names on the row's own v14 columns: the
/// album's membership reconstructs from these rows alone (AD-1), and
/// Epic 9's export derives from them. A reward closed before the
/// After shot writes nothing (zero side effects).
List<LogEntryContent> albumEntryAdded({
  required String groupId,
  required Origin origin,
  required String beforeName,
  required String afterName,
}) {
  return [
    (
      kind: LogKind.albumEntryAdded,
      itemId: groupId,
      itemOrigin: origin,
      stack: null,
      settingKey: null,
      settingValue: null,
      settingTextValue: null,
      pocketMinutes: null,
      energyLevel: null,
      reportValue: null,
      reportWeek: null,
      permission: null,
      sliceCause: null,
      cluster: null,
      enabled: null,
      triageDestination: null,
      triageVolumeTag: null,
      triageBoxId: null,
      beforeName: beforeName,
      afterName: afterName,
    ),
  ];
}

/// `album_entry_deleted` — exactly one content row, the kind's single
/// sanctioned minter (Story 7.2, FR-18, AD-13, AD-21): one album
/// entry left the album, the row mirroring the entry's
/// `album_entry_added` field for field — the same group pair plus
/// BOTH blob names — so the read model's fold tombstones exactly the
/// act the surface named. The names ride the row for the audit trail
/// alone: the deletion's unlink decision routes through the pin fold
/// (`core/derive/album.dart`), never through this row's presence. A
/// double invocation mints a second row and the fold no-ops — the
/// quiet idempotence the delete owes its retry.
List<LogEntryContent> albumEntryDeleted({
  required String groupId,
  required Origin origin,
  required String beforeName,
  required String afterName,
}) {
  return [
    (
      kind: LogKind.albumEntryDeleted,
      itemId: groupId,
      itemOrigin: origin,
      stack: null,
      settingKey: null,
      settingValue: null,
      settingTextValue: null,
      pocketMinutes: null,
      energyLevel: null,
      reportValue: null,
      reportWeek: null,
      permission: null,
      sliceCause: null,
      cluster: null,
      enabled: null,
      triageDestination: null,
      triageVolumeTag: null,
      triageBoxId: null,
      beforeName: beforeName,
      afterName: afterName,
    ),
  ];
}

/// `album_purged` — exactly one content row, the kind's single
/// sanctioned minter (Story 7.2, FR-18, AD-4, AD-21): the album was
/// purged, one payload-less row whose whole claim is its position in
/// the log — every earlier photo claim dies before it. The sweep
/// itself is the Files port's blind `sweepAlbum` (no listing — the
/// port's own ban), and the user fact is one row, never N per-entry
/// deletes: per-entry deletes would leave orphaned Before blobs'
/// claims live while their bytes are swept — drift.
List<LogEntryContent> albumPurged() {
  return [
    (
      kind: LogKind.albumPurged,
      itemId: null,
      itemOrigin: null,
      stack: null,
      settingKey: null,
      settingValue: null,
      settingTextValue: null,
      pocketMinutes: null,
      energyLevel: null,
      reportValue: null,
      reportWeek: null,
      permission: null,
      sliceCause: null,
      cluster: null,
      enabled: null,
      triageDestination: null,
      triageVolumeTag: null,
      triageBoxId: null,
      beforeName: null,
      afterName: null,
    ),
  ];
}

// The reward channel's shell half (Story 7.1, FR-17): the milestone
// reward's own controller — the Before lookup, the Cámara entry rule,
// and the pair flow's one write. The two milestone derivations live
// in the core (`core/derive/reward.dart`); the hooks that fire them
// live in the Dispenser and session controllers; this controller owns
// what the pushed surface needs: reading the space's Before name and
// the shoot rule once, then the shoot's commit half — one
// content-addressed album write, one `album_entry_added` row through
// the kind's single sanctioned minter naming the group and BOTH blobs
// — automatically, in the same flow (AD-21). The open, the framing
// and the denial's own row belong to the shared shoot pipeline
// (`PhotoShootScreen`), which reaches this controller's camera and
// seams through the surface. No face gate, no consent, no egress: the
// photos never upload.
//
// The flow's honest failures fold to the same quiet answer as the
// no-Before arm: a denied or failed open, a lost grant at the
// shutter, a failed write or append all degrade to `Un trabajo
// estupendo` with nothing written — no error dead-end, no retry loop
// (FR-29's calm register, the scan channel's own discipline).
import 'package:core/commands/permission_commands.dart';
import 'package:core/commands/reward_commands.dart';
import 'package:core/commands/session_commands.dart';
import 'package:core/derive/camera_entry.dart';
import 'package:core/derive/reward.dart';
import 'package:core/log/log_entry.dart';
import 'package:core/ports/files_port.dart';
import 'package:core/ports/store_port.dart';
import 'package:uuid/uuid.dart';

import '../files/app_files.dart';
import '../plugins/camera/camera_shell.dart';
import '../session/log_write_queue.dart';

/// The reward read's two facts (Story 7.1): the space's persisted
/// Before blob name — null when none stands, the declined,
/// camera-blocked and typed-genesis cases alike — and whether the
/// Cámara entry rule admits a shoot action (UX-DR24: absent never
/// greyed).
final class RewardRead {
  const RewardRead({required this.beforeName, required this.cameraAllowed});

  final String? beforeName;
  final bool cameraAllowed;
}

/// The reward channel's shell half (Story 7.1, FR-17): see the
/// library comment. The injectables follow `ScanController`'s — the
/// shell may read the clock and mint ids, the core never does.
class RewardController {
  RewardController({
    required this.store,
    required this.files,
    required this.camera,
    LogWriteQueue? writeQueue,
    this.idMinter = const Uuid(),
    this.nowOf = DateTime.now,
  }) : writeQueue = writeQueue ?? LogWriteQueue();

  final StorePort store;
  final FilesPort files;

  /// The camera facade the shared shoot pipeline's viewfinder opens —
  /// held here so the pushed surface hands the pushing flow the same
  /// facade the whole shell composes at the root.
  final CameraShell camera;

  final LogWriteQueue writeQueue;
  final Uuid idMinter;
  final DateTime Function() nowOf;

  /// Reads the reward's two facts over one queue-consistent log: the
  /// space's Before name (`spaceBeforeName`, the latest naming row
  /// wins) and the Cámara entry rule's fold. A failing read answers
  /// the no-Before, no-shoot presentation — the honest nothing, never
  /// an error surface.
  Future<RewardRead> read(NamedRewardSpace space) async {
    try {
      final log = logEntriesOf(await store.readLogEntries());
      return RewardRead(
        beforeName: spaceBeforeName(log, space.groupId),
        cameraAllowed: cameraEntryVisible(log),
      );
    } on Object {
      return const RewardRead(beforeName: null, cameraAllowed: false);
    }
  }

  /// Appends exactly one `permission_refused{camera}` row through the
  /// core's single sanctioned minter — the scan channel's own shape,
  /// minted on the reward's own explicit camera attempt (AD-17: the
  /// ask happens at the attempt, and a refusal retires the entry).
  /// Public since the viewfinder patch: the shared shoot pipeline
  /// (`PhotoShootScreen`) appends the denial's row through this seam.
  Future<void> appendCameraRefusal() {
    final now = nowOf();
    return writeQueue.enqueue(() async {
      for (final content in permissionRefuse(Permission.camera)) {
        await _appendContent(content, now);
      }
    });
  }

  /// The reward's shoot-After commit (Story 7.1, FR-17, AD-13,
  /// AD-21): the shared shoot pipeline's controller half — the
  /// viewfinder's captured bytes become one content-addressed album
  /// blob and exactly one `album_entry_added` row naming [space]'s
  /// group and BOTH blob names, appended automatically in the same
  /// flow. Answers the After blob's name, or null when the write or
  /// append failed — the no-photo presentation, nothing written.
  Future<String?> saveAfterBlob(
    List<int> bytes, {
    required NamedRewardSpace space,
    required String beforeName,
  }) async {
    final afterName = albumPhotoName(bytes);
    // Keep the content-addressed read/write, the authoritative log append
    // and a possible rollback under the shell's one queue. A second flow for
    // the same hash cannot commit a row between this flow's failed append
    // and its cleanup, which would otherwise leave that committed row naming
    // a deleted blob.
    return writeQueue.enqueue(() async {
      var createdHere = false;
      try {
        // A content-addressed write may be reusing a photo already named by a
        // prior act. Only a blob this attempt created is eligible for rollback
        // if the following append fails; deleting an existing blob would break
        // that earlier album entry.
        final existed = await files.read(albumFilesScope, afterName) != null;
        await writeAlbumPhoto(files, bytes);
        createdHere = !existed;
        final now = nowOf();
        for (final content in albumEntryAdded(
          groupId: space.groupId,
          origin: space.origin,
          beforeName: beforeName,
          afterName: afterName,
        )) {
          await _appendContent(content, now);
        }
        return afterName;
      } on Object {
        // The log is the album's authority. A failed append must not strand a
        // newly written private image with no act that can ever surface it.
        if (createdHere) {
          try {
            await files.delete(albumFilesScope, afterName);
          } on Object {
            // The original failure is already the user-visible outcome;
            // cleanup is best effort because Files has no transaction with
            // Store.
          }
        }
        // Quiet by contract: the pair's whole exposure is one blob and
        // one row, and any failure leaves the honest nothing standing.
        return null;
      }
    });
  }

  /// Appends one minted content row — the write path's shared copier,
  /// the scan channel's own idiom: one minted instant per act (the
  /// caller's [now]), a v7 id per row, the offset in force at the
  /// mint, every content field copied verbatim.
  Future<void> _appendContent(LogEntryContent content, DateTime now) async {
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
}

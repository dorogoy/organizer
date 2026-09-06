import 'package:core/commands/permission_commands.dart';
import 'package:core/commands/scan_commands.dart';
import 'package:core/commands/session_commands.dart';
import 'package:core/log/log_entry.dart';
import 'package:core/ports/face_gate_port.dart';
import 'package:core/ports/files_port.dart';
import 'package:core/ports/store_port.dart';
import 'package:uuid/uuid.dart';

import '../plugins/camera/camera_shell.dart';
import '../session/log_write_queue.dart';

/// One shoot's terminal outcome (Story 5.2, FR-25): the surface's
/// navigation fact, decided after the gate has run and the scan's
/// directory is already unlinked. Sealed so no third state — no
/// pending, no queued, no retrying — exists as a type.
sealed class ScanShootOutcome {
  const ScanShootOutcome();
}

/// The gate refused the frame (a person in it): the row is appended,
/// the frame is unlinked, and the surface owes the one calm surface
/// whose copy offers the reframe (`NoSlicerSurface`, cause
/// `personInFrame`) — the refusal is about the frame, never about the
/// user, and the way on is retapping Cámara: same tap count.
final class ScanShootRefused extends ScanShootOutcome {
  const ScanShootRefused();
}

/// The scan ended quietly — the gate passed (the chain continues in
/// 5.5), or a failure folded closed (a missed shot, a detector error
/// past its retry, no gate behind the test seam): no row, nothing
/// surfaced, the surface simply closes.
final class ScanShootClosed extends ScanShootOutcome {
  const ScanShootClosed();
}

/// The shutter found a system problem (a lost grant at the shot):
/// no row — a malfunction is not a refusal — and the surface owes
/// the honest notice (`scanOpenFailed`), never a quiet pop that
/// would read as a taken photo.
final class ScanShootFailed extends ScanShootOutcome {
  const ScanShootFailed();
}

/// The scan flow's shell half (Story 5.2, FR-16, FR-25, AD-17; ruling
/// 1-B): the
/// Cámara entry's one surface, driven end to end — open (the first-use
/// permission moment, its two domains kept apart), shoot (write the
/// frame to the scan's own cache subdirectory), gate, branch — on the
/// capture controller's own
/// division of labour: the core decides content
/// (`permissionRefuse`: the `permission_refused` row a camera denial
/// appends — the denial alone; an interrupted ask or a failed open
/// mints nothing, the ruling's functioning-problem domain), and
/// `faceRefused`: the `face_refused` row a face refusal
/// appends; this shell mints ids, instants and the scan's own
/// cache directory, holding no state beyond the standing scan.
///
/// Every terminal path unlinks the scan's directory — refusal, gate
/// pass, surface exit, permission failure, detector failure, surface
/// disposal — so no frame lingers (5.4's sweep does not exist yet;
/// this story's own hygiene is the whole backstop). The terminal
/// paths are epoch-guarded as well: a shoot or an ask resolving
/// after [close] may create nothing and initialize nothing — the
/// close-epoch check turns a late landing into a quiet stale answer.
/// Writes ride the shared `LogWriteQueue`, one substrate under the
/// whole shell, and are quiet about their own failure exactly as the
/// dictation seam's are.
///
/// The controller is binding-free, like its capture sibling: the
/// preview widget belongs to the surface, built against the
/// [camera] facade seam it can reach through this controller.
///
/// The [gate] seam is optional on the composition-root convention:
/// absent (the test seam), a shot folds closed quietly — nothing
/// half-wired proceeds past a missing gate, and no `face_refused` row
/// exists to mint.
class ScanController {
  ScanController({
    required this.store,
    required this.files,
    required this.camera,
    this.gate,
    LogWriteQueue? writeQueue,
    this.idMinter = const Uuid(),
    this.nowOf = DateTime.now,
  }) : writeQueue = writeQueue ?? LogWriteQueue();

  final StorePort store;
  final FilesPort files;
  final CameraShell camera;

  /// The face gate seam (Story 5.2, FR-25): main composes it through
  /// the ML Kit adapter. Absent (the test seam), the shoot path fails
  /// closed — the honest nothing, never a half-scanned frame.
  final FaceGatePort? gate;
  final LogWriteQueue writeQueue;
  final Uuid idMinter;
  final DateTime Function() nowOf;

  /// The standing scan's own cache segment — minted at open, unlinked
  /// at every terminal path. Null when no scan stands.
  String? _scanId;

  /// The shoot's in-flight guard: one shutter tap owns the surface
  /// until its flow settles, so a rapid second tap is nothing at all —
  /// no second frame, no second row, no stale branch.
  bool _shooting = false;

  /// The open's in-flight guard: one open owns the permission moment.
  bool _opening = false;

  /// Whether a granted open stands (the camera half may run).
  bool _open = false;

  /// The close epoch: bumped by every [close], so an ask or a shoot
  /// resolving after a terminal close can see its own staleness — a
  /// late `granted` initializes nothing, a late frame creates
  /// nothing, and the captured scan identity unlinks whatever it had
  /// already made.
  int _epoch = 0;

  /// Opens the scan (FR-16, AD-17; ruling 1-B): the first-use
  /// permission moment — the facade (through the `camera` channel)
  /// asks CAMERA here, at the explicit scan attempt, never at app
  /// entry. The ruling's two domains split the answers: a **denied**
  /// open appends exactly one `permission_refused{camera}` row
  /// through the core minter and closes the camera — the surface pops
  /// and the entry is absent on the next render. An **interrupted**
  /// ask (the system swallowed it — no answer existed) and an
  /// **unavailable** open (no hardware, a device error — the facade's
  /// own outcome; no pre-check duplicates the platform round-trip)
  /// are functioning problems, never refusals: nothing is appended,
  /// the entry stays, and the outcome is the surface's to
  /// communicate — the caller stays and states the problem, with the
  /// OS back the way out.
  Future<CameraOpenOutcome> open() async {
    if (_opening) {
      // A second concurrent open owns no answer of its own; the
      // single-open surface makes this unreachable, and the
      // interruption is the honest nothing for any other caller.
      return CameraOpenOutcome.interrupted;
    }
    _opening = true;
    final epoch = _epoch;
    try {
      // A fresh scan: unlink whatever still stands under the previous
      // identity (a resume must not mint over an unreleased segment),
      // then a new cache segment.
      await _unlinkScan();
      _scanId = idMinter.v7();
      final outcome = await camera.open();
      if (_epoch != epoch && outcome == CameraOpenOutcome.granted) {
        // The surface left while the ask stood (the staged permission
        // moment — the system dialog's own inactive never releases
        // here, but a back-out does): a late granted answer must not
        // leave a camera standing behind a closed scan. The refusal
        // stays durable when the answer was a denial — the row is the
        // user's act, not the surface's — but a late grant owns
        // nothing: dispose, and the interruption answers.
        await camera.dispose();
        return CameraOpenOutcome.interrupted;
      }
      switch (outcome) {
        case CameraOpenOutcome.granted:
          _open = true;
          return outcome;
        case CameraOpenOutcome.denied:
          await _appendPermissionRefusal();
          await close();
          return outcome;
        case CameraOpenOutcome.interrupted:
        case CameraOpenOutcome.unavailable:
          // System problems, communicated and never recorded: the
          // camera half is torn down (nothing stands behind the
          // notice), the scan's directory unlinks, and the outcome
          // travels to the surface untouched.
          await close();
          return outcome;
      }
    } finally {
      _opening = false;
    }
  }

  /// The shutter tap (FR-25): shoot → write the frame to the scan's
  /// own cache subdirectory **before** the gate runs → gate → branch.
  /// A refusal appends one `face_refused` row, unlinks the frame and
  /// answers [ScanShootRefused] — the surface pushes the calm surface
  /// whose copy offers the reframe. A pass closes quietly with the
  /// frame unlinked (the chain continues in 5.5). A detector error
  /// past its retry folds closed with **no** row — a failure is not a
  /// refusal, and the log must not claim a privacy decision that was
  /// not made — and a failed shot or a missing gate seam takes the
  /// same quiet fail-closed path.
  ///
  /// The whole flow is epoch-guarded against the surface's exit: a
  /// [close] landing mid-shot makes every later step stale — no frame
  /// is written after the terminal unlink (nothing recreates the
  /// directory), and whatever the shot had already written is unlinked
  /// again through the captured scan identity, so no orphan outlives
  /// the close.
  Future<ScanShootOutcome> shoot() async {
    if (_shooting || !_open) {
      return const ScanShootClosed();
    }
    _shooting = true;
    try {
      final scanId = _scanId;
      final epoch = _epoch;
      if (scanId == null) {
        return const ScanShootClosed();
      }
      final shot = await camera.takePicture();
      switch (shot) {
        case CameraShotNone():
          await _unlinkCaptured(scanId);
          return const ScanShootClosed();
        case CameraShotAccessLost():
          // A grant gone at the shutter is a system problem, never a
          // user refusal and never a quiet close that reads as a
          // taken photo: unlink the frame and let the surface drop
          // the preview, then close (dispose-under-preview is a
          // crash). No row.
          await _unlinkCaptured(scanId);
          return const ScanShootFailed();
        case CameraShotCaptured(:final bytes):
          if (_epoch != epoch) {
            // The scan ended while the shot stood: the bytes die here —
            // writing them would recreate the directory the close already
            // unlinked.
            return const ScanShootClosed();
          }
          // The frame is written before the gate runs — the gate reads
          // the written cache file through the measured `fromFilePath`
          // seam, and nothing upstream of that file ever exists.
          final framePath = await files.writeScanFrame(scanId, bytes);
          if (_epoch != epoch) {
            // The close landed inside the write itself: the directory it
            // recreated dies with this scan's captured identity.
            await _unlinkCaptured(scanId);
            return const ScanShootClosed();
          }
          final gate = this.gate;
          if (framePath.isEmpty || gate == null) {
            await _unlinkCaptured(scanId);
            return const ScanShootClosed();
          }
          FaceGateOutcome verdict;
          try {
            verdict = await gate.gate(framePath);
          } on Object {
            // Fail closed, never falsely refused: the frame is unlinked,
            // nothing proceeds, no row lands.
            await _unlinkCaptured(scanId);
            return const ScanShootClosed();
          }
          // The captured identity's own unlink — idempotent beside
          // whatever a concurrent close already took, so the frame never
          // outlives this scan whichever path won the race.
          await _unlinkCaptured(scanId);
          if (_epoch != epoch) {
            // The surface left while the gate ran: a late refusal must
            // not mint a privacy row or navigate after the user has
            // gone. The frame is already unlinked.
            return const ScanShootClosed();
          }
          if (verdict is FaceGateRefusal) {
            await _appendFaceRefused();
            return const ScanShootRefused();
          }
          return const ScanShootClosed();
      }
    } finally {
      _shooting = false;
    }
  }

  /// The terminal close: unlinks the scan's directory (idempotent —
  /// the shoot paths already unlinked their own) and disposes the
  /// camera. The surface's every exit path — the system back, a
  /// refused open, a quiet close, disposal, a backgrounding release —
  /// ends here; no frame outlives its scan, and the bumped epoch
  /// retires every in-flight landing.
  Future<void> close() async {
    _epoch++;
    _open = false;
    await _unlinkScan();
    await camera.dispose();
  }

  Future<void> _unlinkScan() async {
    final scanId = _scanId;
    if (scanId == null) {
      return;
    }
    _scanId = null;
    await _unlinkCaptured(scanId);
  }

  /// Unlinks one captured scan identity — the shoot paths' own
  /// unlink, valid however the scan ended: the port's delete is
  /// idempotent, so a close that already took the directory makes
  /// this a quiet no-op and a close that lands later still finds
  /// nothing of this scan standing.
  Future<void> _unlinkCaptured(String scanId) async {
    try {
      await files.unlinkScan(scanId);
    } on Object {
      // Quiet: the port's own contract absorbs the refusal, and the
      // idempotent segment-clearing keeps the next scan clean
      // whatever a failed unlink left standing.
    }
  }

  /// Appends one minted content row — the write paths' shared copier,
  /// the capture controller's own idiom: one minted instant per
  /// refusal (the caller's [now]), a v7 id per row, the offset in
  /// force at the mint, every content field copied verbatim.
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
    ));
  }

  /// Appends exactly one `permission_refused` {camera} row through
  /// the core's single sanctioned minter — the dictation seam's own
  /// shape: the instant minted at entry, before any await, a v7 id per
  /// row, the shared `LogWriteQueue` serializing the append against
  /// every other write the shell owns. A failing store is absorbed
  /// quietly — the queue recovers and nothing surfaces.
  Future<void> _appendPermissionRefusal() {
    final now = nowOf();
    return writeQueue
        .enqueue(() async {
          for (final content in permissionRefuse(Permission.camera)) {
            await _appendContent(content, now);
          }
        })
        .catchError((Object _) {});
  }

  /// Appends exactly one `face_refused` row through the core's single
  /// sanctioned minter, on the same shape as the permission refusal:
  /// the instant minted at entry, a v7 id, the shared queue, and a
  /// quiet absorption of a failing store.
  Future<void> _appendFaceRefused() {
    final now = nowOf();
    return writeQueue
        .enqueue(() async {
          for (final content in faceRefused()) {
            await _appendContent(content, now);
          }
        })
        .catchError((Object _) {});
  }
}

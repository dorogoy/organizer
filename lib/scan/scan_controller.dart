import 'dart:async';
import 'dart:typed_data';

import 'package:core/commands/permission_commands.dart';
import 'package:core/commands/scan_commands.dart';
import 'package:core/commands/session_commands.dart';
import 'package:core/log/log_entry.dart';
import 'package:core/ports/face_gate_port.dart';
import 'package:core/ports/files_port.dart';
import 'package:core/ports/scan_consent.dart';
import 'package:core/ports/slicer_port.dart';
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

/// The scan ended quietly — a failure folded closed (a missed shot, a
/// detector error past its retry, no gate behind the test seam): no
/// row, nothing surfaced, the surface simply closes. The gate pass is
/// no longer this arm — it carries the consent continuation (Story
/// 5.5).
final class ScanShootClosed extends ScanShootOutcome {
  const ScanShootClosed();
}

/// The gate passed and consent is owed (Story 5.5, FR-25): the frame
/// survived — gate-pass stopped being a terminal path, and the scan's
/// directory stands until the consent act resolves. The arm carries
/// the standing scan's identity — the surface's navigation fact; the
/// frame's bytes stay with the standing scan itself (the consent
/// phase reads them from the controller), never duplicated onto the
/// arm. The surface owes the consent gate; nothing here routes past
/// it.
final class ScanShootGatePassed extends ScanShootOutcome {
  const ScanShootGatePassed({required this.scanId});

  /// The standing scan's identity — the consent token's binding and
  /// the consent phase's unlink key.
  final String scanId;
}

/// The shutter found a system problem (a lost grant at the shot):
/// no row — a malfunction is not a refusal — and the surface owes
/// the honest notice (`scanOpenFailed`), never a quiet pop that
/// would read as a taken photo.
final class ScanShootFailed extends ScanShootOutcome {
  const ScanShootFailed();
}

/// The consent act's terminal answer (Story 5.5): sealed so no queued,
/// pending or retrying state exists as a type — one decision, one
/// dispatch, one resolution.
sealed class ScanConsentOutcome {
  const ScanConsentOutcome();
}

/// The slice was delivered (interim by decision of 2026-09-06, P2-A):
/// nothing lands and no row stands — the landing is 5.7's, and the
/// caller closes the scan quietly to the Dispenser. The dispatch
/// wiring above this arm — mint order, token, cap-in-binding, failure
/// mapping — is permanent.
final class ScanConsentDelivered extends ScanConsentOutcome {
  const ScanConsentDelivered();
}

/// The slice failed terminally with one of the closed eight causes:
/// the caller routes the standing `noSlicerCauseFromFailure` map, the
/// 4-5 mapping unchanged.
final class ScanConsentFailed extends ScanConsentOutcome {
  const ScanConsentFailed(this.cause);

  /// The port's failure cause.
  final SlicerFailureCause cause;
}

/// A stale answer (5.2's epoch discipline): the scan closed while the
/// dispatch stood — no routing, nothing recreated, and the cache was
/// already unlinked by the close itself.
final class ScanConsentStale extends ScanConsentOutcome {
  const ScanConsentStale();
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
/// Every real resolution unlinks the scan's directory — refusal,
/// declined consent, pre-gate no-provider refusal, gate exit (system
/// back), provider failure, delivered-interim discard, epoch-stale
/// late landing, the wait's abandonment (`scan_abandoned`, Story
/// 5.6), surface exit, permission failure, detector failure,
/// surface disposal — so no frame lingers past its scan (the 5.4
/// sweep stays the crash backstop; the gate pass itself is not a
/// resolution: the frame survives it for the consent act). The
/// terminal paths are epoch-guarded as well: a shoot, an ask or a
/// dispatch resolving after [close] may create nothing and
/// initialize nothing — the close-epoch check turns a late landing
/// into a quiet stale answer. Writes ride the shared `LogWriteQueue`,
/// one substrate under the whole shell, and are quiet about their own
/// failure exactly as the dictation seam's are.
///
/// The controller is binding-free, like its capture sibling: the
/// preview widget belongs to the surface, built against the
/// [camera] facade seam it can reach through this controller.
///
/// The [gate] seam is optional on the composition-root convention:
/// absent (the test seam), a shot folds closed quietly — nothing
/// half-wired proceeds past a missing gate, and no `face_refused` row
/// exists to mint. The [slicer] and [readSelectedProvider] seams copy
/// the same convention for the consent phase (Story 5.5): absent, the
/// accept or the gate-pass arm folds closed — nothing half-wired
/// dispatches.
class ScanController {
  ScanController({
    required this.store,
    required this.files,
    required this.camera,
    this.gate,
    this.slicer,
    this.readSelectedProvider,
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

  /// The Slicer seam (Story 5.5, AD-9): main threads the one
  /// production port it already built — the same instance the
  /// Dispenser's rescue path holds. Absent (the test seam), the accept
  /// folds closed — nothing half-wired dispatches, and no token is
  /// minted (the [gate] seam's own rule).
  final SlicerPort? slicer;

  /// The selected-provider read (Story 5.5, AD-22): the pre-gate
  /// availability read, resolved from the log — null when none stands.
  /// The gate never renders for a request that cannot be made. Absent
  /// (the test seam), the gate-pass arm folds closed quietly.
  final Future<String?> Function()? readSelectedProvider;

  final LogWriteQueue writeQueue;
  final Uuid idMinter;
  final DateTime Function() nowOf;

  /// The standing scan's own cache segment — minted at open, unlinked
  /// at every terminal path. Null when no scan stands.
  String? _scanId;

  /// The gate-passed frame's bytes (Story 5.5) — the standing scan's
  /// dispatch payload, held from the shutter until the consent act
  /// resolves. Null whenever no scan stands or the scan resolved.
  Uint8List? _frameBytes;

  /// The consent act's once-guard (Story 5.5): one answer exists per
  /// scan, so a rapid second tap on either action is nothing at all —
  /// no second row, no second token (one exists; consumption is once).
  bool _consentTaken = false;

  /// Whether a granted consent's dispatch stands (Story 5.6): set
  /// once the grant guards pass — the wait has begun — and cleared on
  /// every [grantConsent] exit and by the [close] that mints it, so
  /// [close] mints exactly one `scan_abandoned` row for a departure
  /// mid-wait and nothing for a post-resolution dispose.
  bool _sliceInFlight = false;

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
      // then a new cache segment — and a fresh consent answer with no
      // frame blob carried over: a stale frame under a fresh scanId
      // would dispatch the previous scan's photo.
      await _unlinkScan();
      _scanId = idMinter.v7();
      _consentTaken = false;
      _frameBytes = null;
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
  /// A refusal appends one `face_refused` row and unlinks the frame,
  /// answering [ScanShootRefused] — the surface pushes the calm surface
  /// whose copy offers the reframe. A pass keeps the frame — directory
  /// and bytes — and answers [ScanShootGatePassed]: the scan stands for
  /// the consent act (Story 5.5), whose phase owns the unlink on every
  /// real resolution. A detector error
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
          if (_epoch != epoch) {
            // The surface left while the gate ran: a late refusal must
            // not mint a privacy row or navigate after the user has
            // gone, and a late pass must not open a consent phase
            // behind a closed scan. The close already unlinked this
            // scan's directory, so the frame outlives nothing.
            return const ScanShootClosed();
          }
          if (verdict is FaceGateRefusal) {
            await _unlinkCaptured(scanId);
            await _appendFaceRefused();
            return const ScanShootRefused();
          }
          // The gate passed: the scan stands for the consent act —
          // the frame survives (directory and bytes), and the consent
          // phase owns the unlink from here, on every real resolution.
          // One typed copy of the shot's bytes — the dispatch port's
          // image half is pinned to Uint8List — held on the standing
          // scan itself, never duplicated onto the arm.
          _frameBytes = Uint8List.fromList(bytes);
          return ScanShootGatePassed(scanId: scanId);
      }
    } finally {
      _shooting = false;
    }
  }

  /// The terminal close: unlinks the scan's directory (idempotent —
  /// the shoot paths already unlinked their own) and disposes the
  /// camera. The surface's every exit path — the system back, a
  /// refused open, a quiet close, disposal, a backgrounding release,
  /// and — since Story 5.5 — the consent gate's own exit (leaving the
  /// gate is not declining: no row, the scan just closes) — ends
  /// here; no frame outlives its scan, and the bumped epoch retires
  /// every in-flight landing, the dispatch's included.
  ///
  /// Since Story 5.6 (FR-16, AD-8, AD-21) a dispatch standing at the
  /// close means the user left the wait — back or background, the
  /// departure is the resolution cause — and exactly one payload-less
  /// `scan_abandoned` row is minted for it through the core's single
  /// sanctioned minter, enqueued before the terminal steps so the
  /// queue's row order keeps the act's own chronology (the grant at
  /// the tap, the abandonment at the departure). The append mirrors
  /// `_appendConsentGranted`, not `_appendConsentDeclined`: no
  /// in-closure epoch re-check, because the close is what makes the
  /// row true. The in-flight flag clears here, so the dispose that
  /// follows a lifecycle release — and every later close — mints
  /// nothing more; leaving before an answer (no dispatch standing)
  /// mints nothing either: leaving before consent is neither
  /// declining nor abandoning.
  Future<void> close() async {
    final Future<void>? abandonment;
    if (_sliceInFlight) {
      _sliceInFlight = false;
      abandonment = _appendScanAbandoned();
    } else {
      abandonment = null;
    }
    _epoch++;
    _open = false;
    await _unlinkScan();
    await camera.dispose();
    await abandonment;
  }

  /// Releases the camera while the standing scan survives (Story
  /// 5.5's review): the consent handoff never shoots again — every
  /// path off the gate ends the scan — so the lens does not stand
  /// open (and the OS privacy indicator does not stay lit) through
  /// the open-ended consent ask, the one surface asking permission
  /// to send a photo. The scan's own terminal paths are untouched:
  /// [close] still runs after this and disposes again, idempotently.
  Future<void> releaseCamera() async {
    _open = false;
    await camera.dispose();
  }

  Future<void> _unlinkScan() async {
    final scanId = _scanId;
    if (scanId == null) {
      return;
    }
    _scanId = null;
    _frameBytes = null;
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

  /// The decline tap (Story 5.5, FR-25, FR-29, AD-21): exactly one
  /// payload-less `consent_declined` row through the kind's single
  /// sanctioned minter, then the scan's cache unlinked — the slicer
  /// seam is never called, and the caller routes the no-Slicer
  /// surface's own `consentDeclined` cause. A decline logs, but is
  /// not contact (AD-21): no derivation may read it as engagement,
  /// and no entry asserts a re-ask. Declining costs exactly the same
  /// taps as accepting: no confirmation, no delay, no second attempt
  /// at the gate within the scan.
  ///
  /// The once-guard makes a second decision nothing at all; a call
  /// after the scan ended (no standing identity) is nothing too. The
  /// close epoch guards the whole act like every late landing: the
  /// row commits only while the scan still stands, so a close landing
  /// mid-decision folds into nothing — leaving is not declining, and
  /// no row claims a privacy decision that was never answered. A
  /// failing store is absorbed quietly.
  ///
  /// Returns whether the decline stood — true when the row committed
  /// and the cache unlinked under the standing scan; false on every
  /// fold (no scan, a second decision, or a close landing
  /// mid-decision). A false answer carries no routing data: the
  /// caller pops, never the decline surface — no surface may claim a
  /// decline whose row does not stand.
  Future<bool> declineConsent() async {
    final scanId = _scanId;
    final epoch = _epoch;
    if (scanId == null || _consentTaken) {
      return false;
    }
    _consentTaken = true;
    await _appendConsentDeclined(epoch);
    if (_epoch != epoch) {
      // The scan closed while the decision stood: the stale arm —
      // no routing data, and the close already unlinked the cache.
      return false;
    }
    await _unlinkCaptured(scanId);
    _frameBytes = null;
    return true;
  }

  /// The accept tap (Story 5.5, AD-8, FR-25): the consent act's whole
  /// chain, in AD-8's order — the single-use `ScanConsent` minted
  /// bound to the standing scanId at the tap (after the face gate,
  /// before the cap; the cap runs inside the dispatch's scan branch),
  /// then one `consent_granted` user-act row, then exactly one
  /// `slice(ScanSliceRequest)` carrying the frame's bytes, the scan
  /// prompt and the in-memory identities, and nothing else — no plan
  /// history, no album contents, no device or location identifier
  /// enters the request (FR-25, NFR4) — and the cache unlinked on
  /// every resolution: delivered (the interim discard, P2-A — the
  /// landing is 5.7's), failed (the raw cause for the standing
  /// `noSlicerCauseFromFailure` map), or the close epoch's stale
  /// answer (no routing; the close already unlinked — and, since
  /// Story 5.6, minted the wait's one `scan_abandoned` row).
  ///
  /// Absent [slicer], or no standing scan, or a second decision —
  /// the answer is [ScanConsentStale]: nothing half-wired dispatches
  /// (the [gate] seam's own rule), and one token exists, consumed
  /// once by the dispatch.
  Future<ScanConsentOutcome> grantConsent() async {
    final scanId = _scanId;
    final bytes = _frameBytes;
    final slicer = this.slicer;
    if (scanId == null || bytes == null || _consentTaken || slicer == null) {
      return const ScanConsentStale();
    }
    _consentTaken = true;
    // The wait has begun (Story 5.6): a dispatch stands from here to
    // the resolution, so a close landing anywhere inside it is the
    // user abandoning the wait. Every exit below clears the flag, so
    // an ordinary post-resolution dispose mints nothing.
    _sliceInFlight = true;
    final epoch = _epoch;
    try {
      // The mint at the tap — AD-8's ordering realized with its first
      // production caller. One token exists.
      final consent = mintScanConsent(scanId: scanId);
      await _appendConsentGranted();
      if (_epoch != epoch) {
        // A close won the race before the dispatch began: cancelled
        // and discarded — the slicer is never called (no egress, no
        // token consumption, nothing queued), the close already
        // minted the wait's scan_abandoned row, and the stale answer
        // routes nothing.
        return const ScanConsentStale();
      }
      final SlicerOutcome outcome;
      try {
        outcome = await slicer.slice(
          ScanSliceRequest(
            imageBytes: bytes,
            prompt: _scanPrompt,
            scanId: scanId,
            consent: consent,
          ),
        );
      } on Object {
        // A throw is a malfunction, never a taxonomy value (the rescue
        // path's own containment, byok's folding precedent): resolve as
        // the provider-unreachable arm, the cache unlinked on this real
        // resolution — unless the close won the race, which is the
        // stale answer below.
        if (_epoch != epoch) {
          return const ScanConsentStale();
        }
        // The dispatch has resolved: a close landing during the tail
        // unlink below mints nothing — the flag clears before the
        // await (the finally clear stays as the early arms' backstop).
        _sliceInFlight = false;
        await _unlinkCaptured(scanId);
        _frameBytes = null;
        return const ScanConsentFailed(SlicerFailureCause.providerUnreachable);
      }
      if (_epoch != epoch) {
        // The scan closed while the dispatch stood: a stale answer —
        // no routing, nothing recreated, the close already unlinked
        // (and its own scan_abandoned row already stands).
        return const ScanConsentStale();
      }
      // Same as the throw arm: the resolution owns the rest, so a
      // close during the tail unlink mints nothing.
      _sliceInFlight = false;
      await _unlinkCaptured(scanId);
      _frameBytes = null;
      return switch (outcome) {
        SlicerDelivered() => const ScanConsentDelivered(),
        SlicerFailed(:final cause) => ScanConsentFailed(cause),
      };
    } finally {
      // A stale grant may finish after close has opened a new scan. Do
      // not clear that newer scan's wait flag from the old dispatch.
      if (_epoch == epoch) {
        _sliceInFlight = false;
      }
    }
  }

  /// Appends exactly one `consent_declined` row through the core's
  /// single sanctioned minter — the refusal rows' own shape: the
  /// instant minted at entry, a v7 id, the shared queue, and a quiet
  /// absorption of a failing store. The close epoch is re-checked at
  /// commit, inside the queue's closure, so a close landing between
  /// the once-guard and the append records nothing.
  Future<void> _appendConsentDeclined(int epoch) {
    final now = nowOf();
    return writeQueue
        .enqueue(() async {
          if (_epoch != epoch) {
            // The scan ended while the decision stood: leaving is not
            // declining — the row would claim a refusal that was
            // never answered.
            return;
          }
          for (final content in consentDeclined()) {
            await _appendContent(content, now);
          }
        })
        .catchError((Object _) {});
  }

  /// Appends exactly one `consent_granted` row through the core's
  /// single sanctioned minter — instrumentation only, carrying no
  /// capability; the token itself never touches the log. The same
  /// shape as every row writer above.
  Future<void> _appendConsentGranted() {
    final now = nowOf();
    return writeQueue
        .enqueue(() async {
          for (final content in consentGranted()) {
            await _appendContent(content, now);
          }
        })
        .catchError((Object _) {});
  }

  /// Appends exactly one `scan_abandoned` row through the core's
  /// single sanctioned minter (Story 5.6, FR-16, AD-8, AD-21) — the
  /// same shape as every row writer above: the instant minted at
  /// entry, a v7 id, the shared queue, and a quiet absorption of a
  /// failing store. Unlike [_appendConsentDeclined] there is NO
  /// close-epoch re-check inside the closure: the decline's row
  /// asserts a decision a close can void, while the abandonment's
  /// row is made true BY the close — the departure is the resolution
  /// cause, so the row stands whatever else races it.
  Future<void> _appendScanAbandoned() {
    final now = nowOf();
    return writeQueue
        .enqueue(() async {
          for (final content in scanAbandoned()) {
            await _appendContent(content, now);
          }
        })
        .catchError((Object _) {});
  }
}

/// The scan prompt (Story 5.5): the Slicer's step contract for a photo
/// scan — real actions on what the frame shows, every step tagged 3–5
/// minutes, JSON only. Provider-facing instruction, never UI copy: the
/// rescue prompt's precedent (the access layer composes that one,
/// also not ARB) — AD-15's literal ban is on copy reaching a widget,
/// and this never reaches one. It rides the dispatch verbatim and is
/// the payload's only prose. One line, like the rescue contract's
/// canonical schema — the literal-audit's allowance is per-declaration.
const String _scanPrompt =
    'Eres el asistente de una app móvil de organización del hogar. Recibirás una foto real de un espacio doméstico desordenado. Tu tarea es convertirla en un plan corto que una persona pueda ejecutar hoy mismo, paso a paso. Escribe cada paso como una acción concreta y directa sobre objetos que se vean en la foto — no inventes objetos ni espacios, y da un orden ejecutable de principio a fin. Cada paso lleva su duración como un número entero de minutos entre 3 y 5. Responde únicamente con un objeto JSON con la forma {"steps": [{"text": "…", "duration_minutes": 4}]}, y nada más.';

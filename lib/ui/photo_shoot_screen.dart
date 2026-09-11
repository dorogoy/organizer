// The reward photos' shared shoot pipeline (Story 7.1, FR-17; the
// step-04 review's blind-shot patch): ONE shell helper both photo
// flows ride — the Before-offer's shot and the reward's After —
// owning the whole pipeline the two controllers used to duplicate:
// open (the explicit camera attempt, AD-17 — a denied open appends
// exactly one `permission_refused{camera}` row through the caller's
// own seam, so the Cámara entry is absent on the next render) → the
// viewfinder (`camera.buildPreview()` with a shutter, the scan
// surface's own pattern — a photo is never fired blind at the tap:
// FR-17's same-corner comparison exists because the user framed both
// shots) → dispose → the caller's commit (the content-addressed blob
// write and the queued append) → the pop, answered to the pushing
// surface.
//
// The register is the scan surface's own (Story 5.2, ruling 1-B): a
// preview and one shutter, no title, no helper, the OS back gesture
// the way out — backing out IS the quiet exit, nothing written and
// the pushing surface keeps standing exactly as it was (the offer
// still offered, the shoot primary still present). An interrupted or
// unavailable open, a missed shot or a lost grant at the shutter are
// functioning problems: no row, the honest `scanOpenFailed` notice,
// the OS back the way out and the next tap asking again — never a
// quiet pop that reads as a taken photo, and never the user's
// refusal. No face gate and no consent here: reward photos never
// upload (FR-25).
//
// The controller halves stay behind the seams the pushing surface
// hands in ([onDenied], [commit]) — this widget holds the camera and
// the navigation, never the store, the Files port or a queue.
import 'dart:async';

import 'package:flutter/material.dart';

import '../plugins/camera/camera_shell.dart';
import '../strings/app_strings.dart';
import 'dispenser/task_card.dart';
import 'tokens.dart';

/// The shared viewfinder's one flight, answered to the pushing
/// surface — sealed so no pending or retrying state exists as a type.
/// The OS back gesture answers null instead: the quiet exit, nothing
/// written, indistinguishable from leaving before the shot.
sealed class PhotoShootResult {
  const PhotoShootResult();
}

/// The shutter landed and the caller's commit wrote its blob and row:
/// the content-addressed name the pair or the pop needs.
final class PhotoShootCaptured extends PhotoShootResult {
  const PhotoShootCaptured(this.blobName);

  final String blobName;
}

/// The open was denied: exactly one `permission_refused{camera}` row
/// already stands (the caller's [PhotoShootScreen.onDenied] seam) and
/// the camera half is down — the pushing surface declines
/// permanently, exactly as a blocked Cámara entry rule does.
final class PhotoShootDenied extends PhotoShootResult {
  const PhotoShootDenied();
}

/// The shot or its commit failed (a missed frame, a lost grant, a
/// failed write or append): nothing written, no row beyond the
/// denial's own rule — the pushing surface folds to its own honest
/// nothing, never an error dead-end.
final class PhotoShootFailed extends PhotoShootResult {
  const PhotoShootFailed();
}

/// The reward photos' viewfinder (FR-17): the shared pipeline's
/// surface half. [onDenied] appends the denial's one row; [commit]
/// receives the shot's bytes and answers the landed blob's
/// content-addressed name, or null when its own write failed — the
/// controller halves own every store and Files touch.
class PhotoShootScreen extends StatefulWidget {
  const PhotoShootScreen({
    super.key,
    required this.camera,
    required this.onDenied,
    required this.commit,
  });

  final CameraShell camera;

  /// The denial's one `permission_refused{camera}` row, appended
  /// through the pushing flow's own controller and queue.
  final Future<void> Function() onDenied;

  /// The commit: blob write plus queued append, answering the blob's
  /// content-addressed name or null on any failure.
  final Future<String?> Function(List<int> bytes) commit;

  @override
  State<PhotoShootScreen> createState() => _PhotoShootScreenState();
}

class _PhotoShootScreenState extends State<PhotoShootScreen>
    with WidgetsBindingObserver {
  /// Whether a granted open stands (the preview runs) — false until
  /// the controller's open resolves, the quiet empty ground, never a
  /// loader (UX-DR41's own rule, the scan surface's precedent).
  bool _granted = false;

  /// The system-problem notice (ruling 1-B): the ask was interrupted,
  /// the open failed, or the shot was lost — the surface stays and
  /// states the problem, with the OS back the way out.
  bool _openFailed = false;

  /// The open's in-flight window — the staged permission moment: the
  /// lifecycle's release hands never run inside it (the dialog owns
  /// the moment).
  bool _openInFlight = false;

  /// The shutter's in-flight window: one shoot owns the surface until
  /// its flight settles, so a rapid second tap is nothing at all.
  bool _shooting = false;

  /// Whether this surface's flight already popped — the departure
  /// handler and the flight's own tail may both race the pop, and only
  /// the first owns it.
  bool _settled = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_open());
  }

  @override
  void dispose() {
    // Every exit path ends the camera: the OS back, the denial's pop,
    // the flight's own tail — disposal is the last of them, and the
    // facade's dispose is idempotent. The preview is already off the
    // tree here (the flight dropped it before disposing; the unmount
    // takes it with it).
    WidgetsBinding.instance.removeObserver(this);
    unawaited(widget.camera.dispose());
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
      case AppLifecycleState.inactive:
        // The transient occlusion holds: a system dialog or the
        // notification shade is not a departure.
        break;
      case AppLifecycleState.hidden:
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
        if (!_openInFlight && _granted && !_settled) {
          // A real departure while the viewfinder stands: the lens
          // never stays open behind a backgrounded surface, and the
          // quiet exit answers — nothing written, the pushing surface
          // keeps standing exactly as it was. Never while the ask is
          // staged: the dialog owns the moment.
          unawaited(_exit());
        }
    }
  }

  /// The pipeline's head (AD-17): the explicit camera attempt. The
  /// ruling's two domains split the answers — a denial is the user's
  /// own (the [PhotoShootScreen.onDenied] row, the camera down, the
  /// pop that declines the pushing flow permanently), while an
  /// interrupted or unavailable open is a system problem that mints
  /// nothing: the notice stands, the OS back the way out, and the
  /// next tap asks again.
  Future<void> _open() async {
    if (_openInFlight) {
      return;
    }
    _openInFlight = true;
    try {
      final outcome = await widget.camera.open();
      if (!mounted || _settled) {
        return;
      }
      switch (outcome) {
        case CameraOpenOutcome.granted:
          setState(() => _granted = true);
        case CameraOpenOutcome.denied:
          await widget.onDenied();
          await widget.camera.dispose();
          _pop(const PhotoShootDenied());
        case CameraOpenOutcome.interrupted:
        case CameraOpenOutcome.unavailable:
          setState(() => _openFailed = true);
      }
    } on Object {
      // A throwing seam is the functioning-problem domain: the honest
      // notice, never an eternal empty frame and never a row.
      if (mounted && !_settled) {
        setState(() => _openFailed = true);
      }
    } finally {
      _openInFlight = false;
    }
  }

  /// The shutter tap: the shot, then the pipeline's tail — the
  /// preview drops first (dispose-under-preview is a crash), the
  /// camera comes down, the caller's commit writes blob and row, and
  /// the pop answers the flight. A missed frame or a lost grant is
  /// the notice, no row (a malfunction is not a refusal).
  Future<void> _onShutter() async {
    if (_shooting || !_granted) {
      return;
    }
    _shooting = true;
    try {
      final shot = await widget.camera.takePicture();
      if (!mounted || _settled) {
        return;
      }
      switch (shot) {
        case CameraShotCaptured(:final bytes):
          // The preview leaves the tree first, then the lens comes
          // down — the scan surface's own ordering.
          setState(() => _granted = false);
          await WidgetsBinding.instance.endOfFrame;
          await widget.camera.dispose();
          if (!mounted || _settled) {
            return;
          }
          String? name;
          try {
            name = await widget.commit(bytes);
          } on Object {
            // The commit's own contract is quiet; a throwing seam is
            // the same honest nothing.
            name = null;
          }
          _pop(
            name == null ? const PhotoShootFailed() : PhotoShootCaptured(name),
          );
        case CameraShotNone():
        case CameraShotAccessLost():
          // A photo that was not taken is never presented as one that
          // was: the preview drops, the lens comes down, the notice
          // stays — no row, the OS back the way out.
          setState(() {
            _shooting = false;
            _granted = false;
            _openFailed = true;
          });
          await WidgetsBinding.instance.endOfFrame;
          await widget.camera.dispose();
      }
    } on Object {
      // A throwing shutter seam is the malfunction domain: the notice,
      // never an unhandled flight.
      if (mounted && !_settled) {
        setState(() {
          _shooting = false;
          _granted = false;
          _openFailed = true;
        });
        unawaited(widget.camera.dispose());
      }
    }
  }

  /// The quiet exit (a real departure): the lens down, nothing
  /// written, the null pop the pushing surface reads as leaving.
  Future<void> _exit() async {
    setState(() => _granted = false);
    await WidgetsBinding.instance.endOfFrame;
    await widget.camera.dispose();
    _pop(null);
  }

  void _pop(PhotoShootResult? result) {
    if (_settled || !mounted) {
      return;
    }
    _settled = true;
    Navigator.of(context).pop(result);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (_openFailed) {
      // The system-problem notice (ruling 1-B): the scan surface's own
      // register — the stated problem in the action-secondary role,
      // the OS back the way out, no shutter beneath a camera that did
      // not open.
      return Scaffold(
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(
              horizontal: Spacing.screenMargin,
              vertical: Spacing.touchTargetMin,
            ),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: registerMaxWidth),
                child: Semantics(
                  liveRegion: true,
                  child: Text(
                    AppStrings.of(context).scanOpenFailed,
                    style: theme.textTheme.bodyMedium,
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }
    return Scaffold(
      // The scan surface's own shape: the preview fills the ground,
      // the shutter sits at the bottom — nothing here is text but the
      // one action.
      body: Column(
        children: [
          Expanded(
            child: _granted
                ? widget.camera.buildPreview()
                : const SizedBox.shrink(),
          ),
          if (_granted)
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: Spacing.screenMargin,
                  vertical: Spacing.cardPadding,
                ),
                // The one recommended action, the scan shutter's own
                // affordance (the Done register, 48dp floor) — absent
                // until the grant stands: a dead shutter is not an
                // honest one.
                child: HechoButton(
                  label: AppStrings.of(context).scanShutter,
                  onTap: _onShutter,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// The scan surface (Story 5.2, FR-16, FR-25; amended by the 2026-09-05
// ruling 1-B): the Cámara entry's one screen — a camera preview and
// one shutter action, and nothing else. A-slim on the shoot surface:
// no title, no helper, no second exit — the OS back gesture is the
// way out (the NoSlicer precedent, no styled exit beside it), and the
// permission dialog the first open may raise is the system's own
// surface, never chrome here.
//
// The story ends at the face gate: a refused frame lands on the one
// calm surface (`NoSlicerSurface`, cause `personInFrame`) whose copy
// is the offer to reframe — the way on is retapping Cámara, the same
// tap count as anything else — and a passing frame closes quietly
// (5.5 wires the continuation).
//
// The ruling's system-problem notice: an **interrupted** ask (the
// system swallowed the dialog — no answer existed) and a **failed
// open** (no hardware, a device error) keep the surface standing and
// state the problem honestly (`scanOpenFailed`) — never a pop to the
// Dispenser, never a log row, never the entry touched: a malfunction
// is not hidden and not mistaken for the user's choice. The OS back
// is the way out, and the next tap on the entry asks again.
//
// Lifecycle (the DictationController observer's own pattern): a
// backgrounding releases the camera — never while the permission ask
// is staged (the ask owns the moment; the dialog's own `inactive` is
// exactly that case) — and a resume re-opens through the fast path,
// restoring the preview. Nothing is queued, retried or persisted on
// any exit: the surface holds no state beyond the controller it was
// handed, and the controller's every terminal path unlinks the
// scan's directory.
import 'dart:async';

import 'package:core/ports/no_slicer_cause.dart';
import 'package:flutter/material.dart';

import '../../plugins/camera/camera_shell.dart';
import '../../scan/scan_controller.dart';
import '../../strings/app_strings.dart';
import '../dispenser/task_card.dart';
import '../no_slicer/no_slicer_surface.dart';
import '../tokens.dart';

/// The surface's width bound on wide grounds — CaptureScreen's own
/// layout bound (a layout bound, not a gap; the tokenized side rule
/// `Spacing.screenMargin` stays in force below it).
const double _scanMaxWidth = 480;

/// The scan surface (FR-16, FR-25). [controller] is the shoot seam
/// over the same store the Dispenser holds; absent (the test seam),
/// the surface renders its empty frame and no open ever resolves —
/// the honest nothing.
class ScanScreen extends StatefulWidget {
  const ScanScreen({super.key, this.controller});

  final ScanController? controller;

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> with WidgetsBindingObserver {
  /// Whether a granted open stands (the preview runs). False until
  /// the controller's open resolves — the empty `surfaceBase` frame,
  /// never a loader (UX-DR41's own rule, the Dispenser's precedent).
  bool _granted = false;

  /// The system-problem notice state (ruling 1-B): the ask was
  /// interrupted or the open failed — the surface stays and states
  /// the problem instead of running a preview, with the OS back the
  /// way out.
  bool _openFailed = false;

  /// The shutter's in-flight window: a shoot owns the surface until
  /// its flow settles, so the control shows nothing new and a second
  /// tap is the controller's own guard's to absorb.
  bool _shooting = false;

  /// Whether this surface's own open is in flight — the staged
  /// permission moment. The lifecycle's release hands never run
  /// inside this window: the ask owns the moment, and the system
  /// dialog's own `inactive` is exactly the case being excluded.
  bool _openInFlight = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_open());
  }

  @override
  void dispose() {
    // Every exit path ends the scan: the system back, the refusal's
    // replacement, the quiet closes — disposal is the last of them,
    // and the controller's close is idempotent.
    WidgetsBinding.instance.removeObserver(this);
    unawaited(widget.controller?.close());
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        if (!_openInFlight && !_openFailed && mounted) {
          // A return to the foreground restores the scan: the camera
          // was released on the way out (or never landed), and the
          // fast path re-opens it — granted → the preview back,
          // interrupted/unavailable → the notice, exactly as the
          // first open answered.
          setState(() => _granted = false);
          unawaited(_open());
        }
      case AppLifecycleState.inactive:
      case AppLifecycleState.hidden:
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
        if (!_openInFlight && _granted) {
          // The camera releases on the way out — no lens stands open
          // behind a backgrounded surface — while the ask is staged
          // never: the dialog owns the moment, and its `inactive` is
          // not this surface's exit.
          setState(() => _granted = false);
          unawaited(widget.controller?.close());
        }
    }
  }

  Future<void> _open() async {
    final controller = widget.controller;
    if (controller == null || _openInFlight) {
      return;
    }
    _openInFlight = true;
    try {
      final CameraOpenOutcome outcome;
      try {
        outcome = await controller.open();
      } on Object {
        // The controller's own every-path quietness is a contract of
        // its fakes; the real seam throwing is still a functioning
        // problem, and the notice is the honest landing — never the
        // eternal empty frame.
        if (mounted) {
          setState(() => _openFailed = true);
        }
        return;
      }
      if (!mounted) {
        return;
      }
      switch (outcome) {
        case CameraOpenOutcome.granted:
          setState(() => _granted = true);
        case CameraOpenOutcome.denied:
          // The row is appended and the camera closed; the surface
          // leaves and the entry is absent on the Dispenser's next
          // render.
          Navigator.of(context).pop();
        case CameraOpenOutcome.interrupted:
        case CameraOpenOutcome.unavailable:
          // System problems, the ruling's other domain: the surface
          // STAYS and communicates — no pop, no row, the entry
          // untouched. The OS back is the way out; the next tap on
          // the entry asks again.
          setState(() => _openFailed = true);
      }
    } finally {
      _openInFlight = false;
    }
  }

  /// The shutter tap (FR-25): the shoot runs to its terminal outcome,
  /// then the surface leaves — a refusal replaces this route with the
  /// one calm surface, everything else pops. The outcome arrives with
  /// the scan's directory already unlinked and the row already
  /// appended; navigation is all that is left. A throwing seam is the
  /// fail-closed quiet close — the flight flag resets, nothing is
  /// surfaced, and the pop is the same one every quiet close takes.
  Future<void> _onShoot() async {
    if (_shooting) {
      return;
    }
    final controller = widget.controller;
    if (controller == null || !_granted) {
      return;
    }
    setState(() => _shooting = true);
    final ScanShootOutcome outcome;
    try {
      outcome = await controller.shoot();
    } on Object {
      if (!mounted) {
        return;
      }
      setState(() => _shooting = false);
      Navigator.of(context).pop();
      return;
    }
    if (!mounted) {
      return;
    }
    switch (outcome) {
      case ScanShootRefused():
        // The refusal is about the frame, never about the user: the
        // calm surface's copy offers the reframe, its exit is its
        // own, and this route is gone beneath the replacement.
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) =>
                const NoSlicerSurface(cause: NoSlicerCause.personInFrame),
          ),
        );
      case ScanShootClosed():
        Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (_openFailed) {
      // The system-problem notice (ruling 1-B): the surface's own
      // quiet register — NoSlicerSurface's grammar without its exit,
      // because the way out is the OS back and the way on is backing
      // out and tapping Cámara again (the entry never moved). The
      // notice scrolls at 200% and nothing truncates; no shutter
      // renders beneath a camera that did not open — a dead action is
      // not an honest one. The live region carries the swap to
      // TalkBack: the surface's whole content changed when the
      // problem landed, and the announcement is ink and prose only.
      return Scaffold(
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(
              horizontal: Spacing.screenMargin,
              vertical: Spacing.touchTargetMin,
            ),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: _scanMaxWidth),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Semantics(
                      liveRegion: true,
                      child: Text(
                        AppStrings.of(context).scanOpenFailed,
                        // bodyMedium is the wired action-secondary role
                        // — the warm close's role and ink (theme.dart):
                        // a stated problem, never an error register and
                        // never the user's omission.
                        style: theme.textTheme.bodyMedium,
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }
    final controller = widget.controller;
    return Scaffold(
      // The 200% floor's own shape: the preview fills the ground and
      // the shutter sits at the bottom — nothing here scrolls because
      // nothing here is text but the one action, which grows.
      body: Column(
        children: [
          Expanded(
            // The empty frame before the grant is the whole preview
            // ground — surfaceBase, never a loader — and the facade's
            // own wrap renders once the grant stands (the surface
            // builds it against the shell seam the controller
            // exposes; the controller itself is binding-free, like
            // its capture sibling).
            child: _granted && controller != null
                ? controller.camera.buildPreview()
                : const SizedBox.shrink(),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: Spacing.screenMargin,
                vertical: Spacing.cardPadding,
              ),
              // The one recommended action: the Done button's own
              // register, 48dp minimum, `scanShutter` spoken whole —
              // no glyph (the pinned set admits no new one), no
              // second control anywhere on the surface.
              child: HechoButton(
                label: AppStrings.of(context).scanShutter,
                onTap: _onShoot,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

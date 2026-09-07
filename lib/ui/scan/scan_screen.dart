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
// tap count as anything else — and a passing frame hands the scan to
// the consent gate (Story 5.5): the pre-gate provider read decides —
// no provider selected, the gate never renders and the no-key surface
// replaces this route (consent is never asked for a request that
// cannot be made); a selected provider pushes the gate, which owns
// the scan's terminal close from there.
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

import '../../egress/provider_allowlist.dart';
import '../../plugins/camera/camera_shell.dart';
import '../../scan/scan_controller.dart';
import '../../strings/app_strings.dart';
import '../dispenser/task_card.dart';
import '../no_slicer/no_slicer_surface.dart';
import '../settings/slicer_access_section.dart';
import '../tokens.dart';
import 'consent_gate_screen.dart';

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
  /// Serializes lifecycle close/open so a resume cannot mint a new
  /// scan over an in-flight release, and so `CameraPreview` is off
  /// the tree before dispose.
  Future<void> _lifecycle = Future<void>.value();

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

  /// Whether the gate-pass continuation handed the scan's terminal
  /// close to the consent gate (Story 5.5): the gate screen owns the
  /// close from there, so this surface's disposal must not run it —
  /// or the standing scan (and its frame) would die beneath the gate.
  bool _consentHandedOff = false;

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
    // and the controller's close is idempotent. The one exception is
    // the consent handoff: the gate screen owns the close once the
    // continuation replaced this route with the gate.
    WidgetsBinding.instance.removeObserver(this);
    if (!_consentHandedOff) {
      unawaited(widget.controller?.close());
    }
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        if (!_openInFlight && !_openFailed && !_shooting && mounted) {
          // A return to the foreground restores the scan: wait for
          // any in-flight release (the preview is already off the
          // tree), then the fast path re-opens — granted → the
          // preview back, interrupted/unavailable → the notice.
          setState(() => _granted = false);
          _enqueueLifecycle(() async {
            await widget.controller?.close();
            if (mounted && !_openFailed && !_shooting) {
              await _open();
            }
          });
        }
      case AppLifecycleState.inactive:
      case AppLifecycleState.hidden:
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
        if (!_openInFlight && !_shooting && _granted) {
          // The camera releases on the way out — no lens stands open
          // behind a backgrounded surface — while the ask is staged
          // never: the dialog owns the moment, and its `inactive` is
          // not this surface's exit. An in-flight shoot owns the
          // lens until it settles (the epoch guard retires a late
          // landing if the user left by another path).
          setState(() => _granted = false);
          _enqueueLifecycle(() async {
            await WidgetsBinding.instance.endOfFrame;
            await widget.controller?.close();
          });
        }
    }
  }

  void _enqueueLifecycle(Future<void> Function() work) {
    _lifecycle = _lifecycle.then((_) async {
      try {
        await work();
      } on Object {
        // Quiet: a failed release or restore must not wedge the next
        // lifecycle hand, and the surface's own open/close already
        // fold errors into the notice or the fail-closed close.
      }
    });
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
  /// the row already appended and — refusal, closed and failed — the
  /// scan's directory already unlinked; the one exception is the
  /// gate-pass arm, whose directory deliberately stands: the consent
  /// phase owns the unlink from there (Story 5.5). Navigation is all
  /// that is left. A throwing seam is the
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
      case ScanShootGatePassed():
        await _continueToConsent(controller);
      case ScanShootClosed():
        Navigator.of(context).pop();
      case ScanShootFailed():
        // A photo that was not taken is never presented as one that
        // was: drop the preview, then close, then the notice. No
        // row — a malfunction is not a refusal.
        setState(() {
          _shooting = false;
          _granted = false;
          _openFailed = true;
        });
        _enqueueLifecycle(() async {
          await WidgetsBinding.instance.endOfFrame;
          await widget.controller?.close();
        });
    }
  }

  /// The gate-pass continuation (Story 5.5): the pre-gate checks run
  /// fail-closed, before anything renders — no read seam or no slicer
  /// seam behind the controller (the half-wired test composition) is
  /// the quiet pop every closed scan takes, the gate seam's own rule.
  /// Then the provider read: null, or an id the frozen allowlist does
  /// not carry (the derivation gates charset, not membership), means
  /// the request cannot be made — consent is never asked, and the
  /// no-key surface replaces this route, its disposal closing the
  /// scan quietly. A throwing read is the same fail-closed quiet pop.
  /// A selected, allowlisted provider pushes the consent gate — with
  /// the provider's rendered name, the one display-name truth — and
  /// hands the scan's terminal close to it: this surface's disposal
  /// no longer closes, or the standing scan would die beneath the
  /// gate.
  Future<void> _continueToConsent(ScanController controller) async {
    final read = controller.readSelectedProvider;
    if (read == null || controller.slicer == null) {
      Navigator.of(context).pop();
      return;
    }
    String? providerId;
    try {
      providerId = await read();
    } on Object {
      if (mounted) {
        Navigator.of(context).pop();
      }
      return;
    }
    if (!mounted) {
      return;
    }
    final selected = providerId;
    if (selected == null || allowlistEntryById(selected) == null) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) =>
              const NoSlicerSurface(cause: NoSlicerCause.noKey),
        ),
      );
      return;
    }
    setState(() => _consentHandedOff = true);
    // The lens is never needed again past the handoff — every path
    // off the gate ends the scan — so it releases here, not at the
    // gate's own close: no privacy indicator stands lit through the
    // consent ask (the frame itself survives in the scan's cache).
    unawaited(controller.releaseCamera());
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (context) => ConsentGateScreen(
          controller: controller,
          providerName: providerNameOf(AppStrings.of(context), selected),
        ),
      ),
    );
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
          if (_granted)
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
                // second control anywhere on the surface. Absent until
                // the grant stands — a dead shutter is not an honest
                // one (the failed-open branch's own rule).
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

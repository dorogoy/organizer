// The consent gate (Story 5.5, FR-25): the scan chain's consent act —
// one full-screen surface stating what is sent and to whom (the named
// provider, the scan image and a prompt, nothing else), answered
// through `action-equal-pair` (UX-DR26): one row, both children
// `flex 1 1 0` — identical width, height, ground, hairline, type role,
// ink and tap count — and no fill on either, so neither answer is the
// recommended one. The theme's `accent-soft` (`colorScheme.primary`)
// appears nowhere on the surface. This is THE app's only
// zero-recommended-actions surface, a declared exception composed
// inline here — no shared component exists to borrow, and the
// exception register implies no second consumer.
//
// Declining costs exactly what accepting costs: same taps, no
// dimming, no confirmation, no delay. `Enviar la foto` sits in the
// first, unfavourable slot — the recorded residual asymmetry
// (UX-DR52): reading order, not solved. After an answer the pair is
// gone — no second answer exists, and the controller's own
// once-guards back that up. The accept arm alone becomes the wait
// (Story 5.6, UX-DR56): `Creando tareas` beside the indeterminate
// writing pencil — the app's first and only animation — in the
// illustration register, with no percentage, duration, queue
// position or timeout anywhere on the surface (the wait is
// deliberately uncapped, FR-16); a decline routes on with nothing
// standing in — no copy ever claims task creation on a refusal.
//
// The wait's exits: OS back remains the one way out (UX-DR52 — no
// PopScope, leaving is abandoning, and the controller's close mints
// the departure's one `scan_abandoned` row); the answer itself ends
// it — delivered the interim quiet pop, failed the no-Slicer
// mapping, stale the pop. The pair is gone the frame the answer
// lands and never returns.
//
// The terminal routing (the I/O matrix): decline → the no-Slicer
// surface's own `consentDeclined` cause — no re-ask, no persuasion,
// no second attempt; delivered → quiet close to the Dispenser (the
// interim discard, P2-A — nothing lands, no row; 5.7 replaces
// exactly this arm); failed → the standing `noSlicerCauseFromFailure`
// map, the 4-5 mapping unchanged; stale → pop, the scan already ended
// (leaving is not declining, no decline row). The system back is the
// OS pop — leaving before an answer is neither declining nor
// abandoning: no row, the scan closes quietly through the
// controller's close; leaving mid-wait IS abandoning: the close mints
// the departure's one `scan_abandoned` row (Story 5.6) and the
// dispatch left standing resolves stale (no routing).
//
// The lifecycle mirrors the scan surface's own contract (Story 5.2):
// a real departure (hidden/paused/detached) closes the scan through
// the controller — the cache unlinks, the camera releases, a dispatch
// left standing turns stale with its `scan_abandoned` row beside it —
// while a transient inactive→resumed occlusion (a system dialog, a
// notification shade) holds, never closes: the app holds what stands,
// and the sweep stays the crash backstop.
//
// The layout register is NoSlicerSurface's: full-screen surfaceBase,
// centered, 480 max-width, the 200% floor through SingleChildScrollView,
// system back as OS pop.
import 'dart:async';
import 'dart:math' as math;

import 'package:core/ports/no_slicer_cause.dart';
import 'package:flutter/material.dart';

import '../../scan/scan_controller.dart';
import '../../strings/app_strings.dart';
import '../no_slicer/no_slicer_surface.dart';
import '../tokens.dart';
import 'writing_pencil.dart';

/// The surface's width bound on wide grounds — NoSlicerSurface's own
/// layout bound (a layout bound, not a gap; the tokenized side rule
/// `Spacing.screenMargin` stays in force below it).
const double _consentGateMaxWidth = 480;

/// The wait's pencil, at the illustration register's own scale
/// (DESIGN.md {illustration register}: the mark stands alone on a
/// full-screen surface — the register's mockup precedents draw Warm
/// Return at 168 and the permission-to-rest screen at 150). A layout
/// constant of this surface beside its only reader, never a motion
/// DESIGN token — none exists and 5.6 adds none.
const double _scanWaitPencilSize = 160;

/// The consent gate (FR-25). [controller] is the scan seam the consent
/// act runs through — decline's row and unlink, accept's mint, row and
/// dispatch; absent (the test seam), the pair renders and a tap
/// answers nothing. [providerName] is the selected provider's rendered
/// name — the body's one interpolation (AD-15's sanctioned
/// placeholder), resolved by the caller through the one display-name
/// truth.
class ConsentGateScreen extends StatefulWidget {
  const ConsentGateScreen({
    super.key,
    this.controller,
    required this.providerName,
  });

  final ScanController? controller;

  final String providerName;

  @override
  State<ConsentGateScreen> createState() => _ConsentGateScreenState();
}

class _ConsentGateScreenState extends State<ConsentGateScreen>
    with WidgetsBindingObserver {
  /// Whether an answer stands: the pair is gone the moment one does —
  /// no second answer exists.
  bool _answered = false;

  /// Whether the standing answer was the accept: the wait belongs to
  /// the accept arm alone (the frozen boundaries scope it there) — a
  /// decline routes on with nothing standing in, so no copy ever
  /// claims task creation on a refusal.
  bool _accepted = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.hidden:
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
        // A real departure closes the scan (the scan surface's own
        // release contract, carried past it): the cache unlinks, the
        // camera releases, and a dispatch left standing resolves
        // stale — with its one `scan_abandoned` row minted by the
        // close itself, the departure being the resolution cause
        // (Story 5.6). Close is idempotent — a resolution that
        // already ended the scan makes this a quiet no-op.
        unawaited(widget.controller?.close());
      case AppLifecycleState.resumed:
      case AppLifecycleState.inactive:
        // The transient occlusion holds: a system dialog or the
        // notification shade is not a departure, and nothing closes
        // beneath it (the 5.2 hold-open; the sweep stays the crash
        // backstop).
        break;
    }
  }

  @override
  void dispose() {
    // The scan surface handed the scan's terminal close to this gate:
    // every exit path here — the OS back (leaving before an answer is
    // not declining; leaving mid-wait is abandoning, and the close
    // mints the row), the decline's and the failure's replacement,
    // the delivered arm's quiet pop — ends the scan at this disposal.
    // The controller's close is idempotent: a resolution that already
    // unlinked makes this a quiet no-op beside the camera's dispose
    // and the epoch bump that retires any dispatch left standing.
    WidgetsBinding.instance.removeObserver(this);
    unawaited(widget.controller?.close());
    super.dispose();
  }

  /// The decline tap (FR-25, FR-29): one `consent_declined` row, the
  /// cache unlinked, the slicer never called — then the no-Slicer
  /// surface's own cause replaces this route. No confirmation, no
  /// delay, no re-ask. Absent (the test seam), a tap answers nothing:
  /// the pair stays, nothing routes. A decline that did not stand (a
  /// close landing mid-decision — the stale arm) pops instead: no
  /// surface may claim a decline whose row does not stand.
  Future<void> _decline() async {
    final controller = widget.controller;
    if (_answered || controller == null) {
      return;
    }
    setState(() => _answered = true);
    final took = await controller.declineConsent();
    if (!mounted) {
      return;
    }
    if (!took) {
      // The scan ended while the decision stood: the stale arm — the
      // gate pops like the accept's own, leaving is not declining.
      Navigator.of(context).pop();
      return;
    }
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (context) =>
            const NoSlicerSurface(cause: NoSlicerCause.consentDeclined),
      ),
    );
  }

  /// The accept tap (AD-8): the token minted, the row appended, the
  /// one dispatch — then the outcome routes. The pair is already gone
  /// (the wait stands in), so a rapid second tap is nothing at all.
  /// Absent (the test seam), a tap answers nothing: the pair stays,
  /// nothing routes.
  Future<void> _accept() async {
    final controller = widget.controller;
    if (_answered || controller == null) {
      return;
    }
    setState(() {
      _answered = true;
      _accepted = true;
    });
    final outcome = await controller.grantConsent();
    if (!mounted) {
      return;
    }
    switch (outcome) {
      case ScanConsentDelivered():
        // The interim discard (P2-A): nothing lands, no row — the
        // scan closes to the Dispenser. 5.7 replaces exactly this arm.
        Navigator.of(context).pop();
      case ScanConsentFailed(:final cause):
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) =>
                NoSlicerSurface(cause: noSlicerCauseFromFailure(cause)),
          ),
        );
      case ScanConsentStale():
        // A late resolution after the scan closed: the scan already
        // ended — leaving is not declining, no row — so the gate pops
        // instead of stranding the answer on the untappable wait.
        Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final strings = AppStrings.of(context);
    return Scaffold(
      // The standard surfaceBase frame, centered, NoSlicerSurface's own
      // grammar: SafeArea first, screen margins on the sides, the 200%
      // floor holding through SingleChildScrollView — the body grows
      // and the surface scrolls, never truncates. No PopScope: the
      // system back gesture is the OS pop (leaving is not declining).
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(
            horizontal: Spacing.screenMargin,
            vertical: Spacing.touchTargetMin,
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: _consentGateMaxWidth),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // The whole ask: what is sent (the scan image and a
                  // prompt) and to whom (the named provider) — the
                  // body's one parameterized sentence. bodyMedium is
                  // the wired action-secondary role (theme.dart), the
                  // calm register the no-Slicer causes render in.
                  Text(
                    strings.consentGateBody(widget.providerName),
                    style: theme.textTheme.bodyMedium,
                    textAlign: TextAlign.center,
                  ),
                  // The pause between reading and answering — the same
                  // largest interior gap the dispenser card holds.
                  const SizedBox(height: Spacing.taskToActions),
                  if (_answered)
                    // The answer stands: no second answer exists. The
                    // wait (Story 5.6, UX-DR56) renders on the accept
                    // arm alone — `Creando tareas` beside the
                    // indeterminate writing pencil, the illustration
                    // register's mark standing alone on this
                    // full-screen surface. Nothing here reads as
                    // percentage, duration, queue position or
                    // timeout: the wait is deliberately uncapped
                    // (FR-16), OS back is the one exit, and the pair
                    // is gone the frame the answer landed. A decline
                    // routes on with nothing standing in, never a
                    // copy that claims task creation on a refusal.
                    _accepted
                        ? Center(
                            child: LayoutBuilder(
                              builder: (context, constraints) {
                                // The pair stands centered — the
                                // register's standing-alone mark, never
                                // a stretched row's flush-left anchor.
                                // Below the width where the register
                                // size fits beside a wrapped title the
                                // PENCIL yields (each half the width
                                // minus the gap — the no-measuring
                                // proxy for the longest title word),
                                // so `beside` holds at every width
                                // and nothing overflows horizontally
                                // — the 200% floor's own decision.
                                final pencil = math.max(
                                  24.0,
                                  math.min(
                                    _scanWaitPencilSize,
                                    (constraints.maxWidth -
                                            Spacing.cardPadding) /
                                        2,
                                  ),
                                );
                                return Row(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    WritingPencil(size: pencil),
                                    const SizedBox(width: Spacing.cardPadding),
                                    Flexible(
                                      child: Text(
                                        strings.scanWaitTitle,
                                        style: theme.textTheme.bodyMedium,
                                        textAlign: TextAlign.center,
                                      ),
                                    ),
                                  ],
                                );
                              },
                            ),
                          )
                        : const SizedBox.shrink()
                  else
                    // `action-equal-pair` (UX-DR26), composed inline —
                    // the declared exception, never a reusable
                    // component. Both children `Expanded` (flex 1 1 0):
                    // identical width by construction. Both unfilled —
                    // raised ground with a 1px hairline, no
                    // `accent-soft` anywhere — identical type role,
                    // ink, radius and 48dp floor, `{spacing.action-gap}`
                    // apart. `Enviar la foto` in the first, unfavourable
                    // slot: the recorded residual asymmetry.
                    Row(
                      children: [
                        Expanded(
                          child: Material(
                            color: theme.colorScheme.surfaceContainerHighest,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(
                                Radii.radiusDefault,
                              ),
                              side: BorderSide(
                                color: theme.colorScheme.outline,
                                width: 1,
                              ),
                            ),
                            clipBehavior: Clip.antiAlias,
                            child: InkWell(
                              onTap: _accept,
                              child: ConstrainedBox(
                                constraints: const BoxConstraints(
                                  minHeight: Spacing.touchTargetMin,
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: Spacing.chipPaddingHorizontal,
                                  ),
                                  child: Center(
                                    child: Text(
                                      strings.consentGateSend,
                                      // bodyLarge is the wired
                                      // action-primary role
                                      // (theme.dart).
                                      style: theme.textTheme.bodyLarge,
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: Spacing.actionGap),
                        Expanded(
                          child: Material(
                            color: theme.colorScheme.surfaceContainerHighest,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(
                                Radii.radiusDefault,
                              ),
                              side: BorderSide(
                                color: theme.colorScheme.outline,
                                width: 1,
                              ),
                            ),
                            clipBehavior: Clip.antiAlias,
                            child: InkWell(
                              onTap: _decline,
                              child: ConstrainedBox(
                                constraints: const BoxConstraints(
                                  minHeight: Spacing.touchTargetMin,
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: Spacing.chipPaddingHorizontal,
                                  ),
                                  child: Center(
                                    child: Text(
                                      strings.consentGateDecline,
                                      style: theme.textTheme.bodyLarge,
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

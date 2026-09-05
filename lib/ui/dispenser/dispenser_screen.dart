// The Dispenser surface (Stories 1.8–1.10, UX-DR14/UX-DR41): the app's
// home. Exactly one Micro-task on screen (FR-1), no list, calendar,
// counter, streak, badge or overdue indicator anywhere reachable
// (UX-DR44). The air around the card is a minimum 48dp plus flex — never
// a fixed value — so at 200% font scale the card grows into its air and
// the screen scrolls (NFR6); side margins hold `Spacing.screenMargin` and
// a max-width bound keeps the card from stretching on wide grounds.
//
// No splash, spinner or loader ever precedes the first card (UX-DR41,
// NFR5): a read that has not resolved renders the empty `surfaceBase`
// frame, and a read that fails leaves it standing — the controller's
// memo cleared, so the next read retries. No error string, no crash
// surfaced. The retry's trigger is the same one
// `SessionController` uses: a real return to the foreground re-reads,
// and a Hecho or skip answer refreshes the surface between foregrounds.
//
// The Hecho tap (Story 1.9): the light haptic acknowledges the act
// immediately — never awaited, never the sole signal — then the write is
// awaited (`card_done` + the bundled next `card_dealt`), the surface
// refreshes from the answered log, and «¡Buen trabajo!» shows for a
// fixed window above whatever view commits next (UX-DR38/39/51). The
// completed card exits the tree entirely via the refresh clear — removal,
// deliberately no motion — and a failed write is absorbed by the empty
// frame, quietly.
//
// The secondary tap (Story 1.10, FR-3): the skip is `_onDone`'s
// mechanics minus all feedback — no haptic, no acknowledgement, nothing
// celebration-shaped; the different card *is* the answer. The same
// in-flight guard serializes it against a Hecho, the write is awaited
// (`card_skipped` + the bundled next `card_dealt`), and the surface
// refreshes from the answered log; a failed write leaves the quiet
// empty frame standing, and when the skipped card was the day's last
// candidate the refresh lands on the already-shipped warm close.
// Completion state — the ack flags and their window — stays
// completion-only: a skip touches none of it.
//
// The checkpoint offer (Story 2.4, FR-10, UX-DR44/51): when the
// controller's read resolves the permission-to-rest surface, the
// content arm is the checkpoint's two actions and nothing else —
// `Nada más por el momento` as the primary permission to stop in the
// Done button's register, running the same one-tap pause write, and
// `Quiero seguir` as a `SecondaryTextAction` — silent, never filled,
// never emphasized, never animated, no haptic — running the extension.
// No continuation question exists anywhere, and nothing on the offer
// counts anything (UJ-1). The same silent secondary stands beneath the
// warm close while the close is the offer — an elapsed pocket whose
// pool could still deal — so the close and the offer are one grammar
// with no second surface.
//
// The chrome this surface composes around the committed view — the
// pocket-trigger band with the Lápiz entry, the ladder sheet, the
// footer band, the shared frame — and the all-arm layers around the
// view itself — the ambient strip below it, the Warm Return greeting
// above it, the completion acknowledgement — live in their sibling
// files (`dispenser_chrome.dart`, `dispenser_strip_layer.dart`,
// `dispenser_dealt_view.dart`, `dispenser_closed_view.dart`,
// `dispenser_rest_offer_view.dart`), each carrying its own provenance.
import 'dart:async';

import 'package:core/energy/energy.dart';
import 'package:core/ports/no_slicer_cause.dart';
import 'package:core/settings/settings.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../capture/capture_controller.dart';
import '../../capture/dictation_controller.dart';
import '../../dispenser/dispenser_controller.dart';
import '../../settings/settings_controller.dart';
import '../capture/capture_screen.dart';
import '../no_slicer/no_slicer_surface.dart';
import '../settings/nuevo_proyecto_screen.dart';
import '../tokens.dart';
import 'dispenser_chrome.dart';
import 'dispenser_closed_view.dart';
import 'dispenser_dealt_view.dart';
import 'dispenser_rest_offer_view.dart';
import 'dispenser_strip_layer.dart';

// The ladder options' canonical home moved with the ladder UI into
// `dispenser_chrome.dart`; the widget tests import
// `pocketLadderOptions` through this file, so the symbol stays
// reachable from its old address (the spec's public-surface pin).
export 'dispenser_chrome.dart' show pocketLadderOptions;

/// The short-surface floor's base decision height (Story 2.3, UX-DR45 vs
/// NFR6). It scales with the user's text scale: at 200%, the chrome stays
/// pinned from 320dp upward; below that, both the chip and footer join one
/// scroll region. Moving all chrome together prevents a viewport shorter
/// than the grown chip itself from overflowing. The 320×220 @200% pin
/// guards this floor without making 320 a fixed answer at every scale.
const double _pinnedChromeBaseBodyHeight = 160;

/// The completion acknowledgement's fixed window (UX-DR39): 2000 ms,
/// calm and far from the 500 ms budget it must never gate — the next
/// card is already committed underneath it. A behavior constant, not a
/// DESIGN token, so it lives here beside its only reader.
const Duration _completionAckWindow = Duration(milliseconds: 2000);

class DispenserScreen extends StatefulWidget {
  const DispenserScreen({
    super.key,
    required this.controller,
    this.sessionSettled,
    this.settings,
    this.capture,
    this.dictation,
  });

  final DispenserController controller;
  final Future<void> Function()? sessionSettled;

  /// The Settings seam (Story 2.1): main constructs it over the same
  /// store and hands it down through the way-out chain — the footer
  /// here, the `Nuevo proyecto` carrier, the Settings list. Absent (the
  /// test seam), the footer renders and opens the carrier with no
  /// controller behind it.
  final SettingsController? settings;

  /// The Manual Capture seam (Story 3.2): main constructs it over the
  /// same store and the shared write queue, and the Lápiz entry hands
  /// it to the capture surface. Absent (the test seam), the entry still
  /// opens the surface with no controller behind it — the write goes
  /// nowhere and the route stays.
  final CaptureController? capture;

  /// The dictation seam (Story 3.4): threaded beside the capture seam —
  /// absent (the test seam), the capture surface renders with the
  /// keyboard alone and no capsule.
  final DictationController? dictation;

  @override
  State<DispenserScreen> createState() => _DispenserScreenState();
}

class _DispenserScreenState extends State<DispenserScreen>
    with WidgetsBindingObserver {
  /// Null until the first read resolves: the empty frame, never a loader.
  DispenserView? _view;
  int _readGeneration = 0;
  bool _leftForegroundSinceRead = false;

  /// A completion whose write landed and whose ack is waiting for the
  /// post-completion view to commit — the ack never renders for an
  /// uncommitted (or failed) read, and never for a failed write.
  bool _completionAckWaiting = false;

  /// Whether the committed view carries the ack line above it. Cleared
  /// only by the window's elapse — plain removal, nothing else moves.
  bool _completionAckVisible = false;
  Timer? _completionAckTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refresh();
  }

  @override
  void dispose() {
    _completionAckTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        if (_leftForegroundSinceRead) {
          _leftForegroundSinceRead = false;
          _refresh();
        }
      case AppLifecycleState.inactive:
      case AppLifecycleState.hidden:
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
        _leftForegroundSinceRead = true;
    }
  }

  void _refresh() {
    final generation = ++_readGeneration;
    if (_view != null) {
      setState(() => _view = null);
    }
    _readAfterSessionSettles(generation);
  }

  /// Whether an answer's write — a completion's or a skip's — is between
  /// its tap and its settle: the synchronous in-flight guard both
  /// answers share, so a skip and a `Hecho` can never interleave at the
  /// surface. An answer already in flight owns the surface: a rapid
  /// second tap on either control returns early — it would only fire a
  /// second haptic on the `Hecho` side (a skip fires none) and a second
  /// refresh for a write the core guard no-ops.
  bool _writeInFlight = false;

  /// One tap, no confirmation, no undo (UX-DR43): the light haptic
  /// acknowledges the act — fired immediately, never awaited, never the
  /// sole completion signal — then the write is awaited, then the surface
  /// refreshes from the answered log. The ack appears only when the
  /// post-completion view commits (a failed write would make the visible
  /// line a lie); nothing celebration-related is ever awaited before the
  /// next card, whose only awaits are `complete`'s and `read`'s store
  /// round-trips.
  Future<void> _onDone(DispenserDealt dealt) async {
    if (_writeInFlight) {
      return;
    }
    _writeInFlight = true;
    var releaseAfterRefresh = false;
    HapticFeedback.lightImpact();
    try {
      await widget.controller.complete(dealt);
      if (!mounted) {
        return;
      }
      // The answered deal is over (Story 4.6): whatever deal the
      // rescue markers keyed themselves to ended here too — a
      // completion ends a deal exactly as a skip does.
      _degradedRescueDealId = null;
      _autoRescueFiredForDeal = null;
      _completionAckWaiting = true;
      _refresh();
      // The old card remains in the render tree until this refresh's frame.
      // Keep the shared guard through it so its stale callbacks cannot act.
      releaseAfterRefresh = true;
      _releaseWriteAfterRefreshFrame();
    } catch (_) {
      // The write failed: quiet and deliberate — the empty frame stands,
      // no ack, nothing surfaced. The log stayed consistent either way,
      // and a real return to the foreground re-reads. The whole ack-flag
      // class clears with it: a waiting ack, a visible one and its
      // window are all stale the moment this write is known to have
      // failed.
      _completionAckWaiting = false;
      _completionAckTimer?.cancel();
      _completionAckTimer = null;
      if (mounted) {
        setState(() {
          _view = null;
          _completionAckVisible = false;
        });
      }
    } finally {
      if (!releaseAfterRefresh) {
        _writeInFlight = false;
      }
    }
  }

  /// One tap, no confirmation, and deliberately no feedback of any kind
  /// (FR-3, Story 1.10): the skip is `_onDone`'s mechanics minus the
  /// haptic and the whole ack-flag class — the different card *is* the
  /// answer, so nothing celebration-shaped may precede it. The same
  /// in-flight guard as a completion keeps a rapid second skip — or a
  /// skip racing a Hecho, either order — from interleaving at the
  /// surface: the early return fires before anything observable, and
  /// the core's guard would append nothing anyway. The write is
  /// awaited, then the surface refreshes from the answered log; on
  /// exhaustion the read resolves to the warm close. A failed write is
  /// absorbed by the empty frame, quietly — and because a skip touches
  /// no completion state, no ack flag exists here to clear.
  Future<void> _onSkip(DispenserDealt dealt) async {
    if (_writeInFlight) {
      return;
    }
    _writeInFlight = true;
    var releaseAfterRefresh = false;
    try {
      await widget.controller.skip(dealt);
      if (!mounted) {
        return;
      }
      // The skipped deal is over (Story 4.6): whatever deal the rescue
      // markers keyed themselves to ended here, so a later deal — even
      // a later deal of the same item, fresh from the resolver —
      // starts clean, and a re-warranted one can auto-fire again.
      _degradedRescueDealId = null;
      _autoRescueFiredForDeal = null;
      _refresh();
      // The old card remains in the render tree until this refresh's frame.
      // Keep the shared guard through it so its stale callbacks cannot act.
      releaseAfterRefresh = true;
      _releaseWriteAfterRefreshFrame();
    } catch (_) {
      // The write failed: quiet and deliberate — the empty frame stands,
      // nothing surfaced, and a real return to the foreground re-reads.
      // The completion ack's flags and window are not this write's to
      // touch: they belong to a completion, and stay whatever a
      // completion left them.
      if (mounted) {
        setState(() => _view = null);
      }
    } finally {
      if (!releaseAfterRefresh) {
        _writeInFlight = false;
      }
    }
  }

  void _releaseWriteAfterRefreshFrame() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _writeInFlight = false;
    });
  }

  /// The deal whose failed rescue degraded the one control to its skip
  /// half (Story 4.6, FR-5): ephemeral shell state keyed by the dealt
  /// card's id — skip-only for the rest of THAT deal, nothing
  /// persisted, no counter, no row. The deal's every end clears it —
  /// a skip, a completion, a supersede, a session close, or a
  /// different card committing — so a fresh deal of the same item,
  /// days later or right after a close, starts clean; the failure
  /// itself already reset the item's refusal counter through its
  /// activation row.
  String? _degradedRescueDealId;

  /// The deal the auto-heuristic already fired for and the activation
  /// committed (Story 4.6, FR-5): the belt to the counter's braces —
  /// the activation row is the real reset (a fresh read derives
  /// `autoRescueDue` false once `slice_requested` is in the log), and
  /// this marker holds the line only for the refreshes that can
  /// interleave before that row lands or after its write failed. It
  /// is set when — and only when — the controller reports the
  /// activation committed (the success and failure outcomes; a
  /// decline or a failed write left no row, so the warrant stays
  /// derivable and a retry may fire), and it clears with the deal's
  /// every end exactly like the degrade's, so a re-warranted deal of
  /// the same item days later auto-fires again.
  String? _autoRescueFiredForDeal;

  /// The deal whose rescue is between its ask and its landing (Story
  /// 4.6, FR-5): the FLIGHT guard — one rescue per deal, so a double
  /// tap inside one flight returns early (the core's pending
  /// activation refusal is the same line held at the command
  /// boundary). Deliberately NOT the shared write guard: the network
  /// await may last a provider's whole latency, and a real user act
  /// on the still-standing card — a Hecho, a skip — must land
  /// normally through it; the controller's queue serializes the
  /// actual writes, and the core discards a landing whose deal ended
  /// in flight (done or skipped alike).
  String? _rescueFlightDealId;

  /// The one control's tap resolution (Story 4.6, FR-5): a step
  /// card's tap skips — the depth cap, no ask, no refusal surface, no
  /// error; a deal whose rescue already failed this deal skips too —
  /// the control stated its cause once and degrades; any other dealt
  /// card, any moment, asks. The string never changes
  /// (`Otra más fácil / Ahora no`, FR-3 + FR-5's one unsplit control)
  /// — only the resolution moves.
  Future<void> _onSecondaryAction(DispenserDealt dealt) async {
    if (_writeInFlight) {
      return;
    }
    if (dealt.rescueStep || _degradedRescueDealId == dealt.card.id) {
      return _onSkip(dealt);
    }
    // A tap inside a pending flight passes the card too (FR-3 stays
    // reachable everywhere, even through provider latency): the
    // landing then meets an ended deal and goes quiet, by the stale
    // rule below and the core's own in-flight discard.
    if (_rescueFlightDealId == dealt.card.id) {
      return _onSkip(dealt);
    }
    return _onRescue(dealt, fromTap: true);
  }

  /// The rescue ask (Story 4.6, FR-5, FR-29): tap-first on a normal
  /// card — one tap requests the re-slice through the Origin Context
  /// and the FR-28 path. The ask holds the flight guard alone: the
  /// card still stands through the provider's whole latency, so a
  /// Hecho or a skip on it lands normally (the controller's log queue
  /// serializes the writes; the core discards a landing whose deal
  /// ended in flight — done or skipped alike — so nothing dangles);
  /// only the outcome's commit borrows the shared write guard for the
  /// one frame the replaced card's stale callbacks could act in.
  /// Success supersedes: the head step stands. Failure states the
  /// cause ONCE through the 4-5 calm surface — pushed with both
  /// capture seams threaded, the push idiom's isCurrent guard held —
  /// and degrades this deal's control to its skip half; the card
  /// stands dealable behind the surface, and the system back gesture
  /// is the OS pop. A failed write is absorbed by the empty frame,
  /// quietly, degrades nothing and arms no auto marker — nothing
  /// landed, so the warrant stays derivable for a retry.
  Future<void> _onRescue(DispenserDealt dealt, {bool fromTap = false}) async {
    if (_rescueFlightDealId == dealt.card.id) {
      return;
    }
    _rescueFlightDealId = dealt.card.id;
    // A launch or foreground refresh may still be reading the old log.
    // Its result must not overwrite this rescue's landing after it
    // lands.
    _readGeneration++;
    try {
      await widget.sessionSettled?.call();
      final outcome = await widget.controller.rescue(dealt);
      if (!mounted) {
        return;
      }
      switch (outcome) {
        case DispenserRescueSucceeded(:final view):
          // The activation committed: the counter is reset, and the
          // deal it reset is over — a superseded deal needs neither
          // marker. Only the flight's OWN markers die with it,
          // though: a late delivery into an ended deal is discarded
          // by the core, and whatever deal now stands (a successor
          // whose own ask already failed) owns its markers alone —
          // its control stays degraded for the rest of that deal
          // (FR-5), unrearmed by a discarded landing.
          if (_autoRescueFiredForDeal == dealt.card.id) {
            _autoRescueFiredForDeal = null;
          }
          if (_degradedRescueDealId == dealt.card.id) {
            _degradedRescueDealId = null;
          }
          _writeInFlight = true;
          setState(() => _view = view);
          // The old card remains in the render tree until this
          // refresh's frame. Keep the shared guard through it so its
          // stale callbacks cannot act.
          _releaseWriteAfterRefreshFrame();
        case DispenserRescueFailed(:final cause, :final view):
          // The activation committed here too — the marker holds the
          // auto line while the degraded deal stands. The control is
          // skip-only for the rest of this deal: the failure stated
          // its cause, and the second tap passes the card (FR-3 stays
          // reachable everywhere). But only while the deal still
          // stands: a Hecho or a skip that landed mid-flight ended it,
          // and a dead deal gets neither markers nor surface — the
          // `slice_failed` row stands as history, quietly (D1).
          final dealStands =
              view is DispenserDealt && view.card.id == dealt.card.id;
          if (dealStands) {
            _autoRescueFiredForDeal = dealt.card.id;
            _degradedRescueDealId = dealt.card.id;
          }
          _writeInFlight = true;
          setState(() => _view = view);
          _releaseWriteAfterRefreshFrame();
          if (dealStands) {
            _openNoSlicerSurface(cause);
          }
        case DispenserRescueDeclined():
          // The command boundary refused (a step, an existing chain,
          // a pending activation, or no Slicer behind the test seam):
          // nothing landed. On the tap path the card still passes —
          // a refused ask degrades to its skip half, exactly like a
          // step's tap (no refusal surface, no error, no dead tap).
          // The auto path stays silent: a heuristic never answers.
          if (fromTap) {
            await _onSkip(dealt);
            return;
          }
          _autoRescueFiredForDeal = dealt.card.id;
          break;
      }
    } catch (_) {
      // The write failed: quiet and deliberate — the empty frame
      // stands, nothing surfaced, and a real return to the foreground
      // re-reads. No degradation and no auto marker: nothing stated a
      // cause and nothing landed, so both the tap and the heuristic
      // stay live for a retry.
      if (mounted) {
        setState(() => _view = null);
      }
    } finally {
      if (_rescueFlightDealId == dealt.card.id) {
        _rescueFlightDealId = null;
      }
    }
  }

  /// The 4-5 calm surface's push (Story 4-6 over 4-5, FR-29): the
  /// failure's mapped cause, both Manual Capture seams threaded
  /// exactly as the Lápiz entry threads them, the same rapid-tap
  /// guard every push this surface owns. Nothing is queued on the
  /// push or the pop; the card stands dealable behind the route.
  void _openNoSlicerSurface(NoSlicerCause cause) {
    if (ModalRoute.of(context)?.isCurrent ?? false) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => NoSlicerSurface(
            cause: cause,
            controller: widget.capture,
            dictation: widget.dictation,
          ),
        ),
      );
    }
  }

  Future<void> _readAfterSessionSettles(int generation) async {
    try {
      // The lifecycle mints and appends the launch/resume deal first. A
      // screen read only derives from that settled log, never its precursor.
      await widget.sessionSettled?.call();
      final view = await widget.controller.read();
      if (mounted && generation == _readGeneration) {
        _commitView(view);
      }
    } catch (_) {
      // A completion armed for the post-completion read does not carry
      // its ack past the failure — but only this read may say so. A
      // stale failure (a newer refresh already in flight) has no
      // standing to clear: its read produced no view, and the current
      // generation's commit still owes the ack.
      if (generation == _readGeneration) {
        _completionAckWaiting = false;
        if (mounted) {
          // Pending and failed reads intentionally have the same empty frame.
          setState(() => _view = null);
        }
      }
    }
  }

  /// Ends the rescue markers when the committed view is no longer the
  /// dealt card they key to (Story 4.6): both are per-DEAL state, and
  /// a different card standing — or no card at all, the closed
  /// surface, a rest offer — is not that deal. `_commitView` calls
  /// this with the view it commits for every read and, since the
  /// epic-4 F2 funnel, the nine non-answer write paths too; the
  /// answer paths clear the markers at their own deal's end, and the
  /// rescue landings in `_onRescue` commit directly and manage their
  /// own markers — so a deal ended by a session close or any crossing
  /// ends them exactly as an answer does, and a fresh deal of the
  /// same item starts clean.
  void _endRescueMarkersIfDealEnded(DispenserView view) {
    if (_degradedRescueDealId != null &&
        (view is! DispenserDealt || view.card.id != _degradedRescueDealId)) {
      _degradedRescueDealId = null;
    }
    if (_autoRescueFiredForDeal != null &&
        (view is! DispenserDealt || view.card.id != _autoRescueFiredForDeal)) {
      _autoRescueFiredForDeal = null;
    }
  }

  /// The single commit owner: every resolved read (launch, resume,
  /// refresh) commits here, and since the epic-4 F2 funnel so do the
  /// nine non-answer write results, at the same position their old
  /// direct commits held. The view renders, and a completion waiting
  /// on this commit shows its ack above it — the fixed window starts
  /// (or restarts, for a later completion) at the commit, never before.
  /// Since Story 4.6 the commit is also the auto-heuristic's moment
  /// (FR-5): a committed standing card whose item is declined on
  /// ≥ 3 eligible days since its last activation fires the rescue
  /// while the card stands — the same ask the tap makes, never a
  /// second path — once per deal (the marker) and once per activation
  /// (the counter the activation row resets).
  void _commitView(DispenserView view) {
    final ackWaiting = _completionAckWaiting;
    _completionAckWaiting = false;
    setState(() {
      _view = view;
      if (ackWaiting) {
        _completionAckVisible = true;
      }
    });
    if (ackWaiting) {
      _completionAckTimer?.cancel();
      _completionAckTimer = Timer(_completionAckWindow, () {
        if (mounted) {
          // Plain removal: no motion, and nothing else on the surface
          // changes with it.
          setState(() => _completionAckVisible = false);
        }
      });
    }
    if (view is DispenserDealt &&
        view.autoRescueDue &&
        !view.rescueStep &&
        _autoRescueFiredForDeal != view.card.id) {
      // The flight guard (not the marker) holds the pre-activation
      // window: a re-commit racing the activation's landing returns
      // early inside `_onRescue`, and once the row has landed the
      // counter itself derives `autoRescueDue` false — the marker is
      // armed only by the outcome, when the landing is known.
      unawaited(_onRescue(view));
    }
    // A committed deal the markers no longer key to ends them (Story
    // 4.6): both are per-DEAL state, and a different card standing —
    // or no card at all, the closed surface, a rest offer, a failed
    // read's empty frame — is not that deal. The answer paths clear
    // them at their own deal's end; this covers the lifecycle-driven
    // changes (a crossing, a resumed foreground, a session close with
    // the card standing) so a fresh deal of the same item starts
    // clean and a re-warranted one auto-fires again.
    _endRescueMarkersIfDealEnded(view);
  }

  @override
  Widget build(BuildContext context) {
    final view = _view;
    return Scaffold(
      // The scaffold background is the theme's surfaceBase tone in both
      // modes — the empty frame is already the whole surface. The pocket
      // trigger sits above the scroll region and the footer below it as
      // Dispenser chrome, so neither scrolls away and the card between
      // them grows and scrolls on its own (UX-DR45) — until the body is
      // too short to hold that grown chrome: then the chip and footer join
      // the same scroll region, for the
      // accessibility floor outranks the pin (Story 2.3).
      body: LayoutBuilder(
        builder: (context, constraints) {
          final chromePinned =
              constraints.maxHeight >=
              _pinnedChromeBaseBodyHeight *
                  MediaQuery.textScalerOf(context).scale(1);
          final content = _viewContent(view);
          if (!chromePinned) {
            return DispenserFrame(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  PocketTriggerBand(
                    minutes: _standingPocketMinutes,
                    inFrame: true,
                    onOpenLadder: _openPocketLadder,
                    onOpenCapture: _openCapture,
                  ),
                  const SizedBox(height: Spacing.cardPadding),
                  content,
                  const SizedBox(height: Spacing.cardPadding),
                  DispenserFooterBand(
                    inFrame: true,
                    onStop: _onPause,
                    onNewProject: _openNuevoProyecto,
                  ),
                ],
              ),
            );
          }
          return Column(
            children: [
              PocketTriggerBand(
                minutes: _standingPocketMinutes,
                onOpenLadder: _openPocketLadder,
                onOpenCapture: _openCapture,
              ),
              Expanded(child: DispenserFrame(child: content)),
              DispenserFooterBand(
                onStop: _onPause,
                onNewProject: _openNuevoProyecto,
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _viewContent(DispenserView? view) {
    if (view == null) {
      return const SizedBox.shrink();
    }
    // The layer order is a pinned contract — greeting outermost, then
    // the strip, then the completion ack, then the arm — the nesting
    // the pre-split wrappers held, which the widget suites pin.
    final content = StripLayer(
      resident: view.stripResident,
      onEnergy: _onSetEnergy,
      onDismissCheckIn: _onDismissCheckIn,
      onAnswerReport: _onAnswerReport,
      onDismissReport: _onDismissReport,
      child: CompletionAck(
        visible: _completionAckVisible,
        child: switch (view) {
          DispenserDealt dealt => DealtView(
            card: dealt.card,
            onDone: () => _onDone(dealt),
            onSkip: () => _onSecondaryAction(dealt),
          ),
          DispenserRestOffer() => RestOfferView(
            onPause: _onPause,
            onExtend: _onExtend,
          ),
          DispenserClosed(:final continueOffered) => ClosedView(
            continueOffered: continueOffered,
            onExtend: _onExtend,
          ),
        },
      ),
    );
    return WarmReturnGreeting(visible: view.warmReturnDue, child: content);
  }

  /// One tap on a battery mark (Story 2.5, FR-4): `_onDeclarePocket`'s
  /// mechanics over the controller's setEnergy path — exactly one
  /// `energy_set` row, never a bundled deal — and the committed view
  /// *is* the answer: on baja the next deal narrows to instant-tier
  /// while a card in progress stays finishable; on media and llena the
  /// pool is unchanged; either way the strip is gone for the day. No
  /// haptic, no feedback of any kind — the quieter day is the answer.
  /// The same in-flight guard keeps the answer from interleaving with
  /// a `Hecho`, a skip, a declaration, a stop or a continuation at the
  /// surface; a failed write landed nothing, so the strip still stands
  /// (the frozen I/O matrix's row): the failure path runs a recovery
  /// read — the derivation re-resolves the unanswered day and the
  /// standing surface returns — blanking only if that read fails too.
  Future<void> _onSetEnergy(EnergyLevel level) async {
    if (_writeInFlight) {
      return;
    }
    _writeInFlight = true;
    final tappedAt = widget.controller.nowOf();
    // A launch or foreground refresh may still be reading the old log. Its
    // result must not overwrite this answer after it lands.
    final generation = ++_readGeneration;
    var releaseAfterRefresh = false;
    try {
      await widget.sessionSettled?.call();
      final view = await widget.controller.setEnergy(level, tappedAt: tappedAt);
      if (!mounted) {
        return;
      }
      _commitView(view);
      // The old surface remains in the render tree until this refresh's
      // frame. Keep the shared guard through it so its stale callbacks
      // cannot act.
      releaseAfterRefresh = true;
      _releaseWriteAfterRefreshFrame();
    } catch (_) {
      // The write failed and landed nothing: the strip stands and the
      // day is still unanswered — recover with a fresh read rather
      // than the family's empty frame, so the standing surface (card,
      // close or offer, strip included) returns instead of a blank.
      try {
        final view = await widget.controller.read();
        // A concurrent refresh superseded this recovery read; its
        // commit must not overwrite.
        if (mounted && generation == _readGeneration) {
          _commitView(view);
        }
      } catch (_) {
        // The recovery read failed too: the empty frame is the
        // remaining quiet story, and a real return to the foreground
        // re-reads.
        if (mounted) {
          setState(() => _view = null);
        }
      }
    } finally {
      if (!releaseAfterRefresh) {
        _writeInFlight = false;
      }
    }
  }

  /// The ✕ tap (Story 2.5, FR-4, UX-DR22): skip-for-today, and
  /// deliberately no write — the dismissal is shell state keyed by the
  /// day, so the committed view is simply the same read minus the strip.
  /// It shares the in-flight guard with a battery mark: while either
  /// action waits for lifecycle settlement, the stale alternative cannot
  /// turn a dismissal into an answer. A failed read is absorbed by the
  /// empty frame, quietly.
  Future<void> _onDismissCheckIn() async {
    if (_writeInFlight) {
      return;
    }
    _writeInFlight = true;
    final tapTime = widget.controller.nowOf();
    // A launch or foreground refresh may still be reading the old log.
    // Its result must not resurrect the strip after this dismissal
    // commits.
    _readGeneration++;
    var releaseAfterRefresh = false;
    try {
      await widget.sessionSettled?.call();
      final view = await widget.controller.dismissCheckIn(tapTime: tapTime);
      if (mounted) {
        _commitView(view);
        releaseAfterRefresh = true;
        _releaseWriteAfterRefreshFrame();
      }
    } catch (_) {
      if (mounted) {
        setState(() => _view = null);
      }
    } finally {
      if (!releaseAfterRefresh) {
        _writeInFlight = false;
      }
    }
  }

  /// One tap on a numeral (Story 2.6, SM-2, FR-4): `_onSetEnergy`'s
  /// mechanics verbatim over the controller's answerReport path —
  /// exactly one `report_answered` row carrying the asked week, never
  /// a bundled deal — and the committed view *is* the answer: the
  /// report is gone for the week and, when the day still owes it, the
  /// check-in takes the slot in this same opening. No haptic, no
  /// feedback of any kind. The same in-flight guard keeps the answer
  /// from interleaving with any other write at the surface; a failed
  /// write landed nothing, so the report still stands (the frozen I/O
  /// matrix's row): the failure path runs a recovery read — the
  /// derivation re-resolves the unanswered week and the standing
  /// surface returns — blanking only if that read fails too.
  Future<void> _onAnswerReport(int value) async {
    if (_writeInFlight) {
      return;
    }
    _writeInFlight = true;
    final tappedAt = widget.controller.nowOf();
    // A launch or foreground refresh may still be reading the old log.
    // Its result must not overwrite this answer after it lands.
    final generation = ++_readGeneration;
    var releaseAfterRefresh = false;
    try {
      await widget.sessionSettled?.call();
      final view = await widget.controller.answerReport(
        value,
        tappedAt: tappedAt,
      );
      if (!mounted) {
        return;
      }
      _commitView(view);
      // The old surface remains in the render tree until this
      // refresh's frame. Keep the shared guard through it so its
      // stale callbacks cannot act.
      releaseAfterRefresh = true;
      _releaseWriteAfterRefreshFrame();
    } catch (_) {
      // The write failed and landed nothing: the week is still
      // unanswered — recover with a fresh read rather than the
      // family's empty frame, so the standing surface (card, close or
      // offer, report included) returns instead of a blank.
      try {
        final view = await widget.controller.read();
        // A concurrent refresh superseded this recovery read; its
        // commit must not overwrite.
        if (mounted && generation == _readGeneration) {
          _commitView(view);
        }
      } catch (_) {
        // The recovery read failed too: the empty frame is the
        // remaining quiet story, and a real return to the foreground
        // re-reads.
        if (mounted) {
          setState(() => _view = null);
        }
      }
    } finally {
      if (!releaseAfterRefresh) {
        _writeInFlight = false;
      }
    }
  }

  /// The report's ✕ tap (Story 2.6, FR-4, SM-2, UX-DR22):
  /// skip-for-this-opening, and deliberately no write — the dismissal
  /// is shell state keyed by the opening, so the committed view is
  /// the same read with the check-in holding the freed slot (FR-4's
  /// deterministic handoff); the report itself returns at the next
  /// opening the derivation judges first, never styled as anything
  /// owed. It shares the in-flight guard with the numeral answers; a
  /// failed read is absorbed by the empty frame, quietly.
  Future<void> _onDismissReport() async {
    if (_writeInFlight) {
      return;
    }
    _writeInFlight = true;
    final tapTime = widget.controller.nowOf();
    // A launch or foreground refresh may still be reading the old log.
    // Its result must not resurrect the report after this dismissal
    // commits.
    _readGeneration++;
    var releaseAfterRefresh = false;
    try {
      await widget.sessionSettled?.call();
      final view = await widget.controller.dismissReport(tapTime: tapTime);
      if (mounted) {
        _commitView(view);
        releaseAfterRefresh = true;
        _releaseWriteAfterRefreshFrame();
      }
    } catch (_) {
      if (mounted) {
        setState(() => _view = null);
      }
    } finally {
      if (!releaseAfterRefresh) {
        _writeInFlight = false;
      }
    }
  }

  /// The standing declared pocket the trigger chip carries: the
  /// committed view's own fact — the open session's pocket, absent when
  /// the sitting is unbounded — defaulted to 15 (FR-8, Story 2.2). A
  /// spent or elapsed pocket keeps reading as declared: the chip states
  /// the declaration, never a remainder. The offer view carries it
  /// exactly as the dealt and closed views do — lifted extensions and
  /// all (Story 2.4).
  int get _standingPocketMinutes =>
      switch (_view) {
        DispenserDealt(:final pocketMinutes) => pocketMinutes,
        DispenserRestOffer(:final pocketMinutes) => pocketMinutes,
        DispenserClosed(:final pocketMinutes) => pocketMinutes,
        null => null,
      } ??
      defaultPocketMinutes;

  /// One tap on the Lápiz entry (Story 3.2, FR-27): Manual Capture, one
  /// hop from the Dispenser. The same rapid-tap guard as every push
  /// this surface owns — a push while another route transitions in
  /// would stack a second route — and no confirmation, no writes: the
  /// surface below stands exactly as it is until the route pops back.
  void _openCapture() {
    if (ModalRoute.of(context)?.isCurrent ?? false) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => CaptureScreen(
            controller: widget.capture,
            dictation: widget.dictation,
          ),
        ),
      );
    }
  }

  /// The `Nuevo proyecto` way-out's push (Story 2.1, NFR3, AD-26): the
  /// footer's one prose departure opens the intermediate surface that
  /// carries the `Ajustes` way-out alone — no confirmation, no writes,
  /// and the surface below stands exactly as it is until the route
  /// pops back.
  void _openNuevoProyecto() {
    // A rapid second tap during the route transition would stack
    // a second route: while another route is coming in, this one
    // is not the navigator's current route, and the push is
    // refused.
    if (ModalRoute.of(context)?.isCurrent ?? false) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => NuevoProyectoScreen(settings: widget.settings),
        ),
      );
    }
  }

  /// The quiet stepped ladder (Story 2.2): a titleless modal bottom
  /// sheet of duration pills — the `size-option` idiom — every option
  /// in the command's range, selected marking the standing pocket. The
  /// sheet wraps and scrolls at 200%; a tap pops the sheet and declares.
  /// Nothing here shows a remainder, nothing counts down, and no error
  /// state exists for a refused value to reach.
  Future<void> _openPocketLadder() {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      // The sheet's own scroll view keeps the pills whole at 200% — the
      // wrap reflows and the sheet scrolls, nothing truncates.
      builder: (_) => PocketLadderSheet(
        standingMinutes: _standingPocketMinutes,
        onSelect: _onLadderTap,
      ),
    );
  }

  /// A ladder pill's tap: the sheet pops first, then the declaration
  /// runs — the pop is immediate, the write is awaited inside
  /// [_onDeclarePocket], and the surface commits what returns.
  void _onLadderTap(int minutes) {
    Navigator.of(context).pop();
    unawaited(_onDeclarePocket(minutes));
  }

  /// One tap, no confirmation, and deliberately no feedback of any kind
  /// (Story 2.2): the declare is `_onSkip`'s mechanics over the
  /// controller's declare path — the supersede pair plus whatever deal
  /// fits, or the carried card unchanged — and the committed view *is*
  /// the answer. The same in-flight guard as an answer keeps a
  /// declaration from interleaving with a `Hecho` or a skip at the
  /// surface; a failed write is absorbed by the empty frame, quietly,
  /// and no completion-ack state is this write's to touch.
  Future<void> _onDeclarePocket(int minutes) async {
    if (_writeInFlight) {
      return;
    }
    _writeInFlight = true;
    // A launch or foreground refresh may still be reading the old log. Its
    // result must not overwrite this declaration after it lands.
    _readGeneration++;
    var releaseAfterRefresh = false;
    try {
      await widget.sessionSettled?.call();
      final view = await widget.controller.declarePocket(minutes);
      if (!mounted) {
        return;
      }
      _commitView(view);
      // The old card remains in the render tree until this refresh's frame.
      // Keep the shared guard through it so its stale callbacks cannot act.
      releaseAfterRefresh = true;
      _releaseWriteAfterRefreshFrame();
    } catch (_) {
      // The write failed: quiet and deliberate — the empty frame stands,
      // nothing surfaced, and a real return to the foreground re-reads.
      if (mounted) {
        setState(() => _view = null);
      }
    } finally {
      if (!releaseAfterRefresh) {
        _writeInFlight = false;
      }
    }
  }

  /// One tap, no confirmation, no feedback of any kind (Story 2.3,
  /// FR-9, UX-DR43): the pause is `_onDeclarePocket`'s mechanics
  /// verbatim over the controller's pause path — exactly one
  /// `session_ended` row, or nothing at all when no session is open
  /// (the accepted quiet no-op) — and the committed warm close *is* the
  /// stop's whole presentation, silent by construction: no toast, no
  /// banner, no announcement, and the chip returns to its 15 default as
  /// its own data does. The same in-flight guard as an answer keeps the
  /// stop from interleaving with a `Hecho`, a skip or a declaration at
  /// the surface; a launch or foreground read still reading the old log
  /// cannot overwrite this close after it lands (the generation bump).
  /// A failed write is absorbed by the empty frame, quietly, and no
  /// completion-ack state is this write's to touch.
  Future<void> _onPause() async {
    if (_writeInFlight) {
      return;
    }
    _writeInFlight = true;
    // A launch or foreground refresh may still be reading the old log. Its
    // result must not overwrite this pause after it lands.
    _readGeneration++;
    var releaseAfterRefresh = false;
    try {
      await widget.sessionSettled?.call();
      final view = await widget.controller.pause();
      if (!mounted) {
        return;
      }
      _commitView(view);
      // The old surface remains in the render tree until this refresh's
      // frame. Keep the shared guard through it so its stale callbacks
      // cannot act.
      releaseAfterRefresh = true;
      _releaseWriteAfterRefreshFrame();
    } catch (_) {
      // The write failed: quiet and deliberate — the empty frame stands,
      // nothing surfaced, and a real return to the foreground re-reads.
      if (mounted) {
        setState(() => _view = null);
      }
    } finally {
      if (!releaseAfterRefresh) {
        _writeInFlight = false;
      }
    }
  }

  /// One tap, no confirmation, and deliberately no feedback of any kind
  /// (Story 2.4, FR-10): `_onPause`'s mechanics verbatim over the
  /// controller's extend path — exactly one `session_extended` row, or
  /// nothing at all when no session is open (the accepted quiet no-op)
  /// — plus the bundled next `card_dealt` when the lift unblocks a
  /// sitting with no unanswered card (close-continue, AD-3). The
  /// committed view *is* the answer: the standing card returns, never
  /// re-dealt; the newly minted deal shows; or the close stands as it
  /// did. The extension is the checkpoint's silent secondary: never
  /// highlighted, never animated, no haptic, nothing celebration-shaped.
  /// The same in-flight guard as an answer keeps the continue from
  /// interleaving with a `Hecho`, a skip, a declaration or a stop at
  /// the surface; a launch or foreground read still reading the old log
  /// cannot overwrite this extension after it lands (the generation
  /// bump). A failed write is absorbed by the empty frame, quietly, and
  /// no completion-ack state is this write's to touch.
  Future<void> _onExtend() async {
    if (_writeInFlight) {
      return;
    }
    _writeInFlight = true;
    // A launch or foreground refresh may still be reading the old log. Its
    // result must not overwrite this extension after it lands.
    _readGeneration++;
    var releaseAfterRefresh = false;
    try {
      await widget.sessionSettled?.call();
      final view = await widget.controller.extend();
      if (!mounted) {
        return;
      }
      _commitView(view);
      // The old surface remains in the render tree until this refresh's
      // frame. Keep the shared guard through it so its stale callbacks
      // cannot act.
      releaseAfterRefresh = true;
      _releaseWriteAfterRefreshFrame();
    } catch (_) {
      // The write failed: quiet and deliberate — the empty frame stands,
      // nothing surfaced, and a real return to the foreground re-reads.
      if (mounted) {
        setState(() => _view = null);
      }
    } finally {
      if (!releaseAfterRefresh) {
        _writeInFlight = false;
      }
    }
  }
}

// The Dispenser surface (Stories 1.8–1.9, UX-DR14/UX-DR41): the app's
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
// and a Hecho answer refreshes the surface between foregrounds.
//
// The Hecho tap (Story 1.9): the light haptic acknowledges the act
// immediately — never awaited, never the sole signal — then the write is
// awaited (`card_done` + the bundled next `card_dealt`), the surface
// refreshes from the answered log, and «¡Buen trabajo!» shows for a
// fixed window above whatever view commits next (UX-DR38/39/51). The
// completed card exits the tree entirely via the refresh clear — removal,
// deliberately no motion — and a failed write is absorbed by the empty
// frame, quietly.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../dispenser/dispenser_controller.dart';
import '../../strings/app_strings.dart';
import '../tokens.dart';
import 'task_card.dart';

/// The card's width bound on wide grounds. A layout bound, not a gap: no
/// DESIGN token exists for it, and the tokenized side rule
/// (`Spacing.screenMargin`) stays in force below it.
const double _cardMaxWidth = 480;

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
  });

  final DispenserController controller;
  final Future<void> Function()? sessionSettled;

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

  /// Whether a completion's write is between its tap and its settle —
  /// the synchronous in-flight guard. A completion already in flight
  /// owns the surface: a rapid second tap would only fire a second
  /// haptic and a second refresh for a write the core guard no-ops.
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
    HapticFeedback.lightImpact();
    try {
      await widget.controller.complete(dealt);
      if (!mounted) {
        return;
      }
      _completionAckWaiting = true;
      _refresh();
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
      _writeInFlight = false;
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

  /// Commits a resolved read: the view renders, and a completion waiting
  /// on this commit shows its ack above it — the fixed window starts
  /// (or restarts, for a later completion) at the commit, never before.
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
  }

  @override
  Widget build(BuildContext context) {
    final view = _view;
    return Scaffold(
      // The scaffold background is the theme's surfaceBase tone in both
      // modes — the empty frame is already the whole surface.
      body: switch (view) {
        null => const SizedBox.shrink(),
        DispenserDealt dealt => _frame(
          _withCompletionAck(
            context,
            TaskCard(card: dealt.card, onDone: () => _onDone(dealt)),
          ),
        ),
        DispenserClosed() => _frame(
          _withCompletionAck(context, _closeText(context)),
        ),
      },
    );
  }

  /// The completion acknowledgement (UX-DR51): «¡Buen trabajo!» in the
  /// quiet support register, centered, inside the scroll column above
  /// the committed view — the next card or the warm close string — for
  /// its fixed window. No glyph, no fill, no motion; identical every
  /// time, and it closes rather than opening a door to another.
  Widget _withCompletionAck(BuildContext context, Widget view) {
    if (!_completionAckVisible) {
      return view;
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          AppStrings.of(context).completionAcknowledgement,
          // bodySmall is the wired support role (theme.dart).
          style: Theme.of(context).textTheme.bodySmall,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: Spacing.actionGap),
        view,
      ],
    );
  }

  /// The warm close (FR-3): `poolExhaustedClose` verbatim, centered and
  /// quiet — the secondary action's role and ink, never an error and
  /// never styled as absence or debt.
  Widget _closeText(BuildContext context) {
    return Text(
      AppStrings.of(context).poolExhaustedClose,
      // bodyMedium is the wired action-secondary role (theme.dart).
      style: Theme.of(context).textTheme.bodyMedium,
      textAlign: TextAlign.center,
    );
  }

  /// The one frame every resolved state shares: scroll when the content
  /// outgrows the viewport, center it in the remaining flex otherwise,
  /// with the 48dp minimum air inside the screen margins and the
  /// max-width bound. SafeArea first, so scrolled content never renders
  /// under the status bar or a cutout — the minimum air lives inside it.
  Widget _frame(Widget child) {
    return SafeArea(
      child: LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: Spacing.screenMargin,
                // The air around the card: minimum 48 plus flex, carried
                // here rather than in a token precisely because a token
                // reads as a fixed value (UX-DR14).
                vertical: Spacing.touchTargetMin,
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: _cardMaxWidth),
                  child: child,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

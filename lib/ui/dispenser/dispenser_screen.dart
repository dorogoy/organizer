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
// The footer (Story 2.1, UX-DR25): `Nuevo proyecto` sits bottom-centred
// as the surface's one prose departure — ink-secondary text, 48dp
// opaque target, no glyph, no pastel mass, nothing animated — pinned
// as chrome below the scroll region. It opens the intermediate surface
// that carries the `Ajustes` way-out alone (NFR3, AD-26).
//
// The pocket trigger (Story 2.2, FR-8, UX-DR18): a `duration-chip` pill
// pinned top-centred as chrome above the scroll region — above the card
// on the dealt surface, standing alone on the warm close — carrying
// `Tengo {minutes} minutos ahora`, the standing declared pocket while a
// pocketed session is open, else 15. One tap opens a quiet, titleless
// ladder sheet of stepped duration pills; choosing one declares the
// pocket and the surface commits whatever the log now makes true — the
// carried card, a pocket-bounded deal, or the same warm close as pool
// exhaustion. No countdown, no remaining minutes, no new session state,
// and no error surface anywhere on this path.
//
// The stop control (Story 2.3, FR-9, UX-DR43): `Quiero parar` stands in
// the footer band on BOTH the dealt and closed views — never disabled,
// never suggested, one tap, any moment, any reason. The tap is
// `_onDeclarePocket`'s mechanics verbatim over the controller's pause
// path — exactly one `session_ended` row, no payload — and the committed
// view is the standing warm close with the trigger chip back at its 15
// default: the close is the stop's whole presentation, silent by
// construction. A tap with nothing open appends nothing — the accepted
// quiet no-op. The footer band wraps (never truncates) at 200%, and on
// a body too short to hold the pinned chrome the chip and band join the
// scroll region together: the accessibility floor outranks UX-DR45's pin.
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
// The ambient strip (Stories 2.5–2.6, FR-4, UX-DR20/22): below the
// view, inside the scroll region, whenever the read's own fact says a
// resident is showing — the surface switches on which. The check-in:
// the question verbatim, three battery marks, the ✕; a tap on any
// mark answers the day (one write, the strip gone for the day, baja
// narrowing the next deal only). The weekly self-report (SM-2):
// hairlined, the question verbatim, the 1–5 numerals, the end labels,
// the ✕; a tap on any numeral answers the asked week (one write
// carrying the week, the report gone for the week), and the ✕
// dismisses with no write, hidden for the rest of the opening only —
// never for the week. Either resolution hands the slot to the
// check-in in the same opening when the day still owes it (FR-4's
// deterministic handoff). The strip inherits the short-surface floor —
// it grows and scrolls at 200%, nothing truncated, every target at or
// above 48dp — and after it leaves, nothing on this surface displays
// the level: the narrower deal is the display (AD-4, UX-DR41).
//
// The warm return (Story 2.7, FR-6, AD-24): when the read's own fact
// says the opening arrives 48 h or more after the latest contact that
// preceded it, the fixed greeting «Siempre a tu disposición» stands
// above the committed view — the ack's register, no glyph, no fill, no
// motion — for the whole opening, on every variant. No timer, no
// dismissal, no stored state: the derivation alone, so the greeting
// persists through the session and is gone at the next opening inside
// 48 h, and nothing on the surface counts the days away (they are not
// representable).
import 'dart:async';

import 'package:core/derive/strip.dart';
import 'package:core/energy/energy.dart';
import 'package:core/settings/settings.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../dispenser/dispenser_controller.dart';
import '../../settings/settings_controller.dart';
import '../../strings/app_strings.dart';
import '../settings/nuevo_proyecto_screen.dart';
import '../tokens.dart';
import 'ambient_strip.dart';
import 'duration_chip.dart';
import 'task_card.dart';

/// The card's width bound on wide grounds. A layout bound, not a gap: no
/// DESIGN token exists for it, and the tokenized side rule
/// (`Spacing.screenMargin`) stays in force below it.
const double _cardMaxWidth = 480;

/// The short-surface floor's base decision height (Story 2.3, UX-DR45 vs
/// NFR6). It scales with the user's text scale: at 200%, the chrome stays
/// pinned from 320dp upward; below that, both the chip and footer join one
/// scroll region. Moving all chrome together prevents a viewport shorter
/// than the grown chip itself from overflowing. The 320×220 @200% pin
/// guards this floor without making 320 a fixed answer at every scale.
const double _pinnedChromeBaseBodyHeight = 160;

/// The ladder's stepped options (Story 2.2): every offered value is
/// inside the pocket's command range, so out-of-range is unreachable
/// from the surface. Swapping the list changes nothing else — the log
/// payload and the command contract are unaffected.
const List<int> pocketLadderOptions = [5, 10, 15, 20, 25, 30, 45, 60];

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
  });

  final DispenserController controller;
  final Future<void> Function()? sessionSettled;

  /// The Settings seam (Story 2.1): main constructs it over the same
  /// store and hands it down through the way-out chain — the footer
  /// here, the `Nuevo proyecto` carrier, the Settings list. Absent (the
  /// test seam), the footer renders and opens the carrier with no
  /// controller behind it.
  final SettingsController? settings;

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
          final content = _viewContent(context, view);
          if (!chromePinned) {
            return _frame(
              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _pocketTrigger(context, inFrame: true),
                  const SizedBox(height: Spacing.cardPadding),
                  content,
                  const SizedBox(height: Spacing.cardPadding),
                  _footerActions(context),
                ],
              ),
            );
          }
          return Column(
            children: [
              _pocketTrigger(context),
              Expanded(child: _frame(content)),
              _pinnedFooterBand(context),
            ],
          );
        },
      ),
    );
  }

  Widget _viewContent(BuildContext context, DispenserView? view) {
    final content = switch (view) {
      null => const SizedBox.shrink(),
      DispenserDealt dealt => _withAmbientStrip(
        context,
        view,
        _withCompletionAck(
          context,
          TaskCard(
            card: dealt.card,
            onDone: () => _onDone(dealt),
            onSkip: () => _onSkip(dealt),
          ),
        ),
      ),
      DispenserRestOffer() => _withAmbientStrip(
        context,
        view,
        _withCompletionAck(context, _restOffer(context)),
      ),
      DispenserClosed(:final continueOffered) => _withAmbientStrip(
        context,
        view,
        _withCompletionAck(
          context,
          continueOffered ? _closeWithContinue(context) : _closeText(context),
        ),
      ),
    };
    if (view == null || !view.warmReturnDue) {
      return content;
    }
    return _withWarmReturnGreeting(context, content);
  }

  /// The view with the ambient strip below it (Stories 2.5–2.6,
  /// UX-DR22): inside the frame's scroll region, beneath whatever the
  /// read committed — the strip's own resident on the view decides,
  /// never the surface's memory, and the widget switches on which
  /// resident it is. Nothing else moves: the card's air, the ack line
  /// and the pinned chrome keep their geometry, and the strip grows
  /// into the same scroll at 200%.
  Widget _withAmbientStrip(
    BuildContext context,
    DispenserView view,
    Widget content,
  ) {
    final resident = view.stripResident;
    if (resident == null) {
      return content;
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        content,
        const SizedBox(height: Spacing.cardPadding),
        switch (resident) {
          StripResident.energyCheckIn => AmbientStrip(
            onEnergy: _onSetEnergy,
            onDismiss: _onDismissCheckIn,
          ),
          StripResident.weeklySelfReport => SelfReportStrip(
            onAnswer: _onAnswerReport,
            onDismiss: _onDismissReport,
          ),
          // The four later residents are never eligible in this
          // build — their stories' data does not exist yet — so the
          // read can never hand this switch one.
          StripResident.firstRunCuration ||
          StripResident.quarantineFollowUp ||
          StripResident.seasonalSuggestion ||
          StripResident.snowball => content,
        },
      ],
    );
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
    _readGeneration++;
    var releaseAfterRefresh = false;
    try {
      await widget.sessionSettled?.call();
      final view = await widget.controller.setEnergy(level, tappedAt: tappedAt);
      if (!mounted) {
        return;
      }
      setState(() => _view = view);
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
        if (mounted) {
          setState(() => _view = view);
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
        setState(() => _view = view);
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
    _readGeneration++;
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
      setState(() => _view = view);
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
        if (mounted) {
          setState(() => _view = view);
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
        setState(() => _view = view);
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

  /// The pocket trigger (Story 2.2, FR-8, UX-DR18): the duration-chip
  /// pill top-centred above the card — and standing on the warm close
  /// too, because a spent pocket is declared until superseded. The
  /// carried minutes are log-derived data, never session state held in
  /// memory as truth.
  Widget _pocketTrigger(BuildContext context, {bool inFrame = false}) {
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: Spacing.spacingBase),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: inFrame ? 0 : Spacing.screenMargin,
          ),
          child: Center(
            child: PocketTriggerChip(
              minutes: _standingPocketMinutes,
              onTap: _openPocketLadder,
            ),
          ),
        ),
      ),
    );
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
      builder: (sheetContext) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(Spacing.cardPadding),
          child: Wrap(
            spacing: Spacing.actionGap,
            runSpacing: Spacing.actionGap,
            children: [
              for (final minutes in pocketLadderOptions)
                _PocketLadderOption(
                  minutes: minutes,
                  selected: _standingPocketMinutes == minutes,
                  onTap: () => _onLadderTap(minutes),
                ),
            ],
          ),
        ),
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
      setState(() => _view = view);
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
      setState(() => _view = view);
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
      setState(() => _view = view);
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

  /// The footer band's two prose controls (Stories 2.1, 2.3, UX-DR25,
  /// UX-DR43): `Quiero parar` beside `Nuevo proyecto`, both through the
  /// `action-secondary` grammar — ink-secondary text, 48dp opaque
  /// targets, no glyph, no pastel mass, nothing animated. The band
  /// wraps; nothing in it ever truncates.
  Widget _footerActions(BuildContext context) {
    final strings = AppStrings.of(context);
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: Spacing.actionGap,
      runSpacing: Spacing.spacingBase,
      children: [
        SecondaryTextAction(label: strings.actionStop, onTap: _onPause),
        SecondaryTextAction(
          label: strings.newProjectLink,
          onTap: () {
            // A rapid second tap during the route transition would stack
            // a second route: while another route is coming in, this one
            // is not the navigator's current route, and the push is
            // refused.
            if (ModalRoute.of(context)?.isCurrent ?? false) {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) =>
                      NuevoProyectoScreen(settings: widget.settings),
                ),
              );
            }
          },
        ),
      ],
    );
  }

  /// The band as pinned chrome below the scroll region (UX-DR45) — the
  /// common surface. A body below the text-scaled chrome floor never
  /// reaches here: both chrome controls join the scroll region instead.
  Widget _pinnedFooterBand(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: Spacing.screenMargin),
        child: _footerActions(context),
      ),
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

  /// The Warm Return greeting (Story 2.7, FR-6, AD-24): the fixed
  /// string in the completion ack's register — centered, `bodySmall`,
  /// one `Spacing.actionGap` above the committed view — standing for
  /// the whole opening on every variant. No glyph, no fill, no motion
  /// and no dismissal control; no timer owns it (the 2-s
  /// `_withCompletionAck` window is not this), and no state exists
  /// anywhere: the read's own `warmReturnDue` fact decides, so the
  /// greeting persists through the session by derivation and is gone
  /// at the next opening inside 48 h. Nothing here counts the days
  /// away — they are not representable.
  Widget _withWarmReturnGreeting(BuildContext context, Widget view) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          AppStrings.of(context).warmReturnGreeting,
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

  /// The permission-to-rest offer (Story 2.4, FR-10, UX-DR44/51): the
  /// checkpoint's two actions and nothing else. `Nada más por el
  /// momento` is the primary permission to stop, in the Done button's
  /// register, running the same one-tap pause write; `Quiero seguir` is
  /// the silent secondary — plain prose in the unsplit secondary
  /// grammar, never filled, never emphasized, never animated, no
  /// haptic. No continuation question exists anywhere, and nothing here
  /// counts anything: no number that would have been higher if the user
  /// had kept going (UJ-1).
  Widget _restOffer(BuildContext context) {
    final strings = AppStrings.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        HechoButton(label: strings.checkpointStop, onTap: _onPause),
        const SizedBox(height: Spacing.actionGap),
        SecondaryTextAction(
          label: strings.checkpointContinue,
          onTap: _onExtend,
        ),
      ],
    );
  }

  /// The close as the offer (Story 2.4, UJ-1): the same warm close
  /// string with the checkpoint's silent secondary beneath it — offered
  /// only while one more interval could truthfully reach beyond the
  /// read and the pool could deal if the pocket had room (the core's
  /// window and probe decide). A pool-exhausted or long-elapsed close
  /// carries nothing — the chip is the way back in, never a dead
  /// action. The same `Quiero seguir`, the same extension, no second
  /// surface and no manufactured state between them.
  Widget _closeWithContinue(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _closeText(context),
        const SizedBox(height: Spacing.actionGap),
        SecondaryTextAction(
          label: AppStrings.of(context).checkpointContinue,
          onTap: _onExtend,
        ),
      ],
    );
  }

  /// The one frame every resolved state shares: scroll when the content
  /// outgrows the viewport, center it in the remaining flex otherwise,
  /// with the 48dp minimum air inside the screen margins and the
  /// max-width bound. SafeArea first, so scrolled content never renders
  /// under the status bar or a cutout — the minimum air lives inside it.
  Widget _frame(Widget child) {
    final content = Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: _cardMaxWidth),
        child: child,
      ),
    );
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
              child: content,
            ),
          ),
        ),
      ),
    );
  }
}

/// One stepped ladder pill (Story 2.2, the `size-option` idiom): a
/// duration pill — selected fills `colorScheme.primary` (the theme's
/// accent-soft mapping, the same pastel `DurationChip` fills), unselected
/// sits raised with a 1px hairline edge — ink-primary in the duration
/// role on both, `rounded.full`, 48dp minimum, never a glyph. The label
/// is the minutes themselves through the duration format; context is the
/// chip just tapped, so the sheet carries no title and no internal name
/// renders.
class _PocketLadderOption extends StatelessWidget {
  const _PocketLadderOption({
    required this.minutes,
    required this.selected,
    this.onTap,
  });

  final int minutes;

  final bool selected;

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: selected
          ? theme.colorScheme.primary
          : theme.colorScheme.surfaceContainerHighest,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Radii.radiusFull),
        side: selected
            ? BorderSide.none
            : BorderSide(color: theme.colorScheme.outline, width: 1),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        // Absent, the tap stays an accepted no-op — a null onTap would
        // render a disabled control instead.
        onTap: onTap ?? () {},
        child: Semantics(
          // The affordance reaches screen readers as a button carrying
          // selection state, never as a different visual grammar: the
          // spoken label is the minutes value the pill's own text
          // already carries.
          button: true,
          selected: selected,
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
                  durationLabel(minutes * 60, AppStrings.of(context)),
                  // titleSmall is the wired duration role (theme.dart).
                  style: theme.textTheme.titleSmall,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

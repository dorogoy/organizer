// The Dispenser's all-arm layers (Stories 2.5–2.7, FR-4/FR-6, and the
// completion ack of UX-DR38/39/51): the wrappers that stand around
// whatever the read commits — the ambient strip below the view, the
// Warm Return greeting above it, the completion acknowledgement above
// the arm it wraps. Extracted from `dispenser_screen.dart`
// (`_withAmbientStrip`, `_withCompletionAck` and
// `_withWarmReturnGreeting`), moved verbatim — the rendered output is
// unchanged.
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
import 'package:core/derive/strip.dart';
import 'package:core/energy/energy.dart';
import 'package:flutter/material.dart';

import '../../strings/app_strings.dart';
import '../tokens.dart';
import 'ambient_strip.dart';

/// The view with the ambient strip below it (Stories 2.5–2.6,
/// UX-DR22): inside the frame's scroll region, beneath whatever the
/// read committed — the strip's own resident on the view decides,
/// never the surface's memory, and the widget switches on which
/// resident it is. Nothing else moves: the card's air, the ack line
/// and the pinned chrome keep their geometry, and the strip grows
/// into the same scroll at 200%.
class StripLayer extends StatelessWidget {
  const StripLayer({
    super.key,
    required this.resident,
    required this.onEnergy,
    this.onDismissCheckIn,
    required this.onAnswerReport,
    this.onDismissReport,
    required this.child,
  });

  /// The ambient strip's resident this layer holds — the read's own
  /// fact, never the surface's memory. Null holds nothing: [child]
  /// stands alone.
  final StripResident? resident;

  /// The check-in's answer path: the screen's energy handler, one
  /// write per tap.
  final void Function(EnergyLevel level) onEnergy;

  /// The check-in's ✕ path: the screen's dismissal handler, never a
  /// write.
  final VoidCallback? onDismissCheckIn;

  /// The report's answer path: the screen's report handler, one write
  /// carrying the asked week.
  final void Function(int value) onAnswerReport;

  /// The report's ✕ path: the screen's dismissal handler, never a
  /// write.
  final VoidCallback? onDismissReport;

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final resident = this.resident;
    if (resident == null) {
      return child;
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        child,
        const SizedBox(height: Spacing.cardPadding),
        switch (resident) {
          StripResident.energyCheckIn => AmbientStrip(
            onEnergy: onEnergy,
            onDismiss: onDismissCheckIn,
          ),
          StripResident.weeklySelfReport => SelfReportStrip(
            onAnswer: onAnswerReport,
            onDismiss: onDismissReport,
          ),
          // The four later residents are never eligible in this
          // build — their stories' data does not exist yet — so the
          // read can never hand this switch one.
          StripResident.firstRunCuration ||
          StripResident.quarantineFollowUp ||
          StripResident.seasonalSuggestion ||
          StripResident.snowball => child,
        },
      ],
    );
  }
}

/// The completion acknowledgement (UX-DR51): «¡Buen trabajo!» in the
/// quiet support register, centered, inside the scroll column above
/// the committed view — the next card or the warm close string — for
/// its fixed window. No glyph, no fill, no motion; identical every
/// time, and it closes rather than opening a door to another. It wraps
/// every arm of the content switch, which is why it lives here with
/// the all-arm layers rather than beside the dealt card it most often
/// crowns.
class CompletionAck extends StatelessWidget {
  const CompletionAck({super.key, required this.visible, required this.child});

  /// Whether the committed view below carries the ack line — the
  /// screen's window flag, read here as data and never owned here.
  final bool visible;

  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!visible) {
      return child;
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
        child,
      ],
    );
  }
}

/// The Warm Return greeting (Story 2.7, FR-6, AD-24): the fixed
/// string in the completion ack's register — centered, `bodySmall`,
/// one `Spacing.actionGap` above the committed view — standing for
/// the whole opening on every variant. No glyph, no fill, no motion
/// and no dismissal control; no timer owns it (the 2-s
/// `CompletionAck` window is not this), and no state exists
/// anywhere: the read's own `warmReturnDue` fact decides — passed
/// here as [visible], read as data and never owned — so the greeting
/// persists through the session by derivation and is gone at the
/// next opening inside 48 h. Nothing here counts the days away —
/// they are not representable.
class WarmReturnGreeting extends StatelessWidget {
  const WarmReturnGreeting({
    super.key,
    required this.visible,
    required this.child,
  });

  /// Whether this opening carries the greeting — the read's own
  /// derivation; absent it, [child] stands alone.
  final bool visible;

  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!visible) {
      return child;
    }
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
        child,
      ],
    );
  }
}

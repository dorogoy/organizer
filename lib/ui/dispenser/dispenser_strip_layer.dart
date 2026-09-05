// The Dispenser's ambient strip layer (Stories 2.5–2.6, FR-4,
// UX-DR20/22): below the
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
import 'package:core/derive/strip.dart';
import 'package:core/energy/energy.dart';
import 'package:flutter/material.dart';

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

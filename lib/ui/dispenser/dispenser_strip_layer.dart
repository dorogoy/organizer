// The Dispenser's ambient strip layer (Stories 2.5–2.6, 5.12, FR-4,
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
// never for the week. The once-ever first-run curation offer
// (Story 5.12, FR-31): `Ajustar grupos de tareas` as one whole-
// sentence button plus the ✕, bare chrome; the tap consumes and
// pushes the E1 surface (no write), the ✕ dismisses (no write), and
// the offer never returns — its once-ever fact is derived from the
// log's own history, never stored. Either resolution hands the slot
// to the displaced instruments in the same opening when they still
// owe it (FR-4's deterministic handoff). The once-per-season
// suggestion (Story 5.13, FR-15): the sentence naming the shown
// dormant Epic as one whole-sentence button plus the ✕, bare chrome;
// the tap ACTIVATES the Epic (one `epic_activated` row — the FR-23
// snowball precedent, and the resident is gone by derivation), the ✕
// writes one `suggestion_dismissed` row naming the shown project
// (the season's whole rate limit — per-project, and every other
// derivation unchanged on a decline). Either of its resolutions
// hands the slot the same way. The blind six-month quarantine
// follow-up (Story 6.6, FR-21): `quarantineFollowUpCopy` as one
// static date-anchored sentence plus the ✕, hairlined chrome (it
// persists across openings within its due day); there is no accept
// path — acting on the physical box is the user's — and the ✕ writes
// nothing at all, the day-window derivation never re-offering it on
// any later day. The strip inherits the
// short-surface floor — it grows and scrolls at 200%, nothing
// truncated, every target at or above 48dp — and after it leaves,
// nothing on this surface displays the level: the narrower deal is
// the display (AD-4, UX-DR41).
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
    this.seasonalSuggestion,
    required this.onEnergy,
    this.onDismissCheckIn,
    required this.onAnswerReport,
    this.onDismissReport,
    required this.onAcceptCuration,
    this.onDismissCuration,
    required this.onAcceptSuggestion,
    this.onDismissSuggestion,
    this.onDismissQuarantineFollowUp,
    required this.child,
  });

  /// The ambient strip's resident this layer holds — the read's own
  /// fact, never the surface's memory. Null holds nothing: [child]
  /// stands alone.
  final StripResident? resident;

  /// The shown seasonal suggestion's own record (Story 5.13, FR-15) —
  /// the read's own fact beside the resident, non-null exactly when
  /// [resident] is [StripResident.seasonalSuggestion]: the sentence
  /// names the shown Epic's description, and both paths act on the
  /// project the user was shown, never one re-derived at tap time.
  final StripSuggestion? seasonalSuggestion;

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

  /// The once-ever curation offer's accept path (Story 5.12): the
  /// screen's consume-then-push handler, never a write.
  final VoidCallback onAcceptCuration;

  /// The curation offer's ✕ path (Story 5.12): the screen's dismissal
  /// handler, never a write.
  final VoidCallback? onDismissCuration;

  /// The seasonal suggestion's accept path (Story 5.13): the screen's
  /// activation handler — one `epic_activated` row per tap.
  final VoidCallback onAcceptSuggestion;

  /// The seasonal suggestion's ✕ path (Story 5.13): the screen's
  /// dismissal handler — one `suggestion_dismissed` row per tap.
  final VoidCallback? onDismissSuggestion;

  /// The quarantine follow-up's ✕ path (Story 6.6, FR-21): the
  /// screen's dismissal handler, never a write — shell state for the
  /// due day, and the day-window derivation closes the resident on
  /// its own tomorrow.
  final VoidCallback? onDismissQuarantineFollowUp;

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
          StripResident.firstRunCuration => CurationOfferStrip(
            onAccept: onAcceptCuration,
            onDismiss: onDismissCuration,
          ),
          StripResident.seasonalSuggestion => SeasonalSuggestionStrip(
            suggestion: seasonalSuggestion,
            onAccept: onAcceptSuggestion,
            onDismiss: onDismissSuggestion,
          ),
          // The blind six-month follow-up (Story 6.6, FR-21): the
          // one static date-anchored sentence plus the ✕ — no accept
          // path, and the ✕ writes nothing at all.
          StripResident.quarantineFollowUp => QuarantineFollowUpStrip(
            onDismiss: onDismissQuarantineFollowUp,
          ),
          // The snowball resident is never eligible in this build —
          // its story's data does not exist yet — so the read can
          // never hand this switch one.
          StripResident.snowball => child,
        },
      ],
    );
  }
}

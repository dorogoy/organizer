// The Dispenser's dealt view arm (FR-1, Stories 1.9–1.10): the one
// Micro-task card's wiring, nothing else — the completion
// acknowledgement that can stand above the arm lives with the all-arm
// layers (`dispenser_view_layers.dart`). Extracted from
// `dispenser_screen.dart` (the `DispenserDealt` case's TaskCard
// construction), moved verbatim — the rendered output is unchanged.
import 'package:core/weave/weave.dart';
// The core's Card is the domain object this surface renders; Material's
// widget of the same name stays out of scope here (task_card.dart's
// own arrangement).
import 'package:flutter/material.dart' hide Card;

import 'task_card.dart';

/// The dealt arm of the Dispenser's content switch (FR-1): exactly one
/// Micro-task, nothing else — the TaskCard wiring. [onDone] threads
/// the Hecho tap through to the screen's completion path (Story 1.9)
/// and [onSkip] the one control's tap to its resolution (Stories 1.10
/// and 4.6, FR-3 + FR-5); absent either, the tap stays the leaf
/// control's own accepted no-op.
class DealtView extends StatelessWidget {
  const DealtView({super.key, required this.card, this.onDone, this.onSkip});

  final Card card;

  final VoidCallback? onDone;

  final VoidCallback? onSkip;

  @override
  Widget build(BuildContext context) {
    return TaskCard(card: card, onDone: onDone, onSkip: onSkip);
  }
}

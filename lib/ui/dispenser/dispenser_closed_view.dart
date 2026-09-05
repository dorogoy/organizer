// The Dispenser's closed view arm (FR-3, Story 2.4): the warm close the
// read commits when the pool is spent — and, exactly when the close is
// the offer, the checkpoint's silent continue beneath it. Extracted from
// `dispenser_screen.dart` (the `DispenserClosed` case's `_closeText` and
// `_closeWithContinue`), moved verbatim — the rendered output is
// unchanged.
import 'package:flutter/material.dart';

import '../../strings/app_strings.dart';
import '../tokens.dart';
import 'task_card.dart';

/// The closed arm of the Dispenser's content switch (FR-3, Story 2.4):
/// the warm close, and beneath it the checkpoint's silent secondary
/// exactly when [continueOffered] says the close is the offer.
/// [onExtend] threads the continue's tap through to the screen's
/// extension path; absent, the tap stays the accepted no-op (the leaf
/// control's own default).
class ClosedView extends StatelessWidget {
  const ClosedView({super.key, required this.continueOffered, this.onExtend});

  final bool continueOffered;

  final VoidCallback? onExtend;

  @override
  Widget build(BuildContext context) {
    return continueOffered ? _closeWithContinue(context) : _closeText(context);
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
          onTap: onExtend,
        ),
      ],
    );
  }
}

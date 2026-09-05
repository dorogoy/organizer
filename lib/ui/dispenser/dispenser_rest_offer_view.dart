// The Dispenser's rest-offer view arm (Story 2.4, FR-10, UX-DR44/51):
// the checkpoint's two actions and nothing else — the permission to
// stop in the Done button's register, the silent continue beneath it.
// Extracted from `dispenser_screen.dart` (the `DispenserRestOffer`
// case's `_restOffer`), moved verbatim — the rendered output is
// unchanged.
import 'package:flutter/material.dart';

import '../../strings/app_strings.dart';
import '../tokens.dart';
import 'task_card.dart';

/// The permission-to-rest offer (Story 2.4, FR-10, UX-DR44/51): the
/// checkpoint's two actions and nothing else. `Nada más por el
/// momento` is the primary permission to stop, in the Done button's
/// register, running the same one-tap pause write; `Quiero seguir` is
/// the silent secondary — plain prose in the unsplit secondary
/// grammar, never filled, never emphasized, never animated, no
/// haptic. No continuation question exists anywhere, and nothing here
/// counts anything: no number that would have been higher if the user
/// had kept going (UJ-1).
///
/// [onPause] threads the stop's tap through to the screen's pause
/// path and [onExtend] the continue's tap to its extension path;
/// absent either, the tap stays the accepted no-op (the leaf
/// control's own default).
class RestOfferView extends StatelessWidget {
  const RestOfferView({super.key, this.onPause, this.onExtend});

  final VoidCallback? onPause;

  final VoidCallback? onExtend;

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        HechoButton(label: strings.checkpointStop, onTap: onPause),
        const SizedBox(height: Spacing.actionGap),
        SecondaryTextAction(label: strings.checkpointContinue, onTap: onExtend),
      ],
    );
  }
}

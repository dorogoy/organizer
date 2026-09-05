// The Dispenser's shared frame (Stories 1.8-1.10, UX-DR14): the scroll,
// center, side-margin and max-width boundary around every resolved view.
// Extracted from `_frame` in `dispenser_screen.dart`; the State keeps
// the decision about which content enters it.
import 'package:flutter/material.dart';

import '../tokens.dart';

/// The card's width bound on wide grounds. A layout bound, not a gap: no
/// DESIGN token exists for it, and the tokenized side rule
/// (`Spacing.screenMargin`) stays in force below it.
const double _cardMaxWidth = 480;

/// The one frame every resolved state shares: scroll when the content
/// outgrows the viewport, center it in the remaining flex otherwise,
/// with the 48dp minimum air inside the screen margins and the
/// max-width bound. SafeArea first, so scrolled content never renders
/// under the status bar or a cutout - the minimum air lives inside it.
class DispenserFrame extends StatelessWidget {
  const DispenserFrame({super.key, required this.child});

  /// The resolved content this frame centers, bounds and scrolls.
  final Widget child;

  @override
  Widget build(BuildContext context) {
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

// The Dispenser's all-arm view layers (Stories 2.7, FR-6, AD-24, and
// UX-DR51): the completion acknowledgement and Warm Return greeting
// that wrap whatever the read commits. Extracted from
// `dispenser_screen.dart` (`_withCompletionAck` and
// `_withWarmReturnGreeting`), moved verbatim in behavior; the State
// still owns the flags and their timer.
import 'package:flutter/material.dart';

import '../../strings/app_strings.dart';
import '../tokens.dart';

/// The completion acknowledgement (UX-DR51): "Buen trabajo" in the
/// quiet support register, centered, inside the scroll column above
/// the committed view - the next card or the warm close string - for
/// its fixed window. No glyph, no fill, no motion; identical every
/// time, and it closes rather than opening a door to another. It wraps
/// every arm of the content switch, which is why it lives here rather
/// than beside the dealt card it most often crowns.
class CompletionAck extends StatelessWidget {
  const CompletionAck({super.key, required this.visible, required this.child});

  /// Whether the committed view below carries the ack line - the
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
/// string in the completion ack's register - centered, `bodySmall`,
/// one `Spacing.actionGap` above the committed view - standing for
/// the whole opening on every variant. No glyph, no fill, no motion
/// and no dismissal control; no timer owns it (the 2-s
/// `CompletionAck` window is not this), and no state exists
/// anywhere: the read's own `warmReturnDue` fact decides - passed
/// here as [visible], read as data and never owned - so the greeting
/// persists through the session by derivation and is gone at the
/// next opening inside 48 h. Nothing here counts the days away -
/// they are not representable.
class WarmReturnGreeting extends StatelessWidget {
  const WarmReturnGreeting({
    super.key,
    required this.visible,
    required this.child,
  });

  /// Whether this opening carries the greeting - the read's own
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

// The Dispenser surface (Story 1.8, UX-DR14/UX-DR41): the app's home.
// Exactly one Micro-task on screen (FR-1), no list, calendar, counter,
// streak, badge or overdue indicator anywhere reachable (UX-DR44). The
// air around the card is a minimum 48dp plus flex — never a fixed value
// — so at 200% font scale the card grows into its air and the screen
// scrolls (NFR6); side margins hold `Spacing.screenMargin` and a
// max-width bound keeps the card from stretching on wide grounds.
//
// No splash, spinner or loader ever precedes the first card (UX-DR41,
// NFR5): a read that has not resolved renders the empty `surfaceBase`
// frame, and a read that fails leaves it standing — the controller's
// memo cleared, so the next read retries. No error string, no crash
// surfaced. The retry's trigger is the same one
// `SessionController` uses: a real return to the foreground re-reads,
// and nothing else does — 1.9's answers are what refresh the surface
// between foregrounds.
import 'package:flutter/material.dart';

import '../../dispenser/dispenser_controller.dart';
import '../../strings/app_strings.dart';
import '../tokens.dart';
import 'task_card.dart';

/// The card's width bound on wide grounds. A layout bound, not a gap: no
/// DESIGN token exists for it, and the tokenized side rule
/// (`Spacing.screenMargin`) stays in force below it.
const double _cardMaxWidth = 480;

class DispenserScreen extends StatefulWidget {
  const DispenserScreen({super.key, required this.controller});

  final DispenserController controller;

  @override
  State<DispenserScreen> createState() => _DispenserScreenState();
}

class _DispenserScreenState extends State<DispenserScreen>
    with WidgetsBindingObserver {
  /// Null until the first read resolves: the empty frame, never a loader.
  DispenserView? _view;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refresh();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Only a real return from off-foreground re-reads (the observer's
    // own contract, as with SessionController): the launch read is
    // initState's alone, and a transient occlusion changes nothing.
    if (state == AppLifecycleState.resumed) {
      _refresh();
    }
  }

  void _refresh() {
    widget.controller.read().then(
      (view) {
        if (mounted) {
          setState(() => _view = view);
        }
      },
      onError: (Object _) {
        // A failed catalogue read changes nothing on screen: the empty
        // frame stands, and the controller's cleared memo makes the next
        // read a retry.
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final view = _view;
    return Scaffold(
      // The scaffold background is the theme's surfaceBase tone in both
      // modes — the empty frame is already the whole surface.
      body: switch (view) {
        null => const SizedBox.shrink(),
        DispenserDealt(card: final card) => _frame(TaskCard(card: card)),
        DispenserClosed() => _frame(_closeText(context)),
      },
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

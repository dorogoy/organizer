// The Decluttering Protocol's frame (Story 6.1, FR-19, UX-DR31): the
// surface a dealt purge card's `Hecho` opens — and the ONLY way in.
// No menu, list or second entry reaches it; the dispenser's ordinary
// card is the whole door. This story ships the frame's plumbing only:
// one `Hecho` that funnels into the Dispenser's existing completion
// path — the same `cardDone` command every card answers through, one
// `card_done` on the purge id, no new append site — and then closes
// back onto the dispenser, whose refresh brings the next deal. The
// protocol's own body (the two detachment questions and the
// 3-Destination Flow) is stories 6.2–6.4's work over this same frame;
// nothing of it exists yet, so the frame deliberately carries no copy
// of its own — the surface register (NoSlicerSurface's own grammar:
// full-screen surfaceBase, SafeArea, centered, scrolling at 200%) and
// the one action, nothing else.
import 'package:flutter/material.dart';

import '../dispenser/task_card.dart';
import '../tokens.dart';

/// The frame's width bound on wide grounds — NoSlicerSurface's own
/// layout bound (a layout bound, not a gap; the tokenized side rule
/// `Spacing.screenMargin` stays in force below it).
const double _protocolMaxWidth = 480;

/// The Decluttering Protocol's minimal frame (Story 6.1, UX-DR31).
/// [onComplete] is the dealt purge card's completion — the Dispenser's
/// own `_onDone` path, threaded through the push; the frame holds no
/// state, no controller and no copy of its own. The system back
/// gesture is the OS pop: leaving without completing leaves the purge
/// card standing exactly as it was, dealable and finishable — nothing
/// is queued, retried or persisted on departure.
class DeclutteringProtocolScreen extends StatelessWidget {
  const DeclutteringProtocolScreen({super.key, required this.onComplete});

  final VoidCallback onComplete;

  /// The one action: close the frame first — the push idiom's own
  /// register, never an awaited write on a route — then complete the
  /// purge card through the path that was handed in. The dispenser
  /// below shows the same surface a direct `Hecho` would: the write,
  /// the ack, the next deal.
  void _done(BuildContext context) {
    // The pop-transition guard (Story 6.1's review round): a second
    // `Hecho` landing while the first pop is still animating would run
    // this frame's pop against the dispenser route beneath — stranding
    // the user off the dispenser with a terminal act half-landed. The
    // `isCurrent` idiom every push this surface family owns, held on
    // the exit too: not current, nothing to pop — return early, the
    // ordering (pop, then complete) stands otherwise.
    if (ModalRoute.of(context)?.isCurrent ?? false) {
      Navigator.of(context).pop();
      onComplete();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // The standard surfaceBase frame, centered — NoSlicerSurface's
      // own grammar: SafeArea first, screen margins on the sides, the
      // 200% floor holding through SingleChildScrollView. No PopScope:
      // the system back gesture is the OS pop, and nothing is queued
      // on departure.
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(
            horizontal: Spacing.screenMargin,
            vertical: Spacing.touchTargetMin,
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: _protocolMaxWidth),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Stories 6.2–6.4 land the protocol's body here; this
                  // story ships the entry route and the completion
                  // plumbing alone, so nothing renders above the one
                  // action yet.
                  //
                  // The one action: `Hecho` in the Done button's own
                  // register (HechoButton's default label), full-width
                  // accent-soft, minimum 48dp — completing the purge
                  // through the ordinary answer path and closing.
                  HechoButton(onTap: () => _done(context)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

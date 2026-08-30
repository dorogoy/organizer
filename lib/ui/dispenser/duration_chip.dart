// The duration chip (DESIGN.md {components.duration-chip}): a pill of
// `accent-soft` carrying `ink-primary` text in the duration role — the
// only pastel in the system that carries text, and no glyph may ever sit
// inside it. It sits ABOVE the task as an eyebrow because reading order is
// the mechanism: cost before ask (FR-1 — the estimate is always visible).
//
// Story 2.2 adds the pocket trigger: the same pill idiom carrying
// `Tengo {minutes} minutos ahora` — the standing declared pocket while a
// pocketed session is open, else the 15 default (UX-DR18's second life
// for the chip). Never a countdown, never remaining minutes: the chip
// states what the user declared, nothing more.
import 'package:core/settings/settings.dart';
import 'package:flutter/material.dart';

import '../../strings/app_strings.dart';
import '../tokens.dart';

/// The duration label (DESIGN.md {formats.duration}): value + non-breaking
/// space + unit. Whole minutes when the estimate is at least a minute and
/// divides by 60, else seconds — 900 → `15 min`, 180 → `3 min`,
/// 30 → `30 s`, with the NBSP load-bearing at 200%.
String durationLabel(int seconds, AppStrings strings) {
  if (seconds >= 60 && seconds % 60 == 0) {
    return strings.durationMinutes(seconds ~/ 60);
  }
  return strings.durationSeconds(seconds);
}

/// The eyebrow pill above the task text. Hugs its content and aligns with
/// the card's leading edge — a closed shape reading as "quantity with
/// edges", which is why it takes `{rounded.full}`.
class DurationChip extends StatelessWidget {
  const DurationChip({super.key, required this.seconds});

  final int seconds;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        // The theme's primary pair is accent-soft + ink-primary in both
        // modes — the pair the chip and Hecho share by design.
        color: theme.colorScheme.primary,
        borderRadius: BorderRadius.circular(Radii.radiusFull),
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: Spacing.chipPaddingHorizontal,
        vertical: Spacing.chipPaddingVertical,
      ),
      child: Text(
        durationLabel(seconds, AppStrings.of(context)),
        // titleSmall is the wired duration role (theme.dart).
        style: theme.textTheme.titleSmall,
      ),
    );
  }
}

/// The pocket trigger (Story 2.2, FR-8, UX-DR18): the duration-chip pill
/// as a control, top-centred above the card. Carries
/// `Tengo {minutes} minutos ahora` — [minutes] is the standing declared
/// pocket, already defaulted by the surface (the open session's own
/// pocket fact, else [defaultPocketMinutes]). One tap opens the ladder
/// sheet; nothing here counts down, nothing shows a remainder, and no
/// error state exists for a refusal to reach.
class PocketTriggerChip extends StatelessWidget {
  const PocketTriggerChip({super.key, required this.minutes, this.onTap});

  /// The standing declared pocket in minutes — the surface's defaulted
  /// value, from the read view's own fact.
  final int minutes;

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      // The interim convention holds (no custom semantics beyond the
      // platform's own traversal): the affordance is declared as a
      // button so a reader hears a control, not a bare sentence —
      // the label is the sentence the chip's own text already carries.
      button: true,
      child: Material(
        color: theme.colorScheme.primary,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Radii.radiusFull),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          // Absent, the tap stays an accepted no-op — a null onTap would
          // render a disabled control instead.
          onTap: onTap ?? () {},
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              minHeight: Spacing.touchTargetMin,
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: Spacing.chipPaddingHorizontal,
              ),
              child: Center(
                child: Text(
                  AppStrings.of(context).pocketTrigger(minutes),
                  // titleSmall is the wired duration role (theme.dart).
                  style: theme.textTheme.titleSmall,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

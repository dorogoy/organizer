// The duration chip (DESIGN.md {components.duration-chip}): a pill of
// `accent-soft` carrying `ink-primary` text in the duration role — the
// only pastel in the system that carries text, and no glyph may ever sit
// inside it. It sits ABOVE the task as an eyebrow because reading order is
// the mechanism: cost before ask (FR-1 — the estimate is always visible).
import 'package:flutter/material.dart';

import '../../strings/app_strings.dart';
import '../tokens.dart';

/// The chip's own padding, measured on the canonical render
/// (`mockups/dispenser-canonical-1.html`): a component measurement, not a
/// gap between anatomy elements, so it carries no `Spacing` token.
const double _chipPaddingHorizontal = 14;
const double _chipPaddingVertical = 5;

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
        horizontal: _chipPaddingHorizontal,
        vertical: _chipPaddingVertical,
      ),
      child: Text(
        durationLabel(seconds, AppStrings.of(context)),
        // titleSmall is the wired duration role (theme.dart).
        style: theme.textTheme.titleSmall,
      ),
    );
  }
}

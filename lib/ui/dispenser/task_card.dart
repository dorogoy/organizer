// The dispenser card (DESIGN.md {components.dispenser-card}): `raised`
// on `base`, 1px hairline, 14px radius, no shadow — surfaces separate by
// tone, never by elevation (UX-DR6). Anatomy top to bottom: the duration
// chip as an eyebrow, the task in Lora, full-width Hecho, the secondary
// action as plain centered text, and — only when the card carries a zone
// — the Hoja marker as a quiet footer. Every gap between elements comes
// from `Spacing` tokens; the card never compresses to fit more.
//
// Origin is never on this surface (AD-14): the card renders its name,
// its cost and its zone word, and nothing else the weave knows.
import 'package:core/weave/weave.dart';
// The core's Card is the domain object this surface renders; Material's
// widget of the same name stays out of scope here.
import 'package:flutter/material.dart' hide Card;

import '../../strings/app_strings.dart';
import '../tokens.dart';
import 'duration_chip.dart';
import 'zone_marker.dart';

/// The one recommended action (UX-DR16): full-width, filled `accent-soft`
/// with an `ink-primary` label, `{rounded.DEFAULT}`, minimum height
/// `{spacing.touch-target-min}`. One tap, no confirmation (Story 1.9):
/// [onTap] is the screen's completion path; absent, the tap stays an
/// accepted no-op (the 1.8 anatomy harness).
class HechoButton extends StatelessWidget {
  const HechoButton({super.key, this.onTap});

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      width: double.infinity,
      child: Material(
        color: theme.colorScheme.primary,
        borderRadius: BorderRadius.circular(Radii.radiusDefault),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          // Absent, the no-op keeps the 1.8 anatomy contract: the tap
          // is accepted and does nothing — a null onTap would render a
          // disabled control instead.
          onTap: onTap ?? () {},
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              minHeight: Spacing.touchTargetMin,
            ),
            child: Center(
              // bodyLarge is the wired action-primary role (theme.dart).
              child: Text(
                AppStrings.of(context).actionDone,
                style: theme.textTheme.bodyLarge,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The unsplit secondary (DESIGN.md {components.action-secondary}): plain
/// centered text in `ink-secondary` — no box, no fill, no underline, no
/// animation. One control carrying two features (FR-5 rescue, FR-3 skip);
/// the string is never split or shortened, and the touch target still
/// holds 48dp. [onTap] is the screen's skip path (Story 1.10); absent,
/// the tap stays an accepted no-op (the 1.8 anatomy harness).
///
/// The same grammar carries every quiet prose departure (UX-DR25):
/// [label] overrides the card's own string for the Dispenser footer's
/// `Nuevo proyecto` and the way-out surfaces' `Ajustes` — ink-secondary
/// text, 48dp opaque target, never animated, emphasised, badged, nor
/// carrying pastel mass.
class SecondaryTextAction extends StatelessWidget {
  const SecondaryTextAction({super.key, this.onTap, this.label});

  final VoidCallback? onTap;

  /// The string this action carries, in the accessor the resolved
  /// context provides; absent, the card's own unsplit secondary string.
  final String? label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GestureDetector(
      // Absent, the no-op keeps the 1.8 anatomy contract: the tap is
      // accepted and does nothing — a null onTap would render a
      // disabled control instead.
      onTap: onTap ?? () {},
      // Opaque so the whole 48dp band takes the tap, not just the text
      // glyphs — the touch target is the floor, and a deferToChild
      // default lets the band's gaps fall through.
      behavior: HitTestBehavior.opaque,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: Spacing.touchTargetMin),
        child: Center(
          // bodyMedium is the wired action-secondary role (theme.dart).
          child: Text(
            label ?? AppStrings.of(context).actionRescueOrSkip,
            style: theme.textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}

/// The dealt card (FR-1): exactly one Micro-task with its estimated
/// duration always visible. The zone footer renders iff [Card.zone] is
/// non-null — the card simply ends after the secondary action otherwise.
/// [onDone] threads the Hecho tap through (Story 1.9); [onSkip] threads
/// the secondary's tap through (Story 1.10). Absent either, its tap
/// stays the anatomy's accepted no-op.
class TaskCard extends StatelessWidget {
  const TaskCard({super.key, required this.card, this.onDone, this.onSkip});

  final Card card;

  final VoidCallback? onDone;

  final VoidCallback? onSkip;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        // surfaceContainerHighest is the wired raised tone; outline is
        // the wired hairline (theme.dart) — tone and a 1px edge, no
        // shadow, no gradient, no glow.
        color: theme.colorScheme.surfaceContainerHighest,
        border: Border.all(color: theme.colorScheme.outline, width: 1),
        borderRadius: BorderRadius.circular(Radii.radiusDefault),
      ),
      padding: const EdgeInsets.all(Spacing.cardPadding),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DurationChip(seconds: card.estimateSeconds),
          const SizedBox(height: Spacing.chipToTask),
          // headlineMedium is the wired task role — Lora, the one
          // CONTENT role (theme.dart).
          Text(card.name, style: theme.textTheme.headlineMedium),
          const SizedBox(height: Spacing.taskToActions),
          HechoButton(onTap: onDone),
          const SizedBox(height: Spacing.actionGap),
          SecondaryTextAction(onTap: onSkip),
          if (card.zone != null) ...[
            // The quiet footer's detachment from the actions — the
            // ladder's 24, nearest token step above the canonical
            // render's illustrative 20.
            const SizedBox(height: Spacing.cardPadding),
            ZoneMarker(zone: card.zone!),
          ],
        ],
      ),
    );
  }
}

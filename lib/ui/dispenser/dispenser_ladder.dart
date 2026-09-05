// The Dispenser's quiet stepped ladder (Story 2.2): the titleless sheet
// of duration pills, extracted from the ladder content in
// `dispenser_screen.dart`. The sheet keeps its own scroll and wraps at
// the text-scaling floor; the State still owns the modal push and commit.
import 'package:flutter/material.dart';

import '../../strings/app_strings.dart';
import '../tokens.dart';
import 'dispenser_chrome.dart';
import 'duration_chip.dart';

/// The quiet stepped ladder's content (Story 2.2): the titleless sheet
/// of duration pills - the `size-option` idiom - every option in the
/// command's range, [pocketLadderOptions], selected marking the
/// standing pocket. The sheet wraps and scrolls at 200%; a tap pops
/// the sheet and declares through [onSelect]. Nothing here shows a
/// remainder, nothing counts down, and no error state exists for a
/// refused value to reach.
class PocketLadderSheet extends StatelessWidget {
  const PocketLadderSheet({
    super.key,
    required this.standingMinutes,
    required this.onSelect,
  });

  /// The standing declared pocket the selected pill marks.
  final int standingMinutes;

  /// A pill's tap calls [onSelect] with that pill's minutes.
  final void Function(int minutes) onSelect;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(Spacing.cardPadding),
        child: Wrap(
          spacing: Spacing.actionGap,
          runSpacing: Spacing.actionGap,
          children: [
            for (final minutes in pocketLadderOptions)
              _PocketLadderOption(
                minutes: minutes,
                selected: standingMinutes == minutes,
                onTap: () => onSelect(minutes),
              ),
          ],
        ),
      ),
    );
  }
}

/// One stepped ladder pill (Story 2.2, the `size-option` idiom): a
/// duration pill - selected fills `colorScheme.primary` (the theme's
/// accent-soft mapping, the same pastel `DurationChip` fills), unselected
/// sits raised with a 1px hairline edge - ink-primary in the duration
/// role on both, `rounded.full`, 48dp minimum, never a glyph. The label
/// is the minutes themselves through the duration format; context is the
/// chip just tapped, so the sheet carries no title and no internal name
/// renders.
class _PocketLadderOption extends StatelessWidget {
  const _PocketLadderOption({
    required this.minutes,
    required this.selected,
    this.onTap,
  });

  final int minutes;

  final bool selected;

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: selected
          ? theme.colorScheme.primary
          : theme.colorScheme.surfaceContainerHighest,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Radii.radiusFull),
        side: selected
            ? BorderSide.none
            : BorderSide(color: theme.colorScheme.outline, width: 1),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        // Absent, the tap stays an accepted no-op - a null onTap would
        // render a disabled control instead.
        onTap: onTap ?? () {},
        child: Semantics(
          // The affordance reaches screen readers as a button carrying
          // selection state, never as a different visual grammar: the
          // spoken label is the minutes value the pill's own text
          // already carries.
          button: true,
          selected: selected,
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
                  durationLabel(minutes * 60, AppStrings.of(context)),
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

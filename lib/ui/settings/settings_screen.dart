// Settings (Story 2.1, UX-DR33): a flat platform list — a ListView in
// the frame idiom, scrolling at 200% with nothing truncated — whose
// first and only group is **Tu día**, holding the Time Bag as one row
// of stepped options. Group headers are quiet support copy; light/dark
// follows the system with no row anywhere; no settings glyph exists
// (the ten-glyph set is pinned without one). Setting the bag appends
// one `setting_changed` row and carries no confirmation, state or
// error surface of any kind — the selected option reading as the
// current value is the whole feedback, and the derivation rebuilds it
// from the log on every read (AD-1).
import 'package:core/settings/settings.dart';
import 'package:flutter/material.dart';

import '../../settings/settings_controller.dart';
import '../../strings/app_strings.dart';
import '../dispenser/duration_chip.dart';
import '../tokens.dart';

/// The settings surface (FR-7, UX-DR33): the flat platform list. The
/// Time Bag row offers the six stepped options [timeBagOptions] as
/// duration pills — the `size-option` idiom: selected `accent-soft`,
/// unselected raised with a 1px hairline, both ink-primary in the
/// duration role, both `rounded.full` and 48dp minimum, no glyph
/// anywhere. A tap writes through [SettingsController] — exactly one
/// `setting_changed` row, appended silently.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key, this.controller});

  /// The read/write seam over the same store the Dispenser holds.
  /// Absent (the test seam), the list renders and writes go nowhere.
  final SettingsController? controller;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  /// The derived bag, null until the first read resolves — no loader,
  /// no placeholder: the options render unselected and the selection
  /// mark appears when the derivation lands.
  int? _bagMinutes;

  @override
  void initState() {
    super.initState();
    _readBag();
  }

  Future<void> _readBag() async {
    final controller = widget.controller;
    if (controller == null) {
      return;
    }
    try {
      final bag = await controller.readTimeBag();
      if (mounted) {
        setState(() => _bagMinutes = bag);
      }
    } catch (_) {
      // A failed read leaves the surface exactly as it was — no loader,
      // no error state, nothing surfaced. The derivation is retried on
      // the next write's re-read.
    }
  }

  /// One option tap: a value equal to the current derivation writes
  /// nothing — no redundant `setting_changed` row for re-choosing what
  /// is already in force. Otherwise one write, then a re-read from the
  /// derived source of truth — the selection mark that lands is the
  /// derivation's, not the tap's assumption. A failed write is quiet
  /// and changes nothing: no error surface exists here for anything to
  /// reach.
  Future<void> _onOptionTap(int minutes) async {
    final controller = widget.controller;
    if (controller == null || minutes == _bagMinutes) {
      return;
    }
    try {
      await controller.writeTimeBag(minutes);
    } catch (_) {
      return;
    }
    await _readBag();
  }

  /// The derived bag's off-ladder extra, when it has one: an in-range
  /// value outside [timeBagOptions] renders as its own current-value
  /// chip ahead of the ladder.
  List<int> _offLadderMinutes(int? bag) =>
      bag == null || timeBagOptions.contains(bag) ? const [] : [bag];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bag = _bagMinutes;
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(
            horizontal: Spacing.screenMargin,
            vertical: Spacing.touchTargetMin,
          ),
          children: [
            // The quiet group header (UX-DR33): support copy, ink-secondary.
            Text(
              AppStrings.of(context).settingsGroupYourDay,
              // bodySmall is the wired support role (theme.dart).
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: Spacing.actionGap),
            // The row's label, quiet above its options.
            Text(
              AppStrings.of(context).settingsTimeBag,
              // bodyMedium is the wired action-secondary role (theme.dart).
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: Spacing.actionGap),
            // An in-range value off the stepped ladder (an imported 17,
            // say) still reads as the current value: one extra chip
            // renders for it in the same idiom, selected — selection
            // always reflects the derivation, ladder or no ladder.
            Wrap(
              spacing: Spacing.actionGap,
              runSpacing: Spacing.actionGap,
              children: [
                for (final minutes in [
                  ..._offLadderMinutes(bag),
                  ...timeBagOptions,
                ])
                  _TimeBagOption(
                    minutes: minutes,
                    selected: bag == minutes,
                    onTap: () => _onOptionTap(minutes),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// One stepped Time Bag option (the `size-option` idiom): a duration
/// pill — selected fills `accent-soft`, unselected sits raised with a
/// 1px hairline edge — ink-primary in the duration role on both,
/// `rounded.full`, 48dp minimum, never a glyph. The label is the
/// minutes themselves through the duration format; internal names
/// never render.
class _TimeBagOption extends StatelessWidget {
  const _TimeBagOption({
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
        // Absent, the tap stays an accepted no-op — a null onTap would
        // render a disabled control instead.
        onTap: onTap ?? () {},
        child: Semantics(
          // Selection reaches screen readers as state, never as a
          // different visual grammar: the spoken label is the minutes
          // value the pill's own text already carries, and `selected`
          // marks which option is in force.
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

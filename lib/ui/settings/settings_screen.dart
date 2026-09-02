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
//
// Story 3.4 adds the validator surface's dictation facts (FR-32,
// AD-26): the dictated-capture count line — the one place the
// per-capture dictation boolean is readable, a quiet support line —
// and the `IA y voz` reactivation row, which renders only while the
// microphone permission is refused ∧ not granted (something to
// reactivate) and whose single tap opens the system's app-details
// screen. No new group header: the flat list simply holds both, and
// the row never confirms, never explains, never re-asks.
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

class _SettingsScreenState extends State<SettingsScreen>
    with WidgetsBindingObserver {
  /// The derived bag, null until the first read resolves — no loader,
  /// no placeholder: the options render unselected and the selection
  /// mark appears when the derivation lands.
  int? _bagMinutes;

  /// The derived dictated-capture count (Story 3.4), null until the
  /// first read resolves — same register as the bag: no loader, the
  /// line appears when the derivation lands.
  int? _dictatedCount;

  /// Whether the `IA y voz` reactivation row has something to
  /// reactivate (Story 3.4): refused ∧ not granted. False until the
  /// first read resolves — absent, exactly as when the premise fails.
  bool _micReactivationAvailable = false;

  // Only the newest read may update the selection: an initial slow read can
  // otherwise complete after the post-write refresh and restore old state.
  var _readGeneration = 0;

  // The dictation facts read owns its own generation: the two reads run
  // concurrently from initState, and one must not retire the other.
  var _dictationReadGeneration = 0;

  @override
  void initState() {
    super.initState();
    // The reactivation row's premise reaches outside the app — the
    // system's own permission state — so the surface observes the
    // lifecycle and re-reads on every return from the foreground: a
    // re-grant made in system settings retires the row by itself, and
    // the dictated count refreshes with it.
    WidgetsBinding.instance.addObserver(this);
    _readBag();
    _readDictationFacts();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _readDictationFacts();
    }
  }

  Future<void> _readBag() async {
    final controller = widget.controller;
    if (controller == null) {
      return;
    }
    final generation = ++_readGeneration;
    try {
      final bag = await controller.readTimeBag();
      if (mounted && generation == _readGeneration) {
        setState(() => _bagMinutes = bag);
      }
    } catch (_) {
      // A failed read leaves the surface exactly as it was — no loader,
      // no error state, nothing surfaced. The derivation is retried on
      // the next write's re-read.
    }
  }

  /// Reads the validator surface's dictation facts (Story 3.4): the
  /// count line's figure and the reactivation row's premise. The same
  /// quiet register as the bag read — a failed read changes nothing.
  Future<void> _readDictationFacts() async {
    final controller = widget.controller;
    if (controller == null) {
      return;
    }
    final generation = ++_dictationReadGeneration;
    try {
      final results = await Future.wait([
        controller.readDictatedCount(),
        controller.readMicReactivationAvailable(),
      ]);
      if (mounted && generation == _dictationReadGeneration) {
        setState(() {
          _dictatedCount = results[0] as int;
          _micReactivationAvailable = results[1] as bool;
        });
      }
    } catch (_) {
      // Quiet: the count line stays absent and the row stays as it was.
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
            const SizedBox(height: Spacing.taskToActions),
            // The validator surface's dictated count (Story 3.4, FR-32,
            // AD-26): the one place the per-capture dictation boolean is
            // readable — a quiet support line, rendered only once the
            // derivation lands, never a card's to carry.
            if (_dictatedCount != null)
              Text(
                AppStrings.of(context).settingsDictatedCount(_dictatedCount!),
                // bodySmall is the wired support role (theme.dart).
                style: theme.textTheme.bodySmall,
              ),
            // The reactivation row (Story 3.4): present only while the
            // microphone permission is refused ∧ not granted — while it
            // has something to reactivate. One tap opens the system's
            // app-details screen; no confirmation, no explanation, and
            // the app never re-asks on its own.
            if (_micReactivationAvailable) ...[
              const SizedBox(height: Spacing.actionGap),
              _ReactivationRow(
                label: AppStrings.of(context).settingsAiVoice,
                onTap: _onOpenMicAppSettings,
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// The reactivation row's single action (Story 3.4): open the
  /// system's app-details screen, quietly — a failed open is absorbed
  /// and the row stays exactly as it is.
  Future<void> _onOpenMicAppSettings() async {
    try {
      await widget.controller?.openMicAppSettings();
    } catch (_) {
      // Quiet: nothing is surfaced, nothing changes.
    }
  }
}

/// The `IA y voz` reactivation row (Story 3.4, FR-32): a quiet tappable
/// row in the flat platform list's own grammar — left-aligned
/// bodyMedium label inside a 48dp band, declared to readers as a
/// button. It renders only while a re-grant has something to
/// reactivate, and its whole action is the system's app-details screen.
class _ReactivationRow extends StatelessWidget {
  const _ReactivationRow({required this.label, this.onTap});

  final String label;

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      button: true,
      label: label,
      child: GestureDetector(
        // Absent, the tap stays an accepted no-op — a null onTap would
        // render a disabled control instead.
        onTap: onTap ?? () {},
        behavior: HitTestBehavior.opaque,
        child: Align(
          alignment: AlignmentDirectional.centerStart,
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              minHeight: Spacing.touchTargetMin,
            ),
            child: Center(
              // bodyMedium is the wired action-secondary role
              // (theme.dart) — the row reads as a quiet prose action,
              // never a filled control.
              child: Text(
                label,
                style: theme.textTheme.bodyMedium,
                textAlign: TextAlign.start,
              ),
            ),
          ),
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

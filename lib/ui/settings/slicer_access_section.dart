// The IA y voz access section (Story 4-4, AD-9, AD-10): the BYOK
// path's whole configuration surface — one provider pill plus its
// terms sentence per frozen allowlist entry, and the quiet obscured
// key field with the free-tier sentence stated once below it.
// Selection writes one `setting_changed` {selected_provider} row
// through the controller (silently; the pill reading as selected is
// the whole feedback); a key submit saves into the vault, an empty
// submit deletes, both quiet. No availability or status badge
// exists anywhere — the vault measures at request time and nothing
// remembers its answer. The dictated-count line and the microphone
// reactivation row live under the same group header, outside this
// widget.
import 'package:flutter/material.dart';

import '../../egress/provider_allowlist.dart';
import '../../settings/settings_controller.dart';
import '../../strings/app_strings.dart';
import '../tokens.dart';

/// The empty render for an id the string table does not cover —
/// unreachable by construction (the ARB-coverage pin fails the build
/// before it can render), stated once so both mappings stay total. A
/// named infrastructure identifier on the UI module's AD-15 terms.
const String uncoveredProviderRender = '';

/// The IA y voz group's access content (FR-28): provider pills in
/// the `size-option` grammar (selected `accent-soft` fill, unselected
/// raised with a 1px hairline, 48dp minimum, `rounded.full`, no
/// glyph), each with its terms sentence as a quiet support line
/// beneath — the date baked, "verified on that day, not since", no
/// age indicator, no re-check — then the key field. The section
/// derives its selection from the log on every read and refreshes
/// after every write, exactly the Time Bag row's discipline.
class SlicerAccessSection extends StatefulWidget {
  const SlicerAccessSection({super.key, this.controller});

  /// The read/write seam over the same store the Dispenser holds.
  /// Absent (the test seam), the pills and field render and writes
  /// go nowhere.
  final SettingsController? controller;

  @override
  State<SlicerAccessSection> createState() => _SlicerAccessSectionState();
}

class _SlicerAccessSectionState extends State<SlicerAccessSection> {
  /// The derived selected provider, null until the first read
  /// resolves — no loader, no placeholder: the pills render
  /// unselected and the selection mark appears when the derivation
  /// lands.
  String? _selectedProvider;

  // Only the newest read may update the selection.
  var _readGeneration = 0;

  /// The in-flight (or settled) selection read — the submit path
  /// awaits it, so a key handed in before the first derivation
  /// lands scopes against the log's truth, not the field's timing.
  Future<void> _selectionRead = Future<void>.value();

  /// The key field's controller — an entry point, never a display:
  /// a submit hands its text to the vault and the field clears, so
  /// the field never remembers what the vault now holds (and never
  /// leaks whether it holds anything).
  final TextEditingController _keyFieldController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _readSelection();
  }

  @override
  void didUpdateWidget(SlicerAccessSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      // A replaced controller is a replaced derivation source: the
      // standing selection is stale until re-read, so the read runs
      // now — the pills re-mark themselves when it lands.
      _readSelection();
    }
  }

  @override
  void dispose() {
    _keyFieldController.dispose();
    super.dispose();
  }

  void _readSelection() {
    final controller = widget.controller;
    if (controller == null) {
      return;
    }
    final generation = ++_readGeneration;
    final read = () async {
      try {
        final selected = await controller.readSelectedProvider();
        if (mounted && generation == _readGeneration) {
          setState(() => _selectedProvider = selected);
        }
      } catch (_) {
        // A failed read leaves the surface exactly as it was — the
        // same quiet register every read here holds.
      }
    }();
    _selectionRead = read;
  }

  /// One pill tap: a value equal to the current derivation writes
  /// nothing; otherwise one write, then a re-read — the selection
  /// mark that lands is the derivation's, not the tap's assumption.
  Future<void> _onEntryTap(String providerId) async {
    final controller = widget.controller;
    if (controller == null || providerId == _selectedProvider) {
      return;
    }
    try {
      await controller.writeSelectedProvider(providerId);
    } catch (_) {
      return;
    }
    _readSelection();
    await _readSettled();
  }

  /// The key field's submit (FR-28): text saves, empty deletes —
  /// both quiet, both scoped to the selected provider, and the
  /// field clears either way. The submit first waits for the
  /// in-flight selection read (if the surface just opened, the log's
  /// seeded selection is the truth and must be known before the key
  /// is scoped — a fast paste-and-submit against it saves rather
  /// than discards). With no provider selected once known, or no
  /// controller, the submit goes nowhere: nothing is surfaced, the
  /// register never changes.
  Future<void> _onKeySubmitted(String text) async {
    final controller = widget.controller;
    await _readSettled();
    if (!mounted) {
      return;
    }
    final selected = _selectedProvider;
    _keyFieldController.clear();
    if (controller == null || selected == null) {
      return;
    }
    final trimmed = text.trim();
    try {
      if (trimmed.isEmpty) {
        await controller.clearProviderKey(selected);
      } else {
        await controller.saveProviderKey(selected, trimmed);
      }
    } catch (_) {
      // Quiet: the vault's own write discipline is silence, and no
      // error surface exists here for anything to reach.
    }
  }

  /// Awaits the newest read's settlement — quiet on every path; a
  /// read that already settled returns immediately.
  Future<void> _readSettled() async {
    await _selectionRead;
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final entry in slicerProviderAllowlist) ...[
          _ProviderOption(
            label: _providerNameOf(strings, entry.id),
            selected: _selectedProvider == entry.id,
            onTap: () => _onEntryTap(entry.id),
          ),
          const SizedBox(height: Spacing.chipToTask),
          Text(
            _providerTermsOf(strings, entry.id),
            // bodySmall is the wired support role (theme.dart) — the
            // terms line is quiet support copy.
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: Spacing.actionGap),
        ],
        const SizedBox(height: Spacing.chipToTask),
        _keyField(context),
        const SizedBox(height: Spacing.chipToTask),
        Text(
          strings.settingsProviderKeyFreeTierNote,
          // bodySmall is the wired support role (theme.dart) — the
          // free-tier sentence, stated here exactly once.
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }

  /// The rendered name for an allowlist id — the ARB is the one home
  /// of provider copy, matched to the frozen entries by test (an id
  /// the table does not cover fails the build there, so the empty
  /// arm is unreachable).
  static String _providerNameOf(AppStrings strings, String id) => switch (id) {
    geminiProviderId => strings.providerNameGemini,
    openAiProviderId => strings.providerNameOpenai,
    anthropicProviderId => strings.providerNameAnthropic,
    openRouterProviderId => strings.providerNameOpenrouter,
    _ => uncoveredProviderRender,
  };

  /// The rendered terms sentence for an allowlist id — the same
  /// coverage contract as the name.
  static String _providerTermsOf(AppStrings strings, String id) => switch (id) {
    geminiProviderId => strings.providerTermsGemini,
    openAiProviderId => strings.providerTermsOpenai,
    anthropicProviderId => strings.providerTermsAnthropic,
    openRouterProviderId => strings.providerTermsOpenrouter,
    _ => uncoveredProviderRender,
  };

  /// The quiet obscured key field: the capture line's own register —
  /// raised fill, 1px hairline, radius 14, 48dp minimum — obscured,
  /// single-line by the TextField's default, no validation, no error
  /// surface, no read-back of anything the vault holds. The label is
  /// the field's only copy; the free-tier sentence below it is the
  /// sentence's one home.
  Widget _keyField(BuildContext context) {
    final theme = Theme.of(context);
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(Radii.radiusDefault),
      borderSide: BorderSide(color: theme.colorScheme.outline, width: 1),
    );
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: Spacing.touchTargetMin),
      child: TextField(
        controller: _keyFieldController,
        onSubmitted: _onKeySubmitted,
        obscureText: true,
        // bodyMedium carries the entry in the Lexend mechanism
        // register (theme.dart) — a mechanism, never content.
        style: theme.textTheme.bodyMedium,
        decoration: InputDecoration(
          labelText: AppStrings.of(context).settingsProviderKeyLabel,
          filled: true,
          fillColor: theme.colorScheme.surfaceContainerHighest,
          enabledBorder: border,
          focusedBorder: border,
        ),
      ),
    );
  }
}

/// One provider pill — `_TimeBagOption`'s grammar exactly: selected
/// fills the primary pair, unselected sits raised with a 1px
/// hairline edge, `rounded.full`, 48dp minimum, never a glyph. The
/// label is the provider's rendered name; the internal id never
/// renders. Selection reaches screen readers as state.
class _ProviderOption extends StatelessWidget {
  const _ProviderOption({
    required this.label,
    required this.selected,
    this.onTap,
  });

  final String label;

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
                  label,
                  // bodyMedium is the wired action-secondary role
                  // (theme.dart) — a provider name is a label, never
                  // a duration.
                  style: theme.textTheme.bodyMedium,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

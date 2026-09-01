// The Manual Capture surface (Story 3.2, FR-27, Epic 3's floor): exactly
// two fields — one single-line text field and one size from exactly three
// `size-option` pills — and nothing else is asked. No project, no
// category, no date, no priority, no tags, no recurrence, no
// confirmation screen; the copy (the spatial frame's three-step rule,
// read in order) names a place, lists touchable things, and opens the
// example with a spatial verb. A non-spatial line is accepted in
// silence: no validation, no error state, no red edge, no corrective
// message — and no second version of this screen exists.
//
// `Guardar` is the app's first true disabled control: it stays disabled
// until the trimmed line holds text (a blank capture would put an
// irreversible empty card into circulation) — the same accent-soft pill
// at reduced opacity, behind `IgnorePointer` and `Semantics(enabled:
// false)`, refusing the tap rather than accepting it silently. One tap,
// when enabled, writes the pool fact and its `capture_created` entry
// through the controller's single write path, then pops: once the user
// leaves this surface the capture cannot be corrected or discarded —
// the only path back to it is being dealt (3.3). One secondary only:
// `Descartar`, which is also the exit, and the system back gesture
// behaves as Descartar — no `Cancelar` exists.
//
// The mic capsule (FR-32) is 3.4's, not this story's: the field renders
// full-width and the keyboard is the only input method here. The 200%
// floor holds throughout: the surface scrolls
// (`SingleChildScrollView`), nothing truncates, every target sits at
// or above 48dp, and all copy comes through `AppStrings`.
import 'package:core/pool/pool_fact.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../capture/capture_controller.dart';
import '../../strings/app_strings.dart';
import '../dispenser/duration_chip.dart';
import '../dispenser/task_card.dart';
import '../tokens.dart';

/// The surface's width bound on wide grounds — the Dispenser frame's own
/// layout bound (a layout bound, not a gap; the tokenized side rule
/// `Spacing.screenMargin` stays in force below it).
const double _captureMaxWidth = 480;

/// The disabled `Guardar`'s reduced opacity (mockup `.save.dis`):
/// the same accent-soft pill, dimmed — never a different grammar.
const double _saveDisabledOpacity = 0.45;

/// The Manual Capture surface. [controller] is the write seam over the
/// same store the Dispenser holds; absent (the test seam), the surface
/// renders whole and a `Guardar` goes nowhere — no write, no pop.
class CaptureScreen extends StatefulWidget {
  const CaptureScreen({super.key, this.controller});

  final CaptureController? controller;

  @override
  State<CaptureScreen> createState() => _CaptureScreenState();
}

class _CaptureScreenState extends State<CaptureScreen> {
  /// The size pills' standing selection: single-selection, always
  /// populated, no empty state — `maintenance` preselected per the
  /// canonical mockup. A tap moves the selection; nothing can clear it.
  Size _size = Size.maintenance;

  /// The in-flight guard: one `Guardar` write owns the surface until it
  /// settles, so a rapid double-tap appends exactly one fact and one
  /// entry — the second tap returns early, before anything observable.
  bool _saving = false;

  late final TextEditingController _lineController;

  @override
  void initState() {
    super.initState();
    _lineController = TextEditingController();
    _lineController.addListener(_onLineChanged);
  }

  @override
  void dispose() {
    _lineController.removeListener(_onLineChanged);
    _lineController.dispose();
    super.dispose();
  }

  void _onLineChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  bool get _canSave => !_saving && _lineController.text.trim().isNotEmpty;

  /// The `Guardar` tap (FR-27): the write is awaited — the pool fact,
  /// then the `capture_created` entry referencing it, one instant for
  /// the batch — and only then does the route pop: nothing the surface
  /// shows could outlive a write that never landed. A failing store is
  /// absorbed quietly: the surface stays with its line intact, nothing
  /// is surfaced, and the retry is the same tap. The null-controller
  /// seam writes nothing and pops nothing — the honest test seam.
  Future<void> _onSave() async {
    if (_saving) {
      return;
    }
    // The guard the disabled pill already expresses, restated for any
    // caller the pill cannot speak for (3.4's dictation lands here): a
    // blank-after-trim line saves nothing and pops nothing.
    if (_lineController.text.trim().isEmpty) {
      return;
    }
    final controller = widget.controller;
    if (controller == null) {
      return;
    }
    setState(() => _saving = true);
    try {
      await controller.save(_lineController.text, _size);
      if (!mounted) {
        return;
      }
      // The write completed: the capture belongs to the pool now, and
      // the surface's whole remaining duty is to leave.
      Navigator.of(context).pop();
    } catch (_) {
      // Quiet absorption: nothing landed, nothing is surfaced, and the
      // standing line stays exactly as the user typed it — retryable.
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  /// The single secondary (FR-27): `Descartar` is also the exit — one
  /// tap, no confirmation, no writes. While a save owns the surface the
  /// tap returns early: a discard-looking exit must not race the
  /// committed write, which pops the route itself once it lands. The
  /// system back gesture behaves identically — `PopScope` below is the
  /// same gate — and no `Cancelar` exists anywhere.
  void _onDiscard() {
    if (_saving) {
      return;
    }
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final strings = AppStrings.of(context);
    // The system back gesture's Descartar-equivalent gate: while a
    // save is in flight the route refuses the pop, exactly as the
    // `Descartar` tap does — the write owns the exit, and pops it
    // itself on completion. Programmatic pops (`Guardar`'s own) are
    // not gated.
    return PopScope(
      canPop: !_saving,
      child: Scaffold(
        // The 200% floor: the surface grows and scrolls, never truncates
        // — SafeArea first so scrolled content never renders under the
        // status bar or a cutout, screen margins on the sides.
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(
              horizontal: Spacing.screenMargin,
              vertical: Spacing.touchTargetMin,
            ),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: _captureMaxWidth),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // The spatial frame's rule 1: the title names a place.
                    Text(
                      strings.captureTitle,
                      // headlineSmall is the wired screen-heading role
                      // (theme.dart).
                      style: theme.textTheme.headlineSmall,
                    ),
                    const SizedBox(height: Spacing.actionGap),
                    // Rule 2: the helper lists things you can touch.
                    Text(
                      strings.captureHelper,
                      // bodySmall is the wired support role (theme.dart).
                      style: theme.textTheme.bodySmall,
                    ),
                    const SizedBox(height: Spacing.chipToTask),
                    // Rule 3: the example opens with a spatial verb — a
                    // rendered line in the Lora content register, never
                    // the field's hint.
                    Text(
                      strings.captureExample,
                      // headlineMedium is the wired task role — the one
                      // CONTENT role (theme.dart).
                      style: theme.textTheme.headlineMedium,
                    ),
                    const SizedBox(height: Spacing.cardPadding),
                    _field(context),
                    const SizedBox(height: Spacing.cardPadding),
                    _sizeOptions(context),
                    const SizedBox(height: Spacing.taskToActions),
                    _saveAction(context),
                    const SizedBox(height: Spacing.actionGap),
                    SecondaryTextAction(
                      label: strings.captureDiscard,
                      onTap: _onDiscard,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// The one line of text (FR-27): raised fill, 1px hairline, radius 14,
  /// 48dp minimum — the field's own register, Lora for the content and
  /// Lexend for the hint. Single-line by the TextField's own default,
  /// and a paste can never put interior newlines into the stored Origin
  /// Context: the single-line formatter strips them on entry, so one
  /// line is what the field holds, not what the keyboard happens to
  /// send. No validation, no error surface, and the mic capsule is
  /// 3.4's, so the field renders full-width.
  Widget _field(BuildContext context) {
    final theme = Theme.of(context);
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(Radii.radiusDefault),
      borderSide: BorderSide(color: theme.colorScheme.outline, width: 1),
    );
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: Spacing.touchTargetMin),
      child: TextField(
        controller: _lineController,
        // One line, enforced at the input boundary: a pasted multi-line
        // string can never put interior newlines into the stored Origin
        // Context — the formatter strips them before the controller
        // ever holds them.
        inputFormatters: [FilteringTextInputFormatter.singleLineFormatter],
        // headlineMedium is the wired task role — the captured line is
        // content, the one Lora register (theme.dart).
        style: theme.textTheme.headlineMedium,
        decoration: InputDecoration(
          hintText: AppStrings.of(context).captureFieldPlaceholder,
          // bodyMedium carries the hint in the Lexend mechanism
          // register (theme.dart).
          hintStyle: theme.textTheme.bodyMedium,
          filled: true,
          fillColor: theme.colorScheme.surfaceContainerHighest,
          enabledBorder: border,
          focusedBorder: border,
        ),
      ),
    );
  }

  /// The three size pills (FR-27): the `size-option` idiom — durations
  /// through the format family, never internal taxonomy names —
  /// single-selection, always populated (`maintenance` preselected),
  /// no empty state, no "none of these". Selected fills accent-soft;
  /// unselected sits raised with a 1px hairline; no glyph on any
  /// option; each at 48dp minimum, declared to readers as a button
  /// carrying selection state. The pills wrap and scroll at 200%.
  Widget _sizeOptions(BuildContext context) {
    return Wrap(
      spacing: Spacing.actionGap,
      runSpacing: Spacing.actionGap,
      children: [
        for (final size in Size.values)
          _SizeOption(
            size: size,
            selected: size == _size,
            onTap: () => setState(() => _size = size),
          ),
      ],
    );
  }

  /// `Guardar` — the Done button's register, full-width accent-soft with
  /// an ink-primary label, and the app's first true disabled control:
  /// until the trimmed line holds text (and while a write is in flight)
  /// the same pill renders at reduced opacity behind `IgnorePointer`
  /// and `Semantics(enabled: false)` — the tap is refused, never
  /// accepted as a silent no-op.
  Widget _saveAction(BuildContext context) {
    final theme = Theme.of(context);
    final canSave = _canSave;
    final pill = SizedBox(
      width: double.infinity,
      child: Material(
        color: theme.colorScheme.primary,
        borderRadius: BorderRadius.circular(Radii.radiusDefault),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: canSave ? _onSave : null,
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              minHeight: Spacing.touchTargetMin,
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: Spacing.chipPaddingHorizontal,
              ),
              child: Center(
                // bodyLarge is the wired action-primary role (theme.dart).
                child: Text(
                  AppStrings.of(context).captureSave,
                  style: theme.textTheme.bodyLarge,
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ),
        ),
      ),
    );
    if (canSave) {
      return Semantics(button: true, child: pill);
    }
    return Semantics(
      button: true,
      enabled: false,
      child: IgnorePointer(
        child: Opacity(opacity: _saveDisabledOpacity, child: pill),
      ),
    );
  }
}

/// One size pill (the `size-option` idiom, the ladder pill's precedent):
/// a duration pill — selected fills `colorScheme.primary` (the theme's
/// accent-soft mapping), unselected sits raised with a 1px hairline
/// edge — ink-primary in the duration role on both, `rounded.full`,
/// 48dp minimum, never a glyph. The label is the size's duration
/// through the format family; the internal taxonomy name never renders.
class _SizeOption extends StatelessWidget {
  const _SizeOption({required this.size, required this.selected, this.onTap});

  final Size size;

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
        onTap: onTap ?? () {},
        child: Semantics(
          // The affordance reaches screen readers as a button carrying
          // selection state, never as a different visual grammar: the
          // spoken label is the duration the pill's own text already
          // carries.
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
                  sizeOptionLabel(size, AppStrings.of(context)),
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

// The Manual Capture surface (Story 3.2, FR-27, Epic 3's floor): exactly
// two fields — one single-line text field and one size from exactly three
// `size-option` pills — and nothing else is asked. No project, no
// category, no date, no priority, no tags, no recurrence, no
// confirmation screen; the copy (the spatial frame's three-step rule,
// read in order) names a place, lists touchable things, and opens
// the example with a spatial verb. A non-spatial line is accepted in
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
// the only path back to it is being dealt (3.3).
//
// The mic capsule (FR-32, Story 3.4) sits at the field's end: the
// 24px microphone glyph inside a 48dp target, the `_LapizEntry`
// pattern. It renders only where the derived visibility says so
// (on-device Spanish recognition available ∧ permission not refused)
// and is simply absent otherwise — no error, no grey state, no
// install offer. A press starts listening through the dictation
// controller; the live state is declared by the blue mass and the
// `Escuchando…` caption alone — never by motion — and only a final
// transcript ever lands, replacing the line's content in the existing
// field so `Guardar` enables through the existing listener. The
// keyboard is never removed: corrections need it, and a correction
// after dictation keeps the capture's `dictated` provenance true.
//
// The 200% floor holds throughout: the surface scrolls
// (`SingleChildScrollView`), nothing truncates, every target sits at
// or above 48dp, and all copy comes through `AppStrings`.
import 'dart:async';

import 'package:core/pool/pool_fact.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../capture/capture_controller.dart';
import '../../capture/dictation_controller.dart';
import '../../strings/app_strings.dart';
import '../dispenser/duration_chip.dart';
import '../dispenser/task_card.dart';
import '../glyphs/microphone_glyph.dart';
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
/// [dictation] (Story 3.4) is the press flow's seam: present, the mic
/// capsule renders wherever its derived visibility says so and a press
/// listens; absent, the field's keyboard capture is the whole surface —
/// the honest test seam.
class CaptureScreen extends StatefulWidget {
  const CaptureScreen({super.key, this.controller, this.dictation});

  final CaptureController? controller;

  /// The dictation seam (Story 3.4, FR-32) — same store, same shared
  /// write queue, threaded the way `capture` is.
  final DictationController? dictation;

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

  /// Whether dictation authored the standing line (FR-32): set when a
  /// final transcript lands, kept through any keyboard correction —
  /// the boolean records who authored the line, not its final wording
  /// — and cleared only by a line that went blank (a fresh line has a
  /// fresh author).
  bool _dictated = false;

  /// The transcript landing guard: the assignment the callback makes
  /// must not read as keyboard authorship in the change listener.
  bool _transcriptLanding = false;

  late final TextEditingController _lineController;

  @override
  void initState() {
    super.initState();
    _lineController = TextEditingController();
    _lineController.addListener(_onLineChanged);
    final dictation = widget.dictation;
    if (dictation != null) {
      // Every surface entry re-derives the affordance's visibility
      // from a fresh probe: one transient `unavailable` start must not
      // retire the capsule for a whole foreground session, and a
      // re-grant made while the app was away restores it here — the
      // probe is never cached (no store exists outside the log).
      unawaited(dictation.refresh());
      // The final transcript replaces the line's content in the
      // existing field (FR-32): the commit point is this assignment,
      // and `Guardar` enables through the field's own listener — no
      // second enable path exists.
      dictation.onTranscript = _onTranscript;
      dictation.addListener(_onDictationChanged);
    }
  }

  @override
  void dispose() {
    final dictation = widget.dictation;
    if (dictation != null) {
      // Unsubscribe first: ending the session may notify, and a
      // disposed state must not hear it.
      dictation.removeListener(_onDictationChanged);
      // Leaving the surface — `Descartar`, the system back,
      // `Guardar`'s pop, every path that ends here — ends any
      // dictation the capsule owned: nothing listens outside an
      // explicit press on this surface (FR-32).
      dictation.surfaceExited();
      if (dictation.onTranscript == _onTranscript) {
        dictation.onTranscript = null;
      }
    }
    _lineController.removeListener(_onLineChanged);
    _lineController.dispose();
    super.dispose();
  }

  void _onTranscript(String transcript) {
    if (!mounted || _saving) {
      // A transcript landing while `Guardar`'s write is in flight
      // replaces nothing: the fact and entry were minted from the
      // line as it stood, and the surface's whole remaining duty is
      // to leave.
      return;
    }
    _transcriptLanding = true;
    _lineController.text = _asOneLine(transcript);
    _transcriptLanding = false;
    _dictated = true;
  }

  /// The line's own single-line invariant, on the paste path's terms:
  /// the field's formatter strips these characters from keyboard
  /// entry, and the landing commit strips them from a transcript — a
  /// programmatic assignment bypasses the formatter, so this is the
  /// same guard in the one place it can be bypassed. Nothing else is
  /// altered. The characters are spelled code-unit-wise because the
  /// string table owns every literal (AD-15).
  static String _asOneLine(String transcript) => String.fromCharCodes(
    transcript.codeUnits.where((codeUnit) => codeUnit != 10 && codeUnit != 13),
  );

  void _onDictationChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  void _onLineChanged() {
    if (!_transcriptLanding && _lineController.text.trim().isEmpty) {
      // A blank line has no author: the next content to land — typed
      // or spoken — authors the capture afresh.
      _dictated = false;
    }
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
    final dictated = _dictated;
    setState(() => _saving = true);
    try {
      await controller.save(_lineController.text, _size, dictated: dictated);
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

  /// The one line of text (FR-27) with the mic capsule at its end
  /// (FR-32, Story 3.4): raised fill, 1px hairline, radius 14, 48dp
  /// minimum — the field's own register, Lora for the content and
  /// Lexend for the hint. Single-line by the TextField's own default,
  /// and a paste can never put interior newlines into the stored Origin
  /// Context: the single-line formatter strips them on entry, so one
  /// line is what the field holds, not what the keyboard happens to
  /// send. No validation, no error surface; the capsule renders only
  /// where the derived visibility says so, and while it listens the
  /// support-style caption below declares the state in prose — the
  /// state is ink and prose only, never motion. The keyboard is never
  /// removed: the focus is never touched from here.
  Widget _field(BuildContext context) {
    final theme = Theme.of(context);
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(Radii.radiusDefault),
      borderSide: BorderSide(color: theme.colorScheme.outline, width: 1),
    );
    final dictation = widget.dictation;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  minHeight: Spacing.touchTargetMin,
                ),
                child: TextField(
                  controller: _lineController,
                  // One line, enforced at the input boundary: a pasted
                  // multi-line string can never put interior newlines
                  // into the stored Origin Context — the formatter
                  // strips them before the controller ever holds them.
                  inputFormatters: [
                    FilteringTextInputFormatter.singleLineFormatter,
                  ],
                  // headlineMedium is the wired task role — the
                  // captured line is content, the one Lora register
                  // (theme.dart).
                  style: theme.textTheme.headlineMedium,
                  decoration: InputDecoration(
                    hintText: AppStrings.of(context).captureFieldPlaceholder,
                    // bodyMedium carries the hint in the Lexend
                    // mechanism register (theme.dart).
                    hintStyle: theme.textTheme.bodyMedium,
                    filled: true,
                    fillColor: theme.colorScheme.surfaceContainerHighest,
                    enabledBorder: border,
                    focusedBorder: border,
                  ),
                ),
              ),
            ),
            if (dictation != null && dictation.visible)
              _MicCapsule(
                dictating: dictation.listening,
                onTap: dictation.press,
              ),
          ],
        ),
        if (dictation != null && dictation.listening)
          Padding(
            padding: const EdgeInsets.only(top: Spacing.chipToTask),
            // bodySmall is the wired support role (theme.dart) — the
            // caption declares the live state in prose and nothing
            // else: no error grammar exists for it to borrow. The
            // live region carries the declaration to TalkBack too —
            // its appearance announces, ink and prose, never motion.
            child: Semantics(
              liveRegion: true,
              child: Text(
                AppStrings.of(context).dictationListening,
                style: theme.textTheme.bodySmall,
              ),
            ),
          ),
      ],
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

/// The mic capsule (Story 3.4, FR-32): the dictation affordance at the
/// field's end — the 24px microphone glyph inside a 48dp opaque target,
/// the `_LapizEntry` pattern (the battery mark's own grammar). One
/// press starts listening; no painted label, no fill, no badge,
/// nothing animated — mass is the visual (neutral at rest, blue while
/// dictating, the glyph's own declaration) and the semantics label is
/// the spoken name. Where recognition is unavailable or the permission
/// refused, the capsule is not here at all: unavailable means absent,
/// never grey.
class _MicCapsule extends StatelessWidget {
  const _MicCapsule({required this.dictating, this.onTap});

  /// Whether an utterance is live — the glyph's own blue-mass
  /// declaration, paired with the `Escuchando…` caption the field
  /// renders beneath.
  final bool dictating;

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: AppStrings.of(context).microphoneEntry,
      child: GestureDetector(
        // Absent, the tap stays an accepted no-op — a null onTap would
        // render a disabled control instead.
        onTap: onTap ?? () {},
        behavior: HitTestBehavior.opaque,
        child: SizedBox(
          width: Spacing.touchTargetMin,
          height: Spacing.touchTargetMin,
          child: Center(
            child: MicrophoneGlyph(
              Spacing.glyphZoneMarker,
              dictating: dictating,
            ),
          ),
        ),
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

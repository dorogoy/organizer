// The typed genesis surface behind `Nuevo proyecto` (Story 5.8,
// FR-11's second entrance, FR-25, UX-DR25): 2.1's honest
// intermediate completed — the description field, `Analizar` as the
// one recommended action, and the quiet bottom row `Volver` +
// `Ajustes`. No heading, no chrome beyond the one action; the
// system back gesture pops.
//
// `Analizar` is the consent act itself (FR-25, NFR4): the send IS
// the consent — no separate dialog, no provider name anywhere on
// the surface, and the body copy states in plain Spanish that the
// description will be analysed to create tasks. The pill stays
// disabled until the trimmed description holds text — `Guardar`'s
// own mirror: the same accent-soft pill at reduced opacity, behind
// `IgnorePointer` and `Semantics(enabled: false)`, refusing the tap
// rather than accepting it silently.
//
// The fail-closed provider read runs at the `Analizar` tap, before
// any row or dispatch — `_continueToConsent`'s mirror
// (`scan_screen.dart`): no read seam or no slicer behind the
// controller (the half-wired test composition) is the quiet pop;
// a selected null or an id the frozen allowlist does not carry
// means the request cannot be made, and the no-key surface replaces
// this route — its reworded copy names both halves, so the photo
// path never steals the typed path's diagnosis.
//
// The wait rides 5.6's semantics unchanged, in the consent gate's
// own grammar: `Creando tareas` beside the indeterminate writing
// pencil, the illustration register — no percentage, duration,
// queue position or timeout anywhere (the wait is deliberately
// uncapped, FR-16). The compose state is gone while it stands —
// field, action and bottom row alike — so no action remains
// tappable and the OS back is the one exit: leaving mid-wait IS
// abandoning, the controller's close mints the departure's one
// `scan_abandoned` row, and a lifecycle departure
// (hidden/paused/detached) closes the wait the same way. A
// transient inactive occlusion holds, never closes. The terminal
// routing: delivered the quiet pop to the Dispenser (the steps land
// as pool facts; the one-card landing is 5.9's), failed the
// standing `noSlicerCauseFromFailure` map, stale the pop (the wait
// already closed).
//
// `Volver` and `Ajustes` coexist (EXPERIENCE.md's own pins): the
// quiet exit beside the Settings way-out, both ink-secondary prose
// — one recommended action plus ways out, the Dispenser footer
// band's own grammar. Settings stays reachable from inside this
// surface and nowhere else (NFR3, AD-26).
import 'dart:async';
import 'dart:math' as math;

import 'package:core/ports/no_slicer_cause.dart';
import 'package:core/slicer/scan_steps.dart' show scanDescriptionTextMost;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../egress/provider_allowlist.dart';
import '../../genesis/genesis_controller.dart';
import '../../settings/settings_controller.dart';
import '../../strings/app_strings.dart';
import '../dispenser/task_card.dart';
import '../no_slicer/no_slicer_surface.dart';
import '../scan/writing_pencil.dart';
import '../tokens.dart';
import 'curation_screen.dart';
import 'settings_screen.dart';

/// The surface's width bound on wide grounds — the capture and scan
/// surfaces' own layout bound (a layout bound, not a gap; the
/// tokenized side rule `Spacing.screenMargin` stays in force below
/// it).
const double _nuevoProyectoMaxWidth = 480;

/// The disabled `Analizar`'s reduced opacity (mockup `.save.dis`):
/// the same accent-soft pill, dimmed — never a different grammar.
const double _analyzeDisabledOpacity = 0.45;

/// The wait's pencil, at the illustration register's own scale —
/// the consent gate's own constant, the register's standing-alone
/// mark.
const double _genesisWaitPencilSize = 160;

/// Limits user input in the same UTF-16 code units the core parser counts.
/// Flutter's stock length formatter counts grapheme clusters, which can let
/// a string exceed the parser's wire bound when it contains supplementary
/// characters.
class _Utf16LengthLimitingTextInputFormatter extends TextInputFormatter {
  const _Utf16LengthLimitingTextInputFormatter(this.maxLength);

  final int maxLength;

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (newValue.text.length <= maxLength) {
      return newValue;
    }

    var end = maxLength;
    if (end > 0 &&
        end < newValue.text.length &&
        _isLowSurrogate(newValue.text.codeUnitAt(end))) {
      end--;
    }
    final text = newValue.text.substring(0, end);
    final baseOffset = _boundOffset(newValue.selection.baseOffset, end);
    final extentOffset = _boundOffset(newValue.selection.extentOffset, end);
    final composingStart = _boundOffset(newValue.composing.start, end);
    final composingEnd = _boundOffset(newValue.composing.end, end);

    return newValue.copyWith(
      text: text,
      selection: TextSelection(
        baseOffset: baseOffset,
        extentOffset: extentOffset,
        affinity: newValue.selection.affinity,
        isDirectional: newValue.selection.isDirectional,
      ),
      composing: composingStart < composingEnd
          ? TextRange(start: composingStart, end: composingEnd)
          : TextRange.empty,
    );
  }

  static bool _isLowSurrogate(int codeUnit) =>
      codeUnit >= 0xDC00 && codeUnit <= 0xDFFF;

  static int _boundOffset(int offset, int length) {
    if (offset < 0) {
      return 0;
    }
    if (offset > length) {
      return length;
    }
    return offset;
  }
}

/// The typed genesis surface (FR-11, FR-25). [settings] is the
/// Settings seam handed down from the Dispenser — the same store
/// instance, threaded through the whole way-out chain. [genesis] is
/// the typed channel the `Analizar` act runs through. Either absent
/// (the test seam), the surface renders whole: the way-out still
/// opens the list with no controller behind it, and an `Analizar`
/// answers nothing.
class NuevoProyectoScreen extends StatefulWidget {
  const NuevoProyectoScreen({super.key, this.settings, this.genesis});

  final SettingsController? settings;

  /// The typed genesis seam (Story 5.8) — same store, same shared
  /// write queue, the one production Slicer threaded in main.
  final GenesisController? genesis;

  @override
  State<NuevoProyectoScreen> createState() => _NuevoProyectoScreenState();
}

class _NuevoProyectoScreenState extends State<NuevoProyectoScreen>
    with WidgetsBindingObserver {
  late final TextEditingController _descriptionController;

  /// Whether the wait stands: the compose state is gone while it
  /// does — field, action and bottom row alike — and no action
  /// remains tappable.
  bool _waiting = false;

  /// The `Analizar` act's in-flight guard, set synchronously at the
  /// tap — the capture surface's `_saving` idiom: one tap owns the
  /// surface until its flow settles, so a rapid second tap (the
  /// provider read still standing) is nothing at all — no second
  /// read, no second dispatch, no stale pop racing the first.
  ///
  /// The guard never resets past the dispatch, by invariant rather
  /// than by `finally`: every post-dispatch path EXITS the surface
  /// (pop, pushReplacement, unmount) — the wait owns it until a
  /// resolution routes. The one reset is the pre-dispatch abort
  /// below (route lost or real departure during the read), which
  /// hands the compose state back. A future path that keeps the
  /// surface after the dispatch must own its own reset or brick
  /// the pill.
  bool _analyzing = false;

  /// A real departure (hidden/paused/detached) has stood since the
  /// compose state last owned the surface — the observer's close
  /// arm sets it. Read only in the pre-dispatch window: a departure
  /// between the `Analizar` tap and the dispatch ends the act before
  /// it starts, so no egress ever rides a departure (the wait's own
  /// abandonment rule, held one window earlier).
  bool _departed = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _descriptionController = TextEditingController();
    _descriptionController.addListener(_onDescriptionChanged);
  }

  @override
  void dispose() {
    // Every exit path ends the channel's wait: the OS back (leaving
    // mid-wait is abandoning, and the close mints the row), the
    // terminal routings' replacement, the delivered arm's pop — and
    // a resolution that already ended the wait makes this a quiet
    // no-op, the close idempotent.
    WidgetsBinding.instance.removeObserver(this);
    unawaited(widget.genesis?.close());
    _descriptionController.removeListener(_onDescriptionChanged);
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.hidden:
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
        // A real departure closes the wait (the consent gate's own
        // release contract): the dispatch left standing resolves
        // stale, with its one `scan_abandoned` row minted by the
        // close itself, the departure being the resolution cause.
        // Close is idempotent — a wait that already resolved makes
        // this a quiet no-op. The flag the pre-dispatch window
        // reads stands too: a departure before the dispatch means
        // the act never starts, dispatch or no dispatch.
        _departed = true;
        unawaited(widget.genesis?.close());
      case AppLifecycleState.resumed:
        // A departure while the surface was idle must not brick the next
        // act. Keep the flag during an active read or wait so a real
        // departure cannot be turned into a dispatch by the resume event.
        if (!_analyzing && !_waiting) {
          _departed = false;
        }
        break;
      case AppLifecycleState.inactive:
        // The transient occlusion holds: a system dialog or the
        // notification shade is not a departure, and nothing closes
        // beneath it.
        break;
    }
  }

  void _onDescriptionChanged() {
    // Only the pill's enablement reads the line; the wait owns the
    // surface while it stands.
    if (mounted && !_waiting) {
      setState(() {});
    }
  }

  bool get _canAnalyze =>
      widget.genesis != null &&
      !_waiting &&
      _descriptionController.text.trim().isNotEmpty;

  /// The `Analizar` tap (FR-25): the fail-closed provider read runs
  /// first, before any row or dispatch — the request a consent act
  /// authorizes must be one that can be made. Then the send IS the
  /// consent: one `consent_granted` row, one dispatch, the wait —
  /// and the outcome routes. A rapid second tap is nothing at all:
  /// the wait owns the surface the frame the tap lands.
  Future<void> _onAnalyze() async {
    if (_analyzing || !_canAnalyze) {
      return;
    }
    final controller = widget.genesis;
    if (controller == null) {
      // The null-controller test seam: the pill renders disabled
      // (`_canAnalyze`) and this belt never runs — the honest
      // nothing, refused visibly rather than silently swallowed.
      return;
    }
    // One tap owns the surface from here — synchronously, before the
    // first await.
    _analyzing = true;
    final description = _descriptionController.text.trim();
    final read = controller.readSelectedProvider;
    if (read == null || controller.slicer == null) {
      // Nothing half-wired dispatches: the quiet pop every closed
      // channel takes (the gate seam's own rule).
      Navigator.of(context).pop();
      return;
    }
    String? providerId;
    try {
      providerId = await read();
    } on Object {
      // The read failed closed: the same quiet pop the gate seam
      // takes — but only while this route still owns the navigator;
      // a route pushed above keeps its own stack, and popping here
      // would pop THAT route instead.
      if (mounted && (ModalRoute.of(context)?.isCurrent ?? false)) {
        Navigator.of(context).pop();
      } else if (mounted) {
        setState(() => _analyzing = false);
      }
      return;
    }
    if (!mounted) {
      return;
    }
    // The pre-dispatch window's two ends: a real departure or a
    // route pushed above during the read ends the act BEFORE it
    // starts — no consent row, no dispatch, no navigation. The
    // compose state takes the surface back; the tap is spent, not
    // queued.
    if (_departed || !(ModalRoute.of(context)?.isCurrent ?? false)) {
      setState(() => _analyzing = false);
      return;
    }
    final selected = providerId;
    if (selected == null || allowlistEntryById(selected) == null) {
      // No key stands behind a request that cannot be made: the
      // no-key surface replaces this route, its reworded copy
      // naming both halves — never a consent asked for a request
      // that cannot go.
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) =>
              const NoSlicerSurface(cause: NoSlicerCause.noKey),
        ),
      );
      return;
    }
    setState(() => _waiting = true);
    final outcome = await controller.analyze(description);
    if (!mounted) {
      return;
    }
    // A route pushed above the wait (there is none this surface
    // owns — the compose state is gone — but the navigator's stack
    // is not this surface's to assume): navigate nothing beneath
    // another route. The wait is over either way; the compose state
    // returns, and the act can be taken again — the controller's
    // own fresh-analyze discipline.
    if (!(ModalRoute.of(context)?.isCurrent ?? false)) {
      setState(() {
        _waiting = false;
        _analyzing = false;
      });
      return;
    }
    switch (outcome) {
      case GenesisDelivered():
        // The landed facts' quiet pop: the steps are pool facts now —
        // no surface shows them yet (5.9 owns the one-card landing),
        // so the channel closes to the Dispenser with nothing dealt.
        Navigator.of(context).pop();
      case GenesisFailed(:final cause):
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) =>
                NoSlicerSurface(cause: noSlicerCauseFromFailure(cause)),
          ),
        );
      case GenesisStale():
        // The wait already closed — the departure's row already
        // stands: pop instead of stranding the answer on the
        // untappable wait.
        Navigator.of(context).pop();
    }
  }

  /// The `Volver` tap: the quiet exit — one tap, no confirmation, no
  /// writes; the system back gesture behaves identically. While the
  /// wait owns the surface the control is not on it at all.
  void _onBack() {
    Navigator.of(context).pop();
  }

  /// The `Ajustes` tap — the way-out's own push, the same rapid-tap
  /// guard as before: a push while another route transitions in
  /// would stack a second route.
  void _openSettings() {
    if (ModalRoute.of(context)?.isCurrent ?? false) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => SettingsScreen(controller: widget.settings),
        ),
      );
    }
  }

  /// The quiet curation entry's push (Story 5.12, E1, FR-31): the
  /// same rapid-tap guard as `_openSettings` — the E1 surface is
  /// `CurationScreen` under the house title, over the same Settings
  /// seam this surface already holds. No confirmation, no writes on
  /// the push itself: the eight rows and their one write funnel are
  /// the surface's own, and the compose surface stands beneath until
  /// the route pops back.
  void _openHouseGroups() {
    if (ModalRoute.of(context)?.isCurrent ?? false) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => CurationScreen(
            controller: widget.settings,
            title: AppStrings.of(context).curationHouseGroups,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final strings = AppStrings.of(context);
    return Scaffold(
      // No heading, no chrome: the standard surfaceBase frame. The
      // safe area is consumed once, by the footer band — the
      // dispenser footer's own pattern — and the compose content
      // scrolls above it at the 200% floor (the surface grows and
      // scrolls, never truncates).
      body: Column(
        children: [
          Expanded(
            child: _waiting
                ? _waitBody(theme, strings)
                : _composeBody(theme, strings),
          ),
          if (!_waiting)
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: Spacing.screenMargin,
                ),
                // The quiet bottom row: `Volver` beside `Ajustes`,
                // both ink-secondary prose in the dispenser footer
                // band's own grammar — neither recommended, one
                // recommended action above them.
                child: Wrap(
                  alignment: WrapAlignment.center,
                  spacing: Spacing.actionGap,
                  runSpacing: Spacing.spacingBase,
                  children: [
                    SecondaryTextAction(
                      label: strings.genesisBack,
                      onTap: _onBack,
                    ),
                    SecondaryTextAction(
                      label: strings.settingsWayOut,
                      onTap: _openSettings,
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// The compose state: the body copy stating analysis→tasks with no
  /// provider name, the description field, and `Analizar` — the one
  /// recommended action, the `Guardar` pill register.
  Widget _composeBody(ThemeData theme, AppStrings strings) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(
        horizontal: Spacing.screenMargin,
        vertical: Spacing.touchTargetMin,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: _nuevoProyectoMaxWidth),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // The whole ask, in the calm register: what happens to
              // the description — analysis, tasks — with the
              // destination stated and the provider unnamed (FR-25,
              // NFR4).
              Text(
                strings.genesisBody,
                style: theme.textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: Spacing.taskToActions),
              _field(theme, strings),
              const SizedBox(height: Spacing.cardPadding),
              _analyzeAction(theme, strings),
              const SizedBox(height: Spacing.taskToActions),
              // The quiet curation entry (Story 5.12, E1, FR-31): the
              // complement to typed entry — one unsplit secondary
              // prose line below the recommended action, never in the
              // wait body and never a third way out. The label is the
              // pushed surface's own header, 5.11's
              // entry-label-equals-header idiom.
              SecondaryTextAction(
                label: strings.curationHouseGroups,
                onTap: _openHouseGroups,
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// The description field (FR-11): the capture surface's own
  /// register — raised fill, 1px hairline, radius 14, 48dp floor —
  /// one line by the formatter, no validation, no error state: a
  /// blank description is the disabled pill's to refuse, never a
  /// red edge's.
  Widget _field(ThemeData theme, AppStrings strings) {
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(Radii.radiusDefault),
      borderSide: BorderSide(color: theme.colorScheme.outline, width: 1),
    );
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: Spacing.touchTargetMin),
      child: TextField(
        controller: _descriptionController,
        // One line, enforced at the input boundary — the capture
        // field's own guard — and one length bound: the description
        // that rides the egress payload is capped at the contract's
        // own description bound (`scanDescriptionTextMost`, the
        // in-family constant the response's Origin Context already
        // carries — NFR4's minimum: what leaves is bounded here, at
        // the input, before the payload is ever composed). A
        // formatter, not `maxLength`: no counter ever renders.
        inputFormatters: [
          FilteringTextInputFormatter.singleLineFormatter,
          _Utf16LengthLimitingTextInputFormatter(scanDescriptionTextMost),
        ],
        // The keyboard's Done is the pill's own act — the surface
        // exists for this field, so the natural flow (type, Done)
        // must not dead-end at a keyboard that does nothing;
        // `_onAnalyze` re-guards everything itself.
        textInputAction: TextInputAction.done,
        onSubmitted: (_) => _onAnalyze(),
        // headlineMedium is the wired task role — the description is
        // content, the one Lora register (theme.dart).
        style: theme.textTheme.headlineMedium,
        decoration: InputDecoration(
          hintText: strings.genesisFieldHint,
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

  /// `Analizar` — the Done button's register, full-width
  /// accent-soft with an ink-primary label, and the consent act
  /// itself: until the trimmed description holds text — or behind
  /// the null-controller test seam — the same pill
  /// renders at reduced opacity behind `IgnorePointer` and
  /// `Semantics(enabled: false)` — the tap is refused, never
  /// accepted as a silent no-op (`Guardar`'s own mirror).
  Widget _analyzeAction(ThemeData theme, AppStrings strings) {
    final canAnalyze = _canAnalyze;
    final pill = SizedBox(
      width: double.infinity,
      child: Material(
        color: theme.colorScheme.primary,
        borderRadius: BorderRadius.circular(Radii.radiusDefault),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: canAnalyze ? _onAnalyze : null,
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              minHeight: Spacing.touchTargetMin,
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: Spacing.chipPaddingHorizontal,
              ),
              child: Center(
                // bodyLarge is the wired action-primary role
                // (theme.dart).
                child: Text(
                  strings.genesisAnalyze,
                  style: theme.textTheme.bodyLarge,
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ),
        ),
      ),
    );
    if (canAnalyze) {
      return Semantics(button: true, child: pill);
    }
    return Semantics(
      button: true,
      enabled: false,
      child: IgnorePointer(
        child: Opacity(opacity: _analyzeDisabledOpacity, child: pill),
      ),
    );
  }

  /// The wait (5.6's semantics, the consent gate's own grammar):
  /// `Creando tareas` beside the indeterminate writing pencil, the
  /// illustration register's mark standing alone — nothing here
  /// reads as percentage, duration, queue position or timeout, and
  /// no action remains on the surface: the OS back is the one exit.
  Widget _waitBody(ThemeData theme, AppStrings strings) {
    return Center(
      child: LayoutBuilder(
        builder: (context, constraints) {
          // The pair stands centered; below the width where the
          // register size fits beside a wrapped title the PENCIL
          // yields, so `beside` holds at every width and nothing
          // overflows horizontally — the consent gate's own
          // decision.
          final pencil = math.max(
            24.0,
            math.min(
              _genesisWaitPencilSize,
              (constraints.maxWidth - Spacing.cardPadding) / 2,
            ),
          );
          return Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              WritingPencil(size: pencil),
              const SizedBox(width: Spacing.cardPadding),
              Flexible(
                child: Text(
                  strings.scanWaitTitle,
                  style: theme.textTheme.bodyMedium,
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// The no-Slicer surface (Story 4-5, FR-29): ONE calm surface that
// carries whichever of the seven causes the moment produced, plus a
// single exit — not seven visual states. Copy alone distinguishes the
// causes: the layout, type styling and text-only illustration
// treatment are byte-identical across all seven, and nothing on the
// surface reads as an error — no red, no warning iconography, no
// exclamation mark, no error semantics (the theme admits no alarm
// register at all). The full-screen illustration register is honored
// text-only on the recorded 2-7/2-4 precedent (DESIGN.md:548 —
// "permission, not mandate"; no illustration asset exists to draw).
//
// The exit is `Anotarlo`, in the Done button's register, to Manual
// Capture — input-method-neutral by construction because the
// destination surface carries the microphone (FR-32): the label hands
// nothing to typing or dictation, and the exit works in all seven
// states including no-network (the push is local navigation, never
// egress). The system back gesture stays the OS pop — no `PopScope`
// dead-end, no styled second exit, no Ajustes action: the pointer to
// Ajustes lives inside the config-family strings themselves, as copy,
// never as a control. Nothing is queued, retried or persisted when the
// surface renders or leaves: it holds no state beyond the immutable
// cause it was handed.
//
// This story ships the surface with no production trigger, the 4-2/4-4
// pattern: Rescue Mode (4-6) pushes it when a re-slice finds no
// Slicer, and Epic 5's scan and genesis paths push it for the
// pre-request refusals — the callers arrive later, over this same
// grammar.
import 'package:core/ports/no_slicer_cause.dart';
import 'package:flutter/material.dart';

import '../../capture/capture_controller.dart';
import '../../capture/dictation_controller.dart';
import '../../strings/app_strings.dart';
import '../capture/capture_screen.dart';
import '../dispenser/task_card.dart';
import '../tokens.dart';

/// The surface's width bound on wide grounds — CaptureScreen's own
/// layout bound (a layout bound, not a gap; the tokenized side rule
/// `Spacing.screenMargin` stays in force below it).
const double _noSlicerMaxWidth = 480;

/// The no-Slicer surface (FR-29). [cause] is the immutable fact this
/// surface renders — the only state it holds. [controller] and
/// [dictation] are the Manual Capture seams, threaded into the exit's
/// push exactly as the Dispenser's Lápiz entry threads them; absent
/// (the test seam), the exit still opens Manual Capture with no
/// controller behind it.
class NoSlicerSurface extends StatelessWidget {
  const NoSlicerSurface({
    super.key,
    required this.cause,
    this.controller,
    this.dictation,
  });

  final NoSlicerCause cause;

  /// The Manual Capture write seam — same store, same shared write
  /// queue, threaded through the exit.
  final CaptureController? controller;

  /// The dictation seam — same store, same shared write queue, so the
  /// exit's destination carries the microphone from the start.
  final DictationController? dictation;

  /// The single exit's push — `_openCapture`'s grammar copied verbatim
  /// from the Dispenser's Lápiz entry: the same rapid-tap guard (a
  /// push while another route transitions in would stack a second
  /// route), the same `MaterialPageRoute`, the same threaded seams, no
  /// confirmation and no writes.
  void _openCapture(BuildContext context) {
    if (ModalRoute.of(context)?.isCurrent ?? false) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) =>
              CaptureScreen(controller: controller, dictation: dictation),
        ),
      );
    }
  }

  /// The cause's string through the generated accessor — the only
  /// differentiator on the surface. Exhaustive with no default arm:
  /// an eighth cause is a compile error here, and the seven values
  /// render verbatim (pinned by equality in the surface's tests).
  static String _causeString(AppStrings strings, NoSlicerCause cause) =>
      switch (cause) {
        NoSlicerCause.noKey => strings.noSlicerNoKey,
        NoSlicerCause.invalidKey => strings.noSlicerInvalidKey,
        NoSlicerCause.quotaExhausted => strings.noSlicerQuotaExhausted,
        NoSlicerCause.unreachable => strings.noSlicerUnreachable,
        NoSlicerCause.offline => strings.noSlicerOffline,
        NoSlicerCause.consentDeclined => strings.noSlicerConsentDeclined,
        NoSlicerCause.personInFrame => strings.personInFrame,
      };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // The standard surfaceBase frame, centered, CaptureScreen's own
      // grammar: SafeArea first so scrolled content never renders
      // under the status bar or a cutout, screen margins on the sides,
      // the 200% floor holding through SingleChildScrollView — the
      // cause string grows and the surface scrolls, never truncates.
      // No PopScope: the system back gesture is the OS pop, and
      // nothing is queued on departure.
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(
            horizontal: Spacing.screenMargin,
            vertical: Spacing.touchTargetMin,
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: _noSlicerMaxWidth),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // The whole content: the cause's pinned string, in
                  // the warm close's own register — centered, quiet,
                  // the secondary ink — never an error and never
                  // styled as the user's omission or as pending work.
                  // This one Text is the text-only illustration
                  // register's entire holding.
                  Text(
                    _causeString(AppStrings.of(context), cause),
                    // bodyMedium is the wired action-secondary role —
                    // the warm close's role and ink (theme.dart).
                    style: Theme.of(context).textTheme.bodyMedium,
                    textAlign: TextAlign.center,
                  ),
                  // The pause between reading and leaving — the same
                  // largest interior gap the dispenser card holds
                  // between its task and its actions.
                  const SizedBox(height: Spacing.taskToActions),
                  // The one exit: `Anotarlo` in the Done button's
                  // register (HechoButton's own grammar), full-width
                  // accent-soft, minimum 48dp. No second control of
                  // any register exists on this surface.
                  HechoButton(
                    label: AppStrings.of(context).noSlicerExit,
                    onTap: () => _openCapture(context),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

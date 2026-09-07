// The writing pencil (Story 5.6, FR-16, UX-DR56): the unbounded
// wait's one motion — an indeterminate pencil writing beside
// `Creando tareas`, so activity is never mistaken for a stall. This
// is the app's FIRST and only sanctioned animation, and it leaks no
// conventions: no animation package (the pencil is hand-built on the
// glyph discipline), no motion DESIGN token (the one behavior
// constant — the loop's period — lives here beside its only reader,
// the `_completionAckWindow` precedent), no Semantics (the spine's
// interim no-custom-semantics rule; the app-wide a11y pass is 5.5's
// recorded deferral), and no dash arcs — the seed's motion-dash
// dissolve stands.
//
// Indeterminate by construction: the loop repeats forever over a
// fixed writing gesture and encodes nothing — no percentage, no
// duration, no queue position, no timeout may be read from it
// (UX-DR56, the deliberately uncapped wait). Reduced motion honors
// the OS setting at the mechanism level — the loop stops, not merely
// renders still, and phase zero IS the authored pencil's resting
// pose, so the title alone still communicates activity.
//
// The drawing is the authored `PencilGlyph` (pencil_glyph.dart)
// under the shared two-plate treatment (glyph_canvas.dart): flat
// neutral mass under the ink line, displaced by the one global 45°
// vector — the pencil's own axis, so the offset is strictly axial —
// the whole geometry authored in the 24-unit viewBox and scaled by
// the render size, the line weight the treatment's own constant
// 1.5 px. The geometry itself is single-sourced from the glyph side:
// the painter consumes PencilGlyph's static builders, and the
// phase-independent paths are built once and cached — the phase
// moves BOTH plates together along the axis with a small wobble
// about the center (a writing gesture, never a transformation of
// the mark itself).
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../tokens.dart';
import '../glyphs/glyph_canvas.dart';
import '../glyphs/pencil_glyph.dart';

/// The writing loop's period (UX-DR56): one full gesture cycle — a
/// calm handwriting cadence, far from anything that could read as a
/// countdown. A behavior constant, not a DESIGN token, so it lives
/// here beside its only reader.
const Duration _pencilLoopPeriod = Duration(milliseconds: 2400);

/// The gesture's glide amplitude, in viewBox units — the pencil
/// travels 1.3u of its own 19.06-unit length (shaft 13.4 + tip 5.66)
/// ≈ 7% along the axis at each extreme of a half-cycle.
const double _glideAmplitudeU = 1.3;

/// The gesture's wobble about the viewBox center, in degrees — the
/// small pivot a hand makes around the paper.
const double _wobbleDegrees = 3;

/// The wobble's phase offset ahead of the glide, in radians: at a
/// third of a cycle the pivot leads and trails the travel, so the
/// gesture never reads as one rigid pendulum swing.
const double _wobblePhaseOffset = math.pi / 3;

/// The indeterminate writing pencil — the wait surface's one motion.
/// [size] is the rendered side length in logical pixels, the glyph
/// set's own convention: the drawing is authored in the 24-unit
/// viewBox and scaled whole. Honors `MediaQuery.disableAnimations`
/// with the authored resting pose; carries no semantics of its own.
class WritingPencil extends StatefulWidget {
  const WritingPencil({super.key, required this.size}) : assert(size > 0);

  /// Rendered side length in logical pixels.
  final double size;

  @override
  State<WritingPencil> createState() => _WritingPencilState();
}

class _WritingPencilState extends State<WritingPencil>
    with SingleTickerProviderStateMixin {
  late final AnimationController _phase = AnimationController(
    vsync: this,
    duration: _pencilLoopPeriod,
  );

  // No repeat() here: didChangeDependencies always runs between
  // initState and the first build and owns the loop's whole
  // lifecycle from the MediaQuery — an already-reduced-motion user
  // must never get a started-then-stopped ticker.

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // The OS setting is honored at the mechanism level: a disabled
    // animation schedules no frames at all — stopped, never merely
    // rendered still.
    if (MediaQuery.disableAnimationsOf(context)) {
      _phase.stop();
    } else if (!_phase.isAnimating) {
      _phase.repeat();
    }
  }

  @override
  void dispose() {
    _phase.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final (mass, ink) = glyphPlates(
      context,
      lightMass: IconMassPalette.iconMassNeutral,
      darkMass: DarkPalette.iconMassNeutralDark,
    );
    // The RepaintBoundary pins the 60 fps tick inside the pencil's
    // own layer — the gate's text and pair never repaint beside it.
    if (MediaQuery.disableAnimationsOf(context)) {
      // The resting pose: phase zero is the authored pencil itself.
      return RepaintBoundary(
        child: CustomPaint(
          size: Size.square(widget.size),
          painter: WritingPencilPainter(
            scale: widget.size / 24,
            phase: 0,
            massColor: mass,
            lineColor: ink,
          ),
        ),
      );
    }
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _phase,
        builder: (context, _) => CustomPaint(
          size: Size.square(widget.size),
          painter: WritingPencilPainter(
            scale: widget.size / 24,
            phase: _phase.value,
            massColor: mass,
            lineColor: ink,
          ),
        ),
      ),
    );
  }
}

/// Paints the pencil under the glyph discipline at [phase] — the
/// writing gesture applied to the authored geometry. Phase 0 is the
/// authored `PencilGlyph` exactly; the loop never rests there by
/// meaning anything (a stopped controller's pose is the OS setting's
/// answer, not a progress value).
class WritingPencilPainter extends CustomPainter {
  WritingPencilPainter({
    required this.scale,
    required this.phase,
    required this.massColor,
    required this.lineColor,
  });

  /// render_px / 24: the user-unit scale.
  final double scale;

  /// The loop's phase, 0–1 — indeterminate, encoding nothing.
  final double phase;

  final Color massColor;
  final Color lineColor;

  /// Paths of the colour plate, filled, no stroke, under the line
  /// layer — the authored shaft, built once and shared by every
  /// painter instance and tick (the gesture moves the canvas, never
  /// the paths, so the phase-independent drawing never rebuilds).
  static final List<Path> _massPaths = [PencilGlyph.shaftPath()];

  /// Paths of the line layer, stroked with round caps and joins —
  /// the authored outline, tip and ferrule, cached on the same terms.
  static final List<Path> _linePaths = PencilGlyph.linePaths();

  @override
  void paint(Canvas canvas, Size size) {
    final sweep = 2 * math.pi * phase;
    final glide = math.sin(sweep);
    final wobble =
        (math.sin(sweep + _wobblePhaseOffset) - math.sin(_wobblePhaseOffset)) *
        _wobbleDegrees;

    canvas.save();
    canvas.scale(scale, scale);
    // The gesture moves both plates together — the pencil itself
    // travels, the treatment never re-composes.
    canvas.translate(
      PencilGlyph.axisX * _glideAmplitudeU * glide,
      PencilGlyph.axisY * _glideAmplitudeU * glide,
    );

    canvas.save();
    // The one GLOBAL, screen-space offset vector (glyph_canvas's
    // own rule), applied before the gesture's wobble so the mass's
    // displacement stays along the screen 45° — the pencil's own
    // axis, strictly axial.
    canvas.translate(glyphOffsetU, -glyphOffsetU);
    _wobbleAboutCenter(canvas, wobble);
    final massPaint = Paint()
      ..color = massColor
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;
    for (final path in _massPaths) {
      canvas.drawPath(path, massPaint);
    }
    canvas.restore();

    canvas.save();
    _wobbleAboutCenter(canvas, wobble);
    final linePaint = Paint()
      ..color = lineColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = glyphStrokeWidthU(scale * 24)
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..isAntiAlias = true;
    for (final path in _linePaths) {
      canvas.drawPath(path, linePaint);
    }
    canvas.restore();

    canvas.restore();
  }

  void _wobbleAboutCenter(Canvas canvas, double degrees) {
    if (degrees == 0) {
      return;
    }
    canvas.translate(12, 12);
    canvas.rotate(degrees * math.pi / 180);
    canvas.translate(-12, -12);
  }

  @override
  // The phase changes every tick and Path has no value equality —
  // the treatment's own always-repaint rule (glyph_canvas.dart); the
  // cached paths make each repaint trivially cheap.
  bool shouldRepaint(covariant WritingPencilPainter oldDelegate) => true;
}

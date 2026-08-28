// The shared two-plate treatment of the ten-glyph set
// (DESIGN.md {components.icon-glyph}): a flat colour mass with no stroke,
// and above it the line layer in ink — the mass always under the line,
// displaced by the one global vector, never registered inside its outline.
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../tokens.dart';

/// The one global offset vector: 8% of the 24 viewBox, 45° up-right,
/// decomposed to translate(+1.358, −1.358) in user units. Never a fixed dp
/// offset, never a per-icon vector.
const double glyphOffsetU = 1.358;

/// stroke-width(u) = target_px × 24 / render_px, targeting 1.5px at 24px.
double glyphStrokeWidthU(double renderPx) => 1.5 * 24 / renderPx;

/// Resolves a glyph's two plate colours for the current brightness. The
/// destination trio keeps the light form in dark mode — two plates, the
/// global offset, mass under line — in the dark trio's hues
/// ({components.destination-mark-dark}).
(Color mass, Color ink) glyphPlates(
  BuildContext context, {
  required Color lightMass,
  required Color darkMass,
}) {
  final dark = Theme.of(context).brightness == Brightness.dark;
  return (
    dark ? darkMass : lightMass,
    dark ? DarkPalette.inkPrimaryDark : FieldPalette.inkPrimary,
  );
}

/// Paints one glyph under the shared treatment. All geometry is authored in
/// the 24-unit viewBox and scaled by [TreatmentPainter.scale].
class TreatmentPainter extends CustomPainter {
  TreatmentPainter({
    required this.scale,
    required this.massColor,
    required this.lineColor,
    required this.massPaths,
    required this.linePaths,
    this.inkFillPaths = const [],
    this.registeredMass = false,
    this.rotationDegrees = 0,
  });

  /// render_px / 24: the user-unit scale.
  final double scale;

  final Color massColor;
  final Color lineColor;

  /// Paths of the colour plate, filled, no stroke, under the line layer.
  final List<Path> massPaths;

  /// Paths of the line layer, stroked with round caps and joins.
  final List<Path> linePaths;

  /// Paths filled in the line layer's ink (the seed's filled achene).
  final List<Path> inkFillPaths;

  /// A mass whose axis contradicts the global vector, or that sits inside a
  /// closed container, is REGISTERED: the offset does not apply (the
  /// batería's charge, the Micrófono capsule). Misregistering either would
  /// read as a leak.
  final bool registeredMass;

  /// Whole-drawing rotation — the seed's +8°, which sets its axis to 45.0°
  /// so the transverse component of the offset is exactly 0.
  final double rotationDegrees;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(scale, scale);

    if (massPaths.isNotEmpty) {
      canvas.save();
      // The offset is the one GLOBAL, screen-space vector — applied
      // before the whole-drawing rotation so a rotated glyph's mass still
      // displaces along the screen 45° vector. Applied after the rotation
      // it would rotate with the drawing: the seed's mass would displace
      // at 53° on screen, re-introducing exactly the transverse component
      // DESIGN.md's +8° correction removed (the axial rule).
      if (!registeredMass) {
        canvas.translate(glyphOffsetU, -glyphOffsetU);
      }
      _rotate(canvas);
      final massPaint = Paint()
        ..color = massColor
        ..style = PaintingStyle.fill
        ..isAntiAlias = true;
      for (final path in massPaths) {
        canvas.drawPath(path, massPaint);
      }
      canvas.restore();
    }

    canvas.save();
    _rotate(canvas);
    final linePaint = Paint()
      ..color = lineColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = glyphStrokeWidthU(scale * 24)
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..isAntiAlias = true;
    for (final path in linePaths) {
      canvas.drawPath(path, linePaint);
    }
    final fillPaint = Paint()
      ..color = lineColor
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;
    for (final path in inkFillPaths) {
      canvas.drawPath(path, fillPaint);
    }
    canvas.restore();

    canvas.restore();
  }

  void _rotate(Canvas canvas) {
    if (rotationDegrees == 0) {
      return;
    }
    canvas.translate(12, 12);
    canvas.rotate(rotationDegrees * math.pi / 180);
    canvas.translate(-12, -12);
  }

  @override
  // The paths are rebuilt on every widget build (painterFor constructs
  // fresh Path instances), and Path has no value equality — inputs such as
  // the battery's level change the paths without changing any compared
  // field. Repainting a few paths is trivially cheap, so the painter
  // always repaints rather than risk a stale render.
  bool shouldRepaint(covariant TreatmentPainter oldDelegate) => true;
}

/// Base of every glyph widget: one 24-viewBox drawing under the shared
/// treatment, rendered at [size] render pixels.
abstract class IconGlyph extends StatelessWidget {
  const IconGlyph(this.size, {super.key}) : assert(size > 0);

  /// Rendered side length in logical pixels.
  final double size;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(size: Size.square(size), painter: painterFor(context));
  }

  TreatmentPainter painterFor(BuildContext context);
}

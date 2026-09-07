// Lápiz — the manual-entry affordance (utility glyph, neutral mass). Its
// axis is already 45° up-right, so the mass slides along its length and
// crosses 0% of its width — strictly axial, no exception needed.
//
// The drawing's geometry lives HERE and nowhere else (Story 5.6's
// single-sourcing rule, arrived at in review): the wait's
// WritingPencilPainter consumes these same static builders, so the
// static pencil IS the wait's resting pose — one drawing, two
// readers, zero drift.
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../tokens.dart';
import 'glyph_canvas.dart';

class PencilGlyph extends IconGlyph {
  const PencilGlyph(super.size, {super.key});

  /// The pencil's axial unit, x — cos(−45°), 45° up-right: the same
  /// direction as the global offset vector, so the mass's
  /// displacement is strictly axial.
  static double get axisX => math.cos(-math.pi / 4);

  /// The pencil's axial unit, y — sin(−45°).
  static double get axisY => math.sin(-math.pi / 4);

  /// The perpendicular unit's x — offsets by half a width.
  static const double _perpendicularX = 0.70710678;

  /// The perpendicular unit's y.
  static const double _perpendicularY = 0.70710678;

  /// The eraser end S, x — the axis origin.
  static const double _eraserX = 4.6;

  /// The eraser end S, y.
  static const double _eraserY = 19.4;

  /// The shaft's length along the axis, to the tip base T0.
  static const double _shaftLength = 13.4;

  /// The tip's length beyond T0, to the point P.
  static const double _tipLength = 5.66;

  /// Half the pencil's width — the perpendicular offset.
  static const double _halfWidth = 1.7;

  /// The ferrule's distance along the axis from the eraser end.
  static const double _ferruleAt = 2.2;

  /// The point [distance] user units along the axis from the eraser
  /// end.
  static Offset _alongAxis(double distance) =>
      Offset(_eraserX + axisX * distance, _eraserY + axisY * distance);

  /// [point] offset half a width along the perpendicular's positive
  /// direction.
  static Offset _plusPerpendicular(Offset point) => Offset(
    point.dx + _perpendicularX * _halfWidth,
    point.dy + _perpendicularY * _halfWidth,
  );

  /// [point] offset half a width along the perpendicular's negative
  /// direction.
  static Offset _minusPerpendicular(Offset point) => Offset(
    point.dx - _perpendicularX * _halfWidth,
    point.dy - _perpendicularY * _halfWidth,
  );

  /// The shaft's rectangle, eraser end to tip base — the colour
  /// plate's whole holding, filled, no stroke.
  static Path shaftPath() {
    final t0 = _alongAxis(_shaftLength);
    final s = Offset(_eraserX, _eraserY);
    final sPlus = _plusPerpendicular(s);
    final sMinus = _minusPerpendicular(s);
    final t0Plus = _plusPerpendicular(t0);
    final t0Minus = _minusPerpendicular(t0);
    return Path()
      ..moveTo(sPlus.dx, sPlus.dy)
      ..lineTo(t0Plus.dx, t0Plus.dy)
      ..lineTo(t0Minus.dx, t0Minus.dy)
      ..lineTo(sMinus.dx, sMinus.dy)
      ..close();
  }

  /// The line layer: the shaft's outline, the tip's two edges meeting
  /// at the point, and the ferrule's cross line — stroked with round
  /// caps and joins.
  static List<Path> linePaths() {
    final shaft = shaftPath();
    final t0 = _alongAxis(_shaftLength);
    final tipPoint = _alongAxis(_shaftLength + _tipLength);
    final ferrule = _alongAxis(_ferruleAt);
    return [
      Path()..addPath(shaft, Offset.zero),
      Path()
        ..moveTo(_plusPerpendicular(t0).dx, _plusPerpendicular(t0).dy)
        ..lineTo(tipPoint.dx, tipPoint.dy)
        ..lineTo(_minusPerpendicular(t0).dx, _minusPerpendicular(t0).dy),
      Path()
        ..moveTo(_plusPerpendicular(ferrule).dx, _plusPerpendicular(ferrule).dy)
        ..lineTo(
          _minusPerpendicular(ferrule).dx,
          _minusPerpendicular(ferrule).dy,
        ),
    ];
  }

  @override
  TreatmentPainter painterFor(BuildContext context) {
    final (mass, ink) = glyphPlates(
      context,
      lightMass: IconMassPalette.iconMassNeutral,
      darkMass: DarkPalette.iconMassNeutralDark,
    );

    return TreatmentPainter(
      scale: size / 24,
      massColor: mass,
      lineColor: ink,
      massPaths: [shaftPath()],
      linePaths: linePaths(),
    );
  }
}

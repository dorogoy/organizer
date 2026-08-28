// Lápiz — the manual-entry affordance (utility glyph, neutral mass). Its
// axis is already 45° up-right, so the mass slides along its length and
// crosses 0% of its width — strictly axial, no exception needed.
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../tokens.dart';
import 'glyph_canvas.dart';

class PencilGlyph extends IconGlyph {
  const PencilGlyph(super.size, {super.key});

  @override
  TreatmentPainter painterFor(BuildContext context) {
    final (mass, ink) = glyphPlates(
      context,
      lightMass: IconMassPalette.iconMassNeutral,
      darkMass: DarkPalette.iconMassNeutralDark,
    );

    // Local frame: the pencil's own 45° axis. Axis unit a = (cos −45°,
    // sin −45°); perpendicular p = (0.707, 0.707). Eraser end S, tip base
    // T0 (13.4u along), point P (5.66u further): 19.1u total, so the 1.92u
    // offset slides the mass ~10% along its length.
    final aX = math.cos(-math.pi / 4);
    final aY = math.sin(-math.pi / 4);
    const pX = 0.70710678, pY = 0.70710678;
    const sX = 4.6, sY = 19.4;
    const shaft = 13.4, tip = 5.66, halfWidth = 1.7;

    Offset along(double x, double y, double d) =>
        Offset(x + aX * d, y + aY * d);

    final t0 = along(sX, sY, shaft);
    final tipPoint = along(sX, sY, shaft + tip);
    final sPlus = Offset(sX + pX * halfWidth, sY + pY * halfWidth);
    final sMinus = Offset(sX - pX * halfWidth, sY - pY * halfWidth);
    final t0Plus = Offset(t0.dx + pX * halfWidth, t0.dy + pY * halfWidth);
    final t0Minus = Offset(t0.dx - pX * halfWidth, t0.dy - pY * halfWidth);
    final ferrule = along(sX, sY, 2.2);
    final ferrulePlus = Offset(
      ferrule.dx + pX * halfWidth,
      ferrule.dy + pY * halfWidth,
    );
    final ferruleMinus = Offset(
      ferrule.dx - pX * halfWidth,
      ferrule.dy - pY * halfWidth,
    );

    final shaftPath = Path()
      ..moveTo(sPlus.dx, sPlus.dy)
      ..lineTo(t0Plus.dx, t0Plus.dy)
      ..lineTo(t0Minus.dx, t0Minus.dy)
      ..lineTo(sMinus.dx, sMinus.dy)
      ..close();

    return TreatmentPainter(
      scale: size / 24,
      massColor: mass,
      lineColor: ink,
      massPaths: [shaftPath],
      linePaths: [
        Path()..addPath(shaftPath, Offset.zero),
        Path()
          ..moveTo(t0Plus.dx, t0Plus.dy)
          ..lineTo(tipPoint.dx, tipPoint.dy)
          ..lineTo(t0Minus.dx, t0Minus.dy),
        Path()
          ..moveTo(ferrulePlus.dx, ferrulePlus.dy)
          ..lineTo(ferruleMinus.dx, ferruleMinus.dy),
      ],
    );
  }
}

// `Quedármelo` — the box, first of the destination trio
// (DESIGN.md {components.destination-flow}). Caja C, recalibrated for 64px:
// the mass moved from the lid band to the body so the row's raw ink
// guard-rail holds. Geometry from the measured mockups; mass at L* 76
// displaced by the one global vector, line un-offset above it.
import 'package:flutter/material.dart';

import '../tokens.dart';
import 'glyph_canvas.dart';

class BoxGlyph extends IconGlyph {
  const BoxGlyph(super.size, {super.key});

  @override
  TreatmentPainter painterFor(BuildContext context) {
    final (mass, ink) = glyphPlates(
      context,
      lightMass: IconMassPalette.destKeep,
      darkMass: DarkPalette.destKeepDark,
    );

    final body = RRect.fromRectAndRadius(
      const Rect.fromLTWH(6.9, 11.0, 10.2, 7.85),
      const Radius.circular(1),
    );
    final lid = RRect.fromRectAndRadius(
      const Rect.fromLTWH(4.8, 7.2, 14.4, 3.8),
      const Radius.circular(1),
    );

    return TreatmentPainter(
      scale: size / 24,
      massColor: mass,
      lineColor: ink,
      massPaths: [Path()..addRRect(body)],
      linePaths: [
        Path()
          ..moveTo(6.9, 11.0)
          ..lineTo(6.9, 18.85)
          ..lineTo(17.1, 18.85)
          ..lineTo(17.1, 11.0),
        Path()..addRRect(lid),
      ],
    );
  }
}

// `Donar o vender` — the bag, second of the destination trio
// (DESIGN.md {components.destination-flow}). Geometry from the measured
// mockups: trapezoid mass under the line body and its arc handle.
import 'package:flutter/material.dart';

import '../tokens.dart';
import 'glyph_canvas.dart';

class BagGlyph extends IconGlyph {
  const BagGlyph(super.size, {super.key});

  @override
  TreatmentPainter painterFor(BuildContext context) {
    final (mass, ink) = glyphPlates(
      context,
      lightMass: IconMassPalette.destDonate,
      darkMass: DarkPalette.destDonateDark,
    );

    return TreatmentPainter(
      scale: size / 24,
      massColor: mass,
      lineColor: ink,
      massPaths: [
        Path()
          ..moveTo(5.15, 14.1)
          ..lineTo(18.85, 14.1)
          ..lineTo(19.3, 20)
          ..lineTo(4.7, 20)
          ..close(),
      ],
      linePaths: [
        Path()
          ..moveTo(5.6, 9.4)
          ..lineTo(4.7, 20)
          ..lineTo(19.3, 20)
          ..lineTo(18.4, 9.4),
        Path()
          ..moveTo(9.2, 9.4)
          ..lineTo(9.2, 7.8)
          ..arcToPoint(
            const Offset(14.8, 7.8),
            radius: const Radius.circular(2.8),
            clockwise: true,
          )
          ..lineTo(14.8, 9.4),
      ],
    );
  }
}

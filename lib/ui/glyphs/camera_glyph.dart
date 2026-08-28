// Cámara — the Scan entry on the Dispenser (utility glyph, neutral mass
// under the ordinary treatment). Absent, never greyed, when the camera is
// disabled or its permission refused — that is the surface's decision, not
// this glyph's.
import 'package:flutter/material.dart';

import '../tokens.dart';
import 'glyph_canvas.dart';

class CameraGlyph extends IconGlyph {
  const CameraGlyph(super.size, {super.key});

  @override
  TreatmentPainter painterFor(BuildContext context) {
    final (mass, ink) = glyphPlates(
      context,
      lightMass: IconMassPalette.iconMassNeutral,
      darkMass: DarkPalette.iconMassNeutralDark,
    );

    final body = RRect.fromRectAndRadius(
      const Rect.fromLTWH(4, 8.2, 16, 11),
      const Radius.circular(2),
    );

    return TreatmentPainter(
      scale: size / 24,
      massColor: mass,
      lineColor: ink,
      massPaths: [Path()..addRRect(body)],
      linePaths: [
        Path()..addRRect(body),
        Path()
          ..moveTo(9.2, 8.2)
          ..lineTo(10.2, 5.8)
          ..lineTo(13.8, 5.8)
          ..lineTo(14.8, 8.2),
        Path()..addOval(
          Rect.fromCircle(center: const Offset(12, 13.7), radius: 3.6),
        ),
      ],
    );
  }
}

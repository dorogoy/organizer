// Álbum — the Transformation Album's mark (utility glyph, neutral mass).
// A photograph: one plate, a sun and a horizon drawn on the line layer.
import 'package:flutter/material.dart';

import '../tokens.dart';
import 'glyph_canvas.dart';

class AlbumGlyph extends IconGlyph {
  const AlbumGlyph(super.size, {super.key});

  @override
  TreatmentPainter painterFor(BuildContext context) {
    final (mass, ink) = glyphPlates(
      context,
      lightMass: IconMassPalette.iconMassNeutral,
      darkMass: DarkPalette.iconMassNeutralDark,
    );

    final plate = RRect.fromRectAndRadius(
      const Rect.fromLTWH(5.4, 6.8, 13.2, 12.4),
      const Radius.circular(1.6),
    );

    return TreatmentPainter(
      scale: size / 24,
      massColor: mass,
      lineColor: ink,
      massPaths: [Path()..addRRect(plate)],
      linePaths: [
        Path()..addRRect(plate),
        Path()..addOval(
          Rect.fromCircle(center: const Offset(9.2, 10.4), radius: 1.3),
        ),
        Path()
          ..moveTo(6.4, 17.2)
          ..lineTo(10.6, 12.6)
          ..lineTo(13.2, 15.0)
          ..lineTo(15.2, 13.0)
          ..lineTo(17.6, 15.2),
      ],
    );
  }
}

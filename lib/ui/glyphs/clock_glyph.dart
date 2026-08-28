// Reloj — the time mark (utility glyph, neutral mass). The heaviest mass in
// the utility set (211.2u², a filled face) — that breaks no rule: only the
// destination trio must weigh the same.
import 'package:flutter/material.dart';

import '../tokens.dart';
import 'glyph_canvas.dart';

class ClockGlyph extends IconGlyph {
  const ClockGlyph(super.size, {super.key});

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
      massPaths: [
        Path()..addOval(
          Rect.fromCircle(center: const Offset(12, 12.2), radius: 8.2),
        ),
      ],
      linePaths: [
        Path()..addOval(
          Rect.fromCircle(center: const Offset(12, 12.2), radius: 8.2),
        ),
        Path()
          ..moveTo(12, 12.2)
          ..lineTo(12, 7.4),
        Path()
          ..moveTo(12, 12.2)
          ..lineTo(15.4, 14.0),
      ],
    );
  }
}

// Hoja — the FlyLady zone marker (DESIGN.md {components.zone-marker}),
// rendered quiet at {spacing.glyph-zone-marker} beside a word. Its mass is
// the ochre — computed, neither the neutral utility mass nor any
// destination hue, so the marker reads as neither a destination nor a
// utility control. The leaf's own axis is 45° up-right, so the global
// offset runs along it (axial, never transverse).
import 'package:flutter/material.dart';

import '../tokens.dart';
import 'glyph_canvas.dart';

class LeafGlyph extends IconGlyph {
  const LeafGlyph(super.size, {super.key});

  @override
  TreatmentPainter painterFor(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final mass = dark
        ? DarkPalette.iconMassOchreDark
        : IconMassPalette.iconMassOchre;
    final ink = dark ? DarkPalette.inkSecondaryDark : FieldPalette.inkSecondary;

    final blade = Path()
      ..moveTo(7.2, 16.8)
      ..quadraticBezierTo(7.2, 7.2, 16.8, 7.2)
      ..quadraticBezierTo(16.8, 16.8, 7.2, 16.8)
      ..close();

    return TreatmentPainter(
      scale: size / 24,
      massColor: mass,
      lineColor: ink,
      massPaths: [Path()..addPath(blade, Offset.zero)],
      linePaths: [
        Path()..addPath(blade, Offset.zero),
        Path()
          ..moveTo(7.2, 16.8)
          ..lineTo(16.8, 7.2),
        Path()
          ..moveTo(7.2, 16.8)
          ..lineTo(6, 18),
      ],
    );
  }
}

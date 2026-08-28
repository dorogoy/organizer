// The dandelion seed — the third destination, `Tirar o soltar`
// (DESIGN.md {components.seed-glyph}). Eight filaments at every size, a
// filled achene, the pompom-hub colour mass under the line layer, the whole
// drawing rotated +8° so its axis is 45.0° and the global offset's
// transverse component is exactly 0.
import 'package:flutter/material.dart';

import '../tokens.dart';
import 'glyph_canvas.dart';
import 'seed_geometry.dart';

/// The seed at any drawn size. One drawing, scaled — no fidelity ladder —
/// and always at rest: the filaments and the stem are the whole line layer.
class SeedGlyph extends IconGlyph {
  const SeedGlyph(super.size, {super.key});

  @override
  TreatmentPainter painterFor(BuildContext context) {
    final (mass, ink) = glyphPlates(
      context,
      lightMass: IconMassPalette.destTrash,
      darkMass: DarkPalette.destTrashDark,
    );

    Path filamentPath() {
      final path = Path();
      for (final f in filaments) {
        path.moveTo(f.p0.x, f.p0.y);
        path.cubicTo(f.c1.x, f.c1.y, f.c2.x, f.c2.y, f.p3.x, f.p3.y);
      }
      return path;
    }

    Path stemPath() {
      return Path()
        ..moveTo(stemStart.x, stemStart.y)
        ..quadraticBezierTo(stemControl.x, stemControl.y, hub.x, hub.y);
    }

    Path achenePath() {
      return Path()
        ..moveTo(acheneStart.x, acheneStart.y)
        ..cubicTo(
          acheneC1a.x,
          acheneC1a.y,
          acheneC2a.x,
          acheneC2a.y,
          achenePoint.x,
          achenePoint.y,
        )
        ..cubicTo(
          acheneC1b.x,
          acheneC1b.y,
          acheneC2b.x,
          acheneC2b.y,
          acheneStart.x,
          acheneStart.y,
        )
        ..close();
    }

    return TreatmentPainter(
      scale: size / 24,
      massColor: mass,
      lineColor: ink,
      rotationDegrees: seedAxisCorrectionDegrees,
      massPaths: [
        Path()..addOval(
          Rect.fromCircle(
            // The base placement, pre-offset — the shared painter applies
            // the global 45° vector on top (screen space, once).
            center: pompomBaseLocal.offset,
            radius: pompomRadiusU,
          ),
        ),
      ],
      linePaths: [filamentPath(), stemPath()],
      inkFillPaths: [achenePath()],
    );
  }
}

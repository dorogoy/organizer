// The dandelion seed — the third destination, `Tirar o soltar`
// (DESIGN.md {components.seed-glyph}). Eight filaments at every size, a
// filled achene, the pompom-hub colour mass under the line layer, the whole
// drawing rotated +8° so its axis is 45.0° and the global offset's
// transverse component is exactly 0.
import 'package:flutter/material.dart';

import '../tokens.dart';
import 'glyph_canvas.dart';
import 'seed_geometry.dart';

/// The seed at any drawn size. One drawing, scaled — no fidelity ladder.
///
/// Motion dashes render only at [motionDashThresholdPx] and above, and are
/// never drawn in the 3-Destination Flow regardless of its 64px — the trio
/// seed is at rest by decision, so its surface passes `motionDashes: false`
/// explicitly.
class SeedGlyph extends IconGlyph {
  const SeedGlyph(super.size, {super.key, this.motionDashes});

  /// Overrides the size threshold. Null = follow the threshold.
  final bool? motionDashes;

  /// The threshold rule, exposed for tests and surfaces.
  static bool dashesForSize(double size) => size >= motionDashThresholdPx;

  /// Dashes need the threshold met AND no explicit opt-out — an explicit
  /// `true` never overrides the 56px floor (UX-DR45's sibling guarantee:
  /// below the threshold they are 4px specks that read as dirt).
  bool get _dashes => motionDashes != false && dashesForSize(size);

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

    Path dashesPath() {
      final path = Path();
      for (final (p0, p1, p2) in motionDashArcs) {
        path.moveTo(p0.x, p0.y);
        path.quadraticBezierTo(p1.x, p1.y, p2.x, p2.y);
      }
      return path;
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
      linePaths: [filamentPath(), stemPath(), if (_dashes) dashesPath()],
      inkFillPaths: [achenePath()],
    );
  }
}

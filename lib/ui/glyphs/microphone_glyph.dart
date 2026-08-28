// The Micrófono capsule — Manual Capture's dictation affordance
// (DESIGN.md {components.microphone-glyph}), and nowhere else. The capsule
// is a REGISTERED mass — its vertical axis contradicts the global 45°
// vector, and a capsule is itself the container — so no offset applies.
// At rest the mass is neutral; while dictating it is blue, declared also by
// the caption `Escuchando…` — ink and prose, never motion. Where on-device
// recognition is unavailable the glyph is simply absent.
import 'package:flutter/material.dart';

import '../tokens.dart';
import 'glyph_canvas.dart';

class MicrophoneGlyph extends IconGlyph {
  const MicrophoneGlyph(super.size, {super.key, this.dictating = false});

  final bool dictating;

  @override
  TreatmentPainter painterFor(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final mass = dictating
        ? (dark ? DarkPalette.iconMassBlueDark : IconMassPalette.iconMassBlue)
        : (dark
              ? DarkPalette.iconMassNeutralDark
              : IconMassPalette.iconMassNeutral);
    final ink = dark ? DarkPalette.inkPrimaryDark : FieldPalette.inkPrimary;

    final capsule = RRect.fromRectAndRadius(
      const Rect.fromLTWH(8.6, 3.6, 6.8, 10.4),
      const Radius.circular(3.4),
    );

    return TreatmentPainter(
      scale: size / 24,
      massColor: mass,
      lineColor: ink,
      registeredMass: true,
      massPaths: [Path()..addRRect(capsule)],
      linePaths: [
        Path()..addRRect(capsule),
        Path()
          ..moveTo(6.2, 10.6)
          ..lineTo(6.2, 11.4)
          ..arcToPoint(
            const Offset(17.8, 11.4),
            radius: const Radius.circular(5.8),
            clockwise: false,
          )
          ..lineTo(17.8, 10.6),
        Path()
          ..moveTo(12, 17.2)
          ..lineTo(12, 20.4),
      ],
    );
  }
}

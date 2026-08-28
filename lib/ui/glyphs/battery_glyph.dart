// The batería — the energy check-in's mark (DESIGN.md {components.energy-checkin}).
// Casing and nub line-only; the charge is a REGISTERED mass filling from the
// left — a horizontal casing against the 45° vector, and a fill inside a
// closed container where misregistration would read as a leak — so the
// global offset does not apply. Selected: charge blue + casing ink-primary.
// Unselected: charge neutral + casing ink-secondary. The charge is the
// state, the fill level the meaning; never a traffic light.
import 'package:flutter/material.dart';

import '../tokens.dart';
import 'glyph_canvas.dart';

/// The three charge widths, in 24-viewBox units (llena / media / baja).
enum BatteryLevel { full, medium, low }

class BatteryGlyph extends IconGlyph {
  const BatteryGlyph(
    super.size, {
    super.key,
    required this.level,
    this.selected = false,
  });

  final BatteryLevel level;

  /// Selected takes the blue charge and the ink-primary casing; unselected
  /// the neutral charge and the ink-secondary casing.
  final bool selected;

  double get _chargeWidthU => switch (level) {
    BatteryLevel.full => 12.8,
    BatteryLevel.medium => 6.4,
    BatteryLevel.low => 3.2,
  };

  @override
  TreatmentPainter painterFor(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final charge = selected
        ? (dark ? DarkPalette.iconMassBlueDark : IconMassPalette.iconMassBlue)
        : (dark
              ? DarkPalette.iconMassNeutralDark
              : IconMassPalette.iconMassNeutral);
    final ink = selected
        ? (dark ? DarkPalette.inkPrimaryDark : FieldPalette.inkPrimary)
        : (dark ? DarkPalette.inkSecondaryDark : FieldPalette.inkSecondary);

    final casing = RRect.fromRectAndRadius(
      const Rect.fromLTWH(4.5, 8.0, 15.0, 8.5),
      const Radius.circular(1.6),
    );

    return TreatmentPainter(
      scale: size / 24,
      massColor: charge,
      lineColor: ink,
      registeredMass: true,
      massPaths: [
        Path()..addRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(6.1, 9.6, _chargeWidthU, 5.3),
            const Radius.circular(0.7),
          ),
        ),
      ],
      linePaths: [
        Path()..addRRect(casing),
        Path()
          ..moveTo(20.9, 10.6)
          ..lineTo(20.9, 13.9),
      ],
    );
  }
}

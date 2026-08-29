// The zone-marker footer (DESIGN.md {components.zone-marker}): the Hoja
// at 24px beside its word, sitting at the foot of the dispenser card — a
// place-marker, not a control: it is not a filter and it opens nothing
// (UX-DR28). The label is the canonical A12.4 cluster name from the ARB;
// `Card.zone` is an enum and never carries strings (AD-15).
import 'package:core/catalogue/catalogue.dart';
import 'package:flutter/material.dart';

import '../../strings/app_strings.dart';
import '../glyphs/leaf_glyph.dart';
import '../tokens.dart';

/// The zone's canonical name (A12.4), resolved from the string table —
/// the only place zone vocabulary may enter a surface.
String zoneLabel(Zone zone, AppStrings strings) => switch (zone) {
  Zone.z1 => strings.zoneZ1,
  Zone.z2 => strings.zoneZ2,
  Zone.z3 => strings.zoneZ3,
  Zone.z4 => strings.zoneZ4,
  Zone.z5 => strings.zoneZ5,
};

/// The quiet footer: 24px Hoja + label in the support role, both
/// ink-secondary, the glyph's mass in the ochre. Rendered only when the
/// dealt card carries a zone — daily and `fondo` deals end after the
/// secondary action, and no zone word is ever invented for them.
class ZoneMarker extends StatelessWidget {
  const ZoneMarker({super.key, required this.zone});

  final Zone zone;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        LeafGlyph(Spacing.glyphZoneMarker),
        // The marker sits beside its word at the same proximity the chip
        // holds to its task — the ladder's 8, proximity being the
        // mechanism for a paired mark and its label.
        const SizedBox(width: Spacing.chipToTask),
        // Flexible so the word wraps at 200% instead of overflowing its
        // row — growing, never truncating (UX-DR45).
        Flexible(
          // bodySmall is the wired support role (theme.dart).
          child: Text(
            zoneLabel(zone, AppStrings.of(context)),
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
      ],
    );
  }
}

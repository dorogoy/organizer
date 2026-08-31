// The ambient strip (Story 2.5, UX-DR20/22, FR-4): the surface every
// future ambient ask lives in, sitting below the dispenser-card inside
// the scroll region. A sentence in the support role and ink-secondary,
// tappable where an accept action exists and never a primary action,
// ✕ dismissal at 48dp, at most one resident visible — the check-in is
// this build's only resident, and it is bare: ephemeral residents sit
// on the ground with no hairline (persistent ones — 2.6's self-report —
// carry a 1px edge).
//
// The check-in resident is the question verbatim plus three battery
// marks as direct tap targets and nothing else: llena pre-marked as
// the standing default (the surface's own state, never a written row),
// selected reading `icon-mass-blue` charge with an `ink-primary`
// casing, unselected neutral/secondary — `BatteryGlyph`'s own grammar,
// complete and tested. One tap answers the day through the
// controller's single sanctioned minter; the ✕ writes nothing at all.
// At 200% the strip grows inside the scroll region with every target
// at or above 48dp — nothing truncates.
import 'package:core/energy/energy.dart';
import 'package:flutter/material.dart';

import '../../strings/app_strings.dart';
import '../glyphs/battery_glyph.dart';
import '../tokens.dart';

/// The strip's dismissal mark, drawn line-only: ✕ is not a glyph-set
/// member (no mass plate — it is chrome, not iconography), so an inline
/// painter in the support ink draws it inside a 48dp opaque target.
class _DismissPainter extends CustomPainter {
  const _DismissPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    // A zero-width layout (an unmounted or stripped box) has nothing
    // to draw, and the viewBox math below would divide by zero.
    if (size.width <= 0) {
      return;
    }
    // A 24-unit viewBox scaled to the render side, matching the glyph
    // set's stroke discipline: round caps, 1.5 px at a 24 px box —
    // the width is in viewBox units and the canvas scale renders it,
    // so a smaller box draws a proportionally lighter mark, never a
    // constant-px stroke.
    final scale = size.width / 24;
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round
      ..isAntiAlias = true;
    final path = Path()
      ..moveTo(8.4, 8.4)
      ..lineTo(15.6, 15.6)
      ..moveTo(15.6, 8.4)
      ..lineTo(8.4, 15.6);
    canvas.save();
    canvas.scale(scale, scale);
    canvas.drawPath(path, paint);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _DismissPainter oldDelegate) =>
      oldDelegate.color != color;
}

/// The ✕ dismissal (UX-DR22): one tap, skip-for-today, no write — the
/// quietest control the surface owns, in the unsplit secondary grammar:
/// no fill, no ripple, nothing animated.
class _DismissMark extends StatelessWidget {
  const _DismissMark({this.onTap});

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final ink = dark ? DarkPalette.inkSecondaryDark : FieldPalette.inkSecondary;
    return Semantics(
      button: true,
      label: AppStrings.of(context).ambientStripDismiss,
      child: GestureDetector(
        // Absent, the tap stays an accepted no-op — a null onTap would
        // render a disabled control instead.
        onTap: onTap ?? () {},
        behavior: HitTestBehavior.opaque,
        child: SizedBox(
          width: Spacing.touchTargetMin,
          height: Spacing.touchTargetMin,
          child: Center(
            child: CustomPaint(
              size: const Size.square(18),
              painter: _DismissPainter(ink),
            ),
          ),
        ),
      ),
    );
  }
}

/// One battery mark as a direct tap target (UX-DR20): the glyph inside
/// a 48dp opaque target, declared to readers as a button carrying
/// selection state and the level's own label — the ladder-pill
/// precedent. Selected is the glyph's own grammar (blue charge,
/// ink-primary casing); the surface hands it the standing default.
class _BatteryMark extends StatelessWidget {
  const _BatteryMark({
    required this.level,
    required this.selected,
    required this.label,
    this.onTap,
  });

  final EnergyLevel level;

  final bool selected;

  final String label;

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: GestureDetector(
        // Absent, the tap stays an accepted no-op (the anatomy
        // harness precedent).
        onTap: onTap ?? () {},
        behavior: HitTestBehavior.opaque,
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            minWidth: Spacing.touchTargetMin,
            minHeight: Spacing.touchTargetMin,
          ),
          child: Center(
            child: BatteryGlyph(
              Spacing.glyphZoneMarker,
              level: switch (level) {
                EnergyLevel.full => BatteryLevel.full,
                EnergyLevel.medium => BatteryLevel.medium,
                EnergyLevel.low => BatteryLevel.low,
              },
              selected: selected,
            ),
          ),
        ),
      ),
    );
  }
}

/// The ambient strip holding the daily energy check-in (Story 2.5,
/// FR-4, UX-DR22): `energyCheckInQuestion` verbatim with three battery
/// marks — llena pre-marked as the standing default — and the ✕
/// dismissal, bare chrome on the ground. One tap on any mark answers
/// the day through [onEnergy] (the controller's single write path);
/// the ✕ dismisses through [onDismiss] (no write at all). The strip
/// renders, it never sets the level itself — after it leaves, nothing
/// displays the level anywhere (AD-4).
class AmbientStrip extends StatelessWidget {
  const AmbientStrip({super.key, required this.onEnergy, this.onDismiss});

  /// The answer path: one `energy_set` row per tap, the strip gone for
  /// the day once the write lands.
  final void Function(EnergyLevel level) onEnergy;

  /// The dismissal path: shell state only, never a write.
  final VoidCallback? onDismiss;

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    final theme = Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Text(
                strings.energyCheckInQuestion,
                // bodySmall is the wired support role (theme.dart) —
                // the strip's sentence register, ink-secondary.
                style: theme.textTheme.bodySmall,
                textAlign: TextAlign.center,
              ),
            ),
            _DismissMark(onTap: onDismiss),
          ],
        ),
        const SizedBox(height: Spacing.chipToTask),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _BatteryMark(
              level: EnergyLevel.full,
              // The standing default, pre-marked (UX-DR4): the day
              // already reads llena until a tap says otherwise.
              selected: true,
              label: strings.energyLevelFull,
              onTap: () => onEnergy(EnergyLevel.full),
            ),
            const SizedBox(width: Spacing.actionGap),
            _BatteryMark(
              level: EnergyLevel.medium,
              selected: false,
              label: strings.energyLevelMedium,
              onTap: () => onEnergy(EnergyLevel.medium),
            ),
            const SizedBox(width: Spacing.actionGap),
            _BatteryMark(
              level: EnergyLevel.low,
              selected: false,
              label: strings.energyLevelLow,
              onTap: () => onEnergy(EnergyLevel.low),
            ),
          ],
        ),
      ],
    );
  }
}

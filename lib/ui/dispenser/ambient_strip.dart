// The ambient strip (Stories 2.5–2.6, UX-DR20/22, FR-4): the surface
// every future ambient ask lives in, sitting below the dispenser-card
// inside the scroll region. A sentence in the support role and
// ink-secondary, tappable where an accept action exists and never a
// primary action, ✕ dismissal at 48dp, at most one resident visible.
//
// This build holds two residents, one per chrome side of the strip's
// rule — ephemeral = bare, persistent = hairline. The check-in is
// bare: the question verbatim plus three battery marks as direct tap
// targets, llena pre-marked as the standing default (the surface's own
// state, never a written row), selected reading `icon-mass-blue` charge
// with an `ink-primary` casing, unselected neutral/secondary —
// `BatteryGlyph`'s own grammar, complete and tested. One tap answers
// the day through the controller's single sanctioned minter; the ✕
// writes nothing at all.
//
// The weekly self-report is hairlined, because it persists until
// answered (SM-2): the question verbatim, the 1–5 numerals as direct
// 48dp tap targets in the figure role, visible end labels fixing the
// scale's direction, the same ✕ — one tap answers the asked week
// through the report's own single sanctioned minter, and the ✕ hides
// it for this opening only, never for the week. At 200% both residents
// grow inside the scroll region with every target at or above 48dp —
// nothing truncates.
import 'package:core/energy/energy.dart';
import 'package:core/log/log_entry.dart';
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

/// The ✕ dismissal (UX-DR22): one tap, no write, with the resident owning
/// its scope — today for the check-in, this opening for the report. The
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

/// One scale numeral as a direct tap target (Story 2.6, the
/// `_BatteryMark` grammar): the digit through the one ARB placeholder
/// inside an opaque 48dp-minimum target, declared to readers as a
/// button whose spoken label is the numeral the mark's own text
/// already carries — the ladder-pill precedent. No selection state
/// exists — the report has no default the way the check-in's llena
/// does; nothing is pre-marked, and the visible end labels, not the
/// marks, fix the scale's direction.
class _ScaleDigitMark extends StatelessWidget {
  const _ScaleDigitMark({required this.value, this.onTap});

  final int value;

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
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
            // titleMedium is the wired metricNumeral figure role
            // (theme.dart) — the digits are figures, the mockup's raw
            // 15px bettered on the token it already had.
            child: Text(
              AppStrings.of(context).selfReportScaleValue(value),
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
        ),
      ),
    );
  }
}

/// The ambient strip holding the weekly self-report (Story 2.6, SM-2,
/// FR-4, UX-DR22): `weeklySelfReportQuestion` verbatim with the 1–5
/// numerals as direct tap targets, visible end labels and the ✕
/// dismissal — hairlined chrome, because it persists (the strip's
/// rule: 1px `colorScheme.outline` edge with `radiusDefault` on the
/// resident's own wrapper, never the container). One tap on any
/// numeral answers the asked week through [onAnswer] (the report's
/// single write path); the ✕ dismisses through [onDismiss] (no write
/// at all — hidden for this opening, offered again at the next one,
/// never dismissed for the week). `Nada` sits under the 1 and
/// `Muchísimo` under the 5, so the scale's direction reads without a
/// word of explanation; at 200% the digits row reflows inside the
/// scroll and every target holds 48dp.
class SelfReportStrip extends StatelessWidget {
  const SelfReportStrip({super.key, required this.onAnswer, this.onDismiss});

  /// The answer path: one `report_answered` row per tap, carrying the
  /// asked week — the report gone for the week once the write lands.
  final void Function(int value) onAnswer;

  /// The dismissal path: shell state only, never a write.
  final VoidCallback? onDismiss;

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        // surfaceContainerHighest is the wired raised tone; outline is
        // the wired hairline (theme.dart) — the persistent resident's
        // own 1px edge, the task card's exact precedent.
        color: theme.colorScheme.surfaceContainerHighest,
        border: Border.all(color: theme.colorScheme.outline, width: 1),
        borderRadius: BorderRadius.circular(Radii.radiusDefault),
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: Spacing.chipPaddingHorizontal,
        vertical: Spacing.chipToTask,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Text(
                  strings.weeklySelfReportQuestion,
                  // bodySmall is the wired support role (theme.dart) —
                  // the strip's sentence register, ink-secondary.
                  style: theme.textTheme.bodySmall,
                ),
              ),
              _DismissMark(onTap: onDismiss),
            ],
          ),
          const SizedBox(height: Spacing.chipToTask),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: Spacing.chipToTask,
            runSpacing: Spacing.chipToTask,
            children: [
              for (
                var value = reportScaleLeast;
                value <= reportScaleMost;
                value++
              )
                _ScaleDigitMark(value: value, onTap: () => onAnswer(value)),
            ],
          ),
          const SizedBox(height: Spacing.spacingBase),
          Row(
            children: [
              Expanded(
                child: Text(
                  strings.selfReportScaleLow,
                  style: theme.textTheme.bodySmall,
                ),
              ),
              Expanded(
                child: Text(
                  strings.selfReportScaleHigh,
                  // bodySmall is the wired support role (theme.dart).
                  style: theme.textTheme.bodySmall,
                  textAlign: TextAlign.right,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

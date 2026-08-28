// The seed glyph's closing gate (DESIGN.md Implementation Checks): the
// drawn pompom radius is recorded, asserted, and pinned by golden image.
// The radius was drawn and measured at implementation time — larger than
// the 1.70u anchor, displaced off hub-centre toward the leeward (dense)
// side, its entire free edge under filaments — and these tests are what
// close that decision, not a human check-in.
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:organizer/ui/glyphs/glyph_canvas.dart';
import 'package:organizer/ui/glyphs/seed_geometry.dart';
import 'package:organizer/ui/glyphs/seed_glyph.dart';
import 'package:organizer/ui/tokens.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('seed-glyph pompom radius (DESIGN.md Implementation Checks)', () {
    test('the drawn radius exceeds the 1.70u anchor', () {
      expect(
        pompomRadiusU,
        greaterThan(1.70),
        reason:
            'r = $pompomRadiusU u: the 1.70u anchor was the last size '
            'the eye files as colour when centred; the drawn radius must '
            'clear it',
      );
    });

    test('the circle sits off-centre, toward the leeward (dense) side', () {
      // pompomCentreLocal = base placement + the global offset expressed in
      // the drawing's local frame (screen 45°, so 53° locally — along the
      // seed's own axis); the dense component must exist and point along
      // the leeward bisector — sotavento, where the angular spacing closes.
      final dense = SeedPoint(
        pompomCentreLocal.x - hub.x - globalOffsetLocal.x,
        pompomCentreLocal.y - hub.y - globalOffsetLocal.y,
      );
      final magnitude = math.sqrt(dense.x * dense.x + dense.y * dense.y);
      expect(magnitude, greaterThan(0.0), reason: 'strictly off-centre');
      final cosToDense =
          (dense.x * denseDirection.x + dense.y * denseDirection.y) / magnitude;
      expect(
        cosToDense,
        closeTo(1.0, 1e-6),
        reason: 'along the dense bisector (filaments 6–7, the tightest pair)',
      );
    });

    test(
      'the global offset maps to the drawing local frame along the axis',
      () {
        final magnitude = math.sqrt(
          globalOffsetLocal.x * globalOffsetLocal.x +
              globalOffsetLocal.y * globalOffsetLocal.y,
        );
        // 1.358·√2 — magnitude preserved by the frame rotation (the
        // decomposition itself is rounded from 1.92u in glyph_canvas).
        expect(magnitude, closeTo(glyphOffsetU * math.sqrt2, 1e-9));
        // In local coords the offset runs at 53° — the constructed axis —
        // so after the +8° whole-drawing rotation it lands on the screen
        // 45° vector with zero transverse component (the axial rule).
        final localDegrees =
            -math.atan2(globalOffsetLocal.y, globalOffsetLocal.x) *
            180 /
            math.pi;
        expect(localDegrees, closeTo(53.0, 1e-6));
      },
    );

    test('the free edge is wholly covered by filaments', () {
      final coverage = measurePompomCoverage();
      expect(
        coverage.sectorViolations,
        0,
        reason:
            "no edge point may leave the fan's swept sector: the "
            'centred r = 2.30u candidate failed exactly there — a bare arc '
            'where only the stem passes',
      );
      expect(
        coverage.worstEdgeDistanceU,
        lessThanOrEqualTo(maxPermittedEdgeDistanceU),
        reason:
            'worst edge-to-filament distance '
            '${coverage.worstEdgeDistanceU}u exceeds the permitted '
            '$maxPermittedEdgeDistanceU u (the design\'s accepted centred '
            '1.70u candidate measures 0.83u) — "as large as coverage '
            'permits"',
      );
      expect(coverage.isWhollyCovered, isTrue);
    });

    test('motion dashes follow the 56px threshold', () {
      expect(
        SeedGlyph.dashesForSize(Spacing.glyphMin),
        isFalse,
        reason: '48px interface minimum: at rest',
      );
      expect(SeedGlyph.dashesForSize(55.9), isFalse);
      expect(SeedGlyph.dashesForSize(motionDashThresholdPx), isTrue);
      expect(
        SeedGlyph.dashesForSize(Spacing.glyphDestination),
        isTrue,
        reason:
            '64px clears the threshold in the illustration register; '
            'the destination trio still passes motionDashes: false '
            'explicitly',
      );
    });

    testWidgets(
      'an explicit motionDashes: true never bypasses the 56px floor',
      (tester) async {
        TreatmentPainter painterOf() {
          final found = find.byWidgetPredicate(
            (widget) =>
                widget is CustomPaint && widget.painter is TreatmentPainter,
          );
          return (tester.widget(found) as CustomPaint).painter!
              as TreatmentPainter;
        }

        await tester.pumpWidget(
          MaterialApp(
            home: Center(
              child: SeedGlyph(Spacing.glyphMin, motionDashes: true),
            ),
          ),
        );
        // Filaments + stem; the dashes path stays off below 56px.
        expect(painterOf().linePaths, hasLength(2));
      },
    );

    test('the drawn radius lands as measured', () {
      expect(pompomRadiusU, 1.80);
      expect(pompomDenseDisplacementU, 0.30);
    });
  });

  group('golden images', () {
    Future<void> pumpSeed(WidgetTester tester, double size) async {
      await tester.binding.setSurfaceSize(Size.square(size + 16));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        MaterialApp(home: Center(child: SeedGlyph(size))),
      );
      await tester.pump();
    }

    testWidgets('48px — the interface minimum, dashes off', (tester) async {
      await pumpSeed(tester, Spacing.glyphMin);
      await expectLater(
        find.byType(SeedGlyph),
        matchesGoldenFile('goldens/seed_glyph_48px.png'),
      );
    });

    testWidgets('64px — above the threshold, dashes on', (tester) async {
      await pumpSeed(tester, Spacing.glyphDestination);
      await expectLater(
        find.byType(SeedGlyph),
        matchesGoldenFile('goldens/seed_glyph_64px.png'),
      );
    });
  });
}

// The seed glyph's closing gate (DESIGN.md Implementation Checks): the
// drawn pompom radius is recorded, asserted, and pinned by golden image.
// The radius was drawn and measured at implementation time — larger than
// the 1.70u anchor, displaced off hub-centre toward the leeward (dense)
// side, its entire free edge under filaments — and these tests are what
// close that decision, not a human check-in.
//
// The file's second half is the structure sweep: one drawing, scaled —
// its parts (filaments + stem, the achene, the pompom circle) pinned by
// count and by geometry across 24–168px, in both palettes.
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:organizer/ui/glyphs/glyph_canvas.dart';
import 'package:organizer/ui/glyphs/seed_geometry.dart';
import 'package:organizer/ui/glyphs/seed_glyph.dart';
import 'package:organizer/ui/theme.dart';
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

    testWidgets('48px — the interface minimum, at rest', (tester) async {
      await pumpSeed(tester, Spacing.glyphMin);
      await expectLater(
        find.byType(SeedGlyph),
        matchesGoldenFile('goldens/seed_glyph_48px.png'),
      );
    });

    testWidgets('64px — the destination size, at rest', (tester) async {
      await pumpSeed(tester, Spacing.glyphDestination);
      await expectLater(
        find.byType(SeedGlyph),
        matchesGoldenFile('goldens/seed_glyph_64px.png'),
      );
    });
  });

  group('one drawing, scaled — the structure sweep', () {
    testWidgets(
      'the drawing\'s parts are pinned across 24–168px, both palettes',
      (tester) async {
        // The claim the goldens cannot make alone: at EVERY size — the
        // zone marker to the illustration surfaces — the painter exposes
        // the same parts, and the parts are identified by their geometry,
        // not just counted: the filament fan and the stem as the line
        // layer, the achene as the one ink fill, the pompom circle as the
        // one mass. A different pair of paths would fail the bounds.
        // The expected rectangles are built from the parts' control
        // points, which is exact only because Path.getBounds() returns
        // the control-point hull (Skia's conservative behaviour). An
        // engine that ever returned tight curve bounds would fail these
        // assertions; the fix then is containment (actual ⊆ hull), not
        // equality.
        final filamentHull = _boundsOf([
          for (final f in filaments) ...[f.p0, f.c1, f.c2, f.p3],
        ]);
        final stemHull = _boundsOf([stemStart, stemControl, hub]);
        final acheneHull = _boundsOf([
          acheneStart,
          acheneC1a,
          acheneC2a,
          achenePoint,
          acheneC1b,
          acheneC2b,
        ]);
        final pompomRect = Rect.fromCircle(
          center: pompomBaseLocal.offset,
          radius: pompomRadiusU,
        );

        for (final brightness in Brightness.values) {
          final dark = brightness == Brightness.dark;
          final theme = dark ? OrganizerTheme.dark() : OrganizerTheme.light();
          final expectedMass = dark
              ? DarkPalette.destTrashDark
              : IconMassPalette.destTrash;
          final expectedInk = dark
              ? DarkPalette.inkPrimaryDark
              : FieldPalette.inkPrimary;
          for (final size in <double>[
            Spacing.glyphZoneMarker,
            Spacing.glyphDense,
            Spacing.glyphMin,
            // 56 — the boundary size where the movement lines once began
            // (the dissolved threshold); swept deliberately, and now only
            // another at-rest size.
            56,
            Spacing.glyphDestination,
            96,
            150,
            168,
          ]) {
            await tester.pumpWidget(
              MaterialApp(
                theme: theme,
                home: Center(child: SeedGlyph(size)),
              ),
            );
            await tester.pumpAndSettle();
            final painter = _treatmentPainterOf(tester);
            final where = '${size}px, ${brightness.name}';
            expect(
              painter.linePaths,
              hasLength(2),
              reason: '$where: the line layer is filaments + stem — at rest',
            );
            expect(
              painter.inkFillPaths,
              hasLength(1),
              reason: '$where: one ink fill — the achene',
            );
            expect(
              painter.massPaths,
              hasLength(1),
              reason: '$where: one mass — the pompom circle',
            );
            expect(
              painter.massColor,
              expectedMass,
              reason: '$where: the pompom resolves the theme\'s plate',
            );
            expect(
              painter.lineColor,
              expectedInk,
              reason: '$where: the line layer resolves the theme\'s ink',
            );
            _expectRect(
              painter.linePaths.first.getBounds(),
              filamentHull,
              '$where: the first line path is the filament fan',
            );
            _expectRect(
              painter.linePaths.last.getBounds(),
              stemHull,
              '$where: the second line path is the stem',
            );
            _expectRect(
              painter.inkFillPaths.single.getBounds(),
              acheneHull,
              '$where: the ink fill is the achene',
            );
            _expectRect(
              painter.massPaths.single.getBounds(),
              pompomRect,
              '$where: the mass is the pompom circle',
            );
          }
        }
      },
    );
  });
}

TreatmentPainter _treatmentPainterOf(WidgetTester tester) {
  final found = find.byWidgetPredicate(
    (widget) => widget is CustomPaint && widget.painter is TreatmentPainter,
  );
  return (tester.widget(found) as CustomPaint).painter! as TreatmentPainter;
}

Rect _boundsOf(Iterable<SeedPoint> points) {
  var left = double.infinity;
  var top = double.infinity;
  var right = double.negativeInfinity;
  var bottom = double.negativeInfinity;
  for (final p in points) {
    left = math.min(left, p.x);
    top = math.min(top, p.y);
    right = math.max(right, p.x);
    bottom = math.max(bottom, p.y);
  }
  return Rect.fromLTRB(left, top, right, bottom);
}

void _expectRect(Rect actual, Rect expected, String because) {
  expect(actual.left, closeTo(expected.left, 1e-6), reason: '$because — left');
  expect(actual.top, closeTo(expected.top, 1e-6), reason: '$because — top');
  expect(
    actual.right,
    closeTo(expected.right, 1e-6),
    reason: '$because — right',
  );
  expect(
    actual.bottom,
    closeTo(expected.bottom, 1e-6),
    reason: '$because — bottom',
  );
}

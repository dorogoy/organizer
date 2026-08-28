// Pure geometry of the dandelion seed glyph (DESIGN.md {components.seed-glyph},
// the third destination `Tirar o soltar`), shared by the painter and its test
// so the drawn pompom radius is asserted over the same numbers that are
// rendered.
//
// Silhouette source: imports/dandelion-seed-reference.png, reconciled claim by
// claim in reconcile-dandelion-seed-reference.md; the fan is the constructed
// geometry of mockups/seed-at-scale-1.html §4 with the shipped corrections —
// 8 filaments at every size, and a whole-drawing +8° rotation that sets the
// stem axis to 45.0°, equal to the global offset vector, so the transverse
// component is exactly 0 (the 53.0° geometry was the bug, not the spec).
import 'dart:math' as math;
import 'dart:ui';

import 'glyph_canvas.dart' show glyphOffsetU;

/// The pompom-hub circle's drawn radius, in user units.
///
/// DRAWN AND MEASURED (DESIGN.md leaves this one number to draw time):
/// r = 1.80u, displaced 0.30u off the hub centre toward the leeward (dense)
/// side — sotavento, where the angular spacing between filaments closes —
/// with the global 45° offset applied on top of that placement. It clears
/// the 1.70u anchor (the first size the eye files as colour, the last that
/// fits entirely inside the bundle zone when centred), and it exploits the
/// fan's own asymmetry: the dense displacement tucks the disc's lower-left
/// arc under the hub bundle — the exact failure that sank the centred
/// r = 2.30u candidate ("a bare curved edge reading as a ball behind the
/// drawing") — while its free edge stays wholly under filaments.
const double pompomRadiusU = 1.80;

/// Displacement of the pompom circle's centre off the hub, toward the
/// leeward (dense) side, before the global offset is applied.
const double pompomDenseDisplacementU = 0.30;

/// The measured bound this radius was drawn against: the free edge's worst
/// distance to filament ink may not exceed the design's own accepted
/// peek — the centred r = 1.70u candidate's 0.83u — plus a small engineering
/// margin (0.90u rounded). No edge point may leave the fan's swept sector.
const double maxPermittedEdgeDistanceU = 0.90;

/// The seed is drawn at 45.0° only after this whole-drawing rotation of the
/// 53.0° constructed geometry.
const double seedAxisCorrectionDegrees = 8.0;

/// Motion dashes appear only where the seed is drawn at 56px or above;
/// below that they are 4px specks that read as dirt. Off at glyph scale,
/// and off in the destination trio regardless of size (the trio seed is at
/// rest by decision) — pass `motionDashes: false` there.
const double motionDashThresholdPx = 56;

/// Filament count, permanently — `Nunca añadir rasgos`.
const int filamentCount = 8;

final class SeedPoint {
  const SeedPoint(this.x, this.y);

  final double x;
  final double y;

  Offset get offset => Offset(x, y);

  SeedPoint operator +(SeedPoint o) => SeedPoint(x + o.x, y + o.y);

  SeedPoint operator -(SeedPoint o) => SeedPoint(x - o.x, y - o.y);

  SeedPoint operator *(double f) => SeedPoint(x * f, y * f);
}

/// The filament fan, constructed (not drawn by eye):
///   theta(t) = 152° − 174°·(1−(1−t)^1.25)   — one-way comb, dense to leeward
///   L(t) = 8.6 − 1.8·((0.40−t)/0.40)^1.6    (t < 0.40, windward branch)
///   L(t) = 8.6 − 3.8·((t−0.40)/0.60)^1.5    (t ≥ 0.40, leeward branch)
///   C1 = H + 0.32·L·dir + 0.08·L·perp,  C2 = H + 0.68·L·dir + 0.30·L·perp
/// with dir = (cos θ, −sin θ) and perp = (sin θ, cos θ) in screen
/// coordinates. Reproduces the published fan8 paths exactly.
final class FilamentCurve {
  const FilamentCurve(this.p0, this.c1, this.c2, this.p3);

  final SeedPoint p0;
  final SeedPoint c1;
  final SeedPoint c2;
  final SeedPoint p3;
}

/// The pompom hub — the point where the filaments converge.
final SeedPoint hub = const SeedPoint(12.4, 10.2);

double _thetaDeg(int i) {
  final t = i / (filamentCount - 1);
  final shaped = math.pow(1 - t, 1.25).toDouble();
  return 152 - 174 * (1 - shaped);
}

double _lengthU(int i) {
  final t = i / (filamentCount - 1);
  if (t < 0.40) {
    final shaped = math.pow((0.40 - t) / 0.40, 1.6).toDouble();
    return 8.6 - 1.8 * shaped;
  }
  final shaped = math.pow((t - 0.40) / 0.60, 1.5).toDouble();
  return 8.6 - 3.8 * shaped;
}

FilamentCurve _filament(int i) {
  final th = _thetaDeg(i) * math.pi / 180;
  final l = _lengthU(i);
  final dir = SeedPoint(math.cos(th), -math.sin(th));
  final perp = SeedPoint(math.sin(th), math.cos(th));
  return FilamentCurve(
    hub,
    hub + dir * (0.32 * l) + perp * (0.08 * l),
    hub + dir * (0.68 * l) + perp * (0.30 * l),
    hub + dir * l,
  );
}

/// The eight filaments, windward (i = 0) to leeward (i = 7).
final List<FilamentCurve> filaments = List.unmodifiable(
  List.generate(filamentCount, _filament),
);

/// The stem: quadratic A1 → (8.9, 13.5) → hub, one continuous bowed form
/// with the achene.
const SeedPoint stemStart = SeedPoint(6.35, 18.25);
const SeedPoint stemControl = SeedPoint(8.9, 13.5);

/// The filled achene: two mirrored cubics, widest where the stem meets it
/// (2.52u), drawn to a fine point at the lower-left (4.23u long).
const SeedPoint acheneStart = stemStart;
const SeedPoint achenePoint = SeedPoint(3.7, 21.55);
const SeedPoint acheneC1a = SeedPoint(4.696, 18.55);
const SeedPoint acheneC2a = SeedPoint(2.919, 19.837);
const SeedPoint acheneC1b = SeedPoint(5.541, 21.943);
const SeedPoint acheneC2b = SeedPoint(6.414, 19.93);

/// The five loose motion arcs, 21.78u of ink at mean 4.36u — the 4th's tail
/// is trimmed by 0.5u (from (9, 13.4) to (8.5, 13.15)) so its ink never
/// merges with the stem's at the sizes where dashes render (≥ 56px); the
/// design's own "no tocan la semilla" is honoured over the mockup's exact
/// endpoint. Never drawn below [motionDashThresholdPx], never in the trio.
const List<(SeedPoint, SeedPoint, SeedPoint)> motionDashArcs = [
  (SeedPoint(18.6, 4.4), SeedPoint(20.6, 3.1), SeedPoint(22.3, 3.8)),
  (SeedPoint(19.7, 7.7), SeedPoint(21.4, 6.6), SeedPoint(22.5, 7.4)),
  (SeedPoint(16.2, 2.3), SeedPoint(18.1, 1.25), SeedPoint(19.6, 1.9)),
  (SeedPoint(2.4, 15.2), SeedPoint(5.6, 12.6), SeedPoint(8.5, 13.15)),
  (SeedPoint(1.7, 18.1), SeedPoint(3.1, 16.2), SeedPoint(5.1, 15.8)),
];

/// Bisector of the leeward pair (filaments 6–7, the tightest spacing) — the
/// dense side, sotavento, toward which the pompom circle is displaced.
final SeedPoint denseDirection = (() {
  final th = ((_thetaDeg(6) + _thetaDeg(7)) / 2) * math.pi / 180;
  return SeedPoint(math.cos(th), -math.sin(th));
})();

/// The global offset vector expressed in the drawing's local frame: the
/// screen-space 45° vector rotated back by the +8° whole-drawing
/// rotation. In local coords it runs at 53° — exactly along the seed's own
/// constructed axis, which is what the axial rule asks (the offset runs
/// along the glyph's own axis; the drawing's rotation then carries both to
/// the screen 45° vector, transverse component exactly 0).
final SeedPoint globalOffsetLocal = (() {
  final a = -seedAxisCorrectionDegrees * math.pi / 180;
  final x = glyphOffsetU;
  final y = -glyphOffsetU;
  return SeedPoint(
    x * math.cos(a) - y * math.sin(a),
    x * math.sin(a) + y * math.cos(a),
  );
})();

/// The pompom circle's centre in the drawing's local frame BEFORE the
/// global offset — this is what the mass path is authored against; the
/// shared treatment painter applies the offset on top (screen space).
final SeedPoint pompomBaseLocal =
    hub + denseDirection * pompomDenseDisplacementU;

/// The pompom circle's centre relative to the filaments as rendered: the
/// base placement plus the global offset in the drawing's local frame.
/// Coverage is a property of the rendered glyph, and the painter's
/// screen-space offset maps back to exactly this local position.
final SeedPoint pompomCentreLocal = pompomBaseLocal + globalOffsetLocal;

/// Flattens a cubic Bézier into [segments] chords for distance/coverage
/// checks.
List<SeedPoint> flattenCubic(
  SeedPoint p0,
  SeedPoint p1,
  SeedPoint p2,
  SeedPoint p3, [
  int segments = 120,
]) {
  return List.generate(segments + 1, (k) {
    final u = k / segments;
    final v = 1 - u;
    return p0 * (v * v * v) +
        p1 * (3 * v * v * u) +
        p2 * (3 * v * u * u) +
        p3 * (u * u * u);
  });
}

/// Distance from [p] to the nearest filament centreline.
double distanceToFilaments(SeedPoint p) {
  var best = double.infinity;
  for (final f in filaments) {
    final pts = flattenCubic(f.p0, f.c1, f.c2, f.p3);
    for (var k = 0; k < pts.length - 1; k++) {
      best = math.min(best, _distanceToChord(p, pts[k], pts[k + 1]));
    }
  }
  return best;
}

double _distanceToChord(SeedPoint p, SeedPoint a, SeedPoint b) {
  final ab = b - a;
  final l2 = ab.x * ab.x + ab.y * ab.y;
  if (l2 == 0) {
    final dx = p.x - a.x;
    final dy = p.y - a.y;
    return math.sqrt(dx * dx + dy * dy);
  }
  var t = ((p.x - a.x) * ab.x + (p.y - a.y) * ab.y) / l2;
  t = t.clamp(0.0, 1.0);
  final dx = p.x - (a.x + ab.x * t);
  final dy = p.y - (a.y + ab.y * t);
  return math.sqrt(dx * dx + dy * dy);
}

/// The fan's swept sector as seen from the hub: filament rays windward
/// (−152.0°) through up to leeward (+22.0°). The sector below/left of it is
/// where only the stem passes — where the centred r = 2.30u candidate's
/// bare arc emerged.
final (double, double) fanSectorRadians = (() {
  double toPhi(int i) => -_thetaDeg(i) * math.pi / 180;
  return (toPhi(0), toPhi(7));
})();

bool _inFanSector(SeedPoint p) {
  final v = p - hub;
  final rho = math.sqrt(v.x * v.x + v.y * v.y);
  if (rho < 1e-9) {
    return true;
  }
  final phi = math.atan2(v.y, v.x);
  final (lo, hi) = fanSectorRadians;
  return phi >= lo - 1e-9 && phi <= hi + 1e-9;
}

final class PompomCoverage {
  const PompomCoverage({
    required this.worstEdgeDistanceU,
    required this.sectorViolations,
  });

  /// Worst distance from an edge point of the drawn circle to filament ink.
  final double worstEdgeDistanceU;

  /// Edge points lying outside the fan's swept sector (a bare arc).
  final int sectorViolations;

  bool get isWhollyCovered =>
      sectorViolations == 0 && worstEdgeDistanceU <= maxPermittedEdgeDistanceU;
}

/// Measures the drawn pompom circle's coverage: every sampled edge point
/// must lie in the fan's swept sector and within
/// [maxPermittedEdgeDistanceU] of filament ink — the same bound the
/// design's accepted centred r = 1.70u candidate measures (0.83u), rounded
/// up with margin.
///
/// Distances are measured to filament CENTRELINES, not ink edges: real ink
/// extends half a stroke width beyond the centreline on each side, so the
/// measured figure overstates the true edge-to-ink distance — the bound is
/// conservative by construction, never optimistic.
PompomCoverage measurePompomCoverage({int samples = 720}) {
  var worst = 0.0;
  var violations = 0;
  for (var k = 0; k < samples; k++) {
    final a = 2 * math.pi * k / samples;
    final p = SeedPoint(
      pompomCentreLocal.x + pompomRadiusU * math.cos(a),
      pompomCentreLocal.y + pompomRadiusU * math.sin(a),
    );
    worst = math.max(worst, distanceToFilaments(p));
    if (!_inFanSector(p)) {
      violations++;
    }
  }
  return PompomCoverage(
    worstEdgeDistanceU: worst,
    sectorViolations: violations,
  );
}

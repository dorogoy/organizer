import 'package:core/pool/pool_fact.dart';
import 'package:core/weave/weave.dart' show lowEnergyMaxEstimateSeconds;
import 'package:test/test.dart';

void main() {
  test('the origin taxonomy has exactly the four genesis paths (AD-14)', () {
    expect(Origin.values, hasLength(4));
    expect(
      Origin.values,
      containsAll(<Origin>[
        Origin.shipped,
        Origin.manual,
        Origin.local,
        Origin.cloud,
      ]),
    );
  });

  test('the size taxonomy has exactly the three 1-3-5 members (FR-27)', () {
    expect(Size.values, hasLength(3));
    expect(Size.values, <Size>[Size.instant, Size.maintenance, Size.focus]);
  });

  test('the ONE duration→size rule bands every estimate: ≤ 60 s instant, '
      '61–599 s maintenance, ≥ 600 s focus — the 9:00–9:59 seam declared '
      'maintenance (Story 5.7, FR-27)', () {
    expect(bandInstantMostSeconds, 60);
    expect(bandMaintenanceMostSeconds, 599);
    for (final seconds in [0, 1, 30, 60]) {
      expect(
        sizeOfEstimateSeconds(seconds),
        Size.instant,
        reason: '$seconds s bands instant',
      );
    }
    for (final seconds in [61, 180, 300, 420, 599]) {
      expect(
        sizeOfEstimateSeconds(seconds),
        Size.maintenance,
        reason:
            '$seconds s bands maintenance — the scan band 180–300 '
            'included, and the declared seam 540–599 closest to nine '
            'minutes',
      );
    }
    for (final seconds in [600, 601, 900]) {
      expect(
        sizeOfEstimateSeconds(seconds),
        Size.focus,
        reason: '$seconds s bands focus',
      );
    }
  });

  test('the instant band\'s ceiling IS the 🔴 day\'s — one number, '
      'two declarations (Story 5.7, FR-27, FR-4)', () {
    // The identity both docs claim: two independent literals could
    // drift with no failing test — this pin is the drift\'s failure.
    expect(bandInstantMostSeconds, lowEnergyMaxEstimateSeconds);
  });

  test('a pool fact carries id, origin, size and instant plus offset', () {
    const fact = PoolFact(
      id: '0190bbbb-0000-7000-8000-000000000001',
      origin: Origin.manual,
      size: Size.maintenance,
      instantUtcMicros: 1700000000123456,
      offsetSeconds: 7200,
    );
    expect(fact.id, '0190bbbb-0000-7000-8000-000000000001');
    expect(fact.origin, Origin.manual);
    expect(fact.size, Size.maintenance);
    expect(fact.instantUtcMicros, 1700000000123456);
    expect(fact.offsetSeconds, 7200);
    // Origins whose context lives elsewhere carry none (AD-14).
    expect(fact.originContext, isNull);
  });

  test('a manual capture\'s fact carries its own single line as the '
      'Origin Context (Story 3.2, AD-14)', () {
    const fact = PoolFact(
      id: '0190bbbb-0000-7000-8000-000000000002',
      origin: Origin.manual,
      size: Size.focus,
      instantUtcMicros: 1700000000654321,
      offsetSeconds: 3600,
      originContext: 'llamar al dentista',
    );
    expect(fact.originContext, 'llamar al dentista');
  });

  test('a fact may carry the dictation boolean — a provenance fact '
      'beside the origin, never inside it (Story 3.4, FR-32, AD-26)', () {
    const dictated = PoolFact(
      id: '0190bbbb-0000-7000-8000-000000000003',
      origin: Origin.manual,
      size: Size.maintenance,
      instantUtcMicros: 1700000000999999,
      offsetSeconds: 3600,
      originContext: 'llamar cinco minutos al dentista',
      dictated: true,
    );
    // Dictation is an input method, not a genesis path: the origin
    // stays `manual`, exactly as a typed capture's.
    expect(dictated.dictated, isTrue);
    expect(dictated.origin, Origin.manual);

    const typed = PoolFact(
      id: '0190bbbb-0000-7000-8000-000000000004',
      origin: Origin.manual,
      size: Size.maintenance,
      instantUtcMicros: 1700000000888888,
      offsetSeconds: 3600,
      originContext: 'llamar al dentista',
      dictated: false,
    );
    expect(typed.dictated, isFalse);

    // Absent is a shape too — old rows, and origins whose authorship
    // the boolean never described.
    const contextless = PoolFact(
      id: '0190bbbb-0000-7000-8000-000000000005',
      origin: Origin.shipped,
      size: Size.instant,
      instantUtcMicros: 1700000000777777,
      offsetSeconds: 0,
    );
    expect(contextless.dictated, isNull);
  });
}

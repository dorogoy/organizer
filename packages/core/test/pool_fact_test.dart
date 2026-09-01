import 'package:core/pool/pool_fact.dart';
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
}

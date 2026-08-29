import 'package:core/catalogue/catalogue.dart';
import 'package:core/energy/energy.dart';
import 'package:core/log/log_entry.dart';
import 'package:core/pool/pool_fact.dart';
import 'package:core/weave/weave.dart';
import 'package:test/test.dart';

import 'test_util.dart';

CatalogueEntry _entry(
  String id,
  Size size,
  Cadence cadence, {
  Zone? zone,
  String? name,
}) => CatalogueEntry(
  id: id,
  size: size,
  cadence: cadence,
  zone: zone,
  name: name ?? 'Tarea de $id',
);

/// The shared fixture: two weekly focus candidates, one `fondo` focus,
/// one daily focus (Baseline Upkeep), four maintenance and six instant
/// entries — enough for full 1-3-5 draws with known id order.
final Catalogue _catalogue = Catalogue(
  version: 1,
  entries: [
    _entry('zona-a', Size.focus, Cadence.weekly, zone: Zone.z1),
    _entry('zona-b', Size.focus, Cadence.weekly, zone: Zone.z2),
    _entry('fondo-z', Size.focus, Cadence.seasonal),
    _entry('cocina-diaria', Size.focus, Cadence.daily),
    _entry('man-a', Size.maintenance, Cadence.daily),
    _entry('man-b', Size.maintenance, Cadence.daily),
    _entry('man-c', Size.maintenance, Cadence.daily),
    _entry('man-d', Size.maintenance, Cadence.daily),
    _entry('hab-a', Size.instant, Cadence.daily),
    _entry('hab-b', Size.instant, Cadence.daily),
    _entry('hab-c', Size.instant, Cadence.daily),
    _entry('hab-d', Size.instant, Cadence.daily),
    _entry('hab-e', Size.instant, Cadence.daily),
    _entry('hab-f', Size.instant, Cadence.daily),
  ],
);

MomentEntry _sessionStarted(int micros) => MomentEntry(
  id: 'started-$micros',
  instantUtcMicros: micros,
  offsetSeconds: 0,
  kind: LogKind.sessionStarted,
);

MomentEntry _sessionEnded(int micros) => MomentEntry(
  id: 'ended-$micros',
  instantUtcMicros: micros,
  offsetSeconds: 0,
  kind: LogKind.sessionEnded,
);

ItemActEntry _dealt(int micros, String itemId) => ItemActEntry(
  id: 'dealt-$micros-$itemId',
  instantUtcMicros: micros,
  offsetSeconds: 0,
  kind: LogKind.cardDealt,
  itemId: itemId,
  itemOrigin: Origin.shipped,
);

ItemActEntry _done(int micros, String itemId) => ItemActEntry(
  id: 'done-$micros-$itemId',
  instantUtcMicros: micros,
  offsetSeconds: 0,
  kind: LogKind.cardDone,
  itemId: itemId,
  itemOrigin: Origin.shipped,
);

ItemActEntry _skipped(int micros, String itemId) => ItemActEntry(
  id: 'skipped-$micros-$itemId',
  instantUtcMicros: micros,
  offsetSeconds: 0,
  kind: LogKind.cardSkipped,
  itemId: itemId,
  itemOrigin: Origin.shipped,
);

void main() {
  final now = utcMicros(2026, 8, 28, 12);

  test('a fresh day composes one Focus Chunk, three Micro-maintenance and '
      'five Instant Habits, with per-size estimates', () {
    final composition = composeDay(
      catalogue: _catalogue,
      log: const [],
      instantUtcMicros: now,
      offsetSeconds: 0,
    );
    expect(composition.focus, isNotNull);
    expect(composition.focus!.id, 'fondo-z');
    expect(composition.focus!.size, Size.focus);
    expect(composition.focus!.origin, Origin.shipped);
    expect(composition.focus!.name, 'Tarea de fondo-z');
    expect(composition.focus!.estimateSeconds, focusEstimateSeconds);

    expect(composition.maintenance.map((card) => card.id).toList(), [
      'man-a',
      'man-b',
      'man-c',
    ]);
    expect(
      composition.maintenance.every(
        (card) => card.estimateSeconds == maintenanceEstimateSeconds,
      ),
      isTrue,
    );
    expect(composition.instantHabits.map((card) => card.id).toList(), [
      'hab-a',
      'hab-b',
      'hab-c',
      'hab-d',
      'hab-e',
    ]);
    expect(
      composition.instantHabits.every(
        (card) => card.estimateSeconds == instantEstimateSeconds,
      ),
      isTrue,
    );
  });

  test('the composition is deterministic: same inputs, same composition', () {
    final first = composeDay(
      catalogue: _catalogue,
      log: const [],
      instantUtcMicros: now,
      offsetSeconds: 0,
    );
    final second = composeDay(
      catalogue: _catalogue,
      log: const [],
      instantUtcMicros: now,
      offsetSeconds: 0,
    );
    expect(second.focus, first.focus);
    expect(second.maintenance, equals(first.maintenance));
    expect(second.instantHabits, equals(first.instantHabits));
  });

  test('a tie between never-dealt candidates resolves by stable id order', () {
    final composition = composeDay(
      catalogue: _catalogue,
      log: const [],
      instantUtcMicros: now,
      offsetSeconds: 0,
    );
    // Never-dealt focus candidates in id order: fondo-z, zona-a, zona-b.
    expect(composition.focus!.id, 'fondo-z');
    // Never-dealt maintenance in id order: man-a first.
    expect(composition.maintenance.first.id, 'man-a');
  });

  test('least-recently-dealt orders the draws: never-dealt first, then the '
      'oldest recorded deal (AD-3)', () {
    final yesterday = utcMicros(2026, 8, 27, 12);
    final earlierToday = utcMicros(2026, 8, 28, 8);
    final log = [_dealt(yesterday, 'man-b'), _dealt(earlierToday, 'man-a')];
    final composition = composeDay(
      catalogue: _catalogue,
      log: log,
      instantUtcMicros: now,
      offsetSeconds: 0,
    );
    // Never-dealt man-c and man-d rank first (id order), then man-b —
    // dealt longest ago — then man-a.
    expect(composition.maintenance.map((card) => card.id).toList(), [
      'man-c',
      'man-d',
      'man-b',
    ]);
  });

  test('a skipped chunk re-resolves identity and leaves the slot open', () {
    final log = [
      _sessionStarted(utcMicros(2026, 8, 28, 10)),
      _dealt(utcMicros(2026, 8, 28, 10, 0, 1), 'zona-a'),
      _skipped(utcMicros(2026, 8, 28, 10, 0, 2), 'zona-a'),
    ];
    final composition = composeDay(
      catalogue: _catalogue,
      log: log,
      instantUtcMicros: now,
      offsetSeconds: 0,
    );
    expect(composition.focus, isNotNull, reason: 'the slot stays open');
    final deal = nextDeal(
      catalogue: _catalogue,
      log: log,
      instantUtcMicros: now,
      offsetSeconds: 0,
    );
    expect(deal!.id, isNot('zona-a'));
    expect(deal.size, Size.focus);
  });

  test(
    'a chunk answered Hecho closes the day\'s slot: upkeep and habits only',
    () {
      final log = [
        _sessionStarted(utcMicros(2026, 8, 28, 10)),
        _dealt(utcMicros(2026, 8, 28, 10, 0, 1), 'zona-a'),
        _done(utcMicros(2026, 8, 28, 10, 0, 2), 'zona-a'),
      ];
      final composition = composeDay(
        catalogue: _catalogue,
        log: log,
        instantUtcMicros: now,
        offsetSeconds: 0,
      );
      expect(composition.focus, isNull);
      expect(composition.maintenance, isNotEmpty);
      expect(composition.instantHabits, isNotEmpty);
      final deal = nextDeal(
        catalogue: _catalogue,
        log: log,
        instantUtcMicros: now,
        offsetSeconds: 0,
      );
      expect(deal!.size, isNot(Size.focus));

      // A second session the same domestic day composes no chunk either.
      final sameDaySecondSession = [
        ...log,
        _sessionEnded(utcMicros(2026, 8, 28, 11)),
        _sessionStarted(utcMicros(2026, 8, 28, 11, 30)),
      ];
      final reopened = composeDay(
        catalogue: _catalogue,
        log: sameDaySecondSession,
        instantUtcMicros: utcMicros(2026, 8, 28, 11, 31),
        offsetSeconds: 0,
      );
      expect(reopened.focus, isNull);
    },
  );

  test('a session crossing 04:00 charges its card acts to its start day, and '
      'the crossed-into day\'s slot stays untouched (AD-19)', () {
    final log = [
      _sessionStarted(utcMicros(2026, 8, 28, 3, 40)),
      _dealt(utcMicros(2026, 8, 28, 3, 41), 'zona-a'),
      _done(utcMicros(2026, 8, 28, 4, 10), 'zona-a'),
    ];
    // The session's own day is 2026-08-27: the slot it closed is that
    // day's, and composing inside the session anchors there.
    final inside = composeDay(
      catalogue: _catalogue,
      log: log,
      instantUtcMicros: utcMicros(2026, 8, 28, 4, 15),
      offsetSeconds: 0,
    );
    expect(inside.focus, isNull);

    // After the session closes, the crossed-into day composes a chunk:
    // its slot was never touched by the crossing session.
    final nextDay = [
      ...log,
      _sessionEnded(utcMicros(2026, 8, 28, 4, 20)),
      _sessionStarted(utcMicros(2026, 8, 28, 8)),
    ];
    final morning = composeDay(
      catalogue: _catalogue,
      log: nextDay,
      instantUtcMicros: utcMicros(2026, 8, 28, 8, 1),
      offsetSeconds: 0,
    );
    expect(morning.focus, isNotNull);
  });

  test('a bag below ten minutes composes no chunk, silently; upkeep and '
      'habits are never charged to the bag', () {
    final composition = composeDay(
      catalogue: _catalogue,
      log: const [],
      instantUtcMicros: now,
      offsetSeconds: 0,
      bagMinutes: 9,
    );
    expect(composition.focus, isNull);
    expect(composition.maintenance, hasLength(3));
    expect(composition.instantHabits, hasLength(5));

    // Exactly ten minutes still composes the chunk (FR-7's floor).
    final atFloor = composeDay(
      catalogue: _catalogue,
      log: const [],
      instantUtcMicros: now,
      offsetSeconds: 0,
      bagMinutes: focusChunkLeastBagMinutes,
    );
    expect(atFloor.focus, isNotNull);
  });

  test('low energy composes no chunk; medium changes nothing (FR-4)', () {
    final low = composeDay(
      catalogue: _catalogue,
      log: const [],
      instantUtcMicros: now,
      offsetSeconds: 0,
      energy: EnergyLevel.low,
    );
    expect(low.focus, isNull);
    expect(low.maintenance, hasLength(3));
    expect(low.instantHabits, hasLength(5));

    final medium = composeDay(
      catalogue: _catalogue,
      log: const [],
      instantUtcMicros: now,
      offsetSeconds: 0,
      energy: EnergyLevel.medium,
    );
    expect(medium.focus, isNotNull);
    expect(medium.maintenance, hasLength(3));
    expect(medium.instantHabits, hasLength(5));
  });

  test('Baseline Upkeep that fits the chunk\'s size never occupies the slot '
      '(FR-12)', () {
    final upkeepOnly = Catalogue(
      version: 1,
      entries: [
        _entry('cocina-diaria', Size.focus, Cadence.daily),
        _entry('man-a', Size.maintenance, Cadence.daily),
        _entry('hab-a', Size.instant, Cadence.daily),
      ],
    );
    final composition = composeDay(
      catalogue: upkeepOnly,
      log: const [],
      instantUtcMicros: now,
      offsetSeconds: 0,
    );
    expect(composition.focus, isNull);
    expect(composition.maintenance.map((card) => card.id), ['man-a']);
    expect(composition.instantHabits.map((card) => card.id), ['hab-a']);
    final deal = nextDeal(
      catalogue: upkeepOnly,
      log: const [],
      instantUtcMicros: now,
      offsetSeconds: 0,
    );
    expect(deal!.size, isNot(Size.focus));
  });

  test('the day\'s maintenance and habit draws are capped by count; when they '
      'are dealt, the day offers nothing more', () {
    final log = [
      _sessionStarted(utcMicros(2026, 8, 28, 10)),
      for (final (index, id) in ['man-a', 'man-b', 'man-c'].indexed) ...[
        _dealt(utcMicros(2026, 8, 28, 10, index), id),
        _done(utcMicros(2026, 8, 28, 10, index, 30), id),
      ],
    ];
    final maintenanceExhausted = nextDeal(
      catalogue: _catalogue,
      log: log,
      instantUtcMicros: now,
      offsetSeconds: 0,
      energy: EnergyLevel.low,
    );
    expect(maintenanceExhausted!.size, Size.instant);

    final habitsToo = [
      ...log,
      for (final (index, id) in [
        'hab-a',
        'hab-b',
        'hab-c',
        'hab-d',
        'hab-e',
      ].indexed) ...[
        _dealt(utcMicros(2026, 8, 28, 11, index), id),
        _done(utcMicros(2026, 8, 28, 11, index, 30), id),
      ],
    ];
    final exhausted = nextDeal(
      catalogue: _catalogue,
      log: habitsToo,
      instantUtcMicros: now,
      offsetSeconds: 0,
      energy: EnergyLevel.low,
    );
    expect(exhausted, isNull);
  });

  test('shipped candidates are Origin.shipped items with catalogue ids and '
      'precedence; the focus offering excludes daily upkeep (AD-20)', () {
    final candidates = shippedCandidates(_catalogue);
    expect(
      candidates.every((candidate) => candidate.origin == Origin.shipped),
      isTrue,
    );
    expect(
      candidates.every(
        (candidate) => candidate.precedence == CandidatePrecedence.catalogue,
      ),
      isTrue,
    );
    final focusIds = candidates
        .where((candidate) => candidate.size == Size.focus)
        .map((candidate) => candidate.itemId)
        .toSet();
    expect(focusIds, {'zona-a', 'zona-b', 'fondo-z'});
    expect(
      candidates.where((candidate) => candidate.size == Size.maintenance),
      hasLength(4),
    );
    expect(
      candidates.where((candidate) => candidate.size == Size.instant),
      hasLength(6),
    );
  });

  test('cardForItem resolves a catalogue item into its card', () {
    final card = cardForItem(
      catalogue: _catalogue,
      itemId: 'man-b',
      origin: Origin.shipped,
    );
    expect(card!.size, Size.maintenance);
    expect(card.name, 'Tarea de man-b');
    expect(
      cardForItem(
        catalogue: _catalogue,
        itemId: 'nueva',
        origin: Origin.shipped,
      ),
      isNull,
    );
  });
}

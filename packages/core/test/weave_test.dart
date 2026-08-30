import 'package:core/catalogue/catalogue.dart';
import 'package:core/curation/curation.dart';
import 'package:core/day/calendar.dart';
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

/// The week's focus entries of one zone, `zona-<zone>-a` onward — the
/// shipped asset's per-zone arithmetic (5/3/4/5/3 focus entries).
List<CatalogueEntry> _zoneEntries(Zone zone, int count) => [
  for (var i = 0; i < count; i++)
    _entry(
      'zona-${zone.name}-${'abcde'[i]}',
      Size.focus,
      Cadence.weekly,
      zone: zone,
    ),
];

/// The `fondo` focus entries, `fondo-a` onward (twelve in the shipped
/// asset).
List<CatalogueEntry> _fondoEntries(int count) => [
  for (var i = 0; i < count; i++)
    _entry('fondo-${'abcdefghijkl'[i]}', Size.focus, Cadence.seasonal),
];

/// The shared fixture, mirroring the shipped asset's arithmetic: 5/3/4/5/3
/// zone focus entries + 12 `fondo` focus = 32 eligible chunks (the floor
/// is 28), one daily focus (Baseline Upkeep), four maintenance and six
/// instant entries.
final Catalogue _catalogue = Catalogue(
  version: 1,
  entries: [
    ..._zoneEntries(Zone.z1, 5),
    ..._zoneEntries(Zone.z2, 3),
    ..._zoneEntries(Zone.z3, 4),
    ..._zoneEntries(Zone.z4, 5),
    ..._zoneEntries(Zone.z5, 3),
    ..._fondoEntries(12),
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

/// The clusters minus [removed] — a resolved curation state handed to the
/// weave as the spec's Epic-5 writer one day will.
Set<CurationCluster> _clustersWithout(List<CurationCluster> removed) => {
  for (final cluster in allCurationClusters)
    if (!removed.contains(cluster)) cluster,
};

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

const int _microsPerDay = 24 * 60 * 60 * 1000 * 1000;

/// Noon on the [days]-th day of the fixture's rotation run — day 0 is
/// Monday 2026-08-24, whose ring position is z1 (weeks since the epoch
/// Monday 2000-01-03: 1390, mod 5 = 0).
int _day(int days, [int hour = 12]) =>
    utcMicros(2026, 8, 24, hour) + days * _microsPerDay;

void main() {
  // Friday 2026-08-28 — inside the week anchored Monday 2026-08-24,
  // whose active zone is z1.
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
    // Tier 1 — the week's active zone z1, never answered — beats the
    // never-answered fondo tier (AD-20's order).
    expect(composition.focus!.id, 'zona-z1-a');
    expect(composition.focus!.size, Size.focus);
    expect(composition.focus!.origin, Origin.shipped);
    expect(composition.focus!.name, 'Tarea de zona-z1-a');
    expect(composition.focus!.zone, Zone.z1);
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
    // Never-dealt z1 candidates in id order: zona-z1-a first.
    expect(composition.focus!.id, 'zona-z1-a');
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
      _dealt(utcMicros(2026, 8, 28, 10, 0, 1), 'zona-z1-a'),
      _skipped(utcMicros(2026, 8, 28, 10, 0, 2), 'zona-z1-a'),
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
    expect(deal!.id, isNot('zona-z1-a'));
    expect(deal.size, Size.focus);
    expect(deal.zone, Zone.z1, reason: 'tier 1 still resolves the zone');
  });

  test('the resolver itself never deals over an unanswered card (AD-3)', () {
    final log = [
      _sessionStarted(utcMicros(2026, 8, 28, 10)),
      _dealt(utcMicros(2026, 8, 28, 10, 0, 1), 'zona-z1-a'),
    ];
    expect(
      nextDeal(
        catalogue: _catalogue,
        log: log,
        instantUtcMicros: now,
        offsetSeconds: 0,
      ),
      isNull,
      reason: 'an unanswered card never produces a second card_dealt',
    );

    // Closing the session frees the resolver: the slot never closed, so
    // the chunk tier resolves — a different z1 candidate than the one
    // still outstanding when the session ended.
    final ended = [...log, _sessionEnded(utcMicros(2026, 8, 28, 10, 30))];
    final afterEnd = nextDeal(
      catalogue: _catalogue,
      log: ended,
      instantUtcMicros: now,
      offsetSeconds: 0,
    );
    expect(afterEnd!.size, Size.focus);
    expect(afterEnd.id, 'zona-z1-b');

    // Answering frees it too — and closes the day's slot, so the next
    // deal is upkeep, never a second chunk the same day.
    final answered = [
      ...log,
      _done(utcMicros(2026, 8, 28, 10, 0, 2), 'zona-z1-a'),
    ];
    final afterDone = nextDeal(
      catalogue: _catalogue,
      log: answered,
      instantUtcMicros: now,
      offsetSeconds: 0,
    );
    expect(afterDone!.size, Size.maintenance);
  });

  test('the pipeline holds the AD-3 line too: a dealt-but-unanswered card '
      'composes no chunk, upkeep and habits stand', () {
    final log = [
      _sessionStarted(utcMicros(2026, 8, 28, 10)),
      _dealt(utcMicros(2026, 8, 28, 10, 0, 1), 'zona-z1-a'),
    ];
    final composition = composeDay(
      catalogue: _catalogue,
      log: log,
      instantUtcMicros: now,
      offsetSeconds: 0,
    );
    expect(
      composition.focus,
      isNull,
      reason: 'the day never composes a second card over the standing one',
    );
    expect(composition.maintenance, hasLength(3));
    expect(composition.instantHabits, hasLength(5));
    expect(
      nextDeal(
        catalogue: _catalogue,
        log: log,
        instantUtcMicros: now,
        offsetSeconds: 0,
      ),
      isNull,
      reason: 'nextDeal still yields null outright while the deal stands',
    );
  });

  test('the AD-3 guard covers a maintenance deal too: a skipped chunk leaves '
      'the slot open yet composes none while the upkeep deal stands', () {
    final log = [
      _sessionStarted(utcMicros(2026, 8, 28, 10)),
      _dealt(utcMicros(2026, 8, 28, 10, 0, 1), 'zona-z1-a'),
      _skipped(utcMicros(2026, 8, 28, 10, 0, 2), 'zona-z1-a'),
      _dealt(utcMicros(2026, 8, 28, 10, 0, 3), 'man-a'),
    ];
    final standing = composeDay(
      catalogue: _catalogue,
      log: log,
      instantUtcMicros: now,
      offsetSeconds: 0,
    );
    expect(standing.focus, isNull, reason: 'a deal — any deal — stands');
    expect(standing.maintenance, hasLength(3));
    expect(standing.instantHabits, hasLength(5));

    // The answer frees the pipeline: the skip consumed nothing, so the
    // zone's tier resolves again.
    final freed = composeDay(
      catalogue: _catalogue,
      log: [...log, _done(utcMicros(2026, 8, 28, 10, 0, 4), 'man-a')],
      instantUtcMicros: now,
      offsetSeconds: 0,
    );
    expect(freed.focus!.id, 'zona-z1-b');
  });

  test('a skipped zone entry stays in its tier: it deals again before '
      'fondo once its zone-mates are answered (AD-20)', () {
    var log = <LogEntry>[];
    String chunkOn(int day) {
      final deal = nextDeal(
        catalogue: _catalogue,
        log: log,
        instantUtcMicros: _day(day),
        offsetSeconds: 0,
      )!;
      log
        ..add(_dealt(_day(day), deal.id))
        ..add(
          day == 0
              ? _skipped(_day(day) + 1, deal.id)
              : _done(_day(day) + 1, deal.id),
        );
      return deal.id;
    }

    expect(chunkOn(0), 'zona-z1-a', reason: 'the week opens on the zone');
    expect(chunkOn(1), 'zona-z1-b');
    expect(chunkOn(2), 'zona-z1-c');
    expect(chunkOn(3), 'zona-z1-d');
    expect(chunkOn(4), 'zona-z1-e');
    // Day 6 of the week: the zone's never-answered set holds exactly the
    // skipped entry — it deals again, before any fondo entry.
    expect(chunkOn(5), 'zona-z1-a');
  });

  test('a deferred Focus Chunk across the day boundary is simply a '
      'candidate again — the slot stays open, a chunk still composes, the '
      'deferred id re-deals in-run, and the next week opens on its own '
      'zone (FR-14, AD-1)', () {
    // The run is numbered from its own first session — Tuesday of the
    // z1 week — so run day 6 is the Monday that crosses the week
    // boundary.
    int day(int runDay) => _day(runDay + 1);

    // Run day 0 — Tuesday: the chunk deals and the user defers it.
    var log = <LogEntry>[
      _sessionStarted(utcMicros(2026, 8, 25, 10)),
      _dealt(utcMicros(2026, 8, 25, 10, 0, 1), 'zona-z1-a'),
      _skipped(utcMicros(2026, 8, 25, 10, 0, 2), 'zona-z1-a'),
      _sessionEnded(utcMicros(2026, 8, 25, 10, 30)),
    ];

    // Run day 1 — Wednesday, same week: the skip consumed nothing —
    // only a `card_done` closes the slot — so the day composes a chunk
    // and a different candidate resolves. No visible target moved,
    // because no target was stored. (That composing writes no row is
    // the facade suite's own pin — `nextCard` writes nothing — not a
    // list-length assertion here.)
    final logBeforeComposition = List<LogEntry>.from(log);
    final composition = composeDay(
      catalogue: _catalogue,
      log: log,
      instantUtcMicros: day(1),
      offsetSeconds: 0,
    );
    expect(
      log,
      equals(logBeforeComposition),
      reason:
          'composing the day between the deferred chunk and its next '
          'candidate adds zero rows',
    );
    expect(composition.focus, isNotNull, reason: 'the slot is open');
    expect(composition.focus!.id, 'zona-z1-b');
    expect(composition.focus!.zone, Zone.z1);

    // The run continues on its own arithmetic.
    String dealOn(int runDay) {
      final deal = nextDeal(
        catalogue: _catalogue,
        log: log,
        instantUtcMicros: day(runDay),
        offsetSeconds: 0,
      );
      expect(
        deal,
        isNotNull,
        reason:
            'run day $runDay must hold a chunk — the slot never '
            'closed, so never an empty day while an eligible entry exists',
      );
      log
        ..add(_dealt(day(runDay), deal!.id))
        ..add(_done(day(runDay) + 1, deal.id));
      return deal.id;
    }

    expect(dealOn(1), 'zona-z1-b');
    expect(dealOn(2), 'zona-z1-c');
    expect(dealOn(3), 'zona-z1-d');
    expect(dealOn(4), 'zona-z1-e');
    // Run day 5 — Sunday, still the same week: the zone's
    // never-answered set holds exactly the deferred entry, so it
    // re-deals within the run — never a carried-over target, because
    // no target was stored.
    expect(dealOn(5), 'zona-z1-a');
    // Run day 6 — the Monday past the week boundary: the next zone's
    // own entry leads the new week, and the deferred target never
    // carries over.
    final crossing = nextDeal(
      catalogue: _catalogue,
      log: log,
      instantUtcMicros: day(6),
      offsetSeconds: 0,
    );
    expect(
      crossing,
      isNotNull,
      reason: 'run day 6 — the new week\'s Monday — must hold a chunk',
    );
    expect(crossing!.id, 'zona-z2-a');
    expect(crossing.zone, Zone.z2);
  });

  test(
    'a chunk answered Hecho closes the day\'s slot: upkeep and habits only',
    () {
      final log = [
        _sessionStarted(utcMicros(2026, 8, 28, 10)),
        _dealt(utcMicros(2026, 8, 28, 10, 0, 1), 'zona-z1-a'),
        _done(utcMicros(2026, 8, 28, 10, 0, 2), 'zona-z1-a'),
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
      _dealt(utcMicros(2026, 8, 28, 3, 41), 'zona-z1-a'),
      _done(utcMicros(2026, 8, 28, 4, 10), 'zona-z1-a'),
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

  test('a 🔴 day consumes no rotation: the zone entry still deals the next '
      'day (FR-31)', () {
    // Day 1 is 🔴: no chunk composes, only upkeep deals and answers.
    final redDay = composeDay(
      catalogue: _catalogue,
      log: const [],
      instantUtcMicros: _day(0),
      offsetSeconds: 0,
      energy: EnergyLevel.low,
    );
    expect(redDay.focus, isNull);
    final log = [
      _dealt(_day(0), redDay.maintenance.first.id),
      _done(_day(0) + 1, redDay.maintenance.first.id),
    ];
    // Day 2: the zone's tier-1 set is untouched — nothing was answered.
    final deal = nextDeal(
      catalogue: _catalogue,
      log: log,
      instantUtcMicros: _day(1),
      offsetSeconds: 0,
    );
    expect(deal!.size, Size.focus);
    expect(deal.id, 'zona-z1-a');
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

  test('shipped candidates are Origin.shipped items with catalogue ids, '
      'precedence and their zone; the focus offering excludes daily upkeep '
      '(AD-20)', () {
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
    expect(focusIds, {
      ...[for (final entry in _zoneEntries(Zone.z1, 5)) entry.id],
      ...[for (final entry in _zoneEntries(Zone.z2, 3)) entry.id],
      ...[for (final entry in _zoneEntries(Zone.z3, 4)) entry.id],
      ...[for (final entry in _zoneEntries(Zone.z4, 5)) entry.id],
      ...[for (final entry in _zoneEntries(Zone.z5, 3)) entry.id],
      ...[for (final entry in _fondoEntries(12)) entry.id],
    });
    expect(
      candidates.where((candidate) => candidate.size == Size.maintenance),
      hasLength(4),
    );
    expect(
      candidates.where((candidate) => candidate.size == Size.instant),
      hasLength(6),
    );
    final byId = {
      for (final candidate in candidates) candidate.itemId: candidate,
    };
    expect(byId['zona-z3-b']!.zone, Zone.z3);
    expect(byId['fondo-a']!.zone, isNull);
    expect(byId['man-a']!.zone, isNull);
  });

  test('cluster filtering applies to every candidate: a disabled cluster '
      'offers nothing, an empty set offers nothing at all (AD-16)', () {
    expect(shippedCandidates(_catalogue, activeClusters: {}), isEmpty);
    final anclasOnly = shippedCandidates(
      _catalogue,
      activeClusters: {CurationCluster.anclas},
    );
    expect(anclasOnly.map((candidate) => candidate.itemId).toSet(), {
      'hab-a',
      'hab-b',
      'hab-c',
      'hab-d',
      'hab-e',
      'hab-f',
    });
    final withoutZ2 = shippedCandidates(
      _catalogue,
      activeClusters: _clustersWithout([CurationCluster.z2]),
    );
    expect(withoutZ2.where((candidate) => candidate.zone == Zone.z2), isEmpty);
    expect(
      withoutZ2.where((candidate) => candidate.size == Size.focus).length,
      29,
      reason: '32 eligible minus the three z2 focus entries',
    );
  });

  test(
    'cardForItem resolves a catalogue item into its card, zone included',
    () {
      final card = cardForItem(
        catalogue: _catalogue,
        itemId: 'man-b',
        origin: Origin.shipped,
      );
      expect(card!.size, Size.maintenance);
      expect(card.name, 'Tarea de man-b');
      expect(card.zone, isNull);
      final zoned = cardForItem(
        catalogue: _catalogue,
        itemId: 'zona-z3-b',
        origin: Origin.shipped,
      );
      expect(zoned!.zone, Zone.z3);
      expect(
        cardForItem(
          catalogue: _catalogue,
          itemId: 'nueva',
          origin: Origin.shipped,
        ),
        isNull,
      );
    },
  );

  test('two cards differing only in zone compare unequal; toString renders '
      'the zone and never the literal null', () {
    // An id and name with no hyphens and no digits, so the exact-string
    // pins below can only match the rendered shape itself.
    Card cardOf(Zone? zone) => Card(
      id: 'k',
      size: Size.focus,
      name: 'T',
      origin: Origin.shipped,
      zone: zone,
      estimateSeconds: focusEstimateSeconds,
    );
    final plain = cardOf(null);
    final zoned = cardOf(Zone.z1);

    expect(zoned, isNot(plain), reason: 'the zone participates in equality');
    expect(cardOf(Zone.z1), zoned);
    expect(cardOf(Zone.z1).hashCode, zoned.hashCode);

    expect(zoned.toString(), 'Card(k, focus, shipped, z1, 900s)');
    expect(plain.toString(), 'Card(k, focus, shipped, -, 900s)');
  });

  group('the active-zone ring (FR-11, FR-31)', () {
    const calendar = Calendar();

    test('the nominal ring position is weekOrdinal mod 5', () {
      // Weeks since the epoch Monday 2000-01-03: 1390 for the week
      // anchored 2026-08-24 — mod 5 = 0, zone z1, advancing one zone a
      // week.
      final z1Week = calendar.weekOf(
        calendar.dayOf(utcMicros(2026, 8, 24, 12), 0),
      );
      expect(z1Week.weekOrdinal, 1390);
      expect(activeZoneOf(z1Week, allCurationClusters), Zone.z1);
      expect(
        activeZoneOf(
          calendar.weekOf(calendar.dayOf(utcMicros(2026, 8, 31, 12), 0)),
          allCurationClusters,
        ),
        Zone.z2,
      );
      expect(
        activeZoneOf(
          calendar.weekOf(calendar.dayOf(utcMicros(2026, 9, 7, 12), 0)),
          allCurationClusters,
        ),
        Zone.z3,
      );
      expect(
        activeZoneOf(
          calendar.weekOf(calendar.dayOf(utcMicros(2026, 9, 14, 12), 0)),
          allCurationClusters,
        ),
        Zone.z4,
      );
      expect(
        activeZoneOf(
          calendar.weekOf(calendar.dayOf(utcMicros(2026, 9, 21, 12), 0)),
          allCurationClusters,
        ),
        Zone.z5,
      );
    });

    test('a disabled zone\'s week passes to the next active zone; the ring '
        'wraps; no active zone yields none', () {
      final z1Week = calendar.weekOf(
        calendar.dayOf(utcMicros(2026, 8, 24, 12), 0),
      );
      expect(
        activeZoneOf(z1Week, _clustersWithout([CurationCluster.z1])),
        Zone.z2,
        reason: 'the nominal z1 is disabled — z2 takes its week',
      );
      final z2Week = calendar.weekOf(
        calendar.dayOf(utcMicros(2026, 8, 31, 12), 0),
      );
      expect(
        activeZoneOf(
          z2Week,
          _clustersWithout([
            CurationCluster.z2,
            CurationCluster.z3,
            CurationCluster.z4,
            CurationCluster.z5,
          ]),
        ),
        Zone.z1,
        reason: 'the ring wraps cyclically to the active z1',
      );
      expect(
        activeZoneOf(z2Week, {
          CurationCluster.anclas,
          CurationCluster.sosten,
          CurationCluster.fondo,
        }),
        isNull,
        reason: 'no zone cluster active — no active zone',
      );
    });

    test('the composition follows the ring across the week boundary', () {
      // Friday of the z1 week composes a z1 chunk; the following Monday
      // composes a z2 chunk — the rotation turns on the boundary.
      final friday = nextDeal(
        catalogue: _catalogue,
        log: const [],
        instantUtcMicros: utcMicros(2026, 8, 28, 12),
        offsetSeconds: 0,
      );
      expect(friday!.zone, Zone.z1);
      final monday = nextDeal(
        catalogue: _catalogue,
        log: const [],
        instantUtcMicros: utcMicros(2026, 8, 31, 12),
        offsetSeconds: 0,
      );
      expect(monday!.zone, Zone.z2);
      expect(monday.id, 'zona-z2-a');
    });

    test('a whole week with no session passes without catch-up: the new '
        'week\'s zone deals first (AD-19 × FR-11)', () {
      // The z1 week passed untouched — not a row in the log. The z2
      // week's first composition deals z2, never the missed week's
      // leftover entries.
      final composition = composeDay(
        catalogue: _catalogue,
        log: const [],
        instantUtcMicros: utcMicros(2026, 8, 31, 12),
        offsetSeconds: 0,
      );
      expect(composition.focus!.zone, Zone.z2);
      expect(composition.focus!.id, 'zona-z2-a');

      // The whole z2 week runs its own arithmetic, and the untouched z1
      // entries never jump the queue: they wait for tier 3 while z2 and
      // fondo fill the week.
      var log = <LogEntry>[];
      final dealt = <String>[];
      for (var day = 7; day < 14; day++) {
        final deal = nextDeal(
          catalogue: _catalogue,
          log: log,
          instantUtcMicros: _day(day),
          offsetSeconds: 0,
        )!;
        dealt.add(deal.id);
        log
          ..add(_dealt(_day(day), deal.id))
          ..add(_done(_day(day) + 1, deal.id));
      }
      expect(dealt, [
        'zona-z2-a',
        'zona-z2-b',
        'zona-z2-c',
        'fondo-a',
        'fondo-b',
        'fondo-c',
        'fondo-d',
      ]);

      // The wait spans four full weeks: z3, z4 and z5 take their turns
      // and fondo spends its last entries — 27 distinct deals, never a
      // z1 entry — until only the missed week's entries remain.
      for (var day = 14; day < 34; day++) {
        final deal = nextDeal(
          catalogue: _catalogue,
          log: log,
          instantUtcMicros: _day(day),
          offsetSeconds: 0,
        )!;
        dealt.add(deal.id);
        log
          ..add(_dealt(_day(day), deal.id))
          ..add(_done(_day(day) + 1, deal.id));
      }
      expect(dealt, hasLength(27));
      expect(dealt.toSet(), hasLength(27));
      expect(
        dealt.where((id) => id.startsWith('zona-z1')),
        isEmpty,
        reason: 'the missed week\'s entries wait for the tiers that follow',
      );

      // Day 35 — the ring's return to z1 — deals the oldest missed
      // entry as tier 1 of the returned week, never a tier-3
      // jump-ahead. (Day 34, the spent pool's own tier-3 day, is left
      // uncomposed: this pin is the ring's, not the repetition's.)
      final returned = nextDeal(
        catalogue: _catalogue,
        log: log,
        instantUtcMicros: _day(35),
        offsetSeconds: 0,
      )!;
      expect(returned.zone, Zone.z1);
      expect(returned.id, 'zona-z1-a');
      expect(
        {...dealt, returned.id},
        hasLength(28),
        reason: '28 distinct deals across the whole run',
      );
    });

    test('the ring reaches z5: a z5 week composes and deals z5 entries', () {
      // The week anchored Monday 2026-09-21 is ordinal 1394 — mod 5 = 4.
      final tuesdayOfZ5Week = utcMicros(2026, 9, 22, 12);
      final composition = composeDay(
        catalogue: _catalogue,
        log: const [],
        instantUtcMicros: tuesdayOfZ5Week,
        offsetSeconds: 0,
      );
      expect(composition.focus!.zone, Zone.z5);
      expect(composition.focus!.id, 'zona-z5-a');
      expect(
        nextDeal(
          catalogue: _catalogue,
          log: const [],
          instantUtcMicros: tuesdayOfZ5Week,
          offsetSeconds: 0,
        )!.id,
        'zona-z5-a',
      );
    });

    test('weeks before the epoch Monday still yield a non-negative ring '
        'position', () {
      // Ordinals go negative before the fixed epoch Monday 2000-01-03 —
      // the ring's modulo normalizes, never crashes.
      final beforeEpoch = calendar.weekOf(
        calendar.dayOf(utcMicros(1999, 12, 27, 12), 0),
      );
      expect(beforeEpoch.weekOrdinal, -1);
      expect(activeZoneOf(beforeEpoch, allCurationClusters), Zone.z5);
      final earlierStill = calendar.weekOf(
        calendar.dayOf(utcMicros(1999, 12, 20, 12), 0),
      );
      expect(activeZoneOf(earlierStill, allCurationClusters), Zone.z4);
    });

    test('an open session crossing the week boundary keeps its start '
        'week\'s zone until it closes (AD-19 × FR-11)', () {
      // Opened Sunday 22:00 — the z1 week — and still open Monday
      // morning of the z2 week.
      final log = [_sessionStarted(utcMicros(2026, 8, 30, 22))];
      final mondayMorning = utcMicros(2026, 8, 31, 10);
      final inside = composeDay(
        catalogue: _catalogue,
        log: log,
        instantUtcMicros: mondayMorning,
        offsetSeconds: 0,
      );
      expect(
        inside.focus!.zone,
        Zone.z1,
        reason:
            'the session anchors to its start day, so to that day\'s '
            'week — the zone never flips mid-session',
      );
      expect(
        nextDeal(
          catalogue: _catalogue,
          log: log,
          instantUtcMicros: mondayMorning,
          offsetSeconds: 0,
        )!.zone,
        Zone.z1,
      );

      // Once the session closes, the crossed-into week's zone takes over.
      final closed = [...log, _sessionEnded(utcMicros(2026, 8, 31, 10, 30))];
      final after = composeDay(
        catalogue: _catalogue,
        log: closed,
        instantUtcMicros: utcMicros(2026, 8, 31, 10, 31),
        offsetSeconds: 0,
      );
      expect(after.focus!.zone, Zone.z2);
    });

    test('a mid-week zone disable rides activeClustersAt into the weave '
        '(AD-16 — the seam Epic 5 maps rows through)', () {
      final wednesdayDisable = <CurationObservation>[
        (
          cluster: CurationCluster.z2,
          enabled: false,
          instantUtcMicros: utcMicros(2026, 8, 26, 10),
          offsetSeconds: 0,
        ),
      ];
      // Sunday of the observation's own week: the derived set still holds
      // z2 — this week keeps its zone — and the composition stands on the
      // week's own zone z1.
      final sunday = activeClustersAt(
        wednesdayDisable,
        utcMicros(2026, 8, 30, 12),
      );
      expect(sunday.contains(CurationCluster.z2), isTrue);
      expect(
        nextDeal(
          catalogue: _catalogue,
          log: const [],
          instantUtcMicros: utcMicros(2026, 8, 30, 12),
          offsetSeconds: 0,
          activeClusters: sunday,
        )!.zone,
        Zone.z1,
      );
      // The following Monday the change is effective: the derived set
      // drops z2, and the composition follows it — the nominal z2's week
      // passes to z3.
      final monday = activeClustersAt(
        wednesdayDisable,
        utcMicros(2026, 8, 31, 12),
      );
      expect(monday.contains(CurationCluster.z2), isFalse);
      final composition = composeDay(
        catalogue: _catalogue,
        log: const [],
        instantUtcMicros: utcMicros(2026, 8, 31, 12),
        offsetSeconds: 0,
        activeClusters: monday,
      );
      expect(composition.focus!.zone, Zone.z3);
      expect(composition.focus!.id, 'zona-z3-a');
    });

    test('a mid-day fondo disable rides activeClustersAt into the weave the '
        'same day (AD-16 — the daily-cluster half of the seam)', () {
      // Monday morning answers all five z1 entries; by Thursday the
      // zone's tier is empty and fondo fills — unless fondo left the
      // active set that morning.
      final log = <LogEntry>[
        for (final (index, id) in [
          'zona-z1-a',
          'zona-z1-b',
          'zona-z1-c',
          'zona-z1-d',
          'zona-z1-e',
        ].indexed) ...[
          _dealt(_day(0, 8 + index), id),
          _done(_day(0, 9 + index), id),
        ],
      ];
      final thursdayNoon = _day(3);
      expect(
        composeDay(
          catalogue: _catalogue,
          log: log,
          instantUtcMicros: thursdayNoon,
          offsetSeconds: 0,
        ).focus!.id,
        'fondo-a',
        reason: 'the all-active default fills the exhausted zone with fondo',
      );

      // The disable observed Thursday 08:00 is effective its own
      // domestic day: the derived set drops fondo, and that same day's
      // composition follows it.
      final thursdayMorning = <CurationObservation>[
        (
          cluster: CurationCluster.fondo,
          enabled: false,
          instantUtcMicros: utcMicros(2026, 8, 27, 8),
          offsetSeconds: 0,
        ),
      ];
      final derived = activeClustersAt(thursdayMorning, thursdayNoon);
      expect(derived.contains(CurationCluster.fondo), isFalse);
      final composition = composeDay(
        catalogue: _catalogue,
        log: log,
        instantUtcMicros: thursdayNoon,
        offsetSeconds: 0,
        activeClusters: derived,
      );
      expect(
        composition.focus,
        isNotNull,
        reason: 'never an empty day while an eligible entry exists',
      );
      expect(
        composition.focus!.id,
        'zona-z2-a',
        reason:
            'tier 3: the least-recently-dealt eligible entry regardless '
            'of zone — fondo is out of the offer',
      );
    });

    test('a disabled zone\'s week composes from the zone that took it', () {
      final composition = composeDay(
        catalogue: _catalogue,
        log: const [],
        instantUtcMicros: now,
        offsetSeconds: 0,
        activeClusters: _clustersWithout([CurationCluster.z1]),
      );
      expect(composition.focus!.id, 'zona-z2-a');
      expect(composition.focus!.zone, Zone.z2);
      // The 3- and 5-draws stay size-based and unaffected by the ring.
      expect(composition.maintenance, hasLength(3));
      expect(composition.instantHabits, hasLength(5));
    });

    test('every cluster disabled composes an empty day and deals nothing', () {
      final composition = composeDay(
        catalogue: _catalogue,
        log: const [],
        instantUtcMicros: now,
        offsetSeconds: 0,
        activeClusters: const {},
      );
      expect(composition.focus, isNull);
      expect(composition.maintenance, isEmpty);
      expect(composition.instantHabits, isEmpty);
      expect(
        nextDeal(
          catalogue: _catalogue,
          log: const [],
          instantUtcMicros: now,
          offsetSeconds: 0,
          activeClusters: const {},
        ),
        isNull,
        reason: 'no deal exists — a session start appends no card_dealt',
      );
    });

    test('no active zone empties the chunk tiers; the 3- and 5-draws stand '
        '(FR-11)', () {
      final composition = composeDay(
        catalogue: _catalogue,
        log: const [],
        instantUtcMicros: now,
        offsetSeconds: 0,
        activeClusters: {
          CurationCluster.anclas,
          CurationCluster.sosten,
          CurationCluster.fondo,
        },
      );
      expect(composition.focus, isNull, reason: 'the chunk tiers are empty');
      expect(composition.maintenance, hasLength(3));
      expect(composition.instantHabits, hasLength(5));
    });
  });

  group('the chunk tiers (AD-20)', () {
    test('the zone exhausts in-week and fondo fills before any repetition '
        '(FR-31)', () {
      var log = <LogEntry>[];
      Card chunkOn(int day) {
        final deal = nextDeal(
          catalogue: _catalogue,
          log: log,
          instantUtcMicros: _day(day),
          offsetSeconds: 0,
        )!;
        log
          ..add(_dealt(_day(day), deal.id))
          ..add(_done(_day(day) + 1, deal.id));
        return deal;
      }

      // Monday–Friday answer the five z1 entries.
      for (var day = 0; day < 5; day++) {
        expect(chunkOn(day).zone, Zone.z1);
      }
      // Saturday and Sunday: the zone's never-answered set is empty and
      // fondo fills — never a z1 repeat while fondo holds new entries.
      final saturday = chunkOn(5);
      expect(saturday.zone, isNull);
      expect(saturday.id, 'fondo-a');
      expect(chunkOn(6).id, 'fondo-b');
      // The next Monday the ring moves to z2 — a new zone's entries.
      final nextMonday = chunkOn(7);
      expect(nextMonday.zone, Zone.z2);
      expect(nextMonday.id, 'zona-z2-a');
    });

    test('a skipped fondo entry re-resolves within its tier and is not '
        'consumed (AD-20)', () {
      // One zone entry and a three-entry fondo: the zone exhausts on
      // Monday and fondo carries the week — tier 2, where a skip must
      // behave exactly as it does on tier 1.
      final catalogue = Catalogue(
        version: 1,
        entries: [
          _entry('zona-z1-a', Size.focus, Cadence.weekly, zone: Zone.z1),
          _entry('fondo-1', Size.focus, Cadence.seasonal),
          _entry('fondo-2', Size.focus, Cadence.seasonal),
          _entry('fondo-3', Size.focus, Cadence.seasonal),
          _entry('man-a', Size.maintenance, Cadence.daily),
          _entry('hab-a', Size.instant, Cadence.daily),
        ],
      );
      var log = <LogEntry>[];
      Card chunkOn(int day, {bool skip = false}) {
        final deal = nextDeal(
          catalogue: catalogue,
          log: log,
          instantUtcMicros: _day(day),
          offsetSeconds: 0,
        )!;
        log
          ..add(_dealt(_day(day), deal.id))
          ..add(
            skip
                ? _skipped(_day(day) + 1, deal.id)
                : _done(_day(day) + 1, deal.id),
          );
        return deal;
      }

      expect(chunkOn(0).id, 'zona-z1-a', reason: 'Monday: the zone');
      // Tuesday: the zone is exhausted, fondo fills — and is skipped.
      final skipped = chunkOn(1, skip: true);
      expect(skipped.zone, isNull);
      expect(skipped.id, 'fondo-1');
      // Wednesday: a different fondo candidate resolves — the skip
      // consumed nothing and re-resolved identity.
      expect(chunkOn(2).id, 'fondo-2');
      expect(chunkOn(3).id, 'fondo-3');
      // Friday: tier 2's only never-answered entry is the skipped one —
      // it deals again before any tier-3 repetition of the zone entry.
      expect(chunkOn(4).id, 'fondo-1');
    });

    test('below the floor the least-recently-dealt eligible entry deals — '
        'repetition, never an empty day (AD-20)', () {
      // Curation leaves only z1 + fondo: 17 eligible < the 28 floor. The
      // second week's nominal zone z2 is disabled and the ring wraps to
      // z1, so fondo carries week two alone until it too is answered.
      final clusters = {
        CurationCluster.z1,
        CurationCluster.fondo,
        CurationCluster.anclas,
        CurationCluster.sosten,
      };
      var log = <LogEntry>[];
      final dealt = <String>[];
      for (var day = 0; day < 17; day++) {
        final deal = nextDeal(
          catalogue: _catalogue,
          log: log,
          instantUtcMicros: _day(day),
          offsetSeconds: 0,
          activeClusters: clusters,
        );
        expect(deal, isNotNull, reason: 'never an empty day (day $day)');
        dealt.add(deal!.id);
        log
          ..add(_dealt(_day(day), deal.id))
          ..add(_done(_day(day) + 1, deal.id));
      }
      expect(dealt.toSet(), hasLength(17), reason: 'all eligible answered');
      // Day 18: tiers 1 and 2 hold nothing — tier 3 repeats the
      // least-recently-dealt eligible entry, the deal of day 1.
      final repetition = nextDeal(
        catalogue: _catalogue,
        log: log,
        instantUtcMicros: _day(17),
        offsetSeconds: 0,
        activeClusters: clusters,
      );
      expect(repetition, isNotNull);
      expect(repetition!.size, Size.focus);
      expect(repetition.id, 'zona-z1-a');
      expect(dealt.contains(repetition.id), isTrue);
    });

    test('below the floor with two zones active the ring still advances '
        'across weeks: 20 distinct deals, then the day-21 repetition — '
        'never an empty day (AD-20, FR-31)', () {
      // z3–z5 disabled: 5 z1 + 3 z2 + 12 fondo = 20 eligible, below the
      // 28 floor. The ring still rotates — z1's week, z2's week, then
      // the z3 week passes to the next active zone, z1 — and tier 3
      // repeats only once every eligible entry is answered.
      final clusters = _clustersWithout([
        CurationCluster.z3,
        CurationCluster.z4,
        CurationCluster.z5,
      ]);
      var log = <LogEntry>[];
      final dealt = <String>[];
      final dealtZones = <Zone?>[];
      for (var day = 0; day < 21; day++) {
        final deal = nextDeal(
          catalogue: _catalogue,
          log: log,
          instantUtcMicros: _day(day),
          offsetSeconds: 0,
          activeClusters: clusters,
        );
        expect(deal, isNotNull, reason: 'never an empty day (day $day)');
        dealt.add(deal!.id);
        dealtZones.add(deal.zone);
        log
          ..add(_dealt(_day(day), deal.id))
          ..add(_done(_day(day) + 1, deal.id));
      }
      expect(dealt.take(20).toSet(), hasLength(20));
      // The ring advanced across weeks while the floor was broken:
      // z1's five, the weekend's fondo, z2's three, fondo again — and
      // week three's nominal z3 passes to z1, whose tier is spent, so
      // fondo carries it to the last entry.
      expect(dealtZones.sublist(0, 5), everyElement(Zone.z1));
      expect(dealtZones[7], Zone.z2);
      expect(dealtZones[9], Zone.z2);
      expect(dealtZones[10], isNull);
      expect(dealtZones[14], isNull, reason: 'z1 is spent — fondo fills');
      // Day 21: tiers 1 and 2 empty — tier 3 repeats the deal of day 1.
      expect(dealt[20], dealt[0], reason: 'the oldest deal, dealt again');
      expect(dealt[0], 'zona-z1-a');
    });

    test('28 answered chunks over the default state never repeat a '
        'Micro-task — the shipped arithmetic (FR-31, AC)', () {
      var log = <LogEntry>[];
      final dealtIds = <String>[];
      for (var day = 0; day < 28; day++) {
        final deal = nextDeal(
          catalogue: _catalogue,
          log: log,
          instantUtcMicros: _day(day),
          offsetSeconds: 0,
        );
        expect(deal, isNotNull, reason: 'day $day holds a chunk');
        expect(deal!.size, Size.focus);
        dealtIds.add(deal.id);
        log
          ..add(_dealt(_day(day), deal.id))
          ..add(_done(_day(day) + 1, deal.id));
      }
      expect(dealtIds.toSet(), hasLength(28));
      // The tier arithmetic day by day: five z1 days, fondo fills the
      // weekend, three z2 days, fondo fills, four z3 days, fondo, five
      // z4 days, fondo closes — 17 zone entries + 11 fondo = 28.
      expect(dealtIds, [
        'zona-z1-a',
        'zona-z1-b',
        'zona-z1-c',
        'zona-z1-d',
        'zona-z1-e',
        'fondo-a',
        'fondo-b',
        'zona-z2-a',
        'zona-z2-b',
        'zona-z2-c',
        'fondo-c',
        'fondo-d',
        'fondo-e',
        'fondo-f',
        'zona-z3-a',
        'zona-z3-b',
        'zona-z3-c',
        'zona-z3-d',
        'fondo-g',
        'fondo-h',
        'fondo-i',
        'zona-z4-a',
        'zona-z4-b',
        'zona-z4-c',
        'zona-z4-d',
        'zona-z4-e',
        'fondo-j',
        'fondo-k',
      ]);
    });
  });
}

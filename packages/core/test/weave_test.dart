import 'package:core/catalogue/catalogue.dart';
import 'package:core/commands/session_commands.dart';
import 'package:core/curation/curation.dart';
import 'package:core/day/calendar.dart';
import 'package:core/energy/energy.dart';
import 'package:core/log/log_entry.dart';
import 'package:core/pool/pool_fact.dart';
import 'package:core/settings/settings.dart';
import 'package:core/weave/session.dart';
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

SessionStartEntry _sessionStarted(int micros, {int? pocketMinutes}) =>
    SessionStartEntry(
      id: 'started-$micros',
      instantUtcMicros: micros,
      offsetSeconds: 0,
      kind: LogKind.sessionStarted,
      pocketMinutes: pocketMinutes,
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

/// A manual capture's pool fact (Story 3.3) — origin `manual`, its own
/// single line as the Origin Context.
PoolFact _captureFact(
  String id,
  Size size,
  int micros, {
  String line = 'Llamar al dentista',
}) => PoolFact(
  id: id,
  origin: Origin.manual,
  size: size,
  instantUtcMicros: micros,
  offsetSeconds: 0,
  originContext: line,
);

ItemActEntry _captureDealt(int micros, String itemId) => ItemActEntry(
  id: 'capture-dealt-$micros-$itemId',
  instantUtcMicros: micros,
  offsetSeconds: 0,
  kind: LogKind.cardDealt,
  itemId: itemId,
  itemOrigin: Origin.manual,
);

ItemActEntry _captureDone(int micros, String itemId) => ItemActEntry(
  id: 'capture-done-$micros-$itemId',
  instantUtcMicros: micros,
  offsetSeconds: 0,
  kind: LogKind.cardDone,
  itemId: itemId,
  itemOrigin: Origin.manual,
);

ItemActEntry _captureSkipped(int micros, String itemId) => ItemActEntry(
  id: 'capture-skipped-$micros-$itemId',
  instantUtcMicros: micros,
  offsetSeconds: 0,
  kind: LogKind.cardSkipped,
  itemId: itemId,
  itemOrigin: Origin.manual,
);

/// A rescue step's pool fact (Story 4.6): origin inherited from its
/// parent at the shell's landing, size the fixed instant band, the
/// Slicer's duration tag verbatim.
PoolFact _stepFact(
  String id,
  int micros,
  String parent, {
  int estimateSeconds = 45,
  String line = 'Paso de rescate',
}) => PoolFact(
  id: id,
  origin: Origin.manual,
  size: Size.instant,
  instantUtcMicros: micros,
  offsetSeconds: 0,
  originContext: line,
  rescueOf: parent,
  estimateSeconds: estimateSeconds,
);

/// A `slice_*` row (Story 4.6) naming a pool item in the row's own
/// carried origin.
SliceEntry _sliceRow(
  LogKind kind,
  int micros,
  String itemId, {
  Origin origin = Origin.manual,
}) => SliceEntry(
  id: 'slice-${kind.name}-$micros-$itemId',
  instantUtcMicros: micros,
  offsetSeconds: 0,
  kind: kind,
  itemId: itemId,
  itemOrigin: origin,
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

    // Closing the session holds the sitting line (Story 2.3): with no
    // open session the resolver proposes nothing at all — the read
    // model presents the warm close, never a dead card no command can
    // answer.
    final ended = [...log, _sessionEnded(utcMicros(2026, 8, 28, 10, 30))];
    expect(
      nextDeal(
        catalogue: _catalogue,
        log: ended,
        instantUtcMicros: now,
        offsetSeconds: 0,
      ),
      isNull,
      reason: 'no open session — no deal (the pause\'s other half)',
    );

    // The freed resolver proves out through a fresh `sessionStart`
    // bundle: its synthesized start present is the deal's only door
    // back in, and the slot never closed — a different z1 candidate
    // resolves than the one outstanding at the close.
    final reopened = sessionStart(
      catalogue: _catalogue,
      log: ended,
      instantUtcMicros: now,
      offsetSeconds: 0,
    );
    expect(reopened.map((content) => content.kind).toList(), [
      LogKind.sessionStarted,
      LogKind.cardDealt,
    ]);
    expect(reopened.last.itemId, 'zona-z1-b');

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

  test('no open session means no deal, whatever else the log holds — the '
      'sessionless pin (Story 2.3, AD-19)', () {
    // An empty log, a closed session, and a log holding imported
    // sessionless acts all resolve absent alike: the walk tolerates the
    // rows (their days and indices still charge), the resolver proposes
    // nothing over them.
    final closed = [
      _sessionStarted(utcMicros(2026, 8, 28, 10)),
      _sessionEnded(utcMicros(2026, 8, 28, 10, 30)),
    ];
    final importedActs = [
      _dealt(utcMicros(2026, 8, 27, 10), 'man-a'),
      _done(utcMicros(2026, 8, 27, 10, 0, 1), 'man-a'),
    ];
    for (final log in [const <LogEntry>[], closed, importedActs]) {
      expect(
        nextDeal(
          catalogue: _catalogue,
          log: log,
          instantUtcMicros: now,
          offsetSeconds: 0,
        ),
        isNull,
        reason: 'no unmatched session_started — never a sessionless deal',
      );
    }

    // The sitting's start is the only door back in: over the imported
    // acts a fresh sessionStart bundles the sitting's first deal.
    final reopened = sessionStart(
      catalogue: _catalogue,
      log: importedActs,
      instantUtcMicros: now,
      offsetSeconds: 0,
    );
    expect(reopened.map((content) => content.kind).toList(), [
      LogKind.sessionStarted,
      LogKind.cardDealt,
    ]);
    expect(
      reopened.last.itemId,
      isNot('man-a'),
      reason: 'man-a answered all-time; the bundle deals onward',
    );
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
    // Deals exist only inside sittings (Story 2.3), so each run day is
    // its own sitting: start, deal, answer, close.
    var log = <LogEntry>[];
    String chunkOn(int day) {
      log.add(_sessionStarted(_day(day)));
      final deal = nextDeal(
        catalogue: _catalogue,
        log: log,
        instantUtcMicros: _day(day),
        offsetSeconds: 0,
      )!;
      log
        ..add(_dealt(_day(day) + 1, deal.id))
        ..add(
          day == 0
              ? _skipped(_day(day) + 2, deal.id)
              : _done(_day(day) + 2, deal.id),
        )
        ..add(_sessionEnded(_day(day) + 3));
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

    // The run continues on its own arithmetic — each day its own
    // sitting (Story 2.3): start, deal, answer, close.
    String dealOn(int runDay) {
      log.add(_sessionStarted(day(runDay)));
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
        ..add(_dealt(day(runDay) + 1, deal!.id))
        ..add(_done(day(runDay) + 2, deal.id))
        ..add(_sessionEnded(day(runDay) + 3));
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
    log.add(_sessionStarted(day(6)));
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

  group('the declared pocket bounds the sitting\'s deals (Story 2.2, '
      'FR-8, FR-12)', () {
    test('upkeep is charged to a declared pocket like everything else '
        'dealt in the sitting — and still never to the bag', () {
      final start = utcMicros(2026, 8, 28, 10);
      // A pocket of 5 holds exactly one maintenance draw (3 min) and
      // nothing more: the chunk (15) exceeds it, a second upkeep (3+3)
      // exceeds it, and one instant (30 s) fits after the upkeep.
      final log = [
        _sessionStarted(start, pocketMinutes: 5),
        _dealt(start + 1000, 'man-a'),
        _done(start + 2000, 'man-a'),
      ];
      final next = nextDeal(
        catalogue: _catalogue,
        log: log,
        instantUtcMicros: start + 3000,
        offsetSeconds: 0,
      );
      expect(next, isNotNull);
      expect(next!.size, Size.instant);

      // The bag is untouched by the pocket's arithmetic: the same log
      // composes against a healthy bag with the chunk resolved —
      // the pocket filtered the deal, never the composition.
      final composition = composeDay(
        catalogue: _catalogue,
        log: log,
        instantUtcMicros: start + 3000,
        offsetSeconds: 0,
      );
      expect(composition.focus, isNotNull);
    });

    test('a pocket that cannot hold any tier resolves no deal — the warm '
        'close, with no eager session_ended anywhere', () {
      final start = utcMicros(2026, 8, 28, 10);
      // Pocket 1 holds exactly two instants (30 s + 30 s = its whole
      // minute); with both answered, no tier's estimate fits the
      // remainder of zero — not the chunk (15 min), not an upkeep
      // (3 min), not even one more instant (30 s).
      final log = [
        _sessionStarted(start, pocketMinutes: 1),
        _dealt(start + 1000, 'hab-a'),
        _done(start + 2000, 'hab-a'),
        _dealt(start + 3000, 'hab-b'),
        _done(start + 4000, 'hab-b'),
      ];
      final next = nextDeal(
        catalogue: _catalogue,
        log: log,
        instantUtcMicros: start + 5000,
        offsetSeconds: 0,
      );
      expect(next, isNull);
      // Linger, not eagerly close: the session fact still reads open
      // with its pocket — the row lands at backgrounding, reveal or
      // supersede, never here.
      final facts = walkLog(log, catalogue: _catalogue);
      expect(facts.openSessionStart, isNotNull);
      expect(facts.openSessionPocketMinutes, 1);
    });

    test('the chunk falls through to a smaller tier when the pocket '
        'cannot hold it (FR-8, FR-12)', () {
      final start = utcMicros(2026, 8, 28, 10);
      final log = [_sessionStarted(start, pocketMinutes: 4)];
      final next = nextDeal(
        catalogue: _catalogue,
        log: log,
        instantUtcMicros: start + 1000,
        offsetSeconds: 0,
      );
      expect(next, isNotNull);
      expect(next!.size, Size.maintenance);

      // A pocket of 3 holds the upkeep exactly — 180 ≤ 180 — then
      // offers instants.
      final afterUpkeep = [
        ...log,
        _dealt(start + 2000, 'man-a'),
        _done(start + 3000, 'man-a'),
      ];
      final then = nextDeal(
        catalogue: _catalogue,
        log: afterUpkeep,
        instantUtcMicros: start + 4000,
        offsetSeconds: 0,
      );
      expect(then, isNotNull);
      expect(then!.size, Size.instant);
    });

    test('a dealt-unanswered card still yields no second deal inside a '
        'pocketed session (AD-3)', () {
      final start = utcMicros(2026, 8, 28, 10);
      final log = [
        _sessionStarted(start, pocketMinutes: 15),
        _dealt(start + 1000, 'zona-z1-a'),
      ];
      expect(
        nextDeal(
          catalogue: _catalogue,
          log: log,
          instantUtcMicros: start + 2000,
          offsetSeconds: 0,
        ),
        isNull,
      );
    });

    test('a skip releases its estimate: the alternative deal still '
        'bounded by the pocket (FR-3, FR-8)', () {
      final start = utcMicros(2026, 8, 28, 10);
      // Pocket 6, a focus candidate skipped: nothing consumed, so the
      // upkeep tier (3) still deals — and after answering it, one more
      // upkeep fits (3+3 = 6), while the chunk never does.
      final log = [
        _sessionStarted(start, pocketMinutes: 6),
        _dealt(start + 1000, 'zona-z1-a'),
        _skipped(start + 2000, 'zona-z1-a'),
      ];
      final first = nextDeal(
        catalogue: _catalogue,
        log: log,
        instantUtcMicros: start + 3000,
        offsetSeconds: 0,
      );
      expect(first, isNotNull);
      expect(first!.size, Size.maintenance);

      final answered = [
        ...log,
        _dealt(start + 4000, first.id),
        _done(start + 5000, first.id),
      ];
      final second = nextDeal(
        catalogue: _catalogue,
        log: answered,
        instantUtcMicros: start + 6000,
        offsetSeconds: 0,
      );
      expect(second, isNotNull);
      expect(second!.size, Size.maintenance);

      final answeredTwice = [
        ...answered,
        _dealt(start + 7000, second.id),
        _done(start + 8000, second.id),
      ];
      // The pocket is exactly spent — 3 + 3 against 6 — so nothing
      // more fits, not even a 30-second instant.
      final third = nextDeal(
        catalogue: _catalogue,
        log: answeredTwice,
        instantUtcMicros: start + 9000,
        offsetSeconds: 0,
      );
      expect(third, isNull);
    });

    test('the wall-clock span ends dealability: a pocket elapsed at the '
        'deal instant resolves nothing (AD-19 — derived, never '
        'scheduled)', () {
      final start = utcMicros(2026, 8, 28, 10);
      const microsPerMinute = 60 * 1000 * 1000;
      // Pocket 4 with one upkeep answered (3 of 4 minutes): the
      // remaining 60 s hold an instant, and only until the span closes.
      final log = [
        _sessionStarted(start, pocketMinutes: 4),
        _dealt(start + 1000, 'man-a'),
        _done(start + 2000, 'man-a'),
      ];
      final beforeClose = nextDeal(
        catalogue: _catalogue,
        log: log,
        instantUtcMicros: start + 4 * microsPerMinute - 1,
        offsetSeconds: 0,
      );
      expect(beforeClose, isNotNull);
      expect(beforeClose!.size, Size.instant);

      // At the boundary exactly — and past it — nothing deals.
      for (final at in [
        start + 4 * microsPerMinute,
        start + 30 * 60 * 1000 * 1000,
      ]) {
        expect(
          nextDeal(
            catalogue: _catalogue,
            log: log,
            instantUtcMicros: at,
            offsetSeconds: 0,
          ),
          isNull,
          reason:
              'the pocket elapsed at $at — the read presents the '
              'warm close, and no session_ended was appended',
        );
      }
      // The session still lingers derived-open.
      expect(walkLog(log, catalogue: _catalogue).openSessionStart, isNotNull);
    });

    test('an out-of-range pocket derives as absent: the sitting is '
        'unbounded and the deals stand (AD-23)', () {
      final start = utcMicros(2026, 8, 28, 10);
      final log = [
        _sessionStarted(start, pocketMinutes: 90),
        _dealt(start + 1000, 'man-a'),
        _done(start + 2000, 'man-a'),
        _dealt(start + 3000, 'man-b'),
        _done(start + 4000, 'man-b'),
      ];
      final facts = walkLog(log, catalogue: _catalogue);
      expect(facts.openSessionPocketMinutes, isNull);
      expect(
        nextDeal(
          catalogue: _catalogue,
          log: log,
          instantUtcMicros: start + 100 * 60 * 1000 * 1000,
          offsetSeconds: 0,
        ),
        isNotNull,
        reason:
            'no pocket, no span: the sitting deals as ever at any '
            'later instant',
      );
    });

    test('unbounded sessions deal exactly as shipped: no pocket filter, '
        'no span, ever (Story 2.2 — the auto-open unchanged)', () {
      final start = utcMicros(2026, 8, 28, 10);
      final log = [
        _sessionStarted(start),
        _dealt(start + 1000, 'zona-z1-a'),
        _done(start + 2000, 'zona-z1-a'),
        _dealt(start + 3000, 'man-a'),
        _done(start + 4000, 'man-a'),
      ];
      // Far past any pocket-sized span, the deals continue.
      final next = nextDeal(
        catalogue: _catalogue,
        log: log,
        instantUtcMicros: start + 8 * 60 * 60 * 1000 * 1000,
        offsetSeconds: 0,
      );
      expect(next, isNotNull);
      expect(next!.size, Size.maintenance);
      expect(
        walkLog(log, catalogue: _catalogue).openSessionPocketMinutes,
        isNull,
      );
    });
  });

  group('the advance/upkeep split applied to the pause (FR-7, FR-9, '
      'FR-12, Story 2.3)', () {
    test('bag 15, pocket 10: the chunk (900 s) waits — upkeep and habits '
        'deal within the pocket, and a fuller same-day pocket deals the '
        'chunk (the slot still open)', () {
      final start = utcMicros(2026, 8, 28, 10);
      // Pocket 10 holds 600 s: the chunk's 900 never fits, so it waits —
      // the sitting deals upkeep and habits instead.
      final log = [_sessionStarted(start, pocketMinutes: 10)];
      final first = nextDeal(
        catalogue: _catalogue,
        log: log,
        instantUtcMicros: start + 1000,
        offsetSeconds: 0,
      );
      expect(first!.size, Size.maintenance);
      // The pocket filtered the deal, never the composition: the chunk
      // stands composed against the bag, waiting for a fuller pocket.
      final composition = composeDay(
        catalogue: _catalogue,
        log: log,
        instantUtcMicros: start + 1000,
        offsetSeconds: 0,
      );
      expect(composition.focus, isNotNull);

      // A fuller same-day pocket deals the chunk: the declare
      // supersedes, consumption restarts at zero, and the slot — never
      // closed, for nothing was answered — resolves it.
      final declared = sessionDeclare(
        catalogue: _catalogue,
        log: log,
        pocketMinutes: 15,
        instantUtcMicros: start + 2000,
        offsetSeconds: 0,
      );
      expect(declared.map((content) => content.kind).toList(), [
        LogKind.sessionEnded,
        LogKind.sessionStarted,
        LogKind.cardDealt,
      ]);
      final dealtSize = _catalogue.entries
          .firstWhere((entry) => entry.id == declared.last.itemId)
          .size;
      expect(dealtSize, Size.focus);
    });

    test('bag 5: no chunk exists at all, silently — upkeep and habits '
        'deal inside the sitting, no debt, no mention', () {
      final start = utcMicros(2026, 8, 28, 10);
      final log = [_sessionStarted(start)];
      // The day composes without the "1" at the range's own floor.
      final composition = composeDay(
        catalogue: _catalogue,
        log: log,
        instantUtcMicros: start + 1000,
        offsetSeconds: 0,
        bagMinutes: 5,
      );
      expect(composition.focus, isNull);
      expect(composition.maintenance, hasLength(3));
      expect(composition.instantHabits, hasLength(5));
      // Inside the sitting the same bag deals upkeep, never a chunk.
      final deal = nextDeal(
        catalogue: _catalogue,
        log: log,
        instantUtcMicros: start + 1000,
        offsetSeconds: 0,
        bagMinutes: 5,
      );
      expect(deal!.size, isNot(Size.focus));
    });

    test('bag 30: exactly one chunk — the surplus buys nothing, and '
        'upkeep and habits are charged nowhere', () {
      final start = utcMicros(2026, 8, 28, 10);
      final first = [_sessionStarted(start)];
      // The chunk deals against the day's whole bag...
      final chunk = nextDeal(
        catalogue: _catalogue,
        log: first,
        instantUtcMicros: start + 1000,
        offsetSeconds: 0,
        bagMinutes: 30,
      );
      expect(chunk!.size, Size.focus);
      // ...and its answer closes the slot: a second same-day sitting
      // composes upkeep and habits only — the 15 unspent minutes buy
      // nothing, for the bag bounds the day's advance, not its sittings.
      final answered = [
        ...first,
        _dealt(start + 2000, chunk.id),
        _done(start + 3000, chunk.id),
      ];
      final second = [
        ...answered,
        _sessionEnded(start + 4000),
        _sessionStarted(start + 5000),
      ];
      final next = nextDeal(
        catalogue: _catalogue,
        log: second,
        instantUtcMicros: start + 6000,
        offsetSeconds: 0,
        bagMinutes: 30,
      );
      expect(next!.size, isNot(Size.focus));
      final composition = composeDay(
        catalogue: _catalogue,
        log: second,
        instantUtcMicros: start + 6000,
        offsetSeconds: 0,
        bagMinutes: 30,
      );
      expect(composition.focus, isNull);
      expect(composition.maintenance, hasLength(3));
      expect(composition.instantHabits, hasLength(5));
    });

    test('a session crossing 04:00, paused after the boundary — the '
        'crossed-into day\'s chunk resolves once the pause lands (AD-19, '
        'Story 2.3)', () {
      final log = [
        _sessionStarted(utcMicros(2026, 8, 28, 3, 40), pocketMinutes: 30),
        _dealt(utcMicros(2026, 8, 28, 3, 41), 'zona-z1-a'),
        _done(utcMicros(2026, 8, 28, 3, 50), 'zona-z1-a'),
        // The pause tap, after the 04:00 boundary: the ledger it closes
        // is charged whole to the session's own start day (session_test
        // pins the walk facts; this pin is the composition's).
        _sessionEnded(utcMicros(2026, 8, 28, 4, 10)),
      ];
      // The crossed-into day's slot stays untouched: the morning after
      // composes its own chunk through a fresh sitting.
      final morning = [...log, _sessionStarted(utcMicros(2026, 8, 28, 8))];
      final composition = composeDay(
        catalogue: _catalogue,
        log: morning,
        instantUtcMicros: utcMicros(2026, 8, 28, 8, 1),
        offsetSeconds: 0,
      );
      expect(composition.focus, isNotNull);
      expect(composition.focus!.id, 'zona-z1-b');
      final reopened = sessionStart(
        catalogue: _catalogue,
        log: log,
        instantUtcMicros: utcMicros(2026, 8, 28, 8),
        offsetSeconds: 0,
      );
      expect(reopened.map((content) => content.kind).toList(), [
        LogKind.sessionStarted,
        LogKind.cardDealt,
      ]);
      expect(reopened.last.itemId, 'zona-z1-b');
    });
  });

  test('low energy composes no chunk and narrows to instant-tier only; '
      'medium changes nothing (FR-4, Story 2.5)', () {
    final low = composeDay(
      catalogue: _catalogue,
      log: const [],
      instantUtcMicros: now,
      offsetSeconds: 0,
      energy: EnergyLevel.low,
    );
    expect(low.focus, isNull);
    // The 60 s admission: upkeep (3 min) drops with the chunk, the
    // instant habits (30 s) stand — a baja day is instant-tier only,
    // across composeDay and the deal alike.
    expect(low.maintenance, isEmpty);
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

  test('the 🔴 admission holds across every consumer — nextDeal, the '
      'probe and the composition agree: instant-tier only (Story 2.5, '
      'FR-4)', () {
    // Maintenance 180 s / focus 900 s / instant 30 s candidates: only
    // the instant tier passes the 60 s estimate ceiling.
    final log = [_sessionStarted(now)];
    final deal = nextDeal(
      catalogue: _catalogue,
      log: log,
      instantUtcMicros: now,
      offsetSeconds: 0,
      energy: EnergyLevel.low,
    );
    expect(deal!.size, Size.instant);

    expect(
      dealExistsIgnoringPocket(
        catalogue: _catalogue,
        log: log,
        instantUtcMicros: now,
        offsetSeconds: 0,
        energy: EnergyLevel.low,
      ),
      isTrue,
      reason:
          'the lifted pocket lifts the pocket alone — the low '
          'admission stands, and an instant-tier deal exists',
    );

    // With the day's instant draws exhausted behind a spent pocket, the
    // probe answers false too: nothing the sitting could hold remains.
    final spentLog = [
      ...log,
      for (final (index, id) in [
        'hab-a',
        'hab-b',
        'hab-c',
        'hab-d',
        'hab-e',
      ].indexed) ...[_dealt(now + index, id), _done(now + index + 500, id)],
    ];
    expect(
      dealExistsIgnoringPocket(
        catalogue: _catalogue,
        log: spentLog,
        instantUtcMicros: now,
        offsetSeconds: 0,
        energy: EnergyLevel.low,
      ),
      isFalse,
      reason:
          'upkeep and the chunk stay excluded at low even with the '
          'pocket lifted',
    );
  });

  test('a baja tapped with a card in progress never withdraws it — the '
      'standing-card pin (Story 2.5, FR-4, FR-10)', () {
    // A chunk stands dealt-but-unanswered when the baja lands: the
    // resolver proposes nothing (its own sitting line), and the facade
    // keeps returning the standing card — finishable, never withdrawn.
    final log = [_sessionStarted(now), _dealt(now + 1, 'zona-z1-a')];
    expect(
      nextDeal(
        catalogue: _catalogue,
        log: log,
        instantUtcMicros: now + 2,
        offsetSeconds: 0,
        energy: EnergyLevel.low,
      ),
      isNull,
      reason:
          'the standing card suppresses the deal whatever the '
          'energy — an unanswered card never produces a second one '
          '(AD-3)',
    );
    // The answer to the standing card still bundles under baja: the
    // next deal is instant-tier only, the narrow applying to the next
    // deal and never to the card in progress.
    final answeredLog = [...log, _done(now + 2, 'zona-z1-a')];
    final next = nextDeal(
      catalogue: _catalogue,
      log: answeredLog,
      instantUtcMicros: now + 3,
      offsetSeconds: 0,
      energy: EnergyLevel.low,
    );
    expect(next!.size, Size.instant);
  });

  test('a 🔴 day consumes no rotation: the zone entry still deals the next '
      'day (FR-31)', () {
    // Day 1 is 🔴: no chunk composes, only instant-tier deals answer.
    final redDay = composeDay(
      catalogue: _catalogue,
      log: const [],
      instantUtcMicros: _day(0),
      offsetSeconds: 0,
      energy: EnergyLevel.low,
    );
    expect(redDay.focus, isNull);
    expect(redDay.maintenance, isEmpty);
    final log = [
      _dealt(_day(0), redDay.instantHabits.first.id),
      _done(_day(0) + 1, redDay.instantHabits.first.id),
      // Day 2's sitting opens before its deal resolves (Story 2.3).
      _sessionStarted(_day(1)),
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
    // The sitting stands open (Story 2.3): deals resolve inside it.
    final log = [_sessionStarted(utcMicros(2026, 8, 28, 11))];
    final composition = composeDay(
      catalogue: upkeepOnly,
      log: log,
      instantUtcMicros: now,
      offsetSeconds: 0,
    );
    expect(composition.focus, isNull);
    expect(composition.maintenance.map((card) => card.id), ['man-a']);
    expect(composition.instantHabits.map((card) => card.id), ['hab-a']);
    final deal = nextDeal(
      catalogue: upkeepOnly,
      log: log,
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
      // composes a z2 chunk — the rotation turns on the boundary. Each
      // resolve sits inside its own open sitting (Story 2.3).
      final friday = nextDeal(
        catalogue: _catalogue,
        log: [_sessionStarted(utcMicros(2026, 8, 28, 11))],
        instantUtcMicros: utcMicros(2026, 8, 28, 12),
        offsetSeconds: 0,
      );
      expect(friday!.zone, Zone.z1);
      final monday = nextDeal(
        catalogue: _catalogue,
        log: [_sessionStarted(utcMicros(2026, 8, 31, 11))],
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
      // fondo fill the week. Each run day is its own sitting (Story
      // 2.3): start, deal, answer, close.
      var log = <LogEntry>[];
      final dealt = <String>[];
      for (var day = 7; day < 14; day++) {
        log.add(_sessionStarted(_day(day)));
        final deal = nextDeal(
          catalogue: _catalogue,
          log: log,
          instantUtcMicros: _day(day),
          offsetSeconds: 0,
        )!;
        dealt.add(deal.id);
        log
          ..add(_dealt(_day(day) + 1, deal.id))
          ..add(_done(_day(day) + 2, deal.id))
          ..add(_sessionEnded(_day(day) + 3));
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
        log.add(_sessionStarted(_day(day)));
        final deal = nextDeal(
          catalogue: _catalogue,
          log: log,
          instantUtcMicros: _day(day),
          offsetSeconds: 0,
        )!;
        dealt.add(deal.id);
        log
          ..add(_dealt(_day(day) + 1, deal.id))
          ..add(_done(_day(day) + 2, deal.id))
          ..add(_sessionEnded(_day(day) + 3));
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
      log.add(_sessionStarted(_day(35)));
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
          log: [_sessionStarted(utcMicros(2026, 9, 22, 11))],
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
          log: [_sessionStarted(utcMicros(2026, 8, 30, 11))],
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
          // The sitting stands open, so the null names the empty offer —
          // not the sessionless line (Story 2.3).
          log: [_sessionStarted(utcMicros(2026, 8, 28, 11))],
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
      // Each run day is its own sitting (Story 2.3): start, deal,
      // answer, close.
      var log = <LogEntry>[];
      Card chunkOn(int day) {
        log.add(_sessionStarted(_day(day)));
        final deal = nextDeal(
          catalogue: _catalogue,
          log: log,
          instantUtcMicros: _day(day),
          offsetSeconds: 0,
        )!;
        log
          ..add(_dealt(_day(day) + 1, deal.id))
          ..add(_done(_day(day) + 2, deal.id))
          ..add(_sessionEnded(_day(day) + 3));
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
        log.add(_sessionStarted(_day(day)));
        final deal = nextDeal(
          catalogue: catalogue,
          log: log,
          instantUtcMicros: _day(day),
          offsetSeconds: 0,
        )!;
        log
          ..add(_dealt(_day(day) + 1, deal.id))
          ..add(
            skip
                ? _skipped(_day(day) + 2, deal.id)
                : _done(_day(day) + 2, deal.id),
          )
          ..add(_sessionEnded(_day(day) + 3));
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
      // Each run day is its own sitting (Story 2.3).
      var log = <LogEntry>[];
      final dealt = <String>[];
      for (var day = 0; day < 17; day++) {
        log.add(_sessionStarted(_day(day)));
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
          ..add(_dealt(_day(day) + 1, deal.id))
          ..add(_done(_day(day) + 2, deal.id))
          ..add(_sessionEnded(_day(day) + 3));
      }
      expect(dealt.toSet(), hasLength(17), reason: 'all eligible answered');
      // Day 18: tiers 1 and 2 hold nothing — tier 3 repeats the
      // least-recently-dealt eligible entry, the deal of day 1.
      log.add(_sessionStarted(_day(17)));
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
      // Each run day is its own sitting (Story 2.3).
      var log = <LogEntry>[];
      final dealt = <String>[];
      final dealtZones = <Zone?>[];
      for (var day = 0; day < 21; day++) {
        log.add(_sessionStarted(_day(day)));
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
          ..add(_dealt(_day(day) + 1, deal.id))
          ..add(_done(_day(day) + 2, deal.id))
          ..add(_sessionEnded(_day(day) + 3));
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
      // Each run day is its own sitting (Story 2.3).
      var log = <LogEntry>[];
      final dealtIds = <String>[];
      for (var day = 0; day < 28; day++) {
        log.add(_sessionStarted(_day(day)));
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
          ..add(_dealt(_day(day) + 1, deal.id))
          ..add(_done(_day(day) + 2, deal.id))
          ..add(_sessionEnded(_day(day) + 3));
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

  group('setting_changed rows and the weave (Story 2.1)', () {
    SettingEntry setting(int micros, String key, int value) => SettingEntry(
      id: 'setting-$micros-$key-$value',
      instantUtcMicros: micros,
      offsetSeconds: 0,
      key: key,
      value: value,
    );

    test('the walk is inert to setting rows — settings are the shell\'s '
        'derivation, never the weave\'s internal policy', () {
      final withSettings = walkLog([
        setting(_day(0, 8), 'time_bag', 5),
        _sessionStarted(_day(0, 9)),
        _dealt(_day(0, 9), 'zona-z1-a'),
        setting(_day(0, 10), 'time_bag', 30),
      ], catalogue: _catalogue);
      final without = walkLog([
        _sessionStarted(_day(0, 9)),
        _dealt(_day(0, 9), 'zona-z1-a'),
      ], catalogue: _catalogue);
      expect(
        withSettings.lastDealtInstantByItemId,
        without.lastDealtInstantByItemId,
      );
      expect(withSettings.focusSlotClosedDays, without.focusSlotClosedDays);
      expect(withSettings.dealtCountsByDay, without.dealtCountsByDay);
      expect(withSettings.answeredItemIds, without.answeredItemIds);
      expect(withSettings.openSessionStart, without.openSessionStart);
      expect(withSettings.dealtUnanswered, without.dealtUnanswered);
    });

    test('the bag derivation is invariant to acts and session rows — '
        'FR-9\'s rollback is vacuous (Story 2.3)', () {
      // The no_lateness_proof style, on the ceiling: append every act
      // shape the product can write and the derivation stands — nothing
      // was ever subtracted, so nothing returns and no accumulator can
      // exist.
      final alone = [setting(_day(0, 8), 'time_bag', 15)];
      expect(deriveTimeBagMinutes(alone), 15);
      final withActs = [
        ...alone,
        _sessionStarted(_day(0, 9)),
        _dealt(utcMicros(2026, 8, 24, 9, 0, 1), 'zona-z1-a'),
        _done(utcMicros(2026, 8, 24, 9, 0, 2), 'zona-z1-a'),
        _skipped(utcMicros(2026, 8, 24, 9, 0, 3), 'man-a'),
        _sessionEnded(utcMicros(2026, 8, 24, 9, 30)),
        _sessionStarted(_day(0, 10), pocketMinutes: 10),
      ];
      expect(
        deriveTimeBagMinutes(withActs),
        15,
        reason:
            'no card act, session row or pocket moves the ceiling — '
            'the bag reads setting_changed rows alone',
      );
      // The derivation moves forward only, as ever.
      expect(
        deriveTimeBagMinutes([
          ...withActs,
          setting(_day(1, 8), 'time_bag', 30),
        ]),
        30,
      );
    });

    test('the below-10 gate reads the threaded bag; the default is the '
        'setting\'s own constant — one source of truth for 15', () {
      expect(
        composeDay(
          catalogue: _catalogue,
          log: const [],
          instantUtcMicros: now,
          offsetSeconds: 0,
        ).focus,
        isNotNull,
      );
      expect(
        defaultTimeBagMinutes,
        15,
        reason:
            'the weave\'s composition default is core/settings\' '
            'constant (FR-7, §10.1)',
      );
      // A bag derived by the shell and threaded in composes identically
      // to a literal parameter — the derivation adds no gate of its own.
      final threaded = composeDay(
        catalogue: _catalogue,
        log: const [],
        instantUtcMicros: now,
        offsetSeconds: 0,
        bagMinutes: deriveTimeBagMinutes([setting(_day(0, 8), 'time_bag', 9)]),
      );
      expect(threaded.focus, isNull);
      expect(threaded.maintenance, hasLength(3));
      expect(threaded.instantHabits, hasLength(5));
    });
  });

  group('report_answered rows and the weave (Story 2.6)', () {
    ReportAnsweredEntry answer(int micros, int value, int week) =>
        ReportAnsweredEntry(
          id: 'report-$micros-$value-$week',
          instantUtcMicros: micros,
          offsetSeconds: 0,
          value: value,
          week: week,
        );

    test('the walk is inert to report rows — nothing reads the kind yet '
        '(parts 2–3 derive over the rows, never the walk)', () {
      // The setting-row idiom, on the eleventh kind: a well-formed
      // answer rides the log and moves no fact the walk makes — the
      // no-op switch arm is pinned, not assumed.
      final withReport = walkLog([
        answer(_day(0, 8), 3, 1394),
        _sessionStarted(_day(0, 9), pocketMinutes: 15),
        _dealt(_day(0, 9), 'zona-z1-a'),
        answer(_day(0, 10), 5, 1394),
      ], catalogue: _catalogue);
      final without = walkLog([
        _sessionStarted(_day(0, 9), pocketMinutes: 15),
        _dealt(_day(0, 9), 'zona-z1-a'),
      ], catalogue: _catalogue);
      expect(
        withReport.lastDealtInstantByItemId,
        without.lastDealtInstantByItemId,
      );
      expect(withReport.focusSlotClosedDays, without.focusSlotClosedDays);
      expect(withReport.dealtCountsByDay, without.dealtCountsByDay);
      expect(withReport.answeredItemIds, without.answeredItemIds);
      expect(withReport.openSessionStart, without.openSessionStart);
      expect(withReport.dealtUnanswered, without.dealtUnanswered);
      expect(
        withReport.openSessionPocketMinutes,
        without.openSessionPocketMinutes,
      );
      expect(
        withReport.openSessionAnsweredSeconds,
        without.openSessionAnsweredSeconds,
      );
    });
  });

  group('capture_created rows and the weave (Story 3.2)', () {
    ItemActEntry capture(int micros, String itemId) => ItemActEntry(
      id: 'capture-$micros-$itemId',
      instantUtcMicros: micros,
      offsetSeconds: 0,
      kind: LogKind.captureCreated,
      itemId: itemId,
      itemOrigin: Origin.manual,
    );

    test('the walk is inert to capture rows — a capture is not a '
        'candidate yet (3.3 derives candidacy, never the walk)', () {
      // The report-row idiom, on the twelfth kind: a well-formed
      // capture rides the log and moves no fact the walk makes — the
      // row's itemId names a fact the walk never deals, so the no-op
      // arm is pinned, not assumed.
      final withCapture = walkLog([
        capture(_day(0, 8), 'man-cap-a'),
        _sessionStarted(_day(0, 9), pocketMinutes: 15),
        _dealt(_day(0, 9), 'zona-z1-a'),
        capture(_day(0, 10), 'man-cap-b'),
      ], catalogue: _catalogue);
      final without = walkLog([
        _sessionStarted(_day(0, 9), pocketMinutes: 15),
        _dealt(_day(0, 9), 'zona-z1-a'),
      ], catalogue: _catalogue);
      expect(
        withCapture.lastDealtInstantByItemId,
        without.lastDealtInstantByItemId,
      );
      expect(withCapture.focusSlotClosedDays, without.focusSlotClosedDays);
      expect(withCapture.dealtCountsByDay, without.dealtCountsByDay);
      expect(withCapture.dealtDaysByItemId, without.dealtDaysByItemId);
      expect(withCapture.answeredItemIds, without.answeredItemIds);
      expect(withCapture.openSessionStart, without.openSessionStart);
      expect(withCapture.dealtUnanswered, without.dealtUnanswered);
      expect(
        withCapture.openSessionPocketMinutes,
        without.openSessionPocketMinutes,
      );
      expect(
        withCapture.openSessionAnsweredSeconds,
        without.openSessionAnsweredSeconds,
      );
    });
  });

  group('manual capture candidacy (Story 3.3)', () {
    test('a standing focus capture is the session\'s first deal — its '
        'own line as the name, no zone, its size\'s estimate', () {
      final fact = _captureFact('cap-focus', Size.focus, _day(0, 8));
      final log = [_sessionStarted(_day(0, 9))];
      final deal = nextDeal(
        catalogue: _catalogue,
        log: log,
        instantUtcMicros: now,
        offsetSeconds: 0,
        poolFacts: [fact],
      );
      expect(deal!.id, 'cap-focus');
      expect(deal.name, 'Llamar al dentista');
      expect(deal.size, Size.focus);
      expect(deal.origin, Origin.manual);
      expect(deal.zone, isNull);
      expect(deal.estimateSeconds, focusEstimateSeconds);
    });

    test('a dealt capture charges its size\'s daily count exactly like '
        'a catalogue deal, and its charged day lands per id', () {
      final fact = _captureFact('cap-man', Size.maintenance, _day(0, 8));
      final charged = walkLog(
        [
          _sessionStarted(_day(0, 9)),
          _captureDealt(utcMicros(2026, 8, 24, 9, 0, 1), 'cap-man'),
        ],
        catalogue: _catalogue,
        poolFacts: [fact],
      );
      const calendar = Calendar();
      final day = calendar.dayOf(_day(0, 9), 0);
      expect(charged.dealtCountsByDay[day]?[Size.maintenance], 1);
      expect(charged.dealtDaysByItemId['cap-man'], {day});
    });

    test('captures take precedence over same-size catalogue candidates '
        'in the draws', () {
      final fact = _captureFact('cap-man', Size.maintenance, _day(0, 8));
      final composition = composeDay(
        catalogue: _catalogue,
        log: const [],
        instantUtcMicros: now,
        offsetSeconds: 0,
        poolFacts: [fact],
      );
      expect(composition.maintenance.first.id, 'cap-man');
      expect(composition.maintenance[1].id, 'man-a');
      // An instant capture leads its tier the same way.
      final habit = _captureFact('cap-i', Size.instant, _day(0, 8));
      final habits = composeDay(
        catalogue: _catalogue,
        log: const [],
        instantUtcMicros: now,
        offsetSeconds: 0,
        poolFacts: [habit],
      );
      expect(habits.instantHabits.first.id, 'cap-i');
      expect(habits.instantHabits[1].id, 'hab-a');
    });

    test('same-size captures order oldest-first by fact instants, '
        'never id bit patterns — and never input order', () {
      final older = _captureFact('cap-z', Size.instant, _day(0, 7));
      final newer = _captureFact('cap-a', Size.instant, _day(0, 8));
      final composition = composeDay(
        catalogue: _catalogue,
        log: const [],
        instantUtcMicros: now,
        offsetSeconds: 0,
        poolFacts: [newer, older],
      );
      expect(
        composition.instantHabits.take(2).map((card) => card.id).toList(),
        ['cap-z', 'cap-a'],
        reason: 'the older fact leads whatever its id sorts as',
      );
    });

    test('a skip keeps the capture\'s FIFO place — the same capture '
        're-offers, unlike the catalogue\'s re-ranking', () {
      final older = _captureFact('cap-old', Size.maintenance, _day(0, 7));
      final newer = _captureFact('cap-new', Size.maintenance, _day(0, 8));
      final log = [
        _sessionStarted(_day(0, 9)),
        _dealt(utcMicros(2026, 8, 24, 9, 0, 1), 'zona-z1-a'),
        _done(utcMicros(2026, 8, 24, 9, 0, 2), 'zona-z1-a'),
        _captureDealt(utcMicros(2026, 8, 24, 9, 0, 3), 'cap-old'),
        _captureSkipped(utcMicros(2026, 8, 24, 9, 0, 4), 'cap-old'),
      ];
      final deal = nextDeal(
        catalogue: _catalogue,
        log: log,
        instantUtcMicros: now,
        offsetSeconds: 0,
        poolFacts: [newer, older],
      );
      expect(deal!.id, 'cap-old');
      expect(deal.size, Size.maintenance);
    });

    test('a not-yet-answered focus capture is the chunk tier — ahead '
        'of the zone tier, and composing with no active zone at all', () {
      final fact = _captureFact('cap-focus', Size.focus, _day(0, 8));
      final zoned = composeDay(
        catalogue: _catalogue,
        log: const [],
        instantUtcMicros: now,
        offsetSeconds: 0,
        poolFacts: [fact],
      );
      expect(zoned.focus!.id, 'cap-focus');

      // FR-11's empty ring still holds the capture.
      final ringEmpty = composeDay(
        catalogue: _catalogue,
        log: const [],
        instantUtcMicros: now,
        offsetSeconds: 0,
        activeClusters: const {},
        poolFacts: [fact],
      );
      expect(ringEmpty.focus!.id, 'cap-focus');
      expect(ringEmpty.focus!.zone, isNull);
      // And the day holds no second large item beside it: with the
      // ring empty the draws are sized 3 and 5, and under the active
      // zone they hold no focus card either.
      expect(ringEmpty.maintenance, isEmpty);
      expect(
        zoned.maintenance.every((card) => card.size == Size.maintenance),
        isTrue,
      );
      expect(zoned.maintenance, hasLength(maintenanceDrawsPerDay));
    });

    test('a focus capture\'s Hecho closes the day\'s chunk slot — the '
        'day composes no second large item after it', () {
      final fact = _captureFact(
        'cap-focus',
        Size.focus,
        utcMicros(2026, 8, 28, 8),
      );
      final log = [
        _sessionStarted(utcMicros(2026, 8, 28, 9)),
        _captureDealt(utcMicros(2026, 8, 28, 9, 0, 1), 'cap-focus'),
        _captureDone(utcMicros(2026, 8, 28, 9, 0, 2), 'cap-focus'),
        _sessionEnded(utcMicros(2026, 8, 28, 9, 0, 3)),
      ];
      final composition = composeDay(
        catalogue: _catalogue,
        log: log,
        instantUtcMicros: now,
        offsetSeconds: 0,
        poolFacts: [fact],
      );
      expect(composition.focus, isNull);
      expect(composition.maintenance.first.id, 'man-a');
    });

    test('done-once retirement: an answered capture never deals again, '
        'at the chunk or in any draw', () {
      final retired = _captureFact(
        'cap-focus',
        Size.focus,
        utcMicros(2026, 8, 27, 9),
      );
      final standing = _captureFact(
        'cap-new',
        Size.focus,
        utcMicros(2026, 8, 27, 10),
      );
      final log = [
        _sessionStarted(utcMicros(2026, 8, 28, 9)),
        _captureDealt(utcMicros(2026, 8, 28, 9, 0, 1), 'cap-focus'),
        _captureDone(utcMicros(2026, 8, 28, 9, 0, 2), 'cap-focus'),
        _sessionEnded(utcMicros(2026, 8, 28, 9, 0, 3)),
      ];
      // The same day: the Hecho closed the chunk slot, so nothing
      // focus-sized composes at all.
      final sameDay = composeDay(
        catalogue: _catalogue,
        log: log,
        instantUtcMicros: now,
        offsetSeconds: 0,
        poolFacts: [retired, standing],
      );
      expect(sameDay.focus, isNull);
      expect(sameDay.maintenance.first.id, 'man-a');
      // The next day — Saturday 2026-08-29, its slot open: the retired
      // capture is gone from the offering and the younger capture is
      // the chunk. Had retirement failed, the oldest fact (`cap-focus`)
      // would lead the tier again.
      final nextDay = nextDeal(
        catalogue: _catalogue,
        log: [...log, _sessionStarted(utcMicros(2026, 8, 29, 11))],
        instantUtcMicros: utcMicros(2026, 8, 29, 12),
        offsetSeconds: 0,
        poolFacts: [retired, standing],
      );
      expect(nextDay!.id, 'cap-new');

      // A maintenance capture answers and leaves its tier to the
      // catalogue behind it.
      final upkeep = _captureFact(
        'cap-man',
        Size.maintenance,
        utcMicros(2026, 8, 28, 8),
      );
      final answered = [
        _sessionStarted(utcMicros(2026, 8, 28, 9)),
        _captureDealt(utcMicros(2026, 8, 28, 9, 0, 1), 'cap-man'),
        _captureDone(utcMicros(2026, 8, 28, 9, 0, 2), 'cap-man'),
        _sessionEnded(utcMicros(2026, 8, 28, 9, 0, 3)),
      ];
      final composition = composeDay(
        catalogue: _catalogue,
        log: answered,
        instantUtcMicros: now,
        offsetSeconds: 0,
        poolFacts: [upkeep],
      );
      expect(composition.maintenance.first.id, 'man-a');
    });

    test('a bag below ten minutes drops the focus capture from the '
        'chunk — the existing gate still holds', () {
      final fact = _captureFact('cap-focus', Size.focus, _day(0, 8));
      final composition = composeDay(
        catalogue: _catalogue,
        log: const [],
        instantUtcMicros: now,
        offsetSeconds: 0,
        bagMinutes: 9,
        poolFacts: [fact],
      );
      expect(composition.focus, isNull);
      expect(
        composition.instantHabits.map((card) => card.id),
        isNot(contains('cap-focus')),
      );

      final deal = nextDeal(
        catalogue: _catalogue,
        log: [_sessionStarted(_day(0, 9))],
        instantUtcMicros: now,
        offsetSeconds: 0,
        bagMinutes: 9,
        poolFacts: [fact],
      );
      expect(deal!.id, isNot('cap-focus'));
      expect(deal.size, isNot(Size.focus));
    });

    test('a 🔴 day: focus and maintenance captures reach no draw, an '
        'instant capture deals with the habits (the existing ceiling)', () {
      final focus = _captureFact('cap-focus', Size.focus, _day(0, 8));
      final log = [_sessionStarted(_day(0, 9))];
      final deal = nextDeal(
        catalogue: _catalogue,
        log: log,
        instantUtcMicros: now,
        offsetSeconds: 0,
        energy: EnergyLevel.low,
        poolFacts: [focus],
      );
      expect(deal!.size, Size.instant);
      expect(deal.id, isNot('cap-focus'));

      final maintenance = _captureFact('cap-man', Size.maintenance, _day(0, 8));
      final composition = composeDay(
        catalogue: _catalogue,
        log: const [],
        instantUtcMicros: now,
        offsetSeconds: 0,
        energy: EnergyLevel.low,
        poolFacts: [maintenance],
      );
      expect(
        composition.maintenance.map((card) => card.id),
        isNot(contains('cap-man')),
      );

      final instant = _captureFact('cap-i', Size.instant, _day(0, 8));
      final habits = nextDeal(
        catalogue: _catalogue,
        log: log,
        instantUtcMicros: now,
        offsetSeconds: 0,
        energy: EnergyLevel.low,
        poolFacts: [instant],
      );
      expect(habits!.id, 'cap-i');
    });

    test('a dealt-but-unanswered capture re-materializes through '
        'cardForItem — the standing-card path never depends on '
        'candidacy', () {
      final fact = _captureFact('cap-man', Size.maintenance, _day(0, 8));
      final card = cardForItem(
        catalogue: _catalogue,
        itemId: 'cap-man',
        origin: Origin.manual,
        poolFacts: [fact],
      );
      expect(card!.id, 'cap-man');
      expect(card.name, 'Llamar al dentista');
      expect(card.size, Size.maintenance);
      expect(card.zone, isNull);
      expect(card.origin, Origin.manual);
      expect(card.estimateSeconds, maintenanceEstimateSeconds);

      // The catalogue still answers first for its own ids, and an id
      // no source knows resolves absent.
      expect(
        cardForItem(
          catalogue: _catalogue,
          itemId: 'man-a',
          origin: Origin.shipped,
          poolFacts: [fact],
        )!.name,
        'Tarea de man-a',
      );
      expect(
        cardForItem(
          catalogue: _catalogue,
          itemId: 'no-such-id',
          origin: Origin.manual,
          poolFacts: [fact],
        ),
        isNull,
      );
    });

    test('a FIFO tie between same-size captures with equal creation '
        'instants breaks by stable id — never arbitrarily, never input '
        'order', () {
      final tie = utcMicros(2026, 8, 28, 7);
      final a = _captureFact('cap-a', Size.instant, tie);
      final z = _captureFact('cap-z', Size.instant, tie);
      final composition = composeDay(
        catalogue: _catalogue,
        log: const [],
        instantUtcMicros: now,
        offsetSeconds: 0,
        poolFacts: [z, a],
      );
      expect(
        composition.instantHabits.take(2).map((card) => card.id).toList(),
        ['cap-a', 'cap-z'],
      );
    });

    test('duplicate fact ids offer once — the snapshot\'s first is '
        'the candidate, and two facts sharing an id cannot fill two '
        'draw slots', () {
      final first = _captureFact(
        'cap-dup',
        Size.instant,
        utcMicros(2026, 8, 28, 7),
        line: 'Primera línea',
      );
      final second = _captureFact(
        'cap-dup',
        Size.instant,
        utcMicros(2026, 8, 28, 8),
        line: 'Segunda línea',
      );
      final composition = composeDay(
        catalogue: _catalogue,
        log: const [],
        instantUtcMicros: now,
        offsetSeconds: 0,
        poolFacts: [first, second],
      );
      expect(
        composition.instantHabits.where((card) => card.id == 'cap-dup'),
        hasLength(1),
      );
      expect(composition.instantHabits.first.name, 'Primera línea');
      // The five-slot tier holds one capture and four habits — the
      // duplicate never displaced a second habit.
      expect(
        composition.instantHabits.where(
          (card) => card.origin == Origin.shipped,
        ),
        hasLength(4),
      );
    });

    test('the close-continue probe sees captures: a pool whose only '
        'remaining work is a capture answers true, and false with no '
        'facts (Story 2.4\'s seam over 3.3\'s source)', () {
      // The honest "only remaining work is a capture": the empty
      // cluster set offers no catalogue candidate at all, while the
      // capture tier composes regardless of the ring (a capture
      // charges its size's daily count like anyone, so a spent day\'s
      // exhausted counts admit nobody — captures included).
      final fact = _captureFact(
        'cap-focus',
        Size.focus,
        utcMicros(2026, 8, 28, 8),
      );
      final log = [_sessionStarted(utcMicros(2026, 8, 28, 9))];
      expect(
        dealExistsIgnoringPocket(
          catalogue: _catalogue,
          log: log,
          instantUtcMicros: now,
          offsetSeconds: 0,
          activeClusters: const {},
          poolFacts: [fact],
        ),
        isTrue,
      );
      expect(
        dealExistsIgnoringPocket(
          catalogue: _catalogue,
          log: log,
          instantUtcMicros: now,
          offsetSeconds: 0,
          activeClusters: const {},
        ),
        isFalse,
      );
    });

    test('a declared pocket refuses a focus capture\'s 15-minute '
        'estimate — the ladder falls through to upkeep — and the '
        'capture\'s estimate charges the sitting\'s ceiling once '
        'answered', () {
      final fact = _captureFact(
        'cap-focus',
        Size.focus,
        utcMicros(2026, 8, 28, 8),
      );
      final start = utcMicros(2026, 8, 28, 9);

      // A 10-minute pocket cannot hold the capture's 900 s estimate:
      // the chunk offer falls through and upkeep leads the day.
      final refusal = nextDeal(
        catalogue: _catalogue,
        log: [_sessionStarted(start, pocketMinutes: 10)],
        instantUtcMicros: start + 1,
        offsetSeconds: 0,
        poolFacts: [fact],
      );
      expect(refusal!.size, Size.maintenance);
      expect(refusal.id, isNot('cap-focus'));

      // Answered inside a 10-minute pocket (a carried card, say — the
      // filter never withdraws work in progress), the capture's own
      // estimate charges the sitting via the fact's size: 900 s
      // against the 600 s ceiling, and nothing more fits.
      final charged = [
        _sessionStarted(start, pocketMinutes: 10),
        _captureDealt(start + 1, 'cap-focus'),
        _captureDone(start + 2, 'cap-focus'),
      ];
      final facts = walkLog(charged, catalogue: _catalogue, poolFacts: [fact]);
      expect(facts.openSessionAnsweredSeconds, focusEstimateSeconds);
      final after = nextDeal(
        catalogue: _catalogue,
        log: charged,
        instantUtcMicros: start + 3,
        offsetSeconds: 0,
        poolFacts: [fact],
      );
      expect(after, isNull, reason: 'the blown ceiling admits nothing');
    });
  });

  group('the rescue chains in the weave (Story 4.6, FR-5, AD-20/25)', () {
    // The standing fixture's clock: Friday 2026-08-28 noon.
    final now = utcMicros(2026, 8, 28, 12);

    Card? deal(
      List<LogEntry> log,
      List<PoolFact> facts, {
      int? at,
      EnergyLevel energy = EnergyLevel.full,
    }) => nextDeal(
      catalogue: _catalogue,
      log: log,
      instantUtcMicros: at ?? now,
      offsetSeconds: 0,
      energy: energy,
      poolFacts: facts,
    );

    test('a live chain\'s head step deals first — above the chunk and '
        'above captures, its estimate verbatim (never the size\'s '
        'default)', () {
      final parent = _captureFact(
        'cap-focus',
        Size.focus,
        utcMicros(2026, 8, 27, 8),
      );
      final olderCapture = _captureFact(
        'cap-old',
        Size.maintenance,
        utcMicros(2026, 8, 26, 8),
        line: 'Cosa más vieja',
      );
      final steps = [
        _stepFact(
          's1',
          utcMicros(2026, 8, 28, 9),
          'cap-focus',
          estimateSeconds: 45,
          line: 'Buscar el desengrasante',
        ),
        _stepFact(
          's2',
          utcMicros(2026, 8, 28, 9),
          'cap-focus',
          estimateSeconds: 60,
          line: 'Rociar y dejar actuar',
        ),
      ];
      final log = [_sessionStarted(utcMicros(2026, 8, 28, 10))];
      final card = deal(log, [parent, olderCapture, ...steps]);
      expect(card, isNotNull);
      expect(card!.id, 's1');
      expect(card.size, Size.instant);
      expect(
        card.estimateSeconds,
        45,
        reason:
            'the Slicer\'s own tag, verbatim — not the instant '
            'band\'s default',
      );
      expect(card.name, 'Buscar el desengrasante');
      expect(card.origin, Origin.manual);
      // The head also renders through cardForItem with the same
      // estimate — the standing card and the deal read one number.
      final standing = cardForItem(
        catalogue: _catalogue,
        itemId: 's1',
        origin: Origin.manual,
        poolFacts: steps,
      );
      expect(standing!.estimateSeconds, 45);
    });

    test('the head advances only on answers — a skipped step is still '
        'the head (skips never exclude, the dissolution is the exit), '
        'and a later step never offers early', () {
      final parent = _captureFact(
        'cap-focus',
        Size.focus,
        utcMicros(2026, 8, 27, 8),
      );
      final steps = [
        _stepFact(
          's1',
          utcMicros(2026, 8, 28, 9),
          'cap-focus',
          line: 'Paso uno',
        ),
        _stepFact(
          's2',
          utcMicros(2026, 8, 28, 9),
          'cap-focus',
          line: 'Paso dos',
        ),
      ];
      final skipped = [
        _sessionStarted(utcMicros(2026, 8, 28, 10)),
        _captureDealt(utcMicros(2026, 8, 28, 10, 0, 1), 's1'),
        _captureSkipped(utcMicros(2026, 8, 28, 10, 0, 2), 's1'),
      ];
      final card = deal(skipped, [parent, ...steps]);
      expect(
        card!.id,
        's1',
        reason:
            'the declined step stays the head — one at a time '
            'means answered, not declined',
      );
      // And the composition never leaks the later step into any draw.
      final composition = composeDay(
        catalogue: _catalogue,
        log: skipped,
        instantUtcMicros: now,
        offsetSeconds: 0,
        poolFacts: [parent, ...steps],
      );
      expect(
        [
          ...composition.maintenance,
          ...composition.instantHabits,
          if (composition.focus != null) composition.focus!,
        ].any((card) => card.id == 's2'),
        isFalse,
        reason:
            'only the head is ever a candidate — later steps stand '
            'behind it, unseen by any surface',
      );
    });

    test('the oldest live chain\'s head stands first — a chain never '
        'leapfrogs a chain', () {
      final first = [
        _stepFact('a1', utcMicros(2026, 8, 26, 9), 'cap-one', line: 'A uno'),
      ];
      final second = [
        _stepFact('b1', utcMicros(2026, 8, 27, 9), 'cap-two', line: 'B uno'),
      ];
      final log = [_sessionStarted(utcMicros(2026, 8, 28, 10))];
      final card = deal(log, [...second, ...first]);
      expect(card!.id, 'a1');
    });

    test('all steps done retires the parent by derivation — no '
        'synthetic card_done, the chain offers nothing, and the parent '
        'never returns as a candidate (AD-25)', () {
      final parent = _captureFact(
        'cap-focus',
        Size.focus,
        utcMicros(2026, 8, 27, 8),
      );
      final steps = [
        _stepFact(
          's1',
          utcMicros(2026, 8, 28, 9),
          'cap-focus',
          line: 'Paso uno',
        ),
        _stepFact(
          's2',
          utcMicros(2026, 8, 28, 9),
          'cap-focus',
          line: 'Paso dos',
        ),
      ];
      final log = [
        _sessionStarted(utcMicros(2026, 8, 28, 10)),
        _sliceRow(
          LogKind.sliceReturned,
          utcMicros(2026, 8, 28, 10, 0, 1),
          'cap-focus',
        ),
        _captureDealt(utcMicros(2026, 8, 28, 10, 0, 2), 's1'),
        _captureDone(utcMicros(2026, 8, 28, 10, 0, 3), 's1'),
        _captureDealt(utcMicros(2026, 8, 28, 10, 0, 4), 's2'),
        _captureDone(utcMicros(2026, 8, 28, 10, 0, 5), 's2'),
      ];
      final facts = walkLog(
        log,
        catalogue: _catalogue,
        poolFacts: [parent, ...steps],
      );
      expect(facts.answeredItemIds, containsAll(['s1', 's2']));
      expect(
        facts.answeredItemIds,
        isNot(contains('cap-focus')),
        reason:
            'completion counts user acts only — the parent is done '
            'by derivation, never by a synthetic card_done',
      );
      final card = deal(log, [parent, ...steps]);
      expect(
        card!.id,
        isNot('cap-focus'),
        reason:
            'the parent never returns as a candidate from '
            'activation onward',
      );
      expect(
        card.id,
        'man-a',
        reason:
            'the completed chain out of the way — and the day\'s '
            'slot spent by the completion itself — the maintenance '
            'tier leads as any closed day\'s would',
      );
    });

    test('a focus-parent chain\'s completion closes the slot on the '
        'day of the session that dealt its last card_done — and no '
        'other day; the crossed-into day stays free', () {
      final parent = _captureFact(
        'cap-focus',
        Size.focus,
        utcMicros(2026, 8, 27, 8),
      );
      final steps = [
        _stepFact(
          's1',
          utcMicros(2026, 8, 28, 9),
          'cap-focus',
          line: 'Paso uno',
        ),
        _stepFact(
          's2',
          utcMicros(2026, 8, 28, 9),
          'cap-focus',
          line: 'Paso dos',
        ),
      ];
      // A sitting starting 03:50 on Saturday Aug 29 belongs to
      // domestic Friday Aug 28 (the 04:00 boundary); its last answer
      // lands 04:10 — Saturday's civil clock, Friday's session.
      final crossing = [
        _sessionStarted(utcMicros(2026, 8, 29, 3, 50)),
        _captureDealt(utcMicros(2026, 8, 29, 3, 55), 's1'),
        _captureDone(utcMicros(2026, 8, 29, 3, 56), 's1'),
        _captureDealt(utcMicros(2026, 8, 29, 4, 5), 's2'),
        _captureDone(utcMicros(2026, 8, 29, 4, 10), 's2'),
        _sessionEnded(utcMicros(2026, 8, 29, 4, 30)),
      ];
      final facts = walkLog(
        crossing,
        catalogue: _catalogue,
        poolFacts: [parent, ...steps],
      );
      expect(
        facts.focusSlotClosedDays,
        {const Calendar().dayOf(utcMicros(2026, 8, 28, 12), 0)},
        reason:
            'the session\'s own day — crossing-safe through the '
            'session-day rule',
      );
      // The crossed-into day (Saturday) stays free: its own chunk
      // composes as any untouched day's would.
      final saturday = composeDay(
        catalogue: _catalogue,
        log: crossing,
        instantUtcMicros: utcMicros(2026, 8, 29, 12),
        offsetSeconds: 0,
        poolFacts: [parent, ...steps],
      );
      expect(
        saturday.focus,
        isNotNull,
        reason:
            'a completion crossing 04:00 never closes the '
            'crossed-into day',
      );
      // And Friday itself composes no new chunk — its slot is spent.
      final friday = composeDay(
        catalogue: _catalogue,
        log: crossing,
        instantUtcMicros: utcMicros(2026, 8, 28, 20),
        offsetSeconds: 0,
        poolFacts: [parent, ...steps],
      );
      expect(friday.focus, isNull);
    });

    test('the closure holds regardless of the closing day\'s energy — '
        'a low-energy Friday still spends its slot on a completion', () {
      final parent = _captureFact(
        'cap-focus',
        Size.focus,
        utcMicros(2026, 8, 27, 8),
      );
      final steps = [
        _stepFact(
          's1',
          utcMicros(2026, 8, 28, 9),
          'cap-focus',
          line: 'Paso uno',
        ),
        _stepFact(
          's2',
          utcMicros(2026, 8, 28, 9),
          'cap-focus',
          line: 'Paso dos',
        ),
      ];
      final log = [
        EnergySetEntry(
          id: 'energy-low',
          instantUtcMicros: utcMicros(2026, 8, 28, 8),
          offsetSeconds: 0,
          level: EnergyLevel.low,
        ),
        _sessionStarted(utcMicros(2026, 8, 28, 10)),
        _captureDealt(utcMicros(2026, 8, 28, 10, 0, 1), 's1'),
        _captureDone(utcMicros(2026, 8, 28, 10, 0, 2), 's1'),
        _captureDealt(utcMicros(2026, 8, 28, 10, 0, 3), 's2'),
        _captureDone(utcMicros(2026, 8, 28, 10, 0, 4), 's2'),
      ];
      final facts = walkLog(
        log,
        catalogue: _catalogue,
        poolFacts: [parent, ...steps],
      );
      expect(facts.focusSlotClosedDays, {
        const Calendar().dayOf(utcMicros(2026, 8, 28, 12), 0),
      }, reason: 'energy filters composition, never a landed completion');
    });

    test('a non-focus parent\'s chain closes nothing — the day\'s '
        'chunk remains available behind a maintenance rescue', () {
      final parent = _captureFact(
        'cap-maint',
        Size.maintenance,
        utcMicros(2026, 8, 27, 8),
        line: 'Cosas del garaje',
      );
      final steps = [
        _stepFact(
          's1',
          utcMicros(2026, 8, 28, 9),
          'cap-maint',
          line: 'Paso uno',
        ),
        _stepFact(
          's2',
          utcMicros(2026, 8, 28, 9),
          'cap-maint',
          line: 'Paso dos',
        ),
      ];
      final log = [
        _sessionStarted(utcMicros(2026, 8, 28, 10)),
        _captureDealt(utcMicros(2026, 8, 28, 10, 0, 1), 's1'),
        _captureDone(utcMicros(2026, 8, 28, 10, 0, 2), 's1'),
        _captureDealt(utcMicros(2026, 8, 28, 10, 0, 3), 's2'),
        _captureDone(utcMicros(2026, 8, 28, 10, 0, 4), 's2'),
      ];
      final facts = walkLog(
        log,
        catalogue: _catalogue,
        poolFacts: [parent, ...steps],
      );
      expect(facts.focusSlotClosedDays, isEmpty);
    });

    test('a rescue activation on the day\'s dealt focus card satisfies '
        'the day\'s "1" — the chain carries the advance, no new chunk '
        'composes that day (FR-7\'s conversion, ADV-10)', () {
      final parent = _captureFact(
        'cap-focus',
        Size.focus,
        utcMicros(2026, 8, 27, 8),
      );
      final steps = [
        _stepFact(
          's1',
          utcMicros(2026, 8, 28, 9),
          'cap-focus',
          line: 'Paso uno',
        ),
        _stepFact(
          's2',
          utcMicros(2026, 8, 28, 9),
          'cap-focus',
          line: 'Paso dos',
        ),
      ];
      // The conversion: the Friday chunk dealt, superseded by the
      // slice_returned, the head step dealt in its place — then the
      // head answered, the second step still pending.
      final log = [
        _sessionStarted(utcMicros(2026, 8, 28, 10)),
        _captureDealt(utcMicros(2026, 8, 28, 10, 0, 1), 'cap-focus'),
        _sliceRow(
          LogKind.sliceReturned,
          utcMicros(2026, 8, 28, 10, 0, 2),
          'cap-focus',
        ),
        _captureDealt(utcMicros(2026, 8, 28, 10, 0, 3), 's1'),
        _captureDone(utcMicros(2026, 8, 28, 10, 0, 4), 's1'),
      ];
      final facts = walkLog(
        log,
        catalogue: _catalogue,
        poolFacts: [parent, ...steps],
      );
      expect(facts.focusSlotCarriedDays, {
        const Calendar().dayOf(utcMicros(2026, 8, 28, 12), 0),
      });
      // No unanswered card stands, the slot was never closed by a
      // card_done — and still Friday composes no new chunk: the chain
      // carries the day's "1".
      final friday = composeDay(
        catalogue: _catalogue,
        log: log,
        instantUtcMicros: utcMicros(2026, 8, 28, 11),
        offsetSeconds: 0,
        poolFacts: [parent, ...steps],
      );
      expect(
        friday.focus,
        isNull,
        reason:
            'the conversion, not a closure — but the day is '
            'satisfied either way',
      );
      // The next deal is the chain's second step, never a new chunk.
      expect(deal(log, [parent, ...steps])!.id, 's2');
    });

    test('a FAILED rescue carries nothing — the card stands dealable '
        'and a plain skip still re-resolves a new chunk (AD-20\'s '
        'recorded override)', () {
      // A shipped chunk: the skip re-ranks the zone tier, so the
      // re-resolved chunk is a different entry (identity re-resolves,
      // AD-20) — a capture parent would keep its FIFO place, the
      // zone tier is where the override shows.
      final failed = [
        _sessionStarted(utcMicros(2026, 8, 28, 10)),
        _dealt(utcMicros(2026, 8, 28, 10, 0, 1), 'zona-z1-a'),
        _sliceRow(
          LogKind.sliceRequested,
          utcMicros(2026, 8, 28, 10, 0, 2),
          'zona-z1-a',
          origin: Origin.shipped,
        ),
        _sliceRow(
          LogKind.sliceFailed,
          utcMicros(2026, 8, 28, 10, 0, 3),
          'zona-z1-a',
          origin: Origin.shipped,
        ),
      ];
      final facts = walkLog(failed, catalogue: _catalogue);
      expect(facts.focusSlotCarriedDays, isEmpty);
      expect(
        (facts.dealtUnanswered?.itemId),
        'zona-z1-a',
        reason: 'a failure supersedes nothing: the original stands',
      );
      // The skip after the failure re-resolves the chunk tier — a
      // different zone entry, the slot never closed.
      final skipped = [
        ...failed,
        _skipped(utcMicros(2026, 8, 28, 10, 0, 4), 'zona-z1-a'),
      ];
      final card = deal(skipped, const []);
      expect(card!.id, 'zona-z1-b');
      expect(card.size, Size.focus);
    });

    test('a rescue step\'s verbatim estimate charges the sitting\'s '
        'pocket — the duration-consuming rules read the tag, never the '
        'size\'s default', () {
      final parent = _captureFact(
        'cap-focus',
        Size.focus,
        utcMicros(2026, 8, 27, 8),
      );
      final steps = [
        _stepFact(
          's1',
          utcMicros(2026, 8, 28, 9),
          'cap-focus',
          estimateSeconds: 45,
          line: 'Paso uno',
        ),
        _stepFact(
          's2',
          utcMicros(2026, 8, 28, 9),
          'cap-focus',
          estimateSeconds: 60,
          line: 'Paso dos',
        ),
      ];
      final start = utcMicros(2026, 8, 28, 10);
      final log = [
        _sessionStarted(start, pocketMinutes: 1),
        _captureDealt(start + 1, 's1'),
        _captureDone(start + 2, 's1'),
      ];
      final facts = walkLog(
        log,
        catalogue: _catalogue,
        poolFacts: [parent, ...steps],
      );
      expect(
        facts.openSessionAnsweredSeconds,
        45,
        reason: 'the step\'s own 45 s, not the instant band\'s 30',
      );
      // 45 + 60 exceeds the 60 s pocket: the second step cannot deal,
      // and the sitting presents the warm close — had the size\'s '
      // default (30) been read instead, the head would have fit.
      final next = deal(log, [parent, ...steps], at: start + 3);
      expect(next, isNull);
    });

    test('a 🔴 day still deals a live chain\'s head — the ≤ 60 s '
        'estimate passes the ceiling by construction', () {
      final parent = _captureFact(
        'cap-focus',
        Size.focus,
        utcMicros(2026, 8, 27, 8),
      );
      final steps = [
        _stepFact(
          's1',
          utcMicros(2026, 8, 28, 9),
          'cap-focus',
          estimateSeconds: 60,
          line: 'Paso uno',
        ),
      ];
      final log = [_sessionStarted(utcMicros(2026, 8, 28, 10))];
      final card = deal(log, [parent, ...steps], energy: EnergyLevel.low);
      expect(card, isNotNull);
      expect(card!.id, 's1');
      expect(card.estimateSeconds, 60);
    });

    test('the dissolution retires the chain and its parent atomically '
        '— three decline days of chain steps, and nothing from the '
        'chain or the parent ever deals again (no tombstone, AD-25)', () {
      final parent = _captureFact(
        'cap-focus',
        Size.focus,
        utcMicros(2026, 8, 25, 8),
      );
      final steps = [
        _stepFact(
          's1',
          utcMicros(2026, 8, 26, 9),
          'cap-focus',
          line: 'Paso uno',
        ),
        _stepFact(
          's2',
          utcMicros(2026, 8, 26, 9),
          'cap-focus',
          line: 'Paso dos',
        ),
      ];
      // Three distinct eligible days, each with a sitting that dealt
      // and declined the head.
      List<LogEntry> decline(int days) => [
        _sessionStarted(_day(days, 10)),
        _captureDealt(
          utcMicros(2026, 8, 24, 10, 0, 1) + days * _microsPerDay,
          's1',
        ),
        _captureSkipped(
          utcMicros(2026, 8, 24, 10, 0, 2) + days * _microsPerDay,
          's1',
        ),
      ];
      final log = [...decline(2), ...decline(3), ...decline(4)];
      final card = deal(log, [parent, ...steps], at: _day(5, 10));
      expect(card!.id, isNot('s1'));
      expect(card.id, isNot('s2'));
      expect(
        card.id,
        isNot('cap-focus'),
        reason:
            'the parent retired with its pending steps — one '
            'atomic derivation, silently',
      );
      expect(card.id, 'zona-z1-a');
    });

    test('a SHIPPED parent\'s conversion carries its day — the FR-7 '
        'walk resolves the catalogue\'s own size for the superseded '
        'card, and the day composes no new chunk behind the chain '
        '(the capture-parent pin\'s fact-less twin)', () {
      final steps = [
        _stepFact(
          's1',
          utcMicros(2026, 8, 28, 9),
          'zona-z1-a',
          line: 'Paso uno',
        ),
        _stepFact(
          's2',
          utcMicros(2026, 8, 28, 9),
          'zona-z1-a',
          line: 'Paso dos',
        ),
      ];
      // No parent fact exists — a shipped entry. The conversion: the
      // Friday chunk dealt, superseded by the slice_returned, the
      // head step dealt in its place.
      final log = [
        _sessionStarted(utcMicros(2026, 8, 28, 10)),
        _dealt(utcMicros(2026, 8, 28, 10, 0, 1), 'zona-z1-a'),
        _sliceRow(
          LogKind.sliceReturned,
          utcMicros(2026, 8, 28, 10, 0, 2),
          'zona-z1-a',
          origin: Origin.shipped,
        ),
        _captureDealt(utcMicros(2026, 8, 28, 10, 0, 3), 's1'),
      ];
      final facts = walkLog(log, catalogue: _catalogue, poolFacts: steps);
      expect(
        facts.focusSlotCarriedDays,
        {const Calendar().dayOf(utcMicros(2026, 8, 28, 12), 0)},
        reason:
            'the shipped chunk\'s own focus size resolved through '
            'the walk\'s catalogue arm — the day\'s "1" is carried',
      );
      // And behind the standing head step, Friday composes no new
      // chunk.
      final friday = composeDay(
        catalogue: _catalogue,
        log: log,
        instantUtcMicros: utcMicros(2026, 8, 28, 11),
        offsetSeconds: 0,
        poolFacts: steps,
      );
      expect(friday.focus, isNull);
    });

    test('a SHIPPED parent whose chain completed never re-deals — the '
        'catalogue-side supersede filter holds where no capture fact '
        'exists to hold it, and no synthetic card_done names the '
        'parent (AD-25)', () {
      final steps = [
        _stepFact(
          's1',
          utcMicros(2026, 8, 28, 9),
          'zona-z1-a',
          line: 'Paso uno',
        ),
        _stepFact(
          's2',
          utcMicros(2026, 8, 28, 9),
          'zona-z1-a',
          line: 'Paso dos',
        ),
      ];
      final log = [
        _sessionStarted(utcMicros(2026, 8, 28, 10)),
        _sliceRow(
          LogKind.sliceReturned,
          utcMicros(2026, 8, 28, 10, 0, 1),
          'zona-z1-a',
          origin: Origin.shipped,
        ),
        _captureDealt(utcMicros(2026, 8, 28, 10, 0, 2), 's1'),
        _captureDone(utcMicros(2026, 8, 28, 10, 0, 3), 's1'),
        _captureDealt(utcMicros(2026, 8, 28, 10, 0, 4), 's2'),
        _captureDone(utcMicros(2026, 8, 28, 10, 0, 5), 's2'),
      ];
      final facts = walkLog(log, catalogue: _catalogue, poolFacts: steps);
      expect(
        facts.answeredItemIds,
        isNot(contains('zona-z1-a')),
        reason: 'done by derivation only — completion counts user acts',
      );
      // The completion closed Friday's slot AND the parent is
      // superseded: the next deal is upkeep, never the shipped parent
      // the zone tier would otherwise re-offer.
      final card = deal(log, steps);
      expect(
        card!.id,
        isNot('zona-z1-a'),
        reason:
            'the _resolveDay filter, not the capture source\'s '
            'own fold, is what retires a fact-less parent',
      );
      expect(card.id, 'man-a');
    });

    test('a SHIPPED parent whose chain dissolved never re-deals — the '
        'zone tier re-ranks past it to the next entry, never back to '
        'the refused thing', () {
      final steps = [
        _stepFact(
          's1',
          utcMicros(2026, 8, 26, 9),
          'zona-z1-a',
          line: 'Paso uno',
        ),
      ];
      List<LogEntry> decline(int days) => [
        _sessionStarted(_day(days, 10)),
        _captureDealt(
          utcMicros(2026, 8, 24, 10, 0, 1) + days * _microsPerDay,
          's1',
        ),
        _captureSkipped(
          utcMicros(2026, 8, 24, 10, 0, 2) + days * _microsPerDay,
          's1',
        ),
      ];
      final log = [...decline(2), ...decline(3), ...decline(4)];
      final card = deal(log, steps, at: _day(5, 10));
      expect(card!.id, isNot('s1'));
      expect(
        card.id,
        isNot('zona-z1-a'),
        reason:
            'the dissolved shipped parent is retired by the '
            'catalogue-side supersede filter alone',
      );
      expect(
        card.id,
        'zona-z1-b',
        reason:
            'the zone tier re-ranks to the next never-answered '
            'entry — never-dealt, focus-sized, the chunk the open '
            'sitting composes',
      );
    });

    test('a conversion followed by a dissolution blocks nothing — the '
        'past carried day has no consumer, and no future day\'s '
        'composition is held hostage by a chain that no longer exists', () {
      final steps = [
        _stepFact(
          's1',
          utcMicros(2026, 8, 28, 9),
          'zona-z1-a',
          line: 'Paso uno',
        ),
        _stepFact(
          's2',
          utcMicros(2026, 8, 28, 9),
          'zona-z1-a',
          line: 'Paso dos',
        ),
      ];
      // Friday: the conversion carries the day, the head step stands.
      final friday = [
        _sessionStarted(utcMicros(2026, 8, 28, 10)),
        _dealt(utcMicros(2026, 8, 28, 10, 0, 1), 'zona-z1-a'),
        _sliceRow(
          LogKind.sliceReturned,
          utcMicros(2026, 8, 28, 10, 0, 2),
          'zona-z1-a',
          origin: Origin.shipped,
        ),
        _captureDealt(utcMicros(2026, 8, 28, 10, 0, 3), 's1'),
        _sessionEnded(utcMicros(2026, 8, 28, 10, 0, 4)),
      ];
      // Saturday through Monday: the chain declines on three distinct
      // eligible days and dissolves.
      List<LogEntry> decline(int days) => [
        _sessionStarted(_day(days, 10)),
        _captureDealt(
          utcMicros(2026, 8, 24, 10, 0, 1) + days * _microsPerDay,
          's1',
        ),
        _captureSkipped(
          utcMicros(2026, 8, 24, 10, 0, 2) + days * _microsPerDay,
          's1',
        ),
        _sessionEnded(utcMicros(2026, 8, 24, 10, 0, 3) + days * _microsPerDay),
      ];
      final log = [...friday, ...decline(5), ...decline(6), ...decline(7)];
      final facts = walkLog(log, catalogue: _catalogue, poolFacts: steps);
      expect(facts.focusSlotCarriedDays, {
        const Calendar().dayOf(utcMicros(2026, 8, 28, 12), 0),
      }, reason: 'the statement of history stands — Friday was carried');
      // Tuesday (day 8): a fresh sitting composes a chunk as any
      // untouched day would — the carried day is behind, the chain is
      // gone, and the superseded parent stays retired. The new week's
      // own active zone (z2 — the ring advanced Monday) is itself
      // witness that nothing of the dead chain constrains the weave.
      final tuesday = [...log, _sessionStarted(_day(8, 10))];
      final composition = composeDay(
        catalogue: _catalogue,
        log: tuesday,
        instantUtcMicros: _day(8, 11),
        offsetSeconds: 0,
        poolFacts: steps,
      );
      expect(
        composition.focus,
        isNotNull,
        reason: 'no future day\'s composition is blocked',
      );
      expect(composition.focus!.id, 'zona-z2-a');
      final card = deal(tuesday, steps, at: _day(8, 11));
      expect(card!.id, isNot('s1'));
      expect(card.id, isNot('s2'));
      expect(card.id, isNot('zona-z1-a'));
      expect(card.id, 'zona-z2-a');
    });
  });
}

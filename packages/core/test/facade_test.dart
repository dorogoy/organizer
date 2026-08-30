import 'dart:io';

import 'package:core/catalogue/catalogue.dart';
import 'package:core/commands/session_commands.dart';
import 'package:core/facade/read_facade.dart';
import 'package:core/log/log_entry.dart';
import 'package:core/ports/store_port.dart';
import 'package:core/pool/pool_fact.dart';
import 'package:core/weave/weave.dart';
import 'package:test/test.dart';

import 'test_util.dart';

/// A stand-in store holding inert records, proving the facade reads only
/// through the port and writes never (AD-3, AD-6).
class _FakeStore implements StorePort {
  _FakeStore([List<LogEntryRecord>? seeded]) : _records = [...?seeded];

  final List<LogEntryRecord> _records;
  int appends = 0;

  @override
  Future<void> appendPoolFact(PoolFactRecord fact) async => appends++;

  @override
  Future<void> appendLogEntry(LogEntryRecord entry) async => appends++;

  @override
  Future<List<PoolFactRecord>> readPoolFacts() async => const [];

  @override
  Future<List<LogEntryRecord>> readLogEntries() async =>
      List.unmodifiable(_records);
}

LogEntryRecord _record(
  String kind,
  int micros, {
  String id = 'r',
  String? itemId,
  Origin? itemOrigin,
  String? stack,
  String? settingKey,
  int? settingValue,
}) => (
  id: '$id-$micros-$kind',
  kind: kind,
  instantUtcMicros: micros,
  offsetSeconds: 0,
  itemId: itemId,
  itemOrigin: itemOrigin,
  stack: stack,
  settingKey: settingKey,
  settingValue: settingValue,
);
final Catalogue _catalogue = Catalogue(
  version: 1,
  entries: const [
    CatalogueEntry(
      id: 'zona-a',
      size: Size.focus,
      cadence: Cadence.weekly,
      zone: Zone.z1,
      name: 'Tarea de zona-a',
    ),
    CatalogueEntry(
      id: 'man-a',
      size: Size.maintenance,
      cadence: Cadence.daily,
      name: 'Tarea de man-a',
    ),
    CatalogueEntry(
      id: 'hab-a',
      size: Size.instant,
      cadence: Cadence.daily,
      name: 'Tarea de hab-a',
    ),
  ],
);

void main() {
  final now = utcMicros(2026, 8, 28, 12);
  test(
    'a fresh store yields the resolver\'s next card, one card only',
    () async {
      final store = _FakeStore();
      final card = await nextCard(
        store,
        catalogue: _catalogue,
        instantUtcMicros: now,
        offsetSeconds: 0,
      );
      expect(card, isNotNull);
      expect(card!.id, 'zona-a');
      expect(card.size, Size.focus);
      expect(card.name, 'Tarea de zona-a');
      expect(card.origin, Origin.shipped);
      expect(card.estimateSeconds, focusEstimateSeconds);
      expect(store.appends, 0);
    },
  );

  group('seeded setting_changed rows drive composition (Story 2.1, FR-7)', () {
    LogEntryRecord bag(int micros, int minutes) => _record(
      LogKind.settingChanged.name,
      micros,
      settingKey: 'time_bag',
      settingValue: minutes,
    );

    test('a derived bag below 10 composes no Focus Chunk, silently — '
        'upkeep leads the day and nothing names the absence', () async {
      final store = _FakeStore([bag(utcMicros(2026, 8, 28, 8), 5)]);
      final card = await nextCard(
        store,
        catalogue: _catalogue,
        instantUtcMicros: now,
        offsetSeconds: 0,
      );
      expect(card, isNotNull);
      expect(card!.id, 'man-a');
      expect(card.size, Size.maintenance);
      expect(store.appends, 0);
    });

    test('a derived bag at the weave\'s floor composes the chunk; the '
        'facade derives from its own read, no parameter passed', () async {
      final raised = await nextCard(
        _FakeStore([bag(utcMicros(2026, 8, 28, 8), 10)]),
        catalogue: _catalogue,
        instantUtcMicros: now,
        offsetSeconds: 0,
      );
      expect(raised!.id, 'zona-a');

      final defaulted = await nextCard(
        _FakeStore([bag(utcMicros(2026, 8, 28, 8), 15)]),
        catalogue: _catalogue,
        instantUtcMicros: now,
        offsetSeconds: 0,
      );
      expect(defaulted!.id, 'zona-a');
    });

    test('a raise from below 10 to 10-or-more composes a Focus Chunk iff '
        'the slot is open and none was dealt that day (AD-20)', () async {
      // Raised across the floor: the only effect of the raise is opening
      // the below-10 gate; occupancy then follows the standing facts.
      final open = await nextCard(
        _FakeStore([
          bag(utcMicros(2026, 8, 28, 8), 5),
          bag(utcMicros(2026, 8, 28, 9), 20),
        ]),
        catalogue: _catalogue,
        instantUtcMicros: now,
        offsetSeconds: 0,
      );
      expect(open!.id, 'zona-a');

      // The closed slot: the day's chunk was answered Hecho earlier
      // (bag 15), then the bag moved 5 → 20. A closed slot never
      // re-opens, raise or no raise.
      final closed = await nextCard(
        _FakeStore([
          bag(utcMicros(2026, 8, 28, 8), 15),
          _record(
            LogKind.sessionStarted.name,
            utcMicros(2026, 8, 28, 9),
            id: 'open',
          ),
          _record(
            LogKind.cardDealt.name,
            utcMicros(2026, 8, 28, 9, 0, 1),
            itemId: 'zona-a',
            itemOrigin: Origin.shipped,
          ),
          _record(
            LogKind.cardDone.name,
            utcMicros(2026, 8, 28, 9, 0, 2),
            itemId: 'zona-a',
            itemOrigin: Origin.shipped,
          ),
          _record(LogKind.sessionEnded.name, utcMicros(2026, 8, 28, 9, 0, 3)),
          bag(utcMicros(2026, 8, 28, 10), 5),
          bag(utcMicros(2026, 8, 28, 11), 20),
        ]),
        catalogue: _catalogue,
        instantUtcMicros: now,
        offsetSeconds: 0,
      );
      expect(closed!.id, 'man-a', reason: 'a closed slot never re-opens');

      // The skipped chunk: a skip leaves the slot open with re-ranking,
      // so the raise's composition deals a chunk again — standing slot
      // mechanics, not a new gate.
      final skipped = await nextCard(
        _FakeStore([
          _record(
            LogKind.sessionStarted.name,
            utcMicros(2026, 8, 28, 9),
            id: 'open',
          ),
          _record(
            LogKind.cardDealt.name,
            utcMicros(2026, 8, 28, 9, 0, 1),
            itemId: 'zona-a',
            itemOrigin: Origin.shipped,
          ),
          _record(
            LogKind.cardSkipped.name,
            utcMicros(2026, 8, 28, 9, 0, 2),
            itemId: 'zona-a',
            itemOrigin: Origin.shipped,
          ),
          _record(LogKind.sessionEnded.name, utcMicros(2026, 8, 28, 9, 0, 3)),
          bag(utcMicros(2026, 8, 28, 10), 5),
          bag(utcMicros(2026, 8, 28, 11), 20),
        ]),
        catalogue: _catalogue,
        instantUtcMicros: now,
        offsetSeconds: 0,
      );
      expect(
        skipped!.size,
        Size.focus,
        reason: 'the skip consumed no rotation and closed nothing',
      );
    });

    test('a later same-day session after the chunk\'s Hecho composes '
        'upkeep only, at any bag — chaining cannot multiply advance '
        '(FR-7)', () async {
      for (final minutes in [5, 15, 30]) {
        final card = await nextCard(
          _FakeStore([
            bag(utcMicros(2026, 8, 28, 8), minutes),
            _record(
              LogKind.sessionStarted.name,
              utcMicros(2026, 8, 28, 9),
              id: 'open',
            ),
            _record(
              LogKind.cardDealt.name,
              utcMicros(2026, 8, 28, 9, 0, 1),
              itemId: 'zona-a',
              itemOrigin: Origin.shipped,
            ),
            _record(
              LogKind.cardDone.name,
              utcMicros(2026, 8, 28, 9, 0, 2),
              itemId: 'zona-a',
              itemOrigin: Origin.shipped,
            ),
            _record(LogKind.sessionEnded.name, utcMicros(2026, 8, 28, 9, 0, 3)),
            _record(
              LogKind.sessionStarted.name,
              utcMicros(2026, 8, 28, 11),
              id: 'second',
            ),
          ]),
          catalogue: _catalogue,
          instantUtcMicros: now,
          offsetSeconds: 0,
        );
        expect(card!.id, 'man-a', reason: 'bag $minutes: upkeep only');
        expect(card.size, isNot(Size.focus));
      }
    });

    test('a mid-day change keeps prior answers — the answered chunk stays '
        'answered and the derivation moves forward only (AD-20)', () async {
      final rows = <LogEntryRecord>[
        _record(
          LogKind.sessionStarted.name,
          utcMicros(2026, 8, 28, 9),
          id: 'open',
        ),
        _record(
          LogKind.cardDealt.name,
          utcMicros(2026, 8, 28, 9, 0, 1),
          itemId: 'zona-a',
          itemOrigin: Origin.shipped,
        ),
        _record(
          LogKind.cardDone.name,
          utcMicros(2026, 8, 28, 9, 0, 2),
          itemId: 'zona-a',
          itemOrigin: Origin.shipped,
        ),
        _record(LogKind.sessionEnded.name, utcMicros(2026, 8, 28, 9, 0, 3)),
      ];
      final store = _FakeStore(rows);
      final before = await nextCard(
        store,
        catalogue: _catalogue,
        instantUtcMicros: now,
        offsetSeconds: 0,
      );
      expect(before!.id, 'man-a');

      // The mid-day change appends one row after the answers; the
      // answers derive exactly as they did.
      rows.add(bag(utcMicros(2026, 8, 28, 12), 30));
      final after = await nextCard(
        store,
        catalogue: _catalogue,
        instantUtcMicros: now,
        offsetSeconds: 0,
      );
      expect(after!.id, 'man-a');
      expect(store.appends, 0, reason: 'the read changed nothing');
    });

    test('an out-of-range or unknown-key setting row derives as absent — '
        'previous value or default (AD-23)', () async {
      final invalid = await nextCard(
        _FakeStore([
          _record(
            LogKind.settingChanged.name,
            utcMicros(2026, 8, 28, 8),
            settingKey: 'time_bag',
            settingValue: 45,
          ),
        ]),
        catalogue: _catalogue,
        instantUtcMicros: now,
        offsetSeconds: 0,
      );
      expect(invalid!.id, 'zona-a', reason: 'the default 15 stands');

      final unknownKey = await nextCard(
        _FakeStore([
          _record(
            LogKind.settingChanged.name,
            utcMicros(2026, 8, 28, 8),
            settingKey: 'future_setting',
            settingValue: 5,
          ),
        ]),
        catalogue: _catalogue,
        instantUtcMicros: now,
        offsetSeconds: 0,
      );
      expect(unknownKey!.id, 'zona-a');
    });

    test('the threaded command path derives the bag too: sessionStart over '
        'a seeded below-10 bag opens on upkeep, not the chunk', () async {
      final store = _FakeStore([bag(utcMicros(2026, 8, 28, 8), 5)]);
      final log = logEntriesOf(await store.readLogEntries());
      final contents = sessionStart(
        catalogue: _catalogue,
        log: log,
        instantUtcMicros: now,
        offsetSeconds: 0,
      );
      expect(contents, hasLength(2));
      expect(contents[0].kind, LogKind.sessionStarted);
      expect(contents[1].kind, LogKind.cardDealt);
      expect(contents[1].itemId, 'man-a');
      expect(store.appends, 0, reason: 'the command writes nothing');
    });
  });

  test('a dealt card never answered renders again as the same card, and no '
      'second card_dealt appears (AD-3)', () async {
    final store = _FakeStore([
      _record(
        LogKind.sessionStarted.name,
        utcMicros(2026, 8, 28, 10),
        id: 'open',
      ),
      _record(
        LogKind.cardDealt.name,
        utcMicros(2026, 8, 28, 10, 0, 1),
        itemId: 'man-a',
        itemOrigin: Origin.shipped,
      ),
    ]);
    final first = await nextCard(
      store,
      catalogue: _catalogue,
      instantUtcMicros: now,
      offsetSeconds: 0,
    );
    final second = await nextCard(
      store,
      catalogue: _catalogue,
      instantUtcMicros: now,
      offsetSeconds: 0,
    );
    expect(first!.id, 'man-a');
    expect(second, first);
    expect(store.appends, 0, reason: 'nextCard writes nothing');
  });

  test('malformed rows are excluded and unknown kinds carried — the '
      'composition never crashes (AD-23)', () async {
    final store = _FakeStore([
      _record(
        LogKind.sessionStarted.name,
        utcMicros(2026, 8, 28, 10),
        id: 'open',
      ),
      // Half item pair: excluded from every derivation.
      _record(
        LogKind.cardDone.name,
        utcMicros(2026, 8, 28, 10, 0, 1),
        itemId: 'man-a',
      ),
      // stack on a moment kind: excluded.
      _record(
        LogKind.appOpened.name,
        utcMicros(2026, 8, 28, 10, 0, 2),
        stack: '#0      build',
      ),
      // Unknown kind: carried, ignored.
      _record('future_kind', utcMicros(2026, 8, 28, 10, 0, 3)),
      _record(
        LogKind.cardDealt.name,
        utcMicros(2026, 8, 28, 10, 0, 4),
        itemId: 'hab-a',
        itemOrigin: Origin.shipped,
      ),
    ]);
    final card = await nextCard(
      store,
      catalogue: _catalogue,
      instantUtcMicros: now,
      offsetSeconds: 0,
    );
    expect(card!.id, 'hab-a');
    expect(store.appends, 0);
  });

  test('the facade\'s shape is a single-card surface: one function, no '
      'collection-returning function anywhere in the library (AD-6)', () {
    final source = File('lib/facade/read_facade.dart').readAsStringSync();
    expect(source, contains('Future<Card?> nextCard('));
    expect(
      RegExp(r'\b(List|Set|Map|Iterable|Collection)\s*<').allMatches(source),
      isEmpty,
      reason:
          'the read facade exposes no collection of work items — the one '
          'work surface is nextCard(), returning at most one card',
    );
    expect(
      source,
      isNot(contains('=> List')),
      reason: 'no function here hands out a collection of any kind',
    );
  });
}

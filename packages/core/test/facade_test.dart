import 'dart:io';

import 'package:core/catalogue/catalogue.dart';
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
}) => (
  id: '$id-$micros-$kind',
  kind: kind,
  instantUtcMicros: micros,
  offsetSeconds: 0,
  itemId: itemId,
  itemOrigin: itemOrigin,
  stack: stack,
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

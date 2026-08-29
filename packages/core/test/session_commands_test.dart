import 'package:core/catalogue/catalogue.dart';
import 'package:core/commands/session_commands.dart';
import 'package:core/log/log_entry.dart';
import 'package:core/pool/pool_fact.dart';
import 'package:core/weave/weave.dart';
import 'package:test/test.dart';

import 'test_util.dart';

CatalogueEntry _catalogueEntry(
  String id,
  Size size,
  Cadence cadence, {
  Zone? zone,
}) => CatalogueEntry(
  id: id,
  size: size,
  cadence: cadence,
  zone: zone,
  name: 'Tarea de $id',
);

final Catalogue _catalogue = Catalogue(
  version: 1,
  entries: [
    _catalogueEntry('zona-a', Size.focus, Cadence.weekly, zone: Zone.z1),
    for (final id in ['man-a', 'man-b', 'man-c'])
      _catalogueEntry(id, Size.maintenance, Cadence.daily),
    for (final id in ['hab-a', 'hab-b', 'hab-c', 'hab-d', 'hab-e'])
      _catalogueEntry(id, Size.instant, Cadence.daily),
  ],
);

MomentEntry _started(int micros) => MomentEntry(
  id: 'started-$micros',
  instantUtcMicros: micros,
  offsetSeconds: 0,
  kind: LogKind.sessionStarted,
);

MomentEntry _ended(int micros) => MomentEntry(
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

/// The exhausted day: the chunk answered, all three maintenance draws
/// and all five habit draws dealt and answered. With [finalHabitOpen]
/// the last habit draw is left dealt-but-unanswered and the session
/// stays open; with it answered the session closes.
List<LogEntry> _exhaustedDay({required bool finalHabitOpen}) {
  final log = <LogEntry>[
    _started(utcMicros(2026, 8, 28, 10)),
    _dealt(utcMicros(2026, 8, 28, 10, 0, 1), 'zona-a'),
    _done(utcMicros(2026, 8, 28, 10, 0, 2), 'zona-a'),
  ];
  var step = 0;
  int at() => utcMicros(2026, 8, 28, 10, ++step);
  for (final id in ['man-a', 'man-b', 'man-c']) {
    log
      ..add(_dealt(at(), id))
      ..add(_done(at(), id));
  }
  for (final id in ['hab-a', 'hab-b', 'hab-c', 'hab-d']) {
    log
      ..add(_dealt(at(), id))
      ..add(_done(at(), id));
  }
  log.add(_dealt(at(), 'hab-e'));
  if (finalHabitOpen) {
    return log;
  }
  log.add(_done(at(), 'hab-e'));
  return [...log, _ended(at())];
}

void main() {
  final now = utcMicros(2026, 8, 28, 12);

  test('a session starting on an exhausted day opens bare — exactly '
      '[session_started], no deal', () {
    final contents = sessionStart(
      catalogue: _catalogue,
      log: _exhaustedDay(finalHabitOpen: false),
      instantUtcMicros: now,
      offsetSeconds: 0,
    );
    expect(contents, hasLength(1));
    expect(contents.single.kind, LogKind.sessionStarted);
    expect(contents.single.itemId, isNull);
  });

  test('answering the final habit draw of an exhausted day appends only the '
      'answer row — there is nothing left to deal', () {
    final log = _exhaustedDay(finalHabitOpen: true);
    final done = cardDone(
      itemId: 'hab-e',
      origin: Origin.shipped,
      catalogue: _catalogue,
      log: log,
      instantUtcMicros: now,
      offsetSeconds: 0,
    );
    expect(done, hasLength(1));
    expect(done.single.kind, LogKind.cardDone);
    expect(done.single.itemId, 'hab-e');
    expect(done.single.itemOrigin, Origin.shipped);

    final skipped = cardSkipped(
      itemId: 'hab-e',
      origin: Origin.shipped,
      catalogue: _catalogue,
      log: log,
      instantUtcMicros: now,
      offsetSeconds: 0,
    );
    expect(skipped, hasLength(1));
    expect(skipped.single.kind, LogKind.cardSkipped);
    expect(skipped.single.itemId, 'hab-e');
  });

  test('a duplicate Hecho appends nothing — the card is already answered', () {
    final contents = cardDone(
      itemId: 'hab-e',
      origin: Origin.shipped,
      catalogue: _catalogue,
      log: _exhaustedDay(finalHabitOpen: false),
      instantUtcMicros: now,
      offsetSeconds: 0,
    );
    expect(contents, isEmpty);
  });

  test('a Hecho naming an item never dealt appends nothing: no slot closes, '
      'the standing deal composes upkeep only (AD-3), and the slot proves '
      'open once the session closes', () {
    final log = [
      _started(utcMicros(2026, 8, 28, 10)),
      _dealt(utcMicros(2026, 8, 28, 10, 0, 1), 'zona-a'),
    ];
    final contents = cardDone(
      itemId: 'zona-b',
      origin: Origin.shipped,
      catalogue: _catalogue,
      log: log,
      instantUtcMicros: now,
      offsetSeconds: 0,
    );
    expect(contents, isEmpty);
    // Nothing was appended: the dealt-but-unanswered card stands, so
    // the day composes upkeep and habits only (AD-3) — the foreign
    // Hecho closed no slot and consumed nothing.
    final composition = composeDay(
      catalogue: _catalogue,
      log: log,
      instantUtcMicros: now,
      offsetSeconds: 0,
    );
    expect(composition.focus, isNull);
    expect(composition.maintenance, hasLength(3));
    expect(composition.instantHabits, hasLength(5));
    // Once the session closes, the slot proves still open: the zone's
    // entry resolves again.
    final afterClose = composeDay(
      catalogue: _catalogue,
      log: [...log, _ended(utcMicros(2026, 8, 28, 10, 30))],
      instantUtcMicros: now,
      offsetSeconds: 0,
    );
    expect(afterClose.focus!.id, 'zona-a');
  });

  test(
    'a Hecho naming the right id under a foreign origin appends nothing',
    () {
      final contents = cardDone(
        itemId: 'zona-a',
        origin: Origin.manual,
        catalogue: _catalogue,
        log: [
          _started(utcMicros(2026, 8, 28, 10)),
          _dealt(utcMicros(2026, 8, 28, 10, 0, 1), 'zona-a'),
        ],
        instantUtcMicros: now,
        offsetSeconds: 0,
      );
      expect(
        contents,
        isEmpty,
        reason: 'the answer must name the dealt card\'s (id, origin) pair',
      );
    },
  );

  test('sessionStart with a session already open, and sessionEnd with none '
      'open, append nothing', () {
    final open = [
      _started(utcMicros(2026, 8, 28, 10)),
      _dealt(utcMicros(2026, 8, 28, 10, 0, 1), 'zona-a'),
    ];
    expect(
      sessionStart(
        catalogue: _catalogue,
        log: open,
        instantUtcMicros: now,
        offsetSeconds: 0,
      ),
      isEmpty,
    );
    expect(sessionEnd(log: open), isNotEmpty);
    expect(sessionEnd(log: _exhaustedDay(finalHabitOpen: false)), isEmpty);
  });
}

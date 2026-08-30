import 'package:core/catalogue/catalogue.dart';
import 'package:core/commands/session_commands.dart';
import 'package:core/log/log_entry.dart';
import 'package:core/pool/pool_fact.dart';
import 'package:core/weave/weave.dart';
import 'package:core/settings/settings.dart';
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

SessionStartEntry _started(int micros, {int? pocketMinutes}) =>
    SessionStartEntry(
      id: 'started-$micros',
      instantUtcMicros: micros,
      offsetSeconds: 0,
      kind: LogKind.sessionStarted,
      pocketMinutes: pocketMinutes,
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

/// The fixture catalogue's size for an item id.
Size _sizeOf(String itemId) =>
    _catalogue.entries.firstWhere((entry) => entry.id == itemId).size;

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

  group('the answer path derives the bag for its bundled next deal '
      '(2.1 — the one place the bag meets the bundled card_dealt)', () {
    SettingEntry bag(int micros, int minutes) => SettingEntry(
      id: 'bag-$micros-$minutes',
      instantUtcMicros: micros,
      offsetSeconds: 0,
      key: timeBagSettingKey,
      value: minutes,
    );

    Size sizeOf(String itemId) => _sizeOf(itemId);

    test('cardSkipped with a seeded below-10 bag bundles a non-focus next '
        'deal — the skip left the slot open, the bag closes the gate '
        '(FR-7)', () {
      final log = [
        bag(utcMicros(2026, 8, 28, 9), 5),
        _started(utcMicros(2026, 8, 28, 10)),
        _dealt(utcMicros(2026, 8, 28, 10, 0, 1), 'zona-a'),
      ];
      final contents = cardSkipped(
        itemId: 'zona-a',
        origin: Origin.shipped,
        catalogue: _catalogue,
        log: log,
        instantUtcMicros: now,
        offsetSeconds: 0,
      );
      expect(contents, hasLength(2));
      expect(contents.first.kind, LogKind.cardSkipped);
      expect(contents.last.kind, LogKind.cardDealt);
      // With the derivation reverted to the default 15 the bundled deal
      // would be the chunk again (the skip consumed nothing) — this pin
      // is what fails.
      expect(sizeOf(contents.last.itemId!), isNot(Size.focus));
    });

    test('cardDone on the focus card with a seeded below-10 bag bundles '
        'upkeep — the slot is closed and the gate is closed (FR-7)', () {
      final log = [
        bag(utcMicros(2026, 8, 28, 9), 5),
        _started(utcMicros(2026, 8, 28, 10)),
        _dealt(utcMicros(2026, 8, 28, 10, 0, 1), 'zona-a'),
      ];
      final contents = cardDone(
        itemId: 'zona-a',
        origin: Origin.shipped,
        catalogue: _catalogue,
        log: log,
        instantUtcMicros: now,
        offsetSeconds: 0,
      );
      expect(contents, hasLength(2));
      expect(contents.first.kind, LogKind.cardDone);
      expect(contents.last.kind, LogKind.cardDealt);
      expect(sizeOf(contents.last.itemId!), isNot(Size.focus));
    });

    test('cardDone on an upkeep card with a seeded below-10 bag bundles '
        'another upkeep draw — no chunk composes behind the answer '
        '(FR-7, FR-12)', () {
      final log = [
        bag(utcMicros(2026, 8, 28, 9), 5),
        _started(utcMicros(2026, 8, 28, 10)),
        _dealt(utcMicros(2026, 8, 28, 10, 0, 1), 'man-a'),
      ];
      final contents = cardDone(
        itemId: 'man-a',
        origin: Origin.shipped,
        catalogue: _catalogue,
        log: log,
        instantUtcMicros: now,
        offsetSeconds: 0,
      );
      expect(contents, hasLength(2));
      // With the derivation reverted to the default 15 the next deal
      // would be the day's chunk (zona-a) — this pin is what fails.
      expect(sizeOf(contents.last.itemId!), isNot(Size.focus));
    });
  });

  group('the declare tap (Story 2.2, FR-8, AD-19)', () {
    test('declaring from idle starts a pocketed session with a deal that '
        'fits the pocket', () {
      final contents = sessionDeclare(
        catalogue: _catalogue,
        log: const [],
        pocketMinutes: 15,
        instantUtcMicros: now,
        offsetSeconds: 0,
      );
      expect(contents.map((content) => content.kind).toList(), [
        LogKind.sessionStarted,
        LogKind.cardDealt,
      ]);
      expect(contents.first.pocketMinutes, 15);
      expect(_sizeOf(contents.last.itemId!), Size.focus);

      // A pocket the chunk cannot hold deals beneath it — the sitting's
      // very first card is bounded.
      final narrow = sessionDeclare(
        catalogue: _catalogue,
        log: const [],
        pocketMinutes: 4,
        instantUtcMicros: now,
        offsetSeconds: 0,
      );
      expect(narrow.map((content) => content.kind).toList(), [
        LogKind.sessionStarted,
        LogKind.cardDealt,
      ]);
      expect(_sizeOf(narrow.last.itemId!), isNot(Size.focus));
    });

    test('declaring with a card in progress supersedes and carries it: '
        '[session_ended, session_started{p}], no bundled deal — the same '
        'card stays answerable (AD-19, EXPERIENCE §components)', () {
      final log = [
        _started(utcMicros(2026, 8, 28, 10)),
        _dealt(utcMicros(2026, 8, 28, 10, 0, 1), 'zona-a'),
      ];
      final contents = sessionDeclare(
        catalogue: _catalogue,
        log: log,
        pocketMinutes: 5,
        instantUtcMicros: now,
        offsetSeconds: 0,
      );
      expect(contents.map((content) => content.kind).toList(), [
        LogKind.sessionEnded,
        LogKind.sessionStarted,
      ]);
      expect(contents.last.pocketMinutes, 5);
      // No bundled deal while a card is carried — and its later Hecho
      // consumes the new pocket: a 15-minute chunk under a 5-minute
      // pocket honestly spends it (the next deal resolves null).
      final declaredLog = [
        ...log,
        _ended(now),
        _started(now, pocketMinutes: 5),
      ];
      final done = cardDone(
        itemId: 'zona-a',
        origin: Origin.shipped,
        catalogue: _catalogue,
        log: declaredLog,
        instantUtcMicros: now + 1000,
        offsetSeconds: 0,
      );
      expect(done, hasLength(1));
      expect(done.single.kind, LogKind.cardDone);
    });

    test('re-declaring over an open pocketed session supersedes again: '
        'consumption restarts at zero', () {
      final log = [
        _started(utcMicros(2026, 8, 28, 10), pocketMinutes: 15),
        _dealt(utcMicros(2026, 8, 28, 10, 0, 1), 'man-a'),
        _done(utcMicros(2026, 8, 28, 10, 0, 2), 'man-a'),
      ];
      final contents = sessionDeclare(
        catalogue: _catalogue,
        log: log,
        pocketMinutes: 20,
        instantUtcMicros: now,
        offsetSeconds: 0,
      );
      // No card stands, so the pair carries nothing and the fresh
      // session's first deal may bundle.
      expect(contents.map((content) => content.kind).toList(), [
        LogKind.sessionEnded,
        LogKind.sessionStarted,
        LogKind.cardDealt,
      ]);
      expect(contents[1].pocketMinutes, 20);
      // The new deal fits the restarted sitting: the chunk (15) fits
      // 20 fresh minutes even though 3 were answered under the old
      // pocket.
      expect(_sizeOf(contents.last.itemId!), Size.focus);
    });

    test('an out-of-range pocket returns no content — the command '
        'boundary\'s guard, nothing appended, unreachable from the ladder', () {
      for (final refused in [0, -1, 61, 90]) {
        expect(
          sessionDeclare(
            catalogue: _catalogue,
            log: [
              _started(utcMicros(2026, 8, 28, 10)),
              _dealt(utcMicros(2026, 8, 28, 10, 0, 1), 'zona-a'),
            ],
            pocketMinutes: refused,
            instantUtcMicros: now,
            offsetSeconds: 0,
          ),
          isEmpty,
          reason: 'pocket $refused is outside 1–60',
        );
      }
      // The range edges themselves mint.
      for (final minted in [1, 60]) {
        expect(
          sessionDeclare(
            catalogue: _catalogue,
            log: const [],
            pocketMinutes: minted,
            instantUtcMicros: now,
            offsetSeconds: 0,
          ).first.pocketMinutes,
          minted,
        );
      }
    });
  });

  group('the open\'s composition (Story 2.2, AD-19)', () {
    test('the normal case appends exactly the rows appOpened + '
        'sessionStart always did', () {
      final contents = appOpen(
        catalogue: _catalogue,
        log: const [],
        instantUtcMicros: now,
        offsetSeconds: 0,
      );
      expect(contents.map((content) => content.kind).toList(), [
        LogKind.appOpened,
        LogKind.sessionStarted,
        LogKind.cardDealt,
      ]);
      expect(contents[1].pocketMinutes, isNull);

      // An open session with no pocket appends only app_opened — the
      // session stays, unbounded and untouched.
      final reopened = appOpen(
        catalogue: _catalogue,
        log: [
          _started(utcMicros(2026, 8, 28, 10)),
          _dealt(utcMicros(2026, 8, 28, 10, 0, 1), 'zona-a'),
        ],
        instantUtcMicros: now,
        offsetSeconds: 0,
      );
      expect(reopened.map((content) => content.kind).toList(), [
        LogKind.appOpened,
      ]);
    });

    test('a pocket still within its span appends only app_opened — the '
        'reveal fires on elapse, never on presence', () {
      final start = utcMicros(2026, 8, 28, 11);
      final contents = appOpen(
        catalogue: _catalogue,
        log: [
          _started(start, pocketMinutes: 30),
          _dealt(start + 1000, 'zona-a'),
        ],
        instantUtcMicros: start + 10 * 60 * 1000 * 1000,
        offsetSeconds: 0,
      );
      expect(contents.map((content) => content.kind).toList(), [
        LogKind.appOpened,
      ]);
    });

    test('a pocket elapsed while the app was not foregrounded reveals at '
        'the open: [app_opened, session_ended, session_started, '
        'card_dealt?] — close first, then start (AD-19)', () {
      final start = utcMicros(2026, 8, 28, 10);
      final log = [
        _started(start, pocketMinutes: 15),
        _dealt(start + 1000, 'man-a'),
        _done(start + 2000, 'man-a'),
      ];
      final contents = appOpen(
        catalogue: _catalogue,
        log: log,
        // Forty minutes later — long past the 15-minute span.
        instantUtcMicros: start + 40 * 60 * 1000 * 1000,
        offsetSeconds: 0,
      );
      expect(contents.map((content) => content.kind).toList(), [
        LogKind.appOpened,
        LogKind.sessionEnded,
        LogKind.sessionStarted,
        LogKind.cardDealt,
      ]);
      // The fresh session is unbounded — the reveal closes and opens,
      // it never re-declares.
      expect(contents[2].pocketMinutes, isNull);
    });

    test('the reveal with a card carried suppresses the bundled deal — '
        'the pair rule carries in-progress work across the close, and '
        'its Hecho then answers under the fresh unbounded sitting', () {
      final start = utcMicros(2026, 8, 28, 10);
      final log = [
        _started(start, pocketMinutes: 15),
        _dealt(start + 1000, 'zona-a'),
      ];
      final contents = appOpen(
        catalogue: _catalogue,
        log: log,
        instantUtcMicros: start + 40 * 60 * 1000 * 1000,
        offsetSeconds: 0,
      );
      expect(contents.map((content) => content.kind).toList(), [
        LogKind.appOpened,
        LogKind.sessionEnded,
        LogKind.sessionStarted,
      ]);
      // The carried card stays answerable under the fresh session —
      // and the answer bundles its next deal, the sitting being
      // unbounded.
      final done = cardDone(
        itemId: 'zona-a',
        origin: Origin.shipped,
        catalogue: _catalogue,
        log: [
          ...log,
          _ended(start + 40 * 60 * 1000 * 1000),
          _started(start + 40 * 60 * 1000 * 1000),
        ],
        instantUtcMicros: start + 41 * 60 * 1000 * 1000,
        offsetSeconds: 0,
      );
      expect(done, hasLength(2));
      expect(done.first.kind, LogKind.cardDone);
      expect(done.last.kind, LogKind.cardDealt);
    });

    test('an unbounded session left open by process death never reveals '
        'closed — no pocket, no span (unbounded behaves as shipped)', () {
      final start = utcMicros(2026, 8, 28, 10);
      final contents = appOpen(
        catalogue: _catalogue,
        log: [_started(start), _dealt(start + 1000, 'man-a')],
        // Days later.
        instantUtcMicros: start + 48 * 60 * 60 * 1000 * 1000,
        offsetSeconds: 0,
      );
      expect(contents.map((content) => content.kind).toList(), [
        LogKind.appOpened,
      ]);
    });

    test('an out-of-range pocket row derives as absent: the open cannot '
        'reveal-close over it (AD-23)', () {
      final start = utcMicros(2026, 8, 28, 10);
      final contents = appOpen(
        catalogue: _catalogue,
        log: [
          _started(start, pocketMinutes: 90),
          _dealt(start + 1000, 'man-a'),
        ],
        instantUtcMicros: start + 40 * 60 * 60 * 1000 * 1000,
        offsetSeconds: 0,
      );
      expect(contents.map((content) => content.kind).toList(), [
        LogKind.appOpened,
      ]);
    });
  });
}

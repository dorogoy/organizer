import 'package:core/catalogue/catalogue.dart';
import 'package:core/day/calendar.dart';
import 'package:core/log/log_entry.dart';
import 'package:core/pool/pool_fact.dart';
import 'package:core/weave/session.dart';
import 'package:test/test.dart';

import 'test_util.dart';

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
    CatalogueEntry(
      id: 'hab-b',
      size: Size.instant,
      cadence: Cadence.daily,
      name: 'Tarea de hab-b',
    ),
  ],
);

SessionStartEntry _started(int micros, {String id = 's', int? pocketMinutes}) =>
    SessionStartEntry(
      id: '$id-$micros',
      instantUtcMicros: micros,
      offsetSeconds: 0,
      kind: LogKind.sessionStarted,
      pocketMinutes: pocketMinutes,
    );

MomentEntry _ended(int micros) => MomentEntry(
  id: 'e-$micros',
  instantUtcMicros: micros,
  offsetSeconds: 0,
  kind: LogKind.sessionEnded,
);

ItemActEntry _act(LogKind kind, int micros, String itemId) => ItemActEntry(
  id: 'a-$micros-$itemId',
  instantUtcMicros: micros,
  offsetSeconds: 0,
  kind: kind,
  itemId: itemId,
  itemOrigin: Origin.shipped,
);

void main() {
  test('the open session is the latest session_started with no matching '
      'session_ended (AD-19)', () {
    final first = _started(utcMicros(2026, 8, 27, 10), id: 'one');
    final close = _ended(utcMicros(2026, 8, 27, 11));
    final second = _started(utcMicros(2026, 8, 28, 9), id: 'two');

    final closed = walkLog([first, close], catalogue: _catalogue);
    expect(closed.openSessionStart, isNull);

    final reopened = walkLog([first, close, second], catalogue: _catalogue);
    expect(
      reopened.openSessionStart!.instantUtcMicros,
      second.instantUtcMicros,
    );
  });

  test('a session crossing 04:00 charges every card act to its start day '
      '(AD-19): a 03:40 session\'s 04:10 acts belong to the earlier day', () {
    final log = [
      _started(utcMicros(2026, 8, 28, 3, 40)),
      _act(LogKind.cardDealt, utcMicros(2026, 8, 28, 4, 10), 'man-a'),
      _act(LogKind.cardDone, utcMicros(2026, 8, 28, 4, 15), 'zona-a'),
    ];
    final facts = walkLog(log, catalogue: _catalogue);

    const calendar = Calendar();
    final day27 = calendar.dayOf(utcMicros(2026, 8, 28, 3, 40), 0);
    expect(day27.label, '2026-08-27');

    // The dealt maintenance card is charged to the session's day...
    expect(facts.dealtCountsByDay[day27]?[Size.maintenance], 1);
    // ...the crossed-into day holds nothing...
    final day28 = calendar.dayOf(utcMicros(2026, 8, 28, 12), 0);
    expect(facts.dealtCountsByDay[day28], isNull);
    // ...and the chunk done inside the crossing session closed the
    // start day's slot, never the crossed-into day's.
    expect(facts.focusSlotClosedDays, {day27});
    expect(facts.focusSlotClosedDays.contains(day28), isFalse);
  });

  test('the same crossing under a nonzero stored offset: +02:00 entries at '
      '03:40 charge to the previous domestic day (AD-4)', () {
    // 03:40 +02:00 on the 29th is 01:40 UTC — the wall clock in the
    // stored frame is what decides, never the runner's zone.
    final startUtc = utcMicros(2026, 8, 29, 1, 40);
    final log = [
      SessionStartEntry(
        id: 's-offset',
        instantUtcMicros: startUtc,
        offsetSeconds: 7200,
        kind: LogKind.sessionStarted,
      ),
      ItemActEntry(
        id: 'd-offset',
        instantUtcMicros: utcMicros(2026, 8, 29, 2, 10),
        offsetSeconds: 7200,
        kind: LogKind.cardDealt,
        itemId: 'zona-a',
        itemOrigin: Origin.shipped,
      ),
      ItemActEntry(
        id: 'o-offset',
        instantUtcMicros: utcMicros(2026, 8, 29, 2, 15),
        offsetSeconds: 7200,
        kind: LogKind.cardDone,
        itemId: 'zona-a',
        itemOrigin: Origin.shipped,
      ),
    ];
    final facts = walkLog(log, catalogue: _catalogue);
    const calendar = Calendar();
    final day28 = calendar.dayOf(startUtc, 7200);
    expect(day28.label, '2026-08-28');
    expect(facts.focusSlotClosedDays, {day28});
    expect(facts.dealtCountsByDay[day28]?[Size.focus], 1);
  });

  test('the crossed-into direction too: acts before a same-night boundary '
      'stay on the session\'s day, and a later session opens the new day', () {
    final log = [
      _started(utcMicros(2026, 8, 28, 1, 30)),
      _act(LogKind.cardDealt, utcMicros(2026, 8, 28, 3, 50), 'zona-a'),
      _act(LogKind.cardDone, utcMicros(2026, 8, 28, 3, 55), 'zona-a'),
      _ended(utcMicros(2026, 8, 28, 3, 58)),
    ];
    final facts = walkLog(log, catalogue: _catalogue);
    const calendar = Calendar();
    expect(facts.focusSlotClosedDays, {
      calendar.dayOf(utcMicros(2026, 8, 28, 1, 30), 0),
    });

    final nextNight = [...log, _started(utcMicros(2026, 8, 29, 9))];
    final reopened = walkLog(nextNight, catalogue: _catalogue);
    // The new session anchors to its own day, whose slot is untouched.
    expect(
      anchorDayOf(reopened, utcMicros(2026, 8, 29, 9, 1), 0),
      calendar.dayOf(utcMicros(2026, 8, 29, 9), 0),
    );
  });

  test('anchorDayOf follows the open session, else the instant itself', () {
    final crossing = [_started(utcMicros(2026, 8, 28, 3, 40))];
    final facts = walkLog(crossing, catalogue: _catalogue);
    expect(
      anchorDayOf(facts, utcMicros(2026, 8, 28, 12), 0).label,
      '2026-08-27',
    );

    final closed = walkLog(const [], catalogue: _catalogue);
    expect(
      anchorDayOf(closed, utcMicros(2026, 8, 28, 12), 0).label,
      '2026-08-28',
    );
  });

  test('only a card_done closes the chunk slot; a skip never does', () {
    final skipped = walkLog([
      _started(utcMicros(2026, 8, 28, 10)),
      _act(LogKind.cardDealt, utcMicros(2026, 8, 28, 10, 0, 1), 'zona-a'),
      _act(LogKind.cardSkipped, utcMicros(2026, 8, 28, 10, 0, 2), 'zona-a'),
    ], catalogue: _catalogue);
    expect(skipped.focusSlotClosedDays, isEmpty);

    final done = walkLog([
      _started(utcMicros(2026, 8, 28, 10)),
      _act(LogKind.cardDealt, utcMicros(2026, 8, 28, 10, 0, 1), 'zona-a'),
      _act(LogKind.cardDone, utcMicros(2026, 8, 28, 10, 0, 2), 'zona-a'),
    ], catalogue: _catalogue);
    expect(done.focusSlotClosedDays, hasLength(1));

    // A non-focus card_done closes nothing.
    final upkeepDone = walkLog([
      _started(utcMicros(2026, 8, 28, 10)),
      _act(LogKind.cardDone, utcMicros(2026, 8, 28, 10, 0, 2), 'man-a'),
    ], catalogue: _catalogue);
    expect(upkeepDone.focusSlotClosedDays, isEmpty);
  });

  test('the dealt-but-unanswered card is a fact of the open session only', () {
    final answeredByDone = walkLog([
      _started(utcMicros(2026, 8, 28, 10)),
      _act(LogKind.cardDealt, utcMicros(2026, 8, 28, 10, 0, 1), 'man-a'),
      _act(LogKind.cardDone, utcMicros(2026, 8, 28, 10, 0, 2), 'man-a'),
    ], catalogue: _catalogue);
    expect(answeredByDone.dealtUnanswered, isNull);

    final answeredBySkip = walkLog([
      _started(utcMicros(2026, 8, 28, 10)),
      _act(LogKind.cardDealt, utcMicros(2026, 8, 28, 10, 0, 1), 'man-a'),
      _act(LogKind.cardSkipped, utcMicros(2026, 8, 28, 10, 0, 2), 'man-a'),
    ], catalogue: _catalogue);
    expect(answeredBySkip.dealtUnanswered, isNull);

    final closed = walkLog([
      _started(utcMicros(2026, 8, 28, 10)),
      _act(LogKind.cardDealt, utcMicros(2026, 8, 28, 10, 0, 1), 'man-a'),
      _ended(utcMicros(2026, 8, 28, 10, 30)),
    ], catalogue: _catalogue);
    expect(closed.dealtUnanswered, isNull);

    final open = walkLog([
      _started(utcMicros(2026, 8, 28, 10)),
      _act(LogKind.cardDealt, utcMicros(2026, 8, 28, 10, 0, 1), 'man-a'),
    ], catalogue: _catalogue);
    expect(open.dealtUnanswered!.itemId, 'man-a');
    expect(open.dealtUnanswered!.itemOrigin, Origin.shipped);
  });

  test('a card_done of another origin leaves the outstanding deal standing: '
      'the clear matches (itemId, itemOrigin)', () {
    final crossOriginDone = ItemActEntry(
      id: 'done-cross-origin',
      instantUtcMicros: utcMicros(2026, 8, 28, 10, 0, 2),
      offsetSeconds: 0,
      kind: LogKind.cardDone,
      itemId: 'man-a',
      itemOrigin: Origin.manual,
    );
    final standing = walkLog([
      _started(utcMicros(2026, 8, 28, 10)),
      _act(LogKind.cardDealt, utcMicros(2026, 8, 28, 10, 0, 1), 'man-a'),
      crossOriginDone,
    ], catalogue: _catalogue);
    expect(
      standing.dealtUnanswered!.itemId,
      'man-a',
      reason:
          'the answer\'s origin differs from the deal\'s — the deal '
          'stands',
    );
    expect(standing.dealtUnanswered!.itemOrigin, Origin.shipped);
    // The done still answers all-time — only the clear is origin-scoped.
    expect(standing.answeredItemIds, {'man-a'});

    // The matching (itemId, itemOrigin) pair clears, as always.
    final cleared = walkLog([
      _started(utcMicros(2026, 8, 28, 10)),
      _act(LogKind.cardDealt, utcMicros(2026, 8, 28, 10, 0, 1), 'man-a'),
      crossOriginDone,
      _act(LogKind.cardDone, utcMicros(2026, 8, 28, 10, 0, 3), 'man-a'),
    ], catalogue: _catalogue);
    expect(cleared.dealtUnanswered, isNull);

    // The asymmetry's slot-close twin on a focus item: the
    // pair-mismatched done leaves the deal standing, yet answering
    // stays bare-id — the day's focus slot closes all the same.
    final focusCrossOrigin = walkLog([
      _started(utcMicros(2026, 8, 28, 10)),
      _act(LogKind.cardDealt, utcMicros(2026, 8, 28, 10, 0, 1), 'zona-a'),
      ItemActEntry(
        id: 'done-focus-cross-origin',
        instantUtcMicros: utcMicros(2026, 8, 28, 10, 0, 2),
        offsetSeconds: 0,
        kind: LogKind.cardDone,
        itemId: 'zona-a',
        itemOrigin: Origin.manual,
      ),
    ], catalogue: _catalogue);
    expect(focusCrossOrigin.dealtUnanswered!.itemId, 'zona-a');
    expect(focusCrossOrigin.dealtUnanswered!.itemOrigin, Origin.shipped);
    expect(
      focusCrossOrigin.focusSlotClosedDays,
      {const Calendar().dayOf(utcMicros(2026, 8, 28, 10), 0)},
      reason:
          'the answered index and the slot close stay bare-id — only '
          'the clear is pair-scoped',
    );
  });

  test('the answered index holds card_done rows only, all-time (AD-20)', () {
    final facts = walkLog([
      _started(utcMicros(2026, 8, 28, 10)),
      _act(LogKind.cardDealt, utcMicros(2026, 8, 28, 10, 0, 1), 'man-a'),
      _act(LogKind.cardDone, utcMicros(2026, 8, 28, 10, 0, 2), 'man-a'),
      _act(LogKind.cardDealt, utcMicros(2026, 8, 28, 10, 0, 3), 'hab-a'),
      _act(LogKind.cardSkipped, utcMicros(2026, 8, 28, 10, 0, 4), 'hab-a'),
      _act(LogKind.cardDone, utcMicros(2026, 8, 20, 9), 'zona-a'),
    ], catalogue: _catalogue);
    // A `card_done` answers whatever size it names; a skip consumes
    // nothing; and answering is all-time, never windowed.
    expect(facts.answeredItemIds, {'man-a', 'zona-a'});
  });

  test('the least-recently-dealt index reads recorded deal instants, latest '
      'per item (AD-3)', () {
    final facts = walkLog([
      _act(LogKind.cardDealt, utcMicros(2026, 8, 26, 10), 'hab-a'),
      _act(LogKind.cardDealt, utcMicros(2026, 8, 27, 10), 'hab-a'),
      _act(LogKind.cardDealt, utcMicros(2026, 8, 25, 10), 'hab-b'),
    ], catalogue: _catalogue);
    expect(
      facts.lastDealtInstantByItemId['hab-a'],
      utcMicros(2026, 8, 27, 10),
      reason: 'a repeated deal keeps only the latest instant',
    );
    expect(facts.lastDealtInstantByItemId['hab-b'], utcMicros(2026, 8, 25, 10));
    expect(facts.lastDealtInstantByItemId.containsKey('zona-a'), isFalse);
  });

  test('unknown kinds and crash entries change no session fact (AD-23)', () {
    final log = <LogEntry>[
      _started(utcMicros(2026, 8, 28, 10)),
      UnknownEntry(
        id: 'u-1',
        instantUtcMicros: utcMicros(2026, 8, 28, 10, 0, 1),
        offsetSeconds: 0,
        kind: LogKind.parse('future_kind'),
      ),
      CrashEntry(
        id: 'c-1',
        instantUtcMicros: utcMicros(2026, 8, 28, 10, 0, 2),
        offsetSeconds: 0,
        stack: '#0      build',
      ),
      _act(LogKind.cardDealt, utcMicros(2026, 8, 28, 10, 0, 3), 'man-a'),
    ];
    final facts = walkLog(log, catalogue: _catalogue);
    expect(facts.openSessionStart, isNotNull);
    expect(facts.dealtUnanswered!.itemId, 'man-a');
    expect(facts.dealtCountsByDay, isNotEmpty);
  });

  test('an item the catalogue does not know carries no size: it closes '
      'nothing and counts by no size', () {
    final facts = walkLog([
      _started(utcMicros(2026, 8, 28, 10)),
      _act(LogKind.cardDealt, utcMicros(2026, 8, 28, 10, 0, 1), 'capturada'),
      _act(LogKind.cardDone, utcMicros(2026, 8, 28, 10, 0, 2), 'capturada'),
    ], catalogue: _catalogue);
    expect(facts.focusSlotClosedDays, isEmpty);
    expect(
      facts.dealtCountsByDay.values.every((bySize) => bySize.isEmpty),
      isTrue,
    );
    // The deal index still records it — the id discipline is shared.
    expect(facts.lastDealtInstantByItemId['capturada'], isNotNull);
  });

  group('the declared pocket\'s walk facts (Story 2.2, AD-19, FR-8)', () {
    test('the open session\'s pocket is its start row\'s own payload — '
        'in range as minted, out of range as absent, unbounded when null', () {
      expect(
        walkLog([
          _started(utcMicros(2026, 8, 28, 10), pocketMinutes: 15),
        ], catalogue: _catalogue).openSessionPocketMinutes,
        15,
      );
      expect(
        walkLog([
          _started(utcMicros(2026, 8, 28, 10), pocketMinutes: 1),
        ], catalogue: _catalogue).openSessionPocketMinutes,
        1,
      );
      expect(
        walkLog([
          _started(utcMicros(2026, 8, 28, 10), pocketMinutes: 60),
        ], catalogue: _catalogue).openSessionPocketMinutes,
        60,
      );
      // An imported 90 derives as absent → unbounded, and the row is
      // never repaired (AD-23).
      expect(
        walkLog([
          _started(utcMicros(2026, 8, 28, 10), pocketMinutes: 90),
        ], catalogue: _catalogue).openSessionPocketMinutes,
        isNull,
      );
      expect(
        walkLog([
          _started(utcMicros(2026, 8, 28, 10), pocketMinutes: 0),
        ], catalogue: _catalogue).openSessionPocketMinutes,
        isNull,
      );
      expect(
        walkLog([
          _started(utcMicros(2026, 8, 28, 10)),
        ], catalogue: _catalogue).openSessionPocketMinutes,
        isNull,
      );
      // No session open: no pocket fact either.
      expect(
        walkLog([
          _started(utcMicros(2026, 8, 28, 10), pocketMinutes: 15),
          _ended(utcMicros(2026, 8, 28, 11)),
        ], catalogue: _catalogue).openSessionPocketMinutes,
        isNull,
      );
    });

    test('answered estimates charge the open session — upkeep included; a '
        'skip releases; a dealt-unanswered card consumes nothing; a '
        'supersede restarts at zero (FR-8, FR-12)', () {
      final base = utcMicros(2026, 8, 28, 10);
      final charged = walkLog([
        _started(base, pocketMinutes: 20),
        _act(LogKind.cardDealt, base + 1000, 'man-a'),
        _act(LogKind.cardDone, base + 2000, 'man-a'),
      ], catalogue: _catalogue);
      expect(charged.openSessionAnsweredSeconds, maintenanceEstimateSeconds);

      // A skip adds nothing — its estimate releases back.
      final skipped = walkLog([
        _started(base, pocketMinutes: 20),
        _act(LogKind.cardDealt, base + 1000, 'man-a'),
        _act(LogKind.cardSkipped, base + 2000, 'man-a'),
      ], catalogue: _catalogue);
      expect(skipped.openSessionAnsweredSeconds, 0);

      // Dealt but never answered: consumed nothing.
      final unanswered = walkLog([
        _started(base, pocketMinutes: 20),
        _act(LogKind.cardDealt, base + 1000, 'zona-a'),
      ], catalogue: _catalogue);
      expect(unanswered.openSessionAnsweredSeconds, 0);

      // The supersede pair restarts consumption at zero.
      final superseded = walkLog([
        _started(base, pocketMinutes: 20),
        _act(LogKind.cardDealt, base + 1000, 'man-a'),
        _act(LogKind.cardDone, base + 2000, 'man-a'),
        _ended(base + 3000),
        _started(base + 3000, pocketMinutes: 5),
      ], catalogue: _catalogue);
      expect(superseded.openSessionAnsweredSeconds, 0);
      expect(superseded.openSessionPocketMinutes, 5);

      // Outside any session a card_done charges no pocket — there is
      // none to charge.
      final outside = walkLog([
        _act(LogKind.cardDone, base + 2000, 'man-a'),
      ], catalogue: _catalogue);
      expect(outside.openSessionAnsweredSeconds, 0);
    });

    test('the supersede pair carries the in-progress card; any other start '
        'clears it (AD-19, Story 2.2)', () {
      final base = utcMicros(2026, 8, 28, 10);
      final carried = walkLog([
        _started(base),
        _act(LogKind.cardDealt, base + 1000, 'man-a'),
        _ended(base + 3000),
        _started(base + 3000, pocketMinutes: 15),
      ], catalogue: _catalogue);
      expect(carried.dealtUnanswered, isNotNull);
      expect(carried.dealtUnanswered!.itemId, 'man-a');
      expect(carried.dealtUnanswered!.itemOrigin, Origin.shipped);

      // A started row at another instant clears, even adjacent.
      final clearedLater = walkLog([
        _started(base),
        _act(LogKind.cardDealt, base + 1000, 'man-a'),
        _ended(base + 3000),
        _started(base + 4000, pocketMinutes: 15),
      ], catalogue: _catalogue);
      expect(clearedLater.dealtUnanswered, isNull);

      // A same-instant start that does not directly follow the ended —
      // another row between them — clears too: adjacency is the rule.
      final brokenByRow = walkLog([
        _started(base),
        _act(LogKind.cardDealt, base + 1000, 'man-a'),
        _ended(base + 3000),
        MomentEntry(
          id: 'opened-between',
          instantUtcMicros: base + 3000,
          offsetSeconds: 0,
          kind: LogKind.appOpened,
        ),
        _started(base + 3000, pocketMinutes: 15),
      ], catalogue: _catalogue);
      expect(brokenByRow.dealtUnanswered, isNull);
    });

    test('the carried card\'s later card_done charges the new session: a '
        '15-minute chunk finished under a 5-minute pocket honestly spends '
        'it (Story 2.2)', () {
      final base = utcMicros(2026, 8, 28, 10);
      final facts = walkLog([
        _started(base),
        _act(LogKind.cardDealt, base + 1000, 'zona-a'),
        _ended(base + 3000),
        _started(base + 3000, pocketMinutes: 5),
        _act(LogKind.cardDone, base + 5000, 'zona-a'),
      ], catalogue: _catalogue);
      expect(facts.openSessionPocketMinutes, 5);
      expect(facts.openSessionAnsweredSeconds, focusEstimateSeconds);
      expect(facts.dealtUnanswered, isNull);
    });

    test('a session crossing 04:00 stays one ledger under a pocket: the '
        'pocket is consumed across the boundary and the crossed-into '
        'day\'s slot stays untouched (AD-19, AD-20)', () {
      final start = utcMicros(2026, 8, 28, 3, 40);
      final facts = walkLog([
        _started(start, pocketMinutes: 30),
        _act(LogKind.cardDealt, utcMicros(2026, 8, 28, 3, 50), 'man-a'),
        _act(LogKind.cardDone, utcMicros(2026, 8, 28, 3, 55), 'man-a'),
        // The crossing answer, charged to the start day's ledger — the
        // same maintenance entry re-dealt across the boundary.
        _act(LogKind.cardDealt, utcMicros(2026, 8, 28, 4, 10), 'man-a'),
        _act(LogKind.cardDone, utcMicros(2026, 8, 28, 4, 15), 'man-a'),
      ], catalogue: _catalogue);
      const calendar = Calendar();
      final day27 = calendar.dayOf(start, 0);
      expect(day27.label, '2026-08-27');
      expect(facts.openSessionAnsweredSeconds, 2 * maintenanceEstimateSeconds);
      // Both deals charged to the session's own start day, the
      // crossed-into day holds nothing.
      final day28 = calendar.dayOf(utcMicros(2026, 8, 28, 12), 0);
      expect(facts.dealtCountsByDay[day27]?[Size.maintenance], 2);
      expect(facts.dealtCountsByDay[day28], isNull);
      expect(facts.focusSlotClosedDays.contains(day28), isFalse);
    });

    test('two session_started rows at one instant: store read order '
        'decides, the later wins (AD-3, deterministic replay)', () {
      final base = utcMicros(2026, 8, 28, 10);
      final facts = walkLog([
        _started(base, pocketMinutes: 15, id: 'early'),
        _started(base, pocketMinutes: 30, id: 'late'),
      ], catalogue: _catalogue);
      expect(facts.openSessionPocketMinutes, 30);
      expect(facts.openSessionStart!.instantUtcMicros, base);
    });
  });
}

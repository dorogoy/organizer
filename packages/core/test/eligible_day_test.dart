import 'package:core/day/calendar.dart';
import 'package:core/derive/eligible_day.dart';
import 'package:core/energy/energy.dart';
import 'package:core/log/log_entry.dart';
import 'package:core/pool/pool_fact.dart';
import 'package:test/test.dart';

import 'test_util.dart';

/// A manual capture's pool fact — the item half of `EligibleDay(item,
/// day)`, with its creation instant the window's lower bound.
PoolFact _fact(
  int micros, {
  String id = 'cap-a',
  Size size = Size.focus,
  String line = 'Llamar al dentista',
}) => PoolFact(
  id: id,
  origin: Origin.manual,
  size: size,
  instantUtcMicros: micros,
  offsetSeconds: 0,
  originContext: line,
);

SessionStartEntry _started(int micros, {String id = 'start'}) =>
    SessionStartEntry(
      id: '$id-$micros',
      instantUtcMicros: micros,
      offsetSeconds: 0,
      kind: LogKind.sessionStarted,
    );

MomentEntry _ended(int micros) => MomentEntry(
  id: 'end-$micros',
  instantUtcMicros: micros,
  offsetSeconds: 0,
  kind: LogKind.sessionEnded,
);

ItemActEntry _deal(int micros, String itemId, {String id = 'deal'}) =>
    ItemActEntry(
      id: '$id-$micros-$itemId',
      instantUtcMicros: micros,
      offsetSeconds: 0,
      kind: LogKind.cardDealt,
      itemId: itemId,
      itemOrigin: Origin.manual,
    );

ItemActEntry _answeredRow(int micros, String itemId) => ItemActEntry(
  id: 'done-$micros-$itemId',
  instantUtcMicros: micros,
  offsetSeconds: 0,
  kind: LogKind.cardDone,
  itemId: itemId,
  itemOrigin: Origin.manual,
);

ItemActEntry _skippedRow(int micros, String itemId) => ItemActEntry(
  id: 'skip-$micros-$itemId',
  instantUtcMicros: micros,
  offsetSeconds: 0,
  kind: LogKind.cardSkipped,
  itemId: itemId,
  itemOrigin: Origin.manual,
);

EnergySetEntry _energySet(int micros, EnergyLevel level) => EnergySetEntry(
  id: 'energy-$micros-${level.name}',
  instantUtcMicros: micros,
  offsetSeconds: 0,
  level: level,
);

const int _microsPerDay = 24 * 60 * 60 * 1000 * 1000;

/// Noon on the [days]-th day of the fixture's run — day 0 is Monday
/// 2026-08-24. Hours stay at-or-after 04:00 so the civil date and the
/// domestic day agree.
int _day(int days) => utcMicros(2026, 8, 24, 12) + days * _microsPerDay;

/// One instant on the [days]-th day, at the given wall clock — the
/// sessions, rows and facts place themselves with it.
int _at(int days, int hour, [int minute = 0, int second = 0]) =>
    utcMicros(2026, 8, 24, hour, minute, second) + days * _microsPerDay;

void main() {
  const calendar = Calendar();
  // The read instant: after everything the fixtures hold.
  final now = _at(30, 14);

  Day dayOf(int days) => calendar.dayOf(_day(days), 0);

  bool eligible(List<LogEntry> entries, PoolFact fact, Day day, [int? at]) =>
      eligibleDay(
        entries: entries,
        fact: fact,
        day: day,
        instantUtcMicros: at ?? now,
      );

  int consumed(List<LogEntry> entries, PoolFact fact, [int? at]) =>
      captureDealWindowConsumedDays(
        entries: entries,
        fact: fact,
        instantUtcMicros: at ?? now,
      );

  test('the window is three eligible days — the one named width '
      '(FR-27, AD-24)', () {
    expect(captureDealWindowEligibleDays, 3);
  });

  group('the EligibleDay predicate (AD-24)', () {
    test('a day with no session start is not eligible — absence days '
        'count for nothing', () {
      final fact = _fact(_day(1));
      expect(eligible(const [], fact, dayOf(2)), isFalse);
      // An energy row alone opens no day either.
      expect(
        eligible([_energySet(_at(2, 8), EnergyLevel.low)], fact, dayOf(2)),
        isFalse,
      );
    });

    test('a session started on the day makes it eligible, 🟢 by default', () {
      final fact = _fact(_day(1));
      expect(eligible([_started(_at(2, 10))], fact, dayOf(2)), isTrue);
    });

    test('no earlier than the fact\'s creation — a capture born '
        'mid-session never makes that session\'s day eligible, and a '
        'later same-day start does', () {
      final fact = _fact(_at(2, 11));
      final bornInside = [_started(_at(2, 10))];
      expect(eligible(bornInside, fact, dayOf(2)), isFalse);
      final laterSameDay = [...bornInside, _started(_at(2, 12), id: 'again')];
      expect(eligible(laterSameDay, fact, dayOf(2)), isTrue);
    });

    test('a session outliving its day does not make the later day '
        'eligible — only starts count', () {
      final fact = _fact(_day(1));
      final crossing = [_started(_at(2, 23, 30)), _ended(_at(3, 12))];
      expect(eligible(crossing, fact, dayOf(2)), isTrue);
      expect(eligible(crossing, fact, dayOf(3)), isFalse);
    });

    test('energy is the session\'s own domestic day\'s last row at or '
        'before the start — a previous evening\'s 🔴 is never read', () {
      final fact = _fact(_day(1));
      final entries = [
        _energySet(_at(1, 22), EnergyLevel.low),
        _started(_at(2, 10)),
      ];
      expect(eligible(entries, fact, dayOf(2)), isTrue);
    });

    test('a 🔴 start excludes the two larger sizes and never the '
        'instant size — AD-24\'s freeze mechanics', () {
      final focus = _fact(_day(1), size: Size.focus);
      final maintenance = _fact(_day(1), id: 'cap-m', size: Size.maintenance);
      final instant = _fact(_day(1), id: 'cap-i', size: Size.instant);
      final entries = [
        _energySet(_at(2, 8), EnergyLevel.low),
        _started(_at(2, 10)),
      ];
      expect(eligible(entries, focus, dayOf(2)), isFalse);
      expect(eligible(entries, maintenance, dayOf(2)), isFalse);
      expect(eligible(entries, instant, dayOf(2)), isTrue);
    });

    test('the last row at or before the start wins; a row after the '
        'start never excludes that session', () {
      final fact = _fact(_day(1));
      // Full at 09:00 after a low 08:00: the 10:00 start reads full.
      final recovered = [
        _energySet(_at(2, 8), EnergyLevel.low),
        _energySet(_at(2, 9), EnergyLevel.full),
        _started(_at(2, 10)),
      ];
      expect(eligible(recovered, fact, dayOf(2)), isTrue);
      // Low at 09:00 after a full 08:00: the 10:00 start reads low.
      final dropped = [
        _energySet(_at(2, 8), EnergyLevel.full),
        _energySet(_at(2, 9), EnergyLevel.low),
        _started(_at(2, 10)),
      ];
      expect(eligible(dropped, fact, dayOf(2)), isFalse);
      // A low set AFTER the start excludes nothing for that session.
      final later = [
        _started(_at(2, 10)),
        _energySet(_at(2, 11), EnergyLevel.low),
      ];
      expect(eligible(later, fact, dayOf(2)), isTrue);
    });

    test('at least one of the day\'s sessions admitting the size '
        'suffices', () {
      final fact = _fact(_day(1));
      final entries = [
        _energySet(_at(2, 8), EnergyLevel.low),
        _started(_at(2, 9)),
        _ended(_at(2, 9, 30)),
        _energySet(_at(2, 12), EnergyLevel.full),
        _started(_at(2, 14)),
      ];
      expect(eligible(entries, fact, dayOf(2)), isTrue);
    });

    test('rows after the read instant are skipped — the derivation '
        'judges the log as of a read, never the future', () {
      final fact = _fact(_day(1));
      final entries = [_started(_at(2, 10))];
      expect(eligible(entries, fact, dayOf(2), _at(2, 9)), isFalse);
      expect(eligible(entries, fact, dayOf(2), _at(2, 10)), isTrue);
    });

    test('an energy_set at exactly the session-start instant counts — '
        '"at or before" is inclusive', () {
      final fact = _fact(_day(1));
      final atTheStart = [
        _energySet(_at(2, 10), EnergyLevel.low),
        _started(_at(2, 10)),
      ];
      expect(eligible(atTheStart, fact, dayOf(2)), isFalse);
      final instant = _fact(_day(1), id: 'cap-i', size: Size.instant);
      expect(eligible(atTheStart, instant, dayOf(2)), isTrue);
    });

    test('an exact-instant energy tie resolves to the later-in-input '
        'row — the energy seam\'s own convention', () {
      final fact = _fact(_day(1));
      // Two rows at the same microsecond: the second wins whatever the
      // first said.
      final lowThenFull = [
        _started(_at(2, 10)),
        _energySet(_at(2, 10), EnergyLevel.low),
        _energySet(_at(2, 10), EnergyLevel.full),
      ];
      expect(eligible(lowThenFull, fact, dayOf(2)), isTrue);
      final fullThenLow = [
        _started(_at(2, 10)),
        _energySet(_at(2, 10), EnergyLevel.full),
        _energySet(_at(2, 10), EnergyLevel.low),
      ];
      expect(eligible(fullThenLow, fact, dayOf(2)), isFalse);
    });
  });

  group('the consumed-days fold (FR-27, AD-24)', () {
    test('a dealt-and-answered eligible day consumes one unit', () {
      final fact = _fact(_day(1), id: 'cap-a');
      final entries = [
        _started(_at(2, 10)),
        _deal(_at(2, 10, 0, 1), 'cap-a'),
        _answeredRow(_at(2, 10, 0, 2), 'cap-a'),
        _ended(_at(2, 10, 0, 3)),
      ];
      expect(consumed(entries, fact), 1);
    });

    test('a dealt-and-skipped eligible day consumes exactly the same — '
        'and same-day re-deals stay one day', () {
      final fact = _fact(_day(1), id: 'cap-a');
      final entries = [
        _started(_at(2, 10)),
        _deal(_at(2, 10, 0, 1), 'cap-a'),
        _skippedRow(_at(2, 10, 0, 2), 'cap-a'),
        _deal(_at(2, 10, 0, 3), 'cap-a'),
        _answeredRow(_at(2, 10, 0, 4), 'cap-a'),
      ];
      expect(consumed(entries, fact), 1);
    });

    test('a 🔴 day is not eligible for a focus capture — even a '
        'charged deal consumes nothing there (the canonical freeze, '
        'pinned over any log)', () {
      final fact = _fact(_day(1), id: 'cap-a');
      final entries = [
        _energySet(_at(2, 8), EnergyLevel.low),
        _started(_at(2, 10)),
        _deal(_at(2, 10, 0, 1), 'cap-a'),
        _skippedRow(_at(2, 10, 0, 2), 'cap-a'),
        _ended(_at(2, 10, 0, 3)),
        _started(_at(3, 10)),
        _deal(_at(3, 10, 0, 1), 'cap-a'),
        _skippedRow(_at(3, 10, 0, 2), 'cap-a'),
      ];
      expect(consumed(entries, fact), 1);
    });

    test('an instant capture consumes on a 🔴 day — 30 s is never '
        'excluded', () {
      final fact = _fact(_day(1), id: 'cap-i', size: Size.instant);
      final entries = [
        _energySet(_at(2, 8), EnergyLevel.low),
        _started(_at(2, 10)),
        _deal(_at(2, 10, 0, 1), 'cap-i'),
        _skippedRow(_at(2, 10, 0, 2), 'cap-i'),
      ];
      expect(consumed(entries, fact), 1);
    });

    test('absence days freeze the count and it resumes — no expiry, '
        'no cap, no clamp at the window\'s width', () {
      final fact = _fact(_day(1), id: 'cap-a');
      List<LogEntry> sitting(int days) => [
        _started(_at(days, 10)),
        _deal(_at(days, 10, 0, 1), 'cap-a'),
        _answeredRow(_at(days, 10, 0, 2), 'cap-a'),
        _ended(_at(days, 10, 0, 3)),
      ];

      final entries = [
        ...sitting(2),
        // Days 3–6 hold nothing at all: the window freezes across
        // them and resumes where it froze.
        ...sitting(7),
        ...sitting(8),
        ...sitting(9),
      ];
      expect(consumed(entries, fact), 4);
      // And each intermediate stretch holds the same running count.
      expect(consumed(entries.take(4).toList(), fact), 1);
      expect(consumed(entries.take(8).toList(), fact), 2);
    });

    test('a capture created mid-session and dealt before any new '
        'session start consumes nothing — a later same-day start makes '
        'the day eligible and the charge land', () {
      final fact = _fact(_at(2, 10, 0, 5), id: 'cap-a');
      final before = [
        _started(_at(2, 10)),
        _deal(_at(2, 10, 0, 30), 'cap-a'),
        _skippedRow(_at(2, 10, 0, 31), 'cap-a'),
        _ended(_at(2, 10, 0, 32)),
      ];
      expect(consumed(before, fact), 0);
      final after = [
        ...before,
        _started(_at(2, 12), id: 'again'),
        _deal(_at(2, 12, 0, 1), 'cap-a'),
        _answeredRow(_at(2, 12, 0, 2), 'cap-a'),
      ];
      // The day turned eligible through the later start, so the
      // charge it already held counts — one consumed day, not two.
      expect(consumed(after, fact), 1);
    });

    test('a capture never dealt consumes nothing, whatever the log '
        'holds', () {
      final fact = _fact(_day(1), id: 'cap-a');
      final entries = [
        _started(_at(2, 10)),
        _deal(_at(2, 10, 0, 1), 'another-cap'),
        _skippedRow(_at(2, 10, 0, 2), 'another-cap'),
      ];
      expect(consumed(entries, fact), 0);
    });

    test('rows after the read instant consume nothing', () {
      final fact = _fact(_day(1), id: 'cap-a');
      final entries = [
        _started(_at(2, 10)),
        _deal(_at(2, 10, 0, 1), 'cap-a'),
        _answeredRow(_at(2, 10, 0, 2), 'cap-a'),
      ];
      expect(consumed(entries, fact, _at(2, 9)), 0);
      expect(consumed(entries, fact, _at(2, 10, 0, 2)), 1);
      // The exact shape the bound exists for: a deal dated AFTER the
      // read, charged to a session that started BEFORE it. An
      // unbounded walk would charge the deal to the session's day —
      // a day whose witness start the read already sees — and count
      // one consumed unit at the earlier read; the bounded fold
      // counts nothing until the deal's own instant arrives.
      final dealAfterRead = [
        _started(_at(2, 10)),
        _deal(_at(2, 16), 'cap-a'),
        _answeredRow(_at(2, 17), 'cap-a'),
      ];
      expect(consumed(dealAfterRead, fact, _at(2, 12)), 0);
      expect(consumed(dealAfterRead, fact, _at(2, 16)), 1);
    });
  });
}

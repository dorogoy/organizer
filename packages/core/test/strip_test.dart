import 'package:core/derive/strip.dart';
import 'package:core/energy/energy.dart';
import 'package:core/log/log_entry.dart';
import 'package:core/pool/pool_fact.dart';
import 'package:test/test.dart';

import 'test_util.dart';

MomentEntry _opened(int micros, {int offsetSeconds = 0, String id = 'open'}) =>
    MomentEntry(
      id: id,
      instantUtcMicros: micros,
      offsetSeconds: offsetSeconds,
      kind: LogKind.appOpened,
    );

SessionStartEntry _started(
  int micros, {
  int offsetSeconds = 0,
  String id = 'start',
}) => SessionStartEntry(
  id: id,
  instantUtcMicros: micros,
  offsetSeconds: offsetSeconds,
  kind: LogKind.sessionStarted,
);

MomentEntry _ended(int micros, {int offsetSeconds = 0, String id = 'end'}) =>
    MomentEntry(
      id: id,
      instantUtcMicros: micros,
      offsetSeconds: offsetSeconds,
      kind: LogKind.sessionEnded,
    );

EnergySetEntry _energy(
  int micros,
  EnergyLevel level, {
  int offsetSeconds = 0,
  String id = 'energy',
}) => EnergySetEntry(
  id: id,
  instantUtcMicros: micros,
  offsetSeconds: offsetSeconds,
  level: level,
);

ItemActEntry _dealt(int micros, String itemId, {String id = 'deal'}) =>
    ItemActEntry(
      id: id,
      instantUtcMicros: micros,
      offsetSeconds: 0,
      kind: LogKind.cardDealt,
      itemId: itemId,
      itemOrigin: Origin.shipped,
    );

void main() {
  // "Now" for every test: Saturday 2026-08-29 12:00 UTC (offset 0, so
  // the domestic day began at 04:00 UTC).
  const offset = 0;
  final now = utcMicros(2026, 8, 29, 12);

  StripState? resolve(List<LogEntry> entries, [int? at]) => deriveStrip(
    entries: entries,
    instantUtcMicros: at ?? now,
    offsetSeconds: offset,
  );

  group('the precedence order (UX-DR22, AD-3)', () {
    test('is one total order, rarest eligible frequency first, the '
        'check-in last', () {
      expect(stripResidentPrecedence, [
        StripResident.firstRunCuration,
        StripResident.quarantineFollowUp,
        StripResident.seasonalSuggestion,
        StripResident.snowball,
        StripResident.weeklySelfReport,
        StripResident.energyCheckIn,
      ]);
      // Every resident of the vocabulary holds exactly one slot: the
      // order is total, and a displaced resident is neither consumed
      // nor dismissed — exercised as data while one resident is
      // implemented.
      expect(
        stripResidentPrecedence.toSet(),
        equals(StripResident.values.toSet()),
      );
      expect(stripResidentPrecedence, hasLength(StripResident.values.length));
    });

    test('the check-in is this build\'s only implemented eligibility — '
        'a displaced resident re-offers because only ✕ dismisses', () {
      // The order is a list of values, never a consumption: resolving
      // the strip consumes nothing, so the same order resolves the
      // same resident again at the next read of the same opening.
      final entries = [
        _opened(utcMicros(2026, 8, 29, 9)),
        _started(utcMicros(2026, 8, 29, 9, 0, 1)),
      ];
      final first = resolve(entries);
      final second = resolve(entries);
      expect(first?.resident, StripResident.energyCheckIn);
      expect(second?.resident, StripResident.energyCheckIn);
    });
  });

  group('the check-in eligibility (matrix rows, FR-4)', () {
    test('the day\'s first opening, unanswered — due (matrix: first '
        'opening)', () {
      expect(
        resolve([
          _opened(utcMicros(2026, 8, 29, 9)),
          _started(utcMicros(2026, 8, 29, 9, 0, 1)),
          _dealt(utcMicros(2026, 8, 29, 9, 0, 2), 'hab-a'),
        ])?.resident,
        StripResident.energyCheckIn,
      );
    });

    test('an answered day — gone for the day, whatever the level', () {
      for (final level in EnergyLevel.values) {
        expect(
          resolve([
            _opened(utcMicros(2026, 8, 29, 9)),
            _energy(utcMicros(2026, 8, 29, 9, 1), level),
          ]),
          isNull,
          reason: 'a ${level.name} answer resolves the day',
        );
      }
    });

    test('only the current day\'s rows answer — yesterday\'s energy_set '
        'leaves today due again (matrix: day boundary)', () {
      expect(
        resolve([
          _opened(utcMicros(2026, 8, 28, 9)),
          _energy(utcMicros(2026, 8, 28, 10), EnergyLevel.low),
          _ended(utcMicros(2026, 8, 28, 11)),
          _opened(utcMicros(2026, 8, 29, 9)),
          _started(utcMicros(2026, 8, 29, 9, 0, 1)),
        ])?.resident,
        StripResident.energyCheckIn,
      );
    });

    test('each row\'s own stored offset scopes its day (AD-4)', () {
      // 01:00 UTC stored with +02:00: its own wall clock reads 03:00 on
      // 2026-08-29 — before 04:00, so its own domestic day is
      // 2026-08-28 and it answers nothing today. Scoping it in the
      // caller's frame would wrongly resolve the day.
      expect(
        resolve([
          _opened(utcMicros(2026, 8, 29, 9)),
          _energy(
            utcMicros(2026, 8, 29, 1),
            EnergyLevel.low,
            offsetSeconds: 7200,
          ),
        ])?.resident,
        StripResident.energyCheckIn,
      );
      // The same instant stored with −05:00 reads 20:00 on
      // 2026-08-28 — still yesterday, excluded either way; and an
      // in-day row in a traveller's frame counts.
      expect(
        resolve([
          _opened(utcMicros(2026, 8, 29, 9)),
          _energy(
            utcMicros(2026, 8, 29, 1),
            EnergyLevel.medium,
            offsetSeconds: 39600,
          ),
        ]),
        isNull,
        reason: 'own wall 12:00 today — the day is answered',
      );
    });

    test('a second opening the same day — never re-shown, never styled '
        'as anything owed (matrix: re-open same day)', () {
      expect(
        resolve([
          _opened(utcMicros(2026, 8, 29, 9)),
          _ended(utcMicros(2026, 8, 29, 9, 30)),
          _opened(utcMicros(2026, 8, 29, 10)),
          _started(utcMicros(2026, 8, 29, 10, 0, 1)),
        ]),
        isNull,
      );
    });

    test('a session crossing 04:00 with no app_opened in the '
        'crossed-into day — this read is that day\'s first opening, '
        'shown once (matrix: crossing)', () {
      final read = resolve([
        _opened(utcMicros(2026, 8, 28, 23)),
        _started(utcMicros(2026, 8, 28, 23, 0, 1)),
        _dealt(utcMicros(2026, 8, 29, 0, 30), 'hab-a'),
      ], utcMicros(2026, 8, 29, 5));
      expect(read?.resident, StripResident.energyCheckIn);

      // And once answered during the crossing, the crossed-into day is
      // done — the later opening hides too.
      final answered = resolve([
        _opened(utcMicros(2026, 8, 28, 23)),
        _started(utcMicros(2026, 8, 28, 23, 0, 1)),
        _energy(utcMicros(2026, 8, 29, 5), EnergyLevel.low),
      ], utcMicros(2026, 8, 29, 6));
      expect(answered, isNull);
    });

    test('a crossing ended, then a return — rows precede today\'s '
        'app_opened, so the first opening was consumed (matrix)', () {
      expect(
        resolve([
          _opened(utcMicros(2026, 8, 28, 23)),
          _started(utcMicros(2026, 8, 28, 23, 0, 1)),
          _ended(utcMicros(2026, 8, 29, 5)),
          _opened(utcMicros(2026, 8, 29, 6)),
          _started(utcMicros(2026, 8, 29, 6, 0, 1)),
        ]),
        isNull,
      );
      // A crossing card act at/after the boundary preceding the
      // return's app_opened betrays the consumed opening just the
      // same. (An act at 00:30 would land in the old day by its own
      // instant — the domestic day runs to 04:00.)
      expect(
        resolve([
          _opened(utcMicros(2026, 8, 28, 23)),
          _started(utcMicros(2026, 8, 28, 23, 0, 1)),
          _dealt(utcMicros(2026, 8, 29, 4, 30), 'hab-a'),
          _ended(utcMicros(2026, 8, 29, 5)),
          _opened(utcMicros(2026, 8, 29, 6)),
        ]),
        isNull,
      );
    });

    test('a prior-day session dangling unended — the '
        'kill-during-crossing marker: today\'s lone app_opened is not '
        'a first opening (matrix)', () {
      // The process died inside a crossing sitting; on relaunch the
      // fresh app_opened is today's earliest row, and only the
      // dangling start betrays the opening already underway.
      expect(
        resolve([
          _opened(utcMicros(2026, 8, 28, 23)),
          _started(utcMicros(2026, 8, 28, 23, 0, 1)),
          _opened(utcMicros(2026, 8, 29, 10)),
        ]),
        isNull,
      );
      // But a today-started open session beside the day's first open is
      // the ordinary fresh launch — due.
      expect(
        resolve([
          _opened(utcMicros(2026, 8, 29, 9)),
          _started(utcMicros(2026, 8, 29, 9, 0, 1)),
        ])?.resident,
        StripResident.energyCheckIn,
      );
    });

    test('a log with no app_opened in today reads as the day\'s first '
        'opening underway — flatly, whatever else it holds', () {
      // The predicate's first clause is literal (the story's recorded
      // reading): "no app_opened row in today". An empty log, a log
      // holding only acts, and a crossing sitting all read the same
      // way — the shell's lifecycle guarantees the open row lands
      // before the surface reads, so this clause is the crossing case
      // in production and never a bare log.
      expect(resolve([])?.resident, StripResident.energyCheckIn);
      expect(
        resolve([_energy(utcMicros(2026, 8, 28, 10), EnergyLevel.low)])
            ?.resident,
        StripResident.energyCheckIn,
        reason: 'yesterday\'s answer answers nothing today',
      );
    });
  });

  group('the derivation is pure — no write path (AD-3)', () {
    test('the same log resolves twice to the same resident', () {
      final entries = [_opened(utcMicros(2026, 8, 29, 9))];
      expect(resolve(entries)?.resident, StripResident.energyCheckIn);
      expect(resolve(entries)?.resident, StripResident.energyCheckIn);
      expect(entries, hasLength(1));
    });
  });

  group('the calendar authority (AD-4)', () {
    test('the read instant\'s own frame decides the current day', () {
      // 02:30 UTC on 2026-08-30 read with +02:00: the caller's wall
      // clock reads 04:30 on 2026-08-30 — past the boundary, so the
      // current day is the 30th and the 29th's rows answer nothing:
      // no app_opened row in the crossed-into day makes this read that
      // day's first opening.
      final at = utcMicros(2026, 8, 30, 2, 30);
      final state = deriveStrip(
        entries: [
          _opened(utcMicros(2026, 8, 29, 9)),
          _energy(utcMicros(2026, 8, 29, 10), EnergyLevel.low),
        ],
        instantUtcMicros: at,
        offsetSeconds: 7200,
      );
      expect(state?.resident, StripResident.energyCheckIn);
    });
  });
}

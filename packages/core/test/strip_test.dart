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
  // "Now" for every no-`at` read — the 2-5 matrix and the 2-6 rows
  // that sit on the Saturday base clock: Saturday 2026-08-29 12:00 UTC
  // (offset 0, so the domestic day began at 04:00 UTC).
  const offset = 0;
  final now = utcMicros(2026, 8, 29, 12);

  StripState? resolve(
    List<LogEntry> entries, [
    int? at,
    Set<StripResident> excludeResidents = const {},
  ]) => deriveStrip(
    entries: entries,
    instantUtcMicros: at ?? now,
    offsetSeconds: offset,
    excludeResidents: excludeResidents,
  );

  // The 2-5 wrapper: the read this build's shell makes — the report
  // excluded (dispenser_controller's interim seam, part 3's remover),
  // so the check-in matrix keeps resolving exactly as it shipped.
  StripState? resolveExcludingReport(List<LogEntry> entries, [int? at]) =>
      resolve(entries, at, const {StripResident.weeklySelfReport});

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

    test('under the shell\'s excluded read the check-in stands alone — '
        'a displaced resident re-offers because only ✕ dismisses', () {
      // The order is a list of values, never a consumption: resolving
      // the strip consumes nothing, so the same order resolves the
      // same resident again at the next read of the same opening.
      final entries = [
        _opened(utcMicros(2026, 8, 29, 9)),
        _started(utcMicros(2026, 8, 29, 9, 0, 1)),
      ];
      final first = resolveExcludingReport(entries);
      final second = resolveExcludingReport(entries);
      expect(first?.resident, StripResident.energyCheckIn);
      expect(second?.resident, StripResident.energyCheckIn);
    });
  });

  group('the check-in eligibility (matrix rows, FR-4)', () {
    test('the day\'s first opening, unanswered — due (matrix: first '
        'opening)', () {
      expect(
        resolveExcludingReport([
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
          resolveExcludingReport([
            _opened(utcMicros(2026, 8, 29, 9)),
            _energy(utcMicros(2026, 8, 29, 9, 1), level),
          ]),
          isNull,
          reason: 'a ${level.name} answer resolves the day',
        );
      }
    });

    test('same-day rows after the read instant do not answer or consume '
        'the opening', () {
      expect(
        resolveExcludingReport([
          _opened(utcMicros(2026, 8, 29, 9)),
          _energy(utcMicros(2026, 8, 29, 13), EnergyLevel.low),
          _opened(utcMicros(2026, 8, 29, 14), id: 'future-open'),
        ])?.resident,
        StripResident.energyCheckIn,
      );
    });

    test('only the current day\'s rows answer — yesterday\'s energy_set '
        'leaves today due again (matrix: day boundary)', () {
      expect(
        resolveExcludingReport([
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
        resolveExcludingReport([
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
        resolveExcludingReport([
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
        resolveExcludingReport([
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
      final read = resolveExcludingReport([
        _opened(utcMicros(2026, 8, 28, 23)),
        _started(utcMicros(2026, 8, 28, 23, 0, 1)),
        _dealt(utcMicros(2026, 8, 29, 0, 30), 'hab-a'),
      ], utcMicros(2026, 8, 29, 5));
      expect(read?.resident, StripResident.energyCheckIn);

      // And once answered during the crossing, the crossed-into day is
      // done — the later opening hides too.
      final answered = resolveExcludingReport([
        _opened(utcMicros(2026, 8, 28, 23)),
        _started(utcMicros(2026, 8, 28, 23, 0, 1)),
        _energy(utcMicros(2026, 8, 29, 5), EnergyLevel.low),
      ], utcMicros(2026, 8, 29, 6));
      expect(answered, isNull);
    });

    test('a crossing ended, then a return — rows precede today\'s '
        'app_opened, so the first opening was consumed (matrix)', () {
      expect(
        resolveExcludingReport([
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
        resolveExcludingReport([
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
        resolveExcludingReport([
          _opened(utcMicros(2026, 8, 28, 23)),
          _started(utcMicros(2026, 8, 28, 23, 0, 1)),
          _opened(utcMicros(2026, 8, 29, 10)),
        ]),
        isNull,
      );
      // But a today-started open session beside the day's first open is
      // the ordinary fresh launch — due.
      expect(
        resolveExcludingReport([
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
      expect(resolveExcludingReport([])?.resident, StripResident.energyCheckIn);
      expect(
        resolveExcludingReport([
          _energy(utcMicros(2026, 8, 28, 10), EnergyLevel.low),
        ])?.resident,
        StripResident.energyCheckIn,
        reason: 'yesterday\'s answer answers nothing today',
      );
    });
  });

  group('the derivation is pure — no write path (AD-3)', () {
    test('the same log resolves twice to the same resident', () {
      final entries = [_opened(utcMicros(2026, 8, 29, 9))];
      expect(
        resolveExcludingReport(entries)?.resident,
        StripResident.energyCheckIn,
      );
      expect(
        resolveExcludingReport(entries)?.resident,
        StripResident.energyCheckIn,
      );
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
        // The 2-5 read, wrapper-shaped: the report excluded so the
        // frame's day — not the report's due week — is what this test
        // pins.
        excludeResidents: const {StripResident.weeklySelfReport},
      );
      expect(state?.resident, StripResident.energyCheckIn);
    });
  });

  group('the weekly self-report eligibility (matrix rows, SM-2, FR-4)', () {
    ReportAnsweredEntry answer(int micros, int value, int week) =>
        ReportAnsweredEntry(
          id: 'report-$micros-$value-$week',
          instantUtcMicros: micros,
          offsetSeconds: 0,
          value: value,
          week: week,
        );

    // The week identities the 2026-08-29/30 clocks sit in, off the one
    // Calendar: the week anchored Monday 2026-08-17 is ordinal 1389
    // (its Sunday is the 23rd), the week anchored Monday 2026-08-24 is
    // ordinal 1390 (its Sunday is the 30th), and the week anchored
    // Monday 2026-08-31 is ordinal 1391 — weave_test pins the same
    // numbers for the zone ring.
    const weekOfAug17 = 1389;
    const weekOfAug24 = 1390;

    test('Sunday\'s first opening with the due week unanswered — the '
        'report wins and carries the Sunday\'s own week; the check-in '
        'is displaced, not consumed (matrix: Sunday first opening)', () {
      // Sunday 2026-08-30 12:00 UTC: the running week is the one this
      // Sunday closes — the −0 arm of the due-week arithmetic.
      final at = utcMicros(2026, 8, 30, 12);
      final entries = [
        _opened(utcMicros(2026, 8, 30, 9)),
        _started(utcMicros(2026, 8, 30, 9, 0, 1)),
      ];
      final state = resolve(entries, at);
      expect(state?.resident, StripResident.weeklySelfReport);
      expect(state?.reportWeekOrdinal, weekOfAug24);

      // Displaced, not consumed: the same opening still holds the
      // check-in the moment the report leaves the walk — the excluded
      // read is the deterministic handoff part 3 renders.
      final checkIn = resolveExcludingReport(entries, at);
      expect(checkIn?.resident, StripResident.energyCheckIn);
      expect(checkIn?.reportWeekOrdinal, isNull);
    });

    test('weekday persistence — the latest week whose Sunday has '
        'arrived, on Saturday before it and on every day after it '
        '(matrix: weekday persistence)', () {
      // Saturday 2026-08-29 (the base clock): the running week's
      // Sunday (the 30th) has not arrived, so the due week is the one
      // before — anchored 2026-08-17.
      final saturday = resolve([
        _opened(utcMicros(2026, 8, 29, 9)),
        _started(utcMicros(2026, 8, 29, 9, 0, 1)),
      ]);
      expect(saturday?.resident, StripResident.weeklySelfReport);
      expect(saturday?.reportWeekOrdinal, weekOfAug17);

      // Monday 2026-08-31 and Saturday 2026-09-05: the 08-24 week's
      // Sunday has arrived, so the same week stays due on every later
      // day of it — persistence is the −1 arm holding, never stored
      // state.
      final monday = resolve([
        _opened(utcMicros(2026, 8, 31, 9)),
        _started(utcMicros(2026, 8, 31, 9, 0, 1)),
      ], utcMicros(2026, 8, 31, 12));
      expect(monday?.resident, StripResident.weeklySelfReport);
      expect(monday?.reportWeekOrdinal, weekOfAug24);
      final nextSaturday = resolve([
        _opened(utcMicros(2026, 9, 5, 9)),
        _started(utcMicros(2026, 9, 5, 9, 0, 1)),
      ], utcMicros(2026, 9, 5, 12));
      expect(nextSaturday?.resident, StripResident.weeklySelfReport);
      expect(nextSaturday?.reportWeekOrdinal, weekOfAug24);

      // And an answer on any later day of the week counts — the
      // carried week is the whole match, never the instant re-derived.
      final answeredMidWeek = resolve([
        _opened(utcMicros(2026, 9, 3, 17)),
        _started(utcMicros(2026, 9, 3, 17, 0, 1)),
        answer(utcMicros(2026, 9, 3, 18), 2, weekOfAug24),
      ], utcMicros(2026, 9, 3, 18, 30));
      expect(answeredMidWeek?.resident, isNot(StripResident.weeklySelfReport));
      expect(
        answeredMidWeek?.resident,
        StripResident.energyCheckIn,
        reason:
            'the Thursday answer closed the 08-24 week — the '
            'check-in takes the slot in that same opening',
      );
    });

    test('the next Sunday supersedes, never accumulates — at most one '
        'pending, the superseded week has no data point (matrix: '
        'next-Sunday supersession)', () {
      // Week 1389 stands unanswered into Sunday 2026-08-30: the due
      // week advances to the Sunday's own — never two pending, the
      // state carries exactly one ordinal.
      final sunday = resolve([
        _opened(utcMicros(2026, 8, 30, 9)),
        _started(utcMicros(2026, 8, 30, 9, 0, 1)),
      ], utcMicros(2026, 8, 30, 12));
      expect(sunday?.resident, StripResident.weeklySelfReport);
      expect(sunday?.reportWeekOrdinal, weekOfAug24);

      // A late answer to the superseded week counts for nothing — its
      // carried week no longer matches anything, quietly; 1389 simply
      // has no data point.
      final supersededAnswer = resolve([
        _opened(utcMicros(2026, 8, 30, 9)),
        _started(utcMicros(2026, 8, 30, 9, 0, 1)),
        answer(utcMicros(2026, 8, 30, 10), 4, weekOfAug17),
      ], utcMicros(2026, 8, 30, 10, 30));
      expect(supersededAnswer?.resident, StripResident.weeklySelfReport);
      expect(supersededAnswer?.reportWeekOrdinal, weekOfAug24);

      // And once the due week itself is answered, no third target
      // appears: nothing is pending again until the next Sunday.
      final answered = resolve([
        _opened(utcMicros(2026, 8, 30, 9)),
        _started(utcMicros(2026, 8, 30, 9, 0, 1)),
        answer(utcMicros(2026, 8, 30, 10), 4, weekOfAug24),
      ], utcMicros(2026, 8, 30, 10, 30));
      expect(answered?.resident, StripResident.energyCheckIn);
    });

    test('the due week\'s answer landing mid-opening hands the slot to '
        'the check-in in that same opening (matrix: displaced '
        'check-in)', () {
      // Both eligible at the Saturday first opening: the report wins
      // by the order, and the check-in is delayed, not displaced for
      // the day.
      final opening = [
        _opened(utcMicros(2026, 8, 29, 9)),
        _started(utcMicros(2026, 8, 29, 9, 0, 1)),
      ];
      expect(resolve(opening)?.resident, StripResident.weeklySelfReport);

      // The answer lands as a row after the opening delimiter — the
      // day's earliest row is still the open, so the first opening is
      // still underway and the check-in takes the slot at once.
      final handed = resolve([
        ...opening,
        answer(utcMicros(2026, 8, 29, 9, 30), 3, weekOfAug17),
      ], utcMicros(2026, 8, 29, 9, 45));
      expect(handed?.resident, StripResident.energyCheckIn);
      expect(handed?.reportWeekOrdinal, isNull);
    });

    test('an energy answer never silences the report — the report\'s '
        'gate is the opening and the week alone', () {
      // The instruments gate independently (SM-2, FR-4): the day is
      // energy-answered, but `answeredToday` kills only the check-in —
      // only the check-in is energy-gated — and the day's earliest row
      // is the open, so the first opening is still underway. A baja
      // answer resolves the day's battery and leaves the weekly
      // question standing; the day's row answers nothing for the week.
      final state = resolve([
        _opened(utcMicros(2026, 8, 29, 9)),
        _energy(utcMicros(2026, 8, 29, 9, 30), EnergyLevel.low),
      ]);
      expect(state?.resident, StripResident.weeklySelfReport);
      expect(state?.reportWeekOrdinal, weekOfAug17);
    });

    test('a future-dated answer row is excluded — the report stays '
        'pending, quietly; an answer at exactly the read instant counts '
        '(matrix: future-dated answer)', () {
      // Strictly after the read instant: the row asserts nothing yet.
      expect(
        resolve([
          _opened(utcMicros(2026, 8, 29, 9)),
          _started(utcMicros(2026, 8, 29, 9, 0, 1)),
          answer(utcMicros(2026, 8, 29, 13), 2, weekOfAug17),
        ])?.resident,
        StripResident.weeklySelfReport,
        reason:
            'the row\'s instant is after the read instant — it '
            'asserts nothing yet',
      );

      // At exactly the read instant — the answer fold's `<=`, the
      // energy seam's own boundary: the row counts, the week is
      // answered, and the displaced check-in takes the slot in that
      // opening. Only rows strictly after the read instant assert
      // nothing yet.
      final handed = resolve([
        _opened(utcMicros(2026, 8, 29, 9)),
        _started(utcMicros(2026, 8, 29, 9, 0, 1)),
        answer(now, 3, weekOfAug17),
      ], now);
      expect(handed?.resident, StripResident.energyCheckIn);
    });

    test('a foreign-week answer row counts for nothing — the carried '
        'week is the whole match (matrix: foreign-week answer)', () {
      expect(
        resolve([
          _opened(utcMicros(2026, 8, 29, 9)),
          _started(utcMicros(2026, 8, 29, 9, 0, 1)),
          answer(utcMicros(2026, 8, 29, 9, 30), 2, weekOfAug17 - 1),
        ])?.resident,
        StripResident.weeklySelfReport,
      );
      expect(
        resolve([
          _opened(utcMicros(2026, 8, 29, 9)),
          _started(utcMicros(2026, 8, 29, 9, 0, 1)),
          answer(utcMicros(2026, 8, 29, 9, 30), 2, weekOfAug17 + 1),
        ])?.resident,
        StripResident.weeklySelfReport,
      );
    });

    test('the read instant\'s own frame decides the due week (matrix: '
        'own-offset read)', () {
      // 02:30 UTC on 2026-08-30, read with +02:00: the wall clock
      // reads 04:30 Sunday — past the boundary — so the due week is
      // the Sunday\'s own (the −0 arm).
      final sundayFrame = deriveStrip(
        entries: [_opened(utcMicros(2026, 8, 29, 9))],
        instantUtcMicros: utcMicros(2026, 8, 30, 2, 30),
        offsetSeconds: 7200,
      );
      expect(sundayFrame?.resident, StripResident.weeklySelfReport);
      expect(sundayFrame?.reportWeekOrdinal, weekOfAug24);

      // The same instant read with 00:00: the wall clock reads 02:30
      // Saturday — still the 29th's domestic day — so the due week is
      // the one before (the −1 arm).
      final saturdayFrame = deriveStrip(
        entries: [_opened(utcMicros(2026, 8, 29, 9))],
        instantUtcMicros: utcMicros(2026, 8, 30, 2, 30),
        offsetSeconds: 0,
      );
      expect(saturdayFrame?.resident, StripResident.weeklySelfReport);
      expect(saturdayFrame?.reportWeekOrdinal, weekOfAug17);
    });

    test('a crossing 04:00 with no app_opened in the crossed-into day — '
        'the report shows once (clause 1); answered during the '
        'crossing, it is gone (matrix: crossing 04:00)', () {
      final crossing = [
        _opened(utcMicros(2026, 8, 28, 23)),
        _started(utcMicros(2026, 8, 28, 23, 0, 1)),
      ];
      final read = resolve(crossing, utcMicros(2026, 8, 29, 5));
      expect(read?.resident, StripResident.weeklySelfReport);
      expect(read?.reportWeekOrdinal, weekOfAug17);

      // Answered during the crossing: the report is gone and the
      // check-in — displaced, unresolved — takes the slot.
      final answered = resolve([
        ...crossing,
        answer(utcMicros(2026, 8, 29, 5, 30), 1, weekOfAug17),
      ], utcMicros(2026, 8, 29, 6));
      expect(answered?.resident, StripResident.energyCheckIn);
    });

    test('the same sitting crossing into Sunday asks the Sunday\'s own '
        'week — the −0 arm at a 04:00 crossing', () {
      // The sitting above, one day on: its Saturday read asked
      // weekOfAug17 (the −1 arm), and the week flips with the day at
      // 04:00 — Sunday holds no app_opened row, so clause 1 makes the
      // crossing read the Sunday's first opening and the due week is
      // the one that Sunday closes (the −0 arm), never the frame the
      // sitting started in.
      final read = resolve([
        _opened(utcMicros(2026, 8, 28, 23)),
        _started(utcMicros(2026, 8, 28, 23, 0, 1)),
      ], utcMicros(2026, 8, 30, 5));
      expect(read?.resident, StripResident.weeklySelfReport);
      expect(read?.reportWeekOrdinal, weekOfAug24);
    });

    test('a second opening the same day hides the report by the gate '
        'alone; it returns at the next day\'s first opening (matrix: '
        'second opening)', () {
      expect(
        resolve([
          _opened(utcMicros(2026, 8, 30, 9)),
          _ended(utcMicros(2026, 8, 30, 9, 30)),
          _opened(utcMicros(2026, 8, 30, 10)),
          _started(utcMicros(2026, 8, 30, 10, 0, 1)),
        ], utcMicros(2026, 8, 30, 11)),
        isNull,
        reason:
            'the gate hides every resident, never a stored '
            'dismissal (AD-21)',
      );

      // The next day's first opening: the 08-24 week is still the
      // latest whose Sunday arrived — Monday persistence again.
      final monday = resolve([
        _opened(utcMicros(2026, 8, 31, 9)),
        _started(utcMicros(2026, 8, 31, 9, 0, 1)),
      ], utcMicros(2026, 8, 31, 12));
      expect(monday?.resident, StripResident.weeklySelfReport);
      expect(monday?.reportWeekOrdinal, weekOfAug24);
    });

    test('a pre-open report row betrays the consumed opening — the '
        'report waits for the next day (matrix: pre-open answer row)', () {
      final entries = [
        // A foreign-week answer keeps the due week unanswered, so a
        // null result below can only come from the opening gate.
        answer(utcMicros(2026, 8, 31, 8), 5, weekOfAug17),
        _opened(utcMicros(2026, 8, 31, 9)),
        _started(utcMicros(2026, 8, 31, 9, 0, 1)),
        _ended(utcMicros(2026, 8, 31, 10)),
      ];
      // The answer row is today's earliest row, so the day's lone
      // app_opened is not its first row: the opening was consumed
      // before the open, whatever week that row carries.
      expect(resolve(entries, utcMicros(2026, 8, 31, 12)), isNull);
      // The same log on the next day's first opening still carries the
      // same due week: the foreign answer neither answered nor removed
      // it, and only the prior day's opening was consumed.
      final nextDay = resolve([
        ...entries,
        _opened(utcMicros(2026, 9, 1, 9), id: 'next-open'),
        _started(utcMicros(2026, 9, 1, 9, 0, 1), id: 'next-start'),
      ], utcMicros(2026, 9, 1, 12));
      expect(nextDay?.resident, StripResident.weeklySelfReport);
      expect(nextDay?.reportWeekOrdinal, weekOfAug24);
    });

    test('a bare log reads as the day\'s first opening for the report '
        'too — unexcluded', () {
      // The predicate's clause 1 is literal for every resident: the
      // 2-5 pin holds the excluded read to it, and this one holds the
      // bare read — an empty log resolves the report, not nothing. The
      // shell's lifecycle guarantee (the open row lands before the
      // surface reads) is what makes this the crossing case in
      // production, never a bare log on screen.
      expect(resolve([])?.resident, StripResident.weeklySelfReport);
      expect(resolve([])?.reportWeekOrdinal, weekOfAug17);
    });

    test('the exclusion seam — skipped by the walk, read-scoped, '
        'writing nothing (matrix: exclusion seam)', () {
      final entries = [
        _opened(utcMicros(2026, 8, 29, 9)),
        _started(utcMicros(2026, 8, 29, 9, 0, 1)),
      ];
      // The report excluded: the walk falls through to the check-in —
      // the slot handoff as a pure read.
      expect(
        resolveExcludingReport(entries)?.resident,
        StripResident.energyCheckIn,
      );
      // Read-scoped: the same log without the exclusion resolves the
      // same report the shell cannot render yet.
      expect(resolve(entries)?.resident, StripResident.weeklySelfReport);
      // Both excluded: nothing is eligible, nothing is invented.
      expect(
        resolve(entries, now, const {
          StripResident.weeklySelfReport,
          StripResident.energyCheckIn,
        }),
        isNull,
      );
      // And the reads wrote nothing (AD-3).
      expect(entries, hasLength(2));
    });
  });
}

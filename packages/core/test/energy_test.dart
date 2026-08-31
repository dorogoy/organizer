import 'package:core/energy/energy.dart';
import 'package:core/log/log_entry.dart';
import 'package:test/test.dart';

import 'test_util.dart';

EnergySetEntry _energySet(
  int micros,
  EnergyLevel level, {
  int offsetSeconds = 7200,
}) => EnergySetEntry(
  id: 'energy-$micros',
  instantUtcMicros: micros,
  offsetSeconds: offsetSeconds,
  level: level,
);

void main() {
  // "Now" for every test: 2026-08-29 20:00 in a +02:00 frame (18:00 UTC).
  const nowOffsetSeconds = 7200;
  final nowUtcMicros = utcMicros(2026, 8, 29, 18);

  group('the day-scoped rule (matrix: energy in-day)', () {
    test('no observations at all — full', () {
      expect(
        deriveEnergyForLivePool(const [], nowUtcMicros, nowOffsetSeconds),
        EnergyLevel.full,
      );
    });

    test('the last observation of the current day wins, across mixed stored offsets', () {
      final observations = <EnergyObservation>[
        // Yesterday evening (wall 2026-08-28 21:00 +02:00): ignored.
        (
          level: EnergyLevel.low,
          instantUtcMicros: utcMicros(2026, 8, 28, 19),
          offsetSeconds: 7200,
        ),
        // Today, earlier (wall 09:00 +02:00).
        (
          level: EnergyLevel.full,
          instantUtcMicros: utcMicros(2026, 8, 29, 7),
          offsetSeconds: 7200,
        ),
        // Today, later — stored in a traveller's +00:00 frame (wall
        // 17:30 UTC): a different frame, still the same domestic day.
        (
          level: EnergyLevel.low,
          instantUtcMicros: utcMicros(2026, 8, 29, 17, 30),
          offsetSeconds: 0,
        ),
      ];
      expect(
        deriveEnergyForLivePool(observations, nowUtcMicros, nowOffsetSeconds),
        EnergyLevel.low,
      );
    });

    test("an observation whose own frame says yesterday is excluded, even though the caller's frame would say today", () {
      // 06:00 UTC stored with −05:00: its own wall clock reads 01:00 on
      // 2026-08-29 — before 04:00, so its own domestic day is 2026-08-28
      // and it is excluded. Scoping it in the caller's +02:00 frame
      // (wall 08:00, today) would wrongly let its newer instant win.
      final observations = <EnergyObservation>[
        (
          level: EnergyLevel.full,
          instantUtcMicros: utcMicros(2026, 8, 29, 5), // wall 07:00, today
          offsetSeconds: 7200,
        ),
        (
          level: EnergyLevel.low, // own wall 01:00 — yesterday's day
          instantUtcMicros: utcMicros(2026, 8, 29, 6),
          offsetSeconds: -18000,
        ),
      ];
      expect(
        deriveEnergyForLivePool(observations, nowUtcMicros, nowOffsetSeconds),
        EnergyLevel.full,
      );
    });

    test("an observation whose own frame says today is included, even though the caller's frame alone would say yesterday", () {
      // 01:00 UTC stored with +11:00: its own wall clock reads 12:00 on
      // 2026-08-29 — today, so it counts. Scoping it in the caller's
      // +02:00 frame (wall 03:00, before 04:00 → 2026-08-28) would
      // wrongly drop it.
      final observations = <EnergyObservation>[
        (
          level: EnergyLevel.low, // own wall 12:00 — today
          instantUtcMicros: utcMicros(2026, 8, 29, 1),
          offsetSeconds: 39600,
        ),
      ];
      expect(
        deriveEnergyForLivePool(observations, nowUtcMicros, nowOffsetSeconds),
        EnergyLevel.low,
      );
    });

    test('list order does not decide — the newest instant of the day does', () {
      final newestLast = <EnergyObservation>[
        (
          level: EnergyLevel.full,
          instantUtcMicros: utcMicros(2026, 8, 29, 7),
          offsetSeconds: 7200,
        ),
        (
          level: EnergyLevel.low,
          instantUtcMicros: utcMicros(2026, 8, 29, 8),
          offsetSeconds: 7200,
        ),
      ];
      final newestFirst = <EnergyObservation>[
        (
          level: EnergyLevel.low,
          instantUtcMicros: utcMicros(2026, 8, 29, 10),
          offsetSeconds: 7200,
        ),
        (
          level: EnergyLevel.full,
          instantUtcMicros: utcMicros(2026, 8, 29, 9),
          offsetSeconds: 7200,
        ),
      ];
      expect(
        deriveEnergyForLivePool(newestLast, nowUtcMicros, nowOffsetSeconds),
        EnergyLevel.low,
      );
      expect(
        deriveEnergyForLivePool(newestFirst, nowUtcMicros, nowOffsetSeconds),
        EnergyLevel.low,
      );
    });

    test(
      'exact-microsecond ties resolve to the later-in-input observation',
      () {
        final tie = utcMicros(2026, 8, 29, 9);
        final lowThenMedium = <EnergyObservation>[
          (level: EnergyLevel.low, instantUtcMicros: tie, offsetSeconds: 7200),
          (
            level: EnergyLevel.medium,
            instantUtcMicros: tie,
            offsetSeconds: 7200,
          ),
        ];
        final mediumThenLow = <EnergyObservation>[
          (
            level: EnergyLevel.medium,
            instantUtcMicros: tie,
            offsetSeconds: 7200,
          ),
          (level: EnergyLevel.low, instantUtcMicros: tie, offsetSeconds: 7200),
        ];
        expect(
          deriveEnergyForLivePool(
            lowThenMedium,
            nowUtcMicros,
            nowOffsetSeconds,
          ),
          EnergyLevel.medium,
        );
        expect(
          deriveEnergyForLivePool(
            mediumThenLow,
            nowUtcMicros,
            nowOffsetSeconds,
          ),
          EnergyLevel.low,
        );
      },
    );

    test('an observation after civil midnight still belongs to yesterday', () {
      // Wall 2026-08-29 00:30 +02:00 is inside the 2026-08-28 day
      // (AD-4's [04:00, next 04:00) window) — the night does not re-widen
      // anything.
      final observations = <EnergyObservation>[
        (
          level: EnergyLevel.low,
          instantUtcMicros: utcMicros(2026, 8, 28, 22, 30),
          offsetSeconds: 7200,
        ),
      ];
      expect(
        deriveEnergyForLivePool(observations, nowUtcMicros, nowOffsetSeconds),
        EnergyLevel.full,
      );
    });
  });

  group('the day boundary resets to full (matrix: energy boundary)', () {
    test('only-yesterday observations default to full past 04:00', () {
      final observations = <EnergyObservation>[
        (
          level: EnergyLevel.low,
          instantUtcMicros: utcMicros(2026, 8, 28, 21),
          offsetSeconds: 7200,
        ),
        (
          level: EnergyLevel.medium,
          instantUtcMicros: utcMicros(2026, 8, 28, 10),
          offsetSeconds: 0,
        ),
      ];
      expect(
        deriveEnergyForLivePool(observations, nowUtcMicros, nowOffsetSeconds),
        EnergyLevel.full,
      );
    });

    test(
      'the first observation of a day, at exactly 04:00:00.000000, is in-day',
      () {
        final observations = <EnergyObservation>[
          (
            level: EnergyLevel.low,
            instantUtcMicros: utcMicros(2026, 8, 29, 2),
            offsetSeconds: 7200,
          ),
        ];
        expect(
          deriveEnergyForLivePool(observations, nowUtcMicros, nowOffsetSeconds),
          EnergyLevel.low,
        );
      },
    );

    test('the last microsecond before 04:00 belongs to the old day', () {
      final observations = <EnergyObservation>[
        (
          level: EnergyLevel.low,
          instantUtcMicros: utcMicros(2026, 8, 29, 1, 59, 59, 999, 999),
          offsetSeconds: 7200,
        ),
      ];
      expect(
        deriveEnergyForLivePool(observations, nowUtcMicros, nowOffsetSeconds),
        EnergyLevel.full,
      );
    });
  });

  group('the derivation is pure — no write path', () {
    test('same input twice, same level; the input is untouched', () {
      final observations = <EnergyObservation>[
        (
          level: EnergyLevel.medium,
          instantUtcMicros: utcMicros(2026, 8, 29, 9),
          offsetSeconds: 7200,
        ),
        (
          level: EnergyLevel.low,
          instantUtcMicros: utcMicros(2026, 8, 29, 11),
          offsetSeconds: 3600,
        ),
      ];
      final snapshot = List<EnergyObservation>.of(observations);
      final first = deriveEnergyForLivePool(
        observations,
        nowUtcMicros,
        nowOffsetSeconds,
      );
      final second = deriveEnergyForLivePool(
        observations,
        nowUtcMicros,
        nowOffsetSeconds,
      );
      expect(first, EnergyLevel.low);
      expect(identical(first, second), isTrue); // enum values are canonical
      expect(observations, snapshot);
    });
  });

  group('the EnergyLevel vocabulary', () {
    test('exactly the three semantic levels', () {
      expect(EnergyLevel.values, <EnergyLevel>[
        EnergyLevel.full,
        EnergyLevel.medium,
        EnergyLevel.low,
      ]);
    });

    test('the stable wire ints are pinned: full 0, medium 1, low 2 '
        '(Story 2.5, AD-23)', () {
      expect(energyLevelWireOf(EnergyLevel.full), 0);
      expect(energyLevelWireOf(EnergyLevel.medium), 1);
      expect(energyLevelWireOf(EnergyLevel.low), 2);
      expect(energyLevelOfWire(0), EnergyLevel.full);
      expect(energyLevelOfWire(1), EnergyLevel.medium);
      expect(energyLevelOfWire(2), EnergyLevel.low);
      expect(energyLevelOfWire(null), isNull);
      expect(energyLevelOfWire(3), isNull);
      expect(energyLevelOfWire(-1), isNull);
    });
  });

  group('the seam (Story 2.5): stored rows map at deriveLivePoolEnergy, '
      'never at each caller', () {
    test('the day\'s last energy_set row decides the level', () {
      final log = <LogEntry>[
        MomentEntry(
          id: 'open-1',
          instantUtcMicros: utcMicros(2026, 8, 29, 7),
          offsetSeconds: 7200,
          kind: LogKind.appOpened,
        ),
        _energySet(utcMicros(2026, 8, 29, 8), EnergyLevel.medium),
        _energySet(utcMicros(2026, 8, 29, 9), EnergyLevel.low),
      ];
      expect(
        deriveLivePoolEnergy(log, nowUtcMicros, nowOffsetSeconds),
        EnergyLevel.low,
      );
    });

    test('yesterday\'s rows only — the day defaults llena, no synthetic '
        'row, never carried across the boundary (AD-4)', () {
      final log = <LogEntry>[
        _energySet(utcMicros(2026, 8, 28, 19), EnergyLevel.low),
      ];
      expect(
        deriveLivePoolEnergy(log, nowUtcMicros, nowOffsetSeconds),
        EnergyLevel.full,
      );
    });

    test('each row scoped in its own stored offset, at the seam exactly '
        'as in the derivation', () {
      // 06:00 UTC stored with −05:00: its own wall clock reads 01:00 on
      // 2026-08-29 — before 04:00, so its own domestic day is
      // 2026-08-28 and it is excluded even though its instant is newer.
      final log = <LogEntry>[
        _energySet(utcMicros(2026, 8, 29, 5), EnergyLevel.full),
        _energySet(
          utcMicros(2026, 8, 29, 6),
          EnergyLevel.low,
          offsetSeconds: -18000,
        ),
      ];
      expect(
        deriveLivePoolEnergy(log, nowUtcMicros, nowOffsetSeconds),
        EnergyLevel.full,
      );
    });

    test('an empty log is the standing llena default — the seam itself '
        'is the only place the default can change', () {
      expect(
        deriveLivePoolEnergy(const [], nowUtcMicros, nowOffsetSeconds),
        EnergyLevel.full,
      );
    });
  });
}

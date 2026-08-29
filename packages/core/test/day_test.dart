import 'package:core/day/calendar.dart';
import 'package:test/test.dart';

import 'test_util.dart';

const int _microsPerDay = 24 * 60 * 60 * 1000 * 1000;

void main() {
  const calendar = Calendar();

  group('a mid-day instant (matrix: mid-day)', () {
    test('10:00 local +02:00 lands on its own labelled day', () {
      // 2026-08-29 10:00 +02:00 == 08:00 UTC; 2026-08-29 is a Saturday.
      final day = calendar.dayOf(utcMicros(2026, 8, 29, 8), 7200);
      expect(day.label, '2026-08-29');
      expect(day.weekday, 6);
      expect(day.offsetSeconds, 7200);
      expect(day.startUtcMicros, utcMicros(2026, 8, 29, 2)); // 04:00 +02:00
      expect(day.endUtcMicros, utcMicros(2026, 8, 30, 2)); // next 04:00 +02:00
      expect(day.endUtcMicros - day.startUtcMicros, _microsPerDay);
      final instant = utcMicros(2026, 8, 29, 8);
      expect(day.startUtcMicros, lessThanOrEqualTo(instant));
      expect(day.endUtcMicros, greaterThan(instant));
    });
  });

  group('the 04:00 boundary is half-open (matrix: boundary halves)', () {
    test(
      '03:59:59.999999 is the previous day; 04:00:00.000000 is the new one',
      () {
        final justBefore = calendar.dayOf(
          utcMicros(2026, 8, 29, 1, 59, 59, 999, 999),
          7200,
        );
        final atOpen = calendar.dayOf(utcMicros(2026, 8, 29, 2), 7200);
        expect(justBefore.label, '2026-08-28');
        expect(atOpen.label, '2026-08-29');
      },
    );

    test(
      'the halves touch: the old day closes exactly where the new opens',
      () {
        final before = calendar.dayOf(
          utcMicros(2026, 8, 29, 1, 59, 59, 999, 999),
          7200,
        );
        final after = calendar.dayOf(utcMicros(2026, 8, 29, 2), 7200);
        expect(before.endUtcMicros, after.startUtcMicros);
      },
    );

    test(
      'the night before 04:00 still belongs to the day that opened at 04:00',
      () {
        // Wall 2026-08-30 03:59:59.999999 +02:00 — the last microsecond of
        // the 2026-08-29 day.
        final day = calendar.dayOf(
          utcMicros(2026, 8, 30, 1, 59, 59, 999, 999),
          7200,
        );
        final instant = utcMicros(2026, 8, 30, 1, 59, 59, 999, 999);
        expect(day.label, '2026-08-29');
        expect(day.startUtcMicros, lessThan(instant));
        expect(day.endUtcMicros, greaterThan(instant));
      },
    );
  });

  group('the stored offset is the only frame (matrix: stored-offset rule)', () {
    test('recomputing a stored pair is stable, on any calendar instance', () {
      final instant = utcMicros(2026, 8, 29, 18);
      final first = calendar.dayOf(instant, 7200);
      const other = Calendar();
      expect(other.dayOf(instant, 7200), first);
      expect(identical(calendar, other), isTrue); // const-canonical
    });

    test('the offset is an argument, not ambient state', () {
      // The same instant read in two frames is two entries with two
      // stored pairs — each is labelled in its own frame (AD-4); there is
      // no third, device-zone input for a later zone to travel through.
      final instant = utcMicros(2026, 8, 29, 2);
      expect(calendar.dayOf(instant, 7200).label, '2026-08-29');
      expect(calendar.dayOf(instant, 0).label, '2026-08-28');
    });
  });

  group('travel: one instant, two stored frames (matrix: travel)', () {
    test(
      'each entry is labelled in its own frame; neither re-dates the other',
      () {
        final instant = utcMicros(2026, 8, 29, 20); // 20:00 UTC
        final utcFrame = calendar.dayOf(instant, 0); // wall 20:00 Aug 29
        final plus14 = calendar.dayOf(instant, 50400); // wall 10:00 Aug 30
        expect(utcFrame.label, '2026-08-29');
        expect(utcFrame.startUtcMicros, utcMicros(2026, 8, 29, 4));
        expect(utcFrame.endUtcMicros, utcMicros(2026, 8, 30, 4));
        expect(plus14.label, '2026-08-30');
        expect(
          plus14.startUtcMicros,
          utcMicros(2026, 8, 29, 14),
        ); // 04:00 +14:00
        expect(plus14.endUtcMicros, utcMicros(2026, 8, 30, 14));
        expect(utcFrame == plus14, isFalse);
      },
    );
  });

  group('the offset domain (real-world UTC offsets, unvalidated)', () {
    test('+14:00 labels in its own frame, window anchored at 04:00 there', () {
      final day = calendar.dayOf(utcMicros(2026, 8, 29, 20), 50400);
      expect(day.label, '2026-08-30'); // wall 10:00 Aug 30
      expect(day.startUtcMicros, utcMicros(2026, 8, 29, 14)); // 04:00 +14:00
      expect(day.endUtcMicros, utcMicros(2026, 8, 30, 14));
      expect(day.endUtcMicros - day.startUtcMicros, _microsPerDay);
    });

    test('−12:00 labels in its own frame, window anchored at 04:00 there', () {
      final day = calendar.dayOf(utcMicros(2026, 8, 29, 20), -43200);
      expect(day.label, '2026-08-29'); // wall 08:00 Aug 29
      expect(day.startUtcMicros, utcMicros(2026, 8, 29, 16)); // 04:00 −12:00
      expect(day.endUtcMicros, utcMicros(2026, 8, 30, 16));
      // The night before 04:00 in that frame belongs to the Aug-28 day.
      final night = calendar.dayOf(
        utcMicros(2026, 8, 29, 15, 59, 59, 999, 999),
        -43200,
      );
      expect(night.label, '2026-08-28');
    });
  });

  group(
    'a DST transition never destroys a period (matrix: spring-forward)',
    () {
      test('the whole Madrid jump night is one day', () {
        // Spain jumps 02:00+01:00 -> 03:00+02:00 on 2026-03-29; the last
        // instant before the jump and the first after it are 1 ms apart and
        // carry different stored offsets.
        final beforeJump = calendar.dayOf(
          utcMicros(2026, 3, 29, 0, 59, 59, 999),
          3600,
        );
        final afterJump = calendar.dayOf(utcMicros(2026, 3, 29, 1), 7200);
        // The matrix's invariant: both instants share one label. Under the
        // 04:00-anchored window (pinned by the boundary rows above) the
        // night hours of civil 2026-03-29 belong to the day that opened at
        // 2026-03-28 04:00 local — computed in each entry's own frame.
        expect(beforeJump, afterJump);
        expect(beforeJump.label, '2026-03-28');
        expect(
          beforeJump.endUtcMicros - beforeJump.startUtcMicros,
          _microsPerDay,
        );
        expect(
          afterJump.endUtcMicros - afterJump.startUtcMicros,
          _microsPerDay,
        );
        // The jump instants sit inside their own frames' windows: the hour
        // Europe skipped is covered, not lost.
        final beforeInstant = utcMicros(2026, 3, 29, 0, 59, 59, 999);
        expect(beforeJump.startUtcMicros, lessThan(beforeInstant));
        expect(beforeJump.endUtcMicros, greaterThan(beforeInstant));
        final afterInstant = utcMicros(2026, 3, 29, 1);
        expect(afterJump.startUtcMicros, lessThan(afterInstant));
        expect(afterJump.endUtcMicros, greaterThan(afterInstant));
      });

      test("the next morning's day opens at 04:00 as always", () {
        // Wall 2026-03-29 04:00:00.000000 +02:00 is the first instant of
        // the 2026-03-29 day — the transition destroyed no day.
        final morning = calendar.dayOf(utcMicros(2026, 3, 29, 2), 7200);
        expect(morning.label, '2026-03-29');
        expect(morning.weekday, 7); // Sunday
        expect(
          morning.startUtcMicros,
          utcMicros(2026, 3, 29, 2),
        ); // 04:00 +02:00
      });
    },
  );

  group('a DST transition never duplicates a period (matrix: fall-back)', () {
    test("both 02:30s of Madrid 2026-10-25 are one day", () {
      // Spain falls back 03:00+02:00 -> 02:00+01:00 on 2026-10-25, so
      // wall 02:30 occurs twice, an hour apart, under two offsets.
      final firstHalf = calendar.dayOf(utcMicros(2026, 10, 25, 0, 30), 7200);
      final secondHalf = calendar.dayOf(utcMicros(2026, 10, 25, 1, 30), 3600);
      expect(firstHalf.label, '2026-10-24');
      expect(secondHalf.label, '2026-10-24');
      expect(firstHalf, secondHalf); // two wall-clock 02:30s, one day
      expect(firstHalf.endUtcMicros - firstHalf.startUtcMicros, _microsPerDay);
      expect(
        secondHalf.endUtcMicros - secondHalf.startUtcMicros,
        _microsPerDay,
      );
    });
  });

  group('the week is anchored on Monday (matrix: week anchor)', () {
    test('Saturday, its Monday and the closing Sunday are one week', () {
      final monday = calendar.dayOf(utcMicros(2026, 8, 24, 12), 0);
      final saturday = calendar.dayOf(utcMicros(2026, 8, 29, 12), 0);
      final sunday = calendar.dayOf(utcMicros(2026, 8, 30, 12), 0);
      expect(monday.weekday, 1);
      expect(saturday.weekday, 6);
      expect(sunday.weekday, 7); // Sunday is the week's last day
      final week = calendar.weekOf(saturday);
      expect(calendar.weekOf(monday), week);
      expect(calendar.weekOf(sunday), week);
      expect(week.label, '2026-08-24');
      expect(week.toString(), 'week of 2026-08-24');
    });

    test('the week spans [Monday 04:00, next Monday 04:00) in its frame', () {
      final week = calendar.weekOf(
        calendar.dayOf(utcMicros(2026, 8, 29, 12), 0),
      );
      expect(week.startUtcMicros, utcMicros(2026, 8, 24, 4));
      expect(week.endUtcMicros, utcMicros(2026, 8, 31, 4));
      expect(week.endUtcMicros - week.startUtcMicros, 7 * _microsPerDay);
      expect(week.offsetSeconds, 0);
    });

    test('the frame is inherited from the containing day', () {
      final week = calendar.weekOf(
        calendar.dayOf(utcMicros(2026, 8, 29, 12), 7200),
      );
      expect(week.offsetSeconds, 7200);
      expect(
        week.startUtcMicros,
        utcMicros(2026, 8, 24, 2),
      ); // Mon 04:00 +02:00
    });

    test(
      'a week crossing the civil-year boundary stays anchored on its Monday',
      () {
        // Friday 2027-01-01 belongs to the week anchored Monday 2026-12-28.
        final friday = calendar.dayOf(utcMicros(2027, 1, 1, 12), 0);
        expect(friday.weekday, 5);
        final week = calendar.weekOf(friday);
        expect(week.label, '2026-12-28');
        expect(week.startUtcMicros, utcMicros(2026, 12, 28, 4));
        expect(week.endUtcMicros, utcMicros(2027, 1, 4, 4));
        // Sunday 2028-01-02 closes the week anchored Monday 2027-12-27.
        final sunday = calendar.dayOf(utcMicros(2028, 1, 2, 12), 0);
        expect(sunday.weekday, 7);
        final closingWeek = calendar.weekOf(sunday);
        expect(closingWeek.label, '2027-12-27');
        expect(closingWeek.endUtcMicros, utcMicros(2028, 1, 3, 4));
      },
    );
  });

  group('the week ordinal (FR-31\'s ring input)', () {
    test(
      'consecutive weeks differ by exactly one across a Monday boundary',
      () {
        // The Sunday and the Monday it hands to: one boundary, one step.
        final sunday = calendar.dayOf(utcMicros(2026, 8, 30, 12), 0);
        final monday = calendar.dayOf(utcMicros(2026, 8, 31, 12), 0);
        final before = calendar.weekOf(sunday).weekOrdinal;
        final after = calendar.weekOf(monday).weekOrdinal;
        expect(after - before, 1);
        // Pinned against the fixed epoch Monday: 1390 whole weeks from
        // 2000-01-03 to 2026-08-24.
        expect(before, 1390);
        expect(after, 1391);
      },
    );

    test('the epoch Monday is ordinal 0; earlier weeks go negative and '
        'still resolve', () {
      expect(
        calendar
            .weekOf(calendar.dayOf(utcMicros(2000, 1, 3, 12), 0))
            .weekOrdinal,
        0,
      );
      // 1999-12-27 and 1999-12-20 are Mondays of the epoch's own frame —
      // one and two weeks before it. Negative ordinals are consistent,
      // never a crash: the consumer's ring normalizes them.
      expect(
        calendar
            .weekOf(calendar.dayOf(utcMicros(1999, 12, 27, 12), 0))
            .weekOrdinal,
        -1,
      );
      expect(
        calendar
            .weekOf(calendar.dayOf(utcMicros(1999, 12, 20, 12), 0))
            .weekOrdinal,
        -2,
      );
    });
  });

  group('the season is the meteorological quarter (matrix: season edges)', () {
    test(
      '2026-11-30 closes autumn; 2026-12-01 opens winter anchored Dec 2026',
      () {
        final autumn = calendar.seasonOf(
          calendar.dayOf(utcMicros(2026, 11, 30, 12), 0),
        );
        final winter = calendar.seasonOf(
          calendar.dayOf(utcMicros(2026, 12, 1, 12), 0),
        );
        expect(autumn.kind, SeasonKind.autumn);
        expect(autumn.anchorYear, 2026);
        expect(autumn.startUtcMicros, utcMicros(2026, 9, 1, 4));
        expect(autumn.endUtcMicros, utcMicros(2026, 12, 1, 4));
        expect(winter.kind, SeasonKind.winter);
        expect(winter.anchorYear, 2026);
        expect(winter.startUtcMicros, utcMicros(2026, 12, 1, 4));
        expect(winter.endUtcMicros, utcMicros(2027, 3, 1, 4));
        expect(autumn.endUtcMicros, winter.startUtcMicros); // no gap
        expect(autumn == winter, isFalse);
        expect(winter.toString(), 'winter 2026');
      },
    );

    test('2027-03-01 opens spring; the frame is inherited', () {
      final spring = calendar.seasonOf(
        calendar.dayOf(utcMicros(2027, 3, 1, 12), 3600),
      );
      expect(spring.kind, SeasonKind.spring);
      expect(spring.anchorYear, 2027);
      expect(spring.startUtcMicros, utcMicros(2027, 3, 1, 3)); // 04:00 +01:00
      expect(spring.endUtcMicros, utcMicros(2027, 6, 1, 3));
      expect(spring.offsetSeconds, 3600);
    });

    test(
      'January and February belong to the winter anchored on their December',
      () {
        final january = calendar.seasonOf(
          calendar.dayOf(utcMicros(2027, 1, 15, 12), 0),
        );
        final december = calendar.seasonOf(
          calendar.dayOf(utcMicros(2026, 12, 1, 12), 0),
        );
        final nextWinter = calendar.seasonOf(
          calendar.dayOf(utcMicros(2027, 12, 1, 12), 0),
        );
        expect(january.kind, SeasonKind.winter);
        expect(january.anchorYear, 2026);
        expect(january, december); // same anchored winter
        expect(january == nextWinter, isFalse); // the next winter is another
      },
    );

    test('summer holds Jun-Aug', () {
      final summer = calendar.seasonOf(
        calendar.dayOf(utcMicros(2026, 7, 15, 12), 0),
      );
      expect(summer.kind, SeasonKind.summer);
      expect(summer.anchorYear, 2026);
      expect(summer.startUtcMicros, utcMicros(2026, 6, 1, 4));
      expect(summer.endUtcMicros, utcMicros(2026, 9, 1, 4));
    });

    test('season boundaries sit on domestic-day boundaries, not midnight', () {
      // Wall 2026-12-01 03:59:59.999999 +00:00 is still the Nov-30 day,
      // so still autumn; 04:00:00.000000 opens winter.
      final nightBefore = calendar.seasonOf(
        calendar.dayOf(utcMicros(2026, 12, 1, 3, 59, 59, 999, 999), 0),
      );
      final atOpen = calendar.seasonOf(
        calendar.dayOf(utcMicros(2026, 12, 1, 4), 0),
      );
      expect(nightBefore.kind, SeasonKind.autumn);
      expect(atOpen.kind, SeasonKind.winter);
    });

    test('the winter anchored Dec 2027 includes leap February and hands to spring 2028 with no gap', () {
      final winter = calendar.seasonOf(
        calendar.dayOf(utcMicros(2028, 2, 29, 12), 0),
      );
      final spring = calendar.seasonOf(
        calendar.dayOf(utcMicros(2028, 3, 1, 12), 0),
      );
      expect(winter.kind, SeasonKind.winter);
      expect(winter.anchorYear, 2027);
      expect(winter.endUtcMicros, utcMicros(2028, 3, 1, 4));
      // Dec 31 + Jan 31 + leap Feb 29 = 91 days, all exactly 24 h.
      expect(winter.endUtcMicros - winter.startUtcMicros, 91 * _microsPerDay);
      expect(spring.kind, SeasonKind.spring);
      expect(spring.anchorYear, 2028);
      expect(spring.startUtcMicros, winter.endUtcMicros); // no gap
      expect(spring == winter, isFalse); // and no duplicate
    });
  });

  group('leap February is an ordinary domestic day', () {
    test('2028-02-29 gets a valid label and weekday', () {
      final day = calendar.dayOf(utcMicros(2028, 2, 29, 12), 0);
      expect(day.label, '2028-02-29');
      expect(day.weekday, 2); // Tuesday
      expect(day.startUtcMicros, utcMicros(2028, 2, 29, 4));
      expect(day.endUtcMicros, utcMicros(2028, 3, 1, 4));
      expect(day.endUtcMicros - day.startUtcMicros, _microsPerDay);
    });
  });

  group('value semantics', () {
    test('day identity is the civil-date label, not the frame', () {
      // Two different instants, two different stored offsets, one label:
      // the fall-back matrix row's "no duplicated day" as the general rule.
      final a = calendar.dayOf(utcMicros(2026, 10, 25, 12), 7200); // wall 14:00
      final b = calendar.dayOf(
        utcMicros(2026, 10, 26, 0, 30),
        3600,
      ); // wall 01:30
      expect(a.label, '2026-10-25');
      expect(b.label, '2026-10-25');
      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });

    test(
      'weeks anchored on the same Monday label across frames are one week',
      () {
        final utcWeek = calendar.weekOf(
          calendar.dayOf(utcMicros(2026, 8, 29, 12), 0),
        );
        final plus2Week = calendar.weekOf(
          calendar.dayOf(utcMicros(2026, 8, 29, 12), 7200),
        );
        expect(utcWeek, plus2Week);
        expect(utcWeek.label, '2026-08-24');
        // Identity is the label; the absolute bounds still live in each
        // frame — equal weeks, different instants.
        expect(utcWeek.startUtcMicros, utcMicros(2026, 8, 24, 4));
        expect(plus2Week.startUtcMicros, utcMicros(2026, 8, 24, 2));
        expect(utcWeek.startUtcMicros, isNot(plus2Week.startUtcMicros));
        expect(utcWeek.hashCode, plus2Week.hashCode);
      },
    );

    test(
      'seasons of one kind and anchor year across frames are one season',
      () {
        final utcSeason = calendar.seasonOf(
          calendar.dayOf(utcMicros(2026, 11, 30, 12), 0),
        );
        final plus2Season = calendar.seasonOf(
          calendar.dayOf(utcMicros(2026, 11, 30, 12), 7200),
        );
        expect(utcSeason, plus2Season);
        expect(utcSeason.kind, SeasonKind.autumn);
        expect(utcSeason.anchorYear, 2026);
        expect(utcSeason.startUtcMicros, isNot(plus2Season.startUtcMicros));
        expect(utcSeason.hashCode, plus2Season.hashCode);
      },
    );

    test('years pad to four digits so labels sort lexicographically', () {
      final day = calendar.dayOf(utcMicros(500, 1, 1, 12), 0);
      expect(day.year, 500);
      expect(day.label, '0500-01-01');
      expect(day.toString(), '0500-01-01');
      expect(day.startUtcMicros, utcMicros(500, 1, 1, 4));
    });

    test('same pair in, same day out — every time', () {
      final instant = utcMicros(2026, 1, 1, 0, 0, 0, 0, 1);
      final expected = calendar.dayOf(instant, -18000);
      for (var i = 0; i < 3; i++) {
        expect(calendar.dayOf(instant, -18000), expected);
        expect(expected.label, '2025-12-31'); // wall 19:00 Dec 31 at -05:00
      }
    });
  });
}

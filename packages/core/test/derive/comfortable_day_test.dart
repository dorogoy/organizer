import 'package:core/derive/comfortable_day.dart';
import 'package:core/log/log_entry.dart';
import 'package:core/pool/pool_fact.dart';
import 'package:test/test.dart';

import '../test_util.dart';

/// The comfortable-day run (Story 7.5, FR-23, AD-26): the pure fold
/// behind the snowball's crossing day — sessions paired as the walk
/// pairs them, `card_done` charged by the walk's session-day rule,
/// marathons judged on the original pocket plus the session's own
/// extensions with no grace, consecutive comfortable days counted
/// back from yesterday, today never counted, and rows after the
/// read instant skipped.
void main() {
  // The matrix's read: Saturday 2026-08-29 12:00 UTC, offset 0 —
  // the established core-suite clock, so yesterday is Friday
  // 2026-08-28 and every domestic day runs 04:00→04:00 UTC.
  const offset = 0;
  final read = utcMicros(2026, 8, 29, 12);

  SessionStartEntry started(
    int micros, {
    int? pocket = 15,
    int offsetSeconds = 0,
    String id = 'start',
  }) => SessionStartEntry(
    id: id,
    instantUtcMicros: micros,
    offsetSeconds: offsetSeconds,
    kind: LogKind.sessionStarted,
    pocketMinutes: pocket,
  );

  MomentEntry ended(int micros, {int offsetSeconds = 0, String id = 'end'}) =>
      MomentEntry(
        id: id,
        instantUtcMicros: micros,
        offsetSeconds: offsetSeconds,
        kind: LogKind.sessionEnded,
      );

  ItemActEntry done(int micros, {int offsetSeconds = 0, String id = 'done'}) =>
      ItemActEntry(
        id: id,
        instantUtcMicros: micros,
        offsetSeconds: offsetSeconds,
        kind: LogKind.cardDone,
        itemId: 'item-a',
        itemOrigin: Origin.shipped,
      );

  SessionExtendEntry extended(int micros, int minutes) => SessionExtendEntry(
    id: 'extend-$micros',
    instantUtcMicros: micros,
    offsetSeconds: offset,
    pocketMinutes: minutes,
  );

  /// One comfortable day: a 15-minute pocketed session at 09:00 with
  /// a `card_done` inside it, closed [endMinute] minutes past nine.
  List<LogEntry> comfortableDay(
    int day, {
    int? pocket = 15,
    int endMinute = 10,
  }) => [
    started(utcMicros(2026, 8, day, 9), pocket: pocket, id: 'start-$day'),
    done(utcMicros(2026, 8, day, 9, 5), id: 'done-$day'),
    ended(utcMicros(2026, 8, day, 9, endMinute), id: 'end-$day'),
  ];

  /// [n] consecutive comfortable days ending yesterday (Aug 28):
  /// days 29-n … 28.
  List<LogEntry> comfortableDays(int n) => [
    for (var day = 29 - n; day <= 28; day++) ...comfortableDay(day),
  ];

  int runOf(List<LogEntry> entries, [int? at]) => comfortableDayRunLength(
    entries: entries,
    instantUtcMicros: at ?? read,
    offsetSeconds: offset,
  );

  test('ten consecutive comfortable days ending yesterday — the run '
      'reads ten (the crossing input, FR-23)', () {
    expect(runOf(comfortableDays(10)), 10);
  });

  test('zero rows — the run reads zero (the empty log owes nothing)', () {
    expect(runOf(const []), 0);
  });

  test('yesterday absent — zero: any non-comfortable day, absence '
      'included, breaks the chain', () {
    // Aug 19–27 comfortable, Aug 28 (yesterday) holding nothing: the
    // chain ends at the empty yesterday, so the run reads zero — a
    // nine-day run ending Aug 27 owes nothing on Saturday's read.
    final withoutYesterday = [
      for (var day = 19; day <= 27; day++) ...comfortableDay(day),
    ];
    expect(runOf(withoutYesterday), 0);
    // The control arm: nine days ending yesterday read nine.
    expect(runOf(comfortableDays(9)), 9);
  });

  test('a missing done in the middle — the chain breaks there', () {
    // Aug 23 (the sixth day back) holds a session but no card_done:
    // not comfortable, so the run counts only Aug 24–28.
    final entries = [
      for (var day = 19; day <= 28; day++)
        if (day == 23) ...[
          started(utcMicros(2026, 8, 23, 9), id: 'start-23'),
          ended(utcMicros(2026, 8, 23, 9, 10), id: 'end-23'),
        ] else
          ...comfortableDay(day),
    ];
    expect(runOf(entries), 5);
  });

  test('a missing session in the middle — a lone card_done charges its '
      'own day but the day holds no session: the chain breaks there', () {
    final entries = [
      for (var day = 19; day <= 28; day++)
        if (day == 26)
          done(utcMicros(2026, 8, 26, 9, 5), id: 'done-26')
        else
          ...comfortableDay(day),
    ];
    expect(runOf(entries), 2);
  });

  test('a marathon breaks its session\'s own start day — span strictly '
      'beyond the original pocket, no grace', () {
    // Aug 27's session runs 09:00→09:16 — sixteen minutes against a
    // fifteen pocket, one minute beyond: a marathon on Aug 27, so the
    // run counts only Aug 28.
    final entries = [
      for (var day = 19; day <= 28; day++)
        ...comfortableDay(day, endMinute: day == 27 ? 16 : 10),
    ];
    expect(runOf(entries), 1);
  });

  test('span exactly at the pocket — not a marathon: strictly beyond is '
      'the whole judgment (no grace, no threshold band)', () {
    // Every day runs 09:00→09:15 — exactly the fifteen-minute pocket.
    final entries = [
      for (var day = 19; day <= 28; day++)
        ...comfortableDay(day, endMinute: 15),
    ];
    expect(runOf(entries), 10);
  });

  test('a chosen extension is never a marathon — the judgment reads the '
      'original pocket plus that session\'s own extensions (AD-19)', () {
    // Aug 25 runs 09:00→09:20 — twenty minutes against a fifteen
    // pocket, but the sitting accepted one five-minute extension at
    // 09:14: span 20 ≤ 15+5, comfortable.
    final entries = [
      for (var day = 19; day <= 28; day++)
        if (day == 25) ...[
          started(utcMicros(2026, 8, 25, 9), id: 'start-25'),
          extended(utcMicros(2026, 8, 25, 9, 14), 5),
          done(utcMicros(2026, 8, 25, 9, 18), id: 'done-25'),
          ended(utcMicros(2026, 8, 25, 9, 20), id: 'end-25'),
        ] else
          ...comfortableDay(day),
    ];
    expect(runOf(entries), 10);
  });

  test('an extension outside any session sums nothing — the marathon '
      'judgment reads the start row alone (AD-23 tolerance)', () {
    // Aug 24's session runs 09:00→09:18 with a stray extension AFTER
    // its end: eighteen minutes against fifteen is a marathon, the
    // stray row changes nothing.
    final entries = [
      for (var day = 19; day <= 28; day++) ...[
        ...comfortableDay(day, endMinute: day == 24 ? 18 : 10),
        if (day == 24) extended(utcMicros(2026, 8, 24, 9, 19), 5),
      ],
    ];
    expect(runOf(entries), 4);
  });

  test('an unbounded sitting can fire no marathon — a start row with no '
      'pocket is judged never (AD-23)', () {
    // Aug 22's session opens with no pocket and runs an hour: the
    // day still counts (session + done), nothing can call it a
    // marathon.
    final entries = [
      for (var day = 19; day <= 28; day++) ...[
        ...comfortableDay(day, pocket: day == 22 ? null : 15),
        if (day == 22) ended(utcMicros(2026, 8, 22, 10), id: 'end-22-long'),
      ],
    ];
    expect(runOf(entries), 10);
  });

  test('an out-of-range pocket derives as no pocket — never a repair, '
      'never a marathon (AD-23)', () {
    // Aug 21's start carries an imported 99: outside 1–60, the walk
    // reads it as absent, so its two-hour span fires nothing.
    final entries = [
      for (var day = 19; day <= 28; day++) ...[
        ...comfortableDay(day, pocket: day == 21 ? 99 : 15),
        if (day == 21) ended(utcMicros(2026, 8, 21, 11), id: 'end-21-long'),
      ],
    ];
    expect(runOf(entries), 10);
  });

  test('the still-open session is judged to the read instant — a '
      'yesterday sitting left open past its pocket is a marathon on its '
      'own start day', () {
    // Aug 28's session never closes: judged to the read instant
    // (Saturday 12:00), a 27-hour span against fifteen minutes — a
    // marathon on Aug 28, breaking the run at zero.
    final entries = [
      for (var day = 19; day <= 28; day++)
        if (day == 28) ...[
          started(utcMicros(2026, 8, 28, 9), id: 'start-28'),
          done(utcMicros(2026, 8, 28, 9, 5), id: 'done-28'),
        ] else
          ...comfortableDay(day),
    ];
    expect(runOf(entries), 0);
  });

  test('today never counts until it is over — the run ends at yesterday '
      'whatever today holds', () {
    // Ten days ending yesterday, plus today's own comfortable facts
    // (a fresh open sitting inside its pocket with a done): the run
    // reads ten, never eleven.
    final entries = [
      ...comfortableDays(10),
      started(utcMicros(2026, 8, 29, 11, 50), id: 'start-29-open'),
      done(utcMicros(2026, 8, 29, 11, 55), id: 'done-29-open'),
    ];
    expect(runOf(entries), 10);
  });

  test('a superseded session is judged to its supersession instant — '
      'pairing mirrors the walk\'s discipline', () {
    // Aug 20: a start at 09:00 (pocket 15) replaced by a fresh start
    // at 09:10 the same day — the replaced sitting is judged to
    // 09:10 (10 min ≤ 15, no marathon), the done at 09:12 charges
    // the new sitting's own start day, and the end at 09:14 closes
    // it. Comfortable.
    final entries = [
      for (var day = 19; day <= 28; day++)
        if (day == 20) ...[
          started(utcMicros(2026, 8, 20, 9), id: 'start-20-a'),
          started(utcMicros(2026, 8, 20, 9, 10), id: 'start-20-b'),
          done(utcMicros(2026, 8, 20, 9, 12), id: 'done-20'),
          ended(utcMicros(2026, 8, 20, 9, 14), id: 'end-20'),
        ] else
          ...comfortableDay(day),
    ];
    expect(runOf(entries), 10);
  });

  test('a superseded sitting held past its pocket into the next day — '
      'the marathon lands on its OWN start day (AD-19)', () {
    // Aug 27 23:00 (pocket 15) replaced Aug 28 09:10: the replaced
    // sitting's span is judged to the supersession instant — ten
    // hours beyond fifteen minutes — a marathon on Aug 27, its own
    // start day, so the run counts only Aug 28.
    final entries = [
      for (var day = 19; day <= 28; day++)
        if (day == 27) ...[
          started(utcMicros(2026, 8, 27, 23), id: 'start-27-a'),
          started(utcMicros(2026, 8, 28, 9, 10), id: 'start-27-b'),
          done(utcMicros(2026, 8, 28, 9, 12), id: 'done-27b'),
          ended(utcMicros(2026, 8, 28, 9, 14), id: 'end-27b'),
        ] else
          ...comfortableDay(day),
    ];
    expect(runOf(entries), 1);
  });

  test('days before the log\'s first row end the walk — the run counts '
      'only days the log itself holds', () {
    // The log begins Aug 24: five comfortable days stand, and the
    // walk stops before inventing a sixth.
    expect(runOf(comfortableDays(5)), 5);
  });

  test('a card_done charged by the session-day rule — a done past the '
      '04:00 boundary belongs to its session\'s start day, never the '
      'crossed-into day (AD-19)', () {
    // Aug 26's session starts 03:30 on Aug 27's clock — before the
    // 04:00 boundary, so its own domestic day is Aug 26 — with a
    // sixty-minute pocket; the done lands at 04:05, whose OWN civil
    // day is Aug 27, and the end at 04:10: a 40-minute span inside
    // the pocket, no marathon. Session-day charging charges the done
    // to Aug 26 (its session's own start day), so Aug 26 is
    // comfortable and Aug 27 — its own session below, no done of
    // its own — breaks the chain, leaving the run's only day Aug
    // 28: the run reads one. Under OWN-day charging the done would
    // land on Aug 27 instead, Aug 26 would hold no done, and the run
    // would read zero — the fixture discriminates the attribution
    // mirror exactly because the done's own civil day (Aug 27)
    // differs from its session's start day (Aug 26): a 00:05 done,
    // whose own day is still Aug 26 under the 04:00 boundary, is
    // charged Aug 26 by both rules and cannot tell them apart.
    final entries = [
      for (var day = 19; day <= 28; day++)
        if (day == 26) ...[
          started(utcMicros(2026, 8, 27, 3, 30), pocket: 60, id: 'start-26'),
          done(utcMicros(2026, 8, 27, 4, 5), id: 'done-26'),
          ended(utcMicros(2026, 8, 27, 4, 10), id: 'end-26'),
        ] else if (day == 27) ...[
          started(utcMicros(2026, 8, 27, 9), id: 'start-27'),
          ended(utcMicros(2026, 8, 27, 9, 10), id: 'end-27'),
        ] else
          ...comfortableDay(day),
    ];
    expect(runOf(entries), 1);
  });

  test('rows after the read instant are skipped — the readers\' '
      'convention, quiet (AD-3)', () {
    // A future-dated marathon pair (Aug 30, after the Saturday read)
    // and a future extension of a standing sitting change nothing.
    final entries = [
      ...comfortableDays(10),
      started(utcMicros(2026, 8, 30, 9), id: 'start-30'),
      done(utcMicros(2026, 8, 30, 9, 5), id: 'done-30'),
      ended(utcMicros(2026, 8, 30, 10), id: 'end-30-marathon'),
      extended(utcMicros(2026, 8, 30, 10, 1), 5),
    ];
    expect(runOf(entries), 10);
  });

  test('each row\'s own stored offset scopes its day (AD-4)', () {
    // A comfortable day written under +02:00: 09:00 wall UTC+2 is
    // 07:00 UTC — still inside Aug 20's domestic window ([04:00,
    // 04:00) computed in its own frame). The ten stand.
    final entries = [
      for (var day = 19; day <= 28; day++)
        if (day == 20) ...[
          started(
            utcMicros(2026, 8, 20, 7),
            offsetSeconds: 7200,
            id: 'start-20',
          ),
          done(
            utcMicros(2026, 8, 20, 7, 5),
            offsetSeconds: 7200,
            id: 'done-20',
          ),
          ended(
            utcMicros(2026, 8, 20, 7, 10),
            offsetSeconds: 7200,
            id: 'end-20',
          ),
        ] else
          ...comfortableDay(day),
    ];
    expect(runOf(entries), 10);
  });
}

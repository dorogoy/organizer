/// The one calendar authority (AD-4): the only code — Dart or Kotlin —
/// that converts an instant into a period.
///
/// A [Calendar] is stateless and const-constructible, and every conversion
/// is a pure function of `(instantUtcMicros, offsetSeconds)`. The API
/// accepts no device-zone input, so re-dating history is unrepresentable:
/// the local offset in force when an entry was written travels with the
/// entry (AD-4), and the entry's day, week and season are computed in that
/// stored offset forever — travel or a clock correction moves nothing
/// already written.
///
/// Three periods exist and no more (AD-4):
///
/// - [Day] — `[04:00 local, 04:00 local next)`, the domestic day. A fixed
///   offset frame holds exactly 24 h in every day — no timezone database,
///   no DST rule engine — so a transition never creates or destroys a
///   period: the fixed-offset frame IS the DST mechanism.
/// - [Week] — seven domestic days anchored on Monday; identity is the
///   Monday label, Sunday is the week's last day, and [Week.weekOrdinal]
///   counts weeks since a fixed epoch Monday for the zone rotation.
/// - [Season] — the meteorological quarter (DJF/MAM/JJA/SON) on
///   domestic-day boundaries, winter anchored on its December.
///
/// No other code computes a date boundary (AD-4; enforcement stays
/// core-test- and review-held, SPINE:242): every later consumer — the
/// weave, zone rotation, sessions, SM-2, seasonal reports, invitations —
/// calls this Calendar rather than reimplementing any boundary math.
/// That includes the week's rotation arithmetic input: the ordinal
/// [Week.weekOrdinal] returns is the one number FR-31's zone ring may
/// reduce, never a second week count beside this Calendar.
///
/// The `offsetSeconds` every method takes is the entry's stored offset.
/// Its real-world domain is UTC offsets — |offset| ≤ 14 h, any
/// second-level value — and real values arrive from the shell as each
/// entry's stored `offsetSeconds`, captured when the event was written.
/// No validation is performed: any int still yields a consistent
/// fixed-offset frame (garbage in, shifted-but-consistent labels out).

library;

/// The domestic day (AD-4): `[04:00 local, 04:00 local next)` computed in
/// a fixed stored-offset frame — exactly 24 h, always.
///
/// The day's identity is its civil-date label (y/m/d) in that frame: the
/// date whose 04:00 opens the window. Start and end instants are derived
/// data, and the frame itself is not identity — entries written under
/// +01:00 and +02:00 across one DST transition share a single day, which
/// is what keeps a transition from destroying or duplicating one.
final class Day {
  const Day._({
    required this.year,
    required this.month,
    required this.day,
    required this.weekday,
    required this.offsetSeconds,
    required this.startUtcMicros,
    required this.endUtcMicros,
  });

  /// The civil year of the label.
  final int year;

  /// The civil month of the label, 1–12.
  final int month;

  /// The civil day of the label, 1–31.
  final int day;

  /// The label date's ISO weekday: Monday = 1 … Sunday = 7.
  final int weekday;

  /// The stored offset this day was computed in, seconds east of UTC —
  /// derived data carried for the period math, never identity.
  final int offsetSeconds;

  /// The instant this day opens: 04:00 local on the label date, in UTC
  /// microseconds since the epoch. Half-open: the start belongs to the
  /// day and the end does not.
  final int startUtcMicros;

  /// The instant this day closes: exactly 24 h after [startUtcMicros] —
  /// a fixed offset frame has no 23 h or 25 h days.
  final int endUtcMicros;

  /// The civil-date label, `y-m-d`, zero-padded — the year to four
  /// digits, month and day to two — so labels sort lexicographically into
  /// chronological order.
  String get label =>
      '${year.toString().padLeft(4, '0')}-${month.toString().padLeft(2, '0')}-${day.toString().padLeft(2, '0')}';

  @override
  String toString() => label;

  @override
  bool operator ==(Object other) =>
      other is Day &&
      other.year == year &&
      other.month == month &&
      other.day == day;

  @override
  int get hashCode => Object.hash(year, month, day);
}

/// The domestic week (AD-4): seven days anchored on Monday, so a zone
/// rotation turns on a boundary the user does not notice, and Sunday is
/// the week's last day.
///
/// Identity is the anchor Monday's civil-date label; the frame is
/// inherited from the containing day.
final class Week {
  const Week._(this.monday, this.endUtcMicros);

  /// The Monday anchoring this week; always `weekday == 1`.
  final Day monday;

  /// The instant this week closes (exclusive): the next Monday's 04:00 in
  /// the same frame.
  final int endUtcMicros;

  /// The instant this week opens (inclusive): [monday]'s 04:00.
  int get startUtcMicros => monday.startUtcMicros;

  /// The frame inherited from the containing day.
  int get offsetSeconds => monday.offsetSeconds;

  /// The anchor Monday's civil-date label — the week's identity.
  String get label => monday.label;

  /// Weeks since the fixed epoch Monday 2000-01-03 — a deterministic
  /// ordinal that grows by exactly one at every week boundary, so a
  /// five-slot ring (FR-31's zone rotation) reads `(ordinal mod 5)` off
  /// this one Calendar and never beside it. Derived from the identity
  /// label, never stored; consecutive weeks differ by exactly 1.
  int get weekOrdinal =>
      DateTime.utc(
        monday.year,
        monday.month,
        monday.day,
      ).difference(DateTime.utc(2000, 1, 3)).inDays ~/
      7;

  @override
  String toString() => 'week of $label';

  @override
  bool operator ==(Object other) => other is Week && other.monday == monday;

  @override
  int get hashCode => monday.hashCode;
}

/// The four meteorological seasons (AD-4): DJF, MAM, JJA, SON.
enum SeasonKind { winter, spring, summer, autumn }

/// The meteorological quarter (AD-4): three civil months on domestic-day
/// boundaries — the season opens at its first month's 04:00, so every
/// domestic day belongs wholly to exactly one season.
///
/// Winter (DJF) straddles the year boundary and is anchored on its
/// December; identity is the kind plus the anchor year.
final class Season {
  const Season._({
    required this.kind,
    required this.anchorYear,
    required this.offsetSeconds,
    required this.startUtcMicros,
    required this.endUtcMicros,
  });

  /// Which quarter this is.
  final SeasonKind kind;

  /// The year the season is named by: the December's year for a winter,
  /// the calendar year for every other quarter.
  final int anchorYear;

  /// The frame inherited from the containing day.
  final int offsetSeconds;

  /// The instant this season opens (inclusive): the first day of its
  /// first month at 04:00 local.
  final int startUtcMicros;

  /// The instant this season closes (exclusive): the next season's open,
  /// in the same frame.
  final int endUtcMicros;

  @override
  String toString() => '${kind.name} $anchorYear';

  @override
  bool operator ==(Object other) =>
      other is Season && other.kind == kind && other.anchorYear == anchorYear;

  @override
  int get hashCode => Object.hash(kind, anchorYear);
}

/// The one instant→period converter (AD-4). Stateless, const-constructible,
/// deterministic: integers in, labels and boundary micros out — computed
/// with `DateTime.utc` arithmetic on the given micros, the only time
/// source this module ever touches.
final class Calendar {
  /// Stateless and const-constructible; every method is a pure function
  /// of its arguments.
  const Calendar();

  static const int _microsPerSecond = 1000 * 1000;
  static const int _microsPerDay = 24 * 60 * 60 * _microsPerSecond;

  /// The domestic day holding [instantUtcMicros], computed in the frame
  /// of [offsetSeconds] — the entry's stored offset, never the device's
  /// current zone (AD-4).
  Day dayOf(int instantUtcMicros, int offsetSeconds) {
    // Reading the offset-shifted instant as UTC yields the wall clock of
    // the fixed-offset frame.
    final wall = DateTime.fromMicrosecondsSinceEpoch(
      instantUtcMicros + offsetSeconds * _microsPerSecond,
      isUtc: true,
    );
    var opens = DateTime.utc(wall.year, wall.month, wall.day);
    if (wall.hour < 4) {
      // The domestic day runs [04:00, next 04:00): wall times before
      // 04:00 belong to the previous civil date's day.
      opens = opens.subtract(const Duration(days: 1));
    }
    return _dayOfLabel(opens.year, opens.month, opens.day, offsetSeconds);
  }

  /// The week holding [day]: seven days anchored on Monday, in [day]'s
  /// inherited frame. Sunday is the returned week's last day. The week's
  /// [Week.weekOrdinal] — the zone rotation's ring input — derives from
  /// the anchor Monday this returns.
  Week weekOf(Day day) {
    final mondayCivil = DateTime.utc(
      day.year,
      day.month,
      day.day,
    ).subtract(Duration(days: day.weekday - 1));
    final monday = _dayOfLabel(
      mondayCivil.year,
      mondayCivil.month,
      mondayCivil.day,
      day.offsetSeconds,
    );
    return Week._(monday, monday.endUtcMicros + 6 * _microsPerDay);
  }

  /// The meteorological season holding [day], in [day]'s inherited frame.
  Season seasonOf(Day day) {
    final (kind, anchorYear) = switch (day.month) {
      1 || 2 => (SeasonKind.winter, day.year - 1),
      12 => (SeasonKind.winter, day.year),
      >= 3 && <= 5 => (SeasonKind.spring, day.year),
      >= 6 && <= 8 => (SeasonKind.summer, day.year),
      _ => (SeasonKind.autumn, day.year),
    };
    final firstMonth = switch (kind) {
      SeasonKind.winter => 12,
      SeasonKind.spring => 3,
      SeasonKind.summer => 6,
      SeasonKind.autumn => 9,
    };
    final (closeYear, closeMonth) = switch (kind) {
      SeasonKind.winter => (anchorYear + 1, 3),
      SeasonKind.spring => (anchorYear, 6),
      SeasonKind.summer => (anchorYear, 9),
      SeasonKind.autumn => (anchorYear, 12),
    };
    return Season._(
      kind: kind,
      anchorYear: anchorYear,
      offsetSeconds: day.offsetSeconds,
      startUtcMicros: _fourAmLocal(
        DateTime.utc(anchorYear, firstMonth, 1),
        day.offsetSeconds,
      ),
      endUtcMicros: _fourAmLocal(
        DateTime.utc(closeYear, closeMonth, 1),
        day.offsetSeconds,
      ),
    );
  }

  Day _dayOfLabel(int year, int month, int day, int offsetSeconds) {
    final civil = DateTime.utc(year, month, day);
    final start = _fourAmLocal(civil, offsetSeconds);
    return Day._(
      year: year,
      month: month,
      day: day,
      weekday: civil.weekday,
      offsetSeconds: offsetSeconds,
      startUtcMicros: start,
      endUtcMicros: start + _microsPerDay,
    );
  }

  /// 04:00 local on [civil]'s date in the offset frame, as UTC
  /// microseconds since the epoch.
  static int _fourAmLocal(DateTime civil, int offsetSeconds) =>
      civil.add(const Duration(hours: 4)).microsecondsSinceEpoch -
      offsetSeconds * _microsPerSecond;
}

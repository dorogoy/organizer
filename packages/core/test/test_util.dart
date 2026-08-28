/// Shared core-test fixture: one UTC instant built from civil parts, as
/// microseconds since the epoch — explicit values only; the core itself
/// reads no clock (AD-3).
int utcMicros(
  int year,
  int month,
  int day, [
  int hour = 0,
  int minute = 0,
  int second = 0,
  int millisecond = 0,
  int microsecond = 0,
]) => DateTime.utc(
  year,
  month,
  day,
  hour,
  minute,
  second,
  millisecond,
  microsecond,
).microsecondsSinceEpoch;

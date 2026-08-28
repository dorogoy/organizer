// The forbidden-vocabulary check's violating fixture: every declaration
// here carries one of the nine banned tokens as a real identifier.

// ignore_for_file: constant_identifier_names, unused_element, unused_field, unused_top_level_property
final int overdueItems = 0;
final int isLateToday = 0;
final int missedWindows = 0;
final int pendingQueue = 0;
final int debtMarks = 0;
final int streakLength = 0;
final int skippedCount = 0;
final int dueDateStamp = 0;
final int backlogSize = 0;

// ALL-CAPS evasion: SCREAMING_SNAKE identifiers segment into the same
// lowercase runs and are findings too.
const int MISSED_WINDOWS = 0;
const int LATE_FLAG = 0;

class BannedShapes {
  static const int skippedCountTotal = 0;

  static int get dueDateAnchor => 0;

  int noOverdueGuarantee() => 0;
}

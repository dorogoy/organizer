// The forbidden-vocabulary check's clean fixture: innocent identifiers the
// segment-aware scan must pass — substring lookalikes, the derived-fact
// `Due` suffix, the vocabulary's own skip act, and the `late` declaration
// modifier (a keyword, never an identifier).

// ignore_for_file: unused_top_level_property
String translate(String input) => input;

bool related(int other) => other > 0;

bool captureIsDue(int now, int anchor) => now - anchor > 172800;

bool warmReturnDue(int lastSeen) => lastSeen > 0;

final String cardSkippedAct = 'card_skipped';

final String slatedForLater = 'later';

final int delayAllowance = 0;

final String delegated = 'delegated';

class CleanShapes {
  static const String databaseFileName = 'fixture';

  final int resolved = 7;
}

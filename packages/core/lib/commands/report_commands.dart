/// The weekly self-report command (AD-3, SM-2, AD-21): the one pure
/// function that computes *what* to append when the weekly self-report
/// is answered — never ids, instants or offsets, which the shell mints
/// at the commit of the answer. A `report_answered` row exists only
/// because this file returned it: it is the kind's single sanctioned
/// minter, so no second writer of report rows can appear silently.
/// Nothing here reads the log — an answer is a fresh act, not a
/// derivation — and nothing here decides eligibility or precedence:
/// that is part 2's derivation over the very rows this minter writes,
/// so this story ships the substrate and no behavior.
///
/// The week arrives as the answered week's `Week.weekOrdinal` — the
/// Calendar's one week identity, computed by the shell's own read and
/// handed in — carried explicitly because the report persists until
/// answered (SM-2's override of the Sunday-only reading): an answer
/// may fall outside the week it reports on, and the instant alone
/// cannot attribute it to one.
///
/// Refusal is silence, on the `setting_changed` shape: a value outside
/// the 1–5 scale returns no content and appends nothing — no error
/// surface exists anywhere to show (the report offers exactly the five
/// numerals, so the refusal is unreachable from the UI and guards only
/// the command boundary). The week needs no guard of its own: every
/// int is a `weekOrdinal` this build can carry, and the Calendar that
/// mints real ones is the shell's to call, not this file's.

library;

import 'package:core/commands/session_commands.dart';
import 'package:core/log/log_entry.dart';

/// `report_answered` for the tapped value — exactly one content row,
/// its whole payload the answer and the week it answers. The shell
/// completes the row — minting the UUIDv7 id, the instant and the
/// offset in force — before the port sees it.
List<LogEntryContent> reportAnswered({required int value, required int week}) {
  if (value < reportScaleLeast || value > reportScaleMost) {
    return const [];
  }
  return [
    (
      kind: LogKind.reportAnswered,
      itemId: null,
      itemOrigin: null,
      stack: null,
      settingKey: null,
      settingValue: null,
      settingTextValue: null,
      pocketMinutes: null,
      energyLevel: null,
      reportValue: value,
      reportWeek: week,
      permission: null,
    ),
  ];
}

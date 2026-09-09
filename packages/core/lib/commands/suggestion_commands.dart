/// The suggestion command (Story 5.13, FR-15, AD-21, AD-14): the one
/// pure function that computes *what* to append when the seasonal
/// suggestion's ✕ is tapped — never ids, instants or offsets, which
/// the shell mints at the commit of the act. A `suggestion_dismissed`
/// row exists only because this file returned it: it is the kind's
/// single sanctioned minter, so no second dismissal writer can appear
/// silently.
///
/// The row rides the existing item-act shape (`epic_activated`'s own
/// precedent, AD-14): the pair names the dismissed Epic Project — its
/// derived stable id and its own origin — and nothing else. The row
/// names the project the user was SHOWN, never one re-derived at tap
/// time: the shell hands in the shown record, so a boundary crossed
/// since the view committed cannot dismiss a different project. The
/// row's only reader is the strip's own eligibility (a same-season
/// dismissal suppresses the project until the season turns, the row's
/// own instant and offset deriving the season); it is never contact
/// (the `consent_declined` register — FR-15's zero-side-effects
/// consequence) and no metric, streak, warm return, energy, weave or
/// composition may change on it.

library;

import 'package:core/commands/session_commands.dart';
import 'package:core/log/log_entry.dart';
import 'package:core/pool/pool_fact.dart';

/// `suggestion_dismissed` for the shown Epic Project — exactly one
/// item-act content row, its whole payload the pair. The shell
/// completes the row — minting the UUIDv7 id, the instant and the
/// offset in force — before the port sees it, and the append rides
/// the shared `LogWriteQueue` like every other write.
List<LogEntryContent> suggestionDismissed({
  required String itemId,
  required Origin origin,
}) {
  return [
    (
      kind: LogKind.suggestionDismissed,
      itemId: itemId,
      itemOrigin: origin,
      stack: null,
      settingKey: null,
      settingValue: null,
      settingTextValue: null,
      pocketMinutes: null,
      energyLevel: null,
      reportValue: null,
      reportWeek: null,
      permission: null,
      sliceCause: null,
      cluster: null,
      enabled: null,
    ),
  ];
}

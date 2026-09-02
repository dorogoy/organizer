/// The permission-refusal command (Story 3.4, FR-32, AD-17, AD-21):
/// the one pure function that computes *what* to append when the user
/// refuses one of the three runtime permissions at the moment its
/// feature was first used — or the system revokes it after grant,
/// which the next press reads identically — never ids, instants or
/// offsets, which the shell mints at the commit of the refusal. A
/// `permission_refused` row exists only because this file returned
/// it: it is the kind's single sanctioned minter, so no second
/// refusal writer can appear silently — the camera and notification
/// stories to come twin this file's shape, they do not fork it.
///
/// The row is a system event, not a user act (AD-21): it asserts a
/// fact that happened, never an absence or an obligation, and its
/// whole payload is the [Permission] it names — no grant, no
/// capability claim and no re-ask state rides along (AD-22's
/// discipline). The entry stands forever; `permissionMayBeAsked`
/// derives false over it and the app never re-asks on its own —
/// reversal lives outside the log, in the system's own settings
/// screen, reached through the Settings row that renders only while
/// a re-grant has something to reactivate.

library;

import 'package:core/commands/session_commands.dart';
import 'package:core/log/log_entry.dart';

/// `permission_refused` for the named permission — exactly one
/// content row, its whole payload the permission's identity. Every
/// member of the enum is nameable (the three permissions are the
/// build's own), so there is no refusal shape here to reach: the
/// shell completes the row — minting the UUIDv7 id, the instant and
/// the offset in force — before the port sees it, and the append
/// rides the shared `LogWriteQueue` like every other write.
List<LogEntryContent> permissionRefuse(Permission permission) {
  return [
    (
      kind: LogKind.permissionRefused,
      itemId: null,
      itemOrigin: null,
      stack: null,
      settingKey: null,
      settingValue: null,
      pocketMinutes: null,
      energyLevel: null,
      reportValue: null,
      reportWeek: null,
      permission: permission,
    ),
  ];
}

/// The energy command (AD-3, AD-4, FR-4): the one pure function that
/// computes *what* to append when the daily check-in is answered — never
/// ids, instants or offsets, which the shell mints at the commit of the
/// tap. An `energy_set` row exists only because this file returned it:
/// it is the kind's single sanctioned minter, so no second writer of
/// energy rows can appear silently. Nothing here reads the log — a tap
/// is a fresh act, not a derivation — and the command bundles nothing:
/// the check-in never deals a card (AD-3's door is `sessionStart`'s
/// alone).
///
/// Refusal is silence, on the `setting_changed` shape: a level this
/// build cannot name returns no content and appends nothing — no error
/// surface exists anywhere to show (the strip offers exactly the three
/// marks, so the refusal is unreachable from the UI and guards only the
/// command boundary). The enum input makes an unnamed level
/// unrepresentable; the guard stands for the boundary's own shape.

library;

import 'package:core/commands/session_commands.dart';
import 'package:core/energy/energy.dart';
import 'package:core/log/log_entry.dart';

/// `energy_set` for the tapped level — exactly one content row, its
/// whole payload the level's stable wire int. The shell completes the
/// row — minting the UUIDv7 id, the instant and the offset in force —
/// before the port sees it.
List<LogEntryContent> energySet({required EnergyLevel level}) {
  return [
    (
      kind: LogKind.energySet,
      itemId: null,
      itemOrigin: null,
      stack: null,
      settingKey: null,
      settingValue: null,
      pocketMinutes: null,
      energyLevel: energyLevelWireOf(level),
    ),
  ];
}

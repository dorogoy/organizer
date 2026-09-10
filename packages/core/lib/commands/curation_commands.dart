/// The curation command (Story 5.11, FR-31, AD-16, AD-21): the one pure
/// function that computes *what* to append when a cluster's switch
/// flips — never ids, instants or offsets, which the shell mints at the
/// commit of the act. A `cluster_curation_changed` row exists only
/// because this file returned it: it is the kind's single sanctioned
/// minter, so no second curation writer can appear silently.
///
/// The payload rides its own schema columns (v11) — the cluster's wire
/// name and the enabled bit — never a `setting_changed` key: AD-21's
/// vocabulary split makes the flip a user act on the house's own
/// content, not a settings-cache event, and the house payload
/// discipline puts every payload on its own kind. Nothing here reads
/// the log — a flip is a fresh act, not a derivation — and nothing
/// counts, summarizes or names a task (FR-31, NL-1): the switch is the
/// act's whole feedback.

library;

import 'package:core/commands/session_commands.dart';
import 'package:core/curation/curation.dart';
import 'package:core/log/log_entry.dart';

/// `cluster_curation_changed` for the flipped cluster — exactly one
/// content row, its whole payload the cluster's wire name and the new
/// enabled bit. The shell completes the row — minting the UUIDv7 id,
/// the instant and the offset in force — before the port sees it, and
/// the append rides the shared `LogWriteQueue` like every other write.
/// A rapid on→off→on lands two rows serialized through the write
/// queue; the derivation's last-row-wins rule reads the newest as in
/// force.
List<LogEntryContent> clusterCurationChanged({
  required CurationCluster cluster,
  required bool enabled,
}) {
  return [
    (
      kind: LogKind.clusterCurationChanged,
      itemId: null,
      itemOrigin: null,
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
      cluster: cluster,
      enabled: enabled,
      triageDestination: null,
      triageVolumeTag: null,
      triageBoxId: null,
    ),
  ];
}

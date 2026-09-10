/// The triage command (Story 6.3, FR-22, AD-21): the one pure function
/// that computes *what* to append when a triage act stands — never ids,
/// instants or offsets, which the shell mints at the commit of each act
/// (the crash path's division of labour, generalized). An
/// `item_triaged` row exists only because this file returned it: it is
/// the kind's single sanctioned minter, so no second triage writer can
/// appear silently.
///
/// The payload rides its own schema columns (v12) — the destination's
/// wire name and the optional coarse volume tag's — never a
/// `setting_changed` key and never a number: the [CoarseVolumeTag] enum
/// IS the value space, so a numeric volume is unrepresentable by
/// construction. The tag is optional and declining to tag writes
/// nothing (FR-22): a declined act passes `volumeTag: null` and the
/// row simply carries no tag. Nothing here reads the log — a triage is
/// a fresh act, not a derivation — and no destination flow, glyph or
/// completion rides the command (6.4's surface); this story mints the
/// substrate the later derivations (6.5's Quarantine Box, 6.7's
/// metric) consume.

library;

import 'package:core/commands/session_commands.dart';
import 'package:core/log/log_entry.dart';

/// `item_triaged` for the stood triage act — exactly one content row,
/// its whole payload the destination and the optional coarse volume
/// tag. The shell completes the row — minting the UUIDv7 id, the
/// instant and the offset in force — before the port sees it, and the
/// append rides the shared `LogWriteQueue` like every other write.
List<LogEntryContent> triageItem({
  required TriageDestination destination,
  CoarseVolumeTag? volumeTag,
}) {
  return [
    (
      kind: LogKind.itemTriaged,
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
      cluster: null,
      enabled: null,
      triageDestination: destination,
      triageVolumeTag: volumeTag,
    ),
  ];
}

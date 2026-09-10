/// The triage commands (Stories 6.3/6.5, FR-22, FR-21, AD-3, AD-21):
/// the pure functions that compute *what* to append when a triage act
/// stands — never ids, instants or offsets, which the shell mints at
/// the commit of each act (the crash path's division of labour,
/// generalized). An `item_triaged` or `box_created` row exists only
/// because this file returned it: it is each kind's single sanctioned
/// minter, so no second triage or box writer can appear silently.
///
/// The triage payload rides its own schema columns (v12, v13) — the
/// destination's wire name, the optional coarse volume tag's and the
/// optional box link's — never a `setting_changed` key and never a
/// number: the [CoarseVolumeTag] enum IS the value space, so a numeric
/// volume is unrepresentable by construction. The tag is optional and
/// declining to tag writes nothing (FR-22): a declined act passes
/// `volumeTag: null` and the row simply carries no tag. The box link
/// is Story 6.5's additive half (FR-21): a quarantine row names the
/// `box_created` row the same act appends, by the pre-minted id the
/// shell threads through both — and a quarantined object liberates
/// nothing, so the minter holds that shape by construction: a box
/// link rides only a `quarantine` row with no tag, and any other
/// shape trips `triageItem`'s own assert before a row exists
/// (FR-22/AD-26 honesty — no caller of this file can mint a tag
/// beside a box link, because the minter itself refuses the shape). `boxCreated` is
/// kind-only content: the box's identity is the row's own id and its
/// date is the row's own instant, so the box row carries no payload
/// field at all (AD-4 — and no follow-up date exists anywhere, AD-1:
/// six months is 6.6's derivation over this row's instant, never a
/// stored value). Nothing here reads the log — a triage is a fresh
/// act, not a derivation — and no destination flow, glyph or
/// completion rides the command (6.4's surface); the derivations
/// (6.5's Quarantine Box, 6.7's metric) consume what this file mints.

library;

import 'package:core/commands/session_commands.dart';
import 'package:core/log/log_entry.dart';

/// `item_triaged` for the stood triage act — exactly one content row,
/// its whole payload the destination, the optional coarse volume tag
/// and the optional box link. The box link is bounded by construction,
/// not call-site discipline: `boxId` rides only a `quarantine` row
/// with no tag beside it — a quarantined object liberates nothing
/// (FR-22/AD-26) — and any other shape trips the minter's own assert
/// below, before a row exists. The shell completes the row — minting
/// the UUIDv7 id, the instant and the offset in force — before the
/// port sees it, and the append rides the shared `LogWriteQueue` like
/// every other write.
List<LogEntryContent> triageItem({
  required TriageDestination destination,
  CoarseVolumeTag? volumeTag,
  String? boxId,
}) {
  assert(
    boxId == null ||
        (destination == TriageDestination.quarantine && volumeTag == null),
    'A box link rides only a quarantine row with no tag beside it — '
    'a quarantined object liberates nothing (FR-22/AD-26).',
  );
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
      triageBoxId: boxId,
    ),
  ];
}

/// `box_created` for the stood quarantine act (Story 6.5, FR-21) —
/// exactly one content row, kind-only: the box's identity is the row's
/// own id (the pre-minted v7 the shell threads into the record so the
/// act's `item_triaged` row can link it) and its date is the row's own
/// instant, so no payload field exists to set. One row per act — each
/// hesitation mints its own box (AC-literal), same-date boxes stay
/// distinct rows, and any date-collapse is 6.6's derivation concern.
List<LogEntryContent> boxCreated() {
  return [
    (
      kind: LogKind.boxCreated,
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
      triageDestination: null,
      triageVolumeTag: null,
      triageBoxId: null,
    ),
  ];
}

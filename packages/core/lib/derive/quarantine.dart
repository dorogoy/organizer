/// The Quarantine Box derivation (Story 6.5, FR-21, AD-1, AD-3): a
/// pure fold over the log that reconstructs every dated box from
/// exactly two kinds of rows — a `box_created` row is a box (its id
/// is the box's identity, its instant the box's date, AD-4), and an
/// `item_triaged` row whose destination is `quarantine` and whose
/// box link names an already-minted box is that box's content. No
/// quarantine table exists, no membership column anywhere else, no
/// stored follow-up date (AD-1): the six-month follow-up (6.6, live)
/// is a derivation over these boxes' own instants, computed in
/// `derive/strip.dart` from `instantUtcMicros` and this fold alone.
///
/// The fold is one pass in replay order (AD-3: recorded instant, then
/// append sequence — the store's own snapshot order), which is the
/// act's own shape: the quarantine act appends `box_created` before
/// its `item_triaged` row at one instant, so the box is minted by the
/// time its content arrives. A quarantine row whose link is missing
/// or names no box minted before it is an ORPHAN — skipped from every
/// box's contents, never invented into a box of its own, never a
/// repair write (AD-23's tolerance, forward-only). A box whose
/// content append failed (a partial act) reconstructs as an honest,
/// coarse empty box; a retry's fresh box beside it stays a distinct
/// row. Same-date boxes stay distinct boxes here — any date-collapse
/// is 6.6's concern, never this fold's.

library;

import 'package:core/log/log_entry.dart';

/// One dated Quarantine Box as the fold reconstructs it (Story 6.5,
/// FR-21): the `box_created` row's own id and instant plus the offset
/// in force when it was written (AD-4), and the box's contents — the
/// quarantine `item_triaged` rows that link it, in replay order.
/// Fields are facts, never verbs (AD-6), and nothing here can grow a
/// follow-up date: that is 6.6's derivation, computed from
/// [instantUtcMicros], never stored.
///
/// Identity: `==` is the record's own — every field compares by value
/// except `contents`, whose `List` compares by reference, so two
/// boxes with equal fields but distinct list instances are NOT
/// equal. Compare per-field or by `id` when the box (not its list
/// instance) is what equality must name.
typedef QuarantineBox = ({
  String id,
  int instantUtcMicros,
  int offsetSeconds,
  List<TriageEntry> contents,
});

/// Derives every Quarantine Box from the log (Story 6.5, FR-21,
/// AD-1): pure over the snapshot, writing nothing and storing
/// nothing. Boxes appear in replay order (the order their
/// `box_created` rows were appended); each box's contents are its
/// linked quarantine rows alone, and a row no box claims is skipped
/// — the fold consults no other source, invents no box, and collapses
/// no dates.
List<QuarantineBox> deriveQuarantine(List<LogEntry> entries) {
  final boxes = <QuarantineBox>[];
  final indexById = <String, int>{};
  for (final entry in entries) {
    if (entry is BoxCreatedEntry) {
      indexById[entry.id] = boxes.length;
      boxes.add((
        id: entry.id,
        instantUtcMicros: entry.instantUtcMicros,
        offsetSeconds: entry.offsetSeconds,
        contents: <TriageEntry>[],
      ));
      continue;
    }
    if (entry is TriageEntry &&
        entry.destination == TriageDestination.quarantine) {
      final boxId = entry.boxId;
      final index = boxId == null ? null : indexById[boxId];
      // A missing or unmatched link is an orphan: the row stays in
      // the log (its own fact) and contributes to no box — never
      // coerced, never repaired (AD-23).
      if (index != null) {
        boxes[index].contents.add(entry);
      }
    }
  }
  return [
    for (final box in boxes)
      (
        id: box.id,
        instantUtcMicros: box.instantUtcMicros,
        offsetSeconds: box.offsetSeconds,
        contents: List.unmodifiable(box.contents),
      ),
  ];
}

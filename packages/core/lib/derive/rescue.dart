/// The rescue derivations (Story 4.6, FR-5, AD-24): the refusal
/// counter, the warrant it feeds, and the chain-level atomic
/// dissolution — three pure laws over the log and the pool-fact
/// snapshot, on the eligible-day precedent's own terms (AD-6's stated
/// crossing for derived state): reading entry TYPES only, never kind
/// identifiers or wire-name literals, writing nothing (AD-3) and
/// storing nothing (AD-1).
///
/// The counter is a DERIVED refusal count, never a cumulative skip
/// total: skips feed it and nothing else — no store column, no second
/// tally, no skip-counting surface anywhere. A day counts toward the
/// counter iff it is an eligible day of the item (the ONE
/// `EligibleDay` predicate, `eligible_day.dart`'s anchor form — a
/// catalogue item's fact-less adapter anchored unbounded, "no earlier
/// than" = ever) AND a `card_skipped` for the item is charged to that
/// day. Absence days, non-dealt days and energy filtering neither
/// increment nor reset it: they are simply not eligible days, and the
/// count freezes across them exactly as the capture window's does.
///
/// The anchor is the item's last activation — the latest
/// `slice_requested` naming it — which RESETS the counter whatever
/// follows: success, failure or no-Slicer degradation alike, so a
/// failed rescue cannot re-fire on every deal. A never-activated item
/// anchors at its own genesis: the pool fact's creation, or nothing at
/// all for a shipped entry (ever). The tap path never consults the
/// counter — it is the auto-heuristic's threshold alone.
///
/// Dissolution is chain-level: declines of any of a chain's steps on
/// ≥ 3 distinct eligible days retire the whole chain — the rescue,
/// not one step, is the refused thing; a surviving sibling would be a
/// fragment re-woven forever. The retirement is one atomic derivation
/// over the pool (no tombstone, AD-25): the parent and every
/// not-yet-completed step simply stop existing as candidates, and the
/// history survives in the log and the export untouched.

library;

import 'package:core/catalogue/catalogue.dart';
import 'package:core/day/calendar.dart';
import 'package:core/derive/eligible_day.dart';
import 'package:core/log/log_entry.dart';
import 'package:core/pool/pool_fact.dart';
import 'package:core/weave/session.dart';

/// The item's counter anchor (Story 4.6): the taxonomy size the
/// predicate's energy clause reads, and the instant no eligible day's
/// witness start may precede — the latest activation's own instant,
/// falling back to the item's genesis (a fact's creation, or the
/// unbounded start for a shipped entry). A step has no counter at all:
/// its declines feed dissolution, never rescue (the depth cap).
EligibleDayAnchor? _anchorOf({
  required List<LogEntry> entries,
  required List<PoolFact> poolFacts,
  required Catalogue catalogue,
  required String itemId,
  required int instantUtcMicros,
}) {
  var latestActivation = eligibleDayUnboundedStart;
  for (final entry in entries) {
    if (entry is SliceEntry &&
        entry.kind == LogKind.sliceRequested &&
        entry.itemId == itemId &&
        entry.instantUtcMicros <= instantUtcMicros &&
        entry.instantUtcMicros >= latestActivation) {
      latestActivation = entry.instantUtcMicros;
    }
  }
  for (final fact in poolFacts) {
    if (fact.id == itemId) {
      // A rescue step has no counter: the depth cap's own reading,
      // stated here so the warrant and the counter agree by
      // construction.
      if (fact.rescueOf != null) {
        return null;
      }
      return (
        size: fact.size,
        noEarlierThanUtcMicros: latestActivation > fact.instantUtcMicros
            ? latestActivation
            : fact.instantUtcMicros,
      );
    }
  }
  for (final entry in catalogue.entries) {
    if (entry.id == itemId) {
      return (size: entry.size, noEarlierThanUtcMicros: latestActivation);
    }
  }
  return null;
}

/// How many distinct eligible days the log shows the item declined on
/// (FR-5, AD-24): one per day that is an eligible day of the item AND
/// holds a `card_skipped` for it charged to that day — the walk's own
/// session-day attribution, never a second copy of the rule. Since the
/// item's last activation when one exists, else since its genesis (a
/// pool fact's creation; a shipped entry's "ever"). A rescue step
/// answers nothing (no counter — the depth cap); an id no source knows
/// answers nothing either. Rows after [instantUtcMicros] are skipped,
/// the readers' convention.
int rescueDeclineDays({
  required List<LogEntry> entries,
  required List<PoolFact> poolFacts,
  required Catalogue catalogue,
  required String itemId,
  required int instantUtcMicros,
}) {
  final anchor = _anchorOf(
    entries: entries,
    poolFacts: poolFacts,
    catalogue: catalogue,
    itemId: itemId,
    instantUtcMicros: instantUtcMicros,
  );
  if (anchor == null) {
    return 0;
  }
  final bounded = [
    for (final entry in entries)
      if (entry.instantUtcMicros <= instantUtcMicros) entry,
  ];
  final declinedDays =
      walkLog(bounded).skippedDaysByItemId[itemId] ?? const <Day>{};
  var count = 0;
  for (final day in declinedDays) {
    if (eligibleDayOfAnchor(
      entries: bounded,
      anchor: anchor,
      day: day,
      instantUtcMicros: instantUtcMicros,
    )) {
      count++;
    }
  }
  return count;
}

/// Whether the auto-heuristic's re-slice is warranted for the item
/// (FR-5): declined on at least [captureDealWindowEligibleDays]
/// distinct eligible days since its last activation — the same named
/// width the capture window reads, the one statement of three. A
/// rescue step is never warranted (the depth cap lives here too, so
/// the shell's ask can never re-slice a step). The tap path never
/// reads this: it deals the request at any moment, no counter needed.
bool rescueWarranted({
  required List<LogEntry> entries,
  required List<PoolFact> poolFacts,
  required Catalogue catalogue,
  required String itemId,
  required int instantUtcMicros,
}) {
  return rescueDeclineDays(
        entries: entries,
        poolFacts: poolFacts,
        catalogue: catalogue,
        itemId: itemId,
        instantUtcMicros: instantUtcMicros,
      ) >=
      captureDealWindowEligibleDays;
}

/// The parents whose chains stand dissolved (FR-5): declines of any of
/// a chain's steps on at least [captureDealWindowEligibleDays]
/// distinct eligible days retire the whole chain — the rescue, not one
/// step, is the refused thing. Each step's days read through the ONE
/// predicate over the step's own fact (its instant size is never
/// energy-excluded; its creation bounds "no earlier than"), the union
/// counts DISTINCT days across the chain, and the retirement itself is
/// the caller's candidacy fold — nothing here writes, nothing here is
/// stored, and no tombstone exists anywhere (AD-25).
Set<String> dissolvedChainParentIds({
  required List<LogEntry> entries,
  required List<PoolFact> poolFacts,
  required int instantUtcMicros,
}) {
  final bounded = [
    for (final entry in entries)
      if (entry.instantUtcMicros <= instantUtcMicros) entry,
  ];
  final skippedDaysByItemId = walkLog(bounded).skippedDaysByItemId;
  final dissolved = <String>{};
  final declinedDaysByParent = <String, Set<Day>>{};
  for (final fact in poolFacts) {
    final parent = fact.rescueOf;
    if (parent == null) {
      continue;
    }
    final days = skippedDaysByItemId[fact.id] ?? const <Day>{};
    if (days.isEmpty) {
      continue;
    }
    final charged = declinedDaysByParent.putIfAbsent(parent, () => {});
    for (final day in days) {
      if (eligibleDayOfAnchor(
        entries: bounded,
        anchor: (
          size: fact.size,
          noEarlierThanUtcMicros: fact.instantUtcMicros,
        ),
        day: day,
        instantUtcMicros: instantUtcMicros,
      )) {
        charged.add(day);
      }
    }
  }
  declinedDaysByParent.forEach((parent, days) {
    if (days.length >= captureDealWindowEligibleDays) {
      dissolved.add(parent);
    }
  });
  return dissolved;
}

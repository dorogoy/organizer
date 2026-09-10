/// The 1-3-5 weave (FR-12) and AD-20's single resolver: the pure
/// composition of a domestic day out of the catalogue, the log, the
/// scaling gates and the resolved curation state. Nothing derived is
/// stored (AD-1) — the composition is recomputed from replayable facts
/// whenever a deal needs it.
///
/// `core/weave` is the only code that may emit a deal (AD-20): every
/// work source — the shipped catalogue, manual capture pool facts
/// (Story 3.3), rescue chains' head steps (Story 4.6), active Epic
/// Projects' head steps (Story 5.9) and, since Story 6.1, the derived
/// purge injection —
/// offers candidates with precedence, and the resolver below is the
/// single place that turns them into a card. The module stays
/// deterministic (AD-3): no `Random`, no wall clock, no `dart:io`,
/// ties break by least-recently-dealt then stable id for catalogue
/// work and by the fact's recorded creation instant (FIFO) for
/// captures — never id bit patterns.
///
/// The Focus Chunk slot resolves through ordered tiers (AD-20): the
/// week's active zone first, then `fondo`, then the least-recently-dealt
/// eligible entry regardless of zone — repetition before an empty day.
/// Exactly one zone is active per domestic week (FR-11): the nominal
/// ring position [Week.weekOrdinal] mod 5 decides, and a disabled zone's
/// week passes to the next active one. The 3- and 5-draws stay
/// size-based; only the chunk tier reads the rotation. Consumption is
/// `card_done` rows only — the floor counts answered deals, not calendar
/// days, and a skip re-resolves identity while consuming nothing.

library;

import 'package:core/catalogue/catalogue.dart';
import 'package:core/curation/curation.dart';
import 'package:core/day/calendar.dart';
import 'package:core/derive/rescue.dart';
import 'package:core/energy/energy.dart';
import 'package:core/log/log_entry.dart';
import 'package:core/pool/pool_fact.dart';
import 'package:core/settings/settings.dart';
import 'package:core/weave/session.dart';

// The per-size duration estimates (FR-27) live in `core/weave/session`
// beside the walk that charges them to a declared pocket (Story 2.2);
// re-exported here so the weave's callers keep one import — the names
// below are this library's public surface, unchanged. Since Story 6.1
// three more of the walk's own inputs ride the same seam: the 🔴
// ceiling (FR-4), the purge step's estimate and the purge id prefix
// (FR-19) — `session.dart` may not import its own parent, so anything
// the fold itself charges lives there and is re-exported here.
export 'package:core/weave/session.dart'
    show
        estimateSecondsOf,
        focusEstimateSeconds,
        instantEstimateSeconds,
        lowEnergyMaxEstimateSeconds,
        maintenanceEstimateSeconds,
        purgeItemIdPrefix,
        purgeStepEstimateSeconds;

/// A Focus Chunk composes only from this much bag (FR-7): below it the
/// day composes without the "1", silently — no debt, no mention. The
/// bag's range and its default of 15 live in `core/settings` (2.1) —
/// one source of truth; this is the weave's own policy threshold, not
/// the setting's range.
const int focusChunkLeastBagMinutes = 10;

/// The canonical 1-3-5 draw counts (FR-12): one Focus Chunk, three
/// Micro-maintenance draws, five Instant Habit draws. Scaling drops
/// counts; it never shrinks an estimate.
const int maintenanceDrawsPerDay = 3;
const int instantDrawsPerDay = 5;

/// One composed card (FR-1): the item's id, its taxonomy size, its
/// resolved Spanish name (a shipped task's Origin Context, AD-16), its
/// origin, its zone-or-none, and the per-size duration estimate in
/// seconds. A value: two cards are the same card iff every field
/// matches. The zone is inert data for the surface (1.8's zone-marker);
/// daily and seasonal entries carry none.
final class Card {
  const Card({
    required this.id,
    required this.size,
    required this.name,
    required this.origin,
    required this.zone,
    required this.estimateSeconds,
  });

  /// The referenced item's id — a permanent catalogue id for shipped
  /// work, so the tie-break and rotation read the same id discipline
  /// captured items will use later.
  final String id;

  final Size size;

  /// The resolved Spanish name, handed to the core as inert data by the
  /// named shell loader.
  final String name;

  final Origin origin;

  /// The entry's weekly zone, or absent for daily and seasonal entries —
  /// the zone marker's data, never a zone-name string (that is the ARB
  /// table's, 1.8's and AD-15's business).
  final Zone? zone;

  final int estimateSeconds;

  @override
  bool operator ==(Object other) =>
      other is Card &&
      other.id == id &&
      other.size == size &&
      other.name == name &&
      other.origin == origin &&
      other.zone == zone &&
      other.estimateSeconds == estimateSeconds;

  @override
  int get hashCode =>
      Object.hash(id, size, name, origin, zone, estimateSeconds);

  @override
  String toString() =>
      'Card(${id.toString()}, ${size.name}, ${origin.name}, '
      '${zone?.name ?? '-'}, ${estimateSeconds}s)';
}

/// Where a candidate stands in AD-20's arbitration. Four members
/// since Story 6.1 — a live rescue chain's head step (the first
/// not-yet-answered one) AHEAD of manual captures, which stay ahead
/// of the derived purge injection, which stands directly above the
/// active Epic Projects' head steps; the shipped catalogue stays
/// last. Every source is a member, never a flag on these.
enum CandidatePrecedence {
  /// A live rescue chain's head step (Story 4.6, FR-5) — ahead of every
  /// other source: the chain is the conversion of a card the user
  /// already faced, and no new chunk may bury its next step.
  rescue,

  /// A manual capture's pool fact (Story 3.3, FR-27) — ahead of the
  /// catalogue: the index is the arbitration.
  capture,

  /// A derived purge step (Story 6.1, FR-19, AD-20): one synthetic
  /// candidate per activated organizing group, standing directly
  /// above the Epic Projects' own steps — prepended before any
  /// organization step, behind the user's live commitments (rescue,
  /// captures). A member sourced like any other, never a weave
  /// special case: the resolver alone turns it into a deal.
  purge,

  /// An active Epic Project's head step (Story 5.9, FR-11, AD-20) —
  /// behind captures, ahead of the catalogue: a member, never a flag
  /// (this enum's own rule). Eligible for the Focus Chunk slot by
  /// candidate class, never by size — an Epic step commonly bands
  /// `maintenance` (180–300 s) and still enters the chunk pool.
  epic,

  /// A shipped Evergreen catalogue entry.
  catalogue,
}

/// One candidate offered to the single resolver (AD-20): a work source's
/// item as inert data. Sources return candidates and never a deal; only
/// the resolver in this library turns them into a card.
final class Candidate {
  const Candidate({
    required this.itemId,
    required this.size,
    required this.name,
    required this.origin,
    required this.zone,
    required this.precedence,
    this.createdInstantUtcMicros,
    this.estimateSeconds,
  });

  final String itemId;
  final Size size;
  final String name;
  final Origin origin;

  /// The entry's weekly zone, or absent for daily and seasonal entries —
  /// the chunk tier's discriminator: a zone names the weekly tier, no
  /// zone on a focus candidate names `fondo`.
  final Zone? zone;

  final CandidatePrecedence precedence;

  /// The source's own creation instant — a manual capture's pool-fact
  /// creation, the FIFO key: same-size captures order oldest-first by
  /// it (AD-3: recorded act instants, never id bit patterns, and a
  /// skip keeps the place because deal history never re-orders
  /// captures). Absent for sources with no recorded genesis — the
  /// shipped catalogue, whose ordering reads deals, never births. A
  /// rescue step's own fact creation is its FIFO key too (Story 4.6):
  /// the oldest live chain's head stands first.
  final int? createdInstantUtcMicros;

  /// The candidate's duration estimate in seconds — a rescue step's
  /// own verbatim Slicer tag (Story 4.6, FR-5); absent for every other
  /// source, whose estimate is its taxonomy size's. The
  /// duration-consuming rules (the 🔴 ceiling, the pocket) read the
  /// estimate, never the size's default, on a step.
  final int? estimateSeconds;
}

/// The shipped catalogue as a candidate source (AD-16, AD-20): entries
/// become `Origin.shipped` items — id the permanent catalogue id, name
/// already resolved, zone carried as inert data — handed to the resolver,
/// never materialized as `pool_facts` rows. The focus-size offering
/// excludes daily entries: Baseline Upkeep, however well its size fits,
/// never occupies the chunk slot (FR-12). Entries of a cluster outside
/// [activeClusters] (default: all active, AD-16) are not offered at all
/// — cluster filtering applies to every candidate, every draw.
List<Candidate> shippedCandidates(
  Catalogue catalogue, {
  Set<CurationCluster>? activeClusters,
}) {
  final clusters = activeClusters ?? allCurationClusters;
  return [
    for (final entry in catalogue.entries)
      if (clusters.contains(curationClusterOfEntry(entry)) &&
          (entry.size != Size.focus || entry.cadence != Cadence.daily))
        Candidate(
          itemId: entry.id,
          size: entry.size,
          name: entry.name,
          origin: Origin.shipped,
          zone: entry.zone,
          precedence: CandidatePrecedence.catalogue,
        ),
  ];
}

/// The parents a chain stands behind (Story 4.6, FR-5): every id some
/// pool fact's `rescueOf` names — live, completed or dissolved alike.
/// THE one fold behind both retirement sites (`captureCandidates`'
/// source-side exclusion and `_resolveDay`'s catalogue-side filter),
/// extracted so the two cannot drift: from activation onward the
/// parent never returns as a candidate, its chain in its place — a
/// FAILED rescue mints no fact, so its parent stays dealable by
/// construction.
Set<String> supersededParentIds(List<PoolFact> poolFacts) => {
  for (final fact in poolFacts)
    if (fact.rescueOf != null) fact.rescueOf!,
};

/// The manual pool facts as a candidate source (Story 3.3, FR-27,
/// AD-20, AD-25): origin-`manual` facts become `Origin.manual` items —
/// id the fact's own id, name the fact's Origin Context (its own
/// single line), no zone — offered ahead of the catalogue by
/// [CandidatePrecedence.capture]. Done-once retirement lives here, at
/// the source (AD-25): a fact whose id the handed-in log answers
/// (`card_done`, all-time) is not offered at all, while a skipped
/// capture stays a candidate with its FIFO place — a skip consumes
/// nothing. No cap and no expiry: an unanswered capture is absent
/// rows, never a deleted fact, and the three capture sizes ARE the
/// 1-3-5 taxonomy — the fact's [Size] rides straight through, no
/// conversion. A duplicate fact id offers once — the snapshot's
/// first, replay order being the one order the store guarantees
/// (AD-3) — so two facts sharing an id cannot fill two draw slots.
/// Since Story 4.6 a rescue step is not offered here — steps belong
/// to the rescue source alone, head-only, one at a time — and a
/// parent whose chain exists is not offered here either: from
/// activation onward the parent never returns as a candidate, its
/// chain in its place.
List<Candidate> captureCandidates(
  List<PoolFact> poolFacts,
  Set<String> answeredItemIds,
) {
  final offered = <String>{};
  final supersededParents = supersededParentIds(poolFacts);
  return [
    for (final fact in poolFacts)
      if (fact.origin == Origin.manual &&
          fact.rescueOf == null &&
          !supersededParents.contains(fact.id) &&
          !answeredItemIds.contains(fact.id) &&
          offered.add(fact.id))
        Candidate(
          itemId: fact.id,
          size: fact.size,
          name: fact.originContext ?? '',
          origin: fact.origin,
          zone: null,
          precedence: CandidatePrecedence.capture,
          createdInstantUtcMicros: fact.instantUtcMicros,
        ),
  ];
}

/// The live rescue chains' head steps as a candidate source (Story
/// 4.6, FR-5, AD-20): for each chain — the pool facts sharing one
/// `rescueOf` parent, in snapshot order — exactly the FIRST
/// not-yet-answered step is offered, at [CandidatePrecedence.rescue],
/// ahead of captures: the chain is the conversion of a card the user
/// already faced, its next step never buried behind new work. A chain
/// whose steps are all answered is complete — the parent is retired
/// done-by-derivation and nothing from it is offered again (AD-25);
/// a dissolved chain ([dissolvedParentIds], the caller's fold over
/// the log) offers nothing either — parent and pending steps retire
/// atomically, and the head rule is how "one at a time" reads here:
/// the next step becomes the head only when this one is answered.
List<Candidate> rescueCandidates(
  List<PoolFact> poolFacts,
  Set<String> answeredItemIds,
  Set<String> dissolvedParentIds,
) {
  // One head per chain: the first not-yet-answered step in snapshot
  // order — a chain's later steps stand behind it, one at a time
  // (FR-5's weaving), and a duplicate fact id offers once, the
  // snapshot's first (AD-3).
  final headsByParent = <String, PoolFact>{};
  for (final fact in poolFacts) {
    final parent = fact.rescueOf;
    if (parent == null || dissolvedParentIds.contains(parent)) {
      continue;
    }
    if (headsByParent.containsKey(parent) ||
        answeredItemIds.contains(fact.id)) {
      continue;
    }
    headsByParent[parent] = fact;
  }
  return [
    for (final fact in headsByParent.values)
      Candidate(
        itemId: fact.id,
        size: fact.size,
        name: fact.originContext ?? '',
        origin: fact.origin,
        zone: null,
        precedence: CandidatePrecedence.rescue,
        createdInstantUtcMicros: fact.instantUtcMicros,
        estimateSeconds: fact.estimateSeconds,
      ),
  ];
}

/// THE Epic grouping fold (Story 5.9, extracted 5.10): the facts
/// with `origin ∈ {cloud, local} ∧ rescueOf == null ∧ stepText != null`
/// sharing one `(instantUtcMicros, originContext)` pair are one
/// slice's steps — the insert-only grouping key — and the group's
/// STABLE ID is its first fact in snapshot order. One private helper
/// behind both Epic derivations (`epicCandidates` and
/// `epicBufferedTargets`), so the two can never drift on what a group
/// is: both walk the same groups. (The head rule and the buffer read
/// those groups differently — the head excludes skipped-today and
/// superseded steps, the buffer counts every unanswered step — and
/// that difference belongs to the readers, never to the grouping.)
/// Keyed by the group key, never the stable id, so a degenerate
/// duplicate fact id cannot collapse two groups the candidates fold
/// would keep apart.
Map<String, List<PoolFact>> _epicStepsByGroupKey(List<PoolFact> poolFacts) {
  final stepsByGroupKey = <String, List<PoolFact>>{};
  for (final fact in poolFacts) {
    if ((fact.origin == Origin.cloud || fact.origin == Origin.local) &&
        fact.rescueOf == null &&
        fact.stepText != null) {
      stepsByGroupKey
          .putIfAbsent(
            '${fact.instantUtcMicros}|${fact.originContext}',
            () => [],
          )
          .add(fact);
    }
  }
  return stepsByGroupKey;
}

/// The active Epic Projects' head steps as a candidate source (Story
/// 5.9, FR-11, AD-20): an Epic is a **derivation, not a stored
/// entity** — the groups of [`_epicStepsByGroupKey`], each with its
/// first fact's id as the stable id. A group whose stable id names no
/// `epic_activated` row (`facts.epicActivatedInstantByStableId`) is
/// dormant and offers nothing — invisible by construction, never by a
/// guard, so a landing that crashed mid-plan derives honestly as
/// dormant. For each ACTIVE Epic, exactly the FIRST step neither
/// answered all-time nor skipped on [day] is the head — a skip
/// demotes the head for the day only (`skippedDaysByItemId`,
/// `session.dart:91`, reused verbatim), while an all-time answer
/// retires a step for good; a chain whose every step is answered or
/// skipped-today offers nothing. The returned list is already in
/// AD-20's arbitration order — least-recently-served active Epic
/// (the maximum `lastDealtInstantByItemId` over its own steps,
/// never-served first), then activation order (the `epic_activated`
/// append order — the fold map's iteration order, never the clock,
/// AD-3), then the stable id — so the caller (`_chunkCandidateOf`) may take its first
/// candidate directly, no further sort. Any Epic step named by
/// [supersededParents] (`supersededParentIds`, the same fold
/// `captureCandidates` reads its own facts through) is a live rescue
/// chain's parent — any origin can be sent through Rescue Mode, so an
/// Epic's head is no exception — and is skipped exactly like an
/// answered or skipped-today step: the chain stands in its place, and
/// the Epic's NEXT step becomes the head instead of the whole Epic
/// vanishing from every draw.
List<Candidate> epicCandidates(
  List<PoolFact> poolFacts,
  LogFacts facts,
  Day day,
  Set<String> supersededParents,
) {
  final groups = <({String stableId, PoolFact head, int? servedInstant})>[];
  for (final steps in _epicStepsByGroupKey(poolFacts).values) {
    final stableId = steps.first.id;
    if (!facts.epicActivatedInstantByStableId.containsKey(stableId)) {
      continue; // Dormant: no activation row names this Epic.
    }
    PoolFact? head;
    for (final step in steps) {
      if (facts.answeredItemIds.contains(step.id)) {
        continue;
      }
      if (facts.skippedDaysByItemId[step.id]?.contains(day) ?? false) {
        continue;
      }
      if (supersededParents.contains(step.id)) {
        continue;
      }
      head = step;
      break;
    }
    if (head == null) {
      continue; // Every step answered, skipped today, or being rescued.
    }
    int? servedInstant;
    for (final step in steps) {
      final dealt = facts.lastDealtInstantByItemId[step.id];
      if (dealt != null && (servedInstant == null || dealt > servedInstant)) {
        servedInstant = dealt;
      }
    }
    groups.add((stableId: stableId, head: head, servedInstant: servedInstant));
  }

  // Activation order (AD-20): the `epic_activated` APPEND order —
  // the fold map's own iteration order, a total order with no ties
  // and no dependence on the clock (a retro-dated row cannot
  // reorder arbitration). The stable id remains only as the
  // comparator's total backstop. The rank map is hoisted out of the
  // comparator (Story 6.1's review round): it is per-derivation
  // state, never per-comparison — the sort rebuilds the comparator
  // O(n log n) times, and the map builds exactly once.
  final activationRanks = _activationRanks(facts);
  groups.sort(
    (a, b) => _byEpicArbitration(
      (servedInstant: a.servedInstant, stableId: a.stableId),
      (servedInstant: b.servedInstant, stableId: b.stableId),
      activationRanks,
    ),
  );

  return [
    for (final group in groups)
      Candidate(
        itemId: group.head.id,
        size: group.head.size,
        name: group.head.stepText ?? group.head.originContext ?? '',
        origin: group.head.origin,
        zone: null,
        precedence: CandidatePrecedence.epic,
        createdInstantUtcMicros: group.head.instantUtcMicros,
        estimateSeconds: group.head.estimateSeconds,
      ),
  ];
}

/// The activation-order ranks (AD-3, AD-20): the `epic_activated`
/// APPEND order as a stable-id → rank map — the fold map's own
/// iteration order, a total order with no ties and no dependence on
/// the clock. Both Epic derivations read this one fold, so the head
/// arbitration and the purge arbitration can never disagree on what
/// "activation order" is.
Map<String, int> _activationRanks(LogFacts facts) => {
  for (final (rank, id) in facts.epicActivatedInstantByStableId.keys.indexed)
    id: rank,
};

/// AD-20's Epic arbitration, the one comparator both Epic derivations
/// read (`epicCandidates`' heads and `purgeCandidates`' purges):
/// least-recently-served first (never-served before any served — the
/// group's own recorded `card_dealt` instants, never the clock), then
/// activation order, then the stable id as the total backstop.
int _byEpicArbitration(
  ({int? servedInstant, String stableId}) a,
  ({int? servedInstant, String stableId}) b,
  Map<String, int> activationRankByStableId,
) {
  if (a.servedInstant == null && b.servedInstant != null) {
    return -1;
  }
  if (a.servedInstant != null && b.servedInstant == null) {
    return 1;
  }
  if (a.servedInstant != null &&
      b.servedInstant != null &&
      a.servedInstant != b.servedInstant) {
    return a.servedInstant! < b.servedInstant! ? -1 : 1;
  }
  final aActivated = activationRankByStableId[a.stableId]!;
  final bActivated = activationRankByStableId[b.stableId]!;
  if (aActivated != bActivated) {
    return aActivated.compareTo(bActivated);
  }
  return a.stableId.compareTo(b.stableId);
}

/// The derived purge injection as a candidate source (Story 6.1,
/// FR-19, AD-20, AD-1): for every ACTIVE organizing group — the same
/// groups of [`_epicStepsByGroupKey`], the same activation fold
/// `epicCandidates` reads — exactly one synthetic candidate
/// (`purge:{groupStableId}`, [purgeItemIdPrefix]), offered at
/// [CandidatePrecedence.purge], directly above the group's own steps
/// and behind the user's live commitments (rescue, captures). Purge
/// state is derived, never stored (AD-1): the candidate stands
/// exactly while the group is activated and NO terminal act
/// (`card_done` or `card_skipped` — `terminalActNames`, the walk's
/// own fold over both) names its synthetic id; a skip closes it for
/// good, exactly as a done does, and no re-deal and no nag exists.
/// The step's text is authored copy handed in as inert data
/// ([stepText], the ARB table's `purgeStepText` through the shell —
/// AD-15; the catalogue's own names arrive the same way), and an
/// absent [stepText] derives no candidate at all: no authored text,
/// no authored step — the seam the core tests use to pin the
/// unprefixed world, and the one a production caller never takes.
/// The returned list is already in AD-20's Epic arbitration order
/// (`_byEpicArbitration`, `epicCandidates`' own contract —
/// least-recently-served, then activation order, then stable id), so
/// the tiers that read it take the first candidate directly, no
/// further sort: with two un-purged groups standing, the purges
/// arbitrate between themselves exactly like Epic material, and each
/// group's own first dealt step is still its purge.
List<Candidate> purgeCandidates(
  List<PoolFact> poolFacts,
  LogFacts facts,
  String? stepText,
) {
  // Blank authored copy is no authored copy (Story 6.1, FR-19): a
  // whitespace-only [stepText] derives no candidate either, exactly
  // as an absent one — blank authored copy must never render as a
  // task, and the seam below stays the seam for every call path that
  // hands no copy worth showing.
  if (stepText == null || stepText.trim().isEmpty) {
    return const [];
  }
  // The composed id rides the group tuple (Story 6.1's review
  // round): `purge:{stableId}` is composed once, here, and the
  // return comprehension reads it — the prefix construction lives
  // in exactly one place, never twice.
  final groups =
      <({String stableId, String itemId, Origin origin, int? servedInstant})>[];
  for (final steps in _epicStepsByGroupKey(poolFacts).values) {
    final stableId = steps.first.id;
    if (!facts.epicActivatedInstantByStableId.containsKey(stableId)) {
      continue; // Dormant: no activation row names this Epic.
    }
    final itemId = '$purgeItemIdPrefix$stableId';
    if (facts.terminalActNames(itemId)) {
      continue; // Answered or skipped once: closed, never re-offered.
    }
    if (steps.every((step) => facts.answeredItemIds.contains(step.id))) {
      continue; // Completed: all organization steps already answered (Story 6.1 review).
    }
    groups.add((
      stableId: stableId,
      itemId: itemId,
      origin: steps.first.origin,
      servedInstant: facts.lastDealtInstantByItemId[itemId],
    ));
  }
  // The rank map is hoisted out of the comparator, `epicCandidates`'
  // own rule — per-derivation state, built exactly once.
  final activationRanks = _activationRanks(facts);
  groups.sort(
    (a, b) => _byEpicArbitration(
      (servedInstant: a.servedInstant, stableId: a.stableId),
      (servedInstant: b.servedInstant, stableId: b.stableId),
      activationRanks,
    ),
  );
  return [
    for (final group in groups)
      Candidate(
        itemId: group.itemId,
        size: sizeOfEstimateSeconds(purgeStepEstimateSeconds),
        name: stepText,
        origin: group.origin,
        zone: null,
        precedence: CandidatePrecedence.purge,
        estimateSeconds: purgeStepEstimateSeconds,
      ),
  ];
}

/// The dormant Epic Projects (Story 5.13, FR-15, AD-21): every group
/// of [`_epicStepsByGroupKey`] whose stable id no `epic_activated`
/// row names at-or-before the read instant — the same derivation
/// `epicCandidates` reads for candidacy, projected as records for the
/// strip's suggestion instead of candidates for the weave. Ordered by
/// AD-3's discipline, deterministic over facts that exist: earliest
/// group instant first (the one the landing minted — every step of a
/// slice shares it), then stable id — the earliest-created dormant
/// Epic is the one the user has waited longest to be reminded of, and
/// no recency heuristic exists to tune. The description is the
/// Epic's Origin Context — the slice's retained space description —
/// with the head step's own words and the empty string as the only
/// fallbacks. `epic_activated` rows after [instantUtcMicros] are
/// ignored, exactly `_appOpenedBefore`'s own read-instant discipline:
/// a row the read cannot see yet activates nothing. This is the one
/// dormancy derivation — nothing else may compute dormancy, and the
/// records are structural: `core/derive` reads them without importing
/// this library (strip.dart must not import weave — the cycle), so no
/// shared type exists to import by design.
List<({String stableId, Origin origin, String description})>
dormantEpicProjects(
  List<PoolFact> poolFacts,
  List<LogEntry> entries,
  int instantUtcMicros,
) {
  final activatedStableIds = <String>{
    for (final entry in entries)
      if (entry.instantUtcMicros <= instantUtcMicros &&
          entry is ItemActEntry &&
          entry.kind == LogKind.epicActivated)
        entry.itemId,
  };
  final dormant = <({String stableId, Origin origin, String description})>[];
  final groupInstantByStableId = <String, int>{};
  for (final steps in _epicStepsByGroupKey(poolFacts).values) {
    final first = steps.first;
    if (activatedStableIds.contains(first.id)) {
      continue; // Active: dormancy asserts nothing (AD-21).
    }
    groupInstantByStableId[first.id] = first.instantUtcMicros;
    dormant.add((
      stableId: first.id,
      origin: first.origin,
      description: first.originContext ?? first.stepText ?? '',
    ));
  }
  dormant.sort((a, b) {
    final byInstant = groupInstantByStableId[a.stableId]!.compareTo(
      groupInstantByStableId[b.stableId]!,
    );
    if (byInstant != 0) {
      return byInstant;
    }
    return a.stableId.compareTo(b.stableId);
  });
  return dormant;
}

/// The active Epic Projects' buffered completion horizons (Story
/// 5.10, FR-13, AD-1): the derived target AD-1 names — slack the user
/// cannot see, cannot configure and cannot spend, so nothing anywhere
/// renders it. A pure function of `(pool facts, log facts, day)`, like
/// every derivation: no log row, no column, no `Random`, no wall
/// clock, nothing stored — recomputed on every derivation, so a
/// deferral, a skip or seven days of absence moves the horizon
/// silently later and nothing else (FR-14's rescheduler is not code
/// for exactly this reason).
///
/// THE v1 rule, frozen: `target = day.startUtcMicros + remainingSteps
/// × 2 × 24 h µs` — derivation-day start plus one serving day and one
/// slack day per step, whole domestic days over [Day]'s fixed 24 h
/// frame, never a constructed `Day` (that is [Calendar]'s alone,
/// AD-4). The × 2 is the smallest whole-number buffer that tolerates
/// every-other-day engagement standing still; anchoring at the
/// derivation day's start — never the activation, never the last
/// serving — is what lets the target SURVIVE absence: an absence
/// moves it later instead of blowing through it, and "silently
/// rebalanced" is this recomputation, never a repair.
///
/// `remainingSteps` reuses the head rule's own answered set
/// (`answeredItemIds`, all-time) — no second definition of "done" can
/// drift — so a step skipped today or superseded by a live rescue
/// chain still counts: neither retires work (AD-25), and the buffer
/// must not invent retirements the substrate forbids. Active-only:
/// dormant Epics (no `epic_activated` row naming the group's stable
/// id) and all-answered Epics derive no entry — no obligation either
/// way. The horizon moves later across appended rows for a
/// non-regressing derivation day: the day is an input, not a clock
/// law — replaying the same day over the same log is deterministic,
/// same inputs, same horizon (AD-3), and only a `card_done` shortens
/// it (work done, never time owed). Nothing calls this
/// from the weave's own pipeline: no deal, tier or gate reads it; the
/// surface-invisibility scan (`test/no_lateness_proof_test.dart`)
/// keeps the words off every surface while the derivation stays
/// checkable here.
Map<String, int> epicBufferedTargets(
  List<PoolFact> poolFacts,
  LogFacts facts,
  Day day,
) {
  final targets = <String, int>{};
  for (final steps in _epicStepsByGroupKey(poolFacts).values) {
    final stableId = steps.first.id;
    if (!facts.epicActivatedInstantByStableId.containsKey(stableId)) {
      continue; // Dormant: dormancy asserts nothing.
    }
    var remainingSteps = 0;
    for (final step in steps) {
      if (!facts.answeredItemIds.contains(step.id)) {
        remainingSteps++;
      }
    }
    if (remainingSteps == 0) {
      continue; // Nothing owed; no completion row is minted either.
    }
    targets[stableId] =
        day.startUtcMicros + remainingSteps * 2 * Duration.microsecondsPerDay;
  }
  return targets;
}

/// The week's one active zone (FR-11, FR-31): the nominal ring position
/// `Zone.values[weekOrdinal mod 5]`, then the first active zone
/// at-or-after it cyclically — a disabled zone's week passes to the next
/// active zone, and with no active zone cluster at all the result is
/// absent and the chunk tiers are empty while the 3- and 5-draws stand.
Zone? activeZoneOf(Week week, Set<CurationCluster> activeClusters) {
  final nominalIndex =
      ((week.weekOrdinal % Zone.values.length) + Zone.values.length) %
      Zone.values.length;
  for (var step = 0; step < Zone.values.length; step++) {
    final zone = Zone.values[(nominalIndex + step) % Zone.values.length];
    if (activeClusters.contains(curationClusterOfZone(zone))) {
      return zone;
    }
  }
  return null;
}

/// The composed day (FR-12): the Focus Chunk slot — absent when the
/// scaling gate drops it, the day's occupancy closed it, or no eligible
/// candidate exists — plus the Micro-maintenance and Instant Habit
/// draws. A derivation, never a stored plan (AD-1).
final class DayComposition {
  const DayComposition({
    required this.focus,
    required this.maintenance,
    required this.instantHabits,
  });

  /// The day's "1", or absent.
  final Card? focus;

  /// The day's "3", in resolved order.
  final List<Card> maintenance;

  /// The day's "5", in resolved order.
  final List<Card> instantHabits;
}

/// The single resolver's candidate order (AD-3, AD-20): precedence
/// first, then — for catalogue work — least-recently-dealt (recorded
/// `card_dealt` instants, never-dealt first) then stable id order.
/// Same-precedence captures order instead by their source's recorded
/// creation instant, oldest-first (FIFO, Story 3.3): deal history
/// never re-orders them, which is exactly why a skip keeps a
/// capture's place. Rescue heads read the same FIFO key (Story 4.6):
/// the oldest live chain's head stands first, a chain never leapfrogs
/// a chain. Never id bit patterns, on any branch.
int _resolverOrder(
  Candidate a,
  Candidate b,
  Map<String, int> lastDealtInstantByItemId,
) {
  final byPrecedence = a.precedence.index.compareTo(b.precedence.index);
  if (byPrecedence != 0) {
    return byPrecedence;
  }
  if (a.precedence == CandidatePrecedence.capture ||
      a.precedence == CandidatePrecedence.rescue) {
    // Same-size fact-backed candidates, oldest fact first — the FIFO
    // key is the fact's recorded creation instant, tie stable id. A
    // candidate absent its instant (no source mints one) still orders
    // totally.
    final byCreation = (a.createdInstantUtcMicros ?? 0).compareTo(
      b.createdInstantUtcMicros ?? 0,
    );
    if (byCreation != 0) {
      return byCreation;
    }
    return a.itemId.compareTo(b.itemId);
  }
  final aDealt = lastDealtInstantByItemId[a.itemId];
  final bDealt = lastDealtInstantByItemId[b.itemId];
  if (aDealt == null && bDealt == null) {
    return a.itemId.compareTo(b.itemId);
  }
  if (aDealt == null) {
    return -1;
  }
  if (bDealt == null) {
    return 1;
  }
  if (aDealt != bDealt) {
    return aDealt < bDealt ? -1 : 1;
  }
  return a.itemId.compareTo(b.itemId);
}

List<Candidate> _orderedByResolver(
  Iterable<Candidate> candidates,
  LogFacts facts,
) {
  return candidates.toList()
    ..sort((a, b) => _resolverOrder(a, b, facts.lastDealtInstantByItemId));
}

Card _cardOf(Candidate candidate) => Card(
  id: candidate.itemId,
  size: candidate.size,
  name: candidate.name,
  origin: candidate.origin,
  zone: candidate.zone,
  // A rescue step's or purge candidate's own verbatim estimate; every
  // other source's taxonomy size default (Story 4.6, Story 6.1).
  estimateSeconds:
      candidate.estimateSeconds ?? estimateSecondsOf(candidate.size),
);

List<Card> _draw(List<Candidate> ofSize, LogFacts facts, int count) {
  final ordered = _orderedByResolver(ofSize, facts);
  return [for (final candidate in ordered.take(count)) _cardOf(candidate)];
}

/// The chunk slot's candidate (AD-20's tiers, in order): a manual
/// capture of chunk size first (Story 3.3 — not-yet-answered by the
/// source's own retirement, ahead of every zone tier and composing
/// with no active zone at all, so FR-11's empty ring still holds the
/// capture; the day never holds a second large item beside it, for
/// the tiers below never run while a capture stands), then an active
/// Epic Project's head step (Story 5.9, FR-11, FR-12 — already in
/// AD-20's own arbitration order, `epicCandidates`' own contract, so
/// this tier takes it first with no further sort), then the active
/// zone's focus entries never **answered** (`card_done`) all-time,
/// then `fondo` (seasonal focus) never answered, then the
/// least-recently-dealt eligible focus entry regardless of zone —
/// repetition accepted, never an empty day while any eligible entry
/// exists. Ties within a tier break by the resolver's own order
/// (AD-3 — FIFO by fact instant inside the capture tier,
/// least-recently-dealt then stable id in the others). With no active
/// zone (FR-11's ring empty) the zone tiers are empty — this returns
/// absent once no capture and no active Epic stand.
Candidate? _chunkCandidateOf(
  List<Candidate> focusCandidates,
  LogFacts facts,
  Zone? activeZone,
) {
  // The capture tier (Story 3.3): no not-yet-answered conjunct —
  // retirement already lived at the source, `captureCandidates`'s own
  // fold, so every capture standing here is unanswered by
  // construction.
  final captureTier = _orderedByResolver(
    focusCandidates.where(
      (candidate) => candidate.precedence == CandidatePrecedence.capture,
    ),
    facts,
  );
  if (captureTier.isNotEmpty) {
    return captureTier.first;
  }
  // The purge tier (Story 6.1, FR-19): the pending purges, already in
  // `purgeCandidates`' own Epic-arbitration order — this tier takes
  // the first directly, ahead of every Epic head, so no organization
  // step composes while any group's purge stands. A capture kept its
  // tier above (the user's live material outranks the injection).
  final purgeTier = focusCandidates.where(
    (candidate) => candidate.precedence == CandidatePrecedence.purge,
  );
  if (purgeTier.isNotEmpty) {
    return purgeTier.first;
  }
  // The epic tier (Story 5.9): `epicCandidates` already returns its
  // list in AD-20's own arbitration order (least-recently-served,
  // then activation order, then stable id) — the source owns the
  // Epic arbitration, so this tier takes the first candidate
  // directly, never through the generic resolver order.
  final epicTier = focusCandidates.where(
    (candidate) => candidate.precedence == CandidatePrecedence.epic,
  );
  if (epicTier.isNotEmpty) {
    return epicTier.first;
  }
  if (activeZone == null) {
    return null;
  }
  final answered = facts.answeredItemIds;
  final zoneTier = _orderedByResolver(
    focusCandidates.where(
      (candidate) =>
          candidate.zone == activeZone && !answered.contains(candidate.itemId),
    ),
    facts,
  );
  if (zoneTier.isNotEmpty) {
    return zoneTier.first;
  }
  final fondoTier = _orderedByResolver(
    focusCandidates.where(
      (candidate) =>
          candidate.zone == null && !answered.contains(candidate.itemId),
    ),
    facts,
  );
  if (fondoTier.isNotEmpty) {
    return fondoTier.first;
  }
  final leastRecentlyDealt = _orderedByResolver(focusCandidates, facts);
  return leastRecentlyDealt.isEmpty ? null : leastRecentlyDealt.first;
}

bool _chunkComposes(
  int bagMinutes,
  EnergyLevel energy,
  LogFacts facts,
  Day day,
) =>
    bagMinutes >= focusChunkLeastBagMinutes &&
    energy != EnergyLevel.low &&
    !facts.focusSlotClosedDays.contains(day) &&
    !facts.focusSlotCarriedDays.contains(day);

/// The one policy pipeline behind both surfaces of the weave (1.6's
/// deferred unification): eligibility, cluster filtering, the chunk
/// tiers and the day's ordered draws computed once, so `composeDay` and
/// `nextDeal` cannot drift. The chunk card is resolved only while the
/// gate holds and no dealt-but-unanswered card stands (AD-3 — the line
/// is the pipeline's, so both surfaces read it identically); the draws
/// are the day's full canonical counts.
typedef _DayPolicy = ({
  LogFacts facts,
  Card? chunk,
  List<Card> rescueHeads,
  List<Card> purgeHeads,
  List<Card> maintenance,
  List<Card> instantHabits,
  Map<Size, int> dealtOnDay,
  bool Function(Card card) pocketAllows,
});

_DayPolicy _resolveDay({
  required Catalogue catalogue,
  required List<LogEntry> log,
  required int instantUtcMicros,
  required int offsetSeconds,
  required int bagMinutes,
  required EnergyLevel energy,
  required Set<CurationCluster>? activeClusters,
  List<PoolFact> poolFacts = const [],
  String? purgeStepText,
  bool liftedPocket = false,
}) {
  final facts = walkLog(log, catalogue: catalogue, poolFacts: poolFacts);
  final day = anchorDayOf(facts, instantUtcMicros, offsetSeconds);
  // The log-derived active set (Story 5.11, AD-16): with no explicit
  // override the clusters derive from the log's own curation rows at
  // the composed day's opening instant — daily and `fondo`
  // observations effective from their own day's start, weekly zones
  // at the close of the observation's week, the two speeds AD-16
  // froze — so a flip lands with zero call-site changes and replays
  // deterministically (same log + day → same set, AD-3). The explicit
  // param stays the override the tests already use; with no rows the
  // fold is empty and the all-active default stands (FR-31: the
  // first composed day is never empty).
  final clusters =
      activeClusters ??
      activeClustersAt(curationObservationsOf(log), day.startUtcMicros);
  // The 🔴 day's admission (FR-4, Story 2.5): while the derived energy
  // is low, only candidates whose duration estimate stays within
  // [lowEnergyMaxEstimateSeconds] reach the chunk tier or any draw
  // list — the single filter every consumer inherits, inside this
  // pipeline, so `nextDeal`, `composeDay` and the close-continue probe
  // cannot drift (the chunk gate above already drops the "1" at low;
  // this line narrows the tiers beneath it). The ceiling reads the
  // card's estimate; today that estimate derives from taxonomy size
  // because the catalogue carries no per-item estimates — so the rule
  // and today's sizes coincide at the instant tier — while transient
  // steps that carry their own estimates (FR-5's rescue, Epic 6's
  // purge — each ≤ 60 s by contract, Story 6.1 since) meet the same
  // ceiling through it. Captures meet it like anyone (Story 3.3): a
  // focus or maintenance capture reaches no draw on a 🔴 day, an
  // instant capture (30 s) stands with the habits.
  bool lowEnergyAdmits(Candidate candidate) =>
      energy != EnergyLevel.low ||
      (candidate.estimateSeconds ?? estimateSecondsOf(candidate.size)) <=
          lowEnergyMaxEstimateSeconds;
  // The superseded parents (Story 4.6): a parent whose chain exists
  // never returns as a candidate from activation onward — the chain
  // stands in its place (live, completed or dissolved alike), and a
  // FAILED rescue leaves no chain, so its parent stays dealable. The
  // one fold, shared with `captureCandidates`' source-side exclusion.
  final supersededParents = supersededParentIds(poolFacts);
  final dissolvedParents = dissolvedChainParentIds(
    entries: log,
    poolFacts: poolFacts,
    instantUtcMicros: instantUtcMicros,
  );
  final candidates = [
    for (final candidate in [
      // The candidate sources in precedence order (AD-20): the live
      // chains' head steps first (Story 4.6 — the conversion of a
      // card the user already faced), manual captures behind them
      // (Story 3.3 — done-once retirement already applied at the
      // source), the derived purge injection behind the captures
      // (Story 6.1 — prepended before any organization step, behind
      // the user's live commitments), active Epic Projects behind it
      // (Story 5.9), the shipped catalogue last.
      ...rescueCandidates(poolFacts, facts.answeredItemIds, dissolvedParents),
      ...captureCandidates(poolFacts, facts.answeredItemIds),
      ...purgeCandidates(poolFacts, facts, purgeStepText),
      ...epicCandidates(poolFacts, facts, day, supersededParents),
      ...shippedCandidates(catalogue, activeClusters: clusters),
    ])
      if (lowEnergyAdmits(candidate) &&
          !supersededParents.contains(candidate.itemId))
        candidate,
  ];
  Card? chunk;
  if (_chunkComposes(bagMinutes, energy, facts, day) &&
      facts.dealtUnanswered == null) {
    final activeZone = activeZoneOf(const Calendar().weekOf(day), clusters);
    final chunkCandidate = _chunkCandidateOf(
      candidates
          .where(
            (candidate) =>
                candidate.size == Size.focus ||
                candidate.precedence == CandidatePrecedence.epic ||
                candidate.precedence == CandidatePrecedence.purge,
          )
          .toList(),
      facts,
      activeZone,
    );
    if (chunkCandidate != null) {
      chunk = _cardOf(chunkCandidate);
    }
  }
  // The pocket's deal filter (Story 2.2, FR-8, FR-12): while a
  // pocketed session is open, a candidate is dealt only if the
  // sitting's answered estimates plus the candidate's estimate stay
  // within the declared pocket — upkeep charged like everything else —
  // and only if the pocket has not elapsed at this resolution instant.
  // Unbounded sessions filter nothing; the elapse is derived here,
  // never scheduled anywhere. The checkpoint's close-continue probe
  // (Story 2.4) runs this same pipeline with [liftedPocket], so the
  // two surfaces of the filter cannot drift.
  final openStart = facts.openSessionStart;
  final pocketMinutes = facts.openSessionPocketMinutes;
  final pocketDeadlineMicros = (openStart == null || pocketMinutes == null)
      ? null
      : openStart.instantUtcMicros + pocketMinutes * microsPerMinute;
  final pocketCeilingSeconds = pocketMinutes == null ? 0 : pocketMinutes * 60;
  bool pocketAllows(Card card) {
    if (liftedPocket) {
      return true;
    }
    final deadline = pocketDeadlineMicros;
    if (deadline == null) {
      return true;
    }
    if (instantUtcMicros >= deadline) {
      return false;
    }
    return facts.openSessionAnsweredSeconds + card.estimateSeconds <=
        pocketCeilingSeconds;
  }

  return (
    facts: facts,
    chunk: chunk,
    rescueHeads: [
      for (final candidate in _orderedByResolver(
        candidates
            .where(
              (candidate) => candidate.precedence == CandidatePrecedence.rescue,
            )
            .toList(),
        facts,
      ))
        _cardOf(candidate),
    ],
    // The pending purges in the source's own arbitration order
    // (Story 6.1): the list composition preserves it, so the tier
    // that reads this takes the head directly — `epicCandidates`'
    // own contract, `purgeHeads`'s too.
    purgeHeads: [
      for (final candidate in candidates.where(
        (candidate) => candidate.precedence == CandidatePrecedence.purge,
      ))
        _cardOf(candidate),
    ],
    maintenance: _draw(
      candidates
          .where(
            (candidate) =>
                candidate.size == Size.maintenance &&
                candidate.precedence != CandidatePrecedence.rescue &&
                candidate.precedence != CandidatePrecedence.epic &&
                candidate.precedence != CandidatePrecedence.purge,
          )
          .toList(),
      facts,
      maintenanceDrawsPerDay,
    ),
    instantHabits: _draw(
      candidates
          .where(
            (candidate) =>
                candidate.size == Size.instant &&
                candidate.precedence != CandidatePrecedence.rescue &&
                candidate.precedence != CandidatePrecedence.epic &&
                candidate.precedence != CandidatePrecedence.purge,
          )
          .toList(),
      facts,
      instantDrawsPerDay,
    ),
    dealtOnDay: facts.dealtCountsByDay[day] ?? const <Size, int>{},
    pocketAllows: pocketAllows,
  );
}

/// Composes the day (FR-12, AD-20): a pure function of the catalogue,
/// the log, the scaling inputs and the resolved active clusters (AD-16
/// — default: all active). The chunk is composed only when the bag holds
/// [focusChunkLeastBagMinutes] or more and the derived energy is not low
/// — otherwise the day composes without the "1", silently; 🟡 changes
/// nothing (FR-4). A 🔴 day narrows further (Story 2.5): only
/// candidates within [lowEnergyMaxEstimateSeconds] reach any draw list
/// — upkeep (3 min) drops with the chunk and the instant habits stand —
/// while a card already in progress is never withdrawn (FR-10's
/// grammar). A day whose slot a `card_done` already closed composes
/// upkeep and habits only, and so does a day whose open session still
/// holds a dealt-but-unanswered card — an unanswered card never produces
/// a second card (AD-3), the shared pipeline's line now, not just the
/// deal-level one. Upkeep and habits are never charged to the bag (FR-7).
/// The [poolFacts] (Story 3.3) join the catalogue as the second
/// candidate source — origin-manual facts offered ahead of same-size
/// Evergreen material, FIFO by the fact's recorded creation instant,
/// a not-yet-answered focus capture the chunk tier ahead of every
/// zone tier, composing even with no active zone.
DayComposition composeDay({
  required Catalogue catalogue,
  required List<LogEntry> log,
  required int instantUtcMicros,
  required int offsetSeconds,
  int bagMinutes = defaultTimeBagMinutes,
  EnergyLevel energy = EnergyLevel.full,
  Set<CurationCluster>? activeClusters,
  List<PoolFact> poolFacts = const [],
  String? purgeStepText,
}) {
  final policy = _resolveDay(
    catalogue: catalogue,
    log: log,
    instantUtcMicros: instantUtcMicros,
    offsetSeconds: offsetSeconds,
    bagMinutes: bagMinutes,
    energy: energy,
    activeClusters: activeClusters,
    poolFacts: poolFacts,
    purgeStepText: purgeStepText,
  );
  return DayComposition(
    focus: policy.chunk,
    maintenance: policy.maintenance,
    instantHabits: policy.instantHabits,
  );
}

/// The resolver's next deal (AD-3, AD-20, AD-19): what the command that
/// answers the previous card — or `session_started` for a session's first
/// card — appends. **No open session, no deal**: a log with no unmatched
/// `session_started` resolves absent (Story 2.3) — deals exist only
/// inside sittings, exactly as this contract has always read, and a
/// sessionless proposal would be a card no command can answer
/// (`cardDone`'s side-door guard refuses sessionless answers). A
/// sitting's start — `sessionStart`'s synthesized present, or the
/// supersede pair's second half — is the deal's only door. Pure: it
/// computes the card and writes nothing. The chunk
/// slot resolves first while open and gated — through the same tier
/// pipeline `composeDay` reads; identity re-resolves on every deal, so a
/// skip yields a different candidate and consumes no rotation; once the
/// day's maintenance and habit draws are dealt, the day offers nothing
/// more. An open session's dealt-but-unanswered card yields no deal at
/// all — an unanswered card never produces a second `card_dealt` (AD-3),
/// and the resolver itself holds that line, not only its callers. A
/// candidate the open session's declared pocket cannot hold is not
/// dealt (Story 2.2, FR-8): the tiers fall through in order — chunk,
/// upkeep, habits — and when nothing fits, or the pocket has elapsed at
/// this instant, the deal is absent and the read model presents the
/// warm close. No eager `session_ended` exists here or anywhere: the
/// close row lands at backgrounding, the declare tap, the reveal, or
/// the pause tap — AD-19's three closing causes at their four emission
/// sites. The [poolFacts] (Story 3.3) join the catalogue as the
/// second candidate source — a manual capture deals before any
/// same-size catalogue candidate, and a dealt capture charges its
/// size's daily count exactly like a catalogue deal.
Card? nextDeal({
  required Catalogue catalogue,
  required List<LogEntry> log,
  required int instantUtcMicros,
  required int offsetSeconds,
  int bagMinutes = defaultTimeBagMinutes,
  EnergyLevel energy = EnergyLevel.full,
  Set<CurationCluster>? activeClusters,
  List<PoolFact> poolFacts = const [],
  String? purgeStepText,
}) {
  final policy = _resolveDay(
    catalogue: catalogue,
    log: log,
    instantUtcMicros: instantUtcMicros,
    offsetSeconds: offsetSeconds,
    bagMinutes: bagMinutes,
    energy: energy,
    activeClusters: activeClusters,
    poolFacts: poolFacts,
    purgeStepText: purgeStepText,
  );
  return _guardedTierDealOf(policy, policy.pocketAllows);
}

/// The one decision behind both surfaces of the deal (Story 2.4's
/// unification): the sitting line and the tier ladder, with [allows]
/// as the offer's admission predicate — `nextDeal` threads the open
/// pocket's filter, and the checkpoint's close-continue probe runs
/// this same ladder over a lifted filter, so a change to the tiers can
/// never leave the close's continue offer behind (AD-20's single
/// resolver, one decision).
Card? _guardedTierDealOf(_DayPolicy policy, bool Function(Card card) allows) {
  if (policy.facts.openSessionStart == null) {
    // No open session, no deal (Story 2.3, AD-19): the resolver stops
    // proposing unanswerable cards — `cardDone` would refuse the answer,
    // so the read model presents the warm close instead of a dead card.
    // The walk tolerates imported sessionless `card_*` rows unchanged;
    // only the proposal stops here.
    return null;
  }
  if (policy.facts.dealtUnanswered != null) {
    // The open session still holds its dealt-but-unanswered card: no
    // second deal exists to append while it stands (AD-3). Answering it
    // — or closing the session — clears the fact and frees the resolver.
    return null;
  }
  // The tiers (AD-20): a live chain's head first (Story 4.6 — the
  // conversion stands ahead of everything, no new chunk may bury the
  // next step), then the chunk while it composes, then the day's
  // remaining maintenance draws, then the instant draws — each tier's
  // head offered only when [allows] admits it. When nothing does, the
  // deal is absent and the read model presents the warm close. No
  // eager `session_ended` exists here or anywhere: the close row lands
  // at backgrounding, the declare tap, the reveal, or the pause tap —
  // AD-19's three closing causes at their four emission sites.
  if (policy.rescueHeads.isNotEmpty && allows(policy.rescueHeads[0])) {
    return policy.rescueHeads[0];
  }
  final chunk = policy.chunk;
  if (chunk != null && allows(chunk)) {
    return chunk;
  }
  // The purge tier (Story 6.1, FR-19): directly above the Epic
  // material's every door — the chunk pool resolves a pending purge
  // above every Epic head while the "1" composes, and this tier
  // holds the same order on the days it does not (a 🔴 day, a bag
  // under the chunk floor, a slot an earlier answer closed), so the
  // purge still deals — 60 s passes the pocket filter by construction
  // — before any organization step. Rescue keeps its tier above, and
  // a capture kept the chunk's own capture tier: the user's live
  // commitments outrank the injection, the injected step outranks
  // the plan.
  if (policy.purgeHeads.isNotEmpty && allows(policy.purgeHeads[0])) {
    return policy.purgeHeads[0];
  }
  if ((policy.dealtOnDay[Size.maintenance] ?? 0) < maintenanceDrawsPerDay &&
      policy.maintenance.isNotEmpty &&
      allows(policy.maintenance[0])) {
    return policy.maintenance[0];
  }
  if ((policy.dealtOnDay[Size.instant] ?? 0) < instantDrawsPerDay &&
      policy.instantHabits.isNotEmpty &&
      allows(policy.instantHabits[0])) {
    return policy.instantHabits[0];
  }
  return null;
}

/// Whether a deal would exist if the open session's pocket had room —
/// the checkpoint's close-continue probe (Story 2.4, FR-10, UJ-1). The
/// resolver's own pipeline runs with the pocket filter lifted, so the
/// shared ladder above decides on the pool alone: a pool-exhausted day
/// and a spent day's draws answer false exactly as they would behind
/// the filter, while an elapsed or spent pocket can no longer hide
/// candidates the sitting could still hold. Everything else is
/// `nextDeal`'s own contract: no open session, or a
/// dealt-but-unanswered card standing, and no deal would exist either
/// way — the close carries nothing to continue with. A read, never a
/// write: the probe appends nothing and deals nothing (AD-3, AD-20).
/// The [poolFacts] (Story 3.3) join the catalogue as the second
/// candidate source, exactly as `nextDeal` reads them.
bool dealExistsIgnoringPocket({
  required Catalogue catalogue,
  required List<LogEntry> log,
  required int instantUtcMicros,
  required int offsetSeconds,
  int bagMinutes = defaultTimeBagMinutes,
  EnergyLevel energy = EnergyLevel.full,
  Set<CurationCluster>? activeClusters,
  List<PoolFact> poolFacts = const [],
  String? purgeStepText,
}) {
  final policy = _resolveDay(
    catalogue: catalogue,
    log: log,
    instantUtcMicros: instantUtcMicros,
    offsetSeconds: offsetSeconds,
    bagMinutes: bagMinutes,
    energy: energy,
    activeClusters: activeClusters,
    poolFacts: poolFacts,
    purgeStepText: purgeStepText,
    liftedPocket: true,
  );
  // The lifted pocket's filter admits every card, so the ladder reads
  // the pool's own truth and nothing else.
  return _guardedTierDealOf(policy, policy.pocketAllows) != null;
}

/// The card for a referenced item — the catalogue first, then (since
/// Story 3.3) the handed-in pool facts: a manual fact renders through
/// its own Origin Context as the name, its own taxonomy size as the
/// size and no zone, so a dealt-but-unanswered capture survives reads
/// exactly as a catalogue card does — the standing-card path never
/// depends on candidacy. Absent when no source knows the id. The
/// [origin] param stays the row's own carried origin — the answer
/// commands match on the (itemId, origin) pair the log holds.
Card? cardForItem({
  required Catalogue catalogue,
  required String itemId,
  required Origin origin,
  List<PoolFact> poolFacts = const [],
  String? purgeStepText,
}) {
  if (itemId.startsWith(purgeItemIdPrefix)) {
    // The purge card (Story 6.1): synthetic — no catalogue entry and
    // no pool fact ever carries the id, so the prefix alone names it
    // and the card re-materializes from the same constants the
    // candidate was derived with: a dealt-but-unanswered purge
    // survives reads exactly as any standing card does. [origin]
    // stays the row's own carried origin, and an absent
    // [purgeStepText] renders the empty name — the seam
    // `purgeCandidates` documents, never a production state.
    return Card(
      id: itemId,
      size: sizeOfEstimateSeconds(purgeStepEstimateSeconds),
      name: purgeStepText ?? '',
      origin: origin,
      zone: null,
      estimateSeconds: purgeStepEstimateSeconds,
    );
  }
  for (final entry in catalogue.entries) {
    if (entry.id == itemId) {
      return Card(
        id: entry.id,
        size: entry.size,
        name: entry.name,
        origin: origin,
        zone: entry.zone,
        estimateSeconds: estimateSecondsOf(entry.size),
      );
    }
  }
  for (final fact in poolFacts) {
    if (fact.id == itemId) {
      return Card(
        id: fact.id,
        size: fact.size,
        // The step's own words name the card once a scan step exists
        // (Story 5.9): `stepText` is non-null exactly there, so a
        // manual capture or rescue step still renders through its own
        // Origin Context unchanged.
        name: fact.stepText ?? fact.originContext ?? '',
        origin: origin,
        zone: null,
        // A rescue step's own verbatim estimate stands on its standing
        // card exactly as on its deal (Story 4.6) — the pocket reads
        // the same number either way.
        estimateSeconds: fact.estimateSeconds ?? estimateSecondsOf(fact.size),
      );
    }
  }
  return null;
}

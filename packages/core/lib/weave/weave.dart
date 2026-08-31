/// The 1-3-5 weave (FR-12) and AD-20's single resolver: the pure
/// composition of a domestic day out of the catalogue, the log, the
/// scaling gates and the resolved curation state. Nothing derived is
/// stored (AD-1) — the composition is recomputed from replayable facts
/// whenever a deal needs it.
///
/// `core/weave` is the only code that may emit a deal (AD-20): every
/// work source — today only the shipped catalogue, later captures,
/// rescue and purge — offers candidates with precedence, and the resolver
/// below is the single place that turns them into a card. The module
/// stays deterministic (AD-3): no `Random`, no wall clock, no
/// `dart:io`, and ties break by least-recently-dealt then stable id,
/// never id bit patterns.
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
import 'package:core/energy/energy.dart';
import 'package:core/log/log_entry.dart';
import 'package:core/pool/pool_fact.dart';
import 'package:core/settings/settings.dart';
import 'package:core/weave/session.dart';

// The per-size duration estimates (FR-27) live in `core/weave/session`
// beside the walk that charges them to a declared pocket (Story 2.2);
// re-exported here so the weave's callers keep one import — the names
// below are this library's public surface, unchanged.
export 'package:core/weave/session.dart'
    show
        estimateSecondsOf,
        focusEstimateSeconds,
        instantEstimateSeconds,
        maintenanceEstimateSeconds;

/// A Focus Chunk composes only from this much bag (FR-7): below it the
/// day composes without the "1", silently — no debt, no mention. The
/// bag's range and its default of 15 live in `core/settings` (2.1) —
/// one source of truth; this is the weave's own policy threshold, not
/// the setting's range.
const int focusChunkLeastBagMinutes = 10;

/// A 🔴 day admits only work this short (FR-4, Story 2.5): while the
/// derived energy is low, a candidate is dealt — or composed — only
/// when its duration estimate stays within this ceiling. The rule is
/// estimate-based, not size-based, on purpose: today's catalogue makes
/// it ≡ Instant Habits, but FR-5's rescue steps and Epic 6's purge
/// steps (each ≤ 60 s) stay eligible on a 🔴 day by construction —
/// the epic's cross-dependency line — and no second filter needs to
/// know about them. The ceiling applies to the next deal and the
/// composed day alike, never to a card in progress (work in progress
/// is never withdrawn, FR-10's grammar).
const int lowEnergyMaxEstimateSeconds = 60;

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

/// Where a candidate stands in AD-20's arbitration. One member today —
/// the shipped catalogue is 1.6's only candidate source; later sources
/// (capture precedence, rescue steps, purge injection) join as members,
/// never as flags on this one.
enum CandidatePrecedence {
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
/// first, then least-recently-dealt — recorded `card_dealt` instants,
/// never-dealt first — then stable id order. Never id bit patterns.
int _resolverOrder(
  Candidate a,
  Candidate b,
  Map<String, int> lastDealtInstantByItemId,
) {
  final byPrecedence = a.precedence.index.compareTo(b.precedence.index);
  if (byPrecedence != 0) {
    return byPrecedence;
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
  estimateSeconds: estimateSecondsOf(candidate.size),
);

List<Card> _draw(List<Candidate> ofSize, LogFacts facts, int count) {
  final ordered = _orderedByResolver(ofSize, facts);
  return [for (final candidate in ordered.take(count)) _cardOf(candidate)];
}

/// The chunk slot's candidate (AD-20's tiers, in order): the active
/// zone's focus entries never **answered** (`card_done`) all-time, then
/// `fondo` (seasonal focus) never answered, then the least-recently-dealt
/// eligible focus entry regardless of zone — repetition accepted, never
/// an empty day while any eligible entry exists. Ties within a tier
/// break by least-recently-dealt then stable id (AD-3). With no active
/// zone (FR-11's ring empty) the tiers are empty — this returns absent.
Candidate? _chunkCandidateOf(
  List<Candidate> focusCandidates,
  LogFacts facts,
  Zone? activeZone,
) {
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
    !facts.focusSlotClosedDays.contains(day);

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
  bool liftedPocket = false,
}) {
  final facts = walkLog(log, catalogue: catalogue);
  final day = anchorDayOf(facts, instantUtcMicros, offsetSeconds);
  final clusters = activeClusters ?? allCurationClusters;
  // The 🔴 day's admission (FR-4, Story 2.5): while the derived energy
  // is low, only candidates whose duration estimate stays within
  // [lowEnergyMaxEstimateSeconds] reach the chunk tier or any draw
  // list — the single filter every consumer inherits, inside this
  // pipeline, so `nextDeal`, `composeDay` and the close-continue probe
  // cannot drift (the chunk gate above already drops the "1" at low;
  // this line narrows the tiers beneath it). The ceiling reads the
  // card's estimate; today that estimate derives from taxonomy size
  // because the catalogue carries no per-item estimates — so the rule
  // and today's sizes coincide at the instant tier — and transient
  // steps that carry their own estimates (FR-5's rescue, Epic 6's
  // purge, each ≤ 60 s) meet the same ceiling when their sources
  // arrive.
  bool lowEnergyAdmits(Size size) =>
      energy != EnergyLevel.low ||
      estimateSecondsOf(size) <= lowEnergyMaxEstimateSeconds;
  final candidates = [
    for (final candidate in shippedCandidates(
      catalogue,
      activeClusters: clusters,
    ))
      if (lowEnergyAdmits(candidate.size)) candidate,
  ];
  Card? chunk;
  if (_chunkComposes(bagMinutes, energy, facts, day) &&
      facts.dealtUnanswered == null) {
    final activeZone = activeZoneOf(const Calendar().weekOf(day), clusters);
    final chunkCandidate = _chunkCandidateOf(
      candidates.where((candidate) => candidate.size == Size.focus).toList(),
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
    maintenance: _draw(
      candidates
          .where((candidate) => candidate.size == Size.maintenance)
          .toList(),
      facts,
      maintenanceDrawsPerDay,
    ),
    instantHabits: _draw(
      candidates.where((candidate) => candidate.size == Size.instant).toList(),
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
DayComposition composeDay({
  required Catalogue catalogue,
  required List<LogEntry> log,
  required int instantUtcMicros,
  required int offsetSeconds,
  int bagMinutes = defaultTimeBagMinutes,
  EnergyLevel energy = EnergyLevel.full,
  Set<CurationCluster>? activeClusters,
}) {
  final policy = _resolveDay(
    catalogue: catalogue,
    log: log,
    instantUtcMicros: instantUtcMicros,
    offsetSeconds: offsetSeconds,
    bagMinutes: bagMinutes,
    energy: energy,
    activeClusters: activeClusters,
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
/// sites.
Card? nextDeal({
  required Catalogue catalogue,
  required List<LogEntry> log,
  required int instantUtcMicros,
  required int offsetSeconds,
  int bagMinutes = defaultTimeBagMinutes,
  EnergyLevel energy = EnergyLevel.full,
  Set<CurationCluster>? activeClusters,
}) {
  final policy = _resolveDay(
    catalogue: catalogue,
    log: log,
    instantUtcMicros: instantUtcMicros,
    offsetSeconds: offsetSeconds,
    bagMinutes: bagMinutes,
    energy: energy,
    activeClusters: activeClusters,
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
  // The tiers (AD-20): the chunk while it composes, then the day's
  // remaining maintenance draws, then the instant draws — each tier's
  // head offered only when [allows] admits it. When nothing does, the
  // deal is absent and the read model presents the warm close. No
  // eager `session_ended` exists here or anywhere: the close row lands
  // at backgrounding, the declare tap, the reveal, or the pause tap —
  // AD-19's three closing causes at their four emission sites.
  final chunk = policy.chunk;
  if (chunk != null && allows(chunk)) {
    return chunk;
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
bool dealExistsIgnoringPocket({
  required Catalogue catalogue,
  required List<LogEntry> log,
  required int instantUtcMicros,
  required int offsetSeconds,
  int bagMinutes = defaultTimeBagMinutes,
  EnergyLevel energy = EnergyLevel.full,
  Set<CurationCluster>? activeClusters,
}) {
  final policy = _resolveDay(
    catalogue: catalogue,
    log: log,
    instantUtcMicros: instantUtcMicros,
    offsetSeconds: offsetSeconds,
    bagMinutes: bagMinutes,
    energy: energy,
    activeClusters: activeClusters,
    liftedPocket: true,
  );
  // The lifted pocket's filter admits every card, so the ladder reads
  // the pool's own truth and nothing else.
  return _guardedTierDealOf(policy, policy.pocketAllows) != null;
}

/// The card for a referenced catalogue item, or absent when the catalogue
/// holds no such id (a future origin's items carry their own names when
/// their sources arrive).
Card? cardForItem({
  required Catalogue catalogue,
  required String itemId,
  required Origin origin,
}) {
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
  return null;
}

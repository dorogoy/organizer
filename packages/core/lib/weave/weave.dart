/// The 1-3-5 weave (FR-12) and AD-20's single resolver: the pure
/// composition of a domestic day out of the catalogue, the log and the
/// scaling gates. Nothing derived is stored (AD-1) — the composition is
/// recomputed from replayable facts whenever a deal needs it.
///
/// `core/weave` is the only code that may emit a deal (AD-20): every
/// work source — today only the shipped catalogue, later captures,
/// `fondo`, rescue and purge — offers candidates with precedence, and
/// the resolver below is the single place that turns them into a card.
/// The module stays deterministic (AD-3): no `Random`, no wall clock, no
/// `dart:io`, and ties break by least-recently-dealt then stable id,
/// never id bit patterns.

library;

import 'package:core/catalogue/catalogue.dart';
import 'package:core/day/calendar.dart';
import 'package:core/energy/energy.dart';
import 'package:core/log/log_entry.dart';
import 'package:core/pool/pool_fact.dart';
import 'package:core/weave/session.dart';

/// The Time Bag default, 15 minutes (FR-7, §10.1) — a named core
/// constant; the setter surface is Epic 2's.
const int defaultBagMinutes = 15;

/// A Focus Chunk composes only from this much bag (FR-7): below it the
/// day composes without the "1", silently — no debt, no mention.
const int focusChunkLeastBagMinutes = 10;

/// The canonical 1-3-5 draw counts (FR-12): one Focus Chunk, three
/// Micro-maintenance draws, five Instant Habit draws. Scaling drops
/// counts; it never shrinks an estimate.
const int maintenanceDrawsPerDay = 3;
const int instantDrawsPerDay = 5;

/// The per-size duration estimates (FR-27), in seconds: the canonical
/// day sums to roughly 26 min (≈15 + 9 + 2.5), and the chunk's estimate
/// fits the default bag exactly — 15 against 15 exceeds nothing.
const int focusEstimateSeconds = 15 * 60;
const int maintenanceEstimateSeconds = 3 * 60;
const int instantEstimateSeconds = 30;

/// The duration estimate of one taxonomy size, in seconds.
int estimateSecondsOf(Size size) => switch (size) {
  Size.focus => focusEstimateSeconds,
  Size.maintenance => maintenanceEstimateSeconds,
  Size.instant => instantEstimateSeconds,
};

/// One composed card (FR-1): the item's id, its taxonomy size, its
/// resolved Spanish name (a shipped task's Origin Context, AD-16), its
/// origin, and the per-size duration estimate in seconds. A value: two
/// cards are the same card iff every field matches.
final class Card {
  const Card({
    required this.id,
    required this.size,
    required this.name,
    required this.origin,
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

  final int estimateSeconds;

  @override
  bool operator ==(Object other) =>
      other is Card &&
      other.id == id &&
      other.size == size &&
      other.name == name &&
      other.origin == origin &&
      other.estimateSeconds == estimateSeconds;

  @override
  int get hashCode => Object.hash(id, size, name, origin, estimateSeconds);

  @override
  String toString() =>
      'Card(${id.toString()}, ${size.name}, ${origin.name}, '
      '${estimateSeconds}s)';
}

/// Where a candidate stands in AD-20's arbitration. One member today —
/// the shipped catalogue is 1.6's only candidate source; later sources
/// (capture precedence, `fondo` fill, rescue steps, purge injection)
/// join as members, never as flags on this one.
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
    required this.precedence,
  });

  final String itemId;
  final Size size;
  final String name;
  final Origin origin;
  final CandidatePrecedence precedence;
}

/// The shipped catalogue as a candidate source (AD-16, AD-20): entries
/// become `Origin.shipped` items — id the permanent catalogue id, name
/// already resolved — handed to the resolver as inert data, never
/// materialized as `pool_facts` rows. The focus-size offering excludes
/// daily entries: Baseline Upkeep, however well its size fits, never
/// occupies the chunk slot (FR-12).
List<Candidate> shippedCandidates(Catalogue catalogue) {
  return [
    for (final entry in catalogue.entries)
      if (entry.size != Size.focus || entry.cadence != Cadence.daily)
        Candidate(
          itemId: entry.id,
          size: entry.size,
          name: entry.name,
          origin: Origin.shipped,
          precedence: CandidatePrecedence.catalogue,
        ),
  ];
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

List<Card> _draw(List<Candidate> ofSize, LogFacts facts, int count) {
  final ordered = List.of(ofSize)
    ..sort((a, b) => _resolverOrder(a, b, facts.lastDealtInstantByItemId));
  return [
    for (final candidate in ordered.take(count))
      Card(
        id: candidate.itemId,
        size: candidate.size,
        name: candidate.name,
        origin: candidate.origin,
        estimateSeconds: estimateSecondsOf(candidate.size),
      ),
  ];
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

/// Composes the day (FR-12, AD-20): a pure function of the catalogue,
/// the log and the scaling inputs. The chunk is composed only when the
/// bag holds [focusChunkLeastBagMinutes] or more and the derived energy
/// is not low — otherwise the day composes without the "1", silently;
/// 🟡 changes nothing (FR-4). A day whose slot a `card_done` already
/// closed composes upkeep and habits only. Upkeep and habits are never
/// charged to the bag (FR-7).
DayComposition composeDay({
  required Catalogue catalogue,
  required List<LogEntry> log,
  required int instantUtcMicros,
  required int offsetSeconds,
  int bagMinutes = defaultBagMinutes,
  EnergyLevel energy = EnergyLevel.full,
}) {
  final facts = walkLog(log, catalogue: catalogue);
  final day = anchorDayOf(facts, instantUtcMicros, offsetSeconds);
  final candidates = shippedCandidates(catalogue);
  final focusDraws = _draw(
    candidates.where((candidate) => candidate.size == Size.focus).toList(),
    facts,
    1,
  );
  final maintenanceDraws = _draw(
    candidates
        .where((candidate) => candidate.size == Size.maintenance)
        .toList(),
    facts,
    maintenanceDrawsPerDay,
  );
  final instantDraws = _draw(
    candidates.where((candidate) => candidate.size == Size.instant).toList(),
    facts,
    instantDrawsPerDay,
  );
  return DayComposition(
    focus:
        _chunkComposes(bagMinutes, energy, facts, day) && focusDraws.isNotEmpty
        ? focusDraws[0]
        : null,
    maintenance: maintenanceDraws,
    instantHabits: instantDraws,
  );
}

/// The resolver's next deal (AD-3, AD-20): what the command that answers
/// the previous card — or `session_started` for a session's first card —
/// appends. Pure: it computes the card and writes nothing. The chunk
/// slot resolves first while open and gated; identity re-resolves on
/// every deal, so a skip yields a different candidate and consumes no
/// rotation; once the day's maintenance and habit draws are dealt, the
/// day offers nothing more.
Card? nextDeal({
  required Catalogue catalogue,
  required List<LogEntry> log,
  required int instantUtcMicros,
  required int offsetSeconds,
  int bagMinutes = defaultBagMinutes,
  EnergyLevel energy = EnergyLevel.full,
}) {
  final facts = walkLog(log, catalogue: catalogue);
  final day = anchorDayOf(facts, instantUtcMicros, offsetSeconds);
  final candidates = shippedCandidates(catalogue);
  final dealtOnDay = facts.dealtCountsByDay[day] ?? const <Size, int>{};

  if (_chunkComposes(bagMinutes, energy, facts, day)) {
    final chunk = _draw(
      candidates.where((candidate) => candidate.size == Size.focus).toList(),
      facts,
      1,
    );
    if (chunk.isNotEmpty) {
      return chunk[0];
    }
  }

  if ((dealtOnDay[Size.maintenance] ?? 0) < maintenanceDrawsPerDay) {
    final maintenance = _draw(
      candidates
          .where((candidate) => candidate.size == Size.maintenance)
          .toList(),
      facts,
      1,
    );
    if (maintenance.isNotEmpty) {
      return maintenance[0];
    }
  }

  if ((dealtOnDay[Size.instant] ?? 0) < instantDrawsPerDay) {
    final habits = _draw(
      candidates.where((candidate) => candidate.size == Size.instant).toList(),
      facts,
      1,
    );
    if (habits.isNotEmpty) {
      return habits[0];
    }
  }

  return null;
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
        estimateSeconds: estimateSecondsOf(entry.size),
      );
    }
  }
  return null;
}

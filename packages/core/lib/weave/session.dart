/// The derived session and the one log walk (AD-19, AD-20): every
/// session fact the weave consumes falls out of a single ordered pass
/// over the log — which session is open, the domestic day every card act
/// is charged to, the days whose Focus Chunk slot a `card_done` closed,
/// the items a `card_done` answered all-time, the least-recently-dealt
/// index, the domestic days each item's deals were charged to (Story
/// 3.3's deal-window input), and the open session's dealt-but-unanswered
/// card.
///
/// Nothing here is stored (AD-1): the walk is a pure function of the
/// entries, replayed whenever a derivation needs it. Entries arrive in
/// the store port's replay order — recorded instant first, then append
/// sequence — and the walk trusts that order (AD-3: ordering reads
/// recorded act instants, never id bit patterns).

library;

import 'package:core/catalogue/catalogue.dart';
import 'package:core/day/calendar.dart';
import 'package:core/log/log_entry.dart';
import 'package:core/pool/pool_fact.dart';
import 'package:core/settings/settings.dart';

/// The per-size duration estimates (FR-27), in seconds: the canonical
/// day sums to roughly 26 min (≈15 + 9 + 2.5), and the chunk's estimate
/// fits the default bag exactly — 15 against 15 exceeds nothing. The
/// walk charges these to a declared pocket on every answered card
/// (Story 2.2); the weave re-exports them so its callers keep one
/// import.
const int focusEstimateSeconds = 15 * 60;
const int maintenanceEstimateSeconds = 3 * 60;
const int instantEstimateSeconds = 30;

/// The duration estimate of one taxonomy size, in seconds.
int estimateSecondsOf(Size size) => switch (size) {
  Size.focus => focusEstimateSeconds,
  Size.maintenance => maintenanceEstimateSeconds,
  Size.instant => instantEstimateSeconds,
};

/// The facts one ordered walk of the log yields. Field names are facts,
/// never verbs (AD-6): each states something the log makes true.
final class LogFacts {
  const LogFacts({
    required this.lastDealtInstantByItemId,
    required this.focusSlotClosedDays,
    required this.dealtCountsByDay,
    required this.dealtDaysByItemId,
    required this.skippedDaysByItemId,
    required this.answeredItemIds,
    required this.openSessionStart,
    required this.dealtUnanswered,
    required this.openSessionPocketMinutes,
    required this.openSessionAnsweredSeconds,
    required this.focusSlotCarriedDays,
  });

  /// Per item id, the instant of its latest recorded `card_dealt` —
  /// AD-3's least-recently-dealt tie-break reads recorded act instants;
  /// an absent id was never dealt and ranks first.
  final Map<String, int> lastDealtInstantByItemId;

  /// The domestic days whose Focus Chunk slot a focus-size `card_done`
  /// closed — occupancy is once per domestic day, and only a
  /// `card_done` closes it (AD-20). Since Story 4.6 a completed
  /// focus-parent rescue chain closes the slot on the day of the
  /// session that dealt its LAST step's `card_done` — the session-day
  /// rule's own day, crossing-safe and energy-override, never a
  /// synthetic `card_done` row (AD-25: the derivation, not the
  /// vocabulary, states the completion).
  final Set<Day> focusSlotClosedDays;

  /// Per domestic day, how many `card_dealt` rows were charged to it by
  /// the dealt item's taxonomy size — the day's draw counts.
  final Map<Day, Map<Size, int>> dealtCountsByDay;

  /// Per item id, the domestic days a `card_dealt` was charged to —
  /// the capture's deal-window consumption input (Story 3.3, AD-24),
  /// unconditional in the item's id: a day lands here whether or not
  /// any source could size the item, and the window fold reads these
  /// days without re-deriving attribution (AD-19's session-day rule,
  /// the same rule [dealtCountsByDay] charges by).
  final Map<String, Set<Day>> dealtDaysByItemId;

  /// Per item id, the domestic days a `card_skipped` was charged to —
  /// the rescue refusal counter's input (Story 4.6, FR-5, AD-24's
  /// predicate over the same session-day attribution): a day lands
  /// here exactly when the item was declined on it, and the counter
  /// reads these days without re-deriving attribution. Same-day
  /// re-skips stay one day — the set semantics [dealtDaysByItemId]
  /// already holds.
  final Map<String, Set<Day>> skippedDaysByItemId;

  /// Every item id with a recorded `card_done`, all-time: an answered
  /// deal, the only thing that consumes (AD-20 — FR-31's floor counts
  /// answered deals, not calendar days, and a skip consumes nothing).
  final Set<String> answeredItemIds;

  /// The open session's start instant and its stored offset, or absent
  /// when no session is open — the latest `session_started` with no
  /// matching `session_ended` (AD-19).
  final ({int instantUtcMicros, int offsetSeconds})? openSessionStart;

  /// The open session's dealt-but-unanswered card, if any: the last
  /// `card_dealt` inside it with no answering `card_done` or
  /// `card_skipped` on the same (itemId, itemOrigin) since — and,
  /// since Story 4.6, no answering `slice_returned` either: a
  /// successful rescue supersedes the standing card exactly as an
  /// answer does, the supersede pair's first half. An unanswered card
  /// never produces a second deal (AD-3).
  final ({String itemId, Origin itemOrigin})? dealtUnanswered;

  /// The open session's declared pocket in minutes — the start row's
  /// own payload plus the sum of the extensions that sitting has
  /// accepted (Story 2.4, AD-19): the deadline and the ceiling lift
  /// with the sum, which may pass the declarable 1–60 range (it bounds
  /// starts only). Absent when the session is unbounded, none is open,
  /// or the start row's value derives as absent (an imported
  /// out-of-range pocket reads as no pocket at all, never a repair
  /// write — AD-23); an unbounded sitting stays unbounded, for an
  /// extension cannot bound what no start declared. The original
  /// pocket stays readable on the start row itself (FR-23's input);
  /// this fact is the sitting's lifted declaration.
  final int? openSessionPocketMinutes;

  /// The open session's answered estimate, in seconds: the per-size
  /// estimate of every `card_done` charged to it — upkeep included,
  /// a dealt-unanswered card consumes nothing, and a skip releases
  /// its estimate (Story 2.2, FR-8, FR-12). Since Story 4.6 a rescue
  /// step charges its OWN verbatim estimate, the fact's recorded tag
  /// — the duration-consuming rules read the estimate, never the
  /// size's default, on a step. Session-scoped, never day-scoped: a
  /// superseding declaration restarts it at zero.
  final int openSessionAnsweredSeconds;

  /// The domestic days whose dealt Focus Chunk a rescue conversion
  /// carried (Story 4.6, FR-7, ADV-10): the day a `slice_returned`
  /// superseded a standing focus-size card — the activation converted
  /// the day's "1" into its rescue steps, so no new chunk composes
  /// that day and the chain holds the advance. A FAILED rescue lands
  /// nothing here: the card stands dealable and a plain skip still
  /// re-resolves a new chunk (AD-20's recorded override).
  final Set<Day> focusSlotCarriedDays;
}

/// The domestic day an act at [instantUtcMicros] / [offsetSeconds] is
/// charged to: its dealing session's own start day while one is open
/// (AD-19), else the act's own day. The one definition of the
/// session-day rule — the walk and [anchorDayOf] share it, so no second
/// copy can drift.
Day _chargedDayOf(
  Calendar calendar,
  ({int instantUtcMicros, int offsetSeconds})? openSessionStart,
  int instantUtcMicros,
  int offsetSeconds,
) {
  final open = openSessionStart;
  if (open != null) {
    return calendar.dayOf(open.instantUtcMicros, open.offsetSeconds);
  }
  return calendar.dayOf(instantUtcMicros, offsetSeconds);
}

/// Walks the log once (AD-19): `session_started` opens a session, the
/// matching `session_ended` closes it, and every `card_*` inside belongs
/// to that session's own start day — a session crossing 04:00 charges
/// every card act to its start day, never the crossed-into day. A card
/// act outside any session (no command writes one) falls back to its own
/// instant's day, so the walk stays total. Unknown kinds, crash entries
/// and `setting_changed` rows pass through untouched — settings are read
/// by the shell's own derivation (2.1), never by the weave's internal
/// policy. The [catalogue] resolves a referenced
/// item's taxonomy size — the shipped catalogue is 1.6's only item
/// source; an id it does not know carries no size yet and closes
/// nothing, and later sources extend exactly here. The [poolFacts]
/// (Story 3.3) are the second sizing source at that same seam,
/// fill-only-absent: a manual fact's id carries its own taxonomy
/// size, so its deals charge the day's draw counts, its focus done
/// closes chunk slots and its answers charge the sitting's estimate
/// exactly like a shipped id's — while the walk stays inert to
/// `capture_created` rows themselves (candidacy reads facts, never
/// the kind). A fact id the catalogue already sizes keeps the
/// catalogue's, and a duplicate fact id keeps the snapshot's first.
/// Catalogue ids
/// must be unique ([parseCatalogue] enforces this on the asset path);
/// a hand-built duplicate fails the walk fast rather than reading a
/// last-wins size (AD-23).
///
/// The supersede pair (Story 2.2, AD-19): a `session_started` that
/// directly follows a same-instant `session_ended` in store read order
/// preserves the dealt-but-unanswered card — the declare tap's
/// `[session_ended, session_started{pocket}]` carries in-progress work
/// across the boundary, and its later `card_done` charges the new
/// session. Any other `session_started` clears the standing card, as
/// ever.
///
/// The extensions (Story 2.4, FR-10, AD-19): a `session_extended` row
/// inside the open session sums its minutes into the sitting's declared
/// pocket — the deadline and ceiling lift, and the sum may pass the
/// declarable 1–60 range, which bounds starts only. A session's close
/// resets the sum with the rest of the sitting's facts, so a superseded
/// sitting's extensions die with it; the start's own 1–60 guard is
/// untouched. The command boundary keeps the kind out of a supersede
/// pair's interior (nothing is open at such an instant to extend), so
/// the pair adjacency here is unchanged. An extension outside any
/// session, or one whose minutes are not a positive count, sums
/// nothing — tolerance, never repair (AD-23).
LogFacts walkLog(
  List<LogEntry> entries, {
  Catalogue? catalogue,
  List<PoolFact> poolFacts = const [],
}) {
  const calendar = Calendar();
  final sizeByItemId = <String, Size>{};
  if (catalogue != null) {
    for (final entry in catalogue.entries) {
      if (sizeByItemId.containsKey(entry.id)) {
        throw StateError(
          'duplicate catalogue id "${entry.id}" — ids are permanent and '
          'unique once shipped (AD-23); a fixture bypassing '
          'parseCatalogue has drifted',
        );
      }
      sizeByItemId[entry.id] = entry.size;
    }
  }
  for (final fact in poolFacts) {
    // Fill-only-absent, never overwrite: the catalogue wins an id
    // collision (the same precedence `cardForItem` resolves by —
    // catalogue first, facts behind), and a duplicate fact id keeps
    // the snapshot's first, replay order being the one order the
    // store guarantees (AD-3).
    sizeByItemId.putIfAbsent(fact.id, () => fact.size);
  }

  // The rescue chains (Story 4.6): a step fact names its parent through
  // `rescueOf`, and the chains group by that id in snapshot order — the
  // head step of a chain is its first fact, the completion check reads
  // them all. A step whose estimate the fact carries charges that
  // estimate, never its size's default (the duration-consuming rules
  // read the estimate).
  final rescueParentOfByStepId = <String, String>{};
  final chainStepIdsByParent = <String, List<String>>{};
  final estimateByItemId = <String, int>{};
  for (final fact in poolFacts) {
    final parent = fact.rescueOf;
    if (parent != null) {
      rescueParentOfByStepId.putIfAbsent(fact.id, () => parent);
      chainStepIdsByParent.putIfAbsent(parent, () => []).add(fact.id);
    }
    if (fact.estimateSeconds != null) {
      estimateByItemId.putIfAbsent(fact.id, () => fact.estimateSeconds!);
    }
  }

  final lastDealtInstantByItemId = <String, int>{};
  final focusSlotClosedDays = <Day>{};
  final dealtCountsByDay = <Day, Map<Size, int>>{};
  final dealtDaysByItemId = <String, Set<Day>>{};
  final skippedDaysByItemId = <String, Set<Day>>{};
  final answeredItemIds = <String>{};
  ({int instantUtcMicros, int offsetSeconds})? openSessionStart;
  ({String itemId, Origin itemOrigin})? dealtUnanswered;
  int? openSessionPocketMinutes;
  var openSessionAnsweredSeconds = 0;
  final focusSlotCarriedDays = <Day>{};

  void chargeDealToDay(Day day, Size? size) {
    if (size == null) {
      return;
    }
    final bySize = dealtCountsByDay.putIfAbsent(day, () => {});
    bySize[size] = (bySize[size] ?? 0) + 1;
  }

  Day dayOfOpenOrOwnSession(LogEntry act) => _chargedDayOf(
    calendar,
    openSessionStart,
    act.instantUtcMicros,
    act.offsetSeconds,
  );

  for (var i = 0; i < entries.length; i++) {
    final entry = entries[i];
    switch (entry) {
      case SessionStartEntry():
        // The supersede pair's second half: the started row directly
        // follows a same-instant session_ended (whose own half, below,
        // declined to clear), so the in-progress card carries over —
        // only a start with no such predecessor clears the standing
        // deal.
        final previous = i > 0 ? entries[i - 1] : null;
        final followsSameInstantEnd =
            previous is MomentEntry &&
            previous.kind == LogKind.sessionEnded &&
            previous.instantUtcMicros == entry.instantUtcMicros;
        if (!followsSameInstantEnd) {
          dealtUnanswered = null;
        }
        openSessionStart = (
          instantUtcMicros: entry.instantUtcMicros,
          offsetSeconds: entry.offsetSeconds,
        );
        final declared = entry.pocketMinutes;
        openSessionPocketMinutes =
            (declared != null &&
                declared >= pocketLeastMinutes &&
                declared <= pocketMostMinutes)
            ? declared
            : null;
        openSessionAnsweredSeconds = 0;
      case MomentEntry(:final kind):
        if (kind == LogKind.sessionEnded) {
          // The pair's first half: an ended directly followed by a
          // same-instant started holds the standing card for its
          // successor to carry — every other ended clears it, as ever.
          final next = i + 1 < entries.length ? entries[i + 1] : null;
          final pairStartsNext =
              next is SessionStartEntry &&
              next.instantUtcMicros == entry.instantUtcMicros;
          if (!pairStartsNext) {
            dealtUnanswered = null;
          }
          openSessionStart = null;
          openSessionPocketMinutes = null;
          openSessionAnsweredSeconds = 0;
        }
      case SessionExtendEntry(:final pocketMinutes):
        // The sitting's extensions sum into its declared pocket
        // (Story 2.4, AD-19): the deadline and ceiling lift, the sum
        // may pass the declarable 1–60 range (it bounds starts only),
        // and the original pocket stays on the start row for FR-23. An
        // unbounded sitting stays unbounded — an extension cannot
        // retroactively bound what no start declared — and a value
        // that is not a positive minute count sums nothing (AD-23's
        // tolerance, the start row's out-of-range precedent).
        if (openSessionStart != null &&
            openSessionPocketMinutes != null &&
            pocketMinutes > 0) {
          openSessionPocketMinutes += pocketMinutes;
        }
      case ItemActEntry(:final kind, :final itemId, :final itemOrigin):
        if (kind == LogKind.cardDealt) {
          lastDealtInstantByItemId[itemId] = entry.instantUtcMicros;
          final chargedDay = dayOfOpenOrOwnSession(entry);
          chargeDealToDay(chargedDay, sizeByItemId[itemId]);
          dealtDaysByItemId.putIfAbsent(itemId, () => {}).add(chargedDay);
          if (openSessionStart != null) {
            dealtUnanswered = (itemId: itemId, itemOrigin: itemOrigin);
          }
        } else {
          if (kind == LogKind.cardSkipped) {
            // The decline's own charge (Story 4.6): a skip lands on its
            // session's day exactly as a deal does — the refusal
            // counter's input, unconditional in the item's id.
            skippedDaysByItemId
                .putIfAbsent(itemId, () => {})
                .add(dayOfOpenOrOwnSession(entry));
          }
          if (kind == LogKind.cardDone) {
            answeredItemIds.add(itemId);
            if (sizeByItemId[itemId] == Size.focus) {
              focusSlotClosedDays.add(dayOfOpenOrOwnSession(entry));
            }
            // The chain's completion (Story 4.6, ADV-10): the LAST
            // step's `card_done` closes the slot on its own session's
            // day when the parent is focus-sized — the only day the
            // completion charges, crossing-safe through the
            // session-day rule and regardless of that day's energy.
            // No synthetic `card_done` exists: this IS the derivation
            // AD-25 names.
            final parent = rescueParentOfByStepId[itemId];
            if (parent != null) {
              final chain = chainStepIdsByParent[parent] ?? const [];
              final allAnswered = chain.every(answeredItemIds.contains);
              if (allAnswered && sizeByItemId[parent] == Size.focus) {
                focusSlotClosedDays.add(dayOfOpenOrOwnSession(entry));
              }
            }
            if (openSessionStart != null) {
              final size = sizeByItemId[itemId];
              if (size != null) {
                // A step's own estimate charges, verbatim; anything
                // else its size's default (Story 4.6).
                openSessionAnsweredSeconds +=
                    estimateByItemId[itemId] ?? estimateSecondsOf(size);
              }
            }
          }
          final unanswered = dealtUnanswered;
          if (unanswered != null &&
              unanswered.itemId == itemId &&
              unanswered.itemOrigin == itemOrigin) {
            dealtUnanswered = null;
          }
        }
      case SliceEntry(:final kind, :final itemId, :final itemOrigin):
        // The supersede pair's rescue half (Story 4.6): only a
        // `slice_returned` naming the standing dealt-but-unanswered
        // card clears it — the bundled head-step deal that follows in
        // the same batch is the pair's second half, exactly the
        // `_answered` grammar. A `slice_requested` clears nothing:
        // the card stands while the request is in flight, and a
        // `slice_failed` leaves it standing for good.
        if (kind == LogKind.sliceReturned) {
          final unanswered = dealtUnanswered;
          if (unanswered != null &&
              unanswered.itemId == itemId &&
              unanswered.itemOrigin == itemOrigin) {
            dealtUnanswered = null;
            // FR-7's conversion (ADV-10): the superseded card was the
            // day's dealt Focus Chunk, so the chain carries the
            // advance — no new chunk composes that day. The charge is
            // the session-day rule's own, the entry's.
            if (sizeByItemId[itemId] == Size.focus) {
              focusSlotCarriedDays.add(dayOfOpenOrOwnSession(entry));
            }
          }
        }
      case CrashEntry():
      case SettingEntry():
      case EnergySetEntry():
      case ReportAnsweredEntry():
      case PermissionRefusedEntry():
      case UnknownEntry():
        break;
    }
  }

  return LogFacts(
    lastDealtInstantByItemId: lastDealtInstantByItemId,
    focusSlotClosedDays: focusSlotClosedDays,
    dealtCountsByDay: dealtCountsByDay,
    dealtDaysByItemId: dealtDaysByItemId,
    skippedDaysByItemId: skippedDaysByItemId,
    answeredItemIds: answeredItemIds,
    openSessionStart: openSessionStart,
    dealtUnanswered: dealtUnanswered,
    openSessionPocketMinutes: openSessionPocketMinutes,
    openSessionAnsweredSeconds: openSessionAnsweredSeconds,
    focusSlotCarriedDays: focusSlotCarriedDays,
  );
}

/// The day a composition at [instantUtcMicros] / [offsetSeconds] belongs
/// to: the open session's own day while one is open — a session crossing
/// 04:00 keeps composing for its start day, and the crossed-into day's
/// slot resolves only at the first deal after the session closes (AD-19,
/// AD-20) — else the day of the instant itself. The session-day rule is
/// [_chargedDayOf]'s, shared with the walk.
Day anchorDayOf(LogFacts facts, int instantUtcMicros, int offsetSeconds) =>
    _chargedDayOf(
      const Calendar(),
      facts.openSessionStart,
      instantUtcMicros,
      offsetSeconds,
    );

/// The latest index of a `card_done` naming [itemId], append order, or
/// -1 — the walk home reads the answer kind so a command file stays a
/// minter that never reads what it mints (Story 4.6's discard: only a
/// done after the activation ends the deal the rescue was converting).
int latestDoneIndex(List<LogEntry> log, String itemId) {
  var index = -1;
  for (var i = 0; i < log.length; i++) {
    final entry = log[i];
    if (entry is ItemActEntry &&
        entry.itemId == itemId &&
        entry.kind == LogKind.cardDone) {
      index = i;
    }
  }
  return index;
}

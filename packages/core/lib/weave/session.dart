/// The derived session and the one log walk (AD-19, AD-20): every
/// session fact the weave consumes falls out of a single ordered pass
/// over the log — which session is open, the domestic day every card act
/// is charged to, the days whose Focus Chunk slot a `card_done` closed,
/// the items a `card_done` answered all-time, the least-recently-dealt
/// index, and the open session's dealt-but-unanswered card.
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

/// The facts one ordered walk of the log yields. Field names are facts,
/// never verbs (AD-6): each states something the log makes true.
final class LogFacts {
  const LogFacts({
    required this.lastDealtInstantByItemId,
    required this.focusSlotClosedDays,
    required this.dealtCountsByDay,
    required this.answeredItemIds,
    required this.openSessionStart,
    required this.dealtUnanswered,
  });

  /// Per item id, the instant of its latest recorded `card_dealt` —
  /// AD-3's least-recently-dealt tie-break reads recorded act instants;
  /// an absent id was never dealt and ranks first.
  final Map<String, int> lastDealtInstantByItemId;

  /// The domestic days whose Focus Chunk slot a focus-size `card_done`
  /// closed — occupancy is once per domestic day, and only a
  /// `card_done` closes it (AD-20).
  final Set<Day> focusSlotClosedDays;

  /// Per domestic day, how many `card_dealt` rows were charged to it by
  /// the dealt item's taxonomy size — the day's draw counts.
  final Map<Day, Map<Size, int>> dealtCountsByDay;

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
  /// `card_skipped` since. An unanswered card never produces a second
  /// deal (AD-3).
  final ({String itemId, Origin itemOrigin})? dealtUnanswered;
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
/// instant's day, so the walk stays total. Unknown kinds and crash
/// entries pass through untouched. The [catalogue] resolves a referenced
/// item's taxonomy size — the shipped catalogue is 1.6's only item
/// source; an id it does not know carries no size yet and closes
/// nothing, and later sources extend exactly here. Its ids must be
/// unique ([parseCatalogue] enforces this on the asset path); a
/// hand-built duplicate fails the walk fast rather than reading a
/// last-wins size (AD-23).
LogFacts walkLog(List<LogEntry> entries, {Catalogue? catalogue}) {
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

  final lastDealtInstantByItemId = <String, int>{};
  final focusSlotClosedDays = <Day>{};
  final dealtCountsByDay = <Day, Map<Size, int>>{};
  final answeredItemIds = <String>{};
  ({int instantUtcMicros, int offsetSeconds})? openSessionStart;
  ({String itemId, Origin itemOrigin})? dealtUnanswered;

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

  for (final entry in entries) {
    switch (entry) {
      case MomentEntry(:final kind):
        if (kind == LogKind.sessionStarted) {
          openSessionStart = (
            instantUtcMicros: entry.instantUtcMicros,
            offsetSeconds: entry.offsetSeconds,
          );
          dealtUnanswered = null;
        } else if (kind == LogKind.sessionEnded) {
          openSessionStart = null;
          dealtUnanswered = null;
        }
      case ItemActEntry(:final kind, :final itemId, :final itemOrigin):
        if (kind == LogKind.cardDealt) {
          lastDealtInstantByItemId[itemId] = entry.instantUtcMicros;
          chargeDealToDay(dayOfOpenOrOwnSession(entry), sizeByItemId[itemId]);
          if (openSessionStart != null) {
            dealtUnanswered = (itemId: itemId, itemOrigin: itemOrigin);
          }
        } else {
          if (kind == LogKind.cardDone) {
            answeredItemIds.add(itemId);
            if (sizeByItemId[itemId] == Size.focus) {
              focusSlotClosedDays.add(dayOfOpenOrOwnSession(entry));
            }
          }
          final unanswered = dealtUnanswered;
          if (unanswered != null && unanswered.itemId == itemId) {
            dealtUnanswered = null;
          }
        }
      case CrashEntry():
      case UnknownEntry():
        break;
    }
  }

  return LogFacts(
    lastDealtInstantByItemId: lastDealtInstantByItemId,
    focusSlotClosedDays: focusSlotClosedDays,
    dealtCountsByDay: dealtCountsByDay,
    answeredItemIds: answeredItemIds,
    openSessionStart: openSessionStart,
    dealtUnanswered: dealtUnanswered,
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

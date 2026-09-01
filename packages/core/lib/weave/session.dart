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
    required this.answeredItemIds,
    required this.openSessionStart,
    required this.dealtUnanswered,
    required this.openSessionPocketMinutes,
    required this.openSessionAnsweredSeconds,
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
  /// `card_skipped` on the same (itemId, itemOrigin) since. An
  /// unanswered card never produces a second deal (AD-3).
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
  /// its estimate (Story 2.2, FR-8, FR-12). Session-scoped, never
  /// day-scoped: a superseding declaration restarts it at zero.
  final int openSessionAnsweredSeconds;
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
/// nothing, and later sources extend exactly here. Its ids must be
/// unique ([parseCatalogue] enforces this on the asset path); a
/// hand-built duplicate fails the walk fast rather than reading a
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
  int? openSessionPocketMinutes;
  var openSessionAnsweredSeconds = 0;

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
            if (openSessionStart != null) {
              final size = sizeByItemId[itemId];
              if (size != null) {
                openSessionAnsweredSeconds += estimateSecondsOf(size);
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
      case CrashEntry():
      case SettingEntry():
      case EnergySetEntry():
      case ReportAnsweredEntry():
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
    openSessionPocketMinutes: openSessionPocketMinutes,
    openSessionAnsweredSeconds: openSessionAnsweredSeconds,
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

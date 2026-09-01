/// The capture's deal-window law (Story 3.3, FR-27, AD-24): the one
/// `EligibleDay(item, day)` predicate — a domestic day on which at
/// least one session started, no earlier than the item's pool-fact
/// creation — plus the three-eligible-day window's width and the
/// consumed-days fold over the walk's charged-deal fact.
///
/// This is `core/derive`'s sibling to the strip, the checkpoint and
/// the warm return, on their precedent (AD-6's stated crossing for
/// derived state): a pure law over the log, never a signal-as-work,
/// reading entry TYPES only — `SessionStartEntry` and
/// `EnergySetEntry` — never kind identifiers or wire-name literals,
/// so the vocabulary's one-minter-one-reader pins hold untouched.
/// Nothing here writes (AD-3) and nothing here is stored (AD-1). The
/// window is derived law, not a gate: candidacy never consults it —
/// precedence persists while a capture is unanswered, and "dealt
/// within three eligible days" holds by construction (precedence +
/// FIFO + the daily draw counts) — and the derivation exists so
/// AD-24's semantics are executable and pinnable now: FR-5's counter
/// and FR-26's instrumentation read it later.
///
/// The predicate, AD-24 verbatim: a day is eligible for an item iff
/// at least one session STARTED on it — by start instant, in each
/// row's own stored offset (AD-4), so a session outliving its day
/// never makes the later day eligible — no earlier than the item's
/// pool-fact creation (a capture born mid-session never makes that
/// session's own day eligible), and at whose start at least one of
/// that day's sessions found the item's size not excluded. Energy at
/// a session's start is the last `energy_set` of that session's own
/// domestic day at or before its start instant, defaulting 🟢; the
/// size exclusion is the weave's low-energy ceiling, the same
/// `lowEnergyMaxEstimateSeconds` the live pool admits by — so an
/// instant capture (30 s ≤ the 60 s ceiling) is never excluded while
/// a 🔴 start excludes the two larger sizes: AD-24's own freeze
/// mechanics. Absence days hold no session start and derive not
/// eligible — the window freezes across them and resumes at the next
/// started day, and nothing anywhere expires, caps or deletes (the
/// schema has no overdue, AD-25).
///
/// Consumption (the fold): a day consumes one unit of the window iff
/// it is an eligible day of the capture AND a `card_dealt` for it is
/// charged to that day — answered or skipped alike, a skip consuming
/// exactly like an answer and never extending anything. The charged
/// days derive from the walk over exactly the rows at or before the
/// read instant (AD-19's session-day rule, the same attribution
/// `dealtCountsByDay` charges by), so this fold owns no second copy
/// of the rule and no post-read row can move a count. And because eligibility requires a
/// session starting no earlier than the fact's creation, a capture
/// created mid-session and dealt before any new session start
/// consumes nothing — rare, literal, pinned by test. Resume falls out
/// of recomputation (nothing stored); rows after the read instant are
/// skipped, the readers' convention (strip.dart, warm_return.dart).

library;

import 'package:core/day/calendar.dart';
import 'package:core/energy/energy.dart';
import 'package:core/log/log_entry.dart';
import 'package:core/pool/pool_fact.dart';
import 'package:core/weave/session.dart';
import 'package:core/weave/weave.dart';

/// The deal window's width (FR-27, AD-24): three eligible days — a
/// named const, the one statement of it that FR-5's counter and
/// FR-26's instrumentation will read. The window never gates
/// candidacy: this number is the law's width, never a threshold the
/// resolver consults.
const int captureDealWindowEligibleDays = 3;

/// Whether [size] survives the energy derived at [start]'s own start
/// (AD-24's retrospective per-session reading of the one low-energy
/// ceiling): the last `energy_set` row of the start's own domestic
/// day at or before the start instant — exact-instant ties resolved
/// to the later-in-input row, the energy seam's own convention —
/// defaulting 🟢. A 🔴 start admits only estimates within
/// [lowEnergyMaxEstimateSeconds]; every other level admits all
/// sizes, and no size is excluded on any other clause.
bool _sizeNotExcludedAtStart(
  List<LogEntry> entries,
  SessionStartEntry start,
  Size size,
  Day day,
  Calendar calendar,
) {
  var level = EnergyLevel.full;
  var levelInstant = -1;
  for (final entry in entries) {
    if (entry is! EnergySetEntry ||
        entry.instantUtcMicros > start.instantUtcMicros) {
      continue;
    }
    if (calendar.dayOf(entry.instantUtcMicros, entry.offsetSeconds) != day) {
      continue;
    }
    if (entry.instantUtcMicros >= levelInstant) {
      level = entry.level;
      levelInstant = entry.instantUtcMicros;
    }
  }
  return level != EnergyLevel.low ||
      estimateSecondsOf(size) <= lowEnergyMaxEstimateSeconds;
}

/// AD-24's one eligibility predicate: whether [day] is an eligible day
/// of [fact]'s item — pure over the log, writing nothing (AD-3).
/// Eligible iff at least one session started on [day] — by start
/// instant, in the row's own stored offset, so a session outliving
/// its day never makes the later day eligible — no earlier than the
/// fact's creation instant, and at least one such start found the
/// fact's size not excluded under the energy derived at its own
/// start (see [_sizeNotExcludedAtStart]). Entries after
/// [instantUtcMicros] are skipped, the readers' convention — the
/// derivation judges the log as of a read, never the future.
bool eligibleDay({
  required List<LogEntry> entries,
  required PoolFact fact,
  required Day day,
  required int instantUtcMicros,
}) {
  const calendar = Calendar();
  for (final entry in entries) {
    if (entry is! SessionStartEntry) {
      continue;
    }
    if (entry.instantUtcMicros > instantUtcMicros ||
        entry.instantUtcMicros < fact.instantUtcMicros) {
      continue;
    }
    if (calendar.dayOf(entry.instantUtcMicros, entry.offsetSeconds) != day) {
      continue;
    }
    if (_sizeNotExcludedAtStart(entries, entry, fact.size, day, calendar)) {
      return true;
    }
  }
  return false;
}

/// How many units of [fact]'s deal window the log has consumed
/// (Story 3.3, FR-27, AD-24): one per day that is an eligible day of
/// the capture AND holds a `card_dealt` for it charged to that day —
/// answered or skipped alike, a skip consuming exactly like an answer
/// and never extending anything. The charged days derive from the
/// walk over exactly the rows at or before [instantUtcMicros] — the
/// readers' convention (strip.dart, warm_return.dart), held by the
/// fold itself rather than trusting a caller's unbounded walk: a deal
/// dated after the read, even one charged to a session that started
/// before it, contributes nothing at the earlier read. No second
/// attribution rule exists here (AD-19's session-day rule, the same
/// one `dealtCountsByDay` charges by). 🔴-excluded and absent days
/// are simply not eligible — the count freezes across them and
/// resumes at the next eligible dealt day, with no expiry, no cap and
/// no clamp: the count states what the log made true, never what a
/// capture owes, and the same-day set semantics make any number of
/// same-day re-deals one consumed day.
int captureDealWindowConsumedDays({
  required List<LogEntry> entries,
  required PoolFact fact,
  required int instantUtcMicros,
}) {
  final bounded = [
    for (final entry in entries)
      if (entry.instantUtcMicros <= instantUtcMicros) entry,
  ];
  final chargedDays =
      walkLog(bounded).dealtDaysByItemId[fact.id] ?? const <Day>{};
  var consumed = 0;
  for (final day in chargedDays) {
    if (eligibleDay(
      entries: bounded,
      fact: fact,
      day: day,
      instantUtcMicros: instantUtcMicros,
    )) {
      consumed++;
    }
  }
  return consumed;
}

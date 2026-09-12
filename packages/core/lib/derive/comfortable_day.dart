/// The comfortable-day run (Story 7.5, FR-23, AD-26): one pure
/// derivation over the log — how many consecutive comfortable days
/// end the day before the read instant, the number that decides the
/// snowball's one crossing day. The run is **internal**: nothing this
/// file returns crosses to the shell except through the strip's
/// eligibility, and the fact the surface carries is the proposed bag
/// minutes, never this length (§1.1 P2 — no count, day-total, chain
/// length or run name may appear in any copy, surface or fact).
///
/// A comfortable day = ≥ 1 session belonging to that domestic day +
/// ≥ 1 `card_done` charged to that day + no marathon session that
/// day. The attribution is the walk's own (`weave/session.dart`'s
/// `_chargedDayOf` discipline, mirrored here beside it — strip must
/// not import weave for the cycle, so the fold pairs sessions the
/// same way in its own pass): a session belongs to the day of its
/// own start instant (AD-19), a `card_done` inside it is charged to
/// that same start day, and day identity comes from the one
/// `Calendar` (AD-4), each row scoped in its own stored offset.
///
/// The marathon judgment reads each session's ORIGINAL pocket — the
/// start row's own `pocketMinutes` (`log_entry.dart` keeps the
/// original; FR-23's input) — plus that session's own
/// `session_extended` rows, the walk's own lifting rule (an extension
/// the user chose is never a marathon, AD-19; an unbounded sitting
/// stays unbounded). The judgment is span — `session_ended.instant −
/// session_started.instant`, the still-open session judged to the
/// read instant, a superseded session to its supersession instant —
/// STRICTLY beyond that sum, with no grace: durations are FR-26
/// series (a) facts and the audit stays literal against them, so a
/// false marathon may only cost a later suggestion, never add a
/// nagging one. A start row with no pocket (or one outside the
/// declarable range — tolerated import) can fire no marathon
/// (AD-23).
///
/// The run counts consecutive comfortable days ending the day before
/// the read instant — today never counts until it is over, any
/// non-comfortable day (absence included) breaks the chain, and days
/// before the log's earliest row end the walk. One length leaves the
/// file: no per-day detail exists to cross anywhere.
///
/// The fold is ORDER-SENSITIVE: open-session tracking, supersede and
/// extension attribution all read the rows in the order given. The
/// input is the store's instant-ordered log read — the walk's own
/// precondition (`walkLog` reads the same list the same way); an
/// unsorted list derives nothing meaningful.
///
/// Rows after the read instant are skipped (the readers' convention,
/// strip.dart); every value is derived from log facts, nothing
/// stored (AD-1).

library;

import 'package:core/day/calendar.dart';
import 'package:core/log/log_entry.dart';
import 'package:core/settings/settings.dart';

/// How many consecutive comfortable days end the day before the read
/// instant (Story 7.5, FR-23): zero when yesterday was not
/// comfortable, one when yesterday stood alone, and so on back until
/// a non-comfortable day or the day before the log's earliest row
/// stops the walk. Pure over [entries] at [instantUtcMicros], each row
/// scoped in its own stored offset (AD-4), rows after the read
/// instant skipped.
int comfortableDayRunLength({
  required List<LogEntry> entries,
  required int instantUtcMicros,
  required int offsetSeconds,
}) {
  const calendar = Calendar();
  final sessionsByDay = <Day>{};
  final cardDoneDays = <Day>{};
  final marathonDays = <Day>{};
  ({int instantUtcMicros, int offsetSeconds})? openSessionStart;
  int? openPocketMinutes;
  Day? earliestRowDay;

  void judgeOpenSession(int endInstantUtcMicros) {
    final open = openSessionStart;
    if (open == null) {
      return;
    }
    final threshold = openPocketMinutes;
    if (threshold != null &&
        endInstantUtcMicros - open.instantUtcMicros >
            threshold * microsPerMinute) {
      marathonDays.add(
        calendar.dayOf(open.instantUtcMicros, open.offsetSeconds),
      );
    }
  }

  for (final entry in entries) {
    if (entry.instantUtcMicros > instantUtcMicros) {
      continue;
    }
    final ownDay = calendar.dayOf(entry.instantUtcMicros, entry.offsetSeconds);
    // The walk's floor: the earliest day any visible row can vouch
    // for (labels sort chronologically, calendar.dart) — on the
    // store's instant-ordered read this IS the first row's own day;
    // under mixed offsets the earliest label any row carries is the
    // honest floor either way.
    if (earliestRowDay == null ||
        ownDay.label.compareTo(earliestRowDay.label) < 0) {
      earliestRowDay = ownDay;
    }
    switch (entry) {
      case SessionStartEntry():
        // The supersede discipline, mirrored from the walk: a start
        // while a session stands replaces it — the replaced sitting
        // never gains a `session_ended` of its own, so its span is
        // judged to the supersession instant, the same rule that
        // judges the still-open session to the read instant.
        judgeOpenSession(entry.instantUtcMicros);
        openSessionStart = (
          instantUtcMicros: entry.instantUtcMicros,
          offsetSeconds: entry.offsetSeconds,
        );
        final declared = entry.pocketMinutes;
        openPocketMinutes =
            (declared != null &&
                declared >= pocketLeastMinutes &&
                declared <= pocketMostMinutes)
            ? declared
            : null;
        sessionsByDay.add(
          calendar.dayOf(entry.instantUtcMicros, entry.offsetSeconds),
        );
      case MomentEntry(:final kind) when kind == LogKind.sessionEnded:
        judgeOpenSession(entry.instantUtcMicros);
        openSessionStart = null;
        openPocketMinutes = null;
      case SessionExtendEntry(:final pocketMinutes):
        // The walk's own lifting rule: a positive count sums into the
        // sitting's declared pocket only while one is open AND a
        // start declared one — an extension cannot retroactively
        // bound what no start declared, and a non-positive value sums
        // nothing (AD-23's tolerance).
        if (openSessionStart != null && openPocketMinutes != null) {
          if (pocketMinutes > 0) {
            openPocketMinutes += pocketMinutes;
          }
        }
      case ItemActEntry(:final kind) when kind == LogKind.cardDone:
        // `_chargedDayOf` mirrored: the open session's own start day
        // while one is open, else the act's own day (the walk stays
        // total; no command writes the latter).
        final open = openSessionStart;
        cardDoneDays.add(
          open != null
              ? calendar.dayOf(open.instantUtcMicros, open.offsetSeconds)
              : calendar.dayOf(entry.instantUtcMicros, entry.offsetSeconds),
        );
      case MomentEntry():
      case ItemActEntry():
      case CrashEntry():
      case SettingEntry():
      case EnergySetEntry():
      case ReportAnsweredEntry():
      case PermissionRefusedEntry():
      case ClusterCurationChangedEntry():
      case TriageEntry():
      case BeforeSavedEntry():
      case AlbumEntryAddedEntry():
      case AlbumEntryDeletedEntry():
      case AlbumPurgedEntry():
      case BoxCreatedEntry():
      case UnknownEntry():
      case SliceEntry():
        break;
    }
  }
  // The still-open session: judged to the read instant — its day is
  // its start day, and today never counts until it is over anyway.
  judgeOpenSession(instantUtcMicros);

  bool comfortable(Day day) =>
      sessionsByDay.contains(day) &&
      cardDoneDays.contains(day) &&
      !marathonDays.contains(day);

  // The walk back: yesterday first — today never counts — one label
  // per day (the calendar's day-before idiom: one microsecond before
  // a day's start belongs to the previous day), and the day before
  // the log's earliest row ends the walk whatever the log holds.
  final today = calendar.dayOf(instantUtcMicros, offsetSeconds);
  var cursor = calendar.dayOf(today.startUtcMicros - 1, offsetSeconds);
  var run = 0;
  while (comfortable(cursor) &&
      earliestRowDay != null &&
      cursor.label.compareTo(earliestRowDay.label) >= 0) {
    run++;
    cursor = calendar.dayOf(cursor.startUtcMicros - 1, offsetSeconds);
  }
  return run;
}

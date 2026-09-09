/// The ambient strip's derivation (Story 2.5, FR-4, UX-DR22): which
/// resident — if any — the strip below the card holds at one read
/// instant, decided by one total precedence order over the residents
/// the log makes eligible.
///
/// This is `core/derive`'s second resident, on the checkpoint's
/// precedent (AD-6's stated crossing for derived state): a fact the
/// shell renders as a non-work surface, never a signal-as-work, and a
/// read that writes nothing (AD-3). It is deliberately NOT an
/// `EligibleDay(item, day)` window predicate — AD-24's monopoly is
/// untouched, because nothing here windows or freezes anything; the
/// strip resolves fresh at every read and defines no item-level
/// candidacy.
///
/// Precedence is one total order, rarest eligible frequency first
/// (UX-DR22): the once-ever first-run curation offer, the once-per-box
/// quarantine follow-up, the once-per-season suggestion, the snowball,
/// the weekly self-report, then the daily check-in — ties broken by
/// earliest-eligible instant, then stable id (AD-3's discipline). This
/// build implements three residents' eligibilities (the offer, the
/// report and the check-in, below); the later stories add the others
/// as data under the same order. A displaced resident is neither
/// consumed nor dismissed — it re-offers at the next opening, because
/// only the surface's ✕ is a dismissal, and a dismissal writes nothing
/// (AD-21's vocabulary has no dismissal kind; within the opening,
/// shell state hides it).
///
/// The check-in's eligibility is pure over the log: due iff the
/// current domestic day holds no `energy_set` row AND the day's first
/// opening is underway. Answered or dismissed, the check-in is gone
/// for the day — an answer because the row exists, a dismissal because
/// a later same-day opening fails the first-opening predicate below.
///
/// The report's eligibility is the same shape one slot rarer (SM-2,
/// Story 2.6, FR-4): due iff the due week holds no accepted
/// `report_answered` row AND the day's first opening is underway —
/// re-offered at each day's first opening until answered. The due week
/// is `weekOf(today).weekOrdinal` minus 0 on Sunday (weekday 7, the
/// running week the Sunday closes) and 1 on Mon–Sat (the latest week
/// whose Sunday has arrived), so persistence on any later day, the
/// check-in's delay within an opening, and supersession at the next
/// Sunday are all emergent from that one comparison — no pending
/// state exists to store, which is the only AD-21-legal shape. An
/// answer matches by its carried `week` field alone, never its own
/// instant re-derived (persistence lets the two diverge — the field's
/// whole reason), rows after the read instant excluded, quiet on
/// foreign weeks; an unanswered week simply has no data point.

library;

import 'package:core/day/calendar.dart';
import 'package:core/log/log_entry.dart';
import 'package:core/pool/pool_fact.dart';

/// One resident of the ambient strip (UX-DR22). A value vocabulary:
/// members carry no fields — each resident's eligibility is its own
/// derivation over the log, added by its own story.
enum StripResident {
  /// The once-ever first-run curation offer (FR-31, Story 5.12):
  /// eligible only while the first opening ever is underway — the
  /// derivation below, never a stored dismissal (AD-21).
  firstRunCuration,

  /// The once-per-box quarantine follow-up (Epic 7's data).
  quarantineFollowUp,

  /// The once-per-season suggestion (FR-15, Story 5.13): eligible
  /// at the day's first opening while a dormant Epic stands whose
  /// suggestion holds no live same-season `suggestion_dismissed`
  /// row — the derivation below, never a stored dismissal (AD-21).
  seasonalSuggestion,

  /// The snowball suggestion (Epic 7's data).
  snowball,

  /// The weekly self-report while it stands unanswered (SM-2, 2.6).
  weeklySelfReport,

  /// The daily energy check-in (FR-4, this story).
  energyCheckIn,
}

/// The one total precedence order (UX-DR22, AD-3): rarest eligible
/// frequency first, the check-in last. `deriveStrip` walks this list
/// in order and takes the first eligible resident — the order is
/// load-bearing, not documentation — and ties by earliest-eligible
/// instant then stable id apply only between residents eligible at
/// the same opening; this build's three implemented residents (the
/// first-run offer, report and check-in) never need them, the order
/// alone deciding the overlaps they can produce. The order is the
/// contract the later stories plug their eligibility into.
const List<StripResident> stripResidentPrecedence = [
  StripResident.firstRunCuration,
  StripResident.quarantineFollowUp,
  StripResident.seasonalSuggestion,
  StripResident.snowball,
  StripResident.weeklySelfReport,
  StripResident.energyCheckIn,
];

/// The strip's state at one read instant: the resident the precedence
/// order resolves to, or absent when none is eligible. Fields are
/// facts, never verbs (AD-6).
final class StripState {
  const StripState({
    required this.resident,
    this.reportWeekOrdinal,
    this.suggestion,
  });

  /// The winning resident — at most one is ever visible (UX-DR22).
  final StripResident resident;

  /// The due week the report asks about, as a `Week.weekOrdinal` —
  /// non-null exactly when [resident] is
  /// [StripResident.weeklySelfReport], null for every other resident.
  /// The fact the answer's minter needs (part 1's `week` payload is
  /// minted from it), never a stored pending marker: the derivation
  /// recomputes it at every read, and no dismissal flag or answered
  /// marker rides beside it (AD-21 — an unanswered week is absent
  /// rows, nothing more).
  final int? reportWeekOrdinal;

  /// The suggestion the strip shows, when it shows one — non-null
  /// exactly when [resident] is [StripResident.seasonalSuggestion]
  /// (Story 5.13, FR-15), null for every other resident. The shown
  /// record is the fact BOTH one-tap paths need — the ✕ dismisses
  /// this project, the tap activates it — carried from the read,
  /// never re-derived at tap time (the `reportWeekOrdinal` grammar:
  /// a boundary crossed since the view committed would otherwise act
  /// on a different project entirely). A structural record, shared
  /// with `core/weave`'s `dormantEpicProjects` by shape alone — strip
  /// must not import weave (the cycle), so no named type crosses.
  final StripSuggestion? suggestion;
}

/// One dormant Epic Project the strip may suggest (Story 5.13,
/// FR-15): the derived stable id (`epic_activated`'s own identity —
/// the group's first fact's id), the Epic's own origin, and the
/// description the sentence names (the slice's Origin Context).
typedef StripSuggestion = ({
  String stableId,
  Origin origin,
  String description,
});

/// One resident's eligibility at the read instant. This build
/// implements four — the offer, the suggestion, the report and the
/// check-in, below; every other resident derives not-eligible until
/// its own story lands its data, so the precedence walk falls through
/// them to the implemented set (or to nothing). A new resident's
/// eligibility arrives HERE, in the same pass as its data — never as
/// a special case inside the walk. Since Story 5.13 four
/// eligibilities stand: the once-ever first-run curation offer, the
/// once-per-season suggestion, the weekly self-report and the daily
/// check-in.
bool _residentEligible(
  StripResident resident,
  List<LogEntry> entries,
  Calendar calendar,
  Day today, {
  required bool answeredToday,
  required bool answeredDueWeek,
  required StripSuggestion? seasonalShown,
  required int instantUtcMicros,
}) {
  switch (resident) {
    case StripResident.energyCheckIn:
      return !answeredToday &&
          _firstOpeningUnderway(
            entries,
            calendar,
            today,
            instantUtcMicros: instantUtcMicros,
          );
    case StripResident.firstRunCuration:
      // FR-31's once-ever offer (Story 5.12): eligible exactly while
      // the FIRST opening ever is underway — the day's first-opening
      // gate composed with the historical clause that no `app_opened`
      // row from any earlier day stands in the log. The once-ever
      // fact is this derivation, never a stored dismissal (AD-21): a
      // tap and a ✕ alike write nothing, and "never returns" holds
      // by construction — a second `app_opened` today ends the day's
      // first opening, a day turn makes the earliest open historical,
      // and the offer is gone on each alike, dismissed, tapped,
      // ignored or never seen all the same.
      return _firstOpeningUnderway(
            entries,
            calendar,
            today,
            instantUtcMicros: instantUtcMicros,
          ) &&
          !_appOpenedBefore(
            entries,
            calendar,
            today,
            instantUtcMicros: instantUtcMicros,
          );
    case StripResident.quarantineFollowUp:
      // Epic 7's once-per-box follow-up — its story's data.
      return false;
    case StripResident.seasonalSuggestion:
      // FR-15's once-per-season suggestion (Story 5.13): eligible at
      // the day's first opening while a dormant Epic stands whose
      // suggestion holds no live same-season dismissal — the pick the
      // caller's `dormantEpics` fold (weave's `dormantEpicProjects`, the
      // one dormancy derivation) handed in, ordered deterministically,
      // so this branch only folds the dismissal rows over the pick.
      // Per-project is the declared rate limit: dismissing project A
      // may surface project B in the same opening, and a displaced
      // resident is neither consumed nor dismissed.
      return seasonalShown != null &&
          _firstOpeningUnderway(
            entries,
            calendar,
            today,
            instantUtcMicros: instantUtcMicros,
          );
    case StripResident.snowball:
      // Epic 7's comfortable-day suggestion — its story's data.
      return false;
    case StripResident.weeklySelfReport:
      // SM-2's persistent weekly report (Story 2.6): due while the due
      // week stands unanswered, at the day's first opening — the same
      // gate the check-in rides, one slot above it in the order, so a
      // pending report delays the check-in within the opening and its
      // answer hands the slot back in that same opening (FR-4).
      return !answeredDueWeek &&
          _firstOpeningUnderway(
            entries,
            calendar,
            today,
            instantUtcMicros: instantUtcMicros,
          );
  }
}

/// Whether the day's first opening is underway at the read instant
/// (FR-4's "first opening", in log terms — the reading 2.5 records as
/// code-doc): `app_opened` rows are the only opening delimiters, and
/// three clauses decide, each catching a case the others cannot.
///
/// 1. **No `app_opened` row in today** — the crossing case: a sitting
///    open across 04:00 makes this read the crossed-into day's first
///    opening, shown once if unresolved.
/// 2. **Exactly one `app_opened`, and it is the day's earliest row** —
///    a true first open. A return-after-crossing betrays the consumed
///    opening through earlier rows of today (a departure's
///    `session_ended`, crossing card acts), so it fails here.
/// 3. **No unended prior-day `session_started`** — the kill-during-
///    crossing marker: a process death inside a crossing opening can
///    leave today holding nothing but a fresh `app_opened`, and only
///    the dangling start betrays that the opening was already
///    underway.
///
/// A day that still loses its check-in to an unresolvable edge owes
/// nothing — the 🟢 default carries it (FR-4's own clause).
bool _firstOpeningUnderway(
  List<LogEntry> entries,
  Calendar calendar,
  Day today, {
  required int instantUtcMicros,
}) {
  var appOpensToday = 0;
  LogEntry? earliestToday;
  var sessionOpen = false;
  Day? openSessionDay;
  for (final entry in entries) {
    if (entry.instantUtcMicros > instantUtcMicros) {
      continue;
    }
    final ownDay = calendar.dayOf(entry.instantUtcMicros, entry.offsetSeconds);
    if (ownDay == today) {
      earliestToday ??= entry;
      if (entry is MomentEntry && entry.kind == LogKind.appOpened) {
        appOpensToday++;
      }
    }
    switch (entry) {
      case SessionStartEntry():
        sessionOpen = true;
        openSessionDay = ownDay;
      case MomentEntry(:final kind) when kind == LogKind.sessionEnded:
        sessionOpen = false;
        openSessionDay = null;
      case MomentEntry():
      case SessionExtendEntry():
      case ItemActEntry():
      case CrashEntry():
      case SettingEntry():
      case EnergySetEntry():
      case ReportAnsweredEntry():
      case PermissionRefusedEntry():
      case ClusterCurationChangedEntry():
      case UnknownEntry():
      case SliceEntry():
        break;
    }
  }
  // The kill-during-crossing marker: a session started on an earlier
  // day that no `session_ended` ever closed.
  final priorDaySessionOpen = sessionOpen && openSessionDay != today;
  if (appOpensToday == 0) {
    // Clause 1 — the crossing case.
    return true;
  }
  if (appOpensToday == 1) {
    final first = earliestToday;
    final appOpenIsFirstRowOfToday =
        first != null &&
        first is MomentEntry &&
        first.kind == LogKind.appOpened;
    // Clauses 2 and 3 together.
    return appOpenIsFirstRowOfToday && !priorDaySessionOpen;
  }
  return false;
}

/// Whether an `app_opened` row from a domestic day before [today]
/// stands in the log at the read instant (Story 5.12) — the
/// once-ever offer's historical clause. Each row is scoped in its
/// own stored offset (AD-4) and rows after the read instant are
/// excluded, exactly the derivation's own convention: an install
/// whose log names an opening on any earlier day is not on its
/// first opening ever, so the offer is already gone — whatever
/// became of it.
bool _appOpenedBefore(
  List<LogEntry> entries,
  Calendar calendar,
  Day today, {
  required int instantUtcMicros,
}) {
  for (final entry in entries) {
    if (entry.instantUtcMicros > instantUtcMicros) {
      continue;
    }
    if (entry is MomentEntry && entry.kind == LogKind.appOpened) {
      final ownDay = calendar.dayOf(
        entry.instantUtcMicros,
        entry.offsetSeconds,
      );
      // Day identity is the civil-date label, not the frame-dependent
      // UTC instant at which that day begins. At the UTC date line an
      // earlier label can have a later start instant than today's label
      // when the rows use opposite legal offsets.
      if (ownDay.label.compareTo(today.label) < 0) {
        return true;
      }
    }
  }
  return false;
}

/// The seasonal suggestion the strip may show at this read (Story
/// 5.13, FR-15): the first dormant Epic of the caller's ordered
/// [dormantEpics] whose stable id holds no live
/// `suggestion_dismissed` row in the CURRENT meteorological season —
/// the season of the one `Calendar`, computed over each row's own
/// stored offset (AD-4), rows after the read instant excluded,
/// exactly `_appOpenedBefore`'s discipline. Once per season per
/// project: a dismissal from a prior season suppresses nothing (the
/// season turned, the suppression died with it), a dismissal naming
/// another project suppresses nothing (per-project is the rate
/// limit), and an empty dormant list derives nothing — quietly, the
/// no-dormant matrix row. No second season computation exists
/// anywhere: this fold reads `Calendar.seasonOf` alone.
StripSuggestion? _seasonalShown(
  List<StripSuggestion> dormantEpics,
  List<LogEntry> entries,
  Calendar calendar,
  Day today,
  int instantUtcMicros,
) {
  final season = calendar.seasonOf(today);
  final dismissedThisSeason = <String>{
    for (final entry in entries)
      if (entry.instantUtcMicros <= instantUtcMicros &&
          entry is ItemActEntry &&
          entry.kind == LogKind.suggestionDismissed &&
          calendar.seasonOf(
                calendar.dayOf(entry.instantUtcMicros, entry.offsetSeconds),
              ) ==
              season)
        entry.itemId,
  };
  for (final epic in dormantEpics) {
    if (!dismissedThisSeason.contains(epic.stableId)) {
      return epic;
    }
  }
  return null;
}

/// Derives the strip's resident at one read instant (Story 2.5,
/// FR-4): pure over the log, writing nothing (AD-3). The resolution
/// walks [stripResidentPrecedence] in order and takes the first
/// resident whose eligibility holds — the load-bearing total order
/// UX-DR22 names. This build implements four eligibilities: the
/// once-ever first-run curation offer (due iff the first opening
/// ever is underway — the day's first opening AND no `app_opened`
/// row from any earlier day, Story 5.12, FR-31), the once-per-season
/// suggestion (due iff the day's first opening is underway and the
/// dormant fold handed in an Epic no live same-season
/// `suggestion_dismissed` row names, Story 5.13, FR-15), the weekly
/// self-report (due iff the due week — `weekOf(today).weekOrdinal`
/// minus 0 on Sunday, 1 on Mon–Sat, the latest week whose Sunday has
/// arrived — holds no accepted `report_answered` row whose carried
/// week matches, rows after the read instant excluded, and the day's
/// first opening is underway, SM-2), and the daily check-in (due iff
/// the current domestic day — each row scoped in its own stored
/// offset, AD-4 — holds no `energy_set` row and the day's first
/// opening is underway), so the walk falls through the two
/// not-yet-eligible residents to them, or to nothing. A corrupt
/// `energy_set` or `report_answered` row never reaches this
/// derivation — the read boundary excluded it, and the day (or week)
/// derives as unanswered.
///
/// [excludeResidents] is the read-scoped seam: residents this reader
/// cannot render, skipped by the walk before eligibility is even
/// asked. It writes nothing and stores nothing — the same log without
/// it resolves the same resident — which is exactly what part 3's
/// opening-scoped report dismissal needs to hand the slot to the
/// check-in in the same opening.
StripState? deriveStrip({
  required List<LogEntry> entries,
  required int instantUtcMicros,
  required int offsetSeconds,
  List<StripSuggestion> dormantEpics = const [],
  Set<StripResident> excludeResidents = const {},
}) {
  const calendar = Calendar();
  final today = calendar.dayOf(instantUtcMicros, offsetSeconds);
  var answeredToday = false;
  for (final entry in entries) {
    if (entry is EnergySetEntry &&
        entry.instantUtcMicros <= instantUtcMicros &&
        calendar.dayOf(entry.instantUtcMicros, entry.offsetSeconds) == today) {
      answeredToday = true;
      break;
    }
  }
  // The due week (SM-2, AD-4): the running week on Sunday — the week
  // that Sunday closes — and the one before on Mon–Sat, i.e. the
  // latest week whose Sunday has arrived. Persistence past Sunday,
  // supersession at the next Sunday and at-most-one-pending are all
  // emergent from this one number meeting the answer fold below; no
  // pending state is stored anywhere (AD-21).
  final dueWeek =
      calendar.weekOf(today).weekOrdinal - (today.weekday == 7 ? 0 : 1);
  var answeredDueWeek = false;
  for (final entry in entries) {
    // The carried `week` field is the whole match — never the answer's
    // own instant re-derived (energy.dart's seam rules: rows after the
    // read instant excluded; a foreign-week or future-dated row counts
    // for nothing, quietly).
    if (entry is ReportAnsweredEntry &&
        entry.instantUtcMicros <= instantUtcMicros &&
        entry.week == dueWeek) {
      answeredDueWeek = true;
      break;
    }
  }
  // The seasonal pick (Story 5.13, FR-15): the first dormant Epic with
  // no live same-season dismissal — null when none stands, which is
  // the eligibility's own no-dormant arm. Computed once beside the
  // report's due week, so the walk below reads it as the fact its
  // branch and its StripState both need.
  final seasonalShown = _seasonalShown(
    dormantEpics,
    entries,
    calendar,
    today,
    instantUtcMicros,
  );
  for (final resident in stripResidentPrecedence) {
    if (excludeResidents.contains(resident)) {
      continue;
    }
    if (_residentEligible(
      resident,
      entries,
      calendar,
      today,
      answeredToday: answeredToday,
      answeredDueWeek: answeredDueWeek,
      seasonalShown: seasonalShown,
      instantUtcMicros: instantUtcMicros,
    )) {
      return resident == StripResident.weeklySelfReport
          ? StripState(resident: resident, reportWeekOrdinal: dueWeek)
          : resident == StripResident.seasonalSuggestion
          ? StripState(resident: resident, suggestion: seasonalShown)
          : StripState(resident: resident);
    }
  }
  return null;
}

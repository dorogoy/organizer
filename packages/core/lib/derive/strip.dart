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
/// build implements exactly one resident's eligibility (the check-in,
/// below); the later stories add the others as data under the same
/// order. A displaced resident is neither consumed nor dismissed — it
/// re-offers at the next opening, because only the surface's ✕ is a
/// dismissal, and a dismissal writes nothing (AD-21's vocabulary has
/// no dismissal kind; within the opening, shell state hides it).
///
/// The check-in's eligibility is pure over the log: due iff the
/// current domestic day holds no `energy_set` row AND the day's first
/// opening is underway. Answered or dismissed, the check-in is gone
/// for the day — an answer because the row exists, a dismissal because
/// a later same-day opening fails the first-opening predicate below.

library;

import 'package:core/day/calendar.dart';
import 'package:core/log/log_entry.dart';

/// One resident of the ambient strip (UX-DR22). A value vocabulary:
/// members carry no fields — each resident's eligibility is its own
/// derivation over the log, added by its own story.
enum StripResident {
  /// The once-ever first-run curation offer (FR-31, Epic 8's data).
  firstRunCuration,

  /// The once-per-box quarantine follow-up (Epic 7's data).
  quarantineFollowUp,

  /// The once-per-season suggestion (FR-15, Epic 6's data).
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
/// the same opening, which one implemented resident cannot yet
/// produce. The order is the contract the later stories plug their
/// eligibility into.
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
  const StripState({required this.resident});

  /// The winning resident — at most one is ever visible (UX-DR22).
  final StripResident resident;
}

/// One resident's eligibility at the read instant. This build
/// implements exactly one — the check-in, below; every other resident
/// derives not-eligible until its own story lands its data, so the
/// precedence walk falls through them to the check-in (or to nothing).
/// A new resident's eligibility arrives HERE, in the same pass as its
/// data — never as a special case inside the walk.
bool _residentEligible(
  StripResident resident,
  List<LogEntry> entries,
  Calendar calendar,
  Day today, {
  required bool answeredToday,
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
      // FR-31's once-ever offer — Epic 8's data.
      return false;
    case StripResident.quarantineFollowUp:
      // Epic 7's once-per-box follow-up — its story's data.
      return false;
    case StripResident.seasonalSuggestion:
      // FR-15's once-per-season suggestion — Epic 6's data.
      return false;
    case StripResident.snowball:
      // Epic 7's comfortable-day suggestion — its story's data.
      return false;
    case StripResident.weeklySelfReport:
      // SM-2's persistent weekly report — Story 2.6's data; while it
      // stands unanswered it outranks the check-in right here, one
      // slot above it in the order.
      return false;
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
      case UnknownEntry():
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

/// Derives the strip's resident at one read instant (Story 2.5,
/// FR-4): pure over the log, writing nothing (AD-3). The resolution
/// walks [stripResidentPrecedence] in order and takes the first
/// resident whose eligibility holds — the load-bearing total order
/// UX-DR22 names. This build implements one eligibility (the
/// check-in: due iff the current domestic day — each row scoped in its
/// own stored offset, AD-4 — holds no `energy_set` row and the day's
/// first opening is underway), so the walk falls through the five
/// not-yet-eligible residents to it, or to nothing. A corrupt
/// `energy_set` row never reaches this derivation — the read boundary
/// excluded it, and the day derives as unanswered.
StripState? deriveStrip({
  required List<LogEntry> entries,
  required int instantUtcMicros,
  required int offsetSeconds,
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
  for (final resident in stripResidentPrecedence) {
    if (_residentEligible(
      resident,
      entries,
      calendar,
      today,
      answeredToday: answeredToday,
      instantUtcMicros: instantUtcMicros,
    )) {
      return StripState(resident: resident);
    }
  }
  return null;
}

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
/// build implements all six eligibilities (the first-run curation
/// offer, the quarantine follow-up, the seasonal suggestion, the
/// snowball of Story 7.5, the report and the check-in, below). A
/// displaced resident is neither consumed nor dismissed — it re-offers
/// at the next opening: only the surface's ✕ is a dismissal, and its
/// scope belongs to the resident — the seasonal suggestion's ✕ alone
/// persists a `suggestion_dismissed` row, while the other residents'
/// dismissal scopes stay shell/read-scoped (within the opening, shell
/// state hides it; nothing is written).
///
/// The quarantine follow-up's eligibility (Story 6.6, FR-21) is a pure
/// day-window fold, the one resident with NO first-opening gate: due
/// iff `Calendar.plusMonths` of some NON-EMPTY derived Quarantine
/// Box's own day equals today — the knock's lifetime is the due day
/// itself, an unopened day misses it silently ("at most once" allows
/// zero), and no later day can make it eligible again for that box.
/// Its ✕ writes nothing (FR-21's dismissal has no side effects); the
/// shell hides it for the day and the derivation closes the window on
/// its own tomorrow.
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
import 'package:core/derive/comfortable_day.dart';
import 'package:core/derive/quarantine.dart';
import 'package:core/log/log_entry.dart';
import 'package:core/pool/pool_fact.dart';
import 'package:core/settings/settings.dart';

/// One resident of the ambient strip (UX-DR22). A value vocabulary:
/// members carry no fields — each resident's eligibility is its own
/// derivation over the log, added by its own story.
enum StripResident {
  /// The once-ever first-run curation offer (FR-31, Story 5.12):
  /// eligible only while the first opening ever is underway — the
  /// derivation below, never a stored dismissal (AD-21).
  firstRunCuration,

  /// The once-per-box quarantine follow-up (6.6, FR-21): eligible
  /// exactly on the due day of some non-empty derived box —
  /// `plusMonths(box day, 6) == today` — and never on any other day,
  /// so the knock's whole lifetime is the due day itself: nothing is
  /// stored, no dismissal row exists (AD-21), and "never returns for
  /// that box" holds by derivation alone.
  quarantineFollowUp,

  /// The once-per-season suggestion (FR-15, Story 5.13): eligible
  /// at the day's first opening while a dormant Epic stands whose
  /// suggestion holds no live same-season `suggestion_dismissed`
  /// row — that live row is the resident's persisted per-project
  /// rate limit, written by its own ✕.
  seasonalSuggestion,

  /// The snowball suggestion (Epic 7, Story 7.5, FR-23): eligible
  /// exactly on the crossing day — the one day the comfortable-day
  /// run first reaches ten consecutive comfortable days ending
  /// yesterday — while the Time Bag sits below its top and no
  /// `time_bag` row stands today, so the earned offer of a raised
  /// bag appears at most once per run and never again until a fresh
  /// ten after a break (AD-1, AD-21: nothing stored, the chain is
  /// 10 on exactly one day, and the accept's own setting row closes
  /// the window by derivation alone — the 6-6 knock's own pattern).
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
/// the same opening; this build's implemented residents (the
/// first-run offer, follow-up, suggestion, snowball, report and
/// check-in) never need
/// them, the order alone deciding the overlaps they can produce.
/// The order is the contract a later resident plugs its
/// eligibility into.
const List<StripResident> stripResidentPrecedence = [
  StripResident.firstRunCuration,
  StripResident.quarantineFollowUp,
  StripResident.seasonalSuggestion,
  StripResident.snowball,
  StripResident.weeklySelfReport,
  StripResident.energyCheckIn,
];

/// The comfortable-day run length whose crossing day earns the
/// snowball's offer (Story 7.5, FR-23): ten consecutive comfortable
/// days. Authored, never a setting — one number, read by the strip's
/// eligibility alone (the crossing is `== this`, never `>=`).
const int snowballRunLength = 10;

/// The minutes the snowball's offer raises the Time Bag by (Story
/// 7.5, FR-23): five — the bag's own step (`timeBagOptions`'s
/// cadence), authored beside the derivation that composes it. The
/// eligibility guarantee keeps `bag + this ≤ timeBagMostMinutes`
/// structurally: the offer never stands while the bag reads 30.
const int snowballRaiseMinutes = 5;

/// The strip's state at one read instant: the resident the precedence
/// order resolves to, or absent when none is eligible. Fields are
/// facts, never verbs (AD-6).
final class StripState {
  const StripState({
    required this.resident,
    this.reportWeekOrdinal,
    this.suggestion,
    this.snowballProposedMinutes,
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

  /// The raised Time Bag the snowball's sentence offers, in minutes
  /// (Story 7.5, FR-23) — non-null exactly when [resident] is
  /// [StripResident.snowball], null for every other resident (the
  /// [suggestion] field's own grammar). The shown fact BOTH one-tap
  /// paths need — the tap mints the bag the user was SHOWN through
  /// the existing `setting_changed` minter, never one re-derived at
  /// tap time (the `reportWeekOrdinal` grammar) — and the only fact
  /// the resident carries: no count, chain length or run name
  /// crosses to the shell (§1.1 P2, AD-26 — the offer's grounding is
  /// the moment, never a number).
  final int? snowballProposedMinutes;
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

/// One resident's eligibility at the read instant. Since Story 7.5
/// this build implements all six — the offer, the follow-up, the
/// suggestion, the snowball, the report and the check-in, below. A
/// new resident's eligibility arrives HERE, in the same pass as its
/// data — never as a special case inside the walk. Since Story 6.6
/// five eligibilities stood: the once-ever first-run curation offer,
/// the once-per-box quarantine follow-up, the once-per-season
/// suggestion, the weekly self-report and the daily check-in; since
/// Story 7.5 the sixth stands beside them: the snowball's
/// comfortable-day crossing (ten consecutive comfortable days ending
/// yesterday, the bag below its top, no `time_bag` row today — one
/// day per run, nothing stored).
bool _residentEligible(
  StripResident resident,
  List<LogEntry> entries,
  Calendar calendar,
  Day today, {
  required bool answeredToday,
  required bool answeredDueWeek,
  required StripSuggestion? seasonalShown,
  required int? snowballShown,
  required int instantUtcMicros,
  required int offsetSeconds,
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
      // 6.6's blind once-per-box follow-up (FR-21): due exactly when
      // today is the due day of some NON-EMPTY derived box — the
      // eligibility fold below. No first-opening gate stands here,
      // unlike the residents below: the knock's window IS the day, so
      // a displacement by the rarer curation offer re-offers at the
      // next opening of the same day (UX-DR22's displacement, not a
      // consumption), an unopened day silently misses it ("at most
      // once" allows zero), and every later day closes the window by
      // derivation alone — no stored dismissal, no tombstone (AD-21,
      // AD-25). Empty boxes never knock: an empty box is 6.5's honest
      // partial-write artifact (the failed-retry orphan), not a
      // decision the user made.
      return _quarantineFollowUpDue(
        entries,
        calendar,
        today,
        instantUtcMicros: instantUtcMicros,
      );
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
      // 7.5's crossing-day window (FR-23, AD-1, AD-21): eligible
      // exactly on the day the comfortable-day run first reaches
      // ten — `== 10`, never ≥ (a chain is 10 on one day only, so
      // once-ness, the accept's reset and dismissal's no-nag scope
      // are all structural: nothing is stored, no dismissal row
      // exists, and a fully displaced or unopened day misses it,
      // "at most once" allowing zero — the 6-6 knock's own
      // pattern). No first-opening gate: a rarer resident displacing
      // the first opening re-offers the snowball at the next opening
      // of the same crossing day (the whole-day window). The shown
      // fact's own fold (`_snowballShown`) decides the bag halves:
      // the bag below its top and no `time_bag` row today — the
      // accept's own row (and a manual bag change) consumes the
      // window for the day.
      return snowballShown != null &&
          comfortableDayRunLength(
                entries: entries,
                instantUtcMicros: instantUtcMicros,
                offsetSeconds: offsetSeconds,
              ) ==
              snowballRunLength;
    // ponytail: the ten is authored (FR-23) — not a settings knob.
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

/// Whether today is the due day of at least one NON-EMPTY derived
/// Quarantine Box (Story 6.6, FR-21, AD-4): `plusMonths` of the box's
/// own day — `dayOf` of the box row's own instant in its own stored
/// offset, so a 02:00 box belongs to the previous civil day exactly
/// as every other day judgement in the app — equals today. The fold
/// reuses `deriveQuarantine` (same package, no weave cycle) and reads
/// nothing else: two boxes due the same day are one eligibility
/// (one resident, one knock — the surface carries no per-box
/// targeting), and an empty box contributes nothing at all. The cost
/// is deliberate: the full `deriveQuarantine` fold runs on every
/// strip read (false ~179 of 180 days) because the spec chose honest
/// reuse over a second contents-free existence check — fine at
/// single-user scale.
bool _quarantineFollowUpDue(
  List<LogEntry> entries,
  Calendar calendar,
  Day today, {
  required int instantUtcMicros,
}) {
  // A read can only judge facts that had happened when it began. In
  // particular, a future quarantine row must not fill an older box early.
  final visibleEntries = [
    for (final entry in entries)
      if (entry.instantUtcMicros <= instantUtcMicros) entry,
  ];
  for (final box in deriveQuarantine(visibleEntries)) {
    if (box.contents.isEmpty) {
      continue;
    }
    final boxDay = calendar.dayOf(box.instantUtcMicros, box.offsetSeconds);
    if (calendar.plusMonths(boxDay, 6) == today) {
      return true;
    }
  }
  return false;
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

/// The raised Time Bag the snowball may offer at this read (Story
/// 7.5, FR-23): the derived bag plus [snowballRaiseMinutes] — or
/// null, the offer's own silence, when nothing is left to suggest:
/// the bag already reads [timeBagMostMinutes], or a `time_bag`
/// `SettingEntry` stands whose OWN civil day is today (each row
/// scoped in its own stored offset, AD-4), the accept's own row and
/// a manual bag change alike consuming the window for the day — the
/// once-per-run clause by derivation alone, never a stored marker
/// (AD-21). Rows after the read instant are excluded, exactly the
/// derivation's own convention. The bag itself is the settings
/// derivation's ([deriveTimeBagMinutes] — the last valid row, the
/// default 15): no second definition of the bag exists here.
int? _snowballShown(
  List<LogEntry> entries,
  Calendar calendar,
  Day today,
  int instantUtcMicros,
) {
  final visible = [
    for (final entry in entries)
      if (entry.instantUtcMicros <= instantUtcMicros) entry,
  ];
  final bag = deriveTimeBagMinutes(visible);
  if (bag >= timeBagMostMinutes) {
    return null;
  }
  for (final entry in visible) {
    if (entry is SettingEntry &&
        entry.key == timeBagSettingKey &&
        calendar.dayOf(entry.instantUtcMicros, entry.offsetSeconds) == today) {
      return null;
    }
  }
  return bag + snowballRaiseMinutes;
}

/// Derives the strip's resident at one read instant (Story 2.5,
/// FR-4): pure over the log, writing nothing (AD-3). The resolution
/// walks [stripResidentPrecedence] in order and takes the first
/// resident whose eligibility holds — the load-bearing total order
/// UX-DR22 names. This build implements all six eligibilities: the
/// once-ever first-run curation offer (due iff the first opening
/// ever is underway — the day's first opening AND no `app_opened`
/// row from any earlier day, Story 5.12, FR-31), the once-per-box
/// quarantine follow-up (due iff `plusMonths` of some non-empty
/// derived box's own day equals today — no first-opening gate, the
/// day-window derivation of Story 6.6, FR-21), the once-per-season
/// suggestion (due iff the day's first opening is underway and the
/// dormant fold handed in an Epic no live same-season
/// `suggestion_dismissed` row names, Story 5.13, FR-15), the
/// snowball (due exactly on the crossing day the comfortable-day
/// run first reaches ten — while the bag sits below its top and no
/// `time_bag` row stands today, one day per run, nothing stored,
/// Story 7.5, FR-23), the weekly
/// self-report (due iff the due week — `weekOf(today).weekOrdinal`
/// minus 0 on Sunday, 1 on Mon–Sat, the latest week whose Sunday has
/// arrived — holds no accepted `report_answered` row whose carried
/// week matches, rows after the read instant excluded, and the day's
/// first opening is underway, SM-2), and the daily check-in (due iff
/// the current domestic day — each row scoped in its own stored
/// offset, AD-4 — holds no `energy_set` row and the day's first
/// opening is underway). A corrupt
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
  // The snowball's shown fact (Story 7.5, FR-23): the raised bag the
  // crossing day's sentence offers — null when the bag sits at its
  // top or today already holds a `time_bag` row, which is the
  // eligibility's own suppressed arm. Computed once beside the
  // seasonal pick, so the walk below reads it as the fact its branch
  // and its StripState both need.
  final snowballShown = _snowballShown(
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
      snowballShown: snowballShown,
      instantUtcMicros: instantUtcMicros,
      offsetSeconds: offsetSeconds,
    )) {
      return resident == StripResident.weeklySelfReport
          ? StripState(resident: resident, reportWeekOrdinal: dueWeek)
          : resident == StripResident.seasonalSuggestion
          ? StripState(resident: resident, suggestion: seasonalShown)
          : resident == StripResident.snowball
          ? StripState(
              resident: resident,
              snowballProposedMinutes: snowballShown,
            )
          : StripState(resident: resident);
    }
  }
  return null;
}

/// The Anti-Marathon checkpoint derivation (FR-10): cumulative
/// same-day session time, the interval multiples crossed versus
/// answered, and the preemption rule that decides when the
/// permission-to-rest surface leads the read.
///
/// This is the first resident of `core/derive` — the home the read
/// facade's doc reserved for derived signals. It reaches the shell as a
/// derived **state** fact for a non-work surface: AD-6's stated
/// crossing (the `warmReturnDue` precedent), never a signal-as-work, so
/// the weave's own work policy is untouched. The reveal is derived at
/// reads, never scheduled (AD-17, AD-19's reveal-not-await): no Timer,
/// no periodic write, no stored state — every fact here is recomputed
/// from the log alone, and a read writes nothing (AD-3).
///
/// The ledger rules (AD-19): a session's span is charged to its own
/// start day — a sitting crossing 04:00 accumulates into its start
/// day's total, never the crossed-into day's — and the open session's
/// span is truncated at the read instant. A `session_extended` row
/// belongs to the sitting that was open at its instant, so it answers
/// for that sitting's day; other days' extends and ends answer nothing
/// today.
///
/// Consumption is extends-only (FR-10): a crossed multiple stays
/// unanswered until a `Quiero seguir` acceptance lands — no session
/// boundary, no supersede and no stop consumes it, so chaining short
/// sittings cannot dodge the offer, and the next sitting faces the
/// standing permission once. One acceptance answers every lower
/// multiple too: the answered count is the multiple floor at the last
/// same-day extension's own instant, and cumulative time never runs
/// backwards.

library;

import 'package:core/day/calendar.dart';
import 'package:core/log/log_entry.dart';
import 'package:core/settings/settings.dart';
import 'package:core/weave/session.dart';

/// The checkpoint interval (FR-10, §10.1): fifteen minutes, a builder
/// constant — never a Settings row (the experience's five setting
/// groups own none), never a `setting_changed` key. §10.1 pins the
/// range 10–15 minutes; the core test suite pins this value inside it,
/// and every extension mints exactly this many added minutes. One
/// source of truth: the derivation, the minter and the tests read it
/// from here.
const int checkpointIntervalMinutes = 15;

/// The checkpoint derivation's state at one read instant (FR-10).
/// Fields are facts, never verbs (AD-6): each states something the log
/// makes true at the instant the derivation ran.
final class CheckpointState {
  const CheckpointState({
    required this.offerDue,
    required this.offerPreemptsStandingDeal,
  });

  /// The permission-to-rest offer is due: a session is open and
  /// unelapsed at the read instant, and the day's cumulative session
  /// time has crossed more interval multiples than same-day
  /// extensions have answered. An elapsed pocket is never due — the
  /// standing close always wins (UJ-1), and the close's own continue
  /// action is the probe's business, never this flag's.
  final bool offerDue;

  /// The offer takes the read's surface away from the standing dealt
  /// card: the card was dealt at-or-after the day's first unanswered
  /// crossing (the multiple floor at its deal instant is above the
  /// answered count), so it has never been worked through a crossing.
  /// A card in flight at the crossing stays visible and finishable
  /// (FR-10), and this fact is false while such a card stands — the
  /// offer preempts the read after it resolves. Always false when
  /// [offerDue] is false.
  final bool offerPreemptsStandingDeal;
}

/// Derives the checkpoint's state from the log at one read instant
/// (FR-10, AD-19). Pure: it computes what the log makes true and
/// writes nothing.
///
/// Cumulative same-day session time folds every session span charged
/// to its own start day (AD-19's ledger rule), the open span truncated
/// at the instant — the same fold at an earlier instant reads the
/// cumulative a deal or an extension stood on, which is what the
/// answered count and the preemption rule are made of. Crossed is the
/// interval-multiple floor of the cumulative now; answered is the
/// floor at the last same-day `session_extended`, consuming every
/// lower multiple; and a stop at the offer leaves the multiple
/// standing for the next sitting, because only an extension answers.
CheckpointState deriveCheckpoint({
  required List<LogEntry> entries,
  required int instantUtcMicros,
  required int offsetSeconds,
}) {
  const calendar = Calendar();
  final facts = walkLog(entries);
  final open = facts.openSessionStart;
  final pocket = facts.openSessionPocketMinutes;

  // One ordered pass collects the session spans — each start, its
  // offset, and the instant its matching `session_ended` closed it
  // (null while open) — and the extensions with the span they belong
  // to. An extension outside any session is not a sitting's fact and
  // answers nothing.
  final spanStarts = <int>[];
  final spanStartOffsets = <int>[];
  final spanEnds = <int?>[];
  final extendInstants = <int>[];
  final extendSpans = <int>[];
  var openSpan = -1;
  for (final entry in entries) {
    switch (entry) {
      case SessionStartEntry():
        // A start while a span stands open (an imported stray — the
        // shell's own sessionStart guards against it) abandons the
        // open span at the new start's instant, mirroring the walk's
        // latest-start-wins: the abandoned sitting is never charged
        // through the read instant on top of its successor.
        if (openSpan >= 0) {
          spanEnds[openSpan] = entry.instantUtcMicros;
        }
        spanStarts.add(entry.instantUtcMicros);
        spanStartOffsets.add(entry.offsetSeconds);
        spanEnds.add(null);
        openSpan = spanStarts.length - 1;
      case MomentEntry(:final kind) when kind == LogKind.sessionEnded:
        if (openSpan >= 0) {
          spanEnds[openSpan] = entry.instantUtcMicros;
          openSpan = -1;
        }
      case MomentEntry():
        break;
      case SessionExtendEntry(:final pocketMinutes):
        if (openSpan >= 0 && pocketMinutes > 0) {
          extendInstants.add(entry.instantUtcMicros);
          extendSpans.add(openSpan);
        }
      case ItemActEntry():
      case CrashEntry():
      case SettingEntry():
      case EnergySetEntry():
      case UnknownEntry():
        break;
    }
  }

  // The read's anchor day: the open session's own start day while one
  // is open (AD-19), else the read instant's day — the walk's own
  // session-day rule, shared so no second copy can drift.
  final anchorDay = anchorDayOf(facts, instantUtcMicros, offsetSeconds);

  // Cumulative same-day session minutes at [asOf]: every span charged
  // to the anchor day, clipped to the as-of instant — future spans
  // contribute nothing, the open span runs only up to the instant, and
  // a span whose clipped end precedes its start (non-monotonic
  // imported rows) contributes nothing rather than subtracting time.
  int cumulativeMinutesAt(int asOf) {
    var micros = 0;
    for (var i = 0; i < spanStarts.length; i++) {
      if (calendar.dayOf(spanStarts[i], spanStartOffsets[i]) != anchorDay) {
        continue;
      }
      final start = spanStarts[i];
      if (start >= asOf) {
        continue;
      }
      final end = spanEnds[i] ?? asOf;
      final spanEnd = end < asOf ? end : asOf;
      if (spanEnd > start) {
        micros += spanEnd - start;
      }
    }
    return micros ~/ microsPerMinute;
  }

  final crossed =
      cumulativeMinutesAt(instantUtcMicros) ~/ checkpointIntervalMinutes;

  // Answered: the multiple floor at the last same-day extension's own
  // instant — one acceptance consumes every lower multiple, and a
  // stop, a close or a supersede leaves the standing multiples
  // unanswered for the next sitting (FR-10's extends-only rule). The
  // maximum over the same-day extensions, never the last-in-list: the
  // floor runs with cumulative time, which never runs backwards, so a
  // non-monotonic input order cannot lower what an earlier acceptance
  // already answered.
  var answered = 0;
  for (var i = 0; i < extendInstants.length; i++) {
    final span = extendSpans[i];
    if (calendar.dayOf(spanStarts[span], spanStartOffsets[span]) != anchorDay) {
      continue;
    }
    final crossedAtExtension =
        cumulativeMinutesAt(extendInstants[i]) ~/ checkpointIntervalMinutes;
    if (crossedAtExtension > answered) {
      answered = crossedAtExtension;
    }
  }

  // Due: only inside an open, unelapsed session — the declared pocket
  // (start plus the sitting's extensions, the walk's lifted fact)
  // elapsing at the read instant makes the standing close the surface,
  // never the offer (UJ-1).
  final elapsed =
      open != null &&
      pocket != null &&
      instantUtcMicros >= open.instantUtcMicros + pocket * microsPerMinute;
  final offerDue = open != null && !elapsed && crossed > answered;

  // Preemption: the standing dealt card yields only when it was dealt
  // at-or-after the day's first unanswered crossing — the multiple
  // floor at its deal instant is above the answered count. A card
  // dealt before the crossing stays visible and finishable (FR-10);
  // every later deal hides behind the offer and returns with one
  // silent tap, never re-dealt.
  var offerPreemptsStandingDeal = false;
  final unanswered = facts.dealtUnanswered;
  if (offerDue && unanswered != null) {
    final dealtAt = facts.lastDealtInstantByItemId[unanswered.itemId];
    if (dealtAt != null) {
      offerPreemptsStandingDeal =
          cumulativeMinutesAt(dealtAt) ~/ checkpointIntervalMinutes > answered;
    }
  }

  return CheckpointState(
    offerDue: offerDue,
    offerPreemptsStandingDeal: offerPreemptsStandingDeal,
  );
}

/// Whether the close's silent continue could truthfully act at this
/// read instant (Story 2.4, FR-10): one more interval — the amount
/// every acceptance mints — must be able to buy strictly-future time,
/// so the read instant must fall before the sitting's lifted pocket
/// plus one interval. A pocket elapsed exactly at the read (UJ-1's
/// coincidence) still reaches: the tap lifts the deadline a full
/// interval past the present, and the read after it deals. A pocket
/// long elapsed carries no continue action — the row would land and
/// visibly change nothing, a dead action the offer's own grammar
/// forbids — and the chip, never a dead action, is the way back in.
/// An unbounded sitting has no deadline to lift; its closes are pool
/// exhaustion, where nothing could continue anyway.
bool closeContinueReachable({
  required LogFacts facts,
  required int instantUtcMicros,
}) {
  final open = facts.openSessionStart;
  final pocket = facts.openSessionPocketMinutes;
  if (open == null || pocket == null) {
    return false;
  }
  return instantUtcMicros <
      open.instantUtcMicros +
          (pocket + checkpointIntervalMinutes) * microsPerMinute;
}

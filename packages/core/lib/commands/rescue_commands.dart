/// The Rescue Mode commands (Story 4.6, FR-5, AD-3): pure functions
/// that compute *what* to append when a stuck task is asked to become
/// steps — never ids, instants or offsets, which the shell mints at
/// the commit of each act. A `slice_*` row exists only because one of
/// these returned it, so no second rescue writer can appear silently.
///
/// The triple's grammar mirrors the answer commands': `rescueRequested`
/// is the activation — one `slice_requested` row naming the parent,
/// the row that resets the refusal counter whatever follows (success,
/// failure or no-Slicer degradation alike); `rescueReturned` is the
/// delivered case — the step facts plus the supersede pair
/// (`slice_returned` clearing the standing card, then the bundled
/// next `card_dealt`, the head step, resolved over the log as it will
/// be once the rows land — `_answered`'s own synthesis pattern); and
/// `rescueFailed` is the terminal failure — one `slice_failed` row
/// carrying the cause, nothing queued, nothing retried, the original
/// left dealable exactly as it stood.
///
/// The depth cap lives in `rescueRequested` (FR-5): a rescue step —
/// a fact whose `rescueOf` names a parent — is refused outright, so
/// no rescue of a rescue step can exist as a row; the control's skip
/// half is the shell's reading of the same cap, never a refusal
/// surface here. No per-call dialog, no consent row, no retry and no
/// pending state exist anywhere on this path: a fresh rescue is a
/// fresh `slice_requested` by construction.

library;

import 'package:core/catalogue/catalogue.dart';
import 'package:core/commands/session_commands.dart';
import 'package:core/energy/energy.dart';
import 'package:core/log/log_entry.dart';
import 'package:core/pool/pool_fact.dart';
import 'package:core/settings/settings.dart';
import 'package:core/slicer/rescue_steps.dart';
import 'package:core/ports/slicer_port.dart';
import 'package:core/weave/session.dart';
import 'package:core/weave/weave.dart';

/// The step-fact payload of one delivered re-slice: the step's own
/// text as its Origin Context, its verbatim Slicer estimate, its
/// parent's id through `rescueOf`, and the origin inherited from the
/// parent (AD-14 — re-slice is mechanism, not re-authorship). The
/// size is the fixed `instant` band and never rides the payload: it
/// is law, not data. The shell completes each fact, minting the
/// UUIDv7 id, the instant and the offset in force, before the port
/// sees it.
typedef RescueStepFactContent = ({
  Origin origin,
  String originContext,
  String rescueOf,
  int estimateSeconds,
});

/// One delivered rescue's whole write: the step-fact payloads plus the
/// entry contents — the `slice_returned` row first, then the bundled
/// next `card_dealt` when one resolves. The shell appends each fact
/// before the entry batch, and the batch's rows in order.
typedef RescueReturnedContent = ({
  List<RescueStepFactContent> facts,
  List<LogEntryContent> entries,
});

LogEntryContent _slice(
  LogKind kind,
  String itemId,
  Origin origin, {
  String? sliceCause,
}) => (
  kind: kind,
  itemId: itemId,
  itemOrigin: origin,
  stack: null,
  settingKey: null,
  settingValue: null,
  settingTextValue: null,
  pocketMinutes: null,
  energyLevel: null,
  reportValue: null,
  reportWeek: null,
  permission: null,
  sliceCause: sliceCause,
);

LogEntryContent _dealContent(Card card) => (
  kind: LogKind.cardDealt,
  itemId: card.id,
  itemOrigin: card.origin,
  stack: null,
  settingKey: null,
  settingValue: null,
  settingTextValue: null,
  pocketMinutes: null,
  energyLevel: null,
  reportValue: null,
  reportWeek: null,
  permission: null,
  sliceCause: null,
);

/// `slice_requested` — the rescue's activation, refused on a rescue
/// step (FR-5's depth cap, stated in core so no shell path can route
/// around it): a fact whose id matches [itemId] and whose `rescueOf`
/// is set names a step, and a step's `Otra más fácil` is its skip
/// half — the command appends nothing, no refusal row exists, and no
/// error state is reachable. Refused the same quiet way when the item
/// already has a chain — any pool fact's `rescueOf` naming it, live,
/// completed or dissolved alike: one chain per item, and the parent
/// never returns as a candidate to be asked again — and when an
/// activation stands pending in [log]: a `slice_requested` naming the
/// item that no later `slice_returned` or `slice_failed` of its own
/// has matched, so no second in-flight request can dangle beside the
/// first. Any other item — a manual capture, a shipped entry, at any
/// moment, no counter consulted — appends exactly one row: the
/// request itself, which resets the refusal counter the moment it
/// lands.
List<LogEntryContent> rescueRequested({
  required String itemId,
  required Origin origin,
  required List<PoolFact> poolFacts,
  required List<LogEntry> log,
}) {
  for (final fact in poolFacts) {
    if (fact.id == itemId && fact.rescueOf != null) {
      return const [];
    }
    if (fact.rescueOf == itemId) {
      return const [];
    }
  }
  // A pending activation: the item's latest `slice_*` row in the log
  // is an unanswered `slice_requested` — this build's own request
  // still in flight (or one whose landing never landed), and a second
  // activation beside it would reset the counter a rescue is already
  // holding at zero. Append order is the one order the log guarantees
  // (AD-3), so "latest" reads by position, never by instant. The
  // scan starts at the log's last `session_started`: a request whose
  // sitting is over can never land (its flight died with the
  // process, or the live landing already matched it), so a killed
  // flight never bricks the item's tap path — the in-memory flight
  // guard holds the live double-tap shut instead.
  var sittingStart = -1;
  for (var i = 0; i < log.length; i++) {
    if (log[i].kind == LogKind.sessionStarted) {
      sittingStart = i;
    }
  }
  LogKind? latestSliceKind;
  for (var i = sittingStart + 1; i < log.length; i++) {
    final entry = log[i];
    if (entry is SliceEntry && entry.itemId == itemId) {
      latestSliceKind = entry.kind;
    }
  }
  if (latestSliceKind == LogKind.sliceRequested) {
    return const [];
  }
  return [_slice(LogKind.sliceRequested, itemId, origin)];
}

/// One delivered step beside the id the shell minted for it: the
/// landing's unit of work, one record per step — the id and the step
/// travel together so no parallel list can diverge or silently
/// truncate (the shell mints the id at the commit of the act, AD-3's
/// own division: the command stays pure, the minter stays the shell).
typedef RescueStepSeed = ({String id, RescueStep step});

/// `slice_returned` plus the steps it minted (FR-5): the parsed steps
/// ([parseRescueSteps]' own contract already bounds them 2–4 × 1–60 s,
/// each step's text at most `rescueStepTextMost` code units) become
/// transient pool facts — origin inherited from the parent,
/// size `instant`, estimate verbatim — and the supersede pair lands:
/// the `slice_returned` row clears the standing dealt-but-unanswered
/// card (the walk's rule), and the bundled next `card_dealt` resolves
/// over the log as it will be once the rows append, with the fresh
/// step facts in the pool — so the head step is the deal (rescue
/// precedence, nothing buries it). A parent whose deal ended during
/// the flight — a `card_done` naming it after its activation, or a
/// `card_skipped` naming it since the activation — discards
/// the steps: the row still logs, nothing supersedes, no fact mints
/// (the frozen matrix's own row, the skip its interleaving twin). A
/// session closed during flight simply deals nothing: the steps stand
/// in the pool for the next sitting.
RescueReturnedContent rescueReturned({
  required String itemId,
  required Origin origin,
  required List<RescueStepSeed> seeds,
  required Catalogue catalogue,
  required List<LogEntry> log,
  required int instantUtcMicros,
  required int offsetSeconds,
  int? bagMinutes,
  required List<PoolFact> poolFacts,
}) {
  // The activation located first (the latest `slice_requested`
  // naming the item, append order being the one order the log
  // guarantees), beside the item's latest answer: only a done after
  // the activation ends the deal the rescue was converting — a done
  // predating it is a previous life (a catalogue repetition
  // re-dealt), and the live deal's landing proceeds.
  var activationIndex = -1;
  for (var i = 0; i < log.length; i++) {
    final entry = log[i];
    if (entry is SliceEntry &&
        entry.itemId == itemId &&
        entry.kind == LogKind.sliceRequested) {
      activationIndex = i;
    }
  }
  final doneIndex = latestDoneIndex(log, itemId);
  if (doneIndex > activationIndex) {
    return (
      facts: const [],
      entries: [_slice(LogKind.sliceReturned, itemId, origin)],
    );
  }
  // The skip's own discard half: any decline of the parent at
  // or after it — the deal the rescue was converting is gone, and a
  // supersede against a card that no longer stands would mint a chain
  // behind the resolver's back.
  for (var i = activationIndex + 1; i < log.length; i++) {
    final entry = log[i];
    if (entry is ItemActEntry &&
        entry.itemId == itemId &&
        entry.kind == LogKind.cardSkipped) {
      return (
        facts: const [],
        entries: [_slice(LogKind.sliceReturned, itemId, origin)],
      );
    }
  }
  // The synthesized present the bundled deal resolves over — the
  // `slice_returned` row as it will read once it lands, clearing the
  // standing card exactly as an answer row would (the walk's rule).
  final synthesizedReturned = SliceEntry(
    id: '',
    kind: LogKind.sliceReturned,
    itemId: itemId,
    itemOrigin: origin,
    instantUtcMicros: instantUtcMicros,
    offsetSeconds: offsetSeconds,
  );
  final synthesizedFacts = <PoolFact>[
    for (final seed in seeds)
      PoolFact(
        id: seed.id,
        origin: origin,
        size: Size.instant,
        instantUtcMicros: instantUtcMicros,
        offsetSeconds: offsetSeconds,
        originContext: seed.step.text,
        rescueOf: itemId,
        estimateSeconds: seed.step.durationSeconds,
      ),
  ];
  final deal = nextDeal(
    catalogue: catalogue,
    log: [...log, synthesizedReturned],
    instantUtcMicros: instantUtcMicros,
    offsetSeconds: offsetSeconds,
    bagMinutes: bagMinutes ?? deriveTimeBagMinutes(log),
    energy: deriveLivePoolEnergy(log, instantUtcMicros, offsetSeconds),
    poolFacts: [...poolFacts, ...synthesizedFacts],
  );
  return (
    facts: [
      for (final seed in seeds)
        (
          origin: origin,
          originContext: seed.step.text,
          rescueOf: itemId,
          estimateSeconds: seed.step.durationSeconds,
        ),
    ],
    entries: [
      _slice(LogKind.sliceReturned, itemId, origin),
      if (deal != null) _dealContent(deal),
    ],
  );
}

/// `slice_failed` — the terminal failure, one row carrying the cause
/// (the port's closed seven; an unparsable body arrives here as
/// `malformedResponse`, the parse's own fold). Nothing is queued,
/// nothing retries, nothing persists a pending state: the original
/// stays dealable exactly as it stood and the calm surface states the
/// cause once. This is the kind's single sanctioned minter.
List<LogEntryContent> rescueFailed({
  required String itemId,
  required Origin origin,
  required SlicerFailureCause cause,
}) {
  return [_slice(LogKind.sliceFailed, itemId, origin, sliceCause: cause.name)];
}

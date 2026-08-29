/// Session and card lifecycle commands (AD-3): pure functions that
/// compute *what* to append — never ids, instants or offsets, which the
/// shell mints at the commit of each act (the crash path's division of
/// labour, generalized). A `card_dealt` row exists only because one of
/// these returned it: `session_started` appends the session's first
/// deal, and the command that answers a card appends the next — never a
/// read, never a render. An answer command appends rows only for the
/// open session's dealt-but-unanswered card: a duplicate Hecho, or one
/// naming an item never dealt, appends nothing at all.
///
/// Energy enters through `deriveLivePoolEnergy`: 1.6 has no stored
/// observations, so the level is the 🟢 default until 2.5 maps them at
/// that one seam.

library;

import 'package:core/catalogue/catalogue.dart';
import 'package:core/energy/energy.dart';
import 'package:core/log/log_entry.dart';
import 'package:core/pool/pool_fact.dart';
import 'package:core/weave/session.dart';
import 'package:core/weave/weave.dart';

/// The content of one record to append: its kind and payload. The shell
/// completes it into a record — minting the UUIDv7 id, the instant and
/// the offset in force — before the port sees it.
typedef LogEntryContent = ({
  LogKind kind,
  String? itemId,
  Origin? itemOrigin,
  String? stack,
});

LogEntryContent _moment(LogKind kind) =>
    (kind: kind, itemId: null, itemOrigin: null, stack: null);

LogEntryContent _deal(Card card) => (
  kind: LogKind.cardDealt,
  itemId: card.id,
  itemOrigin: card.origin,
  stack: null,
);

/// `app_opened` — one fact per open (AD-19's lifecycle; AD-24's reader
/// times the warm return from these rows).
List<LogEntryContent> appOpened() => [_moment(LogKind.appOpened)];

/// `session_started`, appending the session's first `card_dealt` — and
/// only when no session is open (AD-3, AD-19). The first deal needs the
/// weave; a day with nothing to deal opens the session bare.
List<LogEntryContent> sessionStart({
  required Catalogue catalogue,
  required List<LogEntry> log,
  required int instantUtcMicros,
  required int offsetSeconds,
  int bagMinutes = defaultBagMinutes,
}) {
  final facts = walkLog(log, catalogue: catalogue);
  if (facts.openSessionStart != null) {
    return const [];
  }
  final deal = nextDeal(
    catalogue: catalogue,
    log: log,
    instantUtcMicros: instantUtcMicros,
    offsetSeconds: offsetSeconds,
    bagMinutes: bagMinutes,
    energy: deriveLivePoolEnergy(instantUtcMicros, offsetSeconds),
  );
  return [_moment(LogKind.sessionStarted), if (deal != null) _deal(deal)];
}

/// `card_done` for the answered item, appending the next `card_dealt`
/// (AD-3: the command that answers the previous card deals the next).
/// The answer must name the open session's dealt-but-unanswered card —
/// a duplicate Hecho, or one naming an item never dealt, appends
/// nothing: a `card_done` on a never-dealt focus id must not close the
/// day's slot through the side door.
List<LogEntryContent> cardDone({
  required String itemId,
  required Origin origin,
  required Catalogue catalogue,
  required List<LogEntry> log,
  required int instantUtcMicros,
  required int offsetSeconds,
  int bagMinutes = defaultBagMinutes,
}) {
  return _answered(
    kind: LogKind.cardDone,
    itemId: itemId,
    origin: origin,
    catalogue: catalogue,
    log: log,
    instantUtcMicros: instantUtcMicros,
    offsetSeconds: offsetSeconds,
    bagMinutes: bagMinutes,
  );
}

/// `card_skipped` for the passed card, appending the next `card_dealt`.
/// The answer must name the open session's dealt-but-unanswered card;
/// anything else appends nothing. A skip re-resolves identity and
/// consumes no rotation (AD-20): the next deal is the resolver's choice
/// afresh, and on the chunk slot a different candidate resolves.
List<LogEntryContent> cardSkipped({
  required String itemId,
  required Origin origin,
  required Catalogue catalogue,
  required List<LogEntry> log,
  required int instantUtcMicros,
  required int offsetSeconds,
  int bagMinutes = defaultBagMinutes,
}) {
  return _answered(
    kind: LogKind.cardSkipped,
    itemId: itemId,
    origin: origin,
    catalogue: catalogue,
    log: log,
    instantUtcMicros: instantUtcMicros,
    offsetSeconds: offsetSeconds,
    bagMinutes: bagMinutes,
  );
}

/// `session_ended` — only when a session is open. Backgrounding is one
/// of AD-19's three closing causes and 1.6's only one.
List<LogEntryContent> sessionEnd({required List<LogEntry> log}) {
  final facts = walkLog(log);
  if (facts.openSessionStart == null) {
    return const [];
  }
  return [_moment(LogKind.sessionEnded)];
}

List<LogEntryContent> _answered({
  required LogKind kind,
  required String itemId,
  required Origin origin,
  required Catalogue catalogue,
  required List<LogEntry> log,
  required int instantUtcMicros,
  required int offsetSeconds,
  required int bagMinutes,
}) {
  final facts = walkLog(log, catalogue: catalogue);
  final unanswered = facts.dealtUnanswered;
  if (facts.openSessionStart == null ||
      unanswered == null ||
      unanswered.itemId != itemId ||
      unanswered.itemOrigin != origin) {
    // Nothing is open, or the answer does not name the open session's
    // dealt-but-unanswered card: a duplicate Hecho and a Hecho on an
    // item never dealt append nothing at all.
    return const [];
  }
  // The bundled next deal must see the answer it ships with: it resolves
  // on the log as it will be once the answer row is appended, so a
  // `Hecho` on the chunk closes the day's slot before the next deal
  // resolves (AD-20 — no second chunk that day). The synthesized answer
  // row carries the command's instant and offset; its id is the shell's
  // to mint and no derivation reads it.
  final answeredLog = [
    ...log,
    ItemActEntry(
      id: '',
      kind: kind,
      itemId: itemId,
      itemOrigin: origin,
      instantUtcMicros: instantUtcMicros,
      offsetSeconds: offsetSeconds,
    ),
  ];
  final deal = nextDeal(
    catalogue: catalogue,
    log: answeredLog,
    instantUtcMicros: instantUtcMicros,
    offsetSeconds: offsetSeconds,
    bagMinutes: bagMinutes,
    energy: deriveLivePoolEnergy(instantUtcMicros, offsetSeconds),
  );
  return [
    (kind: kind, itemId: itemId, itemOrigin: origin, stack: null),
    if (deal != null) _deal(deal),
  ];
}

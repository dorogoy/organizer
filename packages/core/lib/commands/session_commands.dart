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
/// that one seam. The Time Bag enters through `deriveTimeBagMinutes`
/// (2.1): callers may pass a value derived once for the whole operation
/// — the shell's threading — and a caller that passes none gets the
/// derivation over the very log it hands in, so no composition path can
/// rely on the default once a setting exists.
///
/// Story 2.2 adds the declared pocket (FR-8, AD-19): `sessionStart`
/// mints the pocketed row — still the single `session_started` minter —
/// resolving its first deal over the log as it will be once the start
/// row lands, so the pocket bounds the sitting's very first card.
/// `sessionDeclare` is the tap's command: a range guard, then the
/// supersede pair `[session_ended, session_started{pocket}]` at one
/// instant — the user-stop vocabulary and the new declaration — with
/// the in-progress card carried across (the walk's pair rule) and the
/// bundled deal suppressed while one is carried. `appOpen` absorbs the
/// reveal composition: a pocket that elapsed while the app was not
/// foregrounded closes at the open's own instant, before the fresh
/// `session_started` — two derived-open sessions never coexist.
///
/// Story 2.3 adds the pause (FR-9): the quiet stop emits through
/// `sessionEnd` unchanged — one row, no payload, no new LogKind — and
/// `nextDeal` itself now holds the sitting line (no open session, no
/// deal), so the post-pause read model is the standing warm close.

library;

import 'package:core/catalogue/catalogue.dart';
import 'package:core/energy/energy.dart';
import 'package:core/log/log_entry.dart';
import 'package:core/pool/pool_fact.dart';
import 'package:core/settings/settings.dart';
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
  String? settingKey,
  int? settingValue,
  int? pocketMinutes,
});

LogEntryContent _moment(LogKind kind) => (
  kind: kind,
  itemId: null,
  itemOrigin: null,
  stack: null,
  settingKey: null,
  settingValue: null,
  pocketMinutes: null,
);

LogEntryContent _start({int? pocketMinutes}) => (
  kind: LogKind.sessionStarted,
  itemId: null,
  itemOrigin: null,
  stack: null,
  settingKey: null,
  settingValue: null,
  pocketMinutes: pocketMinutes,
);

LogEntryContent _deal(Card card) => (
  kind: LogKind.cardDealt,
  itemId: card.id,
  itemOrigin: card.origin,
  stack: null,
  settingKey: null,
  settingValue: null,
  pocketMinutes: null,
);

/// `app_opened` — one fact per open (AD-19's lifecycle; AD-24's reader
/// times the warm return from these rows).
List<LogEntryContent> appOpened() => [_moment(LogKind.appOpened)];

/// `session_started`, appending the session's first `card_dealt` — and
/// only when no session is open (AD-3, AD-19). The first deal needs the
/// weave; a day with nothing to deal opens the session bare. A
/// [pocketMinutes] value mints the declared pocket on the row (the
/// command boundary's own guard is `sessionDeclare`'s — the shell's
/// auto-open passes none). The deal resolves over the log as it will
/// be once the start row is appended — `_answered`'s synthesis
/// pattern — so a pocketed start bounds its own first card, and a
/// start directly following a same-instant `session_ended` (the
/// supersede pair's second half, already in the handed-in log) carries
/// the in-progress card and suppresses the deal through the walk's
/// pair rule.
List<LogEntryContent> sessionStart({
  required Catalogue catalogue,
  required List<LogEntry> log,
  required int instantUtcMicros,
  required int offsetSeconds,
  int? bagMinutes,
  int? pocketMinutes,
}) {
  final facts = walkLog(log, catalogue: catalogue);
  if (facts.openSessionStart != null) {
    return const [];
  }
  final startLog = [
    ...log,
    SessionStartEntry(
      id: '',
      kind: LogKind.sessionStarted,
      pocketMinutes: pocketMinutes,
      instantUtcMicros: instantUtcMicros,
      offsetSeconds: offsetSeconds,
    ),
  ];
  final deal = nextDeal(
    catalogue: catalogue,
    log: startLog,
    instantUtcMicros: instantUtcMicros,
    offsetSeconds: offsetSeconds,
    bagMinutes: bagMinutes ?? deriveTimeBagMinutes(startLog),
    energy: deriveLivePoolEnergy(instantUtcMicros, offsetSeconds),
  );
  return [_start(pocketMinutes: pocketMinutes), if (deal != null) _deal(deal)];
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
  int? bagMinutes,
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
  int? bagMinutes,
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

/// `session_ended` — only when a session is open. The user stopping —
/// the pause tap (Story 2.3) beside the declare tap's supersede — the
/// declared pocket elapsing while the app is foregrounded (revealed at
/// `app_opened`), and the app being backgrounded are AD-19's three
/// closing causes; there is no fourth closing cause and no emission
/// outside the three causes' sites (the sites themselves are four — the
/// census's business, not the vocabulary's), and no close cause rides
/// the row.
List<LogEntryContent> sessionEnd({required List<LogEntry> log}) {
  final facts = walkLog(log);
  if (facts.openSessionStart == null) {
    return const [];
  }
  return [_moment(LogKind.sessionEnded)];
}

/// The declare tap (Story 2.2, FR-8, AD-19): declares a pocket, ending
/// whatever session is open and starting a pocketed one at the same
/// instant — the supersede pair, adjacent in store read order, so the
/// walk's rule carries the in-progress card across and its later
/// `card_done` charges the new sitting. Consumption restarts at zero
/// (the walk's answered seconds are session-scoped), and the bundled
/// first deal resolves over the pair — bounded by the new pocket,
/// suppressed while a card is carried. A value outside
/// `pocketLeastMinutes`–`pocketMostMinutes` returns no content: the
/// surface offers only in-range options, so the refusal is the command
/// boundary's own guard and nothing else.
List<LogEntryContent> sessionDeclare({
  required Catalogue catalogue,
  required List<LogEntry> log,
  required int pocketMinutes,
  required int instantUtcMicros,
  required int offsetSeconds,
  int? bagMinutes,
}) {
  if (pocketMinutes < pocketLeastMinutes || pocketMinutes > pocketMostMinutes) {
    return const [];
  }
  final end = sessionEnd(log: log);
  final startLog = end.isEmpty
      ? log
      : [
          ...log,
          MomentEntry(
            id: '',
            kind: LogKind.sessionEnded,
            instantUtcMicros: instantUtcMicros,
            offsetSeconds: offsetSeconds,
          ),
        ];
  return [
    ...end,
    ...sessionStart(
      catalogue: catalogue,
      log: startLog,
      instantUtcMicros: instantUtcMicros,
      offsetSeconds: offsetSeconds,
      bagMinutes: bagMinutes,
      pocketMinutes: pocketMinutes,
    ),
  ];
}

/// The open's own composition (Story 2.2, AD-19): `app_opened`, then —
/// only when the derived-open session's declared pocket elapsed at this
/// instant (the reveal, never a scheduled close) — its `session_ended`,
/// then the fresh `session_started` with its first deal. The deal and
/// the start resolve over the synthesized post-`session_ended` log
/// exactly as `_answered` resolves over its synthesized answer, so the
/// reveal pair carries an in-progress card (the walk's same-instant
/// rule suppresses the bundled deal) and the normal case — no session
/// open, or one whose pocket has not elapsed — appends exactly the rows
/// `appOpened` + `sessionStart` always did.
List<LogEntryContent> appOpen({
  required Catalogue catalogue,
  required List<LogEntry> log,
  required int instantUtcMicros,
  required int offsetSeconds,
  int? bagMinutes,
}) {
  final facts = walkLog(log, catalogue: catalogue);
  final open = facts.openSessionStart;
  final pocket = facts.openSessionPocketMinutes;
  final pocketElapsed =
      open != null &&
      pocket != null &&
      instantUtcMicros >= open.instantUtcMicros + pocket * microsPerMinute;
  var startLog = log;
  final end = pocketElapsed ? sessionEnd(log: log) : const <LogEntryContent>[];
  if (end.isNotEmpty) {
    startLog = [
      ...log,
      MomentEntry(
        id: '',
        kind: LogKind.sessionEnded,
        instantUtcMicros: instantUtcMicros,
        offsetSeconds: offsetSeconds,
      ),
    ];
  }
  return [
    ...appOpened(),
    ...end,
    ...sessionStart(
      catalogue: catalogue,
      log: startLog,
      instantUtcMicros: instantUtcMicros,
      offsetSeconds: offsetSeconds,
      bagMinutes: bagMinutes,
    ),
  ];
}

List<LogEntryContent> _answered({
  required LogKind kind,
  required String itemId,
  required Origin origin,
  required Catalogue catalogue,
  required List<LogEntry> log,
  required int instantUtcMicros,
  required int offsetSeconds,
  required int? bagMinutes,
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
  // to mint and no derivation reads it. The bag derives over the very
  // log the deal resolves on — a mid-day change appends its own row and
  // re-derives forward only (AD-20), and the two reads cannot diverge.
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
    bagMinutes: bagMinutes ?? deriveTimeBagMinutes(answeredLog),
    energy: deriveLivePoolEnergy(instantUtcMicros, offsetSeconds),
  );
  return [
    (
      kind: kind,
      itemId: itemId,
      itemOrigin: origin,
      stack: null,
      settingKey: null,
      settingValue: null,
      pocketMinutes: null,
    ),
    if (deal != null) _deal(deal),
  ];
}

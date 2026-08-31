import 'package:core/catalogue/catalogue.dart';
import 'package:core/commands/energy_commands.dart';
import 'package:core/commands/session_commands.dart';
import 'package:core/day/calendar.dart';
import 'package:core/derive/checkpoint.dart';
import 'package:core/derive/strip.dart';
import 'package:core/energy/energy.dart';
import 'package:core/log/log_entry.dart';
import 'package:core/ports/store_port.dart';
import 'package:core/settings/settings.dart';
import 'package:core/weave/session.dart';
import 'package:core/weave/weave.dart';
import 'package:flutter/services.dart';
import 'package:uuid/uuid.dart';

import '../catalogue/loader.dart';
import '../session/log_write_queue.dart';
import '../strings/app_strings.dart';

/// The Dispenser's whole read surface (FR-1, AD-6): what the screen
/// renders once the first read resolves — the dealt card, or the warm
/// close when the deal is absent. The read-not-yet-resolved state is the
/// screen's own (an empty `surfaceBase` frame, never a loader), so it
/// lives there and not here.
///
/// Every variant also carries the ambient strip's fact (Story 2.5,
/// UX-DR22): whether the check-in resident is showing below the card —
/// derived in the same queue-consistent read as the card itself, never
/// held in memory as truth. A dismissal is shell state keyed by the
/// domestic day — skip-for-today (see
/// [DispenserController.dismissCheckIn]); an answer is a row, and the
/// derivation hides the strip for the day on its own.
sealed class DispenserView {
  const DispenserView({this.checkInShown = false});

  /// Whether the ambient strip holds the energy check-in on this read
  /// — the precedence derivation's resident, suppressed by a dismissal
  /// of the current opening and by nothing else in the shell.
  final bool checkInShown;
}

/// The dealt-unanswered card of the open session — the launch deal on a
/// cold start, since `SessionController.handleAppOpen` appends the
/// session's first `card_dealt` before the first frame needs it.
/// Carries the standing declared pocket (Story 2.2): the open session's
/// own pocket fact, absent when the sitting is unbounded — the trigger
/// chip's data, never session state held as truth (AD-19).
final class DispenserDealt extends DispenserView {
  const DispenserDealt(this.card, {this.pocketMinutes, super.checkInShown});

  final Card card;

  final int? pocketMinutes;
}

/// `nextCard` returned nothing: the warm close surface, quiet, never an
/// error (FR-3) — the same close for a spent or elapsed pocket as for
/// pool exhaustion. Carries the standing declared pocket exactly as the
/// dealt variant does: the chip stands on the closed surface too.
/// Since Story 2.4 it also carries whether the close is the offer — the
/// checkpoint's silent `Quiero seguir` secondary, offered only while one
/// more interval could truthfully reach beyond the read and a deal
/// would exist if the pocket had room (the core's probe, UJ-1); a
/// pool-exhausted or long-elapsed close carries nothing.
final class DispenserClosed extends DispenserView {
  const DispenserClosed({
    this.pocketMinutes,
    this.continueOffered = false,
    super.checkInShown,
  });

  final int? pocketMinutes;

  final bool continueOffered;
}

/// The permission-to-rest offer (Story 2.4, FR-10): the checkpoint
/// derivation's surface, preempting the card the read would otherwise
/// present — a standing card dealt at-or-after the pending crossing, or
/// the deal that would now resolve. Carries the standing declared
/// pocket for the chip, exactly as the other variants do. Nothing here
/// counts anything: the surface is two actions, never a question,
/// never a number that would have been higher (UJ-1, UX-DR44).
final class DispenserRestOffer extends DispenserView {
  const DispenserRestOffer({this.pocketMinutes, super.checkInShown});

  final int? pocketMinutes;
}

/// The Dispenser's read and write surface (Stories 1.8–1.10, 2.2–2.5): the
/// app's home surface derives its card and standing pocket from one log snapshot,
/// and answers it through the two core answer commands, each appending its
/// answer and the bundled next deal itself (AD-3): `cardDone` (Story 1.9)
/// and `cardSkipped` (Story 1.10, FR-3), each with the Time Bag derived once
/// per operation and threaded in (2.1); `declarePocket` (Story 2.2) and
/// `pause` (Story 2.3, FR-9) round the surface — a declaration and the
/// quiet one-row stop — and `extend` (Story 2.4, FR-10) is the
/// checkpoint's silent continue: one `session_extended`, plus the
/// bundled next deal when the lift unblocks a sitting with no
/// unanswered card (AD-3). `setEnergy` and `dismissCheckIn`
/// (Story 2.5, FR-4) carry the ambient strip below the card: the
/// check-in's one-row answer and its write-free dismissal, the
/// resident's fact riding every read.
/// The injectables follow `SessionController`'s: `store`, `strings`,
/// `bundle`, `idMinter` and `nowOf` — the shell may read the clock and
/// mint ids, the core never does, and no `ClockPort` exists to implement.
///
/// The catalogue loads once per controller lifetime, memoized with
/// failure-not-memoized retry — the same contract as
/// `session_controller.dart`'s memo: a failed load clears the memo so the
/// next read retries instead of throwing forever. The double asset read
/// this shares with the session controller is benign (`rootBundle` caches
/// bytes).
class DispenserController {
  DispenserController({
    required this.store,
    required this.strings,
    this.bundle,
    this.idMinter = const Uuid(),
    this.nowOf = DateTime.now,
    LogWriteQueue? writeQueue,
  }) : writeQueue = writeQueue ?? LogWriteQueue();

  final StorePort store;
  final AppStrings strings;
  final AssetBundle? bundle;
  final Uuid idMinter;
  final DateTime Function() nowOf;
  final LogWriteQueue writeQueue;
  Future<Catalogue>? _catalogue;

  /// The day whose check-in the ✕ dismissed (Story 2.5, UX-DR22) —
  /// shell state, never a row: AD-21's vocabulary has no dismissal
  /// kind and a synthetic `energy_set` is forbidden. A dismissal is
  /// skip-for-TODAY, so the day alone keys it: every read of the same
  /// domestic day is suppressed whatever the opening census does — a
  /// dismissal taken during a sitting with no `app_opened` in the day
  /// (the crossing or idle-foreground shape) cannot lapse when the
  /// day's first `app_opened` later lands and the derivation judges
  /// the first opening underway again. The next day is a different
  /// `Day` by construction, so the marker never over-reaches and the
  /// derivation decides the new day on its own rows.
  Day? _checkInDismissMarker;

  /// Reads the card to display (AD-3: a pure computation, never a write).
  /// It runs in the shared log queue, so the pocket and card come from one
  /// post-write snapshot and the clock is read only when that snapshot is
  /// safe to derive. The frozen precedence (Story 2.4, FR-10, UJ-1) maps
  /// the checkpoint derivation over the surfaces: a standing close wins
  /// over a due offer — an elapsed pocket is never due, and the close
  /// carries the continue action only while one more interval could
  /// truthfully reach beyond the read AND the pool probe says a deal
  /// would exist with room — and a due offer preempts every deal-shaped
  /// surface: the standing card dealt at-or-after the pending crossing,
  /// or the deal that would now resolve. A card in flight at the
  /// crossing stays visible and finishable; every later deal hides
  /// behind the offer and returns with one silent tap, never re-dealt.
  ///
  /// Story 2.5 adds the ambient strip's fact to the same snapshot: the
  /// strip derivation resolves the check-in resident — due at the day's
  /// first opening while the day holds no `energy_set` row — and the
  /// shell suppresses it only for the day the user dismissed
  /// (skip-for-today); an answered day hides on its own, a later
  /// opening hides by the derivation, and nothing else in the shell
  /// touches it.
  Future<DispenserView> read() => writeQueue.enqueue(() async {
    final now = nowOf();
    final catalogue = await _loadCatalogue();
    // The standing declared pocket (Story 2.2) derives from the log the
    // same read resolves against — log-derived, never held in memory as
    // truth (AD-19). An out-of-range pocket row derives as absent here,
    // exactly as in the walk; a sitting's extensions lift it (2.4).
    final log = logEntriesOf(await store.readLogEntries());
    final facts = walkLog(log, catalogue: catalogue);
    final pocket = facts.openSessionPocketMinutes;
    // The strip's fact (Story 2.5): the resident derivation over the
    // same queue-consistent log, suppressed by a dismissal of this
    // DAY alone — skip-for-today, never skip-for-this-opening, so no
    // later app_opened of the same day can resurrect a dismissed
    // strip. A new day is a different `Day`, and the derivation
    // decides it on its own rows.
    final today = _dayOf(now);
    final strip = deriveStrip(
      entries: log,
      instantUtcMicros: now.microsecondsSinceEpoch,
      offsetSeconds: now.timeZoneOffset.inSeconds,
    );
    final checkInShown = strip != null && _checkInDismissMarker != today;
    final unanswered = facts.dealtUnanswered;
    final card = unanswered == null
        ? nextDeal(
            catalogue: catalogue,
            log: log,
            instantUtcMicros: now.microsecondsSinceEpoch,
            offsetSeconds: now.timeZoneOffset.inSeconds,
            bagMinutes: deriveTimeBagMinutes(log),
            energy: deriveLivePoolEnergy(
              log,
              now.microsecondsSinceEpoch,
              now.timeZoneOffset.inSeconds,
            ),
          )
        : cardForItem(
            catalogue: catalogue,
            itemId: unanswered.itemId,
            origin: unanswered.itemOrigin,
          );
    if (card == null) {
      // The standing close always wins (UJ-1): a due offer never
      // replaces it. The close is the offer — the silent continue
      // beneath the warm string — only while one more interval could
      // truthfully reach beyond this read (the derivation's window:
      // long-elapsed pockets carry nothing, the chip is the way back
      // in) AND the pool probe finds a deal the lifted pocket would
      // let resolve — a pool-exhausted close carries nothing either.
      return DispenserClosed(
        pocketMinutes: pocket,
        continueOffered:
            closeContinueReachable(
              facts: facts,
              instantUtcMicros: now.microsecondsSinceEpoch,
            ) &&
            dealExistsIgnoringPocket(
              catalogue: catalogue,
              log: log,
              instantUtcMicros: now.microsecondsSinceEpoch,
              offsetSeconds: now.timeZoneOffset.inSeconds,
              bagMinutes: deriveTimeBagMinutes(log),
              energy: deriveLivePoolEnergy(
                log,
                now.microsecondsSinceEpoch,
                now.timeZoneOffset.inSeconds,
              ),
            ),
        checkInShown: checkInShown,
      );
    }
    final checkpoint = deriveCheckpoint(
      entries: log,
      instantUtcMicros: now.microsecondsSinceEpoch,
      offsetSeconds: now.timeZoneOffset.inSeconds,
    );
    if (checkpoint.offerDue &&
        (unanswered == null || checkpoint.offerPreemptsStandingDeal)) {
      return DispenserRestOffer(
        pocketMinutes: pocket,
        checkInShown: checkInShown,
      );
    }
    return DispenserDealt(
      card,
      pocketMinutes: pocket,
      checkInShown: checkInShown,
    );
  });

  /// Answers the dealt card (Story 1.9's one write path, FR-2): runs the
  /// core `cardDone` command — the `card_done` row plus the bundled next
  /// `card_dealt` — with the derived bag and the energy default, minting
  /// one instant for the whole batch and a v7 id per row, exactly as
  /// `SessionController._appendAll` does. The instant is minted at entry,
  /// before any await, so the recorded rows describe the tap, not the
  /// reads that follow. A duplicate or never-dealt answer appends
  /// nothing at all (the core's side-door guard); a failing append
  /// rethrows to the caller while the chain recovers.
  Future<void> complete(DispenserDealt dealt) {
    final now = nowOf();
    return _enqueueWrite(() async {
      final catalogue = await _loadCatalogue();
      final log = logEntriesOf(await store.readLogEntries());
      // The bag derives once per operation (2.1) and threads into the
      // command — no shell-reachable path relies on the default.
      final contents = cardDone(
        itemId: dealt.card.id,
        origin: dealt.card.origin,
        catalogue: catalogue,
        log: log,
        instantUtcMicros: now.microsecondsSinceEpoch,
        offsetSeconds: now.timeZoneOffset.inSeconds,
        bagMinutes: deriveTimeBagMinutes(log),
      );
      for (final content in contents) {
        await store.appendLogEntry((
          id: idMinter.v7(),
          kind: content.kind.name,
          instantUtcMicros: now.microsecondsSinceEpoch,
          offsetSeconds: now.timeZoneOffset.inSeconds,
          itemId: content.itemId,
          itemOrigin: content.itemOrigin,
          stack: content.stack,
          settingKey: content.settingKey,
          settingValue: content.settingValue,
          pocketMinutes: content.pocketMinutes,
          energyLevel: content.energyLevel,
        ));
      }
    });
  }

  /// Passes the dealt card (Story 1.10's one write path, FR-3): runs the
  /// core `cardSkipped` command — the `card_skipped` row plus the bundled
  /// next `card_dealt`, the resolver's choice afresh (AD-20: identity
  /// re-resolves and a skip consumes no rotation) — with the derived bag
  /// and the energy default, minting one instant for the whole
  /// batch and a v7 id per row, exactly as `complete` does. The instant
  /// is minted at entry, before any await, so the recorded rows describe
  /// the tap, not the reads that follow. A duplicate or never-dealt skip
  /// appends nothing at all (the core's side-door guard — a skip racing
  /// a `Hecho` lands on it); when the skipped card was the day's last
  /// candidate only the answer row returns and the next read closes
  /// warm; a failing append rethrows to the caller while the chain
  /// recovers. No feedback belongs to this path — the different card
  /// *is* the answer.
  Future<void> skip(DispenserDealt dealt) {
    final now = nowOf();
    return _enqueueWrite(() async {
      final catalogue = await _loadCatalogue();
      final log = logEntriesOf(await store.readLogEntries());
      final contents = cardSkipped(
        itemId: dealt.card.id,
        origin: dealt.card.origin,
        catalogue: catalogue,
        log: log,
        instantUtcMicros: now.microsecondsSinceEpoch,
        offsetSeconds: now.timeZoneOffset.inSeconds,
        bagMinutes: deriveTimeBagMinutes(log),
      );
      for (final content in contents) {
        await store.appendLogEntry((
          id: idMinter.v7(),
          kind: content.kind.name,
          instantUtcMicros: now.microsecondsSinceEpoch,
          offsetSeconds: now.timeZoneOffset.inSeconds,
          itemId: content.itemId,
          itemOrigin: content.itemOrigin,
          stack: content.stack,
          settingKey: content.settingKey,
          settingValue: content.settingValue,
          pocketMinutes: content.pocketMinutes,
          energyLevel: content.energyLevel,
        ));
      }
    });
  }

  /// Declares a pocket (Story 2.2, FR-8): runs the core `sessionDeclare`
  /// command — the supersede pair `[session_ended?, session_started{p}]`
  /// plus a first `card_dealt` only when nothing is carried — with the
  /// derived bag, minting one instant for the whole batch and a v7 id per
  /// row, exactly as `complete` and `skip` do. The instant is minted at
  /// entry, before any await, so the recorded pair describes the tap. A
  /// value the command refuses appends nothing and no error state exists
  /// to reach (the ladder offers only in-range options); a failing
  /// append rethrows to the caller while the chain recovers. The fresh
  /// view — the carried card, the pocket-bounded deal, or the warm close
  /// — is read back from the log the declaration made true.
  Future<DispenserView> declarePocket(int minutes) {
    final now = nowOf();
    final write = _enqueueWrite(() async {
      final catalogue = await _loadCatalogue();
      final log = logEntriesOf(await store.readLogEntries());
      final contents = sessionDeclare(
        catalogue: catalogue,
        log: log,
        pocketMinutes: minutes,
        instantUtcMicros: now.microsecondsSinceEpoch,
        offsetSeconds: now.timeZoneOffset.inSeconds,
        bagMinutes: deriveTimeBagMinutes(log),
      );
      for (final content in contents) {
        await store.appendLogEntry((
          id: idMinter.v7(),
          kind: content.kind.name,
          instantUtcMicros: now.microsecondsSinceEpoch,
          offsetSeconds: now.timeZoneOffset.inSeconds,
          itemId: content.itemId,
          itemOrigin: content.itemOrigin,
          stack: content.stack,
          settingKey: content.settingKey,
          settingValue: content.settingValue,
          pocketMinutes: content.pocketMinutes,
          energyLevel: content.energyLevel,
        ));
      }
    });
    return write.then((_) => read());
  }

  /// Pauses (Story 2.3, FR-9, AD-19): the quiet stop, in
  /// [declarePocket]'s write shape minus the catalogue — `sessionEnd`
  /// reads only the log, so no catalogue load exists on this path.
  /// Exactly one `session_ended` row appends when a session is open —
  /// one minted instant, a v7 id, no payload, no new LogKind — and a
  /// tap with nothing open appends nothing at all: the accepted quiet
  /// no-op, the `PocketTriggerChip` precedent. The instant is minted at
  /// entry, before any await, so the row describes the tap. A failing
  /// append rethrows to the caller while the chain recovers. The fresh
  /// view — the standing warm close with the chip back at its 15
  /// default — is read back from the log the pause made true.
  Future<DispenserView> pause() {
    final now = nowOf();
    final write = _enqueueWrite(() async {
      final log = logEntriesOf(await store.readLogEntries());
      final contents = sessionEnd(log: log);
      for (final content in contents) {
        await store.appendLogEntry((
          id: idMinter.v7(),
          kind: content.kind.name,
          instantUtcMicros: now.microsecondsSinceEpoch,
          offsetSeconds: now.timeZoneOffset.inSeconds,
          itemId: content.itemId,
          itemOrigin: content.itemOrigin,
          stack: content.stack,
          settingKey: content.settingKey,
          settingValue: content.settingValue,
          pocketMinutes: content.pocketMinutes,
          energyLevel: content.energyLevel,
        ));
      }
    });
    return write.then((_) => read());
  }

  /// Extends the sitting (Story 2.4, FR-10, AD-19): the checkpoint's
  /// silent continue, in [declarePocket]'s write shape — `sessionExtend`
  /// needs the catalogue for the bundled next deal (AD-3), the same
  /// door `sessionStart` uses. Exactly one `session_extended` row
  /// appends when a session is open — one minted instant, a v7 id, and
  /// `checkpointIntervalMinutes` added minutes as the row's whole
  /// payload — through the core's single sanctioned minter; when the
  /// lift unblocks a sitting with no unanswered card the command also
  /// returns the next `card_dealt`, so the card the surface shows is
  /// one this write minted. A tap with nothing open appends nothing at
  /// all: the accepted quiet no-op, the pause's own precedent. The walk
  /// lifts the sitting's declared pocket by the added minutes (deadline
  /// and ceiling; the sum may pass the declarable 1–60 range, which
  /// bounds starts only), while the start row keeps FR-23's original
  /// pocket. The instant is minted at entry, before any await, so the
  /// rows describe the tap. A failing append rethrows to the caller
  /// while the chain recovers. The fresh view — the standing card
  /// returned, the newly dealt card, or the close still standing — is
  /// read back from the log the extension made true, and a standing
  /// card is never re-dealt.
  Future<DispenserView> extend() {
    final now = nowOf();
    final write = _enqueueWrite(() async {
      final catalogue = await _loadCatalogue();
      final log = logEntriesOf(await store.readLogEntries());
      final contents = sessionExtend(
        catalogue: catalogue,
        log: log,
        instantUtcMicros: now.microsecondsSinceEpoch,
        offsetSeconds: now.timeZoneOffset.inSeconds,
        bagMinutes: deriveTimeBagMinutes(log),
      );
      for (final content in contents) {
        await store.appendLogEntry((
          id: idMinter.v7(),
          kind: content.kind.name,
          instantUtcMicros: now.microsecondsSinceEpoch,
          offsetSeconds: now.timeZoneOffset.inSeconds,
          itemId: content.itemId,
          itemOrigin: content.itemOrigin,
          stack: content.stack,
          settingKey: content.settingKey,
          settingValue: content.settingValue,
          pocketMinutes: content.pocketMinutes,
          energyLevel: content.energyLevel,
        ));
      }
    });
    return write.then((_) => read());
  }

  /// Answers the check-in (Story 2.5, FR-4): one `energy_set` row
  /// through the core's single sanctioned minter, in [declarePocket]'s
  /// write-then-read shape minus the catalogue — `energySet` reads no
  /// log and bundles no deal, so the check-in never deals a card
  /// (AD-3). The instant is minted at entry, before any await, so the
  /// row describes the tap. On baja the fresh read narrows the next
  /// deal to instant-tier only while a card in progress stays
  /// finishable — the standing card is the read's own answered fact,
  /// never withdrawn; on media and llena the pool is unchanged. A
  /// failing append rethrows to the caller while the chain recovers —
  /// nothing landed, the strip stands, and the retry is the same tap.
  Future<DispenserView> setEnergy(EnergyLevel level) {
    final now = nowOf();
    final write = _enqueueWrite(() async {
      // `energySet` is pure over its input — no log read, no bundled
      // deal — so the write path reads nothing: the row is the tap.
      final contents = energySet(level: level);
      for (final content in contents) {
        await store.appendLogEntry((
          id: idMinter.v7(),
          kind: content.kind.name,
          instantUtcMicros: now.microsecondsSinceEpoch,
          offsetSeconds: now.timeZoneOffset.inSeconds,
          itemId: content.itemId,
          itemOrigin: content.itemOrigin,
          stack: content.stack,
          settingKey: content.settingKey,
          settingValue: content.settingValue,
          pocketMinutes: content.pocketMinutes,
          energyLevel: content.energyLevel,
        ));
      }
    });
    return write.then((_) => read());
  }

  /// Dismisses the check-in (Story 2.5, FR-4, UX-DR22): skip-for-today,
  /// and deliberately NOT a write — AD-21's vocabulary has no dismissal
  /// kind, a synthetic `energy_set` row is forbidden, and the strip
  /// renders but never writes (AD-3). The dismissal lives in shell
  /// state keyed by the tap's own domestic day: every read of that day
  /// hides the resident — whatever opening it belongs to — and the
  /// next day starts clean, decided by the derivation on its own rows.
  /// Never re-shown within the day, never styled as anything owed.
  Future<DispenserView> dismissCheckIn() {
    // The day is minted at entry, from the tap's own instant — no log
    // read exists on this path, because nothing about the dismissal
    // depends on the log.
    _checkInDismissMarker = _dayOf(nowOf());
    return read();
  }

  Future<void> _enqueueWrite(Future<void> Function() step) {
    return writeQueue.enqueue(step);
  }

  /// The domestic day of [now] in its own offset (AD-4's calendar is
  /// the only authority) — the dismissal state's whole key.
  Day _dayOf(DateTime now) => const Calendar().dayOf(
    now.microsecondsSinceEpoch,
    now.timeZoneOffset.inSeconds,
  );

  /// The catalogue loads once per controller lifetime. A failed load is
  /// not memoized — the memo clears on error so the next read retries
  /// instead of throwing into the empty frame forever.
  Future<Catalogue> _loadCatalogue() =>
      _catalogue ??= _loadCatalogueRetryingAfterFailure();

  Future<Catalogue> _loadCatalogueRetryingAfterFailure() async {
    try {
      return await loadEvergreenCatalogue(strings, bundle: bundle);
    } catch (_) {
      _catalogue = null;
      rethrow;
    }
  }
}

import 'package:core/catalogue/catalogue.dart';
import 'package:core/commands/session_commands.dart';
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
sealed class DispenserView {
  const DispenserView();
}

/// The dealt-unanswered card of the open session — the launch deal on a
/// cold start, since `SessionController.handleAppOpen` appends the
/// session's first `card_dealt` before the first frame needs it.
/// Carries the standing declared pocket (Story 2.2): the open session's
/// own pocket fact, absent when the sitting is unbounded — the trigger
/// chip's data, never session state held as truth (AD-19).
final class DispenserDealt extends DispenserView {
  const DispenserDealt(this.card, {this.pocketMinutes});

  final Card card;

  final int? pocketMinutes;
}

/// `nextCard` returned nothing: the warm close surface, quiet, never an
/// error (FR-3) — the same close for a spent or elapsed pocket as for
/// pool exhaustion. Carries the standing declared pocket exactly as the
/// dealt variant does: the chip stands on the closed surface too.
final class DispenserClosed extends DispenserView {
  const DispenserClosed({this.pocketMinutes});

  final int? pocketMinutes;
}

/// The Dispenser's read and write surface (Stories 1.8–1.10): the app's
/// home surface derives its card and standing pocket from one log snapshot,
/// and answers it through the two core answer commands, each appending its
/// answer and the bundled next deal itself (AD-3): `cardDone` (Story 1.9)
/// and `cardSkipped` (Story 1.10, FR-3), each with the Time Bag derived once
/// per operation and threaded in (2.1).
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

  /// Reads the card to display (AD-3: a pure computation, never a write).
  /// It runs in the shared log queue, so the pocket and card come from one
  /// post-write snapshot and the clock is read only when that snapshot is
  /// safe to derive.
  Future<DispenserView> read() => writeQueue.enqueue(() async {
    final now = nowOf();
    final catalogue = await _loadCatalogue();
    // The standing declared pocket (Story 2.2) derives from the log the
    // same read resolves against — log-derived, never held in memory as
    // truth (AD-19). An out-of-range pocket row derives as absent here,
    // exactly as in the walk.
    final log = logEntriesOf(await store.readLogEntries());
    final facts = walkLog(log, catalogue: catalogue);
    final pocket = facts.openSessionPocketMinutes;
    final unanswered = facts.dealtUnanswered;
    final card = unanswered == null
        ? nextDeal(
            catalogue: catalogue,
            log: log,
            instantUtcMicros: now.microsecondsSinceEpoch,
            offsetSeconds: now.timeZoneOffset.inSeconds,
            bagMinutes: deriveTimeBagMinutes(log),
            energy: deriveLivePoolEnergy(
              now.microsecondsSinceEpoch,
              now.timeZoneOffset.inSeconds,
            ),
          )
        : cardForItem(
            catalogue: catalogue,
            itemId: unanswered.itemId,
            origin: unanswered.itemOrigin,
          );
    return card == null
        ? DispenserClosed(pocketMinutes: pocket)
        : DispenserDealt(card, pocketMinutes: pocket);
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
        ));
      }
    });
    return write.then((_) => read());
  }

  Future<void> _enqueueWrite(Future<void> Function() step) {
    return writeQueue.enqueue(step);
  }

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

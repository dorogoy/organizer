import 'package:core/catalogue/catalogue.dart';
import 'package:core/commands/session_commands.dart';
import 'package:core/facade/read_facade.dart';
import 'package:core/log/log_entry.dart';
import 'package:core/ports/store_port.dart';
import 'package:core/settings/settings.dart';
import 'package:core/weave/weave.dart';
import 'package:flutter/services.dart';
import 'package:uuid/uuid.dart';

import '../catalogue/loader.dart';
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
final class DispenserDealt extends DispenserView {
  const DispenserDealt(this.card);

  final Card card;
}

/// `nextCard` returned nothing: the warm close surface, quiet, never an
/// error (FR-3).
final class DispenserClosed extends DispenserView {
  const DispenserClosed();
}

/// The Dispenser's read and write surface (Stories 1.8–1.10): the app's
/// home surface computes its card through `nextCard` — the read facade's
/// one function — and answers it through the two core answer commands,
/// each appending its answer and the bundled next deal itself (AD-3):
/// `cardDone` (Story 1.9) and `cardSkipped` (Story 1.10, FR-3), each with
/// the Time Bag derived once per operation and threaded in (2.1).
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
  });

  final StorePort store;
  final AppStrings strings;
  final AssetBundle? bundle;
  final Uuid idMinter;
  final DateTime Function() nowOf;
  Future<Catalogue>? _catalogue;

  /// The serialized write path (Stories 1.9–1.10): one answer's
  /// read→compute→append — a completion or a skip — runs to completion
  /// before the next begins — `SessionController`'s `_lifecycle`
  /// contract — so a rapid second tap reads the post-answer log and the
  /// core guard appends nothing.
  /// Failures clear from the chain itself so one throwing answer
  /// never wedges the next.
  Future<void> _writes = Future<void>.value();

  /// Reads the card to display (AD-3: a pure computation, never a write).
  /// The instant is minted at entry, before any await, so the derivation
  /// resolves against the moment the user is looking at the screen. The
  /// settled write chain drains before the store is read: a lifecycle
  /// refresh landing mid-answer-batch — the `card_done`/`card_skipped`
  /// appended, the bundled `card_dealt` not yet — must never derive from
  /// that half-written log (a resolver fall-through card the store never
  /// recorded). The chain future never fails; failures clear into it as
  /// they rethrow to their callers, so this await needs no guard.
  Future<DispenserView> read() async {
    final now = nowOf();
    await _writes;
    final catalogue = await _loadCatalogue();
    final card = await nextCard(
      store,
      catalogue: catalogue,
      instantUtcMicros: now.microsecondsSinceEpoch,
      offsetSeconds: now.timeZoneOffset.inSeconds,
    );
    return card == null ? const DispenserClosed() : DispenserDealt(card);
  }

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
        ));
      }
    });
  }

  Future<void> _enqueueWrite(Future<void> Function() step) {
    final chained = _writes.then((_) => step());
    // The caller observes the attempt's failure, while the chain itself
    // recovers so a later answer — a completion or a skip — can retry.
    _writes = chained.catchError((Object error) {});
    return chained;
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

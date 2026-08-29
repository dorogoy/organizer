import 'package:core/catalogue/catalogue.dart';
import 'package:core/facade/read_facade.dart';
import 'package:core/ports/store_port.dart';
import 'package:core/weave/weave.dart';
import 'package:flutter/services.dart';

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

/// The Dispenser's read path (Story 1.8): the app's home surface computes
/// its card through `nextCard` — the read facade's one function — and
/// writes nothing (AD-3; 1.9's answers are what refresh it). The
/// injectables follow `SessionController`'s: `store`, `strings`, `bundle`
/// and `nowOf` — the shell may read the clock, the core never does, and no
/// `ClockPort` exists to implement.
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
    this.nowOf = DateTime.now,
  });

  final StorePort store;
  final AppStrings strings;
  final AssetBundle? bundle;
  final DateTime Function() nowOf;
  Future<Catalogue>? _catalogue;

  /// Reads the card to display (AD-3: a pure computation, never a write).
  /// The instant is minted at entry, before any await, so the derivation
  /// resolves against the moment the user is looking at the screen.
  Future<DispenserView> read() async {
    final now = nowOf();
    final catalogue = await _loadCatalogue();
    final card = await nextCard(
      store,
      catalogue: catalogue,
      instantUtcMicros: now.microsecondsSinceEpoch,
      offsetSeconds: now.timeZoneOffset.inSeconds,
    );
    return card == null ? const DispenserClosed() : DispenserDealt(card);
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

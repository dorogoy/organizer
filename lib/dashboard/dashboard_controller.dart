// The cumulative impact dashboard's shell half (Story 7.4, FR-23):
// the read-only controller behind the dashboard surface — one read
// composing the substrate's own snapshots (the log, the pool facts,
// the catalogue) into the core's crossing derivation
// (`core/derive/impact.dart`). What the construction actually
// provides is two sequential store reads — the log, then the pool
// facts — plus the catalogue load, the Dispenser's own incumbent
// pattern: no queue serializes these reads against a concurrent
// write, so the composition is eventually-consistent across the
// three, never a queue-consistent snapshot. The dashboard is a
// RENDERING of what the log already holds: no new LogKind, no schema
// column, no minter and no write path exist here — the controller
// holds no write queue at all, and the `Files` port is exposed for
// `PhotoFrame` alone.
//
// A failing read rethrows: a transient store, pool or catalogue error
// must not read as an empty album on this surface — the dashboard is
// reachable only through the album, so its empty state is the album's
// own pop, never a figure of zeros over a failed read (the
// `AlbumController.read` contract, mirrored).
import 'package:core/catalogue/catalogue.dart';
import 'package:core/derive/impact.dart';
import 'package:core/log/log_entry.dart';
import 'package:core/ports/files_port.dart';
import 'package:core/ports/store_port.dart';

/// The cumulative impact dashboard's shell half (Story 7.4, FR-23):
/// see the library comment. The catalogue arrives as a loader — the
/// same seam `DispenserController` holds — so the controller never
/// names a bundle or a strings source itself, and the composition
/// site (main) owns which catalogue loads.
class DashboardController {
  DashboardController({
    required this.store,
    required this.files,
    required this.loadCatalogue,
  });

  final StorePort store;

  /// The Files adapter the highlight row's `PhotoFrame`s read the
  /// album blobs through — held here, exposed read-only, so the
  /// surface never touches the store's substrate for bytes.
  final FilesPort files;

  /// The catalogue loader — `loadEvergreenCatalogue` composed in main
  /// over the same strings the shell holds.
  final Future<Catalogue> Function() loadCatalogue;

  /// Reads the whole dashboard in one pass (Story 7.4, FR-23): the
  /// log, the pool facts and the catalogue, awaited in sequence —
  /// two sequential store reads plus the load, the Dispenser's own
  /// incumbent pattern — then composed by the core's one crossing
  /// derivation. Rethrows on any failure: transient is never empty,
  /// and the surface's quiet pending plate is the honest presentation
  /// of a read that has not resolved.
  Future<ImpactRead> read() async {
    final entries = logEntriesOf(await store.readLogEntries());
    final poolFacts = poolFactsOf(await store.readPoolFacts());
    final catalogue = await loadCatalogue();
    return deriveImpact(
      entries: entries,
      catalogue: catalogue,
      poolFacts: poolFacts,
    );
  }
}

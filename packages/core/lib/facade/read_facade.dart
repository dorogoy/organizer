/// The read facade (AD-6): the shell's only work surface. `nextCard` is
/// the one function — it returns at most one card, writes nothing
/// (AD-3), and no function in this library returns a collection of work
/// items. Derived signals, when they arrive, are named as facts and live
/// in `core/derive` — inputs to the weave, not outputs to the shell.
/// That home holds two residents now: `core/derive/checkpoint.dart`
/// (Story 2.4) derives the FR-10 checkpoint and `core/derive/strip.dart`
/// (Story 2.5) the ambient strip's resident, each as a state fact the
/// shell renders as a non-work surface — AD-6's stated crossing for
/// derived state, on the `warmReturnDue` precedent — while every work
/// signal this facade exposes stays `nextCard` alone.

library;

import 'package:core/catalogue/catalogue.dart';
import 'package:core/energy/energy.dart';
import 'package:core/log/log_entry.dart';
import 'package:core/ports/store_port.dart';
import 'package:core/settings/settings.dart';
import 'package:core/weave/session.dart';
import 'package:core/weave/weave.dart';

/// The card the surface renders (AD-3, AD-6): the dealt-but-unanswered
/// card of the open session when one exists — an unanswered card never
/// produces a second deal — else the resolver's next choice, computed
/// purely and appended by no one here. A log with no open session
/// resolves absent too — the warm close (Story 2.3): deals exist only
/// inside sittings, so the facade never hands the shell a card no
/// command can answer. Energy arrives through
/// [deriveLivePoolEnergy] over this read's own log (2.5's seam): the
/// day's `energy_set` rows narrow the resolver's choice, a baja day
/// dealing instant-tier only, while a card in progress stays the
/// answered-unanswered card above. The Time Bag derives from this
/// read's own log too (2.1, AD-1): an explicit [bagMinutes] overrides
/// it for a caller that derived once for a whole operation, and no
/// shell-reachable path relies on the default once a setting exists.
/// Since Story 3.3 the same read also takes the store's pool-fact
/// snapshot — read once beside the log, in this one operation — so
/// the card the surface renders sees manual captures exactly as the
/// deal-resolving paths do: a dealt-but-unanswered capture
/// re-materializes as its own card (its line, its fact's size, no
/// zone), and a standing capture precedes same-size catalogue work
/// in the resolver's choice.
Future<Card?> nextCard(
  StorePort store, {
  required Catalogue catalogue,
  required int instantUtcMicros,
  required int offsetSeconds,
  int? bagMinutes,
}) async {
  final entries = logEntriesOf(await store.readLogEntries());
  final poolFacts = poolFactsOf(await store.readPoolFacts());
  final facts = walkLog(entries, catalogue: catalogue, poolFacts: poolFacts);
  final unanswered = facts.dealtUnanswered;
  if (unanswered != null) {
    return cardForItem(
      catalogue: catalogue,
      itemId: unanswered.itemId,
      origin: unanswered.itemOrigin,
      poolFacts: poolFacts,
    );
  }
  return nextDeal(
    catalogue: catalogue,
    log: entries,
    instantUtcMicros: instantUtcMicros,
    offsetSeconds: offsetSeconds,
    bagMinutes: bagMinutes ?? deriveTimeBagMinutes(entries),
    energy: deriveLivePoolEnergy(entries, instantUtcMicros, offsetSeconds),
    poolFacts: poolFacts,
  );
}

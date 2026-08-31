/// The read facade (AD-6): the shell's only work surface. `nextCard` is
/// the one function — it returns at most one card, writes nothing
/// (AD-3), and no function in this library returns a collection of work
/// items. Derived signals, when they arrive, are named as facts and live
/// in `core/derive` — inputs to the weave, not outputs to the shell.

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
/// [deriveLivePoolEnergy]: no observations exist in 1.6, so the day
/// defaults to 🟢 until 2.5 maps them at that one seam. The Time Bag
/// derives from this read's own log (2.1, AD-1): an explicit
/// [bagMinutes] overrides it for a caller that derived once for a whole
/// operation, and no shell-reachable path relies on the default once a
/// setting exists.
Future<Card?> nextCard(
  StorePort store, {
  required Catalogue catalogue,
  required int instantUtcMicros,
  required int offsetSeconds,
  int? bagMinutes,
}) async {
  final entries = logEntriesOf(await store.readLogEntries());
  final facts = walkLog(entries, catalogue: catalogue);
  final unanswered = facts.dealtUnanswered;
  if (unanswered != null) {
    return cardForItem(
      catalogue: catalogue,
      itemId: unanswered.itemId,
      origin: unanswered.itemOrigin,
    );
  }
  return nextDeal(
    catalogue: catalogue,
    log: entries,
    instantUtcMicros: instantUtcMicros,
    offsetSeconds: offsetSeconds,
    bagMinutes: bagMinutes ?? deriveTimeBagMinutes(entries),
    energy: deriveLivePoolEnergy(instantUtcMicros, offsetSeconds),
  );
}

/// The cumulative impact read (Story 7.4, FR-23, AD-26): the crossing
/// surface between the substrate's derivations and the dashboard —
/// exactly the four achievement figure groups AD-26 names, composed
/// here in one function so no consumer can re-derive them wrong.
///
/// Composition, never invention: the work figures are the walk's own
/// all-time folds (`walkLog`'s `answeredSecondsAllTime` and
/// `cardDoneCount`, charged at the one `card_done` branch through the
/// one charging table), the volume tallies are the declutter metric's
/// own (`deriveDeclutterMetric`, 6.7), the highlights are the album's
/// own live entries (`albumEntries`, 7.2), and the highlight place is
/// the weave's own group fold (`epicGroupsByStableId`) joined by the
/// group stable id the album entry names. Every figure therefore
/// reads exactly what every other derivation reads — the dashboard
/// cannot disagree with the session ledger, the album or the metric.
///
/// The record carries achievement figures ONLY (AD-26's closed list):
/// no internal signal, no per-destination count and — deliberately —
/// no `liberatedItems` subtotal crosses (the volume is named, not
/// counted: FR-22 forbids unit equivalence, so the per-tag tallies
/// stay separate and the precise subtotal stays core-side where the
/// dashboard's shape cannot render it as a denominator). Every value
/// is a fact about what already happened; none admits a denominator
/// (UX-DR36, FR-23), which the record's own shape — counts, seconds
/// and blob names, never a ratio — enforces by construction.

library;

import 'package:core/catalogue/catalogue.dart';
import 'package:core/derive/album.dart';
import 'package:core/derive/declutter_metric.dart';
import 'package:core/log/log_entry.dart';
import 'package:core/pool/pool_fact.dart';
import 'package:core/weave/session.dart';
import 'package:core/weave/weave.dart';

/// One album highlight (Story 7.4, FR-23): a live entry's Before/After
/// blob names plus the caption facts the row renders — the group's
/// Origin Context (the place, absent when no group lookup or no
/// context resolves: a typed-genesis or manual-capture group carries
/// none, and the caption degrades to the date alone) and the entry's
/// own added instant, and the civil-day offset its
/// `album_entry_added` row recorded (AD-4) — from which the short
/// date derives as the act's own recorded civil day, never the
/// reading device's zone. No count, no adjective, nothing else
/// crosses.
typedef ImpactHighlight = ({
  String beforeName,
  String afterName,
  String? place,
  int addedUtcMicros,
  int offsetSeconds,
});

/// The cumulative impact read (Story 7.4, FR-23, AD-26): the work
/// figures straight off the walk's all-time folds, the four per-tag
/// liberated volume tallies straight off the declutter metric, and
/// the three newest live album entries with their place join —
/// newest first, the gallery's own order. Zero — never null — is the
/// honest cumulative for a figure that has not begun (FR-23), and an
/// empty highlights list is the empty album: the dashboard's own
/// surface pops on it (contextual-only reach, UX-DR31/32/51).
typedef ImpactRead = ({
  int answeredSecondsAllTime,
  int cardDoneCount,
  int liberatedBolsa,
  int liberatedCaja,
  int liberatedCajaGrande,
  int liberatedMueble,
  List<ImpactHighlight> highlights,
});

/// How many highlights the dashboard's row renders (Story 7.4,
/// FR-23, mockup §3): three columns of Before/After pairs, the three
/// newest — a closed count of the row's own shape, never a quota or
/// a target (UX-DR36: nothing here can read as a denominator).
const int impactHighlightCount = 3;

/// Derives the cumulative impact read (Story 7.4, FR-23, AD-26,
/// AD-1): pure over the entries, pool facts and catalogue it is
/// given — the caller supplies the queue-consistent reads, the
/// `deriveQuarantine`/`deriveStrip` consumer contract — writing
/// nothing and storing nothing. Same input, identical record; zero
/// rows, every figure zero and no highlights.
ImpactRead deriveImpact({
  required List<LogEntry> entries,
  required Catalogue catalogue,
  required List<PoolFact> poolFacts,
}) {
  final facts = walkLog(entries, catalogue: catalogue, poolFacts: poolFacts);
  final metric = deriveDeclutterMetric(entries);
  final live = albumEntries(entries);
  final groups = epicGroupsByStableId(poolFacts);
  // The newest three, newest first — the gallery's own order, so the
  // row and the album never disagree about which transformation is
  // the latest.
  final newest = live.length <= impactHighlightCount
      ? live.reversed.toList()
      : live.sublist(live.length - impactHighlightCount).reversed.toList();
  return (
    answeredSecondsAllTime: facts.answeredSecondsAllTime,
    cardDoneCount: facts.cardDoneCount,
    liberatedBolsa: metric.liberatedBolsa,
    liberatedCaja: metric.liberatedCaja,
    liberatedCajaGrande: metric.liberatedCajaGrande,
    liberatedMueble: metric.liberatedMueble,
    highlights: [
      for (final entry in newest)
        (
          beforeName: entry.beforeName,
          afterName: entry.afterName,
          // The place join (Story 7.4): the group's own first fact's
          // Origin Context — the space description the whole slice
          // shares — read through the weave's one group fold. A group
          // the fold does not know, or one whose context is null,
          // renders no place: the caption degrades to the date alone,
          // never an invented label.
          place: groups[entry.groupId]?.first.originContext,
          addedUtcMicros: entry.addedUtcMicros,
          offsetSeconds: entry.offsetSeconds,
        ),
    ],
  );
}

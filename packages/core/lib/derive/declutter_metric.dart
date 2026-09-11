/// The cumulative declutter metric (Story 6.7, FR-22, AD-26): a
/// pure fold over the log that turns the letting-go trace — the
/// `item_triaged` rows Story 6.3's minter appended — into the
/// cumulative achievement figures Epic 7's dashboard (7.3) consumes:
/// per-destination item counts plus coarse tag tallies over
/// liberated rows only. One derivation in the core so the "which
/// destinations liberate" rule lives in exactly one place and no
/// future consumer can re-derive it wrong — the `deriveQuarantine`
/// precedent (6.5), mirrored.
///
/// The record is counts and nothing else: every field is an int
/// count of user taps, so a percentage, rate, average or denominator
/// is unrepresentable by construction (FR-22, AD-26 — approximations
/// and figures without denominators; the dashboard's rendering, UX-
/// DR49's `≈ 3 cajas liberadas` register, is 7.3's concern, never
/// this fold's). Only `donate_sell` and `trash_recycle` liberate:
/// `liberatedItems` is their sum and the tag tallies count tags on
/// their rows alone — a kept object liberates nothing, and neither
/// does a quarantined one, the same grammar the minter already
/// asserts for quarantine (`triage_commands.dart`: "a quarantined
/// object liberates nothing"). The per-tag tally is the honest
/// volume shape: collapsing bolsa/caja/caja grande/mueble into one
/// figure would need an equivalence table — a numeric volume in
/// disguise, which FR-22 forbids and the enum makes
/// unrepresentable.
///
/// Figures come only from user taps during purge, never photographs
/// (FR-22): the fold consults nothing but the `item_triaged` rows it
/// is given, and nothing inferred from any other kind crosses here.

library;

import 'package:core/log/log_entry.dart';

/// The cumulative declutter metric as the fold derives it (Story
/// 6.7, FR-22, AD-26): one int count per destination, the
/// `liberatedItems` subtotal (`donate_sell` + `trash_recycle` —
/// the only destinations that liberate), and one int tally per
/// coarse tag over liberated rows alone. Every field is an int:
/// the record's own shape forbids a percentage, rate, average or
/// denominator (FR-22, AD-26), and zero — never null — is the
/// honest cumulative for a count that has not begun (FR-23's
/// dashboard renders 7.3's approximation sentence over these
/// figures, UX-DR49's register).
///
/// Cumulative, never reset: the metric is a fold over the whole
/// read-visible log, so a later read that sees more rows derives
/// counts that only grow. No surface exists for it yet — 7.3 is
/// the crossing, importing this derivation over the queue-consistent
/// read (the `deriveStrip`/`deriveQuarantine` consumer pattern).
typedef DeclutterMetric = ({
  int keepCount,
  int donateSellCount,
  int trashRecycleCount,
  int quarantineCount,
  int liberatedItems,
  int liberatedBolsa,
  int liberatedCaja,
  int liberatedCajaGrande,
  int liberatedMueble,
});

/// Derives the cumulative declutter metric from the log (Story 6.7,
/// FR-22, AD-26, AD-1): pure over the entries it is given — the
/// caller supplies read-visible rows, `deriveQuarantine`'s contract
/// — writing nothing and storing nothing. Same input, identical
/// record; zero rows, every count zero. One pass in replay order,
/// the `TriageEntry` filter the only kind it reads: unknown kinds
/// ride the log as `UnknownEntry` (AD-23 carries them verbatim) and
/// the type filter skips them here, while unknown triage payload
/// wire names never reached this fold at all — the read boundary
/// flawed them out. Every row handed to the fold counts, exactly
/// once: there is no id-dedup, because the caller's snapshot is the
/// unit of truth and sanctioned writers mint UUIDv7 ids — a
/// duplicate would be the caller's corrupted read, not a fact this
/// fold should silently repair (AD-23's no-repair grammar).
DeclutterMetric deriveDeclutterMetric(List<LogEntry> entries) {
  var keepCount = 0;
  var donateSellCount = 0;
  var trashRecycleCount = 0;
  var quarantineCount = 0;
  var liberatedBolsa = 0;
  var liberatedCaja = 0;
  var liberatedCajaGrande = 0;
  var liberatedMueble = 0;
  for (final entry in entries) {
    if (entry is! TriageEntry) {
      continue;
    }
    // Only donate_sell and trash_recycle liberate (FR-22): the tag
    // tally is counted inside this predicate's branch alone, so a
    // tag on a kept row — or a quarantined one, where the minter
    // refuses tags outright — contributes to no volume. The switch
    // is exhaustive by enum case: a future destination member is a
    // compile error here, never a silent non-liberator — the
    // vocabulary is forward-only and this is where it stays honest.
    final liberates = switch (entry.destination) {
      TriageDestination.keep => false,
      TriageDestination.donate_sell => true,
      TriageDestination.trash_recycle => true,
      TriageDestination.quarantine => false,
    };
    switch (entry.destination) {
      case TriageDestination.keep:
        keepCount++;
      case TriageDestination.donate_sell:
        donateSellCount++;
      case TriageDestination.trash_recycle:
        trashRecycleCount++;
      case TriageDestination.quarantine:
        quarantineCount++;
    }
    if (!liberates) {
      continue;
    }
    switch (entry.volumeTag) {
      case null:
        break;
      case CoarseVolumeTag.bolsa:
        liberatedBolsa++;
      case CoarseVolumeTag.caja:
        liberatedCaja++;
      case CoarseVolumeTag.caja_grande:
        liberatedCajaGrande++;
      case CoarseVolumeTag.mueble:
        liberatedMueble++;
    }
  }
  return (
    keepCount: keepCount,
    donateSellCount: donateSellCount,
    trashRecycleCount: trashRecycleCount,
    quarantineCount: quarantineCount,
    liberatedItems: donateSellCount + trashRecycleCount,
    liberatedBolsa: liberatedBolsa,
    liberatedCaja: liberatedCaja,
    liberatedCajaGrande: liberatedCajaGrande,
    liberatedMueble: liberatedMueble,
  );
}

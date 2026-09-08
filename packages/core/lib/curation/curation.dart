/// Cluster curation as inert observations plus one pure derivation
/// (AD-16, FR-31): the user may enable or disable a whole cluster —
/// `anclas`, `sostén`, `z1`–`z5`, `fondo` — and the effective active set
/// is derived from the observation records, never stored.
///
/// This file holds only the derivation and the cluster mapping, mirroring
/// `core/energy`'s shape: [CurationObservation] is inert data a caller
/// hands over — exactly like the energy module's observation record —
/// and since Story 5.11 the one seam every log-holding caller passes
/// through: [curationObservationsOf] maps stored
/// `cluster_curation_changed` entries into observations and hands them
/// to [activeClustersAt], exactly as `deriveLivePoolEnergy` maps
/// `energy_set` rows. Structurally there is still no write path here:
/// a pure function over passed-in entries and records, and with no
/// observation the default is all-active by construction.
///
/// Timing (AD-16's deliberate split): a weekly-zone cluster change takes
/// effect at the start of the week **after** the observation's own
/// domestic week — the rotation argument is theirs, so the current
/// week's rotation stands — while `anclas`, `sostén` and `fondo` changes
/// take effect on their own domestic day, where FR-31's *simply never
/// appear* governs. Boundary instants belong to the new period,
/// half-open, exactly as [Calendar] defines every boundary.

library;

import 'package:core/catalogue/catalogue.dart';
import 'package:core/day/calendar.dart';
import 'package:core/log/log_entry.dart';
import 'package:core/pool/pool_fact.dart';

/// The eight curation clusters (FR-31, AD-16): groups derivable from the
/// catalogue tuple and nothing else — `anclas` (daily Instant Habits),
/// `sostén` (daily upkeep and Focus Chunks of the day), the five weekly
/// zones, and `fondo` (seasonal depth work). A12's `plantas` and `coche`
/// annotations are not independently switchable; no other cluster exists.
enum CurationCluster {
  /// Daily instant-size entries — the anchors' tiny habits.
  anclas,

  /// Daily maintenance and focus entries — the day's upkeep.
  sosten,

  /// The weekly zone z1.
  z1,

  /// The weekly zone z2.
  z2,

  /// The weekly zone z3.
  z3,

  /// The weekly zone z4.
  z4,

  /// The weekly zone z5.
  z5,

  /// Seasonal entries — monthly and seasonal depth work.
  fondo,
}

/// Every cluster, the all-active default (AD-16): with no observations
/// nothing is curated away, so the floor math holds over the whole
/// catalogue by construction.
const Set<CurationCluster> allCurationClusters = {
  CurationCluster.anclas,
  CurationCluster.sosten,
  CurationCluster.z1,
  CurationCluster.z2,
  CurationCluster.z3,
  CurationCluster.z4,
  CurationCluster.z5,
  CurationCluster.fondo,
};

/// One curation observation as inert data: the cluster, whether it was
/// enabled, the instant it was set, and the local offset in force when
/// it was written (AD-4). Each observation is scoped to a period in its
/// own stored frame — exactly like a log entry, because that is what a
/// later writer will map rows into.
typedef CurationObservation = ({
  CurationCluster cluster,
  bool enabled,
  int instantUtcMicros,
  int offsetSeconds,
});

/// The cluster an entry belongs to (AD-16: derivable from the tuple
/// only): daily instants are `anclas`, daily maintenance and focus are
/// `sostén`, weekly entries belong to their zone, seasonal entries are
/// `fondo`. [parseCatalogue] guarantees the tuple's zone discipline on
/// the asset path — a weekly entry carries a zone and no other cadence
/// does — so a hand-built entry breaking either half fails fast here,
/// named — never a bare null dereference or a silently misclustered
/// zone — mirroring `walkLog`'s duplicate-id discipline.
CurationCluster curationClusterOfEntry(CatalogueEntry entry) {
  if (entry.cadence != Cadence.weekly && entry.zone != null) {
    throw StateError(
      'non-weekly entry "${entry.id}" carries a zone — a zone is legal '
      'only on a weekly entry (A12.4); a fixture bypassing '
      'parseCatalogue has drifted',
    );
  }
  return switch (entry.cadence) {
    Cadence.daily =>
      entry.size == Size.instant
          ? CurationCluster.anclas
          : CurationCluster.sosten,
    Cadence.weekly => curationClusterOfZone(_weeklyZoneOf(entry)),
    Cadence.seasonal => CurationCluster.fondo,
  };
}

Zone _weeklyZoneOf(CatalogueEntry entry) {
  final zone = entry.zone;
  if (zone == null) {
    throw StateError(
      'weekly entry "${entry.id}" carries no zone — a weekly entry carries '
      'one (A12.4); a fixture bypassing parseCatalogue has drifted',
    );
  }
  return zone;
}

/// The weekly-zone cluster of [zone].
CurationCluster curationClusterOfZone(Zone zone) => switch (zone) {
  Zone.z1 => CurationCluster.z1,
  Zone.z2 => CurationCluster.z2,
  Zone.z3 => CurationCluster.z3,
  Zone.z4 => CurationCluster.z4,
  Zone.z5 => CurationCluster.z5,
};

/// The zone a weekly-zone cluster names, or absent for `anclas`,
/// `sostén` and `fondo` — the zone rotation's ring walks the five zone
/// clusters through this.
Zone? zoneOfCurationCluster(CurationCluster cluster) => switch (cluster) {
  CurationCluster.z1 => Zone.z1,
  CurationCluster.z2 => Zone.z2,
  CurationCluster.z3 => Zone.z3,
  CurationCluster.z4 => Zone.z4,
  CurationCluster.z5 => Zone.z5,
  CurationCluster.anclas ||
  CurationCluster.sosten ||
  CurationCluster.fondo => null,
};

/// Every cluster keyed by wire name (Story 5.11) — the enum's own
/// names, derived from the values so a new member cannot write a name
/// this map does not know (the `slicerFailureCauseByName` precedent).
/// The `cluster_curation_changed` row's cluster identity is stored as
/// wire text and read through this map alone.
final Map<String, CurationCluster> curationClusterByName = {
  for (final cluster in CurationCluster.values) cluster.name: cluster,
};

/// The cluster a stored wire name names, or absent when the name is
/// null, empty, or one this build does not know (Story 5.11) — the
/// read boundary's quiet tolerance (AD-23), the `permission` column's
/// own discipline: the row is excluded at the boundary, never
/// coerced, never repaired.
CurationCluster? curationClusterOfWireName(String? name) =>
    name == null ? null : curationClusterByName[name];

/// The curation observations of a log (Story 5.11, AD-16, AD-1): every
/// `cluster_curation_changed` entry as one inert observation, in log
/// order — the pure fold between the log the derivations already hold
/// and [activeClustersAt], so the active set is always a derivation of
/// rows, never a stored switch. Every other entry passes through
/// unnamed — unknown kinds, user acts, system events — and a
/// malformed curation row never reaches the fold at all: the read
/// boundary excluded it before the log held an entry.
List<CurationObservation> curationObservationsOf(Iterable<LogEntry> log) => [
  for (final entry in log)
    if (entry is ClusterCurationChangedEntry)
      (
        cluster: entry.cluster,
        enabled: entry.enabled,
        instantUtcMicros: entry.instantUtcMicros,
        offsetSeconds: entry.offsetSeconds,
      ),
];

/// The clusters still active at [instantUtcMicros] (AD-16): every
/// cluster not turned away by its newest *effective* observation — the
/// default, with no effective observation, is active. Each observation's
/// timing is judged in its own stored frame (AD-4), so the derivation
/// needs no evaluation frame: periods are half-open instant ranges.
///
/// An observation is effective when its timing rule is satisfied: a
/// weekly-zone cluster's change from the start of the week **after** the
/// observation's own domestic week (an instant exactly on that boundary
/// belongs to the new week, half-open); an `anclas`/`sostén`/`fondo`
/// change from its own domestic day's opening instant — its whole day.
/// Among a cluster's effective observations the newest wins, and an
/// exact-instant tie resolves to the later-in-input one — the energy
/// derivation's tie discipline.
Set<CurationCluster> activeClustersAt(
  Iterable<CurationObservation> observations,
  int instantUtcMicros,
) {
  const calendar = Calendar();
  final newestEffectiveByCluster = _newestByCluster(
    observations
        .where(
          (observation) =>
              _observationIsEffective(calendar, observation, instantUtcMicros),
        )
        .toList(),
  );
  return {
    for (final cluster in allCurationClusters)
      if (newestEffectiveByCluster[cluster]?.enabled ?? true) cluster,
  };
}

/// The clusters the log's latest declarations hold active (Story
/// 5.11, FR-31): every cluster whose newest observation — timing
/// aside — is enabled; the default, with no observation, active.
/// This is the control surface's own read: the switch shows what the
/// house's keeper last declared, while [activeClustersAt] — the
/// composition read — applies AD-16's two speeds. The two agree on
/// daily and `fondo` clusters at every instant and on weekly zones
/// from their boundary on; between a mid-week flip and its boundary
/// they differ by design, because a switch that springs back reads
/// as a refused act and the surface may carry no copy to explain the
/// spring (UX-DR23: no visual consequence beyond the switch itself).
Set<CurationCluster> declaredActiveClusters(
  Iterable<CurationObservation> observations,
) {
  final newestByCluster = _newestByCluster(observations);
  return {
    for (final cluster in allCurationClusters)
      if (newestByCluster[cluster]?.enabled ?? true) cluster,
  };
}

/// The newest observation per cluster (Story 5.11) — the one fold both
/// curation reads share, so their last-row-wins rule and their
/// exact-instant tie discipline (the later-in-input observation wins,
/// the energy derivation's own) can never drift apart: whatever reads
/// curation, newest means newest.
Map<CurationCluster, CurationObservation> _newestByCluster(
  Iterable<CurationObservation> observations,
) {
  final newestByCluster = <CurationCluster, CurationObservation>{};
  for (final observation in observations) {
    final newest = newestByCluster[observation.cluster];
    if (newest == null ||
        observation.instantUtcMicros >= newest.instantUtcMicros) {
      newestByCluster[observation.cluster] = observation;
    }
  }
  return newestByCluster;
}

/// Whether [observation] has taken effect by [instantUtcMicros]:
/// weekly-zone clusters at the close of the observation's own domestic
/// week — the next Monday 04:00 in the observation's stored frame, an
/// instant exactly there belonging to the new week — and every other
/// cluster from its own domestic day's opening instant.
bool _observationIsEffective(
  Calendar calendar,
  CurationObservation observation,
  int instantUtcMicros,
) {
  final observedDay = calendar.dayOf(
    observation.instantUtcMicros,
    observation.offsetSeconds,
  );
  final effectiveFromUtcMicros =
      zoneOfCurationCluster(observation.cluster) != null
      ? calendar.weekOf(observedDay).endUtcMicros
      : observedDay.startUtcMicros;
  return instantUtcMicros >= effectiveFromUtcMicros;
}

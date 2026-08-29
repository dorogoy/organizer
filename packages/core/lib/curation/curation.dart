/// Cluster curation as inert observations plus one pure derivation
/// (AD-16, FR-31): the user may enable or disable a whole cluster —
/// `anclas`, `sostén`, `z1`–`z5`, `fondo` — and the effective active set
/// is derived from the observation records, never stored.
///
/// This file holds only the derivation and the cluster mapping, mirroring
/// `core/energy`'s shape: [CurationObservation] is inert data a caller
/// hands over — exactly like the energy module's observation record,
/// because rows mapped into it are what a later writer (Epic 5's
/// `cluster_curation_changed`) will produce. Structurally there is no
/// write path here: a pure function over passed-in records, so no
/// observation can exist in this build and the default is all-active by
/// construction.
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
/// `fondo`. A weekly entry's zone is guaranteed by [parseCatalogue]; a
/// hand-built entry without one fails fast here, named — never a bare
/// null dereference — mirroring `walkLog`'s duplicate-id discipline.
CurationCluster curationClusterOfEntry(CatalogueEntry entry) =>
    switch (entry.cadence) {
      Cadence.daily =>
        entry.size == Size.instant
            ? CurationCluster.anclas
            : CurationCluster.sosten,
      Cadence.weekly => curationClusterOfZone(_weeklyZoneOf(entry)),
      Cadence.seasonal => CurationCluster.fondo,
    };

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
  final newestEffectiveByCluster = <CurationCluster, CurationObservation>{};
  for (final observation in observations) {
    if (!_observationIsEffective(calendar, observation, instantUtcMicros)) {
      continue;
    }
    final newest = newestEffectiveByCluster[observation.cluster];
    if (newest == null ||
        observation.instantUtcMicros >= newest.instantUtcMicros) {
      newestEffectiveByCluster[observation.cluster] = observation;
    }
  }
  return {
    for (final cluster in allCurationClusters)
      if (newestEffectiveByCluster[cluster]?.enabled ?? true) cluster,
  };
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

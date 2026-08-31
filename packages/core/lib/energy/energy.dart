/// The day-scoped energy rule (AD-4): the live pool's energy is the last
/// observation of the current domestic day, defaulting to 🟢 — derived,
/// never written.
///
/// This file holds the derivation and the one seam the shell-wide read
/// passes through: `deriveLivePoolEnergy` maps stored `energy_set` rows
/// into observations and hands them here. Structurally there is no write
/// path to forbid: this is a pure function with no store access, so no
/// synthetic `energy_set` row can exist at a boundary and yesterday's
/// level is never carried across one.

library;

import 'package:core/day/calendar.dart';
import 'package:core/log/log_entry.dart';

/// The three energy levels (FR-4): semantic names only — the Spanish copy
/// is the ARB table's concern (Story 2.5), never this vocabulary's.
enum EnergyLevel {
  /// 🟢 — the default at every day boundary.
  full,

  /// 🟡
  medium,

  /// 🔴 — narrows the live pool for the rest of the domestic day.
  low,
}

/// The stable `energy_level` wire ints (Story 2.5, AD-23): 0/1/2 for
/// full/medium/low — the column's whole vocabulary, pinned by test so
/// the enum's declaration order can never drift past the stored rows.
int energyLevelWireOf(EnergyLevel level) => level.index;

/// The level a stored `energy_level` int names, or absent when the int
/// falls outside the stable mapping — the read boundary's quiet
/// tolerance (AD-23): the row is excluded and the day derives
/// unanswered, never repaired.
EnergyLevel? energyLevelOfWire(int? value) {
  if (value == null || value < 0 || value >= EnergyLevel.values.length) {
    return null;
  }
  return EnergyLevel.values[value];
}

/// One energy observation as inert data: the level, the instant it was
/// set, and the local offset in force when it was written (AD-4). Each
/// observation is scoped to a day in its own stored frame — exactly like
/// a log entry, because that is what it will be mapped from (Story 2.5).
typedef EnergyObservation = ({
  EnergyLevel level,
  int instantUtcMicros,
  int offsetSeconds,
});

/// The live pool's energy (AD-4): the last observation of the current
/// domestic day — the day of [instantUtcMicros] computed in the frame of
/// [offsetSeconds], each observation scoped by its own stored offset —
/// defaulting to [EnergyLevel.full] when the day holds none.
///
/// Day-scoped, not session-scoped: a day boundary never carries the
/// previous day's level forward, and opening a new pocket the same
/// evening never resets it to [EnergyLevel.full] — only a new
/// observation or the day boundary changes the derived level.
/// (Retrospective per-session predicates are AD-24's, not this
/// function's.)
///
/// Ties: two observations at the exact same microsecond resolve
/// deterministically to the later-in-input one — input order breaks
/// exact-instant ties only.
EnergyLevel deriveEnergyForLivePool(
  Iterable<EnergyObservation> observations,
  int instantUtcMicros,
  int offsetSeconds,
) {
  const calendar = Calendar();
  final today = calendar.dayOf(instantUtcMicros, offsetSeconds);
  var newestMicros = 0;
  EnergyLevel? newest;
  for (final observation in observations) {
    if (calendar.dayOf(
          observation.instantUtcMicros,
          observation.offsetSeconds,
        ) !=
        today) {
      continue;
    }
    if (newest == null || observation.instantUtcMicros >= newestMicros) {
      newest = observation.level;
      newestMicros = observation.instantUtcMicros;
    }
  }
  return newest ?? EnergyLevel.full;
}

/// The live pool's energy as this build derives it at one instant
/// (Story 2.5's seam): [deriveEnergyForLivePool] over the observations
/// the handed-in log's `energy_set` rows map to — each in its own
/// stored offset, a corrupt row already excluded at the read boundary
/// — so a log with none for today still defaults to 🟢 (AD-4). The
/// mapping lives HERE, at this one seam — never at each caller, where
/// the default would have to change in lockstep.
EnergyLevel deriveLivePoolEnergy(
  List<LogEntry> entries,
  int instantUtcMicros,
  int offsetSeconds,
) => deriveEnergyForLivePool(
  [
    for (final entry in entries)
      if (entry is EnergySetEntry)
        (
          level: entry.level,
          instantUtcMicros: entry.instantUtcMicros,
          offsetSeconds: entry.offsetSeconds,
        ),
  ],
  instantUtcMicros,
  offsetSeconds,
);

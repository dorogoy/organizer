/// The day-scoped energy rule (AD-4): the live pool's energy is the last
/// observation of the current domestic day, defaulting to 🟢 — derived,
/// never written.
///
/// This file holds only the derivation. The `energy_set` log kind, its
/// storage, the port DTO growth and the check-in writer are Story 2.5's;
/// when they land, 2.5 maps stored entries to [EnergyObservation] records
/// and hands them here. Structurally there is no write path to forbid:
/// this is a pure function with no store access, so no synthetic
/// `energy_set` row can exist at a boundary and yesterday's level is
/// never carried across one.

library;

import 'package:core/day/calendar.dart';

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

/// The live pool's energy as this build can derive it at one instant:
/// [deriveEnergyForLivePool] over the observations this build can
/// produce — none yet, so the day defaults to 🟢 (AD-4). Story 2.5 maps
/// stored `energy_set` rows into observations HERE, at this one seam —
/// never at each caller, where the default would have to change in
/// lockstep.
EnergyLevel deriveLivePoolEnergy(int instantUtcMicros, int offsetSeconds) =>
    deriveEnergyForLivePool(const [], instantUtcMicros, offsetSeconds);

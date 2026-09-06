/// The Cámara entry's visibility derivation (Story 5.2, FR-16, AD-17,
/// AD-21): whether the Dispenser's Cámara entry may render — a fact
/// derived from the log alone, never stored, and never probed. One
/// definition, entry types only: the pass reads `SettingEntry` and
/// `PermissionRefusedEntry` rows and nothing else, so no kind
/// constant, no payload column and no shell state can move the answer.
///
/// The fold is `enabled ∧ (no camera refusal row ∨ an enabled-write
/// later than the last refusal row)`:
///
/// - **Enabled** is the `camera_enabled` setting's own derivation
///   (`core/settings/settings.dart`), defaulting to enabled — the
///   toggle is the one way to remove the entry outright.
/// - **No active refusal** composes with `permissionMayBeAsked`'s
///   one-way rule (AD-17's never-ask-again) but recovers through the
///   toggle: any `camera_enabled` write landing after the last camera
///   refusal row re-arms the entry — the Settings row is the
///   reactivation, so UX line 159's "reversible only in Settings"
///   holds literally. The OS permission itself is requested again only
///   at the next first use (the next attempt), never by this fold.
///
/// There is deliberately **no probe** here, by construction: the
/// microphone recovers visibility by probing its channel on resume —
/// free, because a channel status query asks nothing — but the camera
/// plugin's only status check *is* the request (`initialize()`), so an
/// active probe at render time would ask at app entry (AD-17, NFR8).
/// Visibility is therefore log-derived, and an OS-side revocation of a
/// grant is discovered only at the next attempt — where it appends its
/// refusal row and the entry disappears on the next read. A read that
/// writes nothing (AD-3), recomputed from the entries alone.

library;

import 'package:core/log/log_entry.dart';
import 'package:core/settings/settings.dart';

/// Whether the Cámara entry may render (Story 5.2, FR-16): enabled ∧
/// (no camera refusal row ∨ a `camera_enabled` write later than the
/// last refusal row). Pure over the log, writing nothing (AD-3); rows
/// Whether a camera refusal row stands against the entry (Story 5.2,
/// FR-16): a `permission_refused{camera}` row exists with **no**
/// `camera_enabled` write landing after it in store read order. This
/// is the ONE definition of the standing refusal — the entry fold's
/// refusal half and the Settings reactivation premise both read it,
/// so the two surfaces can never disagree: wherever the row stands
/// the entry is absent and the reactivation affordance has something
/// to reactivate, and the toggle's write (the reactivation) clears
/// both at once.
///
/// Pure over the log, writing nothing (AD-3); rows whose payloads
/// this build cannot read never reached the entries (the read
/// boundary excluded them, AD-23), so they move the answer not at
/// all.
bool cameraRefusalStanding(List<LogEntry> entries) {
  var standing = false;
  for (final entry in entries) {
    if (entry is PermissionRefusedEntry &&
        entry.permission == Permission.camera) {
      standing = true;
    } else if (entry is SettingEntry &&
        entry.key == cameraEnabledSettingKey &&
        (entry.value == 0 || entry.value == 1)) {
      // An enabled-write later than the last refusal row re-arms the
      // entry: the toggle is the reactivation. A disable write clears
      // the standing refusal too, but the enabled half of the entry
      // fold keeps the entry absent — the two halves compose, never
      // conflict.
      standing = false;
    }
  }
  return standing;
}

/// Whether the Cámara entry may render (Story 5.2, FR-16): enabled ∧
/// no standing camera refusal — [cameraRefusalStanding] composed with
/// the enabled derivation, the one shared definition behind both the
/// entry's visibility and the Settings reactivation premise.
bool cameraEntryVisible(List<LogEntry> entries) {
  return deriveCameraEnabled(entries) && !cameraRefusalStanding(entries);
}

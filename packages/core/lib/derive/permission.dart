/// The permission derivation (Story 3.4, FR-32, AD-17, AD-21):
/// whether the app may still show the system's permission dialog for
/// one of the three runtime permissions — false exactly when the log
/// holds a `permission_refused` row naming it. One definition, entry
/// types only: the pass reads `PermissionRefusedEntry` rows and
/// nothing else, so no kind constant, no payload column and no shell
/// state can move the answer.
///
/// This is `core/derive`'s sibling to the warm return, on the same
/// precedent (AD-6's stated crossing for derived state): a fact the
/// shell renders as an affordance's visibility, never a
/// signal-as-work, and a read that writes nothing (AD-3). It is one
/// of AD-21's three stated reader exceptions — the system events are
/// excluded from every user-facing derivation except this one, the
/// warm return's opening anchor, and the validator surface's export
/// state.
///
/// The fact is deliberately one-way (AD-17's never-ask-again): after
/// a refusal the entry stands forever and `permissionMayBeAsked`
/// stays false — visibility recovers through the probe's own granted
/// bit alone (a system re-grant), never through the log, so the app
/// never shows the system dialog twice but a system re-grant fully
/// restores the feature. No cache exists anywhere beside the log:
/// the predicate recomputes from the entries alone at every read.

library;

import 'package:core/log/log_entry.dart';

/// Whether the system dialog may still be requested for [permission]
/// (Story 3.4, FR-32, AD-17): false exactly when the log holds a
/// `permission_refused` row naming it — one definition, entry types
/// only. Pure over the log, writing nothing (AD-3): a row whose
/// permission payload this build cannot read never reached the
/// entries (the read boundary excluded it, AD-23), so it moves the
/// answer not at all.
bool permissionMayBeAsked(List<LogEntry> entries, Permission permission) {
  for (final entry in entries) {
    if (entry is PermissionRefusedEntry && entry.permission == permission) {
      return false;
    }
  }
  return true;
}

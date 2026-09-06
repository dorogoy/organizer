// The camera shell facade (Story 5.2, FR-16, FR-25, AD-17; amended by
// the 2026-09-05 ruling 1-B): the shell's own seam over the
// spine-pinned `camera` plugin — the only door the scan path has onto
// a camera, and the only place in `lib/` the plugin is importable
// (the adapter in this directory wraps it; nothing past this
// directory may import `package:camera/`).
//
// The first-use permission moment is **ours** — the hand-written
// `camera` channel beside this interface (DictateChannel's pattern,
// the spine's fourth channel) asks CAMERA at the explicit scan
// attempt, never at app entry, never during first run (AD-17,
// NFR8), and separates the two domains the plugin folds together:
//
//  - `granted` — a grant stood (the channel fast-paths it) or the
//    dialog granted, and the plugin initialized: the preview runs.
//  - `denied` — the user's explicit denial, or a denial discovered
//    after an OS-level revocation of a grant (the plugin's own
//    initialize throwing its access-denied error after the channel
//    said granted — the ask and the open are not one instant). App
//    logic: exactly one `permission_refused{camera}` row, the
//    surface closes, the entry is absent on the next render.
//  - `interrupted` — the system swallowed the ask (empty grants: no
//    answer existed). A functioning problem, not a refusal: no row,
//    the entry stays, and the scan surface states the problem.
//  - `unavailable` — no camera hardware, or a device error at
//    initialize. The same honest problem notice on the surface: no
//    rows, the entry remains (the permission was never refused).
//
// The ruling's line runs through all four: the spec governs user–app
// logic; system malfunctions are *communicated*, never hidden and
// never mistaken for the user's choice — `interrupted` and
// `unavailable` are the surface's to state, `denied` alone is the
// log's to record.
//
// The preview is a widget the facade builds — the plugin's controller
// never crosses this seam, so no caller can reach past the wrap.

library;

import 'package:flutter/widgets.dart';

/// One open's outcome, the ruling's two domains made explicit:
/// granted/denied are the user's answers (app logic — the latter the
/// one the log records); interrupted/unavailable are system problems
/// (the surface's notice, never a row).
enum CameraOpenOutcome {
  /// The permission stands and the camera initialized: the preview
  /// runs and the shutter shoots.
  granted,

  /// The permission was denied — the dialog's explicit refusal, or a
  /// system-level revocation read identically at the attempt. Exactly
  /// one `permission_refused{camera}` row is appended through the
  /// core minter and the Cámara entry is absent on the next render.
  denied,

  /// The ask was swallowed by the system (empty grants — no answer
  /// existed; the dialog interrupted, the activity gone, a superseded
  /// ask). A functioning problem, not a refusal: nothing is appended,
  /// the entry stays, the scan surface communicates the problem, and
  /// a next tap asks again.
  interrupted,

  /// No camera hardware, or the device errored at initialize. The
  /// same honest problem notice on the surface: nothing is appended,
  /// the entry remains — the permission was never refused (the
  /// declared corner: every target device ships a camera).
  unavailable,
}

/// One shutter's outcome: captured bytes, no frame, or a lost
/// grant at the shot — the last is a system problem (ruling 1-B),
/// never a user refusal and never a quiet close that reads as a
/// taken photo.
sealed class CameraShotOutcome {
  const CameraShotOutcome();
}

/// The JPEG bytes of a captured frame.
final class CameraShotCaptured extends CameraShotOutcome {
  const CameraShotCaptured(this.bytes);
  final List<int> bytes;
}

/// The shot failed for a reason that is not a lost grant — the
/// caller's fail-closed quiet close (a detector error's sibling).
final class CameraShotNone extends CameraShotOutcome {
  const CameraShotNone();
}

/// The grant was gone at the shutter (`CameraAccessDenied` after a
/// granted open). A functioning problem: the scan surface
/// communicates (`scanOpenFailed`), no `permission_refused` row, the
/// Cámara entry stays — a photo that was not taken is never presented
/// as one that was.
final class CameraShotAccessLost extends CameraShotOutcome {
  const CameraShotAccessLost();
}

/// The camera seam (Story 5.2): the first-use permission moment, the
/// shot, the preview and the teardown. The plugin implementation
/// lives beside this interface; tests fake it. No availability probe
/// exists — the plugin's only status check is the request itself, and
/// the open's own `unavailable` outcome carries the no-hardware case.
abstract interface class CameraShell {
  /// Opens the camera for a scan: the first-use moment — the
  /// permission is asked through the `camera` channel here, at the
  /// explicit scan attempt, never at app entry, and only then does
  /// the plugin initialize (with the grant in hand, it never asks
  /// again). Exactly one of the four outcomes answers — the
  /// `unavailable` one carries no camera hardware and device errors
  /// alike — and the caller owns the row, the close and the notice.
  Future<CameraOpenOutcome> open();

  /// Shoots the standing frame. Only valid after a granted [open]
  /// and before [dispose].
  Future<CameraShotOutcome> takePicture();

  /// The preview widget for a granted open — the plugin's own preview
  /// wrapped, never its controller. Before a granted open this is the
  /// empty box.
  Widget buildPreview();

  /// Disposes the camera. Idempotent: the surface's every exit path
  /// may call it.
  Future<void> dispose();
}

// The `camera` plugin adapter (Story 5.2, FR-16, FR-25; amended by
// the 2026-09-05 ruling 1-B): the CameraShell's platform half over
// the spine-pinned first-party plugin — the only file in the build
// that imports `package:camera/camera.dart` (the wrap the facade's
// doc declares; `tool/check_egress_imports.dart`'s seal is untouched
// by it, the plugin being no HTTP client).
//
// The permission moment is NOT the plugin's: `open()` asks through
// the hand-written `camera` channel FIRST (fast-pathing an existing
// grant; separating an interrupted ask from an explicit denial — the
// domains the plugin folds together), and only on a grant does the
// plugin initialize, which then never asks: its own permission
// check finds the grant standing. If the plugin still reports its
// access-denied error after a granted ask, the grant was revoked in
// the instant between the two — the revocation-discovered denial,
// read identically to the explicit one (FR-16). No heuristic, no
// `shouldShowRationale`, no second ask.
//
// Privacy: the shot's bytes cross into the app's own cache through
// the Files port, and the plugin-written file — a person-bearing
// frame included — is deleted in the same breath, best-effort:
// nothing this story ships sweeps the plugin's cache, so the adapter
// leaves nothing there to sweep.
import 'package:camera/camera.dart';
import 'package:flutter/widgets.dart';

import '../../files/app_files.dart';
import 'camera_channel.dart';
import 'camera_shell.dart';

/// The plugin's denial wire code (camera_android_camerax's
/// `CameraPermissionsManager.CAMERA_ACCESS_DENIED`) — an
/// infrastructure identifier mirrored from the plugin's Kotlin half,
/// never widget copy. After a granted ask this reads as the
/// revocation-discovered denial; the permission ask itself never
/// reaches the plugin.
const String cameraAccessDeniedWire = 'CameraAccessDenied';

/// Maps a plugin initialize error code to the open outcome (ruling
/// 1-B's domains, read off the plugin's own vocabulary): the denial
/// code alone is the app-logic domain — after a granted ask it can
/// only mean the grant was revoked in the instant between the ask and
/// the open — and every other code is a device problem for the
/// surface's notice, never a row.
CameraOpenOutcome cameraOpenOutcomeOfPluginError(String? code) =>
    code == cameraAccessDeniedWire
    ? CameraOpenOutcome.denied
    : CameraOpenOutcome.unavailable;

/// The CameraShell over the spine-pinned `camera` plugin (Story 5.2).
/// One standing controller per open; every method is quiet on failure
/// exactly where the facade's contract demands it.
class PluginCameraShell implements CameraShell {
  PluginCameraShell({
    CameraPermissionsChannel? permissionChannel,
    this.availableCamerasOf,
    this.initializeOf,
  }) : permissionChannel = permissionChannel ?? const CameraChannel();

  /// The permission moment's seam (ruling 1-B): the hand-written
  /// `camera` channel, injectable for the shell's own tests.
  final CameraPermissionsChannel permissionChannel;

  /// Test seam: replaces `availableCameras()`. Production leaves this
  /// null so the plugin's own listing runs.
  final Future<List<CameraDescription>> Function()? availableCamerasOf;

  /// Test seam: replaces `CameraController.initialize()`. Production
  /// leaves this null. A thrown error is mapped like a real
  /// initialize failure — the catch this story's revocation path
  /// actually runs.
  final Future<void> Function(CameraController controller)? initializeOf;

  CameraController? _controller;

  @override
  Future<CameraOpenOutcome> open() async {
    await dispose();
    // The permission moment is ours, before anything the plugin owns:
    // the channel fast-paths a standing grant, asks otherwise, and
    // separates an interrupted ask (the system swallowed it — empty
    // grants) from an explicit denial. Only the denial reaches the
    // log; only the interruption and the device problems reach the
    // surface's notice.
    switch (await _askPermission()) {
      case CameraPermissionAnswer.refused:
        return CameraOpenOutcome.denied;
      case CameraPermissionAnswer.interrupted:
        return CameraOpenOutcome.interrupted;
      case CameraPermissionAnswer.granted:
        break;
    }
    final List<CameraDescription> cameras;
    try {
      cameras = await (availableCamerasOf ?? availableCameras)();
    } on Object {
      return CameraOpenOutcome.unavailable;
    }
    if (cameras.isEmpty) {
      // No camera hardware: the declared corner, carried by this
      // outcome alone — the notice on the surface, no row, the entry
      // remains.
      return CameraOpenOutcome.unavailable;
    }
    // The back camera is the scan surface's eye; a device with only
    // front-facing cameras still scans — the first description is the
    // plugin's own order and the fallback both.
    final back = cameras.where((camera) {
      return camera.lensDirection == CameraLensDirection.back;
    });
    final description = back.isNotEmpty ? back.first : cameras.first;
    final controller = CameraController(
      description,
      // The scan's payload is detail (the space the Slicer reads);
      // the plugin falls back to the next highest resolution a
      // device cannot offer the preset at. Audio never records.
      ResolutionPreset.max,
      enableAudio: false,
    );
    try {
      await (initializeOf ?? (CameraController c) => c.initialize())(
        controller,
      );
    } on Object catch (error) {
      // The failed controller goes out here whatever its error — a
      // disposal that itself throws must not replace the outcome
      // (the same quiet guard the standing dispose holds).
      await _disposeQuietly(controller);
      return cameraOpenOutcomeOfPluginError(
        error is CameraException ? error.code : null,
      );
    }
    _controller = controller;
    return CameraOpenOutcome.granted;
  }

  /// The channel ask, folding its own failure into the device-problem
  /// domain: a channel that cannot answer (the platform absent, a
  /// malformed wire word) is a malfunction to communicate, never a
  /// refusal the log would have to record.
  Future<CameraPermissionAnswer> _askPermission() async {
    try {
      return await permissionChannel.request();
    } on Object {
      return CameraPermissionAnswer.interrupted;
    }
  }

  @override
  Future<CameraShotOutcome> takePicture() async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) {
      return const CameraShotNone();
    }
    XFile? file;
    try {
      file = await controller.takePicture();
      // The bytes cross into the app's own cache through the Files
      // port; the plugin-written file dies in the same breath — the
      // files module's best-effort deletion, run on a failed read too
      // (the finally): no shot, a person-bearing frame included,
      // lingers in the plugin's cache dir, which nothing this story
      // ships sweeps. The finally is on this try so a throw after
      // takePicture returns still deletes.
      return CameraShotCaptured(await file.readAsBytes());
    } on CameraException catch (error) {
      if (error.code == cameraAccessDeniedWire) {
        return const CameraShotAccessLost();
      }
      return const CameraShotNone();
    } on Object {
      // A failed shot that is not a lost grant: no frame exists to
      // gate, and the caller's fail-closed close takes the scan out.
      return const CameraShotNone();
    } finally {
      final path = file?.path;
      if (path != null) {
        await deleteFileBestEffort(path);
      }
    }
  }

  @override
  Widget buildPreview() {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) {
      return const SizedBox.shrink();
    }
    return CameraPreview(controller);
  }

  @override
  Future<void> dispose() async {
    final controller = _controller;
    _controller = null;
    if (controller != null) {
      await _disposeQuietly(controller);
    }
  }

  /// Disposes one controller, quietly by contract: disposal's whole
  /// duty is that nothing follows, and a controller that errored on
  /// its way out is gone all the same.
  static Future<void> _disposeQuietly(CameraController controller) async {
    try {
      await controller.dispose();
    } on Object {
      // Quiet: see the doc — the outcome the caller answers with is
      // never disposal's to replace.
    }
  }
}

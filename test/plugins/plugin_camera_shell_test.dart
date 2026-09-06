// The plugin shell's channel-first ordering (Story 5.2, ruling 1-B):
// the permission moment belongs to the hand-written `camera` channel
// and precedes everything the plugin owns — a refusal and an
// interruption answer without any plugin call at all, and only a
// grant proceeds to the plugin's open (which, in this test
// environment, has no platform behind it and folds into the honest
// device-problem outcome — proving the ask ran first and the fold is
// quiet). The plugin's error-code→outcome mapping is pinned to an
// independent raw literal, so a plugin upgrade renaming its denial
// code fails here loudly instead of silently remapping.
import 'package:camera/camera.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:organizer/plugins/camera/camera_channel.dart';
import 'package:organizer/plugins/camera/camera_shell.dart';
import 'package:organizer/plugins/camera/plugin_camera_shell.dart';

/// The channel fake: the answers the tests steer, the asks the tests
/// count.
class _FakeChannel implements CameraPermissionsChannel {
  _FakeChannel(this.answer);

  Object? answer; // CameraPermissionAnswer | Exception
  int asks = 0;

  @override
  Future<CameraPermissionAnswer> request() async {
    asks++;
    final answer = this.answer;
    if (answer is CameraPermissionAnswer) {
      return answer;
    }
    throw answer!;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('the denial wire code is pinned to an independent raw literal — '
      'a plugin upgrade renaming it fails loudly, never silently remaps', () {
    expect(cameraAccessDeniedWire, 'CameraAccessDenied');
  });

  test('the plugin error code maps by the ruling\'s domains: the denial '
      'code alone is denied (the revocation-discovered denial after a '
      'granted ask); every other code is a device problem for the '
      'surface\'s notice, never a row', () {
    expect(
      cameraOpenOutcomeOfPluginError(cameraAccessDeniedWire),
      CameraOpenOutcome.denied,
    );
    expect(
      cameraOpenOutcomeOfPluginError('CameraAccessDenied'),
      CameraOpenOutcome.denied,
    );
    expect(
      cameraOpenOutcomeOfPluginError('cameraPermissionsRequestOngoing'),
      CameraOpenOutcome.unavailable,
    );
    expect(
      cameraOpenOutcomeOfPluginError('SomeDeviceError'),
      CameraOpenOutcome.unavailable,
    );
    // A non-plugin error carries no code at all: the same device-
    // problem domain, never a row.
    expect(cameraOpenOutcomeOfPluginError(null), CameraOpenOutcome.unavailable);
  });

  test('a refused ask answers denied without any plugin call — the '
      'app-logic domain never reaches the capture dependency', () async {
    final channel = _FakeChannel(CameraPermissionAnswer.refused);
    final shell = PluginCameraShell(permissionChannel: channel);
    expect(await shell.open(), CameraOpenOutcome.denied);
    expect(channel.asks, 1);
    // No controller stands: the preview is the empty box and a shot
    // has nothing to read.
    expect(shell.buildPreview(), isA<SizedBox>());
    expect(await shell.takePicture(), isA<CameraShotNone>());
  });

  test('an interrupted ask answers interrupted without any plugin call — '
      'the system-swallowed ask is its own outcome, never a refusal', () async {
    final channel = _FakeChannel(CameraPermissionAnswer.interrupted);
    final shell = PluginCameraShell(permissionChannel: channel);
    expect(await shell.open(), CameraOpenOutcome.interrupted);
    expect(channel.asks, 1);
    expect(await shell.takePicture(), isA<CameraShotNone>());
  });

  test('a channel that cannot answer folds into the interruption — a '
      'malfunction is never recorded as a refusal', () async {
    final channel = _FakeChannel(StateError('channel gone'));
    final shell = PluginCameraShell(permissionChannel: channel);
    expect(await shell.open(), CameraOpenOutcome.interrupted);
    expect(channel.asks, 1);
  });

  test('a granted ask proceeds to the plugin open — in this environment '
      'no platform stands behind the plugin, and the device problem '
      'folds quietly, the ask already behind it', () async {
    final channel = _FakeChannel(CameraPermissionAnswer.granted);
    final shell = PluginCameraShell(permissionChannel: channel);
    expect(await shell.open(), CameraOpenOutcome.unavailable);
    expect(
      channel.asks,
      1,
      reason: 'the permission moment ran first, before any plugin call',
    );
  });

  test('a granted ask whose initialize throws CameraAccessDenied is '
      'denied — the revocation-discovered denial at the only site that '
      'talks to the plugin', () async {
    final channel = _FakeChannel(CameraPermissionAnswer.granted);
    final shell = PluginCameraShell(
      permissionChannel: channel,
      availableCamerasOf: () async => [
        const CameraDescription(
          name: '0',
          lensDirection: CameraLensDirection.back,
          sensorOrientation: 90,
        ),
      ],
      initializeOf: (_) async {
        throw CameraException(cameraAccessDeniedWire, 'revoked');
      },
    );
    expect(await shell.open(), CameraOpenOutcome.denied);
    expect(channel.asks, 1);
    expect(await shell.takePicture(), isA<CameraShotNone>());
  });

  test('a granted ask whose initialize throws any other code is '
      'unavailable — a device problem, never a row', () async {
    final channel = _FakeChannel(CameraPermissionAnswer.granted);
    final shell = PluginCameraShell(
      permissionChannel: channel,
      availableCamerasOf: () async => [
        const CameraDescription(
          name: '0',
          lensDirection: CameraLensDirection.back,
          sensorOrientation: 90,
        ),
      ],
      initializeOf: (_) async {
        throw CameraException('SomeDeviceError', 'broken');
      },
    );
    expect(await shell.open(), CameraOpenOutcome.unavailable);
    expect(channel.asks, 1);
  });
}

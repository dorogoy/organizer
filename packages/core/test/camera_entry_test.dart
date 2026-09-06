import 'package:core/derive/camera_entry.dart';
import 'package:core/log/log_entry.dart';
import 'package:core/settings/settings.dart';
import 'package:test/test.dart';

/// A `setting_changed` {camera_enabled, [value]} row, at its own
/// instant.
SettingEntry _cameraSetting(int value, int instant) => SettingEntry(
  id: '0190cccc-0000-7000-8000-$instant',
  instantUtcMicros: instant,
  offsetSeconds: 0,
  key: cameraEnabledSettingKey,
  value: value,
);

/// A `permission_refused` {camera} row, at its own instant.
PermissionRefusedEntry _cameraRefusal(int instant) => PermissionRefusedEntry(
  id: '0190cccc-0000-7000-8000-r$instant',
  instantUtcMicros: instant,
  offsetSeconds: 0,
  permission: Permission.camera,
);

/// An unrelated setting row — the fold reads its key alone.
SettingEntry _bagSetting(int instant) => SettingEntry(
  id: '0190cccc-0000-7000-8000-b$instant',
  instantUtcMicros: instant,
  offsetSeconds: 0,
  key: timeBagSettingKey,
  value: 20,
);

/// An out-of-range camera_enabled row — tolerance, never repair
/// (AD-23): the row stays, the fold skips it.
SettingEntry _corruptCameraSetting(int value, int instant) => SettingEntry(
  id: '0190cccc-0000-7000-8000-x$instant',
  instantUtcMicros: instant,
  offsetSeconds: 0,
  key: cameraEnabledSettingKey,
  value: value,
);

/// A microphone refusal — the fold's permission half is camera-scoped.
PermissionRefusedEntry _micRefusal(int instant) => PermissionRefusedEntry(
  id: '0190cccc-0000-7000-8000-m$instant',
  instantUtcMicros: instant,
  offsetSeconds: 0,
  permission: Permission.microphone,
);

void main() {
  group('the Cámara entry visibility fold (Story 5.2, FR-16)', () {
    test('the default state is visible: enabled, no refusal rows', () {
      expect(cameraEntryVisible(const []), isTrue);
      // The fold ignores everything it does not read.
      expect(
        cameraEntryVisible([_bagSetting(10), _micRefusal(20)]),
        isTrue,
        reason: 'a microphone refusal and a bag row move nothing',
      );
    });

    test('a camera refusal row makes the entry absent — the one-way '
        'rule, log-derived (AD-17)', () {
      expect(cameraEntryVisible([_cameraRefusal(30)]), isFalse);
      // Later unrelated rows do not restore it.
      expect(
        cameraEntryVisible([_cameraRefusal(30), _bagSetting(40)]),
        isFalse,
      );
    });

    test('a disable write makes the entry absent outright', () {
      expect(cameraEntryVisible([_cameraSetting(0, 50)]), isFalse);
    });

    test('an enabled-write after the refusal re-arms the entry — the '
        'toggle is the reactivation (UX-DR33)', () {
      expect(
        cameraEntryVisible([_cameraRefusal(30), _cameraSetting(1, 60)]),
        isTrue,
      );
      // Even a disable-then-enable pair after the refusal restores:
      // the last enabled-write is what stands after the last refusal.
      expect(
        cameraEntryVisible([
          _cameraRefusal(30),
          _cameraSetting(0, 40),
          _cameraSetting(1, 50),
        ]),
        isTrue,
      );
      // A disable write after the refusal clears the standing refusal
      // but the enabled half keeps the entry absent: two halves, one
      // answer.
      expect(
        cameraEntryVisible([_cameraRefusal(30), _cameraSetting(0, 60)]),
        isFalse,
      );
    });

    test('a refusal after the re-enable hides the entry again — the '
        'next attempt\'s refusal stands until the next toggle', () {
      expect(
        cameraEntryVisible([
          _cameraRefusal(10),
          _cameraSetting(1, 20),
          _cameraRefusal(30),
        ]),
        isFalse,
      );
    });

    test('an out-of-range camera_enabled row is skipped — tolerance, '
        'never repair (AD-23)', () {
      // A corrupt value does not disable and does not re-arm.
      expect(cameraEntryVisible([_corruptCameraSetting(7, 10)]), isTrue);
      expect(
        cameraEntryVisible([_cameraRefusal(20), _corruptCameraSetting(7, 30)]),
        isFalse,
        reason: 'a corrupt row is not an enabled-write',
      );
    });

    test('the entry fold and the reactivation premise agree on ONE '
        'definition: visible ⟺ enabled ∧ ¬standing, and the premise '
        'reads standing alone — the two surfaces can never disagree '
        '(the Settings row and the entry clear and re-arm together)', () {
      for (final entries in [
        <LogEntry>[],
        [_bagSetting(10)],
        [_cameraRefusal(30)],
        [_cameraRefusal(30), _bagSetting(40)],
        [_cameraSetting(0, 50)],
        [_cameraRefusal(30), _cameraSetting(1, 60)],
        [_cameraSetting(1, 10), _cameraRefusal(30)],
        [_micRefusal(20)],
      ]) {
        expect(
          cameraEntryVisible(entries),
          deriveCameraEnabled(entries) && !cameraRefusalStanding(entries),
          reason:
              'the fold is exactly the composition over ${entries.length} rows',
        );
      }
      // The agreement cases that matter: after the toggle
      // reactivation the entry is back AND the premise is gone; after
      // a refusal the entry is absent AND the premise stands.
      final reactivated = [_cameraRefusal(30), _cameraSetting(1, 60)];
      expect(cameraEntryVisible(reactivated), isTrue);
      expect(
        cameraRefusalStanding(reactivated),
        isFalse,
        reason: 'the reactivation affordance retired with the toggle',
      );
      final refused = [_cameraRefusal(30)];
      expect(cameraEntryVisible(refused), isFalse);
      expect(cameraRefusalStanding(refused), isTrue);
      // And a disable after the refusal: the entry absent (the
      // enabled half), the premise gone (the toggle answered) — the
      // row has nothing left to reactivate while the camera is off.
      final disabled = [_cameraRefusal(30), _cameraSetting(0, 60)];
      expect(cameraEntryVisible(disabled), isFalse);
      expect(cameraRefusalStanding(disabled), isFalse);
    });

    test('read order decides, not the instant: store order is the '
        'input (AD-3)', () {
      // The refusal row lands after the toggle in store read order
      // even at an earlier instant: the fold reads order alone.
      expect(
        cameraEntryVisible([_cameraSetting(1, 100), _cameraRefusal(30)]),
        isFalse,
      );
    });
  });

  group('the camera-enabled derivation (Story 5.2, FR-16, AD-1)', () {
    test('defaults to enabled', () {
      expect(deriveCameraEnabled(const []), isTrue);
      expect(defaultCameraEnabled, isTrue);
    });

    test('the last valid row wins; invalid values are skipped '
        '(AD-23)', () {
      expect(deriveCameraEnabled([_cameraSetting(0, 10)]), isFalse);
      expect(
        deriveCameraEnabled([_cameraSetting(0, 10), _cameraSetting(1, 20)]),
        isTrue,
      );
      expect(
        deriveCameraEnabled([_cameraSetting(1, 10), _cameraSetting(0, 20)]),
        isFalse,
      );
      expect(
        deriveCameraEnabled([
          _cameraSetting(1, 10),
          _corruptCameraSetting(5, 20),
        ]),
        isTrue,
        reason: 'the corrupt row derives as absent',
      );
      // Other settings are invisible to the pass.
      expect(deriveCameraEnabled([_bagSetting(10)]), isTrue);
    });
  });
}

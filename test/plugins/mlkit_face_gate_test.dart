// The face gate adapter's contract (Story 5.2, FR-25, P12): the ML
// Kit seam's whole decision table, driven through the plugin's own
// method channel over the mock binary messenger (the camera-channel
// adapter suite's pattern) — ≥ 1 face → FaceGateRefusal, 0 faces →
// FaceGatePass, an error on both attempts → throws (fail closed,
// never falsely refused), and the detector closed on every path. The
// branch is pinned from the platform's wire side: inverting it or
// failing open must fail this suite, not the user's privacy.
import 'package:core/ports/face_gate_port.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:organizer/plugins/mlkit_face/mlkit_face_gate.dart';

const MethodChannel _channel = MethodChannel('google_mlkit_face_detector');

/// A face map the plugin's `Face.fromJson` accepts: the bounding rect
/// and the landmarks key its parser dereferences.
Map<dynamic, dynamic> _faceJson() => {
  'rect': {'left': 10.0, 'top': 10.0, 'right': 60.0, 'bottom': 60.0},
  'landmarks': <String, dynamic>{},
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final calls = <MethodCall>[];
  Object? Function()? answer;

  setUp(() {
    calls.clear();
    answer = null;
    TestWidgetsFlutterBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_channel, (call) async {
          calls.add(call);
          return answer?.call();
        });
  });

  tearDown(() {
    TestWidgetsFlutterBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_channel, null);
  });

  test('a frame with one face is a refusal — the refusal is about the '
      'frame, on the platform\'s own wire (FR-25)', () async {
    answer = () => <dynamic>[_faceJson()];
    final outcome = await const MlKitFaceGate().gate('/cache/frame.jpg');
    expect(outcome, isA<FaceGateRefusal>());
  });

  test('a people-free frame passes — 0 faces on the wire', () async {
    answer = () => <dynamic>[];
    final outcome = await const MlKitFaceGate().gate('/cache/frame.jpg');
    expect(outcome, isA<FaceGatePass>());
  });

  test('a detector error past the retry throws — a failure is never a '
      'refusal and never a pass: fail closed, no fold either way', () async {
    var detectionErrors = 0;
    answer = () {
      if (calls.last.method == 'vision#startFaceDetector') {
        detectionErrors++;
      }
      throw PlatformException(code: 'detector-error');
    };
    await expectLater(
      const MlKitFaceGate().gate('/cache/frame.jpg'),
      throwsA(isA<PlatformException>()),
    );
    // Retry-once on error, exactly: two detection attempts, then the
    // failure travels (the probe's own discipline).
    expect(detectionErrors, 2);
  });

  test('a detector error then a clean answer is the retry landing: one '
      'error, then the verdict — the single retry is real', () async {
    var attempts = 0;
    answer = () {
      if (calls.last.method != 'vision#startFaceDetector') {
        return null;
      }
      attempts++;
      if (attempts == 1) {
        throw PlatformException(code: 'transient');
      }
      return <dynamic>[];
    };
    final outcome = await const MlKitFaceGate().gate('/cache/frame.jpg');
    expect(outcome, isA<FaceGatePass>());
    expect(attempts, 2);
  });

  test('the detector closes on every path — the finally holds for the '
      'pass, the refusal and the thrown error alike', () async {
    answer = () => <dynamic>[];
    await const MlKitFaceGate().gate('/cache/frame.jpg');
    answer = () => <dynamic>[_faceJson()];
    await const MlKitFaceGate().gate('/cache/frame.jpg');
    answer = () => throw PlatformException(code: 'detector-error');
    await expectLater(
      const MlKitFaceGate().gate('/cache/frame.jpg'),
      throwsA(isA<PlatformException>()),
    );
    final closeCalls = calls
        .where((call) => call.method == 'vision#closeFaceDetector')
        .toList();
    expect(closeCalls, hasLength(3));
  });

  test('the invocation is the measured one: the file-path input image '
      'crosses with the pinned interim options — accurate, the '
      'smallest face size, every feature off (BAR.md verbatim)', () async {
    answer = () => <dynamic>[];
    await const MlKitFaceGate().gate('/cache/scan_cache/x/frame.jpg');
    final start = calls
        .where((call) => call.method == 'vision#startFaceDetector')
        .single;
    final args = start.arguments as Map<dynamic, dynamic>;
    final options = args['options'] as Map<dynamic, dynamic>;
    expect(options['mode'], 'accurate');
    expect(options['minFaceSize'], 0.0);
    expect(options['enableClassification'], false);
    expect(options['enableLandmarks'], false);
    expect(options['enableContours'], false);
    expect(options['enableTracking'], false);
    final image = args['imageData'] as Map<dynamic, dynamic>;
    expect(image['path'], '/cache/scan_cache/x/frame.jpg');
  });
}

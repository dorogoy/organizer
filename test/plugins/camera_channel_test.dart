// The camera channel adapter's contract (Story 5.2, FR-16; the
// 2026-09-05 ruling 1-B): the wire-vocabulary mapping the platform
// half speaks — the ask's three answers into the ruling's two domains
// (granted/refused are the user's answers; interrupted is the
// system's swallowed ask, its own word, never folded into a refusal)
// — and a wire answer outside the protocol throwing rather than
// substituting. Exercised over the real adapter through the mock
// binary messenger (the dictate adapter suite's own pattern), with
// the channel's constants pinned to independent raw literals so both
// halves of the wire contract are locked to the protocol, not to
// each other's drift.
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:organizer/plugins/camera/camera_channel.dart';

const MethodChannel _channel = MethodChannel('dev.dorogoy.organizer/camera');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('the wire constants are pinned to the protocol, independently of '
      'the Kotlin half', () {
    expect(cameraChannelName, 'dev.dorogoy.organizer/camera');
    expect(cameraRequestMethod, 'request');
    expect(cameraGrantedWire, 'granted');
    expect(cameraRefusedWire, 'refused');
    expect(cameraInterruptedWire, 'interrupted');
  });

  testWidgets('the ask calls the one method with no arguments and maps '
      'the three wire answers to their domains', (tester) async {
    const adapter = CameraChannel();
    final calls = <MethodCall>[];
    Object? answer;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(_channel, (
      call,
    ) async {
      calls.add(call);
      return answer;
    });
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        _channel,
        null,
      ),
    );

    answer = cameraGrantedWire;
    expect(await adapter.request(), CameraPermissionAnswer.granted);
    answer = cameraRefusedWire;
    expect(await adapter.request(), CameraPermissionAnswer.refused);
    answer = cameraInterruptedWire;
    expect(await adapter.request(), CameraPermissionAnswer.interrupted);

    // The one question, asked plainly: the method name and nothing
    // else crosses (the Kotlin half owns the staging and the code).
    expect(calls, hasLength(3));
    for (final call in calls) {
      expect(call.method, 'request');
      expect(call.arguments, isNull);
    }
  });

  testWidgets('a wire answer outside the protocol throws — never a quiet '
      'substitution, and never a disguised refusal', (tester) async {
    const adapter = CameraChannel();
    Object? answer;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      _channel,
      (call) async => answer,
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        _channel,
        null,
      ),
    );

    answer = 'maybe';
    await expectLater(adapter.request(), throwsA(isA<FormatException>()));
    answer = null;
    await expectLater(adapter.request(), throwsA(isA<FormatException>()));
  });
}

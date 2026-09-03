// The dictate channel adapter's contract (Story 3.4, FR-32): the
// wire-vocabulary mapping the platform half speaks — probe and start
// answers into the port's enums (an answer outside the protocol is a
// format violation, never a quiet substitution), the outgoing method
// names and arguments, and the Kotlin→Dart `outcome` upcall, whose
// malformed payloads drop quietly. Exercised over the real adapter
// through the mock binary messenger (the dispenser suite's own
// pattern), because every other seam fakes `RecognizerPort` and the
// adapter itself would otherwise hold no test at all.

import 'package:core/ports/recognizer_port.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:organizer/platform/dictate/dictate_recognizer.dart';

const MethodChannel _channel = MethodChannel(dictateChannelName);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  /// Steers the platform's answers to Dart→platform calls, recording
  /// every call for the method-name and argument pins: the calls list
  /// and a setter for the standing answer.
  (List<MethodCall>, void Function(Object?)) mockAnswers(WidgetTester tester) {
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
    return (calls, (Object? value) => answer = value);
  }

  /// Delivers a platform→Dart method call to the adapter's registered
  /// handler, as the Kotlin half would.
  Future<void> deliver(WidgetTester tester, MethodCall call) {
    return tester.binding.defaultBinaryMessenger.handlePlatformMessage(
      dictateChannelName,
      const StandardMethodCodec().encodeMethodCall(call),
      (_) {},
    );
  }

  testWidgets('probe maps the three wire answers to the availability '
      'enum', (tester) async {
    final recognizer = DictateRecognizer();
    final (_, steer) = mockAnswers(tester);

    steer(dictateGrantedWire);
    expect(await recognizer.probe(), RecognizerAvailability.granted);
    steer(dictateAskableWire);
    expect(await recognizer.probe(), RecognizerAvailability.askable);
    steer(dictateUnavailableWire);
    expect(await recognizer.probe(), RecognizerAvailability.unavailable);
  });

  testWidgets('a probe answer outside the protocol throws — the caller '
      'absorbs it on its own quiet terms, never a silent substitution', (
    tester,
  ) async {
    final recognizer = DictateRecognizer();
    final (_, steer) = mockAnswers(tester);

    steer('maybe');
    await expectLater(recognizer.probe(), throwsA(isA<FormatException>()));
    steer(null);
    await expectLater(recognizer.probe(), throwsA(isA<FormatException>()));
  });

  testWidgets('start maps the three wire answers to the start enum', (
    tester,
  ) async {
    final recognizer = DictateRecognizer();
    final (_, steer) = mockAnswers(tester);

    steer(dictateListeningWire);
    expect(await recognizer.start(4), RecognizerStart.listening);
    steer(dictateRefusedWire);
    expect(await recognizer.start(5), RecognizerStart.refused);
    steer(dictateUnavailableWire);
    expect(await recognizer.start(6), RecognizerStart.unavailable);
    steer('thinking');
    await expectLater(recognizer.start(7), throwsA(isA<FormatException>()));
  });

  testWidgets('cancel and openAppSettings send the right method names '
      'and arguments', (tester) async {
    final recognizer = DictateRecognizer();
    final (calls, _) = mockAnswers(tester);

    await recognizer.cancel(9);
    await recognizer.openAppSettings();

    expect(calls, hasLength(2));
    expect(calls[0].method, dictateCancelMethod);
    expect(calls[0].arguments, 9);
    expect(calls[1].method, dictateOpenAppSettingsMethod);
    expect(calls[1].arguments, isNull);
  });

  test('the wire vocabulary is pinned to independent raw literals — a '
      'constant drifted on either side of the channel fails here and in '
      'tool/check_wire_contracts.dart, never only in production', () {
    expect(dictateChannelName, 'dev.dorogoy.organizer/dictate');
    expect(dictateProbeMethod, 'probe');
    expect(dictateStartMethod, 'start');
    expect(dictateCancelMethod, 'cancel');
    expect(dictateOpenAppSettingsMethod, 'openAppSettings');
    expect(dictateOutcomeMethod, 'outcome');
    expect(dictateSessionIdKey, 'sessionId');
    expect(dictateTranscriptKey, 'transcript');
    expect(dictateUnavailableWire, 'unavailable');
    expect(dictateAskableWire, 'askable');
    expect(dictateGrantedWire, 'granted');
    expect(dictateListeningWire, 'listening');
    expect(dictateRefusedWire, 'refused');
  });

  testWidgets('a well-formed outcome upcall lands on the outcomes stream', (
    tester,
  ) async {
    final recognizer = DictateRecognizer();
    final received = <RecognizerOutcome>[];
    final subscription = recognizer.outcomes.listen(received.add);
    addTearDown(subscription.cancel);

    await deliver(
      tester,
      const MethodCall(dictateOutcomeMethod, <String, Object?>{
        dictateSessionIdKey: 11,
        dictateTranscriptKey: 'llamar al dentista',
      }),
    );

    expect(received, [(sessionId: 11, transcript: 'llamar al dentista')]);
  });

  testWidgets('a nothing-landed outcome carries its null transcript whole', (
    tester,
  ) async {
    final recognizer = DictateRecognizer();
    final received = <RecognizerOutcome>[];
    final subscription = recognizer.outcomes.listen(received.add);
    addTearDown(subscription.cancel);

    await deliver(
      tester,
      const MethodCall(dictateOutcomeMethod, <String, Object?>{
        dictateSessionIdKey: 12,
      }),
    );

    expect(received, [(sessionId: 12, transcript: null)]);
  });

  testWidgets('a malformed outcome drops quietly — a non-int session id '
      'or a non-Map payload lands nothing and breaks nothing', (tester) async {
    final recognizer = DictateRecognizer();
    final received = <RecognizerOutcome>[];
    final subscription = recognizer.outcomes.listen(received.add);
    addTearDown(subscription.cancel);

    await deliver(
      tester,
      const MethodCall(dictateOutcomeMethod, <String, Object?>{
        dictateSessionIdKey: 'eleven',
        dictateTranscriptKey: 'hola',
      }),
    );
    await deliver(tester, const MethodCall(dictateOutcomeMethod, 'not-a-map'));
    await deliver(tester, const MethodCall('someOtherMethod', null));

    expect(received, isEmpty);
  });
}

// The credentials channel adapter's contract (Story 4.3, AD-22): the
// wire-map mapping the platform half speaks — structured outcome maps
// into the seam's vocabulary (an outcome word outside the protocol is
// a format violation, never a quiet substitution and never a silent
// success), the outgoing method names and byte arguments, and the
// folded failure words. Exercised over the real adapter through the
// mock binary messenger (the dictate suite's own pattern), because
// every other seam fakes the cipher and the adapter itself would
// otherwise hold no test at all.

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:organizer/platform/credentials/credentials_cipher.dart';

const MethodChannel _channel = MethodChannel(credentialsChannelName);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  /// Steers the platform's answers to Dart→platform calls, recording
  /// every call for the method-name and argument pins.
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

  testWidgets('seal maps sealed to the envelope bytes', (tester) async {
    final cipher = CredentialsChannelCipher();
    final (_, steer) = mockAnswers(tester);

    steer({
      credentialsOutcomeKey: credentialsSealedWire,
      credentialsEnvelopeKey: Uint8List.fromList([10, 20, 30]),
    });
    final sealed = await cipher.seal([1, 2, 3]);
    expect(sealed.failure, isNull);
    expect(sealed.envelope, [10, 20, 30]);
  });

  testWidgets('unseal maps ready to the plaintext bytes', (tester) async {
    final cipher = CredentialsChannelCipher();
    final (_, steer) = mockAnswers(tester);

    steer({
      credentialsOutcomeKey: credentialsReadyWire,
      credentialsPlaintextKey: Uint8List.fromList([4, 5]),
    });
    final unsealed = await cipher.unseal([10, 20, 30]);
    expect(unsealed.failure, isNull);
    expect(unsealed.plaintext, [4, 5]);
  });

  testWidgets('corrupt and invalidated fold through both methods', (
    tester,
  ) async {
    final cipher = CredentialsChannelCipher();
    final (_, steer) = mockAnswers(tester);

    steer({credentialsOutcomeKey: credentialsCorruptWire});
    expect(
      (await cipher.unseal([1])).failure,
      CredentialsCipherFailure.corrupt,
    );
    steer({credentialsOutcomeKey: credentialsInvalidatedWire});
    expect(
      (await cipher.unseal([1])).failure,
      CredentialsCipherFailure.invalidated,
    );
    // The words are the whole protocol for failures — seal folds the
    // same two, and never invents a third.
    steer({credentialsOutcomeKey: credentialsCorruptWire});
    expect((await cipher.seal([1])).failure, CredentialsCipherFailure.corrupt);
    steer({credentialsOutcomeKey: credentialsInvalidatedWire});
    expect(
      (await cipher.seal([1])).failure,
      CredentialsCipherFailure.invalidated,
    );
  });

  testWidgets('an outcome word outside the protocol throws — never a quiet '
      'success, never a substituted failure', (tester) async {
    final cipher = CredentialsChannelCipher();
    final (_, steer) = mockAnswers(tester);

    steer({credentialsOutcomeKey: 'maybe'});
    await expectLater(cipher.seal([1]), throwsA(isA<FormatException>()));
    await expectLater(cipher.unseal([1]), throwsA(isA<FormatException>()));
    steer(null);
    await expectLater(cipher.seal([1]), throwsA(isA<FormatException>()));
    steer('a bare string, not a map');
    await expectLater(cipher.unseal([1]), throwsA(isA<FormatException>()));
  });

  testWidgets('a success answer missing its payload bytes throws', (
    tester,
  ) async {
    final cipher = CredentialsChannelCipher();
    final (_, steer) = mockAnswers(tester);

    steer({credentialsOutcomeKey: credentialsSealedWire});
    await expectLater(cipher.seal([1]), throwsA(isA<FormatException>()));
    steer({credentialsOutcomeKey: credentialsReadyWire});
    await expectLater(cipher.unseal([1]), throwsA(isA<FormatException>()));
  });

  testWidgets('a channel speaking in exceptions is off-protocol — '
      'PlatformException and MissingPluginException fold to the same '
      'FormatException, never a crypto outcome', (tester) async {
    final cipher = CredentialsChannelCipher();
    final (_, _) = mockAnswers(tester);
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      _channel,
      (call) async => throw PlatformException(code: 'keystore'),
    );
    await expectLater(cipher.seal([1]), throwsA(isA<FormatException>()));
    await expectLater(cipher.unseal([1]), throwsA(isA<FormatException>()));

    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      _channel,
      (call) async => throw MissingPluginException(),
    );
    await expectLater(cipher.seal([1]), throwsA(isA<FormatException>()));
    await expectLater(cipher.unseal([1]), throwsA(isA<FormatException>()));
  });

  testWidgets('the outgoing method names and byte arguments are pinned', (
    tester,
  ) async {
    final cipher = CredentialsChannelCipher();
    final (calls, steer) = mockAnswers(tester);
    steer({
      credentialsOutcomeKey: credentialsSealedWire,
      credentialsEnvelopeKey: Uint8List.fromList([9]),
    });

    await cipher.seal([7, 8]);
    steer({
      credentialsOutcomeKey: credentialsReadyWire,
      credentialsPlaintextKey: Uint8List.fromList([5]),
    });
    await cipher.unseal([9]);

    expect(calls, hasLength(2));
    expect(calls[0].method, credentialsSealMethod);
    // The outgoing argument is bytes, not a boxed list: the standard
    // codec encodes a Uint8List as what Kotlin receives as `byte[]`
    // — the mock erases the distinction, so the type is pinned here
    // beside the values.
    expect(calls[0].arguments, isA<Uint8List>());
    expect(calls[0].arguments, orderedEquals([7, 8]));
    expect(calls[1].method, credentialsUnsealMethod);
    expect(calls[1].arguments, isA<Uint8List>());
    expect(calls[1].arguments, orderedEquals([9]));
  });

  test('the wire vocabulary is pinned to independent raw literals — a '
      'constant drifted on either side of the channel fails here and in '
      'tool/check_wire_contracts.dart, never only in production', () {
    expect(credentialsChannelName, 'dev.dorogoy.organizer/credentials');
    expect(credentialsSealMethod, 'seal');
    expect(credentialsUnsealMethod, 'unseal');
    expect(credentialsOutcomeKey, 'outcome');
    expect(credentialsEnvelopeKey, 'envelope');
    expect(credentialsPlaintextKey, 'plaintext');
    expect(credentialsSealedWire, 'sealed');
    expect(credentialsReadyWire, 'ready');
    expect(credentialsCorruptWire, 'corrupt');
    expect(credentialsInvalidatedWire, 'invalidated');
  });
}

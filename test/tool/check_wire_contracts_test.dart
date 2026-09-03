// The wire contracts check's own contract (Story 3.4; generalized in
// Story 4.3): every hand-written channel's two halves must speak one
// protocol — every Kotlin companion constant equal to its Dart
// counterpart — and each contract's manifest assertion must hold
// (dictate declares RECORD_AUDIO; credentials asserts nothing). A
// drifted constant on either side is a finding with file and line,
// never a silent protocol fork.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../tool/check_wire_contracts.dart';

const String _dictateKotlinHalf = '''
internal class DictateChannel {
    private companion object {
        const val CHANNEL_NAME = "dev.dorogoy.organizer/dictate"
        const val PROBE_METHOD = "probe"
        const val START_METHOD = "start"
        const val CANCEL_METHOD = "cancel"
        const val OPEN_APP_SETTINGS_METHOD = "openAppSettings"
        const val OUTCOME_METHOD = "outcome"
        const val SESSION_ID_KEY = "sessionId"
        const val TRANSCRIPT_KEY = "transcript"
        const val WIRE_UNAVAILABLE = "unavailable"
        const val WIRE_ASKABLE = "askable"
        const val WIRE_GRANTED = "granted"
        const val WIRE_LISTENING = "listening"
        const val WIRE_REFUSED = "refused"
        const val PERMISSION = android.Manifest.permission.RECORD_AUDIO
        const val PERMISSION_REQUEST_CODE = 3404
    }
}
''';

const String _dictateDartHalf = '''
const String dictateChannelName = 'dev.dorogoy.organizer/dictate';
const String dictateProbeMethod = 'probe';
const String dictateStartMethod = 'start';
const String dictateCancelMethod = 'cancel';
const String dictateOpenAppSettingsMethod = 'openAppSettings';
const String dictateOutcomeMethod = 'outcome';
const String dictateSessionIdKey = 'sessionId';
const String dictateTranscriptKey = 'transcript';
const String dictateUnavailableWire = 'unavailable';
const String dictateAskableWire = 'askable';
const String dictateGrantedWire = 'granted';
const String dictateListeningWire = 'listening';
const String dictateRefusedWire = 'refused';
''';

const String _credentialsKotlinHalf = '''
internal class CredentialsChannel {
    private companion object {
        const val CHANNEL_NAME = "dev.dorogoy.organizer/credentials"
        const val SEAL_METHOD = "seal"
        const val UNSEAL_METHOD = "unseal"
        const val OUTCOME_KEY = "outcome"
        const val ENVELOPE_KEY = "envelope"
        const val PLAINTEXT_KEY = "plaintext"
        const val WIRE_SEALED = "sealed"
        const val WIRE_READY = "ready"
        const val WIRE_CORRUPT = "corrupt"
        const val WIRE_INVALIDATED = "invalidated"
    }
}
''';

const String _credentialsDartHalf = '''
const String credentialsChannelName = 'dev.dorogoy.organizer/credentials';
const String credentialsSealMethod = 'seal';
const String credentialsUnsealMethod = 'unseal';
const String credentialsOutcomeKey = 'outcome';
const String credentialsEnvelopeKey = 'envelope';
const String credentialsPlaintextKey = 'plaintext';
const String credentialsSealedWire = 'sealed';
const String credentialsReadyWire = 'ready';
const String credentialsCorruptWire = 'corrupt';
const String credentialsInvalidatedWire = 'invalidated';
''';

const String _manifest = '''
<manifest>
    <uses-permission android:name="android.permission.RECORD_AUDIO"/>
</manifest>
''';

WireContract get _dictateContract =>
    wireContracts.firstWhere((contract) => contract.name == 'dictate');

WireContract get _credentialsContract =>
    wireContracts.firstWhere((contract) => contract.name == 'credentials');

Directory _fixture({
  required String dictateKotlin,
  required String dictateDart,
  String credentialsKotlin = _credentialsKotlinHalf,
  String credentialsDart = _credentialsDartHalf,
  String manifest = _manifest,
}) {
  final root = Directory.systemTemp.createTempSync('wire_contracts');
  addTearDown(() => root.deleteSync(recursive: true));
  void write(String path, String source) {
    File('${root.path}/$path')
      ..createSync(recursive: true)
      ..writeAsStringSync(source);
  }

  write(
    'android/app/src/main/kotlin/dev/dorogoy/organizer/'
    'DictateChannel.kt',
    dictateKotlin,
  );
  write('lib/platform/dictate/dictate_recognizer.dart', dictateDart);
  write(
    'android/app/src/main/kotlin/dev/dorogoy/organizer/'
    'CredentialsChannel.kt',
    credentialsKotlin,
  );
  write('lib/platform/credentials/credentials_cipher.dart', credentialsDart);
  write('android/app/src/main/AndroidManifest.xml', manifest);
  return root;
}

void main() {
  test('a matching pair of dictate halves is clean', () {
    final findings = scanContract(
      contract: _dictateContract,
      kotlinSource: _dictateKotlinHalf,
      dartSource: _dictateDartHalf,
    );
    expect(findings, isEmpty);
  });

  test('a matching pair of credentials halves is clean', () {
    final findings = scanContract(
      contract: _credentialsContract,
      kotlinSource: _credentialsKotlinHalf,
      dartSource: _credentialsDartHalf,
    );
    expect(findings, isEmpty);
  });

  test('a value drifted on the Dart side names the file and line', () {
    final drifted = _dictateDartHalf.replaceFirst(
      "const String dictateProbeMethod = 'probe';",
      "const String dictateProbeMethod = 'probeMic';",
    );
    final findings = scanContract(
      contract: _dictateContract,
      kotlinSource: _dictateKotlinHalf,
      dartSource: drifted,
    );
    expect(findings, hasLength(1));
    expect(
      findings.single,
      startsWith('lib/platform/dictate/dictate_recognizer.dart:2:'),
    );
    expect(findings.single, contains('disagrees with PROBE_METHOD'));
  });

  test('a credentials wire word drifted on the Kotlin side is a finding', () {
    final drifted = _credentialsKotlinHalf.replaceFirst(
      'const val WIRE_CORRUPT = "corrupt"',
      'const val WIRE_CORRUPT = "damaged"',
    );
    final findings = scanContract(
      contract: _credentialsContract,
      kotlinSource: drifted,
      dartSource: _credentialsDartHalf,
    );
    expect(findings, hasLength(1));
    expect(findings.single, contains('WIRE_CORRUPT'));
    expect(findings.single, contains('credentials wire contract'));
  });

  test('a constant missing on either side is a finding', () {
    final kotlinMissing = _dictateKotlinHalf.replaceFirst(
      '        const val WIRE_REFUSED = "refused"\n',
      '',
    );
    expect(
      scanContract(
        contract: _dictateContract,
        kotlinSource: kotlinMissing,
        dartSource: _dictateDartHalf,
      ),
      hasLength(1),
    );
    final dartMissing = _dictateDartHalf.replaceFirst(
      "const String dictateOutcomeMethod = 'outcome';\n",
      '',
    );
    expect(
      scanContract(
        contract: _dictateContract,
        kotlinSource: _dictateKotlinHalf,
        dartSource: dartMissing,
      ),
      hasLength(1),
    );
  });

  test('non-wire Kotlin constants (the permission, the request code) '
      'do not reach the comparison', () {
    final findings = scanContract(
      contract: _dictateContract,
      kotlinSource: _dictateKotlinHalf,
      dartSource: _dictateDartHalf,
    );
    expect(
      findings.every((finding) => !finding.contains('PERMISSION')),
      isTrue,
    );
  });

  group('the executable', () {
    test('exits 0 and passes on matching halves', () async {
      final root = _fixture(
        dictateKotlin: _dictateKotlinHalf,
        dictateDart: _dictateDartHalf,
      );
      final result = await Process.run('dart', [
        'run',
        'tool/check_wire_contracts.dart',
        root.path,
      ]);
      expect(result.exitCode, 0);
      expect(result.stdout as String, contains('wire contracts check passed'));
    });

    test('exits 1 and prints file:line on a drifted constant', () async {
      final root = _fixture(
        dictateKotlin: _dictateKotlinHalf,
        dictateDart: _dictateDartHalf.replaceFirst(
          "const String dictateCancelMethod = 'cancel';",
          "const String dictateCancelMethod = 'stop';",
        ),
      );
      final result = await Process.run('dart', [
        'run',
        'tool/check_wire_contracts.dart',
        root.path,
      ]);
      expect(result.exitCode, 1);
      final out = result.stdout as String;
      expect(out, matches(RegExp(r'dictate_recognizer\.dart:\d+:')));
      expect(out, contains('wire contracts check FAILED'));
    });

    test('exits 1 when the manifest drops RECORD_AUDIO', () async {
      final root = _fixture(
        dictateKotlin: _dictateKotlinHalf,
        dictateDart: _dictateDartHalf,
        manifest: '<manifest/>\n',
      );
      final result = await Process.run('dart', [
        'run',
        'tool/check_wire_contracts.dart',
        root.path,
      ]);
      expect(result.exitCode, 1);
      expect(result.stdout as String, contains('RECORD_AUDIO is not declared'));
    });

    test(
      'exits 1 when a credentials half drifts while dictate matches',
      () async {
        final root = _fixture(
          dictateKotlin: _dictateKotlinHalf,
          dictateDart: _dictateDartHalf,
          credentialsDart: _credentialsDartHalf.replaceFirst(
            "const String credentialsChannelName = "
                "'dev.dorogoy.organizer/credentials';",
            "const String credentialsChannelName = "
                "'dev.dorogoy.organizer/creds';",
          ),
        );
        final result = await Process.run('dart', [
          'run',
          'tool/check_wire_contracts.dart',
          root.path,
        ]);
        expect(result.exitCode, 1);
        expect(result.stdout as String, contains('credentials_cipher.dart:1:'));
      },
    );

    test('exits 2 when a contract file is missing', () async {
      final root = _fixture(
        dictateKotlin: _dictateKotlinHalf,
        dictateDart: _dictateDartHalf,
      );
      File(
        '${root.path}/android/app/src/main/kotlin/dev/dorogoy/organizer/'
        'DictateChannel.kt',
      ).deleteSync();
      final result = await Process.run('dart', [
        'run',
        'tool/check_wire_contracts.dart',
        root.path,
      ]);
      expect(result.exitCode, 2);
    });
  });

  test('the contracts list holds exactly the two shipped channels, with '
      'their wire-name maps pinned', () {
    expect(wireContracts, hasLength(2));
    expect(_dictateContract.kotlinToDartWireNames, hasLength(13));
    expect(_dictateContract.assertedPermission, recordAudioPermission);
    expect(_credentialsContract.kotlinToDartWireNames, hasLength(10));
    // No permission asserted: the credentials channel asks for none.
    expect(_credentialsContract.assertedPermission, isNull);
  });
}

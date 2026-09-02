// The dictate wire contract check's own contract (Story 3.4): the two
// halves of the hand-written `dictate` channel must speak one protocol —
// every Kotlin companion constant equal to its Dart counterpart, and the
// manifest still declaring RECORD_AUDIO. A drifted constant on either
// side is a finding with file and line, never a silent protocol fork.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../tool/check_dictate_wire_contract.dart';

const String _kotlinHalf = '''
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

const String _dartHalf = '''
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

const String _manifest = '''
<manifest>
    <uses-permission android:name="android.permission.RECORD_AUDIO"/>
</manifest>
''';

Directory _fixture({
  required String kotlin,
  required String dart,
  String manifest = _manifest,
}) {
  final root = Directory.systemTemp.createTempSync('dictate_wire');
  addTearDown(() => root.deleteSync(recursive: true));
  final kotlinFile = File(
    '${root.path}/android/app/src/main/kotlin/dev/dorogoy/organizer/'
    'DictateChannel.kt',
  )..createSync(recursive: true);
  kotlinFile.writeAsStringSync(kotlin);
  File('${root.path}/lib/platform/dictate/dictate_recognizer.dart')
    ..createSync(recursive: true)
    ..writeAsStringSync(dart);
  File('${root.path}/android/app/src/main/AndroidManifest.xml')
    ..createSync(recursive: true)
    ..writeAsStringSync(manifest);
  return root;
}

void main() {
  test('a matching pair of halves is clean', () {
    final findings = scanContract(
      kotlinFile: 'DictateChannel.kt',
      kotlinSource: _kotlinHalf,
      dartFile: 'dictate_recognizer.dart',
      dartSource: _dartHalf,
    );
    expect(findings, isEmpty);
  });

  test('a value drifted on the Dart side names the file and line', () {
    final drifted = _dartHalf.replaceFirst(
      "const String dictateProbeMethod = 'probe';",
      "const String dictateProbeMethod = 'probeMic';",
    );
    final findings = scanContract(
      kotlinFile: 'DictateChannel.kt',
      kotlinSource: _kotlinHalf,
      dartFile: 'dictate_recognizer.dart',
      dartSource: drifted,
    );
    expect(findings, hasLength(1));
    expect(findings.single, startsWith('dictate_recognizer.dart:2:'));
    expect(findings.single, contains('disagrees with PROBE_METHOD'));
  });

  test('a constant missing on either side is a finding', () {
    final kotlinMissing = _kotlinHalf.replaceFirst(
      '        const val WIRE_REFUSED = "refused"\n',
      '',
    );
    expect(
      scanContract(
        kotlinFile: 'DictateChannel.kt',
        kotlinSource: kotlinMissing,
        dartFile: 'dictate_recognizer.dart',
        dartSource: _dartHalf,
      ),
      hasLength(1),
    );
    final dartMissing = _dartHalf.replaceFirst(
      "const String dictateOutcomeMethod = 'outcome';\n",
      '',
    );
    expect(
      scanContract(
        kotlinFile: 'DictateChannel.kt',
        kotlinSource: _kotlinHalf,
        dartFile: 'dictate_recognizer.dart',
        dartSource: dartMissing,
      ),
      hasLength(1),
    );
  });

  test('non-wire Kotlin constants (the permission, the request code) '
      'do not reach the comparison', () {
    final findings = scanContract(
      kotlinFile: 'DictateChannel.kt',
      kotlinSource: _kotlinHalf,
      dartFile: 'dictate_recognizer.dart',
      dartSource: _dartHalf,
    );
    expect(
      findings.every((finding) => !finding.contains('PERMISSION')),
      isTrue,
    );
  });

  group('the executable', () {
    test('exits 0 and passes on a matching pair', () async {
      final root = _fixture(kotlin: _kotlinHalf, dart: _dartHalf);
      final result = await Process.run('dart', [
        'run',
        'tool/check_dictate_wire_contract.dart',
        root.path,
      ]);
      expect(result.exitCode, 0);
      expect(
        result.stdout as String,
        contains('dictate wire contract check passed'),
      );
    });

    test('exits 1 and prints file:line on a drifted constant', () async {
      final root = _fixture(
        kotlin: _kotlinHalf,
        dart: _dartHalf.replaceFirst(
          "const String dictateCancelMethod = 'cancel';",
          "const String dictateCancelMethod = 'stop';",
        ),
      );
      final result = await Process.run('dart', [
        'run',
        'tool/check_dictate_wire_contract.dart',
        root.path,
      ]);
      expect(result.exitCode, 1);
      final out = result.stdout as String;
      expect(out, matches(RegExp(r'dictate_recognizer\.dart:\d+:')));
      expect(out, contains('dictate wire contract check FAILED'));
    });

    test('exits 1 when the manifest drops RECORD_AUDIO', () async {
      final root = _fixture(
        kotlin: _kotlinHalf,
        dart: _dartHalf,
        manifest: '<manifest/>\n',
      );
      final result = await Process.run('dart', [
        'run',
        'tool/check_dictate_wire_contract.dart',
        root.path,
      ]);
      expect(result.exitCode, 1);
      expect(result.stdout as String, contains('RECORD_AUDIO is not declared'));
    });

    test('exits 2 when a contract file is missing', () async {
      final root = _fixture(kotlin: _kotlinHalf, dart: _dartHalf);
      File(
        '${root.path}/android/app/src/main/kotlin/dev/dorogoy/organizer/'
        'DictateChannel.kt',
      ).deleteSync();
      final result = await Process.run('dart', [
        'run',
        'tool/check_dictate_wire_contract.dart',
        root.path,
      ]);
      expect(result.exitCode, 2);
    });
  });

  test('the wire-name map pins exactly the shipped protocol', () {
    expect(kotlinToDartWireNames, hasLength(13));
  });
}

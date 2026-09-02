// ignore_for_file: avoid_print
//
// The dictate wire contract (Story 3.4, FR-32, AD-11): the hand-written
// `dictate` channel's protocol is defined twice — once as the named
// constants of `DictateChannel.kt`'s companion and once as the named
// constants of `lib/platform/dictate/dictate_recognizer.dart` — and
// nothing on either side compiles against the other. This check is the
// third copy that fails the build instead of the user: every wire name
// (channel, methods, payload keys, wire words) must match across the
// two halves, and the manifest must still declare the one runtime
// permission the channel asks for. A constant renamed or drifted on
// either side is a finding here; the Dart side is additionally pinned
// to independent raw literals by `test/platform/dictate_recognizer_test.dart`,
// so both halves are locked to the protocol, not to each other's drift.
//
// Output contract (the tool checks' own): one `file:line: message` line
// per finding, exit 1 when any finding exists, exit 2 when a contract
// file is missing.
import 'dart:io';

/// The Kotlin half of the contract, repo-relative.
const String kotlinHalfPath =
    'android/app/src/main/kotlin/dev/dorogoy/organizer/DictateChannel.kt';

/// The Dart half of the contract, repo-relative.
const String dartHalfPath = 'lib/platform/dictate/dictate_recognizer.dart';

/// The manifest that must declare the channel's runtime permission.
const String manifestPath = 'android/app/src/main/AndroidManifest.xml';

/// The runtime permission the channel requests at the first press.
const String recordAudioPermission = 'android.permission.RECORD_AUDIO';

/// The wire vocabulary, one pair per name: the Kotlin companion's
/// constant to the Dart file's constant it must equal. Grown only by
/// explicit decision — a new wire name joins this map in the same pass
/// that adds it to both halves.
const Map<String, String> kotlinToDartWireNames = {
  'CHANNEL_NAME': 'dictateChannelName',
  'PROBE_METHOD': 'dictateProbeMethod',
  'START_METHOD': 'dictateStartMethod',
  'CANCEL_METHOD': 'dictateCancelMethod',
  'OPEN_APP_SETTINGS_METHOD': 'dictateOpenAppSettingsMethod',
  'OUTCOME_METHOD': 'dictateOutcomeMethod',
  'SESSION_ID_KEY': 'dictateSessionIdKey',
  'TRANSCRIPT_KEY': 'dictateTranscriptKey',
  'WIRE_UNAVAILABLE': 'dictateUnavailableWire',
  'WIRE_ASKABLE': 'dictateAskableWire',
  'WIRE_GRANTED': 'dictateGrantedWire',
  'WIRE_LISTENING': 'dictateListeningWire',
  'WIRE_REFUSED': 'dictateRefusedWire',
};

final RegExp _kotlinConstantRegExp = RegExp(
  r'const\s+val\s+(\w+)\s*=\s*"([^"]*)"',
);

final RegExp _dartConstantRegExp = RegExp(
  r"const\s+String\s+(\w+)\s*=\s*'([^']*)'",
);

int _lineOf(String text, int index) =>
    '\n'.allMatches(text.substring(0, index)).length + 1;

/// Extracts one half's named string constants: the constant's name to
/// its value and 1-based line.
Map<String, (String value, int line)> constantsOf(
  String source,
  RegExp pattern,
) {
  final constants = <String, (String, int)>{};
  for (final match in pattern.allMatches(source)) {
    constants[match.group(1)!] = (
      match.group(2)!,
      _lineOf(source, match.start),
    );
  }
  return constants;
}

/// Scans the two halves' sources for contract violations: a wire name
/// missing on either side, or a pair whose values disagree.
List<String> scanContract({
  required String kotlinFile,
  required String kotlinSource,
  required String dartFile,
  required String dartSource,
}) {
  final findings = <String>[];
  final kotlin = constantsOf(kotlinSource, _kotlinConstantRegExp);
  final dart = constantsOf(dartSource, _dartConstantRegExp);
  for (final entry in kotlinToDartWireNames.entries) {
    final kotlinName = entry.key;
    final dartName = entry.value;
    final kotlinConstant = kotlin[kotlinName];
    final dartConstant = dart[dartName];
    if (kotlinConstant == null) {
      findings.add(
        '$kotlinFile:1: the wire name $kotlinName is missing — the '
        'Kotlin half must define it (dictate wire contract)',
      );
      continue;
    }
    if (dartConstant == null) {
      findings.add(
        '$dartFile:1: the wire name $dartName is missing — the Dart '
        'half must define it (dictate wire contract)',
      );
      continue;
    }
    if (kotlinConstant.$1 != dartConstant.$1) {
      findings.add(
        '$dartFile:${dartConstant.$2}: $dartName '
        "('${dartConstant.$1}') disagrees with $kotlinName "
        "('${kotlinConstant.$1}') — the halves drifted apart "
        '(dictate wire contract)',
      );
    }
  }
  findings.sort();
  return findings;
}

/// Runs the whole check against [repoRoot], printing one
/// `file:line: message` line per finding. Returns the process exit
/// code: 0 clean, 1 findings, 2 a contract file missing.
int runCheck([String repoRoot = '']) {
  final root = repoRoot.isEmpty ? '' : '$repoRoot/';
  final files = {
    'kotlin': File('$root$kotlinHalfPath'),
    'dart': File('$root$dartHalfPath'),
    'manifest': File('$root$manifestPath'),
  };
  for (final name in ['kotlin', 'dart', 'manifest']) {
    if (!files[name]!.existsSync()) {
      stderr.writeln('$name contract file not found at ${files[name]!.path}');
      return 2;
    }
  }
  final findings = scanContract(
    kotlinFile: kotlinHalfPath,
    kotlinSource: files['kotlin']!.readAsStringSync(),
    dartFile: dartHalfPath,
    dartSource: files['dart']!.readAsStringSync(),
  );
  final manifest = files['manifest']!.readAsStringSync();
  if (!manifest.contains(recordAudioPermission)) {
    findings.add(
      '$manifestPath:1: RECORD_AUDIO is not declared — the channel '
      'cannot ask for its one runtime permission (dictate wire contract)',
    );
  }
  for (final finding in findings) {
    print(finding);
  }
  if (findings.isNotEmpty) {
    print(
      'dictate wire contract check FAILED: ${findings.length} finding(s) — '
      'the two halves of the channel must speak one protocol',
    );
    return 1;
  }
  print('dictate wire contract check passed');
  return 0;
}

void main(List<String> args) {
  exit(runCheck(args.isEmpty ? '' : args.first));
}

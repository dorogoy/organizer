// ignore_for_file: avoid_print
//
// The wire contracts check (Story 3.4; generalized in Story 4.3):
// every hand-written channel's protocol is defined twice — once as
// the named constants of the Kotlin half's companion and once as the
// named constants of the Dart half's adapter — and nothing on either
// side compiles against the other. This check is the third copy that
// fails the build instead of the user: every wire name (channel,
// methods, payload keys, wire words) must match across the two
// halves of every contract on [wireContracts], and each contract's
// manifest assertion must hold — the dictate channel's RECORD_AUDIO
// (the one runtime permission it asks for at the first press), or
// no assertion at all (the credentials channel asks for nothing).
// A constant renamed or drifted on either side is a finding here;
// the Dart side of each channel is additionally pinned to
// independent raw literals by its adapter test
// (test/platform/…), so both halves are locked to the protocol,
// not to each other's drift.
//
// A new channel joins [wireContracts] in the same pass that writes
// its two halves — the list is the census of hand-written channels
// (AD-11: exactly three, notify/dictate/credentials — the third
// arrives with its own story).
//
// Output contract (the tool checks' own): one `file:line: message`
// line per finding, exit 1 when any finding exists, exit 2 when a
// contract file is missing.
import 'dart:io';

/// One channel's wire contract: the two halves' paths, the wire
/// vocabulary as Kotlin-companion-name → Dart-constant-name pairs,
/// and the manifest permission the channel asserts — null when the
/// channel asks for no runtime permission at all.
class WireContract {
  const WireContract({
    required this.name,
    required this.kotlinHalfPath,
    required this.dartHalfPath,
    required this.kotlinToDartWireNames,
    this.assertedPermission,
  });

  /// The channel's own name, for findings and the pass/fail lines.
  final String name;

  /// The Kotlin half of the contract, repo-relative.
  final String kotlinHalfPath;

  /// The Dart half of the contract, repo-relative.
  final String dartHalfPath;

  /// The wire vocabulary, one pair per name: the Kotlin companion's
  /// constant to the Dart file's constant it must equal.
  final Map<String, String> kotlinToDartWireNames;

  /// The manifest permission this channel's contract asserts, or
  /// null when the channel asks for none.
  final String? assertedPermission;
}

/// The manifest the asserted permissions are declared in.
const String manifestPath = 'android/app/src/main/AndroidManifest.xml';

/// The dictate channel's runtime permission (Story 3.4, FR-32).
const String recordAudioPermission = 'android.permission.RECORD_AUDIO';

/// Every hand-written channel's contract (AD-11). Grown only by
/// explicit decision — a new wire name joins a contract's map in the
/// same pass that adds it to both halves, and a new channel joins
/// this list in the same pass that writes its halves.
const List<WireContract> wireContracts = [
  WireContract(
    name: 'dictate',
    kotlinHalfPath:
        'android/app/src/main/kotlin/dev/dorogoy/organizer/DictateChannel.kt',
    dartHalfPath: 'lib/platform/dictate/dictate_recognizer.dart',
    kotlinToDartWireNames: {
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
    },
    assertedPermission: recordAudioPermission,
  ),
  WireContract(
    name: 'credentials',
    kotlinHalfPath: 'android/app/src/main/kotlin/dev/dorogoy/organizer/CredentialsChannel.kt',
    dartHalfPath: 'lib/platform/credentials/credentials_cipher.dart',
    kotlinToDartWireNames: {
      'CHANNEL_NAME': 'credentialsChannelName',
      'SEAL_METHOD': 'credentialsSealMethod',
      'UNSEAL_METHOD': 'credentialsUnsealMethod',
      'OUTCOME_KEY': 'credentialsOutcomeKey',
      'ENVELOPE_KEY': 'credentialsEnvelopeKey',
      'PLAINTEXT_KEY': 'credentialsPlaintextKey',
      'WIRE_SEALED': 'credentialsSealedWire',
      'WIRE_READY': 'credentialsReadyWire',
      'WIRE_CORRUPT': 'credentialsCorruptWire',
      'WIRE_INVALIDATED': 'credentialsInvalidatedWire',
    },
    // No asserted permission: the credentials channel asks for no
    // runtime permission — the Keystore is permission-free, and the
    // merged-manifest seal (egress seal 3) polices the whole set.
  ),
];

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

/// Scans one contract's two halves' sources for violations: a wire
/// name missing on either side, or a pair whose values disagree.
List<String> scanContract({
  required WireContract contract,
  required String kotlinSource,
  required String dartSource,
}) {
  final findings = <String>[];
  final kotlinFile = contract.kotlinHalfPath;
  final dartFile = contract.dartHalfPath;
  final kotlin = constantsOf(kotlinSource, _kotlinConstantRegExp);
  final dart = constantsOf(dartSource, _dartConstantRegExp);
  for (final entry in contract.kotlinToDartWireNames.entries) {
    final kotlinName = entry.key;
    final dartName = entry.value;
    final kotlinConstant = kotlin[kotlinName];
    final dartConstant = dart[dartName];
    if (kotlinConstant == null) {
      findings.add(
        '$kotlinFile:1: the wire name $kotlinName is missing — the '
        'Kotlin half must define it (${contract.name} wire contract)',
      );
      continue;
    }
    if (dartConstant == null) {
      findings.add(
        '$dartFile:1: the wire name $dartName is missing — the Dart '
        'half must define it (${contract.name} wire contract)',
      );
      continue;
    }
    if (kotlinConstant.$1 != dartConstant.$1) {
      findings.add(
        '$dartFile:${dartConstant.$2}: $dartName '
        "('${dartConstant.$1}') disagrees with $kotlinName "
        "('${kotlinConstant.$1}') — the halves drifted apart "
        '(${contract.name} wire contract)',
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
  final manifestFile = File('$root$manifestPath');
  final findings = <String>[];
  for (final contract in wireContracts) {
    final kotlinFile = File('$root${contract.kotlinHalfPath}');
    final dartFile = File('$root${contract.dartHalfPath}');
    if (!kotlinFile.existsSync()) {
      stderr.writeln(
        '${contract.name} Kotlin contract file not found at '
        '${kotlinFile.path}',
      );
      return 2;
    }
    if (!dartFile.existsSync()) {
      stderr.writeln(
        '${contract.name} Dart contract file not found at ${dartFile.path}',
      );
      return 2;
    }
    findings.addAll(
      scanContract(
        contract: contract,
        kotlinSource: kotlinFile.readAsStringSync(),
        dartSource: dartFile.readAsStringSync(),
      ),
    );
    final permission = contract.assertedPermission;
    if (permission != null) {
      if (!manifestFile.existsSync()) {
        stderr.writeln('manifest not found at ${manifestFile.path}');
        return 2;
      }
      if (!manifestFile.readAsStringSync().contains(permission)) {
        findings.add(
          '$manifestPath:1: $permission is not declared — the channel '
          'cannot ask for its one runtime permission '
          '(${contract.name} wire contract)',
        );
      }
    }
  }
  for (final finding in findings) {
    print(finding);
  }
  if (findings.isNotEmpty) {
    print(
      'wire contracts check FAILED: ${findings.length} finding(s) — '
      "every channel's two halves must speak one protocol",
    );
    return 1;
  }
  print('wire contracts check passed');
  return 0;
}

void main(List<String> args) {
  exit(runCheck(args.isEmpty ? '' : args.first));
}

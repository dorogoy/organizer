// ignore_for_file: avoid_print
//
// The export redaction check (AD-22, Story 4.3): the export fixtures
// — today the fixtures under `test/fixtures/export_redaction/`,
// which Epic 9's export implementation grows into the real
// generation corpus — may never carry a credential's plaintext, a
// provider→key pair shape, or a persisted credential-availability
// claim. Credentials live in the vault's Files envelopes and
// nowhere else; an export that so much as reserves a slot for one
// is a finding here, at fixture time, before any export code ships.
//
// Three shapes are rejected, wherever they sit in the document:
//  - a credential-family property with a non-empty value (an empty
//    string or null is the reserved-slot-free absence; a value is
//    the leak);
//  - a provider→key pair shape — an object associating a provider
//    with a credential-family property of any value, or a
//    providers-named property holding a keyed map of its own;
//  - a persisted existence/availability claim asserted true
//    (`keyExists`, `credentialAvailable` — the honest export never
//    remembers what the vault measures live).
//
// Output contract (the tool checks' own): one `file:line: message`
// line per finding, exit 1 when any finding exists, exit 2 when the
// fixture directory is missing. Registered under `make check`
// (NFR20).
import 'dart:convert';
import 'dart:io';

import 'check_core_purity.dart';

/// The export fixtures' directory, repo-relative — the check's whole
/// scan scope.
const String exportFixturesPath = 'test/fixtures/export_redaction';

/// Credential-family property names: anything naming a credential, a
/// secret, a key of the API kind, a token, a password or plaintext
/// itself. Case-insensitive, separator-tolerant.
final RegExp _credentialFamilyRegExp = RegExp(
  r'(?:credential|secret|api[_-]?key|token|password|plaintext|provider[_-]?key)',
  caseSensitive: false,
);

/// Provider-naming properties — the half a provider→key pair hangs
/// on. `selectedProvider` is deliberately absent: a plain selected
/// provider id (the sanctioned `setting_changed` text, schema v8) is
/// clean export material; only its association with key material is
/// the pair shape.
final RegExp _providerPropertyRegExp = RegExp(
  r'^(?:provider|provider[_-]?id|provider[_-]?name)$',
  caseSensitive: false,
);

/// Properties whose whole job is associating providers with keys: a
/// map-valued `providers`/`providerKeys` property is the pair shape
/// even when every inner value is empty.
final RegExp _providerMapRegExp = RegExp(
  r'^(?:providers?|provider[_-]?keys)$',
  caseSensitive: false,
);

/// Persisted existence/availability claims: `keyExists`,
/// `credentialAvailable`, `providerConfigured` — an export never
/// remembers what only the vault can measure, and the claim is a
/// finding exactly when it asserts true. The provider-prefixed form
/// is the same claim: `providerConfigured: true` persists the
/// configured bit the derivation must measure live.
final RegExp _availabilityClaimRegExp = RegExp(
  r'^(?:key|credential|provider)[a-z_-]*(?:exists|available|configured|valid)$',
  caseSensitive: false,
);

/// One structural finding before its line is located: the JSON
/// property name (quoted, as it appears in source) to probe the raw
/// text with, and the message to report.
typedef _ProvisionalFinding = ({String probe, String message});

/// Scans one decoded JSON value, appending one pending finding per
/// violated shape. [path] names the value's location for the
/// message; the probe carries the offending property's quoted name
/// for the line lookup.
void _scanValue(
  Object? value,
  String path,
  List<_ProvisionalFinding> findings,
) {
  if (value is Map) {
    var hasProviderProperty = false;
    String? credentialPropertyName;
    for (final entry in value.entries) {
      final key = entry.key.toString();
      final child = entry.value;
      final childPath = path.isEmpty ? key : '$path.$key';
      final probe = '"$key"';
      if (_providerPropertyRegExp.hasMatch(key)) {
        hasProviderProperty = true;
      }
      if (_credentialFamilyRegExp.hasMatch(key)) {
        credentialPropertyName ??= key;
        final bool isNonEmpty = switch (child) {
          null => false,
          bool _ => false,
          String s => s.isNotEmpty,
          List l => l.isNotEmpty,
          Map m => m.isNotEmpty,
          num _ => true,
          _ => false,
        };
        if (isNonEmpty) {
          findings.add((
            probe: probe,
            message:
                "'$childPath' carries a non-empty value — a "
                'credential-family property is empty or absent in an '
                'export, never a value (AD-22 export redaction)',
          ));
        }
      }
      if (_providerMapRegExp.hasMatch(key) && child is Map) {
        findings.add((
          probe: probe,
          message:
              "'$childPath' is a provider→key pair shape — an "
              'export associates no provider with key material, not '
              'even as an empty map (AD-22 export redaction)',
        ));
      }
      if (_availabilityClaimRegExp.hasMatch(key) && child == true) {
        findings.add((
          probe: probe,
          message:
              "'$childPath' asserts true — a persisted "
              'availability claim is the vault\'s live measurement, '
              "never the export's memory (AD-22 export redaction)",
        ));
      }
      _scanValue(child, childPath, findings);
    }
    if (hasProviderProperty && credentialPropertyName != null) {
      final where = path.isEmpty ? 'the document root' : "'$path'";
      findings.add((
        probe: '"$credentialPropertyName"',
        message:
            '$where holds a provider→key pair shape — an export '
            'names a selected provider as plain text and never '
            'beside key material (AD-22 export redaction)',
      ));
    }
  } else if (value is List) {
    for (var i = 0; i < value.length; i++) {
      _scanValue(value[i], '$path[$i]', findings);
    }
  }
}

/// Scans one fixture file's source, returning its findings. Pure:
/// tests feed fixture contents directly. Findings carry a
/// best-effort line: the offending property's quoted name located
/// in the raw text, falling back to line 1 when the name appears
/// nowhere (a shape built by a writer that quotes differently).
List<Finding> scanExport({required String file, required String source}) {
  final Object? decoded;
  try {
    decoded = jsonDecode(source);
  } on FormatException catch (error) {
    return [
      Finding(
        file,
        1,
        'not valid JSON — an unparseable export fixture cannot be '
        'verified redacted (${error.message}) (AD-22 export redaction)',
      ),
    ];
  }
  final provisional = <_ProvisionalFinding>[];
  _scanValue(decoded, '', provisional);
  final lines = source.split('\n');
  int lineOfProbe(String probe) {
    for (var i = 0; i < lines.length; i++) {
      if (lines[i].contains(probe)) {
        return i + 1;
      }
    }
    return 1;
  }

  final findings = [
    for (final finding in provisional)
      Finding(file, lineOfProbe(finding.probe), finding.message),
  ]..sort((a, b) => a.message.compareTo(b.message));
  return findings;
}

/// Runs the whole check against [repoRoot], printing one `file:line:
/// message` line per finding. Returns the process exit code: 0
/// clean, 1 findings, 2 the fixtures directory missing.
Future<int> runCheck([String repoRoot = '']) async {
  final root = repoRoot.isEmpty ? '' : '$repoRoot/';
  final fixturesDir = Directory('$root$exportFixturesPath');
  if (!fixturesDir.existsSync()) {
    stderr.writeln('export fixtures not found at ${fixturesDir.path}');
    return 2;
  }
  final files = <File>[];
  void walk(Directory dir) {
    for (final entity in dir.listSync(followLinks: false)) {
      if (entity is Directory) {
        walk(entity);
      } else if (entity is File && entity.path.endsWith('.json')) {
        files.add(entity);
      }
    }
  }

  walk(fixturesDir);
  files.sort((a, b) => a.path.compareTo(b.path));
  final findings = <Finding>[];
  for (final file in files) {
    final scoped = root.isEmpty ? file.path : file.path.substring(root.length);
    findings.addAll(scanExport(file: scoped, source: file.readAsStringSync()));
  }
  for (final finding in findings) {
    print(finding);
  }
  if (findings.isNotEmpty) {
    print(
      'export redaction check FAILED: ${findings.length} finding(s) — '
      'export fixtures carry no plaintext, no provider→key shapes and '
      'no availability claims (AD-22)',
    );
    return 1;
  }
  print('export redaction check passed');
  return 0;
}

Future<void> main(List<String> args) async {
  exit(await runCheck(args.isEmpty ? '' : args.first));
}

// ignore_for_file: avoid_print
//
// The catalogue floor check (AD-16, FR-31): the shipped Evergreen asset
// must hold a well-formed versioned catalogue, all three cadences
// populated, every weekly zone z1..z5 populated (a commit emptying one
// zone must fail), at least 28 distinct 10–15 min non-daily entries — the
// Focus Chunk rotation, so 28 dealt Focus Chunks never repeat with no
// Epic Project active — and the asset must be registered in `pubspec.yaml`'s
// `flutter.assets`, or the bundle never ships it.
//
// Shape and token domains are delegated to the core parser
// (`parseCatalogue`) so the build-time check and the runtime loader can
// never disagree about what a valid entry is. `maintenance` (3 min) never
// counts toward the floor and `daily` entries are excluded: only the
// 10–15 min Focus size on a weekly or seasonal cadence can occupy the
// slot the floor protects.
//
// Output contract (Story 1.1 AC 2): one `file:line: message` line per
// finding, exit 1 when any finding exists, exit 2 when an input file is
// missing. Registered under `make check` (NFR20).
import 'dart:io';

import 'package:core/catalogue/catalogue.dart';
import 'package:core/catalogue/strict_json.dart';
import 'package:core/pool/pool_fact.dart';
import 'package:yaml/yaml.dart';

import 'catalogue_shared.dart';
import 'check_core_purity.dart';

const String assetPath = 'assets/evergreen/catalogue.json';
const String pubspecPath = 'pubspec.yaml';

/// FR-31's coverage floor: distinct 10–15 min non-daily entries.
const int focusFloor = 28;

/// The registration state of the catalogue asset in a pubspec: whether a
/// `flutter.assets` item carries it, and a source line and diagnostic for a
/// malformed declaration. YAML parsing prevents lookalikes in another block
/// and nested mappings from passing as Flutter asset registrations.
({bool registered, int line, String? problem}) registrationState(
  String pubspec,
) {
  final YamlNode root;
  try {
    root = loadYamlNode(pubspec);
  } on YamlException catch (error) {
    return (
      registered: false,
      line: (error.span?.start.line ?? 0) + 1,
      problem: 'invalid pubspec YAML: ${error.message}',
    );
  }
  if (root is! YamlMap) {
    return (
      registered: false,
      line: 1,
      problem: 'pubspec top level must be a YAML mapping',
    );
  }
  final flutter = root['flutter'];
  if (flutter is! YamlMap) {
    return (
      registered: false,
      line: 1,
      problem: 'missing flutter: YAML mapping',
    );
  }
  final flutterLine = _keyLine(root, 'flutter') ?? 1;
  final assets = flutter['assets'];
  if (assets == null) {
    return (registered: false, line: flutterLine, problem: null);
  }
  if (assets is! YamlList) {
    return (
      registered: false,
      line: flutterLine,
      problem: 'flutter.assets must be a YAML list of asset paths',
    );
  }
  for (final asset in assets.nodes) {
    if (asset is YamlScalar &&
        asset.value is String &&
        (asset.value == 'assets/evergreen/' ||
            asset.value == 'assets/evergreen/catalogue.json')) {
      return (registered: true, line: flutterLine, problem: null);
    }
  }
  return (registered: false, line: flutterLine, problem: null);
}

/// Retrieves the parser's source span for a mapping key. Looking at parsed
/// nodes avoids matching a quoted scalar or comment that merely says
/// `flutter:`.
int? _keyLine(YamlMap map, String key) {
  for (final entry in map.nodes.entries) {
    final keyNode = entry.key;
    if (keyNode is YamlNode && keyNode.value == key) {
      return keyNode.span.start.line + 1;
    }
  }
  return null;
}

int _lineForKey(String text, String key) {
  final probe = text.indexOf('"$key"');
  return probe == -1 ? 1 : lineOf(text, probe);
}

/// Scans the catalogue asset source and the pubspec source, returning one
/// finding per violation. Pure: tests feed fixture contents directly.
List<Finding> scanCatalogue({
  required String assetFile,
  required String assetSource,
  required String pubspecFile,
  required String pubspecSource,
}) {
  final findings = <Finding>[];
  final catalogue = _parseOrReport(assetFile, assetSource, findings);
  if (catalogue != null) {
    findings.addAll(
      _coverageFindings(assetFile, assetSource, catalogue.entries),
    );
  }
  final registration = registrationState(pubspecSource);
  if (!registration.registered) {
    findings.add(
      Finding(
        pubspecFile,
        registration.line,
        registration.problem ??
            'the catalogue asset is not registered under flutter.assets — add '
                "'assets/evergreen/' so the bundle ships it (AD-16)",
      ),
    );
  }
  findings.sort((a, b) {
    final byFile = a.file.compareTo(b.file);
    return byFile != 0 ? byFile : a.line.compareTo(b.line);
  });
  return findings;
}

Catalogue? _parseOrReport(
  String assetFile,
  String assetSource,
  List<Finding> findings,
) {
  try {
    return parseCatalogue(assetSource, nameOf: (_) => '');
  } on StrictJsonFormatException catch (error) {
    findings.add(
      Finding(
        assetFile,
        lineForFormatException(assetSource, error),
        error.message,
      ),
    );
    return null;
  } on FormatException catch (error) {
    findings.add(
      Finding(
        assetFile,
        lineForEntryError(assetSource, error.message),
        error.message,
      ),
    );
    return null;
  }
}

List<Finding> _coverageFindings(
  String assetFile,
  String assetSource,
  List<CatalogueEntry> entries,
) {
  final findings = <Finding>[];
  final entriesLine = _lineForKey(assetSource, 'entries');
  for (final cadence in Cadence.values) {
    if (entries.every((entry) => entry.cadence != cadence)) {
      findings.add(
        Finding(
          assetFile,
          entriesLine,
          'no entries with cadence "${cadence.name}" — all three cadences '
          'must be populated (AD-16)',
        ),
      );
    }
  }
  for (final zone in Zone.values) {
    if (entries.every((entry) => entry.zone != zone)) {
      findings.add(
        Finding(
          assetFile,
          entriesLine,
          'no entries with zone "${zone.name}" — every weekly zone must '
          'stay populated (A12.4, AD-16)',
        ),
      );
    }
  }
  final eligible = entries
      .where(
        (entry) => entry.size == Size.focus && entry.cadence != Cadence.daily,
      )
      .length;
  if (eligible < focusFloor) {
    findings.add(
      Finding(
        assetFile,
        entriesLine,
        'coverage floor breached: $eligible distinct focus non-daily '
        'entries, need at least $focusFloor — maintenance never counts and '
        'daily is excluded (AD-16)',
      ),
    );
  }
  return findings;
}

/// Runs the whole check against [repoRoot], printing one `file:line:
/// message` line per finding. Returns the process exit code: 0 clean,
/// 1 findings, 2 an input file missing.
Future<int> runCheck([String repoRoot = '']) async {
  final root = repoRoot.isEmpty ? '' : '$repoRoot/';
  final asset = File('$root$assetPath');
  final pubspec = File('$root$pubspecPath');
  if (!asset.existsSync()) {
    stderr.writeln('catalogue asset not found at ${asset.path}');
    return 2;
  }
  if (!pubspec.existsSync()) {
    stderr.writeln('pubspec not found at ${pubspec.path}');
    return 2;
  }
  final findings = scanCatalogue(
    assetFile: assetPath,
    assetSource: asset.readAsStringSync(),
    pubspecFile: pubspecPath,
    pubspecSource: pubspec.readAsStringSync(),
  );
  for (final finding in findings) {
    print(finding);
  }
  if (findings.isNotEmpty) {
    print(
      'catalogue floor check FAILED: ${findings.length} finding(s) — '
      'three populated cadences, five populated zones, $focusFloor '
      'distinct focus non-daily entries, and pubspec registration (AD-16)',
    );
    return 1;
  }
  print('catalogue floor check passed');
  return 0;
}

Future<void> main(List<String> args) async {
  exit(await runCheck(args.isEmpty ? '' : args.first));
}

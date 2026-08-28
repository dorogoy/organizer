// ignore_for_file: avoid_print
//
// The store seal (AD-21): no persistence API may be touched outside the
// store module — the log and the pool are the only replayable domain
// stores, and "no preferences, no side files, nothing outside the pool and
// log" must fail the build, not depend on review.
//
// Persistence-package imports — drift*, sqlite3*, sqflite*,
// shared_preferences* plus the named denylist below — are legal only
// inside the directories on [persistenceImportAllowlist]. The allowlist is
// a named constant grown only by explicit decision; today it holds
// `lib/store/` (the drift adapter, AD-21's Store) and `test/store/` (the
// adapter's own in-memory drift tests — they exercise the substrate and
// are part of its surface, an explicit decision recorded here).
//
// Scope: `lib/`, `packages/core/`, `tool/`, `test/` — excluding
// `test/fixtures/`, which holds this check's own fixtures. Scans run over
// the masked source (comments and string literals blanked, directive URIs
// kept) via check_core_purity's masking, so an import-shaped line inside a
// string literal cannot false-positive.
//
// Output contract (Story 1.1 AC 2): one `file:line: message` line per
// finding, exit 1 when any finding exists.
import 'dart:io';

import 'check_core_purity.dart';

/// Directory prefixes (repo-relative, forward slashes, trailing slash =
/// directory scope) where persistence imports are legal. Grown only by
/// explicit decision (AD-21).
const List<String> persistenceImportAllowlist = [
  'lib/store/', // the drift adapter — Store owns the two tables (AD-21)
  'test/store/', // the adapter's in-memory drift tests (explicit decision)
];

// Scope limit, recorded here as a decision: the seal polices `package:`
// persistence imports only. Relative imports of vendored persistence code
// and `dart:io`/`dart:ffi` side-file writes are unguarded until the
// Folder/Files modules arrive and this allowlist grows (AD-21).

/// Package-name prefixes whose every package is a persistence API.
const Set<String> persistenceImportPrefixes = {
  'drift',
  'sqlite3',
  'sqflite',
  'shared_preferences',
};

/// Named persistence packages the prefixes above do not already cover.
const Set<String> persistedPackageDenylist = {
  'hive',
  'hive_flutter',
  'isar',
  'isar_flutter_libs',
  'objectbox',
  'objectbox_flutter_libs',
  'sembast',
  'sembast_web',
  'realm',
  'realm_dart',
  'couchbase_lite_dart',
  'flutter_secure_storage',
  'get_storage',
  'mmkv',
};

/// True when [packageName] names a persistence package under the seal.
bool packageIsPersistence(String packageName) =>
    persistenceImportPrefixes.any(packageName.startsWith) ||
    persistedPackageDenylist.contains(packageName);

/// A directive span: the keyword at a line start or immediately after a
/// preceding directive's semicolon, through URIs and
/// configuration, to the terminating `;` — the same shape
/// check_core_purity scans.
final RegExp _directiveRegExp = RegExp(
  "(?:^|;)[ \\t]*(import|export|part(?:[ \\t]+of)?)(?:[^;'\"|'[^']*'|\"[^\"]*\")*;",
  multiLine: true,
);

final RegExp _quotedUriRegExp = RegExp("'([^']*)'|\"([^\"]*)\"");

int _lineOf(String text, int index) =>
    '\n'.allMatches(text.substring(0, index)).length + 1;

String _normalize(String path) =>
    path.replaceAll('\\', '/').replaceFirst('./', '');

const Set<String> rawStoreLibraries = {
  'package:organizer/store/connection.dart',
  'package:organizer/store/substrate.dart',
};

/// Scans one file's source for persistence imports outside the allowlist.
List<Finding> scanSource({
  required String file,
  required String source,
  List<String> allowlist = persistenceImportAllowlist,
}) {
  final findings = <Finding>[];
  final normalized = _normalize(file);
  final allowed = allowlist.any(normalized.startsWith);
  if (allowed) {
    return findings;
  }
  final masked = maskCommentsAndStrings(source);
  for (final directive in _directiveRegExp.allMatches(masked)) {
    final span = directive.group(0)!;
    for (final quoted in _quotedUriRegExp.allMatches(span)) {
      final uri = quoted.group(1) ?? quoted.group(2) ?? '';
      if (rawStoreLibraries.contains(uri)) {
        findings.add(
          Finding(
            file,
            _lineOf(masked, directive.start + quoted.start),
            "raw store library '$uri' is legal only inside "
            '${allowlist.join(', ')} (AD-21 store seal)',
          ),
        );
        continue;
      }
      if (!uri.startsWith('package:')) {
        continue;
      }
      final packageName = uri.substring(8).split('/').first;
      if (packageName.isEmpty || !packageIsPersistence(packageName)) {
        continue;
      }
      findings.add(
        Finding(
          file,
          _lineOf(masked, directive.start + quoted.start),
          "persistence import '$uri' is legal only inside "
          '${allowlist.join(', ')} (AD-21 store seal)',
        ),
      );
    }
  }
  findings.sort((a, b) => a.line.compareTo(b.line));
  return findings;
}

/// The directories this check owns, relative to the repository root.
const List<String> scopeRoots = ['lib', 'packages/core', 'tool', 'test'];

/// Collects every `.dart` file under [root] recursively.
List<File> _collectFiles(Directory root) {
  final files = <File>[];
  void walk(Directory dir) {
    for (final entity in dir.listSync(followLinks: false)) {
      if (entity is Directory) {
        final name = entity.uri.pathSegments.where((s) => s.isNotEmpty).last;
        if (name != '.dart_tool') {
          walk(entity);
        }
      } else if (entity is File && entity.path.endsWith('.dart')) {
        files.add(entity);
      }
    }
  }

  walk(root);
  files.sort((a, b) => a.path.compareTo(b.path));
  return files;
}

/// Runs the whole check against [repoRoot], printing one
/// `file:line: message` line per finding. Returns the process exit code:
/// 0 clean, 1 findings, 2 no lib/ to seal.
Future<int> runCheck([String repoRoot = '']) async {
  final root = repoRoot.isEmpty ? '' : '$repoRoot/';
  final libDir = Directory('${root}lib');
  if (!libDir.existsSync()) {
    stderr.writeln('lib/ not found at ${libDir.path}');
    return 2;
  }
  final findings = <Finding>[];
  for (final scope in scopeRoots) {
    final dir = Directory('$root$scope');
    if (!dir.existsSync()) {
      continue;
    }
    for (final file in _collectFiles(dir)) {
      // Paths are reported — and matched against the allowlist — relative
      // to the scanned root, so an absolute root still seals correctly.
      final scoped = root.isEmpty
          ? file.path
          : file.path.substring(root.length);
      if (_normalize(scoped).startsWith('test/fixtures/')) {
        continue;
      }
      findings.addAll(
        scanSource(file: scoped, source: file.readAsStringSync()),
      );
    }
  }
  for (final finding in findings) {
    print(finding);
  }
  if (findings.isNotEmpty) {
    print(
      'store seal check FAILED: ${findings.length} finding(s) — persistence '
      'APIs live only in the store module (AD-21)',
    );
    return 1;
  }
  print('store seal check passed');
  return 0;
}

Future<void> main(List<String> args) async {
  exit(await runCheck(args.isEmpty ? '' : args.first));
}

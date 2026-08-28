// ignore_for_file: avoid_print
//
// The forbidden-vocabulary lint (spine conventions — naming; §1.1 P2's "no
// field, flag or derived value anywhere may express lateness" as a
// build-time check): no identifier in scope may carry the nine banned
// tokens — `overdue`, `late`, `missed`, `pending`, `debt`, `streak`,
// `skippedCount`, `dueDate`, `backlog`.
//
// The scan is segment-aware: identifiers are split on camelCase humps and
// snake_case underscores, and a token matches a consecutive run of
// lowercased segments. So `translate` and `related` pass (single segments
// that merely contain the letters), `overdueItems` and `skippedCount` fail,
// and `Due` as a derived-fact suffix (`captureIsDue`, `warmReturnDue`)
// passes — `dueDate` is the two-segment run `due`+`date`, which those
// names never contain. `cardSkipped` passes: the vocabulary kind is a
// single act, and the ban is on totals (`skippedCount`), not on the act.
// ALL-CAPS runs stay whole — an uppercase letter only starts a segment at
// a camelCase hump or before the last word of an acronym — so
// `PENDING_QUEUE` → `pending`,`queue` (SCREAMING_SNAKE cannot evade the
// ban) and `parseURLHost` → `parse`,`url`,`host`.
//
// One Dart-keyword carve-out: the `late` modifier (`late final x = …`,
// `late Type x`) is a keyword in declaration position, never an identifier
// expressing lateness, so an exact `late` segment immediately followed by
// another word is not a finding. `isLate` and `lateSession` still fail.
//
// Scope: `lib/`, `packages/core/lib`, `tool/`, `test/` — excluding
// `test/fixtures/`, which holds this check's own fixtures. Scans run over
// the masked source (comments and string literals blanked, directive URIs
// kept) via check_core_purity's masking, so prose and string contents
// cannot false-positive.
//
// Output contract (Story 1.1 AC 2): one `file:line: message` line per
// finding, exit 1 when any finding exists.
import 'dart:io';

import 'check_core_purity.dart';

/// The nine banned tokens (spine conventions — naming), verbatim.
const List<String> bannedVocabulary = [
  'overdue',
  'late',
  'missed',
  'pending',
  'debt',
  'streak',
  'skippedCount',
  'dueDate',
  'backlog',
];

final RegExp _identifierRegExp = RegExp(r'[A-Za-z_][A-Za-z0-9_]*');

/// Splits one token into its lowercase segment list.
List<String> _tokenSegments(String token) => _identifierSegments(token);

/// Splits an identifier into lowercase segments at snake_case underscores
/// and camelCase humps (`skippedCount` → `skipped`,`count`;
/// `warmReturnDue` → `warm`,`return`,`due`).
List<String> _identifierSegments(String identifier) {
  final segments = <String>[];
  var current = StringBuffer();
  for (var i = 0; i < identifier.length; i++) {
    final c = identifier[i];
    if (c == '_') {
      if (current.isNotEmpty) {
        segments.add(current.toString().toLowerCase());
        current = StringBuffer();
      }
    } else if (c.toUpperCase() == c && c.toLowerCase() != c) {
      // An uppercase letter starts a new segment iff (a) the previous
      // character is a lowercase letter (a camelCase hump), or (b) the
      // previous character is an uppercase letter and the next character
      // exists and is lowercase (the last word of an acronym:
      // `parseURLHost` → parse,url,host). Everything else — including a
      // whole ALL-CAPS run — continues the current segment, so
      // `PENDING_QUEUE` segments as `pending`,`queue`.
      final previous = i > 0 ? identifier[i - 1] : null;
      final next = i + 1 < identifier.length ? identifier[i + 1] : null;
      final isBoundary =
          previous != null &&
          (previous.toLowerCase() == previous ||
              (previous.toUpperCase() == previous &&
                  next != null &&
                  next.toLowerCase() == next &&
                  next.toUpperCase() != next));
      if (isBoundary && current.isNotEmpty) {
        segments.add(current.toString().toLowerCase());
        current = StringBuffer();
      }
      current.write(c);
    } else {
      current.write(c);
    }
  }
  if (current.isNotEmpty) {
    segments.add(current.toString().toLowerCase());
  }
  return segments;
}

/// True when [identifier] carries one of the banned tokens as a
/// consecutive run of its segments.
bool identifierIsBanned(String identifier) {
  final segments = _identifierSegments(identifier);
  for (final token in bannedVocabulary) {
    final needle = _tokenSegments(token);
    if (needle.length > segments.length) {
      continue;
    }
    for (var start = 0; start + needle.length <= segments.length; start++) {
      var matches = true;
      for (var k = 0; k < needle.length; k++) {
        if (segments[start + k] != needle[k]) {
          matches = false;
          break;
        }
      }
      if (matches) {
        return true;
      }
    }
  }
  return false;
}

/// True when a banned match on [identifier] is the `late` modifier — the
/// exact keyword followed by another word (`late final x`, `late Type x`),
/// which is always declaration position and never an identifier.
bool _isKeywordNotIdentifier(String masked, RegExpMatch match) {
  if (match.group(0) != 'late') {
    return false;
  }
  final rest = masked.substring(match.end).trimLeft();
  return rest.isNotEmpty && RegExp('[A-Za-z_]').hasMatch(rest[0]);
}

/// Scans one file's source for banned identifiers.
List<Finding> scanSource({required String file, required String source}) {
  final findings = <Finding>[];
  final masked = maskCommentsAndStrings(source);
  for (final match in _identifierRegExp.allMatches(masked)) {
    final identifier = match.group(0)!;
    if (!identifierIsBanned(identifier)) {
      continue;
    }
    if (_isKeywordNotIdentifier(masked, match)) {
      continue;
    }
    findings.add(
      Finding(
        file,
        _lineOf(masked, match.start),
        "identifier '$identifier' carries a banned token — no field, flag or "
        'derived value may express lateness (spine conventions)',
      ),
    );
  }
  findings.sort((a, b) => a.line.compareTo(b.line));
  return findings;
}

int _lineOf(String text, int index) =>
    '\n'.allMatches(text.substring(0, index)).length + 1;

/// Collects every `.dart` file under [root] recursively, skipping files
/// inside any directory named in [excluded].
List<File> _collectFiles(Directory root, Set<String> excluded) {
  final files = <File>[];
  void walk(Directory dir) {
    for (final entity in dir.listSync(followLinks: false)) {
      if (entity is Directory) {
        final name = entity.uri.pathSegments.where((s) => s.isNotEmpty).last;
        if (!excluded.contains(name)) {
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

/// The directories this check owns, relative to the repository root.
const List<String> scopeRoots = ['lib', 'packages/core/lib', 'tool', 'test'];

/// Directories inside the scope roots that are fixture data, not shipped
/// code — this check's own fixtures live there.
const Set<String> excludedDirectoryNames = {'fixtures'};

/// Runs the whole check against [repoRoot], printing one
/// `file:line: message` line per finding. Returns the process exit code:
/// 0 clean, 1 findings, 2 no scope root to scan (a vacuous pass — the
/// check_core_purity contract for a missing tree).
Future<int> runCheck([String repoRoot = '']) async {
  final root = repoRoot.isEmpty ? '' : '$repoRoot/';
  final findings = <Finding>[];
  var scannedRoots = 0;
  for (final scope in scopeRoots) {
    final dir = Directory('$root$scope');
    if (!dir.existsSync()) {
      continue;
    }
    scannedRoots++;
    for (final file in _collectFiles(dir, excludedDirectoryNames)) {
      findings.addAll(
        scanSource(file: file.path, source: file.readAsStringSync()),
      );
    }
  }
  if (scannedRoots == 0) {
    stderr.writeln(
      'no scope root found to scan (expected one of: '
      '${scopeRoots.join(', ')})',
    );
    return 2;
  }
  for (final finding in findings) {
    print(finding);
  }
  if (findings.isNotEmpty) {
    print(
      'forbidden-vocabulary check FAILED: ${findings.length} finding(s) — '
      'the nine banned tokens may not appear as identifiers',
    );
    return 1;
  }
  print('forbidden-vocabulary check passed');
  return 0;
}

Future<void> main(List<String> args) async {
  exit(await runCheck(args.isEmpty ? '' : args.first));
}

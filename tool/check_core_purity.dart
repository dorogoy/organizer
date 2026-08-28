// ignore_for_file: avoid_print, prefer_interpolation_to_compose_strings
import 'dart:convert';
import 'dart:io';

/// A single purity violation: the offending file, its 1-based line, and what
/// is wrong. The output contract (Story 1.1 AC 2) requires the offending file
/// path and line to be named — a bare non-zero exit is not enough.
class Finding {
  const Finding(this.file, this.line, this.message);

  final String file;
  final int line;
  final String message;

  @override
  String toString() => '$file:$line: $message';
}

class _Str {
  _Str(this.quote, this.raw, this.triple, this.keep);

  final String quote;
  final bool raw;
  final bool triple;

  /// Directive URIs stay visible so the directive scan can run over the
  /// masked source (an import-shaped line inside an ordinary string literal
  /// must not match, and every URI of a conditional directive must).
  final bool keep;
}

class _Interp {
  int depth = 0;
}

bool _isIdentStartChar(String c) =>
    c.compareTo('A') >= 0 && c.compareTo('Z') <= 0 ||
    c.compareTo('a') >= 0 && c.compareTo('z') <= 0 ||
    c == '_';

bool _isIdentPartChar(String c) =>
    _isIdentStartChar(c) ||
    c.compareTo('0') >= 0 && c.compareTo('9') <= 0 ||
    c == '_';

/// True when the last non-whitespace word before [quoteIndex] is the
/// `import`, `export` or `part`/`of` keyword — a fallback that keeps a
/// directive URI visible even when the directive does not start its line
/// (e.g. a leading block comment on the same line).
bool _afterDirectiveKeyword(List<String> chars, int quoteIndex) {
  var j = quoteIndex - 1;
  while (j >= 0 &&
      (chars[j] == ' ' ||
          chars[j] == '\t' ||
          chars[j] == '\n' ||
          chars[j] == '\r')) {
    j--;
  }
  var k = j;
  while (k >= 0 && _isIdentPartChar(chars[k])) {
    k--;
  }
  final word = chars.sublist(k + 1, j + 1).join();
  return word == 'import' || word == 'export' || word == 'part' || word == 'of';
}

/// True when the line starting at [lineStart] begins (after spaces/tabs) with
/// the `import`, `export` or `part` keyword — the entry condition of
/// directive mode.
bool _startsWithDirectiveKeyword(List<String> chars, int lineStart) {
  var j = lineStart;
  while (j < chars.length && (chars[j] == ' ' || chars[j] == '\t')) {
    j++;
  }
  var k = j;
  while (k < chars.length && _isIdentPartChar(chars[k])) {
    k++;
  }
  final word = chars.sublist(j, k).join();
  return word == 'import' || word == 'export' || word == 'part';
}

/// Masks every comment and string literal with spaces so that banned-identifier
/// scanning cannot be fooled by prose or string contents, while preserving the
/// original line structure. Interpolation expressions (`${...}`) stay visible
/// because they are real code; `$identifier` interpolations are masked along
/// with their sigil (they cannot contain calls). Block comments nest (`/* /* */
/// */` is legal Dart) and are masked to their outermost terminator.
///
/// Directive context: from a line whose prefix is the `import`, `export` or
/// `part` keyword, every quoted string stays visible until the terminating
/// `;` — including across formatter-wrapped continuation lines — because all
/// of them are URIs or configuration of the directive, never code. A
/// conditional import's alternative URI therefore stays scannable.
String maskCommentsAndStrings(String source) {
  final chars = source.split('');
  final out = source.split('');
  final stack = <Object>[]; // _Str or _Interp entries; empty = plain code
  var inDirective = false;
  var i = 0;

  void blank(int index) {
    if (index < chars.length && chars[index] != '\n') {
      out[index] = ' ';
    }
  }

  while (i < chars.length) {
    final c = chars[i];
    final next = i + 1 < chars.length ? chars[i + 1] : '';
    final top = stack.isEmpty ? null : stack.last;

    if (top is! _Str) {
      // Code context: the base of the file, or inside an interpolation.
      if ((i == 0 || chars[i - 1] == '\n') && !inDirective) {
        inDirective = _startsWithDirectiveKeyword(chars, i);
      }
      if (c == '/' && next == '/') {
        while (i < chars.length && chars[i] != '\n') {
          blank(i);
          i++;
        }
      } else if (c == '/' && next == '*') {
        // Block comments nest in Dart: mask to the matching outer */.
        var depth = 1;
        blank(i);
        blank(i + 1);
        i += 2;
        while (i < chars.length && depth > 0) {
          final cc = chars[i];
          final nn = i + 1 < chars.length ? chars[i + 1] : '';
          if (cc == '/' && nn == '*') {
            depth++;
            blank(i);
            blank(i + 1);
            i += 2;
          } else if (cc == '*' && nn == '/') {
            depth--;
            blank(i);
            blank(i + 1);
            i += 2;
          } else {
            blank(i);
            i++;
          }
        }
      } else if (c == "'" || c == '"') {
        var raw = false;
        if (i > 0 &&
            chars[i - 1] == 'r' &&
            (i == 1 || !_isIdentPartChar(chars[i - 2]))) {
          raw = true;
        }
        final n2 = i + 2 < chars.length ? chars[i + 2] : '';
        final triple = next == c && n2 == c;
        final keep = inDirective || _afterDirectiveKeyword(chars, i);
        stack.add(_Str(c, raw, triple, keep));
        final end = i + (triple ? 3 : 1);
        if (!keep) {
          for (var b = i; b < end; b++) {
            blank(b);
          }
        }
        i = end;
      } else if (top is _Interp && c == '{') {
        top.depth++;
        i++;
      } else if (top is _Interp && c == '}') {
        if (top.depth == 0) {
          stack.removeLast();
          blank(i);
        } else {
          top.depth--;
        }
        i++;
      } else if (c == ';' && inDirective && top is! _Interp) {
        inDirective = false;
        i++;
      } else {
        i++;
      }
      continue;
    }

    // String context.
    if (top.keep) {
      // Directive URI: leave everything visible; only locate the end quote,
      // honouring escapes so the string does not end early.
      if (!top.raw && c == r'\' && i + 1 < chars.length) {
        i += 2;
      } else if (top.raw && c == r'\' && next == top.quote) {
        i += 2;
      } else if (c == top.quote) {
        if (top.triple) {
          final n1 = i + 1 < chars.length ? chars[i + 1] : '';
          final n2 = i + 2 < chars.length ? chars[i + 2] : '';
          if (n1 == top.quote && n2 == top.quote) {
            stack.removeLast();
            i += 3;
          } else {
            i++;
          }
        } else {
          stack.removeLast();
          i++;
        }
      } else {
        i++;
      }
      continue;
    }

    if (!top.raw && c == r'\') {
      blank(i);
      blank(i + 1);
      i += 2;
    } else if (top.raw && c == r'\' && next == top.quote) {
      // Raw strings may contain \' — both characters are content.
      blank(i);
      blank(i + 1);
      i += 2;
    } else if (!top.raw && c == r'$' && next == '{') {
      blank(i);
      blank(i + 1);
      i += 2;
      stack.add(_Interp());
    } else if (!top.raw && c == r'$' && _isIdentStartChar(next)) {
      blank(i);
      i++;
      while (i < chars.length && _isIdentPartChar(chars[i])) {
        blank(i);
        i++;
      }
    } else if (c == top.quote) {
      if (top.triple) {
        final n1 = i + 1 < chars.length ? chars[i + 1] : '';
        final n2 = i + 2 < chars.length ? chars[i + 2] : '';
        if (n1 == top.quote && n2 == top.quote) {
          blank(i);
          blank(i + 1);
          blank(i + 2);
          stack.removeLast();
          i += 3;
        } else {
          blank(i);
          i++;
        }
      } else {
        blank(i);
        stack.removeLast();
        i++;
      }
    } else if (c == '\n' && !top.triple) {
      // Unterminated single-line string (malformed input): recover so the
      // rest of the file still gets scanned.
      stack.removeLast();
      i++;
    } else {
      blank(i);
      i++;
    }
  }

  return out.join();
}

int _lineOf(String text, int index) =>
    '\n'.allMatches(text.substring(0, index)).length + 1;

/// A directive span: the keyword at a line start, through URIs and
/// configuration, to the terminating `;` — across wrapped continuation lines,
/// and never stopping at a `;` inside one of the directive's own URIs.
final RegExp _directiveRegExp = RegExp(
  "^[ \\t]*(import|export|part(?:[ \\t]+of)?)(?:[^;'\"|'[^']*'|\"[^\"]*\")*;",
  multiLine: true,
);

/// Every quoted string inside a directive span (all of them URIs).
final RegExp _quotedUriRegExp = RegExp("'([^']*)'|\"([^\"]*)\"");

const Set<String> _bannedDartLibraries = {
  'dart:io',
  'dart:ui',
  'dart:isolate',
  'dart:ffi',
  'dart:html',
  'dart:js',
  'dart:web',
  'dart:developer',
};

final Map<RegExp, String> _bannedIdentifierRules = {
  RegExp(r'\bRandom\b'):
      "nondeterminism: 'Random' is banned in the core (AD-3)",
  RegExp(r'\bDateTime\s*\.\s*now\b'):
      "wall-clock read 'DateTime.now()' is banned in the core (AD-3)",
  RegExp(r'\bclock\s*\.\s*now\s*\('):
      "ambient clock read 'clock.now()' is banned in the core (AD-3)",
  RegExp(r'\bStopwatch\b'): "'Stopwatch' reads elapsed wall time (AD-3)",
  RegExp(r'\bTimer\b'): "'Timer' introduces ambient time (AD-3)",
  RegExp(r'\bProcess\b'): "'Process' reaches the platform (AD-3)",
  RegExp(r'\bFile\b'): "'File' performs I/O (AD-3)",
  RegExp(r'\bDirectory\b'): "'Directory' performs I/O (AD-3)",
  RegExp(r'\bDriftStore\b'): 'adapter type named inside the core (AD-5)',
  RegExp(r'\bSafFolder\b'): 'adapter type named inside the core (AD-5)',
  RegExp(r'\bByokSlicer\b'): 'adapter type named inside the core (AD-5)',
  RegExp(r'\bCredentialVault\b'): 'shell type named inside the core (AD-5)',
};

/// Tail shared by both mutable-state patterns: one declarator or a
/// comma-separated declarator list, ending in an assignment (`=>` excluded)
/// or a semicolon.
const String _declarators = r'\w+\s*(?:,\s*\w+\s*)*(?:=(?!>)|;)';

// `late final` and `late const` are immutable, so they are excluded from the
// mutable-state patterns at the lookahead position where the `late` modifier
// is consumed — both at top level and for static fields.
final RegExp _topLevelMutableRegExp = RegExp(
  r'^(?!import\b|export\b|library\b|part\b|typedef\b|class\b|enum\b|mixin\b|extension\b|abstract\b|sealed\b|final\b|const\b|late\s+final\b|late\s+const\b|external\b|static\b|void\b|get\b|set\b|operator\b|factory\b|new\b)'
          r'(?:late\s+)?(?:[A-Za-z_][\w.<>,\s\[\]?]*?)\s+' +
      _declarators,
  multiLine: true,
);

final RegExp _staticMutableRegExp = RegExp(
  r'\bstatic\s+(?!(?:const|final|void|late\s+const|late\s+final)\b)(?:late\s+)?(?:var\b|[A-Za-z_][\w.<>,\s\[\]?]*?)\s+' +
      _declarators,
);

/// Scans one file's source for every source-level purity rule: banned
/// imports, banned identifiers, mutable top-level or static state. All scans
/// run over the masked source, so a directive-shaped line inside an ordinary
/// string literal cannot false-positive — while every URI of every directive
/// (including conditional alternatives) is validated.
List<Finding> scanSource({
  required String file,
  required String source,
  Set<String> allowedPackages = const {},
}) {
  final findings = <Finding>[];
  final masked = maskCommentsAndStrings(source);

  for (final directive in _directiveRegExp.allMatches(masked)) {
    final keyword = directive.group(1)!;
    final span = directive.group(0)!;
    final spanStart = directive.start;
    final directiveLine = _lineOf(masked, spanStart);
    if (keyword.startsWith('part')) {
      if (_quotedUriRegExp.hasMatch(span)) {
        findings.add(
          Finding(
            file,
            directiveLine,
            'part directives are banned in the core — the sealed tree holds whole files only (AD-5)',
          ),
        );
      }
      continue;
    }
    for (final quoted in _quotedUriRegExp.allMatches(span)) {
      final uri = quoted.group(1) ?? quoted.group(2) ?? '';
      if (uri.isEmpty) {
        continue;
      }
      final line = _lineOf(masked, spanStart + quoted.start);
      if (uri.startsWith('dart:')) {
        if (_bannedDartLibraries.contains(uri)) {
          findings.add(
            Finding(file, line, "banned SDK import '$uri' (AD-3, AD-5)"),
          );
        }
      } else if (uri.startsWith('package:')) {
        final name = uri.substring(8).split('/').first;
        if (name == 'flutter') {
          findings.add(
            Finding(
              file,
              line,
              "Flutter import '$uri' is banned in the core (AD-5)",
            ),
          );
        } else if (name.startsWith('drift')) {
          findings.add(
            Finding(
              file,
              line,
              "drift import '$uri' is banned in the core (AD-5)",
            ),
          );
        } else if (name != 'core' && !allowedPackages.contains(name)) {
          findings.add(
            Finding(
              file,
              line,
              "import '$uri' is not a dependency of packages/core (AD-5)",
            ),
          );
        }
      } else if (uri.contains('..')) {
        findings.add(
          Finding(
            file,
            line,
            "relative import '$uri' escapes the core lib tree (AD-5)",
          ),
        );
      }
    }
  }

  void reportMatches(RegExp pattern, String message) {
    for (final match in pattern.allMatches(masked)) {
      findings.add(Finding(file, _lineOf(masked, match.start), message));
    }
  }

  _bannedIdentifierRules.forEach(reportMatches);
  reportMatches(
    _topLevelMutableRegExp,
    'mutable top-level state is banned in the core (AD-3)',
  );
  reportMatches(
    _staticMutableRegExp,
    'mutable static state is banned in the core (AD-3)',
  );

  findings.sort((a, b) => a.line.compareTo(b.line));
  return findings;
}

/// Every dependency key (with its 1-based line) in the `dependencies:` and
/// `dependency_overrides:` sections. Keys may be indented by any amount: the
/// first key's indentation defines the section level and deeper lines belong
/// to that key's value.
List<({int line, String name})> _dependencyEntries(String text) {
  final entries = <({int line, String name})>[];
  final lines = text.split('\n');
  var inSection = false;
  var level = -1;
  for (var i = 0; i < lines.length; i++) {
    final line = lines[i];
    final top = RegExp(r'^([A-Za-z_][\w-]*):\s*(?:#.*)?$').firstMatch(line);
    if (top != null) {
      inSection =
          top.group(1) == 'dependencies' ||
          top.group(1) == 'dependency_overrides';
      level = -1;
      continue;
    }
    if (!inSection) {
      continue;
    }
    final key = RegExp(r'^(\s*)([A-Za-z_][\w-]*):').firstMatch(line);
    if (key == null) {
      continue;
    }
    final indent = key.group(1)!.length;
    if (level < 0) {
      level = indent;
    }
    if (indent == level) {
      entries.add((line: i + 1, name: key.group(2)!));
    }
  }
  return entries;
}

/// Flags a `flutter:` key or a flutter/drift dependency (including one under
/// `dependency_overrides:`) in a pubspec.
List<Finding> scanPubspec({required String file, required String text}) {
  final findings = <Finding>[];
  final lines = text.split('\n');
  for (var i = 0; i < lines.length; i++) {
    if (lines[i].startsWith('flutter:')) {
      findings.add(
        Finding(
          file,
          i + 1,
          'packages/core must not declare a flutter key (AD-5)',
        ),
      );
    }
  }
  for (final entry in _dependencyEntries(text)) {
    if (entry.name == 'flutter' || entry.name.startsWith('drift')) {
      findings.add(
        Finding(
          file,
          entry.line,
          "packages/core must not depend on '${entry.name}' (AD-5)",
        ),
      );
    }
  }
  return findings;
}

Set<String> dependencyNames(String pubspecText) =>
    _dependencyEntries(pubspecText).map((entry) => entry.name).toSet();

/// Asserts the resolved dependency closure of packages/core contains no
/// flutter, drift or plugin package. A source-only scan would miss a
/// transitive pull-in; this closes it (Story 1.1 AC 1). Malformed
/// package_config entries are reported as findings, never crashes.
List<Finding> checkDependencyClosure(Directory corePackage) {
  final findings = <Finding>[];
  final configPath = '${corePackage.path}/.dart_tool/package_config.json';
  final configFile = File(configPath);
  if (!configFile.existsSync()) {
    findings.add(
      Finding(
        configPath,
        1,
        'dependency closure not resolved — run make deps first',
      ),
    );
    return findings;
  }
  final Object decoded;
  try {
    decoded = jsonDecode(configFile.readAsStringSync());
  } catch (error) {
    findings.add(
      Finding(configPath, 1, 'package_config.json is not valid JSON ($error)'),
    );
    return findings;
  }
  if (decoded is! Map<String, dynamic> || decoded['packages'] is! List) {
    findings.add(
      Finding(
        configPath,
        1,
        'package_config.json is malformed (no packages list)',
      ),
    );
    return findings;
  }
  for (final entry in decoded['packages'] as List) {
    if (entry is! Map) {
      findings.add(
        Finding(
          configPath,
          1,
          'malformed package_config entry (skipped): $entry',
        ),
      );
      continue;
    }
    final name = entry['name'];
    if (name is! String) {
      findings.add(
        Finding(
          configPath,
          1,
          'package_config entry without a name (skipped): $entry',
        ),
      );
      continue;
    }
    if (name == 'core') {
      continue;
    }
    if (name == 'flutter' || name.startsWith('drift')) {
      findings.add(
        Finding(
          configPath,
          1,
          "'$name' is inside packages/core's dependency closure (AD-5)",
        ),
      );
      continue;
    }
    final rootUri = entry['rootUri'];
    if (rootUri is! String) {
      findings.add(
        Finding(configPath, 1, "package '$name' has no rootUri (skipped)"),
      );
      continue;
    }
    final String root;
    if (rootUri.startsWith('file://')) {
      root = Uri.parse(rootUri).toFilePath();
    } else {
      root = '${corePackage.path}/.dart_tool/$rootUri';
    }
    final pubspec = File('$root/pubspec.yaml');
    if (pubspec.existsSync()) {
      if (RegExp(
        r'^flutter:',
        multiLine: true,
      ).hasMatch(pubspec.readAsStringSync())) {
        findings.add(
          Finding(
            configPath,
            1,
            "plugin/Flutter package '$name' is inside packages/core's dependency closure (AD-5)",
          ),
        );
      }
    }
  }
  return findings;
}

/// Walks every `.dart` file under a core `lib/` directory and returns all
/// findings, ordered by file then line. The tree is hermetic: a symlinked
/// `.dart` entry is reported (followLinks stays off), and nothing outside the
/// tree compiles into it.
List<Finding> scanCoreLib(
  Directory libDir, {
  Set<String> allowedPackages = const {},
}) {
  final files = <File>[];
  final findings = <Finding>[];
  void collect(Directory dir) {
    for (final entity in dir.listSync(followLinks: false)) {
      if (entity is Link && entity.path.endsWith('.dart')) {
        findings.add(
          Finding(
            entity.path,
            1,
            'a symlinked .dart file is banned in the core lib tree — hermetic files only (AD-5)',
          ),
        );
      } else if (entity is Directory) {
        collect(entity);
      } else if (entity is File && entity.path.endsWith('.dart')) {
        files.add(entity);
      }
    }
  }

  collect(libDir);
  files.sort((a, b) => a.path.compareTo(b.path));
  for (final file in files) {
    findings.addAll(
      scanSource(
        file: file.path,
        source: file.readAsStringSync(),
        allowedPackages: allowedPackages,
      ),
    );
  }
  findings.sort((a, b) {
    final byFile = a.file.compareTo(b.file);
    return byFile != 0 ? byFile : a.line.compareTo(b.line);
  });
  return findings;
}

/// Runs the whole check against [repoRoot] (a directory holding
/// `packages/core`), printing one `file:line: message` line per finding.
/// Returns the process exit code: 0 clean, 1 findings, 2 no core package.
/// With the empty default this resolves `packages/core` relative to the
/// working directory exactly as before.
Future<int> runCheck([String repoRoot = '']) async {
  final coreDir = Directory(
    repoRoot.isEmpty ? 'packages/core' : '$repoRoot/packages/core',
  );
  final pubspecFile = File('${coreDir.path}/pubspec.yaml');
  if (!pubspecFile.existsSync()) {
    stderr.writeln('core package not found at ${coreDir.path}');
    return 2;
  }

  final pubspecText = pubspecFile.readAsStringSync();
  final allowed = dependencyNames(pubspecText)
    ..remove('flutter')
    ..removeWhere((name) => name.startsWith('drift'));

  final findings = <Finding>[];
  findings.addAll(scanPubspec(file: pubspecFile.path, text: pubspecText));
  findings.addAll(
    scanCoreLib(Directory('${coreDir.path}/lib'), allowedPackages: allowed),
  );
  findings.addAll(checkDependencyClosure(coreDir));

  for (final finding in findings) {
    print(finding);
  }
  if (findings.isNotEmpty) {
    print('core purity check FAILED: ${findings.length} finding(s)');
    return 1;
  }
  print('core purity check passed');
  return 0;
}

Future<void> main(List<String> args) async {
  exit(await runCheck(args.isEmpty ? '' : args.first));
}

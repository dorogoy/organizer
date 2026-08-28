// ignore_for_file: avoid_print
//
// AD-15's literal ban, as a build-time check: no string literal may reach a
// widget, and no runtime sentence may be assembled by concatenation.
//
// The shipped ARB (`lib/l10n/app_es.arb`) is the single string table;
// `lib/strings/` holds only generated accessors. So this scan bans every
// string literal in `lib/**.dart` outside the two exempt places — the
// generated accessors, and `lib/ui/tokens.dart`, the single token file —
// every value lands there exactly once, and its two format-rule patterns
// never reach a widget, so the whole file is exempt as the one place
// literals may live. Directive URIs (import/export/part,
// through the terminating `;`, across formatter-wrapped lines) are exempt,
// as in check_core_purity.dart. With literals banned outright, runtime
// sentence concatenation has nothing left to concatenate: the sole permitted
// interpolation is a numeral (or the consent gate's provider token)
// substituted into an ARB placeholder through the generated accessors,
// which carry no literals of our own.
//
// Output contract (Story 1.1 AC 2): one `file:line: message` line per
// finding, exit 1 when any finding exists.
import 'dart:io';

/// A string literal found in source, with its 1-based start line.
class LiteralFinding {
  const LiteralFinding(this.file, this.line);

  final String file;
  final int line;

  @override
  String toString() => '$file:$line: string literal reaches lib/ (AD-15)';
}

bool _isIdentPart(int code, String? c) {
  if (c == null) {
    return false;
  }
  return c == '_' ||
      (c.compareTo('a') >= 0 && c.compareTo('z') <= 0) ||
      (c.compareTo('A') >= 0 && c.compareTo('Z') <= 0) ||
      (c.compareTo('0') >= 0 && c.compareTo('9') <= 0);
}

bool _lineStartsWithDirective(String source, int from) {
  var k = from;
  while (k < source.length && (source[k] == ' ' || source[k] == '\t')) {
    k++;
  }
  for (final word in const ['import', 'export', 'part']) {
    if (source.startsWith(word, k) &&
        !_isIdentPart(
          0,
          k + word.length < source.length ? source[k + word.length] : null,
        )) {
      return true;
    }
  }
  return false;
}

/// Locates the span of every non-directive string literal in [source],
/// skipping comments (line, and nested block), raw/triple strings, escape
/// sequences — and `${…}` interpolation bodies, whose braces nest and
/// whose embedded quotes belong to the body, not the enclosing literal —
/// the same lexing judgement `check_core_purity.maskCommentsAndStrings`
/// applies. Directive URIs are exempt. Malformed input (an unterminated
/// single-line string) recovers at the newline so the rest of the file
/// still scans.
List<(int, int)> stringLiteralSpans(String source) {
  final spans = <(int, int)>[];
  var inDirective = false;
  var lineStartHandled = -1;
  var i = 0;

  while (i < source.length) {
    final c = source[i];
    final next = i + 1 < source.length ? source[i + 1] : '';

    if (c == '/' && next == '/') {
      while (i < source.length && source[i] != '\n') {
        i++;
      }
    } else if (c == '/' && next == '*') {
      var depth = 1;
      i += 2;
      while (i < source.length && depth > 0) {
        if (source[i] == '/' && i + 1 < source.length && source[i + 1] == '*') {
          depth++;
          i += 2;
        } else if (source[i] == '*' &&
            i + 1 < source.length &&
            source[i + 1] == '/') {
          depth--;
          i += 2;
        } else {
          i++;
        }
      }
    } else if (c == ';') {
      inDirective = false;
      i++;
    } else if (c != '\n' &&
        (i == 0 || source[i - 1] == '\n') &&
        !inDirective &&
        lineStartHandled != i) {
      // Line-start directive detection: set state once per line start, then
      // re-examine this character from the top of the loop (a comment or a
      // string opening on the same line must be judged in that state).
      lineStartHandled = i;
      inDirective = _lineStartsWithDirective(source, i);
    } else if (c == "'" || c == '"') {
      var raw = false;
      if (i > 0 &&
          source[i - 1] == 'r' &&
          (i == 1 || !_isIdentPart(0, source[i - 2]))) {
        raw = true;
      }
      final triple = next == c && (i + 2 < source.length && source[i + 2] == c);
      final start = i;
      i += triple ? 3 : 1;
      var unterminated = false;
      var interpDepth = 0;
      while (true) {
        if (i >= source.length) {
          unterminated = true;
          break;
        }
        final sc = source[i];
        if (!raw && sc == r'\' && interpDepth == 0) {
          i += 2;
          continue;
        }
        // `${…}` bodies are code, not string content: braces nest, quotes
        // inside are consumed by the body (the enclosing literal is already
        // a finding), and a newline inside a multi-line interpolation does
        // not terminate a single-line string.
        if (!raw &&
            sc == r'$' &&
            i + 1 < source.length &&
            source[i + 1] == '{') {
          interpDepth++;
          i += 2;
          continue;
        }
        if (interpDepth > 0) {
          if (sc == '{') {
            interpDepth++;
          } else if (sc == '}') {
            interpDepth--;
          }
          i++;
          continue;
        }
        if (sc == '\n' && !triple) {
          unterminated = true;
          break;
        }
        if (sc == c) {
          if (triple) {
            final a = i + 1 < source.length ? source[i + 1] : '';
            final b = i + 2 < source.length ? source[i + 2] : '';
            if (a == c && b == c) {
              i += 3;
              break;
            }
            i++;
          } else {
            i++;
            break;
          }
        } else {
          i++;
        }
      }
      if (!unterminated && !inDirective) {
        spans.add((start, i));
      }
    } else {
      i++;
    }
  }
  return spans;
}

int _lineOf(String text, int index) =>
    '\n'.allMatches(text.substring(0, index)).length + 1;

/// Scans one file's source for banned string literals.
List<LiteralFinding> scanSource({
  required String file,
  required String source,
}) {
  return stringLiteralSpans(source)
      .map((span) => LiteralFinding(file, _lineOf(source, span.$1)))
      .toList();
}

/// Walks every `.dart` file under [libDir] except the exempt generated
/// accessors (`lib/strings/`) and the token file (its two format-rule
/// patterns are documented, never widget-bound).
List<LiteralFinding> scanLib(Directory libDir) {
  final findings = <LiteralFinding>[];
  final files = <File>[];
  final exemptStrings = '${libDir.path}/strings';
  final exemptTokens = '${libDir.path}/ui/tokens.dart';
  void collect(Directory dir) {
    for (final entity in dir.listSync(followLinks: false)) {
      if (entity is Directory) {
        if (entity.path == exemptStrings) {
          continue;
        }
        collect(entity);
      } else if (entity is File && entity.path.endsWith('.dart')) {
        if (entity.path == exemptTokens) {
          continue;
        }
        files.add(entity);
      }
    }
  }

  collect(libDir);
  files.sort((a, b) => a.path.compareTo(b.path));
  for (final file in files) {
    findings.addAll(
      scanSource(file: file.path, source: file.readAsStringSync()),
    );
  }
  return findings;
}

Future<int> runCheck([String repoRoot = '']) async {
  final libDir = Directory(repoRoot.isEmpty ? 'lib' : '$repoRoot/lib');
  if (!libDir.existsSync()) {
    stderr.writeln('lib/ not found at ${libDir.path}');
    return 2;
  }
  final findings = scanLib(libDir);
  for (final finding in findings) {
    print(finding);
  }
  if (findings.isNotEmpty) {
    print(
      'no-literal-strings check FAILED: ${findings.length} finding(s) — '
      'every string enters through lib/l10n/app_es.arb (AD-15)',
    );
    return 1;
  }
  print('no-literal-strings check passed');
  return 0;
}

Future<void> main(List<String> args) async {
  exit(await runCheck(args.isEmpty ? '' : args.first));
}

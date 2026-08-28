// ignore_for_file: avoid_print
//
// The 200% floor (UX-DR45, NFR6) as a build-time check: one lint banning
// all five text-scaling escapes — the first two alone leave the obvious
// workarounds open, so all five are named (architecture spine,
// Cross-cutting — text scaling):
//
//   1. `maxLines` anywhere;
//   2. `TextOverflow.ellipsis`;
//   3. `FittedBox`;
//   4. a `TextScaler`/`textScaleFactor` override (`textScaler:` or a
//      MediaQuery scaling wrapper); reading the ambient scaler stays legal;
//   5. a fixed-height text container — direct height/max-height constraints
//      around a Text/RichText/SelectableText/TextField/TextFormField, whether
//      the value is a literal, token or expression. Minimum heights remain
//      legal because they allow text to grow. `TextStyle(height: …)` is a
//      multiplier line-height and remains legal.
//
// Scans `lib/**.dart` over the masked source (comments and string literals
// blanked, directive URIs kept) using check_core_purity's masking, so prose
// and string contents cannot false-positive. `lib/strings/` is exempt as
// generated. Output contract: `file:line: message` per finding, exit 1 on
// any.
import 'dart:io';

import 'check_core_purity.dart';

class ScalingFinding {
  const ScalingFinding(this.file, this.line, this.message);

  final String file;
  final int line;
  final String message;

  @override
  String toString() => '$file:$line: $message';
}

final _bannedIdentifierRules = <RegExp, String>{
  RegExp(r'\bmaxLines\s*:'):
      'maxLines is banned — text grows and the screen scrolls (UX-DR45)',
  RegExp(r'\bTextOverflow\s*\.\s*ellipsis\b'):
      'TextOverflow.ellipsis is banned — nothing truncates (UX-DR45)',
  RegExp(r'\bFittedBox\b'):
      'FittedBox is banned — it shrinks text to fit (UX-DR45)',
  RegExp(r'\btextScaleFactor\b'):
      'textScaleFactor overrides are banned — the system scaler governs '
      '(UX-DR45)',
  RegExp(r'\btextScaler\s*:'):
      'textScaler: overrides are banned — the system scaler governs '
      '(UX-DR45)',
  RegExp(r'\bMediaQuery\s*\.\s*with(?:No|Clamped)TextScaling\b'):
      'MediaQuery text-scaling overrides are banned — the system scaler '
      'governs (UX-DR45)',
};

/// Balanced-paren argument span of a widget constructor starting at [start].
int? _constructorSpan(String text, int openParen) {
  var depth = 0;
  for (var i = openParen; i < text.length; i++) {
    final c = text[i];
    if (c == '(') {
      depth++;
    } else if (c == ')') {
      depth--;
      if (depth == 0) {
        return i;
      }
    }
  }
  return null;
}

final _textWidgetRegExp = RegExp(
  r'\b(?:Text|RichText|SelectableText|EditableText|TextField|TextFormField)'
  r'\s*(?:\(|\.)',
);
final _fixedHeightContainerRegExp = RegExp(
  r'\b(?:SizedBox(?:\.(?:fromSize|square|expand))?|Container|'
  r'AnimatedContainer|ConstrainedBox|FractionallySizedBox|LimitedBox)\s*\(',
);

String? _directNamedArgument(String args, String name) {
  var parens = 0;
  var brackets = 0;
  var braces = 0;
  for (var i = 1; i < args.length - 1; i++) {
    final c = args[i];
    if (c == '(') {
      parens++;
    } else if (c == ')') {
      parens--;
    } else if (c == '[') {
      brackets++;
    } else if (c == ']') {
      brackets--;
    } else if (c == '{') {
      braces++;
    } else if (c == '}') {
      braces--;
    }
    if (parens != 0 || brackets != 0 || braces != 0) {
      continue;
    }
    final match = RegExp('\\b${RegExp.escape(name)}\\s*:')
        .matchAsPrefix(args, i);
    if (match == null) {
      continue;
    }
    final valueStart = match.end;
    var valueParens = 0;
    var valueBrackets = 0;
    var valueBraces = 0;
    var end = valueStart;
    while (end < args.length - 1) {
      final valueChar = args[end];
      if (valueChar == '(') {
        valueParens++;
      } else if (valueChar == ')') {
        if (valueParens == 0) {
          break;
        }
        valueParens--;
      } else if (valueChar == '[') {
        valueBrackets++;
      } else if (valueChar == ']') {
        valueBrackets--;
      } else if (valueChar == '{') {
        valueBraces++;
      } else if (valueChar == '}') {
        valueBraces--;
      } else if (valueChar == ',' &&
          valueParens == 0 &&
          valueBrackets == 0 &&
          valueBraces == 0) {
        break;
      }
      end++;
    }
    return args.substring(valueStart, end).trim();
  }
  return null;
}

bool _hasFixedHeight(String constructor, String args) {
  bool present(String name) {
    final value = _directNamedArgument(args, name);
    return value != null && value != 'null';
  }

  if (constructor.startsWith('SizedBox.')) {
    if (constructor == 'SizedBox.expand') {
      return true;
    }
    return present(constructor == 'SizedBox.square' ? 'dimension' : 'size');
  }
  if (constructor == 'SizedBox' ||
      constructor == 'Container' ||
      constructor == 'AnimatedContainer') {
    if (present('height')) {
      return true;
    }
    final constraints = _directNamedArgument(args, 'constraints');
    return constraints != null &&
        RegExp(r'\b(?:height|maxHeight)\s*:').hasMatch(constraints);
  }
  if (constructor == 'FractionallySizedBox') {
    return present('heightFactor');
  }
  if (constructor == 'LimitedBox') {
    return present('maxHeight');
  }
  final constraints = _directNamedArgument(args, 'constraints');
  return constraints != null &&
      RegExp(r'\b(?:height|maxHeight)\s*:').hasMatch(constraints);
}

List<ScalingFinding> _fixedHeightFindings(String file, String masked) {
  final findings = <ScalingFinding>[];
  for (final match in _fixedHeightContainerRegExp.allMatches(masked)) {
    final constructor = masked.substring(match.start, match.end - 1).trim();
    final openParen = match.end - 1;
    final close = _constructorSpan(masked, openParen);
    if (close == null) {
      continue;
    }
    final args = masked.substring(openParen, close + 1);
    if (_hasFixedHeight(constructor, args) &&
        _textWidgetRegExp.hasMatch(args)) {
      findings.add(
        ScalingFinding(
          file,
          _lineOf(masked, match.start),
          'fixed-height container around text is banned — the box grows '
          'through padding, never a fixed height (UX-DR45)',
        ),
      );
    }
  }
  return findings;
}

int _lineOf(String text, int index) =>
    '\n'.allMatches(text.substring(0, index)).length + 1;

/// Scans one file's masked source for the five text-scaling escapes.
List<ScalingFinding> scanSource({
  required String file,
  required String source,
}) {
  final masked = maskCommentsAndStrings(source);
  final findings = <ScalingFinding>[];
  void reportMatches(RegExp pattern, String message) {
    for (final match in pattern.allMatches(masked)) {
      findings.add(ScalingFinding(file, _lineOf(masked, match.start), message));
    }
  }

  _bannedIdentifierRules.forEach(reportMatches);
  findings.addAll(_fixedHeightFindings(file, masked));
  findings.sort((a, b) => a.line.compareTo(b.line));
  return findings;
}

/// Walks every `.dart` file under [libDir] except generated `lib/strings/`.
List<ScalingFinding> scanLib(Directory libDir) {
  final findings = <ScalingFinding>[];
  final files = <File>[];
  final exemptStrings = '${libDir.path}/strings';
  void collect(Directory dir) {
    for (final entity in dir.listSync(followLinks: false)) {
      if (entity is Directory) {
        if (entity.path == exemptStrings) {
          continue;
        }
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
      scanSource(file: file.path, source: file.readAsStringSync()),
    );
  }
  findings.sort((a, b) {
    final byFile = a.file.compareTo(b.file);
    return byFile != 0 ? byFile : a.line.compareTo(b.line);
  });
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
      'text-scaling check FAILED: ${findings.length} finding(s) — '
      'the 200% floor is met by growing and scrolling (UX-DR45)',
    );
    return 1;
  }
  print('text-scaling check passed');
  return 0;
}

Future<void> main(List<String> args) async {
  exit(await runCheck(args.isEmpty ? '' : args.first));
}

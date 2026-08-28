import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../tool/check_text_scaling.dart';

Directory _makeTemp(String label) {
  final dir = Directory.systemTemp.createTempSync('text_scaling_$label');
  addTearDown(() => dir.deleteSync(recursive: true));
  return dir;
}

void main() {
  group('the five escapes are each banned, with the line named', () {
    test('maxLines', () {
      const source = "Text('Hola', maxLines: 2);\n";
      final findings = scanSource(file: 'max_lines.dart', source: source);
      expect(findings, hasLength(1));
      expect(findings.single.line, 1);
      expect(findings.single.message, contains('maxLines'));
    });

    test('TextOverflow.ellipsis', () {
      const source = "Text('Hola', overflow: TextOverflow.ellipsis);\n";
      final findings = scanSource(file: 'ellipsis.dart', source: source);
      expect(findings.single.message, contains('TextOverflow.ellipsis'));
    });

    test('FittedBox', () {
      const source = "FittedBox(child: Text('Hola'));\n";
      final findings = scanSource(file: 'fitted.dart', source: source);
      expect(findings.single.message, contains('FittedBox'));
    });

    test('a textScaler: or TextScaler override', () {
      const source = "Text('Hola', textScaler: TextScaler.noScaling);\n";
      final findings = scanSource(file: 'scaler.dart', source: source);
      expect(findings.map((f) => f.message), contains(contains('textScaler')));
      expect(findings.map((f) => f.message), contains(contains('TextScaler')));
    });

    test('a textScaleFactor override', () {
      const source = "Text('Hola', textScaleFactor: 1.0);\n";
      final findings = scanSource(file: 'factor.dart', source: source);
      expect(findings.single.message, contains('textScaleFactor'));
    });

    test('a fixed-height container around text', () {
      const source = "SizedBox(height: 48, child: Text('Hola'));\n";
      final findings = scanSource(file: 'fixed.dart', source: source);
      expect(findings, hasLength(1));
      expect(findings.single.line, 1);
      expect(findings.single.message, contains('fixed-height container'));
    });

    test('an animated fixed-height container around text', () {
      const source = "AnimatedContainer(height: 48, child: Text('Hola'));\n";
      expect(
        scanSource(file: 'animated.dart', source: source).map((f) => f.message),
        contains(contains('fixed-height container')),
      );
    });

    test('a height-capped constraint around text', () {
      const source =
          'ConstrainedBox(constraints: BoxConstraints(maxHeight: 48), '
          "child: Text('Hola'));\n";
      expect(
        scanSource(file: 'capped.dart', source: source).map((f) => f.message),
        contains(contains('fixed-height container')),
      );
    });

    test('a decimal-only height literal still counts', () {
      const source = "SizedBox(height: .5, child: Text('Hola'));\n";
      expect(
        scanSource(file: 'dot5.dart', source: source).map((f) => f.message),
        contains(contains('fixed-height container')),
      );
    });

    test('a fixed-height container around an editable text', () {
      const source = 'SizedBox(height: 48, child: EditableText(...));\n';
      expect(
        scanSource(file: 'editable.dart', source: source).map((f) => f.message),
        contains(contains('fixed-height container')),
      );
    });
  });

  group('legal forms stay clean', () {
    test('reading the ambient scaler is not an override', () {
      const source = '''
final scaler = MediaQuery.textScalerOf(context);
final maybe = MediaQuery.maybeTextScalerOf(context);
''';
      expect(scanSource(file: 'ambient.dart', source: source), isEmpty);
    });

    test('TextStyle height is the multiplier line-height form', () {
      const source = 'TextStyle(height: 1.2, fontSize: 26);\n';
      expect(scanSource(file: 'style.dart', source: source), isEmpty);
    });

    test('a fixed-height container without text is a legal spacer', () {
      const source = 'SizedBox(height: 48);\n';
      expect(scanSource(file: 'spacer.dart', source: source), isEmpty);
    });

    test('a token-pulled height is a review matter, not a literal one', () {
      const source =
          "SizedBox(height: Spacing.touchTargetMin, child: Text('Hola'));\n";
      expect(scanSource(file: 'token.dart', source: source), isEmpty);
    });
  });

  group('masking', () {
    test('comments and string contents cannot false-positive', () {
      const source = '''
// maxLines: 2 in a comment.
/* FittedBox in a block comment */
final note = 'TextOverflow.ellipsis inside a string';
int ok() => 1;
''';
      expect(scanSource(file: 'masked.dart', source: source), isEmpty);
    });
  });

  group('the executable', () {
    test('exits 1 and prints file:line for a lib with an escape', () async {
      final root = _makeTemp('cli_violating');
      final lib = Directory('${root.path}/lib')..createSync(recursive: true);
      File('${lib.path}/main.dart')
          .writeAsStringSync("SizedBox(height: 48, child: Text('Hola'));\n");

      final result = await Process.run('dart', [
        'run',
        'tool/check_text_scaling.dart',
        root.path,
      ]);
      expect(result.exitCode, 1);
      expect(result.stdout as String, matches(RegExp(r'\.dart:\d+:')));
      expect(result.stdout as String, contains('FAILED'));
    });

    test('exits 0 and prints the passed message for a clean lib', () async {
      final root = _makeTemp('cli_clean');
      final lib = Directory('${root.path}/lib')..createSync(recursive: true);
      File('${lib.path}/main.dart')
          .writeAsStringSync("Text('Hola');\nint ok() => 1;\n");

      final result = await Process.run('dart', [
        'run',
        'tool/check_text_scaling.dart',
        root.path,
      ]);
      expect(result.exitCode, 0);
      expect(result.stdout as String, contains('text-scaling check passed'));
    });
  });
}

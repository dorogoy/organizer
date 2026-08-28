import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../tool/check_no_literal_strings.dart';

Directory _makeTemp(String label) {
  final dir = Directory.systemTemp.createTempSync('no_literals_$label');
  addTearDown(() => dir.deleteSync(recursive: true));
  return dir;
}

void main() {
  group('scanSource', () {
    test(
      'a literal reaching a widget is banned and file and line are named',
      () {
        const source = "Widget build() => Text('Hecho');\n";
        final findings = scanSource(file: 'widget.dart', source: source);
        expect(findings, hasLength(1));
        expect(findings.single.file, 'widget.dart');
        expect(findings.single.line, 1);
        expect(findings.single.toString(), contains('widget.dart:1:'));
      },
    );

    test('a sentence assembled from localized accessors is banned', () {
      const source = '''
String sentence(AppStrings strings) =>
    strings.actionDone + strings.captureSave;
''';
      final findings = scanSource(file: 'concat.dart', source: source);
      expect(findings, hasLength(1));
      expect(findings.single.line, 2);
      expect(findings.single.message, contains('concatenated at runtime'));
    });

    test('numerals ride ARB placeholders through accessors — clean', () {
      const source = '''
import 'package:organizer/strings/app_strings.dart';

String label(AppStrings strings) => strings.actionDone;
String counted(AppStrings strings) => strings.taskCount(3);
''';
      expect(scanSource(file: 'clean.dart', source: source), isEmpty);
    });

    test('directive URIs are exempt, across a wrapped continuation line', () {
      const source = '''
import 'package:flutter/material.dart';
export 'src/inner.dart'
    show Inner;
''';
      expect(scanSource(file: 'directives.dart', source: source), isEmpty);
    });

    test('comments never count as literals', () {
      const source = '''
// Text('Hecho') mentioned in a comment.
/* 'also hidden' */
int ok() => 1;
''';
      expect(scanSource(file: 'comments.dart', source: source), isEmpty);
    });

    test('interpolation bodies do not end the literal early', () {
      // A quote inside `${…}` belongs to the body; the enclosing literal
      // spans to its true closing quote, and a newline inside the body
      // does not mark it unterminated.
      const source = r"""
final s = '${cond ? 'a' : 'b'}';
final t = '${foo(
  1,
)}';
""";
      final findings = scanSource(file: 'interp.dart', source: source);
      expect(findings, hasLength(2));
      // Dart drops the newline right after """ — the code starts at line 1.
      expect(findings.first.line, 1);
      expect(findings.last.line, 2);
    });

    test('raw and triple-quoted strings are literals too', () {
      const raw =
          r"final p = r'C:\temp';"
          "\n";
      expect(scanSource(file: 'raw.dart', source: raw), hasLength(1));
      const triple = "'''\nHecho\n''';\n";
      expect(scanSource(file: 'triple.dart', source: triple), hasLength(1));
    });

    test('two literals on one line each get a finding on that line', () {
      const source = "final a = 'x'; final b = 'y';\n";
      expect(scanSource(file: 'two.dart', source: source), hasLength(2));
    });
  });

  group('scanLib', () {
    test('marked generated accessors and named token strings are exempt', () {
      final temp = _makeTemp('exemptions');
      final lib = Directory('${temp.path}/lib')..createSync(recursive: true);
      Directory('${lib.path}/strings').createSync();
      Directory('${lib.path}/ui').createSync();
      File('${lib.path}/main.dart')
          .writeAsStringSync("Widget build() => Text('Hecho');\n");
      File('${lib.path}/strings/app_strings.dart').writeAsStringSync(
        "$generatedStringsHeader\nString get actionDone => 'Hecho';\n",
      );
      File('${lib.path}/strings/app_strings_es.dart').writeAsStringSync(
        "$generatedStringsHeader\nString get actionDone => 'Hecho';\n",
      );
      File('${lib.path}/ui/tokens.dart').writeAsStringSync(
        "static const String shortDateFormat = 'd\\u00A0MMM';\n",
      );

      final findings = scanLib(lib);
      expect(findings, hasLength(1));
      expect(findings.single.file, endsWith('lib/main.dart'));
    });

    test('handwritten string files and arbitrary token copy are rejected', () {
      final temp = _makeTemp('narrow_exemptions');
      final lib = Directory('${temp.path}/lib')..createSync(recursive: true);
      Directory('${lib.path}/strings').createSync();
      Directory('${lib.path}/ui').createSync();
      for (final name in ['app_strings.dart', 'app_strings_es.dart']) {
        File('${lib.path}/strings/$name')
            .writeAsStringSync('$generatedStringsHeader\n');
      }
      File('${lib.path}/strings/custom.dart')
          .writeAsStringSync("String copy = 'Hecho';\n");
      File('${lib.path}/ui/tokens.dart')
          .writeAsStringSync("static const String copy = 'Hecho';\n");

      final findings = scanLib(lib);
      expect(findings, hasLength(2));
      expect(
        findings.map((finding) => finding.file),
        contains(endsWith('lib/strings/custom.dart')),
      );
      expect(
        findings.map((finding) => finding.file),
        contains(endsWith('lib/ui/tokens.dart')),
      );
    });

    test('marked .g.dart files are exempt; unmarked ones still flag', () {
      final temp = _makeTemp('generated_marker');
      final lib = Directory('${temp.path}/lib')..createSync(recursive: true);
      Directory('${lib.path}/strings').createSync();
      for (final name in ['app_strings.dart', 'app_strings_es.dart']) {
        File('${lib.path}/strings/$name')
            .writeAsStringSync('$generatedStringsHeader\n');
      }
      File('${lib.path}/strings.dart.g.dart').writeAsStringSync(
        '$generatedCodeHeader\n'
        "const String table = 'CREATE TABLE pool_facts …';\n",
      );
      File('${lib.path}/unmarked.g.dart')
          .writeAsStringSync("const String table = 'handwritten';\n");

      final findings = scanLib(lib);
      expect(findings, hasLength(1));
      expect(findings.single.file, endsWith('lib/unmarked.g.dart'));
    });

    test(
      'the named-constant allowance is store-path-scoped and wrap-aware',
      () {
        final temp = _makeTemp('allowance_scope');
        final lib = Directory('${temp.path}/lib')..createSync(recursive: true);
        Directory('${lib.path}/strings').createSync();
        for (final name in ['app_strings.dart', 'app_strings_es.dart']) {
          File('${lib.path}/strings/$name')
              .writeAsStringSync('$generatedStringsHeader\n');
        }
        Directory('${lib.path}/store').createSync();
        File('${lib.path}/store/substrate.dart').writeAsStringSync(
          "const String substrateSchemaFile =\n    'substrate.drift';\n",
        );
        File('${lib.path}/main.dart').writeAsStringSync(
          "const String substrateSchemaFile = 'substrate.drift';\n",
        );

        final findings = scanLib(lib);
        expect(findings, hasLength(1));
        expect(findings.single.file, endsWith('lib/main.dart'));
      },
    );
  });

  group('the executable', () {
    test('exits 1 and prints file:line for a lib with a literal', () async {
      final root = _makeTemp('cli_violating');
      final lib = Directory('${root.path}/lib')..createSync(recursive: true);
      File('${lib.path}/main.dart')
          .writeAsStringSync("Widget build() => Text('Hecho');\n");

      final result = await Process.run('dart', [
        'run',
        'tool/check_no_literal_strings.dart',
        root.path,
      ]);
      expect(result.exitCode, 1);
      expect(result.stdout as String, matches(RegExp(r'\.dart:\d+:')));
      expect(result.stdout as String, contains('FAILED'));
    });

    test('exits 0 and prints the passed message for a clean lib', () async {
      final root = _makeTemp('cli_clean');
      final lib = Directory('${root.path}/lib')..createSync(recursive: true);
      File('${lib.path}/main.dart').writeAsStringSync('int ok() => 1;\n');

      final result = await Process.run('dart', [
        'run',
        'tool/check_no_literal_strings.dart',
        root.path,
      ]);
      expect(result.exitCode, 0);
      expect(
        result.stdout as String,
        contains('no-literal-strings check passed'),
      );
    });
  });
}

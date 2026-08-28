import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../tool/check_core_purity.dart';

const _fixtures = 'test/fixtures/core_purity';

Directory _makeTemp(String label) {
  final dir = Directory.systemTemp.createTempSync('core_purity_$label');
  addTearDown(() => dir.deleteSync(recursive: true));
  return dir;
}

/// Builds a throwaway repository root holding a minimal `packages/core` with
/// either a violating or a clean port file, for exercising the executable's
/// output and exit-code contract.
Directory _fixtureRoot({required bool violating}) {
  final root = _makeTemp('cli');
  final core = Directory('${root.path}/packages/core')
    ..createSync(recursive: true);
  Directory('${core.path}/lib/ports').createSync(recursive: true);
  Directory('${core.path}/.dart_tool').createSync();
  File('${core.path}/pubspec.yaml')
      .writeAsStringSync('name: core\nenvironment:\n  sdk: ^3.13.0\n');
  File('${core.path}/.dart_tool/package_config.json').writeAsStringSync(
    jsonEncode({
      'configVersion': 2,
      'packages': [
        {
          'name': 'core',
          'rootUri': '../',
          'packageUri': 'lib/',
          'languageVersion': '3.13',
        },
      ],
    }),
  );
  File('${core.path}/lib/ports/machine_port.dart').writeAsStringSync(
    violating
        ? "import 'package:flutter/material.dart';\n\nDateTime stamp() => DateTime.now();\n"
        : 'abstract interface class MachinePort {}\n',
  );
  return root;
}

void main() {
  test('a clean core file produces no findings', () {
    final findings = scanSource(
      file: '$_fixtures/clean.dart',
      source: File('$_fixtures/clean.dart').readAsStringSync(),
    );
    expect(findings, isEmpty);
  });

  test('a Flutter import is banned and the file and line are named', () {
    final path = '$_fixtures/flutter_import.dart';
    final findings = scanSource(
      file: path,
      source: File(path).readAsStringSync(),
    );
    expect(findings, isNotEmpty);
    expect(findings.first.file, path);
    expect(findings.first.line, 1);
    expect(findings.first.message, contains('flutter/material.dart'));
  });

  test('a wall-clock read is banned and the file and line are named', () {
    final path = '$_fixtures/wall_clock.dart';
    final findings = scanSource(
      file: path,
      source: File(path).readAsStringSync(),
    );
    expect(findings, isNotEmpty);
    expect(findings.first.file, path);
    expect(findings.first.line, 2);
    expect(findings.first.message, contains('DateTime.now()'));
  });

  test('mutable static state is banned and the file and line are named', () {
    final path = '$_fixtures/mutable_static.dart';
    final findings = scanSource(
      file: path,
      source: File(path).readAsStringSync(),
    );
    expect(findings, isNotEmpty);
    expect(findings.first.file, path);
    expect(findings.first.line, 3);
    expect(findings.first.message, contains('mutable static state'));
  });

  test('comments and strings cannot hide banned identifiers', () {
    const source = '''
// DateTime.now() mentioned in a comment.
final note = 'Random and Timer inside a string';
int visible() => 3;
''';
    expect(scanSource(file: 'hidden.dart', source: source), isEmpty);

    const sneaky = """
final stamp = '\${DateTime.now()}';
""";
    final findings = scanSource(file: 'sneaky.dart', source: sneaky);
    expect(findings, isNotEmpty);
    expect(findings.first.message, contains('DateTime.now()'));
  });

  test('an import-shaped line inside a string literal is not an import', () {
    const source =
        "const text = '''\nimport 'package:flutter/material.dart';\n''';\n";
    final findings = scanSource(file: 'in_string.dart', source: source);
    expect(findings.where((f) => f.message.contains('import')), isEmpty);
  });

  test('nested block comments are masked to their outer terminator', () {
    const source =
        '/* outer Random /* inner */ still comment */ int ok() => 1;\n';
    expect(scanSource(file: 'nested.dart', source: source), isEmpty);
  });

  test('a DateTime.now tear-off is banned without call parens', () {
    const source = 'final read = DateTime.now;\n';
    final findings = scanSource(file: 'tearoff.dart', source: source);
    expect(findings, isNotEmpty);
    expect(findings.first.message, contains('DateTime.now'));
  });

  test('multi-declarator mutable declarations are banned', () {
    const top = 'int first, second = 0;\n';
    expect(
      scanSource(file: 'multi_top.dart', source: top).map((f) => f.message),
      contains(contains('mutable top-level state')),
    );
    const stat = 'class C {\n  static int first, second = 0;\n}\n';
    expect(
      scanSource(file: 'multi_static.dart', source: stat).map((f) => f.message),
      contains(contains('mutable static state')),
    );
  });

  group('scanPubspec', () {
    test('flags a drift dependency at any indentation', () {
      const pubspec = 'name: core\ndependencies:\n    drift: ^2.34.3\n';
      final findings = scanPubspec(file: 'pubspec.yaml', text: pubspec);
      expect(findings, hasLength(1));
      expect(findings.single.line, 3);
      expect(findings.single.message, contains('drift'));
    });

    test('flags a flutter key', () {
      const pubspec = 'name: core\nflutter:\n  uses-material-design: true\n';
      final findings = scanPubspec(file: 'pubspec.yaml', text: pubspec);
      expect(findings, hasLength(1));
      expect(findings.single.line, 2);
      expect(findings.single.message, contains('flutter key'));
    });

    test('flags drift under dependency_overrides', () {
      const pubspec =
          'name: core\ndependencies:\ndependency_overrides:\n  drift_flutter:\n    path: ../x\n';
      final findings = scanPubspec(file: 'pubspec.yaml', text: pubspec);
      expect(findings, hasLength(1));
      expect(findings.single.message, contains('drift_flutter'));
    });

    test('passes a clean pubspec', () {
      const pubspec =
          'name: core\nenvironment:\n  sdk: ^3.13.0\ndev_dependencies:\n  test: ^1.26.0\n';
      expect(scanPubspec(file: 'pubspec.yaml', text: pubspec), isEmpty);
    });
  });

  group('checkDependencyClosure', () {
    test(
      'reports flutter, drift, plugins and malformed entries without crashing',
      () {
        final temp = _makeTemp('closure');
        final core = Directory('${temp.path}/core')
          ..createSync(recursive: true);
        Directory('${core.path}/.dart_tool').createSync();

        final plugin = Directory('${temp.path}/plugin')..createSync();
        File('${plugin.path}/pubspec.yaml')
            .writeAsStringSync('name: my_plugin\nflutter:\n  plugin:\n');
        final pure = Directory('${temp.path}/pure')..createSync();
        File('${pure.path}/pubspec.yaml').writeAsStringSync('name: path\n');

        File('${core.path}/.dart_tool/package_config.json').writeAsStringSync(
          jsonEncode({
            'packages': [
              {'name': 'core', 'rootUri': '../'},
              {'name': 'flutter', 'rootUri': 'file://${plugin.path}'},
              {'name': 'drift_flutter', 'rootUri': 'file://${pure.path}'},
              {'name': 'my_plugin', 'rootUri': 'file://${plugin.path}'},
              {'rootUri': 'file://${pure.path}'},
              {'name': 'path', 'rootUri': 'file://${pure.path}'},
            ],
          }),
        );

        final findings = checkDependencyClosure(core);
        expect(
          findings.map((f) => f.message),
          contains(contains("'flutter' is inside")),
        );
        expect(
          findings.map((f) => f.message),
          contains(contains("'drift_flutter' is inside")),
        );
        expect(
          findings.map((f) => f.message),
          contains(contains("'my_plugin' is inside")),
        );
        expect(
          findings.map((f) => f.message),
          contains(contains('without a name')),
        );
        expect(findings, hasLength(4));
      },
    );

    test('passes a pure closure', () {
      final temp = _makeTemp('pure');
      final core = Directory('${temp.path}/core')..createSync(recursive: true);
      Directory('${core.path}/.dart_tool').createSync();
      final pure = Directory('${temp.path}/pure')..createSync();
      File('${pure.path}/pubspec.yaml').writeAsStringSync('name: path\n');
      File('${core.path}/.dart_tool/package_config.json').writeAsStringSync(
        jsonEncode({
          'packages': [
            {'name': 'core', 'rootUri': '../'},
            {'name': 'path', 'rootUri': 'file://${pure.path}'},
          ],
        }),
      );
      expect(checkDependencyClosure(core), isEmpty);
    });
  });

  test('scanCoreLib walks nested directories and names the offending file', () {
    final temp = _makeTemp('walk');
    final lib = Directory('${temp.path}/lib')..createSync(recursive: true);
    final deep = Directory('${lib.path}/ports/inner')
      ..createSync(recursive: true);
    File('${deep.path}/machine.dart')
        .writeAsStringSync('class M {\n  static int total = 0;\n}\n');
    final findings = scanCoreLib(lib);
    expect(findings, hasLength(1));
    expect(findings.single.file, endsWith('lib/ports/inner/machine.dart'));
    expect(findings.single.line, 2);
  });

  group('the executable', () {
    test('exits 1 and prints file:line for a violating core', () async {
      final root = _fixtureRoot(violating: true);
      final result = await Process.run('dart', [
        'run',
        'tool/check_core_purity.dart',
        root.path,
      ]);
      expect(result.exitCode, 1);
      expect(result.stdout as String, matches(RegExp(r'\.dart:\d+:')));
    });

    test('exits 0 and prints the passed message for a clean core', () async {
      final root = _fixtureRoot(violating: false);
      final result = await Process.run('dart', [
        'run',
        'tool/check_core_purity.dart',
        root.path,
      ]);
      expect(result.exitCode, 0);
      expect(result.stdout as String, contains('core purity check passed'));
    });
  });
}

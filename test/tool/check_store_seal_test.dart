import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../tool/check_store_seal.dart';

const fixtures = 'test/fixtures/store_seal';

Directory _makeTemp(String label) {
  final dir = Directory.systemTemp.createTempSync('store_seal_$label');
  addTearDown(() => dir.deleteSync(recursive: true));
  return dir;
}

void main() {
  test('a drift import outside lib/store/ is flagged, with file and line', () {
    final path = '$fixtures/outside.dart';
    final source = File(path).readAsStringSync();
    final findings = scanSource(file: path, source: source);
    final importOffset = source.indexOf("import 'package:drift");
    final importLine =
        '\n'.allMatches(source.substring(0, importOffset)).length + 1;
    expect(findings, hasLength(1));
    expect(findings.single.file, path);
    expect(findings.single.line, importLine);
    expect(findings.single.message, contains('package:drift/drift.dart'));
    expect(findings.single.message, contains('AD-21 store seal'));
  });

  test('the drift* prefix catches drift_flutter too', () {
    final path = '$fixtures/outside_drift_flutter.dart';
    final findings = scanSource(
      file: path,
      source: File(path).readAsStringSync(),
    );
    expect(findings, hasLength(1));
    expect(
      findings.single.message,
      contains('package:drift_flutter/drift_flutter.dart'),
    );
  });

  test('an allowlisted path may import persistence packages', () {
    final path = '$fixtures/inside.dart';
    final findings = scanSource(
      file: path,
      source: File(path).readAsStringSync(),
      allowlist: const ['test/fixtures/store_seal/inside'],
    );
    expect(findings, isEmpty);
  });

  test('a file with no persistence imports is clean', () {
    final path = '$fixtures/clean.dart';
    final findings = scanSource(
      file: path,
      source: File(path).readAsStringSync(),
    );
    expect(findings, isEmpty);
  });

  test('the default allowlist holds exactly the two decided scopes', () {
    expect(persistenceImportAllowlist, contains('lib/store/'));
    expect(persistenceImportAllowlist, hasLength(2));
  });

  test('the seal covers the prefixes and the named denylist', () {
    expect(packageIsPersistence('drift'), isTrue);
    expect(packageIsPersistence('drift_flutter'), isTrue);
    expect(packageIsPersistence('sqlite3'), isTrue);
    expect(packageIsPersistence('sqlite3_flutter_libs'), isTrue);
    expect(packageIsPersistence('sqflite'), isTrue);
    expect(packageIsPersistence('sqflite_common_ffi'), isTrue);
    expect(packageIsPersistence('shared_preferences'), isTrue);
    expect(packageIsPersistence('shared_preferences_android'), isTrue);
    expect(packageIsPersistence('hive'), isTrue);
    expect(packageIsPersistence('isar'), isTrue);
    expect(packageIsPersistence('objectbox'), isTrue);
    expect(packageIsPersistence('sembast'), isTrue);
    expect(packageIsPersistence('realm'), isTrue);
    expect(packageIsPersistence('flutter_secure_storage'), isTrue);
    expect(packageIsPersistence('uuid'), isFalse);
    expect(packageIsPersistence('flutter_riverpod'), isFalse);
    expect(packageIsPersistence('core'), isFalse);
    expect(packageIsPersistence('flutter'), isFalse);
  });

  test('an import-shaped line inside a string literal is not an import', () {
    const source =
        "const text = '''\nimport 'package:drift/drift.dart';\n''';\n";
    expect(scanSource(file: 'in_string.dart', source: source), isEmpty);
  });

  test('a raw store library import outside lib/store/ is flagged', () {
    const source = "import 'package:organizer/store/substrate.dart';\n";
    final findings = scanSource(file: 'lib/ui/screen.dart', source: source);
    expect(findings, hasLength(1));
    expect(findings.single.message, contains('raw store library'));
  });

  test('a directive after a same-line library declaration is sealed', () {
    const source = "library fixture; import 'package:drift/drift.dart';\n";
    final findings = scanSource(file: 'lib/ui/screen.dart', source: source);
    expect(findings, hasLength(1));
    expect(findings.single.message, contains('package:drift/drift.dart'));
  });

  group('the executable', () {
    Directory fixtureRoot({required bool violating}) {
      final root = _makeTemp('cli');
      Directory('${root.path}/lib/ui').createSync(recursive: true);
      Directory('${root.path}/lib/store').createSync(recursive: true);
      File('${root.path}/lib/store/adapter.dart')
          .writeAsStringSync("import 'package:drift/drift.dart';\n");
      File('${root.path}/lib/ui/screen.dart').writeAsStringSync(
        violating ? "import 'package:drift/drift.dart';\n" : 'var fine = 1;\n',
      );
      return root;
    }

    test(
      'exits 1 and prints file:line for a leak outside lib/store/',
      () async {
        final root = fixtureRoot(violating: true);
        final result = await Process.run('dart', [
          'run',
          'tool/check_store_seal.dart',
          root.path,
        ]);
        expect(result.exitCode, 1);
        final out = result.stdout as String;
        expect(out, matches(RegExp(r'screen\.dart:\d+:')));
        expect(out, contains('store seal check FAILED'));
      },
    );

    test('exits 0 when only lib/store/ imports persistence', () async {
      final root = fixtureRoot(violating: false);
      final result = await Process.run('dart', [
        'run',
        'tool/check_store_seal.dart',
        root.path,
      ]);
      expect(result.exitCode, 0);
      expect(result.stdout as String, contains('store seal check passed'));
    });

    test('a production lib/fixtures directory remains in scope', () async {
      final root = _makeTemp('production_fixtures');
      Directory('${root.path}/lib/fixtures').createSync(recursive: true);
      File('${root.path}/lib/fixtures/bad.dart')
          .writeAsStringSync("import 'package:drift/drift.dart';\n");
      final result = await Process.run('dart', [
        'run',
        'tool/check_store_seal.dart',
        root.path,
      ]);
      expect(result.exitCode, 1);
      expect(result.stdout as String, contains('lib/fixtures/bad.dart'));
    });
  });
}

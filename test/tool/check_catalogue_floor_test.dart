import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../tool/catalogue_shared.dart';
import '../../tool/check_catalogue_floor.dart';
import '../../tool/check_core_purity.dart' show Finding;

const fixtures = 'test/fixtures/catalogue_floor';

const registeredPubspec = '''
name: fixture
flutter:
  assets:
    - assets/evergreen/
''';

const unregisteredPubspec = '''
name: fixture
flutter:
  uses-material-design: true
''';

const misdirectedPubspec = '''
name: fixture
data:
  assets:
    - assets/evergreen/
flutter:
  uses-material-design: true
''';

List<Finding> scanFixture(String name, {String pubspec = registeredPubspec}) =>
    scanCatalogue(
      assetFile: '$fixtures/$name',
      assetSource: File('$fixtures/$name').readAsStringSync(),
      pubspecFile: 'pubspec.yaml',
      pubspecSource: pubspec,
    );

void main() {
  test('the shipped asset and pubspec pass together', () {
    final findings = scanCatalogue(
      assetFile: assetPath,
      assetSource: File(assetPath).readAsStringSync(),
      pubspecFile: pubspecPath,
      pubspecSource: File(pubspecPath).readAsStringSync(),
    );
    expect(findings, isEmpty);
  });

  test('the clean fixture passes at exactly the floor', () {
    expect(scanFixture('clean.json'), isEmpty);
  });

  test('27 eligible entries breach the floor', () {
    final findings = scanFixture('eligible_27.json');
    expect(findings, hasLength(1));
    expect(findings.single.message, contains('coverage floor breached'));
    expect(findings.single.message, contains('27'));
    expect(findings.single.file, '$fixtures/eligible_27.json');
  });

  test('a maintenance 28th eligible entry drops the count below the floor', () {
    final findings = scanFixture('maintenance_28th.json');
    expect(findings, hasLength(1));
    expect(findings.single.message, contains('coverage floor breached'));
    expect(findings.single.message, contains('maintenance never counts'));
  });

  test(
    'an eligible entry flipped to daily drops the count below the floor',
    () {
      final findings = scanFixture('daily_flip.json');
      expect(findings, hasLength(1));
      expect(findings.single.message, contains('coverage floor breached'));
      expect(findings.single.message, contains('daily is excluded'));
    },
  );

  test('an emptied weekly zone fails naming the zone, floor untouched', () {
    final findings = scanFixture('zone_empty.json');
    expect(findings, hasLength(1));
    expect(findings.single.message, contains('no entries with zone "z4"'));
    expect(findings.single.message, contains('A12.4'));
  });

  test('a fifth field fails naming entry id and key, with file and line', () {
    final findings = scanFixture('extra_field.json');
    expect(findings, hasLength(1));
    final finding = findings.single;
    expect(finding.file, '$fixtures/extra_field.json');
    expect(finding.message, contains('f-daily-instant'));
    expect(finding.message, contains('cluster'));
    final source = File('$fixtures/extra_field.json').readAsStringSync();
    expect(finding.line, lineOf(source, source.indexOf('"f-daily-instant"')));
  });

  test('a duplicate id fails naming the id', () {
    final findings = scanFixture('dup_id.json');
    expect(findings, hasLength(1));
    expect(findings.single.message, contains('duplicate entry id'));
    expect(findings.single.message, contains('f-daily-instant'));
  });

  test('a pubspec without the assets registration fails at flutter:', () {
    final findings = scanFixture('clean.json', pubspec: unregisteredPubspec);
    expect(findings, hasLength(1));
    expect(findings.single.file, 'pubspec.yaml');
    expect(findings.single.line, 2);
    expect(findings.single.message, contains('flutter.assets'));
  });

  test(
    'an assets item outside the flutter: block cannot satisfy the registration',
    () {
      final findings = scanFixture('clean.json', pubspec: misdirectedPubspec);
      expect(findings, hasLength(1));
      expect(findings.single.file, 'pubspec.yaml');
      expect(findings.single.line, 5);
      expect(findings.single.message, contains('flutter.assets'));
    },
  );

  test('the exact file registration also satisfies the check', () {
    const filePubspec = '''
name: fixture
flutter:
  assets:
    - assets/evergreen/catalogue.json
''';
    expect(scanFixture('clean.json', pubspec: filePubspec), isEmpty);
  });

  group('the executable', () {
    Directory fixtureRoot() {
      final root = Directory.systemTemp.createTempSync('catalogue_floor');
      addTearDown(() => root.deleteSync(recursive: true));
      Directory('${root.path}/assets/evergreen').createSync(recursive: true);
      File('${root.path}/assets/evergreen/catalogue.json')
          .writeAsStringSync(File('$fixtures/clean.json').readAsStringSync());
      File('${root.path}/pubspec.yaml').writeAsStringSync(registeredPubspec);
      return root;
    }

    test('exits 0 on a clean tree', () async {
      final root = fixtureRoot();
      final result = await Process.run('dart', [
        'run',
        'tool/check_catalogue_floor.dart',
        root.path,
      ]);
      expect(result.exitCode, 0);
      expect(result.stdout as String, contains('catalogue floor check passed'));
    });

    test('exits 1 with file:line findings on an unregistered asset', () async {
      final root = fixtureRoot();
      File('${root.path}/pubspec.yaml').writeAsStringSync(unregisteredPubspec);
      final result = await Process.run('dart', [
        'run',
        'tool/check_catalogue_floor.dart',
        root.path,
      ]);
      expect(result.exitCode, 1);
      expect(result.stdout as String, contains('pubspec.yaml:2:'));
      expect(result.stdout as String, contains('catalogue floor check FAILED'));
    });
  });
}

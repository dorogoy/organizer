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

  test('a duplicate JSON member fails at the duplicate source line', () {
    const asset = '''
{
  "version": 1,
  "entries": [
    {"id": "f-daily-instant", "id": "other", "size": "instant", "cadence": "daily"}
  ]
}
''';
    final findings = scanCatalogue(
      assetFile: 'duplicate_member.json',
      assetSource: asset,
      pubspecFile: 'pubspec.yaml',
      pubspecSource: registeredPubspec,
    );
    expect(findings, hasLength(1));
    expect(findings.single.line, 4);
    expect(findings.single.message, contains('duplicate JSON member "id"'));
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

  test('quoted file and directory registrations satisfy YAML validation', () {
    const quotedDirectory = '''
name: fixture
flutter:
  assets:
    - "assets/evergreen/"
''';
    const quotedFile = '''
name: fixture
flutter:
  assets:
    - 'assets/evergreen/catalogue.json'
''';
    expect(scanFixture('clean.json', pubspec: quotedDirectory), isEmpty);
    expect(scanFixture('clean.json', pubspec: quotedFile), isEmpty);
  });

  test('uses the parsed quoted flutter key, not earlier text lookalikes', () {
    const pubspec = '''
name: fixture
note: "flutter: is only prose"
# flutter: is also only a comment
'flutter':
  uses-material-design: true
''';
    final findings = scanFixture('clean.json', pubspec: pubspec);
    expect(findings, hasLength(1));
    expect(findings.single.line, 4);
    expect(findings.single.message, contains('flutter.assets'));
  });

  test('non-list or nested flutter.assets declarations fail', () {
    const scalar = '''
name: fixture
flutter:
  assets: assets/evergreen/
''';
    const nested = '''
name: fixture
flutter:
  assets:
    nested:
      - assets/evergreen/
''';
    for (final pubspec in [scalar, nested]) {
      final findings = scanFixture('clean.json', pubspec: pubspec);
      expect(findings, hasLength(1));
      expect(
        findings.single.message,
        contains('flutter.assets must be a YAML list'),
      );
    }
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

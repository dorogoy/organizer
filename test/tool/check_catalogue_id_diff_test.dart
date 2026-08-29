import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../tool/catalogue_shared.dart';
import '../../tool/check_catalogue_id_diff.dart';

const fixtures = 'test/fixtures/catalogue_id_diff';

void main() {
  test('the shipped pair is green: baseline tuples match the asset', () async {
    expect(await runCheck(baselinePath, assetPath), 0);
  });

  test(
    'equivalent relative and absolute production paths retain name checks',
    () async {
      expect(
        await runCheck(
          './tool/catalogue_baseline.json',
          './assets/evergreen/catalogue.json',
        ),
        0,
      );
      expect(
        await runCheck(
          File(baselinePath).absolute.path,
          File(assetPath).absolute.path,
        ),
        0,
      );
    },
  );

  test(
    'production name continuity fails explicitly when the ARB is unavailable',
    () async {
      final missing = '${Directory.systemTemp.path}/missing_catalogue_arb.json';
      final result = await runCheck(
        baselinePath,
        assetPath,
        productionArbPath: missing,
      );
      expect(result, 1);
    },
  );

  test('the v0 fixture pair is green against itself', () async {
    expect(
      await runCheck('$fixtures/v0_baseline.json', '$fixtures/v0_asset.json'),
      0,
    );
  });

  test(
    'an added id versus the baseline passes (AD-23 additions are legal)',
    () async {
      expect(
        await runCheck(
          '$fixtures/v0_baseline.json',
          '$fixtures/added_asset.json',
        ),
        0,
      );
    },
  );

  test('a baseline that is not a JSON object fails instead of passing', () {
    final findings = diffBaseline(
      baselineFile: '$fixtures/array_baseline.json',
      baselineSource: File('$fixtures/array_baseline.json').readAsStringSync(),
      assetFile: '$fixtures/v0_asset.json',
      assetSource: File('$fixtures/v0_asset.json').readAsStringSync(),
    );
    expect(findings, hasLength(1));
    expect(findings.single.message, contains('not a JSON object'));
  });

  test('an invalid baseline tuple fails naming the id', () {
    final findings = diffBaseline(
      baselineFile: '$fixtures/bad_token_baseline.json',
      baselineSource: File('$fixtures/bad_token_baseline.json')
          .readAsStringSync(),
      assetFile: '$fixtures/v0_asset.json',
      assetSource: File('$fixtures/v0_asset.json').readAsStringSync(),
    );
    expect(findings, hasLength(1));
    expect(findings.single.message, contains('"limpiar-el-horno"'));
    expect(findings.single.message, contains('baseline tuple has an invalid'));
  });

  test('a removed id fails naming the id, with file and line', () {
    final baselineSource = File('$fixtures/v0_baseline.json')
        .readAsStringSync();
    final findings = diffBaseline(
      baselineFile: '$fixtures/v0_baseline.json',
      baselineSource: baselineSource,
      assetFile: '$fixtures/removed_asset.json',
      assetSource: File('$fixtures/removed_asset.json').readAsStringSync(),
    );
    expect(findings, hasLength(1));
    expect(findings.single.file, '$fixtures/v0_baseline.json');
    expect(
      findings.single.line,
      lineOf(baselineSource, baselineSource.indexOf('"cambiar-las-sabanas"')),
    );
    expect(findings.single.message, contains('"cambiar-las-sabanas"'));
    expect(findings.single.message, contains('disappeared'));
    expect(findings.single.message, contains('approved catalogue evolution'));
  });

  test('a re-sized id fails naming the id and both sizes', () {
    final findings = diffBaseline(
      baselineFile: '$fixtures/v0_baseline.json',
      baselineSource: File('$fixtures/v0_baseline.json').readAsStringSync(),
      assetFile: '$fixtures/resized_asset.json',
      assetSource: File('$fixtures/resized_asset.json').readAsStringSync(),
    );
    expect(findings, hasLength(1));
    expect(findings.single.message, contains('"limpiar-el-horno"'));
    expect(findings.single.message, contains('"focus"'));
    expect(findings.single.message, contains('"maintenance"'));
    expect(findings.single.message, contains('changed size'));
  });

  test('a cadence or zone drift fails naming old and new values', () {
    final asset = File('$fixtures/v0_asset.json')
        .readAsStringSync()
        .replaceFirst(
          '"cadence": "seasonal"',
          '"cadence": "weekly", "zone": "z1"',
        );
    final findings = diffBaseline(
      baselineFile: '$fixtures/v0_baseline.json',
      baselineSource: File('$fixtures/v0_baseline.json').readAsStringSync(),
      assetFile: 'changed_asset.json',
      assetSource: asset,
    );
    expect(findings, hasLength(2));
    expect(
      findings.map((finding) => finding.message).join(),
      allOf(contains('changed cadence'), contains('changed zone')),
    );
  });

  test('a Spanish name drift fails naming old and new values', () {
    final findings = diffBaseline(
      baselineFile: '$fixtures/v0_baseline.json',
      baselineSource: File('$fixtures/v0_baseline.json').readAsStringSync(),
      assetFile: '$fixtures/v0_asset.json',
      assetSource: File('$fixtures/v0_asset.json').readAsStringSync(),
      assetNames: const {
        'regar-una-planta': 'Regar una planta',
        'cambiar-las-sabanas': 'Cambiar las sábanas',
        'limpiar-el-horno': 'Horno limpio',
      },
    );
    expect(findings, hasLength(1));
    expect(
      findings.single.message,
      allOf(
        contains('Spanish name'),
        contains('Limpiar el horno'),
        contains('Horno limpio'),
      ),
    );
  });

  test('duplicate baseline members fail at their source line', () {
    const baseline = '''
{
  "regar-una-planta": {"size": "instant", "cadence": "daily", "zone": null, "name": "Regar una planta"},
  "regar-una-planta": {"size": "instant", "cadence": "daily", "zone": null, "name": "Otra planta"}
}
''';
    final findings = diffBaseline(
      baselineFile: 'duplicate_baseline.json',
      baselineSource: baseline,
      assetFile: '$fixtures/v0_asset.json',
      assetSource: File('$fixtures/v0_asset.json').readAsStringSync(),
    );
    expect(findings, hasLength(1));
    expect(findings.single.line, 3);
    expect(findings.single.message, contains('duplicate JSON member'));
  });

  test('a malformed asset fails through the core parser, naming the entry', () {
    final findings = diffBaseline(
      baselineFile: '$fixtures/v0_baseline.json',
      baselineSource: File('$fixtures/v0_baseline.json').readAsStringSync(),
      assetFile: 'fixture_asset.json',
      assetSource:
          '{"version": 1, "entries": ['
          '{"id": "cambiar-las-sabanas", "size": "focus"}]}',
    );
    expect(findings, hasLength(1));
    expect(findings.single.file, 'fixture_asset.json');
    expect(findings.single.message, contains('cambiar-las-sabanas'));
    expect(findings.single.message, contains('cadence'));
  });

  test('the executable exits 1 naming the mutated id on a removal', () async {
    final result = await Process.run('dart', [
      'run',
      'tool/check_catalogue_id_diff.dart',
      '$fixtures/v0_baseline.json',
      '$fixtures/removed_asset.json',
    ]);
    expect(result.exitCode, 1);
    final out = result.stdout as String;
    expect(out, contains('cambiar-las-sabanas'));
    expect(out, contains('catalogue id diff check FAILED'));
  });

  test(
    'the executable exits 1 naming id and both sizes on a re-size',
    () async {
      final result = await Process.run('dart', [
        'run',
        'tool/check_catalogue_id_diff.dart',
        '$fixtures/v0_baseline.json',
        '$fixtures/resized_asset.json',
      ]);
      expect(result.exitCode, 1);
      final out = result.stdout as String;
      expect(out, contains('limpiar-el-horno'));
      expect(out, contains('focus'));
      expect(out, contains('maintenance'));
    },
  );

  test('the executable exits 1 on a non-object baseline', () async {
    final result = await Process.run('dart', [
      'run',
      'tool/check_catalogue_id_diff.dart',
      '$fixtures/array_baseline.json',
      '$fixtures/v0_asset.json',
    ]);
    expect(result.exitCode, 1);
    expect(result.stdout as String, contains('not a JSON object'));
  });

  test('the executable exits 2 when the baseline is missing', () async {
    final result = await Process.run('dart', [
      'run',
      'tool/check_catalogue_id_diff.dart',
      '$fixtures/absent_baseline.json',
      '$fixtures/v0_asset.json',
    ]);
    expect(result.exitCode, 2);
  });
}

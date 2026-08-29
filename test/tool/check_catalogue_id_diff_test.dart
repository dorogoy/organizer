import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../tool/catalogue_shared.dart';
import '../../tool/check_catalogue_id_diff.dart';

const fixtures = 'test/fixtures/catalogue_id_diff';

void main() {
  test(
    'the shipped pair is green: baseline ids and sizes match the asset',
    () async {
      expect(await runCheck(baselinePath, assetPath), 0);
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

  test('an invalid baseline size token fails naming the id and the token', () {
    final findings = diffBaseline(
      baselineFile: '$fixtures/bad_token_baseline.json',
      baselineSource: File('$fixtures/bad_token_baseline.json')
          .readAsStringSync(),
      assetFile: '$fixtures/v0_asset.json',
      assetSource: File('$fixtures/v0_asset.json').readAsStringSync(),
    );
    expect(findings, hasLength(1));
    expect(findings.single.message, contains('"limpiar-el-horno"'));
    expect(findings.single.message, contains('"huge"'));
    expect(findings.single.message, contains('instant, maintenance, focus'));
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
    expect(findings.single.message, contains('AD-23'));
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

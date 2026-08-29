import 'package:flutter_test/flutter_test.dart';

import '../../tool/gen_catalogue_lookup.dart';

const tinyAsset = '''
{
  "version": 1,
  "entries": [
    {"id": "regar-una-planta", "size": "instant", "cadence": "daily"},
    {"id": "cambiar-las-sabanas", "size": "focus", "cadence": "weekly", "zone": "z3"}
  ]
}
''';

const tinyArb = '''
{
  "@@locale": "es",
  "catalogueRegarUnaPlanta": "Regar una planta",
  "@catalogueRegarUnaPlanta": {
    "description": "Evergreen catalogue (A12.1)."
  },
  "catalogueCambiarLasSabanas": "Cambiar las sábanas",
  "@catalogueCambiarLasSabanas": {
    "description": "Evergreen catalogue (A12.4)."
  }
}
''';

GenerationResult generate({required String asset, required String arb}) =>
    generateLookup(assetText: asset, arbText: arb);

void main() {
  test('key derivation: kebab-case slug → catalogue + PascalCase', () {
    expect(deriveCatalogueKey('regar-una-planta'), 'catalogueRegarUnaPlanta');
    expect(
      deriveCatalogueKey('recoger-3-cosas-del-suelo'),
      'catalogueRecoger3CosasDelSuelo',
    );
    expect(deriveCatalogueKey('a'), 'catalogueA');
  });

  test('a clean pair yields the marked, complete table', () {
    final result = generate(asset: tinyAsset, arb: tinyArb);
    expect(result.findings, isEmpty);
    final output = result.output!;
    expect(
      output.startsWith('// GENERATED CODE - DO NOT MODIFY BY HAND'),
      isTrue,
    );
    expect(
      output,
      contains(
        "const String catalogueAssetPath = "
        "'assets/evergreen/catalogue.json';",
      ),
    );
    expect(output, contains('Map.unmodifiable'));
    expect(output, contains("  'regar-una-planta': (strings) =>"));
    expect(output, contains('strings.catalogueCambiarLasSabanas,'));
  });

  test('a missing derived ARB key fails naming the entry and the key', () {
    final arb = tinyArb.replaceAll(
      '"catalogueCambiarLasSabanas": "Cambiar las sábanas",',
      '',
    );
    final result = generate(asset: tinyAsset, arb: arb);
    expect(result.findings, hasLength(1));
    expect(result.findings.single, contains('cambiar-las-sabanas'));
    expect(result.findings.single, contains('catalogueCambiarLasSabanas'));
    expect(result.findings.single, contains('is missing'));
    expect(result.output, isNull);
  });

  test('two ids deriving one key fail naming both ids', () {
    // `foo-bar` and `fooBar` both derive catalogueFooBar — the grammar
    // rules the second out at parse time, but the generator guards its
    // own input rather than trusting the caller.
    const asset = '''
{
  "version": 1,
  "entries": [
    {"id": "foo-bar", "size": "instant", "cadence": "daily"},
    {"id": "fooBar", "size": "instant", "cadence": "daily"}
  ]
}
''';
    final result = generate(asset: asset, arb: tinyArb);
    final collisions = result.findings
        .where((finding) => finding.contains('both derive'))
        .toList();
    expect(collisions, hasLength(1));
    expect(collisions.single, contains('"foo-bar"'));
    expect(collisions.single, contains('"fooBar"'));
    expect(collisions.single, contains('"catalogueFooBar"'));
  });

  test('an orphaned catalogue ARB key fails naming the key', () {
    const arb = '''
{
  "@@locale": "es",
  "catalogueRegarUnaPlanta": "Regar una planta",
  "@catalogueRegarUnaPlanta": {
    "description": "Evergreen catalogue (A12.1)."
  },
  "catalogueGhost": "Fantasma",
  "@catalogueGhost": {
    "description": "Dead copy."
  }
}
''';
    const asset = '''
{
  "version": 1,
  "entries": [
    {"id": "regar-una-planta", "size": "instant", "cadence": "daily"}
  ]
}
''';
    final result = generate(asset: asset, arb: arb);
    expect(result.findings, hasLength(1));
    expect(result.findings.single, contains('catalogueGhost'));
    expect(result.findings.single, contains('orphaned'));
    expect(result.findings.single, contains('lib/l10n/app_es.arb:'));
  });

  test('a malformed asset fails instead of generating', () {
    final result = generate(asset: 'not json at all', arb: tinyArb);
    expect(result.findings, hasLength(1));
    expect(result.findings.single, contains('not valid JSON'));
    expect(result.output, isNull);
  });

  test('a non-object asset fails instead of generating', () {
    final result = generate(asset: '[]', arb: tinyArb);
    expect(result.findings, hasLength(1));
    expect(result.findings.single, contains('"entries" array'));
    expect(result.output, isNull);
  });

  test('generation is deterministic: the same inputs give the same bytes', () {
    final first = generate(asset: tinyAsset, arb: tinyArb);
    final second = generate(asset: tinyAsset, arb: tinyArb);
    expect(second.output, first.output);
  });
}

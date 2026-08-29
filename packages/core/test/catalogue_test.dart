import 'package:core/catalogue/catalogue.dart';
import 'package:core/pool/pool_fact.dart';
import 'package:test/test.dart';

const validAsset = '''
{
  "version": 1,
  "entries": [
    {"id": "regar-una-planta", "size": "instant", "cadence": "daily"},
    {"id": "poner-la-mesa", "size": "maintenance", "cadence": "daily"},
    {"id": "pasar-la-aspiradora-a-la-cocina", "size": "focus", "cadence": "weekly", "zone": "z1"},
    {"id": "limpiar-el-horno", "size": "focus", "cadence": "seasonal"}
  ]
}
''';

void main() {
  test('a valid asset parses into inert entries in asset order', () {
    final catalogue = parseCatalogue(validAsset, nameOf: (id) => '[$id]');
    expect(catalogue.version, 1);
    expect(catalogue.entries, hasLength(4));
    final first = catalogue.entries.first;
    expect(first.id, 'regar-una-planta');
    expect(first.size, Size.instant);
    expect(first.cadence, Cadence.daily);
    expect(first.zone, isNull);
    expect(first.name, '[regar-una-planta]');
  });

  test('a weekly entry carries its zone; daily and seasonal carry none', () {
    final catalogue = parseCatalogue(validAsset, nameOf: (_) => 'x');
    expect(catalogue.entries[2].zone, Zone.z1);
    expect(catalogue.entries[0].zone, isNull);
    expect(catalogue.entries[3].zone, isNull);
  });

  test('the name resolver receives each entry id', () {
    final seen = <String>[];
    parseCatalogue(
      validAsset,
      nameOf: (id) {
        seen.add(id);
        return 'x';
      },
    );
    expect(seen, [
      'regar-una-planta',
      'poner-la-mesa',
      'pasar-la-aspiradora-a-la-cocina',
      'limpiar-el-horno',
    ]);
  });

  test('a fifth field fails the parse naming entry id and field', () {
    const asset = '''
{
  "version": 1,
  "entries": [
    {"id": "regar-una-planta", "size": "instant", "cadence": "daily", "cluster": "anclas"}
  ]
}
''';
    expect(
      () => parseCatalogue(asset, nameOf: (_) => 'x'),
      throwsA(
        isA<FormatException>().having(
          (error) => error.message,
          'message',
          allOf(contains('regar-una-planta'), contains('cluster')),
        ),
      ),
    );
  });

  test('a missing cadence fails the parse naming entry id and field', () {
    const asset = '''
{
  "version": 1,
  "entries": [
    {"id": "regar-una-planta", "size": "instant"}
  ]
}
''';
    expect(
      () => parseCatalogue(asset, nameOf: (_) => 'x'),
      throwsA(
        isA<FormatException>().having(
          (error) => error.message,
          'message',
          allOf(contains('regar-una-planta'), contains('cadence')),
        ),
      ),
    );
  });

  test(
    'a free-minutes size token fails the parse naming entry id and field',
    () {
      const asset = '''
{
  "version": 1,
  "entries": [
    {"id": "regar-una-planta", "size": "10min", "cadence": "daily"}
  ]
}
''';
      expect(
        () => parseCatalogue(asset, nameOf: (_) => 'x'),
        throwsA(
          isA<FormatException>().having(
            (error) => error.message,
            'message',
            allOf(
              contains('regar-una-planta'),
              contains('10min'),
              contains('size'),
            ),
          ),
        ),
      );
    },
  );

  test(
    'an out-of-domain zone token fails the parse naming entry and field',
    () {
      const asset = '''
{
  "version": 1,
  "entries": [
    {"id": "regar-una-planta", "size": "instant", "cadence": "daily", "zone": "z6"}
  ]
}
''';
      expect(
        () => parseCatalogue(asset, nameOf: (_) => 'x'),
        throwsA(
          isA<FormatException>().having(
            (error) => error.message,
            'message',
            allOf(
              contains('regar-una-planta'),
              contains('z6'),
              contains('zone'),
            ),
          ),
        ),
      );
    },
  );

  test('a duplicate id fails the parse naming the id', () {
    const asset = '''
{
  "version": 1,
  "entries": [
    {"id": "regar-una-planta", "size": "instant", "cadence": "daily"},
    {"id": "regar-una-planta", "size": "focus", "cadence": "weekly", "zone": "z3"}
  ]
}
''';
    expect(
      () => parseCatalogue(asset, nameOf: (_) => 'x'),
      throwsA(
        isA<FormatException>().having(
          (error) => error.message,
          'message',
          allOf(contains('duplicate'), contains('regar-una-planta')),
        ),
      ),
    );
  });

  test('malformed top levels and versions fail with plain messages', () {
    for (final asset in const [
      'not json at all',
      '[]',
      '{"entries": []}',
      '{"version": 2, "entries": []}',
      '{"version": 1, "entries": {}}',
      '{"version": 1, "entries": [null]}',
      '{"version": 1, "entries": [], "meta": {"authored": true}}',
    ]) {
      expect(
        () => parseCatalogue(asset, nameOf: (_) => 'x'),
        throwsA(isA<FormatException>()),
        reason: asset,
      );
    }
  });

  test('an unknown top-level field fails the parse naming the key', () {
    const asset = '{"version": 1, "entries": [], "meta": {"authored": true}}';
    expect(
      () => parseCatalogue(asset, nameOf: (_) => 'x'),
      throwsA(
        isA<FormatException>().having(
          (error) => error.message,
          'message',
          allOf(contains('unknown top-level field'), contains('meta')),
        ),
      ),
    );
  });

  test('a weekly entry without a zone fails naming entry id and field', () {
    const asset = '''
{
  "version": 1,
  "entries": [
    {"id": "cambiar-las-sabanas", "size": "focus", "cadence": "weekly"}
  ]
}
''';
    expect(
      () => parseCatalogue(asset, nameOf: (_) => 'x'),
      throwsA(
        isA<FormatException>().having(
          (error) => error.message,
          'message',
          allOf(
            contains('cambiar-las-sabanas'),
            contains('missing field "zone"'),
          ),
        ),
      ),
    );
  });

  test(
    'a zone on a daily or seasonal entry fails naming entry id and field',
    () {
      for (final cadence in const ['daily', 'seasonal']) {
        final asset =
            '''
{
  "version": 1,
  "entries": [
    {"id": "regar-una-planta", "size": "instant", "cadence": "$cadence", "zone": "z1"}
  ]
}
''';
        expect(
          () => parseCatalogue(asset, nameOf: (_) => 'x'),
          throwsA(
            isA<FormatException>().having(
              (error) => error.message,
              'message',
              allOf(
                contains('regar-una-planta'),
                contains('field "zone"'),
                contains('weekly'),
              ),
            ),
          ),
          reason: cadence,
        );
      }
    },
  );

  test('ids outside the kebab-case slug grammar fail the parse', () {
    for (final id in const ['Foo-bar', 'a--b', '-abc', 'abc-', 'a b']) {
      final asset =
          '''
{
  "version": 1,
  "entries": [
    {"id": "$id", "size": "instant", "cadence": "daily"}
  ]
}
''';
      expect(
        () => parseCatalogue(asset, nameOf: (_) => 'x'),
        throwsA(
          isA<FormatException>().having(
            (error) => error.message,
            'message',
            allOf(contains(id), contains('kebab-case slug')),
          ),
        ),
        reason: id,
      );
    }
  });

  test('numeral segments are legal slug words', () {
    const asset = '''
{
  "version": 1,
  "entries": [
    {"id": "recoger-3-cosas-del-suelo", "size": "instant", "cadence": "daily"}
  ]
}
''';
    final catalogue = parseCatalogue(asset, nameOf: (_) => 'x');
    expect(catalogue.entries.single.id, 'recoger-3-cosas-del-suelo');
  });

  test('entry failures start with entry "<id>": — the wording the tool checks locate lines by', () {
    // The format is a cross-tool contract: tool/check_catalogue_floor.dart
    // and tool/check_catalogue_id_diff.dart regex it to find the line.
    final badEntries = const [
      '{"id": "regar-una-planta", "size": "10min", "cadence": "daily"}',
      '{"id": "regar-una-planta", "size": "instant", "cadence": "diario"}',
      '{"id": "regar-una-planta", "size": "instant", "cadence": "daily", "zone": "z6"}',
      '{"id": "regar-una-planta", "size": "instant", "cadence": "daily", "cluster": "anclas"}',
      '{"id": "Foo-bar", "size": "instant", "cadence": "daily"}',
      '{"id": "cambiar-las-sabanas", "size": "focus", "cadence": "weekly"}',
    ];
    for (final entry in badEntries) {
      final asset = '{"version": 1, "entries": [$entry]}';
      expect(
        () => parseCatalogue(asset, nameOf: (_) => 'x'),
        throwsA(
          isA<FormatException>().having(
            (error) => error.message,
            'message',
            predicate<String>(
              (message) => message.startsWith('entry "'),
              'starts with entry "<id>":',
            ),
          ),
        ),
        reason: entry,
      );
    }
  });

  test('a non-string or empty id fails the parse', () {
    const asset = '''
{
  "version": 1,
  "entries": [
    {"id": "", "size": "instant", "cadence": "daily"}
  ]
}
''';
    expect(
      () => parseCatalogue(asset, nameOf: (_) => 'x'),
      throwsA(
        isA<FormatException>().having(
          (error) => error.message,
          'message',
          allOf(contains('#0'), contains('id')),
        ),
      ),
    );
  });

  test('the parsed entries list is unmodifiable', () {
    final catalogue = parseCatalogue(validAsset, nameOf: (_) => 'x');
    expect(
      () => catalogue.entries.add(
        CatalogueEntry(
          id: 'fantasma',
          size: Size.instant,
          cadence: Cadence.daily,
          name: 'x',
        ),
      ),
      throwsUnsupportedError,
    );
  });
}

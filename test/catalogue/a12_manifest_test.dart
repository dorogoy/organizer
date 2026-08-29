import 'dart:io';

import 'package:core/catalogue/catalogue.dart';
import 'package:core/catalogue/strict_json.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:organizer/catalogue/catalogue_names.g.dart';
import 'package:organizer/strings/app_strings_es.dart';

const manifestPath = 'test/fixtures/catalogue/a12_v1_manifest.json';
const assetPath = 'assets/evergreen/catalogue.json';

void main() {
  test('the ordered A12 v1 tuple and deliberate exclusions remain frozen', () {
    final manifest = strictJsonDecode(
      File(manifestPath).readAsStringSync(),
    ) as Map<String, dynamic>;
    final strings = AppStringsEs();
    final catalogue = parseCatalogue(
      File(assetPath).readAsStringSync(),
      nameOf: (id) => catalogueNameOf[id]!(strings),
    );
    final actual = [
      for (final entry in catalogue.entries)
        <String, Object?>{
          'id': entry.id,
          'size': entry.size.name,
          'cadence': entry.cadence.name,
          'zone': entry.zone?.name,
          'name': entry.name,
        },
    ];
    expect(manifest['version'], 1);
    expect(manifest['entries'], actual);
    expect(manifest['exclusions'], [
      'cooking and clock-bound work',
      'seasonal wardrobe change',
      'organizing the storage room',
      'non-spatial errands',
    ]);
  });
}

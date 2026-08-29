import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:core/catalogue/catalogue.dart';
import 'package:core/pool/pool_fact.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:organizer/catalogue/catalogue_names.g.dart';
import 'package:organizer/catalogue/loader.dart';
import 'package:organizer/strings/app_strings_es.dart';

/// A fake bundle holding in-memory sources — the real asset file's bytes,
/// or whatever drift scenario a test needs — so the loader runs fully
/// offline: no network, no platform channel, nothing but what the shipped
/// bundle would hold.
class _FakeBundle implements AssetBundle {
  _FakeBundle(this._sources, [this._loadFailure]);

  final Map<String, String> _sources;
  final Object? _loadFailure;
  final List<String> requested = [];

  @override
  Future<ByteData> load(String key) async {
    final bytes = utf8.encode(await loadString(key));
    return ByteData.view(bytes.buffer);
  }

  @override
  Future<ui.ImmutableBuffer> loadBuffer(String key) async {
    final bytes = utf8.encode(await loadString(key));
    return ui.ImmutableBuffer.fromUint8List(bytes);
  }

  @override
  Future<String> loadString(String key, {bool cache = true}) async {
    requested.add(key);
    final failure = _loadFailure;
    if (failure != null) {
      throw failure;
    }
    final source = _sources[key];
    if (source == null) {
      throw FileSystemException('asset not in fake bundle', key);
    }
    return source;
  }

  @override
  Future<T> loadStructuredData<T>(
    String key,
    FutureOr<T> Function(String value) parser,
  ) => loadString(key).then(parser);

  @override
  Future<T> loadStructuredBinaryData<T>(
    String key,
    FutureOr<T> Function(ByteData data) parser,
  ) => load(key).then(parser);

  @override
  void evict(String key) {}

  @override
  void clear() {}
}

/// The shipped asset's exact bytes, read from disk once per test.
_FakeBundle _shippedBundle() => _FakeBundle({
  catalogueAssetPath: File(catalogueAssetPath).readAsStringSync(),
});

void main() {
  test(
    'the loader hands the core 85 named inert entries, fully offline',
    () async {
      final bundle = _shippedBundle();
      final catalogue = await loadEvergreenCatalogue(
        AppStringsEs(),
        bundle: bundle,
      );
      expect(bundle.requested, [catalogueAssetPath]);
      expect(catalogue.version, 1);
      expect(catalogue.entries, hasLength(85));

      final byId = {for (final entry in catalogue.entries) entry.id: entry};
      expect(
        byId['regar-una-planta']!.name,
        'Regar una planta',
        reason: 'names resolve through the generated table, not the asset',
      );
      expect(
        byId['limpiar-el-interior-del-coche']!.name,
        'Limpiar el interior del coche',
      );
      expect(
        byId['repasar-el-espejo-del-bano-con-la-toalla-usada']!.name,
        'Repasar el espejo del baño con la toalla usada',
      );
      expect(catalogue.entries.every((entry) => entry.name.isNotEmpty), isTrue);
    },
  );

  testWidgets('the registered Flutter bundle resolves all 85 named entries', (
    tester,
  ) async {
    final catalogue = await loadEvergreenCatalogue(AppStringsEs());
    expect(catalogue.entries, hasLength(85));
    expect(catalogue.entries.every((entry) => entry.name.isNotEmpty), isTrue);
  });

  test('the shipped catalogue holds A12 cadence and zone counts', () async {
    final catalogue = await loadEvergreenCatalogue(
      AppStringsEs(),
      bundle: _shippedBundle(),
    );
    final cadences = <Cadence, int>{};
    for (final entry in catalogue.entries) {
      cadences.update(entry.cadence, (count) => count + 1, ifAbsent: () => 1);
    }
    expect(cadences[Cadence.daily], 34);
    expect(cadences[Cadence.weekly], 36);
    expect(cadences[Cadence.seasonal], 15);

    final dailySizes = <String, int>{};
    for (final entry in catalogue.entries.where(
      (entry) => entry.cadence == Cadence.daily,
    )) {
      dailySizes.update(
        entry.size.name,
        (count) => count + 1,
        ifAbsent: () => 1,
      );
    }
    expect(dailySizes['instant'], 14);
    expect(dailySizes['maintenance'], 14);
    expect(dailySizes['focus'], 6);

    final zoneCounts = <Zone, int>{};
    for (final entry in catalogue.entries.where(
      (entry) => entry.zone != null,
    )) {
      zoneCounts.update(entry.zone!, (count) => count + 1, ifAbsent: () => 1);
    }
    expect(zoneCounts[Zone.z1], 8);
    expect(zoneCounts[Zone.z2], 7);
    expect(zoneCounts[Zone.z3], 7);
    expect(zoneCounts[Zone.z4], 7);
    expect(zoneCounts[Zone.z5], 7);
  });

  test('the floor math holds: 32 distinct focus non-daily entries', () async {
    final catalogue = await loadEvergreenCatalogue(
      AppStringsEs(),
      bundle: _shippedBundle(),
    );
    final eligible = catalogue.entries
        .where(
          (entry) => entry.size == Size.focus && entry.cadence != Cadence.daily,
        )
        .map((entry) => entry.id)
        .toSet();
    expect(eligible, hasLength(32));
  });

  test(
    'no entry carries another task, an hour or a mealtime dependency',
    () async {
      // A12's invariant, pinned cheaply on the shipped names: the clock-bound
      // and cross-task vocabulary the catalogue deliberately excludes never
      // re-enters through the ARB values.
      final forbidden = [
        'cocinar',
        'desayuno',
        'comida ',
        'cena',
        'antes de ',
        'después de ',
      ];
      final catalogue = await loadEvergreenCatalogue(
        AppStringsEs(),
        bundle: _shippedBundle(),
      );
      for (final entry in catalogue.entries) {
        final lower = entry.name.toLowerCase();
        for (final token in forbidden) {
          expect(
            lower.contains(token),
            isFalse,
            reason: '${entry.id}: "${entry.name}" carries "$token"',
          );
        }
      }
    },
  );

  test('an asset id absent from the generated table fails naming the id '
      '(stale-codegen drift, never a null-check crash)', () async {
    const driftAsset =
        '{"version": 1, "entries": ['
        '{"id": "fantasma-en-el-trastero", "size": "instant", '
        '"cadence": "daily"}]}';
    final bundle = _FakeBundle({catalogueAssetPath: driftAsset});
    await expectLater(
      loadEvergreenCatalogue(AppStringsEs(), bundle: bundle),
      throwsA(
        isA<FormatException>().having(
          (error) => error.message,
          'message',
          allOf(
            contains('fantasma-en-el-trastero'),
            contains('stale'),
            contains('gen_catalogue_lookup'),
          ),
        ),
      ),
    );
  });

  test(
    'a failing asset read surfaces catalogue context, not a bare cause',
    () async {
      final bundle = _FakeBundle({}, StateError('boom'));
      await expectLater(
        loadEvergreenCatalogue(AppStringsEs(), bundle: bundle),
        throwsA(
          isA<Exception>().having(
            (error) => error.toString(),
            'toString',
            allOf(
              contains('assets/evergreen/catalogue.json'),
              contains('boom'),
            ),
          ),
        ),
      );
    },
  );

  test('the generated name table is unmodifiable', () {
    expect(
      () => catalogueNameOf['fantasma-en-el-trastero'] = (_) => 'x',
      throwsUnsupportedError,
    );
    expect(
      () => catalogueNameOf.remove('hacer-la-cama'),
      throwsUnsupportedError,
    );
    expect(() => catalogueNameOf.clear(), throwsUnsupportedError);
  });
}

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:core/catalogue/catalogue.dart';
import 'package:core/log/log_entry.dart';
import 'package:core/pool/pool_fact.dart';
import 'package:core/weave/weave.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:organizer/catalogue/catalogue_names.g.dart';
import 'package:organizer/catalogue/loader.dart';
import 'package:organizer/strings/app_strings_es.dart';

/// A fake bundle holding the real asset file's bytes — the loader runs
/// fully offline, exactly as `test/catalogue/loader_test.dart` drives it.
class _FakeBundle implements AssetBundle {
  _FakeBundle(this._sources);

  final Map<String, String> _sources;

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

Future<Catalogue> _shippedCatalogue() => loadEvergreenCatalogue(
  AppStringsEs(),
  bundle: _FakeBundle({
    catalogueAssetPath: File(catalogueAssetPath).readAsStringSync(),
  }),
);

int _utcMicros(
  int year,
  int month,
  int day, [
  int hour = 0,
  int minute = 0,
  int second = 0,
  int millisecond = 0,
  int microsecond = 0,
]) => DateTime.utc(
  year,
  month,
  day,
  hour,
  minute,
  second,
  millisecond,
  microsecond,
).microsecondsSinceEpoch;

const int _microsPerDay = 24 * 60 * 60 * 1000 * 1000;

ItemActEntry _dealt(int micros, String itemId) => ItemActEntry(
  id: 'dealt-$micros-$itemId',
  instantUtcMicros: micros,
  offsetSeconds: 0,
  kind: LogKind.cardDealt,
  itemId: itemId,
  itemOrigin: Origin.shipped,
);

ItemActEntry _done(int micros, String itemId) => ItemActEntry(
  id: 'done-$micros-$itemId',
  instantUtcMicros: micros,
  offsetSeconds: 0,
  kind: LogKind.cardDone,
  itemId: itemId,
  itemOrigin: Origin.shipped,
);

void main() {
  test('28 answered chunks over the shipped asset never repeat a Micro-task '
      '(FR-31, AD-16)', () async {
    final catalogue = await _shippedCatalogue();

    // The floor the derivation stands on: 5/3/4/5/3 zone focus entries
    // plus 12 fondo — 32 eligible, all distinct ids.
    final zoneFocusCounts = <Zone, int>{};
    final eligibleFocusIds = <String>{};
    for (final entry in catalogue.entries) {
      if (entry.size != Size.focus || entry.cadence == Cadence.daily) {
        continue;
      }
      eligibleFocusIds.add(entry.id);
      if (entry.zone != null) {
        zoneFocusCounts.update(
          entry.zone!,
          (count) => count + 1,
          ifAbsent: () => 1,
        );
      }
    }
    expect(
      [for (final zone in Zone.values) zoneFocusCounts[zone]],
      [5, 3, 4, 5, 3],
    );
    expect(eligibleFocusIds, hasLength(32));

    // 28 days of deal+answer from Monday 2026-08-24 — the week whose
    // ring position is z1 (weeks since the epoch Monday 2000-01-03:
    // 1390, mod 5 = 0), the default all-active curation state, 🟢 and
    // the default bag throughout.
    var log = <LogEntry>[];
    final dealtIds = <String>[];
    final dealtZones = <Zone?>[];
    for (var day = 0; day < 28; day++) {
      final instant = _utcMicros(2026, 8, 24, 12) + day * _microsPerDay;
      final deal = nextDeal(
        catalogue: catalogue,
        log: log,
        instantUtcMicros: instant,
        offsetSeconds: 0,
      );
      expect(deal, isNotNull, reason: 'day $day of the run holds a chunk');
      expect(deal!.size, Size.focus);
      dealtIds.add(deal.id);
      dealtZones.add(deal.zone);
      log
        ..add(_dealt(instant, deal.id))
        ..add(_done(instant + 1, deal.id));
    }

    // The AC itself: 28 answered chunks, no Micro-task repeated.
    expect(dealtIds.toSet(), hasLength(28));
    expect(dealtIds.every(eligibleFocusIds.contains), isTrue);

    // And the tier arithmetic that makes it true, week by week: each
    // zone's never-answered entries first, fondo filling each week's
    // remainder, the ring advancing one zone a week.
    expect(dealtZones, [
      ...List.filled(5, Zone.z1), // Mon–Fri: the five z1 entries
      null,
      null, // the weekend: fondo fills
      ...List.filled(3, Zone.z2),
      null,
      null,
      null,
      null, // 3 z2 days + 4 fondo days
      ...List.filled(4, Zone.z3),
      null,
      null,
      null, // 4 z3 days + 3 fondo days
      ...List.filled(5, Zone.z4),
      null,
      null, // 5 z4 days + 2 fondo days
    ]);
    expect(dealtZones.where((zone) => zone != null), hasLength(17));
    expect(dealtZones.where((zone) => zone == null), hasLength(11));
  });
}

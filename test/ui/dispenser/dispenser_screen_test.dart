// The Dispenser surface's contract (Story 1.8): the launch deal renders
// with the fake store + the real asset bytes + a fixed clock; the warm
// close stands when the deal is absent; a failed catalogue read leaves
// the empty frame with the memo cleared for the next read; 200% font
// scale grows into the air and scrolls with nothing truncated; and no
// loader ever precedes the first card — the I/O matrix's rows, pinned.
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:core/ports/store_port.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:organizer/catalogue/catalogue_names.g.dart';
import 'package:organizer/catalogue/loader.dart';
import 'package:organizer/dispenser/dispenser_controller.dart';
import 'package:organizer/session/session_controller.dart';
import 'package:organizer/strings/app_strings.dart';
import 'package:organizer/strings/app_strings_es.dart';
import 'package:organizer/ui/dispenser/dispenser_screen.dart';
import 'package:organizer/ui/dispenser/duration_chip.dart';
import 'package:organizer/ui/dispenser/task_card.dart';
import 'package:organizer/ui/dispenser/zone_marker.dart';
import 'package:organizer/ui/glyphs/leaf_glyph.dart';
import 'package:organizer/ui/theme.dart';
import 'package:organizer/ui/tokens.dart';

/// The recording store (the session suite's own contract): appends land
/// in order and every read replays them.
class _RecordingStore implements StorePort {
  final List<LogEntryRecord> entries = [];

  @override
  Future<void> appendPoolFact(PoolFactRecord fact) async {}

  @override
  Future<void> appendLogEntry(LogEntryRecord entry) async => entries.add(entry);

  @override
  Future<List<PoolFactRecord>> readPoolFacts() async => const [];

  @override
  Future<List<LogEntryRecord>> readLogEntries() async =>
      List.unmodifiable(entries);
}

/// A fake bundle holding the shipped asset's exact bytes, so the loader
/// runs fully offline (the session suite's pattern).
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
  Future<String> loadString(String key, {bool cache = true}) async =>
      _sources[key] ??
      (throw FileSystemException('asset not in fake bundle', key));

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

/// A bundle whose first read fails and whose later reads return the
/// bytes — the transient-asset-read shape the controller's memo must not
/// remember.
class _FlakyBundle implements AssetBundle {
  _FlakyBundle(this._asset);

  final String _asset;
  var reads = 0;

  Future<String> _source(String key) async {
    reads++;
    if (reads == 1) {
      throw StateError('transient read failure');
    }
    return _asset;
  }

  @override
  Future<ByteData> load(String key) async {
    final bytes = utf8.encode(await _source(key));
    return ByteData.view(bytes.buffer);
  }

  @override
  Future<ui.ImmutableBuffer> loadBuffer(String key) async {
    final bytes = utf8.encode(await _source(key));
    return ui.ImmutableBuffer.fromUint8List(bytes);
  }

  @override
  Future<String> loadString(String key, {bool cache = true}) => _source(key);

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

DateTime _fixedClock() => DateTime.utc(2026, 8, 29, 12);

Widget _harness(DispenserController controller) => MaterialApp(
  theme: OrganizerTheme.light(),
  localizationsDelegates: AppStrings.localizationsDelegates,
  supportedLocales: AppStrings.supportedLocales,
  home: DispenserScreen(controller: controller),
);

void main() {
  final shipped = File(catalogueAssetPath).readAsStringSync();

  DispenserController buildController(
    _RecordingStore store, {
    AssetBundle? bundle,
  }) => DispenserController(
    store: store,
    strings: AppStringsEs(),
    bundle: bundle ?? _FakeBundle({catalogueAssetPath: shipped}),
    nowOf: _fixedClock,
  );

  /// The session's dealt row, found by kind — never by append position:
  /// a new fact landing between the open and the deal must not move the
  /// pin.
  LogEntryRecord? dealtEntryOf(_RecordingStore store) {
    for (final entry in store.entries) {
      if (entry.kind == 'card_dealt') {
        return entry;
      }
    }
    return null;
  }

  testWidgets('a cold start renders the launch deal — chip, task, Hecho, '
      'secondary and the matching footer — with no loader before it', (
    tester,
  ) async {
    final store = _RecordingStore();
    await SessionController(
      store: store,
      strings: AppStringsEs(),
      bundle: _FakeBundle({catalogueAssetPath: shipped}),
      nowOf: _fixedClock,
    ).handleAppOpen();
    final dealtEntryId = dealtEntryOf(store)!.itemId!;

    await tester.pumpWidget(_harness(buildController(store)));
    // First frame: nothing but the empty surfaceBase frame — no splash,
    // spinner or loader ever precedes the first card (UX-DR41, NFR5).
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.byType(LinearProgressIndicator), findsNothing);
    expect(find.byType(RefreshProgressIndicator), findsNothing);

    await tester.pumpAndSettle();

    final catalogue = await loadEvergreenCatalogue(
      AppStringsEs(),
      bundle: _FakeBundle({catalogueAssetPath: shipped}),
    );
    final entry = catalogue.entries.firstWhere(
      (candidate) => candidate.id == dealtEntryId,
    );

    // The dealt Micro-task, with its cost and its two actions.
    expect(find.byType(TaskCard), findsOneWidget);
    expect(find.text(entry.name), findsOneWidget);
    expect(find.byType(DurationChip), findsOneWidget);
    expect(find.text('15\u00A0min'), findsOneWidget);
    expect(find.text('Hecho'), findsOneWidget);
    expect(find.text('Otra más fácil / Ahora no'), findsOneWidget);

    // The footer iff the dealt entry carries a zone — never invented.
    if (entry.zone != null) {
      expect(find.byType(LeafGlyph), findsOneWidget);
      expect(find.byType(ZoneMarker), findsOneWidget);
      expect(find.text(zoneLabel(entry.zone!, AppStringsEs())), findsOneWidget);
    } else {
      expect(find.byType(LeafGlyph), findsNothing);
    }

    // Still no loader, and exactly one actionable Micro-task.
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.byType(TaskCard), findsOneWidget);
    expect(find.text('Hecho'), findsOneWidget);
  });

  testWidgets('a null deal shows the warm close verbatim, quiet — never '
      'an error', (tester) async {
    final store = _RecordingStore();
    final controller = buildController(
      store,
      bundle: _FakeBundle({catalogueAssetPath: '{"version":1,"entries":[]}'}),
    );

    await tester.pumpWidget(_harness(controller));
    await tester.pumpAndSettle();

    expect(
      find.text('por hoy no hay nada más que merezca la pena'),
      findsOneWidget,
    );
    // Quiet: the secondary action's role and ink, centered, no card, no
    // error surface.
    final style = tester
        .widget<Text>(find.text(AppStringsEs().poolExhaustedClose))
        .style!;
    expect(style.color, FieldPalette.inkSecondary);
    expect(style.fontFamily, FontFamilies.lexend);
    expect(find.byType(TaskCard), findsNothing);
    expect(find.byType(ErrorWidget), findsNothing);
  });

  testWidgets('200% font scale: the card grows into its air, nothing is '
      'truncated, and the screen scrolls (UX-DR14, NFR6)', (tester) async {
    tester.platformDispatcher.textScaleFactorTestValue = 2.0;
    addTearDown(tester.platformDispatcher.clearAllTestValues);
    await tester.binding.setSurfaceSize(const Size(320, 480));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final store = _RecordingStore();
    await SessionController(
      store: store,
      strings: AppStringsEs(),
      bundle: _FakeBundle({catalogueAssetPath: shipped}),
      nowOf: _fixedClock,
    ).handleAppOpen();
    final dealtEntryId = dealtEntryOf(store)!.itemId!;

    await tester.pumpWidget(_harness(buildController(store)));
    await tester.pumpAndSettle();

    // Growing and scrolling, never truncating: no layout exception, a
    // scroll view holding the grown card, and every string whole.
    expect(tester.takeException(), isNull);
    expect(find.byType(SingleChildScrollView), findsOneWidget);
    expect(find.text('Otra más fácil / Ahora no'), findsOneWidget);
    expect(find.text('15\u00A0min'), findsOneWidget);

    final catalogue = await loadEvergreenCatalogue(
      AppStringsEs(),
      bundle: _FakeBundle({catalogueAssetPath: shipped}),
    );
    final entry = catalogue.entries.firstWhere(
      (candidate) => candidate.id == dealtEntryId,
    );
    expect(find.text(entry.name), findsOneWidget);

    // The screen really scrolls: the grown card exceeds the viewport,
    // and the drag moves the position — not just a no-op gesture.
    final scrollable = tester.state<ScrollableState>(find.byType(Scrollable));
    expect(
      scrollable.position.maxScrollExtent,
      greaterThan(0),
      reason:
          'the 200% card must outgrow the viewport for the scroll '
          'pin to be real',
    );
    await tester.drag(
      find.byType(SingleChildScrollView),
      const Offset(0, -240),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(scrollable.position.pixels, greaterThan(0));
  });

  testWidgets('the card caps at its width bound on wide grounds — the '
      'side margins and max-width constraint hold', (tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 600));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final store = _RecordingStore();
    await SessionController(
      store: store,
      strings: AppStringsEs(),
      bundle: _FakeBundle({catalogueAssetPath: shipped}),
      nowOf: _fixedClock,
    ).handleAppOpen();

    await tester.pumpWidget(_harness(buildController(store)));
    await tester.pumpAndSettle();

    final cardBox = tester.renderObject<RenderBox>(find.byType(TaskCard));
    expect(cardBox.size.width, closeTo(480, 0.5));
    // Centered in the remaining ground, margins intact on both sides.
    expect(cardBox.localToGlobal(Offset.zero).dx, closeTo(160, 0.5));
  });

  testWidgets('a failed read leaves the empty frame standing; a real '
      'return to the foreground re-reads and the dealt card renders', (
    tester,
  ) async {
    final store = _RecordingStore();
    await SessionController(
      store: store,
      strings: AppStringsEs(),
      bundle: _FakeBundle({catalogueAssetPath: shipped}),
      nowOf: _fixedClock,
    ).handleAppOpen();

    // The flaky bundle's first read fails — the empty frame stands.
    final controller = DispenserController(
      store: store,
      strings: AppStringsEs(),
      bundle: _FlakyBundle(shipped),
      nowOf: _fixedClock,
    );
    await tester.pumpWidget(_harness(controller));
    await tester.pumpAndSettle();

    expect(find.byType(TaskCard), findsNothing);
    expect(find.byType(ErrorWidget), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.byType(LinearProgressIndicator), findsNothing);

    // The transient clears on its own; nothing has re-triggered a read
    // yet, so the frame still stands.
    expect(find.byType(TaskCard), findsNothing);

    // A real return from off-foreground re-reads (the SessionController
    // pattern): the observer fires on resumed only, and the retry now
    // resolves to the launch deal.
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pumpAndSettle();
    expect(find.byType(TaskCard), findsNothing);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();

    expect(find.byType(TaskCard), findsOneWidget);
    expect(find.text('Hecho'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  test(
    'a failed catalogue read leaves the empty frame standing and clears '
    'the memo — the next read retries (the session controller\'s pattern)',
    () async {
      final store = _RecordingStore();
      final controller = DispenserController(
        store: store,
        strings: AppStringsEs(),
        bundle: _FlakyBundle(shipped),
        nowOf: _fixedClock,
      );

      await expectLater(controller.read(), throwsA(isA<Exception>()));
      // The retry resolves once the transient read clears.
      final view = await controller.read();
      expect(view, isA<DispenserDealt>());
    },
  );

  test('the read mints its instant at entry, before any await — the '
      'recorded rows describe the moment the user is looking at the '
      'screen, not the reads that follow (the session controller\'s own '
      'contract)', () {
    final source = File('lib/dispenser/dispenser_controller.dart')
        .readAsStringSync();
    final mintedAtEntry = source.indexOf('final now = nowOf();');
    final firstAwait = source.indexOf('await _loadCatalogue()');
    expect(mintedAtEntry, greaterThanOrEqualTo(0));
    expect(firstAwait, greaterThanOrEqualTo(0));
    expect(
      mintedAtEntry,
      lessThan(firstAwait),
      reason:
          'the clock is read before the first await, so no store or '
          'asset latency can shift the minted instant',
    );
  });
}

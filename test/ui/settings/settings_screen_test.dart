// The Settings surfaces' contract (Story 2.1, UX-DR25/UX-DR33): the nav
// chain Dispenser → `Nuevo proyecto` → `Ajustes` → Settings; the honest
// emptiness of the intermediate surface; the flat platform list whose
// first group is Tu día holding the Time Bag; the six stepped options in
// the size-option idiom; one tap appending exactly one `setting_changed`
// row with no confirmation of any kind; the selected option reading as
// the derived current value; and the quiet prose grammar on every
// way-out — ink-secondary text, 48dp, no glyph, no pastel mass.
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:core/log/log_entry.dart';
import 'package:core/pool/pool_fact.dart';
import 'package:core/ports/recognizer_port.dart';
import 'package:core/ports/store_port.dart';
import 'package:core/settings/settings.dart';
import 'package:flutter/material.dart' hide Card;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:organizer/catalogue/catalogue_names.g.dart';
import 'package:organizer/dispenser/dispenser_controller.dart';
import 'package:organizer/settings/settings_controller.dart';
import 'package:organizer/strings/app_strings.dart';
import 'package:organizer/strings/app_strings_es.dart';
import 'package:organizer/ui/dispenser/dispenser_screen.dart';
import 'package:organizer/ui/settings/nuevo_proyecto_screen.dart';
import 'package:organizer/ui/settings/settings_screen.dart';
import 'package:organizer/ui/theme.dart';
import 'package:organizer/ui/tokens.dart';

/// The recording store (the dispenser suite's own contract): appends
/// land in order and every read replays them.
class _RecordingStore implements StorePort {
  final List<LogEntryRecord> entries = [];
  final List<PoolFactRecord> facts = [];

  @override
  Future<void> appendPoolFact(PoolFactRecord fact) async => facts.add(fact);

  @override
  Future<void> appendLogEntry(LogEntryRecord entry) async => entries.add(entry);

  @override
  Future<List<PoolFactRecord>> readPoolFacts() async =>
      List.unmodifiable(facts);

  @override
  Future<List<LogEntryRecord>> readLogEntries() async =>
      List.unmodifiable(entries);
}

/// The recognizer seam's fake (Story 3.4): the probe's platform answer
/// and the app-details action's call count.
class _FakeRecognizer implements RecognizerPort {
  _FakeRecognizer(this.availability);

  RecognizerAvailability availability;
  int openAppSettingsCalls = 0;

  @override
  Future<RecognizerAvailability> probe() async => availability;

  @override
  Future<RecognizerStart> start(int sessionId) async =>
      RecognizerStart.unavailable;

  @override
  Future<void> cancel(int sessionId) async {}

  @override
  Stream<RecognizerOutcome> get outcomes => const Stream.empty();

  @override
  Future<void> openAppSettings() async {
    openAppSettingsCalls++;
  }
}

/// Holds its first read after taking a snapshot, so a later refresh can
/// complete first and prove that an old response cannot restore old state.
class _StaleFirstReadStore extends _RecordingStore {
  final firstReadGate = Completer<void>();
  var _isFirstRead = true;

  @override
  Future<List<LogEntryRecord>> readLogEntries() async {
    if (_isFirstRead) {
      _isFirstRead = false;
      final snapshot = List<LogEntryRecord>.unmodifiable(entries);
      await firstReadGate.future;
      return snapshot;
    }
    return super.readLogEntries();
  }
}

/// A bundle over the shipped asset's exact bytes (the dispenser suite's
/// pattern), so the loader runs fully offline.
class _ShippedBundle implements AssetBundle {
  final String _asset;

  _ShippedBundle(this._asset);

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
  Future<String> loadString(String key, {bool cache = true}) async => _asset;

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

/// A store whose first `setting_changed` append throws — the
/// write-failure row ported from the dispenser suite's failing-store
/// idiom: the controller's chain must recover (the `.catchError` is
/// load-bearing) so the next change can still land.
class _FailFirstSettingAppendStore implements StorePort {
  _FailFirstSettingAppendStore(this._inner);

  final _RecordingStore _inner;
  var _thrown = false;

  @override
  Future<void> appendPoolFact(PoolFactRecord fact) async {}

  @override
  Future<void> appendLogEntry(LogEntryRecord entry) async {
    if (!_thrown && entry.kind == 'setting_changed') {
      _thrown = true;
      throw StateError('append failed');
    }
    await _inner.appendLogEntry(entry);
  }

  @override
  Future<List<PoolFactRecord>> readPoolFacts() async => const [];

  @override
  Future<List<LogEntryRecord>> readLogEntries() async =>
      _inner.readLogEntries();
}

DateTime _fixedClock() => DateTime.utc(2026, 8, 29, 12);

void main() {
  final shipped = File(catalogueAssetPath).readAsStringSync();

  Widget harnessFor(_RecordingStore store, SettingsController? settings) {
    return MaterialApp(
      theme: OrganizerTheme.light(),
      localizationsDelegates: AppStrings.localizationsDelegates,
      supportedLocales: AppStrings.supportedLocales,
      home: DispenserScreen(
        controller: DispenserController(
          store: store,
          strings: AppStringsEs(),
          bundle: _ShippedBundle(shipped),
          nowOf: _fixedClock,
        ),
        settings: settings,
      ),
    );
  }

  Widget harness(_RecordingStore store, {SettingsController? settings}) =>
      harnessFor(
        store,
        settings ?? SettingsController(store: store, nowOf: _fixedClock),
      );

  Future<void> launch(WidgetTester tester, _RecordingStore store) async {
    await tester.pumpWidget(harness(store));
    await tester.pumpAndSettle();
  }

  /// Opens Settings through the real chain — footer, way-out — leaving
  /// the Settings surface on top and ready to tap.
  Future<void> openSettings(WidgetTester tester) async {
    await tester.tap(find.text(AppStringsEs().newProjectLink));
    await tester.pumpAndSettle();
    await tester.tap(find.text(AppStringsEs().settingsWayOut));
    await tester.pumpAndSettle();
  }

  /// The texts the whole tree carries, every channel included — the
  /// quietness census: nothing beyond the authored strings may render.
  List<String> textsOf(WidgetTester tester) {
    final texts = <String?>[
      for (final text in tester.widgetList<Text>(find.byType(Text))) text.data,
      for (final rich in tester.widgetList<RichText>(find.byType(RichText)))
        rich.text.toPlainText(),
      for (final tooltip in tester.widgetList<Tooltip>(find.byType(Tooltip)))
        tooltip.message,
      for (final semantics in tester.widgetList<Semantics>(
        find.byType(Semantics),
      ))
        semantics.properties.label,
    ];
    return [
      for (final value in texts)
        if (value != null && value.isNotEmpty) value,
    ];
  }

  testWidgets('the nav chain: the footer opens the carrier, the carrier\'s '
      'way-out opens Settings, and system back pops each (Story 2.1, NFR3)', (
    tester,
  ) async {
    final store = _RecordingStore();
    await launch(tester, store);

    await tester.tap(find.text(AppStringsEs().newProjectLink));
    await tester.pumpAndSettle();
    expect(find.byType(NuevoProyectoScreen), findsOneWidget);
    expect(find.byType(SettingsScreen), findsNothing);

    await tester.tap(find.text(AppStringsEs().settingsWayOut));
    await tester.pumpAndSettle();
    expect(find.byType(SettingsScreen), findsOneWidget);
    // The carrier stays on the route stack below, offstage.
    expect(
      find.byType(NuevoProyectoScreen, skipOffstage: false),
      findsOneWidget,
    );

    // System back pops Settings, then the carrier — the Dispenser stands.
    // The surfaces carry no back chrome; the system gesture is the pop,
    // simulated here as the platform's popRoute message.
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byType(SettingsScreen), findsNothing);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byType(NuevoProyectoScreen), findsNothing);
    expect(find.text(AppStringsEs().newProjectLink), findsOneWidget);

    // The whole chain wrote nothing: navigation is pure reading.
    expect(
      store.entries.where((entry) => entry.kind == 'setting_changed'),
      isEmpty,
    );
  });

  testWidgets('the intermediate surface is honestly empty — the Ajustes '
      'way-out is its only content (epics.md:889, UX-DR25)', (tester) async {
    final store = _RecordingStore();
    await launch(tester, store);

    await tester.tap(find.text(AppStringsEs().newProjectLink));
    await tester.pumpAndSettle();

    // No heading, no chrome, no placeholder for Epic 5's genesis: the
    // census is exactly the one way-out string (the Text and RichText
    // channels double-report one widget, so the census reads a set).
    expect(textsOf(tester).toSet(), {AppStringsEs().settingsWayOut});
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.byType(Icon), findsNothing);

    // The way-out holds the same quiet grammar: ink-secondary prose in
    // a 48dp opaque band, no pastel mass.
    final wayOut = find.text(AppStringsEs().settingsWayOut);
    final style = tester.widget<Text>(wayOut).style!;
    expect(style.color, FieldPalette.inkSecondary);
    expect(style.fontFamily, FontFamilies.lexend);
    final band = tester.renderObject<RenderBox>(
      find.ancestor(of: wayOut, matching: find.byType(GestureDetector)),
    );
    expect(band.size.height, greaterThanOrEqualTo(48));
    expect(
      find.descendant(
        of: find.byType(GestureDetector),
        matching: find.byType(Material),
      ),
      findsNothing,
      reason: 'no pastel mass on a way out',
    );
  });

  testWidgets('Settings is a flat platform list whose first group is Tu '
      'día, holding the Time Bag as six stepped options (UX-DR33, FR-7)', (
    tester,
  ) async {
    final store = _RecordingStore();
    await launch(tester, store);

    await tester.tap(find.text(AppStringsEs().newProjectLink));
    await tester.pumpAndSettle();
    await tester.tap(find.text(AppStringsEs().settingsWayOut));
    await tester.pumpAndSettle();

    // The list scrolls (ListView in the frame idiom) and the quiet
    // census is exactly the group header, the row label, the six
    // stepped options and the validator surface's dictated-count line
    // (Story 3.4 — zero until a dictated capture exists) — no heading
    // chrome, no other group, no light/dark row, no glyph.
    expect(find.byType(ListView), findsOneWidget);
    expect(textsOf(tester).toSet(), {
      AppStringsEs().settingsGroupYourDay,
      AppStringsEs().settingsTimeBag,
      '5\u00A0min',
      '10\u00A0min',
      '15\u00A0min',
      '20\u00A0min',
      '25\u00A0min',
      '30\u00A0min',
      AppStringsEs().settingsDictatedCount(0),
    });
    expect(find.byType(Icon), findsNothing);

    // The group header is support copy, quiet.
    final header = tester.widget<Text>(
      find.text(AppStringsEs().settingsGroupYourDay),
    );
    expect(header.style!.color, FieldPalette.inkSecondary);
    expect(header.style!.fontSize, 13);
  });

  testWidgets('one option tap appends exactly one setting_changed row and '
      'moves the selection — no confirmation of any kind (FR-7, AD-1)', (
    tester,
  ) async {
    final store = _RecordingStore();
    await launch(tester, store);

    await tester.tap(find.text(AppStringsEs().newProjectLink));
    await tester.pumpAndSettle();
    await tester.tap(find.text(AppStringsEs().settingsWayOut));
    await tester.pumpAndSettle();

    // The default selection: 15, once the derivation lands.
    await tester.pumpAndSettle();
    expect(selectedMinutes(tester), 15);

    await tester.tap(find.text('10\u00A0min'));
    await tester.pumpAndSettle();

    final settingRows = store.entries
        .where((entry) => entry.kind == 'setting_changed')
        .toList();
    expect(settingRows, hasLength(1));
    expect(settingRows.single.settingKey, 'time_bag');
    expect(settingRows.single.settingValue, 10);
    expect(settingRows.single.itemId, isNull);
    expect(settingRows.single.stack, isNull);

    // The selection reads as the current value — the derived 10.
    expect(selectedMinutes(tester), 10);
    // No confirmation surfaced: the option texts are still exactly six
    // and nothing else appeared.
    expect(
      textsOf(tester).where((text) => text.contains('!')),
      isEmpty,
      reason: 'nothing celebration-shaped on a recorded change',
    );
    expect(find.byType(SnackBar), findsNothing);
  });

  testWidgets('a seeded bag selects its option — the derivation, not a '
      'stored selection (AD-1)', (tester) async {
    final store = _RecordingStore()
      ..entries.add((
        id: 'seed-setting',
        kind: 'setting_changed',
        instantUtcMicros: DateTime.utc(2026, 8, 29, 10).microsecondsSinceEpoch,
        offsetSeconds: 0,
        itemId: null,
        itemOrigin: null,
        stack: null,
        settingKey: 'time_bag',
        settingValue: 25,
        pocketMinutes: null,
        energyLevel: null,
        reportValue: null,
        reportWeek: null,
        permission: null,
      ));
    await launch(tester, store);

    await tester.tap(find.text(AppStringsEs().newProjectLink));
    await tester.pumpAndSettle();
    await tester.tap(find.text(AppStringsEs().settingsWayOut));
    await tester.pumpAndSettle();

    expect(selectedMinutes(tester), 25);
  });

  testWidgets('an out-of-range seeded row selects nothing new — the '
      'previous value or the default stands, silently (AD-23)', (tester) async {
    final store = _RecordingStore()
      ..entries.addAll([
        (
          id: 'seed-valid',
          kind: 'setting_changed',
          instantUtcMicros: DateTime.utc(
            2026,
            8,
            29,
            10,
          ).microsecondsSinceEpoch,
          offsetSeconds: 0,
          itemId: null,
          itemOrigin: null,
          stack: null,
          settingKey: 'time_bag',
          settingValue: 10,
          pocketMinutes: null,
          energyLevel: null,
          reportValue: null,
          reportWeek: null,
          permission: null,
        ),
        (
          id: 'seed-invalid',
          kind: 'setting_changed',
          instantUtcMicros: DateTime.utc(
            2026,
            8,
            29,
            11,
          ).microsecondsSinceEpoch,
          offsetSeconds: 0,
          itemId: null,
          itemOrigin: null,
          stack: null,
          settingKey: 'time_bag',
          settingValue: 45,
          pocketMinutes: null,
          energyLevel: null,
          reportValue: null,
          reportWeek: null,
          permission: null,
        ),
      ]);
    await launch(tester, store);

    await tester.tap(find.text(AppStringsEs().newProjectLink));
    await tester.pumpAndSettle();
    await tester.tap(find.text(AppStringsEs().settingsWayOut));
    await tester.pumpAndSettle();

    expect(selectedMinutes(tester), 10);
  });

  testWidgets('200% font scale: the options reflow in their wrap, the list '
      'scrolls, nothing truncates (UX-DR45, NFR6)', (tester) async {
    tester.platformDispatcher.textScaleFactorTestValue = 2.0;
    addTearDown(tester.platformDispatcher.clearAllTestValues);
    await tester.binding.setSurfaceSize(const ui.Size(320, 480));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final store = _RecordingStore();
    await launch(tester, store);

    await tester.tap(find.text(AppStringsEs().newProjectLink));
    await tester.pumpAndSettle();
    await tester.tap(find.text(AppStringsEs().settingsWayOut));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    for (final label in [
      '5\u00A0min',
      '10\u00A0min',
      '15\u00A0min',
      '20\u00A0min',
      '25\u00A0min',
      '30\u00A0min',
    ]) {
      expect(find.text(label), findsOneWidget);
    }
    final scrollable = tester.state<ScrollableState>(find.byType(Scrollable));
    // The grown list scrolls when it must — and every option stays a
    // whole, tappable target.
    await tester.scrollUntilVisible(
      find.text('30\u00A0min'),
      200,
      scrollable: find.byType(Scrollable),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('30\u00A0min'));
    await tester.pumpAndSettle();
    expect(find.text('30\u00A0min'), findsOneWidget);
    expect(tester.takeException(), isNull);
    expect(scrollable.position.maxScrollExtent, greaterThan(0));

    await tester.tap(find.text('30\u00A0min'));
    await tester.pumpAndSettle();
    expect(
      store.entries
          .where((entry) => entry.kind == 'setting_changed')
          .single
          .settingValue,
      30,
    );
    expect(selectedMinutes(tester), 30);
  });

  group('the review patches (2.1 review pass)', () {
    testWidgets('a late initial read cannot restore the pre-write selection', (
      tester,
    ) async {
      final store = _StaleFirstReadStore();
      final settings = SettingsController(store: store, nowOf: _fixedClock);
      await tester.pumpWidget(
        MaterialApp(
          theme: OrganizerTheme.light(),
          localizationsDelegates: AppStrings.localizationsDelegates,
          supportedLocales: AppStrings.supportedLocales,
          home: SettingsScreen(controller: settings),
        ),
      );
      await tester.pump();

      await tester.tap(find.text('10\u00A0min'));
      await tester.pumpAndSettle();
      expect(selectedMinutes(tester), 10);

      store.firstReadGate.complete();
      await tester.pumpAndSettle();

      expect(selectedMinutes(tester), 10);
    });

    testWidgets('an off-ladder derived value renders as its own selected '
        'chip, and a normal tap still writes (imported 17)', (tester) async {
      final store = _RecordingStore()
        ..entries.add((
          id: 'seed-off-ladder',
          kind: 'setting_changed',
          instantUtcMicros: DateTime.utc(
            2026,
            8,
            29,
            10,
          ).microsecondsSinceEpoch,
          offsetSeconds: 0,
          itemId: null,
          itemOrigin: null,
          stack: null,
          settingKey: 'time_bag',
          settingValue: 17,
          pocketMinutes: null,
          energyLevel: null,
          reportValue: null,
          reportWeek: null,
          permission: null,
        ));
      await launch(tester, store);
      await openSettings(tester);

      // The current value is visible: one extra chip carries 17, in the
      // same pill idiom, selected.
      expect(find.text('17\u00A0min'), findsOneWidget);
      expect(selectedMinutes(tester), 17);
      expect(
        find
            .ancestor(
              of: find.text('17\u00A0min'),
              matching: find.byType(Material),
            )
            .evaluate(),
        isNotEmpty,
      );

      // Tapping a ladder option still works: exactly one new row lands
      // beside the seed, and the selection — now on the ladder — drops
      // the extra chip.
      await tester.tap(find.text('10\u00A0min'));
      await tester.pumpAndSettle();
      final rows = store.entries
          .where((entry) => entry.kind == 'setting_changed')
          .toList();
      expect(rows, hasLength(2));
      expect(rows.first.settingValue, 17, reason: 'the seed stays first');
      expect(rows.last.settingValue, 10, reason: 'exactly one appended');
      expect(selectedMinutes(tester), 10);
      expect(find.text('17\u00A0min'), findsNothing);
    });

    testWidgets('a rapid double tap on the footer stacks one route, not '
        'two — the transition guard holds', (tester) async {
      final store = _RecordingStore();
      await launch(tester, store);

      await tester.tap(find.text(AppStringsEs().newProjectLink));
      // The second tap lands while the first route is still transitioning
      // in — the same frame, before any pump can advance it.
      await tester.tap(find.text(AppStringsEs().newProjectLink));
      await tester.pumpAndSettle();

      expect(
        find.byType(NuevoProyectoScreen, skipOffstage: false),
        findsOneWidget,
        reason:
            'a second push during the transition would stack a '
            'second carrier route',
      );
    });

    testWidgets('a rapid double tap on the way-out stacks one Settings '
        'route, not two — the same guard on the carrier', (tester) async {
      final store = _RecordingStore();
      await launch(tester, store);

      await tester.tap(find.text(AppStringsEs().newProjectLink));
      await tester.pumpAndSettle();
      await tester.tap(find.text(AppStringsEs().settingsWayOut));
      await tester.tap(find.text(AppStringsEs().settingsWayOut));
      await tester.pumpAndSettle();

      expect(
        find.byType(SettingsScreen, skipOffstage: false),
        findsOneWidget,
        reason:
            'a second push during the transition would stack a '
            'second Settings route',
      );
      // One pop still returns to the carrier, not to a stacked twin.
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.byType(SettingsScreen), findsNothing);
      expect(find.text(AppStringsEs().settingsWayOut), findsOneWidget);
    });

    testWidgets('re-tapping the current value appends nothing — no '
        'redundant setting_changed row', (tester) async {
      final store = _RecordingStore();
      await launch(tester, store);
      await openSettings(tester);
      await tester.pumpAndSettle();

      // The default derivation: 15.
      expect(selectedMinutes(tester), 15);

      await tester.tap(find.text('15\u00A0min'));
      await tester.pumpAndSettle();
      expect(
        store.entries.where((entry) => entry.kind == 'setting_changed'),
        isEmpty,
        reason: 'choosing what is already in force writes nothing',
      );
      expect(selectedMinutes(tester), 15);

      // A real change after the no-op still lands.
      await tester.tap(find.text('25\u00A0min'));
      await tester.pumpAndSettle();
      expect(
        store.entries
            .where((entry) => entry.kind == 'setting_changed')
            .single
            .settingValue,
        25,
      );
    });

    testWidgets('the null-controller chain: the footer opens the carrier '
        'with no settings, its way-out opens a controller-less Settings, '
        'and a write goes nowhere (the documented test seam)', (tester) async {
      final store = _RecordingStore();
      await tester.pumpWidget(harnessFor(store, null));
      await tester.pumpAndSettle();

      await tester.tap(find.text(AppStringsEs().newProjectLink));
      await tester.pumpAndSettle();
      expect(find.byType(NuevoProyectoScreen), findsOneWidget);

      await tester.tap(find.text(AppStringsEs().settingsWayOut));
      await tester.pumpAndSettle();
      expect(find.byType(SettingsScreen), findsOneWidget);

      // The surface renders the group and the options, nothing selected,
      // and a tap writes nowhere.
      expect(find.text(AppStringsEs().settingsGroupYourDay), findsOneWidget);
      expect(find.text(AppStringsEs().settingsTimeBag), findsOneWidget);
      expect(selectedMinutes(tester), isNull);
      await tester.tap(find.text('10\u00A0min'));
      await tester.pumpAndSettle();
      expect(store.entries, isEmpty);
      expect(selectedMinutes(tester), isNull);
      expect(find.byType(ErrorWidget), findsNothing);
    });

    testWidgets('two rapid option taps land exactly two setting_changed '
        'rows in tap order — the serialized write chain (Story 2.1)', (
      tester,
    ) async {
      final store = _RecordingStore();
      await launch(tester, store);
      await openSettings(tester);

      await tester.tap(find.text('20\u00A0min'));
      // No settle between: the second write queues behind the first.
      await tester.tap(find.text('25\u00A0min'));
      await tester.pumpAndSettle();

      final rows = store.entries
          .where((entry) => entry.kind == 'setting_changed')
          .toList();
      expect(rows, hasLength(2));
      expect(rows.map((row) => row.settingValue).toList(), [20, 25]);
      expect(selectedMinutes(tester), 25);
    });

    testWidgets('a failed first append is quiet and the chain recovers: '
        'the retry lands exactly one row and a later read completes '
        '(the catchError chain-clearing is load-bearing)', (tester) async {
      final inner = _RecordingStore();
      final store = _FailFirstSettingAppendStore(inner);
      final settings = SettingsController(store: store, nowOf: _fixedClock);
      await tester.pumpWidget(harness(inner, settings: settings));
      await tester.pumpAndSettle();
      await openSettings(tester);
      expect(selectedMinutes(tester), 15);

      // Tap A fails quietly: nothing landed, the selection stands.
      await tester.tap(find.text('10\u00A0min'));
      await tester.pumpAndSettle();
      expect(inner.entries, isEmpty);
      expect(selectedMinutes(tester), 15);
      expect(find.byType(ErrorWidget), findsNothing);

      // Tap B succeeds on the recovered chain: exactly one row, the
      // selection lands on B, and the read path still completes. With
      // the chain-clearing catchError removed, this write never runs and
      // the assertions below fail.
      await tester.tap(find.text('25\u00A0min'));
      await tester.pumpAndSettle();
      final rows = inner.entries
          .where((entry) => entry.kind == 'setting_changed')
          .toList();
      expect(rows, hasLength(1));
      expect(rows.single.settingValue, 25);
      expect(selectedMinutes(tester), 25);
      expect(await settings.readTimeBag(), 25);
    });
  });

  group('the validator surface\'s dictation facts (Story 3.4, FR-32, '
      'AD-26)', () {
    PoolFactRecord fact(String id, {bool? dictated}) => (
      id: id,
      origin: Origin.manual,
      size: Size.maintenance,
      instantUtcMicros: 100,
      offsetSeconds: 0,
      originContext: 'llamar al dentista',
      dictated: dictated,
    );

    testWidgets('the dictated-count line counts the pool\'s dictated '
        'captures — the one place the boolean is readable, plural and '
        'singular both fixed sentences', (tester) async {
      final store = _RecordingStore();
      store.facts.addAll([
        fact('spoken-a', dictated: true),
        fact('spoken-b', dictated: true),
        fact('typed', dictated: false),
        fact('old-row'),
      ]);
      await launch(tester, store);
      await openSettings(tester);
      await tester.pumpAndSettle();

      expect(
        find.text(AppStringsEs().settingsDictatedCount(2)),
        findsOneWidget,
      );

      // The singular is its own fixed sentence: one dictated capture.
      await tester.pumpWidget(const SizedBox.shrink());
      final single = _RecordingStore();
      single.facts.add(fact('only', dictated: true));
      await launch(tester, single);
      await openSettings(tester);
      await tester.pumpAndSettle();
      expect(
        find.text(AppStringsEs().settingsDictatedCount(1)),
        findsOneWidget,
      );
    });

    testWidgets('the IA y voz row renders only while refused ∧ not '
        'granted — the tap opens the system app-details screen, and a '
        're-grant retires the row by itself', (tester) async {
      LogEntryRecord refusal(String id) => (
        id: id,
        kind: LogKind.permissionRefused.name,
        instantUtcMicros: 100,
        offsetSeconds: 0,
        itemId: null,
        itemOrigin: null,
        stack: null,
        settingKey: null,
        settingValue: null,
        pocketMinutes: null,
        energyLevel: null,
        reportValue: null,
        reportWeek: null,
        permission: 'microphone',
      );

      // Not refused: the row is absent whatever the probe says.
      final clean = _RecordingStore();
      final cleanRecognizer = _FakeRecognizer(RecognizerAvailability.askable);
      await tester.pumpWidget(
        harnessFor(
          clean,
          SettingsController(
            store: clean,
            recognizer: cleanRecognizer,
            nowOf: _fixedClock,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await openSettings(tester);
      await tester.pumpAndSettle();
      expect(find.text(AppStringsEs().settingsAiVoice), findsNothing);

      // Refused and not granted: the row renders, and its one tap
      // opens the system screen.
      await tester.pumpWidget(const SizedBox.shrink());
      final refused = _RecordingStore();
      refused.entries.add(refusal('refused-row'));
      final refusedRecognizer = _FakeRecognizer(RecognizerAvailability.askable);
      await tester.pumpWidget(
        harnessFor(
          refused,
          SettingsController(
            store: refused,
            recognizer: refusedRecognizer,
            nowOf: _fixedClock,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await openSettings(tester);
      await tester.pumpAndSettle();
      final row = find.text(AppStringsEs().settingsAiVoice);
      expect(row, findsOneWidget);
      expect(
        tester
            .widget<Semantics>(
              find.ancestor(of: row, matching: find.byType(Semantics)).first,
            )
            .properties
            .button,
        isTrue,
        reason: 'the row reaches readers as a button',
      );
      await tester.ensureVisible(row);
      await tester.pumpAndSettle();
      await tester.tap(row);
      await tester.pumpAndSettle();
      expect(refusedRecognizer.openAppSettingsCalls, 1);
      expect(find.byType(ErrorWidget), findsNothing);

      // Refused but re-granted at the system level: nothing to
      // reactivate — the row retires through the probe alone.
      await tester.pumpWidget(const SizedBox.shrink());
      final regranted = _RecordingStore();
      regranted.entries.add(refusal('refused-row'));
      final grantedRecognizer = _FakeRecognizer(RecognizerAvailability.granted);
      await tester.pumpWidget(
        harnessFor(
          regranted,
          SettingsController(
            store: regranted,
            recognizer: grantedRecognizer,
            nowOf: _fixedClock,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await openSettings(tester);
      await tester.pumpAndSettle();
      expect(find.text(AppStringsEs().settingsAiVoice), findsNothing);

      // Refused, not granted, but recognition itself unavailable: the
      // probe cannot speak "not granted" there, and there is nothing
      // to reactivate into while recognition cannot run — the row
      // stays hidden, returning with availability.
      await tester.pumpWidget(const SizedBox.shrink());
      final noModel = _RecordingStore();
      noModel.entries.add(refusal('refused-row'));
      final unavailableRecognizer = _FakeRecognizer(
        RecognizerAvailability.unavailable,
      );
      await tester.pumpWidget(
        harnessFor(
          noModel,
          SettingsController(
            store: noModel,
            recognizer: unavailableRecognizer,
            nowOf: _fixedClock,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await openSettings(tester);
      await tester.pumpAndSettle();
      expect(find.text(AppStringsEs().settingsAiVoice), findsNothing);
    });

    testWidgets('a return from the foreground re-reads the dictation '
        'facts: a re-grant made in system settings retires the row '
        'without leaving the surface (Story 3.4)', (tester) async {
      LogEntryRecord refusal(String id) => (
        id: id,
        kind: LogKind.permissionRefused.name,
        instantUtcMicros: 100,
        offsetSeconds: 0,
        itemId: null,
        itemOrigin: null,
        stack: null,
        settingKey: null,
        settingValue: null,
        pocketMinutes: null,
        energyLevel: null,
        reportValue: null,
        reportWeek: null,
        permission: 'microphone',
      );

      // The row stands: refused and not granted.
      final store = _RecordingStore();
      store.entries.add(refusal('refused-row'));
      final recognizer = _FakeRecognizer(RecognizerAvailability.askable);
      await tester.pumpWidget(
        harnessFor(
          store,
          SettingsController(
            store: store,
            recognizer: recognizer,
            nowOf: _fixedClock,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await openSettings(tester);
      await tester.pumpAndSettle();
      expect(find.text(AppStringsEs().settingsAiVoice), findsOneWidget);

      // The user leaves for the system's app-details screen and
      // re-grants; the return to the foreground re-derives the
      // premise and the row retires in place.
      recognizer.availability = RecognizerAvailability.granted;
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(find.text(AppStringsEs().settingsAiVoice), findsNothing);
      expect(find.byType(ErrorWidget), findsNothing);
    });
  });
}

/// The minutes of the option whose Material carries the selected fill
/// (accent-soft), or null when none is selected yet. The selected fill
/// is the theme's primary pair — the size-option idiom. The option's
/// own Material is the nearest ancestor of its label. The candidate
/// minutes come from core's [timeBagOptions] — a ladder change cannot
/// desync the helper — plus any off-ladder chip the derivation rendered.
int? selectedMinutes(WidgetTester tester) {
  final candidates = <int>{...timeBagOptions};
  final optionLabel = RegExp(r'^(\d+)\u00A0min$');
  for (final text in tester.widgetList<Text>(find.byType(Text))) {
    final match = optionLabel.firstMatch(text.data ?? '');
    if (match != null) {
      candidates.add(int.parse(match.group(1)!));
    }
  }
  for (final minutes in candidates) {
    final text = find.text('$minutes\u00A0min');
    if (text.evaluate().isEmpty) {
      continue;
    }
    final material = find
        .ancestor(of: text, matching: find.byType(Material))
        .first;
    final color = tester.widget<Material>(material).color;
    if (color == OrganizerTheme.light().colorScheme.primary) {
      return minutes;
    }
  }
  return null;
}

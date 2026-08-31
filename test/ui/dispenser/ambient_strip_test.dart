// The ambient strip's contract (Story 2.5, FR-4, UX-DR20/22): the
// check-in resident renders below the card at the day's first opening —
// the question verbatim, three battery marks as direct tap targets with
// llena pre-marked, the ✕ dismissal — a tap on any mark lands exactly
// one `energy_set` row, clears the strip for the day and (on baja)
// narrows the next deal to instant-tier while the standing card stays
// finishable; the ✕ writes nothing and hides the strip for the rest of
// the opening; at 200% the strip grows and scrolls with every target
// at or above 48dp.
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:core/pool/pool_fact.dart';
import 'package:core/weave/weave.dart';
import 'package:core/ports/store_port.dart';
import 'package:flutter/material.dart' hide Card;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:organizer/catalogue/catalogue_names.g.dart';
import 'package:organizer/catalogue/loader.dart';
import 'package:organizer/dispenser/dispenser_controller.dart';
import 'package:organizer/session/session_controller.dart';
import 'package:organizer/strings/app_strings.dart';
import 'package:organizer/strings/app_strings_es.dart';
import 'package:organizer/ui/dispenser/ambient_strip.dart';
import 'package:organizer/ui/dispenser/dispenser_screen.dart';
import 'package:organizer/ui/dispenser/task_card.dart';
import 'package:organizer/ui/glyphs/battery_glyph.dart';
import 'package:organizer/ui/theme.dart';

/// The recording store (the session suite's own contract): appends land
/// in order and every read replays them.
class _RecordingStore implements StorePort {
  final List<LogEntryRecord> entries = [];
  var failNextAppend = false;

  @override
  Future<void> appendPoolFact(PoolFactRecord fact) async {}

  @override
  Future<void> appendLogEntry(LogEntryRecord entry) async {
    if (failNextAppend) {
      failNextAppend = false;
      throw StateError('planned append failure');
    }
    entries.add(entry);
  }

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

DateTime _fixedClock() => DateTime.utc(2026, 8, 29, 12);

/// A dealt card for the queued-read fakes (the screen suite's own
/// `_testCard` shape).
const _testCard = Card(
  id: 'test-card',
  size: Size.instant,
  name: 'Tarea de prueba',
  origin: Origin.shipped,
  zone: null,
  estimateSeconds: 30,
);

/// A controller whose reads resolve only when the test completes them —
/// the screen suite's queued-read pattern, so a stale read's late
/// commit is observable.
class _QueuedReadController extends DispenserController {
  _QueuedReadController(this._reads)
    : super(store: _RecordingStore(), strings: AppStringsEs());

  final List<Completer<DispenserView>> _reads;
  var _nextRead = 0;

  @override
  Future<DispenserView> read() => _reads[_nextRead++].future;
}

/// The queued-read shape with a controllable dismissal: the ✕'s own
/// path resolves when the test says so.
class _QueuedDismissController extends _QueuedReadController {
  _QueuedDismissController(super._reads);

  final dismissal = Completer<DispenserView>();

  @override
  Future<DispenserView> dismissCheckIn({DateTime? tapTime}) => dismissal.future;
}

Widget _harness(
  DispenserController controller, {
  Future<void> Function()? sessionSettled,
}) => MaterialApp(
  theme: OrganizerTheme.light(),
  localizationsDelegates: AppStrings.localizationsDelegates,
  supportedLocales: AppStrings.supportedLocales,
  home: DispenserScreen(controller: controller, sessionSettled: sessionSettled),
);

void main() {
  final shipped = File(catalogueAssetPath).readAsStringSync();

  _FakeBundle bundle() => _FakeBundle({catalogueAssetPath: shipped});

  /// The launch shape the screen suite uses: the lifecycle's open runs
  /// unawaited while the screen's first read waits on its `settled`
  /// chain, so the committed frame is always the post-session read —
  /// the dealt card with the strip below it, never the pre-session
  /// close.
  Future<DispenserController> launchAndCommit(WidgetTester tester) async {
    final store = _RecordingStore();
    final session = SessionController(
      store: store,
      strings: AppStringsEs(),
      bundle: bundle(),
      nowOf: _fixedClock,
    );
    final controller = DispenserController(
      store: store,
      strings: AppStringsEs(),
      bundle: bundle(),
      nowOf: _fixedClock,
    );
    final opening = session.handleAppOpen();
    await tester.pumpWidget(
      _harness(controller, sessionSettled: () => session.settled),
    );
    await opening;
    await tester.pumpAndSettle();
    return controller;
  }

  _RecordingStore storeOf(DispenserController controller) {
    final store = controller.store;
    return store as _RecordingStore;
  }

  testWidgets('the day\'s first opening shows the check-in below the '
      'card: the question verbatim, three battery marks with llena '
      'pre-marked, the ✕ — and nothing else (UX-DR20/22, FR-4)', (
    tester,
  ) async {
    final controller = await launchAndCommit(tester);

    expect(
      find.byType(TaskCard),
      findsOneWidget,
      reason:
          'the settled launch frame is the dealt card, and the '
          'strip rides below it',
    );
    expect(find.text('¿Cuánta energía tienes hoy?'), findsOneWidget);
    expect(find.byType(AmbientStrip), findsOneWidget);
    expect(find.byType(BatteryGlyph), findsNWidgets(3));
    // Below the card, geometrically: the strip's top-left sits strictly
    // under the card's.
    expect(
      tester.getTopLeft(find.byType(AmbientStrip)).dy,
      greaterThan(tester.getTopLeft(find.byType(TaskCard)).dy),
    );

    // The three marks declare themselves as buttons carrying selection
    // state and their own labels (the ladder-pill precedent): llena is
    // the standing default; media and baja are neutral.
    final full = find.bySemanticsLabel('Llena');
    final medium = find.bySemanticsLabel('Media');
    final low = find.bySemanticsLabel('Baja');
    expect(full, findsOneWidget);
    expect(medium, findsOneWidget);
    expect(low, findsOneWidget);
    expect(
      tester.widget<Semantics>(full).properties.selected,
      isTrue,
      reason: 'llena is pre-marked as the standing default',
    );
    expect(tester.widget<Semantics>(medium).properties.selected, isFalse);
    expect(tester.widget<Semantics>(low).properties.selected, isFalse);

    // The ✕ dismissal carries its own label and writes nothing.
    expect(find.bySemanticsLabel('Cerrar'), findsOneWidget);
    expect(
      storeOf(controller).entries.map((entry) => entry.kind),
      isNot(contains('energy_set')),
    );
  });

  testWidgets('a baja tap lands exactly one energy_set row, clears the '
      'strip for the day, keeps the standing card finishable, and the '
      'next deal is instant-tier only (FR-4)', (tester) async {
    final controller = await launchAndCommit(tester);
    final store = storeOf(controller);
    final catalogue = await loadEvergreenCatalogue(
      AppStringsEs(),
      bundle: bundle(),
    );
    final standingId = store.entries
        .lastWhere((entry) => entry.kind == 'card_dealt')
        .itemId!;
    final standingName = catalogue.entries
        .firstWhere((entry) => entry.id == standingId)
        .name;
    final standingCard = find.text(standingName);

    await tester.ensureVisible(find.bySemanticsLabel('Baja'));
    await tester.pumpAndSettle();
    await tester.tap(find.bySemanticsLabel('Baja'));
    await tester.pumpAndSettle();

    final rows = store.entries
        .where((entry) => entry.kind == 'energy_set')
        .toList();
    expect(rows, hasLength(1));
    expect(rows.single.energyLevel, 2);
    expect(rows.single.itemId, isNull);

    // The strip is gone for the day; the card stands finishable.
    expect(find.text('¿Cuánta energía tienes hoy?'), findsNothing);
    expect(find.byType(BatteryGlyph), findsNothing);
    expect(standingCard, findsOneWidget);
    expect(find.text('Hecho'), findsOneWidget);

    // The narrower deal is the display: the completion bundles an
    // instant-tier card, never a second chunk.
    await tester.tap(find.text('Hecho'));
    await tester.pumpAndSettle();
    final nextDealRow = store.entries.lastWhere(
      (entry) => entry.kind == 'card_dealt',
    );
    final nextSize = catalogue.entries
        .firstWhere((entry) => entry.id == nextDealRow.itemId)
        .size;
    expect(nextSize, Size.instant);
  });

  testWidgets('llena and media write their own levels without narrowing '
      'the next deal', (tester) async {
    for (final (label, wire) in [('Llena', 0), ('Media', 1)]) {
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
      final controller = await launchAndCommit(tester);
      final store = storeOf(controller);
      final catalogue = await loadEvergreenCatalogue(
        AppStringsEs(),
        bundle: bundle(),
      );

      await tester.ensureVisible(find.bySemanticsLabel(label));
      await tester.tap(find.bySemanticsLabel(label));
      await tester.pumpAndSettle();

      expect(store.entries.last.kind, 'energy_set');
      expect(store.entries.last.energyLevel, wire);
      await tester.tap(find.text('Hecho'));
      await tester.pumpAndSettle();
      final nextDeal = store.entries.lastWhere(
        (entry) => entry.kind == 'card_dealt',
      );
      expect(
        catalogue.entries
            .firstWhere((entry) => entry.id == nextDeal.itemId)
            .size,
        isNot(Size.instant),
      );
    }
  });

  testWidgets('a failed energy append restores the standing card and '
      'check-in', (tester) async {
    final controller = await launchAndCommit(tester);
    final store = storeOf(controller)..failNextAppend = true;

    await tester.ensureVisible(find.bySemanticsLabel('Baja'));
    await tester.tap(find.bySemanticsLabel('Baja'));
    await tester.pumpAndSettle();

    expect(store.entries.where((entry) => entry.kind == 'energy_set'), isEmpty);
    expect(find.text('¿Cuánta energía tienes hoy?'), findsOneWidget);
    expect(find.byType(TaskCard), findsOneWidget);
  });

  testWidgets('the ✕ dismissal writes nothing and hides the strip for '
      'the rest of the opening (UX-DR22, FR-4)', (tester) async {
    final controller = await launchAndCommit(tester);
    final store = storeOf(controller);
    final kindsBefore = store.entries.map((entry) => entry.kind).toList();

    await tester.ensureVisible(find.bySemanticsLabel('Cerrar'));
    await tester.pumpAndSettle();
    await tester.tap(find.bySemanticsLabel('Cerrar'));
    await tester.pumpAndSettle();

    expect(
      store.entries.map((entry) => entry.kind).toList(),
      kindsBefore,
      reason: 'a dismissal appends nothing at all',
    );
    expect(find.text('¿Cuánta energía tienes hoy?'), findsNothing);
    expect(find.byType(BatteryGlyph), findsNothing);
    expect(
      find.text('Hecho'),
      findsOneWidget,
      reason: 'the card surface is untouched by the dismissal',
    );
  });

  testWidgets('a pending dismissal blocks a stale battery tap', (tester) async {
    final controller = await launchAndCommit(tester);
    final store = storeOf(controller);
    final settlement = Completer<void>();
    var settleActions = false;

    await tester.pumpWidget(
      _harness(
        controller,
        sessionSettled: () =>
            settleActions ? settlement.future : Future<void>.value(),
      ),
    );
    await tester.pumpAndSettle();
    settleActions = true;

    await tester.ensureVisible(find.bySemanticsLabel('Cerrar'));
    await tester.tap(find.bySemanticsLabel('Cerrar'));
    await tester.pump();
    await tester.ensureVisible(find.bySemanticsLabel('Baja'));
    await tester.tap(find.bySemanticsLabel('Baja'));
    await tester.pump();
    settlement.complete();
    await tester.pumpAndSettle();

    expect(store.entries.where((entry) => entry.kind == 'energy_set'), isEmpty);
    expect(find.text('¿Cuánta energía tienes hoy?'), findsNothing);
  });

  testWidgets('an answered day re-renders nothing on a later same-day '
      'opening — never re-shown, never styled as anything owed', (
    tester,
  ) async {
    final controller = await launchAndCommit(tester);
    final store = storeOf(controller);

    await tester.ensureVisible(find.bySemanticsLabel('Media'));
    await tester.pumpAndSettle();
    await tester.tap(find.bySemanticsLabel('Media'));
    await tester.pumpAndSettle();
    expect(find.text('¿Cuánta energía tienes hoy?'), findsNothing);

    // A later opening in the same day: the derivation hides it on its
    // own — no strip, no pending styling, nothing owed.
    final session = SessionController(
      store: store,
      strings: AppStringsEs(),
      bundle: bundle(),
      nowOf: _fixedClock,
    );
    await session.handleSessionEnd();
    await session.handleAppOpen();
    await controller.read();
    await tester.pumpWidget(_harness(controller));
    await tester.pumpAndSettle();
    expect(find.text('¿Cuánta energía tienes hoy?'), findsNothing);
    expect(find.byType(BatteryGlyph), findsNothing);
  });

  testWidgets('the strip also renders below the permission-to-rest '
      'offer — the offer and the check-in coexist, offer above '
      '(Story 2.5 beside 2.4, UX-DR22)', (tester) async {
    final store = _RecordingStore()
      ..entries.add((
        id: 'seed-offer',
        kind: 'session_started',
        instantUtcMicros: DateTime.utc(
          2026,
          8,
          29,
          11,
          20,
        ).microsecondsSinceEpoch,
        offsetSeconds: 0,
        itemId: null,
        itemOrigin: null,
        stack: null,
        settingKey: null,
        settingValue: null,
        pocketMinutes: 45,
        energyLevel: null,
        reportValue: null,
        reportWeek: null,
      ));
    final controller = DispenserController(
      store: store,
      strings: AppStringsEs(),
      bundle: bundle(),
      nowOf: _fixedClock,
    );
    await tester.pumpWidget(_harness(controller));
    await tester.pumpAndSettle();

    // The offer is the content arm and the strip rides below it.
    expect(find.text('Nada más por el momento'), findsOneWidget);
    expect(find.text('Quiero seguir'), findsOneWidget);
    expect(find.text('¿Cuánta energía tienes hoy?'), findsOneWidget);
    expect(find.byType(BatteryGlyph), findsNWidgets(3));
    expect(
      tester.getTopLeft(find.byType(AmbientStrip)).dy,
      greaterThan(tester.getTopLeft(find.text('Nada más por el momento')).dy),
      reason:
          'the strip sits below whatever the read committed — the '
          'offer included',
    );
  });

  testWidgets('a stale read in flight when the ✕ lands cannot resurrect '
      'the strip — the dismissal\'s generation bump holds', (tester) async {
    final first = Completer<DispenserView>();
    final second = Completer<DispenserView>();
    final controller = _QueuedDismissController([first, second]);

    await tester.pumpWidget(_harness(controller));
    await tester.pump();
    // A foreground return queues a second read (the newer generation);
    // the launch read stays hanging as the stale one.
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();

    second.complete(const DispenserDealt(_testCard, checkInShown: true));
    await tester.pumpAndSettle();
    expect(find.text('¿Cuánta energía tienes hoy?'), findsOneWidget);

    // The ✕: its handler bumps the generation and resolves through the
    // controllable dismissal.
    await tester.ensureVisible(find.bySemanticsLabel('Cerrar'));
    await tester.pumpAndSettle();
    await tester.tap(find.bySemanticsLabel('Cerrar'));
    await tester.pump();
    controller.dismissal.complete(const DispenserDealt(_testCard));
    await tester.pumpAndSettle();
    expect(find.text('¿Cuánta energía tienes hoy?'), findsNothing);

    // The stale launch read completes last, carrying the strip — its
    // generation no longer matches, so it must not commit.
    first.complete(const DispenserDealt(_testCard, checkInShown: true));
    await tester.pumpAndSettle();
    expect(
      find.text('¿Cuánta energía tienes hoy?'),
      findsNothing,
      reason:
          'a read from before the dismissal cannot resurrect the '
          'strip — the generation bump refuses its commit',
    );
    expect(find.byType(TaskCard), findsOneWidget);
  });

  testWidgets('200% font scale: the strip grows and scrolls, nothing '
      'truncates, and every target holds 48dp (UX-DR45, NFR6)', (tester) async {
    tester.platformDispatcher.textScaleFactorTestValue = 2.0;
    addTearDown(tester.platformDispatcher.clearAllTestValues);
    await tester.binding.setSurfaceSize(const ui.Size(320, 480));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await launchAndCommit(tester);

    expect(tester.takeException(), isNull);
    expect(find.text('¿Cuánta energía tienes hoy?'), findsOneWidget);
    expect(find.byType(BatteryGlyph), findsNWidgets(3));

    // Every tap target keeps the 48dp floor: the three battery marks
    // and the ✕ measure through their opaque gesture detectors.
    final glyphTargets = [
      for (final mark in find.byType(BatteryGlyph).evaluate())
        find
            .ancestor(
              of: find.byWidget(mark.widget),
              matching: find.byType(GestureDetector),
            )
            .first,
    ];
    for (final target in glyphTargets) {
      final box = tester.renderObject<RenderBox>(target);
      expect(box.size.width, greaterThanOrEqualTo(48));
      expect(box.size.height, greaterThanOrEqualTo(48));
    }
    final dismissTarget = find.descendant(
      of: find.bySemanticsLabel('Cerrar'),
      matching: find.byType(GestureDetector),
    );
    final dismissBox = tester.renderObject<RenderBox>(dismissTarget);
    expect(dismissBox.size.width, greaterThanOrEqualTo(48));
    expect(dismissBox.size.height, greaterThanOrEqualTo(48));

    // The strip joins the card's scroll region: the grown content
    // really scrolls, nothing clips.
    final scrollable = tester.state<ScrollableState>(find.byType(Scrollable));
    await tester.drag(find.byType(SingleChildScrollView), const Offset(0, -60));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(scrollable.position.pixels, greaterThan(0));
    expect(find.text('¿Cuánta energía tienes hoy?'), findsOneWidget);
  });
}

// The ambient strip's contract (Stories 2.5–2.6, FR-4, UX-DR20/22):
// the check-in resident renders below the card at the day's first
// opening — the question verbatim, three battery marks as direct tap
// targets with llena pre-marked, the ✕ dismissal — a tap on any mark
// lands exactly one `energy_set` row, clears the strip for the day and
// (on baja) narrows the next deal to instant-tier while the standing
// card stays finishable; the ✕ writes nothing and hides the strip for
// the rest of the opening; at 200% the strip grows and scrolls with
// every target at or above 48dp. Story 2.6 adds the weekly
// self-report's resident beside it — hairlined, the question verbatim,
// the 1–5 numerals as 48dp tap targets, the end labels, the ✕ — and
// pins the deterministic handoff: a digit tap or the ✕ hands the slot
// to the check-in in the same opening, and a dismissal hides the
// report for that opening alone, never for the week.
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:core/derive/strip.dart';
import 'package:core/pool/pool_fact.dart';
import 'package:core/weave/weave.dart';
import 'package:core/ports/store_port.dart';
import 'package:flutter/material.dart' hide Card;
import 'package:flutter/semantics.dart';
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
import 'package:organizer/ui/settings/curation_screen.dart';
import 'package:organizer/ui/theme.dart';
import 'package:organizer/ui/tokens.dart';

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

/// A facts-carrying recording store (the seasonal group's own): the
/// recording contract over a seeded pool-fact snapshot, so a dormant
/// Epic stands in the pool before any launch.
class _FactsRecordingStore implements StorePort {
  _FactsRecordingStore(this.facts);

  final List<PoolFactRecord> facts;
  final List<LogEntryRecord> entries = [];

  @override
  Future<void> appendPoolFact(PoolFactRecord fact) async {}

  @override
  Future<void> appendLogEntry(LogEntryRecord entry) async => entries.add(entry);

  @override
  Future<List<PoolFactRecord>> readPoolFacts() async =>
      List.unmodifiable(facts);

  @override
  Future<List<LogEntryRecord>> readLogEntries() async =>
      List.unmodifiable(entries);
}

/// A store whose reads throw only while armed — the launch read
/// commits, then a later arm runs over a failing read (the screen
/// suite's `_FailReadAfterDoneStore` grammar, the arm manual).
class _FailReadWhileArmedStore implements StorePort {
  _FailReadWhileArmedStore(this._inner);

  final _RecordingStore _inner;
  var failReads = false;

  @override
  Future<void> appendPoolFact(PoolFactRecord fact) async {}

  @override
  Future<void> appendLogEntry(LogEntryRecord entry) =>
      _inner.appendLogEntry(entry);

  @override
  Future<List<PoolFactRecord>> readPoolFacts() => _inner.readPoolFacts();

  @override
  Future<List<LogEntryRecord>> readLogEntries() async {
    if (failReads) {
      throw StateError('read failed');
    }
    return _inner.readLogEntries();
  }
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

/// Whether [ancestor] is [node] itself or one of its ancestors —
/// the bound for a semantics walk that stops at the least ancestor
/// two nodes share.
bool _encloses(SemanticsNode ancestor, SemanticsNode node) {
  for (SemanticsNode? walk = node; walk != null; walk = walk.parent) {
    if (identical(walk, ancestor)) {
      return true;
    }
  }
  return false;
}

/// An install-day `app_opened` — a row from the day before the fixed
/// Saturday clock, seeding an ESTABLISHED install (the 5.12
/// translation the 2.5/2.6 groups take): with an opening on any
/// earlier day in the log, the once-ever first-run curation offer is
/// not eligible, so the check-in and report residents keep rendering
/// exactly as they shipped — the controller suite's `_installOpen`
/// precedent. 20:00 keeps it inside 48 h of every later read, so the
/// warm-return greeting stays out of the pins.
LogEntryRecord _installOpen() => (
  id: 'install-open',
  kind: 'app_opened',
  instantUtcMicros: DateTime.utc(2026, 8, 28, 20).microsecondsSinceEpoch,
  offsetSeconds: 0,
  itemId: null,
  itemOrigin: null,
  stack: null,
  settingKey: null,
  settingValue: null,
  settingTextValue: null,
  pocketMinutes: null,
  energyLevel: null,
  reportValue: null,
  reportWeek: null,
  permission: null,
  sliceCause: null,
  cluster: null,
  enabled: null,
  triageDestination: null,
  triageVolumeTag: null,
  triageBoxId: null,
  beforeName: null,
  afterName: null,
);

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

/// The queued-read shape with a controllable report dismissal: the
/// report ✕'s own path resolves when the test says so.
class _QueuedDismissReportController extends _QueuedReadController {
  _QueuedDismissReportController(super._reads);

  final dismissal = Completer<DispenserView>();

  @override
  Future<DispenserView> dismissReport({DateTime? tapTime}) => dismissal.future;
}

/// The queued-read shape with a controllable report answer: a digit
/// tap's own path resolves when the test says so.
class _QueuedAnswerReportController extends _QueuedReadController {
  _QueuedAnswerReportController(super._reads);

  final answer = Completer<DispenserView>();

  @override
  Future<DispenserView> answerReport(int value, {DateTime? tappedAt}) =>
      answer.future;
}

/// The queued-read shape with a controllable quarantine-follow-up
/// dismissal: the follow-up ✕'s own path resolves when the test says
/// so.
class _QueuedDismissQuarantineFollowUpController extends _QueuedReadController {
  _QueuedDismissQuarantineFollowUpController(super._reads);

  final dismissal = Completer<DispenserView>();

  @override
  Future<DispenserView> dismissQuarantineFollowUp({DateTime? tapTime}) =>
      dismissal.future;
}

/// A report surface that records the instants the screen hands to its two
/// actions. The lifecycle gate can then cross 04:00 without changing either
/// tap's identity.
class _CapturingReportActionController extends DispenserController {
  _CapturingReportActionController(DateTime Function() nowOf)
    : super(store: _RecordingStore(), strings: AppStringsEs(), nowOf: nowOf);

  DateTime? answeredAt;
  DateTime? dismissedAt;

  @override
  Future<DispenserView> read() async => const DispenserDealt(
    _testCard,
    stripResident: StripResident.weeklySelfReport,
    reportWeekOrdinal: 1390,
  );

  @override
  Future<DispenserView> answerReport(int value, {DateTime? tappedAt}) async {
    answeredAt = tappedAt;
    return const DispenserDealt(_testCard);
  }

  @override
  Future<DispenserView> dismissReport({DateTime? tapTime}) async {
    dismissedAt = tapTime;
    return const DispenserDealt(_testCard);
  }
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
  /// close. The store seeds week 1389's report answered — the week a
  /// Saturday read judges due — so the check-in's own suite pins the
  /// check-in exactly as 2.5 shipped it, the mechanical translation
  /// part 3 records.
  Future<DispenserController> launchAndCommit(WidgetTester tester) async {
    final store = _RecordingStore()
      ..entries.add(_installOpen())
      ..entries.add((
        id: 'seed-week-answered',
        kind: 'report_answered',
        instantUtcMicros: DateTime.utc(2026, 8, 23, 12).microsecondsSinceEpoch,
        offsetSeconds: 0,
        itemId: null,
        itemOrigin: null,
        stack: null,
        settingKey: null,
        settingValue: null,
        settingTextValue: null,
        pocketMinutes: null,
        energyLevel: null,
        reportValue: 3,
        reportWeek: 1389,
        permission: null,
        sliceCause: null,
        cluster: null,
        enabled: null,
        triageDestination: null,
        triageVolumeTag: null,
        triageBoxId: null,
        beforeName: null,
        afterName: null,
      ));
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
      ..entries.add(_installOpen())
      ..entries.add((
        id: 'seed-week-answered',
        kind: 'report_answered',
        instantUtcMicros: DateTime.utc(2026, 8, 23, 12).microsecondsSinceEpoch,
        offsetSeconds: 0,
        itemId: null,
        itemOrigin: null,
        stack: null,
        settingKey: null,
        settingValue: null,
        settingTextValue: null,
        pocketMinutes: null,
        energyLevel: null,
        reportValue: 3,
        reportWeek: 1389,
        permission: null,
        sliceCause: null,
        cluster: null,
        enabled: null,
        triageDestination: null,
        triageVolumeTag: null,
        triageBoxId: null,
        beforeName: null,
        afterName: null,
      ))
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
        settingTextValue: null,
        pocketMinutes: 45,
        energyLevel: null,
        reportValue: null,
        reportWeek: null,
        permission: null,
        sliceCause: null,
        cluster: null,
        enabled: null,
        triageDestination: null,
        triageVolumeTag: null,
        triageBoxId: null,
        beforeName: null,
        afterName: null,
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

    second.complete(
      const DispenserDealt(
        _testCard,
        stripResident: StripResident.energyCheckIn,
      ),
    );
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
    first.complete(
      const DispenserDealt(
        _testCard,
        stripResident: StripResident.energyCheckIn,
      ),
    );
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

  group('the weekly self-report resident (Story 2.6, SM-2, FR-4, UX-DR22)', () {
    DateTime sundayClock() => DateTime.utc(2026, 8, 30, 12);

    /// The Sunday launch — the report's own matrix clock: the running
    /// week 1390 closes today, and its unanswered report holds the
    /// strip's slot at the first opening.
    Future<DispenserController> launchSundayAndCommit(
      WidgetTester tester,
    ) async {
      final store = _RecordingStore()..entries.add(_installOpen());
      final session = SessionController(
        store: store,
        strings: AppStringsEs(),
        bundle: bundle(),
        nowOf: sundayClock,
      );
      final controller = DispenserController(
        store: store,
        strings: AppStringsEs(),
        bundle: bundle(),
        nowOf: sundayClock,
      );
      final opening = session.handleAppOpen();
      await tester.pumpWidget(
        _harness(controller, sessionSettled: () => session.settled),
      );
      await opening;
      await tester.pumpAndSettle();
      return controller;
    }

    testWidgets('Sunday\'s first opening holds the hairlined report: the '
        'question verbatim, the five numerals as buttons, the end labels '
        'fixing the direction, the ✕ — and the check-in displaced below '
        'nothing (SM-2, UX-DR22)', (tester) async {
      final controller = await launchSundayAndCommit(tester);
      final strings = AppStringsEs();

      expect(find.byType(TaskCard), findsOneWidget);
      expect(find.byType(SelfReportStrip), findsOneWidget);
      expect(
        find.text(strings.weeklySelfReportQuestion),
        findsOneWidget,
        reason: 'the SM-2 instrument, verbatim',
      );
      // Below the card, geometrically.
      expect(
        tester.getTopLeft(find.byType(SelfReportStrip)).dy,
        greaterThan(tester.getTopLeft(find.byType(TaskCard)).dy),
      );

      // The five numerals are buttons whose spoken label is the
      // numeral the mark's own text already carries — no selection
      // state exists anywhere on the scale.
      for (var value = 1; value <= 5; value++) {
        final digitText = find.text(strings.selfReportScaleValue(value));
        expect(digitText, findsOneWidget);
        final mark = find
            .ancestor(of: digitText, matching: find.byType(Semantics))
            .first;
        final semantics = tester.widget<Semantics>(mark);
        expect(semantics.properties.button, isTrue);
        expect(semantics.properties.selected, isNull);
        expect(
          semantics.properties.label,
          isNull,
          reason: 'the numeral itself is the spoken label',
        );
      }

      // The end labels render visibly, Nada under the 1 and Muchísimo
      // under the 5 — the scale's direction reads without explanation.
      final low = find.text(strings.selfReportScaleLow);
      final high = find.text(strings.selfReportScaleHigh);
      expect(low, findsOneWidget);
      expect(high, findsOneWidget);
      expect(
        tester.getTopLeft(low).dx,
        lessThan(tester.getTopLeft(high).dx),
        reason: 'Nada sits under the 1, Muchísimo under the 5',
      );

      // The ✕ carries its own label; the check-in is displaced —
      // nothing energy-shaped renders anywhere.
      expect(
        find.bySemanticsLabel(strings.ambientStripDismiss),
        findsOneWidget,
      );
      expect(find.text(strings.energyCheckInQuestion), findsNothing);
      expect(find.byType(BatteryGlyph), findsNothing);
      expect(
        storeOf(controller).entries
            .where((entry) => entry.kind == 'report_answered')
            .toList(),
        isEmpty,
        reason: 'reading wrote nothing',
      );

      // The hairline: the resident's own wrapper carries the 1px
      // outline edge with the default radius — the task card's exact
      // precedent, never the container's.
      final theme = OrganizerTheme.light();
      final wrapper = find.descendant(
        of: find.byType(SelfReportStrip),
        matching: find.byType(Container),
      );
      final decoration =
          tester.widget<Container>(wrapper).decoration! as BoxDecoration;
      expect(decoration.border!.top.width, 1);
      expect(decoration.border!.top.color, theme.colorScheme.outline);
      expect(
        decoration.borderRadius,
        BorderRadius.circular(Radii.radiusDefault),
      );
    });

    testWidgets('a digit tap lands exactly one report_answered row '
        'carrying the asked week, and the same opening hands the slot to '
        'the check-in (FR-4\'s deterministic handoff)', (tester) async {
      final controller = await launchSundayAndCommit(tester);
      final store = storeOf(controller);
      final strings = AppStringsEs();

      final third = find.text(strings.selfReportScaleValue(3));
      await tester.ensureVisible(third);
      await tester.pumpAndSettle();
      await tester.tap(third);
      await tester.pumpAndSettle();

      final rows = store.entries
          .where((entry) => entry.kind == 'report_answered')
          .toList();
      expect(rows, hasLength(1));
      expect(rows.single.reportValue, 3);
      expect(rows.single.reportWeek, 1390);
      expect(rows.single.itemId, isNull);

      // The handoff: the same opening's committed view holds the
      // check-in — displaced, not consumed — while the report leaves.
      expect(find.text(strings.weeklySelfReportQuestion), findsNothing);
      expect(find.text(strings.energyCheckInQuestion), findsOneWidget);
      expect(find.byType(BatteryGlyph), findsNWidgets(3));
      expect(find.text('Hecho'), findsOneWidget);
    });

    testWidgets('answer and dismissal capture the tap before lifecycle '
        'settlement crosses 04:00', (tester) async {
      final beforeBoundary = DateTime.utc(2026, 8, 30, 3, 59);
      final afterBoundary = DateTime.utc(2026, 8, 30, 4, 1);

      Future<
        ({
          _CapturingReportActionController controller,
          Completer<void> settlement,
          void Function() advanceClock,
        })
      >
      pumpGatedReport() async {
        var now = beforeBoundary;
        final controller = _CapturingReportActionController(() => now);
        final settlement = Completer<void>();
        var gateActions = false;
        await tester.pumpWidget(
          _harness(
            controller,
            sessionSettled: () =>
                gateActions ? settlement.future : Future<void>.value(),
          ),
        );
        await tester.pumpAndSettle();
        gateActions = true;
        addTearDown(() {
          if (!settlement.isCompleted) {
            settlement.complete();
          }
        });
        return (
          controller: controller,
          settlement: settlement,
          advanceClock: () => now = afterBoundary,
        );
      }

      final answering = await pumpGatedReport();
      final third = find.text(AppStringsEs().selfReportScaleValue(3));
      await tester.ensureVisible(third);
      await tester.tap(third);
      await tester.pump();
      answering.advanceClock();
      answering.settlement.complete();
      await tester.pumpAndSettle();
      expect(answering.controller.answeredAt, beforeBoundary);

      await tester.pumpWidget(const SizedBox.shrink());
      final dismissing = await pumpGatedReport();
      await tester.tap(
        find.bySemanticsLabel(AppStringsEs().ambientStripDismiss),
      );
      await tester.pump();
      dismissing.advanceClock();
      dismissing.settlement.complete();
      await tester.pumpAndSettle();
      expect(dismissing.controller.dismissedAt, beforeBoundary);
    });

    testWidgets('the report renders beneath closed and rest-offer views', (
      tester,
    ) async {
      for (final view in <DispenserView>[
        const DispenserClosed(
          stripResident: StripResident.weeklySelfReport,
          reportWeekOrdinal: 1390,
        ),
        const DispenserRestOffer(
          stripResident: StripResident.weeklySelfReport,
          reportWeekOrdinal: 1390,
        ),
      ]) {
        final read = Completer<DispenserView>()..complete(view);
        await tester.pumpWidget(_harness(_QueuedReadController([read])));
        await tester.pumpAndSettle();
        expect(find.byType(SelfReportStrip), findsOneWidget);
        expect(
          find.text(AppStringsEs().weeklySelfReportQuestion),
          findsOneWidget,
        );
        await tester.pumpWidget(const SizedBox.shrink());
      }
    });

    testWidgets('a failed report append restores the standing card and '
        'report — the retry is the same tap (matrix: failed append)', (
      tester,
    ) async {
      final controller = await launchSundayAndCommit(tester);
      final store = storeOf(controller)..failNextAppend = true;
      final strings = AppStringsEs();

      final third = find.text(strings.selfReportScaleValue(3));
      await tester.ensureVisible(third);
      await tester.tap(third);
      await tester.pumpAndSettle();

      // Nothing landed on the failed write: the week stays unanswered
      // and the recovery read re-resolves the report — the question
      // and the card return, nothing celebration-shaped anywhere.
      expect(
        store.entries.where((entry) => entry.kind == 'report_answered'),
        isEmpty,
      );
      expect(find.text(strings.weeklySelfReportQuestion), findsOneWidget);
      expect(find.byType(SelfReportStrip), findsOneWidget);
      expect(find.byType(TaskCard), findsOneWidget);
    });

    testWidgets('the report\'s ✕ writes nothing and frees the slot for '
        'that opening alone — the check-in takes it in the same opening '
        '(SM-2, UX-DR22)', (tester) async {
      final controller = await launchSundayAndCommit(tester);
      final store = storeOf(controller);
      final strings = AppStringsEs();
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
      expect(find.text(strings.weeklySelfReportQuestion), findsNothing);
      expect(find.text(strings.energyCheckInQuestion), findsOneWidget);
      expect(find.byType(BatteryGlyph), findsNWidgets(3));
    });

    testWidgets('a pending report dismissal blocks a stale digit tap', (
      tester,
    ) async {
      final controller = await launchSundayAndCommit(tester);
      final store = storeOf(controller);
      final strings = AppStringsEs();
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

      // The ✕ parks behind the gated settlement; the report still
      // renders, so the stale digit tap is physically available —
      // and refused by the shared in-flight guard.
      await tester.ensureVisible(find.bySemanticsLabel('Cerrar'));
      await tester.pumpAndSettle();
      await tester.tap(find.bySemanticsLabel('Cerrar'));
      await tester.pump();
      final third = find.text(strings.selfReportScaleValue(3));
      await tester.ensureVisible(third);
      await tester.tap(third);
      await tester.pump();
      settlement.complete();
      await tester.pumpAndSettle();

      // The dismissal committed and wrote nothing; the refused digit
      // minted no row either — the week stays unanswered.
      expect(
        store.entries.where((entry) => entry.kind == 'report_answered'),
        isEmpty,
        reason: 'a write already in flight owns the surface',
      );
      expect(find.text(strings.weeklySelfReportQuestion), findsNothing);
      expect(find.text(strings.energyCheckInQuestion), findsOneWidget);
      expect(find.byType(TaskCard), findsOneWidget);
    });

    testWidgets('a stale read in flight when the report\'s ✕ lands '
        'cannot resurrect it — the dismissal\'s generation bump holds', (
      tester,
    ) async {
      final first = Completer<DispenserView>();
      final second = Completer<DispenserView>();
      final controller = _QueuedDismissReportController([first, second]);

      await tester.pumpWidget(_harness(controller));
      await tester.pump();
      // A foreground return queues a second read (the newer
      // generation); the launch read stays hanging as the stale one.
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();

      second.complete(
        const DispenserDealt(
          _testCard,
          stripResident: StripResident.weeklySelfReport,
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.text(AppStringsEs().weeklySelfReportQuestion),
        findsOneWidget,
      );

      // The ✕: its handler bumps the generation and resolves through
      // the controllable dismissal.
      await tester.ensureVisible(find.bySemanticsLabel('Cerrar'));
      await tester.pumpAndSettle();
      await tester.tap(find.bySemanticsLabel('Cerrar'));
      await tester.pump();
      controller.dismissal.complete(const DispenserDealt(_testCard));
      await tester.pumpAndSettle();
      expect(find.text(AppStringsEs().weeklySelfReportQuestion), findsNothing);

      // The stale launch read completes last, carrying the report —
      // its generation no longer matches, so it must not commit.
      first.complete(
        const DispenserDealt(
          _testCard,
          stripResident: StripResident.weeklySelfReport,
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.text(AppStringsEs().weeklySelfReportQuestion),
        findsNothing,
        reason:
            'a read from before the dismissal cannot resurrect the '
            'report — the generation bump refuses its commit',
      );
      expect(find.byType(TaskCard), findsOneWidget);
    });

    testWidgets('a stale read in flight when the answer lands cannot '
        'resurrect the report — the answer\'s generation bump holds', (
      tester,
    ) async {
      final first = Completer<DispenserView>();
      final second = Completer<DispenserView>();
      final controller = _QueuedAnswerReportController([first, second]);

      await tester.pumpWidget(_harness(controller));
      await tester.pump();
      // A foreground return queues a second read (the newer
      // generation); the launch read stays hanging as the stale one.
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();

      second.complete(
        const DispenserDealt(
          _testCard,
          stripResident: StripResident.weeklySelfReport,
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.text(AppStringsEs().weeklySelfReportQuestion),
        findsOneWidget,
      );

      // The digit tap: its handler bumps the generation and resolves
      // through the controllable answer.
      final third = find.text(AppStringsEs().selfReportScaleValue(3));
      await tester.ensureVisible(third);
      await tester.pumpAndSettle();
      await tester.tap(third);
      await tester.pump();
      controller.answer.complete(const DispenserDealt(_testCard));
      await tester.pumpAndSettle();
      expect(find.text(AppStringsEs().weeklySelfReportQuestion), findsNothing);

      // The stale launch read completes last, carrying the report —
      // its generation no longer matches, so it must not commit:
      // neither a resurrection nor a re-armed answer can ride it.
      first.complete(
        const DispenserDealt(
          _testCard,
          stripResident: StripResident.weeklySelfReport,
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.text(AppStringsEs().weeklySelfReportQuestion),
        findsNothing,
        reason:
            'a read from before the answer cannot resurrect the '
            'report — the generation bump refuses its commit',
      );
      expect(find.byType(TaskCard), findsOneWidget);
    });

    testWidgets('200% font scale: the hairlined resident grows and '
        'scrolls over the 5×48dp row, the labels wrap, nothing truncates '
        '(UX-DR45, NFR6)', (tester) async {
      tester.platformDispatcher.textScaleFactorTestValue = 2.0;
      addTearDown(tester.platformDispatcher.clearAllTestValues);
      await tester.binding.setSurfaceSize(const ui.Size(320, 480));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await launchSundayAndCommit(tester);
      final strings = AppStringsEs();

      expect(tester.takeException(), isNull);
      expect(find.text(strings.weeklySelfReportQuestion), findsOneWidget);
      expect(find.text(strings.selfReportScaleLow), findsOneWidget);
      expect(find.text(strings.selfReportScaleHigh), findsOneWidget);

      // Every digit keeps the 48dp floor, whatever row the Wrap gave
      // it — five targets, none shrunk to fit.
      for (var value = 1; value <= 5; value++) {
        final target = find
            .ancestor(
              of: find.text(strings.selfReportScaleValue(value)),
              matching: find.byType(GestureDetector),
            )
            .first;
        final box = tester.renderObject<RenderBox>(target);
        expect(box.size.width, greaterThanOrEqualTo(48));
        expect(box.size.height, greaterThanOrEqualTo(48));
      }

      // The resident joins the card's scroll region: the grown content
      // really scrolls, nothing clips.
      final scrollable = tester.state<ScrollableState>(find.byType(Scrollable));
      await tester.drag(
        find.byType(SingleChildScrollView),
        const Offset(0, -60),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(scrollable.position.pixels, greaterThan(0));
      expect(find.text(strings.weeklySelfReportQuestion), findsOneWidget);
    });
  });

  group('the once-ever first-run curation offer (Story 5.12, FR-31, '
      'UX-DR22, E1)', () {
    /// A fresh install's Saturday launch — no seed rows at all, so the
    /// log's only `app_opened` is today's and the first opening EVER
    /// is underway: the offer holds the slot, every other resident
    /// displaced. The store is a parameter so a read-failure arm can
    /// wrap it.
    Future<DispenserController> launchFreshOver(
      WidgetTester tester,
      StorePort store,
    ) async {
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

    Future<DispenserController> launchFreshAndCommit(WidgetTester tester) =>
        launchFreshOver(tester, _RecordingStore());

    testWidgets('renders the invitation sentence verbatim as one '
        'whole-sentence button with the ✕ — bare chrome, everything '
        'else displaced (UX-DR22, FR-31)', (tester) async {
      final controller = await launchFreshAndCommit(tester);
      final strings = AppStringsEs();

      expect(find.byType(TaskCard), findsOneWidget);
      expect(find.byType(CurationOfferStrip), findsOneWidget);
      expect(find.text(strings.curationInvitation), findsOneWidget);
      final invitation = tester.widget<Text>(
        find.text(strings.curationInvitation),
      );
      final invitationStyle = invitation.style!;
      expect(invitationStyle.fontFamily, TypeRoles.support.fontFamily);
      expect(invitationStyle.fontSize, TypeRoles.support.fontSize);
      expect(invitationStyle.fontWeight, TypeRoles.support.fontWeight);
      expect(invitationStyle.height, TypeRoles.support.height);
      expect(invitationStyle.letterSpacing, TypeRoles.support.letterSpacing);
      expect(invitationStyle.color, FieldPalette.inkSecondary);
      // Below the card, geometrically.
      expect(
        tester.getTopLeft(find.byType(CurationOfferStrip)).dy,
        greaterThan(tester.getTopLeft(find.byType(TaskCard)).dy),
      );

      // The whole sentence is one button: the semantics above the
      // text declares it, and the band holds the 48dp floor as one
      // opaque target.
      final sentence = find
          .ancestor(
            of: find.text(strings.curationInvitation),
            matching: find.byType(Semantics),
          )
          .first;
      expect(tester.widget<Semantics>(sentence).properties.button, isTrue);
      final band = find
          .ancestor(
            of: find.text(strings.curationInvitation),
            matching: find.byType(GestureDetector),
          )
          .first;
      final box = tester.renderObject<RenderBox>(band);
      expect(box.size.height, greaterThanOrEqualTo(48));

      // Bare chrome: no hairlined wrapper anywhere in the strip — the
      // offer is the rarest resident, never a persistent one.
      expect(
        find.descendant(
          of: find.byType(CurationOfferStrip),
          matching: find.byType(Container),
        ),
        findsNothing,
      );

      // The displaced instruments render nothing; the ✕ carries its
      // own label; reading wrote nothing.
      expect(find.byType(BatteryGlyph), findsNothing);
      expect(find.text(strings.weeklySelfReportQuestion), findsNothing);
      expect(
        find.bySemanticsLabel(strings.ambientStripDismiss),
        findsOneWidget,
      );
      expect(
        storeOf(controller).entries
            .where((entry) => entry.kind == 'energy_set'),
        isEmpty,
      );
    });

    testWidgets('blank padding inside the invitation band accepts it', (
      tester,
    ) async {
      var accepted = false;
      await tester.pumpWidget(
        MaterialApp(
          theme: OrganizerTheme.light(),
          localizationsDelegates: AppStrings.localizationsDelegates,
          supportedLocales: AppStrings.supportedLocales,
          home: Scaffold(
            body: CurationOfferStrip(onAccept: () => accepted = true),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final band = find
          .ancestor(
            of: find.text(AppStringsEs().curationInvitation),
            matching: find.byType(GestureDetector),
          )
          .first;
      final bandRect = tester.getRect(band);
      await tester.tapAt(
        Offset(bandRect.center.dx + bandRect.width * 0.35, bandRect.center.dy),
      );
      expect(accepted, isTrue);
    });

    testWidgets('the ✕ writes nothing and the offer is gone — the '
        'displaced report takes the slot in the same opening (matrix: '
        'dismiss the offer)', (tester) async {
      final controller = await launchFreshAndCommit(tester);
      final store = storeOf(controller);
      final strings = AppStringsEs();
      final kindsBefore = store.entries.map((entry) => entry.kind).toList();

      await tester.ensureVisible(
        find.bySemanticsLabel(strings.ambientStripDismiss),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.bySemanticsLabel(strings.ambientStripDismiss));
      await tester.pumpAndSettle();

      expect(
        store.entries.map((entry) => entry.kind).toList(),
        kindsBefore,
        reason: 'a dismissal appends nothing at all',
      );
      expect(find.text(strings.curationInvitation), findsNothing);
      expect(
        find.text(strings.weeklySelfReportQuestion),
        findsOneWidget,
        reason:
            'the fresh install\'s unanswered week takes the freed slot '
            '— the 2.6 handoff grammar',
      );
      expect(find.text('Hecho'), findsOneWidget);
    });

    testWidgets('the tap consumes the offer and pushes the E1 surface — '
        'the house title over the rows; back → the offer never returns '
        '(matrix: tap the offer)', (tester) async {
      await launchFreshAndCommit(tester);
      final strings = AppStringsEs();

      await tester.ensureVisible(find.text(strings.curationInvitation));
      await tester.pumpAndSettle();
      await tester.tap(find.text(strings.curationInvitation));
      await tester.pumpAndSettle();

      // The E1 surface: CurationScreen itself, under the house title,
      // the eight rows verbatim — a CurationRow visible.
      expect(find.byType(CurationScreen), findsOneWidget);
      expect(find.text(strings.curationHouseGroups), findsOneWidget);
      expect(find.text(strings.settingsCurationGroups), findsNothing);
      expect(find.text(strings.curationClusterAnclas), findsOneWidget);
      expect(find.byType(CurationRow), findsNWidgets(8));

      // Back: the offer is gone for the process — the committed view
      // already holds the freed slot, and nothing resurrects it.
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text(strings.curationInvitation), findsNothing);
      expect(
        find.text(strings.weeklySelfReportQuestion),
        findsOneWidget,
        reason: 'the displaced report holds the slot beneath the route',
      );
      expect(find.byType(TaskCard), findsOneWidget);
    });

    testWidgets('a failing read under the tap is quiet — no push, no '
        'error surface — and once the read heals the offer never returns: '
        'the consumption marker held through the failure (matrix: read '
        'failure under the tap)', (tester) async {
      final failing = _FailReadWhileArmedStore(_RecordingStore());
      await launchFreshOver(tester, failing);
      final strings = AppStringsEs();
      expect(find.text(strings.curationInvitation), findsOneWidget);

      failing.failReads = true;
      await tester.ensureVisible(find.text(strings.curationInvitation));
      await tester.pumpAndSettle();
      await tester.tap(find.text(strings.curationInvitation));
      await tester.pumpAndSettle();

      // Quiet: no E1 surface, no error widget, nothing escaping.
      expect(find.byType(CurationScreen), findsNothing);
      expect(find.byType(ErrorWidget), findsNothing);
      expect(tester.takeException(), isNull);

      // The read heals and a foreground return re-reads: the offer is
      // spent for the process — the displaced report holds the slot.
      failing.failReads = false;
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text(strings.curationInvitation), findsNothing);
      expect(find.text(strings.weeklySelfReportQuestion), findsOneWidget);
    });

    testWidgets('a failing read under the ✕ is quiet too — no error '
        'surface, nothing written — and the healed re-read shows the '
        'offer never returned either (matrix: read failure under the '
        'dismissal)', (tester) async {
      final inner = _RecordingStore();
      final failing = _FailReadWhileArmedStore(inner);
      await launchFreshOver(tester, failing);
      final strings = AppStringsEs();
      final kindsBefore = inner.entries.map((entry) => entry.kind).toList();

      failing.failReads = true;
      await tester.ensureVisible(
        find.bySemanticsLabel(strings.ambientStripDismiss),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.bySemanticsLabel(strings.ambientStripDismiss));
      await tester.pumpAndSettle();

      // Quiet: no error widget, no exception, and the ✕ wrote nothing.
      expect(find.byType(CurationScreen), findsNothing);
      expect(find.byType(ErrorWidget), findsNothing);
      expect(tester.takeException(), isNull);
      expect(
        inner.entries.map((entry) => entry.kind).toList(),
        kindsBefore,
        reason: 'the failed dismissal appended nothing at all',
      );

      failing.failReads = false;
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text(strings.curationInvitation), findsNothing);
      expect(find.text(strings.weeklySelfReportQuestion), findsOneWidget);
    });

    testWidgets('200% font scale: the sentence button and the ✕ hold '
        'their floors, the strip grows inside the scroll (UX-DR45, '
        'NFR6)', (tester) async {
      tester.platformDispatcher.textScaleFactorTestValue = 2.0;
      addTearDown(tester.platformDispatcher.clearAllTestValues);
      await tester.binding.setSurfaceSize(const ui.Size(320, 480));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final strings = AppStringsEs();
      await launchFreshAndCommit(tester);

      expect(tester.takeException(), isNull);
      expect(find.text(strings.curationInvitation), findsOneWidget);

      final band = find
          .ancestor(
            of: find.text(strings.curationInvitation),
            matching: find.byType(GestureDetector),
          )
          .first;
      final box = tester.renderObject<RenderBox>(band);
      expect(box.size.height, greaterThanOrEqualTo(48));
      final dismissTarget = find.descendant(
        of: find.bySemanticsLabel(strings.ambientStripDismiss),
        matching: find.byType(GestureDetector),
      );
      final dismissBox = tester.renderObject<RenderBox>(dismissTarget);
      expect(dismissBox.size.width, greaterThanOrEqualTo(48));
      expect(dismissBox.size.height, greaterThanOrEqualTo(48));

      final scrollable = tester.state<ScrollableState>(find.byType(Scrollable));
      await tester.drag(
        find.byType(SingleChildScrollView),
        const Offset(0, -60),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(scrollable.position.pixels, greaterThan(0));
      expect(find.text(strings.curationInvitation), findsOneWidget);
    });
  });

  group('the once-per-season suggestion (Story 5.13, FR-15, UX-DR22)', () {
    PoolFactRecord dormantEpic(String stableId) => (
      id: stableId,
      origin: Origin.cloud,
      size: sizeOfEstimateSeconds(180),
      instantUtcMicros: DateTime.utc(2026, 8, 20, 9).microsecondsSinceEpoch,
      offsetSeconds: 0,
      originContext: 'el trastero del fondo',
      dictated: null,
      rescueOf: null,
      estimateSeconds: 180,
      stepText: 'Recoger las cajas',
    );

    /// The established install's first opening over a dormant Epic —
    /// the install open and the answered week seeded beside the facts,
    /// so the suggestion holds the slot over the check-in. The [epic]
    /// param lets a test swap the fixture (the 200% pin's long
    /// description).
    Future<_FactsRecordingStore> launchWithDormant(
      WidgetTester tester, {
      PoolFactRecord? epic,
    }) async {
      final store = _FactsRecordingStore([epic ?? dormantEpic('s1')]);
      for (final entry in [
        (
          id: 'install-open',
          kind: 'app_opened',
          at: DateTime.utc(2026, 8, 28, 20),
        ),
        (
          id: 'seed-week-answered',
          kind: 'report_answered',
          at: DateTime.utc(2026, 8, 23, 12),
        ),
      ]) {
        store.entries.add((
          id: entry.id,
          kind: entry.kind,
          instantUtcMicros: entry.at.microsecondsSinceEpoch,
          offsetSeconds: 0,
          itemId: null,
          itemOrigin: null,
          stack: null,
          settingKey: null,
          settingValue: null,
          settingTextValue: null,
          pocketMinutes: null,
          energyLevel: null,
          reportValue: entry.kind == 'report_answered' ? 3 : null,
          reportWeek: entry.kind == 'report_answered' ? 1389 : null,
          permission: null,
          sliceCause: null,
          cluster: null,
          enabled: null,
          triageDestination: null,
          triageVolumeTag: null,
          triageBoxId: null,
          beforeName: null,
          afterName: null,
        ));
      }
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
      return store;
    }

    testWidgets('renders the sentence naming the Epic verbatim as one '
        'whole-sentence button with the ✕ — bare chrome, everything '
        'else displaced (UX-DR22, FR-15)', (tester) async {
      await launchWithDormant(tester);
      final strings = AppStringsEs();
      final sentence = strings.seasonalSuggestion('el trastero del fondo');

      expect(find.byType(TaskCard), findsOneWidget);
      expect(find.byType(SeasonalSuggestionStrip), findsOneWidget);
      expect(find.text(sentence), findsOneWidget);
      final text = tester.widget<Text>(find.text(sentence));
      final style = text.style!;
      expect(style.fontFamily, TypeRoles.support.fontFamily);
      expect(style.fontSize, TypeRoles.support.fontSize);
      expect(style.fontWeight, TypeRoles.support.fontWeight);
      expect(style.height, TypeRoles.support.height);
      expect(style.letterSpacing, TypeRoles.support.letterSpacing);
      expect(style.color, FieldPalette.inkSecondary);
      // Below the card, geometrically.
      expect(
        tester.getTopLeft(find.byType(SeasonalSuggestionStrip)).dy,
        greaterThan(tester.getTopLeft(find.byType(TaskCard)).dy),
      );

      // The whole sentence is one button: the semantics above the
      // text declares it, and the band holds the 48dp floor as one
      // opaque target.
      final button = find
          .ancestor(of: find.text(sentence), matching: find.byType(Semantics))
          .first;
      expect(tester.widget<Semantics>(button).properties.button, isTrue);
      final band = find
          .ancestor(
            of: find.text(sentence),
            matching: find.byType(GestureDetector),
          )
          .first;
      final box = tester.renderObject<RenderBox>(band);
      expect(box.size.height, greaterThanOrEqualTo(48));

      // Bare chrome: no hairlined wrapper anywhere in the strip — the
      // suggestion is an ephemeral resident, never a persistent one.
      expect(
        find.descendant(
          of: find.byType(SeasonalSuggestionStrip),
          matching: find.byType(Container),
        ),
        findsNothing,
      );

      // The displaced instruments render nothing; the ✕ carries its
      // own label.
      expect(find.byType(BatteryGlyph), findsNothing);
      expect(find.text(strings.weeklySelfReportQuestion), findsNothing);
      expect(
        find.bySemanticsLabel(strings.ambientStripDismiss),
        findsOneWidget,
      );
    });

    testWidgets('blank padding inside the sentence band accepts it', (
      tester,
    ) async {
      var accepted = false;
      var dismissed = false;
      await tester.pumpWidget(
        MaterialApp(
          theme: OrganizerTheme.light(),
          localizationsDelegates: AppStrings.localizationsDelegates,
          supportedLocales: AppStrings.supportedLocales,
          home: Scaffold(
            body: SeasonalSuggestionStrip(
              suggestion: const (
                stableId: 's1',
                origin: Origin.cloud,
                description: 'el trastero del fondo',
              ),
              onAccept: () => accepted = true,
              onDismiss: () => dismissed = true,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final band = find
          .ancestor(
            of: find.text(
              AppStringsEs().seasonalSuggestion('el trastero del fondo'),
            ),
            matching: find.byType(GestureDetector),
          )
          .first;
      final bandRect = tester.getRect(band);
      await tester.tapAt(
        Offset(bandRect.center.dx + bandRect.width * 0.35, bandRect.center.dy),
      );
      expect(accepted, isTrue);
      expect(dismissed, isFalse);
    });

    testWidgets('the ✕ writes exactly one suggestion_dismissed row '
        'naming the shown project and the strip hands the slot to the '
        'check-in in the same opening (matrix: dismiss)', (tester) async {
      final store = await launchWithDormant(tester);
      final strings = AppStringsEs();
      final sentence = strings.seasonalSuggestion('el trastero del fondo');

      await tester.ensureVisible(find.text(sentence));
      await tester.pumpAndSettle();
      await tester.tap(find.bySemanticsLabel(strings.ambientStripDismiss));
      await tester.pumpAndSettle();

      final rows = store.entries
          .where((entry) => entry.kind == 'suggestion_dismissed')
          .toList();
      expect(rows, hasLength(1));
      expect(rows.single.itemId, 's1');
      expect(rows.single.itemOrigin, Origin.cloud);
      expect(find.text(sentence), findsNothing);
      expect(
        find.text(strings.energyCheckInQuestion),
        findsOneWidget,
        reason: 'the freed slot — the check-in takes it in the same opening',
      );
      expect(find.text('Hecho'), findsOneWidget);
    });

    testWidgets('the tap activates the Epic through one epic_activated '
        'row — the strip gone by derivation, no push, nothing else '
        '(matrix: accept)', (tester) async {
      final store = await launchWithDormant(tester);
      final strings = AppStringsEs();
      final sentence = strings.seasonalSuggestion('el trastero del fondo');

      await tester.ensureVisible(find.text(sentence));
      await tester.pumpAndSettle();
      await tester.tap(find.text(sentence));
      await tester.pumpAndSettle();

      final rows = store.entries
          .where((entry) => entry.kind == 'epic_activated')
          .toList();
      expect(rows, hasLength(1));
      expect(rows.single.itemId, 's1');
      expect(find.text(sentence), findsNothing);
      expect(
        find.text(strings.energyCheckInQuestion),
        findsOneWidget,
        reason: 'gone by derivation — the check-in holds the freed slot',
      );
      // No push: the accept is the activation, never a route.
      expect(find.byType(CurationScreen), findsNothing);
    });

    testWidgets('200% font scale over a long description: the sentence '
        'button and the ✕ hold their floors, the strip grows inside '
        'the scroll (UX-DR45, NFR6 — the siblings\' own pin)', (tester) async {
      tester.platformDispatcher.textScaleFactorTestValue = 2.0;
      addTearDown(tester.platformDispatcher.clearAllTestValues);
      await tester.binding.setSurfaceSize(const ui.Size(320, 480));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      // The Epic's Origin Context is arbitrary user text — the longest
      // copy any resident shows. The fixture's own long arm.
      final long = dormantEpic('s1');
      final epic = (
        id: long.id,
        origin: long.origin,
        size: long.size,
        instantUtcMicros: long.instantUtcMicros,
        offsetSeconds: long.offsetSeconds,
        originContext:
            'el trastero del fondo del pasillo, el que tiene las cajas '
            'de la mudanza y los abrigos del invierno pasado',
        dictated: long.dictated,
        rescueOf: long.rescueOf,
        estimateSeconds: long.estimateSeconds,
        stepText: long.stepText,
      );
      await launchWithDormant(tester, epic: epic);

      final strings = AppStringsEs();
      final sentence = strings.seasonalSuggestion(epic.originContext);
      expect(tester.takeException(), isNull);
      expect(find.text(sentence), findsOneWidget);

      final band = find
          .ancestor(
            of: find.text(sentence),
            matching: find.byType(GestureDetector),
          )
          .first;
      final box = tester.renderObject<RenderBox>(band);
      expect(box.size.height, greaterThanOrEqualTo(48));
      final dismissTarget = find.descendant(
        of: find.bySemanticsLabel(strings.ambientStripDismiss),
        matching: find.byType(GestureDetector),
      );
      final dismissBox = tester.renderObject<RenderBox>(dismissTarget);
      expect(dismissBox.size.width, greaterThanOrEqualTo(48));
      expect(dismissBox.size.height, greaterThanOrEqualTo(48));

      final scrollable = tester.state<ScrollableState>(find.byType(Scrollable));
      await tester.drag(
        find.byType(SingleChildScrollView),
        const Offset(0, -60),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(scrollable.position.pixels, greaterThan(0));
      expect(find.text(sentence), findsOneWidget);
    });

    testWidgets('a null shown record renders nothing — no fallback '
        'sentence, no ✕; the derivation-violating path stays the quiet '
        'one', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: OrganizerTheme.light(),
          localizationsDelegates: AppStrings.localizationsDelegates,
          supportedLocales: AppStrings.supportedLocales,
          home: const Scaffold(
            body: SeasonalSuggestionStrip(
              suggestion: null,
              onAccept: _Noop.accept,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(SeasonalSuggestionStrip), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(SeasonalSuggestionStrip),
          matching: find.byType(Text),
        ),
        findsNothing,
      );
      expect(
        find.bySemanticsLabel(AppStringsEs().ambientStripDismiss),
        findsNothing,
      );
      expect(tester.takeException(), isNull);
    });
  });

  group('the blind six-month quarantine follow-up (Story 6.6, FR-21, '
      'UX-DR22)', () {
    DateTime dueDayClock() => DateTime.utc(2026, 9, 1, 12);

    /// The due week a Tuesday 2026-09-01 read judges due (the week
    /// anchored Monday 2026-08-24), answered — so the freed slot
    /// reads as null and the follow-up alone owes the strip.
    LogEntryRecord answeredDueWeek() => (
      id: 'seed-week-answered',
      kind: 'report_answered',
      instantUtcMicros: DateTime.utc(2026, 8, 23, 12).microsecondsSinceEpoch,
      offsetSeconds: 0,
      itemId: null,
      itemOrigin: null,
      stack: null,
      settingKey: null,
      settingValue: null,
      settingTextValue: null,
      pocketMinutes: null,
      energyLevel: null,
      reportValue: 3,
      reportWeek: 1390,
      permission: null,
      sliceCause: null,
      cluster: null,
      enabled: null,
      triageDestination: null,
      triageVolumeTag: null,
      triageBoxId: null,
      beforeName: null,
      afterName: null,
    );

    /// A `box_created` row — the core suite's `_box` pattern, one
    /// local shape for the whole group.
    LogEntryRecord boxRow(String id, DateTime at) => (
      id: id,
      kind: 'box_created',
      instantUtcMicros: at.microsecondsSinceEpoch,
      offsetSeconds: 0,
      itemId: null,
      itemOrigin: null,
      stack: null,
      settingKey: null,
      settingValue: null,
      settingTextValue: null,
      pocketMinutes: null,
      energyLevel: null,
      reportValue: null,
      reportWeek: null,
      permission: null,
      sliceCause: null,
      cluster: null,
      enabled: null,
      triageDestination: null,
      triageVolumeTag: null,
      triageBoxId: null,
      beforeName: null,
      afterName: null,
    );

    /// The box's linked `item_triaged(quarantine)` row — the same
    /// pattern with the two triage fields carried.
    LogEntryRecord intoBoxRow(String id, DateTime at, String boxId) => (
      id: id,
      kind: 'item_triaged',
      instantUtcMicros: at.microsecondsSinceEpoch,
      offsetSeconds: 0,
      itemId: null,
      itemOrigin: null,
      stack: null,
      settingKey: null,
      settingValue: null,
      settingTextValue: null,
      pocketMinutes: null,
      energyLevel: null,
      reportValue: null,
      reportWeek: null,
      permission: null,
      sliceCause: null,
      cluster: null,
      enabled: null,
      triageDestination: 'quarantine',
      triageVolumeTag: null,
      triageBoxId: boxId,
      beforeName: null,
      afterName: null,
    );

    /// One non-empty box dated 2026-03-01 — due exactly the due-day
    /// clock — as the act's own row pair.
    List<LogEntryRecord> sealedBoxPair(String id) => [
      boxRow('box-$id', DateTime.utc(2026, 3, 1, 10)),
      intoBoxRow('into-$id', DateTime.utc(2026, 3, 1, 10, 0, 1), 'box-$id'),
    ];

    /// The due-day launch over a caller-owned store — the curation
    /// group's `launchFreshOver` shape, for the failing-read pin.
    Future<DispenserController> launchDueDayOver(
      WidgetTester tester,
      StorePort store,
    ) async {
      final session = SessionController(
        store: store,
        strings: AppStringsEs(),
        bundle: bundle(),
        nowOf: dueDayClock,
      );
      final controller = DispenserController(
        store: store,
        strings: AppStringsEs(),
        bundle: bundle(),
        nowOf: dueDayClock,
      );
      final opening = session.handleAppOpen();
      await tester.pumpWidget(
        _harness(controller, sessionSettled: () => session.settled),
      );
      await opening;
      await tester.pumpAndSettle();
      return controller;
    }

    /// The due-day launch: the established install's first opening of
    /// 2026-09-01 over a box sealed 2026-03-01, the due week answered
    /// beside it.
    Future<DispenserController> launchDueDayAndCommit(
      WidgetTester tester,
    ) async {
      final store = _RecordingStore()
        ..entries.add(_installOpen())
        ..entries.add(answeredDueWeek())
        ..entries.addAll(sealedBoxPair('seed'));
      return launchDueDayOver(tester, store);
    }

    testWidgets('the due day holds the hairlined follow-up below the '
        'card: the copy verbatim, no accept path anywhere, the ✕ — and '
        'reading wrote nothing (FR-21, UX-DR22)', (tester) async {
      final controller = await launchDueDayAndCommit(tester);
      final strings = AppStringsEs();

      expect(find.byType(TaskCard), findsOneWidget);
      expect(find.byType(QuarantineFollowUpStrip), findsOneWidget);
      expect(find.text(strings.quarantineFollowUpCopy), findsOneWidget);
      // Below the card, geometrically.
      expect(
        tester.getTopLeft(find.byType(QuarantineFollowUpStrip)).dy,
        greaterThan(tester.getTopLeft(find.byType(TaskCard)).dy),
      );

      // The sentence is no button: in the merged semantics tree, no
      // node from the sentence up to — excluding — the least ancestor
      // it shares with the ✕ is flagged button or tappable (no accept
      // path exists — acting on the physical box is the user's), and
      // tapping it lands nothing. The plain `Text` in Center/
      // ConstrainedBox owns no explicit `Semantics` widget, so only
      // this tree-level probe can see an accept path appear.
      final semanticsHandle = tester.ensureSemantics();
      final sentence = find.text(strings.quarantineFollowUpCopy);
      final sentenceNode = tester.getSemantics(sentence);
      final dismissNode = tester.getSemantics(
        find.bySemanticsLabel(strings.ambientStripDismiss),
      );
      SemanticsNode? shared = sentenceNode;
      while (shared != null && !_encloses(shared, dismissNode)) {
        shared = shared.parent;
      }
      for (
        SemanticsNode? node = sentenceNode;
        node != null && !identical(node, shared);
        node = node.parent
      ) {
        expect(
          node.getSemanticsData().flagsCollection.isButton,
          isFalse,
          reason: 'the copy carries no accept path — only the ✕ acts',
        );
        expect(
          node.getSemanticsData().hasAction(SemanticsAction.tap),
          isFalse,
          reason: 'the copy carries no accept path — only the ✕ acts',
        );
      }
      semanticsHandle.dispose();
      final kindsBefore = storeOf(controller).entries
          .map((entry) => entry.kind)
          .toList();
      await tester.ensureVisible(sentence);
      await tester.pumpAndSettle();
      await tester.tap(sentence);
      await tester.pumpAndSettle();
      expect(
        storeOf(controller).entries.map((entry) => entry.kind).toList(),
        kindsBefore,
        reason: 'tapping the sentence is not an act',
      );
      expect(find.text(strings.quarantineFollowUpCopy), findsOneWidget);

      // The ✕ carries its own label, shared with every resident.
      expect(
        find.bySemanticsLabel(strings.ambientStripDismiss),
        findsOneWidget,
      );

      // The hairline: the resident's own wrapper carries the 1px
      // outline edge with the default radius — the persistent
      // resident's rule, the task card's exact precedent.
      final theme = OrganizerTheme.light();
      final wrapper = find.descendant(
        of: find.byType(QuarantineFollowUpStrip),
        matching: find.byType(Container),
      );
      final decoration =
          tester.widget<Container>(wrapper).decoration! as BoxDecoration;
      expect(decoration.border!.top.width, 1);
      expect(decoration.border!.top.color, theme.colorScheme.outline);
      expect(
        decoration.borderRadius,
        BorderRadius.circular(Radii.radiusDefault),
      );

      // The sentence row holds the 48dp floor, and the ✕ keeps its
      // 48dp opaque target.
      final sentenceTarget = find
          .ancestor(of: sentence, matching: find.byType(ConstrainedBox))
          .first;
      final sentenceBox = tester.renderObject<RenderBox>(sentenceTarget);
      expect(sentenceBox.size.height, greaterThanOrEqualTo(48));
      final dismissTarget = find.descendant(
        of: find.bySemanticsLabel(strings.ambientStripDismiss),
        matching: find.byType(GestureDetector),
      );
      final dismissBox = tester.renderObject<RenderBox>(dismissTarget);
      expect(dismissBox.size.width, greaterThanOrEqualTo(48));
      expect(dismissBox.size.height, greaterThanOrEqualTo(48));
    });

    testWidgets('the ✕ writes nothing and the follow-up is gone for the '
        'rest of the day — the ordinary card standing, nothing owed '
        '(matrix: dismissal)', (tester) async {
      final controller = await launchDueDayAndCommit(tester);
      final store = storeOf(controller);
      final strings = AppStringsEs();

      final kindsBefore = store.entries.map((entry) => entry.kind).toList();
      await tester.ensureVisible(
        find.bySemanticsLabel(strings.ambientStripDismiss),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.bySemanticsLabel(strings.ambientStripDismiss));
      await tester.pumpAndSettle();

      expect(
        store.entries.map((entry) => entry.kind).toList(),
        kindsBefore,
        reason:
            'the ✕ appends nothing at all — zero store writes, zero log '
            'rows (FR-21\'s no-side-effects clause)',
      );
      expect(find.text(strings.quarantineFollowUpCopy), findsNothing);
      expect(
        find.byType(TaskCard),
        findsOneWidget,
        reason: 'the ordinary card stands — the day is owed nothing',
      );
      // The strip never holds the follow-up again through a
      // same-process re-read: the marker is skip-for-the-day shell
      // state, no row exists to resurrect the resident from, and the
      // displaced check-in takes the freed slot (FR-4's handoff).
      expect(
        (await controller.read()).stripResident,
        StripResident.energyCheckIn,
      );
      await tester.pumpAndSettle();
      expect(find.text(strings.quarantineFollowUpCopy), findsNothing);
    });

    testWidgets('a stale read in flight when the follow-up\'s ✕ lands '
        'cannot resurrect it — the dismissal\'s generation bump holds', (
      tester,
    ) async {
      final first = Completer<DispenserView>();
      final second = Completer<DispenserView>();
      final controller = _QueuedDismissQuarantineFollowUpController([
        first,
        second,
      ]);
      final strings = AppStringsEs();

      await tester.pumpWidget(_harness(controller));
      await tester.pump();
      // A foreground return queues a second read (the newer
      // generation); the launch read stays hanging as the stale one.
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();

      second.complete(
        const DispenserDealt(
          _testCard,
          stripResident: StripResident.quarantineFollowUp,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text(strings.quarantineFollowUpCopy), findsOneWidget);

      // The ✕: its handler bumps the generation and resolves through
      // the controllable dismissal.
      await tester.ensureVisible(
        find.bySemanticsLabel(strings.ambientStripDismiss),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.bySemanticsLabel(strings.ambientStripDismiss));
      await tester.pump();
      controller.dismissal.complete(const DispenserDealt(_testCard));
      await tester.pumpAndSettle();
      expect(find.text(strings.quarantineFollowUpCopy), findsNothing);

      // The stale launch read completes last, carrying the follow-up —
      // its generation no longer matches, so it must not commit.
      first.complete(
        const DispenserDealt(
          _testCard,
          stripResident: StripResident.quarantineFollowUp,
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.text(strings.quarantineFollowUpCopy),
        findsNothing,
        reason:
            'a read from before the dismissal cannot resurrect the '
            'follow-up — the generation bump refuses its commit',
      );
      expect(find.byType(TaskCard), findsOneWidget);
    });

    testWidgets('a newer refresh wins when the follow-up dismissal '
        'succeeds later', (tester) async {
      final first = Completer<DispenserView>();
      final newerRefresh = Completer<DispenserView>();
      final controller = _QueuedDismissQuarantineFollowUpController([
        first,
        newerRefresh,
      ]);
      final strings = AppStringsEs();

      await tester.pumpWidget(_harness(controller));
      await tester.pump();
      first.complete(
        const DispenserDealt(
          _testCard,
          stripResident: StripResident.quarantineFollowUp,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.bySemanticsLabel(strings.ambientStripDismiss));
      await tester.pump();

      // The foreground refresh starts after the tap generation and wins
      // before the held dismissal resolves.
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      newerRefresh.complete(const DispenserClosed());
      await tester.pumpAndSettle();
      expect(find.text(strings.poolExhaustedClose), findsOneWidget);

      controller.dismissal.complete(
        const DispenserDealt(
          _testCard,
          stripResident: StripResident.quarantineFollowUp,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text(strings.poolExhaustedClose), findsOneWidget);
      expect(find.text(strings.quarantineFollowUpCopy), findsNothing);
    });

    testWidgets('200% font scale: the follow-up sentence and ✕ keep '
        'their floors without overflow (UX-DR45, NFR6)', (tester) async {
      tester.platformDispatcher.textScaleFactorTestValue = 2.0;
      addTearDown(tester.platformDispatcher.clearAllTestValues);
      await tester.binding.setSurfaceSize(const ui.Size(320, 480));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await launchDueDayAndCommit(tester);
      final strings = AppStringsEs();
      final sentence = find.text(strings.quarantineFollowUpCopy);
      expect(sentence, findsOneWidget);
      expect(tester.takeException(), isNull);

      final sentenceTarget = find
          .ancestor(of: sentence, matching: find.byType(ConstrainedBox))
          .first;
      final sentenceBox = tester.renderObject<RenderBox>(sentenceTarget);
      expect(sentenceBox.size.height, greaterThanOrEqualTo(48));
      final dismissTarget = find.descendant(
        of: find.bySemanticsLabel(strings.ambientStripDismiss),
        matching: find.byType(GestureDetector),
      );
      final dismissBox = tester.renderObject<RenderBox>(dismissTarget);
      expect(dismissBox.size.width, greaterThanOrEqualTo(48));
      expect(dismissBox.size.height, greaterThanOrEqualTo(48));
      expect(tester.takeException(), isNull);
    });

    testWidgets('a failing read under the ✕ keeps the standing surface '
        'and reports the failed refresh, nothing written — '
        'and the healed foreground re-read shows the dismissal held '
        '(matrix: read failure under the dismissal)', (tester) async {
      final inner = _RecordingStore()
        ..entries.add(_installOpen())
        ..entries.add(answeredDueWeek())
        ..entries.addAll(sealedBoxPair('seed'));
      final failing = _FailReadWhileArmedStore(inner);
      await launchDueDayOver(tester, failing);
      final strings = AppStringsEs();
      expect(find.text(strings.quarantineFollowUpCopy), findsOneWidget);
      final kindsBefore = inner.entries.map((entry) => entry.kind).toList();

      failing.failReads = true;
      await tester.ensureVisible(
        find.bySemanticsLabel(strings.ambientStripDismiss),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.bySemanticsLabel(strings.ambientStripDismiss));
      await tester.pumpAndSettle();

      // The failed confirmation is visible, not a quiet blank mistaken
      // for success; the standing surface remains available to recover.
      expect(find.byType(ErrorWidget), findsNothing);
      expect(tester.takeException(), isNull);
      expect(find.text(strings.dispenserRefreshFailed), findsOneWidget);
      expect(find.byType(TaskCard), findsOneWidget);
      expect(find.text(strings.quarantineFollowUpCopy), findsOneWidget);
      expect(
        inner.entries.map((entry) => entry.kind).toList(),
        kindsBefore,
        reason: 'the failed dismissal appended nothing at all',
      );

      // The read heals and a foreground return re-reads: the
      // dismissal held — the follow-up is gone for the day, the
      // displaced check-in holds the freed slot, the card stands.
      failing.failReads = false;
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text(strings.quarantineFollowUpCopy), findsNothing);
      expect(find.text(strings.energyCheckInQuestion), findsOneWidget);
      expect(find.byType(TaskCard), findsOneWidget);
    });
  });
}

class _Noop {
  static void accept() {}
}

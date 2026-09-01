// The Dispenser surface's contract (Stories 1.8–1.10): the launch deal renders
// with the fake store + the real asset bytes + a fixed clock; the warm
// close stands when the deal is absent; a failed catalogue read leaves
// the empty frame with the memo cleared for the next read; 200% font
// scale grows into the air and scrolls with nothing truncated; and no
// loader ever precedes the first card. Story 1.9's write rows: the tap
// dispatches the light haptic, appends the answer, commits the next
// card with the ack above it for its fixed window, absorbs a failed
// write into the empty frame, and serializes a double tap into exactly
// one card_done. Story 1.10's skip rows: the secondary tap appends the
// answer and commits the next candidate with no haptic and no ack, the
// exhausted day lands on the warm close, the chunk slot stays open, a
// double skip — and a skip racing Hecho — lands exactly one row, a
// failed skip heals through the empty frame, and the 200% fold still
// carries the tap — the I/O matrix's rows, pinned.
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:core/catalogue/catalogue.dart';
import 'package:core/commands/session_commands.dart';
import 'package:core/pool/pool_fact.dart';
import 'package:core/ports/store_port.dart';
import 'package:core/settings/settings.dart';
import 'package:core/weave/weave.dart';
import 'package:flutter/material.dart' hide Card;
import 'package:flutter/rendering.dart' show RenderParagraph;
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
import 'package:organizer/ui/settings/nuevo_proyecto_screen.dart';
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

/// A store whose first `card_done` append throws — the write-failure
/// row: the controller rethrows, the screen absorbs it into the empty
/// frame, and the log stays consistent (nothing landed).
class _FailFirstDoneStore implements StorePort {
  _FailFirstDoneStore(this._inner);

  final _RecordingStore _inner;
  var _thrown = false;

  @override
  Future<void> appendPoolFact(PoolFactRecord fact) async {}

  @override
  Future<void> appendLogEntry(LogEntryRecord entry) async {
    if (!_thrown && entry.kind == 'card_done') {
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

/// A store whose first `card_skipped` append throws — the skip's
/// write-failure row: the controller rethrows, the screen absorbs it
/// into the empty frame, and the log stays consistent (nothing landed).
class _FailFirstSkippedStore implements StorePort {
  _FailFirstSkippedStore(this._inner);

  final _RecordingStore _inner;
  var _thrown = false;

  @override
  Future<void> appendPoolFact(PoolFactRecord fact) async {}

  @override
  Future<void> appendLogEntry(LogEntryRecord entry) async {
    if (!_thrown && entry.kind == 'card_skipped') {
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

/// A store whose log reads fail exactly once, and only once a
/// `card_done` has landed — the post-write refresh's read fails while
/// the write itself succeeded (the transient the foreground heal
/// covers).
class _FailReadAfterDoneStore implements StorePort {
  _FailReadAfterDoneStore(this._inner);

  final _RecordingStore _inner;
  var _thrown = false;

  @override
  Future<void> appendPoolFact(PoolFactRecord fact) async {}

  @override
  Future<void> appendLogEntry(LogEntryRecord entry) async =>
      _inner.appendLogEntry(entry);

  @override
  Future<List<PoolFactRecord>> readPoolFacts() async => const [];

  @override
  Future<List<LogEntryRecord>> readLogEntries() async {
    final hasDone = _inner.entries.any((entry) => entry.kind == 'card_done');
    if (hasDone && !_thrown) {
      _thrown = true;
      throw StateError('read failed');
    }
    return _inner.readLogEntries();
  }
}

/// A store whose bundled `card_dealt` appends park behind a gate once a
/// given answer kind has landed — an answer batch (a completion by
/// default, a skip via [answerKind]) held half-written so a second tap
/// lands while the write is genuinely in flight.
class _GatedBundledDealStore implements StorePort {
  _GatedBundledDealStore(
    this._inner,
    this._gate, {
    this.answerKind = 'card_done',
  });

  final _RecordingStore _inner;
  final Future<void> _gate;

  /// The answer kind that arms the gate: a completion by default, a
  /// skip for Story 1.10's in-flight rows.
  final String answerKind;
  var _seenAnswer = false;

  @override
  Future<void> appendPoolFact(PoolFactRecord fact) async {}

  @override
  Future<void> appendLogEntry(LogEntryRecord entry) async {
    if (entry.kind == answerKind) {
      _seenAnswer = true;
    }
    if (_seenAnswer && entry.kind == 'card_dealt') {
      await _gate;
    }
    await _inner.appendLogEntry(entry);
  }

  @override
  Future<List<PoolFactRecord>> readPoolFacts() async => const [];

  @override
  Future<List<LogEntryRecord>> readLogEntries() async =>
      _inner.readLogEntries();
}

/// A store whose next append after [failNextAppend] is set throws once
/// — the declare's write-failure row at the surface: the batch's first
/// row fails, nothing lands, and the quiet empty frame is the whole
/// story.
class _FailNextAppendStore implements StorePort {
  _FailNextAppendStore(this._inner);

  final _RecordingStore _inner;
  var failNextAppend = false;

  @override
  Future<void> appendPoolFact(PoolFactRecord fact) async {}

  @override
  Future<void> appendLogEntry(LogEntryRecord entry) async {
    if (failNextAppend) {
      failNextAppend = false;
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

/// Holds the session catalogue load open so the screen can prove it waits for
/// the persisted launch deal rather than deriving a competing first card.
class _GatedBundle extends _FakeBundle {
  _GatedBundle(super.sources, this._gate);

  final Future<void> _gate;

  @override
  Future<String> loadString(String key, {bool cache = true}) async {
    await _gate;
    return super.loadString(key, cache: cache);
  }
}

class _QueuedReadController extends DispenserController {
  _QueuedReadController(this._reads, {super.bundle})
    : super(store: _RecordingStore(), strings: AppStringsEs());

  final List<Completer<DispenserView>> _reads;
  var _nextRead = 0;

  @override
  Future<DispenserView> read() => _reads[_nextRead++].future;
}

/// A queued reader whose answers succeed immediately: it isolates the
/// screen's in-flight guard from the controller's persistence mechanics.
class _QueuedAnswerController extends _QueuedReadController {
  _QueuedAnswerController(super.reads);

  @override
  Future<void> complete(DispenserDealt dealt) async {}

  @override
  Future<void> skip(DispenserDealt dealt) async {}
}

/// A queued reader whose pause resolves from a held completer: it
/// isolates the screen's generation guard from the controller's
/// persistence mechanics — the ack-generation pattern, on the stop.
class _QueuedPauseController extends _QueuedReadController {
  _QueuedPauseController(super.reads);

  final Completer<DispenserView> pauseView = Completer<DispenserView>();

  @override
  Future<DispenserView> pause() => pauseView.future;
}

/// A queued reader whose extension resolves from a held completer: the
/// pause's generation-guard pattern, on the checkpoint's continue
/// (Story 2.4).
class _QueuedExtendController extends _QueuedReadController {
  _QueuedExtendController(super.reads);

  final Completer<DispenserView> extendView = Completer<DispenserView>();

  @override
  Future<DispenserView> extend() => extendView.future;
}

/// A store whose `card_done` appends fail once, and only once an
/// earlier one has landed — the second-completion write-failure shape:
/// a first ack is mid-window and visible when the failed write's catch
/// must clear the ack-flag class.
class _FailLaterDoneStore implements StorePort {
  _FailLaterDoneStore(this._inner);

  final _RecordingStore _inner;
  var _landedDones = 0;
  var _thrown = false;

  @override
  Future<void> appendPoolFact(PoolFactRecord fact) async {}

  @override
  Future<void> appendLogEntry(LogEntryRecord entry) async {
    if (entry.kind == 'card_done') {
      if (_landedDones > 0 && !_thrown) {
        _thrown = true;
        throw StateError('append failed');
      }
      _landedDones++;
    }
    await _inner.appendLogEntry(entry);
  }

  @override
  Future<List<PoolFactRecord>> readPoolFacts() async => const [];

  @override
  Future<List<LogEntryRecord>> readLogEntries() async =>
      _inner.readLogEntries();
}

const _testCard = Card(
  id: 'prueba',
  size: Size.focus,
  name: 'Tarjeta de prueba',
  origin: Origin.shipped,
  zone: Zone.z1,
  estimateSeconds: 900,
);

const _longCard = Card(
  id: 'prueba-larga',
  size: Size.focus,
  name: 'Despeja la estantería alta del salón y ordena los libros sueltos',
  origin: Origin.shipped,
  zone: Zone.z5,
  estimateSeconds: 900,
);

DateTime _fixedClock() => DateTime.utc(2026, 8, 29, 12);

Rect _rect(WidgetTester tester, Finder finder) {
  final box = tester.renderObject<RenderBox>(finder);
  return box.localToGlobal(Offset.zero) & box.size;
}

/// The committed deal's visible surface, task text excluded: the whole
/// widget tree's runtime types with counts, plus every text-bearing
/// channel — `Text.data`, `RichText` plain text (a `Text.rich` apology
/// cannot slip through), tooltip messages, semantics labels,
/// editable values and icon codePoints. Any gap-shaped element — a
/// badge, a count, an apology, an icon — surfaces here as a difference
/// from a control launch.
List<String> _censusOf(WidgetTester tester, List<String> excludedTexts) {
  final typeCounts = <String, int>{};
  for (final widget in tester.allWidgets) {
    final name = widget.runtimeType.toString();
    typeCounts[name] = (typeCounts[name] ?? 0) + 1;
  }
  final census = [
    for (final name in typeCounts.keys.toList()..sort())
      '$name x${typeCounts[name]}',
  ];
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
    for (final semantics in tester.widgetList<Semantics>(
      find.byType(Semantics),
    ))
      semantics.properties.tooltip,
    for (final semantics in tester.widgetList<Semantics>(
      find.byType(Semantics),
    ))
      semantics.properties.hint,
    for (final semantics in tester.widgetList<Semantics>(
      find.byType(Semantics),
    ))
      semantics.properties.value,
    for (final semantics in tester.widgetList<Semantics>(
      find.byType(Semantics),
    ))
      semantics.properties.increasedValue,
    for (final semantics in tester.widgetList<Semantics>(
      find.byType(Semantics),
    ))
      semantics.properties.decreasedValue,
    for (final editable in tester.widgetList<EditableText>(
      find.byType(EditableText),
    ))
      editable.controller.text,
    for (final icon in tester.widgetList<Icon>(find.byType(Icon)))
      if (icon.icon != null) 'icon:${icon.icon!.codePoint}',
  ];
  return [
    ...census,
    for (final value in texts)
      if (value != null && value.isNotEmpty && !excludedTexts.contains(value))
        value,
  ];
}

/// Records platform-channel traffic through a mock handler on
/// `SystemChannels.platform`, so the light haptic's dispatch is observable
/// (the story's pin: `HapticFeedback.lightImpact` fires immediately).
List<MethodCall> _mockPlatformCalls(WidgetTester tester) {
  final calls = <MethodCall>[];
  tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
    SystemChannels.platform,
    (call) async {
      calls.add(call);
      return null;
    },
  );
  return calls;
}

List<MethodCall> _lightImpacts(List<MethodCall> calls) => calls
    .where(
      (call) =>
          call.method == 'HapticFeedback.vibrate' &&
          call.arguments == 'HapticFeedbackType.lightImpact',
    )
    .toList();

/// Every haptic dispatch of any type — the skip's no-feedback pin is
/// type-agnostic: a medium, heavy or selection haptic regression must
/// fail it just as the light one would.
List<MethodCall> _hapticImpacts(List<MethodCall> calls) =>
    calls.where((call) => call.method == 'HapticFeedback.vibrate').toList();

Widget _harness(
  DispenserController controller, {
  Future<void> Function()? sessionSettled,

  /// Distinct keys are required whenever two harnesses are pumped in
  /// one test: a second pump at the same tree position silently
  /// reuses the first screen's element and committed view (State
  /// survives, no fresh read runs).
  Key? screenKey,
}) => MaterialApp(
  theme: OrganizerTheme.light(),
  localizationsDelegates: AppStrings.localizationsDelegates,
  supportedLocales: AppStrings.supportedLocales,
  home: DispenserScreen(
    key: screenKey,
    controller: controller,
    sessionSettled: sessionSettled,
  ),
);

void main() {
  final shipped = File(catalogueAssetPath).readAsStringSync();

  DispenserController buildController(StorePort store, {AssetBundle? bundle}) =>
      DispenserController(
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

  LogEntryRecord? latestDealtEntryOf(_RecordingStore store) {
    for (final entry in store.entries.reversed) {
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
    // The stop stands in the footer band on the dealt view too — never
    // disabled, never suggested (Story 2.3, UX-DR43).
    expect(find.text('Quiero parar'), findsOneWidget);

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

  testWidgets('the first read waits for the launch lifecycle, then renders '
      'the persisted deal rather than a competing choice', (tester) async {
    final store = _RecordingStore();
    final gate = Completer<void>();
    final session = SessionController(
      store: store,
      strings: AppStringsEs(),
      bundle: _GatedBundle({catalogueAssetPath: shipped}, gate.future),
      nowOf: _fixedClock,
    );
    final opening = session.handleAppOpen();

    await tester.pumpWidget(
      _harness(buildController(store), sessionSettled: () => session.settled),
    );
    await tester.pump();
    expect(find.byType(TaskCard), findsNothing);

    gate.complete();
    await opening;
    await tester.pumpAndSettle();

    final dealtEntryId = dealtEntryOf(store)!.itemId!;
    final catalogue = await loadEvergreenCatalogue(
      AppStringsEs(),
      bundle: _FakeBundle({catalogueAssetPath: shipped}),
    );
    final dealt = catalogue.entries.firstWhere(
      (entry) => entry.id == dealtEntryId,
    );
    expect(find.text(dealt.name), findsOneWidget);
  });

  testWidgets('a failed session launch keeps the Dispenser empty even when '
      'its independent catalogue read could succeed', (tester) async {
    final store = _RecordingStore();
    final session = SessionController(
      store: store,
      strings: AppStringsEs(),
      bundle: _FlakyBundle(shipped),
      nowOf: _fixedClock,
    );
    final opening = session.handleAppOpen();

    await tester.pumpWidget(
      _harness(buildController(store), sessionSettled: () => session.settled),
    );
    await expectLater(opening, throwsA(isA<Exception>()));
    await tester.pumpAndSettle();

    expect(find.byType(TaskCard), findsNothing);
    expect(find.byType(ErrorWidget), findsNothing);
  });

  testWidgets('a real resume waits for the persisted resumed-session deal', (
    tester,
  ) async {
    final store = _RecordingStore();
    // A ticking clock: backgrounding and resuming mint distinct instants,
    // as production always does — under the frozen clock the close and
    // the reopen would collapse onto one instant and read as a supersede
    // pair, which no real background→resume can produce.
    var minute = 0;
    final session = installSessionController(
      store: store,
      strings: AppStringsEs(),
      bundle: _FakeBundle({catalogueAssetPath: shipped}),
      nowOf: () => DateTime.utc(2026, 8, 29, 12, minute++),
    );
    addTearDown(() => tester.binding.removeObserver(session));
    await session.settled;

    await tester.pumpWidget(
      _harness(buildController(store), sessionSettled: () => session.settled),
    );
    await tester.pumpAndSettle();

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pumpAndSettle();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();

    final resumedDeal = latestDealtEntryOf(store)!;
    final catalogue = await loadEvergreenCatalogue(
      AppStringsEs(),
      bundle: _FakeBundle({catalogueAssetPath: shipped}),
    );
    final entry = catalogue.entries.firstWhere(
      (candidate) => candidate.id == resumedDeal.itemId,
    );
    expect(find.text(entry.name), findsOneWidget);
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
    // The stop stands on the closed view as on the dealt one — one tap,
    // any moment, any reason (Story 2.3, UX-DR43).
    expect(find.text('Quiero parar'), findsOneWidget);
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
    await tester.binding.setSurfaceSize(const ui.Size(320, 480));
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

  testWidgets('200% font scale keeps a long zoned card scrollable and its '
      'footer reachable', (tester) async {
    tester.platformDispatcher.textScaleFactorTestValue = 2.0;
    addTearDown(tester.platformDispatcher.clearAllTestValues);
    await tester.binding.setSurfaceSize(const ui.Size(320, 480));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final first = Completer<DispenserView>();
    await tester.pumpWidget(_harness(_QueuedReadController([first])));
    first.complete(const DispenserDealt(_longCard));
    await tester.pumpAndSettle();

    final scrollable = tester.state<ScrollableState>(find.byType(Scrollable));
    expect(scrollable.position.maxScrollExtent, greaterThan(0));
    await tester.scrollUntilVisible(
      find.text(AppStringsEs().zoneZ5),
      200,
      scrollable: find.byType(Scrollable),
    );
    expect(find.text(AppStringsEs().zoneZ5), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the card caps at its width bound on wide grounds — the '
      'side margins and max-width constraint hold', (tester) async {
    await tester.binding.setSurfaceSize(const ui.Size(800, 600));
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

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();

    expect(find.byType(TaskCard), findsOneWidget);
    expect(find.text('Hecho'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a newer refresh wins when an earlier read completes last', (
    tester,
  ) async {
    final first = Completer<DispenserView>();
    final second = Completer<DispenserView>();
    final controller = _QueuedReadController([first, second]);

    await tester.pumpWidget(_harness(controller));
    await tester.pump();

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    second.complete(const DispenserClosed());
    await tester.pumpAndSettle();
    expect(find.text(AppStringsEs().poolExhaustedClose), findsOneWidget);

    first.complete(const DispenserDealt(_testCard));
    await tester.pumpAndSettle();
    expect(find.text(AppStringsEs().poolExhaustedClose), findsOneWidget);
    expect(find.byType(TaskCard), findsNothing);
  });

  testWidgets('a failed refresh clears an already rendered card to the empty '
      'frame', (tester) async {
    final first = Completer<DispenserView>();
    final second = Completer<DispenserView>();
    final controller = _QueuedReadController([first, second]);

    await tester.pumpWidget(_harness(controller));
    await tester.pump();
    first.complete(const DispenserDealt(_testCard));
    await tester.pumpAndSettle();
    expect(find.byType(TaskCard), findsOneWidget);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(find.byType(TaskCard), findsNothing);
    second.completeError(StateError('read failed'));
    await tester.pumpAndSettle();
    expect(find.byType(TaskCard), findsNothing);
    expect(find.byType(ErrorWidget), findsNothing);
  });

  test(
    'a failed catalogue read leaves the empty frame standing and clears '
    'the memo — the next read retries (the session controller\'s pattern)',
    () async {
      final store = _RecordingStore()
        // The sitting stands open with its dealt card: the retry read
        // resolves the dealt-unanswered card (deals exist only inside
        // sittings, Story 2.3).
        ..entries.addAll([
          (
            id: 'seed-open',
            kind: 'session_started',
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
            settingKey: null,
            settingValue: null,
            pocketMinutes: null,
            energyLevel: null,
            reportValue: null,
            reportWeek: null,
          ),
          (
            id: 'seed-deal',
            kind: 'card_dealt',
            instantUtcMicros: DateTime.utc(
              2026,
              8,
              29,
              11,
              0,
              1,
            ).microsecondsSinceEpoch,
            offsetSeconds: 0,
            itemId: 'pasar-la-aspiradora-a-la-cocina',
            itemOrigin: Origin.shipped,
            stack: null,
            settingKey: null,
            settingValue: null,
            pocketMinutes: null,
            energyLevel: null,
            reportValue: null,
            reportWeek: null,
          ),
        ]);
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

  /// The card's own unsplit secondary — the skip control inside the
  /// TaskCard, distinct from the bottom footer's `Nuevo proyecto`
  /// affordance (Story 2.1) since both share the SecondaryTextAction
  /// grammar.
  final cardSecondaryFinder = find.descendant(
    of: find.byType(TaskCard),
    matching: find.byType(SecondaryTextAction),
  );

  /// The shared Story 1.9 harness: a launched session over the shipped
  /// catalogue, the screen committed on the launch deal, ready to tap.
  Future<void> launchAndCommit(WidgetTester tester, StorePort store) async {
    await SessionController(
      store: store,
      strings: AppStringsEs(),
      bundle: _FakeBundle({catalogueAssetPath: shipped}),
      nowOf: _fixedClock,
    ).handleAppOpen();
    await tester.pumpWidget(_harness(buildController(store)));
    await tester.pumpAndSettle();
    expect(find.byType(TaskCard), findsOneWidget);
  }

  testWidgets('tapping Hecho dispatches the light haptic, records the '
      'answer, and commits the next card with the ack above it (FR-2, '
      'NFR5/6, UX-DR38/39/51)', (tester) async {
    final store = _RecordingStore();
    await launchAndCommit(tester, store);
    final firstDealtId = dealtEntryOf(store)!.itemId!;
    final calls = _mockPlatformCalls(tester);

    await tester.tap(find.byType(HechoButton));
    await tester.pumpAndSettle();

    // Exactly one card_done, with the bundled next deal beside it.
    expect(
      store.entries.where((entry) => entry.kind == 'card_done'),
      hasLength(1),
    );
    final nextDealt = latestDealtEntryOf(store)!;
    expect(nextDealt.itemId, isNot(firstDealtId));

    // The light haptic dispatched — and never alone: the visible ack
    // below is the completion signal's other half.
    expect(_lightImpacts(calls), hasLength(1));

    // The next card is already there; the completed card exited the
    // tree entirely — toward no counter, pile or badge.
    final catalogue = await loadEvergreenCatalogue(
      AppStringsEs(),
      bundle: _FakeBundle({catalogueAssetPath: shipped}),
    );
    final first = catalogue.entries.firstWhere(
      (entry) => entry.id == firstDealtId,
    );
    final next = catalogue.entries.firstWhere(
      (entry) => entry.id == nextDealt.itemId,
    );
    expect(find.text(first.name), findsNothing);
    expect(find.text(next.name), findsOneWidget);
    expect(find.byType(TaskCard), findsOneWidget);

    // The ack: the shipped string, the quiet support register, centered,
    // above the committed view — never modal, never a glyph.
    final ack = find.text('¡Buen trabajo!');
    expect(ack, findsOneWidget);
    final ackStyle = tester.widget<Text>(ack).style!;
    expect(ackStyle.fontSize, 13);
    expect(ackStyle.color, FieldPalette.inkSecondary);
    expect(ackStyle.fontFamily, FontFamilies.lexend);
    expect(
      _rect(tester, ack).bottom,
      lessThan(_rect(tester, find.byType(TaskCard)).top),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('the ack closes after its fixed 2000 ms window — plain '
      'removal, nothing else on the surface changes', (tester) async {
    final store = _RecordingStore();
    await launchAndCommit(tester, store);
    _mockPlatformCalls(tester);

    await tester.tap(find.byType(HechoButton));
    await tester.pumpAndSettle();
    expect(find.text('¡Buen trabajo!'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 2000));
    await tester.pumpAndSettle();

    expect(find.text('¡Buen trabajo!'), findsNothing);
    expect(find.byType(TaskCard), findsOneWidget);
    expect(find.byType(ErrorWidget), findsNothing);
  });

  testWidgets('the ack window\'s timer is cancelled on dispose', (
    tester,
  ) async {
    final store = _RecordingStore();
    await launchAndCommit(tester, store);
    _mockPlatformCalls(tester);

    await tester.tap(find.byType(HechoButton));
    await tester.pumpAndSettle();
    expect(find.text('¡Buen trabajo!'), findsOneWidget);

    // Disposing mid-window cancels the timer — the test then ends with
    // no pending timer and no setState on the disposed state.
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('a failed write leaves the empty frame standing with no ack '
      '— quiet, deliberate, no crash surfaced — and a healed retry still '
      'completes: the in-flight guard released', (tester) async {
    final inner = _RecordingStore();
    final store = _FailFirstDoneStore(inner);
    await launchAndCommit(tester, store);
    final calls = _mockPlatformCalls(tester);

    await tester.tap(find.byType(HechoButton));
    await tester.pumpAndSettle();

    expect(find.byType(TaskCard), findsNothing);
    expect(find.text('¡Buen trabajo!'), findsNothing);
    expect(find.byType(ErrorWidget), findsNothing);
    expect(
      inner.entries.where((entry) => entry.kind == 'card_done'),
      isEmpty,
      reason: 'the log stayed consistent: nothing landed on the failed write',
    );

    // The foreground heal re-reads: the launch deal is still unanswered
    // (nothing landed), so the same card returns.
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pumpAndSettle();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(find.byType(TaskCard), findsOneWidget);

    // The guard's finally released the write: Hecho is not bricked. The
    // retried completion lands — the store already spent its one
    // failure — and its ack rides the next card as any completion's.
    await tester.tap(find.byType(HechoButton));
    await tester.pumpAndSettle();

    expect(
      inner.entries.where((entry) => entry.kind == 'card_done'),
      hasLength(1),
      reason:
          'the healed tap completed — a stuck in-flight guard would '
          'have bricked Hecho with the suite green',
    );
    expect(find.byType(TaskCard), findsOneWidget);
    expect(find.text('¡Buen trabajo!'), findsOneWidget);
    expect(
      _lightImpacts(calls),
      hasLength(2),
      reason: 'the healed tap really fired — its haptic is the witness',
    );
  });

  testWidgets('a write that fails under a visible ack clears the ack-flag '
      'class — the foreground-healed commit carries nothing stale', (
    tester,
  ) async {
    final inner = _RecordingStore();
    final store = _FailLaterDoneStore(inner);
    await launchAndCommit(tester, store);
    final calls = _mockPlatformCalls(tester);

    // Completion 1 lands: zero-duration pumps commit the read without
    // advancing the clock, so what follows stays inside the ack's
    // 2000 ms window.
    await tester.tap(find.byType(HechoButton));
    await tester.pump();
    await tester.pump();
    expect(find.byType(TaskCard), findsOneWidget);
    expect(find.text('¡Buen trabajo!'), findsOneWidget);

    // Completion 2's write fails under that visible ack: the empty
    // frame stands, and the whole ack-flag class — waiting flag, armed
    // timer, visible flag — is stale the moment the write is known to
    // have failed.
    await tester.tap(find.byType(HechoButton));
    await tester.pump();
    await tester.pump();
    expect(find.byType(TaskCard), findsNothing);
    expect(find.text('¡Buen trabajo!'), findsNothing);
    expect(
      inner.entries.where((entry) => entry.kind == 'card_done'),
      hasLength(1),
      reason: 'only the first completion landed; the second write failed',
    );

    // Still inside the first window's remains, the foreground heal
    // commits the still-unanswered card: nothing ack-shaped may ride
    // it. Deleting the catch's flag/timer clears fails exactly here —
    // the stale visible ack would render above the healed card.
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    await tester.pump();

    expect(find.byType(TaskCard), findsOneWidget);
    expect(find.text('¡Buen trabajo!'), findsNothing);
    expect(
      _lightImpacts(calls),
      hasLength(2),
      reason: 'the second tap really fired — its haptic is the witness',
    );
    await tester.pumpAndSettle();
  });

  testWidgets('a rapid double tap appends exactly one card_done — the '
      'in-flight guard returns early and the serialization guard reads the '
      'answered log', (tester) async {
    final inner = _RecordingStore();
    final gate = Completer<void>();
    final store = _GatedBundledDealStore(inner, gate.future);
    await SessionController(
      store: store,
      strings: AppStringsEs(),
      bundle: _FakeBundle({catalogueAssetPath: shipped}),
      nowOf: _fixedClock,
    ).handleAppOpen();

    await tester.pumpWidget(_harness(buildController(store)));
    await tester.pumpAndSettle();
    expect(find.byType(TaskCard), findsOneWidget);
    final calls = _mockPlatformCalls(tester);

    // The first tap's write parks behind the gate — the batch is
    // half-written, the completion genuinely in flight when the second
    // tap lands.
    await tester.tap(find.byType(HechoButton));
    await tester.pump();
    await tester.tap(find.byType(HechoButton));
    await tester.pump();

    // The in-flight guard returned the second tap early: one haptic for
    // one recorded completion, not one per tap.
    expect(_lightImpacts(calls), hasLength(1));

    gate.complete();
    await tester.pumpAndSettle();

    expect(
      inner.entries.where((entry) => entry.kind == 'card_done'),
      hasLength(1),
    );
    expect(
      inner.entries.where((entry) => entry.kind == 'card_dealt'),
      hasLength(2),
      reason: 'the launch deal plus the one bundled next deal',
    );
    expect(find.byType(TaskCard), findsOneWidget);
    expect(find.text('¡Buen trabajo!'), findsOneWidget);
  });

  testWidgets('a Hecho on the Focus Chunk closes the day\'s slot: the '
      'next view commits non-chunk, never a second 15-minute card '
      '(AD-19, AD-20)', (tester) async {
    final store = _RecordingStore();
    await launchAndCommit(tester, store);
    final firstDealtId = dealtEntryOf(store)!.itemId!;
    _mockPlatformCalls(tester);

    await tester.tap(find.byType(HechoButton));
    await tester.pumpAndSettle();

    final catalogue = await loadEvergreenCatalogue(
      AppStringsEs(),
      bundle: _FakeBundle({catalogueAssetPath: shipped}),
    );
    final first = catalogue.entries.firstWhere(
      (entry) => entry.id == firstDealtId,
    );
    final next = catalogue.entries.firstWhere(
      (entry) => entry.id == latestDealtEntryOf(store)!.itemId,
    );
    // The launch deal is the chunk; its answer closed the slot before
    // the bundled deal resolved.
    expect(first.size, Size.focus);
    expect(next.size, isNot(Size.focus));
    expect(find.text('15\u00A0min'), findsNothing);
    expect(find.byType(DurationChip), findsOneWidget);
  });

  testWidgets('the day\'s last completion commits the warm close with the '
      'ack above it', (tester) async {
    final store = _RecordingStore();
    await SessionController(
      store: store,
      strings: AppStringsEs(),
      bundle: _FakeBundle({catalogueAssetPath: shipped}),
      nowOf: _fixedClock,
    ).handleAppOpen();
    final controller = buildController(store);
    // Answer every card but the day's last through the controller's own
    // write path; the screen renders the ninth, and its Hecho closes.
    for (var i = 0; i < 8; i++) {
      final view = await controller.read();
      await controller.complete(view as DispenserDealt);
    }

    await tester.pumpWidget(_harness(controller));
    await tester.pumpAndSettle();
    expect(find.byType(TaskCard), findsOneWidget);
    _mockPlatformCalls(tester);

    await tester.tap(find.byType(HechoButton));
    await tester.pumpAndSettle();

    final close = find.text(AppStringsEs().poolExhaustedClose);
    expect(close, findsOneWidget);
    final ack = find.text('¡Buen trabajo!');
    expect(ack, findsOneWidget);
    expect(_rect(tester, ack).bottom, lessThan(_rect(tester, close).top));
    // The day's last answer bundled no next deal.
    expect(store.entries.last.kind, 'card_done');
  });

  testWidgets('200% font scale: the ack wraps inside the scroll column '
      'above the grown card — nothing truncated, the screen scrolls, the '
      'window still closes (UX-DR14, NFR6)', (tester) async {
    tester.platformDispatcher.textScaleFactorTestValue = 2.0;
    addTearDown(tester.platformDispatcher.clearAllTestValues);
    await tester.binding.setSurfaceSize(const ui.Size(320, 480));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final store = _RecordingStore();
    await launchAndCommit(tester, store);
    _mockPlatformCalls(tester);

    // The grown card pushes the button below the fold — the screen
    // scrolls to it, which is itself the 200% floor's mechanism.
    await tester.scrollUntilVisible(
      find.byType(HechoButton),
      200,
      scrollable: find.byType(Scrollable),
    );
    await tester.tap(find.byType(HechoButton));
    await tester.pumpAndSettle();

    // Growing and scrolling, never truncating: no layout exception, the
    // ack and the next card both whole inside the scroll column.
    expect(tester.takeException(), isNull);
    expect(find.text('¡Buen trabajo!'), findsOneWidget);
    expect(find.byType(SingleChildScrollView), findsOneWidget);
    final scrollable = tester.state<ScrollableState>(find.byType(Scrollable));
    expect(
      scrollable.position.maxScrollExtent,
      greaterThan(0),
      reason: 'the ack plus the grown card must outgrow the viewport',
    );
    await tester.drag(
      find.byType(SingleChildScrollView),
      const Offset(0, -240),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(scrollable.position.pixels, greaterThan(0));

    // The fixed window closes at scale too.
    await tester.pump(const Duration(milliseconds: 2000));
    await tester.pumpAndSettle();
    expect(find.text('¡Buen trabajo!'), findsNothing);
  });

  testWidgets('a completion whose post-write read fails shows no ack — and '
      'a later foreground-healed commit carries no stale ack', (tester) async {
    final inner = _RecordingStore();
    final store = _FailReadAfterDoneStore(inner);
    await SessionController(
      store: store,
      strings: AppStringsEs(),
      bundle: _FakeBundle({catalogueAssetPath: shipped}),
      nowOf: _fixedClock,
    ).handleAppOpen();
    final controller = buildController(store);

    await tester.pumpWidget(_harness(controller));
    await tester.pumpAndSettle();
    expect(find.byType(TaskCard), findsOneWidget);
    _mockPlatformCalls(tester);

    await tester.tap(find.byType(HechoButton));
    await tester.pumpAndSettle();

    // The write itself landed whole — both rows — but its refresh's read
    // failed: the empty frame stands and no ack renders for it.
    expect(
      inner.entries.where((entry) => entry.kind == 'card_done'),
      hasLength(1),
    );
    expect(
      inner.entries.where((entry) => entry.kind == 'card_dealt'),
      hasLength(2),
    );
    expect(find.byType(TaskCard), findsNothing);
    expect(find.text('¡Buen trabajo!'), findsNothing);
    expect(find.byType(ErrorWidget), findsNothing);

    // The foreground-healed commit is not the post-completion view: the
    // card returns with nothing waiting above it.
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pumpAndSettle();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();

    expect(find.byType(TaskCard), findsOneWidget);
    expect(find.text('¡Buen trabajo!'), findsNothing);
  });

  testWidgets('a stale failed read cannot drop a waiting ack — only the '
      'current generation\'s failure clears it', (tester) async {
    final first = Completer<DispenserView>();
    final second = Completer<DispenserView>();
    final third = Completer<DispenserView>();
    final controller = _QueuedReadController([
      first,
      second,
      third,
    ], bundle: _FakeBundle({catalogueAssetPath: shipped}));

    await tester.pumpWidget(_harness(controller));
    await tester.pump();
    first.complete(const DispenserDealt(_testCard));
    await tester.pumpAndSettle();
    expect(find.byType(TaskCard), findsOneWidget);
    _mockPlatformCalls(tester);

    // The completion's write resolves and arms the ack on the refresh's
    // read — generation 2, held open.
    await tester.tap(find.byType(HechoButton));
    await tester.pump();
    await tester.pump();

    // A mid-read return to the foreground supersedes it: generation 3's
    // read is now the one whose commit owes the ack.
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();

    // The superseded read fails first — a stale failure with no
    // standing to clear the waiting ack.
    second.completeError(StateError('read failed'));
    await tester.pump();
    await tester.pump();
    expect(find.byType(ErrorWidget), findsNothing);

    // Then the current generation's read commits: the ack rides it.
    // Clearing the waiting flag without a generation guard fails
    // exactly here — the current commit would find nothing waiting.
    third.complete(const DispenserDealt(_longCard));
    await tester.pumpAndSettle();

    expect(find.text(_longCard.name), findsOneWidget);
    expect(find.text('¡Buen trabajo!'), findsOneWidget);
    // Drain the ack's window before the binding's teardown invariants.
    await tester.pump(const Duration(milliseconds: 2000));
    await tester.pumpAndSettle();
    expect(find.text('¡Buen trabajo!'), findsNothing);
  });

  testWidgets('a later completion restarts the ack window — the first '
      'window\'s elapse never cuts the second one short', (tester) async {
    final store = _RecordingStore();
    await launchAndCommit(tester, store);
    _mockPlatformCalls(tester);

    // Commit 1: the window opens. Zero-duration pumps commit the read
    // without advancing the clock, so the window arithmetic below is
    // exact rather than racing pumpAndSettle's per-pump 100 ms.
    await tester.tap(find.byType(HechoButton));
    await tester.pump();
    await tester.pump();
    expect(find.text('¡Buen trabajo!'), findsOneWidget);

    // Partway into the first window (1200 ms of its 2000), the next
    // card is answered: commit 2 cancels the first timer and restarts
    // the window from itself.
    await tester.pump(const Duration(milliseconds: 1200));
    await tester.tap(find.byType(HechoButton));
    await tester.pump();
    await tester.pump();
    expect(find.text('¡Buen trabajo!'), findsOneWidget);

    // 1500 ms into the second window: past the first window's original
    // end (1200 + 1500 > 2000), short of the second's (1500 < 2000) —
    // the ack stands. Deleting the restart's timer cancellation in
    // _commitView fails exactly here: the first window's elapse would
    // have removed it 700 ms ago.
    await tester.pump(const Duration(milliseconds: 1500));
    expect(find.text('¡Buen trabajo!'), findsOneWidget);
    expect(find.byType(TaskCard), findsOneWidget);

    // Past the second window's end (1500 + 700 ≥ 2000): plain removal,
    // nothing else on the surface moves.
    await tester.pump(const Duration(milliseconds: 700));
    expect(find.text('¡Buen trabajo!'), findsNothing);
    expect(find.byType(TaskCard), findsOneWidget);
    // Let the taps' ink ripples settle before the binding's teardown
    // invariants — they advance the clock no further than assertions
    // care about.
    await tester.pumpAndSettle();
  });

  testWidgets('a stale Hecho callback cannot act while a skip refresh waits '
      'for its first frame — no haptic, no false ack', (tester) async {
    final first = Completer<DispenserView>();
    final second = Completer<DispenserView>();
    final controller = _QueuedAnswerController([first, second]);

    await tester.pumpWidget(_harness(controller));
    await tester.pump();
    first.complete(const DispenserDealt(_testCard));
    await tester.pumpAndSettle();
    expect(find.byType(TaskCard), findsOneWidget);
    final calls = _mockPlatformCalls(tester);
    final oldCard = tester.widget<TaskCard>(find.byType(TaskCard));

    // Invoke both callbacks before the scheduled refresh frame. This is the
    // old card's real render-tree window: it has been answered by skip but
    // has not yet been removed from hit testing.
    oldCard.onSkip!();
    await Future<void>.value();
    oldCard.onDone!();
    await Future<void>.value();

    expect(
      _hapticImpacts(calls),
      isEmpty,
      reason: 'the stale Hecho returns through the shared guard',
    );

    second.complete(const DispenserDealt(_longCard));
    await tester.pump();
    await tester.pump();
    expect(find.text(_longCard.name), findsOneWidget);
    expect(find.text('¡Buen trabajo!'), findsNothing);
  });

  testWidgets('tapping the secondary skips with no haptic and no ack — '
      'the answer records once and the next candidate commits (FR-3, '
      'Story 1.10)', (tester) async {
    final store = _RecordingStore();
    await launchAndCommit(tester, store);
    final firstDealtId = dealtEntryOf(store)!.itemId!;
    final calls = _mockPlatformCalls(tester);

    await tester.tap(cardSecondaryFinder);
    await tester.pumpAndSettle();

    // Exactly one card_skipped, naming the dealt card, with the bundled
    // next deal beside it.
    expect(
      store.entries.where((entry) => entry.kind == 'card_skipped'),
      hasLength(1),
    );
    final skipped = store.entries.lastWhere(
      (entry) => entry.kind == 'card_skipped',
    );
    expect(skipped.itemId, firstDealtId);
    final nextDealt = latestDealtEntryOf(store)!;
    expect(nextDealt.itemId, isNot(firstDealtId));

    // The different card *is* the answer: it is on screen already, and
    // no feedback of any kind preceded it — no haptic, no ack.
    final catalogue = await loadEvergreenCatalogue(
      AppStringsEs(),
      bundle: _FakeBundle({catalogueAssetPath: shipped}),
    );
    final next = catalogue.entries.firstWhere(
      (entry) => entry.id == nextDealt.itemId,
    );
    expect(find.text(next.name), findsOneWidget);
    expect(find.byType(TaskCard), findsOneWidget);
    expect(_hapticImpacts(calls), isEmpty);
    expect(find.text('¡Buen trabajo!'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('skipping the Focus Chunk leaves the day\'s slot open: a '
      'different candidate commits and the day\'s chunk remains available '
      '(AD-20)', (tester) async {
    final store = _RecordingStore();
    await launchAndCommit(tester, store);
    final firstDealtId = dealtEntryOf(store)!.itemId!;
    final calls = _mockPlatformCalls(tester);

    await tester.tap(cardSecondaryFinder);
    await tester.pumpAndSettle();

    final catalogue = await loadEvergreenCatalogue(
      AppStringsEs(),
      bundle: _FakeBundle({catalogueAssetPath: shipped}),
    );
    final first = catalogue.entries.firstWhere(
      (entry) => entry.id == firstDealtId,
    );
    final next = catalogue.entries.firstWhere(
      (entry) => entry.id == latestDealtEntryOf(store)!.itemId,
    );
    // The launch deal is the chunk; the skip consumed nothing — no
    // completion happened, so the slot no card_done closed stays open.
    expect(first.size, Size.focus);
    expect(
      store.entries.where((entry) => entry.kind == 'card_done'),
      isEmpty,
      reason: 'a skip consumes nothing: only a card_done closes the slot',
    );
    // Identity re-resolves on the deal (AD-20): re-ranked, never
    // excluded — with another zone candidate the deal differs, and
    // because the slot stays open the re-dealt candidate is chunk-classed
    // again (the core's own pin: a skipped chunk re-resolves identity and
    // leaves the slot open — the day's chunk remains available, never
    // silently lost to a skip).
    expect(next.id, isNot(first.id));
    expect(next.size, Size.focus);
    expect(find.text('15\u00A0min'), findsOneWidget);
    expect(find.byType(DurationChip), findsOneWidget);
    expect(find.text(first.name), findsNothing);
    expect(_hapticImpacts(calls), isEmpty);
  });

  testWidgets('skipping the day\'s last candidate lands on the warm close '
      '— only the answer row appended, never an error, never an ack', (
    tester,
  ) async {
    final store = _RecordingStore();
    await SessionController(
      store: store,
      strings: AppStringsEs(),
      bundle: _FakeBundle({catalogueAssetPath: shipped}),
      nowOf: _fixedClock,
    ).handleAppOpen();
    final controller = buildController(store);
    // The screen renders the ninth card; its secondary closes the day.
    for (var i = 0; i < 8; i++) {
      final view = await controller.read();
      await controller.complete(view as DispenserDealt);
    }

    await tester.pumpWidget(_harness(controller));
    await tester.pumpAndSettle();
    expect(find.byType(TaskCard), findsOneWidget);
    final calls = _mockPlatformCalls(tester);

    await tester.tap(cardSecondaryFinder);
    await tester.pumpAndSettle();

    // The already-shipped warm close: no new close path, no error.
    expect(find.text(AppStringsEs().poolExhaustedClose), findsOneWidget);
    expect(find.byType(TaskCard), findsNothing);
    expect(find.byType(ErrorWidget), findsNothing);
    expect(find.text('¡Buen trabajo!'), findsNothing);
    expect(
      store.entries.where((entry) => entry.kind == 'card_skipped'),
      hasLength(1),
    );
    expect(store.entries.last.kind, 'card_skipped');
    expect(_hapticImpacts(calls), isEmpty);
  });

  testWidgets('a rapid double skip appends exactly one card_skipped — the '
      'in-flight guard returns early and the serialization guard reads the '
      'answered log', (tester) async {
    final inner = _RecordingStore();
    final gate = Completer<void>();
    final store = _GatedBundledDealStore(
      inner,
      gate.future,
      answerKind: 'card_skipped',
    );
    await SessionController(
      store: store,
      strings: AppStringsEs(),
      bundle: _FakeBundle({catalogueAssetPath: shipped}),
      nowOf: _fixedClock,
    ).handleAppOpen();

    await tester.pumpWidget(_harness(buildController(store)));
    await tester.pumpAndSettle();
    expect(find.byType(TaskCard), findsOneWidget);
    final calls = _mockPlatformCalls(tester);

    // The first skip's write parks behind the gate — the batch is
    // half-written, the skip genuinely in flight when the second tap
    // lands.
    await tester.tap(cardSecondaryFinder);
    await tester.pump();
    await tester.tap(cardSecondaryFinder);
    await tester.pump();

    gate.complete();
    await tester.pumpAndSettle();

    expect(
      inner.entries.where((entry) => entry.kind == 'card_skipped'),
      hasLength(1),
    );
    expect(
      inner.entries.where((entry) => entry.kind == 'card_dealt'),
      hasLength(2),
      reason: 'the launch deal plus the one bundled next deal',
    );
    expect(find.byType(TaskCard), findsOneWidget);
    expect(find.text('¡Buen trabajo!'), findsNothing);
    expect(_hapticImpacts(calls), isEmpty);
  });

  testWidgets('a skip racing a Hecho appends exactly one answer row — the '
      'shared in-flight guard serializes the surface in either order', (
    tester,
  ) async {
    // Skip first, Hecho second: the skip lands, the Hecho appends
    // nothing and fired no haptic (the guard returns before one would).
    final skipFirst = _RecordingStore();
    final skipGate = Completer<void>();
    final skipStore = _GatedBundledDealStore(
      skipFirst,
      skipGate.future,
      answerKind: 'card_skipped',
    );
    await SessionController(
      store: skipStore,
      strings: AppStringsEs(),
      bundle: _FakeBundle({catalogueAssetPath: shipped}),
      nowOf: _fixedClock,
    ).handleAppOpen();
    await tester.pumpWidget(_harness(buildController(skipStore)));
    await tester.pumpAndSettle();
    var calls = _mockPlatformCalls(tester);

    await tester.tap(cardSecondaryFinder);
    await tester.pump();
    await tester.tap(find.byType(HechoButton));
    await tester.pump();

    skipGate.complete();
    await tester.pumpAndSettle();

    expect(
      skipFirst.entries.where((entry) => entry.kind == 'card_skipped'),
      hasLength(1),
    );
    expect(
      skipFirst.entries.where((entry) => entry.kind == 'card_done'),
      isEmpty,
    );
    expect(find.text('¡Buen trabajo!'), findsNothing);
    expect(_hapticImpacts(calls), isEmpty);

    // Hecho first, skip second: the completion lands and its ack rides
    // the next card; the skip appends nothing.
    await tester.pumpWidget(const SizedBox.shrink());
    final doneFirst = _RecordingStore();
    final doneGate = Completer<void>();
    final doneStore = _GatedBundledDealStore(doneFirst, doneGate.future);
    await SessionController(
      store: doneStore,
      strings: AppStringsEs(),
      bundle: _FakeBundle({catalogueAssetPath: shipped}),
      nowOf: _fixedClock,
    ).handleAppOpen();
    await tester.pumpWidget(_harness(buildController(doneStore)));
    await tester.pumpAndSettle();
    calls = _mockPlatformCalls(tester);

    await tester.tap(find.byType(HechoButton));
    await tester.pump();
    await tester.tap(cardSecondaryFinder);
    await tester.pump();

    doneGate.complete();
    await tester.pumpAndSettle();

    expect(
      doneFirst.entries.where((entry) => entry.kind == 'card_done'),
      hasLength(1),
    );
    expect(
      doneFirst.entries.where((entry) => entry.kind == 'card_skipped'),
      isEmpty,
    );
    expect(find.text('¡Buen trabajo!'), findsOneWidget);
    expect(find.byType(TaskCard), findsOneWidget);
    // Exactly one haptic of any type — the Hecho's light impact; the
    // early-returned skip contributed none.
    expect(_hapticImpacts(calls), hasLength(1));
  });

  testWidgets('a failed skip leaves the empty frame standing — quiet, no '
      'haptic, no ack, nothing surfaced — and the healed retry skips', (
    tester,
  ) async {
    final inner = _RecordingStore();
    final store = _FailFirstSkippedStore(inner);
    await launchAndCommit(tester, store);
    final calls = _mockPlatformCalls(tester);

    await tester.tap(cardSecondaryFinder);
    await tester.pumpAndSettle();

    expect(find.byType(TaskCard), findsNothing);
    expect(find.text('¡Buen trabajo!'), findsNothing);
    expect(find.byType(ErrorWidget), findsNothing);
    expect(_hapticImpacts(calls), isEmpty);
    expect(
      inner.entries.where((entry) => entry.kind == 'card_skipped'),
      isEmpty,
      reason: 'the log stayed consistent: nothing landed on the failed write',
    );

    // The foreground heal re-reads: the launch deal is still unanswered
    // (nothing landed), so the same card returns.
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pumpAndSettle();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(find.byType(TaskCard), findsOneWidget);

    // The guard's finally released the write: the secondary is not
    // bricked. The retried skip lands — the store already spent its one
    // failure — and the different card commits, still feedback-free.
    await tester.tap(cardSecondaryFinder);
    await tester.pumpAndSettle();

    expect(
      inner.entries.where((entry) => entry.kind == 'card_skipped'),
      hasLength(1),
      reason:
          'the healed tap skipped — a stuck in-flight guard would '
          'have bricked the secondary with the suite green',
    );
    expect(find.byType(TaskCard), findsOneWidget);
    expect(find.text('¡Buen trabajo!'), findsNothing);
    expect(_hapticImpacts(calls), isEmpty);
  });

  testWidgets('200% font scale: the skip still reaches its tap — the '
      'string whole or folded, never truncated — and the alternative '
      'commits (UX-DR14, NFR6)', (tester) async {
    tester.platformDispatcher.textScaleFactorTestValue = 2.0;
    addTearDown(tester.platformDispatcher.clearAllTestValues);
    await tester.binding.setSurfaceSize(const ui.Size(320, 480));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final store = _RecordingStore();
    await launchAndCommit(tester, store);
    final calls = _mockPlatformCalls(tester);

    // The grown card pushes the control below the fold — the screen
    // scrolls to it, which is itself the 200% floor's mechanism.
    await tester.scrollUntilVisible(
      cardSecondaryFinder,
      200,
      scrollable: find.byType(Scrollable),
    );
    await tester.tap(cardSecondaryFinder);
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(
      store.entries.where((entry) => entry.kind == 'card_skipped'),
      hasLength(1),
    );
    // The next candidate is on screen, and its control is still the
    // one-piece string — whole or folded, never split into pieces.
    final catalogue = await loadEvergreenCatalogue(
      AppStringsEs(),
      bundle: _FakeBundle({catalogueAssetPath: shipped}),
    );
    final next = catalogue.entries.firstWhere(
      (entry) => entry.id == latestDealtEntryOf(store)!.itemId,
    );
    expect(find.text(next.name), findsOneWidget);
    expect(find.text('Otra más fácil / Ahora no'), findsOneWidget);
    expect(_hapticImpacts(calls), isEmpty);
  });

  testWidgets('a skip under a visible completion ack commits the '
      'alternative with the ack still standing above it — the original '
      'window, never a restarted one, clears it', (tester) async {
    final store = _RecordingStore();
    await launchAndCommit(tester, store);
    final calls = _mockPlatformCalls(tester);

    // The completion lands: zero-duration pumps commit its read without
    // advancing the clock, so the ack is mid-window and visible above
    // the committed card.
    await tester.tap(find.byType(HechoButton));
    await tester.pump();
    await tester.pump();
    expect(find.byType(TaskCard), findsOneWidget);
    expect(find.text('¡Buen trabajo!'), findsOneWidget);

    // Partway into the window (1200 ms of its 2000), the next card is
    // skipped: the skip's refresh must not touch the completion's ack —
    // it commits the alternative with the ack still above it.
    await tester.pump(const Duration(milliseconds: 1200));
    await tester.tap(cardSecondaryFinder);
    await tester.pump();
    await tester.pump();
    expect(
      store.entries.where((entry) => entry.kind == 'card_skipped'),
      hasLength(1),
    );
    expect(find.byType(TaskCard), findsOneWidget);
    final ack = find.text('¡Buen trabajo!');
    expect(ack, findsOneWidget);
    expect(
      _rect(tester, ack).bottom,
      lessThan(_rect(tester, find.byType(TaskCard)).top),
    );

    // Still inside the original window (1900 < 2000): the ack stands.
    await tester.pump(const Duration(milliseconds: 700));
    expect(ack, findsOneWidget);

    // Past the original deadline (1900 + 110 > 2000): plain removal by
    // the completion's own timer. A skip that restarted the window
    // (deadline 1200 + 2000) would leave the ack standing exactly here.
    await tester.pump(const Duration(milliseconds: 110));
    expect(find.text('¡Buen trabajo!'), findsNothing);
    expect(find.byType(TaskCard), findsOneWidget);
    // The skip stayed feedback-free under the ack: no haptic of any
    // type fired across both taps but the Hecho's.
    expect(_hapticImpacts(calls), hasLength(1));
  });

  testWidgets('a failed skip under a visible completion ack leaves the ack '
      'standing — the healed commit carries it, the original window clears '
      'it', (tester) async {
    final inner = _RecordingStore();
    final store = _FailFirstSkippedStore(inner);
    await launchAndCommit(tester, store);
    final calls = _mockPlatformCalls(tester);

    // The completion lands: the ack is mid-window and visible above the
    // committed card.
    await tester.tap(find.byType(HechoButton));
    await tester.pump();
    await tester.pump();
    expect(find.byType(TaskCard), findsOneWidget);
    expect(find.text('¡Buen trabajo!'), findsOneWidget);

    // The skip's write fails under that visible ack: the empty frame
    // stands, nothing landed — and a skip touches no completion state,
    // so the ack-flag class is not this write's to clear.
    await tester.tap(cardSecondaryFinder);
    await tester.pump();
    await tester.pump();
    expect(find.byType(TaskCard), findsNothing);
    expect(
      inner.entries.where((entry) => entry.kind == 'card_skipped'),
      isEmpty,
    );
    expect(_hapticImpacts(calls), hasLength(1));

    // Still inside the window, the foreground heal commits the
    // still-unanswered card — and the ack rides it. A catch that copied
    // the completion's flag clears would render nothing above it.
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    await tester.pump();
    expect(find.byType(TaskCard), findsOneWidget);
    expect(find.text('¡Buen trabajo!'), findsOneWidget);

    // The original window still owns the removal.
    await tester.pump(const Duration(milliseconds: 2000));
    expect(find.text('¡Buen trabajo!'), findsNothing);
    expect(find.byType(TaskCard), findsOneWidget);
    await tester.pumpAndSettle();
  });

  testWidgets('a seven-day absence opens like any day plus the one '
      'greeting: the normal opening rows land, a TaskCard deals with '
      '«Siempre a tu disposición» above it, the census diff against a '
      'no-gap control is the greeting text alone, and rendering writes '
      'nothing (FR-6, FR-13, FR-14, NFR9)', (tester) async {
    // The milestone limb of the absence property is vacuous until Epic
    // Projects exist — Story 5.5 tests it for real once buffers land.
    // This pin is the vertical half that exists today: the opening
    // itself, row by row, widget by widget — and, since Story 2.7, the
    // one deliberate difference a warm opening renders: the greeting.
    final catalogue = await loadEvergreenCatalogue(
      AppStringsEs(),
      bundle: _FakeBundle({catalogueAssetPath: shipped}),
    );

    // One completed day seven days before the fixed clock: the chunk of
    // that Saturday's own week, dealt, answered, closed — five rows,
    // the day's whole log. The seed chunk resolves through a sitting
    // (Story 2.3: deals exist only inside one).
    final absenceDay = DateTime.utc(2026, 8, 22, 12);
    final absenceOpen = sessionStart(
      catalogue: catalogue,
      log: const [],
      instantUtcMicros: absenceDay.microsecondsSinceEpoch,
      offsetSeconds: 0,
    );
    final absenceChunkId = absenceOpen.last.itemId!;
    LogEntryRecord seedRow(String kind, int second, {String? itemId}) => (
      id: 'seed-$kind',
      kind: kind,
      instantUtcMicros: absenceDay.microsecondsSinceEpoch + second * 1000000,
      offsetSeconds: 0,
      itemId: itemId,
      itemOrigin: itemId == null ? null : Origin.shipped,
      stack: null,
      settingKey: null,
      settingValue: null,
      pocketMinutes: null,
      energyLevel: null,
      reportValue: null,
      reportWeek: null,
    );

    final gapStore = _RecordingStore()
      ..entries.addAll([
        seedRow('app_opened', 0),
        seedRow('session_started', 1),
        seedRow('card_dealt', 2, itemId: absenceChunkId),
        seedRow('card_done', 3, itemId: absenceChunkId),
        seedRow('session_ended', 4),
      ]);
    final seeded = gapStore.entries.length;

    // Launch, seven days later.
    await SessionController(
      store: gapStore,
      strings: AppStringsEs(),
      bundle: _FakeBundle({catalogueAssetPath: shipped}),
      nowOf: _fixedClock,
    ).handleAppOpen();

    // The rows the opening appended are exactly the normal opening
    // kinds — nothing gap-shaped, nothing counting the days away.
    expect(gapStore.entries.skip(seeded).map((entry) => entry.kind).toList(), [
      'app_opened',
      'session_started',
      'card_dealt',
    ]);

    // The two harnesses carry distinct screen keys: a second pump at
    // the same structural position would otherwise REUSE the gap
    // screen's element and its committed view (State survives, no new
    // read runs), and the control's own rendering would never be
    // witnessed — the greeting made that staleness observable.
    await tester.pumpWidget(
      _harness(buildController(gapStore), screenKey: const ValueKey('gap')),
    );
    await tester.pumpAndSettle();
    expect(find.byType(TaskCard), findsOneWidget);
    // Rendering wrote nothing: the read is pure, so the store holds
    // exactly the opening's rows after the frames too.
    expect(
      gapStore.entries.skip(seeded).map((entry) => entry.kind).toList(),
      ['app_opened', 'session_started', 'card_dealt'],
      reason:
          'the UI appended nothing on render — the facade no-write '
          'pin, witnessed at the store',
    );
    final gapDeal = latestDealtEntryOf(gapStore)!;
    final gapEntry = catalogue.entries.firstWhere(
      (entry) => entry.id == gapDeal.itemId,
    );
    // The census is captured while the gap launch is still mounted —
    // materialised as a list, never lazily tied to the later tree.
    final gapCensus = _censusOf(tester, [gapEntry.name]);

    // The greeting: present on the warm launch, above the committed
    // view, in the ack's register (Story 2.7, FR-6, AD-24).
    final greeting = find.text(AppStringsEs().warmReturnGreeting);
    expect(greeting, findsOneWidget);
    expect(
      _rect(tester, greeting).bottom,
      lessThan(_rect(tester, find.byType(TaskCard)).top),
      reason: 'the greeting renders above the committed view',
    );

    // The control: the same launch with no gap in the log at all — and
    // its own appended rows are asserted, so the comparison baseline is
    // itself pinned to a normal opening.
    final controlStore = _RecordingStore();
    await SessionController(
      store: controlStore,
      strings: AppStringsEs(),
      bundle: _FakeBundle({catalogueAssetPath: shipped}),
      nowOf: _fixedClock,
    ).handleAppOpen();
    expect(controlStore.entries.map((entry) => entry.kind).toList(), [
      'app_opened',
      'session_started',
      'card_dealt',
    ], reason: 'the control appended exactly the normal opening rows');

    await tester.pumpWidget(
      _harness(
        buildController(controlStore),
        screenKey: const ValueKey('control'),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(TaskCard), findsOneWidget);
    expect(controlStore.entries.map((entry) => entry.kind).toList(), [
      'app_opened',
      'session_started',
      'card_dealt',
    ], reason: 'rendering appended nothing here either');
    final controlDeal = latestDealtEntryOf(controlStore)!;
    final controlEntry = catalogue.entries.firstWhere(
      (entry) => entry.id == controlDeal.itemId,
    );
    // Same instant, same catalogue, and the seed's answered chunk
    // belongs to the previous week's zone — so both launches resolve
    // the same tier-1 candidate, and excluding that one name from both
    // censuses makes the comparison sound by construction: everything
    // left must be furniture.
    expect(
      gapDeal.itemId,
      controlDeal.itemId,
      reason:
          'the absence day resolves the same first chunk as a '
          'normal day',
    );
    // A chunk still leads the day after the absence: both launches deal
    // the same size — the composition did not silently narrow.
    expect(gapEntry.size, controlEntry.size);
    expect(gapEntry.size, Size.focus);

    // The control launch renders no greeting: its own opening is its
    // only `app_opened` — no contact before it, not due.
    expect(
      find.text(AppStringsEs().warmReturnGreeting),
      findsNothing,
      reason: 'a normal-day launch derives no warm return',
    );

    // The census diff: the greeting text alone. No count, no backlog,
    // no days-away copy anywhere — and the only structural delta is the
    // greeting's own wrap grammar (a Text in a Column with one
    // actionGap SizedBox), the ack's register exactly.
    final controlCensus = _censusOf(tester, [controlEntry.name]);
    final typeLine = RegExp(r'^[A-Za-z_$][A-Za-z0-9_$]* x\d+$');
    Set<String> stringsOf(List<String> census) => {
      for (final line in census)
        if (!typeLine.hasMatch(line)) line,
    };
    expect(stringsOf(gapCensus).difference(stringsOf(controlCensus)), {
      AppStringsEs().warmReturnGreeting,
    }, reason: 'the greeting text is the only added string');
    expect(
      stringsOf(controlCensus).difference(stringsOf(gapCensus)),
      isEmpty,
      reason: 'the control renders nothing the warm launch lacks',
    );
    Map<String, int> countsOf(List<String> census) => {
      for (final line in census)
        if (typeLine.hasMatch(line))
          line.substring(0, line.lastIndexOf(' x')): int.parse(
            line.substring(line.lastIndexOf(' x') + 2),
          ),
    };
    final gapCounts = countsOf(gapCensus);
    final controlCounts = countsOf(controlCensus);
    final deltas = <String, int>{};
    for (final name in {...gapCounts.keys, ...controlCounts.keys}) {
      final delta = (gapCounts[name] ?? 0) - (controlCounts[name] ?? 0);
      if (delta != 0) {
        deltas[name] = delta;
      }
    }
    expect(
      deltas,
      {'Column': 1, 'SizedBox': 1, 'Text': 1, 'RichText': 1},
      reason:
          'the greeting and its wrap alone changed the tree — no '
          'count, no backlog, no days-away element anywhere',
    );
  });

  testWidgets('200% font scale: the warm-return greeting wraps inside '
      'the scroll above the grown card — nothing truncated, the screen '
      'scrolls (FR-6, NFR6, UX-DR14)', (tester) async {
    tester.platformDispatcher.textScaleFactorTestValue = 2.0;
    addTearDown(tester.platformDispatcher.clearAllTestValues);
    await tester.binding.setSurfaceSize(const ui.Size(320, 480));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    // One completed day seven days before the fixed clock — the
    // seven-day launch's own seed shape, on a real shipped id.
    final absenceDay = DateTime.utc(2026, 8, 22, 12);
    LogEntryRecord seedRow(String kind, int second, {String? itemId}) => (
      id: 'seed-$kind',
      kind: kind,
      instantUtcMicros: absenceDay.microsecondsSinceEpoch + second * 1000000,
      offsetSeconds: 0,
      itemId: itemId,
      itemOrigin: itemId == null ? null : Origin.shipped,
      stack: null,
      settingKey: null,
      settingValue: null,
      pocketMinutes: null,
      energyLevel: null,
      reportValue: null,
      reportWeek: null,
    );
    final store = _RecordingStore()
      ..entries.addAll([
        seedRow('app_opened', 0),
        seedRow('session_started', 1),
        seedRow('card_dealt', 2, itemId: 'pasar-la-aspiradora-a-la-cocina'),
        seedRow('card_done', 3, itemId: 'pasar-la-aspiradora-a-la-cocina'),
        seedRow('session_ended', 4),
      ]);
    await SessionController(
      store: store,
      strings: AppStringsEs(),
      bundle: _FakeBundle({catalogueAssetPath: shipped}),
      nowOf: _fixedClock,
    ).handleAppOpen();

    await tester.pumpWidget(_harness(buildController(store)));
    await tester.pumpAndSettle();

    // Growing and scrolling, never truncating: no layout exception, the
    // greeting whole inside the scroll column above the grown card.
    expect(tester.takeException(), isNull);
    final greeting = find.text(AppStringsEs().warmReturnGreeting);
    expect(greeting, findsOneWidget);
    expect(find.byType(SingleChildScrollView), findsOneWidget);
    final screen = tester.view.physicalSize / tester.view.devicePixelRatio;
    final greetingRect = _rect(tester, greeting);
    expect(greetingRect.left, greaterThanOrEqualTo(0));
    expect(greetingRect.right, lessThanOrEqualTo(screen.width));
    expect(find.byType(TaskCard), findsOneWidget);

    // The greeting plus the grown card outgrow the viewport — the
    // screen really scrolls, and the card's controls stay reachable.
    final scrollable = tester.state<ScrollableState>(find.byType(Scrollable));
    expect(
      scrollable.position.maxScrollExtent,
      greaterThan(0),
      reason:
          'the greeting plus the 200% card must outgrow the viewport '
          'for the scroll pin to be real',
    );
    await tester.scrollUntilVisible(
      find.byType(HechoButton),
      200,
      scrollable: find.byType(Scrollable),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.byType(HechoButton), findsOneWidget);
  });

  testWidgets('a warm launch that lands on the warm close renders the '
      'greeting above the close string — the fact rides every variant '
      '(Story 2.7, FR-6, AD-24)', (tester) async {
    // The controller suite's closed shape: a completed day seven days
    // before the fixed clock (the seven-day seed's own rows, on a real
    // shipped id), today's `app_opened` — and a controller over an
    // empty catalogue, so the read resolves the warm close with the
    // greeting standing above it.
    final absenceDay = DateTime.utc(2026, 8, 22, 12);
    LogEntryRecord seedRow(String kind, int second, {String? itemId}) => (
      id: 'seed-$kind',
      kind: kind,
      instantUtcMicros: absenceDay.microsecondsSinceEpoch + second * 1000000,
      offsetSeconds: 0,
      itemId: itemId,
      itemOrigin: itemId == null ? null : Origin.shipped,
      stack: null,
      settingKey: null,
      settingValue: null,
      pocketMinutes: null,
      energyLevel: null,
      reportValue: null,
      reportWeek: null,
    );
    final store = _RecordingStore()
      ..entries.addAll([
        seedRow('app_opened', 0),
        seedRow('session_started', 1),
        seedRow('card_dealt', 2, itemId: 'pasar-la-aspiradora-a-la-cocina'),
        seedRow('card_done', 3, itemId: 'pasar-la-aspiradora-a-la-cocina'),
        seedRow('session_ended', 4),
        (
          id: 'today-open',
          kind: 'app_opened',
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
          settingKey: null,
          settingValue: null,
          pocketMinutes: null,
          energyLevel: null,
          reportValue: null,
          reportWeek: null,
        ),
      ]);

    await tester.pumpWidget(
      _harness(
        buildController(
          store,
          bundle: _FakeBundle({
            catalogueAssetPath: '{"version":1,"entries":[]}',
          }),
        ),
        screenKey: const ValueKey('warm-closed'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(TaskCard), findsNothing);
    final close = find.text(AppStringsEs().poolExhaustedClose);
    expect(close, findsOneWidget);
    final greeting = find.text(AppStringsEs().warmReturnGreeting);
    expect(greeting, findsOneWidget);
    expect(
      _rect(tester, greeting).bottom,
      lessThan(_rect(tester, close).top),
      reason:
          'the greeting renders above the committed close, exactly as '
          'above the dealt card',
    );
  });

  group('the Nuevo proyecto affordance (Story 2.1, UX-DR25)', () {
    // The footer band holds two labelled prose controls now (Story 2.3
    // added the stop); the label discriminates each grammatically
    // identical SecondaryTextAction.
    final footerFinder = find.byWidgetPredicate(
      (widget) =>
          widget is SecondaryTextAction &&
          widget.label == AppStringsEs().newProjectLink,
    );

    testWidgets('sits in the bottom-centred footer band as quiet '
        'ink-secondary text with a 48dp opaque target — never animated, '
        'emphasised, badged, nor carrying pastel mass (UX-DR25)', (
      tester,
    ) async {
      final store = _RecordingStore();
      await launchAndCommit(tester, store);

      final footer = find.text(AppStringsEs().newProjectLink);
      expect(footer, findsOneWidget);
      final style = tester.widget<Text>(footer).style!;
      expect(style.color, FieldPalette.inkSecondary);
      expect(style.fontFamily, FontFamilies.lexend);
      expect(style.fontSize, 15);
      expect(style.fontWeight, FontWeight.w400);

      // Bottom-centred as a band: the wrap holding both prose controls
      // shares the screen's x-axis centre and sits at the bottom of the
      // body, inside the safe area — each control inside the viewport.
      // (The band's own wrap, named through its controls — the report
      // resident's digits row is a wrap in the scroll region too.)
      final screen = tester.view.physicalSize / tester.view.devicePixelRatio;
      final band = _rect(
        tester,
        find.ancestor(of: footerFinder, matching: find.byType(Wrap)).first,
      );
      expect(band.center.dx, closeTo(screen.width / 2, 0.5));
      expect(band.bottom, lessThanOrEqualTo(screen.height));
      final target = _rect(tester, footerFinder);
      expect(target.top, greaterThanOrEqualTo(0));
      expect(target.bottom, lessThanOrEqualTo(screen.height));
      // The 48dp opaque floor.
      expect(target.height, greaterThanOrEqualTo(48));
      expect(
        tester
            .widget<GestureDetector>(
              find.descendant(
                of: footerFinder,
                matching: find.byType(GestureDetector),
              ),
            )
            .behavior,
        HitTestBehavior.opaque,
      );

      // Quiet by census: the footer subtree is text in a tap band and
      // nothing else — no glyph, no fill, no badge, no motion.
      final footerTypes = tester
          .widgetList(
            find.descendant(
              of: footerFinder,
              matching: find.byWidgetPredicate((_) => true),
            ),
          )
          .map((widget) => widget.runtimeType.toString())
          .toSet();
      expect(
        footerTypes.difference(const {
          'SecondaryTextAction',
          'GestureDetector',
          'RawGestureDetector',
          '_GestureSemantics',
          'Listener',
          'ConstrainedBox',
          'Center',
          'Text',
          'RichText',
        }),
        isEmpty,
        reason: 'the affordance is prose in a tap band and nothing else',
      );
      expect(
        find.descendant(of: footerFinder, matching: find.byType(Icon)),
        findsNothing,
      );
      expect(
        find.descendant(of: footerFinder, matching: find.byType(LeafGlyph)),
        findsNothing,
      );
      expect(
        find.descendant(of: footerFinder, matching: find.byType(Material)),
        findsNothing,
        reason: 'no pastel mass: the way off the surface is prose',
      );

      // The furniture census still holds with the footer band standing: no
      // badge, no counter, no gap-shaped element beyond the known
      // strings.
      final census = _censusOf(tester, [
        AppStringsEs().newProjectLink,
        AppStringsEs().actionRescueOrSkip,
        AppStringsEs().actionDone,
        AppStringsEs().actionStop,
      ]);
      expect(census, isNot(contains(contains('Badge'))));
      expect(census, isNot(contains(contains('Animation'))));
    });

    testWidgets('tapping it opens the intermediate surface — the first '
        'navigation in the app (Story 2.1)', (tester) async {
      final store = _RecordingStore();
      await launchAndCommit(tester, store);

      await tester.tap(find.text(AppStringsEs().newProjectLink));
      await tester.pumpAndSettle();

      expect(find.byType(NuevoProyectoScreen), findsOneWidget);
      expect(find.byType(TaskCard), findsNothing);
      // Rendering and navigating wrote nothing.
      expect(
        store.entries.map((entry) => entry.kind).toList(),
        contains('card_dealt'),
      );
      expect(
        store.entries.where((entry) => entry.kind == 'setting_changed'),
        isEmpty,
      );
    });

    testWidgets('a launch with a seeded bag of 5 deals a non-focus card, '
        'while the default 15 leads with focus (FR-7, Story 2.1)', (
      tester,
    ) async {
      Future<_RecordingStore> launchWithBag(int? minutes) async {
        final store = _RecordingStore();
        if (minutes != null) {
          store.entries.add((
            id: 'seed-setting',
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
            settingValue: minutes,
            pocketMinutes: null,
            energyLevel: null,
            reportValue: null,
            reportWeek: null,
          ));
        }
        await SessionController(
          store: store,
          strings: AppStringsEs(),
          bundle: _FakeBundle({catalogueAssetPath: shipped}),
          nowOf: _fixedClock,
        ).handleAppOpen();
        // Unmount any earlier launch first: the same harness position
        // would otherwise reuse the previous screen state and show its
        // committed view instead of reading the new store.
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpWidget(_harness(buildController(store)));
        await tester.pumpAndSettle();
        return store;
      }

      final narrow = await launchWithBag(5);
      final narrowDeal = latestDealtEntryOf(narrow)!;
      final catalogue = await loadEvergreenCatalogue(
        AppStringsEs(),
        bundle: _FakeBundle({catalogueAssetPath: shipped}),
      );
      final narrowEntry = catalogue.entries.firstWhere(
        (entry) => entry.id == narrowDeal.itemId,
      );
      expect(narrowEntry.size, isNot(Size.focus));
      expect(find.text('15\u00A0min'), findsNothing);
      expect(find.byType(TaskCard), findsOneWidget);

      final control = await launchWithBag(null);
      final controlDeal = latestDealtEntryOf(control)!;
      final controlEntry = catalogue.entries.firstWhere(
        (entry) => entry.id == controlDeal.itemId,
      );
      expect(controlEntry.size, Size.focus);
      expect(find.text('15\u00A0min'), findsOneWidget);
    });
  });
  group('the pocket trigger and its ladder (Story 2.2, FR-8, UX-DR18)', () {
    test('every ladder option lies inside the pocket\'s command range — '
        'a stray out-of-range value would reach a refusal the surface '
        'cannot show (Story 2.2)', () {
      expect(pocketLadderOptions, isNotEmpty);
      for (final minutes in pocketLadderOptions) {
        expect(
          minutes,
          greaterThanOrEqualTo(pocketLeastMinutes),
          reason: 'option $minutes dips below the pocket range floor',
        );
        expect(
          minutes,
          lessThanOrEqualTo(pocketMostMinutes),
          reason: 'option $minutes climbs above the pocket range ceiling',
        );
      }
    });

    /// A seeded pocketed session start, as a declaration or a process
    /// death would have left it.
    void seedPocketedStart(_RecordingStore store, int pocketMinutes) {
      store.entries.add((
        id: 'seed-pocket',
        kind: 'session_started',
        instantUtcMicros: DateTime.utc(2026, 8, 29, 11).microsecondsSinceEpoch,
        offsetSeconds: 0,
        itemId: null,
        itemOrigin: null,
        stack: null,
        settingKey: null,
        settingValue: null,
        pocketMinutes: pocketMinutes,
        energyLevel: null,
        reportValue: null,
        reportWeek: null,
      ));
    }

    testWidgets('the trigger chip sits top-centred above the card, '
        'carrying the standing declared pocket — else the 15 default — '
        'and stands on the warm close too', (tester) async {
      final store = _RecordingStore();
      await launchAndCommit(tester, store);

      final chip = find.byType(PocketTriggerChip);
      expect(chip, findsOneWidget);
      expect(find.text('Tengo 15 minutos ahora'), findsOneWidget);
      // Top-centred: shares the screen's x-axis centre, sits above the
      // card, inside the safe area.
      final screen = tester.view.physicalSize / tester.view.devicePixelRatio;
      final chipRect = _rect(tester, chip);
      expect(chipRect.center.dx, closeTo(screen.width / 2, 0.5));
      expect(
        chipRect.bottom,
        lessThan(_rect(tester, find.byType(TaskCard)).top),
        reason: 'the trigger is chrome above the scroll region',
      );
      expect(chipRect.top, greaterThanOrEqualTo(0));

      // The standing pocket: a seeded 20-minute pocketed session reads
      // on the chip (the launch deal suppressed by the pocket's own
      // arithmetic lands beneath the chunk).
      final pocketed = _RecordingStore();
      seedPocketedStart(pocketed, 20);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpWidget(_harness(buildController(pocketed)));
      await tester.pumpAndSettle();
      expect(find.text('Tengo 20 minutos ahora'), findsOneWidget);

      // The warm close keeps the chip: a spent pocket is declared until
      // superseded, and the surface never styles the close as absence.
      final spent = _RecordingStore();
      seedPocketedStart(spent, 1);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpWidget(_harness(buildController(spent)));
      await tester.pumpAndSettle();
      expect(
        find.text('por hoy no hay nada más que merezca la pena'),
        findsOneWidget,
      );
      // The singular ICU plural form: an imported in-range pocket of 1
      // reads grammatically, never "1 minutos".
      expect(find.text('Tengo un minuto ahora'), findsOneWidget);
      expect(find.byType(TaskCard), findsNothing);
      expect(find.byType(ErrorWidget), findsNothing);
    });

    testWidgets('tapping the chip opens a quiet, titleless ladder of '
        'stepped pills — selected marking the standing pocket, a tap '
        'popping the sheet and declaring', (tester) async {
      final store = _RecordingStore();
      await launchAndCommit(tester, store);

      await tester.tap(find.byType(PocketTriggerChip));
      await tester.pumpAndSettle();

      // Every offered option, in the duration format, scoped to the
      // sheet — the card's own duration chip sits behind it and may
      // carry the same label. Nothing else is on the sheet: no title,
      // no glyph, no error state.
      Finder pillOf(int minutes) => find.descendant(
        of: find.byType(BottomSheet),
        matching: find.text('$minutes\u00A0min'),
      );
      for (final minutes in [5, 10, 15, 20, 25, 30, 45, 60]) {
        expect(pillOf(minutes), findsOneWidget);
      }
      expect(find.byType(Icon), findsNothing);
      expect(find.byType(ErrorWidget), findsNothing);
      expect(find.byType(SnackBar), findsNothing);

      // The default standing (no pocketed session) marks 15 selected:
      // exactly one selected semantics node sits in the sheet — the
      // strip's pre-marked llena below the card is the ambient
      // surface's own standing default, never a ladder option.
      final marked = tester
          .widgetList<Semantics>(
            find.descendant(
              of: find.byType(BottomSheet),
              matching: find.byType(Semantics),
            ),
          )
          .where((semantics) => semantics.properties.selected ?? false)
          .toList();
      expect(
        marked,
        hasLength(1),
        reason: 'exactly the standing option is selected',
      );
      expect(pillOf(15), findsOneWidget);

      // The tap pops the sheet and declares: [session_ended,
      // session_started{20}] over the open launch session — a card in
      // progress carries, so no bundled deal.
      await tester.tap(pillOf(20));
      await tester.pumpAndSettle();

      expect(find.byType(BottomSheet), findsNothing);
      expect(store.entries.map((entry) => entry.kind).toList(), [
        'app_opened',
        'session_started',
        'card_dealt',
        'session_ended',
        'session_started',
      ]);
      expect(store.entries[4].pocketMinutes, 20);
      // The carried card still renders, and the chip reads the new
      // standing pocket.
      expect(find.byType(TaskCard), findsOneWidget);
      expect(find.text('Tengo 20 minutos ahora'), findsOneWidget);
    });

    testWidgets('declaring from the ladder with no card standing bundles '
        'the pocket-bounded first deal (FR-8)', (tester) async {
      final store = _RecordingStore();
      // A closed bare session: nothing open, nothing standing. A
      // ticking clock keeps the close and the declaration at distinct
      // instants, as two real taps always are — under the frozen clock
      // they would collapse onto one instant and read as a supersede
      // pair.
      var minute = 0;
      DateTime ticking() => DateTime.utc(2026, 8, 29, 12, minute++);
      await SessionController(
        store: store,
        strings: AppStringsEs(),
        bundle: _FakeBundle({catalogueAssetPath: shipped}),
        nowOf: ticking,
      ).handleAppOpen();
      await SessionController(
        store: store,
        strings: AppStringsEs(),
        bundle: _FakeBundle({catalogueAssetPath: shipped}),
        nowOf: ticking,
      ).handleSessionEnd();
      await tester.pumpWidget(
        _harness(
          DispenserController(
            store: store,
            strings: AppStringsEs(),
            bundle: _FakeBundle({catalogueAssetPath: shipped}),
            nowOf: ticking,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byType(PocketTriggerChip));
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(
          of: find.byType(BottomSheet),
          matching: find.text('15\u00A0min'),
        ),
      );
      await tester.pumpAndSettle();

      expect(store.entries.map((entry) => entry.kind).toList(), [
        'app_opened',
        'session_started',
        'card_dealt',
        'session_ended',
        'session_started',
        'card_dealt',
      ]);
      expect(store.entries[4].pocketMinutes, 15);
      final catalogue = await loadEvergreenCatalogue(
        AppStringsEs(),
        bundle: _FakeBundle({catalogueAssetPath: shipped}),
      );
      // The launch session's dealt chunk was never answered: the day's
      // slot still holds it dealable, and 15 holds the chunk exactly.
      final dealtSize = catalogue.entries
          .firstWhere((entry) => entry.id == store.entries[5].itemId)
          .size;
      expect(dealtSize, Size.focus);
      expect(find.byType(TaskCard), findsOneWidget);
    });

    testWidgets('the ladder at 200%: every pill holds its 48dp floor, '
        'nothing is ellipsized, and the sheet scrolls (UX-DR45, NFR6)', (
      tester,
    ) async {
      tester.platformDispatcher.textScaleFactorTestValue = 2.0;
      addTearDown(tester.platformDispatcher.clearAllTestValues);
      await tester.binding.setSurfaceSize(const ui.Size(320, 480));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final store = _RecordingStore();
      await launchAndCommit(tester, store);

      // The always-visible trigger chip first: its whole sentence
      // renders, never truncated, never maxLines-capped — the scaled
      // text grows past its 100% line height (15sp × 1.40) and the
      // chip stays inside the screen's width, wrapping into its own
      // air if the label outgrows the margins.
      final chipLabel = find.text('Tengo 15 minutos ahora');
      expect(chipLabel, findsOneWidget);
      final chipText = tester.widget<Text>(chipLabel);
      expect(chipText.maxLines, isNull);
      expect(chipText.overflow, isNot(TextOverflow.ellipsis));
      expect(tester.takeException(), isNull);
      final screen = tester.view.physicalSize / tester.view.devicePixelRatio;
      final chipRect = _rect(tester, find.byType(PocketTriggerChip));
      expect(chipRect.left, greaterThanOrEqualTo(0));
      expect(chipRect.right, lessThanOrEqualTo(screen.width));
      expect(
        tester.renderObject<RenderParagraph>(chipLabel).size.height,
        greaterThan(15 * 1.40),
        reason:
            'the chip\'s text grows with the scaler, it is not shrunk '
            'to fit',
      );

      await tester.tap(find.byType(PocketTriggerChip));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      for (final minutes in [5, 10, 15, 20, 25, 30, 45, 60]) {
        final pill = find.descendant(
          of: find.byType(BottomSheet),
          matching: find.text('$minutes\u00A0min'),
        );
        expect(pill, findsOneWidget);
        expect(
          tester
              .renderObject<RenderBox>(
                find.ancestor(of: pill, matching: find.byType(InkWell)).first,
              )
              .size
              .height,
          greaterThanOrEqualTo(48),
          reason: 'the $minutes pill holds the 48dp touch floor',
        );
      }
      // A Wrap reflows and the sheet's own scroll view stands ready.
      // (The footer band's Wrap is another, outside the sheet — the
      // band joined the pinned chrome or the scroll region per the
      // floor; this pin is the sheet's own.)
      expect(
        find.descendant(
          of: find.byType(BottomSheet),
          matching: find.byType(Wrap),
        ),
        findsOneWidget,
      );
      expect(find.byType(SingleChildScrollView), findsWidgets);
      expect(find.byType(ErrorWidget), findsNothing);
    });

    testWidgets('the 200% ladder scrolls its lower pills into view on a '
        'short handset', (tester) async {
      tester.platformDispatcher.textScaleFactorTestValue = 2.0;
      addTearDown(tester.platformDispatcher.clearAllTestValues);
      await tester.binding.setSurfaceSize(const ui.Size(320, 220));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final store = _RecordingStore();
      await launchAndCommit(tester, store);
      await tester.tap(find.byType(PocketTriggerChip));
      await tester.pumpAndSettle();

      final sheet = find.byType(BottomSheet);
      final scrollView = find.descendant(
        of: sheet,
        matching: find.byType(SingleChildScrollView),
      );
      final lastPill = find.descendant(
        of: sheet,
        matching: find.text('60\u00A0min'),
      );
      expect(tester.getRect(lastPill).bottom, greaterThan(220));

      await tester.drag(scrollView, const Offset(0, -300));
      await tester.pumpAndSettle();

      expect(tester.getRect(lastPill).bottom, lessThanOrEqualTo(220));
    });

    testWidgets('the reveal flow: an elapsed pocket left open by process '
        'death closes at the next open, before any new session_started — '
        'and the carried card renders answerable through it (AD-19)', (
      tester,
    ) async {
      final store = _RecordingStore();
      // Process death shape: a pocketed session opened at 11:00 with a
      // 15-minute pocket and a dealt card, never backgrounded — at the
      // fixed 12:00 clock the pocket is long past.
      seedPocketedStart(store, 15);
      store.entries.add((
        id: 'seed-deal',
        kind: 'card_dealt',
        instantUtcMicros: DateTime.utc(
          2026,
          8,
          29,
          11,
          0,
          1,
        ).microsecondsSinceEpoch,
        offsetSeconds: 0,
        itemId: 'pasar-la-aspiradora-a-la-cocina',
        itemOrigin: Origin.shipped,
        stack: null,
        settingKey: null,
        settingValue: null,
        pocketMinutes: null,
        energyLevel: null,
        reportValue: null,
        reportWeek: null,
      ));
      await SessionController(
        store: store,
        strings: AppStringsEs(),
        bundle: _FakeBundle({catalogueAssetPath: shipped}),
        nowOf: _fixedClock,
      ).handleAppOpen();

      expect(store.entries.skip(2).map((entry) => entry.kind).toList(), [
        'app_opened',
        'session_ended',
        'session_started',
      ]);
      expect(store.entries[4].pocketMinutes, isNull);

      await tester.pumpWidget(_harness(buildController(store)));
      await tester.pumpAndSettle();
      // The carried chunk renders; no error anywhere; the chip reads
      // the fresh unbounded default.
      final catalogue = await loadEvergreenCatalogue(
        AppStringsEs(),
        bundle: _FakeBundle({catalogueAssetPath: shipped}),
      );
      final carried = catalogue.entries.firstWhere(
        (entry) => entry.id == 'pasar-la-aspiradora-a-la-cocina',
      );
      expect(find.text(carried.name), findsOneWidget);
      expect(find.byType(ErrorWidget), findsNothing);
      expect(find.text('Tengo 15 minutos ahora'), findsOneWidget);

      // Hecho on the carried card records and bundles freely — the
      // fresh sitting is unbounded.
      await tester.tap(find.byType(HechoButton));
      await tester.pumpAndSettle();
      expect(
        store.entries.where((entry) => entry.kind == 'card_done').length,
        1,
      );
      expect(
        store.entries.where((entry) => entry.kind == 'card_dealt').length,
        2,
      );
      expect(find.byType(ErrorWidget), findsNothing);
    });

    testWidgets('a failed declare leaves the quiet empty frame — no error '
        'surface, nothing landed — and a later Hecho still works (the '
        'in-flight guard was released)', (tester) async {
      final inner = _RecordingStore();
      await SessionController(
        store: inner,
        strings: AppStringsEs(),
        bundle: _FakeBundle({catalogueAssetPath: shipped}),
        nowOf: _fixedClock,
      ).handleAppOpen();
      final failing = _FailNextAppendStore(inner);
      await tester.pumpWidget(_harness(buildController(failing)));
      await tester.pumpAndSettle();
      expect(find.byType(TaskCard), findsOneWidget);
      final before = inner.entries.length;

      // The declare's first append fails: the sheet pops, the surface
      // settles on the empty frame, and no error shape exists anywhere.
      failing.failNextAppend = true;
      await tester.tap(find.byType(PocketTriggerChip));
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(
          of: find.byType(BottomSheet),
          matching: find.text('20\u00A0min'),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(BottomSheet), findsNothing);
      expect(find.byType(TaskCard), findsNothing);
      expect(find.byType(ErrorWidget), findsNothing);
      expect(find.byType(SnackBar), findsNothing);
      expect(inner.entries, hasLength(before));

      // The guard was released and the log stands: a real return to the
      // foreground re-reads the carried card, and Hecho on it records.
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pumpAndSettle();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(find.byType(TaskCard), findsOneWidget);

      await tester.tap(find.byType(HechoButton));
      await tester.pumpAndSettle();
      expect(
        inner.entries.where((entry) => entry.kind == 'card_done').length,
        1,
        reason: 'the Hecho landed — the failed declare wedged nothing',
      );
      expect(
        inner.entries.where((entry) => entry.kind == 'card_dealt').length,
        2,
        reason: 'the bundled next deal landed beside it',
      );
      expect(find.byType(ErrorWidget), findsNothing);
    });
  });

  group('the stop control (Story 2.3, FR-9, UX-DR43)', () {
    /// A seeded pocketed session start, as a declaration would have
    /// left it — the pocket group's own seeding shape, with the start
    /// instant injectable so a pocket can sit unelapsed at the fixed
    /// clock.
    void seedPocketedStart(
      _RecordingStore store,
      int pocketMinutes, {
      DateTime? at,
    }) {
      store.entries.add((
        id: 'seed-pocket',
        kind: 'session_started',
        instantUtcMicros:
            (at ?? DateTime.utc(2026, 8, 29, 11)).microsecondsSinceEpoch,
        offsetSeconds: 0,
        itemId: null,
        itemOrigin: null,
        stack: null,
        settingKey: null,
        settingValue: null,
        pocketMinutes: pocketMinutes,
        energyLevel: null,
        reportValue: null,
        reportWeek: null,
      ));
    }

    testWidgets('one tap on Quiero parar appends exactly one session_ended '
        'and commits the warm close — chip at 15, silence everywhere '
        '(FR-9, UX-DR43)', (tester) async {
      final store = _RecordingStore();
      await launchAndCommit(tester, store);
      final calls = _mockPlatformCalls(tester);

      await tester.tap(find.text('Quiero parar'));
      await tester.pumpAndSettle();

      // Exactly one close row; the surface is the standing warm close.
      expect(
        store.entries.where((entry) => entry.kind == 'session_ended'),
        hasLength(1),
      );
      expect(store.entries.last.kind, 'session_ended');
      expect(find.text(AppStringsEs().poolExhaustedClose), findsOneWidget);
      expect(find.byType(TaskCard), findsNothing);
      // The chip reads its default again: no pocket fact stands.
      expect(find.text('Tengo 15 minutos ahora'), findsOneWidget);
      // Silence by construction: no haptic, no toast, no banner, no
      // dialog — recalculation is invisible.
      expect(_hapticImpacts(calls), isEmpty);
      expect(find.byType(SnackBar), findsNothing);
      expect(find.byType(MaterialBanner), findsNothing);
      expect(find.byType(AlertDialog), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a pocketed sitting paused mid-card: the chip reads the '
        'declared pocket before, the 15 default after', (tester) async {
      final store = _RecordingStore();
      // Seeded 11:50 with 20 minutes: unelapsed at the fixed 12:00
      // clock, the dealt card standing inside it.
      seedPocketedStart(store, 20, at: DateTime.utc(2026, 8, 29, 11, 50));
      await tester.pumpWidget(_harness(buildController(store)));
      await tester.pumpAndSettle();
      expect(find.text('Tengo 20 minutos ahora'), findsOneWidget);
      expect(find.byType(TaskCard), findsOneWidget);

      await tester.tap(find.text('Quiero parar'));
      await tester.pumpAndSettle();

      expect(
        store.entries.where((entry) => entry.kind == 'session_ended'),
        hasLength(1),
      );
      expect(find.text(AppStringsEs().poolExhaustedClose), findsOneWidget);
      expect(find.text('Tengo 15 minutos ahora'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a repeat tap with nothing open is the accepted quiet '
        'no-op — no rows, no state change, silent', (tester) async {
      final store = _RecordingStore();
      await launchAndCommit(tester, store);
      final calls = _mockPlatformCalls(tester);

      await tester.tap(find.text('Quiero parar'));
      await tester.pumpAndSettle();
      expect(find.text(AppStringsEs().poolExhaustedClose), findsOneWidget);

      // The second tap on the close: nothing appends, nothing moves.
      await tester.tap(find.text('Quiero parar'));
      await tester.pumpAndSettle();

      expect(
        store.entries.where((entry) => entry.kind == 'session_ended'),
        hasLength(1),
      );
      expect(find.text(AppStringsEs().poolExhaustedClose), findsOneWidget);
      expect(_hapticImpacts(calls), isEmpty);
      expect(find.byType(SnackBar), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a return after pausing deals the next Micro-task directly '
        '— no resume menu, no summary, nothing about the past (FR-9, '
        'UX-DR41)', (tester) async {
      final store = _RecordingStore();
      // A ticking clock: backgrounding and resuming mint distinct
      // instants, as production always does.
      var minute = 0;
      DateTime ticking() => DateTime.utc(2026, 8, 29, 12, minute++);
      final session = installSessionController(
        store: store,
        strings: AppStringsEs(),
        bundle: _FakeBundle({catalogueAssetPath: shipped}),
        nowOf: ticking,
      );
      addTearDown(() => tester.binding.removeObserver(session));
      await session.settled;

      await tester.pumpWidget(
        _harness(
          DispenserController(
            store: store,
            strings: AppStringsEs(),
            bundle: _FakeBundle({catalogueAssetPath: shipped}),
            nowOf: ticking,
          ),
          sessionSettled: () => session.settled,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(TaskCard), findsOneWidget);
      final firstDealtId = dealtEntryOf(store)!.itemId!;

      // The pause: one row, the close.
      await tester.tap(find.text('Quiero parar'));
      await tester.pumpAndSettle();
      expect(
        store.entries.where((entry) => entry.kind == 'session_ended'),
        hasLength(1),
      );
      expect(find.text(AppStringsEs().poolExhaustedClose), findsOneWidget);

      // Leave and return: the open appends exactly the normal opening
      // rows — the next Micro-task deals directly.
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pumpAndSettle();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();

      expect(store.entries.skip(4).map((entry) => entry.kind).toList(), [
        'app_opened',
        'session_started',
        'card_dealt',
      ]);
      expect(find.byType(TaskCard), findsOneWidget);
      expect(latestDealtEntryOf(store)!.itemId, isNot(firstDealtId));
      // Nothing about the past exists anywhere on the surface.
      expect(find.byType(AlertDialog), findsNothing);
      expect(find.byType(SnackBar), findsNothing);
      expect(find.byType(MaterialBanner), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('the stop stands on the empty frame after a failed pause '
        'write — present, tappable, never disabled — and the retried tap '
        'commits the close through the released guard', (tester) async {
      final inner = _RecordingStore();
      await SessionController(
        store: inner,
        strings: AppStringsEs(),
        bundle: _FakeBundle({catalogueAssetPath: shipped}),
        nowOf: _fixedClock,
      ).handleAppOpen();
      final failing = _FailNextAppendStore(inner);
      await tester.pumpWidget(_harness(buildController(failing)));
      await tester.pumpAndSettle();
      expect(find.byType(TaskCard), findsOneWidget);

      // The pause's only append fails: nothing lands, the quiet empty
      // frame stands — and the stop is still on it, never disabled.
      failing.failNextAppend = true;
      await tester.tap(find.text('Quiero parar'));
      await tester.pumpAndSettle();

      expect(find.byType(TaskCard), findsNothing);
      expect(find.text(AppStringsEs().poolExhaustedClose), findsNothing);
      expect(find.text('Quiero parar'), findsOneWidget);
      expect(
        inner.entries.where((entry) => entry.kind == 'session_ended'),
        isEmpty,
        reason: 'the log stayed consistent: nothing landed',
      );

      // The guard was released and the log stands: the retried stop
      // lands its one row and commits the close.
      await tester.tap(find.text('Quiero parar'));
      await tester.pumpAndSettle();

      expect(
        inner.entries.where((entry) => entry.kind == 'session_ended'),
        hasLength(1),
      );
      expect(find.text(AppStringsEs().poolExhaustedClose), findsOneWidget);
      expect(find.byType(ErrorWidget), findsNothing);
    });

    testWidgets('a stale launch/foreground read cannot overwrite the '
        'committed close — the ack-generation pattern, on the pause '
        '(_readGeneration)', (tester) async {
      final first = Completer<DispenserView>();
      final second = Completer<DispenserView>();
      final controller = _QueuedPauseController([first, second]);

      await tester.pumpWidget(_harness(controller));
      await tester.pump();
      first.complete(const DispenserDealt(_testCard));
      await tester.pumpAndSettle();
      expect(find.byType(TaskCard), findsOneWidget);

      // A foreground refresh starts reading (generation 2) — and while
      // its read hangs, the stop tap commits its own close (generation
      // 3).
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();

      await tester.tap(find.text('Quiero parar'));
      await tester.pump();
      controller.pauseView.complete(const DispenserClosed());
      await tester.pump();
      await tester.pump();
      expect(find.text(AppStringsEs().poolExhaustedClose), findsOneWidget);

      // The stale read lands last carrying a dealt view: the generation
      // guard refuses it — the close stands.
      second.complete(const DispenserDealt(_longCard));
      await tester.pumpAndSettle();
      expect(find.text(AppStringsEs().poolExhaustedClose), findsOneWidget);
      expect(find.byType(TaskCard), findsNothing);
    });

    testWidgets('200%: both footer texts stand whole — wrapping, never '
        'truncating — inside the viewport, the band pinned below the '
        'scroll region', (tester) async {
      tester.platformDispatcher.textScaleFactorTestValue = 2.0;
      addTearDown(tester.platformDispatcher.clearAllTestValues);
      await tester.binding.setSurfaceSize(const ui.Size(320, 480));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final store = _RecordingStore();
      await launchAndCommit(tester, store);

      expect(tester.takeException(), isNull);
      final screen = tester.view.physicalSize / tester.view.devicePixelRatio;
      for (final label in [
        AppStringsEs().actionStop,
        AppStringsEs().newProjectLink,
      ]) {
        final text = find.text(label);
        expect(text, findsOneWidget);
        final widget = tester.widget<Text>(text);
        expect(widget.maxLines, isNull);
        expect(widget.overflow, isNot(TextOverflow.ellipsis));
        final rect = _rect(tester, text);
        expect(rect.top, greaterThanOrEqualTo(0));
        expect(rect.bottom, lessThanOrEqualTo(screen.height));
      }
      // Pinned chrome: the band is not inside the scroll region — the
      // band's own wrap, named through its controls, never the report
      // resident's digits row that legitimately scrolls.
      expect(
        find.descendant(
          of: find.byType(SingleChildScrollView),
          matching: find.ancestor(
            of: find.byType(SecondaryTextAction),
            matching: find.byType(Wrap),
          ),
        ),
        findsNothing,
      );
    });

    testWidgets('the reflow threshold holds its exact boundary: the band '
        'stays pinned at a 320-tall body and joins the scroll one step '
        'below — moving the threshold in either direction fails here', (
      tester,
    ) async {
      Future<void> pumpAt(ui.Size size) async {
        await tester.binding.setSurfaceSize(size);
        await tester.pumpAndSettle();
      }

      tester.platformDispatcher.textScaleFactorTestValue = 2.0;
      addTearDown(tester.platformDispatcher.clearAllTestValues);
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final store = _RecordingStore();
      await launchAndCommit(tester, store);

      // Exactly at the threshold: pinned chrome — the band is not
      // inside the scroll region, both targets render inside the
      // viewport, and the boundary really is the height under test.
      await pumpAt(const ui.Size(320, 320));
      expect(tester.takeException(), isNull);
      final screen = tester.getSize(find.byType(Scaffold));
      expect(screen.height, 320, reason: 'the boundary height is live');
      expect(
        find.descendant(
          of: find.byType(SingleChildScrollView),
          matching: find.ancestor(
            of: find.byType(SecondaryTextAction),
            matching: find.byType(Wrap),
          ),
        ),
        findsNothing,
        reason: 'the band stays pinned at the exact boundary height',
      );
      for (final label in [
        AppStringsEs().actionStop,
        AppStringsEs().newProjectLink,
      ]) {
        final rect = _rect(tester, find.text(label));
        expect(rect.top, greaterThanOrEqualTo(0));
        expect(rect.bottom, lessThanOrEqualTo(screen.height));
      }

      // One step below: all chrome has joined the scroll region. Moving
      // only the band would leave the chip outside the accessibility
      // fallback, where a still-shorter body could overflow it.
      await pumpAt(const ui.Size(320, 319));
      expect(tester.takeException(), isNull);
      expect(
        find.descendant(
          of: find.byType(SingleChildScrollView),
          matching: find.ancestor(
            of: find.byType(SecondaryTextAction),
            matching: find.byType(Wrap),
          ),
        ),
        findsOneWidget,
        reason: 'the footer joins the scroll below the boundary',
      );
      expect(
        find.descendant(
          of: find.byType(SingleChildScrollView),
          matching: find.byType(PocketTriggerChip),
        ),
        findsOneWidget,
        reason: 'the chip follows the footer into the scroll fallback',
      );
    });

    testWidgets('a body shorter than the grown chip reflows all chrome '
        'without overflow', (tester) async {
      tester.platformDispatcher.textScaleFactorTestValue = 2.0;
      addTearDown(tester.platformDispatcher.clearAllTestValues);
      await tester.binding.setSurfaceSize(const ui.Size(320, 100));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final store = _RecordingStore();
      await launchAndCommit(tester, store);

      expect(tester.takeException(), isNull);
      final scrollable = find.byType(Scrollable);
      expect(
        find.descendant(
          of: find.byType(SingleChildScrollView),
          matching: find.byType(PocketTriggerChip),
        ),
        findsOneWidget,
      );
      for (final label in [
        AppStringsEs().actionStop,
        AppStringsEs().newProjectLink,
      ]) {
        final target = find.text(label);
        await tester.scrollUntilVisible(target, 200, scrollable: scrollable);
        final rect = _rect(tester, target);
        expect(rect.top, greaterThanOrEqualTo(0));
        expect(rect.bottom, lessThanOrEqualTo(100));
      }
      expect(tester.takeException(), isNull);
    });

    testWidgets('the stop stands on the empty frame of a short surface '
        'too — the reflow keeps it present in every rendered state', (
      tester,
    ) async {
      tester.platformDispatcher.textScaleFactorTestValue = 2.0;
      addTearDown(tester.platformDispatcher.clearAllTestValues);
      await tester.binding.setSurfaceSize(const ui.Size(320, 220));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final inner = _RecordingStore();
      await SessionController(
        store: inner,
        strings: AppStringsEs(),
        bundle: _FakeBundle({catalogueAssetPath: shipped}),
        nowOf: _fixedClock,
      ).handleAppOpen();
      final failing = _FailNextAppendStore(inner);
      await tester.pumpWidget(_harness(buildController(failing)));
      await tester.pumpAndSettle();
      expect(find.byType(TaskCard), findsOneWidget);
      // The band is below the fold on this class — scroll it into view
      // before the tap.
      await tester.scrollUntilVisible(
        find.text('Quiero parar'),
        200,
        scrollable: find.byType(Scrollable),
      );

      failing.failNextAppend = true;
      await tester.tap(find.text('Quiero parar'));
      await tester.pumpAndSettle();

      // The empty frame stands — and the stop is still on it, inside
      // the scroll region, whole and reachable.
      expect(find.byType(TaskCard), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.scrollUntilVisible(
        find.text('Quiero parar'),
        200,
        scrollable: find.byType(Scrollable),
      );
      expect(find.text('Quiero parar'), findsOneWidget);
      expect(find.byType(ErrorWidget), findsNothing);
    });

    testWidgets('the warm close on a short surface keeps both footer '
        'controls — the joined band renders on the closed view too (the '
        'stop is present in every rendered state)', (tester) async {
      tester.platformDispatcher.textScaleFactorTestValue = 2.0;
      addTearDown(tester.platformDispatcher.clearAllTestValues);
      await tester.binding.setSurfaceSize(const ui.Size(320, 220));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final store = _RecordingStore();
      await launchAndCommit(tester, store);

      // From the dealt view: pause — scrolling the stop into view
      // first, as this class's band lives below the fold.
      await tester.scrollUntilVisible(
        find.text('Quiero parar'),
        200,
        scrollable: find.byType(Scrollable),
      );
      await tester.tap(find.text('Quiero parar'));
      await tester.pumpAndSettle();

      expect(
        store.entries.where((entry) => entry.kind == 'session_ended'),
        hasLength(1),
      );
      expect(find.text(AppStringsEs().poolExhaustedClose), findsOneWidget);
      expect(find.byType(TaskCard), findsNothing);
      expect(tester.takeException(), isNull);

      // The closed view's joined band still carries both footer texts —
      // whole, never truncated, reachable inside the scroll region's
      // viewport.
      final screen = tester.getSize(find.byType(Scaffold));
      for (final label in [
        AppStringsEs().actionStop,
        AppStringsEs().newProjectLink,
      ]) {
        final target = find.text(label);
        expect(target, findsOneWidget);
        final widget = tester.widget<Text>(target);
        expect(widget.maxLines, isNull);
        expect(widget.overflow, isNot(TextOverflow.ellipsis));
        await tester.scrollUntilVisible(
          target,
          200,
          scrollable: find.byType(Scrollable),
        );
        final rect = _rect(tester, target);
        expect(rect.top, greaterThanOrEqualTo(0));
        expect(rect.bottom, lessThanOrEqualTo(screen.height));
      }
      expect(tester.takeException(), isNull);
    });

    testWidgets('the 320×220 @200% class lays out with zero overflow and '
        'both footer tap targets lay out inside the viewport (the '
        'Story-2.2 pinned surface; never retargeted)', (tester) async {
      tester.platformDispatcher.textScaleFactorTestValue = 2.0;
      addTearDown(tester.platformDispatcher.clearAllTestValues);
      await tester.binding.setSurfaceSize(const ui.Size(320, 220));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final store = _RecordingStore();
      await launchAndCommit(tester, store);

      // Zero RenderFlex overflow on the pinned class: the grown chrome
      // (chip + band) outgrows the 220 body, so the band has joined
      // the scroll region — the floor outranks the pin, never the
      // reverse.
      expect(tester.takeException(), isNull);
      final screen = tester.getSize(find.byType(Scaffold));
      expect(screen.height, 220);
      // The chip stands as the pinned chrome that remains, inside the
      // viewport.
      final chipRect = _rect(tester, find.byType(PocketTriggerChip));
      expect(chipRect.top, greaterThanOrEqualTo(0));
      expect(chipRect.bottom, lessThanOrEqualTo(screen.height));

      // Both footer tap targets lay out inside the viewport: they are
      // part of the scrollable viewport's content — reachable, whole,
      // never truncated — and scroll into view.
      final scrollable = find.byType(Scrollable);
      expect(
        tester.state<ScrollableState>(scrollable).position.maxScrollExtent,
        greaterThan(0),
        reason: 'the grown card scrolls between the chip and the band',
      );
      for (final label in [
        AppStringsEs().actionStop,
        AppStringsEs().newProjectLink,
      ]) {
        final target = find.text(label);
        expect(target, findsOneWidget);
        final widget = tester.widget<Text>(target);
        expect(widget.maxLines, isNull);
        expect(widget.overflow, isNot(TextOverflow.ellipsis));
        await tester.scrollUntilVisible(target, 200, scrollable: scrollable);
        final rect = _rect(tester, target);
        expect(rect.top, greaterThanOrEqualTo(0));
        expect(rect.bottom, lessThanOrEqualTo(screen.height));
      }
      expect(tester.takeException(), isNull);
    });
  });

  group('the checkpoint offer (Story 2.4, FR-10, UX-DR44/51)', () {
    /// A seeded pocketed session start, as a declaration or a process
    /// death would have left it — the start instant injectable so a
    /// pocket sits elapsed or unelapsed at the fixed 12:00 clock. The
    /// sitting is seeded beside week 1389's report answered — the week
    /// a Saturday read judges due — so the strip below the offer keeps
    /// holding the check-in exactly as Story 2.5 shipped it.
    void seedPocketedStart(
      _RecordingStore store,
      int pocketMinutes, {
      DateTime? at,
    }) {
      store.entries.add((
        id: 'seed-week-answered',
        kind: 'report_answered',
        instantUtcMicros: DateTime.utc(2026, 8, 23, 12).microsecondsSinceEpoch,
        offsetSeconds: 0,
        itemId: null,
        itemOrigin: null,
        stack: null,
        settingKey: null,
        settingValue: null,
        pocketMinutes: null,
        energyLevel: null,
        reportValue: 3,
        reportWeek: 1389,
      ));
      store.entries.add((
        id: 'seed-pocket',
        kind: 'session_started',
        instantUtcMicros:
            (at ?? DateTime.utc(2026, 8, 29, 11)).microsecondsSinceEpoch,
        offsetSeconds: 0,
        itemId: null,
        itemOrigin: null,
        stack: null,
        settingKey: null,
        settingValue: null,
        pocketMinutes: pocketMinutes,
        energyLevel: null,
        reportValue: null,
        reportWeek: null,
      ));
    }

    /// A sitting seeded 40 minutes into a 45-minute pocket at the
    /// fixed clock: unelapsed (deadline 12:05), the first multiple
    /// crossed — the controller's read resolves the rest offer.
    Future<_RecordingStore> seedOfferSitting(WidgetTester tester) async {
      final store = _RecordingStore();
      seedPocketedStart(store, 45, at: DateTime.utc(2026, 8, 29, 11, 20));
      await tester.pumpWidget(_harness(buildController(store)));
      await tester.pumpAndSettle();
      return store;
    }

    testWidgets('the offer renders both strings — Nada más por el '
        'momento as the primary permission, Quiero seguir as the '
        'silent secondary — and nothing else (no question, no count, '
        'UJ-1, UX-DR44)', (tester) async {
      await seedOfferSitting(tester);

      expect(find.text('Nada más por el momento'), findsOneWidget);
      expect(find.text('Quiero seguir'), findsOneWidget);
      expect(find.byType(TaskCard), findsNothing);
      expect(find.byType(DurationChip), findsNothing);
      expect(find.byType(ErrorWidget), findsNothing);
      // The chip carries the standing declared pocket, lifted
      // extensions and all.
      expect(find.text('Tengo 45 minutos ahora'), findsOneWidget);
      // No continuation question exists anywhere (FR-10) — the only
      // ¿-sentence the surface may carry is the ambient strip's own
      // check-in question below the offer (Story 2.5), never a
      // ¿seguimos-shaped ask.
      final questionTexts = tester
          .widgetList<Text>(find.textContaining('¿'))
          .map((text) => text.data)
          .toSet();
      expect(questionTexts, {'¿Cuánta energía tienes hoy?'});
    });

    testWidgets('the continue is never primary: prose in the unsplit '
        'secondary grammar, while the stop holds the Done button\'s '
        'register — never filled, never emphasized', (tester) async {
      await seedOfferSitting(tester);

      // The stop is the one filled primary on the surface.
      final stop = find.text('Nada más por el momento');
      final stopStyle = tester.widget<Text>(stop).style!;
      // bodyLarge — the wired action-primary role (theme.dart).
      expect(stopStyle.fontSize, TypeRoles.actionPrimary.fontSize);
      expect(stopStyle.color, FieldPalette.inkPrimary);
      final stopButton = tester.widget<HechoButton>(
        find.ancestor(of: stop, matching: find.byType(HechoButton)),
      );
      expect(stopButton.label, AppStringsEs().checkpointStop);

      // The continue is a SecondaryTextAction: ink-secondary prose in
      // a 48dp opaque band, no fill of its own.
      final secondary = find.byWidgetPredicate(
        (widget) =>
            widget is SecondaryTextAction &&
            widget.label == AppStringsEs().checkpointContinue,
      );
      expect(secondary, findsOneWidget);
      final continueStyle = tester
          .widget<Text>(find.text('Quiero seguir'))
          .style!;
      expect(continueStyle.color, FieldPalette.inkSecondary);
      expect(continueStyle.fontFamily, FontFamilies.lexend);
      expect(
        continueStyle.fontSize,
        TypeRoles.actionSecondary.fontSize,
        reason:
            'bodyMedium, the action-secondary role — never the '
            'primary register',
      );
      // The tap band, not the glyphs, holds the 48dp floor.
      final target = _rect(tester, secondary);
      expect(target.height, greaterThanOrEqualTo(48));
      expect(
        tester
            .widget<GestureDetector>(
              find.descendant(
                of: secondary,
                matching: find.byType(GestureDetector),
              ),
            )
            .behavior,
        HitTestBehavior.opaque,
      );
    });

    testWidgets('the offer\'s stop is one tap: Nada más por el momento '
        'runs the pause write — exactly one session_ended, the warm '
        'close commits, silence everywhere', (tester) async {
      final store = await seedOfferSitting(tester);
      final calls = _mockPlatformCalls(tester);

      await tester.tap(find.text('Nada más por el momento'));
      await tester.pumpAndSettle();

      expect(
        store.entries.where((entry) => entry.kind == 'session_ended'),
        hasLength(1),
      );
      expect(
        store.entries.where((entry) => entry.kind == 'session_extended'),
        isEmpty,
        reason:
            'the stop appended nothing but the close row: the '
            'multiple stays standing for the next sitting',
      );
      expect(find.text(AppStringsEs().poolExhaustedClose), findsOneWidget);
      expect(find.byType(TaskCard), findsNothing);
      expect(_hapticImpacts(calls), isEmpty);
      expect(find.byType(SnackBar), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('the offer\'s continue is silent: Quiero seguir appends '
        'exactly one session_extended{15}, no haptic, and the card '
        'returns — never re-dealt', (tester) async {
      final store = await seedOfferSitting(tester);
      // A standing card dealt into the pending offer (cumulative 17).
      store.entries.add((
        id: 'seed-deal',
        kind: 'card_dealt',
        instantUtcMicros: DateTime.utc(
          2026,
          8,
          29,
          11,
          37,
        ).microsecondsSinceEpoch,
        offsetSeconds: 0,
        itemId: 'pasar-la-aspiradora-a-la-cocina',
        itemOrigin: Origin.shipped,
        stack: null,
        settingKey: null,
        settingValue: null,
        pocketMinutes: null,
        energyLevel: null,
        reportValue: null,
        reportWeek: null,
      ));
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpWidget(_harness(buildController(store)));
      await tester.pumpAndSettle();
      expect(find.text('Nada más por el momento'), findsOneWidget);

      final calls = _mockPlatformCalls(tester);
      await tester.tap(find.text('Quiero seguir'));
      await tester.pumpAndSettle();

      expect(
        store.entries.where((entry) => entry.kind == 'session_extended'),
        hasLength(1),
      );
      final extended = store.entries.lastWhere(
        (entry) => entry.kind == 'session_extended',
      );
      expect(extended.pocketMinutes, 15);
      // The standing card returned to the surface — one deal row only,
      // never re-dealt (FR-10).
      expect(
        store.entries.where((entry) => entry.kind == 'card_dealt'),
        hasLength(1),
      );
      expect(find.byType(TaskCard), findsOneWidget);
      expect(
        find.text('Tengo 60 minutos ahora'),
        findsOneWidget,
        reason: 'the chip reads the lifted pocket',
      );
      expect(_hapticImpacts(calls), isEmpty);
      expect(find.text('¡Buen trabajo!'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a failed continue leaves the quiet empty frame — no '
        'error surface, nothing landed — and a later continue still '
        'works (the in-flight guard was released)', (tester) async {
      final inner = _RecordingStore();
      seedPocketedStart(inner, 45, at: DateTime.utc(2026, 8, 29, 11, 20));
      final failing = _FailNextAppendStore(inner);
      await tester.pumpWidget(_harness(buildController(failing)));
      await tester.pumpAndSettle();
      expect(find.text('Nada más por el momento'), findsOneWidget);

      failing.failNextAppend = true;
      await tester.tap(find.text('Quiero seguir'));
      await tester.pumpAndSettle();

      expect(find.text('Nada más por el momento'), findsNothing);
      expect(find.text('Quiero seguir'), findsNothing);
      expect(find.byType(TaskCard), findsNothing);
      expect(find.byType(ErrorWidget), findsNothing);
      expect(find.byType(SnackBar), findsNothing);
      expect(
        inner.entries.where((entry) => entry.kind == 'session_extended'),
        isEmpty,
        reason: 'the log stayed consistent: nothing landed',
      );

      // Continue is content, not footer chrome: the empty frame has
      // no Quiero seguir. A real return to the foreground re-reads
      // the still-pending offer (the declare-fail recovery).
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pumpAndSettle();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(find.text('Quiero seguir'), findsOneWidget);

      await tester.tap(find.text('Quiero seguir'));
      await tester.pumpAndSettle();
      expect(
        inner.entries.where((entry) => entry.kind == 'session_extended'),
        hasLength(1),
      );
      expect(find.byType(TaskCard), findsOneWidget);
      expect(find.byType(ErrorWidget), findsNothing);
    });

    testWidgets('the pocket-elapsed close is the offer: Quiero seguir '
        'stands beneath the warm string while the pool could deal, '
        'and its tap extends and deals (UJ-1)', (tester) async {
      final store = _RecordingStore();
      // Seeded 11:45 with 15 minutes: the close and the checkpoint
      // coincide exactly at the fixed clock.
      seedPocketedStart(store, 15, at: DateTime.utc(2026, 8, 29, 11, 45));
      await tester.pumpWidget(_harness(buildController(store)));
      await tester.pumpAndSettle();

      expect(find.text(AppStringsEs().poolExhaustedClose), findsOneWidget);
      expect(find.text('Quiero seguir'), findsOneWidget);
      expect(find.text('Nada más por el momento'), findsNothing);
      expect(find.byType(TaskCard), findsNothing);

      await tester.tap(find.text('Quiero seguir'));
      await tester.pumpAndSettle();

      expect(
        store.entries.where((entry) => entry.kind == 'session_extended'),
        hasLength(1),
      );
      expect(
        store.entries.where((entry) => entry.kind == 'card_dealt'),
        hasLength(1),
        reason: 'close-continue mints the deal so Hecho can land (AD-3)',
      );
      expect(find.byType(TaskCard), findsOneWidget);
      expect(find.text('Tengo 30 minutos ahora'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a pool-exhausted close carries nothing: no continue '
        'action exists to tap', (tester) async {
      final store = _RecordingStore();
      seedPocketedStart(store, 15, at: DateTime.utc(2026, 8, 29, 11, 45));
      await tester.pumpWidget(
        _harness(
          buildController(
            store,
            bundle: _FakeBundle({
              catalogueAssetPath: '{"version":1,"entries":[]}',
            }),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text(AppStringsEs().poolExhaustedClose), findsOneWidget);
      expect(find.text('Quiero seguir'), findsNothing);
      expect(find.byType(ErrorWidget), findsNothing);
    });

    testWidgets('the extension\'s commit lands last: a read resolving '
        'mid-extension cannot outrun it — the tap\'s generation bump, '
        'on the continue (_readGeneration)', (tester) async {
      final first = Completer<DispenserView>();
      final second = Completer<DispenserView>();
      final controller = _QueuedExtendController([first, second]);

      await tester.pumpWidget(_harness(controller));
      await tester.pump();
      first.complete(const DispenserRestOffer());
      await tester.pumpAndSettle();
      expect(find.text('Nada más por el momento'), findsOneWidget);

      // The continue tap starts its write (generation bumped) while a
      // real return to the foreground fires its own refresh read —
      // the two now race for the surface.
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump();
      await tester.tap(find.text('Quiero seguir'));
      await tester.pump();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      expect(find.text('Nada más por el momento'), findsNothing);

      // The refresh's read resolves while the extension is still in
      // flight; the extension's own commit then lands on top — the
      // surface ends on the extension's truth, never on the
      // interleaved read's.
      second.complete(const DispenserDealt(_longCard));
      await tester.pump();
      await tester.pump();
      expect(find.text(_longCard.name), findsOneWidget);

      controller.extendView.complete(const DispenserRestOffer());
      await tester.pump();
      await tester.pump();
      expect(find.text('Nada más por el momento'), findsOneWidget);
      expect(find.byType(TaskCard), findsNothing);
    });

    testWidgets('the 320×220 @200% offer: the surface grows and '
        'scrolls, both actions whole and reachable, zero overflow (the '
        'short-surface floor)', (tester) async {
      tester.platformDispatcher.textScaleFactorTestValue = 2.0;
      addTearDown(tester.platformDispatcher.clearAllTestValues);
      await tester.binding.setSurfaceSize(const ui.Size(320, 220));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final store = await seedOfferSitting(tester);

      expect(tester.takeException(), isNull);
      final screen = tester.getSize(find.byType(Scaffold));
      expect(screen.height, 220);
      for (final label in ['Nada más por el momento', 'Quiero seguir']) {
        final target = find.text(label);
        expect(target, findsOneWidget);
        final widget = tester.widget<Text>(target);
        expect(widget.maxLines, isNull);
        expect(widget.overflow, isNot(TextOverflow.ellipsis));
        await tester.scrollUntilVisible(
          target,
          200,
          scrollable: find.byType(Scrollable),
        );
        final rect = _rect(tester, target);
        expect(rect.top, greaterThanOrEqualTo(0));
        expect(rect.bottom, lessThanOrEqualTo(screen.height));
      }
      // The continue is tappable at the floor: its tap lands the
      // extension and the card returns.
      await tester.pumpAndSettle();
      await tester.tap(find.text('Quiero seguir'));
      await tester.pumpAndSettle();
      expect(
        store.entries.where((entry) => entry.kind == 'session_extended'),
        hasLength(1),
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('a refresh read started before the continue tap cannot '
        'overwrite the committed extension — the pause race\'s mirror, '
        'on the continue (_readGeneration)', (tester) async {
      final first = Completer<DispenserView>();
      final second = Completer<DispenserView>();
      final controller = _QueuedExtendController([first, second]);

      await tester.pumpWidget(_harness(controller));
      await tester.pump();
      first.complete(const DispenserRestOffer());
      await tester.pumpAndSettle();
      expect(find.text('Nada más por el momento'), findsOneWidget);

      // The committed offer's continue callback, captured from the
      // tree — the stale-callback pattern: the control lives in the
      // content arm, which a refresh clears before its read resolves.
      final onExtend = tester
          .widget<SecondaryTextAction>(
            find.byWidgetPredicate(
              (widget) =>
                  widget is SecondaryTextAction &&
                  widget.label == AppStringsEs().checkpointContinue,
            ),
          )
          .onTap!;

      // A foreground refresh starts reading (generation 2) — its read
      // hangs and the surface is the empty frame.
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();

      // The stale callback still commits its extension — the tap's
      // bump makes the surface generation 3 — and the card returns.
      onExtend();
      await tester.pump();
      controller.extendView.complete(const DispenserDealt(_testCard));
      await tester.pump();
      await tester.pump();
      expect(find.text(_testCard.name), findsOneWidget);

      // The stale read lands last carrying the offer: its generation
      // (2) is no longer the surface's — dropped, the card stands.
      second.complete(const DispenserRestOffer());
      await tester.pumpAndSettle();
      expect(find.text(_testCard.name), findsOneWidget);
      expect(find.text('Nada más por el momento'), findsNothing);
      expect(find.byType(TaskCard), findsOneWidget);
    });

    testWidgets('a long-elapsed close carries no continue — the chip '
        'is the way back in, never a dead action', (tester) async {
      final store = _RecordingStore();
      // A 15-pocket started 11:05: elapsed at 11:20, forty minutes
      // past at the fixed clock — one interval cannot reach.
      seedPocketedStart(store, 15, at: DateTime.utc(2026, 8, 29, 11, 5));
      await tester.pumpWidget(_harness(buildController(store)));
      await tester.pumpAndSettle();

      expect(find.text(AppStringsEs().poolExhaustedClose), findsOneWidget);
      expect(find.text('Quiero seguir'), findsNothing);
      // The chip keeps the declared pocket: the ladder back in.
      expect(find.text('Tengo 15 minutos ahora'), findsOneWidget);
      expect(find.byType(ErrorWidget), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });
}

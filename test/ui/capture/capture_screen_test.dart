// The Manual Capture surface's contract (Story 3.2, FR-27): one-tap
// reachability from the Dispenser's Lápiz entry in both chrome branches;
// exactly two fields and the verbatim copy in its fixed order; the three
// duration pills, preselected and never naming the taxonomy; the one
// primary and one secondary; `Guardar` disabled until the line holds
// text and writing exactly one manual pool fact plus one
// `capture_created` entry before popping; `Descartar` and the system
// back writing nothing; and non-spatial silence — the textsOf census
// over every state the surface holds.
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:core/ports/recognizer_port.dart';
import 'package:core/ports/store_port.dart';
import 'package:core/pool/pool_fact.dart';
import 'package:flutter/material.dart' hide Card;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:organizer/capture/capture_controller.dart';
import 'package:organizer/capture/dictation_controller.dart';
import 'package:organizer/catalogue/catalogue_names.g.dart';
import 'package:organizer/dispenser/dispenser_controller.dart';
import 'package:organizer/strings/app_strings.dart';
import 'package:organizer/strings/app_strings_es.dart';
import 'package:organizer/ui/capture/capture_screen.dart';
import 'package:organizer/ui/dispenser/dispenser_screen.dart';
import 'package:organizer/ui/dispenser/duration_chip.dart';
import 'package:organizer/ui/glyphs/microphone_glyph.dart';
import 'package:organizer/ui/glyphs/pencil_glyph.dart';
import 'package:organizer/ui/theme.dart';

/// The recording store (the settings suite's own contract): appends
/// land in order and every read replays them — pool facts included,
/// because a capture is the pool's first shell writer.
class _RecordingStore implements StorePort {
  final List<PoolFactRecord> facts = [];
  final List<LogEntryRecord> entries = [];

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

/// A store whose first `appendPoolFact` throws — the write-failure row:
/// the surface must stay with its line intact, nothing surfaced, and
/// the recovered queue must let the retry land.
class _FailFirstFactStore implements StorePort {
  _FailFirstFactStore(this._inner);

  final _RecordingStore _inner;
  var _thrown = false;

  @override
  Future<void> appendPoolFact(PoolFactRecord fact) async {
    if (!_thrown) {
      _thrown = true;
      throw StateError('append failed');
    }
    await _inner.appendPoolFact(fact);
  }

  @override
  Future<void> appendLogEntry(LogEntryRecord entry) async =>
      _inner.appendLogEntry(entry);

  @override
  Future<List<PoolFactRecord>> readPoolFacts() async => _inner.readPoolFacts();

  @override
  Future<List<LogEntryRecord>> readLogEntries() async =>
      _inner.readLogEntries();
}

/// A store whose first pool-fact append parks on a completer until the
/// test releases it — the `Guardar` write's in-flight window, held open
/// long enough to race the exits against it.
class _GatedSaveStore implements StorePort {
  _GatedSaveStore(this._inner);

  final _RecordingStore _inner;
  final factGate = Completer<void>();

  @override
  Future<void> appendPoolFact(PoolFactRecord fact) async {
    await factGate.future;
    await _inner.appendPoolFact(fact);
  }

  @override
  Future<void> appendLogEntry(LogEntryRecord entry) async =>
      _inner.appendLogEntry(entry);

  @override
  Future<List<PoolFactRecord>> readPoolFacts() async => _inner.readPoolFacts();

  @override
  Future<List<LogEntryRecord>> readLogEntries() async =>
      _inner.readLogEntries();
}

/// A bundle over the shipped asset's exact bytes (the settings suite's
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

/// The dictation-capable recognizer fake (Story 3.4's seam): probe and
/// start outcomes the tests steer, outcomes the tests emit, calls the
/// tests read.
class _FakeRecognizer implements RecognizerPort {
  _FakeRecognizer(this.availability, this.startOutcome);

  RecognizerAvailability availability;
  RecognizerStart startOutcome;
  final List<int> startedSessions = [];
  final List<int> cancelledSessions = [];
  final StreamController<RecognizerOutcome> _outcomes =
      StreamController<RecognizerOutcome>.broadcast();

  void emit(int sessionId, String? transcript) {
    _outcomes.add((sessionId: sessionId, transcript: transcript));
  }

  @override
  Future<RecognizerAvailability> probe() async => availability;

  @override
  Future<RecognizerStart> start(int sessionId) async {
    startedSessions.add(sessionId);
    return startOutcome;
  }

  @override
  Future<void> cancel(int sessionId) async => cancelledSessions.add(sessionId);

  @override
  Stream<RecognizerOutcome> get outcomes => _outcomes.stream;

  @override
  Future<void> openAppSettings() async {}
}

DateTime _fixedClock() => DateTime.utc(2026, 9, 1, 10);

void main() {
  final shipped = File(catalogueAssetPath).readAsStringSync();
  final strings = AppStringsEs();

  Widget harness(StorePort store) {
    return MaterialApp(
      theme: OrganizerTheme.light(),
      localizationsDelegates: AppStrings.localizationsDelegates,
      supportedLocales: AppStrings.supportedLocales,
      home: DispenserScreen(
        controller: DispenserController(
          store: store,
          strings: strings,
          bundle: _ShippedBundle(shipped),
          nowOf: _fixedClock,
        ),
        capture: CaptureController(store: store, nowOf: _fixedClock),
      ),
    );
  }

  Future<void> launch(WidgetTester tester, StorePort store) async {
    await tester.pumpWidget(harness(store));
    await tester.pumpAndSettle();
  }

  /// Opens Manual Capture through the real entry — the Lápiz tap.
  Future<void> openCapture(WidgetTester tester) async {
    await tester.tap(find.byType(PencilGlyph));
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

  /// Whether any Semantics node in the tree declares itself disabled —
  /// the disabled `Guardar`'s own declaration, and nobody else's.
  bool anyDisabledSemantics(WidgetTester tester) => tester
      .widgetList<Semantics>(find.byType(Semantics))
      .any((semantics) => semantics.properties.enabled == false);

  /// The minutes of the size option whose Material carries the selected
  /// fill (the settings suite's selected-option helper, sized for the
  /// capture pills' own labels).
  String? selectedPillLabel(WidgetTester tester) {
    for (final label in [
      strings.durationSeconds(30),
      strings.durationMinutes(3),
      strings.durationFocusRange,
    ]) {
      final text = find.text(label);
      if (text.evaluate().isEmpty) {
        continue;
      }
      final material = find
          .ancestor(of: text, matching: find.byType(Material))
          .first;
      final color = tester.widget<Material>(material).color;
      if (color == OrganizerTheme.light().colorScheme.primary) {
        return label;
      }
    }
    return null;
  }

  testWidgets('the Lápiz entry sits top-right at ≥48dp and one tap opens '
      'Manual Capture — in both chrome branches, pastel never under the '
      'glyph (FR-27)', (tester) async {
    final store = _RecordingStore();
    await launch(tester, store);

    // The entry's 48dp target — the glyph zone the chip must clear.
    Finder entryTarget(Finder lapiz) =>
        find.ancestor(of: lapiz, matching: find.byType(Semantics)).first;

    // Pinned chrome: the entry is in the top band, the chip keeps the
    // screen's exact centre, the glyph target holds 48dp, and the
    // chip's pastel stops clear of the glyph zone — two controls, never
    // one passing beneath the other.
    final lapiz = find.byType(PencilGlyph);
    expect(lapiz, findsOneWidget);
    final lapizRect = tester.getRect(lapiz);
    final chipRect = tester.getRect(find.byType(PocketTriggerChip));
    final screen = tester.view.physicalSize / tester.view.devicePixelRatio;
    expect(chipRect.center.dx, closeTo(screen.width / 2, 0.5));
    expect(
      lapizRect.center.dx,
      greaterThan(chipRect.center.dx),
      reason: 'the entry sits top-right of the centred chip',
    );
    expect(lapizRect.right, lessThanOrEqualTo(screen.width));
    final target = tester.getRect(entryTarget(lapiz));
    expect(target.width, greaterThanOrEqualTo(48));
    expect(target.height, greaterThanOrEqualTo(48));
    expect(
      tester.widget<Semantics>(entryTarget(lapiz)).properties.label,
      strings.lapizEntry,
    );
    expect(
      chipRect.right,
      lessThan(target.left),
      reason: 'the chip wraps before reaching the glyph zone',
    );

    await openCapture(tester);
    expect(find.byType(CaptureScreen), findsOneWidget);
    // Nothing was written by the way in: navigation is pure reading.
    expect(store.facts, isEmpty);
    expect(store.entries, isEmpty);

    // System back behaves as Descartar: the route pops, still no writes.
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byType(CaptureScreen), findsNothing);
    expect(store.facts, isEmpty);
    expect(store.entries, isEmpty);

    // In-frame chrome (the short-surface floor): the entry joins the
    // scroll region together with the chip and stays a whole target.
    tester.platformDispatcher.textScaleFactorTestValue = 2.0;
    addTearDown(tester.platformDispatcher.clearAllTestValues);
    await tester.binding.setSurfaceSize(const ui.Size(320, 300));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpWidget(harness(store));
    await tester.pumpAndSettle();
    final inFrameLapiz = find.byType(PencilGlyph);
    expect(inFrameLapiz, findsOneWidget);
    final inFrameTarget = tester.getRect(entryTarget(inFrameLapiz));
    expect(inFrameTarget.width, greaterThanOrEqualTo(48));
    expect(inFrameTarget.height, greaterThanOrEqualTo(48));
    await openCapture(tester);
    expect(find.byType(CaptureScreen), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    // 200% on the default surface: the chip grows and wraps inside its
    // inner bounds, still centred and still clear of the glyph zone.
    await tester.binding.setSurfaceSize(null);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpWidget(harness(store));
    await tester.pumpAndSettle();
    final grownChip = tester.getRect(find.byType(PocketTriggerChip));
    final grownTarget = tester.getRect(entryTarget(find.byType(PencilGlyph)));
    expect(grownChip.center.dx, closeTo(screen.width / 2, 0.5));
    expect(
      grownChip.right,
      lessThan(grownTarget.left),
      reason: 'at 200% the wrapped chip still stops clear of the glyph',
    );
  });

  testWidgets('the surface holds exactly two fields, its copy in the fixed '
      'order, and nothing that mentions dates (FR-27, the spatial frame)', (
    tester,
  ) async {
    final store = _RecordingStore();
    await launch(tester, store);
    await openCapture(tester);

    // Exactly two fields: one single-line text field, one size from
    // exactly three pills — no project, category, date, priority, tags
    // or recurrence control of any kind.
    expect(find.byType(TextField), findsOneWidget);
    final pills = [
      strings.durationSeconds(30),
      strings.durationMinutes(3),
      strings.durationFocusRange,
    ];
    for (final pill in pills) {
      expect(find.text(pill), findsOneWidget);
    }

    // The census: exactly the seven authored strings plus the three
    // duration pills (the Text/RichText channels double-report one
    // widget, so the census reads a set). Nothing else renders — no
    // counter, no confirmation, no error channel, no second exit.
    expect(textsOf(tester).toSet(), {
      strings.captureTitle,
      strings.captureHelper,
      strings.captureExample,
      strings.captureFieldPlaceholder,
      ...pills,
      strings.captureSave,
      strings.captureDiscard,
    });

    // Reading order, top to bottom: title (a place), helper (touchable
    // things), example (spatial verb), field, sizes, save, discard.
    double topOf(Finder finder) => tester.getTopLeft(finder).dy;
    final title = find.text(strings.captureTitle);
    final helper = find.text(strings.captureHelper);
    final example = find.text(strings.captureExample);
    final field = find.byType(TextField);
    final sizes = find.text(strings.durationSeconds(30));
    final save = find.text(strings.captureSave);
    final discard = find.text(strings.captureDiscard);
    expect(topOf(title), lessThan(topOf(helper)));
    expect(topOf(helper), lessThan(topOf(example)));
    expect(topOf(example), lessThan(topOf(field)));
    expect(topOf(field), lessThan(topOf(sizes)));
    expect(topOf(sizes), lessThan(topOf(save)));
    expect(topOf(save), lessThan(topOf(discard)));

    // One primary, one secondary, no Cancelar anywhere.
    expect(find.text('Cancelar'), findsNothing);
    expect(find.text(strings.captureSave), findsOneWidget);
    expect(find.text(strings.captureDiscard), findsOneWidget);
  });

  testWidgets('the pills show durations only, one preselected, '
      'single-selection, and a tap moves the mark (FR-27)', (tester) async {
    final store = _RecordingStore();
    await launch(tester, store);
    await openCapture(tester);

    // Preselected: maintenance, per the canonical mockup — always
    // populated, no empty state, never a taxonomy name.
    expect(selectedPillLabel(tester), strings.durationMinutes(3));
    expect(find.text('maintenance'), findsNothing);
    expect(find.text('instant'), findsNothing);
    expect(find.text('focus'), findsNothing);

    // Exactly one selected semantics node among the pills.
    final marked = tester
        .widgetList<Semantics>(find.byType(Semantics))
        .where((semantics) => semantics.properties.selected ?? false)
        .toList();
    expect(marked, hasLength(1));

    // A tap moves the selection — single-selection, never additive.
    await tester.tap(find.text(strings.durationFocusRange));
    await tester.pumpAndSettle();
    expect(selectedPillLabel(tester), strings.durationFocusRange);
    final markedAfter = tester
        .widgetList<Semantics>(find.byType(Semantics))
        .where((semantics) => semantics.properties.selected ?? false)
        .toList();
    expect(markedAfter, hasLength(1));

    // Every pill holds the 48dp floor.
    for (final pill in [
      strings.durationSeconds(30),
      strings.durationMinutes(3),
      strings.durationFocusRange,
    ]) {
      final material = find
          .ancestor(of: find.text(pill), matching: find.byType(Material))
          .first;
      expect(tester.getRect(material).height, greaterThanOrEqualTo(48));
    }
  });

  testWidgets('Guardar stays disabled until the trimmed line holds text — '
      'a tap does nothing and appends nothing (FR-27)', (tester) async {
    final store = _RecordingStore();
    await launch(tester, store);
    await openCapture(tester);

    // Blank: disabled, declared so to readers, refusing the tap.
    expect(anyDisabledSemantics(tester), isTrue);
    // A raw tap at the control's own centre: the disabled pill must
    // refuse it — nothing observable, nothing appended.
    await tester.tapAt(tester.getCenter(find.text(strings.captureSave)));
    await tester.pumpAndSettle();
    expect(find.byType(CaptureScreen), findsOneWidget);
    expect(store.facts, isEmpty);
    expect(store.entries, isEmpty);

    // Whitespace-only is still blank after trimming.
    await tester.enterText(find.byType(TextField), '   \t ');
    await tester.pumpAndSettle();
    expect(anyDisabledSemantics(tester), isTrue);
    // A raw tap at the control's own centre: the disabled pill must
    // refuse it — nothing observable, nothing appended.
    await tester.tapAt(tester.getCenter(find.text(strings.captureSave)));
    await tester.pumpAndSettle();
    expect(find.byType(CaptureScreen), findsOneWidget);
    expect(store.facts, isEmpty);
    expect(store.entries, isEmpty);

    // Text lands: enabled, and no disabled node remains anywhere.
    await tester.enterText(find.byType(TextField), 'llamar al dentista');
    await tester.pumpAndSettle();
    expect(anyDisabledSemantics(tester), isFalse);
    // Blank again after clearing: disabled again — the state follows
    // the line, never a memory of it.
    await tester.enterText(find.byType(TextField), '');
    await tester.pumpAndSettle();
    expect(anyDisabledSemantics(tester), isTrue);
    expect(store.facts, isEmpty);
    expect(store.entries, isEmpty);
  });

  testWidgets('Guardar writes exactly one manual fact and one '
      'capture_created entry sharing the batch instant, the entry naming '
      'the fact — then the route pops (FR-27)', (tester) async {
    final store = _RecordingStore();
    await launch(tester, store);
    await openCapture(tester);

    // A pasted multi-line string is one line by the time the field
    // holds it: the single-line formatter strips the interior newline
    // on entry, so the stored Origin Context can never carry one.
    const pasted = '  llamar al dentista\ny una idea pegada \t ';
    await tester.enterText(find.byType(TextField), pasted);
    await tester.pump();
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      isNot(contains('\n')),
    );
    await tester.tap(find.text(strings.durationFocusRange));
    await tester.pumpAndSettle();
    await tester.tap(find.text(strings.captureSave));
    await tester.pumpAndSettle();

    // The route popped: the write completed first, and the surface's
    // whole remaining duty was to leave.
    expect(find.byType(CaptureScreen), findsNothing);

    // Exactly one pool fact: manual origin, the chosen size, the
    // trimmed line as its whole Origin Context — one line, the paste's
    // newline stripped at the input boundary, padding trimmed by the
    // command, both rows stamped with the tap's nowOf().
    expect(store.facts, hasLength(1));
    final fact = store.facts.single;
    expect(fact.origin, Origin.manual);
    expect(fact.size, Size.focus);
    expect(fact.originContext, isNot(contains('\n')));
    expect(fact.originContext, 'llamar al dentistay una idea pegada');
    expect(fact.instantUtcMicros, _fixedClock().microsecondsSinceEpoch);
    expect(fact.offsetSeconds, _fixedClock().timeZoneOffset.inSeconds);

    // Exactly one capture_created entry: its item pair names the fact,
    // nothing else rides it, and it shares the fact's batch instant.
    expect(store.entries, hasLength(1));
    final entry = store.entries.single;
    expect(entry.kind, 'capture_created');
    expect(entry.itemId, fact.id);
    expect(entry.itemOrigin, Origin.manual);
    expect(entry.instantUtcMicros, fact.instantUtcMicros);
    expect(entry.instantUtcMicros, _fixedClock().microsecondsSinceEpoch);
    expect(entry.stack, isNull);
    expect(entry.settingKey, isNull);
    expect(entry.pocketMinutes, isNull);
    expect(entry.energyLevel, isNull);
    expect(entry.reportValue, isNull);
    expect(entry.reportWeek, isNull);

    // Nothing celebratory or corrective appeared on the way out.
    expect(find.byType(SnackBar), findsNothing);
    expect(find.byType(ErrorWidget), findsNothing);
  });

  testWidgets('a rapid double-tap on Guardar appends exactly one fact and '
      'one entry — the in-flight guard holds', (tester) async {
    final store = _RecordingStore();
    await launch(tester, store);
    await openCapture(tester);

    await tester.enterText(find.byType(TextField), 'regar las plantas');
    await tester.tap(find.text(strings.durationSeconds(30)));
    // One frame first: the enabled button must exist in the render tree
    // before the tap — the second tap then lands while the write is in
    // flight, with no settle between.
    await tester.pump();
    await tester.tap(find.text(strings.captureSave));
    // A raw tap at the control's own centre: the disabled pill must
    // refuse it — nothing observable, nothing appended.
    await tester.tapAt(tester.getCenter(find.text(strings.captureSave)));
    await tester.pumpAndSettle();

    expect(find.byType(CaptureScreen), findsNothing);
    expect(store.facts, hasLength(1));
    expect(store.facts.single.size, Size.instant);
    expect(store.entries, hasLength(1));
  });

  testWidgets('neither Descartar nor the system back can exit while a '
      'Guardar write is in flight — the write owns the surface and pops '
      'it itself (FR-27)', (tester) async {
    final inner = _RecordingStore();
    final store = _GatedSaveStore(inner);
    await launch(tester, store);
    await openCapture(tester);

    await tester.enterText(find.byType(TextField), 'regar las plantas');
    await tester.pumpAndSettle();
    await tester.tap(find.text(strings.captureSave));
    // The write is now parked on the gate: the surface is in flight,
    // and nothing has landed yet.
    await tester.pump();
    expect(find.byType(CaptureScreen), findsOneWidget);
    expect(inner.facts, isEmpty);
    expect(inner.entries, isEmpty);

    // Descartar while in flight: the tap is refused — a discard-looking
    // exit must not race the committed save.
    await tester.ensureVisible(find.text(strings.captureDiscard));
    await tester.pumpAndSettle();
    await tester.tap(find.text(strings.captureDiscard));
    await tester.pumpAndSettle();
    expect(find.byType(CaptureScreen), findsOneWidget);

    // The system back gesture while in flight: the same refusal, through
    // the PopScope gate — the route will not pop by gesture.
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byType(CaptureScreen), findsOneWidget);
    expect(inner.facts, isEmpty);

    // The write completes: it lands exactly once, and the Guardar path
    // pops the route on its own.
    store.factGate.complete();
    await tester.pumpAndSettle();
    expect(find.byType(CaptureScreen), findsNothing);
    expect(inner.facts, hasLength(1));
    expect(inner.facts.single.originContext, 'regar las plantas');
    expect(inner.entries, hasLength(1));
    expect(inner.entries.single.kind, 'capture_created');
  });

  testWidgets('Descartar and the system back write nothing, with no '
      'confirmation — the capture belongs to nobody until Guardar '
      '(FR-27)', (tester) async {
    final store = _RecordingStore();
    await launch(tester, store);
    await openCapture(tester);

    await tester.enterText(find.byType(TextField), 'una línea que no salva');
    await tester.tap(find.text(strings.durationFocusRange));
    await tester.pumpAndSettle();
    expect(anyDisabledSemantics(tester), isFalse);

    // The surface scrolls (the 200% floor's own mechanism): the exit
    // may sit below the fold on a short body, and reaching it through
    // the scroll is the honest path.
    await tester.ensureVisible(find.text(strings.captureDiscard));
    await tester.pumpAndSettle();
    await tester.tap(find.text(strings.captureDiscard));
    await tester.pumpAndSettle();
    expect(find.byType(CaptureScreen), findsNothing);
    expect(store.facts, isEmpty);
    expect(store.entries, isEmpty);

    // The back gesture behaves identically: pop, no writes.
    await openCapture(tester);
    await tester.enterText(find.byType(TextField), 'otra línea');
    await tester.pumpAndSettle();
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byType(CaptureScreen), findsNothing);
    expect(store.facts, isEmpty);
    expect(store.entries, isEmpty);
  });

  testWidgets('a non-spatial line is accepted in silence — the same '
      'writes, no error widget, the census unchanged (FR-27)', (tester) async {
    final store = _RecordingStore();
    await launch(tester, store);
    await openCapture(tester);

    final censusBefore = textsOf(tester).toSet();
    await tester.enterText(find.byType(TextField), 'llamar al dentista');
    await tester.pumpAndSettle();

    // Typing a non-spatial line changes nothing the surface shows:
    // no validation, no error state, no corrective message.
    expect(textsOf(tester).toSet(), censusBefore);
    expect(find.byType(ErrorWidget), findsNothing);
    expect(find.byType(SnackBar), findsNothing);

    await tester.tap(find.text(strings.captureSave));
    await tester.pumpAndSettle();

    // And it saves exactly like any other line — the same two rows,
    // the same silence.
    expect(find.byType(CaptureScreen), findsNothing);
    expect(store.facts, hasLength(1));
    expect(store.facts.single.originContext, 'llamar al dentista');
    expect(store.facts.single.size, Size.maintenance);
    expect(store.entries, hasLength(1));
  });

  testWidgets('a failing store append is absorbed quietly: the surface '
      'stays with its line intact and the retry lands (FR-27)', (tester) async {
    final inner = _RecordingStore();
    final store = _FailFirstFactStore(inner);
    await tester.pumpWidget(
      MaterialApp(
        theme: OrganizerTheme.light(),
        localizationsDelegates: AppStrings.localizationsDelegates,
        supportedLocales: AppStrings.supportedLocales,
        home: DispenserScreen(
          controller: DispenserController(
            store: store,
            strings: strings,
            bundle: _ShippedBundle(shipped),
            nowOf: _fixedClock,
          ),
          capture: CaptureController(store: store, nowOf: _fixedClock),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await openCapture(tester);

    await tester.enterText(find.byType(TextField), 'Vaciar la caja');
    await tester.pumpAndSettle();
    await tester.tap(find.text(strings.captureSave));
    await tester.pumpAndSettle();

    // The write failed and landed nothing: the surface stays, the line
    // is intact, nothing is surfaced, and no partial row exists.
    expect(find.byType(CaptureScreen), findsOneWidget);
    expect(find.byType(ErrorWidget), findsNothing);
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      'Vaciar la caja',
    );
    expect(inner.facts, isEmpty);
    expect(inner.entries, isEmpty);

    // The retry is the same tap — and it lands through the recovered
    // queue: exactly one fact, one entry, and the pop.
    await tester.tap(find.text(strings.captureSave));
    await tester.pumpAndSettle();
    expect(find.byType(CaptureScreen), findsNothing);
    expect(inner.facts, hasLength(1));
    expect(inner.entries, hasLength(1));
    expect(inner.facts.single.originContext, 'Vaciar la caja');
  });

  group('the mic capsule and dictation (Story 3.4, FR-32)', () {
    Widget dictationHarness(StorePort store, DictationController dictation) {
      return MaterialApp(
        theme: OrganizerTheme.light(),
        localizationsDelegates: AppStrings.localizationsDelegates,
        supportedLocales: AppStrings.supportedLocales,
        home: DispenserScreen(
          controller: DispenserController(
            store: store,
            strings: strings,
            bundle: _ShippedBundle(shipped),
            nowOf: _fixedClock,
          ),
          capture: CaptureController(store: store, nowOf: _fixedClock),
          dictation: dictation,
        ),
      );
    }

    Future<void> launchWithDictation(
      WidgetTester tester,
      StorePort store,
      DictationController dictation,
    ) async {
      await tester.pumpWidget(dictationHarness(store, dictation));
      await tester.pumpAndSettle();
    }

    testWidgets('the capsule sits at the field\'s end, a 24px glyph inside '
        'a 48dp target, and a press starts listening — declared only by '
        'the blue mass and the Escuchando… caption, never by motion '
        '(FR-32)', (tester) async {
      final store = _RecordingStore();
      final recognizer = _FakeRecognizer(
        RecognizerAvailability.granted,
        RecognizerStart.listening,
      );
      final observers = <WidgetsBindingObserver>[];
      await launchWithDictation(
        tester,
        store,
        DictationController(
          store: store,
          recognizer: recognizer,
          nowOf: _fixedClock,
          addObserver: observers.add,
        ),
      );
      await openCapture(tester);

      // The affordance defaults to absent, then lands with the probe.
      await tester.pumpAndSettle();
      final mic = find.byType(MicrophoneGlyph);
      expect(mic, findsOneWidget);
      final field = find.byType(TextField);
      expect(
        tester.getTopLeft(mic).dx,
        greaterThan(tester.getTopLeft(field).dx),
        reason: 'the capsule sits at the field\'s end',
      );
      final target = tester.getRect(
        find.ancestor(of: mic, matching: find.byType(Semantics)).first,
      );
      expect(target.width, greaterThanOrEqualTo(48));
      expect(target.height, greaterThanOrEqualTo(48));
      expect(tester.widget<MicrophoneGlyph>(mic).size, 24);
      expect(
        tester
            .widget<Semantics>(
              find.ancestor(of: mic, matching: find.byType(Semantics)).first,
            )
            .properties
            .label,
        strings.microphoneEntry,
      );
      // The quiet census before the press: no listening copy renders.
      expect(find.text(strings.dictationListening), findsNothing);
      expect(tester.widget<MicrophoneGlyph>(mic).dictating, isFalse);

      // The press: listening, declared by the caption and the mass.
      await tester.tap(mic);
      await tester.pumpAndSettle();
      expect(recognizer.startedSessions, [1]);
      expect(find.text(strings.dictationListening), findsOneWidget);
      expect(tester.widget<MicrophoneGlyph>(mic).dictating, isTrue);
      // The census grows by exactly the caption — nothing else.
      expect(find.byType(SnackBar), findsNothing);
      expect(find.byType(ErrorWidget), findsNothing);
    });

    testWidgets('the final transcript replaces the line\'s content, '
        'Guardar enables through the existing listener, and a keyboard '
        'correction keeps dictated true — the provenance records who '
        'authored the line (FR-32)', (tester) async {
      final store = _RecordingStore();
      final recognizer = _FakeRecognizer(
        RecognizerAvailability.granted,
        RecognizerStart.listening,
      );
      final observers = <WidgetsBindingObserver>[];
      await launchWithDictation(
        tester,
        store,
        DictationController(
          store: store,
          recognizer: recognizer,
          nowOf: _fixedClock,
          addObserver: observers.add,
        ),
      );
      await openCapture(tester);
      await tester.pumpAndSettle();

      // A typed line the transcript will replace.
      await tester.enterText(find.byType(TextField), 'una idea vieja');
      await tester.pumpAndSettle();

      await tester.tap(find.byType(MicrophoneGlyph));
      await tester.pumpAndSettle();
      recognizer.emit(1, 'llamar cinco minutos al dentista');
      await tester.pumpAndSettle();
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        'llamar cinco minutos al dentista',
        reason: 'the final transcript replaces the line\'s content',
      );
      expect(
        find.text(strings.dictationListening),
        findsNothing,
        reason: 'the capsule returned to rest with the commit',
      );

      // A keyboard correction lands on the dictated line — the
      // keyboard was never removed.
      await tester.enterText(
        find.byType(TextField),
        'llamar diez minutos al dentista',
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text(strings.captureSave));
      await tester.pumpAndSettle();
      expect(find.byType(CaptureScreen), findsNothing);
      expect(store.facts, hasLength(1));
      final fact = store.facts.single;
      expect(fact.origin, Origin.manual);
      expect(fact.originContext, 'llamar diez minutos al dentista');
      expect(fact.dictated, isTrue);
      expect(store.entries, hasLength(1));
      expect(store.entries.single.kind, 'capture_created');
    });

    testWidgets('interruption mid-utterance: no partial transcript lands, '
        'the capsule resets to rest, and no error appears (FR-32)', (
      tester,
    ) async {
      final store = _RecordingStore();
      final recognizer = _FakeRecognizer(
        RecognizerAvailability.granted,
        RecognizerStart.listening,
      );
      final observers = <WidgetsBindingObserver>[];
      await launchWithDictation(
        tester,
        store,
        DictationController(
          store: store,
          recognizer: recognizer,
          nowOf: _fixedClock,
          addObserver: observers.add,
        ),
      );
      await openCapture(tester);
      await tester.pumpAndSettle();

      await tester.tap(find.byType(MicrophoneGlyph));
      await tester.pumpAndSettle();
      expect(find.text(strings.dictationListening), findsOneWidget);

      // The app leaves the foreground mid-utterance.
      (observers.single as DictationController).didChangeAppLifecycleState(
        AppLifecycleState.paused,
      );
      await tester.pumpAndSettle();

      expect(find.text(strings.dictationListening), findsNothing);
      expect(find.byType(MicrophoneGlyph).hitTestable(), findsOneWidget);
      expect(recognizer.cancelledSessions, [1]);

      // The recognizer's late terminal event carries a stale session
      // id: it drops whole — nothing lands on the line.
      recognizer.emit(1, 'media frase');
      await tester.pumpAndSettle();
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        isEmpty,
      );
      expect(find.byType(ErrorWidget), findsNothing);
      expect(find.byType(SnackBar), findsNothing);
      expect(store.facts, isEmpty);
      expect(store.entries, isEmpty);
    });

    testWidgets('a blank final result writes nothing — Guardar stays '
        'disabled through its own guard (FR-32)', (tester) async {
      final store = _RecordingStore();
      final recognizer = _FakeRecognizer(
        RecognizerAvailability.granted,
        RecognizerStart.listening,
      );
      final observers = <WidgetsBindingObserver>[];
      await launchWithDictation(
        tester,
        store,
        DictationController(
          store: store,
          recognizer: recognizer,
          nowOf: _fixedClock,
          addObserver: observers.add,
        ),
      );
      await openCapture(tester);
      await tester.pumpAndSettle();

      await tester.tap(find.byType(MicrophoneGlyph));
      await tester.pumpAndSettle();
      recognizer.emit(1, '  ');
      await tester.pumpAndSettle();

      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        isEmpty,
      );
      expect(anyDisabledSemantics(tester), isTrue);
      expect(store.facts, isEmpty);
      expect(store.entries, isEmpty);
    });

    testWidgets('on-device Spanish unavailable: the affordance is simply '
        'absent — no error, no grey state, no install offer (FR-32, the '
        '3-1 rule)', (tester) async {
      final store = _RecordingStore();
      final recognizer = _FakeRecognizer(
        RecognizerAvailability.unavailable,
        RecognizerStart.unavailable,
      );
      await launchWithDictation(
        tester,
        store,
        DictationController(
          store: store,
          recognizer: recognizer,
          nowOf: _fixedClock,
          addObserver: (_) {},
        ),
      );
      await openCapture(tester);
      await tester.pumpAndSettle();

      expect(find.byType(MicrophoneGlyph), findsNothing);
      // The field renders whole and the keyboard capture is unaffected.
      expect(find.byType(TextField), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'escrito a mano');
      await tester.pumpAndSettle();
      await tester.tap(find.text(strings.captureSave));
      await tester.pumpAndSettle();
      expect(store.facts.single.dictated, isFalse);
    });

    testWidgets('a refusal appends exactly one permission_refused row, '
        'removes the affordance, and leaves keyboard capture unaffected — '
        'the app never re-asks on its own (FR-32, AD-17)', (tester) async {
      final store = _RecordingStore();
      final recognizer = _FakeRecognizer(
        RecognizerAvailability.askable,
        RecognizerStart.refused,
      );
      await launchWithDictation(
        tester,
        store,
        DictationController(
          store: store,
          recognizer: recognizer,
          nowOf: _fixedClock,
          addObserver: (_) {},
        ),
      );
      await openCapture(tester);
      await tester.pumpAndSettle();
      expect(find.byType(MicrophoneGlyph), findsOneWidget);

      await tester.tap(find.byType(MicrophoneGlyph));
      await tester.pumpAndSettle();
      expect(find.byType(MicrophoneGlyph), findsNothing);
      expect(store.entries, hasLength(1));
      final row = store.entries.single;
      expect(row.kind, 'permission_refused');
      expect(row.permission, 'microphone');

      // Keyboard capture is unaffected: a typed capture still saves.
      await tester.enterText(find.byType(TextField), 'a mano igualmente');
      await tester.pumpAndSettle();
      await tester.tap(find.text(strings.captureSave));
      await tester.pumpAndSettle();
      expect(store.facts, hasLength(1));
      expect(store.facts.single.originContext, 'a mano igualmente');
      expect(store.facts.single.dictated, isFalse);
      expect(store.entries, hasLength(2));
      expect(store.entries.last.kind, 'capture_created');
    });

    testWidgets('leaving the surface while dictation is live cancels the '
        'session — nothing listens outside an explicit press, and a late '
        'outcome lands nowhere (FR-32)', (tester) async {
      final store = _RecordingStore();
      final recognizer = _FakeRecognizer(
        RecognizerAvailability.granted,
        RecognizerStart.listening,
      );
      final controller = DictationController(
        store: store,
        recognizer: recognizer,
        nowOf: _fixedClock,
        addObserver: (_) {},
      );
      await launchWithDictation(tester, store, controller);
      await openCapture(tester);
      await tester.pumpAndSettle();

      await tester.tap(find.byType(MicrophoneGlyph));
      await tester.pumpAndSettle();
      expect(find.text(strings.dictationListening), findsOneWidget);

      // Descartar leaves the surface mid-utterance: every exit path
      // runs the state's dispose, which ends the session.
      await tester.ensureVisible(find.text(strings.captureDiscard));
      await tester.pumpAndSettle();
      await tester.tap(find.text(strings.captureDiscard));
      await tester.pumpAndSettle();
      expect(find.byType(CaptureScreen), findsNothing);
      expect(recognizer.cancelledSessions, [1]);
      expect(controller.listening, isFalse);

      // The recognizer's late terminal event lands nowhere: the
      // surface's callback is gone and the session id is stale.
      final transcripts = <String>[];
      controller.onTranscript = transcripts.add;
      recognizer.emit(1, 'media frase');
      await tester.pumpAndSettle();
      expect(transcripts, isEmpty);
    });

    testWidgets('a transcript landing while Guardar\'s write is in flight '
        'replaces nothing — the fact and entry were minted from the line '
        'as it stood (FR-32)', (tester) async {
      final inner = _RecordingStore();
      final store = _GatedSaveStore(inner);
      final recognizer = _FakeRecognizer(
        RecognizerAvailability.granted,
        RecognizerStart.listening,
      );
      await launchWithDictation(
        tester,
        store,
        DictationController(
          store: store,
          recognizer: recognizer,
          nowOf: _fixedClock,
          addObserver: (_) {},
        ),
      );
      await openCapture(tester);
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'la línea salvada');
      await tester.pumpAndSettle();
      await tester.tap(find.text(strings.captureSave));
      // The write is parked on the gate: the surface is in flight and
      // nothing has landed yet.
      await tester.pump();
      expect(find.byType(CaptureScreen), findsOneWidget);

      // A full utterance resolves while the write stands — its
      // transcript replaces nothing.
      await tester.tap(find.byType(MicrophoneGlyph));
      await tester.pumpAndSettle();
      recognizer.emit(1, 'otra cosa dicha tarde');
      await tester.pumpAndSettle();
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        'la línea salvada',
        reason: 'the in-flight write owns the line it was minted from',
      );

      store.factGate.complete();
      await tester.pumpAndSettle();
      expect(find.byType(CaptureScreen), findsNothing);
      expect(inner.facts.single.originContext, 'la línea salvada');
      expect(inner.facts.single.dictated, isFalse);
    });

    testWidgets('a transcript with interior newlines lands as one line — '
        'the landing commit strips what the formatter strips, nothing '
        'else (FR-32)', (tester) async {
      final store = _RecordingStore();
      final recognizer = _FakeRecognizer(
        RecognizerAvailability.granted,
        RecognizerStart.listening,
      );
      await launchWithDictation(
        tester,
        store,
        DictationController(
          store: store,
          recognizer: recognizer,
          nowOf: _fixedClock,
          addObserver: (_) {},
        ),
      );
      await openCapture(tester);
      await tester.pumpAndSettle();

      await tester.tap(find.byType(MicrophoneGlyph));
      await tester.pumpAndSettle();
      recognizer.emit(1, 'primera\nsegunda\r\ntercera');
      await tester.pumpAndSettle();

      final landed = tester
          .widget<TextField>(find.byType(TextField))
          .controller!
          .text;
      expect(landed, isNot(contains('\n')));
      expect(landed, isNot(contains('\r')));
      expect(landed, 'primerasegundatercera');

      await tester.tap(find.text(strings.captureSave));
      await tester.pumpAndSettle();
      expect(store.facts.single.originContext, 'primerasegundatercera');
      expect(store.facts.single.originContext, isNot(contains('\n')));
      expect(store.facts.single.dictated, isTrue);
    });

    testWidgets('a blank line has a fresh author: dictate, blank, retype '
        'saves dictated false — and dictating the fresh line saves true '
        '(FR-32)', (tester) async {
      final store = _RecordingStore();
      final recognizer = _FakeRecognizer(
        RecognizerAvailability.granted,
        RecognizerStart.listening,
      );
      await launchWithDictation(
        tester,
        store,
        DictationController(
          store: store,
          recognizer: recognizer,
          nowOf: _fixedClock,
          addObserver: (_) {},
        ),
      );
      await openCapture(tester);
      await tester.pumpAndSettle();

      // A dictated line, then blanked, then typed afresh: the typed
      // capture is not dictated.
      await tester.tap(find.byType(MicrophoneGlyph));
      await tester.pumpAndSettle();
      recognizer.emit(1, 'dicho primero');
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), '');
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'escrito después');
      await tester.pumpAndSettle();
      await tester.tap(find.text(strings.captureSave));
      await tester.pumpAndSettle();
      expect(store.facts.single.originContext, 'escrito después');
      expect(store.facts.single.dictated, isFalse);

      // A fresh surface, a fresh dictation: dictated true, standing.
      await openCapture(tester);
      await tester.pumpAndSettle();
      await tester.tap(find.byType(MicrophoneGlyph));
      await tester.pumpAndSettle();
      recognizer.emit(recognizer.startedSessions.last, 'dicho segundo');
      await tester.pumpAndSettle();
      await tester.tap(find.text(strings.captureSave));
      await tester.pumpAndSettle();
      expect(store.facts, hasLength(2));
      expect(store.facts.last.originContext, 'dicho segundo');
      expect(store.facts.last.dictated, isTrue);
    });
  });
}

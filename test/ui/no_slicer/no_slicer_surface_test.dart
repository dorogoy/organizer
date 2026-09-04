// The no-Slicer surface's contract (Story 4-5, FR-29): each of the
// seven causes renders the authored fixed string itself (the
// accessor's value pinned byte-for-byte against EXPERIENCE.md's
// table, never against a duplicated switch) and nothing else; the
// layout is byte-identical across causes — same widget-tree census,
// same type styling, copy the only differentiator; exactly one action
// control exists; the exit pushes Manual Capture with both
// controllers threaded (the mic renders and a typed line saves through
// the capture seam), and a rapid double tap stacks one route, not
// two — the transition guard holds; the styling census holds no error
// semantics — no `!` in any rendered text, no icons at all, no colour
// outside the theme's inks and pastels; a cause swap re-renders with
// no residue; the system back gesture is the OS pop, writing nothing
// through live seams; and nothing in `lib/` outside the surface's own
// file names it — no reachable path opens the surface (4-6 and Epic 5
// arrive later).
import 'dart:io';

import 'package:core/ports/no_slicer_cause.dart';
import 'package:core/ports/recognizer_port.dart';
import 'package:core/ports/store_port.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:organizer/capture/capture_controller.dart';
import 'package:organizer/capture/dictation_controller.dart';
import 'package:organizer/strings/app_strings.dart';
import 'package:organizer/strings/app_strings_es.dart';
import 'package:organizer/ui/capture/capture_screen.dart';
import 'package:organizer/ui/dispenser/task_card.dart';
import 'package:organizer/ui/glyphs/microphone_glyph.dart';
import 'package:organizer/ui/no_slicer/no_slicer_surface.dart';
import 'package:organizer/ui/theme.dart';
import 'package:organizer/ui/tokens.dart';

import '../../../tool/check_core_purity.dart';

/// The recording store (the capture suite's own contract): appends
/// land in order and every read replays them.
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

/// The dictation-capable recognizer fake (the capture suite's own
/// seam): probe and start outcomes the tests steer.
class _FakeRecognizer implements RecognizerPort {
  _FakeRecognizer(this.availability, this.startOutcome);

  RecognizerAvailability availability;
  RecognizerStart startOutcome;
  final List<int> startedSessions = [];
  final List<int> cancelledSessions = [];
  final _outcomes = <RecognizerOutcome>[];

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
  Stream<RecognizerOutcome> get outcomes => Stream.fromIterable(_outcomes);

  @override
  Future<void> openAppSettings() async {}
}

DateTime _fixedClock() => DateTime.utc(2026, 9, 2, 10);

/// The authored fixed-string table (EXPERIENCE.md's seven, verbatim):
/// the independent anchor for the cause→accessor pairing. The helper
/// below switches cause→accessor exactly as the widget does, so a
/// pairing transposed identically in both would pass — these literals
/// cannot, being the authored copy itself rather than a second switch.
/// String literals are legal here: the lib/ literal ban scopes to
/// `lib/**` (AD-15), never `test/`.
const Map<NoSlicerCause, String> _authoredCauseText = {
  NoSlicerCause.noKey:
      'No hay clave de IA guardada. Crear un proyecto a partir de una foto '
      'necesita una; puedes añadirla en Ajustes.',
  NoSlicerCause.invalidKey:
      'La clave guardada no es válida. Puedes revisarla en Ajustes.',
  NoSlicerCause.quotaExhausted:
      'El crédito de la clave se ha agotado. Se repone en la cuenta del '
      'proveedor, no en la app.',
  NoSlicerCause.unreachable:
      'El servicio de IA no responde ahora mismo. Puedes intentarlo más '
      'tarde.',
  NoSlicerCause.offline:
      'El móvil está sin conexión. Los servicios que usan IA no son '
      'accesibles.',
  NoSlicerCause.consentDeclined: 'La foto no se ha enviado.',
  NoSlicerCause.personInFrame:
      'Se ve una persona en la foto, así que no se ha enviado a ningún '
      'sitio. Puedes repetirla sin nadie en el encuadre.',
};

void main() {
  final strings = AppStringsEs();

  String causeTextOf(AppStrings strings, NoSlicerCause cause) =>
      switch (cause) {
        NoSlicerCause.noKey => strings.noSlicerNoKey,
        NoSlicerCause.invalidKey => strings.noSlicerInvalidKey,
        NoSlicerCause.quotaExhausted => strings.noSlicerQuotaExhausted,
        NoSlicerCause.unreachable => strings.noSlicerUnreachable,
        NoSlicerCause.offline => strings.noSlicerOffline,
        NoSlicerCause.consentDeclined => strings.noSlicerConsentDeclined,
        NoSlicerCause.personInFrame => strings.personInFrame,
      };

  Widget harness(
    NoSlicerCause cause, [
    CaptureController? capture,
    DictationController? dictation,
  ]) {
    return MaterialApp(
      theme: OrganizerTheme.light(),
      localizationsDelegates: AppStrings.localizationsDelegates,
      supportedLocales: AppStrings.supportedLocales,
      home: NoSlicerSurface(
        cause: cause,
        controller: capture,
        dictation: dictation,
      ),
    );
  }

  Future<void> pumpSurface(
    WidgetTester tester,
    NoSlicerCause cause, [
    CaptureController? capture,
    DictationController? dictation,
  ]) async {
    await tester.pumpWidget(harness(cause, capture, dictation));
    await tester.pumpAndSettle();
  }

  /// The texts the whole tree carries, every channel included — the
  /// quietness census (the capture suite's own helper).
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

  /// The widget-tree census (the 1-11 idiom): runtime-type counts over
  /// every widget, the shape-comparison basis across causes.
  Map<String, int> typeCensusOf(WidgetTester tester) {
    final census = <String, int>{};
    for (final widget in tester.allWidgets) {
      final name = widget.runtimeType.toString();
      census[name] = (census[name] ?? 0) + 1;
    }
    return census;
  }

  testWidgets('each of the seven causes renders its accessor\'s value '
      'verbatim, plus the exit label and nothing else (FR-29)', (tester) async {
    // The anchor is complete first: every cause owns its authored
    // literal, so the loop below can never fall through quietly.
    expect(_authoredCauseText, hasLength(NoSlicerCause.values.length));
    for (final cause in NoSlicerCause.values) {
      await pumpSurface(tester, cause);
      final causeText = causeTextOf(strings, cause);
      final authored = _authoredCauseText[cause]!;
      // The generated accessor's exact value — byte equality against
      // the authored copy itself, never against a duplicated switch.
      expect(causeText, authored, reason: '$cause');
      expect(find.text(authored), findsOneWidget, reason: '$cause');
      expect(find.text(strings.noSlicerExit), findsOneWidget, reason: '$cause');
      // The Text widgets in tree order: the cause's string, then the
      // exit's label — exactly two, no third text anywhere.
      final datas = [
        for (final text in tester.widgetList<Text>(find.byType(Text)))
          text.data,
      ];
      expect(datas, [authored, strings.noSlicerExit], reason: '$cause');
      // Every channel (RichText, Tooltip, semantics) carries nothing
      // beyond the two authored strings.
      for (final value in textsOf(tester)) {
        expect(
          value == authored || value == strings.noSlicerExit,
          isTrue,
          reason:
              '$cause: nothing beyond the cause string and the exit '
              'renders on any channel',
        );
      }
    }
  });

  testWidgets('the layout is identical across causes — the same '
      'widget-tree census, the same type styling, copy the only '
      'differentiator', (tester) async {
    Map<String, int>? reference;
    String? referenceCauseText;
    TextStyle? referenceCauseStyle;
    TextStyle? referenceExitStyle;
    for (final cause in NoSlicerCause.values) {
      await pumpSurface(tester, cause);
      final census = typeCensusOf(tester);
      if (reference == null) {
        reference = census;
        referenceCauseText = causeTextOf(strings, cause);
        referenceCauseStyle = tester
            .widgetList<Text>(find.byType(Text))
            .first
            .style;
        referenceExitStyle = tester
            .widgetList<Text>(find.byType(Text))
            .last
            .style;
        continue;
      }
      expect(census, reference, reason: '$cause: the tree shape is identical');
      // The cause's Text: the warm close's own register — centered
      // bodyMedium, the secondary ink — for every cause alike.
      final causeWidget = tester.widgetList<Text>(find.byType(Text)).first;
      expect(causeWidget.style, referenceCauseStyle, reason: '$cause');
      expect(
        causeWidget.style?.color,
        FieldPalette.inkSecondary,
        reason: '$cause',
      );
      expect(causeWidget.style?.fontSize, 15, reason: '$cause');
      expect(causeWidget.style?.fontWeight, FontWeight.w400, reason: '$cause');
      expect(causeWidget.textAlign, TextAlign.center, reason: '$cause');
      expect(causeWidget.data, isNot(referenceCauseText), reason: '$cause');
      // The exit: HechoButton's own register, the same label.
      final exitWidget = tester.widgetList<Text>(find.byType(Text)).last;
      expect(exitWidget.style, referenceExitStyle, reason: '$cause');
      expect(
        exitWidget.style?.color,
        FieldPalette.inkPrimary,
        reason: '$cause',
      );
      expect(exitWidget.style?.fontSize, 19, reason: '$cause');
      expect(exitWidget.style?.fontWeight, FontWeight.w600, reason: '$cause');
      expect(exitWidget.data, strings.noSlicerExit, reason: '$cause');
      // Nothing moved and nothing resized between causes: on the wide
      // default test ground the exit spans the full 480 bound and
      // stays screen-centred under every cause alike.
      final exitRect = tester.getRect(find.byType(HechoButton));
      expect(exitRect.width, closeTo(480, 0.5), reason: '$cause');
      final screen = tester.view.physicalSize / tester.view.devicePixelRatio;
      expect(
        exitRect.center.dx,
        closeTo(screen.width / 2, 0.5),
        reason: '$cause',
      );
    }
  });

  testWidgets('exactly one action control exists — one HechoButton, '
      'no second exit of any register (FR-29)', (tester) async {
    for (final cause in NoSlicerCause.values) {
      await pumpSurface(tester, cause);
      expect(find.byType(HechoButton), findsOneWidget, reason: '$cause');
      expect(find.byType(SecondaryTextAction), findsNothing, reason: '$cause');
      expect(
        find.byType(TextButton),
        findsNothing,
        reason: '$cause: no styled second exit',
      );
      expect(find.byType(OutlinedButton), findsNothing, reason: '$cause');
      expect(find.byType(ElevatedButton), findsNothing, reason: '$cause');
      expect(find.byType(FloatingActionButton), findsNothing, reason: '$cause');
      expect(find.byType(IconButton), findsNothing, reason: '$cause');
      expect(find.byType(InkWell), findsOneWidget, reason: '$cause');
      // The framework's own scroll-surface GestureDetector is not an
      // action control; the surface's single InkWell (HechoButton's)
      // is the only tappable box.
      expect(find.byType(PopScope), findsNothing, reason: '$cause');
    }
  });

  testWidgets('the exit pushes Manual Capture in all seven states, '
      'both controllers threaded — the mic renders through the '
      'dictation seam and a typed line saves through the capture seam '
      '(FR-29)', (tester) async {
    for (final cause in NoSlicerCause.values) {
      final store = _RecordingStore();
      final recognizer = _FakeRecognizer(
        RecognizerAvailability.granted,
        RecognizerStart.listening,
      );
      final observers = <WidgetsBindingObserver>[];
      final dictation = DictationController(
        store: store,
        recognizer: recognizer,
        nowOf: _fixedClock,
        addObserver: observers.add,
      );
      await pumpSurface(
        tester,
        cause,
        CaptureController(store: store, nowOf: _fixedClock),
        dictation,
      );
      expect(store.facts, isEmpty, reason: '$cause: rendering wrote nothing');
      expect(store.entries, isEmpty, reason: '$cause');

      await tester.tap(find.text(strings.noSlicerExit));
      await tester.pumpAndSettle();
      expect(find.byType(CaptureScreen), findsOneWidget, reason: '$cause');
      // The dictation seam is threaded: the destination re-derives the
      // capsule's visibility from its own probe, and the microphone is
      // there from the first settled frame — typing and dictation
      // consume nothing the missing half provides.
      expect(
        find.byType(MicrophoneGlyph),
        findsOneWidget,
        reason: '$cause: the dictation controller arrived alive',
      );

      // The capture seam is threaded: one typed line, one Guardar, one
      // manual pool fact plus its capture_created entry — and the
      // route pops back to the surface.
      await tester.enterText(find.byType(TextField), 'Fregar los fogones');
      // Let the field's listener rebuild Guardar into its enabled
      // state before the tap — the pill refuses taps while disabled.
      await tester.pump();
      await tester.tap(find.text(strings.captureSave));
      await tester.pumpAndSettle();
      expect(store.facts, hasLength(1), reason: '$cause');
      expect(store.entries, hasLength(1), reason: '$cause');
      expect(store.entries.single.kind, 'capture_created', reason: '$cause');
      expect(find.byType(CaptureScreen), findsNothing, reason: '$cause');
      expect(find.byType(NoSlicerSurface), findsOneWidget, reason: '$cause');
    }
  });

  testWidgets('the exit pushes with no controllers threaded — the honest '
      'test seam, no write, no pop', (tester) async {
    await pumpSurface(tester, NoSlicerCause.noKey);
    await tester.tap(find.text(strings.noSlicerExit));
    await tester.pumpAndSettle();
    expect(find.byType(CaptureScreen), findsOneWidget);
    // The mic stays absent: no dictation seam was threaded.
    expect(find.byType(MicrophoneGlyph), findsNothing);
  });

  testWidgets('a rapid double tap on the exit stacks one route, not two — '
      'the transition guard holds', (tester) async {
    await pumpSurface(tester, NoSlicerCause.noKey);

    await tester.tap(find.text(strings.noSlicerExit));
    // The second tap lands while the first route is still transitioning
    // in — the same frame, before any pump can advance it. The exit's
    // isCurrent guard must refuse it, exactly as the Dispenser's
    // Lápiz push does (the settings suite's own idiom).
    await tester.tap(find.text(strings.noSlicerExit));
    await tester.pumpAndSettle();

    expect(
      find.byType(CaptureScreen, skipOffstage: false),
      findsOneWidget,
      reason:
          'a second push during the transition would stack a '
          'second capture route',
    );
  });

  testWidgets('the styling census: no exclamation in any rendered text, '
      'no icons at all, no colour outside the theme\'s inks and pastels — '
      'none of the seven reads as an error (FR-29)', (tester) async {
    final theme = OrganizerTheme.light();
    for (final cause in NoSlicerCause.values) {
      await pumpSurface(tester, cause);
      for (final value in textsOf(tester)) {
        expect(value.contains('!'), isFalse, reason: '$cause: "$value"');
      }
      // No iconography exists on the surface at all — warning or
      // otherwise.
      expect(find.byType(Icon), findsNothing, reason: '$cause');
      // No red semantics: every Text carries one of the theme's two
      // inks, every Material carries the accent-soft pastel, and the
      // frame is the theme's surfaceBase — the theme admits no alarm
      // register, and the surface borrows none.
      for (final text in tester.widgetList<Text>(find.byType(Text))) {
        final color = text.style?.color;
        expect(
          color == FieldPalette.inkPrimary ||
              color == FieldPalette.inkSecondary,
          isTrue,
          reason: '$cause: a Text carries "$color"',
        );
      }
      for (final material in tester.widgetList<Material>(
        find.byType(Material),
      )) {
        // The exit's pastel or the frame's surfaceBase — the Scaffold's
        // own Material carries the background tone.
        expect(
          material.color == theme.colorScheme.primary ||
              material.color == theme.scaffoldBackgroundColor,
          isTrue,
          reason: '$cause: a Material carries "${material.color}"',
        );
      }
      expect(find.byType(Scaffold), findsOneWidget, reason: '$cause');
    }
  });

  testWidgets('a cause swapped while mounted re-renders the new string '
      'with no residue — no state, cache or leftover survives', (tester) async {
    // The authored literals, not the helper's switch — the swap is
    // pinned against the copy itself.
    final first = _authoredCauseText[NoSlicerCause.noKey]!;
    final second = _authoredCauseText[NoSlicerCause.offline]!;
    await pumpSurface(tester, NoSlicerCause.noKey);
    expect(find.text(first), findsOneWidget);
    final before = typeCensusOf(tester);

    await tester.pumpWidget(harness(NoSlicerCause.offline));
    await tester.pumpAndSettle();
    // The old string is gone entirely; the new one stands; the exit is
    // unchanged and still exactly one; the tree shape is what it was.
    expect(find.text(first), findsNothing);
    expect(find.text(second), findsOneWidget);
    expect(find.text(strings.noSlicerExit), findsOneWidget);
    expect(typeCensusOf(tester), before);
  });

  testWidgets('the system back gesture is the OS pop — the route pops, '
      'nothing is queued on departure (FR-29)', (tester) async {
    // Live seams, exactly the exit test's own construction: with them
    // threaded, the emptiness assertions below are earned — rendering
    // and departure write nothing through controllers that COULD
    // write, not through nothing at all.
    final store = _RecordingStore();
    final recognizer = _FakeRecognizer(
      RecognizerAvailability.granted,
      RecognizerStart.listening,
    );
    final observers = <WidgetsBindingObserver>[];
    final dictation = DictationController(
      store: store,
      recognizer: recognizer,
      nowOf: _fixedClock,
      addObserver: observers.add,
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: OrganizerTheme.light(),
        localizationsDelegates: AppStrings.localizationsDelegates,
        supportedLocales: AppStrings.supportedLocales,
        home: const Scaffold(),
      ),
    );
    tester
        .state<NavigatorState>(find.byType(Navigator).first)
        .push(
          MaterialPageRoute(
            builder: (context) => NoSlicerSurface(
              cause: NoSlicerCause.noKey,
              controller: CaptureController(store: store, nowOf: _fixedClock),
              dictation: dictation,
            ),
          ),
        );
    await tester.pumpAndSettle();
    expect(find.byType(NoSlicerSurface), findsOneWidget);
    expect(store.facts, isEmpty, reason: 'rendering wrote nothing');
    expect(store.entries, isEmpty);

    // No PopScope dead-end: the OS back channel pops the route.
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byType(NoSlicerSurface), findsNothing);
    expect(store.facts, isEmpty, reason: 'departure queued nothing');
    expect(store.entries, isEmpty);
  });

  test('the surface\'s callers are frozen — its own file names the widget, '
      'and the Dispenser screen (Story 4-6\'s rescue failure) is the one '
      'push site; Epic 5\'s callers renegotiate this census when they '
      'arrive', () {
    final libDir = Directory('lib');
    expect(libDir.existsSync(), isTrue, reason: 'the scan must see a lib/');
    var files = 0;
    final referers = <String>[];
    void collect(Directory dir) {
      for (final entity in dir.listSync(followLinks: false)) {
        if (entity is Directory) {
          collect(entity);
        } else if (entity is File && entity.path.endsWith('.dart')) {
          files++;
          final masked = maskCommentsAndStrings(entity.readAsStringSync());
          if (masked.contains('NoSlicerSurface')) {
            referers.add(entity.path);
          }
        } else if (entity is Link) {
          // A symlinked entry would fall through both census arms
          // and escape the scan silently — fail loudly instead of
          // passing vacuously.
          fail('symlink in lib/: ${entity.path}');
        }
      }
    }

    collect(libDir);
    // Vacuous-pass guards: a real tree was scanned, and the surface's
    // own file is in it (the census saw what it claims to pin).
    expect(files, greaterThan(30), reason: 'a non-trivial lib/ was scanned');
    expect(
      referers,
      hasLength(2),
      reason:
          'only the surface\'s own file and the Dispenser\'s rescue '
          'failure push may name it',
    );
    expect(
      referers.any(
        (path) => path.endsWith('lib/ui/no_slicer/no_slicer_surface.dart'),
      ),
      isTrue,
    );
    expect(
      referers.any(
        (path) => path.endsWith('lib/ui/dispenser/dispenser_screen.dart'),
      ),
      isTrue,
      reason: 'the 4-6 rescue failure push is the surface\'s one caller',
    );
  });
}

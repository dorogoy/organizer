// The typed genesis surface's contract (Story 5.8, FR-11, FR-25,
// UX-DR25, UX-DR52): the ACs rendered. The body copy states
// analysis→tasks with no provider name anywhere on the surface;
// `Analizar` is the consent act itself — the pill stays disabled
// until the trimmed description holds text (the `Guardar` mirror:
// reduced opacity behind `IgnorePointer` and `Semantics(enabled:
// false)`, the tap refused, never a silent no-op); `Volver` and
// `Ajustes` share the quiet bottom row, neither recommended. The
// fail-closed provider read runs at the tap, before any row or
// dispatch — no key stands, the no-key surface replaces this route
// with the reworded both-halves string and zero rows land. The wait
// (5.6's semantics, the consent gate's own grammar): `Creando
// tareas` beside the indeterminate writing pencil, the compose state
// gone — no action remains tappable — and a departure mid-wait
// (back or background) mints exactly one `scan_abandoned` row,
// with the late landing recording nothing more. Test discipline on
// the wait: fixed-duration pumps only — the pencil repeats forever
// and never settles.
import 'dart:async';
import 'dart:ui' as ui;

import 'package:core/ports/slicer_port.dart';
import 'package:core/ports/store_port.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uuid/uuid.dart';

import 'package:organizer/genesis/genesis_controller.dart';
import 'package:organizer/strings/app_strings.dart';
import 'package:organizer/strings/app_strings_es.dart';
import 'package:organizer/ui/no_slicer/no_slicer_surface.dart';
import 'package:organizer/ui/scan/writing_pencil.dart';
import 'package:organizer/ui/settings/nuevo_proyecto_screen.dart';
import 'package:organizer/ui/settings/settings_screen.dart';
import 'package:organizer/ui/theme.dart';

/// The recording store (the consent gate suite's own contract).
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

/// The Slicer fake: the genesis requests the tests read, an
/// in-flight window the close epoch races against.
class _FakeSlicer implements SlicerPort {
  _FakeSlicer(this.outcome);

  final SlicerOutcome outcome;
  final requests = <GenesisSliceRequest>[];
  Completer<void>? gate;

  @override
  Future<SlicerOutcome> slice(SlicerRequest request) async {
    requests.add(request as GenesisSliceRequest);
    final gate = this.gate;
    if (gate != null) {
      await gate.future;
    }
    return outcome;
  }
}

DateTime _fixedClock() => DateTime.utc(2026, 9, 7, 10);

/// The route-pop settle window: one fixed-duration pump long enough
/// for a Material route's exit transition to finish and the popped
/// subtree to dispose — the consent gate suite's own constant.
const Duration routePopSettle = Duration(milliseconds: 600);

void main() {
  final strings = AppStringsEs();
  final theme = OrganizerTheme.light();

  /// A delivered body inside the contract the genesis prompt pins.
  const deliveredBody =
      '{"description": "El trastero ordenado", "steps": '
      '[{"text": "Recoger una caja", "duration_minutes": 4}]}';

  Future<void> pumpSurface(
    WidgetTester tester,
    GenesisController? controller,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: theme,
        localizationsDelegates: AppStrings.localizationsDelegates,
        supportedLocales: AppStrings.supportedLocales,
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => NuevoProyectoScreen(genesis: controller),
              ),
            ),
            child: const Text('launch-surface'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('launch-surface'));
    await tester.pumpAndSettle();
  }

  GenesisController controllerOf(
    _RecordingStore store,
    _FakeSlicer slicer, {
    Future<String?> Function()? read,
  }) => GenesisController(
    store: store,
    slicer: slicer,
    readSelectedProvider: read ?? () async => 'gemini',
    idMinter: const Uuid(),
    nowOf: _fixedClock,
  );

  testWidgets('the body copy states analysis→tasks with no provider '
      'name anywhere on the surface — `Analizar` is the consent, no '
      'separate dialog (FR-25, NFR4)', (tester) async {
    await pumpSurface(tester, null);
    expect(find.text(strings.genesisBody), findsOneWidget);
    for (final name in [
      strings.providerNameGemini,
      strings.providerNameOpenai,
      strings.providerNameAnthropic,
      strings.providerNameOpenrouter,
    ]) {
      expect(find.text(name), findsNothing);
    }
    // The field renders with its hint, the action with its label.
    expect(find.text(strings.genesisFieldHint), findsOneWidget);
    expect(find.text(strings.genesisAnalyze), findsOneWidget);
  });

  testWidgets('`Analizar` stays disabled until the trimmed description '
      'holds text — the tap is refused behind IgnorePointer and '
      'Semantics(enabled: false), never a silent no-op (the Guardar '
      'mirror)', (tester) async {
    final store = _RecordingStore();
    final slicer = _FakeSlicer(const SlicerDelivered(deliveredBody));
    await pumpSurface(tester, controllerOf(store, slicer));

    // Blank: the disabled pill — the same accent-soft ground, pointer
    // refused, semantics disabled.
    final analyze = find.text(strings.genesisAnalyze);
    expect(
      tester
          .widgetList<Semantics>(find.byType(Semantics))
          .any((semantics) => semantics.properties.enabled == false),
      isTrue,
      reason: 'the disabled pill declares itself disabled',
    );
    expect(
      tester
          .widgetList<IgnorePointer>(find.byType(IgnorePointer))
          .any((pointer) => pointer.ignoring),
      isTrue,
      reason: 'the tap is refused, never accepted as a silent no-op',
    );
    final materialColor = tester
        .widget<Material>(
          find.ancestor(of: analyze, matching: find.byType(Material)).first,
        )
        .color;
    expect(materialColor, theme.colorScheme.primary);
    // A real tap at the pill's own centre: refused — no route, no
    // row, no dispatch, the surface stands.
    await tester.tap(analyze);
    await tester.pumpAndSettle();
    expect(find.byType(NuevoProyectoScreen), findsOneWidget);
    expect(find.byType(NoSlicerSurface), findsNothing);
    expect(find.text(strings.scanWaitTitle), findsNothing);
    expect(store.entries, isEmpty);
    expect(slicer.requests, isEmpty);

    // Whitespace alone keeps it refused.
    await tester.enterText(find.byType(TextField), '   ');
    await tester.pump();
    await tester.tap(analyze);
    await tester.pumpAndSettle();
    expect(store.entries, isEmpty);
    expect(slicer.requests, isEmpty);
  });

  testWidgets('`Volver` pops the surface — and both quiet ways out '
      'share the bottom band in the same prose grammar, neither '
      'recommended (EXPERIENCE.md\'s own pins, UX-DR25)', (tester) async {
    await pumpSurface(tester, null);

    // Both quiet prose in the same grammar: ink-secondary, 48dp, no
    // pastel mass.
    for (final label in [strings.genesisBack, strings.settingsWayOut]) {
      final text = find.text(label);
      expect(text, findsOneWidget);
      expect(tester.widget<Text>(text).style!.color, isNotNull);
      final band = tester.renderObject<RenderBox>(
        find.ancestor(of: text, matching: find.byType(GestureDetector)),
      );
      expect(band.size.height, greaterThanOrEqualTo(48));
    }

    // Volver pops the surface.
    await tester.tap(find.text(strings.genesisBack));
    await tester.pumpAndSettle();
    expect(find.byType(NuevoProyectoScreen), findsNothing);
    expect(find.text('launch-surface'), findsOneWidget);
  });

  testWidgets('`Ajustes` really opens Settings — the way-out pushes the '
      'validator surface, not just a label in the band (the test-side '
      'companion of the Volver pin above)', (tester) async {
    await pumpSurface(tester, null);
    await tester.tap(find.text(strings.settingsWayOut));
    await tester.pumpAndSettle();
    expect(find.byType(SettingsScreen), findsOneWidget);
    // Settings stands ABOVE the genesis surface: both live (the
    // covered route is offstage — the finder must look beneath).
    expect(
      find.byType(NuevoProyectoScreen, skipOffstage: false),
      findsOneWidget,
    );
    // And the way back leaves the genesis surface standing — the
    // system back (the suite's own `handlePopRoute` idiom; the
    // settings surface carries no navigation-bar back button).
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byType(SettingsScreen), findsNothing);
    expect(find.byType(NuevoProyectoScreen), findsOneWidget);
  });

  testWidgets('nothing half-wired dispatches: a controller with no read '
      'seam or no slicer takes the quiet pop at the tap — no row, no '
      'dispatch, never a dead surface (the fail-closed arm, pinned)', (
    tester,
  ) async {
    final store = _RecordingStore();
    final slicer = _FakeSlicer(const SlicerDelivered(deliveredBody));

    // No read seam: the availability read cannot even run — the
    // channel folds closed before any row.
    await pumpSurface(
      tester,
      GenesisController(
        store: store,
        slicer: slicer,
        idMinter: const Uuid(),
        nowOf: _fixedClock,
      ),
    );
    await tester.enterText(find.byType(TextField), 'Ordenar el trastero');
    await tester.pump();
    await tester.tap(find.text(strings.genesisAnalyze));
    await tester.pumpAndSettle();
    expect(
      find.text('launch-surface'),
      findsOneWidget,
      reason: 'the surface popped quietly',
    );
    expect(find.byType(NoSlicerSurface), findsNothing);
    expect(store.entries, isEmpty);
    expect(slicer.requests, isEmpty);

    // No slicer seam: the same quiet pop — nothing half-wired
    // dispatches, and no route is replaced.
    await pumpSurface(
      tester,
      GenesisController(
        store: store,
        readSelectedProvider: () async => 'gemini',
        idMinter: const Uuid(),
        nowOf: _fixedClock,
      ),
    );
    await tester.enterText(find.byType(TextField), 'Ordenar el trastero');
    await tester.pump();
    await tester.tap(find.text(strings.genesisAnalyze));
    await tester.pumpAndSettle();
    expect(
      find.text('launch-surface'),
      findsOneWidget,
      reason: 'the surface popped quietly',
    );
    expect(find.byType(NoSlicerSurface), findsNothing);
    expect(store.entries, isEmpty);
    expect(slicer.requests, isEmpty);
  });

  testWidgets('a route pushed above during the provider read ends the '
      'act before it starts — no row, no dispatch, and the compose '
      'state takes the surface back when the way home pops (the '
      'pre-dispatch abort)', (tester) async {
    final store = _RecordingStore();
    final slicer = _FakeSlicer(const SlicerDelivered(deliveredBody));
    final readGate = Completer<String?>();
    await pumpSurface(
      tester,
      controllerOf(store, slicer, read: () => readGate.future),
    );
    await tester.enterText(find.byType(TextField), 'Ordenar el trastero');
    await tester.pump();
    await tester.tap(find.text(strings.genesisAnalyze));
    await tester.pump();

    // The read stands; the way-out pushes Settings above it.
    await tester.tap(find.text(strings.settingsWayOut));
    await tester.pumpAndSettle();
    readGate.complete('gemini');
    await tester.pumpAndSettle();

    // The act aborted: no consent row, no dispatch, no navigation —
    // Settings still owns the navigator, never popped from beneath.
    expect(store.entries, isEmpty);
    expect(slicer.requests, isEmpty);
    expect(find.byType(SettingsScreen), findsOneWidget);

    // And the surface beneath is compose again — the pill is not
    // bricked: the act can be taken again once the way home pops.
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byType(NuevoProyectoScreen), findsOneWidget);
    await tester.tap(find.text(strings.genesisAnalyze));
    await tester.pump();
    expect(slicer.requests, hasLength(1), reason: 'the act is retakeable');
  });

  testWidgets('a real departure during the provider read ends the act '
      'before it starts — no row, no dispatch on the resume, the '
      'compose state stands (the pre-dispatch window\'s other end)', (
    tester,
  ) async {
    final store = _RecordingStore();
    final slicer = _FakeSlicer(const SlicerDelivered(deliveredBody));
    final readGate = Completer<String?>();
    await pumpSurface(
      tester,
      controllerOf(store, slicer, read: () => readGate.future),
    );
    await tester.enterText(find.byType(TextField), 'Ordenar el trastero');
    await tester.pump();
    await tester.tap(find.text(strings.genesisAnalyze));
    await tester.pump();

    // The departure lands inside the read window.
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();
    readGate.complete('gemini');
    await tester.pump();
    // The resume routes through the platform's own return chain
    // (paused → hidden → inactive → resumed) — the listener's state
    // machine rejects the shortcuts.
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    await tester.pump();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pump();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();

    // The act never started: no consent row, no dispatch, no
    // abandonment either (nothing stood to abandon) — no egress ever
    // rides a departure.
    expect(store.entries, isEmpty);
    expect(slicer.requests, isEmpty);
    expect(find.byType(NuevoProyectoScreen), findsOneWidget);
    expect(find.text(strings.scanWaitTitle), findsNothing);
    expect(find.text(strings.genesisAnalyze), findsOneWidget);
  });

  testWidgets('no key at Analizar: the no-key surface replaces this '
      'route BEFORE any row or dispatch — the reworded copy names both '
      'halves, and zero rows land (FR-29, the fail-closed read)', (
    tester,
  ) async {
    final store = _RecordingStore();
    final slicer = _FakeSlicer(const SlicerDelivered(deliveredBody));
    for (final selected in [null, 'not-a-provider']) {
      await pumpSurface(
        tester,
        controllerOf(store, slicer, read: () async => selected),
      );
      await tester.enterText(find.byType(TextField), 'Ordenar el trastero');
      await tester.pump();
      await tester.tap(find.text(strings.genesisAnalyze));
      await tester.pumpAndSettle();
      expect(find.byType(NoSlicerSurface), findsOneWidget);
      expect(find.text(strings.noSlicerNoKey), findsOneWidget);
      // The both-halves naming, pinned: photo AND description.
      expect(strings.noSlicerNoKey, contains('una foto'));
      expect(strings.noSlicerNoKey, contains('una descripción'));
      expect(find.byType(NuevoProyectoScreen), findsNothing);
      // The call never happened: zero rows, zero dispatches.
      expect(store.entries, isEmpty, reason: 'selected: $selected');
      expect(slicer.requests, isEmpty);
      // Reset for the next iteration of the loop.
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      await tester.pumpWidget(const SizedBox.shrink());
    }
  });

  testWidgets('a throwing read seam is the same fail-closed quiet pop '
      '— no row, no dispatch, never a crash', (tester) async {
    final store = _RecordingStore();
    final slicer = _FakeSlicer(const SlicerDelivered(deliveredBody));
    await pumpSurface(
      tester,
      controllerOf(store, slicer, read: () async => throw StateError('x')),
    );
    await tester.enterText(find.byType(TextField), 'Ordenar el trastero');
    await tester.pump();
    await tester.tap(find.text(strings.genesisAnalyze));
    await tester.pumpAndSettle();
    expect(find.byType(NuevoProyectoScreen), findsNothing);
    expect(find.byType(NoSlicerSurface), findsNothing);
    expect(store.entries, isEmpty);
    expect(slicer.requests, isEmpty);
  });

  testWidgets('the wait stands in with its copy — Creando tareas beside '
      'the pencil, the compose state gone, no action remains tappable, '
      'exactly one dispatch (UX-DR56, FR-16)', (tester) async {
    final store = _RecordingStore();
    final slicer = _FakeSlicer(const SlicerDelivered(deliveredBody))
      ..gate = Completer<void>();
    await pumpSurface(tester, controllerOf(store, slicer));
    await tester.enterText(find.byType(TextField), 'Ordenar el trastero');
    await tester.pump();
    await tester.tap(find.text(strings.genesisAnalyze));
    await tester.pump();
    // The swap is immediate: no compose element remains.
    expect(find.byType(TextField), findsNothing);
    expect(find.text(strings.genesisAnalyze), findsNothing);
    expect(find.text(strings.genesisBack), findsNothing);
    expect(find.text(strings.settingsWayOut), findsNothing);
    expect(find.text(strings.genesisBody), findsNothing);
    expect(
      find.descendant(
        of: find.byType(NuevoProyectoScreen),
        matching: find.byType(InkWell),
      ),
      findsNothing,
    );
    // The wait: the title beside the pencil, the consent gate's own
    // register.
    expect(find.text(strings.scanWaitTitle), findsOneWidget);
    expect(find.byType(WritingPencil), findsOneWidget);
    final waitRow = find.ancestor(
      of: find.text(strings.scanWaitTitle),
      matching: find.byType(Row),
    );
    expect(waitRow, findsOneWidget);
    expect(
      find.descendant(of: waitRow, matching: find.byType(WritingPencil)),
      findsOneWidget,
    );
    // No progress semantics exist anywhere: the wait is uncapped.
    expect(find.byType(LinearProgressIndicator), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    // The act's own row landed — the consent act itself, no dialog.
    expect(store.entries.map((entry) => entry.kind), ['consent_granted']);
    expect(slicer.requests, hasLength(1));
    // Fixed-duration pumps only from here: the pencil repeats forever.
    await tester.pump(routePopSettle);
  });

  testWidgets('the delivered arm pops quietly to the caller — nothing '
      'dealt, the one-card landing is 5.9\'s, the facts are on the '
      'substrate', (tester) async {
    final store = _RecordingStore();
    final slicer = _FakeSlicer(const SlicerDelivered(deliveredBody));
    await pumpSurface(tester, controllerOf(store, slicer));
    await tester.enterText(find.byType(TextField), 'Ordenar el trastero');
    await tester.pump();
    await tester.tap(find.text(strings.genesisAnalyze));
    await tester.pump();
    await tester.pump(routePopSettle);
    expect(find.byType(NuevoProyectoScreen), findsNothing);
    expect(find.text('launch-surface'), findsOneWidget);
    expect(store.entries.map((entry) => entry.kind), ['consent_granted']);
    expect(store.facts, hasLength(1), reason: 'the steps landed as facts');
  });

  testWidgets('the failed arm routes the standing map — the no-Slicer '
      'surface beside its one slice_failed row, the 4-5 mapping '
      'unchanged (FR-29)', (tester) async {
    final store = _RecordingStore();
    final slicer = _FakeSlicer(
      const SlicerFailed(SlicerFailureCause.networkUnreachable),
    );
    await pumpSurface(tester, controllerOf(store, slicer));
    await tester.enterText(find.byType(TextField), 'Ordenar el trastero');
    await tester.pump();
    await tester.tap(find.text(strings.genesisAnalyze));
    await tester.pumpAndSettle();
    expect(find.byType(NoSlicerSurface), findsOneWidget);
    expect(find.text(strings.noSlicerOffline), findsOneWidget);
    expect(store.entries.map((entry) => entry.kind), [
      'consent_granted',
      'slice_failed',
    ]);
    expect(store.entries[1].sliceCause, 'networkUnreachable');
  });

  testWidgets('the system back mid-wait is abandoning: the surface pops '
      'with exactly one scan_abandoned beside the act\'s '
      'consent_granted, and the late landing records nothing more '
      '(Story 5.6\'s discipline, UX-DR52)', (tester) async {
    final store = _RecordingStore();
    final slicer = _FakeSlicer(const SlicerDelivered(deliveredBody))
      ..gate = Completer<void>();
    await pumpSurface(tester, controllerOf(store, slicer));
    await tester.enterText(find.byType(TextField), 'Ordenar el trastero');
    await tester.pump();
    await tester.tap(find.text(strings.genesisAnalyze));
    await tester.pump();
    expect(find.byType(WritingPencil), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pump();
    await tester.pump(routePopSettle);
    expect(find.byType(NuevoProyectoScreen), findsNothing);
    expect(store.entries.map((entry) => entry.kind), [
      'consent_granted',
      'scan_abandoned',
    ]);
    // The dispatch resolves after the departure: stale, nothing more.
    slicer.gate!.complete();
    await tester.pump();
    await tester.pump(routePopSettle);
    expect(store.entries.map((entry) => entry.kind), [
      'consent_granted',
      'scan_abandoned',
    ], reason: 'the late landing records nothing more');
    expect(store.facts, isEmpty);
  });

  testWidgets('a real departure (paused) mid-wait closes the wait as an '
      'abandonment — one row, the dispatch cancelled and discarded, '
      'nothing queued on the resume; the stale landing pops the wait', (
    tester,
  ) async {
    final store = _RecordingStore();
    final slicer = _FakeSlicer(const SlicerDelivered(deliveredBody))
      ..gate = Completer<void>();
    await pumpSurface(tester, controllerOf(store, slicer));
    await tester.enterText(find.byType(TextField), 'Ordenar el trastero');
    await tester.pump();
    await tester.tap(find.text(strings.genesisAnalyze));
    await tester.pump();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();
    // The surface stands (it survives the occlusion) but the wait
    // beneath it closed and the row stands.
    expect(find.byType(NuevoProyectoScreen), findsOneWidget);
    expect(store.entries.map((entry) => entry.kind), [
      'consent_granted',
      'scan_abandoned',
    ]);
    // The return: nothing resumes or queues — and the late landing,
    // stale, pops without recording anything more.
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    slicer.gate!.complete();
    await tester.pump();
    await tester.pump(routePopSettle);
    expect(store.entries.map((entry) => entry.kind), [
      'consent_granted',
      'scan_abandoned',
    ], reason: 'nothing resumes, nothing queues, nothing more lands');
    expect(find.byType(NuevoProyectoScreen), findsNothing);
  });

  testWidgets('a transient inactive→resumed occlusion holds, never '
      'closes — no row while the wait stands', (tester) async {
    final store = _RecordingStore();
    final slicer = _FakeSlicer(const SlicerDelivered(deliveredBody))
      ..gate = Completer<void>();
    await pumpSurface(tester, controllerOf(store, slicer));
    await tester.enterText(find.byType(TextField), 'Ordenar el trastero');
    await tester.pump();
    await tester.tap(find.text(strings.genesisAnalyze));
    await tester.pump();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byType(WritingPencil), findsOneWidget);
    expect(store.entries.map((entry) => entry.kind), [
      'consent_granted',
    ], reason: 'a system dialog is not a departure');
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump(const Duration(milliseconds: 100));
    expect(store.entries.map((entry) => entry.kind), ['consent_granted']);
    // The wait resolves delivered after the occlusion: the quiet pop,
    // never an abandonment.
    slicer.gate!.complete();
    await tester.pump();
    await tester.pump(routePopSettle);
    expect(find.byType(NuevoProyectoScreen), findsNothing);
    expect(store.entries.map((entry) => entry.kind), ['consent_granted']);
  });

  testWidgets('a rapid double-tap on Analizar takes one act — the '
      'in-flight guard holds through the provider read: exactly one '
      'read, one dispatch, one row (the surface and the controller '
      'agree)', (tester) async {
    final store = _RecordingStore();
    final slicer = _FakeSlicer(const SlicerDelivered(deliveredBody))
      ..gate = Completer<void>();
    var reads = 0;
    await pumpSurface(
      tester,
      controllerOf(
        store,
        slicer,
        read: () async {
          reads++;
          return 'gemini';
        },
      ),
    );
    await tester.enterText(find.byType(TextField), 'Ordenar el trastero');
    await tester.pump();
    // The second tap is a real gesture at the first's own spot: the
    // pill is gone the frame the act lands, and the synchronous guard
    // owns the window before it.
    final spot = tester.getCenter(find.text(strings.genesisAnalyze));
    await tester.tap(find.text(strings.genesisAnalyze));
    await tester.tapAt(spot);
    await tester.pump();
    expect(find.text(strings.scanWaitTitle), findsOneWidget);
    expect(reads, 1, reason: 'one read, one act, one send');
    expect(slicer.requests, hasLength(1));
    expect(store.entries.map((entry) => entry.kind), ['consent_granted']);
    slicer.gate!.complete();
    await tester.pump();
    await tester.pump(routePopSettle);
    expect(find.text('launch-surface'), findsOneWidget);
  });

  testWidgets('the null-controller test seam: the surface renders whole '
      'and an enabled Analizar answers nothing — no route, no throw, '
      'the surface stands', (tester) async {
    await pumpSurface(tester, null);
    await tester.enterText(find.byType(TextField), 'Ordenar el trastero');
    await tester.pump();
    await tester.tap(find.text(strings.genesisAnalyze));
    await tester.pumpAndSettle();
    expect(find.byType(NuevoProyectoScreen), findsOneWidget);
    expect(find.byType(NoSlicerSurface), findsNothing);
    expect(find.text(strings.scanWaitTitle), findsNothing);
  });

  testWidgets('200% font scale on a 320-wide surface: the compose '
      'surface scrolls, the wait pair holds beside, and nothing '
      'overflows horizontally (UX-DR14, NFR6)', (tester) async {
    tester.platformDispatcher.textScaleFactorTestValue = 2.0;
    addTearDown(tester.platformDispatcher.clearAllTestValues);
    await tester.binding.setSurfaceSize(const ui.Size(320, 480));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final store = _RecordingStore();
    final slicer = _FakeSlicer(const SlicerDelivered(deliveredBody))
      ..gate = Completer<void>();
    await pumpSurface(tester, controllerOf(store, slicer));
    expect(tester.takeException(), isNull);
    await tester.enterText(find.byType(TextField), 'Ordenar el trastero');
    await tester.pump();
    // The 200% body pushes the pill below the fold on the short
    // surface — scroll it into view before the tap.
    await tester.ensureVisible(find.text(strings.genesisAnalyze));
    await tester.pumpAndSettle();
    await tester.tap(find.text(strings.genesisAnalyze));
    await tester.pump();
    expect(find.text(strings.scanWaitTitle), findsOneWidget);
    // The pencil yielded below its register size so `beside` holds.
    expect(tester.getSize(find.byType(WritingPencil)).width, lessThan(160));
    final pair = tester.getRect(
      find.ancestor(
        of: find.text(strings.scanWaitTitle),
        matching: find.byType(Row),
      ),
    );
    expect(pair.right, lessThan(321), reason: 'the pair stays on-surface');
    expect(pair.left, greaterThan(-1), reason: 'nothing bleeds left');
  });
}

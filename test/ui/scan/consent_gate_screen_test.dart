// The consent gate surface's contract (Story 5.5, FR-25, UX-DR26; the
// wait since Story 5.6, UX-DR56): the ACs rendered. The body
// interpolates the provider's rendered name (the one sanctioned
// placeholder); the pair is `action-equal-pair` — one row, both
// children `Expanded` (flex 1 1 0) so their widths are identical,
// identical ground (`surfaceContainerHighest`, never a fill), a 1px
// hairline edge on each, the same type role and radius, the same
// 48dp floor, `Enviar la foto` in the first slot and `No enviarla` in
// the second — and `accent-soft` (`colorScheme.primary`) appears
// NOWHERE on the surface: zero recommended actions, the app's one
// declared exception. After an answer the pair is gone — the accept
// arm becomes the wait: `Creando tareas` beside the indeterminate
// writing pencil, no action remains tappable, no progress semantics
// exist anywhere (no spinner, no bar, no percentage — the wait is
// deliberately uncapped) — so no second answer exists. The system
// back is the OS pop: unanswered it is leaving quietly, mid-wait it
// is abandoning (one `scan_abandoned` row). Test discipline on the
// accept arm: fixed-duration pumps only — the pencil repeats
// forever and never settles.
import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:core/ports/face_gate_port.dart';
import 'package:core/ports/files_port.dart';
import 'package:core/ports/slicer_port.dart';
import 'package:core/ports/store_port.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uuid/uuid.dart';

import 'package:organizer/plugins/camera/camera_shell.dart';
import 'package:organizer/scan/scan_controller.dart';
import 'package:organizer/strings/app_strings.dart';
import 'package:organizer/strings/app_strings_es.dart';
import 'package:organizer/ui/dispenser/task_card.dart';
import 'package:organizer/ui/no_slicer/no_slicer_surface.dart';
import 'package:organizer/ui/glyphs/glyph_canvas.dart';
import 'package:organizer/ui/glyphs/pencil_glyph.dart';
import 'package:organizer/ui/scan/consent_gate_screen.dart';
import 'package:organizer/ui/scan/writing_pencil.dart';
import 'package:organizer/ui/tokens.dart';
import 'package:organizer/ui/theme.dart';

class _RecordingStore implements StorePort {
  final List<LogEntryRecord> entries = [];

  /// Optional brake on the append: when set, the next append hangs on
  /// this completer — the race tests' window for landing a close
  /// mid-write.
  Completer<void>? appendGate;

  @override
  Future<void> appendPoolFact(PoolFactRecord fact) async {}

  @override
  Future<void> appendLogEntry(LogEntryRecord entry) async {
    final gate = appendGate;
    if (gate != null) {
      appendGate = null;
      await gate.future;
    }
    entries.add(entry);
  }

  @override
  Future<List<PoolFactRecord>> readPoolFacts() async => const [];

  @override
  Future<List<LogEntryRecord>> readLogEntries() async =>
      List.unmodifiable(entries);
}

class _RecordingFiles implements FilesPort {
  final unlinkedScans = <String>[];

  @override
  Future<List<int>?> read(String scope, String name) async => null;

  @override
  Future<void> write(String scope, String name, List<int> bytes) async {}

  @override
  Future<void> delete(String scope, String name) async {}

  @override
  Future<String> writeScanFrame(String scanId, List<int> bytes) async =>
      '/cache/scan_cache/$scanId/frame.jpg';

  @override
  Future<void> unlinkScan(String scanId) async => unlinkedScans.add(scanId);

  @override
  Future<String> writeScanCappedCopy(String scanId, List<int> bytes) async =>
      '';

  @override
  Future<void> sweepScanCache() async {}
}

class _FakeCamera implements CameraShell {
  final disposedCalls = <void>[];

  @override
  Future<CameraOpenOutcome> open() async => CameraOpenOutcome.granted;

  @override
  Future<CameraShotOutcome> takePicture() async =>
      const CameraShotCaptured([1, 2, 3]);

  @override
  Widget buildPreview() => const SizedBox.shrink();

  @override
  Future<void> dispose() async => disposedCalls.add(null);
}

class _PassGate implements FaceGatePort {
  @override
  Future<FaceGateOutcome> gate(String framePath) async => const FaceGatePass();
}

class _FakeSlicer implements SlicerPort {
  _FakeSlicer(this.outcome);

  final SlicerOutcome outcome;
  final requests = <ScanSliceRequest>[];
  Completer<void>? gate;

  @override
  Future<SlicerOutcome> slice(SlicerRequest request) async {
    requests.add(request as ScanSliceRequest);
    final gate = this.gate;
    if (gate != null) {
      await gate.future;
    }
    return outcome;
  }
}

DateTime _fixedClock() => DateTime.utc(2026, 9, 6, 10);

/// The route-pop settle window: one fixed-duration pump long enough
/// for a Material route's exit transition to finish and the popped
/// subtree to dispose — a pumping constant, deliberately NOT derived
/// from the pencil's 2400 ms loop period (the loop never settles;
/// only the popped subtree's disposal ends the scheduling).
const Duration routePopSettle = Duration(milliseconds: 600);

Future<Uint8List> _rasterize(CustomPainter painter) async {
  const imageSize = 160;
  const renderSize = 160.0;
  final recorder = ui.PictureRecorder();
  painter.paint(Canvas(recorder), const Size.square(renderSize));
  final image = await recorder.endRecording().toImage(imageSize, imageSize);
  final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
  image.dispose();
  return data!.buffer.asUint8List();
}

int _opaquePixels(Uint8List pixels) {
  var count = 0;
  for (var index = 3; index < pixels.length; index += 4) {
    if (pixels[index] != 0) {
      count++;
    }
  }
  return count;
}

int _differentBytes(Uint8List first, Uint8List second) {
  var count = 0;
  for (var index = 0; index < first.length; index++) {
    if (first[index] != second[index]) {
      count++;
    }
  }
  return count;
}

void main() {
  final strings = AppStringsEs();
  final theme = OrganizerTheme.light();

  /// The wait's painter, read off the rendered CustomPaint — the
  /// phase is public so the motion tests pin movement itself.
  WritingPencilPainter pencilPainterOf(WidgetTester tester) =>
      tester
              .widget<CustomPaint>(
                find.descendant(
                  of: find.byType(WritingPencil),
                  matching: find.byType(CustomPaint),
                ),
              )
              .painter
          as WritingPencilPainter;

  /// A controller standing at the consent moment (gate passed, the
  /// frame surviving), so the gate's taps run the real phase — with
  /// the store it writes to and the seams the lifecycle tests read.
  Future<(ScanController, _RecordingStore, _RecordingFiles, _FakeCamera)>
  standingController(_FakeSlicer slicer) async {
    final store = _RecordingStore();
    final files = _RecordingFiles();
    final camera = _FakeCamera();
    final controller = ScanController(
      store: store,
      files: files,
      camera: camera,
      gate: _PassGate(),
      slicer: slicer,
      readSelectedProvider: () async => 'gemini',
      idMinter: const Uuid(),
      nowOf: _fixedClock,
    );
    await controller.open();
    final outcome = await controller.shoot();
    expect(outcome, isA<ScanShootGatePassed>());
    return (controller, store, files, camera);
  }

  Future<void> pumpGate(WidgetTester tester, ScanController? controller) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: theme,
        localizationsDelegates: AppStrings.localizationsDelegates,
        supportedLocales: AppStrings.supportedLocales,
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => ConsentGateScreen(
                  controller: controller,
                  providerName: strings.providerNameGemini,
                ),
              ),
            ),
            child: const Text('launch-gate'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('launch-gate'));
    await tester.pumpAndSettle();
  }

  Finder materialOf(Text text) => find
      .ancestor(of: find.byWidget(text), matching: find.byType(Material))
      .first;

  /// The delivered arm's new tail (Story 7.1, FR-17): the resolution
  /// no longer pops — the Before-offer stands in, and its `Cerrar`
  /// takes the pop the delivery used to take. Pumps settle the
  /// offer's camera-rule read first.
  Future<void> dismissBeforeOffer(WidgetTester tester) async {
    await tester.pumpAndSettle();
    expect(find.text(strings.rewardBeforeOfferTitle), findsOneWidget);
    // The offer's Cerrar may sit below the fold on a short surface
    // (the 200% test's own floor) — scroll it into view before the
    // tap.
    await tester.ensureVisible(find.text(strings.rewardClose));
    await tester.tap(find.text(strings.rewardClose));
    await tester.pumpAndSettle();
    expect(find.byType(ConsentGateScreen), findsNothing);
  }

  testWidgets('the body states what is sent and to whom — the provider '
      'name interpolated, the one sanctioned placeholder (FR-25, AD-15)', (
    tester,
  ) async {
    await pumpGate(tester, null);
    expect(
      find.text(strings.consentGateBody(strings.providerNameGemini)),
      findsOneWidget,
    );
  });

  testWidgets('the pair is action-equal-pair: equal widths (flex 1 1 0), '
      'identical geometry, hairline, no fill on either, 48dp floor, '
      'Enviar la foto in the first slot (UX-DR26, UX-DR52)', (tester) async {
    await pumpGate(tester, null);

    final send = tester.widget<Text>(find.text(strings.consentGateSend));
    final decline = tester.widget<Text>(find.text(strings.consentGateDecline));
    // Reading order: `Enviar` first, the recorded residual asymmetry.
    final sendRect = tester.getRect(materialOf(send));
    final declineRect = tester.getRect(materialOf(decline));
    expect(sendRect.left, lessThan(declineRect.left));

    // Both children are Expanded with flex 1 — the pair's geometry is
    // one row of flex 1 1 0, identical width by construction.
    final expandeds = tester
        .widgetList<Expanded>(find.byType(Expanded))
        .toList();
    expect(expandeds, hasLength(2));
    for (final expanded in expandeds) {
      expect(expanded.flex, 1);
    }
    expect(sendRect.width, declineRect.width);
    expect(sendRect.height, greaterThanOrEqualTo(48));
    expect(declineRect.height, greaterThanOrEqualTo(48));

    // Identical and unfilled: raised ground, a 1px hairline edge, no
    // `accent-soft` (the theme's `colorScheme.primary`) anywhere —
    // zero recommended actions, the declared exception.
    for (final text in [send, decline]) {
      final material = tester.widget<Material>(materialOf(text));
      expect(material.color, theme.colorScheme.surfaceContainerHighest);
      expect(material.color, isNot(theme.colorScheme.primary));
      final shape = material.shape! as RoundedRectangleBorder;
      expect(shape.side.width, 1);
      expect(shape.side.color, theme.colorScheme.outline);
      expect(shape.borderRadius, BorderRadius.circular(Radii.radiusDefault));
      // The action-primary type role: both labels render the same
      // style, at bodyLarge's size — the Done button's own role, never
      // a second spelling of it.
      expect(text.style!.fontSize, theme.textTheme.bodyLarge!.fontSize);
      expect(text.style, decline.style);
      expect(text.style, send.style);
    }
    // No filled control exists on the surface: no HechoButton, and no
    // Material anywhere wears the primary pair.
    for (final material in tester.widgetList<Material>(find.byType(Material))) {
      expect(material.color, isNot(theme.colorScheme.primary));
    }
    expect(find.byType(HechoButton), findsNothing);
  });

  testWidgets('after an answer the pair is gone — the wait stands in '
      'with its indeterminate pencil, no action remains tappable, '
      'exactly one dispatch, and nothing reads as progress (UX-DR56, '
      'FR-16)', (tester) async {
    final slicer = _FakeSlicer(
      const SlicerDelivered(
        '{"description": "Un rinc\u00f3n con cajas apiladas", "steps": [{"text": "Recoger una caja", "duration_minutes": 4}]}',
      ),
    )..gate = Completer<void>();
    final (controller, store, _, _) = await standingController(slicer);
    await pumpGate(tester, controller);
    await tester.tap(find.text(strings.consentGateSend));
    await tester.pump();
    // The swap is immediate: no action remains on the surface.
    expect(find.text(strings.consentGateSend), findsNothing);
    expect(find.text(strings.consentGateDecline), findsNothing);
    expect(
      find.descendant(
        of: find.byType(ConsentGateScreen),
        matching: find.byType(InkWell),
      ),
      findsNothing,
    );
    // The wait: the title beside the pencil, the app's first and only
    // animation.
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
    // No progress semantics exist anywhere on the surface: no bar, no
    // spinner, no ring — the wait is deliberately uncapped.
    expect(find.byType(LinearProgressIndicator), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.byType(RefreshProgressIndicator), findsNothing);
    // No second answer exists, and no gesture is needed to prove it:
    // the surface holds no InkWell at all (asserted above) and the
    // controller's once-guard owns a late caller — a tap here could
    // only target a non-interactive Text. Still exactly one dispatch,
    // and fixed-duration pumps only from here: the pencil repeats
    // forever and never settles.
    await tester.pump(routePopSettle);
    expect(slicer.requests, hasLength(1));
    // The delivered arm now stands in the Before-offer (Story 7.1):
    // its Cerrar takes the pop, and neither the resolution's own
    // dispose nor the offer's departure mints an abandonment — the
    // dispatch resolved, so nothing stands at the close.
    slicer.gate!.complete();
    await tester.pump();
    await dismissBeforeOffer(tester);
    expect(store.entries.map((entry) => entry.kind), [
      'consent_granted',
      'epic_activated',
    ]);
  });

  testWidgets('the pencil moves: fixed-duration pumps advance the '
      'painter\'s phase off the rest pose — a frozen-at-rest regression '
      'fails here (the loop is live, Story 5.6)', (tester) async {
    final slicer = _FakeSlicer(
      const SlicerDelivered(
        '{"description": "Un rinc\u00f3n con cajas apiladas", "steps": [{"text": "Recoger una caja", "duration_minutes": 4}]}',
      ),
    )..gate = Completer<void>();
    final (controller, _, _, _) = await standingController(slicer);
    await pumpGate(tester, controller);
    await tester.tap(find.text(strings.consentGateSend));
    await tester.pump();
    final atRest = pencilPainterOf(tester).phase;
    // 300 ms of the 2400 ms loop: phase 0.125.
    await tester.pump(const Duration(milliseconds: 300));
    final moved = pencilPainterOf(tester).phase;
    expect(atRest, closeTo(0, 0.001), reason: 'the loop opens at rest');
    expect(moved, allOf(greaterThan(atRest), lessThan(1)));
    expect(
      moved,
      isNot(atRest),
      reason:
          'the pencil is moving — an animation frozen at phase '
          'zero fails here',
    );
  });

  testWidgets('the painter renders the authored rest pose and moves in '
      'both palettes — a blank or rotated wait affordance fails', (
    tester,
  ) async {
    for (final (mass, ink) in [
      (IconMassPalette.iconMassNeutral, FieldPalette.inkPrimary),
      (DarkPalette.iconMassNeutralDark, DarkPalette.inkPrimaryDark),
    ]) {
      final rendered = await tester.runAsync(() async {
        final authored = await _rasterize(
          TreatmentPainter(
            scale: 160 / 24,
            massColor: mass,
            lineColor: ink,
            massPaths: [PencilGlyph.shaftPath()],
            linePaths: PencilGlyph.linePaths(),
          ),
        );
        final rest = await _rasterize(
          WritingPencilPainter(
            scale: 160 / 24,
            phase: 0,
            massColor: mass,
            lineColor: ink,
          ),
        );
        final moved = await _rasterize(
          WritingPencilPainter(
            scale: 160 / 24,
            phase: 0.125,
            massColor: mass,
            lineColor: ink,
          ),
        );
        return (authored, rest, moved);
      });
      final (authored, rest, moved) = rendered!;
      expect(_opaquePixels(rest), greaterThan(0));
      expect(
        _differentBytes(authored, rest),
        0,
        reason: 'phase zero must equal the authored pencil',
      );
      expect(
        _differentBytes(rest, moved),
        greaterThan(0),
        reason: 'a nonzero phase must move the rendered pencil',
      );
    }
  });

  testWidgets('a rapid double-tap on the decline takes one decision — '
      'exactly one consent_declined row (the surface and the controller '
      'agree)', (tester) async {
    final slicer = _FakeSlicer(
      const SlicerDelivered(
        '{"description": "Un rinc\u00f3n con cajas apiladas", "steps": [{"text": "Recoger una caja", "duration_minutes": 4}]}',
      ),
    );
    final (controller, store, _, _) = await standingController(slicer);
    await pumpGate(tester, controller);
    // The second tap is a real gesture at the first's own spot: the
    // pair is gone the frame the answer lands, so no finder can keep
    // targeting the answered decline — the pointer lands on whatever
    // replaced it, and the once-guards own the rest.
    final declineSpot = tester.getCenter(find.text(strings.consentGateDecline));
    await tester.tap(find.text(strings.consentGateDecline));
    await tester.tapAt(declineSpot);
    await tester.pumpAndSettle();
    expect(slicer.requests, isEmpty);
    expect(store.entries.map((entry) => entry.kind), ['consent_declined']);
  });

  testWidgets('the wait copy belongs to the accept arm alone — a decline '
      'never renders Creando tareas, not even for the instant before the '
      'route replaces the gate', (tester) async {
    final slicer = _FakeSlicer(
      const SlicerDelivered(
        '{"description": "Un rinc\u00f3n con cajas apiladas", "steps": [{"text": "Recoger una caja", "duration_minutes": 4}]}',
      ),
    );
    final (controller, store, _, _) = await standingController(slicer);
    await pumpGate(tester, controller);
    await tester.tap(find.text(strings.consentGateDecline));
    await tester.pump();
    // The pair is gone (one answer stands) but the wait text is not
    // there: the boundaries scope it to the accept arm.
    expect(find.text(strings.scanWaitTitle), findsNothing);
    expect(find.text(strings.consentGateDecline), findsNothing);
    await tester.pumpAndSettle();
    expect(find.byType(NoSlicerSurface), findsOneWidget);
    expect(find.text(strings.noSlicerConsentDeclined), findsOneWidget);
    expect(store.entries.map((entry) => entry.kind), ['consent_declined']);
  });

  testWidgets('a close landing mid-decline pops the gate — the decline '
      'surface never claims a decline whose row does not stand (the '
      'stale arm mirrors the accept\'s)', (tester) async {
    final slicer = _FakeSlicer(
      const SlicerDelivered(
        '{"description": "Un rinc\u00f3n con cajas apiladas", "steps": [{"text": "Recoger una caja", "duration_minutes": 4}]}',
      ),
    );
    final (controller, store, _, _) = await standingController(slicer);
    // The append hangs in flight: the window where a real departure
    // (the lifecycle close) can land between the answer and the row's
    // commit.
    final appendGate = Completer<void>();
    store.appendGate = appendGate;
    await pumpGate(tester, controller);
    await tester.tap(find.text(strings.consentGateDecline));
    await tester.pump();
    await controller.close();
    appendGate.complete();
    await tester.pumpAndSettle();
    expect(find.byType(ConsentGateScreen), findsNothing);
    // The decline surface never renders for a scan that already ended.
    expect(find.byType(NoSlicerSurface), findsNothing);
    expect(find.text(strings.noSlicerConsentDeclined), findsNothing);
    expect(find.text(strings.scanWaitTitle), findsNothing);
  });

  testWidgets('the system back pops the gate — leaving is not declining, '
      'the OS gesture is the way out (no PopScope dead-end)', (tester) async {
    final slicer = _FakeSlicer(
      const SlicerDelivered(
        '{"description": "Un rinc\u00f3n con cajas apiladas", "steps": [{"text": "Recoger una caja", "duration_minutes": 4}]}',
      ),
    );
    final (controller, store, _, _) = await standingController(slicer);
    await pumpGate(tester, controller);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byType(ConsentGateScreen), findsNothing);
  });

  testWidgets('a real departure (paused) at the gate closes the scan — '
      'the cache unlinks and the camera releases, the gate stands, and '
      'the return holds (5.2\'s release contract carried past it)', (
    tester,
  ) async {
    final slicer = _FakeSlicer(
      const SlicerDelivered(
        '{"description": "Un rinc\u00f3n con cajas apiladas", "steps": [{"text": "Recoger una caja", "duration_minutes": 4}]}',
      ),
    );
    final (controller, _, files, camera) = await standingController(slicer);
    await pumpGate(tester, controller);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pumpAndSettle();
    expect(find.byType(ConsentGateScreen), findsOneWidget);
    expect(files.unlinkedScans, isNotEmpty);
    expect(camera.disposedCalls, isNotEmpty);
    // The return: the occlusion held — the gate stands, nothing closes
    // again.
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(find.byType(ConsentGateScreen), findsOneWidget);
  });

  testWidgets('a transient inactive→resumed occlusion holds, never '
      'closes — the hold-open rule, no unlink, no camera release', (
    tester,
  ) async {
    final slicer = _FakeSlicer(
      const SlicerDelivered(
        '{"description": "Un rinc\u00f3n con cajas apiladas", "steps": [{"text": "Recoger una caja", "duration_minutes": 4}]}',
      ),
    );
    final (controller, _, files, camera) = await standingController(slicer);
    await pumpGate(tester, controller);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pumpAndSettle();
    expect(find.byType(ConsentGateScreen), findsOneWidget);
    expect(files.unlinkedScans, isEmpty);
    expect(camera.disposedCalls, isEmpty);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(find.byType(ConsentGateScreen), findsOneWidget);
    expect(files.unlinkedScans, isEmpty);
    expect(camera.disposedCalls, isEmpty);
  });

  testWidgets('a stale resolution pops the gate — the scan already '
      'ended: the departure\'s row stands beside the act\'s own, the '
      'close\'s unlink the only one, no routing for the late landing', (
    tester,
  ) async {
    final slicer = _FakeSlicer(
      const SlicerDelivered(
        '{"description": "Un rinc\u00f3n con cajas apiladas", "steps": [{"text": "Recoger una caja", "duration_minutes": 4}]}',
      ),
    )..gate = Completer<void>();
    final (controller, store, files, _) = await standingController(slicer);
    await pumpGate(tester, controller);
    await tester.tap(find.text(strings.consentGateSend));
    await tester.pump();
    // The departure lands mid-dispatch: the close bumps the epoch,
    // unlinks, and — since 5.6 — mints the wait's one abandonment row;
    // the late delivery must not strand the wait or record more.
    await controller.close();
    slicer.gate!.complete();
    await tester.pump();
    await tester.pump(routePopSettle);
    expect(find.byType(ConsentGateScreen), findsNothing);
    expect(files.unlinkedScans, isNotEmpty);
    expect(store.entries.map((entry) => entry.kind), [
      'consent_granted',
      'scan_abandoned',
    ]);
  });

  testWidgets('the system back mid-wait is abandoning: the gate pops '
      'with exactly one scan_abandoned beside the act\'s consent_granted, '
      'and the late landing records nothing more (Story 5.6, FR-16, '
      'AD-8, UX-DR52 — the OS gesture is the one exit)', (tester) async {
    final slicer = _FakeSlicer(
      const SlicerDelivered(
        '{"description": "Un rinc\u00f3n con cajas apiladas", "steps": [{"text": "Recoger una caja", "duration_minutes": 4}]}',
      ),
    )..gate = Completer<void>();
    final (controller, store, files, _) = await standingController(slicer);
    await pumpGate(tester, controller);
    await tester.tap(find.text(strings.consentGateSend));
    await tester.pump();
    expect(find.byType(WritingPencil), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pump();
    await tester.pump(routePopSettle);
    expect(find.byType(ConsentGateScreen), findsNothing);
    expect(store.entries.map((entry) => entry.kind), [
      'consent_granted',
      'scan_abandoned',
    ]);
    expect(files.unlinkedScans, isNotEmpty);
    // The dispatch resolves after the departure: stale, nothing more.
    slicer.gate!.complete();
    await tester.pump();
    await tester.pump(routePopSettle);
    expect(store.entries.map((entry) => entry.kind), [
      'consent_granted',
      'scan_abandoned',
    ], reason: 'the late landing records nothing more');
    expect(find.byType(ConsentGateScreen), findsNothing);
  });

  testWidgets('a real departure (paused) mid-wait closes the scan as an '
      'abandonment — one row, the wait beneath it cancelled and '
      'discarded, nothing queued on the resume (Story 5.6, FR-16, '
      'AD-8)', (tester) async {
    final slicer = _FakeSlicer(
      const SlicerDelivered(
        '{"description": "Un rinc\u00f3n con cajas apiladas", "steps": [{"text": "Recoger una caja", "duration_minutes": 4}]}',
      ),
    )..gate = Completer<void>();
    final (controller, store, files, camera) = await standingController(slicer);
    await pumpGate(tester, controller);
    await tester.tap(find.text(strings.consentGateSend));
    await tester.pump();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();
    // The gate stands (the surface survives the occlusion) but the
    // scan beneath it is closed and the row stands.
    expect(find.byType(ConsentGateScreen), findsOneWidget);
    expect(files.unlinkedScans, isNotEmpty);
    expect(camera.disposedCalls, isNotEmpty);
    expect(store.entries.map((entry) => entry.kind), [
      'consent_granted',
      'scan_abandoned',
    ]);
    // The return: nothing resumes or queues — and the late landing,
    // stale, pops the gate without recording anything more.
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    slicer.gate!.complete();
    await tester.pump();
    await tester.pump(routePopSettle);
    expect(store.entries.map((entry) => entry.kind), [
      'consent_granted',
      'scan_abandoned',
    ], reason: 'nothing resumes, nothing queues, nothing more lands');
    expect(find.byType(ConsentGateScreen), findsNothing);
  });

  testWidgets('a transient inactive occlusion mid-wait holds: the wait '
      'stands, no scan_abandoned row — and the resolution that follows '
      'mints none either (the 5.2/5.5 contract)', (tester) async {
    final slicer = _FakeSlicer(
      const SlicerDelivered(
        '{"description": "Un rinc\u00f3n con cajas apiladas", "steps": [{"text": "Recoger una caja", "duration_minutes": 4}]}',
      ),
    )..gate = Completer<void>();
    final (controller, store, _, _) = await standingController(slicer);
    await pumpGate(tester, controller);
    await tester.tap(find.text(strings.consentGateSend));
    await tester.pump();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byType(ConsentGateScreen), findsOneWidget);
    expect(find.byType(WritingPencil), findsOneWidget);
    expect(store.entries.map((entry) => entry.kind), [
      'consent_granted',
    ], reason: 'a system dialog is not a departure');
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump(const Duration(milliseconds: 100));
    expect(store.entries.map((entry) => entry.kind), [
      'consent_granted',
    ], reason: 'the resume itself mints nothing');
    // The wait resolves delivered after the occlusion: the interim
    // quiet pop, and never an abandonment.
    slicer.gate!.complete();
    await tester.pump();
    await dismissBeforeOffer(tester);
    expect(store.entries.map((entry) => entry.kind), [
      'consent_granted',
      'epic_activated',
    ]);
  });

  testWidgets('reduced motion: the pencil rests at its authored pose — '
      'the loop stops for the OS setting while the title still '
      'communicates the activity (Story 5.6, UX-DR56)', (tester) async {
    final slicer = _FakeSlicer(
      const SlicerDelivered(
        '{"description": "Un rinc\u00f3n con cajas apiladas", "steps": [{"text": "Recoger una caja", "duration_minutes": 4}]}',
      ),
    )..gate = Completer<void>();
    final (controller, store, _, _) = await standingController(slicer);
    await pumpGate(tester, controller);
    // The OS setting through the production path: the root MediaQuery
    // reads the dispatcher's accessibility features.
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    await tester.pump();
    await tester.tap(find.text(strings.consentGateSend));
    // The strong pin: with the OS setting honored at the mechanism
    // level the surface SETTLES — a running pencil never would (and
    // a regression here times this settle out, visibly).
    await tester.pumpAndSettle();
    expect(find.text(strings.scanWaitTitle), findsOneWidget);
    expect(find.byType(WritingPencil), findsOneWidget);
    // The resting pose, pinned on the painter itself: the authored
    // pencil at phase zero — the loop never started.
    final painter = pencilPainterOf(tester);
    expect(painter.phase, 0, reason: 'the rest pose is the authored pencil');
    expect(store.entries.map((entry) => entry.kind), ['consent_granted']);
  });

  testWidgets('reduced motion toggled mid-wait: the running loop stops '
      'at the authored rest pose and restarts when the setting clears '
      '(Story 5.6)', (tester) async {
    final slicer = _FakeSlicer(
      const SlicerDelivered(
        '{"description": "Un rinc\u00f3n con cajas apiladas", "steps": [{"text": "Recoger una caja", "duration_minutes": 4}]}',
      ),
    )..gate = Completer<void>();
    final (controller, store, _, _) = await standingController(slicer);
    await pumpGate(tester, controller);
    await tester.tap(find.text(strings.consentGateSend));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(
      pencilPainterOf(tester).phase,
      moreOrLessEquals(0.125, epsilon: 0.02),
    );
    // The setting lands mid-flight: the ticker stops, and the rendered
    // pose is the authored rest (phase zero), never a frozen mid-glide.
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    await tester.pump();
    expect(pencilPainterOf(tester).phase, 0);
    // Cleared: the loop restarts — the phase advances again.
    tester.platformDispatcher.clearAccessibilityFeaturesTestValue();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(pencilPainterOf(tester).phase, allOf(greaterThan(0), lessThan(1)));
    expect(store.entries.map((entry) => entry.kind), ['consent_granted']);
    slicer.gate!.complete();
    await tester.pump();
    await dismissBeforeOffer(tester);
  });

  testWidgets('a real departure (hidden, then detached in a fresh scan) '
      'mid-wait closes the scan as an abandonment — the same one-row '
      'answer as paused, the three backgrounding states sharing one arm '
      '(Story 5.6, FR-16, AD-8)', (tester) async {
    for (final state in [
      AppLifecycleState.hidden,
      AppLifecycleState.detached,
    ]) {
      final slicer = _FakeSlicer(
        const SlicerDelivered(
          '{"description": "Un rinc\u00f3n con cajas apiladas", "steps": [{"text": "Recoger una caja", "duration_minutes": 4}]}',
        ),
      )..gate = Completer<void>();
      final (controller, store, files, camera) = await standingController(
        slicer,
      );
      await pumpGate(tester, controller);
      await tester.tap(find.text(strings.consentGateSend));
      await tester.pump();
      tester.binding.handleAppLifecycleStateChanged(state);
      await tester.pump();
      // The gate stands, but the scan beneath it closed: unlinked,
      // camera released, exactly the departure's row beside the act's.
      expect(find.byType(ConsentGateScreen), findsOneWidget);
      expect(files.unlinkedScans, isNotEmpty);
      expect(camera.disposedCalls, isNotEmpty);
      expect(store.entries.map((entry) => entry.kind), [
        'consent_granted',
        'scan_abandoned',
      ], reason: '$state closes like paused — one abandonment row');
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      slicer.gate!.complete();
      await tester.pump();
      await tester.pump(routePopSettle);
      expect(find.byType(ConsentGateScreen), findsNothing);
    }
  });

  testWidgets('200% font scale on a 320-wide surface: the wait pair holds '
      'beside — the pencil yields below its register size, the title '
      'wraps, and nothing overflows horizontally (UX-DR14, NFR6, '
      'Story 5.6)', (tester) async {
    tester.platformDispatcher.textScaleFactorTestValue = 2.0;
    addTearDown(tester.platformDispatcher.clearAllTestValues);
    await tester.binding.setSurfaceSize(const ui.Size(320, 480));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final slicer = _FakeSlicer(
      const SlicerDelivered(
        '{"description": "Un rinc\u00f3n con cajas apiladas", "steps": [{"text": "Recoger una caja", "duration_minutes": 4}]}',
      ),
    )..gate = Completer<void>();
    final (controller, store, _, _) = await standingController(slicer);
    await pumpGate(tester, controller);
    // The 200% body pushes the pair below the fold on the short
    // surface — scroll it into view before the tap.
    await tester.ensureVisible(find.text(strings.consentGateSend));
    await tester.pumpAndSettle();
    await tester.tap(find.text(strings.consentGateSend));
    await tester.pump();
    expect(find.text(strings.scanWaitTitle), findsOneWidget);
    // The pencil yielded: below the 320-wide floor the register size
    // (160) would not fit beside a wrapped title, so the mark cedes
    // size — `beside` holds. A RenderFlex overflow would throw here.
    expect(tester.getSize(find.byType(WritingPencil)).width, lessThan(160));
    final pair = tester.getRect(
      find.ancestor(
        of: find.text(strings.scanWaitTitle),
        matching: find.byType(Row),
      ),
    );
    expect(pair.right, lessThan(321), reason: 'the pair stays on-surface');
    expect(pair.left, greaterThan(-1), reason: 'nothing bleeds left');
    expect(store.entries.map((entry) => entry.kind), ['consent_granted']);
    slicer.gate!.complete();
    await tester.pump();
    await dismissBeforeOffer(tester);
  });

  testWidgets('the null-controller test seam: the pair renders and a tap '
      'answers nothing — no route, no throw', (tester) async {
    await pumpGate(tester, null);
    await tester.tap(find.text(strings.consentGateSend));
    await tester.pumpAndSettle();
    expect(find.byType(ConsentGateScreen), findsOneWidget);
    expect(find.byType(NoSlicerSurface), findsNothing);
    await tester.tap(find.text(strings.consentGateDecline));
    await tester.pumpAndSettle();
    expect(find.byType(ConsentGateScreen), findsOneWidget);
    expect(find.byType(NoSlicerSurface), findsNothing);
  });
}

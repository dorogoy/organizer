// The consent gate surface's contract (Story 5.5, FR-25, UX-DR26): the
// ACs rendered. The body interpolates the provider's rendered name (the
// one sanctioned placeholder); the pair is `action-equal-pair` — one
// row, both children `Expanded` (flex 1 1 0) so their widths are
// identical, identical ground (`surfaceContainerHighest`, never a fill),
// a 1px hairline edge on each, the same type role and radius, the same
// 48dp floor, `Enviar la foto` in the first slot and `No enviarla` in
// the second — and `accent-soft` (`colorScheme.primary`) appears
// NOWHERE on the surface: zero recommended actions, the app's one
// declared exception. After an answer the pair is gone — the static
// `Creando tareas` text stands in, no action remains tappable — so no
// second answer exists. The system back is the OS pop (leaving is not
// declining).
import 'dart:async';

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
import 'package:organizer/ui/scan/consent_gate_screen.dart';
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

void main() {
  final strings = AppStringsEs();
  final theme = OrganizerTheme.light();

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

  testWidgets('after an answer the pair is gone — the static wait text '
      'stands in, no action remains tappable, exactly one dispatch '
      '(no second answer exists)', (tester) async {
    final slicer = _FakeSlicer(
      const SlicerDelivered('[{"text": "x", "duration_minutes": 4}]'),
    );
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
    expect(find.text(strings.scanWaitTitle), findsOneWidget);
    // A second tap lands on nothing: still exactly one dispatch.
    await tester.tap(find.text(strings.scanWaitTitle));
    await tester.pumpAndSettle();
    expect(slicer.requests, hasLength(1));
  });

  testWidgets('a rapid double-tap on the decline takes one decision — '
      'exactly one consent_declined row (the surface and the controller '
      'agree)', (tester) async {
    final slicer = _FakeSlicer(const SlicerDelivered('[{"text": "x"}]'));
    final (controller, store, _, _) = await standingController(slicer);
    await pumpGate(tester, controller);
    await tester.tap(find.text(strings.consentGateDecline));
    await tester.tap(find.text(strings.consentGateDecline));
    await tester.pumpAndSettle();
    expect(slicer.requests, isEmpty);
    expect(store.entries.map((entry) => entry.kind), ['consent_declined']);
  });

  testWidgets('the wait copy belongs to the accept arm alone — a decline '
      'never renders Creando tareas, not even for the instant before the '
      'route replaces the gate', (tester) async {
    final slicer = _FakeSlicer(const SlicerDelivered('[{"text": "x"}]'));
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
    final slicer = _FakeSlicer(const SlicerDelivered('[{"text": "x"}]'));
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
    final slicer = _FakeSlicer(const SlicerDelivered('[{"text": "x"}]'));
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
    final slicer = _FakeSlicer(const SlicerDelivered('[{"text": "x"}]'));
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
    final slicer = _FakeSlicer(const SlicerDelivered('[{"text": "x"}]'));
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
      'ended, leaving is not declining: no decline row, the close\'s '
      'unlink the only one', (tester) async {
    final slicer = _FakeSlicer(const SlicerDelivered('[{"text": "x"}]'))
      ..gate = Completer<void>();
    final (controller, store, files, _) = await standingController(slicer);
    await pumpGate(tester, controller);
    await tester.tap(find.text(strings.consentGateSend));
    await tester.pump();
    // The departure lands mid-dispatch: the close bumps the epoch and
    // unlinks; the late delivery must not strand the wait text.
    await controller.close();
    slicer.gate!.complete();
    await tester.pumpAndSettle();
    expect(find.byType(ConsentGateScreen), findsNothing);
    expect(files.unlinkedScans, isNotEmpty);
    // The stale pop records nothing — the only row is the act's own
    // consent_granted, minted at the tap (the controller's own pin).
    expect(store.entries.map((entry) => entry.kind), ['consent_granted']);
    expect(store.entries, hasLength(1));
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

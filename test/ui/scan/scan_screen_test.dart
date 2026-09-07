// The scan surface's contract (Story 5.2, FR-16, FR-25; ruling 1-B):
// the empty frame before the grant (never a loader), the preview once
// granted, the one shutter action in the Done button's register with
// the `scanShutter` semantics, the OS back as the only way out, the
// refusal's pushReplacement onto the one calm surface with the
// personInFrame copy, the quiet pop on every other terminal outcome —
// and the system-problem notice (`scanOpenFailed`) that keeps the
// surface standing through an interrupted ask or a failed open: no
// pop, no row, the entry untouched, a malfunction communicated and
// never mistaken for the user's refusal. A throwing seam is guarded
// both ways (an open failure lands in the notice, a shoot failure in
// the quiet pop), and the lifecycle owns the camera: a backgrounding
// releases it — never while the ask is staged — and a resume re-opens
// through the fast path (the DictationController observer's own
// pattern).
import 'dart:async';

import 'package:core/ports/face_gate_port.dart';
import 'package:core/ports/files_port.dart';
import 'package:core/ports/slicer_port.dart';
import 'package:core/ports/store_port.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:organizer/plugins/camera/camera_shell.dart';
import 'package:organizer/scan/scan_controller.dart';
import 'package:organizer/strings/app_strings.dart';
import 'package:organizer/strings/app_strings_es.dart';
import 'package:organizer/ui/no_slicer/no_slicer_surface.dart';
import 'package:organizer/ui/scan/consent_gate_screen.dart';
import 'package:organizer/ui/scan/scan_screen.dart';
import 'package:organizer/ui/theme.dart';

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

/// The camera fake whose preview is a visible marker widget, whose
/// open may park behind a gate (the pre-grant window is testable) and
/// whose either half may throw, for the surface's fail-closed guards.
class _FakeCamera implements CameraShell {
  _FakeCamera({
    this.openOutcome,
    this.throwOnOpen = false,
    this.throwOnShoot = false,
    this.shotOutcome = const CameraShotCaptured([1]),
  });

  final CameraOpenOutcome? openOutcome;
  final bool throwOnOpen;
  final bool throwOnShoot;
  final CameraShotOutcome shotOutcome;

  final openedCalls = <void>[];
  final disposedCalls = <void>[];

  /// When set, [open] parks on this completer before answering.
  Completer<CameraOpenOutcome>? openGate;

  static const Key previewKey = Key('fake-camera-preview');

  @override
  Future<CameraOpenOutcome> open() async {
    openedCalls.add(null);
    final gate = openGate;
    if (gate != null) {
      await gate.future;
    }
    if (throwOnOpen) {
      throw StateError('open seam threw');
    }
    return openOutcome ?? CameraOpenOutcome.granted;
  }

  @override
  Future<CameraShotOutcome> takePicture() async {
    if (throwOnShoot) {
      throw StateError('shoot seam threw');
    }
    return shotOutcome;
  }

  @override
  Widget buildPreview() => const SizedBox.expand(
    key: previewKey,
    child: ColoredBox(color: Color(0xFF000000)),
  );

  @override
  Future<void> dispose() async => disposedCalls.add(null);
}

class _FakeGate implements FaceGatePort {
  _FakeGate(this.outcome);

  final FaceGateOutcome outcome;

  @override
  Future<FaceGateOutcome> gate(String framePath) async => outcome;
}

/// The Slicer fake: requests recorded, outcome steered (the routing
/// matrix's delivered and failed arms).
class _FakeSlicer implements SlicerPort {
  _FakeSlicer({SlicerOutcome? outcome})
    : outcome = outcome ?? const SlicerDelivered('[{"text": "x"}]');

  SlicerOutcome outcome;
  final requests = <ScanSliceRequest>[];

  @override
  Future<SlicerOutcome> slice(SlicerRequest request) async {
    requests.add(request as ScanSliceRequest);
    return outcome;
  }
}

DateTime _fixedClock() => DateTime.utc(2026, 9, 5, 10);

/// The route-pop settle window (the consent gate suite's own
/// constant): one fixed-duration pump long enough for a Material
/// route's exit/replacement transition to finish and the gone
/// subtree to dispose — deliberately NOT derived from the wait
/// pencil's 2400 ms loop period, which never settles.
const Duration routePopSettle = Duration(milliseconds: 600);

void main() {
  final strings = AppStringsEs();

  /// The launch word for the push button — never rendered copy (the
  /// harness's own control, outside the surface under test).
  const launchWord = 'launch-scan';

  Widget harness(ScanController? controller) {
    return MaterialApp(
      theme: OrganizerTheme.light(),
      localizationsDelegates: AppStrings.localizationsDelegates,
      supportedLocales: AppStrings.supportedLocales,
      home: Builder(
        builder: (context) => TextButton(
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => ScanScreen(controller: controller),
            ),
          ),
          child: const Text(launchWord),
        ),
      ),
    );
  }

  Future<void> launch(WidgetTester tester, ScanController? controller) async {
    await tester.pumpWidget(harness(controller));
    await tester.tap(find.text(launchWord));
    await tester.pumpAndSettle();
  }

  ScanController controllerWith(
    _RecordingStore store,
    _RecordingFiles files,
    CameraShell camera, {
    FaceGatePort? gate,
    SlicerPort? slicer,
    Future<String?> Function()? readSelectedProvider,
  }) => ScanController(
    store: store,
    files: files,
    camera: camera,
    gate: gate,
    slicer: slicer,
    readSelectedProvider: readSelectedProvider,
    nowOf: _fixedClock,
  );

  testWidgets('granted: the empty frame precedes the grant (never a '
      'loader), the preview lands with it, and the shutter is the one '
      'action — 48dp, the scanShutter semantics, the Done register '
      '(FR-16, FR-25)', (tester) async {
    final store = _RecordingStore();
    final files = _RecordingFiles();
    final camera = _FakeCamera()..openGate = Completer<CameraOpenOutcome>();
    // The launch word pumps without settling: the open parks on the
    // gate, and the surface must already hold its whole shape — the
    // empty frame, the shutter, no spinner anywhere.
    await tester.pumpWidget(harness(controllerWith(store, files, camera)));
    await tester.tap(find.text(launchWord));
    await tester.pump();
    // Mid-transition, the route is built and visible: the open still
    // parks on the gate, and the surface already holds its whole
    // shape.
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(
      find.text(strings.scanShutter),
      findsNothing,
      reason: 'a dead shutter is not an honest one — absent until granted',
    );
    expect(find.byKey(_FakeCamera.previewKey), findsNothing);
    expect(find.byType(ScanScreen), findsOneWidget);

    camera.openGate!.complete(CameraOpenOutcome.granted);
    await tester.pumpAndSettle();
    expect(find.byKey(_FakeCamera.previewKey), findsOneWidget);

    // The shutter target: 48dp minimum in the Done button's register.
    final shutter = find.text(strings.scanShutter);
    final material = find
        .ancestor(of: shutter, matching: find.byType(Material))
        .first;
    final rect = tester.getRect(material);
    expect(rect.height, greaterThanOrEqualTo(48));
    expect(
      tester.widget<Material>(material).color,
      OrganizerTheme.light().colorScheme.primary,
    );
    // The census: the shutter string alone — no title, no helper, no
    // second exit (A-slim).
    final texts = [
      for (final text in tester.widgetList<Text>(find.byType(Text)))
        if (text.data != null && text.data!.isNotEmpty) text.data!,
    ];
    expect(texts.toSet(), {strings.scanShutter});
  });

  testWidgets('a passing gate with NO slicer '
      'seam: the gate never renders — the half-wired composition folds '
      'closed with the same quiet pop (the gate-seam convention)', (
    tester,
  ) async {
    final store = _RecordingStore();
    final files = _RecordingFiles();
    final camera = _FakeCamera();
    await launch(
      tester,
      controllerWith(
        store,
        files,
        camera,
        gate: _FakeGate(const FaceGatePass()),
        readSelectedProvider: () async => 'gemini',
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text(strings.scanShutter));
    await tester.pumpAndSettle();
    expect(find.byType(ConsentGateScreen), findsNothing);
    expect(find.byType(ScanScreen), findsNothing);
    expect(find.text(launchWord), findsOneWidget);
    expect(store.entries, isEmpty);
    expect(files.unlinkedScans, isNotEmpty);
    expect(camera.disposedCalls, isNotEmpty);
  });

  testWidgets('a passing gate with NO read seam: the gate never renders '
      'either — the half-wired mirror arm folds closed with the same '
      'quiet pop (the gate-seam convention)', (tester) async {
    final store = _RecordingStore();
    final files = _RecordingFiles();
    final camera = _FakeCamera();
    await launch(
      tester,
      controllerWith(
        store,
        files,
        camera,
        gate: _FakeGate(const FaceGatePass()),
        slicer: _FakeSlicer(),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text(strings.scanShutter));
    await tester.pumpAndSettle();
    expect(find.byType(ConsentGateScreen), findsNothing);
    expect(find.byType(ScanScreen), findsNothing);
    expect(find.text(launchWord), findsOneWidget);
    expect(store.entries, isEmpty);
    expect(files.unlinkedScans, isNotEmpty);
    expect(camera.disposedCalls, isNotEmpty);
  });

  testWidgets('a throwing provider read is the fail-closed quiet pop — '
      'route gone, the scan closed, no gate, no rows', (tester) async {
    final store = _RecordingStore();
    final files = _RecordingFiles();
    final camera = _FakeCamera();
    await launch(
      tester,
      controllerWith(
        store,
        files,
        camera,
        gate: _FakeGate(const FaceGatePass()),
        slicer: _FakeSlicer(),
        readSelectedProvider: () async => throw StateError('read threw'),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text(strings.scanShutter));
    await tester.pumpAndSettle();
    expect(find.byType(ConsentGateScreen), findsNothing);
    expect(find.byType(ScanScreen), findsNothing);
    expect(find.byType(ErrorWidget), findsNothing);
    expect(store.entries, isEmpty);
    expect(files.unlinkedScans, isNotEmpty);
    expect(camera.disposedCalls, isNotEmpty);
  });

  testWidgets('an id outside the frozen allowlist renders the no-key '
      'surface, never the gate with an empty name — the derivation '
      'gates charset, membership is the pre-gate read\'s', (tester) async {
    final store = _RecordingStore();
    final files = _RecordingFiles();
    await launch(
      tester,
      controllerWith(
        store,
        files,
        _FakeCamera(),
        gate: _FakeGate(const FaceGatePass()),
        slicer: _FakeSlicer(),
        // Charset-valid ([a-z0-9_]) but no allowlist entry.
        readSelectedProvider: () async => 'unknown_provider',
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text(strings.scanShutter));
    await tester.pumpAndSettle();
    expect(find.byType(ConsentGateScreen), findsNothing);
    expect(find.byType(NoSlicerSurface), findsOneWidget);
    expect(find.text(strings.noSlicerNoKey), findsOneWidget);
    expect(store.entries, isEmpty);
    expect(files.unlinkedScans, isNotEmpty);
  });

  testWidgets('a passing gate with a selected provider replaces the '
      'route with the consent gate — the frame survives the pass, no row '
      'stands, and the camera is already released at the handoff (the '
      'consent continuation, Story 5.5)', (tester) async {
    final store = _RecordingStore();
    final files = _RecordingFiles();
    final camera = _FakeCamera();
    await launch(
      tester,
      controllerWith(
        store,
        files,
        camera,
        gate: _FakeGate(const FaceGatePass()),
        slicer: _FakeSlicer(),
        readSelectedProvider: () async => 'gemini',
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text(strings.scanShutter));
    await tester.pumpAndSettle();
    expect(find.byType(ScanScreen), findsNothing);
    expect(find.byType(ConsentGateScreen), findsOneWidget);
    // The body interpolates the provider's rendered name.
    expect(
      find.text(strings.consentGateBody(strings.providerNameGemini)),
      findsOneWidget,
    );
    // The lens released at the handoff: no privacy indicator stands
    // lit through the open-ended consent ask.
    expect(camera.disposedCalls, isNotEmpty);
    expect(store.entries, isEmpty);
    expect(files.unlinkedScans, isEmpty);
  });

  testWidgets('a passing gate with NO provider selected: the gate never '
      'renders — the no-key surface replaces the route and the scan '
      'closes quietly (consent is never asked for a request that cannot '
      'be made)', (tester) async {
    final store = _RecordingStore();
    final files = _RecordingFiles();
    await launch(
      tester,
      controllerWith(
        store,
        files,
        _FakeCamera(),
        gate: _FakeGate(const FaceGatePass()),
        slicer: _FakeSlicer(),
        readSelectedProvider: () async => null,
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text(strings.scanShutter));
    await tester.pumpAndSettle();
    expect(find.byType(ScanScreen), findsNothing);
    expect(find.byType(ConsentGateScreen), findsNothing);
    expect(find.byType(NoSlicerSurface), findsOneWidget);
    expect(find.text(strings.noSlicerNoKey), findsOneWidget);
    expect(store.entries, isEmpty);
    expect(files.unlinkedScans, isNotEmpty);
  });

  testWidgets('declining from the gate routes the no-Slicer surface with '
      'its own string — one consent_declined row, the slicer never '
      'called, no re-ask (FR-25, FR-29)', (tester) async {
    final store = _RecordingStore();
    final files = _RecordingFiles();
    final slicer = _FakeSlicer();
    await launch(
      tester,
      controllerWith(
        store,
        files,
        _FakeCamera(),
        gate: _FakeGate(const FaceGatePass()),
        slicer: slicer,
        readSelectedProvider: () async => 'gemini',
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text(strings.scanShutter));
    await tester.pumpAndSettle();
    expect(find.text(strings.consentGateDecline), findsOneWidget);
    await tester.tap(find.text(strings.consentGateDecline));
    await tester.pumpAndSettle();
    expect(find.byType(ConsentGateScreen), findsNothing);
    expect(find.byType(NoSlicerSurface), findsOneWidget);
    expect(find.text(strings.noSlicerConsentDeclined), findsOneWidget);
    expect(store.entries, hasLength(1));
    expect(store.entries.single.kind, 'consent_declined');
    expect(slicer.requests, isEmpty);
    expect(files.unlinkedScans, isNotEmpty);
  });

  testWidgets('accepting from the gate dispatches exactly once and '
      'closes quietly to the Dispenser on delivery — one consent_granted '
      'row, the interim discard (P2-A), nothing queued', (tester) async {
    final store = _RecordingStore();
    final files = _RecordingFiles();
    final slicer = _FakeSlicer();
    await launch(
      tester,
      controllerWith(
        store,
        files,
        _FakeCamera(),
        gate: _FakeGate(const FaceGatePass()),
        slicer: slicer,
        readSelectedProvider: () async => 'gemini',
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text(strings.scanShutter));
    await tester.pumpAndSettle();
    await tester.tap(find.text(strings.consentGateSend));
    // Fixed-duration pumps from the accept arm onward: the wait's
    // pencil repeats forever and never settles (Story 5.6).
    await tester.pump();
    await tester.pump(routePopSettle);
    // Delivered: the scan closes to the Dispenser — the launch surface
    // is back, nothing landed, no second answer exists.
    expect(find.byType(ConsentGateScreen), findsNothing);
    expect(find.text(launchWord), findsOneWidget);
    expect(slicer.requests, hasLength(1));
    expect(store.entries, hasLength(1));
    expect(store.entries.single.kind, 'consent_granted');
    expect(files.unlinkedScans, isNotEmpty);
  });

  testWidgets('a failed dispatch routes the no-Slicer surface through '
      "the standing cause map — the failure arm's string, not a new one", (
    tester,
  ) async {
    final store = _RecordingStore();
    final files = _RecordingFiles();
    final slicer = _FakeSlicer(
      outcome: const SlicerFailed(SlicerFailureCause.invalidKey),
    );
    await launch(
      tester,
      controllerWith(
        store,
        files,
        _FakeCamera(),
        gate: _FakeGate(const FaceGatePass()),
        slicer: slicer,
        readSelectedProvider: () async => 'gemini',
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text(strings.scanShutter));
    await tester.pumpAndSettle();
    await tester.tap(find.text(strings.consentGateSend));
    // Fixed-duration pumps: the wait's pencil never settles (5.6).
    await tester.pump();
    await tester.pump(routePopSettle);
    expect(find.byType(NoSlicerSurface), findsOneWidget);
    expect(find.text(strings.noSlicerInvalidKey), findsOneWidget);
    expect(store.entries.single.kind, 'consent_granted');
    expect(files.unlinkedScans, isNotEmpty);
  });

  testWidgets('the system back on the gate leaves quietly: no row, the '
      'scan closes — leaving is not declining', (tester) async {
    final store = _RecordingStore();
    final files = _RecordingFiles();
    final camera = _FakeCamera();
    final slicer = _FakeSlicer();
    await launch(
      tester,
      controllerWith(
        store,
        files,
        camera,
        gate: _FakeGate(const FaceGatePass()),
        slicer: slicer,
        readSelectedProvider: () async => 'gemini',
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text(strings.scanShutter));
    await tester.pumpAndSettle();
    expect(find.byType(ConsentGateScreen), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byType(ConsentGateScreen), findsNothing);
    expect(find.text(launchWord), findsOneWidget);
    expect(store.entries, isEmpty);
    expect(slicer.requests, isEmpty);
    expect(files.unlinkedScans, isNotEmpty);
    expect(camera.disposedCalls, isNotEmpty);
  });

  testWidgets('a refused frame replaces the route with the one calm '
      'surface carrying the personInFrame copy, and exactly one '
      'face_refused row lands (FR-25, AD-21)', (tester) async {
    final store = _RecordingStore();
    final files = _RecordingFiles();
    await launch(
      tester,
      controllerWith(
        store,
        files,
        _FakeCamera(),
        gate: _FakeGate(const FaceGateRefusal()),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text(strings.scanShutter));
    await tester.pumpAndSettle();
    expect(find.byType(ScanScreen), findsNothing);
    expect(find.byType(NoSlicerSurface), findsOneWidget);
    expect(find.text(strings.personInFrame), findsOneWidget);
    expect(store.entries, hasLength(1));
    expect(store.entries.single.kind, 'face_refused');
    expect(files.unlinkedScans, isNotEmpty);
  });

  testWidgets('a denied open pops the route and appends exactly one '
      'permission_refused{camera} row (FR-16, AD-17)', (tester) async {
    final store = _RecordingStore();
    final files = _RecordingFiles();
    await launch(
      tester,
      controllerWith(
        store,
        files,
        _FakeCamera(openOutcome: CameraOpenOutcome.denied),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(ScanScreen), findsNothing);
    expect(store.entries, hasLength(1));
    expect(store.entries.single.kind, 'permission_refused');
    expect(store.entries.single.permission, 'camera');
  });

  testWidgets('an interrupted ask keeps the surface standing with the '
      'honest problem notice — no pop, no row, the entry untouched; the '
      'OS back is the way out (ruling 1-B)', (tester) async {
    final store = _RecordingStore();
    await launch(
      tester,
      controllerWith(
        store,
        _RecordingFiles(),
        _FakeCamera(openOutcome: CameraOpenOutcome.interrupted),
      ),
    );
    await tester.pumpAndSettle();
    // The surface STAYS: the notice is its whole content, the shutter
    // gone beneath a camera that did not open.
    expect(find.byType(ScanScreen), findsOneWidget);
    expect(find.text(strings.scanOpenFailed), findsOneWidget);
    expect(find.text(strings.scanShutter), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(
      store.entries,
      isEmpty,
      reason: 'a malfunction is never recorded as a refusal',
    );
    // The way out is the OS back — the way on is backing out and
    // tapping Cámara again (the entry never moved).
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byType(ScanScreen), findsNothing);
    expect(store.entries, isEmpty);
  });

  testWidgets('a failed open (a device error) keeps the surface standing '
      'with the same notice — no rows, the entry remains (the declared '
      'corner)', (tester) async {
    final store = _RecordingStore();
    await launch(
      tester,
      controllerWith(
        store,
        _RecordingFiles(),
        _FakeCamera(openOutcome: CameraOpenOutcome.unavailable),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(ScanScreen), findsOneWidget);
    expect(find.text(strings.scanOpenFailed), findsOneWidget);
    expect(find.text(strings.scanShutter), findsNothing);
    expect(store.entries, isEmpty);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byType(ScanScreen), findsNothing);
    expect(store.entries, isEmpty);
  });

  testWidgets('the OS back is the way out: the route pops, the '
      'controller closes (unlink + dispose), no rows', (tester) async {
    final store = _RecordingStore();
    final files = _RecordingFiles();
    final camera = _FakeCamera();
    await launch(tester, controllerWith(store, files, camera));
    await tester.pumpAndSettle();
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byType(ScanScreen), findsNothing);
    expect(store.entries, isEmpty);
    expect(files.unlinkedScans, isNotEmpty);
    expect(camera.disposedCalls, isNotEmpty);
  });

  testWidgets('the null-controller test seam: the surface renders its '
      'empty frame and nothing resolves — the honest nothing', (tester) async {
    await launch(tester, null);
    expect(find.byType(ScanScreen), findsOneWidget);
    expect(find.text(strings.scanShutter), findsNothing);
    expect(find.byKey(_FakeCamera.previewKey), findsNothing);
  });

  testWidgets('a throwing open seam lands in the notice, never the '
      'eternal empty frame — no row, the surface stays (fail-closed '
      'guards)', (tester) async {
    final store = _RecordingStore();
    final files = _RecordingFiles();
    final camera = _FakeCamera(throwOnOpen: true);
    await launch(tester, controllerWith(store, files, camera));
    await tester.pumpAndSettle();
    expect(find.byType(ScanScreen), findsOneWidget);
    expect(find.text(strings.scanOpenFailed), findsOneWidget);
    expect(find.text(strings.scanShutter), findsNothing);
    expect(store.entries, isEmpty);
    expect(find.byType(ErrorWidget), findsNothing);
  });

  testWidgets('a lost grant at the shutter keeps the surface with the '
      'honest notice — no pop that would read as a taken photo, no '
      'permission_refused row', (tester) async {
    final store = _RecordingStore();
    final files = _RecordingFiles();
    final camera = _FakeCamera(shotOutcome: const CameraShotAccessLost());
    final gate = _FakeGate(const FaceGatePass());
    await launch(tester, controllerWith(store, files, camera, gate: gate));
    await tester.pumpAndSettle();
    await tester.tap(find.text(strings.scanShutter));
    await tester.pumpAndSettle();
    expect(find.byType(ScanScreen), findsOneWidget);
    expect(find.text(strings.scanOpenFailed), findsOneWidget);
    expect(find.text(strings.scanShutter), findsNothing);
    expect(store.entries, isEmpty);
    expect(camera.disposedCalls, isNotEmpty);
    expect(find.byType(ErrorWidget), findsNothing);
  });

  testWidgets('a throwing shoot seam is the quiet fail-closed close: '
      'the flight resets and the route pops, nothing surfaced', (tester) async {
    final store = _RecordingStore();
    final files = _RecordingFiles();
    final camera = _FakeCamera(throwOnShoot: true);
    final gate = _FakeGate(const FaceGatePass());
    await launch(tester, controllerWith(store, files, camera, gate: gate));
    await tester.pumpAndSettle();
    expect(find.byKey(_FakeCamera.previewKey), findsOneWidget);

    await tester.tap(find.text(strings.scanShutter));
    await tester.pumpAndSettle();
    // The seam threw: no frame, no row, no error surface — the same
    // quiet pop every closed scan takes.
    expect(find.byType(ScanScreen), findsNothing);
    expect(store.entries, isEmpty);
    expect(find.byType(ErrorWidget), findsNothing);
  });

  testWidgets('a backgrounding releases the camera and a resume '
      're-opens through the fast path: the preview leaves and returns, '
      'no rows either way (the lifecycle owns the lens)', (tester) async {
    final store = _RecordingStore();
    final files = _RecordingFiles();
    final camera = _FakeCamera();
    await launch(tester, controllerWith(store, files, camera));
    await tester.pumpAndSettle();
    expect(find.byKey(_FakeCamera.previewKey), findsOneWidget);
    expect(camera.openedCalls, hasLength(1));
    expect(camera.disposedCalls, isEmpty);

    // The app leaves the foreground mid-scan: the camera releases.
    // (Driven as inactive — Android's own first signal, on which the
    // release already runs; the paused state that follows disables
    // frames in the test binding, and a backgrounded surface renders
    // nothing anyway.)
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pumpAndSettle();
    expect(
      camera.disposedCalls,
      hasLength(1),
      reason: 'no lens stands open behind a backgrounded surface',
    );
    expect(files.unlinkedScans, isNotEmpty);
    expect(
      find.byKey(_FakeCamera.previewKey),
      findsNothing,
      reason: 'the empty frame replaces the released preview',
    );
    expect(
      find.text(strings.scanShutter),
      findsNothing,
      reason: 'the released lens has no live shutter',
    );
    expect(find.byType(ScanScreen), findsOneWidget);

    // The return: the fast path re-opens (granted again — no dialog
    // on this side of the seam) and the preview is back.
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(camera.openedCalls, hasLength(2));
    expect(find.byKey(_FakeCamera.previewKey), findsOneWidget);
    expect(find.text(strings.scanShutter), findsOneWidget);
    expect(
      store.entries,
      isEmpty,
      reason: 'a release and a restore are no refusal and no scan',
    );
  });

  testWidgets('a staged permission ask owns the moment: the dialog\'s '
      'own inactive releases nothing, and the grant lands normally '
      'after the resume', (tester) async {
    final store = _RecordingStore();
    final files = _RecordingFiles();
    final camera = _FakeCamera()..openGate = Completer<CameraOpenOutcome>();
    await launch(tester, controllerWith(store, files, camera));
    await tester.pump();

    // The system dialog's own lifecycle: inactive while the ask stands.
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pumpAndSettle();
    expect(
      camera.disposedCalls,
      isEmpty,
      reason: 'the ask owns the moment — no release beneath it',
    );

    // The user answers and the app resumes: the grant resolves and
    // the preview runs, no re-open needed.
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    camera.openGate!.complete(CameraOpenOutcome.granted);
    await tester.pumpAndSettle();
    expect(camera.openedCalls, hasLength(1));
    expect(find.byKey(_FakeCamera.previewKey), findsOneWidget);
    expect(store.entries, isEmpty);
  });
}

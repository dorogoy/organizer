// The scan controller's contract (Story 5.2, FR-16, FR-25, AD-17;
// ruling 1-B): the frozen I/O matrix, row by row, over fakes — the
// first-use permission moment with its two domains kept apart
// (granted / denied / interrupted / unavailable; no hardware rides
// the open's own unavailable outcome, no pre-check), the shoot flow
// (frame written before the gate, gate pass, face refusal, detector
// failure), the terminal-path unlink on every exit, the close-epoch
// guards (a late granted answer initializes nothing after a close; a
// late frame creates nothing after the terminal unlink), and the row
// counts the log owes (exactly one `permission_refused{camera}` per
// explicit denial, exactly one `face_refused` per refusal, nothing on
// interrupted or failed opens — a malfunction is never mistaken for
// the user's refusal). The controller is binding-free: plain tests,
// no pumping.
import 'dart:async';

import 'package:core/ports/face_gate_port.dart';
import 'package:core/ports/files_port.dart';
import 'package:core/ports/scan_consent.dart';
import 'package:core/ports/slicer_port.dart';
import 'package:core/ports/store_port.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uuid/uuid.dart';

import 'package:organizer/plugins/camera/camera_shell.dart';
import 'package:organizer/scan/scan_controller.dart';

/// The recording store (the capture suite's own contract).
class _RecordingStore implements StorePort {
  final List<PoolFactRecord> facts = [];
  final List<LogEntryRecord> entries = [];

  /// Optional brake on the append: when set, the next append parks on
  /// this completer — the race tests' window for landing a close
  /// mid-write (the UI suite's own _RecordingStore pattern).
  Completer<void>? appendGate;

  @override
  Future<void> appendPoolFact(PoolFactRecord fact) async => facts.add(fact);

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
  Future<List<PoolFactRecord>> readPoolFacts() async =>
      List.unmodifiable(facts);

  @override
  Future<List<LogEntryRecord>> readLogEntries() async =>
      List.unmodifiable(entries);
}

/// A store whose `appendLogEntry` always throws — the quiet-absorption
/// queue path's own row (the dictation suite's precedent).
class _ThrowingAppendStore implements StorePort {
  _ThrowingAppendStore(this._inner);

  final _RecordingStore _inner;

  @override
  Future<void> appendPoolFact(PoolFactRecord fact) async =>
      _inner.appendPoolFact(fact);

  @override
  Future<void> appendLogEntry(LogEntryRecord entry) async {
    throw StateError('append failed');
  }

  @override
  Future<List<PoolFactRecord>> readPoolFacts() async => _inner.readPoolFacts();

  @override
  Future<List<LogEntryRecord>> readLogEntries() async =>
      _inner.readLogEntries();
}

/// The Files fake: every write and unlink recorded, the frame's path
/// handed to the gate exactly as production hands it.
class _RecordingFiles implements FilesPort {
  final writtenFrames = <(String, List<int>)>[];
  final unlinkedScans = <String>[];
  var framePathToReturn = '/cache/scan_cache/x/frame.jpg';

  /// Optional brake on the scan unlink: when set, the next unlink
  /// parks on this completer — the resolution's tail-unlink race
  /// window.
  Completer<void>? unlinkGate;

  @override
  Future<List<int>?> read(String scope, String name) async => null;

  @override
  Future<void> write(String scope, String name, List<int> bytes) async {}

  @override
  Future<void> delete(String scope, String name) async {}

  @override
  Future<String> writeScanFrame(String scanId, List<int> bytes) async {
    writtenFrames.add((scanId, bytes));
    return framePathToReturn;
  }

  @override
  Future<void> unlinkScan(String scanId) async {
    unlinkedScans.add(scanId);
    final gate = unlinkGate;
    if (gate != null) {
      unlinkGate = null;
      await gate.future;
    }
  }

  @override
  Future<String> writeScanCappedCopy(String scanId, List<int> bytes) async =>
      '';

  @override
  Future<void> sweepScanCache() async {}
}

/// The camera fake: the outcomes the tests steer, the calls the tests
/// read, and an open gate so the staged permission moment's window is
/// holdable.
class _FakeCamera implements CameraShell {
  _FakeCamera({this.openOutcome});

  CameraOpenOutcome? openOutcome;
  CameraShotOutcome shotOutcome = const CameraShotCaptured([1, 2, 3]);
  final openedCalls = <void>[];
  final disposedCalls = <void>[];

  /// When set, [open] parks on this completer before answering — the
  /// staged ask's window.
  Completer<CameraOpenOutcome>? openGate;

  /// When set, [takePicture] parks on this completer before
  /// answering — the shot's in-flight window.
  Completer<CameraShotOutcome>? shotGate;

  @override
  Future<CameraOpenOutcome> open() async {
    openedCalls.add(null);
    final gate = openGate;
    if (gate != null) {
      await gate.future;
    }
    return openOutcome ?? CameraOpenOutcome.granted;
  }

  @override
  Future<CameraShotOutcome> takePicture() async {
    final gate = shotGate;
    if (gate != null) {
      await gate.future;
    }
    return shotOutcome;
  }

  @override
  Widget buildPreview() => const SizedBox.shrink();

  @override
  Future<void> dispose() async => disposedCalls.add(null);
}

/// A Files fake whose scan-frame write parks on a completer until
/// the test releases it — the write's in-flight window, held open
/// long enough to race a close against it.
class _GatedWriteFiles implements FilesPort {
  final started = Completer<void>();
  final writeGate = Completer<void>();
  final writeScanIds = <String>[];
  final unlinkedScans = <String>[];

  void release() => writeGate.complete();

  @override
  Future<List<int>?> read(String scope, String name) async => null;

  @override
  Future<void> write(String scope, String name, List<int> bytes) async {}

  @override
  Future<void> delete(String scope, String name) async {}

  @override
  Future<String> writeScanFrame(String scanId, List<int> bytes) async {
    writeScanIds.add(scanId);
    started.complete();
    await writeGate.future;
    return '/cache/scan_cache/$scanId/frame.jpg';
  }

  @override
  Future<void> unlinkScan(String scanId) async => unlinkedScans.add(scanId);

  @override
  Future<String> writeScanCappedCopy(String scanId, List<int> bytes) async =>
      '';

  @override
  Future<void> sweepScanCache() async {}
}

/// The gate fake: pass, refusal, or a throwing detector.
class _FakeGate implements FaceGatePort {
  _FakeGate(this.outcome, {this.hold});

  final Object? outcome; // FaceGatePass | FaceGateRefusal | Exception
  final gatedPaths = <String>[];
  final Completer<void>? hold;
  final started = Completer<void>();

  @override
  Future<FaceGateOutcome> gate(String framePath) async {
    gatedPaths.add(framePath);
    if (!started.isCompleted) {
      started.complete();
    }
    final hold = this.hold;
    if (hold != null) {
      await hold.future;
    }
    final outcome = this.outcome;
    if (outcome is FaceGateOutcome) {
      return outcome;
    }
    throw outcome!;
  }
}

/// The Slicer fake: the requests the tests read (bytes, prompt, scanId,
/// token), the outcome the tests steer, and an in-flight window the
/// close epoch races against.
class _FakeSlicer implements SlicerPort {
  _FakeSlicer({SlicerOutcome? outcome})
    : outcome =
          outcome ??
          const SlicerDelivered('[{"text": "x", "duration_minutes": 4}]');

  SlicerOutcome outcome;

  /// When set, [slice] throws — a malfunctioning seam, never a
  /// taxonomy value (the containment arm's own test input).
  Object? throwOnSlice;
  final requests = <ScanSliceRequest>[];
  Completer<void>? gate;
  Completer<void>? sliceStarted;

  @override
  Future<SlicerOutcome> slice(SlicerRequest request) async {
    requests.add(request as ScanSliceRequest);
    final started = sliceStarted;
    if (started != null && !started.isCompleted) {
      started.complete();
    }
    final gate = this.gate;
    if (gate != null) {
      await gate.future;
    }
    final throwOnSlice = this.throwOnSlice;
    if (throwOnSlice != null) {
      throw throwOnSlice;
    }
    return outcome;
  }
}

DateTime _fixedClock() => DateTime.utc(2026, 9, 5, 10);

void main() {
  group('open — the first-use permission moment (AD-17, NFR8)', () {
    test('granted: the surface may run, nothing is appended', () async {
      final store = _RecordingStore();
      final files = _RecordingFiles();
      final camera = _FakeCamera();
      final controller = ScanController(
        store: store,
        files: files,
        camera: camera,
        nowOf: _fixedClock,
      );
      expect(await controller.open(), CameraOpenOutcome.granted);
      expect(store.entries, isEmpty);
      expect(
        files.unlinkedScans,
        isEmpty,
        reason: 'a standing scan owns its directory until it ends',
      );
    });

    test('denied: exactly one permission_refused{camera} row, the '
        'camera disposed, the scan unlinked (FR-16, AD-17)', () async {
      final store = _RecordingStore();
      final files = _RecordingFiles();
      final camera = _FakeCamera(openOutcome: CameraOpenOutcome.denied);
      final controller = ScanController(
        store: store,
        files: files,
        camera: camera,
        nowOf: _fixedClock,
      );
      expect(await controller.open(), CameraOpenOutcome.denied);
      expect(store.entries, hasLength(1));
      final row = store.entries.single;
      expect(row.kind, 'permission_refused');
      expect(row.permission, 'camera');
      expect(row.instantUtcMicros, _fixedClock().microsecondsSinceEpoch);
      expect(camera.disposedCalls, hasLength(1));
      expect(files.unlinkedScans, hasLength(1));
    });

    test('interrupted (the system swallowed the ask — no answer '
        'existed): the notice outcome, no row, the entry stays, the '
        'camera half torn down — and the next tap asks again', () async {
      final store = _RecordingStore();
      final files = _RecordingFiles();
      final camera = _FakeCamera(openOutcome: CameraOpenOutcome.interrupted);
      final controller = ScanController(
        store: store,
        files: files,
        camera: camera,
        nowOf: _fixedClock,
      );
      expect(await controller.open(), CameraOpenOutcome.interrupted);
      expect(
        store.entries,
        isEmpty,
        reason:
            'a malfunction is never mistaken for the user\'s refusal '
            '(ruling 1-B)',
      );
      expect(camera.disposedCalls, hasLength(1));
      expect(files.unlinkedScans, hasLength(1));
      // Nothing about the interruption is durable: a fresh open asks
      // afresh (the fake answers interrupted again — the ask ran).
      expect(await controller.open(), CameraOpenOutcome.interrupted);
      expect(camera.openedCalls, hasLength(2));
      expect(store.entries, isEmpty);
    });

    test('unavailable (a device error at open): the same notice '
        'outcome, no row — the entry remains', () async {
      final store = _RecordingStore();
      final camera = _FakeCamera(openOutcome: CameraOpenOutcome.unavailable);
      final controller = ScanController(
        store: store,
        files: _RecordingFiles(),
        camera: camera,
        nowOf: _fixedClock,
      );
      expect(await controller.open(), CameraOpenOutcome.unavailable);
      expect(store.entries, isEmpty);
    });

    test('no camera hardware rides the open outcome itself — no '
        'availability pre-check, no duplicate platform round-trip: the '
        'facade answers unavailable and the notice outcome stands, no '
        'rows (the declared corner)', () async {
      final store = _RecordingStore();
      final camera = _FakeCamera(openOutcome: CameraOpenOutcome.unavailable);
      final controller = ScanController(
        store: store,
        files: _RecordingFiles(),
        camera: camera,
        nowOf: _fixedClock,
      );
      expect(await controller.open(), CameraOpenOutcome.unavailable);
      expect(
        camera.openedCalls,
        hasLength(1),
        reason: 'the one open carries the no-hardware case',
      );
      expect(store.entries, isEmpty);
    });

    test('a late granted answer after a close initializes nothing: the '
        'camera half is disposed and the interruption answers (the '
        'close-epoch guard)', () async {
      final store = _RecordingStore();
      final files = _RecordingFiles();
      final camera = _FakeCamera()..openGate = Completer<CameraOpenOutcome>();
      final controller = ScanController(
        store: store,
        files: files,
        camera: camera,
        nowOf: _fixedClock,
      );
      final opening = controller.open();
      // The surface left while the staged ask stood: the terminal
      // close runs and bumps the epoch beneath the unresolved ask.
      await controller.close();
      camera.openGate!.complete(CameraOpenOutcome.granted);
      expect(await opening, CameraOpenOutcome.interrupted);
      // The camera the plugin opened behind the grant is released —
      // nothing stands behind a closed scan — and no row lands.
      expect(camera.disposedCalls, isNotEmpty);
      expect(store.entries, isEmpty);
    });

    test('a late DENIED answer after a close still lands its row — the '
        'refusal is the user\'s act, not the surface\'s lifetime', () async {
      final store = _RecordingStore();
      final camera = _FakeCamera(openOutcome: CameraOpenOutcome.denied)
        ..openGate = Completer<CameraOpenOutcome>();
      final controller = ScanController(
        store: store,
        files: _RecordingFiles(),
        camera: camera,
        nowOf: _fixedClock,
      );
      final opening = controller.open();
      await controller.close();
      camera.openGate!.complete(CameraOpenOutcome.denied);
      expect(await opening, CameraOpenOutcome.denied);
      expect(store.entries, hasLength(1));
      expect(store.entries.single.kind, 'permission_refused');
    });
  });

  group('shoot — the frame, the gate, the branch (FR-25)', () {
    Future<ScanController> openGranted(
      _RecordingStore store,
      _RecordingFiles files,
      _FakeCamera camera, {
      FaceGatePort? gate,
      SlicerPort? slicer,
      Future<String?> Function()? readSelectedProvider,
    }) async {
      final controller = ScanController(
        store: store,
        files: files,
        camera: camera,
        gate: gate,
        slicer: slicer,
        readSelectedProvider: readSelectedProvider,
        idMinter: const Uuid(),
        nowOf: _fixedClock,
      );
      expect(await controller.open(), CameraOpenOutcome.granted);
      return controller;
    }

    test('no face: the gate passes and the frame SURVIVES the pass — '
        'the directory is not unlinked, nothing is appended, and the arm '
        'carries the standing scan identity plus the frame bytes (the '
        "consent act's payload, Story 5.5)", () async {
      final store = _RecordingStore();
      final files = _RecordingFiles();
      final gate = _FakeGate(const FaceGatePass());
      final camera = _FakeCamera()
        ..shotOutcome = const CameraShotCaptured([7, 8, 9]);
      final controller = await openGranted(store, files, camera, gate: gate);
      final outcome = await controller.shoot();
      expect(outcome, isA<ScanShootGatePassed>());
      final passed = outcome as ScanShootGatePassed;
      expect(passed.scanId, isNotEmpty);
      // The frame was written and the gate read the written path; the
      // bytes themselves are pinned by the accept test below, through
      // the one dispatch (the arm carries the identity, not the bytes).
      expect(files.writtenFrames, hasLength(1));
      expect(gate.gatedPaths, [files.framePathToReturn]);
      // Gate-pass is no longer a terminal path: the directory stands
      // for the consent act to resolve.
      expect(files.unlinkedScans, isEmpty);
      expect(store.entries, isEmpty);
    });

    test('a face in the frame: one face_refused row, the frame '
        'unlinked, the refusal outcome for the calm surface (FR-25, '
        'AD-21)', () async {
      final store = _RecordingStore();
      final files = _RecordingFiles();
      final gate = _FakeGate(const FaceGateRefusal());
      final controller = await openGranted(
        store,
        files,
        _FakeCamera(),
        gate: gate,
      );
      final outcome = await controller.shoot();
      expect(outcome, isA<ScanShootRefused>());
      expect(store.entries, hasLength(1));
      final row = store.entries.single;
      expect(row.kind, 'face_refused');
      expect(row.permission, isNull);
      expect(row.instantUtcMicros, _fixedClock().microsecondsSinceEpoch);
      expect(files.unlinkedScans, hasLength(1));
    });

    test('a detector error folds closed: no face_refused row — a '
        'failure is not a refusal — the frame unlinked, fail closed', () async {
      final store = _RecordingStore();
      final files = _RecordingFiles();
      final gate = _FakeGate(StateError('detector errored'));
      final controller = await openGranted(
        store,
        files,
        _FakeCamera(),
        gate: gate,
      );
      final outcome = await controller.shoot();
      expect(outcome, isA<ScanShootClosed>());
      expect(
        store.entries,
        isEmpty,
        reason: 'no false privacy claims in the log',
      );
      expect(files.unlinkedScans, hasLength(1));
    });

    test('a failed shot (no bytes) is the same quiet fail-closed '
        'close: nothing written, nothing gated, nothing appended', () async {
      final store = _RecordingStore();
      final files = _RecordingFiles();
      final gate = _FakeGate(const FaceGatePass());
      final camera = _FakeCamera()..shotOutcome = const CameraShotNone();
      final controller = await openGranted(store, files, camera, gate: gate);
      final outcome = await controller.shoot();
      expect(outcome, isA<ScanShootClosed>());
      expect(files.writtenFrames, isEmpty);
      expect(gate.gatedPaths, isEmpty);
      expect(store.entries, isEmpty);
      expect(files.unlinkedScans, hasLength(1));
    });

    test('a frame write that yields the empty path never gates — the '
        'quiet fail-closed close', () async {
      final store = _RecordingStore();
      final files = _RecordingFiles()..framePathToReturn = '';
      final gate = _FakeGate(const FaceGatePass());
      final controller = await openGranted(
        store,
        files,
        _FakeCamera(),
        gate: gate,
      );
      expect(await controller.shoot(), isA<ScanShootClosed>());
      expect(gate.gatedPaths, isEmpty);
      expect(store.entries, isEmpty);
      expect(files.unlinkedScans, hasLength(1));
    });

    test('no gate behind the test seam: a shot folds closed quietly — '
        'nothing half-wired proceeds', () async {
      final store = _RecordingStore();
      final files = _RecordingFiles();
      final controller = await openGranted(store, files, _FakeCamera());
      expect(await controller.shoot(), isA<ScanShootClosed>());
      expect(store.entries, isEmpty);
      expect(files.unlinkedScans, hasLength(1));
    });

    test('a close during the shot writes nothing after it — the bytes '
        'die with the epoch, and no directory is recreated (the '
        'close-epoch guard)', () async {
      final store = _RecordingStore();
      final files = _RecordingFiles();
      final camera = _FakeCamera()..shotGate = Completer<CameraShotOutcome>();
      final gate = _FakeGate(const FaceGatePass());
      final controller = ScanController(
        store: store,
        files: files,
        camera: camera,
        gate: gate,
        idMinter: const Uuid(),
        nowOf: _fixedClock,
      );
      expect(await controller.open(), CameraOpenOutcome.granted);
      final shooting = controller.shoot();
      // The surface left while the shot stood: the terminal close
      // unlinks beneath the unresolved shot.
      await controller.close();
      expect(files.unlinkedScans, hasLength(1));
      camera.shotGate!.complete(const CameraShotCaptured([9, 9, 9]));
      expect(await shooting, isA<ScanShootClosed>());
      // Nothing was written after the close — the captured identity's
      // directory is not recreated — and nothing was gated.
      expect(files.writtenFrames, isEmpty);
      expect(gate.gatedPaths, isEmpty);
      expect(store.entries, isEmpty);
      expect(
        files.unlinkedScans,
        hasLength(1),
        reason: 'the stale path unlinks nothing new: it created nothing',
      );
    });

    test('a lost grant at the shutter is a system problem: the failed '
        'outcome, no permission_refused row, the camera tears down', () async {
      final store = _RecordingStore();
      final files = _RecordingFiles();
      final camera = _FakeCamera()..shotOutcome = const CameraShotAccessLost();
      final controller = await openGranted(
        store,
        files,
        camera,
        gate: _FakeGate(const FaceGatePass()),
      );
      expect(await controller.shoot(), isA<ScanShootFailed>());
      expect(
        store.entries,
        isEmpty,
        reason: 'a malfunction is never recorded as a refusal',
      );
      expect(files.writtenFrames, isEmpty);
      expect(
        camera.disposedCalls,
        isEmpty,
        reason: 'the surface drops the preview before close',
      );
    });

    test('a close during the gate does not append face_refused — a late '
        'refusal after exit is not a privacy decision', () async {
      final store = _RecordingStore();
      final files = _RecordingFiles();
      final hold = Completer<void>();
      final gate = _FakeGate(const FaceGateRefusal(), hold: hold);
      final controller = await openGranted(
        store,
        files,
        _FakeCamera(),
        gate: gate,
      );
      final shooting = controller.shoot();
      await gate.started.future;
      await controller.close();
      hold.complete();
      expect(await shooting, isA<ScanShootClosed>());
      expect(store.entries, isEmpty);
    });

    test('a close landing inside the write itself unlinks the recreated '
        'directory through the captured identity', () async {
      final store = _RecordingStore();
      // The write parks: the close lands while the frame is being
      // written, so the directory exists again when the write answers.
      final gatedFiles = _GatedWriteFiles();
      final camera = _FakeCamera();
      final gate = _FakeGate(const FaceGatePass());
      final controller = ScanController(
        store: store,
        files: gatedFiles,
        camera: camera,
        gate: gate,
        idMinter: const Uuid(),
        nowOf: _fixedClock,
      );
      expect(await controller.open(), CameraOpenOutcome.granted);
      final shooting = controller.shoot();
      await gatedFiles.started.future;
      await controller.close();
      gatedFiles.release();
      expect(await shooting, isA<ScanShootClosed>());
      // The stale write's directory died through the captured scan
      // identity, and nothing reached the gate.
      expect(gatedFiles.writeScanIds, hasLength(1));
      expect(gatedFiles.unlinkedScans, containsAll(gatedFiles.writeScanIds));
      expect(gate.gatedPaths, isEmpty);
      expect(store.entries, isEmpty);
    });

    test('a rapid second shutter tap is nothing at all — one frame, '
        'one row, one unlink', () async {
      final store = _RecordingStore();
      final files = _RecordingFiles();
      final gate = _FakeGate(const FaceGateRefusal());
      final controller = await openGranted(
        store,
        files,
        _FakeCamera(),
        gate: gate,
      );
      final first = controller.shoot();
      final second = controller.shoot();
      await Future.wait([first, second]);
      expect(files.writtenFrames, hasLength(1));
      expect(store.entries, hasLength(1));
    });
  });

  group('consent — the phase after the gate pass (Story 5.5, FR-25, '
      'AD-8, FR-29)', () {
    /// A standing scan at the consent moment: shot bytes [1, 2, 3],
    /// the gate passed, the frame surviving.
    Future<(ScanController, ScanShootGatePassed)> standingScan(
      _RecordingStore store,
      _RecordingFiles files, {
      _FakeSlicer? slicer,
      Future<String?> Function()? readSelectedProvider,
    }) async {
      final controller = ScanController(
        store: store,
        files: files,
        camera: _FakeCamera()
          ..shotOutcome = const CameraShotCaptured([1, 2, 3]),
        gate: _FakeGate(const FaceGatePass()),
        slicer: slicer,
        readSelectedProvider: readSelectedProvider,
        idMinter: const Uuid(),
        nowOf: _fixedClock,
      );
      expect(await controller.open(), CameraOpenOutcome.granted);
      final outcome = await controller.shoot();
      expect(outcome, isA<ScanShootGatePassed>());
      return (controller, outcome as ScanShootGatePassed);
    }

    test('decline: exactly one payload-less consent_declined row, the '
        'cache unlinked, the slicer never called, no consent_granted row '
        '(FR-25, FR-29, AD-21)', () async {
      final store = _RecordingStore();
      final files = _RecordingFiles();
      final slicer = _FakeSlicer();
      final (controller, passed) = await standingScan(
        store,
        files,
        slicer: slicer,
      );
      // The decline stood: one row, one unlink, the slicer untouched.
      expect(await controller.declineConsent(), isTrue);
      expect(store.entries, hasLength(1));
      final row = store.entries.single;
      expect(row.kind, 'consent_declined');
      expect(row.itemId, isNull);
      expect(row.settingKey, isNull);
      expect(row.permission, isNull);
      expect(row.sliceCause, isNull);
      expect(row.instantUtcMicros, _fixedClock().microsecondsSinceEpoch);
      expect(files.unlinkedScans, [passed.scanId]);
      expect(slicer.requests, isEmpty);
      // One decision exists: a second decline is nothing at all —
      // and it carries no routing data.
      expect(await controller.declineConsent(), isFalse);
      expect(store.entries, hasLength(1));
      expect(files.unlinkedScans, [passed.scanId]);
    });

    test('accept: one consent_granted row, the token minted bound to '
        'the standing scanId, exactly one slice carrying bytes + prompt '
        '+ scanId + token — and the cache unlinked on the resolution '
        '(AD-8, FR-25, NFR4)', () async {
      final store = _RecordingStore();
      final files = _RecordingFiles();
      final slicer = _FakeSlicer();
      final (controller, passed) = await standingScan(
        store,
        files,
        slicer: slicer,
      );
      final outcome = await controller.grantConsent();
      expect(outcome, isA<ScanConsentDelivered>());
      expect(slicer.requests, hasLength(1));
      final request = slicer.requests.single;
      expect(request.imageBytes, [1, 2, 3]);
      expect(request.scanId, passed.scanId);
      expect(request.prompt, isNotEmpty);
      expect(request.consent, isA<ScanConsent>());
      // AD-8's binding, pinned on the dispatched object itself: the
      // token is minted for the standing scan — a wrong-binding
      // regression would throw scanIdMismatch inside every slice and
      // fold to a misleading providerUnreachable.
      expect(request.consent.scanId, passed.scanId);
      expect(store.entries.map((entry) => entry.kind), ['consent_granted']);
      expect(files.unlinkedScans, [passed.scanId]);
      // One decision and one token: a second accept is nothing at all.
      expect(await controller.grantConsent(), isA<ScanConsentStale>());
      expect(slicer.requests, hasLength(1));
      expect(store.entries, hasLength(1));
    });

    test('a failed dispatch surfaces the raw cause for the standing '
        'map and unlinks the cache — the 4-5 mapping consumes it '
        'unchanged', () async {
      final store = _RecordingStore();
      final files = _RecordingFiles();
      final slicer = _FakeSlicer()
        ..outcome = const SlicerFailed(SlicerFailureCause.invalidKey);
      final (controller, passed) = await standingScan(
        store,
        files,
        slicer: slicer,
      );
      final outcome = await controller.grantConsent();
      expect(outcome, isA<ScanConsentFailed>());
      expect(
        (outcome as ScanConsentFailed).cause,
        SlicerFailureCause.invalidKey,
      );
      expect(files.unlinkedScans, [passed.scanId]);
    });

    test('a close mid-dispatch mints exactly one scan_abandoned row and '
        'turns the late resolution into a stale answer: no routing data, '
        'the close already unlinked, the act\'s rows the only two '
        '(Story 5.6, AD-8 — the departure is the resolution cause; 5.2\'s '
        'epoch discipline)', () async {
      final store = _RecordingStore();
      final files = _RecordingFiles();
      final slicer = _FakeSlicer()..gate = Completer<void>();
      final (controller, passed) = await standingScan(
        store,
        files,
        slicer: slicer,
      );
      final granting = controller.grantConsent();
      await controller.close();
      expect(files.unlinkedScans, [passed.scanId]);
      slicer.gate!.complete();
      expect(await granting, isA<ScanConsentStale>());
      // The close's unlink was the only one: the stale answer unlinked
      // nothing new and recreated nothing.
      expect(files.unlinkedScans, [passed.scanId]);
      // The wait was left standing: the grant at the tap, then exactly
      // one payload-less scan_abandoned for the departure — nothing
      // more lands when the late resolution answers stale.
      expect(store.entries.map((entry) => entry.kind), [
        'consent_granted',
        'scan_abandoned',
      ]);
      final abandonment = store.entries[1];
      expect(abandonment.itemId, isNull);
      expect(abandonment.permission, isNull);
      expect(abandonment.sliceCause, isNull);
      expect(
        abandonment.instantUtcMicros,
        _fixedClock().microsecondsSinceEpoch,
      );
    });

    test('a close landing while the consent_granted append stands dispatches '
        'NOTHING — cancelled and discarded: zero slice calls (no egress, no '
        'token consumption), and the rows are exactly the act\'s and the '
        'departure\'s (the pre-dispatch epoch re-check)', () async {
      final appendBrake = Completer<void>();
      final store = _RecordingStore()..appendGate = appendBrake;
      final files = _RecordingFiles();
      final slicer = _FakeSlicer();
      final (controller, passed) = await standingScan(
        store,
        files,
        slicer: slicer,
      );
      final granting = controller.grantConsent();
      // The act's own row parks on the store's brake: the departure
      // lands mid-append, behind it on the shared queue.
      await Future<void>.delayed(Duration.zero);
      final closing = controller.close();
      appendBrake.complete();
      await closing;
      expect(await granting, isA<ScanConsentStale>());
      expect(
        slicer.requests,
        isEmpty,
        reason: 'a departure must not be followed by egress',
      );
      expect(store.entries.map((entry) => entry.kind), [
        'consent_granted',
        'scan_abandoned',
      ]);
      expect(files.unlinkedScans, [passed.scanId]);
    });

    test('a close landing during the resolution\'s tail unlink mints '
        'nothing — the flag cleared before the unlink await, the outcome '
        'still routes, the close still completes', () async {
      final store = _RecordingStore();
      final unlinkBrake = Completer<void>();
      final files = _RecordingFiles()..unlinkGate = unlinkBrake;
      final camera = _FakeCamera();
      final slicer = _FakeSlicer();
      final controller = ScanController(
        store: store,
        files: files,
        camera: camera..shotOutcome = const CameraShotCaptured([1, 2, 3]),
        gate: _FakeGate(const FaceGatePass()),
        slicer: slicer,
        readSelectedProvider: () async => 'gemini',
        idMinter: const Uuid(),
        nowOf: _fixedClock,
      );
      expect(await controller.open(), CameraOpenOutcome.granted);
      expect(await controller.shoot(), isA<ScanShootGatePassed>());
      final granting = controller.grantConsent();
      // The slice resolved; the resolution parks in its tail unlink.
      await Future<void>.delayed(Duration.zero);
      await controller.close();
      unlinkBrake.complete();
      expect(await granting, isA<ScanConsentDelivered>());
      expect(store.entries.map((entry) => entry.kind), [
        'consent_granted',
      ], reason: 'the dispatch resolved — a close after it abandons nothing');
      expect(files.unlinkedScans.toSet(), {files.writtenFrames.single.$1});
      expect(camera.disposedCalls, isNotEmpty);
    });

    test('a failed resolution that parks in its tail unlink cannot mint '
        'scan_abandoned when close lands (Story 5.6)', () async {
      final store = _RecordingStore();
      final unlinkBrake = Completer<void>();
      final files = _RecordingFiles()..unlinkGate = unlinkBrake;
      final slicer = _FakeSlicer()
        ..outcome = const SlicerFailed(SlicerFailureCause.invalidKey);
      final controller = ScanController(
        store: store,
        files: files,
        camera: _FakeCamera()
          ..shotOutcome = const CameraShotCaptured([1, 2, 3]),
        gate: _FakeGate(const FaceGatePass()),
        slicer: slicer,
        readSelectedProvider: () async => 'gemini',
        idMinter: const Uuid(),
        nowOf: _fixedClock,
      );
      expect(await controller.open(), CameraOpenOutcome.granted);
      expect(await controller.shoot(), isA<ScanShootGatePassed>());
      final granting = controller.grantConsent();
      await Future<void>.delayed(Duration.zero);
      expect(files.unlinkedScans, isNotEmpty);
      await controller.close();
      unlinkBrake.complete();
      expect(await granting, isA<ScanConsentFailed>());
      expect(store.entries.map((entry) => entry.kind), ['consent_granted']);
      // The accepted double, asserted exactly rather than masked: the
      // resolution's tail unlink recorded first, then the close's own
      // — the port's delete is idempotent, the second a quiet no-op.
      final scanId = files.writtenFrames.single.$1;
      expect(files.unlinkedScans, [scanId, scanId]);
    });

    test('a throwing resolution that parks in its tail unlink cannot mint '
        'scan_abandoned when close lands (Story 5.6)', () async {
      final store = _RecordingStore();
      final unlinkBrake = Completer<void>();
      final files = _RecordingFiles()..unlinkGate = unlinkBrake;
      final slicer = _FakeSlicer()..throwOnSlice = StateError('seam threw');
      final controller = ScanController(
        store: store,
        files: files,
        camera: _FakeCamera()
          ..shotOutcome = const CameraShotCaptured([1, 2, 3]),
        gate: _FakeGate(const FaceGatePass()),
        slicer: slicer,
        readSelectedProvider: () async => 'gemini',
        idMinter: const Uuid(),
        nowOf: _fixedClock,
      );
      expect(await controller.open(), CameraOpenOutcome.granted);
      expect(await controller.shoot(), isA<ScanShootGatePassed>());
      final granting = controller.grantConsent();
      await Future<void>.delayed(Duration.zero);
      expect(files.unlinkedScans, isNotEmpty);
      await controller.close();
      unlinkBrake.complete();
      expect(await granting, isA<ScanConsentFailed>());
      expect(store.entries.map((entry) => entry.kind), ['consent_granted']);
      // The accepted double, asserted exactly rather than masked: the
      // resolution's tail unlink recorded first, then the close's own
      // — the port's delete is idempotent, the second a quiet no-op.
      final scanId = files.writtenFrames.single.$1;
      expect(files.unlinkedScans, [scanId, scanId]);
    });

    test('a failing store on the abandonment append is absorbed quietly — '
        'close() mid-dispatch still completes, the unlink and the camera '
        'dispose still happen, nothing escapes (the row writer\'s '
        'catchError, now awaited inside close)', () async {
      final inner = _RecordingStore();
      final files = _RecordingFiles();
      final camera = _FakeCamera();
      final slicer = _FakeSlicer()..gate = Completer<void>();
      final controller = ScanController(
        store: _ThrowingAppendStore(inner),
        files: files,
        camera: camera..shotOutcome = const CameraShotCaptured([1, 2, 3]),
        gate: _FakeGate(const FaceGatePass()),
        slicer: slicer,
        readSelectedProvider: () async => 'gemini',
        idMinter: const Uuid(),
        nowOf: _fixedClock,
      );
      expect(await controller.open(), CameraOpenOutcome.granted);
      expect(await controller.shoot(), isA<ScanShootGatePassed>());
      final granting = controller.grantConsent();
      // The grant append threw (absorbed); the dispatch parks on the
      // slicer's gate — the abandonment row's own append will throw
      // the same way inside close.
      await Future<void>.delayed(Duration.zero);
      await controller.close();
      slicer.gate!.complete();
      expect(await granting, isA<ScanConsentStale>());
      expect(files.unlinkedScans, isNotEmpty);
      expect(camera.disposedCalls, isNotEmpty);
      expect(inner.entries, isEmpty, reason: 'nothing landed, nothing escaped');
    });

    test('a double close mid-wait (the lifecycle release, then the '
        'dispose) mints exactly one scan_abandoned row — the flag clears '
        'with the mint, so close stays idempotent for the row (Story '
        '5.6)', () async {
      final store = _RecordingStore();
      final files = _RecordingFiles();
      final slicer = _FakeSlicer()..gate = Completer<void>();
      final (controller, _) = await standingScan(store, files, slicer: slicer);
      final granting = controller.grantConsent();
      // Both departure paths converge on close: the backgrounded
      // lifecycle handler and the gate's own disposal.
      await controller.close();
      await controller.close();
      slicer.gate!.complete();
      expect(await granting, isA<ScanConsentStale>());
      expect(store.entries.map((entry) => entry.kind), [
        'consent_granted',
        'scan_abandoned',
      ], reason: 'the departure is one act — its row is one row');
    });

    test('a stale grant cannot clear a newer scan\'s abandonment flag '
        'after the controller is reused (Story 5.6)', () async {
      final store = _RecordingStore();
      final files = _RecordingFiles();
      final camera = _FakeCamera()
        ..shotOutcome = const CameraShotCaptured([1, 2, 3]);
      final oldGate = Completer<void>();
      final slicer = _FakeSlicer()..gate = oldGate;
      final controller = ScanController(
        store: store,
        files: files,
        camera: camera,
        gate: _FakeGate(const FaceGatePass()),
        slicer: slicer,
        readSelectedProvider: () async => 'gemini',
        idMinter: const Uuid(),
        nowOf: _fixedClock,
      );
      expect(await controller.open(), CameraOpenOutcome.granted);
      expect(await controller.shoot(), isA<ScanShootGatePassed>());
      slicer.sliceStarted = Completer<void>();
      final oldGrant = controller.grantConsent();
      await slicer.sliceStarted!.future;
      await controller.close();

      // Reuse the singleton controller for a new scan while the old
      // provider call is still unresolved.
      expect(await controller.open(), CameraOpenOutcome.granted);
      expect(await controller.shoot(), isA<ScanShootGatePassed>());
      final newGate = Completer<void>();
      slicer
        ..gate = newGate
        ..sliceStarted = Completer<void>();
      final newGrant = controller.grantConsent();
      await slicer.sliceStarted!.future;

      // The old stale landing must not clear the new wait's flag.
      oldGate.complete();
      expect(await oldGrant, isA<ScanConsentStale>());
      await controller.close();
      newGate.complete();
      expect(await newGrant, isA<ScanConsentStale>());
      expect(store.entries.map((entry) => entry.kind), [
        'consent_granted',
        'scan_abandoned',
        'consent_granted',
        'scan_abandoned',
      ]);
    });

    test('a close after the resolution mints nothing — every '
        'grantConsent exit clears the in-flight flag, so the delivered '
        'arm\'s own dispose stays rowless (Story 5.6)', () async {
      final store = _RecordingStore();
      final files = _RecordingFiles();
      final slicer = _FakeSlicer();
      final (controller, _) = await standingScan(store, files, slicer: slicer);
      expect(await controller.grantConsent(), isA<ScanConsentDelivered>());
      await controller.close();
      expect(store.entries.map((entry) => entry.kind), [
        'consent_granted',
      ], reason: 'no dispatch stands at the close — no abandonment exists');
    });

    test('a decline after the scan ended is nothing at all — no row, '
        'no second unlink (and a close before any answer mints no '
        'scan_abandoned: leaving before consent is neither declining '
        'nor abandoning, Story 5.6)', () async {
      final store = _RecordingStore();
      final files = _RecordingFiles();
      final (controller, passed) = await standingScan(store, files);
      await controller.close();
      expect(
        store.entries,
        isEmpty,
        reason: 'no dispatch stood at the close — nothing was abandoned',
      );
      expect(await controller.declineConsent(), isFalse);
      expect(store.entries, isEmpty);
      expect(files.unlinkedScans, [passed.scanId]);
    });

    test('a rapid second decision is nothing: a decline while the '
        'dispatch stands appends no second row and mints no second '
        'token — one decision taken', () async {
      final store = _RecordingStore();
      final files = _RecordingFiles();
      final slicer = _FakeSlicer()..gate = Completer<void>();
      final (controller, passed) = await standingScan(
        store,
        files,
        slicer: slicer,
      );
      final granting = controller.grantConsent();
      expect(await controller.declineConsent(), isFalse);
      expect(store.entries.map((entry) => entry.kind), ['consent_granted']);
      slicer.gate!.complete();
      expect(await granting, isA<ScanConsentDelivered>());
      expect(slicer.requests, hasLength(1));
      expect(files.unlinkedScans, [passed.scanId]);
    });

    test('a close landing mid-decision folds the decline into nothing '
        '— no row, the close\'s unlink the only one (leaving is not '
        'declining)', () async {
      final store = _RecordingStore();
      final files = _RecordingFiles();
      final (controller, passed) = await standingScan(store, files);
      final declining = controller.declineConsent();
      // The close lands while the decision stands — between the
      // once-guard and the append's commit.
      await controller.close();
      expect(await declining, isFalse);
      expect(store.entries, isEmpty);
      expect(files.unlinkedScans, [passed.scanId]);
    });

    test('a throwing slicer seam is contained: the provider-unreachable '
        'failure arm, the cache unlinked, no crash (the rescue path\'s own '
        'containment)', () async {
      final store = _RecordingStore();
      final files = _RecordingFiles();
      final slicer = _FakeSlicer()..throwOnSlice = StateError('seam threw');
      final (controller, passed) = await standingScan(
        store,
        files,
        slicer: slicer,
      );
      final outcome = await controller.grantConsent();
      expect(outcome, isA<ScanConsentFailed>());
      expect(
        (outcome as ScanConsentFailed).cause,
        SlicerFailureCause.providerUnreachable,
      );
      expect(slicer.requests, hasLength(1));
      expect(files.unlinkedScans, [passed.scanId]);
    });

    test('no slicer behind the test seam: the accept folds closed — '
        'nothing half-wired dispatches, no token minted, no row', () async {
      final store = _RecordingStore();
      final files = _RecordingFiles();
      final (controller, _) = await standingScan(store, files);
      expect(await controller.grantConsent(), isA<ScanConsentStale>());
      expect(store.entries, isEmpty);
    });
  });

  group('close — the terminal path', () {
    test('exit before shooting: the scan directory unlinks, the '
        'camera disposes, no rows — and close is idempotent, so the '
        'surface\'s every exit path may run it', () async {
      final store = _RecordingStore();
      final files = _RecordingFiles();
      final camera = _FakeCamera();
      final controller = ScanController(
        store: store,
        files: files,
        camera: camera,
        nowOf: _fixedClock,
      );
      expect(await controller.open(), CameraOpenOutcome.granted);
      await controller.close();
      await controller.close();
      // The standing scan's directory unlinked once — the segment
      // clears with it, so the second close finds no scan to unlink
      // (the port's own idempotence backstops any interleaving).
      expect(files.unlinkedScans, hasLength(1));
      expect(camera.disposedCalls, hasLength(2));
      expect(store.entries, isEmpty);
      // A shoot after close is nothing: the open no longer stands.
      expect(await controller.shoot(), isA<ScanShootClosed>());
      expect(files.writtenFrames, isEmpty);
    });
  });
}

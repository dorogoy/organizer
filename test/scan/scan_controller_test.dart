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

/// The Files fake: every write and unlink recorded, the frame's path
/// handed to the gate exactly as production hands it.
class _RecordingFiles implements FilesPort {
  final writtenFrames = <(String, List<int>)>[];
  final unlinkedScans = <String>[];
  var framePathToReturn = '/cache/scan_cache/x/frame.jpg';

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
  Future<void> unlinkScan(String scanId) async => unlinkedScans.add(scanId);
}

/// The camera fake: the outcomes the tests steer, the calls the tests
/// read, and an open gate so the staged permission moment's window is
/// holdable.
class _FakeCamera implements CameraShell {
  _FakeCamera({this.openOutcome});

  CameraOpenOutcome? openOutcome;
  List<int>? shotBytes = [1, 2, 3];
  final openedCalls = <void>[];
  final disposedCalls = <void>[];

  /// When set, [open] parks on this completer before answering — the
  /// staged ask's window.
  Completer<CameraOpenOutcome>? openGate;

  /// When set, [takePicture] parks on this completer before
  /// answering — the shot's in-flight window.
  Completer<List<int>?>? shotGate;

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
  Future<List<int>?> takePicture() async {
    final gate = shotGate;
    if (gate != null) {
      await gate.future;
    }
    return shotBytes;
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
}

/// The gate fake: pass, refusal, or a throwing detector.
class _FakeGate implements FaceGatePort {
  _FakeGate(this.outcome);

  final Object? outcome; // FaceGatePass | FaceGateRefusal | Exception
  final gatedPaths = <String>[];

  @override
  Future<FaceGateOutcome> gate(String framePath) async {
    gatedPaths.add(framePath);
    final outcome = this.outcome;
    if (outcome is FaceGateOutcome) {
      return outcome;
    }
    throw outcome!;
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
    }) async {
      final controller = ScanController(
        store: store,
        files: files,
        camera: camera,
        gate: gate,
        idMinter: const Uuid(),
        nowOf: _fixedClock,
      );
      expect(await controller.open(), CameraOpenOutcome.granted);
      return controller;
    }

    test('no face: the gate passes, the frame is written before the '
        'gate runs, the directory unlinks, nothing is appended — the '
        'quiet close (the chain continues in 5.5)', () async {
      final store = _RecordingStore();
      final files = _RecordingFiles();
      final gate = _FakeGate(const FaceGatePass());
      final controller = await openGranted(
        store,
        files,
        _FakeCamera(),
        gate: gate,
      );
      final outcome = await controller.shoot();
      expect(outcome, isA<ScanShootClosed>());
      // The frame was written and the gate read the written path.
      expect(files.writtenFrames, hasLength(1));
      expect(gate.gatedPaths, [files.framePathToReturn]);
      // The scan's directory unlinked — no frame lingers.
      expect(files.unlinkedScans, hasLength(1));
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
      final camera = _FakeCamera()..shotBytes = null;
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
      final camera = _FakeCamera()..shotGate = Completer<List<int>?>();
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
      camera.shotGate!.complete([9, 9, 9]);
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

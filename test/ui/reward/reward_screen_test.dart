// The reward surface's contract (Story 7.1, FR-17, UX-DR29/DR39/
// DR40/DR57): the I/O matrix rendered. The pair's equal-plate layout
// is pinned by measurement — same size, same height, same corner,
// `photoPairGap` apart, labels outside the frames — and the copy law
// by what the surface holds: `Antes`/`Después` and `Cerrar` alone, no
// adjective about the result, no share action. The no-Before arm is
// `Un trabajo estupendo` with no shoot prompt and no pair; the
// Cámara entry rule hides the shoot action when the log refuses it
// (absent, never greyed); a shoot that fails mid-flow degrades to the
// no-photo presentation with nothing written; closing before the shot
// writes nothing (zero side effects).
import 'dart:async';

import 'package:core/pool/pool_fact.dart';
import 'package:core/ports/files_port.dart';
import 'package:core/ports/store_port.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uuid/uuid.dart';

import 'package:organizer/plugins/camera/camera_shell.dart';
import 'package:organizer/reward/reward_controller.dart';
import 'package:organizer/strings/app_strings.dart';
import 'package:organizer/strings/app_strings_es.dart';
import 'package:organizer/ui/photo_frame.dart';
import 'package:organizer/ui/photo_shoot_screen.dart';
import 'package:organizer/ui/reward/reward_screen.dart';
import 'package:organizer/ui/theme.dart';

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

class _RecordingFiles implements FilesPort {
  final writtenBlobs = <(String, String, List<int>)>[];
  final blobsByName = <String, List<int>>{};

  @override
  Future<List<int>?> read(String scope, String name) async => blobsByName[name];

  @override
  Future<void> write(String scope, String name, List<int> bytes) async {
    writtenBlobs.add((scope, name, bytes));
    blobsByName[name] = bytes;
  }

  @override
  Future<void> delete(String scope, String name) async {}

  @override
  Future<String> writeScanFrame(String scanId, List<int> bytes) async => '';

  @override
  Future<void> unlinkScan(String scanId) async {}

  @override
  Future<String> writeScanCappedCopy(String scanId, List<int> bytes) async =>
      '';

  @override
  Future<void> sweepScanCache() async {}
}

class _FakeCamera implements CameraShell {
  _FakeCamera({this.openOutcome});

  CameraOpenOutcome? openOutcome;
  CameraShotOutcome shotOutcome = const CameraShotCaptured([1, 2, 3]);
  final openedCalls = <void>[];
  final disposedCalls = <void>[];

  static const Key previewKey = Key('reward-fake-camera-preview');

  @override
  Future<CameraOpenOutcome> open() async {
    openedCalls.add(null);
    return openOutcome ?? CameraOpenOutcome.granted;
  }

  @override
  Future<CameraShotOutcome> takePicture() async => shotOutcome;

  @override
  Widget buildPreview() => const SizedBox.expand(
    key: previewKey,
    child: ColoredBox(color: Color(0xFF000000)),
  );

  @override
  Future<void> dispose() async => disposedCalls.add(null);
}

DateTime _fixedClock() => DateTime.utc(2026, 9, 11, 10);

/// The Before row the space holds — the read's whole input.
void _seedBefore(_RecordingStore store, {String name = 'hash-a.jpg'}) {
  store.entries.add((
    id: 'before-1',
    kind: 'before_saved',
    instantUtcMicros: 1000,
    offsetSeconds: 3600,
    itemId: 'group-1',
    itemOrigin: Origin.cloud,
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
    beforeName: name,
    afterName: null,
  ));
}

/// A store whose log read parks on a gate — the pending window
/// between the push and the read's landing is testable.
class _GatedStore extends _RecordingStore {
  final gate = Completer<void>();

  @override
  Future<List<LogEntryRecord>> readLogEntries() async {
    await gate.future;
    return super.readLogEntries();
  }
}

void main() {
  final strings = AppStringsEs();
  final theme = OrganizerTheme.light();

  RewardController controllerWith(
    _RecordingStore store,
    _RecordingFiles files,
    _FakeCamera camera,
  ) => RewardController(
    store: store,
    files: files,
    camera: camera,
    idMinter: const Uuid(),
    nowOf: _fixedClock,
  );

  Future<void> pumpReward(
    WidgetTester tester,
    RewardController controller, {
    String groupId = 'group-1',
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: theme,
        localizationsDelegates: AppStrings.localizationsDelegates,
        supportedLocales: AppStrings.supportedLocales,
        home: RewardScreen(
          space: (groupId: groupId, origin: Origin.cloud),
          controller: controller,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('a Before exists: the Before plate stands with the '
      'shoot-After primary and Cerrar — never a seguir variant '
      '(FR-17, UX-DR39)', (tester) async {
    final store = _RecordingStore();
    final files = _RecordingFiles()..blobsByName['hash-a.jpg'] = [1, 2, 3];
    _seedBefore(store);
    await pumpReward(tester, controllerWith(store, files, _FakeCamera()));
    expect(find.text(strings.rewardBeforeOfferTitle), findsNothing);
    expect(find.byType(PhotoFrame), findsOneWidget);
    expect(find.text(strings.rewardLabelBefore), findsOneWidget);
    expect(find.text(strings.rewardAfterShoot), findsOneWidget);
    expect(find.text(strings.rewardClose), findsOneWidget);
    // The no-photo string renders nowhere on this arm.
    expect(find.text(strings.rewardWithoutPhoto), findsNothing);
  });

  testWidgets('the shot lands: the pair shows EQUAL plates — same size, '
      'same height, same corner, photoPairGap apart, labels outside the '
      'frames — and the save is the flow\'s own (UX-DR29/DR40, AD-21)', (
    tester,
  ) async {
    final store = _RecordingStore();
    final files = _RecordingFiles()..blobsByName['hash-a.jpg'] = [1, 2, 3];
    _seedBefore(store);
    await pumpReward(tester, controllerWith(store, files, _FakeCamera()));
    // The viewfinder mounts at the primary's tap — the shot is never
    // blind — and only its shutter fires the pipeline.
    await tester.ensureVisible(find.text(strings.rewardAfterShoot));
    await tester.pumpAndSettle();
    await tester.tap(find.text(strings.rewardAfterShoot));
    await tester.pumpAndSettle();
    expect(find.byKey(_FakeCamera.previewKey), findsOneWidget);
    await tester.tap(find.text(strings.scanShutter));
    await tester.pumpAndSettle();

    // The automatic save (FR-17, AD-21): one album_entry_added row
    // naming the group and BOTH blob names — the Before it read and
    // the content-addressed name of the shot just taken — with no
    // share action anywhere.
    final expectedAfter = '${sha256.convert([1, 2, 3]).toString()}.jpg';
    final savedRows = store.entries
        .where((entry) => entry.kind == 'album_entry_added')
        .toList();
    expect(savedRows, hasLength(1));
    final row = savedRows.single;
    expect(row.kind, 'album_entry_added');
    expect(row.itemId, 'group-1');
    expect(row.itemOrigin, Origin.cloud);
    expect(row.beforeName, 'hash-a.jpg');
    expect(row.afterName, expectedAfter);
    expect(files.writtenBlobs.single.$2, expectedAfter);

    // The equal pair, pinned by measurement.
    final plates = find.byType(PhotoFrame);
    expect(plates, findsNWidgets(2));
    final first = tester.getRect(plates.at(0));
    final second = tester.getRect(plates.at(1));
    expect(first.width, second.width, reason: 'equal size');
    expect(first.height, second.height, reason: 'equal height');
    expect(second.left - first.right, 16, reason: 'photoPairGap apart');
    expect(first.top, second.top, reason: 'equal height on the ground');
    // The labels render outside the frames, below each plate.
    expect(find.text(strings.rewardLabelBefore), findsOneWidget);
    expect(find.text(strings.rewardLabelAfter), findsOneWidget);
    final beforeLabel = tester.getRect(find.text(strings.rewardLabelBefore));
    expect(beforeLabel.top, greaterThanOrEqualTo(first.bottom));
    // No caption, no share action: Cerrar is the only control.
    expect(find.text(strings.rewardClose), findsOneWidget);
    expect(find.byType(PhotoFrame), findsNWidgets(2));
  });

  testWidgets('no Before ever: Un trabajo estupendo with no shoot prompt '
      'and no pair — no one-plate diff, no placeholder (UX-DR57)', (
    tester,
  ) async {
    final store = _RecordingStore();
    await pumpReward(
      tester,
      controllerWith(store, _RecordingFiles(), _FakeCamera()),
    );
    expect(find.text(strings.rewardWithoutPhoto), findsOneWidget);
    expect(find.byType(PhotoFrame), findsNothing);
    expect(find.text(strings.rewardAfterShoot), findsNothing);
    expect(find.text(strings.rewardClose), findsOneWidget);
  });

  testWidgets('the Cámara entry rule hides the shoot action when the log '
      'refuses it — absent never greyed, never a dead button '
      '(UX-DR24, FR-16/29)', (tester) async {
    final store = _RecordingStore();
    _seedBefore(store);
    store.entries.add((
      id: 'refusal-1',
      kind: 'permission_refused',
      instantUtcMicros: 2000,
      offsetSeconds: 3600,
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
      permission: 'camera',
      sliceCause: null,
      cluster: null,
      enabled: null,
      triageDestination: null,
      triageVolumeTag: null,
      triageBoxId: null,
      beforeName: null,
      afterName: null,
    ));
    await pumpReward(
      tester,
      controllerWith(store, _RecordingFiles(), _FakeCamera()),
    );
    expect(find.text(strings.rewardWithoutPhoto), findsOneWidget);
    expect(find.text(strings.rewardAfterShoot), findsNothing);
    expect(find.byType(PhotoFrame), findsNothing);
  });

  testWidgets('a shoot that fails mid-flow (a denied open) degrades to '
      'the no-photo presentation — nothing written, no error dead-end, '
      'no retry loop', (tester) async {
    final store = _RecordingStore();
    final files = _RecordingFiles()..blobsByName['hash-a.jpg'] = [1, 2, 3];
    _seedBefore(store);
    final camera = _FakeCamera(openOutcome: CameraOpenOutcome.denied);
    await pumpReward(tester, controllerWith(store, files, camera));
    // The Before plate is tall (3:4): the shoot action may sit below
    // the fold — scroll it into view before the tap. The viewfinder
    // mounts at the tap, its open is denied, and the whole chain —
    // viewfinder pop, reward degrade — settles in one window.
    await tester.ensureVisible(find.text(strings.rewardAfterShoot));
    await tester.pumpAndSettle();
    await tester.tap(find.text(strings.rewardAfterShoot));
    await tester.pumpAndSettle();
    expect(find.text(strings.rewardWithoutPhoto), findsOneWidget);
    expect(
      store.entries.map((e) => e.kind),
      contains('permission_refused'),
      reason: 'the denial\'s own row; the seeded Before stands beside',
    );
    expect(files.writtenBlobs, isEmpty);
    expect(camera.disposedCalls, isNotEmpty);
  });

  testWidgets('closing before the shot writes nothing — no act, no album '
      'entry, no blob for the After (zero side effects)', (tester) async {
    final store = _RecordingStore();
    final files = _RecordingFiles()..blobsByName['hash-a.jpg'] = [1, 2, 3];
    _seedBefore(store);
    final camera = _FakeCamera();
    await pumpReward(tester, controllerWith(store, files, camera));
    await tester.ensureVisible(find.text(strings.rewardClose));
    await tester.pumpAndSettle();
    await tester.tap(find.text(strings.rewardClose));
    await tester.pumpAndSettle();
    expect(store.entries, hasLength(1), reason: 'only the seeded Before');
    expect(files.writtenBlobs, isEmpty);
    expect(camera.openedCalls, isEmpty);
  });

  testWidgets('a frame whose bytes fail to load or decode renders the '
      'empty right-shape plate on surface-base — no spinner, no '
      'shimmer, no gradient (UX-DR29)', (tester) async {
    final store = _RecordingStore();
    // A Before whose blob is absent: the plate holds its shape.
    _seedBefore(store);
    await pumpReward(
      tester,
      controllerWith(store, _RecordingFiles(), _FakeCamera()),
    );
    final plate = find.byType(PhotoFrame);
    expect(plate, findsOneWidget);
    // The read returned null (absent): the empty plate, pinned through
    // the frame's own aspect — the shape holds whatever the bytes did.
    expect(tester.getSize(plate).aspectRatio, closeTo(0.75, 0.01));
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.byType(LinearProgressIndicator), findsNothing);
  });

  testWidgets('the null-controller test seam renders the no-photo '
      'presentation — nothing half-wired', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: theme,
        localizationsDelegates: AppStrings.localizationsDelegates,
        supportedLocales: AppStrings.supportedLocales,
        home: RewardScreen(space: (groupId: 'group-1', origin: Origin.cloud)),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text(strings.rewardWithoutPhoto), findsOneWidget);
    expect(find.byType(PhotoFrame), findsNothing);
  });

  testWidgets('while the read resolves the surface renders the quiet '
      'pending plate — never the no-photo text a space WITH a Before '
      'would flash (UX-DR29, the flash patch)', (tester) async {
    final store = _GatedStore();
    _seedBefore(store);
    await tester.pumpWidget(
      MaterialApp(
        theme: theme,
        localizationsDelegates: AppStrings.localizationsDelegates,
        supportedLocales: AppStrings.supportedLocales,
        home: RewardScreen(
          space: (groupId: 'group-1', origin: Origin.cloud),
          controller: controllerWith(
            store,
            _RecordingFiles()..blobsByName['hash-a.jpg'] = [1, 2, 3],
            _FakeCamera(),
          ),
        ),
      ),
    );
    // One frame with the read still in flight: the empty right-shape
    // plate stands and the no-photo arm renders nowhere — the wrong
    // arm must never flash before the facts land.
    await tester.pump();
    expect(find.text(strings.rewardWithoutPhoto), findsNothing);
    final quietPlate = find.byType(AspectRatio);
    expect(quietPlate, findsOneWidget);
    expect(tester.getSize(quietPlate).aspectRatio, closeTo(0.75, 0.01));
    expect(find.byType(CircularProgressIndicator), findsNothing);
    // The read lands: the space's own arm — the Before plate and the
    // shoot primary — replaces the quiet plate.
    store.gate.complete();
    await tester.pumpAndSettle();
    expect(find.byType(PhotoFrame), findsOneWidget);
    expect(find.text(strings.rewardAfterShoot), findsOneWidget);
  });

  testWidgets('the viewfinder mounts at the primary\'s tap and exiting '
      'it without shooting writes nothing — the reward keeps standing '
      'with its shoot primary (FR-17, the blind-shot patch)', (tester) async {
    final store = _RecordingStore();
    final files = _RecordingFiles()..blobsByName['hash-a.jpg'] = [1, 2, 3];
    _seedBefore(store);
    final camera = _FakeCamera();
    await pumpReward(tester, controllerWith(store, files, camera));
    await tester.ensureVisible(find.text(strings.rewardAfterShoot));
    await tester.pumpAndSettle();
    await tester.tap(find.text(strings.rewardAfterShoot));
    await tester.pumpAndSettle();
    // The viewfinder: preview mounted, shutter present — the photo is
    // never fired blind at the primary's tap.
    expect(find.byKey(_FakeCamera.previewKey), findsOneWidget);
    expect(find.text(strings.scanShutter), findsOneWidget);
    expect(find.byType(PhotoShootScreen), findsOneWidget);
    // The OS back: the quiet exit — nothing written, the reward
    // stands exactly as it was.
    final navigator = tester.state<NavigatorState>(
      find.byType(Navigator).first,
    );
    await navigator.maybePop();
    await tester.pumpAndSettle();
    expect(find.byKey(_FakeCamera.previewKey), findsNothing);
    expect(find.text(strings.rewardAfterShoot), findsOneWidget);
    expect(
      store.entries.where((entry) => entry.kind == 'album_entry_added'),
      isEmpty,
    );
    expect(files.writtenBlobs, isEmpty);
    expect(camera.disposedCalls, isNotEmpty);
  });
}

// The contextual gallery's contract (Story 7.3, FR-18, UX-DR51):
// the I/O matrix rendered. The gallery shows the album's live
// entries newest-first — two thumbnail `PhotoFrame`s per entry at
// `Radii.radiusThumb`, labels `Antes`/`Después` outside the frames,
// a one-tap `Borrar` per entry, one `Borrar todo`, one `Cerrar`, and
// no number of any kind. Deletion and purge invoke 7.2's controller
// verbatim and every mutation is followed by a fresh read: the log's
// truth re-renders, an empty read pops the surface (no empty state,
// no copy), a read failure leaves the quiet pending plate with
// `Cerrar` working, and a mutation failure is absorbed by the same
// fresh read — no error chrome anywhere.
import 'dart:async';

import 'package:core/catalogue/catalogue.dart';
import 'package:core/pool/pool_fact.dart';
import 'package:core/ports/files_port.dart';
import 'package:core/ports/store_port.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uuid/uuid.dart';

import 'package:organizer/album/album_controller.dart';
import 'package:organizer/dashboard/dashboard_controller.dart';
import 'package:organizer/session/log_write_queue.dart';
import 'package:organizer/strings/app_strings.dart';
import 'package:organizer/strings/app_strings_es.dart';
import 'package:organizer/ui/album/album_screen.dart';
import 'package:organizer/ui/dashboard/dashboard_screen.dart';
import 'package:organizer/ui/photo_frame.dart';
import 'package:organizer/ui/theme.dart';
import 'package:organizer/ui/tokens.dart';

class _RecordingStore implements StorePort {
  final List<LogEntryRecord> entries = [];
  bool throwOnRead = false;
  int? throwOnReadNumber;
  int readCalls = 0;
  bool throwOnAppend = false;

  @override
  Future<void> appendPoolFact(PoolFactRecord fact) async {}

  @override
  Future<void> appendLogEntry(LogEntryRecord entry) async {
    if (throwOnAppend) {
      throw StateError('append failed');
    }
    entries.add(entry);
  }

  @override
  Future<List<PoolFactRecord>> readPoolFacts() async => const [];

  @override
  Future<List<LogEntryRecord>> readLogEntries() async {
    readCalls++;
    if (throwOnRead || readCalls == throwOnReadNumber) {
      throw StateError('read failed');
    }
    return List.unmodifiable(entries);
  }
}

class _RecordingFiles implements FilesPort {
  final blobsByName = <String, List<int>>{};
  final deletedNames = <String>[];
  int sweepCalls = 0;

  @override
  Future<List<int>?> read(String scope, String name) async => blobsByName[name];

  @override
  Future<void> write(String scope, String name, List<int> bytes) async {
    blobsByName[name] = bytes;
  }

  @override
  Future<void> delete(String scope, String name) async {
    deletedNames.add(name);
    blobsByName.remove(name);
  }

  @override
  Future<String> writeScanFrame(String scanId, List<int> bytes) async => '';

  @override
  Future<void> unlinkScan(String scanId) async {}

  @override
  Future<String> writeScanCappedCopy(String scanId, List<int> bytes) async =>
      '';

  @override
  Future<void> sweepScanCache() async {}

  @override
  Future<void> sweepAlbum() async {
    sweepCalls++;
    blobsByName.clear();
  }
}

DateTime _fixedClock() => DateTime.utc(2026, 9, 12, 10);

/// A store whose chosen log read parks on a gate — a stale read can
/// be ordered to land after a newer one has already committed.
class _GatedReadStore extends _RecordingStore {
  _GatedReadStore({required this.parkReadNumber});

  /// The 1-based read number that parks until [release].
  final int parkReadNumber;
  int _reads = 0;
  Completer<void>? _gate;

  void release() => _gate?.complete();

  @override
  Future<List<LogEntryRecord>> readLogEntries() async {
    if (throwOnRead) {
      throw StateError('read failed');
    }
    final snapshot = List<LogEntryRecord>.unmodifiable(entries);
    _reads++;
    if (_reads == parkReadNumber) {
      _gate = Completer<void>();
      await _gate!.future;
    }
    return snapshot;
  }
}

/// One live album entry — the read model's whole input.
void _seedAlbumEntry(
  _RecordingStore store, {
  required String group,
  required String beforeName,
  required String afterName,
  int instantUtcMicros = 1000,
}) {
  store.entries.add((
    id: 'album-$group',
    kind: 'album_entry_added',
    instantUtcMicros: instantUtcMicros,
    offsetSeconds: 3600,
    itemId: group,
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
    beforeName: beforeName,
    afterName: afterName,
  ));
}

void main() {
  final strings = AppStringsEs();
  final theme = OrganizerTheme.light();

  AlbumController controllerWith(
    _RecordingStore store,
    _RecordingFiles files,
  ) => AlbumController(
    store: store,
    files: files,
    writeQueue: LogWriteQueue(),
    idMinter: const Uuid(),
    nowOf: _fixedClock,
  );

  /// The hand-built catalogue the dashboard's loader answers — one
  /// entry per taxonomy size, the loader's parsed output shape.
  final Catalogue catalogue = Catalogue(
    version: 1,
    entries: const [
      CatalogueEntry(
        id: 'focus-a',
        size: Size.focus,
        cadence: Cadence.daily,
        name: 'Tarea de focus-a',
      ),
      CatalogueEntry(
        id: 'man-a',
        size: Size.maintenance,
        cadence: Cadence.daily,
        name: 'Tarea de man-a',
      ),
      CatalogueEntry(
        id: 'hab-a',
        size: Size.instant,
        cadence: Cadence.daily,
        name: 'Tarea de hab-a',
      ),
    ],
  );

  DashboardController dashboardWith(
    _RecordingStore store,
    _RecordingFiles files,
  ) => DashboardController(
    store: store,
    files: files,
    loadCatalogue: () async => catalogue,
  );

  /// The gallery is never a MaterialApp's home — it is pushed over the
  /// reward, and its pop returns there. The harness mirrors that: a
  /// standing home route, the gallery pushed on top.
  Future<void> pumpAlbum(
    WidgetTester tester,
    AlbumController album, {
    DashboardController? dashboard,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: theme,
        localizationsDelegates: AppStrings.localizationsDelegates,
        supportedLocales: AppStrings.supportedLocales,
        home: const Scaffold(body: SizedBox.shrink()),
      ),
    );
    tester
        .state<NavigatorState>(find.byType(Navigator).first)
        .push(
          MaterialPageRoute(
            builder: (context) =>
                AlbumScreen(album: album, dashboard: dashboard),
          ),
        );
    await tester.pumpAndSettle();
  }

  testWidgets('a non-empty album renders newest-first pairs at the thumb '
      'radius with the labels outside — and the three quiet controls '
      '(FR-18, UX-DR7/29/40, AD-26)', (tester) async {
    final store = _RecordingStore();
    final files = _RecordingFiles()
      ..blobsByName['before-1.jpg'] = [1]
      ..blobsByName['after-1.jpg'] = [2]
      ..blobsByName['before-2.jpg'] = [3]
      ..blobsByName['after-2.jpg'] = [4];
    // Log order: group-1 older, group-2 newer — the gallery renders the
    // reverse.
    _seedAlbumEntry(
      store,
      group: 'group-1',
      beforeName: 'before-1.jpg',
      afterName: 'after-1.jpg',
      instantUtcMicros: 1000,
    );
    _seedAlbumEntry(
      store,
      group: 'group-2',
      beforeName: 'before-2.jpg',
      afterName: 'after-2.jpg',
      instantUtcMicros: 2000,
    );
    await pumpAlbum(tester, controllerWith(store, files));

    expect(find.text(strings.albumTitle), findsOneWidget);
    final frames = find.byType(PhotoFrame);
    expect(frames, findsNWidgets(4));
    // Newest first: the first frame in the tree is group-2's Before.
    expect(tester.widget<PhotoFrame>(frames.at(0)).name, 'before-2.jpg');
    // Every frame is the thumbnail's own corner — a cut edge, not a
    // small card.
    for (var i = 0; i < 4; i++) {
      expect(
        tester.widget<PhotoFrame>(frames.at(i)).radius,
        Radii.radiusThumb,
        reason: 'frame $i at the thumb radius',
      );
    }
    // The top pair, pinned by measurement: equal plates, photoPairGap
    // apart, the labels outside the frames below each.
    final first = tester.getRect(frames.at(0));
    final second = tester.getRect(frames.at(1));
    expect(first.width, second.width, reason: 'equal size');
    expect(first.height, second.height, reason: 'equal height');
    expect(
      second.left - first.right,
      Spacing.photoPairGap,
      reason: 'photoPairGap apart',
    );
    expect(find.text(strings.rewardLabelBefore), findsNWidgets(2));
    expect(find.text(strings.rewardLabelAfter), findsNWidgets(2));
    final label = tester.getRect(find.text(strings.rewardLabelBefore).at(0));
    expect(label.top, greaterThanOrEqualTo(first.bottom));
    // One delete per entry, one purge, one close — and no count of any
    // kind anywhere.
    expect(find.text(strings.albumEntryDelete), findsNWidgets(2));
    expect(find.text(strings.albumPurge), findsOneWidget);
    expect(find.text(strings.rewardClose), findsOneWidget);
  });

  testWidgets('one tap on Borrar deletes exactly that entry — the row, the '
      'unlink, and the fresh read leaving the rest intact (FR-18, AD-13)', (
    tester,
  ) async {
    final store = _RecordingStore();
    final files = _RecordingFiles()
      ..blobsByName['before-1.jpg'] = [1]
      ..blobsByName['after-1.jpg'] = [2]
      ..blobsByName['before-2.jpg'] = [3]
      ..blobsByName['after-2.jpg'] = [4];
    _seedAlbumEntry(
      store,
      group: 'group-1',
      beforeName: 'before-1.jpg',
      afterName: 'after-1.jpg',
      instantUtcMicros: 1000,
    );
    _seedAlbumEntry(
      store,
      group: 'group-2',
      beforeName: 'before-2.jpg',
      afterName: 'after-2.jpg',
      instantUtcMicros: 2000,
    );
    await pumpAlbum(tester, controllerWith(store, files));

    // The newest entry's delete — the first Borrar in the tree.
    await tester.tap(find.text(strings.albumEntryDelete).at(0));
    await tester.pumpAndSettle();

    // Exactly one album_entry_deleted row naming group-2's pair.
    final deletedRows = store.entries
        .where((entry) => entry.kind == 'album_entry_deleted')
        .toList();
    expect(deletedRows, hasLength(1));
    expect(deletedRows.single.itemId, 'group-2');
    expect(deletedRows.single.beforeName, 'before-2.jpg');
    expect(deletedRows.single.afterName, 'after-2.jpg');
    // The entry's own bytes are gone; the other entry's stand.
    expect(files.blobsByName, isNot(contains('before-2.jpg')));
    expect(files.blobsByName, isNot(contains('after-2.jpg')));
    expect(files.blobsByName, contains('before-1.jpg'));
    expect(files.blobsByName, contains('after-1.jpg'));
    // The fresh read: the older entry alone remains, on the surface.
    expect(find.byType(PhotoFrame), findsNWidgets(2));
    expect(find.text(strings.albumEntryDelete), findsOneWidget);
    expect(find.byType(AlbumScreen), findsOneWidget);
  });

  testWidgets('deleting the last entry pops the surface — no empty state, '
      'no copy (UX-DR51)', (tester) async {
    final store = _RecordingStore();
    final files = _RecordingFiles()
      ..blobsByName['before-1.jpg'] = [1]
      ..blobsByName['after-1.jpg'] = [2];
    _seedAlbumEntry(
      store,
      group: 'group-1',
      beforeName: 'before-1.jpg',
      afterName: 'after-1.jpg',
    );
    await pumpAlbum(tester, controllerWith(store, files));

    await tester.tap(find.text(strings.albumEntryDelete));
    await tester.pumpAndSettle();

    expect(
      store.entries.where((entry) => entry.kind == 'album_entry_deleted'),
      hasLength(1),
    );
    expect(find.byType(AlbumScreen), findsNothing);
  });

  testWidgets('one tap on Borrar todo purges the whole album — the sweep, '
      'the one row, and the pop (FR-18)', (tester) async {
    final store = _RecordingStore();
    final files = _RecordingFiles()
      ..blobsByName['before-1.jpg'] = [1]
      ..blobsByName['after-1.jpg'] = [2]
      ..blobsByName['before-2.jpg'] = [3]
      ..blobsByName['after-2.jpg'] = [4];
    _seedAlbumEntry(
      store,
      group: 'group-1',
      beforeName: 'before-1.jpg',
      afterName: 'after-1.jpg',
      instantUtcMicros: 1000,
    );
    _seedAlbumEntry(
      store,
      group: 'group-2',
      beforeName: 'before-2.jpg',
      afterName: 'after-2.jpg',
      instantUtcMicros: 2000,
    );
    await pumpAlbum(tester, controllerWith(store, files));

    await tester.ensureVisible(find.text(strings.albumPurge));
    await tester.pumpAndSettle();
    await tester.tap(find.text(strings.albumPurge));
    await tester.pumpAndSettle();

    expect(
      store.entries.where((entry) => entry.kind == 'album_purged'),
      hasLength(1),
    );
    expect(files.sweepCalls, 1);
    expect(files.blobsByName, isEmpty);
    expect(find.byType(AlbumScreen), findsNothing);
  });

  testWidgets('an empty read on open pops the surface — the stale '
      'affordance degrades to open-then-pop, and the null-controller test '
      'seam renders nothing half-wired', (tester) async {
    await pumpAlbum(
      tester,
      controllerWith(_RecordingStore(), _RecordingFiles()),
    );
    expect(find.byType(AlbumScreen), findsNothing);

    await tester.pumpWidget(
      MaterialApp(
        theme: theme,
        localizationsDelegates: AppStrings.localizationsDelegates,
        supportedLocales: AppStrings.supportedLocales,
        home: const Scaffold(body: SizedBox.shrink()),
      ),
    );
    tester
        .state<NavigatorState>(find.byType(Navigator).first)
        .push(MaterialPageRoute(builder: (context) => const AlbumScreen()));
    await tester.pumpAndSettle();
    expect(find.byType(AlbumScreen), findsNothing);
  });

  testWidgets('a read failure leaves the quiet pending state standing — '
      'never an empty-album reading, never a pop — and Cerrar works', (
    tester,
  ) async {
    final store = _RecordingStore()..throwOnRead = true;
    _seedAlbumEntry(
      store,
      group: 'group-1',
      beforeName: 'before-1.jpg',
      afterName: 'after-1.jpg',
    );
    await pumpAlbum(tester, controllerWith(store, _RecordingFiles()));

    // The quiet pending plate: no entries, no purge over nothing, no
    // spinner — and the surface never popped.
    expect(find.byType(AlbumScreen), findsOneWidget);
    expect(find.byType(PhotoFrame), findsNothing);
    expect(find.text(strings.albumPurge), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    final quietPlate = find.byType(AspectRatio);
    expect(quietPlate, findsOneWidget);
    expect(tester.getSize(quietPlate).aspectRatio, closeTo(0.75, 0.01));

    await tester.ensureVisible(find.text(strings.rewardClose));
    await tester.pumpAndSettle();
    await tester.tap(find.text(strings.rewardClose));
    await tester.pumpAndSettle();
    expect(find.byType(AlbumScreen), findsNothing);
  });

  testWidgets('a mutation failure is absorbed by the fresh read — the log\'s '
      'truth shows, no error chrome, no pop', (tester) async {
    final store = _RecordingStore()..throwOnAppend = true;
    final files = _RecordingFiles()
      ..blobsByName['before-1.jpg'] = [1]
      ..blobsByName['after-1.jpg'] = [2];
    _seedAlbumEntry(
      store,
      group: 'group-1',
      beforeName: 'before-1.jpg',
      afterName: 'after-1.jpg',
    );
    await pumpAlbum(tester, controllerWith(store, files));

    await tester.tap(find.text(strings.albumEntryDelete));
    await tester.pumpAndSettle();

    // The append failed, so the row never landed: the entry stands —
    // the log's truth — while its bytes already went (privacy beats
    // reversibility, 7.2's own ordering).
    expect(
      store.entries.where((entry) => entry.kind == 'album_entry_deleted'),
      isEmpty,
    );
    expect(files.blobsByName, isEmpty);
    expect(find.byType(AlbumScreen), findsOneWidget);
    expect(find.byType(PhotoFrame), findsNWidgets(2));
    expect(find.text(strings.albumEntryDelete), findsOneWidget);
  });

  testWidgets('a failed mutation refresh returns to the quiet pending state '
      'instead of retaining stale rows', (tester) async {
    final store = _RecordingStore();
    final files = _RecordingFiles()
      ..blobsByName['before-1.jpg'] = [1]
      ..blobsByName['after-1.jpg'] = [2];
    _seedAlbumEntry(
      store,
      group: 'group-1',
      beforeName: 'before-1.jpg',
      afterName: 'after-1.jpg',
    );
    await pumpAlbum(tester, controllerWith(store, files));

    // Read #1 opens the surface and #2 belongs to deleteEntry; fail the
    // fresh surface read (#3) after the mutation has completed.
    store.throwOnReadNumber = 3;
    await tester.tap(find.text(strings.albumEntryDelete));
    await tester.pumpAndSettle();

    expect(find.byType(AlbumScreen), findsOneWidget);
    expect(find.byType(PhotoFrame), findsNothing);
    expect(find.text(strings.albumPurge), findsNothing);
    expect(find.byType(AspectRatio), findsOneWidget);
  });

  testWidgets('a purge failure is absorbed by the fresh read — no landed '
      'row, the entries still stand, no error chrome, no pop (matrix: '
      'purge on throw)', (tester) async {
    final store = _RecordingStore()..throwOnAppend = true;
    final files = _RecordingFiles()
      ..blobsByName['before-1.jpg'] = [1]
      ..blobsByName['after-1.jpg'] = [2]
      ..blobsByName['before-2.jpg'] = [3]
      ..blobsByName['after-2.jpg'] = [4];
    _seedAlbumEntry(
      store,
      group: 'group-1',
      beforeName: 'before-1.jpg',
      afterName: 'after-1.jpg',
      instantUtcMicros: 1000,
    );
    _seedAlbumEntry(
      store,
      group: 'group-2',
      beforeName: 'before-2.jpg',
      afterName: 'after-2.jpg',
      instantUtcMicros: 2000,
    );
    await pumpAlbum(tester, controllerWith(store, files));

    await tester.ensureVisible(find.text(strings.albumPurge));
    await tester.pumpAndSettle();
    await tester.tap(find.text(strings.albumPurge));
    await tester.pumpAndSettle();

    // The append failed, so no album_purged row landed: both entries
    // stand — the log's truth — while the sweep already took the bytes
    // (privacy beats reversibility, 7.2's own ordering).
    expect(
      store.entries.where((entry) => entry.kind == 'album_purged'),
      isEmpty,
    );
    expect(files.sweepCalls, 1);
    expect(files.blobsByName, isEmpty);
    expect(find.byType(AlbumScreen), findsOneWidget);
    expect(find.byType(PhotoFrame), findsNWidgets(4));
  });

  testWidgets('a stale read landing after a newer one must not overwrite '
      'it — the generation guard (the reward _GatedStore pattern)', (
    tester,
  ) async {
    final store = _GatedReadStore(parkReadNumber: 3);
    final files = _RecordingFiles();
    _seedAlbumEntry(
      store,
      group: 'group-1',
      beforeName: 'before-1.jpg',
      afterName: 'after-1.jpg',
      instantUtcMicros: 1000,
    );
    _seedAlbumEntry(
      store,
      group: 'group-2',
      beforeName: 'before-2.jpg',
      afterName: 'after-2.jpg',
      instantUtcMicros: 2000,
    );
    _seedAlbumEntry(
      store,
      group: 'group-3',
      beforeName: 'before-3.jpg',
      afterName: 'after-3.jpg',
      instantUtcMicros: 3000,
    );
    await pumpAlbum(tester, controllerWith(store, files));
    expect(find.byType(PhotoFrame), findsNWidgets(6));

    // Read #3 — the first delete's refresh — parks on the gate: the
    // log now holds one delete, but nothing commits yet.
    await tester.tap(find.text(strings.albumEntryDelete).at(0));
    await tester.pump();
    // The second delete runs through the parked refresh: its own read
    // and its refresh (#4, #5) resolve, commit the FRESH answer — one
    // entry — and render it. The second entry's delete sits below
    // the fold; scroll it in first (no read can commit while the
    // gate holds, so the stale tree stands).
    await tester.ensureVisible(find.text(strings.albumEntryDelete).at(1));
    await tester.tap(find.text(strings.albumEntryDelete).at(1));
    await tester.pump();
    expect(
      store.entries.where((entry) => entry.kind == 'album_entry_deleted'),
      hasLength(2),
    );

    // Releasing the stale read (#3, generation 2): it must not paint
    // its two-entry answer over the fresh one-entry commit.
    store.release();
    await tester.pumpAndSettle();
    expect(
      find.byType(PhotoFrame),
      findsNWidgets(2),
      reason: 'the fresh read\'s single entry — never the stale two',
    );
    expect(find.byType(AlbumScreen), findsOneWidget);
    expect(find.text(strings.albumEntryDelete), findsOneWidget);
  });

  testWidgets('the gallery carries exactly one dashboard affordance '
      'while the seam stands — the app\'s only way into the cumulative '
      'impact surface — and a tap pushes the SAME controller\'s '
      'DashboardScreen (Story 7.4, FR-23, UX-DR31/32)', (tester) async {
    final store = _RecordingStore();
    final files = _RecordingFiles()
      ..blobsByName['before-1.jpg'] = [1]
      ..blobsByName['after-1.jpg'] = [2];
    _seedAlbumEntry(
      store,
      group: 'group-1',
      beforeName: 'before-1.jpg',
      afterName: 'after-1.jpg',
    );
    final dashboard = dashboardWith(store, files);
    await pumpAlbum(tester, controllerWith(store, files), dashboard: dashboard);

    // Exactly one affordance, quiet prose above the close — and
    // nothing else on the surface names the dashboard. The siting
    // pin (UX-DR31/32): the way onward renders ABOVE the close
    // action, sited with the other secondary actions — reading
    // order puts the way onward before the way out.
    expect(find.text(strings.albumOpenDashboard), findsOneWidget);
    expect(
      tester.getRect(find.text(strings.albumOpenDashboard)).top,
      lessThan(tester.getRect(find.text(strings.rewardClose)).top),
      reason: 'the dashboard affordance sits above the close',
    );
    expect(find.text(strings.dashboardTitle), findsNothing);

    await tester.ensureVisible(find.text(strings.albumOpenDashboard));
    await tester.pumpAndSettle();
    await tester.tap(find.text(strings.albumOpenDashboard));
    await tester.pumpAndSettle();

    // The push carries the SAME controller — the seam hop-through pin
    // (dropping the hand-off ships the dashboard dead with every
    // composition pin green) — and the surface renders over the same
    // substrate: the entry it highlights is the album's own.
    expect(find.byType(DashboardScreen), findsOneWidget);
    expect(
      identical(
        tester.widget<DashboardScreen>(find.byType(DashboardScreen)).dashboard,
        dashboard,
      ),
      isTrue,
    );
    expect(find.text(strings.dashboardTitle), findsOneWidget);
    expect(
      find.byType(AlbumScreen, skipOffstage: false),
      findsOneWidget,
      reason: 'the gallery stands beneath, the pop\'s destination',
    );

    // The way back lands on the gallery again.
    await tester.ensureVisible(find.text(strings.dashboardBackToAlbum));
    await tester.pumpAndSettle();
    await tester.tap(find.text(strings.dashboardBackToAlbum));
    await tester.pumpAndSettle();
    expect(find.byType(DashboardScreen), findsNothing);
    expect(find.text(strings.albumTitle), findsOneWidget);
  });

  testWidgets('the absent dashboard seam renders no affordance — never '
      'a dead button (Story 7.4, the 7-3 gating lesson)', (tester) async {
    final store = _RecordingStore();
    final files = _RecordingFiles()
      ..blobsByName['before-1.jpg'] = [1]
      ..blobsByName['after-1.jpg'] = [2];
    _seedAlbumEntry(
      store,
      group: 'group-1',
      beforeName: 'before-1.jpg',
      afterName: 'after-1.jpg',
    );
    await pumpAlbum(tester, controllerWith(store, files));

    expect(find.text(strings.albumOpenDashboard), findsNothing);
    expect(find.byType(DashboardScreen), findsNothing);
  });
}

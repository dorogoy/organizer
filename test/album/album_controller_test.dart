// The album controller's contract (Story 7.2, FR-18, AD-13): the
// I/O matrix rendered — delete of a live entry (exclusive after,
// before pinned by its own before_saved), delete of an entry whose
// after name another live entry shares, purge over a real temp-dir
// Files adapter, the honest append-failure-after-unlink arm, the
// already-dead entry's quiet idempotence, the unlink-before-append
// ordering, and the shared queue's serialization of concurrent
// operations.
import 'dart:io';

import 'package:core/derive/album.dart';
import 'package:core/pool/pool_fact.dart';
import 'package:core/ports/files_port.dart';
import 'package:core/ports/store_port.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:organizer/album/album_controller.dart';
import 'package:organizer/files/app_files.dart';
import 'package:organizer/plugins/camera/camera_shell.dart';
import 'package:organizer/reward/reward_controller.dart';
import 'package:organizer/session/log_write_queue.dart';
import 'package:uuid/uuid.dart';

LogEntryRecord _row(
  String kind, {
  String? itemId,
  String? beforeName,
  String? afterName,
  int instant = 1000,
}) => (
  id: '$kind-$instant-${itemId ?? 'row'}',
  kind: kind,
  instantUtcMicros: instant,
  offsetSeconds: 0,
  itemId: itemId,
  itemOrigin: itemId == null ? null : Origin.cloud,
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
);

/// The fake store: a seedable log, appends recorded, and a shared
/// event stream the Files wrapper joins — so cross-store ordering
/// (unlink before append) is observable in one list.
class _RecordingStore implements StorePort {
  _RecordingStore([List<LogEntryRecord> seed = const []])
    : entries = [...seed],
      events = [];

  final List<LogEntryRecord> entries;

  /// The shared event stream the Files wrapper joins — so
  /// cross-store ordering (unlink before append) is observable in
  /// one list.
  final List<String> events;
  var throwOnAppend = false;
  var throwOnRead = false;

  @override
  Future<void> appendPoolFact(PoolFactRecord fact) async {}

  @override
  Future<void> appendLogEntry(LogEntryRecord entry) async {
    if (throwOnAppend) {
      throw StateError('append failed');
    }
    events.add('append:${entry.kind}');
    entries.add(entry);
  }

  @override
  Future<List<PoolFactRecord>> readPoolFacts() async => const [];

  @override
  Future<List<LogEntryRecord>> readLogEntries() async {
    if (throwOnRead) {
      throw StateError('read failed');
    }
    events.add('read');
    return List.unmodifiable(entries);
  }
}

/// The real adapter wrapped once for observability: every unlink and
/// sweep lands on the shared event stream, the bytes stay the temp
/// dir's own.
class _ObservingFiles implements FilesPort {
  _ObservingFiles(this._inner, this.events);

  final FilesPort _inner;
  final List<String> events;

  @override
  Future<List<int>?> read(String scope, String name) =>
      _inner.read(scope, name);

  @override
  Future<void> write(String scope, String name, List<int> bytes) async {
    await _inner.write(scope, name, bytes);
    events.add('write:$scope/$name');
  }

  @override
  Future<void> delete(String scope, String name) async {
    await _inner.delete(scope, name);
    events.add('delete:$scope/$name');
  }

  @override
  Future<String> writeScanFrame(String scanId, List<int> bytes) =>
      _inner.writeScanFrame(scanId, bytes);

  @override
  Future<void> unlinkScan(String scanId) => _inner.unlinkScan(scanId);

  @override
  Future<String> writeScanCappedCopy(String scanId, List<int> bytes) =>
      _inner.writeScanCappedCopy(scanId, bytes);

  @override
  Future<void> sweepScanCache() => _inner.sweepScanCache();

  @override
  Future<void> sweepAlbum() async {
    await _inner.sweepAlbum();
    events.add('sweepAlbum');
  }
}

DateTime _fixedClock() => DateTime.utc(2026, 9, 12, 10);

/// The reward channel's camera fake — `saveAfterBlob` never opens or
/// shoots, so the facade only needs to exist (the reward screen
/// test's own shape).
class _FakeCamera implements CameraShell {
  @override
  Future<CameraOpenOutcome> open() async => CameraOpenOutcome.granted;

  @override
  Future<CameraShotOutcome> takePicture() async => const CameraShotNone();

  @override
  Widget buildPreview() => const SizedBox.shrink();

  @override
  Future<void> dispose() async {}
}

void main() {
  late Directory root;
  late AppFiles realFiles;

  setUp(() {
    root = Directory.systemTemp.createTempSync('album_controller');
    realFiles = AppFiles(rootOf: () async => root);
  });

  tearDown(() {
    root.deleteSync(recursive: true);
  });

  AlbumController controllerWith(
    _RecordingStore store, {
    LogWriteQueue? writeQueue,
    FilesPort? files,
  }) => AlbumController(
    store: store,
    files: files ?? _ObservingFiles(realFiles, store.events),
    writeQueue: writeQueue ?? LogWriteQueue(),
    idMinter: const Uuid(),
    nowOf: _fixedClock,
  );

  group('read (the read model\'s reader)', () {
    test('answers the live entries over the log\'s album acts — '
        'tombstoned and purged entries never show', () async {
      final store = _RecordingStore([
        _row('before_saved', itemId: 'g1', beforeName: 'a.jpg'),
        _row(
          'album_entry_added',
          itemId: 'g1',
          beforeName: 'a.jpg',
          afterName: 'b.jpg',
        ),
        _row(
          'album_entry_added',
          itemId: 'g2',
          beforeName: 'c.jpg',
          afterName: 'd.jpg',
        ),
        _row(
          'album_entry_deleted',
          itemId: 'g2',
          beforeName: 'c.jpg',
          afterName: 'd.jpg',
        ),
      ]);
      final entries = await controllerWith(store).read();
      expect(entries, hasLength(1));
      expect(entries.single.groupId, 'g1');
      expect(entries.single.afterName, 'b.jpg');
    });

    test('a failing read rethrows — a transient store error must not '
        'read as an empty album on a photo surface (the album has no '
        'empty state)', () async {
      final store = _RecordingStore()..throwOnRead = true;
      await expectLater(controllerWith(store).read(), throwsStateError);
    });
  });

  group('deleteEntry (the I/O matrix)', () {
    test('a live entry with an exclusive after: the act lands naming '
        'the pair and the group, the after blob dies, the before '
        'blob stays pinned by its own before_saved', () async {
      await realFiles.write(albumFilesScope, 'a.jpg', [1]);
      await realFiles.write(albumFilesScope, 'b.jpg', [2]);
      final store = _RecordingStore([
        _row('before_saved', itemId: 'g1', beforeName: 'a.jpg'),
        _row(
          'album_entry_added',
          itemId: 'g1',
          beforeName: 'a.jpg',
          afterName: 'b.jpg',
        ),
      ]);
      final controller = controllerWith(store);
      final entry = (await controller.read()).single;

      await controller.deleteEntry(entry);

      final row = store.entries.last;
      expect(row.kind, 'album_entry_deleted');
      expect(row.itemId, 'g1');
      expect(row.itemOrigin, Origin.cloud);
      expect(row.beforeName, 'a.jpg');
      expect(row.afterName, 'b.jpg');
      expect(row.instantUtcMicros, _fixedClock().microsecondsSinceEpoch);
      expect(
        await realFiles.read(albumFilesScope, 'b.jpg'),
        isNull,
        reason: 'the exclusive after blob is unlinked',
      );
      expect(await realFiles.read(albumFilesScope, 'a.jpg'), [
        1,
      ], reason: 'the before blob stays — its before_saved pins it');
      expect(await controller.read(), isEmpty);
    });

    test('a shared after name: the act lands, nothing is unlinked, '
        'the other entry and its bytes stay intact', () async {
      await realFiles.write(albumFilesScope, 'a.jpg', [1]);
      await realFiles.write(albumFilesScope, 'b.jpg', [2]);
      await realFiles.write(albumFilesScope, 'c.jpg', [3]);
      final store = _RecordingStore([
        _row('before_saved', itemId: 'g1', beforeName: 'a.jpg'),
        _row('before_saved', itemId: 'g2', beforeName: 'c.jpg'),
        _row(
          'album_entry_added',
          itemId: 'g1',
          beforeName: 'a.jpg',
          afterName: 'b.jpg',
        ),
        _row(
          'album_entry_added',
          itemId: 'g2',
          beforeName: 'c.jpg',
          afterName: 'b.jpg',
        ),
      ]);
      final controller = controllerWith(store);
      final first = (await controller.read()).first;

      await controller.deleteEntry(first);

      expect(store.entries.last.kind, 'album_entry_deleted');
      expect(await realFiles.read(albumFilesScope, 'a.jpg'), [1]);
      expect(await realFiles.read(albumFilesScope, 'b.jpg'), [
        2,
      ], reason: 'the shared after name is pinned by the live entry');
      expect(await realFiles.read(albumFilesScope, 'c.jpg'), [3]);
      expect((await controller.read()).single.groupId, 'g2');
    });

    test('bytes die first: every unlink precedes the append — '
        'privacy beats reversibility', () async {
      await realFiles.write(albumFilesScope, 'a.jpg', [1]);
      await realFiles.write(albumFilesScope, 'b.jpg', [2]);
      final store = _RecordingStore([
        _row(
          'album_entry_added',
          itemId: 'g1',
          beforeName: 'a.jpg',
          afterName: 'b.jpg',
        ),
      ]);
      final controller = controllerWith(store);
      await controller.deleteEntry((await controller.read()).single);
      final appendAt = store.events.indexOf('append:album_entry_deleted');
      final deleteAt = store.events.indexOf('delete:$albumFilesScope/b.jpg');
      expect(appendAt, greaterThan(0));
      expect(deleteAt, greaterThan(0));
      expect(
        deleteAt,
        lessThan(appendAt),
        reason: 'the bytes die before the act that promises their death',
      );
    });

    test('an append failure after the unlink rethrows — the files '
        'stay deleted, no silent success, and the retry invokes '
        'again (delete is idempotent)', () async {
      await realFiles.write(albumFilesScope, 'a.jpg', [1]);
      await realFiles.write(albumFilesScope, 'b.jpg', [2]);
      final store = _RecordingStore([
        _row('before_saved', itemId: 'g1', beforeName: 'a.jpg'),
        _row(
          'album_entry_added',
          itemId: 'g1',
          beforeName: 'a.jpg',
          afterName: 'b.jpg',
        ),
      ]);
      final controller = controllerWith(store);
      final entry = (await controller.read()).single;
      store.throwOnAppend = true;

      await expectLater(controller.deleteEntry(entry), throwsStateError);
      expect(
        store.entries.where((row) => row.kind == 'album_entry_deleted'),
        isEmpty,
        reason: 'no act asserted a deletion that did not complete',
      );
      expect(
        await realFiles.read(albumFilesScope, 'b.jpg'),
        isNull,
        reason: 'the files stay deleted — the honest failure',
      );

      // The retry: the store heals, the invocation runs again, the
      // already-absent blob is quiet and the act lands.
      store.throwOnAppend = false;
      await controller.deleteEntry(entry);
      expect(store.entries.last.kind, 'album_entry_deleted');
      expect(await realFiles.read(albumFilesScope, 'a.jpg'), [1]);
    });

    test('an already-dead entry: files already absent, the act still '
        'lands, the fold no-ops (double invocation / stale entry)', () async {
      final store = _RecordingStore([
        _row('before_saved', itemId: 'g1', beforeName: 'a.jpg'),
        _row(
          'album_entry_added',
          itemId: 'g1',
          beforeName: 'a.jpg',
          afterName: 'b.jpg',
        ),
        _row(
          'album_entry_deleted',
          itemId: 'g1',
          beforeName: 'a.jpg',
          afterName: 'b.jpg',
        ),
      ]);
      final controller = controllerWith(store);
      expect(await controller.read(), isEmpty);
      // The stale entry the surface held from before the delete.
      const AlbumEntry stale = (
        groupId: 'g1',
        origin: Origin.cloud,
        beforeName: 'a.jpg',
        afterName: 'b.jpg',
        addedUtcMicros: 1000,
      );
      await controller.deleteEntry(stale);
      expect(
        store.entries.where((row) => row.kind == 'album_entry_deleted'),
        hasLength(2),
        reason: 'the act still lands — the log is append-only',
      );
      expect(await controller.read(), isEmpty, reason: 'the fold no-ops');
    });

    test('an entry whose before name has no before_saved and no '
        'sibling: BOTH files are unlinked through the real adapter '
        'and the act lands', () async {
      await realFiles.write(albumFilesScope, 'a.jpg', [1]);
      await realFiles.write(albumFilesScope, 'b.jpg', [2]);
      final store = _RecordingStore([
        _row(
          'album_entry_added',
          itemId: 'g1',
          beforeName: 'a.jpg',
          afterName: 'b.jpg',
        ),
      ]);
      final controller = controllerWith(store);
      final entry = (await controller.read()).single;

      await controller.deleteEntry(entry);

      expect(store.entries.last.kind, 'album_entry_deleted');
      expect(await realFiles.read(albumFilesScope, 'a.jpg'), isNull);
      expect(await realFiles.read(albumFilesScope, 'b.jpg'), isNull);
      expect(await controller.read(), isEmpty);
    });

    test('a refused unlink fails the operation BEFORE any act lands — '
        'the port\'s delete is quiet, so the controller verifies with '
        'a read-back (never an act asserting a deletion that did not '
        'happen)', () async {
      await realFiles.write(albumFilesScope, 'a.jpg', [1]);
      await realFiles.write(albumFilesScope, 'b.jpg', [2]);
      final store = _RecordingStore([
        _row('before_saved', itemId: 'g1', beforeName: 'a.jpg'),
        _row(
          'album_entry_added',
          itemId: 'g1',
          beforeName: 'a.jpg',
          afterName: 'b.jpg',
        ),
      ]);
      final controller = controllerWith(store);
      final entry = (await controller.read()).single;
      final albumDir = Directory(
        '${root.path}${Platform.pathSeparator}$albumFilesScope',
      );
      // An unwritable scope directory is the refusal: the delete '
      // cannot unlink, quietly, and the read-back catches it.
      expect((await Process.run('chmod', ['a-w', albumDir.path])).exitCode, 0);
      try {
        await expectLater(
          controller.deleteEntry(entry),
          throwsA(isA<StateError>()),
        );
      } finally {
        await Process.run('chmod', ['a+w', albumDir.path]);
      }
      expect(
        store.entries.where((row) => row.kind == 'album_entry_deleted'),
        isEmpty,
        reason: 'no act asserted a deletion that did not happen',
      );
      expect(await realFiles.read(albumFilesScope, 'b.jpg'), [
        2,
      ], reason: 'the refused blob still stands — the honest state');
      // The clean retry after the refusal heals lands the act.
      await controller.deleteEntry(entry);
      expect(store.entries.last.kind, 'album_entry_deleted');
      expect(await realFiles.read(albumFilesScope, 'b.jpg'), isNull);
    });

    test('a clean unlink passes the read-back and the act lands — the '
        'verification never false-positives an absent blob', () async {
      await realFiles.write(albumFilesScope, 'b.jpg', [2]);
      final store = _RecordingStore([
        _row('before_saved', itemId: 'g1', beforeName: 'a.jpg'),
        _row(
          'album_entry_added',
          itemId: 'g1',
          beforeName: 'a.jpg',
          afterName: 'b.jpg',
        ),
      ]);
      final controller = controllerWith(store);
      final entry = (await controller.read()).single;
      // The before blob never existed on disk — only the after is '
      // unlinked, and the absent-name read-back is quietly null.
      await controller.deleteEntry(entry);
      expect(store.entries.last.kind, 'album_entry_deleted');
      expect(await realFiles.read(albumFilesScope, 'b.jpg'), isNull);
    });

    test('two concurrent deletes serialize on the shared queue — '
        'each operation reads the log inside its own closure, so the '
        'fold never sees a torn state', () async {
      await realFiles.write(albumFilesScope, 'a.jpg', [1]);
      await realFiles.write(albumFilesScope, 'b.jpg', [2]);
      final store = _RecordingStore([
        _row('before_saved', itemId: 'g1', beforeName: 'a.jpg'),
        _row(
          'album_entry_added',
          itemId: 'g1',
          beforeName: 'a.jpg',
          afterName: 'b.jpg',
        ),
      ]);
      final controller = controllerWith(store);
      final entry = (await controller.read()).single;

      final first = controller.deleteEntry(entry);
      final second = controller.deleteEntry(entry);
      await Future.wait([first, second]);

      // Strict alternation: the second operation's read happens only
      // after the first's append — interleaved closures would read
      // read-read-append-append here. (The leading read is the
      // controller's own read that fetched the entry; each closure's
      // absent-file delete is the quiet idempotence the port owes.)
      expect(store.events, [
        'read',
        'read',
        'delete:$albumFilesScope/b.jpg',
        'append:album_entry_deleted',
        'read',
        'delete:$albumFilesScope/b.jpg',
        'append:album_entry_deleted',
      ]);
      expect(
        store.entries.where((row) => row.kind == 'album_entry_deleted'),
        hasLength(2),
      );
      expect(await realFiles.read(albumFilesScope, 'b.jpg'), isNull);
      expect(await realFiles.read(albumFilesScope, 'a.jpg'), [1]);
    });
  });

  group('purge (the I/O matrix)', () {
    test('every album-scope file is swept, the scope dir survives, '
        'one album_purged act lands — and bytes outside the scope '
        'are structurally unreachable', () async {
      await realFiles.write(albumFilesScope, 'a.jpg', [1]);
      await realFiles.write(albumFilesScope, 'b.jpg', [2]);
      await realFiles.write(albumFilesScope, 'orphan.jpg', [3]);
      await realFiles.write(credentialFilesScope, 'openai', [9]);
      final store = _RecordingStore([
        _row('before_saved', itemId: 'g1', beforeName: 'a.jpg'),
        _row(
          'album_entry_added',
          itemId: 'g1',
          beforeName: 'a.jpg',
          afterName: 'b.jpg',
        ),
      ]);
      final controller = controllerWith(store);
      expect((await controller.read()), hasLength(1));

      await controller.purge();

      final row = store.entries.last;
      expect(row.kind, 'album_purged');
      expect(row.itemId, isNull);
      expect(row.beforeName, isNull);
      expect(row.afterName, isNull);
      final albumDir = Directory(
        '${root.path}${Platform.pathSeparator}$albumFilesScope',
      );
      expect(albumDir.existsSync(), isTrue, reason: 'the scope remains');
      expect(albumDir.listSync(followLinks: false), isEmpty);
      expect(await realFiles.read(credentialFilesScope, 'openai'), [9]);
      expect(await controller.read(), isEmpty);
    });

    test('the sweep precedes the act — privacy first, exactly as the '
        'delete\'s unlink does', () async {
      await realFiles.write(albumFilesScope, 'a.jpg', [1]);
      final store = _RecordingStore();
      await controllerWith(store).purge();
      expect(
        store.events.indexOf('sweepAlbum'),
        lessThan(store.events.indexOf('append:album_purged')),
      );
    });

    test('an append failure after the sweep rethrows — the bytes '
        'stay gone and the retry invokes again', () async {
      await realFiles.write(albumFilesScope, 'a.jpg', [1]);
      final store = _RecordingStore()..throwOnAppend = true;
      final controller = controllerWith(store);

      await expectLater(controller.purge(), throwsStateError);
      expect(await realFiles.read(albumFilesScope, 'a.jpg'), isNull);

      store.throwOnAppend = false;
      await controller.purge();
      expect(store.entries.last.kind, 'album_purged');
    });

    test('a refused sweep fails the operation BEFORE any act lands — '
        'every name the fresh log\'s acts reference is read back, and '
        'a surviving blob throws', () async {
      await realFiles.write(albumFilesScope, 'a.jpg', [1]);
      await realFiles.write(albumFilesScope, 'b.jpg', [2]);
      final store = _RecordingStore([
        _row('before_saved', itemId: 'g1', beforeName: 'a.jpg'),
        _row(
          'album_entry_added',
          itemId: 'g1',
          beforeName: 'a.jpg',
          afterName: 'b.jpg',
        ),
      ]);
      final controller = controllerWith(store);
      final albumDir = Directory(
        '${root.path}${Platform.pathSeparator}$albumFilesScope',
      );
      expect((await Process.run('chmod', ['a-w', albumDir.path])).exitCode, 0);
      try {
        await expectLater(controller.purge(), throwsA(isA<StateError>()));
      } finally {
        await Process.run('chmod', ['a+w', albumDir.path]);
      }
      expect(
        store.entries.where((row) => row.kind == 'album_purged'),
        isEmpty,
        reason: 'no act asserted a sweep that did not happen',
      );
      expect(await realFiles.read(albumFilesScope, 'a.jpg'), [1]);
      // The clean retry after the refusal heals lands the act and '
      // empties the scope.
      await controller.purge();
      expect(store.entries.last.kind, 'album_purged');
      expect(await realFiles.read(albumFilesScope, 'a.jpg'), isNull);
      expect(await realFiles.read(albumFilesScope, 'b.jpg'), isNull);
    });
  });

  group('the shared queue against a real second writer (the I/O '
      'matrix\'s concurrent save vs delete row)', () {
    test('a reward save and an album delete on ONE queue never '
        'interleave — the save\'s write and append complete before '
        'the delete\'s fresh log read, unlink and append begin', () async {
      await realFiles.write(albumFilesScope, 'a.jpg', [1]);
      await realFiles.write(albumFilesScope, 'b.jpg', [2]);
      final store = _RecordingStore([
        _row('before_saved', itemId: 'g1', beforeName: 'a.jpg'),
        _row(
          'album_entry_added',
          itemId: 'g1',
          beforeName: 'a.jpg',
          afterName: 'b.jpg',
        ),
      ]);
      final queue = LogWriteQueue();
      final files = _ObservingFiles(realFiles, store.events);
      final album = controllerWith(store, writeQueue: queue, files: files);
      final reward = RewardController(
        store: store,
        files: files,
        camera: _FakeCamera(),
        writeQueue: queue,
        idMinter: const Uuid(),
        nowOf: _fixedClock,
      );
      const entry = (
        groupId: 'g1',
        origin: Origin.cloud,
        beforeName: 'a.jpg',
        afterName: 'b.jpg',
        addedUtcMicros: 1000,
      );
      final afterName = albumPhotoName([7, 8, 9]);

      final saving = reward.saveAfterBlob(
        [7, 8, 9],
        space: (groupId: 'g1', origin: Origin.cloud),
        beforeName: 'a.jpg',
      );
      final deleting = album.deleteEntry(entry);
      await Future.wait([saving, deleting]);

      // Strict serialization: the save's write and append stand '
      // contiguous, and only then does the delete's fresh log read '
      // begin — without the queue, the delete's read would interleave '
      // between the save's write and its append (the torn state).
      expect(store.events, [
        'write:$albumFilesScope/$afterName',
        'append:album_entry_added',
        'read',
        'delete:$albumFilesScope/b.jpg',
        'append:album_entry_deleted',
      ]);
      expect(
        await saving,
        afterName,
        reason: 'the save answered its After name',
      );
      expect(
        store.entries.where((row) => row.kind == 'album_entry_added'),
        hasLength(2),
        reason: 'the seeded pair plus the save\'s own',
      );
      expect(
        await realFiles.read(albumFilesScope, 'b.jpg'),
        isNull,
        reason: 'the delete unlinked the seeded entry\'s after',
      );
      expect(
        await realFiles.read(albumFilesScope, afterName),
        isNotEmpty,
        reason: 'the save\'s fresh After survived the concurrent delete',
      );
    });
  });
}

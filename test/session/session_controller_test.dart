import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:core/catalogue/catalogue.dart';
import 'package:core/day/calendar.dart';
import 'package:core/log/log_entry.dart' show logEntriesOf;
import 'package:core/pool/pool_fact.dart';
import 'package:core/ports/files_port.dart';
import 'package:core/ports/store_port.dart';
import 'package:core/weave/session.dart' show anchorDayOf, walkLog;
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart'
    show AppLifecycleState, WidgetsBindingObserver;
import 'package:flutter_test/flutter_test.dart';
import 'package:organizer/catalogue/catalogue_names.g.dart';
import 'package:organizer/catalogue/loader.dart';
import 'package:organizer/session/session_controller.dart';
import 'package:organizer/strings/app_strings_es.dart';

/// The recording store: appends land in order and every read replays them
/// — the same contract the drift adapter offers over (instant, append
/// sequence), faithful here because the minted instants never decrease.
class _RecordingStore implements StorePort {
  _RecordingStore([this.facts = const []]);

  final List<LogEntryRecord> entries = [];
  final List<PoolFactRecord> facts;

  @override
  Future<void> appendPoolFact(PoolFactRecord fact) async {}

  @override
  Future<void> appendLogEntry(LogEntryRecord entry) async => entries.add(entry);

  @override
  Future<List<PoolFactRecord>> readPoolFacts() async =>
      List.unmodifiable(facts);

  @override
  Future<List<LogEntryRecord>> readLogEntries() async =>
      List.unmodifiable(entries);
}

/// A fake bundle holding the shipped asset's exact bytes, so the loader
/// runs fully offline (the loader test's own pattern).
class _FakeBundle implements AssetBundle {
  _FakeBundle(this._sources);

  final Map<String, String> _sources;

  @override
  Future<ByteData> load(String key) async {
    final bytes = utf8.encode(await loadString(key));
    return ByteData.view(bytes.buffer);
  }

  @override
  Future<ui.ImmutableBuffer> loadBuffer(String key) async {
    final bytes = utf8.encode(await loadString(key));
    return ui.ImmutableBuffer.fromUint8List(bytes);
  }

  @override
  Future<String> loadString(String key, {bool cache = true}) async =>
      _sources[key] ??
      (throw FileSystemException('asset not in fake bundle', key));

  @override
  Future<T> loadStructuredData<T>(
    String key,
    FutureOr<T> Function(String value) parser,
  ) => loadString(key).then(parser);

  @override
  Future<T> loadStructuredBinaryData<T>(
    String key,
    FutureOr<T> Function(ByteData data) parser,
  ) => load(key).then(parser);

  @override
  void evict(String key) {}

  @override
  void clear() {}
}

/// A bundle whose first read fails and whose later reads return the
/// shipped bytes — the transient-asset-read shape the memo must not
/// remember (a failed load retries on the next lifecycle event).
class _FlakyBundle implements AssetBundle {
  _FlakyBundle(this._asset);

  final String _asset;
  var reads = 0;

  Future<String> _source(String key) async {
    reads++;
    if (reads == 1) {
      throw StateError('transient read failure');
    }
    return _asset;
  }

  @override
  Future<ByteData> load(String key) async {
    final bytes = utf8.encode(await _source(key));
    return ByteData.view(bytes.buffer);
  }

  @override
  Future<ui.ImmutableBuffer> loadBuffer(String key) async {
    final bytes = utf8.encode(await _source(key));
    return ui.ImmutableBuffer.fromUint8List(bytes);
  }

  @override
  Future<String> loadString(String key, {bool cache = true}) => _source(key);

  @override
  Future<T> loadStructuredData<T>(
    String key,
    FutureOr<T> Function(String value) parser,
  ) => loadString(key).then(parser);

  @override
  Future<T> loadStructuredBinaryData<T>(
    String key,
    FutureOr<T> Function(ByteData data) parser,
  ) => load(key).then(parser);

  @override
  void evict(String key) {}

  @override
  void clear() {}
}

/// The sweep-counting Files fake: it moves no bytes — it only records
/// that the open's crash backstop fired, when, and whether it was
/// asked to throw (Story 5.4).
class _SweepCountingFiles implements FilesPort {
  _SweepCountingFiles(this.logLengthOf);

  /// Read at the moment the sweep runs, so a test can pin the sweep
  /// to the start of the open's queued step (0 rows yet).
  final int Function() logLengthOf;

  int sweeps = 0;

  /// The log length at the moment the sweep ran.
  int? sweptAtLogLength;

  bool throws = false;

  @override
  Future<List<int>?> read(String scope, String name) async => null;

  @override
  Future<void> write(String scope, String name, List<int> bytes) async {}

  @override
  Future<void> delete(String scope, String name) async {}

  @override
  Future<String> writeScanFrame(String scanId, List<int> bytes) async => '';

  @override
  Future<String> writeScanCappedCopy(String scanId, List<int> bytes) async =>
      '';

  @override
  Future<void> unlinkScan(String scanId) async {}

  @override
  Future<void> sweepScanCache() async {
    sweeps++;
    sweptAtLogLength = logLengthOf();
    if (throws) {
      throw StateError('sweep boom');
    }
  }
}

LogEntryRecord _moment(String kind, DateTime at, String id) => (
  id: id,
  kind: kind,
  instantUtcMicros: at.microsecondsSinceEpoch,
  offsetSeconds: 0,
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
  permission: null,
  sliceCause: null,
);

LogEntryRecord _act(String kind, DateTime at, String id, String itemId) => (
  id: id,
  kind: kind,
  instantUtcMicros: at.microsecondsSinceEpoch,
  offsetSeconds: 0,
  itemId: itemId,
  itemOrigin: Origin.shipped,
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
);

const chunkSeedId = 'pasar-la-aspiradora-a-la-cocina';

DateTime _fixedClock() => DateTime.utc(2026, 8, 29, 12);

void main() {
  final v7 = RegExp(
    '^[0-9a-f]{8}-[0-9a-f]{4}-7[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}\$',
  );
  final shipped = File(catalogueAssetPath).readAsStringSync();

  Future<Catalogue> shippedCatalogue() => loadEvergreenCatalogue(
    AppStringsEs(),
    bundle: _FakeBundle({catalogueAssetPath: shipped}),
  );

  SessionController buildController(
    _RecordingStore store, {
    DateTime Function() nowOf = _fixedClock,
    FilesPort? files,
  }) => SessionController(
    store: store,
    strings: AppStringsEs(),
    bundle: _FakeBundle({catalogueAssetPath: shipped}),
    nowOf: nowOf,
    files: files,
  );

  test(
    'app open appends app_opened, session_started and the session\'s first '
    'card_dealt — a chunk from the shipped catalogue (AD-3, AD-16)',
    () async {
      final store = _RecordingStore();
      await buildController(store).handleAppOpen();

      expect(store.entries.map((entry) => entry.kind).toList(), [
        'app_opened',
        'session_started',
        'card_dealt',
      ]);
      final dealt = store.entries[2];
      expect(dealt.itemOrigin, Origin.shipped);
      expect(dealt.itemId, matches(RegExp('^[a-z0-9-]+\$')));

      final catalogue = await shippedCatalogue();
      final entry = catalogue.entries.firstWhere(
        (candidate) => candidate.id == dealt.itemId,
      );
      expect(entry.size, Size.focus);
      expect(entry.cadence, isNot(Cadence.daily));

      for (final record in store.entries) {
        expect(record.id, matches(v7));
      }
      // One minted instant serves the whole batch, and app_opened leads it.
      expect(
        store.entries.map((record) => record.instantUtcMicros).toSet(),
        hasLength(1),
      );
      expect(
        store.entries.map((record) => record.offsetSeconds).toSet(),
        hasLength(1),
      );
    },
  );

  test('app open with a standing focus capture deals the capture, not '
      'a catalogue chunk', () async {
    final store = _RecordingStore([
      (
        id: 'cap-focus',
        origin: Origin.manual,
        size: Size.focus,
        instantUtcMicros:
            _fixedClock().microsecondsSinceEpoch - 60 * 1000 * 1000,
        offsetSeconds: 0,
        originContext: 'Llamar al dentista',
        dictated: null,
        rescueOf: null,
        estimateSeconds: null,
        stepText: null,
      ),
    ]);
    await buildController(store).handleAppOpen();

    expect(store.entries.map((entry) => entry.kind).toList(), [
      'app_opened',
      'session_started',
      'card_dealt',
    ]);
    final dealt = store.entries[2];
    expect(dealt.itemId, 'cap-focus');
    expect(dealt.itemOrigin, Origin.manual);
  });

  test('opening again with no backgrounding in between appends only '
      'app_opened — no second session_started, no second card_dealt', () async {
    final store = _RecordingStore();
    final controller = buildController(store);
    await controller.handleAppOpen();
    await controller.handleAppOpen();

    expect(store.entries.map((entry) => entry.kind).toList(), [
      'app_opened',
      'session_started',
      'card_dealt',
      'app_opened',
    ]);
  });

  test('the open→background→reopen cycle appends the exact lifecycle kinds, '
      'and the reopen resolves a different chunk identity', () async {
    final store = _RecordingStore();
    var minute = 0;
    final controller = buildController(
      store,
      nowOf: () => DateTime.utc(2026, 8, 29, 12, minute++),
    );
    await controller.handleAppOpen();
    await controller.handleSessionEnd();
    await controller.handleAppOpen();

    expect(store.entries.map((entry) => entry.kind).toList(), [
      'app_opened',
      'session_started',
      'card_dealt',
      'session_ended',
      'app_opened',
      'session_started',
      'card_dealt',
    ]);
    final firstChunk = store.entries[2].itemId;
    final secondChunk = store.entries[6].itemId;
    expect(
      secondChunk,
      isNot(firstChunk),
      reason:
          'identity re-resolves on each deal — the first chunk was dealt, '
          'so the reopen deals the next least-recently-dealt candidate',
    );
  });

  test(
    'lifecycle events route through the observer: backgrounding ends the '
    'session, resuming opens a new one, a transient occlusion does nothing',
    () async {
      final store = _RecordingStore();
      // A ticking clock: backgrounding and resuming mint distinct
      // instants, as production always does — under a frozen clock the
      // two would collapse onto one instant and read as a supersede
      // pair, which no real background→resume can produce.
      var minute = 0;
      final controller = buildController(
        store,
        nowOf: () => DateTime.utc(2026, 8, 29, 12, minute++),
      );
      await controller.handleAppOpen();

      controller.didChangeAppLifecycleState(AppLifecycleState.inactive);
      await Future<void>.delayed(Duration.zero);
      expect(store.entries, hasLength(3));

      controller.didChangeAppLifecycleState(AppLifecycleState.hidden);
      await Future<void>.delayed(Duration.zero);
      expect(store.entries[3].kind, 'session_ended');

      controller.didChangeAppLifecycleState(AppLifecycleState.resumed);
      await Future<void>.delayed(Duration.zero);
      expect(store.entries.map((entry) => entry.kind).toList(), [
        'app_opened',
        'session_started',
        'card_dealt',
        'session_ended',
        'app_opened',
        'session_started',
        'card_dealt',
      ]);
    },
  );

  test('a day whose slot a card_done-on-chunk already closed deals no second '
      'chunk — upkeep or habits open the new session', () async {
    final store = _RecordingStore()
      ..entries.addAll([
        _moment('session_started', DateTime.utc(2026, 8, 29, 11), 'seed-1'),
        _act(
          'card_dealt',
          DateTime.utc(2026, 8, 29, 11, 1),
          'seed-2',
          chunkSeedId,
        ),
        _act(
          'card_done',
          DateTime.utc(2026, 8, 29, 11, 2),
          'seed-3',
          chunkSeedId,
        ),
        _moment('session_ended', DateTime.utc(2026, 8, 29, 11, 3), 'seed-4'),
      ]);
    await buildController(store).handleAppOpen();

    expect(store.entries.map((entry) => entry.kind).toList(), [
      'session_started',
      'card_dealt',
      'card_done',
      'session_ended',
      'app_opened',
      'session_started',
      'card_dealt',
    ]);
    final reopenedDeal = store.entries[6];
    final catalogue = await shippedCatalogue();
    final dealt = catalogue.entries.firstWhere(
      (candidate) => candidate.id == reopenedDeal.itemId,
    );
    expect(
      dealt.size,
      isNot(Size.focus),
      reason:
          'the slot closes once per domestic day and only a card_done '
          'reopens nothing — the new session deals upkeep or habits',
    );
  });

  test('a rapid background→resume serializes: exactly one session_ended and '
      'no duplicate session_started or card_dealt', () async {
    final store = _RecordingStore();
    var minute = 0;
    final controller = buildController(
      store,
      nowOf: () => DateTime.utc(2026, 8, 29, 12, minute++),
    );
    unawaited(controller.handleAppOpen());
    controller.didChangeAppLifecycleState(AppLifecycleState.paused);
    controller.didChangeAppLifecycleState(AppLifecycleState.resumed);
    await Future<void>.delayed(Duration.zero);

    expect(
      store.entries.map((entry) => entry.kind).toList(),
      [
        'app_opened',
        'session_started',
        'card_dealt',
        'session_ended',
        'app_opened',
        'session_started',
        'card_dealt',
      ],
      reason:
          'each event\'s read→compute→append completes before the next '
          'begins, so no handler observes the pre-session state twice',
    );
  });

  test('a spurious launch-time resumed appends nothing — the launch open is '
      'the explicit call\'s alone', () async {
    final store = _RecordingStore();
    // Ticking clock, as above: distinct lifecycle events mint distinct
    // instants.
    var minute = 0;
    final controller = buildController(
      store,
      nowOf: () => DateTime.utc(2026, 8, 29, 12, minute++),
    );
    await controller.handleAppOpen();

    controller.didChangeAppLifecycleState(AppLifecycleState.resumed);
    await Future<void>.delayed(Duration.zero);
    expect(store.entries, hasLength(3));

    // After a real departure, the same resumed re-opens.
    controller.didChangeAppLifecycleState(AppLifecycleState.hidden);
    await Future<void>.delayed(Duration.zero);
    controller.didChangeAppLifecycleState(AppLifecycleState.resumed);
    await Future<void>.delayed(Duration.zero);
    expect(store.entries.map((entry) => entry.kind).toList(), [
      'app_opened',
      'session_started',
      'card_dealt',
      'session_ended',
      'app_opened',
      'session_started',
      'card_dealt',
    ]);
  });

  test('a failed catalogue load is not memoized — the next lifecycle event '
      'retries and records', () async {
    final store = _RecordingStore();
    final controller = SessionController(
      store: store,
      strings: AppStringsEs(),
      bundle: _FlakyBundle(shipped),
      nowOf: _fixedClock,
    );
    await expectLater(controller.handleAppOpen(), throwsA(isA<Exception>()));
    expect(store.entries, isEmpty);
    await controller.handleAppOpen();
    expect(store.entries.map((entry) => entry.kind).toList(), [
      'app_opened',
      'session_started',
      'card_dealt',
    ]);
  });

  test('installSessionController registers the observer and performs the '
      'launch open (the crash guard\'s testability pattern)', () async {
    final store = _RecordingStore();
    final observers = <WidgetsBindingObserver>[];
    installSessionController(
      store: store,
      strings: AppStringsEs(),
      bundle: _FakeBundle({catalogueAssetPath: shipped}),
      nowOf: _fixedClock,
      addObserver: observers.add,
    );
    await Future<void>.delayed(Duration.zero);

    expect(observers, hasLength(1));
    expect(store.entries.map((entry) => entry.kind).toList(), [
      'app_opened',
      'session_started',
      'card_dealt',
    ]);

    // The registered observer is the live controller: backgrounding
    // through it ends the session.
    (observers.single as SessionController).didChangeAppLifecycleState(
      AppLifecycleState.paused,
    );
    await Future<void>.delayed(Duration.zero);
    expect(store.entries.last.kind, 'session_ended');
  });

  test(
    'day attribution follows the minted offset — a 03:40 open charges to '
    'the previous domestic day, whatever offset is in force (AD-4)',
    () async {
      // A wall clock of 03:40 local, in the runner's own zone: the
      // minted offset is whatever is in force (a DateTime cannot carry
      // an artificial one), and the AD-4 property must hold through it
      // — the stored instant + stored offset reconstruct the 03:40 wall
      // time, so the session belongs to the previous domestic day in
      // every zone, nonzero or zero. The literal +02:00 attribution is
      // pinned in the core session suite, where entries carry their own
      // offsets.
      final localEarlyMorning = DateTime(2026, 8, 29, 3, 40);
      final store = _RecordingStore();
      final controller = SessionController(
        store: store,
        strings: AppStringsEs(),
        bundle: _FakeBundle({catalogueAssetPath: shipped}),
        nowOf: () => localEarlyMorning,
      );
      await controller.handleAppOpen();

      final opened = store.entries[1];
      expect(opened.kind, 'session_started');
      expect(
        opened.offsetSeconds,
        localEarlyMorning.timeZoneOffset.inSeconds,
        reason: 'the offset in force travels with every minted record',
      );
      expect(
        const Calendar()
            .dayOf(opened.instantUtcMicros, opened.offsetSeconds)
            .label,
        '2026-08-28',
        reason: '03:40 local belongs to the previous domestic day',
      );

      final catalogue = await shippedCatalogue();
      final facts = walkLog(logEntriesOf(store.entries), catalogue: catalogue);
      expect(
        anchorDayOf(facts, opened.instantUtcMicros, opened.offsetSeconds).label,
        '2026-08-28',
        reason:
            'the replayed log anchors the open session to its own stored '
            'offset\'s day, never the device\'s current zone',
      );
    },
  );

  test('an elapsed pocket left open by process death reveals closed at '
      'the next open — [app_opened, session_ended, session_started, '
      'card_dealt?], close first (Story 2.2, AD-19)', () async {
    // A pocketed session started at 11:00 with a 15-minute pocket and a
    // dealt card, left derived-open by a hard death: at the fixed
    // 12:00 clock the pocket is long past.
    final start = DateTime.utc(2026, 8, 29, 11);
    final store = _RecordingStore()
      ..entries.addAll([
        (
          id: 'seed-open',
          kind: 'session_started',
          instantUtcMicros: start.microsecondsSinceEpoch,
          offsetSeconds: 0,
          itemId: null,
          itemOrigin: null,
          stack: null,
          settingKey: null,
          settingValue: null,
          settingTextValue: null,
          pocketMinutes: 15,
          energyLevel: null,
          reportValue: null,
          reportWeek: null,
          permission: null,
          sliceCause: null,
        ),
        _act(
          'card_dealt',
          DateTime.utc(2026, 8, 29, 11, 0, 1),
          'seed-deal',
          chunkSeedId,
        ),
      ]);
    await buildController(store).handleAppOpen();

    expect(store.entries.skip(2).map((entry) => entry.kind).toList(), [
      'app_opened',
      'session_ended',
      'session_started',
    ], reason: 'the carried card suppresses the bundled deal');
    // The reveal rows share one minted instant, and the fresh session
    // is unbounded.
    final ended = store.entries[3];
    final started = store.entries[4];
    expect(ended.kind, 'session_ended');
    expect(started.kind, 'session_started');
    expect(started.pocketMinutes, isNull);
    expect(
      ended.instantUtcMicros == started.instantUtcMicros,
      isTrue,
      reason:
          'the reveal pair lands at one instant — the walk\'s '
          'carried-card rule reads exactly that adjacency',
    );
  });

  test('a pocket still within its span, and an unbounded session, open '
      'with app_opened alone — the reveal fires on elapse only (Story '
      '2.2)', () async {
    // A genuine in-range pocket, still inside its wall-clock span at
    // the fixed 12:00 clock: opened 11:30 with 45 minutes, the span
    // closes at 12:15, so thirty of its minutes have passed and the
    // reveal provably does not fire early.
    final within = _RecordingStore()
      ..entries.addAll([
        (
          id: 'seed-open',
          kind: 'session_started',
          instantUtcMicros: DateTime.utc(
            2026,
            8,
            29,
            11,
            30,
          ).microsecondsSinceEpoch,
          offsetSeconds: 0,
          itemId: null,
          itemOrigin: null,
          stack: null,
          settingKey: null,
          settingValue: null,
          settingTextValue: null,
          pocketMinutes: 45,
          energyLevel: null,
          reportValue: null,
          reportWeek: null,
          permission: null,
          sliceCause: null,
        ),
      ]);
    await buildController(within).handleAppOpen();
    // The pocket is real and in range; the open still appends only its
    // own fact — the reveal fires on elapse, never on presence.
    final seededPocket = within.entries.first;
    expect(seededPocket.pocketMinutes, 45);
    expect(within.entries.skip(1).map((entry) => entry.kind).toList(), [
      'app_opened',
    ]);

    final unbounded = _RecordingStore()
      ..entries.addAll([
        _moment('session_started', DateTime.utc(2026, 8, 28, 9), 'seed-old'),
      ]);
    await buildController(unbounded).handleAppOpen();
    expect(unbounded.entries.skip(1).map((entry) => entry.kind).toList(), [
      'app_opened',
    ], reason: 'a day-old unbounded session stays open — no span exists');
  });

  group('the scan-cache sweep at the open (Story 5.4, AC5, NFR14)', () {
    test('the launch open sweeps exactly once, at the start of the '
        'queued step — before the open\'s rows land', () async {
      final store = _RecordingStore();
      final files = _SweepCountingFiles(() => store.entries.length);
      await buildController(store, files: files).handleAppOpen();

      expect(files.sweeps, 1);
      expect(
        files.sweptAtLogLength,
        0,
        reason: 'the sweep runs before app_opened and the batch append',
      );
      expect(store.entries.map((entry) => entry.kind).toList(), [
        'app_opened',
        'session_started',
        'card_dealt',
      ], reason: 'the open itself is unchanged by the backstop');
    });

    test('each resume sweeps again — one sweep per app_opened, never '
        'more', () async {
      final store = _RecordingStore();
      final files = _SweepCountingFiles(() => store.entries.length);
      final controller = buildController(store, files: files);
      await controller.handleAppOpen();
      await controller.handleAppOpen();
      expect(files.sweeps, 2);
    });

    test('background and end never sweep — the trigger is the open '
        'alone', () async {
      final store = _RecordingStore();
      final files = _SweepCountingFiles(() => store.entries.length);
      final controller = buildController(store, files: files);
      await controller.handleAppOpen();
      expect(files.sweeps, 1);
      await controller.handleSessionEnd();
      expect(
        files.sweeps,
        1,
        reason: 'session_ended mints its row and sweeps nothing',
      );
      expect(store.entries.map((entry) => entry.kind).toList(), [
        'app_opened',
        'session_started',
        'card_dealt',
        'session_ended',
      ]);
    });

    test('a null seam is no sweep — everything else unchanged (the '
        'optional-seam convention)', () async {
      final store = _RecordingStore();
      await buildController(store).handleAppOpen();
      expect(store.entries.map((entry) => entry.kind).toList(), [
        'app_opened',
        'session_started',
        'card_dealt',
      ]);
    });

    test('a throwing sweep never breaks the open — the backstop folds '
        'into nothing', () async {
      final store = _RecordingStore();
      final files = _SweepCountingFiles(() => store.entries.length)
        ..throws = true;
      await buildController(store, files: files).handleAppOpen();
      expect(files.sweeps, 1, reason: 'the sweep ran');
      expect(store.entries.map((entry) => entry.kind).toList(), [
        'app_opened',
        'session_started',
        'card_dealt',
      ], reason: 'the queued step completed after the quiet fold');
    });

    test('the installer threads the seam: the unawaited launch open '
        'sweeps through the standing adapter', () async {
      final store = _RecordingStore();
      final files = _SweepCountingFiles(() => store.entries.length);
      installSessionController(
        store: store,
        strings: AppStringsEs(),
        bundle: _FakeBundle({catalogueAssetPath: shipped}),
        nowOf: _fixedClock,
        files: files,
        addObserver: (_) {},
      );
      await Future<void>.delayed(Duration.zero);
      expect(files.sweeps, 1);
      expect(store.entries.map((entry) => entry.kind).toList(), [
        'app_opened',
        'session_started',
        'card_dealt',
      ]);
    });

    test('a real pause→resume through the observer appends app_opened '
        'and sweeps exactly once — the resume\'s own sweep (Story '
        '5.4, AC5)', () async {
      final store = _RecordingStore();
      final files = _SweepCountingFiles(() => store.entries.length);
      // A ticking clock: distinct lifecycle events mint distinct
      // instants, as production always does.
      var minute = 0;
      final controller = buildController(
        store,
        files: files,
        nowOf: () => DateTime.utc(2026, 8, 29, 12, minute++),
      );
      await controller.handleAppOpen();
      expect(files.sweeps, 1, reason: 'the launch open swept');

      controller.didChangeAppLifecycleState(AppLifecycleState.paused);
      await Future<void>.delayed(Duration.zero);
      expect(
        files.sweeps,
        1,
        reason: 'the departure ends the session and sweeps nothing',
      );

      controller.didChangeAppLifecycleState(AppLifecycleState.resumed);
      await Future<void>.delayed(Duration.zero);
      expect(
        files.sweeps,
        2,
        reason: 'the real return is one app_opened — exactly one sweep',
      );
      expect(store.entries.map((entry) => entry.kind).toList(), [
        'app_opened',
        'session_started',
        'card_dealt',
        'session_ended',
        'app_opened',
        'session_started',
        'card_dealt',
      ]);
    });

    test('a spurious launch-time resumed through the observer sweeps '
        'nothing — no departure seen, the gating flag false (Story '
        '5.4)', () async {
      final store = _RecordingStore();
      final files = _SweepCountingFiles(() => store.entries.length);
      var minute = 0;
      final controller = buildController(
        store,
        files: files,
        nowOf: () => DateTime.utc(2026, 8, 29, 12, minute++),
      );
      await controller.handleAppOpen();
      expect(files.sweeps, 1);
      expect(store.entries, hasLength(3));

      controller.didChangeAppLifecycleState(AppLifecycleState.resumed);
      await Future<void>.delayed(Duration.zero);
      expect(
        files.sweeps,
        1,
        reason: 'no departure since the open — no re-open, no sweep',
      );
      expect(
        store.entries,
        hasLength(3),
        reason: 'the spurious resumed appends nothing, as before',
      );
    });

    test('a transient inactive→resumed occlusion opens without sweeping '
        'the scan cache', () async {
      final store = _RecordingStore();
      final files = _SweepCountingFiles(() => store.entries.length);
      final controller = buildController(store, files: files);
      await controller.handleAppOpen();

      controller.didChangeAppLifecycleState(AppLifecycleState.inactive);
      await Future<void>.delayed(Duration.zero);
      controller.didChangeAppLifecycleState(AppLifecycleState.resumed);
      await Future<void>.delayed(Duration.zero);

      expect(files.sweeps, 1, reason: 'the launch sweep is the only one');
      expect(store.entries.map((entry) => entry.kind).toList(), [
        'app_opened',
        'session_started',
        'card_dealt',
        'app_opened',
      ]);
    });
  });
}

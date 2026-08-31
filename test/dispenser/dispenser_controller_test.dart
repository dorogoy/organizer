// The Dispenser write path's contract (Stories 1.9–1.10): `complete(dealt)`
// appends the `card_done` row and the bundled next `card_dealt` — one
// minted instant for the batch, a v7 id per row, the bag derived once
// per operation and threaded in; the day's last completion appends the
// answer row alone; a rapid second `complete` reads the post-answer log
// and the core guard appends nothing; a failing append rethrows while
// the serialization chain recovers — the I/O matrix's write rows,
// pinned against the shipped catalogue bytes. Story 1.10 pins the same
// contract for `skip(dealt)`: `card_skipped` + the bundled deal, the
// exhausted-day single row, the double-tap and skip-racing-`Hecho`
// guards, failure propagation and the mint-at-entry stamp.
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:core/catalogue/catalogue.dart';
import 'package:core/derive/checkpoint.dart';
import 'package:core/energy/energy.dart';
import 'package:core/log/log_entry.dart';
import 'package:core/pool/pool_fact.dart';
import 'package:core/ports/store_port.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:organizer/catalogue/catalogue_names.g.dart';
import 'package:organizer/catalogue/loader.dart';
import 'package:organizer/dispenser/dispenser_controller.dart';
import 'package:organizer/session/session_controller.dart';
import 'package:organizer/session/log_write_queue.dart';
import 'package:organizer/strings/app_strings_es.dart';

/// The recording store (the session suite's own contract): appends land
/// in order and every read replays them.
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

/// A store whose first `card_done` append throws — the write-failure
/// row: the controller rethrows to the caller, the chain recovers for
/// the next completion, and the log stays consistent (nothing landed).
class _FailFirstDoneStore implements StorePort {
  _FailFirstDoneStore(this._inner);

  final _RecordingStore _inner;
  var _thrown = false;

  @override
  Future<void> appendPoolFact(PoolFactRecord fact) async {}

  @override
  Future<void> appendLogEntry(LogEntryRecord entry) async {
    if (!_thrown && entry.kind == 'card_done') {
      _thrown = true;
      throw StateError('append failed');
    }
    await _inner.appendLogEntry(entry);
  }

  @override
  Future<List<PoolFactRecord>> readPoolFacts() async => const [];

  @override
  Future<List<LogEntryRecord>> readLogEntries() async =>
      _inner.readLogEntries();
}

/// A store whose first `card_skipped` append throws — the skip's
/// write-failure row: the controller rethrows to the caller, the chain
/// recovers for the next answer, and the log stays consistent (nothing
/// landed).
class _FailFirstSkippedStore implements StorePort {
  _FailFirstSkippedStore(this._inner);

  final _RecordingStore _inner;
  var _thrown = false;

  @override
  Future<void> appendPoolFact(PoolFactRecord fact) async {}

  @override
  Future<void> appendLogEntry(LogEntryRecord entry) async {
    if (!_thrown && entry.kind == 'card_skipped') {
      _thrown = true;
      throw StateError('append failed');
    }
    await _inner.appendLogEntry(entry);
  }

  @override
  Future<List<PoolFactRecord>> readPoolFacts() async => const [];

  @override
  Future<List<LogEntryRecord>> readLogEntries() async =>
      _inner.readLogEntries();
}

/// A store whose next append after [arm] throws once — the declare's
/// write-failure row: failing the batch's FIRST row (the supersede
/// pair's `session_ended`) pins that no half-supersede can exist, since
/// nothing behind a failed first row ever lands.
class _FailNextAppendStore implements StorePort {
  _FailNextAppendStore(this._inner);

  final _RecordingStore _inner;
  var failNextAppend = false;

  @override
  Future<void> appendPoolFact(PoolFactRecord fact) async {}

  @override
  Future<void> appendLogEntry(LogEntryRecord entry) async {
    if (failNextAppend) {
      failNextAppend = false;
      throw StateError('append failed');
    }
    await _inner.appendLogEntry(entry);
  }

  @override
  Future<List<PoolFactRecord>> readPoolFacts() async => const [];

  @override
  Future<List<LogEntryRecord>> readLogEntries() async =>
      _inner.readLogEntries();
}

/// A store whose bundled `card_dealt` appends park behind a gate once a
/// given answer kind has landed — an answer batch (a completion by
/// default, a skip via [answerKind]) held half-written — answer row
/// landed, deal row not — so the settled-chain await is observable.
/// Reads delegate to the inner recording store.
class _GatedBundledDealStore implements StorePort {
  _GatedBundledDealStore(
    this._inner,
    this._gate, {
    this.answerKind = 'card_done',
  });

  final _RecordingStore _inner;
  final Future<void> _gate;

  /// The answer kind that arms the gate: a completion by default, a
  /// skip for Story 1.10's in-flight rows.
  final String answerKind;
  var _seenAnswer = false;

  @override
  Future<void> appendPoolFact(PoolFactRecord fact) async {}

  @override
  Future<void> appendLogEntry(LogEntryRecord entry) async {
    if (entry.kind == answerKind) {
      _seenAnswer = true;
    }
    if (_seenAnswer && entry.kind == 'card_dealt') {
      // The bundled next deal parks behind the gate: the batch is
      // half-written — answer row landed, deal row not — until it fires.
      await _gate;
    }
    await _inner.appendLogEntry(entry);
  }

  @override
  Future<List<PoolFactRecord>> readPoolFacts() async => const [];

  @override
  Future<List<LogEntryRecord>> readLogEntries() async =>
      _inner.readLogEntries();
}

/// A store whose log reads tick the advancing clock once more before
/// resolving — code that minted its batch instant only after the reads
/// would stamp a later tick than the entry mint (the session suite's
/// advancing-clock pattern, moved onto the store read).
class _TickingReadStore implements StorePort {
  _TickingReadStore(this._inner, this.tick);

  final _RecordingStore _inner;
  final void Function() tick;

  @override
  Future<void> appendPoolFact(PoolFactRecord fact) async {}

  @override
  Future<void> appendLogEntry(LogEntryRecord entry) async =>
      _inner.appendLogEntry(entry);

  @override
  Future<List<PoolFactRecord>> readPoolFacts() async => const [];

  @override
  Future<List<LogEntryRecord>> readLogEntries() async {
    tick();
    return _inner.readLogEntries();
  }
}

/// A fake bundle holding the shipped asset's exact bytes, so the loader
/// runs fully offline (the session suite's pattern).
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

DateTime _fixedClock() => DateTime.utc(2026, 8, 29, 12);

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
  pocketMinutes: null,
  energyLevel: null,
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
  pocketMinutes: null,
  energyLevel: null,
);

const chunkSeedId = 'pasar-la-aspiradora-a-la-cocina';

void main() {
  final v7 = RegExp(
    '^[0-9a-f]{8}-[0-9a-f]{4}-7[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}\$',
  );
  final shipped = File(catalogueAssetPath).readAsStringSync();

  Future<Catalogue> shippedCatalogue() => loadEvergreenCatalogue(
    AppStringsEs(),
    bundle: _FakeBundle({catalogueAssetPath: shipped}),
  );

  Future<DispenserDealt> openSessionAndReadFirstDeal(StorePort store) async {
    await SessionController(
      store: store,
      strings: AppStringsEs(),
      bundle: _FakeBundle({catalogueAssetPath: shipped}),
      nowOf: _fixedClock,
    ).handleAppOpen();
    final controller = DispenserController(
      store: store,
      strings: AppStringsEs(),
      bundle: _FakeBundle({catalogueAssetPath: shipped}),
      nowOf: _fixedClock,
    );
    return (await controller.read()) as DispenserDealt;
  }

  test('complete appends card_done and the bundled next card_dealt — one '
      'minted instant, a v7 id per row, the dealt item answered', () async {
    final store = _RecordingStore();
    final dealt = await openSessionAndReadFirstDeal(store);
    final controller = DispenserController(
      store: store,
      strings: AppStringsEs(),
      bundle: _FakeBundle({catalogueAssetPath: shipped}),
      nowOf: _fixedClock,
    );
    await controller.complete(dealt);

    expect(store.entries.map((entry) => entry.kind).toList(), [
      'app_opened',
      'session_started',
      'card_dealt',
      'card_done',
      'card_dealt',
    ]);
    final answer = store.entries[3];
    final nextDeal = store.entries[4];
    expect(answer.itemId, dealt.card.id);
    expect(answer.itemOrigin, dealt.card.origin);
    expect(nextDeal.itemId, isNot(dealt.card.id));
    // One minted instant (and offset) serves the whole answer batch.
    expect(answer.instantUtcMicros, nextDeal.instantUtcMicros);
    expect(answer.offsetSeconds, nextDeal.offsetSeconds);
    // A distinct v7 id per row.
    expect(answer.id, matches(v7));
    expect(nextDeal.id, matches(v7));
    expect(answer.id, isNot(nextDeal.id));
  });

  test(
    'a Hecho on the chunk closes the day\'s slot before the bundled '
    'next deal resolves — the next card is no second chunk (AD-20)',
    () async {
      final store = _RecordingStore();
      final dealt = await openSessionAndReadFirstDeal(store);
      final controller = DispenserController(
        store: store,
        strings: AppStringsEs(),
        bundle: _FakeBundle({catalogueAssetPath: shipped}),
        nowOf: _fixedClock,
      );
      await controller.complete(dealt);

      final catalogue = await shippedCatalogue();
      final first = catalogue.entries.firstWhere(
        (entry) => entry.id == dealt.card.id,
      );
      final next = catalogue.entries.firstWhere(
        (entry) => entry.id == store.entries[4].itemId,
      );
      expect(first.size, Size.focus);
      expect(
        next.size,
        isNot(Size.focus),
        reason:
            'the answer row closes the day\'s slot before the bundled next '
            'deal resolves, so no second chunk composes for that day',
      );
    },
  );

  test('completing the day\'s last card appends only the answer row — no '
      'next deal exists to bundle', () async {
    final store = _RecordingStore();
    final controller = DispenserController(
      store: store,
      strings: AppStringsEs(),
      bundle: _FakeBundle({catalogueAssetPath: shipped}),
      nowOf: _fixedClock,
    );
    await SessionController(
      store: store,
      strings: AppStringsEs(),
      bundle: _FakeBundle({catalogueAssetPath: shipped}),
      nowOf: _fixedClock,
    ).handleAppOpen();

    var view = await controller.read();
    var completions = 0;
    while (view is DispenserDealt) {
      await controller.complete(view);
      completions++;
      view = await controller.read();
    }

    // The canonical day: one chunk plus three maintenance plus five
    // habits — the ninth completion exhausts the day and closes warm.
    expect(completions, 9);
    expect(view, isA<DispenserClosed>());
    expect(
      store.entries.where((entry) => entry.kind == 'card_done'),
      hasLength(9),
    );
    // One launch deal plus eight bundled deals: the last answer stands alone.
    expect(
      store.entries.where((entry) => entry.kind == 'card_dealt'),
      hasLength(9),
    );
    expect(store.entries.last.kind, 'card_done');
    expect(store.entries.last.itemId, isNotNull);
  });

  test('a rapid second complete serializes: it reads the post-answer log '
      'and the core guard appends nothing — exactly one card_done', () async {
    final store = _RecordingStore();
    final dealt = await openSessionAndReadFirstDeal(store);
    final controller = DispenserController(
      store: store,
      strings: AppStringsEs(),
      bundle: _FakeBundle({catalogueAssetPath: shipped}),
      nowOf: _fixedClock,
    );

    final first = controller.complete(dealt);
    final second = controller.complete(dealt);
    await first;
    await second;

    expect(store.entries.map((entry) => entry.kind).toList(), [
      'app_opened',
      'session_started',
      'card_dealt',
      'card_done',
      'card_dealt',
    ]);
  });

  test('a failing append rethrows to the caller and appends nothing; the '
      'chain recovers so the next completion records', () async {
    final inner = _RecordingStore();
    final store = _FailFirstDoneStore(inner);
    final dealt = await openSessionAndReadFirstDeal(store);
    final controller = DispenserController(
      store: store,
      strings: AppStringsEs(),
      bundle: _FakeBundle({catalogueAssetPath: shipped}),
      nowOf: _fixedClock,
    );

    await expectLater(controller.complete(dealt), throwsA(isA<StateError>()));
    expect(
      inner.entries.where((entry) => entry.kind == 'card_done'),
      isEmpty,
      reason: 'the log stayed consistent: nothing landed on the failed write',
    );

    // The chain cleared the failure: the retry (the card is still the
    // open session's dealt-but-unanswered one) now records both rows.
    await controller.complete(dealt);
    expect(inner.entries.map((entry) => entry.kind).toList(), [
      'app_opened',
      'session_started',
      'card_dealt',
      'card_done',
      'card_dealt',
    ]);
  });

  test('complete mints its instant at entry, before any await — the '
      'recorded rows describe the tap, not the reads that follow', () {
    final source = File('lib/dispenser/dispenser_controller.dart')
        .readAsStringSync();
    final completeAt = source.indexOf('Future<void> complete(');
    final mintedAtEntry = source.indexOf('final now = nowOf();', completeAt);
    final firstAwait = source.indexOf('await _loadCatalogue()', mintedAtEntry);
    expect(completeAt, greaterThanOrEqualTo(0));
    expect(mintedAtEntry, greaterThan(completeAt));
    expect(firstAwait, greaterThan(mintedAtEntry));
  });

  test('a read landing mid-completion-batch never derives from the '
      'half-written log — it waits for the settled chain and returns the '
      'bundled card', () async {
    final inner = _RecordingStore();
    final gate = Completer<void>();
    final store = _GatedBundledDealStore(inner, gate.future);
    await SessionController(
      store: store,
      strings: AppStringsEs(),
      bundle: _FakeBundle({catalogueAssetPath: shipped}),
      nowOf: _fixedClock,
    ).handleAppOpen();
    final controller = DispenserController(
      store: store,
      strings: AppStringsEs(),
      bundle: _FakeBundle({catalogueAssetPath: shipped}),
      nowOf: _fixedClock,
    );
    final dealt = (await controller.read()) as DispenserDealt;

    // The completion starts: its answer row lands, its bundled next deal
    // parks behind the gate — the log is half-written.
    final completing = controller.complete(dealt);
    await Future<void>.delayed(Duration.zero);
    expect(
      inner.entries.where((entry) => entry.kind == 'card_done'),
      hasLength(1),
    );
    expect(
      inner.entries.where((entry) => entry.kind == 'card_dealt'),
      hasLength(1),
      reason: 'the bundled deal is parked behind the gate, not yet landed',
    );

    // The read while the batch is parked must not resolve: without the
    // settled-chain await it would derive the resolver's fall-through
    // card from the half-written log.
    DispenserView? readResult;
    final reading = controller.read().then((value) => readResult = value);
    await Future<void>.delayed(Duration.zero);
    expect(
      readResult,
      isNull,
      reason: 'the read parks behind the in-flight completion batch',
    );

    gate.complete();
    await completing;
    await reading;

    // Once the batch settles, the read returns the bundled card — the
    // store's own recorded deal, never a resolver fall-through.
    expect(readResult, isA<DispenserDealt>());
    final bundled = (readResult as DispenserDealt).card;
    final landedDeal = inner.entries.lastWhere(
      (entry) => entry.kind == 'card_dealt',
    );
    expect(bundled.id, landedDeal.itemId);
  });

  test('complete stamps the whole batch with the instant minted at entry — '
      'the clock\'s later ticks never reach the rows', () async {
    var minute = 0;
    final mints = <int>[];
    DateTime advancingClock() {
      final now = DateTime.utc(2026, 8, 29, 12, minute++);
      mints.add(now.microsecondsSinceEpoch);
      return now;
    }

    final inner = _RecordingStore()
      ..entries.addAll([
        _moment('session_started', DateTime.utc(2026, 8, 29, 11), 'seed-1'),
        _act(
          'card_dealt',
          DateTime.utc(2026, 8, 29, 11, 1),
          'seed-2',
          chunkSeedId,
        ),
      ]);
    final store = _TickingReadStore(inner, () => minute++);
    final controller = DispenserController(
      store: store,
      strings: AppStringsEs(),
      bundle: _FakeBundle({catalogueAssetPath: shipped}),
      nowOf: advancingClock,
    );

    final dealt = (await controller.read()) as DispenserDealt;
    await controller.complete(dealt);

    // Exactly two mints — read()'s and complete()'s entry mint — and the
    // batch carries the entry mint alone. Code that minted after the
    // store reads (each of which ticks the clock once more) would stamp
    // a later tick on both rows.
    expect(mints, hasLength(2));
    final entryMint = mints[1];
    final answer = inner.entries[2];
    final nextDeal = inner.entries[3];
    expect(answer.kind, 'card_done');
    expect(nextDeal.kind, 'card_dealt');
    expect(answer.instantUtcMicros, entryMint);
    expect(nextDeal.instantUtcMicros, entryMint);
    expect(answer.offsetSeconds, 0);
    expect(nextDeal.offsetSeconds, 0);
  });

  test('skip appends card_skipped and the bundled next card_dealt — one '
      'minted instant, a v7 id per row, the dealt item passed', () async {
    final store = _RecordingStore();
    final dealt = await openSessionAndReadFirstDeal(store);
    final controller = DispenserController(
      store: store,
      strings: AppStringsEs(),
      bundle: _FakeBundle({catalogueAssetPath: shipped}),
      nowOf: _fixedClock,
    );
    await controller.skip(dealt);

    expect(store.entries.map((entry) => entry.kind).toList(), [
      'app_opened',
      'session_started',
      'card_dealt',
      'card_skipped',
      'card_dealt',
    ]);
    final answer = store.entries[3];
    final nextDeal = store.entries[4];
    expect(answer.itemId, dealt.card.id);
    expect(answer.itemOrigin, dealt.card.origin);
    // Identity re-resolves on the skip (AD-20): re-ranked, never
    // excluded — with a second candidate the deal differs.
    expect(nextDeal.itemId, isNot(dealt.card.id));
    // One minted instant (and offset) serves the whole skip batch.
    expect(answer.instantUtcMicros, nextDeal.instantUtcMicros);
    expect(answer.offsetSeconds, nextDeal.offsetSeconds);
    // A distinct v7 id per row.
    expect(answer.id, matches(v7));
    expect(nextDeal.id, matches(v7));
    expect(answer.id, isNot(nextDeal.id));
  });

  test('skipping the day\'s last candidate appends the answer row alone — '
      'the next read lands on the warm close', () async {
    final store = _RecordingStore();
    final controller = DispenserController(
      store: store,
      strings: AppStringsEs(),
      bundle: _FakeBundle({catalogueAssetPath: shipped}),
      nowOf: _fixedClock,
    );
    await SessionController(
      store: store,
      strings: AppStringsEs(),
      bundle: _FakeBundle({catalogueAssetPath: shipped}),
      nowOf: _fixedClock,
    ).handleAppOpen();

    // Answer eight of the canonical day's nine cards; the ninth is the
    // day's last candidate, and it is skipped, not completed.
    var view = await controller.read();
    for (var i = 0; i < 8; i++) {
      await controller.complete(view as DispenserDealt);
      view = await controller.read();
    }
    await controller.skip(view as DispenserDealt);

    expect(await controller.read(), isA<DispenserClosed>());
    expect(
      store.entries.where((entry) => entry.kind == 'card_skipped'),
      hasLength(1),
    );
    // The exhausted day bundled no next deal: the answer row stands alone.
    expect(store.entries.last.kind, 'card_skipped');
    expect(store.entries.last.itemId, isNotNull);
  });

  test('a rapid second skip serializes: it reads the post-answer log and '
      'the core guard appends nothing — exactly one card_skipped', () async {
    final store = _RecordingStore();
    final dealt = await openSessionAndReadFirstDeal(store);
    final controller = DispenserController(
      store: store,
      strings: AppStringsEs(),
      bundle: _FakeBundle({catalogueAssetPath: shipped}),
      nowOf: _fixedClock,
    );

    final first = controller.skip(dealt);
    final second = controller.skip(dealt);
    await first;
    await second;

    expect(store.entries.map((entry) => entry.kind).toList(), [
      'app_opened',
      'session_started',
      'card_dealt',
      'card_skipped',
      'card_dealt',
    ]);
  });

  test('a skip racing a Hecho serializes through the shared chain — '
      'whichever act is enqueued second reads the answered log and the '
      'guard appends nothing, in either order', () async {
    // Skip first, Hecho second: exactly one card_skipped, no card_done.
    final skipFirst = _RecordingStore();
    final dealtSkipFirst = await openSessionAndReadFirstDeal(skipFirst);
    final firstController = DispenserController(
      store: skipFirst,
      strings: AppStringsEs(),
      bundle: _FakeBundle({catalogueAssetPath: shipped}),
      nowOf: _fixedClock,
    );
    final skipping = firstController.skip(dealtSkipFirst);
    final completing = firstController.complete(dealtSkipFirst);
    await skipping;
    await completing;
    expect(
      skipFirst.entries.where((entry) => entry.kind == 'card_skipped'),
      hasLength(1),
    );
    expect(
      skipFirst.entries.where((entry) => entry.kind == 'card_done'),
      isEmpty,
    );

    // Hecho first, skip second: exactly one card_done, no card_skipped.
    final doneFirst = _RecordingStore();
    final dealtDoneFirst = await openSessionAndReadFirstDeal(doneFirst);
    final secondController = DispenserController(
      store: doneFirst,
      strings: AppStringsEs(),
      bundle: _FakeBundle({catalogueAssetPath: shipped}),
      nowOf: _fixedClock,
    );
    final completing2 = secondController.complete(dealtDoneFirst);
    final skipping2 = secondController.skip(dealtDoneFirst);
    await completing2;
    await skipping2;
    expect(
      doneFirst.entries.where((entry) => entry.kind == 'card_done'),
      hasLength(1),
    );
    expect(
      doneFirst.entries.where((entry) => entry.kind == 'card_skipped'),
      isEmpty,
    );
  });

  test('a failing skip append rethrows to the caller and appends nothing; '
      'the chain recovers so the next answer records', () async {
    final inner = _RecordingStore();
    final store = _FailFirstSkippedStore(inner);
    final dealt = await openSessionAndReadFirstDeal(store);
    final controller = DispenserController(
      store: store,
      strings: AppStringsEs(),
      bundle: _FakeBundle({catalogueAssetPath: shipped}),
      nowOf: _fixedClock,
    );

    await expectLater(controller.skip(dealt), throwsA(isA<StateError>()));
    expect(
      inner.entries.where((entry) => entry.kind == 'card_skipped'),
      isEmpty,
      reason: 'the log stayed consistent: nothing landed on the failed write',
    );

    // The chain cleared the failure: the retry (the card is still the
    // open session's dealt-but-unanswered one) now records both rows.
    await controller.skip(dealt);
    expect(inner.entries.map((entry) => entry.kind).toList(), [
      'app_opened',
      'session_started',
      'card_dealt',
      'card_skipped',
      'card_dealt',
    ]);
  });

  test('skip stamps the whole batch with the instant minted at entry — '
      'the clock\'s later ticks never reach the rows', () async {
    var minute = 0;
    final mints = <int>[];
    DateTime advancingClock() {
      final now = DateTime.utc(2026, 8, 29, 12, minute++);
      mints.add(now.microsecondsSinceEpoch);
      return now;
    }

    final inner = _RecordingStore()
      ..entries.addAll([
        _moment('session_started', DateTime.utc(2026, 8, 29, 11), 'seed-1'),
        _act(
          'card_dealt',
          DateTime.utc(2026, 8, 29, 11, 1),
          'seed-2',
          chunkSeedId,
        ),
      ]);
    final store = _TickingReadStore(inner, () => minute++);
    final controller = DispenserController(
      store: store,
      strings: AppStringsEs(),
      bundle: _FakeBundle({catalogueAssetPath: shipped}),
      nowOf: advancingClock,
    );

    final dealt = (await controller.read()) as DispenserDealt;
    // The minute skip() must mint, captured immediately before the call:
    // a mint moved after the store reads (each of which ticks the clock
    // once more) would stamp a later, observably different minute.
    final skipMinute = minute;
    await controller.skip(dealt);

    // Exactly two mints — read()'s and skip()'s entry mint.
    expect(mints, hasLength(2));
    final entryMint = DateTime.utc(
      2026,
      8,
      29,
      12,
      skipMinute,
    ).microsecondsSinceEpoch;
    final answer = inner.entries[2];
    final nextDeal = inner.entries[3];
    expect(answer.kind, 'card_skipped');
    expect(nextDeal.kind, 'card_dealt');
    expect(answer.instantUtcMicros, entryMint);
    expect(nextDeal.instantUtcMicros, entryMint);
    expect(answer.offsetSeconds, 0);
    expect(nextDeal.offsetSeconds, 0);
  });

  test(
    'a read landing mid-skip-batch never derives from the half-written '
    'log — it waits for the settled chain and returns the bundled card',
    () async {
      final inner = _RecordingStore();
      final gate = Completer<void>();
      final store = _GatedBundledDealStore(
        inner,
        gate.future,
        answerKind: 'card_skipped',
      );
      await SessionController(
        store: store,
        strings: AppStringsEs(),
        bundle: _FakeBundle({catalogueAssetPath: shipped}),
        nowOf: _fixedClock,
      ).handleAppOpen();
      final controller = DispenserController(
        store: store,
        strings: AppStringsEs(),
        bundle: _FakeBundle({catalogueAssetPath: shipped}),
        nowOf: _fixedClock,
      );
      final dealt = (await controller.read()) as DispenserDealt;

      // The skip starts: its answer row lands, its bundled next deal parks
      // behind the gate — the log is half-written.
      final skipping = controller.skip(dealt);
      await Future<void>.delayed(Duration.zero);
      expect(
        inner.entries.where((entry) => entry.kind == 'card_skipped'),
        hasLength(1),
      );
      expect(
        inner.entries.where((entry) => entry.kind == 'card_dealt'),
        hasLength(1),
        reason: 'the bundled deal is parked behind the gate, not yet landed',
      );

      // The read while the batch is parked must not resolve: without the
      // settled-chain await it would derive the resolver's fall-through
      // card from the half-written log.
      DispenserView? readResult;
      final reading = controller.read().then((value) => readResult = value);
      await Future<void>.delayed(Duration.zero);
      expect(
        readResult,
        isNull,
        reason: 'the read parks behind the in-flight skip batch',
      );

      gate.complete();
      await skipping;
      await reading;

      // Once the batch settles, the read returns the bundled card — the
      // store's own recorded deal, never a resolver fall-through.
      expect(readResult, isA<DispenserDealt>());
      final bundled = (readResult as DispenserDealt).card;
      final landedDeal = inner.entries.lastWhere(
        (entry) => entry.kind == 'card_dealt',
      );
      expect(bundled.id, landedDeal.itemId);
    },
  );

  test('a lone candidate re-deals: the skip re-ranks, never excludes — '
      'repetition accepted, never an empty day mid-budget (AD-20)', () async {
    // A single-entry catalogue (a real shipped id, so the generated name
    // lookup resolves): exactly one eligible candidate exists, and the
    // day's budget is nowhere near spent.
    final lone =
        '{"version":1,"entries":['
        '{"id":"pasar-la-aspiradora-a-la-cocina","size":"focus",'
        '"cadence":"weekly","zone":"z1"}]}';
    final bundle = _FakeBundle({catalogueAssetPath: lone});
    final store = _RecordingStore();
    await SessionController(
      store: store,
      strings: AppStringsEs(),
      bundle: bundle,
      nowOf: _fixedClock,
    ).handleAppOpen();
    final controller = DispenserController(
      store: store,
      strings: AppStringsEs(),
      bundle: bundle,
      nowOf: _fixedClock,
    );
    final dealt = (await controller.read()) as DispenserDealt;

    await controller.skip(dealt);

    expect(store.entries.map((entry) => entry.kind).toList(), [
      'app_opened',
      'session_started',
      'card_dealt',
      'card_skipped',
      'card_dealt',
    ]);
    final answer = store.entries[3];
    final nextDeal = store.entries[4];
    expect(answer.itemId, dealt.card.id);
    // The bundled deal names the skipped card itself: the lone candidate
    // re-deals (re-ranked, not excluded) rather than leaving an empty
    // day while budget remains.
    expect(nextDeal.itemId, dealt.card.id);
    final view = await controller.read();
    expect(view, isA<DispenserDealt>());
    expect((view as DispenserDealt).card.id, dealt.card.id);
  });

  test('completing with a seeded below-10 bag bundles a non-focus next '
      'deal — the shell threads the derived bag into the answer command '
      '(2.1, FR-7)', () async {
    final store = _RecordingStore();
    // A seeded bag of 5, in the log before the session opens: the shell
    // derivation must feed cardDone, so the bundled next deal composes
    // upkeep, not a chunk.
    store.entries.add((
      id: 'seed-bag',
      kind: 'setting_changed',
      instantUtcMicros: DateTime.utc(2026, 8, 29, 10).microsecondsSinceEpoch,
      offsetSeconds: 0,
      itemId: null,
      itemOrigin: null,
      stack: null,
      settingKey: 'time_bag',
      settingValue: 5,
      pocketMinutes: null,
      energyLevel: null,
    ));
    final dealt = await openSessionAndReadFirstDeal(store);
    // The open's own deal composed under the same derived bag: upkeep
    // leads the day, never the chunk.
    final catalogue = await shippedCatalogue();
    final openSize = catalogue.entries
        .firstWhere((entry) => entry.id == dealt.card.id)
        .size;
    expect(openSize, isNot(Size.focus));

    final controller = DispenserController(
      store: store,
      strings: AppStringsEs(),
      bundle: _FakeBundle({catalogueAssetPath: shipped}),
      nowOf: _fixedClock,
    );
    await controller.complete(dealt);
    final nextDeal = store.entries.last;
    expect(nextDeal.kind, 'card_dealt');
    final nextSize = catalogue.entries
        .firstWhere((entry) => entry.id == nextDeal.itemId)
        .size;
    // With the shell threading reverted to the default, the bundled
    // deal would be a focus card — this pin is what fails.
    expect(nextSize, isNot(Size.focus));
  });

  /// The Story-2.2 harness builder, shared by the declare and pause
  /// groups (the pause matrix mirrors the pocket group's, it does not
  /// duplicate it).
  DispenserController buildFor(
    StorePort store, {
    LogWriteQueue? writeQueue,
    DateTime Function() nowOf = _fixedClock,
  }) => DispenserController(
    store: store,
    strings: AppStringsEs(),
    bundle: _FakeBundle({catalogueAssetPath: shipped}),
    nowOf: nowOf,
    writeQueue: writeQueue,
  );

  group('the pocket declaration (Story 2.2, FR-8, AD-19)', () {
    test('declaring from idle appends [session_started{p}, card_dealt?] '
        '— the deal fits the pocket, and the view carries the standing '
        'pocket for the chip', () async {
      final store = _RecordingStore();
      final controller = buildFor(store);
      final view = await controller.declarePocket(15);

      expect(store.entries.map((entry) => entry.kind).toList(), [
        'session_started',
        'card_dealt',
      ]);
      final started = store.entries.first;
      expect(started.pocketMinutes, 15);
      expect(started.itemId, isNull);
      final catalogue = await shippedCatalogue();
      final dealtSize = catalogue.entries
          .firstWhere((entry) => entry.id == store.entries[1].itemId)
          .size;
      expect(dealtSize, Size.focus, reason: '15 holds the chunk exactly');

      expect(view, isA<DispenserDealt>());
      expect((view as DispenserDealt).pocketMinutes, 15);

      // A pocket the chunk cannot hold deals beneath it.
      final narrow = _RecordingStore();
      final narrowView = await buildFor(narrow).declarePocket(4);
      expect(narrow.entries.map((entry) => entry.kind).toList(), [
        'session_started',
        'card_dealt',
      ]);
      expect(narrow.entries.first.pocketMinutes, 4);
      final narrowSize = catalogue.entries
          .firstWhere((entry) => entry.id == narrow.entries[1].itemId)
          .size;
      expect(narrowSize, isNot(Size.focus));
      expect((narrowView as DispenserDealt).pocketMinutes, 4);
    });

    test('a declaration queued behind app open reads its persisted session '
        'and supersedes it, never racing a second session_started', () async {
      final store = _RecordingStore();
      final writes = LogWriteQueue();
      final session = SessionController(
        store: store,
        strings: AppStringsEs(),
        bundle: _FakeBundle({catalogueAssetPath: shipped}),
        nowOf: _fixedClock,
        writeQueue: writes,
      );
      final dispenser = buildFor(store, writeQueue: writes);

      final opening = session.handleAppOpen();
      final declaration = dispenser.declarePocket(15);
      await Future.wait([opening, declaration]);

      expect(store.entries.map((entry) => entry.kind).toList(), [
        'app_opened',
        'session_started',
        'card_dealt',
        'session_ended',
        'session_started',
      ]);
      expect(store.entries.last.pocketMinutes, 15);
    });

    test('a delayed read derives pocket dealability at its post-queue '
        'instant, not before a pending write', () async {
      final store = _RecordingStore()
        ..entries.add((
          id: 'pocket-start',
          kind: 'session_started',
          instantUtcMicros: DateTime.utc(
            2026,
            8,
            29,
            12,
          ).microsecondsSinceEpoch,
          offsetSeconds: 0,
          itemId: null,
          itemOrigin: null,
          stack: null,
          settingKey: null,
          settingValue: null,
          pocketMinutes: 1,
          energyLevel: null,
        ));
      final writes = LogWriteQueue();
      final release = Completer<void>();
      unawaited(writes.enqueue(() => release.future));
      var now = DateTime.utc(2026, 8, 29, 12, 0, 30);
      final read = buildFor(store, writeQueue: writes, nowOf: () => now).read();

      now = DateTime.utc(2026, 8, 29, 12, 2);
      release.complete();

      expect(await read, isA<DispenserClosed>());
    });

    test(
      'declaring with a card in progress supersedes: [session_ended, '
      'session_started{p}] at one instant, no bundled deal — the same '
      'card stays answerable and its Hecho consumes the new pocket',
      () async {
        final store = _RecordingStore();
        final dealt = await openSessionAndReadFirstDeal(store);
        final controller = buildFor(store);
        final view = await controller.declarePocket(5);

        expect(store.entries.map((entry) => entry.kind).toList(), [
          'app_opened',
          'session_started',
          'card_dealt',
          'session_ended',
          'session_started',
        ]);
        final ended = store.entries[3];
        final started = store.entries[4];
        expect(started.pocketMinutes, 5);
        expect(
          ended.instantUtcMicros == started.instantUtcMicros,
          isTrue,
          reason: 'the supersede pair lands at one instant',
        );
        // The carried card is the view: unchanged and still answerable.
        expect(view, isA<DispenserDealt>());
        expect((view as DispenserDealt).card.id, dealt.card.id);
        expect(view.pocketMinutes, 5);

        // A 15-minute chunk finished under a 5-minute pocket honestly
        // spends it: the Hecho records and nothing bundles.
        await controller.complete(view);
        expect(store.entries[5].kind, 'card_done');
        expect(store.entries[5].itemId, dealt.card.id);
        expect(store.entries, hasLength(6));
        final after = await controller.read();
        expect(after, isA<DispenserClosed>());
        expect((after as DispenserClosed).pocketMinutes, 5);
      },
    );

    test('re-declaring over a pocketed session supersedes again — '
        'consumption restarts at zero', () async {
      final store = _RecordingStore();
      await buildFor(store).declarePocket(15);
      // Answer the dealt card: 15 of 15 consumed, the read closes warm.
      final spent = await buildFor(store).read();
      expect(spent, isA<DispenserDealt>());
      await buildFor(store).complete(spent as DispenserDealt);
      expect(await buildFor(store).read(), isA<DispenserClosed>());

      final view = await buildFor(store).declarePocket(20);
      final kinds = store.entries.map((entry) => entry.kind).toList();
      expect(kinds, [
        'session_started',
        'card_dealt',
        'card_done',
        'session_ended',
        'session_started',
        'card_dealt',
      ]);
      expect(store.entries[4].pocketMinutes, 20);
      // The fresh sitting deals upkeep, not the chunk: the day's focus
      // slot closed with the first sitting's Hecho, and chaining
      // sessions cannot multiply advance (FR-7) — the restarted
      // consumption bounds only upkeep and habits now.
      final catalogue = await shippedCatalogue();
      final size = catalogue.entries
          .firstWhere((entry) => entry.id == store.entries[5].itemId)
          .size;
      expect(size, isNot(Size.focus));
      expect((view as DispenserDealt).pocketMinutes, 20);
    });

    test('a spent pocket presents the warm close through read(), with no '
        'eager session_ended anywhere (FR-3, FR-8)', () async {
      final store = _RecordingStore();
      final controller = buildFor(store);
      await controller.declarePocket(3);
      final dealt = await controller.read();
      expect(dealt, isA<DispenserDealt>());
      await controller.complete(dealt as DispenserDealt);

      // 3 of 3 minutes answered: the read resolves the warm close and
      // the log holds no close row — the pocket lingers derived-open.
      final view = await controller.read();
      expect(view, isA<DispenserClosed>());
      expect((view as DispenserClosed).pocketMinutes, 3);
      expect(
        store.entries.where((entry) => entry.kind == 'session_ended'),
        isEmpty,
      );
    });

    test('an out-of-range value the command refuses writes nothing, '
        'returns the unchanged state, and surfaces no error — the ladder '
        'makes it unreachable', () async {
      final store = _RecordingStore();
      final dealt = await openSessionAndReadFirstDeal(store);
      final controller = buildFor(store);
      final view = await controller.declarePocket(61);

      expect(store.entries.map((entry) => entry.kind).toList(), [
        'app_opened',
        'session_started',
        'card_dealt',
      ], reason: 'the refusal appended nothing at all');
      expect(view, isA<DispenserDealt>());
      expect((view as DispenserDealt).card.id, dealt.card.id);
      expect(view.pocketMinutes, isNull);
    });

    test('the unrounded standing pocket reads on the closed surface too '
        '— the chip\'s data survives the warm close', () async {
      final store = _RecordingStore();
      final controller = buildFor(store);
      await controller.declarePocket(3);
      await controller.complete(await controller.read() as DispenserDealt);
      final closed = await controller.read();
      expect(closed, isA<DispenserClosed>());
      expect((closed as DispenserClosed).pocketMinutes, 3);
    });

    test(
      'a failing declare append rethrows to the caller and lands '
      'nothing — no half-supersede: no session_ended without its '
      'session_started — and the recovered chain lands the next write',
      () async {
        final inner = _RecordingStore();
        final dealt = await openSessionAndReadFirstDeal(inner);
        final failing = _FailNextAppendStore(inner);
        final controller = buildFor(failing);
        final before = inner.entries.length;

        // The first row of the declare batch is the supersede pair's
        // session_ended: its failure leaves the log exactly as it stood.
        failing.failNextAppend = true;
        await expectLater(
          controller.declarePocket(5),
          throwsA(isA<StateError>()),
        );
        expect(inner.entries, hasLength(before));
        expect(
          inner.entries.where((entry) => entry.kind == 'session_ended'),
          isEmpty,
          reason:
              'a landed session_ended without its session_started '
              'would be a half-supersede — the session the declare meant '
              'to replace stays open instead',
        );

        // The chain recovered: a later declare lands its whole batch,
        // carried card and all.
        final view = await controller.declarePocket(15);
        expect(inner.entries.skip(before).map((entry) => entry.kind).toList(), [
          'session_ended',
          'session_started',
        ]);
        expect(inner.entries.last.pocketMinutes, 15);
        expect(view, isA<DispenserDealt>());
        expect((view as DispenserDealt).card.id, dealt.card.id);
        expect(view.pocketMinutes, 15);
      },
    );
  });

  group('the pause (Story 2.3, FR-9, AD-19)', () {
    test('pausing an open session appends exactly [session_ended] — one '
        'row, one minted instant, a v7 id, no payload — and the committed '
        'view is the warm close with the chip back at its default', () async {
      final store = _RecordingStore();
      final dealt = await openSessionAndReadFirstDeal(store);
      final controller = buildFor(store);
      final view = await controller.pause();

      expect(store.entries.map((entry) => entry.kind).toList(), [
        'app_opened',
        'session_started',
        'card_dealt',
        'session_ended',
      ]);
      final ended = store.entries.last;
      expect(ended.itemId, isNull);
      expect(ended.pocketMinutes, isNull);
      expect(ended.id, matches(v7));
      expect(ended.instantUtcMicros, _fixedClock().microsecondsSinceEpoch);

      // The committed view is the standing warm close, no pocket fact.
      expect(view, isA<DispenserClosed>());
      expect((view as DispenserClosed).pocketMinutes, isNull);
      // The dealt card no longer renders as answerable: the read stays
      // closed.
      expect(await controller.read(), isA<DispenserClosed>());
      expect(dealt.card, isNotNull);
    });

    test('pausing with nothing open appends nothing at all — the accepted '
        'quiet no-op, the view unchanged', () async {
      final store = _RecordingStore();
      final controller = buildFor(store);
      await controller.pause();
      expect(store.entries, isEmpty);

      // And again after a real pause: exactly one session_ended ever.
      await openSessionAndReadFirstDeal(store);
      await controller.pause();
      await controller.pause();
      expect(
        store.entries.where((entry) => entry.kind == 'session_ended'),
        hasLength(1),
      );
      expect(await controller.read(), isA<DispenserClosed>());
    });

    test('a failing pause append rethrows to the caller and lands nothing; '
        'the recovered chain lands the next write', () async {
      final inner = _RecordingStore();
      await openSessionAndReadFirstDeal(inner);
      final failing = _FailNextAppendStore(inner);
      final controller = buildFor(failing);
      final before = inner.entries.length;

      failing.failNextAppend = true;
      await expectLater(controller.pause(), throwsA(isA<StateError>()));
      expect(inner.entries, hasLength(before));
      expect(
        inner.entries.where((entry) => entry.kind == 'session_ended'),
        isEmpty,
        reason: 'nothing landed on the failed write',
      );

      // The chain recovered: the retried pause lands its one row.
      final view = await controller.pause();
      expect(inner.entries.skip(before).map((entry) => entry.kind).toList(), [
        'session_ended',
      ]);
      expect(view, isA<DispenserClosed>());
    });

    test(
      'pausing a lingering exhausted-pool session still lands '
      '[session_ended] — the surface was already the close, unchanged',
      () async {
        final store = _RecordingStore();
        final controller = buildFor(store);
        await SessionController(
          store: store,
          strings: AppStringsEs(),
          bundle: _FakeBundle({catalogueAssetPath: shipped}),
          nowOf: _fixedClock,
        ).handleAppOpen();
        // Run the day to exhaustion inside the one open sitting: the
        // ninth answer appends no bundled deal, the read closes warm —
        // and the session lingers derived-open.
        var view = await controller.read();
        while (view is DispenserDealt) {
          await controller.complete(view);
          view = await controller.read();
        }
        expect(view, isA<DispenserClosed>());

        final paused = await controller.pause();
        expect(
          store.entries.where((entry) => entry.kind == 'session_ended'),
          hasLength(1),
        );
        expect(store.entries.last.kind, 'session_ended');
        expect(paused, isA<DispenserClosed>());
        expect(
          (paused as DispenserClosed).pocketMinutes,
          isNull,
          reason: 'no pocket was ever declared',
        );
      },
    );

    test('a pocketed-unelapsed mid-pause with the card standing: the chip '
        'reads the declared pocket before, the 15 default after', () async {
      final store = _RecordingStore();
      final controller = buildFor(store);
      final declared = await controller.declarePocket(20);
      expect(declared, isA<DispenserDealt>());
      expect((declared as DispenserDealt).pocketMinutes, 20);
      // The card stands dealt-but-unanswered inside the unelapsed
      // pocket when the pause lands.
      final paused = await controller.pause();
      expect(store.entries.map((entry) => entry.kind).toList(), [
        'session_started',
        'card_dealt',
        'session_ended',
      ]);
      expect(paused, isA<DispenserClosed>());
      expect((paused as DispenserClosed).pocketMinutes, isNull);
      // The post-pause read keeps the close: no card renders, and the
      // chip's data is gone with the session.
      final after = await controller.read();
      expect(after, isA<DispenserClosed>());
      expect((after as DispenserClosed).pocketMinutes, isNull);
    });

    test('a pause queued behind a completion lands coherently through the '
        'shared queue — the declare-interleave pattern, on the stop', () async {
      final store = _RecordingStore();
      final writes = LogWriteQueue();
      final session = SessionController(
        store: store,
        strings: AppStringsEs(),
        bundle: _FakeBundle({catalogueAssetPath: shipped}),
        nowOf: _fixedClock,
        writeQueue: writes,
      );
      final dispenser = buildFor(store, writeQueue: writes);
      await session.handleAppOpen();
      final dealt = (await dispenser.read()) as DispenserDealt;

      final completing = dispenser.complete(dealt);
      final pausing = dispenser.pause();
      await Future.wait([completing, pausing]);

      // The completion's batch landed whole, then the pause's one row —
      // coherent order through the one shared chain.
      expect(store.entries.map((entry) => entry.kind).toList(), [
        'app_opened',
        'session_started',
        'card_dealt',
        'card_done',
        'card_dealt',
        'session_ended',
      ]);
      expect(await dispenser.read(), isA<DispenserClosed>());
    });

    test('pause stamps its row with the instant minted at entry — the '
        'clock\'s later ticks and the queued write never reach the row '
        '(the complete/skip pattern, on the stop)', () async {
      var minute = 0;
      final mints = <int>[];
      DateTime advancingClock() {
        final now = DateTime.utc(2026, 8, 29, 12, minute++);
        mints.add(now.microsecondsSinceEpoch);
        return now;
      }

      final inner = _RecordingStore()
        ..entries.addAll([
          _moment('session_started', DateTime.utc(2026, 8, 29, 11), 'seed-1'),
          _act(
            'card_dealt',
            DateTime.utc(2026, 8, 29, 11, 1),
            'seed-2',
            chunkSeedId,
          ),
        ]);
      // The shared queue holds a gated antecedent write, so the pause's
      // write parks behind it — and the antecedent advances the clock
      // at its own completion moment before the pause's closure starts.
      // A mint taken anywhere inside that closure — at its top or after
      // the ticking store read — therefore lands on a later,
      // observably different minute than the tap's.
      final writes = LogWriteQueue();
      final release = Completer<void>();
      unawaited(
        writes.enqueue(() async {
          await release.future;
          minute++;
        }),
      );
      final store = _TickingReadStore(inner, () => minute++);
      final controller = buildFor(
        store,
        writeQueue: writes,
        nowOf: advancingClock,
      );

      // The minute pause() must mint, captured immediately before the
      // call: the row must describe the tap, never the post-queue
      // moment.
      final pauseMinute = minute;
      final pausing = controller.pause();
      await Future<void>.delayed(Duration.zero);
      expect(
        inner.entries.where((entry) => entry.kind == 'session_ended'),
        isEmpty,
        reason: 'the write is still parked behind the gated antecedent',
      );

      release.complete();
      await pausing;

      // Exactly two mints — pause()'s entry mint and its read-back's.
      expect(mints, hasLength(2));
      final entryMint = DateTime.utc(
        2026,
        8,
        29,
        12,
        pauseMinute,
      ).microsecondsSinceEpoch;
      final ended = inner.entries.last;
      expect(ended.kind, 'session_ended');
      expect(ended.instantUtcMicros, entryMint);
      expect(ended.offsetSeconds, 0);
    });
  });

  group('the checkpoint extension (Story 2.4, FR-10, AD-19, UJ-1)', () {
    /// A seeded pocketed session start, as a declaration or a process
    /// death would have left it — the start instant injectable so a
    /// pocket sits elapsed or unelapsed at the fixed 12:00 clock.
    void seedPocketedStart(
      _RecordingStore store,
      int pocketMinutes, {
      DateTime? at,
    }) {
      store.entries.add((
        id: 'seed-pocket',
        kind: 'session_started',
        instantUtcMicros:
            (at ?? DateTime.utc(2026, 8, 29, 11)).microsecondsSinceEpoch,
        offsetSeconds: 0,
        itemId: null,
        itemOrigin: null,
        stack: null,
        settingKey: null,
        settingValue: null,
        pocketMinutes: pocketMinutes,
        energyLevel: null,
      ));
    }

    test('read maps the mid-pocket multiple to the rest offer: a '
        '45-pocket 40 minutes in, unelapsed, preempts the deal that '
        'would resolve', () async {
      final store = _RecordingStore();
      seedPocketedStart(store, 45, at: DateTime.utc(2026, 8, 29, 11, 20));
      final view = await buildFor(store).read();

      expect(view, isA<DispenserRestOffer>());
      expect((view as DispenserRestOffer).pocketMinutes, 45);
      // Reading wrote nothing: the derivation is a read (AD-3).
      expect(store.entries, hasLength(1));
    });

    test('a card in flight at the crossing stays visible; a card dealt '
        'into the pending offer is preempted', () async {
      final store = _RecordingStore();
      seedPocketedStart(store, 45, at: DateTime.utc(2026, 8, 29, 11, 20));
      // Dealt at cumulative 13 (11:33): before the 15 crossing.
      store.entries.add((
        id: 'seed-deal-early',
        kind: 'card_dealt',
        instantUtcMicros: DateTime.utc(
          2026,
          8,
          29,
          11,
          33,
        ).microsecondsSinceEpoch,
        offsetSeconds: 0,
        itemId: chunkSeedId,
        itemOrigin: Origin.shipped,
        stack: null,
        settingKey: null,
        settingValue: null,
        pocketMinutes: null,
        energyLevel: null,
      ));
      expect(await buildFor(store).read(), isA<DispenserDealt>());

      // Re-dealt at cumulative 17 (11:37): the offer takes the surface.
      final store2 = _RecordingStore();
      seedPocketedStart(store2, 45, at: DateTime.utc(2026, 8, 29, 11, 20));
      store2.entries.add((
        id: 'seed-deal-late',
        kind: 'card_dealt',
        instantUtcMicros: DateTime.utc(
          2026,
          8,
          29,
          11,
          37,
        ).microsecondsSinceEpoch,
        offsetSeconds: 0,
        itemId: chunkSeedId,
        itemOrigin: Origin.shipped,
        stack: null,
        settingKey: null,
        settingValue: null,
        pocketMinutes: null,
        energyLevel: null,
      ));
      expect(await buildFor(store2).read(), isA<DispenserRestOffer>());
    });

    test('chained short pockets: a new sitting\'s bundled first deal is '
        'preempted — the standing permission leads (FR-10)', () async {
      final store = _RecordingStore();
      void sitting(String id, DateTime start, DateTime end) {
        store.entries.add((
          id: 'start-$id',
          kind: 'session_started',
          instantUtcMicros: start.microsecondsSinceEpoch,
          offsetSeconds: 0,
          itemId: null,
          itemOrigin: null,
          stack: null,
          settingKey: null,
          settingValue: null,
          pocketMinutes: 10,
          energyLevel: null,
        ));
        store.entries.add((
          id: 'end-$id',
          kind: 'session_ended',
          instantUtcMicros: end.microsecondsSinceEpoch,
          offsetSeconds: 0,
          itemId: null,
          itemOrigin: null,
          stack: null,
          settingKey: null,
          settingValue: null,
          pocketMinutes: null,
          energyLevel: null,
        ));
      }

      sitting(
        '1',
        DateTime.utc(2026, 8, 29, 10),
        DateTime.utc(2026, 8, 29, 10, 10),
      );
      sitting(
        '2',
        DateTime.utc(2026, 8, 29, 10, 20),
        DateTime.utc(2026, 8, 29, 10, 30),
      );
      sitting(
        '3',
        DateTime.utc(2026, 8, 29, 10, 40),
        DateTime.utc(2026, 8, 29, 10, 50),
      );
      sitting(
        '4',
        DateTime.utc(2026, 8, 29, 11),
        DateTime.utc(2026, 8, 29, 11, 10),
      );
      seedPocketedStart(store, 10, at: DateTime.utc(2026, 8, 29, 11, 20));
      store.entries.add((
        id: 'seed-deal-s5',
        kind: 'card_dealt',
        instantUtcMicros: DateTime.utc(
          2026,
          8,
          29,
          11,
          20,
        ).microsecondsSinceEpoch,
        offsetSeconds: 0,
        itemId: chunkSeedId,
        itemOrigin: Origin.shipped,
        stack: null,
        settingKey: null,
        settingValue: null,
        pocketMinutes: null,
        energyLevel: null,
      ));
      final view = await buildFor(
        store,
        nowOf: () => DateTime.utc(2026, 8, 29, 11, 21),
      ).read();
      expect(
        view,
        isA<DispenserRestOffer>(),
        reason:
            'cumulative 40 minutes unanswered: the launch deal hides '
            'behind the offer, never a dodge by chaining',
      );
    });

    test('extend appends exactly one session_extended{15} — one minted '
        'instant, a v7 id — and the read-back returns the card with '
        'the lifted pocket (chip reads 60)', () async {
      final store = _RecordingStore();
      seedPocketedStart(store, 45, at: DateTime.utc(2026, 8, 29, 11, 20));
      final controller = buildFor(store);
      expect(await controller.read(), isA<DispenserRestOffer>());

      final view = await controller.extend();

      expect(store.entries.map((entry) => entry.kind).toList(), [
        'session_started',
        'session_extended',
        'card_dealt',
      ]);
      final extended = store.entries.firstWhere(
        (entry) => entry.kind == 'session_extended',
      );
      expect(extended.pocketMinutes, checkpointIntervalMinutes);
      expect(extended.itemId, isNull);
      expect(extended.id, matches(v7));
      expect(extended.instantUtcMicros, _fixedClock().microsecondsSinceEpoch);
      expect(store.entries.last.kind, 'card_dealt');
      expect(store.entries.last.id, matches(v7));

      // No standing card existed, so the command minted the deal
      // (AD-3) — the card the surface shows is one this write landed.
      expect(view, isA<DispenserDealt>());
      expect((view as DispenserDealt).pocketMinutes, 60);
    });

    test('extend with nothing open appends nothing at all — the '
        'accepted quiet no-op, the pause\'s own precedent', () async {
      final store = _RecordingStore();
      final controller = buildFor(store);
      final view = await controller.extend();
      expect(store.entries, isEmpty);
      expect(view, isA<DispenserClosed>());

      // And again after a real session closed: exactly one extension
      // row ever, never a re-open.
      seedPocketedStart(store, 20, at: DateTime.utc(2026, 8, 29, 11, 50));
      await controller.pause();
      expect(await controller.extend(), isA<DispenserClosed>());
      expect(
        store.entries.where((entry) => entry.kind == 'session_extended'),
        isEmpty,
      );
      expect(
        store.entries.where((entry) => entry.kind == 'session_ended'),
        hasLength(1),
      );
    });

    test('the coincidence (UJ-1): an elapsed pocket closes the surface '
        'and the close is the offer — Quiero seguir offered while the '
        'pool could deal', () async {
      final store = _RecordingStore();
      // Seeded 11:45 with 15 minutes: elapsed exactly at the fixed
      // 12:00 clock — the close and the checkpoint coincide.
      seedPocketedStart(store, 15, at: DateTime.utc(2026, 8, 29, 11, 45));
      final view = await buildFor(store).read();

      expect(view, isA<DispenserClosed>());
      expect(
        (view as DispenserClosed).continueOffered,
        isTrue,
        reason:
            'the shipped pool holds candidates: the close carries '
            'the silent continue',
      );

      // A pool-exhausted close carries nothing: with an empty
      // catalogue the probe finds no deal the lifted pocket could
      // resolve.
      final bare = _RecordingStore();
      seedPocketedStart(bare, 15, at: DateTime.utc(2026, 8, 29, 11, 45));
      final bareView = await DispenserController(
        store: bare,
        strings: AppStringsEs(),
        bundle: _FakeBundle({catalogueAssetPath: '{"version":1,"entries":[]}'}),
        nowOf: _fixedClock,
      ).read();
      expect(bareView, isA<DispenserClosed>());
      expect((bareView as DispenserClosed).continueOffered, isFalse);
    });

    test('extend at the close: one session_extended{15} lifts the '
        'pocket 15→30 and the bundled card_dealt lets Hecho land — '
        'the same silent action, no second mechanism', () async {
      final store = _RecordingStore();
      seedPocketedStart(store, 15, at: DateTime.utc(2026, 8, 29, 11, 45));
      final controller = buildFor(store);
      expect(
        (await controller.read() as DispenserClosed).continueOffered,
        isTrue,
      );

      final view = await controller.extend();

      expect(store.entries.map((entry) => entry.kind).toList(), [
        'session_started',
        'session_extended',
        'card_dealt',
      ]);
      expect(
        store.entries
            .firstWhere((entry) => entry.kind == 'session_extended')
            .pocketMinutes,
        15,
      );
      expect(view, isA<DispenserDealt>());
      if (view is! DispenserDealt) {
        fail('expected DispenserDealt after close-continue');
      }
      expect(view.pocketMinutes, 30);

      await controller.complete(view);
      expect(
        store.entries.where((entry) => entry.kind == 'card_done'),
        hasLength(1),
        reason: 'the bundled deal is unanswered, so Hecho lands (AD-3)',
      );
    });

    test('a failing extend append rethrows to the caller and lands '
        'nothing; the recovered chain lands the retried extension', () async {
      final inner = _RecordingStore();
      seedPocketedStart(inner, 45, at: DateTime.utc(2026, 8, 29, 11, 20));
      final failing = _FailNextAppendStore(inner);
      final controller = buildFor(failing);
      final before = inner.entries.length;

      failing.failNextAppend = true;
      await expectLater(controller.extend(), throwsA(isA<StateError>()));
      expect(inner.entries, hasLength(before));
      expect(
        inner.entries.where((entry) => entry.kind == 'session_extended'),
        isEmpty,
        reason: 'nothing landed on the failed write',
      );

      // The chain recovered: the retried extension lands its rows.
      final view = await controller.extend();
      expect(inner.entries.skip(before).map((entry) => entry.kind).toList(), [
        'session_extended',
        'card_dealt',
      ]);
      expect(
        inner.entries
            .firstWhere((entry) => entry.kind == 'session_extended')
            .pocketMinutes,
        15,
      );
      expect(view, isA<DispenserDealt>());
    });

    test('read maps the offer on an unbounded sitting too — the '
        'auto-open shape, no declared pocket: the offer carries no '
        'pocket fact and the chip falls back to its default', () async {
      final store = _RecordingStore();
      // A pocket-less open sitting 16 minutes in at the fixed clock.
      store.entries.add(
        _moment('session_started', DateTime.utc(2026, 8, 29, 11, 44), 'seed'),
      );
      final view = await buildFor(store).read();

      expect(view, isA<DispenserRestOffer>());
      expect((view as DispenserRestOffer).pocketMinutes, isNull);
      // Reading wrote nothing: the derivation is a read (AD-3).
      expect(store.entries, hasLength(1));
    });

    test('a pool-exhausted close with an unelapsed pocket swallows the '
        'due offer — the standing close wins, no continue is offered, '
        'and the multiple stands for the next sitting', () async {
      final store = _RecordingStore();
      seedPocketedStart(store, 45, at: DateTime.utc(2026, 8, 29, 11, 50));
      // The sitting's first deal, as the launch lifecycle would have
      // left it: without a recorded card_dealt no answer can land
      // (AD-3 — the read proposes, only commands write).
      store.entries.add(
        _act(
          'card_dealt',
          DateTime.utc(2026, 8, 29, 11, 50, 1),
          'seed-deal',
          chunkSeedId,
        ),
      );
      // A mutable clock: the day exhausts under fifteen minutes of
      // sitting time (no multiple crosses while the work lasts), then
      // time moves forty minutes in — the pocket still unelapsed to
      // 12:35, the second multiple crossed, the pool spent.
      var now = DateTime.utc(2026, 8, 29, 11, 50);
      final controller = buildFor(store, nowOf: () => now);

      var view = await controller.read();
      var completions = 0;
      while (view is DispenserDealt) {
        await controller.complete(view);
        completions++;
        now = DateTime.utc(2026, 8, 29, 11, 50 + completions);
        view = await controller.read();
      }
      expect(completions, 9, reason: 'the canonical day ran to exhaustion');
      expect(view, isA<DispenserClosed>());

      now = DateTime.utc(2026, 8, 29, 12, 30);
      final close = await controller.read();
      expect(close, isA<DispenserClosed>());
      expect(
        (close as DispenserClosed).continueOffered,
        isFalse,
        reason:
            'the pool holds nothing: the standing close wins over '
            'the due multiple and carries no continue action',
      );

      // The multiple stood through the close: after the sitting ends,
      // the next same-day sitting's derivation owes the offer once
      // more (FR-10's extends-only rule — only an acceptance consumes).
      await controller.pause();
      view = await controller.declarePocket(15);
      expect(
        view,
        isA<DispenserClosed>(),
        reason: 'the spent day deals nothing',
      );
      final state = deriveCheckpoint(
        entries: logEntriesOf(store.entries),
        instantUtcMicros: now.microsecondsSinceEpoch,
        offsetSeconds: 0,
      );
      expect(
        state.offerDue,
        isTrue,
        reason:
            'crossed 2 against answered 0 inside the fresh sitting: '
            'the close swallowed the offer, never the multiple',
      );
    });

    test('a long-elapsed close carries no continue even over a full '
        'pool — one interval cannot reach, and the chip is the way '
        'back in (FR-10\'s dead-action rule)', () async {
      final store = _RecordingStore();
      // A 15-pocket started 11:05: elapsed at 11:20, forty minutes
      // past at the fixed clock — one +15 acceptance could lift the
      // deadline only to 11:35, long gone.
      seedPocketedStart(store, 15, at: DateTime.utc(2026, 8, 29, 11, 5));
      final view = await buildFor(store).read();

      expect(view, isA<DispenserClosed>());
      final close = view as DispenserClosed;
      expect(
        close.continueOffered,
        isFalse,
        reason:
            'the pool could deal, but the tap would visibly change '
            'nothing — a dead action the offer\'s grammar forbids',
      );
      expect(
        close.pocketMinutes,
        15,
        reason:
            'the chip keeps the declared pocket: the ladder, never '
            'a dead action, is the way back in',
      );
    });
  });

  group('the ambient strip and the check-in (Story 2.5, FR-4, UX-DR22)', () {
    test(
      'the day\'s first opening reads with the check-in showing below '
      'the card — and nothing else about energy anywhere on the view',
      () async {
        final store = _RecordingStore();
        final view = await openSessionAndReadFirstDeal(store);
        expect(view.checkInShown, isTrue);
        expect(view.card, isNotNull);
        // Reading wrote nothing: the strip renders, it never writes.
        expect(
          store.entries.map((entry) => entry.kind),
          isNot(contains('energy_set')),
        );
      },
    );

    test('a baja tap with a card in progress: exactly one energy_set row, '
        'the strip gone for the day, the card finishable, and the NEXT '
        'deal instant-tier only', () async {
      final store = _RecordingStore();
      final dealt = await openSessionAndReadFirstDeal(store);
      final controller = buildFor(store);

      final after = await controller.setEnergy(EnergyLevel.low);

      // One row, the level's stable wire int, nothing bundled — the
      // check-in never deals a card.
      expect(
        store.entries.where((entry) => entry.kind == 'energy_set'),
        hasLength(1),
      );
      final row = store.entries.last;
      expect(row.kind, 'energy_set');
      expect(row.energyLevel, 2);
      expect(row.itemId, isNull);
      expect(row.instantUtcMicros, _fixedClock().microsecondsSinceEpoch);
      expect(row.id, matches(v7));
      expect(
        store.entries[store.entries.length - 2].kind,
        isNot('energy_set'),
        reason: 'exactly one row, never a batch',
      );

      // The standing card stays the view — finishable, never withdrawn.
      expect(after, isA<DispenserDealt>());
      expect((after as DispenserDealt).card.id, dealt.card.id);
      expect(
        after.checkInShown,
        isFalse,
        reason: 'answered — gone for the day',
      );

      // The filter applies to the next deal: the completion bundles an
      // instant-tier card under baja.
      await controller.complete(after);
      final nextDealRow = store.entries.last;
      expect(nextDealRow.kind, 'card_dealt');
      final catalogue = await shippedCatalogue();
      final nextSize = catalogue.entries
          .firstWhere((entry) => entry.id == nextDealRow.itemId)
          .size;
      expect(nextSize, Size.instant);
    });

    test('a media or an explicit llena tap lands its row and changes no '
        'pool — only baja narrows', () async {
      for (final (level, wire) in [
        (EnergyLevel.medium, 1),
        (EnergyLevel.full, 0),
      ]) {
        final store = _RecordingStore();
        await openSessionAndReadFirstDeal(store);
        final controller = buildFor(store);

        final after = await controller.setEnergy(level);

        final row = store.entries.last;
        expect(row.kind, 'energy_set');
        expect(row.energyLevel, wire);
        expect(after.checkInShown, isFalse);
        // The pool is unchanged: the next deal is the standing card's
        // own successor at the ordinary tier, never narrowed.
        await controller.complete(after as DispenserDealt);
        final catalogue = await shippedCatalogue();
        final nextSize = catalogue.entries
            .firstWhere((entry) => entry.id == store.entries.last.itemId)
            .size;
        expect(
          nextSize,
          isNot(Size.instant),
          reason:
              'media filters nothing, and an explicit llena is the '
              'default made visible',
        );
      }
    });

    test('a failing setEnergy append rethrows, lands nothing, and the '
        'strip stands — the retry is the same tap (matrix: failing '
        'append)', () async {
      final inner = _RecordingStore();
      await openSessionAndReadFirstDeal(inner);
      final failing = _FailNextAppendStore(inner);
      final controller = buildFor(failing);

      failing.failNextAppend = true;
      await expectLater(
        controller.setEnergy(EnergyLevel.low),
        throwsA(isA<StateError>()),
      );
      expect(
        inner.entries.where((entry) => entry.kind == 'energy_set'),
        isEmpty,
        reason: 'nothing landed on the failed write',
      );
      // The observable outcome the matrix names: nothing landed, so a
      // fresh read re-resolves the day unanswered — the strip stands.
      final standing = await controller.read();
      expect(
        standing.checkInShown,
        isTrue,
        reason: 'the failed write changed nothing the derivation reads',
      );

      // The recovered chain lands the retry, and the day resolves.
      final view = await controller.setEnergy(EnergyLevel.low);
      expect(
        inner.entries.where((entry) => entry.kind == 'energy_set'),
        hasLength(1),
      );
      expect(view.checkInShown, isFalse);
    });

    test('an energy answer and dismissal honor their tap-time day across '
        '04:00', () async {
      var now = DateTime.utc(2026, 8, 29, 12);
      final tappedAt = now;
      final answerStore = _RecordingStore();
      await openSessionAndReadFirstDeal(answerStore);
      final answering = buildFor(answerStore, nowOf: () => now);

      now = DateTime.utc(2026, 8, 30, 5);
      await answering.setEnergy(EnergyLevel.low, tappedAt: tappedAt);
      expect(
        answerStore.entries.last.instantUtcMicros,
        tappedAt.microsecondsSinceEpoch,
      );

      final dismissalStore = _RecordingStore();
      await openSessionAndReadFirstDeal(dismissalStore);
      now = DateTime.utc(2026, 8, 29, 12);
      final dismissing = buildFor(dismissalStore, nowOf: () => now);
      now = DateTime.utc(2026, 8, 30, 5);
      await dismissing.dismissCheckIn(tapTime: tappedAt);
      now = tappedAt;
      expect(
        (await dismissing.read()).checkInShown,
        isFalse,
        reason: 'the marker belongs to the day on which the user tapped ✕',
      );
    });

    test('the ✕ dismissal writes nothing and hides the strip for the '
        'rest of the opening; a later same-day opening hides it by the '
        'derivation alone (matrix: dismissal, re-open)', () async {
      final store = _RecordingStore();
      await openSessionAndReadFirstDeal(store);
      final controller = buildFor(store);

      final dismissed = await controller.dismissCheckIn();

      expect(store.entries.map((entry) => entry.kind).toList(), [
        'app_opened',
        'session_started',
        'card_dealt',
      ], reason: 'a dismissal appends nothing at all');
      expect(dismissed.checkInShown, isFalse);
      expect(
        (await controller.read()).checkInShown,
        isFalse,
        reason: 'hidden for the rest of the opening',
      );

      // The opening ends; a second open lands its own app_opened — the
      // derivation itself says not due now, never styled as anything.
      await SessionController(
        store: store,
        strings: AppStringsEs(),
        bundle: _FakeBundle({catalogueAssetPath: shipped}),
        nowOf: _fixedClock,
      ).handleSessionEnd();
      await SessionController(
        store: store,
        strings: AppStringsEs(),
        bundle: _FakeBundle({catalogueAssetPath: shipped}),
        nowOf: _fixedClock,
      ).handleAppOpen();
      final reopened = await controller.read();
      expect(
        reopened.checkInShown,
        isFalse,
        reason:
            'a second app_opened row today — the first opening was '
            'consumed, whatever the shell state holds',
      );
    });

    test('a session crossing 04:00 with no app_opened in the '
        'crossed-into day: the next resolution is that day\'s first '
        'opening — shown once (matrix: crossing)', () async {
      final store = _RecordingStore()
        ..entries.addAll([
          _moment('app_opened', DateTime.utc(2026, 8, 28, 23), 'crossing-open'),
          _moment(
            'session_started',
            DateTime.utc(2026, 8, 28, 23, 0, 1),
            'crossing-start',
          ),
        ]);
      final controller = buildFor(
        store,
        nowOf: () => DateTime.utc(2026, 8, 29, 5),
      );
      expect((await controller.read()).checkInShown, isTrue);

      // Answered during the crossing: the crossed-into day is done.
      final answered = await controller.setEnergy(EnergyLevel.low);
      expect(answered.checkInShown, isFalse);
      expect((await controller.read()).checkInShown, isFalse);
    });

    test('a prior-day session dangling unended: the relaunch\'s lone '
        'app_opened is not a first opening (kill-during-crossing)', () async {
      final store = _RecordingStore()
        ..entries.addAll([
          _moment('app_opened', DateTime.utc(2026, 8, 28, 23), 'killed-open'),
          _moment(
            'session_started',
            DateTime.utc(2026, 8, 28, 23, 0, 1),
            'killed-start',
          ),
        ]);
      final controller = buildFor(store);
      // The relaunch mints the crossing reveal: app_opened lands in
      // today as its first row, and the dangling start betrays the
      // opening already underway.
      await SessionController(
        store: store,
        strings: AppStringsEs(),
        bundle: _FakeBundle({catalogueAssetPath: shipped}),
        nowOf: _fixedClock,
      ).handleAppOpen();
      expect((await controller.read()).checkInShown, isFalse);
    });

    test('a baja day with the instant tier spent behind an elapsed '
        'pocket closes with no continue — the derived level reaches the '
        'probe through the seam (FR-4, Story 2.5)', () async {
      final store = _RecordingStore();
      // The baja row, answered at the day's first opening.
      store.entries.add((
        id: 'seed-baja',
        kind: 'energy_set',
        instantUtcMicros: DateTime.utc(2026, 8, 29, 10).microsecondsSinceEpoch,
        offsetSeconds: 0,
        itemId: null,
        itemOrigin: null,
        stack: null,
        settingKey: null,
        settingValue: null,
        pocketMinutes: null,
        energyLevel: 2,
      ));
      // A 60-pocket sitting opened at 11:00: elapsed exactly at the
      // fixed 12:00 clock, while one +15 acceptance could still lift
      // the deadline to 12:15 — the probe, not the window, decides.
      store.entries.add((
        id: 'seed-pocket-60',
        kind: 'session_started',
        instantUtcMicros: DateTime.utc(2026, 8, 29, 11).microsecondsSinceEpoch,
        offsetSeconds: 0,
        itemId: null,
        itemOrigin: null,
        stack: null,
        settingKey: null,
        settingValue: null,
        pocketMinutes: 60,
        energyLevel: null,
      ));
      // The day's whole instant tier spent inside the sitting: five
      // dealt-and-answered habits, as the launch lifecycle would have
      // left them (ids from the shipped asset, never invented).
      final catalogue = await shippedCatalogue();
      final instantIds = [
        for (final entry in catalogue.entries)
          if (entry.size == Size.instant) entry.id,
      ].take(5).toList();
      expect(instantIds, hasLength(5));
      for (final (index, id) in instantIds.indexed) {
        final minute = 1 + index;
        store.entries.add(
          _act(
            'card_dealt',
            DateTime.utc(2026, 8, 29, 11, minute),
            'spent-deal-$index',
            id,
          ),
        );
        store.entries.add(
          _act(
            'card_done',
            DateTime.utc(2026, 8, 29, 11, minute, 30),
            'spent-done-$index',
            id,
          ),
        );
      }

      final view = await buildFor(store).read();

      expect(view, isA<DispenserClosed>());
      final close = view as DispenserClosed;
      expect(close.pocketMinutes, 60);
      expect(
        close.continueOffered,
        isFalse,
        reason:
            'the pocket elapsed and one interval could still reach, '
            'but the probe finds nothing the baja day may deal — the '
            'chunk and upkeep fall to the 60 s ceiling and the instant '
            'draws are spent',
      );
    });

    test('a dismissal is skip-for-today and no further: the next day\'s '
        'first opening shows the check-in again (FR-4, matrix: day '
        'boundary)', () async {
      var now = DateTime.utc(2026, 8, 29, 12);
      final store = _RecordingStore();
      final session = SessionController(
        store: store,
        strings: AppStringsEs(),
        bundle: _FakeBundle({catalogueAssetPath: shipped}),
        nowOf: () => now,
      );
      final controller = buildFor(store, nowOf: () => now);

      // Day 1: the launch, the strip, the ✕.
      await session.handleAppOpen();
      expect((await controller.read()).checkInShown, isTrue);
      await controller.dismissCheckIn();
      expect(
        (await controller.read()).checkInShown,
        isFalse,
        reason: 'skip-for-today holds across every read of the day',
      );

      // The day turns: the sitting closes before the boundary, the new
      // day's open lands its own app_opened — and the strip returns.
      await session.handleSessionEnd();
      now = DateTime.utc(2026, 8, 30, 9);
      await session.handleAppOpen();
      expect(
        (await controller.read()).checkInShown,
        isTrue,
        reason:
            'the dismissal keyed the old day alone; the new day '
            'starts clean and its first opening is due',
      );
    });
  });
}

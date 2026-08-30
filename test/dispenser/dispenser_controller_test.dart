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

  group('the pocket declaration (Story 2.2, FR-8, AD-19)', () {
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
}

// The Dispenser write path's contract (Story 1.9): `complete(dealt)`
// appends the `card_done` row and the bundled next `card_dealt` — one
// minted instant for the batch, a v7 id per row, the command's
// `bagMinutes`/energy defaults; the day's last completion appends the
// answer row alone; a rapid second `complete` reads the post-answer log
// and the core guard appends nothing; a failing append rethrows while
// the serialization chain recovers — the I/O matrix's write rows,
// pinned against the shipped catalogue bytes.
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

/// A store whose log reads fail exactly once, and only once a
/// `card_done` has landed — the post-write refresh's read fails while
/// the write itself succeeded (the transient the foreground heal
/// covers). Reads delegate to the inner recording store otherwise.
class _GatedBundledDealStore implements StorePort {
  _GatedBundledDealStore(this._inner, this._gate);

  final _RecordingStore _inner;
  final Future<void> _gate;
  var _seenDone = false;

  @override
  Future<void> appendPoolFact(PoolFactRecord fact) async {}

  @override
  Future<void> appendLogEntry(LogEntryRecord entry) async {
    if (entry.kind == 'card_done') {
      _seenDone = true;
    }
    if (_seenDone && entry.kind == 'card_dealt') {
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
);

LogEntryRecord _act(String kind, DateTime at, String id, String itemId) => (
  id: id,
  kind: kind,
  instantUtcMicros: at.microsecondsSinceEpoch,
  offsetSeconds: 0,
  itemId: itemId,
  itemOrigin: Origin.shipped,
  stack: null,
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
}

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
import 'package:core/derive/quarantine.dart';
import 'package:core/derive/strip.dart';
import 'package:core/energy/energy.dart';
import 'package:core/log/log_entry.dart';
import 'package:core/pool/pool_fact.dart';
import 'package:core/ports/no_slicer_cause.dart';
import 'package:core/ports/slicer_port.dart';
import 'package:core/ports/store_port.dart';
import 'package:core/weave/weave.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:organizer/catalogue/catalogue_names.g.dart';
import 'package:organizer/catalogue/loader.dart';
import 'package:organizer/dispenser/dispenser_controller.dart';
import 'package:organizer/session/session_controller.dart';
import 'package:organizer/session/log_write_queue.dart';
import 'package:organizer/strings/app_strings_es.dart';

/// The recording store (the session suite's own contract): appends land
/// in order and every read replays them. Since Story 3.3 it also carries
/// a seeded pool-fact snapshot, so the write paths read captures beside
/// the log exactly as the real store would.
class _RecordingStore implements StorePort {
  _RecordingStore([this.facts = const []]);

  final List<LogEntryRecord> entries = [];
  final List<PoolFactRecord> facts;
  var writeCalls = 0;

  @override
  Future<void> appendPoolFact(PoolFactRecord fact) async {
    writeCalls++;
  }

  @override
  Future<void> appendLogEntry(LogEntryRecord entry) async {
    writeCalls++;
    entries.add(entry);
  }

  @override
  Future<List<PoolFactRecord>> readPoolFacts() async =>
      List.unmodifiable(facts);

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

/// A store delegating every port call to handed-in closures — the
/// seasonal group's fail-one-append arm over a facts-carrying store
/// (`_FailNextAppendStore` reads no facts, so it cannot host a dormant
/// Epic seed).
class _DelegatingStore implements StorePort {
  _DelegatingStore({
    required this._appendLogEntry,
    required this._readLogEntries,
    required this._readPoolFacts,
  });

  final Future<void> Function(LogEntryRecord entry) _appendLogEntry;
  final Future<List<LogEntryRecord>> Function() _readLogEntries;
  final Future<List<PoolFactRecord>> Function() _readPoolFacts;

  @override
  Future<void> appendPoolFact(PoolFactRecord fact) async {}

  @override
  Future<void> appendLogEntry(LogEntryRecord entry) => _appendLogEntry(entry);

  @override
  Future<List<PoolFactRecord>> readPoolFacts() => _readPoolFacts();

  @override
  Future<List<LogEntryRecord>> readLogEntries() => _readLogEntries();
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

/// A store whose first `card_done` append throws once, after letting
/// the `item_triaged` append through — the destination act's mid-batch
/// failure row (Story 6.4): the triage row lands, the completion
/// throws, and the re-entry retry appends a second triage row beside
/// the orphan (the tolerated partial-act exposure).
class _FailAfterTriageStore implements StorePort {
  _FailAfterTriageStore(this._inner);

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
  Future<List<PoolFactRecord>> readPoolFacts() async => _inner.readPoolFacts();

  @override
  Future<List<LogEntryRecord>> readLogEntries() async =>
      _inner.readLogEntries();
}

/// A store whose first `item_triaged` append throws once, after letting
/// a `box_created` append through — the quarantine act's mid-batch
/// failure row BETWEEN the box and its triage row (Story 6.5): the box
/// row lands, the triage append throws, and the orphan box
/// reconstructs as an honest empty box (the tolerated partial-act
/// exposure's other half).
class _FailAfterBoxStore implements StorePort {
  _FailAfterBoxStore(this._inner);

  final _RecordingStore _inner;
  var _seenBox = false;
  var _thrown = false;

  @override
  Future<void> appendPoolFact(PoolFactRecord fact) async {}

  @override
  Future<void> appendLogEntry(LogEntryRecord entry) async {
    if (entry.kind == 'box_created') {
      _seenBox = true;
    }
    if (_seenBox && !_thrown && entry.kind == 'item_triaged') {
      _thrown = true;
      throw StateError('append failed');
    }
    await _inner.appendLogEntry(entry);
  }

  @override
  Future<List<PoolFactRecord>> readPoolFacts() async => _inner.readPoolFacts();

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

/// The week a Saturday 2026-08-29 read judges due (the week anchored
/// Monday 2026-08-17 — its Sunday, the 23rd, has arrived) and the week
/// Sunday 2026-08-30 asks about (the running week, anchored Monday
/// 2026-08-24), as `Week.weekOrdinal`s — the seed rows' keys.
const weekOfAug17 = 1389;
const weekOfAug24 = 1390;
const weekOfAug31 = 1391;

/// A `report_answered` row closing [week] — the 2-5 group's seed: with
/// the report's own week answered, Saturday's read owes no report and
/// every 2.5 pin holds exactly as shipped, the mechanical translation
/// part 3 records.
LogEntryRecord _answeredWeek(int week, String id) => (
  id: id,
  kind: 'report_answered',
  instantUtcMicros: DateTime.utc(2026, 8, 23, 12).microsecondsSinceEpoch,
  offsetSeconds: 0,
  itemId: null,
  itemOrigin: null,
  stack: null,
  settingKey: null,
  settingValue: null,
  settingTextValue: null,
  pocketMinutes: null,
  energyLevel: null,
  reportValue: 3,
  reportWeek: week,
  permission: null,
  sliceCause: null,
  cluster: null,
  enabled: null,
  triageDestination: null,
  triageVolumeTag: null,
  triageBoxId: null,
  beforeName: null,
  afterName: null,
);

/// An install-day `app_opened` — a row from the day before the fixed
/// Saturday clock, seeding an ESTABLISHED install (the 5.12
/// translation the 2.5/2.6 groups take): with an opening on any
/// earlier day in the log, the once-ever first-run curation offer is
/// not eligible, so the check-in and report matrices keep resolving
/// exactly as they shipped — the `_answeredWeek` precedent, one
/// story on. 20:00 keeps it inside 48 h of every later read, so the
/// warm-return derivation stays out of the pin.
LogEntryRecord _installOpen() =>
    _moment('app_opened', DateTime.utc(2026, 8, 28, 20), 'install-open');

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
  cluster: null,
  enabled: null,
  triageDestination: null,
  triageVolumeTag: null,
  triageBoxId: null,
  beforeName: null,
  afterName: null,
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
  cluster: null,
  enabled: null,
  triageDestination: null,
  triageVolumeTag: null,
  triageBoxId: null,
  beforeName: null,
  afterName: null,
);

LogEntryRecord _pocketedStart(DateTime at, int minutes) => (
  id: 'pocket-${at.microsecondsSinceEpoch}',
  kind: 'session_started',
  instantUtcMicros: at.microsecondsSinceEpoch,
  offsetSeconds: 0,
  itemId: null,
  itemOrigin: null,
  stack: null,
  settingKey: null,
  settingValue: null,
  settingTextValue: null,
  pocketMinutes: minutes,
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
  beforeName: null,
  afterName: null,
);

const chunkSeedId = 'pasar-la-aspiradora-a-la-cocina';

/// A store that records what the rescue path mints (Story 4.6): the
/// step facts beside the rows — the recording contract the story-3.3
/// store grew for exactly this landing.
class _FactRecordingStore implements StorePort {
  final List<LogEntryRecord> entries = [];
  final List<PoolFactRecord> facts = [];

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

/// The Slicer seam's steerable stub (Story 4.6): one outcome per
/// construction, every request recorded — the port's own contract, no
/// provider named anywhere near the Dispenser.
class _StubSlicer implements SlicerPort {
  _StubSlicer(this.outcome);

  final SlicerOutcome outcome;
  final List<RescueSliceRequest> requests = [];

  @override
  Future<SlicerOutcome> slice(SlicerRequest request) async {
    requests.add(request as RescueSliceRequest);
    return outcome;
  }
}

/// A slicer that breaks the port's outcome-only promise and throws —
/// the fold's own test seam (Story 4.6's review round).
class _ThrowingSlicer implements SlicerPort {
  _ThrowingSlicer(this.error);

  final Object error;

  @override
  Future<SlicerOutcome> slice(SlicerRequest request) => throw error;
}

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
      beforeName: null,
      afterName: null,
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
          settingTextValue: null,
          pocketMinutes: 1,
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
          beforeName: null,
          afterName: null,
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

    test('pausing an open session that completed a group step stashes the '
        'session milestone — the space with the completion, spent once '
        '(Story 7.1, FR-17)', () async {
      final landing = DateTime.utc(2026, 8, 29, 9);
      final store =
          _RecordingStore([
              (
                id: 'step-1',
                origin: Origin.cloud,
                size: Size.maintenance,
                instantUtcMicros: landing.microsecondsSinceEpoch,
                offsetSeconds: 0,
                originContext: 'Un rinc\u00f3n con cajas',
                dictated: null,
                rescueOf: null,
                estimateSeconds: 240,
                stepText: 'Recoger una caja',
              ),
              (
                id: 'step-2',
                origin: Origin.cloud,
                size: Size.maintenance,
                instantUtcMicros: landing.microsecondsSinceEpoch,
                offsetSeconds: 0,
                originContext: 'Un rinc\u00f3n con cajas',
                dictated: null,
                rescueOf: null,
                estimateSeconds: 240,
                stepText: 'Apilar las cajas',
              ),
            ])
            ..entries.addAll([
              _moment(
                'session_started',
                DateTime.utc(2026, 8, 29, 11),
                's-open',
              ),
              _act(
                'epic_activated',
                DateTime.utc(2026, 8, 29, 11, 0, 1),
                'e-1',
                'step-1',
              ),
              _act(
                'card_dealt',
                DateTime.utc(2026, 8, 29, 11, 0, 2),
                'd-1',
                'step-1',
              ),
              _act(
                'card_done',
                DateTime.utc(2026, 8, 29, 11, 0, 3),
                'done-1',
                'step-1',
              ),
            ]);
      final controller = buildFor(store);
      await controller.pause();

      final milestone = controller.takeUnfiredReward();
      expect(milestone, isNotNull);
      expect(milestone!.groupId, 'step-1');
      expect(milestone.origin, Origin.cloud);
      // Spent once: a second drain answers nothing, and the session's
      // end landed exactly one close row.
      expect(controller.takeUnfiredReward(), isNull);
      expect(
        store.entries.where((entry) => entry.kind == 'session_ended'),
        hasLength(1),
      );
    });

    test('pausing with no group completion stashes nothing — the session '
        'milestone needs a completed step of a slicer-origin space '
        '(Story 7.1)', () async {
      final store = _RecordingStore();
      await openSessionAndReadFirstDeal(store);
      final controller = buildFor(store);
      await controller.pause();
      expect(controller.takeUnfiredReward(), isNull);
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
        settingTextValue: null,
        pocketMinutes: pocketMinutes,
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
        beforeName: null,
        afterName: null,
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
        beforeName: null,
        afterName: null,
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
        beforeName: null,
        afterName: null,
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
          settingTextValue: null,
          pocketMinutes: 10,
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
          beforeName: null,
          afterName: null,
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
          beforeName: null,
          afterName: null,
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
        beforeName: null,
        afterName: null,
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
        final store = _RecordingStore()
          ..entries.add(_answeredWeek(weekOfAug17, 'seed-week-answered'))
          ..entries.add(_installOpen());
        final view = await openSessionAndReadFirstDeal(store);
        expect(view.stripResident, StripResident.energyCheckIn);
        expect(view.reportWeekOrdinal, isNull);
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
      final store = _RecordingStore()
        ..entries.add(_answeredWeek(weekOfAug17, 'seed-week-answered'))
        ..entries.add(_installOpen());
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
        after.stripResident,
        isNull,
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
        final store = _RecordingStore()
          ..entries.add(_answeredWeek(weekOfAug17, 'seed-week-answered'))
          ..entries.add(_installOpen());
        await openSessionAndReadFirstDeal(store);
        final controller = buildFor(store);

        final after = await controller.setEnergy(level);

        final row = store.entries.last;
        expect(row.kind, 'energy_set');
        expect(row.energyLevel, wire);
        expect(after.stripResident, isNull);
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
      final inner = _RecordingStore()
        ..entries.add(_answeredWeek(weekOfAug17, 'seed-week-answered'))
        ..entries.add(_installOpen());
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
        standing.stripResident,
        StripResident.energyCheckIn,
        reason: 'the failed write changed nothing the derivation reads',
      );

      // The recovered chain lands the retry, and the day resolves.
      final view = await controller.setEnergy(EnergyLevel.low);
      expect(
        inner.entries.where((entry) => entry.kind == 'energy_set'),
        hasLength(1),
      );
      expect(view.stripResident, isNull);
    });

    test('an energy answer and dismissal honor their tap-time day across '
        '04:00', () async {
      var now = DateTime.utc(2026, 8, 29, 12);
      final tappedAt = now;
      final answerStore = _RecordingStore()
        ..entries.add(_answeredWeek(weekOfAug17, 'seed-week-answered'))
        ..entries.add(_installOpen());
      await openSessionAndReadFirstDeal(answerStore);
      final answering = buildFor(answerStore, nowOf: () => now);

      now = DateTime.utc(2026, 8, 30, 5);
      await answering.setEnergy(EnergyLevel.low, tappedAt: tappedAt);
      expect(
        answerStore.entries.last.instantUtcMicros,
        tappedAt.microsecondsSinceEpoch,
      );

      final dismissalStore = _RecordingStore()
        ..entries.add(_answeredWeek(weekOfAug17, 'seed-week-answered'))
        ..entries.add(_installOpen());
      await openSessionAndReadFirstDeal(dismissalStore);
      now = DateTime.utc(2026, 8, 29, 12);
      final dismissing = buildFor(dismissalStore, nowOf: () => now);
      now = DateTime.utc(2026, 8, 30, 5);
      await dismissing.dismissCheckIn(tapTime: tappedAt);
      now = tappedAt;
      expect(
        (await dismissing.read()).stripResident,
        isNull,
        reason: 'the marker belongs to the day on which the user tapped ✕',
      );
    });

    test('the ✕ dismissal writes nothing and hides the strip for the '
        'rest of the opening; a later same-day opening hides it by the '
        'derivation alone (matrix: dismissal, re-open)', () async {
      final store = _RecordingStore()
        ..entries.add(_answeredWeek(weekOfAug17, 'seed-week-answered'))
        ..entries.add(_installOpen());
      await openSessionAndReadFirstDeal(store);
      final controller = buildFor(store);

      final kindsBefore = store.entries.map((entry) => entry.kind).toList();
      final dismissed = await controller.dismissCheckIn();

      expect(
        store.entries.map((entry) => entry.kind).toList(),
        kindsBefore,
        reason: 'a dismissal appends nothing at all',
      );
      expect(dismissed.stripResident, isNull);
      expect(
        (await controller.read()).stripResident,
        isNull,
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
        reopened.stripResident,
        isNull,
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
          _answeredWeek(weekOfAug17, 'seed-week-answered'),
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
      expect(
        (await controller.read()).stripResident,
        StripResident.energyCheckIn,
      );

      // Answered during the crossing: the crossed-into day is done.
      final answered = await controller.setEnergy(EnergyLevel.low);
      expect(answered.stripResident, isNull);
      expect((await controller.read()).stripResident, isNull);
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
      expect((await controller.read()).stripResident, isNull);
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
        settingTextValue: null,
        pocketMinutes: null,
        energyLevel: 2,
        reportValue: null,
        reportWeek: null,
        permission: null,
        sliceCause: null,
        cluster: null,
        enabled: null,
        triageDestination: null,
        triageVolumeTag: null,
        triageBoxId: null,
        beforeName: null,
        afterName: null,
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
        settingTextValue: null,
        pocketMinutes: 60,
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
        beforeName: null,
        afterName: null,
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
      final store = _RecordingStore()
        ..entries.add(_answeredWeek(weekOfAug17, 'seed-week-answered'))
        ..entries.add(_installOpen());
      final session = SessionController(
        store: store,
        strings: AppStringsEs(),
        bundle: _FakeBundle({catalogueAssetPath: shipped}),
        nowOf: () => now,
      );
      final controller = buildFor(store, nowOf: () => now);

      // Day 1: the launch, the strip, the ✕.
      await session.handleAppOpen();
      expect(
        (await controller.read()).stripResident,
        StripResident.energyCheckIn,
      );
      await controller.dismissCheckIn();
      expect(
        (await controller.read()).stripResident,
        isNull,
        reason: 'skip-for-today holds across every read of the day',
      );

      // The day turns: the sitting closes before the boundary, the new
      // day's open lands its own app_opened — and the strip returns.
      // (The new day is a Sunday: its own due week, 1390, is answered
      // by seed too, so what returns is the check-in and nothing
      // rarer — the 2.5 semantics, translated.)
      await session.handleSessionEnd();
      store.entries.add(_answeredWeek(weekOfAug24, 'seed-sunday-answered'));
      now = DateTime.utc(2026, 8, 30, 9);
      await session.handleAppOpen();
      expect(
        (await controller.read()).stripResident,
        StripResident.energyCheckIn,
        reason:
            'the dismissal keyed the old day alone; the new day '
            'starts clean and its first opening is due',
      );
    });
  });

  group('the weekly self-report and the deterministic slot handoff '
      '(Story 2.6, SM-2, FR-4)', () {
    /// Sunday 2026-08-30 12:00 — the spec's own matrix clock: the day
    /// the running week (1390, anchored Monday the 24th) closes and
    /// the report asks about it.
    DateTime sundayClock() => DateTime.utc(2026, 8, 30, 12);

    /// The Sunday launch: the lifecycle's open lands the day's one
    /// `app_opened` (plus the auto-open sitting and its first deal),
    /// and the controller over the same store reads from the settled
    /// log — the widget harness's shape, minus the screen. The store
    /// takes the established-install seed (the 5.12 translation): an
    /// opening on an earlier day keeps the once-ever offer out of
    /// these matrices, which are the report's own.
    Future<DispenserController> launchSunday(
      _RecordingStore store, {
      DateTime Function()? nowOf,
    }) async {
      store.entries.add(_installOpen());
      final clock = nowOf ?? sundayClock;
      await SessionController(
        store: store,
        strings: AppStringsEs(),
        bundle: _FakeBundle({catalogueAssetPath: shipped}),
        nowOf: clock,
      ).handleAppOpen();
      return buildFor(store, nowOf: clock);
    }

    test('Sunday\'s first opening holds the report: the due week 1390 '
        'rides the view, the check-in displaced — never consumed (SM-2, '
        'FR-4, matrix: Sunday first read)', () async {
      final store = _RecordingStore();
      final controller = await launchSunday(store);

      final view = await controller.read();

      expect(view, isA<DispenserDealt>());
      final dealt = view as DispenserDealt;
      expect(dealt.stripResident, StripResident.weeklySelfReport);
      expect(dealt.reportWeekOrdinal, weekOfAug24);
      expect(dealt.card, isNotNull);
      // The check-in is displaced, not consumed: no energy-shaped row
      // exists anywhere, and the day's energy still derives the llena
      // default — the handoff tests below hand the slot back the
      // moment the report clears it.
      expect(
        store.entries.where((entry) => entry.kind == 'energy_set'),
        isEmpty,
      );
    });

    test('the report and its asked week survive the closed and rest-offer '
        'view variants', () async {
      final closedStore = _RecordingStore()
        ..entries.addAll([
          _moment('app_opened', DateTime.utc(2026, 8, 29, 22), 'sat-open'),
          _moment(
            'session_started',
            DateTime.utc(2026, 8, 29, 22, 0, 1),
            'sat-start',
          ),
          _moment(
            'session_ended',
            DateTime.utc(2026, 8, 29, 22, 30),
            'sat-end',
          ),
        ]);
      final closed = await buildFor(
        closedStore,
        nowOf: () => DateTime.utc(2026, 8, 30, 5),
      ).read();
      expect(closed, isA<DispenserClosed>());
      expect(closed.stripResident, StripResident.weeklySelfReport);
      expect(closed.reportWeekOrdinal, weekOfAug24);

      final offerStore = _RecordingStore()
        ..entries.add(_installOpen())
        ..entries.addAll([
          _moment('app_opened', DateTime.utc(2026, 8, 30, 11, 19), 'sun-open'),
          (
            id: 'sun-pocket',
            kind: 'session_started',
            instantUtcMicros: DateTime.utc(
              2026,
              8,
              30,
              11,
              20,
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
            cluster: null,
            enabled: null,
            triageDestination: null,
            triageVolumeTag: null,
            triageBoxId: null,
            beforeName: null,
            afterName: null,
          ),
        ]);
      final offer = await buildFor(offerStore, nowOf: sundayClock).read();
      expect(offer, isA<DispenserRestOffer>());
      expect(offer.stripResident, StripResident.weeklySelfReport);
      expect(offer.reportWeekOrdinal, weekOfAug24);
    });

    test('a digit tap mid-opening lands exactly one report_answered row '
        'carrying the asked week, and the same opening\'s read hands the '
        'slot to the check-in (matrix: answer lands)', () async {
      final store = _RecordingStore();
      final controller = await launchSunday(store);
      final dealt = await controller.read() as DispenserDealt;
      final launchRows = store.entries.length;

      final after = await controller.answerReport(3);

      // One row, the tapped value beside the asked week, nothing
      // bundled — the report never deals a card.
      final rows = store.entries
          .where((entry) => entry.kind == 'report_answered')
          .toList();
      expect(rows, hasLength(1));
      expect(store.entries.length, launchRows + 1);
      final row = rows.single;
      expect(row.reportValue, 3);
      expect(row.reportWeek, weekOfAug24);
      expect(row.itemId, isNull);
      expect(row.instantUtcMicros, sundayClock().microsecondsSinceEpoch);
      expect(row.id, matches(v7));

      // The standing card stays the view; the same opening's read
      // hands the slot to the check-in — displaced, not consumed.
      expect(after, isA<DispenserDealt>());
      expect((after as DispenserDealt).card.id, dealt.card.id);
      expect(after.stripResident, StripResident.energyCheckIn);
      expect(after.reportWeekOrdinal, isNull);
      expect(
        (await controller.read()).stripResident,
        StripResident.energyCheckIn,
        reason: 'the handoff holds across the same opening\'s reads',
      );
    });

    test('the report\'s ✕ writes nothing, frees the slot for that '
        'opening alone — the check-in takes it — and the report hides '
        'for the rest of the opening (matrix: ✕ dismissal)', () async {
      final store = _RecordingStore();
      final controller = await launchSunday(store);
      await controller.read();
      final kindsBefore = store.entries.map((entry) => entry.kind).toList();

      final dismissed = await controller.dismissReport();

      expect(
        store.entries.map((entry) => entry.kind).toList(),
        kindsBefore,
        reason: 'a dismissal appends nothing at all',
      );
      expect(dismissed.stripResident, StripResident.energyCheckIn);
      expect(
        (await controller.read()).stripResident,
        StripResident.energyCheckIn,
        reason: 'hidden for this opening; the check-in holds the slot',
      );
    });

    test('a dismissal taken during a 04:00 crossing (opens = 0) re-arms '
        'when the day\'s app_opened lands: opens = 1 ≠ the marker, and '
        'the report re-offers at that first opening (matrix: re-arm at a '
        'crossing)', () async {
      // A Saturday sitting, closed before midnight: Sunday holds no
      // rows at all when the crossing read happens.
      final store = _RecordingStore()
        ..entries.addAll([
          _moment('app_opened', DateTime.utc(2026, 8, 29, 22), 'sat-open'),
          _moment(
            'session_started',
            DateTime.utc(2026, 8, 29, 22, 0, 1),
            'sat-start',
          ),
          _moment(
            'session_ended',
            DateTime.utc(2026, 8, 29, 22, 30),
            'sat-end',
          ),
        ]);
      var now = DateTime.utc(2026, 8, 30, 5);
      final controller = buildFor(store, nowOf: () => now);

      // The crossing read: no app_opened in Sunday yet, so this is the
      // day's first opening — and the due report holds it.
      expect(
        (await controller.read()).stripResident,
        StripResident.weeklySelfReport,
      );
      final dismissed = await controller.dismissReport();
      expect(
        dismissed.stripResident,
        StripResident.energyCheckIn,
        reason: 'the dismissal frees the slot for the crossing opening',
      );

      // The day's app_opened lands: the census grows past the marker's
      // 0, and the still-unanswered report re-offers at that opening.
      store.entries.add(
        _moment('app_opened', DateTime.utc(2026, 8, 30, 9), 'sun-open'),
      );
      now = DateTime.utc(2026, 8, 30, 9, 0, 30);
      final reoffered = await controller.read();
      expect(
        reoffered.stripResident,
        StripResident.weeklySelfReport,
        reason:
            'the marker is opening-scoped, never day-scoped — a new '
            'opening lifts the exclusion by itself',
      );
      expect(reoffered.reportWeekOrdinal, weekOfAug24);
    });

    test('the report\'s dismissal is skip-for-this-opening and no '
        'further: the next day\'s first opening offers the report again, '
        'never dismissed for the week (SM-2, matrix: day scope)', () async {
      var now = sundayClock();
      final store = _RecordingStore()..entries.add(_installOpen());
      final session = SessionController(
        store: store,
        strings: AppStringsEs(),
        bundle: _FakeBundle({catalogueAssetPath: shipped}),
        nowOf: () => now,
      );
      final controller = buildFor(store, nowOf: () => now);

      // Sunday: the report holds the slot; the ✕ frees it for the
      // opening alone.
      await session.handleAppOpen();
      expect(
        (await controller.read()).stripResident,
        StripResident.weeklySelfReport,
      );
      await controller.dismissReport();

      // Monday's first opening: the marker keyed Sunday alone, and the
      // week 1390 the Sunday closed is still the due week on Monday —
      // the report returns, unanswered week or not.
      await session.handleSessionEnd();
      now = DateTime.utc(2026, 8, 31, 9);
      await session.handleAppOpen();
      final reopened = await controller.read();
      expect(
        reopened.stripResident,
        StripResident.weeklySelfReport,
        reason:
            'a dismissal hides the report for one opening, never for '
            'the week — Monday\'s first opening asks again',
      );
      expect(reopened.reportWeekOrdinal, weekOfAug24);
    });

    test('a same-day second app_opened lifts the marker\'s exclusion — '
        'and the derivation hides the report anyway: the first-opening '
        'gate owns the rest of the day, and the next day\'s first '
        'opening asks again (FR-4, SM-2, the marker/derivation '
        'layering)', () async {
      var now = sundayClock();
      final store = _RecordingStore()..entries.add(_installOpen());
      final session = SessionController(
        store: store,
        strings: AppStringsEs(),
        bundle: _FakeBundle({catalogueAssetPath: shipped}),
        nowOf: () => now,
      );
      final controller = buildFor(store, nowOf: () => now);

      // Sunday's first opening: the report holds the slot; the ✕
      // frees it for the opening alone, marker (day, opens: 1).
      await session.handleAppOpen();
      expect(
        (await controller.read()).stripResident,
        StripResident.weeklySelfReport,
      );
      await controller.dismissReport();

      // A second same-day app_opened lands: the census grows past the
      // marker, so the exclusion lifts on its own — and the report
      // stays hidden anyway, because the derivation's first-opening
      // gate now owns the day (the opening was consumed). The layering
      // is the pin: the marker lifted, the derivation hid.
      await session.handleSessionEnd();
      now = DateTime.utc(2026, 8, 30, 15);
      await session.handleAppOpen();
      final sameDay = await controller.read();
      expect(
        sameDay.stripResident,
        isNull,
        reason:
            'the marker no longer excludes the report (opens 2 ≠ 1) '
            'and still nothing shows — the consumed opening is the '
            'derivation\'s fact, not the shell\'s',
      );

      // The next day's first opening: a new `Day`, a fresh opening —
      // and the still-unanswered week asks again.
      await session.handleSessionEnd();
      now = DateTime.utc(2026, 8, 31, 9);
      await session.handleAppOpen();
      final nextDay = await controller.read();
      expect(
        nextDay.stripResident,
        StripResident.weeklySelfReport,
        reason:
            'the new day starts clean — the marker and the consumed '
            'opening both keyed Sunday alone',
      );
      expect(nextDay.reportWeekOrdinal, weekOfAug24);
    });

    test('refusal is silence: a value outside the scale or a null asked '
        'week writes nothing, and the fresh read returns the report '
        '(matrix: refusal guard)', () async {
      final store = _RecordingStore();
      final controller = await launchSunday(store);
      expect(
        (await controller.read()).stripResident,
        StripResident.weeklySelfReport,
      );

      // Out of scale: the minter refuses, nothing lands, no error
      // surface exists anywhere to reach.
      final after = await controller.answerReport(9);
      expect(
        store.entries.where((entry) => entry.kind == 'report_answered'),
        isEmpty,
      );
      expect(
        after.stripResident,
        StripResident.weeklySelfReport,
        reason: 'the week was not answered — the report stands',
      );

      // A null asked week: a controller whose reads never showed the
      // report mints nothing at all.
      final silentStore = _RecordingStore();
      await launchSunday(silentStore);
      final unread = buildFor(silentStore);
      await unread.answerReport(3);
      expect(
        silentStore.entries.where((entry) => entry.kind == 'report_answered'),
        isEmpty,
      );
      expect(
        (await unread.read()).stripResident,
        StripResident.weeklySelfReport,
      );
    });

    test('a failing answerReport append rethrows, lands nothing, and '
        'the report still stands — the retry is the same tap (matrix: '
        'failed append)', () async {
      final inner = _RecordingStore();
      await launchSunday(inner);
      final failing = _FailNextAppendStore(inner);
      final controller = buildFor(failing, nowOf: sundayClock);
      // The showing read runs through the answering controller: the
      // asked week is a controller field, established by ITS read.
      expect(
        (await controller.read()).stripResident,
        StripResident.weeklySelfReport,
      );

      failing.failNextAppend = true;
      await expectLater(controller.answerReport(3), throwsA(isA<StateError>()));
      expect(
        inner.entries.where((entry) => entry.kind == 'report_answered'),
        isEmpty,
        reason: 'nothing landed on the failed write',
      );
      final standing = await controller.read();
      expect(
        standing.stripResident,
        StripResident.weeklySelfReport,
        reason: 'the failed write changed nothing the derivation reads',
      );

      // The recovered chain lands the retry, and the week resolves
      // with the same-opening handoff.
      final done = await controller.answerReport(3);
      expect(
        inner.entries.where((entry) => entry.kind == 'report_answered'),
        hasLength(1),
      );
      expect(done.stripResident, StripResident.energyCheckIn);
    });

    test('a tap landing past the 04:00 boundary answers the asked week: '
        'the row\'s instant is the tap\'s, its week the view carried '
        '(AD-21, matrix: tap across 04:00)', () async {
      final store = _RecordingStore();
      final controller = await launchSunday(store);
      expect(
        (await controller.read()).stripResident,
        StripResident.weeklySelfReport,
      );

      // The view committed inside Sunday; the tap lands Monday, past
      // the boundary — the row describes the tap, and answers the week
      // the user was asked.
      final tap = DateTime.utc(2026, 8, 31, 5);
      await controller.answerReport(4, tappedAt: tap);

      final row = store.entries.singleWhere(
        (entry) => entry.kind == 'report_answered',
      );
      expect(row.instantUtcMicros, tap.microsecondsSinceEpoch);
      expect(row.reportWeek, weekOfAug24);
      expect(row.reportValue, 4);
    });

    test('supersession, not accumulation: a foreign-week answer counts '
        'for nothing, and the unanswered week is superseded at the next '
        'Sunday (SM-2, matrix: supersession)', () async {
      // Saturday 23:00: the 1389 report — unanswered since its own
      // Sunday — holds the slot at the day's first opening. The
      // install seed keeps the once-ever offer out of the matrices.
      final store = _RecordingStore()
        ..entries.add(_installOpen())
        ..entries.addAll([
          _moment('app_opened', DateTime.utc(2026, 8, 29, 22), 'sat-open'),
          _moment(
            'session_started',
            DateTime.utc(2026, 8, 29, 22, 0, 1),
            'sat-start',
          ),
          _moment(
            'session_ended',
            DateTime.utc(2026, 8, 29, 22, 30),
            'sat-end',
          ),
        ]);
      var now = DateTime.utc(2026, 8, 29, 23);
      final controller = buildFor(store, nowOf: () => now);
      final saturday = await controller.read();
      expect(saturday.stripResident, StripResident.weeklySelfReport);
      expect(
        saturday.reportWeekOrdinal,
        weekOfAug17,
        reason: 'the week the Saturday read was asking is 1389',
      );

      // The tap lands across the boundary, on Sunday — where the
      // derivation now offers 1390. The row answers what was asked.
      final tap = DateTime.utc(2026, 8, 30, 5);
      await controller.answerReport(2, tappedAt: tap);
      final row = store.entries.singleWhere(
        (entry) => entry.kind == 'report_answered',
      );
      expect(row.reportWeek, weekOfAug17);
      expect(row.instantUtcMicros, tap.microsecondsSinceEpoch);

      // Sunday's read: 1389's answer is a foreign week — quiet, never
      // a match — and 1390 stands due at most once, the new week's
      // report taking the slot.
      now = DateTime.utc(2026, 8, 30, 9);
      final sunday = await controller.read();
      expect(sunday.stripResident, StripResident.weeklySelfReport);
      expect(sunday.reportWeekOrdinal, weekOfAug24);

      // And week 1390 unanswered into Sunday 2026-09-06: the due week
      // is 1391 — superseded, never accumulated.
      final nextStore = _RecordingStore()..entries.add(_installOpen());
      final nextSundayClock = DateTime.utc(2026, 9, 6, 12);
      await SessionController(
        store: nextStore,
        strings: AppStringsEs(),
        bundle: _FakeBundle({catalogueAssetPath: shipped}),
        nowOf: () => nextSundayClock,
      ).handleAppOpen();
      final nextController = buildFor(nextStore, nowOf: () => nextSundayClock);
      final nextSunday = await nextController.read();
      expect(nextSunday.stripResident, StripResident.weeklySelfReport);
      expect(
        nextSunday.reportWeekOrdinal,
        weekOfAug31,
        reason:
            'the Sunday the 1390 week closed into has passed — at most '
            'one report is ever asked, the newest week\'s',
      );
    });

    test('a day that ends with the report unresolved owes the check-in '
        'nothing: energy carries the llena default and the pool never '
        'narrows (FR-4, matrix: check-in never shown)', () async {
      final store = _RecordingStore();
      final controller = await launchSunday(store);
      final dealt = await controller.read() as DispenserDealt;
      expect(dealt.stripResident, StripResident.weeklySelfReport);

      // The report holds every read of the opening; no energy row can
      // exist. The card is answered anyway — and the bundled next deal
      // is ordinary-tier, the llena default carrying the day.
      await controller.complete(dealt);
      final stillHolding = await controller.read();
      expect(
        stillHolding.stripResident,
        StripResident.weeklySelfReport,
        reason: 'unanswered — the report keeps holding the slot',
      );
      final catalogue = await shippedCatalogue();
      final nextDealRow = store.entries.lastWhere(
        (entry) => entry.kind == 'card_dealt',
      );
      final nextSize = catalogue.entries
          .firstWhere((entry) => entry.id == nextDealRow.itemId)
          .size;
      expect(
        nextSize,
        isNot(Size.instant),
        reason:
            'the check-in never shown means the 🟢 default, never a '
            'narrowed pool — the day owes nothing',
      );
    });
  });

  group('the once-ever first-run curation offer (Story 5.12, FR-31, '
      'UX-DR22)', () {
    /// A fresh install's Saturday launch — no seed rows at all, so the
    /// log's only `app_opened` is today's and the first opening EVER
    /// is underway.
    Future<DispenserController> launchFreshInstall(
      _RecordingStore store,
    ) async {
      await SessionController(
        store: store,
        strings: AppStringsEs(),
        bundle: _FakeBundle({catalogueAssetPath: shipped}),
        nowOf: _fixedClock,
      ).handleAppOpen();
      return buildFor(store);
    }

    test('the first opening ever reads with the offer showing below '
        'the card — rarest wins, the report and the check-in both '
        'displaced (matrix: fresh install)', () async {
      final store = _RecordingStore();
      final controller = await launchFreshInstall(store);

      final view = await controller.read();

      expect(view, isA<DispenserDealt>());
      expect(view.stripResident, StripResident.firstRunCuration);
      expect(view.reportWeekOrdinal, isNull);
      // Reading wrote nothing — the offer renders, it never writes.
      expect(
        store.entries.where((entry) => entry.kind == 'energy_set'),
        isEmpty,
      );
      expect(
        store.entries.where((entry) => entry.kind == 'report_answered'),
        isEmpty,
      );
    });

    test('the ✕ writes zero rows and excludes the offer on every later '
        'read of the process — the displaced instruments take the freed '
        'slot (matrix: dismiss the offer)', () async {
      final store = _RecordingStore();
      final controller = await launchFreshInstall(store);
      await controller.read();
      final kindsBefore = store.entries.map((entry) => entry.kind).toList();

      final dismissed = await controller.dismissCurationOffer();

      expect(
        store.entries.map((entry) => entry.kind).toList(),
        kindsBefore,
        reason: 'a dismissal appends nothing at all',
      );
      expect(dismissed.stripResident, StripResident.weeklySelfReport);
      expect(
        (await controller.read()).stripResident,
        StripResident.weeklySelfReport,
        reason: 'excluded for the process, the report holding the slot',
      );
    });

    test('the tap consumes with the same zero rows — consume and '
        'dismiss are the same terminal path', () async {
      final store = _RecordingStore()
        ..entries.add(_answeredWeek(weekOfAug17, 'seed-week-answered'));
      final controller = await launchFreshInstall(store);
      await controller.read();
      final kindsBefore = store.entries.map((entry) => entry.kind).toList();

      final consumed = await controller.consumeCurationOffer();

      expect(
        store.entries.map((entry) => entry.kind).toList(),
        kindsBefore,
        reason: 'the accept path appends nothing either',
      );
      expect(
        consumed.stripResident,
        StripResident.energyCheckIn,
        reason:
            'the offer excluded — the check-in takes the slot in the '
            'same opening, the 2.6 handoff grammar',
      );
    });

    test('any later opening never sees it again — a same-day reopen, a '
        'restart, a next-day first opening alike (matrix: any later '
        'opening; never returns)', () async {
      var now = _fixedClock();
      final store = _RecordingStore()
        ..entries.add(_answeredWeek(weekOfAug17, 'seed-week-answered'));
      final session = SessionController(
        store: store,
        strings: AppStringsEs(),
        bundle: _FakeBundle({catalogueAssetPath: shipped}),
        nowOf: () => now,
      );
      final controller = buildFor(store, nowOf: () => now);

      await session.handleAppOpen();
      expect(
        (await controller.read()).stripResident,
        StripResident.firstRunCuration,
      );
      await controller.dismissCurationOffer();

      // A second opening the same day: the first opening was consumed
      // — the derivation alone hides the offer, never the marker.
      await session.handleSessionEnd();
      await session.handleAppOpen();
      expect(
        (await controller.read()).stripResident,
        isNull,
        reason: 'a second app_opened today — not the first opening',
      );

      // The next day's first opening: an `app_opened` from an earlier
      // day stands — history, so the offer is gone forever, and the
      // process-lifetime marker died with nothing to re-arm. (The new
      // day is a Sunday: its own due week, 1390, answered by seed too,
      // so what shows is the check-in and nothing rarer.)
      await session.handleSessionEnd();
      store.entries.add(_answeredWeek(weekOfAug24, 'seed-sunday-answered'));
      now = DateTime.utc(2026, 8, 30, 9);
      await session.handleAppOpen();
      final nextDay = buildFor(store, nowOf: () => now);
      expect(
        (await nextDay.read()).stripResident,
        StripResident.energyCheckIn,
        reason:
            'a FRESH process over the next day\'s log — no marker, and '
            'the offer still never returns: the earliest open is '
            'historical',
      );
    });
  });

  group('the seasonal suggestion (Story 5.13, FR-15, UX-DR22)', () {
    /// A dormant Epic's slice as a one-step pool-fact record — the
    /// scan-landing shape (cloud origin, no `rescueOf`, `stepText`
    /// set, the slice's shared description as Origin Context) with
    /// NO `epic_activated` row: dormancy by construction (5.9's
    /// derivation), seeded before any launch.
    PoolFactRecord dormantEpic(
      String stableId, {
      String description = 'el trastero del fondo',
      int at = 0,
    }) => (
      id: stableId,
      origin: Origin.cloud,
      size: sizeOfEstimateSeconds(180),
      instantUtcMicros:
          DateTime.utc(2026, 8, 20, 9).microsecondsSinceEpoch + at,
      offsetSeconds: 0,
      originContext: description,
      dictated: null,
      rescueOf: null,
      estimateSeconds: 180,
      stepText: 'Recoger las cajas',
    );

    _RecordingStore storeOfFacts(List<PoolFactRecord> facts) =>
        _RecordingStore(facts)
          ..entries.add(_answeredWeek(weekOfAug17, 'seed-week-answered'))
          ..entries.add(_installOpen());

    test('the day\'s first opening over a dormant Epic reads with the '
        'suggestion holding the slot — the shown record rides the view, '
        'and reading wrote nothing (matrix: first opening)', () async {
      final store = storeOfFacts([dormantEpic('s1')]);
      final dealt = await openSessionAndReadFirstDeal(store);
      final controller = buildFor(store);

      final view = await controller.read();

      expect(view.stripResident, StripResident.seasonalSuggestion);
      expect(view.seasonalSuggestion?.stableId, 's1');
      expect(view.seasonalSuggestion?.origin, Origin.cloud);
      expect(view.seasonalSuggestion?.description, 'el trastero del fondo');
      expect(view.reportWeekOrdinal, isNull);
      expect(view, isA<DispenserDealt>());
      expect(
        store.entries.where((entry) => entry.kind == 'suggestion_dismissed'),
        isEmpty,
        reason: 'the strip renders, it never writes on a read',
      );
      expect(dealt.card, isNotNull);
    });

    test('no dormant Epic — never eligible: the ordinary walk stands '
        '(matrix: no dormant)', () async {
      final store = _RecordingStore()..entries.add(_installOpen());
      await openSessionAndReadFirstDeal(store);
      final view = await buildFor(store).read();
      expect(view.stripResident, StripResident.weeklySelfReport);
      expect(view.seasonalSuggestion, isNull);
    });

    test('the ✕ writes exactly one suggestion_dismissed row naming the '
        'SHOWN project — the slot hands to the check-in in the same '
        'opening, and zero collateral rows exist (matrix: dismiss)', () async {
      final store = storeOfFacts([dormantEpic('s1')]);
      await openSessionAndReadFirstDeal(store);
      final controller = buildFor(store);
      await controller.read();
      final kindsBefore = store.entries.map((entry) => entry.kind).toList();

      final after = await controller.dismissSeasonalSuggestion();

      final rows = store.entries
          .where((entry) => entry.kind == 'suggestion_dismissed')
          .toList();
      expect(rows, hasLength(1));
      expect(rows.single.itemId, 's1');
      expect(rows.single.itemOrigin, Origin.cloud);
      expect(
        rows.single.instantUtcMicros,
        _fixedClock().microsecondsSinceEpoch,
      );
      expect(rows.single.id, matches(v7));
      // Zero collateral: nothing but the one row appended.
      expect(
        store.entries.map((entry) => entry.kind).toList(),
        [...kindsBefore, 'suggestion_dismissed'],
        reason:
            'no energy, report, session or deal row rides the decline — '
            'FR-15\'s zero-side-effects consequence',
      );
      // The freed slot: the answered week means the check-in takes it.
      expect(after.stripResident, StripResident.energyCheckIn);
      expect(after.seasonalSuggestion, isNull);
      // Silent for the season: a later read of the same opening never
      // re-offers the project.
      expect(
        (await controller.read()).stripResident,
        StripResident.energyCheckIn,
      );
    });

    test('per-project is the rate limit — dismissing A surfaces B in '
        'the same opening (matrix: two dormant Epics)', () async {
      final store = storeOfFacts([
        dormantEpic('a', description: 'el trastero'),
        dormantEpic('b', description: 'la terraza', at: 1),
      ]);
      await openSessionAndReadFirstDeal(store);
      final controller = buildFor(store);
      final first = await controller.read();
      expect(first.seasonalSuggestion?.stableId, 'a');

      final after = await controller.dismissSeasonalSuggestion();

      expect(after.stripResident, StripResident.seasonalSuggestion);
      expect(after.seasonalSuggestion?.stableId, 'b');
      expect(
        store.entries
            .where((entry) => entry.kind == 'suggestion_dismissed')
            .toList(),
        hasLength(1),
      );
    });

    test('overlapping one-tap calls mint exactly one row — consume-at-entry '
        'is the guard, not the screen', () async {
      final store = storeOfFacts([dormantEpic('s1')]);
      await openSessionAndReadFirstDeal(store);
      final controller = buildFor(store);
      await controller.read();

      // Both paths capture `_shownSuggestion` synchronously at entry.
      // The second call sees null and mints nothing, even though its
      // write has not yet been queued past the first append.
      final dismiss = controller.dismissSeasonalSuggestion();
      final accept = controller.acceptSeasonalSuggestion();
      await Future.wait([dismiss, accept]);

      expect(
        store.entries.where((entry) => entry.kind == 'suggestion_dismissed'),
        hasLength(1),
        reason: 'the first capture owns the shown record',
      );
      expect(
        store.entries.where((entry) => entry.kind == 'epic_activated'),
        isEmpty,
        reason: 'the overlapping accept minted nothing',
      );
    });

    test('a stale ✕ — a handler firing after a read that showed no '
        'suggestion — writes nothing, quietly (matrix: stale tap)', () async {
      final store = storeOfFacts([dormantEpic('s1')]);
      await openSessionAndReadFirstDeal(store);
      final controller = buildFor(store);
      await controller.read();
      await controller.dismissSeasonalSuggestion(); // The real ✕.
      final rowsAfterReal = store.entries.length;

      // A second ✕ on the already-dismissed project: the last read
      // showed no suggestion, so `_shownSuggestion` is null — nothing
      // mints.
      final after = await controller.dismissSeasonalSuggestion();
      expect(store.entries.length, rowsAfterReal);
      expect(after.stripResident, isNot(StripResident.seasonalSuggestion));

      // And the same guard on the accept path: a fresh controller
      // that never read a suggestion mints nothing either.
      final fresh = _RecordingStore([dormantEpic('s2')])
        ..entries.addAll(store.entries);
      final freshController = buildFor(fresh);
      await freshController.acceptSeasonalSuggestion();
      expect(
        fresh.entries.where((entry) => entry.kind == 'epic_activated'),
        isEmpty,
        reason:
            'no read ever showed the suggestion — the tap mints '
            'nothing',
      );
    });

    test('the tap writes exactly one epic_activated row naming the shown '
        'project — the resident is gone by derivation and the Epic\'s '
        'head competes for the next deal (matrix: accept)', () async {
      final store = storeOfFacts([dormantEpic('s1')]);
      await openSessionAndReadFirstDeal(store);
      final controller = buildFor(store);
      final before = await controller.read();
      expect(before.seasonalSuggestion?.stableId, 's1');

      final after = await controller.acceptSeasonalSuggestion();

      final rows = store.entries
          .where((entry) => entry.kind == 'epic_activated')
          .toList();
      expect(rows, hasLength(1));
      expect(rows.single.itemId, 's1');
      expect(rows.single.itemOrigin, Origin.cloud);
      expect(
        after.stripResident,
        StripResident.energyCheckIn,
        reason:
            'gone by derivation — the Epic is no longer dormant, and '
            'the check-in takes the freed slot (the answered week '
            'keeps the report out)',
      );
      expect(after.seasonalSuggestion, isNull);

      // The Epic is active in the weave: the completion's bundled
      // deal stands unanswered (no second deal exists while it
      // stands, AD-3), so the pin reads the composition the next
      // day's fresh opening would resolve — the activated head step
      // holds the Focus Chunk itself, the epic tier ahead of every
      // zone tier (5.9's own arbitration, now over an Epic the tap
      // made active).
      expect(after, isA<DispenserDealt>());
      await controller.complete(after as DispenserDealt);
      // Close the sitting: a day whose open session still holds a
      // dealt-but-unanswered card composes without the "1", so the
      // pin ends the session before composing the next day.
      await controller.pause();
      final catalogue = await shippedCatalogue();
      final composition = composeDay(
        catalogue: catalogue,
        log: logEntriesOf(store.entries),
        instantUtcMicros: DateTime.utc(2026, 8, 30, 9).microsecondsSinceEpoch,
        offsetSeconds: 0,
        poolFacts: poolFactsOf(store.facts),
      );
      expect(composition.focus!.id, 's1');
      expect(composition.focus!.origin, Origin.cloud);
    });

    test('a dismissed-last-season project re-offers this season (matrix: '
        'dismissed last season)', () async {
      final store = _RecordingStore([dormantEpic('s1')])
        ..entries.add(_answeredWeek(weekOfAug17, 'seed-week-answered'))
        ..entries.add(_installOpen())
        ..entries.add(
          _act(
            'suggestion_dismissed',
            DateTime.utc(2026, 5, 20, 9),
            'spring-dismissal',
            's1',
          ),
        );
      await openSessionAndReadFirstDeal(store);
      final view = await buildFor(store).read();
      expect(view.stripResident, StripResident.seasonalSuggestion);
      expect(view.seasonalSuggestion?.stableId, 's1');
    });

    test('a failed ✕ append lands nothing — the resident stands and the '
        'retry is the same tap (matrix: read failure)', () async {
      // A facts-carrying store whose NEXT append throws once —
      // `_FailNextAppendStore` reads no facts, so the group owns its
      // own wrapper. The session opens over the inner store first, so
      // the armed failure is the dismissal's own append.
      final inner = storeOfFacts([dormantEpic('s1')]);
      await openSessionAndReadFirstDeal(inner);
      var failNextAppend = true;
      final store = _DelegatingStore(
        appendLogEntry: (entry) {
          if (failNextAppend) {
            failNextAppend = false;
            throw StateError('append failed');
          }
          return inner.appendLogEntry(entry);
        },
        readLogEntries: inner.readLogEntries,
        readPoolFacts: inner.readPoolFacts,
      );
      final controller = buildFor(store);
      await controller.read();

      await expectLater(
        controller.dismissSeasonalSuggestion(),
        throwsStateError,
      );
      expect(
        inner.entries.where((entry) => entry.kind == 'suggestion_dismissed'),
        isEmpty,
        reason: 'nothing landed',
      );
      expect(
        (await controller.read()).stripResident,
        StripResident.seasonalSuggestion,
        reason: 'the resident stands — the derivation re-resolves it',
      );
    });

    test('a failed tap append lands nothing — the resident stands and '
        'the retry is the same tap (matrix: read failure under the '
        'accept)', () async {
      // The ✕-failure twin, on the accept path: the armed failure is
      // the activation's own append — nothing lands, the Epic stays
      // dormant, the suggestion re-resolves, and no other row exists.
      final inner = storeOfFacts([dormantEpic('s1')]);
      await openSessionAndReadFirstDeal(inner);
      var failNextAppend = true;
      final store = _DelegatingStore(
        appendLogEntry: (entry) {
          if (failNextAppend) {
            failNextAppend = false;
            throw StateError('append failed');
          }
          return inner.appendLogEntry(entry);
        },
        readLogEntries: inner.readLogEntries,
        readPoolFacts: inner.readPoolFacts,
      );
      final controller = buildFor(store);
      await controller.read();

      await expectLater(
        controller.acceptSeasonalSuggestion(),
        throwsStateError,
      );
      expect(
        inner.entries.where((entry) => entry.kind == 'epic_activated'),
        isEmpty,
        reason: 'nothing landed',
      );
      expect(
        inner.entries.where((entry) => entry.kind == 'suggestion_dismissed'),
        isEmpty,
        reason: 'the accept path writes no other row',
      );
      expect(
        (await controller.read()).stripResident,
        StripResident.seasonalSuggestion,
        reason: 'the resident stands — the Epic is still dormant',
      );
    });

    test('the weave\'s deal is identical after a dismissal — the '
        'decline changes no derivation (FR-15)', () async {
      final store = storeOfFacts([dormantEpic('s1')]);
      final dealt = await openSessionAndReadFirstDeal(store);
      final controller = buildFor(store);
      final before = await controller.read();
      await controller.dismissSeasonalSuggestion();
      final after = await controller.read();
      expect(after, isA<DispenserDealt>());
      expect(
        (after as DispenserDealt).card,
        (before as DispenserDealt).card,
        reason:
            'the standing card is the same card — the dismissal '
            'moved no deal',
      );
      expect(dealt.card, isNotNull);
    });
  });

  group('the blind six-month follow-up (Story 6.6, FR-21, UX-DR22)', () {
    /// A `box_created` row — the core suite's `_box` pattern, one
    /// local shape for the whole group.
    LogEntryRecord boxRow(String id, DateTime at) =>
        _moment('box_created', at, id);

    /// The box's linked `item_triaged(quarantine)` row — the same
    /// pattern with the two triage fields carried.
    LogEntryRecord intoBoxRow(String id, DateTime at, String boxId) => (
      id: id,
      kind: 'item_triaged',
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
      cluster: null,
      enabled: null,
      triageDestination: 'quarantine',
      triageVolumeTag: null,
      triageBoxId: boxId,
      beforeName: null,
      afterName: null,
    );

    /// One non-empty box dated 2026-03-01 — due 2026-09-01, the due
    /// day every read of this group sits on (the act's own shape:
    /// the box row first, then its linked `item_triaged(quarantine)`
    /// row, one instant apart).
    List<LogEntryRecord> seededBox(String id) => [
      boxRow('box-$id', DateTime.utc(2026, 3, 1, 10)),
      intoBoxRow('into-$id', DateTime.utc(2026, 3, 1, 10, 0, 1), 'box-$id'),
    ];

    /// The established install's due-day first opening: install open
    /// the day before, the due day's open and session at 09:00 — the
    /// 2.5 launch shape, one clock on.
    List<LogEntryRecord> dueDayOpening() => [
      _installOpen(),
      _moment('app_opened', DateTime.utc(2026, 9, 1, 9), 'due-open'),
      _moment(
        'session_started',
        DateTime.utc(2026, 9, 1, 9, 0, 1),
        'due-start',
      ),
    ];

    DateTime dueDayClock() => DateTime.utc(2026, 9, 1, 12);

    test('the due day read holds the follow-up below the card — '
        'precedence slot 2, the report and check-in displaced, and '
        'reading wrote nothing (matrix: due day, app opened)', () async {
      final store = _RecordingStore()
        ..entries.addAll([...dueDayOpening(), ...seededBox('a')]);
      final controller = buildFor(store, nowOf: dueDayClock);

      final view = await controller.read();

      // The knock rides every variant of the view (the strip layer
      // composes below whatever the read commits); what this pin
      // holds is the resident itself, precedence slot 2.
      expect(view.stripResident, StripResident.quarantineFollowUp);
      expect(
        store.entries.where((entry) => entry.kind == 'report_answered'),
        isEmpty,
        reason: 'the displaced report is neither consumed nor answered',
      );
    });

    test('the ✕ dismissal writes nothing, hides the resident for the '
        'rest of the day, and hands the slot to the displaced report '
        '(matrix: dismissal)', () async {
      final store = _RecordingStore()
        ..entries.addAll([...dueDayOpening(), ...seededBox('a')]);
      final controller = buildFor(store, nowOf: dueDayClock);
      await controller.read();

      final writesBefore = store.writeCalls;
      final kindsBefore = store.entries.map((entry) => entry.kind).toList();
      final dismissed = await controller.dismissQuarantineFollowUp();

      expect(
        store.entries.map((entry) => entry.kind).toList(),
        kindsBefore,
        reason:
            'a dismissal appends nothing at all — no row, no '
            'marker row, nothing (FR-21\'s no-side-effects clause)',
      );
      expect(
        store.writeCalls,
        writesBefore,
        reason:
            'the dismissal must make zero StorePort writes, not merely add '
            'zero log rows',
      );
      expect(
        dismissed.stripResident,
        StripResident.weeklySelfReport,
        reason:
            'the ✕ hands the freed slot to the displaced report in '
            'the same read (FR-4\'s deterministic handoff)',
      );
      expect(
        (await controller.read()).stripResident,
        StripResident.weeklySelfReport,
        reason: 'hidden for the rest of the day',
      );
    });

    test('a later day never re-offers — the window is derived-closed, '
        'marker or no marker (matrix: day after due)', () async {
      var now = dueDayClock();
      final store = _RecordingStore()
        ..entries.addAll([...dueDayOpening(), ...seededBox('a')]);
      final controller = buildFor(store, nowOf: () => now);

      await controller.dismissQuarantineFollowUp();
      // The day turns: the marker keys the old day alone, and the
      // derivation has closed the window on its own — no stored fact
      // could bring either back. The standing resident is pinned,
      // not just the follow-up's absence: the later-day read still
      // owes the walk's own resident (the core twin's convention),
      // so a regression to nothing-eligible-at-all fails here.
      now = DateTime.utc(2026, 9, 2, 12);
      expect(
        (await controller.read()).stripResident,
        StripResident.weeklySelfReport,
        reason:
            'the crossed-into day\'s first opening still owes the '
            'running week\'s report — only the knock is gone',
      );

      // And the un-dismissed twin reads the same on that later day:
      // the closure is the derivation's, never the marker's.
      final untouched = _RecordingStore()
        ..entries.addAll([...dueDayOpening(), ...seededBox('a')]);
      expect(
        (await buildFor(
          untouched,
          nowOf: () => DateTime.utc(2026, 9, 2, 12),
        ).read()).stripResident,
        StripResident.weeklySelfReport,
        reason:
            'the window closed by derivation — the ordinary walk '
            'stands, not an empty strip',
      );
      expect(
        untouched.entries.where(
          (entry) =>
              entry.kind != 'app_opened' &&
              entry.kind != 'session_started' &&
              entry.kind != 'box_created' &&
              entry.kind != 'item_triaged',
        ),
        isEmpty,
        reason:
            'no path wrote a dismissal row — the window closed '
            'itself (AD-21, AD-25)',
      );
    });

    test('an empty box never knocks — the partial-write artifact stays '
        'quiet (matrix: empty box due)', () async {
      final store = _RecordingStore()
        ..entries.addAll([
          ...dueDayOpening(),
          boxRow('box-empty', DateTime.utc(2026, 3, 1, 10)),
        ]);
      expect(
        (await buildFor(store, nowOf: dueDayClock).read()).stripResident,
        isNot(StripResident.quarantineFollowUp),
        reason:
            'the 6.5 failed-retry orphan reconstructs honestly '
            'empty — knocking about it would be noise about a '
            'non-decision',
      );
    });

    test('a fresh process over the same log re-offers within the due '
        'day only — the marker is shell state, never a row (matrix: '
        'process death after dismiss)', () async {
      final store = _RecordingStore()
        ..entries.addAll([...dueDayOpening(), ...seededBox('a')]);
      final first = buildFor(store, nowOf: dueDayClock);
      await first.read();
      await first.dismissQuarantineFollowUp();
      expect(
        (await first.read()).stripResident,
        isNot(StripResident.quarantineFollowUp),
      );

      // Process death: a fresh controller holds no marker, and the
      // log holds no fact — the same due day re-offers once, the
      // `_checkInDismissMarker` family's accepted shape. Tomorrow
      // stays closed either way (the pin above).
      final revived = buildFor(store, nowOf: dueDayClock);
      expect(
        (await revived.read()).stripResident,
        StripResident.quarantineFollowUp,
      );
      expect(
        store.entries.where((entry) => entry.kind == 'box_created'),
        hasLength(1),
        reason: 'the whole dismissal cycle wrote zero rows',
      );
    });
  });

  group('the warm return (Story 2.7, FR-6, AD-24)', () {
    /// A completed day, dealt-and-answered through a closed sitting,
    /// ending 2026-08-26 09:06 — just under 75 hours before the fixed
    /// Saturday clock. The screen suite's seven-day seed shape, at the
    /// shorter gap.
    void seedContactDay(_RecordingStore store) {
      store.entries.addAll([
        _moment('app_opened', DateTime.utc(2026, 8, 26, 9), 'warm-open'),
        _moment(
          'session_started',
          DateTime.utc(2026, 8, 26, 9, 0, 1),
          'warm-start',
        ),
        _act(
          'card_dealt',
          DateTime.utc(2026, 8, 26, 9, 0, 2),
          'warm-deal',
          chunkSeedId,
        ),
        _act(
          'card_done',
          DateTime.utc(2026, 8, 26, 9, 5),
          'warm-done',
          chunkSeedId,
        ),
        _moment('session_ended', DateTime.utc(2026, 8, 26, 9, 6), 'warm-end'),
      ]);
    }

    test('a days-long gap since the last contact reads warmReturnDue on '
        'the dealt view, and the launch appended exactly the normal '
        'opening rows', () async {
      final store = _RecordingStore();
      seedContactDay(store);
      final seeded = store.entries.length;
      await SessionController(
        store: store,
        strings: AppStringsEs(),
        bundle: _FakeBundle({catalogueAssetPath: shipped}),
        nowOf: _fixedClock,
      ).handleAppOpen();

      final view = await buildFor(store).read();

      expect(view, isA<DispenserDealt>());
      expect(view.warmReturnDue, isTrue);
      expect(
        store.entries.skip(seeded).map((entry) => entry.kind).toList(),
        ['app_opened', 'session_started', 'card_dealt'],
        reason:
            'the greeting writes nothing: the warm opening appends '
            'exactly the rows a normal opening appends',
      );
    });

    test("yesterday's contact reads warmReturnDue false — the ordinary "
        'opening control', () async {
      final store = _RecordingStore()
        ..entries.addAll([
          _moment('app_opened', DateTime.utc(2026, 8, 28, 10), 'y-open'),
          _moment(
            'session_started',
            DateTime.utc(2026, 8, 28, 10, 0, 1),
            'y-start',
          ),
          _act(
            'card_dealt',
            DateTime.utc(2026, 8, 28, 10, 0, 2),
            'y-deal',
            chunkSeedId,
          ),
          _act(
            'card_done',
            DateTime.utc(2026, 8, 28, 10, 5),
            'y-done',
            chunkSeedId,
          ),
          _moment('session_ended', DateTime.utc(2026, 8, 28, 10, 6), 'y-end'),
        ]);
      await SessionController(
        store: store,
        strings: AppStringsEs(),
        bundle: _FakeBundle({catalogueAssetPath: shipped}),
        nowOf: _fixedClock,
      ).handleAppOpen();

      expect((await buildFor(store).read()).warmReturnDue, isFalse);
    });

    test('the greeting stands through the same opening\'s writes and is '
        'gone at the next opening inside 48 h — the derivation alone, no '
        'state anywhere', () async {
      var now = _fixedClock();
      final store = _RecordingStore();
      seedContactDay(store);
      final session = SessionController(
        store: store,
        strings: AppStringsEs(),
        bundle: _FakeBundle({catalogueAssetPath: shipped}),
        nowOf: () => now,
      );
      final controller = buildFor(store, nowOf: () => now);
      await session.handleAppOpen();
      final launch = await controller.read();
      expect(launch.warmReturnDue, isTrue);

      // A write-then-read inside the same opening: the acts sit after
      // the last `app_opened` and cannot move the anchor.
      now = DateTime.utc(2026, 8, 29, 12, 1);
      await controller.complete(launch as DispenserDealt);
      expect((await controller.read()).warmReturnDue, isTrue);

      // The next opening, ten minutes past those acts: false — the
      // derivation alone flipped it, nothing was stored.
      now = DateTime.utc(2026, 8, 29, 12, 5);
      await session.handleSessionEnd();
      now = DateTime.utc(2026, 8, 29, 12, 10);
      await session.handleAppOpen();
      expect((await controller.read()).warmReturnDue, isFalse);
    });

    test('the close and the rest offer carry the greeting fact exactly '
        'as the dealt view does (variant propagation)', () async {
      // The close: an empty catalogue over the warm log — no deal
      // exists, and the greeting rides the close.
      final closedStore = _RecordingStore();
      seedContactDay(closedStore);
      closedStore.entries.add(
        _moment('app_opened', DateTime.utc(2026, 8, 29, 11), 'closed-open'),
      );
      final closed = await DispenserController(
        store: closedStore,
        strings: AppStringsEs(),
        bundle: _FakeBundle({catalogueAssetPath: '{"version":1,"entries":[]}'}),
        nowOf: _fixedClock,
      ).read();
      expect(closed, isA<DispenserClosed>());
      expect(closed.warmReturnDue, isTrue);

      // The rest offer: a pocketed sitting 40 minutes in at the fixed
      // clock, opened on a warm launch — the offer preempts the deal
      // and the greeting stands above it too.
      final offerStore = _RecordingStore();
      seedContactDay(offerStore);
      offerStore.entries.addAll([
        _moment('app_opened', DateTime.utc(2026, 8, 29, 11, 19), 'offer-open'),
        (
          id: 'offer-pocket',
          kind: 'session_started',
          instantUtcMicros: DateTime.utc(
            2026,
            8,
            29,
            11,
            20,
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
          cluster: null,
          enabled: null,
          triageDestination: null,
          triageVolumeTag: null,
          triageBoxId: null,
          beforeName: null,
          afterName: null,
        ),
      ]);
      final offer = await buildFor(offerStore).read();
      expect(offer, isA<DispenserRestOffer>());
      expect(offer.warmReturnDue, isTrue);
    });
  });

  group('the capture comes back as an ordinary card (Story 3.3)', () {
    const captureId = '019123ab-cdef-7abc-8def-0123456789ab';
    PoolFactRecord captureFact(
      Size size,
      DateTime at, {
      String line = 'Llamar al dentista',
    }) => (
      id: captureId,
      origin: Origin.manual,
      size: size,
      instantUtcMicros: at.microsecondsSinceEpoch,
      offsetSeconds: 0,
      originContext: line,
      dictated: null,
      rescueOf: null,
      estimateSeconds: null,
      stepText: null,
    );

    test('read deals the standing capture by its own line — the '
        'launch bundle sees the facts', () async {
      final store = _RecordingStore([
        captureFact(Size.focus, DateTime.utc(2026, 8, 29, 10)),
      ]);
      final dealt = await openSessionAndReadFirstDeal(store);
      expect(dealt.card.id, captureId);
      expect(dealt.card.name, 'Llamar al dentista');
      expect(dealt.card.size, Size.focus);
      expect(dealt.card.origin, Origin.manual);
      expect(dealt.card.zone, isNull);
      // The launch bundle minted the capture's deal itself.
      expect(
        store.entries
            .where((entry) => entry.kind == 'card_dealt')
            .single
            .itemId,
        captureId,
      );
    });

    test('completing a focus capture closes the day\'s chunk slot — no '
        'second large item composes after it', () async {
      final store = _RecordingStore([
        captureFact(Size.focus, DateTime.utc(2026, 8, 29, 10)),
      ]);
      final dealt = await openSessionAndReadFirstDeal(store);
      final controller = DispenserController(
        store: store,
        strings: AppStringsEs(),
        bundle: _FakeBundle({catalogueAssetPath: shipped}),
        nowOf: _fixedClock,
      );
      await controller.complete(dealt);
      // The answer closed the slot through the fact's own size, so the
      // read leaves the focus tier entirely.
      final view = await controller.read();
      expect(view, isA<DispenserDealt>());
      expect((view as DispenserDealt).card.size, isNot(Size.focus));
      expect(view.card.id, isNot(captureId));
    });

    test('skipping the capture re-bundles it — the same card returns, '
        'its FIFO place kept', () async {
      final store = _RecordingStore([
        captureFact(Size.focus, DateTime.utc(2026, 8, 29, 10)),
      ]);
      final dealt = await openSessionAndReadFirstDeal(store);
      final controller = DispenserController(
        store: store,
        strings: AppStringsEs(),
        bundle: _FakeBundle({catalogueAssetPath: shipped}),
        nowOf: _fixedClock,
      );
      await controller.skip(dealt);
      final kinds = store.entries.map((entry) => entry.kind).toList();
      expect(kinds, [
        'app_opened',
        'session_started',
        'card_dealt',
        'card_skipped',
        'card_dealt',
      ]);
      expect(store.entries[3].itemId, captureId);
      expect(store.entries[4].itemId, captureId);
      final view = await controller.read();
      expect(view, isA<DispenserDealt>());
      expect((view as DispenserDealt).card.id, captureId);
      expect(view.card.name, 'Llamar al dentista');
    });

    test('a maintenance capture leads the day\'s upkeep draws once the '
        'chunk is answered', () async {
      final store = _RecordingStore([
        captureFact(Size.maintenance, DateTime.utc(2026, 8, 29, 10)),
      ]);
      // Open and answer the shipped chunk first: the capture waits in
      // the 3-draw behind it.
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
      var view = await controller.read();
      final chunk = view as DispenserDealt;
      expect(chunk.card.size, Size.focus);
      expect(chunk.card.origin, Origin.shipped);
      await controller.complete(chunk);
      view = await controller.read();
      final upkeep = view as DispenserDealt;
      expect(upkeep.card.id, captureId);
      expect(upkeep.card.size, Size.maintenance);
      expect(upkeep.card.name, 'Llamar al dentista');
    });

    /// A seeded pocketed sitting row — the extend path's shape.
    LogEntryRecord pocketedStart(DateTime at, int minutes) =>
        _pocketedStart(at, minutes);

    test('declarePocket mints the capture as the fresh sitting\'s '
        'first card — the controller-level facts threading', () async {
      final store = _RecordingStore([
        captureFact(Size.focus, DateTime.utc(2026, 8, 29, 10)),
      ]);
      final controller = DispenserController(
        store: store,
        strings: AppStringsEs(),
        bundle: _FakeBundle({catalogueAssetPath: shipped}),
        nowOf: _fixedClock,
      );
      final view = await controller.declarePocket(15);
      // Nothing was open, so the declaration is exactly the fresh
      // pocketed start plus its first deal — and the deal names the
      // capture, never the shipped chunk the empty-facts path mints.
      expect(store.entries.map((entry) => entry.kind).toList(), [
        'session_started',
        'card_dealt',
      ]);
      expect(
        store.entries.singleWhere((e) => e.kind == 'card_dealt').itemId,
        captureId,
      );
      expect(
        store.entries
            .singleWhere((e) => e.kind == 'session_started')
            .pocketMinutes,
        15,
      );
      expect(view, isA<DispenserDealt>());
      expect((view as DispenserDealt).card.id, captureId);
    });

    test('extend mints the capture as the lifted sitting\'s bundled '
        'continue deal — the controller-level facts threading', () async {
      final store = _RecordingStore([
        captureFact(Size.focus, DateTime.utc(2026, 8, 29, 10)),
      ]);
      // An open pocketed sitting, nothing standing, room once the
      // interval lifts the ceiling: the extension's bundled deal is
      // the capture.
      store.entries.add(pocketedStart(DateTime.utc(2026, 8, 29, 11, 55), 20));
      final controller = DispenserController(
        store: store,
        strings: AppStringsEs(),
        bundle: _FakeBundle({catalogueAssetPath: shipped}),
        nowOf: _fixedClock,
      );
      final view = await controller.extend();
      expect(store.entries.map((entry) => entry.kind).toList(), [
        'session_started',
        'session_extended',
        'card_dealt',
      ]);
      expect(store.entries.last.kind, 'card_dealt');
      expect(store.entries.last.itemId, captureId);
      expect(view, isA<DispenserDealt>());
      expect((view as DispenserDealt).card.id, captureId);
      expect(view.card.name, 'Llamar al dentista');
    });
  });

  group('Rescue Mode (Story 4.6, FR-5)', () {
    const deliveredBody =
        '{"steps":['
        '{"text":"Buscar el desengrasante bajo el fregadero","duration_seconds":45},'
        '{"text":"Rociar la campana y dejar actuar","duration_seconds":60},'
        '{"text":"Secar con un trapo limpio","duration_seconds":30}]}';

    DispenserController controllerFor(StorePort store, SlicerPort? slicer) =>
        DispenserController(
          store: store,
          strings: AppStringsEs(),
          bundle: _FakeBundle({catalogueAssetPath: shipped}),
          nowOf: _fixedClock,
          slicer: slicer,
        );

    test('a delivered re-slice lands whole: the activation row, the '
        'step facts (origin inherited, instant size, the tag verbatim, '
        'the shipped parent\'s Spanish name on the request), the '
        'supersede pair and the head-step deal — one id per step on '
        'both halves of the landing', () async {
      final store = _FactRecordingStore();
      final dealt = await openSessionAndReadFirstDeal(store);
      expect(
        dealt.card.origin,
        Origin.shipped,
        reason:
            'the pre-condition: the standing card is the shipped '
            'chunk the launch dealt',
      );
      final slicer = _StubSlicer(const SlicerDelivered(deliveredBody));
      final controller = controllerFor(store, slicer);

      final outcome = await controller.rescue(dealt);

      // The request rode the Origin Context path: both slots hold the
      // Card's own resolved name — the Spanish catalogue name, no
      // catalogue field, no new loader machinery.
      expect(slicer.requests, hasLength(1));
      expect(slicer.requests.single.originContext, dealt.card.name);
      expect(slicer.requests.single.task, dealt.card.name);

      expect(store.entries.map((entry) => entry.kind).toList(), [
        'app_opened',
        'session_started',
        'card_dealt',
        'slice_requested',
        'slice_returned',
        'card_dealt',
      ]);
      final activation = store.entries[3];
      expect(activation.itemId, dealt.card.id);
      expect(activation.itemOrigin, Origin.shipped);
      expect(activation.id, matches(v7));
      final returned = store.entries[4];
      final headDeal = store.entries[5];
      expect(returned.itemId, dealt.card.id);
      // One minted instant for the landing batch.
      expect(returned.instantUtcMicros, headDeal.instantUtcMicros);

      // The step facts: transient pool facts, nothing enters the
      // catalogue (FR-31) — origin inherited shipped, size the fixed
      // instant band, the Slicer's tag verbatim, each step's own text
      // as its Origin Context.
      expect(store.facts, hasLength(3));
      expect(store.facts.map((fact) => fact.origin).toSet(), {Origin.shipped});
      expect(store.facts.map((fact) => fact.size).toSet(), {Size.instant});
      expect(store.facts.map((fact) => fact.estimateSeconds).toList(), [
        45,
        60,
        30,
      ]);
      expect(
        store.facts.every((fact) => fact.rescueOf == dealt.card.id),
        isTrue,
      );
      expect(store.facts.map((fact) => fact.originContext).toList(), [
        'Buscar el desengrasante bajo el fregadero',
        'Rociar la campana y dejar actuar',
        'Secar con un trapo limpio',
      ], reason: 'each step\'s own text rides its own fact');
      expect(
        store.facts.every((fact) => fact.dictated == null),
        isTrue,
        reason: 'the Slicer authors no dictation flag',
      );

      // The bundled deal names the fact the same landing minted — the
      // head step, not a second mint's stranger.
      expect(headDeal.itemId, store.facts.first.id);
      expect(headDeal.itemOrigin, Origin.shipped);

      // The outcome's view is the fresh read: the head step standing,
      // a step card (its tap skips — the depth cap's shell reading),
      // never warranted.
      expect(outcome, isA<DispenserRescueSucceeded>());
      final view = (outcome as DispenserRescueSucceeded).view;
      expect(view, isA<DispenserDealt>());
      expect((view as DispenserDealt).card.id, store.facts.first.id);
      expect(view.card.estimateSeconds, 45);
      expect(view.rescueStep, isTrue);
      expect(view.autoRescueDue, isFalse);
    });

    test(
      'a capture parent\'s re-slice rides its own line — the Origin '
      'Context is the capture\'s single line, steps inherit manual',
      () async {
        const line = 'Llamar al dentista';
        final store = _RecordingStore([
          (
            id: 'cap-manual',
            origin: Origin.manual,
            size: Size.focus,
            instantUtcMicros: DateTime.utc(2026, 8, 25).microsecondsSinceEpoch,
            offsetSeconds: 0,
            originContext: line,
            dictated: null,
            rescueOf: null,
            estimateSeconds: null,
            stepText: null,
          ),
        ]);
        final dealt = await openSessionAndReadFirstDeal(store);
        expect(
          dealt.card.origin,
          Origin.manual,
          reason: 'the pre-condition: the standing card is the seeded capture',
        );
        expect(dealt.card.name, line);
        final slicer = _StubSlicer(const SlicerDelivered(deliveredBody));
        final outcome = await controllerFor(store, slicer).rescue(dealt);
        // The request carries the capture's own line in both slots —
        // no catalogue field anywhere near a manual parent.
        expect(slicer.requests.single.originContext, line);
        expect(slicer.requests.single.task, line);
        expect(outcome, isA<DispenserRescueSucceeded>());
      },
    );

    test('a failed re-slice lands one cause row — nothing queued, the '
        'original stays dealable exactly as it stood, and the mapped '
        'cause rides the outcome', () async {
      final store = _FactRecordingStore();
      final dealt = await openSessionAndReadFirstDeal(store);
      final controller = controllerFor(
        store,
        _StubSlicer(const SlicerFailed(SlicerFailureCause.networkUnreachable)),
      );

      final outcome = await controller.rescue(dealt);

      expect(store.entries.map((entry) => entry.kind).toList(), [
        'app_opened',
        'session_started',
        'card_dealt',
        'slice_requested',
        'slice_failed',
      ]);
      final failed = store.entries.last;
      expect(failed.itemId, dealt.card.id);
      expect(failed.sliceCause, 'networkUnreachable');
      expect(
        store.facts,
        isEmpty,
        reason: 'nothing was queued and nothing was minted',
      );
      expect(outcome, isA<DispenserRescueFailed>());
      final failure = outcome as DispenserRescueFailed;
      expect(failure.cause, NoSlicerCause.offline);
      expect(failure.view, isA<DispenserDealt>());
      expect(
        (failure.view as DispenserDealt).card.id,
        dealt.card.id,
        reason: 'the original stands behind the calm surface',
      );
    });

    test('an unparsable body folds to malformedResponse — the parse '
        'is in core, and the recorded unreachable fold rides the '
        'outcome', () async {
      final store = _FactRecordingStore();
      final dealt = await openSessionAndReadFirstDeal(store);
      final controller = controllerFor(
        store,
        _StubSlicer(
          const SlicerDelivered(
            '{"steps":[{"text":"x","duration_seconds":30}]}',
          ),
        ),
      );

      final outcome = await controller.rescue(dealt);

      expect(store.entries.last.kind, 'slice_failed');
      expect(store.entries.last.sliceCause, 'malformedResponse');
      expect(store.facts, isEmpty);
      expect(
        (outcome as DispenserRescueFailed).cause,
        NoSlicerCause.unreachable,
      );
    });

    test('the depth cap: a rescue of a rescue step declines quietly — '
        'no row, no fact, no surface state', () async {
      final store = _FactRecordingStore();
      final dealt = await openSessionAndReadFirstDeal(store);
      final controller = controllerFor(
        store,
        _StubSlicer(const SlicerDelivered(deliveredBody)),
      );
      final succeeded = await controller.rescue(dealt);
      final headStep =
          (succeeded as DispenserRescueSucceeded).view as DispenserDealt;
      final rowsAfterLanding = store.entries.length;

      final declined = await controller.rescue(headStep);

      expect(declined, isA<DispenserRescueDeclined>());
      expect(
        store.entries.length,
        rowsAfterLanding,
        reason: 'the refusal appends nothing — no row exists for it',
      );
      expect(store.facts, hasLength(3));
    });

    test('no Slicer threaded declines quietly too — the test seam is '
        'not half of a control', () async {
      final store = _FactRecordingStore();
      final dealt = await openSessionAndReadFirstDeal(store);
      final controller = controllerFor(store, null);

      expect(await controller.rescue(dealt), isA<DispenserRescueDeclined>());
      expect(
        store.entries.where((entry) => entry.kind.startsWith('slice_')),
        isEmpty,
      );
    });

    test('a THROWING slicer folds to providerUnreachable — the port '
        'promises outcomes only for the BYOK wire, and a third '
        'implementation that breaks the promise can dangle no '
        'activation: the failure path is the one calm surface, the '
        'cause the no-answer bucket', () async {
      final store = _FactRecordingStore();
      final dealt = await openSessionAndReadFirstDeal(store);
      final controller = controllerFor(
        store,
        _ThrowingSlicer(StateError('the stub broke the port')),
      );

      final outcome = await controller.rescue(dealt);

      expect(store.entries.map((entry) => entry.kind).toList().sublist(3), [
        'slice_requested',
        'slice_failed',
      ]);
      expect(store.entries.last.sliceCause, 'providerUnreachable');
      expect(store.facts, isEmpty);
      expect(outcome, isA<DispenserRescueFailed>());
      expect(
        (outcome as DispenserRescueFailed).cause,
        NoSlicerCause.unreachable,
      );
    });

    test('the auto-heuristic\'s fact derives from the log — three '
        'decline days warrant the standing card, the activation '
        'resets it, and no Slicer threaded derives nothing', () async {
      const captureId = '019123ab-cdef-7abc-8def-0123456789ab';
      PoolFactRecord captureFact(DateTime at) => (
        id: captureId,
        origin: Origin.manual,
        size: Size.focus,
        instantUtcMicros: at.microsecondsSinceEpoch,
        offsetSeconds: 0,
        originContext: 'Llamar al dentista',
        dictated: null,
        rescueOf: null,
        estimateSeconds: null,
        stepText: null,
      );

      // Three eligible days of declines, each its own closed sitting.
      List<LogEntryRecord> decline(int day) {
        final at = DateTime.utc(2026, 8, day, 10);
        return [
          _moment('session_started', at, 'start-$day'),
          _act(
            'card_dealt',
            at.add(const Duration(seconds: 1)),
            'deal-$day',
            captureId,
          ),
          _act(
            'card_skipped',
            at.add(const Duration(seconds: 2)),
            'skip-$day',
            captureId,
          ),
          _moment(
            'session_ended',
            at.add(const Duration(seconds: 3)),
            'end-$day',
          ),
        ];
      }

      // The read's own sitting: the warranted item dealt, standing.
      final store = _RecordingStore([captureFact(DateTime.utc(2026, 8, 25))])
        ..entries.addAll([
          ...decline(26),
          ...decline(27),
          ...decline(28),
          _moment(
            'session_started',
            DateTime.utc(2026, 8, 29, 11),
            'start-today',
          ),
          _act(
            'card_dealt',
            DateTime.utc(2026, 8, 29, 11, 0, 1),
            'deal-today',
            captureId,
          ),
        ]);

      final stub = _StubSlicer(
        const SlicerFailed(SlicerFailureCause.invalidKey),
      );
      final withSlicer = controllerFor(store, stub);
      final warranted = await withSlicer.read();
      expect(warranted, isA<DispenserDealt>());
      expect((warranted as DispenserDealt).card.id, captureId);
      expect(
        warranted.autoRescueDue,
        isTrue,
        reason:
            'declined on 3 different eligible days — the '
            'auto-heuristic fires while the card stands',
      );
      expect(warranted.rescueStep, isFalse);

      // The activation resets the counter — the very next read (the
      // failure's landing included) derives false: a failed rescue
      // cannot re-fire on every deal.
      await withSlicer.rescue(warranted);
      expect(stub.requests.single.originContext, 'Llamar al dentista');
      final afterFailure = await withSlicer.read();
      expect((afterFailure as DispenserDealt).autoRescueDue, isFalse);

      // And the same log behind a slicer-less controller derives
      // nothing — no half-wired heuristic exists.
      final withoutSlicer = controllerFor(
        _RecordingStore([captureFact(DateTime.utc(2026, 8, 25))])
          ..entries.addAll([
            ...decline(26),
            ...decline(27),
            ...decline(28),
            _moment(
              'session_started',
              DateTime.utc(2026, 8, 29, 11),
              'start-today',
            ),
            _act(
              'card_dealt',
              DateTime.utc(2026, 8, 29, 11, 0, 1),
              'deal-today',
              captureId,
            ),
          ]),
        null,
      );
      final bare = await withoutSlicer.read();
      expect((bare as DispenserDealt).autoRescueDue, isFalse);
    });

    test('the auto-heuristic succeeds the same way — a warranted card '
        'auto-fires through delivery into the head step, then goes '
        'quiet', () async {
      const captureId = '019123ab-cdef-7abc-8def-0123456789ab';
      PoolFactRecord captureFact(DateTime at) => (
        id: captureId,
        origin: Origin.manual,
        size: Size.focus,
        instantUtcMicros: at.microsecondsSinceEpoch,
        offsetSeconds: 0,
        originContext: 'Llamar al dentista',
        dictated: null,
        rescueOf: null,
        estimateSeconds: null,
        stepText: null,
      );
      List<LogEntryRecord> decline(int day) {
        final at = DateTime.utc(2026, 8, day, 10);
        return [
          _moment('session_started', at, 'start-$day'),
          _act(
            'card_dealt',
            at.add(const Duration(seconds: 1)),
            'deal-$day',
            captureId,
          ),
          _act(
            'card_skipped',
            at.add(const Duration(seconds: 2)),
            'skip-$day',
            captureId,
          ),
          _moment(
            'session_ended',
            at.add(const Duration(seconds: 3)),
            'end-$day',
          ),
        ];
      }

      final store = _FactRecordingStore()
        ..facts.add(captureFact(DateTime.utc(2026, 8, 25)))
        ..entries.addAll([
          ...decline(26),
          ...decline(27),
          ...decline(28),
          // Today's sitting opens ten minutes before the read: no
          // checkpoint crossing elapses, so no rest offer preempts
          // either read.
          _moment(
            'session_started',
            DateTime.utc(2026, 8, 29, 11, 50),
            'start-today',
          ),
          _act(
            'card_dealt',
            DateTime.utc(2026, 8, 29, 11, 50, 1),
            'deal-today',
            captureId,
          ),
        ]);
      final stub = _StubSlicer(const SlicerDelivered(deliveredBody));
      final controller = controllerFor(store, stub);
      final warranted = await controller.read();
      expect((warranted as DispenserDealt).autoRescueDue, isTrue);
      final outcome = await controller.rescue(warranted);
      expect(outcome, isA<DispenserRescueSucceeded>());
      expect(stub.requests.single.originContext, 'Llamar al dentista');
      expect(store.entries.map((entry) => entry.kind).toList().sublist(14), [
        'slice_requested',
        'slice_returned',
        'card_dealt',
      ]);
      final view = (outcome as DispenserRescueSucceeded).view as DispenserDealt;
      expect(view.rescueStep, isTrue);
      final after = await controller.read();
      expect((after as DispenserDealt).autoRescueDue, isFalse);
    });

    test('a shipped catalogue entry declined on 3 eligible days '
        'warrants too — the fact-less anchor through read()', () async {
      List<LogEntryRecord> decline(int day) {
        final at = DateTime.utc(2026, 8, day, 10);
        return [
          _moment('session_started', at, 'start-$day'),
          _act(
            'card_dealt',
            at.add(const Duration(seconds: 1)),
            'deal-$day',
            chunkSeedId,
          ),
          _act(
            'card_skipped',
            at.add(const Duration(seconds: 2)),
            'skip-$day',
            chunkSeedId,
          ),
          _moment(
            'session_ended',
            at.add(const Duration(seconds: 3)),
            'end-$day',
          ),
        ];
      }

      final store = _RecordingStore()
        ..entries.addAll([
          ...decline(26),
          ...decline(27),
          ...decline(28),
          _moment(
            'session_started',
            DateTime.utc(2026, 8, 29, 11),
            'start-today',
          ),
          _act(
            'card_dealt',
            DateTime.utc(2026, 8, 29, 11, 0, 1),
            'deal-today',
            chunkSeedId,
          ),
        ]);
      final view = await controllerFor(
        store,
        _StubSlicer(const SlicerFailed(SlicerFailureCause.networkUnreachable)),
      ).read();
      expect((view as DispenserDealt).card.id, chunkSeedId);
      expect(view.card.origin, Origin.shipped);
      expect(view.autoRescueDue, isTrue);
      expect(view.rescueStep, isFalse);
    });
  });

  group('the purge comes first (Story 6.1, FR-19, UX-DR31)', () {
    /// An activated organizing group's slice as pool-fact records —
    /// the seasonal group's own dormant shape, activated: the scan
    /// landing's shape (cloud origin, no `rescueOf`, `stepText` set)
    /// with an `epic_activated` row naming the stable id.
    List<PoolFactRecord> epicFacts() => [
      (
        id: 's1',
        origin: Origin.cloud,
        size: sizeOfEstimateSeconds(180),
        instantUtcMicros: DateTime.utc(2026, 8, 28, 9).microsecondsSinceEpoch,
        offsetSeconds: 0,
        originContext: 'el trastero del fondo',
        dictated: null,
        rescueOf: null,
        estimateSeconds: 180,
        stepText: 'Recoger las cajas',
      ),
      (
        id: 's2',
        origin: Origin.cloud,
        size: sizeOfEstimateSeconds(180),
        instantUtcMicros: DateTime.utc(2026, 8, 28, 9).microsecondsSinceEpoch,
        offsetSeconds: 0,
        originContext: 'el trastero del fondo',
        dictated: null,
        rescueOf: null,
        estimateSeconds: 180,
        stepText: 'Etiquetar los archivadores',
      ),
    ];

    LogEntryRecord epicActivatedRow() => (
      id: 'seed-epic-activated',
      kind: 'epic_activated',
      instantUtcMicros: DateTime.utc(2026, 8, 29, 10).microsecondsSinceEpoch,
      offsetSeconds: 0,
      itemId: 's1',
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
      beforeName: null,
      afterName: null,
    );

    _RecordingStore activatedStore() => _RecordingStore(epicFacts())
      ..entries.add(_answeredWeek(weekOfAug17, 'seed-week-answered'))
      ..entries.add(_installOpen())
      ..entries.add(epicActivatedRow());

    test('the launch deal over a newly activated group is its purge — '
        'an ordinary DispenserDealt whose discriminator is the shell\'s '
        'only routing signal, and the authored text is the ARB\'s own '
        'copy', () async {
      final store = activatedStore();
      final dealt = await openSessionAndReadFirstDeal(store);

      expect(dealt.card.id, '${purgeItemIdPrefix}s1');
      expect(dealt.card.name, AppStringsEs().purgeStepText);
      expect(dealt.card.size, Size.instant);
      expect(dealt.card.origin, Origin.cloud);
      expect(dealt.card.estimateSeconds, purgeStepEstimateSeconds);
      expect(dealt.card.zone, isNull);
      expect(dealt.purgeStep, isTrue);
      expect(dealt.rescueStep, isFalse);
      expect(dealt.autoRescueDue, isFalse);
      // The launch rows: the seeded opening rows, then the open,
      // the session, the purge deal.
      expect(store.entries.map((entry) => entry.kind).toList(), [
        'report_answered',
        'app_opened',
        'epic_activated',
        'app_opened',
        'session_started',
        'card_dealt',
      ]);
      expect(store.entries.last.itemId, '${purgeItemIdPrefix}s1');
      expect(store.entries.last.itemOrigin, Origin.cloud);
    });

    test('a standing purge card survives reads — the read path '
        're-materializes the card, not the resolver\'s fresh choice '
        '(AD-3)', () async {
      final store = activatedStore();
      await openSessionAndReadFirstDeal(store);
      final controller = DispenserController(
        store: store,
        strings: AppStringsEs(),
        bundle: _FakeBundle({catalogueAssetPath: shipped}),
        nowOf: _fixedClock,
      );
      final view = (await controller.read()) as DispenserDealt;
      expect(view.card.id, '${purgeItemIdPrefix}s1');
      expect(view.purgeStep, isTrue);
      // Re-reading wrote nothing: no second deal, no answer.
      expect(
        store.entries.where((entry) => entry.kind == 'card_dealt'),
        hasLength(1),
      );
    });

    test('complete appends exactly one card_done on the purge id and '
        'the bundled next deal is the group\'s head step — the '
        'existing complete path, no new append site', () async {
      final store = activatedStore();
      final dealt = await openSessionAndReadFirstDeal(store);
      final controller = DispenserController(
        store: store,
        strings: AppStringsEs(),
        bundle: _FakeBundle({catalogueAssetPath: shipped}),
        nowOf: _fixedClock,
      );
      await controller.complete(dealt);

      final done = store.entries
          .where((entry) => entry.kind == 'card_done')
          .toList();
      expect(done, hasLength(1));
      expect(done.single.itemId, '${purgeItemIdPrefix}s1');
      expect(done.single.itemOrigin, Origin.cloud);
      final nextDealRow = store.entries.last;
      expect(nextDealRow.kind, 'card_dealt');
      expect(
        nextDealRow.itemId,
        's1',
        reason: 'the purge closed, the organization steps begin',
      );
    });

    test(
      'triageAndComplete appends the ordered act — item_triaged, then '
      'card_done on the purge id, then the bundled next card_dealt, all '
      'stamped from the one act instant (Story 6.4, FR-20/22, AD-3/21)',
      () async {
        final store = activatedStore();
        final dealt = await openSessionAndReadFirstDeal(store);
        final controller = DispenserController(
          store: store,
          strings: AppStringsEs(),
          bundle: _FakeBundle({catalogueAssetPath: shipped}),
          nowOf: _fixedClock,
        );

        await controller.triageAndComplete(
          dealt,
          destination: TriageDestination.donate_sell,
          volumeTag: CoarseVolumeTag.caja,
        );

        // The act's three rows, in the act's order, after the launch deal.
        final kinds = store.entries.map((entry) => entry.kind).toList();
        final actAt = kinds.lastIndexOf('item_triaged');
        expect(actAt, 6);
        expect(kinds.sublist(actAt), [
          'item_triaged',
          'card_done',
          'card_dealt',
        ]);
        final triage = store.entries[actAt];
        final done = store.entries[actAt + 1];
        final nextDeal = store.entries[actAt + 2];
        expect(triage.triageDestination, 'donate_sell');
        expect(triage.triageVolumeTag, 'caja');
        expect(triage.itemId, isNull, reason: 'the triaged object is physical');
        expect(done.itemId, '${purgeItemIdPrefix}s1');
        expect(done.itemOrigin, Origin.cloud);
        expect(nextDeal.itemId, 's1');
        // One act instant serves the whole trio — the entry mint.
        expect(triage.instantUtcMicros, done.instantUtcMicros);
        expect(done.instantUtcMicros, nextDeal.instantUtcMicros);
        expect(triage.instantUtcMicros, _fixedClock().microsecondsSinceEpoch);
        // A distinct v7 id per row.
        expect(triage.id, matches(v7));
        expect(done.id, matches(v7));
        expect(nextDeal.id, matches(v7));
        expect(triage.id, isNot(done.id));
        expect(done.id, isNot(nextDeal.id));

        // The next read deals the step — the purge is retired.
        final view = await controller.read();
        expect(view, isA<DispenserDealt>());
        expect(
          (view as DispenserDealt).card.id.startsWith(purgeItemIdPrefix),
          isFalse,
        );
      },
    );

    test(
      'a declined tag passes null through — the triage row carries no '
      'tag, and the act still completes (FR-22: declining writes nothing)',
      () async {
        final store = activatedStore();
        final dealt = await openSessionAndReadFirstDeal(store);
        final controller = DispenserController(
          store: store,
          strings: AppStringsEs(),
          bundle: _FakeBundle({catalogueAssetPath: shipped}),
          nowOf: _fixedClock,
        );

        await controller.triageAndComplete(
          dealt,
          destination: TriageDestination.keep,
        );

        final triage = store.entries.firstWhere(
          (entry) => entry.kind == 'item_triaged',
        );
        expect(triage.triageDestination, 'keep');
        expect(triage.triageVolumeTag, isNull);
        expect(
          store.entries.where((entry) => entry.kind == 'card_done'),
          hasLength(1),
        );
      },
    );

    test('a stale double act is a no-op — the second call on the answered '
        'card appends nothing at all, no orphan triage row either '
        '(cardDone\'s answered-guard, decided before any append)', () async {
      final store = activatedStore();
      final dealt = await openSessionAndReadFirstDeal(store);
      final controller = DispenserController(
        store: store,
        strings: AppStringsEs(),
        bundle: _FakeBundle({catalogueAssetPath: shipped}),
        nowOf: _fixedClock,
      );
      await controller.triageAndComplete(
        dealt,
        destination: TriageDestination.keep,
      );
      final afterAct = List.of(store.entries);

      await controller.triageAndComplete(
        dealt,
        destination: TriageDestination.trash_recycle,
      );

      expect(store.entries, orderedEquals(afterAct));
      expect(
        store.entries.where((entry) => entry.kind == 'item_triaged'),
        hasLength(1),
      );
    });

    test('a mid-batch failure leaves the triage row standing and the '
        're-entry retry appends a second one beside it — the same '
        'partial-act exposure every multi-row act has, tolerated under '
        'FR-22\'s approximate cumulative counts (the appends are '
        'sequential, not transactional)', () async {
      final inner = activatedStore();
      final dealt = await openSessionAndReadFirstDeal(inner);
      final store = _FailAfterTriageStore(inner);
      final controller = DispenserController(
        store: store,
        strings: AppStringsEs(),
        bundle: _FakeBundle({catalogueAssetPath: shipped}),
        nowOf: _fixedClock,
      );

      // The triage append lands; the completion append throws.
      await expectLater(
        controller.triageAndComplete(
          dealt,
          destination: TriageDestination.keep,
        ),
        throwsStateError,
      );

      // The orphan stands: one item_triaged, no card_done — and the
      // orphan itself is the log's last row (it landed after the
      // seeded deal, and nothing behind the thrown completion did).
      expect(
        inner.entries.where((entry) => entry.kind == 'item_triaged'),
        hasLength(1),
      );
      expect(
        inner.entries.where((entry) => entry.kind == 'card_done'),
        isEmpty,
      );
      expect(inner.entries.last.kind, 'item_triaged');

      // The re-entry retry on the still-live card appends its own full
      // trio — a second triage row beside the orphan, tolerated under
      // the approximate-counts rule.
      await controller.triageAndComplete(
        dealt,
        destination: TriageDestination.keep,
      );
      final kinds = inner.entries.map((entry) => entry.kind).toList();
      final actAt = kinds.lastIndexOf('item_triaged');
      expect(kinds.sublist(actAt), ['item_triaged', 'card_done', 'card_dealt']);
      expect(
        inner.entries.where((entry) => entry.kind == 'item_triaged'),
        hasLength(2),
        reason:
            'the orphan plus the retry\'s own row — approximate '
            'cumulative counts absorb the double',
      );
    });

    test(
      'triageAndComplete throws AssertionError if destination is quarantine — '
      'quarantine completions must go through quarantineAndComplete',
      () async {
        final store = activatedStore();
        final dealt = await openSessionAndReadFirstDeal(store);
        final controller = DispenserController(
          store: store,
          strings: AppStringsEs(),
          bundle: _FakeBundle({catalogueAssetPath: shipped}),
          nowOf: _fixedClock,
        );
        expect(
          () => controller.triageAndComplete(
            dealt,
            destination: TriageDestination.quarantine,
          ),
          throwsA(isA<AssertionError>()),
        );
      },
    );

    test('quarantineAndComplete appends the ordered act — box_created, then '
        'item_triaged carrying quarantine and the box\'s own pre-minted id, '
        'then card_done on the purge id, then the bundled next card_dealt, '
        'all stamped from the one act instant and carrying no tag whatever '
        'the visit handed off (Story 6.5, FR-21/22, AD-3/21)', () async {
      final store = activatedStore();
      final dealt = await openSessionAndReadFirstDeal(store);
      final controller = DispenserController(
        store: store,
        strings: AppStringsEs(),
        bundle: _FakeBundle({catalogueAssetPath: shipped}),
        nowOf: _fixedClock,
      );

      await controller.quarantineAndComplete(dealt);

      // The act's four rows, in the act's order, after the launch deal.
      final kinds = store.entries.map((entry) => entry.kind).toList();
      final boxAt = kinds.lastIndexOf('box_created');
      expect(boxAt, 6);
      expect(kinds.sublist(boxAt), [
        'box_created',
        'item_triaged',
        'card_done',
        'card_dealt',
      ]);
      final box = store.entries[boxAt];
      final triage = store.entries[boxAt + 1];
      final done = store.entries[boxAt + 2];
      final nextDeal = store.entries[boxAt + 3];
      // The box row is payload-less: its id and instant ARE the box.
      expect(box.itemId, isNull);
      expect(box.triageDestination, isNull);
      expect(box.triageVolumeTag, isNull);
      expect(box.triageBoxId, isNull);
      expect(box.id, matches(v7));
      // The triage row links the box by its own id and carries no tag.
      expect(triage.triageDestination, 'quarantine');
      expect(triage.triageBoxId, box.id);
      expect(
        triage.triageVolumeTag,
        isNull,
        reason:
            'a quarantined object liberates nothing — the tag the '
            'visit handed off writes nothing on this act',
      );
      expect(triage.itemId, isNull);
      expect(done.itemId, '${purgeItemIdPrefix}s1');
      expect(nextDeal.itemId, 's1');
      // One act instant serves the whole quartet — the entry mint.
      expect(box.instantUtcMicros, triage.instantUtcMicros);
      expect(triage.instantUtcMicros, done.instantUtcMicros);
      expect(done.instantUtcMicros, nextDeal.instantUtcMicros);
      expect(box.instantUtcMicros, _fixedClock().microsecondsSinceEpoch);
      // A distinct v7 id per row, the box row's id being the one
      // the triage row names — the pre-minted link, threaded once.
      expect(triage.id, matches(v7));
      expect(done.id, matches(v7));
      expect(nextDeal.id, matches(v7));
      expect(box.id, isNot(triage.id));
      expect(triage.id, isNot(done.id));

      // The next read deals the step — the purge is retired, and the
      // derivation reconstructs exactly one dated box holding one row.
      final view = await controller.read();
      expect(view, isA<DispenserDealt>());
      final boxes = deriveQuarantine(
        logEntriesOf(await store.readLogEntries()),
      );
      expect(boxes, hasLength(1));
      expect(boxes.single.id, box.id);
      expect(boxes.single.instantUtcMicros, box.instantUtcMicros);
      expect(boxes.single.contents, hasLength(1));
      expect(boxes.single.contents.single.id, triage.id);
    });

    test('a stale double quarantine act is a no-op — the second call on '
        'the answered card appends nothing at all, no orphan box row '
        'either (the guard is decided before any append)', () async {
      final store = activatedStore();
      final dealt = await openSessionAndReadFirstDeal(store);
      final controller = DispenserController(
        store: store,
        strings: AppStringsEs(),
        bundle: _FakeBundle({catalogueAssetPath: shipped}),
        nowOf: _fixedClock,
      );
      await controller.quarantineAndComplete(dealt);
      final afterAct = List.of(store.entries);

      await controller.quarantineAndComplete(dealt);

      expect(store.entries, orderedEquals(afterAct));
      expect(
        store.entries.where((entry) => entry.kind == 'box_created'),
        hasLength(1),
      );
      expect(
        store.entries.where((entry) => entry.kind == 'item_triaged'),
        hasLength(1),
      );
    });

    test('a mid-batch failure after the box row leaves the pair standing '
        'and the re-entry retry appends a fresh box beside them — the '
        'same partial-act exposure every multi-row act has, and the '
        'orphan box reconstructs as an honest empty box', () async {
      final inner = activatedStore();
      final dealt = await openSessionAndReadFirstDeal(inner);
      final store = _FailAfterTriageStore(inner);
      final controller = DispenserController(
        store: store,
        strings: AppStringsEs(),
        bundle: _FakeBundle({catalogueAssetPath: shipped}),
        nowOf: _fixedClock,
      );

      // The box and triage appends land; the completion append throws.
      await expectLater(
        controller.quarantineAndComplete(dealt),
        throwsStateError,
      );

      // The orphan pair stands: one box, one quarantine row linking
      // it, no card_done — the partial-act class, tolerated.
      expect(
        inner.entries.where((entry) => entry.kind == 'box_created'),
        hasLength(1),
      );
      expect(
        inner.entries.where((entry) => entry.kind == 'item_triaged'),
        hasLength(1),
      );
      expect(
        inner.entries.where((entry) => entry.kind == 'card_done'),
        isEmpty,
      );
      final orphanBoxId = inner.entries
          .firstWhere((entry) => entry.kind == 'box_created')
          .id;
      expect(
        inner.entries
            .firstWhere((entry) => entry.kind == 'item_triaged')
            .triageBoxId,
        orphanBoxId,
      );

      // The re-entry retry on the still-live card appends its own
      // full act — a FRESH box beside the orphan pair, never a
      // second content row on the orphaned box.
      await controller.quarantineAndComplete(dealt);
      final kinds = inner.entries.map((entry) => entry.kind).toList();
      final retryBoxAt = kinds.lastIndexOf('box_created');
      expect(kinds.sublist(retryBoxAt), [
        'box_created',
        'item_triaged',
        'card_done',
        'card_dealt',
      ]);
      final retryBoxId = inner.entries[retryBoxAt].id;
      expect(retryBoxId, isNot(orphanBoxId));
      expect(
        inner.entries
            .lastWhere((entry) => entry.kind == 'item_triaged')
            .triageBoxId,
        retryBoxId,
      );
      // And the derivation reads both boxes: the orphan holding its
      // linked row, the retry's holding its own — distinct, honest,
      // coarse (any date-collapse is 6.6's concern, never a write).
      final boxes = deriveQuarantine(
        logEntriesOf(await inner.readLogEntries()),
      );
      expect(boxes, hasLength(2));
      expect(
        boxes.map((box) => box.id),
        containsAll([orphanBoxId, retryBoxId]),
      );
      expect(boxes.every((box) => box.contents.length == 1), isTrue);
    });

    test('a mid-batch failure between the box row and its triage row '
        'leaves the lone box standing — the orphan reconstructs as an '
        'honest empty box and the re-entry retry appends a fresh one '
        'beside it (the tolerated partial-act class\'s other half)', () async {
      final inner = activatedStore();
      final dealt = await openSessionAndReadFirstDeal(inner);
      final store = _FailAfterBoxStore(inner);
      final controller = DispenserController(
        store: store,
        strings: AppStringsEs(),
        bundle: _FakeBundle({catalogueAssetPath: shipped}),
        nowOf: _fixedClock,
      );

      // The box append lands; the triage append throws.
      await expectLater(
        controller.quarantineAndComplete(dealt),
        throwsStateError,
      );

      // The orphan stands ALONE: one box_created, no quarantine row,
      // no completion — and the derivation reads it back as the
      // honest, coarse empty box it is.
      final orphanBoxId = inner.entries
          .firstWhere((entry) => entry.kind == 'box_created')
          .id;
      expect(
        inner.entries.where((entry) => entry.kind == 'box_created'),
        hasLength(1),
      );
      expect(
        inner.entries.where((entry) => entry.kind == 'item_triaged'),
        isEmpty,
      );
      expect(
        inner.entries.where((entry) => entry.kind == 'card_done'),
        isEmpty,
      );
      final orphanBoxes = deriveQuarantine(
        logEntriesOf(await inner.readLogEntries()),
      );
      expect(orphanBoxes, hasLength(1));
      expect(orphanBoxes.single.id, orphanBoxId);
      expect(orphanBoxes.single.contents, isEmpty);

      // The re-entry retry on the still-live card appends its own
      // fresh box and the whole act behind it — never a content row
      // on the orphaned box.
      await controller.quarantineAndComplete(dealt);
      final kinds = inner.entries.map((entry) => entry.kind).toList();
      final retryBoxAt = kinds.lastIndexOf('box_created');
      expect(kinds.sublist(retryBoxAt), [
        'box_created',
        'item_triaged',
        'card_done',
        'card_dealt',
      ]);
      final retryBoxId = inner.entries[retryBoxAt].id;
      expect(retryBoxId, isNot(orphanBoxId));
      // Two boxes after the retry: the orphan honestly empty, the
      // retry's holding its own row — distinct, never collapsed.
      final boxes = deriveQuarantine(
        logEntriesOf(await inner.readLogEntries()),
      );
      expect(boxes, hasLength(2));
      expect(boxes.first.id, orphanBoxId);
      expect(boxes.first.contents, isEmpty);
      expect(boxes.last.id, retryBoxId);
      expect(boxes.last.contents, hasLength(1));
    });

    test('skip appends exactly one card_skipped on the purge id — the '
        'purge closes for good and never re-deals', () async {
      final store = activatedStore();
      final dealt = await openSessionAndReadFirstDeal(store);
      final controller = DispenserController(
        store: store,
        strings: AppStringsEs(),
        bundle: _FakeBundle({catalogueAssetPath: shipped}),
        nowOf: _fixedClock,
      );
      await controller.skip(dealt);

      final skipped = store.entries
          .where((entry) => entry.kind == 'card_skipped')
          .toList();
      expect(skipped, hasLength(1));
      expect(skipped.single.itemId, '${purgeItemIdPrefix}s1');
      expect(store.entries.last.kind, 'card_dealt');
      expect(store.entries.last.itemId, 's1');
      // The next read deals a step, never the purge again.
      final view = await controller.read();
      expect(view, isA<DispenserDealt>());
      expect(
        (view as DispenserDealt).card.id.startsWith(purgeItemIdPrefix),
        isFalse,
        reason: 'no nagging: a skipped purge never returns',
      );
    });

    test('a purge left standing by a pause re-deals through the '
        'declared pocket — the bundled card_dealt names the purge id '
        '(the nullable seam, pinned: the pause cleared the standing '
        'card, so the deal is the resolver\'s fresh choice)', () async {
      final store = activatedStore();
      await openSessionAndReadFirstDeal(store);
      // A movable clock, the `nowOf: () => now` precedent: at the '
      // frozen instant the pause\'s `session_ended` and the '
      // declaration\'s `session_started` would share an instant and '
      // the walk would read the accidental pair as a supersede — '
      // holding the standing card and suppressing the bundled deal.
      // Distinct instants keep the end an end.
      var now = _fixedClock();
      final controller = buildFor(store, nowOf: () => now);
      now = now.add(const Duration(seconds: 30));
      await controller.pause();
      now = now.add(const Duration(seconds: 30));

      final view = await controller.declarePocket(5);

      // The seeded rows, the launch sitting (open, session, purge
      // deal), its end, and the declaration's fresh sitting — whose
      // bundled deal is the purge again, 60 s against a 300 s pocket.
      expect(store.entries.map((entry) => entry.kind).toList(), [
        'report_answered',
        'app_opened',
        'epic_activated',
        'app_opened',
        'session_started',
        'card_dealt',
        'session_ended',
        'session_started',
        'card_dealt',
      ]);
      expect(store.entries.last.kind, 'card_dealt');
      expect(store.entries.last.itemId, '${purgeItemIdPrefix}s1');
      expect(store.entries.last.itemOrigin, Origin.cloud);
      expect(view, isA<DispenserDealt>());
      expect((view as DispenserDealt).card.id, '${purgeItemIdPrefix}s1');
      expect(view.pocketMinutes, 5);
    });

    test('a 1-minute pocket still admits the purge — its 60 s meets '
        'the declared ceiling exactly, through the same bundled '
        'deal (matrix: minimal pocket)', () async {
      final store = activatedStore();
      await openSessionAndReadFirstDeal(store);
      // The same movable clock as the 5-minute pin: no accidental
      // supersede pair, and the declare lands 30 s before its own
      // 1-minute deadline — the ceiling is what the pin reads.
      var now = _fixedClock();
      final controller = buildFor(store, nowOf: () => now);
      now = now.add(const Duration(seconds: 30));
      await controller.pause();
      now = now.add(const Duration(seconds: 30));

      final view = await controller.declarePocket(1);

      expect(store.entries.last.kind, 'card_dealt');
      expect(store.entries.last.itemId, '${purgeItemIdPrefix}s1');
      expect((view as DispenserDealt).card.id, '${purgeItemIdPrefix}s1');
      expect(view.pocketMinutes, 1);
    });

    test(
      'controller.extend() with no unanswered card deals the pending '
      'purge — extending bundles the pre-clean step (Story 6.1 review)',
      () async {
        final store = activatedStore();
        store.entries.add(
          _pocketedStart(DateTime.utc(2026, 8, 29, 11, 55), 20),
        );
        final controller = buildFor(store, nowOf: _fixedClock);

        final view = await controller.extend();

        expect(store.entries.last.kind, 'card_dealt');
        expect(store.entries.last.itemId, '${purgeItemIdPrefix}s1');
        expect(view, isA<DispenserDealt>());
        expect((view as DispenserDealt).card.id, '${purgeItemIdPrefix}s1');
      },
    );
  });
}

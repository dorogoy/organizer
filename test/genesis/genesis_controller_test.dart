// The genesis controller's contract (Story 5.8, FR-11, FR-25,
// FR-26 b, FR-29): the frozen I/O matrix, row by row, over fakes —
// the scan suite's own group shapes on the typed channel's own
// terms. The `Analizar` act's whole chain (the guards, the one
// consent_granted row, the one token-free dispatch, the landing's
// 5.7 discipline), the failure arms (the raw cause, the
// malformedResponse fold, the throw's providerUnreachable fold),
// the wait's abandonment (exactly one scan_abandoned on a close
// mid-dispatch, nothing on a close after the resolution), and the
// epoch guards (a late landing records nothing, lands nothing).
// The controller is binding-free: plain tests, no pumping.
import 'dart:async';

import 'package:core/ports/slicer_port.dart';
import 'package:core/ports/store_port.dart';
import 'package:core/pool/pool_fact.dart';
import 'package:core/slicer/scan_steps.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uuid/uuid.dart';

import 'package:organizer/egress/local_slicer.dart';
import 'package:organizer/genesis/genesis_controller.dart';
import 'package:organizer/session/log_write_queue.dart';

/// The recording store (the scan suite's own contract).
class _RecordingStore implements StorePort {
  final List<PoolFactRecord> facts = [];
  final List<LogEntryRecord> entries = [];

  /// Optional brake on the append: when set, the next append parks on
  /// this completer — the race tests' window for landing a close
  /// mid-write.
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

/// A store whose `appendLogEntry` always throws — the
/// quiet-absorption queue path's own row (the scan suite's
/// precedent).
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

/// A store whose `appendPoolFact` throws on its SECOND call — the
/// landing's partial-plan window (the first fact stands, the rest
/// dies).
class _ThrowingFactStore implements StorePort {
  _ThrowingFactStore(this._inner);

  final _RecordingStore _inner;
  var _appended = 0;

  @override
  Future<void> appendPoolFact(PoolFactRecord fact) async {
    _appended++;
    if (_appended >= 2) {
      throw StateError('append failed');
    }
    await _inner.appendPoolFact(fact);
  }

  @override
  Future<void> appendLogEntry(LogEntryRecord entry) async =>
      _inner.appendLogEntry(entry);

  @override
  Future<List<PoolFactRecord>> readPoolFacts() async => _inner.readPoolFacts();

  @override
  Future<List<LogEntryRecord>> readLogEntries() async =>
      _inner.readLogEntries();
}

/// A canonical scan-shaped delivered body — two steps, the contract
/// the genesis prompt pins (one parser, both entrances).
const String _scanBody =
    '{"description": "El trastero ordenado", "steps": '
    '[{"text": "Recoger una caja", "duration_minutes": 3},'
    '{"text": "Etiquetar los archivadores", "duration_minutes": 5}]}';

/// The Slicer fake: the requests the tests read, the outcome the
/// tests steer, and an in-flight window the close epoch races
/// against.
class _FakeSlicer implements SlicerPort {
  _FakeSlicer({SlicerOutcome? outcome})
    : outcome = outcome ?? const SlicerDelivered(_scanBody);

  SlicerOutcome outcome;

  /// When set, [slice] throws — a malfunctioning seam, never a
  /// taxonomy value.
  Object? throwOnSlice;
  final requests = <GenesisSliceRequest>[];
  Completer<void>? gate;
  Completer<void>? sliceStarted;

  @override
  Future<SlicerOutcome> slice(SlicerRequest request) async {
    requests.add(request as GenesisSliceRequest);
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

DateTime _fixedClock() => DateTime.utc(2026, 9, 7, 10);

void main() {
  group('analyze — the Analizar act (Story 5.8, FR-25, AD-8)', () {
    test('a blank description is nothing at all: no row, no dispatch '
        '(the disabled pill\'s own guard, restated for any caller the '
        'pill cannot speak for)', () async {
      final store = _RecordingStore();
      final slicer = _FakeSlicer();
      final controller = GenesisController(
        store: store,
        slicer: slicer,
        nowOf: _fixedClock,
      );
      for (final blank in ['', '   ', '\t\n ']) {
        expect(await controller.analyze(blank), isA<GenesisStale>());
      }
      expect(store.entries, isEmpty);
      expect(slicer.requests, isEmpty);
    });

    test('the happy path: one consent_granted row, exactly one '
        'token-free dispatch whose text is the composed prompt, the '
        'steps landed as facts with the description as Origin Context — '
        'and nothing dealt (Story 5.7\'s landing verbatim, FR-16, '
        'FR-26 b)', () async {
      final store = _RecordingStore();
      final slicer = _FakeSlicer();
      final controller = GenesisController(
        store: store,
        slicer: slicer,
        idMinter: const Uuid(),
        nowOf: _fixedClock,
      );
      final outcome = await controller.analyze('Ordenar el trastero');
      expect(outcome, isA<GenesisDelivered>());
      // The act's one row, payload-less, the scan channel's own
      // minter.
      expect(store.entries.map((entry) => entry.kind), ['consent_granted']);
      final row = store.entries.single;
      expect(row.itemId, isNull);
      expect(row.sliceCause, isNull);
      expect(row.permission, isNull);
      expect(row.instantUtcMicros, _fixedClock().microsecondsSinceEpoch);
      // The one dispatch: a genesis request carrying the composed
      // prompt — instruction + the user's description + the scan JSON
      // contract.
      expect(slicer.requests, hasLength(1));
      final request = slicer.requests.single;
      expect(request.text, contains('Ordenar el trastero'));
      // The prompt parity pin: the JSON shape the prompt shows carries
      // the four wire names the core parse owns — a renamed field in
      // either direction fails here.
      expect(request.text, contains('"$scanWireDescriptionField"'));
      expect(request.text, contains('"$scanWireStepsField"'));
      expect(request.text, contains('"$scanWireTextField"'));
      expect(request.text, contains('"$scanWireDurationField"'));
      expect(request.text, contains('"description"'));
      expect(request.text, contains('"duration_minutes"'));
      // The shared-contract pin (Story 5.8's review): the prompt ends
      // with the ONE core-owned sentence the scan prompt also
      // interpolates — a phrasing drift between the two entrances'
      // provider contracts fails here.
      expect(request.text, endsWith('. $scanResponseContract'));
      // The landing: one fact per parsed step, in the body's own
      // order, the description as the Origin Context every step
      // shares.
      expect(store.facts, hasLength(2));
      final instant = _fixedClock().microsecondsSinceEpoch;
      final ids = <String>{};
      for (var i = 0; i < store.facts.length; i++) {
        final fact = store.facts[i];
        expect(fact.id, isNotEmpty);
        ids.add(fact.id);
        // A fake Slicer is the BYOK path: the cloud origin, set at
        // genesis.
        expect(fact.origin, Origin.cloud);
        // The ONE banding: 180–300 s is maintenance, by construction.
        expect(fact.size, Size.maintenance);
        expect(fact.estimateSeconds, [180, 300][i]);
        expect(fact.originContext, 'El trastero ordenado');
        expect(
          fact.stepText,
          ['Recoger una caja', 'Etiquetar los archivadores'][i],
        );
        expect(fact.dictated, isNull);
        expect(fact.rescueOf, isNull);
        expect(fact.instantUtcMicros, instant);
        expect(fact.offsetSeconds, _fixedClock().timeZoneOffset.inSeconds);
      }
      expect(ids, hasLength(2), reason: 'one shell-minted id per fact');
    });

    test('the Local stub delivers the local origin — the debug path '
        'mints cloud nowhere (FR-16)', () async {
      final store = _RecordingStore();
      const slicer = LocalSlicer(cannedMarker: 'marca local');
      final controller = GenesisController(
        store: store,
        slicer: slicer,
        idMinter: const Uuid(),
        nowOf: _fixedClock,
      );
      expect(
        await controller.analyze('Ordenar el trastero'),
        isA<GenesisDelivered>(),
      );
      expect(store.facts, hasLength(2));
      for (final fact in store.facts) {
        expect(fact.origin, Origin.local);
        expect(fact.size, Size.maintenance);
        expect(fact.estimateSeconds, inInclusiveRange(180, 300));
        expect(fact.originContext, 'marca local');
        expect(fact.stepText, 'marca local');
      }
    });

    test('a delivered body that violates the step contract folds into '
        'the declared mapping: one slice_failed row under '
        'malformedResponse, the failed outcome, nothing dealt, never '
        'an eighth cause (FR-16, FR-29, AD-21)', () async {
      final store = _RecordingStore();
      // Parses as JSON, violates the contract: no description.
      final slicer = _FakeSlicer()
        ..outcome = const SlicerDelivered(
          '{"steps": [{"text": "Recoger", "duration_minutes": 4}]}',
        );
      final controller = GenesisController(
        store: store,
        slicer: slicer,
        nowOf: _fixedClock,
      );
      final outcome = await controller.analyze('Ordenar el trastero');
      expect(outcome, isA<GenesisFailed>());
      expect(
        (outcome as GenesisFailed).cause,
        SlicerFailureCause.malformedResponse,
      );
      expect(store.facts, isEmpty, reason: 'a violating body lands nothing');
      expect(store.entries.map((entry) => entry.kind), [
        'consent_granted',
        'slice_failed',
      ]);
      final row = store.entries[1];
      expect(row.itemId, isNull);
      expect(row.itemOrigin, isNull);
      expect(row.sliceCause, 'malformedResponse');
      expect(row.permission, isNull);
      expect(row.settingKey, isNull);
      expect(row.instantUtcMicros, _fixedClock().microsecondsSinceEpoch);
    });

    test('a failed dispatch surfaces the raw cause for the standing '
        'map and its one slice_failed row — the 4-5 mapping consumes '
        'it unchanged (FR-26 b)', () async {
      final store = _RecordingStore();
      final slicer = _FakeSlicer()
        ..outcome = const SlicerFailed(SlicerFailureCause.invalidKey);
      final controller = GenesisController(
        store: store,
        slicer: slicer,
        nowOf: _fixedClock,
      );
      final outcome = await controller.analyze('Ordenar el trastero');
      expect(outcome, isA<GenesisFailed>());
      expect((outcome as GenesisFailed).cause, SlicerFailureCause.invalidKey);
      expect(store.entries.map((entry) => entry.kind), [
        'consent_granted',
        'slice_failed',
      ]);
      expect(store.entries[1].sliceCause, 'invalidKey');
      expect(store.entries[1].itemId, isNull);
      expect(store.facts, isEmpty);
    });

    test('a throwing slicer seam is contained: the '
        'provider-unreachable fold, its row on record, no crash (the '
        'scan path\'s own containment)', () async {
      final store = _RecordingStore();
      final slicer = _FakeSlicer()..throwOnSlice = StateError('seam threw');
      final controller = GenesisController(
        store: store,
        slicer: slicer,
        nowOf: _fixedClock,
      );
      final outcome = await controller.analyze('Ordenar el trastero');
      expect(outcome, isA<GenesisFailed>());
      expect(
        (outcome as GenesisFailed).cause,
        SlicerFailureCause.providerUnreachable,
      );
      expect(slicer.requests, hasLength(1));
      expect(store.entries.map((entry) => entry.kind), [
        'consent_granted',
        'slice_failed',
      ]);
      expect(store.entries[1].sliceCause, 'providerUnreachable');
      expect(store.facts, isEmpty);
    });

    test('a rapid second act is nothing at all — one send exists: no '
        'second row, no second dispatch (the wait owns the seam)', () async {
      final store = _RecordingStore();
      final slicer = _FakeSlicer()..gate = Completer<void>();
      final controller = GenesisController(
        store: store,
        slicer: slicer,
        nowOf: _fixedClock,
      );
      final first = controller.analyze('Ordenar el trastero');
      expect(await controller.analyze('Otra cosa'), isA<GenesisStale>());
      slicer.gate!.complete();
      expect(await first, isA<GenesisDelivered>());
      expect(slicer.requests, hasLength(1));
      expect(store.entries.map((entry) => entry.kind), ['consent_granted']);
    });

    test('no slicer behind the test seam: the act folds closed — '
        'nothing half-wired dispatches, no row', () async {
      final store = _RecordingStore();
      final controller = GenesisController(store: store, nowOf: _fixedClock);
      expect(
        await controller.analyze('Ordenar el trastero'),
        isA<GenesisStale>(),
      );
      expect(store.entries, isEmpty);
    });

    test('a fresh analyze after a resolution owns the seam again — the '
        'controller is a root singleton, reused surface to surface', () async {
      final store = _RecordingStore();
      final slicer = _FakeSlicer();
      final controller = GenesisController(
        store: store,
        slicer: slicer,
        idMinter: const Uuid(),
        nowOf: _fixedClock,
      );
      expect(
        await controller.analyze('Ordenar el trastero'),
        isA<GenesisDelivered>(),
      );
      expect(
        await controller.analyze('Colgar los cuadros'),
        isA<GenesisDelivered>(),
      );
      expect(slicer.requests, hasLength(2));
      expect(store.entries.map((entry) => entry.kind), [
        'consent_granted',
        'consent_granted',
      ]);
      expect(store.facts, hasLength(4));
    });
  });

  group('the wait — abandonment and the epoch guards (Story 5.6\'s '
      'discipline, FR-16, AD-8)', () {
    test('a close mid-dispatch mints exactly one scan_abandoned row and '
        'turns the late resolution into a stale answer: no routing '
        'data, no facts, the act\'s rows the only two (the departure '
        'is the resolution cause)', () async {
      final store = _RecordingStore();
      final slicer = _FakeSlicer()..gate = Completer<void>();
      final controller = GenesisController(
        store: store,
        slicer: slicer,
        nowOf: _fixedClock,
      );
      final analyzing = controller.analyze('Ordenar el trastero');
      await controller.close();
      slicer.gate!.complete();
      expect(await analyzing, isA<GenesisStale>());
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
      // The delivered body that answered after the close is discarded
      // whole — no facts, no slice_failed row.
      expect(store.facts, isEmpty);
    });

    test('a close landing while the consent_granted append stands '
        'dispatches NOTHING — cancelled and discarded: zero slice '
        'calls (no egress), and the rows are exactly the act\'s and '
        'the departure\'s (the pre-dispatch epoch re-check)', () async {
      final appendBrake = Completer<void>();
      final store = _RecordingStore()..appendGate = appendBrake;
      final slicer = _FakeSlicer();
      final controller = GenesisController(
        store: store,
        slicer: slicer,
        nowOf: _fixedClock,
      );
      final analyzing = controller.analyze('Ordenar el trastero');
      // The act's own row parks on the store's brake: the departure
      // lands mid-append, behind it on the shared queue.
      await Future<void>.delayed(Duration.zero);
      final closing = controller.close();
      appendBrake.complete();
      await closing;
      expect(await analyzing, isA<GenesisStale>());
      expect(
        slicer.requests,
        isEmpty,
        reason: 'a departure must not be followed by egress',
      );
      expect(store.entries.map((entry) => entry.kind), [
        'consent_granted',
        'scan_abandoned',
      ]);
      expect(store.facts, isEmpty);
    });

    test(
      'a double close mid-wait (the lifecycle release, then the '
      'dispose) mints exactly one scan_abandoned row — the flag '
      'clears with the mint, so close stays idempotent for the row',
      () async {
        final store = _RecordingStore();
        final slicer = _FakeSlicer()..gate = Completer<void>();
        final controller = GenesisController(
          store: store,
          slicer: slicer,
          nowOf: _fixedClock,
        );
        final analyzing = controller.analyze('Ordenar el trastero');
        await controller.close();
        await controller.close();
        slicer.gate!.complete();
        expect(await analyzing, isA<GenesisStale>());
        expect(store.entries.map((entry) => entry.kind), [
          'consent_granted',
          'scan_abandoned',
        ], reason: 'the departure is one act — its row is one row');
        expect(store.facts, isEmpty);
      },
    );

    test('a close after the resolution mints nothing — every analyze '
        'exit clears the in-flight flag, so the delivered arm\'s own '
        'dispose stays rowless', () async {
      final store = _RecordingStore();
      final slicer = _FakeSlicer();
      final controller = GenesisController(
        store: store,
        slicer: slicer,
        nowOf: _fixedClock,
      );
      expect(
        await controller.analyze('Ordenar el trastero'),
        isA<GenesisDelivered>(),
      );
      await controller.close();
      expect(store.entries.map((entry) => entry.kind), [
        'consent_granted',
      ], reason: 'no dispatch stands at the close — no abandonment exists');
    });

    test('a stale resolution cannot clear a newer wait\'s flag after '
        'the controller is reused mid-flight', () async {
      final store = _RecordingStore();
      final oldGate = Completer<void>();
      final slicer = _FakeSlicer()..gate = oldGate;
      final controller = GenesisController(
        store: store,
        slicer: slicer,
        idMinter: const Uuid(),
        nowOf: _fixedClock,
      );
      slicer.sliceStarted = Completer<void>();
      final oldAct = controller.analyze('Ordenar el trastero');
      await slicer.sliceStarted!.future;
      await controller.close();

      // Reuse the singleton controller while the old provider call is
      // still unresolved.
      final newGate = Completer<void>();
      slicer
        ..gate = newGate
        ..sliceStarted = Completer<void>();
      final newAct = controller.analyze('Colgar los cuadros');
      await slicer.sliceStarted!.future;

      // The old stale landing must not clear the new wait's flag.
      oldGate.complete();
      expect(await oldAct, isA<GenesisStale>());
      await controller.close();
      newGate.complete();
      expect(await newAct, isA<GenesisStale>());
      expect(store.entries.map((entry) => entry.kind), [
        'consent_granted',
        'scan_abandoned',
        'consent_granted',
        'scan_abandoned',
      ]);
      expect(store.facts, isEmpty);
    });

    test('a close during terminal persistence abandons the wait and '
        'discards the queued landing', () async {
      final store = _RecordingStore();
      final queue = LogWriteQueue();
      final slicer = _FakeSlicer()..gate = Completer<void>();
      slicer.sliceStarted = Completer<void>();
      final controller = GenesisController(
        store: store,
        slicer: slicer,
        writeQueue: queue,
        nowOf: _fixedClock,
      );
      final analyzing = controller.analyze('Ordenar el trastero');
      await slicer.sliceStarted!.future;

      final blockerGate = Completer<void>();
      final blockerStarted = Completer<void>();
      queue.enqueue(() async {
        blockerStarted.complete();
        await blockerGate.future;
      });
      await blockerStarted.future;

      slicer.gate!.complete();
      await Future<void>.delayed(Duration.zero);
      final closing = controller.close();
      blockerGate.complete();
      await closing;

      expect(await analyzing, isA<GenesisStale>());
      expect(store.entries.map((entry) => entry.kind), [
        'consent_granted',
        'scan_abandoned',
      ]);
      expect(store.facts, isEmpty);
    });

    test('a failing store on the abandonment append is absorbed quietly '
        '— close() mid-dispatch still completes, nothing escapes', () async {
      final inner = _RecordingStore();
      final slicer = _FakeSlicer()..gate = Completer<void>();
      final controller = GenesisController(
        store: _ThrowingAppendStore(inner),
        slicer: slicer,
        nowOf: _fixedClock,
      );
      final analyzing = controller.analyze('Ordenar el trastero');
      await Future<void>.delayed(Duration.zero);
      await controller.close();
      slicer.gate!.complete();
      expect(await analyzing, isA<GenesisStale>());
      expect(inner.entries, isEmpty, reason: 'nothing landed, nothing escaped');
    });

    test('a failing store on the landing\'s fact appends is absorbed '
        'quietly — a delivered body still resolves delivered, and the '
        'partial plan derives honestly', () async {
      final inner = _RecordingStore();
      final slicer = _FakeSlicer();
      final controller = GenesisController(
        store: _ThrowingFactStore(inner),
        slicer: slicer,
        idMinter: const Uuid(),
        nowOf: _fixedClock,
      );
      // The second fact append throws (absorbed): no throw escapes
      // the wait — the outcome is delivered, the one landed fact
      // stands.
      expect(
        await controller.analyze('Ordenar el trastero'),
        isA<GenesisDelivered>(),
      );
      expect(inner.facts, hasLength(1));
    });
  });

  group('the read seam — carried, never called (the surface\'s own '
      'fail-closed read)', () {
    test('the selected-provider read is the surface\'s seam: analyze '
        'never calls it, whatever it answers', () async {
      final store = _RecordingStore();
      var reads = 0;
      final slicer = _FakeSlicer();
      final controller = GenesisController(
        store: store,
        slicer: slicer,
        readSelectedProvider: () async {
          reads++;
          return 'gemini';
        },
        nowOf: _fixedClock,
      );
      expect(
        await controller.analyze('Ordenar el trastero'),
        isA<GenesisDelivered>(),
      );
      expect(
        reads,
        0,
        reason:
            'the provider read runs at the tap, on the '
            'surface — the controller dispatches what it is handed',
      );
    });
  });
}

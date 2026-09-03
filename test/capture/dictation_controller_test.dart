// The dictation seam's contract (Story 3.4, FR-32): the derived
// visibility (probe ∧ granted-or-askable over the log), the press
// flow's session state machine (one terminal outcome per press, stale
// ids dropped), the refusal append through the core's single
// sanctioned minter on the shared queue, and interruption via the
// binding observer — nothing surfaces, ever.
import 'dart:async';

import 'package:core/log/log_entry.dart';
import 'package:core/ports/recognizer_port.dart';
import 'package:core/ports/store_port.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uuid/uuid.dart';

import 'package:organizer/capture/dictation_controller.dart';
import 'package:organizer/session/log_write_queue.dart';

class _FakeRecognizer implements RecognizerPort {
  RecognizerAvailability availability = RecognizerAvailability.unavailable;
  RecognizerStart startOutcome = RecognizerStart.unavailable;
  Object? startError;

  /// When set, `start` pends on this gate — the permission dialog's
  /// own stand, resolved by the test.
  Completer<RecognizerStart>? startGate;

  /// When set, `probe` pends on this gate — the overlapping-refresh
  /// race's own stand, resolved by the test.
  Completer<RecognizerAvailability>? probeGate;

  final List<int> startedSessions = [];
  final List<int> cancelledSessions = [];
  final StreamController<RecognizerOutcome> _outcomes =
      StreamController<RecognizerOutcome>.broadcast();
  int openAppSettingsCalls = 0;

  void emit(int sessionId, String? transcript) {
    _outcomes.add((sessionId: sessionId, transcript: transcript));
  }

  @override
  Future<RecognizerAvailability> probe() async {
    final gate = probeGate;
    if (gate != null) {
      return gate.future;
    }
    return availability;
  }

  @override
  Future<RecognizerStart> start(int sessionId) async {
    startedSessions.add(sessionId);
    if (startError != null) {
      throw startError!;
    }
    final gate = startGate;
    if (gate != null) {
      return gate.future;
    }
    return startOutcome;
  }

  @override
  Future<void> cancel(int sessionId) async => cancelledSessions.add(sessionId);

  @override
  Stream<RecognizerOutcome> get outcomes => _outcomes.stream;

  @override
  Future<void> openAppSettings() async {
    openAppSettingsCalls++;
  }
}

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

void main() {
  late _FakeRecognizer recognizer;
  late _RecordingStore store;
  late List<WidgetsBindingObserver> observers;

  DictationController build() => DictationController(
    store: store,
    recognizer: recognizer,
    writeQueue: LogWriteQueue(),
    idMinter: const Uuid(),
    addObserver: observers.add,
  );

  setUp(() {
    recognizer = _FakeRecognizer();
    store = _RecordingStore();
    observers = [];
  });

  test('visibility derives from the probe and the log: available ∧ '
      '(granted ∨ mayBeAsked) — and defaults to absent while the probe '
      'pends', () async {
    recognizer.availability = RecognizerAvailability.granted;
    final controller = build();
    expect(controller.visible, isFalse, reason: 'absent until probed');
    await Future<void>.delayed(Duration.zero);
    expect(controller.visible, isTrue);

    recognizer.availability = RecognizerAvailability.unavailable;
    final unavailable = build();
    await Future<void>.delayed(Duration.zero);
    expect(
      unavailable.visible,
      isFalse,
      reason: 'unavailable means absent, whatever the permission',
    );

    recognizer.availability = RecognizerAvailability.askable;
    final askable = build();
    await Future<void>.delayed(Duration.zero);
    expect(
      askable.visible,
      isTrue,
      reason: 'askable and never refused: the dialog may be requested',
    );

    final refused = await () async {
      final entries = <LogEntryRecord>[
        (
          id: 'refused-row',
          kind: LogKind.permissionRefused.name,
          instantUtcMicros: 1000,
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
          permission: 'microphone',
        ),
      ];
      return entries;
    }();
    store.entries.addAll(refused);
    final afterRefusal = build();
    await Future<void>.delayed(Duration.zero);
    expect(
      afterRefusal.visible,
      isFalse,
      reason: 'refused and not granted: the affordance is gone',
    );

    recognizer.availability = RecognizerAvailability.granted;
    final regranted = build();
    await Future<void>.delayed(Duration.zero);
    expect(
      regranted.visible,
      isTrue,
      reason:
          'a system re-grant restores visibility through the probe '
          'alone — the log entry stands forever',
    );
  });

  test('the press flow: one press mints one session, listens, and only '
      'the final transcript commits — Guardar\'s enable path is the '
      'field\'s own listener', () async {
    recognizer.availability = RecognizerAvailability.granted;
    recognizer.startOutcome = RecognizerStart.listening;
    final controller = build();
    await Future<void>.delayed(Duration.zero);

    final transcripts = <String>[];
    controller.onTranscript = transcripts.add;

    await controller.press();
    expect(recognizer.startedSessions, [1]);
    expect(controller.listening, isTrue);

    // A second press while listening is nothing at all.
    await controller.press();
    expect(recognizer.startedSessions, [1]);

    recognizer.emit(1, 'llamar al dentista');
    await Future<void>.delayed(Duration.zero);
    expect(transcripts, ['llamar al dentista']);
    expect(controller.listening, isFalse);
  });

  test(
    'a blank final result writes nothing — the _onSave guard\'s terms',
    () async {
      recognizer.availability = RecognizerAvailability.granted;
      recognizer.startOutcome = RecognizerStart.listening;
      final controller = build();
      await Future<void>.delayed(Duration.zero);
      final transcripts = <String>[];
      controller.onTranscript = transcripts.add;

      await controller.press();
      recognizer.emit(1, '   ');
      await Future<void>.delayed(Duration.zero);
      expect(transcripts, isEmpty);
      expect(controller.listening, isFalse);
    },
  );

  test('a stale session id drops the outcome whole — no transcript, no '
      'reset, the standing state untouched', () async {
    recognizer.availability = RecognizerAvailability.granted;
    recognizer.startOutcome = RecognizerStart.listening;
    final controller = build();
    await Future<void>.delayed(Duration.zero);
    final transcripts = <String>[];
    controller.onTranscript = transcripts.add;

    await controller.press();
    recognizer.emit(0, 'stale');
    await Future<void>.delayed(Duration.zero);
    expect(transcripts, isEmpty);
    expect(
      controller.listening,
      isTrue,
      reason: 'a stale outcome resets nothing',
    );
  });

  test('a refusal appends exactly one permission_refused {microphone} row '
      'through the core minter and removes the affordance — a second '
      'press is nothing at all', () async {
    recognizer.availability = RecognizerAvailability.askable;
    recognizer.startOutcome = RecognizerStart.refused;
    final controller = build();
    await Future<void>.delayed(Duration.zero);
    expect(controller.visible, isTrue);

    await controller.press();
    await Future<void>.delayed(Duration.zero);
    expect(controller.visible, isFalse);
    expect(controller.listening, isFalse);

    expect(store.entries, hasLength(1));
    final row = store.entries.single;
    expect(row.kind, 'permission_refused');
    expect(row.permission, 'microphone');
    expect(row.itemId, isNull);
    expect(row.stack, isNull);

    // The app never re-asks on its own: the invisible affordance
    // presses nothing — the one recorded start is the refused press's.
    await controller.press();
    expect(recognizer.startedSessions, [1]);
    expect(store.entries, hasLength(1));
  });

  test('revocation reads identically: refused-after-grant appends the '
      'same one row (the first-use shape)', () async {
    recognizer.availability = RecognizerAvailability.askable;
    recognizer.startOutcome = RecognizerStart.refused;
    final controller = build();
    await Future<void>.delayed(Duration.zero);
    await controller.press();
    await Future<void>.delayed(Duration.zero);
    expect(store.entries.single.kind, 'permission_refused');
    expect(store.entries.single.permission, 'microphone');
  });

  test('a quiet-unavailable start removes the affordance and appends '
      'nothing', () async {
    recognizer.availability = RecognizerAvailability.granted;
    recognizer.startOutcome = RecognizerStart.unavailable;
    final controller = build();
    await Future<void>.delayed(Duration.zero);
    await controller.press();
    await Future<void>.delayed(Duration.zero);
    expect(controller.visible, isFalse);
    expect(store.entries, isEmpty);
  });

  test('interruption via the lifecycle: the session is cancelled, the '
      'capsule returns to rest, and the late outcome drops as stale — '
      'nothing lands, nothing surfaces', () async {
    recognizer.availability = RecognizerAvailability.granted;
    recognizer.startOutcome = RecognizerStart.listening;
    final controller = build();
    await Future<void>.delayed(Duration.zero);
    final transcripts = <String>[];
    controller.onTranscript = transcripts.add;

    await controller.press();
    expect(controller.listening, isTrue);

    final observer = observers.single;
    observer.didChangeAppLifecycleState(AppLifecycleState.paused);
    await Future<void>.delayed(Duration.zero);

    expect(controller.listening, isFalse);
    expect(recognizer.cancelledSessions, [1]);

    recognizer.emit(1, 'half a sentence the call cut off');
    await Future<void>.delayed(Duration.zero);
    expect(transcripts, isEmpty);
  });

  test('a press pending its permission answer survives the dialog\'s '
      'inactive: the grant resolves into listening — the first-use '
      'flow, whose dialog pauses the activity itself (FR-32)', () async {
    recognizer.availability = RecognizerAvailability.askable;
    final gate = Completer<RecognizerStart>();
    recognizer.startGate = gate;
    final controller = build();
    await Future<void>.delayed(Duration.zero);
    expect(controller.visible, isTrue);

    // The press stands; the system dialog's appearance delivers
    // inactive — no live session exists, so nothing is cancelled and
    // the pending press keeps its session.
    final stoodPress = controller.press();
    observers.single.didChangeAppLifecycleState(AppLifecycleState.inactive);
    await Future<void>.delayed(Duration.zero);
    expect(recognizer.cancelledSessions, isEmpty);

    // The grant answers: the same press resolves into listening.
    gate.complete(RecognizerStart.listening);
    await stoodPress;
    expect(controller.listening, isTrue);
  });

  test('a start resolving while the app left the foreground is '
      'invalidated and cancelled — nothing begins off the foreground, '
      'and the orphan outcome drops whole (FR-32)', () async {
    recognizer.availability = RecognizerAvailability.askable;
    final gate = Completer<RecognizerStart>();
    recognizer.startGate = gate;
    var standing = AppLifecycleState.resumed;
    final controller = DictationController(
      store: store,
      recognizer: recognizer,
      writeQueue: LogWriteQueue(),
      addObserver: observers.add,
      lifecycleStateOf: () => standing,
    );
    await Future<void>.delayed(Duration.zero);

    final stoodPress = controller.press();
    standing = AppLifecycleState.hidden;
    gate.complete(RecognizerStart.listening);
    await stoodPress;
    await Future<void>.delayed(Duration.zero);
    expect(controller.listening, isFalse);
    expect(recognizer.cancelledSessions, [1]);

    recognizer.emit(1, 'una frase huérfana');
    await Future<void>.delayed(Duration.zero);
    expect(controller.listening, isFalse);
  });

  test('a refusal is durable whatever the session\'s fate: the entry '
      'lands even when the dialog\'s lifecycle outran the answer '
      '(FR-32)', () async {
    recognizer.availability = RecognizerAvailability.askable;
    final gate = Completer<RecognizerStart>();
    recognizer.startGate = gate;
    final controller = build();
    await Future<void>.delayed(Duration.zero);
    expect(controller.visible, isTrue);

    final stoodPress = controller.press();
    // The system auto-denied the standing dialog as the app left; the
    // refused answer resolves after the lifecycle moved on.
    observers.single.didChangeAppLifecycleState(AppLifecycleState.paused);
    gate.complete(RecognizerStart.refused);
    await stoodPress;
    await Future<void>.delayed(Duration.zero);
    expect(store.entries, hasLength(1));
    expect(store.entries.single.kind, 'permission_refused');
    expect(store.entries.single.permission, 'microphone');
    expect(controller.visible, isFalse);
  });

  test('a resumed lifecycle re-derives visibility — the re-grant path '
      'runs through the probe alone', () async {
    recognizer.availability = RecognizerAvailability.askable;
    final controller = build();
    await Future<void>.delayed(Duration.zero);
    expect(controller.visible, isTrue);

    // The user refuses in the dialog (the press flow appends the row).
    recognizer.startOutcome = RecognizerStart.refused;
    await controller.press();
    await Future<void>.delayed(Duration.zero);
    expect(controller.visible, isFalse);

    // While away, the permission is re-granted at the system level.
    recognizer.availability = RecognizerAvailability.granted;
    observers.single.didChangeAppLifecycleState(AppLifecycleState.resumed);
    await Future<void>.delayed(Duration.zero);
    expect(
      controller.visible,
      isTrue,
      reason: 'recovery through granted alone, the entry still standing',
    );
  });

  test('a failing store on the refusal append is absorbed quietly — the '
      'affordance still disappears', () async {
    recognizer.availability = RecognizerAvailability.askable;
    recognizer.startOutcome = RecognizerStart.refused;
    final throwing = _RecordingStore();
    final controller = DictationController(
      store: _ThrowingAppendStore(throwing),
      recognizer: recognizer,
      writeQueue: LogWriteQueue(),
      addObserver: (_) {},
    );
    await Future<void>.delayed(Duration.zero);
    await controller.press();
    await Future<void>.delayed(Duration.zero);
    expect(controller.visible, isFalse);
  });

  test('surfaceExited cancels a live session exactly like the lifecycle '
      'interruption — bump, quiet cancel, rest — and is a no-op when '
      'nothing stands (FR-32)', () async {
    recognizer.availability = RecognizerAvailability.granted;
    recognizer.startOutcome = RecognizerStart.listening;
    final controller = build();
    await Future<void>.delayed(Duration.zero);
    final transcripts = <String>[];
    controller.onTranscript = transcripts.add;

    await controller.press();
    expect(controller.listening, isTrue);

    controller.surfaceExited();
    await Future<void>.delayed(Duration.zero);
    expect(controller.listening, isFalse);
    expect(recognizer.cancelledSessions, [1]);

    // The cancelled session's late outcome lands nowhere.
    recognizer.emit(1, 'media frase');
    await Future<void>.delayed(Duration.zero);
    expect(transcripts, isEmpty);

    // Nothing stands: exiting again cancels nothing, notifies nobody.
    controller.surfaceExited();
    await Future<void>.delayed(Duration.zero);
    expect(recognizer.cancelledSessions, [1]);
  });

  test('a second press while a start is awaited is nothing at all — one '
      'session, one fate; a stale unavailable resolution clears nothing '
      'and the newer session stands untouched', () async {
    recognizer.availability = RecognizerAvailability.granted;
    final gate = Completer<RecognizerStart>();
    recognizer.startGate = gate;
    final controller = build();
    await Future<void>.delayed(Duration.zero);
    expect(controller.visible, isTrue);

    final stoodPress = controller.press();
    await Future<void>.delayed(Duration.zero);
    // The in-flight guard: a press while the first awaits its start
    // starts nothing at all.
    await controller.press();
    expect(recognizer.startedSessions, [1]);

    // The surface leaves while the start pends; the stale resolution
    // then answers unavailable: it must clear nothing.
    controller.surfaceExited();
    gate.complete(RecognizerStart.unavailable);
    await stoodPress;
    await Future<void>.delayed(Duration.zero);
    expect(
      controller.visible,
      isTrue,
      reason: 'a stale unavailable never retires the affordance',
    );
    expect(controller.listening, isFalse);

    // A fresh press mints the next session and owns it.
    recognizer.startGate = null;
    recognizer.startOutcome = RecognizerStart.listening;
    await controller.press();
    expect(recognizer.startedSessions, [1, 3]);
    expect(controller.listening, isTrue);
  });

  test('a stale refresh cannot overwrite a newer read\'s visibility — '
      'only the newest generation commits (the ordering guard)', () async {
    recognizer.availability = RecognizerAvailability.granted;
    final slowGate = Completer<RecognizerAvailability>();
    recognizer.probeGate = slowGate;
    final controller = build();
    await Future<void>.delayed(Duration.zero);
    expect(controller.visible, isFalse, reason: 'the first read still pends');

    // A newer refresh lands while the first one pends: the constructor
    // read, a surface entry and a resume can all overlap like this.
    recognizer.probeGate = null;
    final observer = observers.single;
    observer.didChangeAppLifecycleState(AppLifecycleState.resumed);
    await Future<void>.delayed(Duration.zero);
    expect(controller.visible, isTrue, reason: 'the newest read landed');

    // The stale read resolves last: unavailable must not flip the
    // visibility the newer generation already committed.
    slowGate.complete(RecognizerAvailability.unavailable);
    await Future<void>.delayed(Duration.zero);
    expect(
      controller.visible,
      isTrue,
      reason: 'a stale refresh overwrites nothing',
    );
  });

  test('dispose unregisters through the injected seam — symmetric with '
      'the registration, headless throughout', () async {
    final removed = <WidgetsBindingObserver>[];
    final controller = DictationController(
      store: store,
      recognizer: recognizer,
      writeQueue: LogWriteQueue(),
      addObserver: observers.add,
      removeObserver: removed.add,
    );
    controller.dispose();
    expect(removed, hasLength(1));
    expect(identical(removed.single, controller), isTrue);
    expect(
      observers,
      hasLength(1),
      reason: 'the real binding was never touched',
    );
  });
}

/// A store whose `appendLogEntry` always throws — the quiet-absorption
/// queue path's own row.
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

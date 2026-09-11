import 'package:core/log/log_entry.dart';
import 'package:core/ports/store_port.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:organizer/crash.dart';

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

class _FailingStore implements StorePort {
  @override
  Future<void> appendPoolFact(PoolFactRecord fact) async => throw Exception();

  @override
  Future<void> appendLogEntry(LogEntryRecord entry) async => throw Exception();

  @override
  Future<List<PoolFactRecord>> readPoolFacts() async => throw Exception();

  @override
  Future<List<LogEntryRecord>> readLogEntries() async => throw Exception();
}

void main() {
  final v7 = RegExp(
    '^[0-9a-f]{8}-[0-9a-f]{4}-7[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}\$',
  );

  test(
    'the crash entry is exactly stack + timestamp (+ id and offset)',
    () async {
      final before = DateTime.now().microsecondsSinceEpoch;
      final offsetBefore = DateTime.now().timeZoneOffset.inSeconds;
      final store = _RecordingStore();
      await appendCrashEntry(
        store,
        '#0      build (package:organizer/x.dart:9)',
      );
      final after = DateTime.now().microsecondsSinceEpoch;

      expect(store.facts, isEmpty);
      expect(store.entries, hasLength(1));
      final entry = store.entries.single;
      expect(entry.kind, LogKind.crashRecorded.name);
      expect(entry.stack, '#0      build (package:organizer/x.dart:9)');
      expect(entry.itemId, isNull);
      expect(entry.itemOrigin, isNull);
      expect(entry.id, matches(v7));
      expect(entry.instantUtcMicros, greaterThanOrEqualTo(before));
      expect(entry.instantUtcMicros, lessThanOrEqualTo(after));
      expect(entry.offsetSeconds, offsetBefore);
    },
  );

  test(
    'a failing store write is swallowed — the guard never re-throws',
    () async {
      await appendCrashEntry(
        _FailingStore(),
        'Bearer sk-proj-abcdefghijklmnopqrstuvwx',
      );
    },
  );

  test('a missing Flutter stack is replaced with the current stack', () async {
    final store = _RecordingStore();
    await appendCrashEntry(store, null);
    expect(store.entries.single.stack, isNotEmpty);
    expect(store.entries.single.stack, isNot(contains('sk-')));
  });

  test('OpenAI/OpenRouter Bearer in a stack is redacted at persist', () async {
    final store = _RecordingStore();
    const token = 'sk-proj-abcdefghijklmnopqrstuvwx';
    const stack =
        '#0      send (package:organizer/egress/byok_wire.dart:396)\n'
        'Bearer $token\n'
        '#1      build (package:organizer/x.dart:9)';
    await appendCrashEntry(store, stack);
    final stored = store.entries.single.stack!;
    expect(stored, contains('Bearer [REDACTED]'));
    expect(
      stored,
      contains('#0      send (package:organizer/egress/byok_wire.dart:396)'),
    );
    expect(stored, contains('#1      build (package:organizer/x.dart:9)'));
    expect(stored, isNot(contains(token)));
    expect(stored, isNot(contains('sk-')));
  });

  test(
    'OpenAI/OpenRouter Authorization Bearer wire line is redacted at persist',
    () async {
      final store = _RecordingStore();
      const token = 'org-live-abcdefghijklmnopqrstuvwx';
      const stack =
          '#0      send (package:organizer/egress/byok_wire.dart:396)\n'
          'Authorization: Bearer $token\n'
          '#1      build (package:organizer/x.dart:9)';
      await appendCrashEntry(store, stack);
      final stored = store.entries.single.stack!;
      expect(stored, contains('Authorization: Bearer [REDACTED]'));
      expect(
        stored,
        contains('#0      send (package:organizer/egress/byok_wire.dart:396)'),
      );
      expect(stored, contains('#1      build (package:organizer/x.dart:9)'));
      expect(stored, isNot(contains(token)));
    },
  );

  test(
    'Anthropic header and standalone sk-ant token are both redacted',
    () async {
      final store = _RecordingStore();
      const token = 'sk-ant-abcdefghijklmnopqrstuvwx';
      const stack =
          '#0      send (package:organizer/egress/byok_wire.dart:398)\n'
          'x-api-key: $token\n'
          '#1      slice (package:organizer/egress/byok_slicer.dart:110)\n'
          '$token\n'
          '#2      build (package:organizer/x.dart:9)';
      await appendCrashEntry(store, stack);
      final stored = store.entries.single.stack!;
      expect(stored, contains('x-api-key: [REDACTED]'));
      expect(
        stored,
        contains('#0      send (package:organizer/egress/byok_wire.dart:398)'),
      );
      expect(stored, contains('#2      build (package:organizer/x.dart:9)'));
      expect(stored, isNot(contains(token)));
      expect(stored, isNot(contains('sk-ant-')));
    },
  );

  test('Gemini header and standalone AIzaSy token are both redacted', () async {
    final store = _RecordingStore();
    const token = 'AIzaSyABCDEFGHIJKLMNOPQRSTUVWXYZ0123456';
    const stack =
        '#0      send (package:organizer/egress/byok_wire.dart:393)\n'
        'x-goog-api-key: $token\n'
        '#1      slice (package:organizer/egress/byok_slicer.dart:110)\n'
        '$token\n'
        '#2      build (package:organizer/x.dart:9)';
    await appendCrashEntry(store, stack);
    final stored = store.entries.single.stack!;
    expect(stored, contains('x-goog-api-key: [REDACTED]'));
    expect(
      stored,
      contains('#0      send (package:organizer/egress/byok_wire.dart:393)'),
    );
    expect(stored, contains('#2      build (package:organizer/x.dart:9)'));
    expect(stored, isNot(contains(token)));
    expect(stored, isNot(contains('AIzaSy')));
  });

  test(
    'compact header values without a space after the delimiter are redacted',
    () async {
      final store = _RecordingStore();
      const token = 'vaultsecret_compact_abcdefghij';
      const stack =
          '#0      send (package:organizer/egress/byok_wire.dart:398)\n'
          'x-api-key:$token\n'
          'x-goog-api-key=$token\n'
          '#1      build (package:organizer/x.dart:9)';
      await appendCrashEntry(store, stack);
      final stored = store.entries.single.stack!;
      expect(stored, contains('x-api-key:[REDACTED]'));
      expect(stored, contains('x-goog-api-key=[REDACTED]'));
      expect(stored, contains('#1      build (package:organizer/x.dart:9)'));
      expect(stored, isNot(contains(token)));
    },
  );

  test('query api_key values are redacted at persist', () async {
    final store = _RecordingStore();
    const token = 'sk-abcdefghijklmnopqrstuvwx';
    const stack =
        '#0      send (package:organizer/egress/byok_wire.dart:380)\n'
        'https://example.invalid/v1?api_key=$token\n'
        '#1      build (package:organizer/x.dart:9)';
    await appendCrashEntry(store, stack);
    final stored = store.entries.single.stack!;
    expect(stored, contains('api_key=[REDACTED]'));
    expect(stored, contains('#1      build (package:organizer/x.dart:9)'));
    expect(stored, isNot(contains(token)));
  });

  test('Authorization header without Bearer and access_token query are redacted at persist', () async {
    final store = _RecordingStore();
    const token = 'custom-auth-token-67890';
    const stack =
        '#0      send (package:organizer/egress/byok_wire.dart:380)\n'
        'Authorization: $token\n'
        'https://example.invalid/v1?access_token=$token\n'
        '#1      build (package:organizer/x.dart:9)';
    await appendCrashEntry(store, stack);
    final stored = store.entries.single.stack!;
    expect(stored, contains('Authorization: [REDACTED]'));
    expect(stored, contains('access_token=[REDACTED]'));
    expect(stored, contains('#1      build (package:organizer/x.dart:9)'));
    expect(stored, isNot(contains(token)));
  });

  test('query key values are redacted at persist', () async {
    final store = _RecordingStore();
    const token = 'vaultsecret_abcdefghijklmnopqrstuv';
    const stack =
        '#0      send (package:organizer/egress/byok_wire.dart:380)\n'
        'https://example.invalid/v1?key=$token\n'
        '#1      build (package:organizer/x.dart:9)';
    await appendCrashEntry(store, stack);
    final stored = store.entries.single.stack!;
    expect(stored, contains('key=[REDACTED]'));
    expect(stored, contains('#1      build (package:organizer/x.dart:9)'));
    expect(stored, isNot(contains(token)));
  });

  test('query token values are redacted at persist', () async {
    final store = _RecordingStore();
    const token = 'opaque-credential-value-12345';
    const stack =
        '#0      send (package:organizer/egress/byok_wire.dart:380)\n'
        'https://example.invalid/v1?token=$token\n'
        '#1      build (package:organizer/x.dart:9)';
    await appendCrashEntry(store, stack);
    final stored = store.entries.single.stack!;
    expect(stored, contains('token=[REDACTED]'));
    expect(stored, contains('#1      build (package:organizer/x.dart:9)'));
    expect(stored, isNot(contains(token)));
  });

  test('the guard records the stack only — exception credential text is not stored', () async {
    final store = _RecordingStore();
    final previous = FlutterError.onError;
    addTearDown(() => FlutterError.onError = previous);
    installCrashGuard(store);

    FlutterError.reportError(
      FlutterErrorDetails(
        exception: StateError('Bearer sk-proj-abcdefghijklmnopqrstuvwx'),
        stack: StackTrace.fromString(
          '#0      build (package:organizer/x.dart:9)',
        ),
        library: 'organizer',
      ),
    );
    await Future<void>.delayed(Duration.zero);

    expect(store.entries, hasLength(1));
    expect(store.entries.single.kind, LogKind.crashRecorded.name);
    final stored = store.entries.single.stack!;
    const frames = '#0      build (package:organizer/x.dart:9)';
    expect(stored, anyOf(frames, '$frames\n'));
    expect(stored, isNot(contains('StateError')));
  });

  test(
    'installing the guard routes Flutter errors to the crash entry',
    () async {
      final store = _RecordingStore();
      final previous = FlutterError.onError;
      addTearDown(() => FlutterError.onError = previous);
      installCrashGuard(store);

      FlutterError.reportError(
        FlutterErrorDetails(
          exception: StateError('boom'),
          stack: StackTrace.current,
          library: 'organizer',
        ),
      );
      await Future<void>.delayed(Duration.zero);

      expect(store.entries, hasLength(1));
      expect(store.entries.single.kind, LogKind.crashRecorded.name);
      expect(store.entries.single.stack, isNotEmpty);
    },
  );

  test('the installed platform error handler records one crash entry and returns true', () async {
    final store = _RecordingStore();
    final previous = PlatformDispatcher.instance.onError;
    final previousFlutter = FlutterError.onError;
    addTearDown(() {
      PlatformDispatcher.instance.onError = previous;
      FlutterError.onError = previousFlutter;
    });
    installCrashGuard(store);

    final handler = PlatformDispatcher.instance.onError;
    expect(handler, isNotNull);
    final handled = handler!(StateError('boom'), StackTrace.current);
    await Future<void>.delayed(Duration.zero);

    expect(handled, isTrue);
    expect(store.entries, hasLength(1));
    expect(store.entries.single.kind, LogKind.crashRecorded.name);
    expect(store.entries.single.stack, isNotNull);
  });
}

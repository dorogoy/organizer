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
}

class _FailingStore implements StorePort {
  @override
  Future<void> appendPoolFact(PoolFactRecord fact) async => throw Exception();

  @override
  Future<void> appendLogEntry(LogEntryRecord entry) async => throw Exception();
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
      await appendCrashEntry(_FailingStore(), '#0      build');
    },
  );

  test('a missing Flutter stack is replaced with the current stack', () async {
    final store = _RecordingStore();
    await appendCrashEntry(store, null);
    expect(store.entries.single.stack, isNotEmpty);
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

import 'dart:io';

import 'package:core/ports/clock_port.dart';
import 'package:core/ports/store_port.dart';
import 'package:test/test.dart';

/// A shell-side stand-in proving the clock port is implementable outside its
/// declaring library — adapters hand the core an instant, the core never
/// reads one (AD-3, AD-5).
class _ShellClock implements ClockPort {
  const _ShellClock();

  @override
  DateTime instant() => DateTime.fromMillisecondsSinceEpoch(0);
}

/// A shell-side stand-in proving the store port is implementable outside its
/// declaring library; adapters return inert rows, never domain objects (AD-5).
class _ShellStore implements StorePort {
  const _ShellStore();

  @override
  Future<void> appendPoolFact(PoolFactRecord fact) async {}

  @override
  Future<void> appendLogEntry(LogEntryRecord entry) async {}

  @override
  Future<List<PoolFactRecord>> readPoolFacts() async => const [];

  @override
  Future<List<LogEntryRecord>> readLogEntries() async => const [];
}

void main() {
  test('the ports library declares exactly the build\'s ports', () {
    final dir = Directory('lib/ports');
    if (!dir.existsSync()) {
      fail('lib/ports is missing: the ports library must exist (AD-5)');
    }
    final names =
        dir
            .listSync()
            .whereType<File>()
            .map((file) => file.uri.pathSegments.last)
            .toList()
          ..sort();
    // The two Epic-1 ports plus the recognizer port Story 3.4 adds
    // (FR-32): ClockPort minimalism, one file each.
    expect(names, [
      'clock_port.dart',
      'recognizer_port.dart',
      'store_port.dart',
    ]);
  });

  test('both ports are implementable by a shell-side adapter (AD-5)', () {
    const clock = _ShellClock();
    const store = _ShellStore();
    expect(clock, isA<ClockPort>());
    expect(store, isA<StorePort>());
    expect(clock.instant(), DateTime.fromMillisecondsSinceEpoch(0));
  });
}

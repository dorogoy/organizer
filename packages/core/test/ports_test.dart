import 'dart:io';

import 'package:core/ports/clock_port.dart';
import 'package:core/ports/files_port.dart';
import 'package:core/ports/slicer_port.dart';
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

/// A shell-side stand-in proving the files port is implementable outside
/// its declaring library (Story 4.3, AD-21, AD-22) — adapters move bytes,
/// never semantics.
class _ShellFiles implements FilesPort {
  const _ShellFiles();

  @override
  Future<List<int>?> read(String scope, String name) async => null;

  @override
  Future<void> write(String scope, String name, List<int> bytes) async {}

  @override
  Future<void> delete(String scope, String name) async {}
}

/// A shell-side stand-in proving the slicer port is implementable
/// outside its declaring library (Story 4-4, AD-9) — adapters send,
/// the core only names the vocabulary.
class _ShellSlicer implements SlicerPort {
  const _ShellSlicer();

  @override
  Future<SlicerOutcome> slice(SlicerRequest request) async =>
      const SlicerFailed(SlicerFailureCause.managedUnavailable);
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
    // The two Epic-1 ports, the recognizer port Story 3.4 adds
    // (FR-32), the files port Story 4.3 adds (AD-22), and the slicer
    // port Story 4-4 adds (AD-9): one file each.
    expect(names, [
      'clock_port.dart',
      'files_port.dart',
      'recognizer_port.dart',
      'slicer_port.dart',
      'store_port.dart',
    ]);
  });

  test('both ports are implementable by a shell-side adapter (AD-5)', () {
    const clock = _ShellClock();
    const store = _ShellStore();
    const files = _ShellFiles();
    expect(clock, isA<ClockPort>());
    expect(store, isA<StorePort>());
    expect(files, isA<FilesPort>());
    expect(clock.instant(), DateTime.fromMillisecondsSinceEpoch(0));
  });

  test(
    'the slicer port is implementable by a shell-side adapter (AD-9)',
    () async {
      const slicer = _ShellSlicer();
      expect(slicer, isA<SlicerPort>());
      expect(
        await slicer.slice(
          const RescueSliceRequest(originContext: 'shelf', task: 'clear it'),
        ),
        isA<SlicerFailed>(),
      );
    },
  );
}

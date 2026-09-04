import 'dart:io';

import 'package:core/pool/pool_fact.dart';
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
    // port Story 4-4 adds (AD-9): one file each — plus the no-Slicer
    // cause vocabulary Story 4-5 lands beside them (FR-29): pure
    // enum-plus-map vocabulary, not an interface, but the ports
    // library is its decided home.
    expect(names, [
      'clock_port.dart',
      'files_port.dart',
      'no_slicer_cause.dart',
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

  group(
    'the pool-fact read boundary\'s rescue sanitation (Story 4.6, AD-23)',
    () {
      PoolFactRecord record({String? rescueOf, int? estimateSeconds}) => (
        id: '019123ab-cdef-7abc-8def-0123456789ab',
        origin: Origin.manual,
        size: Size.instant,
        instantUtcMicros: 1758900000123456,
        offsetSeconds: 0,
        originContext: 'Buscar el desengrasante',
        dictated: null,
        rescueOf: rescueOf,
        estimateSeconds: estimateSeconds,
      );

      test('a well-formed rescue pair passes verbatim — the band\'s own '
          'edges included', () {
        for (final estimate in [1, 45, 60]) {
          final fact = poolFactsOf([
            record(rescueOf: 'cap-a', estimateSeconds: estimate),
          ]).single;
          expect(fact.rescueOf, 'cap-a');
          expect(fact.estimateSeconds, estimate);
        }
      });

      test('an out-of-band estimate reads as absent — a corrupt 0, '
          'negative or absurd tag never reaches the pocket, the 🔴 '
          'ceiling or the retirement arithmetic; the size default '
          'charges exactly as a pre-4-6 fact\'s did', () {
        for (final estimate in [0, -5, 61, 999999]) {
          final fact = poolFactsOf([
            record(rescueOf: 'cap-a', estimateSeconds: estimate),
          ]).single;
          expect(
            fact.estimateSeconds,
            isNull,
            reason: 'estimate=$estimate is outside the 1–60 band',
          );
          expect(
            fact.rescueOf,
            'cap-a',
            reason:
                'the parent half is untouched by the estimate\'s '
                'own corruption',
          );
        }
      });

      test('an empty or whitespace rescueOf reads as absent — a mangled '
          'row derives as an ordinary fact, never the head of a chain '
          'named by nothing', () {
        for (final parent in ['', '   ']) {
          final fact = poolFactsOf([
            record(rescueOf: parent, estimateSeconds: 45),
          ]).single;
          expect(fact.rescueOf, isNull, reason: 'rescueOf="$parent"');
          expect(
            fact.estimateSeconds,
            45,
            reason:
                'the estimate half is untouched by the parent\'s '
                'own corruption',
          );
        }
      });

      test('a lone half survives as stored — halves normalize '
          'independently, never as a pair', () {
        final parentOnly = poolFactsOf([record(rescueOf: 'cap-a')]).single;
        expect(parentOnly.rescueOf, 'cap-a');
        expect(parentOnly.estimateSeconds, isNull);
        final estimateOnly = poolFactsOf([record(estimateSeconds: 45)]).single;
        expect(estimateOnly.rescueOf, isNull);
        expect(estimateOnly.estimateSeconds, 45);
      });

      test('an ordinary fact\'s null pair passes as null — the '
          'pre-4-6 shape is unchanged', () {
        final fact = poolFactsOf([record()]).single;
        expect(fact.rescueOf, isNull);
        expect(fact.estimateSeconds, isNull);
      });
    },
  );
}

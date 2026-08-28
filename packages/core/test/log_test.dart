import 'package:core/log/log_entry.dart';
import 'package:core/pool/pool_fact.dart';
import 'package:test/test.dart';

void main() {
  group('LogKind vocabulary membership (AD-21)', () {
    test('holds exactly this epic\'s seven kinds', () {
      final names = [
        LogKind.cardDealt,
        LogKind.cardDone,
        LogKind.cardSkipped,
        LogKind.sessionStarted,
        LogKind.sessionEnded,
        LogKind.appOpened,
        LogKind.crashRecorded,
      ].map((kind) => kind.name).toList()..sort();
      expect(names, [
        'app_opened',
        'card_dealt',
        'card_done',
        'card_skipped',
        'crash_recorded',
        'session_ended',
        'session_started',
      ]);
      expect(LogKind.knownByName, hasLength(7));
    });

    test('every known kind is known, and parse round-trips wire names', () {
      for (final kind in LogKind.knownByName.values) {
        expect(kind.known, isTrue);
        expect(LogKind.parse(kind.name), same(kind));
      }
    });

    test('kinds are values: equality follows name and knownness', () {
      expect(LogKind.parse('card_done'), LogKind.cardDone);
      expect(LogKind.parse('future_kind'), LogKind.parse('future_kind'));
      expect(LogKind.parse('future_kind').known, isFalse);
      expect(LogKind.parse('future_kind').name, 'future_kind');
    });
  });

  group('the unknown-kind carrier (AD-23)', () {
    test('an unknown kind parses to a carried, non-fatal entry', () {
      final entry = UnknownEntry(
        id: '0190aaaa-0000-7000-8000-000000000001',
        instantUtcMicros: 1000,
        offsetSeconds: 7200,
        kind: LogKind.parse('future_kind'),
      );
      expect(entry.kind.known, isFalse);
      expect(entry.kind.name, 'future_kind');
    });

    test('a derivation meeting an unknown kind skips it and continues', () {
      final entries = <LogEntry>[
        MomentEntry(
          id: '0190aaaa-0000-7000-8000-000000000002',
          instantUtcMicros: 2000,
          offsetSeconds: 0,
          kind: LogKind.appOpened,
        ),
        UnknownEntry(
          id: '0190aaaa-0000-7000-8000-000000000003',
          instantUtcMicros: 3000,
          offsetSeconds: 0,
          kind: LogKind.parse('future_kind'),
        ),
        ItemActEntry(
          id: '0190aaaa-0000-7000-8000-000000000004',
          instantUtcMicros: 4000,
          offsetSeconds: 0,
          kind: LogKind.cardDone,
          itemId: '0190aaaa-0000-7000-8000-000000000005',
          itemOrigin: Origin.shipped,
        ),
      ];
      // The derivation shape every reader takes: known kinds only, the
      // unknown entry passes through untouched and stops nothing.
      final read = entries.where((entry) => entry.kind.known).toList();
      expect(read, hasLength(2));
      expect(read[0].kind, LogKind.appOpened);
      expect(read[1].kind, LogKind.cardDone);
    });
  });

  group('entry shapes', () {
    test(
      'an item-referencing entry carries the item id and origin (AD-14)',
      () {
        final entry = ItemActEntry(
          id: '0190aaaa-0000-7000-8000-000000000006',
          instantUtcMicros: 5000,
          offsetSeconds: -3600,
          kind: LogKind.cardSkipped,
          itemId: '0190aaaa-0000-7000-8000-000000000007',
          itemOrigin: Origin.cloud,
        );
        expect(entry.itemId, '0190aaaa-0000-7000-8000-000000000007');
        expect(entry.itemOrigin, Origin.cloud);
        expect(entry.instantUtcMicros, 5000);
        expect(entry.offsetSeconds, -3600);
      },
    );

    test('a crash entry carries the stack and timestamp and nothing else', () {
      final entry = CrashEntry(
        id: '0190aaaa-0000-7000-8000-000000000008',
        instantUtcMicros: 6000,
        offsetSeconds: 3600,
        stack: '#0      main (package:organizer/main.dart:8)',
      );
      expect(entry.kind, LogKind.crashRecorded);
      expect(entry.stack, '#0      main (package:organizer/main.dart:8)');
      expect(entry.instantUtcMicros, 6000);
      expect(entry.offsetSeconds, 3600);
    });
  });
}

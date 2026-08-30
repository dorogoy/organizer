import 'package:core/log/log_entry.dart';
import 'package:core/ports/store_port.dart';
import 'package:core/pool/pool_fact.dart';
import 'package:test/test.dart';

LogEntryRecord _record(
  String kind, {
  String? itemId,
  Origin? itemOrigin,
  String? stack,
  String? settingKey,
  int? settingValue,
}) => (
  id: '0190bbbb-0000-7000-8000-$kind',
  kind: kind,
  instantUtcMicros: 7000,
  offsetSeconds: 3600,
  itemId: itemId,
  itemOrigin: itemOrigin,
  stack: stack,
  settingKey: settingKey,
  settingValue: settingValue,
);

void main() {
  group('LogKind vocabulary membership (AD-21)', () {
    test('holds exactly the build\'s eight kinds', () {
      final names = [
        LogKind.cardDealt,
        LogKind.cardDone,
        LogKind.cardSkipped,
        LogKind.sessionStarted,
        LogKind.sessionEnded,
        LogKind.appOpened,
        LogKind.crashRecorded,
        LogKind.settingChanged,
      ].map((kind) => kind.name).toList()..sort();
      expect(names, [
        'app_opened',
        'card_dealt',
        'card_done',
        'card_skipped',
        'crash_recorded',
        'session_ended',
        'session_started',
        'setting_changed',
      ]);
      expect(LogKind.knownByName, hasLength(8));
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

    test('a setting entry carries its key and value and nothing else '
        '(Story 2.1, AD-1)', () {
      final entry = SettingEntry(
        id: '0190aaaa-0000-7000-8000-000000000009',
        instantUtcMicros: 7000,
        offsetSeconds: 3600,
        key: 'time_bag',
        value: 20,
      );
      expect(entry.kind, LogKind.settingChanged);
      expect(entry.key, 'time_bag');
      expect(entry.value, 20);
      expect(entry.instantUtcMicros, 7000);
      expect(entry.offsetSeconds, 3600);
    });
  });

  group('the record→entry read boundary (Story 1.6; AD-12, AD-14, AD-23)', () {
    test('a well-shaped item act converts with its pair intact', () {
      final conversion = convertLogEntryRecord(
        _record('card_dealt', itemId: 'man-a', itemOrigin: Origin.shipped),
      );
      final entry = conversion.entry;
      expect(conversion.flaw, isNull);
      expect(entry, isA<ItemActEntry>());
      expect(entry!.kind, LogKind.cardDealt);
      expect((entry as ItemActEntry).itemId, 'man-a');
      expect(entry.itemOrigin, Origin.shipped);
    });

    test('moments and crash entries convert with their own payloads', () {
      final moment = convertLogEntryRecord(_record('session_started')).entry;
      expect(moment, isA<MomentEntry>());
      expect(moment!.kind, LogKind.sessionStarted);

      final crash = convertLogEntryRecord(
        _record('crash_recorded', stack: '#0      build'),
      ).entry;
      expect(crash, isA<CrashEntry>());
      expect(crash!.kind, LogKind.crashRecorded);
    });

    test('an unknown kind is carried whatever its payload (AD-23)', () {
      final carried = convertLogEntryRecord(
        _record(
          'future_kind',
          itemId: 'man-a',
          itemOrigin: Origin.shipped,
          stack: 'opaque',
        ),
      );
      expect(carried.flaw, isNull);
      expect(carried.entry, isA<UnknownEntry>());
      expect(carried.entry!.kind.known, isFalse);
    });

    test('a half item pair is excluded, distinctly', () {
      final conversion = convertLogEntryRecord(
        _record('card_done', itemId: 'man-a'),
      );
      expect(conversion.entry, isNull);
      expect(conversion.flaw, LogRecordFlaw.halfItemPair);
    });

    test('an item act without its pair at all is excluded', () {
      final conversion = convertLogEntryRecord(_record('card_dealt'));
      expect(conversion.entry, isNull);
      expect(conversion.flaw, LogRecordFlaw.itemPairAbsent);
    });

    test('stack on a non-crash kind is excluded', () {
      final onAct = convertLogEntryRecord(
        _record(
          'card_done',
          itemId: 'man-a',
          itemOrigin: Origin.shipped,
          stack: '#0      build',
        ),
      );
      expect(onAct.entry, isNull);
      expect(onAct.flaw, LogRecordFlaw.stackOffCrashKind);

      final onMoment = convertLogEntryRecord(
        _record('app_opened', stack: '#0      build'),
      );
      expect(onMoment.entry, isNull);
      expect(onMoment.flaw, LogRecordFlaw.stackOffCrashKind);
    });

    test('an item pair on a non-item kind is excluded', () {
      final onMoment = convertLogEntryRecord(
        _record('session_ended', itemId: 'man-a', itemOrigin: Origin.shipped),
      );
      expect(onMoment.entry, isNull);
      expect(onMoment.flaw, LogRecordFlaw.itemOnNonItemKind);

      final onCrash = convertLogEntryRecord(
        _record(
          'crash_recorded',
          itemId: 'man-a',
          itemOrigin: Origin.shipped,
          stack: '#0      build',
        ),
      );
      expect(onCrash.entry, isNull);
      expect(onCrash.flaw, LogRecordFlaw.itemOnNonItemKind);
    });

    test('crash_recorded without its stack is excluded', () {
      final conversion = convertLogEntryRecord(_record('crash_recorded'));
      expect(conversion.entry, isNull);
      expect(conversion.flaw, LogRecordFlaw.stackAbsent);
    });

    test('an empty itemId string counts as an absent pair, not a value', () {
      final withOrigin = convertLogEntryRecord(
        _record('card_done', itemId: '', itemOrigin: Origin.shipped),
      );
      expect(withOrigin.entry, isNull);
      expect(withOrigin.flaw, LogRecordFlaw.halfItemPair);

      final withoutOrigin = convertLogEntryRecord(
        _record('card_dealt', itemId: ''),
      );
      expect(withoutOrigin.entry, isNull);
      expect(withoutOrigin.flaw, LogRecordFlaw.itemPairAbsent);
    });

    test('an empty stack string counts as no stack at all', () {
      final conversion = convertLogEntryRecord(
        _record('crash_recorded', stack: ''),
      );
      expect(conversion.entry, isNull);
      expect(conversion.flaw, LogRecordFlaw.stackAbsent);
    });

    group('the setting payload path (Story 2.1, AD-1, AD-23)', () {
      test('a well-shaped setting entry converts with its pair intact', () {
        final conversion = convertLogEntryRecord(
          _record('setting_changed', settingKey: 'time_bag', settingValue: 25),
        );
        final entry = conversion.entry;
        expect(conversion.flaw, isNull);
        expect(entry, isA<SettingEntry>());
        expect(entry!.kind, LogKind.settingChanged);
        expect((entry as SettingEntry).key, 'time_bag');
        expect(entry.value, 25);
      });

      test('a value outside the confirmed range still converts — it stays '
          'in the log and the derivation treats it as absent, never a '
          'repair write (AD-23)', () {
        final tooSmall = convertLogEntryRecord(
          _record('setting_changed', settingKey: 'time_bag', settingValue: 4),
        );
        expect(tooSmall.flaw, isNull);
        expect((tooSmall.entry as SettingEntry).value, 4);

        final tooLarge = convertLogEntryRecord(
          _record('setting_changed', settingKey: 'time_bag', settingValue: 31),
        );
        expect(tooLarge.flaw, isNull);
        expect((tooLarge.entry as SettingEntry).value, 31);
      });

      test('an unknown setting key converts and derives nothing — carried, '
          'never coerced (AD-23)', () {
        final conversion = convertLogEntryRecord(
          _record(
            'setting_changed',
            settingKey: 'future_setting',
            settingValue: 2,
          ),
        );
        expect(conversion.flaw, isNull);
        expect((conversion.entry as SettingEntry).key, 'future_setting');
      });

      test('setting_changed without its key is excluded', () {
        final noKey = convertLogEntryRecord(
          _record('setting_changed', settingValue: 15),
        );
        expect(noKey.entry, isNull);
        expect(noKey.flaw, LogRecordFlaw.settingKeyAbsent);

        final emptyKey = convertLogEntryRecord(
          _record('setting_changed', settingKey: '', settingValue: 15),
        );
        expect(emptyKey.entry, isNull);
        expect(emptyKey.flaw, LogRecordFlaw.settingKeyAbsent);
      });

      test('setting_changed without its value is excluded', () {
        final conversion = convertLogEntryRecord(
          _record('setting_changed', settingKey: 'time_bag'),
        );
        expect(conversion.entry, isNull);
        expect(conversion.flaw, LogRecordFlaw.settingValueAbsent);
      });

      test('an item pair or stack on setting_changed is excluded', () {
        final withItem = convertLogEntryRecord(
          _record(
            'setting_changed',
            settingKey: 'time_bag',
            settingValue: 15,
            itemId: 'man-a',
            itemOrigin: Origin.shipped,
          ),
        );
        expect(withItem.entry, isNull);
        expect(withItem.flaw, LogRecordFlaw.itemOnNonItemKind);

        final withStack = convertLogEntryRecord(
          _record(
            'setting_changed',
            settingKey: 'time_bag',
            settingValue: 15,
            stack: '#0      build',
          ),
        );
        expect(withStack.entry, isNull);
        expect(withStack.flaw, LogRecordFlaw.stackOffCrashKind);
      });
      test('setting fields on a non-setting kind are excluded, distinctly', () {
        final onAct = convertLogEntryRecord(
          _record(
            'card_done',
            itemId: 'man-a',
            itemOrigin: Origin.shipped,
            settingKey: 'time_bag',
            settingValue: 15,
          ),
        );
        expect(onAct.entry, isNull);
        expect(onAct.flaw, LogRecordFlaw.settingOnNonSettingKind);

        final onMoment = convertLogEntryRecord(
          _record('session_started', settingValue: 15),
        );
        expect(onMoment.entry, isNull);
        expect(onMoment.flaw, LogRecordFlaw.settingOnNonSettingKind);

        final onCrash = convertLogEntryRecord(
          _record(
            'crash_recorded',
            stack: '#0      build',
            settingKey: 'time_bag',
          ),
        );
        expect(onCrash.entry, isNull);
        expect(onCrash.flaw, LogRecordFlaw.settingOnNonSettingKind);
      });

      test('an empty setting key counts as absent everywhere — an empty '
          'string is not a value, on non-setting kinds too (the house '
          'rule, aligned)', () {
        // An empty key with no value carries nothing: the row converts
        // as its own kind, never excluded for a setting it does not
        // hold.
        final onMoment = convertLogEntryRecord(
          _record('app_opened', settingKey: ''),
        );
        expect(onMoment.flaw, isNull);
        expect(onMoment.entry, isA<MomentEntry>());

        final onAct = convertLogEntryRecord(
          _record(
            'card_dealt',
            itemId: 'man-a',
            itemOrigin: Origin.shipped,
            settingKey: '',
          ),
        );
        expect(onAct.flaw, isNull);
        expect(onAct.entry, isA<ItemActEntry>());

        // A value beside the empty key still carries — the flaw fires.
        final carrying = convertLogEntryRecord(
          _record('session_ended', settingKey: '', settingValue: 15),
        );
        expect(carrying.entry, isNull);
        expect(carrying.flaw, LogRecordFlaw.settingOnNonSettingKind);
      });
    });

    test(
      'logEntriesOf keeps the accepted entries in order and drops the rest',
      () {
        final entries = logEntriesOf([
          _record('session_started'),
          _record('card_done', itemId: 'man-a'),
          _record('future_kind'),
          _record('card_dealt', itemId: 'man-a', itemOrigin: Origin.shipped),
        ]);
        expect(entries, hasLength(3));
        expect(entries[0].kind, LogKind.sessionStarted);
        expect(entries[1].kind.known, isFalse);
        expect(entries[2].kind, LogKind.cardDealt);
      },
    );
  });
}

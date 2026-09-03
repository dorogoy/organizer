import 'package:core/energy/energy.dart';
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
  String? settingTextValue,
  int? pocketMinutes,
  int? energyLevel,
  int? reportValue,
  int? reportWeek,
  String? permission,
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
  settingTextValue: settingTextValue,
  pocketMinutes: pocketMinutes,
  energyLevel: energyLevel,
  reportValue: reportValue,
  reportWeek: reportWeek,
  permission: permission,
);

void main() {
  group('LogKind vocabulary membership (AD-21)', () {
    test('holds exactly the build\'s thirteen kinds', () {
      final names = [
        LogKind.cardDealt,
        LogKind.cardDone,
        LogKind.cardSkipped,
        LogKind.sessionStarted,
        LogKind.sessionEnded,
        LogKind.sessionExtended,
        LogKind.appOpened,
        LogKind.crashRecorded,
        LogKind.settingChanged,
        LogKind.energySet,
        LogKind.reportAnswered,
        LogKind.captureCreated,
        LogKind.permissionRefused,
      ].map((kind) => kind.name).toList()..sort();
      expect(names, [
        'app_opened',
        'capture_created',
        'card_dealt',
        'card_done',
        'card_skipped',
        'crash_recorded',
        'energy_set',
        'permission_refused',
        'report_answered',
        'session_ended',
        'session_extended',
        'session_started',
        'setting_changed',
      ]);
      expect(LogKind.knownByName, hasLength(13));
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

    test('a session extension carries its added minutes and nothing else '
        '(Story 2.4, FR-10, AD-19)', () {
      final entry = SessionExtendEntry(
        id: '0190aaaa-0000-7000-8000-00000000000a',
        instantUtcMicros: 8000,
        offsetSeconds: 3600,
        pocketMinutes: 15,
      );
      expect(entry.kind, LogKind.sessionExtended);
      expect(entry.pocketMinutes, 15);
      expect(entry.instantUtcMicros, 8000);
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

    test('moments, session starts and crash entries convert with their own '
        'payloads', () {
      final start = convertLogEntryRecord(_record('session_started')).entry;
      expect(start, isA<SessionStartEntry>());
      expect(start!.kind, LogKind.sessionStarted);
      expect((start as SessionStartEntry).pocketMinutes, isNull);

      final moment = convertLogEntryRecord(_record('session_ended')).entry;
      expect(moment, isA<MomentEntry>());
      expect(moment!.kind, LogKind.sessionEnded);

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

      test('a setting row with neither int nor text is excluded — the '
          'exactly-one-of rule broken by absence (Story 4.3, schema v8)', () {
        final neither = convertLogEntryRecord(
          _record('setting_changed', settingKey: 'selected_provider'),
        );
        expect(neither.entry, isNull);
        expect(neither.flaw, LogRecordFlaw.settingValueAbsent);

        // An empty text is not a value: it counts as absent, so the
        // row still holds neither (the house rule, aligned).
        final emptyText = convertLogEntryRecord(
          _record(
            'setting_changed',
            settingKey: 'selected_provider',
            settingTextValue: '',
          ),
        );
        expect(emptyText.entry, isNull);
        expect(emptyText.flaw, LogRecordFlaw.settingValueAbsent);
      });

      test('a setting row with both int and text is excluded — the '
          'exactly-one-of rule broken by excess (Story 4.3, schema v8)', () {
        final both = convertLogEntryRecord(
          _record(
            'setting_changed',
            settingKey: 'selected_provider',
            settingValue: 15,
            settingTextValue: 'openai',
          ),
        );
        expect(both.entry, isNull);
        expect(both.flaw, LogRecordFlaw.settingValueConflict);
      });

      test('a text-valued setting row converts carrying its text, null int '
          '(Story 4.3, AD-22)', () {
        final conversion = convertLogEntryRecord(
          _record(
            'setting_changed',
            settingKey: 'selected_provider',
            settingTextValue: 'openai',
          ),
        );
        expect(conversion.flaw, isNull);
        final entry = conversion.entry as SettingEntry;
        expect(entry.key, 'selected_provider');
        expect(entry.value, isNull);
        expect(entry.textValue, 'openai');
      });

      test('an int value with an empty text converts as int-only — the '
          'empty string normalizes to absent, never a phantom second '
          'value (Story 4.3)', () {
        final conversion = convertLogEntryRecord(
          _record(
            'setting_changed',
            settingKey: 'time_bag',
            settingValue: 15,
            settingTextValue: '',
          ),
        );
        expect(conversion.flaw, isNull);
        final entry = conversion.entry as SettingEntry;
        expect(entry.value, 15);
        expect(entry.textValue, isNull);
      });

      test('a text value on a non-setting kind is excluded — the payload '
          'column rides its own kind and no other (Story 4.3)', () {
        final onMoment = convertLogEntryRecord(
          _record('app_opened', settingTextValue: 'openai'),
        );
        expect(onMoment.entry, isNull);
        expect(onMoment.flaw, LogRecordFlaw.settingOnNonSettingKind);

        // An empty text on a foreign kind carries nothing: the row
        // converts as its own kind (the house rule).
        final emptyOnMoment = convertLogEntryRecord(
          _record('app_opened', settingTextValue: ''),
        );
        expect(emptyOnMoment.flaw, isNull);
        expect(emptyOnMoment.entry, isA<MomentEntry>());
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

    group('the pocket payload path (Story 2.2, AD-19, AD-23)', () {
      test('a well-shaped session start converts with its pocket intact', () {
        final conversion = convertLogEntryRecord(
          _record('session_started', pocketMinutes: 15),
        );
        final entry = conversion.entry;
        expect(conversion.flaw, isNull);
        expect(entry, isA<SessionStartEntry>());
        expect(entry!.kind, LogKind.sessionStarted);
        expect((entry as SessionStartEntry).pocketMinutes, 15);
      });

      test('a session start without a pocket converts unbounded', () {
        final conversion = convertLogEntryRecord(_record('session_started'));
        expect(conversion.flaw, isNull);
        expect((conversion.entry as SessionStartEntry).pocketMinutes, isNull);
      });

      test('an out-of-range pocket still converts — it stays in the log '
          'and the derivation reads it as absent, never a repair write '
          '(AD-23)', () {
        final imported = convertLogEntryRecord(
          _record('session_started', pocketMinutes: 90),
        );
        expect(imported.flaw, isNull);
        expect((imported.entry as SessionStartEntry).pocketMinutes, 90);

        final zero = convertLogEntryRecord(
          _record('session_started', pocketMinutes: 0),
        );
        expect(zero.flaw, isNull);
        expect((zero.entry as SessionStartEntry).pocketMinutes, 0);
      });

      test('a pocket on a kind that carries no pocket is excluded, '
          'distinctly', () {
        final onEnd = convertLogEntryRecord(
          _record('session_ended', pocketMinutes: 15),
        );
        expect(onEnd.entry, isNull);
        expect(onEnd.flaw, LogRecordFlaw.pocketOnNonPocketKind);

        final onOpen = convertLogEntryRecord(
          _record('app_opened', pocketMinutes: 15),
        );
        expect(onOpen.entry, isNull);
        expect(onOpen.flaw, LogRecordFlaw.pocketOnNonPocketKind);

        final onAct = convertLogEntryRecord(
          _record(
            'card_done',
            itemId: 'man-a',
            itemOrigin: Origin.shipped,
            pocketMinutes: 15,
          ),
        );
        expect(onAct.entry, isNull);
        expect(onAct.flaw, LogRecordFlaw.pocketOnNonPocketKind);

        final onCrash = convertLogEntryRecord(
          _record('crash_recorded', stack: '#0      build', pocketMinutes: 15),
        );
        expect(onCrash.entry, isNull);
        expect(onCrash.flaw, LogRecordFlaw.pocketOnNonPocketKind);

        final onSetting = convertLogEntryRecord(
          _record(
            'setting_changed',
            settingKey: 'time_bag',
            settingValue: 15,
            pocketMinutes: 15,
          ),
        );
        expect(onSetting.entry, isNull);
        expect(onSetting.flaw, LogRecordFlaw.pocketOnNonPocketKind);
      });
    });

    group('the extension payload path (Story 2.4, FR-10, AD-19, AD-23)', () {
      test('a well-shaped session extension converts with its minutes', () {
        final conversion = convertLogEntryRecord(
          _record('session_extended', pocketMinutes: 15),
        );
        final entry = conversion.entry;
        expect(conversion.flaw, isNull);
        expect(entry, isA<SessionExtendEntry>());
        expect(entry!.kind, LogKind.sessionExtended);
        expect((entry as SessionExtendEntry).pocketMinutes, 15);
      });

      test('an extension without its minutes is excluded, distinctly — '
          'the minutes are the row\'s whole payload', () {
        final conversion = convertLogEntryRecord(_record('session_extended'));
        expect(conversion.entry, isNull);
        expect(conversion.flaw, LogRecordFlaw.extendMinutesAbsent);
      });

      test('an out-of-range minute value still converts — it stays in '
          'the log and the derivation treats it as absent, never a '
          'repair write (AD-23)', () {
        final zero = convertLogEntryRecord(
          _record('session_extended', pocketMinutes: 0),
        );
        expect(zero.flaw, isNull);
        expect((zero.entry as SessionExtendEntry).pocketMinutes, 0);

        final negative = convertLogEntryRecord(
          _record('session_extended', pocketMinutes: -5),
        );
        expect(negative.flaw, isNull);
        expect((negative.entry as SessionExtendEntry).pocketMinutes, -5);
      });

      test('an item pair, a stack or setting fields on session_extended '
          'are excluded', () {
        final withItem = convertLogEntryRecord(
          _record(
            'session_extended',
            pocketMinutes: 15,
            itemId: 'man-a',
            itemOrigin: Origin.shipped,
          ),
        );
        expect(withItem.entry, isNull);
        expect(withItem.flaw, LogRecordFlaw.itemOnNonItemKind);

        final withStack = convertLogEntryRecord(
          _record('session_extended', pocketMinutes: 15, stack: '#0      b'),
        );
        expect(withStack.entry, isNull);
        expect(withStack.flaw, LogRecordFlaw.stackOffCrashKind);

        final withSetting = convertLogEntryRecord(
          _record(
            'session_extended',
            pocketMinutes: 15,
            settingKey: 'time_bag',
            settingValue: 15,
          ),
        );
        expect(withSetting.entry, isNull);
        expect(withSetting.flaw, LogRecordFlaw.settingOnNonSettingKind);
      });
    });

    group('the energy payload path (Story 2.5, FR-4, AD-4, AD-23)', () {
      test('a well-shaped energy row converts with its level', () {
        for (final (wire, level) in [
          (0, EnergyLevel.full),
          (1, EnergyLevel.medium),
          (2, EnergyLevel.low),
        ]) {
          final conversion = convertLogEntryRecord(
            _record('energy_set', energyLevel: wire),
          );
          final entry = conversion.entry;
          expect(conversion.flaw, isNull);
          expect(entry, isA<EnergySetEntry>());
          expect(entry!.kind, LogKind.energySet);
          expect((entry as EnergySetEntry).level, level);
        }
      });

      test('the stable wire ints are pinned: 0/1/2 and nothing else '
          'converts', () {
        expect(energyLevelWireOf(EnergyLevel.full), 0);
        expect(energyLevelWireOf(EnergyLevel.medium), 1);
        expect(energyLevelWireOf(EnergyLevel.low), 2);

        final absent = convertLogEntryRecord(_record('energy_set'));
        expect(absent.entry, isNull);
        expect(absent.flaw, LogRecordFlaw.energyLevelAbsent);

        for (final outside in [3, -1, 99]) {
          final outOfRange = convertLogEntryRecord(
            _record('energy_set', energyLevel: outside),
          );
          expect(
            outOfRange.entry,
            isNull,
            reason: 'an out-of-range level excludes the row, quietly',
          );
          expect(outOfRange.flaw, LogRecordFlaw.energyLevelAbsent);
        }
      });

      test('an item pair, a stack, setting fields or a pocket on '
          'energy_set are excluded', () {
        final withItem = convertLogEntryRecord(
          _record(
            'energy_set',
            energyLevel: 2,
            itemId: 'man-a',
            itemOrigin: Origin.shipped,
          ),
        );
        expect(withItem.entry, isNull);
        expect(withItem.flaw, LogRecordFlaw.itemOnNonItemKind);

        final withStack = convertLogEntryRecord(
          _record('energy_set', energyLevel: 2, stack: '#0      b'),
        );
        expect(withStack.entry, isNull);
        expect(withStack.flaw, LogRecordFlaw.stackOffCrashKind);

        final withSetting = convertLogEntryRecord(
          _record(
            'energy_set',
            energyLevel: 2,
            settingKey: 'time_bag',
            settingValue: 15,
          ),
        );
        expect(withSetting.entry, isNull);
        expect(withSetting.flaw, LogRecordFlaw.settingOnNonSettingKind);

        final withPocket = convertLogEntryRecord(
          _record('energy_set', energyLevel: 2, pocketMinutes: 15),
        );
        expect(withPocket.entry, isNull);
        expect(withPocket.flaw, LogRecordFlaw.pocketOnNonPocketKind);
      });

      test('an energy level on any other kind is excluded — the payload '
          'rides its own kind and no other', () {
        final onAct = convertLogEntryRecord(
          _record(
            'card_done',
            itemId: 'man-a',
            itemOrigin: Origin.shipped,
            energyLevel: 1,
          ),
        );
        expect(onAct.entry, isNull);
        expect(onAct.flaw, LogRecordFlaw.energyOnNonEnergyKind);

        final onMoment = convertLogEntryRecord(
          _record('app_opened', energyLevel: 1),
        );
        expect(onMoment.entry, isNull);
        expect(onMoment.flaw, LogRecordFlaw.energyOnNonEnergyKind);

        final onStart = convertLogEntryRecord(
          _record('session_started', pocketMinutes: 15, energyLevel: 1),
        );
        expect(onStart.entry, isNull);
        expect(onStart.flaw, LogRecordFlaw.energyOnNonEnergyKind);

        final onCrash = convertLogEntryRecord(
          _record('crash_recorded', stack: '#0      build', energyLevel: 1),
        );
        expect(onCrash.entry, isNull);
        expect(onCrash.flaw, LogRecordFlaw.energyOnNonEnergyKind);
      });

      test('a corrupt energy row never becomes an entry — the day '
          'derives as unanswered downstream', () {
        final entries = logEntriesOf([
          _record('energy_set'),
          _record('energy_set', energyLevel: 7),
          _record('energy_set', energyLevel: 2),
        ]);
        expect(entries, hasLength(1));
        expect(entries.single, isA<EnergySetEntry>());
      });
    });

    group('the report payload path (Story 2.6, SM-2, AD-21, AD-23)', () {
      test('a well-shaped report row converts carrying both ints — the '
          'value and the week it answers, never a re-derived instant', () {
        for (final value in [1, 3, 5]) {
          final conversion = convertLogEntryRecord(
            _record('report_answered', reportValue: value, reportWeek: 1394),
          );
          final entry = conversion.entry;
          expect(conversion.flaw, isNull);
          expect(entry, isA<ReportAnsweredEntry>());
          expect(entry!.kind, LogKind.reportAnswered);
          expect((entry as ReportAnsweredEntry).value, value);
          expect(entry.week, 1394);
        }
      });

      test('the 1–5 scale is pinned: outside it or absent, the row is '
          'excluded quietly — the week simply has no data point', () {
        expect(reportScaleLeast, 1);
        expect(reportScaleMost, 5);

        final absent = convertLogEntryRecord(
          _record('report_answered', reportWeek: 1394),
        );
        expect(absent.entry, isNull);
        expect(absent.flaw, LogRecordFlaw.reportValueAbsent);

        for (final outside in [0, 6, -1, 99]) {
          final outOfRange = convertLogEntryRecord(
            _record('report_answered', reportValue: outside, reportWeek: 1394),
          );
          expect(
            outOfRange.entry,
            isNull,
            reason: 'an out-of-scale answer excludes the row, quietly',
          );
          expect(outOfRange.flaw, LogRecordFlaw.reportValueAbsent);
        }
      });

      test('a report row without its week is excluded, distinctly — the '
          'week is the answer\'s whole attribution, and persistence can '
          'move the answer outside it', () {
        final conversion = convertLogEntryRecord(
          _record('report_answered', reportValue: 3),
        );
        expect(conversion.entry, isNull);
        expect(conversion.flaw, LogRecordFlaw.reportWeekAbsent);
      });

      test('an item pair, a stack, setting fields, a pocket or an energy '
          'level on report_answered are excluded', () {
        final withItem = convertLogEntryRecord(
          _record(
            'report_answered',
            reportValue: 3,
            reportWeek: 1394,
            itemId: 'man-a',
            itemOrigin: Origin.shipped,
          ),
        );
        expect(withItem.entry, isNull);
        expect(withItem.flaw, LogRecordFlaw.itemOnNonItemKind);

        final withStack = convertLogEntryRecord(
          _record(
            'report_answered',
            reportValue: 3,
            reportWeek: 1394,
            stack: '#0      b',
          ),
        );
        expect(withStack.entry, isNull);
        expect(withStack.flaw, LogRecordFlaw.stackOffCrashKind);

        final withSetting = convertLogEntryRecord(
          _record(
            'report_answered',
            reportValue: 3,
            reportWeek: 1394,
            settingKey: 'time_bag',
            settingValue: 15,
          ),
        );
        expect(withSetting.entry, isNull);
        expect(withSetting.flaw, LogRecordFlaw.settingOnNonSettingKind);

        final withPocket = convertLogEntryRecord(
          _record(
            'report_answered',
            reportValue: 3,
            reportWeek: 1394,
            pocketMinutes: 15,
          ),
        );
        expect(withPocket.entry, isNull);
        expect(withPocket.flaw, LogRecordFlaw.pocketOnNonPocketKind);

        final withEnergy = convertLogEntryRecord(
          _record(
            'report_answered',
            reportValue: 3,
            reportWeek: 1394,
            energyLevel: 1,
          ),
        );
        expect(withEnergy.entry, isNull);
        expect(withEnergy.flaw, LogRecordFlaw.energyOnNonEnergyKind);
      });

      test('report fields on any other kind are excluded — the payload '
          'rides its own kind and no other', () {
        final onAct = convertLogEntryRecord(
          _record(
            'card_done',
            itemId: 'man-a',
            itemOrigin: Origin.shipped,
            reportValue: 3,
          ),
        );
        expect(onAct.entry, isNull);
        expect(onAct.flaw, LogRecordFlaw.reportOnNonReportKind);

        final onMoment = convertLogEntryRecord(
          _record('app_opened', reportValue: 3),
        );
        expect(onMoment.entry, isNull);
        expect(onMoment.flaw, LogRecordFlaw.reportOnNonReportKind);

        final onSetting = convertLogEntryRecord(
          _record(
            'setting_changed',
            settingKey: 'time_bag',
            settingValue: 15,
            reportValue: 3,
          ),
        );
        expect(onSetting.entry, isNull);
        expect(onSetting.flaw, LogRecordFlaw.reportOnNonReportKind);

        final onEnergy = convertLogEntryRecord(
          _record('energy_set', energyLevel: 2, reportWeek: 1394),
        );
        expect(onEnergy.entry, isNull);
        expect(onEnergy.flaw, LogRecordFlaw.reportOnNonReportKind);

        final onStart = convertLogEntryRecord(
          _record('session_started', pocketMinutes: 15, reportValue: 3),
        );
        expect(onStart.entry, isNull);
        expect(onStart.flaw, LogRecordFlaw.reportOnNonReportKind);

        final onCrash = convertLogEntryRecord(
          _record('crash_recorded', stack: '#0      build', reportValue: 3),
        );
        expect(onCrash.entry, isNull);
        expect(onCrash.flaw, LogRecordFlaw.reportOnNonReportKind);

        final onExtend = convertLogEntryRecord(
          _record('session_extended', pocketMinutes: 15, reportWeek: 1394),
        );
        expect(onExtend.entry, isNull);
        expect(onExtend.flaw, LogRecordFlaw.reportOnNonReportKind);
      });

      test('a corrupt report row never becomes an entry, and a good one '
          'survives the boundary in reading order — the week it names '
          'keeps its data point downstream', () {
        final entries = logEntriesOf([
          _record('report_answered', reportWeek: 1394),
          _record('report_answered', reportValue: 6, reportWeek: 1394),
          _record('report_answered', reportValue: 2, reportWeek: 1390),
          _record('report_answered', reportValue: 4, reportWeek: 1394),
        ]);
        expect(entries, hasLength(2));
        final first = entries[0] as ReportAnsweredEntry;
        final second = entries[1] as ReportAnsweredEntry;
        expect(first.value, 2);
        expect(first.week, 1390);
        expect(second.value, 4);
        expect(second.week, 1394);
      });
    });

    group('the capture payload path (Story 3.2, FR-27, AD-14, AD-23)', () {
      test('a well-shaped capture_created converts with its pair intact — '
          'the ItemActEntry family\'s own shape', () {
        final conversion = convertLogEntryRecord(
          _record(
            'capture_created',
            itemId: 'man-cap-1',
            itemOrigin: Origin.manual,
          ),
        );
        final entry = conversion.entry;
        expect(conversion.flaw, isNull);
        expect(entry, isA<ItemActEntry>());
        expect(entry!.kind, LogKind.captureCreated);
        expect((entry as ItemActEntry).itemId, 'man-cap-1');
        expect(entry.itemOrigin, Origin.manual);
      });

      test('a capture_created without its pair at all is excluded — '
          'itemPairAbsent, the family\'s own flaw', () {
        final conversion = convertLogEntryRecord(_record('capture_created'));
        expect(conversion.entry, isNull);
        expect(conversion.flaw, LogRecordFlaw.itemPairAbsent);
      });

      test('a half capture pair is excluded, distinctly — halfItemPair', () {
        final conversion = convertLogEntryRecord(
          _record('capture_created', itemId: 'man-cap-2'),
        );
        expect(conversion.entry, isNull);
        expect(conversion.flaw, LogRecordFlaw.halfItemPair);
      });

      test('an item pair, a stack, setting fields, a pocket, energy or '
          'report fields on capture_created are excluded — the row rides '
          'its pair and nothing else', () {
        final offenders = <LogRecordFlaw, LogEntryRecord>{
          LogRecordFlaw.stackOffCrashKind: _record(
            'capture_created',
            itemId: 'man-cap-3',
            itemOrigin: Origin.manual,
            stack: '#0      build',
          ),
          LogRecordFlaw.settingOnNonSettingKind: _record(
            'capture_created',
            itemId: 'man-cap-3',
            itemOrigin: Origin.manual,
            settingKey: 'time_bag',
          ),
          LogRecordFlaw.pocketOnNonPocketKind: _record(
            'capture_created',
            itemId: 'man-cap-3',
            itemOrigin: Origin.manual,
            pocketMinutes: 15,
          ),
          LogRecordFlaw.energyOnNonEnergyKind: _record(
            'capture_created',
            itemId: 'man-cap-3',
            itemOrigin: Origin.manual,
            energyLevel: 2,
          ),
          LogRecordFlaw.reportOnNonReportKind: _record(
            'capture_created',
            itemId: 'man-cap-3',
            itemOrigin: Origin.manual,
            reportValue: 3,
          ),
        };
        offenders.forEach((flaw, record) {
          final conversion = convertLogEntryRecord(record);
          expect(conversion.entry, isNull, reason: '$flaw');
          expect(conversion.flaw, flaw);
        });
      });

      test('a capture row survives the boundary in reading order beside '
          'the card acts — one family, no flag', () {
        final entries = logEntriesOf([
          _record('card_dealt', itemId: 'shp-a', itemOrigin: Origin.shipped),
          _record(
            'capture_created',
            itemId: 'man-cap-4',
            itemOrigin: Origin.manual,
          ),
          _record('card_done', itemId: 'shp-a', itemOrigin: Origin.shipped),
        ]);
        expect(entries, hasLength(3));
        expect(entries[1].kind, LogKind.captureCreated);
        expect((entries[1] as ItemActEntry).itemId, 'man-cap-4');
      });
    });

    group('the permission payload path (Story 3.4, FR-32, AD-17, AD-23)', () {
      test('a well-shaped permission_refused converts carrying its '
          'permission — the crash shape: own payload, no item pair', () {
        final conversion = convertLogEntryRecord(
          _record('permission_refused', permission: 'microphone'),
        );
        final entry = conversion.entry;
        expect(conversion.flaw, isNull);
        expect(entry, isA<PermissionRefusedEntry>());
        expect(entry!.kind, LogKind.permissionRefused);
        expect(
          (entry as PermissionRefusedEntry).permission,
          Permission.microphone,
        );
      });

      test('each of the three permissions names its own row', () {
        for (final permission in Permission.values) {
          final conversion = convertLogEntryRecord(
            _record('permission_refused', permission: permission.name),
          );
          expect(conversion.flaw, isNull, reason: permission.name);
          expect(
            (conversion.entry as PermissionRefusedEntry).permission,
            permission,
          );
        }
      });

      test('a permission_refused without its permission is excluded — '
          'permissionAbsent, quiet tolerance never a repair write', () {
        final absent = convertLogEntryRecord(_record('permission_refused'));
        expect(absent.entry, isNull);
        expect(absent.flaw, LogRecordFlaw.permissionAbsent);

        final blank = convertLogEntryRecord(
          _record('permission_refused', permission: ''),
        );
        expect(blank.entry, isNull);
        expect(blank.flaw, LogRecordFlaw.permissionAbsent);

        final unknown = convertLogEntryRecord(
          _record('permission_refused', permission: 'telepathy'),
        );
        expect(unknown.entry, isNull);
        expect(unknown.flaw, LogRecordFlaw.permissionAbsent);
      });

      test('an item pair, a stack, setting fields, a pocket, energy or '
          'report fields on permission_refused are excluded — the row '
          'rides its permission and nothing else', () {
        final offenders = <LogRecordFlaw, LogEntryRecord>{
          LogRecordFlaw.itemOnNonItemKind: _record(
            'permission_refused',
            permission: 'microphone',
            itemId: 'man-a',
            itemOrigin: Origin.manual,
          ),
          LogRecordFlaw.stackOffCrashKind: _record(
            'permission_refused',
            permission: 'microphone',
            stack: '#0      build',
          ),
          LogRecordFlaw.settingOnNonSettingKind: _record(
            'permission_refused',
            permission: 'microphone',
            settingKey: 'time_bag',
          ),
          LogRecordFlaw.pocketOnNonPocketKind: _record(
            'permission_refused',
            permission: 'microphone',
            pocketMinutes: 15,
          ),
          LogRecordFlaw.energyOnNonEnergyKind: _record(
            'permission_refused',
            permission: 'microphone',
            energyLevel: 2,
          ),
          LogRecordFlaw.reportOnNonReportKind: _record(
            'permission_refused',
            permission: 'microphone',
            reportValue: 3,
          ),
        };
        offenders.forEach((flaw, record) {
          final conversion = convertLogEntryRecord(record);
          expect(conversion.entry, isNull, reason: '$flaw');
          expect(conversion.flaw, flaw);
        });
      });

      test('a permission payload on any other kind is excluded — the '
          'payload column rides its own kind and no other', () {
        final onAct = convertLogEntryRecord(
          _record(
            'card_done',
            itemId: 'man-a',
            itemOrigin: Origin.shipped,
            permission: 'microphone',
          ),
        );
        expect(onAct.entry, isNull);
        expect(onAct.flaw, LogRecordFlaw.permissionOnNonPermissionKind);

        final onMoment = convertLogEntryRecord(
          _record('app_opened', permission: 'microphone'),
        );
        expect(onMoment.entry, isNull);
        expect(onMoment.flaw, LogRecordFlaw.permissionOnNonPermissionKind);

        final onCrash = convertLogEntryRecord(
          _record(
            'crash_recorded',
            stack: '#0      build',
            permission: 'camera',
          ),
        );
        expect(onCrash.entry, isNull);
        expect(onCrash.flaw, LogRecordFlaw.permissionOnNonPermissionKind);

        final onSetting = convertLogEntryRecord(
          _record(
            'setting_changed',
            settingKey: 'time_bag',
            settingValue: 15,
            permission: 'notifications',
          ),
        );
        expect(onSetting.entry, isNull);
        expect(onSetting.flaw, LogRecordFlaw.permissionOnNonPermissionKind);

        final onCapture = convertLogEntryRecord(
          _record(
            'capture_created',
            itemId: 'man-cap-1',
            itemOrigin: Origin.manual,
            permission: 'microphone',
          ),
        );
        expect(onCapture.entry, isNull);
        expect(onCapture.flaw, LogRecordFlaw.permissionOnNonPermissionKind);
      });

      test('a corrupt permission row never becomes an entry, and a good '
          'one survives the boundary — the derivation downstream reads '
          'the log as if the corrupt row were not there', () {
        final entries = logEntriesOf([
          _record('permission_refused'),
          _record('permission_refused', permission: 'microphone'),
          _record('permission_refused', permission: 'camera'),
        ]);
        expect(entries, hasLength(2));
        expect(
          (entries[0] as PermissionRefusedEntry).permission,
          Permission.microphone,
        );
        expect(
          (entries[1] as PermissionRefusedEntry).permission,
          Permission.camera,
        );
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

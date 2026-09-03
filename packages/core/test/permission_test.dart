import 'package:core/commands/permission_commands.dart';
import 'package:core/derive/permission.dart';
import 'package:core/log/log_entry.dart';
import 'package:core/ports/store_port.dart';
import 'package:core/pool/pool_fact.dart';
import 'package:test/test.dart';

import 'test_util.dart';

LogEntryRecord _refusal(Permission permission, int micros) => (
  id: '0190eeee-0000-7000-8000-$micros',
  kind: LogKind.permissionRefused.name,
  instantUtcMicros: micros,
  offsetSeconds: 3600,
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
  permission: permission.name,
);

void main() {
  group('the single sanctioned permission-refusal minter (Story 3.4, '
      'FR-32, AD-17, AD-3)', () {
    test('returns exactly one content row carrying the permission — the '
        'crash shape: own payload, no item pair, nothing else rides', () {
      for (final permission in Permission.values) {
        final contents = permissionRefuse(permission);
        expect(contents, hasLength(1), reason: permission.name);
        final row = contents.single;
        expect(row.kind, LogKind.permissionRefused);
        expect(row.permission, permission);
        expect(row.itemId, isNull);
        expect(row.itemOrigin, isNull);
        expect(row.stack, isNull);
        expect(row.settingKey, isNull);
        expect(row.settingValue, isNull);
        expect(row.pocketMinutes, isNull);
        expect(row.energyLevel, isNull);
        expect(row.reportValue, isNull);
        expect(row.reportWeek, isNull);
      }
    });

    test('the minted row passes the read boundary unchanged — the '
        'permission round-trips into PermissionRefusedEntry', () {
      final contents = permissionRefuse(Permission.microphone);
      final conversion = convertLogEntryRecord((
        id: '0190eeee-0000-7000-8000-000000000001',
        kind: contents.single.kind.name,
        instantUtcMicros: utcMicros(2026, 9, 2, 10),
        offsetSeconds: 3600,
        itemId: contents.single.itemId,
        itemOrigin: contents.single.itemOrigin,
        stack: contents.single.stack,
        settingKey: contents.single.settingKey,
        settingValue: contents.single.settingValue,
        settingTextValue: null,
        pocketMinutes: contents.single.pocketMinutes,
        energyLevel: contents.single.energyLevel,
        reportValue: contents.single.reportValue,
        reportWeek: contents.single.reportWeek,
        permission: contents.single.permission?.name,
      ));
      expect(conversion.flaw, isNull);
      final entry = conversion.entry as PermissionRefusedEntry;
      expect(entry.kind, LogKind.permissionRefused);
      expect(entry.permission, Permission.microphone);
    });
  });

  group('the permissionMayBeAsked derivation (Story 3.4, FR-32, AD-17, '
      'AD-21 — one definition, entry types only)', () {
    test('an empty log may ask for every permission', () {
      for (final permission in Permission.values) {
        expect(permissionMayBeAsked(const [], permission), isTrue);
      }
    });

    test('a refusal for the named permission makes it false — and only '
        'it', () {
      final entries = logEntriesOf([_refusal(Permission.microphone, 1000)]);
      expect(permissionMayBeAsked(entries, Permission.microphone), isFalse);
      expect(permissionMayBeAsked(entries, Permission.camera), isTrue);
      expect(permissionMayBeAsked(entries, Permission.notifications), isTrue);
    });

    test('the fact is one-way: acts appended after the refusal never '
        'restore it — reversal lives outside the log', () {
      final entries = <LogEntry>[
        ...logEntriesOf([_refusal(Permission.microphone, 1000)]),
        MomentEntry(
          id: '0190eeee-0000-7000-8000-000000000002',
          instantUtcMicros: 2000,
          offsetSeconds: 3600,
          kind: LogKind.appOpened,
        ),
        ItemActEntry(
          id: '0190eeee-0000-7000-8000-000000000003',
          instantUtcMicros: 3000,
          offsetSeconds: 3600,
          kind: LogKind.cardDone,
          itemId: 'shp-a',
          itemOrigin: Origin.shipped,
        ),
      ];
      expect(permissionMayBeAsked(entries, Permission.microphone), isFalse);
    });

    test('a row this build cannot read moves the answer not at all — '
        'the read boundary excluded it before the derivation ran '
        '(AD-23)', () {
      final entries = logEntriesOf([
        _refusal(Permission.camera, 1000),
        () {
          // A permission_refused naming an unknown permission: stored
          // verbatim, excluded at the boundary, deriving nothing.
          return (
            id: '0190eeee-0000-7000-8000-000000000004',
            kind: LogKind.permissionRefused.name,
            instantUtcMicros: 2000,
            offsetSeconds: 3600,
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
            permission: 'telepathy',
          );
        }(),
      ]);
      expect(permissionMayBeAsked(entries, Permission.microphone), isTrue);
      expect(permissionMayBeAsked(entries, Permission.camera), isFalse);
    });
  });
}

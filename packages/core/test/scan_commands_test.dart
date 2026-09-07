import 'package:core/commands/scan_commands.dart';
import 'package:core/log/log_entry.dart';
import 'package:core/ports/store_port.dart';
import 'package:test/test.dart';

void main() {
  group('the face-refusal minter (Story 5.2, FR-25, AD-21)', () {
    test('mints exactly one payload-less face_refused row', () {
      final contents = faceRefused();
      expect(contents, hasLength(1));
      final content = contents.single;
      expect(content.kind, same(LogKind.faceRefused));
      expect(content.kind.name, 'face_refused');
      // The `app_opened` precedent: no payload at all — no item pair,
      // no stack, no setting, no pocket, no energy, no report, no
      // permission, no cause.
      expect(content.itemId, isNull);
      expect(content.itemOrigin, isNull);
      expect(content.stack, isNull);
      expect(content.settingKey, isNull);
      expect(content.settingValue, isNull);
      expect(content.settingTextValue, isNull);
      expect(content.pocketMinutes, isNull);
      expect(content.energyLevel, isNull);
      expect(content.reportValue, isNull);
      expect(content.reportWeek, isNull);
      expect(content.permission, isNull);
      expect(content.sliceCause, isNull);
    });

    test('the row converts back at the read boundary as a moment — '
        'no drift schema change (AD-23)', () {
      LogEntryRecord record({String? permission, String? itemId}) => (
        id: '0190dddd-0000-7000-8000-000000000001',
        kind: 'face_refused',
        instantUtcMicros: 7000,
        offsetSeconds: 3600,
        itemId: itemId,
        itemOrigin: null,
        stack: null,
        settingKey: null,
        settingValue: null,
        settingTextValue: null,
        pocketMinutes: null,
        energyLevel: null,
        reportValue: null,
        reportWeek: null,
        permission: permission,
        sliceCause: null,
      );
      final conversion = convertLogEntryRecord(record());
      expect(conversion.flaw, isNull);
      final entry = conversion.entry!;
      expect(entry, isA<MomentEntry>());
      expect(entry.kind, same(LogKind.faceRefused));
      // A face_refused row carrying any payload is excluded, never
      // coerced: a permission or item pair on the refusal reads as
      // its own kind's violation.
      expect(
        convertLogEntryRecord(record(permission: 'camera')).flaw,
        LogRecordFlaw.permissionOnNonPermissionKind,
      );
      expect(
        convertLogEntryRecord(record(itemId: 'an-item')).flaw,
        LogRecordFlaw.itemOnNonItemKind,
      );
    });
  });

  group('the consent minter (Story 5.4, AD-8, FR-26 b)', () {
    test('mints exactly one payload-less consent_granted row', () {
      final contents = consentGranted();
      expect(contents, hasLength(1));
      final content = contents.single;
      expect(content.kind, same(LogKind.consentGranted));
      expect(content.kind.name, 'consent_granted');
      // The `app_opened` precedent: no payload at all — no item pair,
      // no stack, no setting, no pocket, no energy, no report, no
      // permission, no cause. Instrumentation only, no capability, no
      // scan identity: the token itself is never persisted.
      expect(content.itemId, isNull);
      expect(content.itemOrigin, isNull);
      expect(content.stack, isNull);
      expect(content.settingKey, isNull);
      expect(content.settingValue, isNull);
      expect(content.settingTextValue, isNull);
      expect(content.pocketMinutes, isNull);
      expect(content.energyLevel, isNull);
      expect(content.reportValue, isNull);
      expect(content.reportWeek, isNull);
      expect(content.permission, isNull);
      expect(content.sliceCause, isNull);
    });

    test('the row converts back at the read boundary as a moment — '
        'no drift schema change (AD-23)', () {
      LogEntryRecord record({String? itemId, int? pocketMinutes}) => (
        id: '0190dddd-0000-7000-8000-000000000002',
        kind: 'consent_granted',
        instantUtcMicros: 7000,
        offsetSeconds: 3600,
        itemId: itemId,
        itemOrigin: null,
        stack: null,
        settingKey: null,
        settingValue: null,
        settingTextValue: null,
        pocketMinutes: pocketMinutes,
        energyLevel: null,
        reportValue: null,
        reportWeek: null,
        permission: null,
        sliceCause: null,
      );
      final conversion = convertLogEntryRecord(record());
      expect(conversion.flaw, isNull);
      final entry = conversion.entry!;
      expect(entry, isA<MomentEntry>());
      expect(entry.kind, same(LogKind.consentGranted));
      // A consent_granted row carrying any payload is excluded, never
      // coerced: an item pair or pocket on the row reads as its own
      // kind's violation.
      expect(
        convertLogEntryRecord(record(itemId: 'an-item')).flaw,
        LogRecordFlaw.itemOnNonItemKind,
      );
      expect(
        convertLogEntryRecord(record(pocketMinutes: 15)).flaw,
        LogRecordFlaw.pocketOnNonPocketKind,
      );
    });
  });

  group('the consent-decline minter (Story 5.5, FR-25, FR-26, AD-21)', () {
    test('mints exactly one payload-less consent_declined row', () {
      final contents = consentDeclined();
      expect(contents, hasLength(1));
      final content = contents.single;
      expect(content.kind, same(LogKind.consentDeclined));
      expect(content.kind.name, 'consent_declined');
      // The `app_opened` precedent: no payload at all — no item pair,
      // no stack, no setting, no pocket, no energy, no report, no
      // permission, no cause. A decline record that asserts nothing:
      // no capability, no scan identity, no re-ask state.
      expect(content.itemId, isNull);
      expect(content.itemOrigin, isNull);
      expect(content.stack, isNull);
      expect(content.settingKey, isNull);
      expect(content.settingValue, isNull);
      expect(content.settingTextValue, isNull);
      expect(content.pocketMinutes, isNull);
      expect(content.energyLevel, isNull);
      expect(content.reportValue, isNull);
      expect(content.reportWeek, isNull);
      expect(content.permission, isNull);
      expect(content.sliceCause, isNull);
    });

    test('the row converts back at the read boundary as a moment — '
        'no drift schema change (AD-23)', () {
      LogEntryRecord record({String? permission, int? pocketMinutes}) => (
        id: '0190dddd-0000-7000-8000-000000000003',
        kind: 'consent_declined',
        instantUtcMicros: 7000,
        offsetSeconds: 3600,
        itemId: null,
        itemOrigin: null,
        stack: null,
        settingKey: null,
        settingValue: null,
        settingTextValue: null,
        pocketMinutes: pocketMinutes,
        energyLevel: null,
        reportValue: null,
        reportWeek: null,
        permission: permission,
        sliceCause: null,
      );
      final conversion = convertLogEntryRecord(record());
      expect(conversion.flaw, isNull);
      final entry = conversion.entry!;
      expect(entry, isA<MomentEntry>());
      expect(entry.kind, same(LogKind.consentDeclined));
      // A consent_declined row carrying any payload is excluded, never
      // coerced: a permission or pocket on the row reads as its own
      // kind's violation.
      expect(
        convertLogEntryRecord(record(permission: 'camera')).flaw,
        LogRecordFlaw.permissionOnNonPermissionKind,
      );
      expect(
        convertLogEntryRecord(record(pocketMinutes: 15)).flaw,
        LogRecordFlaw.pocketOnNonPocketKind,
      );
    });
  });

  group('the scan-abandonment minter (Story 5.6, FR-16, AD-8, AD-21)', () {
    test('mints exactly one payload-less scan_abandoned row', () {
      final contents = scanAbandoned();
      expect(contents, hasLength(1));
      final content = contents.single;
      expect(content.kind, same(LogKind.scanAbandoned));
      expect(content.kind.name, 'scan_abandoned');
      // The `app_opened` precedent: no payload at all — no item pair,
      // no stack, no setting, no pocket, no energy, no report, no
      // permission, no cause. The departure asserts nothing beyond
      // itself: no capability, no scan identity, no re-ask.
      expect(content.itemId, isNull);
      expect(content.itemOrigin, isNull);
      expect(content.stack, isNull);
      expect(content.settingKey, isNull);
      expect(content.settingValue, isNull);
      expect(content.settingTextValue, isNull);
      expect(content.pocketMinutes, isNull);
      expect(content.energyLevel, isNull);
      expect(content.reportValue, isNull);
      expect(content.reportWeek, isNull);
      expect(content.permission, isNull);
      expect(content.sliceCause, isNull);
    });

    test('the row converts back at the read boundary as a moment — '
        'never unclassifiedKind (the R1 lesson), no drift schema '
        'change (AD-23)', () {
      LogEntryRecord record({String? itemId, String? permission}) => (
        id: '0190dddd-0000-7000-8000-000000000004',
        kind: 'scan_abandoned',
        instantUtcMicros: 7000,
        offsetSeconds: 3600,
        itemId: itemId,
        itemOrigin: null,
        stack: null,
        settingKey: null,
        settingValue: null,
        settingTextValue: null,
        pocketMinutes: null,
        energyLevel: null,
        reportValue: null,
        reportWeek: null,
        permission: permission,
        sliceCause: null,
      );
      final conversion = convertLogEntryRecord(record());
      expect(conversion.flaw, isNull);
      final entry = conversion.entry!;
      expect(entry, isA<MomentEntry>());
      expect(entry.kind, same(LogKind.scanAbandoned));
      // A scan_abandoned row carrying any payload is excluded, never
      // coerced: an item pair or permission on the row reads as its
      // own kind's violation.
      expect(
        convertLogEntryRecord(record(itemId: 'an-item')).flaw,
        LogRecordFlaw.itemOnNonItemKind,
      );
      expect(
        convertLogEntryRecord(record(permission: 'camera')).flaw,
        LogRecordFlaw.permissionOnNonPermissionKind,
      );
    });
  });
}

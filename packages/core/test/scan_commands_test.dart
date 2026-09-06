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
}

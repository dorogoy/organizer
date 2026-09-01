import 'package:core/commands/report_commands.dart';
import 'package:core/log/log_entry.dart';
import 'package:test/test.dart';

void main() {
  group('the single sanctioned report minter (Story 2.6, SM-2, AD-3)', () {
    test('returns exactly one content row per in-scale value — the answer '
        'and the week are the row\'s whole payload', () {
      for (final value in [1, 2, 3, 4, 5]) {
        final contents = reportAnswered(value: value, week: 1394);
        expect(contents, hasLength(1));
        final row = contents.single;
        expect(row.kind, LogKind.reportAnswered);
        expect(row.reportValue, value);
        expect(row.reportWeek, 1394);
        // Nothing else rides the row: no item, no stack, no setting,
        // no pocket, no energy — and no dismissal state of any kind.
        expect(row.itemId, isNull);
        expect(row.itemOrigin, isNull);
        expect(row.stack, isNull);
        expect(row.settingKey, isNull);
        expect(row.settingValue, isNull);
        expect(row.pocketMinutes, isNull);
        expect(row.energyLevel, isNull);
      }
    });

    test('refusal is silence: a value outside the 1–5 scale mints '
        'nothing — no throw, no error surface', () {
      for (final outside in [0, 6, -1, 99]) {
        expect(reportAnswered(value: outside, week: 1394), isEmpty);
      }
    });

    test('the minted rows pass the read boundary unchanged — the answer '
        'and the week round-trip', () {
      for (final value in [1, 3, 5]) {
        final content = reportAnswered(value: value, week: 1390).single;
        final conversion = convertLogEntryRecord((
          id: '0190eeee-0000-7000-8000-000000000002',
          kind: content.kind.name,
          instantUtcMicros: 7000,
          offsetSeconds: 3600,
          itemId: content.itemId,
          itemOrigin: content.itemOrigin,
          stack: content.stack,
          settingKey: content.settingKey,
          settingValue: content.settingValue,
          pocketMinutes: content.pocketMinutes,
          energyLevel: content.energyLevel,
          reportValue: content.reportValue,
          reportWeek: content.reportWeek,
        ));
        expect(conversion.flaw, isNull);
        expect((conversion.entry as ReportAnsweredEntry).value, value);
        expect((conversion.entry as ReportAnsweredEntry).week, 1390);
      }
    });

    test('week 0 — the epoch week itself — mints and round-trips as a '
        'valid entry: the ordinal\'s whole int domain is carried, never '
        'range-checked', () {
      // The minter guards the value alone; the week needs no guard
      // because every int is a `Week.weekOrdinal` this build can
      // carry — epoch Monday 2000-01-03's own week included, and a
      // future negative week (pre-epoch) would ride just the same.
      final content = reportAnswered(value: 2, week: 0).single;
      expect(content.reportWeek, 0);
      final conversion = convertLogEntryRecord((
        id: '0190eeee-0000-7000-8000-000000000003',
        kind: content.kind.name,
        instantUtcMicros: 7000,
        offsetSeconds: 3600,
        itemId: content.itemId,
        itemOrigin: content.itemOrigin,
        stack: content.stack,
        settingKey: content.settingKey,
        settingValue: content.settingValue,
        pocketMinutes: content.pocketMinutes,
        energyLevel: content.energyLevel,
        reportValue: content.reportValue,
        reportWeek: content.reportWeek,
      ));
      expect(conversion.flaw, isNull);
      final entry = conversion.entry as ReportAnsweredEntry;
      expect(entry.value, 2);
      expect(entry.week, 0);
    });
  });
}

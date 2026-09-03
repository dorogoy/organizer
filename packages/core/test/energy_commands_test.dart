import 'package:core/commands/energy_commands.dart';
import 'package:core/energy/energy.dart';
import 'package:core/log/log_entry.dart';
import 'package:test/test.dart';

void main() {
  group('the single sanctioned energy minter (Story 2.5, FR-4, AD-3)', () {
    test('returns exactly one content row per level — the level is the '
        'row\'s whole payload', () {
      for (final (level, wire) in [
        (EnergyLevel.full, 0),
        (EnergyLevel.medium, 1),
        (EnergyLevel.low, 2),
      ]) {
        final contents = energySet(level: level);
        expect(contents, hasLength(1));
        final row = contents.single;
        expect(row.kind, LogKind.energySet);
        expect(row.energyLevel, wire);
        // Nothing else rides the row: no item, no stack, no setting,
        // no pocket — and no session attribution of any kind.
        expect(row.itemId, isNull);
        expect(row.itemOrigin, isNull);
        expect(row.stack, isNull);
        expect(row.settingKey, isNull);
        expect(row.settingValue, isNull);
        expect(row.pocketMinutes, isNull);
      }
    });

    test('the minter never deals a card — no content row of any other '
        'kind can leave this file', () {
      for (final level in EnergyLevel.values) {
        expect(
          energySet(level: level).map((content) => content.kind),
          everyElement(LogKind.energySet),
        );
      }
    });

    test('the minted rows pass the read boundary unchanged — the wire '
        'ints round-trip', () {
      for (final level in EnergyLevel.values) {
        final content = energySet(level: level).single;
        final conversion = convertLogEntryRecord((
          id: '0190eeee-0000-7000-8000-000000000001',
          kind: content.kind.name,
          instantUtcMicros: 7000,
          offsetSeconds: 3600,
          itemId: content.itemId,
          itemOrigin: content.itemOrigin,
          stack: content.stack,
          settingKey: content.settingKey,
          settingValue: content.settingValue,
          settingTextValue: null,
          pocketMinutes: content.pocketMinutes,
          energyLevel: content.energyLevel,
          reportValue: content.reportValue,
          reportWeek: content.reportWeek,
          permission: null,
        ));
        expect(conversion.flaw, isNull);
        expect((conversion.entry as EnergySetEntry).level, level);
      }
    });
  });
}

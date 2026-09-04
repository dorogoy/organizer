import 'package:core/commands/capture_commands.dart';
import 'package:core/log/log_entry.dart';
import 'package:core/pool/pool_fact.dart';
import 'package:test/test.dart';

import 'test_util.dart';

void main() {
  group('the single sanctioned capture minter (Story 3.2, FR-27, AD-3)', () {
    test('returns the manual fact payload and exactly one content row — '
        'the line as Origin Context, the item pair as the row\'s whole '
        'payload', () {
      final content = captureCreate(
        factId: '0190dddd-0000-7000-8000-000000000001',
        line: 'llamar al dentista',
        size: Size.focus,
        dictated: false,
      )!;
      expect(content.fact.origin, Origin.manual);
      expect(content.fact.size, Size.focus);
      expect(content.fact.originContext, 'llamar al dentista');

      final row = content.entry;
      expect(row.kind, LogKind.captureCreated);
      expect(row.itemId, '0190dddd-0000-7000-8000-000000000001');
      expect(row.itemOrigin, Origin.manual);
      // Nothing else rides the row: no stack, no setting, no pocket, no
      // energy, no report — the item-pair shape, and no flag of any
      // kind on an old kind.
      expect(row.stack, isNull);
      expect(row.settingKey, isNull);
      expect(row.settingValue, isNull);
      expect(row.pocketMinutes, isNull);
      expect(row.energyLevel, isNull);
      expect(row.reportValue, isNull);
      expect(row.reportWeek, isNull);
    });

    test('the line trims once — the stored Origin Context is the single '
        'trimmed line, nothing more', () {
      final content = captureCreate(
        factId: '0190dddd-0000-7000-8000-000000000002',
        line: '  Vaciar la caja de la entrada \t ',
        size: Size.instant,
        dictated: false,
      )!;
      expect(content.fact.originContext, 'Vaciar la caja de la entrada');
    });

    test('a non-spatial line is accepted in silence — no judgement, no '
        'refusal, no marker of any kind', () {
      for (final line in [
        'llamar al dentista',
        'regar las plantas de la vecina',
        '?????',
        'una línea con números 123 y !¡¿?',
      ]) {
        final content = captureCreate(
          factId: '0190dddd-0000-7000-8000-000000000003',
          line: line,
          size: Size.maintenance,
          dictated: false,
        );
        expect(content, isNotNull);
        expect(content!.fact.originContext, line);
        // Silence is structural: no flag, no field and no kind besides
        // the one shape every capture shares.
        expect(content.entry.kind, LogKind.captureCreated);
      }
    });

    test('refusal is silence: a line blank after trimming returns no '
        'content and appends nothing (the boundary\'s own shape)', () {
      for (final blank in ['', ' ', ' \t ', '\n']) {
        expect(
          captureCreate(
            factId: '0190dddd-0000-7000-8000-000000000004',
            line: blank,
            size: Size.focus,
            dictated: false,
          ),
          isNull,
        );
      }
    });

    test('the minter never deals a card — no content row of any other '
        'kind can leave this file', () {
      for (final size in Size.values) {
        final content = captureCreate(
          factId: '0190dddd-0000-7000-8000-000000000005',
          line: 'un rincón cualquiera',
          size: size,
          dictated: false,
        )!;
        expect(content.entry.kind, LogKind.captureCreated);
      }
    });

    test('the dictated boolean rides the fact verbatim — a provenance '
        'fact, written once and outside origin arithmetic either way '
        '(Story 3.4, FR-32)', () {
      final dictated = captureCreate(
        factId: '0190dddd-0000-7000-8000-000000000008',
        line: 'Vaciar la caja de la entrada',
        size: Size.focus,
        dictated: true,
      )!;
      expect(dictated.fact.origin, Origin.manual);
      expect(dictated.fact.dictated, isTrue);

      final typed = captureCreate(
        factId: '0190dddd-0000-7000-8000-000000000009',
        line: 'Vaciar la caja de la entrada',
        size: Size.focus,
        dictated: false,
      )!;
      expect(typed.fact.origin, Origin.manual);
      expect(typed.fact.dictated, isFalse);

      // The log row rides its item pair and nothing else either way —
      // no dictation flag reaches the log (a new kind is a new kind,
      // never a flag on an old one).
      expect(dictated.entry.kind, LogKind.captureCreated);
      expect(dictated.entry.itemId, '0190dddd-0000-7000-8000-000000000008');
      expect(dictated.entry.permission, isNull);
      expect(typed.entry.kind, LogKind.captureCreated);
    });

    test('the minted row passes the read boundary unchanged — the item '
        'pair round-trips into the ItemActEntry family', () {
      final content = captureCreate(
        factId: '0190dddd-0000-7000-8000-000000000006',
        line: 'Colgar la toalla que está en el sofá',
        size: Size.maintenance,
        dictated: false,
      )!;
      final conversion = convertLogEntryRecord((
        id: '0190dddd-0000-7000-8000-000000000007',
        kind: content.entry.kind.name,
        instantUtcMicros: utcMicros(2026, 9, 1, 9, 30),
        offsetSeconds: 3600,
        itemId: content.entry.itemId,
        itemOrigin: content.entry.itemOrigin,
        stack: content.entry.stack,
        settingKey: content.entry.settingKey,
        settingValue: content.entry.settingValue,
        settingTextValue: null,
        pocketMinutes: content.entry.pocketMinutes,
        energyLevel: content.entry.energyLevel,
        reportValue: content.entry.reportValue,
        reportWeek: content.entry.reportWeek,
        permission: null,
        sliceCause: null,
      ));
      expect(conversion.flaw, isNull);
      final entry = conversion.entry as ItemActEntry;
      expect(entry.kind, LogKind.captureCreated);
      expect(entry.itemId, content.entry.itemId);
      expect(entry.itemOrigin, Origin.manual);
    });
  });
}

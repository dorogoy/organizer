import 'dart:convert';

import 'package:core/slicer/scan_steps.dart';
import 'package:test/test.dart';

/// One contract-shaped body over handed-in parts — the wire's own
/// object, composed so each clause below varies exactly one thing.
String body(Object description, List<Map<String, Object?>> steps) =>
    jsonEncode({'description': description, 'steps': steps});

Map<String, Object?> step(Object text, Object duration) => {
  'text': text,
  'duration_minutes': duration,
};

const String description = 'Un rincón con cajas apiladas junto a la puerta';

void main() {
  group('the bounds (FR-16, AD-5)', () {
    test('the contract\'s own constants — 1–6 steps of 3–5 minutes each '
        '— and the parse\'s own text ceilings', () {
      expect(scanStepsLeast, 1);
      expect(scanStepsMost, 6);
      expect(scanStepMinutesLeast, 3);
      expect(scanStepMinutesMost, 5);
      expect(scanStepSecondsLeast, 180);
      expect(scanStepSecondsMost, 300);
      expect(scanStepTextMost, 160);
      expect(scanDescriptionTextMost, 400);
    });

    test('the wire field names — the scan prompt\'s four, stated here '
        'as this library\'s own (parity pinned shell-side)', () {
      expect(scanWireDescriptionField, 'description');
      expect(scanWireStepsField, 'steps');
      expect(scanWireTextField, 'text');
      expect(scanWireDurationField, 'duration_minutes');
    });

    test('the response contract advertises a complete JSON object', () {
      final example = scanResponseContract
          .replaceFirst(
            'Responde únicamente con un objeto JSON con la forma ',
            '',
          )
          .replaceFirst(', y nada más.', '');
      final decoded = jsonDecode(example);

      expect(decoded, {
        scanWireDescriptionField: '…',
        scanWireStepsField: [
          {scanWireTextField: '…', scanWireDurationField: 4},
        ],
      });
    });
  });

  group('parseScanSlice', () {
    test('a canonical body parses: the description and texts trimmed, '
        'the durations verbatim in minutes', () {
      final slice = parseScanSlice(
        body('  Un rincón con cajas  ', [
          step('  Recoger la caja de arriba  ', 3),
          step('Doblar la ropa del sofá', 5),
        ]),
      );
      expect(slice, isNotNull);
      expect(slice!.description, 'Un rincón con cajas');
      expect(slice.steps, hasLength(2));
      expect(slice.steps[0].text, 'Recoger la caja de arriba');
      expect(slice.steps[0].durationMinutes, 3);
      expect(slice.steps[1].text, 'Doblar la ropa del sofá');
      expect(slice.steps[1].durationMinutes, 5);
    });

    test('the full span admits: one step, six steps, three and five '
        'minutes', () {
      expect(
        parseScanSlice(body(description, [step('Uno', 3)])),
        isNotNull,
        reason:
            'the least count parses — a scan slice is not a '
            're-slice, one step is a plan',
      );
      expect(
        parseScanSlice(body(description, [step('Uno', 5)])),
        isNotNull,
        reason: 'the most minutes parse',
      );
      expect(
        parseScanSlice(
          body(description, [for (var i = 0; i < 6; i++) step('Paso $i', 4)]),
        ),
        isNotNull,
        reason: 'the most count parses',
      );
    });

    test('unknown extra keys ride along — a provider\'s dialect may add '
        'what it likes around the four names the contract owns', () {
      final slice = parseScanSlice(
        body(description, [
          {...step('Paso uno', 4), 'role': 'head', 'why': 'porque'},
          {...step('Paso dos', 5), 'index': 1},
        ]),
      );
      expect(slice, isNotNull);
      expect(slice!.steps, hasLength(2));
      expect(slice.steps[1].text, 'Paso dos');
    });

    test('not JSON answers null — one failure cause covers them all', () {
      expect(parseScanSlice('El plan es: primero...'), isNull);
      expect(parseScanSlice(''), isNull);
    });

    test('not an object answers null', () {
      expect(
        parseScanSlice(jsonEncode([step('Uno', 4)])),
        isNull,
        reason: 'a bare steps array is not the scan slice',
      );
      expect(parseScanSlice(jsonEncode('steps')), isNull);
      expect(parseScanSlice('null'), isNull);
    });

    test('a missing, non-string, blank or whitespace-only description '
        'answers null', () {
      expect(
        parseScanSlice(
          jsonEncode({
            'steps': [step('Uno', 4)],
          }),
        ),
        isNull,
        reason: 'no description — the slice carries no Origin Context',
      );
      expect(parseScanSlice(body(7, [step('Uno', 4)])), isNull);
      expect(parseScanSlice(body('', [step('Uno', 4)])), isNull);
      expect(parseScanSlice(body('   ', [step('Uno', 4)])), isNull);
    });

    test('description text at the bound parses, one code unit over '
        'rejects — the bound rides the trimmed text, UTF-16 units', () {
      final atBound = 'p' * scanDescriptionTextMost;
      final slice = parseScanSlice(body('  $atBound  ', [step('Uno', 4)]));
      expect(
        slice,
        isNotNull,
        reason:
            'exactly the bound is not over it, and the measure is the '
            'trimmed text — the padding does not count',
      );
      expect(slice!.description, atBound);
      expect(
        parseScanSlice(
          body('p' * (scanDescriptionTextMost + 1), [step('Uno', 4)]),
        ),
        isNull,
        reason: 'one code unit over the bound rejects the whole body',
      );
    });

    test('no steps array answers null', () {
      expect(parseScanSlice(jsonEncode({'description': description})), isNull);
      expect(
        parseScanSlice(jsonEncode({'description': description, 'pasos': []})),
        isNull,
      );
    });

    test('a steps array outside 1–6 answers null — the parse\'s own '
        'wall bound', () {
      expect(parseScanSlice(body(description, [])), isNull);
      expect(
        parseScanSlice(
          body(description, [for (var i = 0; i < 7; i++) step('Paso $i', 4)]),
        ),
        isNull,
      );
    });

    test('a step that is not an object answers null', () {
      expect(
        parseScanSlice(
          jsonEncode({
            'description': description,
            'steps': ['Recoger una caja', 4],
          }),
        ),
        isNull,
      );
    });

    test('a missing, non-string, blank or whitespace-only text answers '
        'null', () {
      expect(
        parseScanSlice(
          body(description, [
            {'duration_minutes': 4},
            step('Dos', 4),
          ]),
        ),
        isNull,
      );
      expect(
        parseScanSlice(body(description, [step(7, 4), step('Dos', 4)])),
        isNull,
      );
      expect(
        parseScanSlice(body(description, [step('', 4), step('Dos', 4)])),
        isNull,
      );
      expect(
        parseScanSlice(body(description, [step('   ', 4), step('Dos', 4)])),
        isNull,
      );
    });

    test('step text at the bound parses, one code unit over rejects '
        '— the bound rides the trimmed text, UTF-16 units, not bytes', () {
      final atBound = 'p' * scanStepTextMost;
      final slice = parseScanSlice(
        body(description, [step('  $atBound  ', 4), step('Dos', 4)]),
      );
      expect(
        slice,
        isNotNull,
        reason:
            'exactly the bound is not over it, and the measure is '
            'the trimmed text — the padding does not count',
      );
      expect(slice!.steps.first.text, atBound);
      final acentos = 'á' * (scanStepTextMost - 2);
      final sliceAcentos = parseScanSlice(
        body(description, [step('      $acentos      ', 4), step('Dos', 4)]),
      );
      expect(
        sliceAcentos,
        isNotNull,
        reason:
            'the raw wire string runs past the bound but trims under '
            'it — a Spanish accent is one UTF-16 unit, never two bytes',
      );
      expect(sliceAcentos!.steps.first.text, acentos);
      expect(
        parseScanSlice(
          body(description, [step('p' * (scanStepTextMost + 1), 4)]),
        ),
        isNull,
        reason: 'one code unit over the bound rejects the whole body',
      );
    });

    test('a missing, non-integer or out-of-band duration answers null '
        '— a double is not the contract\'s integer, and neither is a '
        'numeral-shaped string', () {
      expect(
        parseScanSlice(
          body(description, [
            {'text': 'Uno'},
            step('Dos', 4),
          ]),
        ),
        isNull,
      );
      expect(
        parseScanSlice(body(description, [step('Uno', 4.5), step('Dos', 4)])),
        isNull,
      );
      expect(
        parseScanSlice(body(description, [step('Uno', '4'), step('Dos', 4)])),
        isNull,
      );
      expect(
        parseScanSlice(body(description, [step('Uno', 2), step('Dos', 4)])),
        isNull,
        reason: 'two minutes is under the 3–5 band',
      );
      expect(
        parseScanSlice(body(description, [step('Uno', 6), step('Dos', 4)])),
        isNull,
        reason: 'six minutes is over the 3–5 band',
      );
      expect(
        parseScanSlice(body(description, [step('Uno', -4), step('Dos', 4)])),
        isNull,
      );
    });

    test('one bad step spoils the body — nothing repairs, retries or '
        'coaxes a near-miss into shape (AD-23\'s tolerance is for '
        'unknown log kinds, never for a slice this build would land '
        'as work)', () {
      expect(
        parseScanSlice(
          body(description, [
            step('Bien', 4),
            step('También bien', 5),
            step('Vació', 9),
          ]),
        ),
        isNull,
      );
      expect(
        parseScanSlice(
          body(description, [
            step('Bien', 4),
            step('También bien', 5),
            step('p' * (scanStepTextMost + 1), 4),
          ]),
        ),
        isNull,
        reason:
            'the wall guard refuses whole, it never trims the words '
            'into shape',
      );
    });
  });
}

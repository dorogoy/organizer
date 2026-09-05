import 'dart:convert';

import 'package:core/slicer/rescue_steps.dart';
import 'package:test/test.dart';

/// One contract-shaped body over handed-in steps — the wire's own
/// object, composed so each clause below varies exactly one thing.
String body(List<Map<String, Object?>> steps) => jsonEncode({'steps': steps});

Map<String, Object?> step(Object text, Object duration) => {
  'text': text,
  'duration_seconds': duration,
};

void main() {
  group('the bounds (FR-5, AD-5)', () {
    test('the contract\'s own constants — 2–4 steps of 1–60 s each '
        '— and the parse\'s own text ceiling', () {
      expect(rescueStepsLeast, 2);
      expect(rescueStepsMost, 4);
      expect(rescueStepSecondsLeast, 1);
      expect(rescueStepSecondsMost, 60);
      expect(rescueStepTextMost, 120);
    });

    test('the wire field names — the shell contract\'s three, stated '
        'here as this library\'s own (parity pinned shell-side)', () {
      expect(rescueWireStepsField, 'steps');
      expect(rescueWireTextField, 'text');
      expect(rescueWireDurationField, 'duration_seconds');
    });
  });

  group('parseRescueSteps', () {
    test('a canonical body parses: the texts trimmed, the durations '
        'verbatim', () {
      final steps = parseRescueSteps(
        body([
          step('  Buscar el desengrasante bajo el fregadero  ', 45),
          step('Rociar la campana y esperar un minuto', 60),
        ]),
      );
      expect(steps, isNotNull);
      expect(steps!.length, 2);
      expect(steps[0].text, 'Buscar el desengrasante bajo el fregadero');
      expect(steps[0].durationSeconds, 45);
      expect(steps[1].text, 'Rociar la campana y esperar un minuto');
      expect(steps[1].durationSeconds, 60);
    });

    test('the full span admits: two steps, four steps, one second, '
        'sixty seconds', () {
      expect(
        parseRescueSteps(body([step('Uno', 1), step('Dos', 60)])),
        isNotNull,
        reason: 'the least count and both duration extremes parse',
      );
      expect(
        parseRescueSteps(
          body([step('Uno', 30), step('Dos', 30), step('Tres', 30)]),
        ),
        isNotNull,
        reason: 'the middle count parses too',
      );
      expect(
        parseRescueSteps(
          body([
            step('Uno', 30),
            step('Dos', 30),
            step('Tres', 30),
            step('Cuatro', 30),
          ]),
        ),
        isNotNull,
        reason: 'the most count parses',
      );
    });

    test('unknown extra keys ride along — a provider\'s dialect may add '
        'what it likes around the three names the contract owns', () {
      final steps = parseRescueSteps(
        body([
          {...step('Paso uno', 20), 'role': 'head', 'why': 'porque'},
          {...step('Paso dos', 25), 'index': 1},
        ]),
      );
      expect(steps, isNotNull);
      expect(steps!.length, 2);
      expect(steps[1].text, 'Paso dos');
    });

    test('not JSON answers null — one failure cause covers them all', () {
      expect(parseRescueSteps('Los pasos son: primero...'), isNull);
      expect(parseRescueSteps(''), isNull);
    });

    test('not an object answers null', () {
      expect(parseRescueSteps(jsonEncode([step('Uno', 10)])), isNull);
      expect(parseRescueSteps(jsonEncode('steps')), isNull);
      expect(parseRescueSteps('null'), isNull);
    });

    test('no steps array answers null', () {
      expect(parseRescueSteps(jsonEncode({'pasos': []})), isNull);
      expect(parseRescueSteps(jsonEncode({})), isNull);
    });

    test('a steps array outside 2–4 answers null — below is not a '
        're-slice, above is a wall', () {
      expect(parseRescueSteps(body([step('Único', 30)])), isNull);
      expect(
        parseRescueSteps(
          body([
            step('Uno', 15),
            step('Dos', 15),
            step('Tres', 15),
            step('Cuatro', 15),
            step('Cinco', 15),
          ]),
        ),
        isNull,
      );
    });

    test('a step that is not an object answers null', () {
      expect(
        parseRescueSteps(
          jsonEncode({
            'steps': ['Buscar el trapo', 30],
          }),
        ),
        isNull,
      );
    });

    test('a missing, non-string, blank or whitespace-only text answers '
        'null', () {
      expect(
        parseRescueSteps(
          body([
            {'duration_seconds': 30},
            step('Dos', 30),
          ]),
        ),
        isNull,
      );
      expect(parseRescueSteps(body([step(7, 30), step('Dos', 30)])), isNull);
      expect(parseRescueSteps(body([step('', 30), step('Dos', 30)])), isNull);
      expect(
        parseRescueSteps(body([step('   ', 30), step('Dos', 30)])),
        isNull,
      );
    });

    test('step text at the bound parses, one code unit over rejects '
        '— the bound rides the trimmed text, UTF-16 units, not bytes', () {
      final atBound = 'p' * 120;
      final steps = parseRescueSteps(
        body([step('  $atBound  ', 30), step('Dos', 30)]),
      );
      expect(
        steps,
        isNotNull,
        reason:
            'exactly the bound is not over it, and the measure is '
            'the trimmed text — the padding does not count',
      );
      expect(steps!.first.text, atBound);
      final acentos = 'á' * 118;
      final stepsAcentos = parseRescueSteps(
        body([step('      $acentos      ', 30), step('Dos', 30)]),
      );
      expect(
        stepsAcentos,
        isNotNull,
        reason:
            'the raw wire string runs past the bound but trims under '
            'it — a Spanish accent is one UTF-16 unit, never two bytes',
      );
      expect(stepsAcentos!.first.text, acentos);
      expect(
        parseRescueSteps(body([step('p' * 121, 30), step('Dos', 30)])),
        isNull,
        reason: 'one code unit over the bound rejects the whole body',
      );
      expect(
        parseRescueSteps(body([step('😀' * 60, 30), step('Dos', 30)])),
        isNotNull,
        reason:
            'sixty surrogate pairs are one hundred twenty UTF-16 '
            'code units — the bound counts units, not characters',
      );
      expect(
        parseRescueSteps(body([step('😀' * 61, 30), step('Dos', 30)])),
        isNull,
        reason:
            'sixty-one surrogate pairs are one hundred twenty-two '
            'code units — two over the bound',
      );
    });

    test('a missing, non-integer or out-of-band duration answers null '
        '— a double is not the contract\'s integer, and neither is a '
        'numeral-shaped string', () {
      expect(
        parseRescueSteps(
          body([
            {'text': 'Uno'},
            step('Dos', 30),
          ]),
        ),
        isNull,
      );
      expect(
        parseRescueSteps(body([step('Uno', 30.5), step('Dos', 30)])),
        isNull,
      );
      expect(
        parseRescueSteps(body([step('Uno', '30'), step('Dos', 30)])),
        isNull,
      );
      expect(
        parseRescueSteps(body([step('Uno', 0), step('Dos', 30)])),
        isNull,
        reason: 'zero seconds is under the band',
      );
      expect(
        parseRescueSteps(body([step('Uno', 61), step('Dos', 30)])),
        isNull,
        reason: 'sixty-one seconds is over the ≤ 60 s band',
      );
      expect(
        parseRescueSteps(body([step('Uno', -5), step('Dos', 30)])),
        isNull,
      );
    });

    test('one bad step spoils the body — nothing repairs, retries or '
        'coaxes a near-miss into shape (AD-23\'s tolerance is for '
        'unknown log kinds, never for a slice this build would weave '
        'as work)', () {
      expect(
        parseRescueSteps(
          body([
            step('Bien', 30),
            step('También bien', 45),
            step('Vació', 999),
          ]),
        ),
        isNull,
      );
    });

    test('one over-long step among valid ones spoils the body — the '
        'wall guard refuses whole, it never trims the words into '
        'shape', () {
      expect(
        parseRescueSteps(
          body([
            step('Bien', 30),
            step('También bien', 45),
            step('p' * 121, 20),
          ]),
        ),
        isNull,
      );
    });
  });
}

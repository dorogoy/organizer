import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';

import 'package:eval/candidates.dart';
import 'package:eval/verdict.dart';

/// The real shared inputs — the tests exercise exactly what the candidates
/// receive (cwd for `dart test` is the eval package root).
final schemaJson = File('schema.json').readAsStringSync();

String planJson({List<int> durations = const [4, 4, 4, 4]}) => jsonEncode({
  'steps': [
    for (final d in durations) {'text': 'paso', 'duration_minutes': d},
  ],
});

PhotoVerdict machinePassing(String photoId, {String candidate = 'e2b_local'}) {
  final evaluation = evaluateModelOutput(TextOutput(planJson()));
  return PhotoVerdict(
    candidate: candidate,
    photoId: photoId,
    photoFile: '$photoId.jpg',
    spaceType: 'cocina',
    model: 'm',
    timestamp: 't',
    transportOk: true,
    machine: evaluation.verdict,
    steps: evaluation.steps,
  );
}

PhotoVerdict passedPhoto(String photoId, {String candidate = 'e2b_local'}) =>
    machinePassing(
      photoId,
      candidate: candidate,
    ).withHuman(const HumanVerdict(realActions: true, workableOrder: true));

PhotoVerdict failedPhoto(String photoId, {String candidate = 'e2b_local'}) =>
    PhotoVerdict(
      candidate: candidate,
      photoId: photoId,
      photoFile: '$photoId.jpg',
      spaceType: 'cocina',
      model: 'm',
      timestamp: 't',
      transportOk: false,
      transportReason: 'HTTP 500: boom',
    ).withHuman(
      const HumanVerdict(
        realActions: false,
        workableOrder: false,
        autoRecorded: true,
      ),
    );

List<PhotoVerdict> runOf(
  int passedCount, {
  String candidate = 'e2b_local',
  int unresolved = 0,
}) {
  final verdicts = <PhotoVerdict>[
    for (var i = 0; i < passedCount; i++)
      passedPhoto('p$i', candidate: candidate),
  ];
  var failed = 0;
  while (verdicts.length < corpusSize - unresolved) {
    verdicts.add(failedPhoto('f${failed++}', candidate: candidate));
  }
  var pending = 0;
  while (verdicts.length < corpusSize) {
    verdicts.add(machinePassing('u${pending++}', candidate: candidate));
  }
  return verdicts;
}

void main() {
  group('validateSlicePlan', () {
    test('accepts the canonical minimal schema shape', () {
      expect(validateSlicePlan(jsonDecode(planJson())), isEmpty);
    });

    test('rejects a non-object root', () {
      expect(validateSlicePlan([1, 2]), contains('root is not a JSON object'));
      expect(validateSlicePlan('x'), contains('root is not a JSON object'));
    });

    test('rejects a missing steps property', () {
      expect(
        validateSlicePlan({}),
        contains("missing required property 'steps'"),
      );
    });

    test('rejects steps that is not an array', () {
      expect(
        validateSlicePlan({'steps': 4}),
        contains("'steps' is not an array"),
      );
    });

    test('rejects unexpected root and step properties', () {
      final value = jsonDecode(
        '{"steps": [{"text": "a", "duration_minutes": 4}], "extra": 1}',
      );
      expect(
        validateSlicePlan(value),
        contains(contains('unexpected root properties: extra')),
      );
      final value2 = jsonDecode(
        '{"steps": [{"text": "a", "duration_minutes": 4, "why": 1}]}',
      );
      expect(
        validateSlicePlan(value2),
        contains(contains('steps[1] unexpected properties: why')),
      );
    });

    test('rejects wrong field types inside a step', () {
      final missing = jsonDecode('{"steps": [{"text": "a"}]}');
      expect(
        validateSlicePlan(missing),
        contains(contains("missing 'duration_minutes'")),
      );
      final notString = jsonDecode(
        '{"steps": [{"text": 1, "duration_minutes": 4}]}',
      );
      expect(
        validateSlicePlan(notString),
        contains(contains("'text' is not a string")),
      );
      final fractional = jsonDecode(
        '{"steps": [{"text": "a", "duration_minutes": 4.5}]}',
      );
      expect(
        validateSlicePlan(fractional),
        contains(contains("'duration_minutes' is not an integer")),
      );
    });
  });

  group('evaluateModelOutput — machine limbs', () {
    test('all three limbs pass on a clean first-attempt answer', () {
      final evaluation = evaluateModelOutput(TextOutput(planJson()));
      expect(evaluation.verdict.allPassed, isTrue);
      expect(evaluation.steps, hasLength(4));
    });

    test(
      'a DecodedOutput (Anthropic tool_use input) goes through the same limbs',
      () {
        final evaluation = evaluateModelOutput(
          DecodedOutput(jsonDecode(planJson())),
        );
        expect(evaluation.verdict.allPassed, isTrue);
      },
    );

    test('a single markdown fence is stripped once and recorded (2026-09-02 amendment)', () {
      final fenced = '```json\n${planJson()}\n```';
      final evaluation = evaluateModelOutput(TextOutput(fenced));
      expect(evaluation.verdict.allPassed, isTrue);
      expect(evaluation.verdict.fenceStripped, isTrue);
      expect(evaluation.steps, hasLength(4));
    });

    test('a bare answer records fenceStripped false', () {
      final evaluation = evaluateModelOutput(TextOutput(planJson()));
      expect(evaluation.verdict.allPassed, isTrue);
      expect(evaluation.verdict.fenceStripped, isFalse);
    });

    test('a fence without the json tag is still a single fence', () {
      final evaluation = evaluateModelOutput(
        TextOutput('```\n${planJson()}\n```'),
      );
      expect(evaluation.verdict.allPassed, isTrue);
      expect(evaluation.verdict.fenceStripped, isTrue);
    });

    test(
      'prose around the JSON still fails — the amendment is one fence only',
      () {
        final chatty = 'Here is the plan:\n```json\n${planJson()}\n```\nDone!';
        final evaluation = evaluateModelOutput(TextOutput(chatty));
        expect(evaluation.verdict.parse.ok, isFalse);
        expect(
          evaluation.verdict.parse.reason,
          contains('first-attempt JSON parse failed'),
        );
      },
    );

    test('two fences still fail — no repeated stripping', () {
      final doubleFenced = '```json\n```\n${planJson()}\n```\n```';
      final evaluation = evaluateModelOutput(TextOutput(doubleFenced));
      expect(evaluation.verdict.parse.ok, isFalse);
    });

    test('an unclosed fence still fails', () {
      final evaluation = evaluateModelOutput(
        TextOutput('```json\n${planJson()}'),
      );
      expect(evaluation.verdict.parse.ok, isFalse);
    });

    test('a fence wrapping invalid JSON still fails with the reason', () {
      final evaluation = evaluateModelOutput(
        TextOutput('```json\nnot json at all\n```'),
      );
      expect(evaluation.verdict.parse.ok, isFalse);
      expect(
        evaluation.verdict.parse.reason,
        contains('first-attempt JSON parse failed'),
      );
      expect(evaluation.verdict.fenceStripped, isFalse);
    });

    test('double-encoded JSON fails the schema check', () {
      final evaluation = evaluateModelOutput(
        TextOutput(jsonEncode(planJson())),
      );
      expect(evaluation.verdict.parse.ok, isFalse);
      expect(
        evaluation.verdict.parse.reason,
        contains('root is not a JSON object'),
      );
    });

    test('a 200-with-nothing-extractable answer fails the parse limb with its reason', () {
      final evaluation = evaluateModelOutput(
        const OutputAbsent('no tool_use block'),
      );
      expect(evaluation.verdict.parse.ok, isFalse);
      expect(evaluation.verdict.parse.reason, contains('no tool_use block'));
    });

    test('durations outside 3–5 fail the duration limb and name the step', () {
      for (final duration in [2, 6]) {
        final evaluation = evaluateModelOutput(
          TextOutput(planJson(durations: [4, duration, 4, 4])),
        );
        expect(
          evaluation.verdict.parse.ok,
          isTrue,
          reason: 'duration $duration',
        );
        expect(evaluation.verdict.durations.ok, isFalse);
        expect(
          evaluation.verdict.durations.reason,
          contains('step 2: duration_minutes $duration outside 3–5'),
        );
      }
      final boundaries = evaluateModelOutput(
        TextOutput(planJson(durations: [3, 5, 3, 5])),
      );
      expect(boundaries.verdict.durations.ok, isTrue);
    });

    test('fewer than 4 steps fails the step-count limb', () {
      final evaluation = evaluateModelOutput(
        TextOutput(planJson(durations: [4, 4, 4])),
      );
      expect(evaluation.verdict.steps.ok, isFalse);
      expect(
        evaluation.verdict.steps.reason,
        contains('3 steps — at least 4 required'),
      );
    });
  });

  group('tally and the 8-of-10 bar', () {
    test('7 of 10 fails the bar, 8 of 10 passes it', () {
      expect(tally('c', runOf(7)).passesBar, isFalse);
      expect(tally('c', runOf(8)).passesBar, isTrue);
    });

    test('the bar reads null while judging is incomplete', () {
      final t = tally('c', runOf(8, unresolved: 1));
      expect(t.complete, isFalse);
      expect(t.passesBar, isNull);
    });

    test('transport-failed photos with auto-recorded limbs count as resolved failures', () {
      final t = tally('c', runOf(0));
      expect(t.resolved, corpusSize);
      expect(t.passed, 0);
      expect(t.passesBar, isFalse);
    });
  });

  group('cascadeProposal', () {
    test('an E2B pass selects E2B provisionally and nothing later runs', () {
      final results = {
        'e2b_local': tally('e2b_local', runOf(9, candidate: 'e2b_local')),
      };
      final proposal = cascadeProposal(results);
      expect(proposal.kind, 'local-provisional');
      expect(proposal.selected, 'e2b_local');
      expect(proposal.rationale, contains('stays unrun'));
    });

    test('only an E2B failure promotes E4B', () {
      final results = {
        'e2b_local': tally('e2b_local', runOf(7, candidate: 'e2b_local')),
        'e4b_local': tally('e4b_local', runOf(8, candidate: 'e4b_local')),
      };
      final proposal = cascadeProposal(results);
      expect(proposal.kind, 'local-provisional');
      expect(proposal.selected, 'e4b_local');
    });

    test(
      'both locals killed runs the cloud trio; ties break in cascade order',
      () {
        final results = {
          'e2b_local': tally('e2b_local', runOf(5, candidate: 'e2b_local')),
          'e4b_local': tally('e4b_local', runOf(6, candidate: 'e4b_local')),
          'gemini': tally('gemini', runOf(9, candidate: 'gemini')),
          'openai': tally('openai', runOf(8, candidate: 'openai')),
          'anthropic': tally('anthropic', runOf(9, candidate: 'anthropic')),
        };
        final proposal = cascadeProposal(results);
        expect(proposal.kind, 'cloud-best');
        expect(proposal.selected, 'gemini');
        expect(proposal.rationale, contains('ties break in cascade order'));
      },
    );

    test('no cloud candidate at 8/10 selects nothing', () {
      final results = {
        'e2b_local': tally('e2b_local', runOf(5, candidate: 'e2b_local')),
        'e4b_local': tally('e4b_local', runOf(6, candidate: 'e4b_local')),
        'gemini': tally('gemini', runOf(7, candidate: 'gemini')),
        'openai': tally('openai', runOf(6, candidate: 'openai')),
        'anthropic': tally('anthropic', runOf(7, candidate: 'anthropic')),
      };
      final proposal = cascadeProposal(results);
      expect(proposal.kind, 'none-passed');
      expect(proposal.selected, isNull);
    });

    test('a missing E2B run leaves the cascade incomplete', () {
      final proposal = cascadeProposal(const {});
      expect(proposal.kind, 'incomplete');
      expect(proposal.rationale, contains('e2b_local has not been scored'));
    });

    test('an unjudged E2B run leaves the cascade incomplete', () {
      final results = {
        'e2b_local': tally(
          'e2b_local',
          runOf(9, candidate: 'e2b_local', unresolved: 2),
        ),
      };
      expect(cascadeProposal(results).kind, 'incomplete');
    });
  });

  group('cascadeGuardFailures — the Ask-First behind eval-run', () {
    test('re-running e2b_local is always allowed (superseding)', () {
      final existing = {
        'e2b_local': tally('e2b_local', runOf(9, candidate: 'e2b_local')),
      };
      expect(cascadeGuardFailures('e2b_local', existing), isEmpty);
    });

    test('e4b_local refuses while e2b_local has not run', () {
      expect(cascadeGuardFailures('e4b_local', {}), isNotEmpty);
    });

    test('e4b_local refuses when e2b_local passed the bar', () {
      final existing = {
        'e2b_local': tally('e2b_local', runOf(9, candidate: 'e2b_local')),
      };
      final refusals = cascadeGuardFailures('e4b_local', existing);
      expect(refusals, isNotEmpty);
      expect(refusals.first, contains('cascade stops at E2B'));
    });

    test('e4b_local refuses while e2b_local is unjudged', () {
      final existing = {
        'e2b_local': tally(
          'e2b_local',
          runOf(9, candidate: 'e2b_local', unresolved: 1),
        ),
      };
      expect(cascadeGuardFailures('e4b_local', existing), isNotEmpty);
    });

    test('e4b_local is allowed once e2b_local is judged below the bar', () {
      final existing = {
        'e2b_local': tally('e2b_local', runOf(7, candidate: 'e2b_local')),
      };
      expect(cascadeGuardFailures('e4b_local', existing), isEmpty);
    });

    test('cloud refuses while a local passed, or the locals never ran', () {
      final e2bPassed = {
        'e2b_local': tally('e2b_local', runOf(9, candidate: 'e2b_local')),
      };
      expect(cascadeGuardFailures('gemini', e2bPassed), isNotEmpty);
      expect(cascadeGuardFailures('gemini', const {}), isNotEmpty);
    });

    test('cloud is allowed once both locals are judged below the bar', () {
      final existing = {
        'e2b_local': tally('e2b_local', runOf(7, candidate: 'e2b_local')),
        'e4b_local': tally('e4b_local', runOf(7, candidate: 'e4b_local')),
      };
      expect(cascadeGuardFailures('gemini', existing), isEmpty);
      expect(cascadeGuardFailures('openai', existing), isEmpty);
      expect(cascadeGuardFailures('anthropic', existing), isEmpty);
    });
  });

  group('validateManifest', () {
    Map<String, Object?> entry(int i, String type) => {
      'id': 'photo-$i',
      'filename': 'photo-$i.jpg',
      'spaceType': type,
      'groundTruthObjects': ['objeto'],
    };

    String manifestOf(
      int count, {
      Set<String> types = const {'cocina', 'salón', 'baño', 'dormitorio'},
    }) {
      final typesList = types.toList();
      return jsonEncode({
        'photos': [
          for (var i = 0; i < count; i++)
            entry(i, typesList[i % typesList.length]),
        ],
      });
    }

    test('accepts 10 photos over 4 space types with files present', () {
      final check = validateManifest(manifestOf(10), photoExists: (_) => true);
      expect(check.failures, isEmpty);
      expect(check.entries, hasLength(10));
      expect(check.entries.first.groundTruthObjects, ['objeto']);
    });

    test('refuses two ids sharing one photo file', () {
      final source = manifestOf(10);
      final decoded = jsonDecode(source) as Map<String, Object?>;
      (decoded['photos']! as List)[9] = entry(9, 'cocina')
        ..['filename'] = 'photo-0.jpg';
      final check = validateManifest(
        jsonEncode(decoded),
        photoExists: (_) => true,
      );
      expect(
        check.failures,
        contains(contains("duplicate filename 'photo-0.jpg'")),
      );
    });

    test('refuses ids or filenames carrying path separators', () {
      const types = ['cocina', 'salón', 'baño', 'dormitorio'];
      final check = validateManifest(
        jsonEncode({
          'photos': [
            for (var i = 0; i < 9; i++) entry(i, types[i % types.length]),
            {
              'id': '../evil',
              'filename': '../x.jpg',
              'spaceType': 'pasillo',
              'groundTruthObjects': ['o'],
            },
          ],
        }),
        photoExists: (_) => true,
      );
      expect(check.failures, contains(contains("'id' must be a bare name")));
      expect(
        check.failures,
        contains(contains("'filename' must be a bare name")),
      );
    });

    test('refuses on the wrong photo count, listing every failure', () {
      final check = validateManifest(manifestOf(9), photoExists: (_) => true);
      expect(
        check.failures,
        contains(contains('expected exactly 10 photos, found 9')),
      );
    });

    test('refuses on fewer than 4 space types alongside the count failure', () {
      final check = validateManifest(
        manifestOf(9, types: {'cocina', 'salón', 'baño'}),
        photoExists: (_) => true,
      );
      expect(
        check.failures,
        anyElement(contains('expected exactly 10 photos')),
      );
      expect(
        check.failures,
        anyElement(
          contains('expected at least 4 distinct space types, found 3'),
        ),
      );
    });

    test('refuses when a photo file is missing', () {
      final check = validateManifest(
        manifestOf(10),
        photoExists: (f) => !f.contains('photo-3'),
      );
      expect(
        check.failures,
        contains(
          contains("file 'photo-3.jpg' not found under eval/corpus/photos/"),
        ),
      );
    });

    test('refuses on duplicate ids, bad extensions and empty ground truth', () {
      final source = jsonEncode({
        'photos': [
          for (var i = 0; i < 8; i++) entry(i, 'cocina'),
          {
            'id': 'photo-0',
            'filename': 'a.gif',
            'spaceType': 'baño',
            'groundTruthObjects': ['x'],
          },
          {
            'id': 'photo-8',
            'filename': 'b.jpg',
            'spaceType': 'salón',
            'groundTruthObjects': [],
          },
        ],
      });
      final check = validateManifest(source, photoExists: (_) => true);
      expect(check.failures, anyElement(contains("duplicate id 'photo-0'")));
      expect(check.failures, anyElement(contains('extension is not one of')));
      expect(
        check.failures,
        anyElement(contains("'groundTruthObjects' is missing or empty")),
      );
    });

    test('refuses on unparseable JSON with a single clear failure', () {
      final check = validateManifest('not json', photoExists: (_) => true);
      expect(check.failures, hasLength(1));
      expect(check.failures.first, contains('not valid JSON'));
    });

    test('an empty corpus refuses and tells the builder what to supply', () {
      final check = validateManifest(
        '{"photos": []}',
        photoExists: (_) => true,
      );
      expect(check.failures, anyElement(contains('the corpus is empty')));
    });
  });

  group('validateBar', () {
    test('promptTextOf sends the text below the marker, never the header', () {
      const file =
          '# Prompt — foto → plan\n\nHeader prose that must not be sent.\n\n---\n\nEres el asistente.\nSegunda línea.\n';
      expect(promptTextOf(file), startsWith('Eres el asistente'));
      expect(promptTextOf(file), isNot(contains('Header prose')));
      expect(promptTextOf(file), contains('Segunda línea.'));
    });

    test('promptTextOf sends a marker-less file whole', () {
      const file = 'Solo instrucciones.\n';
      expect(promptTextOf(file), 'Solo instrucciones.\n');
    });

    test('comparePhotoIds sorts digit runs numerically', () {
      final ids = ['estancia-10', 'estancia-2', 'estancia-1'];
      ids.sort(comparePhotoIds);
      expect(ids, ['estancia-1', 'estancia-2', 'estancia-10']);
    });
    test('refuses while only the placeholder line is present', () {
      final check = validateBar('# bar\n\nConfirmed: YYYY-MM-DD — <builder>\n');
      expect(check.ok, isFalse);
      expect(check.failures.first, contains('no dated builder confirmation'));
    });

    test('accepts a real dated confirmation line', () {
      final check = validateBar('# bar\n\nConfirmed: 2026-09-03 — Sergio\n');
      expect(check.ok, isTrue);
      expect(check.confirmedOn, '2026-09-03');
    });

    test('refuses an impossible date that matches the shape', () {
      final check = validateBar('Confirmed: 2026-13-45 — x\n');
      expect(check.ok, isFalse);
      expect(check.failures.first, contains('not a real date'));
    });
  });

  group('PhotoVerdict serialization', () {
    test('round-trips through JSON keeping limbs, steps and resolution', () {
      final original = passedPhoto('cocina-01');
      final round = PhotoVerdict.fromJson(
        jsonDecode(jsonEncode(original.toJson())) as Map<String, Object?>,
      );
      expect(round.passed, isTrue);
      expect(round.resolved, isTrue);
      expect(round.steps, hasLength(4));
      expect(round.machine!.allPassed, isTrue);
      expect(round.photoFile, 'cocina-01.jpg');
    });

    test('round-trips a transport failure with its recorded reason', () {
      final original = failedPhoto('salon-02');
      final round = PhotoVerdict.fromJson(
        jsonDecode(jsonEncode(original.toJson())) as Map<String, Object?>,
      );
      expect(round.transportOk, isFalse);
      expect(round.transportReason, contains('HTTP 500'));
      expect(round.passed, isFalse);
      expect(round.human!.autoRecorded, isTrue);
    });
  });

  group('draftOq1Answer', () {
    test('a provisional local selection names the handset deferral', () {
      final results = {
        'e2b_local': tally('e2b_local', runOf(9, candidate: 'e2b_local')),
      };
      final draft = draftOq1Answer(cascadeProposal(results), results);
      expect(draft, contains('e2b_local passed 9/10'));
      expect(draft, contains('Epic 5'));
    });

    test('a cloud-best selection names the killed locals and FR-28', () {
      final results = {
        'e2b_local': tally('e2b_local', runOf(5, candidate: 'e2b_local')),
        'e4b_local': tally('e4b_local', runOf(6, candidate: 'e4b_local')),
        'gemini': tally('gemini', runOf(9, candidate: 'gemini')),
        'openai': tally('openai', runOf(8, candidate: 'openai')),
        'anthropic': tally('anthropic', runOf(7, candidate: 'anthropic')),
      };
      final draft = draftOq1Answer(cascadeProposal(results), results);
      expect(draft, contains('gemini'));
      expect(draft, contains('FR-28'));
    });
  });
}

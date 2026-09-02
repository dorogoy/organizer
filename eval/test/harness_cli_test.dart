@Timeout(Duration(minutes: 3))
library;

import 'dart:convert';
import 'dart:io';

import 'package:eval/verdict.dart';
import 'package:test/test.dart';

/// CLI integration tests over the real `bin/harness.dart` binary: each I/O
/// matrix row gets an end-to-end run against a temp eval root (EVAL_ROOT) and
/// a fake OpenAI-compatible endpoint, asserting exit codes and behavior.
void main() {
  const goodStepsJson =
      '{"steps":['
      '{"text":"Recoge la ropa del sillón","duration_minutes":4},'
      '{"text":"Guarda los platos en la alacena","duration_minutes":5},'
      '{"text":"Limpia la mesa del comedor","duration_minutes":3},'
      '{"text":"Dobla las toallas del baño","duration_minutes":4}]}';

  late HttpServer server;
  var requestCount = 0;
  final capturedBodies = <String>[];
  int Function(int requestNumber) statusFor = (_) => 200;
  String Function(int requestNumber) contentFor = (_) => goodStepsJson;

  setUpAll(() async {
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((request) async {
      requestCount++;
      final number = requestCount;
      capturedBodies.add(await utf8.decoder.bind(request).join());
      final status = statusFor(number);
      if (status != 200) {
        request.response.statusCode = status;
        request.response.headers.contentType = ContentType.json;
        request.response.write(
          jsonEncode({
            'error': {'message': 'image content parts are not supported'},
          }),
        );
        await request.response.close();
        return;
      }
      request.response.statusCode = 200;
      request.response.headers.contentType = ContentType.json;
      request.response.write(
        jsonEncode({
          'choices': [
            {
              'message': {'content': contentFor(number)},
            },
          ],
        }),
      );
      await request.response.close();
    });
  });

  tearDownAll(() async {
    await server.close(force: true);
  });

  setUp(() {
    requestCount = 0;
    capturedBodies.clear();
    statusFor = (_) => 200;
    contentFor = (_) => goodStepsJson;
  });

  final packageDir = Directory.current.path;

  late Directory root;
  late Directory photos;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('eval-harness-test-');
    photos = Directory('${root.path}/corpus/photos');
    await photos.create(recursive: true);
    await File('${root.path}/prompt.md')
        .writeAsString(File('$packageDir/prompt.md').readAsStringSync());
    await File('${root.path}/schema.json')
        .writeAsString(File('$packageDir/schema.json').readAsStringSync());
    await File('${root.path}/pubspec.yaml').writeAsString('name: eval\n');
    await writeBar(root, confirmed: true);
    await writeManifest(root, photoCount: 10);
    for (var i = 1; i <= 10; i++) {
      await File('${photos.path}/p${i.toString().padLeft(2, '0')}.jpg')
          .writeAsBytes([1, 2, 3]);
    }
  });

  tearDown(() async {
    await root.delete(recursive: true);
  });

  Future<ProcessResult> runHarness(
    List<String> args, {
    Map<String, String>? environment,
    String? stdin,
  }) async {
    if (stdin == null) {
      return Process.run(
        'dart',
        ['run', 'bin/harness.dart', ...args],
        workingDirectory: packageDir,
        environment: {
          ...Platform.environment,
          'EVAL_ROOT': root.path,
          ...?environment,
        },
        stdoutEncoding: utf8,
        stderrEncoding: utf8,
      );
    }
    final process = await Process.start(
      'dart',
      ['run', 'bin/harness.dart', ...args],
      workingDirectory: packageDir,
      environment: {
        ...Platform.environment,
        'EVAL_ROOT': root.path,
        ...?environment,
      },
    );
    process.stdin.write(stdin);
    await process.stdin.close();
    final out = await process.stdout.transform(utf8.decoder).join();
    final err = await process.stderr.transform(utf8.decoder).join();
    final code = await process.exitCode;
    return ProcessResult(process.pid, code, out, err);
  }

  test('probe — an image-capable endpoint answers in-schema and the local route opens (exit 0)', () async {
    final result = await runHarness([
      'probe',
      '--base-url',
      'http://127.0.0.1:${server.port}/v1',
    ]);
    expect(result.exitCode, 0, reason: result.stderr as String);
    expect(result.stdout, contains('local route is open'));
    expect(requestCount, 1);
  });

  test('probe — an endpoint that rejects images halts with the invalid-route message (exit 2)', () async {
    statusFor = (_) => 400;
    final result = await runHarness([
      'probe',
      '--base-url',
      'http://127.0.0.1:${server.port}/v1',
    ]);
    expect(result.exitCode, 2);
    expect(result.stderr, contains('desktop local route is invalid'));
  });

  test('run — an unconfirmed bar refuses to score (exit 2)', () async {
    await writeBar(root, confirmed: false);
    final result = await runHarness([
      'run',
      '--candidate',
      'e2b_local',
      '--base-url',
      'http://127.0.0.1:${server.port}/v1',
    ]);
    expect(result.exitCode, 2);
    expect(result.stderr, contains('refusing to score'));
    expect(result.stderr, contains('confirmation'));
    expect(requestCount, 0);
  });

  test(
    'run — an invalid manifest refuses, listing every failure (exit 2)',
    () async {
      await writeManifest(root, photoCount: 9);
      final result = await runHarness([
        'run',
        '--candidate',
        'e2b_local',
        '--base-url',
        'http://127.0.0.1:${server.port}/v1',
      ]);
      expect(result.exitCode, 2);
      expect(result.stderr, contains('expected exactly 10 photos, found 9'));
      expect(requestCount, 0);
    },
  );

  test('run — the OpenRouter route resolves the shared key and scores the slug (exit 0)', () async {
    final result = await runHarness(
      [
        'run',
        '--candidate',
        'gemini',
        '--via',
        'openrouter',
        '--force',
        '--base-url',
        'http://127.0.0.1:${server.port}/v1',
      ],
      environment: {
        ...Platform.environment,
        'EVAL_OPENROUTER_API_KEY': 'or-test-key',
        'EVAL_GEMINI_API_KEY': '',
      },
    );
    expect(result.exitCode, 0, reason: result.stderr as String);
    expect(result.stdout, contains('via OpenRouter'));
    expect(result.stdout, contains('google/gemini-3.5-flash-lite'));
    expect(requestCount, 10);
    final runMeta = jsonDecode(
      File('${root.path}/results/runs/gemini.json').readAsStringSync(),
    ) as Map<String, Object?>;
    final lastRun = (runMeta['runs']! as List).last as Map<String, Object?>;
    expect(lastRun['via'], 'openrouter');
    expect(lastRun['model'], 'google/gemini-3.5-flash-lite');
  });

  test(
    'run — the OpenRouter route without the shared key refuses (exit 2)',
    () async {
      final result = await runHarness(
        [
          'run',
          '--candidate',
          'openai',
          '--via',
          'openrouter',
          '--force',
          '--base-url',
          'http://127.0.0.1:${server.port}/v1',
        ],
        environment: {...Platform.environment, 'EVAL_OPENROUTER_API_KEY': ''},
      );
      expect(result.exitCode, 2);
      expect(result.stderr, contains('EVAL_OPENROUTER_API_KEY'));
      expect(requestCount, 0);
    },
  );

  test('run — one request per photo; transport and parse failures are recorded and the corpus continues (exit 0)', () async {
    statusFor = (number) => number == 3 ? 500 : 200;
    contentFor = (number) =>
        number == 5 ? '```json\n$goodStepsJson\n```' : goodStepsJson;
    final result = await runHarness([
      'run',
      '--candidate',
      'e2b_local',
      '--base-url',
      'http://127.0.0.1:${server.port}/v1',
    ]);
    expect(result.exitCode, 0, reason: result.stderr as String);
    // No retry anywhere: ten photos, ten requests — even the two failures.
    expect(requestCount, 10);

    final verdictDir = Directory('${root.path}/results/verdicts/e2b_local');
    final files = verdictDir.listSync().whereType<File>().toList();
    expect(files.length, 10);

    final p03 = readVerdict(verdictDir, 'p03');
    expect(p03['transportOk'], false);
    expect(p03['transportReason'] as String, contains('HTTP 500'));

    final p05 = readVerdict(verdictDir, 'p05');
    expect(p05['transportOk'], true);
    // Fenced under the 2026-09-02 amendment: parsed once the single fence was
    // stripped, and the strip is recorded, not buried.
    expect((p05['machine'] as Map)['fenceStripped'], true);
    expect((p05['machine'] as Map)['parse'] as Map, containsPair('ok', true));

    final p01 = readVerdict(verdictDir, 'p01');
    final machine = p01['machine']! as Map;
    expect((machine['parse'] as Map)['ok'], true);
    expect((machine['durations'] as Map)['ok'], true);
    expect((machine['steps'] as Map)['ok'], true);
    expect((p01['steps'] as List).length, 4);
  });

  test('run — the cascade Ask-First refuses e4b_local after a passing e2b run (exit 2)', () async {
    await seedPassingRun(root, 'e2b_local');
    final result = await runHarness([
      'run',
      '--candidate',
      'e4b_local',
      '--base-url',
      'http://127.0.0.1:${server.port}/v1',
    ]);
    expect(result.exitCode, 2);
    expect(result.stderr, contains('cascade stops at E2B'));
    expect(requestCount, 0);
  });

  test('report — writes report.md + scores.json with the selection proposal (exit 0)', () async {
    await seedPassingRun(root, 'e2b_local');
    final result = await runHarness(['report']);
    expect(result.exitCode, 0, reason: result.stderr as String);

    final report = File('${root.path}/results/report.md');
    expect(report.existsSync(), isTrue);
    final text = report.readAsStringSync();
    expect(text, contains('local-provisional'));
    expect(text, contains('e2b_local'));
    expect(text, contains('OQ-1 answer'));

    final scores = jsonDecode(
      File('${root.path}/results/scores.json').readAsStringSync(),
    ) as Map<String, Object?>;
    expect((scores['cascade']! as Map)['selected'], 'e2b_local');
  });

  test('judge — machine-failed photos auto-record their human limbs without a prompt; the rest are asked (exit 0)', () async {
    await seedPassingRun(root, 'e2b_local', judged: false);
    // One machine-failed photo: transport ok, schema-invalid steps → the
    // judge must auto-fail its human limbs and never prompt for it.
    await File('${root.path}/results/verdicts/e2b_local/p03.json')
        .writeAsString(
          jsonEncode(
            PhotoVerdict(
              candidate: 'e2b_local',
              photoId: 'p03',
              photoFile: 'p03.jpg',
              spaceType: 'cocina',
              model: 'test-model',
              timestamp: '2026-09-02T00:00:00',
              transportOk: true,
              machine: MachineVerdict.notEvaluated(
                'schema check failed: steps[1] is not an object',
              ),
              steps: null,
              human: null,
            ).toJson(),
          ),
        );
    // Nine prompted photos (all but p03), each answered 4✗ 5✓.
    final result = await runHarness([
      'judge',
      '--candidate',
      'e2b_local',
    ], stdin: 'n\ns\n' * 9);
    expect(result.exitCode, 0, reason: result.stderr as String);
    expect(result.stdout, contains('no parsed steps (machine failure)'));
    final p03 = readVerdict(
      Directory('${root.path}/results/verdicts/e2b_local'),
      'p03',
    );
    final human = p03['human']! as Map<String, Object?>;
    expect(human['autoRecorded'], true);
    expect(human['realActions'], false);
    expect(human['workableOrder'], false);
    expect(result.stdout, contains('score: 0/10'));
  });

  test('report — a transport-failed raw record (no responseBody) contributes no cost and crashes nothing (exit 0)', () async {
    await seedPassingRun(root, 'e2b_local');
    final rawDir = Directory('${root.path}/results/raw/e2b_local');
    await rawDir.create(recursive: true);
    await File('${rawDir.path}/p01.json').writeAsString(
      jsonEncode({
        'photoId': 'p01',
        'ok': false,
        'transportReason': 'HTTP 500: upstream boom',
      }),
    );
    await File('${rawDir.path}/p02.json').writeAsString(
      jsonEncode({
        'photoId': 'p02',
        'responseBody': jsonEncode({
          'choices': [
            {
              'message': {'content': '{}'},
            },
          ],
          'usage': {
            'cost_details': {'upstream_inference_cost': 0.00070},
          },
        }),
      }),
    );
    final result = await runHarness(['report']);
    expect(result.exitCode, 0, reason: result.stderr as String);
    final text = File('${root.path}/results/report.md').readAsStringSync();
    expect(text, contains('0.00070'));
    final scores = jsonDecode(
      File('${root.path}/results/scores.json').readAsStringSync(),
    ) as Map<String, Object?>;
    final candidate =
        (scores['candidates']! as Map)['e2b_local']! as Map<String, Object?>;
    expect(candidate['costEvidenceUsd'], 0.00070);
  });

  test(
    'report — refuses when the manifest is no longer valid (exit 2)',
    () async {
      await seedPassingRun(root, 'e2b_local');
      File('${root.path}/corpus/photos/p01.jpg').deleteSync();
      final result = await runHarness(['report']);
      expect(result.exitCode, 2);
      expect(result.stderr, contains('manifest no longer valid'));
    },
  );

  test('run — a re-run of an already-scored candidate is an Ask-First refusal without --force (exit 2)', () async {
    await seedPassingRun(root, 'e2b_local');
    final result = await runHarness([
      'run',
      '--candidate',
      'e2b_local',
      '--base-url',
      'http://127.0.0.1:${server.port}/v1',
    ]);
    expect(result.exitCode, 2);
    expect(result.stderr, contains('already scored'));
    expect(result.stderr, contains('Ask-First'));
    expect(requestCount, 0);
  });

  test(
    'run — the sent prompt is the text below the marker, never the file header',
    () async {
      capturedBodies.clear();
      await runHarness([
        'run',
        '--candidate',
        'e2b_local',
        '--base-url',
        'http://127.0.0.1:${server.port}/v1',
      ]);
      final body = jsonDecode(capturedBodies.first) as Map<String, Object?>;
      final parts =
          ((body['messages'] as List).first as Map)['content'] as List;
      final text = (parts.first as Map)['text'] as String;
      expect(text, startsWith('Eres el asistente'));
      expect(text, isNot(contains('byte-identical')));
    },
  );

  test(
    'run — the local pair refuses the OpenRouter route cleanly (exit 2)',
    () async {
      final result = await runHarness([
        'run',
        '--candidate',
        'e2b_local',
        '--via',
        'openrouter',
      ]);
      expect(result.exitCode, 2);
      expect(result.stderr, contains('does not route through OpenRouter'));
      expect(requestCount, 0);
    },
  );

  test('report — the cost section shows builder-supplied and evidence-summed figures', () async {
    await seedPassingRun(root, 'e2b_local');
    // One raw response carrying an upstream cost — the evidence column
    // sums these; a second one without a cost contributes nothing.
    final rawDir = Directory('${root.path}/results/raw/e2b_local');
    await rawDir.create(recursive: true);
    Future<void> writeRaw(String photoId, double? cost) =>
        File('${rawDir.path}/$photoId.json').writeAsString(
          jsonEncode({
            'photoId': photoId,
            'responseBody': jsonEncode({
              'choices': [
                {
                  'message': {'content': '{}'},
                },
              ],
              'usage': {
                if (cost != null)
                  'cost_details': {'upstream_inference_cost': cost},
              },
            }),
          }),
        );
    await writeRaw('p01', 0.00070);
    await writeRaw('p02', null);
    await File('${root.path}/results/costs.json').writeAsString(
      jsonEncode({
        'source': 'test',
        'candidates': {
          'e2b_local': {'usd': 0.00757},
        },
      }),
    );

    final result = await runHarness(['report']);
    expect(result.exitCode, 0, reason: result.stderr as String);
    final text = File('${root.path}/results/report.md').readAsStringSync();
    expect(text, contains('## Cost (whole 10-photo run per candidate)'));
    expect(text, contains('0.00757'));
    expect(text, contains('0.00070'));

    final scores = jsonDecode(
      File('${root.path}/results/scores.json').readAsStringSync(),
    ) as Map<String, Object?>;
    final candidate =
        (scores['candidates']! as Map)['e2b_local']! as Map<String, Object?>;
    expect(candidate['costBuilderUsd'], 0.00757);
    expect(candidate['costEvidenceUsd'], 0.00070);
  });

  test('report — refuses when nothing has been scored (exit 2)', () async {
    final result = await runHarness(['report']);
    expect(result.exitCode, 2);
    expect(result.stderr, contains('nothing to report'));
  });
}

Map<String, Object?> readVerdict(Directory dir, String photoId) =>
    jsonDecode(File('${dir.path}/$photoId.json').readAsStringSync())
        as Map<String, Object?>;

Future<void> writeBar(Directory root, {required bool confirmed}) async {
  final source = File('PASS-BAR.md').readAsStringSync();
  // The committed bar carries a real dated confirmation; the unconfirmed
  // variant rewrites it back to the placeholder the harness must refuse.
  await File('${root.path}/PASS-BAR.md').writeAsString(
    confirmed
        ? source
        : source.replaceFirst(
            RegExp(r'^Confirmed: \d{4}-\d{2}-\d{2}.*$', multiLine: true),
            'Confirmed: YYYY-MM-DD — the builder',
          ),
  );
}

Future<void> writeManifest(Directory root, {required int photoCount}) async {
  const types = ['cocina', 'salón', 'dormitorio', 'escritorio'];
  final photos = List.generate(photoCount, (index) {
    final id = 'p${(index + 1).toString().padLeft(2, '0')}';
    return {
      'id': id,
      'filename': '$id.jpg',
      'spaceType': types[index % types.length],
      'groundTruthObjects': ['platos', 'ropa'],
    };
  });
  await File('${root.path}/corpus/manifest.json')
      .writeAsString(jsonEncode({'photos': photos}));
}

/// Seeds a complete, bar-passing run for [candidate] — exactly what
/// `eval-run` + `eval-judge` would have left behind. Pass `judged: false`
/// to leave the human limbs pending (what `eval-run` alone leaves).
Future<void> seedPassingRun(
  Directory root,
  String candidate, {
  bool judged = true,
}) async {
  final verdictDir = Directory('${root.path}/results/verdicts/$candidate');
  await verdictDir.create(recursive: true);
  await Directory('${root.path}/results/runs').create(recursive: true);
  await File('${root.path}/results/runs/$candidate.json').writeAsString(
    jsonEncode({
      'runs': [
        {'timestamp': '2026-09-02T00:00:00', 'model': 'test-model'},
      ],
    }),
  );
  const types = ['cocina', 'salón', 'dormitorio', 'escritorio'];
  for (var index = 0; index < 10; index++) {
    final id = 'p${(index + 1).toString().padLeft(2, '0')}';
    final verdict = PhotoVerdict(
      candidate: candidate,
      photoId: id,
      photoFile: '$id.jpg',
      spaceType: types[index % types.length],
      model: 'test-model',
      timestamp: '2026-09-02T00:00:00',
      transportOk: true,
      machine: const MachineVerdict(
        parse: LimbResult.passed(),
        durations: LimbResult.passed(),
        steps: LimbResult.passed(),
      ),
      steps: const [
        SliceStep(text: 'Recoge la ropa', durationMinutes: 4),
        SliceStep(text: 'Guarda los platos', durationMinutes: 5),
        SliceStep(text: 'Limpia la mesa', durationMinutes: 3),
        SliceStep(text: 'Dobla las toallas', durationMinutes: 4),
      ],
      human: judged
          ? const HumanVerdict(realActions: true, workableOrder: true)
          : null,
    );
    await File('${verdictDir.path}/$id.json')
        .writeAsString(jsonEncode(verdict.toJson()));
  }
}

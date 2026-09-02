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
  int Function(int requestNumber) statusFor = (_) => 200;
  String Function(int requestNumber) contentFor = (_) => goodStepsJson;

  setUpAll(() async {
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((request) async {
      requestCount++;
      final number = requestCount;
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
  }) async {
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
    expect((p05['machine'] as Map)['parse'] as Map, containsPair('ok', false));

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

/// Seeds a complete, fully-judged, bar-passing run for [candidate] — exactly
/// what `eval-run` + `eval-judge` would have left behind.
Future<void> seedPassingRun(Directory root, String candidate) async {
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
      human: const HumanVerdict(realActions: true, workableOrder: true),
    );
    await File('${verdictDir.path}/$id.json')
        .writeAsString(jsonEncode(verdict.toJson()));
  }
}

/// The story 4.1 harness CLI: `probe`, `run --candidate <id>`,
/// `judge --candidate <id>`, `report`.
///
/// Run through the Makefile targets (`make eval-probe`, `eval-run`,
/// `eval-judge`, `eval-report`) from inside `devbox shell`, or directly from
/// `eval/` with `dart run bin/harness.dart …`. Exit codes: 0 success; 2
/// refusal (unconfirmed bar, invalid manifest, cascade Ask-First, missing
/// key, probe failure — anything the spec says HALTs).
library;

import 'dart:convert';
import 'dart:io';

import 'package:args/args.dart';
import 'package:crypto/crypto.dart' as crypto;

import 'package:eval/candidates.dart';
import 'package:eval/verdict.dart';

const usageHeader =
    'eval harness — subcommands: probe, run --candidate <id>, judge --candidate <id>, report';

Future<void> main(List<String> arguments) async {
  if (arguments.isEmpty) {
    stderr.writeln(usageHeader);
    exit(2);
  }
  switch (arguments.first) {
    case 'probe':
      await _probe(arguments.skip(1).toList());
    case 'run':
      await _run(arguments.skip(1).toList());
    case 'judge':
      await _judge(arguments.skip(1).toList());
    case 'report':
      await _report(arguments.skip(1).toList());
    case '--help' || '-h':
      stdout.writeln(usageHeader);
      stdout.writeln(
        'candidates: ${candidateSpecs.map((s) => s.id).join(', ')}',
      );
      exit(0);
    default:
      stderr.writeln('unknown subcommand "${arguments.first}" — $usageHeader');
      exit(2);
  }
}

// ---------------------------------------------------------------------------
// Paths and shared loaders
// ---------------------------------------------------------------------------

final class Paths {
  Paths(this.root);

  factory Paths.resolve() {
    // EVAL_ROOT points the harness at another package-shaped root — it exists
    // for the CLI integration tests, which run the real binary against a temp
    // corpus and a fake endpoint.
    final override = Platform.environment['EVAL_ROOT'];
    if (override != null && override.isNotEmpty) {
      final root = Directory(override);
      final shaped =
          File('${root.path}/pubspec.yaml').existsSync() &&
          File('${root.path}/prompt.md').existsSync();
      if (!shaped) {
        stderr.writeln(
          'EVAL_ROOT does not point at an eval root (pubspec.yaml + prompt.md expected)',
        );
        exit(2);
      }
      return Paths(root);
    }
    final cwd = Directory.current;
    final here =
        File('${cwd.path}/pubspec.yaml').existsSync() &&
        File('${cwd.path}/prompt.md').existsSync();
    if (here) {
      return Paths(cwd);
    }
    final nested = Directory('${cwd.path}/eval');
    if (File('${nested.path}/pubspec.yaml').existsSync()) {
      return Paths(nested);
    }
    stderr.writeln('run the harness from eval/ or the repo root');
    exit(2);
  }

  final Directory root;

  File get prompt => File('${root.path}/prompt.md');
  File get schema => File('${root.path}/schema.json');
  File get bar => File('${root.path}/PASS-BAR.md');
  File get manifest => File('${root.path}/corpus/manifest.json');
  Directory get photos => Directory('${root.path}/corpus/photos');
  Directory get results => Directory('${root.path}/results');
  Directory get verdicts => Directory('${root.path}/results/verdicts');
  Directory get raw => Directory('${root.path}/results/raw');
  Directory get runs => Directory('${root.path}/results/runs');

  Directory verdictDirFor(String candidate) =>
      Directory('${verdicts.path}/$candidate');
  Directory rawDirFor(String candidate) => Directory('${raw.path}/$candidate');
  File runMetaFor(String candidate) => File('${runs.path}/$candidate.json');
}

String? _mimeTypeOf(String filename) {
  final lower = filename.toLowerCase();
  if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) return 'image/jpeg';
  if (lower.endsWith('.png')) return 'image/png';
  return null;
}

Never _refuse(List<String> messages) {
  for (final message in messages) {
    stderr.writeln(message);
  }
  exit(2);
}

(BarCheck, ManifestCheck) _loadGates(Paths paths) {
  if (!paths.bar.existsSync()) {
    _refuse(['refusing — eval/PASS-BAR.md not found']);
  }
  final bar = validateBar(paths.bar.readAsStringSync());
  if (!bar.ok) {
    _refuse(['refusing to score — ${bar.failures.join('; ')}']);
  }
  if (!paths.manifest.existsSync()) {
    _refuse(['refusing — eval/corpus/manifest.json not found']);
  }
  final manifest = validateManifest(
    paths.manifest.readAsStringSync(),
    photoExists: (filename) =>
        File('${paths.photos.path}/$filename').existsSync(),
  );
  if (!manifest.ok) {
    _refuse([
      'refusing — invalid corpus manifest:',
      ...manifest.failures.map((f) => '  - $f'),
    ]);
  }
  return (bar, manifest);
}

Map<String, CandidateTally> _loadTallies(Paths paths) {
  final tallies = <String, CandidateTally>{};
  if (!paths.verdicts.existsSync()) {
    return tallies;
  }
  for (final dir in paths.verdicts.listSync().whereType<Directory>()) {
    final candidate = dir.uri.pathSegments.where((s) => s.isNotEmpty).last;
    final verdicts = _loadVerdicts(dir);
    if (verdicts.isNotEmpty) {
      tallies[candidate] = tally(candidate, verdicts);
    }
  }
  return tallies;
}

List<PhotoVerdict> _loadVerdicts(Directory dir) {
  final verdicts = <PhotoVerdict>[];
  for (final file in dir.listSync().whereType<File>()) {
    if (!file.path.endsWith('.json')) continue;
    try {
      verdicts.add(
        PhotoVerdict.fromJson(
          jsonDecode(file.readAsStringSync()) as Map<String, Object?>,
        ),
      );
    } on FormatException {
      stderr.writeln('warning: skipping unparseable verdict file ${file.path}');
    }
  }
  verdicts.sort((a, b) => comparePhotoIds(a.photoId, b.photoId));
  return verdicts;
}

ArgResults _parseOrRefuse(ArgParser parser, List<String> args) {
  try {
    return parser.parse(args);
  } on ArgParserException catch (e) {
    stderr.writeln(e.message);
    stderr.writeln(parser.usage);
    exit(2);
  }
}

const _encoder = JsonEncoder.withIndent('  ');

// ---------------------------------------------------------------------------
// probe
// ---------------------------------------------------------------------------

Future<void> _probe(List<String> args) async {
  final parser = ArgParser()
    ..addOption(
      'base-url',
      help: 'Lemonade base URL (default $lemonadeDefaultBaseUrl)',
    )
    ..addOption(
      'model',
      help:
          "model id to probe (default the e2b_local default, '${candidateSpecs.first.defaultModel}')",
    );
  final parsed = _parseOrRefuse(parser, args);
  final paths = Paths.resolve();
  final (_, manifest) = _loadGates(paths);
  final entry = manifest.entries.first;
  final candidate = buildCandidate(
    id: 'e2b_local',
    baseUrl: parsed['base-url'] as String?,
    model: parsed['model'] as String?,
  );
  final photo = File('${paths.photos.path}/${entry.filename}');
  stdout.writeln(
    'probing ${candidate.model} at ${parsed['base-url'] ?? lemonadeDefaultBaseUrl} with one photo (${entry.id})…',
  );
  final CandidateReply reply;
  try {
    reply = await candidate.requestSlicePlan(
      prompt: promptTextOf(paths.prompt.readAsStringSync()),
      schemaJson: paths.schema.readAsStringSync(),
      imageBytes: photo.readAsBytesSync(),
      imageMimeType: _mimeTypeOf(entry.filename)!,
    );
  } on HarnessTransportException catch (e) {
    _refuse([
      'probe failed — ${e.reason}',
      'HALT: if the endpoint rejects image input, the desktop local route is invalid — nothing else is planned around it.',
    ]);
  }
  final evaluation = evaluateModelOutput(reply.output);
  if (evaluation.verdict.allPassed) {
    stdout.writeln(
      'probe ok — one photo answered in-schema; the local route is open.',
    );
    exit(0);
  }
  _refuse([
    'probe failed — the response did not pass every machine limb on the first attempt: '
        '${_failedLimbsOf(evaluation.verdict)}',
  ]);
}

/// Names every failed machine limb with its reason — a probe failure is not
/// always the parse limb, and `null` is not a reason.
String _failedLimbsOf(MachineVerdict verdict) {
  final failed = <String>[
    if (!verdict.parse.ok)
      'parse — ${verdict.parse.reason ?? 'failed'}'
    else ...[
      if (!verdict.durations.ok)
        'durations — ${verdict.durations.reason ?? 'failed'}',
      if (!verdict.steps.ok) 'steps — ${verdict.steps.reason ?? 'failed'}',
    ],
  ];
  return failed.join('; ');
}

// ---------------------------------------------------------------------------
// run
// ---------------------------------------------------------------------------

Future<void> _run(List<String> args) async {
  final parser = ArgParser()
    ..addOption(
      'candidate',
      mandatory: true,
      allowed: candidateSpecs.map((s) => s.id).toList(),
      help: 'candidate id',
    )
    ..addOption(
      'base-url',
      help:
          'Lemonade base URL (local candidates only; default $lemonadeDefaultBaseUrl)',
    )
    ..addOption('model', help: "override the candidate's default model id")
    ..addOption(
      'via',
      allowed: const ['native', 'openrouter'],
      defaultsTo: 'native',
      help:
          'serving route for cloud candidates: native per-provider adapters, or '
          "one shared $openRouterEnvKey at OpenRouter under each candidate's slug",
    )
    ..addFlag(
      'force',
      negatable: false,
      help: 'override a cascade Ask-First refusal (cloud scoring when a local passed, or out-of-order running)',
    );
  final parsed = _parseOrRefuse(parser, args);
  final candidateId = parsed['candidate'] as String;
  final spec = specFor(candidateId);
  final via = parsed['via'] as String;
  final baseUrl = parsed['base-url'] as String?;
  if (baseUrl != null && !spec.local && via != 'openrouter') {
    _refuse(['refusing — --base-url applies to the local candidates only']);
  }
  if (spec.local && via != 'native') {
    _refuse([
      'refusing — the local pair serves from Lemonade and does not route through OpenRouter',
    ]);
  }

  final paths = Paths.resolve();
  final (bar, manifest) = _loadGates(paths);
  final entries = manifest.entries;

  final existing = _loadTallies(paths);
  if (parsed['force'] != true) {
    final refusals = [...cascadeGuardFailures(candidateId, existing)];
    if (existing.containsKey(candidateId)) {
      refusals.add(
        '$candidateId is already scored — a re-run is whole-candidate, superseding the earlier run and noted in the report (Ask-First; use --force to record an explicit override)',
      );
    }
    if (refusals.isNotEmpty) {
      _refuse(['refusing to score — ${refusals.join('; ')}']);
    }
  }

  final envKey = via == 'openrouter' ? openRouterEnvKey : spec.envKey;
  String? apiKey;
  if (envKey != null) {
    apiKey = Platform.environment[envKey];
    if (apiKey == null || apiKey.isEmpty) {
      _refuse([
        'refusing to score — $envKey is not set (keys come from the environment only)',
      ]);
    }
  }

  final candidate = buildCandidate(
    id: candidateId,
    baseUrl: baseUrl,
    model: parsed['model'] as String?,
    apiKey: apiKey,
    via: via,
  );
  final rawDir = paths.rawDirFor(candidateId);
  final verdictDir = paths.verdictDirFor(candidateId);
  await rawDir.create(recursive: true);
  await verdictDir.create(recursive: true);

  stdout.writeln(
    'scoring $candidateId (model ${candidate.model}'
    '${via == 'openrouter' ? ', via OpenRouter' : ''}) over ${entries.length} photos — '
    'bar confirmed ${bar.confirmedOn}',
  );

  final verdicts = <PhotoVerdict>[];
  for (final entry in entries) {
    final verdict = await _scoreOne(
      paths: paths,
      candidate: candidate,
      rawDir: rawDir,
      entry: entry,
    );
    verdicts.add(verdict);
    await File('${verdictDir.path}/${entry.id}.json')
        .writeAsString(_encoder.convert(verdict.toJson()));
    stdout.writeln('  ${entry.id}: ${_describe(verdict)}');
  }

  await _appendRunMeta(
    paths,
    candidateId,
    candidate.model,
    via: via,
    promptSha256: _sha256Of(paths.prompt.readAsStringSync()),
    schemaSha256: _sha256Of(paths.schema.readAsStringSync()),
  );

  final t = tally(candidateId, verdicts);
  stdout.writeln(
    'machine tally: ${t.machinePassed}/${t.photos} photos pass the three machine limbs — '
    'human limbs pending: make eval-judge CANDIDATE=$candidateId',
  );
  final proposal = cascadeProposal({...existing, candidateId: t});
  stdout.writeln('cascade: ${proposal.rationale}');
  if (verdicts.isNotEmpty && verdicts.every((v) => !v.transportOk)) {
    stdout.writeln(
      'warning: every photo failed at transport — the run may be infrastructure-voided; '
      'a re-run is always whole-candidate (superseding, noted in the report).',
    );
  }
  exit(0);
}

/// Scores one photo: exactly one request, the raw response recorded under
/// gitignored `eval/results/raw/`, and the verdict with its machine limbs and
/// failure reasons. A transport error fails the photo and the corpus
/// continues — never retried.
Future<PhotoVerdict> _scoreOne({
  required Paths paths,
  required Candidate candidate,
  required Directory rawDir,
  required CorpusEntry entry,
}) async {
  final photo = File('${paths.photos.path}/${entry.filename}');
  final timestamp = DateTime.now().toIso8601String();
  try {
    final reply = await candidate.requestSlicePlan(
      prompt: promptTextOf(paths.prompt.readAsStringSync()),
      schemaJson: paths.schema.readAsStringSync(),
      imageBytes: photo.readAsBytesSync(),
      imageMimeType: _mimeTypeOf(entry.filename)!,
    );
    await File('${rawDir.path}/${entry.id}.json').writeAsString(
      _encoder.convert({
        'candidate': candidate.id,
        'photoId': entry.id,
        'model': candidate.model,
        'timestamp': timestamp,
        'ok': true,
        'endpoint': reply.endpoint.toString(),
        'responseBody': reply.rawBody,
      }),
    );
    final evaluation = evaluateModelOutput(reply.output);
    return PhotoVerdict(
      candidate: candidate.id,
      photoId: entry.id,
      photoFile: entry.filename,
      spaceType: entry.spaceType,
      model: candidate.model,
      timestamp: timestamp,
      transportOk: true,
      machine: evaluation.verdict,
      steps: evaluation.steps,
    );
  } on HarnessTransportException catch (e) {
    await File('${rawDir.path}/${entry.id}.json').writeAsString(
      _encoder.convert({
        'candidate': candidate.id,
        'photoId': entry.id,
        'model': candidate.model,
        'timestamp': timestamp,
        'ok': false,
        'reason': e.reason,
      }),
    );
    return PhotoVerdict(
      candidate: candidate.id,
      photoId: entry.id,
      photoFile: entry.filename,
      spaceType: entry.spaceType,
      model: candidate.model,
      timestamp: timestamp,
      transportOk: false,
      transportReason: e.reason,
    );
  }
}

/// Collapse a recorded reason onto one line so it cannot break a markdown
/// table row (first-attempt parse reasons quote the offending text).
String _oneLine(String reason) =>
    reason.replaceAll('\n', ' ⏎ ').replaceAll('\r', '');

String _describe(PhotoVerdict verdict) {
  if (!verdict.transportOk) {
    return 'transport failure — ${verdict.transportReason}';
  }
  final machine = verdict.machine!;
  if (!machine.parse.ok) {
    return 'parse failure — ${machine.parse.reason}';
  }
  if (!machine.allPassed) {
    return [
      if (!machine.durations.ok)
        'durations failure — ${machine.durations.reason}',
      if (!machine.steps.ok) 'step-count failure — ${machine.steps.reason}',
    ].join('; ');
  }
  return 'machine limbs ok (${verdict.steps!.length} steps) — human limbs pending';
}

/// Builder-supplied per-candidate totals from the committed
/// `results/costs.json` — the raw responses those derive from are
/// gitignored, so this file is what preserves the figures in-repo.
Map<String, double> _loadBuilderCosts(Paths paths) {
  final file = File('${paths.results.path}/costs.json');
  if (!file.existsSync()) return const {};
  try {
    final decoded = jsonDecode(file.readAsStringSync()) as Map<String, Object?>;
    final candidates = decoded['candidates'];
    if (candidates is! Map) return const {};
    return {
      for (final entry in candidates.entries)
        if (entry.value is Map && (entry.value as Map)['usd'] is num)
          entry.key as String: ((entry.value as Map)['usd'] as num).toDouble(),
    };
  } on FormatException {
    return const {};
  }
}

/// Sums `usage.cost_details.upstream_inference_cost` over one candidate's
/// recorded raw responses — the evidence behind the dashboard figure. Null
/// when no raw response carries a cost.
double? _evidenceCostOf(Directory rawDir) {
  if (!rawDir.existsSync()) return null;
  var total = 0.0;
  var any = false;
  for (final file in rawDir.listSync().whereType<File>()) {
    if (!file.path.endsWith('.json')) continue;
    try {
      final raw = jsonDecode(file.readAsStringSync()) as Map<String, Object?>;
      final bodyText = raw['responseBody'];
      if (bodyText is! String) {
        // A transport-failed photo records no response body — it carries no
        // cost, and that is not an error.
        continue;
      }
      final body = jsonDecode(bodyText) as Map<String, Object?>;
      final cost =
          ((body['usage'] as Map<String, Object?>?)?['cost_details']
              as Map<String, Object?>?)?['upstream_inference_cost'];
      if (cost is num) {
        total += cost.toDouble();
        any = true;
      }
    } on FormatException {
      // Unparseable raw evidence contributes nothing to the sum.
    }
  }
  return any ? total : null;
}

Future<void> _appendRunMeta(
  Paths paths,
  String candidateId,
  String model, {
  String via = 'native',
  String? promptSha256,
  String? schemaSha256,
}) async {
  await paths.runs.create(recursive: true);
  final file = paths.runMetaFor(candidateId);
  var runs = <Object?>[];
  if (file.existsSync()) {
    try {
      runs =
          (jsonDecode(file.readAsStringSync()) as Map<String, Object?>)['runs']!
              as List<Object?>;
    } on FormatException {
      runs = [];
    }
  }
  runs = [
    ...runs,
    {
      'timestamp': DateTime.now().toIso8601String(),
      'model': model,
      if (via != 'native') 'via': via,
      'promptSha256': ?promptSha256,
      'schemaSha256': ?schemaSha256,
    },
  ];
  await file.writeAsString(_encoder.convert({'runs': runs}));
}

String _sha256Of(String content) =>
    crypto.sha256.convert(utf8.encode(content)).toString();

// ---------------------------------------------------------------------------
// judge
// ---------------------------------------------------------------------------

Future<void> _judge(List<String> args) async {
  final parser = ArgParser()
    ..addOption(
      'candidate',
      mandatory: true,
      allowed: candidateSpecs.map((s) => s.id).toList(),
      help: 'candidate id',
    )
    ..addFlag(
      'redo',
      negatable: false,
      help: 're-ask every photo, including already-judged ones',
    );
  final parsed = _parseOrRefuse(parser, args);
  final candidateId = parsed['candidate'] as String;
  final redo = parsed['redo'] as bool;

  final paths = Paths.resolve();
  final (_, manifest) = _loadGates(paths);
  final verdictDir = paths.verdictDirFor(candidateId);
  if (!verdictDir.existsSync()) {
    _refuse([
      'refusing — no verdicts for $candidateId; score it first: make eval-run CANDIDATE=$candidateId',
    ]);
  }

  final byId = {
    for (final verdict in _loadVerdicts(verdictDir)) verdict.photoId: verdict,
  };
  final missing = manifest.entries
      .where((e) => !byId.containsKey(e.id))
      .toList();
  if (missing.isNotEmpty) {
    _refuse([
      'refusing — verdicts for $candidateId do not cover the manifest: ${missing.map((e) => e.id).join(', ')}; '
          're-run the whole candidate (make eval-run CANDIDATE=$candidateId)',
    ]);
  }

  stdout.writeln(
    'judging the two human limbs for $candidateId — machine limbs never prompt.',
  );
  stdout.writeln(
    'Limb 4: every step a real action on objects the photo contains.',
  );
  stdout.writeln(
    'Limb 5: workable order (nothing put away before its surface is cleared).',
  );
  final verdicts = <PhotoVerdict>[];
  for (final entry in manifest.entries) {
    var verdict = byId[entry.id]!;
    if (verdict.human != null && !redo) {
      stdout.writeln('  ${entry.id}: already judged (use --redo to re-ask)');
      verdicts.add(verdict);
      continue;
    }
    if (verdict.steps == null) {
      verdict = verdict.withHuman(
        const HumanVerdict(
          realActions: false,
          workableOrder: false,
          autoRecorded: true,
        ),
      );
      await File('${verdictDir.path}/${entry.id}.json')
          .writeAsString(_encoder.convert(verdict.toJson()));
      stdout.writeln(
        '  ${entry.id}: no parsed steps (machine failure) — human limbs recorded failed, no prompt',
      );
      verdicts.add(verdict);
      continue;
    }
    stdout.writeln('');
    stdout.writeln('photo: ${paths.photos.path}/${entry.filename}');
    stdout.writeln('space type: ${entry.spaceType}');
    stdout.writeln('ground truth: ${entry.groundTruthObjects.join(', ')}');
    for (final failure in _machineFailuresOf(verdict)) {
      stdout.writeln('machine limb (already recorded): $failure');
    }
    for (var i = 0; i < verdict.steps!.length; i++) {
      final step = verdict.steps![i];
      stdout.writeln('  ${i + 1}. ${step.text} — ${step.durationMinutes} min');
    }
    final realActions = _askBool(
      'Limb 4 — every step a real action on objects the photo contains?',
    );
    final workableOrder = _askBool('Limb 5 — workable order?');
    verdict = verdict.withHuman(
      HumanVerdict(realActions: realActions, workableOrder: workableOrder),
    );
    await File('${verdictDir.path}/${entry.id}.json')
        .writeAsString(_encoder.convert(verdict.toJson()));
    verdicts.add(verdict);
  }

  final t = tally(candidateId, verdicts);
  stdout.writeln('');
  stdout.writeln('score: ${t.passed}/${t.photos} photos pass all five limbs');
  if (t.passesBar == true) {
    if (specFor(candidateId).local) {
      stdout.writeln(
        '$candidateId PASSES the $barThreshold/$corpusSize bar — provisional: handset re-verification is '
        'deferred to Epic 5 (AD-9); the cascade stops here.',
      );
    } else {
      stdout.writeln('$candidateId passes the $barThreshold/$corpusSize bar.');
    }
  } else if (t.passesBar == false) {
    stdout.writeln(
      specFor(candidateId).local
          ? '$candidateId is below the bar — killed outright (a desktop failure kills a local candidate).'
          : '$candidateId is below the bar — fail recorded.',
    );
  } else {
    stdout.writeln(
      'judging incomplete: ${t.resolved}/${t.photos} photos resolved.',
    );
  }
  exit(0);
}

List<String> _machineFailuresOf(PhotoVerdict verdict) {
  if (!verdict.transportOk) {
    return ['transport failure — ${verdict.transportReason}'];
  }
  final machine = verdict.machine!;
  return [
    if (!machine.parse.ok) 'parse — ${machine.parse.reason}',
    if (!machine.durations.ok) 'durations — ${machine.durations.reason}',
    if (!machine.steps.ok) 'step count — ${machine.steps.reason}',
  ];
}

bool _askBool(String label) {
  while (true) {
    stdout.write('$label [s/n] ');
    final line = stdin.readLineSync();
    if (line == null) {
      _refuse([
        'input closed — judge aborted; re-run make eval-judge CANDIDATE=<id>',
      ]);
    }
    switch (line.trim().toLowerCase()) {
      case 's' || 'si' || 'sí' || 'y' || 'yes':
        return true;
      case 'n' || 'no':
        return false;
      default:
        stdout.writeln('responde s o n');
    }
  }
}

// ---------------------------------------------------------------------------
// report
// ---------------------------------------------------------------------------

Future<void> _report(List<String> args) async {
  if (args.isNotEmpty) {
    stderr.writeln('report takes no arguments');
    exit(2);
  }
  final paths = Paths.resolve();
  final tallies = _loadTallies(paths);
  if (tallies.isEmpty) {
    _refuse([
      'refusing — nothing to report; score a candidate first: make eval-run CANDIDATE=<id>',
    ]);
  }
  if (!paths.bar.existsSync()) {
    _refuse(['refusing — eval/PASS-BAR.md not found']);
  }
  final bar = validateBar(paths.bar.readAsStringSync());
  if (!bar.ok) {
    _refuse(['refusing — ${bar.failures.join('; ')}']);
  }

  final orderedIds = candidateSpecs
      .map((s) => s.id)
      .where(tallies.containsKey)
      .toList();
  final verdictsById = {
    for (final id in orderedIds) id: _loadVerdicts(paths.verdictDirFor(id)),
  };
  final proposal = cascadeProposal(tallies);
  final oq1Draft = draftOq1Answer(proposal, tallies);
  final generatedAt = DateTime.now().toIso8601String();

  // Per-candidate cost: builder-supplied totals from the committed
  // results/costs.json (the raw responses are gitignored), plus the sum of
  // usage.cost_details.upstream_inference_cost over the recorded raw
  // responses — both shown so a discrepancy stays visible.
  final builderCosts = _loadBuilderCosts(paths);
  final evidenceCosts = {
    for (final id in orderedIds) id: _evidenceCostOf(paths.rawDirFor(id)),
  };

  final runNotes = <String>[];
  final runsById = <String, List<Object?>>{};
  for (final id in orderedIds) {
    final meta = paths.runMetaFor(id);
    if (!meta.existsSync()) continue;
    try {
      final runs =
          (jsonDecode(meta.readAsStringSync()) as Map<String, Object?>)['runs']!
              as List<Object?>;
      runsById[id] = runs;
      final models = runs
          .map((r) => (r as Map)['model'] as String?)
          .toSet()
          .join(', ');
      final routes = runs
          .map((r) => (r as Map)['via'])
          .whereType<String>()
          .toSet()
          .join(', ');
      runNotes.add(
        '- $id: ${runs.length} run(s), model(s) $models'
        '${routes.isEmpty ? '' : ', via $routes'}'
        '${runs.length > 1 ? ' — the latest run supersedes the earlier one(s)' : ''}',
      );
    } on FormatException {
      runNotes.add('- $id: run metadata unparseable');
    }
  }

  final spaceTypes = {
    for (final id in orderedIds)
      for (final v in verdictsById[id]!) v.spaceType,
  };
  if (!paths.manifest.existsSync()) {
    _refuse(['refusing — eval/corpus/manifest.json not found']);
  }
  final manifestOk = validateManifest(
    paths.manifest.readAsStringSync(),
    photoExists: (f) => File('${paths.photos.path}/$f').existsSync(),
  );
  if (!manifestOk.ok) {
    _refuse([
      'refusing — corpus manifest no longer valid: ${manifestOk.failures.join('; ')}',
    ]);
  }
  for (final input in [paths.prompt, paths.schema]) {
    if (!input.existsSync()) {
      _refuse(['refusing — ${input.path} not found']);
    }
  }

  // Shared-input digests recorded per run since the digest amendment: all
  // candidates must have run on identical bytes. Pre-amendment runs record
  // none — noted, not refused (the recorded 2026-09-02 runs predate it).
  final digestNotes = <String>[];
  final promptDigests = <String>{};
  final schemaDigests = <String>{};
  var digestsRecorded = false;
  for (final id in orderedIds) {
    for (final run in runsById[id] ?? const <Object?>[]) {
      final runMap = run as Map<String, Object?>;
      final p = runMap['promptSha256'];
      final s = runMap['schemaSha256'];
      if (p is String && s is String) {
        digestsRecorded = true;
        promptDigests.add(p);
        schemaDigests.add(s);
      }
    }
  }
  if (digestsRecorded) {
    if (promptDigests.length > 1 || schemaDigests.length > 1) {
      _refuse([
        'refusing — shared inputs differ across recorded runs '
            '(prompt digests: ${promptDigests.join(', ')}; '
            'schema digests: ${schemaDigests.join(', ')}) — the byte-identical claim does not hold',
      ]);
    }
    digestNotes.add(
      '- shared-input digests: prompt ${promptDigests.first}, schema '
      '${schemaDigests.first} — identical across every recorded run that carries one',
    );
  } else {
    digestNotes.add(
      '- shared-input digests: not recorded (the runs predate the digest '
      'amendment); byte-identity rests on the run procedure',
    );
  }

  final buffer = StringBuffer();
  buffer
    ..writeln('# Model-evaluation report — story 4.1')
    ..writeln()
    ..writeln(
      'Generated $generatedAt by `make eval-report`. Machine-written: the builder reviews the  ',
    )
    ..writeln(
      'selection proposal and the OQ-1 draft below before the PRD/spine edit lands.',
    )
    ..writeln()
    ..writeln('## Shared inputs (byte-identical for every candidate)')
    ..writeln()
    ..writeln(
      '- prompt: `eval/prompt.md` — sent as the text below its `---` marker, verbatim at the end of this report',
    )
    ..writeln(
      '- schema: `eval/schema.json` — verbatim at the end of this report',
    )
    ..writeln('- bar: `eval/PASS-BAR.md` — confirmed on ${bar.confirmedOn}')
    ..writeln(
      '- corpus: `eval/corpus/manifest.json` — ${manifestOk.entries.length} photos, '
      '${spaceTypes.length} space types (${spaceTypes.join(', ')})',
    )
    ..writeAll(digestNotes, '\n')
    ..writeln()
    ..writeln();
  if (runNotes.isNotEmpty) {
    buffer
      ..writeln('## Runs')
      ..writeln()
      ..writeAll(runNotes, '\n')
      ..writeln()
      ..writeln();
  }
  buffer
    ..writeln('## Scores')
    ..writeln()
    ..writeln(
      '| candidate | photos | judged | machine-passed | passed | bar (≥$barThreshold/$corpusSize) |',
    )
    ..writeln('|---|---|---|---|---|---|');
  for (final id in orderedIds) {
    final t = tallies[id]!;
    buffer.writeln(
      '| $id | ${t.photos} | ${t.resolved} | ${t.machinePassed} | ${t.passed} | ${t.passesBar == null
          ? 'pending'
          : t.passesBar!
          ? 'pass'
          : 'fail'} |',
    );
  }
  buffer.writeln();
  buffer
    ..writeln('## Cost (whole 10-photo run per candidate)')
    ..writeln()
    ..writeln(
      'Builder-supplied totals from the committed `results/costs.json` '
      '(OpenRouter dashboard); the evidence column sums '
      '`usage.cost_details.upstream_inference_cost` over the recorded raw '
      'responses (gitignored, reproducible from the provider). Small '
      'third-decimal differences are dashboard rounding.',
    )
    ..writeln()
    ..writeln(
      '| candidate | builder-supplied USD | evidence sum USD | per photo USD (evidence) |',
    )
    ..writeln('|---|---|---|---|');
  for (final id in orderedIds) {
    final evidence = evidenceCosts[id];
    final photos = verdictsById[id]?.length ?? corpusSize;
    buffer.writeln(
      '| $id | ${builderCosts[id]?.toStringAsFixed(5) ?? 'n/a'} | '
      '${evidence?.toStringAsFixed(5) ?? 'n/a'} | '
      '${evidence == null ? 'n/a' : (evidence / photos).toStringAsFixed(6)} |',
    );
  }
  buffer.writeln();
  for (final id in orderedIds) {
    final fenceCount = verdictsById[id]!
        .where((v) => v.machine?.fenceStripped ?? false)
        .length;
    buffer
      ..writeln('### $id')
      ..writeln()
      ..writeln(
        '- fence-stripped responses (2026-09-02 bar amendment): '
        '$fenceCount of ${verdictsById[id]!.length}',
      )
      ..writeln(
        '| photo | transport | parse | durations | steps | real actions | workable order | passed |',
      )
      ..writeln('|---|---|---|---|---|---|---|---|');
    for (final v in verdictsById[id]!) {
      String limb(bool ok, String? reason) =>
          ok ? 'ok' : 'fail${reason == null ? '' : ' — ${_oneLine(reason)}'}';
      final machine = v.machine;
      buffer.writeln(
        '| ${v.photoId} | ${limb(v.transportOk, v.transportReason)} | '
        '${machine == null ? 'n/a' : limb(machine.parse.ok, machine.parse.reason)} | '
        '${machine == null ? 'n/a' : limb(machine.durations.ok, machine.durations.reason)} | '
        '${machine == null ? 'n/a' : limb(machine.steps.ok, machine.steps.reason)} | '
        '${v.human == null
            ? 'pending'
            : v.human!.realActions
            ? 'ok'
            : 'fail${v.human!.autoRecorded ? ' (auto)' : ''}'} | '
        '${v.human == null
            ? 'pending'
            : v.human!.workableOrder
            ? 'ok'
            : 'fail${v.human!.autoRecorded ? ' (auto)' : ''}'} | '
        '${v.human == null
            ? 'pending'
            : v.passed
            ? 'yes'
            : 'no'} |',
      );
    }
    buffer.writeln();
  }
  buffer
    ..writeln('## Cascade decision')
    ..writeln()
    ..writeln('- kind: ${proposal.kind}')
    ..writeln('- selected: ${proposal.selected ?? 'none'}')
    ..writeln('- ${proposal.rationale}')
    ..writeln()
    ..writeln('## Selection proposal')
    ..writeln()
    ..writeln(
      proposal.selected == null
          ? 'No provider selected yet.'
          : proposal.kind == 'local-provisional'
          ? '${proposal.selected} — proposed provisionally (desktop pass; handset re-verification deferred to Epic 5, AD-9).'
          : '${proposal.selected} — proposed (best cloud candidate at ≥$barThreshold/$corpusSize once the locals were killed).',
    )
    ..writeln()
    ..writeln(
      '## OQ-1 answer (DRAFT — builder reviews before the PRD/spine edit)',
    )
    ..writeln()
    ..writeln(oq1Draft)
    ..writeln()
    ..writeln('## Prompt (verbatim, `eval/prompt.md`)')
    ..writeln()
    ..writeln('```text')
    ..writeln(paths.prompt.readAsStringSync().trimRight())
    ..writeln('```')
    ..writeln()
    ..writeln('## Schema (verbatim, `eval/schema.json`)')
    ..writeln()
    ..writeln('```json')
    ..writeln(paths.schema.readAsStringSync().trimRight())
    ..writeln('```')
    ..writeln();

  await paths.results.create(recursive: true);
  await File('${paths.results.path}/report.md')
      .writeAsString(buffer.toString());
  await File('${paths.results.path}/scores.json').writeAsString(
    _encoder.convert({
      'generatedAt': generatedAt,
      'barConfirmedOn': bar.confirmedOn,
      'prompt': paths.prompt.readAsStringSync(),
      'schema': jsonDecode(paths.schema.readAsStringSync()),
      'candidates': {
        for (final id in orderedIds)
          id: {
            'model': verdictsById[id]!.first.model,
            ...tallies[id]!.toJsonEntries(),
            'fenceStripped': verdictsById[id]!
                .where((v) => v.machine?.fenceStripped ?? false)
                .length,
            'costBuilderUsd': builderCosts[id],
            'costEvidenceUsd': evidenceCosts[id],
            'photos': [
              for (final v in verdictsById[id]!)
                {
                  'photoId': v.photoId,
                  'spaceType': v.spaceType,
                  'transportOk': v.transportOk,
                  'machine': v.machine?.toJson(),
                  'human': v.human?.toJson(),
                  'passed': v.human == null ? null : v.passed,
                },
            ],
          },
      },
      'runs': runsById,
      'cascade': {
        'kind': proposal.kind,
        'selected': proposal.selected,
        'rationale': proposal.rationale,
      },
      'oq1Draft': oq1Draft,
    }),
  );
  stdout.writeln(
    'wrote ${paths.results.path}/report.md and ${paths.results.path}/scores.json',
  );
  stdout.writeln('cascade: ${proposal.rationale}');
  exit(0);
}

extension on CandidateTally {
  Map<String, Object?> toJsonEntries() => {
    'photos': photos,
    'judged': resolved,
    'machinePassed': machinePassed,
    'passed': passed,
    'passesBar': passesBar,
  };
}

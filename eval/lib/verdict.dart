/// Machine limbs, score tally, cascade proposal, manifest + bar validation
/// (story 4.1).
///
/// Pure logic, no HTTP: the CLI glue in `bin/harness.dart` feeds it data and
/// the unit tests exercise it directly. The schema check implements exactly
/// the minimal `eval/schema.json` — `minItems` and the 3–5 bounds live here
/// as distinct limbs instead, so a failure records which limb broke while the
/// schema stays what the app will enforce at runtime.
library;

import 'dart:convert';

import 'package:eval/candidates.dart';

const corpusSize = 10;
const barThreshold = 8;
const minSpaceTypes = 4;
const localCascadeOrder = ['e2b_local', 'e4b_local'];

// ---------------------------------------------------------------------------
// Limbs
// ---------------------------------------------------------------------------

final class SliceStep {
  const SliceStep({required this.text, required this.durationMinutes});

  factory SliceStep.fromJson(Map<String, Object?> json) => SliceStep(
    text: json['text']! as String,
    durationMinutes: json['duration_minutes']! as int,
  );

  final String text;
  final int durationMinutes;

  Map<String, Object?> toJson() => {
    'text': text,
    'duration_minutes': durationMinutes,
  };
}

final class LimbResult {
  const LimbResult.passed() : ok = true, reason = null;

  const LimbResult.failed(String this.reason) : ok = false;

  final bool ok;
  final String? reason;

  Map<String, Object?> toJson() => {
    'ok': ok,
    if (reason != null) 'reason': reason,
  };

  factory LimbResult.fromJson(Map<String, Object?> json) => json['ok'] as bool
      ? const LimbResult.passed()
      : LimbResult.failed(json['reason'] as String? ?? 'failed');
}

final class MachineVerdict {
  const MachineVerdict({
    required this.parse,
    required this.durations,
    required this.steps,
    this.fenceStripped = false,
  });

  factory MachineVerdict.notEvaluated(
    String why, {
    bool fenceStripped = false,
  }) => MachineVerdict(
    parse: LimbResult.failed(why),
    durations: const LimbResult.failed(
      'not evaluated — an earlier limb failed',
    ),
    steps: const LimbResult.failed('not evaluated — an earlier limb failed'),
    fenceStripped: fenceStripped,
  );

  final LimbResult parse;
  final LimbResult durations;
  final LimbResult steps;

  /// True when the raw answer carried a single markdown fence that the
  /// parse limb stripped under the 2026-09-02 bar amendment — recorded so
  /// the report shows how often a candidate needed it, never buried.
  final bool fenceStripped;

  bool get allPassed => parse.ok && durations.ok && steps.ok;

  Map<String, Object?> toJson() => {
    'parse': parse.toJson(),
    'durations': durations.toJson(),
    'steps': steps.toJson(),
    'fenceStripped': fenceStripped,
  };

  factory MachineVerdict.fromJson(Map<String, Object?> json) => MachineVerdict(
    parse: LimbResult.fromJson(json['parse']! as Map<String, Object?>),
    durations: LimbResult.fromJson(json['durations']! as Map<String, Object?>),
    steps: LimbResult.fromJson(json['steps']! as Map<String, Object?>),
    fenceStripped: json['fenceStripped'] as bool? ?? false,
  );
}

final class LimbEvaluation {
  const LimbEvaluation(this.verdict, this.steps);

  final MachineVerdict verdict;
  final List<SliceStep>? steps;
}

/// Limb 1 in the narrow sense: the value conforms to `eval/schema.json`.
/// Returns every failure so the recorded reason names them all.
List<String> validateSlicePlan(Object? value) {
  if (value is! Map) {
    return ['root is not a JSON object'];
  }
  final failures = <String>[];
  final extra = value.keys.where((key) => key != 'steps').toList();
  if (extra.isNotEmpty) {
    failures.add('unexpected root properties: ${extra.join(', ')}');
  }
  if (!value.containsKey('steps')) {
    failures.add("missing required property 'steps'");
    return failures;
  }
  final steps = value['steps'];
  if (steps is! List) {
    failures.add("'steps' is not an array");
    return failures;
  }
  for (var i = 0; i < steps.length; i++) {
    failures.addAll(_stepFailures(steps[i], i));
  }
  return failures;
}

List<String> _stepFailures(Object? step, int index) {
  final n = index + 1;
  if (step is! Map) {
    return ['steps[$n] is not an object'];
  }
  final failures = <String>[];
  final extra = step.keys
      .where((key) => key != 'text' && key != 'duration_minutes')
      .toList();
  if (extra.isNotEmpty) {
    failures.add('steps[$n] unexpected properties: ${extra.join(', ')}');
  }
  if (!step.containsKey('text')) {
    failures.add("steps[$n] missing 'text'");
  } else if (step['text'] is! String) {
    failures.add("steps[$n] 'text' is not a string");
  }
  if (!step.containsKey('duration_minutes')) {
    failures.add("steps[$n] missing 'duration_minutes'");
  } else if (step['duration_minutes'] is! int) {
    failures.add(
      "steps[$n] 'duration_minutes' is not an integer (got ${step['duration_minutes'].runtimeType})",
    );
  }
  return failures;
}

/// Matches a whole response that is exactly one markdown fence — optional
/// leading whitespace, an opening ` ``` ` or ` ```json `, the payload, and a
/// closing ` ``` ` before optional trailing whitespace. Anything else (prose
/// around the JSON, two fences, an unclosed fence) does not match.
final _singleFencePattern = RegExp(
  r'^\s*```(?:json)?\s*\n?([\s\S]*?)\n?\s*```\s*$',
);

/// The 2026-09-02 bar amendment tolerates exactly one markdown fence around
/// the JSON — stripped once, recorded per photo. Returns the payload, or
/// null when the response is not exactly one fence.
String? stripSingleFence(String text) {
  final match = _singleFencePattern.firstMatch(text);
  return match?.group(1);
}

/// The three machine limbs over one candidate reply: first-attempt parse
/// against the schema, every duration within 3–5, at least 4 steps.
LimbEvaluation evaluateModelOutput(ModelOutput output) {
  Object? decoded;
  var fenceStripped = false;
  switch (output) {
    case TextOutput(:final text):
      try {
        decoded = jsonDecode(text);
      } on FormatException catch (e) {
        final payload = stripSingleFence(text);
        if (payload == null) {
          return LimbEvaluation(
            MachineVerdict.notEvaluated('first-attempt JSON parse failed: $e'),
            null,
          );
        }
        try {
          decoded = jsonDecode(payload);
          fenceStripped = true;
        } on FormatException catch (inner) {
          // The fence was stripped but its payload is not JSON — record the
          // payload's error, the text the decode actually ran on.
          return LimbEvaluation(
            MachineVerdict.notEvaluated(
              'first-attempt JSON parse failed: $inner',
            ),
            null,
          );
        }
      }
    case DecodedOutput(:final value):
      decoded = value;
    case OutputAbsent(:final reason):
      return LimbEvaluation(MachineVerdict.notEvaluated(reason), null);
  }
  final schemaFailures = validateSlicePlan(decoded);
  if (schemaFailures.isNotEmpty) {
    return LimbEvaluation(
      MachineVerdict.notEvaluated(
        'schema check failed: ${schemaFailures.join('; ')}',
        fenceStripped: fenceStripped,
      ),
      null,
    );
  }
  final stepsRaw = (decoded as Map)['steps']! as List;
  final steps = [
    for (final raw in stepsRaw)
      SliceStep(
        text: (raw as Map)['text']! as String,
        durationMinutes: raw['duration_minutes']! as int,
      ),
  ];
  final badDurations = <String>[];
  for (var i = 0; i < steps.length; i++) {
    final duration = steps[i].durationMinutes;
    if (duration < 3 || duration > 5) {
      badDurations.add('step ${i + 1}: duration_minutes $duration outside 3–5');
    }
  }
  final durations = badDurations.isEmpty
      ? const LimbResult.passed()
      : LimbResult.failed(badDurations.join('; '));
  final stepLimb = steps.length >= 4
      ? const LimbResult.passed()
      : LimbResult.failed('${steps.length} steps — at least 4 required');
  return LimbEvaluation(
    MachineVerdict(
      parse: const LimbResult.passed(),
      durations: durations,
      steps: stepLimb,
      fenceStripped: fenceStripped,
    ),
    steps,
  );
}

// ---------------------------------------------------------------------------
// Verdict records
// ---------------------------------------------------------------------------

final class HumanVerdict {
  const HumanVerdict({
    required this.realActions,
    required this.workableOrder,
    this.autoRecorded = false,
  });

  factory HumanVerdict.fromJson(Map<String, Object?> json) => HumanVerdict(
    realActions: json['realActions']! as bool,
    workableOrder: json['workableOrder']! as bool,
    autoRecorded: json['autoRecorded'] as bool? ?? false,
  );

  final bool realActions;
  final bool workableOrder;

  /// True when the harness recorded both limbs failed without prompting
  /// because the photo never produced parseable steps.
  final bool autoRecorded;

  Map<String, Object?> toJson() => {
    'realActions': realActions,
    'workableOrder': workableOrder,
    'autoRecorded': autoRecorded,
  };
}

final class PhotoVerdict {
  PhotoVerdict({
    required this.candidate,
    required this.photoId,
    required this.photoFile,
    required this.spaceType,
    required this.model,
    required this.timestamp,
    required this.transportOk,
    this.transportReason,
    this.machine,
    this.steps,
    this.human,
  });

  factory PhotoVerdict.fromJson(Map<String, Object?> json) => PhotoVerdict(
    candidate: json['candidate']! as String,
    photoId: json['photoId']! as String,
    photoFile: json['photoFile']! as String,
    spaceType: json['spaceType']! as String,
    model: json['model']! as String,
    timestamp: json['timestamp']! as String,
    transportOk: json['transportOk']! as bool,
    transportReason: json['transportReason'] as String?,
    machine: json['machine'] == null
        ? null
        : MachineVerdict.fromJson(json['machine']! as Map<String, Object?>),
    steps: json['steps'] == null
        ? null
        : [
            for (final raw in json['steps']! as List)
              SliceStep.fromJson(raw as Map<String, Object?>),
          ],
    human: json['human'] == null
        ? null
        : HumanVerdict.fromJson(json['human']! as Map<String, Object?>),
  );

  final String candidate;
  final String photoId;
  final String photoFile;
  final String spaceType;
  final String model;
  final String timestamp;
  final bool transportOk;
  final String? transportReason;
  final MachineVerdict? machine;
  final List<SliceStep>? steps;
  final HumanVerdict? human;

  bool get machinePassed => transportOk && (machine?.allPassed ?? false);

  /// All five limbs: transport + three machine limbs + two judged limbs.
  bool get passed =>
      machinePassed &&
      (human?.realActions ?? false) &&
      (human?.workableOrder ?? false);

  /// True once the human limbs are recorded (judged, or auto-failed because
  /// there was nothing to judge).
  bool get resolved => human != null;

  PhotoVerdict withHuman(HumanVerdict value) => PhotoVerdict(
    candidate: candidate,
    photoId: photoId,
    photoFile: photoFile,
    spaceType: spaceType,
    model: model,
    timestamp: timestamp,
    transportOk: transportOk,
    transportReason: transportReason,
    machine: machine,
    steps: steps,
    human: value,
  );

  Map<String, Object?> toJson() => {
    'candidate': candidate,
    'photoId': photoId,
    'photoFile': photoFile,
    'spaceType': spaceType,
    'model': model,
    'timestamp': timestamp,
    'transportOk': transportOk,
    'transportReason': transportReason,
    'machine': machine?.toJson(),
    'steps': steps == null ? null : [for (final step in steps!) step.toJson()],
    'human': human?.toJson(),
  };
}

// ---------------------------------------------------------------------------
// Tally
// ---------------------------------------------------------------------------

final class CandidateTally {
  const CandidateTally({
    required this.candidate,
    required this.photos,
    required this.resolved,
    required this.machinePassed,
    required this.passed,
  });

  final String candidate;
  final int photos;
  final int resolved;
  final int machinePassed;
  final int passed;

  /// Fully scored and fully judged over the exact corpus size.
  bool get complete => photos == corpusSize && resolved == corpusSize;

  /// `null` while incomplete — the 8/10 bar only reads over a complete,
  /// fully-judged run.
  bool? get passesBar => complete ? passed >= barThreshold : null;
}

CandidateTally tally(String candidate, List<PhotoVerdict> verdicts) =>
    CandidateTally(
      candidate: candidate,
      photos: verdicts.length,
      resolved: verdicts.where((v) => v.resolved).length,
      machinePassed: verdicts.where((v) => v.machinePassed).length,
      passed: verdicts.where((v) => v.passed).length,
    );

// ---------------------------------------------------------------------------
// Cascade
// ---------------------------------------------------------------------------

final class CascadeProposal {
  const CascadeProposal(this.kind, this.selected, this.rationale);

  /// One of: `local-provisional`, `cloud-best`, `none-passed`, `incomplete`.
  final String kind;
  final String? selected;
  final String rationale;
}

String _scoresOf(Map<String, CandidateTally> results) => results.entries
    .map((e) => '${e.key} ${e.value.passed}/${e.value.photos}')
    .join(', ');

/// The cascade: E2B first; only its failure runs E4B; only both local
/// failures run the cloud trio (all three, scored; best ≥ 8/10 proposed,
/// ties break in `cloudCascadeOrder`).
CascadeProposal cascadeProposal(Map<String, CandidateTally> results) {
  for (final id in localCascadeOrder) {
    final t = results[id];
    if (t == null) {
      return CascadeProposal(
        'incomplete',
        null,
        '$id has not been scored — the cascade stops here (E2B first; only its failure runs E4B; only both local failures run the cloud trio).',
      );
    }
    if (!t.complete) {
      return CascadeProposal(
        'incomplete',
        null,
        '$id is scored but not fully judged — run make eval-judge CANDIDATE=$id before deciding the cascade.',
      );
    }
    if (t.passesBar!) {
      return CascadeProposal(
        'local-provisional',
        id,
        '$id passed ${t.passed}/$corpusSize on the desktop corpus — selected provisionally (handset re-verification deferred to Epic 5, AD-9); every later candidate stays unrun.',
      );
    }
  }
  final localScores = localCascadeOrder
      .map((id) => '$id ${results[id]!.passed}/$corpusSize')
      .join(', ');
  final missingClouds = cloudCascadeOrder
      .where((c) => !results.containsKey(c))
      .toList();
  if (missingClouds.isNotEmpty) {
    return CascadeProposal(
      'incomplete',
      null,
      'both local candidates are killed ($localScores) — the cloud trio runs next; not yet scored: ${missingClouds.join(', ')}.',
    );
  }
  final unresolvedClouds = cloudCascadeOrder
      .where((c) => results[c]!.complete == false)
      .toList();
  if (unresolvedClouds.isNotEmpty) {
    return CascadeProposal(
      'incomplete',
      null,
      'cloud candidate ${unresolvedClouds.join(', ')} is scored but not fully judged — run make eval-judge before deciding the cascade.',
    );
  }
  var best = cloudCascadeOrder.first;
  var bestScore = results[best]!.passed;
  for (final id in cloudCascadeOrder.skip(1)) {
    final score = results[id]!.passed;
    if (score > bestScore) {
      best = id;
      bestScore = score;
    }
  }
  if (bestScore >= barThreshold) {
    return CascadeProposal(
      'cloud-best',
      best,
      '$best is the best cloud candidate at $bestScore/$corpusSize (${_scoresOf(results)}; ties break in cascade order gemini → openai → anthropic) — proposed; the Local path stays a debug-only stub (FR-28).',
    );
  }
  return CascadeProposal(
    'none-passed',
    null,
    'no candidate reached the $barThreshold/$corpusSize bar (${_scoresOf(results)}) — nothing is selected; revise prompt/schema before any re-run.',
  );
}

/// The Ask-First guard behind `eval-run`: what refuses to score without
/// `--force`. Empty list means the run is allowed as-is.
List<String> cascadeGuardFailures(
  String candidateId,
  Map<String, CandidateTally> existing,
) {
  const forceHint = 'use --force to record an explicit Ask-First override';
  final e2b = existing['e2b_local'];
  final e4b = existing['e4b_local'];
  switch (candidateId) {
    case 'e2b_local':
      // Re-running E2B is always allowed: a fresh run supersedes the earlier
      // one and the report notes the supersession.
      return const [];
    case 'e4b_local':
      if (e2b == null) {
        return [
          'E2B must run first — the cascade runs e2b_local before e4b_local; $forceHint',
        ];
      }
      if (e2b.passesBar == true) {
        return [
          'e2b_local already passed ≥$barThreshold/$corpusSize — the cascade stops at E2B; $forceHint',
        ];
      }
      if (e2b.passesBar == null) {
        return [
          'e2b_local is scored but not fully judged — judge it first (make eval-judge CANDIDATE=e2b_local); $forceHint',
        ];
      }
      return const [];
    default:
      if (e2b?.passesBar == true || e4b?.passesBar == true) {
        return [
          'a local candidate already passed ≥$barThreshold/$corpusSize — scoring cloud candidates is an Ask-First, not run by default; $forceHint',
        ];
      }
      if (e2b == null || e4b == null) {
        return [
          'the cascade runs both locals before any cloud candidate — e2b_local and e4b_local must run (and fail) first; $forceHint',
        ];
      }
      if (e2b.passesBar == null || e4b.passesBar == null) {
        return [
          'a local candidate is scored but not fully judged — judge before scoring cloud (make eval-judge CANDIDATE=…); $forceHint',
        ];
      }
      return const [];
  }
}

/// The OQ-1 answer draft `eval-report` emits for builder review — never
/// absorbed silently: the builder carries it into the PRD §9 + Changelog and
/// the spine by hand.
String draftOq1Answer(
  CascadeProposal proposal,
  Map<String, CandidateTally> results,
) {
  final scores = _scoresOf(results);
  switch (proposal.kind) {
    case 'local-provisional':
      final t = results[proposal.selected!]!;
      return 'OQ-1 (draft — builder reviews before the PRD/spine edit): ${proposal.selected} passed '
          '${t.passed}/$corpusSize on the desktop corpus through Lemonade with the frozen prompt and schema, '
          'so the quality half reads as settled for the desktop and the topology half points to the Local path. '
          'A desktop pass is provisional: the Android artifact is more aggressively quantized, so handset '
          're-verification — and the deferred storage/memory/latency/thermal questions — move to Epic 5 per '
          'AD-9. Cloud candidates were not run: the cascade stops at the first local pass. Full scores: $scores.';
    case 'cloud-best':
      return 'OQ-1 (draft — builder reviews before the PRD/spine edit): both local candidates were killed '
          'outright on the desktop (a desktop failure kills — the phone build cannot do better). '
          '${proposal.selected} is the best cloud candidate over the identical corpus, prompt and schema, so '
          'the topology half points to cloud BYOK and the Local path ships as the debug-only canned stub '
          '(FR-28). Full scores: $scores.';
    case 'none-passed':
      return 'OQ-1 stays open: no candidate reached the $barThreshold/$corpusSize bar ($scores) — nothing is '
          'selected; the prompt/schema must be revised before any re-run, and a re-run is always whole-candidate, '
          'superseding and noted in the report.';
    default:
      return 'OQ-1 (draft): cascade incomplete — ${proposal.rationale}';
  }
}

// ---------------------------------------------------------------------------
// Manifest + bar validation
// ---------------------------------------------------------------------------

final class CorpusEntry {
  const CorpusEntry({
    required this.id,
    required this.filename,
    required this.spaceType,
    required this.groundTruthObjects,
  });

  factory CorpusEntry.fromJson(Map<String, Object?> json) => CorpusEntry(
    id: json['id']! as String,
    filename: json['filename']! as String,
    spaceType: json['spaceType']! as String,
    groundTruthObjects: [
      for (final raw in json['groundTruthObjects']! as List) raw as String,
    ],
  );

  final String id;
  final String filename;
  final String spaceType;
  final List<String> groundTruthObjects;

  Map<String, Object?> toJson() => {
    'id': id,
    'filename': filename,
    'spaceType': spaceType,
    'groundTruthObjects': groundTruthObjects,
  };
}

final class ManifestCheck {
  const ManifestCheck(this.failures, this.entries);

  final List<String> failures;
  final List<CorpusEntry> entries;

  bool get ok => failures.isEmpty;
}

const allowedPhotoExtensions = ['.jpg', '.jpeg', '.png'];

/// Validates the corpus manifest: exactly $corpusSize photos, ≥
/// $minSpaceTypes distinct space types, every referenced file present under
/// `eval/corpus/photos/`, unique non-empty ids, non-empty ground truth.
/// Lists every failure, never just the first.
ManifestCheck validateManifest(
  String source, {
  required bool Function(String filename) photoExists,
}) {
  Object? decoded;
  try {
    decoded = jsonDecode(source);
  } on FormatException catch (e) {
    return ManifestCheck(['manifest.json is not valid JSON: $e'], const []);
  }
  if (decoded is! Map) {
    return ManifestCheck(['manifest root is not a JSON object'], const []);
  }
  final failures = <String>[];
  final extraRoot = decoded.keys.where((key) => key != 'photos').toList();
  if (extraRoot.isNotEmpty) {
    failures.add('unexpected root properties: ${extraRoot.join(', ')}');
  }
  final photos = decoded['photos'];
  if (photos is! List) {
    failures.add("'photos' is missing or not an array");
    return ManifestCheck(failures, const []);
  }
  if (photos.isEmpty) {
    failures.add(
      'the corpus is empty — the builder supplies $corpusSize photos (≥ $minSpaceTypes space types) under '
      'eval/corpus/photos/ (gitignored) with ground truth here: '
      '{"id": "…", "filename": "…", "spaceType": "…", "groundTruthObjects": ["…"]}',
    );
  }
  final entries = <CorpusEntry>[];
  final seenIds = <String>{};
  final seenFiles = <String>{};
  for (var i = 0; i < photos.length; i++) {
    final entry = photos[i];
    if (entry is! Map) {
      failures.add('photos[$i] is not an object');
      continue;
    }
    final label = 'photos[$i]';
    final okSoFar = <bool>[true];
    void fail(String message) {
      failures.add('$label $message');
      okSoFar[0] = false;
    }

    final id = entry['id'];
    if (id is! String || id.trim().isEmpty) {
      fail("'id' is missing or not a non-empty string");
    } else if (id.contains('/') || id.contains(r'\') || id.contains('..')) {
      fail("'id' must be a bare name (no path separators or '..')");
    } else if (!seenIds.add(id)) {
      fail("duplicate id '$id'");
    }
    final filename = entry['filename'];
    if (filename is! String || filename.trim().isEmpty) {
      fail("'filename' is missing or not a non-empty string");
    } else if (filename.contains('/') ||
        filename.contains(r'\') ||
        filename.contains('..')) {
      fail("'filename' must be a bare name (no directories)");
    } else if (!seenFiles.add(filename)) {
      fail("duplicate filename '$filename' — two ids sharing one photo");
    } else {
      final lower = filename.toLowerCase();
      final extension = allowedPhotoExtensions.where(lower.endsWith).toList();
      if (extension.isEmpty) {
        fail(
          "'filename' extension is not one of ${allowedPhotoExtensions.join(', ')}",
        );
      } else if (!photoExists(filename)) {
        fail("file '$filename' not found under eval/corpus/photos/");
      }
    }
    final spaceType = entry['spaceType'];
    if (spaceType is! String || spaceType.trim().isEmpty) {
      fail("'spaceType' is missing or not a non-empty string");
    }
    final objects = entry['groundTruthObjects'];
    if (objects is! List || objects.isEmpty) {
      fail("'groundTruthObjects' is missing or empty");
    } else if (objects.any((o) => o is! String || o.trim().isEmpty)) {
      fail(
        "'groundTruthObjects' must be a non-empty list of non-empty strings",
      );
    }
    if (okSoFar[0]) {
      entries.add(CorpusEntry.fromJson(entry.cast<String, Object?>()));
    }
  }
  if (photos.length != corpusSize) {
    failures.add('expected exactly $corpusSize photos, found ${photos.length}');
  }
  final types = entries.map((e) => e.spaceType).toSet();
  if (types.length < minSpaceTypes) {
    failures.add(
      'expected at least $minSpaceTypes distinct space types, found ${types.length}'
      '${types.isEmpty ? '' : ' (${types.join(", ")})'}',
    );
  }
  return ManifestCheck(failures, entries);
}

final class BarCheck {
  const BarCheck(this.failures, this.confirmedOn);

  final List<String> failures;
  final String? confirmedOn;

  bool get ok => failures.isEmpty;
}

final _confirmationPattern = RegExp(
  r'^Confirmed:\s*(\d{4})-(\d{2})-(\d{2})',
  multiLine: true,
);

/// `eval/prompt.md` declares that everything below its `---` marker line is
/// the prompt text — the harness sends exactly that, never the file's own
/// documentation header. A file with no marker is sent whole (there is
/// nothing to strip).
String promptTextOf(String promptFileContents) {
  final lines = promptFileContents.split('\n');
  for (var i = 0; i < lines.length; i++) {
    if (lines[i].trim() == '---') {
      return lines.skip(i + 1).join('\n').trimLeft();
    }
  }
  return promptFileContents;
}

/// Natural id order — digit runs compare numerically, so `estancia-2`
/// precedes `estancia-10` instead of following it lexicographically.
int comparePhotoIds(String a, String b) {
  final pa = RegExp(r'\d+').allMatches(a).map((m) => m[0]!).toList();
  final pb = RegExp(r'\d+').allMatches(b).map((m) => m[0]!).toList();
  for (var i = 0; i < pa.length && i < pb.length; i++) {
    final na = int.parse(pa[i]);
    final nb = int.parse(pb[i]);
    if (na != nb) return na.compareTo(nb);
  }
  return a.compareTo(b);
}

/// The bar is confirmed when PASS-BAR.md carries a dated `Confirmed:` line —
/// the placeholder `YYYY-MM-DD` does not match, so an unconfirmed bar refuses
/// to score.
BarCheck validateBar(String content) {
  final match = _confirmationPattern.firstMatch(content);
  if (match == null) {
    return BarCheck([
      'PASS-BAR.md carries no dated builder confirmation — write a real "Confirmed: YYYY-MM-DD — <name>" '
          'line into its Builder confirmation section (Ask-First: the bar is confirmed before the first scored run)',
    ], null);
  }
  final year = int.parse(match.group(1)!);
  final month = int.parse(match.group(2)!);
  final day = int.parse(match.group(3)!);
  final date = '${match.group(1)}-${match.group(2)}-${match.group(3)}';
  // DateTime.parse normalizes out-of-range components, so a plain tryParse
  // would accept 2026-13-45 — verify the components round-trip unchanged.
  final parsed = DateTime.tryParse(date);
  if (parsed == null ||
      parsed.year != year ||
      parsed.month != month ||
      parsed.day != day) {
    return BarCheck(['confirmation date "$date" is not a real date'], null);
  }
  return BarCheck(const [], date);
}

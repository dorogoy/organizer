// ignore_for_file: avoid_print
//
// Story 5.1's person-gate instrument (v2 — face ∨ pose; the voided
// run-2 attempt's), preserved verbatim at
// face-gate/probe/face_gate_probe_v2_test.dart after the composition
// deferral (2026-09-05). It measured the amended gate: the spine-pinned
// face plugin plus the then-pinned pose plugin, both detectors' frozen
// configurations parsed out of face-gate/BAR.md — trust comes from the
// measurement, never from a README. Restores to
// integration_test/face_gate_probe_test.dart (see the report's restore
// recipe; the _v2_ suffix is the evidence-pack disambiguator).
//
// Contract (the story's spec, as amended 2026-09-05): reads BAR.md and
// the corpus from the app's external-files dir (adb-pushed there; no
// permissions needed), refuses to score without the bar's dated
// builder confirmation, validates the corpus floor, scores every photo
// through BOTH pinned detectors (face: FaceDetectorOptions; pose:
// PoseDetectorOptions, accurate model, single mode) and refuses the
// frame iff either finds ≥ 1 detection — the person gate, face ∨ pose.
// Writes per-image rows (faces + poses) plus the FN/FP summary to
// <external-files>/facegate/results/run-<n>.json, and fails the run iff
// any false negative exists — the bar's escalation path, never silent
// tuning. No upload path: no HTTP import, nothing from lib/egress/, and
// the results stay on-device until the operator pulls them.
//
// Operator recipe (AGENTS.md → Android emulation setup). Scoped
// storage hides shell-created dirs from the app, and each test run ends
// by uninstalling the app (wiping its external tree) — so the probe
// creates its own dirs and waits for the push mid-run:
//   flutter test integration_test/face_gate_probe_test.dart -d emulator-5554
//   # when the probe prints "waiting … for BAR.md":
//   adb push face-gate/BAR.md /sdcard/Android/data/dev.dorogoy.organizer/files/facegate/
//   adb push face-gate/corpus/. /sdcard/Android/data/dev.dorogoy.organizer/files/facegate/corpus/
//   # the run JSON prints between "----- face-gate run json begin/end -----" —
//   # capture the console copy (the run-end uninstall wipes the on-device one)
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';

/// The evidence pack's directory inside the app's external-files dir.
const String facegateDirName = 'facegate';

/// The bar file, pushed verbatim from the committed evidence pack.
const String barFileName = 'BAR.md';

/// The committed ground truth, pushed with its machine-local photos.
const String manifestFileName = 'manifest.json';
const String photosDirName = 'photos';

/// Where the per-run machine output lands (pulled into results/runs/).
const String resultsDirName = 'results';
const String runFilePrefix = 'run-';
const String runFileSuffix = '.json';

/// One scored attempt plus the single rerun the bar's error row allows.
const int maxAttemptsPerPhoto = 2;

/// Generous: ML Kit's first load plus the whole corpus on one emulator.
const Duration probeTimeout = Duration(minutes: 30);

/// How long the probe waits, dirs created, for the operator's adb push.
/// The external-files tree the probe reads must be created by the app
/// itself (scoped storage's FUSE view hides shell-created dirs from the
/// app), and each `flutter test` run ends by uninstalling the app and
/// wiping that tree — so the run that scores is the one that waits for
/// the push, not a second run after it.
const Duration pushWait = Duration(minutes: 15);
const Duration pushPollInterval = Duration(seconds: 5);

/// The dated builder confirmation, 4-1 `PASS-BAR.md`'s marker contract:
/// a line starting `Confirmed: YYYY-MM-DD` — trailing explanation prose
/// after the date is tolerated, as in 4-1's confirmed line.
final RegExp confirmationRegExp = RegExp(
  r'^Confirmed:[ \t]*(\d{4})-(\d{2})-(\d{2})\b',
  multiLine: true,
);

/// The two machine-readable blocks of the bar (see BAR.md).
const String detectorConfigBegin = '<!-- detector-config: begin -->';
const String detectorConfigEnd = '<!-- detector-config: end -->';
const String poseDetectorConfigBegin = '<!-- pose-detector-config: begin -->';
const String poseDetectorConfigEnd = '<!-- pose-detector-config: end -->';
const String barFactsBegin = '<!-- bar-facts: begin -->';
const String barFactsEnd = '<!-- bar-facts: end -->';
const List<String> detectorConfigKeys = [
  'performanceMode',
  'minFaceSize',
  'enableClassification',
  'enableContours',
  'enableLandmarks',
  'enableTracking',
];
const List<String> poseDetectorConfigKeys = ['model', 'mode'];
const List<String> barFactsKeys = [
  'minPhotosPerHardCaseCategory',
  'minNoPersonPhotos',
];

/// The six with-people hard-case categories (BAR.md → Corpus floor).
const Set<String> hardCaseCategories = {
  'partial',
  'profile',
  'distance',
  'low-light',
  'mirror',
  'print-on-wall',
};

const String personClass = 'person';
const String noPersonClass = 'no-person';

/// One corpus photo's committed ground truth.
final class CorpusPhoto {
  const CorpusPhoto({
    required this.id,
    required this.fileName,
    required this.isPerson,
    required this.categories,
  });

  final String id;
  final String fileName;
  final bool isPerson;
  final Set<String> categories;

  Map<String, Object?> toJson() => <String, Object?>{
    'id': id,
    'filename': fileName,
    'class': isPerson ? personClass : noPersonClass,
    'categories': categories.toList()..sort(),
  };
}

/// The bar's corpus floors, parsed from BAR.md's bar-facts block.
final class BarFloors {
  const BarFloors({required this.perHardCaseCategory, required this.noPerson});

  final int perHardCaseCategory;
  final int noPerson;
}

/// Parses one `<!-- begin -->` … `<!-- end -->` block of the bar into
/// its `key: value` lines. Anything that is not a `key: value` line is
/// tolerated as prose; a missing block refuses the run.
Map<String, String> parseBarBlock(String barText, String begin, String end) {
  final start = barText.indexOf(begin);
  if (start < 0) {
    throw StateError(
      'refuses to score: BAR.md carries no $begin block — the bar, not the '
      'probe, is the source of truth',
    );
  }
  final stop = barText.indexOf(end, start + begin.length);
  if (stop < 0) {
    throw StateError('refuses to score: BAR.md block $begin is unterminated');
  }
  final values = <String, String>{};
  for (final rawLine
      in barText.substring(start + begin.length, stop).split('\n')) {
    final line = rawLine.trim();
    if (line.isEmpty) {
      continue;
    }
    final colon = line.indexOf(':');
    if (colon < 0) {
      continue;
    }
    values[line.substring(0, colon).trim()] = line.substring(colon + 1).trim();
  }
  return values;
}

/// The dated builder confirmation, or a refusal. The scored run may not
/// predate its builder's confirmation of the bar (Ask-First limb).
String parseBarConfirmation(String barText) {
  final match = confirmationRegExp.firstMatch(barText);
  if (match == null) {
    throw StateError(
      'refuses to score: BAR.md carries no dated builder confirmation — add '
      'a real `Confirmed: YYYY-MM-DD` line to its Builder confirmation '
      'section before any scored run',
    );
  }
  final year = int.parse(match.group(1)!);
  final month = int.parse(match.group(2)!);
  final day = int.parse(match.group(3)!);
  const List<int> monthLengths = [
    31,
    29,
    31,
    30,
    31,
    30,
    31,
    31,
    30,
    31,
    30,
    31,
  ];
  final plausibleDate =
      month >= 1 && month <= 12 && day >= 1 && day <= monthLengths[month - 1];
  if (!plausibleDate) {
    throw StateError(
      'refuses to score: BAR.md confirmation line is not a plausible date — '
      '${match.group(0)}',
    );
  }
  return '$year-${match.group(2)}-${match.group(3)}';
}

/// The pinned detector configuration, parsed from BAR.md so the bar and
/// the measurement cannot drift apart.
FaceDetectorOptions parseDetectorOptions(String barText) {
  final config = parseBarBlock(barText, detectorConfigBegin, detectorConfigEnd);
  final missing = detectorConfigKeys
      .where((key) => !config.containsKey(key))
      .toList();
  if (missing.isNotEmpty) {
    throw StateError(
      'refuses to score: BAR.md detector-config block lacks '
      '${missing.join(', ')}',
    );
  }
  final FaceDetectorMode performanceMode;
  switch (config['performanceMode']) {
    case 'accurate':
      performanceMode = FaceDetectorMode.accurate;
    case 'fast':
      performanceMode = FaceDetectorMode.fast;
    default:
      throw StateError(
        'refuses to score: BAR.md performanceMode must be accurate or fast, '
        'not ${config['performanceMode']}',
      );
  }
  final double minFaceSize;
  try {
    minFaceSize = double.parse(config['minFaceSize']!);
  } on FormatException {
    throw StateError(
      'refuses to score: BAR.md minFaceSize is not a number — '
      '${config['minFaceSize']}',
    );
  }
  if (minFaceSize < 0 || minFaceSize > 1) {
    throw StateError(
      'refuses to score: BAR.md minFaceSize must be within 0.0–1.0 — '
      '$minFaceSize',
    );
  }
  bool parseSwitch(String key) {
    final value = config[key];
    if (value == 'true' || value == 'false') {
      return value == 'true';
    }
    throw StateError(
      'refuses to score: BAR.md $key must be true or false, not $value',
    );
  }

  return FaceDetectorOptions(
    performanceMode: performanceMode,
    minFaceSize: minFaceSize,
    enableClassification: parseSwitch('enableClassification'),
    enableContours: parseSwitch('enableContours'),
    enableLandmarks: parseSwitch('enableLandmarks'),
    enableTracking: parseSwitch('enableTracking'),
  );
}

/// The pose detector's pinned configuration, parsed from BAR.md's
/// pose-detector-config block (the 2026-09-05 amendment's second
/// detector) — accurate model, single-image mode.
PoseDetectorOptions parsePoseDetectorOptions(String barText) {
  final config = parseBarBlock(
    barText,
    poseDetectorConfigBegin,
    poseDetectorConfigEnd,
  );
  final missing = poseDetectorConfigKeys
      .where((key) => !config.containsKey(key))
      .toList();
  if (missing.isNotEmpty) {
    throw StateError(
      'refuses to score: BAR.md pose-detector-config block lacks '
      '${missing.join(', ')}',
    );
  }
  final PoseDetectionModel model;
  switch (config['model']) {
    case 'accurate':
      model = PoseDetectionModel.accurate;
    case 'base':
      model = PoseDetectionModel.base;
    default:
      throw StateError(
        'refuses to score: BAR.md pose model must be accurate or base, '
        'not ${config['model']}',
      );
  }
  final PoseDetectionMode mode;
  switch (config['mode']) {
    case 'single':
      mode = PoseDetectionMode.single;
    case 'stream':
      mode = PoseDetectionMode.stream;
    default:
      throw StateError(
        'refuses to score: BAR.md pose mode must be single or stream, '
        'not ${config['mode']}',
      );
  }
  return PoseDetectorOptions(model: model, mode: mode);
}

/// The corpus floors, parsed from BAR.md's bar-facts block.
BarFloors parseBarFloors(String barText) {
  final facts = parseBarBlock(barText, barFactsBegin, barFactsEnd);
  final missing = barFactsKeys.where((key) => !facts.containsKey(key)).toList();
  if (missing.isNotEmpty) {
    throw StateError(
      'refuses to score: BAR.md bar-facts block lacks ${missing.join(', ')}',
    );
  }
  int parseFloor(String key) {
    final value = int.tryParse(facts[key]!);
    if (value == null || value < 0) {
      throw StateError(
        'refuses to score: BAR.md $key must be a non-negative integer, not '
        '${facts[key]}',
      );
    }
    return value;
  }

  return BarFloors(
    perHardCaseCategory: parseFloor('minPhotosPerHardCaseCategory'),
    noPerson: parseFloor('minNoPersonPhotos'),
  );
}

/// Loads the manifest and validates it against the floors: classes and
/// categories well-formed, every hard-case category at its floor, the
/// no-person limb at its floor, ids unique, photo files present. A
/// corpus that cannot be scored refuses before any image is processed.
List<CorpusPhoto> loadCorpus(Directory baseDir, BarFloors floors) {
  final manifestFile = File('${baseDir.path}/corpus/$manifestFileName');
  if (!manifestFile.existsSync()) {
    throw StateError(
      'refuses to score: ${manifestFile.path} missing — adb-push the '
      'evidence pack with the corpus',
    );
  }
  final Object decoded;
  try {
    decoded = jsonDecode(manifestFile.readAsStringSync());
  } on FormatException {
    throw StateError('refuses to score: manifest.json is not valid JSON');
  }
  if (decoded is! Map<String, dynamic> || decoded['photos'] is! List) {
    throw StateError(
      'refuses to score: manifest.json has no photos list — fill it with the '
      "builder's pseudonymous ground truth",
    );
  }
  final photos = <CorpusPhoto>[];
  final ids = <String>{};
  for (final entry in decoded['photos'] as List) {
    if (entry is! Map<String, dynamic>) {
      throw StateError('refuses to score: manifest entry is not an object');
    }
    final id = entry['id'];
    final fileName = entry['filename'];
    final cls = entry['class'];
    if (id is! String || fileName is! String || cls is! String) {
      throw StateError(
        'refuses to score: manifest entry needs string id, filename and class',
      );
    }
    if (!ids.add(id)) {
      throw StateError('refuses to score: duplicate manifest id $id');
    }
    final categoryList = entry['categories'] ?? const <String>[];
    if (categoryList is! List ||
        categoryList.any((category) => category is! String)) {
      throw StateError(
        'refuses to score: manifest categories of $id must be a list of '
        'strings',
      );
    }
    final categories = Set<String>.from(categoryList);
    final unknown = categories.difference(hardCaseCategories);
    if (unknown.isNotEmpty) {
      throw StateError(
        'refuses to score: manifest id $id carries unknown category '
        '${unknown.toList().join(', ')}',
      );
    }
    if (cls == personClass) {
      if (categories.isEmpty) {
        throw StateError(
          'refuses to score: manifest id $id is class person with no '
          'hard-case category',
        );
      }
      photos.add(
        CorpusPhoto(
          id: id,
          fileName: fileName,
          isPerson: true,
          categories: categories,
        ),
      );
    } else if (cls == noPersonClass) {
      if (categories.isNotEmpty) {
        throw StateError(
          'refuses to score: manifest id $id is class no-person but carries '
          'categories',
        );
      }
      photos.add(
        CorpusPhoto(
          id: id,
          fileName: fileName,
          isPerson: false,
          categories: categories,
        ),
      );
    } else {
      throw StateError(
        'refuses to score: manifest id $id class must be person or no-person, '
        'not $cls',
      );
    }
  }
  if (photos.isEmpty) {
    throw StateError('refuses to score: the corpus is empty');
  }
  for (final category in hardCaseCategories) {
    final count = photos
        .where((photo) => photo.categories.contains(category))
        .length;
    if (count < floors.perHardCaseCategory) {
      throw StateError(
        'refuses to score: corpus floor unmet — category $category has '
        '$count photo(s), the bar demands ${floors.perHardCaseCategory}',
      );
    }
  }
  final noPersonCount = photos.where((photo) => !photo.isPerson).length;
  if (noPersonCount < floors.noPerson) {
    throw StateError(
      'refuses to score: corpus floor unmet — $noPersonCount no-person '
      'photo(s), the bar demands ${floors.noPerson}',
    );
  }
  final photosDir = Directory('${baseDir.path}/corpus/$photosDirName');
  for (final photo in photos) {
    if (!File('${photosDir.path}/${photo.fileName}').existsSync()) {
      throw StateError(
        'refuses to score: corpus photo ${photo.fileName} (${photo.id}) is '
        'not in ${photosDir.path}',
      );
    }
  }
  return photos;
}

/// The amended gate rule (BAR.md, 2026-09-05): a frame is refused iff
/// face detection finds ≥ 1 face OR pose detection finds ≥ 1 pose.
/// Verdicts against the manifest's ground truth: a `person` photo not
/// refused is the false negative; a `no-person` photo refused is the
/// false positive (accepted); refusals on `person` are gate-passes,
/// clean passes on `no-person`.
String verdictFor({
  required bool isPerson,
  required int faces,
  required int poses,
}) {
  final refused = faces > 0 || poses > 0;
  if (isPerson) {
    return refused ? 'gate-pass' : 'false-negative';
  }
  return refused ? 'false-positive' : 'clean-pass';
}

/// One detector's outcome after its retry budget: the count when it
/// succeeded, `null` when it errored through every attempt.
Future<(int?, int, Object?)> countWithRetry(
  Future<int> Function() detect,
) async {
  Object? failure;
  for (var attempt = 1; attempt <= maxAttemptsPerPhoto; attempt++) {
    try {
      return (await detect(), attempt, null);
    } on Object catch (error) {
      failure = error;
    }
  }
  return (null, maxAttemptsPerPhoto, failure);
}

/// Scores one photo through BOTH detectors: a detection error on either
/// is retried once, then the row is declared `error` — excluded from
/// the FN/FP denominators, reported, never silently dropped.
Future<Map<String, Object?>> scorePhoto(
  FaceDetector faceDetector,
  PoseDetector poseDetector,
  Directory photosDir,
  CorpusPhoto photo,
) async {
  final file = File('${photosDir.path}/${photo.fileName}');
  final stopwatch = Stopwatch()..start();
  final (faces, faceAttempts, faceFailure) = await countWithRetry(() async {
    final result = await faceDetector.processImage(
      InputImage.fromFilePath(file.path),
    );
    return result.length;
  });
  final (poses, poseAttempts, poseFailure) = await countWithRetry(() async {
    final result = await poseDetector.processImage(
      InputImage.fromFilePath(file.path),
    );
    return result.length;
  });
  stopwatch.stop();
  final scored = faces != null && poses != null;
  final verdict = !scored
      ? 'error'
      : verdictFor(isPerson: photo.isPerson, faces: faces, poses: poses);
  return <String, Object?>{
    ...photo.toJson(),
    'faces': faces,
    'poses': poses,
    'verdict': verdict,
    'faceAttempts': faceAttempts,
    'poseAttempts': poseAttempts,
    'elapsedMs': stopwatch.elapsedMilliseconds,
    if (faceFailure != null) 'faceError': faceFailure.toString(),
    if (poseFailure != null) 'poseError': poseFailure.toString(),
  };
}

/// `run-<n>.json`, n one past the highest already written — each scored
/// run lands beside its predecessors, never over them.
int nextRunNumber(Directory resultsDir) {
  if (!resultsDir.existsSync()) {
    return 1;
  }
  var highest = 0;
  for (final entity in resultsDir.listSync()) {
    final name = entity.uri.pathSegments.last;
    if (!name.startsWith(runFilePrefix) || !name.endsWith(runFileSuffix)) {
      continue;
    }
    final number = int.tryParse(
      name.substring(runFilePrefix.length, name.length - runFileSuffix.length),
    );
    if (number != null && number > highest) {
      highest = number;
    }
  }
  return highest + 1;
}

/// Waits until [file] exists, printing the push recipe once — the probe
/// creates the app-owned tree (the only kind its scoped-storage view can
/// see), then the operator pushes the evidence pack into it mid-run.
Future<void> waitForPush(File file, String what) async {
  if (file.existsSync()) {
    return;
  }
  print(
    'waiting up to ${pushWait.inMinutes} min for $what — adb-push it now:\n'
    '  adb push face-gate/${file.path.split('/facegate/').last} '
    '${file.path}',
  );
  final stopwatch = Stopwatch()..start();
  while (!file.existsSync()) {
    if (stopwatch.elapsed >= pushWait) {
      fail(
        'refuses to score: $what never arrived within '
        '${pushWait.inMinutes} min — '
        're-run the probe and adb-push during the wait window',
      );
    }
    await Future<void>.delayed(pushPollInterval);
  }
  print('$what arrived after ${stopwatch.elapsed.inSeconds} s');
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('face-gate probe — the pinned detector over the corpus', (
    tester,
  ) async {
    final externalDir = await getExternalStorageDirectory();
    if (externalDir == null) {
      fail('refuses to score: this device exposes no external-files dir');
    }
    final baseDir = Directory('${externalDir.path}/$facegateDirName');
    baseDir.createSync(recursive: true);
    // The whole tree is app-created before anything is pushed: the FUSE
    // view only shows the app entries inside dirs it owns, so the
    // operator's push must land files, never mkdirs.
    Directory('${baseDir.path}/corpus/$photosDirName')
        .createSync(recursive: true);
    Directory('${baseDir.path}/$resultsDirName').createSync(recursive: true);
    final barFile = File('${baseDir.path}/$barFileName');
    await waitForPush(barFile, 'BAR.md');
    final barText = barFile.readAsStringSync();
    final confirmedOn = parseBarConfirmation(barText);
    final options = parseDetectorOptions(barText);
    final poseOptions = parsePoseDetectorOptions(barText);
    final floors = parseBarFloors(barText);
    final manifestFile = File('${baseDir.path}/corpus/$manifestFileName');
    await waitForPush(manifestFile, 'corpus manifest.json');
    final photos = loadCorpus(baseDir, floors);
    final photosDir = Directory('${baseDir.path}/corpus/$photosDirName');
    print(
      'bar confirmed $confirmedOn — ${photos.length} photos, face '
      '${options.toJson()}, pose ${poseOptions.toJson()}',
    );

    final faceDetector = FaceDetector(options: options);
    final poseDetector = PoseDetector(options: poseOptions);
    final rows = <Map<String, Object?>>[];
    try {
      for (final photo in photos) {
        final row = await scorePhoto(
          faceDetector,
          poseDetector,
          photosDir,
          photo,
        );
        rows.add(row);
        print(
          '${photo.id}: ${row['verdict']} (${row['faces'] ?? '-'} faces, '
          '${row['poses'] ?? '-'} poses, ${row['elapsedMs']} ms)',
        );
      }
    } finally {
      await faceDetector.close();
      await poseDetector.close();
    }

    var gatePasses = 0;
    var falseNegatives = 0;
    var falsePositives = 0;
    var cleanPasses = 0;
    var errors = 0;
    // The amendment's effect, visible in the run file: person photos
    // the pose detector rescued after the face detector missed, and
    // the both/face-only split of the passes.
    var faceOnlyPasses = 0;
    var poseOnlyPasses = 0;
    var bothPasses = 0;
    for (final row in rows) {
      switch (row['verdict'] as String) {
        case 'gate-pass':
          gatePasses++;
          final faces = row['faces'] as int;
          final poses = row['poses'] as int;
          if (faces > 0 && poses > 0) {
            bothPasses++;
          } else if (faces > 0) {
            faceOnlyPasses++;
          } else {
            poseOnlyPasses++;
          }
        case 'false-negative':
          falseNegatives++;
        case 'false-positive':
          falsePositives++;
        case 'clean-pass':
          cleanPasses++;
        default:
          errors++;
      }
    }
    final scoredPersons = gatePasses + falseNegatives;
    final summary = <String, Object?>{
      'photos': rows.length,
      'scoredPersons': scoredPersons,
      'gatePasses': gatePasses,
      'faceOnlyPasses': faceOnlyPasses,
      'poseOnlyPasses': poseOnlyPasses,
      'rescuedByPose': poseOnlyPasses,
      'bothPasses': bothPasses,
      'falseNegatives': falseNegatives,
      'falsePositives': falsePositives,
      'cleanPasses': cleanPasses,
      'errors': errors,
    };
    final barPassed = falseNegatives == 0;
    final run = <String, Object?>{
      'probe': 'integration_test/face_gate_probe_test.dart (story 5.1)',
      'startedUtc': DateTime.now().toUtc().toIso8601String(),
      'barConfirmedOn': confirmedOn,
      'detectorOptions': options.toJson(),
      'poseDetectorOptions': poseOptions.toJson(),
      'floors': {
        'minPhotosPerHardCaseCategory': floors.perHardCaseCategory,
        'minNoPersonPhotos': floors.noPerson,
      },
      'corpus': {
        'photos': photos.length,
        'perCategory': {
          for (final category in hardCaseCategories)
            category: photos
                .where((photo) => photo.categories.contains(category))
                .length,
        },
        'noPerson': photos.where((photo) => !photo.isPerson).length,
      },
      'rows': rows,
      'summary': summary,
      'barPassed': barPassed,
    };
    final resultsDir = Directory('${baseDir.path}/$resultsDirName');
    resultsDir.createSync(recursive: true);
    final runNumber = nextRunNumber(resultsDir);
    final runFile = File(
      '${resultsDir.path}/$runFilePrefix$runNumber$runFileSuffix',
    );
    final runJsonText = const JsonEncoder.withIndent('  ').convert(run);
    runFile.writeAsStringSync(runJsonText);
    print('summary: $summary');
    print(
      'bar ${barPassed ? 'passed' : 'FAILED'} — results in ${runFile.path}',
    );
    // The run ends with the runner uninstalling the app, which wipes the
    // external tree — the console copy is the one that reliably survives.
    print('----- face-gate run json begin -----');
    print(runJsonText);
    print('----- face-gate run json end -----');

    expect(
      falseNegatives,
      0,
      reason:
          'BAR FAILED: $falseNegatives of $scoredPersons person photo(s) '
          'were not refused by either detector (zero faces and zero '
          'poses) — escalate to the builder with the measurement, never '
          'absorbed as tuning. Results are in the console copy above.',
    );
  }, timeout: const Timeout(probeTimeout));
}

// Story 5.1's probe, unit-tested host-side where the I/O matrix is
// machine-checkable without a device: the refusal limbs (unconfirmed
// bar, unparsable bar, floor unmet, corrupt manifest) and the parsers
// that turn BAR.md into the pinned detector configuration. The scored
// loop itself is device-only by design. Preserved (not deleted) with
// the instrument at face-gate/probe/ after the story's close-outs —
// sha256-recorded in face-gate/results/report.md; restores to
// test/face_gate_probe_test.dart.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

import 'face_gate_probe_test.dart' as probe;

const String confirmedBar = '''
# Face-gate bar — on-device face detection (story 5.1)

<!-- detector-config: begin -->
performanceMode: accurate
minFaceSize: 0.05
enableClassification: false
enableContours: false
enableLandmarks: false
enableTracking: false
<!-- detector-config: end -->

<!-- bar-facts: begin -->
minPhotosPerHardCaseCategory: 2
minNoPersonPhotos: 3
<!-- bar-facts: end -->

## Builder confirmation (Ask-First — required before the first scored run)

Confirmed: 2026-09-05 — the builder approved the bar in session
''';

String barWithoutConfirmation() => confirmedBar.replaceFirst(
  RegExp(r'^Confirmed: \d{4}-\d{2}-\d{2}.*$', multiLine: true),
  'Unconfirmed — awaiting the builder',
);

String barWithBlockSwapped(String begin, String end, String replacement) {
  final start = confirmedBar.indexOf(begin);
  final stop = confirmedBar.indexOf(end) + end.length;
  return confirmedBar.substring(0, start) +
      replacement +
      confirmedBar.substring(stop);
}

void main() {
  test('an unconfirmed bar refuses the run', () {
    expect(
      () => probe.parseBarConfirmation(barWithoutConfirmation()),
      throwsStateError,
    );
  });

  test('a confirmed bar yields its dated marker', () {
    expect(probe.parseBarConfirmation(confirmedBar), '2026-09-05');
  });

  test('an implausible date in the marker refuses the run', () {
    final implausible = confirmedBar.replaceFirst(
      'Confirmed: 2026-09-05',
      'Confirmed: 2026-13-40',
    );
    expect(() => probe.parseBarConfirmation(implausible), throwsStateError);
  });

  test('a missing detector-config block refuses the run', () {
    expect(
      () => probe.parseDetectorOptions(
        barWithBlockSwapped(
          probe.detectorConfigBegin,
          probe.detectorConfigEnd,
          '',
        ),
      ),
      throwsStateError,
    );
  });

  test('a detector-config block missing one key refuses the run', () {
    final shortBlock = barWithBlockSwapped(
      probe.detectorConfigBegin,
      probe.detectorConfigEnd,
      '${probe.detectorConfigBegin}\nperformanceMode: accurate\n'
      '${probe.detectorConfigEnd}',
    );
    expect(() => probe.parseDetectorOptions(shortBlock), throwsStateError);
  });

  test('an unknown performance mode refuses the run', () {
    final badMode = confirmedBar.replaceFirst(
      'performanceMode: accurate',
      'performanceMode: thorough',
    );
    expect(() => probe.parseDetectorOptions(badMode), throwsStateError);
  });

  test('a non-numeric minFaceSize refuses the run', () {
    final badSize = confirmedBar.replaceFirst(
      'minFaceSize: 0.05',
      'minFaceSize: tiny',
    );
    expect(() => probe.parseDetectorOptions(badSize), throwsStateError);
  });

  test('the pinned configuration parses into the exact options', () {
    final options = probe.parseDetectorOptions(confirmedBar);
    expect(options.performanceMode, FaceDetectorMode.accurate);
    expect(options.minFaceSize, 0.05);
    expect(options.enableClassification, isFalse);
    expect(options.enableContours, isFalse);
    expect(options.enableLandmarks, isFalse);
    expect(options.enableTracking, isFalse);
  });

  test('a missing bar-facts block refuses the run', () {
    expect(
      () => probe.parseBarFloors(
        barWithBlockSwapped(probe.barFactsBegin, probe.barFactsEnd, ''),
      ),
      throwsStateError,
    );
  });

  test('the corpus floors parse from the bar', () {
    final floors = probe.parseBarFloors(confirmedBar);
    expect(floors.perHardCaseCategory, 2);
    expect(floors.noPerson, 3);
  });

  test('a corpus directory without a manifest refuses the run', () {
    final empty = Directory.systemTemp.createTempSync('facegate');
    addTearDown(() => empty.deleteSync(recursive: true));
    expect(
      () => probe.loadCorpus(
        empty,
        const probe.BarFloors(perHardCaseCategory: 1, noPerson: 1),
      ),
      throwsStateError,
    );
  });

  test('a manifest below the floor refuses the run', () {
    final base = Directory.systemTemp.createTempSync('facegate');
    addTearDown(() => base.deleteSync(recursive: true));
    final photos = Directory('${base.path}/corpus/photos')
      ..createSync(recursive: true);
    final rows = [
      for (final entry in [
        ['p-1', 'person', 'profile'],
        ['p-2', 'person', 'distance'],
        ['n-1', 'no-person', ''],
      ])
        {
          'id': entry[0],
          'filename': '${entry[0]}.jpg',
          'class': entry[1],
          if (entry[2].isNotEmpty) 'categories': [entry[2]],
        },
    ];
    for (final row in rows) {
      File('${photos.path}/${row['filename']}').writeAsStringSync('bytes');
    }
    File('${base.path}/corpus/manifest.json')
        .writeAsStringSync('{"photos": ${jsonEncode(rows)}}');
    expect(
      () => probe.loadCorpus(
        base,
        const probe.BarFloors(perHardCaseCategory: 2, noPerson: 3),
      ),
      throwsStateError,
    );
  });

  test('a manifest at the floor loads with its ground truth intact', () {
    final base = Directory.systemTemp.createTempSync('facegate');
    addTearDown(() => base.deleteSync(recursive: true));
    final photos = Directory('${base.path}/corpus/photos')
      ..createSync(recursive: true);
    final rows = [
      {
        'id': 'p-1',
        'filename': 'p-1.jpg',
        'class': 'person',
        'categories': ['profile', 'low-light'],
      },
      {
        'id': 'p-2',
        'filename': 'p-2.jpg',
        'class': 'person',
        'categories': ['profile', 'distance'],
      },
      {
        'id': 'p-3',
        'filename': 'p-3.jpg',
        'class': 'person',
        'categories': ['distance', 'low-light'],
      },
      {
        'id': 'p-4',
        'filename': 'p-4.jpg',
        'class': 'person',
        'categories': ['mirror', 'print-on-wall'],
      },
      {
        'id': 'p-5',
        'filename': 'p-5.jpg',
        'class': 'person',
        'categories': ['mirror', 'partial'],
      },
      {
        'id': 'p-6',
        'filename': 'p-6.jpg',
        'class': 'person',
        'categories': ['print-on-wall', 'partial'],
      },
      {'id': 'n-1', 'filename': 'n-1.jpg', 'class': 'no-person'},
      {'id': 'n-2', 'filename': 'n-2.jpg', 'class': 'no-person'},
      {'id': 'n-3', 'filename': 'n-3.jpg', 'class': 'no-person'},
    ];
    for (final row in rows) {
      File('${photos.path}/${row['filename']}').writeAsStringSync('bytes');
    }
    File('${base.path}/corpus/manifest.json')
        .writeAsStringSync('{"photos": ${jsonEncode(rows)}}');
    final loaded = probe.loadCorpus(
      base,
      const probe.BarFloors(perHardCaseCategory: 2, noPerson: 3),
    );
    expect(loaded, hasLength(9));
    expect(loaded.where((photo) => photo.isPerson), hasLength(6));
    final mirror = loaded.singleWhere((photo) => photo.id == 'p-4');
    expect(mirror.categories, {'mirror', 'print-on-wall'});
    final noPerson = loaded.singleWhere((photo) => photo.id == 'n-1');
    expect(noPerson.categories, isEmpty);
  });

  test('a no-person row carrying categories refuses the run', () {
    final base = Directory.systemTemp.createTempSync('facegate');
    addTearDown(() => base.deleteSync(recursive: true));
    final photos = Directory('${base.path}/corpus/photos')
      ..createSync(recursive: true);
    File('${photos.path}/bad.jpg').writeAsStringSync('bytes');
    File('${base.path}/corpus/manifest.json').writeAsStringSync(
      '{"photos": [{"id": "bad", "filename": "bad.jpg", "class": '
      '"no-person", "categories": ["profile"]}]}',
    );
    expect(
      () => probe.loadCorpus(
        base,
        const probe.BarFloors(perHardCaseCategory: 1, noPerson: 1),
      ),
      throwsStateError,
    );
  });

  test('a manifest naming a missing photo file refuses the run', () {
    final base = Directory.systemTemp.createTempSync('facegate');
    addTearDown(() => base.deleteSync(recursive: true));
    Directory('${base.path}/corpus/photos').createSync(recursive: true);
    File('${base.path}/corpus/manifest.json').writeAsStringSync(
      '{"photos": [{"id": "ghost", "filename": "ghost.jpg", "class": '
      '"person", "categories": ["profile"]}]}',
    );
    expect(
      () => probe.loadCorpus(
        base,
        const probe.BarFloors(perHardCaseCategory: 1, noPerson: 0),
      ),
      throwsStateError,
    );
  });

  test('run numbering lands one past the highest existing run', () {
    final base = Directory.systemTemp.createTempSync('facegate');
    addTearDown(() => base.deleteSync(recursive: true));
    expect(probe.nextRunNumber(base), 1);
    base.createSync(recursive: true);
    File('${base.path}/run-1.json').writeAsStringSync('{}');
    File('${base.path}/run-2.json').writeAsStringSync('{}');
    File('${base.path}/notes.txt').writeAsStringSync('not a run');
    expect(probe.nextRunNumber(base), 3);
  });
}

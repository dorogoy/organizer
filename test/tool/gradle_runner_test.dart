import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../tool/gradle_runner.dart';

Directory _makeAndroid(String label) {
  final root = Directory.systemTemp.createTempSync('gradle_runner_$label');
  addTearDown(() => root.deleteSync(recursive: true));
  final android = Directory('${root.path}/android')..createSync();
  File('${android.path}/local.properties')
      .writeAsStringSync('flutter.sdk=/sdk/flutter\n');
  return android;
}

void _writeWrapper(Directory android, String body) {
  final wrapper = File('${android.path}/gradlew')
    ..writeAsStringSync('#!/bin/sh\n$body\n');
  final chmod = Process.runSync('chmod', ['u+x', wrapper.path]);
  expect(chmod.exitCode, 0, reason: chmod.stderr);
}

void main() {
  test('missing wrapper is an actionable StateError', () async {
    final android = Directory.systemTemp.createTempSync(
      'gradle_runner_wrapper',
    );
    addTearDown(() => android.deleteSync(recursive: true));
    await expectLater(
      runGradle(androidDir: android.path, args: const []),
      throwsA(
        isA<StateError>().having(
          (error) => error.message,
          'message',
          contains('make deps'),
        ),
      ),
    );
  });

  test('missing flutter.sdk is an actionable StateError', () async {
    final root = Directory.systemTemp.createTempSync('gradle_runner_props');
    addTearDown(() => root.deleteSync(recursive: true));
    final android = Directory('${root.path}/android')..createSync();
    File('${android.path}/gradlew').writeAsStringSync('#!/bin/sh\nexit 0\n');
    await expectLater(
      runGradle(androidDir: android.path, args: const []),
      throwsA(
        isA<StateError>().having(
          (error) => error.message,
          'message',
          contains('flutter.sdk'),
        ),
      ),
    );
  });

  test('a non-zero Gradle exit is surfaced with stderr and its code', () async {
    final android = _makeAndroid('failure');
    _writeWrapper(android, "printf 'wrapper failed\n' >&2\nexit 7");
    await expectLater(
      runGradle(androidDir: android.path, args: const [':app:dependencies']),
      throwsA(
        isA<StateError>().having(
          (error) => error.message,
          'message',
          allOf(contains('exit 7'), contains('wrapper failed')),
        ),
      ),
    );
  });

  test('a successful wrapper returns stdout', () async {
    final android = _makeAndroid('success');
    _writeWrapper(android, "printf 'resolved graph\\n'");
    expect(
      await runGradle(androidDir: android.path, args: const []),
      'resolved graph\n',
    );
  });

  test('a stalled wrapper is killed and surfaced as exit 2 input', () async {
    final android = _makeAndroid('timeout');
    _writeWrapper(android, 'while :; do :; done');
    await expectLater(
      runGradle(
        androidDir: android.path,
        args: const [],
        timeout: const Duration(milliseconds: 20),
      ),
      throwsA(
        isA<StateError>().having(
          (error) => error.message,
          'message',
          contains('exceeded'),
        ),
      ),
    );
  });
}

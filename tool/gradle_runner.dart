// ignore_for_file: avoid_print
//
// The shared Gradle runner for the two Gradle-backed egress seals
// (story 4-2: resolved-graph allowlist, merged-manifest enumeration).
// Both checks drive the bootstrap-injected gradle wrapper directly; the
// error contract they share lives here: every environment failure —
// missing or unexecutable wrapper, missing android/local.properties
// (Gradle cannot configure without flutter.sdk), a stalled download, a
// non-zero Gradle exit — surfaces as one StateError with an actionable
// message, which the checks turn into exit 2. A generous timeout keeps
// a wedged first-run distribution download from hanging `make check`.
import 'dart:async';
import 'dart:io';

/// The maximum a Gradle invocation may take: the first run on a cold
/// machine downloads the pinned distribution, which is slow but not
/// unbounded.
const Duration gradleTimeout = Duration(minutes: 15);

/// Runs `./gradlew [args]` inside [androidDir]. Returns stdout.
///
/// Throws [StateError] with the exact remedy when the environment
/// cannot run: wrapper missing (make deps injects it),
/// local.properties missing its flutter.sdk (flutter pub get writes
/// it — verified 2026-09-03), the JVM cannot start, Gradle exits
/// non-zero, or the run exceeds [gradleTimeout] (the process is
/// killed).
Future<String> runGradle({
  required String androidDir,
  required List<String> args,
  Duration timeout = gradleTimeout,
}) async {
  final wrapper = File('$androidDir/gradlew');
  if (!wrapper.existsSync()) {
    throw StateError(
      'android/gradlew not found — run make deps once: tool/bootstrap.sh '
      'injects the wrapper from the pinned Flutter SDK (story 4-2)',
    );
  }
  final localProperties = File('$androidDir/local.properties');
  if (!localProperties.existsSync() ||
      !localProperties.readAsStringSync().contains('flutter.sdk=')) {
    throw StateError(
      'android/local.properties is missing its flutter.sdk entry — Gradle '
      'cannot configure. Run make deps (or flutter pub get) once; the '
      'Flutter tool writes the file (verified 2026-09-03)',
    );
  }
  final Process process;
  try {
    process = await Process.start(
      './gradlew',
      args,
      workingDirectory: androidDir,
    );
  } on ProcessException catch (error) {
    throw StateError(
      'could not start android/gradlew $args (${error.message}) — likely '
      'causes: the wrapper is not executable, or the JVM / ANDROID_HOME '
      'the devbox shell provides is absent. Run make deps once, inside '
      'devbox',
    );
  }
  final stdoutSink = StringBuffer();
  final stderrSink = StringBuffer();
  final drains = <Future<dynamic>>[
    process.stdout
        .transform(systemEncoding.decoder)
        .listen(stdoutSink.write)
        .asFuture(),
    process.stderr
        .transform(systemEncoding.decoder)
        .listen(stderrSink.write)
        .asFuture(),
  ];
  try {
    final exitCode = await process.exitCode.timeout(timeout);
    await Future.wait(drains);
    if (exitCode != 0) {
      throw StateError(
        'gradlew ${args.join(' ')} failed (exit $exitCode):\n'
        '${_tail(stderrSink.toString())}',
      );
    }
    return stdoutSink.toString();
  } on TimeoutException {
    process.kill();
    throw StateError(
      'gradlew ${args.join(' ')} exceeded ${timeout.inMinutes} '
      'minutes — likely a stalled distribution download; re-run (the '
      'partial download is discarded)',
    );
  }
}

/// The last ~30 lines, so failures name the cause without burying it.
String _tail(String text) {
  final lines = text.split('\n');
  return lines.length <= 30
      ? text
      : '…\n${lines.sublist(lines.length - 30).join('\n')}';
}

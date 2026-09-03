// ignore_for_file: avoid_print
//
// The egress seal, second of three (AD-7, story 4.2): the resolved
// Gradle runtime classpath of all three variants is compared against a
// frozen in-code allowlist. This is the check that catches a network
// SDK arriving as a native dependency — a path invisible to the Dart
// import sweep, because pub plugins embed their Gradle artifacts
// transitively and no `dependencies {}` block exists in our own build
// files to read instead.
//
// The allowlist is in code (not a data file) on the store seal's
// precedent. Maven entries carry their full version — including the
// engine-hash io.flutter artifacts — while project/file entries retain
// their exact non-coordinate label. Every drift, even a Flutter patch
// bump, is a visible, deliberate re-freeze rather than silent acceptance.
// Drift fails with the exact additions and removals and the re-freeze
// instruction:
//
//   dart run tool/check_gradle_dependencies.dart --re-freeze
//
// (prints the new literal; paste it over `gradleDependencyAllowlist`).
//
// The check drives the bootstrap-injected gradle wrapper itself, so it
// needs no prior `flutter build` (first run downloads the pinned 9.3.1
// distribution — accepted once per machine/CI runner).
//
// Output contract (the tool checks' own): one finding line per
// addition or removal, exit 1 on drift, exit 2 when the environment
// cannot run (missing wrapper, Gradle failure).
import 'dart:convert';
import 'dart:io';

import 'check_core_purity.dart';
import 'gradle_runner.dart';

/// The runtime classpath configurations frozen per variant.
const List<String> frozenConfigurations = [
  'debugRuntimeClasspath',
  'releaseRuntimeClasspath',
  'profileRuntimeClasspath',
];

/// The frozen allowlist: configuration -> every resolved graph entry the
/// classpath held at freeze time. Maven coordinates are stored verbatim;
/// non-coordinate nodes (for example a project or local AAR) carry the
/// `non-coordinate:` prefix. Re-freeze with
/// `dart run tool/check_gradle_dependencies.dart --re-freeze` — drift
/// is a deliberate act or it is a failure (AD-7).
// Frozen AD-7 egress allowlist (seal 2 re-freeze output).
// Flutter: 3.47.2; configurations: debugRuntimeClasspath, releaseRuntimeClasspath, profileRuntimeClasspath;
// generated 2026-09-02T22:52:25.706987Z by `dart run tool/check_gradle_dependencies.dart --re-freeze`.
// Every drift against this list — including the engine-hash io.flutter coordinates a
// Flutter patch bump changes — is a visible, deliberate re-freeze or a failure.
const Map<String, Set<String>> gradleDependencyAllowlist = {
  'debugRuntimeClasspath': {
    'androidx.activity:activity:1.8.1',
    'androidx.annotation:annotation-experimental:1.4.0',
    'androidx.annotation:annotation-jvm:1.8.1',
    'androidx.annotation:annotation:1.8.1',
    'androidx.arch.core:core-common:2.2.0',
    'androidx.arch.core:core-runtime:2.2.0',
    'androidx.collection:collection:1.1.0',
    'androidx.concurrent:concurrent-futures:1.1.0',
    'androidx.core:core-ktx:1.13.1',
    'androidx.core:core:1.13.1',
    'androidx.customview:customview:1.0.0',
    'androidx.exifinterface:exifinterface:1.4.1',
    'androidx.fragment:fragment:1.7.1',
    'androidx.interpolator:interpolator:1.0.0',
    'androidx.lifecycle:lifecycle-common-java8:2.7.0',
    'androidx.lifecycle:lifecycle-common:2.7.0',
    'androidx.lifecycle:lifecycle-livedata-core-ktx:2.7.0',
    'androidx.lifecycle:lifecycle-livedata-core:2.7.0',
    'androidx.lifecycle:lifecycle-livedata:2.7.0',
    'androidx.lifecycle:lifecycle-process:2.7.0',
    'androidx.lifecycle:lifecycle-runtime:2.7.0',
    'androidx.lifecycle:lifecycle-viewmodel-savedstate:2.7.0',
    'androidx.lifecycle:lifecycle-viewmodel:2.7.0',
    'androidx.loader:loader:1.0.0',
    'androidx.profileinstaller:profileinstaller:1.3.1',
    'androidx.savedstate:savedstate:1.2.1',
    'androidx.startup:startup-runtime:1.1.1',
    'androidx.tracing:tracing:1.2.0',
    'androidx.versionedparcelable:versionedparcelable:1.1.1',
    'androidx.viewpager:viewpager:1.0.0',
    'androidx.window.extensions.core:core:1.0.0',
    'androidx.window:window-java:1.2.0',
    'androidx.window:window:1.2.0',
    'com.getkeepsafe.relinker:relinker:1.4.5',
    'com.google.guava:listenablefuture:1.0',
    'io.flutter:arm64_v8a_debug:1.0.0-a804b261645ef8c13eb3d5c44a5c2fb0340c5539',
    'io.flutter:armeabi_v7a_debug:1.0.0-a804b261645ef8c13eb3d5c44a5c2fb0340c5539',
    'io.flutter:flutter_embedding_debug:1.0.0-a804b261645ef8c13eb3d5c44a5c2fb0340c5539',
    'io.flutter:x86_64_debug:1.0.0-a804b261645ef8c13eb3d5c44a5c2fb0340c5539',
    'non-coordinate:project :jni',
    'non-coordinate:project :jni_flutter',
    'org.jetbrains.kotlin:kotlin-stdlib-common:2.4.0',
    'org.jetbrains.kotlin:kotlin-stdlib-jdk7:1.8.20',
    'org.jetbrains.kotlin:kotlin-stdlib-jdk8:1.8.20',
    'org.jetbrains.kotlin:kotlin-stdlib:2.4.0',
    'org.jetbrains.kotlinx:kotlinx-coroutines-android:1.7.1',
    'org.jetbrains.kotlinx:kotlinx-coroutines-bom:1.7.1',
    'org.jetbrains.kotlinx:kotlinx-coroutines-core-jvm:1.7.1',
    'org.jetbrains.kotlinx:kotlinx-coroutines-core:1.7.1',
    'org.jetbrains:annotations:23.0.0',
    'org.jspecify:jspecify:1.0.0',
  },
  'releaseRuntimeClasspath': {
    'androidx.activity:activity:1.8.1',
    'androidx.annotation:annotation-experimental:1.4.0',
    'androidx.annotation:annotation-jvm:1.8.1',
    'androidx.annotation:annotation:1.8.1',
    'androidx.arch.core:core-common:2.2.0',
    'androidx.arch.core:core-runtime:2.2.0',
    'androidx.collection:collection:1.1.0',
    'androidx.concurrent:concurrent-futures:1.1.0',
    'androidx.core:core-ktx:1.13.1',
    'androidx.core:core:1.13.1',
    'androidx.customview:customview:1.0.0',
    'androidx.exifinterface:exifinterface:1.4.1',
    'androidx.fragment:fragment:1.7.1',
    'androidx.interpolator:interpolator:1.0.0',
    'androidx.lifecycle:lifecycle-common-java8:2.7.0',
    'androidx.lifecycle:lifecycle-common:2.7.0',
    'androidx.lifecycle:lifecycle-livedata-core-ktx:2.7.0',
    'androidx.lifecycle:lifecycle-livedata-core:2.7.0',
    'androidx.lifecycle:lifecycle-livedata:2.7.0',
    'androidx.lifecycle:lifecycle-process:2.7.0',
    'androidx.lifecycle:lifecycle-runtime:2.7.0',
    'androidx.lifecycle:lifecycle-viewmodel-savedstate:2.7.0',
    'androidx.lifecycle:lifecycle-viewmodel:2.7.0',
    'androidx.loader:loader:1.0.0',
    'androidx.profileinstaller:profileinstaller:1.3.1',
    'androidx.savedstate:savedstate:1.2.1',
    'androidx.startup:startup-runtime:1.1.1',
    'androidx.tracing:tracing:1.2.0',
    'androidx.versionedparcelable:versionedparcelable:1.1.1',
    'androidx.viewpager:viewpager:1.0.0',
    'androidx.window.extensions.core:core:1.0.0',
    'androidx.window:window-java:1.2.0',
    'androidx.window:window:1.2.0',
    'com.getkeepsafe.relinker:relinker:1.4.5',
    'com.google.guava:listenablefuture:1.0',
    'io.flutter:arm64_v8a_release:1.0.0-a804b261645ef8c13eb3d5c44a5c2fb0340c5539',
    'io.flutter:armeabi_v7a_release:1.0.0-a804b261645ef8c13eb3d5c44a5c2fb0340c5539',
    'io.flutter:flutter_embedding_release:1.0.0-a804b261645ef8c13eb3d5c44a5c2fb0340c5539',
    'io.flutter:x86_64_release:1.0.0-a804b261645ef8c13eb3d5c44a5c2fb0340c5539',
    'non-coordinate:project :jni',
    'non-coordinate:project :jni_flutter',
    'org.jetbrains.kotlin:kotlin-stdlib-common:2.4.0',
    'org.jetbrains.kotlin:kotlin-stdlib-jdk7:1.8.20',
    'org.jetbrains.kotlin:kotlin-stdlib-jdk8:1.8.20',
    'org.jetbrains.kotlin:kotlin-stdlib:2.4.0',
    'org.jetbrains.kotlinx:kotlinx-coroutines-android:1.7.1',
    'org.jetbrains.kotlinx:kotlinx-coroutines-bom:1.7.1',
    'org.jetbrains.kotlinx:kotlinx-coroutines-core-jvm:1.7.1',
    'org.jetbrains.kotlinx:kotlinx-coroutines-core:1.7.1',
    'org.jetbrains:annotations:23.0.0',
    'org.jspecify:jspecify:1.0.0',
  },
  'profileRuntimeClasspath': {
    'androidx.activity:activity:1.8.1',
    'androidx.annotation:annotation-experimental:1.4.0',
    'androidx.annotation:annotation-jvm:1.8.1',
    'androidx.annotation:annotation:1.8.1',
    'androidx.arch.core:core-common:2.2.0',
    'androidx.arch.core:core-runtime:2.2.0',
    'androidx.collection:collection:1.1.0',
    'androidx.concurrent:concurrent-futures:1.1.0',
    'androidx.core:core-ktx:1.13.1',
    'androidx.core:core:1.13.1',
    'androidx.customview:customview:1.0.0',
    'androidx.exifinterface:exifinterface:1.4.1',
    'androidx.fragment:fragment:1.7.1',
    'androidx.interpolator:interpolator:1.0.0',
    'androidx.lifecycle:lifecycle-common-java8:2.7.0',
    'androidx.lifecycle:lifecycle-common:2.7.0',
    'androidx.lifecycle:lifecycle-livedata-core-ktx:2.7.0',
    'androidx.lifecycle:lifecycle-livedata-core:2.7.0',
    'androidx.lifecycle:lifecycle-livedata:2.7.0',
    'androidx.lifecycle:lifecycle-process:2.7.0',
    'androidx.lifecycle:lifecycle-runtime:2.7.0',
    'androidx.lifecycle:lifecycle-viewmodel-savedstate:2.7.0',
    'androidx.lifecycle:lifecycle-viewmodel:2.7.0',
    'androidx.loader:loader:1.0.0',
    'androidx.profileinstaller:profileinstaller:1.3.1',
    'androidx.savedstate:savedstate:1.2.1',
    'androidx.startup:startup-runtime:1.1.1',
    'androidx.tracing:tracing:1.2.0',
    'androidx.versionedparcelable:versionedparcelable:1.1.1',
    'androidx.viewpager:viewpager:1.0.0',
    'androidx.window.extensions.core:core:1.0.0',
    'androidx.window:window-java:1.2.0',
    'androidx.window:window:1.2.0',
    'com.getkeepsafe.relinker:relinker:1.4.5',
    'com.google.guava:listenablefuture:1.0',
    'io.flutter:arm64_v8a_profile:1.0.0-a804b261645ef8c13eb3d5c44a5c2fb0340c5539',
    'io.flutter:armeabi_v7a_profile:1.0.0-a804b261645ef8c13eb3d5c44a5c2fb0340c5539',
    'io.flutter:flutter_embedding_profile:1.0.0-a804b261645ef8c13eb3d5c44a5c2fb0340c5539',
    'io.flutter:x86_64_profile:1.0.0-a804b261645ef8c13eb3d5c44a5c2fb0340c5539',
    'non-coordinate:project :jni',
    'non-coordinate:project :jni_flutter',
    'org.jetbrains.kotlin:kotlin-stdlib-common:2.4.0',
    'org.jetbrains.kotlin:kotlin-stdlib-jdk7:1.8.20',
    'org.jetbrains.kotlin:kotlin-stdlib-jdk8:1.8.20',
    'org.jetbrains.kotlin:kotlin-stdlib:2.4.0',
    'org.jetbrains.kotlinx:kotlinx-coroutines-android:1.7.1',
    'org.jetbrains.kotlinx:kotlinx-coroutines-bom:1.7.1',
    'org.jetbrains.kotlinx:kotlinx-coroutines-core-jvm:1.7.1',
    'org.jetbrains.kotlinx:kotlinx-coroutines-core:1.7.1',
    'org.jetbrains:annotations:23.0.0',
    'org.jspecify:jspecify:1.0.0',
  },
};

/// A dependency-tree entry line: pipes/spaces then `+--- ` or
/// `\--- `. The configuration header (`--- debugRuntimeClasspath - …`)
/// has no branch marker and does not match.
final RegExp _treeEntryRegExp = RegExp(r'^[| ]*[+\\]--- +(.*)$');

/// One Maven `group:artifact:version` token. A resolved Maven version may
/// contain `+` and other non-space, non-marker characters, so do not narrow
/// the version to the common dotted form.
final RegExp _coordinateRegExp = RegExp(
  r'[A-Za-z0-9._-]+:[A-Za-z0-9._-]+:[^\s()]+',
);

const String _nonCoordinatePrefix = 'non-coordinate:';

final RegExp _nonCoordinateEntryRegExp = RegExp(
  r'^(?:project\b|file\b|fileTree\b)',
);

/// Gradle report markers stripped before parsing: `(n)` not resolved,
/// `(*)` previously displayed, `(c)` conflict-resolved, `(b)` cycle
/// break.
final RegExp _markerRegExp = RegExp(r'\s*\((?:n|\*|c|b)\)');

/// Parses one `gradlew :app:dependencies --configuration …` report
/// into its set of resolved graph entries. Version
/// conflicts (`g:a:1.0 -> 2.0`) contribute the resolved coordinate —
/// the pre-arrow `group:artifact` combined with the post-arrow
/// version, so a conflict line never silently drops out of the set; a
/// post-arrow full coordinate (`g:a:1.0 -> other:b:2.0`, a
/// substitution) stands on its own. Entries without Maven coordinates are
/// retained with the [non-coordinate] prefix so a local project or file
/// dependency cannot enter the runtime graph silently.
Set<String> parseResolvedDependencies(String gradleOutput) {
  final coordinates = <String>{};
  for (final line in gradleOutput.split('\n')) {
    final entry = _treeEntryRegExp.firstMatch(line);
    if (entry == null) {
      continue;
    }
    final text = entry.group(1)!.replaceAll(_markerRegExp, '');
    final trimmed = text.trim();
    if (_nonCoordinateEntryRegExp.hasMatch(trimmed)) {
      coordinates.add('$_nonCoordinatePrefix$trimmed');
      continue;
    }
    final arrow = text.lastIndexOf(' -> ');
    if (arrow < 0) {
      final matches = _coordinateRegExp.allMatches(text).toList();
      if (matches.isEmpty) {
        if (text.trim().isNotEmpty) {
          coordinates.add('$_nonCoordinatePrefix${text.trim()}');
        }
      } else {
        coordinates.addAll(matches.map((match) => match.group(0)!));
      }
      continue;
    }
    final pre = text.substring(0, arrow);
    final post = text.substring(arrow + 4).trim();
    final postCoordinates = _coordinateRegExp
        .allMatches(post)
        .map((match) => match.group(0)!);
    if (postCoordinates.isNotEmpty) {
      coordinates.addAll(postCoordinates);
      continue;
    }
    final preMatches = _coordinateRegExp.allMatches(pre).toList();
    if (preMatches.isEmpty) {
      if (text.trim().isNotEmpty) {
        coordinates.add('$_nonCoordinatePrefix${text.trim()}');
      }
      continue;
    }
    final preParts = preMatches.last.group(0)!.split(':')..removeLast();
    if (post.isEmpty) {
      coordinates.add(preMatches.last.group(0)!);
    } else if (RegExp(r'^[^\s()]+$').hasMatch(post)) {
      coordinates.add('${preParts.join(':')}:$post');
    } else {
      coordinates.add('$_nonCoordinatePrefix${text.trim()}');
    }
  }
  return coordinates;
}

/// Compares a resolved set against its frozen set; one finding per
/// addition and per removal, plus the re-freeze instruction.
List<Finding> compareDependencies({
  required String configuration,
  required Set<String> resolved,
  required Set<String> frozen,
}) {
  final findings = <Finding>[];
  for (final addition in resolved.difference(frozen).toList()..sort()) {
    findings.add(
      Finding(
        'tool/check_gradle_dependencies.dart',
        1,
        "resolved graph drift in $configuration: '$addition' is in the "
            'resolved graph but not the frozen allowlist (AD-7 — a new '
            'native dependency is a deliberate re-freeze or a failure)',
      ),
    );
  }
  for (final removal in frozen.difference(resolved).toList()..sort()) {
    findings.add(
      Finding(
        'tool/check_gradle_dependencies.dart',
        1,
        "resolved graph drift in $configuration: '$removal' is in the "
            'frozen allowlist but not the resolved graph',
      ),
    );
  }
  return findings;
}

/// Renders a resolved map as the Dart literal to paste over
/// `gradleDependencyAllowlist` (the `--re-freeze` output), under a
/// provenance header — the pinned Flutter version, the frozen
/// configurations and the generation date — so a re-frozen literal is
/// reviewable as a deliberate act.
String renderAllowlistLiteral(
  Map<String, Set<String>> resolved, {
  String root = '',
}) {
  final buffer = StringBuffer();
  buffer.write('// Frozen AD-7 egress allowlist (seal 2 re-freeze output).\n');
  buffer.write(
    '// Flutter: ${pinnedFlutterVersion(root)}; configurations: '
    '${frozenConfigurations.join(', ')};\n'
    '// generated ${DateTime.now().toUtc().toIso8601String()} by '
    '`dart run tool/check_gradle_dependencies.dart --re-freeze`.\n'
    '// Every drift against this list — including the engine-hash '
    'io.flutter coordinates a\n'
    '// Flutter patch bump changes — is a visible, deliberate re-freeze '
    'or a failure.\n',
  );
  buffer.write(
    'const Map<String, Set<String>> '
    'gradleDependencyAllowlist = {\n',
  );
  for (final configuration in frozenConfigurations) {
    buffer.write("  '$configuration': {\n");
    for (final coordinate in (resolved[configuration] ?? {}).toList()..sort()) {
      buffer.write('    ${_dartStringLiteral(coordinate)},\n');
    }
    buffer.write('  },\n');
  }
  buffer.write('};');
  return buffer.toString();
}

String _dartStringLiteral(String value) =>
    "'${value.replaceAll('\\', '\\\\').replaceAll("'", "\\'")}'";

/// The pinned Flutter SDK's own version, read from its cache — the
/// version the frozen graph was resolved against. `unknown` when the
/// cache file is absent (never a failure of the check itself).
String pinnedFlutterVersion(String root) {
  try {
    // [root] is '' or ends with a slash, by the callers' convention.
    final file = File('$root.toolchain/flutter/bin/cache/flutter.version.json');
    if (file.existsSync()) {
      final decoded = jsonDecode(file.readAsStringSync());
      if (decoded is Map<String, dynamic> &&
          decoded['flutterVersion'] is String) {
        return decoded['flutterVersion'] as String;
      }
    }
  } catch (_) {
    // The provenance header degrades to `unknown`, nothing more.
  }
  return 'unknown';
}

/// Resolves every frozen configuration's graph through the
/// bootstrap-injected wrapper (see gradle_runner for the shared error
/// contract: wrapper, local.properties, JVM, timeout, Gradle exit).
/// Throws [StateError] on environment failure — callers turn that into
/// exit 2.
Future<Map<String, Set<String>>> resolveAll(String root) async {
  final resolved = <String, Set<String>>{};
  for (final configuration in frozenConfigurations) {
    final output = await runGradle(
      androidDir: '${root}android',
      args: [
        ':app:dependencies',
        '--configuration',
        configuration,
        '--console=plain',
      ],
    );
    resolved[configuration] = parseResolvedDependencies(output);
  }
  return resolved;
}

/// Runs the whole check against [repoRoot]. Returns the process exit
/// code: 0 clean or frozen, 1 drift, 2 environment failure.
Future<int> runCheck([String repoRoot = '']) async {
  final root = repoRoot.isEmpty ? '' : '$repoRoot/';
  final resolved = await resolveAll(root);
  final findings = <Finding>[];
  for (final configuration in frozenConfigurations) {
    findings.addAll(
      compareDependencies(
        configuration: configuration,
        resolved: resolved[configuration]!,
        frozen: gradleDependencyAllowlist[configuration]!,
      ),
    );
  }
  for (final finding in findings) {
    print(finding);
  }
  if (findings.isNotEmpty) {
    print(
      'gradle dependency check FAILED: ${findings.length} finding(s) — '
      're-freeze deliberately with '
      "'dart run tool/check_gradle_dependencies.dart --re-freeze' (AD-7)",
    );
    return 1;
  }
  final total = frozenConfigurations
      .map((configuration) => resolved[configuration]!.length)
      .reduce((a, b) => a + b);
  print(
    'gradle dependency check passed '
    '(${frozenConfigurations.length} configurations, $total graph entries)',
  );
  return 0;
}

Future<void> main(List<String> args) async {
  if (args.contains('--re-freeze')) {
    final positional = args.where((arg) => arg != '--re-freeze').toList();
    final root = positional.isEmpty ? '' : '${positional.first}/';
    try {
      final resolved = await resolveAll(root);
      print(renderAllowlistLiteral(resolved, root: root));
      return;
    } on StateError catch (error) {
      stderr.writeln(error.message);
      exit(2);
    }
  }
  try {
    exit(await runCheck(args.isEmpty ? '' : args.first));
  } on StateError catch (error) {
    stderr.writeln(error.message);
    exit(2);
  }
}

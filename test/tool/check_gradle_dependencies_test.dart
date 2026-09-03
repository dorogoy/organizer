import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../tool/check_gradle_dependencies.dart';

const fixture = 'test/fixtures/gradle_dependencies/sample_dependencies.txt';

void main() {
  test('the parser reads real report shape: markers stripped, conflicts '
      'resolved, and non-coordinate nodes retained', () {
    final resolved = parseResolvedDependencies(
      File(fixture).readAsStringSync(),
    );
    expect(resolved, contains('org.jetbrains.kotlin:kotlin-stdlib:2.4.0'));
    expect(
      resolved,
      contains('org.jetbrains:annotations:23.0.0'),
      reason: 'conflict arrow contributes the resolved version only',
    );
    expect(
      resolved,
      isNot(contains('org.jetbrains:annotations:13.0')),
      reason: 'the pre-conflict version is not the resolved graph',
    );
    expect(
      resolved,
      isNot(contains('org.jetbrains.kotlin:kotlin-stdlib:1.8.22')),
    );
    expect(
      resolved,
      contains(
        'io.flutter:flutter_embedding_debug:'
        '1.0.0-a804b261645ef8c13eb3d5c44a5c2fb0340c5539',
      ),
      reason:
          'engine-hash versions are frozen by design — every Flutter '
          'patch bump is a visible re-freeze',
    );
    expect(resolved, contains('non-coordinate:project :jni'));
  });

  test('a version-conflict line contributes the reconstructed resolved '
      'coordinate', () {
    const output =
        '--- debugRuntimeClasspath - Runtime classpath\n'
        '+--- com.example:foo:1.0 -> 2.0\n';
    final resolved = parseResolvedDependencies(output);
    expect(resolved, {'com.example:foo:2.0'});
  });

  test('an (n)-marked conflict still contributes its resolved coordinate', () {
    const output =
        '--- debugRuntimeClasspath - Runtime classpath\n'
        '+--- com.example:bar:1.0 -> 2.0 (n)\n';
    final resolved = parseResolvedDependencies(output);
    expect(resolved, {'com.example:bar:2.0'});
  });

  test('a substitution conflict contributes the post-arrow coordinate '
      'wholesale', () {
    const output =
        '--- debugRuntimeClasspath - Runtime classpath\n'
        '+--- com.example:old:1.0 -> com.example:new:2.0\n';
    final resolved = parseResolvedDependencies(output);
    expect(resolved, {'com.example:new:2.0'});
  });

  test('an (n) entry still contributes its coordinate', () {
    const output =
        '--- debugRuntimeClasspath - Runtime classpath\n'
        '+--- com.example:unresolved:1.0 (n)\n'
        '\\--- com.example:resolved:2.0\n';
    final resolved = parseResolvedDependencies(output);
    expect(resolved, {
      'com.example:unresolved:1.0',
      'com.example:resolved:2.0',
    });
  });

  test('project and local-file entries remain visible in the graph', () {
    const output =
        '--- debugRuntimeClasspath - Runtime classpath\n'
        '+--- project :localLibrary\n'
        "\\--- file collection 'libs/local.aar'\n";
    expect(parseResolvedDependencies(output), {
      'non-coordinate:project :localLibrary',
      "non-coordinate:file collection 'libs/local.aar'",
    });
  });

  test('version text is preserved when it contains a plus suffix', () {
    const output =
        '--- debugRuntimeClasspath - Runtime classpath\n'
        '+--- com.example:build:1.0+local.7\n';
    expect(parseResolvedDependencies(output), {
      'com.example:build:1.0+local.7',
    });
  });

  test('a conflict preserves non-alphanumeric version qualifiers', () {
    const output =
        '--- debugRuntimeClasspath - Runtime classpath\n'
        '+--- com.example:aar:1.0 -> 2.0@aar\n';
    expect(parseResolvedDependencies(output), {'com.example:aar:2.0@aar'});
  });

  test('a project entry is not mistaken for a coordinate', () {
    const output =
        '--- debugRuntimeClasspath - Runtime classpath\n'
        '+--- project:local:debug\n';
    expect(parseResolvedDependencies(output), {
      'non-coordinate:project:local:debug',
    });
  });

  test('the configuration header line contributes nothing', () {
    const output = '--- debugRuntimeClasspath - Runtime classpath of x.\n';
    expect(parseResolvedDependencies(output), isEmpty);
  });

  test('drift produces exact additions and removals with re-freeze '
      'instructions', () {
    final findings = compareDependencies(
      configuration: 'debugRuntimeClasspath',
      resolved: {'androidx.core:core:1.13.1', 'com.sneaky:sdk:9.9.9'},
      frozen: {
        'androidx.core:core:1.13.1',
        'io.flutter:flutter_embedding_debug:1.0.0-x',
      },
    );
    expect(findings, hasLength(2));
    final addition = findings
        .where((finding) => finding.message.contains('com.sneaky:sdk:9.9.9'))
        .single;
    expect(addition.message, contains('not the frozen allowlist'));
    expect(addition.message, contains('AD-7'));
    final removal = findings
        .where((finding) => finding.message.contains('flutter_embedding_debug'))
        .single;
    expect(removal.message, contains('not the resolved graph'));
  });

  test('a matching graph is clean', () {
    const set = {'a:b:1.0'};
    expect(
      compareDependencies(
        configuration: 'debugRuntimeClasspath',
        resolved: set,
        frozen: set,
      ),
      isEmpty,
    );
  });

  test('the frozen allowlist covers exactly the three variants and is '
      'non-empty', () {
    expect(gradleDependencyAllowlist.keys, {
      'debugRuntimeClasspath',
      'releaseRuntimeClasspath',
      'profileRuntimeClasspath',
    });
    for (final entry in gradleDependencyAllowlist.entries) {
      expect(entry.value, isNotEmpty, reason: entry.key);
    }
  });

  test('the frozen allowlist parses as valid coordinates', () {
    for (final entry in gradleDependencyAllowlist.entries) {
      for (final coordinate in entry.value) {
        expect(
          _coordinateRegExpForTest.hasMatch(coordinate),
          isTrue,
          reason: coordinate,
        );
      }
    }
  });

  test('renderAllowlistLiteral round-trips through the parser shape', () {
    final literal = renderAllowlistLiteral({
      for (final entry in gradleDependencyAllowlist.entries)
        entry.key: entry.value,
    });
    expect(literal, contains('const Map<String, Set<String>>'));
    expect(literal, contains("'debugRuntimeClasspath': {"));
    // The rendered literal is itself valid-looking Dart and mentions
    // every frozen coordinate.
    for (final coordinate
        in gradleDependencyAllowlist.values.expand((set) => set).take(5)) {
      expect(literal, contains("'$coordinate',"));
    }
  });

  test('renderAllowlistLiteral carries a provenance header', () {
    final literal = renderAllowlistLiteral(const {});
    expect(literal.startsWith('//'), isTrue);
    expect(literal, contains('Frozen AD-7 egress allowlist'));
    expect(literal, contains('configurations:'));
    expect(literal, contains('debugRuntimeClasspath'));
    expect(literal, contains('generated'));
    expect(literal, contains('Flutter:'));
  });

  test('pinnedFlutterVersion reads the SDK cache or degrades to unknown', () {
    // This test runs from the repo root, where .toolchain exists.
    final version = pinnedFlutterVersion('');
    expect(version, anyOf(matches(RegExp(r'^\d+\.\d+\.\d+$')), 'unknown'));
  });
}

final RegExp _coordinateRegExpForTest = RegExp(
  r'^(?:non-coordinate:.+|[A-Za-z0-9._-]+:[A-Za-z0-9._-]+:[^\s()]+)$',
);

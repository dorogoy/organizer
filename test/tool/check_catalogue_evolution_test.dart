import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../tool/check_catalogue_evolution.dart';

const validRecord = '''
# Catalogue Evolution Record

Approval: Catalogue owner, change request CAT-42

## Changes

1. Add one reviewed catalogue entry.
''';

void _git(Directory root, List<String> arguments) {
  final result = Process.runSync('git', arguments, workingDirectory: root.path);
  if (result.exitCode != 0) {
    throw StateError('git ${arguments.join(' ')} failed: ${result.stderr}');
  }
}

void main() {
  test('one protected input does not require an evolution record', () {
    expect(
      requiresEvolutionRecord(['assets/evergreen/catalogue.json']),
      isFalse,
    );
  });

  test('coordinated protected inputs require a reviewed record', () {
    expect(
      requiresEvolutionRecord([
        'assets/evergreen/catalogue.json',
        'tool/catalogue_baseline.json',
      ]),
      isTrue,
    );
  });

  test('empty or unrelated records cannot satisfy the guard', () {
    const changed = [
      'assets/evergreen/catalogue.json',
      'test/fixtures/catalogue/a12_v1_manifest.json',
      'catalogue-evolution/notes.md',
    ];
    expect(
      requiresEvolutionRecord(
        changed,
        recordContents: const {
          'catalogue-evolution/notes.md': '# Notes\n\nNothing approved.',
        },
      ),
      isTrue,
    );
    expect(
      requiresEvolutionRecord(
        changed,
        recordContents: const {
          'catalogue-evolution/notes.md':
              '# Catalogue Evolution Record\n\nApproval: \n\n## Changes\n',
        },
      ),
      isTrue,
    );
  });

  test('a structured approved record satisfies a coordinated evolution', () {
    expect(
      requiresEvolutionRecord(
        [
          'assets/evergreen/catalogue.json',
          'lib/l10n/app_es.arb',
          'catalogue-evolution/a12-v1.md',
        ],
        recordContents: const {'catalogue-evolution/a12-v1.md': validRecord},
      ),
      isFalse,
    );
  });

  test('the executable checks the supplied Git base range', () async {
    final root = Directory.systemTemp.createTempSync('catalogue_evolution');
    addTearDown(() => root.deleteSync(recursive: true));
    Directory('${root.path}/assets/evergreen').createSync(recursive: true);
    Directory('${root.path}/tool').createSync(recursive: true);
    File('${root.path}/assets/evergreen/catalogue.json')
        .writeAsStringSync('{}');
    File('${root.path}/tool/catalogue_baseline.json').writeAsStringSync('{}');
    _git(root, ['init', '--quiet']);
    _git(root, ['config', 'user.email', 'test@example.invalid']);
    _git(root, ['config', 'user.name', 'Test']);
    _git(root, ['add', '.']);
    _git(root, ['commit', '--quiet', '-m', 'base']);
    final base =
        (Process.runSync('git', [
                  'rev-parse',
                  'HEAD',
                ], workingDirectory: root.path).stdout
                as String)
            .trim();

    File('${root.path}/assets/evergreen/catalogue.json')
        .writeAsStringSync('{"version": 1}');
    File('${root.path}/tool/catalogue_baseline.json')
        .writeAsStringSync('{"version": 1}');
    _git(root, ['add', '.']);
    _git(root, ['commit', '--quiet', '-m', 'unreviewed catalogue evolution']);
    expect(await runCheck(workingDirectory: root.path, base: base), 1);

    Directory('${root.path}/catalogue-evolution').createSync();
    File('${root.path}/catalogue-evolution/change.md')
        .writeAsStringSync(validRecord);
    _git(root, ['add', '.']);
    _git(root, ['commit', '--quiet', '-m', 'approve catalogue evolution']);

    expect(await runCheck(workingDirectory: root.path, base: base), 0);
  });
}

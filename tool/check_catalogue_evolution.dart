// ignore_for_file: avoid_print
//
// A coordinated edit of protected catalogue inputs is an evolution, not
// routine maintenance. It must carry a reviewed record in the same change.
import 'dart:io';

const _protected = {
  'assets/evergreen/catalogue.json',
  'lib/l10n/app_es.arb',
  'tool/catalogue_baseline.json',
  'test/fixtures/catalogue/a12_v1_manifest.json',
};

const _recordPrefix = 'catalogue-evolution/';

/// A reviewable evolution record has this exact stable structure:
///
/// ```markdown
/// # Catalogue Evolution Record
///
/// Approval: <non-blank approver and reference>
///
/// ## Changes
///
/// 1. <enumerated change>
/// ```
bool isApprovedEvolutionRecord(String markdown) {
  final lines = markdown.split('\n');
  if (lines.isEmpty || lines.first.trim() != '# Catalogue Evolution Record') {
    return false;
  }
  final approval = RegExp(r'^Approval:[ \t]*(\S.*)$', multiLine: true);
  final changes = RegExp(r'^## Changes[ \t]*$', multiLine: true);
  final enumeratedChange = RegExp(r'^\s*1\.\s+\S', multiLine: true);
  return approval.hasMatch(markdown) &&
      changes.hasMatch(markdown) &&
      enumeratedChange.hasMatch(markdown);
}

/// Returns true when changed protected inputs lack a valid changed record.
/// [recordContents] maps changed record paths to their Markdown contents.
bool requiresEvolutionRecord(
  Iterable<String> changedFiles, {
  Map<String, String> recordContents = const {},
}) {
  final changed = changedFiles.toSet();
  final protectedCount = changed.where(_protected.contains).length;
  if (protectedCount < 2) {
    return false;
  }
  return !changed
      .where((path) => path.startsWith(_recordPrefix) && path.endsWith('.md'))
      .any((path) => isApprovedEvolutionRecord(recordContents[path] ?? ''));
}

List<String> _changedFiles({
  required String workingDirectory,
  required String? base,
}) {
  final arguments = [
    'diff',
    '--name-only',
    if (base != null && base.isNotEmpty) '$base...HEAD' else 'HEAD',
  ];
  final diff = Process.runSync(
    'git',
    arguments,
    workingDirectory: workingDirectory,
  );
  if (diff.exitCode != 0) {
    throw StateError('could not determine changed files: ${diff.stderr}');
  }
  final tracked = (diff.stdout as String)
      .split('\n')
      .where((path) => path.isNotEmpty);
  if (base != null && base.isNotEmpty) {
    return tracked.toList();
  }
  final untracked = Process.runSync('git', [
    'ls-files',
    '--others',
    '--exclude-standard',
  ], workingDirectory: workingDirectory);
  if (untracked.exitCode != 0) {
    throw StateError(
      'could not determine untracked files: ${untracked.stderr}',
    );
  }
  return [
    ...tracked,
    ...(untracked.stdout as String)
        .split('\n')
        .where((path) => path.isNotEmpty),
  ];
}

Map<String, String> _recordContents(
  String workingDirectory,
  Iterable<String> changedFiles,
) {
  final records = <String, String>{};
  for (final path in changedFiles) {
    if (!path.startsWith(_recordPrefix) || !path.endsWith('.md')) {
      continue;
    }
    final file = File('$workingDirectory/$path');
    if (file.existsSync()) {
      records[path] = file.readAsStringSync();
    }
  }
  return records;
}

/// Runs the guard in [workingDirectory]. [base] is injectable for CI and
/// tests; when absent, the current worktree and untracked files are checked.
Future<int> runCheck({String workingDirectory = '.', String? base}) async {
  try {
    final changed = _changedFiles(
      workingDirectory: workingDirectory,
      base: base ?? Platform.environment['CATALOGUE_EVOLUTION_BASE'],
    );
    if (requiresEvolutionRecord(
      changed,
      recordContents: _recordContents(workingDirectory, changed),
    )) {
      stderr.writeln(
        'catalogue evolution check FAILED: coordinated protected catalogue '
        'changes require a valid reviewed catalogue-evolution/*.md record',
      );
      return 1;
    }
    print('catalogue evolution check passed');
    return 0;
  } catch (error) {
    stderr.writeln('catalogue evolution check FAILED: $error');
    return 2;
  }
}

Future<void> main() async {
  exit(await runCheck());
}

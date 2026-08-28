import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../tool/check_forbidden_vocabulary.dart';

const fixtures = 'test/fixtures/forbidden_vocabulary';

Directory _makeTemp(String label) {
  final dir = Directory.systemTemp.createTempSync('forbidden_vocab_$label');
  addTearDown(() => dir.deleteSync(recursive: true));
  return dir;
}

void main() {
  test(
    'every one of the nine banned tokens is flagged, with file and line',
    () {
      final path = '$fixtures/banned.dart';
      final findings = scanSource(
        file: path,
        source: File(path).readAsStringSync(),
      );
      final flagged = findings.map((finding) => finding.toString()).join('\n');
      for (final token in bannedVocabulary) {
        expect(
          flagged,
          contains(token),
          reason: 'the token $token must be named in a finding',
        );
      }
      expect(findings.first.file, path);
      expect(findings.first.line, greaterThan(0));
      expect(findings.first.message, contains('banned token'));
    },
  );

  test('innocent identifiers produce no findings', () {
    final path = '$fixtures/clean.dart';
    final findings = scanSource(
      file: path,
      source: File(path).readAsStringSync(),
    );
    expect(findings, isEmpty);
  });

  test('the scan is segment-aware, not substring-aware', () {
    expect(identifierIsBanned('translate'), isFalse);
    expect(identifierIsBanned('related'), isFalse);
    expect(identifierIsBanned('slated'), isFalse);
    expect(identifierIsBanned('delegated'), isFalse);
    expect(identifierIsBanned('delay'), isFalse);
    expect(identifierIsBanned('cardSkipped'), isFalse);
    expect(identifierIsBanned('card_skipped'), isFalse);
    expect(identifierIsBanned('captureIsDue'), isFalse);
    expect(identifierIsBanned('warmReturnDue'), isFalse);
    expect(identifierIsBanned('isDue'), isFalse);
  });

  test('the banned tokens match as identifier segments', () {
    expect(identifierIsBanned('overdue'), isTrue);
    expect(identifierIsBanned('isOverdue'), isTrue);
    expect(identifierIsBanned('overdueItems'), isTrue);
    expect(identifierIsBanned('no_overdue_days'), isTrue);
    expect(identifierIsBanned('late'), isTrue);
    expect(identifierIsBanned('isLate'), isTrue);
    expect(identifierIsBanned('lateSession'), isTrue);
    expect(identifierIsBanned('missed'), isTrue);
    expect(identifierIsBanned('missedWindows'), isTrue);
    expect(identifierIsBanned('pending'), isTrue);
    expect(identifierIsBanned('pendingQueue'), isTrue);
    expect(identifierIsBanned('debt'), isTrue);
    expect(identifierIsBanned('debtMarks'), isTrue);
    expect(identifierIsBanned('streak'), isTrue);
    expect(identifierIsBanned('streakLength'), isTrue);
    expect(identifierIsBanned('skippedCount'), isTrue);
    expect(identifierIsBanned('skipped_count'), isTrue);
    expect(identifierIsBanned('totalSkippedCount'), isTrue);
    expect(identifierIsBanned('dueDate'), isTrue);
    expect(identifierIsBanned('dueDateUtc'), isTrue);
    expect(identifierIsBanned('nextDueDate'), isTrue);
    expect(identifierIsBanned('due_date'), isTrue);
    expect(identifierIsBanned('backlog'), isTrue);
    expect(identifierIsBanned('backlogSize'), isTrue);
    expect(identifierIsBanned('overdue2'), isTrue);
    expect(identifierIsBanned('skippedCount3'), isTrue);
  });

  test('SCREAMING_SNAKE and acronym casing segment like camelCase', () {
    expect(identifierIsBanned('PENDING_QUEUE'), isTrue);
    expect(identifierIsBanned('MISSED_COUNT'), isTrue);
    expect(identifierIsBanned('LATE_FLAG'), isTrue);
    expect(identifierIsBanned('OVERDUE_LIMIT'), isTrue);
    expect(identifierIsBanned('parseURLHost'), isFalse);
    expect(identifierIsBanned('TRANSLATE'), isFalse);
    expect(identifierIsBanned('RELATED_ITEMS'), isFalse);
  });

  test('the late modifier is a keyword, not an identifier', () {
    const modifierDeclarations = '''
late final int cached = 3;
late var counter = 0;
late const String table = 'x';
class C {
  late final field = 4;
}
''';
    expect(
      scanSource(file: 'modifier.dart', source: modifierDeclarations),
      isEmpty,
    );

    const identifierUses = '''
final isLate = false;
final lateSession = 1;
''';
    final findings = scanSource(file: 'usage.dart', source: identifierUses);
    expect(findings, hasLength(2));
    expect(findings.first.line, 1);
  });

  test('comments and strings cannot hide or fake banned identifiers', () {
    const source = '''
// The word overdue in a comment.
final note = 'missed and streak inside a string';
final int visibleCount = 0;
''';
    expect(scanSource(file: 'masked.dart', source: source), isEmpty);

    const sneaky = "final overdue = '\$skippedCount';";
    final findings = scanSource(file: 'sneaky.dart', source: sneaky);
    expect(findings, isNotEmpty);
    expect(findings.first.line, 1);
  });

  test('directive URIs are masked along with ordinary strings', () {
    const source = "import 'package:overdue/tools.dart';\n";
    expect(scanSource(file: 'directive.dart', source: source), isEmpty);
  });

  group('the executable', () {
    Directory fixtureRoot({required bool violating}) {
      final root = _makeTemp('cli');
      Directory('${root.path}/lib/ui').createSync(recursive: true);
      File('${root.path}/lib/ui/screen.dart').writeAsStringSync(
        violating
            ? 'final int skippedCount = 0;\n'
            : 'final int doneCount = 0;\n',
      );
      return root;
    }

    test('exits 1 and prints file:line for a violating tree', () async {
      final root = fixtureRoot(violating: true);
      final result = await Process.run('dart', [
        'run',
        'tool/check_forbidden_vocabulary.dart',
        root.path,
      ]);
      expect(result.exitCode, 1);
      expect(result.stdout as String, matches(RegExp(r'\.dart:\d+:')));
      expect(result.stdout as String, contains('skippedCount'));
    });

    test('exits 0 and prints the passed message for a clean tree', () async {
      final root = fixtureRoot(violating: false);
      final result = await Process.run('dart', [
        'run',
        'tool/check_forbidden_vocabulary.dart',
        root.path,
      ]);
      expect(result.exitCode, 0);
      expect(
        result.stdout as String,
        contains('forbidden-vocabulary check passed'),
      );
    });

    test('test/fixtures is excluded from the live scan', () async {
      final root = _makeTemp('fixtures_excluded');
      Directory('${root.path}/test/fixtures').createSync(recursive: true);
      Directory('${root.path}/lib').createSync(recursive: true);
      File('${root.path}/lib/ok.dart').writeAsStringSync('var fine = 1;\n');
      File('${root.path}/test/fixtures/bad.dart')
          .writeAsStringSync('final int overdueItems = 0;\n');
      final result = await Process.run('dart', [
        'run',
        'tool/check_forbidden_vocabulary.dart',
        root.path,
      ]);
      expect(result.exitCode, 0);
    });

    test(
      'packages/core/test is in scope, symmetric with the store seal',
      () async {
        final root = _makeTemp('core_test_scope');
        Directory('${root.path}/packages/core/test')
            .createSync(recursive: true);
        Directory('${root.path}/lib').createSync(recursive: true);
        File('${root.path}/lib/ok.dart').writeAsStringSync('var fine = 1;\n');
        File('${root.path}/packages/core/test/late_session_test.dart')
            .writeAsStringSync('final int lateSession = 0;\n');
        final result = await Process.run('dart', [
          'run',
          'tool/check_forbidden_vocabulary.dart',
          root.path,
        ]);
        expect(result.exitCode, 1);
        expect(
          result.stdout as String,
          contains('packages/core/test/late_session_test.dart:1:'),
        );
        expect(result.stdout as String, contains('lateSession'));
      },
    );

    test('a production lib/fixtures directory remains in scope', () async {
      final root = _makeTemp('production_fixtures');
      Directory('${root.path}/lib/fixtures').createSync(recursive: true);
      File('${root.path}/lib/fixtures/bad.dart')
          .writeAsStringSync('final int overdueItems = 0;\n');
      final result = await Process.run('dart', [
        'run',
        'tool/check_forbidden_vocabulary.dart',
        root.path,
      ]);
      expect(result.exitCode, 1);
      expect(result.stdout as String, contains('lib/fixtures/bad.dart'));
    });
  });
}

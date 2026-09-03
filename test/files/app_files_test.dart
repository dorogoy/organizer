// The Files adapter's contract (Story 4.3, AD-21, AD-22): app-private
// byte storage over a temp root — read nullable, write atomic (a
// failed write leaves the old blob intact), delete idempotent,
// scope-partitioned, and traversal-refusing (no scope or name may
// compose its way out of the root).
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:organizer/files/app_files.dart';

void main() {
  late Directory root;
  late AppFiles files;

  setUp(() {
    root = Directory.systemTemp.createTempSync('app_files');
    files = AppFiles(rootOf: () async => root);
  });

  tearDown(() {
    root.deleteSync(recursive: true);
  });

  test('a written blob reads back byte-for-byte, scoped by name', () async {
    await files.write(credentialFilesScope, 'openai', [1, 2, 3, 250]);
    expect(await files.read(credentialFilesScope, 'openai'), [1, 2, 3, 250]);
    // Scope-partitioned: another scope does not see it.
    expect(await files.read('scan_cache', 'openai'), isNull);
  });

  test('an absent blob reads as null — absence is a quiet state', () async {
    expect(await files.read(credentialFilesScope, 'openai'), isNull);
  });

  test(
    'a write replaces what stood there before — the second blob wins',
    () async {
      await files.write(credentialFilesScope, 'openai', [1, 2, 3]);
      await files.write(credentialFilesScope, 'openai', [9, 9]);
      expect(await files.read(credentialFilesScope, 'openai'), [9, 9]);
    },
  );

  test('a failed write leaves the previous blob intact and no staging or '
      'partial file behind', () async {
    await files.write(credentialFilesScope, 'openai', [1, 2, 3]);
    final scopeDir = Directory(
      '${root.path}${Platform.pathSeparator}$credentialFilesScope',
    );
    // An unwritable scope directory is the failure: the staging
    // write cannot open, the rename never runs, and the failure is
    // the caller's (the vault's write discipline swallows it there).
    expect((await Process.run('chmod', ['a-w', scopeDir.path])).exitCode, 0);
    try {
      await expectLater(
        files.write(credentialFilesScope, 'openai', [9, 9, 9]),
        throwsA(isA<FileSystemException>()),
      );
    } finally {
      await Process.run('chmod', ['a+w', scopeDir.path]);
    }
    // The old blob stands, and the directory holds nothing else —
    // no staging file, no partial write.
    expect(await files.read(credentialFilesScope, 'openai'), [1, 2, 3]);
    expect(scopeDir.listSync().map((e) => e.uri.pathSegments.last).toList(), [
      'openai',
    ]);
  });

  test('a write lands as one rename — no staging file outlives it', () async {
    await files.write(credentialFilesScope, 'openai', [1, 2, 3]);
    final scopeDir = Directory(
      '${root.path}${Platform.pathSeparator}$credentialFilesScope',
    );
    final names = scopeDir
        .listSync()
        .map((entity) => entity.uri.pathSegments.last)
        .toList();
    expect(names, ['openai']);
  });

  test(
    'a delete removes the blob; deleting again is the same outcome',
    () async {
      await files.write(credentialFilesScope, 'openai', [1, 2, 3]);
      await files.delete(credentialFilesScope, 'openai');
      expect(await files.read(credentialFilesScope, 'openai'), isNull);
      // Idempotent: an absent file is not an error.
      await files.delete(credentialFilesScope, 'openai');
      expect(await files.read(credentialFilesScope, 'openai'), isNull);
    },
  );

  test(
    'deleting a blob that never existed is quiet — and creates nothing',
    () async {
      await files.delete(credentialFilesScope, 'never_there');
      expect(root.listSync(), isEmpty);
    },
  );

  test('a read never creates the scope directory', () async {
    await files.read(credentialFilesScope, 'openai');
    expect(root.listSync(), isEmpty);
  });

  test('an empty blob reads back as empty, never as absent', () async {
    await files.write(credentialFilesScope, 'openai', []);
    expect(await files.read(credentialFilesScope, 'openai'), isEmpty);
  });

  group('the traversal refusal — one clean segment, everywhere', () {
    test('a traversal-shaped name writes nothing and reads as null', () async {
      for (final name in [
        '../evil',
        '..\\evil',
        'a/b',
        'a\\b',
        '.',
        '..',
        '',
      ]) {
        await files.write(credentialFilesScope, name, [1, 2, 3]);
        expect(
          await files.read(credentialFilesScope, name),
          isNull,
          reason: name,
        );
        // Nothing escaped the root: it holds no file at all.
        expect(root.listSync(), isEmpty, reason: name);
      }
    });

    test('a traversal-shaped scope is refused the same way', () async {
      for (final scope in ['../credentials', 'a/b', '.', '..']) {
        await files.write(scope, 'openai', [1, 2, 3]);
        expect(await files.read(scope, 'openai'), isNull, reason: scope);
        expect(root.listSync(), isEmpty, reason: scope);
      }
    });

    test('a delete over a traversal-shaped pair is quiet and total', () async {
      await files.delete('../evil', 'openai');
      await files.delete(credentialFilesScope, '../evil');
      expect(root.listSync(), isEmpty);
    });

    test('a name with a NUL is refused', () async {
      await files.write(credentialFilesScope, 'a\u0000b', [1]);
      expect(root.listSync(), isEmpty);
    });
  });
}

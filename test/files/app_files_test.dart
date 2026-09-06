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

  group('the per-scan cache mechanics (Story 5.2, FR-16, FR-25)', () {
    test('a frame writes into the scan\'s own subdirectory and the '
        'returned path reads back byte-for-byte', () async {
      final path = await files.writeScanFrame('scan-1', [4, 5, 250]);
      expect(path, isNotEmpty);
      final file = File(path);
      expect(file.existsSync(), isTrue);
      expect(await file.readAsBytes(), [4, 5, 250]);
      // The reserved vocabulary: the scan_cache scope, the scan's own
      // clean segment, the one frame name.
      expect(
        path.replaceAll('\\', '/').split('/'),
        containsAllInOrder([scanCacheScope, 'scan-1', scanFrameFileName]),
      );
      // The flat scope's own read does not see the frame (it lives in
      // a subdirectory the flat vocabulary never composes) — the
      // subdirectory exists only through the scan methods.
      expect(await files.read(scanCacheScope, 'frame.jpg'), isNull);
    });

    test('two scans hold separate frames — one clean segment each', () async {
      final one = await files.writeScanFrame('scan-1', [1]);
      final two = await files.writeScanFrame('scan-2', [2, 2]);
      expect(one, isNot(two));
      expect(await File(one).readAsBytes(), [1]);
      expect(await File(two).readAsBytes(), [2, 2]);
    });

    test('a rename failure deletes the sibling staging file — no .tmp '
        'lingers beside the planted destination', () async {
      await files.writeScanFrame('scan-1', [1, 1]);
      final scanDir = Directory(
        '${root.path}${Platform.pathSeparator}$scanCacheScope'
        '${Platform.pathSeparator}scan-1',
      );
      File('${scanDir.path}${Platform.pathSeparator}$scanFrameFileName')
          .deleteSync();
      Directory('${scanDir.path}${Platform.pathSeparator}$scanFrameFileName')
          .createSync();
      expect(await files.writeScanFrame('scan-1', [2, 2, 2]), '');
      String namedOf(FileSystemEntity entity) =>
          entity.uri.pathSegments.where((s) => s.isNotEmpty).last;
      final names = scanDir.listSync().map(namedOf).toList();
      expect(names, [scanFrameFileName]);
      expect(
        names.where((name) => name.endsWith(stagingSuffix)),
        isEmpty,
        reason: 'the staging sibling died with the failed rename',
      );
    });

    test('a re-write replaces the standing frame — one rename, no '
        'staging file behind', () async {
      await files.writeScanFrame('scan-1', [1, 1]);
      await files.writeScanFrame('scan-1', [2]);
      final scanDir = Directory(
        '${root.path}${Platform.pathSeparator}$scanCacheScope'
        '${Platform.pathSeparator}scan-1',
      );
      expect(scanDir.listSync().map((e) => e.uri.pathSegments.last).toList(), [
        scanFrameFileName,
      ]);
    });

    test('unlink removes the scan\'s whole subdirectory and is '
        'idempotent — the scope itself stays for the other scans', () async {
      await files.writeScanFrame('scan-1', [1]);
      await files.writeScanFrame('scan-2', [2]);
      await files.unlinkScan('scan-1');
      final scopeDir = Directory(
        '${root.path}${Platform.pathSeparator}$scanCacheScope',
      );
      // A directory entity's URI ends in a slash, so its last raw
      // segment is empty — the census reads the named segment.
      String namedOf(FileSystemEntity entity) =>
          entity.uri.pathSegments.where((s) => s.isNotEmpty).last;
      expect(scopeDir.listSync().map(namedOf).toList(), ['scan-2']);
      // Idempotent: a second unlink of the same scan is quiet.
      await files.unlinkScan('scan-1');
      expect(scopeDir.listSync().map(namedOf).toList(), ['scan-2']);
      // A scan that never existed unlinks quietly too.
      await files.unlinkScan('never-opened');
    });

    test('a traversal-shaped scanId is refused quietly: no write, the '
        'empty path, nothing escaped the root', () async {
      for (final scanId in ['../evil', 'a/b', '.', '..', 'a\u0000b']) {
        expect(await files.writeScanFrame(scanId, [1]), '', reason: scanId);
        await files.unlinkScan(scanId);
        expect(root.listSync(), isEmpty, reason: scanId);
      }
    });

    test('the plugin-shot deletion helper removes the named file, '
        'best-effort: absent is quiet, nothing throws (P1 — no shot '
        'lingers where nothing sweeps)', () async {
      final shot = File(
        '${root.path}${Platform.pathSeparator}plugin_cache_shot.jpg',
      )..writeAsBytesSync([1, 2, 3]);
      await deleteFileBestEffort(shot.path);
      expect(shot.existsSync(), isFalse);
      // Absent is the same quiet answer; a directory-shaped path
      // neither throws nor recurses.
      await deleteFileBestEffort(shot.path);
      await deleteFileBestEffort(root.path);
      expect(root.existsSync(), isTrue);
    });
  });
}

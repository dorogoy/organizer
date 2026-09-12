// The Files adapter's contract (Story 4.3, AD-21, AD-22): app-private
// byte storage over a temp root — read nullable, write atomic (a
// failed write leaves the old blob intact), delete idempotent,
// scope-partitioned, and traversal-refusing (no scope or name may
// compose its way out of the root).
import 'dart:io';

import 'package:core/ports/scan_consent.dart';
import 'package:crypto/crypto.dart';
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

  group('the capped copy and the sweep (Story 5.4, AD-8)', () {
    String namedOf(FileSystemEntity entity) =>
        entity.uri.pathSegments.where((s) => s.isNotEmpty).last;

    Directory scanDirOf(String scanId) => Directory(
      '${root.path}${Platform.pathSeparator}$scanCacheScope'
      '${Platform.pathSeparator}$scanId',
    );

    test('a capped copy writes beside the frame and the returned path '
        'reads back byte-for-byte', () async {
      final framePath = await files.writeScanFrame('scan-1', [1]);
      final cappedPath = await files.writeScanCappedCopy('scan-1', [7, 8, 250]);
      expect(cappedPath, isNotEmpty);
      final file = File(cappedPath);
      expect(file.existsSync(), isTrue);
      expect(await file.readAsBytes(), [7, 8, 250]);
      expect(
        cappedPath.replaceAll('\\', '/').split('/'),
        containsAllInOrder([scanCacheScope, 'scan-1', scanCappedCopyName]),
      );
      expect(framePath, isNotEmpty);
      // Two sanctioned names, nothing else: a scan's subdirectory
      // holds at most the frame and the capped copy, by construction.
      final names = scanDirOf('scan-1').listSync().map(namedOf).toList()
        ..sort();
      expect(names, [scanCappedCopyName, scanFrameFileName]);
      // The flat scope's own read does not see it (it lives in a
      // subdirectory the flat vocabulary never composes).
      expect(await files.read(scanCacheScope, scanCappedCopyName), isNull);
    });

    test('a re-write replaces the standing capped copy atomically, and '
        'a failed rename deletes the staging sibling', () async {
      await files.writeScanCappedCopy('scan-1', [1, 1]);
      final scanDir = scanDirOf('scan-1');
      final cappedFile = File(
        '${scanDir.path}${Platform.pathSeparator}$scanCappedCopyName',
      );
      cappedFile.deleteSync();
      // A directory standing where the file belongs makes the rename
      // fail — the write answers the quiet empty path, and no .tmp
      // lingers beside the planted destination.
      Directory(cappedFile.path).createSync();
      expect(await files.writeScanCappedCopy('scan-1', [2]), '');
      final names = scanDir.listSync().map(namedOf).toList();
      expect(names, [scanCappedCopyName]);
      expect(
        names.where((name) => name.endsWith(stagingSuffix)),
        isEmpty,
        reason: 'the staging sibling died with the failed rename',
      );
    });

    test('a traversal-shaped scanId is refused quietly: no write, the '
        'empty path, nothing escaped the root', () async {
      for (final scanId in ['../evil', 'a/b', '.', '..', 'a\u0000b']) {
        expect(
          await files.writeScanCappedCopy(scanId, [1]),
          '',
          reason: scanId,
        );
        expect(root.listSync(), isEmpty, reason: scanId);
      }
    });

    test('two scans hold separate capped copies — cross-scope '
        'isolation, one clean segment each', () async {
      final one = await files.writeScanCappedCopy('scan-1', [1]);
      final two = await files.writeScanCappedCopy('scan-2', [2, 2]);
      expect(one, isNot(two));
      expect(await File(one).readAsBytes(), [1]);
      expect(await File(two).readAsBytes(), [2, 2]);
    });

    test('the mint validates nothing — the adapter is the refusing '
        'edge (Story 5.4, AD-8): a token bound to a traversal-shaped '
        'scanId writes nothing through either scan write', () async {
      // The sanctioned minter binds whatever it is handed — the
      // caller's contract, no validation at the mint — so the
      // enforcement is proven at the adapter, exactly where the
      // documents put it.
      final token = mintScanConsent(scanId: '../evil');
      expect(await files.writeScanFrame(token.scanId, [1]), '');
      expect(await files.writeScanCappedCopy(token.scanId, [2]), '');
      expect(root.listSync(), isEmpty, reason: 'nothing escaped the root');
    });

    test('unlinkScan removes the two-file state whole — the directory '
        'is gone, and the unlink stays idempotent (AC3, AC4)', () async {
      await files.writeScanFrame('scan-1', [1]);
      await files.writeScanCappedCopy('scan-1', [2]);
      expect(scanDirOf('scan-1').listSync(), hasLength(2));
      await files.unlinkScan('scan-1');
      expect(scanDirOf('scan-1').existsSync(), isFalse);
      // Idempotent: a second unlink of the same scan is quiet.
      await files.unlinkScan('scan-1');
      // The scope itself stays for the other scans.
      await files.writeScanFrame('scan-2', [3]);
      expect(scanDirOf('scan-2').existsSync(), isTrue);
    });

    test('the sweep unlinks every child of the scope — stale subdirs '
        'and stray files alike — and the scope dir itself remains '
        '(AC5)', () async {
      await files.writeScanFrame('scan-old', [1]);
      await files.writeScanCappedCopy('scan-old', [2]);
      await files.writeScanFrame('scan-live', [3]);
      File(
        '${root.path}${Platform.pathSeparator}$scanCacheScope'
        '${Platform.pathSeparator}stray.bin',
      ).createSync();
      // Another scope's blob is not the sweep's to touch.
      await files.write(credentialFilesScope, 'openai', [9]);
      // A nested leftover dies whole.
      Directory(
        '${root.path}${Platform.pathSeparator}$scanCacheScope'
        '${Platform.pathSeparator}scan-nested',
      ).createSync();
      File(
        '${root.path}${Platform.pathSeparator}$scanCacheScope'
        '${Platform.pathSeparator}scan-nested'
        '${Platform.pathSeparator}$scanFrameFileName',
      ).writeAsBytesSync([4]);

      await files.sweepScanCache();

      final scopeDir = Directory(
        '${root.path}${Platform.pathSeparator}$scanCacheScope',
      );
      expect(scopeDir.existsSync(), isTrue, reason: 'the scope remains');
      expect(scopeDir.listSync(followLinks: false), isEmpty);
      expect(await files.read(credentialFilesScope, 'openai'), [9]);
    });

    test('a fresh install: a missing scope sweeps as a quiet no-op, '
        'creating nothing', () async {
      await files.sweepScanCache();
      expect(root.listSync(), isEmpty);
    });

    test('the sweep is idempotent — a second run is the same quiet '
        'outcome', () async {
      await files.writeScanFrame('scan-old', [1]);
      await files.sweepScanCache();
      await files.sweepScanCache();
      expect(
        Directory('${root.path}${Platform.pathSeparator}$scanCacheScope')
            .listSync(followLinks: false),
        isEmpty,
      );
    });

    test('a sweep over a scope it cannot read is quiet — a backstop '
        'never breaks its caller', () async {
      await files.writeScanFrame('scan-old', [1]);
      final scopeDir = Directory(
        '${root.path}${Platform.pathSeparator}$scanCacheScope',
      );
      expect((await Process.run('chmod', ['000', scopeDir.path])).exitCode, 0);
      try {
        await files.sweepScanCache();
      } finally {
        await Process.run('chmod', ['755', scopeDir.path]);
      }
      // Nothing threw; whatever the filesystem refused stands for the
      // next open's sweep.
      expect(scopeDir.existsSync(), isTrue);
    });
  });

  group('the content-addressed album write (Story 7.1, FR-17, AD-13)', () {
    test(
      'the sha256 hex of the bytes names the blob, with the fixed '
      'suffix, in the album scope — and it reads back byte-for-byte',
      () async {
        final name = await writeAlbumPhoto(files, [4, 5, 250]);
        final expected =
            '${sha256.convert([4, 5, 250]).toString()}$albumPhotoSuffix';
        expect(name, expected);
        expect(await files.read(albumFilesScope, name), [4, 5, 250]);
        // The blob lives in the album scope alone — one flat partition,
        // exactly the scope FilesPort's own doc reserved.
        final albumDir = Directory(
          '${root.path}${Platform.pathSeparator}$albumFilesScope',
        );
        expect(
          albumDir.listSync().map((e) => e.uri.pathSegments.last).toList(),
          [expected],
        );
      },
    );

    test('content addressing is idempotent — the same bytes name the '
        'same blob, so no duplicate ever grows the album', () async {
      final one = await writeAlbumPhoto(files, [1, 2, 3]);
      final two = await writeAlbumPhoto(files, [1, 2, 3]);
      expect(two, one);
      final albumDir = Directory(
        '${root.path}${Platform.pathSeparator}$albumFilesScope',
      );
      expect(albumDir.listSync(), hasLength(1));
    });

    test('different bytes name different blobs — a Before and an After '
        'never collide', () async {
      final before = await writeAlbumPhoto(files, [1]);
      final after = await writeAlbumPhoto(files, [2]);
      expect(after, isNot(before));
    });
  });

  group('the album purge sweep (Story 7.2, FR-18)', () {
    test('sweepAlbum unlinks every blob in the scope — the scope dir '
        'survives, another scope is not the sweep\'s to touch', () async {
      await writeAlbumPhoto(files, [1]);
      await writeAlbumPhoto(files, [2, 2]);
      await writeAlbumPhoto(files, [3, 3, 3]);
      // Another scope's blob is not the purge's to touch — and a
      // user-initiated export lands outside the app-private root
      // altogether, structurally beyond the sweep (NFR4).
      await files.write(credentialFilesScope, 'openai', [9]);

      await files.sweepAlbum();

      final albumDir = Directory(
        '${root.path}${Platform.pathSeparator}$albumFilesScope',
      );
      expect(albumDir.existsSync(), isTrue, reason: 'the scope remains');
      expect(albumDir.listSync(followLinks: false), isEmpty);
      expect(await files.read(credentialFilesScope, 'openai'), [9]);
    });

    test('a fresh install: a missing album scope sweeps as a quiet '
        'no-op, creating nothing', () async {
      await files.sweepAlbum();
      expect(root.listSync(), isEmpty);
    });

    test('the sweep is idempotent — a second run is the same quiet '
        'outcome, the purge retry\'s own footing', () async {
      await writeAlbumPhoto(files, [1]);
      await files.sweepAlbum();
      await files.sweepAlbum();
      expect(
        Directory('${root.path}${Platform.pathSeparator}$albumFilesScope')
            .listSync(followLinks: false),
        isEmpty,
      );
    });
  });
}

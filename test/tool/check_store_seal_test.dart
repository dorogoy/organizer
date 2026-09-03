import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../tool/check_store_seal.dart';

const fixtures = 'test/fixtures/store_seal';

Directory _makeTemp(String label) {
  final dir = Directory.systemTemp.createTempSync('store_seal_$label');
  addTearDown(() => dir.deleteSync(recursive: true));
  return dir;
}

void main() {
  test('a drift import outside lib/store/ is flagged, with file and line', () {
    final path = '$fixtures/outside.dart';
    final source = File(path).readAsStringSync();
    final findings = scanSource(file: path, source: source);
    final importOffset = source.indexOf("import 'package:drift");
    final importLine =
        '\n'.allMatches(source.substring(0, importOffset)).length + 1;
    expect(findings, hasLength(1));
    expect(findings.single.file, path);
    expect(findings.single.line, importLine);
    expect(findings.single.message, contains('package:drift/drift.dart'));
    expect(findings.single.message, contains('AD-21 store seal'));
  });

  test('the drift* prefix catches drift_flutter too', () {
    final path = '$fixtures/outside_drift_flutter.dart';
    final findings = scanSource(
      file: path,
      source: File(path).readAsStringSync(),
    );
    expect(findings, hasLength(1));
    expect(
      findings.single.message,
      contains('package:drift_flutter/drift_flutter.dart'),
    );
  });

  test('an allowlisted path may import persistence packages', () {
    final path = '$fixtures/inside.dart';
    final findings = scanSource(
      file: path,
      source: File(path).readAsStringSync(),
      allowlist: const ['test/fixtures/store_seal/inside'],
    );
    expect(findings, isEmpty);
  });

  test('a file with no persistence imports is clean', () {
    final path = '$fixtures/clean.dart';
    final findings = scanSource(
      file: path,
      source: File(path).readAsStringSync(),
    );
    expect(findings, isEmpty);
  });

  test('the default allowlist holds exactly the five decided scopes '
      '(4-4 grew the dart:io half by lib/egress/)', () {
    expect(persistenceImportAllowlist, contains('lib/store/'));
    expect(persistenceImportAllowlist, contains('lib/files/'));
    expect(persistenceImportAllowlist, contains('test/store/'));
    expect(persistenceImportAllowlist, contains('test/files/'));
    expect(persistenceImportAllowlist, hasLength(4));
    expect(dartIoAllowlist, contains('lib/egress/'));
    expect(dartIoAllowlist, hasLength(3));
  });

  test('the seal covers the prefixes and the named denylist', () {
    expect(packageIsPersistence('drift'), isTrue);
    expect(packageIsPersistence('drift_flutter'), isTrue);
    expect(packageIsPersistence('sqlite3'), isTrue);
    expect(packageIsPersistence('sqlite3_flutter_libs'), isTrue);
    expect(packageIsPersistence('sqflite'), isTrue);
    expect(packageIsPersistence('sqflite_common_ffi'), isTrue);
    expect(packageIsPersistence('shared_preferences'), isTrue);
    expect(packageIsPersistence('shared_preferences_android'), isTrue);
    expect(packageIsPersistence('hive'), isTrue);
    expect(packageIsPersistence('isar'), isTrue);
    expect(packageIsPersistence('objectbox'), isTrue);
    expect(packageIsPersistence('sembast'), isTrue);
    expect(packageIsPersistence('realm'), isTrue);
    expect(packageIsPersistence('flutter_secure_storage'), isTrue);
    expect(packageIsPersistence('uuid'), isFalse);
    expect(packageIsPersistence('flutter_riverpod'), isFalse);
    expect(packageIsPersistence('core'), isFalse);
    expect(packageIsPersistence('flutter'), isFalse);
  });

  test('an import-shaped line inside a string literal is not an import', () {
    const source =
        "const text = '''\nimport 'package:drift/drift.dart';\n''';\n";
    expect(scanSource(file: 'in_string.dart', source: source), isEmpty);
  });

  test('a raw store library import outside lib/store/ is flagged', () {
    const source = "import 'package:organizer/store/substrate.dart';\n";
    final findings = scanSource(file: 'lib/ui/screen.dart', source: source);
    expect(findings, hasLength(1));
    expect(findings.single.message, contains('raw store library'));
  });

  test('a directive after a same-line library declaration is sealed', () {
    const source = "library fixture; import 'package:drift/drift.dart';\n";
    final findings = scanSource(file: 'lib/ui/screen.dart', source: source);
    expect(findings, hasLength(1));
    expect(findings.single.message, contains('package:drift/drift.dart'));
  });

  group('the dart:io rule (Story 4.3 — side files are Files\' business or '
      'nobody\'s)', () {
    test('a dart:io import under lib/ outside store/files is flagged', () {
      const source = "import 'dart:io';\n";
      final findings = scanDartIoSource(
        file: 'lib/ui/screen.dart',
        source: source,
      );
      expect(findings, hasLength(1));
      expect(findings.single.file, 'lib/ui/screen.dart');
      expect(findings.single.line, 1);
      expect(findings.single.message, contains('dart:io'));
      expect(findings.single.message, contains('AD-21 store seal'));
    });

    test('the files module may import dart:io', () {
      const source = "import 'dart:io';\n";
      expect(
        scanDartIoSource(file: 'lib/files/app_files.dart', source: source),
        isEmpty,
      );
      expect(
        scanDartIoSource(file: 'lib/store/connection.dart', source: source),
        isEmpty,
      );
    });

    test('a dart:io import inside a string literal is not an import', () {
      const source = "const text = '''\nimport 'dart:io';\n''';\n";
      expect(
        scanDartIoSource(file: 'lib/ui/screen.dart', source: source),
        isEmpty,
      );
    });

    test('lib/egress/ may import dart:io for SocketException (Story 4-4)', () {
      const source = "import 'dart:io' show SocketException;\n";
      expect(
        scanDartIoSource(file: 'lib/egress/byok_slicer.dart', source: source),
        isEmpty,
      );
    });
  });

  group('the egress file-API fence (Story 4-4 — socket classification '
      'only)', () {
    test('a clean egress file — SocketException classification — passes', () {
      final path = '$fixtures/egress_socket_ok.dart';
      expect(
        scanEgressFileApiSource(
          file: 'lib/egress/byok_slicer.dart',
          source: File(path).readAsStringSync(),
        ),
        isEmpty,
      );
    });

    test('dart:io file APIs in lib/egress/ are flagged, with file and '
        'line', () {
      final path = '$fixtures/egress_file_leak.dart';
      final source = File(path).readAsStringSync();
      final findings = scanEgressFileApiSource(
        file: 'lib/egress/leak.dart',
        source: source,
      );
      final directoryOffset = source.indexOf('Directory(');
      final directoryLine =
          '\n'.allMatches(source.substring(0, directoryOffset)).length + 1;
      expect(findings, isNotEmpty);
      expect(findings.first.file, 'lib/egress/leak.dart');
      expect(findings.first.line, directoryLine);
      expect(findings.first.message, contains('Directory'));
      expect(
        findings.any((finding) => finding.message.contains('File')),
        isTrue,
      );
      expect(findings.every((f) => f.message.contains('AD-21')), isTrue);
    });

    test('dart:io socket constructors and stdio getters in lib/egress/ '
        'are flagged — no second opener beside package:http', () {
      final path = '$fixtures/egress_socket_channel_leak.dart';
      final source = File(path).readAsStringSync();
      final findings = scanEgressFileApiSource(
        file: 'lib/egress/leak.dart',
        source: source,
      );
      expect(findings, isNotEmpty);
      for (final token in ['HttpClient', 'Socket', 'stdout']) {
        expect(
          findings.any((finding) => finding.message.contains(token)),
          isTrue,
          reason: token,
        );
      }
    });

    test('dart:io process APIs in lib/egress/ are flagged too — no child '
        'processes through the chokepoint (Story 4-4 fence)', () {
      final path = '$fixtures/egress_process_leak.dart';
      final source = File(path).readAsStringSync();
      final findings = scanEgressFileApiSource(
        file: 'lib/egress/leak.dart',
        source: source,
      );
      expect(findings, isNotEmpty);
      for (final token in ['Process', 'sleep', 'exit']) {
        expect(
          findings.any((finding) => finding.message.contains(token)),
          isTrue,
          reason: token,
        );
      }
      expect(
        findings.every(
          (finding) => finding.message.contains('file, process or socket API'),
        ),
        isTrue,
      );
    });

    test('a file-API identifier inside a string literal or comment is '
        'not a finding', () {
      const source = '''
const copy = 'File in a string stays copy';
// Directory in a comment stays copy too
var fine = 1;
''';
      expect(
        scanEgressFileApiSource(file: 'lib/egress/copy.dart', source: source),
        isEmpty,
      );
    });

    test('the fence polices lib/egress/ alone — the files module still '
        'may', () {
      // The scan is only invoked for egress paths by runCheck; the
      // direct call documents the scope by refusing nothing here.
      const source = 'var fine = 1;\n';
      expect(
        scanEgressFileApiSource(file: 'lib/egress/ok.dart', source: source),
        isEmpty,
      );
    });
  });
  group('the Kotlin sweep (Story 4.3 — one closed native exception)', () {
    test('Keystore/crypto is clean inside exactly the allowlisted path', () {
      final path = '$fixtures/CredentialKeystore.kt';
      expect(
        scanKotlinSource(
          file:
              'android/app/src/main/kotlin/dev/dorogoy/organizer/'
              'CredentialKeystore.kt',
          source: File(path).readAsStringSync(),
        ),
        isEmpty,
      );
    });

    test('a decoy same-named file on another path is not the service — '
        'the allowlist matches the exact path, not a basename', () {
      final path = '$fixtures/DecoyCredentialKeystore.kt';
      final findings = scanKotlinSource(
        file:
            'android/app/src/debug/kotlin/dev/dorogoy/organizer/other/'
            'CredentialKeystore.kt',
        source: File(path).readAsStringSync(),
      );
      expect(findings, isNotEmpty);
      expect(
        findings.every(
          (finding) => finding.message.contains('Keystore/crypto'),
        ),
        isTrue,
      );
    });

    test('ordinary channel Kotlin is clean by default', () {
      final path = '$fixtures/CleanChannel.kt';
      expect(
        scanKotlinSource(file: path, source: File(path).readAsStringSync()),
        isEmpty,
      );
    });

    test('Keystore/crypto outside the allowlisted file is flagged, imports '
        'and identifiers both', () {
      final path = '$fixtures/CryptoLeak.kt';
      final findings = scanKotlinSource(
        file: path,
        source: File(path).readAsStringSync(),
      );
      expect(findings, isNotEmpty);
      expect(
        findings.every((finding) => finding.message.contains('AD-21')),
        isTrue,
      );
      expect(
        findings.any((finding) => finding.message.contains('import')),
        isTrue,
      );
      expect(
        findings.any((finding) => finding.message.contains('KeyGenerator')),
        isTrue,
      );
      expect(
        findings.any((finding) => finding.message.contains('fully-qualified')),
        isTrue,
      );
    });

    test('file APIs are flagged in no Kotlin file — the allowlisted '
        'keystore file included', () {
      final leakPath = '$fixtures/FileLeak.kt';
      final findings = scanKotlinSource(
        file: leakPath,
        source: File(leakPath).readAsStringSync(),
      );
      expect(findings, isNotEmpty);
      expect(
        findings.every((finding) => finding.message.contains('Dart-side')),
        isTrue,
      );
      // And even the wrapping key's own service may not touch files.
      final keystoreWithFile = '''
import java.security.KeyStore
import java.io.File

internal class CredentialKeystore {
    fun leak() = File("envelope").readBytes()
}
''';
      final mixed = scanKotlinSource(
        file:
            'android/app/src/main/kotlin/dev/dorogoy/organizer/'
            'CredentialKeystore.kt',
        source: keystoreWithFile,
      );
      expect(
        mixed.where((finding) => finding.message.contains('file-API')),
        isNotEmpty,
      );
      expect(
        mixed.where((finding) => finding.message.contains('Keystore/crypto')),
        isEmpty,
      );
    });

    test('crypto inside a string literal or comment is not a finding', () {
      const source = '''
val copy = "Cipher in a string stays copy"
// KeyStore in a comment stays copy too
val fine = 1
''';
      expect(scanKotlinSource(file: 'SomeChannel.kt', source: source), isEmpty);
    });

    test('side-channel store APIs are flagged in no Kotlin file — the '
        'allowlisted keystore service included', () {
      final path = '$fixtures/SideChannelLeak.kt';
      final findings = scanKotlinSource(
        file:
            'android/app/src/main/kotlin/dev/dorogoy/organizer/'
            'SideChannelLeak.kt',
        source: File(path).readAsStringSync(),
      );
      expect(findings, isNotEmpty);
      expect(
        findings.every(
          (finding) => finding.message.contains('side-channel store API'),
        ),
        isTrue,
      );
      for (final token in [
        'openFileOutput',
        'getFilesDir',
        'getCacheDir',
        'getExternalFilesDir',
        'getSharedPreferences',
      ]) {
        expect(
          findings.any((finding) => finding.message.contains(token)),
          isTrue,
          reason: token,
        );
      }

      // And the one allowlisted file carries no side-channel
      // exemption either: Files is Dart-side only, everywhere.
      final keystoreWithPrefs = '''
import android.content.Context

internal class CredentialKeystore(private val context: Context) {
    fun leak() = context.getSharedPreferences("vault", 0)
}
''';
      final mixed = scanKotlinSource(
        file:
            'android/app/src/main/kotlin/dev/dorogoy/organizer/'
            'CredentialKeystore.kt',
        source: keystoreWithPrefs,
      );
      expect(
        mixed.where(
          (finding) => finding.message.contains('side-channel store API'),
        ),
        isNotEmpty,
      );
      expect(
        mixed.where((finding) => finding.message.contains('Keystore/crypto')),
        isEmpty,
      );
    });

    test('the NIO file family is flagged imported and fully qualified', () {
      final path = '$fixtures/NioFilesLeak.kt';
      final findings = scanKotlinSource(
        file:
            'android/app/src/main/kotlin/dev/dorogoy/organizer/'
            'NioFilesLeak.kt',
        source: File(path).readAsStringSync(),
      );
      expect(findings, isNotEmpty);
      expect(
        findings.any(
          (finding) =>
              finding.message.contains('NIO file import') &&
              finding.message.contains('java.nio.file.Files'),
        ),
        isTrue,
      );
      expect(
        findings.any((finding) => finding.message.contains('NIO file usage')),
        isTrue,
      );
    });

    test('a wildcard NIO file import is flagged', () {
      const source = '''
package dev.dorogoy.organizer

import java.nio.file.*

class WildcardLeak
''';
      final findings = scanKotlinSource(
        file:
            'android/app/src/main/kotlin/dev/dorogoy/organizer/WildcardLeak.kt',
        source: source,
      );
      expect(findings, isNotEmpty);
      expect(
        findings.any((finding) => finding.message.contains('NIO file import')),
        isTrue,
      );
    });
  });

  group('the executable', () {
    Directory fixtureRoot({required bool violating}) {
      final root = _makeTemp('cli');
      Directory('${root.path}/lib/ui').createSync(recursive: true);
      Directory('${root.path}/lib/store').createSync(recursive: true);
      File('${root.path}/lib/store/adapter.dart')
          .writeAsStringSync("import 'package:drift/drift.dart';\n");
      File('${root.path}/lib/ui/screen.dart').writeAsStringSync(
        violating ? "import 'package:drift/drift.dart';\n" : 'var fine = 1;\n',
      );
      return root;
    }

    test(
      'exits 1 and prints file:line for a leak outside lib/store/',
      () async {
        final root = fixtureRoot(violating: true);
        final result = await Process.run('dart', [
          'run',
          'tool/check_store_seal.dart',
          root.path,
        ]);
        expect(result.exitCode, 1);
        final out = result.stdout as String;
        expect(out, matches(RegExp(r'screen\.dart:\d+:')));
        expect(out, contains('store seal check FAILED'));
      },
    );

    test('exits 0 when only lib/store/ imports persistence', () async {
      final root = fixtureRoot(violating: false);
      final result = await Process.run('dart', [
        'run',
        'tool/check_store_seal.dart',
        root.path,
      ]);
      expect(result.exitCode, 0);
      expect(result.stdout as String, contains('store seal check passed'));
    });

    test('a production lib/fixtures directory remains in scope', () async {
      final root = _makeTemp('production_fixtures');
      Directory('${root.path}/lib/fixtures').createSync(recursive: true);
      File('${root.path}/lib/fixtures/bad.dart')
          .writeAsStringSync("import 'package:drift/drift.dart';\n");
      final result = await Process.run('dart', [
        'run',
        'tool/check_store_seal.dart',
        root.path,
      ]);
      expect(result.exitCode, 1);
      expect(result.stdout as String, contains('lib/fixtures/bad.dart'));
    });

    test('a dart:io leak under lib/ fails the executable', () async {
      final root = _makeTemp('dart_io');
      Directory('${root.path}/lib/ui').createSync(recursive: true);
      File('${root.path}/lib/ui/screen.dart')
          .writeAsStringSync("import 'dart:io';\nvoid main() {}\n");
      final result = await Process.run('dart', [
        'run',
        'tool/check_store_seal.dart',
        root.path,
      ]);
      expect(result.exitCode, 1);
      final out = result.stdout as String;
      expect(out, contains("a 'dart:io' import is legal under lib/"));
    });

    test('a dart:io file-API leak under lib/egress/ fails the executable '
        '(Story 4-4 fence)', () async {
      final root = _makeTemp('egress_file_leak');
      Directory('${root.path}/lib/store').createSync(recursive: true);
      Directory('${root.path}/lib/egress').createSync(recursive: true);
      File('${root.path}/lib/egress/wire.dart').writeAsStringSync(
        "import 'dart:io';\n"
        "void leak() => File('side').readAsStringSync();\n",
      );
      final result = await Process.run('dart', [
        'run',
        'tool/check_store_seal.dart',
        root.path,
      ]);
      expect(result.exitCode, 1);
      final out = result.stdout as String;
      expect(out, contains('dart:io file, process or socket API'));
      expect(out, contains('lib/egress/wire.dart:'));
    });

    test('a dart:io socket-channel leak under lib/egress/ fails the '
        'executable (HttpClient/Socket/stdout)', () async {
      final root = _makeTemp('egress_socket_channel_leak');
      Directory('${root.path}/lib/store').createSync(recursive: true);
      Directory('${root.path}/lib/egress').createSync(recursive: true);
      File('${root.path}/lib/egress/open.dart').writeAsStringSync(
        "import 'dart:io';\n"
        'void leak() => HttpClient();\n',
      );
      final result = await Process.run('dart', [
        'run',
        'tool/check_store_seal.dart',
        root.path,
      ]);
      expect(result.exitCode, 1);
      final out = result.stdout as String;
      expect(out, contains('dart:io file, process or socket API'));
      expect(out, contains('HttpClient'));
      expect(out, contains('lib/egress/open.dart:'));
    });

    test('a dart:io process leak under lib/egress/ fails the executable '
        '(the fence covers child processes)', () async {
      final root = _makeTemp('egress_process_leak');
      Directory('${root.path}/lib/store').createSync(recursive: true);
      Directory('${root.path}/lib/egress').createSync(recursive: true);
      File('${root.path}/lib/egress/spawn.dart').writeAsStringSync(
        "import 'dart:io';\n"
        "void leak() => Process.runSync('cat', ['envelope']);\n",
      );
      final result = await Process.run('dart', [
        'run',
        'tool/check_store_seal.dart',
        root.path,
      ]);
      expect(result.exitCode, 1);
      final out = result.stdout as String;
      expect(out, contains('dart:io file, process or socket API'));
      expect(out, contains('lib/egress/spawn.dart:'));
    });

    test('a socket-classification dart:io import under lib/egress/ '
        'passes the executable (the 4-4 exception)', () async {
      final root = _makeTemp('egress_socket');
      Directory('${root.path}/lib/store').createSync(recursive: true);
      Directory('${root.path}/lib/egress').createSync(recursive: true);
      File('${root.path}/lib/egress/wire.dart').writeAsStringSync(
        "import 'dart:io' show SocketException;\n"
        'Object? classify(Object cause) => cause is SocketException;\n',
      );
      final result = await Process.run('dart', [
        'run',
        'tool/check_store_seal.dart',
        root.path,
      ]);
      expect(result.exitCode, 0);
      expect(result.stdout as String, contains('store seal check passed'));
    });

    test('a Kotlin crypto leak outside the allowlisted file fails the '
        'executable', () async {
      final root = _makeTemp('kotlin_crypto');
      Directory('${root.path}/lib/store').createSync(recursive: true);
      final kotlinDir = Directory(
        '${root.path}/android/app/src/main/kotlin/dev/dorogoy/organizer',
      )..createSync(recursive: true);
      File('${kotlinDir.path}/MainActivity.kt')
          .writeAsStringSync('class MainActivity\n');
      File('${kotlinDir.path}/CryptoLeak.kt').writeAsStringSync(
        'import javax.crypto.Cipher\n'
        'class CryptoLeak\n'
        '    fun leak() = Cipher.getInstance("AES/GCM/NoPadding")\n',
      );
      final result = await Process.run('dart', [
        'run',
        'tool/check_store_seal.dart',
        root.path,
      ]);
      expect(result.exitCode, 1);
      final out = result.stdout as String;
      expect(out, contains('CryptoLeak.kt:'));
      expect(out, contains('Keystore/crypto'));
    });

    test('a decoy CredentialKeystore.kt in another source set fails the '
        'executable — the real one stays clean', () async {
      final root = _makeTemp('kotlin_decoy');
      Directory('${root.path}/lib/store').createSync(recursive: true);
      final main = Directory(
        '${root.path}/android/app/src/main/kotlin/dev/dorogoy/organizer',
      )..createSync(recursive: true);
      File('${main.path}/CredentialKeystore.kt').writeAsStringSync(
        File('$fixtures/CredentialKeystore.kt').readAsStringSync(),
      );
      final debug = Directory(
        '${root.path}/android/app/src/debug/kotlin/dev/dorogoy/organizer',
      )..createSync(recursive: true);
      File('${debug.path}/CredentialKeystore.kt').writeAsStringSync(
        File('$fixtures/DecoyCredentialKeystore.kt').readAsStringSync(),
      );
      final result = await Process.run('dart', [
        'run',
        'tool/check_store_seal.dart',
        root.path,
      ]);
      expect(result.exitCode, 1);
      final out = result.stdout as String;
      expect(out, contains('src/debug/kotlin'));
      expect(out, contains('Keystore/crypto'));
      expect(
        out,
        isNot(
          contains(
            'src/main/kotlin/dev/dorogoy/organizer/CredentialKeystore.kt:',
          ),
        ),
      );
    });
  });
}

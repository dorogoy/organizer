import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../tool/check_egress_imports.dart';

const fixtures = 'test/fixtures/egress_imports';

Directory _makeTemp(String label) {
  final dir = Directory.systemTemp.createTempSync('egress_imports_$label');
  addTearDown(() => dir.deleteSync(recursive: true));
  return dir;
}

void main() {
  test('an http import outside lib/egress/ is flagged, with file and line', () {
    final path = '$fixtures/http_outside.dart';
    final source = File(path).readAsStringSync();
    final findings = scanDartSource(file: 'lib/ui/screen.dart', source: source);
    final importOffset = source.indexOf("import 'package:http");
    final importLine =
        '\n'.allMatches(source.substring(0, importOffset)).length + 1;
    expect(findings, isNotEmpty);
    final http = findings.where(
      (finding) => finding.message.contains('package:http/http.dart'),
    );
    expect(http, hasLength(1));
    expect(http.single.line, importLine);
    expect(http.single.message, contains('lib/egress/'));
    expect(http.single.message, contains('AD-7'));
  });

  test('a dio import is caught by the named denylist', () {
    final path = '$fixtures/dio_outside.dart';
    final findings = scanDartSource(
      file: 'lib/ui/api.dart',
      source: File(path).readAsStringSync(),
    );
    expect(findings, hasLength(1));
    expect(findings.single.message, contains('package:dio/dio.dart'));
  });

  test('an import-shaped line inside a string literal is not an import', () {
    const source = "const text = '''\nimport 'package:http/http.dart';\n''';\n";
    expect(scanDartSource(file: 'lib/ui/screen.dart', source: source), isEmpty);
  });

  test('a socket identifier outside the permit zone is flagged', () {
    final path = '$fixtures/socket_outside.dart';
    final findings = scanDartSource(
      file: 'lib/ui/net.dart',
      source: File(path).readAsStringSync(),
    );
    expect(findings, hasLength(1));
    expect(findings.single.message, contains('HttpClient'));
    expect(findings.single.message, contains('lib/egress/'));
  });

  test('all Dart server and raw socket identifiers are sealed', () {
    const source = '''
final a = ServerSocket;
final b = RawServerSocket;
final c = RawSecureSocket;
final d = DatagramSocket;
''';
    final findings = scanDartSource(file: 'lib/ui/net.dart', source: source);
    final messages = findings.map((finding) => finding.message).join('\n');
    expect(messages, contains("'ServerSocket'"));
    expect(messages, contains("'RawServerSocket'"));
    expect(messages, contains("'RawSecureSocket'"));
    expect(messages, contains("'DatagramSocket'"));
  });

  test('Dart FFI imports are sealed outside the permit zone', () {
    const source = "import 'dart:ffi';\n";
    final findings = scanDartSource(file: 'lib/ui/native.dart', source: source);
    expect(findings, hasLength(1));
    expect(findings.single.message, contains("'dart:ffi'"));
    expect(findings.single.message, contains('lib/egress/'));
  });

  test('Dart HTTP imports with clauses are all detected', () {
    const source =
        "import 'package:http/http.dart' show Client;\n"
        "import 'package:http/http.dart' hide BaseClient;\n"
        "import 'package:http/http.dart' deferred as http;\n";
    final findings = scanDartSource(file: 'lib/ui/http.dart', source: source);
    expect(findings, hasLength(3));
    expect(findings.map((finding) => finding.line), [1, 2, 3]);
  });

  test('an http import inside lib/egress/ is permitted', () {
    final path = '$fixtures/inside.dart';
    final findings = scanDartSource(
      file: 'lib/egress/transport.dart',
      source: File(path).readAsStringSync(),
    );
    expect(findings, isEmpty);
  });

  test('the default allowlist holds exactly the one decided scope', () {
    expect(egressImportAllowlist, contains('lib/egress/'));
    expect(egressImportAllowlist, hasLength(1));
  });

  test('the denylist covers the enumerated HTTP-client packages', () {
    for (final name in [
      'http',
      'dio',
      'http2',
      'web_socket_channel',
      'cupertino_http',
      'cronet_http',
      'fetch_client',
      'oauth2',
      'grpc',
      'mqtt_client',
      'socket_io_client',
    ]) {
      expect(packageIsHttpClient(name), isTrue, reason: name);
    }
    expect(packageIsHttpClient('flutter'), isFalse);
    expect(packageIsHttpClient('image'), isFalse);
    expect(packageIsHttpClient('drift'), isFalse);
    expect(
      packageIsHttpClient('https_faker'),
      isFalse,
      reason: 'the ban is by exact package name, not prefix',
    );
  });

  test('a clean Dart file is clean', () {
    final path = '$fixtures/clean.dart';
    expect(
      scanDartSource(
        file: 'lib/ui/screen.dart',
        source: File(path).readAsStringSync(),
      ),
      isEmpty,
    );
  });

  group('the Kotlin sweep', () {
    test('a java.net socket import and usage are flagged', () {
      final path = '$fixtures/SocketFixture.kt';
      final findings = scanKotlinSource(
        file: path,
        source: File(path).readAsStringSync(),
      );
      expect(findings, isNotEmpty);
      final imports = findings.where((f) => f.message.contains('import'));
      expect(imports, hasLength(2), reason: 'one finding per banned import');
      expect(
        imports
            .where((f) => f.message.contains('import java.net.Socket'))
            .single,
        isNotNull,
      );
      expect(
        findings.where((f) => f.message.contains('HttpURLConnection')),
        isNotEmpty,
      );
      expect(findings.where((f) => f.message.contains('Socket(')), isEmpty);
    });

    test('date computation is flagged', () {
      final path = '$fixtures/DateFixture.kt';
      final findings = scanKotlinSource(
        file: path,
        source: File(path).readAsStringSync(),
      );
      expect(findings, isNotEmpty);
      expect(
        findings.where((f) => f.message.contains('System.currentTimeMillis')),
        isNotEmpty,
      );
      expect(
        findings.where((f) => f.message.contains('java.util.Date')),
        isNotEmpty,
      );
      expect(findings.where((f) => f.message.contains('Calendar')), isNotEmpty);
      expect(
        findings.where((f) => f.message.contains('java.time.')),
        isNotEmpty,
      );
    });

    test('a java.time star import is flagged (the whole package is the '
        'violation)', () {
      final path = '$fixtures/StarImportFixture.kt';
      final findings = scanKotlinSource(
        file: path,
        source: File(path).readAsStringSync(),
      );
      final date = findings.where(
        (f) => f.message.contains('date computation'),
      );
      expect(date, isNotEmpty);
      expect(date.first.message, contains('java.time.'));
      expect(date.first.line, 7);
    });

    test('NIO channels, indented imports, java.util wildcard and Date are '
        'flagged', () {
      const source = '''
    import static java.nio.channels.SocketChannel.open
    import java.util.*

    fun date(): Date = Date()
''';
      final findings = scanKotlinSource(
        file: 'test/fixtures/egress_imports/expanded.kt',
        source: source,
      );
      expect(
        findings.any(
          (finding) => finding.message.contains('java.nio.channels'),
        ),
        isTrue,
      );
      expect(
        findings.any((finding) => finding.message.contains('java.util.*')),
        isTrue,
      );
      expect(
        findings.where((finding) => finding.message.contains("'Date'")),
        isNotEmpty,
      );
    });

    test('fully-qualified java.net usage without an import is flagged', () {
      final path = '$fixtures/QualifiedSocketFixture.kt';
      final findings = scanKotlinSource(
        file: path,
        source: File(path).readAsStringSync(),
      );
      final qualified = findings
          .where((f) => f.message.contains('fully-qualified'))
          .toList();
      expect(qualified, isNotEmpty);
      expect(qualified.first.message, contains('java.net.Socket'));
    });

    test('an Apache HTTP import is flagged', () {
      final path = '$fixtures/ApacheHttpFixture.kt';
      final findings = scanKotlinSource(
        file: path,
        source: File(path).readAsStringSync(),
      );
      final import = findings.where((f) => f.message.contains('import'));
      expect(import, hasLength(1));
      expect(import.single.message, contains('org.apache.http.'));
    });

    test('a custom flavor source set is swept automatically', () async {
      final root = _makeTemp('flavor');
      Directory('${root.path}/lib').createSync(recursive: true);
      final flavorDir = '${root.path}/android/app/src/prodFlavor/kotlin/dev/x';
      Directory(flavorDir).createSync(recursive: true);
      File('$flavorDir/Leak.kt').writeAsStringSync(
        'import java.net.Socket\n'
        'class Leak\n'
        'fun open() = Socket("127.0.0.1", 1)\n',
      );
      final result = await Process.run('dart', [
        'run',
        'tool/check_egress_imports.dart',
        root.path,
      ]);
      expect(result.exitCode, 1);
      final out = result.stdout as String;
      expect(out, contains('prodFlavor'));
      expect(out, contains('java.net.Socket'));
    });

    test('the repo-clean shape is clean', () {
      final path = '$fixtures/CleanFixture.kt';
      expect(
        scanKotlinSource(file: path, source: File(path).readAsStringSync()),
        isEmpty,
      );
    });

    test('banned tokens in comments and strings are not findings', () {
      final path = '$fixtures/StringOnlyFixture.kt';
      expect(
        scanKotlinSource(file: path, source: File(path).readAsStringSync()),
        isEmpty,
      );
    });

    test('a symlinked Dart source is reported without following it', () async {
      final root = _makeTemp('dart_symlink');
      final target = File('${root.path}/outside.dart')
        ..writeAsStringSync("import 'package:http/http.dart';\n");
      final link = Link('${root.path}/lib/ui/linked.dart')
        ..createSync(target.path, recursive: true);
      final result = await Process.run('dart', [
        'run',
        'tool/check_egress_imports.dart',
        root.path,
      ]);
      expect(result.exitCode, 1);
      expect(result.stdout as String, contains('lib/ui/linked.dart'));
      expect(result.stdout as String, contains('symlinked source'));
      expect(link.existsSync(), isTrue);
    });

    test('symlinked Kotlin and Java source roots are reported', () async {
      final root = _makeTemp('native_symlink');
      Directory('${root.path}/lib').createSync();
      final src = Directory('${root.path}/android/app/src/main')
        ..createSync(recursive: true);
      final outside = Directory('${root.path}/outside')
        ..createSync(recursive: true);
      final kotlinTarget = Directory('${outside.path}/kotlin')
        ..createSync(recursive: true);
      final javaTarget = Directory('${outside.path}/java')
        ..createSync(recursive: true);
      Link('${src.path}/kotlin').createSync(kotlinTarget.path);
      Link('${src.path}/java').createSync(javaTarget.path);
      final result = await Process.run('dart', [
        'run',
        'tool/check_egress_imports.dart',
        root.path,
      ]);
      expect(result.exitCode, 1);
      final out = result.stdout as String;
      expect(out, contains('android/app/src/main/kotlin'));
      expect(out, contains('android/app/src/main/java'));
      expect(out, contains('symlinked source'));
    });
  });

  group('the executable', () {
    Directory fixtureRoot() {
      final root = _makeTemp('cli');
      Directory('${root.path}/lib/ui').createSync(recursive: true);
      Directory('${root.path}/lib/egress').createSync(recursive: true);
      File('${root.path}/lib/egress/transport.dart')
          .writeAsStringSync("import 'package:http/http.dart';\n");
      return root;
    }

    test('exits 1 and prints file:line for a Dart HTTP import outside '
        'lib/egress/', () async {
      final root = fixtureRoot();
      File('${root.path}/lib/ui/screen.dart')
          .writeAsStringSync("import 'package:http/http.dart';\n");
      final result = await Process.run('dart', [
        'run',
        'tool/check_egress_imports.dart',
        root.path,
      ]);
      expect(result.exitCode, 1);
      final out = result.stdout as String;
      expect(out, matches(RegExp(r'screen\.dart:\d+:')));
      expect(out, contains('package:http/http.dart'));
      expect(out, contains('egress import check FAILED'));
    });

    test('exits 0 when only lib/egress/ holds an HTTP import', () async {
      final root = fixtureRoot();
      final result = await Process.run('dart', [
        'run',
        'tool/check_egress_imports.dart',
        root.path,
      ]);
      expect(result.exitCode, 0);
      expect(result.stdout as String, contains('egress import check passed'));
    });

    test('exits 1 for a socket in the app\'s Kotlin', () async {
      final root = fixtureRoot();
      final ktDir = '${root.path}/android/app/src/main/kotlin/dev/x';
      Directory(ktDir).createSync(recursive: true);
      File('$ktDir/Leak.kt').writeAsStringSync(
        'import java.net.Socket\n'
        'class Leak\n'
        'fun open() = Socket("127.0.0.1", 1)\n',
      );
      final result = await Process.run('dart', [
        'run',
        'tool/check_egress_imports.dart',
        root.path,
      ]);
      expect(result.exitCode, 1);
      final out = result.stdout as String;
      expect(out, contains('Leak.kt'));
      expect(out, contains('java.net.Socket'));
    });

    test(
      'eval/ is outside the sweep — its http import is not a finding',
      () async {
        final root = fixtureRoot();
        Directory('${root.path}/eval/bin').createSync(recursive: true);
        File('${root.path}/eval/bin/harness.dart')
            .writeAsStringSync("import 'package:http/http.dart';\n");
        final result = await Process.run('dart', [
          'run',
          'tool/check_egress_imports.dart',
          root.path,
        ]);
        expect(result.exitCode, 0);
        expect(result.stdout as String, contains('egress import check passed'));
      },
    );
  });
}

// ignore_for_file: avoid_print
//
// The egress import seal, first of three (AD-7, story 4.2): no HTTP
// client may be imported and no socket may be opened anywhere in app
// code except `lib/egress/` — and the app's own Kotlin sources may
// reach no socket or connection API and compute no date at all (AD-4,
// AD-11). The Dart half catches an opener arriving as a package
// import; the Kotlin half catches one arriving as hand-written native
// code. (A native SDK arriving as a Gradle dependency or a
// manifest-initialised component is invisible to this check — that is
// what seals two and three are for.)
//
// Scope: `lib/`, `packages/`, `tool/`, `test/` — excluding
// `test/fixtures/`, which holds this check's own fixtures — plus every
// `.kt`/`.java` file under `android/app/src/*/kotlin|java`. `eval/` is
// deliberately outside: it is not app code (story 4-1), and its one
// http import is the legitimate exception the seal is designed around.
//
// Scans run over the masked source (comments and string literals
// blanked, directive URIs kept) via check_core_purity's masking, so an
// import-shaped line inside a string literal cannot false-positive.
//
// Output contract (the tool checks' own): one `file:line: message`
// line per finding, exit 1 when any finding exists, exit 2 when there
// is no lib/ to seal.
import 'dart:io';

import 'check_core_purity.dart';

/// Directory prefixes (repo-relative, forward slashes, trailing slash =
/// directory scope) where HTTP-client imports and socket identifiers
/// are legal. Grown only by explicit decision (AD-7).
const List<String> egressImportAllowlist = [
  'lib/egress/', // the single egress chokepoint — the only HTTP opener
];

/// HTTP-client packages (by package name) whose import is forbidden
/// outside the allowlist.
///
/// Residual risk, stated plainly: this ban is by package name, and FFI
/// (`dart:ffi`) can always open a socket without any of them — that
/// escape is covered by the other two egress seals (the resolved
/// Gradle graph and the merged-manifest sets), which is precisely why
/// AD-7 seals the chokepoint three ways instead of one.
const Set<String> httpClientPackageDenylist = {
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
};

/// Socket identifiers forbidden outside the allowlist (dart:io's own
/// shapes included — `HttpClient` covers `dart:io`'s client).
const Set<String> dartSocketIdentifiers = {
  'HttpClient',
  'Socket',
  'SecureSocket',
  'WebSocket',
  'RawSocket',
  'RawDatagramSocket',
};

/// True when [packageName] names a banned HTTP-client package.
bool packageIsHttpClient(String packageName) =>
    httpClientPackageDenylist.contains(packageName);

/// The directories the Dart sweep owns, relative to the repository
/// root (`eval/` is outside the app by design, story 4-1).
const List<String> dartScopeRoots = ['lib', 'packages', 'tool', 'test'];

/// Discovers the Kotlin/Java source-set roots under
/// `android/app/src` generically — every variant (or flavor) source
/// set's `kotlin`/`java` tree, so a future flavor is swept
/// automatically instead of by hand-editing a list.
List<String> kotlinSourceRoots(Directory androidSrc) {
  if (!androidSrc.existsSync()) {
    return const [];
  }
  final roots = <String>[];
  for (final sourceSet
      in androidSrc.listSync(followLinks: false).whereType<Directory>()) {
    for (final kind in const ['kotlin', 'java']) {
      final dir = Directory('${sourceSet.path}/$kind');
      if (dir.existsSync()) {
        roots.add(dir.path);
      }
    }
  }
  roots.sort();
  return roots;
}

/// Socket/connection imports forbidden in the app's Kotlin (and Java):
/// the java.net/javax.net socket families, okhttp3, and the legacy
/// Apache HTTP client. Captures the whole import statement so findings
/// can name it.
final RegExp _kotlinConnectionImportRegExp = RegExp(
  r'^(import\s+(?:java\.net\.|javax\.net\.|okhttp3\.|org\.apache\.http\.)\S+)',
  multiLine: true,
);

/// Fully-qualified socket/connection usage anywhere in code —
/// `java.net.Socket("…")` needs no import line, so the import rule
/// alone is escapable. okhttp3's qualified form is included on the
/// same reasoning.
final RegExp _kotlinQualifiedConnectionRegExp = RegExp(
  r'\b(?:java\.net\.|javax\.net\.|okhttp3\.)\S+',
);

/// Socket/connection identifiers forbidden in the app's Kotlin outside
/// import lines.
final RegExp _kotlinConnectionIdentifierRegExp = RegExp(
  r'\b(?:Socket|ServerSocket|DatagramSocket|MulticastSocket'
  r'|HttpURLConnection|URLConnection|URL|OkHttpClient)\b',
);

/// Date-computation imports and usages forbidden in the app's Kotlin
/// (AD-4: dates are the core's authority, computed nowhere else;
/// AD-11: the channels may not compute them) — on import lines
/// included, because importing the API is already the violation. The
/// `java.time.` alternative consumes its whole qualified tail, so a
/// star import (`import java.time.*`) is caught too.
final RegExp _kotlinDateComputationRegExp = RegExp(
  r'\b(?:java\.util\.Date\b|Calendar\b|java\.time\.\S+'
  r'|System\.currentTimeMillis\b)',
);

/// A directive span: the keyword at a line start or immediately after a
/// preceding directive's semicolon, through URIs and configuration, to
/// the terminating `;` — the same shape check_core_purity scans.
final RegExp _directiveRegExp = RegExp(
  "(?:^|;)[ \\t]*(import|export|part(?:[ \\t]+of)?)(?:[^;'\"|'[^']*'|\"[^\"]*\")*;",
  multiLine: true,
);

final RegExp _quotedUriRegExp = RegExp("'([^']*)'|\"([^\"]*)\"");

final RegExp _socketIdentifierRegExp = RegExp(
  r'\b(?:HttpClient|Socket|SecureSocket|WebSocket|RawSocket|RawDatagramSocket)\b',
);

int _lineOf(String text, int index) =>
    '\n'.allMatches(text.substring(0, index)).length + 1;

String _normalize(String path) =>
    path.replaceAll('\\', '/').replaceFirst('./', '');

/// Scans one Dart file's source for HTTP-client imports and socket
/// identifiers outside the allowlist.
List<Finding> scanDartSource({
  required String file,
  required String source,
  List<String> allowlist = egressImportAllowlist,
}) {
  final findings = <Finding>[];
  final normalized = _normalize(file);
  final allowed = allowlist.any(normalized.startsWith);
  if (allowed) {
    return findings;
  }
  final masked = maskCommentsAndStrings(source);
  for (final directive in _directiveRegExp.allMatches(masked)) {
    final span = directive.group(0)!;
    for (final quoted in _quotedUriRegExp.allMatches(span)) {
      final uri = quoted.group(1) ?? quoted.group(2) ?? '';
      if (!uri.startsWith('package:')) {
        continue;
      }
      final packageName = uri.substring(8).split('/').first;
      if (!packageIsHttpClient(packageName)) {
        continue;
      }
      findings.add(
        Finding(
          file,
          _lineOf(masked, directive.start + quoted.start),
          "HTTP-client import '$uri' is legal only inside "
          '${allowlist.join(', ')} (AD-7 egress seal)',
        ),
      );
    }
  }
  for (final match in _socketIdentifierRegExp.allMatches(masked)) {
    findings.add(
      Finding(
        file,
        _lineOf(masked, match.start),
        "socket identifier '${match.group(0)}' is legal only inside "
        '${allowlist.join(', ')} (AD-7 egress seal)',
      ),
    );
  }
  findings.sort((a, b) => a.line.compareTo(b.line));
  return findings;
}

/// Scans one Kotlin (or Java) file's source for socket/connection APIs
/// and date computation (AD-4, AD-7, AD-11). There is no allowlist:
/// the app's native code may open no socket and compute no date at all.
List<Finding> scanKotlinSource({required String file, required String source}) {
  final findings = <Finding>[];
  final masked = maskCommentsAndStrings(source);
  for (final match in _kotlinConnectionImportRegExp.allMatches(masked)) {
    findings.add(
      Finding(
        file,
        _lineOf(masked, match.start),
        "socket/connection import '${match.group(1)}' is banned in the "
        "app's Kotlin — sockets live only in lib/egress/ (AD-7, AD-11)",
      ),
    );
  }
  final importLines = <int>{};
  for (final match in RegExp(
    r'^import\b',
    multiLine: true,
  ).allMatches(masked)) {
    importLines.add(_lineOf(masked, match.start));
  }
  void reportMatches(
    RegExp pattern,
    String Function(String) message, {
    bool skipImportLines = false,
  }) {
    for (final match in pattern.allMatches(masked)) {
      final line = _lineOf(masked, match.start);
      if (skipImportLines && importLines.contains(line)) {
        continue; // import lines carry their own, more precise findings
      }
      findings.add(Finding(file, line, message(match.group(0)!)));
    }
  }

  reportMatches(
    _kotlinConnectionIdentifierRegExp,
    (token) =>
        "socket/connection API '$token' is banned in the app's "
        'Kotlin — sockets live only in lib/egress/ (AD-7, AD-11)',
    skipImportLines: true,
  );
  reportMatches(
    _kotlinQualifiedConnectionRegExp,
    (token) =>
        "fully-qualified socket/connection usage '$token' is banned in "
        "the app's Kotlin — sockets live only in lib/egress/ "
        '(AD-7, AD-11)',
    skipImportLines: true,
  );
  reportMatches(
    _kotlinDateComputationRegExp,
    (token) =>
        "date computation '$token' is banned in the app's Kotlin — "
        "dates are the core's authority (AD-4, AD-11)",
  );
  findings.sort((a, b) => a.line.compareTo(b.line));
  return findings;
}

/// Collects every file with one of [extensions] under [root]
/// recursively.
List<File> _collectFiles(Directory root, Set<String> extensions) {
  final files = <File>[];
  void walk(Directory dir) {
    for (final entity in dir.listSync(followLinks: false)) {
      if (entity is Directory) {
        final name = entity.uri.pathSegments.where((s) => s.isNotEmpty).last;
        if (name != '.dart_tool') {
          walk(entity);
        }
      } else if (entity is File) {
        final dot = entity.path.lastIndexOf('.');
        if (dot >= 0 && extensions.contains(entity.path.substring(dot))) {
          files.add(entity);
        }
      }
    }
  }

  walk(root);
  files.sort((a, b) => a.path.compareTo(b.path));
  return files;
}

/// Runs the whole check against [repoRoot], printing one
/// `file:line: message` line per finding. Returns the process exit
/// code: 0 clean, 1 findings, 2 no lib/ to seal.
Future<int> runCheck([String repoRoot = '']) async {
  final root = repoRoot.isEmpty ? '' : '$repoRoot/';
  final libDir = Directory('${root}lib');
  if (!libDir.existsSync()) {
    stderr.writeln('lib/ not found at ${libDir.path}');
    return 2;
  }
  final findings = <Finding>[];
  for (final scope in dartScopeRoots) {
    final dir = Directory('$root$scope');
    if (!dir.existsSync()) {
      continue;
    }
    for (final file in _collectFiles(dir, {'.dart'})) {
      // Paths are reported — and matched against the allowlist —
      // relative to the scanned root, so an absolute root still seals
      // correctly.
      final scoped = root.isEmpty
          ? file.path
          : file.path.substring(root.length);
      if (_normalize(scoped).startsWith('test/fixtures/')) {
        continue;
      }
      findings.addAll(
        scanDartSource(file: scoped, source: file.readAsStringSync()),
      );
    }
  }
  for (final scopeRoot in kotlinSourceRoots(
    Directory('${root}android/app/src'),
  )) {
    final dir = Directory(scopeRoot);
    for (final file in _collectFiles(dir, {'.kt', '.java'})) {
      final scoped = root.isEmpty
          ? file.path
          : file.path.substring(root.length);
      findings.addAll(
        scanKotlinSource(file: scoped, source: file.readAsStringSync()),
      );
    }
  }
  for (final finding in findings) {
    print(finding);
  }
  if (findings.isNotEmpty) {
    print(
      'egress import check FAILED: ${findings.length} finding(s) — HTTP '
      'clients live only in lib/egress/, and the app\'s Kotlin opens no '
      'socket and computes no date (AD-7)',
    );
    return 1;
  }
  print('egress import check passed');
  return 0;
}

Future<void> main(List<String> args) async {
  exit(await runCheck(args.isEmpty ? '' : args.first));
}

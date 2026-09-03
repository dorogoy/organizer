// ignore_for_file: avoid_print
//
// The store seal (AD-21): no persistence API may be touched outside the
// store module — the log and the pool are the only replayable domain
// stores, and "no preferences, no side files, nothing outside the pool
// and log" must fail the build, not depend on review. Story 4.3 grows
// the seal to the shape AD-21 always stated (the anticipated
// evolution): the Files module arrives beside Store, a dart:io rule
// closes the side-file gap the import allowlist could not see, and a
// Kotlin sweep closes the native half — Keystore/crypto APIs live in
// exactly one allowlisted file (the credential wrapping key's own
// service) and file APIs live in no Kotlin file at all (Files is
// Dart-side only).
//
// Persistence-package imports — drift*, sqlite3*, sqflite*,
// shared_preferences* plus the named denylist below — are legal only
// inside the directories on [persistenceImportAllowlist]. The
// allowlist is a named constant grown only by explicit decision;
// today it holds `lib/store/` (the drift adapter, AD-21's Store),
// `lib/files/` (the Files adapter, Story 4.3 — the credential
// vault's envelope storage and later the scan cache and album
// bytes), `test/store/` (the adapter's own in-memory drift tests)
// and `test/files/` (the Files adapter's own temp-dir tests).
//
// The dart:io rule: no `dart:io` import under `lib/` outside
// [dartIoAllowlist] — the stated gap ("relative imports of vendored
// persistence code and dart:io/dart:ffi side-file writes are
// unguarded", now closed for lib/): side files are Files' business
// or nobody's. tool/ and test/ stay outside this rule by decision —
// the checks and tests read the tree they police.
//
// The Kotlin sweep: Keystore/crypto APIs (`java.security.KeyStore`,
// `android.security.keystore.*`, `javax.crypto.*` and their
// identifiers) are legal in exactly [keystoreAllowlistedFile] — the
// one closed native exception AD-21 states ("CredentialVault's
// AndroidKeyStore access for the wrapping key") — and file APIs
// (`java.io.File*` and their identifiers) are legal in no Kotlin
// file: envelope storage is the Dart Files adapter's job, so the
// native half can never grow a side-channel store of its own.
//
// Scope: `lib/`, `packages/core/`, `tool/`, `test/` — excluding
// `test/fixtures/`, which holds this check's own fixtures — plus
// every `.kt`/`.java` file under `android/app/src/*/kotlin|java`.
// Scans run over the masked source (comments and string literals
// blanked, directive URIs kept) via check_core_purity's masking, so
// an import-shaped line inside a string literal cannot false-positive.
//
// Output contract (Story 1.1 AC 2): one `file:line: message` line per
// finding, exit 1 when any finding exists.
import 'dart:io';

import 'check_core_purity.dart';
import 'check_egress_imports.dart' show kotlinSourceRoots;

/// Directory prefixes (repo-relative, forward slashes, trailing slash =
/// directory scope) where persistence imports are legal. Grown only by
/// explicit decision (AD-21).
const List<String> persistenceImportAllowlist = [
  'lib/store/', // the drift adapter — Store owns the two tables (AD-21)
  'lib/files/', // the Files adapter — app-private bytes (Story 4.3)
  'test/store/', // the adapter's in-memory drift tests (explicit decision)
  'test/files/', // the Files adapter's temp-dir tests (Story 4.3)
];

/// Directory prefixes (repo-relative) where a `dart:io` import is legal
/// under `lib/` — the store and files modules alone: side files are
/// Files' business or nobody's (Story 4.3, AD-21).
const List<String> dartIoAllowlist = [
  'lib/store/', // the drift adapter's own file plumbing
  'lib/files/', // the Files adapter is dart:io's one shell home
];

/// The one Kotlin file where Keystore/crypto APIs are legal (AD-21's
/// one closed native exception): the credential wrapping key's own
/// service. Matched against the exact normalized repo path — a
/// decoy same-named file in another source set is not the service
/// and must fail, exactly as a real one must pass.
const String keystoreAllowlistedPath =
    'android/app/src/main/kotlin/dev/dorogoy/organizer/CredentialKeystore.kt';

/// Package-name prefixes whose every package is a persistence API.
const Set<String> persistenceImportPrefixes = {
  'drift',
  'sqlite3',
  'sqflite',
  'shared_preferences',
};

/// Named persistence packages the prefixes above do not already cover.
const Set<String> persistedPackageDenylist = {
  'hive',
  'hive_flutter',
  'isar',
  'isar_flutter_libs',
  'objectbox',
  'objectbox_flutter_libs',
  'sembast',
  'sembast_web',
  'realm',
  'realm_dart',
  'couchbase_lite_dart',
  'flutter_secure_storage',
  'get_storage',
  'mmkv',
};

/// True when [packageName] names a persistence package under the seal.
bool packageIsPersistence(String packageName) =>
    persistenceImportPrefixes.any(packageName.startsWith) ||
    persistedPackageDenylist.contains(packageName);

/// A directive span: the keyword at a line start or immediately after a
/// preceding directive's semicolon, through URIs and
/// configuration, to the terminating `;` — the same shape
/// check_core_purity scans.
final RegExp _directiveRegExp = RegExp(
  "(?:^|;)[ \\t]*(import|export|part(?:[ \\t]+of)?)(?:[^;'\"|'[^']*'|\"[^\"]*\")*;",
  multiLine: true,
);

final RegExp _quotedUriRegExp = RegExp("'([^']*)'|\"([^\"]*)\"");

int _lineOf(String text, int index) =>
    '\n'.allMatches(text.substring(0, index)).length + 1;

String _normalize(String path) =>
    path.replaceAll('\\', '/').replaceFirst('./', '');

const Set<String> rawStoreLibraries = {
  'package:organizer/store/connection.dart',
  'package:organizer/store/substrate.dart',
};

/// Scans one file's source for persistence imports outside the allowlist.
List<Finding> scanSource({
  required String file,
  required String source,
  List<String> allowlist = persistenceImportAllowlist,
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
      if (rawStoreLibraries.contains(uri)) {
        findings.add(
          Finding(
            file,
            _lineOf(masked, directive.start + quoted.start),
            "raw store library '$uri' is legal only inside "
            '${allowlist.join(', ')} (AD-21 store seal)',
          ),
        );
        continue;
      }
      if (!uri.startsWith('package:')) {
        continue;
      }
      final packageName = uri.substring(8).split('/').first;
      if (packageName.isEmpty || !packageIsPersistence(packageName)) {
        continue;
      }
      findings.add(
        Finding(
          file,
          _lineOf(masked, directive.start + quoted.start),
          "persistence import '$uri' is legal only inside "
          '${allowlist.join(', ')} (AD-21 store seal)',
        ),
      );
    }
  }
  findings.sort((a, b) => a.line.compareTo(b.line));
  return findings;
}

/// The directories this check owns, relative to the repository root.
const List<String> scopeRoots = ['lib', 'packages/core', 'tool', 'test'];

/// Scans one Dart file's source for a `dart:io` import outside
/// [dartIoAllowlist] — the side-file gap closed (Story 4.3): under
/// `lib/`, only the store and files modules may touch the local
/// filesystem at all.
List<Finding> scanDartIoSource({
  required String file,
  required String source,
  List<String> allowlist = dartIoAllowlist,
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
      if (uri == 'dart:io') {
        findings.add(
          Finding(
            file,
            _lineOf(masked, directive.start + quoted.start),
            "a 'dart:io' import is legal under lib/ only inside "
            '${allowlist.join(', ')} — side files are Files\' business '
            'or nobody\'s (AD-21 store seal, Story 4.3)',
          ),
        );
      }
    }
  }
  findings.sort((a, b) => a.line.compareTo(b.line));
  return findings;
}

/// Keystore/crypto imports forbidden in every swept Kotlin file but
/// [keystoreAllowlistedFile]. Captures the whole import statement so
/// findings can name it.
final RegExp _kotlinCryptoImportRegExp = RegExp(
  r'^([ \t]*import\s+(?:static\s+)?(?:java\.security\.|'
  r'android\.security\.keystore\.|javax\.crypto\.)\S+)',
  multiLine: true,
);

/// Fully-qualified Keystore/crypto usage anywhere in code —
/// `javax.crypto.Cipher.getInstance(...)` needs no import line, so
/// the import rule alone is escapable.
final RegExp _kotlinCryptoQualifiedRegExp = RegExp(
  r'\b(?:java\.security\.|android\.security\.keystore\.|javax\.crypto\.)'
  r'[A-Za-z_]\w*',
);

/// Keystore/crypto identifiers forbidden outside import lines in every
/// swept Kotlin file but [keystoreAllowlistedFile].
final RegExp _kotlinCryptoIdentifierRegExp = RegExp(
  r'\b(?:KeyStore|KeyGenerator|KeyGenParameterSpec|KeyProperties'
  r'|KeyPermanentlyInvalidatedException|UserNotAuthenticatedException'
  r'|KeyAgreement|KeyPairGenerator|KeyPair|PrivateKey|PublicKey'
  r'|SecretKey|SecretKeySpec|KeyManagerFactory|TrustManagerFactory'
  r'|SecureRandom|Cipher|Mac|AEADBadTagException'
  r'|GCMParameterSpec|IvParameterSpec)\b',
);

/// File APIs forbidden in every swept Kotlin file without exception
/// (Files is Dart-side only): imports of the `java.io.File*` family.
final RegExp _kotlinFileImportRegExp = RegExp(
  r'^([ \t]*import\s+(?:static\s+)?java\.io\.File\w*)',
  multiLine: true,
);

/// Fully-qualified file-API usage anywhere in code.
final RegExp _kotlinFileQualifiedRegExp = RegExp(r'\bjava\.io\.File\w*');

/// File-API identifiers forbidden outside import lines — a bare
/// `File(...)` construction needs no import to reach the filesystem.
final RegExp _kotlinFileIdentifierRegExp = RegExp(
  r'\b(?:File|FileInputStream|FileOutputStream|FileReader|FileWriter'
  r'|RandomAccessFile)\b',
);

/// Side-channel store APIs forbidden in every swept Kotlin file
/// without exception: the Context methods that write app-private
/// files or preferences without ever naming `java.io.File`, and the
/// NIO file writers the import rule above cannot see. An identifier
/// match catches both the call and any import line naming it.
final RegExp _kotlinSideChannelStoreRegExp = RegExp(
  r'\b(?:openFileOutput|getFilesDir|getCacheDir|getExternalFilesDir'
  r'|getSharedPreferences)\b',
);

/// The NIO file family, imported or fully qualified — `java.nio
/// .file.Files`/`Paths` write files while looking like nothing the
/// `java.io` rule polices.
final RegExp _kotlinNioFileImportRegExp = RegExp(
  r'^([ \t]*import\s+(?:static\s+)?java\.nio\.file\.(?:(?:Files|Paths)\b|\*)\S*)',
  multiLine: true,
);

final RegExp _kotlinNioFileQualifiedRegExp = RegExp(
  r'\bjava\.nio\.file\.(?:Files|Paths)\b',
);

/// Scans one Kotlin (or Java) file's source for the seal's native
/// rules: Keystore/crypto APIs outside [keystoreAllowlistedPath]
/// (the exact normalized path — a decoy same-named file elsewhere
/// fails), and file or side-channel store APIs everywhere — the
/// native half cannot grow a store of its own.
List<Finding> scanKotlinSource({required String file, required String source}) {
  final findings = <Finding>[];
  final masked = maskCommentsAndStrings(source);
  final cryptoAllowed = _normalize(file) == keystoreAllowlistedPath;
  final importLines = <int>{};
  for (final match in RegExp(
    r'^[ \t]*import\b',
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

  if (!cryptoAllowed) {
    for (final match in _kotlinCryptoImportRegExp.allMatches(masked)) {
      findings.add(
        Finding(
          file,
          _lineOf(masked, match.start),
          "Keystore/crypto import '${match.group(1)}' is legal in exactly "
          '$keystoreAllowlistedPath — the wrapping key\'s own service '
          '(AD-21 store seal, Story 4.3)',
        ),
      );
    }
    reportMatches(
      _kotlinCryptoQualifiedRegExp,
      (token) =>
          "fully-qualified Keystore/crypto usage '$token' is legal in "
          'exactly $keystoreAllowlistedPath (AD-21 store seal, Story 4.3)',
      skipImportLines: true,
    );
    reportMatches(
      _kotlinCryptoIdentifierRegExp,
      (token) =>
          "Keystore/crypto API '$token' is legal in exactly "
          '$keystoreAllowlistedPath (AD-21 store seal, Story 4.3)',
      skipImportLines: true,
    );
  }
  for (final match in _kotlinFileImportRegExp.allMatches(masked)) {
    findings.add(
      Finding(
        file,
        _lineOf(masked, match.start),
        "file-API import '${match.group(1)}' is legal in no Kotlin file — "
        'Files is Dart-side only (AD-21 store seal, Story 4.3)',
      ),
    );
  }
  reportMatches(
    _kotlinFileQualifiedRegExp,
    (token) =>
        "file-API usage '$token' is legal in no Kotlin file — Files is "
        'Dart-side only (AD-21 store seal, Story 4.3)',
    skipImportLines: true,
  );
  reportMatches(
    _kotlinFileIdentifierRegExp,
    (token) =>
        "file-API identifier '$token' is legal in no Kotlin file — Files "
        'is Dart-side only (AD-21 store seal, Story 4.3)',
    skipImportLines: true,
  );
  reportMatches(
    _kotlinSideChannelStoreRegExp,
    (token) =>
        "side-channel store API '$token' is legal in no Kotlin file — "
        'app-private writes and preferences are the Dart Files adapter\'s '
        'alone (AD-21 store seal, Story 4.3)',
  );
  for (final match in _kotlinNioFileImportRegExp.allMatches(masked)) {
    findings.add(
      Finding(
        file,
        _lineOf(masked, match.start),
        "NIO file import '${match.group(1)}' is legal in no Kotlin file — "
        'Files is Dart-side only (AD-21 store seal, Story 4.3)',
      ),
    );
  }
  reportMatches(
    _kotlinNioFileQualifiedRegExp,
    (token) =>
        "NIO file usage '$token' is legal in no Kotlin file — Files is "
        'Dart-side only (AD-21 store seal, Story 4.3)',
    skipImportLines: true,
  );
  findings.sort((a, b) => a.line.compareTo(b.line));
  return findings;
}

/// Collects every `.dart` file under [root] recursively.
List<File> _collectFiles(Directory root) {
  final files = <File>[];
  void walk(Directory dir) {
    for (final entity in dir.listSync(followLinks: false)) {
      if (entity is Directory) {
        final name = entity.uri.pathSegments.where((s) => s.isNotEmpty).last;
        if (name != '.dart_tool') {
          walk(entity);
        }
      } else if (entity is File && entity.path.endsWith('.dart')) {
        files.add(entity);
      }
    }
  }

  walk(root);
  files.sort((a, b) => a.path.compareTo(b.path));
  return files;
}

/// Collects every `.kt`/`.java` file under [root] recursively.
List<File> _collectKotlinFiles(Directory root) {
  final files = <File>[];
  void walk(Directory dir) {
    for (final entity in dir.listSync(followLinks: false)) {
      if (entity is Directory) {
        walk(entity);
      } else if (entity is File &&
          (entity.path.endsWith('.kt') || entity.path.endsWith('.java'))) {
        files.add(entity);
      }
    }
  }

  walk(root);
  files.sort((a, b) => a.path.compareTo(b.path));
  return files;
}

/// Runs the whole check against [repoRoot], printing one
/// `file:line: message` line per finding. Returns the process exit code:
/// 0 clean, 1 findings, 2 no lib/ to seal.
Future<int> runCheck([String repoRoot = '']) async {
  final root = repoRoot.isEmpty ? '' : '$repoRoot/';
  final libDir = Directory('${root}lib');
  if (!libDir.existsSync()) {
    stderr.writeln('lib/ not found at ${libDir.path}');
    return 2;
  }
  final findings = <Finding>[];
  for (final scope in scopeRoots) {
    final dir = Directory('$root$scope');
    if (!dir.existsSync()) {
      continue;
    }
    for (final file in _collectFiles(dir)) {
      // Paths are reported — and matched against the allowlist — relative
      // to the scanned root, so an absolute root still seals correctly.
      final scoped = root.isEmpty
          ? file.path
          : file.path.substring(root.length);
      if (_normalize(scoped).startsWith('test/fixtures/')) {
        continue;
      }
      findings.addAll(
        scanSource(file: scoped, source: file.readAsStringSync()),
      );
      // The dart:io rule polices `lib/` alone: side files under lib/
      // are Files' business or nobody's, while tool/ and test/ read
      // the very tree they police (recorded decision above).
      if (_normalize(scoped).startsWith('lib/')) {
        findings.addAll(
          scanDartIoSource(file: scoped, source: file.readAsStringSync()),
        );
      }
    }
  }
  final androidSrc = Directory('${root}android/app/src');
  for (final scopeRoot in kotlinSourceRoots(androidSrc)) {
    for (final file in _collectKotlinFiles(Directory(scopeRoot))) {
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
      'store seal check FAILED: ${findings.length} finding(s) — persistence '
      'APIs live only in the store and files modules, dart:io only beside '
      'them, Keystore/crypto only in $keystoreAllowlistedPath, and no file '
      'APIs in Kotlin at all (AD-21)',
    );
    return 1;
  }
  print('store seal check passed');
  return 0;
}

Future<void> main(List<String> args) async {
  exit(await runCheck(args.isEmpty ? '' : args.first));
}

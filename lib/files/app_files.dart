import 'dart:async';
import 'dart:io';

import 'package:core/ports/files_port.dart';
import 'package:path_provider/path_provider.dart';

/// The Files scope the credential vault stores its envelopes under
/// (Story 4.3, AD-22) — one flat partition inside the app-private
/// root, one blob per provider id. An infrastructure identifier on
/// the files module's terms (AD-15's ban is on literals reaching a
/// widget), never user copy.
const String credentialFilesScope = 'credentials';

/// The temp file's name suffix while a write stages its bytes before
/// the rename — an infrastructure identifier on the terms above.
const String stagingSuffix = '.tmp';

/// A path segment's two separators (both, whatever the host) — the
/// characters a traversal-refused scope or name may not carry. Named
/// infrastructure identifiers on the terms above.
const String segmentSlash = '/';
const String segmentBackslash = '\\';

/// The two dot segments that mean "here" and "one level up" — a
/// traversal-refused segment may be neither. Named infrastructure
/// identifiers on the terms above.
const String selfSegment = '.';
const String parentSegment = '..';

/// The NUL byte — no path segment may carry it. A named
/// infrastructure identifier on the terms above.
const String segmentNulCharacter = '\u0000';

/// The shell adapter over app-private byte storage (Story 4.3,
/// AD-21, AD-22): the FilesPort's platform half over path_provider's
/// support directory plus dart:io's write-to-temp-then-rename. The
/// scope partitioning and the traversal refusal are the adapter's
/// whole policy: every [scope] and [name] must be one clean path
/// segment — non-empty, no separator, not `.` or `..`, no NUL — so
/// no caller can compose its way out of the app-private root, and
/// the vault's provider ids never become paths the vault did not
/// validate first (the core's [isValidProviderId] is the same rule,
/// stated once). Paths compose through `Uri.pathSegments`, never
/// through separator literals, so the adapter itself could not build
/// a nested path if it wanted to.
///
/// One instance resolves its root once (lazily, on the first
/// operation — the root is async and main constructs the adapter
/// synchronously), with concurrent first operations sharing the one
/// in-flight resolution; main constructs this adapter once and
/// threads it to every consumer.
class AppFiles implements FilesPort {
  AppFiles({Future<Directory> Function()? rootOf})
    : _rootOf = rootOf ?? getApplicationSupportDirectory;

  final Future<Directory> Function() _rootOf;

  /// The one in-flight (or settled) root resolution — never a
  /// second concurrent call into path_provider.
  Future<Directory>? _rootFuture;

  /// The staging serial: one per attempted write, so two racing
  /// writes to one blob never share a staging file. A counter, not
  /// a clock — the adapter computes no time.
  int _stagingSerial = 0;

  Future<Directory> _resolvedRoot() {
    final standing = _rootFuture;
    if (standing != null) {
      return standing;
    }
    final resolving = _rootOf();
    _rootFuture = resolving;
    // A failed resolution is forgotten, so a later operation retries
    // instead of caching the failure forever.
    unawaited(
      resolving.then<void>(
        (_) {},
        onError: (Object _) {
          if (identical(_rootFuture, resolving)) {
            _rootFuture = null;
          }
        },
      ),
    );
    return resolving;
  }

  /// Appends one validated segment to a base URI — the adapter's
  /// only path composition, one segment deep by construction.
  static Uri _segmentUri(Uri base, String segment) => base.replace(
    pathSegments: [
      ...base.pathSegments.where((segment) => segment.isNotEmpty),
      segment,
    ],
  );

  Future<File> _blobFile(
    String scope,
    String name, {
    required bool create,
  }) async {
    final root = await _resolvedRoot();
    // A scope with no blobs yet has no directory yet: writes create
    // it on demand, reads and deletes only ever name the path.
    final dir = Directory.fromUri(_segmentUri(root.uri, scope));
    if (create) {
      await dir.create(recursive: true);
    }
    return File.fromUri(_segmentUri(dir.uri, name));
  }

  @override
  Future<List<int>?> read(String scope, String name) async {
    if (!_isCleanSegment(scope) || !_isCleanSegment(name)) {
      return null;
    }
    final file = await _blobFile(scope, name, create: false);
    // Absence is quiet on every path: no existsSync probe (a probe
    // answers a question the read itself answers atomically — the
    // gap between the two is a TOCTOU), and any filesystem refusal
    // to hand back the bytes reads as absent, never as a crash.
    try {
      return await file.readAsBytes();
    } on FileSystemException {
      return null;
    }
  }

  @override
  Future<void> write(String scope, String name, List<int> bytes) async {
    if (!_isCleanSegment(scope) || !_isCleanSegment(name)) {
      // The refusal is quiet and total: a traversal-shaped pair
      // writes nothing anywhere, exactly as the port's contract
      // demands — never an error surface, never a fallback path.
      return;
    }
    final file = await _blobFile(scope, name, create: true);
    // Atomic replacement: the bytes land in a sibling temp file
    // first, then one rename swaps it in. A reader racing the write
    // observes the old blob or the new one — never a half-written
    // one — and a failed write leaves the old blob intact. The
    // staging name carries the write's serial, so two racing writes
    // to one blob stage apart; the serial is a counter, never a
    // clock read.
    final staging = File(
      file.path + (_stagingSerial++).toString() + stagingSuffix,
    );
    try {
      await staging.writeAsBytes(bytes, flush: true);
      await staging.rename(file.path);
    } on FileSystemException {
      // Best-effort cleanup of the half-written staging file, then
      // the failure is the caller's (the vault's write discipline
      // swallows it there; the adapter never leaves a partial
      // standing in the blob's place).
      try {
        if (staging.existsSync()) {
          await staging.delete();
        }
      } on FileSystemException {
        // Nothing more this side can do: the staging file is not
        // the blob, and the blob still holds its previous bytes.
      }
      rethrow;
    }
  }

  @override
  Future<void> delete(String scope, String name) async {
    if (!_isCleanSegment(scope) || !_isCleanSegment(name)) {
      return;
    }
    final file = await _blobFile(scope, name, create: false);
    // Idempotent by construction: an absent file is not an error, a
    // missing scope directory stays missing — nothing is created on
    // the way out — and a filesystem refusal reads as the same
    // quiet outcome the caller asked for.
    try {
      if (file.existsSync()) {
        await file.delete();
      }
    } on FileSystemException {
      // Quiet: the delete's contract is idempotence, and the next
      // read measures whatever actually stands.
    }
  }

  /// One clean path segment: non-empty, no separator, no `.`, no
  /// `..`, no NUL — the port's traversal refusal, stated once.
  static bool _isCleanSegment(String segment) =>
      segment.isNotEmpty &&
      segment != selfSegment &&
      segment != parentSegment &&
      !segment.contains(segmentSlash) &&
      !segment.contains(segmentBackslash) &&
      !segment.contains(segmentNulCharacter);
}

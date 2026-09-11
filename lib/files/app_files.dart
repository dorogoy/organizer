import 'dart:async';
import 'dart:io';

import 'package:core/ports/files_port.dart';
import 'package:crypto/crypto.dart';
import 'package:path_provider/path_provider.dart';

/// The Files scope the credential vault stores its envelopes under
/// (Story 4.3, AD-22) — one flat partition inside the app-private
/// root, one blob per provider id. An infrastructure identifier on
/// the files module's terms (AD-15's ban is on literals reaching a
/// widget), never user copy.
const String credentialFilesScope = 'credentials';

/// The Files scope holding the per-scan cache (Story 5.2, FR-16,
/// FR-25): one subdirectory per scan — named by the scan's own clean
/// `scanId` segment — holding that scan's frame (and, from 5.4, its
/// capped copy) until every terminal path unlinks it. The reserved
/// name `FilesPort`'s own doc anticipated, on the same infrastructure
/// terms as the credentials scope.
const String scanCacheScope = 'scan_cache';

/// The frame file's name inside a scan's cache subdirectory (Story
/// 5.2): the JPEG bytes the camera wrote, named once here so no
/// caller composes a path the adapter did not validate. An
/// infrastructure identifier on the terms above.
const String scanFrameFileName = 'frame.jpg';

/// The capped copy's file name inside a scan's cache subdirectory
/// (Story 5.4, AD-8): fixed and extension-free, beside
/// [scanFrameFileName] — the resolution cap may re-encode to JPEG or
/// PNG, and the sniff (story 5.3) is the single mime truth, so the
/// name claims nothing a later re-encode could unmake. An
/// infrastructure identifier on the terms above.
const String scanCappedCopyName = 'capped';

/// The Files scope holding the transformation reward's album bytes
/// (Story 7.1, FR-17, AD-13): one flat partition inside the
/// app-private root — the scope `FilesPort`'s own doc reserved —
/// holding one content-addressed blob per photo. The bytes are
/// stored verbatim (no re-encode, no EXIF strip): they never upload,
/// and export is user-initiated (NFR4, Epic 9's seam). An
/// infrastructure identifier on the terms above.
const String albumFilesScope = 'album';

/// The album blob name's fixed suffix (AD-13): the content hash names
/// the blob — identity first, container claim second — and the
/// suffix never asserts a sniff the bytes did not make. An
/// infrastructure identifier on the terms above.
const String albumPhotoSuffix = '.jpg';

/// Writes one album photo, content-addressed (Story 7.1, FR-17,
/// AD-13): the sha256 hex of [bytes] plus [albumPhotoSuffix] is the
/// blob's name in the [albumFilesScope] partition, written through
/// the port's flat atomic write — staging then one rename — and the
/// name is the whole answer. Content addressing makes the write
/// idempotent by construction: the same bytes always name the same
/// blob, so a Before and an After that happen to be byte-identical
/// share one blob and no duplicate ever grows the album. The hash
/// lives in the shell — the core stays pure (AD-3) — and a throwing
/// write is the caller's to fold, exactly the vault's own discipline.
// ponytail: no cap on album growth — cap at write time here if
// storage ever needs one, never in the core.
Future<String> writeAlbumPhoto(FilesPort files, List<int> bytes) async {
  final name = sha256.convert(bytes).toString() + albumPhotoSuffix;
  await files.write(albumFilesScope, name, bytes);
  return name;
}

/// The scan writes' answer when no file exists to hand back (Story
/// 5.2's frame write and Story 5.4's capped-copy write alike): a
/// refused traversal-shaped segment, or a directory that would not
/// create. The empty path is the quiet fail-closed signal the scan
/// controller folds into its close, on the same terms above.
const String absentFramePath = '';

/// Best-effort deletion of one absolute file path outside the
/// adapter's own scopes (Story 5.2's review, P1): the camera plugin
/// writes its shot to the platform's cache before the app reads the
/// bytes, and that file — a person-bearing frame included — dies in
/// the same breath. Nothing this story ships sweeps the plugin's
/// cache, so the deletion is eager and best-effort: a path that would
/// not delete is a quiet nothing, never a failed shot. This module is
/// dart:io's one shell home (the store seal's own allowlist), which
/// is why the helper lives here and not beside the plugin wrap.
Future<void> deleteFileBestEffort(String path) async {
  try {
    final file = File(path);
    if (file.existsSync()) {
      await file.delete();
    }
  } on FileSystemException {
    // Quiet by contract: best-effort means the attempt, never the
    // outcome, and no caller's flow turns on this file's death.
  }
}

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

  @override
  Future<String> writeScanFrame(String scanId, List<int> bytes) async {
    if (!_isCleanSegment(scanId)) {
      // The quiet refusal, on the flat methods' own terms: a
      // traversal-shaped scanId writes nothing anywhere, and the
      // empty path tells the caller no frame exists to gate.
      return absentFramePath;
    }
    // The whole write is guarded against anything the platform can
    // throw — not just the filesystem family: the root resolution
    // itself can surface as a PlatformException (path_provider's
    // method channel), and the scan's quiet fail-closed contract
    // takes every flavour alike (the caller's failed-shot close
    // covers the empty path).
    try {
      final root = await _resolvedRoot();
      // Two validated segments, one composition at a time: the scope,
      // then the scan's own subdirectory — the only nesting the
      // port's scan vocabulary admits, and only through this method.
      final scanDir = Directory.fromUri(
        _segmentUri(_segmentUri(root.uri, scanCacheScope), scanId),
      );
      await scanDir.create(recursive: true);
      final file = File.fromUri(_segmentUri(scanDir.uri, scanFrameFileName));
      // Atomic like the flat write: the bytes land in a sibling temp
      // file first, then one rename swaps them in — the gate reads
      // the whole frame or none of it.
      final staging = File(
        file.path + (_stagingSerial++).toString() + stagingSuffix,
      );
      try {
        await staging.writeAsBytes(bytes, flush: true);
        await staging.rename(file.path);
        return file.path;
      } on Object {
        // writeAsBytes can succeed and rename fail: the sibling
        // staging file would otherwise linger. The scan's unlink is
        // the directory backstop; this is the write's own hygiene,
        // the flat `write` method's shape.
        try {
          if (staging.existsSync()) {
            await staging.delete();
          }
        } on FileSystemException {
          // Quiet: unlinkScan still takes the directory.
        }
        return absentFramePath;
      }
    } on Object {
      // Root resolution or directory create failed: nothing to
      // stage. The quiet empty path is the whole answer — a failed
      // frame write is the scan's fail-closed close, never a crash
      // and never a half-readable frame.
      return absentFramePath;
    }
  }

  @override
  Future<void> unlinkScan(String scanId) async {
    if (!_isCleanSegment(scanId)) {
      return;
    }
    try {
      final root = await _resolvedRoot();
      final scanDir = Directory.fromUri(
        _segmentUri(_segmentUri(root.uri, scanCacheScope), scanId),
      );
      // Idempotent by construction: an absent directory is not an
      // error, the scope directory itself stays — other scans' frames
      // are not this call's to touch — and a filesystem refusal reads
      // as the same quiet outcome the caller asked for.
      if (scanDir.existsSync()) {
        await scanDir.delete(recursive: true);
      }
    } on FileSystemException {
      // Quiet: the unlink's contract is idempotence, and 5.4's
      // `app_opened` sweep is the crash backstop for whatever a
      // refused delete left standing.
    }
  }

  @override
  Future<String> writeScanCappedCopy(String scanId, List<int> bytes) async {
    if (!_isCleanSegment(scanId)) {
      // The quiet refusal, the frame write's own terms: a
      // traversal-shaped scanId writes nothing anywhere, and the
      // empty path tells the caller no capped copy exists.
      return absentFramePath;
    }
    // The whole write is guarded against anything the platform can
    // throw, exactly as the frame write is: the root resolution
    // itself can surface as a PlatformException, and the quiet
    // fail-closed contract takes every flavour alike.
    try {
      final root = await _resolvedRoot();
      // Two validated segments, one composition at a time: the scope,
      // then the scan's own subdirectory — the same only-nesting the
      // frame write composes, so a scan's directory can hold no third
      // location by construction.
      final scanDir = Directory.fromUri(
        _segmentUri(_segmentUri(root.uri, scanCacheScope), scanId),
      );
      await scanDir.create(recursive: true);
      final file = File.fromUri(_segmentUri(scanDir.uri, scanCappedCopyName));
      // Atomic like the frame write: the bytes land in a sibling temp
      // file first, then one rename swaps them in — a reader sees the
      // whole capped copy or none of it.
      final staging = File(
        file.path + (_stagingSerial++).toString() + stagingSuffix,
      );
      try {
        await staging.writeAsBytes(bytes, flush: true);
        await staging.rename(file.path);
        return file.path;
      } on Object {
        // writeAsBytes can succeed and rename fail: the sibling
        // staging file would otherwise linger. The scan's unlink is
        // the directory backstop; this is the write's own hygiene,
        // the frame write's shape.
        try {
          if (staging.existsSync()) {
            await staging.delete();
          }
        } on FileSystemException {
          // Quiet: unlinkScan still takes the directory.
        }
        return absentFramePath;
      }
    } on Object {
      // Root resolution or directory create failed: nothing to
      // stage. The quiet empty path is the whole answer — never a
      // crash, never a half-readable copy.
      return absentFramePath;
    }
  }

  @override
  Future<void> sweepScanCache() async {
    try {
      final root = await _resolvedRoot();
      final scopeDir = Directory.fromUri(_segmentUri(root.uri, scanCacheScope));
      // Async like every other path here: the sweep runs at the
      // lifecycle opens that request the crash backstop and blocks the
      // platform isolate on the filesystem no
      // longer than the write paths do. A scope with no scans yet has
      // no directory: the fresh-install sweep is a no-op, and nothing
      // is created on the way out.
      if (!await scopeDir.exists()) {
        return;
      }
      // Blind by construction: the children are read here only to be
      // unlinked, and no child's name is returned, stored or passed
      // anywhere — this enumeration is the adapter's own mechanics,
      // never a capability the port exposes (the port's method
      // returns void and takes nothing).
      // Handle an enumeration error on the stream itself rather than
      // letting it abort the async loop before later children are seen.
      // The Directory stream remains best-effort and the next open retries
      // anything the platform still refused.
      final children = scopeDir
          .list(followLinks: false)
          .handleError((Object _) {});
      await for (final child in children) {
        try {
          await child.delete(recursive: true);
        } on Object {
          // Quiet per child — every flavour, not just the filesystem
          // family: one refused delete never stops the sweep, and the
          // next open sweeps again. The backstop's idempotence is
          // what makes the refusal survivable.
        }
      }
    } on Object {
      // Quiet by contract: the sweep is the open's backstop — a
      // backstop may never break the open it runs inside.
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

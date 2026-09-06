/// The Files port (Story 4.3, AD-22, AD-21): the core's only view of
/// app-private byte storage — the spine's seventh declared port, whose
/// first consumer is the shell's credential vault (the envelopes are
/// the port's bytes, never plaintext). Epic 5 adds the scan cache and
/// Epic 7 the album bytes over the same port, additively.
///
/// The port is deliberately narrower than a filesystem: one stored
/// blob is a ([scope], [name]) pair — a scope being a flat partition
/// (`credentials`, later `scan_cache`, `album`), a name being one path
/// segment inside it. Adapters refuse any pair that is not two clean
/// single segments (no separators, no `.`, no `..`), so no caller can
/// traverse out of the app-private root, and the port's vocabulary
/// never grows a directory listing, a search, or a watch — the two
/// tables plus Files are the whole persistence story AD-21 allows.
///
/// Bytes only, no plaintext semantics: nothing here knows what the
/// bytes mean, and no method may name a credential, a key or a
/// secret. Writes are atomic (a reader sees the old blob or the new
/// one, never a half-written one), reads are nullable (absence is a
/// quiet state, never an error), and deletes are idempotent (the
/// same outcome whether or not the blob existed).

library;

/// The app-private byte store: read nullable, write atomic, delete
/// idempotent, over flat scope/name partitions — plus, additively
/// since Story 5.2, the per-scan cache mechanics Epic 5's scan path
/// owns: one write of a scan's frame into that scan's own
/// subdirectory, and one unlink of the whole subdirectory on every
/// terminal path. The subdirectory vocabulary exists only through
/// these two methods: a [scanId] is one clean path segment, never a
/// composed path, and no listing, search or watch grows beside them.
abstract interface class FilesPort {
  /// Reads the blob [name] in [scope], or null when no such blob
  /// exists. A stored empty blob reads back as empty, never as
  /// absent — absence and emptiness are different states.
  Future<List<int>?> read(String scope, String name);

  /// Writes [bytes] to [name] in [scope] as an atomic replacement:
  /// a concurrent or racing reader observes either the previous blob
  /// or this one, and a failed write leaves the previous blob intact.
  Future<void> write(String scope, String name, List<int> bytes);

  /// Deletes the blob [name] in [scope]. Idempotent by contract: the
  /// outcome is the same whether or not the blob existed, and it is
  /// never an error for it to have been absent.
  Future<void> delete(String scope, String name);

  /// Writes [bytes] as the frame of the scan named [scanId], in that
  /// scan's own cache subdirectory, and returns the written file's
  /// absolute path — the path the face gate reads the frame through
  /// (the measured `InputImage.fromFilePath` seam). Atomic like
  /// [write]; a [scanId] that is not one clean path segment writes
  /// nothing and returns the empty string — the quiet refusal, never
  /// a crash. The ≤ 2-files invariant and the `app_opened` sweep are
  /// 5.4's to govern; this story adds the mechanics alone.
  Future<String> writeScanFrame(String scanId, List<int> bytes);

  /// Unlinks the scan [scanId]'s whole cache subdirectory — the frame
  /// and anything else the scan cached. Idempotent by contract: the
  /// outcome is the same whether or not the directory existed, and it
  /// is never an error for it to have been absent. Every terminal
  /// path a scan can take ends here, so no frame lingers.
  Future<void> unlinkScan(String scanId);
}

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
/// The scan-cache sweep (Story 5.4) is explicitly not a listing: it
/// is a blind mass-unlink that names no child to any caller and
/// returns nothing, so the ban holds by construction, not by promise.
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
/// subdirectory, one write of the resolution cap's capped copy beside
/// it (Story 5.4), one unlink of the whole subdirectory on every
/// terminal path, and the blind `app_opened` sweep (Story 5.4) as the
/// crash backstop. A [scanId] is one clean path segment, never a
/// composed path — only the scan methods can target a scan's
/// subdirectory, so it holds at most the frame and the capped copy,
/// the two sanctioned names, both dying with the scan.
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
  /// a crash. Since Story 5.4 the ≤ 2-files invariant (frame + capped
  /// copy, both sanctioned names) and the `app_opened` sweep are
  /// governed beside this method: [writeScanCappedCopy] and
  /// [sweepScanCache] carry the rest of the invariant.
  Future<String> writeScanFrame(String scanId, List<int> bytes);

  /// Unlinks the scan [scanId]'s whole cache subdirectory — the frame
  /// and the capped copy and anything else the scan cached. Idempotent
  /// by contract: the outcome is the same whether or not the directory
  /// existed, and it is never an error for it to have been absent.
  /// Every terminal path a scan can take ends here, so no frame or
  /// capped copy lingers; the crash left standing after a death
  /// between mint and resolution is [sweepScanCache]'s to take.
  Future<void> unlinkScan(String scanId);

  /// Writes [bytes] as the capped copy of the scan named [scanId]
  /// (Story 5.4), in that scan's own cache subdirectory beside the
  /// frame, and returns the written file's absolute path — the twin
  /// of [writeScanFrame] in every term: atomic, absolute path back,
  /// and a [scanId] that is not one clean path segment writes nothing
  /// and returns the empty string, the same quiet refusal. The capped
  /// copy is the resolution cap's re-encoded output on its way out
  /// (AD-7's second sanctioned file); its fixed name claims no mime —
  /// the sniff is the mime truth, the name claims nothing.
  Future<String> writeScanCappedCopy(String scanId, List<int> bytes);

  /// Unlinks every child of the scan-cache scope — the crash backstop
  /// run at launch and after a real background `app_opened` (Story 5.4):
  /// every terminal path and lifecycle close already unlinks its own
  /// subdirectory, so a standing child at such an open is a leftover
  /// from a scan that died between mint and resolution. A transient
  /// inactive→resumed occlusion is not swept while the scan surface may
  /// still hold its frame. Blind by contract: the sweep
  /// names no child to any caller and returns nothing — it is not a
  /// listing, and the port's no-listing ban holds by construction.
  /// Idempotent and quiet on every error: a missing scope (a fresh
  /// install), an unremovable child, a failed root resolution — every
  /// refusal folds into the same silent completion, because a backstop
  /// may never break the open it runs inside. The scope directory
  /// itself remains.
  Future<void> sweepScanCache();
}

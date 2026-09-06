/// The scan consent token (Story 5.4, AD-8, FR-25, FR-26): the
/// compile-time precondition every scan upload carries. The token is
/// the capability — no boolean, no nullable check, no runtime consent
/// branch exists anywhere: a scan request or payload shape cannot be
/// constructed without one, because the consent field is required at
/// every seam the request travels (`ScanSliceRequest` here,
/// `ScanImagePrompt` in the shell's egress chokepoint), so the test
/// suites' own compilation is the proof of absence being impossible.
///
/// AD-8's full contract, restated as this library's invariants:
///
/// - **Minting.** The token is minted only through [mintScanConsent],
///   the single sanctioned minter, binding it to the scan's cache
///   subdirectory identity (the `scanId` segment). The mint ordering —
///   after the on-device face gate, before the resolution cap — is the
///   caller's contract (story 5.5 wires the mint into the flow); this
///   library ships the machinery and the pins, with zero production
///   mint callers by census.
/// - **Consumption.** Exactly once, one-way, performed by the
///   egress dispatch's scan branch before the image-resolution cap —
///   one token authorizes one dispatch entry, burned even when the cap
///   rejects (no retry exists; terminal by design). A second
///   consumption throws a `StateError` outside every catch arm: a
///   programmer error that propagates raw, never folded into
///   `EgressFailed` or any `SlicerFailureCause`.
/// - **Leak-proof surface.** The token is never persisted, never
///   serialized (no serializer touches it; the wire body is built from
///   the image bytes and the prompt alone), never reconstructible from
///   the log. No `==`, no `hashCode` and no `toString` override exists
///   — identity semantics, so nothing readable of the binding can
///   leak, and two tokens for the same scan are never equal.
/// - **Instrumentation is not capability.** The `consent_granted` log
///   row (its single sanctioned minter lives in
///   `core/commands/scan_commands.dart`) is a payload-less user act
///   that carries no capability and names no scanId; this token is
///   never logged.
library;

/// One scan's single-use upload consent (AD-8): minted bound to the
/// scan's cache subdirectory identity, consumable exactly once by the
/// dispatch's scan branch, and carrying no readable surface beyond
/// the binding itself. Not const — a consent is an event, minted once
/// at the consent act's own instant, never a compile-time constant.
final class ScanConsent {
  ScanConsent._({required this.scanId});

  /// The scan's cache subdirectory identity this token is bound to —
  /// the same clean `scanId` segment the Files port's scan methods
  /// take. The binding is what makes the token about this scan and no
  /// other; nothing else of the scan travels with it.
  final String scanId;

  /// The one-way consumption state. Never exposed: the only legal
  /// transitions are mint → unconsumed → consumed, and the second
  /// consume is the caller's bug, thrown raw.
  bool _consumed = false;

  /// Consumes the token — the one-way transition the egress dispatch's
  /// scan branch performs before the resolution cap. A second call
  /// throws `StateError`: one token authorizes one dispatch entry, and
  /// reuse is a programmer error that must propagate raw, never wear a
  /// failure taxonomy's costume.
  void consume() {
    if (_consumed) {
      throw ScanConsentStateError('ScanConsent already consumed');
    }
    _consumed = true;
  }
}

/// A raw [StateError] raised by a violated scan-consent binding. The shell
/// uses the subtype only to preserve this programmer error through its broad
/// outcome boundary; it is never converted into a failure taxonomy.
final class ScanConsentStateError extends StateError {
  ScanConsentStateError(super.message);

  /// The scan request carried a different in-memory identity than the
  /// consent token. This remains a programmer error, not a provider failure.
  ScanConsentStateError.scanIdMismatch()
    : super('ScanConsent does not match scanId');
}

/// The single sanctioned minter (AD-8): binds a fresh, unconsumed
/// token to [scanId]. No second minting path exists as code anywhere —
/// the private constructor sees to it inside this library, and the
/// single-minter census sees to it outside. The caller owns the
/// ordering contract: after the on-device face gate, before the
/// resolution cap. No validation happens here by design — the adapter
/// stays the enforcing edge for cache writes, and a dirty [scanId]
/// fails exactly there, quietly.
ScanConsent mintScanConsent({required String scanId}) =>
    ScanConsent._(scanId: scanId);

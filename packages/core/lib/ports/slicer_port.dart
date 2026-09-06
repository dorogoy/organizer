/// The Slicer port (Story 4-4, AD-9): the core's name for "ask a
/// provider for a slice" — one `slice` operation over one request,
/// answering one outcome or one of eight failure causes. Three
/// request kinds mirror the egress payload union (AD-7) one-for-one:
/// a scan photograph plus its prompt, a project-genesis text, and a
/// rescue re-slice's origin context plus task. Declaring three and
/// calling fewer is the seal working as designed: this build calls
/// none (the port ships with no production call site, like 4-2's
/// dispatch); Rescue Mode (4-6) calls the rescue shape and Epic 5
/// the scan and genesis shapes.
///
/// The port is core-pure vocabulary only: requests are inert data,
/// the outcome is a delivered response body or a failure cause, and
/// nothing here names a provider, a credential, an HTTP client or a
/// socket — the three implementations live in the shell's `lib/egress/`
/// (`ByokSlicer` — already banned here by name in
/// `tool/check_core_purity.dart` — plus the Local stub and the
/// Managed third shape). The cause taxonomy is the whole honesty
/// contract FR-29 builds its calm surface on: the port distinguishes
/// eight causes, closed here so no ninth can appear as a type, split
/// by evidence — the image seam's pre-transport refusals read
/// `malformedInput` (story 5.3), socket-family failures read
/// `networkUnreachable`, HTTP-status evidence reads
/// `invalidKey`/`quotaExhausted`/`providerUnreachable`, and a
/// provider's answer that will not yield its slice text reads
/// `malformedResponse`. FR-29's rendered surface stays exactly seven
/// strings: `no_slicer_cause.dart`'s total map folds the taxonomy
/// down, deliberately.

library;

import 'dart:typed_data';

import 'package:core/ports/scan_consent.dart';

/// One Slicer request: exactly three shapes exist and no fourth
/// exists as a type — the union is sealed in this one library.
sealed class SlicerRequest {
  const SlicerRequest();
}

/// A scan photograph plus its prompt (Epic 5's caller): the image
/// half of the Slicer's input, mirroring `ScanImagePrompt`. Since
/// Story 5.4 (AD-8) the shape cannot be constructed without the
/// scan's minted [ScanConsent] — a required field, so absence is a
/// compile error at every construction site and no runtime consent
/// branch exists anywhere. The other two request kinds carry no
/// token: rescue and genesis are not consent-bearing (the token binds
/// to a scan cache identity only scans have).
final class ScanSliceRequest extends SlicerRequest {
  const ScanSliceRequest({
    required this.imageBytes,
    required this.prompt,
    required this.scanId,
    required this.consent,
  });

  /// The frame's encoded bytes (JPEG or PNG as captured).
  final Uint8List imageBytes;

  /// The prompt the Slicer answers for this scan.
  final String prompt;

  /// The in-memory identity of the scan whose frame is being sent. It is
  /// checked against [consent] at the egress seam and never serialized.
  final String scanId;

  /// The scan's single-use consent token (Story 5.4, AD-8) — minted
  /// through the one sanctioned minter after the on-device face gate
  /// and before the resolution cap, bound to this scan's cache
  /// subdirectory identity, consumed exactly once by the dispatch's
  /// scan branch. It travels with the request and never serializes.
  final ScanConsent consent;
}

/// A project-genesis request (Epic 5's caller): text describing a
/// project the Slicer turns into steps.
final class GenesisSliceRequest extends SlicerRequest {
  const GenesisSliceRequest({required this.text});

  /// The genesis text.
  final String text;
}

/// A rescue re-slice request (FR-5, story 4-6's caller): the stuck
/// task's origin context and the task itself.
final class RescueSliceRequest extends SlicerRequest {
  const RescueSliceRequest({required this.originContext, required this.task});

  /// The task's origin context.
  final String originContext;

  /// The current task text.
  final String task;
}

/// Why a slice could not be delivered: the eight-cause taxonomy,
/// closed by construction (story 5.3 gained `malformedInput`; FR-29's
/// rendered surface stays seven — the fold to it is
/// `no_slicer_cause.dart`'s recorded map, not a new string).
/// Config-family causes (`credentialUnavailable`, `invalidKey`,
/// `managedUnavailable`) carry a text pointer to Ajustes in 4-5's
/// copy; the split between `networkUnreachable` and
/// `providerUnreachable` is evidential — socket-family vs
/// HTTP-status — and deliberately honest about its limits: a provider
/// being down and DNS failing can both surface as sockets.
enum SlicerFailureCause {
  /// No usable credential stands behind the selected provider —
  /// none selected, no envelope stored, or material that will not
  /// unseal. Nothing was sent.
  credentialUnavailable,

  /// The provider rejected the key (HTTP 401/403).
  invalidKey,

  /// The key's quota is exhausted (HTTP 429).
  quotaExhausted,

  /// The provider answered as unreachable (HTTP 5xx family).
  providerUnreachable,

  /// No network — a socket-family failure before any HTTP status
  /// existed.
  networkUnreachable,

  /// The provider answered but its body yielded no slice text.
  malformedResponse,

  /// The image seam refused the input before any transport existed
  /// (story 5.3): the bytes were not a type the wire can declare
  /// honestly, would not decode, or claimed more than the pixel
  /// ceiling. Nothing was ever sent — a pre-transport fact about the
  /// input, never the delivered-but-unusable `malformedResponse`.
  malformedInput,

  /// The Managed shape was asked for a slice: it is inert in this
  /// build, and every request reads this cause.
  managedUnavailable,
}

/// One slice's outcome: delivered (with the provider's slice text)
/// or failed (with one cause). Sealed here so no third outcome —
/// and no queued or retained one — can exist as a type.
sealed class SlicerOutcome {
  const SlicerOutcome();
}

/// The provider's slice text, extracted per its own wire. 4-6 parses
/// it against the rescue schema; the port itself promises only a
/// non-empty extraction.
final class SlicerDelivered extends SlicerOutcome {
  const SlicerDelivered(this.responseBody);

  /// The extracted slice text.
  final String responseBody;
}

/// The slice failed terminally with [cause]. No retry is implied or
/// performed anywhere; a fresh `slice` is a fresh call by
/// construction.
final class SlicerFailed extends SlicerOutcome {
  const SlicerFailed(this.cause);

  /// The failure's cause, one of the closed eight.
  final SlicerFailureCause cause;
}

/// The Slicer seam (AD-9): one operation, one request, one outcome.
/// Implementations live shell-side only — BYOK (usable), Local
/// (canned, debug-variant-only) and Managed (inert) — and adding
/// either of the last two changes no call site outside `lib/egress/`.
abstract interface class SlicerPort {
  /// Asks for one slice. Sends at most once per call, meters
  /// nothing, reports nothing, and queues or retries nothing.
  Future<SlicerOutcome> slice(SlicerRequest request);
}

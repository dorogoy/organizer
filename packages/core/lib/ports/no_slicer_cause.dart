/// The no-Slicer cause vocabulary (Story 4-5, FR-29): the seven
/// states the honest-degradation surface renders, chosen here in the
/// core — not the failure taxonomy itself. Two of the seven
/// (`consentDeclined`, `personInFrame`) are pre-request refusals that
/// never produce a `SlicerFailureCause` (Epic 5's callers decline or
/// refuse on-device, before any request exists), so the UI's cause set
/// is not the port's failure set, and the total map below is where the
/// two vocabularies meet: every failure a slice call can report lands
/// on exactly one renderable cause, and no eighth cause can appear as
/// a type.
///
/// Core-pure vocabulary only, on `StripResident`'s precedent (a
/// core-pure enum the shell switches on): members carry no fields, the
/// shell owns every string, and nothing here names a provider, a
/// credential, a network or a screen — 4-6 (Rescue Mode) and Epic 5
/// (scan/genesis) push the surface this vocabulary feeds; this story
/// ships the piece with no production call site, the 4-2/4-4 pattern.

library;

import 'package:core/ports/slicer_port.dart';

/// Why no Slicer stands behind the moment (FR-29): seven members,
/// closed by construction — copy alone distinguishes them on the one
/// calm surface, never layout, styling or iconography.
enum NoSlicerCause {
  /// No key configured (or none usable behind the selected provider):
  /// nothing was sent. Config-family — the string's remedy is Ajustes.
  noKey,

  /// The stored key was rejected by the provider. Config-family — the
  /// string's remedy is Ajustes.
  invalidKey,

  /// The key's quota is exhausted: a provider-account fact, scoped by
  /// its string to exactly what is unavailable.
  quotaExhausted,

  /// The provider is unresponsive — HTTP 5xx evidence, and the
  /// recorded fold of a body that yields no slice text.
  unreachable,

  /// No network — a socket-family failure before any HTTP status
  /// existed; the exit still works (FR-29's all-seven-states clause).
  offline,

  /// The per-scan consent was declined (Epic 5's caller): a
  /// pre-request refusal with no failure-cause origin — the string
  /// deliberately names no remedy, since retry-and-accept would be
  /// persuasion.
  consentDeclined,

  /// A person was detected in the frame and the photo was refused
  /// on-device (Epic 5's caller): a pre-request refusal with no
  /// failure-cause origin.
  personInFrame,
}

/// The total map from the port's failure taxonomy to the renderable
/// cause vocabulary: every `SlicerFailureCause` lands on exactly one
/// `NoSlicerCause`, exhaustive with no default arm, so an eighth
/// failure cause is a compile error here before it is a review
/// comment anywhere.
///
/// The two folds are recorded, not improvised:
/// `malformedResponse→unreachable` (epics.md:1988 — the provider
/// answered but its body would not yield a slice, surfaced under the
/// provider-unresponsive string) and `managedUnavailable→noKey`
/// (config-family per `slicer_port.dart`'s own doc: the Managed shape
/// is inert in this BYOK-only build, nothing was sent, and the no-key
/// string's remedy — Ajustes — is the true one). The image is exactly
/// the five causes a request can produce: `consentDeclined` and
/// `personInFrame` have no failure-cause origin by construction.
NoSlicerCause noSlicerCauseFromFailure(SlicerFailureCause failure) =>
    switch (failure) {
      SlicerFailureCause.credentialUnavailable => NoSlicerCause.noKey,
      SlicerFailureCause.invalidKey => NoSlicerCause.invalidKey,
      SlicerFailureCause.quotaExhausted => NoSlicerCause.quotaExhausted,
      SlicerFailureCause.providerUnreachable => NoSlicerCause.unreachable,
      SlicerFailureCause.networkUnreachable => NoSlicerCause.offline,
      SlicerFailureCause.malformedResponse => NoSlicerCause.unreachable,
      SlicerFailureCause.managedUnavailable => NoSlicerCause.noKey,
    };

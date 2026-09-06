import 'dart:typed_data';

import 'package:core/ports/scan_consent.dart';

/// The egress payload union (AD-7): exactly three shapes exist and no
/// fourth exists as a type — the union is sealed in this one library, so
/// a fourth subtype declared anywhere is a compile error. This module
/// (`lib/egress/`, with `egress_dispatch.dart` and `image_cap.dart`) is
/// the app's single egress chokepoint: the only code that may ever
/// import an HTTP client, sealed three ways by
/// `tool/check_egress_imports.dart`,
/// `tool/check_gradle_dependencies.dart` and
/// `tool/check_android_manifest.dart`.
///
/// Declaring three shapes and calling fewer is the seal working as
/// designed: this story wires no transport at all; Epic 5 calls the
/// scan and genesis shapes, and Rescue Mode (story 4-6) the re-slice
/// shape.
sealed class EgressPayload {
  const EgressPayload();
}

/// A scan photograph plus its prompt: the image half of the Slicer's
/// input. The bytes are the raw encoded frame; the resolution cap
/// (AD-7, `image_cap.dart`) is applied inside dispatch before any
/// transport sees them. Since Story 5.4 (AD-8) the shape cannot be
/// constructed without the scan's minted [ScanConsent] — the
/// compile-time precondition, the same required field
/// `ScanSliceRequest` carries, so the chokepoint's scan shape is
/// sealed the same way and no runtime consent branch exists. The
/// token never serializes: the wire body is built from the bytes and
/// the prompt alone, and no serializer touches the consent field.
final class ScanImagePrompt extends EgressPayload {
  const ScanImagePrompt({
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
  /// checked against [consent] at dispatch and never reaches the wire.
  final String scanId;

  /// The scan's single-use consent token (Story 5.4, AD-8), consumed
  /// by the dispatch's scan branch before the cap. Never serialized,
  /// never persisted, never reconstructible from anything stored.
  final ScanConsent consent;
}

/// A project-genesis request: text describing a project the Slicer
/// turns into steps. No image, so the cap never touches it.
final class ProjectGenesisText extends EgressPayload {
  const ProjectGenesisText({required this.text});

  /// The genesis text.
  final String text;
}

/// A rescue re-slice request (FR-5): the stuck task's origin context
/// and the task itself, sent for a fresh slice. No image, so the cap
/// never touches it.
final class RescueResliceText extends EgressPayload {
  const RescueResliceText({required this.originContext, required this.task});

  /// The task's origin context.
  final String originContext;

  /// The current task text.
  final String task;
}

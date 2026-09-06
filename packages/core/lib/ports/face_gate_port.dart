/// The face gate port (Story 5.2, FR-25, AD-11): the core's name for
/// "does this frame hold a person?" — one `gate` operation over one
/// written frame file, answering pass or refusal. Declared now and
/// called by this story's scan path, on the SlicerPort's own
/// declare-now-call-later precedent: core-pure vocabulary, the fragile
/// ML Kit dependency sealed behind the seam in `lib/plugins/mlkit_face/`
/// so AD-11's promotion to our own platform channel stays a one-file
/// move.
///
/// The interim rule of record runs verbatim behind the adapter
/// (`face-gate/BAR.md`, run 1): face-only, `performanceMode: accurate`,
/// `minFaceSize: 0.0`, landmarks/classification/contours/tracking off
/// — refuse iff the detector finds at least one face. The bar accepts
/// false positives (the cost is one reframe offer); composition
/// (face ∨ pose ∨ object) reopens before 5.5 ships the first payload.
///
/// The outcome vocabulary is closed at two: a gate that decided says
/// pass or refusal, never "maybe", never "queued". A gate that could
/// not decide — the detector erred past its one retry — throws: a
/// failure is not a refusal, and the caller folds it into a quiet
/// fail-closed abort with no `face_refused` row, so the log can never
/// claim a privacy decision that was not made.

library;

/// One gate's outcome: the frame passed (no face found), or the frame
/// was refused (at least one face). Sealed here so no third outcome —
/// and no error-as-refusal fold — can exist as a type.
sealed class FaceGateOutcome {
  const FaceGateOutcome();
}

/// No face was detected in the frame: the scan may proceed (this story
/// closes quietly — 5.5 wires the continuation).
final class FaceGatePass extends FaceGateOutcome {
  const FaceGatePass();
}

/// At least one face was detected in the frame: the scan is refused
/// on-device, before any upload path exists — the caller appends one
/// `face_refused` row and lands the calm surface whose copy offers the
/// reframe. The refusal is about the frame, never about the user.
final class FaceGateRefusal extends FaceGateOutcome {
  const FaceGateRefusal();
}

/// The face gate seam (AD-11): one operation, one written frame file,
/// one decided outcome. The implementation lives shell-side only, over
/// the measured `InputImage.fromFilePath` input path — decode and
/// orientation travel with the file, exactly as the 5-1 probe scored
/// it.
abstract interface class FaceGatePort {
  /// Inspects the frame file at [framePath] and answers whether it
  /// holds a person. Sends nothing anywhere, meters nothing, and
  /// retries nothing the caller can observe: a detector error past the
  /// implementation's own single retry travels as an error, never as a
  /// refusal.
  Future<FaceGateOutcome> gate(String framePath);
}

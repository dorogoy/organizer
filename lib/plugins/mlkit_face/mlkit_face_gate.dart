// The face gate adapter (Story 5.2, FR-25): the FaceGatePort's shell
// half over the spine-pinned community plugin — production running
// exactly what the 5-1 probe measured (face-gate/probe/
// face_gate_probe_test.dart): a `FaceDetector` from the pinned
// options, `processImage(InputImage.fromFilePath(...))` on the
// written cache frame, ≥ 1 face → refusal, retry-once on error,
// `close()` in `finally`.
//
// The interim rule of record, verbatim (face-gate/BAR.md, run 1):
// face-only, `performanceMode: accurate`, `minFaceSize: 0.0`,
// landmarks/classification/contours/tracking all off. The input path
// is the report's recorded seam — decode and orientation travel with
// the file — so the anticipated `fromBytes`-with-rotation seam does
// not arise.
//
// One of the architecture's three named fragile dependencies
// (AD-11): everything ML Kit-shaped stays inside this directory, and
// promotion to our own platform channel is a one-file move.
import 'package:core/ports/face_gate_port.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

/// The gate's single retry count: a detection error is attempted
/// twice, then the failure travels to the caller — fail closed, never
/// falsely refused (the probe's own `maxAttemptsPerPhoto`).
const int faceGateAttempts = 2;

/// The FaceGatePort over google_mlkit_face_detection (Story 5.2,
/// FR-25). One detector per gate call, closed in `finally` — the
/// probe's own lifecycle discipline.
class MlKitFaceGate implements FaceGatePort {
  const MlKitFaceGate();

  @override
  Future<FaceGateOutcome> gate(String framePath) async {
    // The pinned interim config, verbatim from BAR.md's rule of
    // record: accurate mode, the smallest face size the detector
    // accepts, every optional feature off — the asymmetric bar leans
    // entirely toward refusing (FR-25).
    final detector = FaceDetector(
      options: FaceDetectorOptions(
        performanceMode: FaceDetectorMode.accurate,
        minFaceSize: 0.0,
        enableClassification: false,
        enableContours: false,
        enableLandmarks: false,
        enableTracking: false,
      ),
    );
    try {
      Object? failure;
      for (var attempt = 0; attempt < faceGateAttempts; attempt++) {
        try {
          // The measured input path: the written cache file, decoded
          // and oriented by the plugin itself.
          final faces = await detector.processImage(
            InputImage.fromFilePath(framePath),
          );
          return faces.isNotEmpty
              ? const FaceGateRefusal()
              : const FaceGatePass();
        } on Object catch (error) {
          failure = error;
        }
      }
      // Both attempts errored: a failure is not a refusal — it
      // travels to the caller, which closes quietly and mints no
      // `face_refused` row (no false privacy claims in the log).
      throw failure!;
    } finally {
      await detector.close();
    }
  }
}

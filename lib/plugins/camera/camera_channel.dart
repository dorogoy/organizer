// The `camera` channel's Dart half (Story 5.2, FR-16, AD-11; the
// 2026-09-05 ruling 1-B): the permission moment of the scan path,
// hand-written beside the facade because the spine-pinned plugin
// cannot say what the ruling demands — it folds a system-interrupted
// request (empty grants: the ask was swallowed, no answer existed)
// into the same denial code as the user's explicit refusal. This
// channel separates the two domains on DictateChannel's own staged-ask
// pattern: an explicit denial is app logic (the refusal row); an
// interrupted ask is a functioning problem the scan surface
// communicates, never a fact the log records.
//
// Capture stays plugin-served — this channel opens no camera, carries
// no bytes, and answers one question only.
import 'package:flutter/services.dart';

/// The `camera` channel's name — one of the build's four decided
/// channels (dictate, credentials and camera shipped, notify reserved
/// and unshipped; the camera slot grown by the 2026-09-05 ruling),
/// and an infrastructure identifier, never widget copy: a named
/// string constant on the platform module's own terms (AD-15).
const String cameraChannelName = 'dev.dorogoy.organizer/camera';

/// The permission-request method's name: the channel's one question.
const String cameraRequestMethod = 'request';

/// The ask's wire answers (the Kotlin half's companion mirrors them):
/// `granted` (a grant stood, or the dialog granted), `refused` (the
/// user's explicit denial — the app-logic domain), `interrupted` (the
/// system swallowed the ask: empty grants, no answer existed — the
/// functioning-problem domain).
const String cameraGrantedWire = 'granted';
const String cameraRefusedWire = 'refused';
const String cameraInterruptedWire = 'interrupted';

/// One ask's answer, in the ruling's two domains: [granted] and
/// [refused] are the user's answers (app logic); [interrupted] is the
/// system's malfunction (communicated, never recorded).
enum CameraPermissionAnswer {
  /// A grant stood (the fast path, no dialog) or the dialog granted.
  granted,

  /// The user explicitly denied — or a revocation of a grant was
  /// discovered at the ask. App logic: the refusal row, the entry
  /// gone. The app never re-asks on its own.
  refused,

  /// The system swallowed the ask — empty grants, no answer existed.
  /// A functioning problem, not a refusal: nothing is appended, the
  /// entry stays, the scan surface states the problem.
  interrupted,
}

/// The seam over the hand-written `camera` channel — the scan facade's
/// one door onto the permission moment. Tests fake this; the
/// composition root constructs the one real channel.
abstract interface class CameraPermissionsChannel {
  /// Asks CAMERA at the first scan attempt only (AD-17): an existing
  /// grant fast-paths to [CameraPermissionAnswer.granted] with no
  /// dialog; otherwise the system dialog answers, or the system
  /// swallows the ask and the interruption travels instead.
  Future<CameraPermissionAnswer> request();
}

/// The adapter over the hand-written Kotlin `camera` channel. Thin by
/// design, the dictate adapter's own shape: it translates wire text
/// into the answer vocabulary and nothing else — the staging, the
/// empty-grants separation and the request code all live on the Kotlin
/// side. A wire answer outside the protocol is a format violation,
/// never a quiet substitution: the caller absorbs it on its own
/// quiet terms (a failed ask is a device problem, never a refusal).
class CameraChannel implements CameraPermissionsChannel {
  const CameraChannel();

  static const MethodChannel _channel = MethodChannel(cameraChannelName);

  @override
  Future<CameraPermissionAnswer> request() async {
    final answer = await _channel.invokeMethod<String>(cameraRequestMethod);
    switch (answer) {
      case cameraGrantedWire:
        return CameraPermissionAnswer.granted;
      case cameraRefusedWire:
        return CameraPermissionAnswer.refused;
      case cameraInterruptedWire:
        return CameraPermissionAnswer.interrupted;
      default:
        throw const FormatException();
    }
  }
}

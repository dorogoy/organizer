/// The recognizer port (Story 3.4, FR-32, AD-11): the core's only view
/// of on-device speech recognition — the contract the shell's `dictate`
/// channel adapter implements and every test seam fakes. Deliberately
/// minimal, on the ClockPort's own terms: its real shape is exactly
/// what dictation needs and nothing more.
///
/// The port never decides *when* to listen — dictation starts only on
/// an explicit capsule press, and nothing listens outside it — and it
/// never carries partial results: only final transcripts cross, so
/// interruption yielding nothing is true by construction rather than
/// by cleanup. Session ids are shell-minted per press and travel every
/// request and outcome, so the Dart half can drop whatever a stale or
/// cancelled session emits.

library;

/// What a probe found (the 3-1 rule, applied at read time): on-device
/// recognition is forced by the creator/availability pair and gated
/// further by the Spanish-model support check — a service being
/// available is not the model being present. `unavailable` wins over
/// everything: where recognition is absent the affordance is simply
/// absent, whatever the permission says.
enum RecognizerAvailability {
  /// On-device Spanish recognition is absent (the service, the model,
  /// or the support check errored) — the affordance never renders and
  /// no error, grey state or install offer exists.
  unavailable,

  /// Recognition is available and the microphone permission is not
  /// granted — the system dialog may still be requested (once; the
  /// `permissionMayBeAsked` derivation decides whether it should be).
  askable,

  /// Recognition is available and the microphone permission is
  /// granted.
  granted,
}

/// One press's start outcome: the session state machine's door. Exactly
/// one of these answers every press, before any outcome event.
enum RecognizerStart {
  /// Listening began — the capsule declares itself through the blue
  /// mass and the `Escuchando…` caption alone, never by motion.
  listening,

  /// The permission was refused — the dialog's refusal, or the
  /// system-level revocation read identically. Exactly one
  /// `permission_refused` entry is appended through the core minter
  /// and the affordance disappears.
  refused,

  /// Recognition became unavailable between the probe and the press —
  /// quiet: the capsule resets to rest and nothing is surfaced.
  unavailable,
}

/// One session's terminal outcome (FR-32): the session id it belongs
/// to, and the final transcript — null when nothing landed
/// (interruption, recognizer error, an empty `onResults`), because
/// partial results never cross the port. One terminal outcome per
/// press: transcript or nothing, never both, never a third thing.
typedef RecognizerOutcome = ({int sessionId, String? transcript});

/// The shell's only view of the `dictate` channel (FR-32, AD-11's
/// hand-written channel). The adapter owns no state the port exposes:
/// each probe re-reads the platform, each start owns its session, and
/// outcomes arrive carrying the session id the request minted.
abstract interface class RecognizerPort {
  /// Probes availability and the microphone permission's granted bit —
  /// never a cache (no store exists outside the log), so the answer is
  /// recomputed on every call and defaults to absence while it pends.
  Future<RecognizerAvailability> probe();

  /// Starts one utterance for [sessionId]: requests the microphone
  /// permission at this first-use moment if it is not granted (never
  /// at app entry), then either listens, reports the refusal, or
  /// reports quiet unavailability.
  Future<RecognizerStart> start(int sessionId);

  /// Cancels the session [sessionId] without delivering anything —
  /// the interruption path (backgrounding, call, focus loss): nothing
  /// listens outside an explicit press's foreground lifetime.
  Future<void> cancel(int sessionId);

  /// The terminal outcomes of started sessions, in arrival order. A
  /// stale session id makes an outcome meaningless: the listener drops
  /// it, the port never rewrites it.
  Stream<RecognizerOutcome> get outcomes;

  /// Opens the system's app-details screen — the Settings
  /// reactivation row's single action, the permission surface's only
  /// recovery path (reversal lives outside the log; the app itself
  /// never re-asks).
  Future<void> openAppSettings();
}

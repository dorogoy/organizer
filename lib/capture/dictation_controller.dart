import 'dart:async';

import 'package:core/commands/permission_commands.dart';
import 'package:core/derive/permission.dart';
import 'package:core/log/log_entry.dart';
import 'package:core/ports/recognizer_port.dart';
import 'package:core/ports/store_port.dart';
import 'package:flutter/widgets.dart';
import 'package:uuid/uuid.dart';

import '../session/log_write_queue.dart';

/// The dictation seam (Story 3.4, FR-32): the press flow's shell half,
/// on the capture controller's own division of labour — the core
/// decides content (`permissionRefuse`: the `permission_refused` row a
/// refusal appends; `permissionMayBeAsked`: whether the dialog may
/// still be asked), and this shell mints ids, instants and session
/// counters and holds the session state machine: one terminal outcome
/// per press (transcript | nothing) with a single commit point.
///
/// Visibility is derived, never stored: `available ∧ (granted ∨
/// permissionMayBeAsked)` recomputed from the probe and the log at
/// every read (AD-17's never-ask-again — after a refusal the log entry
/// stands forever, so recovery flows through the probe's granted bit
/// alone, never through a re-ask). The affordance defaults to absent:
/// the probe is async and absence is the unavailable state, so the
/// capsule never flashes in on a device recognition does not serve.
///
/// Only final results commit: partials never cross the port, and a
/// stale session id makes any outcome meaningless — the counter moves
/// on every press and every live-session interruption, so a late event
/// from a cancelled session drops here, at the single reader. A press
/// still pending its start owns no recognizer (the permission dialog's
/// own `inactive` is exactly that case): its fate is decided when the
/// start resolves — a refusal is a durable fact whatever the session's
/// state, and a listening resolution is honoured only when the app
/// still stands in the foreground. Interruption (backgrounding, a
/// call, focus loss) cancels a live session through the binding
/// observer: nothing listens outside an explicit press's foreground
/// lifetime, and the reset is ink and prose only — the capsule returns
/// to rest, no error surfaces anywhere.
///
/// A refusal append rides the shared `LogWriteQueue` (one substrate
/// under the whole shell) and is quiet about its own failure: the
/// existing queue path absorbs a failing store, and the affordance
/// still disappears — the derivation reads the log as it lands.
class DictationController extends ChangeNotifier with WidgetsBindingObserver {
  DictationController({
    required this.store,
    required this.recognizer,
    LogWriteQueue? writeQueue,
    this.idMinter = const Uuid(),
    this.nowOf = DateTime.now,
    void Function(WidgetsBindingObserver observer)? addObserver,
    void Function(WidgetsBindingObserver observer)? removeObserver,
    AppLifecycleState? Function()? lifecycleStateOf,
  }) : writeQueue = writeQueue ?? LogWriteQueue(),
       lifecycleStateOf = lifecycleStateOf ?? _bindingLifecycleState {
    _outcomesSubscription = recognizer.outcomes.listen(_onOutcome);
    (addObserver ?? WidgetsBinding.instance.addObserver)(this);
    // The removal mirrors the registration: an injected registration
    // never touches the real binding, so its removal must not either
    // (a seam-registered observer is the seam's to keep, and the
    // default pair is the binding's own add/remove).
    _removeObserver =
        removeObserver ??
        (addObserver == null ? WidgetsBinding.instance.removeObserver : (_) {});
    unawaited(refresh());
  }

  final StorePort store;
  final RecognizerPort recognizer;
  final LogWriteQueue writeQueue;
  final Uuid idMinter;
  final DateTime Function() nowOf;

  /// The binding's own lifecycle state at read time, when a binding
  /// exists — a headless read answers null, which reads as resumed:
  /// the gate exists for the dialog-and-background races, not for the
  /// test seam.
  static AppLifecycleState? _bindingLifecycleState() {
    try {
      return WidgetsBinding.instance.lifecycleState;
    } on Object {
      return null;
    }
  }

  /// Where [press] reads the foreground fact: the start resolution's
  /// gate (a press may resolve only into a foreground app).
  final AppLifecycleState? Function() lifecycleStateOf;

  /// The observer-removal seam, mirroring the constructor's
  /// registration seam: dispose unregisters exactly how the
  /// constructor registered — the injected path never touches the
  /// real binding, so headless tests stay headless.
  late final void Function(WidgetsBindingObserver observer) _removeObserver;

  /// The transcript commit point (FR-32): the surface hands its line
  /// controller's replacement in here, and the final transcript
  /// replaces the line's content — never a confirmation screen, and
  /// the keyboard is never removed.
  void Function(String transcript)? onTranscript;

  StreamSubscription<RecognizerOutcome>? _outcomesSubscription;

  /// The session counter: every press mints one, every interruption
  /// invalidates the standing one. Outcomes carrying an id other than
  /// the current session's drop.
  int _sessionId = 0;

  /// The press's in-flight guard: one press's start owns the flow
  /// until it resolves, so a second press while the first still awaits
  /// is nothing at all — no second session, no double refusal, no
  /// stale answer clearing a state a newer press owns.
  bool _starting = false;

  /// The refresh's ordering guard: an older refresh (its probe or log
  /// read still in flight) must not overwrite the visibility a newer
  /// one already landed — the entry, lifecycle and press paths can all
  /// overlap, and only the newest read may commit.
  int _refreshGeneration = 0;

  bool _disposed = false;

  bool _visible = false;
  bool _listening = false;

  /// Whether the capsule renders at all (the derived visibility, absent
  /// by default): on-device Spanish recognition available ∧ (granted ∨
  /// the dialog may still be asked).
  bool get visible => _visible;

  /// Whether a press's utterance is live — declared only by the blue
  /// mass and the `Escuchando…` caption, never by motion.
  bool get listening => _listening;

  @override
  void dispose() {
    _disposed = true;
    // Invalidate every in-flight refresh at once: a late read may no
    // longer commit state — and, through [_notify], reach a listener
    // that is itself going away.
    _refreshGeneration++;
    _outcomesSubscription?.cancel();
    _removeObserver(this);
    super.dispose();
  }

  /// Recomputes the derived visibility: the probe's platform facts and
  /// the log's refusal derivation, one read each. A failing read or
  /// probe leaves the standing state exactly as it was — quiet. Only
  /// the newest refresh commits: overlapping reads (the constructor,
  /// a surface entry, a resume) resolve in any order, and a stale one
  /// overwrites nothing.
  Future<void> refresh() async {
    final generation = ++_refreshGeneration;
    final availability = await _probeQuietly();
    if (availability == null) {
      return;
    }
    if (generation != _refreshGeneration) {
      return;
    }
    final mayBeAsked = await _micMayBeAsked();
    if (mayBeAsked == null) {
      return;
    }
    if (generation != _refreshGeneration) {
      return;
    }
    final visible =
        availability != RecognizerAvailability.unavailable &&
        (availability == RecognizerAvailability.granted || mayBeAsked);
    if (visible != _visible) {
      _visible = visible;
      _notify();
    }
  }

  /// The capsule press (FR-32): dictation starts only here — nothing
  /// listens outside an explicit press. One press owns one session:
  /// the counter moves, the start outcome opens or closes the capsule.
  /// A press while a start is awaited, while an utterance is live, or
  /// while the affordance is absent is nothing at all (the in-flight
  /// guard, the listening guard, the visibility guard). A refusal is
  /// durable whatever became of the session (the dialog was up, the
  /// app was away — the system answered denied): exactly one
  /// `permission_refused` entry is appended through the core minter
  /// before the affordance disappears. A listening resolution is
  /// honoured only when the press still owns the standing session AND
  /// the app stands in the foreground — otherwise the session is
  /// invalidated and the platform half is cancelled, quietly. A quiet
  /// `unavailable` retires the affordance only while the press still
  /// owns the standing session: a stale answer from a session a
  /// newer press or an interruption superseded clears nothing.
  Future<void> press() async {
    if (_disposed || !_visible || _listening || _starting) {
      return;
    }
    _starting = true;
    try {
      final sessionId = ++_sessionId;
      final start = await _startQuietly(sessionId);
      switch (start) {
        case null:
          return;
        case RecognizerStart.listening:
          final state = lifecycleStateOf();
          final foreground =
              sessionId == _sessionId &&
              (state == null || state == AppLifecycleState.resumed);
          if (!foreground) {
            // The press outlived its validity — a newer press stands, or
            // the app left the foreground while the permission dialog
            // was up. Bump so the session's outcomes drop, cancel the
            // platform half, and stay quiet: nothing listens off the
            // foreground, and no error exists to surface.
            _sessionId++;
            await _cancelQuietly(sessionId);
            return;
          }
          _setListening(true);
        case RecognizerStart.refused:
          await _appendRefusal();
          // The refusal stands in the log from here on: visibility
          // derives false over it until a system re-grant restores it
          // through the probe's granted bit alone.
          if (_visible) {
            _visible = false;
            _notify();
          }
        case RecognizerStart.unavailable:
          if (sessionId == _sessionId && _visible) {
            _visible = false;
            _notify();
          }
      }
    } finally {
      _starting = false;
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        // A return to the foreground re-derives visibility: a
        // re-grant made in system settings while the app was away
        // restores the affordance through the probe alone.
        unawaited(refresh());
      case AppLifecycleState.inactive:
      case AppLifecycleState.hidden:
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
        _interrupt();
    }
  }

  /// The interruption path (FR-32): backgrounding, a call, focus loss.
  /// A live session's id moves — every outcome the cancelled session
  /// might still emit now carries a stale id and drops — the platform
  /// half is told to stop, and the capsule returns to rest. A press
  /// still pending its start owns no recognizer (the permission
  /// dialog's own `inactive`/`paused` is that case): its fate is
  /// decided by the start resolution's foreground gate, so the
  /// lifecycle event touches nothing here. No transcript lands, no
  /// error surfaces: partial results never crossed the port in the
  /// first place.
  void _interrupt() {
    if (!_listening) {
      return;
    }
    final standing = _sessionId++;
    unawaited(_cancelQuietly(standing));
    _setListening(false);
  }

  void _setListening(bool listening) {
    if (_listening == listening) {
      return;
    }
    _listening = listening;
    _notify();
  }

  /// The one notification path: a disposed controller notifies nobody —
  /// a press or refresh resolving after disposal may still mutate its
  /// own fields, but no listener exists to reach.
  void _notify() {
    if (!_disposed) {
      notifyListeners();
    }
  }

  /// The capture surface's exit hook (FR-32): `Descartar`, the system
  /// back, `Guardar`'s pop — every path that leaves the surface ends
  /// any dictation the capsule owned, because nothing listens outside
  /// an explicit press on that surface. The lifecycle interruption's
  /// own mechanics: the standing session's id moves (a press still
  /// awaiting its start loses its claim the same way a live utterance
  /// does, so its outcomes drop as stale), the platform half is told
  /// to stop quietly, and the capsule returns to rest. A no-op when
  /// no session stands — neither live nor awaiting its start: exiting
  /// with the affordance absent or at rest cancels nothing and
  /// notifies nobody.
  void surfaceExited() {
    if (!_starting && !_listening) {
      return;
    }
    final standing = _sessionId;
    _sessionId++;
    unawaited(_cancelQuietly(standing));
    _setListening(false);
  }

  /// The terminal outcome reader: the commit point. A stale session id
  /// drops the event; a transcript commits (replacing the line through
  /// [onTranscript]); nothing resets the capsule quietly and the
  /// capsule's own rest follows. A blank-after-trim final result
  /// writes nothing — the `_onSave` guard's terms.
  void _onOutcome(RecognizerOutcome outcome) {
    if (outcome.sessionId != _sessionId) {
      return;
    }
    _setListening(false);
    final transcript = outcome.transcript;
    if (transcript != null && transcript.trim().isNotEmpty) {
      onTranscript?.call(transcript);
    }
  }

  /// Appends exactly one `permission_refused` {microphone} row through
  /// the core's single sanctioned minter, on the capture controller's
  /// own shape: the instant minted at entry, before any await, a v7 id
  /// per row, the shared `LogWriteQueue` serializing the append
  /// against every other write the shell owns. A failing store is
  /// absorbed quietly — the queue recovers and nothing surfaces.
  Future<void> _appendRefusal() {
    final now = nowOf();
    return writeQueue
        .enqueue(() async {
          for (final content in permissionRefuse(Permission.microphone)) {
            await store.appendLogEntry((
              id: idMinter.v7(),
              kind: content.kind.name,
              instantUtcMicros: now.microsecondsSinceEpoch,
              offsetSeconds: now.timeZoneOffset.inSeconds,
              itemId: content.itemId,
              itemOrigin: content.itemOrigin,
              stack: content.stack,
              settingKey: content.settingKey,
              settingValue: content.settingValue,
              pocketMinutes: content.pocketMinutes,
              energyLevel: content.energyLevel,
              reportValue: content.reportValue,
              reportWeek: content.reportWeek,
              permission: content.permission?.name,
            ));
          }
        })
        .catchError((Object _) {});
  }

  Future<RecognizerAvailability?> _probeQuietly() async {
    try {
      return await recognizer.probe();
    } catch (_) {
      return null;
    }
  }

  Future<RecognizerStart?> _startQuietly(int sessionId) async {
    try {
      return await recognizer.start(sessionId);
    } catch (_) {
      return null;
    }
  }

  Future<void> _cancelQuietly(int sessionId) async {
    try {
      await recognizer.cancel(sessionId);
    } catch (_) {
      // Quiet by construction: the cancellation's whole duty is that
      // nothing follows.
    }
  }

  Future<bool?> _micMayBeAsked() async {
    try {
      final entries = logEntriesOf(await store.readLogEntries());
      return permissionMayBeAsked(entries, Permission.microphone);
    } catch (_) {
      return null;
    }
  }
}

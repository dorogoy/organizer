import 'dart:async';

import 'package:core/ports/recognizer_port.dart';
import 'package:flutter/services.dart';

/// The `dictate` channel's name — one of the three hand-written
/// channels (AD-11), and an infrastructure identifier, never widget
/// copy: a named string constant on the store module's terms (AD-15's
/// ban is on literals reaching a widget).
const String dictateChannelName = 'dev.dorogoy.organizer/dictate';

/// The probe method's name: availability + the permission's granted
/// bit, recomputed on every call — never cached.
const String dictateProbeMethod = 'probe';

/// The start method's name: one press's utterance, owning its session.
const String dictateStartMethod = 'start';

/// The cancel method's name: the interruption path — nothing listens
/// outside an explicit press's foreground lifetime.
const String dictateCancelMethod = 'cancel';

/// The Settings reactivation row's action: the system app-details
/// screen, the permission surface's only recovery path.
const String dictateOpenAppSettingsMethod = 'openAppSettings';

/// The Kotlin→Dart outcome callback's name: one terminal outcome per
/// session, the final transcript or nothing.
const String dictateOutcomeMethod = 'outcome';

/// The outcome map's session-id key.
const String dictateSessionIdKey = 'sessionId';

/// The outcome map's transcript key — absent when nothing landed.
const String dictateTranscriptKey = 'transcript';

/// The probe's wire answers (the 3-1 rule: `unavailable` wins over
/// everything — the service, the model, or the support check).
const String dictateUnavailableWire = 'unavailable';
const String dictateAskableWire = 'askable';
const String dictateGrantedWire = 'granted';

/// The start's wire answers.
const String dictateListeningWire = 'listening';
const String dictateRefusedWire = 'refused';

/// The drift-side adapter over the hand-written Kotlin `dictate`
/// channel (Story 3.4, FR-32, AD-11) — the RecognizerPort's platform
/// half. Thin by design: it translates wire text into the port's
/// vocabulary and nothing else. The availability rule, the permission
/// request at first press, the main-looper marshalling of every
/// recognition callback and the terminal-only commit all live on the
/// Kotlin side; this half drops nothing a fresh session id did not
/// mint (the controller owns that judgement).
///
/// One instance owns the channel's method-call handler (the handler
/// is per-channel, last-set-wins): main constructs this adapter once
/// and threads it to every consumer.
class DictateRecognizer implements RecognizerPort {
  DictateRecognizer() {
    _channel.setMethodCallHandler(_onMethodCall);
  }

  static const MethodChannel _channel = MethodChannel(dictateChannelName);

  final _outcomes = StreamController<RecognizerOutcome>.broadcast();

  @override
  Future<RecognizerAvailability> probe() async {
    final answer = await _channel.invokeMethod<String>(dictateProbeMethod);
    switch (answer) {
      case dictateUnavailableWire:
        return RecognizerAvailability.unavailable;
      case dictateAskableWire:
        return RecognizerAvailability.askable;
      case dictateGrantedWire:
        return RecognizerAvailability.granted;
      default:
        // A wire answer outside the protocol is a format violation,
        // never a quiet `unavailable`: the caller absorbs it on its
        // own quiet terms (a failed probe leaves the standing state
        // exactly as it was), while the violation stays visible to
        // the seam's tests.
        throw const FormatException();
    }
  }

  @override
  Future<RecognizerStart> start(int sessionId) async {
    final answer = await _channel.invokeMethod<String>(
      dictateStartMethod,
      sessionId,
    );
    switch (answer) {
      case dictateListeningWire:
        return RecognizerStart.listening;
      case dictateRefusedWire:
        return RecognizerStart.refused;
      case dictateUnavailableWire:
        return RecognizerStart.unavailable;
      default:
        throw const FormatException();
    }
  }

  @override
  Future<void> cancel(int sessionId) =>
      _channel.invokeMethod<void>(dictateCancelMethod, sessionId);

  @override
  Stream<RecognizerOutcome> get outcomes => _outcomes.stream;

  @override
  Future<void> openAppSettings() =>
      _channel.invokeMethod<void>(dictateOpenAppSettingsMethod);

  Future<dynamic> _onMethodCall(MethodCall call) async {
    if (call.method != dictateOutcomeMethod) {
      return null;
    }
    final args = call.arguments;
    if (args is! Map) {
      return null;
    }
    final sessionId = args[dictateSessionIdKey];
    if (sessionId is! int) {
      return null;
    }
    final transcript = args[dictateTranscriptKey];
    _outcomes.add((
      sessionId: sessionId,
      transcript: transcript is String ? transcript : null,
    ));
    return null;
  }
}

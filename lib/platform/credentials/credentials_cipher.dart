import 'package:flutter/services.dart';

/// The `credentials` channel's name — the second of the build's
/// exactly three hand-written channels (AD-11, Story 4.3, AD-22) —
/// an infrastructure identifier, never widget copy: a named string
/// constant on the platform module's terms (AD-15's ban is on
/// literals reaching a widget).
const String credentialsChannelName = 'dev.dorogoy.organizer/credentials';

/// The seal method's name: plaintext bytes in, envelope bytes out,
/// under the one non-exportable AndroidKeyStore wrapping key.
const String credentialsSealMethod = 'seal';

/// The unseal method's name: envelope bytes in, plaintext bytes out
/// — or one of the two failure words.
const String credentialsUnsealMethod = 'unseal';

/// The outcome map's outcome key — every answer is a structured map;
/// no `PlatformException` ever crosses (native failures fold to wire
/// words before they reach the channel).
const String credentialsOutcomeKey = 'outcome';

/// The seal answer's envelope key, present only on `sealed`.
const String credentialsEnvelopeKey = 'envelope';

/// The unseal answer's plaintext key, present only on `ready`.
const String credentialsPlaintextKey = 'plaintext';

/// The wire words (the Kotlin half's folded outcomes): `sealed` is a
/// seal's success, `ready` an unseal's — the plaintext decrypted and
/// the request may proceed. `corrupt` names an envelope that does
/// not decrypt under the wrapping key (AEAD failure or malformed
/// bytes); `invalidated` names key material the AndroidKeyStore
/// will not let this build use.
const String credentialsSealedWire = 'sealed';
const String credentialsReadyWire = 'ready';
const String credentialsCorruptWire = 'corrupt';
const String credentialsInvalidatedWire = 'invalidated';

/// Why a seal or unseal did not produce bytes: the measured failure
/// the vault folds into its own vocabulary. Exactly two causes
/// cross the wire — missing is Dart/Files-side and never the
/// channel's to say.
enum CredentialsCipherFailure {
  /// The envelope does not decrypt: AEAD failure or malformed
  /// bytes (`AEADBadTagException` folded on the Kotlin side).
  corrupt,

  /// The wrapping key is unusable — the AndroidKeyStore invalidated
  /// it (a key-invalidating exception folded on the Kotlin side).
  invalidated,
}

/// One seal's conversion: the envelope bytes when the outcome is
/// `sealed`, otherwise the folded failure — exactly one of the two
/// is non-null.
typedef CredentialsSealConversion = ({
  List<int>? envelope,
  CredentialsCipherFailure? failure,
});

/// One unseal's conversion: the plaintext bytes when the outcome is
/// `ready`, otherwise the folded failure — exactly one of the two
/// is non-null.
typedef CredentialsUnsealConversion = ({
  List<int>? plaintext,
  CredentialsCipherFailure? failure,
});

/// The seam the credential vault consumes (Story 4.3, AD-22): seal
/// and unseal over the one named non-exportable wrapping key, bytes
/// in and bytes out. The provider id never crosses — scoping is
/// Dart/Files-side, and the Kotlin half is a pure crypto service.
/// No method decides *when* to decrypt: the vault's `withCredential`
/// owns the request scope, and nothing here caches, retries or
/// stores anything.
abstract interface class CredentialsCipher {
  /// Seals [plaintext] under the wrapping key, returning the opaque
  /// envelope (IV inside).
  Future<CredentialsSealConversion> seal(List<int> plaintext);

  /// Unseals [envelope], returning the plaintext bytes or the
  /// measured failure.
  Future<CredentialsUnsealConversion> unseal(List<int> envelope);
}

/// The platform half over the hand-written Kotlin `credentials`
/// channel (Story 4.3, AD-22). Thin by design: it translates wire
/// maps into the seam's vocabulary and nothing else — the folding of
/// native crypto failures into wire words lives on the Kotlin side,
/// the envelope format (IV + ciphertext) is the Keystore service's
/// own, and an answer outside the protocol is a format violation
/// here, never a quiet success and never a `PlatformException`.
///
/// One instance owns the channel's method-call handler (per-channel,
/// last-set-wins): main constructs this adapter once and threads it
/// to the vault.
class CredentialsChannelCipher implements CredentialsCipher {
  static const MethodChannel _channel = MethodChannel(credentialsChannelName);

  @override
  Future<CredentialsSealConversion> seal(List<int> plaintext) async {
    final answer = await _invoke(credentialsSealMethod, plaintext);
    switch (answer[credentialsOutcomeKey]) {
      case credentialsSealedWire:
        final envelope = answer[credentialsEnvelopeKey];
        if (envelope is! List<int>) {
          // `sealed` without envelope bytes is off-protocol: a
          // success answer missing its payload is a contract
          // violation, never a quiet failure the caller could
          // mistake for measured key state.
          throw const FormatException();
        }
        return (envelope: envelope, failure: null);
      case credentialsCorruptWire:
        return (envelope: null, failure: CredentialsCipherFailure.corrupt);
      case credentialsInvalidatedWire:
        return (envelope: null, failure: CredentialsCipherFailure.invalidated);
      default:
        throw const FormatException();
    }
  }

  @override
  Future<CredentialsUnsealConversion> unseal(List<int> envelope) async {
    final answer = await _invoke(credentialsUnsealMethod, envelope);
    switch (answer[credentialsOutcomeKey]) {
      case credentialsReadyWire:
        final plaintext = answer[credentialsPlaintextKey];
        if (plaintext is! List<int>) {
          throw const FormatException();
        }
        return (plaintext: plaintext, failure: null);
      case credentialsCorruptWire:
        return (plaintext: null, failure: CredentialsCipherFailure.corrupt);
      case credentialsInvalidatedWire:
        return (plaintext: null, failure: CredentialsCipherFailure.invalidated);
      default:
        throw const FormatException();
    }
  }

  Future<Map<Object?, Object?>> _invoke(String method, List<int> bytes) async {
    // Uint8List, never a plain List: the standard codec encodes a
    // Uint8List as the bytes Kotlin receives as `byte[]` — a plain
    // list would arrive as boxed ints and fail the channel's own
    // argument read. The copy is the adapter's guarantee, whatever
    // list its caller handed in.
    final Object? answer;
    try {
      answer = await _channel.invokeMethod<Object?>(
        method,
        Uint8List.fromList(bytes),
      );
    } on PlatformException {
      // The channel speaking in exceptions is already off its
      // protocol — this half folded those away on the Kotlin side,
      // so one arriving here is a protocol violation, never a
      // crypto outcome.
      throw const FormatException();
    } on MissingPluginException {
      // An unregistered or dead channel is the same violation: the
      // wire contract check and the boot smoke own its existence,
      // and no caller may read its silence as success.
      throw const FormatException();
    }
    if (answer is! Map) {
      // A non-map answer — null included — is off-protocol the same
      // way an unknown outcome word is: never treated as success.
      throw const FormatException();
    }
    return answer.cast<Object?, Object?>();
  }
}

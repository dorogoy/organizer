import 'dart:async';
import 'dart:convert';

import 'package:core/ports/files_port.dart';
import 'package:core/settings/settings.dart';

import '../files/app_files.dart';
import '../platform/credentials/credentials_cipher.dart';

/// The vault's measured display state (Story 4.3, AD-22): what a
/// full read-and-decrypt says about one provider's credential
/// *right now*. Display state only — `withCredential` never consults
/// it (no TOCTOU): every request does its own read and unseal.
enum CredentialAvailability {
  /// A healthy envelope stands behind the provider and decrypts.
  available,

  /// No envelope is stored for the provider (and a provider id the
  /// vault refuses can never have one — it reads as missing too).
  missing,

  /// An envelope is stored but does not decrypt — AEAD failure or
  /// malformed bytes.
  corrupt,

  /// The AndroidKeyStore will not hand the wrapping key's use back
  /// — the key was invalidated under us.
  invalidated,
}

/// Why a `withCredential` request could not run: the measured cause,
/// one of the three (missing is Dart/Files-side; corrupt and
/// invalidated fold from the channel's wire words).
enum CredentialAccessCause { missing, corrupt, invalidated }

/// One `withCredential` request's outcome: either the operation ran
/// and its result returns, or the credential material was measured
/// unavailable and the operation was never invoked.
sealed class CredentialAccess<T> {
  const CredentialAccess();
}

/// The operation ran inside the request scope; [result] is its own
/// return value, unchanged.
final class AccessGranted<T> extends CredentialAccess<T> {
  const AccessGranted(this.result);

  /// The operation's result, as it returned it.
  final T result;
}

/// The credential material was unavailable; the operation was not
/// invoked — nothing was sent — and [cause] names the measured
/// reason. No retry is implied or performed.
final class AccessUnavailable<T> extends CredentialAccess<T> {
  const AccessUnavailable(this.cause);

  /// The measured cause: missing, corrupt or invalidated.
  final CredentialAccessCause cause;
}

/// The shell's credential vault (Story 4.3, AD-22): provider-scoped
/// envelopes in app-private Files storage under one non-exportable
/// AndroidKeyStore wrapping key reached through the `credentials`
/// channel's seal/unseal. The core's name for this seam is already
/// banned (`tool/check_core_purity.dart`); this is the shell half,
/// and nothing about it crosses into a derivation.
///
/// Plaintext discipline, by construction: plaintext enters only
/// [saveCredential], crosses to `seal`, and in [withCredential]
/// reaches only the operation closure as a request-scoped local —
/// no field, cache, log line, pool fact, export row, crash entry or
/// URL ever holds it, and the vault exposes no accessor returning
/// it. The provider id is validated against the core's one shared
/// charset rule ([isValidProviderId]) before anything is stored:
/// an id outside it is refused quietly by all four operations
/// (never a throw) — for the reads it reads as missing, because an
/// unstorable id can never have a stored envelope.
///
/// Saves are atomic replacements (the Files adapter's temp+rename)
/// serialized under the vault's own write queue — the settings
/// controller's `_enqueueWrite` pattern — and deletes are
/// idempotent: the same outcome whether or not the envelope
/// existed. Only the file writes serialize: a seal is pure crypto
/// over the one wrapping key and touches no file, so seals may run
/// concurrently with the queue — it is the envelope write (or
/// delete) that lands in order. Corrupt-after-invalidation is
/// honest, not a bug: re-sealing after a Keystore invalidation
/// mints a fresh key and the old envelopes read as corrupt; nothing
/// is auto-deleted.
class CredentialVault {
  CredentialVault({required this.files, required this.cipher});

  /// The app-private byte store — the envelope store's only
  /// persistence surface (never preferences, never the log).
  final FilesPort files;

  /// The seal/unseal seam over the hand-written `credentials`
  /// channel.
  final CredentialsCipher cipher;

  /// The serialized write path: one save or delete runs to
  /// completion before the next begins, so a rapid replace cannot
  /// interleave two temp+rename pairs. Failures clear from the
  /// chain itself so one throwing change never wedges the next.
  Future<void> _writes = Future<void>.value();

  /// Saves [plaintext] as the provider's sealed envelope — an
  /// atomic replacement of whatever envelope stood there before.
  /// Quiet outcome, never a throw: a refused provider id or a
  /// failed seal appends nothing, stores nothing, and surfaces
  /// nothing — the next `credentialAvailable` read measures the
  /// result.
  Future<void> saveCredential(String provider, String plaintext) {
    if (!isValidProviderId(provider)) {
      return Future<void>.value();
    }
    final sealing = cipher
        .seal(utf8.encode(plaintext))
        .catchError(
          (Object _) =>
              (envelope: null, failure: CredentialsCipherFailure.corrupt),
        );
    // The returned future is quiet by contract (never a throw): a
    // refused id, a failed seal, a failed write — the next read
    // measures the result, and no error surface exists anywhere.
    return _enqueueWrite(() async {
      final sealed = await sealing;
      final envelope = sealed.envelope;
      if (envelope == null) {
        // The seal measured a failure: nothing is written, and the
        // previous envelope — if any — stands exactly as it was.
        return;
      }
      await files.write(credentialFilesScope, provider, envelope);
    }).then<void>((_) {}, onError: (Object _) {});
  }

  /// Deletes the provider's envelope. Idempotent: the outcome is
  /// the same whether or not one existed, an absent file is not an
  /// error, and a failed delete is swallowed exactly as a failed
  /// save is — the two writes share one error discipline, quiet on
  /// every path.
  Future<void> deleteCredential(String provider) {
    if (!isValidProviderId(provider)) {
      return Future<void>.value();
    }
    return _enqueueWrite(() => files.delete(credentialFilesScope, provider))
        .then<void>((_) {}, onError: (Object _) {});
  }

  /// Measures the provider's credential state now: a full read and
  /// unseal, the same work a request would do — display state only,
  /// never request authorisation ([withCredential] does its own
  /// read+unseal; consulting this would be a TOCTOU). The settled
  /// write chain drains first so the measurement cannot race a
  /// queued save into reading a superseded envelope.
  Future<CredentialAvailability> credentialAvailable(String provider) async {
    if (!isValidProviderId(provider)) {
      return CredentialAvailability.missing;
    }
    await _writes;
    final envelope = await files.read(credentialFilesScope, provider);
    if (envelope == null) {
      return CredentialAvailability.missing;
    }
    final unsealed = await cipher.unseal(envelope);
    final failure = unsealed.failure;
    if (failure != null) {
      return switch (failure) {
        CredentialsCipherFailure.corrupt => CredentialAvailability.corrupt,
        CredentialsCipherFailure.invalidated =>
          CredentialAvailability.invalidated,
      };
    }
    final plaintextBytes = unsealed.plaintext;
    if (plaintextBytes == null) {
      return CredentialAvailability.corrupt;
    }
    try {
      utf8.decode(plaintextBytes);
      return CredentialAvailability.available;
    } on FormatException {
      return CredentialAvailability.corrupt;
    }
  }

  /// Runs [operation] with the provider's plaintext — the one
  /// request scope (Story 4.3, AD-22). The operation is invoked
  /// only after the envelope is read and unsealed right here right
  /// now: when the material is unavailable the operation is **not
  /// invoked** (nothing is sent) and the cause names why; on a
  /// grant, the plaintext is a local of this request alone and the
  /// operation's result returns unchanged inside
  /// [AccessGranted]. The operation's own errors propagate
  /// unchanged — the vault wraps nothing, retries nothing.
  ///
  /// This method never consults [credentialAvailable] (no TOCTOU:
  /// every request does its own read and unseal). It drains the
  /// settled write chain before that read — the same discipline
  /// [credentialAvailable] holds — so a racing request can never
  /// send just-revoked or superseded material. The drain completes
  /// before the operation is invoked, so an operation that itself
  /// saves or deletes only ever enqueues behind this request, never
  /// deadlocks inside it.
  Future<CredentialAccess<T>> withCredential<T>(
    String provider,
    FutureOr<T> Function(String plaintext) operation,
  ) async {
    if (!isValidProviderId(provider)) {
      return AccessUnavailable(CredentialAccessCause.missing);
    }
    await _writes;
    final envelope = await files.read(credentialFilesScope, provider);
    if (envelope == null) {
      return AccessUnavailable(CredentialAccessCause.missing);
    }
    final unsealed = await cipher.unseal(envelope);
    final plaintextBytes = unsealed.plaintext;
    if (plaintextBytes == null) {
      return AccessUnavailable(switch (unsealed.failure) {
        CredentialsCipherFailure.corrupt => CredentialAccessCause.corrupt,
        CredentialsCipherFailure.invalidated =>
          CredentialAccessCause.invalidated,
        null => CredentialAccessCause.missing,
      });
    }
    final String plaintext;
    try {
      plaintext = utf8.decode(plaintextBytes);
    } on FormatException {
      // Bytes that are not the UTF-8 the vault sealed: an envelope
      // this build cannot read back, folded to corrupt so the
      // vocabulary stays closed. Unreachable in practice (every
      // envelope sealed a String) — the guard is the consistency,
      // not the expectation.
      return AccessUnavailable(CredentialAccessCause.corrupt);
    }
    return AccessGranted(await operation(plaintext));
  }

  Future<void> _enqueueWrite(Future<void> Function() step) {
    final chained = _writes.then((_) => step());
    // The caller observes the attempt's failure, while the chain
    // itself recovers so a later change can retry.
    _writes = chained.catchError((Object error) {});
    return chained;
  }
}

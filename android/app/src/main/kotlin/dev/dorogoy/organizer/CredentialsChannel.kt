package dev.dorogoy.organizer

import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * The hand-written `credentials` channel (Story 4.3, AD-22) — the
 * second of the build's exactly three channels: seal and unseal
 * under the one named non-exportable AndroidKeyStore wrapping key,
 * and nothing else. The provider id never crosses — the Kotlin half
 * is a pure crypto service over the one key, and scoping lives on
 * the Dart/Files side. Registered by `MainActivity
 * .configureFlutterEngine` and torn down in its cleanup.
 *
 * The protocol (mirrored by the named constants in
 * `lib/platform/credentials/credentials_cipher.dart`, pinned by the
 * wire-contract check — the dictate's three-copy pattern):
 *  - `seal(plaintext)` → `{outcome: "sealed", envelope}` — the
 *    opaque envelope bytes, IV inside; or `{outcome: "invalidated"}`
 *    when the key material cannot be minted or used.
 *  - `unseal(envelope)` → `{outcome: "ready", plaintext}` — the
 *    decrypted bytes; or `{outcome: "corrupt" | "invalidated"}` for
 *    the two measured failure words (an envelope that does not
 *    decrypt; key material the keystore will not hand back).
 *
 * No `PlatformException` ever crosses: the Keystore service folds
 * its own crypto failures into the result shape before they reach
 * this file, and this half only ever answers structured outcome
 * maps. Every handler runs confined to the main looper
 * (platform-channel handlers arrive there), so no cross-thread
 * state exists to race.
 */
internal class CredentialsChannel(
    messenger: io.flutter.plugin.common.BinaryMessenger,
) {
    private val methodChannel = MethodChannel(messenger, CHANNEL_NAME)
    private val keystore = CredentialKeystore()

    init {
        methodChannel.setMethodCallHandler(::onMethodCall)
    }

    private fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            SEAL_METHOD -> {
                val plaintext = call.arguments as? ByteArray
                if (plaintext == null) {
                    // Bytes that did not arrive are malformed input,
                    // and malformed folds to corrupt — a structured
                    // map always, never an error surface.
                    result.success(corruptOutcome())
                    return
                }
                when (val sealed = keystore.seal(plaintext)) {
                    is CredentialKeystore.Result.Sealed ->
                        result.success(
                            mapOf(
                                OUTCOME_KEY to WIRE_SEALED,
                                ENVELOPE_KEY to sealed.envelope,
                            ),
                        )
                    is CredentialKeystore.Result.Ready -> result.success(corruptOutcome())
                    CredentialKeystore.Result.Corrupt -> result.success(corruptOutcome())
                    CredentialKeystore.Result.Invalidated -> result.success(invalidatedOutcome())
                }
            }
            UNSEAL_METHOD -> {
                val envelope = call.arguments as? ByteArray
                if (envelope == null) {
                    result.success(corruptOutcome())
                    return
                }
                when (val unsealed = keystore.unseal(envelope)) {
                    is CredentialKeystore.Result.Ready ->
                        result.success(
                            mapOf(
                                OUTCOME_KEY to WIRE_READY,
                                PLAINTEXT_KEY to unsealed.plaintext,
                            ),
                        )
                    is CredentialKeystore.Result.Sealed -> result.success(corruptOutcome())
                    CredentialKeystore.Result.Corrupt -> result.success(corruptOutcome())
                    CredentialKeystore.Result.Invalidated -> result.success(invalidatedOutcome())
                }
            }
            else -> result.notImplemented()
        }
    }

    /** The teardown: the handler is released outright. */
    fun destroy() {
        methodChannel.setMethodCallHandler(null)
    }

    private fun corruptOutcome(): Map<String, String> = mapOf(OUTCOME_KEY to WIRE_CORRUPT)

    private fun invalidatedOutcome(): Map<String, String> = mapOf(OUTCOME_KEY to WIRE_INVALIDATED)

    private companion object {
        const val CHANNEL_NAME = "dev.dorogoy.organizer/credentials"
        const val SEAL_METHOD = "seal"
        const val UNSEAL_METHOD = "unseal"
        const val OUTCOME_KEY = "outcome"
        const val ENVELOPE_KEY = "envelope"
        const val PLAINTEXT_KEY = "plaintext"
        const val WIRE_SEALED = "sealed"
        const val WIRE_READY = "ready"
        const val WIRE_CORRUPT = "corrupt"
        const val WIRE_INVALIDATED = "invalidated"
    }
}

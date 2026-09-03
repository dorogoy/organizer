package dev.dorogoy.organizer

import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyProperties
import java.security.KeyStore
import java.security.UnrecoverableKeyException
import javax.crypto.AEADBadTagException
import javax.crypto.BadPaddingException
import javax.crypto.Cipher
import javax.crypto.IllegalBlockSizeException
import javax.crypto.KeyGenerator
import javax.crypto.SecretKey
import javax.crypto.spec.GCMParameterSpec

/**
 * The Keystore service behind the `credentials` channel (Story 4.3,
 * AD-22) — the store seal's one closed native exception, allowlisted
 * for exactly this file: AES-256-GCM under one named non-exportable
 * AndroidKeyStore wrapping key, generated on first use, no biometric
 * or user-auth binding. This class is a pure crypto service: bytes
 * in, folded results out. It opens no file (envelope storage is
 * Dart/Files-side), opens no socket, computes no date, and holds no
 * state beyond the AndroidKeyStore's own.
 *
 * The envelope format is this file's alone: `IV ‖ ciphertext+tag`,
 * the 12-byte GCM IV prepended — opaque bytes to every caller, and
 * the reason a wrong-key envelope folds to [Result.Corrupt] the
 * moment a fresh key stands where the original did.
 *
 * Failure folding happens here, inside the crypto boundary, so the
 * channel file needs no crypto import and the wire never sees a
 * `PlatformException`: AEAD failures, bad padding and malformed
 * inputs are [Result.Corrupt]; key-invalidating failures (the key
 * invalidated under us, the keystore refusing its use, or the key
 * absent on an unseal that never mints) are [Result.Invalidated].
 * Design note: an absent key is *not* an error path for sealing —
 * the next seal mints a fresh key (generate-on-first-use) and the
 * old envelopes read as corrupt thereafter; nothing is
 * auto-deleted.
 */
internal class CredentialKeystore {

    /** The wrapping key's one AndroidKeyStore alias. */
    private val alias = WRAPPING_KEY_ALIAS

    /**
     * One folded crypto outcome: the bytes on success, or one of the
     * two measured failure words — never an exception, so the channel
     * maps these onto the wire without ever touching a crypto type.
     */
    sealed class Result {
        class Sealed(val envelope: ByteArray) : Result()
        class Ready(val plaintext: ByteArray) : Result()
        object Corrupt : Result()
        object Invalidated : Result()
    }

    /**
     * Seals [plaintext] under the wrapping key: mints the key on
     * first use (non-exportable by construction — the AndroidKeyStore
     * generates it inside itself and no code path can read it out),
     * then returns `IV ‖ ciphertext+tag`.
     */
    fun seal(plaintext: ByteArray): Result = try {
        val cipher = Cipher.getInstance(TRANSFORMATION)
        cipher.init(Cipher.ENCRYPT_MODE, wrappingKey(generate = true))
        Result.Sealed(cipher.iv + cipher.doFinal(plaintext))
    } catch (failure: Exception) {
        fold(failure)
    }

    /**
     * Unseals [envelope] under the wrapping key. Never mints: an
     * envelope from a key this device no longer holds folds to
     * [Result.Invalidated] — the honest word for key material that
     * is gone, since the envelope's own bytes may be perfectly fine
     * and the next seal will mint a fresh key regardless.
     */
    fun unseal(envelope: ByteArray): Result = try {
        if (envelope.size < IV_LENGTH_BYTES) {
            throw IllegalArgumentException("envelope shorter than its IV")
        }
        val cipher = Cipher.getInstance(TRANSFORMATION)
        cipher.init(
            Cipher.DECRYPT_MODE,
            wrappingKey(generate = false),
            GCMParameterSpec(TAG_LENGTH_BITS, envelope.copyOfRange(0, IV_LENGTH_BYTES)),
        )
        Result.Ready(cipher.doFinal(envelope.copyOfRange(IV_LENGTH_BYTES, envelope.size)))
    } catch (failure: Exception) {
        fold(failure)
    }

    /**
     * The one folding point: native crypto failures to the two wire
     * words the channel knows. Everything unrecognized lands on
     * [Result.Invalidated] — the keystore refusing to work is key
     * material this build cannot use, never a crash onto the channel.
     */
    private fun fold(failure: Exception): Result = when (failure) {
        is AEADBadTagException,
        is BadPaddingException,
        is IllegalBlockSizeException,
        is IllegalArgumentException,
        -> Result.Corrupt
        else -> Result.Invalidated
    }

    /** The wrapping key, generated on first use only when [generate]. */
    private fun wrappingKey(generate: Boolean): SecretKey {
        val keyStore = KeyStore.getInstance(ANDROID_KEYSTORE).apply { load(null) }
        val existing = keyStore.getKey(alias, null)
        if (existing is SecretKey) {
            return existing
        }
        if (!generate) {
            throw UnrecoverableKeyException("the wrapping key is absent")
        }
        val generator = KeyGenerator.getInstance(KeyProperties.KEY_ALGORITHM_AES, ANDROID_KEYSTORE)
        generator.init(
            KeyGenParameterSpec.Builder(
                alias,
                KeyProperties.PURPOSE_ENCRYPT or KeyProperties.PURPOSE_DECRYPT,
            )
                .setBlockModes(KeyProperties.BLOCK_MODE_GCM)
                .setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_NONE)
                .setKeySize(KEY_LENGTH_BITS)
                .build(),
        )
        return generator.generateKey()
    }

    private companion object {
        const val ANDROID_KEYSTORE = "AndroidKeyStore"
        const val WRAPPING_KEY_ALIAS = "organizer_credential_wrapping"
        const val TRANSFORMATION = "AES/GCM/NoPadding"
        const val IV_LENGTH_BYTES = 12
        const val TAG_LENGTH_BITS = 128
        const val KEY_LENGTH_BITS = 256
    }
}

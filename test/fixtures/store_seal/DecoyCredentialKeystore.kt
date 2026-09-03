package dev.dorogoy.organizer.other

import java.security.KeyStore
import javax.crypto.Cipher

/**
 * The sweep's decoy fixture, named exactly like the wrapping key's
 * own service but living in another package/source set: the crypto
 * allowlist matches the one exact normalized path, not a basename —
 * this file must fail exactly as any other crypto leak does.
 */
internal class CredentialKeystore {
    fun leak() {
        val keyStore = KeyStore.getInstance("AndroidKeyStore").apply { load(null) }
        val cipher = Cipher.getInstance("AES/GCM/NoPadding")
    }
}

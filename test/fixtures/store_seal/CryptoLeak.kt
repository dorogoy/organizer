package dev.dorogoy.organizer

import java.security.KeyStore
import javax.crypto.Cipher

/**
 * The sweep's violating fixture: Keystore/crypto APIs outside the one
 * allowlisted file — both on the import lines and in the body.
 */
internal class CryptoLeak {
    fun leak(): ByteArray {
        val keyStore = KeyStore.getInstance("AndroidKeyStore").apply { load(null) }
        val cipher = Cipher.getInstance("AES/GCM/NoPadding")
        val qualified = javax.crypto.KeyGenerator.getInstance("AES")
        return byteArrayOf()
    }
}

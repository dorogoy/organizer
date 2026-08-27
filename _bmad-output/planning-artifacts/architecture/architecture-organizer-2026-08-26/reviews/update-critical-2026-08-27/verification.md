# Independent reality verification — final confirmation

Date: 2026-08-27  
Scope: final AD-13/AD-22 confirmation against current official Android contracts.  
Spine modification: none.

## Verdict

**PASS — AD-13, AD-22, the Structural Seed and the Stack table now align and pass this official-reality verification scope.**

## Confirmed

- **AD-13 passes.** Create-once immutable snapshots and manifests, exact-byte hashes, deterministic sequence/UUID ordering, rejection of partial/incomplete inventory, and refusal to use SAF rename as an atomic commit are consistent with `DocumentsContract`. Conservative retention now correctly avoids inferring global listing completeness from a cloud-capable `DocumentsProvider`; automatic cleanup is limited to installation-recorded uncommitted debris.
- **AD-22 passes.** The owned Kotlin `credentials` channel cleanly distinguishes the non-exportable AndroidKeyStore AEAD wrapping key from provider credential ciphertext in app-private Files. Scoped decryption at request time, invalidation handling, and excluding live credential capability from replay/export match Android's actual Keystore guarantees.
- **The prior plugin conflict is closed** in AD-11 and the Stack table: `flutter_secure_storage` is explicitly not used.

Primary sources:

- Android Keystore guarantees: https://developer.android.com/privacy-and-security/keystore
- Keystore invalidation: https://developer.android.com/reference/android/security/keystore/KeyPermanentlyInvalidatedException
- SAF grants and persistence limitations: https://developer.android.com/training/data-storage/shared/documents-files
- Provider capability and partial-document flags: https://developer.android.com/reference/android/provider/DocumentsContract.Document
- Rename contract (no atomic-commit guarantee; URI may change): https://developer.android.com/reference/android/provider/DocumentsContract#renameDocument(android.content.ContentResolver,android.net.Uri,java.lang.String)
- Provider-dependent stream semantics: https://developer.android.com/reference/android/content/ContentResolver#openOutputStream(android.net.Uri,java.lang.String)

## Final alignment confirmation

The Structural Seed now lists only `camera · mlkit face · saf_util/saf_stream` under `plugins/`, while `android/app/src/main/kotlin/` owns the native `credentials` channel. This matches AD-11 and the Stack row that explicitly rejects `flutter_secure_storage`. The last blocker is closed; no blocker remains in this verification scope.

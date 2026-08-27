# Final adversarial confirmation — AD-13 / AD-22

Date: 2026-08-27  
Scope: final re-attack of all previously reported counterexamples  
Edits to spine: none

## Verdict

**PASS — no blocker and no remaining critical/high divergence.**

## Attack replay

| Attack | Verdict | Contract that closes it |
| --- | --- | --- |
| Pool/log snapshots represent different logical instants | Closed | Both are read in one SQLite read transaction under the coordinator. |
| Export/import/cleanup race locally or across isolates/processes | Closed | One process-wide foreground coordinator covers all three plus album mutation; background isolate and second-process execution are forbidden. |
| Two importers disagree on newest generation | Closed | Canonical UUIDv7 text plus integer sequence and total `(generationSequence, generationId)` order; wall clock and listing order are irrelevant. |
| Delayed visibility creates same-sequence branches | Closed | Branches remain deterministic under the total tuple and carry explicit predecessor identity. |
| SAF eventual/incomplete visibility causes destructive GC | Closed | Automatic cleanup cannot delete any committed manifest, committed snapshot, or content-addressed blob. It may delete only names recorded by this installation's own failed uncommitted attempt. Visibility uncertainty therefore costs space, never recovery. |
| Checksum implementations disagree | Closed | UTF-8 JSON schema pins 64-character lowercase-hex SHA-256 over exact file bytes plus non-negative byte length. |
| Manifest paths/roles alias or escape authoritative storage | Closed | Inventory roles are closed to `pool`, `log`, `album_blob`; paths are contained relative lowercase-ASCII segments with empty, `.` and `..` forbidden; fields and inventory have canonical lexicographic emission. |
| Existing name is overwritten or reused incompatibly | Closed | Every target is create-once; collision is structural corruption, never overwrite. |
| Source album deletion invalidates prior export | Closed | App-private source deletion and retained exported blobs have distinct lifecycles; committed blobs are never automatically deleted. |
| Presence check is mistaken for credential usability | Closed | Availability requires successful decryption now and is explicitly display-only, never request authorization. |
| Egress invents a secret-retrieval seam or cannot authenticate | Closed | Every request must use the named `withCredential(provider, operation)` scope; the vault supplies plaintext only to that egress operation and releases references at return. |
| Wrong provider credential is reused/replaced/deleted | Closed | Ciphertext envelopes and save replacement are provider-scoped under the vault lock; delete is idempotent. |
| Android invalidation occurs between UI check and request | Closed | The UI check authorizes nothing; request-time `withCredential` decrypts afresh and maps missing/corrupt/invalidated material to unavailable without sending. |
| Secret leaks into replayable/exported state | Closed | Plaintext ingress and egress paths are closed; core, log, pool, export, crash event, URL and caches are forbidden sinks. Envelopes live only in app-private Files; only the Kotlin CredentialVault may use AndroidKeyStore, solely for the non-exportable wrapping key. |
| A fourth credential store bypasses the architecture | Closed | AD-21 names the sole native exception and store seal: Files owns envelopes, Kotlin CredentialVault composes Files with one named Keystore key, and no adapter-private persistence exists. |

## Final disposition

- Critical: 0
- High: 0
- Medium blockers: 0
- Prior medium items: closed by the canonical manifest contract and named `withCredential` request scope.
- Result: AD-13 and AD-22 are convergent enough for independent implementation units.

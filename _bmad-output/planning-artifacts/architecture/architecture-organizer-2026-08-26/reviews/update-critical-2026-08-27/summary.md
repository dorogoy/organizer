# Critical findings update — final gate

**Date:** 2026-08-27  
**Scope:** C1 export atomicity; C2 restored credential availability  
**Verdict:** **PASS**

## C1 — closed

AD-13 now defines immutable export generations, a shared SQLite snapshot, a process-wide foreground coordinator, a canonical committed manifest, exact-byte SHA-256 verification, deterministic generation ordering and non-destructive recovery under partial SAF visibility. Automatic cleanup never removes committed generations or shared blobs; committed-generation compaction is explicitly Deferred.

## C2 — closed

AD-22 now separates replayable provider choice from installation-local credential capability. AndroidKeyStore owns a non-exportable AEAD wrapping key; provider credentials are encrypted in provider-scoped app-private Files envelopes. Availability requires successful decryption and is display-only; every provider request uses request-scoped `withCredential`. Secret material never crosses the core, log, pool or export.

## Gate evidence

- Deterministic lint: PASS, 0 findings.
- Rubric review: PASS.
- Technology/reality verification: PASS.
- Adversarial review: PASS, no blockers.
- `git diff --check`: PASS.

Full reviews: [rubric](rubric.md), [verification](verification.md), [adversarial](adversarial.md).

## Upstream reconciliation offered

PRD FR-28 currently says the provider key is held in the OS keystore. The spine implements the viable precise meaning: a non-exportable wrapping key is held in AndroidKeyStore and the provider credential is held only as ciphertext in app-private Files storage. The PRD should be amended to use the same wording so source and architecture cannot be read incompatibly.

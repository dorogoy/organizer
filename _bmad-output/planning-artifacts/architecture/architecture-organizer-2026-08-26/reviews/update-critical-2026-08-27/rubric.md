# Good-spine rubric — critical update 2026-08-27

## Terminal confirmation

**PASS.** The final blocker is closed: the testing convention now repeats AD-21's exact store-seal boundary—Store, Folder and Files, plus CredentialVault's allowlisted AndroidKeyStore access solely for the wrapping key. This terminal verdict supersedes every earlier verdict retained below as review history.

## Final confirmation pass

### Final verdict

**ACCEPT WITH ONE HIGH-SEVERITY TEXTUAL FIX.** No critical blocker remains; `lint_spine.py` passes with 0 findings. This section supersedes both earlier verdicts retained below as audit history.

- **Sibling-generation critical closed:** automatic cleanup no longer deletes any committed generation, snapshot or content-addressed blob. Partial visibility and branches can increase storage but cannot destroy a recoverable generation. Committed compaction is explicitly Deferred with a revisit condition.
- **Store-seal rule closed in AD-21:** it names the sole native exception—CredentialVault may call AndroidKeyStore only for the wrapping key—and keeps credential envelopes behind Files.
- **Stack/diagram contradiction closed:** `flutter_secure_storage` is explicitly unused; the Stack binds the Kotlin credentials channel; Keystore is labelled as the non-exportable wrapping key; AD-11 and AD-22 agree on the envelope design and request-scoped credential use.
- **Full-rubric regression sweep:** no new critical contradictions, missing initiative-level dimensions, unsafe Deferred items, AD-ID instability, or loss of memlog decisions 85–86 found.

### Remaining high finding — testing convention omits the named Keystore exception

The `Testing — where the guards live` row still describes the store seal as “no persistence API outside the Store, Folder and Files adapters,” without AD-21's sole CredentialVault/AndroidKeyStore exception. A builder implementing that row literally will make the required credentials channel fail its own build check; another will infer an undocumented checker exemption.

**Required textual fix:** repeat AD-21's exact closed allowlist in the testing row: Store, Folder and Files, plus CredentialVault's AndroidKeyStore access solely for the AD-22 wrapping key. This is a one-line reconciliation; no architectural decision is open.

## Confirmation re-review after fixes

### Latest verdict

**FAIL — the original C1/C2/H1/H2 are closed, but one new critical fork-safety defect remains.** The mechanical lint still passes with 0 findings.

This confirmation supersedes the initial verdict below; the original review is retained as an audit trail.

### Closure of prior findings

- **Prior C1 closed:** app-private source deletion is now distinct from exported blob lifetime; exported blobs obey retained-generation reachability.
- **Prior C2 closed in substance:** AD-21 now distinguishes replayable domain state from the named installation capability, and envelopes live through Files rather than a hidden preference store.
- **Prior H1 closed:** plaintext flow is pinned to shell credential handler → vault and vault → `ByokSlicer`, transiently and never through core.
- **Prior H2 closed:** the manifest explicitly excludes itself and inventories exact data bytes with sizes and SHA-256.
- **Prior M2 closed:** fixture checks now correctly target plaintext/key shapes and persisted availability claims rather than claiming to inspect Keystore contents.
- **Prior M3 closed:** cleanup has conservative capability/visibility gates; uncertainty leaves debris rather than risking recoverability.
- **Prior M1 is no longer applicable as written:** `CredentialVault` is deliberately a shell capability, not a core port. The diagram reflects that choice.

### New critical finding

#### C3 — Partial SAF visibility can create sibling generations, but retention follows ancestry rather than “two newest verified”

**Evidence:** Generation creation reads the newest *currently visible* verified manifest and assigns `previous.sequence + 1`. AD-13 explicitly treats partial provider visibility as possible. Therefore export A can create generation `2-A` from generation 1 while generation `2-B` is temporarily invisible, producing two valid siblings with the same sequence and different UUIDs. Selection correctly orders them by `(sequence, id)`, but cleanup retains “the newest manifest and its verified predecessor,” not the two greatest verified tuples required by the adopted decision.

**Failure:** If `2-B` is the greatest tuple and `2-A` is second, cleanup retains `2-B` plus generation 1 and may delete snapshots or blobs reachable only from `2-A`. It has destroyed the second-newest verified generation even though the adopted rule promises to retain it. A later visibility change can also make the selected branch switch unexpectedly.

**Disposition:** **Autofix before handoff.** Choose one coherent protocol:

1. Recommended: after complete enumeration and verification, retain the two greatest valid tuples, regardless of ancestry. The predecessor link remains diagnostic only. Cleanup is permitted only when that complete-view precondition is established; its reachability roots are those exact two manifests.
2. Alternatively, define forks as structural corruption and refuse both selection and cleanup until repaired. This is safer but makes a valid generation temporarily unrestorable after ordinary provider inconsistency.

Extend the property corpus with stale/partial listings that create equal-sequence siblings, later reveal both, and vary UUID ordering. Assert deterministic import and preservation of the top two valid tuples.

### Residual high findings

#### H3 — The store seal still states an exhaustive rule that does not literally allow Keystore access

AD-21 says no persistence API is touched outside Store, Folder and Files, while the diagram and AD-22 give `CredentialVault` direct Android Keystore access. The later phrase “beyond AD-22's named Keystore key” signals an exception, but a build-time seal needs a syntactic allowlist and the testing convention repeats only the three adapters.

**Autofix:** say the seal permits persistence APIs only in Store, Folder, Files, plus the single Android-Keystore wrapping-key implementation owned by CredentialVault; only Files may hold credential envelopes. Repeat that exact allowlist in the testing convention.

#### H4 — Stack and deployment diagram still describe the superseded credential mechanism

The phone diagram labels Keystore as `BYOK key — never leaves`, but AD-22 says Keystore contains only a wrapping key and the BYOK credential is a ciphertext envelope in Files. The Stack still binds `flutter_secure_storage` and discusses its SharedPreferences/AES-in-Keystore modes, while AD-22 now explicitly forbids preferences and specifies a custom envelope split. A builder could follow the Stack instead of AD-22.

**Autofix:** relabel the diagram as `wrapping key — non-exportable` and show the encrypted credential envelope in app-private Files. Either remove `flutter_secure_storage` from the bound Stack and name the Android Keystore implementation used for wrapping, or state precisely how that package can implement the AD-22 envelope protocol without its preference-backed storage path.

### Confirmation checklist

The adopted memlog decisions remain preserved. No regression was found in the authoritative/derived split, import tolerance, credential-availability semantics, dependency direction, Deferred coverage, or initiative-level operational envelope. Once C3 and the two residual documentation/enforcement mismatches are reconciled, this rubric would pass.

## Verdict

**FAIL — the two adopted decisions are preserved, but the update is not yet a coherent build substrate.** AD-13's generational retention is contradicted by its older immediate-unlink rule, and AD-22's `CredentialVault` is contradicted by AD-21's exhaustive persistence boundary. Two independently built units could follow different, individually reasonable readings and either destroy a retained backup or fail the store seal.

Mechanical gate: **PASS**, `lint_spine.py` reports 0 findings.

## Preservation check

Memlog entries 85–86 are materially present:

- Entry 85 is preserved in AD-13: `generationId`, immutable pool/log snapshots, content-addressed shared blobs, manifest written last with inventory/sizes/checksums, newest-to-oldest verified import, two verified generations, post-commit reachability GC, no SAF rename-atomicity claim, and cut-after-every-write/partial-visibility/missing/checksum tests.
- Entry 86 is preserved in AD-22 and the structural diagram: `selectedProvider` persists without `keyExists`; `CredentialVault` owns key material and exposes save/delete/live availability; `providerConfigured` is choice plus live capability; availability is neither persisted nor exported; restore may retain provider choice while unconfigured; round-trip identity excludes availability; present/absent/deleted/invalidated cases and fixture checks are named.

The preservation is faithful. The failures below are reconciliation failures with pre-existing rules, not omissions of the accepted decisions.

## Critical findings

### C1 — AD-13 can delete bytes still required by a retained generation

**Evidence:** AD-13 still says `album_entry_deleted` "unlinks the file in the same operation" and that purge unlinks all album files. The adopted generation rule says album images are immutable content-addressed blobs shared across generations, the two newest verified generations are retained, and GC deletes only bytes unreachable from both retained manifests.

**Divergence:** An album-delete story can follow the immediate-unlink sentence and remove a blob referenced by generation N, while the export-retention story follows reachability and expects generation N to remain restorable. The next import then rejects what was a retained verified generation. The same failure applies to purge.

**Disposition:** **Autofix.** Replace immediate physical unlink with logical deletion by event. App-private working bytes may be removed when no live read model needs them, but exported content-addressed blobs may be removed only by AD-13's post-commit reachability GC after neither retained manifest references them. State explicitly that purge does not override retained-generation reachability.

### C2 — AD-22's vault violates AD-21's exhaustive “no other store” and store seal

**Evidence:** AD-21 says “No other store exists,” enumerates Store, Folder and Files as the only adapters permitted to touch persistence APIs, and says there is “no adapter-private store.” AD-22 requires OS-keystore persistence behind a `CredentialVault`; the architecture diagram adds it, but the store-seal convention still allowlists only Store, Folder and Files.

**Divergence:** One unit can correctly make the build fail because the keystore plugin touches persistence outside the three allowlisted adapters. Another can exempt it ad hoc, weakening the exhaustive seal. A third can incorrectly put credential state into Store to satisfy AD-21.

**Disposition:** **Autofix.** Define the exhaustive boundary as two replayable stores plus explicitly non-replayable capability stores. Add `CredentialVault` to the store-seal allowlist, state that it may persist only opaque key material/capability state in Android Keystore, and preserve AD-22's bans on log/pool/export/adapter sidecars. Update AD-21, the testing convention, the source-tree seed, and the port-list comment together.

## High findings

### H1 — `CredentialVault.save` does not pin who may handle the secret

**Evidence:** AD-22 says the port exposes `save`, while also saying secret bytes never reach the core. The port is drawn as core-owned and UI normally enters through core commands. No rule states whether the shell calls the vault directly, whether a core command accepts the secret, or whether `save` receives an OS-owned opaque handle rather than bytes.

**Divergence:** A settings story may pass the plaintext key through a core command and DTO because the core owns the port; another may bypass core and invoke the adapter from UI; both can claim compliance. This affects memory lifetime, tests, dependency direction, and what “never secret bytes to the core” means.

**Disposition:** **Discuss, then encode.** Recommended: make credential entry a shell capability flow that sends the key directly from the settings controller to the vault adapter, never through a core command or persisted state; the core receives only `credentialAvailable(provider)`. If all UI actions must pass through commands, define a shell command boundary distinct from the pure-Dart core. Also require best-effort buffer lifetime minimisation without claiming Dart can guarantee zeroisation.

### H2 — The commit manifest's “complete authoritative inventory” is self-ambiguous

**Evidence:** `AUTHORITATIVE/` contains each generation's commit manifest, while that manifest contains the “complete authoritative inventory.” If the inventory includes the manifest itself, its own checksum/size is circular; if it excludes itself, “complete” is literally false and different implementations may choose differently.

**Divergence:** Export and import implementations can disagree about whether the manifest inventories itself and whether unrelated generations' manifests are members of the generation.

**Disposition:** **Autofix.** State that a generation manifest inventories exactly that generation's pool snapshot, log snapshot, and referenced blob set; it does not inventory itself or any other generation's manifest. Its own parseability/presence is the commit marker.

## Medium findings

### M1 — Port and source-tree inventories disagree

The Mermaid dependency diagram includes `CredentialVault`, but the `packages/core/lib/ports/` comment lists only Store, Slicer, Clock, Notifier, Recognizer, Folder and Files. This is a seed inconsistency likely to produce an omitted port or an adapter placed outside the seal. **Autofix:** add `CredentialVault` to that explicit list and identify its adapter directory.

### M2 — The AD-22 fixture check is phrased as if export fixtures can detect keystore contents

The rule says CI rejects “keystore-held values, provider-key shapes and persisted `keyExists: true` in export fixtures.” An export fixture cannot establish whether a matching value is held in Keystore; it can only reject secret-shaped fields/values and availability claims in exported data. **Autofix:** rephrase as a schema/fixture negative assertion: no credential fields, known key patterns, or persisted availability claims occur in either export half; vault integration tests separately prove secrets remain keystore-only.

### M3 — Cleanup recovery is one-sided

AD-13 says the next successful export may collect unreachable debris, but does not say whether every successful export must attempt cleanup or how cleanup failures are observed. This does not threaten correctness, only bounded storage. **Defer or encode:** require best-effort cleanup after verified commit and record cleanup failure as the export failure cause or a separately defined non-user-facing outcome; otherwise name unbounded debris as an accepted deferred risk.

## Checklist result

| Check | Result | Note |
| --- | --- | --- |
| Real divergence points fixed | Fail | Retained-blob lifecycle and vault persistence boundary remain contradictory. |
| Each Rule enforceable and prevents its stated divergence | Fail | AD-21's seal would reject AD-22; AD-13 has mutually exclusive deletion rules. |
| Deferred contains no hidden divergence | Pass | Current findings are in adopted rules, not Deferred. |
| Named technology verified-current | Pass with reliance | Stack records an independent live verification on 2026-08-27; this review found no new version binding in entries 85–86. |
| Brownfield conventions ratified | N/A | Greenfield, no code yet. |
| Input capabilities covered | Pass | FR-28/FR-30 and their relevant cross-cutting constraints are bound. |
| Parent invariants preserved | N/A | No parent spine identified. |
| Every initiative-level dimension addressed | Pass | Product/data/security, shell/core boundaries, persistence, export/restore, testing, Android envelope, operations/update ritual, and deferred evolution are all represented. |
| Memlog preservation | Pass | Entries 85–86 survive substantively and without weakening in their own clauses. |

## Recommended gate action

Apply C1, C2, H2, M1 and M2 as reconciliation fixes. Resolve H1 explicitly with the user because it chooses the credential-entry boundary. M3 can be placed in Deferred with a storage threshold/revisit condition if bounded cleanup is intentionally outside this validation build. Re-run lint plus the semantic gate after those changes.

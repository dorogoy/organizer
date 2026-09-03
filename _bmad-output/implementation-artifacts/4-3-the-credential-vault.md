---
title: 'The credential vault'
type: 'feature'
created: '2026-09-03'
status: 'done'
review_loop_iteration: 0
baseline_commit: '0286640d42b00b0f1c0ca8cb5ab48b44566b215f'
context:
  - '{project-root}/_bmad-output/implementation-artifacts/epic-4-context.md'
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** AD-22's credential vault exists only as prose — no Keystore wrapping key, no envelope storage, no `withCredential` request scope — and story 4-4's BYOK path needs this vault to exist first.

**Approach:** Declare the core `Files` port (the vault is its first consumer, per the spine) with a shell adapter over app-private storage; add the hand-written Kotlin `credentials` channel exposing only Keystore seal/unseal under the one named non-exportable AEAD wrapping key; compose both into the shell-side `CredentialVault` (atomic save, idempotent delete, `credentialAvailable`, `withCredential`); extend `setting_changed` to carry `selectedProvider` as text (additive schema v8); seal it all — store-seal growth (dart:io rule + Kotlin Keystore sweep), a generalized wire-contract check, and the AD-22 export-fixture redaction check.

## Boundaries & Constraints

**Always:**
- Envelope: opaque bytes from `seal(plaintext)` — AES-256-GCM under AndroidKeyStore alias `organizer_credential_wrapping` (generated on first use, non-exportable by construction, no biometric binding), IV inside the envelope; stored per provider at Files scope `credentials/<provider>`. Provider ids match `^[a-z0-9_]{1,64}$` or the vault refuses (quiet outcome, never a throw). The provider id never crosses the channel — the Kotlin half is a pure crypto service over the one wrapping key; scoping is Dart/Files-side.
- Plaintext enters only `CredentialVault.saveCredential(provider, plaintext)`, crosses to `seal`, and in `withCredential` reaches only the operation closure; no field, cache, log line, pool fact, export, crash entry or URL ever holds it; the vault exposes no accessor returning it.
- Save = atomic replacement (temp + rename) serialized under the vault's write queue (settings `_enqueueWrite` pattern); delete is idempotent — same outcome whether or not the envelope existed.
- `credentialAvailable(provider)` performs a full read + unseal **now** → `available | missing | corrupt | invalidated`; display state only — `withCredential` never consults it (no TOCTOU): it does its own read + unseal.
- `withCredential<T>(provider, operation)` → `AccessGranted<T>(operation's result)` | `AccessUnavailable(cause)`, cause ∈ missing/corrupt/invalidated; when unavailable the operation is **not invoked** (nothing is sent); on granted, plaintext is a local of the request scope only; operation errors propagate unchanged.
- Wire protocol: channel `dev.dorogoy.organizer/credentials`, methods `seal`/`unseal`, structured outcome maps, no `PlatformException` — native failures fold to wire words (`AEADBadTagException`/malformed → corrupt; key-invalidating exceptions → invalidated); main-looper confined; constants in Kotlin companion + Dart consts + the wire-contract check (dictate's three-copy pattern).
- `setting_changed` v8: additive nullable `text_value` column; `SettingEntry` carries `value int?` + `textValue String?`, exactly one non-null (read-boundary flaw otherwise; foreign kinds carrying text → flaw); sanctioned keys grow to `selected_provider` (charset-validated text; refusal is silence); `deriveSelectedProvider` + `deriveProviderConfigured(selectedProvider, credentialAvailable)` land beside `deriveTimeBagMinutes`.
- Store seal grows (the anticipated AD-21 evolution): persistence allowlist + `lib/files/` + `test/files/` (pin test grows with it); new rule closing the stated dart:io gap — no `dart:io` in `lib/` outside store/files scopes; new Kotlin sweep — Keystore/crypto APIs (`java.security.KeyStore`, `android.security.keystore.*`, `javax.crypto.*`) legal in exactly `CredentialKeystore.kt`, file APIs (`java.io.File*`) legal in **no** Kotlin file (Files is Dart-side only).
- Export redaction check (AD-22): `tool/check_export_redaction.dart` over `test/fixtures/export_redaction/` — rejects credential-family properties with non-empty values, provider→key pair shapes, and `keyExists`/availability-`true` claims; clean fixture passes; registered under `make check`.

**Ask First:**
- On-device evidence for this story: default is emulator **boot smoke only** (channel registration + vault wiring must not crash; the real seal/unseal round-trip is exercised by 4-4's key-entry UI). Confirm or require more.
- Renaming `tool/check_dictate_wire_contract.dart` → `tool/check_wire_contracts.dart` (Makefile + tests move in the same pass). Default: rename.
- Any change to the resolved Gradle graph (path_provider is already resolved transitively; promoting it to direct should change nothing — if it does, flag before re-freezing).

**Never:**
- No `SlicerPort`, allowlist, provider/key UI, free-tier sentence, or BYOK transport (4-4); no degradation strings (4-5); no export implementation (Epic 9 — fixtures + check only).
- No manifest or permission changes, no INTERNET, no new plugins beyond path_provider.
- No `flutter_secure_storage` (store-seal denied), no biometric/user-auth key binding, no Dart-side crypto, no plaintext in any String field that outlives a call.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Save new / replace | provider + plaintext | envelope written atomically; second save replaces first | quiet outcome, never throws |
| Delete absent / present | provider | same idempotent outcome; file removed when present | absent file is not an error |
| credentialAvailable | healthy envelope | `available` after full decrypt now | missing/corrupt/invalidated as measured |
| withCredential granted | healthy envelope | plaintext only inside operation; its result returns | operation errors propagate unchanged |
| withCredential unavailable | missing/corrupt/invalidated | `AccessUnavailable(cause)`; operation **not invoked** — nothing sent | N/A |
| Invalidation at request time | available said ok, unseal says invalidated | `AccessUnavailable(invalidated)`; operation not invoked | no retry |
| Provider id rejected | `../evil`, `UPPER`, `''`, 65 chars | all four vault operations refuse | quiet outcome |
| Off-protocol wire answer | unknown outcome word at the Dart adapter | `FormatException` | never treated as success |
| setting_changed neither value | v8 row with value and text_value both NULL | read-boundary flaw, entry inert | malformed row never derives |
| Foreign kind carrying text | non-setting row with text_value | flaw, inert | N/A |

</frozen-after-approval>

## Code Map

- `packages/core/lib/ports/files_port.dart` -- NEW pure port: app-private byte storage (read nullable, write-atomic, delete-idempotent); bytes only, no plaintext semantics; spine declares Files among the core ports.
- `lib/files/app_files.dart` -- NEW shell adapter: path_provider (promoted to direct dep; already transitively resolved via drift_flutter) + dart:io temp+rename; scope-partitioned paths (`credentials/<provider>`).
- `android/app/src/main/kotlin/dev/dorogoy/organizer/CredentialKeystore.kt` + `CredentialsChannel.kt` -- NEW Keystore service + channel; mirror `DictateChannel.kt:42-105` (companion consts `:224-241`, `when` dispatch, `result.notImplemented()`, no PlatformException); register in `MainActivity.kt:9-16`, destroy in `:31-35`.
- `lib/platform/credentials/credentials_cipher.dart` -- NEW Dart adapter, documented top-level wire consts (pattern: `lib/platform/dictate/dictate_recognizer.dart:10-45`); the injected seam the vault consumes.
- `lib/vault/credential_vault.dart` -- NEW shell vault (name already banned in core by `tool/check_core_purity.dart:308`); write-queue pattern from `lib/settings/settings_controller.dart:150-156`.
- `packages/core/lib/log/log_entry.dart:262-280,542-883` -- `SettingEntry` + read boundary: add `textValue`, exactly-one-of validation, new flaws.
- `packages/core/lib/commands/settings_commands.dart:29-53` + `packages/core/lib/settings/settings.dart:30-94` -- sanctioned-key growth + the two derivations; `packages/core/test/no_lateness_proof_test.dart:1299-1382` -- single-minter pin, update if it enumerates.
- `lib/store/substrate.dart:24-85,106-123` (+ `.drift`) + `lib/store/drift_store.dart:43-64` + `packages/core/lib/ports/store_port.dart:55-70` -- additive v8 `text_value` + record/mapping; regen via `make codegen`.
- `tool/check_store_seal.dart:31-39,42-70` + `test/tool/check_store_seal_test.dart:62-65` -- allowlist growth, dart:io rule, Kotlin sweep (sweep shape: `tool/check_egress_imports.dart:89-123`); `.kt` fixtures under `test/fixtures/store_seal/`.
- `tool/check_dictate_wire_contract.dart:14-52` -- generalize the consts + map into a contracts list; rename per Ask-First.
- `tool/check_export_redaction.dart` -- NEW + fixtures + `test/tool/` tests (check shape: `tool/check_catalogue_floor.dart`).
- `Makefile:17,44-59` -- register both check targets (rule `:3-7`); `lib/main.dart:23-64` -- construct AppFiles + cipher + one `CredentialVault`; `pubspec.yaml` + spine Stack row (~`ARCHITECTURE-SPINE.md:256`).

## Tasks & Acceptance

**Execution:**
- [x] `packages/core/lib/ports/files_port.dart` + `lib/files/app_files.dart` + `pubspec.yaml` (+ spine Stack row) -- the Files port and adapter; atomic write, idempotent delete, scope-partitioned, traversal-refusing.
- [x] `CredentialKeystore.kt` + `CredentialsChannel.kt` + `MainActivity.kt` -- named non-exportable AES-256-GCM wrapping key (generate on first use), seal/unseal over the channel, wire words sealed/ready/corrupt/invalidated.
- [x] `lib/platform/credentials/credentials_cipher.dart` + `lib/vault/credential_vault.dart` + `lib/main.dart` -- adapter consts + vault (validated provider ids, write-queued atomic save, idempotent delete, `credentialAvailable`, `withCredential`), wired once in main.
- [x] Core log v8: `substrate.drift` + `substrate.dart` + `store_port.dart` + `drift_store.dart` + `log_entry.dart` + `settings_commands.dart` + `settings.dart` (+ `no_lateness_proof_test.dart` pin, `make codegen` regen) -- `text_value` end to end + `selected_provider` + the two derivations.
- [x] `tool/check_store_seal.dart` (+ pin test, + fixtures) -- allowlist + `lib/files/`,`test/files/`; dart:io closed outside store/files; Keystore sweep allowlisting exactly `CredentialKeystore.kt`; Kotlin file APIs denied everywhere.
- [x] `tool/check_wire_contracts.dart` (rename, Makefile + tests moved) -- contracts list: dictate (RECORD_AUDIO asserted) + credentials (no permission asserted).
- [x] `tool/check_export_redaction.dart` + `test/fixtures/export_redaction/` + `test/tool/check_export_redaction_test.dart` + Makefile -- rejects plaintext shapes, provider-key shapes, `keyExists: true`.
- [x] `test/vault/credential_vault_test.dart` + `test/platform/credentials_cipher_test.dart` + `test/files/app_files_test.dart` (+ core derivation/validation tests in the touched suites) -- every matrix row: request-time invalidation, unavailable-without-invoking, replace atomicity, idempotence, wire pins to raw literals, `FormatException` on off-protocol answers.

**Acceptance Criteria:**
- Given the Kotlin sources, when the store seal runs, then Keystore/crypto appears in exactly `CredentialKeystore.kt` and no Kotlin file touches file APIs — the one closed native exception is structural.
- Given a saved envelope, when `credentialAvailable` runs, then it reports the measured state after a full decrypt and nothing in the request path consults it.
- Given `withCredential` over unavailable material, when it runs, then the operation is never invoked (nothing is sent) and the cause is one of missing/corrupt/invalidated.
- Given `setting_changed`, when a payload is inspected, then it may carry `selectedProvider` as text and never `keyExists` or any availability claim; a row with neither int nor text is inert.
- Given a restore where the choice survived but no credential was saved, when `providerConfigured` derives, then it is false until a credential is saved again.
- Given the export fixtures, when the redaction check runs, then plaintext, provider-key shapes and `keyExists: true` all fail and the clean shape passes.
- Given the story's failure modes, when tests run, then save, replace, delete, absent, corrupt, Android-invalidated and request-time invalidation are all covered.

## Design Notes

- Corrupt-after-invalidation is honest, not a bug: re-sealing after Keystore invalidation mints a fresh key and old envelopes read as corrupt; nothing is auto-deleted.
- Plaintext lifetime is call-scoped locals on both sides of the channel — there is nothing to clear, and the vault's API surface (no plaintext-returning accessor) keeps it that way.

## Verification

**Commands:**
- `devbox run -- make gate` -- expected: green (all suites + format + analyze).
- `devbox run -- make check` -- expected: green incl. grown store seal, wire contracts, export redaction, unchanged Gradle graph.
- `devbox run -- make codegen` then `make codegen-check` -- expected: drift regen fresh.

**Manual checks (if no CLI):**
- Emulator boot smoke per Ask-First default: install + launch on `organizer36`, app reaches the first screen — channel registration and vault construction crash nothing.

## Suggested Review Order

**The vault — AD-22's request scope**

- Entry point: drain the write chain, read, unseal, invoke only on grant — the whole discipline in one method.
  [`credential_vault.dart:192`](../../lib/vault/credential_vault.dart#L192)

- Display state measured live by full decrypt; requests never consult it (no TOCTOU).
  [`credential_vault.dart:153`](../../lib/vault/credential_vault.dart#L153)

- Quiet atomic saves on the serialized write queue; seals run concurrently (pure crypto).
  [`credential_vault.dart:114`](../../lib/vault/credential_vault.dart#L114)

**The crypto boundary (Kotlin)**

- One named non-exportable AES-256-GCM key; IV‖ciphertext envelopes; generate on first use.
  [`CredentialKeystore.kt:64`](../../android/app/src/main/kotlin/dev/dorogoy/organizer/CredentialKeystore.kt#L64)

- Every native failure folds here — corrupt vs invalidated, never an exception across the wire.
  [`CredentialKeystore.kt:100`](../../android/app/src/main/kotlin/dev/dorogoy/organizer/CredentialKeystore.kt#L100)

- The second of the three channels: seal/unseal only, no provider id ever crosses.
  [`CredentialsChannel.kt:43`](../../android/app/src/main/kotlin/dev/dorogoy/organizer/CredentialsChannel.kt#L43)

**The Files port and adapter**

- The spine's seventh port: bytes only — read nullable, write atomic, delete idempotent.
  [`files_port.dart:27`](../../packages/core/lib/ports/files_port.dart#L27)

- Temp+rename with counter-serial staging, quiet absence on every path, memoized root.
  [`app_files.dart:131`](../../lib/files/app_files.dart#L131)

**Schema v8 — selectedProvider rides setting_changed**

- Exactly-one-of int/text at the read boundary; empty text is absence, conflict is a flaw.
  [`log_entry.dart:685`](../../packages/core/lib/log/log_entry.dart#L685)

- The two derivations: the choice survives restore; configuration asks the vault.
  [`settings.dart:129`](../../packages/core/lib/settings/settings.dart#L129)

- The shared provider-id charset — the rule both vault and minter enforce.
  [`settings.dart:64`](../../packages/core/lib/settings/settings.dart#L64)

**The three seals**

- dart:io closed outside store/files scopes — the side-file gap AD-21 named is shut.
  [`check_store_seal.dart:68`](../../tool/check_store_seal.dart#L68)

- Side-channel denials: no getFilesDir/SharedPreferences/java.nio file APIs in any Kotlin.
  [`check_store_seal.dart:274`](../../tool/check_store_seal.dart#L274)

- Both channels' wire vocabularies pinned three ways (Kotlin, Dart, check).
  [`check_wire_contracts.dart:78`](../../tool/check_wire_contracts.dart#L78)

- Export redaction: plaintext, provider-key pairs, availability claims — with real line numbers.
  [`check_export_redaction.dart:39`](../../tool/check_export_redaction.dart#L39)

**Peripherals**

- The three pieces constructed once; 4-4 consumes the vault from here.
  [`main.dart:41`](../../lib/main.dart#L41)

- Keystore constants pinned by source text — a drift would brick every stored envelope.
  [`credential_keystore_constants_test.dart:1`](../../test/tool/credential_keystore_constants_test.dart#L1)

- Matrix coverage: request-time invalidation, queue draining, failed writes, quiet outcomes.
  [`credential_vault_test.dart:1`](../../test/vault/credential_vault_test.dart#L1)

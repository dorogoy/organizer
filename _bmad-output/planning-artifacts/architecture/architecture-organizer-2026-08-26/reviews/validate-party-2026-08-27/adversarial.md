# Adversarial architecture review — Amelia + Splinter

**Artifact:** `ARCHITECTURE-SPINE.md`  
**Intent:** validate only; no changes applied  
**Lens:** construct independently built, one-level-down units that obey the written ADs yet fail to interoperate  
**Verdict:** **FAIL — 2 critical, 5 high, 2 medium findings.** The spine is unusually strong about product invariants, but it still permits incompatible implementations at the persistence/export boundary, recovery semantics, native callback seams, and enforcement layer.

## Critical findings

### ADV-1 — The prescribed export commit protocol cannot provide the atomicity it claims

**Severity:** Critical  
**Domains:** export/import, ownership, temporal behavior

**Written contract:** AD-13 requires temporary files to be renamed in the order `images → pool → log`, calls the log rename the commit point, and states that a crash leaves the previous export intact and never a mixed vintage.

**Compliant unit pair:**

- **Export adapter A** writes `pool.jsonl.tmp`, renames it over `pool.jsonl`, then crashes before renaming `log.jsonl.tmp`. It followed the mandated order literally.
- **Import adapter B** sees no temporary name after the OS or cleanup removes the temp log, then reads the new pool with the old log. It also follows AD-13 literally: the import rejection rule is based on a remaining fixed temp suffix or structural corruption. Both JSONL files parse and all known fields exist.

The resulting destination is a mixed generation even though neither unit violated a stated rule. Per-file rename is atomic; a sequence of independent renames is not. Images are worse: deleting or replacing an authoritative image before the log commit can make the old committed log refer to new or absent bytes.

**Why it matters:** FR-30 says partial restore is forbidden, and AD-18 makes this the recovery path for validation evidence. The claimed invariant is false under an ordinary process death or revoked SAF grant.

**Contract needed:** generation directories or generation-stamped immutable filenames plus one atomic manifest/pointer commit; import must select only the last complete generation and validate a generation id/checksums across every authoritative component. Cleanup occurs after commit, never before it.

### ADV-2 — The key-exists setting becomes a lie after restore

**Severity:** Critical  
**Domains:** shared data, ownership, export/import, AI egress

**Written contract:** AD-1 says settings are pure derivations of pool/log. AD-22 says `setting_changed` may carry provider identity and “the fact that a key exists,” while key material is keystore-only and never exported. AD-13 restores the exported log. The SAF capability gets an explicit redaction-and-identity exception; the provider-key fact does not.

**Compliant unit pair:**

- **Settings unit A** replays the restored `setting_changed(provider: openai, keyExists: true)` and reports the Slicer configured, exactly as AD-1 requires.
- **Egress unit B** consults the OS keystore at call time, finds no key on the restored/new install, and returns “no key configured,” exactly as AD-22 requires.

Both are literal implementations, but the read model and command path disagree. A third implementation that derives `keyExists` from the keystore fixes the behavior while violating AD-1’s “all settings from `(pool, log, day, session)`” rule.

**Why it matters:** restore is a first-class update/recovery path. The app can show a provider as ready and fail on first use, or can choose incompatible provider-gate behavior across stories.

**Contract needed:** treat key presence as a non-exportable capability projection just like SAF: export the provider choice but redact/reset key presence, exclude it explicitly from round-trip identity, and define the single authority for `providerConfigured` as provider selection ∧ live keystore capability.

## High findings

### ADV-3 — Pool/log payloads and correlation keys are not a canonical shared-data contract

**Severity:** High  
**Domains:** shared-data shapes, ownership, mutation paths, temporal behavior

The spine exhaustively names event kinds but does not fix the minimum envelope or payload per kind. “Every log entry referencing an item carries origin” is not enough to make independently built command, derivation, export, and migration units interoperable.

**Compliant unit pair:**

- **Session story A** emits `session_started {id, pocketSeconds}` and `session_ended {sessionId, cause}`; it matches explicitly by id.
- **Session derivation B** uses a stack-like latest-open interpretation and emits `session_ended {cause}` with no session id, because AD-19 only says “matching” and guarantees a latest start. Both obey the named vocabulary, append-only mutation, and derived-session rule.

The same divergence exists for `card_done`: one unit references the `card_dealt` id (preserving which deal/session/day it answers), another references only `itemId` and current session. After process death, duplicate callbacks, or imported equal-time records they retire different items/slots. Rescue-chain lineage, Epic activation, `setting_changed`, scan identity, export outcomes, and album-byte names have the same unspecified correlation problem.

**Contract needed:** a canonical versioned envelope and per-kind payload schema, including event id, recorded instant, offset, causation/correlation ids, subject refs, origin rules, and uniqueness/idempotency rules. This can be a compact schema companion rather than prose in every AD, but it must be normative.

### ADV-4 — Equal-time event ordering is undefined, so replay is not deterministic

**Severity:** High  
**Domains:** temporal behavior, shared data, derived state

AD-3 mandates deterministic ties for candidate selection and the conventions forbid using UUID bit patterns for ordering, but no total order exists for folding log entries that share a recorded instant. Millisecond-resolution clocks and rapid native callbacks make ties routine.

**Compliant unit pair:**

- **Store A** returns equal-time rows in SQLite insertion/rowid order.
- **Import/export B** preserves JSONL order, or sorts by timestamp only using a non-stable sort. Both use recorded act instants and never UUID mint order.

For same-instant `energy_set` + `session_started`, one replay sees the new energy at session start and another sees the default/old value, changing `EligibleDay`. For `session_ended` + `session_started`, they disagree about the open session. For `setting_changed` pairs, they disagree about the effective setting.

**Contract needed:** a persisted monotonic sequence or an explicit deterministic `(instant, sequence)` order minted at commit; export/import preserves it verbatim. Specify idempotency for repeated command/native callbacks.

### ADV-5 — Notification delivery and `invitation_emitted` cannot be made exactly-once with the stated seam

**Severity:** High  
**Domains:** Android/native seams, temporal behavior, mutation paths

AD-4 forbids native date arithmetic; AD-17 schedules one inexact alarm; AD-21 derives behavior/evidence from `invitation_emitted`. It never binds the atomic relationship between the Kotlin notification side effect and the Dart log append.

**Compliant unit pair:**

- **Native unit A** posts the notification, then tries to wake Flutter to append `invitation_emitted`. Process death between the two leaves a visible invitation with no evidence; boot reschedule can emit it again.
- **Shell unit B** appends first, then invokes native posting. Process death between them suppresses the later invitation because the log says it was emitted, although none was shown.

Neither ordering gives exactly-once delivery/evidence, and both obey the channel and store rules. A killed app also cannot assume the Dart core is available for the boot receiver’s decision while Kotlin is forbidden to compute periods.

**Contract needed:** explicitly choose at-most-once or at-least-once semantics and define a durable handoff/ack protocol owned by one adapter. If “at most one visible notification per domestic day” is load-bearing, persist a native-safe occurrence identity derived by the core when scheduling and use a stable notification id; specify how the receiver records or reconciles actual delivery without a forbidden adapter-private store.

### ADV-6 — The Slicer response and error algebra is missing, so providers produce different products

**Severity:** High  
**Domains:** AI egress, errors, adapter/core ownership

AD-7 fixes three outbound payload shapes; AD-5 requires inert adapter DTOs; AD-9 fixes three Slicer implementations; FR-29 requires seven distinguishable no-Slicer causes. No normative response DTO or error taxonomy maps HTTP, SDK, provider, parsing, cancellation, and quota signals into those seven states.

**Compliant unit pair:**

- **OpenAI adapter A** maps HTTP 429 to exhausted quota and malformed structured output to provider unreachable.
- **Gemini adapter B** maps 429 to provider unreachable (rate-limited, not necessarily exhausted) and malformed output to provider failure/cap. Both return inert DTOs and let the core choose a calm state, but they feed different facts into that choice.

Cancellation on background is also indistinguishable from a network/provider failure unless the port says otherwise, which changes whether `scan_abandoned` or `slice_failed` is appended and corrupts FR-26 series (b).

**Contract needed:** a closed `SlicerResult`/`SlicerFailure` algebra with provider-neutral semantics, precedence when several causes apply, cancellation as a separate non-failure outcome, structured-response validation, and fixture conformance tests for every provider implementation.

### ADV-7 — Dictation’s native lifecycle and commit semantics are unspecified

**Severity:** High  
**Domains:** Android/native seams, privacy, temporal behavior

AD-11 selects the correct on-device Android APIs and model gate, but not the cross-channel protocol. FR-32 says the transcript is the only artifact and audio is never stored/exported/transmitted/instrumented.

**Compliant unit pair:**

- **Capture UI A** streams partial recognition callbacks directly into the capture line; backgrounding leaves the last partial text, which can later be committed.
- **Native adapter B** keeps partials transient and returns only `onResults`; background/cancel restores the prior line. Both use on-device recognition, store no audio, and keep the keyboard.

They disagree on user data after cancellation, duplicate/final callback ordering, permission refusal, recognizer errors, and whether a transcript’s dictation boolean is true after keyboard correction. Those differences directly alter pool facts and FR-32 validation evidence.

**Contract needed:** a channel state machine with request id, partial/final/cancel/error messages; exactly one terminal outcome; background cancellation behavior; transcript commit point; definition of the per-capture dictation boolean; and tests with duplicate/out-of-order callbacks.

## Medium findings

### ADV-8 — Database trigger guarantees are not preserved by import/migration ownership

**Severity:** Medium  
**Domains:** mutation paths, export/import, ownership

AD-2 says triggers exist from the initial migration, but import ownership and transaction behavior are not explicit. One import adapter can insert through Drift into live tables; another can replace the SQLite file or bulk-load into staging and swap it. Both can plausibly claim that the final two tables carry triggers, yet the latter bypasses the insert-only enforcement and may omit/recreate triggers differently during migration.

**Contract needed:** import must go through one Store-owned transaction/API, may only insert, validates duplicate ids, and proves the four triggers exist before and after import/migration. Define duplicate-record behavior (idempotent no-op vs structural refusal).

### ADV-9 — “CI check,” “lint,” and “review-enforced” do not form an executable quality gate

**Severity:** Medium  
**Domains:** test enforcement

The conventions name useful guards, but do not define the command or CI dependency graph that runs all of them. Several load-bearing guarantees are described as “core-test- and review-enforced” even though they span Kotlin, Gradle, merged manifests, UI reachability, SAF crash behavior, and release signing. `flutter test`, `dart format --set-exit-if-changed .`, and `flutter analyze` do not automatically execute arbitrary `tool/` scripts, inspect an assembled manifest, or exercise process-death/native callback behavior.

**Compliant unit pair:**

- **Feature story A** adds the required `tool/check_store_seal.dart`; its local story gate runs only the three repository policy commands.
- **CI story B** runs some checks in a separate job that is not a dependency of the build/release job. Every check exists as promised, but a validation APK can still be produced green while a seal is red or unrun.

**Contract needed:** one canonical verification entry point/CI required job that runs the three repository gates plus every tool check, schema/trigger assertions, native unit/instrumentation checks, and assembled-manifest/Gradle checks; artifact production must depend on it. Keep handset-only ritual items explicitly separate rather than calling them CI-enforced.

## Attack coverage

| Requested seam | Findings |
| --- | --- |
| Shared-data shapes | ADV-2, ADV-3, ADV-4 |
| Ownership | ADV-1, ADV-2, ADV-3, ADV-8 |
| Mutation paths | ADV-3, ADV-5, ADV-8 |
| Temporal behavior | ADV-1, ADV-4, ADV-5, ADV-7 |
| Android/native seams | ADV-5, ADV-7 |
| Export/import | ADV-1, ADV-2, ADV-8 |
| Errors | ADV-6, ADV-7 |
| AI egress | ADV-2, ADV-6 |
| Test enforcement | ADV-9 |

## Disposition

The critical and high findings are architecture-spine work, not story-local choices: two units one level down can and will choose incompatibly. ADV-1 and ADV-2 block treating restore as safe. ADV-3 through ADV-7 should be resolved before splitting storage, session, notification, Slicer, or dictation into independent implementation units. ADV-8 and ADV-9 can be made explicit in the Store contract and project verification entry point.

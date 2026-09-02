---
title: 'Dictation into the capture line'
type: 'feature'
created: '2026-09-01'
status: 'done'
review_loop_iteration: 0
baseline_commit: '8fac403923886f579a5fe92f67dccb6293cbcc90'
context:
  - '{project-root}/_bmad-output/implementation-artifacts/epic-3-context.md'
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** The capture surface (3-2) types only — nothing listens. FR-32's floor (say the thing instead of typing it) has no code: no `Recognizer` port, no `dictate` channel (the repo's first platform channel — `MainActivity.kt` is bare), no `permission_refused` kind, no per-capture dictation boolean, no reactivation row.

**Approach:** Put the mic capsule at the capture line's end behind a hand-written Kotlin `dictate` channel using `createOnDeviceSpeechRecognizer()` gated by the 3-1 availability rule; land the final transcript into the existing field; append `permission_refused` on refusal (dialog or system revocation) with a Settings-only `IA y voz` reactivation row; store a per-capture `dictated` boolean outside origin arithmetic, readable on the validator surface only.

## Boundaries & Constraints

**Always:**
- On-device only, forced by the pair `createOnDeviceSpeechRecognizer()` + `isOnDeviceRecognitionAvailable()`, gated further by `checkRecognitionSupport()` with an `es-*` tag in `installedOnDeviceLanguages` (the 3-1 rule). No cloud fallback on any path; the egress map gains nothing.
- Dictation starts only on explicit capsule press; nothing listens outside it. The final transcript **replaces** the line's content and lands in the existing field — never a confirmation screen. The keyboard is never removed (no focus manipulation).
- Only final results commit: partial results never touch the line, so interruption (backgrounding, call, focus loss, recognizer error) yields nothing — capsule resets to rest, no error surfaces.
- One utterance = one task; nothing is parsed out of the transcript. No audio exists anywhere: nothing is written, exported, or recoverable — the transcript is the only artifact.
- `RECORD_AUDIO` is requested by the channel at the first press, never at app entry. Refusal or system-level revocation after grant appends exactly one `permission_refused` entry through the core minter; the affordance disappears; the app never re-asks on its own. Reversal only via the Settings row, which renders only while refused ∧ not granted and opens the system app-details screen; a re-grant restores the affordance through the probe (`visibility = available ∧ (granted ∨ permissionMayBeAsked)`).
- Session state machine: one terminal outcome per press (transcript | nothing) with a commit point. Kotlin marshals every recognition callback to the main looper (the 3-1 latch-race guard, deferred-work.md:177-179); Dart drops events carrying a stale session id.
- `dictated` is a nullable pool-fact column (schema v7 additive ALTER, old rows null), written once at creation, `true` whenever dictation authored the line — keyboard correction afterwards never resets it. Origin stays `manual`; no card anywhere marks a capture as spoken.
- `permissionMayBeAsked` derives from entry types only (warm-return shape); the permission identity is a core enum (microphone/camera/notifications) stored as wire text — no free-form strings. Every append rides the shared `LogWriteQueue`; kinds flow through core constants.

**Ask First:**
- Any second recognition path, cloud fallback, or new pub dependency.
- Any user-visible string beyond the three new keys (mic semantics label, `IA y voz` row, dictated-count line) or any re-wording of the seven pinned capture strings.
- Any change to `Guardar`/`Descartar` semantics.

**Never:**
- No transcript splitting or parsing, no partial-transcript UI, no stop/cancel control, no wake word, no background audio, no motion (state is ink + prose only).
- No permission cache outside the log (no SharedPreferences / fourth store); no app-triggered re-ask; no greyed-out affordance — unavailable means absent.
- No camera or notify work (their stories twin this pattern later), no export changes, no schema rewrite (additive v7 only).

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Press, available + granted | Explicit capsule press | Listening: blue mass + `Escuchando…`; final transcript replaces the line; `Guardar` enables via the existing listener | Quiet reset on recognizer error |
| First press, never asked | Press | System dialog; grant → listening; refusal → `permission_refused` appended, affordance removed | Quiet |
| Revoked after grant | Press | Behaves exactly as first-use refusal | Quiet |
| Spanish on-device unavailable | Surface renders | Affordance simply absent — no error, grey state, or install offer | N/A |
| Interrupted mid-utterance | Backgrounding / call / focus loss / error | No partial transcript lands; capsule resets; no error | Quiet |
| Spoken duration | `llamar cinco minutos al dentista` | Words in the line like any others; size still the three taps | N/A |
| Blank final result | `onResults` empty/blank | Nothing written; `Guardar` stays disabled (the `_onSave` guard) | Quiet |
| Refusal append throws | Failing store | Existing quiet-absorption queue path | Quiet |
| Settings while refused | Settings opens | `IA y voz` row renders only while refused ∧ not granted; tap opens system app settings | Quiet |

</frozen-after-approval>

## Code Map

- `lib/ui/capture/capture_screen.dart` -- the surface: `_field` L227 (renders full-width today; doc L219-226 says the capsule is 3-4's), `_onSave` blank guard L105-107 ("3.4's dictation lands here"), `_canSave` L92, controller seam L50-53. Capsule = field-end 48dp target with glyph at 24px (`_LapizEntry` pattern, `lib/ui/dispenser/dispenser_screen.dart:1184-1207`); caption in support style only while listening.
- `lib/ui/glyphs/microphone_glyph.dart` -- `MicrophoneGlyph(size, dictating:)` L13 ALREADY EXISTS: neutral→blue mass, registered mass; tokens `iconMassNeutral`/`iconMassBlue` at `lib/ui/tokens.dart:58,66`. No glyph file added.
- `lib/l10n/app_es.arb` -- `captureFieldPlaceholder` L351 and `dictationListening` ("Escuchando…") L356 EXIST. Add three keys (mic semantics label, `IA y voz` row, dictated-count line); `make codegen` regenerates `lib/strings/` (codegen-check gates freshness).
- `packages/core/lib/ports/recognizer_port.dart` -- NEW port: probe (unavailable/askable/granted), start outcome (listening/refused/unavailable), per-session outcome events. ClockPort minimalism, pure Dart.
- `lib/platform/dictate/dictate_recognizer.dart` -- NEW adapter over the channel; register the file in `namedConstantAllowance` of `tool/check_no_literal_strings.dart` (channel/method-name literals, store-file precedent).
- `android/app/src/main/kotlin/dev/dorogoy/organizer/` -- `MainActivity.kt` L4 is bare; add `DictateChannel.kt` (+ recognizer wrapper) registered in `configureFlutterEngine`. Reuse 3-1's preserved Kotlin idiom (`3-1-…-handsets.md:210-344`: `runOnMainSync`, `RecognitionSupportCallback`, `destroy()`) with every callback marshalled to the main looper. `android/app/src/main/AndroidManifest.xml` gains `RECORD_AUDIO`.
- `packages/core/lib/log/log_entry.dart` -- `LogKind` L32 + `knownByName` L56: add `permissionRefused` (crash-shape: own payload, no item pair) — subtype + `LogRecordFlaw` pair + conversion branch L468-749.
- `packages/core/lib/pool/pool_fact.dart` -- `PoolFact` L51 gains `bool? dictated` (nullable `originContext` precedent L83).
- `packages/core/lib/ports/store_port.dart` -- `PoolFactRecord` L25, `LogEntryRecord` L49, `poolFactsOf` L72 grow fields (record freezes at `packages/core/test/no_lateness_proof_test.dart:871-916`).
- `packages/core/lib/commands/capture_commands.dart` -- `captureCreate` L55 + `CaptureFactContent` L45 gain `dictated` (single sanctioned minter; doc L40 already says dictated is `manual`).
- `packages/core/lib/commands/permission_commands.dart` -- NEW `permissionRefuse(permission)` minter (settings_commands refusal-is-silence shape).
- `packages/core/lib/derive/permission.dart` -- NEW `permissionMayBeAsked(entries, permission)`, the `warm_return.dart:92-124` shape; classify the new subtype in `_isUserAct` L59-79 (→ not an act, `CrashEntry` precedent).
- `lib/store/substrate.dart` + `substrate.drift` -- schema v7: log `permission` TEXT NULL + pool `dictated` BOOL NULL; named ALTER consts (v6 precedent L61-68), `schemaVersion` L80, `onUpgrade` L101-123; then `make codegen`.
- `lib/store/drift_store.dart` -- `appendPoolFact`/`appendLogEntry`/both reads map the new columns.
- Log-record literal sweep -- 16-field literals in `lib/dispenser/dispenser_controller.dart` (×6), `lib/session/session_controller.dart`, `lib/settings/settings_controller.dart:62-76`, `lib/capture/capture_controller.dart:67-81`, plus fixtures in both test roots.
- `lib/capture/dictation_controller.dart` -- NEW: press flow, session ids, lifecycle observation (interruption), refusal append through the queue, transcript callback; constructed at the `lib/main.dart:52` seam and threaded like `capture`.
- `lib/settings/settings_controller.dart` + `lib/ui/settings/settings_screen.dart` -- refusal read via the derivation; conditional `IA y voz` row (opens system app settings via a channel method); validator-only dictated-count row (AD-26).
- Pins: `test/no_lateness_proof_test.dart` `bannedWireNames` L200 += `permission_refused`; reader censuses in both roots; `test/store/substrate_test.dart` `takeOverWithV6` group + `schemaVersion == 7`; `test/ui/capture/capture_screen_test.dart` string census L348-356 (includes `Semantics` labels, L188-204) needs the new listening tests; `test/ui/glyphs/glyph_set_test.dart` needs nothing.

## Tasks & Acceptance

**Execution:**
- [x] `packages/core/lib/log/log_entry.dart` + `pool_fact.dart` + `store_port.dart` + `capture_commands.dart` + NEW `permission_commands.dart` + NEW `derive/permission.dart` -- kind, subtype, flaw pair, conversion; `dictated` field; record growth; minter widen + refusal minter; the derivation -- the law, pinned by tests.
- [x] `lib/store/substrate.dart` + `substrate.drift` + `drift_store.dart` -- v7 additive columns + adapter mapping + `make codegen`; `test/store/substrate_test.dart` takeover group extended to v7.
- [x] `packages/core/lib/ports/recognizer_port.dart` + NEW `lib/platform/dictate/` + Kotlin half + manifest -- port, channel adapter (with the no-literal-strings allowance), `DictateChannel.kt` with the race-guarded recognizer and permission flow, `RECORD_AUDIO`.
- [x] `lib/capture/dictation_controller.dart` + `lib/ui/capture/capture_screen.dart` + `lib/main.dart` -- press flow, capsule + caption wiring, transcript replace, interruption via lifecycle, thread the seam -- with widget/controller tests over a fake port.
- [x] `lib/settings/settings_controller.dart` + `lib/ui/settings/settings_screen.dart` + `lib/l10n/app_es.arb` -- refusal read, conditional `IA y voz` row, dictated-count row, three new keys + codegen -- with tests.
- [x] Both `no_lateness_proof_test.dart` roots + shell test fixtures -- record freezes, `bannedWireNames`, reader censuses, append-site fixtures.

**Acceptance Criteria:**
- Given recognition available and not refused, when the surface renders, then the capsule sits at the field's end (24px glyph inside a 48dp target) and a press starts listening — declared only by the blue mass and `Escuchando…`, never by motion.
- Given a completed utterance, when results arrive, then the final transcript replaces the line's content in the existing field, `Guardar` enables through the existing listener, and a spoken duration stays words.
- Given interruption mid-utterance, when the surface returns, then no partial transcript landed, the capsule reset to rest, and no error appeared.
- Given refusal (dialog or system revocation), when it happens, then exactly one `permission_refused` entry is appended, the affordance disappears, keyboard capture is unaffected, and only the Settings row — while it has something to reactivate — reverses it.
- Given on-device Spanish unavailable, when the surface renders, then the affordance is simply absent.
- Given a dictated capture saved, when stored, then its origin is `manual`, its `dictated` boolean is true (keyboard correction never resets it), and only Settings renders it — no card marks it spoken.
- Given any log, when derived, then `permissionMayBeAsked(microphone)` is false iff a microphone refusal entry exists — one definition, entry types only.

## Spec Change Log

## Design Notes

- Replace-not-append: one utterance = one task and the line holds one task, so a new transcript replaces the field's content. Correction: keyboard edits after dictation keep `dictated = true` — the boolean records who authored the line (provenance), not its final wording.
- Terminal-only commit: only `onResults` ever writes the line; partials are dropped everywhere, which is what makes "interruption yields nothing" true by construction rather than by cleanup.
- Affordance defaults to absent: the probe is async and absence is the unavailable state, so the capsule never flashes in on an unsupported device.
- After a refusal the log entry stands forever; `permissionMayBeAsked` stays false — visibility recovers through `granted` alone (the probe's `checkSelfPermission`), so the app never shows the system dialog twice but a system re-grant fully restores dictation.
- The emulator image may honestly lack the Spanish model: affordance absence there is the correct outcome, not a bug (3-1 verified the two real handsets AVAILABLE).

## Verification

**Commands:**
- `devbox run -- make codegen` -- expected: regenerated `lib/strings/` + `substrate.g.dart` committed.
- `devbox run -- make gate` -- expected: green (flutter test, format check, analyze).
- `devbox run -- make check` -- expected: green (purity, literals incl. the new allowance, text scaling, string audit, vocabulary, store seal, catalogue, codegen-check).

**Manual checks (if no CLI):**
- On a 3-1-probed handset: dictate a line, correct it by keyboard, save — the capture deals as an ordinary card with no spoken marker. Refuse the permission once: affordance gone, `IA y voz` row appears; re-grant via system settings: affordance returns.

## Suggested Review Order

**The law — a refusal becomes a log fact**

- The thirteenth kind, past-tense with the sanctioned `_refused` suffix
  [`log_entry.dart:80`](../../packages/core/lib/log/log_entry.dart#L80)

- The crash-shaped entry: own payload, no item pair — plus the `Permission` enum
  [`log_entry.dart:378`](../../packages/core/lib/log/log_entry.dart#L378)

- The one-way derivation: entry types only, false iff a named refusal stands
  [`permission.dart:37`](../../packages/core/lib/derive/permission.dart#L37)

**The port and the channel — the repo's first**

- The minimal contract: probe/start/outcomes, partials never cross
  [`recognizer_port.dart:68`](../../packages/core/lib/ports/recognizer_port.dart#L68)

- The Dart half over the wire: probe/start/cancel/openAppSettings mapping
  [`dictate_recognizer.dart:59`](../../lib/platform/dictate/dictate_recognizer.dart#L59)

- The permission ask lives here: first press only, never app entry
  [`DictateChannel.kt:96`](../../android/app/src/main/kotlin/dev/dorogoy/organizer/DictateChannel.kt#L96)

- The 3-1 rule as code: forced on-device, `es-*` installed, quiet otherwise
  [`DictateRecognizer.kt:63`](../../android/app/src/main/kotlin/dev/dorogoy/organizer/DictateRecognizer.kt#L63)

- Terminal-only emission: one outcome per session, stale ids drop platform-side
  [`DictateRecognizer.kt:205`](../../android/app/src/main/kotlin/dev/dorogoy/organizer/DictateRecognizer.kt#L205)

**The seam — the press flow's state machine**

- One press, one session: in-flight guard, foreground gate, durable refusal
  [`dictation_controller.dart:174`](../../lib/capture/dictation_controller.dart#L174)

- The commit point: stale ids drop, blank writes nothing, transcript replaces
  [`dictation_controller.dart:290`](../../lib/capture/dictation_controller.dart#L290)

- Every surface exit cancels a live session — nothing listens outside the press
  [`dictation_controller.dart:275`](../../lib/capture/dictation_controller.dart#L275)

**The surface — ink and prose, never motion**

- The capsule at the field's end: 24px glyph inside the 48dp target
  [`capture_screen.dart:507`](../../lib/ui/capture/capture_screen.dart#L507)

- `Escuchando…` as a live region — the prose half of the state declaration
  [`capture_screen.dart:390`](../../lib/ui/capture/capture_screen.dart#L390)

- The transcript landing: replace, single-line, ignore while saving, author flag
  [`capture_screen.dart:147`](../../lib/ui/capture/capture_screen.dart#L147)

**The validator surface — Settings only (AD-26)**

- The dictated count and the conditional `IA y voz` row, re-read on resume
  [`settings_screen.dart:216`](../../lib/ui/settings/settings_screen.dart#L216)

**The store — additive v7, both stores sealed**

- Schema 7: `permission` on the log, `dictated` on the pool — named ALTERs
  [`substrate.dart:98`](../../lib/store/substrate.dart#L98)

- The single sanctioned minter widens: origin stays `manual`, `dictated` rides along
  [`capture_commands.dart:56`](../../packages/core/lib/commands/capture_commands.dart#L56)

**Evidence**

- The wire protocol pinned in both directions over the mock messenger
  [`dictate_recognizer_test.dart:19`](../../test/platform/dictate_recognizer_test.dart#L19)

- The state machine: press flow, dialog races, refusal durability, exits
  [`dictation_controller_test.dart:85`](../../test/capture/dictation_controller_test.dart#L85)

- The composition root cannot silently drop the dictation seam
  [`app_test.dart:164`](../../test/ui/app_test.dart#L164)

- The surface census plus six dictation widget flows (replace, interrupt, blank)
  [`capture_screen_test.dart:743`](../../test/ui/capture/capture_screen_test.dart#L743)

### Review Findings

- [x] [Review][Patch] Add native/integration coverage for the dictation channel and an independent protocol cross-check (resolved decision: add now) — `DictateChannel.kt` and `DictateRecognizer.kt` have no Android-side automated tests, while the Dart wire tests reuse the production protocol constants; the permission, Spanish-support and callback-race paths must be verified independently of the production constants.
- [x] [Review][Patch] Cancel staged permission requests when dictation is cancelled [android/app/src/main/kotlin/dev/dorogoy/organizer/DictateChannel.kt:72-75]
- [x] [Review][Patch] Prevent stale native callbacks from cancelling a newer recognition session [android/app/src/main/kotlin/dev/dorogoy/organizer/DictateRecognizer.kt:205-214]
- [x] [Review][Patch] Detect permission revocation without re-asking and persist the refusal outcome [android/app/src/main/kotlin/dev/dorogoy/organizer/DictateChannel.kt:101-106]
- [x] [Review][Patch] Keep the Settings reactivation row tied to the actual microphone grant when recognition is unavailable [lib/settings/settings_controller.dart:80-85]
- [x] [Review][Patch] Guard dictation visibility refreshes against out-of-order probe and log results [lib/capture/dictation_controller.dart:140-155]
- [x] [Review][Patch] Make the v6-to-v7 schema migration failure-atomic [lib/store/substrate.dart:144-146]
- [x] [Review][Patch] Re-enforce the Spanish on-device support gate when starting recognition [android/app/src/main/kotlin/dev/dorogoy/organizer/DictateRecognizer.kt:131-145]
- [x] [Review][Defer] Capture fact and `capture_created` appends are not atomic, so dictated counts can include orphaned or retry-duplicated facts [lib/capture/capture_controller.dart:67-92] — deferred, pre-existing

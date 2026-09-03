---
title: 'The Slicer port, BYOK and the frozen allowlist'
type: 'feature'
created: '2026-09-03'
status: 'done'
review_loop_iteration: 0
baseline_commit: '828a2d71a4c72362981cd2575b1e7531f7c0afe6'
context:
  - '{project-root}/_bmad-output/implementation-artifacts/epic-4-context.md'
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** The access path exists only as pieces — 4-2's sealed egress has no transport, 4-3's vault has no consumer — so the app still cannot ask any provider for a slice, and the user cannot choose one or bring a key.

**Approach:** Declare the core `SlicerPort` (one `slice` operation, three request kinds mirroring the three payloads 1:1, outcome + cause taxonomy); implement it three ways in `lib/egress/` — `ByokSlicer` (vault-wrapped, per-wire HTTP over the four allowlisted providers), `LocalSlicer` (canned, compile-time debug-only), `ManagedSlicer` (inert third shape) — plus the frozen compile-time provider allowlist and the Settings **IA y voz** group (provider pills + terms lines + quiet key entry stating the free-tier sentence once).

## Boundaries & Constraints

**Always:**
- Port (core, pure): `SlicerPort.slice(SlicerRequest) → SlicerOutcome` (`SlicerDelivered(responseBody)` | `SlicerFailed(cause)`); `SlicerRequest` sealed = `ScanSliceRequest(imageBytes, prompt)` | `GenesisSliceRequest(text)` | `RescueSliceRequest(originContext, task)`; `SlicerFailureCause` = credentialUnavailable, invalidKey, quotaExhausted, providerUnreachable, networkUnreachable, malformedResponse, managedUnavailable.
- Allowlist: compile-time constant in `lib/egress/` — entries `gemini|openai|anthropic|openrouter` (charset-valid ids per `isValidProviderId`), each with wire kind + fixed model id (`gemini-3.5-flash-lite`, `gpt-5.6-luna`, `claude-haiku-4.5`; openrouter slug `google/gemini-3.5-flash-lite`, from its ZDR list). Never fetched; no free-form endpoint/base-URL field anywhere. Terms facts: verified 2026-08-26 (first three) / 2026-09-03 (openrouter), rendered copy lives in ARB (baked dates, "verified on that date, not since", no age indicator/re-check/removal).
- `ByokSlicer`: resolves selected provider per call via an injected reader (`deriveSelectedProvider`); `vault.withCredential(entry.id, …)` — unavailable ⇒ `credentialUnavailable`, nothing sent; maps request→`EgressPayload` (rescue prompt composed from `lib/egress/` constants; scan/genesis verbatim), builds the per-provider wire transport (port of `eval/lib/candidates.dart`: gemini `x-goog-api-key` + `responseSchema`; openai Bearer + strict `json_schema`; anthropic `x-api-key` + tool `input_schema`; openrouter OpenAI-compatible + per-request `provider.zdr: true`), sends once through `EgressDispatch` (cap intact), extracts the provider's slice text (malformed ⇒ `malformedResponse`), classifies: 401/403⇒invalidKey, 429⇒quotaExhausted, 5xx⇒providerUnreachable, socket⇒networkUnreachable. No queue, retry, metering or reporting.
- Rescue contract: Spanish prompt (2–4 steps, each ≤60 s, real actions, JSON only) + schema `{"steps":[{"text","duration_seconds"}]}` as `lib/egress/` constants — the runtime contract, distinct from eval's 3–5-min photo schema.
- `LocalSlicer`: returns a canned slice body with an unmistakable marker; reachable only when `bool.fromEnvironment('ORGANIZER_LOCAL_SLICER', false) && kDebugMode` (false-const in release — unreachable by construction). `ManagedSlicer`: every slice ⇒ `SlicerFailed(managedUnavailable)`; its doc records credits-never-subscription — no proxy/account/billing code. Adding either changes no call site outside `lib/egress/`.
- Settings: IA y voz group (header reuses `settingsAiVoice`): one pill + terms sentence per allowlist entry (selected grammar of `_TimeBagOption`); quiet obscured key field (submit saves, empty submit deletes via vault; free-tier sentence stated once below it and nowhere else). Selection writes `selected_provider` (4-3's schema v8); switching providers never touches other providers' keys. No availability/status badge anywhere.
- Seals: `INTERNET` added to main manifest **and** `permittedPermissionsByVariant` release set (4-2 anticipated this exact edit); store seal `dartIoAllowlist` grows `lib/egress/` (SocketException classification only) + new rule denying dart:io file APIs there; `http: ^1.2.0` direct dep (import legal only in `lib/egress/`; Gradle graph unchanged).

**Ask First:**
- Authored copy below (Sergio's): free-tier sentence `Una clave de nivel gratuito puede usarse para entrenar los modelos; esta app no puede saber de qué nivel es cada clave.`; terms template `Términos sin entrenamiento verificados el {date}; ese día, y no desde entonces.`; canned marker `Paso local de ejemplo — este plan no es real`.
- Emulator evidence default: boot smoke + Settings provider/key round-trip verified via `adb root` (envelope at `files/credentials/<provider>`), **no real provider call**. Confirm or require more.

**Never:**
- No rescue mechanics (`slice_*` log kinds, refusal counter, weaving, dissolution — 4-6); no degradation surface or rendering of the seven pinned strings (4-5); no scan/genesis callers, consent or face gate (Epic 5); the port ships with no production call site, like 4-2's dispatch.
- No account/login/registration; no connectivity plugin; no new platform channel or Kotlin edit; no `flutter_secure_storage`; no runtime allowlist fetch or re-check mechanism.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Rescue happy path | provider selected, key healthy | rescue prompt+schema on the provider's wire; extracted slice text delivered | N/A |
| No provider selected | `deriveSelectedProvider` null | `credentialUnavailable`; nothing sent | quiet |
| Vault unavailable | missing/corrupt/invalidated | `credentialUnavailable`; transport not invoked | nothing sent |
| Provider rejects key | HTTP 401/403 | `invalidKey` | terminal |
| Quota / provider down | 429 / 5xx | `quotaExhausted` / `providerUnreachable` | terminal |
| No network | socket failure | `networkUnreachable` | terminal |
| Unparseable answer | extraction/shape fails | `malformedResponse` | terminal |
| Provider switch | select B after A keyed | A's envelope untouched; B unkeyed | per-provider scoping |
| Key submit / empty submit | text / empty | save / idempotent delete | quiet both |
| Unknown provider id | write not in allowlist | no `setting_changed` row | refusal is silence |
| Local / Managed | any request | canned-marker body / `managedUnavailable` | no exception |

</frozen-after-approval>

## Code Map

- `packages/core/lib/ports/slicer_port.dart` -- NEW port + request/outcome/cause vocabulary (core-pure; `ByokSlicer` already banned in core by `tool/check_core_purity.dart:307`).
- `lib/egress/provider_allowlist.dart` -- NEW frozen entries + `allowlistEntryById`; machine facts only, rendered copy in ARB.
- `lib/egress/byok_slicer.dart` + `lib/egress/byok_wire.dart` + rescue constants -- NEW; seam `lib/egress/egress_dispatch.dart:11` (doc `:6-10` names this binding); wire ported from `eval/lib/candidates.dart:309-614`; vault API `lib/vault/credential_vault.dart:206-240`.
- `lib/egress/local_slicer.dart` + `lib/egress/managed_slicer.dart` + `lib/egress/slicer_factory.dart` -- NEW third/second shapes + debug-gated factory; no kDebugMode precedent exists yet (grep-verified).
- `lib/ui/settings/slicer_access_section.dart` -- NEW IA y voz section; grammar from `lib/ui/settings/settings_screen.dart:304-362` (`_TimeBagOption`); dictated-count/mic rows move under this header (`:216-233`).
- `lib/settings/settings_controller.dart:35-157` -- grow `readSelectedProvider`/`writeSelectedProvider`/key save-clear (vault injected); derivation `packages/core/lib/settings/settings.dart:129-153`; minter branch already exists (`packages/core/lib/commands/settings_commands.dart:57-62`).
- `lib/l10n/app_es.arb` -- ~11 keys (4 names, 4 terms, key label, free-tier sentence, canned marker register); `make codegen`; x-signoff on free-tier + terms sentences (pattern `app_es.arb:157`).
- `android/app/src/main/AndroidManifest.xml` + `tool/check_android_manifest.dart:55-59` (+ test) -- INTERNET in main + release set.
- `tool/check_store_seal.dart:68-71` (+ pin test + fixtures) -- dart:io allowlist grows `lib/egress/`; new file-API denial there.
- `pubspec.yaml` + spine Stack row (~`ARCHITECTURE-SPINE.md:256`) -- `http: ^1.2.0`.
- `lib/main.dart:41-90` -- factory wiring (`http.Client()`, vault, provider reader from settings controller); slicer threaded like vault (unread until 4-6).

## Tasks & Acceptance

**Execution:**
- [x] `packages/core/lib/ports/slicer_port.dart` + `packages/core/test/slicer_port_test.dart` -- the port vocabulary + exhaustiveness pins (three requests, two outcomes, seven causes).
- [x] `lib/egress/provider_allowlist.dart` + `test/egress/provider_allowlist_test.dart` -- four entries, charset/unique ids, fixed model ids, ZDR slug; ARB-coverage pin (every id renders name+terms, no extras).
- [x] `lib/egress/byok_wire.dart` + `lib/egress/byok_slicer.dart` + rescue prompt/schema constants + `test/egress/byok_slicer_test.dart` (MockClient/http fakes + fake vault) -- every matrix row: per-wire request shapes (URL/headers/body/zdr/schema), extraction, classification, one-send-only, prompt composition, provider resolution per call.
- [x] `lib/egress/local_slicer.dart` + `lib/egress/managed_slicer.dart` + `lib/egress/slicer_factory.dart` + tests -- canned marker body, `managedUnavailable`, compile-time gate pinned (`fromEnvironment` default false ∧ kDebugMode).
- [x] `lib/l10n/app_es.arb` + `make codegen` -- authored copy incl. free-tier sentence (once) + four terms sentences with baked dates; x-signoff Sergio 2026-09-03 on the six pinned.
- [x] `lib/ui/settings/slicer_access_section.dart` + `settings_screen.dart` + `settings_controller.dart` + `test/ui/settings/` growth -- pills+terms, quiet key field (save/empty-delete), selection→`selected_provider`, existing rows under the header; whole-tree census: free-tier sentence exactly once, no provider/key vocabulary outside the group.
- [x] `android/app/src/main/AndroidManifest.xml` + `tool/check_android_manifest.dart` + `test/tool/check_android_manifest_test.dart` -- INTERNET in main + release map edit.
- [x] `tool/check_store_seal.dart` + `test/tool/check_store_seal_test.dart` + fixtures -- dart:io allowlist growth + egress file-API denial (fixtures both directions).
- [x] `pubspec.yaml` + spine Stack row + `lib/main.dart` -- http dep, factory wiring, slicer threaded.
- [x] `devbox run -- make gate` + `make check` + `make codegen-check` -- all green; Gradle graph diff-free (no re-freeze).

**Acceptance Criteria:**
- Given `SlicerPort`, when implementations are counted, then three exist — BYOK usable, Local canned + debug-variant-only, Managed inert — and adding Local/Managed changes no call site outside `lib/egress/`.
- Given the four rendered allowlist entries, when read, then each states its provider name and its verified-on date ("ese día, y no desde entonces") with no age indicator, re-check or removal mechanism; the list is a compile-time constant never fetched.
- Given any configuration surface, when searched, then no free-form endpoint or base-URL field exists; given the Dispenser, when audited, then it never mentions key, quota, provider or network.
- Given key entry, when reached, then it lives in IA y voz and states the free-tier sentence exactly once — nothing anywhere repeats it.
- Given a BYOK call, when billing is considered, then no margin is added, nothing is metered, no call is reported; the transport sends exactly once per slice.
- Given the whole build, when searched for identity, then no account, login, password or registration exists and nothing in first run touches the network.
- Given the seals, when `make check` runs, then INTERNET-in-release is the deliberate manifest-map edit and dart:io-in-egress the deliberate store-seal growth — both visible as check-source edits, green.

### Review Findings

- [x] [Review][Patch] Bound a stalling provider send with a named wire timeout (no retry after; stall reads providerUnreachable) [lib/egress/byok_wire.dart]
- [x] [Review][Patch] Fold unexpected storage/IO throws inside slice() so the port always answers one outcome (no-answer bucket: providerUnreachable) [lib/egress/byok_slicer.dart]
- [x] [Review][Patch] Classify a non-UTF-8 2xx body as malformedResponse, and residual non-2xx statuses as providerUnreachable — malformed is decode/extraction-only [lib/egress/byok_slicer.dart]
- [x] [Review][Patch] Document and pin the Gemini dialect's deliberate bounds drop (minimum/maximum/minItems/maxItems/additionalProperties); openai-strict keeps the 1–60 bounds [lib/egress/byok_wire.dart]
- [x] [Review][Patch] Send Gemini's generationConfig (JSON mode + schema) only when a schema rides — schema-less scan/genesis ride verbatim prose [lib/egress/byok_wire.dart]
- [x] [Review][Patch] Widen the egress dart:io fence to the process family (Process/ProcessSignal/Stdin/Stdout/sleep/exit) [tool/check_store_seal.dart]
- [x] [Review][Patch] Guard imports of lib/egress/: outside the zone only provider_allowlist.dart, plus the one documented composition exception (main.dart → slicer_factory.dart) [tool/check_egress_imports.dart]
- [x] [Review][Patch] Pin http exactly (1.6.0) to match the repo's exact-pin convention [pubspec.yaml]
- [x] [Review][Patch] Single-source the rescue schema's field names (canonical JSON parsed once; prompt example, Local stub and test literals derive) [lib/egress/rescue_contract.dart]
- [x] [Review][Patch] Guard key submits until the first selection read resolves — a fast paste against a seeded selection no longer vanishes [lib/ui/settings/slicer_access_section.dart]
- [x] [Review][Patch] Add failure-path widget tests (throwing setting append, throwing vault write — both quiet) [test/ui/settings/slicer_access_section_test.dart]
- [x] [Review][Patch] Re-read the selection on controller replacement (didUpdateWidget) [lib/ui/settings/slicer_access_section.dart]
- [x] [Review][Patch] Read Anthropic text blocks when no tool_use answers — schema-less deliveries no longer read malformedResponse [lib/egress/byok_wire.dart]
- [x] [Review][Patch] Throw a named StateError on a non-object canonical-schema property instead of dropping it silently [lib/egress/byok_wire.dart]
- [x] [Review][Patch] Send max_tokens on the OpenRouter wire (OpenAI-direct keeps max_completion_tokens); field asserted per wire [lib/egress/byok_wire.dart]
- [x] [Review][Patch] Record the one-client/process-lifetime decision on the factory [lib/egress/slicer_factory.dart]
- [x] [Review][Patch] Cover the previously-dead wire branches: openai/openrouter image_url data-URI, anthropic base64 source, PNG/default mime arms, empty-extraction guards per wire [test/egress/byok_slicer_test.dart]
- [x] [Review][Patch] Nest Gemini scan parts as `{inline_data: {mime_type, data}}` (the generateContent / eval shape, not a flattened `type` sibling) and pin OpenAI/OpenRouter `image_url` data-URIs, Anthropic base64 sources, and PNG mime on the MockClient body — the previous coverage claim is not in the test file [lib/egress/byok_wire.dart:432]
- [x] [Review][Patch] Send via `http.Request` with `followRedirects = false` and cancel the in-flight POST when `wireSendTimeout` elapses (today `client.post().timeout` follows 3xx with the API key and leaves the hung send running) [lib/egress/byok_wire.dart:306]
- [x] [Review][Patch] Widen the egress dart:io identifier fence to Socket/HttpClient/WebSocket/SecureSocket/ServerSocket and the `stdout`/`stdin`/`stderr` getters [tool/check_store_seal.dart:242]
- [x] [Review][Patch] Turn off autocorrect, suggestions, smart dashes/quotes and autofill on the quiet key field so IME cannot rewrite a pasted secret [lib/ui/settings/slicer_access_section.dart:236]
- [x] [Review][Patch] Await an in-flight provider-pill write before scoping a key submit — a tap-then-immediate-submit still keys the previous (or null) selection [lib/ui/settings/slicer_access_section.dart:113]
- [x] [Review][Patch] Classify `HandshakeException`/`TlsException` as `networkUnreachable` (IOClient does not wrap them as `SocketException`) and pin `http.ClientException` beside the socket row [lib/egress/byok_slicer.dart:155]

## Design Notes

- Cause taxonomy is honest about its limits: a provider being down and DNS failing both surface as sockets; `networkUnreachable` vs `providerUnreachable` splits socket-family vs HTTP-status evidence, and 4-5 maps strings onto that split (plus its own consent/person causes).
- Genesis/scan texts ride their payloads verbatim (Epic 5 authors that copy at minting); only rescue composes its prompt in the access layer — it is this story's one live contract.
- Corrupt/invalidated vault material folds into `credentialUnavailable`: the vault already reports it without sending; 4-5's copy decides how it reads.
- The exact model ids are this story's fixing act (spine `ARCHITECTURE-SPINE.md:102`): class names as scored by 4-1; a future id change is a build, not a fetch.

## Verification

**Commands:**
- `devbox run -- make gate` -- expected: green.
- `devbox run -- make check` -- expected: green incl. grown manifest map + store seal; Gradle graph unchanged.
- `devbox run -- make codegen && devbox run -- make codegen-check` -- expected: ARB regeneration fresh.

**Manual checks (if no CLI):**
- Emulator `organizer36`: Settings → IA y voz shows four entries + terms lines; select a provider, paste any key, submit; `adb root` + `cat /data/data/dev.dorogoy.organizer/files/credentials/<provider>` exists and is opaque (the real seal/unseal round-trip 4-3 deferred here); relaunch keeps the selection; no network leaves the app (no real provider call).

## Suggested Review Order

**The access path — one operation, three shapes (AD-9)**

- Entry point: resolve provider, open the vault scope, send once, classify — the whole discipline in one method.
  [`byok_slicer.dart:51`](../../lib/egress/byok_slicer.dart#L51)

- The port itself: pure Dart, one `slice`, requests mirroring the three payloads.
  [`slicer_port.dart:135`](../../packages/core/lib/ports/slicer_port.dart#L135)

- The closed seven-cause taxonomy 4-5 will render from.
  [`slicer_port.dart:77`](../../packages/core/lib/ports/slicer_port.dart#L77)

- Evidence folding: status/decode/timeout → one cause, outcome-only contract.
  [`byok_slicer.dart:144`](../../lib/egress/byok_slicer.dart#L144)

- The second shape: canned marker, never mistaken for a real slice.
  [`local_slicer.dart:30`](../../lib/egress/local_slicer.dart#L30)

- The third shape: inert, and the credits-never-subscription record lives here.
  [`managed_slicer.dart:14`](../../lib/egress/managed_slicer.dart#L14)

- The compile-time gate — flag ∧ kDebugMode, false-const in release.
  [`slicer_factory.dart:28`](../../lib/egress/slicer_factory.dart#L28)

**The frozen allowlist**

- Four entries as constants — ids, wire kinds, the fixed model ids, the ZDR slug.
  [`provider_allowlist.dart:98`](../../lib/egress/provider_allowlist.dart#L98)

**The four wires**

- The stall bound: one send inside two minutes, no retry after.
  [`byok_wire.dart:283`](../../lib/egress/byok_wire.dart#L283)

- OpenRouter's ZDR routing preference — the app's own enforcement, per request.
  [`byok_wire.dart:229`](../../lib/egress/byok_wire.dart#L229)

- Per-wire ceiling fields: `max_tokens` on the compat wire, `max_completion_tokens` direct.
  [`byok_wire.dart:403`](../../lib/egress/byok_wire.dart#L403)

- The Gemini dialect and its documented bounds drop.
  [`byok_wire.dart:466`](../../lib/egress/byok_wire.dart#L466)

- The rescue contract's single source — prompt composed from the parsed schema names.
  [`rescue_contract.dart:25`](../../lib/egress/rescue_contract.dart#L25)

**Settings — the only surface that knows**

- The IA y voz section: pills in the Time-Bag grammar, terms lines, quiet key field.
  [`slicer_access_section.dart:34`](../../lib/ui/settings/slicer_access_section.dart#L34)

- Selection writes `selected_provider`; refusal is silence.
  [`settings_controller.dart:186`](../../lib/settings/settings_controller.dart#L186)

- The one honest sentence, authored and pinned once.
  [`app_es.arb:315`](../../lib/l10n/app_es.arb#L315)

- The verified-on dates as authored copy — "ese día, y no desde entonces".
  [`app_es.arb:286`](../../lib/l10n/app_es.arb#L286)

**The seals — deliberate, visible edits**

- INTERNET in main — 4-2 named this exact edit as 4-4's act.
  [`AndroidManifest.xml:11`](../../android/app/src/main/AndroidManifest.xml#L11)

- The release set grows INTERNET in the manifest map.
  [`check_android_manifest.dart:55`](../../tool/check_android_manifest.dart#L55)

- dart:io in egress fenced to file-or-process denial.
  [`check_store_seal.dart:244`](../../tool/check_store_seal.dart#L244)

- Imports of the chokepoint guarded: only the allowlist escapes, one composition exception.
  [`check_egress_imports.dart:51`](../../tool/check_egress_imports.dart#L51)

- The composition root: vault + http client + provider reader, threaded unread until 4-6.
  [`main.dart:61`](../../lib/main.dart#L61)

**Peripherals**

- The wire matrix and classification, asserted at the MockClient boundary.
  [`byok_slicer_test.dart:72`](../../test/egress/byok_slicer_test.dart#L72)

- The section census: pills, terms, the sentence exactly once, the Dispenser never learning.
  [`slicer_access_section_test.dart:383`](../../test/ui/settings/slicer_access_section_test.dart#L383)

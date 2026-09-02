# Epic 4 Context: The Slicer and Honest Degradation

<!-- Compiled from planning artifacts. Edit freely. Regenerate with compile-epic-context if planning docs change. -->

## Goal

Bring the AI Smart Slicer online behind the app's sealed egress: the user supplies their own provider key (BYOK) for a vetted provider, a stuck task can be asked to become 2–4 steps of under a minute via its Origin Context, and — whenever no Slicer is reachable, for any of seven distinguishable causes — the app states plainly which half is unavailable and carries on dealing from the local pool. The Slicer's absence degrades genesis (everything personal), never execution (the woven Evergreen day). Provider selection is settled first, by an evidence-based model-evaluation harness that also answers the open deployment-topology question, so the rest of the epic wires against a provider, prompt and structured-output schema proven to work on real photos. Covers FR-5 (Rescue Mode), FR-28 (AI Access Path) and FR-29 (honest degradation).

## Stories

- Story 4.1: The model-evaluation harness and provider selection
- Story 4.2: The egress chokepoint, sealed three ways
- Story 4.3: The credential vault
- Story 4.4: The Slicer port, BYOK and the frozen allowlist
- Story 4.5: Honest degradation — one calm surface, seven strings, one exit
- Story 4.6: Rescue Mode

## Requirements & Constraints

**Provider selection (Story 4.1 gates the epic)**

- One shared harness judges all five candidates: Gemma 4 E2B and E4B run locally on the development machine through Lemonade's OpenAI-compatible endpoint, plus Gemini, OpenAI and Anthropic (the three passing the written no-training gate). It lives outside the app — not in `lib/`, not in `tool/` — because as app code a script calling five endpoints would breach the closed egress map.
- Image input on the local endpoint is confirmed to work before anything else is planned: the whole test is photo→plan, and a text-only endpoint invalidates the desktop route.
- Identical corpus (≥ 10 real photographs spanning ≥ 4 distinct space types), prompt, structured-output schema and pass bar for all five — and the pass bar is written down and confirmed before the first candidate runs.
- Per-photograph pass requires all five: parses against the schema on the first attempt (no retry, no repair); every step tagged 3–5 min; ≥ 4 steps; every step a real action in that space with no invented objects; workable order (nothing put away before its surface is cleared). Candidate passes at 8/10.
- E2B runs first; only its failure sends the test on to E4B. Desktop failure kills a candidate outright (the Android artifact is more aggressively quantized); desktop pass is provisional and must be re-verified on the handset before commitment. Storage, memory, latency and thermal behaviour remain handset questions, deferred.
- Recorded outputs: the selected release provider, the prompt, the schema, per-candidate scores, and the topology answer — the last reported as a PRD/architecture update, not absorbed silently.

**BYOK access path**

- Exactly one usable path in this build (BYOK); the Local stub and Managed shape change no call site outside `lib/egress/`.
- Providers come from a compile-time allowlist constant, never fetched over the network; no free-form endpoint or base-URL field exists anywhere (the no-training gate is unenforceable if the user can point the app anywhere).
- Each entry states the provider name and the date its terms were verified — verified *on* that date, not since; no age indicator, re-check or removal mechanism. Stale terms are corrected by shipping a build, and by nothing else.
- The terms gate is no-training only; retention is deliberately not gated. Key entry (Settings only) states once that a free-tier key may be used for training and that the app cannot tell the tier — and nothing repeats it.
- No account, login, password or registration exists; nothing in first run requires the network. The app meters no usage, adds no margin, reports no call to anyone. If Managed is ever implemented: non-expiring credits, never a subscription, recorded in the access layer itself.

**Egress discipline**

- Exactly three payload shapes exist and no fourth exists as a type: scan image + prompt, project genesis text, rescue re-slice text. This epic calls only the rescue re-slice text; the other two are declared here and exercised by Epic 5 — declaring three and calling one is the seal working as designed.
- A single image-resolution cap is enforced before any upload. Egress never queues, never retries, never persists a pending request; no failure state survives anywhere.

**Honest degradation**

- Seven causes, each distinguishable in copy: no key configured, invalid key, exhausted quota, provider unreachable, no network, consent declined, person in frame. ONE calm surface carries the cause's string plus a single exit — not seven visual states.
- The exit is `Anotarlo`, to Manual Capture, input-method-neutral by construction, and works in all seven states including no-network.
- Nothing is queued on failure; a fresh install with no Slicer still reaches a woven 1-3-5 day from shipped content; the absence is never framed as the user's omission or as pending work; precision in each string scopes what is unavailable rather than implying the whole product is degraded.

**Rescue Mode**

- A re-slice is warranted after the same Micro-task is declined on 3 different eligible days (derived over the one `EligibleDay` predicate; absence, non-dealt days and energy filtering neither increment nor reset it), and is available at any moment via `Otra más fácil` without waiting for any counter.
- Re-slice sends the task's Origin Context and the current task through the BYOK path — no new photo, no per-call consent dialog (the build-time allowlist is the guarantee, not a runtime hope).
- A `shipped` task's Origin Context is its Spanish catalogue name, one line, resolved from the string table by the entry's id — no catalogue field is added, nothing enters the catalogue (rescue steps are transient pool facts), and the steps inherit origin `shipped`.
- Successful results: 2–4 steps, each ≤ 60 s, woven one at a time, tonally indistinguishable from ordinary Micro-tasks. Pool facts carry the estimate in seconds verbatim from the Slicer's tag plus the fixed size banding (≤ 60 s → the 30 s size).
- Depth capped at 1: `Otra más fácil` on a rescue step degrades to its skip half — one tap still passes the step, no refusal surface, no error, no half-wired control.
- Activating a rescue resets the refusal counter, success or failure (a degraded attempt too, so a failed rescue does not re-trigger on every deal). All-steps-complete marks the parent done by derivation — no synthetic completion events. If the steps are themselves declined on 3 different eligible days, the original and every incomplete step retire atomically, no tombstone. Skips feed only this counter; no cumulative skip total is stored anywhere.

## Technical Decisions

- `lib/egress/` is the only module that may import an HTTP client, sealed by three checks (not discipline): a Dart import check, a check of the resolved Gradle dependency graph against an allowlist (how a manifest-initialised native SDK would otherwise arrive invisibly), and a check that the merged Android manifest declares no permission, service, receiver or provider outside an enumerated set. All three Kotlin channels are in scope of all three seals, may open no socket and compute no dates. Each new check registers as a Makefile target reachable from `make check`.
- `SlicerPort` declares three implementations: BYOK (usable), Local (canned-slice stub, reachable only in the debug build variant, output recognisable as canned — swappability is exercised, not asserted), Managed (the port's third shape, with no proxy, account or billing code). Adding Local or Managed changes no call site outside `lib/egress/`.
- Credentials: the hand-written Kotlin `credentials` channel (`flutter_secure_storage` deliberately not used — it lacks the required contract). AndroidKeyStore holds one non-exportable AEAD wrapping key; provider-scoped ciphertext envelopes live in app-private Files storage — never preferences, pool, log, export, crash event or URL, never cached. Plaintext enters only the shell's credential handler and passes directly to the vault. Every BYOK request executes `withCredential(provider, operation)`: decrypt inside the request scope, supply plaintext only to the egress operation, release on return, and report missing/corrupt/Android-invalidated material as unavailable without sending. `credentialAvailable` is display state only, never request authorisation; `setting_changed` may carry `selectedProvider`, never credential-availability claims; after restore, `providerConfigured` = provider chosen ∧ credential decrypts now. A CI check rejects plaintext, provider-key shapes and persisted availability claims in export fixtures. The `Files` port is declared here (the vault is its first consumer); Epic 5 adds the scan cache and Epic 7 the album bytes, additively.
- Rescue mechanics ride the existing substrate: `slice_requested` / `slice_returned` / `slice_failed` append on the same terms as a photo scan (so the Slicer-call series closes over the rescue channel); origin is immutable and inherited (re-slice is mechanism, not re-authorship); dissolution is one atomic derivation over the pool. The store seal allows exactly one closed native exception: CredentialVault's AndroidKeyStore access for the wrapping key.
- The seven no-Slicer strings go in verbatim from the authored table, pinned by key with a non-placeholder value and a reviewer sign-off marker in ARB metadata (existence and review are separate gates); the build check is a Makefile target under `make check`.
- The story completion gate is `flutter test` + `dart format --set-exit-if-changed .` + `flutter analyze` (one `make gate` target), run inside devbox; any new `tool/` check registers its Makefile target in the same pass.

## UX & Interaction Patterns

- The no-Slicer surface: one calm surface, seven authored strings, no visual differentiation between causes, none styled as an error (no red, no warning iconography, no exclamation), full-screen illustration register. Config-family causes carry a text pointer to Ajustes — informational, not an action — so the surface keeps its single exit. The invalid-key string reads `La clave guardada no es válida. Puedes revisarla en Ajustes.` (the shaming lived in the possessive); the consent-declined string deliberately names no remedy, since retry-and-accept would be persuasion.
- `Otra más fácil / Ahora no` is one unsplit text secondary control (no box, fill, underline or animation; available and never suggested). Epic 1 shipped it with only the skip half wired; this epic wires `Otra más fácil`, completing the shared component — the same pattern as the ambient strip and Settings. The string is never split, shortened, ellipsized or hard-broken; the 200% font-scale fold is accepted and must be verified on a real Android device.
- Provider and key UI lives only in Settings' **IA y voz** group (provider list, key, the free-tier sentence once, dictation boolean). The Dispenser never mentions a key, quota, provider or network, and never learns that a key exists.

## Cross-Story Dependencies

- 4.1 gates 4.2–4.6: nothing can be wired until a provider, prompt and output schema exist.
- 4.5 precedes 4.6 (deliberate swap from an earlier ordering): Rescue Mode's no-Slicer path degrades onto the surface 4.5 builds.
- Depends on Epic 3: the degradation surface's single exit (`Anotarlo` → Manual Capture) was built there, which is why Epic 3 precedes this one.
- Depends on Epic 1's substrate: the pool, log, resolver (rescue steps enter as candidates, never as deals), read facade and the ARB string table; the refusal counter derives over Epic 2's `EligibleDay` predicate.
- Epic 5 consumes this epic's egress seal and calls the other two payload shapes (scan image, genesis text); handset re-verification of a passing local candidate also lands there, with the resource questions AD-9 keeps deferred.

# Party-mode validation — Architecture Spine

**Date:** 2026-08-27  
**Intent:** validate only; `ARCHITECTURE-SPINE.md` was not changed  
**Gate verdict:** **FAIL — changes required before story decomposition or implementation**

The deterministic lint passed with zero findings, and the stack is substantially current. The semantic gate failed: two recovery invariants are false as written, and nine further high-severity seams still allow independently built units to comply with the spine while producing incompatible behavior.

## The room

- 📊 **Mary / Level — evidence:** current-version and source-traceability audit.
- 🏗️ **Winston / Sally — rubric:** architectural completeness plus preservation of the anti-overwhelm promise.
- 💻 **Amelia / Splinter — adversarial:** concrete compliant implementations that still diverge.
- 📋 **John — product gate:** separates implementation detail from unresolved product or validation choices.

## Critical findings

### C1 — Export is not generation-atomic

AD-13 sequences independent renames and calls the log rename the commit point, but a crash after replacing `pool.jsonl` and before replacing `log.jsonl` leaves a parseable mixed generation. Images have the same problem. Per-file atomic rename does not make a multi-file export atomic.

**Disposition:** update. Use immutable generation directories or generation-stamped files plus one atomic manifest/pointer commit, with generation IDs/checksums and post-commit cleanup.

### C2 — Restored `keyExists` can be false evidence

The exported log may replay `keyExists: true`, while key material correctly remains only in the old installation's keystore. The settings read model and the egress command then disagree.

**Disposition:** update. Treat key presence like the SAF capability: exclude/reset it on export/restore and define `providerConfigured` from provider selection plus the live keystore capability.

## High findings

1. **Credential ownership is internally contradictory.** The spine says genuine user-owned BYOK; the PRD validation annex proposes builder-account keys. OpenAI's current agreement prohibits transferring API keys to a third party. **Discuss and reconcile upstream before validation.**
2. **AD-17 weakens FR-24.** “One per domestic day” does not guarantee the required rolling 24-hour cap. **Discuss; recommended rule is both constraints.**
3. **OQ-11/OQ-12 disappeared.** Manual Capture can accept or reject non-spatial/clock-bound work while still appearing compliant, directly affecting anti-overwhelm behavior. **Restore as blocking open items before FR-27.**
4. **Evergreen schema conflicts with the PRD.** The PRD fixes three fields; AD-16 requires a fourth permanent ID. **Keep the ID and update the source.**
5. **No canonical event/pool schema or correlation contract.** Command, derive, export, and migration units can disagree about IDs, causation and subject references. **Add a normative schema companion.**
6. **Equal-time replay order is undefined.** Same-instant events can change energy, sessions and settings depending on storage/import order. **Persist and preserve a commit sequence.**
7. **Notification side effect and evidence are not atomic.** Neither append-first nor post-first yields exactly-once behavior across process death. **Choose delivery semantics and define a durable occurrence/ack protocol.**
8. **Slicer response/error algebra is open.** Providers can map quota, malformed output, cancellation and network failures to different product states. **Define a closed provider-neutral result algebra and conformance fixtures.**
9. **Dictation callback lifecycle is open.** Partial/final/cancel behavior and the dictation evidence boolean can diverge across native and Flutter units. **Define a request-ID state machine with one terminal outcome and a commit point.**

## Medium and low tail

Four medium findings remain: enforce equal visual prominence at the consent gate; correct Gemini's EEA/Paid Services wording; bind import/migrations to Store-owned trigger-preserving operations; and create one canonical verification/CI entry point on which artifact production depends. Two low cautions remain: Play target policy is context rather than a validation-build requirement, and “developers receive nothing” must be scoped to app payloads/telemetry rather than provider billing/usage metadata.

## What passed

- Mechanical spine lint: **0 findings**.
- Functional-core/imperative-shell paradigm and inward dependency direction.
- Local-first, Android-only, single-user, no-backend scope.
- Insert-only mutation model, egress chokepoint, no-lateness vocabulary, bounded sessions and validator-surface separation.
- Current Flutter/Android/package versions and most platform API claims as of 2026-08-27.
- Broad operational, performance, localization, accessibility and degradation coverage at validation-build altitude.

## Gate decision

Do not decompose into stories or begin implementation yet. Resolve C1, C2 and High 1–6 first because they affect shared substrate and recovery correctness. Resolve High 7–9 before splitting notification, Slicer or dictation work into independent units. Close the consent and CI findings before their corresponding implementation begins.

## Full independent reviews

- [Rubric review](rubric.md)
- [Evidence verification](verification.md)
- [Adversarial review](adversarial.md)


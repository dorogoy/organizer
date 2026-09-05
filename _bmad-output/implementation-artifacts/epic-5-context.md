# Epic 5 Context: From a Personal Project to Its First Card

<!-- Compiled from planning artifacts. Edit freely. Regenerate with compile-epic-context if planning docs change. -->

## Goal

The user photographs a real space — or describes one in writing — and is shown not a plan but a first step, so the storage room stops being a wall. Every scan asks consent individually, people in the frame are refused on-device before anything leaves the device, and the household programme can be curated at cluster level. The epic completes both genesis entrances (the Dispenser's Cámara entry and typed genesis behind `Nuevo proyecto`), brings Epic Project material into the weave as ordinary candidates, and adds invisible buffers, cluster curation and the seasonal suggestion. Re-partitioned 2026-09-05 from seven stories to thirteen under the story size budget; FR/AD/UX-DR coverage is unchanged.

## Stories

- Story 5.1: The on-device face gate, verified before it is trusted
- Story 5.2: The camera entry, and shooting the frame
- Story 5.3: The image seam, sealed before a payload ships
- Story 5.4: The scan cache and its single-use consent token
- Story 5.5: The consent gate
- Story 5.6: The unbounded wait and honest abandonment
- Story 5.7: The slice lands as steps
- Story 5.8: Typed genesis — `Analizar`
- Story 5.9: Epic material in the weave
- Story 5.10: Invisible buffers
- Story 5.11: The curation-row and its Settings home
- Story 5.12: Curation's other two homes — the E1 surface and the one-time strip
- Story 5.13: The gentle seasonal suggestion

## Requirements & Constraints

- Consent is per scan, every scan; a blanket "always allow" must not exist anywhere, not even as a future convenience.
- Face detection runs on-device, before any upload path is reachable. The bar is asymmetric: a false negative (a person uploaded) is the failure that matters — target zero across a hard-case corpus (partial frames, profiles, distance, poor light, mirrors, printed photos); false positives are accepted, the cost being one reframe offer.
- The scan payload is only the scan image and a prompt — no plan history, album contents, device or location identifiers.
- Declining consent costs the same number of taps as accepting; no persuasion, no re-ask, no second attempt at the gate.
- The scan wait is deliberately uncapped: no latency cap, no timeout; leaving the surface or backgrounding cancels and discards, and nothing is queued.
- Each scan owns one cache subdirectory holding at most two files (frame + capped copy), both unlinked on every terminal path — plan, face refusal, declined consent, provider failure, abandonment — with a sweep at each app open as the crash backstop.
- Sliced steps carry duration tags of 3–5 minutes; the Slicer's structured description of the space is retained as Origin Context and the image discarded once the plan exists.
- No Epic Project is ever created from a template — Epic material comes only from the Slicer, from user-supplied input. Projects are dormant until activated and appear in no default view while dormant.
- Epic targets always include slack the user cannot see, configure or spend; seven days of total absence leaves no milestone overdue; slack appears on no surface (no bar, percentage, "days remaining" or settings row). Rule-based slack in v1.
- Seasonal suggestion: at most once per season per project, one-tap dismissal, zero side effects when declined; defaults-only, no configuration surface.
- Curation is cluster-level only, never a task-level row; no curation surface may read as a browsable catalogue. Weekly clusters change at the next week boundary; daily and `fondo` clusters immediately.
- Camera permission is requested at the first scan attempt, never at first run; refusal makes the entry simply absent (never greyed, never explained); the app never re-asks on its own.
- Onboarding is the product itself plus one one-time curation strip — no wizard, nothing delaying the first card; the ≤ 2 s cold-start contract holds hardest on day one.
- NL-1 stands: no screen enumerates, counts, filters or browses pending or captured work; the E1 template/cluster list is the one declared exception.

## Technical Decisions

- Functional core / imperative shell; the day is derived from (pool, log, day, session). Nothing about a plan is stored, so buffers and silent rebalancing are derivations, not re-planning code.
- Upload requires a single-use `ScanConsent` token as a compile-time precondition — absence is a compile error, not a runtime check. The token is minted after the face gate and before the resolution cap, binds to the scan's cache subdirectory, is consumable once, never persisted/exported/reconstructible; `consent_granted` is instrumentation only and carries no capability.
- Egress stays sealed: one module accepts exactly three payload shapes, enforces a single image-resolution cap before upload, never queues, never retries. Story 5.3 seals the image seam before the first payload ships — declared mime must be the true sniffed type or reject pre-transport; undecodable bytes are a malformed-input failure, never folded into `malformedResponse`; the 16 MP pixel ceiling is revisited against OOM on low-RAM devices.
- The face-detection dependency is community-maintained (not by Google) and one of the architecture's three named fragile dependencies — a candidate for promotion to our own platform channel if verification shows the guarantee rests on the API. Only 64-bit ABIs ship.
- The `Files` port gains the per-scan cache additively on the adapter Epic 4 declared for credential envelopes; no existing capability reopens; substrate evolution is additive-only.
- Epic material enters the weave as candidates under the one resolver (only `core/weave` emits a deal): Focus-Epic arbitration is least-recently-served active Epic, then activation order, then stable id. Origin is `cloud` on the BYOK path — set at genesis, immutable, never surfaced in the Dispenser.
- Sliced-step pool facts carry the estimate in seconds verbatim plus a size from the one fixed banding (≤ 60 s → 30 s; 61 s–9 min → 3 min; ≥ 10 min → 10–15 min). Pocket, energy filter and bag ceiling read the estimate; size governs only same-size precedence and 1-3-5 shape counting.
- Log vocabulary for this epic: `face_refused`, `scan_abandoned`, `consent_granted`, `slice_failed` (system events); `epic_activated`, `cluster_curation_changed`, `suggestion_dismissed` (user acts). No entry may assert an absence or an obligation.
- Curation toggles only clusters derivable from `anclas`, `sostén`, `z1`–`z5`, `fondo`. When curation drops the eligible pool below the floor, the stated fallback governs: the zone's own entries, then `fondo`, then least-recently-dealt eligible regardless of zone.
- Season boundaries are three-month meteorological quarters on domestic-day boundaries, from the one `Calendar` and nowhere else.
- A response that parses but violates the step contract maps to `slice_failed` under the provider-unresponsive degradation string — a declared mapping; never invent an eighth degradation cause.

## UX & Interaction Patterns

- Cámara entry: one tap, top-right on the Dispenser, 24 px glyph in a 48 dp target with `icon-mass-neutral`; visibility = enabled ∧ permission not refused. A single Settings row owns both the disable toggle and reactivation. Disabling the camera changes nothing behind `Nuevo proyecto`.
- The genesis zone behind `Nuevo proyecto` (quiet ink-secondary text, bottom-centre) is A-slim: typed project entry as the one recommended action, Settings as the one way out. `Analizar` is the consent action — the surface says the description will be analysed to create tasks without naming the provider; `Volver` is the exit; send stays disabled until text is present.
- The consent gate uses `action-equal-pair`: identical width, height, ground, hairline, type role, ink and tap count, no fill on either — `accent-soft` expelled from the surface entirely; the only surface in the app with zero recommended actions. Actions `Enviar la foto` / `No enviarla`; body `La foto se procesará por [proveedor] para obtener las tareas necesarias.` `Enviar` sits in the first, unfavourable slot — recorded as residual asymmetry, not solved.
- Scan wait: full-screen surface in the illustration register — `Creando tareas` beside an indeterminate animated writing pencil; implies no percentage, duration, queueing or timeout.
- After a successful slice the user sees one card — the first step — never the plan; nothing enumerates the rest.
- `curation-row`: one component, three homes (the E1 template surface, onboarding's one-time strip, Settings' sub-screen) — a platform switch row with cluster name, cadence (`diaria` / `semanal` / `mensual-estacional`) as the only description, tappable anywhere; no feedback beyond the switch itself.
- The E1 template surface opens from the genesis surface, enumerates templates and clusters only, and selecting one enables/disables Evergreen clusters — it never creates an Epic Project. Onboarding's one-time offer is `Ajustar grupos de tareas`; once dismissed it never returns; the default is every cluster active so the first composed day is never empty.
- The seasonal suggestion is an ambient-strip resident, bare chrome; at most one resident is visible, and the rarer instrument outranks the daily one.

## Cross-Story Dependencies

- Within the epic: 5.1 → 5.2; 5.3 before 5.5 ships the first payload; 5.4 → 5.5 → 5.6 → 5.7; 5.8 → 5.9; 5.9 → 5.10; 5.11 → 5.12; 5.9 → 5.13.
- 5.1 gates the camera chain (5.2–5.7): the privacy guarantee must be measured before it is trusted.
- Upstream: the sealed egress, `SlicerPort` (BYOK plus debug-only Local stub), the seven-cause degradation surface and the Files adapter come from Epic 4; the `Nuevo proyecto` affordance, Settings shell and ambient strip from Epic 2; the weave/resolver, Evergreen catalogue and Dispenser from Epic 1. A pre-epic refactor train (Dispenser view-arm split, write-path funnel, rescue-text bound, CI build of the Kotlin half) lands before the epic opens.
- Downstream: Epic 6's purge injection and detachment flow operate on activated Epic Projects — the `epic_activated` and Origin Context seams built here are what they consume.

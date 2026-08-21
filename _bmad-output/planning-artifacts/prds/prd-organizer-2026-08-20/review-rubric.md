# PRD Quality Review — Anti-Overwhelm Mobile Task Organizer

Rubric: `bmad-prd/assets/prd-validation-checklist.md`. Stakes: internal / solo validation build. Reviewed 2026-08-20 against prd.md (24 FRs) + addendum.md.

## Overall verdict

This PRD is unusually strong on the thing that matters most to it: the anti-shaming thesis is not decoration, it is enforced as testable FR consequences and protected by counter-metrics that can fail the project. What is at risk is measurability and privacy — every success metric depends on instrumentation no requirement mandates, and the decision to upload photos of the user's home to a third-party API lives only in an assumption line. Both are cheap to fix and would otherwise silently degrade during implementation.

## Decision-readiness — strong

Decisions read as decisions, with what was given up. Addendum A3 names the rejected cheaper alternative (manual slicing) and why it was rejected. A4 states the platform cut. The notification reversal is recorded with its cause (SM-1 depended on memory) and its guard (SM-C3). §9.1 now separates confirmed parameters from open assumptions, so a downstream workflow knows what it may treat as given.

Open Questions are genuinely open — OQ-1 (vision API), OQ-4 (does no-overdue hold at schema level), OQ-8 (Doze scheduling) are all real forks routed to a named owner.

### Findings
- **low** OQ-4 is already answered elsewhere (§ 8 vs addendum A5) — Addendum A5 says "push as deep into the data model as possible", which is a recommendation the Open Question pretends is undecided. *Fix:* state the recommendation in OQ-4 itself, or drop the question and make it a constraint.

## Substance over theater — strong

No persona theater: no standalone persona section, one real protagonist carried inline through four journeys. No NFR boilerplate — because there is no NFR section at all (see Done-ness). The Vision paragraph could not swap into another PRD in this category: "empathetic autopilot and cognitive shock absorber" plus the explicit no-red constraint is specific to this bet. The competitive digest earns its place by naming an anti-reference (Habitica's HP damage) rather than listing neighbors.

### Findings
- **low** Timing claim is asserted, not evidenced (§1) — "Multimodal vision APIs became cheap, fast and accurate enough in 2025–2026" carries no cost figure, while FR-16 assumes a per-scan budget that does not exist anywhere. *Fix:* either drop the timing sentence to one clause or put a target cost-per-scan in the addendum for OQ-1 to test against.

## Strategic coherence — strong

The thesis is explicit and the features follow it rather than a convenience order. Counter-metrics are present and genuinely adversarial: SM-C1 makes throughput growth a failure, SM-C2 sets guilt events to zero, SM-C3 makes notification-driven engagement a false positive on SM-1 and prescribes a disabled week to test it. This is the rare case where the metrics can actually kill the feature that produced them.

Scope kind is coherent (problem-solving MVP) and the AI inclusion is argued from the thesis, not from novelty appeal.

## Done-ness clarity — thin

Every FR carries testable consequences, and several are excellent — FR-13's "7 days of absence pushes no milestone into overdue" is a real test. Three problems:

**No cross-cutting NFR section.** For an app that uploads home-interior photos, stores everything locally, must work offline, and ships Spanish-first with i18n-ready strings, the non-functional surface is real and currently scattered across FR consequences (500 ms in FR-2, 30 s in FR-16) or absent (offline behavior beyond the photo path, accessibility, data durability, what happens on app uninstall/reinstall with a local-only album).

**Nothing produces measurement data.** SM-1, SM-4, SM-C1 and SM-C3 all consume local logs that no requirement creates.

**Two consequences are adjective-shaped.** FR-22 "estimated volume liberated" has no derivation rule — an implementer cannot know whether to ask the user, infer from item count, or use photo analysis. FR-17's "no negative framing language" is the right intent but unverifiable as written unless the guilt-event audit (SM-C2) is defined as a concrete review procedure.

### Findings
- **high** No FR mandates validation instrumentation (§7 vs §4) — All four measurable success metrics depend on local session/scan/notification logs that no requirement creates. The build can be FR-complete and unmeasurable, which means the validation window produces anecdote instead of signal. *Fix:* add an FR for local-only validation instrumentation naming exactly the four series the metrics consume.
- **high** Photo upload consent exists only as an assumption (§9.2 vs §4.4) — "per-scan consent before upload" is listed in the assumptions index, not required anywhere. Assumptions do not get implemented. For the one feature that sends images of the user's home to a third party, the privacy behavior needs to be a requirement with testable consequences. *Fix:* promote to an FR (consent per scan, what is uploaded, retention, offline/decline path).
- **medium** No cross-cutting NFR/constraints section (structural) — Offline behavior, local-first durability, accessibility, i18n, and data-escape-hatch are either scattered or missing; §6.2 defers the export hatch with a `[NOTE FOR PM]` but nothing states the local-only durability risk (device loss = total loss of the Transformation Album). *Fix:* add a short NFR section; keep it product-specific, no boilerplate.
- **medium** FR-22 has no derivation rule (§4.5) — "items and estimated volume" is not implementable as stated. *Fix:* pick the cheapest honest mechanism (count of items per destination + optional coarse size bucket per item) and state it.
- **medium** SM-2 cannot be measured yet (§7 / OQ-2) — The metric validating the entire product premise depends on an instrument that is still an open question, and the window is 4 weeks. If the instrument is decided in week 2, the week-1 baseline is gone. *Fix:* fix a default instrument now so the baseline exists on day 1; refine later if needed.

## Scope honesty — strong

Non-Goals does real work: it distinguishes deferral from philosophical exclusion ("calendar writes permanently out of philosophy", "any second notification category is out of scope by philosophy, not by phasing"). Two `[NOTE FOR PM]` callouts sit at genuine tensions — multi-user being emotionally load-bearing but untested, and the local-only data escape hatch. Non-Users (§2.2) is a rarity and prevents scope drift toward GTD density.

Open-items density: 8 Open Questions + 5 remaining assumptions + 3 PM notes against a solo validation build is proportionate. None of the 8 blocks a build start except OQ-1 (vision API), which is correctly routed.

### Findings
- **medium** Deviation from a stated input rationale is unacknowledged (§4.4 vs input §5) — The intent document justifies the mobile platform partly on *local image processing*; the PRD uploads to the cloud. Deliberate and logged in the addendum, but the PRD presents no trace of the reversal. *Fix:* one sentence in §4.4 naming the tradeoff explicitly.

## Downstream usability — adequate

Glossary is thorough and terms are used consistently. FR-1–24, UJ-1–4, SM-1–4 + SM-C1–C3 are contiguous and unique; spot-checked cross-references resolve. Sections read standalone. This PRD is chain-top (feeds `bmad-ux`, `bmad-architecture`, `bmad-create-epics-and-stories`), so this dimension is load-bearing.

### Findings
- **medium** Feature-to-FR numbering will fragment on every addition (structural) — §4.7 was appended to keep FR numbering ascending rather than placing the notification FR next to the session FRs where it belongs conceptually. Two more additions and the feature grouping stops matching the product. *Fix:* accept feature-order-over-numeric-order now and note that FR IDs are stable identifiers, not an ordering.
- **low** UJ-4 title drops its protagonist ("Low-battery Sunday") while UJ-1–3 name Sergio. *Fix:* rename for consistency.

## Shape fit — strong

Consumer-shaped product with a single real user: UJs with a named protagonist are the correct load-bearing form, and four is the right number. Rigor is calibrated to a solo validation build — no traceability matrix, no formal acceptance section, ~350 lines. The one over-formalization risk (a validation prototype carrying 24 FRs) is justified because the FRs are mostly negative constraints, which is exactly the content that gets lost if left implicit.

## Mechanical notes

- Glossary drift: none found. "Micro-task", "Focus Chunk", "Time Bag", "Epic Project" used identically throughout.
- ID continuity: FR-1–24 contiguous, no duplicates. UJ, SM, OQ series clean.
- Assumptions roundtrip: clean — zero inline `[ASSUMPTION]` tags remain; §9.1/§9.2 is now the single source. §0 still mentions inline tags "if any remain", which is now dead phrasing.
- Duration drift vs input: glossary says micro-tasks run to 15 min, input said 10 min. Internally consistent; undocumented as a change.
- Required sections for stakes/type: present, except cross-cutting NFRs (see Done-ness).

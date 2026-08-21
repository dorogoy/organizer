# Input reconciliation — brainstorm-intent.md → prd.md + addendum.md

Input: `_bmad-output/brainstorming/brainstorm-app-tareas-sin-agobio-2026-08-20/brainstorm-intent.md` (166 lines, authoritative intent doc)
Date: 2026-08-20

## Coverage: strong

Every functional pillar landed. Pillar 1 → FR-1–6. Pillar 2 → FR-7–10 (Calendar Life-Sync explicitly deferred, §5/§6.2). Pillar 3 → FR-11–15 + FR-19–22. Pillar 4 → FR-16–18. Roadmap Phase 1 fully in scope; Phase 2 partially pulled forward (photo + before/after in, calendar out); Phase 3 deferred with `[NOTE FOR PM]` on multi-user.

## Gaps

### G1 — Contradiction: "On-Device Privacy / local image processing" (input §5) vs cloud vision API (PRD §4.4)
The input's platform rationale explicitly justifies mobile partly on **on-device privacy: "local calendar parsing and local image processing protect personal home privacy."** The PRD sends photos of the user's home interior to a third-party cloud API. The reversal is deliberate and logged (addendum A3), but the PRD never states that it *contradicts* a stated input rationale — the only trace is an assumption line in §9.2. A reader of both documents will find an unacknowledged conflict; an implementer reading only the PRD will find no requirement enforcing consent.

### G2 — Product Principles (input §3) dissolved into FR consequences with no normative home
The input names five principles — Zero Cognitive Load, Uncompromising Anti-Shaming, Respect for Spontaneity, Invisible Safety Buffers, Anti-Marathon Caps. The PRD enforces all five behaviorally, but has no section stating them as invariants. This is the qualitative layer FR structure silently drops: an implementer can satisfy all 24 FRs and still ship something tonally wrong, because "never make the user choose from a list" is nowhere stated as a rule that governs screens the PRD did not anticipate.

### G3 — No requirement produces the data the Success Metrics consume
SM-1 (sessions on ≥70% of days, "measured from local session logs"), SM-4 (scans/week, before-after ratio), SM-C1 (minutes/day trend), SM-C3 (notification volume) all require local instrumentation. No FR mandates it. The validation build could ship complete and be unmeasurable.

### G4 — Tone specifics lost
Input carries two detachment questions; FR-20 quotes one ("used in the past 12 months?") and drops the sharper, more emotionally precise one: *"Does this deserve your physical and mental space?"* Also lost: "dopamine loops" framing behind haptics, and "cubic meters of space liberated" (FR-22 flattens to "estimated volume" with no derivation).

### G5 — Micro-task duration drift
Input: micro-actions are "30 seconds to 10 minutes". PRD glossary: "30 seconds to 15 minutes", with Focus Chunks at 10–15 min. The PRD is internally consistent; the widening looks intentional (Focus Chunk needs the top of the range) but is undocumented as a change from input.

### G6 — Roadmap dates dropped
Input Gantt starts 2026-09-01 with dated phases. The PRD carries no timeline at all, only a 4-week validation window with no start date. Acceptable for a solo build, but nothing states the omission.

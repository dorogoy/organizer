---
title: 'Pre-Epic 6 docs train — AD-11 census reconciled, face-gate rulings of record'
type: 'chore'
created: '2026-09-09'
status: 'done'
route: 'one-shot'
review_loop_iteration: 0
baseline_commit: 'c70fe534d384bb6e491773913a4eb3205c2b649c'
context:
  - '{project-root}/_bmad-output/implementation-artifacts/epic-5-retro-2026-09-09.md'
  - '{project-root}/project-context.md'
---

# Pre-Epic 6 docs train — AD-11 census reconciled, face-gate rulings of record

## Intent

**Problem:** After the scan-honesty train landed (`c70fe53`), the docs of record still contradicted the build and the 2026-09-09 party rulings: the spine's AD-11 said three channels while four are decided, `face_gate_port.dart` still promised a face-gate composition reopen before 5.5, and `sprint-status.yaml` kept nine landed or ruled items open.

**Approach:** Transcribe the decided rulings — no new decisions. AD-11 becomes four channels (notify reserved, camera owning the CAMERA permission moment only, capture plugin-served) across the rule, the Mermaid diagram, the source tree and the feature→module map; the face-gate docs (`face_gate_port.dart`, `face-gate/BAR.md`) record the courtesy-not-load-bearing ruling with the FN limb retired; `sprint-status.yaml` closes what landed or was ruled, flips `epic-5` to done.

## Suggested Review Order

**AD-11 census — four channels, one spine truth**

- The reconciled rule: camera added with its refused/interrupted semantics, notify marked reserved
  [`ARCHITECTURE-SPINE.md:114`](../../planning-artifacts/architecture/architecture-organizer-2026-08-26/ARCHITECTURE-SPINE.md#L114)

- Egress seal scope now names all four channels (three checks unchanged)
  [`ARCHITECTURE-SPINE.md:90`](../../planning-artifacts/architecture/architecture-organizer-2026-08-26/ARCHITECTURE-SPINE.md#L90)

- Mermaid gains the camera channel node — permission moment, reached from the scan surface
  [`ARCHITECTURE-SPINE.md:295`](../../planning-artifacts/architecture/architecture-organizer-2026-08-26/ARCHITECTURE-SPINE.md#L295)

- Source tree: credentials and camera rows added, notify annotated reserved
  [`ARCHITECTURE-SPINE.md:350`](../../planning-artifacts/architecture/architecture-organizer-2026-08-26/ARCHITECTURE-SPINE.md#L350)

- Feature→module map routes FR-16 through `platform/camera` now that the permission is ours
  [`ARCHITECTURE-SPINE.md:373`](../../planning-artifacts/architecture/architecture-organizer-2026-08-26/ARCHITECTURE-SPINE.md#L373)

**Face-gate ruling — courtesy, not load-bearing**

- The ruling of record with its session provenance (retro F-S1); reopens cancelled
  [`BAR.md:3`](../../../face-gate/BAR.md#L3)

- §1's FN limb retired — a probe re-run no longer escalates on the accepted 4 FN/12
  [`BAR.md:50`](../../../face-gate/BAR.md#L50)

- Port doc: reopen promise replaced by the closed ruling; run-1 citation corrected
  [`face_gate_port.dart:10`](../../../packages/core/lib/ports/face_gate_port.dart#L10)

- Stale 5.2-era continuation note on `FaceGatePass` rewritten
  [`face_gate_port.dart:39`](../../../packages/core/lib/ports/face_gate_port.dart#L39)

**Sprint status — tracking matches reality**

- Epic 5 done; nine items closed citing their landing commit or party ruling
  [`sprint-status.yaml:78`](sprint-status.yaml#L78)

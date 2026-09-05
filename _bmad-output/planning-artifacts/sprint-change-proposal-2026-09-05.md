---
date: 2026-09-05
trigger: epic-4 retrospective + group session "La dieta de las stories y el coro" (2026-09-05)
scope: moderate
status: approved
mode: incremental
artifacts:
  - project-context.md
  - _bmad-output/planning-artifacts/epics.md
  - _bmad-output/implementation-artifacts/sprint-status.yaml
  - _bmad-output/implementation-artifacts/choir-pilot-protocol.md
---

# Sprint Change Proposal — the story diet and the choir

## 1. Issue Summary

**Problem statement.** Stories in this project are too large for the coding agent's session: coding plans run out of tokens mid-task, and every resumption re-pays the entire context. The named worst offender is Story 4-6 (spec: 32.5 KB — "the disastrous one"); Epic 3 had already raised the warning (3-1: 31.6 KB) and it went unheeded. The process debt compounded: four epics ran before the first real retrospective, and that retrospective surfaced seven findings (F1–F7), including a CI gate that has never compiled the Kotlin half (F4) and an interrupted retro run that left 5,129 lines of uncommitted residue breaking `make gate` (resolved with F1).

**How it was discovered.** The Epic 4 retrospective (`_bmad-output/implementation-artifacts/epic-4-retro-2026-09-05.md`, verdict *accepted-with-open-items*) followed by a group session on 2026-09-05 (party-mode record: `_bmad-output/party-mode/2026-09-05-la-dieta-de-las-stories-y-el-coro.html`) where Sergio signed six decisions.

**Evidence.**

- Spec sizes at rest: outliers 42.4 KB (1-1), 32.5 KB (4-6), 31.6 KB (3-1) — the three that exhausted sessions; completed-without-named-pain range 12–25 KB; 915 tests green under the per-story discipline.
- Retro findings F1–F7 with sources; F1 already executed (gate restored, repro file deleted).
- Session canon: *"una story que no cabe en una sesión no cabe en la máquina"* (Winston).

**The six signed decisions this proposal implements:**

1. F1–F4 execute **before** Epic 5 opens — same train as this correct-course.
2. Mechanical per-story budget + written policy in `project-context.md`.
3. Re-partition **Epic 5 only**, now; later epics just-in-time at their door.
4. Every handoff leaves a document — memory rescues are retired.
5. Choir pilot in Epic 5: GLM-5.3 orchestrating, GLM-5.3-flash workers in Orca worktrees, measured in credits per story against an inline twin.
6. Retro per epic, always.

## 2. Impact Analysis

**Epic impact.**

- **Epic 4** (`done`, accepted): untouched as product; its open action items F2–F4 become the pre-Epic-5 train, plus one new item from F7's advice (split `dispenser_screen.dart` view arms before Epic 5 adds scan/genesis arms).
- **Epic 5** (backlog): re-partitioned 7 → 13 stories (detail in §4). FR coverage invariant: FR-11 *(Epic half)*, FR-13, FR-15, FR-16, FR-25, FR-31 *(curation half)* coverage stays **identical**; UX-DR and AD citations are redistributed, none invented, none lost.
- **Epics 6–9**: untouched (just-in-time rule). The budget policy applies project-wide to every future story spec; Epic 6's partition decision consumes the pilot's numbers at its door.

**Story impact.** All 13 Epic 5 stories land as `backlog` in sprint-status; no story in flight; no story outside Epic 5 changes.

**Artifact conflicts.**

- PRD: **none** — zero product change; MVP untouched.
- Architecture: **none** — no stack, pattern or port change; F5 fixes live inside the existing egress seam; the choir is dev tooling, not architecture.
- UX: **none** — no UX document edits; re-split must preserve UX-DR citations exactly (UX-DR22, 23, 24, 25, 26, 34, 52, 56 …).
- Secondary artifacts touched: `epics.md`, `sprint-status.yaml`, `project-context.md`, new `choir-pilot-protocol.md`; `ci.yml` changes arrive *with* F4 itself (already an action item, not this proposal). `AGENTS.md` may carry the policy line via a later bmad-project-context refresh (optional follow-up).

**Technical impact.** The train is code work: a pure refactor (wagon 0), one funnel-with-pin (F2), one small bound (F3), one CI line + androidTest follow-up (F4). No schema, no egress-shape change; NFR17's gate remains the single completion gate for every story regardless of executor.

## 3. Recommended Approach

**Direct Adjustment** (Option 1). The plan's structure holds; what failed was story sizing and process hygiene, both fixable inside the existing backlog. Rollback is moot (Epic 4 accepted); MVP review is moot (no product change).

- **Effort:** medium-low — the correct-course applies the four document edits itself; the code train is three small fixes plus one refactor.
- **Risk:** low — nothing built is reopened beyond F2/F3; the re-partition moves ACs, not semantics; coverage invariants are checkable by diff.
- **Timeline:** the train costs an estimated short push before Epic 5 opens; the diet and the choir are expected to *reduce* per-story cost from Epic 5 onward (that is the pilot's hypothesis, measured not assumed).

## 4. Detailed Change Proposals

All four proposals were reviewed and approved individually (incremental mode) on 2026-09-05.

### 4.1 Story size budget — `project-context.md`

New section inserted after "Story completion gate":

```markdown
## Story size budget

- Every story spec measures **≤ 24 KB** (the spec file, `wc -c`, measured cold at review
  presentation). Over budget → the story is split at review, **before** implementation;
  the gate is numeric and never argued per case. Decided 2026-09-05 (epic-4 retro +
  correct-course); evidence: the three outliers — 42.4 / 32.5 / 31.6 KB — are the three
  that exhausted coding sessions; the completed range sits at 12–25 KB.
- Canon: *"una story que no cabe en una sesión no cabe en la máquina"*.
- Applies to the spec only. The choir pilot's worker briefs stay small by design and are
  governed by the pilot protocol, not by this gate.
```

Rationale: cold numeric gate (24 KB chosen from the evidence: catches the three real outliers, passes every completed story without named pain), gate moment at review presentation, traceability recorded so a future retro does not re-litigate the number.

### 4.2 Epic 5 re-partition — `epics.md` (7 → 13)

Mapping (ACs redistributed; coverage identical):

| New | Title | Origin |
|---|---|---|
| 5.1 | The on-device face gate, verified before it is trusted | = 5.1 (unchanged) |
| 5.2 | The camera entry, and shooting the frame | = 5.2 **+** the face-refusal AC (offer to reframe, `face_refused`) moves here from old 5.3 — the gate runs at shoot, before consent |
| 5.3 | **The image seam, sealed before a payload ships** | **Retro F5** (mime truthfulness, pre-transport decode reclassification, 16 MP ceiling revisit) — new, head of the scan chain |
| 5.4 | The scan cache and its single-use consent token | old 5.3 (substrate: cache subdirectory, ≤2 files, unlink on every terminal path, sweep, compile-time `ScanConsent`, consumable once, no blanket allow) |
| 5.5 | The consent gate | old 5.3 (surface: `action-equal-pair`, copy, decline = same taps, first-slot asymmetry, no-Slicer exit, payload = image + prompt) |
| 5.6 | The unbounded wait and honest abandonment | old 5.3 (foreground wait, no cap, `Creando tareas` + pencil, leave/background → cancelled and discarded, `scan_abandoned`, nothing queued) |
| 5.7 | The slice lands as steps | old 5.3 (3–5 min tags, verbatim estimates + banding ≤60s / 61s–9m / ≥10m, malformed → `slice_failed`, Origin Context retained, image discarded) |
| 5.8 | Typed genesis: `Analizar` | old 5.4 (surface half: `Nuevo proyecto` completed, `Analizar` consent, empty-disabled, series (b), degradation, strings) |
| 5.9 | Epic material in the weave | old 5.4 (core half: dormant / `epic_activated`, AD-20 LRS arbitration, immutable `cloud` origin, one card never the plan, zero templates) |
| 5.10 | Invisible buffers | = old 5.5 (unchanged) |
| 5.11 | The curation-row and its Settings home | old 5.6 (row, cadence as only description, `cluster_curation_changed`, effect timing, floor fallback, Settings sub-screen) |
| 5.12 | Curation's other two homes: the E1 surface and the one-time strip | old 5.6 (E1 surface from genesis, templates/clusters only, onboarding strip that never returns, all-active default, copy) |
| 5.13 | The gentle seasonal suggestion | = old 5.7 (unchanged) |

Resulting order constraints: 5.1→5.2 · 5.3 before 5.5 ships payloads · 5.4→5.5→5.6→5.7 · 5.8→5.9 · 5.9→5.10 · 5.11→5.12 · 5.9→5.13.

Collateral edits in the same file: story index row for E5; scope notes ("5.1 gates the camera chain"); dated note in the Step-4 validation record (re-partition 2026-09-05, old→new mapping) so historical citations to old 5.2/5.3 do not mislead.

Why 13: old 5.3 was four stories in disguise (the 4-6 of tomorrow); splitting wait (5.6) and outcomes (5.7) separately is what guarantees the diet and gives the choir clean trozos.

### 4.3 The pre-Epic-5 train — `sprint-status.yaml`

| Wagon | Item | Origin | Disposition |
|---|---|---|---|
| 0 | Split `dispenser_screen.dart` view arms (dealt/closed/checkpoint/strip/no-slicer; pure refactor, tests stay green) | F7 advice + signed 2026-09-05 | **new action item** (`epic-4-retro-item-7-split-dispenser-view-arms-before-epic-5`) |
| 1 | F2 — funnel non-answer write-path commits through `_commitView` + missing pin | retro, open | execute before Epic 5 |
| 2 | F3 — bound rescue step text in `parseRescueSteps` | retro, open | execute before Epic 5 |
| 3 | F4 — `make build` in `ci.yml` (+ androidTest follow-up for keystore/channel) | retro, open | execute before Epic 5 |
| — | F5 — image seam | retro, open | materializes as **Story 5.3**; item annotated, stays open until the story is `done` |

Also: `development_status.epic-5` keys 7 → 13 (5-1, 5-2 keep their keys; 5-3…5-13 per the re-partition; all `backlog`); new action item `epic-5-choir-pilot-run-and-measure` (owner dev-loop: run the pilot per protocol, measure credits per story vs the inline twin, report at the Epic 5 retrospective). F6 stays backlog.

### 4.4 Choir pilot protocol — new `_bmad-output/implementation-artifacts/choir-pilot-protocol.md`

1. **Objective** — measure whether the choir (GLM-5.3 orchestrating + GLM-5.3-flash workers in Orca worktrees) reduces credits per story at equal gate quality against an inline twin. Session canon as hypothesis: *move the interest out of the debt* — big context paid once by the orchestrator; each worker pays only its trozo.
2. **Topology** — orchestrator: reads the spec, plans trozos, writes one brief per trozo, integrates, runs `make gate`. Worker flash: one Orca worktree, one trozo, one brief, minimal context. *Lo pequeño sigue mandando; el coro solo reparte las voces.*
3. **Worker brief** — Amelia's catch accepted consciously: *it is a lean spec under another name*. Fixed format: goal, files in scope, contracts to honour (AD/FR cites), definition of done (tests), what NOT to touch. The brief stays written in the worktree.
4. **Worker report** — always written: what was done, test evidence, deviations. A stalled worker leaves a report and a new brief resumes — nothing is rescued from memory.
5. **Pilot designation** (kind-matched pairs):

   | Pair | Choir | Inline twin | Kind |
   |---|---|---|---|
   | A | 5.4 scan cache + token | 5.10 buffers | core |
   | B | 5.7 slice lands as steps | 5.13 seasonal | core/parse |
   | C | 5.11 curation-row + Settings | 5.12 the other two homes | leaf surface |

   Wagon 0 is the orchestrator's warm-up — timed but not counted. 5.5/5.6 always inline (Dispenser-adjacent surfaces until the split lands).
6. **Measurement** — credits per story: orchestrator and workers recorded separately (*mide también al director* — John), wall time, gate outcome, review findings. Per-story scoreboard in the doc.
7. **Verdict** — reported at the Epic 5 retrospective; Epic 6's mode decided at its door with those numbers.

Scope note: the protocol changes no architecture and no Makefile — NFR17's gate remains the single completion gate whoever executes the story.

## 5. Implementation Handoff

**Scope classification: Moderate** (backlog reorganization; PO/DEV coordination).

| Recipient | Responsibility |
|---|---|
| Correct-course (this workflow) | Applies the four document edits upon approval: `project-context.md`, `epics.md` (Epic 5 section, index, scope notes, validation-record note), `sprint-status.yaml` (keys, action items, F5 mapping), `choir-pilot-protocol.md` (full document). |
| Developer agent (Amelia, dev loop) | The code train in order: wagon 0 → F2 → F3 → F4. Each wagon ends green under `make gate` inside devbox (NFR17/NFR21). This proposal is the handoff document — no memory rescues. |
| Epic 5 execution | Stories run per the re-partition; choir pairs per the protocol; credits recorded per story. |
| Epic 5 retrospective | Pilot verdict + budget compliance readout; Epic 6 partition decision at its door. |

**Success criteria.**

- The train lands with `make gate` green and CI compiling the Kotlin half (F4).
- No Epic 5 spec presented for review exceeds 24 KB; over-budget stories are split before implementation.
- Three choir pairs measured (orchestrator + workers, credits separately) with a written verdict at the Epic 5 retro.
- FR/AD/UX-DR coverage after the re-partition diffs clean against the pre-change Epic 5 section.

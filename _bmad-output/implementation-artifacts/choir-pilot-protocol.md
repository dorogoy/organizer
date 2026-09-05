---
status: active
decided: 2026-09-05
source: session "La dieta de las stories y el coro" + sprint-change-proposal-2026-09-05
applies-to: epic 5 (pilot)
---

# Choir Pilot Protocol — orchestrator and workers in Epic 5

## 1. Objective

Measure whether the choir — **GLM-5.3 orchestrating, GLM-5.3-flash cutting stone in Orca worktrees** — reduces credits per story at equal gate quality, against an inline twin running the ordinary single-agent loop.

Hypothesis (session canon, Mary's accounting): *move the interest out of the debt* — the large context is paid once by the orchestrator; each worker pays only its own trozo. Counterweight (John's alarm): *baratijas cortando piedra, diamante supervisando — and measure the director too*: orchestrating consumes tokens, so the orchestrator's credits are recorded separately, never hidden inside the story's total.

Standing rule the pilot may not break: *lo pequeño sigue mandando; el coro solo reparte las voces* — the story diet comes first; the choir only distributes the parts.

## 2. Topology

- **Orchestrator (GLM-5.3):** reads the story spec and the epics/architecture context it needs; plans the trozos; writes one brief per trozo; dispatches workers to Orca worktrees; integrates their branches; runs `make gate`; is accountable for the story's completion exactly as an inline agent would be.
- **Worker (GLM-5.3-flash):** one Orca worktree, one trozo, one brief, minimal context. Never reads the story spec. Never touches files outside the brief's scope. Reports in writing (§5).

## 3. The worker brief

Amelia's catch is accepted on the record: *the worker brief is a lean spec under another name*. It is small **by design and by law of the story diet** — the 24 KB gate governs story specs; briefs are governed here.

Fixed format, one page maximum:

1. **Goal** — the trozo in one paragraph, in the worker's terms.
2. **Files in scope** — the exhaustive list the worker may create/modify. Anything else is out of bounds; the worktree enforces, the brief states.
3. **Contracts to honour** — the specific AD/FR/NFR citations that bind this trozo, quoted, not referenced wholesale.
4. **Definition of done** — the tests that must exist or pass, named.
5. **What NOT to touch** — named files and behaviours that tempt but belong to another trozo.

The brief is written into the worktree before the worker starts (decision 4 of the session: every handoff leaves a document — zero memory rescues).

## 4. Dispatch and integration

1. Orchestrator plans trozos against the story's order constraints; a trozo never spans two stories.
2. One brief per trozo, one worker per brief, one worktree per worker. Parallel workers may run only when their file scopes are disjoint.
3. Worker finishes → written report → orchestrator reviews the diff against the brief → integrate → repeat for the next trozo.
4. After the last trozo: orchestrator runs the full completion gate inside devbox (`flutter test`, `dart format --set-exit-if-changed .`, `flutter analyze` — NFR17). Gate red = the story is not done, regardless of who wrote the red line.

## 5. The worker report

Always written, always in the worktree, never verbal:

- what was done, per file;
- test evidence (names, pass state);
- deviations from the brief, with reason;
- anything discovered that the orchestrator should know for the next trozo.

A stalled or exhausted worker leaves the report at the stall point; a new brief (not a memory rescue) resumes the trozo. This is the operational form of session decision 4.

## 6. Pilot designation — kind-matched pairs

| Pair | Choir | Inline twin | Kind |
|---|---|---|---|
| A | 5.4 scan cache + consent token | 5.10 invisible buffers | core substrate |
| B | 5.7 slice lands as steps | 5.13 gentle seasonal suggestion | core / parsing |
| C | 5.11 curation-row + Settings home | 5.12 the other two homes | leaf surface |

- **Wagon 0** (split `dispenser_screen.dart` view arms — action item `epic-4-retro-item-7`) is the orchestrator's **warm-up**: run it orchestrated, timed, but excluded from the comparison.
- **5.5 and 5.6 always run inline**: they are Dispenser-adjacent surfaces and stay high-collision until the view-arm split has settled.
- Remaining stories (5.1, 5.2, 5.3, 5.8, 5.9) run inline unless the pairs finish early and Sergio extends the pilot.

## 7. Measurement — the scoreboard

One row per measured story, kept in this file as stories complete:

| Story | Mode | Orchestrator credits | Worker credits (Σ) | Total credits | Wall time | Gate | Review findings |
|---|---|---|---|---|---|---|---|
| wagon 0 (warm-up) | choir | — | — | — | — | — | not counted |
| 5.4 | choir | | | | | | |
| 5.10 | inline | n/a | n/a | | | | |
| 5.7 | choir | | | | | | |
| 5.13 | inline | n/a | n/a | | | | |
| 5.11 | choir | | | | | | |
| 5.12 | inline | n/a | n/a | | | | |

Rules: credits are recorded per agent run as reported by the orchestration tooling; inline totals are the single agent's credits. Wall time is first-token-of-spec-read to gate-green. Review findings = defects found at code review (count and severity), so quality cannot silently degrade for cost.

## 8. Verdict

The scoreboard is read at the **Epic 5 retrospective** (retro per epic — Sergio's standing commitment). The verdict states, per pair and overall, whether the choir reduced total credits at equal quality, and recommends Epic 6's working mode. Epic 6's partition decision is taken **at its door**, with these numbers — just-in-time, per the session.

## 9. Scope guard

This protocol changes no architecture, no Makefile target and no completion gate. NFR17 remains the single story completion gate whoever executes the story. If any part of this protocol is found to conflict with `AGENTS.md` policy or the architecture spine, the spine and the policy win and this protocol is amended, not the reverse.

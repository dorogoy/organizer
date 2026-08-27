---
id: SPEC-organizer
companions:
  - ../../planning-artifacts/prds/prd-organizer-2026-08-20/prd.md
  - ../../planning-artifacts/prds/prd-organizer-2026-08-20/addendum.md
  - ../../planning-artifacts/ux-designs/ux-organizer-2026-08-21/EXPERIENCE.md
  - ../../planning-artifacts/ux-designs/ux-organizer-2026-08-21/DESIGN.md
  - ../../planning-artifacts/architecture/architecture-organizer-2026-08-26/ARCHITECTURE-SPINE.md
  - ../../../project-context.md
sources: []
---

> **Canonical contract.** This SPEC and the files in `companions:` are the complete, preservation-validated contract for what to build, test, and validate. Source documents listed in frontmatter are for traceability — consult them only if you need narrative rationale or prose color this contract intentionally omits.

# Anti-Overwhelm Mobile Task Organizer

## Why

Overwhelmed people need household and personal work converted into one small, achievable action without exposing a backlog or turning absence, variable energy, or spontaneous leisure into failure. This validation build must prove that an empathetic autopilot can sustain calm real-world use, reduce felt overwhelm, and advance a real Epic Project through short sessions rather than marathons.

## Capabilities

- **CAP-1**
  - **intent:** The user can receive exactly one suitable Micro-task at a time, complete it, defer it without guilt, reduce demand for low energy, simplify stuck work, and return after absence without debt.
  - **success:** The Dispenser demonstrates these paths without showing pending-work lists, overdue state, failure counters, missed days, or shaming copy.

- **CAP-2**
  - **intent:** The user can declare a flexible pocket of available time and pause, stop, or actively extend a session without surrendering control.
  - **success:** Dealt work fits the declared pocket, interruption preserves progress, rest is explicitly permitted, and the app never initiates or promotes continuation.

- **CAP-3**
  - **intent:** The system can derive and re-weave each day from Evergreen, Epic, and manual-origin work according to time, energy, precedence, cadence, and anti-marathon rules.
  - **success:** Given the same pool, event log, calendar day, and session facts, selection is deterministic; skips and absences require no stored plan, overdue state, or visible rescheduling.

- **CAP-4**
  - **intent:** The user can start with a useful pre-sliced Evergreen household programme spanning daily anchors, baseline upkeep, weekly zones, and monthly or seasonal work.
  - **success:** A fresh install composes a working day with no typing, network, key, account, or model, and the catalogue proves at least 28 distinct eligible 10–15 minute non-daily entries.

- **CAP-5**
  - **intent:** The user can capture one personal task by typed or on-device dictated text and choose one of three coarse sizes without creating a task-management backlog.
  - **success:** Capture completes on one surface, exposes no browsable or editable captured-task list, and the task is dealt FIFO within three eligible days ahead of same-size Evergreen or Epic work.

- **CAP-6**
  - **intent:** The user can turn a consented room photo or personal description into sequenced Micro-tasks through a swappable Smart Slicer.
  - **success:** Successful slicing yields usable 3–5 minute steps with origin and effort data; every unavailable, declined, abandoned, or refused path discards transient scan data and offers calm Manual Capture while local execution continues.

- **CAP-7**
  - **intent:** The user can approach organizing work through a purge-first flow with empathetic detachment questions, three equal destinations, quarantine follow-up, and liberated-space feedback.
  - **success:** Organizing Epics deal purge work first, all three destinations have equal interaction and visual weight, and quarantine follow-up never claims knowledge the app does not have.

- **CAP-8**
  - **intent:** The user can see progress through private before/after comparisons, a local Transformation Album, and cumulative impact.
  - **success:** Progress is demonstrable and deletable without streaks, debt, throughput pressure, negative framing, or app-initiated sharing.

- **CAP-9**
  - **intent:** The user can opt into one ambient daily invitation that opens a path to action without recalling pending work.
  - **success:** The notification is silent, content-free, non-urgent, limited to one per day, and structurally unable to escalate through another channel or category.

- **CAP-10**
  - **intent:** The user can retain control of local data while selectively using a cloud Slicer and preserving a restorable personal record.
  - **success:** Each photo upload requires single-use consent after on-device person detection; credentials never enter domain state or export; the app has no developer-held data or unapproved egress; export and import round-trip all authoritative state and album bytes.

- **CAP-11**
  - **intent:** The builder can evaluate sustained use, felt overwhelm, Epic progress, and adoption of the photo-to-plan loop without turning measurement into user pressure.
  - **success:** A four-week local export supports SM-1 through SM-4 and SM-C1 through SM-C3 while the Dispenser exposes no validator-only metrics or export state.

## Constraints

- The validation build is a single-user Android app: local-first, backend-free, Flutter 3.47 and Dart 3.13, with a pure-Dart functional core and an imperative Flutter/adapters shell.
- Zero cognitive load and uncompromising anti-shaming govern every surface: no pending-work list, overdue state, streak, undone count, failure framing, or app-led pressure to continue. Only PRD exceptions E1 and E2 may bend the one-action/no-list rule, and only at genesis and Evergreen cluster selection.
- The task pool and event log are immutable, insert-only facts; plans, sessions, settings, eligibility, counters, targets, and validation signals are deterministic derivations under the Architecture Spine.
- Network egress is sealed to the three Smart Slicer payload shapes. No analytics, crash-reporting, remote-config, feature-flag, or other network SDK may enter the app.
- Every scan requires per-scan consent after on-device person detection. Scan files die on every terminal path; voice audio is never stored, exported, or transmitted.
- BYOK is the only usable release Slicer path. Providers are compile-time allowlisted by dated written no-training terms; credentials are non-exportable; no account, proxy, or developer key custody exists.
- Product UI copy is Spanish-first, externally auditable, non-concatenated, and subject to the UX anti-shaming rules; keyboard-free operation is required for user-facing writing surfaces, while Settings may require typing.
- A story is done only when `flutter test`, `dart format --set-exit-if-changed .`, and `flutter analyze` all pass.

## Non-goals

- Multi-user households, sharing, delegation, coordination, or merged validation data.
- iOS, web, desktop, backend accounts, developer-hosted sync, or developer-held user data.
- A production Local Slicer, the Managed access path, proxy infrastructure, billing, or subscription monetization.
- GTD-style task lists, backlog browsing, post-capture editing, tags, filters, folders, kanban, calendar writes, deadlines, time-blocking, or clock-bound tasks.
- Streaks, badges, levels, social comparison, urgency, repeated reminders, automatic sharing, or any mechanism that represents absence as failure.

## Success signal

Across four consecutive weeks, Sergio uses the app on at least five days per week, reports at least a one-point reduction in household overwhelm, and reaches a visible milestone in a real Epic Project without app-initiated continuation. The photo loop is exercised at least weekly and produces before/after evidence for at least half of completed project milestones, while guilt events remain zero, notifications never exceed one silent invitation per day, and usage is not purchased through longer or more numerous sessions.

## Assumptions

- This is the living evergreen contract for the project, while its current delivery boundary remains the four-week validation build; future scope changes append to `.memlog.md` and preserve capability IDs.
- The source assumptions retained in the PRD remain live until validation evidence or an explicit decision supersedes them.

## Open Questions

- Does Gemma 4 E4B produce usable 3–5 minute slices from real clutter photos on the validation handset, or should the BYOK cloud path remain primary?
- Should Manual Capture accept non-spatial or date-bearing work, and what copy explains the boundary without shaming the user?
- Before each affected surface is implemented, which unresolved UX decisions in `EXPERIENCE.md` must be closed, including required copy, onboarding, Settings IA, accessibility, permission denial, theme selection, and before/after presentation?

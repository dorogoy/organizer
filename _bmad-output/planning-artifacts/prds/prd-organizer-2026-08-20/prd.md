---
title: Anti-Overwhelm Mobile Task Organizer
status: final
created: 2026-08-20
updated: 2026-08-26
---

# PRD: Anti-Overwhelm Mobile Task Organizer
*Working title, confirmed 2026-08-20 for the validation build; product naming deferred.*

## 0. Document Purpose

This PRD specifies the validation build of the Anti-Overwhelm Mobile Task Organizer: a single-user Android app that turns household and personal chores into one micro-action at a time, distributed across days, with zero guilt mechanics. Audience: the builder (PM + implementer) and downstream BMad workflows (`bmad-ux`, `bmad-architecture`, `bmad-create-epics-and-stories`). It builds on the brainstorming session `brainstorm-app-tareas-sin-agobio-2026-08-20` (authoritative intent document) and does not duplicate it; competitive-landscape detail and technology options live in `addendum.md`. Vocabulary is Glossary-anchored; §10 is the single record of confirmed parameters and remaining assumptions — no inline assumption tags remain in the body.

**Revision 2026-08-21.** Task genesis and AI access were separated into two independent axes after an elicitation pass found the "works without AI" claim false: nothing created tasks without the Slicer, so a fresh install had nothing to dispense and every template fallback fell back onto nothing. Manual Capture (§4.9) is now the permanent floor, the AI Access Path (§4.10) is explicit, and the validation build ships BYOK only — no account, no login, no proxy, no developer-held data. §5, §7, §8, §9 and §10 carry the consequences; rationale in addendum A9.

**Revision 2026-08-23.** The Evergreen material widened from five zone templates plus five 30-second anchors into a full pre-sliced catalogue across three cadences — daily anchors and Baseline Upkeep, weekly zone routines, monthly/seasonal upkeep — specified by FR-31 (§4.11) and authored in addendum A12 rather than deferred. Two rulings paid for it: clock-bound work stays out of the catalogue entirely, and Baseline Upkeep sits outside the Time Bag, which from now on budgets advance work only. §3, FR-7, FR-11, FR-12, §5.2, §6, §7, §9 and §10 carry the consequences; rationale in addendum A11.

**Revision 2026-08-26.** Voice arrived as an input method for Manual Capture — dictation into FR-27's single line, recognised on-device, specified by FR-32 (§4.9). Three boundaries keep it from becoming something else: it replaces the keyboard rather than adding capability, so §5.1's deferred voice-first slicer is untouched; recognition is on-device only, so FR-27's no-network floor and §7's egress map survive unchanged; and the transcript lands in the existing capture field rather than a confirmation screen, which is what keeps a mis-heard line correctable under §4.9's leave-and-it-is-gone rule. §2.1, UJ-5, §5.1, §6, §7, §9 and §10 carry the consequences; rationale in addendum A13.

**Revision 2026-08-26 (UX session `ux-organizer-2026-08-21`).** Three decisions taken in the UX session are carried upstream rather than left to diverge silently. The third destination of the 3-Destination Flow is labelled `Tirar o soltar` in the UI — *soltar* rather than *reciclar*, because the third choice must not read as the bad one — while `Trash-Recycle` stays the internal concept name for what that destination covers (§3, FR-20). And principle 1 acquires its first two declared exceptions, registered in §1.1 instead of absorbed: the Archetype Template selection surface shows a list (E1), and task genesis is multi-path — the photo path an invitation, manual entry always available beside it (E2), which is also what reconciles FR-11's several genesis paths with principle 1's cap. Neither exception touches §5.2's exclusion of a task list in any form. §1.1, §3, FR-11, FR-20 and FR-31 carry the consequences; rationale in that session's `DESIGN.md` and `EXPERIENCE.md`.

## 1. Vision

Traditional task managers fail overwhelmed users psychologically: endless lists, red overdue badges, broken streaks, and rigid time blocks turn productivity into shame. This app is the opposite — an **empathetic autopilot and cognitive shock absorber**. It tells the user exactly which single small action to do right now, absorbs guilt when life happens, and guarantees steady progress on big chores by distributing them as micro-actions across days.

The engine combines FlyLady zone cleaning with the 1-3-5 rule, automatically weaving tasks from recurring routines and dormant epic projects (storage room, seasonal closet switch) into a modest daily time budget. A "Floating Time Bag" replaces rigid scheduling: the user commits minutes-per-day, not hours-on-the-clock, and triggers a session whenever a pocket of free time appears. AI photo-diagnosis makes setup effortless — snap a picture of the messy space and the app returns a precise sequence of 3–5 minute micro-steps, later rewarded with a before/after visual diff.

The differentiating loop — photo → micro-plan → visual reward — rests on multimodal vision being accurate enough to slice real clutter at a price worth paying per scan. Open Question 1 settles it, against the cost target in the addendum. This build validates the concept with the builder as the primary user: **success is sustained real usage, a felt reduction in overwhelm, and visible progress on a real epic project — without marathons.**

### 1.1 Principles (invariants)

These govern decisions the FRs did not anticipate. Where an FR and a principle conflict, the principle wins and the FR is wrong.

1. **Zero cognitive load.** The user never chooses from a list. Any new surface offers at most one recommended action plus a way out.
2. **Uncompromising anti-shaming.** No red, no overdue, no streak, no count of anything undone. If a feature needs to represent failure or absence to work, it does not ship.
3. **Respect for spontaneity and variable energy.** Every plan is regenerable. Nothing the user does away from the app can invalidate it, and leisure is never a cost.
4. **Invisible buffers.** Slack is never shown, never configurable, never spendable by the user — a visible buffer is a deadline with extra steps.
5. **Anti-marathon.** The app never encourages more than it asked for. No "keep going" is ever a primary action. And no walls: the app guides, the user decides — session length included. Extending a session is always the user's active act; the app never asks "shall we continue?", because a question that appears after every session exhausts as much as a nag.
6. **The Slicer authors everything personal.** Evergreen material — the whole shipped Library: daily anchors, Baseline Upkeep, the FlyLady zones and the seasonal upkeep (FR-31) — is product content: sliced at build time and shipped, identical for every user because the methodology is published, needing no network, key, model or first-run cost. Everything specific to *this* user's home and life comes from the Slicer: Epic Projects, photo slicing, re-slicing. Without a reachable Slicer there is no personal slicing — what remains is the shipped Evergreen day, Manual Capture (§4.9) as the floor, and the dispensing of what already exists. An offline app executes; it does not beget. And Manual Capture never grows into a task manager — the moment it acquires a list, this principle has been violated by whoever added the list.

**Declared exceptions to principle 1 (UX session `ux-organizer-2026-08-21`).** Principle 1 is amended in exactly two named places, both of them the builder's explicit decisions in that session, and neither clause is weakened anywhere else. They are registered here rather than absorbed at the surface that needed them, because an invariant that overrides FRs cannot be bent without the bend being written down. An exception exists only where this register names it: nothing further is implied by silence, and no other surface may borrow either of these.

- **E1 — the Archetype Template selection surface shows a list.** An exception to *"the user never chooses from a list"*. It is a complement offered from the manual-entry screen of project genesis — a help, not a primary path — and that is what pays for the list; the clause itself stands and still governs every other surface. **This does not touch §5.2's exclusion of a task list in any form.** Archetype Templates are product content; captured tasks are not. No screen gains the power to enumerate captured tasks, edit them, or let the user browse what is pending — that exclusion stands entire, and a later reader must not read E1 as a crack in it. Consequences: FR-11, FR-31.
- **E2 — the genesis zone carries one recommended action and more than one way out.** An exception to *"at most one recommended action plus a way out"*. Task genesis is multi-path by decision: the photo path is an invitation and never a gate — *"no podemos obligar a la gente a que use el sistema de fotos si no quiere"* — manual entry is always available beside it, and E1's template list opens from that manual-entry screen rather than as a third top-level path. This also **reconciles a tension the document already carried**: FR-11 has always mandated more than one genesis path while principle 1 capped them, and the two were never squared. They are squared by declaring the exception, not by cutting FR-11. Consequences: FR-11.

## 2. Target User

### 2.1 Jobs To Be Done

- **Emotional:** "When I feel overwhelmed by chores, I want an invisible autopilot that absorbs my guilt and tells me the one small thing to do now — not a manager cracking a whip over a backlog."
- **Functional:** Free up personal time and avoid whole-day marathon chores by fragmenting them into micro-steps spread across days within a committed daily budget.
- **Functional:** Capture a messy space (photo) and get an accurate, effort-estimated micro-plan without typing or categorizing. The photo is the path that needs no *words* at all; Manual Capture (§4.9) needs one line, dictated or typed (FR-32), and stays a floor for what the app cannot see rather than the main road. Neither path requires a keyboard, and that is deliberate: the keyboard is the thing this product's users are worst at.
- **Social:** Protect and celebrate spontaneous leisure (an unplanned cinema trip) without penalty or judgment.
- **Contextual:** On low-energy days, still do something tiny and feel progress; defer the rest silently.

### 2.2 Non-Users (v1)

- Couples/families needing shared or delegated chores (multi-user sync is a non-goal for v1).
- Power users wanting GTD density: projects hierarchies, tags, filters, kanban, calendar writes. Manual Capture (§4.9) is the one entrance they could write into and it is deliberately crippled — no list, no editing, no browsing — precisely so this group stays a non-user. Voice (FR-32) does not soften that: it makes the one line cheaper to produce and leaves every missing affordance missing.
- Anyone wanting strict hourly time-blocking or deadline-driven reminders.

### 2.3 Key User Journeys

- **UJ-1. Sergio spends a 15-minute pocket on the storage room.**
  Sergio, builder and primary validation user, finishes lunch with 15 free minutes. He opens the app straight into the Dispenser, taps "Tengo 15 minutos ahora", and the app immediately deals one Focus Chunk micro-task from his active Epic Project: *"Storage room: box the books on the left shelf (≈10 min)"*. He does it, taps **Hecho**, gets a subtle haptic buzz and warm confirmation, and is offered one 2-minute micro-maintenance task from the active weekly zone. Timer hits 15: the app shows explicit permission to stop. He closes the app feeling ahead, not behind.

- **UJ-2. Sergio photographs the trastero and gets a micro-plan.**
  Standing at the storage room door, Sergio taps the Scan surface and shoots one photo of the mess. The AI Smart Slicer returns 6 micro-steps of 3–5 minutes with per-step effort tags ("sorted into a structured sequence"). He accepts, the app creates the Epic Project with an Invisible Buffer spreading steps across ~5 days at his daily budget. Before step 1, the Decluttering Protocol injects a pre-clean purge micro-step. **Edge case:** the Slicer is unreachable — no network on the BYOK path, invalid or exhausted key, provider down → the app states the cause plainly and offers Manual Capture (FR-29). No template stands in for the trastero — Evergreen zones ship pre-sliced, but an Epic Project is personal and only the Slicer authors it (FR-11) — and the photo is not queued for a later upload: he shoots it again when the Slicer is back, because a silent pending upload would break per-scan consent (FR-25).

- **UJ-3. Sergio returns after six days away.**
  After a work trip plus a spontaneous weekend away, Sergio reopens the app expecting guilt. Instead: a warm welcome-back screen, a silently rebalanced plan, and the same single micro-task dispenser as always — no overdue list, no red, no streak shaming. The six missed days simply folded into the Invisible Buffer; his epic target date quietly absorbed them.

- **UJ-4. Sergio on a low-battery Sunday.**
  Sergio taps the 1-tap energy check-in: 🔴 Low Battery. The Dispenser instantly re-filters to instant habits and 30-second micro-actions; the planned Focus Chunk disappears without comment. Later he skips a task three times in a row; instead of nagging, the app contracts it into a 30-Second Rescue micro-step: *"Just pick up 3 items off the floor."* He does it, which counts.

- **UJ-5. Sergio anota algo a mano en diez segundos.**
  Something occurs to Sergio that the app cannot know and no photo can reveal: he promised to water the neighbour's plants on Thursday. He taps Manual Capture from the Dispenser, holds the microphone and says it out loud — *"regar las plantas de la vecina el jueves"* — the words land in the line, he picks "3 min" from three sizes, and it is out of his head. No project, no category, no date, no confirmation screen. Had the recognition heard *la vecina* as *la vitrina*, he would have fixed it right there on the capture surface, because that is the last moment it can be fixed (FR-32). Days later it surfaces as an ordinary dealt card, indistinguishable from a sliced one. He never sees a list of what he has captured, because there is no list. On the day his API key expires, this is the only path still working — and the app keeps being useful without saying a word about it.

## 3. Glossary

- **Micro-task** — The atomic unit of work: 30 seconds to 15 minutes, always with a duration estimate. Served one at a time by the Dispenser. (The intent document capped micro-actions at 10 min; widened deliberately so a Focus Chunk fits at the top of the range without a second unit.)
- **Dispenser (Single-Task Dispenser)** — The primary UI surface: exactly one Micro-task card with Done / Skip actions. No lists, no calendars.
- **Focus Chunk** — The "1" of the 1-3-5 composition: a 10–15 min Micro-task drawn from the active Epic Project or active weekly zone.
- **Micro-maintenance** — The "3" of the 1-3-5 composition: 2–3 min recurring upkeep tasks across common areas.
- **Instant Habit** — The "5" of the 1-3-5 composition: ~30 s daily anchors (wipe sink, ventilate, drink water).
- **Floating Time Bag** — The daily flexible minutes quota the user commits to, spent on demand instead of fixed appointments. It budgets **advance** work — the Focus Chunk drawn from an Epic Project or the active zone — and not Baseline Upkeep, which the day already contains (FR-12). Values: §10.1.
- **Energy Level** — 1-tap capacity state: 🟢 High / 🟡 Medium / 🔴 Low. Filters the eligible Micro-task pool.
- **Rescue Mode** — Unsticking of a stuck or user-flagged Micro-task by re-slicing it into 2–4 steps of ≤ 60 s each, via its Origin Context. Triggers: dealt-and-declined on 3 different days (soft heuristic) or user request at any time.
- **Anti-Marathon Checkpoint** — The scheduled rest offer inside every session (default 15 min): explicit permission to stop, never a wall — continuing past it is exclusively the user's active choice. Values: §10.1.
- **FlyLady Zone** — One of the rotating weekly household areas (kitchen, bathrooms, …) with pre-configured routine Micro-tasks. Cardinality: exactly one active zone per day.
- **Archetype Template** — A pre-configured zone or project starter (zero blank page), of two kinds, and the distinction is load-bearing. **Evergreen templates** — the Evergreen Library: daily anchors, Baseline Upkeep, the 5 FlyLady zones and monthly/seasonal upkeep (FR-31) — ship as *pre-sliced Micro-tasks*: product content authored at build time, identical for every user because FlyLady is a published methodology, working with no network and no key. **Epic seeds** are structured *input* the Slicer turns into Micro-tasks, never pre-sliced content, because an Epic Project is specific to this user's home. A template never stands in for the Slicer on personal material (FR-11, FR-29).
- **Evergreen Project** — High-frequency recurring project: daily anchors, weekly zones, monthly upkeep. Always active.
- **Evergreen Library** — The catalogue of pre-sliced Evergreen Micro-tasks that ships in the build, spanning three cadences and carrying size, cadence and zone on every entry. Breadth requirement: FR-31. Content: addendum A12.
- **Baseline Upkeep** — Recurring daily household work the user does with or without the app: wash the dishes, set and clear the table, empty the dishwasher, close the kitchen. Part of the Evergreen Library, dispensed like anything else, and deliberately not charged to the Time Bag (FR-12). Distinct from Instant Habits by size, not by kind: upkeep runs 3–15 min, an anchor runs 30 s.
- **Epic Project** — Low-frequency/seasonal project (organize storage room, wash curtains, closet switch). Dormant by default; activated on demand or by seasonal suggestion.
- **Project Weaver** — The engine that composes each day's 1-3-5 budget by weaving Micro-tasks from active Evergreen and Epic Projects. The user never browses folders.
- **Invisible Buffer** — Background temporal slack added to Epic Project targets so deferrals and absences are absorbed without moving visible deadlines.
- **Silent Rescheduler** — The mechanism that rebalances unfinished Micro-tasks into future days without overdue states, notifications of failure, or user-visible debt.
- **Photo-Diagnosis** — Cloud AI analysis of a space photo: clutter detection, object classification, micro-step generation with effort estimation (the Smart Slicer).
- **Smart Slicer** — The component that converts an input (photo, text, form, or template seed) into a sequence of 3–5 min Micro-tasks with per-step duration tags. Reached through any AI Access Path behind one interface, so the path is swappable without touching anything else.
- **Manual Capture** — The floor of task genesis: the user writes one Micro-task — typed, or dictated on-device (FR-32) — and picks its size from three options that are the 1-3-5 taxonomy (30 s / 3 min / 10–15 min). Available always, with or without AI, network, key or account. Never a list, never browsable, never editable once left. Details: FR-27, FR-32.
- **AI Access Path** — How the app reaches a Slicer: **Local** (on-device model, no account, no egress), **BYOK** (the user's own key against a vetted provider), or **Managed** (developer-run proxy behind login/password, paid in non-expiring credits). The validation build implements BYOK only. Details: FR-28, §5.1.
- **Origin Context** — The retained structured description of a task's source — photo-diagnosis output, form data, free text, or template — kept when the raw input is discarded, and reused to re-slice or regenerate tasks without re-capturing input. Tasks never come from nothing: they come from information the user provided. A Manual Capture's Origin Context is its own single line and nothing more — enough for FR-5 to re-slice it when a Slicer is reachable, and nothing at all when none is.
- **Before/After Reward** — Visual diff between the initial clutter photo and the post-completion state, saved to the Transformation Album.
- **Transformation Album** — Local, private gallery of Before/After pairs and progress milestones.
- **Decluttering Protocol** — Pre-clean purge sequence injected before organizing projects: detachment questions, 3-Destination Flow, Quarantine Box.
- **3-Destination Flow** — Item triage: Keep / Donate-Sell / Trash-Recycle. Those are internal concept names — never shown, like Instant Habit, Micro-maintenance and Focus Chunk; the surfaced Spanish labels are `Quedármelo` / `Donar o vender` / `Tirar o soltar` (UX session `ux-organizer-2026-08-21`). The third label says *soltar* and not *reciclar* deliberately: it avoids both the deletion vocabulary of a bin and the compliance vocabulary of recycling arrows, and the equal weight of the trio depends on the third choice not reading as the bad one. `Trash-Recycle` stays accurate for what that destination *covers* — discarding and recycling as one destination — which is why the concept keeps its name while the label changes.
- **Quarantine Box** — Dated physical box for emotionally hesitated items; if untouched after 6 months, the app gently suggests donation.
- **Warm Return** — The welcome-back state after an absence: clean reset, rebalanced plan, no backlog display. Threshold: §10.1.
- **Ambient Invitation** — The single optional daily notification: a silent, content-free invitation at a user-chosen hour. Carries no task, no count, no reference to anything pending. Distinct from a reminder: it invites, it does not recall a debt.

## 4. Features

| FR | Requirement | Feature |
|---|---|---|
| 1–6 | Single card, Done, guilt-free Skip, energy check-in, Rescue Mode, Warm Return | 4.1 Dispenser |
| 7–10 | Time Bag, "I have X minutes", pause and silent recalc, Anti-Marathon checkpoint | 4.2 Time Bag & Session |
| 11–15 | Dual lifecycle, 1-3-5 weaving, Invisible Buffers, Silent Rescheduler, seasonal activation | 4.3 Project Weaver |
| 16–18 | Photo scan and Smart Slicer, Before/After reward, local Album | 4.4 Photo-Diagnosis |
| 19–22 | Purge injection, detachment questions, Quarantine Box, declutter metric | 4.5 Decluttering Protocol |
| 23 | Cumulative impact dashboard, snowball suggestion | 4.6 Progress |
| 24 | One silent daily invitation | 4.7 Ambient Invitation |
| 25–26, 30 | Per-scan consent and upload minimization, local instrumentation, silent automatic export | 4.8 Data Handling |
| 27, 32 | Manual Capture floor: one task, three sizes, no list; voice dictation into the line | 4.9 Manual Capture |
| 28–29 | AI Access Path, vetted-provider allowlist, honest degradation with no Slicer | 4.10 AI Access |
| 31 | Pre-sliced Evergreen catalogue across three cadences, curated by cluster | 4.11 Evergreen Task Library |

FR IDs are stable identifiers, not an ordering: features are grouped where they belong conceptually, so a later addition keeps its number rather than renumbering the document. FR-30 sits in 4.8 for that reason.


### 4.1 Single-Task Dispenser (UI kernel)

**Description:** The app's home and default surface. Shows exactly one Micro-task card with its duration estimate and two actions: **Hecho** (Done) and **"Otra más fácil / Ahora no"** (Skip). No lists, no calendar, no backlog anywhere in the primary surface. Completing a task triggers subtle positive feedback (a haptic buzz and warm copy) and advances to the next dealt Micro-task. Realizes UJ-1, UJ-3, UJ-4.

**Functional Requirements:**

#### FR-1: Single-card viewport
The user sees exactly one dispensed Micro-task with duration estimate at the Dispenser surface. Realizes UJ-1.

**Consequences (testable):**
- No screen reachable in under 3 taps from the Dispenser ever renders more than one actionable Micro-task at once.
- Every dealt card displays its estimated duration.

#### FR-2: Done action with positive feedback
The user can complete the dealt Micro-task with one tap, receiving non-intrusive positive feedback and the next card. Realizes UJ-1.

**Consequences (testable):**
- Completion advances the queue in under 500 ms.
- Feedback is never modal, never plays loud audio, and never spawns a rating prompt or a nag screen.

#### FR-3: Guilt-free skip
The user can skip the dealt Micro-task with one tap; the Dispenser deals an alternative without recording failure.

**Consequences (testable):**
- Skips produce no overdue state, no counter, and no notification.
- The alternative respects current Energy Level and remaining Time Bag budget.

#### FR-4: 1-tap energy check-in
The user can set Energy Level (🟢🟡🔴) in one tap; the eligible Micro-task pool filters immediately. Realizes UJ-4.

**Consequences (testable):**
- On 🔴, Focus Chunks are excluded from the pool; only Instant Habits and ≤60 s Micro-tasks remain.
- Pool re-filters in under 500 ms after the tap.

#### FR-5: Rescue Mode (task unsticking)
A stuck Micro-task is unblocked by re-slicing it into much simpler steps. Two triggers: (a) automatic heuristic — the same Micro-task is dealt and declined on 3 different calendar days, a soft signal to attempt unsticking, not a rigid rule (days of absence, days the task was not dealt, or energy filtering neither increment nor reset the count); (b) user-initiated — the user asks to simplify the dealt Micro-task at any time, without waiting for any counter. Realizes UJ-4. Heuristic threshold confirmed 2026-08-20; user-initiated path added same date.

**Consequences (testable):**
- On trigger, the system requests a re-slice from the Slicer through the FR-28 access path, using the task's Origin Context — no new photo is taken or re-processed.
- The re-slice returns 2–4 simpler steps, each ≤ 60 s; steps enter the queue one at a time, woven by the Project Weaver, tonally indistinguishable from any other Micro-task.
- Completing all rescue steps marks the original Micro-task done; activating the rescue resets the refusal counter (no cumulative skip totals exist — FR-26).
- Rescue depth is capped at 1: a rescue step can never itself be rescued.
- A rescue with no reachable Slicer degrades per FR-29: the original task stays dealable as-is, nothing is queued, and no error state appears. A manually captured task with no Slicer at all cannot be rescued, which is stated plainly at the moment of asking and never as a failure.

#### FR-6: Warm Return
After ≥48 h of absence, the user is received with a warm reset: rebalanced plan, no backlog, no reference to missed days in any UI element or copy. Realizes UJ-3. Threshold: 48 h (confirmed 2026-08-20).

**Consequences (testable):**
- No "you missed N days" copy, overdue badge, or broken-streak indicator exists in the entire app.
- After absence, first dispensed card comes from the silently rebalanced plan.

### 4.2 Floating Time Bag & Session Control

**Description:** Flexible daily time commitment with an ad-hoc session trigger and an anti-marathon rest checkpoint. The user commits minutes per day, not schedule slots; sessions start when a real pocket of time appears; interruptions save progress silently. Realizes UJ-1.

**Functional Requirements:**

#### FR-7: Daily floating time budget
The user can set a daily Time Bag of 5–30 minutes (default 15). Range and default confirmed 2026-08-20.

**Consequences (testable):**
- Budget persists until changed; changing it mid-day never invalidates completed work.
- The 1-3-5 composition adapts to the current budget (see FR-12).
- The budget covers **advance** work only — the Focus Chunk. Baseline Upkeep and Instant Habits are not charged to it (FR-12, revised 2026-08-23): they happen with or without the app, and a budget that pays for the dishes leaves nothing for the Epic Project SM-3 measures.

#### FR-8: "I have X minutes now" trigger
The user can start an ad-hoc session declaring available minutes; the Dispenser deals Micro-tasks fitting that pocket.

**Consequences (testable):**
- Dealt tasks' estimated durations sum to ≤ the declared pocket.
- The session runs to the declared pocket; the Anti-Marathon Checkpoint (FR-10) is a rest offer along the way, never an end.

#### FR-9: Pause and silent recalculation
The user can interrupt a session at any moment; partial progress is saved and remaining minutes roll back into the Time Bag without penalty states.

**Consequences (testable):**
- No interrupted, incomplete, or overdue state is ever displayed anywhere — in either language.
- Resuming deals the next Micro-task directly — never a resume menu about the past.

#### FR-10: Anti-Marathon checkpoint
Every session reaches a rest checkpoint (default 15 min, configurable 10–15) with an explicit permission-to-stop screen. The checkpoint is a rest offer, not a wall: continuing past it is exclusively a user-initiated action. Reworked 2026-08-20, superseding the same-day hard-cap ruling: the app guides, the user decides — session length included.

**Consequences (testable):**
- At the checkpoint the current Micro-task can be finished; the permission-to-rest screen is the primary surface.
- No continuation question exists anywhere in the app — a recurring "¿seguimos?" is a nag in interrogative form. Extending is an available, silent, secondary action the user takes; the app never highlights, animates, or suggests it.
- The session runs to the user's declared length; the user may extend it actively at the end via the same silent action.
- Stopping is always one tap (FR-9), at any moment, for any reason.

### 4.3 Project Weaver — FlyLady + 1-3-5 Hybrid Engine

**Description:** Dual-lifecycle project structure (Evergreen + Epic) automatically woven into each day's 1-3-5 composition. The Evergreen material it weaves is the shipped library specified in §4.11; Epic material comes only from the Slicer. Epic Projects carry Invisible Buffers; deferrals and absences are absorbed by the Silent Rescheduler; dormant Epics may be gently suggested by seasonal triggers. The user never manages folders or triages categories. Realizes UJ-1, UJ-2, UJ-3.

**Functional Requirements:**

#### FR-11: Dual-lifecycle projects with archetype templates
The user can instantiate Evergreen Projects from the pre-sliced Evergreen Library (daily anchors, Baseline Upkeep, 5 FlyLady zones, monthly/seasonal upkeep — FR-31), and create Epic Projects from a photo or from a typed/form description — the latter always through the Slicer, never from a template.

**Consequences (testable):**
- Fresh install reaches a working 1-3-5 day with zero typing, zero network, zero key and zero model: the whole Evergreen Library ships pre-sliced (FR-31, addendum A12). This is product content, honestly labelled as such, not a Slicer substitute.
- No Epic Project is ever created from a template. Epic material always comes from the Slicer, from input the user supplied (FR-16, FR-28).
- With no Slicer reachable the Evergreen day works and Epic Projects cannot be created; the app names which is which plainly rather than implying the whole product is degraded (FR-29).
- Exactly one FlyLady Zone is active per day, rotating weekly.
- Epic Projects are dormant until activated and do not appear in any default view while dormant.
- Genesis is multi-path, and the photo is an invitation rather than a gate: the photo path is the recommended action, typed/form entry sits beside it and is always available, and neither is a precondition for the other. Reaching manual entry costs one tap and asks for no reason (§1.1 exception E2, UX session `ux-organizer-2026-08-21`).
- The Archetype Template selection surface enumerates templates, and opens from that manual-entry screen as a complement — never as a third top-level genesis path (§1.1 exception E1, same session). Selecting a template instantiates an Evergreen Project only; it never creates an Epic Project, which this list's "no Epic Project is ever created from a template" consequence forbids.

#### FR-12: Automatic 1-3-5 weaving
The system composes each day's queue as 1 Focus Chunk (10–15 min, from the active Epic Project or active zone) + 3 Micro-maintenance tasks + 5 Instant Habits, scaled to the current Time Bag and Energy Level.

**Consequences (testable):**
- Composition respects the budget on advance work: the Focus Chunk's estimated duration is ≤ the Time Bag. Baseline Upkeep and Instant Habits are composed alongside it and are not charged to the budget — they are work the day already contains, and the app's job there is ordering it, not rationing it (revised 2026-08-23).
- The Focus Chunk slot is **reserved for advance work** — the active Epic Project or the active zone — and Baseline Upkeep never occupies it, however well its size fits. Upkeep fills the "3" and may add at most one 10–15 min item per day (lavar los platos, dejar la cocina cerrada). Without that reservation the dishes would take the Epic's slot on their size alone, and SM-3 would stop being measurable.
- Anti-marathon is enforced by the session, never by the budget: everything dealt inside one session — upkeep included — still sums to ≤ the declared pocket (FR-8). An unbudgeted class of tasks can therefore never produce an unbounded session.
- The canonical 1-3-5 sums to roughly 26 min (≈15 + 9 + 2.5) and always exceeded the 15-minute default Time Bag; the split above is what makes "scaled to the current Time Bag" mean something rather than hide the arithmetic. Scaling drops upkeep and habits by count, never by shrinking a Micro-task's own estimate.
- Composition is regenerable (not fixed): skipping one element re-weaves the rest, never "fails the day".
- Manually captured tasks (FR-27) take precedence over Evergreen and Epic material of the same size, and are dealt within 3 days of capture (§10.1). This is the only privilege Manual Capture has, and it exists because a capture that can sit undealt for a week teaches the user not to trust the capture — and a capture surface nobody trusts gets used twice, once here and once in a notes app.
- The composition records the origin mix it produced (FR-26), so Time Bag overruns can be read against the share of self-estimated durations instead of being blamed on the budget.

#### FR-13: Invisible safety buffers
The system spreads Epic Project steps across days with built-in temporal slack so targets survive deferrals and absences silently.

**Consequences (testable):**
- Epic target dates displayed to the user always include slack the user cannot see or configure.
- N days of total absence (test: 7) do not push any Epic milestone into an overdue state; the target silently rebalances.

#### FR-14: Silent rescheduler
Unfinished Micro-tasks are automatically re-woven into future days by the Silent Rescheduler without user action, failure records, or notifications.

**Consequences (testable):**
- There is no concept of "overdue" anywhere in the data model surfaced to the UI.
- Deferral of a Focus Chunk reschedules it within the Invisible Buffer window without changing any visible target.

#### FR-15: Gentle seasonal activation
The system may suggest activating a dormant Epic Project on seasonal triggers (e.g., closet switch in spring), proposing a minutes/day plan.

**Consequences (testable):**
- Suggestions are dismissible in one tap and never repeat more than once per season per project.
- Declining a suggestion has zero side effects on any metric, streak, or plan.

### 4.4 AI Photo-Diagnosis & Visual Rewards

**Description:** Cloud multimodal vision analysis that turns a photo of a messy space into a structured micro-plan, plus the before/after reward loop. Included in the validation build per decision (2026-08-20): photo slicing is the differentiating hook. **Acknowledged deviation:** the intent document justified the mobile form factor partly on local, on-device image processing; this build assumed cloud slicing instead, because on-device vision models were judged unlikely to slice clutter well enough to validate the hook. Per OQ1's ruling (2026-08-20) the topology is deliberately open, and as of 2026-08-21 the local candidate is concrete rather than hypothetical: Gemma 4 (released 2026-04-02) ships E2B/E4B variants with native multimodal image input and official Android support. Existence is settled; quality is not — whether E4B slices real clutter photos into usable 3–5 min steps is an empirical question OQ1 still owns. The validation build therefore implements the cloud path via BYOK (FR-28) and treats on-device as the preferred ideal to test in parallel. FR-25 is written for the cloud worst case; any fully local path satisfies it trivially, and it states the price of the reversal instead of assuming it away. Realizes UJ-2.

**Functional Requirements:**

#### FR-16: Space photo scan with Smart Slicer
The user can photograph a space and receive a sequence of 3–5 min Micro-tasks with per-step effort estimates derived from clutter analysis.

**Consequences (testable):**
- No latency cap: scan time is not a determining factor (OQ1 ruling, 2026-08-20). The wait happens in-app with visible progress and honest copy; if completion is asynchronous, it is announced only inside the app — never via a second notification category (FR-24, §5.2).
- Each generated step carries a duration tag between 3 and 5 minutes.
- If analysis fails (no network, invalid or exhausted key, provider down, cap), the app states the cause plainly and offers Manual Capture (FR-29) — never an error dead-end, and never a template dressed up as a plan. Realizes UJ-2 edge case.
- The Slicer's structured description of the analyzed space (Origin Context) is retained for future re-slicing (FR-5); the image itself is discarded per FR-25.

#### FR-17: Before/After visual reward
After completing a session or project milestone on a scanned space, the user can shoot an "after" photo and receive a side-by-side visual diff as reward.

**Consequences (testable):**
- The diff view shows before and after with no negative framing language (no "still messy" copy).
- Diffs are saved to the Transformation Album automatically.

#### FR-18: Local transformation album
The app maintains a private, local gallery of before/after pairs and cumulative milestones.

**Consequences (testable):**
- Album contents are never sent by the app; they leave the device only via user-initiated export (§7) into the user's chosen folder.
- Album entries are deletable individually and purgeable in one action.

### 4.5 Mindful Decluttering Protocol

**Description:** "You cannot organize clutter": before any organizing Epic Project, the app injects a pre-clean purge sequence with empathetic detachment questions, the 3-Destination Flow, and the Quarantine Box for hesitant items. Tracks liberated space as a satisfaction metric. Realizes UJ-2.

**Functional Requirements:**

#### FR-19: Pre-clean purge injection
When an organizing Epic Project activates, the system prepends purge Micro-tasks before any organization steps.

**Consequences (testable):**
- The first dealt Micro-task of a newly activated organizing project is always a purge step.

#### FR-20: Detachment questions and 3-Destination Flow
During purge steps, the app presents guilt-free detachment questions — the factual one ("Have you used this in the past 12 months?") and the one that does the real work ("Does this deserve your physical and mental space?") — alongside the Keep / Donate-Sell / Trash-Recycle triage, surfaced as `Quedármelo` / `Donar o vender` / `Tirar o soltar` (§3).

**Consequences (testable):**
- Question copy contains no pressure framing; every question is answerable by skip without consequence.
- The three destinations carry equal weight, and the third is labelled `Tirar o soltar` — never `Tirar o reciclar`, never a bin or a recycling word (§3, UX session `ux-organizer-2026-08-21`). No destination is worded, styled or ordered as the undesirable one.

#### FR-21: Quarantine Box
The user can send hesitated items to a dated Quarantine Box; if untouched after 6 months, the app gently suggests donation.

**Consequences (testable):**
- The follow-up suggestion appears at most once per box and is dismissible in one tap (6-month cadence, once-only — confirmed 2026-08-20).

#### FR-22: Cumulative declutter metric
The system tracks liberated items as a positive-impact milestone, derived only from what the user taps during purge steps.

**Consequences (testable):**
- The metric is a per-destination item count (Keep / Donate-Sell / Trash-Recycle), incremented by tap during purge steps. Nothing is inferred from photos.
- Volume is optional and coarse: the user may tag a batch as bolsa / caja / caja grande / mueble. Absent tags simply do not contribute.
- Volume is displayed as an approximation with its unit visible ("≈ 3 cajas liberadas"), never as a precise figure or a percentage.
- Displayed only as cumulative achievement — never a target, a rate, or a deficit.

### 4.6 Progress & Cumulative Impact

**Description:** Gentle visibility of real advance: minutes invested, micro-tasks done, space liberated, before/after album — counters of achievement only. Includes the optional motivating snowball: a gentle suggestion to raise the Time Bag after sustained streaks of comfortable completion. Realizes UJ-3, UJ-4 (perceived-progress concern from the brainstorm's Critic room).

**Functional Requirements:**

#### FR-23: Cumulative impact dashboard
The user can view cumulative minutes, completed Micro-tasks, liberated items/volume, and album highlights.

**Consequences (testable):**
- Dashboard contains no daily quotas, no averages-over-time comparisons, and no deficit framing.
- After a snowball condition (≥ 10 comfortable days), a one-tap-dismissable suggestion to raise the Time Bag by ≤ 5 min may appear; declining has no effect.

### 4.7 Ambient Invitation (passive daily notification)

**Description:** The app's only outward-facing signal. One silent notification per day at a user-chosen hour, phrased as an open invitation ("hay 15 minutos esperando cuando te apetezca") — never a task, never a count, never a reference to anything unfinished. It exists because the app cannot help someone who forgets it exists, and it must remain incapable of escalating into a nag. Realizes UJ-1 (session initiation).

**Functional Requirements:**

#### FR-24: Single silent daily invitation
The user can enable exactly one daily notification at a chosen hour, delivered silently, whose content invites a session without referencing tasks, counts, or pending work. Off by default; once disabled it stays disabled until the user turns it back on.

**Consequences (testable):**
- At most one notification per 24 h is emitted by the app, under every code path — no second chance, no re-delivery on dismissal, no follow-up if unopened.
- The notification is posted on a low-importance/silent channel: no sound, no heads-up interruption, no badge count.
- Notification copy contains no task title, no numeric counter, no time reference other than the offered minutes, and no word framing anything as owed, late, missed, or remaining.
- Dismissing or ignoring it has zero effect on any plan, metric, or subsequent notification content — consecutive ignored days are indistinguishable from opened ones in app behavior.
- Disabling it removes the app's notification permission usage entirely; the app requests no other notification category.

### 4.8 Data Handling & Privacy

**Description:** The app holds photographs of the inside of the user's home. Two rules govern them: nothing leaves the device without a per-scan decision, and what leaves is the minimum that makes the Smart Slicer work. Everything else — plan state, album, metrics — is local and stays local.

**Functional Requirements:**

#### FR-25: Per-scan consent and upload minimization
Before any image leaves the device, the user confirms that specific upload; the app restricts what may be sent and discards the scan image once the plan exists.

**Consequences (testable):**
- No image is transmitted without a per-scan confirmation. A blanket "always allow" setting does not exist — consent is asked per scan, every scan.
- If the app detects a person or face in the frame, the scan is refused before upload with an offer to reframe; that refusal happens on-device.
- The scan image is deleted from the device once the micro-plan is generated. Only Before/After photos the user deliberately shoots for the reward loop (FR-17) persist, and only in the local Transformation Album.
- Declining consent, or a detection refusal, routes to Manual Capture (FR-29) — never an error dead-end, and never a template presented as a plan.
- The confirmation screen states, in plain Spanish, what is sent and to whom. It contains no dark-pattern asymmetry: declining is the same number of taps as accepting.
- Only the scan image and a prompt are sent. No plan history, no album contents, no device or location identifiers.
- Text-only re-slice requests (FR-5) send the Origin Context and the current task — never an image — without a per-call dialog. This rests on the FR-28 allowlist gate: only providers with written no-training, no-retention terms are selectable at all, so the guarantee is a build-time property rather than a runtime hope.
- On the BYOK path the destination is the user's own provider account, reached with the user's own key. The developers receive nothing, hold nothing and operate nothing (§7). On the Local path nothing leaves the device and this FR is satisfied trivially.

#### FR-26: Local validation instrumentation
The app records, on-device only, the minimum series the success metrics consume.

**Consequences (testable):**
- Four series exist and are queryable: (a) session start/end with duration and Micro-tasks completed, (b) Photo-Diagnosis scans and their outcome (plan / declined / Slicer unavailable), (c) Before/After pairs per project milestone, (d) Ambient Invitation emissions and whether the app was opened within the following hour.
- Every Micro-task carries its genesis origin — `shipped` (pre-sliced Evergreen Library content, FR-11, FR-31) / `manual` / `local` / `cloud` — and every series row that references a task carries it too. Without this field SM-3 and SM-4 become unreadable the moment Manual Capture is in use: a milestone reached entirely by hand validates the engine but not the hook, and the two must be distinguishable. Origin is a provenance tag, never a quality ranking, and never surfaced in the Dispenser.
- All series are local-only; no third-party analytics SDK is present in the build. The app transmits no usage data of any kind, and in the validation build there is no developer-side record at all, because there is no proxy (§7, FR-28).
- The user can read the series as raw exported data, so the validation verdict does not depend on the app's own summary.
- No series is surfaced in the Dispenser or dashboard as a daily target, average, or period comparison (constraint from SM-C1/SM-C2).
- Skips feed only FR-5's consecutive-skip logic. No cumulative skip total is stored anywhere — a skip count is a debt record with a different name.

#### FR-30: Silent automatic export
The full export runs by itself, silently, into the folder the user chose — with no reminder, no indicator, and no pending state anywhere. Promoted from a downstream note to a requirement 2026-08-21.

**Consequences (testable):**
- After the user picks a destination folder once (system folder picker, persisted URI), every subsequent export happens without being asked for: plans, album images and all FR-26 series, in the same single legible-text-plus-images format that serves as raw series export, validation source and restore format (§7).
- Export is triggered at natural foreground moments — end of a session, app going to background — and is **not** background work: no periodic job, no persistent service, no wake lock, no new permission (§7 background minimalism holds unchanged).
- The app never transmits the export. It writes a local file; if the chosen folder happens to be a synced one (Drive, Dropbox, Nextcloud), the user's own already-installed client does the uploading. Zero provider integrations, and the egress map (§7) is unaffected — the destination is still "the user's own storage".
- No reminder, no badge, no backup-age indicator, no "last exported" line and no failure toast exists in the Dispenser or anywhere the user lives. Backup must never read as pending work, and a silent export that nags is worse than a manual one.
- Export state — destination, last success, last failure and its cause — is readable **in settings only**. This is the validator's surface, not the user's (§7).
- One-tap manual export remains available for the user who wants it now (§7).
- If the destination becomes unwritable (revoked permission, removed volume), the app keeps working and stays silent; the fact is visible in settings and nowhere else. The failure is never framed as the user's omission.

### 4.9 Manual Capture (the floor)

**Description:** The one entrance the user writes, and deliberately the poorest one — whether the words arrive by keyboard or by voice (FR-32). Something occurs to the user that the app cannot know and no photo can reveal — a favour promised to a neighbour, a form to hand in. Manual Capture takes one line and one of three sizes, then returns to the Dispenser. It exists so the app is never useless: with no key, no network, no model and no account, it still holds work and dispenses it. It is a floor, not a road — every affordance that would make it comfortable to live in has been left out on purpose. Voice (FR-32) is the one exception to that sentence, and it is an exception about *cost* rather than about *capability*: dictation makes the single line cheaper to produce and adds nothing the line could not already hold — no second task, no parsed size, no natural-language plan, no list. A cheaper floor is still a floor; a floor with a list is not. Realizes UJ-5.

**Functional Requirements:**

#### FR-27: Manual Capture
The user can add one Micro-task by typing one line and choosing one of three sizes, at any time, with no network, no key, no model and no account. Added 2026-08-21.

**Consequences (testable):**
- Capture is reachable from the Dispenser in one tap and completes in two fields: one line of text, and a size chosen from exactly three options — 30 s, 3 min, 10–15 min. No free-form minute entry exists anywhere.
- The three sizes *are* the 1-3-5 taxonomy (Instant Habit / Micro-maintenance / Focus Chunk), so a captured task enters the Project Weaver's composition with no conversion step and FR-12's budget arithmetic holds unchanged.
- Capture asks for nothing else: no project, no category, no date, no priority, no tags, no recurrence, no confirmation screen.
- The captured line can be corrected or discarded from the capture surface itself, before the user leaves it. Once the user leaves, the task belongs to the pool and there is no path back to it except being dealt.
- No screen in the app lists, counts, filters or browses captured tasks (§5.2). A captured task is next seen as an ordinary dealt card, visually and tonally indistinguishable from a sliced one.
- Manual Capture behaves identically under every AI Access Path, including none.
- A manually captured task carries origin `manual` (FR-26) and an Origin Context consisting of its own line (§3). It is re-sliceable by FR-5 when a Slicer is reachable, and not re-sliceable when none is.
- A captured task is dealt within 3 days of capture (§10.1), ahead of Evergreen and Epic material of the same size (FR-12). Nothing else about it is privileged.
- Whether Manual Capture accepts non-spatial work at all is an open product decision (OQ-11), not an implementation detail: the whole engine is spatial, and this is the first entrance through which "call the dentist" can arrive.

#### FR-32: Voice dictation into the capture line
The user can fill Manual Capture's single line by speaking instead of typing, recognised on-device, with no network, no key, no model and no account. Added 2026-08-26.

**Consequences (testable):**
- Dictation is offered on the Manual Capture surface and nowhere else in the build. No other field or action accepts voice, and no voice *command* exists anywhere — the Dispenser is operated by tapping (§1.1 principle 1). Voice is a second way to fill one field, never a second way to drive the app.
- Voice fills **the text line only**. The size is still chosen from the same three taps (FR-27), and a spoken duration is treated as words in the line like any others: nothing is ever parsed out of the transcript. Parsing speech into structure is the deferred voice-first slicer (§5.1), and this requirement sits on the other side of that line.
- One utterance produces at most one Micro-task. A dictation that plainly contains several errands still becomes one line and one task — the app does not split it, and does not tell the user it could.
- Recognition runs **on-device**. The audio never leaves the phone, so §7's egress map gains no destination. There is deliberately **no cloud fallback**: where on-device recognition is unavailable the feature is absent, never degraded into an upload, because a fallback is exactly how a new egress destination arrives without anyone having decided to add one.
- No audio is retained anywhere, for any duration. It is not written to storage, not included in the export (FR-30), not present in any FR-26 series, and not recoverable once the transcript exists. The only artifact a dictation leaves behind is text in a field.
- The transcript appears **in the existing one-line field on the existing capture surface** — not in a confirmation screen, which §4.9 does not have and does not acquire. FR-27's correct-or-discard affordance is therefore what governs a mis-transcription, and it becomes load-bearing in a way it was not before: leave-and-it-is-gone was safe while the user typed what they read, and a machine-written line that reaches the pool wrong can never be fixed, because §5.2 abolishes the list. Dictation without a visible, editable transcript is a defect, not a variant.
- **The keyboard is never removed.** Voice is strictly additive: the surface accepts typing at all times, and correcting a transcript requires it. A voice-only capture surface would be unusable the first time recognition mis-hears a household word.
- Where on-device Spanish recognition is unavailable — no language pack, unsupported device, or a microphone permission the user has refused — the microphone affordance is **simply not present**. No error, no explanation, no offer to install anything, no greyed-out state: an affordance the user never saw is not a loss, whereas a disabled microphone is pending work sitting in the one place the user lives (§1.1 principle 2, §7). OQ-13 owns whether settings may carry a one-time pointer.
- The microphone permission is requested at the first dictation attempt, never at app entry and never during first run — nothing in first run acquires a new prerequisite (§7). Refusing it leaves Manual Capture fully functional by keyboard, removes the affordance, and the app never asks again.
- Nothing listens outside an explicit press on that affordance. No wake word, no always-on capture, no ambient recognition, and no background audio work of any kind (§7 background minimalism holds unchanged, and FR-24's invitation remains the only background work in the build).
- A dictated task carries origin `manual` exactly as a typed one does (FR-26): dictation is an input method, not a genesis path, and origin records what authored a task rather than which key was pressed. Whether dictation was used is recorded as a separate local boolean on the capture, readable **in settings only** (§7), so the window can answer whether voice earned its place without disturbing SM-4's origin arithmetic.
- Dictated and typed tasks are indistinguishable once dealt. No badge, no icon and no copy anywhere marks a card as spoken.

### 4.10 AI Access Path

**Description:** How the app reaches a Slicer. Three implementations behind one interface — Local (on-device model), BYOK (the user's own key against a vetted provider), Managed (developer-run proxy behind login/password, paid in non-expiring credits and never a subscription — §5.1, §5.2) — of which the validation build ships exactly one. BYOK is chosen for v1 because it is the only path that costs nothing to build and holds nothing: no proxy, no account, no login, no developer-held data, no first-run network requirement. This section exists because the earlier PRD collapsed "who creates tasks" into "how AI is paid for", and the collapse manufactured a login requirement at app entry that nothing actually needed (addendum A9).

**Functional Requirements:**

#### FR-28: AI Access Path with a vetted-provider allowlist
The Slicer is reached through a swappable access interface. The validation build implements BYOK: the user supplies their own API key for a provider chosen from an in-app allowlist. Added 2026-08-21.

**Consequences (testable):**
- Exactly one path is *usable* in the validation build (BYOK). Adding Local or Managed changes no call site outside the access layer.
- The Local path ships as a **stub that returns a canned slice**, so the interface has two real callers in the shipped build and its swappability is exercised rather than asserted. An interface with a single implementation is an untested abstraction, and untested abstractions are wrong almost always; the stub is the cheapest possible test and is a build requirement, not a suggestion. Promoted from a downstream note 2026-08-21.
- The stub is never reachable by the user: it is selectable only in a debug build, and its canned output is recognisable as such so it can never be mistaken for a real slice.
- Providers are chosen from a fixed in-app allowlist. A free-form endpoint or base-URL field does not exist — FR-25's no-training, no-retention gate is unenforceable the moment the user can point the app anywhere, and a gate that depends on the user reading terms is not a gate.
- The allowlist is frozen at build time and never fetched over the network. A remote list would reintroduce a developer-side endpoint, and with it the third egress destination §7 has just eliminated — the guarantee would be bought back at the price of the property it protects.
- Each allowlist entry states, in plain Spanish, the provider name and the date its terms were verified, and says plainly that they were verified *on* that date and not since. An app with no backend cannot revoke anything; claiming otherwise would be the more dishonest option.
- Stale terms are corrected by shipping a build. That is the only mechanism that exists, and OQ-10 owns what the app does in the meantime.
- The key is held in the OS keystore: never in app preferences, never in the export (§7), and never transmitted anywhere except to its own provider.
- No account, login, password or registration exists anywhere in the build, and nothing in the first-run experience requires the network.
- The app never adds a margin, meters usage, or reports a call to anyone. On BYOK the billing relationship is entirely between the user and their provider.
- If the Managed path is ever implemented it is paid in non-expiring credits, never in a recurring fee (§5.1, §5.2), and its balance is never surfaced outside settings. This is recorded in the access layer and not only in Non-Goals, because the access layer is precisely where someone would otherwise wire a subscription check.

#### FR-29: Honest degradation with no Slicer
When no Slicer is reachable, the app states the cause plainly and offers Manual Capture. It never invents tasks, never presents a template as a plan, and never queues work for a later upload. Added 2026-08-21.

**Consequences (testable):**
- Every no-Slicer cause is distinguishable in the copy and names its own remedy: no key configured, invalid key, exhausted quota, provider unreachable, no network, consent declined (FR-25), person detected in frame (FR-25).
- Every one of those states offers Manual Capture as the way forward. None is a dead end and none is styled as an error — no red, no warning iconography, no exclamation (§1.1).
- Nothing is queued: no scan image, no re-slice request and no pending-upload state survives the failure. The user reshoots or retypes when the Slicer is back, because a deferred upload would break per-scan consent (FR-25) and background minimalism (§7).
- A fresh install with no Slicer reachable still reaches a woven 1-3-5 day, from the pre-sliced Evergreen content that ships in the build (FR-11). What is unavailable is everything personal: Epic Projects, photo slicing, re-slicing. The app names that distinction plainly instead of implying the whole product is degraded.
- The absence of a Slicer is never framed as the user's omission, and never as pending work.
- **The seven strings are authored before the failure path is wired**, and they are part of the SM-C2 audit surface from the start. Promoted from a downstream note to a requirement 2026-08-21: these are the highest shaming-risk sentences in the product — "tu clave no es válida" is one tap away from blame — and they are exactly the strings that otherwise get written last, in a hurry, by whoever cables the error branch. No implementation of FR-29 is complete while any of the seven is a placeholder or a developer string.

### 4.11 Evergreen Task Library

**Description:** The catalogue of pre-sliced household Micro-tasks the build ships with. It is what makes FR-11's promise real: a fresh install with no key, no network and no model still has a varied month of household work to deal from. Three cadences, because a home has three — the things done every day, the things that rotate weekly by zone, and the things that come round monthly or with the season. It is product content, fixed at build time, and it is not a place the user writes. Content: addendum A12. Realizes UJ-1, UJ-3, UJ-4.

**Functional Requirements:**

#### FR-31: Pre-sliced Evergreen Library
The build ships a catalogue of Evergreen Micro-tasks spanning three cadences, broad enough to compose a varied 1-3-5 day for the whole validation window. Added 2026-08-23.

**Consequences (testable):**
- Three cadences ship and each is populated: **daily** — Instant Habits (~30 s) and Baseline Upkeep (3–15 min); **weekly** — zone routines across the 5 FlyLady zones; **monthly/seasonal** — windows, filters, descaling, deep-clean upkeep.
- Every entry carries three fields and no more: a size drawn from the 1-3-5 taxonomy (30 s / 3 min / 10–15 min), a cadence, and a zone or none. The Weaver therefore needs no conversion step and FR-12's arithmetic holds unchanged.
- **Coverage floor:** the weekly plus monthly/seasonal pool holds at least 45 distinct entries, so 28 consecutive Focus Chunks never repeat a Micro-task even with no Epic Project active. Daily items recur by definition; everything else must have the breadth to keep a rotation from collapsing into the same handful.
- **No entry is bound to a clock.** No catalogue task carries an hour, a mealtime, or a before/after dependency the app would have to track (§1.1 principle 3, §5.2). Cooking is excluded for exactly this reason; the upkeep that follows a meal ships, because it follows a moment the user recognises rather than a time the app must know.
- The catalogue is curated at **cluster** level — zones and upkeep groups — never at task level. No screen anywhere enumerates individual catalogue entries: a browsable 80-item catalogue is the task list §5.2 abolishes, arriving through the template door.
- The Archetype Template selection surface of §1.1 exception E1 is not an exception to the bullet above: what it enumerates is templates and clusters, never the individual catalogue entries inside them (UX session `ux-organizer-2026-08-21`).
- Curation is reachable from onboarding and settings only, never from the Dispenser (§7). A disabled cluster's tasks simply never appear; disabling one produces no count, no summary and no copy about what was turned off.
- The library is fixed at build time and the user cannot author, edit or extend it. Manual Capture (FR-27) remains the only way a user-written task enters the pool, and it stays a floor rather than becoming a template editor.
- Every library task carries origin `shipped` (FR-26), so SM-4 can read the Focus Chunk mix against it.
- Library breadth is a build-time property, verifiable without running the app: the catalogue is a data file, and the coverage floor above is checkable by counting it.

## 5. Non-Goals

Two kinds of omission, kept apart deliberately: what may come back, and what may not.

### 5.1 Deferred — outside the validation build, may return

- **Adaptive/ML buffer learning** — Invisible Buffers are rule-based in v1 (Phase 3).
- **Voice-first natural-language slicer** — Phase 3. What stays deferred is voice as *genesis*: speaking freely and having the app parse the speech into several sized micro-tasks, or into a project. What is **not** deferred, and ships in this build, is voice as a *keyboard replacement* on the one line Manual Capture already had (FR-32). The distinction is the one §1.1 principle 6 draws everywhere else — dictation transcribes, a Slicer authors — and it is named here because "we added voice" is precisely the sentence a later reader would take as having shipped this bullet.
- **Multi-user household zones and shared Time Bags** — v3. [NOTE FOR PM] Emotionally load-bearing and core to the household vision; this build leaves it entirely untested. Revisit before any public launch.
- **iOS, web, desktop, widgets, wearables** — Android only in v1.
- **Cloud backup or sync of app data** — local-first only, and no provider integration ever. Automatic *export to a local folder* is no longer deferred: it is required and silent (FR-30, promoted 2026-08-21). What stays deferred is anything that would make the app itself talk to a cloud provider — if the chosen folder is synced, that is the user's own client doing it, not us.
- **Managed AI access, sold as credits** — the third AI Access Path (§4.10) is interface-only in v1: no proxy, no account, no login and no billing is built. The structural requirement is named rather than merely hoped for — the Slicer sits behind an access interface with three implementations (Local / BYOK / Managed), so this is never foreclosed by a shortcut taken now. Pricing is deferred, but three constraints on it are settled here, because they follow from §1.1 rather than from pricing strategy:
  - **Credits never expire.** An expiring credit punishes absence, which is precisely what Warm Return exists to forgive — and an expiring credit is a subscription wearing a costume.
  - **The balance is never visible outside settings.** Never a badge, never a counter near the Scan surface, never a per-scan price. A depleting number beside "photograph your mess" manufactures exactly the hesitation A8 forbids.
  - **BYOK remains available forever.** Prepaid credits are then never lock-in, and a dead proxy never holds a user's plans hostage.

### 5.2 Excluded by philosophy — will not return

- **Calendar access — reads and writes.** Propose, never impose; ask, never observe. Calendar writes would impose structure the app exists to remove. Calendar life-sync (brainstorm Phase 2, read-only availability suggestions) is likewise excluded by philosophy, not by phasing: the calendar knows where the user will be, not what energy they will have — a free slot is not free energy — and an app that observes the calendar breaks the promise the whole data model stands on (§7). The availability tap ("I have X minutes now") is the product, not friction to remove. No calendar permission of any kind is ever requested.
- **Gamification that can punish** — no streaks, HP, points decay, or levels tied to performance.
- **Reminder or nagging notifications** — the app never recalls a debt. The single exception is the opt-in Ambient Invitation (FR-24): one silent, content-free daily invitation. No task notifications, no streak alerts, no re-engagement campaigns, no notification that references anything unfinished. Any second notification category is out of scope by philosophy, not by phasing.
- **Clock-bound tasks — anything with an hour attached.** Cooking, the school run, appointments. The Floating Time Bag exists precisely so nothing here has a time of day (§1.1 principle 3), and one catalogue entry with an hour on it drags the calendar back in through the template door — the same door the bullet above just locked. The app does not deal them, does not remind about them and does not model them. What it does ship is the upkeep hanging off them — clearing the table, the dishwasher, closing the kitchen — because those follow a moment the user recognises rather than a clock the app must track (FR-31).
- **GTD density** — no tags, filters, kanban, or task hierarchies beyond the dual lifecycle.
- **A task list, in any form.** Manual Capture (FR-27) writes into the pool and returns; it never opens a backlog. No screen anywhere enumerates captured tasks, permits editing them, or lets the user browse what is pending — a "just let me see what I typed" screen is the first version of the endless list §1 exists to abolish, and it is the door GTD density walks through. The single concession: the line just written can be corrected or discarded from the capture surface itself, before the user leaves it. After that it belongs to the pool.
- **Subscription pricing for AI access.** A recurring fee bills for the months the user does not open the app — it monetizes exactly the absence FR-6 and UJ-3 exist to forgive. And a business that earns from silence acquires an interest in breaking it: recurring revenue rewards engagement, while the reminder exclusion above forbids engineering engagement. The two cannot share a product, so the fee is excluded by philosophy rather than deferred by phasing. Credits (§5.1) track use, and use tracks the user's own free will.

## 6. MVP Scope

Validation build = brainstorm Phase 1 **plus** AI Photo-Diagnosis and Before/After rewards (per decision 2026-08-20), on Android, Spanish-first. What is out of scope is §5.

- Dispenser UI with Done/Skip, energy check-in, Rescue Mode, Warm Return (FR-1–FR-6)
- Time Bag, "I have X minutes now", pause/silent recalculation, Anti-Marathon checkpoint (FR-7–FR-10)
- Dual-lifecycle projects, 1-3-5 weaving, Invisible Buffer, Silent Rescheduler, seasonal suggestions (FR-11–FR-15)
- Pre-sliced Evergreen Library across three cadences — daily anchors and Baseline Upkeep, weekly zone routines, monthly/seasonal upkeep — with cluster-level curation in onboarding and settings (FR-31)
- Cloud Photo-Diagnosis with Smart Slicer, Before/After reward, local Transformation Album (FR-16–FR-18)
- Decluttering Protocol with Quarantine Box and declutter metric (FR-19–FR-22)
- Cumulative impact dashboard with snowball suggestion (FR-23)
- Opt-in Ambient Invitation: one silent daily notification (FR-24)
- Per-scan photo consent with on-device person/face gate, and local-only validation instrumentation (FR-25, FR-26)
- Silent automatic export of plans, album and all series to a user-chosen folder, with no reminder and no pending state (FR-30)
- Manual Capture: one task, one line, three sizes, no list — always available with or without AI (FR-27)
- Voice dictation into Manual Capture's line: on-device recognition, no cloud fallback, keyboard always retained, no audio ever stored or transmitted (FR-32)
- AI Access Path: BYOK only, against a vetted-provider allowlist; Local and Managed are interface-only; no account and no proxy (FR-28, FR-29)
- Spanish UI, i18n-ready strings (no hardcoded copy)

## 7. Cross-Cutting Constraints

- **Offline by default — execution, not genesis.** Dispensing, completing, weaving, rescheduling, the album, the dashboard, export and Manual Capture work with no network, always — Manual Capture including its voice dictation, which is recognised on-device precisely so this sentence needs no exception (FR-32). Slicing does not: on the BYOK path every slice and re-slice needs the network, on the Local path none does. The shipped Evergreen day is exempt because it was sliced at build time rather than at runtime (FR-11) — a phone in airplane mode on day one still has the whole Evergreen Library — anchors, Baseline Upkeep, zones and seasonal upkeep (FR-31) — and a composition built from it. The distinction is load-bearing (§1.1) — an offline app executes, it does not beget. Airplane mode is supported, never an error state; a slice or rescue that cannot reach its provider degrades per FR-29 and queues nothing.
- **Local-first durability.** No developer-held data of any kind. A lost device loses the Transformation Album and every metric series unless exported — so one-tap full export (plans, album, series) is required, not optional: legible text plus album images, restorable on reinstall. Destination is chosen through the system folder picker — any cloud folder the user already has (Drive, Dropbox, Nextcloud) works, with zero provider integrations. No backup reminders or backup-age indicators anywhere: backup must never read as pending work. As of 2026-08-21 the export is also **automatic and silent** (FR-30), because manual-only export plus no reminders plus a 4-week window is a real chance of the validation data dying with a dropped phone in week 3 — and the fix for the user (never nag) and the fix for the validator (never lose the data) are only compatible if the export happens by itself. Sync *to a provider* stays deferred (§5.1); the app writes a local file and nothing else.
- **Settings is where the validator reads; the Dispenser is where the user lives.** Anything a validator needs and a user must never be shown — the FR-26 raw series, FR-30's export state, the Managed path's credit balance (§5.1) — is reachable in settings and nowhere else. This is what makes the same person's two roles survivable in one app: the user's surfaces stay free of counters, and the numbers still exist for whoever goes looking.
- **Data egress map — path-dependent, and the validation build has no third destination.** To the AI provider: only the scan image (per-scan consent, FR-25) or the rescue re-slice text (FR-5), nothing else ever — and on the BYOK path that provider is the user's own account, reached with the user's own key. **Audio: nowhere, to no one.** Voice dictation (FR-32) is recognised on-device and adds no destination to this map, and it has no cloud fallback for exactly that reason — a fallback is how a new destination arrives without anyone deciding to add one. To the user's own storage: whatever the user exports, when the user chooses. **To the developers: nothing.** The 2026-08-20 turnstile ruling — an account identifier and AI request timestamps at a proxy, because "access cannot be free" — was a consequence of the Managed path, and the Managed path is not built (§5.1): with BYOK there is no proxy to log anything and no account to identify. On the Local path even the first destination disappears. No app-open counts, no telemetry, no analytics; the app never reports usage to anyone. When the Managed path is built the turnstile returns and this bullet must be rewritten, not quietly reinterpreted. One format, three uses: the legible-text export is simultaneously the FR-26 raw series export, the validation data source, and the backup/restore format.
- **Latency inside a 15-minute pocket.** Cold start to first dispensed card ≤ 2 s; Done → next card ≤ 500 ms (FR-2). Startup latency is stolen from the pocket the user offered. Slicing is deliberately exempt: OQ1 demoted scan latency and FR-16 sets no cap, so the stale "scan → plan ≤ 30 s" that stood here — contradicting both FR-16 and §10.2 — is removed (2026-08-21). The exemption matters most on the Local path, where inference on a mid-range phone will be slow.
- **Accessibility.** Legible at 200% system font scale with no truncation; every action reachable one-handed; haptics never the sole completion signal. **No keyboard is required to use the app.** The photo path needs no words and Manual Capture's one line can be dictated (FR-32), so someone who cannot type comfortably on a touch screen — small keys, motor difficulty, poor eyesight — is never shut out of the only surface where the app asks for writing. This is a floor on the whole build rather than a property of FR-32: any future surface that demands typed input breaks it.
- **Copy is the product surface.** Spanish UI, every string externalized, no runtime sentence concatenation — the anti-shaming audit (SM-C2) must be reviewable as a flat string table. The failure and degradation strings are in that table on the same terms as everything else: FR-29's seven no-Slicer messages are authored before the path that shows them is wired, not after (FR-29).
- **Background minimalism.** The only background work is FR-24's daily invitation. No sync, no location, no persistent service, no wake locks, **and no microphone outside an explicit press** — no wake word, no always-on listening, no ambient recognition (FR-32). Voice does add the one new runtime permission in the build, requested at first dictation and never at first run; it is named here rather than left to FR-32 because a permission list is what a reviewer reads, and this bullet is where the build promises what is not in it. The automatic export (FR-30) is deliberately *not* an exception: it runs in the foreground at natural moments — session end, app backgrounding — because a periodic sync job would buy durability with the one property this bullet protects.
- **No overdue at the schema level.** "No overdue concept" (FR-14) is a data-model constraint, not a UI rule: no field, flag, or derived value anywhere may express lateness, debt, or a missed occurrence. Overdue-shaped data breeds overdue-shaped UI, and the next person to touch the schema will not have read §1.1.
- **Single-user data model throughout.** All local data (plans, album, series) remains account-free and single-user. Multi-user (§5) remains a schema change, and that is accepted knowingly.
- **No account in the validation build.** BYOK needs a key, not an identity: no login, no password, no registration, no first-run network requirement. The app is fully usable the second it installs, because Manual Capture (FR-27) needs nothing at all. The earlier formulation — "login/password requested at first AI use, never at app entry" — was incoherent while the Slicer was the only source of tasks, since on a fresh install the first use *is* an AI use. Manual Capture is what makes that sentence unnecessary rather than merely rephrased. Login/password belongs exclusively to the Managed path (§5.1) and does not exist in this build.

## 8. Success Metrics

Validation window: 4 consecutive weeks of real use (confirmed 2026-08-20). Day 1 is the first day the build is usable daily on Sergio's own phone — not a calendar date. The intent document's Gantt (phases from 2026-09-01) is deliberately not carried into this PRD: a solo validation build paced by a dated plan would reintroduce exactly the deadline pressure the product exists to remove.

Secondary observers: the builder's wife (same household) and sister-in-law (separate household) run independent single-user instances during the window. Their data is reported as a separate annex and never merged into SM-1–SM-3. All subjects are motivated and non-representative — the signal is within-subject decay (week 4 vs week 1), never cross-subject comparison. Domestic territory in the shared household is agreed before day 1, outside the app: the product proposes per-person projects and coordinates nothing between users, by design.

BYOK (FR-28) does not break the annex, because a shared key is not required: each subject gets **her own API key issued from the builder's single provider account** — providers that support per-key cost attribution make this a one-minute setup with no payment method and no account of her own, and with per-person cost visible to the builder. Each instance's FR-26 series stay on that person's device and are never merged (above); the provider-side per-key figures are cost data, not usage telemetry, and feed no metric. One caveat belongs to OQ-10: an aggregator that routes to many upstream providers turns FR-28's no-training/no-retention gate from a property into a *configuration* — the account's data policy and provider filtering must be pinned and verified, or the gate is void.

**Primary**
- **SM-1**: Sustained usage — sessions on ≥ 70% of days across the 4-week window, measured from local session logs. Validates FR-1–FR-10.
- **SM-2**: Felt overwhelm reduction — weekly in-app self-report, one question on a 5-point scale ("Esta semana, ¿cuánto te ha agobiado la casa?"), asked Sundays, trending ≥ 1 point better by week 4 vs week 1. Instrument fixed 2026-08-20 so the week-1 baseline exists on day 1. Validates the product premise (Vision).
- **SM-3**: Real epic progress — at least one Epic Project reaches a visible milestone (e.g., storage room phase complete) with zero app-initiated session continuations: sessions may run long only by the user's active choice (FR-10). Validates FR-11–FR-16.

**Secondary**
- **SM-4**: Photo loop adoption — ≥ 1 Photo-Diagnosis scan per week in active use; before/after pair shot for ≥ 50% of completed project milestones. Read against task origin (FR-26), and on the right denominator: the daily 1-3-5 is dominated by `shipped` Evergreen content by construction, so raw task share proves nothing. The question is what authored the **Focus Chunks and the Epic material** — if `manual` originates most of those across the window, the differentiating hook is unvalidated however well SM-1 and SM-3 read, and that is the window's most important finding rather than a footnote. Validates FR-16–FR-18.

**Counter-metrics (do not optimize)**
- **SM-C1**: Minutes or tasks per day must NOT be pushed upward — the product's value is calm progress, not throughput. Counterbalances SM-1: engagement achieved by nagging or marathon-creep is failure, not success.
- **SM-C2**: Guilt events = 0 — count of UI/copy occurrences that frame anything as owed, late, or failed must remain zero. Counterbalances SM-3: progress purchased with pressure voids the premise.
- **SM-C3**: Notification volume must NOT rise above 1/day, and invitation copy must NOT acquire task content, counters, or urgency across the window. Counterbalances SM-1 specifically: if sustained usage turns out to be driven by notification pressure rather than by the product being pleasant to open, SM-1 is a false positive. Test: passive analysis of FR-26 series (d) — share of sessions started within the hour following an emission; if most sessions trace to the ping, run one week with the invitation disabled, outside the 4-week window.

## 9. Open Questions

1. Which multimodal vision API/model for the Smart Slicer? Ruling 2026-08-20: for the validation build, selection optimizes for one thing — does the photo → micro-plan loop actually work on real photos. Fixed around it: (a) provider terms gate (written no-training, no-retention) — non-negotiable, forever, applies to any cloud path; (b) latency sacrificed; (c) price parked until monetization (§5.1). Deployment topology — cloud API vs on-device — is deliberately open, and as of 2026-08-21 the local candidate has a name: Gemma 4 (released 2026-04-02), E2B/E4B variants, native multimodal image input, official Android support. E4B is the phone-class target; the 12B is laptop-class and out of scope for a handset. Existence is no longer the question — the question is whether E4B slices real clutter photos into usable 3–5 min steps, which is an afternoon of testing on the validation phone, not a decision to be made in this document. The Slicer sits behind the FR-28 access interface, so the choice stays swappable without touching the rest. EU data residency is deferred to the phase where users who are not family exist — it is a jurisdiction concern of scale, not of validation. → `bmad-architecture` designs for both; real-photo tests decide.
2. ~~Self-report instrument for SM-2~~ — closed 2026-08-20, see SM-2.
3. ~~Content of the 5 default FlyLady zone Archetype Templates~~ — closed 2026-08-23. The lifecycle split settled on 2026-08-21 stands unchanged (Evergreen ships pre-sliced because FlyLady is published; Epic is never templated because it is personal). What was still open — the concrete content — is now authored rather than deferred, and widened well past five zones: the Evergreen Library covers three cadences, daily anchors and Baseline Upkeep included (FR-31, addendum A12). What survives is a UX question rather than a content one: how cluster-level curation is presented at onboarding without becoming the list §5.2 abolishes. → `bmad-ux`.
4. ~~"No overdue" — schema constraint or UI rule?~~ — closed 2026-08-20, see §7.
5. Local-first storage tech and the export/escape-hatch format → architecture.
6. Does the seasonal suggestion engine (FR-15) need any configuration surface in v1, or pure defaults? → Sergio, revisit at `bmad-ux`; defaults-only is the standing answer until a suggestion actually misfires.
7. Exact Ambient Invitation copy (FR-24) — one fixed string, or a small rotating set to avoid the blindness that kills any repeated notification? Must survive the SM-C3 constraint either way. → `bmad-ux`.
8. Android delivery mechanism for FR-24 under Doze/battery optimization: is an inexact daily alarm acceptable (invitation slips by an hour) or does the chosen hour need to hold? → `bmad-architecture`.
9. ~~Model API access path and proxy design~~ — dissolved for v1 on 2026-08-21. BYOK (FR-28) removes the proxy entirely: no auth flow, no key custody beyond the OS keystore, no request logging, no scaling question. What survives is narrow and already lives in FR-28 — where the key is stored, and what the app does when it is invalid or exhausted (FR-29). The full proxy design returns with the Managed path (§5.1). → `bmad-architecture`, reduced scope.
10. Which providers pass the FR-28 allowlist gate — written no-training and no-retention terms, verified in the provider's own terms and dated at verification — and what the app does when a listed provider changes those terms after ship. Silent removal from the list strands a user's configured key; leaving it listed voids the guarantee FR-25 rests on. → `bmad-architecture` picks the initial list; the stale-terms behaviour is a product decision for Sergio.
11. Does Manual Capture accept non-spatial work at all — "llamar al dentista", "entregar el formulario"? The engine is spatial throughout: FlyLady zones, photos of rooms, clutter, "≈ 3 cajas liberadas". Manual Capture (FR-27) is the first entrance through which non-spatial work can reach the pool, and both answers cost something. Accepting means three of the glossary's size labels (Instant Habit, Micro-maintenance, Focus Chunk) mislead for a subset of the pool, and FR-4's energy filter has no criterion for a phone call. Refusing means the app tells the user their task does not belong here, which is a small shaming of its own. Voice (FR-32) raises the stakes without changing the question: dictation makes "llamar al dentista" the cheapest thing in the whole product to capture, so whichever answer is chosen will be exercised harder than a keyboard would have exercised it. → `bmad-ux`, before FR-27 is built.
12. Does excluding clock-bound work leave a hole the user feels? The catalogue ships the dishes and skips the cooking that produced them. That is coherent for the engine — the Floating Time Bag has no hour, so a task with one cannot be dealt (§5.2, FR-31) — and it may read as arbitrary to someone standing in the kitchen at eight in the evening. The exclusion is philosophical and not up for phasing; what is unwritten is the copy, because nothing currently explains why the app knows about the plates and not the meal. Same underlying question as OQ-11 — what this app is for — and they should be answered together. → `bmad-ux`.
13. When on-device Spanish recognition is unavailable, FR-32 makes the microphone simply absent and says nothing about it. May settings carry a one-time pointer to the system's own language-pack installation, and if so, how — given that a pointer is a small piece of pending work planted in the one surface §7 reserves for the validator? Absent-and-silent is the standing answer, and the argument against it is real: someone who never sees a microphone concludes the app has no voice at all and never goes looking. → `bmad-ux`.


## 10. Parameters and Assumptions

### 10.1 Confirmed Parameters (2026-08-20)

Fixed decisions, not assumptions. Downstream workflows may treat these as given; they are validation-build values chosen for a single user and expected to be revisited with real usage data, not tuned mid-window.

| Parameter | Value | Where |
|---|---|---|
| Rescue Mode trigger | soft heuristic: declined on 3 different days; or user request anytime | FR-5 |
| Warm Return trigger | ≥ 48 h of absence | FR-6, §3 |
| Time Bag | default 15 min, range 5–30 | FR-7 |
| Anti-Marathon checkpoint | default 15 min, configurable 10–15 — a rest offer, never a session limit | FR-10 |
| Quarantine Box follow-up | 6 months, one suggestion only | FR-21 |
| Snowball condition | ≥ 10 comfortable days, suggests +≤ 5 min | FR-23 |
| Notifications | exactly one opt-in silent daily invitation, off by default | FR-24, §5.2 |
| Validation window | 4 consecutive weeks | §8 |
| Photo uploads | per-scan consent only, no blanket opt-in; face/person frames refused on-device | FR-25 |
| Instrumentation | local-only, four series, no analytics SDK | FR-26 |
| AI Access Path | BYOK only in the validation build, against a vetted-provider allowlist; Local and Managed are interface-only. No account, no login, no proxy, no developer-held data. Managed, when built, is non-expiring credits — never a subscription (§5.2). | §7, FR-28, §5.1 |
| Manual Capture | always available; one Micro-task per capture, three sizes (30 s / 3 min / 10–15 min); typed or dictated; no list, no editing once the capture surface is left | FR-27, FR-32 |
| Archetype Templates | two kinds: Evergreen ships pre-sliced as product content; Epic seeds are Slicer input only | FR-11, §3 |
| Evergreen Library | three cadences (daily anchors + Baseline Upkeep / weekly zone routines / monthly-seasonal), pre-sliced at build time; ≥ 45 distinct non-daily entries so 28 consecutive Focus Chunks never repeat | FR-31, A12 |
| Time Bag coverage | budgets advance work (the Focus Chunk) only; Baseline Upkeep and Instant Habits sit outside it. Session length is bounded by the declared pocket, not by the budget | FR-7, FR-12, FR-8 |
| Clock-bound tasks | excluded from the catalogue entirely — no entry carries an hour, a mealtime or a before/after dependency. Cooking is out; post-meal upkeep is in | FR-31, §5.2 |
| Catalogue curation | cluster level only (zones and upkeep groups), in onboarding and settings; never task level, never from the Dispenser, never user-authored | FR-31 |
| Manual Capture deal latency | dealt within 3 days of capture, ahead of same-size Evergreen/Epic material | FR-12, FR-27 |
| On-device candidate | Gemma 4 E4B (Android, native multimodal, released 2026-04-02) — exists; slicing quality unproven | OQ1 |
| Task origin tag | every Micro-task tagged `shipped` / `manual` / `local` / `cloud` | FR-26 |
| Export | automatic and silent, foreground-triggered, to a user-chosen local folder; state visible in settings only | FR-30, §7 |
| Local path in v1 | ships as a debug-only canned-slice stub, so the access interface has two callers | FR-28 |
| FR-29 copy | the seven no-Slicer strings authored before the failure path is wired; part of the SM-C2 audit | FR-29, §7 |
| SM-2 instrument | one in-app 5-point question, Sundays | §8 |
| Voice input | dictation into Manual Capture's single line only; on-device recognition; no cloud fallback; keyboard always retained; nothing parsed out of the transcript | FR-32, §5.1 |
| Voice audio handling | never stored, never exported, never transmitted, never in any FR-26 series; the transcript is the only artifact | FR-32, §7 |
| Microphone affordance when unavailable | absent and silent — no error, no greyed state, no install offer; permission asked at first use, never at first run | FR-32, OQ-13 |
| Keyboard dependency | none anywhere in the build; every surface that asks for writing has a wordless or spoken route | §7, FR-32 |
| Working title | "Anti-Overwhelm Mobile Task Organizer" (product naming deferred) | frontmatter |

### 10.2 Remaining Assumptions

- §4.11 FR-31 — the library is assumed broad enough that a 28-day window never repeats a non-daily Micro-task, and that literal non-repetition is enough to avoid prompt blindness. It may not be: blindness can set in on category rather than on task ("otra vez el baño") well before any entry comes round twice. FR-26 series (a) would show it as sessions shortening across the window with no matching change in energy reports.
- §4.11 / §4.2 — Baseline Upkeep sitting outside the Time Bag assumes Sergio reads the budget as "time I give to getting ahead" rather than "time I give to the house". If he reads it the second way, FR-23's dashboard will feel like it undercounts his day: the dishes are done and the number did not move. The dashboard already shows cumulative minutes, so the remedy if this appears is a display decision, not a model change.
- §4.11 — the catalogue is assumed to fit an ordinary Spanish flat well enough at cluster granularity. It was authored for one home. A cluster that does not apply (no terrace, no car) is disabled whole, and there is deliberately no finer control — per-task opt-out would be the browsable list FR-31 refuses.
- §4.4 FR-16 — with latency demoted (OQ1 ruling), the remaining scan-experience assumption is that an in-app wait with visible progress stays acceptable on mid-range hardware; the 30 s budget is gone, and price-reasonableness rests on current market levels until monetization is designed.
- §4.4 — cloud vision processing is acceptable for validation privacy provided the provider does not retain or train on uploads. This is no longer an assumption about one chosen provider: FR-28's allowlist makes verified terms a build-time gate, so the residual assumption is only that at least one provider with written no-training, no-retention terms is available and affordable at validation time (OQ10). Professional pay-per-use APIs commonly exclude training, but not universally and not by default.
- §1/§2 — the builder (Sergio) is the primary validation user; his wife and sister-in-law run independent single-user instances as an annex (their counters are never merged into SM-1–SM-3). The data model is single-user throughout because projects are personal portfolios, not household entities — two people sharing a home are two parallel users, and the app coordinates nothing between them. The household/multi-user vision (§5.1) is knowingly untested by this build.
- §4.4 — deployment topology stays open until real-photo tests. Gemma 4 E4B removes the existence doubt (§4.4, OQ1) but not the quality one, and the builder's separate doubt — that not every future user's phone could run a local model — remains a scale-phase question, not a validation one. The three-path access interface (FR-28) is what makes that doubt cheap: it is a configuration, not a rewrite.
- §4.9 FR-27 — Manual Capture's three coarse sizes are assumed sufficient for the Project Weaver's budget arithmetic (FR-12). Free-form minutes were rejected deliberately: a user's minute estimate is the least reliable number in the system, and the three sizes are already the 1-3-5 taxonomy, so a manual task lands in the composition without a conversion step. If manual estimates wreck the budget math, the failure shows up as sessions overrunning the Time Bag, which FR-26 series (a) already records.
- §4.9 / §4.3 FR-13 — the Invisible Buffer absorbs deferrals and absences, not estimation error. Manual Capture introduces a third source of slack demand FR-13 was never designed for: self-estimated durations, which humans systematically underestimate. The predicted failure path is arithmetic rather than tonal — sessions overrun, the Anti-Marathon Checkpoint fires more often, and a checkpoint that fires too often stops reading as permission and starts reading as interruption. FR-12 now records the origin mix so this is detectable; no calibration is attempted in v1.
- §8 SM-4 — BYOK biases SM-4 against itself. A8 requires that Sergio never hesitate before shooting a photo, and BYOK puts a real metered bill in front of him that the Managed path's flat fee would have hidden: the cheapest path to build is the worst one for the thing being validated. Assumed mitigation for the window: buy a fixed credit up front so no meter is visible during the 4 weeks. If hesitation still appears, SM-4 is reading the payment model rather than the hook.
- §4.9 FR-27 — Manual Capture is assumed not to cannibalize the photo loop. It might; SM-4 is now written to detect exactly that. The alternative — withholding a manual entrance to protect a metric — would make the app unusable on day one in order to keep a measurement clean, which is the wrong trade (addendum A9).
- §4.9 FR-32 — on-device Spanish recognition is assumed present on the validation devices and accurate enough on household vocabulary that accepting a transcript is the common case and correcting one the exception. Both halves are unverified and they fail differently. If accuracy is poor the keyboard absorbs it silently (FR-32 keeps it), and voice simply reads as noise rather than as a broken feature. If *availability* is poor, the accessibility floor §7 now claims is void on those devices — and that is the claim to test against a real handset first, because it is a promise about who can use the app rather than a convenience.
- §4.9 FR-32 / §5.2 — voice is assumed to lower the cost of capture without raising its volume enough to turn the floor into the road. It may not: a capture that costs three seconds of speech invites exactly the head-emptying that a pool with no visible bottom and no list has no answer for, and the Weaver's deal-within-3-days rule (§10.1) would then crowd Evergreen and Epic material out of the day. FR-32's dictation boolean read against SM-4's origin mix is what shows it — Focus Chunks dominated by `manual` captures that were mostly dictated is this failure, distinct from the payment-model failure A9 predicted. No throttle, cap or warning is built in v1; §1.1 principle 6 already names who has violated the design if a list appears as the remedy.
- §8 SM-2 — a 1-point shift on a 5-point single-question self-report by a single self-aware user is taken as meaningful signal. The instrument is now fixed (SM-2), so this is an assumption about the reading, not about the measurement. Ruling 2026-08-20: no blinding, no anchor item — the validation is deliberately not a rigorous study. Annex subjects' weekly answers and general observations are anecdotal color ("how the app feels"), never statistical evidence; the primary user's own within-subject reading carries the verdict.

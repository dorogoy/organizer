---
title: Anti-Overwhelm Mobile Task Organizer
status: final
created: 2026-08-20
updated: 2026-09-01
---

# PRD: Anti-Overwhelm Mobile Task Organizer
*Working title, confirmed 2026-08-20 for the validation build; product naming deferred.*

## 0. Document Purpose

This PRD specifies the validation build of the Anti-Overwhelm Mobile Task Organizer: a single-user Android app that turns household and personal chores into one micro-action at a time, distributed across days, with zero guilt mechanics. Audience: the builder (PM + implementer) and downstream BMad workflows (`bmad-ux`, `bmad-architecture`, `bmad-create-epics-and-stories`). It builds on the brainstorming session `brainstorm-app-tareas-sin-agobio-2026-08-20` (authoritative intent document) and does not duplicate it; competitive-landscape detail and technology options live in `addendum.md`. Vocabulary is Glossary-anchored; §10 is the single record of confirmed parameters and remaining assumptions — no inline assumption tags remain in the body, and FRs cite `Values: §10.1` rather than restating numbers. Revision history lives in the Changelog at the end of the document; the body states current rules only.

## 1. Vision

Traditional task managers fail overwhelmed users psychologically: endless lists, red overdue badges, broken streaks, and rigid time blocks turn productivity into shame. This app is the opposite — an **empathetic autopilot and cognitive shock absorber**. It tells the user exactly which single small action to do right now, absorbs guilt when life happens, and guarantees steady progress on big chores by distributing them as micro-actions across days.

The engine combines FlyLady zone cleaning with the 1-3-5 rule, automatically weaving tasks from recurring routines and dormant epic projects (storage room, seasonal closet switch) into a modest daily time budget. A "Floating Time Bag" replaces rigid scheduling: the user commits minutes-per-day, not hours-on-the-clock, and triggers a session whenever a pocket of free time appears. AI photo-diagnosis makes setup effortless — snap a picture of the messy space and the app returns a precise sequence of 3–5 minute micro-steps, later rewarded with a before/after visual diff.

The differentiating loop — photo → micro-plan → visual reward — rests on multimodal vision being accurate enough to slice real clutter at a price worth paying per scan. Open Question 1 settles it, against the cost target in the addendum. This build validates the concept with the builder as the primary user: **success is sustained real usage, a felt reduction in overwhelm, and visible progress on a real epic project — without marathons.**

### 1.1 Principles (invariants)

These govern decisions the FRs did not anticipate. Where an FR and a principle conflict, the principle wins and the FR is wrong.

1. **Zero cognitive load.** The user never chooses from a list of pending work, and any new surface offers at most one recommended action plus a way out. Fixed answer options to a single question — a size, an energy, a destination, a scale point — are answers, not lists; what this principle always abolishes is the enumeration of the user's pending work.
2. **Uncompromising anti-shaming.** No red, no overdue, no streak, no count of anything undone — and what is forbidden is *showing* one. Internal, invisible signals a mechanism needs (FR-5's decline heuristic, the snowball's run of comfortable days) may exist; they count only what the user did, never what they didn't, and they are never surfaced. If a feature needs to represent failure or absence to the user to work, it does not ship.
3. **Respect for spontaneity and variable energy.** Every plan is regenerable. Nothing the user does away from the app can invalidate it, and leisure is never a cost.
4. **Invisible buffers.** Slack is never shown, never configurable, never spendable by the user — a visible buffer is a deadline with extra steps.
5. **Anti-marathon.** The app never encourages more than it asked for. No "keep going" is ever a primary action. And no walls: the app guides, the user decides — session length included. Extending a session is always the user's active act; the app never asks "shall we continue?", because a question that appears after every session exhausts as much as a nag.
6. **The Slicer authors everything personal.** Evergreen material — the whole shipped Library: daily anchors, Baseline Upkeep, the FlyLady zones and the seasonal upkeep (FR-31) — is product content: sliced at build time and shipped, identical for every user because the methodology is published, needing no network, key, model or first-run cost. Everything specific to *this* user's home and life comes from the Slicer: Epic Projects, photo slicing, re-slicing. Without a reachable Slicer there is no personal slicing — what remains is the shipped Evergreen day, Manual Capture (§4.9) as the floor, and the dispensing of what already exists. An offline app executes; it does not beget. And Manual Capture never grows into a task manager — the moment it acquires a list, this principle has been violated by whoever added the list.

**Declared exceptions to principle 1 (UX session `ux-organizer-2026-08-21`).** Principle 1 is amended in exactly one named place, the builder's explicit decision in that session, and the clause itself is not weakened anywhere else. It is registered here rather than absorbed at the surface that needed it, because an invariant that overrides FRs cannot be bent without the bend being written down. An exception exists only where this register names it: nothing further is implied by silence, and no other surface may borrow it.

- **E1 — the Archetype Template selection surface shows a list.** An exception to *"the user never chooses from a list"*. It is a complement offered from the genesis surface — a help, not a primary path — and that is what pays for the list; the clause itself stands and still governs every other surface. **This does not touch NL-1 (§5.2).** Archetype Templates are product content; captured tasks are not. No screen gains the power to enumerate captured tasks, edit them, or let the user browse what is pending — that exclusion stands entire, and a later reader must not read E1 as a crack in it. Consequences: FR-11, FR-31.

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
  Sunday's first opening carries the weekly question — *"Esta semana, ¿cuánto te ha agobiado la casa?"* — and he answers it in one tap; the energy check-in takes the freed slot in the same breath: 🔴 Low Battery. The Dispenser instantly re-filters to instant habits and 30-second micro-actions; the planned Focus Chunk disappears without comment. Later in the week he skips a task three days running; instead of nagging, the app contracts it into a 30-Second Rescue micro-step: *"Just pick up 3 items off the floor."* He does it, which counts.

- **UJ-5. Sergio anota algo a mano en diez segundos.**
  Something occurs to Sergio that the app cannot know and no photo can reveal: he promised to water the neighbour's plants. He taps Manual Capture from the Dispenser, holds the microphone and says it out loud — *"regar las plantas de la vecina"* — the words land in the line, he picks "3 min" from three sizes, and it is out of his head. No project, no category, no date, no confirmation screen. Had the recognition heard *la vecina* as *la vitrina*, he would have fixed it right there on the capture surface, because that is the last moment it can be fixed (FR-32). Days later it surfaces as an ordinary dealt card, indistinguishable from a sliced one. He never sees a list of what he has captured, because there is no list. On the day his API key expires, this is the only path still working — and the app keeps being useful without saying a word about it.

## 3. Glossary

- **Micro-task** — The atomic unit of work: 30 seconds to 15 minutes, always with a duration estimate. Served one at a time by the Dispenser. (The intent document capped micro-actions at 10 min; widened deliberately so a Focus Chunk fits at the top of the range without a second unit.)
- **Dispenser (Single-Task Dispenser)** — The primary UI surface: exactly one Micro-task card with Done / Skip actions, plus a small set of quiet entrances — the camera entry (FR-16), Manual Capture (FR-27) and the single quiet affordance to the genesis surface (FR-11) — and at most **one ambient element visible per opening**: the daily energy check-in (FR-4), the weekly self-report while it is pending (§8 SM-2), or a one-time suggestion (FR-15, FR-31); the rarer instrument outranks the daily one (FR-4). No lists, no calendars.
- **Genesis surface** — Where a personal project is begun by writing: opened from the Dispenser's single quiet affordance, with typed entry as its one recommended action and settings as its way out (FR-11). The photo path to the same goal is the Dispenser's camera entrance, not part of this surface.
- **Focus Chunk** — The "1" of the 1-3-5 composition: the slot, occupied by one 10–15 min Micro-task drawn from the active Epic Project, the active weekly zone, the `fondo` cluster filling in (FR-31), or a pending manual capture by precedence (FR-12). *Focus Chunk* names the slot; 10–15 min is the size that fills it — the two travel together by construction, and a day never holds two.
- **Micro-maintenance** — The "3" of the 1-3-5 composition: 2–3 min recurring upkeep tasks across common areas.
- **Instant Habit** — The "5" of the 1-3-5 composition: ~30 s daily anchors (wipe sink, ventilate, drink water).
- **Floating Time Bag** — The daily flexible minutes quota the user commits to, spent on demand instead of fixed appointments; budgets advance work only (FR-12). Values: §10.1.
- **Energy Level** — 1-tap capacity state: 🟢 High / 🟡 Medium / 🔴 Low. Asked once per day at the first opening, skippable, defaulting to 🟢 (FR-4). Filters the eligible Micro-task pool.
- **Rescue Mode** — Unsticking of a stuck or user-flagged Micro-task by re-slicing it into 2–4 steps of ≤ 60 s each, via its Origin Context (FR-5). Values: §10.1.
- **Anti-Marathon Checkpoint** — The recurring rest offer inside a session: explicit permission to stop, never a wall; sessions shorter than one interval end without one (FR-10). Values: §10.1.
- **FlyLady Zone** — One of the rotating weekly household areas (kitchen, bathrooms, …) with pre-configured routine Micro-tasks. Cardinality: exactly one active zone per day.
- **Archetype Template** — A pre-configured starter for Evergreen material (zero blank page): the Evergreen Library itself, shipped as pre-sliced product content (FR-31). One kind only — an Epic Project is never templated, and a template never stands in for the Slicer on personal material (FR-11, FR-29).
- **Evergreen Project** — High-frequency recurring project: daily anchors, weekly zones, monthly upkeep. Active by default on a fresh install; its entries appear only while its cluster is enabled under curation (FR-31).
- **Evergreen Library** — The catalogue of pre-sliced Evergreen Micro-tasks that ships in the build, spanning three cadences and carrying size, cadence and zone on every entry. Breadth requirement: FR-31. Content: addendum A12.
- **Baseline Upkeep** — Recurring daily household work the user does with or without the app (dishes, table, dishwasher, closing the kitchen): part of the Evergreen Library, not charged to the Time Bag (FR-12), distinct from Instant Habits by size (3–15 min vs 30 s).
- **Epic Project** — Low-frequency/seasonal project (organize storage room, wash curtains, closet switch). Dormant by default; activated on demand or by seasonal suggestion.
- **Project Weaver** — The engine that composes each day's 1-3-5 budget by weaving Micro-tasks from active Evergreen and Epic Projects. The user never browses folders.
- **Invisible Buffer** — Background temporal slack added to Epic Project targets so deferrals and absences are absorbed without moving visible deadlines.
- **Silent Rescheduler** — The mechanism that rebalances unfinished Micro-tasks into future days without overdue states, notifications of failure, or user-visible debt.
- **Photo-Diagnosis** — Cloud AI analysis of a space photo: clutter detection, object classification, micro-step generation with effort estimation (the Smart Slicer).
- **Smart Slicer** — The component that converts an input (photo, text, or form) into a sequence of 3–5 min Micro-tasks with per-step duration tags. Reached through any AI Access Path behind one interface, so the path is swappable without touching anything else.
- **Manual Capture** — The floor of task genesis: one line, typed or dictated (FR-32), and one of three sizes; available always, with or without AI, network, key or account. Never a list (NL-1), never browsable, never editable once left. Details: FR-27, FR-32.
- **AI Access Path** — How the app reaches a Slicer: Local, BYOK or Managed behind one interface; the validation build ships BYOK only. Details: FR-28, §4.10.
- **Origin Context** — The retained structured description of a task's source — photo-diagnosis output, form data, or free text — kept when the raw input is discarded, and reused to re-slice or regenerate tasks without re-capturing input. Tasks never come from nothing: everything personal comes from information the user provided, and the shipped Evergreen material comes from published methodology sliced at build time (§1.1 principle 6). A Manual Capture's Origin Context is its own single line and nothing more — enough for FR-5 to re-slice it when a Slicer is reachable, and nothing at all when none is. A `shipped` task's Origin Context is its **Spanish catalogue name**, one line of text, exactly the shape a Manual Capture's is: no field is added to the catalogue (FR-31), because the name already lives in the string table (§7, addendum A12) and is resolved by the entry's key — so a catalogue entry is rescuable on the same terms as a captured one (FR-5).
- **Before/After Reward** — Visual diff between the initial clutter photo and the post-completion state, saved to the Transformation Album.
- **Transformation Album** — Local, private gallery of Before/After pairs and progress milestones.
- **Decluttering Protocol** — Pre-clean purge sequence injected before organizing projects: detachment questions, 3-Destination Flow, Quarantine Box.
- **3-Destination Flow** — Item triage: Keep / Donate-Sell / Trash-Recycle — internal concept names, never shown; surfaced labels `Quedármelo` / `Donar o vender` / `Tirar o soltar` (FR-20 owns the labelling rationale).
- **Quarantine Box** — Dated physical box for emotionally hesitated items; a blind timer on the date alone suggests donation when it elapses (FR-21). Values: §10.1.
- **Warm Return** — The welcome-back state after an absence: clean reset, rebalanced plan, no backlog display. Threshold: §10.1.
- **Ambient Invitation** — The single optional daily notification: silent, motivating and kind, at a user-chosen hour — an invitation, never a recalled debt (FR-24).

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
- When the eligible pool runs out mid-session, the session closes early with neutral, warm copy ("por hoy no hay nada más que merezca la pena") — never an error, never an empty state styled as absence or debt. The string is part of the SM-C2 audit table (§7).

#### FR-4: 1-tap daily energy check-in
The user can set Energy Level (🟢🟡🔴) in one tap, offered once per day as a check-in at the first opening; the eligible Micro-task pool filters immediately. Realizes UJ-4.

**Consequences (testable):**
- The check-in is a daily surface, not permanent furniture: it appears at the day's first opening and never again on re-opens within that day, skippable in one tap; once answered or dismissed it is gone for the day — a dismissal is a skip-for-today, never re-shown within the day and never styled as pending. The one element that can precede it at a first opening is the weekly self-report (below).
- Energy defaults to 🟢 every day and never decays on its own. The check-in exists to ask for less, never to clear a gate: the pool stays wide until the user narrows it, and a user who never answers it loses nothing. A decay toward 🟡 late in the day was considered and rejected — it would shrink the pool precisely during the app's real usage window and would turn an ambient, optional check-in into a necessary correction.
- The weekly self-report (SM-2) is the rarer instrument and outranks the check-in whenever it is pending: from the first Sunday opening until answered that week, it holds the slot at every first opening, on any day. The handoff is deterministic — once the self-report clears the slot, answered, or dismissed for that opening alone (a dismissal hides it until the next opening, never for the week: SM-2), the check-in takes the slot in that same opening if it has not already been resolved that day. Each is one tap, nothing nags after; a day that ends without the check-in having shown is carried by the 🟢 default and owes nothing.
- The check-in presents the three levels as direct tap targets — the one-tap property is the whole mechanism — and nothing else.
- On 🔴, Focus Chunks are excluded from the pool; only Instant Habits and ≤60 s Micro-tasks remain. This is the only exclusion any level defines: 🟢 and 🟡 filter nothing and deal from the full pool — a day of middling energy is not a smaller day.
- A 🔴 tapped while the check-in is open with a card in progress behaves like the checkpoint (FR-10): the card in progress can be finished; the filter applies to the next deal, never to the active card. Work in progress is never withdrawn without comment. Outside the open check-in no energy control exists to tap mid-task — simplifying the *current* task is Rescue Mode's job (FR-5), not an energy change.
- Pool re-filters in under 500 ms after the tap.

#### FR-5: Rescue Mode (task unsticking)
A stuck Micro-task is unblocked by re-slicing it into much simpler steps. Two triggers: (a) automatic heuristic — the same Micro-task is dealt and declined on the trigger number of different calendar days (§10.1), a soft signal to attempt unsticking, not a rigid rule (days of absence, days the task was not dealt, or energy filtering neither increment nor reset the count); (b) user-initiated — the user asks to simplify the dealt Micro-task at any time, without waiting for any counter. Realizes UJ-4. Values: §10.1.

**Consequences (testable):**
- On trigger, the system requests a re-slice from the Slicer through the FR-28 access path, using the task's Origin Context — no new photo is taken or re-processed.
- **A `shipped` catalogue task is rescuable, and its Origin Context is its Spanish catalogue name** (§3) — one line, the same shape a Manual Capture's is. One Origin Context shape for the whole product, rather than two that each fit their own source better: name-plus-zone was considered and rejected on that ground, the catalogue names being self-locating anyway. A pre-authored rescue stored in the catalogue was rejected too — it violates FR-31's fields-and-no-more rule and would mean authoring product content for 85 entries — and not-rescuable was rejected as a real product loss, since the most-repeated tasks in the app are the shipped ones, precisely the case Rescue Mode exists for.
- **What that costs and does not cost.** No field is added to the catalogue: the name is resolved from the string table by the entry's key (FR-31, §7). Rescue steps still inherit origin `shipped`, so SM-4's origin arithmetic is untouched. Offline, a shipped task's rescue degrades per FR-29 like any other — the original stays dealable, nothing is queued (§1.1 principle 6: an offline app executes, it does not beget). And nothing enters the catalogue: rescue steps are transient pool facts, and FR-31's "fixed at build time, the user cannot author, edit or extend it" stands entire.
- The re-slice returns 2–4 simpler steps, each ≤ 60 s; steps enter the queue one at a time, woven by the Project Weaver, tonally indistinguishable from any other Micro-task.
- Completing all rescue steps marks the original Micro-task done; activating the rescue resets the refusal counter, success or failure — an attempt that degrades per FR-29 because no Slicer is reachable has already reset it, so a failed rescue does not re-trigger on every subsequent deal, and the user-initiated path remains available at any moment (no cumulative skip totals exist — FR-26).
- Rescue depth is capped at 1: a rescue step can never itself be rescued.
- A rescue whose steps are themselves declined on 3 different days dissolves the original task silently — out of the pool, no state, no notice. Nothing is re-woven forever; the task's history survives in the FR-26 series and the export (FR-30), which is where a dissolved task is read.
- A rescue with no reachable Slicer degrades per FR-29: the original task stays dealable as-is, nothing is queued, and no error state appears. A manually captured task with no Slicer at all cannot be rescued, which is stated plainly at the moment of asking and never as a failure.

#### FR-6: Warm Return
After an absence past the Warm Return threshold, the user is received with a warm reset: rebalanced plan, no backlog, no reference to missed days in any UI element or copy. Realizes UJ-3. Values: §10.1.

**Consequences (testable):**
- No "you missed N days" copy, overdue badge, or broken-streak indicator exists in the entire app.
- After absence, first dispensed card comes from the silently rebalanced plan.

### 4.2 Floating Time Bag & Session Control

**Description:** Flexible daily time commitment with an ad-hoc session trigger and an anti-marathon rest checkpoint. The user commits minutes per day, not schedule slots; sessions start when a real pocket of time appears; interruptions save progress silently. Realizes UJ-1.

**Functional Requirements:**

#### FR-7: Daily floating time budget
The user can set a daily Time Bag inside the confirmed range and default. Values: §10.1.

**Consequences (testable):**
- Budget persists until changed; changing it mid-day never invalidates completed work.
- The 1-3-5 composition adapts to the current budget (see FR-12).
- The budget covers **advance** work only — the Focus Chunk. Baseline Upkeep and Instant Habits are not charged to it (FR-12): they happen with or without the app, and a budget that pays for the dishes leaves nothing for the Epic Project SM-3 measures.
- With a Time Bag below 10 minutes no Focus Chunk fits, and the day composes without one — the "1" is absent, silently, with no debt and no mention: the same mechanism as a 🔴 day (FR-4, UJ-4). The budget buys what it can hold.
- The bag bounds the day's **total** advance, not just one composition: once the day's Focus Chunk has been dealt — or its rescue steps (FR-5) — later sessions that day compose of upkeep and habits only, silently, with no budget-exhausted state anywhere. Chaining sessions cannot multiply advance, and SM-C1 keeps its reference.

#### FR-8: "I have X minutes now" trigger
The user can start an ad-hoc session declaring available minutes; the Dispenser deals Micro-tasks fitting that pocket.

**Consequences (testable):**
- Dealt tasks' estimated durations sum to ≤ the declared pocket.
- The session runs to the declared pocket; the Anti-Marathon Checkpoint (FR-10) offers rest at each interval within it, and never ends the session by itself.

#### FR-9: Pause and silent recalculation
The user can interrupt a session at any moment; partial progress is saved and remaining minutes roll back into the Time Bag without penalty states.

**Consequences (testable):**
- No interrupted, incomplete, or overdue state is ever displayed anywhere — in either language.
- Resuming deals the next Micro-task directly — never a resume menu about the past.
- Only unspent pocket minutes of advance work return to the Time Bag on pause; minutes spent on Baseline Upkeep or Instant Habits never entered it and return nowhere — the advance/upkeep split FR-12 draws, applied to the pause.

#### FR-10: Anti-Marathon checkpoint
A session offers rest at every multiple of the checkpoint interval with an explicit permission-to-stop screen. The checkpoint is a rest offer, not a wall: continuing past it is exclusively a user-initiated action. Sessions shorter than one interval simply end, and their close is the permission to stop — an offer a short pocket cannot hold is never manufactured. The app guides, the user decides — session length included. Values: §10.1.

**Consequences (testable):**
- At the checkpoint the current Micro-task can be finished; the permission-to-rest screen is the primary surface.
- The offer repeats at each interval boundary in sessions longer than one interval: a 45-minute pocket with a 15-minute checkpoint offers rest three times. A session shorter than the interval reaches no checkpoint — its close (FR-8) already is the permission to stop. When the final checkpoint coincides with the close, that close is the offer (UJ-1).
- No continuation question exists anywhere in the app — a recurring "¿seguimos?" is a nag in interrogative form. Extending is an available, silent, secondary action the user takes; the app never highlights, animates, or suggests it.
- The session runs to the user's declared length; the user may extend it actively at the end via the same silent action.
- Stopping is always one tap (FR-9), at any moment, for any reason.

### 4.3 Project Weaver — FlyLady + 1-3-5 Hybrid Engine

**Description:** Dual-lifecycle project structure (Evergreen + Epic) automatically woven into each day's 1-3-5 composition. The Evergreen material it weaves is the shipped library specified in §4.11; Epic material comes only from the Slicer. Epic Projects carry Invisible Buffers; deferrals and absences are absorbed by the Silent Rescheduler; dormant Epics may be gently suggested by seasonal triggers. The user never manages folders or triages categories. Realizes UJ-1, UJ-2, UJ-3.

**Functional Requirements:**

#### FR-11: Dual-lifecycle projects with archetype templates
Evergreen material arrives active by default from the pre-sliced Evergreen Library (daily anchors, Baseline Upkeep, 5 FlyLady zones, monthly/seasonal upkeep — FR-31), and curation enables or disables its clusters; Epic Projects are created from a photo or from a typed/form description — always through the Slicer, never from a template.

**Consequences (testable):**
- Fresh install reaches a working 1-3-5 day with zero typing, zero network, zero key and zero model: the whole Evergreen Library ships pre-sliced (FR-31, addendum A12). This is product content, honestly labelled as such, not a Slicer substitute.
- No Epic Project is ever created from a template. Epic material always comes from the Slicer, from input the user supplied (FR-16, FR-28).
- With no Slicer reachable the Evergreen day works and Epic Projects cannot be created; the app names which is which plainly rather than implying the whole product is degraded (FR-29).
- Exactly one FlyLady Zone is active per day, rotating weekly over the *active* clusters: the week of a disabled zone passes to the next active zone, so curation never leaves a day without an active zone (FR-31).
- Epic Projects are dormant until activated and do not appear in any default view while dormant.
- Genesis is multi-path, and the photo is an invitation rather than a gate. The photo path is a direct one-tap camera entry on the Dispenser itself (FR-16) — UJ-2's "one tap to Scan" — an add-work entrance sitting beside the day's card, not a departure from it. Typed/form entry is reached through the Dispenser's single quiet affordance, which opens the genesis surface with typed entry as its one recommended action and settings as the way out. Neither entrance is a precondition for the other, and reaching manual entry costs one tap and asks for no reason (*"no podemos obligar a la gente a que use el sistema de fotos si no quiere"*). This squares FR-11's multiple genesis paths with principle 1 structurally: the camera is an entrance, not a decision surface, and the genesis surface itself carries exactly one recommended action plus its way out — no surface holds two recommended actions, so no exception is owed (UX session `ux-organizer-2026-08-21`).
- The Archetype Template selection surface enumerates templates and clusters, and opens from the genesis surface as a complement — never as a third top-level genesis path (§1.1 exception E1, same session). Selecting a template enables or disables Evergreen clusters only; it never creates an Epic Project, which this list's "no Epic Project is ever created from a template" consequence forbids.

#### FR-12: Automatic 1-3-5 weaving
The system composes each day's queue as 1 Focus Chunk (10–15 min, from the active Epic Project, the active zone, or the `fondo` cluster filling in when the zone's eligible entries run out — FR-31) + 3 Micro-maintenance tasks + 5 Instant Habits, scaled to the current Time Bag and Energy Level.

**Consequences (testable):**
- Composition respects the budget on advance work: the Focus Chunk's estimated duration is ≤ the Time Bag. A Time Bag below 10 minutes composes the day without a "1" altogether (FR-7) — nothing is owed. Baseline Upkeep and Instant Habits are composed alongside it and are not charged to the budget — they are work the day already contains, and the app's job there is ordering it, not rationing it.
- The Focus Chunk slot is **reserved for advance work** — the active Epic Project, the active zone, or `fondo` filling the zone's gap (FR-31) — and Baseline Upkeep never occupies it, however well its size fits. Upkeep fills the "3" and may add at most one 10–15 min item per day (lavar los platos, dejar la cocina cerrada). Without that reservation the dishes would take the Epic's slot on their size alone, and SM-3 would stop being measurable.
- Anti-marathon is enforced by the session, never by the budget: everything dealt inside one session — upkeep included — still sums to ≤ the declared pocket (FR-8). An unbudgeted class of tasks can therefore never produce an unbounded session.
- The canonical 1-3-5 sums to roughly 26 min (≈15 + 9 + 2.5); under the advance/upkeep split only the Focus Chunk is charged against the bag, and 15 against 15 exceeds nothing. Scaling drops upkeep and habits by count, never by shrinking a Micro-task's own estimate.
- Composition is regenerable (not fixed): skipping one element re-weaves the rest, never "fails the day".
- Manually captured tasks (FR-27) take precedence over Evergreen and Epic material of the same size, and are dealt within the confirmed window (§10.1). This is the only privilege Manual Capture has, and it exists because a capture that can sit undealt for a week teaches the user not to trust the capture — and a capture surface nobody trusts gets used twice, once here and once in a notes app.
- The deal window advances only on days the capture was actually eligible for dealing: a 🔴 day (FR-4) or an absence (FR-6) freezes it, exactly as FR-5 freezes its own counter on days its task was not dealt. At the return there are no "expired" captures, because the schema has no overdue (§7) — the window simply resumes where it froze.
- Within a size, pending captures deal oldest-first (FIFO). There is no expiry and no cap on the backlog: silently deleting a capture betrays the trust the deal window exists to protect. The displacement risk — captures crowding out Evergreen and Epic material — stays instrumented (§10.2, FR-26 origin mix): measured, not punished.
- A pending manual capture of 10–15 min occupies the Focus Chunk slot for the day — it *is* the "1", by the precedence above — and the day never holds a second large item beside it. "Focus Chunk" names the slot and the slot is one (§3); two 10–15 min items in one day is a marathon with a comma.
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

**Description:** Cloud multimodal vision analysis that turns a photo of a messy space into a structured micro-plan, plus the before/after reward loop — the differentiating hook, in the validation build by explicit decision. One acknowledged deviation: the intent document justified the mobile form factor partly on on-device processing, and this build assumed cloud slicing instead; the topology stayed open, and the local candidate is concrete rather than hypothetical — Gemma 4, phone-class E2B and E4B, existence settled, slicing quality not. OQ1 owns that empirical question, and the model choice with it. The validation build implements the cloud path via BYOK (FR-28); FR-25 is written for the cloud worst case, and any fully local path satisfies it trivially. Realizes UJ-2.

**Functional Requirements:**

#### FR-16: Space photo scan with Smart Slicer
The user can photograph a space and receive a sequence of 3–5 min Micro-tasks with per-step effort estimates derived from clutter analysis.

**Consequences (testable):**
- No latency cap: scan time is not a determining factor (OQ1 ruling). The wait happens in-app, on the scan surface, in the foreground, with visible progress and honest copy; if completion is asynchronous, it is announced only inside the app — never via a second notification category (FR-24, §5.2). Leaving the surface or backgrounding the app cancels the wait and discards it — the same nothing-is-queued rule as failure (FR-29). There is deliberately no timeout: with latency demoted, the clock is the user's own patience, and an impatient user already has the exit.
- Each generated step carries a duration tag between 3 and 5 minutes.
- If analysis fails (no network, invalid or exhausted key, provider down, cap), the app states the cause plainly and offers Manual Capture (FR-29) — never an error dead-end, and never a template dressed up as a plan. Realizes UJ-2 edge case.
- The Slicer's structured description of the analyzed space (Origin Context) is retained for future re-slicing (FR-5); the image itself is discarded per FR-25.
- The scan surface is a direct one-tap camera entry on the Dispenser — the photo genesis path of FR-11 and UJ-2's "one tap to Scan". Photographing a space is add-work beside the day's card, and the camera permission is requested at the first scan attempt, never at app entry and never during first run — the same first-use rule the microphone follows (FR-32, §7).
- The camera entry can be disabled outright in settings, so it never appears on the Dispenser at all; and a camera permission refused at first use — or revoked at the system level after being granted — removes the entry under its own power, following the refusal rule, until the user restores it from settings. Visibility is *enabled and permission not refused*, and a single settings row owns both the disable toggle and the reactivation, so the reversal lives where the user put the refusal. An entry the user never enabled or never granted is not a loss, whereas a dead camera icon sitting on the primary surface is pending work in the one place the user lives (§1.1 principle 2).

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
During purge steps, the app presents guilt-free detachment questions — the factual one ("Have you used this in the past 12 months?") and the one that does the real work ("Does this deserve your physical and mental space?"). Each requires a `Sí` or `No` answer before the Keep / Donate-Sell / Trash-Recycle triage, surfaced as `Quedármelo` / `Donar o vender` / `Tirar o soltar` (§3).

**Consequences (testable):**
- Question copy contains no pressure framing. Each question offers only `Sí` and `No`; there is no skip action, and choosing one of the three destinations remains required after both answers.
- The three destinations carry equal weight, and the third is labelled `Tirar o soltar` — never `Tirar o reciclar`, never a bin or a recycling word: *soltar* avoids both the deletion vocabulary of a bin and the compliance vocabulary of recycling arrows, and the trio's equal weight depends on the third choice not reading as the bad one (UX session `ux-organizer-2026-08-21`; `Trash-Recycle` stays the internal concept name because discarding and recycling genuinely are one destination here). No destination is worded, styled or ordered as the undesirable one.

#### FR-21: Quarantine Box
The user can send hesitated items to a dated Quarantine Box; once the follow-up period elapses on the box's date, the app gently suggests donation. The timer is blind — it runs on the date alone because the app has no signal about the physical box, and the suggestion's copy never claims one. Values: §10.1.

**Consequences (testable):**
- The follow-up suggestion appears at most once per box, when its period elapses, and is dismissible in one tap; it is phrased on the date alone and contains no claim about the box's contents or use.

#### FR-22: Cumulative declutter metric
The system tracks liberated items as a positive-impact milestone, derived only from what the user taps during purge steps.

**Consequences (testable):**
- The metric is a per-destination item count (Keep / Donate-Sell / Trash-Recycle), incremented by tap during purge steps. Nothing is inferred from photos.
- Volume is optional and coarse: the user may tag a batch as bolsa / caja / caja grande / mueble. Absent tags simply do not contribute.
- Volume is displayed as an approximation with its unit visible ("≈ 3 cajas liberadas"), never as a precise figure or a percentage.
- Displayed only as cumulative achievement — never a target, a rate, or a deficit.

### 4.6 Progress & Cumulative Impact

**Description:** Gentle visibility of real advance: minutes invested, micro-tasks done, space liberated, before/after album — counters of achievement only. Includes the optional motivating snowball: a gentle suggestion to raise the Time Bag after a sustained run of comfortable days — an internal count, invisible by §1.1 principle 2. Realizes UJ-3, UJ-4 (perceived-progress concern from the brainstorm's Critic room).

**Functional Requirements:**

#### FR-23: Cumulative impact dashboard
The user can view cumulative minutes, completed Micro-tasks, liberated items/volume, and album highlights.

**Consequences (testable):**
- Dashboard contains no daily quotas, no averages-over-time comparisons, and no deficit framing.
- After a snowball condition — the §10.1 run of comfortable days, each auditable in FR-26 series (a) — a one-tap-dismissable suggestion to raise the Time Bag by the confirmed step may appear; declining has no effect. The run of comfortable days is an internal count and is never surfaced (§1.1 principle 2). The suggestion does not appear when the Time Bag already sits at the top of its range (FR-7) — there is nothing left to suggest.

### 4.7 Ambient Invitation (passive daily notification)

**Description:** The app's only outward-facing signal. One silent notification per day at a user-chosen hour, phrased as a motivating, kind invitation. It may refer generally to household action, a short available time, or a change of activity, but never names an actual pending task, a count, or a recalled debt. It exists because the app cannot help someone who forgets it exists, and it must remain incapable of escalating into a nag. Realizes UJ-1 (session initiation).

**Functional Requirements:**

#### FR-24: Single silent daily invitation
The user can enable exactly one daily notification at a chosen hour, delivered silently, whose motivating, kind content invites a session without naming an actual pending task, showing a count, or framing work as owed. Off by default; once disabled it stays disabled until the user turns it back on.

**Consequences (testable):**
- At most one notification per 24 h is emitted by the app, under every code path — no second chance, no re-delivery on dismissal, no follow-up if unopened.
- The notification is posted on a low-importance/silent channel: no sound, no heads-up interruption, no badge count.
- Notification copy may refer generally to household action, a short available time, or a change of activity. It contains no actual task title, no numeric counter, and no word framing anything as owed, late, missed, or remaining.
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
- Text-only re-slice requests (FR-5) send the Origin Context and the current task — never an image — without a per-call dialog. This rests on the FR-28 allowlist gate: only providers with written no-training terms are selectable at all, so the guarantee is a build-time property rather than a runtime hope.
- Genesis by typed or form description (FR-11) sends that text for analysis, and the `Analizar` action is the consent: the genesis surface states in plain Spanish that the description will be analysed to create tasks. Unlike the per-scan photo confirmation, it does not name the provider and has no separate dialog (§7).
- On the BYOK path the destination is the user's own provider account, reached with the user's own key. The developers receive nothing, hold nothing and operate nothing (§7). On the Local path nothing leaves the device and this FR is satisfied trivially.

#### FR-26: Local validation instrumentation
The app records, on-device only, the minimum series the success metrics consume.

**Consequences (testable):**
- Four series exist and are queryable: (a) session start/end with duration and Micro-tasks completed, (b) Slicer calls and their outcome (plan / declined / Slicer unavailable) — every Photo-Diagnosis scan and every text-genesis call (FR-11) on the same terms, so the text path is instrumented like the photo path, (c) Before/After pairs per project milestone, (d) Ambient Invitation emissions and whether the app was opened within the following hour.
- Every Micro-task carries its genesis origin — `shipped` (pre-sliced Evergreen Library content, FR-11, FR-31) / `manual` / `local` / `cloud` — and every series row that references a task carries it too. Without this field SM-3 and SM-4 become unreadable the moment Manual Capture is in use: a milestone reached entirely by hand validates the engine but not the hook, and the two must be distinguishable. Origin is a provenance tag, never a quality ranking, and never surfaced in the Dispenser. Origin tags genesis and is immutable under re-slicing: the steps of a rescue (FR-5) inherit the original task's origin, because a re-slice is mechanism, not re-authorship — a hand-written line rescued by the cloud Slicer still entered the pool by hand, and SM-4 keeps measuring what generated the work rather than what re-cut it.
- All series are local-only; no third-party analytics SDK is present in the build. The app transmits no usage data of any kind, and in the validation build there is no developer-side record at all, because there is no proxy (§7, FR-28).
- The user can read the series as raw exported data, so the validation verdict does not depend on the app's own summary.
- No series is surfaced in the Dispenser or dashboard as a daily target, average, or period comparison (constraint from SM-C1/SM-C2).
- Skips feed only FR-5's consecutive-skip logic. No cumulative skip total is stored anywhere — a skip count is a debt record with a different name.

#### FR-30: Silent automatic export
The full export runs by itself, silently, into the folder the user chose — with no reminder, no indicator, and no pending state anywhere.

**Consequences (testable):**
- After the user picks a destination folder once (system folder picker, persisted URI), every subsequent export happens without being asked for: plans, album images and all FR-26 series, in the same single legible-text-plus-images format that serves as raw series export, validation source and restore format (§7).
- Export is triggered at natural foreground moments — end of a session, app going to background — and is **not** background work: no periodic job, no persistent service, no wake lock, no new permission (§7 background minimalism holds unchanged).
- The app never transmits the export. It writes a local file; if the chosen folder happens to be a synced one (Drive, Dropbox, Nextcloud), the user's own already-installed client does the uploading. Zero provider integrations, and the egress map (§7) is unaffected — the destination is still "the user's own storage".
- No reminder, no badge, no backup-age indicator, no "last exported" line and no failure toast exists in the Dispenser or anywhere the user lives. Backup must never read as pending work, and a silent export that nags is worse than a manual one.
- Export state — destination, last success, last failure and its cause — is readable **in settings only**. This is the validator's surface, not the user's (§7).
- One-tap manual export remains available for the user who wants it now (§7).
- If the destination becomes unwritable (revoked permission, removed volume), the app keeps working and stays silent; the fact is visible in settings and nowhere else. The failure is never framed as the user's omission.
- The export is restorable: settings — the validator's surface (§7) — carries a one-file-picker import that restores plans, album and series in full, with no merging and no partial restore. This is what buys the format its name; without an import, "restore format" is a promise rather than a property.

### 4.9 Manual Capture (the floor)

**Description:** The one entrance the user writes, and deliberately the poorest one — whether the words arrive by keyboard or by voice (FR-32). Something occurs to the user that the app cannot know and no photo can reveal — a favour promised to a neighbour, a form to hand in. Manual Capture takes one line and one of three sizes, then returns to the Dispenser. It exists so the app is never useless: with no key, no network, no model and no account, it still holds work and dispenses it. It is a floor, not a road — every affordance that would make it comfortable to live in has been left out on purpose. Voice (FR-32) is the one exception to that sentence, and it is an exception about *cost* rather than about *capability*: dictation makes the single line cheaper to produce and adds nothing the line could not already hold — no second task, no parsed size, no natural-language plan, no list. A cheaper floor is still a floor; a floor with a list is not. Realizes UJ-5.

**Functional Requirements:**

#### FR-27: Manual Capture
The user can add one Micro-task by typing one line and choosing one of three sizes, at any time, with no network, no key, no model and no account.

**Consequences (testable):**
- Capture is reachable from the Dispenser in one tap and completes in two fields: one line of text, and a size chosen from exactly three options — 30 s, 3 min, 10–15 min. No free-form minute entry exists anywhere.
- The three sizes *are* the 1-3-5 taxonomy (Instant Habit / Micro-maintenance / Focus Chunk), so a captured task enters the Project Weaver's composition with no conversion step and FR-12's budget arithmetic holds unchanged.
- Capture asks for nothing else: no project, no category, no date, no priority, no tags, no recurrence, no confirmation screen.
- The captured line can be corrected or discarded from the capture surface itself, before the user leaves it. Once the user leaves, the task belongs to the pool and there is no path back to it except being dealt. The line must be non-empty before a capture can be left with a task in it: the confirming action stays disabled until there is text — a blank capture is not a task, and letting one enter the pool would put an irreversible empty card into circulation.
- No screen in the app lists, counts, filters or browses captured tasks (NL-1). A captured task is next seen as an ordinary dealt card, visually and tonally indistinguishable from a sliced one.
- Manual Capture behaves identically under every AI Access Path, including none.
- A manually captured task carries origin `manual` (FR-26) and an Origin Context consisting of its own line (§3). It is re-sliceable by FR-5 when a Slicer is reachable, and not re-sliceable when none is.
- A captured task is dealt within the confirmed window (§10.1), ahead of Evergreen and Epic material of the same size (FR-12). Nothing else about it is privileged.
- The line is plain text, and the app models nothing written in it — including a day. A line that says "el jueves" is not held until Thursday: the deal window runs from capture regardless, no exemption exists, and nothing is ever parsed out of the text (FR-32). A capture with a real deadline does not belong on this surface, and the frame's copy says nothing about dates — the surface does not lecture (OQ-11 closed 2026-08-27).
- Manual Capture handles spatial work, and it says so by framing rather than by refusing: the capture surface is framed spatially — title, helper text, example, the three sizes — so non-spatial work is never invited and rarely attempted. The app performs **no validation of the captured line**: "llamar al dentista" typed or dictated anyway is accepted silently and dealt as an ordinary card, because rejecting it would shame the user and detecting it reliably is impossible. No invitation, no validation, no refusal — the shaming cost the question warned about is avoided by design rather than absorbed, and the engine's spatial nature is why the frame works rather than a rule the app enforces (OQ-11 closed 2026-08-27; frame copy authored in the UX spines).

#### FR-32: Voice dictation into the capture line
The user can fill Manual Capture's single line by speaking instead of typing, recognised on-device, with no network, no key, no model and no account.

**Consequences (testable):**
- Dictation is offered on the Manual Capture surface and nowhere else in the build. No other field or action accepts voice, and no voice *command* exists anywhere — the Dispenser is operated by tapping (§1.1 principle 1). Voice is a second way to fill one field, never a second way to drive the app.
- Voice fills **the text line only**. The size is still chosen from the same three taps (FR-27), and a spoken duration is treated as words in the line like any others: nothing is ever parsed out of the transcript. Parsing speech into structure is the deferred voice-first slicer (§5.1), and this requirement sits on the other side of that line.
- One utterance produces at most one Micro-task. A dictation that plainly contains several errands still becomes one line and one task — the app does not split it, and does not tell the user it could.
- Recognition runs **on-device**. The audio never leaves the phone, so §7's egress map gains no destination. There is deliberately **no cloud fallback**: where on-device recognition is unavailable the feature is absent, never degraded into an upload, because a fallback is exactly how a new egress destination arrives without anyone having decided to add one.
- No audio is retained anywhere, for any duration. It is not written to storage, not included in the export (FR-30), not present in any FR-26 series, and not recoverable once the transcript exists. The only artifact a dictation leaves behind is text in a field.
- The transcript appears **in the existing one-line field on the existing capture surface** — not in a confirmation screen, which §4.9 does not have and does not acquire. FR-27's correct-or-discard affordance is therefore what governs a mis-transcription, and it becomes load-bearing in a way it was not before: leave-and-it-is-gone was safe while the user typed what they read, and a machine-written line that reaches the pool wrong can never be fixed, because NL-1 abolishes the list. Dictation without a visible, editable transcript is a defect, not a variant.
- **The keyboard is never removed.** Voice is strictly additive: the surface accepts typing at all times, and correcting a transcript requires it. A voice-only capture surface would be unusable the first time recognition mis-hears a household word.
- Where on-device Spanish recognition is unavailable — no language pack, unsupported device — the microphone affordance is **simply not present**. No error, no explanation, no offer to install anything, no greyed-out state, and no settings pointer to the system's language-pack installation either: an affordance the user never saw is not a loss, whereas a disabled microphone is pending work sitting in the one place the user lives (§1.1 principle 2, §7). This is a decision, not a deferred question, and it forecloses nothing: every string is externalized (§7), so a second locale remains pure translation.
- The microphone permission is requested at the first dictation attempt, never at app entry and never during first run — nothing in first run acquires a new prerequisite (§7). Refusing it leaves Manual Capture fully functional by keyboard, removes the affordance, and the app never asks again on its own. A refused permission is reversible in settings and nowhere else — the same unified pattern the camera entry follows (FR-16): a reactivation row exists only while there is something to reactivate, and a phone with recognition available and permission granted shows no row at all.
- Nothing listens outside an explicit press on that affordance. No wake word, no always-on capture, no ambient recognition, and no background audio work of any kind (§7 background minimalism holds unchanged, and FR-24's invitation remains the only background work in the build).
- A dictated task carries origin `manual` exactly as a typed one does (FR-26): dictation is an input method, not a genesis path, and origin records what authored a task rather than which key was pressed. Whether dictation was used is recorded as a separate local boolean on the capture, readable **in settings only** (§7), so the window can answer whether voice earned its place without disturbing SM-4's origin arithmetic.
- Dictated and typed tasks are indistinguishable once dealt. No badge, no icon and no copy anywhere marks a card as spoken.

### 4.10 AI Access Path

**Description:** How the app reaches a Slicer. Three implementations behind one interface — Local (on-device model), BYOK (the user's own key against a vetted provider), Managed (developer-run proxy behind login/password, paid in non-expiring credits and never a subscription — §5.1, §5.2) — of which the validation build ships exactly one. BYOK is chosen for v1 because it is the only path that costs nothing to build and holds nothing: no proxy, no account, no login, no developer-held data, no first-run network requirement. This section exists because the earlier PRD collapsed "who creates tasks" into "how AI is paid for", and the collapse manufactured a login requirement at app entry that nothing actually needed (addendum A9).

**Functional Requirements:**

#### FR-28: AI Access Path with a vetted-provider allowlist
The Slicer is reached through a swappable access interface. The validation build implements BYOK: the user supplies their own API key for a provider chosen from an in-app allowlist.

**Consequences (testable):**
- Exactly one path is *usable* in the validation build (BYOK). Adding Local or Managed changes no call site outside the access layer.
- The Local path ships as a **stub that returns a canned slice**, so the interface has two real callers in the shipped build and its swappability is exercised rather than asserted. An interface with a single implementation is an untested abstraction, and untested abstractions are wrong almost always; the stub is the cheapest possible test and is a build requirement, not a suggestion.
- The stub is never reachable by the user: it is selectable only in a debug build, and its canned output is recognisable as such so it can never be mistaken for a real slice.
- Providers are chosen from a fixed in-app allowlist. A free-form endpoint or base-URL field does not exist — FR-25's no-training gate is unenforceable the moment the user can point the app anywhere, and a gate that depends on the user reading terms is not a gate.
- The allowlist is frozen at build time and never fetched over the network. A remote list would reintroduce a developer-side endpoint, and with it the third egress destination §7 has just eliminated — the guarantee would be bought back at the price of the property it protects.
- Each allowlist entry states, in plain Spanish, the provider name and the date its terms were verified, and says plainly that they were verified *on* that date and not since. An app with no backend cannot revoke anything; claiming otherwise would be the more dishonest option. Stale terms are corrected by shipping a build and by nothing else: there is no age indicator, no re-check and no removal mechanism, because each of those would promise a vigilance the app does not have.
- **The gate is no-training only, and the key's tier is the user's own call.** Retention is deliberately not gated: no provider reachable with a user's own key offers written zero retention — all of them hold an upload briefly for abuse monitoring, and true zero-retention is an enterprise contract. Gating on it would have excluded every candidate and taken the differentiating hook with it. No-training is the criterion that actually separates the acceptable from the unacceptable, and it happens to be exactly the line a provider's free tier crosses. Since the key is the user's, so is the choice: **the app states at key entry, once, that a free-tier key may be used for training and that the app cannot tell which tier a key belongs to** — and then never mentions it again, anywhere. Key entry lives in settings (§7), so this notice never reaches the Dispenser. What the app owes the user here is one honest sentence at the one moment it is actionable, not a guarantee it is not in a position to make.
- Stale terms are corrected by shipping a build. That is the only mechanism that exists, and OQ-10 owns what the app does in the meantime.
- The credential is protected at rest by an OS-backed non-exportable key: never in app preferences, never in the export (§7), and never readable outside credential entry or one request to the selected provider. Provider selection may be restored, but credential availability is installation-local and checked live; a restore without usable local credential material requires key entry again. A14 and architecture AD-22 own the mechanism.
- No account, login, password or registration exists anywhere in the build, and nothing in the first-run experience requires the network.
- The app never adds a margin, meters usage, or reports a call to anyone. On BYOK the billing relationship is entirely between the user and their provider.
- If the Managed path is ever implemented it is paid in non-expiring credits, never in a recurring fee (§5.1, §5.2), and its balance is never surfaced outside settings. This is recorded in the access layer and not only in Non-Goals, because the access layer is precisely where someone would otherwise wire a subscription check.

#### FR-29: Honest degradation with no Slicer
When no Slicer is reachable, the app states the cause plainly and offers Manual Capture. It never invents tasks, never presents a template as a plan, and never queues work for a later upload.

**Consequences (testable):**
- Every no-Slicer cause is distinguishable in the copy and names its own remedy: no key configured, invalid key, exhausted quota, provider unreachable, no network, consent declined (FR-25), person detected in frame (FR-25).
- Every one of those states offers Manual Capture as the way forward. None is a dead end and none is styled as an error — no red, no warning iconography, no exclamation (§1.1).
- Nothing is queued: no scan image, no re-slice request and no pending-upload state survives the failure. The user reshoots or retypes when the Slicer is back, because a deferred upload would break per-scan consent (FR-25) and background minimalism (§7).
- A fresh install with no Slicer reachable still reaches a woven 1-3-5 day, from the pre-sliced Evergreen content that ships in the build (FR-11). What is unavailable is everything personal: Epic Projects, photo slicing, re-slicing. The app names that distinction plainly instead of implying the whole product is degraded.
- The absence of a Slicer is never framed as the user's omission, and never as pending work.
- **The seven strings are authored before the failure path is wired**, and they are part of the SM-C2 audit surface from the start. These are the highest shaming-risk sentences in the product — "tu clave no es válida" is one tap away from blame — and they are exactly the strings that otherwise get written last, in a hurry, by whoever cables the error branch. No implementation of FR-29 is complete while any of the seven is a placeholder or a developer string.

### 4.11 Evergreen Task Library

**Description:** The catalogue of pre-sliced household Micro-tasks the build ships with. It is what makes FR-11's promise real: a fresh install with no key, no network and no model still has a varied month of household work to deal from. Three cadences, because a home has three — the things done every day, the things that rotate weekly by zone, and the things that come round monthly or with the season. It is product content, fixed at build time, and it is not a place the user writes. Content: addendum A12. Realizes UJ-1, UJ-3, UJ-4.

**Functional Requirements:**

#### FR-31: Pre-sliced Evergreen Library
The build ships a catalogue of Evergreen Micro-tasks spanning three cadences, broad enough to compose a varied 1-3-5 day for the whole validation window.

**Consequences (testable):**
- Three cadences ship and each is populated: **daily** — Instant Habits (~30 s) and Baseline Upkeep (3–15 min); **weekly** — zone routines across the 5 FlyLady zones; **monthly/seasonal** — windows, filters, descaling, deep-clean upkeep.
- Every entry carries three fields and no more: a size drawn from the 1-3-5 taxonomy (30 s / 3 min / 10–15 min), a cadence, and a zone or none. The Weaver therefore needs no conversion step and FR-12's arithmetic holds unchanged.
- **Coverage floor, in eligible units:** the pool eligible for the Focus Chunk slot — weekly zone routines and monthly/seasonal upkeep at 10–15 min, across all zones and clusters — holds at least 28 distinct entries, so 28 dealt Focus Chunks never repeat a Micro-task even with no Epic Project active. Only 10–15 min entries count towards the floor: a 3-minute entry can never occupy the slot. Daily items recur by definition and are excluded; everything else must have the breadth to keep a rotation from collapsing into the same handful.
- **The floor counts dealt Focus Chunks, not calendar days.** A 🔴 day deals no Focus Chunk at all (FR-4) and consumes nothing of the rotation; the repetition of daily anchors on such days is their nature, not a failure of this floor (UJ-4). The catalogue is deliberately not grown for the 🔴 case: repetition on a 🔴 day is accepted and documented rather than engineered away, because a 🔴 day is meant to be tiny.
- **The `fondo` cluster is an eligible source.** Monthly/seasonal upkeep is advance work and fills the slot when the active zone's own 10–15 entries are exhausted within its week — before any repetition. A thin zone week draws from `fondo` rather than repeating itself; the zone's entries come first, and the floor above holds over the combined pool.
- **No entry is bound to a clock.** No catalogue task carries an hour, a mealtime, or a before/after dependency the app would have to track (§1.1 principle 3, §5.2). Cooking is excluded for exactly this reason; the upkeep that follows a meal ships, because it follows a moment the user recognises rather than a time the app must know.
- The catalogue is curated at **cluster** level — `anclas`, `sostén`, weekly zones `z1`–`z5`, and `fondo` — never at task level. A12's `plantas` and `coche` are authorial annotations, not derivable curation groups. No screen anywhere enumerates individual catalogue entries: a browsable 80-item catalogue is the task list NL-1 abolishes, arriving through the template door.
- The Archetype Template selection surface of §1.1 exception E1 is not an exception to the bullet above: what it enumerates is templates and clusters, never the individual catalogue entries inside them (UX session `ux-organizer-2026-08-21`).
- Curation is reachable from onboarding and settings only, never from the Dispenser (§7). A disabled cluster's tasks simply never appear; disabling one produces no count, no summary and no copy about what was turned off. Onboarding is the product itself plus **one** one-time ambient strip offering curation after first run — no wizard and no first-run curation flow, because the cold-start contract (§7) holds hardest on day one. The strip is dismissible in one tap, a dismissal means never again, and settings plus the template-selection surface (E1) remain as the standing routes. A user who dismisses it, or never sees it, keeps the default standing — every cluster active — because curation is inherently optional and the first composed day is never empty.
- The library is fixed at build time and the user cannot author, edit or extend it. Manual Capture (FR-27) remains the only way a user-written task enters the pool, and it stays a floor rather than becoming a template editor.
- Every library task carries origin `shipped` (FR-26), so SM-4 can read the Focus Chunk mix against it.
- Library breadth is a build-time property, verifiable without running the app: the catalogue is a data file, and the coverage floor above is checkable by counting its distinct 10–15 min non-daily entries.

## 5. Non-Goals

Two kinds of omission, kept apart deliberately: what may come back, and what may not.

### 5.1 Deferred — outside the validation build, may return

- **Adaptive/ML buffer learning** — Invisible Buffers are rule-based in v1 (Phase 3).
- **Voice-first natural-language slicer** — Phase 3. What stays deferred is voice as *genesis*: speaking freely and having the app parse the speech into several sized micro-tasks, or into a project. What is **not** deferred, and ships in this build, is voice as a *keyboard replacement* on the one line Manual Capture already had (FR-32). The distinction is the one §1.1 principle 6 draws everywhere else — dictation transcribes, a Slicer authors — and it is named here because "we added voice" is precisely the sentence a later reader would take as having shipped this bullet.
- **Multi-user household zones and shared Time Bags** — v3. [NOTE FOR PM] Emotionally load-bearing and core to the household vision; this build leaves it entirely untested. Revisit before any public launch.
- **iOS, web, desktop, widgets, wearables** — Android only in v1.
- **Cloud backup or sync of app data** — local-first only, and no provider integration ever. Automatic *export to a local folder* is no longer deferred: it is required and silent (FR-30). What stays deferred is anything that would make the app itself talk to a cloud provider — if the chosen folder is synced, that is the user's own client doing it, not us.
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
- **NL-1 — a task list, in any form.** Named for stable citation, like the §1.1 exception register. Manual Capture (FR-27) writes into the pool and returns; it never opens a backlog. No screen anywhere enumerates captured tasks, permits editing them, or lets the user browse what is pending — a "just let me see what I typed" screen is the first version of the endless list §1 exists to abolish, and it is the door GTD density walks through. The single concession: the line just written can be corrected or discarded from the capture surface itself, before the user leaves it. After that it belongs to the pool.
- **Subscription pricing for AI access.** A recurring fee bills for the months the user does not open the app — it monetizes exactly the absence FR-6 and UJ-3 exist to forgive. And a business that earns from silence acquires an interest in breaking it: recurring revenue rewards engagement, while the reminder exclusion above forbids engineering engagement. The two cannot share a product, so the fee is excluded by philosophy rather than deferred by phasing. Credits (§5.1) track use, and use tracks the user's own free will.

## 6. MVP Scope

Validation build = brainstorm Phase 1 **plus** AI Photo-Diagnosis and Before/After rewards, on Android, Spanish-first. Scope is the FR index in §4 — every feature above ships, nothing else; out-of-scope is §5. The only item with no FR of its own: Spanish UI with i18n-ready strings, no hardcoded copy (§7).

## 7. Cross-Cutting Constraints

- **Offline by default — execution, not genesis.** Dispensing, completing, weaving, rescheduling, the album, the dashboard, export and Manual Capture work with no network, always — Manual Capture including its voice dictation, which is recognised on-device precisely so this sentence needs no exception (FR-32). Slicing does not: on the BYOK path every slice and re-slice needs the network, on the Local path none does. The shipped Evergreen day is exempt because it was sliced at build time rather than at runtime (FR-11) — a phone in airplane mode on day one still has the whole Evergreen Library — anchors, Baseline Upkeep, zones and seasonal upkeep (FR-31) — and a composition built from it. The distinction is load-bearing (§1.1) — an offline app executes, it does not beget. Airplane mode is supported, never an error state; a slice or rescue that cannot reach its provider degrades per FR-29 and queues nothing.
- **Local-first durability.** No developer-held data of any kind. A lost device loses the Transformation Album and every metric series unless exported — so one-tap full export (plans, album, series) is required, not optional: legible text plus album images, restorable on reinstall. Destination is chosen through the system folder picker — any cloud folder the user already has (Drive, Dropbox, Nextcloud) works, with zero provider integrations. No backup reminders or backup-age indicators anywhere: backup must never read as pending work. The export is also **automatic and silent** (FR-30): never nagging the user and never losing the validation data are only compatible if the export happens by itself. Sync *to a provider* stays deferred (§5.1); the app writes a local file and nothing else.
- **Settings is where the validator reads; the Dispenser is where the user lives.** Anything a validator needs and a user must never be shown — the FR-26 raw series, FR-30's export state, the Managed path's credit balance (§5.1) — is reachable in settings and nowhere else. This is what makes the same person's two roles survivable in one app: the user's surfaces stay free of counters, and the numbers still exist for whoever goes looking.
- **Data egress map — path-dependent, and the validation build has no third destination.** To the AI provider: only three payloads ever — the scan image (per-scan consent, FR-25), the genesis text of a typed or form-described project (FR-11: the send action is the consent, destination stated on the genesis surface), or the rescue re-slice text (FR-5) — and on the BYOK path that provider is the user's own account, reached with the user's own key. **Audio: nowhere, to no one.** Voice dictation (FR-32) is recognised on-device, has no cloud fallback, and adds no destination to this map — FR-32 owns the rationale. To the user's own storage: whatever the user exports, when the user chooses. **To the developers: nothing.** The turnstile ruling — an account identifier and AI request timestamps at a proxy, because "access cannot be free" — was a consequence of the Managed path, and the Managed path is not built (§5.1): with BYOK there is no proxy to log anything and no account to identify. On the Local path even the first destination disappears. No app-open counts, no telemetry, no analytics; the app never reports usage to anyone. When the Managed path is built the turnstile returns and this bullet must be rewritten, not quietly reinterpreted. One format, three uses: the legible-text export is simultaneously the FR-26 raw series export, the validation data source, and the backup/restore format.
- **Latency inside a 15-minute pocket.** Cold start to first dispensed card ≤ 2 s; Done → next card ≤ 500 ms (FR-2). Startup latency is stolen from the pocket the user offered. Slicing is deliberately exempt: OQ1 demoted scan latency and FR-16 sets no cap. The exemption matters most on the Local path, where inference on a mid-range phone will be slow.
- **Accessibility.** Legible at 200% system font scale with no truncation; every action reachable one-handed; haptics never the sole completion signal. **No goal is reachable only by typing** — the floor is scoped to goals rather than surfaces: creating work needs no keyboard, because the photo path needs no words at all (FR-16), Manual Capture's one line can be dictated (FR-32), and Evergreen content ships pre-sliced (FR-31). The genesis surface's typed entrance (FR-11) is an alternative, not a gate — the same goal, a personal project, is reachable wordlessly through the camera — so typing on that surface does not break the floor. Settings is outside the floor: it is the validator's surface (see the settings/Dispenser split above) and the BYOK key entry lives there. This is a floor on the whole build rather than a property of FR-32: any future goal reachable only through typed input breaks it.
- **Copy is the product surface.** Spanish UI, every string externalized, no runtime sentence concatenation — the anti-shaming audit (SM-C2) must be reviewable as a flat string table. The failure and degradation strings are in that table on the same terms as everything else: FR-29's seven no-Slicer messages are authored before the path that shows them is wired, not after (FR-29).
- **Background minimalism.** The only background work is FR-24's daily invitation. No sync, no location, no persistent service, no wake locks, **and no microphone outside an explicit press** (FR-32). Runtime permissions follow one rule: requested at first use and never at first run — the microphone at the first dictation attempt (FR-32), the camera at the first scan attempt (FR-16). Refusing either removes the affordance silently until the user reverses it in settings; the app never re-asks on its own. The automatic export (FR-30) is deliberately *not* an exception: it runs in the foreground at natural moments — session end, app backgrounding — because a periodic sync job would buy durability with the one property this bullet protects.
- **No overdue at the schema level.** "No overdue concept" (FR-14) is a data-model constraint, not a UI rule: no field, flag, or derived value anywhere may express lateness, debt, or a missed occurrence. Overdue-shaped data breeds overdue-shaped UI, and the next person to touch the schema will not have read §1.1.
- **Single-user data model throughout.** All local data (plans, album, series) remains account-free and single-user. Multi-user (§5) remains a schema change, and that is accepted knowingly.
- **No account in the validation build.** BYOK needs a key, not an identity: no login, no password, no registration, no first-run network requirement. The app is fully usable the second it installs, because Manual Capture (FR-27) needs nothing at all. The earlier formulation — "login/password requested at first AI use, never at app entry" — was incoherent while the Slicer was the only source of tasks, since on a fresh install the first use *is* an AI use. Manual Capture is what makes that sentence unnecessary rather than merely rephrased. Login/password belongs exclusively to the Managed path (§5.1) and does not exist in this build.

## 8. Success Metrics

Validation window: 4 consecutive weeks of real use. Day 1 is the first day the build is usable daily on Sergio's own phone — not a calendar date. The intent document's Gantt (phases from 2026-09-01) is deliberately not carried into this PRD: a solo validation build paced by a dated plan would reintroduce exactly the deadline pressure the product exists to remove.

Secondary observers: the builder's wife (same household) and sister-in-law (separate household) run independent single-user instances during the window. Handset topology, settled 2026-09-01: of the three validation handsets, exactly two — the builder's and the wife's — are ever connected to the development computer (installs, probes, the release ritual); the sister-in-law's handset is **field-use only** — real use in her own household, never USB-connected, never probed, never computer-managed — so builds must reach it and its exports must leave it without a cable, by a mechanism architecture still owes (AD-18's three-handset USB ritual is not that path). Their data is reported as a separate annex and never merged into SM-1–SM-3. All subjects are motivated and non-representative — the signal is within-subject decay (week 4 vs week 1), never cross-subject comparison. Domestic territory in the shared household is agreed before day 1, outside the app: the product proposes per-person projects and coordinates nothing between users, by design.

BYOK (FR-28) does not break the annex, because a shared key is not required: each subject gets **her own API key issued from the builder's single provider account** — providers that support per-key cost attribution make this a one-minute setup with no payment method and no account of her own, and with per-person cost visible to the builder. Each instance's FR-26 series stay on that person's device and are never merged (above); the provider-side per-key figures are cost data, not usage telemetry, and feed no metric. One caveat that belonged to OQ-10 is now moot by construction: an aggregator routing to many upstream providers would have turned FR-28's no-training gate from a property into a *configuration*, and no aggregator is on the closed allowlist — all three entries are first-party providers whose own written terms are the gate.

**Primary**
- **SM-1**: Sustained usage — sessions on ≥ 70% of days across the 4-week window, measured from local session logs. Validates FR-1–FR-10.
- **SM-2**: Felt overwhelm reduction — weekly in-app self-report, one question on a 5-point scale ("Esta semana, ¿cuánto te ha agobiado la casa?"), asked Sundays: an ambient question in the Dispenser on the first opening from Sunday onward, persisting until answered that week, never notified — a notification would violate FR-24 and §5.2. A week with no answer simply has no data point; the trend reads over the weeks that do. Target: trending ≥ 1 point better by week 4 vs week 1; the week-1 baseline exists on day 1. Validates the product premise (Vision).
- **SM-3**: Real epic progress — at least one Epic Project reaches a visible milestone (e.g., storage room phase complete) with zero app-initiated session continuations: sessions may run long only by the user's active choice (FR-10). Validates FR-11–FR-16.

**Secondary**
- **SM-4**: Photo loop adoption — ≥ 1 Photo-Diagnosis scan per week in active use; before/after pair shot for ≥ 50% of completed project milestones. Read against task origin (FR-26), and on the right denominator: the daily 1-3-5 is dominated by `shipped` Evergreen content by construction, so raw task share proves nothing. The question is what authored the **Focus Chunks and the Epic material** — if `manual` originates most of those across the window, the differentiating hook is unvalidated however well SM-1 and SM-3 read, and that is the window's most important finding rather than a footnote. Validates FR-16–FR-18.

**Counter-metrics (do not optimize)**
- **SM-C1**: Minutes or tasks per day must NOT be pushed upward — the product's value is calm progress, not throughput. Counterbalances SM-1: engagement achieved by nagging or marathon-creep is failure, not success.
- **SM-C2**: Guilt events = 0 — count of UI/copy occurrences that frame anything as owed, late, or failed must remain zero. Counterbalances SM-3: progress purchased with pressure voids the premise.
- **SM-C3**: Notification volume must NOT rise above 1/day, and invitation copy must NOT acquire task content, counters, or urgency across the window. Counterbalances SM-1 specifically: if sustained usage turns out to be driven by notification pressure rather than by the product being pleasant to open, SM-1 is a false positive. Test: passive analysis of FR-26 series (d) — share of sessions started within the hour following an emission; if most sessions trace to the ping, run one week with the invitation disabled, outside the 4-week window.

## 9. Open Questions

1. Which multimodal vision API/model for the Smart Slicer? Ruling 2026-08-20: for the validation build, selection optimizes for one thing — does the photo → micro-plan loop actually work on real photos. Fixed around it: (a) provider terms gate (written no-training) — non-negotiable, forever, applies to any cloud path; (b) latency sacrificed; (c) price parked until monetization (§5.1). Deployment topology — cloud API vs on-device — is deliberately open, and as of 2026-08-21 the local candidate has a name: Gemma 4 (released 2026-04-02), E2B/E4B variants, native multimodal image input, official Android support; the 12B is laptop-class and out of scope for a handset. Existence is no longer the question — the question is whether Gemma 4 slices real clutter photos into usable 3–5 min steps. **Venue, candidate set and method, decided 2026-08-27:** the test runs on the **development machine first, not the handset** — Gemma 4 runs locally there through **Lemonade**, a local inference server exposing an OpenAI-compatible endpoint, and slicing quality is a property of the weights and the prompt rather than of the host, so the desktop settles the quality question validly and far more cheaply. **One check gates the whole desktop route:** the local endpoint must accept **image input**, not just text — the entire test is photo→plan, and a text-only endpoint invalidates the desktop plan. The desktop result **reads in one direction only**, because the Android artifact is differently and more aggressively quantized: a desktop **failure kills a candidate outright** (the phone build cannot do better), while a desktop **pass is provisional** and must be re-verified on the handset before commitment. **Gemma 4 E2B is the preferred candidate and is tested before E4B** — it is smaller on exactly the axis the standing constraint cares about (not every handset can host a model, nor every user spare the storage), so if E2B passes the work ends on the better outcome and only its failure sends the test on to E4B. **E2B's Android size is not yet recorded**; the 3.66 GB on disk and ~3283 MB peak memory on record are E4B's and remain correct for E4B. And if E2B wins, the on-device re-verification matters *more* rather than less: the smaller model has less headroom to lose to quantization. **One shared harness answers two questions at once:** the same harness targets **five candidates** — E2B and E4B locally via Lemonade, plus Gemini, OpenAI and Anthropic, the three already on the FR-28 allowlist — over one corpus of real clutter photos, one prompt, one structured-output schema and one written pass bar, so a single session resolves this question's topology half *and* the structured-output-reliability criterion OQ-10 left as the remaining basis for provider selection. **The harness lives outside the app** — not in `lib/`, not in `tool/`: a script calling five endpoints is legitimate tooling, and as app code it would violate the §7 egress map and the no-network-SDK rule. Storage, peak memory, inference latency and thermal behaviour **remain handset questions and remain deferred**; the FR-28 access interface keeps the choice a configuration rather than a rewrite. EU data residency is deferred to the phase where users who are not family exist — it is a jurisdiction concern of scale, not of validation. → `bmad-architecture` designs for both; real-photo tests decide.
2. ~~Self-report instrument for SM-2~~ — closed 2026-08-20, see SM-2.
3. ~~Content of the 5 default FlyLady zone Archetype Templates~~ — closed 2026-08-23. The lifecycle split settled on 2026-08-21 stands unchanged (Evergreen ships pre-sliced because FlyLady is published; Epic is never templated because it is personal). What was still open — the concrete content — is now authored rather than deferred, and widened well past five zones: the Evergreen Library covers three cadences, daily anchors and Baseline Upkeep included (FR-31, addendum A12). ~~What survives is a UX question rather than a content one: how cluster-level curation is presented at onboarding without becoming the list NL-1 abolishes. → `bmad-ux`~~ — closed 2026-08-27 at `bmad-ux`: onboarding is the product plus a one-time ambient strip offering cluster-level curation (switch rows, cluster granularity only — never a browsable catalogue); no wizard, dismissed = never again, settings and the template-selection surface (E1) remain (FR-31).
4. ~~"No overdue" — schema constraint or UI rule?~~ — closed 2026-08-20, see §7.
5. Local-first storage tech and the export/escape-hatch format → architecture.
6. Does the seasonal suggestion engine (FR-15) need any configuration surface in v1, or pure defaults? → Sergio, revisit at `bmad-ux`; defaults-only is the standing answer until a suggestion actually misfires.
7. Exact Ambient Invitation copy (FR-24) — one fixed string, or a small rotating set to avoid the blindness that kills any repeated notification? Must survive the SM-C3 constraint either way. → `bmad-ux`.
8. ~~Android delivery mechanism for FR-24 under Doze/battery optimization: is an inexact daily alarm acceptable (invitation slips by an hour) or does the chosen hour need to hold?~~ — closed 2026-08-26 at `bmad-architecture`: inexact daily alarm. `USE_EXACT_ALARM` is Play-restricted to apps whose core function is precise timing — which this app is the negation of — and FR-24's copy carries no clock to be wrong about. An invitation that arrives whenever is still an invitation.
9. ~~Model API access path, credential custody and proxy design~~ — closed for v1. BYOK (FR-28) removes the proxy entirely: no auth flow, no developer key custody, no request logging, no scaling question. Credential protection and restore semantics live in FR-28; FR-29 owns invalid, unavailable or exhausted credentials; A14 and architecture AD-22 own the mechanism. The full proxy design returns with the Managed path (§5.1). → closed by `bmad-architecture` on 2026-08-27.
10. ~~Which providers pass the FR-28 allowlist gate, and what the app does when a listed provider changes those terms after ship~~ — closed 2026-08-26 at `bmad-architecture`. The gate narrowed to **written no-training** (retention dropped — FR-28 owns the reasoning). Initial list: Google Gemini (paid API), OpenAI, Anthropic — all three exclude API data from training by written terms, verified 2026-08-26. Cost is not a selection criterion: a room photo prices at roughly 0.003–0.006 USD per scan, so A8's target is met by every candidate with room to spare, and selection rests on the terms gate and structured-output reliability alone. Stale-terms behaviour: nothing automatic — the dated statement FR-28 already requires is the whole mechanism, and a build is what corrects it.
11. ~~Does Manual Capture accept non-spatial work at all — "llamar al dentista", "entregar el formulario"?~~ — closed 2026-08-27 at `bmad-ux`, confirmed by the builder. The engine stays spatial throughout, and the app never refuses: the capture surface is framed spatially — title, helper, example, the three sizes — so non-spatial work is never invited; the captured line is never validated, and "llamar al dentista" typed or dictated anyway is accepted silently, because rejecting it would shame the user and detecting it reliably is impossible. No invitation, no validation, no refusal — the shaming cost the question warned about is avoided by design rather than absorbed (FR-27). Voice raised the stakes without changing the answer: dictation makes non-spatial capture the cheapest thing in the product, which is why the silent-acceptance ruling is load-bearing rather than hypothetical. The dates sub-question closes with the authorized frame copy: it says nothing about dates — the line is plain text and the surface does not lecture (FR-27).
12. Does excluding clock-bound work leave a hole the user feels? The catalogue ships the dishes and skips the cooking that produced them. That is coherent for the engine — the Floating Time Bag has no hour, so a task with one cannot be dealt (§5.2, FR-31) — and it may read as arbitrary to someone standing in the kitchen at eight in the evening. The exclusion is philosophical and not up for phasing; what is unwritten is the copy, because nothing currently explains why the app knows about the plates and not the meal. Same underlying question as OQ-11 — what this app is for — whose framing half has since closed (2026-08-27); the copy half here stays open on its own. → `bmad-ux`.
13. ~~When on-device Spanish recognition is unavailable, FR-32 makes the microphone simply absent and says nothing about it. May settings carry a one-time pointer to the system's own language-pack installation?~~ — closed 2026-08-27 at `bmad-ux`: absent-and-silent stands as the decision — no language-pack pointer anywhere, in settings or elsewhere. The distinction that survives: recognition *unavailability* shows nothing at all, while a *refused permission* carries a settings reactivation row unified with the camera's pattern (FR-16, FR-32). The multi-language concern is covered by construction — every string is externalized i18n-ready (§7), so a second locale is translation, not redesign.


## 10. Parameters and Assumptions

### 10.1 Confirmed Parameters (2026-08-20)

Fixed decisions, not assumptions. Downstream workflows may treat these as given; they are validation-build values chosen for a single user and expected to be revisited with real usage data, not tuned mid-window.

| Parameter | Value | Where |
|---|---|---|
| Energy check-in | once per day at the first opening, skippable, resolved = gone for the day; Sunday yields the slot to the SM-2 self-report first; default 🟢 daily, no decay | FR-4 |
| Rescue Mode trigger | soft heuristic: declined on 3 different days; or user request anytime | FR-5 |
| Warm Return trigger | ≥ 48 h of absence | FR-6, §3 |
| Time Bag | default 15 min, range 5–30; below 10 the day composes without a Focus Chunk, silently | FR-7 |
| Anti-Marathon checkpoint | default 15 min, range 10–15; rest offer at every interval multiple, never a session limit; sessions shorter than one interval simply end | FR-10 |
| Quarantine Box follow-up | 6 months from the box's date, once — blind timer, copy never claims knowledge of the box | FR-21 |
| Snowball condition | ≥ 10 comfortable days — each with ≥ 1 session, ≥ 1 completed Micro-task and no session beyond its declared pocket (FR-26 series (a); internal, never shown) — suggests +≤ 5 min, suppressed at the bag's top | FR-23 |
| Notifications | exactly one opt-in silent daily invitation, off by default | FR-24, §5.2 |
| Validation window | 4 consecutive weeks | §8 |
| Validation fleet | two computer-managed handsets (builder + wife) plus the sister-in-law's field-use-only handset, never connected to a computer | §8 |
| Photo uploads | per-scan consent only, no blanket opt-in; face/person frames refused on-device | FR-25 |
| Instrumentation | local-only, four series, no analytics SDK | FR-26 |
| AI Access Path | BYOK only, vetted-provider allowlist, no account, no proxy; Local and Managed interface-only — Managed is credits, never a subscription (§5.2) | §7, FR-28 |
| Manual Capture | always available; one task per capture, three sizes; typed or dictated; no list, no editing after leaving the surface | FR-27, FR-32 |
| Archetype Templates | one kind only: the Evergreen Library, pre-sliced product content; an Epic is never templated | FR-11, §3 |
| Evergreen Library | three cadences, pre-sliced at build time; coverage floor ≥ 28 distinct 10–15 min non-daily entries (weekly zones + `fondo`) | FR-31, A12 |
| Zone rotation | weekly, over active clusters only — a disabled zone's week passes to the next active zone | FR-11, FR-31 |
| Time Bag coverage | advance work only; upkeep and habits outside it; session bounded by the declared pocket, not the budget | FR-7, FR-12, FR-8 |
| Clock-bound tasks | no entry carries an hour, mealtime or dependency; cooking out, post-meal upkeep in | FR-31, §5.2 |
| Catalogue curation | cluster level only, in onboarding + settings; never task level, never from the Dispenser, never user-authored | FR-31 |
| Manual Capture deal latency | within 3 eligible days of capture, oldest first, ahead of same-size Evergreen/Epic material; a pending 10–15 min capture fills the day's Focus Chunk slot | FR-12, FR-27 |
| On-device candidate | Gemma 4 E2B preferred, E4B fallback (Android, native multimodal) — both exist; slicing quality unproven for both; tested on the development machine first via Lemonade | OQ1, §4.4 |
| Origin Context of a `shipped` task | its Spanish catalogue name — one line, resolved from the string table by the entry's key; no catalogue field added | §3, FR-5, FR-31 |
| Task origin tag | every Micro-task tagged `shipped` / `manual` / `local` / `cloud` | FR-26 |
| Export | automatic, silent, foreground-triggered, to a user-chosen local folder; state in settings only; restorable via settings import | FR-30, §7 |
| Local path in v1 | ships as a debug-only canned-slice stub, so the access interface has two callers | FR-28 |
| FR-29 copy | seven no-Slicer strings authored before the failure path is wired; part of the SM-C2 audit | FR-29, §7 |
| SM-2 instrument | one 5-point question, Sundays — ambient in the Dispenser, persisted until answered that week, never notified | §8 |
| Voice input | capture line only; on-device recognition; no cloud fallback; keyboard always retained; nothing parsed from the transcript | FR-32, §5.1 |
| Voice audio | never stored, exported, transmitted or instrumented; the transcript is the only artifact | FR-32, §7 |
| Entry visibility (mic and camera) | permissions requested at first use, never at first run; refused or system-revoked permission removes the entry until reversed in settings — camera row always present (owns disable + reactivate), mic row only while a reversal is possible; camera disableable outright; mic unavailable → absent and silent, no pointer | FR-16, FR-32 |
| Keyboard dependency | no goal reachable only by typing — photo path wordless, capture line dictatable, Evergreen pre-sliced; the genesis surface's typed entrance is an alternative with the wordless camera route beside it; settings (incl. the BYOK key) may type | §7, FR-11, FR-32 |

### 10.2 Remaining Assumptions

- §4.11 FR-31 — the library is assumed broad enough that a 28-day window never repeats a non-daily Micro-task, and that literal non-repetition is enough to avoid prompt blindness. It may not be: blindness can set in on category rather than on task ("otra vez el baño") well before any entry comes round twice. FR-26 series (a) would show it as sessions shortening across the window with no matching change in energy reports.
- §4.11 / §4.2 — Baseline Upkeep sitting outside the Time Bag assumes Sergio reads the budget as "time I give to getting ahead" rather than "time I give to the house". If he reads it the second way, FR-23's dashboard will feel like it undercounts his day: the dishes are done and the number did not move. The dashboard already shows cumulative minutes, so the remedy if this appears is a display decision, not a model change.
- §4.11 — the catalogue is assumed to fit an ordinary Spanish flat well enough at cluster granularity. It was authored for one home. A cluster that does not apply (no terrace, no car) is disabled whole, and there is deliberately no finer control — per-task opt-out would be the browsable list FR-31 refuses.
- §4.4 FR-16 — with latency demoted (OQ1 ruling), the remaining scan-experience assumption is that an in-app wait with visible progress stays acceptable on mid-range hardware; the 30 s budget is gone, and price-reasonableness rests on current market levels until monetization is designed.
- §4.4 — cloud vision processing is acceptable for validation privacy provided the provider does not train on uploads. FR-28's allowlist makes verified no-training terms a build-time gate, so the residual assumption is narrow and named: that the user enters a key from a paid tier rather than a free one. The app cannot verify that, states it once at key entry, and leaves it there — the key is the user's and so is the responsibility (FR-28, 2026-08-26). Brief retention for abuse monitoring is accepted rather than assumed away: it is universal among reachable providers and is no longer part of the gate.
- §1/§2 — the builder (Sergio) is the primary validation user; his wife and sister-in-law run independent single-user instances as an annex (their counters are never merged into SM-1–SM-3). The data model is single-user throughout because projects are personal portfolios, not household entities — two people sharing a home are two parallel users, and the app coordinates nothing between them. The household/multi-user vision (§5.1) is knowingly untested by this build.
- §4.4 — deployment topology stays open until real-photo tests. Gemma 4's phone-class variants remove the existence doubt (§4.4, OQ1) but not the quality one, and the builder's separate doubt — that not every future user's phone could run a local model — remains a scale-phase question, not a validation one. The three-path access interface (FR-28) is what makes that doubt cheap: it is a configuration, not a rewrite.
- §4.9 FR-27 — Manual Capture's three coarse sizes are assumed sufficient for the Project Weaver's budget arithmetic (FR-12). Free-form minutes were rejected deliberately: a user's minute estimate is the least reliable number in the system, and the three sizes are already the 1-3-5 taxonomy, so a manual task lands in the composition without a conversion step. If manual estimates wreck the budget math, the failure shows up as sessions overrunning the Time Bag, which FR-26 series (a) already records.
- §4.9 / §4.3 FR-13 — the Invisible Buffer absorbs deferrals and absences, not estimation error. Manual Capture introduces a third source of slack demand FR-13 was never designed for: self-estimated durations, which humans systematically underestimate. The predicted failure path is arithmetic rather than tonal — sessions overrun, the Anti-Marathon Checkpoint fires more often, and a checkpoint that fires too often stops reading as permission and starts reading as interruption. FR-12 now records the origin mix so this is detectable; no calibration is attempted in v1.
- §8 SM-4 — BYOK biases SM-4 against itself. A8 requires that Sergio never hesitate before shooting a photo, and BYOK puts a real metered bill in front of him that the Managed path's flat fee would have hidden: the cheapest path to build is the worst one for the thing being validated. Assumed mitigation for the window: buy a fixed credit up front so no meter is visible during the 4 weeks. If hesitation still appears, SM-4 is reading the payment model rather than the hook.
- §8 annex — per-key cost attribution from the builder's single provider account is assumed available (distinct keys per person, no payment method, per-person cost visible to the builder) and stable across the window. If the provider that passes the FR-28 gate lacks it, the accepted fallback is a shared key agreed explicitly by all three subjects — per-person attribution is then simply unavailable, and the annex reports cost as one figure (OQ-10 keeps the aggregator-policy half).
- §4.9 FR-27 — Manual Capture is assumed not to cannibalize the photo loop. It might; SM-4 is now written to detect exactly that. The alternative — withholding a manual entrance to protect a metric — would make the app unusable on day one in order to keep a measurement clean, which is the wrong trade (addendum A9).
- §4.9 FR-32 — on-device Spanish recognition is assumed present on the validation devices and accurate enough on household vocabulary that accepting a transcript is the common case and correcting one the exception. Both halves began unverified and they fail differently. If accuracy is poor the keyboard absorbs it silently (FR-32 keeps it), and voice simply reads as noise rather than as a broken feature. If *availability* is poor, the accessibility floor §7 now claims is void on those devices — and that is the claim to test against a real handset first, because it is a promise about who can use the app rather than a convenience. The availability half was settled 2026-09-01 on the two computer-connectable handsets (story 3-1: both AVAILABLE, `es-ES` installed); the field-use-only handset is never probed, so the assumption stands there untested by design, and the accuracy half remains open on all three.
- §4.9 FR-32 / §5.2 — voice is assumed to lower the cost of capture without raising its volume enough to turn the floor into the road. It may not: a capture that costs three seconds of speech invites exactly the head-emptying that a pool with no visible bottom and no list has no answer for, and the Weaver's deal-within-3-days rule (§10.1) would then crowd Evergreen and Epic material out of the day. FR-32's dictation boolean read against SM-4's origin mix is what shows it — Focus Chunks dominated by `manual` captures that were mostly dictated is this failure, distinct from the payment-model failure A9 predicted. No throttle, cap or warning is built in v1; §1.1 principle 6 already names who has violated the design if a list appears as the remedy.
- §8 SM-2 — a 1-point shift on a 5-point single-question self-report by a single self-aware user is taken as meaningful signal. The instrument is now fixed (SM-2), so this is an assumption about the reading, not about the measurement. Ruling: no blinding, no anchor item — the validation is deliberately not a rigorous study. Annex subjects' weekly answers and general observations are anecdotal color ("how the app feels"), never statistical evidence; the primary user's own within-subject reading carries the verdict.

## Changelog

History, kept out of the body by design: every section above states current rules only. Findings and triage live in the review files of the run folder.

- **2026-08-20** — First draft and finalization: 23 FRs, 6 features, 4 UJs, addendum. Zero-notifications reversed into FR-24 (opt-in Ambient Invitation); thresholds confirmed; FR-26 instrumentation, §7 constraints and §1.1 principles added in review.
- **2026-08-21** — Elicitation pass dissolved the "works without AI" claim: Manual Capture as permanent floor (FR-27), AI Access Path (FR-28, BYOK-only), honest degradation (FR-29); §7 rewritten; FR-26 origin tags; UJ-5; addendum A9. Second-order pass: capture precedence and the deal window; allowlist frozen at build time; OQ-3 lifecycle ruling; credits-never-subscription; three downstream notes promoted to requirements (Local stub, seven strings, FR-30); per-key attribution correction.
- **2026-08-23** — Evergreen Library widened to three cadences (FR-31, addendum A12); clock-bound work excluded; Baseline Upkeep moved outside the Time Bag; FR-7/FR-12 rewritten for the advance/upkeep split; OQ-3 closed, OQ-12 added.
- **2026-08-26 (voice)** — FR-32 dictation into the capture line: on-device only, no cloud fallback, transcript in the existing field; §2/§3/§6/§7/§9/§10 cascaded; addendum A13; OQ-13.
- **2026-08-26 (UX session `ux-organizer-2026-08-21`)** — `Tirar o soltar` label ruling; §1.1 exception register E1/E2 created; FR-11/FR-20/FR-31 cascaded.
- **2026-08-26 (coherence review, tranche 1)** — FR-31 coverage floor in eligible units with `fondo` eligible; zone rotation over active clusters; Time Bag <10 composes without "1"; checkpoint recurrent with short-session exemption; capture line ruled plain text (UJ-5 fixed); genesis text as third egress payload with send-as-consent; origin immutable under re-slicing.
- **2026-08-26 (coherence review, tranche 2)** — Adversarial: Epic seeds deleted (ADR-2); keyboard floor scoped to user surfaces (ADR-7); SM-2 ambient persisted question (ADR-8); comfortable day defined, principle 2 internal-signals clause (ADR-10); Evergreen active-by-default under curation (ADR-11); Quarantine blind timer (ADR-12); Focus Chunk fixed as the slot, one per day (ADR-14); principle 1 scoped to pending-work lists (ADR-15). Edge: 🟡 filters nothing; capture window freezing; 🔴 mid-task finishes the card; advance-only rollback on pause; bag bounds daily advance; warm pool-exhausted close; rescue reset on activation and silent dissolution; foreground scan wait, no timeout; FR-30 restore import; FIFO captures with no expiry; snowball suppressed at the top; non-empty line gate; onboarding-abandon default all-active. Structure: revision blocks moved here; §3/§6/§10.1 condensed; FR parameter values single-sourced in §10.1 (`Values: §10.1`); the no-list invariant named NL-1; dated provenance stripped from FRs.
- **2026-08-26 (architecture session `architecture-organizer-2026-08-26`)** — FR-28's provider gate narrowed to **written no-training**; retention dropped from the gate, because no provider reachable with a user's own key offers written zero retention and gating on it would have excluded every candidate along with the differentiating hook. Added with it: the key's tier is the user's own responsibility, stated once at key entry (settings) and never repeated; stale terms are corrected by shipping a build and by no other mechanism. OQ-10 closed — initial allowlist Google Gemini (paid API) / OpenAI / Anthropic, verified 2026-08-26; cost removed as a selection criterion at ~0.003–0.006 USD per scan. OQ-8 closed at architecture (inexact daily alarm: `USE_EXACT_ALARM` is Play-restricted to apps whose core function is precise timing, which this app is the negation of, and FR-24's copy carries no clock to be wrong about). FR-25, §7's data-egress bullet neighbours, §9 OQ-1(a), §10.2 and addendum A2/A9 cascaded; `EXPERIENCE.md`'s AI Access Path section cascaded in the same pass.
- **2026-08-27 (architecture reconciliation)** — FR-28's credential-at-rest wording corrected: AndroidKeyStore holds a non-exportable wrapping key, while the provider API key is a provider-scoped encrypted envelope in app-private storage. Provider selection is restorable; credential availability is installation-local and checked live. The prior shorthand that the arbitrary API-key string itself lived in Keystore was not implementable as written.
- **2026-08-27 (UX blocker-resolution pass, session `ux-organizer-2026-08-21`)** — upstream debts from the session's handoff ledger. §1.1 exception **E2 removed**: A-slim genesis restores literal principle-1 arithmetic (the photo path is a direct one-tap camera entry on the Dispenser; the genesis surface carries typed entry as its one recommended action plus settings as the way out), so the register holds E1 alone; FR-11 rewritten to that structure. FR-4 rewritten from a permanent control to a **daily check-in**: first opening of the day, skippable, resolved = gone for the day; Sunday yields the slot to SM-2's self-report first; default 🟢 with no decay (A5 resolved); the mid-task 🔴 clause scoped to while the check-in is open. FR-16 gained camera-entry visibility (disable in settings; permission refused at first use → absent until settings reactivation) and FR-32 mirrors the unified mic/camera reactivation pattern; §7's first-use permission rule generalized to both. FR-31: onboarding realized as the product plus a one-time curation strip, no wizard. FR-27: OQ-11 resolved — spatial framing, no validation, no refusal, silent acceptance, no dates copy. OQ-3 (surviving half), OQ-11 and OQ-13 closed with dated rulings; §3, §10.1 and addendum A5 cascaded. Downstream one-liners owed outside this document: `SPEC.md` and `ARCHITECTURE-SPINE.md` must drop E2 from their sources lines (ledger's order: PRD → SPEC → spine → épicas). Rubric pass (review-ux-handoff-rubric-2026-08-27.md) applied in the same pass: FR-4's Sunday handoff made deterministic against SM-2's weekly persistence (self-report outranks while pending, on any day; dismissal hides for the opening only; unresolved check-in days carried by the 🟢 default); UJ-4 rewritten to the Sunday order and FR-5's three-days trigger; §7's keyboard floor re-scoped from surfaces to goals (the genesis surface's typed entrance is an alternative with the wordless camera route beside it); Dispenser glossary entry now carries the surface composition (entrances + one ambient per opening, rarer instrument wins) and a Genesis surface entry anchors the four drifting names; FR-16 covers system-level revocation and §10.1's visibility row splits mic/camera row-existence; pre-existing mechanicals fixed in passing (OQ-8 struck with the 2026-08-26 ruling, addendum A2/A6/A12.6/A13 closure notes).
- **2026-08-27 (model-testing venue and the `shipped` Origin Context)** — three builder decisions, two of them debts owed upstream from the epic pass. **OQ-1's venue moved off the handset:** the local-model test runs on the development machine first, through Lemonade's OpenAI-compatible local endpoint, gated on that endpoint accepting image input; a desktop failure kills a candidate outright while a desktop pass is provisional until re-verified on the phone, because the Android artifact is more aggressively quantized. **Gemma 4 E2B entered as the preferred candidate, tested before E4B** — smaller on the axis the standing constraint cares about, its Android size not yet recorded, E4B's 3.66 GB / ~3283 MB figures left as E4B's — and one shared harness now covers five candidates (E2B, E4B, Gemini, OpenAI, Anthropic) over one corpus, prompt, schema and pass bar, closing OQ-1's topology half together with the structured-output-reliability criterion OQ-10 left standing; the harness lives outside the app, since as app code it would breach the §7 egress map. OQ-1 stays open: only its venue, candidate set and method are settled. §4.4, §10.1's on-device row and §10.2 cascaded. **A `shipped` task's Origin Context is now defined** as its Spanish catalogue name — one line, the shape a Manual Capture's already has — so the FR-5 decline heuristic firing on a catalogue entry has something to re-slice. No catalogue field is added (the name is an existing string-table entry resolved by the entry's key), rescue steps still inherit origin `shipped`, offline rescues degrade per FR-29, and nothing enters the catalogue. Rejected: name-plus-zone (two Origin Context shapes), a pre-authored rescue stored per entry (breaks FR-31's fields rule, 85 entries of product content), and not-rescuable (the most-repeated tasks in the app are the shipped ones). §3's Origin Context entry qualified in the same pass — "tasks never come from nothing" now distinguishes the personal, which comes from the user, from the shipped, which comes from published methodology sliced at build time (§1.1 principle 6); FR-5 gained two consequence bullets and §10.1 a row.
- **2026-08-27 (UX blocker-resolution follow-up)** — typed-project genesis no longer identifies the provider. Its surface states that the typed description will be analysed to create tasks, and `Analizar` is the consent action; this deviation is intentionally limited to text genesis. Per-scan photo consent still states what is sent and to which provider.
- **2026-08-27 (UX blocker-resolution follow-up)** — FR-20's detachment questions are no longer skippable. Each is answered `Sí` or `No`; the user then chooses one required destination. This replaces the prior no-consequence skip rule.
- **2026-08-27 (UX blocker-resolution follow-up)** — FR-24's daily invitation now uses a motivating, kind rotating copy set. It may make a general reference to household action, a short available time or a change of activity; it still cannot name a pending task, show a count, or frame anything as owed, late, missed or remaining. Its single silent opt-in channel and once-per-domestic-day ceiling are unchanged.
- **2026-09-01 (validation handset topology)** — only two of the three validation handsets are ever USB-connected to the development computer (the builder's and the wife's); the sister-in-law's handset is field-use only — real use in her own household, never connected, never probed. Promotes story 3-1's in-story builder decision to a PRD-level fact and rules out any reading that assumes three computer-managed handsets. The three annex subjects stand unchanged (§8); FR-32's §10.2 availability assumption is now verified on both connectable handsets (2026-09-01, both AVAILABLE with `es-ES` installed) and stays untested-by-design on the field-only handset. Downstream debts logged in the run memlog: architecture's AD-18 release ritual ("export on all three handsets, install on top") needs a cable-free path for the third handset; the epics' "each of the three validation handsets" wording regenerates against this fact.

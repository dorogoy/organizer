# Source extraction — PRD + addendum

Extracted 2026-08-21 for the UX Discovery. Sources:
- `{planning_artifacts}/prds/prd-organizer-2026-08-20/prd.md`
- `{planning_artifacts}/prds/prd-organizer-2026-08-20/addendum.md`

Reference only. **The spines win on conflict.** Quotes are verbatim from the PRD.

---

## Product

Working title **"Anti-Overwhelm Mobile Task Organizer"** (product naming explicitly deferred). A "single-user Android app that turns household and personal chores into one micro-action at a time, distributed across days, with zero guilt mechanics." Positioned as an "empathetic autopilot and cognitive shock absorber."

Core problem: "Traditional task managers fail overwhelmed users psychologically: endless lists, red overdue badges, broken streaks, and rigid time blocks turn productivity into shame."

Engine: FlyLady zone cleaning + 1-3-5 rule + Floating Time Bag (minutes-per-day, not hours-on-the-clock) + AI photo-diagnosis. Differentiating loop: **photo → micro-plan → visual reward.**

Explicit non-users: couples/families, GTD power users, anyone wanting hourly time-blocking or deadline reminders.

## Form factor — RESOLVED by PRD

**Android-only mobile, single device, offline-capable, no account.**

- "a single-user Android app"
- §5.1 Deferred: "iOS, web, desktop, widgets, wearables — Android only in v1."
- A4: "Android-only, single device (the builder's daily phone) … hybrid-vs-native framework choice deferred to architecture (constraint: camera, haptics, background scheduling, local-first storage, i18n-ready strings)."
- §7: "Offline by default — execution, not genesis. … Airplane mode is supported, never an error state." "A phone in airplane mode on day one still has zones, anchors and a composition."
- §7: "No account in the validation build. BYOK needs a key, not an identity: no login, no password, no registration, no first-run network requirement."
- Background work: only FR-24's daily invitation. "No sync, no location, no persistent service, no wake locks."
- PWA never mentioned. Multi-surface and multi-user explicitly excluded.

## Named users

- **Sergio** — "builder and primary validation user", "the builder (PM + implementer)". Primary user of all five journeys. Holds two roles at once, treated as a design constraint: "Settings is where the validator reads; the Dispenser is where the user lives."
- **The builder's wife** (same household) and **sister-in-law** (separate household) — "secondary observers", "independent single-user instances" during the 4-week window. "All subjects are motivated and non-representative."

## Named journeys (§2.3) — mirror verbatim

- **UJ-1.** Sergio spends a 15-minute pocket on the storage room.
- **UJ-2.** Sergio photographs the trastero and gets a micro-plan. *(includes named Edge case: Slicer unreachable)*
- **UJ-3.** Sergio returns after six days away.
- **UJ-4.** Sergio on a low-battery Sunday.
- **UJ-5.** Sergio anota algo a mano en diez segundos.

Named sub-sequences (defined flows, not journeys): **Decluttering Protocol**, **3-Destination Flow** (Keep / Donate-Sell / Trash-Recycle), **Warm Return**, **Rescue Mode** → "2–4 steps of ≤ 60 s each", **30-Second Rescue** ("Just pick up 3 items off the floor.").

## Stated needs → candidate surfaces

| FR | Need | Surface implication |
|---|---|---|
| FR-1 | "exactly one dispensed Micro-task with duration estimate" | **Dispenser** (primary) |
| FR-2 | Done, one tap, "non-intrusive positive feedback and the next card" | Dispenser inline |
| FR-3 | Guilt-free skip — **"Otra más fácil / Ahora no"** | Dispenser inline |
| FR-4 | 1-tap energy check-in 🟢/🟡/🔴 | Dispenser or pre-Dispenser |
| FR-5 | Rescue Mode, user-initiated at any time | Dispenser action |
| FR-6 | **Warm Return** — "rebalanced plan, no backlog, no reference to missed days in any UI element or copy" | Distinct state of Dispenser |
| FR-7 | Time Bag 5–30 min, default 15 | Settings |
| FR-8 | **"Tengo 15 minutos ahora"** trigger | Entry point |
| FR-9 | Pause + silent recalculation. "Resuming deals the next Micro-task directly — never a resume menu about the past." | Dispenser |
| FR-10 | Anti-Marathon checkpoint — "an explicit permission-to-stop screen"; "the permission-to-rest screen is the primary surface"; extending is "an available, silent, secondary action" | **Checkpoint surface** |
| FR-11 | Instantiate Evergreen from Archetype Templates; create Epic from photo or typed/form description | **Project genesis** |
| FR-15 | Seasonal activation suggestion, "dismissible in one tap" | Ambient in Dispenser |
| FR-16 | Photo scan → 3–5 min Micro-tasks with per-step effort. "The wait happens in-app with visible progress and honest copy." | **Scan surface** |
| FR-17 | Before/After — "side-by-side visual diff as reward" | **Reward surface** |
| FR-18 | **Local Transformation Album** — "private, local gallery of before/after pairs and cumulative milestones", deletable individually, purgeable in one action | **Album** |
| FR-20 | Detachment questions verbatim: "Have you used this in the past 12 months?" / "Does this deserve your physical and mental space?" + Keep / Donate-Sell / Trash-Recycle triage | **Declutter flow** |
| FR-21 | **Quarantine Box** — dated box, one dismissible follow-up after 6 months | Declutter flow + ambient |
| FR-22 | Per-destination tap counts; optional volume tags **bolsa / caja / caja grande / mueble**; displayed as **"≈ 3 cajas liberadas"** | Dashboard |
| FR-23 | **Cumulative impact dashboard** — minutes, completed Micro-tasks, liberated items/volume, album highlights + one-tap-dismissable snowball suggestion | **Dashboard** |
| FR-24 | **Ambient Invitation** setup — exactly one daily notification at a chosen hour, off by default | Settings |
| FR-25 | **Per-scan consent screen** — "states, in plain Spanish, what is sent and to whom"; "declining is the same number of taps as accepting" | Scan flow gate |
| FR-27 | **Manual Capture** — "reachable from the Dispenser in one tap and completes in two fields: one line of text, and a size chosen from exactly three options — 30 s, 3 min, 10–15 min. No free-form minute entry exists anywhere." Correctable/discardable only from the capture surface, before leaving. | **Capture surface** |
| FR-28 | **AI Access Path** config — own API key, provider from in-app allowlist. "A free-form endpoint or base-URL field does not exist." Each entry states provider name + date terms verified. | Settings |
| FR-29 | **Seven distinguishable no-Slicer states**, each offering Manual Capture. "none is styled as an error — no red, no warning iconography, no exclamation." | Degradation states |
| FR-30 | Automatic silent export; destination picked once via system folder picker | Settings |
| §8 | SM-2 self-report: one in-app 5-point question, Sundays — **"Esta semana, ¿cuánto te ha agobiado la casa?"** | Ambient weekly |

## Invariant principles (§1.1) — override individual FRs

1. **Zero cognitive load.** "The user never chooses from a list. Any new surface offers at most one recommended action plus a way out."
2. **Uncompromising anti-shaming.** "No red, no overdue, no streak, no count of anything undone. If a feature needs to represent failure or absence to work, it does not ship."
3. **Respect for spontaneity and variable energy.** "Every plan is regenerable… leisure is never a cost."
4. **Invisible buffers.** "Slack is never shown, never configurable, never spendable by the user."
5. **Anti-marathon.** "The app never encourages more than it asked for. No 'keep going' is ever a primary action… the app never asks '¿seguimos?'"
6. **The Slicer authors everything personal.** "Manual Capture never grows into a task manager — the moment it acquires a list, this principle has been violated."

## Explicit UX constraints already committed

**Density / IA**
- "No screen reachable in under 3 taps from the Dispenser ever renders more than one actionable Micro-task at once."
- "No lists, no calendar, no backlog anywhere in the primary surface."
- "A task list, in any form" excluded by philosophy: "No screen anywhere enumerates captured tasks, permits editing them, or lets the user browse what is pending."
- "No GTD density — no tags, filters, kanban, or task hierarchies beyond the dual lifecycle."
- "No interrupted, incomplete, or overdue state is ever displayed anywhere — in either language."
- Epic Projects "dormant until activated and do not appear in any default view while dormant."
- "Epic target dates displayed to the user always include slack the user cannot see or configure."
- Dashboard: "no daily quotas, no averages-over-time comparisons, and no deficit framing."
- Diff view: "no negative framing language (no 'still messy' copy)."
- Origin tag "never surfaced in the Dispenser."

**Interaction / feedback / motion**
- "Completion advances the queue in under 500 ms." "Cold start to first dispensed card ≤ 2 s." Energy re-filter "under 500 ms."
- "Feedback is never modal, never plays loud audio, and never spawns a rating prompt or a nag screen."
- "a subtle haptic buzz and warm confirmation"; "haptics never the sole completion signal."
- Session extension: "the app never highlights, animates, or suggests it." — *the only motion statement in the document.*
- "Stopping is always one tap (FR-9), at any moment, for any reason."
- Suggestions / snowball / quarantine follow-up: "dismissible in one tap."

**Accessibility floor (§7)**
- "Legible at 200% system font scale with no truncation; every action reachable one-handed; haptics never the sole completion signal."

**i18n / copy**
- "Spanish UI, every string externalized, no runtime sentence concatenation — the anti-shaming audit (SM-C2) must be reviewable as a flat string table."
- FR-9 references "in either language" — a second locale is implied but **never named**.
- FR-29: "the seven no-Slicer strings authored before the failure path is wired."
- Fixed Spanish strings: `Hecho` · `Otra más fácil / Ahora no` · `Tengo 15 minutos ahora` · `hay 15 minutos esperando cuando te apetezca` · `≈ 3 cajas liberadas` · `Esta semana, ¿cuánto te ha agobiado la casa?` · `tu clave no es válida` *(cited as a shaming risk — needs rewrite)*

**Notifications (FR-24, §5.2, A6)**
Exactly one, opt-in, off by default, user-chosen hour, silent low-importance channel. "no sound, no heads-up interruption, no badge count." "Suppress the launcher badge explicitly (`setShowBadge(false)`)." No second category ever. At most one per 24 h. "no re-delivery on dismissal, no follow-up if unopened." Rejected alternative: home-screen widget (out of scope §5.1).

**Input modalities**
Camera photo (primary "typeless" path); one-line text + three-size picker (Manual Capture); taps. "No free-form minute entry exists anywhere." Voice excluded — "Voice-first natural-language slicer — Phase 3." No calendar permission ever requested. Consent screen: "no dark-pattern asymmetry."

**Dark mode: absent from the PRD.** Never mentions dark mode, theming, color palette (beyond "no red"), typography, iconography (beyond "no warning iconography"), or branding.

## Domain vocabulary (§3 glossary) — mirror verbatim

**Micro-task** (30 s–15 min, always with duration estimate) · **Dispenser / Single-Task Dispenser** (primary surface: one card, Done / Skip) · **Focus Chunk** (the "1", 10–15 min) · **Micro-maintenance** (the "3", 2–3 min) · **Instant Habit** (the "5", ~30 s daily anchors) · **Floating Time Bag** · **Energy Level** (🟢 High / 🟡 Medium / 🔴 Low) · **Rescue Mode** / **30-Second Rescue** · **Anti-Marathon Checkpoint** · **FlyLady Zone** ("exactly one active zone per day", rotating weekly) · **Archetype Template** (**Evergreen templates** pre-sliced / **Epic seeds** Slicer input) · **Evergreen Project** / **Epic Project** · **Project Weaver** · **Invisible Buffer** · **Silent Rescheduler** · **Photo-Diagnosis** · **Smart Slicer / the Slicer** · **Manual Capture** · **AI Access Path** (Local / BYOK / Managed) · **Origin Context** · **Before/After Reward** · **Transformation Album** · **Decluttering Protocol** · **3-Destination Flow** · **Quarantine Box** · **Warm Return** · **Ambient Invitation** · **Scan surface**

Origin tags: `shipped` / `manual` / `local` / `cloud`. Spanish surface terms: **Hecho**, **trastero**, **bolsa / caja / caja grande / mueble**.

## Non-functional context shaping UX

**Stakes.** Personal validation build, single user, 4-week window. "success is sustained real usage, a felt reduction in overwhelm, and visible progress on a real epic project — without marathons." Not regulated, not a consumer launch.

**Privacy.** "The app holds photographs of the inside of the user's home. Two rules govern them: nothing leaves the device without a per-scan decision, and what leaves is the minimum that makes the Smart Slicer work."
- Consent per scan, every scan. "A blanket 'always allow' setting does not exist."
- On-device face detection: "If the app detects a person or face in the frame, the scan is refused before upload with an offer to reframe; that refusal happens on-device."
- "The scan image is deleted from the device once the micro-plan is generated." Only user-shot Before/After photos persist, locally.
- "Only the scan image and a prompt are sent. No plan history, no album contents, no device or location identifiers."
- "To the developers: nothing." "No app-open counts, no telemetry, no analytics"; no third-party analytics SDK in the build.

**AI access.** BYOK only in v1. Provider from in-app allowlist, gated on "written no-training, no-retention terms", each entry dated. Key in OS keystore, never in the export. Local path = debug-only canned-slice stub. Managed path (proxy + login + non-expiring credits, never a subscription) interface-only and deferred; if built, "its balance is never surfaced outside settings."

**Export (FR-30).** Destination folder picked once via system picker; thereafter "every subsequent export happens without being asked for: plans, album images and all FR-26 series", "the same single legible-text-plus-images format." Foreground-triggered at "end of a session, app going to background" — no background job. "No reminder, no badge, no backup-age indicator, no 'last exported' line and no failure toast exists in the Dispenser or anywhere the user lives." Failure visible in settings only, "never framed as the user's omission." One-tap manual export also remains.

**Data ownership.** "No developer-held data of any kind." "Local-first only, and no provider integration ever." "The app never transmits the export. It writes a local file" — a synced folder is the user's own client's job.

**Schema constraint with UX consequence.** "no field, flag, or derived value anywhere may express lateness, debt, or a missed occurrence. Overdue-shaped data breeds overdue-shaped UI."

**Counter-metrics that constrain design.** SM-C1: "Minutes or tasks per day must NOT be pushed upward." SM-C2: "Guilt events = 0 — count of UI/copy occurrences that frame anything as owed, late, or failed must remain zero." SM-C3: notification volume must not rise above 1/day and "invitation copy must NOT acquire task content, counters, or urgency."

**Latency exemption.** Slicing has "No latency cap" (OQ1 demoted it) — the scan wait must be designed for: "in-app with visible progress and honest copy"; "if completion is asynchronous, it is announced only inside the app."

---

## Gaps routed to UX

Explicitly assigned to `bmad-ux` by the PRD:

- **OQ-6** — "Does the seasonal suggestion engine (FR-15) need any configuration surface in v1, or pure defaults? → defaults-only is the standing answer until a suggestion actually misfires."
- **OQ-7** — "Exact Ambient Invitation copy (FR-24) — one fixed string, or a small rotating set to avoid the blindness that kills any repeated notification? Must survive the SM-C3 constraint either way."
- **OQ-11** — "Does Manual Capture accept non-spatial work at all — 'llamar al dentista', 'entregar el formulario'? … Accepting means three of the glossary's size labels mislead for a subset of the pool, and FR-4's energy filter has no criterion for a phone call. Refusing means the app tells the user their task does not belong here, which is a small shaming of its own. → before FR-27 is built."
- **A5** — "Energy check-in should be ambient and optional: a default of 🟢 with gentle decay toward 🟡 late in the day was floated in brainstorming but left undecided — UX decision."
- **OQ-3 residue** — "What remains open is only the wording of the five zones. → before FR-11 is built."
- **FR-29's seven strings** — required deliverable, unwritten: no key configured, invalid key, exhausted quota, provider unreachable, no network, consent declined, person detected in frame.

Openings the PRD states as absent (not inferred):

- **No visual identity at all**: no product name, no color system beyond "no red", no typography, no iconography, no dark-mode stance, no motion language beyond one prohibition.
- Copy unauthored for: Anti-Marathon permission-to-rest screen, Warm Return screen, Done feedback.
- How the silent "extend the session" secondary action is presented "without highlighting, animating, or suggesting it."
- Before/After diff presentation — side-by-side is stated; layout, sharing, framing is not.
- Decluttering Protocol question presentation, and how "answerable by skip" is surfaced.
- How the seven degradation states are visually differentiated given "no red, no warning iconography, no exclamation."
- Onboarding / first-run never described as a surface — only "no network, no account" and zone selection "per-person selection at install."
- Scan progress/wait experience — no cap, no specified affordance beyond "visible progress and honest copy."
- Settings IA — contents enumerated, never organized.
- Second-language target implied by "in either language" is never named.

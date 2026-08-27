---
name: Anti-Overwhelm Mobile Task Organizer
description: Experience spine for a single-user Android household task dispenser. One card at a time, nothing enumerated, nothing accumulated. Paired with DESIGN.md, which owns the visual identity.
status: final
updated: 2026-08-27
sources:
  - "{planning_artifacts}/prds/prd-organizer-2026-08-20/prd.md"
  - "{planning_artifacts}/prds/prd-organizer-2026-08-20/addendum.md"
---

# Anti-Overwhelm Mobile Task Organizer — Experience Spine

## Foundation

Single-surface **Android** mobile. One device, one user, **no account**, offline-capable — airplane mode is a supported condition, never an error state. iOS, web, desktop, widgets and wearables are explicitly deferred by the PRD, so there is no second surface to reconcile and no parity question to answer.

**No UI system is named.** Navigation, system gestures, the back gesture and dynamic type are inherited from platform convention. Where a behaviour here differs from the platform default it says so explicitly; everything unstated is the platform's.

`DESIGN.md` is the visual identity reference and owns how this looks — palette, type ramp, iconography, the misregistration idiom, dark mode. This spine owns how it works. Visual specs are referenced by token (`{path.to.token}`) and never restated. Upstream product content — the six invariant principles, the thirty-two FRs, the glossary, the counter-metrics — is inherited from `sources` by reference and not duplicated here.

**Responsive & Platform is deliberately omitted.** There is one surface, one form factor and no breakpoint; everything that section would carry is stated above or in Accessibility Floor.

**Mockups illustrate; they do not specify.** Eight promoted artifacts sit in [`mockups/`](mockups/), each carrying a note at its top naming what in it is superseded and by what; superseded exploration stays in `.working/`. The one supplied visual reference — [`imports/dandelion-seed-reference.png`](imports/dandelion-seed-reference.png), the builder's own drawing of the dandelion seed — is a shape reference for the third destination glyph, specified in `DESIGN.md` and reconciled claim by claim in [`reconcile-dandelion-seed-reference.md`](reconcile-dandelion-seed-reference.md). **The spines win on conflict** — over the PRD, over the reference image, and over every artifact in `mockups/` and `.working/`. *Realigned 2026-08-26 against the PRD's 2026-08-23 and 2026-08-26 revisions* (Evergreen library, FR-32 voice, both coherence tranches), then carried through the **blocker-resolution pass of 2026-08-27** (the seven no-Slicer strings, the canonical Dispenser, the Micrófono and Manual Capture, Settings IA and curation, the completed dark palette). **One known divergence with `sources` is open by design:** the PRD's §1.1 still carries the E2 exception, which the A-slim genesis restructure dissolved here — the upstream removal is owed, in the same payment pattern as `Tirar o soltar` and E1 before it.

## Information Architecture

| Surface | Reached from | Purpose |
|---|---|---|
| **Dispenser** | App open (cold start) | The primary surface and **where the user lives**. Exactly one dispensed Micro-task on a `{components.dispenser-card}`: duration, task, `Hecho`, `Otra más fácil / Ahora no`, zone marker. |
| Pocket trigger — `Tengo 15 minutos ahora` | Dispenser | Declares a **session pocket** and re-filters the pool. The pocket is not the Time Bag: the bag (5–30 min, default 15) bounds the day's **total advance** — once the day's Focus Chunk has been dealt, later sessions that day compose of upkeep and habits only, silently (FR-7, FR-12). Rendered as `{components.duration-chip}`. |
| Energy check-in | Dispenser — the ambient strip, first opening of the day | Three battery marks — llena / media / baja — three direct taps (FR-4). Exists to ask for **less**: media filters nothing, only baja narrows. Once a day: answered or dismissed, it is gone until tomorrow. Sunday the strip belongs to the weekly self-report first; once that resolves, the check-in may take the slot in the same opening. |
| **Scan** | Dispenser, one tap — the Cámara entry, top-right | Photo-Diagnosis of a real space. This IS the photo path of project genesis: photographing a space and having the Slicer cut it is one flow with one entry — the duplication this table used to carry is resolved. The entry is absent, never greyed, when the camera is disabled in Settings or its permission was refused (reactivable in Settings). |
| **Per-scan consent gate** | Scan, before every upload, every time | States in plain Spanish what is sent and to whom. Declining costs the same number of taps as accepting. **The only surface in the app with zero recommended actions** — `{components.action-equal-pair}`, neither button filled. |
| **Manual Capture** | Dispenser, one tap — and the single exit from the no-Slicer surface | One line of text — **typed or dictated on-device** (FR-32) — plus a size from exactly three options (30 s / 3 min / 10–15 min). |
| **Project genesis** | Dispenser — the text link `Nuevo proyecto`, as its **recommended action** | The typed path: describe a project in writing and the Slicer seeds the Epic Project. **The photo path is the Dispenser's direct Cámara entry** — an add-work action, not a departure. The Archetype Template list opens from the manual-entry screen. That screen states what is sent and to which provider — **the send action is the consent** (FR-25, §7). `Ajustes` is the way out, as quiet text. |
| **Archetype Template / cluster curation** | Genesis' manual-entry screen — a complement there, never a third top-level path; onboarding and Settings carry the same capability (FR-31) | Enumerates templates and clusters, and **curating Evergreen clusters is all it does**: selection enables or disables clusters — product content, never pending work. It **never creates an Epic Project** (FR-11) and never enumerates individual catalogue entries (FR-31). **The surface shows a list**, by the builder's explicit decision (E1). |
| **Anti-Marathon checkpoint** | Dispenser, at every multiple of the checkpoint interval inside a session | The permission-to-rest screen **is** the primary surface. Rest is offered at each interval boundary — a 45-minute pocket with a 15-minute interval offers it three times — and extending is an available, silent, secondary action. Sessions shorter than one interval reach no checkpoint: their close is the permission to stop, and when the final checkpoint coincides with the close, that close is the offer (FR-10, UJ-1). |
| **Before/After reward** | Dispenser, on completing work a Before photo was taken for | Side-by-side visual diff. No negative framing, no "still messy" copy. |
| **Transformation Album** | Before/After reward, when a transformation completes — **contextual only** | Private local gallery of Before/After pairs and cumulative milestones. Individually deletable, purgeable in one action. |
| **Cumulative impact dashboard** | Transformation Album — **contextual only** | Minutes, completed Micro-tasks, liberated volume (`≈ 3 cajas liberadas`), album highlights, one dismissible snowball suggestion. |
| **Decluttering Protocol** | Dispenser, when the dealt Micro-task is a decision about an object | The two detachment questions, verbatim per FR-20, answerable by skip. |
| **3-Destination Flow** | Decluttering Protocol | One decision on a whole screen: `Quedármelo` · `Donar o vender` · `Tirar o soltar`. Three choices and nothing else. `{components.destination-flow}`. |
| **Quarantine Box** | 3-Destination Flow | A dated box for the undecided, with exactly one dismissible follow-up after six months. |
| **No-Slicer surface** | Scan or project genesis, whenever the Slicer cannot run | **One** calm surface carrying seven different strings, plus one exit — `Anotarlo`, to Manual Capture. |
| **Settings** | Dispenser — from inside `Nuevo proyecto`, as the quiet text way-out | **Where the validator reads.** A flat platform list in five quiet groups, from what the house does to plumbing: **Tu día** (Time Bag) · **Contenido de la casa** (cluster curation, on a sub-screen of `{components.curation-row}` rows) · **IA y voz** (provider allowlist, key + the free-tier sentence once, dictation boolean read-only, mic entry *only* when its permission was refused, camera entry disable+reactivate) · **Avisos** (Ambient Invitation opt-in + hour) · **Tus datos** (export destination + manual export + last result never framed as omission, import/restore, album purge). Light/dark follows the system — no row, the app's only un-duplicated preference. |

Ambient, one strip below the card — **one spec for six residents, the differences in behaviour rather than chrome**: the seasonal activation suggestion, the six-month Quarantine follow-up, and the snowball suggestion (all one-tap dismissible, at most one visible), the daily energy check-in (first opening of the day, gone until tomorrow once answered or dismissed), the Sunday self-report `Esta semana, ¿cuánto te ha agobiado la casa?`, which **persists until answered that week** (SM-2) and is **never notified** — a notification would violate FR-24 and §5.2 — and the **one-time first-run curation offer**, which appears once ever and never returns once dismissed. Sunday the self-report holds the strip first; once it resolves, the check-in may take the slot in the same opening — each is one tap, and nothing nags after. The strip's chrome rule: **ephemeral = bare, persistent = hairline** — check-in and suggestions sit bare on the ground; the self-report carries a 1px hairline edge because it stays. Dismissal of the self-report hides it for the opening, not the week; a week with no answer simply has no data point.

**Navigation is mixed, and every half of it is a decision.** There is no nav bar, no drawer and no list of destinations anywhere — not as restraint but because conventional navigation is unavailable here. Principle 1 caps any surface at one recommended action plus a way out, and the PRD forbids browsing what is pending. A bottom bar with four destinations would violate the invariant and the information-density ceiling at once. Two mechanisms carry the whole map instead.

- **Contextual.** The Transformation Album is reached only when a Before/After completes; the cumulative impact dashboard is reached from the Album. **Nothing is reachable "just because"** — a surface appears when its moment arrives, and not before.
- **One quiet departure on the Dispenser, and it is prose, not a glyph.** The text link `Nuevo proyecto` (ink-secondary, the `{typography.action-secondary}` pattern, bottom-centred) opens the typed path of project genesis as the recommended action, with **Settings as the way out** — one recommended action plus one way out, literally. The mark question is dissolved by the same move: a glyph has to mean one thing, and this affordance means two (project entry + configuration behind it); prose can name both. The grammar it establishes is checkable: **on the Dispenser, everything carrying a pastel mass does something to the day — Cámara, Lápiz, the card — and the departure is text.** The misregistration idiom is designed to be *seen*, the opposite of discreet; it was never going to mark the quietest control on the screen. The Ajustes glyph is dissolved with it: Settings is reached as quiet text inside the affordance's surface, so no drawing ever needs to read as "settings". Rejected: a settings glyph on the affordance (Settings is the way *out*, not the destination); two separate affordances (they would redistribute the departure this concentrates); the gear as a documented single-ink exception (mooted by dissolution).

**Two consequences, recorded rather than smoothed over.**

- **The contextual half means these surfaces exist without always being available.** If the user never completes a transformation, the Transformation Album is unreachable for as long as that lasts — and the dashboard behind it with it. That is accepted, not an oversight: a permanently reachable Album is a surface that invites browsing, which is the thing the product removed.
- **Concentrating the departure into one point is deliberate**, and the PRD supplies the cover for that point being Settings — *Settings is where the validator reads*. The single place the user can leave the Dispenser for is the place already specified as not being where the user lives.

**The genesis zone — photo is an invitation, not a gate.** In the builder's words: *"No podemos obligar a la gente a que use el sistema de fotos si no quiere."* The photo path is a first-class Cámara entry on the Dispenser itself; **manual entry sits behind `Nuevo proyecto` and is always available**. Neither is a precondition for the other. The **Archetype Template list is offered from the manual-entry screen**, where it is a complement or a help — **not** a third top-level genesis path. **The template surface shows a list**, by the builder's explicit decision (E1).

**Slimmed to compliance — 2026-08-27, and E2 dissolves.** With the camera sited directly on the Dispenser, what sits behind `Nuevo proyecto` is: the typed project entry (recommended action), the template list offered from it (E1), and Settings as the way out. Count it: **one recommended action plus one way out — principle 1 satisfied literally.** The E2 exception (multi-path genesis zone) is no longer needed and **dissolves**; the declared-exception register shrinks to two, the FR-23 density exception and the consent gate's zero recommended actions. The zone is still entered from exactly one place, and the list still lives on the template surface and nowhere else.

**Paid into the PRD** — 2026-08-27: §1.1's exception register now holds **E1 alone**, and FR-11's genesis bullets carry the A-slim structure (the photo path as the Dispenser's camera entry, the genesis surface with typed entry plus its way out). FR-11 and FR-31 kept their consequences; only the E2 entry retired. `SPEC.md` and the Architecture Spine's `binds` line dropped E2 in the same pass, so no document disagrees about which exceptions exist. The upstream edit this paragraph used to demand is closed; what remains here is the record of the arithmetic behind it.

**Also rejected, on measurement:** serialising the templates one at a time behind a *see another* deck. It removes the *list* and not the *choice*, hides how large the set is, and puts no ceiling on the number of taps — worse than a list on the only question principle 1 asks, which is whether the user is choosing. Drawn and judged in [`mockups/key-screens-1.html`](mockups/key-screens-1.html) § 4, whose verdict box is the record of how this arithmetic was reached; that page's genesis screens are superseded in structure and say so at the top.

**Invariants that govern the whole map.**

- **No screen anywhere enumerates pending tasks.** Nothing lets the user browse what is pending, edit it, or count it. No lists, no calendar, no backlog, no kanban, no tags, no filters. Dormant Epic Projects appear in no default view. **The one list in the app is the Archetype Template surface**, which lists templates and clusters — product content, never pending work — and whose selection enables or disables Evergreen clusters (FR-31); it never creates an Epic Project (FR-11) and never enumerates individual catalogue entries. It is the declared exception above.
- No screen reachable in under three taps from the Dispenser renders more than one actionable Micro-task at once. Beyond the PRD's cap on *actionable* items, **information** is capped too — one card, mostly empty space.
- No interrupted, incomplete or overdue state is displayed anywhere, in either language. The schema cannot express lateness, so the UI cannot render it.
- The **cumulative impact dashboard is a declared density exception** — the single multi-value surface in the app. It is written as an exception precisely so it is not a precedent, and **that density must not propagate to any other surface** (see `DESIGN.md` Do's and Don'ts). The Sunday self-report is the only other place where more than one value shares a surface; it inherits the ordinary card rules, not the dashboard's licence.
- **The denominator rule — this is the mechanism that makes the density exception safe, and it is checkable line by line.** Six values share that screen, which on any other surface would be a violation, and it does not shame because **no value on the screen admits a denominator**. Every figure is a completed fact with no reference number to be measured against: no *"de 7 días"*, no average, no target, no *"this week, less than last"*, no per-day rate, no percentage, no completion ratio. That absence is what stops cumulative figures turning into quotas, averages or deficits. It is also what a reviewer checks, one value at a time: **if a value could be given a denominator, it does not belong on this screen.** `4 h 25 min de trabajo hecho, desde el primer día` has no denominator; *"4 h 25 min de las 10 h de esta semana"* has one, and would be forbidden. The corollary: adding any comparison — to a goal, to a prior period, to another person — breaks the exception rather than extending it. The screen is drawn at both scales in [`mockups/key-screens-1.html`](mockups/key-screens-1.html) § 3.
- **The volume line carries no glyph, and the general rule behind it.** `≈ 3 cajas liberadas` stands as a figure alone, because the system's only box glyph *is* `Quedármelo`, the first choice of the destination trio, and setting it beside a sentence about boxes *released* would say the opposite of the sentence. Generalised in `DESIGN.md` as the glyph-adjacency rule: **a destination glyph appears only where the destination it names is the meaning being expressed.**
- **The dashboard is also the one place 200% breaks a layout rather than a size** — see Accessibility Floor. `{components.dashboard-highlight-row}` reflows to a single column; it never shrinks.
- Origin tags (`shipped` / `manual` / `local` / `cloud`) exist in the data and are never surfaced in the Dispenser.

## Voice and Tone

Microcopy discipline. Register, warmth and the print idiom live in `DESIGN.md`.

**Every string is externalised and no sentence is concatenated at runtime.** This is a hard structural rule, not a preference: the anti-shaming audit (SM-C2) must be reviewable as a **flat string table**, and a sentence assembled from fragments at runtime cannot be audited. Guilt events must read zero — no string frames anything as owed, late or failed.

Fixed strings, verbatim, not to be re-worded downstream:

| String | Where |
|---|---|
| `Hecho` | `{components.action-primary}` |
| `Otra más fácil / Ahora no` | `{components.action-secondary}` |
| `Tengo 15 minutos ahora` | `{components.duration-chip}` / pocket trigger |
| `Despeja la mesa del salón` | The measured sample task, `{typography.task}` |
| `Quedármelo` · `Donar o vender` · `Tirar o soltar` | 3-Destination Flow |
| `≈ 3 cajas liberadas` | Cumulative impact dashboard |
| `Esta semana, ¿cuánto te ha agobiado la casa?` | Sunday self-report, ambient and dismissible |
| `hay 15 minutos esperando cuando te apetezca` | Ambient Invitation notification |
| `por hoy no hay nada más que merezca la pena` | Session close on pool exhaustion (FR-3) — neutral, warm; part of the SM-C2 audit table |
| `No hay clave de IA guardada. Crear un proyecto a partir de una foto necesita una; puedes añadirla en Ajustes.` | No-Slicer surface · no key configured |
| `La clave guardada no es válida. Puedes revisarla en Ajustes.` | No-Slicer surface · invalid key — the rewrite of the PRD's flagged `tu clave no es válida` |
| `El crédito de la clave se ha agotado. Se repone en la cuenta del proveedor, no en la app.` | No-Slicer surface · exhausted quota |
| `El servicio de IA no responde ahora mismo. Puedes intentarlo más tarde.` | No-Slicer surface · provider unreachable |
| `El móvil está sin conexión. Los servicios que usan IA no son accesibles.` | No-Slicer surface · no network |
| `La foto no se ha enviado.` | No-Slicer surface · consent declined |
| `Se ve una persona en la foto, así que no se ha enviado a ningún sitio. Puedes repetirla sin nadie en el encuadre.` | No-Slicer surface · person detected in frame |
| `Anotarlo` | No-Slicer surface — the single exit, to Manual Capture |
| `Nuevo proyecto` | Dispenser — the quiet text departure, opening typed project genesis |
| `¿Cuánta energía tienes hoy?` | Energy check-in — the daily ambient strip, first opening |
| `Nada` · `Muchísimo` | End labels of the Sunday self-report's 1–5 scale |
| `Un rincón de la casa` | Manual Capture — title, names a place (the frame's rule 1) |
| `Una cosa que se pueda señalar con la mano: un cajón, una estantería, una silla, un rincón.` | Manual Capture — helper, touchable things (rule 2) |
| `Vaciar la caja de la entrada` | Manual Capture — example, opens with a spatial verb (rule 3) |
| `Escríbelo o dilo en voz alta` | Manual Capture — field placeholder, naming both modalities (FR-32) |
| `Escuchando…` | Manual Capture — while dictating; prose declares the live state, ink never moves |
| `Guardar` · `Descartar` | Manual Capture — confirm (disabled until the line holds text) and the single exit |

| Do | Don't |
|---|---|
| Name the cost before the ask (duration above the task). | Frame a duration as a deadline. |
| Say what happened. `Hecho`. | Congratulate volume — no "you're on three", no combos. |
| Offer a way out in the user's own register — `Otra más fácil / Ahora no`. | Ask `¿seguimos?`, or make "keep going" a primary action. |
| State plainly what the app cannot do right now. | Frame a degradation as the user's fault or as an error. |
| Accept what the user typed. | Correct, validate or reject captured text. |
| Leave the missed days unmentioned. | Reference absence, count it, or apologise for it. |
| Exclamation-free, alarm-free, streak-free. | Red, warning iconography, exclamation marks, badges, overdue language. |
| Let the reward caption name the place, the moment and the authorship. | Any adjective about the result — *mejor*, *más despejado*, *casi*. An adjective is a scale, and a scale brings back the deficit. |
| Let a cumulative figure stand as a completed fact. | Give any figure a denominator — a target, an average, a period to compare against, a percentage. |

**`Tirar o soltar` is a confirmed, intentional change from the PRD's original `Tirar o reciclar` / *Trash-Recycle*.** *Soltar* dodges both the deletion vocabulary of a bin and the compliance vocabulary of recycling arrows, which is the whole reason the third destination does not read as the bad one. **Paid into the PRD** — 2026-08-26: §3 and FR-20 now carry the `Tirar o soltar` label with its rationale, `Trash-Recycle` remaining the internal concept name. The divergence this paragraph used to flag is closed.

**The seven no-Slicer strings are authored — 2026-08-27, verbatim in the fixed-string table above.** They carry the entire differentiation load of that surface (there is no visual differentiation — see State Patterns), and none frames the user as at fault. The register is the builder's directive: the key and configuration causes are **objective problems of the app, not of the home** — *señalar y listo*. State the fact, name the remedy where one exists, no cushioning. FR-29's requirement to name the distinction plainly is carried by **precision** rather than reassurance: each string scopes exactly what is unavailable (`los servicios que usan IA`, `crear un proyecto a partir de una foto`), so none implies the whole product is degraded. The PRD's flagged `tu clave no es válida` is rewritten as `La clave guardada no es válida` — the shaming lived in the possessive, not in the judgment, and objectivity pays the flag.

**One deliberate deviation, recorded so it is not read as an omission: the consent-declined string names no remedy.** FR-29 asks every cause to name its own remedy, but here the remedy would be *retry and accept* — the persuasion the PRD forbids on this path. `La foto no se ha enviado.` states the fact and stops; `Anotarlo` is the way forward, and nothing invites a second attempt.

## Component Patterns

Behavioural only. Visual specs live in `DESIGN.md` Components.

| Component | Use | Behavioural rules |
|---|---|---|
| `{components.dispenser-card}` | Dispenser | One card, one Micro-task, always with its duration. On completion **the card leaves** (below). Never compresses to fit more; the screen scrolls instead. The air around it is a **minimum plus flex**, never a fixed value — at 200% the card grows into it (see `DESIGN.md` Layout & Spacing). |
| `{components.action-primary}` — `Hecho` | Dispenser | One tap. No confirmation, no undo prompt, no modal. One recommended action per surface, outside the two declared exceptions. |
| `{components.action-secondary}` — `Otra más fácil / Ahora no` | Dispenser | **One control, never split** (below). Available and never suggested: no animation, no emphasis, no hint. |
| `{components.duration-chip}` | Dispenser eyebrow; pocket trigger | Reading order is the mechanism — the cost is read before the ask. Never a countdown, never a clock. |
| Energy check-in | Dispenser — the ambient strip, once a day | Three battery marks (`{components.energy-checkin}`): llena / media / baja, each a direct tap (FR-4), llena pre-marked as the standing default. Re-filters the pool in under 500 ms. Media filters nothing — only baja narrows, to Instant Habits and ≤ 60 s; a day of middling energy is not a smaller day (FR-4). Tapping baja while the strip is still open behaves like the checkpoint: the card in progress can be finished, and the filter applies to the next deal — work in progress is never withdrawn without comment. Only ever narrows what is asked of the user; never unlocks anything. Mid-session overload after the strip has gone rides on `Otra más fácil` (FR-5), which is the per-task relief. Default llena, fixed, no decay, reset daily. |
| `{components.destination-flow}` | 3-Destination Flow | Three equal-weight choices at `{spacing.glyph-destination}`, `{spacing.destination-row-gap}` between rows, one decision per screen, nothing else on it. No default, no pre-selection, no ordering signal. Skip is a legitimate answer. |
| `{components.zone-marker}` | Dispenser footer | Names the one active FlyLady zone for today, in `{typography.support}`. A place-marker, not a control — it is not a filter and opens nothing. |
| Ambient strip | Dispenser, below the card | One spec, six residents (see Information Architecture). Seasonal, snowball, Quarantine follow-up and the one-time first-run curation offer: sentence in `{typography.support}`, tappable where an accept exists and never a primary action, ✕ dismiss at `{spacing.touch-target-min}`, bare chrome. The energy check-in and the Sunday self-report are the strip's other residents (chrome rule: ephemeral bare, persistent hairline). At most one visible at a time. The snowball suggestion is suppressed when the Time Bag sits at the top of its range — there is nothing left to suggest (FR-23). |
| Curation row | The E1 template surface, onboarding's one-time offer, and Settings — one component, three homes | A platform switch row: cluster name, **cadence in `{typography.support}`** (diaria / semanal / mensual-estacional), and the switch — tappable anywhere in the row. Cadence is product metadata, not volume: it tells the user what rhythm they are switching without enumerating anything. Enabling and disabling produce no count, no summary and no copy about what changed (FR-31). Never a task-level row; none of the three homes may read as a browsable catalogue. |
| Quiet affordance — `Nuevo proyecto` | Dispenser | The **single** departure from the Dispenser, and it is **text, not a glyph**: ink-secondary, the `{typography.action-secondary}` pattern, bottom-centred. Opens the typed project entry as the recommended action, with Settings as the text way-out inside. Never animated, never emphasised, never badged — and never carrying a pastel mass, because on this surface **mass means work and prose means leaving**. |
| Cámara — the Scan entry | Dispenser, top-right | Opens Scan directly: one tap to the camera. **Absent, never greyed, never explained**, when the user has disabled the camera in Settings or refused its permission at first use — the microphone's absent-and-silent pattern, plus a reversal path: Settings re-enables the entry, and the OS permission is requested again at the next first use. Visibility = enabled ∧ permission not refused; the app never re-asks on its own. |
| Genesis paths | Project genesis | The photo path is the Dispenser's own Cámara entry; behind `Nuevo proyecto`, manual entry is the recommended action and is **never gated** by anything. The Archetype Template list opens from the manual-entry screen only, and selecting a template is a tap like any other — no confirmation step; what it does is enable or disable Evergreen clusters (FR-31), nothing more. The manual-entry screen states what is sent and to which provider: **the send action is the consent** (FR-25, §7). |
| `{components.action-equal-pair}` | Per-scan consent gate, and nowhere else | Two answers of identical weight, one tap each, no delay on either, no fill on either. **This surface has zero recommended actions** — the only one in the app. Declining opens no confirmation, no second ask, no persuasion; it lands on the no-Slicer surface with its own string. |
| `{components.size-option}` | Manual Capture | Three options shown as durations (`{formats.duration}`), never as glossary names. Single selection, always populated: no empty state, no "none of these". Selected is `{colors.accent-soft}`; unselected is a hairline. Changing the selection is a tap and costs nothing. |
| Microphone affordance | Manual Capture, and nowhere else | An **explicit press** starts dictation; nothing listens outside it — no wake word, no ambient capture, no background audio (FR-32). The transcript lands **in the existing one-line field on the existing surface** — never a confirmation screen — and FR-27's correct-or-discard affordance governs a mis-hearing, which makes it load-bearing. The mark is the capsule glyph at the field's end (`{components.microphone-glyph}`); while dictating it declares itself in ink and prose — blue mass plus the caption `Escuchando…` — and **never by motion** (the breathing cue was offered and declined). One utterance produces at most one Micro-task; nothing is ever parsed out of the transcript, and a spoken duration is words in the line like any others. **The keyboard is never removed**; correcting a transcript requires it. Recognition is on-device with no cloud fallback, and no audio is retained anywhere. Where on-device Spanish recognition is unavailable — no language pack, unsupported device, microphone permission refused — the affordance is **simply absent**: no error, no greyed-out state, no install offer — the language-pack pointer stays absent-and-silent, by decision 2026-08-27. The permission is requested at the first dictation attempt, never at app entry and never at first run; refusing it leaves keyboard capture fully functional and the app never asks again. Dictated tasks carry origin `manual` and are indistinguishable once dealt; a separate local dictation boolean is readable **in Settings only**. |
| `{components.photo-frame}` | Before/After reward, Transformation Album | Equal size, equal height, same corner, labels outside the frame. Loading shows an empty frame of the right shape — no spinner, no shimmer. Every image is local; nothing here is ever uploaded. |
| `{components.dashboard-highlight-row}` | Cumulative impact dashboard only | Three highlights, each a thumbnail plus place and `{formats.short-date}`. Reflows to one column when a caption passes two lines; never shrinks, never truncates. Tapping a highlight is a way *into* the Album, not a browse surface. |
| `{components.icon-glyph}` · `{components.seed-glyph}` · `{components.destination-mark-dark}` | Throughout | Drawing specs with no behaviour of their own. `destination-mark-dark` is the dark-mode form of the destination trio; how light/dark is selected is unresolved (Open Questions). |

**The card leaves.** On completing a Micro-task the card does not change content — it **exits**. The justification is platform-specific and decisive: in Android's gesture vocabulary, dismissing a card means the card *disappears*. The iOS reading — dismissed cards stack somewhere else — is what would have implied accumulation, and the app is Android-only, so the Android reading governs and the accumulation risk does not apply. Two hard constraints on the departure: **it must exit the screen entirely**, and **it must never fly toward a counter, a pile or a badge**, because that would reintroduce accumulation through motion after the whole product removed it from the data.

**Celebration is mandated, not forbidden.** FR-2 requires non-intrusive positive feedback; the PRD specifies a subtle haptic buzz and warm confirmation, and calls FR-17 a visual reward. The line is not whether celebration exists but **where it points**:

- It must **close** — "done, and that is enough." Celebration that opens a door — "done! another?" — is forbidden even with identical animation. What disqualifies it is the continuity gesture, not the sparkle.
- It must **not scale with quantity**. The same celebration every time. No combos, no streak, no "you're on three." This follows directly from counter-metric SM-C1: a celebration that grows with volume pushes with light instead of words.
- It must **never gate the next card**. Completion advances the queue in under 500 ms; celebration may overlap the next card's arrival but never delays it.
- **Two tiers, and the restraint at tier one is what makes tier two mean anything.** Tier one: a small warm haptic acknowledgement per Micro-task. Tier two: the Before/After diff, which is the real reward.

**Tier two, and the two rules that keep it from becoming a score.** Both were established by drawing it, and both are checkable.

- **Proportion does the work a score would do.** Two `{components.photo-frame}` plates of **equal size, at equal height, with the same corner**, `{spacing.photo-pair-gap}` apart, and the labels `Antes` / `Ahora` **outside** the pastel rather than on it. That layout makes the comparison legible without anyone grading it. The moment one plate is larger, or higher, or framed differently, the layout starts having an opinion — and an opinion is a rating. This is what replaces the percentage, the star, the score and the progress bar, none of which exist.
- **The reward caption has a hard ceiling: it may name the place, the moment and the authorship — and nothing else.** `La mesa del salón, esta tarde. Esto lo hiciste tú.` is the shape of it. There is no third sentence available without entering judgement: **any adjective about the result — *mejor*, *más despejado*, *casi* — reintroduces a scale, and with a scale the deficit comes back.** The ceiling is narrower than it looks before you try to write it, which is why it is written here as a rule and not left to the copywriter's taste. The caption's type role is `{typography.caption-warm}` (`DESIGN.md`), the only role in the ramp created for one sentence. Drawn in [`mockups/key-screens-1.html`](mockups/key-screens-1.html) § 5, where the plates are icon-mass pastels standing in for photographs — declared scaffolding on that page, and forbidden in the product.
- **The secondary here closes, it does not continue.** `Cerrar`, never a variant of *seguir*. The closing rule above binds hardest on this surface, because this is the one place the celebration is large enough to be worth extending.

**The single secondary control stays unsplit.** `Otra más fácil / Ahora no` carries two distinct PRD features — `Otra más fácil` is FR-5 Rescue Mode (simplify the dealt Micro-task at any time) and `Ahora no` is FR-3's guilt-free skip. Splitting it would fix the 200% line-break fold and tell the truth about what it is, and it was still rejected: principle 1 allows a surface **at most one recommended action plus a way out**, and keeping this as one control is exactly what preserves that invariant. Consequence carried knowingly: the string cannot survive intact at 200% system font scale, so **the fold is accepted and must be verified on a real Android device** — the measurement behind it was taken in Blink, and Android's line breaker is a different engine. The string is never split, shortened, ellipsized or hard-broken.

## State Patterns

| State | Surface | Treatment |
|---|---|---|
| Cold open | Dispenser | One card in ≤ 2 s. Never a splash, never a loader before the first card. |
| **Warm Return** | Dispenser | A rebalanced plan. **No backlog, and no reference to missed days in any UI element or copy.** The days away are not representable in the schema, so they cannot appear. Copy unauthored (Open Questions). Illustrated at register scale in [`mockups/seed-at-scale-1.html`](mockups/seed-at-scale-1.html) § 4. |
| Pause | Dispenser | One tap, at any moment, for any reason. Recalculation is silent and invisible. |
| Resume | Dispenser | **Deals the next Micro-task directly.** Never a resume menu, never a summary, never anything about the past. |
| Energy level | Dispenser | Defaults to llena, **fixed, no decay, reset daily** — the pool stays wide at all times. The check-in exists only to ask for **less**: once per day, at the first opening, skippable — never a gate to be cleared. Rejected (A5, grounds unchanged): decay toward media late in the day (it would shrink the pool during the app's real usage window and force a tap to *correct* the app), last-choice-persistent (one bad day silently starves the app for weeks), and no default at all. Visual corollary of the once-a-day cadence: the level is behaviour, not chrome — after the strip leaves, nothing on the Dispenser displays it; the narrower deal is itself the display. |
| Camera disabled or refused | Dispenser | The Cámara entry is simply absent — no error, no greyed state, no explanation. Reversible only in Settings (see Component Patterns). |
| **No Slicer** (all seven causes) | No-Slicer surface | **ONE calm surface carrying seven different strings (fixed-string table, Voice and Tone) plus a single exit — `Anotarlo`, to Manual Capture — not seven visual states.** No visual differentiation is needed or wanted, which dissolves the no-red / no-warning-iconography / no-exclamation conflict entirely. **None is styled as an error.** The full-screen illustration register applies (see `DESIGN.md`). |
| Manual Capture | Manual Capture | Spatial work only, achieved by framing rather than by refusal: **no invitation** to non-spatial work, **no validation**, **no rejection** (the frame, and why it needs no refusal, are below). Correctable and discardable only here, before leaving the surface. Nothing appears afterwards: no list, no counter, no confirmation screen. The confirming action stays **disabled until the line holds text** — a blank capture is not a task (FR-27). The line is typed or dictated (FR-32; microphone affordance in Component Patterns). |
| Anti-Marathon checkpoint | Checkpoint | Rest offered at **every multiple of the checkpoint interval** within the session; a session shorter than one interval reaches none, and its close is the permission to stop (FR-10). When the final checkpoint coincides with the close, that close is the offer (UJ-1). The permission-to-rest screen is the primary surface. Extending the session exists as an available, silent, secondary action — never highlighted, never animated, never suggested. The app never asks `¿seguimos?`. Copy unauthored (Open Questions). Illustrated at register scale in [`mockups/seed-at-scale-1.html`](mockups/seed-at-scale-1.html) § 4. |
| Offline / airplane mode | Everywhere | Supported, **never an error state**. Zones, anchors and a composition exist on a phone in airplane mode on day one. No banner, no retry prompt, no degraded chrome. |
| Person detected in frame | Scan | Refused **on-device, before any upload**, with an offer to reframe. |
| Consent declined | Scan | No upload happens. Lands on the no-Slicer surface with its own string and the Manual Capture exit. No re-ask, no persuasion, no second attempt at the gate. |
| Scan wait | Scan | In-app, with visible progress and honest copy. There is **no latency cap** — the wait must be designed for rather than raced against — and deliberately **no timeout**. Leaving the surface or backgrounding the app **cancels the wait and discards it** — the same nothing-is-queued rule as failure (FR-16, FR-29). The affordance is unspecified (Open Questions). |
| Dormant Epic Project | Everywhere | Absent from every default view until activated. Not listed, not counted, not previewed. |
| Export failure | Settings only | Visible nowhere the user lives, and **never framed as the user's omission** (see Export Silence). |
| Empty Album / empty dashboard | Album, dashboard | Unauthored (Open Questions). Whatever is written may not count what is absent. |
| Pool exhausted mid-session | Dispenser | The session closes early with the fixed warm string `por hoy no hay nada más que merezca la pena` — never an error, never an empty state styled as absence or debt (FR-3). Part of the SM-C2 audit table. |
| Later session, same day | Dispenser | Once the day's Focus Chunk — or its rescue steps — has been dealt, later sessions compose of upkeep and habits only, silently. No budget-exhausted state exists anywhere; chaining sessions cannot multiply advance (FR-7). |
| First run / onboarding | Dispenser | **Onboarding is not a gate — it is the product, plus one strip.** First open puts the card on screen in ≤ 2 s: the working Evergreen 1-3-5 day, zero typing, zero network, zero key (FR-31). The curation offer lives on the ambient strip **once ever**: tappable to the cluster list, dismissable, and dismissed it never returns — Settings and the E1 surface remain the permanent paths. No wizard, no welcome screen delaying the first card: the ≤ 2 s contract holds hardest on day one, the day of the promise. |
| Onboarding curation abandoned | Onboarding | Abandonment mid-curation leaves the default standing — every cluster active — and the first composed day is never empty (FR-31). |

**Manual Capture's spatial frame is an ordering rule, not a copy suggestion.** It fits in two sentences plus one example, and **the order is what does the work**, so it is written as a sequence a reviewer can check:

1. **The title names a place** — a place in the house, not a task and not a category.
2. **The helper lists things you can touch** — a drawer, a shelf, a chair, a corner: things that can be pointed at with a hand.
3. **The example opens with a spatial verb** — *"Vaciar la caja de la entrada"*, a verb that acts on an object in a room.

Read in that order, non-spatial work does not occur to the user, which is why no refusal is needed. Change the order — put the example first, or let the helper name outcomes instead of objects — and the frame stops framing. The three sizes are shown as durations (`{formats.duration}`), never as the glossary's internal names, because that vocabulary names a role inside the plan rather than what the person will spend. The surface is drawn in [`mockups/key-screens-1.html`](mockups/key-screens-1.html) § 1.

**And the confirmed absence, which is the proof that the frame works: there is no error state, no validation and no rejection, therefore no second version of this screen exists.** No red edge, no corrective message, no *"esto no encaja aquí"*, and no gentle equivalent of one. If `llamar al dentista` is typed, it is accepted in silence. Rejecting would shame; detecting reliably is impossible; so neither is attempted. One secondary control only — `Descartar`, which is also the exit; no `Cancelar` beside it, because that would be a second way out on a surface that already has a recommended action.

**Voice is now specified — FR-32, in the PRD since 2026-08-26.** The forward-looking note this section carried is retired: dictation into the capture line ships in this build, on-device only, and the surface's behaviour is specified under Component Patterns (the microphone affordance) and Interaction Primitives. The consequence predicted here stands, and is now load-bearing rather than hypothetical: **dictation makes non-spatial input more likely, not less** — `llamar al dentista` is easier to say than to type. That puts more weight on the spatial frame's ordering rule above and on the no-validation, no-rejection decision: the frame is the only thing standing between dictation and a to-do list (§1.1 principle 6).

## Interaction Primitives

- **One tap** is the unit for every primitive act: done, skip, dismiss, stop. Nothing important costs two.
- **Stopping is always one tap, at any moment, for any reason.** There is no wrong moment to stop and no state in which stopping is unavailable.
- **Timings are contractual.** Cold start to first dispensed card **≤ 2 s**. Completion advances the queue in **under 500 ms**. Energy re-filter **under 500 ms**.
- **Feedback is never modal, never plays loud audio, and never spawns a rating prompt or a nag screen.** A subtle haptic buzz plus a warm confirmation; haptics are never the sole completion signal.
- **Input modalities:** camera photo (the primary typeless path), taps, and one line of text plus a three-size picker in Manual Capture — the line typed **or dictated on-device** (FR-32; see the microphone affordance in Component Patterns). **No free-form minute entry exists anywhere.** Voice fills that one field and nothing else: no voice command exists anywhere, and the Dispenser is operated by tapping (§1.1 principle 1). No calendar permission is ever requested.
- **Notifications — exactly one category, forever.** The Ambient Invitation: opt-in, **off by default**, at a user-chosen hour, on a silent low-importance channel. No sound, no heads-up interruption, no badge count; the launcher badge is suppressed explicitly. At most one per 24 h, no re-delivery on dismissal, no follow-up if unopened. Its copy must never acquire task content, counters or urgency (SM-C3). No second category is ever added.
- **Background work** is limited to that one daily invitation. No sync, no location, no persistent service, no wake locks — and **no microphone outside an explicit press** on the dictation affordance (FR-32). Voice adds the build's one new runtime permission, requested at the first dictation attempt and never at first run.
- **Banned everywhere:** lists, calendars, backlogs, counts of anything undone, streaks, badges, overdue anything, red as alarm, warning iconography, exclamation marks, `¿seguimos?`, "keep going" as a primary action, a blanket "always allow" consent setting, always-on listening or ambient audio of any kind, and any motion that carries a completed card toward a counter, a pile or a badge.

## Accessibility Floor

Behavioural. Contrast ratios and the type ramp live in `DESIGN.md`.

- **Legible at 200% system font scale with no truncation.** The floor stands as a live constraint — only the demonstration tile in [`mockups/color-themes-1.html`](mockups/color-themes-1.html) was dropped as scaffolding. Nothing is ellipsized, nothing gets `maxLines`; the card grows and the screen scrolls, which is correct. The `Otra más fácil / Ahora no` fold is the known pressure point and must be verified on a real device.
- **One named, expected degradation: the dashboard's three-highlight row at 200%.** It is the only place in the app where 200% breaks a **layout** rather than merely a size. Nothing truncates — so the floor is met — but each column of `{components.dashboard-highlight-row}` falls to **~101dp** and its caption breaks to **four or five lines**, and the row stops reading as a row. **The stated fallback is a reflow, not a shrink: the row drops to one column per row as soon as a caption would break beyond two lines.** The trigger is expressed in lines rather than in dp deliberately, so it survives a different line breaker and a second locale. Nothing else on the screen scales: the dp gaps stay put, because what grows at 200% is content, never the grid. This is expected behaviour and is not a defect to be filed.
- **Every action reachable one-handed.** Touch targets never below `{spacing.touch-target-min}`, which is a platform constant and does not scale with font size.
- **Haptics are never the sole completion signal.** Every haptic acknowledgement is accompanied by something visible.
- **Shape carries the entire differentiation load in the 3-Destination Flow, and this is load-bearing.** Coloured destination tiles were dropped, so hue now lives *only inside each glyph* — on the order of 200 device pixels. For a user with reduced colour vision, `{colors.dest-keep}`, `{colors.dest-donate}` and `{colors.dest-trash}` contribute almost nothing, and the three choices are told apart by **silhouette alone**. That is a real cost, accepted, not a detail — and it produces one non-negotiable rule: **the three destination hues never appear as a field, tile, bar or band without their glyph inside.** A hue on its own carries no meaning to part of the audience, so it must never be asked to.
- Utility glyphs carry `{colors.icon-mass-neutral}` and no semantic hue; the zone-marker Hoja carries `{colors.icon-mass-ochre}`, which is neither the neutral mass nor any destination hue and is separated from the nearest of them by 17.21 against a threshold of 15. Nothing outside the trio can be mistaken for a destination.

## Privacy & Consent Behaviour

The app holds photographs of the inside the user's home. Two rules govern them: **nothing leaves the device without a per-scan decision, and what leaves is the minimum that makes the Slicer work.** The behavioural consequences:

- **Consent is per scan, every scan.** A blanket "always allow" setting **does not exist** and must not be added as a convenience. The gate states, in plain Spanish, what is sent and to whom — the named provider, the scan image and a prompt, nothing else.
- **Genesis text travels on the scan's terms.** The manual-entry screen of project genesis states, in plain Spanish, what is sent and to which provider — the typed or form description of the project (FR-11) — and **the send action is the consent**: an explicit send with the destination named, not a separate dialog (FR-25, §7's egress map).
- **Declining is the same number of taps as accepting.** No dark-pattern asymmetry: no larger accept button, no dimmed decline, no "are you sure", no delay before decline becomes tappable.
- **The consent gate is the only surface in the app with ZERO recommended actions, and that is a rule rather than an omission.** Every surface carries exactly one recommended action plus a way out, apart from this gate and the genesis zone. This one carries none, because FR-25's symmetry requirement **expels `{colors.accent-soft}` from the surface entirely**: filling either button makes it the recommended one, and recommending is exactly the dark pattern the requirement forbids. Both answers are therefore `{components.action-equal-pair}` — identical width, height, ground, hairline edge, type role, ink and tap count, with no fill on either. It is a **declared exception** to the one-recommended-action invariant, written as an exception in the same spirit as the FR-23 density exception so that it is not read as a precedent: no other surface may borrow it. Drawn in [`mockups/key-screens-1.html`](mockups/key-screens-1.html) § 2.
- **The residual asymmetry that cannot be removed is reading order, and it is recorded rather than claimed solved.** Two buttons in a row are read left to right; stacked, one is on top. No arrangement escapes it. `Enviar` sits in the **first slot**, which for a consent decision is the unfavourable position rather than the favourable one — the honest direction to fail in, and still a failure of symmetry rather than symmetry. Everything else about the pair is verifiable by looking, which is what makes the requirement auditable.
- **On-device face detection refuses before upload.** If a person or a face is in the frame, the scan is refused *on-device* — the image never leaves — with an offer to reframe. The refusal is about the frame, never about the user.
- **The scan image is deleted from the device once the micro-plan is generated.** Only user-shot Before/After photos persist, and only locally.
- **What is never sent:** plan history, album contents, device or location identifiers. **To the developers: nothing.** No app-open counts, no telemetry, no analytics, no third-party analytics SDK in the build.
- **Audio: nowhere, to no one (FR-32).** Voice dictation is recognised on-device, has no cloud fallback, and no audio is written, retained, exported or instrumented — the transcript is the only artifact. The egress map gains no destination.
- The Transformation Album is local and private: entries individually deletable, the whole album purgeable in one action.

## AI Access Path & Degradation

- **BYOK only in v1.** The user supplies their own key; the provider is chosen from an **in-app allowlist**. A free-form endpoint or base-URL field **does not exist**. Each allowlist entry states the provider name and the date its no-training terms were verified. **Key entry carries one sentence, once**: a free-tier key may be used for training and the app cannot tell which tier a key belongs to. It is stated at the moment it is actionable and never repeated — not on the Dispenser, not as a badge, not as a recurring warning (FR-28).
- **A key is not an identity.** No login, no password, no registration, no first-run network requirement. The key lives in the OS keystore and never appears in the export.
- The Local path is a debug-only canned-slice stub. The Managed path is interface-only and deferred; if it is ever built, its balance is never surfaced outside Settings.
- **Configuration lives in Settings — where the validator reads — and never intrudes on the Dispenser, where the user lives.** The Dispenser never mentions a key, a quota, a provider or a network.
- **Degradation is one calm surface, seven strings, one exit.** Whatever the cause — no key, invalid key, exhausted quota, provider unreachable, no network, consent declined, person in frame — the user meets the same composed screen and the same single onward move: Manual Capture. Nothing is styled as an error, nothing is retried automatically in front of the user, and nothing implies a task was lost. The Slicer being unavailable degrades **genesis**, never execution: the dealt pool is local, so the Dispenser keeps working.

## Export Silence

Export exists so the user owns their data, and it is designed to be **unnoticeable**.

- The destination folder is picked **once**, through the system folder picker, in Settings. Every subsequent export happens without being asked for: plans, album images and all FR-26 series, in the same single legible-text-plus-images format.
- **Foreground-triggered** — end of a session, app going to background. No background job. The app writes a local file and **never transmits it**; putting that folder in a synced directory is the user's own client's job.
- **Nowhere the user lives is there any trace of it.** No reminder, no badge, no backup-age indicator, no "last exported" line, no failure toast — not in the Dispenser and not anywhere else. Silence is the specified behaviour, not an omission to be corrected later.
- **Failure is visible in Settings only, and never framed as the user's omission.** No "you haven't backed up", no elapsed-time guilt, no call to action.
- A one-tap manual export also remains available in Settings, for the validator rather than for reassurance.
- **Restore lives in Settings too**: a one-file-picker import restores plans, album and series in full — no merging, no partial restore. It is what makes the export format a *restore* format rather than a promise (FR-30).

## Inspiration & Anti-patterns

- **Rejected — the wellness / self-care register.** Dusty pastels and soft corners are exactly where every habit, mood and meditation app already lives, and that is the streak-and-badge category this product exists to reject. The palette stays soft anyway, and the antidote is a different **drawing language**: printed-matter iconography, risograph misregistration, a colour plate slipped off its line plate. Softest colour register, most graphic mark-making — that collision is deliberate and it is the brand.
- **Rejected — streaks, badges, counters, overdue markers.** Every one of them needs to represent absence or failure to work, and a feature that needs to represent failure does not ship.
- **Rejected — trash bins and recycling arrows** for the third destination. They *implican imposición* — imposition and deletion — and the whole trio depends on the third choice not reading as the bad one. The dandelion seed is the release gesture as the user's own breath: chosen, gentle, not institutional. Two of the three destinations mean the object goes on existing, which is what makes the trio genuinely equal. **One consequence is accepted rather than smoothed over:** motion dashes are barred from the destination trio on ink-parity grounds, and by the system's own inverse rule that makes the 64px trio seed read **at rest** rather than in flight — the opposite of the reference drawing's mid-flight feeling. It was confirmed knowingly once it had been named instead of arrived at as arithmetic, and dashes-on is now reserved for the illustration register at 56px and above (`DESIGN.md`).
- **Rejected — the paper aeroplane, on measurement.** It was area-matched and ink-matched to the other two and it still lost, for one reason: **it is the only mark in the trio that POINTS.** A 23° nose, implied velocity, an offset that reads as speed. In a row of three equal-weight choices, the one that points is read first. The plane version nudges the user toward option three, discarding. The alternative asymmetry (the eye landing on the box, i.e. toward keeping) is inert; this one **contradicts the product's purpose**. An anti-overwhelm app must not push the user toward throwing things away.
- **Rejected — splitting `Otra más fácil / Ahora no` into two controls**, despite it being two offers and two FRs. The reasoning, and the 200% cost accepted with it, is under Component Patterns.

## Key Flows

Protagonist: **Sergio**, the builder and primary validation user. He holds two roles at once, and that is a design constraint: *Settings is where the validator reads; the Dispenser is where the user lives.* Journey names mirror the PRD verbatim.

### UJ-1 — Sergio spends a 15-minute pocket on the storage room

1. He opens the app at 21:50, depleted. Cold start puts **one** card on screen in ≤ 2 s: the duration above, the task beneath, `Hecho`, `Otra más fácil / Ahora no`, and the zone marker as a quiet footer.
2. He has a real pocket of time, so he declares it: `Tengo 15 minutos ahora`. The pool re-filters to what fits.
3. He does the Micro-task and taps `Hecho`. The card **leaves the screen entirely** — a small warm haptic, a warm confirmation, and the next card arrives in under 500 ms without the celebration holding it up.
4. The next card is more than he has left. He taps `Otra más fácil / Ahora no` — the one control, either offer. No explanation is asked for and none is offered.
5. He does one more.
6. **Climax:** the pocket's minutes are spent and the Anti-Marathon checkpoint arrives — as **permission to stop**. With the default 15-minute interval inside a 15-minute pocket, the final checkpoint coincides with the close, and that close is the offer (FR-10). That is the primary surface; continuing is there, silent, unhighlighted, unanimated. Nothing counts what is left, nothing asks `¿seguimos?`, and there is no number anywhere that would have been higher if he had kept going. He puts the phone down and the storage room is measurably less than it was.

*Failure path:* he abandons mid-task. Stopping is one tap. Recalculation is silent, and when he comes back the app deals the next Micro-task directly — never a menu about what he left.

### UJ-2 — Sergio photographs the trastero and gets a micro-plan

1. From the Dispenser, one tap to Scan.
2. He frames the trastero and shoots.
3. On-device face detection runs first. Nobody is in frame, so it passes — had there been, the scan would have been refused **before upload**, on-device, with an offer to reframe.
4. The per-scan consent gate appears — as it does on **every** scan. Plain Spanish: the scan image and a prompt go to the named provider; nothing else does. Declining is the same number of taps as accepting.
5. He accepts. The wait happens in-app, with visible progress and honest copy, on a full-screen surface in the illustration register. Leaving the surface or backgrounding the app cancels the wait and discards it — nothing is queued (FR-16).
6. The Slicer returns Micro-tasks of 3–5 minutes with per-step effort. **The scan image is deleted from the device** now that the plan exists.
7. **Climax:** he is never shown the plan. He is shown **one card** — the first step of the trastero — and the trastero has stopped being a wall and become a thing with a first step. Nothing enumerated the rest, so there is nothing to dread.

*Edge case, named in the PRD — Slicer unreachable:* the calm no-Slicer surface appears with the provider-unreachable string and one exit, Manual Capture. It is not styled as an error, nothing is framed as his fault, no retry loop runs in front of him, and the Dispenser keeps dealing from the local pool. A declined consent lands on the same surface with its own string.

### UJ-3 — Sergio returns after six days away

1. He opens the app after six days of not opening it.
2. Cold start, ≤ 2 s, one card — exactly as on the day he left.
3. **Warm Return:** the plan has been rebalanced silently. The zone marker names today's zone. Invisible buffers absorbed the slip; slack is never shown, never configurable, never spendable.
4. **Climax:** there is nothing to catch up on, and — more precisely — **there is nothing that could have accumulated.** No backlog, no "6 días", no rebalanced-plan announcement, no apology, no reference to the missed days in any UI element or in any string. The six days are not representable in the schema, so they cannot reach the screen. He does one Micro-task and stops.

*Note:* the Warm Return copy is unauthored (Open Questions). Whatever is written may not name the absence it is responding to.

### UJ-4 — Sergio on a low-battery Sunday

1. Sunday evening, nothing in the tank. He opens the app.
2. The Dispenser is already dealing from a **wide** pool: energy defaults to llena, fixed, with no decay. The app never quietly narrowed his options while he was away from it.
3. The strip holds the Sunday self-report first. He answers it — a number, one tap. The energy check-in takes the slot, and he taps the battery's **baja**: he is asking for **less**, and the pool re-filters in under 500 ms. He asked; he was not made to ask.
4. He gets a 30-second Instant Habit. `Otra más fácil` would have taken him further down still, into Rescue Mode and the 30-Second Rescue.
5. A week with no answer would simply have no data point — the self-report is never notified (SM-2).
6. **Climax:** thirty seconds of work, one tap on `Hecho`, and the card leaves. The celebration is **identical** to the one he got after fifteen minutes on the trastero — it closes the loop and opens no door. No combo, no "you're on three", nothing suggesting a second. On the worst day of the week the app asked him for thirty seconds and then let him go.

*Failure path:* no network, no key configured. Nothing breaks — genesis degrades, execution does not. The pool is local, airplane mode is a supported condition rather than an error state, and no banner says otherwise.

### UJ-5 — Sergio anota algo a mano en diez segundos

1. Something occurs to him that the app cannot know and no photo can reveal: he promised to water the neighbour's plants. One tap from the Dispenser to Manual Capture.
2. He holds the microphone affordance and says it out loud — `regar las plantas de la vecina` — and the words land in the line, **in the existing one-line field on the existing surface**. No confirmation screen exists to receive them. Had he preferred typing, the keyboard is right there and always is (FR-32).
3. The surface is framed **spatially** — helper text, an example, the three durations — so non-spatial work is never invited. Dictation, which makes stray input cheaper than typing ever was, is exactly why that frame's ordering rule is load-bearing now rather than decorative.
4. There is no validation. Had recognition heard *la vitrina* instead of *la vecina*, he fixes it right there — the last moment it can be fixed — with the keyboard, which is never removed.
5. He picks `3 min` from exactly three options. The confirming action stays disabled until the line holds text.
6. **Climax:** ten seconds later he is back on the Dispenser looking at one card, and **the thing he just captured is nowhere to be seen.** No list appeared. No counter moved. No confirmation screen congratulated him. It will arrive as an ordinary dealt card, on a day when it fits — and until then it does not weigh anything.

*Failure path:* on-device recognition unavailable — no language pack, unsupported device, permission refused. The microphone is simply absent, nothing says so, and keyboard capture is unchanged. If no Slicer is reachable, it does not matter: this path never needed one.

## Open Questions

None of these is answered anywhere in the decision record; none should be filled in with a plausible value.

1. **Warm Return copy.** Unauthored. It must rebalance without naming what it is rebalancing.
2. **Anti-Marathon permission-to-rest copy**, and how the "extend the session" secondary action is *presented* without highlighting, animating or suggesting it.
3. **The `Hecho` confirmation copy.** "A warm confirmation" is specified; the words are not.
4. **Ambient Invitation copy** (PRD OQ-7): one fixed string, or a small rotating set to avoid the blindness that kills any repeated notification. `hay 15 minutos esperando cuando te apetezca` exists; whether it is *the* string or *a* string is undecided. Either shape must survive SM-C3.
5. **Whether the seasonal suggestion engine needs any configuration surface in v1** (PRD OQ-6), or pure defaults. Defaults-only is the standing answer until a suggestion actually misfires — which is a position, not a decision.
6. **The scan-wait experience.** There is **no latency cap**, and no affordance beyond "visible progress and honest copy". What progress means when the duration is unbounded is undecided.
7. **Empty states for the Transformation Album and the cumulative impact dashboard.** Unauthored, and constrained: they may not count or name what is absent.
8. **Screen-reader behaviour.** TalkBack labels, roles, state announcements and traversal order are never discussed anywhere in the record.
9. **Before/After diff presentation** beyond "side-by-side": layout, whether sharing exists at all, framing, and what the reward surface does when no Before photo was ever taken.
10. **Decluttering Protocol question presentation**, and how "answerable by skip" is surfaced without reading as an evasion.
11. **The departure trajectory of the completed card.** That it exits entirely and never flies toward a counter is settled; whether it departs along the global 45° offset axis, and whether **the departure itself is the celebration** (satisfying FR-2 with one gesture instead of two), is proposed and unconfirmed.
12. **The second locale.** FR-9 says no interrupted, incomplete or overdue state is displayed "in either language". The second language is never named, and its string lengths bear on the 200% fold. The flat i18n-ready string table (§7) already makes a second locale translation rather than redesign.
13. **Strings still drafted and never authorised.** The Manual Capture set is now authorised and lives in the fixed-string table (2026-08-27). What remains: `Enviar la foto` · `No enviarla` (consent gate, plus the gate's explanatory body) · `Empezar con esta` · `Volver` (genesis — **these predate the A-slim restructure and must be re-authored against the slimmed surface before use**) · `Guardar en el álbum` · `Cerrar` (Before/After) · `Quitar esta sugerencia` (snowball) · the one-time first-run curation offer on the strip (unwritten) · and the Before/After caption itself, which is bounded by the ceiling above but not written. The structural rule in Voice and Tone applies to all of them before anything is wired: every string externalised, nothing concatenated at runtime, the whole set auditable as one flat table.
14. **The "plates but not the meal" copy (PRD OQ-12).** Does any copy explain why the app knows about clearing the table and not the cooking that produced it, and where would it live? It is a copy decision on a surface this spine sites, and it has no answer. *(OQ-11's dates half, which this entry used to carry, closed upstream on 2026-08-27: the capture frame's copy says nothing about dates, because the surface does not lecture — FR-27.)*

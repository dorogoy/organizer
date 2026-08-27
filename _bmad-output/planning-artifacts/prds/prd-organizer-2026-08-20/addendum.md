# Addendum — Anti-Overwhelm Mobile Task Organizer PRD

Depth that belongs downstream (architecture, UX, strategy) or earned a place outside the PRD narrative. Audit/decision trail lives in `.memlog.md`, not here.

## A1. Competitive Landscape Digest (research, 2026-08-20)

Comparables:
- **Sweepy** (sweepy.com) — gamified family cleaning; room scores + auto daily plan; has a "how much time today" budget. Closest mechanic overlap on time budgeting.
- **Tody** (todyapp.com) — "make peace with your cleaning routine"; dirt-score priority replaces due dates. Closest philosophy on no-overdue.
- **FlyLadyPlus** (flylady.net) — official FlyLady app; zones, missions, 15-min timer. No weaving, no single-task UI.
- **Nipto** (nipto.co) — couples/roommate chore competition. Punitive-by-omission contrast. Unverified: the research search timed out and the claim was never confirmed.
- **Finch** (finchcare.com) — self-care pet; reward-only mechanics, no punishment. Anti-shaming precedent.
- **Tiimo** (tiimoapp.com) — visual planner for ADHD/autism; calm positioning, but timeline-based.
- **Habitica** — RPG with HP damage on missed dailies: the anti-reference.
- **One Thing** (App Store) — anti-todo, one visible task, no backlog — but not wired to any chore engine.
- **1-3-5 apps** (Todo List 135, Rocket 135) — rule planners, manual selection.
- **SnapNClean** (snapnclean.com) — photo → cleaning checklist (no effort estimation, no reward loop).
- **Clean My Room AI** — photo → clean-room visualization only.
- Traditional managers (Todoist/OmniFocus/Things) — overdue counters, badge pressure: the contrast frame.

Differentiator status:
- FlyLady + 1-3-5 **hybrid auto-weaving engine**: novel combination.
- Photo → micro-steps + **before/after reward loop**: novel in combination.
- **Invisible buffers + explicit no-overdue/no-red philosophy**: rare (Tody adjacent).
- **Quarantine-box decluttering protocol**: no comparable found.
- "I have X minutes now" trigger: partial precedent (Home Tasker).

Market caution: ChoreMonster (dead ~2018), OurHome (discontinued) — kid-chore gamification proved fragile; punishment-adjacent mechanics correlate with abandonment. Supports the anti-shaming bet.

## A2. Technology Options for the Smart Slicer (→ bmad-architecture decides)

Open question OQ-1 (OQ-10 closed 2026-08-26 at `bmad-architecture`). Updated 2026-08-21 for the three-path access model (FR-28).

**Cloud candidates (BYOK, shipped in v1).** Multimodal vision LLM APIs with written no-training terms: OpenAI GPT vision class, Google Gemini vision class, Anthropic Claude vision class — all three verified 2026-08-26 and all three shipped in the initial allowlist (OQ-10, closed). Evaluation order matters — no-training terms come first because they are the allowlist gate (FR-28), not a tiebreaker; then Spanish output quality; then structured-output reliability for micro-step JSON. Two criteria have since been dropped rather than reordered: latency (OQ1 demoted it, and the stale 30 s budget is gone from §7) and **cost** — a room photo prices at roughly 0.003–0.006 USD per scan across the candidates, so A8's target is met by all of them with room to spare and the figure discriminates nothing. Retention is likewise not a criterion (FR-28).

**On-device candidate (Local, the preferred ideal).** Gemma 4, released 2026-04-02, in E2B / E4B / 26B-MoE / 31B-dense variants. E4B is the phone-class target: native multimodal input (image with variable aspect ratio and resolution, plus video and audio), an encoder-free architecture projecting raw image patches directly into the embedding space, 256K context, and official Android support. The 12B is laptop-class and irrelevant to a handset. The only open question is slicing quality on real clutter photos — a bounded test on the validation phone, not a research programme.

**The fallback path is no longer a template — but the Evergreen day is not a fallback.** FR-29 makes the no-Slicer state explicit and routes anything personal to Manual Capture (FR-27). Separately, the whole Evergreen Library ships pre-sliced as product content (FR-11, FR-31, catalogue in A12), so a keyless offline install still has a varied month of 1-3-5 days. The distinction that matters downstream: Evergreen is universal and can be authored once at build time; Epic is personal and only the Slicer authors it.

## A3. Decision Rationale — AI included in the validation build

Tradeoff accepted (2026-08-20): Photo-Diagnosis is the differentiating hook; validating the core loop without it would not test the actual concept. Cost contained by: single-device Android, cloud API with per-scan cap, template fallback. Rejected alternative: photo before/after only, manual slicing — cheaper but leaves the novel loop unvalidated.

## A4. Decision Rationale — Platform and language

Android-only, single device (the builder's daily phone): validation does not need cross-platform reach; hybrid-vs-native framework choice deferred to architecture (constraint: camera, haptics, background scheduling, local-first storage, i18n-ready strings).

## A5. Mechanism Notes for Downstream Design

- The 1-3-5 composition is a daily *regenerable* set, not a checklist: re-weaving (not "failing the day") is the invariant the scheduler state machine must hold.
- "No overdue concept" (FR-14) should be pushed as deep into the data model as possible — overdue-shaped data breeds overdue-shaped UI.
- Anti-Marathon Cap interacts with Time Bag: cap is per-session, bag is per-day; multiple pockets per day are legitimate and celebrated (leisure respect cuts both ways).
- Energy check-in should be ambient and optional — decided at `bmad-ux` (2026-08-27; carried in FR-4): default 🟢, fixed, no decay, offered once per day at the first opening and skippable. Late-day decay toward 🟡 was floated in brainstorming and rejected: it would shrink the pool precisely during the app's real usage window (evenings) and would turn an ambient, optional check-in into a necessary correction.

## A6. Mechanism Notes — Ambient Invitation (FR-24)

Added 2026-08-20 when the zero-notification stance was traded for one opt-in silent invitation.

- **Channel design is the enforcement point.** On Android, a low-importance notification channel (`IMPORTANCE_LOW`) gives silence and no heads-up by construction, and the user can tighten it further in system settings but the app can never widen it back — the channel importance is fixed at creation. That property is what makes "incapable of escalating" real rather than aspirational. Do not create a second channel.
- **No badge, no count.** Suppress the launcher badge explicitly (`setShowBadge(false)`); a badge is a counter, and a counter is a debt display.
- **Scheduling tradeoff (OQ-8, closed 2026-08-26).** `setInexactRepeating` / WorkManager survives Doze cheaply but may drift by up to an hour; exact alarms need `SCHEDULE_EXACT_ALARM` and read as urgent-app behavior to the OS. Ruled at `bmad-architecture`: inexact — `USE_EXACT_ALARM` is Play-restricted to apps whose core function is precise timing, which this app is the negation of, and FR-24's copy carries no clock to be wrong about. The prior recommendation to evaluate was adopted.
- **Statelessness is a requirement, not an optimization.** The invitation must be composed from nothing but the configured hour and the Time Bag value — no read of plan state, completion history, or last-open time. If it cannot see whether Sergio has been away, it cannot acquire pressure later, no matter who edits the copy.
- **Rejected alternative:** home-screen widget instead of a notification. Cheaper philosophically (fully passive, no permission), but widgets are out of scope (§5.1) and a widget requires an intentional glance at the home screen — the memory problem SM-1 faces is precisely that the app leaves attention entirely. Revisit post-validation as a possible replacement for FR-24.

## A7. Decision Rationale — Photo privacy stance (FR-25)

Decided 2026-08-20. The intent document's platform rationale claimed on-device image processing as a privacy property; this build reverses that.

- **Why reversed:** on-device vision models available at validation time were judged unlikely to produce a micro-step sequence good enough to test the hook. Validating the differentiator with a degraded slicer would answer the wrong question.
- **Price paid explicitly:** per-scan consent with no blanket opt-in, on-device person/face detection as a hard pre-upload gate, scan images deleted after plan generation, upload payload limited to image + prompt.
- **Rejected alternative:** blanket consent at onboarding. Cheaper in taps, but it converts a series of deliberate decisions into one forgotten decision — and the photos are of the inside of a home.
- **Downstream note:** the person/face gate needs an on-device detector (ML Kit face detection class is sufficient — it need not identify anyone, only detect presence). This is a real dependency, not a nice-to-have, because it is the only check that runs before the network call.
- **Deferred:** whether provider choice (OQ-1) should be constrained to EU processing regions. Raised in A2; still open.
- **Partial re-reversal, 2026-08-21.** The judgement above — that on-device vision models available at validation time were unlikely to produce a good enough micro-step sequence — was formed before Gemma 4 shipped on 2026-04-02 with phone-class multimodal variants and official Android support. The judgement is not overturned: nobody has yet fed E4B a photo of the trastero. But its premise expired, and it may no longer be cited as settled. Test before restating it (OQ-1, A2).
- **The privacy price is now path-dependent.** On the Local path every cost enumerated above becomes unnecessary rather than merely paid: no upload, no consent dialog, no deletion policy, no provider terms. On BYOK the costs stand, with one improvement the original cloud reversal did not offer — the destination is the user's own provider account and the developers hold nothing at all (§7).

## A8. Cost target for OQ-1 (Smart Slicer economics)

FR-16 assumes a per-scan budget that the PRD deliberately does not name. The figure to test candidates against, for a validation build used by one person: a scan should cost little enough that Sergio never hesitates before shooting one — at roughly 1–2 scans per week over the 4-week window, total spend should stay in the "a coffee" range, not the "watch the meter" range. Any candidate whose pricing makes per-scan hesitation rational fails the requirement regardless of output quality, because hesitation kills the loop the build exists to validate. Concrete numbers belong to `bmad-architecture` once candidates are priced.

**Updated 2026-08-21.** BYOK (FR-28) changes who feels the cost, not the requirement. Sergio now pays his provider directly, so per-scan hesitation is literal rather than notional — which strengthens the requirement rather than relaxing it: the figure that matters is still whether he hesitates before shooting a photo. The Local path collapses the cost to zero, and that is a large part of why it stays the preferred ideal (OQ-1). Per-candidate pricing still belongs to `bmad-architecture` at allowlist selection (OQ-10).

## A9. Decision Rationale — separating task genesis from AI access (2026-08-21)

The PRD had collapsed two independent questions into one sentence, and the collapse produced a false requirement.

- **What was wrong.** The document claimed the app worked without AI — FR-11's zero-typing fresh install, FR-16's and FR-25's template fallbacks, §7's "functions fully without it except AI features" — while the Slicer was the only thing that created tasks. On a fresh install with no Slicer there was nothing to dispense, so every fallback fell back onto nothing. Following the thread honestly forced login/password to app entry, because the first use of a task-less app is necessarily an AI use.
- **What fixed it.** Manual Capture (FR-27) as a permanent floor. It removes the forcing entirely: the app is usable at second zero with no key, no network and no account, so the login requirement the contradiction had just manufactured disappeared instead of being implemented.
- **The two axes.** Genesis (manual / on-device Slicer / cloud Slicer) and access (Local / BYOK / Managed) are orthogonal. Treating them as one axis is what let "the AI is behind a paywall" silently mean "the app is behind a paywall".
- **Why BYOK for v1.** It is the only path with nothing to build and nothing to hold: no proxy (OQ-9 dissolved), no account, no login, no billing, no developer-held data, no first-run network requirement. §7's "no developer-held data of any kind" becomes true without an asterisk for the first time.
- **Rejected: withholding Manual Capture to protect SM-4.** A manual entrance risks cannibalising the photo loop the build exists to validate. Rejected because the remedy is measurement, not deprivation — FR-26 now tags task origin and SM-4 reads against it. Shipping an app that is useless offline on day one, in order to keep a metric clean, inverts the priority.
- **Rejected: a free-form provider endpoint for BYOK.** Maximum flexibility, but it makes FR-25's no-training gate unenforceable: the user could point the app anywhere, and a privacy guarantee that depends on the user reading terms is not a guarantee. An allowlist costs one dropdown.
- **Refined the same day, by a second-order pass.** The first formulation demoted *all* templates to Slicer seeds — which made the first thing a new user does cost money and require the network, immediately after §7 had celebrated that the app needs neither. Corrected by splitting on lifecycle rather than mechanism: Evergreen ships pre-sliced because FlyLady is published and identical for everyone; Epic is never templated because it is personal. The Slicer's job is not "all tasks" but "everything personal", which is the sharper and more defensible claim — and it restores a working offline day-one product.
- **Corrected: BYOK does not force a shared key in the annex.** The first reading of §8 assumed the secondary observers would either buy their own API access or share the builder's key. Providers with per-key cost attribution allow one account to issue a distinct key per person, so each instance stays separately attributable at no cost to the observer. The residual risk moved to OQ-10: an aggregator makes FR-28's terms gate a configuration rather than a property.
- **Rejected: shipping all three access paths in the validation build.** Three paths for one user triples the surface that has to work for a window that only has to answer one question. The interface ships; two implementations do not.
- **Rejected: leaving three findings as downstream advice (2026-08-21, Sergio's call).** All three were promoted to binding requirements instead — see A10.
- **Rejected: a monthly subscription for the Managed path (2026-08-21, Sergio's call).** The reasoning is a coherence argument rather than a pricing one. A recurring fee bills for the months the user does not open the app — it monetizes the absence FR-6 and UJ-3 exist to forgive — and a business that earns from silence acquires an interest in breaking it, which is institutional pressure toward exactly the notification behaviour §5.2 forbids. Credits align revenue with use, and use with the user's own free will. A secondary benefit lands squarely on §7: credits need *less* developer-held data than a subscription — no payment method on file, no renewal state, no dunning, no cancellation flow. Three constraints follow and are recorded in §5.1: credits never expire, the balance never appears outside settings, and BYOK stays available forever so credits are never lock-in. The cost of the choice is stated rather than hidden: credits keep the meter visible, and §10.2 already records that a visible meter biases SM-4 — which is why the balance is confined to settings and no per-scan price is ever shown. A flat fee would have hidden the meter better and broken the philosophy instead; that trade was refused.

## A10. Decision Rationale — three promotions from advice to requirement (2026-08-21)

A second-order pass produced three findings that were first routed downstream as notes. Sergio promoted all three, on the grounds that advice in a memlog does not survive contact with an implementer.

- **FR-28's Local stub.** FR-28 claims that adding a path "changes no call site outside the access layer". With one implementation, nothing tests that claim, and an untested abstraction is usually wrong. A debug-only stub returning a canned slice gives the interface two real callers for almost nothing. It is also a free head start on the path OQ-1 may well select.
- **FR-29's seven strings, authored first.** These are the highest shaming-risk sentences in a product whose entire thesis is anti-shaming, and they are structurally the last strings anyone writes — the error branch, in a hurry, at the end. Making them a completion condition of FR-29 rather than a UX wish is the only mechanism that reliably beats that ordering. They enter the SM-C2 audit table with everything else.
- **FR-30's silent automatic export.** Manual-only export + no backup reminders (correct for the user) + a 4-week window = a real chance the validation data dies with a dropped phone in week 3. The two requirements are only compatible if the export happens by itself. Two constraints kept it from breaking anything: it runs in the *foreground* at natural moments, so §7's background minimalism holds unchanged; and the app writes a local file rather than transmitting, so the egress map is untouched and any cloud sync is the user's own client's doing.
- **What the third promotion also produced.** Resolving where export state may be shown surfaced a principle that had been implicit in three separate decisions: **settings is where the validator reads, the Dispenser is where the user lives.** The raw FR-26 series, FR-30's export state and the Managed path's credit balance all belong there and nowhere else. It is what makes one person holding both roles survivable inside one app, and it is now written into §7.

## A11. Decision Rationale — the Evergreen Library, and the two rulings that paid for it (2026-08-23)

Sergio asked that the PRD record the need for predefined tasks, varied across cadences: everyday basics (lavar los platos, cocinar, poner la mesa) and weekly work (pasar la aspiradora, limpiar ventanas). The concept already existed — Archetype Templates, Evergreen pre-sliced since the 2026-08-21 lifecycle split — but it was far narrower than the ask, and reconciling the two forced two product decisions.

- **What was actually missing.** The shipped Evergreen material amounted to five FlyLady zone templates plus five ~30-second daily anchors. That fills the "5" of the 1-3-5 and, thinly, the "1". Nothing filled the "3", and nothing covered the third cadence a home actually has — the monthly and seasonal work that "limpiar ventanas" belongs to. FR-11 promised a working 1-3-5 day on a keyless offline install; the content behind that promise could not deliver a varied month. FR-31 and A12 are that content, with a coverage floor attached so it stays checkable.

- **Daily Evergreen could no longer mean 30 seconds.** Poner la mesa is ~3 min (Micro-maintenance) and lavar los platos ~10 min (Focus Chunk). The request therefore required daily Evergreen material at all three sizes, not only at the anchor size — which is why **Baseline Upkeep** is a named glossary term rather than "more anchors". The distinction is by size, not by kind.

- **Rejected: cooking, and clock-bound work generally.** Cooking has an hour. The Floating Time Bag exists so that nothing in this product has a time of day (§1.1 principle 3), and calendar access is excluded by philosophy rather than by phasing (§5.2). A Dispenser that deals "cocinar" at five in the afternoon is not a nag, it is simply broken — and the alternative, teaching the app mealtimes, rebuilds the calendar inside the catalogue. The upkeep that hangs off a meal ships instead: clearing the table, the dishwasher, closing the kitchen. Those follow a moment the user recognises rather than a clock the app must track. The cost is stated rather than hidden: the app knows about the plates and not the meal, which may read as arbitrary from inside the kitchen, and OQ-12 now owns the copy problem that creates.

- **Rejected: charging Baseline Upkeep to the Time Bag.** Honest on its face, and fatal in arithmetic. At the 15-minute default, dishes (10) plus setting the table (3) consume the day before any Epic Project is touched — and SM-3, the metric that validates the whole Weaver, requires visible Epic progress. Charging unavoidable work to a budget meant for getting ahead guarantees the build never validates the thing it exists to validate. So the Time Bag now budgets **advance** work only, and upkeep sits outside it. Also rejected, as a middle path: letting the user mark per-task which obligations count against the budget. Maximum fidelity to any given home, and one more onboarding decision in a product whose first principle is that the user never chooses from a list.

- **What that split had to keep intact.** An unbudgeted class of tasks is an anti-marathon hole if nothing else bounds it. Nothing else needed inventing: FR-8 already bounds a session by the *declared pocket*, which is a different quantity from the daily budget. The pocket bounds the sitting; the Time Bag budgets the advance. Anti-marathon lives on the first, so it survives the change untouched.

- **A pre-existing contradiction the split resolves rather than adds to.** FR-12's canonical 1-3-5 sums to roughly 26 minutes (15 + 9 + 2.5) against FR-7's 15-minute default Time Bag. "Scaled to the current Time Bag" had been carrying that inconsistency silently since the first draft. With the Focus Chunk as the only budgeted element, 15 against 15 is exact, and scaling now has a defined meaning: drop upkeep and habits by count, never shrink a Micro-task's own estimate.

- **Rejected: shipping the catalogue as a browsable, editable list.** The natural way to let a user tailor 85 tasks to their own home is to show them 85 tasks. That is the endless list §1 exists to abolish, walking in through the template door rather than the GTD one. Curation is therefore at cluster level — zones and upkeep groups — in onboarding and settings only, never from the Dispenser (§7). Per-task opt-out was refused for the same reason, and the price is accepted in §10.2: a cluster that half applies is enabled whole or disabled whole.

- **Rejected: letting the user add to the catalogue.** A "create your own template" affordance is a task manager with a longer setup. Manual Capture (FR-27) is the only user-authored entrance and stays deliberately poor. The library is a data file fixed at build time, which is also what makes FR-31's coverage floor verifiable without running the app.

## A12. The Evergreen Library — shipped catalogue (FR-31)

Product content, authored 2026-08-23, closing OQ-3. Task names are shipped Spanish UI copy and go into the string table on the same terms as everything else (§7). Sizes are the 1-3-5 taxonomy exactly: **30 s** = Instant Habit, **3 min** = Micro-maintenance, **10–15 min** = Focus Chunk. Nothing here carries an hour, a mealtime, or a dependency on another task.

Counts against FR-31's coverage floor: **34 daily**, **36 weekly** across five zones, **15 monthly/seasonal**. The floor counts eligible units only (corrected 2026-08-26): distinct 10–15 min non-daily entries — 20 weekly (5/3/4/5/3 per zone) plus 12 monthly/seasonal in `fondo` = 32 against a floor of 28, so 28 dealt Focus Chunks never repeat even with no Epic Project active. A thin zone week (baño, entrada) draws from `fondo` before repeating anything; the earlier ≥45 non-daily count included 3-minute entries that can never occupy the slot and verified nothing.

### A12.1 Daily — Instant Habits (30 s), cluster `anclas`

| Task | Notes |
|---|---|
| Sacar brillo al fregadero | The FlyLady keystone anchor |
| Hacer la cama | |
| Abrir una ventana a ventilar | |
| Recoger 3 cosas del suelo | Also FR-5's canonical 30-Second Rescue |
| Colgar la toalla | |
| Repasar el espejo del baño con la toalla usada | |
| Meter en el lavavajillas lo que hay en el fregadero | |
| Arrancar una lavadora | Starting it only; the load is separate |
| Sacar la basura al rellano | |
| Guardar los zapatos de la entrada | |
| Regar una planta | Cluster `plantas` |
| Despejar la mesita de noche | |
| Bajar la tapa y repasar el borde del inodoro | |
| Vaciar la papelera del baño | |

### A12.2 Daily — Baseline Upkeep (3 min), cluster `sostén`

| Task | Notes |
|---|---|
| Poner la mesa | |
| Recoger la mesa | Post-meal, no hour attached |
| Vaciar el lavavajillas | |
| Repasar la encimera | |
| Limpiar la placa | Post-meal |
| Barrer bajo la mesa del comedor | |
| Pasar la mopa por la cocina | |
| Repasar el lavabo y los grifos | |
| Doblar cinco prendas | Deliberately bounded — not "fold the laundry" |
| Guardar la compra que quedó fuera | |
| Ordenar los cojines y la manta del sofá | |
| Vaciar y aclarar el cubo de reciclaje | |
| Recoger la mesa de centro | |
| Sacar la basura orgánica | |

### A12.3 Daily — Baseline Upkeep (10–15 min), cluster `sostén`

| Task | Notes |
|---|---|
| Lavar los platos a mano | |
| Dejar la cocina cerrada | Encimera, fregadero y suelo — the end-of-day one |
| Tender la colada | |
| Doblar y guardar una colada | |
| Recoger el salón entero | |
| Ordenar la entrada y el recibidor | |

### A12.4 Weekly — zone routines

Five FlyLady zones, exactly one active per day, rotating weekly (§3, FR-11).

**Z1 · Cocina y despensa** — 8 entries

| Task | Size |
|---|---|
| Pasar la aspiradora a la cocina | 10–15 min |
| Fregar el suelo de la cocina | 10–15 min |
| Desengrasar la campana extractora | 10–15 min |
| Vaciar una balda del frigorífico y tirar lo caducado | 10–15 min |
| Repasar los azulejos detrás de la placa | 10–15 min |
| Limpiar el microondas por dentro | 3 min |
| Limpiar el frigorífico por fuera y los tiradores | 3 min |
| Ordenar el cajón de los cubiertos | 3 min |

**Z2 · Baños** — 7 entries

| Task | Size |
|---|---|
| Limpiar la ducha o la bañera | 10–15 min |
| Fregar el suelo del baño | 10–15 min |
| Ordenar el armario del baño y tirar lo caducado | 10–15 min |
| Limpiar el inodoro | 3 min |
| Limpiar el espejo y los grifos | 3 min |
| Cambiar las toallas | 3 min |
| Destapar el desagüe de la ducha | 3 min |

**Z3 · Dormitorios** — 7 entries

| Task | Size |
|---|---|
| Cambiar las sábanas | 10–15 min |
| Pasar la aspiradora al dormitorio | 10–15 min |
| Aspirar debajo de la cama | 10–15 min |
| Vaciar y airear una balda del armario | 10–15 min |
| Quitar el polvo de las superficies | 3 min |
| Ordenar la mesilla y los cables | 3 min |
| Limpiar los espejos del armario | 3 min |

**Z4 · Salón y zonas comunes** — 7 entries

| Task | Size |
|---|---|
| Pasar la aspiradora al salón | 10–15 min |
| Fregar el suelo del salón | 10–15 min |
| Quitar el polvo de las estanterías | 10–15 min |
| Aspirar el sofá y los cojines | 10–15 min |
| Ordenar el mueble de cables y cargadores | 10–15 min |
| Limpiar la mesa de centro y los mandos | 3 min |
| Limpiar la pantalla del televisor | 3 min |

**Z5 · Entrada, lavadero y exteriores** — 7 entries

| Task | Size |
|---|---|
| Barrer y fregar la entrada | 10–15 min |
| Ordenar los zapatos del recibidor | 10–15 min |
| Barrer el balcón o la terraza | 10–15 min |
| Limpiar el filtro de la lavadora | 3 min |
| Limpiar el cubo de la basura por dentro | 3 min |
| Revisar y regar las plantas | 3 min |
| Repasar el espejo y la consola de la entrada | 3 min |

### A12.5 Monthly and seasonal — cluster `fondo`

15 entries. These are the cadence the previous template set had no representation for at all.

| Task | Size |
|---|---|
| Limpiar los cristales de una habitación | 10–15 min |
| Limpiar las mosquiteras y los rieles de las ventanas | 10–15 min |
| Limpiar el horno | 10–15 min |
| Revisar y organizar el congelador | 10–15 min |
| Descalcificar los grifos | 10–15 min |
| Repasar las juntas de la ducha | 10–15 min |
| Limpiar los rodapiés de una habitación | 10–15 min |
| Limpiar las puertas y los marcos | 10–15 min |
| Limpiar las lámparas y las pantallas | 10–15 min |
| Aspirar detrás de un mueble grande | 10–15 min |
| Revisar el botiquín y tirar lo caducado | 10–15 min |
| Limpiar el interior del coche | 10–15 min (cluster `coche`) |
| Limpiar el filtro del aire acondicionado | 3 min |
| Limpiar el filtro del lavavajillas | 3 min |
| Poner a lavar las fundas de los cojines | 3 min |

### A12.6 Deliberately absent

Named so nobody adds them back by accident.

- **Cocinar**, and any other task with an hour attached (§5.2, FR-31, A11).
- **Cambio de armario de temporada** and **ordenar el trastero** — these are Epic Projects, personal to a home, and only the Slicer authors them (§1.1 principle 6, FR-11). A catalogue entry for either would be exactly the template-standing-in-for-the-Slicer fiction FR-29 removed.
- **Non-spatial errands** (llamar al dentista, entregar el formulario) — the catalogue is spatial throughout, and whether such work belongs in the product at all was OQ-11 — closed 2026-08-27: the app neither invites nor refuses it (spatial framing, no validation, silent acceptance; FR-27). The catalogue itself stays spatial.

## A13. Decision Rationale — voice as an input method, not as a path (2026-08-26)

**The signal.** Typing on a touch-screen keyboard is genuinely hard for a lot of people, so voice must be one of the ways information enters the app. The observation is correct and the PRD had already half-conceded it: §2.1's "without typing or categorizing" was true only of the photo path, and Manual Capture — the one surface that asks for writing — asked for it through the worst input device on the phone.

**What made this a decision rather than a feature.** Four things in the document pointed different ways, and "add voice" would have quietly broken three of them.

- §5.1 already deferred a **voice-first natural-language slicer** to Phase 3. Shipping "voice" without saying which voice would leave a later reader unable to tell whether that bullet had been delivered.
- §4.9 describes Manual Capture as a floor whose comfort was removed **on purpose**, and §2.2 uses that discomfort to keep GTD power users out of the product. Voice is a comfort affordance. If it makes the floor pleasant to live in, the non-user boundary moves without anyone having chosen to move it.
- §7's egress map and FR-27's "no network, no key, no model, no account" are the strongest promises in the build. Cloud speech recognition would add a destination to the map and put a network dependency inside the one feature that exists to need nothing.
- FR-27 says a captured line is unrecoverable once the user leaves the surface, and §5.2 forbids the list that would let them find it again. That rule was written for a human typing what they read.

**The four rulings.**

1. **Dictation, not genesis.** Voice fills the existing one line and nothing is parsed out of it — not the size, not a second task, not a date. The boundary is the one §1.1 principle 6 already draws: dictation transcribes, a Slicer authors. §5.1's bullet now states which side of the line it owns, so the Phase 3 item survives intact instead of being half-consumed.
2. **On-device only, with no fallback.** This is what keeps FR-27's floor and §7's egress map literally true rather than newly qualified. The absence of a fallback is the load-bearing half: a cloud fallback is precisely how a new egress destination arrives in a build without anyone deciding to add one, and the person who wires it will be fixing a bug on an unsupported device, not making a privacy decision.
3. **The transcript is visible and editable before the user leaves.** Machine-written text plus an unrecoverable pool plus no list is a defect, not a trade-off: a mis-heard word becomes an undeletable garbage card. The transcript lands in the field the correct-or-discard affordance already governs, so §4.9 keeps its "no confirmation screen" property and gains no surface.
4. **The keyboard stays, forever.** Correcting a transcript requires it, and a voice-only capture surface fails the first time recognition mis-hears a household word.

**Rejected alternatives.**

- **Cloud STT, or on-device with a cloud fallback.** Rejected on §7 rather than on cost. It buys universal availability with the property that makes the whole data stance credible, and it buys it in the one feature whose entire purpose is to need nothing.
- **Voice through the BYOK provider.** Rejected because it ties Manual Capture to a configured key — exactly the dependency FR-27 exists to eliminate. UJ-5's closing line ("on the day his API key expires, this is the only path still working") would have become false.
- **Bringing the Phase 3 voice-first slicer forward.** Rejected as scope, not as an idea. Free speech → several sized micro-tasks needs a text slicer, network, key and a review surface for a multi-task result — and a review surface for several tasks is a list, which §5.2 abolishes. It is a genuinely different product decision and it deserves its own pass.
- **A tablet form factor and a tablet user segment.** The signal mentioned tablets; §5.1's "Android only" already covers Android tablets, but §2's three named users, §7's one-handed rule and the pocket-sized framing of every UJ do not. Treating "people who use tablets" as a new segment would have widened the validation build's audience on the strength of one sentence. Ruled: the input problem is real and general to touch keyboards, and it is absorbed by §7's Accessibility floor rather than by a new persona. The tablet segment, if it is one, is a post-validation question.
- **Voice commands for the Dispenser** (saying "hecho", "otra más fácil"). Rejected on §1.1 principle 1 and on honesty: the Dispenser has two buttons and one card, so voice would add a modality to the one surface that is already effortless while doing nothing for the one that is not.
- **Spoken sizes** ("tres minutos"). Rejected because parsing a duration out of speech is the first step of the deferred slicer, and because the three sizes are three taps — the cheapest interaction in the app. There is nothing to save.

**Deliberately left open, then closed.** What the app does when on-device Spanish recognition is missing was OQ-13 — closed 2026-08-27: absent-and-silent is the decision, no language-pack pointer anywhere. The standing answer followed from §1.1 principle 2 — a greyed-out microphone is pending work in the Dispenser's own house; the counter-argument, that a user who never sees the affordance concludes the product has no voice, was weighed and overruled. A refused *permission* differs from *unavailability*: it carries a settings reactivation row, unified with the camera's pattern (FR-16, FR-32).

**What the window should watch.** FR-32 records a local dictation boolean on each capture, settings-visible only. Read against SM-4's origin mix it answers two separate questions: whether voice was used at all, and whether cheap capture turned the floor into the road (§10.2). The second is the one that would matter, because its only obvious remedy is a list.

## A14. Credential-at-rest reconciliation (2026-08-27)

FR-28's original shorthand said that the provider API key itself was held in the OS keystore. AndroidKeyStore stores cryptographic keys; it does not store an arbitrary provider credential string directly, so that wording admitted incompatible or impossible implementations.

The architecture closes the mechanism without weakening the product requirement: AndroidKeyStore generates and retains a non-exportable AEAD wrapping key; the provider credential is stored only as a provider-scoped encrypted envelope in app-private files storage, never preferences. Provider selection is replayable and may be restored. Credential availability belongs to the current installation, is determined by successful live decryption, and is never logged or exported. Each BYOK request decrypts the credential only for the duration of that request; plaintext never crosses the functional core and is never cached.

This is a clarification of “protected by the OS keystore,” not a new egress or persistence destination. The authoritative mechanism is [architecture AD-22](../../architecture/architecture-organizer-2026-08-26/ARCHITECTURE-SPINE.md#AD-22--No-secret-is-ever-an-entry-a-pool-fact-or-in-either-half-of-the-export).

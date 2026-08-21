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

Open questions OQ-1 and OQ-10. Updated 2026-08-21 for the three-path access model (FR-28).

**Cloud candidates (BYOK, shipped in v1).** Multimodal vision LLM APIs with written no-training / no-retention terms: OpenAI GPT vision class, Google Gemini vision class, Anthropic Claude vision class. Evaluation order matters — data-processing terms come first because they are the allowlist gate (FR-28), not a tiebreaker; then Spanish output quality; then structured-output reliability for micro-step JSON; then cost per scan against A8. Latency is no longer a criterion: OQ1 demoted it and the stale 30 s budget has been removed from §7.

**On-device candidate (Local, the preferred ideal).** Gemma 4, released 2026-04-02, in E2B / E4B / 26B-MoE / 31B-dense variants. E4B is the phone-class target: native multimodal input (image with variable aspect ratio and resolution, plus video and audio), an encoder-free architecture projecting raw image patches directly into the embedding space, 256K context, and official Android support. The 12B is laptop-class and irrelevant to a handset. The only open question is slicing quality on real clutter photos — a bounded test on the validation phone, not a research programme.

**The fallback path is no longer a template — but the Evergreen day is not a fallback.** FR-29 makes the no-Slicer state explicit and routes anything personal to Manual Capture (FR-27). Separately, Evergreen templates ship pre-sliced as product content (FR-11), so a keyless offline install still has a 1-3-5 day. The distinction that matters downstream: Evergreen is universal and can be authored once at build time; Epic is personal and only the Slicer authors it.

## A3. Decision Rationale — AI included in the validation build

Tradeoff accepted (2026-08-20): Photo-Diagnosis is the differentiating hook; validating the core loop without it would not test the actual concept. Cost contained by: single-device Android, cloud API with per-scan cap, template fallback. Rejected alternative: photo before/after only, manual slicing — cheaper but leaves the novel loop unvalidated.

## A4. Decision Rationale — Platform and language

Android-only, single device (the builder's daily phone): validation does not need cross-platform reach; hybrid-vs-native framework choice deferred to architecture (constraint: camera, haptics, background scheduling, local-first storage, i18n-ready strings).

## A5. Mechanism Notes for Downstream Design

- The 1-3-5 composition is a daily *regenerable* set, not a checklist: re-weaving (not "failing the day") is the invariant the scheduler state machine must hold.
- "No overdue concept" (FR-14) should be pushed as deep into the data model as possible — overdue-shaped data breeds overdue-shaped UI.
- Anti-Marathon Cap interacts with Time Bag: cap is per-session, bag is per-day; multiple pockets per day are legitimate and celebrated (leisure respect cuts both ways).
- Energy check-in should be ambient and optional: a default of 🟢 with gentle decay toward 🟡 late in the day was floated in brainstorming but left undecided — UX decision.

## A6. Mechanism Notes — Ambient Invitation (FR-24)

Added 2026-08-20 when the zero-notification stance was traded for one opt-in silent invitation.

- **Channel design is the enforcement point.** On Android, a low-importance notification channel (`IMPORTANCE_LOW`) gives silence and no heads-up by construction, and the user can tighten it further in system settings but the app can never widen it back — the channel importance is fixed at creation. That property is what makes "incapable of escalating" real rather than aspirational. Do not create a second channel.
- **No badge, no count.** Suppress the launcher badge explicitly (`setShowBadge(false)`); a badge is a counter, and a counter is a debt display.
- **Scheduling tradeoff (OQ-8).** `setInexactRepeating` / WorkManager survives Doze cheaply but may drift by up to an hour; exact alarms need `SCHEDULE_EXACT_ALARM` and read as urgent-app behavior to the OS. Recommendation to evaluate: inexact is philosophically consistent (an invitation that arrives whenever is still an invitation) and avoids a permission that only nagging apps need.
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
- **Rejected: a free-form provider endpoint for BYOK.** Maximum flexibility, but it makes FR-25's no-training / no-retention gate unenforceable: the user could point the app anywhere, and a privacy guarantee that depends on the user reading terms is not a guarantee. An allowlist costs one dropdown.
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

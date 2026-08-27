---
lens: adversarial
method: construct two units, one level down, each letter-compliant with every AD, that still build incompatibly
reviewer: independent adversarial subagent (no prior context)
date: '2026-08-27'
target: ARCHITECTURE-SPINE.md (architecture-organizer-2026-08-26), status final, updated 2026-08-26
inputs: ARCHITECTURE-SPINE.md; prd-organizer-2026-08-20/prd.md
verdict: FAIL
severity-tally: { critical: 1, high: 4, medium: 4 }
---

# Adversarial review — two compliant builds that diverge

Every finding below exhibits **two implementation units that each obey the letter of the ADs they cite** and still produce incompatible products: clashing attributions of one entity, conflicting mutation paths, or divergent shared-data derivations. Findings where one unit would have to break an AD were rejected (see "Worked and cleared"). Severity follows the configured floor: **critical** = one compliant build ships a broken guarantee; **high** = divergent builds; **medium** = rework.

The previous review pass tightened individual ADs; nearly every hole below is a seam **between two tightened ADs** — the fixes opened them.

---

## ADV-1 — Who owns the Focus Chunk slot when a session crosses 04:00? AD-19 and AD-20 charge two different ledgers

**Seam:** AD-19 × AD-20 × AD-4 (with AD-24 and SM-1 dragged in).

**Setup.** Session starts 03:55 (domestic Day 1). A Focus Chunk is dealt 03:58 and answered `Hecho` at 04:05 — the `card_done`'s stored instant is inside domestic Day 2. The session closes at 04:30.

**Unit A — occupancy by the act's domestic day.** The 04:05 `card_done` closes **Day 2's** slot: AD-20 says "at most one Focus Chunk is ever answered `Hecho` **in a day**", and AD-4 makes the day of an act the day of its stored instant+offset. AD-19's "the advance is charged to the session's own day" is read as *Time-Bag accounting only* — the bag charge goes to Day 1, the slot goes to Day 2. Consequence: when the user opens the app at 10:00 on Day 2 with a fresh bag, no Focus Chunk is dealt that day — Day 2's slot was consumed by an act of yesterday's session.

**Unit B — occupancy by the charged day.** AD-19's letter is followed to the word: the advance — deal, answer, occupancy — is charged to the session's own day, and "the next day's slot **resolves at the first deal after the session closes**" is read as guaranteeing Day 2's slot is open after close. The 04:05 answer occupies **Day 1's** slot; the 10:00 answer occupies Day 2's.

**Both cite ADs in their own defense.** A cites AD-20's "answered `Hecho` in a day" + AD-4's instant-to-day conversion. B cites AD-19's "the advance is charged to the session's own day" and the very next clause about the next day's slot resolving after close — which under A is false (the slot resolved, and closed, *before* the session closed). Neither AD defines whether "charged" and "occupied" are one ledger or two.

**User-visible failure.** Divergent builds for identical logs. Worse, unit B ships the exact hazard AD-4's *Prevents* clause names — "dishes finished at 23:55 and a second Focus Chunk at 00:05 *because it is another day*": the marathon with a comma, two answered Focus Chunks (04:05 and 10:00) inside one domestic-day boundary, each build-compliant. Unit A ships the mirror: a silently chunk-less Day 2 (FR-7's "the day composes without a '1'" without any bag reason). A third sub-case compounds it: after process death mid-session (no `session_ended`), a session started Day 1 can still be dealing on Day 3 — is Day 3 a day "carrying at least one `session_started`" (AD-24)? Unit A says no (no start *on* the day) and freezes every capture window; unit B says yes. SM-1's "sessions on ≥70% of days" measures differently on the two builds.

**Severity: critical** — one letter-compliant build ships the broken once-per-day guarantee AD-20 and FR-12 exist to make structural.

**Tightening.** Amend AD-20 (or add AD-27): *a `card_done` occupies the slot of the day the session that dealt it belongs to (AD-19), and of no other day; a session whose own day's slot is closed may not be dealt a Focus Chunk after crossing a boundary; the crossed-into day's slot is never occupied by an act of the crossing session.* And amend AD-24: *"carrying at least one `session_started`" means a session **started** on that day by its start instant; a session outliving its day does not make the later day eligible.*

---

## ADV-2 — "That day's energy" is undefined for days with multiple `energy_set`, and for energy set inside a cross-boundary session

**Seam:** AD-24 × AD-4 (feeding FR-5's decline counter and FR-12's capture window — which the PRD declares "the same mechanism").

**Setup.** Day D: session at 10:00 with energy 🟡 (set 09:55), session at 21:00 with energy 🔴 (set 20:00). A pending 10–15 min capture. Was Day D an `EligibleDay` for it?

**Unit A — day energy = the last `energy_set` of the day.** Day D's energy is 🔴; the size was excluded; Day D is ineligible; the deal window freezes. Cites AD-4 verbatim: "the last `energy_set` of the current domestic day" — applied retrospectively, that *is* "that day's energy" in AD-24's singular.

**Unit B — exclusion is evaluated per dealing opportunity.** At the 10:00 session the capture *was* eligible for dealing (energy 🟡 filters nothing, FR-4) and simply wasn't dealt; a day is ineligible only if the size was excluded at **every** session on that day. Day D is eligible; the window advances. Cites AD-24's own wording — "on which the item's size was **not excluded by that day's energy**" says nothing about *last* — and FR-4's "the eligible Micro-task pool filters immediately", which makes the pool a time-varying thing, not a per-day constant.

**User-visible failure.** The same capture deals on calendar day 3 in one build and day 6 in the other; two captures' FIFO order inverts; FR-5's rescue fires a week apart; and because both windows are "the same mechanism", the two builds disagree about *whether they are* the same mechanism. A third wrinkle: `energy_set` written at 04:10 inside a Day-1-charged session (ADV-1) — AD-4 gives the *instant's* day (Day 2), AD-19 charges the *session's* acts to Day 1; the two units attribute the exclusion to different days.

**Severity: high** — divergent builds over the two load-bearing freeze windows.

**Tightening.** Amend AD-24 with an evaluation function: *"that day's energy" at a session = the last `energy_set` at or before that session's start instant, defaulting 🟢; a size is excluded on a day iff it is excluded at the start of every session that day; an `energy_set` belongs to its own instant's domestic day regardless of session attribution.* AD-4's "last of the current day" then governs the *live* pool only, not retrospective predicates.

---

## ADV-3 — Export outcome has no compliant durable home: AD-21's exhaustive seven + "no other store" leaves FR-30's observability volatile

**Seam:** AD-21 × AD-13 × FR-30 (with AD-22).

**Setup.** The silent export fails for three weeks (revoked SAF permission). FR-30 and AD-13 require "destination, last success, last failure **and cause**" readable in settings.

**Unit A — volatile, in the adapter.** The export adapter reports its outcome in memory to the settings surface. Cites AD-21: system events are "enumerated exhaustively" — `export_observed` is not among the seven, so persisting the outcome as an eighth event violates the letter; and "**No other store exists**: no preferences, no side files" forbids a durable side channel. After any process death, settings shows no failure at all.

**Unit B — derived from the destination.** Last success is derived from the exported files themselves via the Folder port (AD-13's atomic rename makes the file's presence the record of success); last failure and cause are simply not derivable and never shown. Cites the same AD-21 sentences plus AD-13's "the adapter reports its outcome" — a report, not a record.

**User-visible failure.** On both builds, FR-30's "last failure and its cause" effectively does not survive a restart — the validator cannot distinguish "exporting fine" from "silently failing since Tuesday" without manually inspecting the folder, which is precisely the failure mode FR-30's observability exists to catch during a 4-week window with mid-window builds. The builds also disagree with each other about what settings shows.

**Severity: high** — the validation evidence pipeline's health is unobservable in every compliant build, and the two builds diverge.

**Tightening.** Add `export_recorded` (outcome + cause; naming fits AD-21's `*_recorded` convention, AD-12's `crash_recorded` is the precedent) to the enumerated seven, and say it is excluded from user-facing derivations like the rest. Note for the fixer: the same scan of the vocabulary finds **no act for "the user left the scan surface"** (an AD-8 resolution cause) and therefore no way to derive FR-26 series (b)'s outcome for an abandoned call — unit A counts resolved calls only, unit B counts every `slice_requested`; SM-4's denominator shifts between builds. Either enumerate that act too or state in AD-13/AD-26 how abandoned calls read in series (b).

---

## ADV-4 — Import across a version seam: AD-23's tolerance is stated over *derivations*, not over the import, and the two disagree

**Seam:** AD-13 × AD-23 × AD-18.

**Setup.** AD-18's ritual: export on all three handsets, install on top, **import if a migration fails** — i.e., the import deliberately runs against a log produced by a *different build*. Mid-window builds add payload fields and new entry kinds (AD-23's only lawful evolution).

**Unit A — tolerate and default.** The import accepts older JSONL rows, applying AD-23 defaults for missing fields, preserving unknown kinds verbatim. Cites AD-23: "payloads are additive-only; a field may be added with a default" and "unknown kinds are tolerated and ignored, never coerced and never fatal".

**Unit B — refuse on anything unrecognized.** The import rejects rows it cannot fully parse — unknown kinds, unknown fields — as corrupt, restoring nothing. Cites AD-13's own refusal posture: the import "refuses rather than partially restoring" (the torn-case clause), and restoring state it cannot interpret *is* partial restore.

Both are letter-compliant because AD-23's tolerance sentence begins "**A derivation** that meets an entry kind it does not know…" — the import adapter is not a derivation, and no AD binds it.

**User-visible failure.** On unit B's build, the exact scenario AD-18 exists for — migration fails mid-window, data must come back from the export — the restore refuses, because the export was made by the *newer* build the handsets had been running. Validation data lost. A second face of the same hole: unit A's build importing a newer build's export containing a new kind (say `album_purged`) tolerates-and-ignores it, then derives the album manifest as if the purge never happened — a restored album whose entries point at unlinked, unexported images.

**Severity: high** — divergent builds; one loses the restore path the update ritual depends on.

**Tightening.** Amend AD-13 with an import contract: *the import applies AD-23's tolerance — unknown kinds and fields are preserved verbatim and defaulted where a default exists; refusal is reserved for structural corruption (truncation, malformed records) and nothing else.* Extend the property test: import a fixture from build N+1 into build N and assert no derived read model regresses.

---

## ADV-5 — AD-25's dissolution retires *what*, exactly? Orphaned rescue siblings keep being dealt in one build

**Seam:** AD-25 × FR-5 × AD-20 (with AD-23's additive payloads and AD-14's immutable origin as context).

**Setup.** A rescue chain has four ≤60 s steps. Two of them are declined on 3 different days. FR-5: "A rescue whose steps are themselves declined on 3 different days **dissolves the original task** silently — out of the pool."

**Unit A — the original only.** AD-25: "Retirement has exactly two derived causes… the completion of its rescue children, and FR-5's dissolution pattern." FR-5's sentence dissolves *the original task*; the two declined steps dissolve nothing (dissolution is the *rescue's* pattern, not a step's), and the two never-declined siblings remain pool items with no retirement cause at all — "an item is in the pool if a pool fact created it and no derivation retires it". The siblings keep being woven as ordinary 60 s cards, forever; the parent's derived completion ("completion of its rescue children") can now never fire, so nothing ever closes.

**Unit B — the whole chain.** "FR-5's dissolution pattern" retires the original *and* every remaining step of that rescue chain in the same derivation, on the reading that the pattern is a property of the chain.

Both cite AD-25's "exactly two derived causes" and FR-5's wording; the *scope* of "the dissolution pattern" is the undefined term.

**User-visible failure.** On unit A, the user keeps being dealt ghost steps of a task that dissolved — an anti-shaming hazard dressed as a pool item ("out of the pool, no state, no notice" was the guarantee), and their completions count in FR-26 series (a) toward nothing. On unit B the day silently loses them. Related seam, same finding: on a 🔴 day a Focus Chunk's ≤60 s rescue steps *are* dealable (FR-4 excludes by size, the steps are small), and a chain completed on a 🔴 day — unit A closes the day's slot and consumes rotation ("a completed rescue chain closes the slot", AD-20); unit B holds that a day that deals no Focus Chunk consumes nothing of the rotation (FR-31). The 28-deal guarantee counts differently.

**Severity: high** — divergent builds; one keeps re-weaving the fragments of a dissolved task, which is FR-5's "nothing is re-woven forever" broken while letter-compliant.

**Tightening.** Amend AD-25: *the dissolution pattern retires the original item and every not-yet-completed step of that rescue chain, atomically in one derivation; a completed rescue chain closes the slot of (and consumes rotation on) the day of its last `card_done`, regardless of that day's energy.*

---

## ADV-6 — SM-2's report window: "from Sunday onward, persisting until answered that week" against a Monday-anchored week

**Seam:** AD-4 (week definition) × SM-2 × AD-15 (the SM-C2 audit surface).

**Setup.** AD-4 anchors the week on Monday, and glosses SM-2: "'from Sunday onward, persisting until answered that week' is the week's **last day**, and one answer closes it."

**Unit A — Sunday only.** The question appears on the first opening of Sunday (the week's last domestic day); unanswered, it expires at the week boundary; "a week with no answer simply has no data point". Cites AD-4's gloss.

**Unit B — Sunday onward.** The question appears on the first opening from Sunday and *persists until answered*, which on a Monday-anchored week means it can be answered any day of the following week. Cites SM-2's literal text — "persisting until answered" is explicit, and AD-4's gloss concedes Sunday is "the week's last day" without ever saying the question *dies* there.

**User-visible failure.** Unit B's build nags: an unanswered 5-point question about overwhelm persisting six days in the one surface the user lives is an obligation-shaped presence — adjacent to the exact P2/SM-C2 hazard the product exists to remove — and its week-1 baseline can be answered on a Wednesday, so SM-2's within-subject trend is measured on different days across builds. Both builds pass AD-15's audit because the copy is identical; the divergence is purely in the window derivation, which no AD pins.

**Severity: medium** — rework and a metrics-validity risk, not a broken structural guarantee.

**Tightening.** Amend AD-4's SM-2 clause to close the ambiguity: *the report window is the last domestic day (Sunday) of the week only; an unanswered report expires at the week boundary and never carries into the next week.*

---

## ADV-7 — "The one quiet affordance" is load-bearing and defined nowhere

**Seam:** AD-26 × §7 settings/Dispenser split × AD-6.

**Setup.** AD-26: "Nothing on the validator surface is reachable from the Dispenser except through the one quiet affordance." The Deferred section lists "the single quiet affordance's mark" as an open UX question — its *mark*, but not its *identity, count, host surface, or depth*, is deferred.

**Unit A** hosts the affordance in the Dispenser chrome (a quiet glyph, one tap to settings). **Unit B** hosts it two surfaces away (e.g., on the dashboard), holding that the Dispenser merely needs *a* route and that the dashboard is "the one quiet affordance" — the raw FR-26 series then sit three taps from the home surface. A third variant renders the affordance on both the Dispenser and the capture surface, counting each as "the one" from its own vantage.

**All cite AD-26's own sentence** — it is the only sentence in the corpus about the affordance, and it presupposes rather than defines it.

**User-visible failure.** The §7 split — "the user's surfaces stay free of counters, and the numbers still exist for whoever goes looking" — is enforced at a different depth on each build: on one, the decline counts and raw series live one quiet tap from where the user lives; on another, the validator (the builder, mid-window) cannot find them without hunting. Neither is checkable, because no AD states what to check.

**Severity: medium** — divergent builds of the split's enforcement; fixable cheaply now, expensively once surfaces exist.

**Tightening.** Amend AD-26: *the affordance is unique, lives in the Dispenser chrome (its mark is the deferred UX question), and no surface reachable within three taps of the Dispenser may link into the validator surface by any other route.*

---

## ADV-8 — The three causes of `session_ended` do not cover FR-3's early close or process death, and the two compliant completions write different series

**Seam:** AD-19 × FR-3 × FR-9 (with FR-26 series (a) as the reader).

**Setup 1.** The eligible pool runs out mid-session; FR-3 mandates "the session closes early with neutral, warm copy". AD-19: `session_ended` "is emitted by exactly three causes and no others".

**Unit A** maps the warm close's stop affordance onto cause 1 — the tap *is* "the user stopping" — and writes `session_ended` at the tap. **Unit B** shows the copy with no stop affordance of its own; the session ends by cause 2 (pocket elapsing while foregrounded) or cause 3 (backgrounding), minutes later. Both letter-compliant; the warm copy itself is pure rendering and no AD binds it to a cause.

**Setup 2.** Process death mid-session: none of the three causes fires; the derived session is still open on reopen, possibly days later, with its pocket long spent.

**Unit A** closes it at the next foreground instant, reading "the declared pocket elapsing **while the app is foregrounded**" as satisfied at the moment foregrounding reveals the elapse. **Unit B** resumes it (FR-9: "resuming deals the next Micro-task directly") into an immediately-empty pocket and warm-closes per FR-3. Again both compliant; AD-19 is silent on whether the elapse must *occur* during foreground.

**User-visible failure.** FR-26 series (a) — "session start/end **with duration**", the input to SM-C1, the comfortable-day run, and SM-2's context — records different durations for identical user behavior on the two builds, and the comfortable-day predicate ("no session beyond its declared pocket") sits on the same ambiguity. The export, which is the validation evidence, differs.

**Severity: medium** — no broken product guarantee, but the validation data itself is build-dependent at its source.

**Tightening.** Amend AD-19: *FR-3's early close is cause 1 — the warm close presents the stop, and the tap emits `session_ended`; a session whose pocket has fully elapsed at any foreground instant closes at that instant.*

---

## ADV-9 — Nothing pins what "oldest first" reads: act instants vs UUIDv7 mint order

**Seam:** Conventions (ids, time) × AD-3 × FR-12 FIFO.

**Setup.** Conventions: "UUIDv7 minted in the shell and handed to the core"; the stack note leans UUIDv7 monotonicity against AD-3's stable-id tie-break. Two captures: X's surface opens 10:00:00 (unit B's shell pre-mints the id then), Y's opens 10:00:30; Y is confirmed 10:00:45, X at 10:01 (the user edited X's line longer).

**Unit A** derives FIFO from the recorded instant of the committing act (`capture_created`): Y deals before X. **Unit B** derives FIFO from the id's embedded time-bits ("stable id" order): X deals before Y. Both cite the conventions table — it fixes where ids are minted, never that ordering derivations read *act instants*; AD-3 fixes tie-breaks among candidates but not the FIFO anchor.

**User-visible failure.** The two captures are dealt in opposite order on the two builds; FR-12's "oldest first" and the 3-eligible-day window's fairness silently depend on a convention that was never written. (The worst variant — an import that re-mints ids — is caught by AD-13's round-trip property test, which is why this is medium, not high; the pre-mint variant above is not caught by any stated test.)

**Severity: medium** — rework; a one-line convention closes it.

**Tightening.** Conventions amendment: *every ordering derivation (FIFO, least-recently-dealt, window anchors) reads recorded act instants, never id bit patterns; ids are minted at the commit of the act or fact they name, and export/import preserves ids verbatim.*

---

## Worked and cleared (attacks that did not yield a both-compliant pair)

- **AD-8's sweep needs no log entry.** Existence of a scan subdirectory *is* the unresolved marker: every resolution path unlinks, so at session start any remaining directory is crash debris and the sweep unlinks it — a unit sweeping "nothing" after process death would violate AD-8's letter outright. Not a pair. (The adjacent vocabulary gap — no act for "user left the scan surface" — is real and is folded into ADV-3.)
- **Zone-change alarm drift.** AD-4 pins the trigger instant as core-computed from the chosen hour; a last-fired-plus-24h implementation drifts but no AD letter defends it against AD-17's "at most one per domestic day" once it emits twice. Cleared.
- **🟡 filtering, tie-break counting, skip/rotation.** AD-3's "counts these rows and no others" plus AD-20's "answered deals on the same terms" pin the two countings; no both-compliant divergence found.
- **SAF destination as a third store.** AD-22 explicitly rules the persisted URI a capability grant, not a value; cleared by letter.
- **AD-24's excluded item-level candidacy.** Deliberate and reasoned in the AD itself; not a hole.
- **Synthetic 🟢 day-boundary `energy_set`.** Materializing the default would have a compliant-ish letter reading, but no stated reader of `energy_set` rows makes the divergence user-visible; noted for ADV-2's fix to forbid in passing ("the 🟢 default is derived, never written").

## Summary for triage

The spine's individual ADs are tight; its failures are now all *between* pairs of them: one entity (the day's slot) charged by two ledgers (ADV-1), one predicate reading two clocks of energy (ADV-2), an exhaustive vocabulary that starves two legitimate needs (ADV-3, ADV-8's tail), an evolution theory stated over the wrong consumer (ADV-4), and retirement/termination scopes left to the reader (ADV-5, ADV-6). One new AD and five amendments close all nine.

**Verdict: FAIL** — one critical, four high.

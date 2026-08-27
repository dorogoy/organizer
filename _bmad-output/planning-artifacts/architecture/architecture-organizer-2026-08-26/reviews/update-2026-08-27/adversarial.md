---
lens: adversarial
method: construct two units, one level down, each letter-compliant with every AD, that still build incompatibly
reviewer: independent adversarial subagent (update pass)
date: '2026-08-27'
target: ARCHITECTURE-SPINE.md (architecture-organizer-2026-08-26), status final, updated 2026-08-27
inputs: ARCHITECTURE-SPINE.md; prd-organizer-2026-08-20/prd.md; reviews/validate-2026-08-27/adversarial.md (prior round, ADV-1..ADV-9)
verdict: FAIL
severity-tally: { critical: 0, high: 4, medium: 7 }
---

# Adversarial review — the updated spine, attacked at its seams

Two passes, in the configured order. First: each of the nine prior findings is re-attacked through its amendment — a fix counts as closed only if **no both-compliant pair remains**. Second: the whole spine is attacked fresh, with priority on the seams the new sentences opened (`export_recorded`, `scan_abandoned`, `warmReturnDue`, the one-ledger rule, the store seal). Every finding below exhibits two units that each obey the letter of the ADs they cite and still build incompatibly; one finding (ADV-14) additionally shows a rule no build can satisfy as written. Severity follows the prior round's floor: **critical** = one compliant build ships a broken guarantee; **high** = divergent builds; **medium** = rework.

---

## Part 1 — Verification of the prior nine (ADV-1..ADV-9)

| Prior | Amendment applied | Disposition |
| --- | --- | --- |
| ADV-1 (slot across 04:00) | AD-20 session-day rule; AD-24 start-instant eligibility | **Re-opened** — the rescue-chain clause in the same AD kept act-day attribution; see ADV-10 |
| ADV-2 (that day's energy) | AD-24 evaluation function; AD-4 live/retrospective split | **Re-opened** — the amendment's two sentences contradict each other on mixed-energy days, and the anchor is day-unscoped; see ADV-11 |
| ADV-3 (export outcome home) | `export_recorded` as eighth event; AD-13 observability; `scan_abandoned` added | Core **closed**; two tails remain — see ADV-15 (backgrounding cause) and ADV-18 (which facts render) |
| ADV-4 (import tolerance) | AD-13 import contract; N+1 fixture test | **Closed**, with a residual edge on "malformed" — see ADV-16 |
| ADV-5 (dissolution scope) | AD-25 atomic chain retirement; AD-20 rescue slot/rotation clause | Dissolution scope **closed**; the slot/rotation clause is half of ADV-10 |
| ADV-6 (SM-2 window) | AD-4 Sunday-only window | **Closed** |
| ADV-7 (quiet affordance) | AD-26 unique, Dispenser chrome, three-tap rule | **Closed** |
| ADV-8 (`session_ended` causes) | AD-19 cause-1 mapping; elapse revealed, not awaited | **Closed** |
| ADV-9 (FIFO anchor) | Conventions: act instants, never id bits; mint at commit | **Closed** |

Six of nine hold. The two re-opens share a cause worth naming for triage: **the update applied the prior round's fix texts verbatim, and two of them collide with each other and with themselves** — ADV-5's tightening ("the day of its last `card_done`") was written before ADV-1's tightening ("the day its dealing session belongs to") existed, and both were adopted into the same AD.

---

## Part 2 — Findings

### ADV-10 — AD-20's two new rules collide: the rescue chain still closes the slot by act-day, the plain `card_done` by session-day

**Seam:** AD-20 × AD-19 × AD-4 (the ADV-1 fix × the ADV-5 fix).

**Setup.** Session starts 03:55 on domestic Day 1 (declared pocket 60 min). A stuck 10–15 min item's rescue chain is running; its final ≤60 s step is answered `Hecho` at 04:05 — the `card_done`'s stored instant is inside domestic Day 2. The session closes at 04:30.

**Unit A — the rescue sentence, literally.** AD-20: "A completed rescue chain closes the slot of, and consumes rotation on, the day of its **last** `card_done`." The day of an event is the day of its stored instant+offset (AD-4); AD-3 uses exactly this act-day reading elsewhere ("a `card_skipped` on that day"). The chain closes **Day 2's** slot. Day 1's slot was never closed (the original chunk was only ever skipped, and a skip closes nothing), but Day 1 ends at 04:00 — so it dies open. At 10:00 on Day 2 the user is dealt no Focus Chunk: Day 2's slot was consumed by an act of yesterday's session.

**Unit B — harmonized with the adjacent clause.** The very sentence before says "The slot a `card_done` closes is **the day its dealing session belongs to (AD-19), and no other**." Unit B reads "the day of its last `card_done`" through that rule (the only added content being "regardless of that day's energy", from ADV-5): the chain closes **Day 1's** slot, and Day 2 gets its own chunk at 10:00.

Both cite AD-20's letter — the plain-`card_done` rule and the rescue rule are stated on different attributions, and neither sentence says which governs the other.

**User-visible failure.** Identical logs, divergent slot occupancy — the exact ADV-1 failure resurrected through the rescue path: unit A ships the silently chunk-less Day 2 (FR-7's "day composes without a '1'" with no bag reason); FR-31's rotation is consumed on different days, so the 28-deal guarantee's counting shifts between builds; the export differs.

**Severity: high** — divergent builds over the once-per-day occupancy guarantee; neither build can double-chunk, so it stops short of critical.

**Tightening.** Rewrite the rescue clause: *a completed rescue chain closes the slot of, and consumes rotation on, the day the session that dealt its last `card_done` belongs to (AD-19), and no other — regardless of that day's energy.* One attribution rule in AD-20, stated once, covering both paths.

---

### ADV-11 — AD-24's amendment contradicts itself on mixed-energy days, and its energy anchor is day-unscoped

**Seam:** AD-24's first sentence × AD-24's second sentence × AD-4 (re-open of ADV-2).

**Setup.** The original ADV-2 day: session at 10:00 with energy 🟡 (set 09:55), session at 21:00 with energy 🔴 (set 20:00). A pending 10–15 min capture. Was the day eligible?

**Unit A — the definition sentence.** "A size is excluded on a day iff it is excluded at the start of **every** session that day" → not excluded at every session → **eligible**; the deal window advances.

**Unit B — the gloss sentence.** "A domestic day … on which the item's size was **not excluded at any session's start**" — natural reading: at no session's start was it excluded. It *was* excluded at the 21:00 session's start → **ineligible**; the window freezes.

Each unit cites a different sentence of the same amendment. On any day whose sessions carry mixed energies, the two sentences give opposite answers — which is precisely the divergence ADV-2 existed to close, now armed with the fix's own text.

**Second face — the unscoped anchor.** "'That day's energy' at a session is the last `energy_set` at or before that session's start instant, defaulting to 🟢" — the sentence never scopes the search to the session's day. Day 1, 20:00: `energy_set` 🔴. Day 2, 10:00: a session starts; no new `energy_set`. Unit A (literal, cross-day): the last `energy_set` at or before 10:00 is yesterday's 🔴 → 10–15 min excluded at that session's start → Day 2 ineligible for captures. Unit B (day-scoped, defaulting 🟢 per AD-4's "never carried across one [boundary]" — which AD-4 explicitly confines to the *live* pool, leaving the retrospective anchor unpinned): 🟢 → eligible. On unit A the freeze continues into a day the user experienced as green-by-default and on which they may even have answered a Focus Chunk.

**User-visible failure.** Captures deal on different days between builds; FIFO between two captures inverts; FR-5's rescue fires days apart; SM-1's day set is untouched but every window that freezes "on the same mechanism" freezes differently. Both faces hit the two load-bearing freeze windows the PRD calls one mechanism.

**Severity: high** — divergent builds, and the fix's own text is internally inconsistent.

**Tightening.** Make the evaluation function the sole definition and repair the gloss to match it ("…on which the item's size was not excluded at the start of every session that day" — or drop the gloss). Day-scope the anchor: *the last `energy_set` at or before the session's start instant **and after the start of that session's own domestic day**, defaulting to 🟢* — the retrospective rule then matches AD-4's carry-free boundary instead of contradicting it.

---

### ADV-12 — `warmReturnDue` reads `app_opened` against AD-21's single-exception reader seal — and the spine now contradicts itself about who may read a system event

**Seam:** AD-24's new `warmReturnDue` sentence × AD-21 × AD-6 (× FR-6).

**Setup.** AD-24: "`warmReturnDue` — 48 h wall-clock since the later of the last `app_opened` and the last user act." AD-21: system events "are readable only by `core/export` and the FR-26 series — excluded from every user-facing derivation by construction, with **one stated exception**: `permissionMayBeAsked`." `app_opened` is a system event; `warmReturnDue` gates the Warm Return screen, the most user-facing derivation in the product.

**Unit A — obeys AD-24.** Reads `app_opened`; the anchor is the later of the last open and the last act. **Unit B — obeys AD-21.** Holds the read illegal outside the one stated exception and anchors on user acts alone. Both are letter-compliant; the two ADs mandate incompatible predicates and neither marks itself as yielding.

**User-visible failure — the lurker and its inverse.** A disengaged user peeks daily (an `app_opened`, no acts — the exact person Warm Return exists for). On unit A the anchor moves with every peek: the welcome-back **never fires**, and FR-6's promise is broken in effect. On unit B it fires after 48 h for a user who was there yesterday — "you were gone" said to someone who wasn't. A third wrinkle: AD-6 says derived signals "are inputs to `core/weave`, not outputs to the shell" — so unit B2, taking that letter seriously, has no compliant way to let the Warm Return *screen* learn the predicate at all. The same disease appears in AD-13's new observability clause (the settings surface renders `export_recorded` — a second unstated reader of a system event, defensible only because the validator surface is arguably not "user-facing"). AD-21's "one stated exception" is now false on its own document's terms.

**Severity: high** — a self-contradiction between two ADs, and divergent builds of a user-facing state machine.

**Tightening.** Amend AD-21 to enumerate its exceptions exhaustively: `permissionMayBeAsked`, `warmReturnDue` (over `app_opened`), and the validator surface's render of `export_recorded` — or re-anchor `warmReturnDue` on user acts plus `session_started` and drop `app_opened` from AD-24. And add one clause to AD-6: a derived *state* fact (`warmReturnDue`) may cross to the shell for a non-work surface; only signals-as-work are confined to the weave.

---

### ADV-13 — `card_skipped` is absent from the one-ledger enumeration: a skip after 04:00 counts on one build and nowhere on the other

**Seam:** AD-19's enumeration ("deal, answer, occupancy and rotation") × AD-4 × AD-24 × FR-5.

**Setup.** Session starts 03:40 on Day 1, crosses 04:00. A card is dealt 03:50 (deal: charged to Day 1) and skipped at 04:05 — the `card_skipped`'s stored instant is Day 2. FR-5's counter is expressed over `EligibleDay` (AD-24: every counter and freeze is).

**Unit A — the skip follows its deal.** "Deal" and "answer" are the ledger's nouns, and a skip is an answer (AD-3: `card_dealt` "is appended by the command that answers the previous card" — Done and Skip are the two answers, FR-1). The skip is charged to Day 1; Day 1 is eligible (a session started on it); **the decline counter advances**.

**Unit B — the skip is its own act on its own day.** The enumeration names deal, answer (`card_done`, per AD-20's "answered `Hecho`" usage), occupancy, rotation — `card_skipped` is listed nowhere, and `energy_set` got an explicit carve-out ("belongs to its own instant's domestic day") that the skip did not. The skip's day is Day 2 (AD-4); Day 2 has no `session_started` by start instant, so it is **ineligible**, and a frozen day advances nothing: **the skip counts nowhere**.

Both cite AD-19's letter plus one of AD-3/AD-4/AD-24. The amendment that fixed `card_done`'s attribution enumerated four nouns and closed the list.

**User-visible failure.** FR-5's rescue trigger day-set differs by one day per crossing-session skip: identical logs contract a stuck task into a rescue on different days on the two builds; the export's series differ. The same enumeration gap moves every future skip-adjacent per-day count.

**Severity: high** — divergent builds over FR-5's trigger, the mechanism ADV-2's "same mechanism" clause was written to keep uniform.

**Tightening.** Amend AD-19: *every `card_*` act of a session — dealt, done, skipped — is charged to the session's own day* (or add `skip` to the enumeration explicitly). One sentence; the carve-out pattern (`energy_set`) shows the shape.

---

### ADV-14 — The store seal names two adapters; the design mandates three file planes outside them — no build satisfies the letter, and the carve-outs diverge

**Seam:** AD-21's store seal ("no persistence API is touched outside the Store and Folder adapters") × AD-8 (per-scan cache create/unlink) × AD-13 (album byte writes and unlinks) × AD-16 (catalogue asset read) × the conventions row on files.

**Setup.** The spine itself requires durable and transient file work that is neither SQLite nor the SAF destination: album images live in app-private storage and are written, exported and unlinked (AD-13, conventions); every scan owns a cache subdirectory that is created, capped and unlinked (AD-8); the catalogue asset must be read by some shell module — the core does no I/O (AD-5), the Store adapter is drift, and the Folder adapter is the *user-chosen export destination* (routing a scan frame through it would write a photo of the user's home into the export folder).

**Unit A — "files aren't persistence."** Reads the seal as covering databases and preferences only; album and scan-cache I/O live in `plugins/` and the scan surface module; the catalogue is loaded anywhere in shell bootstrap via the asset bundle. **Unit B — everything durable is persistence.** Widens the Store adapter to own all app-private file paths and the asset load, keeping the seal's grep clean. Both are compliant only under an unstated interpretation of "persistence API" — and notably, **a unit that implements the letter with no interpretation cannot exist**: every legal build must adopt one of these carve-outs.

**User-visible failure.** None immediately — and that is the trap. The `tool/` store seal, written to unit A's reading, blesses any file a plugin touches (the next fourth store walks through as a "plugin cache file"); written to unit B's, it fails unit A's legal build. CI diverges or gets waived, and the waived seal is the hole AD-21 added it to close. The restore path also splits: on unit B the import restores album bytes through the Store; on unit A through an unowned module — two owners of one entity, the exact shape this lens hunts.

**Severity: medium** — rework now, a dead seal later; behavior converges once the carve-out is written.

**Tightening.** Amend AD-21: *no persistence API is touched outside the Store, Folder, and Files adapters* — naming a third adapter that owns app-private bytes (album, scan cache) — plus: *the catalogue asset is loaded once by a named loader and handed to the core as data; the asset bundle is on the seal's allowlist*. The tool/ check then greps against an exhaustive allowlist instead of an undefined noun. (The l10n ARB needs nothing: `gen_l10n` is compile-time, no runtime persistence API. The settings cache needs nothing either: it is in-memory, and persisting it would violate "no side files" directly.)

---

### ADV-15 — The scan-resolution vocabulary's tails: backgrounding has no event, and the crash sweep's "session start" is not a session

**Seam:** AD-8 × FR-16 × the conventions row on `scan_abandoned` × AD-19 (ADV-3's fix, incomplete at the tail).

**Setup 1.** FR-16 names two abandonment causes with an "or": "Leaving the surface **or backgrounding the app** cancels the wait and discards it." AD-8 maps exactly one cause to an event: "the user leaving the surface (recorded as `scan_abandoned`)".

**Unit A** records backgrounding as `scan_abandoned` too — it is the only abandonment vocabulary that exists. **Unit B** holds backgrounding is a different cause (FR-16's "or" separates them), unlinks per AD-8, and writes no event — AD-21's exhaustive enumeration forbids inventing one. Both letter-compliant.

**Setup 2.** AD-8's backstop sweeps the cache "at session start". A crash mid-scan, then a user who never opens a Time-Bag pocket — the only `session` the corpus defines is AD-19's. **Unit A** sweeps at every app open (colloquial "session"); **unit B** sweeps only on `session_started` (the term's only defined meaning), and the crashed frame of the inside of the user's home sits on disk for days — the exact image AD-8's *Prevents* clause exists to kill.

**User-visible failure.** FR-26 series (b)'s outcome mix and denominator diverge between builds (on B, backgrounded scans are `slice_requested` rows with no terminal outcome — unclassifiable, though "the denominator closes over `scan_abandoned`"); SM-4's per-week scan accounting shifts; on B's sweep reading, a photograph outlives its scan.

**Severity: medium** — validation-evidence divergence and a privacy-hygiene window; no structural guarantee breaks.

**Tightening.** Amend AD-8 (or the conventions row): *`scan_abandoned` is the event for every non-completing resolution the user's departure caused — navigating away or backgrounding* — and: *the sweep runs at each `app_opened`*. Two phrases.

---

### ADV-16 — "Malformed records" is undefined: one bad field refuses the whole restore on one build and silently vanishes an act on the other

**Seam:** AD-13's import contract × AD-23 (residual edge of ADV-4's fix).

**Setup.** The import's refusal is "reserved for structural corruption (truncation, malformed records) and nothing else", with tolerance "preserved verbatim, defaulted where a default exists". A log row arrives that parses as JSON, has a known kind, and is missing a payload field for which no default exists (hand-edited export, or a partial sync write by the user's cloud client).

**Unit A — malformed, refuse.** A known kind missing a required field is a malformed record; the import refuses (FR-30's no-partial-restore backs this: restoring everything-but-one is partial). The entire restore is lost for one row — the ADV-4 failure one level down. **Unit B — well-formed, tolerate.** The record parses; the missing field is "preserved verbatim" (as absent), stored, and derivations skip what they cannot read. Every byte is restored — but a derived read model silently missing one act is partial restore in effect, while fully compliant with AD-13's "nothing else [is refused]".

Both cite the fix's own sentence; "malformed" is the undefined term, and the two property tests (torn truncation, N+1 fixture) cover neither shape.

**User-visible failure.** On A, a single damaged row costs all validation data on restore; on B, minutes and completions quietly go missing from the restored evidence. Same log, opposite outcomes.

**Severity: medium** — narrow log shape, but it lands on the restore path the whole validation depends on.

**Tightening.** Define it: *a record is malformed iff it fails to parse as JSON or a known kind lacks a field with no default; the import refuses on malformed rows*, and add both shapes to the property test's generated corpus.

---

### ADV-17 — Atomicity is per-file and the export is many files: rename order is unspecified, so a mid-rename crash leaves restorable mixed vintages

**Seam:** AD-13's atomicity clause × AD-13's import tolerance (new sentence × new sentence).

**Setup.** "Every file is written to a temporary name in the destination and renamed on completion" — per file. The export renames: the log, the pool, and every album image, in some order the AD does not give.

**Unit A** renames log → pool → images. **Unit B** renames images → pool → log. A process death (or revoked permission) between renames leaves A with a new log beside an old pool, B the reverse — each file structurally valid, so the import's tolerance ("refusal reserved for structural corruption… and nothing else") **must accept both**. The torn-case test truncates a file; no test mixes vintages, and the N+1 fixture crosses builds, not generations of one build.

**User-visible failure.** Restore from that folder produces a state no build ever held: log entries referencing pool facts that postdate the pool snapshot, derivations meeting item ids with no pool fact (a shape AD-23's "unknown kinds" tolerance does not govern), album manifest pointing at old images. Silent corruption of the validation evidence, arrived at legally.

**Severity: medium** — needs a crash inside a rename window plus a restore from that folder; the stakes (only copy after device loss) are the ones FR-30 exists for.

**Tightening.** State the commit protocol: *renames proceed images → pool → log; the log's rename is the export's commit point, and an import finding a newer log beside an older pool refuses* — or add a generation id to the payload (additive, per AD-23) that the import validates across files.

---

### ADV-18 — "The settings surface renders the latest" vs FR-30's three facts: after three failing weeks, one build cannot say when export last worked

**Seam:** AD-13's observability clause × FR-30 (ADV-3's fix, tail).

**Setup.** FR-30: "Export state — destination, **last success, last failure and its cause** — is readable in settings only." AD-13: "the adapter writes each outcome to the log as `export_recorded` … and the settings surface renders **the latest**."

**Unit A — one entry.** Renders the latest `export_recorded`: during a failure streak that is the latest failure; the last success is unreadable. **Unit B — the latest of each.** Derives last-success and last-failure-and-cause from the entry stream. Both compliant: "the latest" is singular in AD-13; FR-30 names three facts and no AD ranks it below AD-13.

**User-visible failure.** ADV-3's own test — "distinguish exporting fine from silently failing since Tuesday" — fails on unit A after any later failure overwrites the last success; the validator must inspect the folder by hand, which is what the fix existed to remove.

**Severity: medium** — one surface's observability; a sentence fixes it.

**Tightening.** *…the settings surface renders the latest success and the latest failure with its cause* (two derivations over `export_recorded`).

---

### ADV-19 — "The advance" is chunk-only in FR-7 and everything-dealt in AD-19's gloss: the comfortable-day run counts different days

**Seam:** AD-19's one-ledger rule × FR-7 × FR-23/§10.1 (snowball).

**Setup.** AD-19: "the advance — deal, answer, occupancy and rotation — is one ledger, charged to the session's own day." FR-7 defines the term: "The budget covers **advance work only — the Focus Chunk**." A session crosses 04:00; at 04:05 the user answers `Hecho` a 3-minute micro-maintenance card — not chunk-class work.

**Unit A — the ledger covers every dealt card.** The 04:05 completion is charged to Day 1 (session's day); Day 1 satisfies the snowball's "≥ 1 completed Micro-task". **Unit B — the ledger is the advance, and the advance is the chunk.** Non-chunk completions attribute by their own act's day (AD-4): Day 2 has the completion, and Day 2 — no session started on it — cannot be a comfortable day at all.

Both cite letter: A reads AD-19's enumeration broadly (deal, answer — of any card); B reads "the advance" through the only definition the corpus gives it.

**User-visible failure.** The comfortable-day run (internal, §10.1) counts differently; the snowball suggestion — the one user-visible output — appears on different days on the two builds; SM-C1's per-day reference shifts. (FR-23's dashboard totals are cumulative and attribution-free — the divergence is entirely in the per-day internals.)

**Severity: medium** — internal signal, user-visible only through snowball timing.

**Tightening.** One clause in AD-19: *the one-ledger rule covers every `card_*` act of a session, chunk-class or not* — or, if the advance really is chunk-only, *every non-chunk act attributes by its own instant's day* (the `energy_set` carve-out's shape). Either, stated.

---

### ADV-20 — The invitation hour is interpreted in a zone no AD names: home-zone builds ping at 03:00 after a trip

**Seam:** AD-4 ("FR-24's trigger instant is computed in the core from the chosen hour") × AD-17 × AD-4's own offset discipline.

**Setup.** The user sets the invitation hour 20:00 while in Madrid; during the validation window they travel to Mexico City (UJ-3's work trip is the product's own scenario). The core must convert "the chosen hour" into an absolute instant; the AD never says **in which offset** — and AD-4's stored-offset rule governs *history*, not a future trigger.

**Unit A — the current zone.** The shell hands the core the device's zone at each (re)schedule; the ping follows the user: 20:00 local wherever they are. **Unit B — the stored offset.** The `setting_changed` event that set the hour carried Madrid's offset; the trigger is 20:00 Madrid — 03:00 in Mexico City: a silent 3 a.m. notification, the loudest thing this product is permitted to do, from a build that broke nothing.

Both compliant — "computed in the core from the chosen hour" is the whole specification, and neither reading contradicts any letter (the Kotlin half computes no dates either way, AD-4).

**User-visible failure.** Post-travel invitation hours diverge between builds; one ships a 3 a.m. ping during the exact window SM-C3 watches notification pressure.

**Severity: medium** — travel-shaped edge, but the product's own journey assumes it, and AD-4 is the AD whose job this is.

**Tightening.** One sentence in AD-4: *the chosen hour is interpreted in the local offset in force at each reschedule* (follows the user) — or *in the offset stored on the `setting_changed` event that set it* (home-anchored). Pick one; say it.

---

## Worked and cleared (attacks that did not yield a both-compliant pair)

- **`warmReturnDue` × AD-4's offset-carrying entries** (a named priority): cleared as an *offset* seam — the predicate compares UTC instants and converts nothing to a period, so stored offsets cannot enter it. The real `warmReturnDue` hole is its input and output paths (ADV-12).
- **The l10n ARB vs the store seal** (named priority): cleared — `gen_l10n` resolves at compile time to generated accessors; no runtime persistence API is touched.
- **The settings cache vs the store seal** (named priority): cleared — AD-1's cache is an in-memory derivation rebuilt from the log; persisting it would violate AD-21's "no side files" by letter, not interpretation.
- **`scan_abandoned` vs AD-21's system-event naming pattern** (`*_emitted`/`*_refused`/`*_observed`/`*_recorded`/`*_opened`): cleared — the pattern binds system events; `scan_abandoned` is classified as a user act, which carries no pattern requirement.
- **The one-ledger rule vs FR-23's dashboard** (named priority): cleared as stated — cumulative minutes and totals are attribution-free sums. The per-day internals are not; that is ADV-19.
- **Dropped export triggers and data lag**: both builds drop per AD-13's letter; the lag self-heals at the next trigger. Not a pair.
- **`export_recorded` feedback into the round-trip property test**: deterministic — entries ride the log like any other row; wipe/import restores them identically.
- **The "within milliseconds" double trigger (session end + backgrounding)**: AD-13's lock-and-drop governs both units identically; the second trigger's absence from the log is the letter's choice, not a divergence.
- **Process death mid-session with pocket remaining** (ADV-8's second setup, re-checked): AD-19's revealed-not-awaited rule plus cause 3 (backgrounding ends the session before any OS kill) leaves one compliant behavior. Closed.
- **Capture precedence after the deal window with a closed slot**: FR-12's "no expiry" plus AD-20's re-resolve rule make the post-window capture ordinary material deterministically; no pair found.
- **Mixed-vintage `energy_set` inside a crossing session**: explicitly carved ("belongs to its own instant's domestic day regardless of session attribution"); cleared — the carve-out the skip lacked (ADV-13).

## Summary for triage

The update closed six of nine prior holes and added real machinery — the eighth event, the abandonment act, the session-day slot rule, the energy evaluation function, the store seal. Four high findings remain, and their shape is consistent: **the fixes were adopted verbatim without being reconciled with each other**. ADV-10 is ADV-5's fix text colliding with ADV-1's fix text inside one AD; ADV-11 is ADV-2's fix colliding with itself; ADV-12 is a new sentence (warmReturnDue) colliding with an old seal (AD-21's "one stated exception"); ADV-13 is an enumeration closed one noun too early. The mediums are tail-language: "persistence API", "session start", "malformed", "the latest", "the advance", "the chosen hour" — each a term two units can both obey and still differ. Eleven findings, each closable by a sentence or two of stated attribution; none requires re-architecture.

**Verdict: FAIL** — four high findings; the ADV-1 and ADV-2 amendments do not close what they claim.

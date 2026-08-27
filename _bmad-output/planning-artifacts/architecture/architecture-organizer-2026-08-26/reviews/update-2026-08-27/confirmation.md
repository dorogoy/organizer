---
lens: confirmation
reviewer: independent confirmation subagent (no prior context; second amendment round)
date: '2026-08-27'
target: ARCHITECTURE-SPINE.md (architecture-organizer-2026-08-26), status final, updated 2026-08-27 (second amendment round)
inputs: ARCHITECTURE-SPINE.md; reviews/update-2026-08-27/adversarial.md (ADV-10..ADV-20); reviews/update-2026-08-27/rubric.md (H-1..H-3, M-1..M-4, L-1..L-4); prd-organizer-2026-08-20/prd.md (targeted checks: FR-12, FR-31, §10.1)
verdict: ISSUES REMAIN
tally: { adversarial: '10 closed, 1 partial (ADV-12), 0 not closed', rubric: '11 closed, 0 partial, 0 not closed', 'new seams': '2 medium, 1 low', 'residuals below seam bar': 3 }
---

# Confirmation review — did the second amendment round close what it claims?

Method. For each Part A item: locate the amended text in the current spine, re-run the original two-unit construction, and apply the bar stated for this pass — an adversarial item is CLOSED only if **no both-compliant pair remains**. For Part B: attack only the seven named new-sentence groups; a NEW seam counts only with two letter-compliant units that build incompatibly. No whole-spine re-review; no style; pre-existing low/informational observations suppressed.

---

## Part A — Item-by-item verification

### Adversarial (ADV-10..ADV-20)

**ADV-10 — rescue chain vs plain `card_done` attribution. CLOSED.**
AD-20 now reads: *"The slot a `card_done` closes is **the day its dealing session belongs to (AD-19), and no other**"* and *"A completed rescue chain closes the slot of, and consumes rotation on, the day **the session that dealt its last `card_done` belongs to (AD-19)**, and no other — regardless of that day's energy."* The proposed tightening was adopted verbatim: both paths now carry one attribution rule (session-day). The ADV-10 setup (final step answered 04:05 in a session started 03:55) closes Day 1's slot on **both** readings; Day 2 gets its chunk on both. The act-day reading has no sentence left to cite. No surviving pair.

**ADV-11 — self-contradictory definition + unscoped anchor. CLOSED.**
The contradictory gloss ("not excluded at any session's start") is gone. AD-24 now states one definition — *"a domestic day on which at least one session started — by its start instant … — and at whose start at least one of that day's sessions found the item's size not excluded"* — explicitly *"evaluation stated once"*, and the anchor is day-scoped: *"the last `energy_set` **of that session's own domestic day** at or before its start instant, defaulting to 🟢 at the day boundary — yesterday's 🔴 never freezes today's windows."* Mixed-energy day (🟡 10:00, 🔴 21:00): the ∃ over session-starts yields *eligible* — one answer. Cross-day 🔴 (Mon 20:00, Tue 09:00 session): 🟢 default — one answer, matching AD-4's live rule, so the live/retrospective split no longer disagrees. No surviving pair. (A narrower edge of the new ∃ sentence is handled in Part B, NS-1 — it is a different pair, not the resurrected old one.)

**ADV-12 — `warmReturnDue` vs the reader seal. PARTIAL.**
The primary contradiction is closed exactly as proposed: AD-21 now enumerates **three stated exceptions** — `permissionMayBeAsked` from `permission_refused`, `warmReturnDue` from `app_opened` (FR-6, AD-24), and the validator surface's render of `export_recorded` — and AD-24 cross-references *"AD-21's second stated reader exception"*, which matches AD-21's ordering. The anchor pair (reads `app_opened` vs user-acts-only) is dead: no unit may anchor on acts alone against AD-24's letter. **What remains:** (1) the finding's AD-6 limb was not applied — AD-6 still says derived signals *"are inputs to `core/weave`, not outputs to the shell"* with no carve-out for a non-work **state** fact, so the Warm Return screen's path to the predicate still rests on reading AD-6's "derived signals" as not covering `warmReturnDue` (an unstated interpretation; `permissionMayBeAsked`, which must reach the ask-decision, shares the exposure). A unit refusing the crossing cites AD-6's letter; a unit crossing cites AD-21's exception — FR-6 fires on one build and is stranded on the other. (2) AD-17 (line 156) still says *"AD-21's **one** stated reader exception"* — now false on the document's own terms. Both are one sentence each; neither resurrects the original high-severity pair (AD-21 and AD-24 now point the same way).

**ADV-13 — `card_skipped` absent from the one-ledger enumeration. CLOSED.**
AD-19 now reads *"every `card_*` act of the session, **dealt, done or skipped**, chunk-class or not, plus occupancy and rotation — is **one ledger**, charged to the session's own day."* The 04:05 skip in a 03:40 session charges Day 1 on every reading; Day 1 is eligible (session started on it); the decline counter advances on both units. The carve-out pattern was not needed — inclusion settled it.

**ADV-14 — store seal names two adapters; no build satisfies the letter. CLOSED.**
AD-21's seal now reads *"no persistence API is touched outside the **Store, Folder and Files** adapters — Files owning app-private bytes (album images, the per-scan cache) — with the catalogue asset loaded once by a named shell loader onto the seal's allowlist and handed to the core as data"* plus the routing sentence *"Facts go through the Store, destination bytes through the Folder, private bytes through the Files adapter; no adapter-private store."* This is the proposed tightening verbatim, and it adds the routing sentence the rubric's H-3 asked for. A build now exists that satisfies the letter with no interpretation (route album/scan bytes through Files, catalogue through the named loader, facts through Store, SAF through Folder), so the no-satisfying-build defect and the carve-out divergence are both gone. Residual (below the seam bar, flagged in Part B): the conventions row (line 242) still describes the seal as *"no persistence API outside the Store and Folder adapters"* — a stale mirror — and the Structural Seed contains no Files adapter anywhere (port list, diagram, tree). Neither yields two divergent letter-compliant builds; both are one-line consistency fixes.

**ADV-15 — `scan_abandoned` tails. CLOSED.**
AD-8 now maps both departure causes: *"the user leaving the surface **or backgrounding the app** (recorded as `scan_abandoned` — the event for every non-completing resolution the user's departure caused)"*, and the backstop is re-anchored: *"a sweep of that directory at each `app_opened`."* The conventions row agrees (line 224). Both tails fixed with the proposed phrases.

**ADV-16 — "malformed" undefined. CLOSED.**
AD-13 now defines it: *"A record is **malformed** iff it fails to parse as JSON or a known kind lacks a field with no default — the two shapes the refusal exists for, and both in the property test's corpus."* Definition and corpus clause both applied. The one-row-refuses-everything vs silently-vanishes-act pair has no letter left to stand on.

**ADV-17 — rename order unspecified. CLOSED.**
AD-13 now states the protocol: *"renamed on completion, in the order **images → pool → log**: the log's rename is the export's commit point, and the import refuses any destination in which a temporary name remains — … never a mixed vintage."* With the log renaming last, every mid-rename crash state leaves at least one temporary name, so no mixed-vintage destination is restorable; the order divergence (log-first vs log-last) is now non-compliant on one side. A new tail created by the *applied variant* of this fix is reported in Part B (NS-2) — it is a different seam, not a re-opening.

**ADV-18 — "renders the latest" vs FR-30's tuple. CLOSED.**
AD-13 now reads *"the settings surface renders the **latest success and the latest failure with its cause**: two derivations over the entry stream, not one; **nothing else** observes it."* Exactly the proposed fix, with the no-other-observer clause as a bonus. (Also closes rubric L-3.)

**ADV-19 — "the advance" chunk-only vs everything-dealt. CLOSED.**
AD-19's ledger now reads *"every `card_*` act of the session, dealt, done or skipped, **chunk-class or not**"* — the proposed first alternative, applied. The 04:05 non-chunk completion charges the session's day on both units; the comfortable-day run counts identically.

**ADV-20 — invitation hour in an unnamed offset. CLOSED.**
AD-4 now reads: *"interpreted in the **local offset in force at each reschedule** — the invitation follows the user, not the zone the hour was set in — and the Kotlin half performs no date arithmetic of any kind, **boot reschedule included**."* Option A adopted verbatim; the 03:00-in-Mexico-City build is now non-compliant.

### Rubric (H-1..H-3, M-1..M-4, L-1..L-4)

**H-1 — session-energy lookup crosses the day boundary. CLOSED.**
AD-24 now bounds the lookup exactly as proposed: *"the last `energy_set` **of that session's own domestic day** at or before its start instant, defaulting to 🟢 at the day boundary."* The Monday-20:00-🔴 / Tuesday-09:00 case now yields 🟢 on both the live (AD-4) and retrospective (AD-24) paths; the two energy amendments agree at the first session of a day.

**H-2 — `warmReturnDue` vs the "one stated exception". CLOSED** (with one stale mirror noted).
AD-21 enumerates the exceptions (three — a superset of the two the fix required), naming `warmReturnDue` from `app_opened` and the validator surface's `export_recorded` render; the implementer trap (violate AD-21 or break FR-6) is gone. Residual: AD-17 line 156 still characterizes `permissionMayBeAsked` as *"AD-21's one stated reader exception"* — the exact stale-count phrasing this finding hunted, now living one AD over. It contradicts no implementer path (AD-21 governs its own seal), but it is false on the document's terms and should be updated to "first stated reader exception". Folded into ADV-12's remainder list.

**H-3 — SAF destination home + seal-scope contradiction. CLOSED.**
The proposed deciding sentence was adopted: AD-22 — *"it rides in `setting_changed` like any setting, the export redacts that one field, and the round-trip property excludes it from read-model identity — a capability cannot be replayed onto another install"* — mirrored in AD-13's property-test parenthetical (*"the SAF destination field is redacted from the exported log and excluded from read-model identity — AD-22"*), so the verbatim/round-trip contract now states its own exception in both places. The flat-ban vs seal-scope contradiction is resolved by the routing sentence (*"Facts go through the Store, destination bytes through the Folder, private bytes through the Files adapter; **no adapter-private store**"*). All four ADs (AD-1, AD-13, AD-21, AD-22) are now jointly satisfiable. (A minor divergence inside the redaction itself is Part B, NS-3.)

**M-1 — suffix taxonomy misses two of eight events. CLOSED.**
AD-21's suffix list now includes `*_declined` / `*_failed`: all eight enumerated events (`invitation_emitted`, `app_opened`, `consent_declined`, `face_refused`, `slice_failed`, `crash_recorded`, `permission_refused`, `export_recorded`) match the stated set.

**M-2 — "Every AD is enforced by a named guard" overclaim. CLOSED.**
The overclaim is replaced by *"Guards are named wherever one is nameable"*, and AD-4's native clause, AD-6's facade shape, AD-8's file lifecycle, AD-9's variant discipline, AD-11's channel scope and AD-26's reachability join AD-10/AD-18 in the *"core-test- and review-enforced"* list — the second of the two offered fixes, applied completely.

**M-3 — 🔴-day rescue rotation vs FR-31, override unrecorded. CLOSED.**
AD-20 now records it in the FR-7 pattern: *"regardless of that day's energy: **an override of FR-31's *a 🔴 day consumes nothing of the rotation*, recorded deliberately**, for a finishing chain is chosen work completing."* A story writer holding FR-31 now meets the override in the spine.

**M-4 — week-boundary curation over-scope. CLOSED.**
AD-16 now splits it: *"at the **next week boundary** for weekly zones — the rotation argument is theirs — and **immediately** for daily and `fondo` clusters, where FR-31's *simply never appear* governs; AD-20's fallback governs a below-floor remainder either way."* The first offered fix (scoping to the cadences whose rotation it protects), applied; the daily/`fondo` path now satisfies FR-31's letter outright.

**L-1 — API-37 projection asserted as fact in Deferred. CLOSED.**
The Deferred bullet now carries the parenthetical: *"Target 36 is compliant into 2027 (Play's posted floor; **the Aug-2027 date for 37 is a projection**)."* Both sites agree.

**L-2 — FR-20 bound by no AD. CLOSED.**
AD-26's Binds now opens *"FR-20, FR-22, FR-23, FR-26, FR-30, FR-32 …"* — both previously unbound FRs have an owning AD.

**L-3 — export-state tuple narrowed. CLOSED.** Same text as ADV-18: *"latest success and the latest failure with its cause."*

**L-4 — `Due`-suffixed facts vs the vocabulary ban. CLOSED.**
The forbidden-vocabulary row now states the decision: *"`Due` as a derived-fact suffix (`captureIsDue`, `warmReturnDue`) is outside the ban; a stored due-anything is not."* Both named predicates are covered by the carve-out; the ban's stored-anything core stands.

---

## Part B — New seams from this round's new sentences

Each of the seven named groups was attacked; a group is reported as a seam only where two letter-compliant units diverge.

### B-1. Three stated reader exceptions (AD-21) — no new seam

The enumeration is internally consistent and consistent with its consumers: AD-24's *"second stated reader exception"* matches AD-21's ordering; exception 3 (validator surface renders `export_recorded`) matches AD-13's observability clause and AD-26's *"validator surface is settings and nowhere else"*. Attacks on scope (who computes, who renders, which input) all collapse to one compliant behavior. The two live issues here are not new sentences' seams: the AD-6 state-fact crossing gap is ADV-12's unapplied limb (Part A), and the AD-17 stale phrase is a residual (below).

### B-2. Three-adapter store seal with Files (AD-21) — no new seam

The seal, routing sentence and loader allowlist admit one compliant routing (album/scan cache → Files; catalogue → named loader; facts → Store; SAF bytes → Folder). Attack angles tried: module placement of Files (unspecified — but placement divergence produces no incompatible builds, no rule cites the location); loader naming; export temp writes (Folder work); keystore access (an interpretive question of "persistence API" that predates this round's sentence and is out of scope here). Two residuals created by this round's edit, both below the seam bar, both one-line fixes:

- **R-1 (low).** Conventions line 242 still summarizes the seal as *"no persistence API outside the Store and Folder adapters"* — stale against AD-21's three-adapter text. A tool/ check written to the conventions mirror fails every AD-21-compliant build (its own included), so it self-corrects rather than diverging — but a guard description that contradicts the guard's definition is exactly the waiver trap ADV-14 warned about.
- **R-2 (low).** The Structural Seed — which the spine designates as the one place the port set and source layout are stated — contains no Files adapter (not in the port list, the diagram, or the tree). AD-21's Files adapter exists nowhere in the canonical layout.

### B-3. Day-scoped energy anchor (AD-24) — clean

The window `[session's own day start, session start]` is pinned by AD-19 (session belongs to its start instant's day) and AD-4 (half-open domestic days fix boundary instants); "at or before" is inclusive and deterministic; an `energy_set` after 04:00 inside a crossing session belongs to the crossed-into day by the existing carve-out, and a new session on that day finds it identically on both units. No pair found.

### B-4. The ∃-formulation of EligibleDay (AD-24) — **NS-1, NEW SEAM, medium**

**Seam:** AD-24's witness clause × item creation instant × FR-12/FR-5 (PRD: "the deal window advances only on days the capture was **actually eligible for dealing**"; §10.1 "within 3 eligible days of capture").

**Setup.** A 10–15 min capture created at 17:00. That day's sessions: 09:00 with energy 🟢 (set 08:55), 19:00 with energy 🔴 (set 16:00).

**Unit A — pure-size witness.** `EligibleDay(item, day)` evaluates `sizeExcluded(item.size, energyAt(session))` over *all* the day's sessions — the size is creation-immutable, so the 09:00 session is a valid ∃-witness: not excluded → **the creation day is eligible**; the capture's window and FR-5's counter may advance on it. This is the natural code the sentence writes.

**Unit B — existence-scoped witness.** A session cannot *"find the item's size not excluded"* for an item that did not exist at its start; the ∃ ranges over sessions at or after the creation instant. Only the 19:00 🔴 session is in range → excluded → **the creation day is ineligible**; the window starts one day later. PRD's "actually eligible for dealing" supports this reading's spirit.

Both are letter-compliant with AD-24's sentence (it never scopes the witness to the item's existence; "Item-level candidacy is deliberately excluded" excludes *candidacy* — the composition — not *existence*). **Failure:** identical logs, FR-12's window and FR-5's decline counter start a day apart; a rescue fires a day apart; the export's series differ — the ADV-2/ADV-11 failure class, on a narrower trigger (a friendlier-energy session earlier on the creation day than every session after creation).

**Severity: medium** — divergent builds over the two load-bearing freeze windows; narrower precondition than ADV-11 (which fired on every mixed day, by contradiction).
**Tightening:** one clause — *…at least one of that day's sessions **at or after the item's creation instant** found the item's size not excluded* (or: explicitly state that the witness is evaluated over all the day's sessions regardless of creation — either, stated).

### B-5. The images → pool → log commit protocol (AD-13) — **NS-2, NEW SEAM, medium**

**Seam:** the new refusal noun × the absent cleanup rule × AD-18's mid-window installs.

**Setup.** Tuesday's export crashes between renames: the log is still under its temporary name, which the protocol leaves in place — nothing in AD-13 says any run ever removes it. Friday's export succeeds (all its own temps renamed). The stale Tuesday temp is still in the destination.

**Unit A — refuse on any temporary name, never clean.** Implements the sentence literally; Friday's import **refuses** — the folder holds a temporary name — and keeps refusing until a human deletes a hidden file in their own folder. **Unit B — sweep the protocol's temporary names at export start.** Also letter-compliant (nothing forbids removing temporary names; the sweep is Folder work; "leaves the previous export intact" still holds); Friday's export heals the folder and the import succeeds. Cross-build, a second pair opens: no temporary-name *pattern* is stated, so a unit that refuses only its own build's pattern will import a destination another build crashed mid-write — the mixed vintage ADV-17 existed to kill, back through the naming gap.

Both units cite AD-13's letter; they diverge on whether a crashed destination is ever restorable again.

**Failure:** after any single mid-write crash, one build's restore path is permanently blocked (validation data unreachable from the only copy that matters) and the other's self-heals; across builds, silent mixed-vintage restore resurfaces.
**Severity: medium** — restore-path divergence; same stakes and rarity class as ADV-17, which this round's variant created while closing the original.
**Tightening:** state the pattern and the cleanup — e.g. *temporary names carry a fixed, versioned prefix; each export removes any name carrying that prefix before writing; the import refuses any file in the export structure that is neither a final artifact nor removable by that rule.*

### B-6. The SAF redaction (AD-22 / AD-13) — **NS-3, NEW SEAM, low**

**Seam:** the redaction's form is unspecified × import verbatim tolerance × the derived SETTINGS read model.

**Setup.** Export → wipe → import on a new install. AD-22: *"the export redacts that one field"* — as a null? an empty string? a marker? Unstated. The entry itself must ride (*"rides in `setting_changed` like any setting"*), so the row is present on import; AD-13's tolerance preserves a known kind verbatim.

**Unit A — redacts to empty.** The restored derivation sees no destination: the validator surface shows the destination unset, the next export asks for a folder — the behavior AD-22's own rationale ("a capability cannot be replayed onto another install") implies. **Unit B — redacts to a marker value.** The restored derivation carries the marker as the destination: the surface renders a dead string, and the next export fails against an invalid grant with a cause the validator must read as a mystery. Both are letter-compliant; the round-trip property cannot arbitrate because the field is *excluded from read-model identity* by design.

**Severity: low** — validator-facing, post-restore only, self-heals on re-pick or on the failed export's recorded cause; but it is a real two-unit divergence created by the new sentence.
**Tightening:** one clause — *the field is exported as empty, and an empty destination derives as unset* (pinning the form and the derivation in the same breath).

### B-7. The curation split, weekly vs immediate (AD-16) — clean

The three classes map one-to-one onto FR-31's three cadences (PRD line 491: daily / weekly zones / monthly-seasonal = `fondo`), so no cluster is unclassified; the classification input (the cadence field) is per-entry data, not interpretation. Effect timing is deterministic: weekly zones at the next Monday-anchored domestic-day boundary (AD-4), daily and `fondo` immediate; a change landing exactly on a boundary instant resolves by the half-open day interval. Below-floor remainders route to AD-20's fallback "either way," and the 28-deal rotation test runs on the default curation state, which no curation timing touches. Attacks on mid-week rotation ("the week of a disabled zone passes to the next active zone") converge: rotation recomputes over active clusters at the boundary on both units. No pair found.

### Residuals created by this round (below the seam bar; one line each)

- **R-1 (low):** Conventions line 242 describes the store seal as two-adapter ("Store and Folder") against AD-21's three-adapter text — stale mirror of the amended seal (see B-2).
- **R-2 (low):** The Files adapter appears in no port list, diagram, or directory of the Structural Seed, which the spine names as the single home of the port set and layout (see B-2).
- **R-3 (low):** AD-17 line 156 still reads "AD-21's **one** stated reader exception" against AD-21's "three stated exceptions" (see ADV-12/H-2).

---

## Tally and verdict

| Item | Verdict |
| --- | --- |
| ADV-10 | CLOSED |
| ADV-11 | CLOSED |
| ADV-12 | **PARTIAL** — AD-21's three-exception enumeration applied (primary pair dead); the finding's AD-6 limb (state-fact crossing for non-work surfaces) not applied, and AD-17's "one stated exception" mirror left stale |
| ADV-13 | CLOSED |
| ADV-14 | CLOSED (residuals R-1, R-2 — consistency only, no compliant pair) |
| ADV-15 | CLOSED |
| ADV-16 | CLOSED |
| ADV-17 | CLOSED (its applied variant opens NS-2) |
| ADV-18 | CLOSED |
| ADV-19 | CLOSED |
| ADV-20 | CLOSED |
| H-1 | CLOSED |
| H-2 | CLOSED (residual R-3) |
| H-3 | CLOSED (opens NS-3) |
| M-1 | CLOSED |
| M-2 | CLOSED |
| M-3 | CLOSED |
| M-4 | CLOSED |
| L-1 | CLOSED |
| L-2 | CLOSED |
| L-3 | CLOSED |
| L-4 | CLOSED |

**Part A: 21 of 22 closed, 1 partial (ADV-12), 0 not closed.**
**Part B new seams: NS-1 medium (EligibleDay pre-creation witness), NS-2 medium (temporary-name refusal — undefined noun, no cleanup), NS-3 low (SAF redaction form). Residuals R-1..R-3, low, below the seam bar.**

**Verdict: ISSUES REMAIN** — no high or critical finding survives, but one adversarial item is partially closed and the round's own new sentences opened two medium seams and one low seam, each closable by a clause.

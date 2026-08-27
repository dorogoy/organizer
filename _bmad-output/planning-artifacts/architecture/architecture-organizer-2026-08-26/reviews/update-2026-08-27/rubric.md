# Re-judge review — ARCHITECTURE-SPINE.md, update of 2026-08-27

Reviewer: independent subagent, no prior context. Inputs read in full: `ARCHITECTURE-SPINE.md` (376 lines, `updated: 2026-08-27`) and `prd.md` (653 lines, `updated: 2026-08-26`). Method: good-spine checklist — per-AD enforceability, cross-reference consistency (AD↔AD, conventions↔AD-21, guard inventory, ERD caption, tree comment, Binds lines), act-vocabulary completeness both directions, dimension coverage (decided/deferred/open), and whether the amendments closed or opened divergence holes. Every finding below was verified by re-reading the quoted passages. No style nits.

## Verdict

**PASS WITH FIXES.** The update closes most of what it aimed at (both-tables seal, Sunday-only report window, N+1 fixture, one-ledger advance, slot-ownership-to-session-day, atomic retire-set, eight-event enumeration with matching convention, six-entry tool/ inventory matching the tree comment). Three high-severity internal contradictions remain, two of them created or sharpened by this update's own amendments.

---

## Findings

### HIGH

#### H-1 — AD-24's session-energy lookup crosses the day boundary that AD-4 says energy never crosses

- **Location:** AD-4, line 70; AD-24, line 206; FR-12 consequence, prd.md line 247.
- **What is wrong:** The two energy amendments contradict each other at the first session of a day.
- **Evidence:** AD-4: *"Energy is day-scoped … the last `energy_set` of the current domestic day, defaulting to 🟢 at each day boundary and **never carried across one** … This rule governs the **live** pool only; retrospective predicates read energy per session (AD-24)."* AD-24: *"**'That day's energy'** at a session is the last `energy_set` at or before that session's start instant, defaulting to 🟢."* The AD-24 lookup is unbounded by the day. Concrete case: `energy_set` 🔴 Monday 20:00; session Tuesday 09:00 with no new check-in. Live pool (AD-4): 🟢 — Focus Chunks are dealt Tuesday morning. AD-24, literal: the session's energy is Monday's 🔴 → the 10–15 size is "excluded at the start of every session that day" → Tuesday is not an `EligibleDay`, and FR-12's capture window / FR-5's counter freeze on Tuesday. FR-12 freezes the window only on days the capture was *"actually eligible for dealing"* — and on Tuesday it was dealable (the live pool said 🟢). Two implementers, each literal, ship different counters — the exact divergence class AD-24's **Prevents** paragraph names (*"Two defensible definitions give a capture dealt on day 3 in one build and day 6 in the other"*). The `energy_set`-attribution clause in AD-24 (*"belongs to its own instant's domestic day"*) resolves attribution, not the lookup window, so it does not close this.
- **Fix:** Bound the lookup: "the last `energy_set` **of that session's domestic day** at or before the session's start instant, defaulting to 🟢 at the day boundary" — one clause, and the live and retrospective views stop disagreeing.

#### H-2 — `warmReturnDue` reads `app_opened`, which AD-21 permits no reader to do (the "one stated exception" is now two)

- **Location:** AD-21, line 185; AD-24, line 206; AD-17, line 156.
- **What is wrong:** The `warmReturnDue` amendment requires a user-facing derivation to consume a system event, while the AD-21 amendment declares exactly one reader exception and it is `permissionMayBeAsked`.
- **Evidence:** AD-21: system events *"are readable only by `core/export` and the FR-26 series — excluded from every user-facing derivation by construction, with **one stated exception**: the core derives `permissionMayBeAsked(permission)` from `permission_refused`."* AD-24: *"One sibling predicate serves FR-6: `warmReturnDue` — 48 h wall-clock since the later of the last `app_opened` and the last user act."* FR-6 is the Warm Return welcome-back screen — the definition of a user-facing derivation — and the predicate lives in `core/derive`, not `core/export` and not the FR-26 series. An implementer must either violate AD-21 ("by construction") or make FR-6 unimplementable. Note the enumeration of `app_opened` itself is fine; FR-26 series (d) reading it is legal. Only `warmReturnDue` is caught.
- **Fix:** Name the second exception where the first is named ("…with two stated exceptions: `permissionMayBeAsked` from `permission_refused`, and `warmReturnDue` from `app_opened`"), or route the Warm-Return trigger through a fact the shell may read.

#### H-3 — The SAF destination URI has no home that satisfies AD-1 + AD-13 + AD-21 + AD-22 jointly; and AD-21's flat store ban contradicts its own seal's scope

- **Location:** AD-1, line 44; AD-13, lines 126–132; AD-21, line 185; AD-22, line 191; Stack `saf_util` row, line 257.
- **What is wrong:** FR-30's persisted export destination must be durably stored somewhere, and every candidate location breaks one AD.
- **Evidence:** AD-1: *"`SETTINGS` is a derived cache over `setting_changed` events"* — so the destination URI rides in the log. AD-13: *"`AUTHORITATIVE/` holds the log … and nothing else"* and the round-trip test *"asserts every derived read model is identical"* — so the log, URI included, is exported verbatim. AD-22: *"The SAF destination is a capability grant rather than a value: **the persisted URI is not exported**."* Contradiction: if the URI is in `setting_changed`, it is in the export; redacting it breaks AD-13's verbatim/round-trip identity for the SETTINGS read model; keeping it out of the log requires state outside the pool and log, which AD-1 (*"no mutable record anywhere"*) and AD-21 (*"**No other store exists**: no preferences, no side files, nothing outside the pool and the log"*) forbid. Compounding it, AD-21's new seal states a different scope than the flat sentence beside it: *"no persistence API is touched **outside the Store and Folder adapters**"* — which *licenses* an adapter-internal store the flat sentence bans. The 2026-08-27 seal wording sharpened this: pre-update it was a tension; now the document states both the ban and the permission in one sentence. (The same flat sentence is literally falsified by AD-8's two scan-cache files and the album bytes; those are defensible as transient/blobs, but the URI is durable state.)
- **Fix:** One sentence decides it, e.g.: the destination lives in `setting_changed`; the export redacts that one field; the round-trip property excludes the destination from read-model identity (it cannot replay across installs anyway — AD-22 already says why). And make the flat sentence and the seal state the same scope (blobs through Folder, facts through Store, no adapter-private stores — or name the exception).

### MEDIUM

#### M-1 — AD-21's system-event suffix taxonomy misses two of its own eight events

- **Location:** AD-21, line 185.
- **Evidence:** *"System events are named `*_emitted` / `*_refused` / `*_observed` / `*_recorded` / `*_opened`"* — then the enumeration includes **`consent_declined`** and **`slice_failed`**, which match none of the five suffixes. (The conventions row, line 225, separately licenses `slice_failed` via the "`failed` in exactly two places" rule, but the AD-21 sentence is self-inconsistent on its own terms.) Any lint or review check built on the stated suffix set fails 2 of the 8 enumerated events. The `_opened` addition fixed `app_opened` and left these two behind. Add `*_declined` / `*_failed` to the suffix list (or mark them as the two named exceptions).

#### M-2 — "Every AD is enforced by a named guard" is an overclaim

- **Location:** Conventions "Testing — the core", line 240.
- **Evidence:** The row asserts *"Every AD is enforced by a named guard — a trigger, a `tool/` check, a lint or a test; AD-10's … and AD-18's … are review-enforced, and say so."* Named guards exist for AD-2, 3, 5, 7, 13, 15, 16, 21, 22, 23 — but none is named anywhere for **AD-4** (nothing bans date arithmetic outside `Calendar`; the *"including native code"* clause is unguardable by any listed mechanism and can only be review), **AD-6** (widget tests exercise consumers of the facade, not the no-collection ban), **AD-8** (the unlink/sweep lifecycle is testable but unnamed), **AD-9**, **AD-11**, and **AD-26** (the three-tap reachability property is manual-only). Either name the guards (a `DateTime`-arithmetic lint for AD-4 would be cheap) or add them to the review-enforced list with AD-10/AD-18 — as written, the inventory's completeness claim is false.

#### M-3 — AD-20's 🔴-day rescue-chain rotation consumption contradicts FR-31's letter, and the override is not recorded (unlike FR-7's)

- **Location:** AD-20, line 175; FR-31, prd.md line 494.
- **Evidence:** AD-20: *"A completed rescue chain closes the slot of, and consumes rotation on, the day of its **last** `card_done`, **regardless of that day's energy**."* FR-31: *"A 🔴 day deals no Focus Chunk at all (FR-4) and **consumes nothing of the rotation**."* A rescue chain finishing on a 🔴 day (rescue steps are ≤ 60 s, so they are dealable there) consumes rotation under AD-20 and must consume nothing under FR-31. The spine handles the analogous FR-7 "dealt" clash by naming it — *"an override recorded deliberately"* — but this one is decided silently. A story writer holding only FR-31 builds the other behavior. Record it as an override against FR-31's sentence, or reconcile the two.

#### M-4 — AD-16's week-boundary curation rule conflicts with FR-31's "simply never appear" and over-scopes its own rationale to daily clusters

- **Location:** AD-16, line 150; FR-31, prd.md line 499.
- **Evidence:** AD-16: *"Cluster curation changes take effect at the **next week boundary**, never mid-week — the current week's rotation stands."* FR-31: *"A disabled cluster's tasks **simply never appear**."* Under AD-16, disabling a cluster on Tuesday keeps its tasks dealing until Monday — visible behavior that contradicts the FR consequence's letter, with no override recorded. The deferral rationale is rotation (weekly zone churn), yet the rule is stated unqualified: it also defers **daily** and **`fondo`** clusters, where no rotation argument applies and immediate effect is the natural reading. Two builds, mid-week, visibly diverge — exactly the hole class the spine exists to close. Scope the deferral to cadences whose rotation it protects, or record the override against FR-31's sentence.

### LOW

#### L-1 — The API-37 softening was applied to the Stack row but not to the Deferred bullet

- **Location:** Stack, line 251 vs Deferred, line 372.
- **Evidence:** Stack: *"the Aug-2027 date for 37 is **a projection**"*; Deferred: *"Target 36 is compliant until Aug 2027"* — asserted as fact. The update fixed one site and left the other asserting the projection.

#### L-2 — FR-20 is bound by no AD (FR-22 only by a conventions parenthetical)

- **Location:** All `Binds:` lines, AD-1…AD-26.
- **Evidence:** Scanned every Binds line: FR-20 appears in none; FR-22 appears only in the `item_triaged` convention (line 224, "never a number, FR-22") and implicitly under AD-26's "liberated volume". Their substance is covered (copy via AD-15's whole-ARB audit, the triage act and metric via conventions, homes via the Capability Map), but the header binds FR-1…FR-32 while the ADs bind all others; FR-20 is the one FR with no owning AD. Cosmetic-to-low: add it to AD-15's or the conventions' Binds, or accept and note.

#### L-3 — AD-13 "renders the latest" is narrower than FR-30's export-state tuple

- **Location:** AD-13, line 130; FR-30, prd.md line 404.
- **Evidence:** FR-30: *"Export state — destination, **last success, last failure and its cause** — is readable in settings only."* AD-13: *"the settings surface renders **the latest**"* — one entry, not last-success-and-last-failure. The log holds every outcome, so the data exists; the rendering rule as worded drops the "last success after a failure" case. One clause fixes it ("renders the latest success and the latest failure with cause").

#### L-4 — `warmReturnDue` and `captureIsDue` mint "Due" while the conventions ban due-flavoured identifiers

- **Location:** Conventions forbidden-vocabulary row, line 225; AD-24 line 206 (`warmReturnDue` — new in this update); AD-6 line 84 (`captureIsDue`).
- **Evidence:** The banned token list (`dueDate`, `pending`, `overdue`, …) does not substring-match either name, so the lint as specified will not fire — but the row's stated purpose (*"the next person to touch the schema will not have read §1.1"*) is spirit-level, and the same document bans `dueDate` and mints two `Due`-suffixed facts, one of them in this update. Decide once: either "Due" as a fact-suffix is explicitly outside the ban, or rename (`warmReturnPending` is worse; `warmReturnElapsed` is not).

---

## Checked and clean (amendments and cross-references verified consistent)

- **AD-2 both-tables seal:** consistent with AD-1 (two shapes), AD-14 (origin immutability "structural"), AD-25 (retirement is derivation, not deletion), AD-23 (rows never deleted, kinds retired by ceasing to write). No product path needs an UPDATE or DELETE — album purge unlinks files (AD-13), capture discard precedes the pool fact (FR-27). Guard named (triggers; Stack drift row lines up: `.drift` file, initial migration).
- **AD-4 SM-2 window:** "that Sunday only, expires at the week boundary" is the correct reading of PRD SM-2's "first opening from Sunday onward, persisting until answered that week" under Monday-anchored weeks; `report_answered` exists in conventions.
- **AD-13 import/N+1:** tolerance rule matches AD-23 verbatim (unknown kinds preserved, refusal reserved for structural corruption); N+1 fixture is the testable form of AD-18's ritual; `export_recorded` enumeration, settings-only rendering, and "nothing else observes it" are mutually consistent with FR-30 and AD-26.
- **AD-19 one-ledger advance:** "charged to the session's own day" ↔ AD-20's "slot a `card_done` closes is the day its dealing session belongs to" — the cross-references agree in both directions; the three close causes leave no uncovered path (pocket elapsing while backgrounded is pre-empted by cause 3); FR-3's early close correctly folded into cause 1; process-death handling states its rule.
- **AD-21 vs conventions:** the eight enumerated events match the conventions' "the eight enumerated in AD-21" exactly; `scan_abandoned` is consistently a user act (AD-8's cause + FR-26 (b) denominator), and every act named in any AD appears in the conventions, and vice versa — the act vocabulary is complete in both directions (verified event by event).
- **Guard inventory count:** the six named `tool/` entries (purity, egress seal, strings, floor, id-diff, store seal) match the tree comment "the six build-time checks"; the egress seal's three sub-checks are stated identically in both places. (The completeness *claim* is M-2; the count is consistent.)
- **ERD caption vs ADs:** all eight classification claims check out against AD-1/2/13/16/19/25; `ORIGIN_CONTEXT ||--o|` optionality is right (shipped items have none); album-Epic link optionality matches FR-17's "session or project milestone".
- **Stack:** ML Kit 32/64-bit wording and `abiFilters` consequence are internally consistent; the API-37 projection softening is right in the Stack row (see L-1 for the leftover); `flutter_secure_storage` cipher configuration is consistent with AD-22/FR-28 (the store-seal scope question is folded into H-3).
- **Dimensions:** every PRD open question is either closed in the PRD itself, decided by an AD (OQ-5 storage/export format, OQ-8 alarm, OQ-10 allowlist, OQ-1 topology → Deferred), or routed to UX in Deferred; the genuinely silent corners are H-1/H-3 above, not a missing section.

## Severity summary

| Severity | Count |
| --- | --- |
| Critical | 0 |
| High | 3 |
| Medium | 4 |
| Low | 4 |
| **Total** | **11** |

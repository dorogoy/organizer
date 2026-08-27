# Architecture Spine Review — Good-Spine Checklist

- **Reviewer:** independent review subagent (no prior project context)
- **Date:** 2026-08-27
- **Inputs read in full:** `ARCHITECTURE-SPINE.md` (373 lines), `prd.md` (653 lines), `addendum.md` (307 lines)
- **Mode:** research + writing only; the spine was not modified

## Verdict

**PASS WITH FIXES** — 9 findings: **0 critical, 0 high, 3 medium, 6 low**. The spine is strong: divergence coverage for FR-1..FR-32, SM-* and §7 is essentially complete, the Deferred list contains no divergence hazards, the operational envelope (deployment, infra, operations), security and error handling are decided rather than silent, and the cross-reference web (AD↔AD, conventions ↔ ADs, Stack ↔ ADs, diagram ↔ tree, PRD A12 arithmetic ↔ AD-16) checks out almost everywhere. The three medium findings are all in one family: **rules whose enforcement is asserted but not actually wired** — pool-fact immutability, the "no fourth store" ban, and an ER seed that contradicts the derivation rulings it sits next to. All three are cheap fixes that stay inside the spine's own idiom (extend the trigger seal, add one guard to `tool/`, caption the ERD).

## Findings summary

| # | Severity | Location | Finding |
|---|---|---|---|
| F1 | Medium | AD-2 (L50), AD-14 (L137), AD-25 (L210) | Pool-fact immutability is asserted but structurally unenforced; AD-14 cites AD-2 for a guarantee AD-2 does not give |
| F2 | Medium | Structural Seed ERD (L307–317) vs AD-13 (L126), AD-16 (L149), AD-21 | ER diagram contradicts the derivation rulings for the album and leaves the storage status of `ALBUM_ENTRY`, `QUARANTINE_BOX`, `CATALOGUE_ENTRY` ambiguous |
| F3 | Medium | AD-21 (L182–183), AD-22 (L189), Conventions (L238–239) | "No other store exists" has no named guard; the guard inventory is also internally loose (five checks vs AD-7's three; AD-22's CI grep unlisted; "every AD has a test" over-claims) |
| F4 | Low | AD-21 (L183) | `app_opened` violates AD-21's own system-event naming pattern |
| F5 | Low | AD-21 (L183) vs AD-17 (L155) | System events "readable only by `core/export` and the FR-26 series" leaves `permission_refused`'s never-ask-again consumer with no legal home |
| F6 | Low | AD-20 (L172–175) vs PRD FR-7 (prd L192) | AD-20 silently rewrites FR-7's "once the Focus Chunk **has been dealt**" into answered-`Hecho` occupancy without recording the override |
| F7 | Low | AD-1 (L44) vs PRD §10.1 (prd L595) | Warm Return trigger ("≥ 48 h of absence") has no architectural definition — absence from what, measured how |
| F8 | Low | core/weave; PRD FR-11 (prd L232–233) | Residual weave-arbitration ambiguities: multiple simultaneously active Epics; effect of mid-week cluster curation on the current week's active zone |
| F9 | Low | Conventions — Testing (L238–239) | Shell/UI test strategy is silent at an altitude that owns the whole build |

---

## 1. Does it fix the real divergence points and miss none? (checklist Q1)

### FR walk (all have an architectural home)

| Feature group | Home / deciding ADs | Verdict |
|---|---|---|
| FR-1 single card | AD-6 (read facade exposes no collection; `nextCard()` ≤ 1 card), AD-26; cap. map 4.1 | covered |
| FR-2 Done, <500 ms | AD-3 (deal written by command); conventions Testing asserts ≤ 500 ms over the derivation | covered |
| FR-3 guilt-free skip | AD-3 (skip-on-a-day = `card_skipped`), AD-20 (skip re-resolves, consumes no rotation) | covered |
| FR-4 energy | AD-4 (day-scoped `energy_set`, daily 🟢 reset — a decision on a point the PRD leaves open, addendum A5), AD-20 (🔴 exclusion as candidate rule) | covered |
| FR-5 Rescue | AD-3 (3-different-days counting), AD-14 (origin inheritance), AD-20 (depth cap 1), AD-24, AD-25 (dissolution, no synthetic completion) | covered |
| FR-6 Warm Return | AD-1 L44 ("needs no path of its own" — derivation), AD-24 machinery adjacent | **gap → F7**: the ≥48 h trigger computation itself is undefined |
| FR-7 Time Bag | AD-1 (settings derived), AD-20 (mid-day change re-resolves; occupancy bounds advance) | covered (but see F6 on the dealt/done letter) |
| FR-8 pocket session | AD-19 (declared pocket) | covered |
| FR-9 pause/recalc | AD-1 + AD-19 (log is truth; nothing holds session state; rollback is derivation) | covered |
| FR-10 checkpoint | AD-19 (`session_extended`, original-pocket rule for FR-23) | covered |
| FR-11 dual lifecycle | AD-7 (genesis payload), AD-9, AD-14; capability 4.3 | covered (residuals → F8) |
| FR-12 1-3-5 weaving | AD-20 (one resolver, occupancy vs identity, capture precedence, `fondo` fallback), AD-24, AD-19 | covered — this is the spine's best AD |
| FR-13 buffers | AD-1 (buffered target is a pure function; nothing stored) | covered |
| FR-14 Silent Rescheduler | AD-1 ("not code" — nothing assigned, nothing to replan) | covered |
| FR-15 seasonal | AD-4 (Season = meteorological quarter, domestic-day anchored; the PRD never defined "season"), `suggestion_dismissed` in vocabulary | covered |
| FR-16 photo scan | AD-7, AD-8, AD-11 (camera via plugin), capability 4.4 | covered |
| FR-17 before/after | ERD: album↔Epic link optional both sides, reasoned against FR-17's milestone reward | covered |
| FR-18 album | AD-13 (derived manifest, unlink semantics, purge) | covered (but see F2) |
| FR-19 purge injection | AD-20 (returns candidates with precedence) | covered |
| FR-20 triage | `item_triaged` conventions row (coarse volume tag, never a number — FR-22 honored) | covered |
| FR-21 Quarantine Box | `box_created` act; ERD entity | **thin → F2**: follow-up derivation home unstated |
| FR-22 declutter metric | AD-26 (achievement figures, denominator rule) | covered |
| FR-23 dashboard/snowball | AD-1, AD-19 (original pocket), AD-26 | covered |
| FR-24 invitation | AD-4 (absolute instant only), AD-11 (channel), AD-17 (inexact alarm, one per domestic day, boot reschedule), AD-21 (`invitation_emitted`) | covered — exemplary |
| FR-25 consent | AD-8 (single-use token, cache lifecycle), AD-7 (resolution cap), AD-10 | covered |
| FR-26 instrumentation | AD-21 (system events incl. series (b)/(d) needs), AD-13 (derived half), AD-25, AD-14 | covered |
| FR-27 Manual Capture | AD-6, AD-14, AD-24 (deal window over one eligible-day predicate) | covered |
| FR-28 access path | AD-9, AD-10, AD-22 | covered |
| FR-29 degradation | AD-15 (seven strings pinned by key + sign-off), conventions State—errors (state chosen in the core) | covered |
| FR-30 export | AD-13 (halves, atomicity, torn-case property test), AD-17, AD-18, AD-22, AD-26 | covered |
| FR-31 Evergreen | AD-16 (asset + two checks), AD-20 (sub-floor fallback), AD-23 (permanent ids) | covered |
| FR-32 dictation | AD-11 (recognizer + Spanish-model gate), AD-17 (RECORD_AUDIO at first use), AD-26, conventions dictation-boolean row | covered |

### SM walk

- **SM-1** — AD-4 (domestic day), AD-19 (session), AD-23 (upgrade safety). Covered. (Cosmetic: SM-3 is the one bound metric appearing in no AD's `Binds:` line; its real homes are AD-19's "no app-initiated continuation" and AD-20's slot reservation.)
- **SM-2** — AD-4's Monday-anchored week explicitly absorbs SM-2's "first opening from Sunday onward" edge; `report_answered` in vocabulary. Covered.
- **SM-3** — see above; covered substantively.
- **SM-4** — AD-14 (immutable origin, rescue inheritance — the exact SM-4 mechanism). Covered.
- **SM-C1** — AD-25 (counts user acts only), AD-26. Covered.
- **SM-C2** — AD-15 (audit list = every ARB key minus reviewed exclusions; silence adds to the audit). Covered.
- **SM-C3** — AD-21 + AD-12 (`invitation_emitted`, `app_opened`; "the only test the PRD gives it"). Covered.

### §7 walk

Offline-by-default (AD-7 seals); local-first durability (AD-13, incl. the no-nag observability rule); settings/Dispenser split (AD-26); egress map (AD-7's three payloads match §7 verbatim; audio-nowhere via AD-11's on-device-only channel design); latency budget (conventions Testing); accessibility 200% (text-scaling lint row); copy-is-the-surface (AD-15); background minimalism (AD-17); no-overdue (AD-1/AD-2 + forbidden-vocabulary lint); single-user (Deferred); no-account (AD-9/AD-10). All ratified — see §6 below for the two refinements.

**Result:** two low coverage gaps (F7, F8). No feature group is homeless.

## 2. Is every AD's Rule enforceable, and does it prevent its stated divergence? (checklist Q2)

AD-by-AD audit, condensed:

- **Structurally enforced (CI/tool/DB):** AD-2 (SQL triggers), AD-3 (purity check), AD-5 (dep check + sealed core), AD-7 (three seals), AD-8 (type-state token — compile-time), AD-15 (lint + key-pinned build check), AD-16 (two checks), AD-17 (manifest allowlist), AD-22 (fixture grep), AD-23 (id-diff tool check).
- **Test-enforced:** AD-13 (property test incl. torn case), AD-19, AD-20, AD-24, AD-25 (via core API surface), AD-4 (Calendar as sole converter; native side reviewable against "computes no dates").
- **Review-enforced but concrete and falsifiable:** AD-6 (absence of a forbidden signature is checkable by reading the facade), AD-9, AD-10, AD-11 (named OS APIs), AD-26.
- **Enforcement gaps → findings:** AD-1/AD-14/AD-25 (**F1**: pool-fact immutability has no trigger or check; AD-14 L137 claims "AD-2 makes that structural," but AD-2 L50 scopes its triggers to "the log table" only). AD-21 (**F3**: "No other store exists" (L183) — no guard named; AD-21's own Prevents (L182) proves the failure is invisible to the round-trip test, which is precisely the situation where the spine elsewhere insists on a check, not an intention).

No AD is pure aspiration: every Rule is at least falsifiable. The gaps are missing wiring, not unenforceable prose.

## 3. Could anything under Deferred let two units diverge? (checklist Q3)

No findings. Checked each: OQ-1 topology (AD-9 pins it as configuration; stub is debug-only, and AD-18 bans debug variants on handsets); log growth (revisit trigger named; projection stays AD-1-compatible); multi-user (no owner column — a schema fact, not an ambiguous default); iOS (explicitly not designed toward); screen-reader semantics — the one real divergence hazard in principle — is defused by the interim convention (L237: no custom semantics, platform traversal); API 37; the three fragile dependencies (promotion rule = AD-11's test); design tokens (hand-transcribed once, tokens.dart single source); second locale (ARB, AD-16); UX copy questions (AD-15 gates the strings at build time). Nothing deferred is a decision two stories would have to make independently.

## 4. Is every owned dimension decided, deferred, or an open question? (checklist Q4)

- **Deployment & environments:** decided — AD-18 (same-keystore install-on-top, export/import ritual, no store, debug-variant ban), Stack (minSdk 33 / target 36 with reasons).
- **Infra/provider strategy:** decided — AD-9/AD-10 (BYOK allowlist, compile-time constant), Local/Managed deferred via OQ-1 with the interface pinned.
- **Operations:** decided for a no-backend build — crash visibility via `crash_recorded` in the export (AD-12), update path = restore path (AD-18), log-growth revisit trigger (Deferred).
- **Security:** decided — consent (AD-8), secrets (AD-22, incl. the keystore cipher configuration in the Stack note), provider terms (AD-10), egress seals (AD-7).
- **Error handling:** decided — conventions State—errors (one calm surface; the core chooses the state), FR-29's seven states, export failure surfaced to settings only (AD-13), migration failure → import (AD-18).
- **Testing strategy:** core fully decided (conventions Testing rows); **shell/UI testing is silent → F9** (low).

## 5. Internal consistency (checklist Q5)

**Verified consistent (checked, no finding):**

- **AD citations inside ADs:** every cross-reference resolves and matches its target's content — AD-13's "AD-7's no-queue rule" (AD-7 L90 "never queues, never retries"); AD-13's "AD-17's two triggers" (session end + backgrounding, L155); AD-11's "AD-7's three seals" and "compute no dates (AD-4)"; AD-16's citations of AD-3's tie-break, AD-23's continuity, AD-20's fallback; AD-2's "(AD-13 owns the bytes)". The one broken citation is inside AD-14 (**F1**).
- **Act vocabulary (conventions L222) vs AD-21's seven system events:** exact match, seven of seven (`invitation_emitted`, `app_opened`, `consent_declined`, `face_refused`, `slice_failed`, `crash_recorded`, `permission_refused`); user-act list covers every event named anywhere in the ADs (`session_extended` ← AD-19, `card_skipped` ← AD-3, `item_triaged` ← FR-20/22, `report_answered` ← SM-2, `epic_activated` ← FR-19, …). One pattern violation (**F4**).
- **Ports: diagram (L273–278) vs tree (L327):** Store · Slicer · Clock · Notifier · Recognizer · Folder — identical, adapters match one-to-one (store/, egress/, plugins/, platform/notify, platform/dictate, plugins/saf_*).
- **Stack vs ADs:** drift trigger note ↔ AD-2; minSdk 33 rationale ↔ AD-11/AD-17 (`POST_NOTIFICATIONS`, `checkRecognitionSupport`); `flutter_secure_storage` cipher note ↔ AD-22/FR-28; `flutter_local_notifications` deliberately unused ↔ AD-11; Gemma 3.66 GB ↔ Deferred OQ-1 and addendum A2.
- **Arithmetic:** AD-16's "disable one zone plus `coche` and the pool sits at the line" is exactly right against addendum A12 (20 weekly eligible + 12 `fondo` = 32; a 3-entry zone + 1 `coche` = 28 = floor).
- **Binds lines** spot-checked against content; frontmatter `binds` matches what the ADs actually consume.

**Findings from this section:** F2 (ERD vs AD-13/AD-16), F4 (naming pattern), F5 (readability rule vs AD-17), plus the count mismatches folded into F3: conventions L239 claims "five build-time checks" while AD-7 L90 says "**Three checks seal it, not one**" (five bundles = seven checks), AD-22's fixture grep (L189) appears in no guard inventory, and L238's "Every AD above has a test that fails when it is broken" is untrue as written for AD-18 (signing/ritual) and AD-10 (terms copy).

## 6. Does it ratify its inputs' constraints? (checklist Q6)

§7 spot-checks all pass (see §1 walk). Three deviations found, all examined:

- **F6 (low):** AD-20 (L174) rules "at most one Focus Chunk is ever **answered `Hecho`** in a day; … only a `card_done` — or a completed rescue chain — closes the slot," while PRD FR-7 (L192) says "once the day's Focus Chunk **has been dealt** — or its rescue steps — later sessions that day compose of upkeep and habits only." AD-20's Prevents (L172) explicitly frames the FR-7-literal reading ("silently spends the day's advance on work the user declined") as the failure it exists to stop — a deliberate, principle-grounded override (and the PRD's own §1.1 says the principle wins over the FR). But the PRD's discipline for exactly this situation (E1/E2: "an invariant that overrides FRs cannot be bent without the bend being written down") asks the spine to name the FR-7 sentence it is amending. It doesn't.
- **Noted, not findings (deliberate, justified amendments):** (a) AD-16 gives catalogue entries **four** fields where FR-31 (L492) says "three fields and no more" — the added permanent id is required by AD-3/AD-23/AD-15 and stated with its rationale inline; (b) AD-17 refines FR-24's "at most one per 24 h" to once per domestic day, with the 03:30-straddle reasoning stated; (c) AD-4's daily 🟢 energy reset decides a point addendum A5 records as UX-open, and decides only the scoping (architectural), not the decay (left to UX).

---

## Finding detail

### F1 — Pool-fact immutability asserted but not sealed; AD-14 over-cites AD-2 (Medium)

- **Where:** AD-2 L50; AD-14 L137; AD-25 L210.
- **What:** AD-2's insert-only seal is scoped to "the log table." Pool facts — which AD-1 (L44) makes one of the only two persisted shapes, and which carry AD-14's immutable `origin` — have no trigger, check, or named guard against `UPDATE`/`DELETE`. AD-14 claims "written once at creation and never updated (**AD-2 makes that structural**)" for pool items, which AD-2 does not. AD-25's "**No tombstone is stored** and no synthetic completion is ever appended" rests on discipline, and AD-13's round-trip test cannot catch the tempting violation (hard-deleting a dissolved item's pool row and deriving retirement produce identical read models and identical exports), so the cheap wrong implementation passes every named guard.
- **Why it matters:** this is the exact failure shape AD-2 exists to prevent ("SQLite puts UPDATE and DELETE one keyword away"), left open on the second of the two tables the substrate rests on.
- **Fix direction:** extend the insert-only triggers to pool facts (same `.drift` mechanism, per the Stack note), or name an equivalent check — and correct AD-14's citation.

### F2 — ER seed contradicts the derivation rulings beside it (Medium)

- **Where:** Structural Seed ERD L307–317 vs AD-13 L126, AD-16 L149, AD-21.
- **What:** the ERD caption (L317) states the derivation discipline as "SETTINGS, SESSION and pool membership are all derived and **appear as no entity**" — implying the entities drawn are stored. But: `ALBUM_ENTRY` (L313) is drawn as an entity although AD-13 (L126) rules the album manifest **derived** (an album table is precisely the "delete by removing a row" divergence AD-13's Prevents names); `CATALOGUE_ENTRY` (L308) is drawn as an entity although AD-16 (L149) rules the catalogue a read-only build-time asset that must never become "a database the user could reach"; `QUARANTINE_BOX` (L314) has no stated storage home at all — its follow-up semantics (once-per-box, 6-month blind timer) are reconstructible from `box_created` + `item_triaged` + `suggestion_dismissed`, but nothing says so, and the natural reading of the ERD is a `quarantine_box` table with a date column — adjacent to AD-1's "no table, column or field may name a future assignment."
- **Why it matters:** the Structural Seed is what a story implementer reads first; here it points opposite to three ADs.
- **Fix direction:** one caption sentence classifying each entity (stored pool fact / log-reconstructible / build-time asset), and a line stating the box's follow-up is derived from `box_created`'s instant, never a stored date.

### F3 — "No other store exists" has no guard, and the guard inventory is loose (Medium)

- **Where:** AD-21 L182–183; AD-22 L189; Conventions L238–239; tree L340.
- **What:** three connected defects. (1) AD-21's "**No other store exists**: no preferences, no side files, nothing outside the pool and the log" — the rule that makes every system event exportable and every third-store drift impossible — is enforced by nothing: it is not among the five `tool/` checks, not a lint, not a test. AD-21's own Prevents paragraph (L182) demonstrates the failure is invisible to AD-13's round-trip (a `SharedPreferences` flag for, e.g., onboarding-done passes everything), which is precisely the "discipline decays" argument AD-2 makes for triggers. (2) Conventions L239 claims "five build-time checks" while AD-7 L90 insists its seal is "**Three checks seal it, not one**" — five bundles, seven checks; and AD-22's export-fixture CI grep (L189) appears in no inventory. (3) L238's "Every AD above has a test that fails when it is broken" is false for AD-18 (keystore/release ritual) and AD-10 (terms copy) as written.
- **Fix direction:** add a store seal to `tool/` (e.g., no persistence API touched outside the Store/Folder adapters — the same shape as AD-7's import seal); recount the checks honestly; place AD-22's grep; soften "every AD has a test" to match the guards that exist.

### F4 — `app_opened` breaks AD-21's own naming pattern (Low)

- **Where:** AD-21 L183.
- **What:** "System events are named `*_emitted` / `*_refused` / `*_observed` / `*_recorded`" — `app_opened` matches none of the four suffixes, in the very sentence that enumerates it. The vocabulary elsewhere is exhaustively patterned; this is the one off-pattern name, and a future story adding system events will treat the pattern (or the example) as the rule.
- **Fix direction:** rename (`app_open_observed` or similar) or add `_opened` to the sanctioned suffix list — either, stated once.

### F5 — `permission_refused`'s only operational reader has no legal home (Low)

- **Where:** AD-21 L183 vs AD-17 L155.
- **What:** AD-17 requires that a refused permission "is never asked again," recorded as `permission_refused` so it survives restore. AD-21 scopes system events as "readable only by `core/export` and the FR-26 series — excluded from every user-facing derivation by construction." The permission gate is neither: it is shell behavior that must consume the event (or a derived fact the letter does not permit `core/derive` to expose from system events). As written, two units resolve it differently — one reads the raw event from the shell, the other invents a derived fact of unstated legality.
- **Fix direction:** one clause — e.g., the core derives a `permissionMayBeAsked(port)` fact from `permission_refused`, named as an exception to the readability rule.

### F6 — AD-20 amends FR-7's letter without recording the bend (Low)

- **Where:** AD-20 L172–175 vs PRD FR-7 (prd L192).
- **What:** FR-7: "once the day's Focus Chunk **has been dealt** — or its rescue steps — later sessions that day compose of upkeep and habits only." AD-20: occupancy closes only on `card_done` or a completed rescue chain, so a dealt-but-skipped chunk leaves the slot open and later sessions may deal another large candidate. The override is deliberate (AD-20's Prevents names the FR-7-literal behavior as the failure) and consistent with the PRD's principles-win meta-rule — but the PRD's own exception register (E1/E2) sets the standard that overrides of FR text are written down as overrides, and the spine doesn't say it is touching FR-7's sentence.
- **Fix direction:** one sentence in AD-20 ("FR-7's 'dealt' is read as answered `Hecho`, because the literal reading punishes a skip — the mirror failure above").

### F7 — Warm Return trigger undefined (Low)

- **Where:** AD-1 L44 vs PRD §10.1 (prd L595: "≥ 48 h of absence").
- **What:** AD-1 dismisses FR-6 ("needs no path of its own" — correct about the rebalancing) but no AD defines the trigger: 48 h of absence from *what* — last `app_opened`, last `session_started`, or a count of AD-24-eligible domestic days — measured wall-clock or in domestic days. Two defensible readings show the welcome screen on different days (a Friday-evening open followed by a Sunday-morning session straddles the boundary differently under each). AD-24 built exactly this kind of predicate for windows and counters and stopped one FR short of FR-6.
- **Fix direction:** one clause in AD-24 or AD-4 defining the absence predicate.

### F8 — Residual weave-arbitration ambiguities (Low)

- **Where:** core/weave; PRD FR-11 (prd L232–233).
- **What:** two arbitration points the PRD also leaves open and no AD takes: (a) FR-12 says "the active Epic Project" (singular) but nothing caps concurrent activation, so with two active Epics the chunk's epic-of-the-day is undefined (least-recently-served epic? activation order?); (b) the zone rotation "over the *active* clusters" is stated but not against curation *timing* — disable this week's zone on Wednesday: does the week re-map now or Sunday? AD-16's rotation test covers only the default curation state, and AD-20's fallback covers the below-floor case, not the mid-week change.
- **Fix direction:** one clause each in AD-20 (epic arbitration is a property of the resolver, like capture precedence) and AD-4 or AD-16 (curation changes take effect at the next week boundary).

### F9 — Shell/UI test strategy silent (Low)

- **Where:** Conventions — Testing (L238–239).
- **What:** the testing rows are excellent for the core (`dart test`, no emulator, performance assertions, the two property tests) and name the build-time guards and lints, but say nothing about the shell: whether surfaces get widget tests, golden tests, or handset-manual verification. At an altitude owning the whole validation build — with a three-handset release ritual in AD-18 — the shell's verification stance is a dimension, and it is neither decided, deferred, nor an open question.
- **Fix direction:** one row ("Testing — the shell: …"), even if the answer is "manual on the validation handsets, per AD-18."

---

## Closing note

The spine's characteristic strength is that it argues enforcement, not intention — "Three checks seal it, not one," triggers instead of discipline, a type-state token instead of a reminder. The three medium findings are all places where that standard was stated for one table, one rule, or one diagram and then not applied one step further; fixing them is an afternoon and requires no structural change.

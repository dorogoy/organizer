# Reviewer lens — adversarial (configured reviewer 2)

**Mandate:** construct two units one level down that each obey every AD to the letter and still build incompatibly. Every pair found is a hole to close.

**Verdict:** FAIL as drafted — seven live incompatibilities, all in the seam between "the pool" and "the derivation", which is exactly where AD-1 concentrated the design's weight. All seven close without touching the paradigm.

## A1 — CRITICAL. Two owners of session state.

AD-1 derives the composition from `(pool, acts, day, session)` and never says where `session` lives. It is not a pool fact, and no AD declares it derived.

- **Unit A** (Dispenser story) holds the session in a Riverpod provider: declared pocket, start instant, minutes spent.
- **Unit B** (Pause/Resume story, FR-9) derives it from `session_started` / `session_ended` acts.

Both obey every AD. On process death mid-session, A has no session and deals a fresh card; B resumes the running pocket. FR-9 mandates B (*"Resuming deals the next Micro-task directly — never a resume menu about the past"*), and FR-8's *"dealt durations sum to ≤ the declared pocket"* is unenforceable in A after a restart.
**Fix: an AD stating there is no session of record — session state is derived from acts like everything else.**

## A2 — CRITICAL. Two emitters of the Focus Chunk slot.

FR-12 gives the slot to the active Epic / active zone / `fondo`, and separately gives a pending 10–15 min capture precedence, in which case the capture *is* the "1". FR-7 says a day never holds a second large item.

- **Unit A** (Weaver story) resolves the slot while composing the day.
- **Unit B** (Manual Capture story) applies capture precedence inside the deal-window derivation.

Both obey AD-1, AD-3 and AD-4. No AD names a single owner, so the day can be composed with the zone's Focus Chunk while B independently deals the capture — *"a marathon with a comma"*, the very thing AD-4 prevents at the day boundary and leaves unprevented inside the day.
**Fix: an AD naming exactly one resolver for the slot; everything else returns candidates, never deals.**

## A3 — HIGH. Origin is assigned in two places with two different meanings.

AD-14 says rescue steps inherit the parent's origin. AD-7 and AD-9 put the Slicer's response inside `lib/egress/`.

- **Unit A** (Photo-Diagnosis story) has egress build pool items from the response, tagged `cloud` — correct for a fresh Epic slice.
- **Unit B** (Rescue story, FR-5) expects a rescue of a `manual` capture to stay `manual`.

If the adapter constructs the items, A's rule wins and SM-4's arithmetic shifts silently: *"a hand-written line rescued by the cloud Slicer still entered the pool by hand"*. AD-14 states the outcome; no AD forbids the adapter from constructing the item.
**Fix: adapters return inert DTOs and never domain objects; only the core constructs pool items.** Closes the class, not the instance.

## A4 — HIGH. Two records of the same album deletion.

AD-2 makes a user deletion an act. AD-13 puts "album images and manifest" in the authoritative half.

- **Unit A** deletes by appending `album_entry_deleted`.
- **Unit B** deletes by removing the manifest row.

Both defensible as written, and the export can then carry a manifest listing an entry the log says was deleted, or the reverse. Restore reads the authoritative half, so the contradiction is load-bearing.
**Fix: the manifest is derived, not authoritative. The authoritative half holds the images and the acts that name them.**

## A5 — MEDIUM. The consent act is a replayable capability.

AD-8 makes consent a single-use in-memory token; AD-2's vocabulary includes `consent_granted`, because FR-26 series (b) counts scans. A unit that reconstructs a token from the log — reasonable, since the log is the source of truth for everything else — restores the blanket always-allow FR-25 forbids, one refactor at a time.
**Fix: AD-8 states the act is instrumentation only, carries no capability, and the token is never persisted or reconstructible.**

## A6 — MEDIUM. Settings are mutable, so the past is unreconstructible.

The conventions call settings "the single mutable record". FR-7 lets the Time Bag change any time; the snowball's comfortable day requires *"no session beyond its declared pocket"*, and SM-C1 reads minutes against the budget. With settings mutable and unlogged, the export cannot say what the bag was on day 5 — so a validation reading is not reproducible from the export, contradicting AD-13's purpose. Two units also diverge trivially: one logs a change for its own feature, one does not.
**Fix: setting changes are acts; the settings record is a derived cache.** Removes the one exception to a uniform substrate.

## A7 — LOW. Two clocks for the invitation.

AD-17 says at most one invitation per 24 h; AD-4 rolls the day at 04:00. With a chosen hour of 03:30 the two disagree about whether two invitations fell on one day.
**Fix: one invitation per *domestic* day.**

## Attacks that failed (recorded so they are not re-run)

- **No-overdue through a derived value.** A `daysSinceDealt` helper for AD-3's tie-break is permitted and harmless: it counts elapsed time, not a missed obligation. The forbidden-vocabulary lint catches a rename into debt language.
- **A fourth egress payload.** The three-shape rule plus the single-importer CI check leaves no seam; a unit wanting a fourth must edit `lib/egress/` and delete a check.
- **Catalogue as a writable store.** AD-16's read-only asset plus cluster-level curation closes the template door FR-31 worried about.
- **Rescue depth.** FR-5 caps rescue at 1. Two units could each rescue a rescue — but the parent link in the ERD makes depth computable in the core, and AD-20's single resolver is where it is checked.

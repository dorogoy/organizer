# Independent review — adversarial lens

**Target:** `ARCHITECTURE-SPINE.md` (architecture-organizer-2026-08-26), status `final`.
**Mandate:** construct two units one level down that each obey every AD to the letter and still build incompatibly. Every pair is a hole to close with a new or tightened AD.
**Method:** each unit is an epic or story built by someone who has read the spine and their own story and nothing else. Two such people, in parallel, never talking.

**Verdict:** FAIL as final — 17 live incompatibilities, five of them CRITICAL; the newest ADs (AD-19, AD-20) closed the previous round's holes and opened three of their own, and the substrate's biggest remaining gap is that **non-user events and non-derived state have no declared home**, so four separate stories will each invent one.

Note on scope: the seven findings in `../review-adversarial.md` are all closed in this draft (AD-19, AD-20, AD-5's DTO clause, AD-13's derived manifest, AD-8's instrumentation clause, AD-1's settings-as-acts, AD-17's domestic day). Nothing below re-runs them; they are recorded in the failed-attacks section so they stay closed.

---

## 1. CRITICAL — `SETTINGS` has two owners, and the spine states both

**Unit A:** the story implementing FR-7 (daily Time Bag) plus FR-24's chosen hour and FR-30's destination folder — i.e. "the Settings surface".
**Unit B:** the story implementing FR-30's export/restore, or FR-23's snowball, both of which need history.

Unit A reads the Consistency Conventions verbatim:

> `State — mutation` — Only two shapes: append an act, or insert a pool fact. Everything else is derivation. **Settings are the single mutable record in the app.**

and builds a `settings` drift table with `UPDATE`. Nothing forbids it: AD-2's triggers are on `acts` only, and this row grants the exception explicitly.

Unit B reads the Structural Seed's ERD note, on the same page:

> `SETTINGS` is a **derived cache** over `setting_changed` acts, not a mutable record (AD-1).

and derives it, with `setting_changed` as the only write.

Both obey every AD to the letter, because the spine says both things. Consequences, all silent:

- **Restore is wrong.** AD-13's `AUTHORITATIVE/` holds "acts, pool and album image files — and nothing else". Under A the settings table is in neither half, so an import restores a phone with the *default* Time Bag, default hour, no destination folder — and AD-13's round-trip test still passes, because a mutable settings table is not a derived read model rebuilt from the log.
- **SM-C1 is unreadable.** AD-1's own justification — "what the Time Bag was on day 5 is reconstructible from the export" — is false under A.
- **Merge conflict is invisible.** A's table and B's projection can coexist in one binary, disagreeing.

**Fix:** delete the sentence "Settings are the single mutable record in the app" from the conventions row and replace it with the ERD note's ruling: *there is no mutable record; `SETTINGS` is a derived cache over `setting_changed`, rebuilt on start and never the source of truth.* One statement, one place.

---

## 2. CRITICAL — no rule says which settings become acts, so a plausible unit exports the user's API key

**Unit A:** the story implementing FR-28 (BYOK key entry, provider allowlist selection) in the settings surface.
**Unit B:** the story implementing FR-30/AD-13 (export and restore).

AD-1 is unconditional:

> Persist only (a) the task pool as immutable facts and (b) an append-only log of user acts — **settings changes included** …

and the act vocabulary carries exactly one kind for it, `setting_changed`. Unit A, wiring the settings surface, records `setting_changed` for every field that surface owns — Time Bag, hour, provider, and the key, because the key is a setting the user changes and the rule says settings changes are acts. AD-13 then puts acts in `AUTHORITATIVE/`, and FR-30 writes that folder into a user-chosen directory which §7 explicitly anticipates being Drive, Dropbox or Nextcloud.

FR-28 says the opposite and the spine never carries it:

> The key is held in the OS keystore: never in app preferences, **never in the export** (§7), and never transmitted anywhere except to its own provider.

AD-10 gets close — "the Dispenser never learns a key exists" — but that is a UI statement, not a persistence one. No AD names a class of settings excluded from the log.

**Consequence:** the user's provider credential leaves the device inside the backup, to a synced folder, and the one guarantee §7 calls unqualified ("to the developers: nothing") survives while a worse one dies. It is also unnoticeable: the key is one line in a JSONL file nobody opens.

**Fix:** a new AD (or a clause on AD-1): *no secret is ever an act. `setting_changed` may carry the provider identity and the fact that a key exists; the key material lives only in the keystore, is never an act, never in the pool, never in either half of the export, and a CI check greps the export fixtures for keystore-held values.* State the same for the SAF destination URI, which is a capability grant rather than a value and cannot be replayed onto another install (see §16 note).

---

## 3. CRITICAL — AD-19's session evaporates at 04:00, reintroducing exactly the marathon AD-4 exists to prevent

**Unit A:** the story implementing FR-8/FR-9 (session start, pause, resume) against AD-19.
**Unit B:** the story implementing FR-7's daily advance bound and AD-20's once-per-day slot.

AD-19's definition is precise and load-bearing:

> A session is `session_started` (carrying the declared pocket) with no matching `session_ended` **in the current domestic day**.

AD-4 rolls the day at 04:00 and states the hazard it was written to kill: "dishes finished at 23:55 and a second Focus Chunk offered at 00:05 *because it is another day*, a marathon with a comma."

Take a session declared at 03:40 with a 30-minute pocket. At 04:00 the domestic day rolls. Unit A, applying AD-19 literally, now finds no `session_started` in the current day: the session is over. Unit B, whose slot is "resolved once per domestic day", resolves a fresh Focus Chunk for the new day — the day's advance budget has just reset under a user who never put the phone down. FR-8's "dealt durations sum to ≤ the declared pocket" is unenforceable across the boundary, and the user is handed a second large item in one sitting. The hazard did not disappear; it moved from midnight to 04:00 and AD-19 wrote the door back in.

Both units obey every AD. The 04:00 hour makes it rare, which is worse: it will not be found in testing, and 03:40 is exactly when a validation user with insomnia opens the app.

**Fix:** tighten AD-19 to define a session by its *own* start, not by the current day: *a session is the latest `session_started` with no matching `session_ended`, and it belongs to the domestic day of its start instant. A domestic-day boundary crossed inside a session neither ends it nor resets the day's advance; the advance bound is charged to the session's own day, and the next day's slot is resolved at the first deal after the session closes.*

---

## 4. CRITICAL — AD-19 cannot express FR-10's session extension, and the vocabulary has no kind for it

**Unit A:** the story implementing FR-10 (the checkpoint and the silent "extend" secondary action).
**Unit B:** the story implementing FR-23's snowball, whose §10.1 condition is "no session beyond its declared pocket".

AD-2 forbids editing: "Corrections are new acts, never edits." The conventions add: "A new act is a new kind, never a flag on an old one." The declared vocabulary has `session_started` and `session_ended` and nothing for an extension.

Unit A therefore extends by appending a second `session_started` with a longer pocket — the only move the rules leave. AD-19 now has two `session_started` acts and one `session_ended`, and its definition ("`session_started` with no matching `session_ended`") does not say which pocket is *the* declared pocket. Unit B's predicate breaks in the same stroke: under "first pocket wins" every extended session is "beyond its declared pocket" and no day is ever comfortable, so the snowball never fires; under "latest pocket wins" no session is ever beyond its pocket and every day is comfortable, so the snowball fires on day 10 regardless of behaviour. FR-8's bound picks up the same ambiguity.

**Fix:** add `session_extended` (carrying the added minutes) to the vocabulary, and tighten AD-19: *the session's declared pocket is `session_started`'s pocket plus the sum of its `session_extended` acts; a session is closed only by `session_ended`.* Then state which quantity the comfortable-day predicate reads — the original pocket, so an extension the user chose is not scored as a marathon, and FR-10's "the app never encourages more than it asked for" stays measurable.

---

## 5. CRITICAL — non-user events have no home, and FR-26's series (b) and (d) require four of them

The conventions define acts as "one per **user** act". AD-1 permits exactly two persisted things: pool facts and the act log. AD-12 forbids any logging framework. Nothing else may be written. Four events FR-26 requires are not user acts:

| Event | Required by | Declared kind |
|---|---|---|
| consent declined | FR-26 series (b) outcome "declined" | none — only `consent_granted` exists |
| person detected in frame (pre-upload refusal) | FR-26 (b); AD-8 routes it to FR-29 | none |
| Ambient Invitation **emitted** | FR-26 series (d) | none |
| app opened (within the hour after an emission) | FR-26 (d), SM-C3's stated test | none — `session_started` is a different event |

**Unit A:** the story implementing FR-26's four series and the export's derived half. It needs all four, reads "a new act is a new kind, never a flag on an old one", and adds `consent_declined`, `face_refused`, `invitation_emitted`, `app_opened` as acts — putting machine-initiated rows in a table the conventions define as a record of what the user did, and putting an app-open counter in the substrate that §1.1 P2 exists to keep out.

**Unit B:** the story implementing FR-24's alarm. It also needs the last emission — to honour "at most one per domestic day" after a boot reschedule — and, reading the same conventions row, refuses to write a non-user act. It keeps the last-emission instant in `SharedPreferences`: a third mutable store, outside AD-1's two shapes, absent from both halves of the export, invisible to AD-13's round-trip test.

**Consequences:** de-duplication state exists in two places and disagrees after a reschedule, so FR-24's "at most one per 24 h under every code path" fails on the one path nobody tests (boot after the alarm already fired). Series (d) is empty in whichever build B wins, so **SM-C3's only stated test — "share of sessions started within the hour following an emission" — cannot be run**, and SM-1 keeps its false-positive risk permanently. Series (b) under-counts declines in both builds, and SM-4's denominator moves.

**Fix:** one AD, not four patches. *The log holds two kinds of row: user acts and **system events**. System events are insert-only in the same table under the same triggers, are named `*_emitted` / `*_refused` / `*_observed`, are excluded from every user-facing derivation by construction (they can be read only by `core/export` and the FR-26 series), and are enumerated exhaustively here: `invitation_emitted`, `app_opened`, `consent_declined`, `face_refused`, `slice_failed`.* Then state that no other store exists — no preferences, no side files — so B has nowhere else to go.

---

## 6. HIGH — "dealt" is an input to two counters and nobody owns when it is written

**Unit A:** the Dispenser story (FR-1, FR-2). It renders `nextCard()` and appends `card_dealt` at render, because AD-3's tie-break "least-recently-dealt" needs a deal recorded whether or not the user answers.
**Unit B:** the Rescue story (FR-5). Its trigger is "the same Micro-task is dealt and declined on 3 **different calendar days**", and FR-5 adds that "days the task was not dealt … neither increment nor reset the count". B therefore reads `card_dealt` as *the user saw it and had the chance to decline*.

The spine names `card_dealt` in the vocabulary and never says who appends it or at which moment. Three divergences, all live:

- **A card dealt and never seen.** Process death between render and answer leaves `card_dealt` with no `card_done` / `card_skipped`. Under B's reading that is a decline day; the user never saw the card. Three cold starts in three days silently dissolve a task (FR-5's dissolution clause). Under a write-on-answer scheme, no `card_dealt` exists at all and B's counter never advances.
- **A card silently vanishes.** With write-on-render, restarting the app re-runs `nextCard()` over a log that now contains yesterday's — in fact this second's — `card_dealt`, so least-recently-dealt returns a *different* card. The user's card changed with no act of theirs. AD-3's "same card, forever" is preserved only in the trivial sense that the inputs changed.
- **FR-26 series (a)'s "Micro-tasks completed"** is unaffected, but SM-4's Focus-Chunk origin mix is computed over dealt rows in one build and answered rows in the other.

**Fix:** an AD, or a clause on AD-3: *`card_dealt` is appended by the act command that answers the previous card (or by `session_started` for the first card of a session) — never as a side effect of a read. `nextCard()` is pure and writes nothing. A card the user never answered has no `card_dealt`, and "declined on a different day" means a `card_skipped` on that day.* State the same rule for the deal window and the coverage floor, which both count deals.

---

## 7. HIGH — "an eligible day" is derived twice, by two stories, and the PRD says they must agree

**Unit A:** the Manual Capture story (FR-12, FR-27). Its rule: "The deal window advances only on days the capture was actually eligible for dealing: a 🔴 day (FR-4) or an absence (FR-6) freezes it."
**Unit B:** the Rescue story (FR-5). Its rule: "days of absence, days the task was not dealt, or energy filtering neither increment nor reset the count" — the PRD explicitly says this is the *same* mechanism ("exactly as FR-5 freezes its own counter").

AD-1 declares both derived ("FR-5's decline count … a capture's deal window … are all returned by a pure function"), and AD-6 says both cross into the shell as opaque decisions. Neither AD says what an eligible day *is*, and the two candidate definitions are both defensible:

- A defines eligible as: a domestic day with a `session_started` and no 🔴 in effect.
- B defines eligible as: a domestic day on which *this item* was actually in the candidate set — which for a 3-minute capture on a day whose "3" was filled by upkeep is false, and for a Focus-Chunk capture on a day the slot went to the Epic is also false.

**Consequence:** the two counters advance on different day sets. A capture is dealt on day 3 in one build and day 6 in the other; FIFO order between two captures inverts; a rescue triggers a week apart. Every one of those is user-visible, and none of them is a bug either unit can find alone — each is correct against its own story.

**Fix:** a new AD naming one predicate: *`core/derive` exposes exactly one `EligibleDay(item, day)` predicate; every window, counter and freeze in the product is expressed over it, and no story may define a second. Its definition: a domestic day carrying at least one `session_started`, on which the item's size was not excluded by the day's energy.* Item-level candidacy is deliberately excluded, because it makes the window depend on the composition it is an input to.

---

## 8. HIGH — nothing says how a pool item leaves the pool, and FR-5 requires two items to leave

**Unit A:** the Rescue story. FR-5: "Completing all rescue steps marks the original Micro-task done", and "A rescue whose steps are themselves declined on 3 different days **dissolves the original task silently — out of the pool**, no state, no notice."
**Unit B:** the Weaver story, which derives candidacy from pool facts and acts.

The spine's mutation rule is "append an act, or insert a pool fact"; the pool is "immutable facts"; the vocabulary has `card_done` (a user act) and no kind for dissolution. Two reasonable builds:

- Unit A marks the parent done by appending a `card_done` for it — a row the user did not produce, in a table defined as "one per user act". Series (a)'s completed-task count now reads 5 for a four-step rescue; SM-C1 reads tasks-per-day upward for a mechanism that was supposed to make a stuck task smaller. And it dissolves by inserting a tombstone pool fact (permitted: "insert a pool fact"), which is a new entity nothing else knows about.
- Unit B derives both: the parent is done when its children are, and an item is out when the decline pattern holds. Its derivation never sees A's tombstone, so a dissolved item keeps coming back in B's build; and A's synthetic `card_done` makes B's parent-done derivation double-count.

Either way AD-13's round-trip test passes — it exports and re-imports whatever exists — and the two builds cannot merge: the same log yields two different pools.

**Fix:** an AD stating that **pool membership is derived, not stored**: *an item is in the pool if a pool fact created it and no derivation retires it. Retirement has exactly two derived causes — the completion of its rescue children, and FR-5's dissolution pattern — both computed in `core/derive`, both with no act and no tombstone of their own. Completion of a parent by its children is derived; no synthetic `card_done` is ever appended, and every completion count in FR-26 counts user acts only.*

---

## 9. HIGH — two export triggers fire at the same instant, and no AD owns single-writer or atomicity

**Unit A:** the session story. AD-17: "FR-30's export runs in the foreground at **session end**."
**Unit B:** the app-lifecycle story. Same sentence: "and **app backgrounding**."

At the end of UJ-1 both happen within milliseconds — the user taps the last `Hecho`, the session closes, and they put the phone down. Two triggers, two calls into the export adapter, one SAF destination, the same file names. Nothing in AD-13 or AD-17 says the export is single-writer, idempotent, or written temp-and-renamed. Two concurrent SAF writers on Android do not fail loudly; they interleave.

**Consequences:** a torn `AUTHORITATIVE/acts.jsonl` — and that file is the validation window's only durability (AD-18 exists precisely because a dropped phone in week 3 is a real risk). Worse: AD-13's import "reads only the authoritative", so the next restore reads the truncated file and AD-13's round-trip test never catches it, because the test exports once, cleanly, from a quiescent state. The property the spine claims — "That test is what earns the format the name *restore*" — is claimed over a scenario the test does not contain.

**Fix:** a clause on AD-13: *the export is a single-writer operation guarded by a lock in the adapter; a trigger arriving while an export runs is dropped, not queued (AD-7's no-queue rule, applied here); every file is written to a temporary name in the destination and renamed on completion, so a crash or a revoked permission mid-write leaves the previous export intact. The round-trip property test includes a torn-export case: truncate the authoritative half at an arbitrary byte and assert the import refuses rather than partially restores* (FR-30 already forbids partial restore).

---

## 10. HIGH — AD-16's build-time floor counts the shipped file; the floor it claims to prove is about the eligible pool

**Unit A:** the catalogue story. AD-16: "A tool in `tool/` counts distinct 10–15 min non-daily entries and fails the build below 28." It implements exactly that over `assets/evergreen/`, gets 32 (A12: 20 weekly + 12 `fondo`), and ships green.
**Unit B:** the curation story (FR-31, FR-11). It lets the user enable and disable clusters, and the zone rotation runs "over the *active* clusters".

Both are correct. But FR-31's floor is stated over the *eligible* pool — "the pool eligible for the Focus Chunk slot … holds at least 28 distinct entries, so 28 dealt Focus Chunks never repeat" — and B moves that pool at runtime. Disable Z5 (entrada/lavadero — a flat with no terrace, the exact case A12's own assumption anticipates) and the `coche` entry (no car): 32 − 3 − 1 = 28, at the line. Disable one more zone and the guarantee is gone, with a green build and no signal anywhere. The spine's "Prevents" clause for AD-16 says "the coverage floor becoming an unverified claim" and "FR-31 requires it checkable *without running the app*" — the stated check verifies a property of the file, not the claim.

**Fix:** tighten AD-16 to check the property that is actually load-bearing: *the tool asserts the floor over **every reachable curation state**, not over the file — i.e. min over all cluster subsets the UI can produce, which is the all-disabled case and therefore unprovable by counting. So instead: the tool asserts the floor over the file, **and** a core test asserts that the derivation's Focus-Chunk rotation never repeats within 28 deals for the default curation state, and that `core/weave` has a defined, non-repeating fallback when curation drops the eligible pool below 28.* Name that fallback in AD-20 (today it falls through `fondo` and then nothing). Without it, a curated install repeats silently and §10.2's prompt-blindness assumption is being tested against the wrong pool.

---

## 11. HIGH — the one flat string table has two homes

**Unit A:** the strings story. AD-15: "Every user-visible string is an entry in **one flat externalised table**", and the Structural Seed places it: `strings/ # the one flat table (AD-15)`. A builds `lib/strings/` as a flat map of Dart constants and points the build check at it.
**Unit B:** any surface story. The i18n convention: "ARB files through `flutter_localizations` / `gen_l10n`, Spanish as the only shipped locale … so the generated Spanish ARB *is* the flat audit table AD-15 requires." B puts its strings in `lib/l10n/app_es.arb`.

Both are quoting the spine. Two tables now exist, and AD-15's build check — "fails if any of FR-29's seven no-Slicer strings, or any string on the SM-C2 audit list, is empty or still a developer placeholder" — reads exactly one of them. Every string in the other escapes the SM-C2 audit surface entirely, and SM-C2's target ("guilt events = 0") becomes a claim about half the product's copy.

**Fix:** delete one. Tighten AD-15 to: *the ARB file for the shipped locale **is** the table; `lib/strings/` holds no literals and exists only as the generated accessor; a lint fails on any string literal reaching a widget.* Remove `strings/` from the Structural Seed or relabel it as generated output. Then state where the SM-C2 audit list lives (see §17) — it is currently an input to a machine check with no owner.

---

## 12. MEDIUM — energy is a declared input to the weave with no declared scope

The spine's own derivation diagram makes energy an input: `SESS["session: pocket, energy"] --> W`. AD-19 defines the *session* and says nothing about energy; the vocabulary has `energy_set`; AD-4 owns day boundaries.

**Unit A:** the Dispenser/energy story (FR-4). Reading the diagram, energy is session-scoped: it resets to 🟢 at each `session_started`, which matches EXPERIENCE.md's "defaults to 🟢, fixed, no decay" and its rejection of "last-choice-persistent (one bad day silently starves the app for weeks)".
**Unit B:** the weave story. Reading AD-4, energy is day-scoped: the last `energy_set` of the current domestic day.

Consequence, on the exact night FR-4 was written for: the user taps 🔴 at 20:00, does a 30-second habit, closes the session, and opens the app again at 21:30. Under A the pool is wide again and the app offers a Focus Chunk to someone who told it they were empty ninety minutes ago. Under B it stays narrow. UJ-4 reads as A being wrong and the UX record as B being wrong ("one bad day silently starves the app" was rejected at *day* granularity, not at session). Both builds are defensible; they deal different cards.

**Fix:** an AD clause: *energy is scoped to the domestic day — the last `energy_set` in the current day, defaulting to 🟢 at each day boundary and never carried across one. It is not session-scoped: a second pocket in the same evening does not re-widen a pool the user asked to narrow.* State it in AD-4 (it is a period question) rather than AD-19.

---

## 13. MEDIUM — the scan image has one lifecycle rule and three artifacts

The conventions state one rule: "the scan image lives in the cache directory, is never written to album storage, and is **unlinked the moment a plan exists** (FR-25)." AD-7 adds a second artifact: "It enforces a single image-resolution cap before any upload."

**Unit A:** the scan story (FR-16). It owns the capture, the on-device face gate (AD-8: the refusal "produce[s] no token", so detection precedes the token), and the cancel path — FR-16: "Leaving the surface or backgrounding the app cancels the wait and discards it."
**Unit B:** the egress story (AD-7). It receives the consented image, downscales it to the cap, and uploads.

Three holes, none owned:

- **The capped copy is a second file** and no rule names it. B writes it into the cache; the conventions' unlink rule speaks of "the scan image", singular. A photograph of the inside of the home persists after the plan exists, in whichever unit did not think of it.
- **No plan, no unlink.** The rule fires "the moment a plan exists". On the cancel path, on the no-network path, on the person-detected path and on the declined-consent path, no plan ever exists — so the literal rule never fires and the frame stays in cache indefinitely. Unit A discards "the wait"; discarding the wait is not unlinking the file.
- **AD-8's binding is unspecified.** "A `ScanConsent` bound to one specific image and consumable once" — bound by path, by id, or by content hash? If by hash, B's downscale invalidates the token the user granted and the scan dies for a reason no string covers. If by id, "bound to one specific image" is nominal and a unit can re-point the id. AD-8 claims "Absence of a token is a compile-time impossibility" — true, and it is only about absence: single use and correct binding are runtime properties the AD asserts without assigning.

**Fix:** a clause on AD-7/AD-8: *every scan derives at most two files, both in one cache subdirectory owned by the scan story, and **both are unlinked when the scan resolves — by a plan, a refusal, a decline, a failure or a cancel — whichever comes first**, with a session-start sweep of that directory as the crash backstop. `ScanConsent` binds to the cache subdirectory identity, is minted after the face gate and before the cap, and the cap operates inside the binding rather than producing a new subject.*

---

## 14. MEDIUM — AD-12 mandates a crash log and AD-1 leaves nowhere to put it

AD-12: "Crash visibility is a **local** log written into the export's derived half — stack and timestamp, no task text, no image paths." AD-13: "`derived/` holds the manifest, the four FR-26 series rendered for reading, and the crash log". The conventions: "Diagnostics are the local crash log of AD-12 and nothing more", and mutation has "only two shapes".

**Unit A:** the crash story. A crash happens between exports, so the log must persist locally *before* the export renders it. A writes `crash.log` in app-private storage — a third mutable store, outside AD-1's two shapes, with no declared rotation, no wipe-on-restore, and invisible to AD-13's round-trip test.
**Unit B:** the export story. It reads AD-13 literally — `derived/` is rendered at export time from the substrate — finds no source for the crash log in the substrate, and renders an empty section. Crashes are silently lost, which is the one thing AD-12 exists to prevent.

**Fix:** decide it in AD-12: either *crash records are system events in the act log* (see §5 — the uniform answer, and it makes them survive restore and round-trip), or *AD-1 admits exactly one non-substrate file, named here, with a stated size cap, a stated rotation, and a stated wipe on import.* Also note the forbidden-vocabulary lint bans identifiers containing `failed`, which a crash handler will reach for — name the permitted term.

---

## 15. MEDIUM — "resolved once per domestic day" and "skip deals an alternative" both apply to the Focus Chunk, and neither wins

**Unit A:** the Weaver story. AD-20: "The slot is **resolved once per domestic day**, in one function, and that function is where 'the day never holds a second large item' is a single line."
**Unit B:** the Dispenser story. FR-3: "the Dispenser deals an alternative without recording failure", and its consequence "The alternative respects current Energy Level and remaining Time Bag budget."

The user is dealt the day's Focus Chunk and taps `Otra más fácil / Ahora no`. Under A the slot is already resolved to that item, so either the same card returns (a wall, and FR-3's "an alternative" is violated) or nothing large is offered for the rest of the day (advance is silently spent by a skip — FR-7 charges the bag to *dealt* advance, not to completed advance, and never says a skip consumes the day). Under B a different Focus Chunk arrives, which is an alternative but re-opens AD-20's own line: the day can now deal a second 10–15 min item, and if the first was later completed out of a lingering card, "the day never holds a second large item" fails.

The same ambiguity hits a mid-day Time Bag change (FR-7 raises it from 8 to 15 at noon: is the slot re-resolved?) and FR-31's floor, which "counts dealt Focus Chunks" — under A a skipped Focus Chunk consumes rotation, under B it does not, and 28 non-repeating deals means two different things.

**Fix:** tighten AD-20 to separate *occupancy* from *identity*: *the slot's **occupancy** is resolved once per domestic day — at most one Focus Chunk is ever **dealt and answered `Hecho`** in a day. Its **identity** is re-resolved on each deal, so a skip yields a different candidate and consumes no rotation; only a `card_done` (or a completed rescue chain) closes the slot for the day. A Time Bag change re-resolves identity and never re-opens a closed slot.*

---

## 16. MEDIUM — AD-4's absolute prohibition cannot hold at the alarm boundary

AD-4: "One `Calendar` in the core is the **only** thing in the system that converts an instant to a period, and **nothing else may compute a date boundary**." AD-17 delivers FR-24 by "an **inexact** alarm, at most one per **domestic day**, rescheduled after boot".

**Unit A:** the notify story. It computes the next trigger in Kotlin, where AlarmManager lives and where "next 21:00 local" is one `LocalDate` call. It violates AD-4's letter — but AD-4 gives it no alternative, because the core is pure and reads no clock, and the boot receiver runs before any Dart engine exists.
**Unit B:** a story that needs the same computation and routes it through `Calendar`, handing an instant out through the Notifier port.

Divergence lands on DST and on the domestic-day rule together: with a chosen hour of 02:30 on a spring-forward night, A's Kotlin computation skips or doubles a day; AD-4 promises "a DST transition never creates or destroys a period", and A cannot keep that promise from where it stands. Chosen hours between 00:00 and 04:00 also straddle the domestic day — AD-17 anticipates that exact case for 03:30 and fixes the *count*, not the *computation*.

**Fix:** a clause on AD-4/AD-11: *the Notifier port accepts an absolute instant only; the trigger instant is always computed in `core/day` from the chosen hour, and the Kotlin half performs no date arithmetic of any kind. The boot reschedule is a Dart entry point that recomputes from the core, not a native recomputation.* If that is impossible for the boot path, name the exception explicitly and state what it may compute — an unstated exception is where the second clock arrives.

---

## 17. MEDIUM — AD-6 licenses a decision literally named "deal this" while AD-20 gives the deal to one module

AD-20: "`core/weave` is the only code that may emit a deal. Everything else … returns **candidates with precedence, never a deal**."
AD-6: signals "are computed inside the core and returned as opaque decisions — *rescue now*, **deal this**, *suggest the bag*", and the spine's own derivation diagram labels the signal output `deal capture`.

**Unit A:** the capture-precedence story (FR-12). It implements `derive.captureDecision() → dealThis(captureId)` — the exact name AD-6 authorises — and the Dispenser provider, which is entitled to consume opaque decisions ("never as numbers crossing into the shell" implies decisions *do* cross), renders it.
**Unit B:** the Weaver story, which resolves the slot and emits the day's deal.

That is the previous round's A2 walking back in through AD-6's vocabulary: two things reaching the card surface, and AD-20's single-resolver rule intact on paper because A never called its output "a deal".

**Fix:** tighten AD-6's decision vocabulary so no decision carries a deal verb, and state the direction: *opaque decisions are inputs to `core/weave`, not outputs to the shell. The only thing the shell may render as work is `nextCard()`. Rename the decisions to state a fact, never an action — `captureIsDue`, `rescueIsWarranted`, `bagIsComfortable` — so no story can consume one as an instruction.*

---

## 18. LOW — three machine checks are asserted to prevent things they do not catch

Grouped because the fix is one habit, not three ADs.

- **The 200% lint.** Conventions: "Never set `maxLines` and never set `TextOverflow.ellipsis` on user-facing text … a lint enforces the absence." Unit A fixes the known `Otra más fácil / Ahora no` fold with a `FittedBox`; Unit B fixes the dashboard row with a `TextScaler` clamp in the theme. Both pass the lint, and both break the 200% floor exactly where the UX spine says it is under most pressure. **Tighten:** ban `FittedBox`, `TextScaler`/`textScaleFactor` overrides, and fixed-height containers around text, in the same lint.
- **AD-15's placeholder check.** It "fails if any of FR-29's seven … is empty or still a developer placeholder". A non-empty sentence passes — including `tu clave no es válida`, the one string the PRD and the UX spine both flag by name as the shaming risk the seven exist to remove. The check enforces *existence*, and AD-15's stated purpose is that the seven "cannot be written last, in a hurry". **Tighten:** the seven are pinned by key in the check with a required non-placeholder value *and* a required reviewer sign-off marker in the ARB metadata, so existence and review are separate gates.
- **"the SM-C2 audit list"** is an input to that check and no AD says where it lives or who adds to it. Unit A hand-maintains a file; Unit B ships a surface and never touches it; the check stays green over an incomplete audit. **Tighten:** the audit list is *every* key in the shipped ARB, minus an explicit, reviewed exclusion list — so silence adds a string to the audit rather than omitting it.

Also in this class, smaller: AD-17's "each refusal … is never asked again" needs persisted refusal state, which is not an act and not a pool fact (§5 and §14 again) — and if a unit does persist it as a setting act, it rides through AD-13's restore and suppresses a permission prompt on a device where the permission was never asked. And the ERD's `ALBUM_ENTRY ||--|| EPIC_PROJECT` makes the epic link mandatory on both sides, while FR-17 fires a Before/After on "completing a session **or** project milestone on a scanned space" — a reward for a scanned space that never became an Epic has no parent, so one unit writes a null and the other cannot store the entry.

---

## Attacks that failed, and why — recorded so they are not re-run

- **A stored `daily_plan`.** AD-1 forbids it, the ERD names its absence explicitly ("There is no `DAILY_PLAN`"), and the forbidden-vocabulary lint catches the rename. Two units cannot both build here.
- **A second clock for the *day*.** AD-4's single `Calendar` plus "no date-only columns" and "UTC instants in storage" leaves no seam for a second day definition. The only crack is the alarm boundary (§16), which is a different attack.
- **Nondeterministic selection.** AD-3 bans `Random`, wall-clock reads and ambient state, and states the full tie-break ("least-recently-dealt, then by stable id"). Two units implementing selection independently produce the same card, given §6's fix on what "dealt" means. UUIDv7 ids minted in the shell do not break it: the id is part of the input, not sampled during derivation.
- **Origin tagged by arrival instead of lineage.** AD-5's "adapters return inert DTOs and never domain objects" plus AD-14's inheritance rule closes the class, not just the instance. An egress unit cannot construct a `cloud`-tagged item for a rescue of a `manual` capture, because it cannot construct an item at all.
- **A fourth egress payload.** Three shapes as types, one importer, a CI check on the HTTP import. A unit wanting a fourth must edit `lib/egress/` and delete a check — visible in review, which is the point.
- **Consent replayed from the log.** AD-8's clause ("instrumentation only … never persisted, never exported and never reconstructible") is explicit enough that a unit reconstructing a token is violating the AD, not obeying it.
- **Two records of one album deletion.** AD-13's derived manifest removes the second writer. Restore reads acts and images only.
- **Two writers of the pool for rescue steps.** AD-5 plus AD-20's depth-cap ownership puts construction in the core and the cap in one function. (What is *not* closed is how the parent leaves the pool — §8.)
- **A crash-reporting SDK arriving as "not analytics".** AD-12's blanket prohibition is stated as a class, not a list, and names the two permitted plugins by the property that admits them (neither opens a destination).
- **A list surface growing from the read facade.** AD-6's negative rule ("exposes no function returning a collection of pending or captured tasks") is checkable by inspection of one file, and E1's catalogue list reads a build-time asset rather than user data. The album and dashboard are collections of *facts*, not of pending work.
- **The Local stub reaching a validation handset.** AD-9's debug-variant gate plus AD-18's "the debug variant is never installed on a validation handset" is belt and braces; a `local`-origin row cannot appear in a validation export.
- **A blanket "always allow" arriving as a convenience.** The token's type signature makes the absence of consent uncompilable, and no settings surface can grant one. (Its *binding* is still unowned — §13.)

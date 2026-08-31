# Epic 2 Context: How Much the App Asks of Me

<!-- Compiled from planning artifacts. Edit freely. Regenerate with compile-epic-context if planning docs change. -->

## Goal

Epic 2 makes the app's asks settable and shrinkable: the user sets the daily Time Bag, declares the pocket of minutes they actually have right now, can stop with one tap at any moment, is offered rest instead of continuation at checkpoint intervals, is asked once a day how much energy they have (only low energy narrows the day), answers one weekly self-report that feeds the validation instrument, and returns after days away to a silently rebalanced day with nothing to catch up on. Everything in this epic narrows what the app requests; nothing adds work. It covers FR-4, FR-6, FR-7, FR-8, FR-9, FR-10, and builds the Settings shell, the ambient strip, and the session-derivation substrate later epics consume.

## Stories

- Story 2.1: The Time Bag, and the way into Settings
- Story 2.2: The declared pocket and the derived session
- Story 2.3: Pause, and the advance/upkeep split applied to it
- Story 2.4: The Anti-Marathon checkpoint as permission to stop
- Story 2.5: The ambient strip and the daily energy check-in
- Story 2.6: The weekly self-report and the deterministic slot handoff
- Story 2.7: Warm Return

## Requirements & Constraints

- Time Bag: 5–30 minutes, default 15, covers advance work only (the Focus Chunk); upkeep and habits are composed alongside it and charged nowhere. Below 10 minutes the day composes with no Focus Chunk, silently, with no budget-exhausted state. Mid-day changes never invalidate completed work; once the day's chunk is answered `Hecho`, later sessions that day compose of upkeep and habits only.
- Declared pocket: a positive whole number of minutes, 1–60; dealt durations (upkeep included) sum to ≤ the pocket; only answered cards consume it — a skipped card's estimate is released. A remaining pocket smaller than every candidate's estimate closes the session early with the fixed warm close (same string as pool exhaustion), never an error state.
- Pause: always available at one tap, for any reason; recalculation is silent and invisible (no toast, no banner); no interrupted, incomplete or overdue state may exist anywhere, in either language. Returning deals the next card directly — never a resume menu, never a summary, never anything about the past.
- Checkpoint: the permission-to-rest screen is the primary surface at every interval multiple (default 15 minutes, range 10–15); interval multiples read cumulative same-day session time, not per-session elapsed, so chaining short sessions cannot dodge the offer; a card in progress can always be finished; extension is a silent secondary — never highlighted, animated or suggested; no continuation question (`¿seguimos?` or any variant) exists anywhere; a session shorter than one interval reaches no checkpoint — its close is the permission; a close coinciding with a final checkpoint is the offer itself, no second surface.
- Energy check-in: once per day at the day's first opening; only baja narrows (Instant Habits and ≤ 60 s, excluding Focus Chunks) — media filters nothing; a baja tapped mid-card lets the in-progress card finish and filters the next deal; dismissal is skip-for-today, never re-shown that day, never styled as pending; the re-filter completes in under 500 ms; energy defaults to llena at each day boundary, never decays, is derived and never written; after the strip leaves, nothing displays the level. No energy control exists outside the strip — mid-session relief is Rescue Mode's job (Epic 4).
- Weekly self-report: appears at Sunday's first opening (Sunday is the last day of the Monday-anchored week); persists until answered, re-offered at each day's first opening on any day; numeric 1–5 with `Nada` / `Muchísimo` end labels, the numbers as tap targets; outranks the check-in while pending, but a resolved report hands the slot to the check-in within the same opening — it delays, never displaces for the day; a dismissal frees the slot for that opening only, never for the week; a report still pending when the next Sunday arrives is superseded, never accumulated — at most one is ever pending and the superseded week simply has no data point; the answer entry carries the week it answers, not merely its instant; it is never notified under any code path.
- Warm Return: due at ≥ 48 h since the later of the last app open and the last user act; the first dispensed card comes from the silently rebalanced composition and cold start still meets ≤ 2 s; no missed-days copy, overdue badge or broken-streak indicator anywhere — days away are not representable in the schema, so they cannot reach the screen.
- Fixed strings are verbatim, never re-worded: `Tengo 15 minutos ahora`, `por hoy no hay nada más que merezca la pena`, `¿Cuánta energía tienes hoy?`, `Esta semana, ¿cuánto te ha agobiado la casa?`, `Nada más por el momento` with `Quiero seguir`, `Siempre a tu disposición`.
- No field, flag or derived value anywhere may express lateness, debt, streak or a missed occurrence; the forbidden-vocabulary lint enforces it.

## Technical Decisions

- Nothing about a day is stored: today's composition, the current session and the settings record are all pure functions of (pool, log, day, session). Settings — the Time Bag included — is a derived cache over `setting_changed` entries rebuilt at start, never a source of truth, so historical values are answerable from the log alone.
- The Time Bag is a daily ceiling derived from the setting, never a depleting wallet: nothing is ever subtracted from it, so the pause rollback clause is satisfied vacuously — do not build an accumulator.
- The session is derived, never held in memory as truth: the latest `session_started` with no matching `session_ended`, belonging to the domestic day (04:00–04:00 local) of its own start instant. The declared pocket is the start pocket plus the sum of `session_extended` entries. Exactly three closing causes exist and no others: the user stopping, the pocket elapsing while foregrounded, and backgrounding; an elapsed pocket is revealed at the next foreground instant, not awaited; after process death the derived session is still open and the same rule applies. A session crossing 04:00 neither ends nor resets — all its card acts charge to its own start day as one ledger, it never occupies the crossed-into day's Focus slot, and the next day's slot resolves at the first deal after it closes. Two derived-open sessions never coexist: an open one whose pocket elapsed closes before a new `session_started` appends.
- One calendar authority converts instants to day/week/season (04:00 day, Monday-anchored week, Sunday last); energy is day-scoped — the last `energy_set` of the current domestic day, defaulting llena at each boundary, never carried across one.
- `warmReturnDue` is the single sibling of the one `EligibleDay(item, day)` predicate, and one of the log's stated reader exceptions for system events.
- Focus-slot occupancy closes only on a `card_done` (a skip re-resolves identity and consumes nothing); a mid-day Time Bag change re-resolves identity and never re-opens a closed slot; raising the bag from below 10 to 10+ composes a Focus Chunk iff none was dealt that day.
- New log kinds land additively under forward-only evolution: `session_extended`, `energy_set`, `setting_changed`, `report_answered` (carrying the answered week); unknown kinds are tolerated, payloads additive-only.
- Strip resident precedence is one total order: rarest eligible frequency first (once-ever first-run curation offer, then once-per-box quarantine follow-up, then once-per-season suggestion, then snowball, then weekly self-report, then daily check-in), ties broken by earliest-eligible instant, then stable id. A displaced resident is neither consumed nor dismissed — it re-offers at the next opening; only ✕ is a dismissal.
- The core stays pure and deterministic: no `Random`, wall-clock reads, `dart:io` or ambient state inside it; ordering derivations read recorded act instants, never id bit patterns.
- Testing shape: core invariants via `dart test` on the machine, no emulator; widget tests only where a surface consumes the read facade or a command; no golden tests. The report/check-in slot handoff is deterministic and tested as such. Completion gate: `flutter test`, `dart format --set-exit-if-changed .`, `flutter analyze` — one `make gate`, inside `devbox shell`.

## UX & Interaction Patterns

- `Nuevo proyecto`: quiet text affordance, bottom-centred, ink-secondary text in the `action-secondary` pattern — never animated, never emphasised, never badged, no pastel mass. Settings is reachable from inside it as a quiet text way-out, and is the only route into the validator surface from any surface within three taps of the Dispenser.
- Settings is a flat platform list of five quiet groups; this epic builds the shell plus the **Tu día** group (Time Bag). Light/dark follows the system with no settings row. No "settings" glyph exists anywhere — it was dissolved.
- The pocket trigger renders as a `duration-chip`; out-of-range input is refused by the trigger surface with no error state.
- The `ambient-strip` sits below the card: a sentence in support type and ink-secondary, tappable where an accept action exists (never primary), ✕ dismissal at 48dp, at most one resident visible at a time. Chrome rule: ephemeral residents sit bare, persistent ones carry a 1px hairline — the check-in is bare; the self-report is hairlined with its numeric 1–5 row inline.
- Energy check-in: three battery marks (llena / media / baja) as direct tap targets — casing and nub line-only, the charge a registered mass filling from the left with no offset (documented exception, closed-container rule); selected charge `icon-mass-blue` with `ink-primary` casing, unselected neutral with `ink-secondary`; llena pre-marked as standing default. `icon-mass-blue` marks state only, never a meaning.
- Checkpoint: `Nada más por el momento` is the primary message; `Quiero seguir` is the silent secondary. Warm Return shows `Siempre a tu disposición` with the rebalanced card — cold start stays card-first at ≤ 2 s.
- Accessibility floor: nothing ellipsized or truncated at 200% font scale — surfaces grow and scroll; touch targets never below 48dp; stopping always costs one tap; haptics never the sole signal.

## Cross-Story Dependencies

- Builds on Epic 1: the session already exists as log facts (open on entry, close on background) and gains the other two closing causes here; the pocket field is added to `session_started` additively. Tokens, the ARB string table, `dispenser-card`, `duration-chip` and the unsplit secondary control all arrive from Epic 1.
- The `Nuevo proyecto` surface is shared across epics: this epic builds the affordance carrying the Settings way-out alone; Epic 5 later adds typed genesis as that surface's recommended action. Settings groups grow additively — Epics 4, 5, 8 and 9 each add their own group.
- The ambient strip is built here with its first two residents (daily check-in, weekly self-report); Epics 5, 6 and 7 add residents as data under the same precedence order, and the displaced-resident/dismissal rules must hold for all six.
- The session derivation (2.2) and the `EligibleDay` substrate feed Epic 3's capture deal window; the original-pocket reading of `session_extended` (2.4) is what Epic 7's snowball comfortable-day predicate consumes.
- The low-energy filter must leave in-flight rescue chains (Epic 4) and the purge-first guarantee (Epic 6) intact — their ≤ 60 s steps stay eligible, and the purge guarantee defers to the next non-low day.
- `Otra más fácil`, the other half of Epic 1's unsplit secondary, arrives with Rescue Mode in Epic 4 — a shared control completed across epics, by design, not a defect.

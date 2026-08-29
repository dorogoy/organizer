# Epic 1 Context: The Day That Deals Itself

<!-- Compiled from planning artifacts. Edit freely. Regenerate with compile-epic-context if planning docs change. -->

## Goal

A fresh install in airplane mode — no key, no account, no model — puts one household Micro-task on screen within two seconds and lets the user complete it or pass on it. This is the vertical slice that proves the paradigm: the pure-Dart functional core, the insert-only substrate, the one calendar authority, the shipped Evergreen catalogue, the 1-3-5 weave and the single-card Dispenser. It also establishes the build-wide invariants later epics inherit: the no-overdue schema, determinism, the single ARB string table, the pinned stack and the devbox/Makefile development loop.

## Stories

- Story 1.1: The sealed scaffold
- Story 1.2: Both palettes, the glyph set and the single string table
- Story 1.3: The insert-only substrate
- Story 1.4: One calendar authority
- Story 1.5: The shipped Evergreen catalogue
- Story 1.6: The 1-3-5 weave and the Focus Chunk slot
- Story 1.7: Zone rotation, `fondo` fill and the below-floor fallback
- Story 1.8: One card on screen
- Story 1.9: `Hecho`
- Story 1.10: The unsplit secondary control — the skip half
- Story 1.11: Proof that lateness cannot be expressed

## Requirements & Constraints

The Dispenser shows exactly one actionable Micro-task, always with its estimated duration; no screen within three taps shows two. `Hecho` completes in one tap with no confirmation, the next card arrives in under 500 ms, and feedback is a small warm haptic plus something visible — never modal; `¡Buen trabajo!` is the only exclamation anywhere. `Ahora no` records no failure and no cumulative skip total; the alternative respects energy and remaining budget; pool exhaustion closes the session with the fixed warm string `por hoy no hay nada más que merezca la pena`, never an error and never styled as absence or debt.

The day composes as 1 Focus Chunk (10–15 min) + 3 Micro-maintenance + 5 Instant Habits, scaled to the Time Bag and energy. The chunk slot is reserved for advance work — Baseline Upkeep never occupies it however well its size fits — and a bag below 10 minutes composes with no chunk, silently. This epic runs on defaults: bag 15 minutes, energy 🟢, no surface to change either. Exactly one FlyLady zone is active per day, rotating weekly over active clusters; `fondo` fills an exhausted zone before any repetition.

The catalogue ships as fixed build-time content: four fields per entry (permanent id, 1-3-5 size, cadence, zone-or-none), at least 28 distinct 10–15 min non-daily eligible entries (3-minute entries can never fill the chunk slot), curation at cluster level only, no screen enumerating individual entries, and never user-authored or extended.

Execution is offline by default — airplane mode is a supported condition, never an error. Cold start to first card ≤ 2 s, hardest on day one. No account, owner column, network requirement, lateness/debt/missed state, future assignment, backlog, streak or task list anywhere. All copy is Spanish in one ARB table with no runtime sentence concatenation. The 200% font-scale floor is met by growing and scrolling, touch targets ≥ 48dp. The core is deterministic: no `Random`, wall-clock read, `dart:io` or ambient state. Stack: Flutter 3.47.x / Dart 3.13, minSdk 33, target SDK 36, 64-bit ABIs only, no `material_ui`/`cupertino_ui`. Development runs in devbox (official sha256-pinned Flutter tarball, never nixpkgs) with the root `Makefile` as the single entry point; `make gate` runs `flutter test`, `dart format --set-exit-if-changed .` and `flutter analyze` — the story completion gate.

## Technical Decisions

- Functional core / imperative shell, dependencies inward only. The core is pure Dart — no `flutter`, `drift` or plugin imports, no adapter names inside, adapters return inert DTOs — enforced by a machine check. Only the `Clock` and `Store` ports are declared here; the other five arrive with their first consumer.
- Exactly two persisted stores, both insert-only: SQL triggers declared in a `.drift` file raise on `UPDATE` and `DELETE`. Pool facts carry a shell-minted UUIDv7 id, an immutable origin (`shipped`/`manual`/`local`/`cloud`), a 1-3-5 size enum, and the creation instant plus the local offset in force; no date-only columns, no owner column. A store seal forbids any third replayable domain store.
- Nothing derived is stored: the day's composition, next card, session and pool membership are pure functions of `(pool, log, day, session)`. `nextCard()` writes nothing; `card_dealt` is appended by commands only, with `session_started` writing a session's first card. Ties break by least-recently-dealt, then stable id. Log kinds written here: `app_opened`, `session_started`, `card_dealt`, `card_done`, `card_skipped`, `session_ended`; `crash_recorded` (stack + timestamp, nothing else) is the only diagnostics destination.
- One `Calendar` is the sole instant-to-period authority: domestic day `[04:00 local, 04:00 local next)`, weeks anchored on Monday, meteorological seasons. Days are computed from the offset stored on each entry, so travel, clock corrections and DST never re-date history.
- The read facade exposes no collection of pending or captured tasks; derived signals are named as facts. `core/weave`'s single resolver is the only code that may emit a deal — everything else returns candidates with precedence. The Focus Chunk slot closes once per domestic day only via `card_done` and belongs to the dealing session's day; a skip re-resolves identity and consumes no rotation.
- The catalogue is a versioned read-only asset under `assets/evergreen/`. Spanish names are ARB entries keyed by catalogue id — the name is not in the asset — resolved by a named shell loader at load time (a shipped task's Origin Context is that name). A floor check enforces the 28-entry minimum; an id-diff check fails on any id that disappears or changes size; a core test asserts 28 dealt chunks never repeat.
- Zone rotation runs over active clusters only — a disabled zone's week passes to the next active zone, so curation never leaves a day without an active zone. When curation drops the eligible pool below the floor, the fallback order is: the zone's own entries, then `fondo`, then the least-recently-dealt eligible entry regardless of zone — repetition accepted, never an empty day. Weekly clusters change at the next week boundary; daily and `fondo` clusters change immediately. With every cluster disabled, the day composes no deals and the session closes with the same warm string.
- Guards land with the code: core purity, catalogue floor, catalogue id diff, store seal, the no-literal-strings lint, the forbidden-vocabulary lint (`overdue`, `late`, `missed`, `pending`, `debt`, `streak`, `skippedCount`, `dueDate`, `backlog`) and the text-scaling lint (bans `maxLines`, ellipsis, `FittedBox`, `TextScaler` overrides and fixed-height text containers). Every new `tool/` check registers its Makefile target in the same pass.

## UX & Interaction Patterns

- Tokens live once in `lib/ui/tokens.dart`: field tier at Aliento baseline, icon-mass tier at L\* 76.0 exactly (the two tiers never touch), a separately authored dark palette (never an inversion), eight type roles — Lora for task text only, Lexend for the other seven, `sp` sizes with multiplier line-heights — three radii (14 default, pill for time quantities, 4 for album thumbnails) and a 4dp spacing scale. Theme follows the system with no settings row.
- Card order top to bottom: `duration-chip` eyebrow (accent-soft pill, tight 8dp above the task — proximity is the mechanism), task in Lora, full-width `Hecho` filled accent-soft, the unsplit text-only secondary in ink-secondary, then the Hoja zone-marker as a quiet 24px footer — a place-marker, never a control.
- Flat depth only: tone plus a 1px hairline; no shadow, gradient or glow. Cold open has no splash and no loader before the first card. Air around the card is a 48dp minimum plus flex, never a fixed value.
- `Hecho` needs one tap; the completed card exits the screen entirely, never toward a counter, pile or badge; celebration is identical every time, closes rather than opening a door, and never delays the next card past 500 ms.
- The secondary control `Otra más fácil / Ahora no` is text only — no box, fill, underline or animation; at 200% its fold is accepted and must be verified on a real device; the string is never split, shortened or ellipsized.
- Ten printed-matter glyphs with one global 45° offset (`translate(1.358, −1.358)`, 8% of rendered size), mass under line; the seed has exactly 8 filaments, its axis at 45.0°, and draws at rest at every size — motion dashes were dissolved and must never be drawn. No Ajustes glyph exists. Interim accessibility: no custom semantics, platform traversal order.
- Every string entering the table is checked against the Voice-and-Tone do/don't table; fixed strings ship verbatim.
- Two implementation checks gate completion: the seed's pompom radius is recorded in Story 1.2 (larger than 1.70u, displaced toward the leeward edge, free edge under filaments); the 24px zone-marker is verified readable on a real handset in light and dark before Story 1.8 completes.

## Cross-Story Dependencies

- Tokens and the string table (1.2) precede the catalogue (1.5) because catalogue names are id-keyed ARB entries.
- The substrate (1.3) and calendar (1.4) underpin catalogue loading, composition, rotation and the Dispenser; 1.11 machine-checks their no-lateness property. The Silent Rescheduler is discharged as this proven property — no such code exists, because nothing was assigned to a future day.
- The session exists here only as a log fact: open on app entry, close on backgrounding. Epic 2 adds the declared pocket, pause and checkpoint additively, plus the settable Time Bag and the energy check-in.
- The secondary control ships with its final string but only the skip half wired; `Otra más fácil` (Rescue Mode) arrives in Epic 4 — a shared component completed across two epics, not a forward dependency. Catalogue curation surfaces arrive in Epic 5; this epic ships the all-clusters-active default.
- Story 1.11's "no milestone overdue" clause is vacuous until Epic Projects exist; Story 5.5 tests the same property for real once buffers land.

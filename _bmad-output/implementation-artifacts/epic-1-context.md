# Epic 1 Context: The Day That Deals Itself

<!-- Compiled from planning artifacts. Edit freely. Regenerate with compile-epic-context if planning docs change. -->

## Goal

A fresh install — in airplane mode, with no key, no account and no model — puts one household Micro-task on screen within two seconds and lets the user complete it or pass on it. This is the vertical slice that proves the product's whole paradigm: a pure-Dart functional core inside a Flutter shell, an insert-only substrate, one calendar authority, a shipped Evergreen catalogue, automatic 1-3-5 daily composition, and a single-card Dispenser. Every later epic extends this slice rather than replacing it; the invariants established here are inherited build-wide.

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

Covers: single-card viewport, nothing within three taps of the Dispenser shows two actionable Micro-tasks, and every dealt card shows its estimated duration; one-tap `Hecho`, next card < 500 ms, non-intrusive feedback; guilt-free skip (`Ahora no`) records no failure and consumes no rotation, with pool exhaustion closing on the fixed warm string `por hoy no hay nada más que merezca la pena`; Evergreen active by default with exactly one zone active per day; the 1-3-5 composition (one 10–15 min Focus Chunk + 3 Micro-maintenance + 5 Instant Habits) scaled to the Time Bag and derived energy, the chunk slot reserved for advance work — Baseline Upkeep never occupies it; no silent rescheduler as code — nothing is ever assigned to a future day, so lateness is inexpressible and is proved so by test and lint; and a pre-sliced catalogue fixed at build time: four fields per entry, ≥ 28 distinct 10–15 min non-daily entries (3-minute entries never count), cluster-level curation only, never user-authored or enumerated below cluster level.

Build-wide constraints this epic establishes and the rest inherit: execution offline by default — airplane mode is a supported condition, never an error; cold start to first card ≤ 2 s, Done→next < 500 ms; a 200% font-scale floor met by growing and scrolling, 48dp minimum touch targets, no goal reachable only by typing (the shipped catalogue needs no keyboard); all Spanish copy in one ARB string table, no runtime sentence concatenation (one atomic value substituted into a fixed sentence is permitted); no identifier anywhere may express lateness, debt or a missed occurrence — lint-banned vocabulary: `overdue`, `late`, `missed`, `pending`, `debt`, `streak`, `skippedCount`, `dueDate`, `backlog` (`Due` as a derived-fact suffix is allowed); single-user, account-free data, no owner column; a deterministic core — no `Random`, wall-clock read, `dart:io` or ambient state; the pinned stack (Flutter 3.47.x / Dart 3.13, minSdk 33, target SDK 36, 64-bit ABIs only, no `material_ui`/`cupertino_ui` dependency); the three-command completion gate (`flutter test`, `dart format --set-exit-if-changed .`, `flutter analyze`) as one root-Makefile `gate` target CI invokes identically; and a devbox-owned environment (`devbox.json` + committed `devbox.lock`; Flutter from the sha256-pinned official tarball of the 3.47 line — never the nixpkgs package, which lags the line's patches).

## Technical Decisions

- Functional core / imperative shell, hexagonal. Seven ports exist in the design; only `Clock` and `Store` are declared in this epic — each remaining port arrives with its first consumer. The core declares no `flutter`, `drift` or plugin dependency (machine-checked), names no adapter, and adapters return inert DTOs.
- No plan is ever stored. The day is a pure function of (pool, log, day, session). `nextCard()` is pure and writes nothing; `card_dealt` is appended by a command — the session's first card by `session_started` — never by rendering, so an unanswered card leaves no second deal. Ties break by least-recently-dealt, then stable id, reading recorded instants, never id bit patterns.
- Exactly two persisted stores — task pool and event log — both insert-only via SQL triggers declared in a `.drift` file and created in the initial migration; corrections are new entries, never edits. Pool facts carry a shell-minted UUIDv7 id, an immutable origin (`shipped` / `manual` / `local` / `cloud`), a 1-3-5 size enum, and creation instant plus the local offset in force; no date-only columns anywhere. A store seal check forbids any persistence API outside `Store`.
- One calendar authority in `core/day` is the only instant→period conversion in the codebase, Kotlin included: day = `[04:00 local, 04:00 local next)`, week = Monday-anchored seven domestic days, season = three-month meteorological quarter. Days are computed from the offset stored on the entry, never the device's current zone — travel never re-dates history; DST never creates or destroys a period. Energy is day-scoped, defaults to green at each boundary, and the default is derived, never written.
- The read facade structurally forbids lists: no function returns a collection of pending or captured tasks; `nextCard()` returns at most one card; derived signals are named as facts, never actions.
- One resolver owns the Focus Chunk slot and is the only deal-emitter; every other work source returns candidates with precedence — the extension point later epics feed without reopening composition. Occupancy is not identity: a skipped chunk re-resolves to a different candidate with the slot open and no rotation consumed; at most one chunk is answered `Hecho` per domestic day, charged to the day its dealing session belongs to; a bag below 10 minutes composes with no chunk, silently; the below-floor fallback runs zone entries → `fondo` → least-recently-dealt eligible entry — repetition, never an empty day.
- The catalogue is a versioned read-only asset under `assets/evergreen/`: per entry a permanent id, size, cadence, zone-or-none — nothing else. The Spanish name is an ARB entry keyed by id, not in the asset, so catalogue copy is audited like every other string; a `shipped` task's Origin Context is that Spanish name, resolved at load time by the named shell loader and handed to the core as inert data (this is what later makes catalogue entries re-sliceable). Floor and id-permanence are build-time checks — the id-diff check proves its own failure mode against a mutated fixture even in the greenfield build — and a 28-deal no-repeat rotation test covers the default curation state.
- Log vocabulary written here: `card_dealt`, `card_done`, `card_skipped`, `session_started`, `session_ended`, `app_opened`, plus `crash_recorded` (stack and timestamp only, nothing else) from a startup-installed handler — the build's only diagnostics destination, with no logging framework. Unknown entry kinds are tolerated and skipped by derivations; payloads evolve additively only.
- The session is a log fact, not a feature: opened on app entry, closed on backgrounding — later epics add the pocket, pause and checkpoint to it additively. Shell state management is Riverpod, shell-only. Pinned versions include drift 2.34.3 (+ `drift_flutter`) and `uuid` 4.6.0. `tool/` checks landing here: core purity, catalogue floor, catalogue id diff, no-literal-strings, plus the forbidden-vocabulary and text-scaling lints; the root Makefile is created in Story 1.1 and every story that adds a check registers its target in the same pass.

## UX & Interaction Patterns

- One token file (`lib/ui/tokens.dart`) holds every design constant once — field-tier colours, an icon-mass tier at exactly L\* 76.0 that never touches the field tier, a separately authored dark palette (never an inversion), eight typography roles (Lora for task text only, Lexend for the other seven; `sp` sizes with multiplier line-heights), three radii, spacing — referenced nowhere else by literal. Theme follows the system with no settings row.
- Ten glyphs including the dandelion seed (exactly eight filaments, 45° axis). The seed draws at rest at every size — its motion-dash lever is dissolved and no flag or threshold may reintroduce it. No Ajustes glyph exists: Settings is reached as quiet text.
- Dispenser anatomy: a `duration-chip` eyebrow 8dp above the task; task text in Lora; full-width `action-primary` (`Hecho`, filled `accent-soft`, radius 14, 48dp, one tap, no confirmation) sitting 32dp below the task as the largest interior gap; the unsplit text secondary `Otra más fácil / Ahora no` (plain text, no fill or animation, 48dp target); the `zone-marker` (Hoja) as a quiet footer place-marker at 24px, never a control. Celebration is `¡Buen trabajo!` — the one permitted exclamation — identical every time, closes rather than opening a door, never delays the next card past 500 ms. A completed card exits the screen entirely, never toward a counter, pile or badge.
- Flat depth only: tone plus a 1px hairline; no shadow, gradient or glow. Cold start shows no splash and no loader before the first card. Nothing on the Dispenser or within three taps may take the shape of a list, calendar, backlog, counter, streak, badge or overdue indicator.
- Interim screen-reader convention: no custom semantics, no manual announcements, platform traversal order.
- Two on-device checks gate their stories: the zone-marker's 24px readability in light and dark (Story 1.8), and the seed's pompom radius recorded within its coverage constraint (Story 1.2).

## Cross-Story Dependencies

- Story 1.2 must land before 1.5: catalogue names are string-table entries keyed by id.
- 1.3 (substrate) and 1.4 (calendar) precede 1.5–1.7 (catalogue and composition), which feed 1.8–1.10 (surface and controls); 1.11 proves properties of all of it.
- The declared pocket, pause and checkpoint belong to the next epic and attach to the session additively — this epic writes only open-on-entry / close-on-backgrounding.
- This epic runs on defaults (15-minute bag, green energy, no Settings surface); a later epic makes both settable as additive inputs, not a rewrite.
- The secondary control's rescue half (`Otra más fácil`) is completed with Rescue Mode in a later epic, and the curation surfaces the catalogue supports are not exposed here — shared components finished across epic boundaries, by design, not defects.
- One of 1.11's criteria (no milestone overdue) is vacuous until projects with milestones exist; it is re-verified for real once buffers land in a later epic.

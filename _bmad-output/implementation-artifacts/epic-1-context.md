# Epic 1 Context: The Day That Deals Itself

<!-- Compiled from planning artifacts. Edit freely. Regenerate with compile-epic-context if planning docs change. -->

## Goal

A fresh install — in airplane mode, with no key, no account and no model — puts one household Micro-task on screen within two seconds and lets the user complete it or pass on it, with no list ever shown. This is the vertical slice that proves the whole product paradigm: the pure-Dart functional core, the insert-only substrate, the one calendar authority, the shipped Evergreen catalogue, the automatic 1-3-5 daily composition, and the single-card Dispenser surface. Everything later epics build (settable Time Bag, capture, the Slicer, projects, letting-go flows, dashboards, notifications, export) extends this slice rather than replacing it.

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

Covers: single-card viewport, nothing within 3 taps shows two actionable tasks; one-tap completion with next card <500ms and non-intrusive feedback; guilt-free skip recording no failure, pool exhaustion closing with a fixed warm string; Evergreen active by default with one zone per day; automatic composition scaled to time budget and energy; no silent rescheduler needed (nothing is ever assigned to a future day); a pre-sliced catalogue with four fields per entry, ≥28 eligible 10–15min units, cluster-level curation only, fixed at build time.

Build-wide constraints established here, inherited by every later epic: offline-by-default execution (airplane mode supported, never an error); cold start to first card ≤2s, completion→next card <500ms; a 200% font-scale floor with no ellipsis/truncation/fixed-height text containers; Spanish copy fully externalized in one string table with no runtime concatenation; nothing in schema or UI may express lateness/debt/a missed occurrence (lint-enforced); single-user/account-free data model; deterministic composition (no randomness, wall-clock read or ambient state in the core); a three-command completion gate run through one root Makefile target; the whole toolchain provisioned via a reproducible dev-environment tool, never the host toolchain; fixed Android SDK floor/target, 64-bit ABIs only.

## Technical Decisions

- **No plan is ever stored.** The day is a pure function of (pool, log, day, session), recomposed on every read; a deal is written only by the dealing command, never by rendering — an unanswered card leaves no second write.
- **Two persisted stores only** — a task pool and an event log — both insert-only, enforced by database-level triggers that reject any update/delete. Pool rows carry an immutable origin, a stable id, a 1-3-5 size, and instant+offset; no date-only columns, no owner column.
- **One calendar authority.** A single component is the only code anywhere that computes day/week/season boundaries: day = a fixed early-morning-to-early-morning window, week = Monday-anchored, season = meteorological quarter. Boundary computation always uses the offset stored on the entry, never the device's current zone.
- **Core purity is machine-enforced.** The core package has no framework, database or plugin dependency and only two ports at this stage — clock and store — checked by an automated script that fails the build and names offenders.
- **The read facade structurally forbids lists.** No function returns a collection of pending/captured tasks; the next-card query returns at most one card; derived signals are named as facts.
- **One composer is the sole deal-emitter; everything else offers precedence-ordered candidates** — the extension point later epics (capture, projects, rescue) plug into without reopening this epic's composition logic. Ties break by least-recently-dealt, then stable id.
- **The catalogue is a build-time asset**, four fields per entry (id, size, cadence, zone-or-none); Spanish names live in the string table keyed by id, not in the asset, so catalogue copy is audited like any other string. An id-diff check fails the build if a shipped id disappears or changes size; a floor check requires ≥28 distinct non-daily mid-length entries.
- **The single string table is authoritative.** One generated-accessor layer sits over it; a lint bans literals in widgets and bans runtime sentence concatenation.
- **Log vocabulary established here:** deal, done, skipped, session-started/ended, app-opened, crash-recorded; unknown kinds are tolerated and skipped by derivations (forward-only evolution).
- **A session is a derived log fact, not a feature** — opened on app entry, closed on backgrounding — set up so later epics' pocket/pause/checkpoint additions extend it additively.

## UX & Interaction Patterns

- One token file (`lib/ui/tokens.dart`) holds every design constant once — field-tier colours, icon-mass colours (fixed lightness, never mixed with field tier), a separately authored dark palette (never an inversion), an eight-role typography ramp (Lora for task text, Lexend for the other seven roles), three radii, spacing — referenced nowhere else by literal. Theme follows the system with no override setting.
- Ten glyphs total; no Ajustes (settings) glyph — Settings is reached as quiet text only.
- Dispenser layout: a `duration-chip` eyebrow above the task, task text in Lora, a full-width `action-primary` (`Hecho`, 48dp, one tap, no confirmation, celebration string `¡Buen trabajo!`), the unsplit `action-secondary` control `Otra más fácil / Ahora no` (only its `Ahora no` skip half is wired this epic — the rescue half arrives with the Slicer epic), and a quiet `zone-marker` footer glyph that is a place-marker, never a control.
- Flat depth only: tone plus a 1px hairline, no gradients/glow/shadow. A completed card exits the screen entirely, never animating toward a counter or badge.
- Nothing on the Dispenser or anywhere within three taps may take the shape of a list, calendar, backlog, counter, streak or overdue indicator.

## Cross-Story Dependencies

- Story 1.2 (tokens/string table) must land before Story 1.5, because catalogue entry names are string-table entries keyed by id.
- Stories 1.3 (substrate) and 1.4 (calendar) are prerequisites for 1.5–1.7 (catalogue and composition), which in turn feed 1.8–1.10 (the rendered surface and its two controls).
- Story 1.11's "no milestone overdue" criterion is vacuous until a later epic introduces milestone-bearing projects; it is re-verified for real then.
- This epic runs entirely on defaults (fixed daily time budget, default energy, no Settings surface) — a later epic makes both settable.
- The secondary control's rescue half and Settings itself are completed by later epics — not defects, but components intentionally finished across epic boundaries.
- A later epic adds the curation surfaces (cluster-level enable/disable) that this epic's catalogue is built to support but does not itself expose.

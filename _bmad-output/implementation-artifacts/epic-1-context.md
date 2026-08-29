# Epic 1 Context: The Day That Deals Itself

<!-- Compiled from planning artifacts. Edit freely. Regenerate with compile-epic-context if planning docs change. -->

## Goal

A fresh installation works in airplane mode, with no account, key, or model: it shows one household Micro-task within two seconds and lets the user complete or pass on it. This vertical slice establishes the pure-Dart core, durable facts, calendar, shipped Evergreen content, automatic composition, and single-card Dispenser that later epics extend rather than replace.

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
- Story 1.10: The unsplit secondary control - the skip half
- Story 1.11: Proof that lateness cannot be expressed

## Requirements & Constraints

The Dispenser shows one actionable Micro-task, including its duration; no surface within three taps shows two. `Hecho` takes one tap, brings the next card in under 500 ms, and gives quiet, non-blocking acknowledgement. `Ahora no` is guilt-free: it records no failure, re-resolves to another candidate, and does not consume rotation. An exhausted pool closes warmly rather than presenting an error or empty state.

Evergreen is active by default. The daily weave is one 10-15 minute Focus Chunk, three Micro-maintenance tasks, and five Instant Habits, scaled to the default 15-minute Time Bag and green energy. The Focus Chunk is advance work, never Baseline Upkeep. One active FlyLady zone rotates weekly; `fondo` fills an exhausted zone before repetition. The fixed build-time catalogue has only permanent id, size, cadence, and zone-or-none; it must supply at least 28 distinct eligible non-daily 10-15 minute entries and must never be user-authored or exposed as individual task content.

Execution is offline by default. The first card must appear within two seconds, including day one. There is no account, owner field, network requirement, lateness/debt/missed-state data, future assignment, backlog, streak, or task list. All copy is Spanish in one ARB table, with no runtime sentence construction. The app must support 200% font scale through growth and scrolling, use 48dp minimum targets, and avoid goals requiring typing. The core is deterministic and free of ambient time, `Random`, and `dart:io`. Android targets SDK 36 with minSdk 33 and 64-bit ABIs. Development runs through devbox with the sha256-pinned official Flutter 3.47.x SDK; `make gate` and CI run `flutter test`, format checking, and analysis.

## Technical Decisions

- Use a functional core and imperative Flutter shell. Only `ClockPort` and `StorePort` are introduced here; the core has no Flutter, Drift, plugin, or adapter dependency and adapters return inert DTOs.
- Persist only immutable pool facts and append-only log events. SQL triggers in the initial `.drift` migration reject updates and deletes. Pool ids are shell-minted UUIDv7; facts include immutable origin, 1-3-5 size, instant, and recorded local offset. The store seal prevents other replayable domain persistence.
- Derive the day, composition, session, settings, pool membership, and next card from pool, log, domestic day, and session. Rendering never writes a deal. Commands append `app_opened`, `session_started`, `card_dealt`, `card_done`, `card_skipped`, and `session_ended`; diagnostics append only a timestamp and stack in `crash_recorded`.
- `Calendar` is the sole instant-to-period authority: domestic days run 04:00 local to 04:00 local, weeks begin Monday, and seasons are meteorological quarters. Use each fact's recorded offset, so travel and DST do not re-date history.
- The read facade exposes no collection of captured or waiting tasks. `nextCard()` returns at most one card, and derived signals are facts rather than commands. One resolver is the sole deal emitter; other sources provide candidates with precedence. A skipped Focus Chunk leaves its slot open, while only `Hecho` occupies the slot for the dealing session's domestic day.
- Keep the catalogue as a versioned read-only asset. Spanish names are ARB entries keyed by catalogue id, not asset fields. Enforce core purity, forbidden vocabulary, string-table usage, font-scaling rules, catalogue floor and id continuity with checks; test the default 28-deal rotation.

## UX & Interaction Patterns

- Define tokens once in `lib/ui/tokens.dart`: separately authored light and dark palettes, field and icon-mass tiers, typography, radii, and spacing. Lora is task text only; Lexend serves all other roles. Theme follows the system with no override.
- The Dispenser card orders duration chip, task, full-width `Hecho`, unsplit text-only `Otra más fácil / Ahora no`, and a quiet Hoja zone marker. The marker is a place label, never a control. `Hecho` needs no confirmation; its acknowledgement never delays the next card, and the completed card leaves the screen rather than moving toward an accumulating surface.
- Preserve flat depth: tone plus a 1px hairline, never shadows, gradients, or glow. Cold open has neither splash nor loader before the card. The secondary control may fold at 200% but is never split, shortened, ellipsized, or hard-broken.
- Use the printed-matter ten-glyph set, with the seed at rest and no Ajustes glyph. Interim accessibility uses platform traversal without custom semantics or announcements.

## Cross-Story Dependencies

- The string table and generated accessors precede catalogue content because catalogue names are id-keyed ARB entries.
- The substrate and calendar underpin catalogue loading, composition, rotation, and the Dispenser; the final story verifies their no-lateness properties.
- This epic opens a session on entry and closes it on backgrounding. The next epic adds declared pockets, pause, checkpoint, and user-set Time Bag and energy as additive inputs.
- The secondary control's Rescue Mode half and catalogue curation surfaces land in later epics; this epic ships only the skip behaviour and default catalogue state.

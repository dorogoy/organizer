# Epic 6 Context: Letting Go Without Guilt

<!-- Compiled from planning artifacts. Edit freely. Regenerate with compile-epic-context if planning docs change. -->

## Goal

Before the app asks the user to organize anything, it makes them clear things out: the first dealt Micro-task of a newly activated organizing project is always a purge step, carrying the two detachment questions that do the real work and the 3-Destination Flow — three choices of genuinely equal weight, none worded, styled or ordered as the bad one. Hesitation is a valid outcome, not a decision to re-open: undecided items go into a dated Quarantine Box whose blind six-month follow-up never claims to know what happened to its contents. Every letting-go decision leaves one honest, coarse trace that becomes the cumulative declutter metric — framed only as what letting go produced, never what it cost. This epic is the producer; Epic 7's dashboard renders the figures written here.

## Stories

- Story 6.1: Purge comes first
- Story 6.2: The two detachment questions
- Story 6.3: The triage act — `item_triaged` with destination and coarse volume
- Story 6.4: Three destinations of equal weight
- Story 6.5: The Quarantine Box, derived from the log
- Story 6.6: The blind six-month follow-up
- Story 6.7: The cumulative declutter metric

## Requirements & Constraints

- **Purge injection:** when an organizing Epic Project activates, purge Micro-tasks are prepended before any organization step; the first dealt card is always a purge step. A purge step renders as an ordinary dispenser card — never styled, framed or announced as a different kind of work. The Decluttering Protocol is reached from the Dispenser when the dealt Micro-task is a decision about an object — never from a menu or list.
- **Detachment questions:** two mandatory questions — the factual one (used in the past 12 months?) and the one that does the real work (does this deserve your physical and mental space?). Each offers only `Sí`/`No`; no skip affordance exists. After both answers, choosing one of the three destinations is required. Question copy carries no pressure framing and sits in the anti-shaming string audit.
- **Destinations:** three of equal weight, internal concept names keep/donate-sell/trash-recycle, surfaced verbatim as `Quedármelo` / `Donar o vender` / `Tirar o soltar`. The third label is never `Tirar o reciclar`, never a bin word, never a recycling word.
- **Quarantine Box:** hesitated items go to a dated box; follow-up exactly six months after the box's date, at most once per box, dismissible in one tap with zero side effects and no return. Copy is phrased on the date alone and claims no knowledge of the box's contents or use.
- **Declutter metric:** per-destination item counts derived only from taps during purge steps — nothing inferred from photographs. Volume tags are optional, coarse, from exactly `bolsa` / `caja` / `caja grande` / `mueble` — never a number; absent tags simply do not contribute. Displayed as an approximation with its unit visible (shape: `≈ 3 cajas liberadas`), never precise, never a percentage; only as cumulative achievement — never a target, rate or deficit.

## Technical Decisions

- **Candidate precedence, not a weave special case:** purge injection returns candidates with precedence to the single resolver in `core/weave`; `core/weave` stays the only code that emits a deal.
- **Substrate is the log, no new tables:** a triage appends an `item_triaged` user act carrying the destination and optional coarse volume tag; quarantining appends a `box_created` act (the box's date) plus an `item_triaged` with destination `quarantine` linked to that `box_created` id. The Quarantine Box is reconstructed from these acts — no quarantine table, and its follow-up is derived from the box's instant, never a stored date.
- **Destination vocabulary is data:** exactly the three surfaced destinations, with `quarantine` arriving as a later additive value; nothing else may ever be added (forward-only substrate evolution — unknown kinds tolerated, payloads additive).
- **Log discipline:** entries are facts; no entry asserts an absence or obligation. Identifiers never contain the forbidden vocabulary (`overdue`, `late`, `missed`, `pending`, `debt`, `streak`, `skippedCount`, `dueDate`, `backlog`). Ids are UUIDv7 minted in the shell; entries carry a UTC instant plus local offset.
- **Metric figures cross to the shell as achievement figures only** (rendered on the dashboard Epic 7 builds); internal signals never cross as numbers.
- **Strings:** every string externalised in the single ARB table, no runtime sentence concatenation.
- **Code homes:** the Decluttering Protocol lives in `core/pool`, `core/log` and `ui/destinations`.

## UX & Interaction Patterns

- **`destination-flow`:** a full-screen surface — a question, the object, three choices, nothing else. Three rows, each a 64px glyph beside its label (`destination-label`: Lexend 19sp/600, 1.25 line-height), 32dp row gap. No tile, no field, no default, no pre-selection, no ordering signal.
- **Hue lives only inside each glyph:** a destination hue never appears as a field, tile, bar or band without its glyph inside it. Silhouette alone carries the three-way differentiation (including for reduced colour vision) — this is load-bearing and non-negotiable.
- **Seed glyph (third destination):** exactly 8 filaments, axis at 45°, drawn at rest — motion dashes were dissolved outright and may not be reinstated on any surface.
- **Dark mode:** the destinations keep their light form unchanged (two plates, global offset, mass under line) with the line in the dark ink and the mass in the dark destination hues.
- **Six-month follow-up is an ambient-strip resident:** sentence in support typography, one-tap dismissible (48dp target), never a primary action, at most one resident visible; ephemeral residents render bare (no hairline).
- **The volume line carries no glyph** (glyph-adjacency rule: a destination glyph appears only where the destination it names is the meaning being expressed — the system's only box glyph is `Quedármelo`).

## Cross-Story Dependencies

- **Epic 5 precedes this epic:** there is nothing to purge until Epic Projects exist; purge injection fires on activation of an organizing Epic Project (genesis built in Epic 5).
- **Story order:** 6.1 → 6.2 → 6.3 → 6.4 → 6.5 → 6.6; 6.7 depends on 6.3 (the metric derives from `item_triaged`) and must land before Epic 7 opens. (Epic re-partitioned 2026-09-09 from five stories into these seven; criteria redistributed, none lost.)
- **Epic 7 consumes this epic's output:** the dashboard renders the per-destination counts and volume tags written here; nothing there recomputes them.
- **Ambient strip is shared infrastructure** (built in Epic 2): 6.6 adds its resident through the shared resident write path extracted under Epic 5's retro finding F-D2 — reuse it; do not add another copy.

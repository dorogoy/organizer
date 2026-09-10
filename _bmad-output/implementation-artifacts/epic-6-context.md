# Epic 6 Context: Letting Go Without Guilt

<!-- Compiled from planning artifacts. Edit freely. Regenerate with compile-epic-context if planning docs change. -->

## Goal

Before the app asks the user to organize anything, it helps them let go without guilt: purge work is dealt first, two mandatory detachment questions replace justification, and three destinations remain genuinely equal. Hesitation becomes a valid dated Quarantine Box outcome rather than a decision to reopen. Every choice leaves an honest, coarse trace of what letting go produced; Epic 7 consumes those achievement figures without turning them into quotas.

## Stories

- Story 6.1: Purge comes first
- Story 6.2: The two detachment questions
- Story 6.3: The triage act — `item_triaged` with destination and coarse volume
- Story 6.4: Three destinations of equal weight
- Story 6.5: The Quarantine Box, derived from the log
- Story 6.6: The blind six-month follow-up
- Story 6.7: The cumulative declutter metric

## Requirements & Constraints

- Activating an organizing Epic Project prepends purge candidates, and its first dealt Micro-task is always a purge step. Purge work is still an ordinary dispenser card; it is reached from the dealt card, never from a menu or list.
- Each purge item presents the factual 12-month-use question and the physical/mental-space question. Both require `Sí` or `No`, use pressure-free copy, and are followed by one required destination choice.
- The surfaced destinations are exactly `Quedármelo`, `Donar o vender`, and `Tirar o soltar`. They have equal weight: no default, pre-selection, ordering signal, or undesirable framing. Destination hues may appear only inside their glyphs; silhouette must carry differentiation without relying on colour.
- A triage act appends `item_triaged` with one destination and an optional tag from `bolsa`, `caja`, `caja grande`, or `mueble`; no numeric volume is permitted. Batch tagging is optional, and declining to tag writes nothing.
- Quarantine creates a dated box through `box_created` and records its contents as `item_triaged` with additive destination `quarantine`. Its follow-up is blind, one-time per box, six months from the box instant, and copy may refer only to the date—not the box's contents or use. Dismissal has no side effects.
- Declutter figures come only from user taps during purge, never photographs. Counts and optional volume are approximate cumulative achievements only: no target, rate, deficit, percentage, or denominator. They cross to Epic 7's dashboard, not ordinary surfaces.

## Technical Decisions

The functional core is pure Dart; the shell supplies facts and effects. Replayable domain state consists only of immutable pool facts and the insert-only event log. There is no stored plan, quarantine table, future date, tombstone, or synthetic completion; pool membership and quarantine are derived.

`core/weave` is the sole deal emitter. Purge work is a candidate source with precedence under AD-20, so it does not create a special scheduling path. Log kinds use past-tense `snake_case`; `item_triaged` carries destination and optional coarse volume, while `box_created` carries the creation instant. Destination vocabulary evolves forward-only: `quarantine` is additive and unknown future kinds are tolerated. All instants include UTC time and local offset, and `Calendar` is the only period authority. Achievement figures are the only Epic 6 data allowed to cross to the shell; internal signals remain hidden. Strings are Spanish, externalised in the single ARB table, and never concatenated at runtime. Core checks use machine `dart test`; widget tests are limited to facade/command consumers, with no golden tests.

## UX & Interaction Patterns

The 3-Destination Flow is one full-screen decision with nothing else on it: three 64px glyphs separated by 32dp, with no tiles or coloured fields. Labels use the specified Spanish copy and equal treatment. The seed glyph is at rest, has eight filaments and a 45° axis; the light form is retained in dark mode with dark ink and destination-specific dark masses. Tappable areas remain at least 48dp and text grows/scrolls rather than truncating.

The six-month follow-up is an ambient-strip resident, one-tap dismissible and shown at most once per box. Copy stays factual and non-possessive. Any volume figure stands without a glyph because the box glyph denotes keeping, not released volume. All Epic 6 copy follows the anti-shaming register: no alarm styling, pressure, guilt, progress language, or continuation prompt.

## Cross-Story Dependencies

Epic 5 must provide active organizing Epic Projects before purge injection can operate. Within Epic 6, purge precedence comes before the questions; the questions precede triage and the destination flow; triage supplies the log facts used to derive Quarantine and the metric; Quarantine supplies the six-month ambient resident. Epic 7 is the consumer of Epic 6's achievement figures. All stories extend the shared resolver, event log, ARB table, glyph system, and ambient strip without introducing alternate emitters or storage paths.

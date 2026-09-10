---
title: '6-2: The two detachment questions'
type: 'feature'
created: '2026-09-10'
status: 'done'
review_loop_iteration: 0
baseline_commit: 'c39cfca50ad38a500c8d306237143089fc244972'
context: ['_bmad-output/implementation-artifacts/epic-6-context.md']
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** Story 6.1 opens the Decluttering Protocol from a purge card, but its frame still contains only the terminal `Hecho` action. A purge therefore completes without asking the two pressure-free questions that should replace justification.

**Approach:** Turn the existing frame into a stateful question surface. Show both questions, collect one `Sí`/`No` answer for each in transient shell state, and hand the pair to a typed callback only after both answers exist. The later destination and triage stories consume that seam.

## Boundaries & Constraints

**Always:** Use the Spanish strings `¿Has utilizado este objeto en los últimos 12 meses?` and `¿Merece este objeto tu espacio físico y mental?`, plus exactly `Sí` and `No` for each question. Both questions must be answered before the handoff; answers are revisable while the surface remains open. Keep the question controls equal in weight, at least 48dp, and compatible with 200% text scaling through wrapping and scrolling. Preserve the purge-card-only entry, existing route/current-route and in-flight guards, and system-back behavior: leaving writes nothing and leaves the purge card standing. Keep answers ephemeral and invoke the handoff at most once per visit.

**Ask First:** No additional product decisions are required; the copy and boundary above are the approved intent for this story.

**Never:** Do not add a log kind, event payload, store column, analytics record, `item_triaged`, `box_created`, destination glyph/flow, volume tag, quarantine behavior, or a new entry route. Do not call `cardDone` or complete the purge when either answer is selected. Do not add a skip action to the question surface, edit generated localization files, or introduce object data that the synthetic purge card does not provide.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Initial protocol visit | Purge card enters the existing route | Both questions and only their `Sí`/`No` choices render; no answer is preselected | N/A |
| First answer | One question receives `Sí` or `No` | That answer is held transiently; the other question remains unanswered and no handoff or log write occurs | N/A |
| Both answers | One answer exists for each question | One typed answer object reaches the downstream callback; the card is not completed by this story | N/A |
| Leave and return | System back before handoff, then reopen the purge card | Transient answers are discarded; no event is appended and the questions start unanswered | N/A |
| Large text | System font scale is 200% | Copy wraps and the route scrolls; no text is truncated and every answer target remains at least 48dp | N/A |

</frozen-after-approval>

## Code Map

- `lib/ui/destinations/decluttering_protocol_screen.dart:25-93` -- replace the Story 6.1 stateless placeholder with the question state, immutable answer value, two question blocks, and the typed downstream callback; retain the surface-base layout and safe back semantics.
- `lib/ui/dispenser/dispenser_screen.dart:565-591, 763-803` -- adapt `_openDeclutteringProtocol` and its purge `Hecho` branch to pass the answer handoff without completing the card; retain `_writeInFlight`/`isCurrent` guards and the sole entry route.
- `lib/l10n/app_es.arb:34-102` -- add the two question strings and the `Sí`/`No` labels with `@` metadata; regenerate `lib/strings/*` through the existing codegen target, never by hand.
- `lib/ui/tokens.dart:213-258` and `lib/ui/theme.dart:8-83` -- reuse the established spacing, touch-target, surface and text roles; do not introduce destination styling into this screen.
- `test/ui/destinations/decluttering_protocol_screen_test.dart` -- add focused widget coverage for initial state, independent answer selection, required two-answer handoff, no early completion, back-without-write, and 200% wrapping/scrolling.
- `test/ui/dispenser/dispenser_screen_test.dart:6549-6897` -- update Story 6.1 route tests to pin the changed protocol body and preserve purge-only entry, rapid-tap guards, and no-write-on-back behavior.

## Tasks & Acceptance

**Execution:**
- [x] `lib/ui/destinations/decluttering_protocol_screen.dart` -- implement the two-question state machine and `DetachmentAnswers` callback seam; keep answers transient and do not complete the card -- FR-20, AD-1.
- [x] `lib/ui/dispenser/dispenser_screen.dart` -- thread the typed handoff from the purge route while retaining existing navigation guards and deferring destination/card completion -- UX-DR31.
- [x] `lib/l10n/app_es.arb` -- add audited, unconcatenated Spanish question and answer strings; run code generation -- AD-15, NFR7.
- [x] `test/ui/destinations/decluttering_protocol_screen_test.dart` and `test/ui/dispenser/dispenser_screen_test.dart` -- cover the matrix and regression behavior, including no skip and no write before the downstream destination flow -- FR-20.

**Acceptance Criteria:**
- Given a dealt purge card, when its `Hecho` opens the protocol, then both the 12-month-use question and the physical/mental-space question are visible with only `Sí` and `No` choices.
- Given either question, when its copy is audited, then it contains no pressure, guilt, urgency or disposal instruction.
- Given one unanswered question, when the other receives an answer, then the unanswered question remains required and no callback, completion or log write occurs.
- Given both questions have answers, when the second answer is selected, then the downstream callback receives both answers exactly once and no `card_done` or other event is appended by this story.
- Given the protocol is left before the handoff, when the purge card is opened again, then no prior answer is restored and the card remains eligible.
- Given system text is scaled to 200%, when the question surface is rendered, then all copy remains readable by wrapping/scrolling and every answer target is at least 48dp.

## Design Notes

The callback is the seam between this story and the later destination flow. The question screen must not fake a destination, silently finish the purge, or persist answers merely to make the current route appear complete. The synthetic purge card has no physical-object payload, so the question copy refers to “este objeto” without attempting to render an object name.

## Verification

**Commands:**
- `devbox run -- make codegen` -- expected: generated Spanish accessors contain all four new keys.
- `devbox run -- make gate` -- expected: `flutter test`, format, analyze, and repository checks pass.

**Manual checks (if no CLI):**
- Open a purge card, verify both questions and equal `Sí`/`No` choices, select answers in either order, confirm the handoff occurs only after the second answer, and use system back to confirm no completion or persistence.

## Suggested Review Order

**Purge route boundary**

- The existing purge-card entry remains the sole route and forwards a typed pair without completing.
  [`dispenser_screen.dart:570`](../../lib/ui/dispenser/dispenser_screen.dart#L570)

- The callback sink deliberately stops at this story's boundary; destination work remains downstream.
  [`dispenser_screen.dart:594`](../../lib/ui/dispenser/dispenser_screen.dart#L594)

**Question state and handoff**

- The immutable answer value makes the downstream handoff a stable, typed snapshot.
  [`decluttering_protocol_screen.dart:30`](../../lib/ui/destinations/decluttering_protocol_screen.dart#L30)

- Visit-local nullable fields enforce two answers before the one-shot callback.
  [`decluttering_protocol_screen.dart:72`](../../lib/ui/destinations/decluttering_protocol_screen.dart#L72)

**Accessible question surface**

- Each answer exposes stable choice-group semantics and selected value without extra product copy.
  [`decluttering_protocol_screen.dart:104`](../../lib/ui/destinations/decluttering_protocol_screen.dart#L104)

- Question containers associate their prompts with the independent `Sí`/`No` controls.
  [`decluttering_protocol_screen.dart:145`](../../lib/ui/destinations/decluttering_protocol_screen.dart#L145)

- The shared scroll and width constraints preserve readable copy and answer targets at 200%.
  [`decluttering_protocol_screen.dart:202`](../../lib/ui/destinations/decluttering_protocol_screen.dart#L202)

**Localized contract**

- The four approved Spanish values stay flat, audited, and generated through the existing pipeline.
  [`app_es.arb:39`](../../lib/l10n/app_es.arb#L39)

- Generated Spanish accessors carry the ARB values into the widget without hand edits.
  [`app_strings_es.dart:42`](../../lib/strings/app_strings_es.dart#L42)

**Verification matrix**

- Literal copy, route keys, and the absence of completion controls pin the initial protocol visit.
  [`decluttering_protocol_screen_test.dart:51`](../../test/ui/destinations/decluttering_protocol_screen_test.dart#L51)

- Semantics assertions prove independent groups and visible reselection state.
  [`decluttering_protocol_screen_test.dart:71`](../../test/ui/destinations/decluttering_protocol_screen_test.dart#L71)

- All four answer pairs verify field mapping and the typed callback boundary.
  [`decluttering_protocol_screen_test.dart:158`](../../test/ui/destinations/decluttering_protocol_screen_test.dart#L158)

- Large-text tests verify both prompts, no truncation, scroll reachability, and two-dimensional target floors.
  [`decluttering_protocol_screen_test.dart:243`](../../test/ui/destinations/decluttering_protocol_screen_test.dart#L243)

- Dispenser regressions cover no-write behavior, rapid entry, and leave-and-reopen eligibility.
  [`dispenser_screen_test.dart:6698`](../../test/ui/dispenser/dispenser_screen_test.dart#L6698)

- The project delegation rule keeps future delegated work on internal subagents.
  [`AGENTS.md:40`](../../AGENTS.md#L40)

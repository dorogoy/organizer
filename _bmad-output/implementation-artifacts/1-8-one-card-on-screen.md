---
title: 'One card on screen'
type: 'feature'
created: '2026-08-29'
status: 'done'
review_loop_iteration: 0
baseline_commit: '3dbf3038acef0b4b55310d55a294cfe57b618ef6'
context: ['FR-1', 'FR-3', 'NFR5', 'NFR6', 'AD-14', 'AD-15', 'AD-16', 'UX-DR6', 'UX-DR14', 'UX-DR16', 'UX-DR28', 'UX-DR41', 'UX-DR44', 'UX-DR45']
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** Home is `SizedBox.shrink()` — the shell already deals a card into the log at launch (`SessionController.handleAppOpen` → `session_started` + first `card_dealt`) but no surface renders it, so the epic's promise (open → one card within 2 s) has no screen.

**Approach:** Build the Dispenser as the app's home: a `DispenserController` reading `nextCard` (the dealt-unanswered path) with the established injectable pattern, the first surface components (`TaskCard`, duration chip, `Hecho`, text secondary, Hoja zone-marker footer), seven new ARB keys (five zone names, two duration units), and the warm close string when the deal is null.

## Boundaries & Constraints

**Always:**
- Anatomy, top to bottom (DESIGN.md `dispenser-card`): duration-chip eyebrow (pill `accent-soft`, `ink-primary`, `duration` role, `Radii.radiusFull`) with `Spacing.chipToTask` (8) above the task; task in Lora `TypeRoles.task`; `Spacing.taskToActions` (32); full-width `Hecho` (`accent-soft` fill, `ink-primary`, `actionPrimary` role, `Radii.radiusDefault`, min height `Spacing.touchTargetMin`); `Spacing.actionGap` (12); `actionRescueOrSkip` as plain centered text (`actionSecondary` role, no box/fill/underline); zone-marker footer only when `Card.zone != null` — 24px (`Spacing.glyphZoneMarker`) `LeafGlyph` + label in `TypeRoles.support`. Card container: `surfaceRaised` on `surfaceBase`, 1px `borderHairline`, `radiusDefault`, `Spacing.cardPadding`, no shadow/gradient/glow. All gaps from `Spacing` tokens only.
- Estimated duration always visible (FR-1): chip text from ARB placeholders — minutes when the estimate is ≥ 60 s and divides by 60, else seconds; value + NBSP + unit (900→`15 min`, 180→`3 min`, 30→`30 s`).
- Zone labels are five ARB keys with the canonical A12.4 names: `Cocina y despensa` · `Baños` · `Dormitorios` · `Salón y zonas comunes` · `Entrada, lavadero y exteriores`. `Card.zone` never carries strings.
- `nextCard` null → `poolExhaustedClose` verbatim, centered, quiet (`actionSecondary` role, `inkSecondary`), never an error and never styled as absence or debt.
- Read pending → empty `surfaceBase` frame; no splash, spinner or loader ever precedes the first card (UX-DR41).
- Air around the card: minimum 48dp plus flex (padding minimums + Center + max-width constraint), never a fixed value; side margins ≥ `Spacing.screenMargin`; the screen scrolls (UX-DR14/NFR6: wrap + Column + minimums — no `maxLines`, no ellipsis, no fixed heights).
- `Hecho` and the secondary render in final form; taps are accepted no-ops in 1.8 — `cardDone`/haptics/celebration are 1.9's, skip wiring 1.10's.
- `DispenserController` follows `SessionController`'s injectables (`store`, `strings`, `bundle`, `nowOf`); memoized catalogue load with failure-not-memoized retry (mirror `session_controller.dart:147-157`); `read()` computes via `nextCard` and writes nothing (AD-3). No `ClockPort` implementation — the injectable-now convention.
- No origin tag anywhere (AD-14); no list, calendar, counter, streak, badge or overdue indicator anywhere reachable (UX-DR44); exactly one actionable Micro-task on screen.

**Ask First:** None.

**Never:** No core changes (`nextCard`, weave, commands untouched); no new log kinds; no `cardDone`/`cardSkipped` effects; no pocket trigger, Cámara entry, `Nuevo proyecto` link, ambient strip or energy check-in (later epics); no session-controller behavior changes beyond exposing its settled lifecycle future so the Dispenser reads the persisted launch/resume deal; no new `tool/` checks or Makefile targets; no card goldens (structure + token tests pin the surface).

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Behavior | Error Handling |
|----------|---------------|-------------------|-----------------|
| Cold start, first frame | launch session dealt a chunk | `TaskCard` with chip, task, `Hecho`, secondary, zone footer; no loader before it | N/A |
| Null-zone card | maintenance/instant/fondo deal (`zone == null`) | no footer — the card ends after the secondary action | N/A |
| Duration rendering | 900 / 180 / 30 s | `15 min` / `3 min` / `30 s` (NBSP between value and unit) | N/A |
| Null deal | empty-catalogue bundle → `nextCard` null | `poolExhaustedClose` verbatim, quiet close surface | never an error surface |
| Catalogue load failure | throwing bundle | the empty surface stands; the memo clears so the next read retries | no error string, no crash surfaced |
| 200% font scale | `textScaleFactor 2.0`, long task text | card grows into its air, nothing ellipsized/truncated, screen scrolls | N/A |

</frozen-after-approval>

## Code Map

- `lib/main.dart` :48 -- `home: SizedBox.shrink()` becomes the Dispenser; `OrganizerApp` gains an optional controller param (main constructs it with the same store; test seam preserved).
- `packages/core/lib/facade/read_facade.dart` :22 -- `nextCard(store, catalogue:, instantUtcMicros:, offsetSeconds:)`: the only core call; returns the dealt-unanswered `Card` else `nextDeal`.
- `packages/core/lib/weave/weave.dart` :69-117 -- `Card` fields: `id`, `size`, `name`, `origin`, `zone`, `estimateSeconds`; estimates are per-size constants :52-61.
- `lib/session/session_controller.dart` :89-106 -- the launch deal already stands before any read; :147-157 the retry-memo pattern to mirror.
- `lib/catalogue/loader.dart` :34 -- `loadEvergreenCatalogue(strings, bundle:)`.
- `lib/ui/tokens.dart` -- `FieldPalette` :19 / `DarkPalette` :73; `TypeRoles` :102 (`task` :104, `duration` :114, `actionPrimary` :124, `actionSecondary` :134, `support` :144); `Radii` :189; `Spacing` :213 (`chipToTask` :218, `actionGap` :221, `cardPadding` :224, `screenMargin` :227, `taskToActions` :231, `touchTargetMin` :237, `glyphZoneMarker` :249).
- `lib/ui/glyphs/leaf_glyph.dart` :12 -- `LeafGlyph(size)`; mass/line self-resolve per brightness (ochre / ink-secondary).
- `lib/ui/theme.dart` :51-82 -- scaffold background and the wired text roles.
- `lib/l10n/app_es.arb` -- add `zoneZ1`..`zoneZ5`, `durationMinutes`, `durationSeconds` (int placeholder — pattern `consentGateBody` :141); existing `actionDone` :4, `actionRescueOrSkip` :14, `poolExhaustedClose` :94.
- `test/session/session_controller_test.dart` :24-82 -- `_RecordingStore` + `_FakeBundle`(real asset bytes) + fixed clock — copy for dispenser tests.
- `test/ui/app_test.dart` :51-56 -- home-element find to update for the new home.
- `tool/check_no_literal_strings.dart` :43 -- AD-15 compliance via ARB (no allowance edit expected); `tool/check_string_table_audit.dart` -- new keys auto-audit; write descriptions accordingly.
- `Makefile` :72 -- `make gate`.

## Tasks & Acceptance

**Execution:**
- [x] `lib/l10n/app_es.arb` -- add the seven keys (five zone names with A12.4 descriptions, two duration units with int placeholders) -- the table is the only string source (AD-15); then `make codegen`
- [x] `lib/dispenser/dispenser_controller.dart` -- NEW: injectable controller; `read()` → card-or-closed view via `nextCard`; retry-memo catalogue load -- the surface's one read path, testable with fakes
- [x] `lib/ui/dispenser/dispenser_screen.dart` -- NEW: Scaffold + scroll + center, pending = empty surface, closed = warm string, card = `TaskCard`; max-width constraint, air = min 48 + flex -- UX-DR14/UX-DR41 surface
- [x] `lib/ui/dispenser/task_card.dart` (+ `duration_chip.dart`, `zone_marker.dart`, duration/zone-label helpers) -- NEW: the card anatomy from tokens only -- the epic's first surface components
- [x] `lib/main.dart` -- home becomes the Dispenser wired to main's store -- the story's one shell edit
- [x] `test/ui/dispenser/task_card_test.dart` -- NEW: anatomy order and token gaps, Lora task, full-width `Hecho`, plain secondary, footer iff zone non-null, duration labels incl. NBSP, hairline/no-shadow surface, no origin text -- pin the I/O matrix rows
- [x] `test/ui/dispenser/dispenser_screen_test.dart` -- NEW: dealt card shown with fake store + real asset + fixed clock; close string on an empty-catalogue bundle; 200% scale scrolls with nothing truncated; zero loaders; exactly one actionable item -- pin the matrix's scale/close/first-frame rows
- [x] `test/ui/app_test.dart` -- update the home assertions to the Dispenser home -- keep the shell pin true

**Acceptance Criteria:**
- Given a cold start with the launch deal standing, when the Dispenser renders, then the dealt Micro-task is on screen with its chip, task, `Hecho`, secondary and zone footer, and no loader preceded it
- Given a dealt card, when rendered, then its estimated duration is always visible and its origin is nowhere surfaced
- Given `nextCard` null, when the Dispenser renders, then `poolExhaustedClose` shows verbatim, quiet, never an error
- Given 200% font scale, when the card renders, then nothing is ellipsized or truncated and the screen scrolls
- Given the Dispenser in any state, when inspected, then exactly one actionable Micro-task exists and no list, calendar, counter, streak, badge or overdue indicator appears
- Given the completion gate, then `make codegen`-clean, `make check` and `make gate` are green

### Review Findings

- [x] [Review][Patch] High: a failed catalogue read left the empty frame standing forever — the retry the matrix promises had no trigger; the screen now re-reads on `AppLifecycleState.resumed` (SessionController's observer pattern) and a widget test drives a flaky-bundle failure through paused→resumed to the dealt card [lib/ui/dispenser/dispenser_screen.dart, test/ui/dispenser/dispenser_screen_test.dart]
- [x] [Review][Patch] Medium: the secondary's `GestureDetector` (deferToChild) dropped taps landing in the 48dp band but off the text glyphs — now `HitTestBehavior.opaque`, the target the 1.10 wiring will inherit [lib/ui/dispenser/task_card.dart]
- [x] [Review][Patch] Medium: the anatomy fixture paired `Size.maintenance` with 900 s — impossible in the domain (`estimateSecondsOf(maintenance) == 180`); the zoned fixture is now a focus card (real `15 min` pairing) and the real maintenance `3 min` is pinned besides [test/ui/dispenser/task_card_test.dart]
- [x] [Review][Patch] Medium: the 200% scroll assertion proved nothing — now asserts `maxScrollExtent > 0` before the drag and `pixels > 0` after (320×480 genuinely overflows at 200%) [test/ui/dispenser/dispenser_screen_test.dart]
- [x] [Review][Patch] Low: `store.entries[2].itemId!` coupled tests to the session's append order — replaced by a by-kind `card_dealt` lookup [test/ui/dispenser/dispenser_screen_test.dart]
- [x] [Review][Patch] Low: the card was never rendered in dark mode — now pinned on `surfaceRaisedDark`/`borderHairlineDark`/`inkPrimaryDark` [test/ui/dispenser/task_card_test.dart]
- [x] [Review][Patch] Low: scrolled content rendered under the status bar — the frame body is wrapped in `SafeArea`, the 48dp air inside it [lib/ui/dispenser/dispenser_screen.dart]
- [x] [Review][Patch] Low: `_cardMaxWidth` was untested — an 800×600 test pins the card at 480 wide, centered [test/ui/dispenser/dispenser_screen_test.dart]
- [x] [Review][Patch] Low: main()'s same-store wiring had no verification — source-pinned (`openStore()` exactly once; both consumers take the one `store`), the `facade_test.dart` precedent [test/ui/app_test.dart]
- [x] [Review][Patch] Low: `read()`'s mint-before-await contract was unpinned — source-pinned (`nowOf()` precedes the catalogue await) [test/ui/dispenser/dispenser_screen_test.dart]
- [x] [Review][Patch] High: cold-start ordering race between the unawaited session append and the screen's first read across a 04:00/week boundary — `SessionController.settled` now gates each Dispenser read, including resumed reads, and a gated lifecycle widget test proves the rendered card is the persisted `card_dealt` [lib/session/session_controller.dart, lib/ui/dispenser/dispenser_screen.dart, test/ui/dispenser/dispenser_screen_test.dart]
- [ ] [Review][Defer] Boot-level execution of main()'s construction (beyond the source pins) — recorded in deferred-work.md (factory or integration test)
- [ ] [Review][Reject] A timeout on `read()` — invents a policy the spines do not state; drift/asset reads do not hang in practice
- [ ] [Review][Reject] Routing swallowed read failures to the crash guard — the session controller's own established pattern swallows lifecycle errors silently (deliberate quietness, `_enqueue`'s catchError)
- [ ] [Review][Reject] `Semantics(button: true)` on the secondary — the decided interim accessibility posture is "no custom semantics, platform traversal order"
- [ ] [Review][Reject] Re-wiring the controller through Riverpod providers — the constructor seam is this spec's own design, tested and consistent with the shell's injectable convention
- [ ] [Review][Reject] Deduplicating the AssetBundle/store test doubles across suites — the repo's decided stance keeps local duplication loud (1-7's rejection precedent)
- [ ] [Review][Reject] Guarding `estimateSeconds <= 0` — unreachable: estimates are per-size constants over the fixed build-time asset
- [ ] [Review][Reject] `didUpdateWidget` on controller swap — no production path ever swaps the controller
- [x] [Review][Patch] Medium: duration-chip padding bypassed the spacing contract — selected 12dp horizontal and 4dp vertical values are now documented in DESIGN.md, named in `Spacing`, and widget-pinned [DESIGN.md, lib/ui/tokens.dart, lib/ui/dispenser/duration_chip.dart, test/ui/dispenser/task_card_test.dart]
- [x] [Review][Patch] Medium: an older refresh could overwrite a newer state — generation-gated commits retain only the latest result, with an out-of-order completion test [lib/ui/dispenser/dispenser_screen.dart, test/ui/dispenser/dispenser_screen_test.dart]
- [x] [Review][Patch] Medium: a failed refresh left an old card visible — a refresh clears to the intentional empty frame before awaiting and keeps it there on failure, pinned from an already-rendered card [lib/ui/dispenser/dispenser_screen.dart, test/ui/dispenser/dispenser_screen_test.dart]
- [x] [Review][Patch] Medium: session failure could permit an undealt card — `settled` now preserves the current attempt's failure while the serialization queue remains retryable, and a mixed session/dispenser catalogue-failure test pins the quiet empty frame [lib/session/session_controller.dart, test/ui/dispenser/dispenser_screen_test.dart]
- [x] [Review][Patch] Medium: spurious `resumed` cleared an existing card — the Dispenser now mirrors the session's foreground-departure flag, and an installed-session pause/resume test proves the rendered card is the resumed session's persisted deal [lib/ui/dispenser/dispenser_screen.dart, test/ui/dispenser/dispenser_screen_test.dart]
- [x] [Review][Patch] Medium: 200% coverage missed long content — a long zoned card with the longest zone label now proves real overflow, footer reachability and no layout exception [test/ui/dispenser/dispenser_screen_test.dart]

## Spec Change Log

- **2026-08-29 (Review Iteration 1):**
  - Completed review loop across Blind Hunter, Edge-Case Hunter and Verification-Gap lenses; 10 patches applied and verified (266 tests, `make check` 10/10, `make gate` green), 2 deferrals recorded, 8 findings rejected with rationale.
  - No bad-spec or intent-gap findings — the frozen intent held; every patch stayed inside the spec's boundaries (the resumed re-read is the matrix's "next read retries" given its trigger, not a new surface).

- **2026-08-29 (Review Iteration 2):**
  - User approved lifecycle synchronization and 12dp/4dp duration-chip padding. Four review patches applied: session/read coordination, tokenized chip padding, refresh generation protection, and empty-on-refresh-failure behavior.
  - Verified: 269 tests, clean format and analysis, `make check`, and `make gate`.

- **2026-08-29 (Review Iteration 3):**
  - Second review loop resolved lifecycle-failure propagation, spurious-resume refreshes and long-content 200% verification.
  - Verified: 272 tests, clean format and analysis, `make check`, and `make gate`.

## Design Notes

- **The first frame's card is the launch deal.** `installSessionController` → `handleAppOpen` appends `session_started` + `card_dealt` unawaited before `runApp`; `nextCard` returns it through `dealtUnanswered`. The surface never writes (AD-3) — 1.9's answers are what refresh it.
- **Null zone ⇒ no footer.** DESIGN.md:411 restricts the 24px marker to "a zone marker beside a word"; daily and `fondo` deals have no zone word, and inventing one would surface cluster vocabulary the card does not own (Epic 5's curation business).
- **Duration rule** keeps the chip deterministic: whole minutes ≥ 1 min, else seconds — the three shipped sizes render `15 min` / `3 min` / `30 s` with the ARB's NBSP.
- **No-op buttons** are deliberate: 1.8 delivers the rendered contract; the wired tap, haptic and sub-500 ms next-card timing land with 1.9/1.10 against the same components.

## Verification

**Commands:**
- `devbox run -- make codegen` -- expected: regenerated accessors fresh (after ARB edits)
- `devbox run -- make check` -- expected: all checks green, incl. no-literal-strings, text-scaling, string-table audit
- `devbox run -- make gate` -- expected: test, format, analyze all green
- `devbox run -- flutter test test/ui/dispenser test/ui/app_test.dart` -- expected: new suites green

**Manual checks (if no CLI):** — verified 2026-08-29, Sergio, on a real handset:
- [x] Real handset, light and dark: the 24px Hoja crescent reads as a place-marker (DESIGN.md:505 gates 1.8 on this) — verified at standard resolution in both modes
- [x] Cold start on device, day one: first card within 2 s — measured under the 2-second bound
- [x] The secondary's 200% fold verified on the handset — at the system's maximum font scale (≥ 200%) everything renders whole; `Otra más fácil / Ahora no` folds with `no` on the next line, exactly the accepted fold

### Completion Notes

- The three manual gates were verified on the builder's handset on 2026-08-29 (observations transcribed above, verbatim in substance). The font-scale check ran at the system maximum rather than exactly 200%, which covers the floor the spec names.

## Suggested Review Order

**The read path — the surface never writes (AD-3)**

- The one read: `nextCard`'s dealt-unanswered card or the resolver's choice, instant minted before any await
  [`dispenser_controller.dart:64`](../../lib/dispenser/dispenser_controller.dart#L64)

- The retry-memo catalogue load, mirroring the session controller's failure-not-memoized contract
  [`dispenser_controller.dart:82`](../../lib/dispenser/dispenser_controller.dart#L82)

- main()'s wiring: one store feeds both the session lifecycle and the Dispenser (source-pinned in tests)
  [`main.dart:32`](../../lib/main.dart#L32)

**The card anatomy — DESIGN.md's dispenser-card, from tokens only**

- The anatomy column: chip eyebrow → Lora task → `Hecho` → text secondary → footer iff zoned
  [`task_card.dart:95`](../../lib/ui/dispenser/task_card.dart#L95)

- The one recommended action: full-width accent-soft pill, 48dp floor, tap a deliberate no-op until 1.9
  [`task_card.dart:26`](../../lib/ui/dispenser/task_card.dart#L26)

- The unsplit secondary: plain centered text with an opaque hit target for 1.10 to inherit
  [`task_card.dart:64`](../../lib/ui/dispenser/task_card.dart#L64)

- The duration rule: whole minutes else seconds, value + NBSP + unit from ARB placeholders
  [`duration_chip.dart:21`](../../lib/ui/dispenser/duration_chip.dart#L21)

- The zone footer: 24px Hoja beside the canonical A12.4 word, `zone == null` renders nothing
  [`zone_marker.dart:27`](../../lib/ui/dispenser/zone_marker.dart#L27)

- Seven new keys: five zone names + two duration units — the table stays the only string source
  [`app_es.arb:29`](../../lib/l10n/app_es.arb#L29)

**The frame — air, scroll, quiet failure**

- The shared frame: SafeArea first, scroll when grown, 48dp-min air plus flex, 480 max-width
  [`dispenser_screen.dart:112`](../../lib/ui/dispenser/dispenser_screen.dart#L112)

- The resumed re-read — the review fix that gives the failed read its retry trigger
  [`dispenser_screen.dart:57`](../../lib/ui/dispenser/dispenser_screen.dart#L57)

- The warm close: `poolExhaustedClose` verbatim, quiet, never an error
  [`dispenser_screen.dart:95`](../../lib/ui/dispenser/dispenser_screen.dart#L95)

**Peripherals — the proofs**

- Cold start renders the launch deal; zero loaders, exactly one actionable item
  [`dispenser_screen_test.dart:178`](../../test/ui/dispenser/dispenser_screen_test.dart#L178)

- The failed-read row end to end: empty frame stands, resumed retry resolves the card
  [`dispenser_screen_test.dart:345`](../../test/ui/dispenser/dispenser_screen_test.dart#L345)

- 200% scrolls for real: `maxScrollExtent > 0`, pixels move; wide grounds cap the card at 480
  [`dispenser_screen_test.dart:296`](../../test/ui/dispenser/dispenser_screen_test.dart#L296)

- Anatomy gaps, token colors, the domain-real duration pairings, dark palette
  [`task_card_test.dart:72`](../../test/ui/dispenser/task_card_test.dart#L72)

- The main.dart source pins: one `openStore()`, both consumers on the same store
  [`app_test.dart:136`](../../test/ui/app_test.dart#L136)

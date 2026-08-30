---
title: 'The declared pocket and the derived session'
type: 'feature'
created: '2026-08-30'
status: 'done'
review_loop_iteration: 0
baseline_commit: 'b51bdfe2f4715785e57588802f6c0dc18b8a9d03'
context: ['FR-8', 'FR-3', 'FR-9', 'FR-12', 'AD-1', 'AD-6', 'AD-15', 'AD-19', 'AD-20', 'AD-23', 'UX-DR18', 'UX-DR25']
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** The Dispenser deals without knowing how long the user actually has: sessions open on entry carrying no pocket, so nothing bounds what one sitting asks (FR-8), and today's session vocabulary cannot express a declared amount, an elapsing close, or a superseding declaration (AD-19).

**Approach:** Add `pocket_minutes` to `session_started` (one additive nullable column, schema v3) and pure commands `sessionDeclare` and `appOpen`: declaring supersedes any open session (`session_ended` + `session_started{pocket}` at one instant, the in-progress card carried over) and deals only what fits — answered estimates, upkeep included, sum ≤ the pocket, and the wall-clock span `start + pocket` ends dealability. A `Tengo {minutes} minutos ahora` duration-chip on the Dispenser opens a quiet stepped ladder; a spent or elapsed pocket presents the same warm close as pool exhaustion; an elapsed pocket left open by process death closes first at the next `app_opened`, before any new `session_started`.

## Boundaries & Constraints

**Always:**
- The pocket is log-derived, never held in memory as truth: the open session stays the latest `session_started` with no matching `session_ended`; its pocket is that row's `pocket_minutes` (1–60 as minted; an out-of-range value derives as absent → unbounded). Extensions are 2.4's `session_extended` — nothing here pre-mints or pre-computes them.
- Deal filtering: while a pocketed session is open, a candidate is dealt only if `Σ estimate(card_done in session) + estimate(candidate) ≤ pocket·60s`, and only if the pocket has not elapsed (`deal instant < start + pocket·60s`). Skips release their estimate; a dealt-unanswered card consumes nothing. Estimates are the weave's per-Size constants — upkeep (maintenance, instant) is charged to the pocket like everything else dealt in the sitting, never to the Time Bag.
- Exactly three `session_ended` causes and no others: backgrounding (existing), the declare tap (supersede — the user-stop vocabulary, AD-19's "the tap emits `session_ended`"), and the reveal at `app_opened` of an elapsed pocket. No timer exists in the shell; the elapse is derived at read/answer/open instant, never scheduled.
- A no-fit or elapsed pocket appends NO eager `session_ended`: the warm close is the read model's null deal — the same surface and the same `poolExhaustedClose` string as pool exhaustion. The row lands later, at backgrounding, reveal, or supersede. Unbounded (auto-opened) sessions behave exactly as shipped: pool exhaustion lingers open, no new close path.
- Supersede preserves the in-progress card: `session_started` clears `dealtUnanswered` unless it directly follows a same-instant `session_ended` in store read order — "a pocket declared while a card is in progress: the card can be finished, the re-filter applies to the next deal" (EXPERIENCE §components). The carried card's later `card_done` charges the new session and consumes its pocket (a 15-min chunk finished under a 5-min pocket honestly spends it); the declare and reveal bundles suppress their own first deal while a card is carried.
- Sessions crossing 04:00 stay one ledger on the session's own start day (existing `_chargedDayOf` pins hold); pocket accounting is session-scoped, never day-scoped, and the crossed-into day's Focus slot stays untouched (AD-19/AD-20).
- Additive substrate: `pocket_minutes INTEGER NULL` on `log_entries` via `schemaVersion` 3, ALTER-TABLE-only `onUpgrade` (the v1→v2 pattern); refusal triggers, insert-only discipline, no-FK/no-CHECK stay untouched. A `SessionStartEntry {kind, pocketMinutes}` subtype leaves `session_started` the moment family; `session_ended`/`app_opened` stay moments and must carry NULL pocket (a new flaw kind mirrors `settingOnNonSettingKind`).
- The trigger is a `duration-chip` top-centred above the card (and on the closed surface) carrying `Tengo {minutes} minutos ahora` — the standing declared pocket while a pocketed session is open, else 15. Tapping opens a quiet stepped ladder of pills (48dp targets, `rounded.full`, the quantity-of-time idiom); every offered option is in range so out-of-range is unreachable in the UI; command-level refusal returns no content with no error state.
- Every string change lands in `app_es.arb` with a description: `pocketTrigger` gains a `{minutes}` placeholder; regenerated accessors committed. No countdown, no remaining-minutes display, no new session state, surface or error anywhere.
- Core purity (no Flutter imports, no clock/Random/io) and the text-scaling floor (no maxLines/ellipsis/fixed heights) hold on every new file; pins are renegotiated deliberately in-pass, never bent.

**Ask First:** Any non-additive schema change beyond the one nullable column; any new user-visible string beyond the parameterized `pocketTrigger`; any shell timer or scheduled close; any perceived need to record a close cause on the `session_ended` row; any change to the ladder's option set beyond swapping values.

**Never:** No `session_extended` kind or extension arithmetic (2.4); no checkpoint surface or interval reading (2.4); no pause/stop control (2.3 — the declare tap is the only new user-stop emission); no free-form minute entry; no remaining-pocket, countdown or progress surface; no wallet semantics on the Time Bag; no resume menu or session summary on return; no eager `session_ended` on pool exhaustion; no UPDATE/DELETE path or side file.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Behavior | Error Handling |
|----------|---------------|-------------------|-----------------|
| Declare, idle | ladder tap 15, no open session | `[session_started{15}, card_dealt?]` — deal fits 15 | N/A |
| Declare, card in progress | open unbounded session, dealt-unanswered card | `[session_ended, session_started{p}]`, no bundled deal; the same card stays answerable; its `card_done` consumes the new pocket | N/A |
| Re-declare | open pocketed session | supersede to the new pocket; consumption restarts at 0 | N/A |
| Out-of-range | `sessionDeclare(pocketMinutes: 0 or 61)` | returns no content; nothing appended | surface offers only in-range options, unreachable in UI |
| Imported pocket | log row `session_started` with 90 | entry stays in the log; derivation reads it as absent → unbounded | no crash, no repair write |
| Pocket consumed | pocket 15, 15-min chunk answered | next deal resolves null → warm close; no eager `session_ended` | silent |
| Skip releases | pocket 6, 5-min-focus candidate skipped | consumed stays 0; the alternative deal still bounded by 6 | silent |
| Elapsed, foregrounded | now ≥ start + pocket, card on screen | read deals nothing (warm close); `Hecho` on the card still records the answer, bundling no deal | silent |
| Elapsed, revealed | reopen after process death, pocket long past | `appOpen` bundle `[app_opened, session_ended, session_started, card_dealt?]` — close first, then start; the carried card suppresses the bundled deal | N/A |
| Reopen, not elapsed | background at 12:00, pocket to 12:10, reopen 12:02 | existing behavior: bg appended `session_ended`; fresh session on open | N/A |
| Crosses 04:00 | start 03:40, answers 04:10 | all acts charged to the start day (existing); pocket consumed across the boundary; crossed-into day's slot untouched | N/A |
| Same-instant pair | two `session_started` at one instant | store read order (instant, rowid) decides; the later wins | deterministic replay |
| v2 install upgrade | pre-v3 database opened | ALTER TABLE adds `pocket_minutes`; old rows read null and convert unchanged | migration tolerant, no rebuild |

</frozen-after-approval>

## Code Map

- `packages/core/lib/log/log_entry.dart:34-53,122-132,235-290` -- extend: `SessionStartEntry {kind, pocketMinutes: int?}` (session_started leaves the moment family; sessionEnded/appOpened stay `MomentEntry`), `convertLogEntryRecord` branch with the null-or-int structural check, and a `pocketOnNonSessionStartKind` flaw at the `_isMoment` checks mirroring the setting rule
- `packages/core/lib/ports/store_port.dart:38-48` -- `LogEntryRecord` grows nullable `pocketMinutes` (field-identical to domain, AD-6); `LogEntryContent` in `commands/session_commands.dart:32-39` gains the same field
- `lib/store/substrate.drift` + `lib/store/substrate.dart:24-58` + regenerated `substrate.g.dart` + `lib/store/drift_store.dart:41-57,83-107` -- `pocket_minutes INTEGER NULL`, `schemaVersion => 3`, `if (from < 3)` ALTER-only upgrade; row mapping both ways
- `packages/core/lib/weave/session.dart:23-62,97-184` -- `LogFacts` grows `openSessionPocketMinutes: int?` and `openSessionAnsweredSeconds: int`; walk sets pocket on start, adds `estimateSecondsOf(size)` on `card_done` while open (size resolved as `dealtCountsByDay` already resolves), skip adds nothing; supersede-pair rule: `session_started` preserves `dealtUnanswered` when it directly follows a same-instant `session_ended`
- `packages/core/lib/weave/weave.dart:52-57,279-320,337-464` -- read-only estimates and the filter site: `nextDeal`'s candidate resolution gains pocket-eligibility (`openSessionAnsweredSeconds + estimate ≤ pocket·60` and not elapsed at the deal instant) across chunk/maintenance/instant tiers; the below-10 chunk gate is untouched
- `packages/core/lib/commands/session_commands.dart:27-149` -- extend: `sessionStart({..., int? pocketMinutes})` mints the pocketed row (still the single `session_started` minter); NEW `sessionDeclare({catalogue, log, pocketMinutes, instant, offset, bagMinutes})` = range guard + `[...sessionEnd(log), ...sessionStart(...)]` with carried-card suppression; NEW `appOpen({catalogue, log, instant, offset, bagMinutes})` composes `[app_opened, ...sessionEnd(log) iff the open pocket is elapsed at the instant, ...sessionStart(...)]`, resolving over a synthesized post-`session_ended` log exactly as `_answered` (session_commands.dart:151+) already does
- `packages/core/lib/settings/settings.dart:24-41` -- read-only template; pocket constants land beside the bag's: `pocketLeastMinutes = 1`, `pocketMostMinutes = 60`, `defaultPocketMinutes = 15` (single source; the command guard and the chip default read it)
- `packages/core/lib/facade/read_facade.dart:22-52` -- unchanged shape (one function, no collections — pinned at `facade_test.dart:436`); pocket facts flow through the walk
- `lib/session/session_controller.dart:19-37,99-134` -- `handleAppOpen` composes via the new `appOpen` command (same row sequence as today in the normal case); no timer, no new lifecycle branch
- `lib/dispenser/dispenser_controller.dart:19-99,110-192` -- NEW `declarePocket(int minutes)` via `_enqueueWrite` (read log+catalogue → `sessionDeclare` → append → `read()`); both `DispenserView` variants carry `pocketMinutes: int?` (the standing declared pocket) for the chip
- `lib/ui/dispenser/dispenser_screen.dart:283-432` + `lib/ui/dispenser/duration_chip.dart:25-51` -- trigger chip top-centred above the card and on the closed surface, in the duration-chip pill idiom with a label seam carrying `pocketTrigger(minutes)`; tap opens a quiet modal bottom sheet (SafeArea, wraps and scrolls at 200%) of stepped pills 5/10/15/20/25/30/45/60 rendering `durationMinutes`, selected = standing pocket, tap pops and calls `declarePocket`
- `lib/l10n/app_es.arb:19-22` -- `pocketTrigger` gains an int `{minutes}` placeholder, description updated to name the standing-declaration semantics; regenerate (`make codegen`)
- Test doubles to reuse: `_RecordingStore` + `launchAndCommit` + furniture census `_censusOf` + lifecycle faking `tester.binding.handleAppLifecycleStateChanged` (`test/ui/dispenser/dispenser_screen_test.dart:45-61,928-938,390-443,641-646`), `openSessionAndReadFirstDeal` (`test/dispenser/dispenser_controller_test.dart:259-273`), fixed clock + weave entry builders (`packages/core/test/weave_test.dart:49-125`)
- Pins renegotiated in-pass: `packages/core/test/log_test.dart:27-49` (kinds stay eight; new structural cases for the pocket payload, template at :320-360), `packages/core/test/no_lateness_proof_test.dart:601-979` (freeze lists: `SessionStartEntry`, `LogEntryRecord` 10 fields, `LogEntryContent` 7, `LogFacts` 8, `MomentEntry` scope narrowed; exhaustiveness census; mint counts — `app_opened`/`session_started`/`session_ended` still minted only in session_commands.dart), `test/store/substrate_test.dart:508-523,553-690` (ten-column pin; v2→v3 migration group seeded on a real v2 database), `test/no_lateness_proof_test.dart:307-329` (append-site census: dispenser_controller 2→3; wire names unchanged), `packages/core/test/weave_test.dart:549-571` (upkeep re-pinned as pocket-charged under a pocketed session, still bag-uncharged), `packages/core/test/session_test.dart` + `session_commands_test.dart` + `facade_test.dart` (walk, declare and answer bundles under pockets)

## Tasks & Acceptance

**Execution:**
- [x] `packages/core/lib/log/log_entry.dart` + `packages/core/lib/ports/store_port.dart` -- `SessionStartEntry`, pocket fields on record/content, conversion + flaw rules -- additive payload path for the pocket
- [x] `lib/store/substrate.drift` + `lib/store/substrate.dart` + regenerated `substrate.g.dart` + `lib/store/drift_store.dart` -- nullable column, schemaVersion 3, ALTER-only upgrade -- insert-only substrate survives v2 installs
- [x] `packages/core/lib/weave/session.dart` + `packages/core/lib/weave/weave.dart` -- pocket facts in the walk, supersede-pair preserve, estimate consumption, pocket+elapsed deal filter -- AD-19 made real in the derivation
- [x] `packages/core/lib/settings/settings.dart` + `packages/core/lib/commands/session_commands.dart` -- pocket constants, `sessionDeclare`, pocketed `sessionStart`, `appOpen` with elapsed-reveal composition -- the single sanctioned pocket and session minters
- [x] `lib/session/session_controller.dart` + `lib/dispenser/dispenser_controller.dart` -- `handleAppOpen` via `appOpen`; `declarePocket` + `pocketMinutes` on the view -- serialized write seams, no timer
- [x] `lib/ui/dispenser/dispenser_screen.dart` + `lib/ui/dispenser/duration_chip.dart` -- trigger chip + quiet ladder sheet -- UX-DR18 grammar, no error state
- [x] `lib/l10n/app_es.arb` + regenerated accessors -- parameterized `pocketTrigger` -- AD-15
- [x] `packages/core/test/session_test.dart` -- walk matrix: pocket facts, supersede preserve, consumption (done consumes, skip releases, carried card consumes), imported-90-as-absent, 04:00 one-ledger with pocket, same-instant order
- [x] `packages/core/test/weave_test.dart` -- filter matrix: no-fit null per tier, upkeep charged to the pocket, chunk-vs-pocket interplay, elapsed-at-deal-instant, unbounded sessions unchanged
- [x] `packages/core/test/session_commands_test.dart` -- declare matrix (idle / supersede open / re-declare / refusal 0 and 61 / carried-card suppression), `appOpen` reveal bundle order `[app_opened, session_ended, session_started, card_dealt?]`, normal-case sequence identical to today
- [x] `packages/core/test/log_test.dart` + `packages/core/test/no_lateness_proof_test.dart` + `packages/core/test/facade_test.dart` -- renegotiate the pins named in the Code Map; facade integration: seeded pocketed log drives the warm close and the re-filter
- [x] `test/store/substrate_test.dart` -- ten-column pin + v2→v3 migration on a seeded v2 database
- [x] `test/no_lateness_proof_test.dart` + `test/session/session_controller_test.dart` -- shell census 2→3 with wire names unchanged; `handleAppOpen` sequences unchanged in the normal case
- [x] `test/dispenser/dispenser_controller_test.dart` + `test/ui/dispenser/dispenser_screen_test.dart` -- declare sequence `[session_ended?, session_started{p}, card_dealt?]`; in-progress card survives declare and consumes the new pocket; chip standing pocket; spent-pocket warm close through `read()`; reveal flow via lifecycle faking; furniture-census compatibility; ladder quietness (48dp pills, no glyph, no error state, nothing ellipsized at 200%)

**Acceptance Criteria:**
- Given the Dispenser, when rendered, then the pocket trigger sits as a `duration-chip` carrying `Tengo {minutes} minutos ahora` — the standing declared pocket, else 15 — and declaring opens a quiet stepped ladder with no error state (FR-8, UX-DR18)
- Given a declared pocket, when cards are dealt inside the session, then their estimated durations — upkeep included — sum ≤ the declared pocket, and a skip releases its estimate so the alternative deal still fits (FR-8, FR-12)
- Given a remaining pocket smaller than every eligible candidate's estimate, when the next deal resolves, then no over-budget card is dealt and the surface carries `por hoy no hay nada más que merezca la pena` — the same warm close as pool exhaustion (FR-8, FR-3)
- Given the app re-opened after process death left a derived-open session, when `app_opened` is handled, then any open session whose pocket elapsed closes at that instant first, and only then does a new `session_started` append — two derived-open sessions never coexist (AD-19)
- Given the log, when the current session is derived, then it is the latest `session_started` with no matching `session_ended`, belonging to the domestic day of its own start instant; a 04:00 crossing neither ends it nor resets the day's advance, and the crossed-into day's Focus slot is never occupied (AD-19, AD-20)
- Given a pocket fully elapsed while the app was not foregrounded, when the app is next foregrounded, then the session closes at that instant — the elapse is revealed, not awaited — and nothing held session state in memory as the source of truth (AD-19)
- Given the completion gate, then `make check` and `make gate` are green, core suites via `make test-core`

### Review Findings

- [x] [Review][Patch] Serialize lifecycle and declaration writes through one shared queue [`lib/dispenser/dispenser_controller.dart:220`, `lib/session/session_controller.dart:102`]
- [x] [Review][Patch] Derive the displayed pocket and card from one post-write log snapshot at a post-wait instant [`lib/dispenser/dispenser_controller.dart:98`]
- [x] [Review][Patch] Invalidate an older read before committing a declared pocket view [`lib/ui/dispenser/dispenser_screen.dart:437`]
- [x] [Review][Patch] Prove the 200% pocket ladder can scroll to every option [`test/ui/dispenser/dispenser_screen_test.dart:2474`]
- [x] [Review][Defer] Make multi-row log bundles transactional [`lib/dispenser/dispenser_controller.dart:233`] — deferred, pre-existing

## Spec Change Log

## Design Notes

- **No shell timer, by derivation.** "Closes at that instant" is derived dealability going null, not a scheduled write: reads and answers derive elapse from `(start + pocket·60s) ≤ now`, so an in-progress card answered after expiry still records (the guard sees the still-open session — no dead `Hecho`), and the very next read presents the warm close. The `session_ended` row lands at backgrounding, reveal, or supersede — the three sanctioned causes; no fourth emission site exists.
- **The supersede pair is the declare's signature.** `[session_ended, session_started{pocket}]` at one instant, adjacent in store read order: the ended row is the user-stop vocabulary (the tap emits it), the pair-preserve rule carries the in-progress card, and consumption restarts at 0 — the declaration bounds the sitting from now, exactly "the re-filter applies to the next deal". Latest-start-wins is unchanged, so a lingering spent session never coexists with the new one in the derivation.
- **Linger, don't eagerly close.** A spent pocketed session stays derived-open, exactly as pool exhaustion lingers today: the warm-close presentation is one surface and one string, the read facade's session semantics are unchanged, and no read-rule change is needed.
- **Pocket is a sitting bound, not a wallet.** The Time Bag stays a daily ceiling charged nowhere (2.1); the pocket bounds one sitting's dealt total and its wall-clock span. FR-9's rollback clause stays vacuously true — nothing is ever subtracted from the bag.
- **Ladder 5/10/15/20/25/30/45/60, titleless sheet.** The trigger-as-control was never drawn ("solo spine", mockups key-screens-1 §7): the bag-ladder idiom extended with 45/60 headroom keeps every option in range while 1–60 stays the command contract (sub-5 pockets are command-legal, not surfaced — swapping the list changes nothing else, the log payload is unaffected). No new strings: pills render via `durationMinutes`; context is the chip just tapped.
- **`appOpen` absorbs the reveal composition.** `sessionStart` no-ops on an open session, so the shell cannot compose the reveal from parts; the command resolves over a synthesized post-`session_ended` log — the established `_answered` pattern — keeping the bundle one atomic, testable list.

## Verification

**Commands:**
- `devbox run -- make codegen` -- expected: drift + l10n regeneration clean, `make codegen-check` green
- `devbox run -- make check` -- expected: store seal, purity, forbidden vocabulary, string-table audit with the parameterized key, text scaling all green
- `devbox run -- make test-core` -- expected: core suites green including the renegotiated pins
- `devbox run -- make gate` -- expected: test, format, analyze all green

**Manual checks (if no CLI):**
- On a device/emulator: declare 5 from the ladder with a card in progress — the card stays, `Hecho` consumes it, the next read presents the warm close; background mid-pocket and return — the reveal order holds; a v2 install upgraded in place opens with history intact.

## Suggested Review Order

**The derivation — AD-19 made real (start here)**

- The supersede pair's second half: a same-instant predecessor holds the standing card
  [`session.dart:189`](../../packages/core/lib/weave/session.dart#L189)

- Pocket consumption: answered estimates charge, upkeep included; skips release
  [`session.dart:240`](../../packages/core/lib/weave/session.dart#L240)

**The deal filter**

- `pocketAllows` — estimate ceiling plus derived wall-clock elapse, never a timer
  [`weave.dart:374`](../../packages/core/lib/weave/weave.dart#L374)

- Tier fall-through: chunk declined, upkeep and habits still dealt within budget
  [`weave.dart:482`](../../packages/core/lib/weave/weave.dart#L482)

**The commands — the only new minters**

- `sessionDeclare` — range guard, then the supersede pair with carried-card suppression
  [`session_commands.dart:210`](../../packages/core/lib/commands/session_commands.dart#L210)

- `appOpen` — the reveal: elapsed pocket closes first, then the fresh start
  [`session_commands.dart:256`](../../packages/core/lib/commands/session_commands.dart#L256)

**The substrate seam**

- `SessionStartEntry` — session_started leaves the moment family, carrying its pocket
  [`log_entry.dart:144`](../../packages/core/lib/log/log_entry.dart#L144)

- `pocketOnNonSessionStartKind` — moments must carry no pocket
  [`log_entry.dart:327`](../../packages/core/lib/log/log_entry.dart#L327)

- Schema 3, one ALTER-only step — v2 installs upgrade in place
  [`substrate.dart:49`](../../lib/store/substrate.dart#L49)

**The surfaces**

- `declarePocket` — the serialized write seam, one minted instant per batch
  [`dispenser_controller.dart:220`](../../lib/dispenser/dispenser_controller.dart#L220)

- `PocketTriggerChip` — the sentence pill, button semantics included
  [`duration_chip.dart:67`](../../lib/ui/dispenser/duration_chip.dart#L67)

- The ladder options — every pill in range by construction
  [`dispenser_screen.dart:76`](../../lib/ui/dispenser/dispenser_screen.dart#L76)

- The singular/plural sentence — ICU plural, canon kept
  [`app_es.arb:19`](../../lib/l10n/app_es.arb#L19)

**The proofs**

- Walk matrix: pair preserve, carried-card charge, same-instant order
  [`session_test.dart:461`](../../packages/core/test/session_test.dart#L461)

- No-fit warm close per tier, and the elapsed-at-instant boundary
  [`weave_test.dart:611`](../../packages/core/test/weave_test.dart#L611)

- Declare and reveal command matrices, refusals included
  [`session_commands_test.dart:322`](../../packages/core/test/session_commands_test.dart#L322)

- The v2→v3 migration on a seeded database
  [`substrate_test.dart:751`](../../test/store/substrate_test.dart#L751)

- The reveal at the controller — one instant, close before start
  [`session_controller_test.dart:512`](../../test/session/session_controller_test.dart#L512)

- Failing declare: nothing lands, chain recovers, no half pair
  [`dispenser_controller_test.dart:1150`](../../test/dispenser/dispenser_controller_test.dart#L1150)

- The vertical proof: chip, ladder, warm close and reveal through the screen
  [`dispenser_screen_test.dart:2218`](../../test/ui/dispenser/dispenser_screen_test.dart#L2218)

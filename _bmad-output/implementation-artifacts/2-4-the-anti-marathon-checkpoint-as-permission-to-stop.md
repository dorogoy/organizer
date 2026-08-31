---
title: 'The Anti-Marathon checkpoint as permission to stop'
type: 'feature'
created: '2026-08-31'
status: 'done'
review_loop_iteration: 2
baseline_commit: '73c713621a44d02c0c52f18ecfd963abe6cf1b61'
context: ['FR-10', 'FR-8', 'FR-9', 'FR-23', 'AD-6', 'AD-17', 'AD-19', 'UX-DR44', 'UX-DR51', 'UJ-1', 'NFR9']
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** FR-10's rest offer has no surface, no derivation and no vocabulary: nothing reads elapsed session time, `session_extended` does not exist (the walk's pocket is the start row alone), and the pre-seeded strings `checkpointStop` / `checkpointContinue` render nowhere — a long sitting never offers rest, and an elapsed pocket offers no way back in.

**Approach:** A pure checkpoint derivation in the facade's documented `core/derive` home (AD-6's non-work carve-out): cumulative same-day session seconds from start-day-charged session spans, interval multiples crossed versus answered (answered reads the last same-day `session_extended`), and a close-continue probe. The shell maps it to a third `DispenserView` variant — the permission-to-rest screen with `Nada más por el momento` primary and `Quiero seguir` silent secondary — plus the same continue action on the pocket-elapsed close; `sessionExtend` mints the one new kind additively, reusing the `pocketMinutes` column so the declared pocket (deadline and ceiling) lifts with no schema change.

## Boundaries & Constraints

**Always:**
- The interval is a builder constant, never a Settings row (§10.1; EXPERIENCE's five groups own none): `checkpointIntervalMinutes = 15`, pinned inside 10–15 by test.
- Cumulative session time sums session spans charged to each session's own start day (AD-19's ledger rule), the open session truncated at the read instant. Crossed = floor(cumulative / interval); answered = floor(cumulative-at-instant of the last same-day `session_extended`), consuming every lower multiple. The offer is due only inside an open, unelapsed session — the standing close always wins (UJ-1). Chaining cannot dodge: a crossed multiple stays pending until `Quiero seguir` answers it; no session boundary, supersede or stop consumes it.
- The reveal is derived at reads, never scheduled (AD-17, AD-19's reveal-not-await): init, resume, post-answer, post-declare — no Timer, no periodic write.
- Preemption: the offer preempts a standing card only when that card was dealt at-or-after the pending boundary (floor at its deal instant > answered) — a card in flight at the crossing stays visible and finishable (FR-10); every later deal hides behind the offer and returns with one silent tap, never re-dealt.
- A pocket-elapsed close carries `Quiero seguir` as a silent secondary only while a deal would exist if the pocket had room (the core's pool probe); a pool-exhausted close carries nothing.
- `Quiero seguir` appends exactly one `session_extended` row carrying `checkpointIntervalMinutes` added minutes through the single sanctioned minter `sessionExtend` (open-session guard; refusal is silence — the `PocketTriggerChip` no-op precedent). The walk's `openSessionPocketMinutes` becomes the start pocket plus the open session's extensions — the declarable 1–60 range bounds starts only, the sum may pass it — lifting `pocketAllows`'s deadline and ceiling; the original pocket stays readable off the start row for FR-23, proven by test.
- Stop is always one tap: the offer's primary `Nada más por el momento` runs the pause write (`sessionEnd` → warm close); `Quiero seguir` renders as `SecondaryTextAction` — never filled, never emphasized, never animated, no haptic (FR-10, UX-DR44). `_onExtend` is `_onPause`'s mechanics verbatim (guard, `_readGeneration++`, await settle, commit, post-frame release, absorb failure into the empty frame).
- Strings are the pre-seeded ARB pair, verbatim, zero ARB edits; the surface respects the short-surface floor (320×220 @200% grows and scrolls).

**Ask First:** The extension amount (one interval at every acceptance, mid-pocket included) and the extends-only consumption rule (a stop leaves a crossed multiple pending, so the next sitting re-offers) are recorded readings with no verbatim upstream pin — they land beside 2.1's ceiling text as code-doc plus this spec record; a spine edit to host them is the human's call (2.3's precedent).

**Never:** No `¿seguimos?` or any continuation question; no count of anything on the offer (UJ-1: no number that would have been higher); no timer, Ticker or scheduled write; no Settings row or `setting_changed` key for the interval; no new ARB string, no new LogEntryRecord column, no schema version bump (the `pocketMinutes` column is reused); no fourth closing cause — `sessionExtend` never appends `session_ended` and never re-opens; no `LogFacts` field-list change; no energy/strip/check-in surface (2.5); no golden tests.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Behavior | Error Handling |
|----------|---------------|-------------------|-----------------|
| Mid-pocket multiple | 45-pocket, interval 15, read at cumulative ≥ 15 | `DispenserRestOffer` preempts; extend → one `session_extended{15}`, card returns, chip reads 60 | N/A |
| Three offers, 45-pocket | extends accepted at 15 and 30 | offers at 15, 30, 45; ceiling 45→60→75 (sum may pass 60) | N/A |
| Stop at the offer | offer visible, `Nada más por el momento` tapped | `session_ended` → warm close; the multiple stays pending | N/A |
| Chained short pockets | 4 × 10-minute sittings, same day | session 5's first read preempts with the offer; one extension answers both pending multiples | N/A |
| Card in flight at crossing | card dealt at cumulative 13, crossing 15 | card stays visible and finishable; offer preempts the read after it resolves | N/A |
| Card dealt into pending offer | bundled deal at cumulative 17, multiple pending | offer preempts the standing card; `Quiero seguir` returns it, never re-dealt | N/A |
| Coincides with close | 15-pocket, interval 15, cumulative 15 | the standing close wins, `Quiero seguir` offered iff the pool could deal; no second surface (UJ-1) | N/A |
| Extend at the close | elapsed pocket, pool has candidates | one `session_extended{15}`; the read after deals or resurfaces the card | N/A |
| Pool-exhausted close | no candidates anywhere | plain close, no continue action; a stray extend tap lands nothing | quiet no-op |
| Short first session | day's only session < one interval | no offer; the close is the permission (FR-10) | N/A |
| No open session | extend tapped with nothing open | `sessionExtend` → `[]`; nothing lands, no state change | silent |
| Failing append | store throws on the extend write | nothing lands; empty frame stands; queue recovers (declare precedent) | quiet |
| Day boundary | session crossing 04:00; other days' extends/ends | spans charge to the start day; other days' rows answer nothing today | N/A |
| Interval constant | any build | 15, and 10 ≤ interval ≤ 15 (§10.1 pin) | N/A |

</frozen-after-approval>

## Code Map

- `packages/core/lib/derive/checkpoint.dart` (new) -- the derivation + interval constants; `read_facade.dart:4-5` names `core/derive` as derived signals' home (its doc gains the arrival line); AD-6 carve-out; start-day charging idiom `energy/energy.dart:55-78`; `microsPerMinute` `settings/settings.dart:65`; deadline-comparison pattern `weave/weave.dart:368-384`
- `packages/core/lib/log/log_entry.dart:24-69,144-159` -- ninth kind `sessionExtended` + `SessionExtendEntry{kind, pocketMinutes}` reusing the record column (`ports/store_port.dart:49`), no schema bump (additive pattern `store/substrate.dart:41-63`); renegotiate the `:140` "extensions are 2.4's" doc; parse/convert paths
- `packages/core/lib/weave/session.dart:139-268` -- the walk's new case: extensions sum into `openSessionPocketMinutes` while a session is open; the start's 1–60 guard (`:200-206`) unchanged; supersede adjacency (`:182-195,208-219`) untouched — the command's guard keeps the kind out of pair interiors
- `packages/core/lib/commands/session_commands.dart` -- `sessionExtend` beside `sessionDeclare`: `{catalogue, log, instantUtcMicros, offsetSeconds}` (sessionDeclare's shape, review iteration 1 — AD-3 bundled deal on close-continue), open-session guard, one `session_extended` carrying the interval plus `card_dealt?` when no unanswered card stands; doc: single sanctioned minter, AD-19 sum, FR-23 original-pocket, no fourth closing cause
- `packages/core/lib/weave/weave.dart` -- narrow pool probe (`dealExistsIgnoringPocket` or an equivalent internal seam): the resolver's tiers with `pocketAllows` lifted, documented as the checkpoint's close-continue probe
- `packages/core/test/log_test.dart:29-51` -- kind pin eight→nine, deliberate; payload pins
- `packages/core/test/session_test.dart` + `packages/core/test/session_commands_test.dart` -- sum pins (deadline/ceiling lift, original preserved, supersede drops the old session's extensions, 04:00 span charging, stray tolerance); the `sessionExtend` matrix; builders `_started(micros, {pocketMinutes})` (`session_test.dart:41-48`) + an `_extended` sibling
- `packages/core/test/checkpoint_test.dart` (new) -- every matrix row above + the interval pin; `utcMicros` helper `test/test_util.dart:4-22`
- `packages/core/test/no_lateness_proof_test.dart:639-700,857-995` -- freeze registration for the new shapes (`SessionExtendEntry`, the derivation's state record); `LogFacts` list unchanged
- `lib/dispenser/dispenser_controller.dart:21-47,89-120,262-282` -- third variant `DispenserRestOffer{pocketMinutes}`; `read()` maps the derivation per the frozen precedence; `extend()` in `declarePocket`'s write shape — catalogue + bag threaded, write-then-read-back
- `lib/ui/dispenser/dispenser_screen.dart:384-396,403-409,484-562` -- the offer arm (primary `checkpointStop` in the Done button's register, `task_card.dart:75-109`'s grammar; `checkpointContinue` as `SecondaryTextAction`); `_onExtend` = `_onPause` verbatim; the closed arm's conditional continue; `_withCompletionAck` wrap; short-surface reflow inherited (`:90,350-370`)
- `lib/l10n/app_es.arb:129-137` -- READ ONLY: both strings pre-seeded with accessors generated; `make codegen-check` must stay green with zero churn
- `test/no_lateness_proof_test.dart:10-17,199-207,311-334` -- census 4→5 in both maps, header wording, `bannedWireNames` += `session_extended`; constant-idiom scan: `sessionExtend(` exactly once in the controller (`:270-283` pattern)
- `test/dispenser/dispenser_controller_test.dart` + `test/ui/dispenser/dispenser_screen_test.dart` -- extend/read matrices mirroring the I/O rows; screen pins: both strings via `find.text`, continue never primary (style pin), stop→close, extend→card-returns, extendable-close, silence (no haptics on extend), the 320×220 @200% offer, stale-read race (`_readGeneration`); reuse `_RecordingStore`, `_FailNextAppendStore`, `launchAndCommit`, `_censusOf`, lifecycle faking, `_fixedClock`, `seedPocketedStart`

## Tasks & Acceptance

**Execution:**
- [x] `packages/core/lib/derive/checkpoint.dart` + `packages/core/lib/facade/read_facade.dart` -- the derivation + interval constants + the doc's arrival line -- cumulative spans, crossed/answered, due, preemption, close-continue (FR-10, §10.1, AD-6)
- [x] `packages/core/lib/log/log_entry.dart` -- `sessionExtended` + `SessionExtendEntry` reusing `pocketMinutes` -- additive, no schema bump (AD-23)
- [x] `packages/core/lib/weave/session.dart` -- the walk sums the open session's extensions into the declared pocket -- deadline and ceiling lift; original pocket preserved (AD-19, FR-23)
- [x] `packages/core/lib/commands/session_commands.dart` -- `sessionExtend`, the single sanctioned minter -- one row, +interval, open-session guard
- [x] `packages/core/lib/weave/weave.dart` -- the pool probe seam -- the close-continue truth
- [x] `packages/core/test/checkpoint_test.dart` + `packages/core/test/log_test.dart` + `packages/core/test/session_test.dart` + `packages/core/test/session_commands_test.dart` + `packages/core/test/no_lateness_proof_test.dart` -- every matrix row, the interval pin, kind pin nine, sum/original pins, freeze registrations
- [x] `lib/dispenser/dispenser_controller.dart` -- `extend()` + the read mapping -- `DispenserRestOffer`, `DispenserClosed{continueOffered}`
- [x] `lib/ui/dispenser/dispenser_screen.dart` -- the offer surface + the close's continue + `_onExtend` -- primary stop, silent secondary, one-tap mechanics (FR-10, UX-DR43/44/51)
- [x] `test/no_lateness_proof_test.dart` -- census 4→5, wire name, header wording
- [x] `test/dispenser/dispenser_controller_test.dart` + `test/ui/dispenser/dispenser_screen_test.dart` -- controller matrix, screen flows, silence, the 200% floor, race pins

**Acceptance Criteria:**
- Given a session and a day whose cumulative session time crosses an unanswered interval multiple, when any read resolves, then the permission-to-rest screen is the primary surface — `Nada más por el momento` primary, `Quiero seguir` silent secondary — and no continuation question exists anywhere (FR-10, UX-DR44, UX-DR51)
- Given the offer, when either action is taken, then exactly one `session_extended{15}` or `session_ended` appends and stopping costs one tap (FR-9, FR-10); when the lift unblocks a sitting with no unanswered card, the command also returns the bundled next `card_dealt` (AD-3)
- Given chained same-day sessions, when a multiple crosses, then it stays pending until extended — no boundary, supersede or stop consumes it (FR-10, AD-19)
- Given a card in flight at the crossing, when the surface resolves, then the card stays finishable and the offer preempts only deals made at-or-after the boundary (FR-10)
- Given a pocket that elapses at a multiple, when the close resolves, then the close is the offer — `Quiero seguir` offered only while the pool could deal — and no second surface exists (FR-10, UJ-1)
- Given `session_extended` rows, when derivations read them, then the declared pocket is the start plus the sum, the deadline and ceiling lift, and FR-23's original pocket stays readable off the start row (AD-19, FR-23)
- Given the completion gate, then `make check`, `make test-core` and `make gate` are green

## Spec Change Log

- 2026-08-31 review iteration 1: `sessionExtend` takes catalogue + instant (`sessionDeclare`'s shape) and returns `[session_extended, card_dealt?]` when the lift unblocks a sitting with no unanswered card, so close-continue's visible card is command-minted (AD-3). Mid-pocket still one row. Frozen Always (`exactly one session_extended`) unchanged.

## Design Notes

- **Why extends-only consumption.** If a close consumed pending multiples, four chained ten-minute pockets would never see the offer — exactly FR-10's named dodge; consuming at starts fails one step earlier. So only `Quiero seguir` answers a multiple, and one acceptance (max-based) answers every lower multiple too. A stop leaves it pending and the next sitting faces the standing permission once — cadence once per sitting plus once per crossing, inside §10.2's anti-nag intent.
- **Why preemption is deal-instant-based.** The facade resolves the standing card first, so a due offer could never fire — every answer bundles the next deal. Preempting exactly the cards dealt at-or-after the pending boundary (floor at the deal instant > answered) keeps the in-flight card finishable (FR-10's clause) while unblocking the reveal; cumulative-at-instant is the same fold as cumulative-now with the open span truncated at that instant.
- **The close and the offer are one grammar.** UJ-1's coincidence (15/15) makes the close the offer; the continue action on the close is the same `Quiero seguir` and the same `extend()` — a pocket-elapsed close is just the pocket filter, lifted by the extension, so the read after the tap deals the card. FR-10's "extend at the end via the same silent action" falls out with no second mechanism.
- **Column reuse over schema v4.** `session_extended`'s payload is minutes of pocket — the fact `pocketMinutes` already carries on `session_started`. Reusing the column keeps the store sealed at v3 and AD-23 intact; a new column would buy a second name for one fact.
- **`core/derive` arrives.** The facade doc already reserved the home; the checkpoint is its first resident — derived state reaching the shell for a non-work surface, AD-6's carve-out — so the weave's own work policy stays untouched.

## Verification

**Commands:**
- `devbox run -- make codegen` -- expected: zero churn — both strings pre-seeded, accessors already generated
- `devbox run -- make check` -- expected: purity, vocabulary (`checkpoint`/`interval`/`cumulative` clean; no `pending`), string audit, freeze suite green with the ninth kind registered
- `devbox run -- make test-core` -- expected: the derivation matrix, sum/original pins, the command matrix green
- `devbox run -- make gate` -- expected: test, format, analyze all green

**Manual checks (if no CLI):**
- On a device: a 15-minute pocket ends in the close with `Quiero seguir` present only while more work could deal; a 45-minute pocket offers rest at each multiple after the card finishes; extend returns the card silently; stop always one tap; nothing counts anything, at 200% included.

## Suggested Review Order

**The derivation — the design's heart**

- The interval, a builder constant inside §10.1's 10–15, never a Settings row
  [`checkpoint.dart:46`](../../packages/core/lib/derive/checkpoint.dart#L46)

- The state facts the shell reads — due, and when the offer preempts a standing deal
  [`checkpoint.dart:51`](../../packages/core/lib/derive/checkpoint.dart#L51)

- The fold itself: start-day-charged spans, crossed vs max-answered, extends-only consumption
  [`checkpoint.dart:89`](../../packages/core/lib/derive/checkpoint.dart#L89)

- The truthful window — `Quiero seguir` only where one tap un-elapses the pocket
  [`checkpoint.dart:242`](../../packages/core/lib/derive/checkpoint.dart#L242)

- The doc that reserved this home — derived signals have now arrived
  [`read_facade.dart:1`](../../packages/core/lib/facade/read_facade.dart#L1)

**The vocabulary — one kind, no schema**

- The ninth kind, reusing the `pocketMinutes` column — no v4 bump
  [`log_entry.dart:41`](../../packages/core/lib/log/log_entry.dart#L41)

- The entry subtype; the renamed pocket-flaw now names its real rule
  [`log_entry.dart:176`](../../packages/core/lib/log/log_entry.dart#L176)

**The ledger — extensions lift the declared pocket**

- The walk's sum: start plus the sitting's extensions; deadline and ceiling follow
  [`session.dart:219`](../../packages/core/lib/weave/session.dart#L219)

**The minter**

- `sessionExtend`, catalogue + instant, one `session_extended` plus bundled deal when unanswered is empty, +interval, refusal is silence
  [`session_commands.dart:231`](../../packages/core/lib/commands/session_commands.dart#L231)

**The probe**

- One shared tier ladder — nextDeal and the probe cannot drift apart
  [`weave.dart:500`](../../packages/core/lib/weave/weave.dart#L500)

- The close-continue probe over the lifted pocket
  [`weave.dart:550`](../../packages/core/lib/weave/weave.dart#L550)

**The shell mapping**

- The third view variant and the close's `continueOffered`
  [`dispenser_controller.dart:64`](../../lib/dispenser/dispenser_controller.dart#L64)

- The read precedence — close > offer > card, checkpoint state beside the walk
  [`dispenser_controller.dart:176`](../../lib/dispenser/dispenser_controller.dart#L176)

- `extend()` — pause's shape, write-then-read-back
  [`dispenser_controller.dart:369`](../../lib/dispenser/dispenser_controller.dart#L369)

**The surface**

- The offer: `Nada más por el momento` primary, `Quiero seguir` secondary — one grammar
  [`dispenser_screen.dart:727`](../../lib/ui/dispenser/dispenser_screen.dart#L727)

- The extendable close — the same silent action beneath the warm string
  [`dispenser_screen.dart:750`](../../lib/ui/dispenser/dispenser_screen.dart#L750)

- `_onExtend` — `_onPause`'s mechanics verbatim
  [`dispenser_screen.dart:601`](../../lib/ui/dispenser/dispenser_screen.dart#L601)

- The `label` seam that let the primary wear the checkpoint string
  [`task_card.dart:30`](../../lib/ui/dispenser/task_card.dart#L30)

**The proofs**

- The derivation matrix — every I/O row, the interval pin, unbounded sittings
  [`checkpoint_test.dart:507`](../../packages/core/test/checkpoint_test.dart#L507)

- The minter matrix
  [`checkpoint_test.dart:748`](../../packages/core/test/checkpoint_test.dart#L748)

- The controller's extend/read mapping and the screen's flows, silence, 200% floor
  [`dispenser_controller_test.dart:1606`](../../test/dispenser/dispenser_controller_test.dart#L1606)

- The census — five append sites, the wire name, the header wording
  [`no_lateness_proof_test.dart:311`](../../test/no_lateness_proof_test.dart#L311)

### Review Findings

Chunk 1 of 4 — production core (`derive/checkpoint`, `session_commands`, `session` walk, `weave`, `log_entry`, `read_facade`). Shell, tests, and artifacts are later chunks.

- [x] [Review][Patch] Close-continue shows a never-dealt card, so Hecho appends nothing — `sessionExtend` takes catalogue + instant (sessionDeclare's shape) and returns `[session_extended, card_dealt?]` when the lift unblocks a sitting with no unanswered card; mid-pocket stays one row. Human chose option 2. [`packages/core/lib/commands/session_commands.dart:231`]
- [x] [Review][Patch] `SessionExtendEntry` documents minted-shape-or-absent; walk and derive accept any `pocketMinutes > 0` [`packages/core/lib/log/log_entry.dart:187`]
- [x] [Review][Patch] `offerDue` field comment says "the sitting's extensions" but the fold is same-day across sittings [`packages/core/lib/derive/checkpoint.dart:57`]

Chunk 2 of 4 — shell (`dispenser_controller.dart`, `dispenser_screen.dart`, `task_card.dart`).

- [x] [Review][Patch] Failed `Quiero seguir` has no screen pin of the I/O empty-frame row — pause and declare already have the `_FailNextAppendStore` surface test; continue does not [`test/ui/dispenser/dispenser_screen_test.dart:3430`]
- [x] [Review][Patch] `HechoButton` with the wrapping checkpoint label has no `textAlign: center` and no horizontal inset, so `Nada más por el momento` at 200% sits start-aligned and can meet the 14px clip radius [`lib/ui/dispenser/task_card.dart:58`]
- [x] [Review][Patch] `_onExtend` still documents a one-row extension / card-returns-or-close-stands and omits close-continue's command-minted deal [`lib/ui/dispenser/dispenser_screen.dart:587`]
- [x] [Review][Defer] Sequential `appendLogEntry` is not a transaction — if bundled `card_dealt` throws after `session_extended` landed, resume can show a never-dealt card [`lib/dispenser/dispenser_controller.dart:385`] — deferred, pre-existing

Chunk 3+4 of 4 — tests and artifacts (combined pass).

- [x] [Review][Patch] Mid-pocket due is pinned at 16, never at the matrix `≥ 15` boundary [`packages/core/test/checkpoint_test.dart:97`]
- [x] [Review][Patch] Three-offers row never derives at 15 or 30 — only after both extends at minute 46 [`packages/core/test/checkpoint_test.dart:138`]
- [x] [Review][Patch] Chained shorts / stop-then-next-sitting never put a bundled `card_dealt` on the new sitting, so `offerPreemptsStandingDeal` (FR-10's named dodge) is unpinned [`packages/core/test/checkpoint_test.dart:189`]
- [x] [Review][Patch] Close-continue with a standing unanswered card is untested — bundling must not mint a second deal [`packages/core/test/session_commands_test.dart:280`]
- [x] [Review][Patch] `HechoButton` wrap/inset is proven on `'Hecho'`, not on `checkpointStop` [`test/ui/dispenser/task_card_test.dart:243`]
- [x] [Review][Patch] `closeContinueReachable` is sampled at just-elapsed and +40, never at the exclusive `pocket+interval` bound [`packages/core/test/checkpoint_test.dart:685`]
- [x] [Review][Defer] Pool-exhausted stray `extend()` on an still-open sitting is UI-guarded (`continueOffered: false`) while the minter still only no-ops when nothing is open — same open-session command shape as pause [`packages/core/lib/commands/session_commands.dart:252`] — deferred, pre-existing command guard

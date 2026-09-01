---
title: 'Warm Return (2-7)'
type: 'feature'
created: '2026-09-01'
status: 'done'
review_loop_iteration: 0
baseline_commit: '7191bcf81584efd08cb8cd61464ddc0cf3f0cb44'
context: []
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** FR-6's welcome-back state has no derivation: `warmReturnDue` (AD-24) exists only in comments and lint fixtures, and the fixed greeting `Siempre a tu disposición` (ARB `warmReturnGreeting`, shipped by Story 1-2) is referenced by no surface — after days away the app opens exactly as on any day, with nothing receiving the user.

**Approach:** Add the sibling predicate in `packages/core/lib/derive/warm_return.dart` — pure over the log, measuring 48 h wall-clock from the latest contact (`app_opened` rows and user acts) that precedes the current opening — read it in `DispenserController.read()` beside `deriveStrip`/`deriveCheckpoint`, carry it on `DispenserView` as a base fact, and render the greeting line above the committed view in `_withCompletionAck`'s register. No new log kind, no write, no ARB change.

## Boundaries & Constraints

**Always:**
- `bool warmReturnDue({required List<LogEntry> entries, required int instantUtcMicros})` in a new `packages/core/lib/derive/warm_return.dart`, pure (AD-3), rows after the read instant skipped (the convention, strip.dart:199). No `offsetSeconds`: 48 h is a wall-clock duration between absolute instants; the predicate never computes a day.
- The current opening is the last `app_opened` row at or before the read instant, in store order; the anchor is the max instant among rows strictly before that row in list order that are `app_opened` rows or user acts. Due iff `instantUtcMicros − anchor ≥ 48 h` (micros). No `app_opened` row at all → false; no anchor before the last one → false.
- User acts = every typed entry except the system events (AD-21's enumeration; today `app_opened` = `MomentEntry(appOpened)` and `crash_recorded` = `CrashEntry`); `UnknownEntry` contributes nothing — a future kind joins exactly one set when it lands, said in the code-doc.
- All three `DispenserView` variants carry the base field `bool warmReturnDue` (default `false`, so existing constructors and tests compile), set from the one read; the greeting shows for the whole opening — no timer, no dismissal (the 2-s `_withCompletionAck` window is not this) — on every variant.
- The greeting mirrors `_withCompletionAck`'s grammar: `AppStrings.of(context).warmReturnGreeting`, `bodySmall` (the wired support role), centered, `Spacing.actionGap`, above the committed view, no glyph, fill, motion or dismissal control.
- Mid-opening user acts never move the anchor (they sit after the last `app_opened`): the greeting persists through the session and is gone by derivation at the next non-warm opening.

**Ask First:** None — AD-24/AD-6/AD-21 and UX-DR51 fix every decision; the text-only greeting (no seed illustration) follows Story 2-4's precedent for a named illustration-register surface and lands as code-doc plus this record.

**Never:** No new log kind and no write of any kind (the controller's append census stays at 7); no ARB or codegen change (`warmReturnGreeting` already shipped); not a strip resident (Warm Return is not in UX-DR22's precedence); no seed glyph or motion dashes (the lever was dissolved 2026-08-28 — at rest everywhere); no dismissal or persistence state; no days-away, backlog or streak representation anywhere; no clock read inside core.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Behavior | Error Handling |
|----------|---------------|-------------------|-----------------|
| First-ever open | one `app_opened` (the current one), no prior rows | false | N/A |
| Boundary | prior contact exactly 48 h before the read | true (≥ is inclusive) | N/A |
| Just under | contact 47 h 59 m 59 s ago | false | N/A |
| Daily lurker | `app_opened` without acts every 24 h | false — the anchor moves with each peek | N/A |
| Act after open | an act 30 m after the morning open | anchor = the act's instant | N/A |
| Crash row after contact | `crash_recorded` lands after the last contact | excluded (system event) — still due | N/A |
| Opening batch | `session_started` + `card_dealt` at the open's own instant | contribute nothing — the anchor is prior contact | N/A |
| Mid-session read | re-read after any tap in the same opening | still true — opening-scoped | N/A |
| Next open inside 48 h | yesterday's contact | false — greeting gone | N/A |
| No `app_opened` at all | acts only (pure-function edge) | false — no current opening defined | N/A |
| Unknown kind row | a tolerated row | contributes nothing to the anchor | N/A |
| 200% font scale | textScaler 2.0 | the greeting wraps inside the scroll, nothing truncates | N/A |

</frozen-after-approval>

## Code Map

- `packages/core/lib/derive/warm_return.dart` -- NEW: the predicate, the 48 h threshold const, the `_isUserAct` classification; docs cite AD-24/AD-21/AD-6 (shape precedents: `derive/checkpoint.dart`, `derive/strip.dart`)
- `packages/core/lib/log/log_entry.dart` -- READ ONLY: the nine subtypes; `MomentEntry` carries `appOpened`/`sessionEnded` (:137-158); `CrashEntry` and `UnknownEntry` close the classification
- `packages/core/test/warm_return_test.dart` -- NEW: the matrix above as core pins, builders mirroring `strip_test.dart:9-55`
- `packages/core/test/no_lateness_proof_test.dart:1490-1500` -- add `'derive/warm_return.dart'` to the `allowed` set (the `app_opened` wire-name scan); no mint census changes — nothing new is minted
- `lib/dispenser/dispenser_controller.dart:35-51` -- `DispenserView` base gains `warmReturnDue`; `read()` :213-323 derives it beside `deriveStrip` (:243) and passes it to all three constructions (:281, :311, :317)
- `lib/ui/dispenser/dispenser_screen.dart:417-445` -- `_viewContent` wraps once when `view.warmReturnDue`; `_withCompletionAck` :957-974 is the grammar to mirror
- `lib/strings/app_strings.dart:246`, `lib/l10n/app_es.arb:139-140` -- READ ONLY: `warmReturnGreeting` = `Siempre a tu disposición`, accessors already generated
- `lib/session/session_controller.dart:185-203` -- READ ONLY: one minted instant serves the whole opening batch — why list order identifies the current open
- `test/dispenser/dispenser_controller_test.dart` -- new group: `_fixedClock` :255, `_moment`/`_act` seed helpers :285-315, `openSessionAndReadFirstDeal` :330-344; propagation pins for Closed/RestOffer
- `test/ui/dispenser/dispenser_screen_test.dart:2013-2150` -- the seven-day-absence group to extend; `_censusOf` :447-500 is the no-gap enforcement
- `test/no_lateness_proof_test.dart:338-374` -- READ ONLY, verify only: the append census is unchanged

## Tasks & Acceptance

**Execution:**
- [x] `packages/core/lib/derive/warm_return.dart` -- the predicate, the classification helper, the threshold const, AD-citing docs
- [x] `packages/core/test/warm_return_test.dart` -- the I/O matrix as core pins (inclusive boundary, lurker, crash exclusion, batch exclusion, mid-session, unknown, post-instant skip)
- [x] `packages/core/test/no_lateness_proof_test.dart` -- the `allowed` set gains the new reader
- [x] `lib/dispenser/dispenser_controller.dart` -- the base field, the read-time derivation, the three constructions
- [x] `lib/ui/dispenser/dispenser_screen.dart` -- the `_viewContent` single wrap; `_withWarmReturnGreeting` in the ack's register
- [x] `test/dispenser/dispenser_controller_test.dart` -- the warm-return group (due/not-due via seeded gap, opening persistence, variant propagation, append sequence unchanged)
- [x] `test/ui/dispenser/dispenser_screen_test.dart` -- greeting present above the card on the seven-day launch, absent on the control, census diff = exactly one text node, 200% floor

**Acceptance Criteria:**
- Given 48 h since the latest contact before the current opening, when the read commits, then `view.warmReturnDue` is true on every variant and `Siempre a tu disposición` renders above the committed view
- Given any write-then-read inside the same opening, then the greeting still stands; given the next opening inside 48 h, then it is gone — no state anywhere, the derivation alone
- Given the seven-day-absence launch, then the appended rows are exactly `['app_opened','session_started','card_dealt']` and the census diff against a control launch is the greeting text alone — no count, no backlog, no days-away copy anywhere
- Given the completion gate, then `make check`, `make test`, `make codegen-check` (no churn) and `make gate` are green

### Review Findings

- [x] [Review][Decision] El reloj del umbral es el instante de lectura, no el del `app_opened` actual — descartado: Always y el boundary del matrix mandan; «opening-scoped» solo significa que un `true` no se apaga. (elección 2)
- [x] [Review][Patch] El test de censo de session kinds sigue titulándose «read in exactly one» después de añadir el segundo lector de `app_opened` [packages/core/test/no_lateness_proof_test.dart:1482]

## Spec Change Log

## Design Notes

- **Why list order, not instant equality.** The opening batch (`app_opened` + `session_started` + `card_dealt`) shares one minted instant (session_controller.dart:185-203), so "before the last `app_opened`'s instant" and "before that row in store order" differ only on same-instant clock collisions — list order is the log's own truth and needs no tie-break.
- **Why the last `app_opened` is the current opening.** The read is queue-consistent after the opening batch (the screen awaits `sessionSettled()`), so no later open can exist; anchoring on the literal last `app_opened` would include the current one and the predicate could never fire. AD-24's "48 h since the later of the last `app_opened` and the last user act" reads on contact *before* this opening — the only reading under which the AC's "When the app is opened / Then derives true" is satisfiable.
- **Why text-only.** DESIGN.md:548 names Warm Return a legitimate illustration-register home (seed at scale, at rest since the 2026-08-28 dissolution) — permission, not mandate; Story 2-4's permission-to-rest surface (also named there) shipped text-only. The greeting stays in the fixed-string economy; an illustration, if ever wanted, is a UX pass away.

## Verification

**Commands:**
- `devbox run -- make check` -- expected: purity, string audit, forbidden vocabulary and censuses green (the new reader allowed)
- `devbox run -- make test` -- expected: the core `warm_return` suite plus the controller and screen groups green
- `devbox run -- make codegen-check` -- expected: clean — no ARB change, no churn
- `devbox run -- make gate` -- expected: test, format, analyze all green

## Suggested Review Order

**The derivation — AD-24's sibling predicate**

- The predicate itself — pure, one pass, the anchor is contact strictly before the current opening
  [`warm_return.dart:92`](../../packages/core/lib/derive/warm_return.dart#L92)

- The 48 h threshold — wall-clock micros, never a day count, no offset
  [`warm_return.dart:50`](../../packages/core/lib/derive/warm_return.dart#L50)

- The act/system classification — moment kinds whitelisted like `UnknownEntry`, future-safe
  [`warm_return.dart:59`](../../packages/core/lib/derive/warm_return.dart#L59)

**The shell — the fact rides one read**

- The base field — default false, carried by every variant, no state anywhere
  [`dispenser_controller.dart:71`](../../lib/dispenser/dispenser_controller.dart#L71)

- The read derives it beside the strip — same queue-consistent log
  [`dispenser_controller.dart:278`](../../lib/dispenser/dispenser_controller.dart#L278)

**The surface — the fixed greeting**

- The single wrap site — after the variant switch, inside the frame's scroll
  [`dispenser_screen.dart:456`](../../lib/ui/dispenser/dispenser_screen.dart#L456)

- The greeting in the ack's register — bodySmall, centered, no timer, no dismissal
  [`dispenser_screen.dart:1001`](../../lib/ui/dispenser/dispenser_screen.dart#L1001)

**The proofs**

- The stated-reader `allowed` set — `app_opened`'s second legitimate reader
  [`no_lateness_proof_test.dart:1502`](../../packages/core/test/no_lateness_proof_test.dart#L1502)

**The tests**

- The core I/O matrix — inclusive boundary, lurker, batch exclusion, mid-session, repeats
  [`warm_return_test.dart:76`](../../packages/core/test/warm_return_test.dart#L76)

- Every payload-carrying act kind moves the anchor — parameterized
  [`warm_return_test.dart:202`](../../packages/core/test/warm_return_test.dart#L202)

- The controller group — append sequence pinned, opening persistence, variant propagation
  [`dispenser_controller_test.dart:2910`](../../test/dispenser/dispenser_controller_test.dart#L2910)

- The seven-day launch — census diff is the greeting text alone, nothing gap-shaped
  [`dispenser_screen_test.dart:2023`](../../test/ui/dispenser/dispenser_screen_test.dart#L2023)

- The 200% floor — greeting wraps in the scroll, controls stay reachable
  [`dispenser_screen_test.dart:2230`](../../test/ui/dispenser/dispenser_screen_test.dart#L2230)

- The warm close variant — the fact rides every variant, geometrically pinned
  [`dispenser_screen_test.dart:2306`](../../test/ui/dispenser/dispenser_screen_test.dart#L2306)

- The `screenKey` reuse warning — the double-pump pitfall, documented at the source
  [`dispenser_screen_test.dart:539`](../../test/ui/dispenser/dispenser_screen_test.dart#L539)

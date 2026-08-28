---
title: 'One calendar authority'
type: 'feature'
created: '2026-08-29'
status: 'done'
review_loop_iteration: 0
baseline_commit: '4038d217dcf997ac3451d51232d636b1f3f0fa73'
context: []
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** No code converts an instant into a period — every rule that says "day", "week" or "season" rests on nothing, so two units could implement two clocks (AD-4); the never-re-date guarantee (stored offset, never device zone) and the day-scoped energy default are equally unbacked.

**Approach:** Add `packages/core/lib/day/` — the one `Calendar` converting instant+offset into half-open Day/Week/Season periods (04:00-anchored day, Monday-anchored week, meteorological season, all computed in the entry's stored-offset frame) — plus a pure day-scoped energy derivation in `packages/core/lib/energy/`.

## Boundaries & Constraints

**Always:**
- One `Calendar` in `packages/core/lib/day/` is the only instant→period converter (AD-4). Stateless, const-constructible, deterministic — a pure function of `(instantUtcMicros, offsetSeconds)`; the API accepts no device-zone input, so re-dating history is unrepresentable.
- Day = `[04:00 local, 04:00 local next)` computed in the entry's stored-offset frame (fixed offset ⇒ exactly 24 h; no timezone database, no DST rule engine). Day identity = civil-date label (y/m/d) in that frame. Week = seven domestic days anchored on Monday (identity = Monday label; Sunday is its last day). Season = meteorological quarter (DJF/MAM/JJA/SON) on domestic-day boundaries; winter is anchored on its December.
- Periods are half-open and expose start / end-exclusive instants in the entry's frame; `Day` exposes its weekday (Mon=1…Sun=7).
- Energy: `EnergyLevel` (`full`/`medium`/`low` — semantic names, Spanish copy is 2.5's ARB concern) + `deriveEnergyForLivePool` — last observation of the current domestic day, else `full` (🟢). Derived, never written — structurally: it is a pure function with no store access.
- Pure Dart, `dart:core` only, zero new dependencies (core purity check stays green); core tests use `package:test`.
- Enforcement of "no other code computes a boundary" stays core-test- and review-enforced per the spine (SPINE:242) — no new `tool/` check this story.

**Ask First:** None.

**Never:** No timezone/DST package; no wall-clock or ambient reads (`DateTime.now()` stays out of the core); no energy writer, no `energy_set` log kind, no port DTO or schema growth (Story 2.5 owns them); no changes to `packages/core/lib/ports/` (pinned by `ports_test.dart` to exactly two files); no UI and no ARB strings; no period kinds beyond Day/Week/Season.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|---------------|---------------------------|----------------|
| Mid-day instant | 2026-08-29 10:00, offset +02:00 | Day labelled 2026-08-29; window [04:00+2, next 04:00+2) | N/A |
| Boundary halves | local 03:59:59.999999 vs 04:00:00.000000 | Previous-day label vs new-day label (half-open) | N/A |
| Stored offset rules | Same entry recomputed under any later device zone | Identical label — offset is an argument, not ambient state | N/A |
| Travel | Same absolute instant stored with +00:00 and with +14:00 | Each labelled in its own frame; possibly different labels; history never re-dated | N/A |
| DST spring-forward | Madrid 2026-03-29; entries at 01:59:59.999 +01:00 and at 03:00 +02:00 | Both share one label (2026-03-28) — no day destroyed | N/A |
| DST fall-back | Madrid 2026-10-25; both 02:30 local hours (+02:00 then +01:00) | Same label — no duplicated day | N/A |
| Week anchor | Sat 2026-08-29 and Mon 2026-08-24, same offset | Same Week (Monday label 2026-08-24) | N/A |
| Season edges | 2026-11-30 then 2026-12-01 (+00:00) | Autumn (2026) then winter (anchored Dec 2026); 2027-03-01 opens spring | N/A |
| Energy in-day | Observations `full` then `low` earlier today; older days ignored | `low` — last of the current domestic day wins, across mixed stored offsets | N/A |
| Energy boundary | Observations only from yesterday; now past 04:00 | `full` — never carried across a boundary | N/A |
| No observations | Empty input | `full` | N/A |

</frozen-after-approval>

## Code Map

- `packages/core/lib/day/` -- NEW module (`Calendar`, `Day`, `Week`, `Season`); sibling of `log/`, `pool/`, `ports/` — do NOT touch `lib/ports/` (`packages/core/test/ports_test.dart:30-43` pins it to exactly two files).
- `packages/core/lib/log/log_entry.dart:79,83`, `packages/core/lib/pool/pool_fact.dart:69,74`, `packages/core/lib/ports/store_port.dart:21-43` -- the stored-time contract this API mirrors: the same `instantUtcMicros` + `offsetSeconds` pair, taken as primitives (no import — the stored feed arrives with 2.5's writer).
- `packages/core/lib/ports/clock_port.dart:6-9` -- existing `ClockPort`; the shell reads the clock (`lib/crash.dart:37,42-43` is the legal pattern); the Calendar takes no clock.
- `packages/core/test/log_test.dart` -- `package:test` style to follow for the new suites.
- `_bmad-output/planning-artifacts/architecture/architecture-organizer-2026-08-26/ARCHITECTURE-SPINE.md:58-72` -- AD-4: day window, Monday week, meteorological season, stored-offset rule, native ban; `:229` time convention; `:242` enforcement = core tests + review.
- `Makefile:30-31,42-49,60-63` -- `test-core` / `check` / `gate`; no Makefile change expected.

## Tasks & Acceptance

**Execution:**
- [x] `packages/core/lib/day/calendar.dart` -- NEW: `Calendar` + `Day`/`Week`/`Season` value types; `dayOf(instantUtcMicros, offsetSeconds)`, `weekOf(day)`, `seasonOf(day)`; half-open periods with frame start/end instants; `Day.weekday` -- the one authority (AD-4)
- [x] `packages/core/lib/energy/energy.dart` -- NEW: `EnergyLevel` (`full`/`medium`/`low`) + `deriveEnergyForLivePool(observations, instantUtcMicros, offsetSeconds)` over `EnergyObservation` records -- the day-scoped rule with the 🟢 default
- [x] `packages/core/test/day_test.dart` -- NEW: pin every I/O-matrix row (boundary halves, stored-offset rule, travel, both DST transitions, Monday anchor, meteorological quarter edges)
- [x] `packages/core/test/energy_test.dart` -- NEW: last-of-day wins across mixed offsets; boundary resets to `full`; empty input; the function has no write path
- [x] `_bmad-output/implementation-artifacts/deferred-work.md` -- append the deferred item: `energy_set` vocabulary, level storage, port DTO growth and the check-in writer land in Story 2.5

**Acceptance Criteria:**
- Given any code that needs a day, week or season, then it calls the one `Calendar` in `packages/core/lib/day/` and no other code — Kotlin included — computes a date boundary
- Given a log entry written in one zone offset and read in another, then its period labels come from the stored offset and travel or clock correction never re-dates history
- Given a DST transition inside a period, then no day, week or season is created or destroyed by the transition
- Given energy derived at a day boundary, then it is the last observation of the current domestic day defaulting to 🟢, and no synthetic `energy_set` row exists at a boundary
- Given the completion gate, then `make check`'s seven checks and the core purity scan stay green with the new modules

### Review Findings

- [x] [Review][Patch] High: the mixed-offset energy test could not discriminate own-frame scoping from caller-frame scoping — a one-token mutant shipping the AD-4 violation passed the whole suite; discriminating tests added in both directions and mutant-verified [packages/core/test/energy_test.dart]
- [x] [Review][Patch] Medium: equal-instant tie semantics in `deriveEnergyForLivePool` were undocumented and untested; now documented (later-in-input wins exact-microsecond ties) and pinned [packages/core/lib/energy/energy.dart, packages/core/test/energy_test.dart]
- [x] [Review][Patch] Medium: `offsetSeconds` had no documented domain; library doc now states the accepted domain (|offset| ≤ 14 h, second-level, unvalidated — any int yields a consistent frame) with extreme-offset tests [packages/core/lib/day/calendar.dart, packages/core/test/day_test.dart]
- [x] [Review][Patch] Medium: no week test crossed the civil-year boundary (Monday anchoring in the previous year); added Fri 2027-01-01 → Mon 2026-12-28 and Sun 2028-01-02 → Mon 2027-12-27 [packages/core/test/day_test.dart]
- [x] [Review][Patch] Low: `Day.label` did not zero-pad the year despite its doc ("zero-padded"), breaking lexicographic ordering for years < 1000; padded to 4 digits and tested [packages/core/lib/day/calendar.dart]
- [x] [Review][Patch] Low: misleading doc claim "a second pocket the same evening does not re-widen" — under last-observation-wins a later `full` does re-widen; reworded to the true day-scoped statement [packages/core/lib/energy/energy.dart]
- [x] [Review][Patch] Low: cross-frame value equality pinned only for `Day`; `Week` and `Season` equality across frames now tested [packages/core/test/day_test.dart]
- [x] [Review][Patch] Low: no leap-year coverage; 2028-02-29 label and the winter-2027 → 2028-03-01 close now pinned [packages/core/test/day_test.dart]
- [x] [Review][Patch] Low: `_utc` helper duplicated verbatim across suites; extracted to `test/test_util.dart` (`utcMicros`) [packages/core/test/]
- [x] [Review][Patch] Low: `Week` lacked a `label` getter though identity is the Monday label; added [packages/core/lib/day/calendar.dart]
- [x] [Review][Patch] Low: Code Map called the stored-time files "consumed" with no call site yet; reworded to "mirrored — no import until 2.5" [this spec]
- [ ] [Review][Defer] Period arithmetic (adjacency, iteration, ordinals) grows on the Calendar with its first needing consumer — recorded in `deferred-work.md`
- [ ] [Review][Defer] `make test-core` is outside the gate trio, so a core-only regression can pass the gate — recorded in `deferred-work.md`
- [x] [Review][Reject] DateTime-range overflow guards (inputs impossible via shell writers; malformed-row tolerance is the already-deferred parse boundary's job); future-dated observations filtered (the frozen rule is literally "last of the day"; consequence bounded to the same day); run evidence embedded in the spec (the template records commands + expected, not transcripts)

## Spec Change Log

- 2026-08-29 — Human-approved frozen-block renegotiation (implementation checkpoint): the spring-forward matrix row's expected label `2026-03-29` contradicted the boundary-halves row; corrected to "Both share one label (2026-03-28) — no day destroyed". Avoids the known-bad state of a matrix that pins both a pre-04:00 previous-day rule and a pre-04:00 same-day label. KEEP: the shared-label invariant (the epic AC's actual demand) and the code's boundary-halves semantics, both already test-pinned.

## Design Notes

- **The fixed-offset frame IS the DST mechanism.** Each entry's periods are computed in its own stored offset, so labels cannot duplicate or vanish at a transition; 23 h / 25 h wall-clock days never enter the math. Implement with `DateTime.utc` arithmetic on the given micros (deterministic, `dart:core`): integers in, labels and boundary micros out.
- Day equality = civil-date label in the frame; the frame's start/end instants are derived data. Weeks and seasons inherit the containing day's frame.
- `deriveEnergyForLivePool` takes `EnergyObservation` records (level, `instantUtcMicros`, `offsetSeconds`) — not log entries: the `energy_set` kind, its storage and its writer are Story 2.5's; when they land, 2.5 maps stored entries to observations. Story 1.6's weave consumes this function (EPICS:647).
- Later consumers — 1.6 weave, 1.7 zone rotation, 2.2 sessions, 2.6 SM-2, 5.7 seasons, 8.2 invitations — must call this Calendar rather than reimplement any boundary math (SPINE:72 extends to Kotlin: no date arithmetic of any kind).

## Verification

**Commands:**
- `devbox run -- make test-core` -- expected: green, including the new `day_test.dart` and `energy_test.dart`
- `devbox run -- make check` -- expected: the seven checks green, set unchanged
- `devbox run -- make gate` -- expected: `flutter test`, `dart format --set-exit-if-changed .`, `flutter analyze` all green

## Suggested Review Order

**The one authority (AD-4) — start here, the story's whole point**

- Stateless const converter: integers in, labels and boundary micros out; no clock, no zone
  [`calendar.dart:187`](../../packages/core/lib/day/calendar.dart#L187)

- `dayOf` — the wall clock of the stored-offset frame, split at 04:00 into half-open days
  [`calendar.dart:198`](../../packages/core/lib/day/calendar.dart#L198)

- `Day` — identity is the civil-date label; start/end instants are derived data
  [`calendar.dart:45`](../../packages/core/lib/day/calendar.dart#L45)

- `weekOf` — Monday anchoring by pure civil arithmetic; Sunday closes the week
  [`calendar.dart:216`](../../packages/core/lib/day/calendar.dart#L216)

- `seasonOf` — meteorological quarters on domestic-day boundaries; winter anchored on its December
  [`calendar.dart:232`](../../packages/core/lib/day/calendar.dart#L232)

**The DST mechanism — the fixed-offset frame itself**

- Spring-forward: the whole Madrid jump night is one day, in two stored frames
  [`day_test.dart:133`](../../packages/core/test/day_test.dart#L133)

- Fall-back: both 02:30 wall clocks are one day — no duplicated label
  [`day_test.dart:183`](../../packages/core/test/day_test.dart#L183)

**The day-scoped energy rule**

- `deriveEnergyForLivePool` — last observation of the current day, each scoped by its own stored offset, else 🟢
  [`energy.dart:55`](../../packages/core/lib/energy/energy.dart#L55)

- `EnergyLevel` — semantic names only; the Spanish copy is 2.5's ARB concern
  [`energy.dart:19`](../../packages/core/lib/energy/energy.dart#L19)

- The mutant-killing mixed-frame tests the review round demanded
  [`energy_test.dart:11`](../../packages/core/test/energy_test.dart#L11)

**Peripherals**

- Half-open boundary halves pinned to the microsecond
  [`day_test.dart:27`](../../packages/core/test/day_test.dart#L27)

- Leap February, year-crossing weeks, cross-frame value semantics, extreme offsets
  [`day_test.dart:352`](../../packages/core/test/day_test.dart#L352)

- Shared `utcMicros` helper — one definition, two suites
  [`test_util.dart:1`](../../packages/core/test/test_util.dart#L1)

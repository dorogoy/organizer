---
title: 'The weekly self-report substrate (2-6, part 1)'
type: 'feature'
created: '2026-08-31'
status: 'done'
review_loop_iteration: 0
baseline_commit: '0afd789a7cbde1851356918edd87dd2f3b9b4f44'
context: ['SM-2', 'AD-21', 'AD-23', 'NFR17']
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** SM-2's weekly answer cannot be recorded: the log's ten kinds have no `report_answered`, the store has no column for a 1–5 value nor for the week an answer reports on, and no sanctioned minter exists — so the weekly self-report surface and the deterministic slot handoff (this story's parts 2–3, deferred) have no substrate.

**Approach:** Land the eleventh kind `report_answered` additively — `ReportAnsweredEntry{value, week}` over two nullable schema-v5 columns (ALTER TABLE only), the single minter `reportAnswered({value, week})` guarding 1–5 with refusal-as-silence, and the census/freezes/mint-site proofs the sealed substrate requires. Nothing consumes the kind yet; `strip.dart`'s `weeklySelfReport` stub stays `false`.

## Boundaries & Constraints

**Always:**
- `value` is the wire int 1–5, validated at the read boundary — outside the range or null the row is excluded quietly as its flaw. `week` is the answered week's `Week.weekOrdinal` (calendar.dart:135-141, the only week identity — no second counter), carried explicitly so an answer may fall outside the week it reports on (AD-21, SM-2: without the target week the week-4-versus-week-1 trend cannot be built).
- Additive (AD-23): schema v5 by ALTER TABLE only (`report_value`, `report_week INTEGER NULL`); three flaws on the energy pattern — `reportValueAbsent`, `reportWeekAbsent`, `reportOnNonReportKind` — the last mirrored as a guard in every other kind's convert branch; unknown kinds still tolerated; `(instant, rowid)` ordering unchanged.
- The minter is the kind's single sanctioned site (settings/energy shape): pure, no log read, exactly one `LogEntryContent` row carrying both ints, refusal `const []` outside 1–5 — never an error surface.
- Proofs land with the kind: `ReportAnsweredEntry` freeze (value, week, override `kind` last); `LogEntryRecord` 11→13; `LogEntryContent` 8→10; census frozen set grows the entry; a `report_answered` mint-site family on the `energy_set` template (allowed files `log/log_entry.dart` + `commands/report_commands.dart`); `log_test` kind pin 10→11 plus a payload-path group.
- The two ALTER constants join `tool/check_no_literal_strings.dart`'s `namedConstantAllowance`; the `make codegen` churn (`substrate.g.dart`) is committed and `codegen-check` runs clean.

**Ask First:** The week-as-`weekOrdinal` and value-as-own-wire-int encodings have no verbatim upstream pin (AD-21 names the kind and the week it answers; the representation is ours) — they land as code-doc plus this record; a spine edit is the human's call.

**Never:** No strip change (part 2 derives eligibility), no shell surface, controller, view or ARB change (part 3), no reader/trend derivation — SM-2 reads the week-carrying rows at analysis time, unanswered weeks being absent rows; no notification path (FR-24); no golden tests.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Behavior | Error Handling |
|----------|---------------|-------------------|-----------------|
| Valid round-trip | `{report_answered, report_value: 3, report_week: W}` | `ReportAnsweredEntry{value: 3, week: W}` survives the boundary in reading order | N/A |
| Value out of range / week null | `report_value` 0 or 6; `report_week` null | excluded as `reportValueAbsent` / `reportWeekAbsent` | quiet |
| Payload on another kind | `report_value` on an `energy_set` row | excluded as `reportOnNonReportKind`; every branch gains the mirror | quiet |
| Minter refusal / happy path | value 0 or 6; value 1–5 | `const []`, no throw; exactly one row carrying both ints | silence |
| v4 → v5 upgrade | v4 substrate holding rows | in-place ALTERs, `schemaVersion` 5, prior rows preserved with null columns | N/A |
| Unknown kind | wire name `'foo'` | carried verbatim as `UnknownEntry` — tolerance unchanged | quiet |

</frozen-after-approval>

## Code Map

- `packages/core/lib/log/log_entry.dart:29-78,254-270,289-345,379-602` -- eleventh kind + `ReportAnsweredEntry` in `EnergySetEntry`'s fixed-kind shape (:254-270); three flaws; convert branch on the energy pattern (:546-572) with the range check + mirrored guards (:421,450,480,505,533,587)
- `packages/core/lib/ports/store_port.dart:42-54` + `lib/store/substrate.dart:39-58,72-88` + `lib/store/substrate.drift:40-52` + `lib/store/drift_store.dart:41-59,85-111` -- record gains `int? reportValue, int? reportWeek`; two named ALTER constants; `schemaVersion => 5`; `if (from < 5)`; drift columns; `Value(...)` insert; passthrough decode; v5 doc paragraph
- `tool/check_no_literal_strings.dart` (namedConstantAllowance) -- the two ALTER constants join the substrate set
- `packages/core/lib/commands/report_commands.dart` (new) -- the minter on `energy_commands.dart:28-41`'s shape with `settings_commands.dart:29-50`'s range guard; `session_commands.dart:68-121,436-445` -- content typedef + every literal grows the nulls
- `packages/core/lib/day/calendar.dart:111-151,135-141` -- READ ONLY (the stored week); `energy.dart:33-44` -- wire-int precedent
- `packages/core/test/log_test.dart:7-28,32-58,602-740` -- `_record` grows two params; kind pin 11; payload group
- `test/store/substrate_test.dart:22-38,524-543,641-1080` -- column audit → 13; version → 5; v4→v5 upgrade group on the v3→v4 template
- `packages/core/test/no_lateness_proof_test.dart:693-703,821-863,910-1064,1282-1366` -- entry freeze (kind last); record 13 / content 10; census counts; mint-site family clone

## Tasks & Acceptance

**Execution:**
- [x] `packages/core/lib/log/log_entry.dart` + `packages/core/lib/ports/store_port.dart` -- eleventh kind, entry, three flaws, boundary branch + mirrored guards
- [x] `lib/store/substrate.dart` + `lib/store/substrate.drift` + `lib/store/drift_store.dart` + `tool/check_no_literal_strings.dart` -- v5 columns, migration, insert/decode, allowlist -- then `make codegen` with churn committed
- [x] `packages/core/lib/commands/report_commands.dart` (new) + `session_commands.dart` -- the single minter; typedef and literals grow
- [x] Core tests (`log_test`, `substrate_test`, `no_lateness_proof_test`) -- every matrix row, freezes, census, mint-site family, kind pin 11

**Acceptance Criteria:**
- Given a stored answer row with value in 1–5 and a week ordinal, when the log is read, then `ReportAnsweredEntry` survives the boundary carrying both ints
- Given a row with value outside 1–5, week null, or the columns on another kind, when the boundary converts, then it is excluded quietly under its named flaw
- Given `reportAnswered` outside 1–5, then nothing is minted — refusal is silence; at 1–5 exactly one row
- Given a v4 substrate holding rows, when it opens under v5, then ALTERs run in place, the version reads 5, every prior row survives
- Given the completion gate, then `make codegen-check`, `make check`, `make test-core` and `make gate` are green

## Spec Change Log

## Design Notes

- **Why ordinal, not a Week object.** `weekOrdinal` (whole days from epoch Monday 2000-01-03 over 7, consecutive weeks differ by 1) is already consumed by the zone ring; one int is the week's only identity and part 2's eligibility match is a single comparison (calendar.dart:27-30 forbids a second counter).
- **Why the value is its own wire int.** Energy needed an enum because levels are semantic; five numerals are their own encoding — a range check at the boundary (the `settingValue` guard's terms) and the same check at the minter are the whole ceremony.
- **Why nothing consumes the kind yet.** Substrate-first is the repo's idiom (1-3's log, 1-5's catalogue): parts 2–3 review against a sealed base and no shipped behavior changes here.

## Verification

**Commands:**
- `devbox run -- make codegen` -- expected: `substrate.g.dart` regenerated; then `make codegen-check` clean with churn committed
- `devbox run -- make check` -- expected: purity, string audit (the two ALTER allowlist entries), freezes green with the eleventh kind registered
- `devbox run -- make test-core` -- expected: log/substrate matrices green, incl. the v4→v5 upgrade group
- `devbox run -- make gate` -- expected: test, format, analyze all green

## Suggested Review Order

**The kind and its entry — the design's heart**

- The eleventh kind, one registry entry — the whole story hangs off this name
  [`log_entry.dart:51`](../../packages/core/lib/log/log_entry.dart#L51)

- The 1–5 scale pinned as named bounds beside the entry, never magic ints
  [`log_entry.dart:284`](../../packages/core/lib/log/log_entry.dart#L284)

- The entry itself: fixed-kind shape, value + the answered week, `kind` last
  [`log_entry.dart:304`](../../packages/core/lib/log/log_entry.dart#L304)

**The read boundary — tolerance by exclusion**

- Out-of-scale or absent value excludes the row quietly — the energy pattern
  [`log_entry.dart:675`](../../packages/core/lib/log/log_entry.dart#L675)

- The week bound as a local, bang-free, check and use adjacent
  [`log_entry.dart:678`](../../packages/core/lib/log/log_entry.dart#L678)

- The two payload flaws and the foreign-payload mirror, named beside their siblings
  [`log_entry.dart:410`](../../packages/core/lib/log/log_entry.dart#L410)

- One mirror example — every other kind's branch carries the same guard
  [`log_entry.dart:505`](../../packages/core/lib/log/log_entry.dart#L505)

**The single sanctioned minter**

- Value guarded 1–5, refusal is silence, no log read — the settings shape
  [`report_commands.dart:36`](../../packages/core/lib/commands/report_commands.dart#L36)

**Schema v5 — additive, ALTER-only**

- The two named ALTER constants on the v2/v3/v4 pattern
  [`substrate.dart:55`](../../lib/store/substrate.dart#L55)

- The version bump and the `if (from < 5)` migration block
  [`substrate.dart:102`](../../lib/store/substrate.dart#L102)

- Both nullable columns in the drift schema
  [`substrate.drift:58`](../../lib/store/substrate.drift#L58)

- `Value(...)` insert wrap and passthrough decode
  [`drift_store.dart:57`](../../lib/store/drift_store.dart#L57)

**The inert arms — nothing consumes the kind yet**

- The weave walk's no-op case, compile-forced and now test-pinned
  [`session.dart:286`](../../packages/core/lib/weave/session.dart#L286)

- The checkpoint derivation's no-op — part 2 keeps it that way until eligibility lands
  [`checkpoint.dart:141`](../../packages/core/lib/derive/checkpoint.dart#L141)

- The strip walk's no-op — the stub story 2-6 part 2 replaces
  [`strip.dart:185`](../../packages/core/lib/derive/strip.dart#L185)

**The proofs and tests**

- The mint-site family: one file mints, the wire literal lives in exactly two places
  [`no_lateness_proof_test.dart:1390`](../../packages/core/test/no_lateness_proof_test.dart#L1390)

- The payload-path group — round-trip, scale, absent week, all seven mirror sites
  [`log_test.dart:730`](../../packages/core/test/log_test.dart#L730)

- The v4→v5 upgrade group — in-place ALTERs, prior rows preserved
  [`substrate_test.dart:1218`](../../test/store/substrate_test.dart#L1218)

- The composed out-of-scale path: stored 9 → boundary excludes it on the production path
  [`substrate_test.dart:665`](../../test/store/substrate_test.dart#L665)

- The three inertness pins — weave, strip, checkpoint identical with answer rows
  [`weave_test.dart:2176`](../../packages/core/test/weave_test.dart#L2176)

- Week 0 — the epoch week — mints and round-trips as a valid entry
  [`report_commands_test.dart:60`](../../packages/core/test/report_commands_test.dart#L60)

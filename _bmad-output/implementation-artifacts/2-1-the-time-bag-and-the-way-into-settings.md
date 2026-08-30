---
title: 'The Time Bag, and the way into Settings'
type: 'feature'
created: '2026-08-30'
status: 'done'
review_loop_iteration: 0
baseline_commit: 'd77b8496dafd65242f1bbede5596d459aba59f23'
context: ['FR-7', 'FR-12', 'NFR3', 'AD-1', 'AD-2', 'AD-15', 'AD-20', 'AD-21', 'AD-23', 'AD-26', 'UX-DR25', 'UX-DR33', 'UX-DR45']
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** The app composes every day against a hardcoded bag (`defaultBagMinutes = 15`, weave.dart:37) — it asks for an amount it assumed, not one the user chose. The Dispenser also has no way out: no affordance, no Settings, no route a validator could ever reach (NFR3, AD-26).

**Approach:** Add the quiet `Nuevo proyecto` text affordance (bottom-centred, ink-secondary, `action-secondary`) to the Dispenser, opening the Epic-2 intermediate surface that carries the `Ajustes` way-out alone (typed genesis is Epic 5). Build the Settings shell as a flat platform list whose first group is **Tu día**, holding the Time Bag as stepped options (5–30, step 5, default 15). A change appends a `setting_changed` log entry (additive kind, two nullable columns, schema v2); the bag is derived from the log on every read and threaded through facade and commands, so composition honors it: below 10 no Focus Chunk composes — silently; a raise from <10 to ≥10 composes one iff the slot allows.

## Boundaries & Constraints

**Always:**
- `setting_changed` lands additively (AD-23): new `LogKind` constant + `SettingEntry` subtype; two nullable columns `setting_key`/`setting_value` on `log_entries` via `schemaVersion` 2 with ALTER-TABLE-only `onUpgrade`; refusal triggers, insert-only discipline and no-FK/no-CHECK stay untouched.
- The bag derivation is a pure function over `logEntriesOf` output (latest valid `time_bag` entry in store read order, default 15), mirroring `energy.dart`'s shape; rebuilt on every read, never cached across launches, never written (AD-1). No persistence imports outside `lib/store/` (store seal).
- The shell derives the bag via the core derivation and threads it through every command/facade call; no shell-reachable composition path relies on `defaultBagMinutes` once a setting exists. The Time Bag is a ceiling, never a wallet: nothing subtracts from it, no accumulator exists anywhere.
- Affordance grammar (UX-DR25): plain centred text, ink-secondary, `action-secondary`/bodyMedium, 48dp opaque target — reuses `SecondaryTextAction`; never animated, emphasised, badged, no pastel mass, no glyph. Same grammar for the `Ajustes` way-out.
- Settings (UX-DR33): flat platform list, quiet group headers, only the **Tu día** group; light/dark follows the system with no row; the glyph set stays exactly ten (no settings glyph — pinned by `glyph_set_test.dart:125`).
- Every new string lands in `app_es.arb` with a description (AD-15); regenerated accessors committed; no literal strings, no accessor concatenation. Silence everywhere: a below-10 day, a refused value and a recorded change carry no message, state or error surface.
- Pins are renegotiated deliberately in-pass, never bent: the "exactly seven kinds" pin becomes eight; the 1-11 freeze lists extend to cover `SettingEntry`, the grown `LogEntryContent`/`LogEntryRecord` and the two new columns; the mint census pins `setting_changed`'s single sanctioned minter.
- Completed work is never invalidated: answers and slot facts are log-derived; a bag change appends one row and re-derives forward only (AD-20).
- Core purity (no Flutter imports, no clock/Random/io) and the text-scaling floor (no maxLines/ellipsis/fixed heights) hold on every new file.

**Ask First:** Any non-additive schema change beyond the two nullable columns; any perceived need for a settings glyph, a fifth-group placeholder, or urgency-toned copy.

**Never:** No typed genesis surface or placeholder (Epic 5) — the `Nuevo proyecto` surface carries the way-out alone; no other Settings groups; no light/dark row; no pocket/pause/checkpoint/energy/report surfaces (Stories 2.2–2.6); no free-form minute entry; no wallet, budget-exhaustion, debt or mention of the below-10 state in any identifier or string; no UPDATE/DELETE path or side file.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Behavior | Error Handling |
|----------|---------------|-------------------|-----------------|
| First launch | log with no `setting_changed` | derived bag 15; Focus Chunk leads the day | N/A |
| Set the bag | option 10/15/20/25/30 tapped | one `setting_changed` {time_bag, N} appended; next derivation returns N; no confirmation UI | N/A |
| Out-of-range value | command asked for <5 or >30 | command returns no content; nothing appended | surface offers only valid options, so unreachable in UI |
| Imported/invalid entry | `time_bag` value outside 5–30 or unknown key in log | entry stays in the log; derivation treats it as absent (previous value or default) | no crash, no repair write |
| Same-instant pair | two `setting_changed` rows at one instant | store read order (instant, rowid) decides; the later row wins | deterministic replay |
| Bag below 10 | composition with derived bag 5 | no Focus Chunk; upkeep + habits compose; nothing names the absence | silent — no state, no string |
| Mid-day change (any direction) | setting row appended after answers | prior `card_done`/answers unchanged; next deal re-resolves identity | N/A |
| Raise <10 → ≥10 | slot open, no chunk dealt that day | a Focus Chunk composes on the next deal | closed slot stays closed |
| Chunk answered Hecho | later same-day session, any bag | upkeep + habits only — chaining cannot multiply advance | silent |
| v1 install upgrade | pre-v2 database opened | ALTER TABLE adds the columns; old rows read unchanged (null setting fields) | migration is tolerant, no rebuild |

</frozen-after-approval>

## Code Map

- `packages/core/lib/weave/weave.dart:37-54,312-320` -- read-only: `defaultBagMinutes`, `focusChunkLeastBagMinutes = 10`, `_chunkComposes` already encodes the below-10 gate (pinned by `weave_test.dart:549-571`); this story feeds it the derived bag, it does not add a gate
- `packages/core/lib/weave/weave.dart:337-464` -- `_resolveDay`/`composeDay`/`nextDeal`: slot identity re-resolves per call; chunk resolved while gate holds and `dealtUnanswered == null`; `focusSlotClosedDays` (set only by a focus `card_done`, `weave/session.dart:154-158`) is the closed-slot fact
- `packages/core/lib/log/log_entry.dart:22-65,95-160,186-202,213-290` -- extend: `settingChanged` kind constant, `knownByName`, `SettingEntry {kind, key, value}` subtype, classifiers, `convertLogEntryRecord` payload checks (setting kind requires key + int value; other kinds carry null setting fields)
- `packages/core/lib/ports/store_port.dart:36-44` -- extend `LogEntryRecord` with nullable `settingKey`/`settingValue` (field-identical to domain, AD-6)
- `lib/store/substrate.drift` + `lib/store/substrate.dart:28-38` -- extend: two nullable columns; `schemaVersion => 2`; `onUpgrade` v1→v2 ALTER TABLE only; regenerate `substrate.g.dart` (build_runner)
- `packages/core/lib/settings/settings.dart` -- NEW: bag-min constants (5/30/default 15 — single source; weave keeps its threshold constant) + `deriveTimeBagMinutes(entries)`; template is `packages/core/lib/energy/energy.dart:55-87` (own pass over entries, last valid observation, default)
- `packages/core/lib/commands/settings_commands.dart` -- NEW: `settingChanged(key, minutes)` following `session_commands.dart:27-71` (pure, returns `LogEntryContent` list; out-of-range returns empty)
- `packages/core/lib/facade/read_facade.dart:22-47` -- `nextCard` derives the bag from its own log read instead of the parameter default; command threading: `session_commands.dart` callers pass the derived value (shell derives once per operation)
- `lib/settings/settings_controller.dart` -- NEW: read (derive) + serialized write (`_enqueueWrite` pattern, `dispenser_controller.dart:75,176-182`); same store instance as the dispenser (`app_test.dart:134-156` single-openStore pin)
- `lib/ui/dispenser/dispenser_screen.dart:283-374` -- the `_frame` column grows a bottom-centred footer: `SecondaryTextAction` (`task_card.dart:69-99`) with `newProjectLink`; `Navigator.push` (first navigation in the app — no route table exists, `main.dart:67-72`)
- `lib/ui/settings/nuevo_proyecto_screen.dart` -- NEW: intermediate surface — standard frame, no heading, no chrome, single quiet `Ajustes` way-out (bottom-centred), system back pops
- `lib/ui/settings/settings_screen.dart` -- NEW: flat platform list (ListView in the frame idiom), **Tu día** group header (`support` role), Bolsa de tiempo row, stepped options 5/10/15/20/25/30 reusing `durationMinutes` + `Radii.radiusFull` pill idiom (`duration_chip.dart:25-51`); selection writes via controller; selected option reads as current value
- `lib/l10n/app_es.arb` -- +3 keys with descriptions: way-out `Ajustes`, group `Tu día`, row `Bolsa de tiempo`; regenerate (`make codegen`)
- `lib/main.dart:13-40` -- construct `SettingsController` with the same store; pass controllers into the screens; keep the constructor test seam
- Test doubles to reuse: `_RecordingStore` (`test/ui/dispenser/dispenser_screen_test.dart:45-59`), `_EmptyCatalogueStore`/`_FakeBundle` + fixed clock (`test/ui/app_test.dart:26-74`), `utcMicros` + weave entry builders (`packages/core/test/weave_test.dart:49-125`), `launchAndCommit` harness, whole-tree census helper (`dispenser_screen_test.dart:389`)
- Pins renegotiated in-pass: `packages/core/test/log_test.dart:23-42` (seven→eight kinds), `packages/core/test/no_lateness_proof_test.dart` (freeze lists: `SettingEntry`, `LogEntryContent`, `LogEntryRecord`; exhaustiveness census; kind-name enumeration — `setting_changed` carries no banned segment), `test/store/substrate_test.dart:476-508` (exact column set), `test/no_lateness_proof_test.dart` (shell mint census: `setting_changed` minted only in `settings_commands.dart`, `LogEntryRecord` construction only in sanctioned append sites)

## Tasks & Acceptance

**Execution:**
- [x] `packages/core/lib/log/log_entry.dart` + `packages/core/lib/ports/store_port.dart` -- add kind, subtype, record fields, conversion/validation -- additive payload path for `setting_changed`
- [x] `lib/store/substrate.drift` + `lib/store/substrate.dart` + regenerated `substrate.g.dart` -- nullable columns, schemaVersion 2, ALTER-only upgrade -- insert-only substrate survives v1 installs
- [x] `packages/core/lib/settings/settings.dart` -- NEW derivation + range constants -- the derived cache over `setting_changed` (AD-1)
- [x] `packages/core/lib/commands/settings_commands.dart` -- NEW pure command with range refusal -- the single sanctioned `setting_changed` minter
- [x] `packages/core/lib/facade/read_facade.dart` + `packages/core/lib/commands/session_commands.dart` -- derive the bag inside the facade; shell threads the derived value into every command call -- no shell-reachable path relies on the default
- [x] `lib/settings/settings_controller.dart` -- NEW controller (same store, serialized write) -- read/write seam for the surfaces
- [x] `lib/ui/dispenser/dispenser_screen.dart` -- bottom-centred `Nuevo proyecto` footer + push navigation -- UX-DR25 affordance, first navigation
- [x] `lib/ui/settings/nuevo_proyecto_screen.dart` + `lib/ui/settings/settings_screen.dart` -- NEW surfaces (way-out carrier; platform list with Tu día/Time Bag) -- UX-DR25/UX-DR33
- [x] `lib/l10n/app_es.arb` + regenerated accessors -- 3 keys with descriptions -- AD-15
- [x] `lib/main.dart` -- wire `SettingsController` and pass it through -- single-store pin holds
- [x] `packages/core/test/settings_test.dart` -- NEW: derivation matrix (default, latest-wins, same-instant order, invalid-entry-as-absent, unknown key) + command acceptance/refusal
- [x] `packages/core/test/log_test.dart` + `packages/core/test/no_lateness_proof_test.dart` + `test/store/substrate_test.dart` + `test/no_lateness_proof_test.dart` -- renegotiate the pins named in the Code Map; migration test v1→v2 on a seeded old database
- [x] `packages/core/test/weave_test.dart` + `packages/core/test/facade_test.dart` -- integration pins: seeded `setting_changed` rows drive composition through the facade (below-10 silent, raise composes iff slot open and none dealt, Hecho-then-session upkeep-only, mid-day change keeps prior answers)
- [x] `test/ui/dispenser/dispenser_screen_test.dart` + NEW `test/ui/settings/` -- affordance presence/quietness (ink-secondary text, 48dp, no glyph) and furniture-census compatibility; nav chain Dispenser → way-out → Settings; Tu día group renders; option tap appends exactly one `setting_changed` row; launch with seeded bag 5 deals a non-focus card while default 15 leads with focus

### Review Findings

- [x] [Review][Patch] Quiet-failure reads — the Settings screen's initial and post-write `_readBag` calls now catch and leave state unchanged (unhandled async exception on a failing store read) [lib/ui/settings/settings_screen.dart]
- [x] [Review][Patch] Off-ladder derived values render — an in-range value outside the ladder (imported 17) shows as its own selected chip ahead of the ladder; selection always reflects the derivation [lib/ui/settings/settings_screen.dart]
- [x] [Review][Patch] `Semantics(selected:)` on `_TimeBagOption` — selection was fill-colour-only, invisible to screen readers; state flag added inside the tap target, visuals unchanged [lib/ui/settings/settings_screen.dart]
- [x] [Review][Patch] Double-tap push guards — both navigation sites check `ModalRoute.isCurrent`; same-frame double taps stack one route each [lib/ui/dispenser/dispenser_screen.dart, lib/ui/settings/nuevo_proyecto_screen.dart]
- [x] [Review][Patch] Redundant append guarded — tapping the current derived value writes nothing [lib/ui/settings/settings_screen.dart]
- [x] [Review][Patch] Empty-string alignment — `carriesSetting` treats an empty setting key/value as absent (the itemId rule), for carrying and the setting-kind requirement; conversion tests extended [packages/core/lib/log/log_entry.dart]
- [x] [Review][Patch] Answer-path bag pins — the one place the bag meets the bundled next deal was unobserved (a revert-to-default mutation survived every suite): skip/done-on-focus and done-on-upkeep core tests plus a controller-level seeded-bag-5 `complete()` test now kill it [packages/core/test/session_commands_test.dart, test/dispenser/dispenser_controller_test.dart]
- [x] [Review][Patch] SettingsController failure recovery pinned — failing-first-append store: quiet failure, recovered chain, second write lands, read completes; the `.catchError` is load-bearing; rapid-tap ordering pinned [test/ui/settings/settings_screen_test.dart]
- [x] [Review][Patch] One-shell-edit pin extended to `SettingsController(store: store`; `OrganizerApp(settings: …)` constructed in a test [test/ui/app_test.dart]
- [x] [Review][Patch] Null-controller chain pinned — footer → carrier(null) → `SettingsScreen(controller: null)` renders, writes go nowhere [test/ui/settings/settings_screen_test.dart]
- [x] [Review][Patch] `_answered` derives the bag over `answeredLog` (the log `nextDeal` resolves on) — future source divergence cannot hide [packages/core/lib/commands/session_commands.dart]
- [x] [Review][Patch] Redundant nested `SafeArea` removed from the carrier screen; `complete()` doc updated; `selectedMinutes` helper reads `timeBagOptions` from core [lib/ui/settings/nuevo_proyecto_screen.dart, lib/dispenser/dispenser_controller.dart, test/ui/settings/settings_screen_test.dart]
- [x] [Review][Reject] Frozen I/O matrix row lists "option 10/15/20/25/30 tapped" without 5 — erratum only: the frozen Approach itself says "stepped options (5–30, step 5)" and the built ladder is 5/10/15/20/25/30; reading is unique, no code action (human may renegotiate the frozen text if desired)

**Acceptance Criteria:**
- Given the Dispenser, when it renders, then `Nuevo proyecto` sits bottom-centred as quiet ink-secondary text — never animated, emphasised, badged, nor carrying pastel mass (UX-DR25)
- Given the affordance, when opened, then Settings is reachable from inside it as a quiet text way-out, and is the only route into the validator surface from any surface within three taps of the Dispenser (NFR3, AD-26)
- Given Settings, when rendered, then it is a flat platform list whose first group is **Tu día**, holding the Time Bag (UX-DR33)
- Given the Time Bag, when set, then it accepts 5–30 (stepped options), defaults to 15, persists until changed; a mid-day change never invalidates completed work (FR-7)
- Given a Time Bag change, when recorded, then one `setting_changed` entry is appended and the settings record is a derived cache rebuilt at start — "what the bag was on day 5" is answerable from the log (AD-1)
- Given a bag below 10, when the day composes, then no Focus Chunk composes, silently — no debt, no mention, no budget-exhausted state anywhere (FR-7, FR-12)
- Given the bag, when what it pays for is examined, then it covers advance only; upkeep and habits compose alongside it charged nowhere (FR-7, FR-12)
- Given the day's Focus Chunk answered Hecho, when a later session starts that day, then it composes upkeep and habits only — chaining cannot multiply advance (FR-7)
- Given a mid-day change, when the slot is re-evaluated, then identity re-resolves and a closed slot never re-opens; a raise from <10 to ≥10 composes a Focus Chunk iff none was dealt that day and the slot is open (AD-20)
- Given the completion gate, then `make check` and `make gate` are green, core suites via `make test-core`

## Spec Change Log

## Design Notes

- **"Iff none was dealt" reads through standing slot mechanics, not a new gate.** The raise's only effect is opening the below-10 gate; occupancy then follows the existing facts — a focus `card_done` closes (`focusSlotClosedDays`), a skip leaves the slot open with re-ranking (1.10/1.11 pins). A literal "no chunk dealt today" gate would kill the pinned same-day repetition after a skip and is rejected. The canonical scenario the AC names — bag below 10 from the start, nothing dealt, raise — composes a chunk iff the slot is open.
- **Derived-cache shape mirrors energy.** One pure pass, last valid observation wins, constant default — the established template (`energy.dart`, `curation.dart`) rather than extending `walkLog`'s facts, because settings are read by the shell, not by the weave's internal policy.
- **Stepped options (5/10/15/20/25/30), not a slider or free entry.** No free-form minute entry exists anywhere in the product (PRD §7); six quiet pills reuse the size-option/duration-chip idiom and `durationMinutes`, stay tappable at 200% scale, and keep the choice calm. FR-7 fixes the range, not the granularity. If per-minute granularity is wanted, swap the option list — the log payload is unaffected.
- **The `Nuevo proyecto` surface is honestly empty in 2.1.** One quiet way-out, no placeholder for Epic 5's genesis, no heading chrome — the intermediate state epics.md:889 sanctions. Back is the system gesture plus pop.
- **Schema v2 is two ALTERs.** `setting_key` TEXT NULL, `setting_value` INT NULL — no CHECK (import tolerance), no FK, refusal triggers untouched; v1 rows and non-setting v2 rows read with null fields and convert as their own kinds.
- **Range constants live in core/settings, not the weave.** The weave keeps `focusChunkLeastBagMinutes` (its policy threshold); 5/30/default belong to the setting. `defaultBagMinutes` in the weave becomes a delegation or moves — either way one source of truth for 15.

## Verification

**Commands:**
- `devbox run -- make codegen` -- expected: drift + l10n regeneration clean, `make codegen-check` green
- `devbox run -- make check` -- expected: all tool checks green (store seal, purity, forbidden vocabulary, string-table audit with the 3 new keys, text scaling, no-literal-strings)
- `devbox run -- make test-core` -- expected: core suites green including the renegotiated pins
- `devbox run -- make gate` -- expected: test, format, analyze all green

**Manual checks (if no CLI):**
- On a device/emulator: v1 install upgraded in place opens with history intact; setting the bag to 5 and returning to the Dispenser deals a non-focus card with no message anywhere; the affordance stays quiet in both themes.

## Suggested Review Order

**The substrate seam — an additive eighth kind**

- The kind constant and its entry subtype — the whole payload path starts here
  [`log_entry.dart:41`](../../packages/core/lib/log/log_entry.dart#L41)

- `SettingEntry {key, value}` — the only new shape; conversion rules below it
  [`log_entry.dart:159`](../../packages/core/lib/log/log_entry.dart#L159)

- Schema 2 and the ALTER-only upgrade — insert-only survives v1 installs
  [`substrate.dart:40`](../../lib/store/substrate.dart#L40)

**The derivation — AD-1 made real**

- The derived cache, energy-shaped: last valid `time_bag`, default 15
  [`settings.dart:56`](../../packages/core/lib/settings/settings.dart#L56)

- The single sanctioned minter — out-of-range and unknown keys return nothing
  [`settings_commands.dart:29`](../../packages/core/lib/commands/settings_commands.dart#L29)

- The facade derives the bag from its own log read — the shell never supplies it
  [`read_facade.dart:49`](../../packages/core/lib/facade/read_facade.dart#L49)

- The answer path threads the same derivation over `answeredLog` — the bundled next deal honors the bag
  [`session_commands.dart:196`](../../packages/core/lib/commands/session_commands.dart#L196)

- Serialized writes, failures cleared from the chain — same-store seam
  [`settings_controller.dart:57`](../../lib/settings/settings_controller.dart#L57)

**The surfaces — quiet in, quiet out**

- The Dispenser footer: `Nuevo proyecto` in the UX-DR25 grammar, first navigation, double-tap guarded
  [`dispenser_screen.dart:347`](../../lib/ui/dispenser/dispenser_screen.dart#L347)

- The carrier: honestly empty, one `Ajustes` way-out (genesis is Epic 5)
  [`nuevo_proyecto_screen.dart:40`](../../lib/ui/settings/nuevo_proyecto_screen.dart#L40)

- The platform list: **Tu día**, the ladder of six pills, off-ladder values rendered selected
  [`settings_screen.dart:89`](../../lib/ui/settings/settings_screen.dart#L89)

- The option widget — `Semantics(selected:)`, fill-colour grammar unchanged
  [`settings_screen.dart:150`](../../lib/ui/settings/settings_screen.dart#L150)

**The pins — renegotiated, not bent; and the proofs**

- Eight kinds, `SettingEntry` frozen, census and mint distribution extended
  [`no_lateness_proof_test.dart:646`](../../packages/core/test/no_lateness_proof_test.dart#L646)

- The v1→v2 migration on a seeded old database
  [`substrate_test.dart:604`](../../test/store/substrate_test.dart#L604)

- Below-10 composes no Focus Chunk, silently — through the facade
  [`facade_test.dart:111`](../../packages/core/test/facade_test.dart#L111)

- The raise composes iff the slot allows — the AC's exact clause
  [`facade_test.dart:145`](../../packages/core/test/facade_test.dart#L145)

- The derivation matrix: default, latest-wins, same-instant order, invalid-as-absent
  [`settings_test.dart:25`](../../packages/core/test/settings_test.dart#L25)

- The answer-path pin — skip with a seeded bag 5 bundles a non-focus next deal
  [`session_commands_test.dart:247`](../../packages/core/test/session_commands_test.dart#L247)

- One tap, one row; recovered chain; the null-controller path
  [`settings_screen_test.dart:295`](../../test/ui/settings/settings_screen_test.dart#L295)

- Launch with a seeded bag of 5 deals a non-focus card — the vertical proof
  [`dispenser_screen_test.dart:2149`](../../test/ui/dispenser/dispenser_screen_test.dart#L2149)

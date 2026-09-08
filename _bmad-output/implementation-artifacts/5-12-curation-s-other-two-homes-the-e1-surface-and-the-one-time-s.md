---
title: 'Story 5.12: Curation''s other two homes — the E1 surface and the one-time strip'
type: 'feature'
created: '2026-09-08'
status: 'done'
review_loop_iteration: 0
baseline_commit: '4cb53f16c9f3a1fda6d737a2a3a5c47ac9ef3695'
context:
  - '{project-root}/_bmad-output/implementation-artifacts/epic-5-context.md'
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** Curation has one home only — Settings' sub-screen (5.11). The design's other two homes do not exist: no surface inside genesis lets a starting user pick "what applies to my house" (the E1 exception — the one licensed list), and first run offers nothing — no way to discover curation exists without finding Settings, because onboarding must stay the product itself (UX-DR34, NFR5).

**Approach:** Two routes over 5.11's existing machinery, zero new kinds and zero schema change. (1) The **E1 surface** = `CurationScreen` with an optional title, pushed from the genesis screen (quiet entry below `Analizar`) and from the strip offer — the eight `CurationRow`s verbatim, the same `SettingsController` seam. (2) The **one-time strip**: `StripResident.firstRunCuration` (declared in 2-5, precedence slot 1, never eligible) gets its derivation — eligible exactly while the **first opening ever** is underway (the day's first opening ∧ no `app_opened` row from any earlier day). Tap pushes the E1 surface; tap and ✕ both consume the offer for the process; "never returns" holds by construction — eligibility is historical, so no dismissal row, no persisted flag, nothing to store (AD-21).

## Boundaries & Constraints

**Always:**
- Once-ever by derivation, not by storage: eligibility = `_firstOpeningUnderway(...)` ∧ no `app_opened` row (≤ read instant, own stored offset, AD-4) from a day before today. Neither the tap nor the ✕ writes anything; both only feed the read-scoped `excludeResidents` seam. No new LogKind, no schema bump, no `setting_changed` reuse.
- The offer renders `curationInvitation` verbatim ("Ajustar grupos de tareas", UX-DR52 register, already in ARB), sentence in the support role/ink-secondary, whole sentence one ≥48dp opaque target with `Semantics(button)`, `_DismissMark` ✕, bare chrome (UX-DR22: at most one resident; the offer is rarest, so it outranks the day-one check-in — the displaced check-in re-offers next opening).
- The E1 surface enumerates the eight clusters only — templates-at-cluster-granularity per the UX memlog correction ("template surface corrected from instantiation to cluster curation") — never a catalogue entry, never a task row; selection is the row switch, effect speeds are 5.11's (AD-16); no `epic_activated` is reachable from it (FR-11: never creates an Epic Project).
- The E1 surface IS `CurationScreen` (title param) — no cloned screen, no second lifecycle grammar; all writes stay through `writeClusterCuration` (write-path census unchanged: zero new append sites, minter still called ×1).
- Genesis stays A-slim: `Analizar` remains the one recommended action; the curation entry is quiet secondary text in the compose body only — absent from the wait body and from every way-out slot; pushes sit behind the `ModalRoute.isCurrent` guard.
- First run stays the product plus one strip: no wizard, no welcome, nothing between launch and the first card (UX-DR34, NFR5 ≤ 2 s — the eligibility is a pure log fold on the already-queued read).
- Authored copy through the ARB + `make codegen`; no wire-name literals in `lib/`.

**Ask First:**
- The one authored string `curationHouseGroups` = **"Grupos de tu casa"** (proposal: one key serving both the genesis entry label and the pushed surface's header — 5.11's entry-label-equals-header idiom). Checkpoint approval per the UX-DR52 register.
- Genesis entry placement: proposed below the `Analizar` pill in the compose body (the complement to typed entry); alternative = beside the ways-out in the footer Wrap.
- The strip's tap target: proposed the E1 surface (house-framed title); alternative = the Settings sub-screen with its default header.
- The once-ever reading itself: "shown during the first opening ever; dismissed ⇒ never returns by construction" (a kill before the user sees it loses the offer — covered by the never-saw AC). The alternative — persisting a dismissal fact — would need a new log kind and reopens the epic's declared vocabulary.

**Never:**
- No onboarding gate of any kind; no screen, dialog or delay before the first card (FR-31, UX-DR34, NFR5).
- No new LogKind, no payload column, no SETTINGS flag; the offer's paths write zero rows (AD-21).
- No template deck, no per-entry catalogue rows, no counts, no volume, no browse (FR-31, NL-1; E1 is the only list licence and it lives on this surface).
- No second curation screen widget; no direct `clusterCurationChanged`/`appendLogEntry` call outside the settings controller (census pins).
- No change to 5.11's timing semantics, the minter, the write funnel, the check-in/report residents, warm-return classification (strip paths are not contact), or `activeZoneOf`/tiers/fallback.
- Nothing curation-related on the Dispenser beyond the once-ever strip resident (FR-31, NFR3).

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Fresh install, first opening | empty log, launch deal done, strip read | `firstRunCuration` wins the precedence walk; strip shows "Ajustar grupos de tareas"; the day-one check-in is displaced (re-offers next opening) | read failure: no strip, quiet |
| Tap the offer | sentence tapped once | E1 surface pushed (house title + eight `CurationRow`s); offer consumed for the process; no row written | push guarded by `isCurrent`; quiet on read failure |
| Dismiss the offer | ✕ tapped | strip gone for the process; no row written; never returns (see below) | — |
| Any later opening | second `app_opened` today, or any app_opened from an earlier day | never eligible again — dismissed, tapped, ignored or unseen alike; standing routes are Settings + the E1 entry | — |
| Restart after dismissing | process killed, reopened same day | still gone: eligibility is historical (today's first opening already has an `app_opened` row) | — |
| Kill before seeing it | process death during the first opening | offer never shows (never-saw path); default stands — every cluster active, first day never empty (FR-31) | — |
| Transient occlusion in the first opening | inactive→resumed beat appends a second `app_opened` today | first-opening gate closes; offer gone if not yet shown — the check-in's own shipped gate semantics | — |
| First-ever sitting-open crossing 04:00 | no `app_opened` today, earliest from yesterday | not eligible (an `app_opened` exists from an earlier day) | — |
| Flip a row on the E1 surface | any switch tap | exactly one `cluster_curation_changed` row via the existing funnel; immediate daily/`fondo`, weekly at boundary (5.11 semantics verbatim) | quiet failure: switch returns to derived state |
| E1 surface during strip-unread window | pushed before first curation read | all-active default, no off-flash; pre-read tap writes nothing (5.11 grammar unchanged) | — |

</frozen-after-approval>

## Code Map

**Core — the eligibility lands where 2-5 left its slot:**

- `packages/core/lib/derive/strip.dart` -- `StripResident.firstRunCuration` (~:57, stale "Epic 8's data" doc — this story owns it); `stripResidentPrecedence` (~:82, already first); `_residentEligible` (~:121 — the `return false` branch to replace); `_firstOpeningUnderway` (:188 — the day's-first-opening gate to compose with a no-prior-day-`app_opened` scan, AD-4 own-offset discipline); `deriveStrip` (:271, `excludeResidents` seam — unchanged).
- `packages/core/lib/log/log_entry.dart` -- `LogKind.appOpened` (:~104-126) — read-only; no kind is added.
- `packages/core/lib/curation/curation.dart` -- read-only for this story (5.11 shipped the fold, `activeClustersAt`, `declaredActiveClusters`).

**Shell — the strip's two new paths and the two routes:**

- `lib/dispenser/dispenser_controller.dart` -- marker precedent `_checkInDismissMarker` (:296, day scope) / `_reportDismissMarker` (:306, opening scope); `excludeResidents` assembly (:365-379); `dismissCheckIn` (:880) — the no-write read-refresh grammar to twin as `dismissCurationOffer`/`consumeCurationOffer` with a plain process-lifetime `bool`.
- `lib/ui/dispenser/ambient_strip.dart` -- `AmbientStrip` (:174 — the check-in's sentence row + `_DismissMark` grammar to mirror); `_DismissMark` (:80, 48dp, label `ambientStripDismiss`).
- `lib/ui/dispenser/dispenser_strip_layer.dart` -- `StripLayer` switch (:82-98 — `firstRunCuration` currently falls through to `child`; the fall-through comment lies after this story); new `onAcceptCuration`/`onDismissCuration` params.
- `lib/ui/dispenser/dispenser_screen.dart` -- `_viewContent` wires `StripLayer` (~:735); push precedent `_openNuevoProyecto` (:~1018, `isCurrent` guard); `widget.settings` (`SettingsController`) already threaded.
- `lib/ui/settings/curation_screen.dart` -- `CurationScreen` ctor (:~63) gains `String? title`; header (:174, `strings.settingsCurationGroups`) becomes `title ?? …`; `CurationRow` (:205, public), `curationClusterLabelOf`/`curationCadenceLabelOf` (:26/:42) — reused untouched.
- `lib/ui/settings/nuevo_proyecto_screen.dart` -- `_composeBody` places `_analyzeAction` (:464, built :528); `SecondaryTextAction` (bottom Wrap :419-423; class in `lib/ui/dispenser/task_card.dart:90`) — the quiet-text idiom for the new entry; `_openSettings` push idiom (:376-386) to twin; `widget.settings` param already exists.
- `lib/l10n/app_es.arb` -- `curationInvitation` (:404, signoff'd — the strip string, finally used); 5.11's cluster/cadence keys (:284-318) reused; ADD `curationHouseGroups` with description + x-signoff; then `make codegen` (Makefile:41-45; freshness gate in `make check`).

**Tests and pins:**

- `packages/core/test/strip_test.dart` -- grammar: precedence group (:82), matrix (:120/:349), exclusion seam (:684). ADD the firstRunCuration group: first-opening-ever eligible; second-opening-today not; earlier-day app_opened not; crossing case not; beats the check-in on day one; excluded via the seam.
- `test/dispenser/dispenser_controller_test.dart` -- dismissal-scope tests (:2245, :2276, :2468). ADD: consume/dismiss write zero rows, exclude on re-read, first-opening view shows the resident.
- `test/ui/dispenser/ambient_strip_test.dart` -- `_RecordingStore` (:46); ✕-writes-nothing precedent (:415). ADD the offer strip's group.
- `test/ui/dispenser/dispenser_screen_test.dart` -- ADD: tap → E1 surface pushed (house title + a `CurationRow` visible), strip gone on return; AUDIT existing fresh-log cases for a now-visible resident (renegotiate only where a no-strip assertion meets an empty log).
- `test/ui/settings/nuevo_proyecto_screen_test.dart` -- tree assertions (:135-:227). ADD: entry row in compose body, absent in wait body, push wiring, A-slim unchanged.
- `test/ui/settings/curation_screen_test.dart` -- `harnessFor` (:200). ADD: title override renders; default header regression (existing pins already cover).
- `test/no_lateness_proof_test.dart` -- write-path census (:581-646) and `clusterCurationChanged` ×1 pin (:573): verify unchanged; banned wire names / forbidden vocabulary: new identifiers must pass.

## Tasks & Acceptance

**Execution:**
- [x] `packages/core/lib/derive/strip.dart` -- replace the `firstRunCuration` false branch with the first-opening-ever derivation (day's-first-opening gate ∧ no prior-day `app_opened`); fix the stale enum/layer comments -- the once-ever fact is derived, never stored
- [x] `lib/dispenser/dispenser_controller.dart` -- `consumeCurationOffer`/`dismissCurationOffer`: process-lifetime marker + queued read-refresh through `excludeResidents`, zero writes -- the ✕ and the tap are both terminal
- [x] `lib/ui/dispenser/ambient_strip.dart` -- `CurationOfferStrip`: `curationInvitation` sentence, whole-sentence ≥48dp button, `_DismissMark`, bare chrome -- the check-in's sentence-row grammar, nothing else
- [x] `lib/ui/dispenser/dispenser_strip_layer.dart` + `lib/ui/dispenser/dispenser_screen.dart` -- new `StripLayer` case + params; wire accept → consume + guarded push of the E1 surface, dismiss → controller call -- the strip's two paths land on the screen, as 2.5/2.6 did
- [x] `lib/ui/settings/curation_screen.dart` -- optional `String? title` on `CurationScreen`, header falls back to `settingsCurationGroups` -- the E1 surface without a cloned screen
- [x] `lib/ui/settings/nuevo_proyecto_screen.dart` -- quiet `SecondaryTextAction` below `Analizar` in `_composeBody`, guarded push of the titled `CurationScreen(controller: widget.settings)` -- the E1 entry, the complement to typed entry
- [x] `lib/l10n/app_es.arb` + `make codegen` -- `curationHouseGroups` = "Grupos de tu casa" (description + x-signoff per checkpoint) -- the one authored string
- [x] `packages/core/test/strip_test.dart` -- the firstRunCuration group incl. crossing and occlusion edges -- the eligibility ACs as proof
- [x] `test/dispenser/dispenser_controller_test.dart` + `test/ui/dispenser/ambient_strip_test.dart` + `test/ui/dispenser/dispenser_screen_test.dart` -- no-write paths, consumption, push wiring, fresh-log audit -- the strip's behaviour end to end
- [x] `test/ui/settings/nuevo_proyecto_screen_test.dart` + `test/ui/settings/curation_screen_test.dart` -- entry row, wait-body absence, push, title override, A-slim intact -- the genesis half's pins

**Acceptance Criteria:**
- Given a fresh install, when the app first opens, then the first card lands in ≤ 2 s with the strip offering `Ajustar grupos de tareas` and nothing else added — no wizard, no welcome (UX-DR34, NFR5).
- Given the one-time offer and a tap, when the E1 surface opens, then it shows the house title and exactly eight `CurationRow`s — identical rows, cadence the only description — and returning to the Dispenser the offer is gone (UX-DR23, FR-31).
- Given the offer dismissed, when any later opening or restart happens, then it never returns; Settings' sub-screen and the genesis entry remain the standing routes (FR-31).
- Given a user who dismisses, ignores or never sees the offer, when the first day composes, then every cluster is active and the day is never empty (FR-31).
- Given the genesis surface, when rendered, then the curation entry is quiet secondary text beside `Analizar`'s recommendation — no third top-level path, and the E1 list licence lives on the surface it opens (FR-11, E1).
- Given the E1 surface, when any switch flips, then exactly one `cluster_curation_changed` row lands through the 5.11 funnel and no Epic Project, catalogue entry or count ever appears (FR-11, FR-31, AD-21).
- Given the strip on day one alongside an unanswered check-in, when both are eligible, then only the curation offer shows — rarest wins, the check-in re-offers next opening (UX-DR22).
- Given the censuses, when `make check` runs, then the write-path map, kind census (22) and schema pins are all unchanged — this story adds no write anywhere.

## Spec Change Log

### Review Findings

- [x] [Review][Record] Fresh-log audit conclusion: the empty-`_RecordingStore` launches across the dispenser suites that remained unseeded were each inspected — no strip-absence assertion meets an empty log anywhere except the two census pins and the two genesis A-slim censuses that were renegotiated; a future strip-absence assertion over an empty log would fail correctly (the offer IS eligible there), not mysteriously [`test/ui/dispenser/dispenser_screen_test.dart`]
- [x] [Review][Patch] Duplicated header comment line after the three-residents rewrite [`lib/ui/dispenser/ambient_strip.dart`]
- [x] [Review][Patch] `_installOpen` seeded Friday 09:00 put Sunday-noon reads 51 h out — inside warm-return; moved to Friday 20:00 (40 h) in all three suites, comments included [`test/ui/dispenser/ambient_strip_test.dart`]
- [x] [Review][Patch] Stranded reflow lines in `_residentEligible`'s doc comment re-wrapped, wording unchanged [`packages/core/lib/derive/strip.dart`]
- [x] [Review][Patch] The offer's accept/dismiss read-failure arms were unpinned — matrix error cells ("quiet on read failure", no push) now have two running tests over an armed throwing store: no `CurationScreen`, no `ErrorWidget`, nothing written, consumption held through the failure and the healed re-read [`test/ui/dispenser/ambient_strip_test.dart`]
- [x] [Review][Patch] Settings test title overstated ("no curation string" behind `Nuevo proyecto`) after 5.12 added the house-groups entry; retitled, assertions untouched [`test/ui/settings/settings_screen_test.dart`]
- [x] [Review][Defer] The 2.5-era `_onDismissCheckIn` read-failure arm shares the untested shape → `deferred-work.md`
- [x] [Review][Decision] Sergio approved the proposed choices on 2026-09-09: below-`Analizar` genesis placement, the E1-surface tap destination, and derivation-based once-ever consumption; the alternatives in `Ask First` are now resolved [`5-12-curation-s-other-two-homes-the-e1-surface-and-the-one-time-s.md:31-35`, `lib/ui/settings/nuevo_proyecto_screen.dart:394-496`, `lib/ui/dispenser/dispenser_screen.dart:1012-1055`]
- [x] [Review][Patch] Compare prior app-open days by civil-date label, not by UTC start instant: with an earlier row stored at UTC−14 and the current day at UTC+14, an earlier label can have a later `startUtcMicros`, so `_appOpenedBefore` returns false and can show the supposedly once-ever offer again; add the corresponding boundary test [`packages/core/lib/derive/strip.dart:287-299`]
- [x] [Review][Patch] Add a future-dated `app_opened` regression that exercises the curation historical clause; the existing future-row test always excludes `firstRunCuration`, so removing the read-instant guard would still pass the suite [`packages/core/test/strip_test.dart:722-828`]
- [x] [Review][Patch] Add stale-read race tests for both curation actions: the handlers bump `_readGeneration`, but no curation test completes a delayed pre-action read after accept or dismissal to prove it cannot restore the invitation [`lib/ui/dispenser/dispenser_screen.dart:560-567`, `:976-1027`, `test/ui/dispenser/dispenser_screen_test.dart:6109-6179`]
- [x] [Review][Patch] Exercise a row toggle from the genesis-pushed E1 surface and assert one `cluster_curation_changed` row on the shared store; the current test proves only that the eight-row screen renders, so a broken/null Settings seam would pass [`test/ui/settings/nuevo_proyecto_screen_test.dart:300-330`]
- [x] [Review][Patch] Pin the invitation's support-role/secondary-ink styling in its widget test; the implementation uses `bodySmall`, but the current assertions would allow a primary-colored or otherwise wrong-hierarchy sentence [`lib/ui/dispenser/ambient_strip.dart:197-212`, `test/ui/dispenser/ambient_strip_test.dart:1252-1308`]
- [x] [Review][Patch] Pin that tapping blank padding inside the invitation's advertised 48dp band accepts it; the current test taps the text itself, so `deferToChild` would pass despite violating the opaque-target contract [`lib/ui/dispenser/ambient_strip.dart:196-215`, `test/ui/dispenser/ambient_strip_test.dart:1270-1284`]
- [x] [Review][Patch] Refresh stale resident and route documentation: the precedence comment still says only two residents, the controller read comment omits curation, and Settings still claims curation renders only there after 5.12 added Genesis and Dispenser homes [`packages/core/lib/derive/strip.dart:79-87`, `lib/dispenser/dispenser_controller.dart:342-350`, `lib/ui/settings/settings_screen.dart:31-35`]
- [x] [Review][Patch] Correct the deferred-work record: it says Story 5.12 avoided read-failure tests for its two new handlers, but the diff adds exactly those accept/dismiss tests; only the pre-existing check-in arm remains deferred [`_bmad-output/implementation-artifacts/deferred-work.md:309-311`]
- [x] [Review][Patch] Correct the stored-offset test comment: `01:00 UTC` with `+02:00` is `03:00` on August 29, which belongs to domestic day August 28; it is not `03:00` on August 28 [`packages/core/test/strip_test.dart:804-817`]

## Design Notes

- **Why first-opening-ever rather than a persisted dismissal:** the epic's declared log vocabulary has no kind for an invitation dismissal, and 5.11's Never tier bans `setting_changed` reuse — so the only AD-21-legal once-ever is a derivation over facts that already exist. `app_opened` rows are the opening delimiters (`_firstOpeningUnderway`'s own reading); "the first one ever belongs to today, and today's first opening is underway" gives dismissed⇒never-returns exactly, with nothing stored. The cost is explicit: a process death during the first opening loses the offer — the never-saw AC already prices that path (default stands).
- **Why the tap lands on the E1 surface, not Settings' sub-screen:** EXPERIENCE §207 says "tappable to the cluster list" with "Settings and the E1 surface" as the *standing* routes — the offer is neither; it is the onboarding moment, and the house-framed title is its register. One `CurationScreen` serves both homes; only the title string differs.
- **Why one string for entry and header:** 5.11's idiom — the settings entry row's label is the sub-screen's header again. `curationHouseGroups` plays both roles on the genesis side; `curationInvitation` stays the strip's own sentence (UX-DR52 register).
- **"Templates" today:** the memlog correction ("from instantiation to cluster curation") plus the absence of any authored template names means the Library's groups — the eight clusters — are the template granularity the E1 surface enumerates. If a future story authors named house archetypes, this surface is where they land; nothing here precludes it.
- **Golden example:** fresh install 09:00 → launch deal (card 1, ≤ 2 s), strip shows the offer, check-in displaced. User taps → "Grupos de tu casa" with eight rows; flips `z3` off (one row, effective next Monday 04:00); back → strip gone. 21:00 reopen → no strip ever again; `z3` exclusion already standing.

## Verification

**Commands:**
- `devbox run -- make gate` -- expected: green (format, analyze, full suite incl. the renegotiated dispenser/genesis groups)
- `devbox run -- make check` -- expected: green (codegen fresh, censuses unchanged, no-literal-strings + vocabulary clean)
- `devbox run -- make test-core` -- expected: green (strip group: first-opening-ever, crossing, occlusion, precedence)
- `devbox run -- flutter test test/ui/dispenser test/ui/settings test/dispenser` -- expected: exit 0

**Manual checks (device, AGENTS.md recipe):**
- Fresh install (uninstall first): first card under 2 s with the strip beside it; tap → surface, flip a row, back → strip gone; kill + reopen → strip never returns; `Ajustes` → `Contenido de la casa` still the standing route; genesis → quiet entry below `Analizar` opens the same rows under the house title.
- Pull `organizer_substrate.sqlite`: only the expected `cluster_curation_changed` row(s) — zero rows from the offer's own paths; schema still v11.

## Suggested Review Order

**The once-ever derivation — the story's keystone**

- The eligibility itself: first-opening gate ∧ no earlier-day `app_opened` — "never returns" by construction.
  [`strip.dart:144`](../../packages/core/lib/derive/strip.dart#L144)

- The historical clause: own-offset day scoping, rows after the read instant excluded (AD-4).
  [`strip.dart:281`](../../packages/core/lib/derive/strip.dart#L281)

**The two terminal paths — zero writes**

- The process-lifetime marker feeding the read-scoped `excludeResidents` seam (AD-21).
  [`dispenser_controller.dart:326`](../../lib/dispenser/dispenser_controller.dart#L326)

- Tap and ✕ both land here — set synchronously, then the queued read.
  [`dispenser_controller.dart:975`](../../lib/dispenser/dispenser_controller.dart#L975)

**The strip surface — the onboarding half**

- The offer resident: sentence verbatim, one ≥48dp button, `_DismissMark`, bare chrome.
  [`ambient_strip.dart:179`](../../lib/ui/dispenser/ambient_strip.dart#L179)

- The layer's new case — the fall-through era ends.
  [`dispenser_strip_layer.dart:103`](../../lib/ui/dispenser/dispenser_strip_layer.dart#L103)

- The accept path: consume, commit, guarded push of the E1 surface.
  [`dispenser_screen.dart:1012`](../../lib/ui/dispenser/dispenser_screen.dart#L1012)

- The dismiss path: same grammar as the check-in's ✕, quiet on read failure.
  [`dispenser_screen.dart:976`](../../lib/ui/dispenser/dispenser_screen.dart#L976)

**The E1 surface and its genesis entry — the other half**

- The title param: one screen, three homes; Settings' default header stands unchanged.
  [`curation_screen.dart:76`](../../lib/ui/settings/curation_screen.dart#L76)

- The guarded push from genesis, house title riding the ctor.
  [`nuevo_proyecto_screen.dart:394`](../../lib/ui/settings/nuevo_proyecto_screen.dart#L394)

- The quiet entry below `Analizar` — the complement to typed entry, A-slim intact.
  [`nuevo_proyecto_screen.dart:493`](../../lib/ui/settings/nuevo_proyecto_screen.dart#L493)

- The one authored string, signoff'd — entry label and header in one key (5.11's idiom).
  [`app_es.arb:409`](../../lib/l10n/app_es.arb#L409)

**Proofs**

- The eligibility matrix: first-opening-ever, later openings, crossing, offsets, seam, precedence.
  [`strip_test.dart:722`](../../packages/core/test/strip_test.dart#L722)

- Zero-row consume/dismiss, exclusion on re-read, never-returns across processes.
  [`dispenser_controller_test.dart:3063`](../../test/dispenser/dispenser_controller_test.dart#L3063)

- The offer's rendering plus the review-pinned read-failure arms — quiet, no push, consumption held.
  [`ambient_strip_test.dart:1217`](../../test/ui/dispenser/ambient_strip_test.dart#L1217)

- Tap → E1 surface end to end: house title, eight rows, one funnel row, strip gone on return.
  [`dispenser_screen_test.dart:6109`](../../test/ui/dispenser/dispenser_screen_test.dart#L6109)

- The genesis half: entry present, wait-body absence, push wiring.
  [`nuevo_proyecto_screen_test.dart:254`](../../test/ui/settings/nuevo_proyecto_screen_test.dart#L254)

- The title override pin; Settings' default header regression rides 5.11's suite.
  [`curation_screen_test.dart:297`](../../test/ui/settings/curation_screen_test.dart#L297)

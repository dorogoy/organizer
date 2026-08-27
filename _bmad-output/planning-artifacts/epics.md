---
stepsCompleted:
  - step-01-validate-prerequisites
  - step-02-design-epics
  - step-03-create-stories
  - step-04-final-validation
inputDocuments:
  - _bmad-output/specs/spec-organizer/SPEC.md
  - _bmad-output/planning-artifacts/prds/prd-organizer-2026-08-20/prd.md
  - _bmad-output/planning-artifacts/prds/prd-organizer-2026-08-20/addendum.md
  - _bmad-output/planning-artifacts/architecture/architecture-organizer-2026-08-26/ARCHITECTURE-SPINE.md
  - _bmad-output/planning-artifacts/ux-designs/ux-organizer-2026-08-21/DESIGN.md
  - _bmad-output/planning-artifacts/ux-designs/ux-organizer-2026-08-21/EXPERIENCE.md
  - project-context.md
status: final
readiness: clear
upstreamDebtsPaid: 2026-08-27
  # All four debts written into the PRD and the Architecture Spine by two clean-context passes:
  #   AD-4's Week clause rewritten to SM-2 persistence + the two forced consequences
  #   A `shipped` task's Origin Context = its Spanish catalogue name (PRD glossary + FR-5 + AD-16 mechanism)
  #   PRD OQ-1's venue = the development machine via Lemonade, with E2B as the preferred candidate
  #   Plus one found while verifying: AD-16's fourth catalogue field now DECLARED as an override of FR-31's three
inputsReadAt: 2026-08-27 (post blocker-resolution pass; all five documents at status final, updated 2026-08-27)
precedence: "SPEC.md is canonical (self-declared contract). PRD / Architecture Spine / UX spine pair are its companions and the source of FR, NFR, AD and UX-DR detail. On conflict, SPEC wins; §1.1 principles win over any FR; the UX/Architecture spines win over the PRD on the surfaces they own."
---

# organizer - Epic Breakdown

## Overview

This document provides the complete epic and story breakdown for the Anti-Overwhelm Mobile Task Organizer (working title; product naming deferred), decomposing the requirements from the canonical SPEC, the PRD, the UX design contract (`DESIGN.md` + `EXPERIENCE.md`) and the Architecture Spine into implementable stories.

**Product in one line.** A single-user, local-first, backend-free Android app that converts household and personal work into exactly one dispensed micro-action at a time, with zero guilt mechanics, a swappable BYOK Smart Slicer, and a four-week validation window as its delivery boundary.

**Two rules that override everything below.** The PRD's §1.1 principles beat any FR they contradict ("where an FR and a principle conflict, the principle wins and the FR is wrong"). And `NL-1` — no screen anywhere enumerates, counts, filters or browses pending or captured work — is not a UI preference but a schema and read-API constraint (AD-2, AD-6).

**One declared exception register, holding two entries.** The FR-23 dashboard departs on information density; the per-scan consent gate departs on the one-recommended-action rule, carrying zero. **E2 (the multi-path genesis zone) dissolved on 2026-08-27** when the camera moved to the Dispenser as a direct entry — the genesis surface came back to one recommended action plus one way out, literally. E1 (the Archetype Template list) is an exception to the *no-list* clause and never bent the one-action clause. Anything claiming a third exception is a defect.

## Requirements Inventory

### Functional Requirements (index)

Source of record: **PRD §4** (status final, updated 2026-08-27). FR IDs are stable identifiers, not an ordering. All 32 are in scope (PRD §6). Every operative clause is restated at point of use by the story acceptance criteria that cite it; this index exists for lookup and ID anchoring, not as the text of record. Epic and story homes: the FR Coverage Map below.

| FR | Subject (one line) |
|---|---|
| FR-1 | Single-card viewport; nothing within 3 taps shows two actionable Micro-tasks |
| FR-2 | `Hecho` in one tap; next card < 500 ms; non-intrusive positive feedback |
| FR-3 | Guilt-free skip, alternative dealt, no failure recorded; pool exhaustion closes with the fixed warm string |
| FR-4 | 1-tap daily energy check-in at the first opening; only 🔴 narrows; the weekly self-report outranks it while pending |
| FR-5 | Rescue Mode: 2–4 steps ≤ 60 s via Origin Context; depth capped at 1; dissolution pattern; degrades per FR-29 |
| FR-6 | Warm Return ≥ 48 h: rebalanced plan, no reference to missed days anywhere |
| FR-7 | Daily Time Bag 5–30, default 15; advance work only; below 10 = no Focus Chunk, silently |
| FR-8 | `Tengo X minutos ahora`: dealt estimates sum ≤ the declared pocket; never ended by the app |
| FR-9 | Pause at any moment; silent recalculation; no interrupted/overdue state in either language |
| FR-10 | Anti-Marathon checkpoint as permission-to-rest; extension a silent secondary; no `¿seguimos?` anywhere |
| FR-11 | Dual lifecycle: Evergreen active by default; Epic Projects via the Slicer only; one zone active per day |
| FR-12 | Automatic 1-3-5 weaving scaled to bag and energy; capture precedence; 3-eligible-day deal window |
| FR-13 | Invisible safety buffers; 7 days of absence push no milestone overdue |
| FR-14 | Silent rescheduler: no overdue concept anywhere in the data model surfaced to the UI |
| FR-15 | Gentle seasonal activation; once per season per project; declining has zero side effects |
| FR-16 | Photo scan via Smart Slicer; unbounded in-app foreground wait; entry visibility = enabled ∧ permission not refused |
| FR-17 | Before/After reward: side-by-side diff, no negative framing, saved to the Album automatically |
| FR-18 | Local transformation album: individually deletable, purgeable in one action, never sent |
| FR-19 | Pre-clean purge injection: the first dealt task of a newly activated organizing project is a purge step |
| FR-20 | Two mandatory Sí/No detachment questions, then the equal-weight 3-Destination Flow |
| FR-21 | Quarantine Box: blind 6-month timer, at most once per box, copy claims no knowledge of contents |
| FR-22 | Cumulative liberated-items metric: tap-only, coarse volume tags, never a target or rate |
| FR-23 | Cumulative impact dashboard under the denominator rule; snowball suggestion ≤ +5 min, suppressed at the cap |
| FR-24 | One silent opt-in daily invitation; at most one per 24 h (superseded by the domestic-day rule, Story 8.2) |
| FR-25 | Per-scan consent, no blanket allow; on-device face gate; scan image deleted once the plan exists |
| FR-26 | Four on-device-only series; immutable genesis origin; no analytics SDK; no cumulative skip total |
| FR-27 | Manual Capture: one line + one of exactly three sizes, nothing else; no validation, no refusal, no list |
| FR-28 | BYOK access path behind `SlicerPort`; frozen provider allowlist; no account; non-exportable key |
| FR-29 | Honest degradation: seven distinguishable causes, one calm surface, `Anotarlo` exit |
| FR-30 | Silent automatic export (foreground triggers); full restore, no merging; state readable in Settings only |
| FR-31 | Pre-sliced Evergreen Library: four fields, ≥ 28 eligible floor, cluster-level curation, fixed at build time |
| FR-32 | On-device voice dictation into the capture line; absent where unavailable; no audio retained |

### NonFunctional Requirements

**The PRD carries no numbered NFR section.** These are extracted from PRD §7 (Cross-Cutting Constraints), §10.1, the SPEC's Constraints block, and the Architecture Spine's Stack, and given stable IDs here for citation. Each is a build-wide constraint, not a feature.

- **NFR1: Offline by default — execution, not genesis.** Dispensing, completing, weaving, rescheduling, the album, the dashboard, export and Manual Capture (voice included) work with no network, always. Slicing does not: on BYOK every slice and re-slice needs the network. Airplane mode is a supported condition, never an error state; no banner, no retry prompt, no degraded chrome.
- **NFR2: Local-first durability, no developer-held data.** No developer-side record of any kind exists. A lost device loses the album and every series unless exported, which is why FR-30's export is required rather than optional. No backup reminders or backup-age indicators anywhere.
- **NFR3: The settings/Dispenser split.** Anything a validator needs and a user must never see — the FR-26 raw series, FR-30's export state, FR-32's dictation boolean, a Managed credit balance — is reachable in settings and nowhere else. Settings is reached only as the quiet text way-out inside the `Nuevo proyecto` surface, and that is the only route into the validator surface from any surface within three taps of the Dispenser.
- **NFR4: Closed data-egress map.** To the AI provider: exactly three payload shapes, ever — scan image + prompt, project genesis text, rescue re-slice text — and on BYOK that provider is the user's own account. **Audio: nowhere, to no one.** To the user's own storage: whatever the user exports, when the user chooses. **To the developers: nothing** — no app-open counts, no telemetry, no analytics.
- **NFR5: Latency inside a 15-minute pocket.** Cold start to first dispensed card ≤ 2 s — **and this contract holds hardest on day one**, which is why onboarding is not a wizard; Done → next card < 500 ms; energy re-filter < 500 ms. Slicing is deliberately exempt: no cap, no timeout.
- **NFR6: Accessibility floor — scoped to goals, not surfaces** *(re-scoped 2026-08-27)*. Legible at 200% system font scale with no truncation — nothing ellipsized, no `maxLines`, no `FittedBox`, no `TextScaler` override, no fixed-height container around text; the card grows and the screen scrolls. Every action reachable one-handed; touch targets never below 48dp. Haptics never the sole completion signal. **No goal is reachable only by typing**: creating work needs no keyboard because the photo path needs no words (FR-16), the capture line can be dictated (FR-32), and Evergreen ships pre-sliced (FR-31). **The genesis surface's typed entrance is an alternative, not a gate** — the same goal, a personal project, is reachable wordlessly through the camera — so typing there does not break the floor. Settings is outside the floor. Any future goal reachable only through typed input breaks it.
- **NFR7: Copy is the product surface.** Spanish UI, every string externalised in one ARB table, no runtime sentence concatenation — the SM-C2 anti-shaming audit must be reviewable as a flat string table. The audit list is every key in the shipped ARB minus an explicit reviewed exclusion list.
- **NFR8: Background minimalism and one permission rule.** The only background work is FR-24's daily invitation, delivered by an inexact alarm. No sync, no location, no persistent service, no wake locks, and no microphone outside an explicit press. **Runtime permissions follow one generalized rule: requested at first use and never at first run** — the microphone at the first dictation attempt, the camera at the first scan attempt. **Refusing either removes the affordance silently until the user reverses it in settings; the app never re-asks on its own.** FR-30's export is deliberately not an exception: it runs in the foreground at session end and app backgrounding.
- **NFR9: No overdue at the schema level.** No field, flag or derived value anywhere may express lateness, debt or a missed occurrence. Enforced by a lint over a forbidden vocabulary (`overdue`, `late`, `missed`, `pending`, `debt`, `streak`, `skippedCount`, `dueDate`, `backlog`).
- **NFR10: Single-user data model throughout.** All local data is account-free and single-user; the pool and log carry no owner column. Multi-user remains a knowingly accepted schema change.
- **NFR11: No account in the validation build.** BYOK needs a key, not an identity: no login, no password, no registration, no first-run network requirement. The app is fully usable the second it installs.
- **NFR12: Platform and stack.** Android only. Flutter 3.47.1 / Dart 3.13.1, Java 17. Android target SDK 36, **minSdk 33** (set by `POST_NOTIFICATIONS` and by `checkRecognitionSupport()` / `triggerModelDownload()`). 64-bit ABIs only (`abiFilters` excludes 32-bit — also the 16 KB page-size condition). No `material_ui` / `cupertino_ui` dependency added.
- **NFR13: No network SDK enters the build.** No analytics, crash-reporting, remote-config, feature-flag or other third-party SDK that opens a network destination may be added, for any reason. Crash visibility is a local `crash_recorded` event carrying stack and timestamp and no task text, image paths, prompt or URL.
- **NFR14: Scan-data lifecycle.** Every scan requires per-scan consent after on-device person detection. Each scan owns one cache subdirectory holding at most two files, both unlinked when the scan resolves by **any** means — plan, face refusal, declined consent, provider failure, or the user leaving/backgrounding — with a sweep at each app open as the crash backstop.
- **NFR15: Credential custody.** BYOK is the only usable release Slicer path. Providers are compile-time allowlisted by dated written no-training terms. Credentials are non-exportable, never in preferences, never in domain state, never in either half of the export; no account, proxy or developer key custody exists.
- **NFR16: Determinism.** Given the same pool, event log, calendar day and session facts, selection is deterministic. No `Random`, no wall-clock read, no `dart:io`, no ambient state inside the core.
- **NFR17: Story completion gate.** A story is done only when `flutter test`, `dart format --set-exit-if-changed .` and `flutter analyze` all pass. *(Source: `project-context.md` / `AGENTS.md` Policy.)*
- **NFR18: Testing shape.** Core invariants are exercised with `dart test` on the machine, no emulator. Widget tests only where a surface consumes the read facade or a command. No golden tests; visual and behavioural verification is manual on the three validation handsets.
- **NFR19: Theme selection is the platform's.** Light/dark **follows the system, with no settings row** — an override row would be the app's only duplicated preference, and the Foundation rule is that everything unstated is the platform's *(decided 2026-08-27, closing its OQ with zero UI)*.
- **NFR20: One `Makefile` at the repository root is the entry point for every development command.** Tests, formatting, linting, analysis, localisation regeneration, the `tool/` build-time checks, running and building — no development operation is invoked by a remembered incantation. **`make gate` runs exactly NFR17's three commands** (`flutter test`, `dart format --set-exit-if-changed .`, `flutter analyze`) so the story completion gate is one command, and **CI invokes the same targets** so local green means CI green. `make help` lists every target with a one-line description. The file grows additively: every story that introduces a `tool/` check or a build-time guard registers its own target in the same pass. *(Builder requirement, 2026-08-27.)*

### Additional Requirements (index)

Source of record: **ARCHITECTURE-SPINE.md** (status final, updated 2026-08-27). The scaffold tree, the pinned stack table and the authored catalogue counts live there and are consumed where needed (Stories 1.1 and 1.5). Paradigm in one line: functional core / imperative shell, seven ports (`Store`, `Slicer`, `Clock`, `Notifier`, `Recognizer`, `Folder`, `Files`), adapters named for their technology, dependencies pointing inward only. Every AD below is cited by the story acceptance criteria that must honour it — the 26/26 mapping is asserted in Coverage completeness.

| AD | Subject (one line) | Anchored in |
|---|---|---|
| AD-1 | No plan is ever stored; the day is derived from (pool, log, day, session) | 1.6, 2.1, 6.4 |
| AD-2 | Both stores insert-only, enforced by SQL triggers in a `.drift` file | 1.3 |
| AD-3 | Determinism; `card_dealt` written by a command, never by rendering | 1.1, 1.6 |
| AD-4 | One calendar authority: 04:00 day, Monday week, meteorological season; SM-2 persists until answered | 1.4, 2.6, 5.7, 8.2 |
| AD-5 | Core sealed (no flutter/drift/plugins, CI-enforced); no adapter names inside | 1.1 |
| AD-6 | NL-1 in the read API: no collections of pending/captured tasks; signals named as facts | 1.6, 3.3 |
| AD-7 | One egress chokepoint sealed three ways; exactly three payload shapes, no fourth as a type | 4.2 |
| AD-8 | Consent a single-use `ScanConsent` token; scan cache unlinked on every terminal path | 5.2, 5.3 |
| AD-9 / AD-10 | `SlicerPort`'s three implementations; compile-time provider allowlist, no-training gate | 4.4, 4.1 |
| AD-11 | Three Kotlin channels (notify, dictate, credentials); no socket, no date arithmetic | 3.4, 4.3, 8.1 |
| AD-12 | Egress map a closed list; no network SDK for any reason; `crash_recorded` is the only diagnostic | 1.3, 4.2 |
| AD-13 | Export authoritative/derived split; one foreground coordinator; `(generationSequence, generationId)` order | 9.2, 9.3 |
| AD-14 | Origin set at genesis, immutable, inherited by rescue steps, never in the Dispenser | 1.3, 3.2, 4.6, 5.4 |
| AD-15 | The shipped ARB is the string table; no literals; pinned keys need value + sign-off | 1.2, 4.5 |
| AD-16 | Catalogue a build-time asset: four fields, ARB names keyed by id, 28-deal rotation test | 1.5, 1.7, 4.6 |
| AD-17 | Three runtime permissions at first use; inexact alarm; `RECEIVE_BOOT_COMPLETED`; no exact-alarm | 3.4, 5.2, 8.2 |
| AD-18 | Update path is the restore path: one keystore, install-on-top, debug never on a validation handset | 9.3 |
| AD-19 | No session of record; a session belongs to its start day; exactly three closing causes | 2.2 |
| AD-20 | One resolver owns the Focus slot: occupancy vs identity, Epic arbitration, below-floor fallback | 1.6, 3.3, 5.4, 6.1 |
| AD-21 | One log of user acts and system events; no entry asserts an absence; store seal | 1.3 |
| AD-22 | No secret in log, pool or export; vault envelopes; `withCredential` per request | 4.3 |
| AD-23 | Forward-only evolution: unknown kinds tolerated, payloads additive, catalogue ids permanent | 1.3, 1.5, 5.3, 9.3 |
| AD-24 | Exactly one `EligibleDay(item, day)`; `warmReturnDue` the one sibling | 2.7, 3.3, 4.6 |
| AD-25 | Pool membership derived; no synthetic completion; dissolution retires the chain atomically | 4.6, 1.11 |
| AD-26 | Achievement figures cross only to the dashboard; internal signals never cross as numbers | 7.3, 9.1 |

Also from the spine, consumed where cited: the six `tool/` build-time checks (AD-3/5, AD-7 ×3, AD-15, AD-16, AD-23, AD-21's store seal) plus AD-22's export-fixture check; the two export property tests (AD-13 round-trip, AD-16 rotation) live as tests; no logging framework and no log destination (AD-12); deferred by the architecture and **not to be built**: OQ-1's deployment topology, log-growth projections, multi-user, iOS, committed-export compaction, screen-reader semantics, API 37, design-token generation, the second locale.

### UX Design Requirements (index)

Source of record: **DESIGN.md + EXPERIENCE.md** (the spine pair, updated after the 2026-08-27 blocker-resolution follow-up). Mockups illustrate; the spines specify and win on conflict — over the PRD, the reference image and every artifact in `mockups/`. Remaining deferred positions and implementation checks are carried by Coverage completeness below. Every UX-DR is cited by the story acceptance criteria that implement it.

| UX-DR | Subject (one line) | Story |
|---|---|---|
| 1 | Full token set once in `lib/ui/tokens.dart`, referenced nowhere else by literal | 1.2 |
| 2 | Two-tier colour discipline: field tier at Aliento baseline; icon-mass at L\* 76.0 exactly | 1.2 |
| 3 | Four colour rules: `accent-soft` the sole text pastel; destination hues only inside glyphs | 1.2, 6.3 |
| 4 | `icon-mass-blue` = active state only, never a meaning | 2.5, 3.4 |
| 5 | Eight-role ramp: Lora for task text only, Lexend for the other seven; sp with multiplier line-heights | 1.2 |
| 6 | Flat depth: tone + 1px hairline; no gradients, glow or blurred shadows | 1.8 |
| 7 | Three radii: 14 default, 9999 for time quantities, 4 for album thumbnails | 1.2, 7.2 |
| 8 | Printed-matter glyphs: one global 45° offset, mass under line, one stroke width per render | 1.2 |
| 9 | Registered-mass rule for masses whose axis contradicts the vector (batería, mic capsule) | 2.5, 3.4 |
| 10 | Seed glyph: exactly 8 filaments, 45° axis, motion dashes only at ≥ 56px | 1.2, 6.3 |
| 11 | Ten-glyph set; the Ajustes glyph is dissolved | 1.2 |
| 12 | Dark palette separately authored, never an inversion | 1.2 |
| 13 | Destinations keep their light form in dark mode | 6.3 |
| 14 | `dispenser-card`: order, hairline, and air as 48dp minimum plus flex | 1.8 |
| 15 | Dispenser furniture grammar: mass means work, prose means leaving | 3.2, 5.2 |
| 16 | `action-primary Hecho`: full-width `accent-soft`, 48dp, one tap, no confirmation | 1.9 |
| 17 | The unsplit text secondary; string never split or ellipsized; fold verified on device | 1.10 |
| 18 | `duration-chip` eyebrow above the task; also the pocket trigger | 1.8, 2.2 |
| 19 | `size-option`: durations never internal names; selected `accent-soft`; no glyph | 3.2 |
| 20 | Battery check-in marks: registered charge filling from the left, no offset | 2.5 |
| 21 | Mic capsule at the field's end; state declared in ink and prose, never by motion | 3.4 |
| 22 | `ambient-strip`: six residents, at most one visible; ephemeral bare, persistent hairline | 2.5 |
| 23 | `curation-row`: one component, three homes, cadence as the only description | 5.6 |
| 24 | Cámara entry: absent never greyed; reversal in Settings; visibility = enabled ∧ permission | 5.2 |
| 25 | `Nuevo proyecto`: quiet text affordance carrying typed entry + the Settings way-out | 2.1, 5.4 |
| 26 | `action-equal-pair` consent gate: zero recommended actions, no fill on either | 5.3 |
| 27 | `destination-flow`: three glyphs at 64px, one decision per screen, no tile or default | 6.3 |
| 28 | `zone-marker` Hoja footer: a place-marker, not a control | 1.8 |
| 29 | `photo-frame`: 3:4, labels outside, empty frame of the right shape while loading | 7.1, 7.2 |
| 30 | `dashboard-highlight-row`: reflow by lines at the two-line break, never shrink | 7.3 |
| 31 | The surface map exactly as sited | all |
| 32 | Contextual navigation plus one quiet prose departure; no nav bar, no destination list | 7.2, 7.3 |
| 33 | Settings as a flat platform list in five quiet groups | 2.1, 4.4, 8.1, 9.2 |
| 34 | Onboarding = the product plus one one-time strip; the first card in ≤ 2 s | 5.6 |
| 35 | Two declared exceptions and no third; dashboard density must not propagate | 7.3 |
| 36 | The denominator rule as a checkable review gate, value by value | 7.3 |
| 37 | The volume line carries no glyph (glyph-adjacency rule) | 6.5, 7.3 |
| 38 | The card exits entirely; never toward a counter, pile or badge | 1.9 |
| 39 | Celebration mandated, two tiers, three rules; never gates the next card | 1.9 |
| 40 | Two anti-score rules: equal plates; only `Antes` and `Después`, with no caption | 7.1 |
| 41 | State patterns as specified: cold open, warm return, pause, no-Slicer, offline, first run … | 1.8, 4.5 |
| 42 | Manual Capture's spatial frame as an ordering rule; no second version of the screen | 3.2 |
| 43 | Interaction primitives: one tap per primitive; stopping always one tap; contractual timings | 2.3 |
| 44 | The banned-everywhere list (lists, streaks, `¿seguimos?`, alarm red, animated states …) | 1.8, 4.5, 6.2 |
| 45 | The 200% floor by growing and scrolling; one lint bans all five escapes; 48dp targets | 1.2, 1.8 |
| 46 | The dashboard reflow is the one named degradation, expected not a defect | 7.3 |
| 47 | Silhouette alone carries the 3-destination differentiation (load-bearing) | 6.3 |
| 48 | Screen-reader interim convention: no custom semantics, platform traversal | 1.2 |
| 49 | The 26 authored fixed strings, verbatim, never re-worded | 3.2, 6.3 |
| 50 | The seven no-Slicer strings authored and pinned; exit works in all seven states | 4.5 |
| 51–54 | Authored copy items, except the non-gating plates-not-meal question | register |
| 55 | The Voice-and-Tone do/don't table applies to every string entering the table | 1.2 |
| 56–59 | Authored scan-wait, diff and question presentation; seasonal configuration remains open | register |
| 60–62 | `[DEFERRED]`: system chroma, `short-date` past a year, the second locale | — |

### FR Coverage Map

Legend: **E1–E9** are the epics below. Two FRs are deliberately split across two epics; the split is named rather than hidden.

| FR | Epic | What that epic does with it |
|---|---|---|
| FR-1 | **E1** | The single-card viewport — the Dispenser's whole premise, and the read-facade shape (AD-6) that makes NL-1 structural |
| FR-2 | **E1** | `Hecho` in one tap, the card exits, next card under 500 ms, tier-one haptic acknowledgement |
| FR-3 | **E1** | `Ahora no` — the skip half of the unsplit secondary control; skips consume no rotation (AD-20) and record no failure |
| FR-4 | **E2** | The daily energy check-in: battery marks in the ambient strip, first opening, skippable, SM-2 outranks it while pending |
| FR-5 | **E4** | Rescue Mode — the Slicer's cheapest real consumer (text-only re-slice, no camera, no consent dialog), depth capped at 1, dissolution pattern |
| FR-6 | **E2** | Warm Return via the `warmReturnDue` sibling predicate (AD-24); the absence is unrepresentable, so it cannot reach the screen |
| FR-7 | **E2** | The Time Bag becomes settable (E1 ran on its 15-minute default); advance-only coverage; the below-10 silent no-chunk day |
| FR-8 | **E2** | The pocket trigger — `Tengo 15 minutos ahora`; dealt durations sum to ≤ the declared pocket |
| FR-9 | **E2** | Pause and silent recalculation; only unspent *advance* minutes return to the bag |
| FR-10 | **E2** | The Anti-Marathon checkpoint as permission-to-rest; extension as a silent secondary; no `¿seguimos?` anywhere |
| FR-11 | **E1** *(Evergreen half)* | Evergreen active by default from the shipped Library; one zone active per day rotating over active clusters |
| FR-11 | **E5** *(Epic half)* | Epic Project genesis through the Slicer, both entrances: the Dispenser's Cámara entry and the typed genesis surface (A-slim) |
| FR-12 | **E1** | The 1-3-5 weave and AD-20's single resolver — the extension point epics 3 and 5 later feed candidates into |
| FR-13 | **E5** | Invisible buffers — nothing to buffer until Epic Projects exist, so it lands with them |
| FR-14 | **E1** | Discharged as a **proven property, not code**: AD-1 means nothing was assigned to a future day, so nothing needs re-planning. Carried by a test that lateness is inexpressible |
| FR-15 | **E5** | Seasonal activation suggestion — an ambient-strip resident, once per season per project |
| FR-16 | **E5** | The Cámara entry, the scan surface and its unbounded in-app wait; entry visibility = enabled ∧ permission not refused |
| FR-17 | **E7** | The Before/After reward: two equal plates, only `Antes` and `Después`, `Cerrar` never *seguir* |
| FR-18 | **E7** | The local Transformation Album — contextual only, individually deletable, purgeable in one action |
| FR-19 | **E6** | Purge injection: the first dealt card of a newly activated organizing project is always a purge step |
| FR-20 | **E6** | The two detachment questions and the three equal destinations, differentiated by silhouette alone |
| FR-21 | **E6** | The Quarantine Box and its blind six-month follow-up, derived from `box_created`'s instant |
| FR-22 | **E6** | The per-destination tap count and coarse volume tags — the figures **E7** later renders |
| FR-23 | **E7** | The cumulative impact dashboard under the denominator rule, plus the snowball suggestion on the strip |
| FR-24 | **E8** | The one silent invitation: `IMPORTANCE_LOW` channel created once, inexact alarm, one per domestic day, boot reschedule |
| FR-25 | **E5** | Per-scan consent as a single-use token (AD-8), the on-device face gate, and the scan-file lifecycle on every terminal path |
| FR-26 | **E9** | The four series assembled and rendered — **the acts themselves were written by the epic that owns each behaviour** |
| FR-27 | **E3** | Manual Capture: one line, three sizes, the spatial frame's ordering rule, no validation and no refusal |
| FR-28 | **E4** | BYOK behind `SlicerPort`, the compile-time allowlist, the debug-only Local stub, and AD-22's credential vault |
| FR-29 | **E4** | Honest degradation: one calm surface, the seven authored strings, and the `Anotarlo` exit **E3** already built |
| FR-30 | **E9** | Silent generational export and full restore — the authoritative/derived split and the round-trip property test |
| FR-31 | **E1** *(catalogue half)* | The build-time asset, its ARB names, the ≥ 28 eligible-unit floor check and the 28-deal rotation test |
| FR-31 | **E5** *(curation half)* | The `curation-row` in all three homes, and onboarding as the product plus one one-time strip |
| FR-32 | **E3** | On-device dictation into the capture line: the `dictate` channel, the capsule glyph, `Escuchando…`, absent-and-silent |

**Coverage: 32 of 32 FRs mapped.** No FR is unassigned, and no epic depends on a later epic to function.

**Where the NFRs land.** NFR1–NFR20 are build-wide and owned by no single epic; NFR9 (no overdue at the schema level), NFR16 (determinism), NFR7 (the ARB as the single string table) and NFR12 (the pinned stack) are established by Epic 1 and inherited. The rest are verified per story through the `tool/` checks, the lints and NFR17's completion gate.

## Epic List

**Nine epics.** The solution design is validated end to end — Architecture Spine, UX spine pair and SPEC all `final` — so the structure prefers fewer, larger epics over many small ones, per the standing rule that direction changes between epics are unlikely here.

**Why heavy shared-file overlap does not force one giant epic.** Almost the whole product lives in `core/weave`, `core/derive`, `core/pool` and `core/log`. Three pre-designed extension points are what keep separate epics from churning the same files:

- **AD-20's resolver.** `core/weave` is the only code that may emit a deal, and *everything else returns candidates with precedence*. Epic 3 adds manual captures and Epic 5 adds Epic material as new candidate sources — neither reopens Epic 1's composition logic.
- **The `ambient-strip`.** One spec, six residents, differences carried in behaviour rather than chrome. Epic 2 builds it with its first resident; epics 5, 6 and 7 add residents as data.
- **Settings.** A flat five-group list, fully enumerated up front. Epic 2 builds the shell plus **Tu día**; epics 4, 5, 8 and 9 each add their own group.

That is incidental sharing of stable components, not the same component redesigned end to end.

**Three ordering constraints, discovered rather than assumed:**

1. **Epic 3 precedes Epic 4.** FR-29's degradation surface has exactly one exit — `Anotarlo`, to Manual Capture. Build the Slicer first and that surface has nowhere to go.
2. **Rescue Mode (FR-5) lives with the Slicer, not with Epic 2's relief valves.** It needs a re-slice, and it is the Slicer's cheapest real consumer: text only, no camera, no consent dialog.
3. **FR-13 and FR-19 land at or after Epic 5.** There is nothing to buffer and nothing to purge until Epic Projects exist.

---

**The nine epics, one line each** — each epic's full narrative, scope notes and stories live in its own section below; the implementation notes formerly carried here are merged into those sections (2026-08-27).

- **E1 · The Day That Deals Itself** — a fresh install in airplane mode deals one household card in ≤ 2 s: the vertical slice that proves the paradigm.
- **E2 · How Much the App Asks of Me** — Time Bag, pocket, pause, checkpoint, energy check-in, Warm Return: everything narrows what the app requests; nothing adds work.
- **E3 · The Floor — Capture by Hand or Voice** — a ten-second capture, typed or spoken, that comes back as an ordinary card and never as a list.
- **E4 · The Slicer and Honest Degradation** — BYOK behind the sealed egress, Rescue Mode, and seven plain reasons when the AI half is unavailable.
- **E5 · From a Personal Project to Its First Card** — photo or typed genesis under per-scan consent, plus cluster curation in its three homes.
- **E6 · Letting Go Without Guilt** — purge first, two detachment questions, three equal destinations, a blind Quarantine Box.
- **E7 · Seeing What I Did** — equal plates, a deletable local album, and a dashboard no denominator can turn into a quota.
- **E8 · The One Silent Invitation** — one opt-in notification that is structurally incapable of escalating.
- **E9 · My Data, My Copy** — silent generational export and full restore; the format that earns the name *restore*.

**Story index** (story titles are load-bearing; FR homes are in the Coverage Map below):

| Epic | Stories | FRs covered |
|---|---|---|
| E1 | 1.1 sealed scaffold · 1.2 tokens, glyphs, ARB · 1.3 insert-only substrate · 1.4 one calendar · 1.5 Evergreen catalogue · 1.6 the 1-3-5 weave · 1.7 zone rotation · 1.8 one card on screen · 1.9 `Hecho` · 1.10 the skip half · 1.11 no-overdue proof | FR-1, 2, 3, 11 *(Evergreen)*, 12, 14, 31 *(catalogue)* |
| E2 | 2.1 Time Bag + way into Settings · 2.2 declared pocket + derived session · 2.3 pause · 2.4 checkpoint · 2.5 ambient strip + check-in · 2.6 weekly self-report · 2.7 Warm Return | FR-4, 6, 7, 8, 9, 10 |
| E3 | 3.1 recognition availability probe · 3.2 Manual Capture · 3.3 the capture returns · 3.4 dictation | FR-27, 32 |
| E4 | 4.1 model harness · 4.2 egress seal · 4.3 credential vault · 4.4 port + allowlist · 4.5 honest degradation · 4.6 Rescue Mode | FR-5, 28, 29 |
| E5 | 5.1 face gate · 5.2 camera entry · 5.3 consent + scan lifecycle · 5.4 genesis · 5.5 buffers · 5.6 curation's three homes · 5.7 seasonal suggestion | FR-11 *(Epic)*, 13, 15, 16, 25, 31 *(curation)* |
| E6 | 6.1 purge first · 6.2 detachment questions · 6.3 three destinations · 6.4 Quarantine Box · 6.5 declutter metric | FR-19, 20, 21, 22 |
| E7 | 7.1 Before/After · 7.2 Transformation Album · 7.3 impact dashboard | FR-17, 18, 23 |
| E8 | 8.1 one silent channel · 8.2 one per domestic day + boot | FR-24 |
| E9 | 9.1 four series · 9.2 generational export · 9.3 restore + property test | FR-26, 30 |

---

## Coverage completeness

Checked by hand against the inventory tables on 2026-08-27 — no tooling exists in the greenfield repo yet, and a `tool/` id-coverage check over the story sections is owed to NFR20 when the scaffold lands:

| Inventory | Covered | Note |
|---|---|---|
| **FR-1 … FR-32** | **32 / 32** | FR-11 and FR-31 are each split across two epics, declared in the coverage map |
| **NFR1 … NFR20** | **20 / 20** | Build-wide constraints; four are *established* by Epic 1 and inherited thereafter |
| **AD-1 … AD-26** | **26 / 26** | Every architectural invariant is cited by the story that must honour it |
| **UX-DR1 … UX-DR62** | **58 / 62** | The four exceptions are listed below |

**Four UX-DRs deliberately have no story, and that is the correct outcome rather than an omission:**

- **UX-DR54 `[OPEN]` — the "plates but not the meal" copy** (PRD OQ-12). The record poses it as *"does any copy explain this, and where would it live?"* — so the surface is itself part of the open question. Assigning it to a story would invent the answer to the half that is actually open. It stays unassigned until the copy decision is taken, and it gates nothing.
- **UX-DR60 `[DEFERRED]` — system chroma.** A judgement to be made in situ once the app is on a handset, with a stated lever if it reads as too present. There is nothing to build.
- **UX-DR61 `[DEFERRED]` — `short-date` past a year.** Cannot bite inside a four-week window; the ambiguity it describes arrives twelve months after the first album entry.
- **UX-DR62 `[DEFERRED]` — the second locale.** Covered by construction: every string is already externalised in one flat table, so a second locale is translation rather than redesign.

**One class of correction from this pass:** a UX-DR renumbering left three story citations pointing at old numbers; all three are corrected — re-verify citations against subject text after any renumbering.

**Implementation checks that gate story completion.** All copy and surface decisions are closed in the UX spine pair. The two checks below require their named implementation evidence.

| Item | Source | Blocking story | Closure owner |
|---|---|---|---|
| Zone-marker 24px readability on device | UX-DR28 / `DESIGN` implementation check | 1.8 | builder, on handset in light and dark mode |
| Seed-glyph pompom radius | UX-DR10 / `DESIGN` implementation check | 1.2 | builder, record exact drawn value within the coverage constraint |

## Step-4 validation record

Every check the validation step mandates was run against the written stories rather than asserted. Four **real forward dependencies** were found and fixed by reordering or by moving acceptance criteria across a story boundary — each one a case where a story could not have been completed by a single agent working in sequence.

| Found | Why it was a defect | Fix applied |
|---|---|---|
| The catalogue story needed the ARB | Catalogue task names are ARB entries keyed by id (AD-16), but the ARB, its lint and its generated accessors arrived three stories later | The tokens-and-string-table story moved from **1.7 to 1.2**; the rest of Epic 1 shifted down |
| The capture surface needed the pool insert | `Guardar` cannot complete without writing a pool fact, which sat in the next story | The pool-fact insert moved from **3.3 into 3.2**; 3.3 is now purely about how the capture comes back |
| Rescue needed the degradation surface | FR-5's no-Slicer path degrades per FR-29, whose surface was built one story later | **4.5 and 4.6 swapped** — degradation now precedes rescue |
| The scan surface needed the consent token | AD-8 makes a `ScanConsent` a compile-time precondition of upload, so the wait and the slice outcome could not exist before the token | The upload, the wait and the slice outcomes moved from **5.2 into 5.3**; 5.2 now ends at the face gate, and both stories were retitled to match |

**Two findings that are not defects in this document but are worth carrying forward:**

1. **A `shipped` Evergreen task's Origin Context was undefined, and FR-5 needs one to re-slice — decided 2026-08-27: its Spanish catalogue name, one line, exactly the Manual Capture shape (debt 4, paid).** Story 4.6 is where it bites.
2. **One acceptance criterion in Story 1.11 is vacuous until Epic 5.** Its *"no milestone is in an overdue state"* clause has no milestones to check while Epic Projects do not exist. It is not wrong and it costs nothing — Story 5.5 tests the same property for real once buffers exist — but a reader should not mistake the Epic 1 pass for evidence about buffers.

**Checks that passed without change:** FR coverage (32/32 with the two declared splits); Story 1.1 is a scaffold story, not a template clone; both stores land in one story because Epic 1 genuinely needs both, later epics adding fields additively under AD-23; ports declared by first consumer; epic independence in both directions; and `core/weave` overlap answered by AD-20's candidate-precedence extension point (rationale in the Epic List).

## Upstream debts — all four paid, 2026-08-27

Recorded here so they are not carried in anyone's head. All four were created by passes on 2026-08-27 and **paid the same day**; the register stays because Stories 2.6 and 4.6 implement the decisions and cite this reasoning.

1. **PRD OQ-1's test venue — PAID (PRD changelog, 2026-08-27).** The development machine first, through Lemonade's OpenAI-compatible endpoint, as a cheap kill filter; the handset only if quality passes. OQ-1 itself stays open — only venue, candidate set and method are settled.
2. **E2B as the preferred local candidate — PAID (PRD changelog + the spine's Stack table, 2026-08-27).** The Stack table's Gemma rows are split E2B/E4B; E2B's Android size remains to be read off the model card when OQ-1's test runs; E4B's 3.66 GB / ~3283 MB figures stay E4B's.
3. **AD-4's Week clause — PAID (spine surgical update, 2026-08-27).** AD-4 now carries the persistence reading as a recorded override, both forced consequences included: a pending report is **superseded at the next Sunday, never accumulated**, and `report_answered` **carries the week it answers** (AD-21's vocabulary line updated to match). Nothing upstream still states the Sunday-only reading. Story 2.6 implements all three.
4. **A `shipped` Evergreen task's Origin Context — PAID (PRD §3 + FR-5, and the spine's AD-16, 2026-08-27).** Its **Spanish catalogue name** — one line of text, exactly the shape a Manual Capture's is; name-plus-zone, a pre-authored per-entry rescue and not-rescuable were each rejected on the record. No schema change: the name is an ARB entry keyed by id, resolved at load time by AD-21's named shell loader and handed to the core as inert data. Story 4.6 implements it.

---

## Epic 1: The Day That Deals Itself

A fresh install — in airplane mode, with no key, no account and no model — puts one household Micro-task on screen within two seconds and lets the user complete it or pass on it. This is the vertical slice that proves the paradigm: the pure-Dart functional core, the insert-only substrate, the one calendar authority, the shipped catalogue, the 1-3-5 weave and the Dispenser surface.

**FRs covered:** FR-1, FR-2, FR-3, FR-11 *(Evergreen half)*, FR-12, FR-14, FR-31 *(catalogue half)*

**Scope notes carried into the stories, so no story has to rediscover them:**

- **The session arrives here as a log fact, not as a feature.** AD-3 makes `session_started` the writer of a session's first `card_dealt`, and AD-24 defines an eligible day as one on which at least one session started. Without both, nothing is ever dealt and no day is ever eligible — which would break Epic 3's capture window at the origin. So Epic 1 opens a session on app entry and closes it on backgrounding. FR-8's declared pocket, FR-9's pause and FR-10's checkpoint stay in Epic 2, and the pocket field is added to `session_started` there, additively, under AD-23.
- **Only the ports this epic consumes are declared** — `Clock` and `Store`. The remaining five (`Slicer`, `Notifier`, `Recognizer`, `Folder`, `Files`) arrive with their first consumer, per the create-only-what-the-story-needs principle.
- **Epic 1 runs on defaults.** The Time Bag sits at its 15-minute default and energy at 🟢, with no surface to change either; Epic 2 makes both settable. The weave takes them as inputs from the first line, so this is additive rather than a rewrite.
- **The root `Makefile` is created in Story 1.1 and grows additively (NFR20).** It cannot invoke checks that do not exist yet — the catalogue floor arrives in 1.5, the egress seal in Epic 4 — so 1.1 lays down the development loop and the `gate` target, and **every later story that introduces a `tool/` check or build-time guard registers its target in the same pass.** That way the file is useful from the first story rather than assembled at the end. AD-18's release-ritual targets (build, install-on-top, export, import) are owed by Epic 9, where the export and import they drive actually land.
- **`Otra más fácil / Ahora no` ships with its final string and only its skip half wired.** `Ahora no` is FR-3 and belongs here; `Otra más fácil` is FR-5's Rescue Mode and arrives in Epic 4. The control is a shared component completed across two epics — the same pattern as the ambient strip and Settings — not a forward dependency, and not a defect to file.

**Implementation notes:** establishes the greenfield scaffold (`packages/core` + shell + `tool/` + `assets/evergreen/`), the seven ports of which only `Clock` and `Store` are consumed here, AD-2's SQL triggers declared in `.drift` and created in the initial migration, AD-4's `Calendar`, AD-21's full log vocabulary, and AD-20's resolver as the extension point later epics feed. Ships `tokens.dart`, the `dispenser-card`, `action-primary`, the unsplit `action-secondary`, `duration-chip` and `zone-marker`. Four `tool/` checks land here — core purity, the catalogue floor, the catalogue id diff and the no-literal-strings lint — plus the forbidden-vocabulary lint and the 28-deal rotation test. FR-14 is discharged as a proven property, not code.

### Story 1.1: The sealed scaffold

As a builder,
I want the project to stand up as a pure-Dart core inside a Flutter shell with the core's purity enforced by a machine check,
So that every invariant the product rests on is checkable from the first commit instead of trusted to review.

**Acceptance Criteria:**

**Given** a fresh clone
**When** `dart test` is run inside `packages/core`
**Then** it executes with no emulator
**And** no `flutter`, `drift` or plugin dependency is resolved for that package

**Given** any file under `packages/core/lib/`
**When** a commit adds an import of `package:flutter/…`, `drift` or any plugin
**Then** the `tool/` core-purity check fails the build and names the offending file (AD-5)

**Given** any file under `packages/core/lib/`
**When** a commit introduces `Random`, a wall-clock read, `dart:io` or ambient state
**Then** the same check fails the build (AD-3, NFR16)

**Given** the port declarations
**When** `packages/core/lib/ports/` is inspected
**Then** exactly two ports exist — `Clock` and `Store` — each named with the `Port` suffix
**And** no adapter type is named anywhere inside the core (AD-5)

**Given** the Android configuration
**When** the app is assembled
**Then** `minSdk` is 33, `targetSdk` is 36
**And** `abiFilters` excludes every 32-bit ABI (NFR12)

**Given** `pubspec.yaml`
**When** its dependencies are read
**Then** Flutter 3.47.1 / Dart 3.13.1 and the pinned versions of the Stack table are used
**And** neither `material_ui` nor `cupertino_ui` is added

**Given** the test strategy
**When** it is set up
**Then** core invariants run under `dart test` on the machine with no emulator; widget tests exist **only where a surface consumes the read facade or a command**; and **no golden tests are written** — visual and behavioural verification is manual on the three validation handsets (NFR18)

**Given** the repository root
**When** it is listed
**Then** a `Makefile` exists carrying every command needed to work on the app in development, and no development operation requires a remembered incantation (NFR20)

**Given** the `Makefile`
**When** `make help` is run
**Then** it lists every target with a one-line description, and it is the default target so a bare `make` is never destructive

**Given** the `Makefile`
**When** `make gate` is run
**Then** it runs exactly `flutter test`, `dart format --set-exit-if-changed .` and `flutter analyze`, failing on the first that fails
**And** it is the single command that answers NFR17's story completion gate

**Given** the development loop
**When** the targets available at this story are used
**Then** `make deps`, `make test`, `make test-core` (pure `dart test` over the core, no emulator), `make format`, `make format-check`, `make analyze`, `make check` (the `tool/` checks that exist), `make run` and `make clean` all work

**Given** CI
**When** it verifies a commit
**Then** it invokes the same `Makefile` targets rather than duplicating their command lines, so a green `make gate` locally means a green CI

**Given** a later story that introduces a `tool/` check or a build-time guard
**When** that story is complete
**Then** its target is registered in the `Makefile` and reachable from `make check` in the same pass (NFR20)

**Given** the story is complete
**When** the completion gate runs
**Then** `flutter test`, `dart format --set-exit-if-changed .` and `flutter analyze` are all green (NFR17)

### Story 1.2: Both palettes, the glyph set and the single string table

As a builder,
I want one file of tokens and one table of strings, both enforced by lints,
So that the anti-shaming audit can be read as a flat table and no surface built later can smuggle in a literal.

**Acceptance Criteria:**

**Given** `DESIGN.md`
**When** its tokens are transcribed
**Then** `lib/ui/tokens.dart` holds them once as named constants — 6 field colours, 6 icon-mass colours, 11 dark-mode colours, 8 typography roles, 3 radii, 14 spacing values and the 2 format rules
**And** no literal token value appears anywhere else (UX-DR1)

**Given** any widget
**When** a string literal reaches it
**Then** a lint fails the build — `lib/l10n/app_es.arb` is the single table and `lib/strings/` holds generated accessors only (AD-15, NFR7)

**Given** any user-facing string
**When** it is assembled
**Then** no sentence is produced by runtime concatenation; a number substituted into a fixed sentence is permitted and a sentence built from fragments is not (AD-15)

**Given** any user-facing text widget
**When** the text-scaling lint runs
**Then** it fails on `maxLines`, `TextOverflow.ellipsis`, `FittedBox`, a `TextScaler`/`textScaleFactor` override, or a fixed-height container around text — all five (UX-DR45, NFR6)

**Given** the type ramp
**When** roles are applied
**Then** the task text is Lora and all seven other roles are Lexend, every size in `sp` with multiplier line-heights (UX-DR5)

**Given** the shipped ARB
**When** the SM-C2 audit list is produced
**Then** it is every key in the table minus an explicit reviewed exclusion list, so silence adds a string to the audit rather than omitting one (AD-15)

**Given** the two colour tiers
**When** they are transcribed
**Then** the field tier sits at Aliento's baseline for grounds, cards, text, hairlines, the chip and the primary action, and the icon-mass tier sits at **L\* 76.0 exactly** for the colour plate inside a glyph **and nowhere else** — the two tiers never touch (UX-DR2)

**Given** the dark palette
**When** it is transcribed
**Then** all eleven dark tokens land as **a separately authored palette, never an inversion**: the dark mass tier at L\* 62 / chroma ~13, `ink-secondary-dark` **assigned** as the dark secondary ink covering `action-secondary`, `support` and the zone-marker line, and `border-strong-dark` **deleted** as an orphan because `border-hairline-dark` covers every dark edge (UX-DR12)

**Given** light and dark
**When** the theme is selected
**Then** it **follows the system, with no settings row** — an override row would be the app's only duplicated preference, and everything unstated is the platform's (NFR19)

**Given** the glyph set
**When** it is established
**Then** ten glyphs exist — Cámara, Álbum, Caja, Bolsa, Reloj, Hoja, Lápiz, the dandelion seed, the batería and the Micrófono capsule — with utility glyphs carrying `icon-mass-neutral`
**And** **no Ajustes glyph exists**: it is dissolved by decision, because Settings is reached as quiet text and no drawing ever needs to read as "settings" (UX-DR11)

**Given** screen-reader behaviour
**When** a surface is built
**Then** the interim convention holds so that no surface-builder invents one: **no custom semantics, no manual announcements, platform traversal order** — TalkBack labels, roles and traversal order are `[OPEN]` per UX-DR48 and are revisited before the first surface ships to a handset other than the builder's

**Given** any string entering the table
**When** it is reviewed
**Then** it is checked against the Voice-and-Tone do/don't table — name the cost before the ask, say what happened rather than congratulate volume, never ask `¿seguimos?`, never frame degradation as fault, never correct what the user typed, leave the missed days unmentioned, no exclamations except `¡Buen trabajo!` after `Hecho`, no adjective about a result, and no figure with a denominator (UX-DR55)

### Story 1.3: The insert-only substrate

As a builder,
I want the pool and the event log to be the only two persisted stores, with the database itself refusing every rewrite,
So that the no-overdue guarantee rests on a trigger rather than on nobody reaching for `UPDATE`.

**Acceptance Criteria:**

**Given** the initial migration
**When** it has run
**Then** exactly two tables exist — the task pool and the event log
**And** each carries SQL triggers, declared in a `.drift` file, that raise on `UPDATE` and on `DELETE` (AD-2)

**Given** either table holds a row
**When** an `UPDATE` or `DELETE` is attempted against it by any code path
**Then** the statement raises and the row is unchanged

**Given** a pool fact
**When** it is inserted
**Then** it carries an id minted in the shell as UUIDv7, an immutable origin of `shipped` / `manual` / `local` / `cloud`, a size from the 1-3-5 taxonomy enum, and its creation instant **plus the local offset in force** (AD-14, AD-4)
**And** no date-only column exists anywhere

**Given** a log entry
**When** it is inserted
**Then** it carries its kind, its UTC instant plus the local offset in force, and — where it references a pool item — that item's origin (AD-4, AD-14)

**Given** the entry vocabulary
**When** the log's kinds are enumerated
**Then** user acts and system events live in the one table under the same triggers
**And** the kinds this epic writes are present: `card_dealt`, `card_done`, `card_skipped`, `session_started`, `session_ended`, `app_opened` (AD-21)

**Given** an uncaught Flutter or platform error
**When** it occurs
**Then** a `crash_recorded` entry is appended carrying the stack and the timestamp and nothing else — no task text, no image path, no prompt, no URL — via a handler the shell installs at startup, the only diagnostics destination in a build with no logging framework (NFR13, AD-12, AD-21)
**And** its sole readers are `core/export` and the FR-26 series, per AD-21's system-events rule; Story 9.2's `derived/` crash log renders it

**Given** a derivation meets a log entry of a kind it does not know
**When** it processes the stream
**Then** it skips that entry and continues, never coercing it and never failing (AD-23)

**Given** any identifier in the codebase
**When** the forbidden-vocabulary lint runs
**Then** it fails on `overdue`, `late`, `missed`, `pending`, `debt`, `streak`, `skippedCount`, `dueDate` or `backlog`
**And** `Due` as a derived-fact suffix is permitted (NFR9)

**Given** either table's columns
**When** they are inspected
**Then** **neither carries an owner column** — all local data is account-free and single-user throughout, and multi-user remains a knowingly accepted schema change (NFR10)

**Given** any persistence API call outside `Store`
**When** the `tool/` store seal runs
**Then** the build fails — no third replayable domain store may exist (AD-21)

### Story 1.4: One calendar authority

As a builder,
I want a single place that converts an instant into a period,
So that every rule in the product that says "day" means the same day, and two units cannot implement two clocks.

**Acceptance Criteria:**

**Given** the core
**When** any code needs a day, week or season
**Then** it calls the one `Calendar` in `packages/core/lib/day/`
**And** no other code — Kotlin included — computes a date boundary (AD-4)

**Given** an instant
**When** its day is computed
**Then** the day is the half-open period `[04:00 local, 04:00 local next)`

**Given** a log entry written in one zone offset and read in another
**When** its day is computed
**Then** the computation uses **the offset stored on the entry**, never the device's current zone
**And** travel or a user correcting the clock never re-dates history

**Given** a DST transition inside a period
**When** the period is computed
**Then** no day, week or season is created or destroyed by the transition

**Given** a week
**When** its boundary is computed
**Then** it is seven domestic days anchored on Monday

**Given** a season
**When** its boundary is computed
**Then** it is a three-month meteorological quarter falling on domestic-day boundaries

**Given** a day boundary
**When** energy is derived for the live pool
**Then** it is the last `energy_set` of the current domestic day, defaulting to 🟢 at each boundary
**And** the default is derived, never written — no synthetic `energy_set` row exists at a boundary

### Story 1.5: The shipped Evergreen catalogue

As Sergio,
I want the app to arrive already knowing a month of household work,
So that a fresh install in airplane mode, with no key and no model, already has a varied day to deal from.

**Acceptance Criteria:**

**Given** the build
**When** `assets/evergreen/` is read
**Then** it holds a versioned, read-only data file
**And** each entry carries exactly four fields: a permanent id, a size from the 1-3-5 taxonomy, a cadence, and a zone-or-none (AD-16)

**Given** a catalogue entry
**When** its Spanish name is needed
**Then** the name comes from an ARB entry keyed by the entry's id — **the name is not in the asset** — so catalogue copy is audited on the same terms as every other string (AD-15, AD-16)

**Given** the catalogue
**When** the three cadences are counted
**Then** all three are populated: daily (Instant Habits ~30 s and Baseline Upkeep 3–15 min), weekly (zone routines across five FlyLady zones), and monthly/seasonal (`fondo`)

**Given** the catalogue
**When** the `tool/` floor check counts distinct 10–15 min **non-daily** entries
**Then** the count is at least 28, and the build fails below it
**And** 3-minute entries are excluded from the count, because they can never occupy the Focus Chunk slot (FR-31, AD-16)

**Given** any catalogue entry
**When** it is inspected
**Then** it carries no hour, no mealtime and no dependency on another task (FR-31, §5.2)

**Given** the previous release's id set
**When** the `tool/` id-diff check runs
**Then** the build fails on any id that disappeared or whose size changed, because `card_dealt` rows reference them (AD-23)

**Given** no previous release exists — the greenfield build
**When** the id-diff check lands
**Then** its failure mode is proven anyway: a checked-in v0 id-set fixture with a deliberately mutated copy fails the self-test and names the mutated id, so the check has fired at least once before the first real release exists (AD-23)

**Given** a phone in airplane mode on day one
**When** the app is opened
**Then** the whole Evergreen Library is present and a composition is built from it — the shipped day is exempt from the network because it was **sliced at build time rather than at runtime**, and airplane mode is a supported condition, never an error state (NFR1, FR-11)

**Given** the user
**When** any surface in the app is reached
**Then** no screen enumerates individual catalogue entries — curation is at cluster level only, and its surfaces arrive in Epic 5 (FR-31)

### Story 1.6: The 1-3-5 weave and the Focus Chunk slot

As Sergio,
I want the app to compose today by itself and hand me one task at a time,
So that I never choose from a list and never see what is waiting.

**Acceptance Criteria:**

**Given** a pool, a log and a domestic day
**When** the day is composed
**Then** `core/weave` returns 1 Focus Chunk (10–15 min) + 3 Micro-maintenance + 5 Instant Habits, scaled to the Time Bag's default and the derived energy
**And** no plan is stored anywhere — the composition is a pure function of `(pool, log, day, session)` (AD-1)

**Given** the read facade
**When** its surface is inspected
**Then** no function returns a collection of pending or captured tasks, `nextCard()` returns at most one card, and derived signals are named as facts rather than actions (AD-6, FR-1, NL-1)

**Given** the app is opened
**When** entry is handled
**Then** `app_opened` and `session_started` are appended, and `session_started` writes the session's first `card_dealt` (AD-3)
**And** the session closes with `session_ended` when the app is backgrounded (AD-19)

**Given** a dealt card the user has not answered
**When** the surface is rendered again
**Then** `nextCard()` has written nothing — a card the user never answered leaves no second `card_dealt` (AD-3)

**Given** two candidates that tie
**When** the resolver orders them
**Then** the tie breaks by least-recently-dealt, then by stable id, reading recorded act instants and never id bit patterns (AD-3)

**Given** any source of work — the active Epic, the active zone, `fondo`, a capture, a purge step, a rescue step
**When** it offers work
**Then** it returns **candidates with precedence** and `core/weave` is the only code that emits a deal (AD-20)

**Given** a day whose Focus Chunk has been answered `Hecho`
**When** a further deal is requested that day
**Then** no second Focus Chunk is dealt — occupancy is once per domestic day, closed only by a `card_done`, and the slot belongs to the day the dealing session belongs to (AD-19, AD-20)

**Given** a Focus Chunk the user skipped
**When** the next deal resolves
**Then** identity re-resolves to a different candidate, the slot stays open, and no rotation is consumed (AD-20, FR-3)

**Given** the Time Bag's default is below 10 minutes
**When** the day composes
**Then** it composes with no Focus Chunk at all, silently, with no debt and no mention anywhere (FR-7, FR-12)

**Given** Baseline Upkeep entries that fit the Focus Chunk's size
**When** the slot resolves
**Then** Baseline Upkeep never occupies it — the slot is reserved for advance work (FR-12)

### Story 1.7: Zone rotation, `fondo` fill and the below-floor fallback

As Sergio,
I want the app to move through my home week by week without ever repeating itself while it still has something new,
So that twenty-eight days of work never feel like the same four tasks.

**Acceptance Criteria:**

**Given** a domestic week
**When** the active zone is derived
**Then** exactly one FlyLady zone is active per day, rotating weekly over the **active** clusters only
**And** the week of a disabled zone passes to the next active zone, so curation never leaves a day without an active zone (FR-11, FR-31)

**Given** an active zone whose own 10–15 min entries are exhausted within its week
**When** the Focus Chunk slot resolves
**Then** the `fondo` cluster fills the gap **before any repetition** (FR-31)

**Given** the default curation state
**When** 28 Focus Chunks are dealt and answered
**Then** a core test asserts no Micro-task repeats across those 28 deals (AD-16)

**Given** a 🔴 day
**When** the day composes
**Then** no Focus Chunk is dealt and no rotation is consumed — the floor counts answered deals, not calendar days (FR-31, FR-4)

**Given** curation has dropped the eligible pool below the floor
**When** the slot resolves
**Then** the fallback runs in the stated order: the zone's own entries, then `fondo`, then the least-recently-dealt eligible entry regardless of zone — repetition, accepted and visible in the export, never an empty day (AD-20)

**Given** a cluster curation change
**When** it takes effect
**Then** weekly zones change at the **next week boundary** and daily and `fondo` clusters change **immediately** (AD-16)
**And** the next-week-boundary rule **supersedes FR-31's literal *simply never appear*** for weekly zones — the rotation argument is the zone's — recorded as a declared, reasoned override on AD-17's pattern so a later reader does not "correct" it to immediate effect (AD-16, FR-31)

**Given** every cluster disabled by curation
**When** the day composes
**Then** the day composes with no deals and any session closes immediately carrying `por hoy no hay nada más que merezca la pena` — the same empty-pool close as FR-3, never an error and never styled as debt, with Settings as the way back (FR-3, FR-31)

### Story 1.8: One card on screen

As Sergio,
I want to open the app and see exactly one task with what it will cost me,
So that I know the one thing to do now and there is nothing else to read.

**Acceptance Criteria:**

**Given** a cold start
**When** the app opens
**Then** one dispensed Micro-task is on screen within 2 seconds
**And** there is no splash screen and no loader before the first card (NFR5, UX-DR41)

**Given** the Dispenser
**When** it is rendered
**Then** it shows the `duration-chip` as an eyebrow 8dp above the task, the task in Lora, `action-primary`, `action-secondary` as plain text, and the `zone-marker` as a quiet footer (UX-DR14)
**And** the `zone-marker` is the Hoja at 24px with an `ink-secondary` line and `icon-mass-ochre` mass in `support` type — a place-marker, **not a control**: it is not a filter and it opens nothing (UX-DR28)

**Given** any screen reachable in under three taps from the Dispenser
**When** it is rendered
**Then** it never shows more than one actionable Micro-task at once (FR-1)

**Given** the card
**When** the system font scale is 200%
**Then** nothing is ellipsized or truncated: the card grows into its air — a minimum 48dp plus flex, never a fixed value — and the screen scrolls (UX-DR14, NFR6)

**Given** the card
**When** its surface is inspected
**Then** it separates from the ground by tone and a 1px hairline, with no shadow, gradient or glow anywhere (UX-DR6)

**Given** a dealt card
**When** it is displayed
**Then** its estimated duration is always shown (FR-1)
**And** its origin tag is never surfaced (AD-14)

**Given** the Dispenser
**When** the user looks for pending work
**Then** no list, calendar, backlog, counter, streak, badge or overdue indicator exists on it or anywhere reachable from it (UX-DR44)

### Story 1.9: `Hecho`

As Sergio,
I want to finish the task with one tap and have the card leave,
So that the thing is done, that is enough, and the next one is already there.

**Acceptance Criteria:**

**Given** a dealt card
**When** the user taps `Hecho`
**Then** `card_done` is appended and the next card arrives in under 500 ms (FR-2, NFR5)

**Given** the completed card
**When** it leaves
**Then** it **exits the screen entirely** and never flies toward a counter, a pile or a badge (UX-DR38)

**Given** completion
**When** feedback is given
**Then** it is a small warm haptic acknowledgement accompanied by something visible — haptics are never the sole signal
**And** it is never modal, never plays loud audio, and never spawns a rating prompt or a nag screen (FR-2, NFR6)

**Given** completion
**When** the celebration plays
**Then** it is identical every time — no combo, no streak, no "you're on three" — and it **closes** rather than opening a door to another (UX-DR39)

**Given** the celebration
**When** the next card is ready
**Then** the celebration may overlap its arrival but never delays it past 500 ms (UX-DR39)

**Given** a `Hecho` on a Focus Chunk
**When** the slot is evaluated
**Then** occupancy closes for the day that card's dealing session belongs to, and for no other day (AD-19, AD-20)

**Given** `action-primary`
**When** it is rendered
**Then** it is full-width, 14px, filled `accent-soft` with `ink-primary` label at 11.96:1, minimum height 48dp, and 32dp below the task as the largest interior gap (UX-DR16)

**Given** the `Hecho` confirmation's visible copy
**When** this story is planned
**Then** it is `¡Buen trabajo!`, the explicit narrow exception to the exclamation-free rule; it acknowledges completed effort, carries no quantity and suggests no further work (UX-DR51)

### Story 1.10: The unsplit secondary control — the skip half

As Sergio,
I want to pass on a task with one tap and get a different one,
So that not doing this particular thing right now costs me nothing and is recorded nowhere.

**Acceptance Criteria:**

**Given** a dealt card
**When** the user taps `Otra más fácil / Ahora no`
**Then** `card_skipped` is appended, a different candidate is dealt, and no failure is recorded (FR-3)

**Given** a skip
**When** the system state is inspected afterwards
**Then** no overdue state, no counter and no notification exists
**And** no cumulative skip total is stored anywhere — a skip count is a debt record with a different name (FR-3, FR-26)

**Given** a skip
**When** the alternative is resolved
**Then** it respects the derived energy and the remaining Time Bag budget, and consumes no rotation (FR-3, AD-20)

**Given** the eligible pool runs out mid-session
**When** the session closes
**Then** it closes early carrying the fixed string `por hoy no hay nada más que merezca la pena` — never an error, never an empty state styled as absence or debt (FR-3)

**Given** the control
**When** it is rendered
**Then** it is **text only** — no box, no fill, no underline, no animation — in `ink-secondary`, with a 48dp touch target, available and never suggested (UX-DR17)

**Given** the string at 200% font scale
**When** it folds
**Then** the fold is accepted and the string is never split, shortened, ellipsized, hard-broken or non-breaking-spaced
**And** the fold is verified on a real Android device, because the original measurement was taken in a different line breaker (UX-DR17)

**Given** the control carries two product features
**When** this story is complete
**Then** only `Ahora no`'s skip behaviour is wired; `Otra más fácil`'s re-slice arrives with FR-5 in Epic 4, and this is a shared component completed across two epics rather than a defect

### Story 1.11: Proof that lateness cannot be expressed

As a builder,
I want the absence of overdue to be a machine-checked property of the substrate rather than a promise,
So that the next person to touch the schema does not have to have read the principles.

**Acceptance Criteria:**

**Given** the whole persisted schema and every derived read model
**When** they are inspected by test
**Then** no field, flag or derived value expresses lateness, debt or a missed occurrence (NFR9, §7)

**Given** the codebase
**When** a search for a Silent Rescheduler is made
**Then** none exists — nothing was assigned to a future day, so nothing needs re-planning, and FR-14 is discharged by the substrate's shape rather than by code (AD-1, FR-14)

**Given** a user absent for seven consecutive days
**When** the app is next opened
**Then** the day composes normally, no milestone is in an overdue state, and no UI element or string references the missed days (FR-13, FR-6, FR-14)

**Given** a deferred Focus Chunk
**When** the next day composes
**Then** it is simply a candidate again — no visible target moved, because no target was stored (FR-14, AD-1)

**Given** the log
**When** any entry is examined
**Then** no entry asserts an absence or an obligation (AD-21)

**Given** a completion
**When** completion counts are derived
**Then** every count counts user acts only — no synthetic completion is ever appended (AD-25)

**Given** the story is complete
**When** the completion gate runs
**Then** `flutter test`, `dart format --set-exit-if-changed .` and `flutter analyze` are all green (NFR17)

---

## Epic 2: How Much the App Asks of Me

The user sets the minutes they are willing to give a day, declares the pocket of time they actually have right now, stops with one tap at any moment, asks for less on a low day, and comes back after an absence with nothing to catch up on. Everything in this epic narrows what the app requests; nothing in it adds work.

**FRs covered:** FR-4, FR-6, FR-7, FR-8, FR-9, FR-10

**Scope notes:**

- **Settings is reached through a surface whose other half arrives in Epic 5.** UX-DR25 sites Settings as the text way-out *inside* the `Nuevo proyecto` affordance, whose recommended action is typed project genesis — and genesis needs the Slicer, which is Epic 4. So this epic builds the affordance and Settings behind it, carrying the way out alone; Epic 5 adds typed genesis as that surface's recommended action. This is a build-order intermediate state, not a declared exception to principle 1: nothing ships until later epics land, and Epic 2's own domain — setting the Time Bag — is complete and reachable.
- **The session already exists as a log fact from Epic 1.** This epic adds the *declared pocket* to `session_started` (additively, under AD-23), `session_extended`, the pause semantics and the checkpoint. Epic 1's open-on-entry / close-on-background behaviour stays and gains the other two closing causes.
- **The SM-2 window persists until answered — FR-4's reading, chosen 2026-08-27 and now carried by AD-4 itself as a recorded override (debt 3, paid): a pending report is superseded at the next Sunday, never accumulated, and `report_answered` carries the week it answers.** The reasoning is the instrument's fragility — SM-2 yields only four data points across the whole validation window, and it measures the product premise. Story 2.6 implements all three and tests the deterministic slot handoff. **(a) A pending report is superseded at the next Sunday, never accumulated** — otherwise two reports are pending at once and an answer cannot be attributed to a week. The superseded week simply has no data point, which is where SM-2's *"a week with no answer"* consequence survives. **(b) `report_answered` must carry the week it answers, not merely its instant.** Under AD-4's reading the instant sufficed, because an answer always fell inside the week it belonged to; under persistence it does not, and without the explicit target week SM-2's week-4-versus-week-1 trend cannot be built at all.

**Implementation notes:** implements AD-19's derived session (no session of record; the day a session belongs to; the three closing causes) and AD-24's single `EligibleDay` predicate with its `warmReturnDue` sibling. Builds the `ambient-strip` with its first resident, the `energy-checkin` battery marks, and `icon-mass-blue` as the active-state hue. Builds the Settings shell plus the **Tu día** group. The FR-4 ↔ SM-2 slot handoff is deterministic and is tested as such in Story 2.6.

### Story 2.1: The Time Bag, and the way into Settings

As Sergio,
I want to say how many minutes a day I am willing to give the house,
So that the app asks me for an amount I chose rather than one it assumed.

**Acceptance Criteria:**

**Given** the Dispenser
**When** it is rendered
**Then** the quiet affordance `Nuevo proyecto` sits bottom-centred as ink-secondary text in the `action-secondary` pattern — never animated, never emphasised, never badged, and carrying no pastel mass (UX-DR25)

**Given** the affordance
**When** it is opened
**Then** Settings is reachable from inside it as a quiet text way-out
**And** Settings is the only route into the validator surface from any surface within three taps of the Dispenser (NFR3, AD-26)

**Given** Settings
**When** it is rendered
**Then** it is a flat platform list whose first group is **Tu día**, holding the Time Bag (UX-DR33)

**Given** the Time Bag
**When** the user sets it
**Then** it accepts a value inside 5–30 minutes, defaults to 15, and persists until changed
**And** changing it mid-day never invalidates completed work (FR-7)

**Given** a Time Bag change
**When** it is recorded
**Then** a `setting_changed` entry is appended, and the settings record is a **derived cache over those entries rebuilt at start** — never a source of truth, so "what the Time Bag was on day 5" is answerable from the log (AD-1)

**Given** a Time Bag below 10 minutes
**When** the day composes
**Then** it composes with no Focus Chunk, silently, with no debt, no mention and no budget-exhausted state anywhere (FR-7, FR-12)

**Given** the Time Bag
**When** what it pays for is examined
**Then** it covers **advance work only** — the Focus Chunk; Baseline Upkeep and Instant Habits are composed alongside it and charged nowhere (FR-7, FR-12)

**Given** the day's Focus Chunk has been answered `Hecho`
**When** a later session starts that day
**Then** it composes of upkeep and habits only, silently — chaining sessions cannot multiply advance (FR-7)

**Given** a mid-day Time Bag change
**When** the slot is re-evaluated
**Then** identity re-resolves and a closed slot is never re-opened (AD-20)

**Given** a mid-day Time Bag raise from below 10 minutes to 10 or more
**When** the slot is re-evaluated
**Then** a Focus Chunk composes iff none was dealt that day — a closed slot never re-opens, and an undealt one is freed by exactly this raise (AD-20, FR-7)

### Story 2.2: The declared pocket and the derived session

As Sergio,
I want to tell the app how long I actually have right now,
So that what it deals me fits the time I have instead of the time it wishes I had.

**Acceptance Criteria:**

**Given** the Dispenser
**When** the user declares a pocket
**Then** the trigger renders as a `duration-chip` carrying `Tengo 15 minutos ahora`, and the pool re-filters to what fits (FR-8, UX-DR18)

**Given** a declared pocket
**When** cards are dealt inside the session
**Then** their estimated durations sum to **≤ the declared pocket**, upkeep included (FR-8, FR-12)

**Given** the declared pocket
**When** it is accepted
**Then** it is a positive whole number of minutes inside 1–60; out-of-range input is refused by the trigger surface with no error state (FR-8)

**Given** a remaining pocket smaller than every eligible candidate's estimate
**When** the next deal resolves
**Then** no over-budget card is dealt: the session closes early carrying `por hoy no hay nada más que merezca la pena` — the same warm close as pool exhaustion (FR-8, FR-3)

**Given** a dealt card answered `Ahora no`
**When** the pocket sum is recomputed
**Then** only answered cards consume the pocket — a skipped card's estimate is released, and the alternative deal still fits the pocket (FR-8, FR-3)

**Given** the app re-opened after process death left a derived-open session
**When** `app_opened` is handled
**Then** any open session whose pocket elapsed closes at that instant **first**, and only then does a new `session_started` append — two derived-open sessions never coexist (AD-19)

**Given** the log
**When** the current session is derived
**Then** it is the latest `session_started` with no matching `session_ended`, and it **belongs to the domestic day of its own start instant** (AD-19)

**Given** a session that crosses 04:00
**When** the day boundary passes
**Then** the session neither ends nor resets the day's advance, and every `card_*` act of that session is charged to the session's own day as one ledger (AD-19)

**Given** a session that crossed 04:00
**When** the crossed-into day's Focus Chunk slot is evaluated
**Then** the session never occupies it, and the next day's slot resolves at the first deal after the session closes (AD-19, AD-20)

**Given** the user extends the session
**When** the extension is recorded
**Then** a `session_extended` entry is appended, and the declared pocket becomes `session_started`'s pocket plus the sum of its extensions (AD-19)

**Given** a session
**When** it closes
**Then** it closed for exactly one of three causes and no others: the user stopping, the declared pocket elapsing while the app is foregrounded, or the app being backgrounded (AD-19)

**Given** a pocket fully elapsed while the app was not foregrounded
**When** the app is next foregrounded
**Then** the session closes at that instant — the elapse is revealed, not awaited (AD-19)

**Given** the process died mid-session
**When** the app is opened again
**Then** the derived session is still open and the same foreground rule applies
**And** nothing held session state in memory as the source of truth (AD-19)

### Story 2.3: Pause, and the advance/upkeep split applied to it

As Sergio,
I want to stop in the middle of anything and have the app say nothing about it,
So that a life that interrupts me never turns into a state I have to clear.

**Acceptance Criteria:**

**Given** any moment in a session
**When** the user stops
**Then** it costs one tap, works for any reason, and no state exists in which stopping is unavailable (FR-9, UX-DR43)

**Given** the Time Bag
**When** its ledger semantics are inspected
**Then** it is a **daily ceiling derived from the setting, never a depleting wallet**: nothing is ever subtracted from it, so FR-9's *unspent advance minutes roll back into the Time Bag* is satisfied vacuously — there is nothing to return because nothing was spent — a declared reading recorded on AD-17/AD-20's pattern so no later reader implements an accumulator (AD-1, FR-7, FR-9)
**And** the day's advance ledger is three worked cases: bag 15 with pocket 10 — the chunk is dealt only if its estimate fits the pocket, else the day's advance waits for a fuller pocket; bag 5 — the day composes with no chunk at all, silently; bag 30 — the advance is still one chunk, and the surplus buys nothing, because upkeep and habits are charged nowhere (FR-7, FR-12)
**And** a session crossing 04:00 charges its advance to **its own start day's** slot, never the crossed-into day's (AD-19)

**Given** a paused or interrupted session
**When** any surface is rendered
**Then** no interrupted, incomplete or overdue state is displayed anywhere, in either language (FR-9, NFR9)

**Given** the user returns after pausing
**When** the Dispenser is rendered
**Then** it deals the next Micro-task directly — never a resume menu, never a summary, never anything about the past (FR-9, UX-DR41)

**Given** the recalculation after a pause
**When** it runs
**Then** it is silent and invisible: no toast, no banner, no announcement that a plan was rebalanced (FR-9)

### Story 2.4: The Anti-Marathon checkpoint as permission to stop

As Sergio,
I want the app to offer me rest instead of asking me to continue,
So that finishing a session never feels like giving up on something.

**Acceptance Criteria:**

**Given** a session longer than one checkpoint interval
**When** each multiple of the interval is reached
**Then** the permission-to-rest screen appears as the **primary surface**, and the offer repeats at every interval boundary — a 45-minute pocket with a 15-minute interval offers rest three times (FR-10)

**Given** the checkpoint interval
**When** it is configured
**Then** it defaults to 15 minutes inside a 10–15 range (FR-10, §10.1)

**Given** a domestic day of several sessions, each shorter than one checkpoint interval
**When** the interval multiples are computed
**Then** they read **cumulative same-day session time, not per-session elapsed** — chaining short sessions cannot dodge the rest offer, which is the concern FR-10 exists to carry (FR-10, AD-19)

**Given** the checkpoint arrives
**When** a card is in progress
**Then** that card can be finished, and the rest offer is never a wall (FR-10)

**Given** any surface anywhere in the app
**When** its strings are audited
**Then** no continuation question exists — no `¿seguimos?`, no variant of it, and "keep going" is never a primary action (FR-10, UX-DR44)

**Given** the extend-the-session action
**When** it is rendered
**Then** it is available, silent and secondary — never highlighted, never animated, never suggested (FR-10)

**Given** a session shorter than one checkpoint interval
**When** it ends
**Then** it reaches no checkpoint and its close **is** the permission to stop (FR-10)

**Given** a final checkpoint that coincides with the session's close
**When** the close is handled
**Then** that close is the offer — no manufactured second surface (FR-10, UJ-1)

**Given** a session the user chose to extend
**When** the comfortable-day predicate is derived
**Then** it reads the **original** pocket, so a chosen extension is never scored as a marathon (AD-19, FR-23)

**Given** the permission-to-rest copy and the extend action's presentation
**When** this story is planned
**Then** the primary message is `Nada más por el momento` and the available silent secondary action is `Quiero seguir` (UX-DR51)

### Story 2.5: The ambient strip and the daily energy check-in

As Sergio,
I want to be asked once a day how much I have in the tank, and to be able to ask for less,
So that a bad day makes the app quieter instead of making me feel behind.

**Acceptance Criteria:**

**Given** the Dispenser
**When** the strip is rendered
**Then** it sits below the `dispenser-card` as a sentence in `support` and `ink-secondary`, with a ✕ dismissal at 48dp, tappable where an accept action exists and never a primary action
**And** **at most one resident is visible at a time** (UX-DR22)

**Given** the strip's chrome
**When** a resident is rendered
**Then** ephemeral residents sit bare on the ground and persistent residents carry a 1px hairline — the energy check-in is bare (UX-DR22)

**Given** the day's first opening
**When** the strip resolves
**Then** the energy check-in appears carrying `¿Cuánta energía tienes hoy?` with three battery marks — llena / media / baja — as **three direct tap targets** and nothing else (FR-4, UX-DR20)

**Given** the battery marks
**When** they are drawn
**Then** each is a casing and nub line-only with the charge as a **registered mass filling from the left** at 12.8u / 6.4u / 3.2u in a 24 viewBox, carrying **no offset** — the documented registered exception (UX-DR9, UX-DR20)

**Given** a selected battery
**When** it is rendered
**Then** its charge is `icon-mass-blue` and its casing `ink-primary`; unselected charges are `icon-mass-neutral` with `ink-secondary` casings
**And** llena is pre-marked as the standing default (UX-DR4, UX-DR20)

**Given** the check-in has been answered or dismissed
**When** the app is re-opened later that same day
**Then** it does not appear again — a dismissal is a skip-for-today, never re-shown within the day and never styled as pending (FR-4)

**Given** a selection
**When** the pool re-filters
**Then** it completes in under 500 ms (FR-4, NFR5)

**Given** media is selected
**When** the pool is filtered
**Then** nothing is excluded — only baja narrows, to Instant Habits and ≤ 60 s, excluding Focus Chunks. A day of middling energy is not a smaller day (FR-4)

**Given** baja is tapped while the check-in is open with a card in progress
**When** the filter applies
**Then** the card in progress can be finished and the filter applies to the next deal — work in progress is never withdrawn without comment (FR-4)

**Given** the check-in has left the strip
**When** the user wants an easier task mid-session
**Then** **no energy control exists to tap** — simplifying the current task is Rescue Mode's job via `Otra más fácil` (FR-4, FR-5)

**Given** any day boundary
**When** energy is derived
**Then** it defaults to 🟢 / llena, never decays, and is never carried across a boundary
**And** after the strip leaves, nothing on the Dispenser displays the level — the narrower deal is itself the display (AD-4, UX-DR41)

**Given** more than one strip resident eligible at one opening
**When** the strip resolves
**Then** one total precedence order decides — rarest eligible frequency first: the once-ever first-run curation offer, then the once-per-box Quarantine follow-up, then the once-per-season suggestion, then the snowball, then the weekly self-report, then the daily check-in — ties broken by earliest-eligible instant, then stable id (UX-DR22, AD-3)
**And** a displaced resident is neither consumed nor dismissed: it re-offers at the next opening, because only the ✕ is a dismissal (UX-DR22)

**Given** a session crossing 04:00 into a new domestic day
**When** the strip next resolves after the boundary
**Then** that resolution is the crossed-into day's first opening for the check-in — shown once if unresolved, skippable, never again that day (FR-4)

**Given** a 🔴 day holding an in-flight rescue chain or a pending first purge step
**When** the pool filters
**Then** the rescue chain's steps remain eligible — their estimates are ≤ 60 s, inside the filter's own rule — and the purge-first guarantee defers to the next non-🔴 day rather than breaking (FR-4, FR-5, FR-19)

### Story 2.6: The weekly self-report and the deterministic slot handoff

As the builder,
I want one weekly question about how much the house has weighed on me, and for it to wait until I answer it,
So that SM-2 has a trend to read without the app ever notifying me, and an unopened Sunday does not cost a quarter of the instrument.

**Acceptance Criteria:**

**Given** Sunday — the last day of the Monday-anchored domestic week
**When** the day's first opening resolves the strip
**Then** the self-report appears carrying `Esta semana, ¿cuánto te ha agobiado la casa?` (SM-2, AD-4)

**Given** the self-report
**When** its answer row is rendered
**Then** it is **numeric 1–5** with the end labels `Nada` and `Muchísimo`, the numbers being the tap targets
**And** it carries a 1px hairline, because it persists (UX-DR22)

**Given** a self-report that Sunday passed without answering
**When** any later day's first opening resolves the strip
**Then** the report **is offered again**, on any day, and keeps being offered at each day's first opening until it is answered — it does **not** expire at the week boundary (FR-4)

**Given** the self-report is pending
**When** the strip resolves against the energy check-in
**Then** the self-report **outranks** it — the rarer instrument wins the slot (FR-4)

**Given** the self-report is answered, or dismissed for that opening
**When** the same opening continues
**Then** the check-in takes the slot in that same opening if it has not already been resolved that day — so a pending report **delays** the check-in within an opening rather than displacing it for the day (FR-4)

**Given** a dismissal
**When** its scope is evaluated
**Then** it frees the slot for that opening only and the report returns at the next day's first opening — **never dismissed for the week** (FR-4, SM-2)

**Given** an answer
**When** it is recorded
**Then** a `report_answered` entry is appended carrying **the week it answers**, not merely its own instant — under persistence an answer can fall outside the week it reports on, and without the explicit target week SM-2's week-4-versus-week-1 trend cannot be built (AD-21, SM-2)

**Given** a report still pending when the next Sunday arrives
**When** that Sunday's report becomes due
**Then** the pending one is **superseded, not accumulated**: at most one report is ever pending, the new week's report takes the slot, and the superseded week simply has no data point (SM-2)

**Given** a week whose report was superseded or never answered
**When** the SM-2 trend is read
**Then** that week has no data point and the trend reads over the weeks that do (SM-2)

**Given** the self-report
**When** notification behaviour is examined
**Then** it is **never notified** under any code path — a notification would violate FR-24 and §5.2 (SM-2)

**Given** a day that ends without the check-in having shown
**When** energy is derived for that day
**Then** it is carried by the 🟢 default and owes nothing (FR-4)

### Story 2.7: Warm Return

As Sergio,
I want to come back after days away and find nothing waiting for me,
So that the app cannot make my absence into a debt, because it has no way to represent one.

**Acceptance Criteria:**

**Given** 48 hours have passed since the later of the last `app_opened` and the last user act
**When** the app is opened
**Then** `warmReturnDue` derives true — the one sibling predicate of `EligibleDay`, and one of AD-21's three stated reader exceptions (FR-6, AD-24)

**Given** a Warm Return
**When** the Dispenser is rendered
**Then** the first dispensed card comes from the silently rebalanced composition, and cold start still meets ≤ 2 s (FR-6, NFR5)

**Given** any UI element or string anywhere in the app
**When** it is audited
**Then** no "you missed N days" copy, overdue badge or broken-streak indicator exists
**And** the days away are not representable in the schema, so they cannot reach the screen (FR-6, NFR9)

**Given** six days of absence
**When** the app is opened
**Then** there is no backlog, no count, no rebalanced-plan announcement and no apology (FR-6, UJ-3)

**Given** the Warm Return copy
**When** this story is planned
**Then** it is `Siempre a tu disposición`, which rebalances without naming what it is rebalancing (UX-DR51)

---

## Epic 3: The Floor — Capture by Hand or Voice

The user puts something into the app that it could never have known about — a favour promised to a neighbour — in about ten seconds, typed or spoken out loud, and then never sees it again until it arrives as an ordinary card. No list appears, no counter moves, nothing congratulates them.

**FRs covered:** FR-27, FR-32

**Scope notes:**

- **Story 3.1 is a verification story and it gates 3.4.** §10.2 records two unverified halves of the recognition assumption, and they fail differently: poor *accuracy* is absorbed silently by the keyboard, so it gates nothing; poor *availability* voids the accessibility floor §7 claims, which is a promise about **who can use the app**. So availability is verified first, on real handsets, and it needs no pass bar — it is binary.
- **This epic is what makes Epic 4's degradation surface possible.** FR-29's single exit is `Anotarlo`, to Manual Capture. Built in the other order, that surface has nowhere to go.
- **Manual Capture's only privilege is its deal window.** Everything else about a captured task is ordinary, and the pool is the only place it can be seen again.

**Implementation notes:** adds capture pool facts and their precedence as a new candidate source into AD-20's resolver, with the deal window expressed over Epic 2's `EligibleDay` predicate. Builds the `size-option` component with its two states, the spatial frame's three-step ordering rule, and the AD-11 `dictate` channel gated by `isOnDeviceRecognitionAvailable()` **and** `checkRecognitionSupport()` — a service being available is not the Spanish model being present. Ships the `microphone-glyph` capsule under UX-DR9's registered-mass rule, the `Escuchando…` caption, and the per-capture dictation boolean that only Settings may read. The seven authored Manual Capture strings go in verbatim.

### Story 3.1: On-device recognition availability, verified on the handsets

As the builder,
I want to know before building the microphone whether on-device Spanish recognition is actually present on the validation handsets,
So that the accessibility floor is a verified property rather than a promise, because it is a claim about who can use the app.

**Acceptance Criteria:**

**Given** each of the three validation handsets
**When** availability is probed
**Then** `isOnDeviceRecognitionAvailable()` **and** `checkRecognitionSupport()` are both queried, and the result is recorded per device — a *service* being available is not the **Spanish model** being present (AD-11)

**Given** a handset reporting the service but not the Spanish model
**When** the result is interpreted
**Then** it counts as **unavailable**, because FR-32's "the affordance is simply not present" is a statement about the language, not the service (AD-11)

**Given** the probe results
**When** they are read against §7
**Then** the accessibility floor's wordless-route claim is confirmed or reported as void on the affected devices — and if void, that is a finding to escalate, not a detail (NFR6, §10.2)

**Given** availability is confirmed
**When** accuracy is considered
**Then** **no pass bar is set and none is needed**: poor accuracy is absorbed silently by the keyboard, which FR-32 never removes, so voice reads as noise rather than as a broken feature (§10.2)

**Given** the probe
**When** it is implemented
**Then** it lives outside the shipped app surfaces as a throwaway check — it introduces no UI, no permission request at app entry, and no dependency the app keeps

### Story 3.2: Manual Capture — one line, three sizes, and a frame instead of a rule

As Sergio,
I want to put one thing into the app in ten seconds without it asking me anything else,
So that something I promised gets out of my head without becoming a task-management chore.

**Acceptance Criteria:**

**Given** the Dispenser
**When** the user reaches Manual Capture
**Then** it costs **one tap** via the Lápiz entry, top-right (FR-27, UX-DR15)

**Given** the capture surface
**When** it is rendered
**Then** it holds exactly two fields — one line of text and a size from exactly three options — and asks for nothing else: no project, no category, no date, no priority, no tags, no recurrence, no confirmation screen (FR-27)

**Given** the three size options
**When** they are rendered
**Then** they are `size-option` pills showing **durations** — `30 s` · `3 min` · `10–15 min` — never the glossary's internal names, single-selection and always populated, with no empty state and no "none of these" (UX-DR19)
**And** selected is `accent-soft`, unselected is `surface-raised` with a 1px hairline, and no option ever carries a glyph (UX-DR19)

**Given** the surface's copy
**When** it is read in order
**Then** the spatial frame's three steps hold: the title `Un rincón de la casa` names **a place**; the helper `Una cosa que se pueda señalar con la mano: un cajón, una estantería, una silla, un rincón.` lists **things you can touch**; the example `Vaciar la caja de la entrada` opens with **a spatial verb** (UX-DR42, UX-DR49)

**Given** a line that is not spatial — `llamar al dentista`
**When** the user confirms it
**Then** it is **accepted in silence**: no error state, no validation, no rejection, no red edge, no corrective message and no gentle equivalent of one
**And** therefore **no second version of this screen exists** (FR-27, UX-DR42)

**Given** the captured line
**When** the user looks for a date
**Then** the frame's copy says nothing about dates — the surface does not lecture (FR-27, OQ-11 closed 2026-08-27)

**Given** an empty line
**When** the confirming action is evaluated
**Then** `Guardar` stays **disabled until the line holds text** — a blank capture is not a task, and letting one enter the pool would put an irreversible empty card into circulation (FR-27)

**Given** the surface's controls
**When** they are counted
**Then** there is one secondary only — `Descartar`, which is also the exit — and no `Cancelar` beside it (UX-DR42)

**Given** a confirmed capture
**When** `Guardar` is tapped
**Then** a pool fact is inserted carrying origin `manual`, the chosen size from the 1-3-5 taxonomy, and an Origin Context consisting of **its own single line and nothing more** (FR-27, AD-14)
**And** a `capture_created` entry is appended (AD-21)

**Given** the user has left the surface
**When** they look for the captured line
**Then** it can no longer be corrected or discarded: it belongs to the pool, and the only path back to it is being dealt (FR-27)

### Story 3.3: The capture comes back as an ordinary card

As Sergio,
I want what I captured to arrive on a day when it fits, without ever appearing in a list,
So that I trust the capture surface enough to use it instead of a notes app.

*(Story 3.2 wrote the pool fact; this story is about how it comes back.)*

**Acceptance Criteria:**

**Given** the three capture sizes
**When** the composition arithmetic runs
**Then** they **are** the 1-3-5 taxonomy, so a captured task enters the Project Weaver with no conversion step and FR-12's budget arithmetic holds unchanged (FR-27, FR-12)

**Given** a pending capture and Evergreen or Epic material of the same size
**When** the resolver orders candidates
**Then** the capture takes precedence — offered as a candidate with precedence, never as a deal, because `core/weave` is the only emitter (FR-12, AD-20)

**Given** several pending captures of the same size
**When** they are ordered
**Then** they deal **oldest-first (FIFO)**, read from recorded act instants and never from id bit patterns (FR-12, AD-3)

**Given** a capture
**When** its deal window is derived
**Then** it is expressed over the **one** `EligibleDay(item, day)` predicate and no second definition exists, and the window is three eligible days (FR-12, AD-24)

**Given** an eligible day on which a capture was dealt and declined
**When** the window advances
**Then** the day is consumed — a capture is dealt within three eligible days, answered or not, and skipping never extends the window (FR-12, AD-24)

**Given** a 🔴 day or a day of absence
**When** the deal window advances
**Then** it **freezes** — the window advances only on days the capture was actually eligible for dealing (FR-12, AD-24)

**Given** the user returns after a freeze
**When** the window resumes
**Then** there are no "expired" captures, because the schema has no overdue — the window simply resumes where it froze (FR-12, NFR9)

**Given** a pending 10–15 min capture
**When** the day's Focus Chunk slot resolves
**Then** the capture **is** the "1" for that day, and the day never holds a second large item beside it (FR-12, AD-20)

**Given** any number of pending captures
**When** the pool is examined
**Then** there is **no expiry and no cap** — silently deleting a capture would betray the trust the deal window exists to protect (FR-12)

**Given** any screen in the app
**When** it is audited
**Then** none lists, counts, filters or browses captured tasks, and the read facade exposes no function that could (FR-27, NL-1, AD-6)

**Given** a captured task is dealt
**When** the card is rendered
**Then** it is visually and tonally **indistinguishable** from a sliced one — no badge, no icon, no copy, and its origin tag never reaches the Dispenser (FR-27, AD-14)

### Story 3.4: Dictation into the capture line

As Sergio,
I want to say the thing out loud instead of typing it,
So that the one surface where the app asks me to write does not depend on the worst input device on the phone.

**Acceptance Criteria:**

**Given** the capture surface with recognition available
**When** it is rendered
**Then** the `microphone-glyph` sits at the **one-line field's end** at 24px inside a 48dp tap — a vertical capsule, stem and U-arc stand, line-only in `ink-primary`, with the capsule as a **registered mass** in `icon-mass-neutral` at rest (UX-DR21, UX-DR9)
**And** the field placeholder reads `Escríbelo o dilo en voz alta`, naming both modalities (UX-DR49)

**Given** the affordance
**When** the user presses it
**Then** dictation starts on that **explicit press** and nothing listens outside it — no wake word, no ambient capture, no background audio of any kind (FR-32, NFR8)

**Given** dictation is running
**When** the state is declared
**Then** the capsule mass turns `icon-mass-blue` **and** the caption `Escuchando…` appears in `support` — state is declared in ink and prose and **never by motion**; the breathing cue was offered and declined (UX-DR21, UX-DR44)

**Given** recognition
**When** it runs
**Then** it uses `createOnDeviceSpeechRecognizer()` gated by `isOnDeviceRecognitionAvailable()`, because that pair **forces** on-device and fails rather than falling back — `EXTRA_PREFER_OFFLINE` is only a hint and FR-32 forbids a fallback outright (AD-11)
**And** there is no cloud fallback on any path, so §7's egress map gains no destination (FR-32, NFR4)

**Given** a completed utterance
**When** the transcript lands
**Then** it appears **in the existing one-line field on the existing surface** — never a confirmation screen, which this surface does not have and does not acquire (FR-32)

**Given** a mis-transcription
**When** the user corrects it
**Then** FR-27's correct-or-discard affordance governs, and **the keyboard is never removed** — correcting requires it, and the surface accepts typing at all times (FR-32)

**Given** one utterance plainly containing several errands
**When** it is processed
**Then** it becomes **one line and one task**; the app does not split it and does not tell the user it could (FR-32)

**Given** a spoken duration inside the utterance
**When** the transcript is handled
**Then** it is words in the line like any others — **nothing is ever parsed out of the transcript**, and the size is still chosen from the same three taps (FR-32)

**Given** any dictation
**When** storage and transmission are audited
**Then** **no audio exists anywhere**: not written to storage, not in the export, not in any FR-26 series, not recoverable once the transcript exists — the transcript is the only artifact (FR-32, NFR4)

**Given** the microphone permission
**When** it is requested
**Then** it is requested at the **first dictation attempt**, never at app entry and never during first run (AD-17, NFR8)

**Given** the user refuses the permission
**When** the surface is rendered afterwards
**Then** keyboard capture is fully functional, the affordance is removed, a `permission_refused` entry is appended, and **the app never asks again on its own** via the derived `permissionMayBeAsked` fact (AD-17, AD-21)
**And** the refusal is reversible in Settings and nowhere else, on the same unified pattern the camera follows — a row exists only while there is something to reactivate (FR-32, UX-DR33)

**Given** the microphone permission revoked at the system level after being granted
**When** dictation is next attempted
**Then** it behaves exactly as a first-use refusal: the affordance is removed, a `permission_refused` entry is appended, and the IA y voz reactivation row appears — the camera's unified pattern, twin case (AD-17, UX-DR33)

**Given** dictation interrupted by backgrounding, a call, or focus loss mid-utterance
**When** the surface returns
**Then** no partial transcript lands in the line — the interrupted utterance yields nothing, the affordance resets to rest, and no error appears (FR-32)

**Given** on-device Spanish recognition is unavailable
**When** the surface is rendered
**Then** the affordance is **simply absent** — no error, no explanation, no greyed-out state, no install offer, and no settings pointer to the system's language-pack installation (FR-32, OQ-13 closed 2026-08-27)

**Given** a dictated capture
**When** its provenance is recorded
**Then** its origin is `manual`, exactly as a typed one — dictation is an input method, not a genesis path (AD-14)
**And** a separate per-capture dictation boolean is stored as a pool-fact field, readable **on the validator surface only**, and sits outside origin arithmetic (FR-32, AD-26)

**Given** a dictated task and a typed one
**When** either is dealt
**Then** they are indistinguishable — no badge, no icon and no copy anywhere marks a card as spoken (FR-32)

---

## Epic 4: The Slicer and Honest Degradation

The user supplies their own provider key, asks a stuck task to be made simpler and gets steps of under a minute, and — whenever the AI cannot be reached, for any of seven reasons — reads plainly what is unavailable and carries on working from the local pool. The Slicer's absence degrades genesis, never execution.

**FRs covered:** FR-5, FR-28, FR-29

**Scope notes:**

- **Story 4.1 gates the rest of the epic.** The PRD leaves provider choice to *"the terms gate and structured-output reliability alone"*, and that reliability has never been tested. Nothing else here can be wired until a provider, a prompt and an output schema exist.
- **Only one of the three payload shapes is exercised by this epic.** All three are declared as types (AD-7 forbids a fourth existing at all), but Epic 4 calls only the rescue re-slice text. The scan image and the genesis text are called by Epic 5. Declaring three and calling one is the seal working as designed, not dead code.
- **The `Files` port is declared here**, as its first consumer: AD-22's encrypted credential envelopes. Epic 5 adds the scan cache and Epic 7 the album bytes, additively.
- **`Otra más fácil`'s half of the secondary control is wired in this epic** (Story 4.6), completing the shared component Epic 1 built with only its skip half.

**Implementation notes:** builds `lib/egress/` as the single HTTP chokepoint with exactly three payload shapes and no fourth existing as a type, sealed by three checks — Dart imports, the resolved Gradle graph and the merged Android manifest. `SlicerPort` with BYOK usable and the Local canned stub reachable only in the debug variant, so the interface has two real callers. AD-22's `CredentialVault` — AndroidKeyStore wrapping key, provider-scoped envelopes in app-private Files, `withCredential` per request, plaintext never crossing the core — plus the CI check that rejects secrets and key shapes in export fixtures. FR-5's dissolution pattern retires the original and every incomplete sibling atomically (AD-25), with no tombstone and no synthetic completion. The seven no-Slicer strings are already authored and are pinned by key in AD-15's build check, which requires both a non-placeholder value and a reviewer sign-off marker. Provider selection is settled by the shared model-evaluation harness — Story 4.1 — which also closes PRD OQ-1's venue and candidate set (debts 1–2, paid).

### Story 4.1: The model-evaluation harness and provider selection

As the builder,
I want one harness that judges all five Slicer candidates against the same photos, prompt, schema and written pass bar,
So that the provider choice and OQ-1's topology question are answered by evidence in one session instead of by intuition in two.

**Acceptance Criteria:**

**Given** the harness
**When** its location is checked
**Then** it lives **outside the app** — not in `lib/`, not in `tool/` — because a script calling five endpoints is legitimate tooling and would be an AD-7 / AD-12 violation as app code: a second HTTP opener outside `lib/egress/`, against AD-12's closed egress map (NFR13)

**Given** the harness
**When** its candidates are enumerated
**Then** it targets five: **Gemma 4 E2B and E4B run locally through Lemonade's OpenAI-compatible endpoint**, plus Gemini, OpenAI and Anthropic — the three that pass FR-28's written no-training gate (OQ-10, closed 2026-08-26)

**Given** the local candidates
**When** the endpoint is first exercised
**Then** **image input is confirmed to work before anything else is planned around it** — the whole test is photo→plan, and a text-only local endpoint invalidates the desktop route

**Given** the shared inputs
**When** the harness runs
**Then** all five candidates receive the identical corpus, prompt and structured-output schema, and are judged against the identical bar

**Given** the corpus
**When** it is assembled
**Then** it holds at least 10 photographs of real spaces spanning at least 4 distinct space types, so no candidate is judged on ten shots of the same shelf

**Given** the pass bar
**When** the first candidate is run
**Then** the bar has already been **written down and confirmed by the builder** — a bar agreed after seeing results is a rationalisation, not a bar

**Given** a candidate and one photograph
**When** its response is judged
**Then** that photograph counts as a pass only if **all five hold**: the response parses against the schema on the first attempt with no retry and no repair; every step carries a duration tag inside 3–5 minutes; at least 4 steps are returned; every returned step is a real action available in that space, with no object the photograph does not contain; and the order is workable, in that nothing is put away before the surface it goes on has been cleared (FR-16)

**Given** the ten photographs
**When** a candidate's score is totalled
**Then** it passes at **8 of 10 or better**, and fails below that

**Given** a candidate that fails on the desktop
**When** the result is interpreted
**Then** the candidate is **killed outright** — the Android artifact is more aggressively quantized, so it cannot do better

**Given** a candidate that passes on the desktop
**When** the result is interpreted
**Then** the pass is **provisional** and must be re-verified on the handset before commitment, because the artifact that passed is not the artifact that would run

**Given** the running order
**When** the candidates are tested
**Then** **E2B runs first**: if it passes, the work ends on the better outcome — smaller on exactly the axis the standing storage constraint cares about — and only if it fails does E4B follow

**Given** the harness has completed
**When** its outputs are recorded
**Then** they are: the selected release provider, the prompt, the structured-output schema, the per-candidate scores, and OQ-1's answer — and the last is reported as a PRD/architecture update rather than absorbed silently

**Given** storage, peak memory, inference latency and thermal behaviour
**When** they are considered
**Then** they remain **handset questions and remain deferred** — AD-9 keeps the Local path a configuration rather than a rewrite, so a late answer costs no redesign

### Story 4.2: The egress chokepoint, sealed three ways

As the builder,
I want exactly one module able to open a network connection, sealed by checks rather than by discipline,
So that a fourth destination cannot arrive without someone deciding to add one.

**Acceptance Criteria:**

**Given** the codebase
**When** HTTP client imports are located
**Then** only `lib/egress/` has one, and a `tool/` check fails the build on any other (AD-7)

**Given** the egress module
**When** its accepted payloads are enumerated
**Then** exactly three shapes exist and **no fourth exists as a type**: scan image plus prompt, project genesis text, rescue re-slice text (AD-7, NFR4)

**Given** an image payload
**When** it is prepared
**Then** a single image-resolution cap is enforced **before any upload**, serving upload minimisation, cost, and how much of the user's home leaves the device at once (AD-7, FR-25)

**Given** any egress call that fails
**When** the module's state is inspected
**Then** it **never queues, never retries and never persists a pending request** (AD-7, FR-29)

**Given** the resolved Gradle dependency graph
**When** the second seal runs
**Then** it is checked against an allowlist and the build fails on any addition — this is how a manifest-initialised native SDK would otherwise arrive invisibly to a Dart import check (AD-7, AD-12)

**Given** the merged Android manifest
**When** the third seal runs
**Then** it declares no permission, service, receiver or provider outside an enumerated set, and the build fails otherwise (AD-7)

**Given** the three Kotlin channels
**When** they are checked
**Then** all three are in scope of all three seals, may open no socket, and compute no dates (AD-11, AD-4)

**Given** the three new checks
**When** this story is complete
**Then** each is registered as a `Makefile` target reachable from `make check` (NFR20)

### Story 4.3: The credential vault

As Sergio,
I want my provider key held where nothing can read it out and nothing can export it,
So that putting a key into the app never means writing it into a file that ends up in Drive.

**Acceptance Criteria:**

**Given** Android Keystore
**When** the vault is initialised
**Then** it holds **one non-exportable AEAD wrapping key** — Keystore cannot hold the provider's arbitrary credential string directly, which is why the envelope exists (AD-22, A14)

**Given** a provider credential
**When** it is stored
**Then** it is a **provider-scoped ciphertext envelope in app-private Files storage** — never in preferences, never in the pool, never in the log (AD-22, NFR15)

**Given** the credential plaintext
**When** its path through the system is traced
**Then** it enters only the shell's credential-setting handler, passes directly to the vault for encryption, and **never crosses the core, the log, the pool, the export, a crash event or a URL, and is never cached** (AD-22)

**Given** a save
**When** it executes
**Then** it is an atomic provider-scoped replacement under the vault lock; a delete is idempotent (AD-22)

**Given** `credentialAvailable(provider)`
**When** its role is checked
**Then** it means the complete envelope decrypts successfully **now**, and it is **display state only, never request authorisation** (AD-22)

**Given** a BYOK request
**When** it executes
**Then** it runs `withCredential(provider, operation)`: the vault decrypts inside that request scope, supplies plaintext only to the egress operation, releases its references on return, and reports missing, corrupt or Android-invalidated material as unavailable **without sending** (AD-22)

**Given** a `setting_changed` entry
**When** its payload is inspected
**Then** it may carry `selectedProvider` and **never `keyExists`** or any credential-availability claim (AD-22)

**Given** a restore from export
**When** configuration is derived
**Then** `providerConfigured` is exactly `selectedProvider != null && credentialAvailable(selectedProvider)` — the provider choice may survive the restore while configuration stays false until a credential is saved again (AD-22)

**Given** export fixtures
**When** the CI check runs
**Then** it **rejects** plaintext, provider-key shapes and any persisted `keyExists: true` (AD-22)

**Given** the vault's failure modes
**When** they are tested
**Then** coverage includes save, replace, delete, absent, corrupt and Android-invalidated envelopes, and invalidation discovered **at request time** (AD-22)

**Given** the store seal
**When** it runs
**Then** `CredentialVault` composes `Files` with the named Keystore key and owns **no fourth store** — its Keystore access is the one closed native exception (AD-21)

### Story 4.4: The Slicer port, BYOK and the frozen allowlist

As Sergio,
I want to choose a provider from a short list the app vouches for and paste in my own key,
So that the app can slice my home without anyone in the middle holding my data or my money.

**Acceptance Criteria:**

**Given** `SlicerPort`
**When** its implementations are counted
**Then** three are declared — BYOK usable, Local, Managed — and adding Local or Managed changes no call site outside `lib/egress/` (AD-9, FR-28)

**Given** the Local implementation
**When** it is exercised
**Then** it returns a **canned slice**, is reachable **only in the debug build variant**, and its output is recognisable as canned so it can never be mistaken for a real slice (AD-9, FR-28)
**And** it exists so the interface has two real callers, making swappability exercised rather than asserted

**Given** the Managed implementation
**When** it is inspected
**Then** it exists as the port's third shape with **no proxy, no account and no billing code**, and the credits-never-subscription constraint is recorded in the access layer itself — because the access layer is precisely where someone would otherwise wire a subscription check (AD-9, FR-28)

**Given** provider selection
**When** the user chooses
**Then** they choose from a **compile-time allowlist constant that is never fetched over the network** — a remote list would reintroduce a developer-side endpoint and with it the third egress destination (AD-9, FR-28)

**Given** the app's configuration surfaces
**When** they are searched
**Then** **no free-form endpoint or base-URL field exists anywhere** — the no-training gate is unenforceable the moment the user can point the app anywhere (FR-28)

**Given** an allowlist entry
**When** it is rendered
**Then** it states the provider name and the date its terms were verified, saying plainly they were verified **on** that date and not since — there is no age indicator, no re-check and no removal mechanism, because each would promise a vigilance the app does not have (AD-10, FR-28)

**Given** the terms gate
**When** its criterion is checked
**Then** it is **no-training only**; retention is deliberately not gated, because no provider reachable with a user's own key offers written zero retention and gating on it would have excluded every candidate (AD-10, FR-28)

**Given** key entry
**When** it is reached
**Then** it lives in Settings' **IA y voz** group and states **once** that a free-tier key may be used for training and that the app cannot tell which tier a key belongs to — and nothing anywhere repeats it (AD-10, UX-DR33)

**Given** the Dispenser
**When** it is audited
**Then** it never mentions a key, a quota, a provider or a network, and **never learns that a key exists** (AD-10, NFR3)

**Given** the whole build
**When** it is searched for identity
**Then** no account, login, password or registration exists, and nothing in the first-run experience requires the network (FR-28, NFR11)

**Given** a BYOK call
**When** billing is considered
**Then** the app adds no margin, meters no usage and reports no call to anyone — the relationship is entirely between the user and their provider (FR-28, NFR4)

### Story 4.5: Honest degradation — one calm surface, seven strings, one exit

As Sergio,
I want the app to tell me plainly what it cannot do right now and let me get on with my day,
So that a key problem is the app's problem and never reads as mine.

**Acceptance Criteria:**

**Given** any of the seven no-Slicer causes
**When** the surface is rendered
**Then** it is **ONE calm surface carrying the cause's string plus a single exit — not seven visual states** (FR-29, UX-DR41)

**Given** the seven strings
**When** they are wired
**Then** they go in verbatim from the authored table: no key configured, invalid key, exhausted quota, provider unreachable, no network, consent declined, person in frame (UX-DR50)
**And** the register holds: objective problems of the app rather than of the home — state the fact, name the remedy where one exists, **no cushioning**

**Given** the invalid-key string
**When** it is compared to the PRD's flagged original
**Then** it reads `La clave guardada no es válida. Puedes revisarla en Ajustes.` — the shaming lived in the possessive, not in the judgment (UX-DR50)

**Given** the consent-declined string
**When** its remedy is looked for
**Then** it deliberately names none — the remedy would be retry-and-accept, which is the persuasion the PRD forbids on this path. **A recorded deviation from FR-29, not an omission** (UX-DR50)

**Given** the config-family causes
**When** they are rendered
**Then** they carry a **text pointer** to Ajustes — informational, not an action — so the surface keeps its single exit (UX-DR50)

**Given** the surface
**When** its exit is used
**Then** it is `Anotarlo`, to Manual Capture, and it is **input-method-neutral by construction** — the manual path includes on-device dictation, so a label claiming *a mano* would collide with the microphone on the destination surface (UX-DR50)

**Given** each of the seven states including no-network
**When** the exit is exercised
**Then** it works in **all seven** — typing and on-device dictation never need what is missing (UX-DR50, FR-32)

**Given** the surface
**When** its styling is audited
**Then** none of the seven is styled as an error: no red, no warning iconography, no exclamation, and the full-screen illustration register applies (FR-29, UX-DR44)

**Given** any no-Slicer failure
**When** state is inspected afterwards
**Then** **nothing is queued**: no scan image, no re-slice request and no pending-upload state survives it (FR-29, AD-7)

**Given** a fresh install with no Slicer reachable
**When** the app is opened
**Then** it still reaches a woven 1-3-5 day from shipped content, and the app **names which half is unavailable** rather than implying the whole product is degraded — carried by precision in each string rather than by a blanket reassurance (FR-29, FR-11)

**Given** the absence of a Slicer
**When** its framing is audited
**Then** it is never framed as the user's omission and never as pending work (FR-29)

**Given** the seven strings
**When** the build check runs
**Then** each is pinned **by key** and requires both a non-placeholder value **and** a reviewer sign-off marker in the ARB metadata — existence and review are separate gates (AD-15)
**And** the check is registered as a `Makefile` target reachable from `make check` (NFR20)

### Story 4.6: Rescue Mode

As Sergio,
I want a task I keep passing over to become something smaller instead of something that keeps coming back,
So that being stuck produces a smaller ask rather than a quiet accusation.

**Acceptance Criteria:**

**Given** the same Micro-task
**When** it has been declined on **3 different eligible days**
**Then** a re-slice is warranted — a soft signal, derived over the one `EligibleDay` predicate, so days of absence, days the task was not dealt, and energy filtering neither increment nor reset the count (FR-5, AD-24)

**Given** any dealt card at any moment
**When** the user taps `Otra más fácil`
**Then** a re-slice is requested without waiting for any counter — completing the shared secondary control Epic 1 built with only its skip half (FR-5)

**Given** a re-slice request
**When** it is sent
**Then** it uses the task's **Origin Context** through the FR-28 access path, and **no new photo is taken or re-processed** (FR-5, FR-25)

**Given** a `shipped` catalogue task declined on three different eligible days
**When** its Origin Context is resolved
**Then** it is **the task's Spanish catalogue name — one line of text, exactly the shape a Manual Capture's is** (builder decision, 2026-08-27)
**And** no field is added to the catalogue asset: the name already exists as an ARB entry keyed by the entry's id, so the existing allowlisted shell loader resolves that key at load time and hands the name to the core as inert data — AD-16's four-fields-and-no-more, AD-15's single string table and AD-5's sealed core all stand unchanged
**And** the rescue steps inherit origin `shipped` (AD-14), so SM-4's origin arithmetic is untouched
**And** nothing enters the catalogue: the steps are transient pool facts, and FR-31's *fixed at build time, the user cannot author, edit or extend it* stands entire
**And** it sends the Origin Context and the current task with no per-call dialog, resting on the build-time allowlist gate rather than a runtime hope (FR-25)

**Given** a successful re-slice
**When** its result enters the queue
**Then** it is 2–4 steps, each ≤ 60 s, woven one at a time by the Project Weaver, and **tonally indistinguishable** from any other Micro-task (FR-5)

**Given** a rescue step's pool fact
**When** it is written
**Then** it carries the step's **estimate in seconds, verbatim from the Slicer's tag**, and a size from Story 5.3's one fixed banding — ≤ 60 s → the 30 s size — with every duration-consuming rule reading the estimate and the size governing only same-size precedence and shape counting (AD-23, FR-5)

**Given** a rescue re-slice
**When** it is requested, returned or failed
**Then** `slice_requested` / `slice_returned` / `slice_failed` are appended on the same terms as a photo scan, so FR-26 series (b) closes over the rescue channel too (FR-26, AD-21)

**Given** rescue steps
**When** their provenance is recorded
**Then** they **inherit the parent's origin** — a re-slice is mechanism, not re-authorship, so a hand-written line rescued by the cloud Slicer still entered the pool by hand (AD-14, SM-4)

**Given** all rescue steps are completed
**When** the parent is evaluated
**Then** the parent is done **by derivation** — no synthetic `card_done` is ever appended, so completion counts still count user acts only (AD-25, FR-26)

**Given** a rescued Focus Chunk
**When** its chain completes or dissolves on a later domestic day
**Then** the advance is charged to the dealing session's own day — completion closes that day's occupancy by derivation, the completing day's slot stays free, and a dissolution releases the dealing day's slot for a fresh resolve (AD-19, AD-20, AD-25)

**Given** a rescue is activated
**When** the refusal counter is evaluated
**Then** it resets, success or failure — including an attempt that degraded because no Slicer was reachable, so a failed rescue does not re-trigger on every subsequent deal (FR-5)

**Given** a rescue step
**When** `Otra más fácil` is tapped on it
**Then** the depth cap holds — no second re-slice — and the control degrades to its skip half with no refusal surface and no error: one tap still passes the step, and no half-wired control exists anywhere (FR-5)

**Given** a rescue whose steps are themselves declined on 3 different eligible days
**When** dissolution runs
**Then** it retires **the original item and every not-yet-completed step of that chain, atomically in one derivation** — a surviving sibling would be a fragment re-woven forever (AD-25, FR-5)
**And** no tombstone is stored: the dissolved task leaves the pool by derivation, and its history survives in the FR-26 series and the export

**Given** no reachable Slicer
**When** a rescue is attempted
**Then** it degrades per FR-29: the original task stays dealable as-is, nothing is queued, and no error state appears (FR-5, FR-29)

**Given** a manually captured task
**When** rescue is requested
**Then** it is rescuable through its own single line whenever a Slicer is reachable — a capture's Origin Context is exactly the re-slice text (§3) — and with no reachable Slicer it degrades per FR-29 like any other task: the original stays dealable, nothing is queued, and nothing is styled as failure (FR-5, FR-27)

**Given** any skip
**When** storage is inspected
**Then** skips feed only this counter and **no cumulative skip total is stored anywhere** (FR-26, FR-5)

---

## Epic 5: From a Personal Project to Its First Card

The user photographs a real space — or describes one in writing — and is shown not a plan but a first step, so the storage room stops being a wall. Consent is asked for every single scan, people in the frame are refused before anything leaves the device, and the household programme can be curated at cluster level.

**FRs covered:** FR-11 *(Epic half)*, FR-13, FR-15, FR-16, FR-25, FR-31 *(curation half)*

**Scope notes:**

- **Story 5.1 gates 5.2 and 5.3.** The face gate is a privacy guarantee resting on a **community-maintained** dependency the architecture already lists among its three fragile ones. Its bar is asymmetric and that asymmetry is the whole point: a false positive costs an annoyance, a false negative **uploads a photograph of a person**, which is the failure FR-25 exists to prevent.
- **This epic completes the genesis surface Epic 2 half-built.** Epic 2 put the `Nuevo proyecto` affordance on the Dispenser carrying only its Settings way-out; this epic adds typed project entry as that surface's recommended action, restoring principle 1's literal arithmetic — one recommended action plus one way out. E2 stays dissolved.
- **The `Files` port gains the per-scan cache**, additively on the adapter Epic 4 declared for credential envelopes.

**Implementation notes:** both genesis entrances, A-slim — the Cámara entry sited directly on the Dispenser (visibility = enabled ∧ permission not refused, with the single Settings row owning both the disable toggle and the reactivation) and the typed genesis surface behind `Nuevo proyecto` carrying one recommended action plus its way out. AD-8's single-use `ScanConsent` token bound to the scan's cache subdirectory, minted after the on-device face gate and before the resolution cap; both scan files unlinked on **every** terminal path, with a sweep at each `app_opened` as the crash backstop. Adds Epic material as a candidate source with AD-20's least-recently-served arbitration. Builds the `action-equal-pair` consent gate — the only surface in the app with zero recommended actions — and the `curation-row` in all three homes. Onboarding is the product plus one one-time strip: no wizard, because the ≤ 2 s contract holds hardest on day one.

### Story 5.1: The on-device face gate, verified before it is trusted

As the builder,
I want to know how often the face gate lets a person through before I let it guard anything,
So that a privacy promise rests on a measurement rather than on a package's README.

**Acceptance Criteria:**

**Given** `google_mlkit_face_detection`
**When** its provenance is recorded
**Then** it is noted as **community-maintained and not by Google**, and as one of the architecture's three named fragile dependencies — a candidate for promotion to a platform channel under AD-11's rule if the guarantee turns out to rest on the API after all

**Given** the verification corpus
**When** it is assembled
**Then** it holds photographs **with** people — including hard cases: partially framed, in profile, at distance, poorly lit, reflected in a mirror, and printed in a photograph on a wall — and photographs **without** people that contain face-like objects

**Given** the bar
**When** it is set
**Then** it is **asymmetric and written before the run**: the failure that matters is a **false negative** — a frame containing a person that the gate passes — and the target for it is **zero across the corpus**, because that failure uploads a photograph of a person

**Given** a false positive
**When** it occurs
**Then** it is recorded and accepted: the cost is one reframe, and the offer to reframe is the specified behaviour rather than an error (FR-25)

**Given** any false negative
**When** it occurs
**Then** it is escalated as a **finding, not a tuning parameter** — and the recorded remedy options are promotion to our own platform channel (AD-11) or a tighter detection configuration, decided against the measurement

**Given** the detection
**When** it runs
**Then** it runs **on-device and before any upload path is reachable** (FR-25, AD-8)

**Given** the build configuration
**When** ABIs are checked
**Then** only 64-bit libraries ship, because only those are 16 KB-aligned — already enforced by Story 1.1's `abiFilters` (NFR12)

### Story 5.2: The camera entry, and shooting the frame

As Sergio,
I want to photograph the mess in front of me with one tap from where I already am,
So that starting a project costs a photo instead of a form.

**Acceptance Criteria:**

**Given** the Dispenser
**When** the Cámara entry is used
**Then** it opens Scan directly — one tap, top-right, at 24px inside a 48dp target carrying `icon-mass-neutral` under the ordinary treatment (FR-16, UX-DR15, UX-DR24)

**Given** the camera permission
**When** it is requested
**Then** it is requested at the **first scan attempt**, never at app entry and never during first run — the same first-use rule the microphone follows (AD-17, NFR8)

**Given** a refused camera permission, or one revoked at the system level after being granted
**When** the Dispenser is rendered
**Then** the entry is **simply absent** — never greyed, never explained — and a `permission_refused` entry is appended (FR-16, AD-17, UX-DR24)

**Given** the entry's visibility
**When** it is derived
**Then** it is exactly **enabled ∧ permission not refused**, and the app never re-asks on its own (FR-16)

**Given** Settings
**When** the camera row is used
**Then** a **single row owns both the disable toggle and the reactivation**, so the reversal lives where the user put the refusal — and re-enabling means the OS permission is requested again at the next first use (FR-16, UX-DR33)

**Given** the user disables the camera outright
**When** the Dispenser is rendered
**Then** the entry never appears at all, and nothing behind `Nuevo proyecto` references the photo — so disabling changes nothing about the genesis surface (FR-16)

**Given** the camera surface
**When** the user shoots
**Then** the frame is written to that scan's own cache subdirectory and handed to the on-device face gate — and **no upload path is reachable from this story**, because AD-8 makes a `ScanConsent` a compile-time precondition of upload and Story 5.3 is what mints one (FR-16, AD-8)

### Story 5.3: Per-scan consent, the upload and the scan's whole lifecycle

As Sergio,
I want to be asked every single time before a photo of the inside of my home leaves the device,
So that consent is a decision I make rather than a setting I once forgot.

**Acceptance Criteria:**

**Given** the upload function
**When** its signature is inspected
**Then** it **cannot be called without a `ScanConsent`** — the absence of a token is a compile-time impossibility, not a runtime check (AD-8)

**Given** a `ScanConsent`
**When** it is minted
**Then** it is minted **after the on-device face gate and before the resolution cap**, binds to the scan's cache subdirectory identity, and is **consumable once** — so the cap operates inside the binding rather than producing a new subject (AD-8)

**Given** the app's settings
**When** they are searched for a consent preference
**Then** **no blanket "always allow" exists**, and it must not be added as a convenience — consent is asked per scan, every scan (FR-25)

**Given** the consent gate
**When** it is rendered
**Then** it uses `action-equal-pair`: one row, both children `flex 1 1 0`, identical width, height, ground, hairline, type role, ink and tap count, with **no fill on either** — `accent-soft` is expelled from the surface entirely (UX-DR26)
**And** it is **the only surface in the app with zero recommended actions**, a declared exception that no other surface may borrow

**Given** the gate's copy
**When** it is read
**Then** it states in plain Spanish **what is sent and to whom** — the named provider, the scan image and a prompt, and nothing else (FR-25)

**Given** the decline path
**When** its cost is measured
**Then** declining is the **same number of taps** as accepting, with no larger accept button, no dimmed decline, no "are you sure" and no delay before decline becomes tappable (FR-25)

**Given** the residual reading-order asymmetry
**When** it is handled
**Then** `Enviar` sits in the **first slot** — the unfavourable position for a consent decision — recorded as a failure of symmetry rather than claimed solved (UX-DR26)

**Given** a declined consent
**When** the flow continues
**Then** no upload happens, the user lands on the no-Slicer surface with its own string and the `Anotarlo` exit, and there is **no re-ask, no persuasion and no second attempt at the gate** (FR-25, FR-29)

**Given** a person or face detected in the frame
**When** the scan is handled
**Then** it is refused **on-device, before upload**, with an offer to reframe, and a `face_refused` entry is appended — **the refusal is about the frame, never about the user** (FR-25, AD-21)

**Given** a scan
**When** its files are examined
**Then** it owns **one cache subdirectory holding at most two files** — the frame and its capped copy (AD-8)

**Given** a scan that resolves by **any** means — a plan, a face refusal, a declined consent, a provider failure, or the user leaving or backgrounding the app
**When** resolution completes
**Then** **both files are unlinked**, whichever cause came first (AD-8, NFR14)

**Given** a crash between minting and resolution
**When** the app is next opened
**Then** a sweep of the scan cache directory runs at `app_opened` as the backstop (AD-8, NFR14)

**Given** the `consent_granted` entry
**When** its power is examined
**Then** it is **instrumentation only and carries no capability**: the token is never persisted, never exported and never reconstructible from the log (AD-8)

**Given** what is sent
**When** the payload is inspected
**Then** it is only the scan image and a prompt — **no plan history, no album contents, no device or location identifiers** (FR-25, NFR4)

**Given** a granted consent
**When** the upload runs and the wait is rendered
**Then** it happens **in-app, in the foreground, with visible progress and honest copy**, on a full-screen surface in the illustration register
**And** there is deliberately **no latency cap and no timeout** — with latency demoted, the clock is the user's own patience, and an impatient user already has the exit (FR-16, NFR5)

**Given** the user leaves the scan surface or backgrounds the app mid-wait
**When** the scan resolves
**Then** the wait is **cancelled and discarded**, a `scan_abandoned` entry is appended, and **nothing is queued** (FR-16, AD-8, AD-21)

**Given** a successful slice
**When** the steps are returned
**Then** each carries a duration tag **between 3 and 5 minutes** (FR-16)

**Given** a sliced step's pool fact
**When** it is written
**Then** it carries the step's **estimate in seconds, verbatim from the Slicer's tag**, and a **size from the 1-3-5 taxonomy by one fixed banding — ≤ 60 s → 30 s, 61 s–9 min → 3 min, ≥ 10 min → 10–15 min** — and this banding is the product's only duration→size rule: the pocket, the 🔴 filter's *≤ 60 s* and the bag's ceiling read the **estimate**, never the bucket; the size governs only same-size precedence and 1-3-5 shape counting; Focus-slot eligibility is by candidate class, never by size; and a Manual Capture's estimate is its size's canonical value (AD-23, FR-12, FR-27)

**Given** a response that parses but violates the step contract — a duration tag outside 3–5 minutes, or steps that are not real actions in the space
**When** the outcome is recorded
**Then** it is `slice_failed`, never dealt as-is, surfaced under the provider-unresponsive string — a declared mapping recorded so a later reader does not invent an eighth cause (FR-16, FR-29, AD-21)

**Given** a successful slice
**When** the scan's data is handled
**Then** the Slicer's structured description of the space is retained as **Origin Context** for future re-slicing, and the image itself is discarded (FR-16, FR-25, FR-5)

**Given** the consent gate's strings and the scan-wait affordance
**When** this story is planned
**Then** the equal actions are `Enviar la foto` and `No enviarla`; the body is `La foto se procesará por [proveedor] para obtener las tareas necesarias.`; the unbounded wait says `Creando tareas` beside an indeterminate animated writing pencil (UX-DR52, UX-DR56)

### Story 5.4: Epic Project genesis, by photograph or in writing

As Sergio,
I want the trastero to become a thing with a first step instead of a wall,
So that a project I have been avoiding for months starts with ten minutes.

**Acceptance Criteria:**

**Given** the `Nuevo proyecto` affordance
**When** its surface is opened
**Then** it carries **typed project entry as its one recommended action** and Settings as its one way out — restoring principle 1's literal arithmetic and keeping E2 dissolved (FR-11, UX-DR25)

**Given** the two genesis entrances
**When** they are compared
**Then** the photo path is the Dispenser's own Cámara entry and the typed path sits behind the affordance; **neither is a precondition for the other**, and reaching manual entry costs one tap and asks for no reason (FR-11)

**Given** any template or archetype
**When** an Epic Project is created
**Then** **no Epic Project is ever created from a template** — Epic material always comes from the Slicer, from input the user supplied (FR-11)

**Given** the typed genesis surface
**When** the user sends a description
**Then** the surface states in plain Spanish that the description will be analysed to create tasks, and **`Analizar` is the consent action** — no separate dialog and no provider name on this text-genesis surface (FR-25, NFR4)

**Given** an empty description on the typed genesis surface
**When** the send action is evaluated
**Then** it stays disabled until the description holds text, mirroring `Guardar` — no empty egress call exists (FR-25, NFR4)

**Given** a genesis call
**When** it is instrumented
**Then** it is recorded in FR-26 series (b) on the **same terms as a photo scan**, so the text path is instrumented like the photo path (FR-26)

**Given** a created Epic Project
**When** its lifecycle is inspected
**Then** it is **dormant until activated** and appears in **no default view** while dormant — not listed, not counted, not previewed (FR-11, UX-DR41)
**And** activation appends an `epic_activated` entry (AD-21)

**Given** more than one active Epic Project
**When** the Focus Chunk's Epic is chosen
**Then** it is the **least-recently-served active Epic**, then activation order, then stable id — arbitration belongs to the one resolver, not to the Epics (AD-20, AD-3)

**Given** a sliced Epic step
**When** its provenance is recorded
**Then** its origin is `cloud` on the BYOK path — set once at genesis, immutable, never surfaced in the Dispenser (AD-14)

**Given** the user after a successful slice
**When** the surface is rendered
**Then** they are shown **one card — the first step — and never the plan**: nothing enumerates the rest, so there is nothing to dread (FR-1, UJ-2)

**Given** no reachable Slicer
**When** genesis is attempted by either entrance
**Then** it degrades per FR-29 and the Evergreen day keeps working — the app names which half is unavailable (FR-11, FR-29)

**Given** the genesis surface's drafted strings
**When** this story is planned
**Then** the consent action is `Analizar` and the quiet exit is `Volver`; the surface says the description will be analysed to create tasks without naming the provider (UX-DR52)

### Story 5.5: Invisible buffers

As Sergio,
I want the app to have already absorbed the days I will inevitably miss,
So that a week away costs me nothing I can see.

**Acceptance Criteria:**

**Given** an Epic Project's steps
**When** they are spread across days
**Then** the spreading includes built-in temporal slack, and the slack is **rule-based in v1** — adaptive or ML buffer learning is deferred (FR-13, §5.1)

**Given** any Epic target date shown to the user
**When** it is derived
**Then** it **always includes slack the user cannot see, cannot configure and cannot spend** — a visible buffer is a deadline with extra steps (FR-13, §1.1 P4)

**Given** seven days of total absence
**When** the app is next opened
**Then** **no Epic milestone is in an overdue state** and the target has silently rebalanced (FR-13)

**Given** a deferred Focus Chunk
**When** the next composition runs
**Then** it is rescheduled within the buffer window **without changing any visible target** — and because nothing was stored as a future assignment, there is nothing to re-plan (FR-13, FR-14, AD-1)

**Given** the buffer
**When** any surface is audited
**Then** slack appears nowhere: no bar, no percentage, no "days remaining", no configuration row (FR-13, §1.1 P4)

### Story 5.6: Cluster curation in its three homes

As Sergio,
I want to switch off the parts of the house I do not have,
So that the app stops offering me a terrace I never had, without ever showing me a catalogue.

**Acceptance Criteria:**

**Given** the `curation-row`
**When** it is rendered
**Then** it is a platform switch row carrying **cluster name, cadence in `support`, and the switch**, tappable anywhere in the row (UX-DR23)

**Given** the cadence line
**When** it is read
**Then** it says one of `diaria` / `semanal` / `mensual-estacional` and is **the row's only description** — rhythm is product metadata, not volume, and FR-31 forbids counting tasks while cadence counts nothing (UX-DR23)

**Given** the three homes — the E1 template surface, onboarding's one-time strip offer, and Settings' sub-screen
**When** each is rendered
**Then** all three render the **identical row**, so curation looks like itself everywhere it is found (UX-DR23)
**And** none of the three may read as a browsable catalogue (FR-31)

**Given** a switch being flipped
**When** feedback is considered
**Then** there is **none beyond the switch itself**: no count, no summary, no copy about what was turned off (FR-31, UX-DR23)
**And** a `cluster_curation_changed` entry is appended (AD-21)

**Given** any curation surface
**When** its granularity is checked
**Then** it is **cluster level only and never a task-level row** — a browsable 80-item catalogue is the list NL-1 abolishes, arriving through the template door (FR-31)

**Given** the E1 template surface
**When** it is built
**Then** it opens **from the genesis surface** — the complement to typed entry, never a third top-level path — rendered in the identical `curation-row`, and its exception licence lives here and nowhere else (FR-11, E1)
**And** it enumerates **templates and clusters, never the individual catalogue entries inside them**, and selecting a template enables or disables Evergreen clusters only — it never creates an Epic Project (FR-11, FR-31, E1)

**Given** a curation change
**When** it takes effect
**Then** **weekly zones change at the next week boundary** — the rotation argument is theirs — and **daily and `fondo` clusters change immediately**, where FR-31's *simply never appear* governs (AD-16)

**Given** curation that drops the eligible pool below the coverage floor
**When** the slot resolves
**Then** Story 1.7's stated fallback governs: the zone's own entries, then `fondo`, then the least-recently-dealt eligible entry regardless of zone (AD-16, AD-20)

**Given** the Dispenser
**When** curation is looked for
**Then** it is reachable from **onboarding and Settings only, never from the Dispenser** (FR-31, NFR3)
**And** Settings' **Contenido de la casa** group holds it as a sub-screen (UX-DR33)

**Given** first run
**When** onboarding is rendered
**Then** it is **the product itself plus one one-time ambient strip** offering curation — no wizard and no welcome screen delaying the first card, because the ≤ 2 s contract holds hardest on day one (FR-31, UX-DR34, NFR5)

**Given** the one-time curation offer
**When** it is dismissed
**Then** it **never returns**, and Settings plus the E1 surface remain the standing routes (FR-31)

**Given** a user who dismisses the offer or never sees it
**When** the first day composes
**Then** the default stands — **every cluster active** — and the first composed day is never empty (FR-31)

**Given** the one-time curation offer's copy
**When** this story is planned
**Then** it is `Ajustar grupos de tareas`, tappable once on the strip and gone forever when dismissed (UX-DR52)

### Story 5.7: The gentle seasonal suggestion

As Sergio,
I want the app to mention the closet switch when spring arrives and then drop it,
So that seasonal work occurs to me once without becoming a thing I am behind on.

**Acceptance Criteria:**

**Given** a seasonal trigger and a dormant Epic Project
**When** the suggestion is offered
**Then** it appears on the **ambient strip** as one resident, bare chrome, proposing a minutes-per-day plan (FR-15, UX-DR22)

**Given** a season
**When** its boundary is computed
**Then** it is a three-month meteorological quarter falling on domestic-day boundaries, from the one `Calendar` and nowhere else (AD-4)

**Given** a suggestion
**When** the user dismisses it
**Then** it costs **one tap**, a `suggestion_dismissed` entry is appended, and it **never repeats more than once per season per project** (FR-15, AD-21)

**Given** a declined suggestion
**When** side effects are inspected
**Then** there are **zero** — on any metric, any internal signal and any composition (FR-15)

**Given** the strip
**When** more than one resident is eligible
**Then** at most one is visible, and the rarer instrument outranks the daily one (UX-DR22, FR-4)

**Given** a configuration surface for the suggestion engine
**When** it is looked for
**Then** there is none: `[OPEN, position stands]` per UX-DR59 — defaults-only is the standing answer until a suggestion actually misfires, which is a position rather than a decision (PRD OQ-6)

---

## Epic 6: Letting Go Without Guilt

Before organizing anything, the user is asked the two questions that do the real work, and offered three destinations of genuinely equal weight — none of them worded, styled or ordered as the bad one. What they hesitate over goes in a dated box that never claims to know what happened to it.

**FRs covered:** FR-19, FR-20, FR-21, FR-22

**Scope notes:**

- **Purge injection is a candidate-precedence rule, not a special case in the weave.** `core/weave` stays the only emitter of a deal; purge steps return candidates with precedence like everything else (AD-20).
- **This epic produces the figures Epic 7 renders.** `item_triaged` is written here and read there — a clean producer/consumer seam, which is why the two epics stayed separate.
- **The accessibility consequence of dropping coloured tiles is load-bearing here and nowhere else.** With hue confined inside each glyph, the three choices are told apart by silhouette alone. That cost was accepted knowingly and it produces one non-negotiable rule this epic must honour.

**Implementation notes:** the `destination-flow` at 64px with no tile, no default and no ordering signal — and the load-bearing accessibility consequence honoured: with tiles dropped, hue lives only inside each glyph, so the three choices are told apart by silhouette alone and the three destination hues may never appear as a field, tile, bar or band without their glyph inside. The Quarantine Box is reconstructed from `box_created` and `item_triaged` acts with its follow-up derived from the box's instant — never a stored date. `item_triaged` carries a destination plus an optional coarse volume tag from the four allowed values and never a number. This epic produces the figures Epic 7 renders.

### Story 6.1: Purge comes first

As Sergio,
I want the app to make me clear things out before it asks me to organize them,
So that I never spend twenty minutes arranging what I should have let go of.

**Acceptance Criteria:**

**Given** an organizing Epic Project
**When** it is activated
**Then** purge Micro-tasks are prepended before any organization step (FR-19)

**Given** a newly activated organizing project
**When** its first Micro-task is dealt
**Then** it is **always a purge step** (FR-19)

**Given** purge steps
**When** they reach the resolver
**Then** they are offered as **candidates with precedence** and `core/weave` remains the only code that emits a deal (AD-20)

**Given** a purge step
**When** the card is rendered
**Then** it is an ordinary `dispenser-card` — a purge step is not styled, framed or announced as a different kind of work (FR-19, FR-1)

**Given** the Decluttering Protocol is reached
**When** the surface is entered
**Then** it is reached from the Dispenser **when the dealt Micro-task is a decision about an object**, and not from a menu or a list (UX-DR31)

### Story 6.2: The two detachment questions

As Sergio,
I want to be asked whether this thing deserves my space rather than told to get rid of it,
So that deciding costs me a thought instead of a justification.

**Acceptance Criteria:**

**Given** a purge step
**When** the questions are presented
**Then** both appear as specified: the factual one — has this been used in the past 12 months — and the one that does the real work — does this deserve your physical and mental space (FR-20)

**Given** either question
**When** its copy is audited
**Then** it contains **no pressure framing** (FR-20, NFR7)

**Given** either question
**When** it is rendered
**Then** it offers only `Sí` and `No`; there is no skip action, and the user must choose one of the three destinations after both answers (FR-20)

**Given** the questions
**When** they enter the string table
**Then** they are externalised and unconcatenated like every other string, and they sit in the SM-C2 audit (AD-15, NFR7)

**Given** the question presentation
**When** this story is planned
**Then** each question has only `Sí` and `No`, followed by the required 3-Destination Flow; no skip affordance is built (UX-DR58, FR-20)

### Story 6.3: Three destinations of equal weight

As Sergio,
I want the choice to keep, to give away or to let go to feel like three equal choices,
So that letting something go is not the answer the app was pushing me toward.

**Acceptance Criteria:**

**Given** the 3-Destination Flow
**When** it is rendered
**Then** it is **one decision on a whole screen with nothing else on it** — three glyphs at 64px, 32dp row gap (UX-DR27, FR-20)

**Given** the three choices
**When** their labels are set
**Then** they read `Quedármelo` · `Donar o vender` · `Tirar o soltar`, verbatim (UX-DR49)
**And** the third is **never** `Tirar o reciclar`, never a bin word and never a recycling word — *soltar* avoids both the deletion vocabulary of a bin and the compliance vocabulary of recycling arrows (FR-20)

**Given** the trio
**When** its weighting is audited
**Then** there is **no tile, no field, no default, no pre-selection and no ordering signal**, and no destination is worded, styled or ordered as the undesirable one (FR-20, UX-DR27)

**Given** the destination hues
**When** they are applied
**Then** each lives **only inside its own glyph** — and the non-negotiable rule holds: **a destination hue never appears as a field, tile, bar or band without its glyph inside it** (UX-DR3, UX-DR47)

**Given** a user with reduced colour vision
**When** the three choices are distinguished
**Then** **silhouette alone carries the load** — the accepted cost of dropping coloured tiles, recorded rather than smoothed over (UX-DR47)

**Given** the seed glyph in the trio
**When** it is drawn
**Then** it carries exactly 8 filaments, its axis at 45.0°, and **no motion dashes** — dashes are reserved for the illustration register at 56px and above, so the trio's seed reads **at rest** by decision (UX-DR8, UX-DR10)

**Given** dark mode
**When** the trio is rendered
**Then** it keeps the **light form unchanged** — two plates, the global offset, mass under line — with the line in `ink-primary-dark` and the mass in the dark hue. The earlier 6px-bar construction is superseded (UX-DR13)

**Given** a triage decision
**When** it is recorded
**Then** an `item_triaged` entry is appended carrying the destination and an **optional coarse volume tag** from exactly `bolsa` / `caja` / `caja grande` / `mueble` — **never a number** (FR-22, AD-21)

### Story 6.4: The Quarantine Box and its blind timer

As Sergio,
I want somewhere to put the things I cannot decide about today,
So that hesitating is a valid outcome instead of a decision I keep re-opening.

**Acceptance Criteria:**

**Given** a hesitated item
**When** the user sends it to quarantine
**Then** a `box_created` entry is appended carrying the box's date (FR-21, AD-21)

**Given** a hesitated item
**When** it goes into the box
**Then** it is recorded as an `item_triaged` entry carrying the destination `quarantine` — an additive value of the destination vocabulary under AD-23 — linked to its box's `box_created` id, so the box's contents reconstruct from the log and nothing else (FR-21, AD-21, AD-23)

**Given** a Quarantine Box
**When** it is reconstructed
**Then** it is derived from `box_created` and `item_triaged` acts — there is **no quarantine table** and its follow-up is derived from the box's own instant, **never a stored date** (AD-1)

**Given** six months since the box's date
**When** the follow-up is offered
**Then** it appears **at most once per box**, on the ambient strip, dismissible in one tap (FR-21, UX-DR22)

**Given** the follow-up's copy
**When** it is audited
**Then** it is **phrased on the date alone and contains no claim about the box's contents or its use** — the timer is blind because the app has no signal about a physical box, and the copy must not pretend otherwise (FR-21)

**Given** a dismissed follow-up
**When** side effects are inspected
**Then** there are none, and it never returns for that box (FR-21)

### Story 6.5: The cumulative declutter metric

As Sergio,
I want to see roughly how much space I have freed,
So that letting go leaves a trace of what it produced rather than of what it cost.

**Acceptance Criteria:**

**Given** the metric
**When** its source is inspected
**Then** it is derived **only from what the user tapped during purge steps** — a per-destination item count, and **nothing is inferred from photographs** (FR-22)

**Given** the volume tags
**When** they are applied
**Then** they are optional and coarse — `bolsa` / `caja` / `caja grande` / `mueble` — and **absent tags simply do not contribute** (FR-22)

**Given** a volume figure
**When** it is displayed
**Then** it is an approximation with its unit visible, in the shape `≈ 3 cajas liberadas` — **never a precise figure and never a percentage** (FR-22, UX-DR49)

**Given** the volume line
**When** it is laid out
**Then** it carries **no glyph**, because the system's only box glyph *is* `Quedármelo` and setting it beside a sentence about boxes *released* would say the opposite of the sentence (UX-DR37)

**Given** the metric
**When** its framing is audited
**Then** it is displayed **only as cumulative achievement** — never a target, never a rate, never a deficit (FR-22)

**Given** the metric's figures
**When** they cross to the shell
**Then** they cross as **achievement figures**, rendered only on the FR-23 dashboard that Epic 7 builds, and subject to the denominator rule there (AD-26)

---

## Epic 7: Seeing What I Did

The user sees the same corner of their home before and after, in two plates of equal size that let the comparison speak without anyone grading it, kept in a private local album they can delete piece by piece — and a cumulative account of what they have done that no denominator can turn into a quota.

**FRs covered:** FR-17, FR-18, FR-23

**Scope notes:**

- **This epic reads what Epic 6 wrote.** The per-destination counts and volume tags come from `item_triaged`; nothing here recomputes them from anything else.
- **The dashboard is the app's one declared density exception**, and the denominator rule is what makes it safe. Both are review gates on this epic's stories, checkable value by value.
- **The album is contextual only.** It is reached when a transformation completes and not otherwise, and the dashboard sits behind it. A permanently reachable album is a surface that invites browsing, which is the thing the product removed.

**Implementation notes:** the `photo-frame` pair has only `Antes` and `Después` outside the pastel — no caption, share action or rating language. AD-26's split is the gate for the dashboard: achievement figures may cross to the shell, internal signals never. `dashboard-highlight-row` reflows to one column when a caption would break beyond two lines; it never shrinks. Album bytes are content-addressed, and `album_entry_deleted` unlinks the app-private source file in the same operation.

### Story 7.1: The Before/After reward

As Sergio,
I want to see the corner as it was beside the corner as it is,
So that the work is visible without anyone putting a score on it.

**Acceptance Criteria:**

**Given** completed work on a space a Before photo was taken for
**When** the reward is offered
**Then** the user can shoot an "after" photo and receive a side-by-side diff (FR-17)

**Given** the two plates
**When** they are laid out
**Then** they are **equal size, at equal height, with the same corner**, 16dp apart, in `photo-frame` at 3:4 with a 1px hairline (UX-DR29, UX-DR40)
**And** the moment one plate is larger, higher or framed differently, the layout has an opinion — and an opinion is a rating

**Given** the labels
**When** they are placed
**Then** `Antes` and `Después` sit **outside the frame**, never over the image (UX-DR29)

**Given** a frame while its image loads
**When** it is rendered
**Then** it shows an **empty frame of the right shape** on `surface-base` — no spinner, no shimmer, no gradient (UX-DR29)

**Given** the diff view
**When** its copy is audited
**Then** it contains **no negative framing** — no "still messy", and no adjective about the result at all: *mejor*, *más despejado*, *casi* each reintroduce a scale, and with a scale the deficit comes back (FR-17, UX-DR40)

**Given** the reward's secondary control
**When** it is labelled
**Then** it **closes**: `Cerrar`, never a variant of *seguir* — the closing rule binds hardest here, because this is the one place the celebration is large enough to be worth extending (UX-DR40, UX-DR39)

**Given** a completed diff
**When** it is saved
**Then** it goes to the Transformation Album **automatically**, and an `album_entry_added` entry is appended (FR-17, AD-21)

**Given** a session milestone on a space no Before photo was ever taken for
**When** the reward is offered
**Then** it shows `Un trabajo estupendo` — no one-plate diff, placeholder plate or shoot-and-save prompt — and the milestone still counts for FR-26 series (c) (UX-DR57, FR-17, FR-26)

**Given** the camera entry disabled or its permission refused
**When** the reward's shoot action is rendered
**Then** it follows the Cámara entry's own rule — absent, or degrading to Manual Capture's path — never a dead button on the reward surface (FR-16, FR-29, UX-DR24)

**Given** the diff presentation beyond side-by-side
**When** this story is planned
**Then** equal-size frames sit side-by-side, labelled only `Antes` and `Después`; the pair is private and local, has no caption or share action, and the no-Before case shows `Un trabajo estupendo` (UX-DR57)

### Story 7.2: The local Transformation Album

As Sergio,
I want a private gallery of what changed that I can delete piece by piece,
So that a record of my own home stays mine and stays deletable.

**Acceptance Criteria:**

**Given** the album
**When** it is reached
**Then** it is reached **only from the Before/After reward when a transformation completes** — contextual, never a permanently available destination (UX-DR31, UX-DR32)

**Given** album images
**When** their location is inspected
**Then** they live in **app-private Files storage** and the app **never sends them** — they leave the device only via user-initiated export, into the folder the user chose (FR-18, NFR4)

**Given** an album entry
**When** the user deletes it
**Then** an `album_entry_deleted` entry is appended **and the app-private source file is unlinked in the same operation** (FR-18, AD-13)

**Given** the whole album
**When** the user purges it
**Then** it is purgeable **in one action**, unlinking all app-private album files (FR-18)

**Given** the album read model
**When** its shape is inspected
**Then** it is **derived** over stored image bytes and log acts — there is **no album table**, because an independently editable manifest would let one unit delete by removing a row while another deletes by appending an event (AD-13)

**Given** album thumbnails
**When** they are rendered
**Then** they use `photo-frame` at the 4px thumb radius, because 14px on a ~100dp plate eats the corners of the photograph itself (UX-DR7, UX-DR29)

**Given** an already-exported generation
**When** an album source file is deleted
**Then** the committed generation stays valid — exported bytes are content-addressed and obey the retained-generation reachability rule, so deleting the source never invalidates a committed export (AD-13)

**Given** the album's empty state
**When** this story is planned
**Then** no empty state exists: the Album is unreachable until a first transformation exists (UX-DR51)

### Story 7.3: The cumulative impact dashboard

As Sergio,
I want one place that adds up what I have actually done,
So that progress is visible as a completed fact rather than as a fraction of something I owe.

**Acceptance Criteria:**

**Given** the dashboard
**When** it is reached
**Then** it is reached **from the Album only** — contextual, behind a contextual surface (UX-DR31, UX-DR32)

**Given** the dashboard
**When** its contents are rendered
**Then** it shows cumulative minutes, completed Micro-tasks, liberated items and volume, and album highlights (FR-23)

**Given** every value on the screen
**When** the denominator rule is applied one value at a time
**Then** **none admits a denominator**: no "de 7 días", no average, no target, no "this week, less than last", no per-day rate, no percentage, no completion ratio (UX-DR36, FR-23)
**And** the reviewable form is: *if a value could be given a denominator, it does not belong on this screen*

**Given** the dashboard
**When** its density is justified
**Then** it is the app's **single declared density exception**, written as an exception so it is not a precedent — and **that density must not propagate to any other surface** (UX-DR35, UX-DR36)

**Given** the figures reaching the shell
**When** they are classified
**Then** only **achievement figures** cross — cumulative minutes, completed tasks, liberated volume, album highlights — and **internal signals never cross as numbers**: not FR-5's decline count, not the comfortable-day run, not a deal window, not any skip total (AD-26, AD-6)

**Given** `dashboard-highlight-row`
**When** it is rendered
**Then** it is three columns at default scale, each a thumbnail plus place and `short-date` (UX-DR30)

**Given** a caption that would break beyond two lines
**When** the row reflows
**Then** it drops to **one column per row** — it **never shrinks, never truncates, and never scales the dp gaps** (UX-DR30, UX-DR46)
**And** the trigger is expressed in **lines rather than dp**, so it survives a different line breaker and a second locale

**Given** the row at 200% font scale
**When** the degradation is observed
**Then** it is **expected behaviour and not a defect to file** — the one place in the app where 200% breaks a layout rather than a size (UX-DR46)

**Given** a highlight
**When** the user taps it
**Then** it is a way **into** the album, not a browse surface (UX-DR30)

**Given** at least 10 comfortable days — each with ≥ 1 session, ≥ 1 completed Micro-task and no session beyond its declared pocket
**When** the snowball condition is evaluated
**Then** a one-tap-dismissable suggestion to raise the Time Bag by ≤ 5 min may appear **on the ambient strip**, and declining has no effect (FR-23, UX-DR22)

**Given** the comfortable-day run
**When** the UI is audited
**Then** it is an **internal count and is never surfaced** anywhere (FR-23, §1.1 P2, AD-26)

**Given** the Time Bag already at the top of its range
**When** the snowball is evaluated
**Then** the suggestion **does not appear** — there is nothing left to suggest (FR-23)

**Given** the snowball suggestion accepted
**When** it is applied
**Then** the Time Bag rises by exactly 5 minutes capped at 30, a `setting_changed` entry is appended, and the comfortable-day run resets to zero — the next suggestion must be earned by a fresh run (FR-23, AD-1)

**Given** the snowball suggestion dismissed
**When** its scope is evaluated
**Then** it stays hidden while the current run stands and may reappear only after that run breaks and a new one reaches ten — dismissal never becomes a permanent feature loss, and never a nag (FR-23)

**Given** a session the user chose to extend
**When** the comfortable-day predicate reads its pocket
**Then** it reads the **original** pocket, so the extension is never scored as a marathon (AD-19)

**Given** the dashboard's empty state and the snowball's dismissal copy
**When** this story is planned
**Then** the dashboard is unreachable until a first transformation exists, and the snowball dismissal is `Está bien así.` (UX-DR51, UX-DR52)

---

## Epic 8: The One Silent Invitation

The user opts into a single daily invitation at an hour they choose, and it arrives silently with motivating, kind rotating copy. It may refer generally to household action, a short available time or a change of activity, but never names an actual pending task, shows a count or frames anything as owed. Ignoring it changes nothing — a week of ignored days is indistinguishable from a week of opened ones — and it is structurally incapable of escalating.

**FRs covered:** FR-24

**Scope notes:**

- **Kept as its own epic because it is structurally isolated**, not because it is large: its own Kotlin channel, its own alarm, its own boot receiver, its own permission, and the only background work in the entire build.
- **The `Notifier` port is declared here**, as its first and only consumer.
- **Statelessness is a requirement, not an optimisation.** The invitation may use only its configured hour, the Time Bag value and the fixed reviewed copy set. It cannot see whether the user has been away, so it cannot acquire pressure later, no matter who edits the copy.

**Implementation notes:** the AD-11 `notify` channel — one `NotificationChannel` at `IMPORTANCE_LOW` with `setShowBadge(false)`, created once and never a second — an **inexact** alarm at most once per *domestic day* (not a rolling 24 h — a chosen hour of 03:30 would otherwise straddle two days), `RECEIVE_BOOT_COMPLETED` for the reschedule, and no exact-alarm permission. The trigger instant is computed in the core and the Kotlin half performs no date arithmetic of any kind, boot reschedule included. Adds Settings' **Avisos** group. The reviewed motivating copy set rotates; it may refer generally to household action, a short available time or a change of activity, but no entry names an actual pending task, shows a count or frames anything as owed, late, missed or remaining.

### Story 8.1: One silent channel that cannot be widened

As Sergio,
I want the app to be able to remind me it exists without ever being able to nag me,
So that the one notification I allow cannot grow into the thing I turned notifications off for.

**Acceptance Criteria:**

**Given** the app
**When** notification channels are enumerated
**Then** exactly **one** `NotificationChannel` exists, created once at `IMPORTANCE_LOW` with `setShowBadge(false)`, and **no second channel is ever created** (AD-11, FR-24)

**Given** the channel
**When** its importance is considered after creation
**Then** it **cannot be changed** — the user may loosen it in system settings and the app can never widen it back, which is what makes "incapable of escalating" structural rather than hoped-for (AD-11, A6)

**Given** a delivered invitation
**When** it arrives
**Then** it is silent: **no sound, no heads-up interruption, no badge count**, and the launcher badge is suppressed explicitly (FR-24)

**Given** the notification's copy
**When** it is audited
**Then** it may refer generally to household action, a short available time or a change of activity, but contains **no actual task title, no numeric counter, and no word framing anything as owed, late, missed or remaining** (FR-24, SM-C3)

**Given** the invitation's composition
**When** its inputs are traced
**Then** it reads only the configured hour, the Time Bag value and the fixed reviewed copy set — no plan state, no completion history, no last-open time. It cannot see whether the user has been away, so it cannot acquire pressure later (A6)

**Given** the setting
**When** its default is checked
**Then** it is **off by default**, and once disabled it stays disabled until the user turns it back on (FR-24)

**Given** the invitation is disabled
**When** any code path runs
**Then** no notification is ever posted and the channel is never recreated — FR-24's *"removes the app's notification permission usage entirely"* is carried by those observables, because an app cannot revoke its own grant: the manifest entry stays inside AD-7's enumerated set, and the grant is the user's to revoke in system settings (FR-24, AD-7, AD-11)
**And** the app requests **no other notification category** (FR-24)

**Given** the invitation enabled while `POST_NOTIFICATIONS` is refused or revoked
**When** the Avisos group is rendered
**Then** the undeliverable fact is stated beside the hour row — never a silent no-delivery state, and never a re-ask the app initiates on its own (FR-24, AD-17)

**Given** Settings
**When** the **Avisos** group is rendered
**Then** it holds the opt-in and the chosen hour, and nothing else (UX-DR33)

**Given** the `POST_NOTIFICATIONS` permission
**When** it is requested
**Then** it is requested at the moment the feature is first used, never at app entry and never during first run; a refusal leaves the app working, appends `permission_refused`, and is never asked again on its own (AD-17)

**Given** the invitation's copy decision
**When** this story is planned
**Then** it uses the reviewed motivating, kind rotating set. Every string survives SM-C3: no actual task title, counter, owed/late/missed/remaining framing or increased frequency (UX-DR53, FR-24)

### Story 8.2: One per domestic day, rescheduled after boot

As Sergio,
I want at most one invitation a day, no matter what the phone does overnight,
So that a reboot or a doze cycle can never turn one invitation into two.

**Acceptance Criteria:**

**Given** the alarm
**When** it is scheduled
**Then** it is **inexact**, and **no exact-alarm permission is requested** — `USE_EXACT_ALARM` is Play-restricted to apps whose core function is precise timing, which this app is the negation of, and the copy carries no clock to be wrong about (AD-17, PRD OQ-8 closed 2026-08-26)

**Given** the delivery rate
**When** it is bounded
**Then** it is at most one per **domestic day** — not a rolling 24 hours, because a chosen hour of 03:30 would otherwise straddle two days (AD-4, AD-17)
**And** this **supersedes FR-24's literal "one per 24 h"**: a declared, reasoned override recorded in AD-17 on the same pattern AD-20 uses for FR-7's *dealt*, so a later reader must not "correct" the code back to a rolling window (AD-17, AD-20)

**Given** every code path including a boot reschedule after the alarm already fired
**When** emission is evaluated
**Then** **at most one notification per domestic day is emitted**: no second chance, no re-delivery on dismissal, no follow-up if unopened (FR-24)

**Given** the last emission
**When** it is read
**Then** it is read from the **`invitation_emitted` log entry** — not from preferences, not from a side file, because a third store would sit outside the two shapes, be absent from both export halves, and be invisible to the round-trip property (AD-21)

**Given** the trigger instant
**When** it is computed
**Then** it is computed **in the core** from the chosen hour, interpreted in the local offset in force at each reschedule — so the invitation follows the user rather than the zone the hour was set in (AD-4)

**Given** the Kotlin half
**When** its work is inspected
**Then** it performs **no date arithmetic of any kind, boot reschedule included**, and the `Notifier` port accepts an **absolute instant only** (AD-4, AD-11)

**Given** device boot
**When** the reschedule runs
**Then** it uses `RECEIVE_BOOT_COMPLETED` — the one install-time permission beyond the three runtime ones, and inside AD-7's manifest allowlist (AD-17, AD-7)

**Given** a dismissed or ignored invitation
**When** subsequent behaviour is compared to an opened one
**Then** they are **indistinguishable in app behaviour**: dismissing or ignoring has zero effect on any plan, metric or subsequent notification content (FR-24)

**Given** the app is opened within the hour after an emission
**When** FR-26 series (d) is written
**Then** both the emission and whether the app opened within the following hour are recorded, which is the only test SM-C3 has (FR-26, AD-21, SM-C3)

**Given** the whole build
**When** background work is enumerated
**Then** this invitation is **the only background work that exists** — no sync, no location, no persistent service, no wake locks, and the export runs in the foreground (NFR8)

---

## Epic 9: My Data, My Copy

Nothing the user does leaves their phone unless they export it, and the export happens by itself into the folder they chose once — with no reminder, no badge, no backup-age line and no failure toast anywhere they live. It restores in full on a fresh install, which is what earns the format the name *restore*.

**FRs covered:** FR-26, FR-30

**Scope notes:**

- **Placed last because the product functions without it, and because FR-26's four series need every act to exist first.** Each act was written by the epic that owns its behaviour; this epic assembles and renders them.
- **The `Folder` port is declared here**, as its only consumer, paired across `saf_util` (pickers and persisted permissions **only** — it provides no read or write) and `saf_stream` (the actual write path). Missing that pair was the architecture's first-draft error and it is called out so it is not repeated.
- **A hard sequencing condition:** AD-18's release ritual — export on all three handsets, install on top, import if a migration fails — **has no teeth until this epic lands**, so it must be complete before the four-week validation window opens. The `Makefile` targets for that ritual are owed here (NFR20).

**Implementation notes:** implements AD-13 in full — the authoritative/derived split with `derived/` never read on import, one process-wide foreground coordinator that drops rather than queues a concurrent automatic trigger, pool and log from the same SQLite read transaction, the `(generationSequence, generationId)` total order, create-once manifests, and cleanup that never deletes a committed manifest, snapshot or blob. The property test is what earns the name: arbitrary state exported, wiped, imported, every derived read model identical — cut after every write, across partial provider visibility, missing bytes, checksum mismatch and truncated manifests — plus a build-N+1 fixture imported into build N. Adds Settings' **Tus datos** group and the validator surface.

### Story 9.1: The four series, on the device and nowhere else

As the builder,
I want the minimum series the success metrics consume, readable as raw data,
So that the validation verdict does not depend on the app's own summary of itself.

**Acceptance Criteria:**

**Given** the instrumentation
**When** its series are enumerated
**Then** exactly four exist and are queryable: **(a)** session start/end with duration and Micro-tasks completed, **(b)** Slicer calls and their outcome — plan / declined / unavailable — covering **every photo scan, every text-genesis call and every rescue re-slice on the same terms**, **(c)** Before/After pairs per project milestone, **(d)** invitation emissions and whether the app was opened within the following hour (FR-26)

**Given** series (b)
**When** its denominator is closed
**Then** `scan_abandoned` is included, so an abandoned scan is not silently missing from the outcome mix (AD-21, FR-26)

**Given** every Micro-task
**When** its provenance is read
**Then** it carries its genesis origin — `shipped` / `manual` / `local` / `cloud` — and **every series row referencing a task carries it too** (FR-26, AD-14)
**And** origin is a provenance tag, never a quality ranking, and never surfaced in the Dispenser

**Given** SM-4's denominator
**When** it is computed
**Then** it reads what authored the **Focus Chunks and the Epic material**, not raw task share — the daily 1-3-5 is dominated by `shipped` content by construction, so raw share proves nothing (SM-4, FR-26)

**Given** the whole build
**When** it is searched for analytics
**Then** **no third-party analytics SDK is present**, the app transmits no usage data of any kind, and there is no developer-side record at all, because there is no proxy (FR-26, NFR13, NFR4)

**Given** any series
**When** the Dispenser and the dashboard are audited
**Then** **none is surfaced as a daily target, an average or a period comparison** (FR-26, SM-C1, SM-C2)

**Given** skips
**When** their storage is inspected
**Then** they feed only FR-5's consecutive-decline logic and **no cumulative skip total is stored anywhere** — a skip count is a debt record with a different name (FR-26)

**Given** the validator surface
**When** it is reached
**Then** it renders the raw series, FR-30's export state and FR-32's per-capture dictation boolean, and it is **Settings and nowhere else** (AD-26, NFR3)

### Story 9.2: The generational export, and the coordinator that keeps it whole

As Sergio,
I want my data to back itself up into my own folder without ever being asked,
So that nothing is lost and nothing about backup ever appears as work I owe.

**Acceptance Criteria:**

**Given** the destination
**When** it is chosen
**Then** it is chosen **once** through the system folder picker with a persisted URI, in Settings' **Tus datos** group (FR-30, UX-DR33)

**Given** the destination is set
**When** an export trigger arrives
**Then** every subsequent export happens **without being asked for**, writing plans, album images and all four series (FR-30)

**Given** the export triggers
**When** they fire
**Then** they are **foreground-only**: end of a session, and the app going to background. **No periodic job, no persistent service, no wake lock and no new permission** (FR-30, NFR8, AD-17)

**Given** the export
**When** transmission is considered
**Then** the app **never transmits it** — it writes a local file, and if the chosen folder happens to be a synced one, the user's own already-installed client does the uploading. Zero provider integrations (FR-30, NFR4)

**Given** the SAF adapter
**When** its parts are inspected
**Then** `saf_util` provides pickers and persisted permissions **only** and `saf_stream` is the actual write path — both are needed, and the pair is what the architecture's first draft got wrong

**Given** `AUTHORITATIVE/`
**When** its contents are enumerated
**Then** it holds immutable generation snapshots of the log and pool, content-addressed album-image blobs, and each generation's commit manifest — **and nothing else** (AD-13)

**Given** `derived/`
**When** its role is checked
**Then** it holds the album manifest, the four series rendered for reading, and the crash log — and is **never read on import** (AD-13)

**Given** export, import, cleanup and album-byte mutation
**When** any of them runs
**Then** a **single process-wide foreground coordinator** serialises them, and none runs in a background isolate or a second process (AD-13)

**Given** a trigger arriving while an export is running
**When** it is handled
**Then** it is **dropped, not queued** — AD-17's two triggers fire within milliseconds of each other at the end of a session (AD-13, AD-7)

**Given** a manual export requested while an export is already running
**When** the coordinator handles it
**Then** the manual export is **serialized behind the running one, never dropped** — the drop rule belongs to automatic triggers, and a user-initiated act is not a trigger (AD-13, FR-30)

**Given** a second installation exporting into the same destination folder
**When** it assigns its `generationSequence`
**Then** it continues from the **greatest fully verified manifest visible in that folder**, not from its own history — a shared folder is one lineage (AD-13)

**Given** the coordinator is held
**When** the snapshot is taken
**Then** pool and log come from the **same SQLite read transaction**, so a byte-perfect generation cannot still be logically torn (AD-13)

**Given** a new generation
**When** it is committed
**Then** it reads the newest fully verified manifest, assigns `generationSequence = previous + 1`, mints a UUIDv7 `generationId`, records the predecessor, writes create-once snapshots and any new content-addressed blobs, and **writes the `committed` manifest last** (AD-13)
**And** the manifest is **not in its own inventory**, order is the total tuple `(generationSequence, generationId)`, and folder enumeration order and wall time are irrelevant

**Given** a pre-existing target name
**When** a write is attempted
**Then** it is **structural corruption and is never overwritten** — and no correctness claim relies on SAF rename atomicity (AD-13)

**Given** cleanup
**When** it runs
**Then** it **never deletes a committed manifest, a committed generation snapshot or a content-addressed blob** — only uncommitted debris whose names this installation recorded during its own failed attempt, because SAF cannot prove a listing is globally complete (AD-13)
**And** at least the greatest valid manifest and its verified predecessor are retained

**Given** the export
**When** the Dispenser and every surface the user lives on are audited
**Then** there is **no reminder, no badge, no backup-age indicator, no "last exported" line and no failure toast** (FR-30, NFR2)

**Given** an export outcome
**When** it is recorded
**Then** an `export_recorded` entry is appended carrying destination, outcome and cause, and Settings renders the **latest success and the latest failure with its cause** — two derivations over the entry stream, and **nothing else observes it** (AD-13, AD-21)

**Given** a destination that becomes unwritable
**When** the app continues
**Then** it keeps working and stays silent; the fact is visible in Settings and nowhere else, and **never framed as the user's omission** (FR-30)

**Given** the export state
**When** its home is checked
**Then** it is readable **in Settings only** — the validator's surface, not the user's (FR-30, NFR3, AD-26)

**Given** a one-tap manual export
**When** it is looked for
**Then** it remains available in Settings, for the validator rather than for reassurance (FR-30)

### Story 9.3: Restore, and the property test that earns the name

As Sergio,
I want a fresh install to come back exactly as it was,
So that "restore format" is a property of the file rather than a promise about it.

**Acceptance Criteria:**

**Given** Settings' **Tus datos** group
**When** import is used
**Then** it is a **one-file-picker import** restoring plans, album and series **in full — no merging and no partial restore** (FR-30)

**Given** the import
**When** it selects a generation
**Then** it considers **only manifests that are fully visible** (never `FLAG_PARTIAL`), parses them, **verifies every inventory byte**, and chooses the **greatest valid tuple** (AD-13)

**Given** an incomplete, hidden or corrupt newer generation
**When** selection runs
**Then** it is **ignored without invalidating an older one** (AD-13)

**Given** an import that refuses — no valid generation found
**When** it refuses
**Then** the existing database is left untouched: the wipe begins only after a generation is fully verified, so a failed restore can never destroy local data (AD-13, FR-30)

**Given** an import while a scan is resolving
**When** the coordinator is held
**Then** the import waits for the scan's resolution to complete — scan pool facts never land in wiped or restored state (AD-13, AD-8)

**Given** an import from a different build
**When** unknown kinds and fields are met
**Then** they are **preserved verbatim and defaulted where a default exists** — AD-18's ritual imports an export made by a *different* build, so tolerating its rows is the contract, not a courtesy (AD-13, AD-23)

**Given** a record
**When** it is judged malformed
**Then** it is malformed **iff** it fails to parse as JSON, or a known kind lacks a field with no default — the two shapes the refusal exists for, and refusal is reserved for structural corruption and nothing else (AD-13)

**Given** the credential and the SAF destination
**When** the round-trip is compared
**Then** **both are excluded from read-model identity**: provider choice may be restored while configuration stays false, and the SAF destination is redacted **to null — never dropped as a field** (AD-22, AD-13)

**Given** arbitrary state
**When** the property test runs
**Then** it exports, wipes, imports and asserts **every derived read model is identical** (AD-13)

**Given** the property test
**When** its corpus is built
**Then** it **cuts the export after every write** and covers partial provider visibility, missing bytes, checksum mismatch, and corrupt or truncated manifests — and every case either restores the newest fully verified generation or refuses when none exists, **never partially restores** (AD-13, FR-30)

**Given** a fixture produced by build N+1
**When** it is imported into build N
**Then** **no derived read model regresses** (AD-13, AD-23)

**Given** an install-on-top under AD-18's ritual
**When** the app starts afterwards
**Then** the persisted SAF grant **survives**, because it belongs to the install the same keystore preserved — so the silent export resumes with **no user action and no prompt** (AD-18, FR-30)

**Given** a genuine fresh install followed by an import
**When** the restored state is read
**Then** the SAF destination comes back **not configured** — the grant belongs to the previous install and the export redacted the field to null — so **the user must re-pick the destination before any export can resume** (AD-22, AD-13)

**Given** a restored install whose destination has not been re-picked
**When** the app runs
**Then** it keeps working and **stays silent**: export simply does not happen, the fact is visible in Settings only, and it is **never framed as the user's omission** — no reminder, no badge, no backup-age line and no toast (FR-30, NFR2)
**And** an `export_recorded` entry carries the outcome and cause, so the gap is legible to the validator without ever reaching the Dispenser (AD-13, AD-21)

**Given** the release ritual
**When** it is performed
**Then** every build is signed with the **same keystore** so install-on-top preserves data and the migration runs; the ritual is export on all three handsets, install on top, import if a migration fails
**And** there is **no store distribution**, and the debug variant is **never installed on a validation handset** (AD-18)

**Given** the ritual's commands
**When** this story is complete
**Then** they are registered as `Makefile` targets — build, install-on-top, export, import — completing the file the epic plan owes here (NFR20)

**Given** the four-week validation window
**When** its start is gated
**Then** this epic is **complete first**, because AD-18's ritual has no teeth without it and a mid-window build would otherwise risk the evidence the window exists to produce

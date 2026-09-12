---
title: 'Story 7.4: The cumulative impact dashboard'
type: 'feature'
created: '2026-09-12'
status: 'done'
review_loop_iteration: 0
baseline_commit: '97ca605b357e98b05a22041cf7609997ce4cd7dd'
context: []
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** Completed work is invisible as a whole: the log holds every `card_done`, every `item_triaged` volume tag and every album entry, but no surface adds them up — progress can only be read as a fraction of what is owed.

**Approach:** One dashboard surface, reached from the Album only, rendering the achievement figures the log already holds — cumulative work minutes, completed Micro-tasks, liberated volume as approximation sentences, and the three newest album highlights — via one new core derivation (`derive/impact.dart`) whose record carries achievement figures only (AD-26's crossing list, nothing else).

## Boundaries & Constraints

**Always:**
- One denominator audit applies to every rendered value: no "de N", no average, no target, no period comparison, no rate, no percentage, no completion ratio — *if a value could be given a denominator, it does not belong on this screen* (UX-DR36, FR-23).
- AD-26 crossing list, closed set: cumulative minutes, completed Micro-tasks count, per-tag liberated volume tallies, album highlights. `liberatedItems` (the precise subtotal) and every internal signal stay core-side.
- Entry: from the Album only, via one quiet affordance; the dashboard is unreachable until a first transformation exists (contextual navigation, UX-DR31/32/51).
- Cumulative minutes reuse the walk's one charging table (`estimateSecondsOf`/rescue-own-estimate/purge 60 s) — charged on every `card_done` regardless of session state; never wall-clock, never pocket arithmetic.
- Volume renders as one approximation sentence per non-zero tag, shape `≈ 3 cajas liberadas`, unit visible, gender/plural correct per unit; the volume lines carry **no glyph** (glyph-adjacency, UX-DR37).
- `dashboard-highlight-row`: three columns `actionGap` apart; each cell is a Before/After pair of `PhotoFrame`s at `radiusThumb` (pair gap `spacingBase`) plus a support caption `place · short-date` (intl, `Formats.shortDateFormat`, locale `es`). Reflow trigger is measured in **lines** (`TextPainter` at candidate width, ambient scaler): any caption beyond two lines drops the **whole row** to one column per row — never shrink, never truncate, never scale the dp gaps (UX-DR30/46; the 200 % degradation is expected, not a defect).
- Figures render in `metricNumeral` (theme `titleMedium`), labels in support; title in `screenHeading` like the Album's. Density is the single declared exception and must not propagate (UX-DR35/36) — say so in the screen's library comment.
- Read discipline mirrors 7.3: one-shot read in `initState`, generation-guarded commit, read failure = quiet pending plate (close still works), empty album read = self-pop behind the `ModalRoute.isCurrent` guard (UX-DR51, defensive).

**Ask First:** None — every decision is pinned by epics 7.4, the UX spine and 6.7's hand-off.

**Never:** No snowball block (7.5's, and it moved to the ambient strip); no per-entry viewer or browse surface — a highlight tap pops back into the Album (guarded), same exit as `Volver al álbum`; no new LogKind, schema column, minter or write path (the dashboard is read-only — no `LogWriteQueue`); no bolsa↔caja equivalence (FR-22); no empty state or copy; no new glyphs (reuse `ClockGlyph`/`AlbumGlyph`; the volume line stays glyphless); `liberatedVolume`'s authored literal is superseded only by its parameterized family, never re-worded (UX-DR49).

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Open from album | ≥1 album entry | Title, minutes figure + label, micro-tasks figure + plural label, volume card, `Del álbum` + highlight row, `Volver al álbum` | — |
| Read fails | store/pool/catalogue read throws | Quiet pending plate; `Volver al álbum` still pops (guarded) | No error surface, no retry |
| Empty album read | 0 entries (stale affordance, defensive) | Screen pops itself behind `isCurrent` guard | — |
| Fewer than 3 entries | 1–2 album entries | Row renders 1–2 cells; no placeholder slots | — |
| Caption beyond two lines | long place or 200 % scale | Whole row renders one column per row; gaps unchanged; nothing truncated | — |
| Missing origin context | group lookup or `originContext` null | Dateless caption (date alone) | — |
| All volume tallies zero | no tagged liberated rows | Volume card absent entirely — no zero sentence, no method line | — |
| Sub-minute total | cumulative seconds < 60 | Existing `durationSeconds` figure; < 60 min uses `durationMinutes` | — |
| Highlight tap / double-tap pop | tap during transition | Single guarded pop; no viewer opens | — |

</frozen-after-approval>

## Code Map

- `packages/core/lib/weave/session.dart:84,139,455-489` -- `LogFacts` gains `cardDoneCount` + `answeredSecondsAllTime` (docs citing FR-23/AD-26), accumulated inside the single `cardDone` branch, **outside** the `openSessionStart` gate, via the existing `dealSizeOf`/`answeredSecondsOf` resolution (unknown ids charge nothing — AD-23 tolerance). One charging site, zero drift from the session ledger.
- NEW `packages/core/lib/derive/impact.dart` -- `ImpactRead` typedef (`answeredSecondsAllTime`, `cardDoneCount`, `liberatedBolsa/Caja/CajaGrande/Mueble`, `List<({String beforeName, String afterName, String? place, int addedUtcMicros})> highlights`) + `deriveImpact({required entries, required catalogue, required poolFacts})` composing `walkLog` + `deriveDeclutterMetric` + `albumEntries` + `epicGroupsByStableId(poolFacts)[groupId]?.first.originContext` for the place join; highlights = newest 3. The AD-26 crossing surface, named in one function.
- `packages/core/lib/derive/declutter_metric.dart:40-70` -- `DeclutterMetric` consumed verbatim; per-tag tallies cross, `liberatedItems` does not.
- NEW `packages/core/test/derive/impact_test.dart` -- machine-side matrix on the `declutter_metric_test.dart` convention: estimates charged session-independently (done outside any session still counts), rescue-own-estimates, purge 60 s, tallies, newest-3 ordering, null place, zero rows → zeros.
- NEW `lib/dashboard/dashboard_controller.dart` -- `DashboardController({required store, required files, required loadCatalogue})`; `read()` awaits `readLogEntries` + `readPoolFacts` + the catalogue (the `RewardController.read` queue-consistent shape, `reward_controller.dart:79-92`), returns `ImpactRead`; exposes `files` for `PhotoFrame`; rethrows (transient ≠ empty). No write side.
- NEW `lib/ui/dashboard/dashboard_screen.dart` -- built on the `AlbumScreen` skeleton (`album_screen.dart:59-150`): pending `AspectRatio(3/4)` plate; two metric rows (`ClockGlyph`/`AlbumGlyph` at `glyphDense`, mockup §3 `key-screens-1.html`); volume card (`radiusDefault`, `cardPadding`, surface base); highlight row with `LayoutBuilder` + `TextPainter` line measurement (never `maxLines`/`TextOverflow` — the lint bans them); `Volver al álbum` = guarded pop; library comment declaring the single density exception.
- `lib/ui/album/album_screen.dart` -- gains nullable `dashboard` param + one `SecondaryTextAction` (`albumOpenDashboard`) sited with the other secondary actions above the close; `_openDashboard` pushes `DashboardScreen` under the `isCurrent` guard; affordance renders only when `widget.dashboard != null` (7.3's gating pattern).
- `lib/ui/reward/reward_screen.dart` + `lib/ui/dispenser/dispenser_screen.dart` + `lib/main.dart:315-325` -- thread `DashboardController(store, files, loadCatalogue: …)` root → Dispenser → Reward → Album (the 7.3 seam hop extended one step; `loadEvergreenCatalogue(strings)` from `lib/catalogue/loader.dart:34`).
- `lib/l10n/app_es.arb` -- replaces `liberatedVolume` with the parameterized family `liberatedVolumeBolsa/Caja/CajaGrande/Mueble(count)` (ICU plurals, gender-correct, caja-other = the authored shape verbatim); adds `dashboardTitle` `Lo que ya has movido`, `dashboardWorkCaption` `de trabajo hecho, desde el primer día`, `dashboardWorkDuration(hours, minutes)` (`{hours}\u00A0h{minutes, plural, =0 {} other {\u00A0{minutes}\u00A0min}}`), `dashboardMicroTasksLabel(count)` plural, `dashboardVolumeMethod` `Contado en bolsas, cajas y muebles, tal como los fuiste marcando.`, `dashboardAlbumSection` `Del álbum`, `dashboardHighlightCaption(place, date)` `{place} · {date}`, `dashboardHighlightDatelessCaption(date)`, `dashboardBackToAlbum` `Volver al álbum`, `albumOpenDashboard` `Ver lo que ya has movido` — all mockup-verbatim or register-consistent, each `@` description carrying its rule (no denominator, no glyph, contextual-only). Then `make codegen`.
- `test/ui/album/album_screen_test.dart` + `test/ui/reward/reward_screen_test.dart` + `test/ui/app_test.dart:281-345` -- affordance gating (null seam on negative arms per 7-3's review lesson), hop-through pins `identical(...)` for the new seam; NEW `test/ui/dashboard/dashboard_screen_test.dart` drives the whole I/O matrix on the per-file fakes convention, including a 200 % `textScaler` pump asserting single-column reflow and unchanged gaps, and caption/figure rendering by `getRect`.

## Tasks & Acceptance

**Execution:**
- [x] `packages/core/lib/weave/session.dart` -- two all-time `LogFacts` fields at the single charging site.
- [x] NEW `packages/core/lib/derive/impact.dart` + NEW `packages/core/test/derive/impact_test.dart` -- the crossing derivation and its machine-side matrix.
- [x] NEW `lib/dashboard/dashboard_controller.dart` -- read-only controller.
- [x] `lib/l10n/app_es.arb` + `make codegen` -- the key set above, generated files committed.
- [x] NEW `lib/ui/dashboard/dashboard_screen.dart` -- the surface per Boundaries and the mockup.
- [x] `lib/ui/album/album_screen.dart` + `lib/ui/reward/reward_screen.dart` + `lib/ui/dispenser/dispenser_screen.dart` + `lib/main.dart` -- affordance and the seam hop.
- [x] NEW `test/ui/dashboard/dashboard_screen_test.dart` + edits to album/reward/app tests -- I/O matrix, gating, seam pins.

**Acceptance Criteria:**
- Given the album with entries, when the arm renders, then exactly one dashboard affordance appears — the app's only way into the dashboard; nothing in the Dispenser or reward offers it (UX-DR31/32).
- Given every rendered value, when the denominator rule is applied one value at a time, then none admits a denominator — the reviewable form (UX-DR36, FR-23).
- Given the figures reaching the shell, when classified, then exactly AD-26's four groups cross and nothing else — no internal signal, no `liberatedItems` subtotal (AD-26, AD-6).
- Given the highlight row at default scale, when rendered, then it is three columns `actionGap` apart, each a Before/After pair at `radiusThumb` with a place · short-date support caption (UX-DR30).
- Given any caption beyond two lines at any scale, when the row lays out, then the whole row reflows to one column per row, gaps unscaled, nothing truncated (UX-DR30/46).
- Given a highlight tap, when it fires, then the dashboard pops into the Album — no viewer, no browse surface (UX-DR30).
- Given a volume figure, when read, then it is an approximation with its unit in the authored shape, carries no glyph, and derives only from `item_triaged` tags (FR-22, UX-DR37/49).
- Given `make gate`, when it runs, then all targets pass — no seal edits, no forbidden-vocabulary hits, string-table audit and codegen green.

### Review Findings

- [x] [Review][Patch] Civil-day offsets are not unique per album entry [packages/core/lib/derive/impact.dart:101] — **Severity: medium.** `addOffsets` keys only `(groupId, addedUtcMicros)`, while the album fold distinguishes an entry by origin and its Before/After pair. Two same-group adds at the same instant therefore overwrite one another and both captions can receive the last row's offset. Preserve the offset with the entry identity and add a regression test.
- [x] [Review][Patch] Guard non-positive highlight candidate widths before measuring captions [lib/ui/dashboard/dashboard_screen.dart:434] — **Severity: low.** For a sufficiently narrow `LayoutBuilder` constraint, subtracting the inter-cell gaps can produce a zero or negative candidate width; `_lineCount` passes it to `TextPainter` before the one-column fallback. Clamp/branch to the one-column layout and cover a narrow constraint.
- [x] [Review][Patch] Pin the exact AD-26 crossing record shape [packages/core/test/derive/impact_test.dart:367] — **Severity: medium.** The test comment lists the intended seven fields but no assertion fails if `ImpactRead` grows an internal or denominator-bearing field. Assert the exact record field set, including the nested highlight shape.
- [x] [Review][Patch] Exercise the two-entry arm of the “1–2 highlights” matrix [test/ui/dashboard/dashboard_screen_test.dart:613] — **Severity: low.** The test title promises 1–2 entries but seeds only one, so the two-cell row and its gap/width behavior are unverified.
- [x] [Review][Patch] Make the read-only test fail on accidental writes [test/ui/dashboard/dashboard_screen_test.dart:42] — **Severity: low.** Both fake append methods are no-ops, so checking that the entry list length is unchanged cannot detect a write call. Record or throw on append and assert no append was attempted.
- [x] [Review][Patch] Assert that a highlight pop lands on `AlbumScreen` [test/ui/dashboard/dashboard_screen_test.dart:808] — **Severity: low.** The test places the dashboard over a blank home and only checks that `DashboardScreen` disappears; an incorrect destination would still pass. Put a real Album route beneath it and assert that route is the one revealed.
- [x] [Review][Patch] Expand the denominator audit beyond `%` and `/` [test/ui/dashboard/dashboard_screen_test.dart:732] — **Severity: medium.** The acceptance rule also bans textual forms such as “de N”, average, target, period comparison, rate and completion ratio; the current sweep would accept those regressions. Test the semantic deny-list or a rendered-copy census.
- [x] [Review][Patch] Pin the contextual-only negative arm on the Dispenser [test/ui/reward/reward_screen_test.dart:317] — **Severity: low.** The Album seam is tested and Reward's pre-pair arm is negative, but no screen test asserts that a non-null dashboard seam never exposes the dashboard affordance from the Dispenser/Reward path. Add the negative assertion at the actual Dispenser entry point.
- [x] [Review][Patch] Cover every volume unit's singular and plural arms [test/ui/dashboard/dashboard_screen_test.dart:712] — **Severity: low.** Current widget coverage exercises Caja plural and Caja grande singular, but not Bolsa plural, Caja grande plural, Mueble singular or Mueble plural, leaving the authored gender/number matrix partially unpinned.
- [x] [Review][Patch] Reconcile the manual seed arithmetic and row census [_bmad-output/implementation-artifacts/7-4-the-cumulative-impact-dashboard.md:108] — **Severity: medium.** The stated 16 focus + 3 maintenance + 2 instant captures total 15,000 seconds using the canonical estimates, not the reported 15,900 pool seconds; the report also claims 27 `card_done` rows without accounting for the six rows beyond those 21 captures. Document the complete row/estimate breakdown or correct the observed figures.

## Spec Change Log

## Design Notes

- **Why extend `LogFacts` instead of a parallel fold:** the walk already resolves every item's charge through one table; accumulating all-time totals at that site cannot drift from the session ledger. A second fold would re-resolve sizes and eventually disagree.
- **Why one sentence per volume tag, stacked:** FR-22 forbids unit equivalence, so tallies cannot collapse into one number; per-tag sentences keep each unit honest and dodge mixed-gender agreement. The common single-tag case renders exactly the mockup's one line. `liberatedItems` stays core-side: AD-26's crossing list names the volume, not the precise count.
- **Why pop instead of push on a highlight tap:** the Album is always directly beneath (contextual-only reach), so popping *is* the way into the Album; pushing would stack a duplicate gallery route for nothing.
- **Why `TextPainter` measurement:** the trigger must be in lines, not dp, and the lint bans `maxLines`/ellipsis/FittedBox anywhere in `lib/` — measuring at candidate width with the ambient scaler is the compliant first use; the rendered captions stay unconstrained.
- **Why `screenHeading` for the title:** the register the Album and reward titles use; the mockup's `action-primary` title predates the metricNumeral correction (its G2 note) and no spine rule licenses a second title register.

## Verification

**Commands:**
- `devbox run -- make gate` -- expected: check (incl. text-scaling, no-literal-strings, string-table audit, forbidden vocabulary), test, format-check, analyze all green.
- `wc -c` on this spec ≤ 24576 bytes at review presentation.

## Manual Verification (Android emulator, 2026-09-12)

**Environment (original implementation pass):** AVD `organizer36` (Pixel 6, API 36 `google_apis` x86_64, KVM), debug `app-debug.apk` @ `b90bb5e`, driven over adb; UI read via `screencap` + vision OCR, every figure cross-checked against the pulled substrate DB. The review-hardening patch was applied after this manual pass, so the APK hash identifies the manually verified base implementation, not this later patch. State synthesized by direct substrate seeding on a `pm clear`-fresh install: 4 single-step `local`-origin epic groups (one with a 60+ char place) + `epic_activated` + `before_saved` + 4 content-addressed JPEGs, 21 answered manual captures (16 focus/3 maintenance/2 instant) plus six additional `card_done` rows (five resolved through pool facts and one catalogue fallback), and 7 `item_triaged` rows (bolsa/caja/caja grande/mueble + keep + quarantine). Two machine-local pitfalls hit and fixed: blobs must go to `/data/data/<pkg>/files/album/` (the FilesPort root — NOT `app_flutter/files/`), and `item_triaged` rows must leave `item_id`/`item_origin` NULL (the read boundary flaws them out otherwise — which the screen itself proved by rendering zero until the rows were corrected).

**Seed arithmetic:** the 27 `card_done` rows reconcile by source and canonical estimate: 16 Focus captures × 900 s = 14,400 s; 3 Maintenance captures × 180 s = 540 s; 2 Instant captures × 30 s = 60 s; the 21 manual-capture rows therefore contribute 15,000 s. The five pool-fact-resolved rows are Maintenance rows × 180 s = 900 s, and the one catalogue fallback is a Focus row × 900 s = 900 s. Thus 21 + 5 + 1 = 27 rows and 15,000 + 900 + 900 = 16,800 s (`4 h 40 min`).

| Check | Observed |
|---|---|
| Contextual entry | `Ver lo que ya has movido` on the album only, sited between `Borrar todo` and `Cerrar`; no dashboard affordance anywhere on the Dispenser or reward ✓ |
| Figures | `4 h 40 min` + `de trabajo hecho, desde el primer día`; `27` + `micro-tareas hechas` — SQL parity: 21 manual rows / 15,000 s + 5 pool-fact Maintenance rows / 900 s + 1 catalogue Focus fallback / 900 s = 27 rows / 16,800 s ✓ |
| Volume card | Four sentences, gender/plural correct: `≈ 1 bolsa liberada`, `≈ 2 cajas liberadas` (authored shape), `≈ 1 caja grande liberada`, `≈ 1 mueble liberado` + method line; keep/quarantine rows contribute nothing ✓ |
| Flaw filtering | Screen tallies (1/2/1/1) = the 7 valid rows only; raw SQL over all 14 rows gives 2/4/2/2 — the read boundary's flaw discipline demonstrably holds on-device ✓ |
| Highlight row | Three columns at default scale, pairs side-by-side at thumb radius, captions `El balcón de casa · 13 sept` / `La mesa del salón · 12 sept` / `El trastero del pasillo · 2 sept` — newest-first, oldest two (incl. the long-place group) correctly excluded ✓ |
| Civil-day dates | Captions show each entry's own day (13/12 sept, 2 sept) under a device clock moved +25 h mid-pass ✓ |
| Real pair flow | Group milestone → Before renders (seeded kalimba photo) → `Hacer la foto` → virtual-scene After → pair lands → `Ver el álbum` appears ✓ |
| Highlight tap | Pops back into the Album — no viewer, no browse surface ✓ |
| 200 % font scale | Row reflows to one column per row, each unit full-width with its pair + caption; nothing truncated, nothing shrunk, `≈` sentences wrap naturally with no ellipsis ✓ |
| Log truth | 5 `album_entry_added` (4 seeded + 1 real), 2 `slice_requested/failed` (rescue attempts, degraded honestly), figures identical across re-entry ✓ |

**Manual checks (if no CLI):**
- On emulator per the AGENTS.md recipe: complete a transformation → album shows `Ver lo que ya has movido`; dashboard figures match a pulled-substrate SQL count (`card_done` rows, triage tags, album entries); long-place seed and 200 % font scale reflow the highlight row to one column with gaps unchanged.

## Suggested Review Order

**The derivation — the story's heart (entry point)**

- The crossing in one function: walk + declutter metric + album + place join, achievement figures only.
  [`impact.dart:85`](../../packages/core/lib/derive/impact.dart#L85)

- The single charging site: all-time count and seconds accumulated outside the session gate — zero drift from the ledger.
  [`session.dart:501`](../../packages/core/lib/weave/session.dart#L501)

- The two all-time folds, documented against AD-26 and AD-23 tolerance.
  [`session.dart:166`](../../packages/core/lib/weave/session.dart#L166)

- The civil-day recovery: each highlight's offset read back from its own `album_entry_added` row (AD-4).
  [`impact.dart:133`](../../packages/core/lib/derive/impact.dart#L133)

**The surface — the density exception**

- One-shot read, generation guard, empty-pop: the 7.3 skeleton inherited whole.
  [`dashboard_screen.dart:98`](../../lib/ui/dashboard/dashboard_screen.dart#L98)

- The measured reflow: candidate width, ambient scaler, lines not dp — the app's only one.
  [`dashboard_screen.dart:475`](../../lib/ui/dashboard/dashboard_screen.dart#L475)

- The glyphless volume card: one ICU sentence per non-zero tag, gate owned by the card.
  [`dashboard_screen.dart:308`](../../lib/ui/dashboard/dashboard_screen.dart#L308)

- The tappable cell as Semantics button — the way into the Album, named.
  [`dashboard_screen.dart:498`](../../lib/ui/dashboard/dashboard_screen.dart#L498)

**The seam — contextual navigation**

- The one affordance, guarded push, above the close: the app's only door to the dashboard.
  [`album_screen.dart:162`](../../lib/ui/album/album_screen.dart#L162)

- Root construction of the read-only controller; the hop begins here.
  [`main.dart:152`](../../lib/main.dart#L152)

- The hop's two hand-downs: Dispenser → Reward, Reward → Album.
  [`dispenser_screen.dart:910`](../../lib/ui/dispenser/dispenser_screen.dart#L910) · [`reward_screen.dart:181`](../../lib/ui/reward/reward_screen.dart#L181)

**Copy — the single string table**

- The parameterized volume family: authored shape verbatim, NBSP binding the mark to its count.
  [`app_es.arb:159`](../../lib/l10n/app_es.arb#L159)

**Peripherals — the pins**

- The machine-side matrix: session-independent charging, rescue estimates, purge 60 s, civil-day offsets.
  [`impact_test.dart:1`](../../packages/core/test/derive/impact_test.dart#L1)

- The widget matrix's crown: 200 % reflow by measurement, gaps unscaled.
  [`dashboard_screen_test.dart:495`](../../test/ui/dashboard/dashboard_screen_test.dart#L495)

- Literal pins and the denominator sweep — the shape asserted, not self-referenced.
  [`dashboard_screen_test.dart:360`](../../test/ui/dashboard/dashboard_screen_test.dart#L360)

- The siting pin: the affordance above the close, existence alone not enough.
  [`album_screen_test.dart:657`](../../test/ui/album/album_screen_test.dart#L657)

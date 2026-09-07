---
title: 'Story 5.6: The unbounded wait and honest abandonment'
type: 'feature'
created: '2026-09-07'
status: 'done'
review_loop_iteration: 1
baseline_commit: 'd82592e4411a3546cf5814f916353f99f8100c5f'
context:
  - '{project-root}/_bmad-output/implementation-artifacts/epic-5-context.md'
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** After `Enviar la foto`, the wait is a static `Creando tareas` text (`consent_gate_screen.dart:242-258` — the surface 5.5 itself marked as 5.6's stand-in): no motion, so activity reads as a stall, and FR-16's "visible progress and honest copy" is unmet. And when the user leaves mid-wait — back or background — the scan closes silently with no record: the naming table's `scan_abandoned` (`ARCHITECTURE-SPINE.md:225`, AD-8's resolution cause) exists nowhere, so FR-26's audit trail cannot see a single abandonment.

**Approach:** Turn the gate's accept arm into the real wait surface — `scanWaitTitle` beside the app's first and only sanctioned animation, an indeterminate writing pencil on the glyph discipline — and mint `scan_abandoned` (the twentieth kind: payload-less **user act**, never contact) inside `close()` whenever a dispatch stands, so OS-back and backgrounding both record the departure, cancel and discard through the existing epoch-stale machinery, and queue nothing. The delivered arm stays the interim P2-A quiet close — the landing is 5.7's.

## Boundaries & Constraints

**Always:**
- Copy is closed: `scanWaitTitle` (`app_es.arb:216`) is the only wait string — **zero new ARB keys**, string table byte-identical. No percentage, duration, queue position or timeout may appear on any surface or string (UX-DR56, `EXPERIENCE.md:201`).
- The pencil is the app's first animation and stays its only one: `AnimationController` + `CustomPainter` per the glyph discipline (`glyph_canvas.dart` two-plate treatment, 24-unit viewBox scaling, theme ink), geometry derived from the authored `PencilGlyph` paths (`pencil_glyph.dart:11-74`); an indeterminate constant loop whose period is a behavior const beside its only reader (the `_completionAckWindow` precedent, `dispenser_screen.dart:88-92`); honors `MediaQuery.disableAnimations` with a resting pose; **no Semantics** (the spine's interim no-custom-semantics rule `:240`; the app-wide a11y pass is the 5.5 deferral); no dash arcs — the seed's dissolved motion-dash ban stands.
- Abandonment minting lives in `close()` gated on a dispatch standing (consent granted ∧ `slice()` in flight): one `scanAbandoned()` row enqueued through the write queue **without** an epoch re-check inside the closure — the row exists because of the close (mirror `_appendConsentGranted` :624-633; do **not** copy `_appendConsentDeclined`'s in-closure re-check :607). Every `grantConsent()` exit clears the in-flight flag so a post-resolution dispose mints nothing. The late slice landing stays epoch-stale: no second row, no routing (`:584-588` unchanged).
- `scan_abandoned` is a payload-less **user act** per the naming table (`:225` — the user leaving or backgrounding; AD-8's resolution cause), classified a moment via `_isMoment` (the R1 lesson: a payload-less kind outside the families vanishes as `unclassifiedKind`, `log_entry.dart:1122`), and **never contact** — `warm_return.dart:94-100`'s default already excludes it; no derivation change.
- Wait register: the gate screen's accept arm, full-screen standing alone — the illustration register's exemption (`DESIGN.md:548`) on the existing layout grammar (SafeArea → SingleChildScrollView → 480 max-width, `surfaceBase`); the pair is gone the frame the answer lands. Failure keeps the existing no-Slicer routing; delivered keeps the interim quiet pop (5.7 replaces exactly that arm).
- Core stays pure, substrate grows additively only, every gate inside devbox.

**Ask First:**
- Any new string, semantics label, or ARB edit of any kind.
- Any change to the epoch/`close()`/unlink semantics beyond the additive row, or to 5.5's outcome routing.
- Any animation dependency (lottie, rive, flutter_animate) — the pencil is hand-built; a package is scope creep.
- If renegotiating the `pumpAndSettle` accept-arm tests cannot stay additive (e.g. it wants a repo-wide pump helper).
- If any census (`bannedWireNames`, append/invocation pins, kind census) cannot renegotiate additively.

**Never:**
- No latency cap, no timeout, no progress/percentage/duration semantics anywhere (FR-16).
- No landing: delivered stays the interim discard; no pool facts, banding, Origin Context, one-card (5.7). No scan-side `slice_*` rows — outcome vocabulary is 5.7's.
- No queueing, no retry, no second dispatch; the answered pair never returns.
- No new route or surface file for the wait itself (it lives on the gate's accept arm; the pencil widget file is the one new file); no `PopScope` — OS back remains the one way out, and leaving is abandoning.
- No motion outside the pencil; no motion DESIGN tokens added to `tokens.dart`.
- No face-gate composition change (P1), no shoot-side quiet-close renegotiation (P3 — retro), no egress/cap/token/`ScanConsent` changes.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Wait render | Accept answered, dispatch in flight | Full-screen wait: `Creando tareas` + indeterminate animated pencil; pair gone same-frame | N/A |
| Delivered mid-wait | `SlicerDelivered` | Interim quiet pop to the Dispenser; no row; unlink (5.7's arm) | N/A |
| Failed mid-wait | `SlicerFailed(cause)` | `NoSlicerSurface(noSlicerCauseFromFailure(cause))`; unlink | 4-5 mapping unchanged |
| Back out mid-wait | OS back during the wait | One `scan_abandoned` row + unlink + pop; late landing stays stale | Quiet |
| Background mid-wait | `hidden`/`paused`/`detached` | One `scan_abandoned` row + unlink; nothing resumes or queues | Quiet |
| Transient occlusion | `inactive` → `resumed` | Wait holds, no row (5.2/5.5 contract) | Hold |
| Leave before answer | Back on the unanswered gate | No row — leaving before consent is neither declining nor abandoning | Quiet |
| Close after resolution | Dispose following delivered/failed/stale | No `scan_abandoned` — no dispatch stands; close idempotent | Quiet |
| Reduced motion | `MediaQuery.disableAnimations` true | Pencil at its resting pose; title still renders | N/A |
| Rapid second answer | Double-tap on the pair | One decision, one dispatch (`_consentTaken`); second tap is nothing | Existing guard |
| Test pumping | Repeating pencil in widget tests | Fixed-duration pumps only; no `pumpAndSettle` while the pencil animates | Test discipline |

</frozen-after-approval>

## Code Map

<!-- Anchors from the post-5.5 working tree (baseline d82592e). Expect drift in landed files. -->

- `lib/ui/scan/consent_gate_screen.dart` -- THE surface. Accept-arm static text :242-258 (with 5.5's reservation comment :244-249) becomes the wait: title + pencil. `_accept` :173-204 awaits `grantConsent()` and routes outcomes (delivered pop :190, failed :191-197, stale pop :198-202) — routing unchanged. Lifecycle :102-121 (`hidden`/`paused`/`detached` → close; `inactive`/`resumed` hold) and `dispose()` :124-135 are the two departure paths — both already converge on `close()`. Layout grammar :207-235 (SafeArea/ScrollView/480/`surfaceBase`). No `PopScope` anywhere in the chain.
- `lib/ui/scan/writing_pencil.dart` -- NEW: the pencil widget + painter, the only new file. Follow `lib/ui/glyphs/glyph_canvas.dart:37-157` (TreatmentPainter, viewBox 24, plates/ink) with `PencilGlyph`'s authored paths (`lib/ui/glyphs/pencil_glyph.dart:11-74`) as the base geometry plus an indeterminate phase parameter; period const lives here; `disableAnimations` → rest pose; no Semantics.
- `lib/scan/scan_controller.dart` -- the abandonment seam. `grantConsent()` :548-595 (guards :549-554, epoch capture :556, mint :559, `consent_granted` append :560, dispatch :563-570, throw containment :571-583, stale :584-588, unlink :589-590): gains a `_sliceInFlight` flag set once the guards pass and cleared on **every** exit arm. `close()` :387-392 mints `scanAbandoned()` through a `_appendScanAbandoned` wrapper on the `_appendConsentGranted` shape :624-633 (no in-closure epoch re-check), then proceeds — unlink/epoch/camera-dispose unchanged. Rows ride `_appendContent` :435-454 via `LogWriteQueue`; epoch mechanics :209/:388; `releaseCamera()` :401-404 (no epoch bump — not our path).
- `packages/core/lib/log/log_entry.dart` -- the twentieth kind: constant after :113, `knownByName` after :135, `_isMoment` member :637-642, `MomentEntry` doc mention :205-213, header chronicle :24-29 (cite FR-16, AD-8, AD-21, naming-table user-act register). The vanishing mechanism to avoid: :1122.
- `packages/core/lib/commands/scan_commands.dart` -- `scanAbandoned()` on the `consentDeclined()` shape :96-114 (exactly one payload-less row, all 13 payload fields null); header :1-20 gains the minter sentence ("the single sanctioned minter…").
- `packages/core/lib/derive/warm_return.dart` -- READ-ONLY: :94-100 already defaults new moments to not-contact; the same-pass rule :74-75/:97-99 is satisfied by leaving the default and pinning it in tests.
- Tests to renegotiate: `packages/core/test/log_test.dart` :43-88 (census 19→20: title, name list, wire list, `hasLength(20)` :87); `packages/core/test/scan_commands_test.dart` (new group on the :134-190 pattern: payload-less row, moment conversion, payload exclusion); `packages/core/test/warm_return_test.dart` (non-contact pin on the :362-385 pattern, `_abandoned` helper beside :138-143); `packages/core/test/no_lateness_proof_test.dart` (mint census :2186-2193 already whitelists `lib/scan/scan_controller.dart` — no change); root `test/no_lateness_proof_test.dart` :360-376/:406-444 (append census + content counts renegotiate additively; a `scanAbandoned(` ×1 invocation pin is the pattern); `test/scan/scan_controller_test.dart` :750-801 (the stale tests renegotiate: close mid-dispatch now expects exactly one `scan_abandoned` row; no row pre-answer or post-resolution; `_FakeSlicer.gate` :196-223 holds the wait open); `test/ui/scan/consent_gate_screen_test.dart` :251-276/:271/:292-301/:329 (wait pins replace the static-text pins; fixed-duration pumping; abandonment matrix — the stale-mid-dispatch template is :381-401; lifecycle simulation :350-379); `test/ui/scan/scan_screen_test.dart` :465-495 (accept-path `pumpAndSettle` callers).
- Read-only: `lib/egress/*` (the seal), `lib/ui/no_slicer/no_slicer_surface.dart` (the register, :42/:126-146), `lib/main.dart` :96-104 (no new seams — the wait rides `grantConsent()`), `lib/l10n/app_es.arb` :216, `Makefile` :44-60.
- Planning anchors: `ARCHITECTURE-SPINE.md` :92-96 (AD-8), :182-186 (AD-21), :225 (naming table — user act), :240 (no custom semantics); `epics.md` :2012-2031 (the three ACs), :88 (NFR5 latency exemption); `EXPERIENCE.md` :107/:201; `DESIGN.md` :547-550 (illustration register); `ux-organizer-2026-08-21/.memlog.md` :204-205 (moving affordance; no percentage/duration/queue/timeout).

## Tasks & Acceptance

**Execution:**
- [x] `packages/core/lib/log/log_entry.dart` -- add `scanAbandoned` (twentieth kind): constant, `knownByName` row, `_isMoment` membership, `MomentEntry` doc mention, header chronicle sentence (user act per the naming table, AD-8's resolution cause, asserts nothing) -- the vocabulary grows additively (AD-23)
- [x] `packages/core/lib/commands/scan_commands.dart` -- `scanAbandoned()`: exactly one payload-less content row, the kind's single sanctioned minter, header sentence -- no second writer can appear silently
- [x] `packages/core/test/log_test.dart` + `scan_commands_test.dart` + `warm_return_test.dart` -- census 19→20 (title, both lists, `hasLength`); minter row-shape group (payload-less, moment conversion, payload exclusion); non-contact pin (abandonment alone at 96 h → not due; 49 h-open + 47 h-abandon → still due) -- the same-pass rule's tests
- [x] `lib/scan/scan_controller.dart` -- `_sliceInFlight` set after the grant guards, cleared on every exit; `close()` mints one `scanAbandoned()` row via a no-recheck `_appendScanAbandoned` wrapper when a dispatch stands, before the existing unlink/epoch/camera steps -- departure is the resolution cause (AD-8)
- [x] `lib/ui/scan/writing_pencil.dart` -- NEW: pencil widget + phase-parameterized painter on the glyph discipline, indeterminate constant loop, local period const, `disableAnimations` rest pose, no Semantics -- the app's first animation, leaking no conventions
- [x] `lib/ui/scan/consent_gate_screen.dart` -- the accept arm becomes the wait: `scanWaitTitle` beside the animated pencil in the illustration register; routing, lifecycle and dispose untouched -- UX-DR56 lands where 5.5 reserved it
- [x] `test/scan/scan_controller_test.dart` -- renegotiate the stale matrix additively: close mid-dispatch → exactly one `scan_abandoned` row + unlink + late landing stale; close pre-answer / post-resolution → no row; background-equivalent close mid-wait covered by the same close() path
- [x] `test/ui/scan/consent_gate_screen_test.dart` (+ `scan_screen_test.dart` accept-path callers) -- wait pins (title renders, pencil present, pair gone, no progress semantics), abandonment matrix (back mid-wait → row + pop; paused → row; `inactive` holds; post-resolution dispose → no row; reduced motion → rest pose), fixed-duration pumping replacing `pumpAndSettle` on the accept arm
- [x] Root `test/no_lateness_proof_test.dart` -- additive renegotiation: `scanAbandoned(` invocation pin (×1, `lib/scan/scan_controller.dart`); the append/content censuses stay UNCHANGED — `_appendScanAbandoned` rides the shared `_appendContent` copier, so no new `.appendLogEntry`/`content.kind.name` site exists to list; `bannedWireNames` unchanged
- [x] Gate -- `make gate` + `make check` green inside devbox; ARB byte-identical; egress untouched

**Acceptance Criteria:**
- Given a granted consent, when the upload runs and the wait renders, then it is in-app, in the foreground, full-screen in the illustration register — `Creando tareas` beside an indeterminate animated writing pencil — with no latency cap, no timeout, and nothing that reads as percentage, duration or queue position (FR-16, UX-DR56).
- Given the user leaves the scan surface or backgrounds the app mid-wait, when the scan resolves, then the wait was cancelled and discarded: exactly one payload-less `scan_abandoned` row stands, the cache subdirectory is unlinked, the late landing records nothing more, and nothing is queued (FR-16, AD-8, AD-21).
- Given the wait affordance, when it is inspected, then the copy is `Creando tareas` verbatim with zero new ARB keys, the pencil is the only motion on the surface, and OS back is the only exit (UX-DR56, UX-DR52).
- Given `scan_abandoned`, when the log is read, then it is the twentieth known kind, converts as a moment (never `unclassifiedKind`), is a user act per the naming table, and is not contact — warm return is unmoved by an abandonment (AD-21, FR-26).
- Given the diff, when the seals are inspected, then egress, cap, mime truth and `ScanConsent` semantics are byte-untouched, the string table is unchanged, the delivered arm is still the interim discard, and no scan-side `slice_*` row exists (5.7's).

## Design Notes

- **Why `close()` mints the row.** Both departure paths — `dispose()` on the pop and the lifecycle handler's `hidden`/`paused`/`detached` — already converge on `close()`; minting there needs no new surface API, cannot be forgotten by a future surface, and matches AD-8's wording: the departure *is* the resolution cause. The in-flight flag is the only new state, and every `grantConsent()` exit clears it so an ordinary post-resolution dispose stays rowless.
- **Why no epoch re-check in the closure.** `consent_declined` suppresses its row when a close wins the race because the row asserts a decision the close voided; `scan_abandoned` is the opposite — the close is what makes the row true. Mirror `consent_granted` (:624-633), not `consent_declined` (:607).
- **Why a user act, not a system event.** The spine's naming table (:225) classes `scan_abandoned` with user acts (departure-caused) and AD-21's system-event enumeration excludes it; `epic-5-context.md:51`'s "system events" phrasing is the looser summary. Either way the load-bearing outcome is identical — never contact — and `warm_return`'s default delivers it without a code change; the spec resolves the wording in the spine's favour.
- **Why the pencil is hand-built and token-less.** No animation dependency exists in the pubspec and none may appear; no motion DESIGN tokens exist, and the one behavior constant (the period) lives beside its only reader per the `_completionAckWindow` precedent. Reduced motion honors the OS setting with a rest pose rather than forcing movement — the title still communicates activity.
- **The `pumpAndSettle` hazard.** A repeating animation never settles; every existing accept-arm test that settles after the tap must move to fixed-duration pumps. This is the one place 5.6 touches already-green tests beyond additive row assertions — renegotiate the pumping, not the assertions.

## Verification

**Commands:**
- `devbox run -- make gate` -- expected: green (format, analyze, all tests including the 20-kind census and the renegotiated stale matrix)
- `devbox run -- make check` -- expected: green — string-table audit unchanged (byte-identical ARB), no-literal-strings green with zero new keys, seals untouched
- `devbox run -- flutter test test/scan/ test/ui/scan/ packages/core/test/log_test.dart packages/core/test/scan_commands_test.dart packages/core/test/warm_return_test.dart` -- expected: exit 0 (the abandonment matrix green)

**Manual checks (if no CLI):**
- On the emulator (AGENTS.md recipe): grant consent with a gated provider and verify the pencil moves with no progress semantics; system-back mid-wait → Dispenser, and the substrate log (`organizer_substrate.sqlite`) shows exactly one `scan_abandoned`; background/resume mid-wait → same row, no queue behavior; `inactive` occlusion (permission shade) → wait holds; OS reduce-motion on → pencil rests.
  - Coverage note (2026-09-07): the device pass covered back-out abandonment (exactly one `scan_abandoned` in the substrate, nothing more after the late landing) and the moving pencil with no progress semantics; background/resume, the `inactive` hold and reduced motion are widget-test-verified (see Completed Verification below).

## Completed Verification (2026-09-07)

**CLI (all green, devbox):**
- `make gate`: 989 tests pass (985 + 4 added by the review patches), `dart format --set-exit-if-changed` clean, `flutter analyze` clean.
- `make check`: all 15 tool checks pass (string-table audit unchanged, ARB byte-identical — `git diff` empty over `lib/l10n/`, `lib/egress/`, `packages/core/lib/ports/scan_consent.dart`; forbidden vocabulary, store seal, egress seals, codegen freshness).
- Focused command (test/scan, test/ui/scan, log_test, scan_commands_test, warm_return_test): exit 0.

**Device (emulator organizer36, AGENTS.md recipe; screencap + vision-OCR):**
- Full chain driven: provider selected (Gemini, bogus key), Cámara → shoot (virtual scene passes the face gate) → consent gate renders verbatim → `Enviar la foto`.
- Wait held open by blackholing outbound 443 (`adb root` + iptables DROP — the "gated provider"): `Creando tareas` beside the line-art pencil, no progress semantics anywhere; two captures ~2 s apart show the pencil in different poses (motion confirmed), all text identical.
- System back mid-wait → Dispenser; substrate log shows exactly `consent_granted 09:25:22` then `scan_abandoned 09:27:08`, nothing more after the late landing (re-pulled DB unchanged 3 min later — no second row, nothing queued). Network restored, emulator killed after.
- Not device-driven: the `inactive` hold and reduce-motion rest pose (widget tests pin both: `FakeAccessibilityFeatures(disableAnimations: true)` settles, proving the loop stops).

### Review Findings

- [x] [Review][Patch] A close landing between the `consent_granted` append and the dispatch still egressed the frame and consumed the token — no epoch re-check guarded the dispatch's launch [lib/scan/scan_controller.dart] — and a close landing during the tail `_unlinkCaptured` (after the resolution's epoch check passed) minted `scan_abandoned` for a dispatch that had already resolved. — Fixed: epoch re-check added after the grant append (a departure now precedes zero egress — "cancelled and discarded" made literally true), and `_sliceInFlight` clears at each resolution point before the tail unlink (the `finally` stays as backstop); two gated-fake tests pin both windows (zero `slice()` calls + rows `[consent_granted, scan_abandoned]`; tail-unlink close → no row, delivered routes).
- [x] [Review][Patch] The wait's painter transcribed `PencilGlyph`'s authored geometry into a second private definition (drift risk against its own "one place" comment) and rebuilt the phase-independent paths every tick (~5 `Path` allocations at 60 fps). — Fixed: the geometry is single-sourced as public static builders on the glyph side, consumed by both painters (no visual change), with the static paths cached once; the amplitude comment now states the true math (1.3u of the 19.06u pencil ≈ 7%) and the π/3 wobble offset carries its rationale.
- [x] [Review][Patch] The first continuous animation had no `RepaintBoundary`, so every tick repainted the whole gate layer. — Fixed: both CustomPaint branches wrapped; the tick stays inside the pencil's layer.
- [x] [Review][Patch] `initState` started the loop unconditionally before `didChangeDependencies` could consult `disableAnimations`, giving reduced-motion users a started-then-stopped ticker. — Fixed: `didChangeDependencies` (always run before first build) owns the loop's whole lifecycle.
- [x] [Review][Patch] The abandonment append's quiet store-failure absorption was unobserved by any test, and its future is awaited inside `close()` — the one row-writer whose failure could escape into the terminal close. — Fixed: `_ThrowingAppendStore` (the dictation suite's precedent) pins that a mid-wait `close()` against a throwing store completes with unlink and camera dispose intact.
- [x] [Review][Patch] The "second tap" gestures in the widget suite warned `warnIfMissed` (a bare `Text` and an already-replaced pair), passing vacuously for the tap itself. — Fixed: the wait-title tap dropped in favour of the structural no-InkWell + once-guard assertions; the double-decline's second tap is a real `tapAt` at the first tap's captured centre — both suites now run with zero `warnIfMissed`.
- [x] [Review][Patch] No test proved the pencil actually moves (a frozen-at-phase-0 loop passed everything), and the reduced-motion pin matched any `CustomPaint`. — Fixed: a two-pump phase test reads the rendered `WritingPencilPainter.phase` (0 at rest → 0.125 after 300 ms), and the reduced-motion test now asserts the painter type at phase 0.
- [x] [Review][Patch] Test/doc hygiene: the ~10 unexplained 600 ms pumps extracted as `routePopSettle` with one rationale comment; a redundant `hasLength` duplicating a kind-map equality removed; `sprint-status.yaml`'s `last_updated` regained its time component; the Execution task's "censuses grow" wording amended to what landed (unchanged censuses riding `_appendContent`; only the invocation pin added).
- [x] [Review][Reject] `_sliceInFlight` set before the mint/append window "disagrees" with the frozen "dispatch stands" wording — rejected: with the pre-dispatch epoch check, a departure in that window records exactly the honest pair (row + zero egress), which is the intent's one possible reading ("the wait has begun"); the code comments record it.
- [x] [Review][Reject] Cross-scan queue chronology unpinned; `close()` awaiting the row extends the standing unbounded-await family; NaN size guard — rejected: marginal or unreachable, and the no-timeout recovery contract is already the house's deferred 2-3 family.
- [x] [Review][Patch] A stale `grantConsent()` can clear a newer scan's `_sliceInFlight`, losing its abandonment row [lib/scan/scan_controller.dart:649-650] — the flag is controller-global and `finally` clears it unconditionally; if scan A is closed, scan B opens and begins waiting before A's late slice resolves, A's stale `finally` clears B's flag and closing B records no `scan_abandoned`. Fixed: the clear is epoch-scoped, with a controller-reuse regression covering two abandoned waits.
- [x] [Review][Patch] Phase zero is not the authored resting pose [lib/ui/scan/writing_pencil.dart:181-183] — `sin(π/3) * 3` rotates the pencil at phase 0, including the reduced-motion path; fixed: the wobble is normalized to zero at phase 0 and the rendered pose is pinned.
- [x] [Review][Patch] The wait title is stacked above rather than beside the pencil [lib/ui/scan/consent_gate_screen.dart:278-289] — the `Column` contradicts UX-DR56 and the explicit acceptance criterion; fixed: the wait uses a side-by-side `Row` with wrapped text while preserving the 200% scroll behavior.
- [x] [Review][Patch] The failed-resolution tail race lacks regression coverage [test/scan/scan_controller_test.dart:869-900] — only the delivered tail-unlink close is exercised; if the flag clear is removed from the failed/throw paths, a resolved scan can mint `scan_abandoned`. Fixed: gated failed and throwing-resolution tests cover the tail.
- [x] [Review][Patch] The only wait affordance has no rendered-output assertion [lib/ui/scan/writing_pencil.dart:179-224; test/ui/scan/consent_gate_screen_test.dart:321-342] — tests check widget presence and numeric phase only, so a blank painter or incorrect resting pose passes; fixed: a canvas raster assertion covers authored/rest/moved output in both palettes.

Second review round (2026-09-07, four context-free layers + acceptance audit):

- [x] [Review][Decision] The wait pair's presentation at the 200% floor — lost centering and a horizontal overflow risk [lib/ui/scan/consent_gate_screen.dart:277-292] — resolved 2026-09-07 (Sergio): **smaller pencil at narrow widths** — `beside` holds at every width, the mark yields size; implementation is the patch item below, fenced by the 200% pin. (Context: the accept arm's `Row` stretched the 480-unit column — pencil flush-left, title centered only in the remainder — and at the tested floor (320-wide, 200%) the title column got ~88px while "Creando" at bodyMedium×2 measures ~105–110px, a RenderFlex overflow the vertical `SingleChildScrollView` cannot absorb.)
- [x] [Review][Decision] The epoch/`close()` extensions beyond the frozen "additive row" — ratified 2026-09-07 (Sergio): the extensions stand as shipped; the Ask-First gate is considered exercised by the round-1 review loop. (Context: the pre-dispatch epoch re-check, the per-arm `_sliceInFlight` clears before each tail unlink, and the epoch-scoped `finally` change epoch semantics the frozen Ask-First list reserves for the human; each is protective and documented as an accepted [Patch] entry above.)
- [x] [Review][Patch] The wait pair's layout after the presentation decision [lib/ui/scan/consent_gate_screen.dart:277-292] — recenter the pair (`MainAxisSize.min` row, the register's standing-alone mark) and make the pencil yield size at narrow widths so `beside` holds with no horizontal overflow at the 200% floor (the 160 constant stays the at-rest register size; below the width where 160 + gap + longest title word fits, the pencil shrinks).
- [x] [Review][Patch] No 200% font-scale pin renders the changed wait `Row` [test/ui/scan/consent_gate_screen_test.dart:311-360] — every wait test runs at 1.0 on 800×600, while the sibling suites pin the floor (the dispenser pattern); add the pin at 320-wide + `textScaleFactor` 2.0 with fixed-duration pumps once the presentation decision lands — it is the regression fence for the overflow above.
- [x] [Review][Patch] Five row-append wrappers share one enqueue/copy shape [lib/scan/scan_controller.dart:493-714] — `_appendPermissionRefusal`, `_appendFaceRefused`, `_appendConsentDeclined`, `_appendConsentGranted`, `_appendScanAbandoned` differ only in the minter called (and the declined-only in-closure re-check); extract the common body, keeping the census pins intact (`scanAbandoned(` stays ×1, `appendLogEntry` stays the single `_appendContent` site).
- [x] [Review][Patch] `hidden` and `detached` departures have no abandonment pin [test/ui/scan/consent_gate_screen_test.dart:597-631] — the spec's I/O matrix names all three backgrounding states, but only `paused` is simulated; add the two one-line lifecycle sims asserting the same `[consent_granted, scan_abandoned]` rows (the states share one switch arm).
- [x] [Review][Patch] Reduced-motion stop/restart branches untested [lib/ui/scan/writing_pencil.dart:89-97; test/ui/scan/consent_gate_screen_test.dart] — no test toggles `disableAnimations` while the loop runs, so a regression that never restarts (or never stops) passes; pin the mid-flight stop (rest pose) and the restart.
- [x] [Review][Patch] Read-boundary payload exclusion pinned for 2 of 12 payload fields [packages/core/test/scan_commands_test.dart:223-257] — only `itemOnNonItemKind` and `permissionOnNonPermissionKind` are pinned for `scan_abandoned`; assert the converted moment carries no payload across the whole record so a read-side family drift on any field fails.
- [x] [Review][Patch] `PencilGlyph` publishes ten members nothing outside the file uses [lib/ui/glyphs/pencil_glyph.dart:22-73] — only `shaftPath`/`linePaths`/`axisX`/`axisY` are consumed by the two painters (and the raster test); make the internal geometry library-private (`seed_glyph` exposes none — there is no house pattern of public glyph geometry).
- [x] [Review][Patch] Tail-race double unlink masked by `toSet()`/`isNotEmpty` [test/scan/scan_controller_test.dart:869-912] — both the close's `_unlinkScan()` and the resolution's tail `_unlinkCaptured(scanId)` unlink the same scanId in that window; the port delete is idempotent by contract, so assert the exact list with a comment recording the accepted no-op instead of masking it.
- [x] [Review][Patch] `review_loop_iteration: 0` while the Review Findings record ~15 applied patches [_bmad-output/implementation-artifacts/5-6-the-unbounded-wait-and-honest-abandonment.md:6] — stale frontmatter misrepresents the review history; bump it to reflect the applied findings round.
- [x] [Review][Patch] Throwing-store test omits `readSelectedProvider` [test/scan/scan_controller_test.dart:965-973] — every other inline `ScanController` construction in this diff passes `() async => 'gemini'`; make the seam setup uniform (the omission is inert — `grantConsent` never reads it — but reads as an oversight).
- [x] [Review][Patch] `bannedWireNames` census comment overstates its list [test/no_lateness_proof_test.dart:195-220] — "every user-act and moment kind" omits `consent_granted`/`consent_declined` (pre-existing drift) and now `scan_abandoned`; the list itself was deliberately left unchanged (the invocation pin fences the new kind), so reword the comment to the accurate claim.

## Suggested Review Order

**The abandonment act — the departure is the resolution cause**

- The heart: `close()` mints exactly one `scan_abandoned` when a dispatch stands, before the terminal steps.
  [`close():410`](../../lib/scan/scan_controller.dart#L410)

- The pre-dispatch epoch check: a departure before the launch means zero egress, no token spent.
  [`grantConsent:599`](../../lib/scan/scan_controller.dart#L599)

- The flag clears at each resolution point — a close during the tail unlink mints nothing.
  [`resolution clears:629`](../../lib/scan/scan_controller.dart#L629)

- The row writer: no in-closure epoch re-check — the close is what makes the row true.
  [`_appendScanAbandoned:701`](../../lib/scan/scan_controller.dart#L701)

**The wait surface — the app's first animation**

- The accept arm: `Creando tareas` beside the pencil, pair gone, routing untouched.
  [`wait arm:278`](../../lib/ui/scan/consent_gate_screen.dart#L278)

- The widget: `didChangeDependencies` owns the loop (reduced motion never starts it); the tick stays inside its layer.
  [`WritingPencil:66`](../../lib/ui/scan/writing_pencil.dart#L66)

- The painter: static paths cached once, gesture applied to the authored geometry.
  [`WritingPencilPainter:152`](../../lib/ui/scan/writing_pencil.dart#L152)

- Single-sourced geometry: the glyph's own builders, consumed by both painters.
  [`PencilGlyph.shaftPath:73`](../../lib/ui/glyphs/pencil_glyph.dart#L73)

**The vocabulary — the twentieth kind**

- `scan_abandoned`: user act, moment, never `unclassifiedKind`.
  [`LogKind.scanAbandoned:119`](../../packages/core/lib/log/log_entry.dart#L119)

- The single sanctioned minter — one payload-less row, asserts nothing.
  [`scanAbandoned():132`](../../packages/core/lib/commands/scan_commands.dart#L132)

**The pins**

- Both race windows held open by gated fakes: append-brake (no dispatch) and tail-unlink (no row).
  [`append-brake test:836`](../../test/scan/scan_controller_test.dart#L836)

- A throwing store cannot stall the terminal close — quiet absorption, now observed.
  [`throwing-store test:911`](../../test/scan/scan_controller_test.dart#L911)

- The widget abandonment matrix: back mid-wait, paused, `inactive` hold, reduced motion, the pencil moves.
  [`back mid-wait:479`](../../test/ui/scan/consent_gate_screen_test.dart#L479)

- Census 19→20 and the non-contact pin — warm return unmoved by a departure.
  [`census:43`](../../packages/core/test/log_test.dart#L43)

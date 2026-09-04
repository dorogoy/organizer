---
title: 'Honest degradation — one calm surface, seven strings, one exit'
type: 'feature'
created: '2026-09-03'
status: 'done'
review_loop_iteration: 0
baseline_commit: 'bf34a05e2ada46b0d9c5df198f3a0b6ef98373d8'
context:
  - '{project-root}/_bmad-output/implementation-artifacts/epic-4-context.md'
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** The seven no-Slicer strings sit pinned in the ARB since 1.2 and 4-4 closed the failure-cause taxonomy, but nothing renders them — FR-29's calm surface does not exist, so 4-6 (Rescue) and Epic 5 (scan/genesis) have nothing to degrade onto.

**Approach:** A core-pure `NoSlicerCause` vocabulary (seven members, total mapping from `SlicerFailureCause`) plus one shell surface that renders the cause's pinned string with a single `Anotarlo` exit to Manual Capture — identical layout for all seven causes, no production trigger in this story (the 4-2/4-4 pattern: the piece ships, the caller arrives later).

## Boundaries & Constraints

**Always:**
- `NoSlicerCause` (core, pure): `noKey`, `invalidKey`, `quotaExhausted`, `unreachable`, `offline`, `consentDeclined`, `personInFrame` — closed at seven so no eighth can appear. `noSlicerCauseFromFailure(SlicerFailureCause)` is total: `credentialUnavailable→noKey`, `invalidKey→invalidKey`, `quotaExhausted→quotaExhausted`, `providerUnreachable→unreachable`, `networkUnreachable→offline`, `malformedResponse→unreachable` (recorded: epics.md:1988 — surfaced under the provider-unresponsive string), `managedUnavailable→noKey` (config-family per slicer_port.dart's own doc). `consentDeclined`/`personInFrame` are pre-request refusals with no failure-cause origin (Epic 5's callers).
- The surface: full-screen `surfaceBase` frame, centered, 480-max-width (CaptureScreen's grammar); renders exactly the cause's pinned ARB string + one `HechoButton`-register exit `Anotarlo` → pushes `CaptureScreen(controller, dictation)` with the isCurrent guard, copying `_openCapture`. System back stays the OS pop — no `PopScope` dead-end, no styled second exit, no Ajustes action (the pointer lives in copy). Identical layout, type styling and illustration treatment for all seven — copy is the only differentiator.
- Styling: no red, no warning iconography, no exclamation mark, no error semantics; full-screen illustration register applies as permission, shipped **text-only** on the recorded 2-7/2-4 precedent (DESIGN.md:548 — "permission, not mandate"; no illustration asset exists to draw).
- All copy via `AppStrings` accessors; the seven values render verbatim (assert equality with the generated accessors in tests).
- Pin hardening: `noSlicerExit` gains `x-signoff: "Sergio, 2026-08-27"` (same authored table, EXPERIENCE.md:109) and joins `pinnedNoSlicerKeys` — existence and review stay separate gates; the check remains the existing Makefile target under `make check`.

**Ask First:**
- Text-only surface (no illustration mark) — confirm, or commission an authored mark (asset/glyph work this spec does not include).
- Verification default: widget-test evidence only; no emulator demo — the surface is unreachable in production by design until 4-6. Confirm, or require a throwaway debug demo route.
- Extending the pinned set to `noSlicerExit` — confirm or keep the pin at the seven cause strings.

**Never:**
- No production call site or trigger (4-6, Epic 5); no Dispenser edit — it never learns key/quota/provider/network; no new ARB strings (all exist); no queue, retry, pending state or persisted failure anywhere; no per-cause visual differentiation; no egress, vault, Kotlin, manifest or platform-channel edit; no new Makefile target (string_table_audit already registers the check).

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Render each cause | any of the 7 `NoSlicerCause` | one calm surface: that cause's pinned string + `Anotarlo`, byte-identical layout across causes | N/A |
| Exit used | tap `Anotarlo` in any cause, incl. offline | pushes `CaptureScreen` with threaded capture+dictation controllers | typing/dictation consume nothing missing |
| Failure mapping | each of the 7 `SlicerFailureCause` | total map to a `NoSlicerCause` per Always table | no eighth cause can exist (exhaustive switch) |
| Cause swapped while mounted | new cause on rebuild | new string renders; no state, cache or residue survives | quiet |
| System back | back gesture/button | route pops (OS behavior); nothing queued on departure | nothing persisted |

</frozen-after-approval>

## Code Map

- `packages/core/lib/ports/slicer_port.dart:69-102` -- the closed seven-cause taxonomy + config-family doc comments; the vocabulary this surface renders from.
- `packages/core/lib/derive/strip.dart:57` -- precedent: core-pure enum the shell switches on (`StripResident`).
- `lib/ui/dispenser/dispenser_screen.dart:808-819` -- `_openCapture`: the push grammar to copy (MaterialPageRoute + `ModalRoute.of(context)?.isCurrent` guard).
- `lib/ui/capture/capture_screen.dart:67-78` -- `CaptureScreen({controller, dictation})`, both optional — the exit destination; scaffold/max-width grammar (`:54`).
- `lib/ui/dispenser/task_card.dart:29,78` -- `HechoButton` primary register / `SecondaryTextAction` — the exit control's grammar.
- `lib/l10n/app_es.arb:154-194` -- the seven pinned strings (signed 2026-08-27); `:221-224` -- `noSlicerExit` (unsigned, unpinned — this story's one ARB edit).
- `tool/check_string_table_audit.dart:25-33,117-147` -- `pinnedNoSlicerKeys` + placeholder/sign-off gates to extend.
- `test/tool/check_string_table_audit_test.dart` -- pin-test pattern (pure function + CLI end-to-end).
- `Makefile:44-60` -- `check` already runs string_table_audit; no registration edit needed.
- `tool/check_no_literal_strings.dart` -- string-literal ban in `lib/**`: copy only through accessors.
- `lib/main.dart:156-160` -- slicer threaded and unread; 4-6 wires the trigger.
- `_bmad-output/implementation-artifacts/2-7-warm-return.md:94` -- text-only illustration-register precedent (DESIGN.md:548 "permission, not mandate").
- Census-test idiom: `_bmad-output/implementation-artifacts/1-11-proof-that-lateness-cannot-be-expressed.md:69`, `2-7-warm-return.md:80`.

## Tasks & Acceptance

**Execution:**
- [x] `packages/core/lib/ports/no_slicer_cause.dart` + `packages/core/test/no_slicer_cause_test.dart` -- enum (7 members) + total `noSlicerCauseFromFailure`; pin exhaustiveness (no default arms), the recorded mapping rows, and that consent/person have no failure origin.
- [x] `lib/ui/no_slicer/no_slicer_surface.dart` -- the surface widget: cause → accessor switch, single exit, threaded controllers; doc records the 4-6/Epic 5 callers as the future pushers.
- [x] `test/ui/no_slicer/no_slicer_surface_test.dart` -- all seven causes render their accessor's value verbatim; identical layout across causes (same widget tree shape, only copy differs); exactly one action control; exit pushes `CaptureScreen` with both controllers threaded; styling census: no '!' in any rendered text, no warning/error icons, no red color semantics; cause-swap re-render leaves no residue.
- [x] `lib/l10n/app_es.arb` + `tool/check_string_table_audit.dart` + `test/tool/check_string_table_audit_test.dart` + `make codegen` -- x-signoff on `noSlicerExit`, pin it, extend pin tests (missing-signoff and placeholder findings for the new member).
- [x] `devbox run -- make gate` + `make check` + `make codegen-check` -- all green.

**Acceptance Criteria:**
- Given any of the seven causes, when the surface renders, then it is ONE calm surface carrying the cause's string plus a single exit — not seven visual states; copy alone distinguishes them.
- Given the surface's styling, when audited, then none of the seven reads as an error — no red, no warning iconography, no exclamation — and the full-screen illustration register is honored (text-only, recorded precedent).
- Given the exit, when exercised in each of the seven states, then it opens Manual Capture and is input-method-neutral by construction: typing and on-device dictation consume nothing the missing half provides.
- Given any no-Slicer failure rendered, when the surface is left, then nothing is queued, retried or persisted — the surface holds no state beyond the immutable cause it was handed.
- Given the build check, when `make check` runs, then eight keys are pinned (seven causes + exit), each with a non-placeholder value and a reviewer sign-off — existence and review as separate gates.
- Given the Dispenser and production navigation, when this story's diff is audited, then the Dispenser is untouched and no reachable path opens the surface — the callers arrive in 4-6 and Epic 5.

## Spec Change Log

## Design Notes

- Why a second enum instead of rendering `SlicerFailureCause` directly: the spine (ARCHITECTURE-SPINE.md:234) says the seven states are chosen in the core, and two of the seven (consent declined, person in frame) are pre-request refusals that never produce a failure — the UI cause set is not the failure set, and the total map is where the two vocabularies meet.
- `managedUnavailable→noKey` is the honest fold for this build: Managed is unreachable, nothing was sent, and the no-key string's remedy (Ajustes) is the true one for a BYOK-only build; the port's own doc already files it under config-family.
- The exit label method-neutrality is FR-32's doing: the destination surface carries the microphone, so any hand-claiming label collides with it (`Anotarlo` chosen over `Añadir a mano` in the authored session).

## Verification

**Commands:**
- `devbox run -- make gate` -- expected: green (tests, format, analyze).
- `devbox run -- make check` -- expected: green incl. string-table audit with the extended pin.
- `devbox run -- make codegen && devbox run -- make codegen-check` -- expected: regenerated accessors committed, no diff.

**Manual checks (if no CLI):**
- None reachable in production by design (trigger arrives in 4-6) — widget tests are the rendering evidence; an emulator demo would require a debug route this story deliberately does not add.

## Suggested Review Order

**The cause vocabulary — chosen in the core**

- The total map: where the failure taxonomy and the renderable causes meet, both folds recorded.
  [`no_slicer_cause.dart:74`](../../packages/core/lib/ports/no_slicer_cause.dart#L74)

- The seven members, closed by construction — copy alone will differentiate them.
  [`no_slicer_cause.dart:26`](../../packages/core/lib/ports/no_slicer_cause.dart#L26)

**The one calm surface**

- The exhaustive accessor switch — the only differentiator, no default arm.
  [`no_slicer_surface.dart:88`](../../lib/ui/no_slicer/no_slicer_surface.dart#L88)

- The whole layout: one string, one gap, one exit — identical for all seven causes.
  [`no_slicer_surface.dart:100`](../../lib/ui/no_slicer/no_slicer_surface.dart#L100)

- The exit's push — `_openCapture`'s guard grammar copied, seams threaded.
  [`no_slicer_surface.dart:73`](../../lib/ui/no_slicer/no_slicer_surface.dart#L73)

**The pin hardening**

- The pinned set grows the exit — eight keys, existence and review separate gates.
  [`check_string_table_audit.dart:28`](../../tool/check_string_table_audit.dart#L28)

- The exit's sign-off — same authored table, same date, value untouched.
  [`app_es.arb:221`](../../lib/l10n/app_es.arb#L221)

**Verification — the contract pinned from outside**

- The authored-table anchor: widget pairing checked against EXPERIENCE.md's literals, not a duplicated switch.
  [`no_slicer_surface_test.dart:98`](../../test/ui/no_slicer/no_slicer_surface_test.dart#L98)

- Departure writes nothing — OS back with live seams threaded, store stays empty.
  [`no_slicer_surface_test.dart:502`](../../test/ui/no_slicer/no_slicer_surface_test.dart#L502)

- The rapid double tap stacks one route, not two — the settings idiom, mirrored.
  [`no_slicer_surface_test.dart:377`](../../test/ui/no_slicer/no_slicer_surface_test.dart#L377)

- The no-referer census fails loudly on a symlinked lib/ entry.
  [`no_slicer_surface_test.dart:527`](../../test/ui/no_slicer/no_slicer_surface_test.dart#L527)

- The mapping rows, pinned one by one against the recorded folds.
  [`no_slicer_cause_test.dart:29`](../../packages/core/test/no_slicer_cause_test.dart#L29)

- The exit key's three findings — missing sign-off, placeholder, absence.
  [`check_string_table_audit_test.dart:44`](../../test/tool/check_string_table_audit_test.dart#L44)

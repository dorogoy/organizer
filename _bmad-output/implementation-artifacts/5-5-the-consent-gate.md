---
title: 'Story 5.5: The consent gate'
type: 'feature'
created: '2026-09-06'
status: 'done'
review_loop_iteration: 0
baseline_commit: '45d31a92f4b999394292c59ee6d1349e44f60a36'
context:
  - '{project-root}/_bmad-output/implementation-artifacts/epic-5-context.md'
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** The scan chain stops at a quiet close: after the face gate passes, nothing asks the user, nothing uploads, and the frame dies. AD-8's compile-time `ScanConsent` (5.4) has no production minter, `consent_granted` is minted nowhere, `NoSlicerCause.consentDeclined` (4-5) has no trigger, and the first scan payload cannot legally ship. FR-25's per-scan consent — the epic's core promise — does not exist as a surface.

**Approach:** Replace the gate-pass quiet close (`scan_controller.dart:266`) with the consent act: a new full-screen consent gate rendering the fixed copy through `action-equal-pair` (the app's only zero-recommended-actions surface; `accent-soft` expelled), wired so decline routes to the existing no-Slicer surface with its own string and the `Anotarlo` exit, and accept mints the token (after the face gate, before the cap), appends `consent_granted`, and dispatches the first `ScanSliceRequest` — image and prompt and nothing else — through the sealed egress. The dispatch's failure arm maps through the standing `noSlicerCauseFromFailure`; the success arm is **interim by decision of 2026-09-06 (P2-A)**: unlink and quiet close, the landing belonging to 5.7. The face gate stays **face-only** (decision of 2026-09-06, P1: composition face∨pose stays banked — 4 FN/12 accepted, 3/12 ceiling recorded in `face-gate/results/report.md`; reopens at the Epic 5 retro). The shoot-side quiet closes are untouched (P3: the retro decides the epic-wide communication rule).

## Boundaries & Constraints

**Always:**
- The gate copy is the shipped strings, verbatim and parameterized: body `consentGateBody(providerName)` — `La foto se procesará por {provider} para obtener las tareas necesarias.` — and actions `consentGateSend` (`Enviar la foto`, **first slot**) / `consentGateDecline` (`No enviarla`). No new ARB keys, no copy edits, no re-sign-off.
- `action-equal-pair` (UX-DR26): one row, both children `flex 1 1 0` — identical width, height, ground, hairline, type role, ink and tap count; **no fill on either**; `accent-soft` (the theme's `colorScheme.primary`) appears nowhere on the surface. The gate is the only zero-recommended-actions surface — a declared exception no other surface borrows; compose the pair inline in the gate widget (no shared component; the exception register implies no second consumer).
- Declining costs exactly the same taps as accepting: no larger accept, no dimmed decline, no confirmation, no delay. After an answer the pair is replaced (static `scanWaitTitle` text on accept — no pencil, no progress semantics: UX-DR56's animated wait is 5.6's), so no second answer exists.
- Decline: no upload (the slicer seam is never called), one payload-less `consent_declined` system-event row through its single core minter, cache unlinked, then the existing `NoSlicerSurface(NoSlicerCause.consentDeclined)` — no re-ask, no persuasion, no second attempt at the gate within the scan.
- Accept: `mintScanConsent(scanId)` at the tap — after the face gate, before the resolution cap (AD-8's ordering, now with its first production caller) — then one `consent_granted` user-act row, then one `SlicerPort.slice(ScanSliceRequest(imageBytes: frameBytes, prompt, scanId, consent))`. The request carries only the frame's bytes, the prompt, and the in-memory identities; nothing from the album, store, plan history, device or location ever enters it (FR-25, NFR4).
- The frame survives the gate pass — gate-pass stops being a terminal path; `unlinkScan` fires on every real resolution: decline, pre-gate no-provider refusal, gate exit (system back), provider failure, delivered-interim discard, epoch-stale late landing. The 5.4 sweep stays the crash backstop.
- No provider selected (`readSelectedProvider()` null) → the gate never renders: route the existing `NoSlicerSurface(NoSlicerCause.noKey)` and close the scan quietly — consent is never asked for a request that cannot be made. A selected-but-broken credential fails inside the dispatch and maps to its cause like any failure.
- Core stays pure, egress stays sealed (zero egress-file changes — 5.4 already threads the token and the cap), substrate grows additively only (one new payload-less kind: `consent_declined`, the nineteenth), every gate inside devbox.

**Ask First:**
- Any new log kind beyond `consent_declined`, or any scan-side `slice_requested`/`slice_returned`/`slice_failed` row — scan outcome vocabulary belongs to 5.7's landing, and the rescue arming logic reads those kinds today.
- Any change to the equal-pair's geometry, the copy, the slot order, or the declared-exception register.
- Any egress, cap, mime-truth or `ScanConsent` semantics change (5.3/5.4 sealed; AD-23).
- If `make check`'s string-table audit demands an `x-signoff` on the already-shipped `consentGate*` keys, or the literal audit flags the scan prompt constant — halt and surface before editing audits or ARB metadata.

**Never:**
- No wait surface beyond the static text (5.6: pencil, unbounded-wait semantics, `scan_abandoned`, backgrounding), no landing (5.7: pool facts, banding, Origin Context, one-card), no typed genesis (5.8).
- No blanket "always allow", no consent preference, no settings surface, no re-ask — the settings censuses stay green untouched (FR-25).
- No composition of the face gate (pose/object packages stay out of pubspec; P1).
- No renegotiated shoot-side quiet closes (P3 — retro).
- No upload on any path but an answered, minted, bound, once-consumed consent.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Gate render | Face gate passed, provider selected | Consent gate full-screen: body with the provider's display name, equal pair, `Enviar la foto` first; zero recommended actions | N/A |
| Decline | Tap `No enviarla` | One `consent_declined` row, cache unlinked, slicer never called, `NoSlicerSurface(consentDeclined)` replaces the route | Quiet unlink |
| Accept | Tap `Enviar la foto` | Token minted bound to `scanId`, one `consent_granted` row, pair replaced by static `Creando tareas`, exactly one `slice()` | N/A |
| Slice delivered (interim) | `SlicerDelivered` | Cache unlinked, scan closes to the Dispenser — nothing lands, no row (5.7 replaces this arm) | N/A |
| Slice failed | `SlicerFailed(cause)` | Cache unlinked, `NoSlicerSurface` with `noSlicerCauseFromFailure(cause)`'s string | The 4-5 mapping, unchanged |
| No provider | `readSelectedProvider()` → null after gate pass | Gate never renders; `NoSlicerSurface(noKey)`; scan closes quietly | No row (silence, not absence) |
| System back on the gate | Back before answering | No row, cache unlinked, scan closes — leaving is not declining | Quiet |
| Close/exit mid-dispatch | `close()` or route pop after accept | Epoch guard turns the late resolution into a stale answer: no routing, cache unlinked | Quiet (5.2's discipline) |
| Rapid second tap | Double-tap on either action | One decision taken; the second tap is nothing (one token exists; consumption is once) | In-flight guard |
| Detector fails at shoot | Gate throws / empty frame path | Unchanged quiet close (P3) — no consent, no upload | Unchanged 5.2 behavior |

</frozen-after-approval>

## Code Map

<!-- Anchors baseline-relative (45d31a9, post-5.4). Expect drift in landed files. -->

- `lib/scan/scan_controller.dart` -- THE seam. `ScanShootOutcome` :17-52 (sealed: Refused/Closed/Failed) gains a fourth arm carrying the standing scan's identity; gate-pass quiet close :264-266 (`return const ScanShootClosed();`) becomes that arm — the frame survives. Frame write :218, epoch guards :213/:223/:235/:246-251, `_unlinkScan` :293-301 / `_unlinkCaptured` :303-315, `close()` :281-290 (still unlinks — the gate-exit path), ctor :82-90 (gains the `SlicerPort` seam; `gate` :100-104 is the optional-seam pattern to copy), rows via `LogWriteQueue` :333-363. Gains: the consent-phase API (decline = row + unlink; grant = mint + row + bytes + slice + unlink-on-every-resolution) and the scan prompt as a private code const (provider instruction, not UI copy — the rescue prompt's precedent lives in the access layer, also not ARB).
- `packages/core/lib/commands/scan_commands.dart` -- `faceRefused()` :28-49 is the pattern; gains `consentDeclined()` — payload-less system-event row, single sanctioned minter, doc per AD-21 (a decline logs, but is not contact).
- `packages/core/lib/log/log_entry.dart` -- kinds :99-117 + `knownByName` :119-135 + `_isMoment` :~620; `consentDeclined` joins as the nineteenth kind, **not** a moment, **not** a user act (`warm_return.dart:100`'s set stays untouched — pin the non-contact).
- `packages/core/lib/ports/slicer_port.dart` -- `ScanSliceRequest` :47-70 (fields pinned; do not touch), `SlicerOutcome` :144+ (`SlicerDelivered`/`SlicerFailed`), `SlicerFailureCause` :96+ (eight causes).
- `packages/core/lib/ports/no_slicer_cause.dart` -- `noSlicerCauseFromFailure` :86-95 (the standing map the failure arm reuses); `consentDeclined` :44-49 and `noKey` already exist.
- `lib/ui/scan/scan_screen.dart` -- `_onShoot` :222-284: the `ScanShootClosed` pop arm :257-258 becomes the consent continuation (pre-gate provider read, gate push, decline/delivered/failed routing); the `personInFrame` pushReplacement :234-239 is the navigation grammar.
- `lib/ui/scan/consent_gate_screen.dart` -- NEW: the gate surface. `NoSlicerSurface` (`lib/ui/no_slicer/no_slicer_surface.dart` :47-170) is the layout register to copy: full-screen `surfaceBase`, centered, 480 max-width, system back as OS pop. Body `AppStrings.of(context).consentGateBody(providerName)`; pair = `Row` of two `Expanded` children — unfilled `Material` + 1 px hairline `Border.all` + radius + `Spacing.touchTargetMin` floor; `Enviar la foto` in the first slot; on answer the pair swaps to a static `scanWaitTitle` text.
- `lib/ui/settings/slicer_access_section.dart` -- `_providerNameOf` :214-218 — lift to a public top-level function in place (ids from `lib/egress/provider_allowlist.dart`, names from `AppStrings.providerName*`); the settings section keeps calling it.
- `lib/settings/settings_controller.dart` -- `readSelectedProvider()` :217-221 (derived from the log; null = none) — the pre-gate availability read; main threads the resolver into the scan composition.
- `lib/main.dart` -- scan composition :92-98 (`scan = ScanController(...)`) gains `slicer:` (the same `slicer` instance threaded to `DispenserController` :116-121 — one production SlicerPort) and the provider-read seam.
- Tests to renegotiate: `packages/core/test/log_test.dart` (kinds 18→19 + `knownByName` length); `packages/core/test/scan_commands_test.dart` (minter row shape, single-writer); `packages/core/test/warm_return_test.dart` (pin `consent_declined` is **not** contact); `packages/core/test/no_lateness_proof_test.dart` :2163-2233 (mint census: `mintAllowed` += `lib/scan/scan_controller.dart`; consumeAllowed unchanged); `test/scan/scan_controller_test.dart` :362 (gate pass = quiet close → consent phase: frame survives, decline/grant/epoch/rapid-tap); `test/ui/scan/scan_screen_test.dart` :238 (quiet pop → gate continuation, routing matrix, equal-pair geometry: equal widths, no primary fill, hairline, first-slot order, provider-name interpolation).
- Read-only: `lib/egress/*` (the seal — zero changes; the token already travels and the cap already runs inside the binding), `lib/files/app_files.dart` :297/:321/:376 (unlinkScan / capped copy — no new production caller needed; "at most two files" is a ceiling the one-file state satisfies), `lib/session/session_controller.dart` (the sweep backstop, untouched), `lib/ui/dispenser/dispenser_controller.dart` :632/:704-715 (the rescue slice precedent and its failure mapping), `Makefile` :44-60 (the gates).
- Planning anchors: `ARCHITECTURE-SPINE.md` :92-96 (AD-8), :145 (AD-15 — the provider-name placeholder is a sanctioned interpolation), :182-186 (AD-21 — `consent_declined` a system event; no entry asserts an absence), :225 (naming table — `consent_granted` a user act), `epics.md` :1975-2011 (the ACs), `ux-designs/.../DESIGN.md` :528-532 (action-equal-pair), `EXPERIENCE.md` :33/:105-106/:141 (the gate, the copy, the no-remedy deviation), `face-gate/results/report.md` (P1's recorded decision and the 3/12 banked ceiling).

## Tasks & Acceptance

**Execution:**
- [x] `packages/core/lib/log/log_entry.dart` -- add the `consentDeclined` kind (payload-less system event, nineteenth), `knownByName` row, `_isMoment` excluded; docs naming it a decline record that asserts nothing -- the vocabulary grows additively (AD-23)
- [x] `packages/core/lib/commands/scan_commands.dart` -- `consentDeclined()`: exactly one payload-less content row, the kind's single sanctioned minter, doc: logged decline, never contact, no capability -- no second writer can appear silently
- [x] `packages/core/test/log_test.dart` + `scan_commands_test.dart` + `warm_return_test.dart` -- kinds census 18→19, `knownByName` length, minter row shape, and the pin that `consent_declined` is not a user act -- the set assignments are the same-pass rule's
- [x] `packages/core/test/no_lateness_proof_test.dart` -- mint census gains `lib/scan/scan_controller.dart` as the one production mint caller (consumeAllowed unchanged: the dispatch) -- the 5.4 census renegotiates additively, exactly as its comment promises
- [x] `lib/scan/scan_controller.dart` -- fourth `ScanShootOutcome` arm on gate pass (identity-carrying; frame survives); consent-phase API: `declineConsent()` (one `consentDeclined` row + unlink), `grantConsent()` (mint bound to the standing scanId → one `consentGranted` row → frame bytes → one `slice(ScanSliceRequest)` → unlink on every resolution → delivered/failed(cause) out), epoch-guarded so a late resolution after `close()` is a quiet stale answer; the scan prompt as a private const instructing the Slicer's step contract (real actions in the space, 3–5-minute tags) -- the quiet close becomes the consent act, AD-8's ordering realized
- [x] `lib/main.dart` + `lib/settings/settings_controller.dart` + `lib/ui/settings/slicer_access_section.dart` -- thread the shared `slicer` instance and a provider-read seam into the scan composition; lift `_providerNameOf` to a public function in place -- one SlicerPort, one display-name truth
- [x] `lib/ui/scan/consent_gate_screen.dart` -- NEW: the gate surface per the Code Map's register: body with interpolated provider name, inline equal pair (two `Expanded`, unfilled, hairline, identical geometry, `Enviar la foto` first, ≥48 dp), pair replaced by static `Creando tareas` after the answer, no `accent-soft` anywhere -- UX-DR26's declared exception, composed not canonized
- [x] `lib/ui/scan/scan_screen.dart` -- the gate-pass arm: resolve the selected provider (null → `NoSlicerSurface(noKey)` + quiet close, gate never renders); else push the gate; route decline → `NoSlicerSurface(consentDeclined)`, delivered → quiet close to the Dispenser, failed → `NoSlicerSurface(noSlicerCauseFromFailure(cause))`; system back on the gate closes the scan quietly -- every resolution routes, none queues
- [x] `test/scan/scan_controller_test.dart` -- consent phase: frame survives gate pass; decline = one row + unlink + zero slice calls; grant = mint/row/slice-once with bytes+prompt+scanId+token and unlink on delivered, failed, and epoch-stale; rapid second decision is nothing -- the controller's whole consent contract
- [x] `test/ui/scan/scan_screen_test.dart` + a `consent_gate_screen_test.dart` -- the routing matrix of the I/O table; the pair's geometry pinned (equal widths via `flex 1 1 0`, no `colorScheme.primary` fill, hairline present, first-slot text order, body interpolates the provider name); after answering, no action remains tappable -- the surface is the ACs, rendered
- [x] Gate -- `make gate` + `make check` green inside devbox, seals untouched, string table byte-identical

**Acceptance Criteria:**
- Given the consent gate, when it is rendered, then it uses `action-equal-pair` — one row, both children `flex 1 1 0`, identical in every respect, no fill on either, `accent-soft` expelled — and it is the app's only zero-recommended-actions surface (UX-DR26).
- Given the gate's copy, when it is read, then it states what is sent and to whom — the named provider, the scan image and a prompt, nothing else (FR-25); `Enviar la foto` sits in the first slot, recorded as residual asymmetry, not solved (UX-DR52).
- Given the decline path, when its cost is measured, then it equals the accept path — same taps, no dimming, no confirmation, no delay — and declining routes to the no-Slicer surface with its own string and the `Anotarlo` exit, with no re-ask, no persuasion and no second attempt (FR-25, FR-29).
- Given what is sent, when the payload is inspected, then it is only the scan image and a prompt plus the in-memory identities — no plan history, no album contents, no device or location identifiers (FR-25, NFR4).
- Given a granted consent, when the upload runs, then a single-use `ScanConsent` minted after the face gate and before the cap authorizes exactly one dispatch entry, `consent_granted` is a payload-less user-act row reconstructed from nothing, and the scan's files are unlinked on every terminal path (AD-8, NFR14).
- Given a declined consent, when the log is read, then exactly one payload-less `consent_declined` system-event row stands — the nineteenth kind — contact for no derivation, minted by one sanctioned minter (AD-21).
- Given the diff, when the seals are inspected, then egress, cap, mime truth and `ScanConsent` semantics are byte-untouched, the string table is unchanged, the settings censuses are green, and the face gate is still face-only (P1) with the quiet closes unmoved (P3).

## Spec Change Log

- **2026-09-06 — Sergio's planning decisions folded into the frozen intent.** P1: the face gate stays face-only; the composition reopen is answered (kept banked, 3 FN/12 ceiling recorded), reopening at the Epic 5 retro. P2 (A): the success arm ships as an interim discard — unlink + quiet close, no landing, no rows — replaced whole by 5.7. P3: shoot-side quiet closes are not renegotiated here; the retro owns the epic-wide rule.

## Design Notes

- **Why the success arm may discard a paid-for result.** A legal landing needs 5.7's pool facts (estimate-seconds + banding) and one-card rule; half-building it would create throwaway code 5.7 rewrites. Between story commits the app stays honest by discarding silently rather than fake-landing: no row asserts anything, nothing queues, the frame dies. 5.7 replaces exactly this arm. The dispatch wiring above it — mint order, token, cap-in-binding, failure mapping — is permanent.
- **Why `consent_declined` logs but is not contact, while `consent_granted` is both.** The spine's naming table (:225) fixes the asymmetry: granting is mid-scan app use (warm return counts it); declining means no scan is coming — the record exists for FR-26's audit trail, not for engagement.
- **Why no scan slice rows.** `slice_requested`/`slice_returned` drive the rescue arming logic today (`rescue_commands.dart:132-158` reads an unanswered request); scan-side rows would collide with it and preempt 5.7's outcome vocabulary. Silence is AD-21-legal; asserting is not.
- **Why the pair is inline, not a component.** The exception register (DESIGN.md :598) implies no second consumer; a shared widget for one surface is the abstraction the register forbids borrowing.

## Verification

**Commands:**
- `devbox run -- make gate` -- expected: green (format, analyze, all tests including the 19-kind census and the renegotiated mint census)
- `devbox run -- make check` -- expected: green — every seal untouched; string-table audit unchanged; no-literal-strings green with the new surface on `AppStrings` only
- `devbox run -- flutter test test/scan/scan_controller_test.dart test/ui/scan/` -- expected: exit 0 (the consent matrix green)

**Manual checks (if no CLI):**
- None required — no hardware behavior ships beyond 5.2's; the committed suites and the device recipe in `AGENTS.md` cover the flow if a device pass is wanted (face-refusal → reframe, consent gate → decline → `Anotarlo`).

## Suggested Review Order

**The consent act — the quiet close becomes a decision**

- The heart: mint bound to the standing scan, one act row, exactly one slice, unlink on every resolution.
  [`grantConsent:528`](../../lib/scan/scan_controller.dart#L528)

- Decline: one payload-less row with the epoch re-checked inside the write-queue closure — a late close records nothing.
  [`declineConsent:493`](../../lib/scan/scan_controller.dart#L493)

- The gate-pass arm: the frame survives the pass; only the identity rides out.
  [`ScanShootGatePassed:52`](../../lib/scan/scan_controller.dart#L52)

- The sealed outcomes a gate answer can produce — delivered, failed(cause), stale.
  [`ScanConsentOutcome:71`](../../lib/scan/scan_controller.dart#L71)

- The scan prompt: provider instruction, not UI copy — the rescue-contract precedent, on the audit's allowance.
  [`_scanPrompt:624`](../../lib/scan/scan_controller.dart#L624)

- A throw from the port folds to providerUnreachable after unlink+clear — the port answers outcomes only.
  [`grantConsent:546`](../../lib/scan/scan_controller.dart#L546)

**The gate surface — the declared exception**

- Lifecycle: hidden/paused/detached close the scan; a transient inactive→resumed occlusion holds (5.2's contract, mirrored).
  [`_ConsentGateScreenState:82`](../../lib/ui/scan/consent_gate_screen.dart#L82)

- The pair: inline `action-equal-pair` — two `Expanded` (flex 1 1 0), unfilled, hairline, `Enviar la foto` first; `accent-soft` nowhere.
  [`pair:235`](../../lib/ui/scan/consent_gate_screen.dart#L235)

- The body names the provider — the one sanctioned interpolation (AD-15).
  [`body:215`](../../lib/ui/scan/consent_gate_screen.dart#L215)

- A stale resolution pops the gate — leaving is not declining; the pair cannot be answered twice.
  [`stale:178`](../../lib/ui/scan/consent_gate_screen.dart#L178)

**The continuation — fail closed before rendering**

- Null provider, unknown-provider id, absent read, absent slicer: the gate never renders for a request that cannot be made.
  [`_continueToConsent:294`](../../lib/ui/scan/scan_screen.dart#L294)

- Routing matrix: decline → consentDeclined, delivered → quiet close (P2-A interim), failed → the standing cause map.
  [`routing:343`](../../lib/ui/scan/scan_screen.dart#L343)

**The vocabulary — the nineteenth kind**

- `consent_declined`: payload-less system event, not a moment, never contact.
  [`LogKind.consentDeclined:113`](../../packages/core/lib/log/log_entry.dart#L113)

- The kind's single sanctioned minter; the header now counts all three rows.
  [`consentDeclined():96`](../../packages/core/lib/commands/scan_commands.dart#L96)

**Composition and wiring**

- The two production seams — one shared SlicerPort, the provider read — pinned by the composition test.
  [`main.dart:101`](../../lib/main.dart#L101)

- The display-name switch lifted public in place — one truth for the gate and Settings.
  [`providerNameOf:33`](../../lib/ui/settings/slicer_access_section.dart#L33)

- The literal audit's allowance: the prompt joins the rescue contract on the same terms.
  [`allowance:265`](../../tool/check_no_literal_strings.dart#L265)

**The pins**

- The controller's consent contract: decline, accept, stale, rapid double-tap, throw containment.
  [`accept test:694`](../../test/scan/scan_controller_test.dart#L694)

- The routing matrix, end to end: no-slicer, throwing read, membership, decline, accept, failed, back.
  [`routing tests:260`](../../test/ui/scan/scan_screen_test.dart#L260)

- The surface pins: geometry, post-answer inertness, double-tap, back.
  [`pair test:188`](../../test/ui/scan/consent_gate_screen_test.dart#L188)

- Census 18→19 with `knownByName` at nineteen; the mint census gains its first production caller.
  [`census:87`](../../packages/core/test/log_test.dart#L87)

- The composition pin: deleting either seam from main fails this test.
  [`pin:274`](../../test/ui/app_test.dart#L274)

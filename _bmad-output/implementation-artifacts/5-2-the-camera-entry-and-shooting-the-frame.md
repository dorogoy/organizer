---
title: 'Story 5.2: The camera entry, and shooting the frame'
type: 'feature'
created: '2026-09-05'
status: 'done'
review_loop_iteration: 0
baseline_commit: '9324d5a260afe05cd84eb8bb998469aa4800a37c'
context:
  - '{project-root}/_bmad-output/implementation-artifacts/epic-5-context.md'
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** Genesis has no photo path: the Dispenser ships only the Lápiz entry, no camera surface exists, and the face gate 5.1 measured has no production caller — starting a project from a real space is impossible (FR-16, FR-25).

**Approach:** Add the Cámara entry beside Lápiz (top-right, one tap to Scan), a minimal scan surface on the spine-pinned `camera` plugin behind a shell facade, first-use permission on our own `camera` channel (log-derived visibility, never re-asks, system failures communicated), an additive per-scan cache write in `FilesPort`, and the `FaceGatePort` in core with an ML Kit adapter running 5.1's interim rule — the story ends at the gate; refusal lands on the 4-5 calm surface.

## Boundaries & Constraints

**Always:**
- CAMERA is requested at the first scan attempt (opening the scan surface), never at app entry, never during first run (AD-17, NFR8). The permission moment is **ours** — the `dev.dorogoy.organizer/camera` channel (DictateChannel's pattern, the spine's fourth channel, grown by the 2026-09-05 ruling below) requests CAMERA and separates the two domains the plugin folds together: **the user's explicit denial** — or a denial discovered after an OS-level revocation of a grant — is app logic: exactly one `permission_refused{camera}` row via the existing single minter, surface closes, entry absent. **A system-interrupted request** (empty grants — the ask was swallowed, no answer existed) is a functioning problem, not a refusal: nothing is appended, the entry stays, and the scan surface communicates the problem honestly (ruling: app logic and system-problem notification are separate domains; a malfunction is never hidden and never mistaken for the user's choice).
- Entry visibility is exactly **enabled ∧ permission not refused**, derived from the substrate log — never from an active OS probe (`initialize()` triggers the OS dialog; probing at render would be asking at app entry). Revocation is discovered only at the next attempt.
- One Settings row (in the `IA y voz` group) owns both the disable toggle and the reactivation. Re-enabling (or toggling after a refusal) restores the entry; the OS permission is requested again only at the next first use.
- The face gate runs 5.1's interim rule of record verbatim: face-only, `performanceMode: accurate`, `minFaceSize: 0.0`, landmarks/classification/contours/tracking off; refuse iff ≥ 1 face. Production feeds the written cache frame file through `InputImage.fromFilePath` — the same input path the 5-1 instrument measured (`face-gate/BAR.md`, report's recorded seam).
- The frame is written to that scan's own cache subdirectory **before** the gate runs; every terminal path this story creates — refusal, gate pass, surface exit, permission failure, detector failure, surface disposal — unlinks the scan's directory. No frame lingers: 5.4's sweep does not exist yet.
- A face refusal appends one `face_refused` row and lands on the one calm surface (`NoSlicerSurface`, cause `personInFrame`) whose copy is the offer to reframe — the refusal is about the frame, never about the user; no re-ask, no persuasion, retry costs the same taps (FR-25, AD-21).
- No upload path: nothing in this story imports `lib/egress/` (the import seal proves it mechanically); no `ScanConsent` exists to mint (AD-8; 5.4's).
- Seal edits are deliberate and recorded: `android.permission.CAMERA` enters the main manifest with the `check_android_manifest.dart` permission map grown in the same change (INTERNET's 4-4 precedent); the Gradle allowlist is re-frozen once for the camera plugin's resolved graph (5-1 precedent).
- Story completion gate: `make gate` and `make check` green inside devbox.

**Ask First:**
- The `camera` plugin (spine pin `0.12.0+2`) fails to initialize on the emulator, or the resolved graph forces a different capture package — a different dependency is an architecture decision, not a substitution.
- `camerax` requires raising `minSdkVersion` above the Flutter template's floor — that reopens the build floor.
- Real-device or emulator use shows systematic false refusals on people-free frames severe enough to break the flow — the bar accepts FPs, but a flow-breaking FP rate is Sergio's escalation (5-1 discipline: findings, not tuning).

**Never:**
- No upload, egress, or consent code: no `ScanConsent`, no consent gate (5.5), no wait surface (5.6), no `scan_abandoned`/`consent_granted` log kinds.
- No 5.3 image-seam changes: `image_cap`, mime handling, `egressPixelCeiling` and the failure taxonomy stay untouched.
- No 5.4 cache-lifecycle contract: the ≤ 2-files invariant, the `app_opened` sweep, and token binding are 5.4's — this story adds only additive write/delete mechanics.
- No OS-permission query package (`permission_handler`) and no `shouldShowRationale` heuristics — the user's explicit denial is the refusal. The permission moment runs on our own `camera` channel (fourth channel, AD-11 growth recorded in the change log); camera **capture** stays plugin-served.
- No new glyph (CameraGlyph already ships, golden-pinned), no new refusal surface, no placeholder or "coming soon" UI on the gate-pass branch (5.5 wires the continuation).
- No change behind `Nuevo proyecto` — disabling the camera changes nothing there.
- The app never re-asks for the permission on its own.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|---------------|----------------------------|----------------|
| Entry, default state | No camera log rows, enabled by default | Cámara entry present top-right beside Lápiz: 48dp target, 24px CameraGlyph, `icon-mass-neutral`, ordinary treatment; one tap opens the scan surface | N/A |
| First use, granted | Tap entry → surface opens → CAMERA requested → granted | Preview runs; shutter (the one recommended action) shoots; OS back is the way out | N/A |
| First use, denied | Permission dialog answered "deny" | One `permission_refused{camera}` row; surface closes; entry absent on next render | N/A |
| Dialog interrupted | System swallowed the ask (empty grants — no answer existed) | The scan surface stays and communicates the functioning problem (`scanOpenFailed`); no row; entry stays — a malfunction is never hidden, never mistaken for the user's refusal | Next tap asks again |
| Revoked after grant | OS-side revocation, then a scan attempt | `initialize` reports denied → one refusal row; surface closes; entry absent thereafter | N/A |
| Camera disabled | Settings row toggled off | Entry never renders; everything else on the Dispenser and behind `Nuevo proyecto` unchanged | N/A |
| Face in frame | Gate finds ≥ 1 face | One `face_refused` row; frame directory unlinked; `NoSlicerSurface(personInFrame)` pushed — its copy offers the reframe, its exit is its own | Retapping Cámara reframes — same tap count |
| No face | Gate passes | Surface closes back to the Dispenser quietly; frame directory unlinked (the chain continues in 5.5) | N/A |
| Detector error | Gate errors | Retry once; still error → surface closes quietly, frame unlinked, **no** `face_refused` row — a failure is not a refusal; fail closed | No false privacy claims in the log |
| Camera failed to open | Device error at initialize / no hardware | The same honest problem notice on the surface; no rows; entry remains (the permission was never refused) | Declared corner: every target device ships a camera |
| Exit before shooting | OS back / surface disposed | Surface closes; scan directory unlinked; no rows | N/A |

</frozen-after-approval>

## Code Map

- `lib/ui/dispenser/dispenser_chrome.dart:211-233` -- `_LapizEntry`, the exact entry pattern to twin (Semantics button + 48dp `Spacing.touchTargetMin` + 24px glyph); the Cámara entry sits beside it, and the wide-ground chip clearance (:113-128, sized for one glyph zone) grows to clear two.
- `lib/ui/dispenser/dispenser_screen.dart:649-682,906-936` -- view-arm composition (the entry is chrome, not an arm) and the push-opener precedents (`_openCapture`, rapid-tap guard).
- `lib/dispenser/dispenser_controller.dart:48,322` -- sealed `DispenserView` + the queue-consistent `read()`; the entry's visibility boolean joins the read output (settings + log are already read there).
- `lib/ui/glyphs/camera_glyph.dart:10-43` -- CameraGlyph, shipped and golden-pinned, `icon-mass-neutral` both palettes; sited now, never redrawn.
- `lib/capture/dictation_controller.dart:129-179,339-365` -- the first-use pattern this story twins: derived visibility, refusal-row append, resume refresh.
- `android/app/src/main/kotlin/dev/dorogoy/organizer/DictateChannel.kt:122-145` -- dictation's Kotlin permission moment (empty grants → quiet; denied → refused) — the pattern `CameraChannel.kt` ports.
- `packages/core/lib/log/log_entry.dart:83-118,398-427` -- kinds registry (16 today) + `PermissionRefusedEntry` (payload = `Permission.camera`, already in the enum at :43-57); `face_refused` joins as a payload-less kind → **no** drift schema change (`app_opened` precedent).
- `packages/core/lib/commands/permission_commands.dart:34-51` -- the single-minter refusal command (doc: twin, don't fork); `scan_commands.dart` mints `face_refused` (one kind, one file).
- `packages/core/test/no_lateness_proof_test.dart:~1095-1165,1796-1860` -- frozen-shape census + single-minter pattern tests to update when the kind lands.
- `packages/core/lib/derive/permission.dart:36-44` -- `permissionMayBeAsked`, the one-way fold the entry derivation composes with.
- `packages/core/lib/ports/files_port.dart:27-42` + `lib/files/app_files.dart:89-96,191-197` -- the flat port (doc reserves `scan_cache`) and its traversal-refusing adapter; additive scan methods enter here, one clean `scanId` segment.
- `packages/core/lib/ports/slicer_port.dart` + `packages/core/test/ports_test.dart:66-92` -- declare-now-call-later precedent; the 6-file ports pin grows to 7 with `face_gate_port.dart`.
- `packages/core/lib/commands/settings_commands.dart:48-65` + `packages/core/lib/settings/settings.dart:105-140` -- the closed else-chain of sanctioned settings keys and the last-wins derivation; the camera-enabled key (default enabled) joins here.
- `lib/ui/no_slicer/no_slicer_surface.dart:26` + `packages/core/lib/ports/no_slicer_cause.dart:53-57` -- the one calm surface (doc names Epic 5's scan path as `personInFrame`'s designed pusher; 5.2 is that caller, the surface untouched) and the shipped cause + string (ARB:190 — copy is the reframe offer).
- `face-gate/probe/face_gate_probe_test.dart:258-265,438-447,545-557` -- the measured invocation the adapter replicates: pinned `FaceDetector` options, `processImage(InputImage.fromFilePath(...))`, retry-once, `close()` in `finally`.
- `pubspec.yaml:30-45` -- exact-pin convention; `camera: 0.12.0+2` (spine `ARCHITECTURE-SPINE.md:258`, first-party; adapter home `lib/plugins/`, spine :351 — the dir is new in this story).
- `android/app/src/main/AndroidManifest.xml:6,12` + `tool/check_android_manifest.dart:65-69` -- manifest seal; CAMERA enters main + the permission map in one deliberate edit.
- `tool/check_gradle_dependencies.dart:19,49-53` -- allowlist; camera's camerax closure → one deliberate `--re-freeze`, recorded.
- `tool/check_egress_imports.dart:38-57` -- the mechanical no-upload proof; stays green untouched.
- `lib/main.dart:23-120` -- composition root; the new threads follow the optional-seam convention (null = test seam).
- `lib/ui/settings/settings_screen.dart:219-251,275-314` -- the `IA y voz` group (where the camera row lands) and `_ReactivationRow`, the reactivation precedent (`settings_controller.dart:97-134` mic premise + `openAppSettings`).
- `test/ui/dispenser/dispenser_screen_test.dart:632-648` -- harness; `test/ui/capture/capture_screen_test.dart:209-300` -- entry + 48dp geometry pin precedent (grows the second entry and two-glyph clearance).
- `lib/l10n/app_es.arb:408` (`lapisEntry` pattern), `:184-218` (scan strings already shipped) -- new keys: `camaraEntry`, `scanShutter`, `settingsCameraLabel`, `settingsCameraReactivate`; audit + signoff per the string-table checks.

## Tasks & Acceptance

**Execution:**
- [x] `pubspec.yaml` -- add `camera: 0.12.0+2` (exact pin, spine-decided); `make deps`; one Gradle `--re-freeze`; `make check` green or an Ask-First trip -- the capture dependency enters the build visibly
- [x] `android/app/src/main/AndroidManifest.xml` + `tool/check_android_manifest.dart` -- declare CAMERA and grow `permittedPermissionsByVariant` in the same change, dated (INTERNET's 4-4 precedent) -- policy-visible and deliberate
- [x] `packages/core/lib/log/log_entry.dart` + `packages/core/lib/commands/scan_commands.dart` -- the `face_refused` kind (payload-less, `app_opened` precedent), its entry subtype and single minter; census + pattern tests updated -- the refusal is recordable before any surface exists
- [x] `packages/core/lib/ports/files_port.dart` + `lib/files/app_files.dart` -- additive scan-cache mechanics: write a frame file, unlink a scan's directory, `scanId` one clean segment, nothing existing reopened -- the frame has a home that 5.4's lifecycle will govern
- [x] `packages/core/lib/derive/` (new `camera_entry.dart`) + `packages/core/lib/commands/settings_commands.dart` + `packages/core/lib/settings/settings.dart` -- the sanctioned camera-enabled key (default enabled) and the pure fold: visible = enabled ∧ (no `permission_refused{camera}` row ∨ enabled-write later than the last refusal row); core tests cover the five states -- visibility is derived, never stored; the toggle is the reactivation
- [x] `packages/core/lib/ports/face_gate_port.dart` -- port + sealed outcome (`FaceGatePass` / `FaceGateRefusal`), core-pure vocabulary on the SlicerPort precedent; `packages/core/test/ports_test.dart` 6→7 pin -- the fragile ML Kit dependency sits behind a seam (AD-11 promotion stays cheap)
- [x] `lib/plugins/camera/` (new) -- shell facade interface (availability, open with the four outcomes, takePicture, dispose, preview) + the `camera` plugin implementation -- the plugin is wrapped, never imported past this dir
- [x] `lib/plugins/mlkit_face/` (new) -- `FaceGatePort` adapter: BAR interim config verbatim (accurate, `minFaceSize: 0.0`, all switches off), `InputImage.fromFilePath` on the written frame, ≥ 1 face → refusal, retry-once, `close()` in `finally` -- production runs what 5.1 measured
- [x] `lib/scan/scan_controller.dart` (new) -- the shoot flow: open (first-use permission), shoot → write frame to the scan's cache subdirectory → gate → branch (refusal: row + unlink + push calm surface; pass: quiet close + unlink); terminal-path unlink on every exit; rows through the core minters over the shared `LogWriteQueue`
- [x] `lib/ui/scan/scan_screen.dart` (new) -- camera preview, one shutter action (48dp target, `scanShutter` semantics), OS back as the way out (no styled second exit, NoSlicer precedent) -- A-slim on the shoot surface
- [x] `lib/ui/dispenser/dispenser_chrome.dart` + `dispenser_screen.dart` + `lib/dispenser/dispenser_controller.dart` -- the Cámara entry beside Lápiz (Lápiz stays at `end: 0`), visibility from the read cycle, opener with the rapid-tap guard; wide-ground clearance clears two glyph zones -- chrome, grammatically identical to Lápiz
- [x] `lib/ui/settings/settings_screen.dart` + `lib/settings/settings_controller.dart` -- the single camera row in `IA y voz`: switch bound to the setting; when a refusal row exists, the quiet reactivation affordance joins it (`openAppSettings`, mic-row premise twin) -- UX-DR33
- [x] `lib/l10n/app_es.arb` + regenerated strings -- the four keys (and `scanOpenFailed` with the channel task); descriptions + Sergio signoff entries -- the single string table discipline holds
- [x] `lib/main.dart` -- thread camera facade, gate adapter and scan controller as optional seams (null = test seam) -- the composition root owns every adapter
- [x] `android/app/src/main/kotlin/dev/dorogoy/organizer/CameraChannel.kt` + `lib/plugins/camera/` + `tool/check_wire_contracts.dart` -- the fourth channel (request CAMERA, fast-path an existing grant, empty grants -> `interrupted`, explicit denial -> `refused`), the Dart half beside the facade, `open()` reworked to ask through it first, the wire-contract seal grown with tests -- the domains are separated where the plugin folds them
- [x] `lib/ui/scan/scan_screen.dart` + `lib/l10n/app_es.arb` -- the system-problem notice state (`scanOpenFailed`) for interrupted/failed opens: the surface stays and communicates, no rows, entry untouched
- [x] Tests (new + extended) -- core: kind/census/minter, entry fold, scan-cache mechanics; shell: scan controller against fakes for **every** I/O matrix row, scan surface (shutter semantics, back), dispenser entry (default present; absent after refusal row, after disable; geometry 48dp + beside Lápiz + two-glyph wide-ground clearance; capture geometry pin updated), settings row (toggle writes; reactivation appears only when refused), `Nuevo proyecto` renders identically with camera disabled (census), egress import seal green
- [x] Gate -- `make gate` + `make check` green inside devbox

**Acceptance Criteria:**
- Given the Dispenser with no camera refusal and the camera enabled, when it renders, then the Cámara entry is present top-right beside Lápiz — one tap, 24px glyph in a 48dp target, `icon-mass-neutral`, ordinary treatment (FR-16, UX-DR15, UX-DR24).
- Given the app's entry and first run, when no scan has ever been attempted, then the CAMERA permission has never been requested (AD-17, NFR8).
- Given a refused or revoked camera permission, when the Dispenser next renders, then the entry is simply absent — never greyed, never explained — and one `permission_refused{camera}` row exists per refusal event (FR-16, AD-17, UX-DR24).
- Given Settings' single camera row, when it is used, then it owns both the disable toggle and the reactivation, and re-enabling restores the entry with the OS permission requested again only at the next first use (FR-16, UX-DR33).
- Given the camera disabled outright, when the Dispenser renders and `Nuevo proyecto` is opened, then the entry never appears and nothing behind `Nuevo proyecto` references the photo (FR-16).
- Given a shot, when it is handled, then the frame is written to that scan's own cache subdirectory before the face gate runs, and no upload path is reachable from this story (FR-16, AD-8 — `ScanConsent` is 5.4's to mint).
- Given a person or face detected in the frame, when the scan is handled, then it is refused on-device with the `personInFrame` offer to reframe on the one calm surface, a `face_refused` row is appended, and the frame is unlinked — the refusal is about the frame, never about the user (FR-25, AD-21).
- Given the gate passing, when the scan ends, then the surface closes quietly and no frame lingers on disk — the chain continues in 5.5.

## Spec Change Log

- **2026-09-05 — ruling 1-B: system problems are communicated, never folded into refusal logic.** The plugin folds a system-interrupted request (empty grants) into `CameraAccessDenied`, making the shipped "dismissed dialog closes quietly" row undeliverable. Sergio ruled the domains apart: the spec governs user–app logic; system malfunctions are *communicated*, never hidden, never mistaken for the user's refusal. Amendment: the permission moment moves to our own `dev.dorogoy.organizer/camera` channel (DictateChannel's pattern — the spine's fourth channel, AD-11 growth being this ruling's consequence; capture stays plugin-served), answering `granted | refused | interrupted`; `interrupted` and device-open failures render an honest notice (`scanOpenFailed`) on the scan surface — no row, entry intact. Always bullet 1 and the matrix rows "Dialog dismissed"→"Dialog interrupted", "No camera hardware"→"Camera failed to open" amended in the builder's name. Avoids: a system-swallowed dialog being recorded as the user's refusal, silently, entry gone.
- **2026-09-05 — ruling 2-A: the real-face on-device leg is deferred.** No host webcam; the emulator's virtual scene holds no person. The refusal branch was verified against fakes; the ML Kit invocation is 5.1's measured seam (same pin, config, input path). Sergio ruled the face distinction dispensable — deferred, to be discarded outright if it grows too complicated or resource-heavy. The leg moves to his handset or a webcam session whenever one exists.

## Design Notes

- **No probe, by construction.** The camera plugin's only status check *is* the request (`initialize()`), so an active probe at render would ask at app entry. Visibility is log-derived; OS-side recovery is explicit (the Settings row). `enabled ∧ (no refusal row ∨ enabled-write after the last refusal row)` makes the toggle itself the reactivation — insert-only-safe; "reversible only in Settings" holds literally. This is the camera pattern EXPERIENCE.md ruled would govern the mic too.
- **The refusal has a shipped home.** 4-5 built `personInFrame` + the calm surface with Epic 5's scan path named as a caller; the copy *is* the offer to reframe. Zero new surfaces; the way on is retapping Cámara — same tap count.
- **Production stays inside the measurement.** The gate reads the written cache file via `InputImage.fromFilePath` — the exact path the 5-1 instrument scored; decode and orientation travel with the file.
- **Fail closed, never falsely refused.** A detector error (after retry-once) aborts without a `face_refused` row: a failure is not a refusal, and the log must not claim a privacy decision that was not made — the same domain separation as ruling 1-B, at the gate.
- **The pass branch is deliberately silent.** No consent surface exists (5.5), so a passing frame has no consumer; lingering with no sweep (5.4's) would be the story's one privacy defect. Close, unlink, leave the seam where 5.5 wires the continuation.
- **Where the subdirectory comes from.** `FilesPort`'s doc already reserves `scan_cache`; this story adds only write/unlink mechanics for one clean `scanId` segment — the ≤ 2-files invariant, every-terminal-path contract and `app_opened` sweep are 5.4's.

## Verification

**Commands:**
- `devbox run -- make gate` -- expected: green (format, analyze, all tests)
- `devbox run -- make check` -- expected: green (CAMERA in the manifest map by deliberate edit; re-frozen Gradle allowlist; string-table audit; egress import seal; core purity; codegen-check green once the story commit lands)

**Manual checks (emulator leg, AGENTS.md recipe; screencap + OCR):**
- Boot `organizer36`: entry beside Lápiz; open → the system dialog appears **on the surface**; grant → preview shoots; shoot on the people-free virtual scene → quiet close, no row, `scan_cache` empty.
- `pm revoke` after a grant, reopen → refusal path: entry absent; Settings reactivation affordance; toggle off/on → entry returns; next open re-requests.
- Disable the row outright → entry gone, `Nuevo proyecto` unchanged.
- Pull `organizer_substrate.sqlite` after each leg: exactly one `permission_refused{camera}` per explicit denial, one `face_refused` per refusal, nothing on interrupted or failed opens.
- **Deferred (ruling 2-A):** the real-face leg — Sergio's handset or a webcam session whenever one exists; the face distinction is ruled dispensable.

## Suggested Review Order

**Ruling 1-B — the two permission domains, separated where the plugin folds them**

- Entry point: the staged ask — an existing grant fast-paths, empty grants answer `interrupted`, explicit denial `refused`
  [`CameraChannel.kt:62`](../../android/app/src/main/kotlin/dev/dorogoy/organizer/CameraChannel.kt#L62)

- The four outcomes with the domain split documented (denied is the log's alone; interrupted/unavailable the notice's)
  [`camera_shell.dart:46`](../../lib/plugins/camera/camera_shell.dart#L46)

- The channel asks first; the plugin's own ask becomes the revocation-discovered denial only
  [`plugin_camera_shell.dart:64`](../../lib/plugins/camera/plugin_camera_shell.dart#L64)

- The plugin's error code mirrored and pinned — a rename fails loudly, never silently remaps
  [`plugin_camera_shell.dart:45`](../../lib/plugins/camera/plugin_camera_shell.dart#L45)

**The entry and its one visibility fold**

- `cameraRefusalStanding` — the single definition the entry, the Settings premise and the core tests all agree on
  [`camera_entry.dart:54`](../../packages/core/lib/derive/camera_entry.dart#L54)

- The Cámara entry beside Lápiz, `_LapizEntry`'s grammar verbatim, CameraGlyph 24px in the 48dp target
  [`dispenser_chrome.dart:273`](../../lib/ui/dispenser/dispenser_chrome.dart#L273)

- The single Settings row owning both the switch and the reactivation, on `_ReactivationRow`'s merged grammar
  [`settings_screen.dart:433`](../../lib/ui/settings/settings_screen.dart#L433)

**The shoot chain — cache before gate, nothing lingers**

- The additive scan-cache vocabulary: write a frame, unlink the scan, one clean `scanId` segment
  [`files_port.dart:57`](../../packages/core/lib/ports/files_port.dart#L57)

- The plugin's own shot file deleted in the same breath — best-effort, quiet by contract
  [`app_files.dart:43`](../../lib/files/app_files.dart#L43)

- The core port + sealed outcome; the fragile ML Kit dependency sits behind a seam (AD-11 stays cheap)
  [`face_gate_port.dart:52`](../../packages/core/lib/ports/face_gate_port.dart#L52)

- The BAR interim rule verbatim — accurate, `minFaceSize: 0.0`, `fromFilePath` on the written frame
  [`mlkit_face_gate.dart:30`](../../lib/plugins/mlkit_face/mlkit_face_gate.dart#L30)

- The system-problem notice (`scanOpenFailed`): the surface stays and communicates, never pops to silence
  [`scan_screen.dart:145`](../../lib/ui/scan/scan_screen.dart#L145)

**Core vocabulary — the refusal is recordable**

- The seventeenth kind, payload-less on the `app_opened` precedent — no schema change
  [`log_entry.dart:102`](../../packages/core/lib/log/log_entry.dart#L102)

- Its single minter — one kind, one file, the established discipline
  [`scan_commands.dart:33`](../../packages/core/lib/commands/scan_commands.dart#L33)

**The deliberate seal edits**

- CAMERA enters the main manifest with the permission map grown in the same change
  [`AndroidManifest.xml:13`](../../android/app/src/main/AndroidManifest.xml#L13)

- The re-freeze, every transitive mover traced to the camerax closure and annotated
  [`check_gradle_dependencies.dart:51`](../../tool/check_gradle_dependencies.dart#L51)

- The wire-contract seal grows the fourth channel — three shipped, notify reserved
  [`check_wire_contracts.dart:23`](../../tool/check_wire_contracts.dart#L23)

**Peripherals — the covering tests**

- The privacy branch executed: refusal on ≥1 face, pass on 0, throw past retry, close on every path
  [`mlkit_face_gate_test.dart:45`](../../test/plugins/mlkit_face_gate_test.dart#L45)

- Every I/O matrix row against fakes, including the close-epoch races (late grant, shoot vs exit)
  [`scan_controller_test.dart:1`](../../test/scan/scan_controller_test.dart#L1)

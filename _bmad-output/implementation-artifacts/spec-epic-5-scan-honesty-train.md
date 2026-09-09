---
title: 'Epic 5 scan-honesty train — abandon cancels, functioning failures speak'
type: 'bugfix'
created: '2026-09-09'
status: 'done'
review_loop_iteration: 0
# review: no loopback; patch findings applied in step-04
baseline_commit: 'abe8aca562557d2819d88890ac5c3f42a4718920'
context:
  - '{project-root}/_bmad-output/implementation-artifacts/epic-5-retro-2026-09-09.md'
  - '{project-root}/project-context.md'
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** Leaving a scan can still land a plan or keep an HTTP POST alive; a missed shot or detector crash still pops as if nothing happened. Epic 6 must not open on that chain.

**Approach:** Make scan abandonment match genesis (epoch in the landing queue, cancel the in-flight POST, close even while shooting) and route functioning camera failures through the existing `scanOpenFailed` notice.

## Boundaries & Constraints

**Always:**
- Functioning failures are communicated (`project-context.md`). Anti-frustration is task-spirit only.
- `scanOpenFailed` is the notice. No new ARB key, no eighth `SlicerFailureCause`, no new `NoSlicerCause`.
- Detector throw and missed shot: unlink, **no** `face_refused` / `permission_refused`.
- Close mid-wait: one `scan_abandoned`, stale answer, no landing, no `epic_activated`.
- Abort is transport-only. Consent stays consumed (AD-8). Three payload shapes unchanged.
- HTTP stays in `lib/egress/`. Do not `http.Client.close()`. Abort the in-flight send Completer, not the process client (shared with rescue).
- Close-after-abort that already bumped `_epoch` returns Stale, not `networkUnreachable`/`offline`.
- `_openInFlight` still skips close (permission dialog owns `inactive`).

**Ask First:**
- Folding `_onShoot`'s `on Object` catch (the `throwOnShoot` widget path) onto `scanOpenFailed` — production `takePicture` does not throw; leave it unless Sergio says fold it.
- Applying genesis honest-delivery (store throw ≠ Delivered) to genesis itself — this train is scan.

**Never:**
- Pose/object packs, face-gate composition, APK bloat, Epic 6 stories.
- Fourth egress payload, retry after abort, reconstructing consent, wait-surface timeout.
- Quiet-closing `CameraShotNone` or detector throw.
- Treating empty `framePath` / missing gate / epoch-stale close as Failed (those stay Closed).
- Changing consent-gate `inactive` (transient occlusion) to match scan's inactive-close.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Close while landing queued | Slice delivered; `LogWriteQueue` blocked; `close()` | `ScanConsentStale`; `consent_granted` + `scan_abandoned`; no facts, no `epic_activated` | In-queue `_epoch` no-ops the landing |
| Store throw on landing | `_ThrowingFactStore` after delivered slice | Not `ScanConsentDelivered` | Surface maps the throw; queue does not stall |
| Close mid-POST | Real `ByokSlicer` + abortable request in flight | `abortTrigger` completed; one `scan_abandoned`; Stale | No retry; token stays burned |
| Background during shutter | `_shooting`; lifecycle `inactive` | `close()`; unlink + dispose **before** the shot completes | Late shot → `ScanShootClosed` (left, not Failed) |
| Missed shot | `CameraShotNone` | `ScanShootFailed` → `scanOpenFailed`; surface stays; no row | Unlink |
| Detector throw | `gate.gate` throws | `ScanShootFailed` → `scanOpenFailed`; no `face_refused` | Unlink |
| AccessLost | `CameraShotAccessLost` | Unchanged Failed + notice | Unchanged |
| Close during shot/gate | Existing `shotGate` races | Still `ScanShootClosed`; no Failed notice | Epoch already pins this |

</frozen-after-approval>

## Code Map

- `lib/scan/scan_controller.dart` -- `_epoch` :228; `_sliceInFlight` :210; `grantConsent` :590–701 (clears in-flight at :639/:657 **before** persist — genesis does not); delivered :682–686 always `ScanConsentDelivered`; `_appendScanSliceFailed` :747–748 no epoch; `_appendScanLanded` :771–825 no epoch, `catchError` :824; shoot None :329–331 Closed; detector `on Object` :365–369 Closed; AccessLost already Failed :332–339; `close` :421–434.
- `lib/genesis/genesis_controller.dart` -- **read-only copy source.** Keep wait armed through persist (:200–202). `_appendGenesisSliceFailed` in-queue epoch :345/:349. `_appendGenesisLanded` :379/:388/:407. Caller epoch-after-await :225–233. Do not change genesis outcomes this train.
- `lib/session/log_write_queue.dart` -- **read-only.** Blocker pattern: genesis test :599–610.
- `lib/egress/byok_wire.dart` -- `abortTrigger` only on timeout :311–338. Keep `wireSendTimeout`.
- `lib/egress/byok_slicer.dart` -- one POST :87–93; `ClientException` → `networkUnreachable` :177–180. Add `abortInFlight()` completing the send Completer. No-op on Local/Managed.
- `lib/egress/egress_dispatch.dart` -- consume-then-cap :76–91 **read-only**.
- `lib/ui/scan/scan_screen.dart` -- lifecycle skips close while `_shooting` :144; Failed already → `_openFailed` + `scanOpenFailed` :264–276, :341–368; Closed pops :262–263. Copy consent-gate close-on-departure; keep `!_shooting` on **resume** only :127.
- `lib/ui/scan/consent_gate_screen.dart` -- **read-only.** Close on hidden/paused/detached :126–138; does **not** close on inactive.
- `lib/plugins/camera/camera_shell.dart` -- None comment still says quiet close :85–88; update comment only.
- `packages/core/lib/ports/face_gate_port.dart` -- doc still says quiet abort :18–21; caller changes, port still throws.
- `test/scan/scan_controller_test.dart` -- invert :1109–1144 (unconditional landing) and :1257–1294 (throwing store still Delivered); add genesis-style queued-landing close; renegotiate :539 detector and :560 failed-shot to `ScanShootFailed`; keep Closed pins :575/:592/:602/:662.
- `test/genesis/genesis_controller_test.dart` -- **read-only** pattern :584–619.
- `test/ui/scan/scan_screen_test.dart` -- clone AccessLost :724 for None and throwing gate; lifecycle :762 uses `inactive`; add `shotGate` on `_FakeCamera`; leave `throwOnShoot` :743 unless Ask First fires.
- `test/egress/byok_slicer_test.dart` -- stall pin :974; add abort-on-close/abortInFlight pin. HTTP only here.
- Read-only seals: `egress_payload.dart`, `no_slicer_cause.dart`, `app_es.arb` `scanOpenFailed` :508–512, `slicer_port.dart`, `scan_commands.dart`, `main.dart` shared slicer :93–114.

## Tasks & Acceptance

**Execution:**
- [x] `lib/scan/scan_controller.dart` -- Pass `epoch` into landing/failure writers (genesis :338–356 / :371–438). Do not clear `_sliceInFlight` before terminal persist. Drop landing `.catchError` so `grantConsent` can refuse Delivered on store throw. None + detector throw return `ScanShootFailed`.
- [x] `lib/egress/byok_slicer.dart` + `lib/egress/byok_wire.dart` -- Per-send abort Completer completable from `abortInFlight()` and from timeout. Local/Managed no-op.
- [x] `lib/scan/scan_controller.dart` + `lib/genesis/genesis_controller.dart` -- `close()` calls `abortInFlight()` after the epoch bump, before/with unlink. Genesis close only for abort; do not rewrite genesis landing.
- [x] `lib/ui/scan/scan_screen.dart` -- Drop `!_shooting` from the close arm only. Keep `_openInFlight` skip and resume `!_shooting`.
- [x] `lib/plugins/camera/camera_shell.dart` -- Comment: None is Failed notice, not quiet close.
- [x] `test/scan/scan_controller_test.dart` -- Matrix pins (queued-landing close, honest delivery, None/detector Failed).
- [x] `test/ui/scan/scan_screen_test.dart` -- None + throwing-gate notice clones of AccessLost; background-during-shutter unlink/dispose.
- [x] `test/egress/byok_slicer_test.dart` -- Abort completes `abortTrigger`; no retry.

**Acceptance Criteria:**
- Given a delivered slice whose landing is still queued, when `close()` wins, then no pool facts and no `epic_activated` land, and exactly one `scan_abandoned` follows `consent_granted`.
- Given a store throw during scan landing, when `grantConsent` settles, then the outcome is not `ScanConsentDelivered`.
- Given an in-flight BYOK POST, when scan or genesis `close()` runs, then the request abort fires and no second POST is sent.
- Given the shutter in flight, when the app goes `inactive`, then the scan is closed and unlinked before the shot returns.
- Given `CameraShotNone` or a throwing face gate, when the user is still on the scan surface, then `scanOpenFailed` is shown, the log has no refusal row, and the surface does not pop as success.

## Verification

**Commands:**
- `devbox run -- make gate` -- expected: flutter test / format / analyze all green
- `devbox run -- make check` -- expected: egress import seal, wire contracts, string-table (183 keys, `scanOpenFailed` unchanged) green

## Suggested Review Order

**Abandonment**

- Close bumps epoch then aborts the in-flight send, not the process client.
  [`scan_controller.dart:436`](../../lib/scan/scan_controller.dart#L436)

- Landing writers no-op when close already won the epoch.
  [`scan_controller.dart:805`](../../lib/scan/scan_controller.dart#L805)

- Store throw on landing is Failed, so the wait maps to no-Slicer.
  [`scan_controller.dart:703`](../../lib/scan/scan_controller.dart#L703)

**Wire abort**

- Completer registered before the first await; rescue flights are tagged and skipped.
  [`byok_slicer.dart:60`](../../lib/egress/byok_slicer.dart#L60)

- Dispatch helper so scan/genesis never import `byok_slicer.dart` (egress allowlist).
  [`local_slicer.dart:115`](../../lib/egress/local_slicer.dart#L115)

**Shoot honesty**

- Missed shot / lost grant / detector throw: Failed unless close already won.
  [`scan_controller.dart:330`](../../lib/scan/scan_controller.dart#L330)

- Backgrounding during the shutter now closes (keep `_openInFlight` skip).
  [`scan_screen.dart:145`](../../lib/ui/scan/scan_screen.dart#L145)

- Existing `scanOpenFailed` is the notice; no new string.
  [`scan_screen.dart:266`](../../lib/ui/scan/scan_screen.dart#L266)

**Tests**

- Queued-landing close, honest delivery, late None/throw → Closed.
  [`scan_controller_test.dart:540`](../../test/scan/scan_controller_test.dart#L540)

- Widget notice + unlink; background-during-shutter stays a leave.
  [`scan_screen_test.dart:737`](../../test/ui/scan/scan_screen_test.dart#L737)

- Abort completes the trigger; rescue-only flight is left alone.
  [`byok_slicer_test.dart:1018`](../../test/egress/byok_slicer_test.dart#L1018)


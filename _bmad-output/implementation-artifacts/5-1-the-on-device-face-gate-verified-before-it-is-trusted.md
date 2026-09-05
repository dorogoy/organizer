---
title: 'Story 5.1: The on-device face gate, verified before it is trusted'
type: 'chore'
created: '2026-09-05'
status: 'done'
review_loop_iteration: 0
baseline_commit: '95dc9dd47f2f081b3203bf4c4e833641593ef131'
context:
  - '{project-root}/_bmad-output/implementation-artifacts/epic-5-context.md'
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** Story 5.2 will wire a camera whose frames must be refused on-device when they contain a person (FR-25), but the face-detection dependency (`google_mlkit_face_detection` — community-maintained, one of the architecture's three named fragile dependencies) has never been measured; trusting it on its README would make the privacy promise rest on nothing.

**Approach:** Before any production scan code exists, assemble a builder-supplied photo corpus (with-people hard cases plus face-like no-people cases), write an asymmetric bar — false negatives must be zero — confirmed before any scored run, and measure the pinned plugin 0.15.1 on-device (emulator) with a throwaway integration-test probe; record findings and the unblock-or-escalate ruling in a committed evidence pack, then delete the instrument.

## Boundaries & Constraints

**Always:**
- The bar is written and builder-confirmed (dated marker in `face-gate/BAR.md`) before any scored run; mid-story amendments are dated entries, never silent (4-1 `PASS-BAR.md` precedent).
- Detection runs on-device through the pinned plugin (`google_mlkit_face_detection 0.15.1`, exact pin, spine Stack table) — the instrument measures what 5.2 will ship; the probe contains no upload path and imports nothing from `lib/egress/`.
- Corpus photos of people are machine-local: `face-gate/corpus/photos/` is gitignored; the committed `manifest.json` carries pseudonymous ids and ground truth only (3-1 declared-redaction discipline). Probe source and results contain no image bytes.
- False negatives are findings, not tuning: any FN is escalated with the two recorded remedy options (AD-11 platform-channel promotion; tighter detection configuration), decided against the measurement — never absorbed silently.
- Every resolved-Gradle-graph change is re-frozen deliberately (`dart run tool/check_gradle_dependencies.dart --re-freeze`), and the merged-manifest check stays green or is amended visibly.
- The instrument is deleted once evidence is captured (hash-level add/delete recorded), with the probe source preserved verbatim at `face-gate/probe/`; the story ends with the completion gate green (`make gate`, `make check`).

**Ask First:**
- `make check` trips on the merged manifest after the plugin is added (entries outside the enumerated set) — amending AD-7's seal-3 set is policy-visible.
- Any false negative on the corpus (the remedy decision is Sergio's).
- The resolved Gradle graph shows the detection model is Play-Services-served (unbundled) rather than bundled — voids the emulator-only transfer argument; a handset leg or a different ruling is needed before 5.2 trusts the gate.
- ML Kit fails to load or run on the emulator at all.

**Never:**
- No production scan/camera/consent code: no `FaceGate` port, no new log kinds (`face_refused` is 5.2's), no substrate or `FilesPort` changes, no UI strings, no `CAMERA` permission.
- No corpus photo or raw image bytes are ever committed.
- No new Makefile targets or permanent `tool/` checks — the instrument is throwaway.
- No trust absorbed from the plugin's README or documentation — only from the measurement.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|---------------|----------------------------|----------------|
| Frame with a person, hard case | Corpus photo, class `person` (partial / profile / distance / low-light / mirror / print-on-wall) | Detector flags a face → correct refusal, counted as gate-pass | Detection error on one image → row recorded `error`, rerun once; still error → declared indeterminate, never silently dropped |
| Frame without a person, face-like object | Corpus photo, class `no-person` | May flag (false positive — recorded and accepted; cost is one reframe offer, FR-25) or pass | Same as above |
| Missed person (false negative) | `person` photo the detector passes | FN count > 0 → run fails the bar → escalation finding with remedy options | Bar failure is the escalation path, not a crash |
| Unconfirmed bar | `face-gate/BAR.md` lacks the dated builder-confirmation marker | Probe refuses to score, exits with marker message | N/A — refusal is correct behaviour |
| Undecodable image | Corrupt or unsupported bytes in the corpus | Row recorded `error`, excluded from FN/FP denominators, reported in report.md | Builder replaces the file or the row stays declared-error |

</frozen-after-approval>

## Code Map

- `face-gate/` -- NEW committed evidence pack, mirroring `eval/`'s split: `BAR.md` (bar + baseline detector config + dated confirmation + amendments), `corpus/manifest.json` (pseudonymous ground truth), `probe/face_gate_probe_test.dart` (verbatim preserved copy, post-deletion), `results/report.md` (findings + ruling), `results/runs/<n>.json` (machine outputs).
- `face-gate/corpus/photos/` -- NEW, gitignored: builder-supplied corpus, machine-local forever.
- `integration_test/face_gate_probe_test.dart` -- NEW throwaway instrument: runs on the emulator, reads bar + corpus from the app's external-files dir, runs the plugin's `FaceDetector` with the pinned config, writes per-image JSON plus FN/FP summary; deleted after evidence capture (add/delete hashes recorded in the report).
- `pubspec.yaml` -- add `google_mlkit_face_detection: 0.15.1` (stays: spine-pinned, 5.2 consumes it) and `integration_test` dev-dependency (stays: keeps the preserved probe copy analyzer-resolvable).
- `tool/check_gradle_dependencies.dart` -- read-only reference; its committed allowlist is re-frozen once the plugin resolves new Gradle entries.
- `android/app/build.gradle.kts:30-35` -- read-only: `abiFilters arm64-v8a, x86_64` already enforces 64-bit-only; AC evidence is `unzip -l` of the built APK showing no 32-bit ML Kit libs.
- `_bmad-output/planning-artifacts/architecture/architecture-organizer-2026-08-26/ARCHITECTURE-SPINE.md` lines 259, 388, 110-114 -- read-only: version pin + community-maintained provenance, the three-fragile-deps list, and AD-11's rule; the report's provenance section cites these.
- `AGENTS.md` → "Android emulation setup" -- the emulator recipe (AVD organizer36, adb via `ANDROID_HOME`, app install) the device leg follows.
- Precedent specs (read-only): `_bmad-output/implementation-artifacts/4-1-the-model-evaluation-harness-and-provider-selection.md` (bar-before-run; committed-metadata/gitignored-photos split) and `3-1-on-device-recognition-availability-verified-on-the-handsets.md` (throwaway instrument deleted with hash evidence; declared redaction).

## Tasks & Acceptance

**Execution:**
- [x] `face-gate/BAR.md` -- write the asymmetric bar (FN target zero across the corpus; FP accepted and recorded), the corpus floor (at least 2 photos per hard-case category across all six: partial, profile, distance, low-light, mirror, print-on-wall; at least 3 no-person face-like), and the baseline `FaceDetectorOptions` with exact values (performance mode, minFaceSize, landmarks/classification/tracking off) -- the bar exists before the measurement does
- [x] `face-gate/corpus/manifest.json` + `face-gate/corpus/photos/` -- builder supplies photos (manual gate: Sergio); write the pseudonymous manifest with class + hard-case category per photo; gitignore the photos dir -- ground truth committed, images never *(16 photos supplied 2026-09-05; manifest p01–p16; photos gitignored, verified invisible to git)*
- [x] `pubspec.yaml` -- add the plugin and `integration_test` dev-dep; `make deps`; re-freeze the Gradle allowlist; `make check` green or an Ask-First trip -- the measurement target enters the build visibly *(seal 2 re-frozen deliberately 2026-09-05; seal 3 tripped → Ask-First, unamended — see face-gate/results/report.md)*
- [x] `integration_test/face_gate_probe_test.dart` -- write the probe: parses BAR.md and refuses to score without the dated confirmation; runs the pinned config over the corpus; writes per-image JSON + FN/FP summary to the external-files dir *(refusal verified on-device on emulator organizer36, 2026-09-05)*
- [x] Device leg (AGENTS.md recipe) -- build; adb-push bar + corpus to `/sdcard/Android/data/dev.dorogoy.organizer/files/facegate/`; run the probe on emulator organizer36; pull results into `face-gate/results/runs/`; record from the resolved graph whether the model is bundled, with evidence -- the measurement *(run 1 scored 2026-09-05T18:31:05Z: 6 FN / 12, `face-gate/results/runs/1.json`; run 2 voided by infrastructure — pose-era strips broke pose, 16/16 error rows, no runs/2.json, diagnostic banked under results/diagnostics/; gate composition deferred by builder ruling 2026-09-05, face-only interim gate verified by the final-state smoke on the final tree; model verified bundled — evidence in the report)*
- [x] `face-gate/results/report.md` -- record findings: provenance (community-maintained, not by Google; fragile-deps list; AD-11 promotion candidate — citing spine lines), pinned config, corpus composition, FN/FP table, ABI evidence, bundled-vs-unbundled evidence, and the ruling: zero FN → gate verified, 5.2 unblocked; any FN → escalation with both remedy options -- the deliverable *(three escalations narrated to the final deferral ruling: run 1's 6 FN/12 → a third remedy chosen, outside the two recorded options (1. AD-11 promotion, 2. tighter configuration); run 2 voided + diagnostic 3 FN/12 banked; composition deferred, face-only interim gate, risk accepted in Sergio's name with the reopen condition before 5.5)*
- [x] `face-gate/probe/face_gate_probe_test.dart` -- preserve the probe verbatim; delete `integration_test/`; record add/delete hashes in the report -- instrument deleted, re-runnable from the evidence pack *(v1 preserved verbatim + its unit tests with one declared import fix; v2 preserved under distinct names for the deferred reopen, excluded from analysis via a dated entry while the pose dep is out; sha256 add/delete identity for both in the report)*
- [x] Gate -- `make gate` and `make check` green after deletion; the preserved probe copy is formatted and analyzer-clean *(both green 2026-09-05; format 214 files 0 changed, analyze clean, 834 tests + 94 eval tests)*

**Acceptance Criteria:**
- Given the plugin's provenance, when `face-gate/results/report.md` is written, then it notes community-maintained/not-by-Google status and the fragile-dependency listing with AD-11 promotion candidacy, citing the spine.
- Given the corpus, when assembled, then it holds with-people photos covering all six hard-case categories and no-people photos with face-like objects, per the BAR floor, images machine-local and ground truth committed.
- Given the bar, when the probe runs, then it refuses to score unless BAR.md carries the dated builder confirmation, and bar plus exact detector config predate the first scored run.
- Given a false positive, when one occurs, then it is recorded in report.md and accepted — the offer to reframe is the specified behaviour (FR-25).
- Given any false negative, when one occurs, then it is escalated as a finding with both remedy options recorded (AD-11 promotion; tighter configuration), decided against the measurement — never absorbed as tuning.
- Given the detection, when it runs, then it ran on-device (emulator, plugin 0.15.1, pinned config) through an instrument with no upload path, and report.md states both.
- Given the build, when ABIs are checked, then the built APK ships only `arm64-v8a` and `x86_64` native libs — the existing abiFilters verified, not changed.
- Given story end, when the instrument is deleted, then the tree carries only the evidence pack plus the dependency/allowlist changes, and `make gate` / `make check` are green.

## Spec Change Log

- **2026-09-05 — escalation 1 ruled; gate widened to persons (bar amendment).** Run 1 (face-only) scored 6 FN / 12 and escalated; Sergio ruled in session for a remedy outside the two recorded options: the gate's composition widens to persons — face detection ∨ pose detection ⇒ refuse — with `minFaceSize` 0.05 → 0.0 subsumed. Recorded as the dated amendment in `face-gate/BAR.md`; dependency `google_mlkit_pose_detection 0.16.1` added (pub.dev-verified latest); seal 2 re-frozen a second time; seal 3 surgery extended per ruling-1 policy (pose registrar baselined; work/acceleration machinery stripped); probe extended to both detectors (v2).
- **2026-09-05 — escalation 2: STOP before run 2's tally.** On the policy build the pose detector errors on every image (`MlKitException: Internal error`) — the run-2 attempt was voided by infrastructure (16/16 error rows, nothing scored; no `runs/2.json`). Diagnostics: stripping the pose closure's work/acceleration entries is the cause (pose works with them lifted, E2); restoring the acceleration service alone does not fix it (E3). A diagnostic run on the lifted build measured the amended gate at 3 FN / 12 (`partial` 0/2, `distance` 1/2) — recorded in `face-gate/results/report.md` → "Amendment cycle". Per the ruling discipline, no remedy chosen or applied; both the seal-policy question and the residual-FN question return to Sergio. The instrument (probe v2) stays in `integration_test/` for the next re-run; spine untouched (the stack-table update is close-out work, gated on FN = 0).
- **2026-09-05 — escalation 3 ruled: composition DEFERRED; story closed in a coherent face-only state.** Sergio's final ruling (in session): the gate-composition effort is deferred until there is more data — the cost spiral (~22 MB pose on-device, added latency, a second fragile surface, contingent AD-11) outweighs the benefit while nothing uploads until 5.5 (AD-8's compile-time `ScanConsent` precondition), and 5.2 usage will produce better data (real scan frames, real refusal rates) than the 16-photo proxy. **Known-bad state avoided:** an incoherent tree shipping a pose dependency that cannot run under the seal policy its closure requires (E1/E3) — the tree is returned to exactly the face-era state run 1 verified: pose plugin removed, allowlist re-frozen back to the face-only closure, pose-era manifest strips and seal-3 baseline additions reverted (PoseRegistrar out; face registrars/network strips/emoji2 disposition unchanged). **Kept:** the escalation discipline (three builder rulings, all in session, all dated in BAR.md/report.md) and the banked diagnostics (run-1 JSON, lifted-build diagnostic JSON, final-tree smoke JSON, probe v1 + v2 preserved at `face-gate/probe/`). Interim gate: face-only accurate `minFaceSize: 0.0`; risk accepted in Sergio's name; reopen before 5.5 ships the first payload. Recorded in `deferred-work.md`; the spine's stack table correctly still lists no pose dependency.
- **2026-09-05 — review patch: `integration_test` dev-dependency dropped (deviation from the Code Map's "dev-dep stays" note).** Cause: review finding — the binding's junit/hamcrest/androidx.test closure sat permanently in the debug/profile runtime graphs for inert evidence files; the `analysis_options.yaml` exclusion of the preserved probes achieves the same resolvability story without the graph cost. Allowlist re-frozen accordingly (the instrumentation closure left); `make check` green.

## Design Notes

- Why a throwaway integration test rather than an androidTest probe or an `eval/`-style package: the measurement must go through the pinned Flutter plugin (what 5.2 ships), needs the device (ML Kit native libs), and must leave zero shipped-surface contact — `integration_test/` deleted after evidence is 3-1's pattern applied at the plugin layer; `eval/` is host-side by design (closed egress, AD-7/AD-12).
- Emulator-only transfer argument: if the resolved graph shows the model bundled in the APK, detection is a property of the app's own binaries and the emulator measurement transfers; unbundled (Play-Services) voids it — hence the Ask-First.
- The probe reads/writes the app's external-files dir (no permissions needed, adb-reachable); `InputImage.fromFilePath` handles decode; a corrupt file surfaces as an `error` row, not a silent skip.
- FN/FP are defined against the manifest's ground truth: FN = `person` photo with zero faces detected; FP = `no-person` photo with at least one face detected.

## Verification

**Commands:**
- `devbox run -- make gate` -- expected: green (after instrument deletion; preserved probe copy formatted and analyzer-clean)
- `devbox run -- make check` -- expected: green (re-frozen allowlist covers the plugin's resolved graph; manifest enumerated set unchanged unless visibly amended)
- `unzip -l build/app/outputs/flutter-apk/app-debug.apk | grep lib/` -- expected: only `arm64-v8a/` and `x86_64/` paths

**Manual checks (device leg, builder-in-the-loop):**
- Sergio confirms BAR.md with the dated marker before the scored run, supplies the corpus photos, and reviews `face-gate/results/report.md` — the ruling (unblock 5.2, or escalate a remedy when any FN exists) is his call.

## Suggested Review Order

**The ruling trail (this story's product is the decision record)**

- Entry point — the interim rule of record and why the composition blocks are historical
  [`BAR.md:3`](../../face-gate/BAR.md#L3)

- Final deferral ruling: cost table, accepted interim risk, reopen condition
  [`report.md:467`](../../face-gate/results/report.md#L467)

- First escalation: face-only scored 6 FN / 12, remedies menu, builder picks composition
  [`report.md:311`](../../face-gate/results/report.md#L311)

- Second escalation: run 2 voided by the seal strips, lifted-build diagnostic banked
  [`report.md:339`](../../face-gate/results/report.md#L339)

**The measurement evidence**

- The scored run: per-photo verdicts under the confirmed bar
  [`1.json:1`](../../face-gate/results/runs/1.json#L1)

- Final-tree smoke artifact — the 4 FN / 12 interim-risk figure reproduces from the pack
  [`final-tree-smoke.json:1`](../../face-gate/results/diagnostics/final-tree-smoke.json#L1)

- Face ∨ pose diagnostic on the lifted build (banked for the reopen)
  [`lifted-manifest-diagnostic.json:1`](../../face-gate/results/diagnostics/lifted-manifest-diagnostic.json#L1)

- FN/FP table with per-category faces/poses detail
  [`report.md:96`](../../face-gate/results/report.md#L96)

**AD-7 seal surgery (builder ruling, option a)**

- Network-facing merged entries stripped via manifest merger
  [`AndroidManifest.xml:25`](../../android/app/src/main/AndroidManifest.xml#L25)

- Minimal ML Kit init set baselined with justification (plus fixtures/tests)
  [`check_android_manifest.dart:86`](../../tool/check_android_manifest.dart#L86)

- Gradle allowlist re-frozen to the face-only closure (twice reverted from pose eras)
  [`check_gradle_dependencies.dart:43`](../../tool/check_gradle_dependencies.dart#L43)

**Build surface and privacy guard**

- The measured dependency enters as an exact pin
  [`pubspec.yaml:45`](../../pubspec.yaml#L45)

- Preserved probes stay analyzer-clean without carrying the instrumentation graph
  [`analysis_options.yaml:20`](../../analysis_options.yaml#L20)

- Corpus photos are machine-local forever (the Never rule's mechanism)
  [`.gitignore:75`](../../.gitignore#L75)

**Reopen readiness**

- Preserved instruments (v1 = run 1 + final smoke; v2 = pose era) with sha256 identity
  [`face_gate_probe_test.dart:1`](../../face-gate/probe/face_gate_probe_test.dart#L1)

- Nine known probe defects to fix on restore — recorded, deliberately not patched
  [`report.md:620`](../../face-gate/results/report.md#L620)

- Operator recipe: which copy restores under which name
  [`report.md:283`](../../face-gate/results/report.md#L283)

**Deferred registry**

- Composition deferral + the two review-deferred guards (pin check, gitignore check)
  [`deferred-work.md:1`](deferred-work.md#L1)

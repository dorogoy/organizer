# Face gate — measurement report (story 5.1)

**Status: CLOSED IN DEFERRAL — face-only interim gate, composition
banked for the pre-5.5 reopen.** Three escalations, all ruled on by
the builder in session on 2026-09-05:

1. Run 1 (face-only, `minFaceSize: 0.05`) scored **6 FN / 12** —
   remedy: a third option, outside the two recorded ones (1. AD-11
   promotion, 2. tighter configuration): widen the gate to
   persons, face ∨ pose, with `minFaceSize` 0.0 subsumed.
2. The run-2 attempt on the policy build was **voided by
   infrastructure** (the pose-era seal surgery broke pose at runtime,
   16/16 error rows, nothing scored); a diagnostic on a lifted build
   banked the composition's ceiling: **face ∨ pose = 3 FN / 12**.
3. **Deferral (final ruling):** the gate-composition effort is DEFERRED
   until there is more data — face-only is the interim production
   gate, reopened before story 5.5 ships the first scan payload.

The tree is returned to the coherent face-only state (pose dependency
removed, seals re-frozen/reverted to the face-era baselines run 1
verified), the final-state smoke below proves detection works there,
and `make gate` / `make check` are green. Baseline commit `95dc9dd`.

## Provenance (why this measurement exists)

- The dependency is **community-maintained, not by Google** — the
  architecture spine's Stack table says so verbatim for the pinned
  `google_mlkit_face_detection 0.15.1`:
  [`ARCHITECTURE-SPINE.md:259`](../../_bmad-output/planning-artifacts/architecture/architecture-organizer-2026-08-26/ARCHITECTURE-SPINE.md#L259).
- It is one of the **three named fragile dependencies**, each a
  candidate for promotion to our own platform channel under AD-11's
  rule *if verification shows the guarantee rests on the API*:
  [`ARCHITECTURE-SPINE.md:388`](../../_bmad-output/planning-artifacts/architecture/architecture-organizer-2026-08-26/ARCHITECTURE-SPINE.md#L388).
- AD-11's rule — our own channel only where the guarantee *is* an OS
  API; camera, on-device face detection and folder access stay
  plugin-served until a verification says otherwise:
  [`ARCHITECTURE-SPINE.md:110`](../../_bmad-output/planning-artifacts/architecture/architecture-organizer-2026-08-26/ARCHITECTURE-SPINE.md#L110-L114).
  This measurement is that verification — and its outcome is the
  escalation trigger the rule anticipated.
- No trust was absorbed from the plugin's README or documentation —
  the findings below come from the measurement alone.

## What ran where

- Plugin: `google_mlkit_face_detection 0.15.1` (exact pin).
- Instrument: the throwaway integration probe (now deleted, preserved
  at `face-gate/probe/face_gate_probe_test.dart`) — **no upload
  path**: no HTTP import, nothing from `lib/egress/`, results stayed
  on-device until pulled/copied.
- Device: emulator `organizer36` (android-36, `google_apis;x86_64`,
  KVM), AGENTS.md recipe — the **post-strip build** (see the seal
  record below), so the measurement is of what 5.2 would ship.
- The probe parsed its detector configuration and floors out of
  `face-gate/BAR.md`; the scored run started only after the bar's
  dated confirmation was read (`barConfirmedOn: 2026-09-05`).
- Scored run: started 2026-09-05T18:31:05Z, 16 photos, 0 errors,
  every row recorded — `results/runs/1.json` (the console copy; the
  on-device copy dies with the test runner's end-of-run uninstall).

## Pinned detector configuration (from `face-gate/BAR.md`)

**Run-1-era configuration** — the values the scored run 1 parsed
(`minFaceSize: 0.05`). The interim/live value since the deferral
close-out is **`minFaceSize: 0.0`**, per the final BAR amendment (the
rule of record: face-only at 0.0); the table below is kept as run 1's
record, not the shipped config.

| Option | Value |
| --- | --- |
| performanceMode | `accurate` |
| minFaceSize | `0.05` |
| enableClassification | false |
| enableContours | false |
| enableLandmarks | false |
| enableTracking | false |

Rationale (bar): `accurate` and a small `minFaceSize` widen the net —
the `distance` hard case is a small head; the FPs this admits are
accepted (FR-25's reframe offer is the specified cost).

## Corpus composition (builder-supplied, 2026-09-05)

16 photos, machine-local under `face-gate/corpus/photos/` (gitignored,
verified invisible to git); ground truth committed in
`face-gate/corpus/manifest.json` under pseudonymous ids `p01…p16`:

- 12 person photos — exactly 2 per hard-case category: `partial`
  (p01–p02), `profile` (p03–p04), `distance` (p05–p06), `low-light`
  (p07–p08), `mirror` (p09–p10), `print-on-wall` (p11–p12).
- 4 no-person photos with face-like content (p13–p16): children's
  drawings, masks on a wall, dolls, a cartoon on a TV screen.

The floor (≥ 2 per category, ≥ 3 no-person) was met; the probe
validated it before scoring.

## FN/FP table — the measurement

| Category | Photo | Verdict | Faces | Elapsed |
| --- | --- | --- | --- | --- |
| partial | p01 `parcia-1.jpg` | **false-negative** | 0 | 1255 ms |
| partial | p02 `parcial-2.jpg` | **false-negative** | 0 | 455 ms |
| profile | p03 `perfil-1.jpg` | **false-negative** | 0 | 484 ms |
| profile | p04 `perfil-2.jpg` | **false-negative** | 0 | 475 ms |
| distance | p05 `distancia-1.jpg` | **false-negative** | 0 | 465 ms |
| distance | p06 `distancia-2.jpg` | gate-pass | 1 | 484 ms |
| low-light | p07 `luz-1.jpg` | gate-pass | 1 | 460 ms |
| low-light | p08 `luz-2.jpg` | gate-pass | 1 | 473 ms |
| mirror | p09 `esperjo-1.jpg` | gate-pass | 1 | 454 ms |
| mirror | p10 `espejo-2.jpg` | gate-pass | 1 | 457 ms |
| print-on-wall | p11 `impresa-1.jpg` | gate-pass | 4 | 459 ms |
| print-on-wall | p12 `impresa-2.jpg` | **false-negative** | 0 | 447 ms |
| no-person | p13 `dibujos-infantiles.jpg` | clean-pass | 0 | 464 ms |
| no-person | p14 `mascaras-en-pared.jpg` | clean-pass | 0 | 458 ms |
| no-person | p15 `munecas.jpg` | false-positive | 10 | 506 ms |
| no-person | p16 `tv-dibujo.jpg` | false-positive | 1 | 522 ms |

Per-category tally: **partial 0/2 detected, profile 0/2, distance 1/2,
low-light 2/2, mirror 2/2, print-on-wall 1/2.** Summary: 16 photos, 12
scored persons, 6 gate-passes, **6 false negatives**, 2 false
positives, 2 clean passes, 0 errors.

Reading the two limbs against the bar:

- **False negatives: 6 — the bar FAILS.** A frame containing a person
  passed the detector with zero faces six times in twelve. These are
  genuine misses, not instrument or strip artifacts: the same run
  decoded and detected faces on the other six person photos and both
  FPs (0 error rows), so the pipeline — decode, model load, detect —
  worked throughout.
- **False positives: 2 — accepted and recorded** (p15 dolls, 10
  faces; p16 TV cartoon, 1 face). FR-25's reframe offer is the
  specified cost; nothing to decide.

## ABI evidence (verified, not changed)

`android/app/build.gradle.kts:30-35` `abiFilters arm64-v8a, x86_64` —
the built APK's native libs, `unzip -l` of
`build/app/outputs/flutter-apk/app-debug.apk`:

```
lib/arm64-v8a/libVkLayer_khronos_validation.so   (debug validation layer)
lib/arm64-v8a/libdartjni.so
lib/arm64-v8a/libface_detector_v2_jni.so
lib/arm64-v8a/libflutter.so
lib/arm64-v8a/libsqlite3.so
lib/x86_64/libdartjni.so
lib/x86_64/libface_detector_v2_jni.so
lib/x86_64/libflutter.so
lib/x86_64/libsqlite3.so
```

Only `arm64-v8a/` and `x86_64/` paths exist — no 32-bit lib ships. The
ML Kit `face-detection` AAR itself packs `armeabi-v7a` and `x86`
`libface_detector_v2_jni.so`; the filter drops them (the spine's
16 KB-alignment / NFR12 precondition, verified working).

## Bundled vs unbundled (verified: **bundled — in the APK**)

The naive graph reading trips the story's Ask-First, so the evidence
is spelled out:

- The plugin's `android/build.gradle` pins
  `com.google.mlkit:face-detection:16.1.7` (the *bundled* coordinate).
- That artifact's POM **compile-depends on**
  `com.google.android.gms:play-services-mlkit-face-detection:17.1.0` —
  so the resolved graph (frozen in seal 2's allowlist) contains a
  play-services coordinate even though nothing is Play-Services-served.
- The model physically ships inside `face-detection-16.1.7.aar`:
  `assets/models_bundled/fssd_25_8bit_gray_v2.tflite`,
  `fssd_25_8bit_v2.tflite`, `fssd_medium_8bit_gray_v5.tflite`,
  `fssd_medium_8bit_v2.tflite`, plus
  `jni/<abi>/libface_detector_v2_jni.so` — and those four `.tflite`
  files and the detector lib are **in the built APK**
  (`assets/models_bundled/`, `lib/{arm64-v8a,x86_64}/`).
- The merged manifest carries no `com.google.mlkit.vision.DEPENDENCIES`
  metadata — the opt-in that would request a Play-Services model
  download is absent.

Ruling on the design note's transfer argument: the detection model is
a property of the app's own binaries, so the emulator measurement
transfers; the Ask-First "unbundled" condition is **not** tripped.

## AD-7 seal record (builder ruling 2026-09-05, option a)

**Seal 2 (resolved Gradle graph): re-frozen deliberately** on
2026-09-05, `dart run tool/check_gradle_dependencies.dart --re-freeze`
— counting basis: **+28 entries per runtime configuration** (debug,
release and profile identical; 84 drift findings across the three at
freeze time), which is **26 unique non-project Maven coordinates plus
the two plugin project nodes** (`:google_mlkit_commons`,
`:google_mlkit_face_detection`). Composition: the mlkit face closure
(`com.google.mlkit:{face-detection,common,vision-common,
vision-interfaces}`, the play-services coordinate above,
`play-services-{base,basement,tasks}`, datatransport
`transport-{api,backend-cct,runtime}`, firebase
`{-annotations,-components,-encoders,-encoders-json}`, guava, odml
`image`) and androidx additions (appcompat + its resource/vectordrawable
chain, exifinterface bump). A later re-freeze the same day removed the
instrumentation closure again (review finding: the `integration_test`
dev-dependency's junit/hamcrest/androidx.test entries left the debug
and profile graphs once nothing living used it). The check is green
against the final literal.

**Seal 3 (merged manifest): surgery per the ruling.** The network-facing
ML Kit entries are **stripped by merger rule** (`tools:node="remove"`)
in `android/app/src/main/AndroidManifest.xml`:

- permission `android.permission.ACCESS_NETWORK_STATE`
- activity `com.google.android.gms.common.api.GoogleApiActivity`
- service `…datatransport.runtime.backends.TransportBackendDiscovery`
- service `…jobscheduling.JobInfoSchedulerService`
- receiver `…jobscheduling.AlarmManagerSchedulerBroadcastReceiver`
- metadata `backend:…cct.CctBackendFactory`
- metadata `androidx.emoji2.text.EmojiCompatInitializer` (disposition
  below)

The **minimal ML Kit init set** is enumerated, with justification
comments, in `tool/check_android_manifest.dart`'s baseline (and its
test fixtures per the check's conventions): provider
`com.google.mlkit.common.internal.MlKitInitProvider`, service
`…MlKitComponentDiscoveryService`, the three firebase-components
registrar metadata entries, and metadata `com.google.android.gms.version`.

**Emoji2 disposition (investigated, not silent):** the
`EmojiCompatInitializer` finding appears in **all three variants**
(debug/release/profile each), and `androidx.appcompat` — which
declares it — is a **new entry in this story's re-frozen graph**,
arriving via `com.google.mlkit:common` (the pre-ML Kit graph held no
appcompat; the 4-4-era baseline never enumerated emoji2 and `make
check` was green). It is therefore ML Kit-transitive, not pre-existing
Flutter-embedding noise, and per the ruling's decision rule it is
**stripped**, not baselined.

**Post-strip re-verification (required by the ruling):** the
stripped build was rebuilt, reinstalled on emulator organizer36 and
launched — process starts, MainActivity holds focus, no FATAL in
logcat — and the scored run itself ran on the stripped APK: 6
gate-passes and 2 false positives prove bundled detection initializes
and detects with the network-facing entries gone. `make check` is
green across all three seals.

## Bar confirmation

`face-gate/BAR.md` → Builder confirmation, as confirmed in session:

> Confirmed: 2026-09-05 — Sergio (in-session: "confirmo")

The scored run read this marker before any image was processed
(`barConfirmedOn` in the run file).

## Instrument record and hashes (first close-out; superseded in part by the final close-out below)

- The probe ran once over the corpus (run 1, above). One aborted
  attempt preceded it: killed during the manifest **wait window**
  (before any image was processed) to fix a corpus-path bug —
  manifest/photos were polled at `facegate/` instead of
  `facegate/corpus/`. No image was ever scored in that attempt; run 1
  is the first and only scored run, on the fixed instrument.
- Deleted after evidence capture; preserved verbatim:
  - `face-gate/probe/face_gate_probe_test.dart` — the instrument,
    sha256
    `5ddad6358175f08288337e07a5dd91d83b6e1a7bc60b3d492da8a63dcdc66cd6`
    at deletion (byte-identical to the file that ran; the re-run story
    needs only the pubspec deps, which stay).
  - `face-gate/probe/face_gate_probe_test_test.dart` — its host-side
    unit tests (16 at this point; refusal limbs, parsers, floor
    enforcement), with the one relative import rewritten to the
    same-directory preserved copy — the sole, declared deviation from
    verbatim (working-tree sha256 before deletion:
    `0365c1b1701221c1c26a571e9f25d9519654d5d0e98cd853ecc08edf9f35426a`;
    the preserved copy with the import fix hashes
    `cf961ebc605a071efef690236e4de4e7cf2ba9399ef5ee8b59ea13a98e2181f5`,
    re-recorded in the final close-out below).
- Hash-level add/delete evidence (3-1's pattern, adapted): this story
  lands as a single commit, so git never holds the instrument — the
  sha256s above are the add-time and delete-time identity (the
  working-tree files are content-identical before deletion and after
  preservation). Commit-level hashes, once landed: add `〈story
  commit〉` (adds the evidence pack; the instrument exists only as the
  preserved copy), delete — same commit (the tree carries no
  `integration_test/`).

## Operator recipe for a re-run

Scoped storage hides shell-created dirs from the app, and each test
run ends by uninstalling the app (wiping its external tree) — the
probe creates its own dirs and waits for the push mid-run:

```
# emulator per AGENTS.md; then:
devbox run -- make build
flutter test integration_test/face_gate_probe_test.dart -d emulator-5554
# when the probe prints "waiting … for BAR.md" (it polls ≤ 15 min):
adb push face-gate/BAR.md /sdcard/Android/data/dev.dorogoy.organizer/files/facegate/
adb push face-gate/corpus/. /sdcard/Android/data/dev.dorogoy.organizer/files/facegate/corpus/
# the run JSON prints between "----- face-gate run json begin/end -----"
# markers in the console — capture it there into face-gate/results/runs/<n>.json
# (the runner uninstalls the app at run end, wiping the on-device copy).
# NOTE: restore first — see "Restore recipe (which copy, which name)"
# in the close-out section: v1 restores from
# face-gate/probe/face_gate_probe_test.dart, v2 from the _v2_ copy
# renamed back; the two versions collide on filenames and cannot be
# restored simultaneously. The restore re-adds the SDK dependencies
# the copy needs and drops its analysis_options exclusion.
```

Note: `adb root` is **not** needed for the push and actively breaks it
(root-owned files are invisible to the app's FUSE view) — plain shell
push into the probe-created dirs works.

## Ruling — ESCALATION (Sergio's decision, 5.2 stays gated)

The bar's FN target is zero; the measurement found **6**. Both remedy
options, as the bar and the spec record them, stand for decision:

1. **AD-11 platform-channel promotion** — our own Kotlin channel over
   the same bundled ML Kit native stack (or an alternative on-device
   detector), where the refusal guarantee becomes ours to configure
   and verify per hard case.
2. **Tighter detection configuration** — revisiting the pinned
   `FaceDetectorOptions` (and/or preprocessing) against the measured
   misses, then re-scoring the corpus under a dated bar amendment.

Facts the decision weighs, from the run alone (no README trust, no
tuning written): every miss is a zero-face row on a decoded image
(no errors); `partial` and `profile` missed both photos each,
`distance` and `print-on-wall` one of two; `low-light` and `mirror`
passed clean; the no-person limb produced 2 FPs (accepted by the bar).
**No remedy was chosen or applied by this story.**

**Outcome of this escalation (2026-09-05, in session — Sergio):**
remedy **outside the two recorded options** — widen the gate's target
to persons: **face detection ∨ pose detection ⇒ refuse**, with the
config lever (`minFaceSize` 0.05 → 0.0) subsumed into the same re-run.
Recorded as the dated amendment in `face-gate/BAR.md` → Amendments
(builder-confirmed in session the same day). The cycle that followed
is the next section.

## Amendment cycle — run 2 attempt (2026-09-05, evening; second escalation)

Executed in bar-before-run order:

- **Bar first**: `face-gate/BAR.md` amended (dated entry; rule text and
  both machine blocks updated — face `minFaceSize: 0.0`; pose
  `model: accurate`, `mode: single`) before any re-run. The original
  dated confirmation line still stands; the amendment records its own
  in-session confirmation.
- **Dependency**: `google_mlkit_pose_detection` **0.16.1** added
  exact-pinned — verified as current latest on pub.dev on 2026-09-05
  (published 2026-08-17 by the flutter-ml community family, the face
  plugin's publisher; `dart pub` metadata fetched from
  `pub.dev/api/packages/google_mlkit_pose_detection`). The plugin
  embeds both Gradle artifacts
  (`com.google.mlkit:pose-detection:18.0.0-beta5` and
  `pose-detection-accurate:18.0.0-beta5`) — the **accurate** model is
  what the bar pins (miss-cost asymmetry). The pose models ship in the
  APK (`assets/mlkit_pose/pose_landmark_detector_{full,lite}_f16_inf.tflite`
  + mediapipe graphs; `libxeno_native.so` in both shipped ABIs) —
  bundled, like the face model.
- **Seal 2**: allowlist re-frozen deliberately a second time — pose
  closure additions per configuration: `com.google.mlkit:
  {pose-detection,pose-detection-accurate,pose-detection-common,
  acceleration,mediapipe-internal}`, `androidx.room:{room-common,
  room-runtime}`, `androidx.sqlite:{sqlite,sqlite-framework}`,
  `androidx.work:{work-runtime,work-runtime-ktx,work-multiprocess}`,
  `com.squareup.okhttp3:okhttp` + `com.squareup.okio:okio` (inside
  `mediapipe-internal` — native-internal transport, never reachable
  from Dart; recorded here because a network library in the runtime
  graph deserves its own line), `:google_mlkit_pose_detection` project
  node, and a `vision-interfaces` version bump. Check green.
- **Seal 3 (ruling-1 policy applied to the new entries)**: the pose
  closure merged 19 new declarations × 3 variants. Baselined with
  justification (+ fixtures/tests): the pose registrar metadata
  `com.google.firebase.components:…pose.internal.PoseRegistrar`
  (same init family as the face registrars). Stripped by merger rule:
  `MlKitRemoteWorkerService` (mlkit acceleration), the androidx.work
  services/receivers (8 components), `MultiInstanceInvalidationService`
  (room), the `WorkManagerInitializer` startup metadata, and the
  FOREGROUND_SERVICE / RECEIVE_BOOT_COMPLETED / WAKE_LOCK permissions
  that exist only to serve that machinery. Check green against the
  amended baseline.
- **Probe v2**: resurrected from `face-gate/probe/`, extended to run
  both detectors per image (rows carry `faces` and `poses`; verdict per
  the amended rule via an extracted, unit-tested `verdictFor`;
  per-detector retry-once; summary adds face-only/pose-only/both pass
  splits and `rescuedByPose`). Unit tests grown to 20. Analyzer-clean,
  formatted. One pre-run plumbing fix: the corpus-path bug's v1 fix
  carried over; a stale-FUSE uid mapping after uninstall/reinstall
  caused one clean abort (no image scored) until the device tree was
  cleaned — recorded, no measurement affected.

**The run-2 attempt on the policy build was voided by infrastructure**:
every row errored on the pose limb
(`PlatformException(PoseDetectorError,
MlKitException: Internal error has occurred when executing ML Kit
tasks)`), 16/16 error rows, nothing scored — the bar's error limb
declares and excludes them, and a run voided by infrastructure is
re-run whole, never tallied. **No `results/runs/2.json` exists.**

**Diagnosis (narrowing only — no remedy applied):**

- E1 — policy build (all person-gate strips in): pose errors on every
  image. Logcat at the failure: ML Kit's RemoteConfig resolves
  `vision_pose_detection_enable_acceleration = true` and
  `…_gpu = true` for the pose pipeline.
- E2 — same build with the pose-era strips lifted (face-era strips
  retained): **pose works** — 0 errors, poses detected across the
  corpus. The measurement from this build is below.
- E3 — policy build with **only** `MlKitRemoteWorkerService` restored:
  **pose still errors on every image**. The acceleration service alone
  is not the culprit; more of the work/permission set is involved.

**Diagnostic measurement (E2 build, lifted pose-era strips — a
non-policy build, so it is recorded as a diagnostic, not run 2;
`results/diagnostics/lifted-manifest-diagnostic.json`):**

| Category | Photo | Faces | Poses | Verdict |
| --- | --- | --- | --- | --- |
| partial | p01 `parcia-1.jpg` | 0 | 0 | **false-negative** |
| partial | p02 `parcial-2.jpg` | 0 | 0 | **false-negative** |
| profile | p03 `perfil-1.jpg` | 0 | 1 | gate-pass (rescued by pose) |
| profile | p04 `perfil-2.jpg` | 1 | 1 | gate-pass |
| distance | p05 `distancia-1.jpg` | 0 | 0 | **false-negative** |
| distance | p06 `distancia-2.jpg` | 1 | 0 | gate-pass |
| low-light | p07 `luz-1.jpg` | 1 | 1 | gate-pass |
| low-light | p08 `luz-2.jpg` | 1 | 1 | gate-pass |
| mirror | p09 `esperjo-1.jpg` | 1 | 1 | gate-pass |
| mirror | p10 `espejo-2.jpg` | 1 | 1 | gate-pass |
| print-on-wall | p11 `impresa-1.jpg` | 4 | 1 | gate-pass |
| print-on-wall | p12 `impresa-2.jpg` | 1 | 1 | gate-pass |
| no-person | p13 `dibujos-infantiles.jpg` | 0 | 0 | clean-pass |
| no-person | p14 `mascaras-en-pared.jpg` | 0 | 0 | clean-pass |
| no-person | p15 `munecas.jpg` | 12 | 1 | false-positive (accepted) |
| no-person | p16 `tv-dibujo.jpg` | 2 | 1 | false-positive (accepted) |

Amended-gate tally on the diagnostic build: **9 gate-passes, 3 FN
(p01, p02 `partial`; p05 `distance`), 2 accepted FPs, 0 errors.**
`rescuedByPose` = 1 (p03); `minFaceSize: 0.0` moved p04 and p12 from
run 1's FN column into face-detected passes.

**Second escalation — both questions are Sergio's (STOP; no remedy
chosen or applied):**

1. **Seal policy for the pose closure.** The ruling-1 surgery pattern
   strips the work/acceleration machinery — and that breaks pose
   (E1/E3). Options he weighs: restore the pose-era strip set into the
   baseline (E2's build, justified like the init set), or some subset
   (E3 shows the acceleration worker alone is insufficient), or
   another disabling mechanism — his call; the policy tree stays
   stripped pending it, and `make check` is green in that state.
2. **The 3 residual FNs.** The amended gate still misses both `partial`
   photos and one `distance` photo on the diagnostic build. Per the
   instruction: no further remedy chosen or applied — the table above
   is the decision basis.

## Instrument status after the amendment cycle

- Probe **v2 is alive** in `integration_test/` (with its 20 unit tests
  in `test/`) awaiting the next ruling and the policy-build re-run;
  not deleted, so no close-out hashes this cycle. Working-tree sha256
  at the second escalation:
  `integration_test/face_gate_probe_test.dart` =
  `ca035f44a9a8f8fa4e84ecdcc49e1060f3f6953f894bcd72fcb201b3f45b2798`,
  `test/face_gate_probe_test.dart` =
  `2aae07e70befffd246cf83f2e2712e7cb910842643b46bab8d6c9a824ab5ef91`.

## Final ruling — DEFERRAL (Sergio, 2026-09-05, in session)

The gate-composition effort is **deferred until there is more data**.
Rationale as ruled: the cost spiral outweighs the benefit for now —
nothing uploads until story 5.5 anyway (AD-8's compile-time
`ScanConsent` precondition orders the egress after the camera chain),
and 5.2 usage will produce better data (real scan frames, real
refusal rates) than the 16-photo proxy.

**Interim production gate: face-only** (`google_mlkit_face_detection
0.15.1`, `performanceMode: accurate`, `minFaceSize: 0.0`), exactly the
final tree state this report closes on.

**Risk acceptance (recorded in Sergio's name, 2026-09-05):** the
interim face-only gate missed **6 of 12** corpus hard cases at the
run-1 configuration (`partial` 2/2, `profile` 2/2, `distance` 1/2,
`print-on-wall` 1/2) and **4 of 12** at the interim `minFaceSize: 0.0`
(`partial` 2/2 — p01, p02; `profile` 1/2 — p03; `distance` 1/2 —
p05; reproduced on the final tree by the final-state smoke,
`results/diagnostics/final-tree-smoke.json`). **What the config lever
already rescued:** the `print-on-wall` misses (p11, p12) and one
`profile` (p04) pass on the face limb alone at `0.0` — delivered by
the interim gate itself. **What awaits the deferred composition
only:** `partial` (p01, p02), one `profile` (p03) and one `distance`
(p05) — per the banked diagnostic, p03 is pose-rescued, p01/p02/p05
were missed by both detectors. Accepted against: no upload path
exists before 5.5 (AD-8), and the reopen is ordered before the first
payload ships. **At-rest exposure, named:** between 5.2 and 5.5, a
person-containing frame the interim gate misses lands in story 5.4's
on-device scan cache and stays at rest there until its terminal-path
unlink (plan, face refusal, declined consent, provider failure,
abandonment — plus the open-time sweep). That exposure is local-only
and never uploaded (AD-8's compile-time `ScanConsent` precondition),
but the acceptance record names it: the interim gate's misses are
frames at rest on device, not merely unfired refusals.

**Banked data for the reopen** (kept verbatim, evidence pack):

- Run 1: `results/runs/1.json` (face-only @ 0.05, 6 FN / 12).
- Diagnostic: `results/diagnostics/lifted-manifest-diagnostic.json`
  (face∨pose @ 0.0/accurate on the lifted build, 3 FN / 12,
  `rescuedByPose` = 1).
- Final-tree smoke: `results/diagnostics/final-tree-smoke.json`
  (face-only @ 0.0 on the final tree, 4 FN / 12 — the headline
  interim-risk figure, reproducible from the evidence pack).
- Probe v1 (face-only instrument) and v2 (person-gate instrument)
  preserved under `face-gate/probe/` — hashes below.
- The object-detection rung of the composition was **never measured**.
- **The input-path seam:** the corpus was scored via
  `InputImage.fromFilePath` — stills decoded by the plugin's file
  path, EXIF rotation applied inside that path. Story 5.2 feeds
  camera-captured **bytes** with manually applied rotation through a
  different `InputImage` constructor (`InputImage.fromBytes` +
  metadata). The reopen must measure on 5.2's real frames and real
  input path — which is already the stated plan; recorded here so
  the seam itself is a named input, not an accident of the proxy.

**The cost table that motivated the deferral** (measured/observed
2026-09-05): ~**22 MB** of pose on-device footprint (pose-detection +
pose-detection-accurate artifacts; the accurate model alone is
6.4 MB of the APK's `assets/mlkit_pose/`); ~**590 ms** median
per-image face+pose latency on the emulator (the face limb alone
runs ~450–560 ms); a **second fragile dependency surface** in the
community-plugin family (the spine's fragile-deps list would grow ×2,
each a contingent AD-11 promotion candidate); and the measured
fragility itself — the pose closure's merged-manifest machinery could
not be stripped without breaking it (E1/E3), so shipping it meant
widening AD-7's baselines for background machinery the gate does not
functionally need.

**Reopen condition: before story 5.5 ships the first scan payload**
(AD-8 ordering). Inputs: real scan frames and refusal rates from 5.2
usage, plus the banked diagnostic above. The decision to reopen is
the builder's.

## Final-state verification and instrument record (close-out)

- **Final-state smoke (2026-09-05, emulator organizer36, the final
  face-only tree):** the preserved face-only flow (probe v1) ran the
  whole corpus end-to-end — build, install, external-files IO, BAR
  parse (confirmed marker, `minFaceSize: 0.0`), detection, summary.
  Person photos detected: **8 gate-passes / 12** (p04, p06–p12), 0
  errors, 2 accepted FPs, 2 clean passes — the banked diagnostic's
  face-limb numbers reproduce exactly on the final tree. The probe's
  non-zero exit (4 FN) is the honest interim-gate state, not a smoke
  failure. **The machine JSON is committed as
  `results/diagnostics/final-tree-smoke.json`** (run again after the
  review patches, labeled smoke — not a scored run — so the headline
  interim-risk figure 4 FN / 12 is reproducible from the evidence
  pack; the run predates the same review's inert
  `integration_test`-dev-dep removal by ordering necessity, which
  changes no detection code).
- **Instruments out, preserved — sha256 identities (as-ran → preserved
  now; the arrowed changes are the two declared deviations from
  verbatim: each unit-test copy's relative-import rewrite, and the
  post-review header corrections below):**
  - v1 (face-only; run 1's instrument, also both final smokes'):
    `face-gate/probe/face_gate_probe_test.dart` =
    `5ddad6358175f08288337e07a5dd91d83b6e1a7bc60b3d492da8a63dcdc66cd6`
    (verbatim — header was already accurate); unit tests
    `face-gate/probe/face_gate_probe_test_test.dart`: as-ran (working
    tree, pre-preservation)
    `0365c1b1701221c1c26a571e9f25d9519654d5d0e98cd853ecc08edf9f35426a`
    → preserved
    `bba281640a7c1f3b40ea61a4317708c2747fbedfe1fa71360b7bb8565048de59`.
  - v2 (person-gate; the voided run-2 attempt's instrument): as-ran
    (working tree at the second escalation)
    `ca035f44a9a8f8fa4e84ecdcc49e1060f3f6953f894bcd72fcb201b3f45b2798`
    → preserved
    `3a4c5caab4c7d95e6eb28f98e0d29bf40973f5cebf84317715a7dc5d352eb09f`;
    unit tests as-ran
    `2aae07e70befffd246cf83f2e2712e7cb910842643b46bab8d6c9a824ab5ef91`
    → preserved
    `f83782e17cd17b1a4384a2aeda1fee818cbc2d6e0e77014e5c179b3d20520ded`.
  - Post-review correction (2026-09-05): the preserved files' header
    comments were fixed to name their own filenames and preservation
    (v2's pointed at v1's filename; the unit-test headers still claimed
    deletion with the instrument); the hashes above are the corrected
    files'.
- **Deletion record:** `integration_test/` (held v1, staged for the
  smokes after v2's preservation) and `test/face_gate_probe_test.dart`
  deleted after each run; the tree carries no `integration_test/` —
  git never held either instrument (single-commit landing; the sha256s
  above are the add/delete identity, 3-1's pattern adapted).
- **Analyzer status of the preserved copies:** both instruments import
  SDK dependencies the tree no longer carries (v2: the pose plugin;
  both: the `integration_test` binding, removed by the review's graph
  cleanup) and are excluded from analysis via one dated, commented
  entry in `analysis_options.yaml` covering all four files. Dropping
  that exclusion (and re-adding what it names) is the restore
  recipe's first step.
- **Restore recipe (which copy, which name — the versions collide on
  filenames and cannot be restored simultaneously):**
  - v1: `face-gate/probe/face_gate_probe_test.dart` →
    `integration_test/face_gate_probe_test.dart`, and
    `face-gate/probe/face_gate_probe_test_test.dart` →
    `test/face_gate_probe_test.dart` (import re-extended to
    `'../integration_test/face_gate_probe_test.dart'`); needs only the
    `integration_test` dev-dependency back.
  - v2: `face-gate/probe/face_gate_probe_v2_test.dart` →
    `integration_test/face_gate_probe_test.dart` (the `_v2_` suffix is
    the evidence-pack disambiguator; the runtime name is the shared
    one), and `face-gate/probe/face_gate_probe_v2_test_test.dart` →
    `test/face_gate_probe_test.dart`; needs the pose plugin
    (`google_mlkit_pose_detection`) and the `integration_test`
    dev-dependency back, plus the BAR pose-detector-config block to be
    un-superseded by a new dated amendment.
  - Either way: drop the corresponding `analysis_options.yaml`
    exclusions, `make deps`, then the operator recipe below.
- **Corpus filename note:** two builder filenames carry intentional
  typos kept so the committed manifest matches the machine-local
  files — `parcia-1.jpg` (parcial) and `esperjo-1.jpg` (espejo).

## Known probe defects to fix on restore

The preserved copies stay verbatim (sha256 identity above), so these
are recorded, not fixed — the edge-case review found them; fix all
nine before trusting a restored instrument's next scored run:

1. An all-error run with zero scored persons reads as `barPassed:
   true` — add a void guard (errors > 0 with an empty FN denominator
   is an infrastructure failure, not a pass; the voided run-2 attempt
   printed "bar passed" exactly this way).
2. `minFaceSize: NaN` passes the range checks (`NaN < 0` and
   `NaN > 1` are both false) — reject non-finite values explicitly.
3. Implausible dates are accepted as confirmations (Feb 30 passes the
   month-length table as written for non-leap February; year `0000`
   passes) — tighten the plausibility bounds.
4. Duplicate bar keys silently last-win in `parseBarBlock` — refuse
   duplicates inside a machine block.
5. The `Confirmed:` line is matched anywhere in the file, not only in
   the Builder-confirmation section — scope the match.
6. Duplicate manifest filenames under distinct ids satisfy the floors
   (two ids pointing at one photo double-count a category) — require
   unique filenames.
7. Manifest filenames containing `/` or `..` escape the photos dir —
   validate as a bare basename.
8. No push-stability wait on the BAR/corpus reads — a file observed
   mid-`adb push` parses partially; wait for size stability or a
   sentinel before reading.
9. No per-photo checkpointing of the run JSON — a timeout or crash
   after N photos loses the whole run; flush incrementally.

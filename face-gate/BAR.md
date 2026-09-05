# Face-gate bar — on-device person gate (story 5.1)

**Rule of record (deferral close-out, 2026-09-05): the interim
production gate is face-only at `minFaceSize: 0.0`** — the detector
config block below carries those live values. The face ∨ pose rule
text and the pose-detector-config block in the sections below are
**historical (run-2 era) and superseded** — kept as the record of the
deferred composition, not the shipped rule. The spine's Stack table
pins face detection only (`google_mlkit_face_detection 0.15.1`; no
pose row exists — the pose dependency was removed with the deferral),
and story 5.2 ships the face-only gate this bar closes on. The
interim rule **fails the FN=0 target**: 4 FN / 12 person photos at
the final tree (2026-09-05 final-state smoke,
`face-gate/results/diagnostics/final-tree-smoke.json`) — accepted by
the builder's deferral ruling and reopened before story 5.5 ships the
first scan payload.

Written before the measurement exists. One bar, measured on-device
through the same plugin story 5.2 will ship — the probe imports
nothing from `lib/egress/` and has no upload path. The probe refuses
to score while this file carries no dated confirmation in its Builder
confirmation section. (The run-2-era text between here and the
Amendments section describes the superseded person gate; the
Amendments entries are the authoritative history.)

## The asymmetric bar

1. **False negatives: target zero.** A false negative is a corpus photo
   of class `person` on which the gate does not refuse — since the
   2026-09-05 amendment below, face detection finding zero faces AND
   pose detection finding zero poses — the frame 5.2 would let
   through. **Any FN > 0 fails the bar.** Bar failure is the
   escalation path, not a crash and never silent tuning: the FN is
   recorded as a finding with the recorded remedy options and the
   ruling is the builder's.
2. **False positives: accepted and recorded.** A false positive is a
   corpus photo of class `no-person` on which the gate refuses — face
   detection reporting at least one face OR pose detection reporting at
   least one pose. The cost is one reframe offer (FR-25) — the
   specified behaviour. FPs are counted and reported, never tuned away
   mid-story.
3. **The gate rule (amended 2026-09-05): a frame is refused iff
   face-detection finds ≥ 1 face OR pose-detection finds ≥ 1 pose.**
   Verdicts are defined against the manifest's ground truth: FN =
   `person` photo with zero faces and zero poses; FP = `no-person`
   photo with ≥ 1 face or ≥ 1 pose; `person` refused is a gate-pass
   (correct refusal); `no-person` not refused is a clean pass.
4. **Errors are declared, never dropped.** A detection error on one
   image (either detector) is retried once; still failing, the row is
   recorded `error` and excluded from the FN/FP denominators, reported
   as such in `report.md`. The builder replaces the file or the row
   stays declared-error. A corpus that cannot be scored at all (missing
   bar confirmation, floor unmet, missing photos) makes the probe
   refuse before any image is processed.

## Corpus floor

- At least **2 photos per hard-case category** across all six: `partial`,
  `profile`, `distance`, `low-light`, `mirror`, `print-on-wall`. A photo may
  carry several categories; each category must reach the floor on its own.
- At least **3 photos of class `no-person`** containing face-like objects
  (posters, mannequins, masks, faces on packaging, …) — the FP limb needs
  something to bite on.
- Photos are builder-supplied and machine-local forever:
  `face-gate/corpus/photos/` is gitignored; the committed
  `face-gate/corpus/manifest.json` carries pseudonymous ids and ground
  truth (class + categories) only, never image bytes (3-1's declared
  redaction discipline).

## Pinned detector configuration

Exact values the probe runs — parsed from these blocks, not from its own
constants, so the bar and the measurement cannot drift apart. The face
block's `minFaceSize` reads 0.0 since the 2026-09-05 amendment (was
0.05); the pose block is the amendment's second detector.

<!-- detector-config: begin -->
performanceMode: accurate
minFaceSize: 0.0
enableClassification: false
enableContours: false
enableLandmarks: false
enableTracking: false
<!-- detector-config: end -->

<!-- pose-detector-config: begin -->
model: accurate
mode: single
<!-- pose-detector-config: end -->

`accurate` over `fast`, `minFaceSize: 0.0` (the floor: no size
pre-filter — every candidate head counts) and the **accurate** pose
model over the base one all widen the net, per the miss-cost asymmetry:
an FN is the failure that matters, an FP costs one reframe offer. The
pose detector runs in `single` mode — static images, the corpus's and
5.2's shoot-time frame's shape. Landmarks, classification, contours and
tracking are off: pure cost, no count contribution.

<!-- bar-facts: begin -->
minPhotosPerHardCaseCategory: 2
minNoPersonPhotos: 3
<!-- bar-facts: end -->

## Amendments

- **2026-09-05 — the gate's target is widened to persons: face ∨ pose.**
  Run 1 (face-only, `minFaceSize: 0.05`) escalated: **6 false negatives
  out of 12 person photos** (`partial` 0/2, `profile` 0/2, `distance`
  1/2, `print-on-wall` 1/2; `low-light` and `mirror` clean; 0 errors;
  2 FPs accepted) — the bar's FN target of zero failed. The builder
  ruled in session (Sergio, 2026-09-05) on a remedy **outside the two
  then-recorded options** (AD-11 platform-channel promotion; tighter
  detection configuration): widen the gate's composition to persons —
  **face detection ∨ pose detection ⇒ refuse** — with the config lever
  (`minFaceSize` 0.05 → 0.0) subsumed into the same re-run. Recorded
  here as this dated entry; the rule text above and the two pinned
  config blocks carry the amended values the probe parses. The second
  detector is `google_mlkit_pose_detection 0.16.1` (flutter-ml, the
  face plugin's community family; verified latest on pub.dev
  2026-09-05) pinned to its **accurate** model in `single` mode.
  FP semantics unchanged: accepted, recorded, never tuned away.
  Amendment confirmed in session by the builder the same day.
- **2026-09-05 — composition DEFERRED; face-only is the interim gate.**
  The re-run never scored on the policy build: the pose-era seal
  surgery (the strip set this amendment's dependency brought down on
  its work/acceleration machinery) broke pose detection at runtime —
  `MlKitException: Internal error` on every image, 16/16 error rows,
  the attempt **voided by infrastructure** (no `runs/2.json`). A
  diagnostic on a non-policy build (pose-era strips lifted) banked the
  composition's ceiling: **face ∨ pose = 3 FN / 12** (`partial` 0/2,
  `distance` 1/2; `minFaceSize: 0.0` rescuing `profile` and
  `print-on-wall`) — the object-detection rung was never measured. The
  builder ruled in session (Sergio, 2026-09-05): **defer the gate's
  composition** (face ∨ pose ∨ OD vs minimal) — the cost spiral (~22 MB
  pose on-device, added latency, a second fragile surface, contingent
  AD-11 promotion) outweighs the benefit while nothing uploads until
  story 5.5 anyway (AD-8's compile-time `ScanConsent` precondition),
  and 5.2's usage will produce better data (real scan frames, real
  refusal rates) than this 16-photo proxy. **Interim rule: the
  face-only gate at `minFaceSize: 0.0`** (the amended face block
  above stands; the pose block is banked, not live). **Reopen
  condition: before story 5.5 ships the first scan payload**, with
  5.2's real-usage frames plus the banked diagnostic
  (`face-gate/results/diagnostics/`) as inputs. Deferral confirmed in
  session by the builder the same day.

## Builder confirmation (Ask-First — required before the first scored run)

Replace the placeholder below with a real dated line; the probe looks for
`Confirmed: YYYY-MM-DD` and refuses to score without it.

Confirmed: 2026-09-05 — Sergio (in-session: "confirmo")

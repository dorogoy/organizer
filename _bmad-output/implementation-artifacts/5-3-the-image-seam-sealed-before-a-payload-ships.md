---
title: 'Story 5.3: The image seam, sealed before a payload ships'
type: 'bugfix'
created: '2026-09-06'
status: 'done'
review_loop_iteration: 1
baseline_commit: '546c79e30ea68f67ec9b2e252fdbc5e26a8cd902'
context:
  - '{project-root}/_bmad-output/implementation-artifacts/epic-5-context.md'
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** Epic 4 retro F5 verified three dormant defects at the egress image seam, all invisible while Epic 4 sent no images and all live the moment 5.5–5.6 ship the first scan payload: decodable sub-cap WebP/GIF/BMP inputs pass through the cap untouched and get mislabelled `image/jpeg` on the wire (guaranteed 4xx misdiagnosed as provider unreachability); undecodable bytes throw `FormatException`, which `_causeOf` folds into `malformedResponse` — the taxonomy's delivered-but-unusable bucket — though nothing was ever sent; and `egressPixelCeiling` = 16 MP admits ~48–64 MB rasters plus resize/encode buffers that OOM-kill the flow on low-RAM devices.

**Approach:** Make the cap admit exactly JPEG and PNG behind one shared magic sniff (single mime truth for cap and wire; every other input — decodable or not — is one pre-transport malformed-input rejection), give that rejection its own port classification `SlicerFailureCause.malformedInput` folding to the existing `unreachable` surface cause (FR-29's seven strings untouched), and lower the ceiling to 12.5 MP against recorded memory arithmetic — all pinned by committed suites before the first payload ships.

## Boundaries & Constraints

**Always:**
- The declared mime is the true sniffed type on every input that reaches the wire; JPEG/PNG are the only declarable mimes; a type the wire cannot declare rejects as malformed **before transport** (AC1, AD-7 — the chokepoint keeps its three seals, only its image honesty changes).
- Every pre-transport cap rejection — non-JPEG/PNG sniff, undecodable bytes, corrupt body past the header, over-ceiling raster — is one classification: malformed input. `malformedResponse` stays reserved for delivered-but-unusable evidence (non-UTF-8 2xx body, extraction null) and is never reached pre-transport.
- FR-29 stands: `NoSlicerCause` stays exactly seven, one calm surface, zero new strings; the new port cause maps to `unreachable` in the total map — the same recorded fold as `malformedResponse → unreachable`.
- Behavior for JPEG/PNG inputs within the pixel ceiling is byte-identical to today (the camera path — the only production image source, ≤ the 12 MP sensor class — is unaffected); headers above the ruled 12.5 MP ceiling reject as malformed input, the story's one recorded band move (Spec Change Log). The cap still runs inside `compute()` off the UI isolate and still operates inside AD-8's ordering (mint → cap → upload).
- Egress stays sealed: `MalformedImageInput` is declared, thrown and caught inside `lib/egress/`; no import outside the module changes; `tool/check_egress_imports.dart` stays green untouched. Core edits are pure additions (one enum member, one map row, docs).

**Ask First:**
- The ceiling value (12.5 MP — renegotiated from a literal 12 MP by Sergio's ruling 2026-09-06, review round 1; see Spec Change Log) — any further change remains Sergio's call.
- Anything that would add an eighth surface cause or degradation string, or reopen the capture-side `ResolutionPreset.max` decision.

**Never:**
- No upload path becomes reachable: `ScanConsent` stays 5.4's to mint; no scan/camera code from 5.2 is touched; no payload leaves the device from this story.
- The bounded-capture-preset decision stays deferred (`deferred-work.md`, 5-2 review: coupled to the 5.1 composition reopen because it shifts the face gate's input distribution). This story records the coupling; it does not decide the preset.
- No new log kind, l10n string, manifest entry, Gradle dependency or pubspec change. The wire's delivered-body decode failures are not reclassified — they stay `malformedResponse`, honestly.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| In-cap JPEG | ≤ 1536 px long edge, JPEG magic | Pass-through untouched; wire declares `image/jpeg` | N/A |
| In-cap PNG | ≤ 1536 px, PNG magic | Pass-through untouched; wire declares `image/png` | N/A |
| Oversized JPEG/PNG | > 1536 px, ≤ 12.5 MP header | Decode, bake EXIF, resize to 1536, re-encode (PNG→PNG, JPEG→q85) — unchanged | N/A |
| In-cap WebP/GIF/BMP | Decodable, sub-cap, non-declarable magic | Reject before transport, before any decode | `MalformedImageInput` → `malformedInput` → `unreachable` |
| Undecodable bytes | No known magic | Reject pre-decode, zero transport calls | Same |
| Corrupt body | JPEG/PNG magic; corruption the header probe trips, or the oversized path's decode trips. A header that parses in-cap with corruption past it passes through value-identical — 4-2's header-decides design, unchanged and pinned as documented | Probe-tripped corruption rejects pre-transport; in-cap past-header corruption ships as the user's own bytes (the sniffed mime stays true) | `MalformedImageInput` on the rejecting paths |
| Over-ceiling raster | Header claims > 12.5 MP (or a dimension/product the overflow-safe guard refuses) | Reject before pixel allocation | Same |
| Delivered garbage (wire) | 2xx body not UTF-8 / extraction null | `malformedResponse` — unchanged | Delivered-but-unusable; honest |
| Surface fold | `noSlicerCauseFromFailure(malformedInput)` | `NoSlicerCause.unreachable` | Recorded fold; seven strings stand |

</frozen-after-approval>

## Code Map

<!-- Anchors are baseline-relative (546c79e, pre-landing); expect drift in landed files. -->

- `lib/egress/image_cap.dart` -- the whole fix site. `egressImageCap = 1536` (:8), `egressJpegQuality = 85` (:11), `egressPixelCeiling = 16_000_000` (:18, doc :13-17 — decompression-bomb guard, the ceiling to lower). `prepareImageForEgress` (:46-47) runs `_capImage` in `compute()`. Pass-through hole :57-61 (sub-cap bytes returned value-identical — how WebP/GIF/BMP reach the wire). Four bare `FormatException` sites :55, :105, :119, :133 — all become `MalformedImageInput`. Doc :37-45 ("every other decodable format becomes JPEG q85"; "never as a rejection of the user") rewritten to the admit-exactly-two contract.
- `lib/egress/byok_wire.dart` -- `imageMimeTypeOf` :268-280: JPEG magic `FF D8` → `image/jpeg` (:259), PNG magic → `image/png` (:262), **everything else → `image/jpeg`** (:279, the lie). False doc :264-267 ("every scan payload that reaches the wire carries one of the two"). Three payload builders call it: `_geminiBody` :460-466 (inline_data), `_chatBody` :554-564 (data-URI), `_anthropicBody` :593-601 (media_type) — the sniffer must not lie for any of them. Delivered-body `FormatException`s at :299-301, :336, :367-371 stay as-is.
- `lib/egress/byok_slicer.dart` -- `_causeOf` :145-165; the `FormatException` arm :161-163 (currently catches the cap's throws) keeps only wire-delivered evidence; new `MalformedImageInput` arm above it. Classification honesty doc :127-144 (:136-140 is the claim F5 broke; :143-144 "adds no eighth cause" stays true at the surface). Cap failures arrive via `EgressFailed` from `lib/egress/egress_dispatch.dart:58-66` (cap call at :61, scan shapes only).
- `packages/core/lib/ports/slicer_port.dart` -- `SlicerFailureCause` :77-102, seven members, doc :69-76 ("seven-cause taxonomy (FR-29), closed by construction"); gains `malformedInput` with a pre-transport doc. Sealed payload union mirrors here (:32-67) — untouched.
- `packages/core/lib/ports/no_slicer_cause.dart` -- `NoSlicerCause` stays seven (:26-57); total map `noSlicerCauseFromFailure` :74-83 gains the `malformedInput → unreachable` row beside the recorded `malformedResponse → unreachable` fold (:81).
- `test/egress/egress_fixtures.dart` -- `gradientJpeg/rotatedJpeg/gradientPng/gradientGif` (:10-28), `gradient` raster builder (:30-38), probes `decodeOrThrow`/`formatOf` (:40-54). WebP/BMP rejection fixtures land here.
- `test/egress/image_cap_test.dart` -- ceiling pin :10-14 (`== 16_000_000` — update); GIF pass-through pin :129-134 (flips to rejection); undecodable/over-budget `FormatException` expectations :136-147 + `_fakeOverBudgetJpegHeader` :150-167 (claims 5000×4000 = 20 MP — still over 12.5 MP; becomes `MalformedImageInput`).
- `test/egress/egress_dispatch_test.dart` -- 'undecodable scan bytes fail before the transport is touched' :115-130 (0 transport calls, `cause isA<FormatException>` — retype); three-shapes census :153-180 stays green.
- `test/egress/byok_slicer_test.dart` -- MockClient harness (:13, :65-70) over the real `ByokSlicer`; scan-shape mime pins :611-612, :643-648, :702; in-cap PNG keeps `image/png` :707-733 (stays green). Nothing today asserts which `SlicerFailureCause` undecodable scan bytes produce — 5.3 owes that end-to-end pin.
- `packages/core/test/no_slicer_cause_test.dart` -- seven-members census :13-27 (stays 7); total-map rows :29-62 (gain one); map-image census :64-87 (update).
- `tool/check_egress_imports.dart` -- the module seal (:38-57 allowlist, import surface) — green untouched; listed so the implementer does not "fix" it.
- `Makefile:44-60,101-104` -- `make check` (14 tool checks + eval + codegen-check) and `make gate` (test/format/analyze) — the completion gates.
- `_bmad-output/planning-artifacts/epics.md:1911-1933` -- the story's four ACs verbatim; ordering constraint at :1933 (before 5.5–5.6 ship the first payload).
- `lib/plugins/camera/plugin_camera_shell.dart:112-119,150-181` + `lib/plugins/mlkit_face/mlkit_face_gate.dart:39-71` -- read-only context for the arithmetic: `ResolutionPreset.max` capture, `readAsBytes()` wholesale read, ML Kit `fromFilePath` decode with `close()` in `finally` (its native bitmap is released before the cap runs — sequencing the arithmetic relies on).

## Tasks & Acceptance

**Execution:**
- [x] `lib/egress/image_cap.dart` -- add the shared sniff (JPEG/PNG magic, single source of truth), gate the cap on it before any decode: only JPEG/PNG proceed, every other input rejects pre-transport; declare `MalformedImageInput` (simple final-field class, crossable through `compute()`) and replace all four `FormatException` sites; lower `egressPixelCeiling` to `12_500_000` (review-round ruling); make the pixel-budget guard overflow-safe (a per-dimension bound before the product, so crafted uint32 PNG headers cannot wrap the product negative); rewrite the doc with the recorded arithmetic (12.5 MP × 3 ch uint8 ≈ 37.5 MB JPEG worst production case, ×4 ≈ 50 MB alpha worst; resize ≤ 1536×1536 ≈ 2.36 MP ≈ 7.1–9.4 MB; encode buffers bounded; sequenced after the gate's released native decode, raw capture bytes the only co-resident holding) -- the seam becomes honest in one module
- [x] `lib/egress/byok_wire.dart` -- `imageMimeTypeOf` delegates to the shared sniff; unknown/undeclarable magic throws `MalformedImageInput` instead of returning `image/jpeg`; rewrite the false doc :264-267 -- the wire can no longer mislabel, by construction
- [x] `lib/egress/byok_slicer.dart` -- `_causeOf` gains an `on MalformedImageInput` arm (above `FormatException`) mapping to the new cause; rewrite the classification doc :127-144 so the honesty claim covers pre-transport input failures explicitly -- nothing sent is never "delivered-but-unusable"
- [x] `packages/core/lib/ports/slicer_port.dart` -- add `SlicerFailureCause.malformedInput` with a pre-transport doc; update the taxonomy doc (eight port causes; FR-29's seven surface causes unchanged) -- the port vocabulary can say what actually failed
- [x] `packages/core/lib/ports/no_slicer_cause.dart` -- total map row `malformedInput → unreachable` (recorded fold, `malformedResponse` :81 precedent, no-eighth-string ruling cited); docs -- the surface stays seven
- [x] `test/egress/egress_fixtures.dart` -- `gradientWebP`/`gradientBmp` via the `image` encoders, or minimal hand-rolled magic-byte stubs if encoding is unsuitable (rejection happens at the sniff; no decodable body needed) -- the undeclarable inputs exist as fixtures
- [x] `test/egress/image_cap_test.dart` -- GIF pass-through pin flips to rejection; WebP/BMP reject pre-decode; JPEG/PNG pass-through and resize paths unchanged; ceiling pin `12_500_000`; a real 4032×3024 (12 MP-class) fixture survives the cap and resizes (the boundary pin the ruling demanded); undecodable/corrupt/over-budget → `MalformedImageInput`; a real panoramic resize-bound pin replaces the vacuous constants-only arithmetic test -- the cap contract is pinned
- [x] `test/egress/egress_dispatch_test.dart` -- undecodable scan bytes: 0 transport calls, `cause is MalformedImageInput` -- pre-transport stays pre-transport
- [x] `test/egress/byok_slicer_test.dart` -- end-to-end: undecodable **and** in-cap GIF scan bytes → `failure.cause == malformedInput` (never `malformedResponse`), transport 0 calls; in-cap PNG data-URI pin :707-733 stays green; review round adds the BMP leg end-to-end and direct `imageMimeTypeOf` pins (jpeg/png map; GIF/WebP/BMP throw — the wire half can no longer regress silently) -- the taxonomy pin the story owes
- [x] `packages/core/test/no_slicer_cause_test.dart` -- map row added; `NoSlicerCause.values.length == 7` census stays -- the seven strings cannot drift
- [x] Gate -- `make gate` + `make check` green inside devbox

**Acceptance Criteria:**
- Given a decodable sub-cap image whose bytes are not JPEG or PNG (WebP, GIF, BMP), when it passes toward the wire, then no payload is sent — the rejection is a pre-transport malformed-input failure, never a payload mislabelled `image/jpeg`, and `imageMimeTypeOf` and the cap agree on every input (single shared sniff) (AC1, AD-7).
- Given bytes that cannot be decoded, when the cap attempts them, then the resulting `SlicerFailureCause` is `malformedInput` — never `malformedResponse` — and the recorded transport shows zero calls; the delivered-but-unusable bucket keeps meaning "a 2xx arrived and was unusable" (AC2, FR-29, AD-7).
- Given a low-RAM device mid-camera-flow, when the pixel ceiling is consulted, then `egressPixelCeiling` is 12.5 MP with the memory arithmetic recorded in the doc, the 12 MP sensor class (4032×3024) passes, and an over-ceiling header rejects before allocation as malformed input (AC3).
- Given the committed suites, when this story lands, then each fix is pinned (mime truthfulness, taxonomy, ceiling) with the old defective assertions gone, and the story precedes 5.5–5.6 shipping the first scan payload (AC4, ordering constraint).

## Spec Change Log

- **2026-09-06 — review round 1, intent_gap resolved by human ruling: the ceiling is 12,500,000, not a literal 12 MP.** Blind-hunter finding: the canonical 12 MP sensor output (4032×3024 = 12,192,768 px) exceeds 12,000,000, so the ruled-at-approval value rejected the camera path the frozen boundaries promised unaffected. Sergio ruled **12,500,000** (2026-09-06). Amendment: frozen Intent/Matrix/Boundaries now say 12.5 MP; the guard becomes overflow-safe (per-dimension bound before the product — crafted uint32 PNG headers can no longer wrap `probeWidth * probeHeight` negative past the check); the resize-target arithmetic is corrected to ≤ 1536×1536 ≈ 2.36 MP (1536×2048 never occurs — the long edge always lands on the cap); the alpha-format worst case (≈ 72 MB peak, no production sender) is recorded as residual instead of scoped away; the Verification section no longer claims zero visible behavior change (the >12.5 MP rejection band is named); a real 4032×3024 fixture pins that the camera class passes; the vacuous constants-only arithmetic test is replaced by a real panoramic resize-bound pin; the wire's `imageMimeTypeOf` gains direct pins (jpeg/png map, GIF/WebP/BMP throw) so the mislabel cannot regress silently; corrupt-body coverage gains the PNG leg; the BMP leg joins the end-to-end taxonomy pin. KEEP (survived re-derivation verbatim): the shared sniff design, the admit-exactly-two contract, `MalformedImageInput` as one type for all four cap refusals, the `malformedInput` cause and its recorded `→ unreachable` fold, FR-29's untouched seven strings, and the sealed-egress/no-preset-deferral boundaries. Known-bad avoided: a camera path that rejects every 12 MP capture while the spec claims nothing visible changed. Applied as patches in place with full gates re-run — re-derivation from the amended spec converges to the same code.

- **2026-09-06 — review round 2, patch-class findings applied (no loopback).** (1) The frozen Always bullet's "byte-identical" claim is scoped to inputs within the ceiling, naming the >12.5 MP band move it already sat beside — completing Sergio's standing ruling, not changing it. (2) The corrupt-body matrix row and the cap/`_causeOf` docs overclaimed: past-header corruption on a header-parses in-cap body was never detected (4-2's header-decides pass-through, unchanged by 5.3) — the row now states both sides and the behavior is pinned as documented rather than silently implied. (3) The ruled ceiling's bite is now behaviorally discriminable: a real 4096×3072 (12,582,912 px) JPEG rejects — under a reverted 16 MP guard it would decode and resize, so the band cannot silently reopen (verification-gap demonstration). (4) The 12.5–16 MP band previously had no pin that could distinguish the two ceilings. (5) WebP gains its end-to-end slicer leg (AC1 named it first; GIF/OpenAI and BMP/Gemini already had theirs). (6) `egressImageFormatOf` gains direct pins (census exactly {jpeg, png}; empty/short-fragment edges; zero-dimension probe guard). (7) A resize×wire composition pin joins the suites (an oversized scan through the real slicer asserts the declared mime on the re-encoded copy — cap and wire were never joined before). (8) In-cap APNG pass-through pinned as documented; the "first frame" doc is scoped to the decode path. (9) The drifted `epics.md:1988` citation is corrected to :2051 (the re-partition moved the fold ruling), and the `malformedInput → unreachable` fold gains its planning anchor (story 5.3's AC2, epics.md:1925). (10) Verification banks run evidence; the Code Map marks its anchors baseline-relative. KEEP: everything from round 1's KEEP list, plus the round-1 patch set verbatim. Known-bad avoided: a guard-only revert to 16 MP shipping green; docs claiming corruption detection the code never performed.

## Design Notes

- **Reject, don't re-encode, undeclarable types.** The AC's own second clause decides it: "a type the wire cannot declare rejects as malformed before transport". Re-encoding sub-cap WebP→JPEG would also be truthful, but then small WebP rejects nowhere while oversized WebP silently transcodes — size-dependent format policy is incoherent, and rejection is cheaper (magic check, no decode). Production never feeds the cap anything but camera JPEG, so the pass-through hole was only ever a lie waiting for a caller.
- **One exception, one cause.** All four cap failure sites are the same fact — "this input cannot honestly be carried" — whether the sniff failed, the header lies, the body is corrupt, or the raster is over budget. One `MalformedImageInput`, one `_causeOf` arm, one port cause; `FormatException` inside egress goes back to meaning only delivered-body decode trouble, which is what the arm's doc always claimed.
- **The surface fold is precedented, not new.** `malformedResponse → unreachable` is already a recorded fold (`no_slicer_cause.dart:81`); `malformedInput → unreachable` is the same shape. The port taxonomy gets honest; FR-29's seven strings and one calm surface are untouched — the no-eighth-cause ruling holds where it was made (the degradation surface).
- **Arithmetic, corrected and recorded.** The retro's "~64 MB" was the alpha-format worst case: `image` 4.9.2 stores uint8 rasters with 3 channels for JPEG (`image.dart:88-93`, `image_data_uint8.dart:17-20`), so 16 MP JPEG ≈ 48 MB, alpha ≈ 64 MB. At 12.5 MP: 37.5/50 MB raster + ≤ 9.4 MB resize target (≤ 1536×1536 ≈ 2.36 MP — the long edge always lands on 1536, so 1536×2048 never occurs) + bounded encode buffers ≈ 50–63 MB transient peak in the compute isolate for the JPEG production path — inside low-RAM process budgets, versus ~70+ MB at 16 MP. The alpha-format worst case (no production sender exists — the camera is JPEG-only) peaks ≈ 72 MB and is recorded as residual, not silently scoped away. The gate's native bitmap is already released (`close()` in `finally`) before the cap runs, so the peaks don't stack; the raw capture bytes (~10 MB at `ResolutionPreset.max`) are the only co-resident holding.
- **The ceiling's residual, recorded.** Captures above 12.5 MP at `ResolutionPreset.max` reject as malformed input (above 16 MP already did today — misclassified). The canonical 12 MP sensor class (4032×3024 = 12,192,768 px) is admitted — that is what the ruled value exists to guarantee, pinned by a real fixture. The real fix for the >12.5 MP band is the bounded preset, which stays deferred with the 5.1 reopen because it shifts the gate's input distribution. Not decided here, not silently.
- **`compute()` crossing.** Flutter's `compute` rethrows isolate exceptions; keep `MalformedImageInput` a plain final-field class (no closures, no ports) so it crosses cleanly on Dart 3.13 — the dispatch test exercises exactly this path.

## Verification

**Commands:**
- `devbox run -- make gate` -- expected: green (format, analyze, all tests). Run evidence: green 2026-09-06 at 546c79e+working tree (915 tests, "No issues found"), re-run green after review round 2 patches
- `devbox run -- make check` -- expected: green with no seal edits (egress import seal, string-table audit, core purity, wire contracts, Gradle graph, merged manifests, eval harness, codegen-check). Run evidence: exit 0, 2026-09-06, both rounds

**Manual checks (if no CLI):**
- No surface or string renders from this story; the committed suites are the evidence. One behavior band does move and is recorded, not hidden: captures claiming more than 12.5 MP now reject as malformed input (previously >16 MP rejected, misclassified) — the 12 MP sensor class (4032×3024) passes, pinned by a real fixture. If Sergio wants a device leg anyway, the emulator recipe needs no new setup: nothing in this story renders.

## Suggested Review Order

**The one sniff, two readers (AC1 — mime truthfulness)**

- The shared magic sniff — single source of truth for cap and wire; disagreement is now a construction impossibility.
  [`image_cap.dart:16`](../../lib/egress/image_cap.dart#L16)

- The wire's declaration delegates to the sniff; undeclarable magic throws instead of silently reading `image/jpeg`.
  [`byok_wire.dart:274`](../../lib/egress/byok_wire.dart#L274)

**The pre-transport taxonomy (AC2 — nothing sent is never delivered-but-unusable)**

- `MalformedImageInput`: one plain final class for all four cap refusals, crossing `compute()` verbatim.
  [`image_cap.dart:44`](../../lib/egress/image_cap.dart#L44)

- `_causeOf`'s dedicated arm, above the `FormatException` arm (which returns to meaning delivered bodies only).
  [`byok_slicer.dart:172`](../../lib/egress/byok_slicer.dart#L172)

- The eighth port cause, pre-transport by doc; FR-29's surface stays seven.
  [`slicer_port.dart:110`](../../packages/core/lib/ports/slicer_port.dart#L110)

- The recorded fold `malformedInput → unreachable`, beside its `malformedResponse` precedent.
  [`no_slicer_cause.dart:87`](../../packages/core/lib/ports/no_slicer_cause.dart#L87)

**The ruled ceiling (AC3 — 12.5 MP, Sergio's ruling)**

- `egressPixelCeiling = 12_500_000` with the recorded arithmetic (37.5 MB JPEG worst, alpha residual named, camera class admitted).
  [`image_cap.dart:93`](../../lib/egress/image_cap.dart#L93)

- The overflow-safe guard: per-dimension bound before the product, so crafted uint32 headers cannot wrap past the budget check.
  [`image_cap.dart:151`](../../lib/egress/image_cap.dart#L151)

**The pins (AC4)**

- The discriminating band pin: 4096×3072 (12,582,912 px) refuses — under a reverted 16 MP guard it would decode, so the band cannot silently reopen.
  [`image_cap_test.dart:45`](../../test/egress/image_cap_test.dart#L45)

- The camera-class boundary: a real 4032×3024 capture survives and resizes — what the ruled value exists to guarantee.
  [`image_cap_test.dart:37`](../../test/egress/image_cap_test.dart#L37)

- The end-to-end taxonomy group: undecodable, GIF, BMP and WebP legs → `malformedInput`, zero sends.
  [`byok_slicer_test.dart:738`](../../test/egress/byok_slicer_test.dart#L738)

- The resize×wire composition: an oversized scan rides the wire as its re-encoded self — cap and wire joined for the first time.
  [`byok_slicer_test.dart:827`](../../test/egress/byok_slicer_test.dart#L827)

- Direct `imageMimeTypeOf` pins — the mislabel cannot regress silently.
  [`byok_slicer_test.dart:862`](../../test/egress/byok_slicer_test.dart#L862)

- The sniff's own census and edge shapes (empty, fragments, zero-dimension headers).
  [`image_cap_test.dart:264`](../../test/egress/image_cap_test.dart#L264)

- In-cap APNG passes through whole — the documented animated-shape behavior, pinned.
  [`image_cap_test.dart:299`](../../test/egress/image_cap_test.dart#L299)

- The genuinely-decodable WebP/BMP fixtures the refusals are staged with.
  [`egress_fixtures.dart:35`](../../test/egress/egress_fixtures.dart#L35)

---
title: 'The egress chokepoint, sealed three ways'
type: 'feature'
created: '2026-09-02'
status: 'done'
review_loop_iteration: 0
baseline_commit: '7923402761e42c607336dcbc338136c11fb57760'
context:
  - '{project-root}/_bmad-output/implementation-artifacts/epic-4-context.md'
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** AD-7's single egress chokepoint exists only as prose — nothing structural stops a second network opener arriving as a Dart import, a manifest-initialised native SDK, or a socket in our own Kotlin code.

**Approach:** Create `lib/egress/` — exactly three payload types, one image-resolution cap applied before any transport call, one-shot no-queue dispatch over a transport seam — and seal it with three `tool/` checks (Dart/Kotlin import check, resolved-Gradle-graph allowlist, merged-manifest enumerated set), each registered under `make check`.

## Boundaries & Constraints

**Always:**
- Payload union: `sealed class EgressPayload` in one library — `ScanImagePrompt(imageBytes, prompt)`, `ProjectGenesisText(text)`, `RescueResliceText(originContext, task)`; sealed-in-one-library makes a fourth subtype a compile error (AD-7's "no fourth exists as a type").
- Cap: one constant; after preparation no image dimension exceeds it; oversized input is downscaled, never rejected; JPEG→JPEG (q85), PNG→PNG; pure-Dart `package:image` via `compute()`; the cap runs inside `send()` before the transport is touched (AD-8's gate→mint→cap→upload order stays intact when Epic 5 wires consent).
- Dispatch: `EgressDispatch.send(payload)` → cap (scan shape only) → exactly one transport invocation; failure is terminal and surfaced; no queue, no retry, no persisted or retained pending state; no such API exists in the module. Transport is an injected closure (`typedef EgressTransport`) — 4-4's ByokSlicer binds the real HTTP client; `lib/egress/` therefore has no HTTP import yet, and the import check's permit-zone plus fixture tests cover both directions meanwhile.
- Seal 1 `tool/check_egress_imports.dart`: sweeps `lib`, `packages`, `test`, `tool` (NOT `eval/` — outside the app by design, story 4-1) for HTTP-client package imports (`package:http/`, `dio`, `http2`, `web_socket_channel`, `cupertino_http`, `cronet_http`, `fetch_client`, `oauth2`) and socket identifiers (`HttpClient`, `Socket`, `SecureSocket`, `WebSocket`, `RawSocket`, `RawDatagramSocket`) — all forbidden outside `lib/egress/**`. Kotlin sweep over `android/app/src/*/kotlin|java`: forbid socket/connection APIs (`java.net` sockets, `HttpURLConnection`, `URL`, `okhttp3`, `javax.net`) and date computation (`java.util.Date`, `Calendar`, `java.time.`, `System.currentTimeMillis`) per AD-4/AD-11.
- Seal 2 `tool/check_gradle_dependencies.dart`: runs `gradlew :app:dependencies --configuration {debug,release,profile}RuntimeClasspath --console=plain`, parses `group:artifact:version` (strips `(n)`/`(*)`), compares against a frozen in-code allowlist; any diff fails with the exact additions/removals and re-freeze instructions.
- Seal 3 `tool/check_android_manifest.dart`: runs `process{Debug,Release,Profile}MainManifest`, locates merged manifests under `build/app/intermediates`, enumerates `uses-permission`/`service`/`receiver`/`provider`; enumerated sets: release ⊆ {RECORD_AUDIO}, debug/profile ⊆ {RECORD_AUDIO, INTERNET}, app-declared components ∅ in all variants with one named, minimal platform baseline enumerated in the check (AGP's `DYNAMIC_RECEIVER_NOT_EXPORTED_PERMISSION`, `androidx.startup.InitializationProvider`, `androidx.profileinstaller.ProfileInstallReceiver`) — renegotiated with the human 2026-09-03. 4-4 adding INTERNET to main is a deliberate allowlist edit.
- All three follow repo check conventions: `Finding`/`maskCommentsAndStrings` from `tool/check_core_purity.dart`, output contract, exit 0/1/2; each has `test/tool/` tests plus `test/fixtures/` (fixtures excluded from their own sweep, as the store seal does).
- `tool/bootstrap.sh` becomes gradle-wrapper-aware (injects the wrapper from the pinned Flutter SDK's cache so seals run without a prior `flutter build`); the Makefile registers all three under `check` + `.PHONY`; bootstrap's "never by the completion gate" comment is fixed (now false).

**Ask First:**
- Cap value — propose **1536 px** (no dimension over; gemini-class vision input tiles at 768 px, so 2×768 captures all attainable quality while cutting a 12 MP frame ~6×) plus JPEG q85. Confirm or set another number.
- Wrapper provisioning — default: bootstrap copies `gradlew`/wrapper jar from `$FLUTTER_ROOT/bin/cache/artifacts/gradle_wrapper/` (idempotent; keeps flutter-managed files out of git). Alternative: un-ignore and commit the wrapper.
- Any change adding INTERNET to `android/app/src/main/AndroidManifest.xml` before 4-4.

**Never:**
- No `SlicerPort`, provider allowlist, credentials, BYOK transport or egress caller (4-3/4-4/4-5/4-6/Epic 5); no new Kotlin channels; no UI/string-table changes; no `eval/` changes; no persistence of anything in egress; no retry/queue/backoff machinery; no fourth payload type.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Dispatch, scan payload ≤ cap | bytes + prompt | transport invoked once with unchanged bytes | N/A |
| Dispatch, scan payload > cap | 4000 px JPEG | transport sees ≤ cap JPEG (q85), aspect preserved, either orientation | N/A |
| Dispatch, transport throws | any payload | `EgressFailed(cause)`; one attempt; a second `send` is a fresh call | no retry, nothing retained |
| HTTP import outside egress | fixture `package:http` in `lib/ui/` | finding at file:line, exit 1 | names the permit zone |
| HTTP import inside egress | fixture in `lib/egress/` | no finding | N/A |
| Kotlin socket/date usage | fixture `java.net.Socket` / `System.currentTimeMillis` | finding, exit 1 | N/A |
| Gradle graph drift | resolved graph ≠ frozen allowlist | exit 1, exact diff, re-freeze instructions | missing wrapper → actionable message |
| Manifest drift | merged manifest adds `<service>` or unknown permission | exit 1 naming component/permission + variant | N/A |

</frozen-after-approval>

## Code Map

- `lib/egress/` -- NEW module (none exists; zero network code in `lib/` today). Style anchors: sealed union at `packages/core/lib/log/log_entry.dart:120`; adapter-seam pattern at `lib/platform/dictate/dictate_recognizer.dart`.
- `tool/check_core_purity.dart:8-17,95` -- `Finding` + `maskCommentsAndStrings` helpers to import; output/exit contract.
- `tool/check_store_seal.dart:144-213` -- scopeRoots / `_collectFiles` / exit pattern and fixture exclusion to mirror.
- `test/tool/check_store_seal_test.dart` + `test/fixtures/store_seal/` -- the check-test pattern to copy.
- `Makefile:3-7,17,44-56` -- registration rule, `.PHONY`, `check:` recipe.
- `android/settings.gradle.kts:20-24` -- AGP 9.1.0, Kotlin 2.4.0; wrapper pinned 9.3.1 (`android/gradle/wrapper/gradle-wrapper.properties`); NO `dependencies {}` blocks exist — the graph arrives transitively from the Flutter Gradle plugin embedding pub plugins.
- `android/build.gradle.kts:8-17` -- build dir redirected to repo-root `build/`, so intermediates land under `build/app/…`.
- `android/app/src/main/AndroidManifest.xml:5` -- RECORD_AUDIO only; debug/profile manifests add INTERNET (template). Release has NO INTERNET today — correct until 4-4.
- `android/app/src/main/kotlin/dev/dorogoy/organizer/` -- `MainActivity.kt`, `DictateChannel.kt`, `DictateRecognizer.kt`: the only Kotlin sources; no sockets/dates today; notify + credentials channels are future stories (AD-11), covered by the sweeps automatically.
- `tool/bootstrap.sh` + `.github/workflows/ci.yml` -- `make deps` provisions the Android SDK (platform 36, build-tools 36); CI runs `make check`, JDK 21 from devbox — seals must pass there.
- `pubspec.yaml` -- add `image` (pinned at cold-start); spine Stack table gets a row (`ARCHITECTURE-SPINE.md:256` area).
- `eval/pubspec.yaml:7` -- the one legitimate `http` import outside the app (4-1) — why seal 1 excludes `eval/`.

## Tasks & Acceptance

**Execution:**
- [x] `lib/egress/egress_payload.dart` + `lib/egress/image_cap.dart` + `lib/egress/egress_dispatch.dart` + `pubspec.yaml` (+ spine Stack row) -- sealed three-payload union, cap (value per Ask-First, q85), one-shot dispatch over injected transport typedef, `EgressResult` sealed (`EgressDelivered(responseBody)` / `EgressFailed(cause)`) -- AD-7's chokepoint skeleton; no HTTP import yet.
- [x] `test/egress/` -- matrix rows 1–3: exactly-once transport, cap pass-through/downscale (JPEG+PNG, portrait+landscape), failure terminal, union exhaustiveness (a fourth type does not compile).
- [x] `tool/check_egress_imports.dart` + `test/tool/` tests + fixtures -- seal 1, Dart and Kotlin sweeps as bounded above.
- [x] `tool/check_gradle_dependencies.dart` + tests + fixtures (sample `dependencies` output text) -- seal 2, frozen from a real resolve.
- [x] `tool/check_android_manifest.dart` + tests + fixtures (sample merged XMLs) -- seal 3, per-variant enumerated sets.
- [x] `tool/bootstrap.sh` + `Makefile` -- wrapper injection (Ask-First choice), three check lines + `.PHONY`, bootstrap comment fix; verify `make check` green end-to-end in devbox (first run may download Gradle 9.3.1).

**Acceptance Criteria:**
- Given the codebase, when HTTP client imports are located, then only `lib/egress/` is permitted one (none in-app today; 4-4 lights the positive case) and `dart run tool/check_egress_imports.dart` fails on any other, Kotlin sources included.
- Given the egress module, when payloads are enumerated, then exactly three shapes exist and a fourth does not compile.
- Given an image payload, when it is prepared, then no dimension exceeds the cap before any transport call.
- Given a failed egress call, when the module is inspected, then no queue, retry, or persisted/retained pending request exists — by construction and by test.
- Given the resolved Gradle graph, when seal 2 runs, then it matches the frozen allowlist or the check fails.
- Given the merged manifests, when seal 3 runs, then nothing outside the enumerated per-variant sets is declared, else the check fails.
- Given the three checks, when the story completes, then each is a Makefile target reachable from `make check`, green in devbox and CI.
- Given the Kotlin sources, when swept, then no socket API and no date-computation API is present.

## Spec Change Log

- 2026-09-03 (review): human approved the frozen-block renegotiation for seal 3 — "components ∅ in all variants" amended to "app-declared components ∅ + one named, minimal platform baseline" after the review's intent_gap finding confirmed AGP/androidx inject components into every merged variant. Code unchanged (it already implemented the amended intent); the frozen line and this entry are the only edits. KEEP: the platform baseline stays named and minimal in-check, and any other component/permission in any variant still fails.
- 2026-09-03 (implementation): seal 3's frozen "components ∅ in all variants" cannot pass against the real merged manifests — AGP injects `dev.dorogoy.organizer.DYNAMIC_RECEIVER_NOT_EXPORTED_PERMISSION` (targetSdk 34+) and androidx.core (via the Flutter embedding) merges `androidx.startup.InitializationProvider` + `androidx.profileinstaller.ProfileInstallReceiver` into every variant. Implemented as the frozen per-variant app sets plus one named, minimal platform-baseline constant (`permittedComponentsAllVariants` + `dynamicReceiverPermission` in `tool/check_android_manifest.dart`); any other component or permission, in any variant, still fails. The seal's purpose (a manifest-initialised SDK declares a component → exit 1) is unchanged.
- 2026-09-03 (implementation): Ask-First defaults taken as proposed — cap 1536 px + JPEG q85 (`egressImageCap`/`egressJpegQuality`, pinned by test); wrapper injected from the pinned SDK's `bin/cache/artifacts/gradle_wrapper/` (idempotent, gitignored); no INTERNET in main before 4-4.
- 2026-09-03 (implementation): `compute()` copies the byte buffer across the isolate boundary, so the cap's within-cap pass-through is byte-identical in value, not the same instance — tests assert value equality; `lib/egress/` documents it.

## Design Notes

- Per-variant manifest sets: the template's debug/profile INTERNET is dev tooling (hot reload), not app egress; release carrying none is the honest current state — adding it is 4-4's deliberate act, visible as an allowlist edit.
- In-code allowlist (not a data file): store-seal precedent (`persistenceImportAllowlist`); the frozen graph is ~40 transitive lines with versions, so every drift (even a Flutter patch bump) is a visible, deliberate re-freeze.
- `package:image` is pure Dart with no Android footprint, so both native seals stay unaffected; the cap bounds both dimensions, so EXIF orientation cannot dodge it.
- RegExp parsing of `dependencies` text and machine-generated manifest XML matches the repo's zero-dependency check style; the live-Gradle path stays thin and fixture-tested.

## Verification

**Commands:**
- `devbox run -- make gate` -- expected: green.
- `devbox run -- make check` -- expected: green including the three new seals (first Gradle invocation downloads the 9.3.1 distribution).
- `devbox run -- flutter test test/egress test/tool` -- expected: all matrix rows green.

**Executed evidence (2026-09-03, post-review patches, devbox):**
- `make gate` green — 618 tests, `dart format` 0 changed, `flutter analyze` no issues.
- `make check` green — all prior checks plus `egress import check passed`, `gradle dependency check passed (3 configurations, 153 graph entries)`, `android manifest check passed (3 variants)`, eval 94 tests, codegen fresh.
- `flutter test test/egress test/tool` green — 257 tests, including conflict-line parsing, project/local-file graph entries, foreign-application metadata failure, Dart FFI/server sockets, star-import `java.time.*`, flavor source-set glob, symlink refusal, EXIF bake, third-format (GIF), header-ceiling, stack-capture, wrapper/local.properties exit-2 drills.
- Gradle distribution switched to `-bin` with `distributionSha256Sum` (b266d5ff…); one local re-download observed, seals green after.
- Fresh-clone facts verified: `flutter pub get` writes `android/local.properties`; the official Flutter tarball ships `bin/cache/artifacts/gradle_wrapper/`.

## Suggested Review Order

**The chokepoint module**

- Three payloads, sealed in one library — a fourth shape is a compile error, not a convention.
  [`egress_payload.dart:17`](../../lib/egress/egress_payload.dart#L17)

- The cap's whole pipeline in one doc: header probe, ceiling, pass-through, bake, resize, re-encode.
  [`image_cap.dart:21`](../../lib/egress/image_cap.dart#L21)

- Pass-through is decided by the header alone — in-cap photos pay no decode.
  [`image_cap.dart:56`](../../lib/egress/image_cap.dart#L56)

- EXIF baked before resize so a portrait JPEG never reaches the model sideways.
  [`image_cap.dart:65`](../../lib/egress/image_cap.dart#L65)

- One-shot dispatch: cap inside `send`, one transport call, failure carries its stack.
  [`egress_dispatch.dart:11`](../../lib/egress/egress_dispatch.dart#L11)

**Seal 1 — imports and Kotlin hygiene**

- The permit zone and the denylist, including the FFI residual-risk note.
  [`check_egress_imports.dart:45`](../../tool/check_egress_imports.dart#L45)

- Kotlin sweep: generic variant glob, star imports, qualified `java.net.` use.
  [`check_egress_imports.dart:79`](../../tool/check_egress_imports.dart#L79)

**Seal 2 — the frozen Gradle graph**

- The frozen allowlist with its provenance header — re-freeze output, reviewable.
  [`check_gradle_dependencies.dart:46`](../../tool/check_gradle_dependencies.dart#L46)

- Conflict-arrow reconstruction: pre-arrow `group:artifact` + post-arrow version.
  [`check_gradle_dependencies.dart:238`](../../tool/check_gradle_dependencies.dart#L238)

**Seal 3 — the merged manifest**

- Per-variant permission sets; release carries no INTERNET until 4-4 decides.
  [`check_android_manifest.dart:55`](../../tool/check_android_manifest.dart#L55)

- The named platform baseline the human renegotiated (AGP + androidx injections).
  [`check_android_manifest.dart:61`](../../tool/check_android_manifest.dart#L61)

- `activity`/`activity-alias` enumerated against exactly MainActivity.
  [`check_android_manifest.dart:12`](../../tool/check_android_manifest.dart#L12)

**Build wiring**

- Three new targets under `make check` (NFR20), each independently runnable.
  [`Makefile:61`](../../Makefile#L61)

- Wrapper injected from the pinned SDK's cache — seals run before any `flutter build`.
  [`bootstrap.sh:174`](../../tool/bootstrap.sh#L174)

- Contract-hardened Gradle runner: exit 2 with remedies, 15-minute timeout.
  [`gradle_runner.dart:7`](../../tool/gradle_runner.dart#L7)

- `-bin` distribution, sha256-pinned like every other downloaded bit.
  [`gradle-wrapper.properties:9`](../../android/gradle/wrapper/gradle-wrapper.properties#L9)

- CI Gradle cache so `make check` stops paying the distribution download.
  [`ci.yml:23`](../../.github/workflows/ci.yml#L23)

**Peripherals**

- Shared fixtures and both over-cap orientations, ~3× faster than the first cut.
  [`egress_fixtures.dart:1`](../../test/egress/egress_fixtures.dart#L1)

- 257 check/module tests: conflict lines, foreign activities, star imports, EXIF, GIF.
  [`check_egress_imports_test.dart:1`](../../test/tool/check_egress_imports_test.dart#L1)

### Review Findings

- [x] [Review][Patch] Do not reject valid oversized images, and bound the decode without permitting an unsafe 20,000 x 20,000 allocation [lib/egress/image_cap.dart:49-53]
- [x] [Review][Patch] Seal Dart server and raw socket APIs outside the egress permit zone [tool/check_egress_imports.dart:59-68]
- [x] [Review][Patch] Parse show, hide and deferred clauses so every outside HTTP import is detected [tool/check_egress_imports.dart:138-189]
- [x] [Review][Patch] Prevent Dart FFI from opening a native socket outside all three egress seals [tool/check_egress_imports.dart:40-44]
- [x] [Review][Patch] Include project and local-file runtime dependencies in the frozen Gradle graph [tool/check_gradle_dependencies.dart:230-265]
- [x] [Review][Patch] Enumerate the application entry point and startup metadata in the merged-manifest seal [tool/check_android_manifest.dart:108-131]
- [x] [Review][Patch] Seal java.nio.channels socket APIs in the Kotlin/Java sweep [tool/check_egress_imports.dart:104-122]
- [x] [Review][Patch] Catch java.util wildcard imports and unqualified date APIs in the Kotlin/Java sweep [tool/check_egress_imports.dart:124-133]
- [x] [Review][Patch] Fail closed or inspect symlinked Dart, Kotlin and Java sources [tool/check_egress_imports.dart:82-97]
- [x] [Review][Patch] Preserve complete Gradle versions containing characters outside the narrow coordinate regex [tool/check_gradle_dependencies.dart:212-215]
- [x] [Review][Patch] Add direct tests for the Gradle runner's documented exit-2 environment contract [tool/gradle_runner.dart:28-93]

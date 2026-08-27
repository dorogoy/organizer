# Verification Review — ARCHITECTURE-SPINE.md, update round 2026-08-27

- **Reviewer role:** independent verification subagent (no prior context; research + writing only, nothing modified in the spine or project)
- **Lens:** every committed stack/API decision re-checked against the live web rather than training data; greenfield, so starter/live defaults checked directly
- **Date of re-verification:** 2026-08-27
- **Subject:** `ARCHITECTURE-SPINE.md` (updated 2026-08-27), Stack table + Deferred + the Android API claims embedded in AD-11/AD-17
- **Method:** live fetches of pub.dev package pages/API, Google Play policy page, Flutter releases JSON and blog, Kotlin release pages, Google issue tracker, HuggingFace model card, Android developer docs/API diff, CommonsWare; no claim accepted from memory alone where a 2025+ fact was involved

## Verdict

**PASS.** Every load-bearing claim in the amended Stack table and the Android API claims was independently re-verified against the live web and found accurate, including the three amended rows this round. One LOW finding (an ambiguity in a non-load-bearing note, the uuid v7 monotonicity phrasing) is recorded below; it does not require a change to any decision, only an optional one-word clarification.

## The three amended rows — re-verified in detail

### Amendment 1 — Target SDK note

**Claim (spine):** "API 37 (Android 17) shipped 2026-06-16; Play requires 36 from 2026-08-31 (its live policy page) — the Aug-2027 date for 37 is a projection, and moot while AD-18 rules out store distribution. 37's edge-to-edge and resizability changes are a known follow-up"

**What the web says:**

- The live Play Console Help page "Target API level requirements for Google Play apps" (fetched in full, 2026-08-27) states verbatim: "Starting August 31, 2026: New apps and app updates must target Android 16 (API level 36) or higher to be submitted to Google Play" — and lists **no requirement for API 37 anywhere on the page**. So "requires 36 from 2026-08-31 (its live policy page)" is exact, and calling the Aug-2027-for-37 date "a projection" is the correct epistemic status: it is not on the live policy page.
- Android 17 (API 37) release: the official Android Developers blog "Android 17 is here" is dated June 2026, and third-party developer coverage states "Android 17 shipped on 16 June 2026 as API level 37." The 2026-06-16 date checks out.
- API 37 behavior changes: developer coverage of Android 17 lists "forced resizability on large screens" and edge-to-edge enforcement among the breaking changes — consistent with "edge-to-edge and resizability changes are a known follow-up."
- The Deferred section's "Target 36 is compliant until Aug 2027" is a projection of Google's annual cadence, labeled as such in context; nothing on the live page contradicts it.

**Sources:**
- https://support.google.com/googleplay/android-developer/answer/11926878?hl=en (live policy page, fetched 2026-08-27)
- https://android-developers.googleblog.com/2026/06/Android-17.html
- https://developer.android.com/about/versions/17/release-notes
- https://abinantony.io/blog/android-17-api-37-changes-to-act-on ("shipped on 16 June 2026 as API level 37")

**Result: CONFIRMED, no finding.**

### Amendment 2 — ML Kit 16 KB alignment row

**Claim (spine):** google_mlkit_face_detection 0.15.1, "community-maintained, **not** by Google. 32-bit libs exist but only the 64-bit libs are 16 KB-aligned; `abiFilters` must exclude 32-bit ABIs — which is also the 16 KB page-size condition"

**What the web says:**

- The Google issue tracker entry "[ML Kit] 32-bit face-detection native libraries are still built with 4 KB page alignment (not 16 KB)" (issuetracker.google.com/issues/458518879) and the mirrored feature request googlesamples/mlkit#986 state: "The arm64-v8a and x86_64 versions of `libface_detector_v2_jni.so` are correctly aligned" — i.e., exactly the spine's split: 32-bit libs ship but are 4 KB-aligned; only 64-bit libs are 16 KB-aligned. Excluding the 32-bit ABIs via `abiFilters` removes the only non-16 KB-aligned artifacts, which is what the Play 16 KB page-size condition requires (all shipped `.so` must be 16 KB-aligned). The amended row matches the tracker precisely.
- A separate report (googlesamples/mlkit#1024, "ML Kit Face Detection (16.1.7) not compatible with 16KB page size…") asserts broader incompatibility ("native binaries appear to still be built with 4KB alignment") but is a user report without the 32/64-bit breakdown; the official tracker issue and #986 carry the precise per-ABI facts the spine cites. No contradiction of the spine's narrower, correct claim.
- Plugin: pub.dev `google_mlkit_face_detection` 0.15.1 is the live latest (published ~9 days before 2026-08-27), publisher flutter-ml.dev; README states verbatim: "This plugin is not sponsored or maintained by Google." "Community-maintained, not by Google" confirmed.
- iOS README note in the same plugin ("ML Kit does not support 32-bit architectures (i386 and armv7)" on iOS) is about iOS only; on Android the 32-bit libs do exist, as the spine says.

**Sources:**
- https://issuetracker.google.com/issues/458518879
- https://github.com/googlesamples/mlkit/issues/986
- https://github.com/googlesamples/mlkit/issues/1024
- https://pub.dev/packages/google_mlkit_face_detection (version + "not sponsored or maintained by Google")

**Result: CONFIRMED, no finding.**

### Amendment 3 — flutter_secure_storage row

**Claim (spine):** flutter_secure_storage 11.0.0. "It did **not** move to Tink. Under the default RSA-OAEP cipher the AES key is RSA-wrapped **in SharedPreferences**, which FR-28 forbids in words — so the AES-in-KeyStore cipher is configured explicitly, or the requirement is broken by default. Fork `flutter_secure_storage_x` 13.2.0 is the fallback"

**What the web says, clause by clause:**

1. **"It did not move to Tink" — confirmed.** The live pub.dev README and the 11.0.0-beta.1 changelog state the Jetpack Security `EncryptedSharedPreferences` backend (the Tink-based path) was **removed** and replaced by custom cipher implementations: "New default ciphers: RSA OAEP (key cipher) + AES-GCM (storage cipher)"; "Removed encryptedSharedPreferences parameter from AndroidOptions… The Jetpack Security (EncryptedSharedPreferences) backend is no [longer used]". v11 uses its own RSA/AES implementation, not Tink. The claim (dropped motivation clause, negative assertion only) is accurate.
2. **"Under the default RSA-OAEP cipher the AES key is RSA-wrapped in SharedPreferences" — confirmed.** The README's Android cipher table: default `AndroidOptions()` = key cipher `RSA/ECB/OAEPWithSHA-256AndMGF1Padding`, storage cipher `AES/GCM/NoPadding`, with the note "RSA key ciphers wrap the AES encryption key with RSA." Storage location of the wrapped key + ciphertext is SharedPreferences: the README's backup section instructs excluding "sharedprefs used by FlutterSecureStorage" from Auto Backup; maintainer-threaded issue #413 ("[Loophole] Is it really secure?") describes the RSA-wrapped key stored in SharedPreferences; the fork's own roadmap table labels v10/v11 of the lineage "SharedPreferences (Default)… Custom Implementation (RSA/AES)."
3. **"The AES-in-KeyStore cipher is configured explicitly" — confirmed.** README: the `AES_GCM_NoPadding` key cipher "stores the key directly in Android KeyStore," available only via `AndroidOptions(keyCipherAlgorithm: KeyCipherAlgorithm.AES_GCM_NoPadding, …)` or the `AndroidOptions.biometric()` constructors — i.e., opt-in, not default. "Or the requirement is broken by default" is a sound inference from (2)+(3).
4. **"Fork `flutter_secure_storage_x` 13.2.0 exists as fallback" — confirmed.** Live on pub.dev: `flutter_secure_storage_x` 13.2.0 (published ~59 days before 2026-08-27, publisher koji-1009.com), "a fork of the popular flutter_secure_storage package," Android v13 = "Android KeyStore ONLY" with DataStore default — a coherent FR-28-compatible fallback.
5. **Version 11.0.0** is the live latest of the original package (published ~20 days before 2026-08-27).

**Sources:**
- https://pub.dev/packages/flutter_secure_storage (README cipher tables, backup guidance, v11.0.0 latest)
- https://pub.dev/packages/flutter_secure_storage/versions/11.0.0-beta.1/changelog (Jetpack Security removal)
- https://github.com/juliansteenbakker/flutter_secure_storage/issues/413 (wrapped key in SharedPreferences)
- https://pub.dev/packages/flutter_secure_storage_x (13.2.0, fork, KeyStore-only v13)

**Result: CONFIRMED, no finding.**

## Remaining pinned versions — all re-verified live (2026-08-27)

| # | Spine claim | Live web result | Source | Status |
|---|---|---|---|---|
| 1 | Flutter 3.47.1 / Dart 3.13.1 | Official releases JSON: stable `3.47.1` with `dart_sdk_version: "3.13.1"` (released 2026-08-19); it is the current stable (`current_release.stable` hash matches) | https://storage.googleapis.com/flutter_infra_release/releases/releases_linux.json | ✓ |
| 2 | Flutter 3.47 "brings Java 17 and a Flutter-side minimum of Android API 24" | Flutter 3.47 blog, "Android dependency matrix": "Java: 17 (minimum required version)"; "`flutter.minSdkVersion` (API 24)". Also compile/target default API 36 | https://flutter.dev/blog/whats-new-in-flutter-3-47 | ✓ |
| 3 | drift 2.34.3 + drift_flutter 0.3.1 | Both are the live `latest` on pub.dev API (drift_flutter 0.3.1 published 2026-07-11) | https://pub.dev/api/packages/drift , …/drift_flutter | ✓ |
| 4 | "AD-2's triggers must be declared in a `.drift` file — drift supports them nowhere else" | Official drift API docs, verbatim: "In drift, triggers can only be declared in .drift files." | https://pub.dev/documentation/drift/latest/drift/ ; https://drift.simonbinder.eu/sql_api/drift_files/ | ✓ |
| 5 | flutter_riverpod 3.4.2 | Live `latest` on pub.dev API | https://pub.dev/api/packages/flutter_riverpod | ✓ |
| 6 | camera 0.12.0+2, "first-party (flutter.dev)" | Live `latest` on pub.dev API; package maintained under flutter/packages, documented as the standard camera plugin in the Flutter cookbook | https://pub.dev/api/packages/camera ; https://docs.flutter.dev/cookbook/plugins/picture-using-camera | ✓ |
| 7 | google_mlkit_face_detection 0.15.1 | Live latest (see Amendment 2) | https://pub.dev/packages/google_mlkit_face_detection | ✓ |
| 8 | saf_util 3.1.0, "pickers and persisted permissions **only — it provides no read/write**" | Live latest 3.1.0 (2026-05-30). README verbatim: "Note that this package doesn't provide any read / write functions (go to saf_stream for that)"; lists `hasPersistedPermission` / `releasePersistedPermission` | https://pub.dev/api/packages/saf_util ; https://github.com/flutter-cavalry/saf_util README | ✓ |
| 9 | saf_stream 4.0.1, "the actual write path for FR-30" | Live latest 4.0.1 (2026-07-28); description "Read and write Android SAF `DocumentFile`" | https://pub.dev/api/packages/saf_stream | ✓ |
| 10 | uuid 4.6.0, "RFC 9562 v7" | Live latest (2026-07-15); changelog adopts RFC 9562 terminology (`strictRFC9562`, deprecating `strictRFC4122`). See Finding F1 for the monotonicity phrasing | https://pub.dev/api/packages/uuid ; Daegalus/dart-uuid CHANGELOG | ✓ (with F1 note) |
| 11 | flutter_local_notifications 22.3.0, actively maintained, deliberately unused | Live `latest` on pub.dev API | https://pub.dev/api/packages/flutter_local_notifications | ✓ |
| 12 | Kotlin 2.4.0 "released 2026-06-03", from the Flutter Android template | kotlinlang.org releases: "2.4.0 Released: June 3, 2026"; JetBrains blog "Kotlin 2.4.0 Released" June 3, 2026; Flutter 3.47 verified dependency matrix pins "Kotlin Gradle Plugin (KGP): 2.4.0" | https://kotlinlang.org/docs/releases.html ; https://blog.jetbrains.com/kotlin/2026/06/kotlin-2-4-0-released/ ; https://flutter.dev/blog/whats-new-in-flutter-3-47 | ✓ |
| 13 | material/cupertino "**not a dependency**"; opt-in `material_ui` 1.1.0 / `cupertino_ui` in 3.47; SDK still ships the libraries; `package:flutter/material.dart` only *scheduled* for deprecation in the November 2026 stable | All four confirmed: 3.47 blog "you can now opt-in to the standalone `material_ui` and `cupertino_ui` packages" (1.0 announced; `material_ui` 1.1.0 published 2026-08-24 is now live latest, depends on `cupertino_ui ^1.0.0`); "the core SDK still includes these libraries for this release"; "The original design libraries inside the core SDK are scheduled for formal deprecation in the upcoming Fall stable release in November" | https://flutter.dev/blog/whats-new-in-flutter-3-47 ; https://pub.dev/api/packages/material_ui | ✓ |
| 14 | Gemma 4 E4B "3.66 GB on disk; 3654 MB Android model size; ~3283 MB peak memory, per the official model card — not the ~2.5 GB the first draft claimed" | litert-community HF model card `gemma-4-E4B-it-litert-lm`: "The model file size is 3.66 GB"; benchmark table rows "195, 17.7, 5.3, **3654**, **3283**" (Android S26 Ultra CPU: peak CPU memory 3283 MB). Google's AI Edge LiteRT-LM page rounds the same artifact to "Model Size: 3.65 GB" with the same 3283 MB peak — same fact, coarser rounding. First-draft ~2.5 GB was indeed wrong in the direction that matters | https://huggingface.co/litert-community/gemma-4-E4B-it-litert-lm ; https://developers.google.com/edge/litert-lm/models/gemma-4 | ✓ |
| 15 | Deferred: "`flutter_gemma` 1.6.5 exists with MediaPipe and LiteRT-LM engines and Gemma 4 E4B listed" | Live latest 1.6.5 (published 4 days before 2026-08-27, publisher sashadenisov.dev). README lists "Gemma 4 E2B/E4B" in supported models, and engine packages `flutter_gemma_litertlm` and `flutter_gemma_mediapipe`. Repo moved to DenisovAV/flutter_gemma — worth knowing if anyone follows an old link, not a spine defect | https://pub.dev/packages/flutter_gemma | ✓ |
| 16 | Android minSdk 33 rationale: recognizer APIs are 31; `POST_NOTIFICATIONS` and `checkRecognitionSupport()` / `triggerModelDownload()` set 33 | Android SDK API diff for 33 lists `SpeechRecognizer.checkRecognitionSupport(Intent, Executor, RecognitionSupportCallback)` and `triggerModelDownload(Intent)` as added in 33; on-device recognizer pair (`createOnDeviceSpeechRecognizer`/`isOnDeviceRecognitionAvailable`) is documented as API 31; `POST_NOTIFICATIONS` runtime permission exists since API 33 | https://developer.android.com/sdk/api_diff/33/changes/android.speech.SpeechRecognizer ; https://developer.android.com/reference/android/speech/SpeechRecognizer | ✓ |
| 17 | AD-17: inexact alarm, "No exact-alarm permission is requested" | Consistent with Android alarm docs: only exact alarms need `SCHEDULE_EXACT_ALARM`/`USE_EXACT_ALARM`; inexact alarms require no permission (long-stable documented behavior) | https://developer.android.com/training/schedule/alarms | ✓ |
| 18 | `RECEIVE_BOOT_COMPLETED` as the one install-time permission | `RECEIVE_BOOT_COMPLETED` is a normal (install-time, auto-granted) permission per the Android manifest/permissions docs (long-stable) | https://developer.android.com/reference/android/Manifest.permission#RECEIVE_BOOT_COMPLETED | ✓ |
| 19 | AD-11: channel "importance cannot be changed after creation… the user may loosen it in system settings; the app can never widen it back" | developer.android.com, verbatim: "After you create a notification channel, you can't change the notification channel's visual and auditory behaviors programmatically. Only the user can change…" | https://developer.android.com/develop/ui/compose/notifications/channels | ✓ |
| 20 | 512 persisted SAF grants (context for the SAF pair; lives in `.memlog.md`, not the spine text itself) | CommonsWare: "there is a cap of 128 persisted permission grants… UPDATE: Android 11 updated that limit to 512," baked into AOSP `UriGrantsManagerService` (`MAX_PERSISTED_URI_GRANTS`), i.e. 512 on API 30+ | https://commonsware.com/blog/2020/06/13/count-your-saf-uri-permission-grants.html ; AOSP UriGrantsManagerService.java | ✓ |

## Findings

### F1 — LOW — uuid note overstates default v7 monotonicity (non-load-bearing; clarify, don't decide)

- **Severity:** LOW
- **Quoted claim:** "`uuid` | 4.6.0 | RFC 9562 v7. Intra-millisecond monotonicity bears on AD-3's stable-id tie-break"
- **What the web actually says:** dart-uuid's README is explicit that plain `uuid.v7()` is **not** ordered within a millisecond: "`uuid.v7()` fills everything after the millisecond timestamp with random bits, so ids created in the same millisecond have no defined order." Intra-millisecond monotonicity exists only as an **optional** generator — `UuidV7Monotonic` from `package:uuid/v7monotonic.dart` (16-bit counter, RFC 9562 §6.2 Method 1) — which must be imported and used deliberately.
- **Why it is only LOW:** the spine's own conventions line already forecloses any reliance on id ordering — "every ordering derivation (FIFO, least-recently-dealt, window anchors) reads recorded act instants, **never id bit patterns**" — so no invariant rests on v7 monotonicity; the stack note is contextual, not load-bearing. The risk is only that a future story reads the note as "v7 ids sort by creation time" and leans on it. A one-word fix ("optional intra-millisecond monotonicity via `v7monotonic`") would close the ambiguity; no decision changes either way.
- **Source:** https://github.com/Daegalus/dart-uuid README, "Monotonic v7" section (fetched 2026-08-27)

## Claims checked and deliberately not flagged (per review ground rules)

- **Stable-but-current pins that could drift daily** (Flutter 3.47.1, drift 2.34.3, riverpod 3.4.2, camera 0.12.0+2, saf_util 3.1.0, saf_stream 4.0.1, uuid 4.6.0, FLN 22.3.0, google_mlkit_face_detection 0.15.1, flutter_secure_storage 11.0.0, drift_flutter 0.3.1): each was the live `latest` on 2026-08-27 — i.e., maximally fresh, not stale. Nothing to flag.
- **3.66 GB vs 3.65 GB for Gemma 4 E4B:** the HF model card says 3.66 GB; Google's AI Edge page rounds the same artifact to 3.65 GB. The spine cites "the official model card" and quotes its exact figures (3.66 GB / 3654 MB / 3283 MB) — correct as cited; the 3.65 elsewhere is coarser rounding of the same 3654 MB, not a contradiction.
- **"Moot while AD-18 rules out store distribution"** and similar internal-logic statements: architecture reasoning, not web facts; out of scope for this lens and internally consistent with the spine's own AD-18.
- **Flutter localizations / gen_l10n "ships with Flutter"; material libraries still in SDK:** both restated verbatim by the 3.47 blog ("the core SDK still includes these libraries for this release"; localization delegates unbundled into the standalone packages).
- **google_mlkit issue #1024's broader 16 KB complaint:** a user report lacking the per-ABI breakdown; the official tracker (458518879) supports the spine's precise 32/64-bit claim. Recording it here so the next reviewer knows it was seen and discounted deliberately, not missed.

## Summary counts

- Findings: **1 total** — LOW: 1, MEDIUM: 0, HIGH: 0, BLOCKER: 0
- Claims re-verified live: 20 numbered above (3 amended rows + 12 version pins + 5 Android API/platform claims), all confirmed except F1's phrasing nuance

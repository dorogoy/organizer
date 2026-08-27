# Reviewer lens — verification (configured reviewer 1)

**Mandate:** every committed decision web-researched or reality-checked, not asserted from training data.

**Verdict:** PASS with three corrections. No named technology is invented; the gaps are unverified pins and one split-evidence API level that was load-bearing.

## Confirmed against the web on 2026-08-26

| Claim | Status |
| --- | --- |
| Flutter 3.47.1 / Dart 3.13.1 stable 2026-08-19 | confirmed |
| Impeller default on Android, Skia removed | confirmed |
| Material/Cupertino moved out of Flutter core to standalone packages | confirmed — **not reflected in the spine's Stack** |
| Android 16 = API 36; Play requires it for new apps from 2026-08-31 | confirmed |
| drift 2.34.3, Flutter Favorite, verified publisher | confirmed |
| Gemma 4 E4B real, LiteRT-LM/MediaPipe on Android, ~2.5 GB disk / 4–5 GB RAM | confirmed |
| No provider offers written zero retention with a user key; Gemini free tier trains | confirmed |
| Per-scan cost ~0.003–0.006 USD | confirmed from current published per-token pricing |
| `USE_EXACT_ALARM` Play-restricted; `SCHEDULE_EXACT_ALARM` denied by default from Android 14 | confirmed |
| `shared_storage` discontinued; `saf_util` live; 512 persisted grants on API 30+ | confirmed |
| `google_mlkit_face_detection` exists, community-maintained, not by Google, 64-bit only | confirmed |
| `speech_to_text` 7.4.0 exposes neither on-device recognizer nor fallback prevention | confirmed |
| `flutter_local_notifications` issue #2106 (channel importance one level low) | confirmed |

## Findings

**CRITICAL — C1. `createOnDeviceSpeechRecognizer()` API level is unresolved and minSdk was set on the weaker reading.**
Two sources conflict: one states API 31 for both `createOnDeviceSpeechRecognizer()` and `isOnDeviceRecognitionAvailable()`; a 2026 guide states "starting in Android 13 (API 33)". The official reference page did not yield the annotation. The spine binds `minSdk 31` on the API-31 reading. If 33 is correct, FR-32 is silently absent on Android 12–12L — which FR-32's own "affordance simply not present" rule would mask, so the defect would never surface as a bug.
*Fix applied:* minSdk raised to **33**, with the split evidence recorded. Costs nothing for a 2026 three-handset validation and removes the ambiguity.

**HIGH — H1. `flutter_secure_storage` was asserted, not verified.**
It is FR-28's key-custody mechanism, i.e. load-bearing.
*Verified after the finding:* actively maintained (11.0.0-beta.1 as of ~mid-2026), migrated from the deprecated Jetpack Crypto library to Google Tink, RSA-OAEP + AES-GCM on Android with the AES key held in Android KeyStore, min Android SDK 23, needs Dart ≥ 3.3 / Flutter ≥ 3.19. A maintained fork exists (`flutter_secure_storage_x` 10.2.3) as a fallback. *Fix applied* to the Stack row.

**MEDIUM — M1. Material/Cupertino as standalone packages is unrecorded.**
Flutter 3.44 moved them out of core. A cold-start pubspec that assumes they come with `flutter` will not resolve. *Fix applied* as a Stack note.

**MEDIUM — M2. Riverpod and `camera` carry no verified version.**
Both say "pin at cold-start", which is honest rather than asserted, and neither is load-bearing to an invariant. Accepted as-is; the pubspec is the pin.

**LOW — L1. Gemma 4 context window.** The PRD says 256K; current sources say 128K. The spine does not state it, so nothing to fix — noted so a later reader does not carry the PRD figure into a design.

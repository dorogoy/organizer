# Party validation — Mary + Level verification lens

**Reviewed:** `ARCHITECTURE-SPINE.md` (status `final`, updated 2026-08-27)  
**Mode:** validate only; no spine edits  
**Verdict:** **CONDITIONAL PASS — one blocking source/operability conflict, one material provider-terms correction, and two documentation cautions.** The committed Flutter/Android/package versions and most platform-API claims are current and supported. The architecture's local-first/no-backend boundary is faithful to the PRD, but the validation annex's proposed key-distribution mechanism is not safely implementable as written for every allowlisted provider.

## Findings

### V-1 — HIGH / BLOCKING — “BYOK” and the validation annex describe two incompatible credential owners; sharing builder-issued OpenAI keys is contractually unsafe

The spine's scope and topology say the app reaches **“the user's own provider account”** using a BYOK key, while PRD §8 says each subject receives her own API key **issued from the builder's single provider account**, without her own account. These are materially different trust, billing, revocation, and incident boundaries. More importantly, OpenAI's current Services Agreement expressly prohibits customers from buying, selling, or **transferring API keys to or from a third party**. Handing builder-account keys to validation subjects therefore cannot be treated as an implementation detail common to the three-provider allowlist.

This does not invalidate the app's no-backend architecture, but it blocks the stated three-subject validation procedure until the credential-ownership model is reconciled. Safe routes include genuine participant-owned keys/accounts, a provider-supported project/member credential mechanism whose terms permit the setup, or narrowing the validation provider. A developer proxy would be a different architecture and is not silently authorized.

Evidence:

- Spine Structural Seed: “The user's own provider account”; scope: BYOK/no backend.
- PRD §4.10 and §7 repeat user-owned provider/account semantics.
- PRD §8 says keys are issued from the builder's single provider account and subjects need no account.
- OpenAI Services Agreement, restriction 3.3(g): https://cdn.openai.com/osa/openai-services-agreement.pdf

### V-2 — MEDIUM — Gemini's tier warning is not accurate for this Spain/EEA validation context, and the terms require Paid Services for an API client

AD-10 says key entry states that “a free-tier key may be used for training” and leaves the tier entirely to the user. Google's live Gemini terms are region-sensitive: generally, Unpaid Services content may be used to improve products, but for users in the **EEA, Switzerland, or UK**, Paid-Services data treatment applies even to unpaid quota. Separately and more decisively, those terms say an API Client made available to users in those regions may use **only Paid Services**. Since this project and validation context are in Spain, the architecture should not frame free-vs-paid as merely a user privacy choice for Gemini; paid-service eligibility is a use restriction for the client.

The chosen allowlist entry already says “Gemini (paid API),” so the implementation direction is sound; AD-10's generic warning and “key's tier is the user's” rule are the stale/overbroad pieces.

Primary sources:

- Gemini API Additional Terms, effective 2026-03-23: https://ai.google.dev/gemini-api/terms
- Gemini billing/data-handling guide: https://ai.google.dev/gemini-api/docs/billing

### V-3 — LOW — The Play API-36 statement is correct but operationally irrelevant to the committed distribution topology

The stack accurately states that new apps and updates submitted to Google Play must target API 36 from 2026-08-31, and accurately labels any API-37/August-2027 date as a projection. However, AD-18 rules out store distribution, so Play policy is not a requirement for this build. It should remain context/deferred rationale rather than evidence that targetSdk 36 is required by the validation topology.

Primary source: https://support.google.com/googleplay/android-developer/answer/11926878

### V-4 — LOW — “No backend / developers receive nothing” is traceable, but should not be read as “providers collect nothing” or “the builder learns nothing”

The no-backend choice is strongly and consistently traceable to PRD FR-28, §5.1 and §7: no proxy, app account, remote allowlist, telemetry, or developer data endpoint. AD-7/AD-12 implement that boundary coherently. But provider terms permit operational metadata and limited abuse-monitoring retention, and the PRD annex expects builder-visible provider-side cost attribution. Thus “developers receive nothing” is valid only for **app payloads and app telemetry sent by this app**; it is not a statement that the provider account exposes no billing/usage metadata to its owner.

Primary example (Gemini Paid Services explicitly distinguishes prompts/responses from account, billing and usage details): https://ai.google.dev/gemini-api/terms

## Technology/version verification matrix

| Committed claim | Result | Evidence |
| --- | --- | --- |
| Flutter 3.47.1 / Dart 3.13.1; Java 17; Flutter min API 24 | Supported by Flutter's canonical release metadata and 3.47 release notes | https://storage.googleapis.com/flutter_infra_release/releases/releases_linux.json ; https://flutter.dev/blog/whats-new-in-flutter-3-47 |
| targetSdk 36 / Android 16; Play submission floor on 2026-08-31 | Verified; API-37/2027 correctly labelled projection | https://support.google.com/googleplay/android-developer/answer/11926878 |
| SpeechRecognizer on-device methods API 31; recognition-support/model-download methods API 33 | Verified in Android reference/API history | https://developer.android.com/reference/android/speech/SpeechRecognizer ; https://developer.android.com/sdk/api_diff/33/changes/android.speech.SpeechRecognizer |
| Notification channel behavior immutable after creation; user retains control | Verified | https://developer.android.com/develop/ui/views/notifications/channels ; https://developer.android.com/reference/android/app/NotificationChannel |
| drift 2.34.3 / drift_flutter 0.3.1; triggers only in `.drift` files | Verified | https://pub.dev/packages/drift ; https://pub.dev/packages/drift_flutter ; https://pub.dev/documentation/drift/latest/drift/Trigger-class.html |
| flutter_riverpod 3.4.2 | Verified | https://pub.dev/packages/flutter_riverpod |
| camera 0.12.0+2, flutter.dev publisher | Verified | https://pub.dev/packages/camera |
| google_mlkit_face_detection 0.15.1; community, not Google | Verified. The 32-bit/16-KB workaround remains fragile and should stay deferred/guarded as written | https://pub.dev/packages/google_mlkit_face_detection ; https://issuetracker.google.com/issues/458518879 ; https://developer.android.com/guide/practices/page-sizes |
| saf_util 3.1.0 has no read/write; saf_stream 4.0.1 supplies it | Verified | https://pub.dev/packages/saf_util ; https://pub.dev/packages/saf_stream |
| flutter_secure_storage 11.0.0 and explicit Android cipher choice | Version verified; migration/default behavior warning remains justified | https://pub.dev/packages/flutter_secure_storage ; https://pub.dev/packages/flutter_secure_storage/changelog |
| uuid 4.6.0, UUIDv7/RFC 9562 support | Verified | https://pub.dev/packages/uuid |
| Kotlin 2.4.0 in Flutter 3.47 Android template | Supported by Flutter 3.47 release material and Kotlin releases | https://flutter.dev/blog/whats-new-in-flutter-3-47 ; https://kotlinlang.org/docs/releases.html |
| Gemma 4 E4B LiteRT-LM size/memory numbers | Supported by the named model card; correctly deferred rather than bound as shipped technology | https://huggingface.co/litert-community/gemma-4-E4B-it-litert-lm |

## Traceability conclusion

- **BYOK / no backend:** clearly inherited from PRD FR-28, §5.1 and §7; architecture is faithful.
- **Local-first:** clearly inherited from PRD §7 and FR-30; architecture preserves the distinction between local app data, user-selected SAF export, and explicit Slicer egress.
- **Managed path:** correctly interface-only and deferred.
- **Major gap:** the PRD itself contains the user-owned-account versus builder-issued-key contradiction. The spine inherited only the former into its topology and therefore does not warn implementers that the validation annex cannot be executed uniformly across providers.

## Acceptance condition

Resolve V-1 in the source PRD/validation annex and cascade the chosen credential-ownership rule into the spine. Correct the Gemini/EEA wording in AD-10 or bind Gemini to Paid Services explicitly. No stack-version refresh is otherwise required as of 2026-08-27.

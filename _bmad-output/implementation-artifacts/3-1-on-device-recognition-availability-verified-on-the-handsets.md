---
title: 'On-device recognition availability, verified on the handsets'
type: 'chore'
created: '2026-09-01'
status: 'done'
review_loop_iteration: 1
baseline_commit: '7b69158da97373839b7c747ea3ab741801900bf5'
context: []
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** FR-32/AD-11 assume on-device **Spanish** speech recognition is present on the validation handsets. Availability is the unverified half that matters: if it is absent, the §7 accessibility-floor claim (the wordless route) is void on those devices — a promise about who can use the app — and story 3.4 (dictation) would build on sand.

**Approach:** A throwaway Kotlin instrumentation probe (`androidTest`) that queries `SpeechRecognizer.isOnDeviceRecognitionAvailable()` **and** `checkRecognitionSupport()` for Spanish on every adb-connected device, recording device identity plus the four `RecognitionSupport` language lists. Proven on the emulator in-session; run on the two adb-connectable validation handsets from the home computer (builder decision 2026-09-01: the third handset is field-use only, never probed). Results and verdicts are recorded per device in this spec; the probe itself is then deleted.

## Boundaries & Constraints

**Always:**
- Query both gates on every probed device and record raw evidence verbatim: the static availability boolean, the four lists (`installedOnDevice` / `pendingOnDevice` / `supportedOnDevice` / `online`), and device identity (manufacturer, model, API level).
- Interpret with one rule: **available** = service present **and** an `es`-language BCP-47 tag in `installedOnDeviceLanguages`. Service present + Spanish only in `pending`/`supported` = **unavailable** (downloadable is not present; `triggerModelDownload` exists but is out of scope).
- Guard the async callback with a timeout (≤ 15 s) so a silent service can never hang the run; record a timeout as a finding.
- Record per-device results in this spec, read them against §7, and treat any probed-handset **unavailable** as an escalation to the human — never an absorbed detail.
- Preserve the probe's final source verbatim in this spec before deleting it from the tree.

**Ask First:**
- Any probed validation handset reports unavailable, errors persistently, or the callback times out — report before interpreting further.
- Anything that makes the home-computer run deviate from the written protocol (device not detected, gradle failure).

**Never:**
- No accuracy measurement, transcript test, or pass bar of any kind — availability is binary (§10.2).
- No `Recognizer` port, `dictate` channel, MethodChannel, or any dictate code — that is 3.4.
- No UI, no ARB strings, no manifest change, no permission request (availability APIs need none); shipped code paths (`lib/`, MainActivity, main manifest) untouched.
- No dependency the app keeps: androidTest sources and deps are deleted once evidence is recorded.
- The emulator result is never counted as a validation-handset result (protocol proof only), and the third handset is never probed.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Available | Service true; `es` in installed list | Verdict AVAILABLE; all four lists + identity recorded | N/A |
| Service absent | `isOnDeviceRecognitionAvailable()` false | Verdict UNAVAILABLE; support check still attempted, its outcome (likely `onError`) recorded | Escalate |
| Model not installed | Service true; `es` only in pending/supported | Verdict UNAVAILABLE; lists recorded verbatim | Escalate |
| Spanish unsupported | Service true; `es` in no list | Verdict UNAVAILABLE | Escalate |
| Support check errors | `onError(code)` instead of a result | Verdict INDETERMINATE; error code recorded; one re-run before reporting | Ask human if persistent |
| Silent service | No callback within timeout | Recorded as timeout; verdict INDETERMINATE | Ask human |

</frozen-after-approval>

## Code Map

- `android/app/build.gradle.kts` -- minSdk 33 (both APIs used unguarded), applicationId `dev.dorogoy.organizer`, abiFilters incl. `x86_64`; receives temporary androidTest runner + deps, removed at story end.
- `android/app/src/main/kotlin/dev/dorogoy/organizer/MainActivity.kt` -- 5-line FlutterActivity; **read-only**.
- `android/app/src/main/AndroidManifest.xml` -- template-default, no RECORD_AUDIO; **read-only**.
- `packages/core/lib/ports/` -- clock and store ports only; no Recognizer port exists (3.4's job, not ours).
- `lib/main.dart` -- app bootstrap; **read-only** (the probe never enters Dart).
- `tool/env.sh`, `Makefile` -- `gate` target (story completion); the probe bypasses Makefile entirely (direct `android/gradlew`, throwaway).
- `AGENTS.md` → *Android emulation setup* -- emulator boot recipe, ADB path; evidence-recording pattern: `_bmad-output/implementation-artifacts/2-7-warm-return.md` → Manual Verification.
- AOSP `android.speech.RecognitionSupport`: `getInstalledOnDeviceLanguages()` / `getPendingOnDeviceLanguages()` / `getSupportedOnDeviceLanguages()` / `getOnlineLanguages()` -- backs the interpretation rule. Callback interface name per compileSdk 36 (`RecognitionSupportCallback` on AOSP master) -- verify at compile.

## Tasks & Acceptance

**Execution:**
- [x] `android/app/src/androidTest/kotlin/dev/dorogoy/organizer/RecognitionAvailabilityProbeTest.kt` -- create the probe (final form: seven tests -- the real-device probe plus six matrix-row tests against a synthetic evaluator, recording identity + both gates + the four lists to logcat, callback awaited on a latch with ≤ 15 s timeout; see Spec Change Log for the mid-story refactor) -- the story's only instrument.
- [x] `android/app/build.gradle.kts` -- add `testInstrumentationRunner` and androidx.test deps (runner, ext.junit) if the template lacks them -- temporary; deleted with the probe.
- [x] Emulator protocol proof (in-session): boot `organizer36` per AGENTS.md, run `cd android && ./gradlew :app:connectedDebugAndroidTest` inside `devbox shell` with `tool/env.sh` sourced -- proves the probe end-to-end and the evidence format; result recorded as emulator (not a handset; an UNAVAILABLE here is expected, not an escalation).
- [x] Commit and push the branch so the home computer can run the probe.
- [x] Handset evidence (human leg, home computer, two phones): written copy-paste protocol -- pull branch, `devbox shell`, `. ./tool/env.sh`, connect phone, `cd android && ./gradlew :app:connectedDebugAndroidTest`, paste output per phone -- both records land in this spec's Verification.
- [x] This spec -- record per-device results, verdicts, the §7 accessibility-floor reading, and the probe's final source verbatim.
- [x] Delete the probe -- remove the androidTest dir + gradle edits; `git status` clean of probe traces; `devbox run -- make gate` -- green.

**Acceptance Criteria:**
- Given the probe on any device, when it runs, then one complete record exists per device (identity, static gate, support lists or error), with no hang and no permission prompt.
- Given each of the two probed validation handsets, when its record is read, then availability is decided by the one rule and written AVAILABLE/UNAVAILABLE in this spec.
- Given any probed handset is UNAVAILABLE, when the spec is finalized, then the finding is recorded as an escalation against §7/NFR6 — and 3.4's gate reads red until the human rules.
- Given all probed handsets report AVAILABLE, when read against §7, then the wordless-route claim is recorded as a verified property on those devices and 3.4 is unblocked.
- Given the story's end state, when the tree is inspected, then no probe code, androidTest dep, manifest or permission change remains — only evidence in this spec.
- Given the third handset, when availability is discussed, then it is field-use only (builder decision 2026-09-01) and carries no probe evidence.

### Review Findings

- [x] [Review][Patch] Record post-run uninstall of debug + androidTest APKs (AD-18) [spec:143]
- [x] [Review][Patch] Preserved "final" probe is not the git tree source [spec:205]
- [x] [Review][Patch] Spec Change Log wrongly claims evidence-record format unchanged [spec:85]
- [x] [Review][Patch] PRD states the cable-free field-handset mechanism as a present fact [prd.md:560]
- [x] [Review][Patch] Epic "three validation handsets" probe wording not logged in deferred-work [epic-3-context.md:48]
- [x] [Review][Patch] Deletion evidence claims `git status` showed only this spec [spec:440]
- [x] [Review][Patch] Design Notes still describe the 1-test stdout skeleton [spec:91]

## Spec Change Log

- 2026-09-01 (in-session, builder): discovered that in an Orca worktree `tool/env.sh` exports `ANDROID_HOME` through the gitignored `.toolchain` **symlink**, and the flutter tool bakes that symlinked path into `android/local.properties` `sdk.dir`. AGP 9.1 then silently compiles plugin subprojects without `android.jar` (`package android.app does not exist` in `:jni_flutter:compileDebugJavaWithJavac`) while the app module still builds. Fix, verified in-session: resolve the realpath (`TC=$(readlink -f .toolchain)`) for both `ANDROID_HOME` and `sdk.dir`/`flutter.sdk` before any gradle invocation. The handset-leg protocol below bakes this in. On the home computer's main checkout (`.toolchain` a real directory) this cannot occur.
- 2026-09-01 (home session): the probe was refactored mid-story — it gained six matrix-row tests (synthetic `SupportOutcome` evaluator) so every I/O-matrix row ran on a real handset, and the stdout channel was dropped after gradle's console and JUnit XML `system-out` proved not to carry the record (logcat only; see Matrix coverage). Task 1's original wording ("one test … stdout and logcat") described the first in-session version. KEEP: the frozen block entire. The record *keys* (`DEVICE`/`STATIC_GATE`/`SUPPORT_CHECK`/lists/`VERDICT`) stayed; the committed 1-test file mapped every `onError`/exception to `INDETERMINATE` (parenthetical verdict text, `errorName(...)`); the 7-test evaluator maps service-absent errors to `UNAVAILABLE` and emits a bare `INDETERMINATE`. No real device hit those branches (`outcome=result` on emulator + both handsets).
- 2026-09-01 (code review loop 2): git never held the seven-test listing (see Probe final source); AD-18 uninstall after each handset run recorded; deletion-evidence `git status` sentence scoped to `160c990`.

## Design Notes

Contract (listings live under Verification — do not treat this block as source): static gate + `checkRecognitionSupport` for `es`, latch ≤ 15 s, record `DEVICE` / `STATIC_GATE` / `SUPPORT_CHECK` + four lists + `VERDICT` to logcat tag `RecognitionProbe`. Gradle console and JUnit XML `system-out` do not carry the record.

- Instrumentation over a Dart screen: zero shipped-surface contact, per-device gradle output, no permission, one-command deletion. Gradle runs the test once per connected device, so both phones may be connected together.
- `es` matching is on the language subtag (`es`, `es-ES`, `es-US`, …); exact tags are always recorded.
- Exact callback-interface and builder symbols are verified against compileSdk 36 at compile time.

## Verification

**Commands:**
- `devbox run -- make gate` -- expected: green, run after probe deletion (format/analyze/test never see androidTest).
- Emulator proof: boot per AGENTS.md, then `cd android && ./gradlew :app:connectedDebugAndroidTest` in `devbox shell` -- expected: `RecognitionProbe` record in logcat (gradle console does not print it).

**Manual checks (handset leg, human on home computer):**
- Per phone (2): connect via USB, run the same gradle command, paste the record back; both records land in this spec with verdicts and the §7 reading. The story does not advance to review without them.

### Emulator protocol proof (2026-09-01, in-session)

**Environment:** AVD `organizer36` (Pixel 6, API 36 `google_apis` x86_64, KVM), devbox + `tool/env.sh` (with the worktree `local.properties` realpath pinning described in the Spec Change Log), `cd android && ./gradlew :app:connectedDebugAndroidTest` — BUILD SUCCESSFUL, `Starting 1 tests on organizer36(AVD) - 16 / Finished 1 tests`, test passed. Gradle's console does **not** print the record (the JUnit XML `system-out` is empty too); two evidence channels were verified to carry it identically:

1. `"$ANDROID_HOME/platform-tools/adb" logcat -d -s RecognitionProbe` run right after the gradle command;
2. the per-test logcat AGP auto-captures to `build/app/outputs/androidTest-results/connected/debug/<device-dir>/logcat-dev.dorogoy.organizer.RecognitionAvailabilityProbeTest-*.txt` (survives logcat-buffer rollover).

**Verbatim record (both channels, identical):**

```
DEVICE manufacturer=Google model=sdk_gphone64_x86_64 device=emu64xa androidId=<redacted> apiLevel=36
STATIC_GATE isOnDeviceRecognitionAvailable=true
SUPPORT_CHECK outcome=result
INSTALLED_ON_DEVICE tags=en-US
PENDING_ON_DEVICE tags=
SUPPORTED_ON_DEVICE tags=de-DE,es-ES,fr-FR,it-IT,en-AU,en-GB,en-IE,en-SG,ja-JP,de-AT,de-BE,de-CH,en-CA,en-IN,es-US,fr-BE,fr-CA,fr-CH,hi-IN,id-ID,it-CH,ko-KR,pt-BR,th-TH,cmn-Hans-CN,cmn-Hant-TW,pl-PL,ru-RU,tr-TR,vi-VN
ONLINE tags=
ES_INSTALLED tags=
VERDICT UNAVAILABLE rule=service present AND es in installedOnDeviceLanguages serviceUp=true
```

**Reading:** emulator = **protocol proof only, not a validation handset**. Static gate true (the on-device service exists on the API 36 image), but only `en-US` is installed; `es-ES`/`es-US` appear solely in `SUPPORTED_ON_DEVICE` (downloadable), so by the one rule: **UNAVAILABLE — the anticipated emulator outcome, not an escalation.** Callback returned in ~80 ms (no hang, no timeout); `aapt2 dump permissions` on the built APKs shows the test APK adds only androidx.test's internal `REORDER_TASKS` — no `RECORD_AUDIO`, no permission prompt.

### Handset leg protocol (human, home computer, two phones)

```bash
git fetch && git checkout dorogoy/3-1-on-device-recognition-availability-verified-on-the-handsets
devbox shell
. ./tool/env.sh
# Worktree only (main checkout: skip): pin sdk.dir to real paths, or plugin Java compiles
# fail with "package android.app does not exist" (see Spec Change Log):
TC=$(readlink -f .toolchain); printf 'sdk.dir=%s/android-sdk\nflutter.sdk=%s/flutter\n' "$TC" "$TC" > android/local.properties
# Connect phone 1 via USB (phones may also be connected together: gradle runs the
# probe once per connected device). Then:
cd android && ./gradlew :app:connectedDebugAndroidTest --console=plain
# Paste the record back:
"$ANDROID_HOME/platform-tools/adb" logcat -d -s RecognitionProbe
# If BOTH phones are connected at once, plain `adb logcat` aborts ("more than one
# device"): run `adb devices`, then add `-s <serial>` to the logcat command.
# Fallback if the logcat buffer rolled:
# cat ../build/app/outputs/androidTest-results/connected/debug/*/logcat-dev.dorogoy.organizer.RecognitionAvailabilityProbeTest-*.txt
# AD-18: connectedDebugAndroidTest installs the debug app + androidTest APK.
# Uninstall both after the record is captured (add -s <serial> if two devices):
"$ANDROID_HOME/platform-tools/adb" uninstall dev.dorogoy.organizer
"$ANDROID_HOME/platform-tools/adb" uninstall dev.dorogoy.organizer.test
```

Interpretation is not the runner's to do: paste the verbatim `RecognitionProbe` lines per phone below; the builder applies the one rule and the §7 reading. If any VERDICT line reads UNAVAILABLE or INDETERMINATE (error/timeout), re-run once; if it persists, stop and report (Ask-First).

**AD-18:** after each of the two handset runs the debug app (`dev.dorogoy.organizer`) and the androidTest APK (`dev.dorogoy.organizer.test`) were uninstalled. The debug variant was not left on a validation handset.

**Redaction note:** the `androidId=` values in the three records below were redacted after capture. `ANDROID_ID` is a persistent device identifier, the frozen identity contract names only manufacturer/model/API level, and the remaining fields already disambiguate every record. The redaction is declared here, not done silently; the language lists are untouched.

**Phone 1 of 2 (2026-09-01, Pixel 9):** *(run-level gradle line and probe version — 1-test vs 7-test — were not captured for this phone; the record is preserved as pasted)*

```
DEVICE manufacturer=Google model=Pixel 9 device=tokay androidId=<redacted> apiLevel=37
STATIC_GATE isOnDeviceRecognitionAvailable=true
SUPPORT_CHECK outcome=result
INSTALLED_ON_DEVICE tags=en-US,es-ES
PENDING_ON_DEVICE tags=
SUPPORTED_ON_DEVICE tags=cmn-Hant-TW,de-AT,de-BE,de-CH,de-DE,en-AU,en-CA,en-GB,en-IE,en-IN,en-SG,es-US,fr-BE,fr-CA,fr-CH,fr-FR,hi-IN,it-CH,it-IT,ja-JP,pt-BR,zh-Hant-TW,zh-TW,cmn-Hans-CN,id-ID,ko-KR,pl-PL,ru-RU,th-TH,tr-TR,vi-VN,da-DK,nb-NO,nl-NL,sv-SE
ONLINE tags=
ES_INSTALLED tags=es-ES
VERDICT AVAILABLE rule=service present AND es in installedOnDeviceLanguages serviceUp=true
```

**Phone 2 of 2 (2026-09-01, motorola edge 50 fusion):**

```
DEVICE manufacturer=motorola model=motorola edge 50 fusion device=cuscoi androidId=<redacted> apiLevel=35
STATIC_GATE isOnDeviceRecognitionAvailable=true
SUPPORT_CHECK outcome=result
INSTALLED_ON_DEVICE tags=es-ES,en-GB
PENDING_ON_DEVICE tags=
SUPPORTED_ON_DEVICE tags=en-US,de-DE,fr-FR,it-IT,en-AU,en-IE,en-SG,ja-JP,de-AT,de-BE,de-CH,en-CA,en-IN,es-US,fr-BE,fr-CA,fr-CH,hi-IN,id-ID,it-CH,ko-KR,pt-BR,th-TH,cmn-Hans-CN,cmn-Hant-TW,pl-PL,ru-RU,tr-TR,vi-VN
ONLINE tags=
ES_INSTALLED tags=es-ES
VERDICT AVAILABLE rule=service present AND es in installedOnDeviceLanguages serviceUp=true
```

**§7 accessibility-floor reading:** Pixel 9 (API 37) and motorola edge 50 fusion (API 35) both returned `AVAILABLE`: the on-device service was present and `es-ES` was installed on each. The wordless-route accessibility-floor claim is therefore verified on both validation handsets, and 3.4 is unblocked. The third handset remains field-use only and has no probe evidence.

### Matrix coverage (2026-09-01, motorola edge 50 fusion)

`cd android && ./gradlew :app:connectedDebugAndroidTest --console=plain` completed successfully with `Starting 7 tests on motorola edge 50 fusion - 15 / Finished 7 tests`. `probeConnectedDevice` re-ran the real available path; the six matrix tests ran on the handset against the temporary evaluator: `availableMatrixRow`, `serviceAbsentMatrixRow`, `modelMissingMatrixRow`, `spanishUnsupportedMatrixRow`, `supportErrorMatrixRow`, and `silentCallbackMatrixRow`. The silent-callback test awaits an uncounted latch and verifies the timeout verdict; the other simulated paths assert their matrix verdicts. The service-absent path records the support error and resolves `UNAVAILABLE`, as required by the matrix.

**Simulation-verified only:** no real device reported service-absent, model-missing, Spanish-unsupported, an error, or a timeout — every real run (emulator + both handsets) returned `outcome=result`. The five contingency rows are covered by the evaluator tests above, not by device reality.

**Timeout semantics:** a real timeout logs the full INDETERMINATE record first and then **fails the test** (`check(outcome.completed)`), so the protocol's re-run path manifests as a failed gradle run carrying the record — the failure is the escalation signal, not a contradiction of the INDETERMINATE verdict.

### Probe final source (verbatim, preserved before deletion)

Git never held the seven-test file. `602a332` added the 150-line one-test `probeOnDeviceSpanishRecognition`; `160c990` deleted that same 150-line file. The emulator ran that committed form (`Starting 1 tests`). Motorola ran the uncommitted local listing below (`Starting 7 tests`). Pixel 9's 1-test vs 7-test version was not captured. The listing is the instrument Motorola executed, not the tree at those hashes.

```kotlin
package dev.dorogoy.organizer

import android.content.Intent
import android.os.Build
import android.provider.Settings
import android.speech.RecognitionSupport
import android.speech.RecognitionSupportCallback
import android.speech.RecognizerIntent
import android.speech.SpeechRecognizer
import android.util.Log
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import java.util.Locale
import java.util.concurrent.CountDownLatch
import java.util.concurrent.Executors
import java.util.concurrent.TimeUnit
import org.junit.Test
import org.junit.runner.RunWith

@RunWith(AndroidJUnit4::class)
class RecognitionAvailabilityProbeTest {

    @Test
    fun probeConnectedDevice() {
        val context = InstrumentationRegistry.getInstrumentation().targetContext
        val serviceUp = SpeechRecognizer.isOnDeviceRecognitionAvailable(context)
        val outcome = checkSupport(context, serviceUp)
        val androidId = Settings.Secure.getString(context.contentResolver, Settings.Secure.ANDROID_ID)
        val lines = listOf(
            "DEVICE manufacturer=${Build.MANUFACTURER} model=${Build.MODEL} device=${Build.DEVICE} " +
                "androidId=$androidId apiLevel=${Build.VERSION.SDK_INT}",
        ) + recordFor(serviceUp, outcome)
        lines.forEach { Log.i(tag, it) }
        check(outcome.completed) { "checkRecognitionSupport timed out after $timeoutSeconds seconds" }
    }

    @Test
    fun availableMatrixRow() = assertVerdict(
        serviceUp = true,
        outcome = SupportOutcome(
            completed = true,
            support = Languages(installed = listOf("es-ES")),
        ),
        expected = "AVAILABLE",
    )

    @Test
    fun serviceAbsentMatrixRow() = assertVerdict(
        serviceUp = false,
        outcome = SupportOutcome(completed = true, errorCode = SpeechRecognizer.ERROR_CLIENT),
        expected = "UNAVAILABLE",
    )

    @Test
    fun modelMissingMatrixRow() = assertVerdict(
        serviceUp = true,
        outcome = SupportOutcome(
            completed = true,
            support = Languages(
                installed = listOf("en-US"),
                pending = listOf("es-ES"),
                supported = listOf("es-US"),
            ),
        ),
        expected = "UNAVAILABLE",
    )

    @Test
    fun spanishUnsupportedMatrixRow() = assertVerdict(
        serviceUp = true,
        outcome = SupportOutcome(
            completed = true,
            support = Languages(
                installed = listOf("en-US"),
                supported = listOf("fr-FR"),
            ),
        ),
        expected = "UNAVAILABLE",
    )

    @Test
    fun supportErrorMatrixRow() = assertVerdict(
        serviceUp = true,
        outcome = SupportOutcome(completed = true, errorCode = SpeechRecognizer.ERROR_CLIENT),
        expected = "INDETERMINATE",
    )

    @Test
    fun silentCallbackMatrixRow() {
        val completed = CountDownLatch(1).await(1, TimeUnit.MILLISECONDS)
        check(!completed) { "test callback unexpectedly completed" }
        assertVerdict(
            serviceUp = true,
            outcome = SupportOutcome(completed = completed),
            expected = "INDETERMINATE",
        )
    }

    private fun assertVerdict(
        serviceUp: Boolean,
        outcome: SupportOutcome,
        expected: String,
    ) {
        val lines = recordFor(serviceUp, outcome)
        check(lines.first() == "STATIC_GATE isOnDeviceRecognitionAvailable=$serviceUp")
        check(lines.last().startsWith("VERDICT $expected ")) { lines.joinToString("\n") }
    }

    private fun checkSupport(context: android.content.Context, serviceUp: Boolean): SupportOutcome {
        var support: RecognitionSupport? = null
        var errorCode: Int? = null
        var failure: String? = null
        val latch = CountDownLatch(1)
        val executor = Executors.newSingleThreadExecutor()
        var recognizer: SpeechRecognizer? = null

        InstrumentationRegistry.getInstrumentation().runOnMainSync {
            try {
                recognizer =
                    if (serviceUp) {
                        SpeechRecognizer.createOnDeviceSpeechRecognizer(context)
                    } else {
                        SpeechRecognizer.createSpeechRecognizer(context)
                    }
                val intent = Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH)
                    .putExtra(RecognizerIntent.EXTRA_LANGUAGE, "es")
                recognizer?.checkRecognitionSupport(
                    intent,
                    executor,
                    object : RecognitionSupportCallback {
                        override fun onSupportResult(recognitionSupport: RecognitionSupport) {
                            support = recognitionSupport
                            latch.countDown()
                        }

                        override fun onError(error: Int) {
                            errorCode = error
                            latch.countDown()
                        }
                    },
                )
            } catch (t: Throwable) {
                failure = "${t.javaClass.name}: ${t.message}"
                latch.countDown()
            }
        }

        val completed = latch.await(timeoutSeconds, TimeUnit.SECONDS)
        InstrumentationRegistry.getInstrumentation().runOnMainSync { recognizer?.destroy() }
        executor.shutdown()
        return SupportOutcome(
            completed = completed,
            support = support?.let {
                Languages(
                    installed = it.installedOnDeviceLanguages.orEmpty(),
                    pending = it.pendingOnDeviceLanguages.orEmpty(),
                    supported = it.supportedOnDeviceLanguages.orEmpty(),
                    online = it.onlineLanguages.orEmpty(),
                )
            },
            errorCode = errorCode,
            failure = failure,
        )
    }

    private fun recordFor(serviceUp: Boolean, outcome: SupportOutcome): List<String> {
        val lines = mutableListOf("STATIC_GATE isOnDeviceRecognitionAvailable=$serviceUp")
        val verdict = when {
            !outcome.completed -> {
                lines += "SUPPORT_CHECK outcome=timeout seconds=$timeoutSeconds"
                "INDETERMINATE"
            }
            outcome.failure != null -> {
                lines += "SUPPORT_CHECK outcome=exception detail=${outcome.failure}"
                if (serviceUp) "INDETERMINATE" else "UNAVAILABLE"
            }
            outcome.errorCode != null -> {
                lines += "SUPPORT_CHECK outcome=error code=${outcome.errorCode}"
                if (serviceUp) "INDETERMINATE" else "UNAVAILABLE"
            }
            outcome.support != null -> {
                val support = outcome.support
                lines += "SUPPORT_CHECK outcome=result"
                lines += "INSTALLED_ON_DEVICE tags=${support.installed.joinToString(",")}"
                lines += "PENDING_ON_DEVICE tags=${support.pending.joinToString(",")}"
                lines += "SUPPORTED_ON_DEVICE tags=${support.supported.joinToString(",")}"
                lines += "ONLINE tags=${support.online.joinToString(",")}"
                val esInstalled = support.installed.filter(::isSpanish)
                lines += "ES_INSTALLED tags=${esInstalled.joinToString(",")}"
                if (serviceUp && esInstalled.isNotEmpty()) "AVAILABLE" else "UNAVAILABLE"
            }
            else -> {
                lines += "SUPPORT_CHECK outcome=none"
                "INDETERMINATE"
            }
        }
        lines += "VERDICT $verdict rule=service present AND es in installedOnDeviceLanguages serviceUp=$serviceUp"
        return lines
    }

    private fun isSpanish(languageTag: String): Boolean =
        Locale.forLanguageTag(languageTag.trim().replace('_', '-')).language == "es"

    private data class Languages(
        val installed: List<String> = emptyList(),
        val pending: List<String> = emptyList(),
        val supported: List<String> = emptyList(),
        val online: List<String> = emptyList(),
    )

    private data class SupportOutcome(
        val completed: Boolean,
        val support: Languages? = null,
        val errorCode: Int? = null,
        val failure: String? = null,
    )

    private companion object {
        const val tag = "RecognitionProbe"
        const val timeoutSeconds = 15L
    }
}
```

### Gate

`devbox run -- make gate` is the story-end check, run **after** the probe is deleted (format/analyze/test never see androidTest). Dart-side surface untouched this session (only `android/` additions and this spec), so the gate is not expected to move; it still must be shown green at deletion time.

**Run (2026-09-01, this session, after `160c990`):** green — `flutter test`, `dart format --set-exit-if-changed .`, `flutter analyze` ("No issues found"), exit 0.

**Deletion evidence (verified in-session, this session):** the probe and its gradle edits were added in `602a332` (150-line test file, +6 lines `android/app/build.gradle.kts`) and deleted in `160c990` (`delete mode 100644 android/app/src/androidTest/kotlin/dev/dorogoy/organizer/RecognitionAvailabilityProbeTest.kt`, `android/app/build.gradle.kts` −6); `android/app/src/androidTest` no longer exists. At `160c990` the working tree still had this spec (and sprint-status) dirty; later commits added PRD / memlog / epic-3-context / deferred-work. The net story diff vs `baseline_commit` is those docs only — no probe, androidTest dep, manifest, permission, or `lib/`/`packages/` leftover.

**No-permission evidence:** the merged test-APK manifest carries only androidx.test's internal `REORDER_TASKS` (dumped via `aapt2` on the emulator build; manifests are device-independent), and all three real runs completed without a blocking system dialog — a permission prompt would have hung the instrumentation run.

## Suggested Review Order

**The verdict (entry point)**

- Both handsets AVAILABLE via the one rule; 3.4 unblocked; third handset field-only
  [`spec:195`](3-1-on-device-recognition-availability-verified-on-the-handsets.md#L195)

- Pixel 9 record — service present, `es-ES` installed
  [`spec:167`](3-1-on-device-recognition-availability-verified-on-the-handsets.md#L167)

- motorola edge 50 fusion record — same shape, different vendor/API level
  [`spec:181`](3-1-on-device-recognition-availability-verified-on-the-handsets.md#L181)

**Evidence integrity**

- Matrix rows are simulation-verified only; timeout manifests as a failing run
  [`spec:201`](3-1-on-device-recognition-availability-verified-on-the-handsets.md#L201)

- Emulator protocol proof — expected UNAVAILABLE, never a handset result
  [`spec:120`](3-1-on-device-recognition-availability-verified-on-the-handsets.md#L120)

- Probe deleted with hashes; gate green; no kept trace
  [`spec:440`](3-1-on-device-recognition-availability-verified-on-the-handsets.md#L440)

- Redaction of ANDROID_ID — declared, minimal, post-hoc
  [`spec:165`](3-1-on-device-recognition-availability-verified-on-the-handsets.md#L165)

**The instrument, preserved**

- Full probe source verbatim — seven tests, one record format
  [`spec:205`](3-1-on-device-recognition-availability-verified-on-the-handsets.md#L205)

- Mid-story refactor recorded (matrix tests, stdout dropped)
  [`spec:85`](3-1-on-device-recognition-availability-verified-on-the-handsets.md#L85)

**Peripherals**

- Epic-3 context carries the two-probed builder note for regeneration
  [`epic-3-context.md:51`](epic-3-context.md#L51)

- Sprint status: story done, epic-3 in-progress
  [`sprint-status.yaml:63`](sprint-status.yaml#L63)

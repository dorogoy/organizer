---
title: 'On-device recognition availability, verified on the handsets'
type: 'chore'
created: '2026-09-01'
status: 'in-progress'
review_loop_iteration: 0
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
- [x] `android/app/src/androidTest/kotlin/dev/dorogoy/organizer/RecognitionAvailabilityProbeTest.kt` -- create the probe: one test recording identity + both gates + the four lists (or error/timeout) to instrumentation stdout and logcat, callback awaited on a latch with ≤ 15 s timeout -- the story's only instrument.
- [x] `android/app/build.gradle.kts` -- add `testInstrumentationRunner` and androidx.test deps (runner, ext.junit) if the template lacks them -- temporary; deleted with the probe.
- [x] Emulator protocol proof (in-session): boot `organizer36` per AGENTS.md, run `cd android && ./gradlew :app:connectedDebugAndroidTest` inside `devbox shell` with `tool/env.sh` sourced -- proves the probe end-to-end and the evidence format; result recorded as emulator (not a handset; an UNAVAILABLE here is expected, not an escalation).
- [x] Commit and push the branch so the home computer can run the probe.
- [ ] Handset evidence (human leg, home computer, two phones): written copy-paste protocol -- pull branch, `devbox shell`, `. ./tool/env.sh`, connect phone, `cd android && ./gradlew :app:connectedDebugAndroidTest`, paste output per phone -- both records land in this spec's Verification.
- [ ] This spec -- record per-device results, verdicts, the §7 accessibility-floor reading, and the probe's final source verbatim.
- [ ] Delete the probe -- remove the androidTest dir + gradle edits; `git status` clean of probe traces; `devbox run -- make gate` -- green.

**Acceptance Criteria:**
- Given the probe on any device, when it runs, then one complete record exists per device (identity, static gate, support lists or error), with no hang and no permission prompt.
- Given each of the two probed validation handsets, when its record is read, then availability is decided by the one rule and written AVAILABLE/UNAVAILABLE in this spec.
- Given any probed handset is UNAVAILABLE, when the spec is finalized, then the finding is recorded as an escalation against §7/NFR6 — and 3.4's gate reads red until the human rules.
- Given all probed handsets report AVAILABLE, when read against §7, then the wordless-route claim is recorded as a verified property on those devices and 3.4 is unblocked.
- Given the story's end state, when the tree is inspected, then no probe code, androidTest dep, manifest or permission change remains — only evidence in this spec.
- Given the third handset, when availability is discussed, then it is field-use only (builder decision 2026-09-01) and carries no probe evidence.

## Spec Change Log

- 2026-09-01 (in-session, builder): discovered that in an Orca worktree `tool/env.sh` exports `ANDROID_HOME` through the gitignored `.toolchain` **symlink**, and the flutter tool bakes that symlinked path into `android/local.properties` `sdk.dir`. AGP 9.1 then silently compiles plugin subprojects without `android.jar` (`package android.app does not exist` in `:jni_flutter:compileDebugJavaWithJavac`) while the app module still builds. Fix, verified in-session: resolve the realpath (`TC=$(readlink -f .toolchain)`) for both `ANDROID_HOME` and `sdk.dir`/`flutter.sdk` before any gradle invocation. The handset-leg protocol below bakes this in. On the home computer's main checkout (`.toolchain` a real directory) this cannot occur.

## Design Notes

Probe skeleton (final source preserved in Verification before deletion):

```kotlin
@Test fun probeOnDeviceSpanishRecognition() {
    val cx = InstrumentationRegistry.getInstrumentation().targetContext
    val serviceUp = SpeechRecognizer.isOnDeviceRecognitionAvailable(cx) // static, API 31
    val recognizer = SpeechRecognizer.createOnDeviceSpeechRecognizer(cx)
    val intent = Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH)
        .putExtra(RecognizerIntent.EXTRA_LANGUAGE, "es")
    val latch = CountDownLatch(1)
    recognizer.checkRecognitionSupport(intent, executor, callback(latch)) // API 33
    check(latch.await(15, TimeUnit.SECONDS)) { "checkRecognitionSupport timed out" }
    // record to stdout + Log.i: Build.MANUFACTURER / MODEL / VERSION.SDK_INT,
    //   serviceUp, installed/pending/supported/online lists or error code,
    //   "es installed: <tags>" verdict line
}
```

- Instrumentation over a Dart screen: zero shipped-surface contact, per-device gradle output, no permission, one-command deletion. Gradle runs the test once per connected device, so both phones may be connected together.
- `es` matching is on the language subtag (`es`, `es-ES`, `es-US`, …); exact tags are always recorded.
- Exact callback-interface and builder symbols are verified against compileSdk 36 at compile time; the skeleton above is the contract, not the literal API.

## Verification

**Commands:**
- `devbox run -- make gate` -- expected: green, run after probe deletion (format/analyze/test never see androidTest).
- Emulator proof: boot per AGENTS.md, then `cd android && ./gradlew :app:connectedDebugAndroidTest` in `devbox shell` -- expected: one complete probe record in the instrumentation output.

**Manual checks (handset leg, human on home computer):**
- Per phone (2): connect via USB, run the same gradle command, paste the record back; both records land in this spec with verdicts and the §7 reading. The story does not advance to review without them.

### Emulator protocol proof (2026-09-01, in-session)

**Environment:** AVD `organizer36` (Pixel 6, API 36 `google_apis` x86_64, KVM), devbox + `tool/env.sh`, `cd android && ./gradlew :app:connectedDebugAndroidTest` — BUILD SUCCESSFUL, `Starting 1 tests on organizer36(AVD) - 16 / Finished 1 tests`, test passed. Gradle's console does **not** print the record (the JUnit XML `system-out` is empty too); two evidence channels were verified to carry it identically:

1. `"$ANDROID_HOME/platform-tools/adb" logcat -d -s RecognitionProbe` run right after the gradle command;
2. the per-test logcat AGP auto-captures to `build/app/outputs/androidTest-results/connected/debug/<device-dir>/logcat-dev.dorogoy.organizer.RecognitionAvailabilityProbeTest-*.txt` (survives logcat-buffer rollover).

**Verbatim record (both channels, identical):**

```
DEVICE manufacturer=Google model=sdk_gphone64_x86_64 device=emu64xa androidId=2ad73fcf0dba1ab9 apiLevel=36
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
# Fallback if the logcat buffer rolled:
# cat ../build/app/outputs/androidTest-results/connected/debug/*/logcat-dev.dorogoy.organizer.RecognitionAvailabilityProbeTest-*.txt
```

Interpretation is not the runner's to do: paste the verbatim `RecognitionProbe` lines per phone below; the builder applies the one rule and the §7 reading. If any VERDICT line reads UNAVAILABLE or INDETERMINATE (error/timeout), re-run once; if it persists, stop and report (Ask-First).

**Phone 1 of 2 (pending):**

```
<paste record here>
```

**Phone 2 of 2 (pending):**

```
<paste record here>
```

**§7 accessibility-floor reading (filled once both handset records land):** pending.

### Probe final source (verbatim, preserved before deletion)

Deleted at story end; this is the exact tree state it ran with:

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

    private val tag = "RecognitionProbe"
    private val timeoutSeconds = 15L

    @Test
    fun probeOnDeviceSpanishRecognition() {
        val instrumentation = InstrumentationRegistry.getInstrumentation()
        val context = instrumentation.targetContext
        val lines = mutableListOf<String>()
        fun record(line: String) {
            lines += line
            Log.i(tag, line)
        }

        val androidId = try {
            Settings.Secure.getString(context.contentResolver, Settings.Secure.ANDROID_ID)
        } catch (t: Throwable) {
            "unreadable:${t.javaClass.simpleName}"
        }
        record(
            "DEVICE manufacturer=${Build.MANUFACTURER} model=${Build.MODEL} device=${Build.DEVICE} " +
                "androidId=$androidId apiLevel=${Build.VERSION.SDK_INT}",
        )

        val serviceUp = SpeechRecognizer.isOnDeviceRecognitionAvailable(context)
        record("STATIC_GATE isOnDeviceRecognitionAvailable=$serviceUp")

        var support: RecognitionSupport? = null
        var errorCode: Int? = null
        var failure: String? = null
        val latch = CountDownLatch(1)
        val executor = Executors.newSingleThreadExecutor()
        var recognizer: SpeechRecognizer? = null

        instrumentation.runOnMainSync {
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
        val outcomeSupport = support
        val outcomeError = errorCode
        val outcomeFailure = failure

        val verdict = when {
            !completed -> {
                record("SUPPORT_CHECK outcome=timeout seconds=$timeoutSeconds")
                "INDETERMINATE (no callback within ${timeoutSeconds}s — silent service)"
            }
            outcomeFailure != null -> {
                record("SUPPORT_CHECK outcome=exception detail=$outcomeFailure")
                "INDETERMINATE (checkRecognitionSupport threw)"
            }
            outcomeError != null -> {
                record("SUPPORT_CHECK outcome=error code=$outcomeError name=${errorName(outcomeError)}")
                "INDETERMINATE (onError $outcomeError ${errorName(outcomeError)})"
            }
            outcomeSupport != null -> {
                val installed = outcomeSupport.installedOnDeviceLanguages.orEmpty()
                val pending = outcomeSupport.pendingOnDeviceLanguages.orEmpty()
                val supported = outcomeSupport.supportedOnDeviceLanguages.orEmpty()
                val online = outcomeSupport.onlineLanguages.orEmpty()
                record("SUPPORT_CHECK outcome=result")
                record("INSTALLED_ON_DEVICE tags=${installed.joinToString(",")}")
                record("PENDING_ON_DEVICE tags=${pending.joinToString(",")}")
                record("SUPPORTED_ON_DEVICE tags=${supported.joinToString(",")}")
                record("ONLINE tags=${online.joinToString(",")}")
                val esInstalled = installed.filter { esSubtag(it) }
                record("ES_INSTALLED tags=${esInstalled.joinToString(",")}")
                if (serviceUp && esInstalled.isNotEmpty()) "AVAILABLE" else "UNAVAILABLE"
            }
            else -> {
                record("SUPPORT_CHECK outcome=none")
                "INDETERMINATE (latch released without an outcome)"
            }
        }
        record(
            "VERDICT $verdict " +
                "rule=service present AND es in installedOnDeviceLanguages serviceUp=$serviceUp",
        )

        instrumentation.runOnMainSync { recognizer?.destroy() }
        executor.shutdown()

        val banner = buildString {
            appendLine("=== 3-1 recognition availability probe BEGIN ===")
            for (line in lines) appendLine(line)
            append("=== 3-1 recognition availability probe END ===")
        }
        println(banner)
        check(completed) { "checkRecognitionSupport timed out after ${timeoutSeconds}s\n$banner" }
    }

    private fun esSubtag(languageTag: String): Boolean =
        Locale.forLanguageTag(languageTag.trim().replace('_', '-')).language == "es"

    private fun errorName(code: Int): String =
        SpeechRecognizer::class.java.fields
            .filter { it.name.startsWith("ERROR_") }
            .firstOrNull { runCatching { it.getInt(null) }.getOrNull() == code }
            ?.name
            ?: "UNKNOWN"
}
```

### Gate

`devbox run -- make gate` is the story-end check, run **after** the probe is deleted (format/analyze/test never see androidTest). Dart-side surface untouched this session (only `android/` additions and this spec), so the gate is not expected to move; it still must be shown green at deletion time.

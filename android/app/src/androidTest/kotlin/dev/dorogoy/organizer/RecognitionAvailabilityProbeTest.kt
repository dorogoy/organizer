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

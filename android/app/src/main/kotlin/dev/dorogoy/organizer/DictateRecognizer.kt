package dev.dorogoy.organizer

import android.content.Context
import android.content.Intent
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.speech.RecognitionListener
import android.speech.RecognitionSupport
import android.speech.RecognitionSupportCallback
import android.speech.RecognizerIntent
import android.speech.SpeechRecognizer

/**
 * The race-guarded on-device recognizer wrapper (Story 3.4, FR-32): the
 * `dictate` channel's platform half, on the 3-1 probe's own preserved
 * idiom — `createOnDeviceSpeechRecognizer()` (which forces on-device
 * and fails rather than falling back to any cloud path) gated by
 * `isOnDeviceRecognitionAvailable()` and `checkRecognitionSupport()`
 * with an `es-*` tag in `installedOnDeviceLanguages`, because a service
 * being available is not the Spanish model being present.
 *
 * Every callback is marshalled to the main looper (the 3-1 latch-race
 * guard, deferred-work.md:177-179): the support check's callbacks run
 * on the executor handed in — here one that posts to the main handler —
 * and the recognition callbacks are re-posted the same way, so all
 * mutable state is main-confined and no late callback can race a read.
 * There is no latch to await: the wrapper is fully asynchronous, and a
 * support check that never answers is bounded by a main-looper
 * timeout that releases the probe recognizer and answers false — the
 * honest default, arrived at without leaking anything.
 *
 * Only final results are emitted: partial results never leave this
 * class, which is what makes interruption yielding nothing true by
 * construction. One utterance = one session: the session id the Dart
 * half minted travels every emission, and a session that was cancelled
 * or superseded drops its outcomes here as well as there.
 */
internal class DictateRecognizer(private val context: Context) {
    private val mainHandler = Handler(Looper.getMainLooper())

    /** The support callbacks' executor: main-looper confinement. */
    private val mainExecutor = java.util.concurrent.Executor { runnable ->
        mainHandler.post(runnable)
    }

    private var recognizer: SpeechRecognizer? = null

    /** The session the standing recognizer belongs to; -1 when none. */
    private var activeSessionId = -1

    /**
     * Probes the 3-1 availability rule and answers on the main thread:
     * true only when the on-device service is present AND an `es-*`
     * model is installed. A thrown error or an errored support check
     * answers false — quiet, never an error surface: where recognition
     * is unavailable the affordance is simply absent. A support check
     * that never answers is bounded by a main-looper timeout that
     * destroys the probe recognizer and answers false exactly once
     * (the answered flag is main-confined with every callback — the
     * 3-1 race guard stands; no new thread, no latch).
     */
    fun probeAvailability(onOutcome: (available: Boolean) -> Unit) {
        mainHandler.post {
            if (!SpeechRecognizer.isOnDeviceRecognitionAvailable(context)) {
                onOutcome(false)
                return@post
            }
            val probeRecognizer =
                try {
                    SpeechRecognizer.createOnDeviceSpeechRecognizer(context)
                } catch (_: Exception) {
                    null
                }
            if (probeRecognizer == null) {
                onOutcome(false)
                return@post
            }
            var answered = false
            val timeout = Runnable {
                if (answered) {
                    return@Runnable
                }
                answered = true
                probeRecognizer.destroy()
                onOutcome(false)
            }
            mainHandler.postDelayed(timeout, PROBE_ANSWER_TIMEOUT_MILLIS)
            fun answer(available: Boolean) {
                if (answered) {
                    return
                }
                answered = true
                mainHandler.removeCallbacks(timeout)
                probeRecognizer.destroy()
                onOutcome(available)
            }
            try {
                probeRecognizer.checkRecognitionSupport(
                    recognizeIntent(),
                    mainExecutor,
                    object : RecognitionSupportCallback {
                        override fun onSupportResult(recognitionSupport: RecognitionSupport) {
                            val spanishInstalled =
                                recognitionSupport.installedOnDeviceLanguages.any { tag ->
                                    tag == SPANISH_LANGUAGE || tag.startsWith(SPANISH_TAG_PREFIX)
                                }
                            answer(spanishInstalled)
                        }

                        override fun onError(error: Int) {
                            answer(false)
                        }
                    },
                )
            } catch (_: Exception) {
                answer(false)
            }
        }
    }

    /**
     * Starts one utterance for [sessionId], answering [onAnswered] on the
     * main thread with whether listening began — the 3-1 rule re-armed at
     * the press itself: the support check runs again here, because a model
     * removed between the visibility probe and the press must not begin
     * listening (FR-32's quiet unavailability, not a broken session). The
     * answer is bounded by the probe's own timeout; a session cancelled
     * while the probe ran answers false and owns nothing further.
     */
    fun startListening(
        sessionId: Int,
        onAnswered: (started: Boolean) -> Unit,
    ) {
        mainHandler.post {
            pendingSessionId = sessionId
            pendingAnswer = onAnswered
            probeAvailability { available ->
                if (pendingSessionId != sessionId) {
                    // Cancelled or superseded while the probe ran: the
                    // session owns nothing, and its answer already left
                    // through the cancel path.
                    return@probeAvailability
                }
                pendingSessionId = -1
                pendingAnswer = null
                onAnswered(available && beginSession(sessionId))
            }
        }
    }

    private fun beginSession(sessionId: Int): Boolean {
        if (!SpeechRecognizer.isOnDeviceRecognitionAvailable(context)) {
            return false
        }
        cancelActive()
        val fresh =
            try {
                SpeechRecognizer.createOnDeviceSpeechRecognizer(context)
            } catch (_: Exception) {
                null
            } ?: return false
        recognizer = fresh
        activeSessionId = sessionId
        fresh.setRecognitionListener(
            object : RecognitionListener {
                override fun onResults(results: Bundle) {
                    mainHandler.post { emitTerminal(sessionId) { transcriptOf(results) } }
                }

                override fun onError(error: Int) {
                    mainHandler.post { emitTerminal(sessionId) { null } }
                }

                override fun onPartialResults(partialResults: Bundle?) {
                    // Partial results never touch the line (FR-32).
                }

                override fun onReadyForSpeech(params: Bundle?) {}

                override fun onBeginningOfSpeech() {}

                override fun onRmsChanged(rmsdB: Float) {}

                override fun onBufferReceived(buffer: ByteArray?) {}

                override fun onEndOfSpeech() {}

                override fun onEvent(eventType: Int, params: Bundle?) {}
            }
        )
        try {
            fresh.startListening(recognizeIntent())
        } catch (_: Exception) {
            // A start that throws after creation succeeded leaves a
            // recognizer holding nothing: release it and answer the
            // quiet unavailability, never an exception into the
            // method handler.
            cancelActive()
            return false
        }
        return true
    }

    /**
     * Cancels the session [sessionId] without delivering anything — the
     * interruption path (backgrounding, call, focus loss). A session id
     * other than the active one is already gone: nothing to do — except
     * a session still awaiting its own support probe, whose pending
     * answer is settled here (false) so no Dart future can hang on a
     * session that will never begin.
     */
    fun cancel(sessionId: Int) {
        if (sessionId == activeSessionId) {
            cancelActive()
        }
        if (sessionId == pendingSessionId) {
            pendingSessionId = -1
            pendingAnswer?.invoke(false)
            pendingAnswer = null
        }
    }

    /** Releases the recognizer outright (the channel's teardown). */
    fun destroy() {
        cancelActive()
        if (pendingSessionId != -1) {
            pendingSessionId = -1
            pendingAnswer?.invoke(false)
            pendingAnswer = null
        }
    }

    /**
     * Emits the session's one terminal outcome, then releases the
     * recognizer — but only for the session that still owns it: a stale
     * session (cancelled or superseded) drops its outcome AND touches
     * nothing, because the standing recognizer belongs to a newer
     * session whose utterance a late cleanup must not cut off.
     */
    private fun emitTerminal(
        sessionId: Int,
        transcript: () -> String?,
    ) {
        if (sessionId != activeSessionId) {
            return
        }
        val value = transcript()
        cancelActive()
        outcomeSink?.invoke(sessionId, value)
    }

    /** The sink every terminal outcome flows through, set once by the channel. */
    fun setOutcomeSink(sink: ((sessionId: Int, transcript: String?) -> Unit)?) {
        outcomeSink = sink
    }

    private var outcomeSink: ((sessionId: Int, transcript: String?) -> Unit)? = null

    /**
     * The session still awaiting its start probe's answer, with the
     * answer owed — main-confined with everything else, so a cancel or
     * teardown arriving mid-probe settles the future it must.
     */
    private var pendingSessionId = -1

    private var pendingAnswer: ((started: Boolean) -> Unit)? = null

    private fun cancelActive() {
        recognizer?.let {
            try {
                it.cancel()
            } catch (_: Exception) {
                // Quiet: a failing cancellation still must release.
            }
            try {
                it.destroy()
            } catch (_: Exception) {
                // Quiet by the same terms.
            }
        }
        recognizer = null
        activeSessionId = -1
    }

    private fun transcriptOf(results: Bundle): String? {
        val hypotheses =
            results.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION) ?: return null
        val first = hypotheses.firstOrNull() ?: return null
        return first.ifBlank { null }
    }

    private fun recognizeIntent(): Intent =
        Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH).putExtra(
            RecognizerIntent.EXTRA_LANGUAGE,
            SPANISH_LANGUAGE,
        )

    private companion object {
        const val SPANISH_LANGUAGE = "es"
        const val SPANISH_TAG_PREFIX = "es-"

        /** The support check's answer bound: a few seconds, main-looper. */
        const val PROBE_ANSWER_TIMEOUT_MILLIS = 3_000L
    }
}

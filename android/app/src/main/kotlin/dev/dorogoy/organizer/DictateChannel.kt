package dev.dorogoy.organizer

import android.app.Activity
import android.content.ActivityNotFoundException
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.provider.Settings
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * The hand-written `dictate` channel (Story 3.4, FR-32, AD-11) — one of
 * the build's exactly three channels, and the repo's first: no socket,
 * no date arithmetic, no cloud fallback on any path. Registered by
 * `MainActivity.configureFlutterEngine` and torn down in its cleanup.
 *
 * The protocol (mirrored by the named constants in
 * `lib/platform/dictate/dictate_recognizer.dart`):
 *  - `probe` → "unavailable" | "askable" | "granted" — the 3-1 rule's
 *    availability (which wins over everything) plus the microphone
 *    permission's granted bit, recomputed on every call, never cached.
 *  - `start(sessionId)` → "listening" | "refused" | "unavailable" —
 *    requests RECORD_AUDIO at this first-use moment when it is not
 *    granted (never at app entry), and either listens, reports the
 *    refusal, or reports quiet unavailability.
 *  - `cancel(sessionId)` → the interruption path; nothing listens
 *    outside an explicit press's foreground lifetime.
 *  - `openAppSettings` → the Settings reactivation row's single
 *    action: the system's app-details screen.
 *  - `outcome` (Kotlin→Dart, `{sessionId, transcript?}`) — one
 *    terminal outcome per session: the final transcript or nothing;
 *    partial results never cross.
 *
 * Every handler and callback runs confined to the main looper
 * (platform-channel handlers arrive there; the recognizer wrapper
 * marshals its own callbacks the same way), so the channel holds no
 * cross-thread state and no latch exists to race.
 */
internal class DictateChannel(
    private val activity: Activity,
    messenger: io.flutter.plugin.common.BinaryMessenger,
) {
    private val methodChannel = MethodChannel(messenger, CHANNEL_NAME)
    private val recognizer = DictateRecognizer(activity)

    /** The press whose permission request is still unanswered, if any. */
    private var stagedStart: StagedStart? = null

    private class StagedStart(
        val sessionId: Int,
        val result: MethodChannel.Result,
    )

    init {
        recognizer.setOutcomeSink { sessionId, transcript ->
            methodChannel.invokeMethod(
                OUTCOME_METHOD,
                mapOf(
                    SESSION_ID_KEY to sessionId,
                    TRANSCRIPT_KEY to transcript,
                ),
            )
        }
        methodChannel.setMethodCallHandler(::onMethodCall)
    }

    private fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            PROBE_METHOD -> probe(result)
            START_METHOD -> start(call.arguments as? Int, result)
            CANCEL_METHOD -> {
                recognizer.cancel(call.arguments as? Int ?: -1)
                result.success(null)
            }
            OPEN_APP_SETTINGS_METHOD -> {
                openAppSettings()
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }

    private fun probe(result: MethodChannel.Result) {
        recognizer.probeAvailability { available ->
            if (!available) {
                result.success(WIRE_UNAVAILABLE)
                return@probeAvailability
            }
            val granted =
                activity.checkSelfPermission(PERMISSION) == PackageManager.PERMISSION_GRANTED
            result.success(if (granted) WIRE_GRANTED else WIRE_ASKABLE)
        }
    }

    private fun start(sessionId: Int?, result: MethodChannel.Result) {
        if (sessionId == null) {
            result.success(WIRE_UNAVAILABLE)
            return
        }
        if (activity.checkSelfPermission(PERMISSION) != PackageManager.PERMISSION_GRANTED) {
            // A superseded press (a second press while the dialog
            // stands) is answered quietly before its own request lands.
            stagedStart?.result?.success(WIRE_UNAVAILABLE)
            stagedStart = StagedStart(sessionId, result)
            activity.requestPermissions(arrayOf(PERMISSION), PERMISSION_REQUEST_CODE)
            return
        }
        beginListening(sessionId, result)
    }

    /**
     * The permission request's answer, forwarded by MainActivity.
     * Returns true when consumed — the channel is the only permission
     * requester, so an unmatched code is not ours to keep.
     */
    fun onRequestPermissionsResult(
        requestCode: Int,
        grantResults: IntArray,
    ): Boolean {
        if (requestCode != PERMISSION_REQUEST_CODE) {
            return false
        }
        val staged = stagedStart
        stagedStart = null
        if (staged == null) {
            return true
        }
        val granted =
            grantResults.isNotEmpty() && grantResults[0] == PackageManager.PERMISSION_GRANTED
        if (granted) {
            beginListening(staged.sessionId, staged.result)
        } else {
            staged.result.success(WIRE_REFUSED)
        }
        return true
    }

    private fun beginListening(
        sessionId: Int,
        result: MethodChannel.Result,
    ) {
        val started = recognizer.startListening(sessionId)
        result.success(if (started) WIRE_LISTENING else WIRE_UNAVAILABLE)
    }

    private fun openAppSettings() {
        val intent =
            Intent(
                Settings.ACTION_APPLICATION_DETAILS_SETTINGS,
                Uri.fromParts(PACKAGE_SCHEME, activity.packageName, null),
            )
        try {
            activity.startActivity(intent)
        } catch (_: ActivityNotFoundException) {
            // Quiet: no activity handles the app-details intent — the
            // row's tap simply does what it can, and no error surface
            // exists anywhere to reach.
        }
    }

    /**
     * The teardown: a press still awaiting its permission answer is
     * answered with the quiet unavailability (its Dart future must not
     * hang), and then the recognizer and the handler are released
     * outright.
     */
    fun destroy() {
        stagedStart?.result?.success(WIRE_UNAVAILABLE)
        stagedStart = null
        recognizer.destroy()
        methodChannel.setMethodCallHandler(null)
    }

    private companion object {
        const val CHANNEL_NAME = "dev.dorogoy.organizer/dictate"
        const val PROBE_METHOD = "probe"
        const val START_METHOD = "start"
        const val CANCEL_METHOD = "cancel"
        const val OPEN_APP_SETTINGS_METHOD = "openAppSettings"
        const val OUTCOME_METHOD = "outcome"
        const val SESSION_ID_KEY = "sessionId"
        const val TRANSCRIPT_KEY = "transcript"
        const val WIRE_UNAVAILABLE = "unavailable"
        const val WIRE_ASKABLE = "askable"
        const val WIRE_GRANTED = "granted"
        const val WIRE_LISTENING = "listening"
        const val WIRE_REFUSED = "refused"
        const val PERMISSION = android.Manifest.permission.RECORD_AUDIO
        const val PERMISSION_REQUEST_CODE = 3404
        const val PACKAGE_SCHEME = "package"
    }
}

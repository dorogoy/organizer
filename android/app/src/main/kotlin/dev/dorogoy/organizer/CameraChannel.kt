package dev.dorogoy.organizer

import android.app.Activity
import android.content.pm.PackageManager
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * The hand-written `camera` channel (Story 5.2, FR-16, AD-11; the
 * 2026-09-05 ruling 1-B) — one of the build's four decided channels
 * (dictate, credentials and camera shipped, notify reserved and
 * unshipped; this slot grown by the ruling): no socket, no date
 * arithmetic (AD-4), no capture — the camera plugin still serves
 * every frame. This channel owns exactly one thing the plugin cannot
 * say: **the permission moment**, with the two domains the plugin
 * folds together kept apart.
 *
 * The protocol (mirrored by the named constants in
 * `lib/plugins/camera/camera_channel.dart`):
 *  - `request` → "granted" | "refused" | "interrupted" — asks CAMERA
 *    at the first scan attempt only (never at app entry, AD-17),
 *    fast-pathing an existing grant with no dialog:
 *    an existing grant answers `granted` outright; otherwise the ask
 *    is staged and `requestPermissions` fires.
 *  - A permission answer with **empty grants** answers `interrupted`:
 *    the system swallowed the ask (the activity gone, the request
 *    superseded) — no answer existed, so nobody refused anything
 *    (DictateChannel's own empty-grants reading, surfaced as its own
 *    wire word this time: a malfunction is never mistaken for the
 *    user's choice, and the scan surface communicates it).
 *  - An explicit denial answers `refused` — the app-logic domain: the
 *    Dart half appends the one `permission_refused{camera}` row and
 *    the entry is absent thereafter.
 *
 * Every handler runs confined to the main looper (platform-channel
 * handlers arrive there), so the channel holds no cross-thread state.
 */
internal class CameraChannel(
    private val activity: Activity,
    messenger: io.flutter.plugin.common.BinaryMessenger,
) {
    private val methodChannel = MethodChannel(messenger, CHANNEL_NAME)

    /** The ask whose permission request is still unanswered, if any. */
    private var stagedAsk: StagedAsk? = null

    private class StagedAsk(
        val result: MethodChannel.Result,
    )

    init {
        methodChannel.setMethodCallHandler(::onMethodCall)
    }

    private fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            REQUEST_METHOD -> request(result)
            else -> result.notImplemented()
        }
    }

    private fun request(result: MethodChannel.Result) {
        // The fast path: a grant that already stands answers outright,
        // no dialog — the second open of a granted camera is silent.
        if (activity.checkSelfPermission(PERMISSION) == PackageManager.PERMISSION_GRANTED) {
            result.success(WIRE_GRANTED)
            return
        }
        // A superseded ask (a second request while the dialog stands)
        // is answered with the interruption before its own request
        // lands — no answer existed for it either.
        stagedAsk?.result?.success(WIRE_INTERRUPTED)
        stagedAsk = StagedAsk(result)
        activity.requestPermissions(arrayOf(PERMISSION), PERMISSION_REQUEST_CODE)
    }

    /**
     * The permission request's answer, forwarded by MainActivity.
     * Returns true when consumed — each channel is the only requester
     * of its own permission under its own request code, so an
     * unmatched code is not ours to keep.
     */
    fun onRequestPermissionsResult(
        requestCode: Int,
        grantResults: IntArray,
    ): Boolean {
        if (requestCode != PERMISSION_REQUEST_CODE) {
            return false
        }
        val staged = stagedAsk
        stagedAsk = null
        if (grantResults.isEmpty()) {
            // The system cancelled the request itself (the activity
            // gone, the ask dismissed without an answer): nobody
            // refused anything — the interruption, its own word.
            staged?.result?.success(WIRE_INTERRUPTED)
            return true
        }
        val granted = grantResults[0] == PackageManager.PERMISSION_GRANTED
        staged?.result?.success(if (granted) WIRE_GRANTED else WIRE_REFUSED)
        return true
    }

    /**
     * The teardown: an ask still awaiting its answer is answered with
     * the interruption (its Dart future must not hang), then the
     * handler is released outright.
     */
    fun destroy() {
        stagedAsk?.result?.success(WIRE_INTERRUPTED)
        stagedAsk = null
        methodChannel.setMethodCallHandler(null)
    }

    private companion object {
        const val CHANNEL_NAME = "dev.dorogoy.organizer/camera"
        const val REQUEST_METHOD = "request"
        const val WIRE_GRANTED = "granted"
        const val WIRE_REFUSED = "refused"
        const val WIRE_INTERRUPTED = "interrupted"
        const val PERMISSION = android.Manifest.permission.CAMERA
        const val PERMISSION_REQUEST_CODE = 3405
    }
}

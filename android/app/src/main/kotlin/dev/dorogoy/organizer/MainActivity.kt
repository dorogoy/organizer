package dev.dorogoy.organizer

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterActivity() {
    private var dictateChannel: DictateChannel? = null
    private var credentialsChannel: CredentialsChannel? = null
    private var cameraChannel: CameraChannel? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // The repo's first hand-written channel (Story 3.4, FR-32,
        // AD-11): the `dictate` channel over the race-guarded on-device
        // recognizer, constructed once per engine over this activity.
        dictateChannel =
            DictateChannel(this, flutterEngine.dartExecutor.binaryMessenger)
        // The second (Story 4.3, AD-22): the `credentials` channel over
        // the Keystore service's seal/unseal — no activity of its own,
        // torn down with the engine like its sibling.
        credentialsChannel =
            CredentialsChannel(flutterEngine.dartExecutor.binaryMessenger)
        // The camera channel (Story 5.2, FR-16, AD-11 — the fourth of
        // the build's four decided channels: dictate, credentials and
        // camera shipped, notify reserved and unshipped; the 2026-09-05
        // ruling 1-B grew the count): it owns the scan path's
        // permission moment alone — capture stays plugin-served, and
        // this channel opens no camera of its own.
        cameraChannel =
            CameraChannel(this, flutterEngine.dartExecutor.binaryMessenger)
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray,
    ) {
        // Each channel's first-use permission answer arrives here
        // under its own request code; everything else falls through
        // to the embedding.
        if (dictateChannel?.onRequestPermissionsResult(requestCode, grantResults) == true) {
            return
        }
        if (cameraChannel?.onRequestPermissionsResult(requestCode, grantResults) == true) {
            return
        }
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
    }

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        dictateChannel?.destroy()
        dictateChannel = null
        credentialsChannel?.destroy()
        credentialsChannel = null
        cameraChannel?.destroy()
        cameraChannel = null
        super.cleanUpFlutterEngine(flutterEngine)
    }
}

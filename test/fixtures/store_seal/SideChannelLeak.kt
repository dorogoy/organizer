package dev.dorogoy.organizer

/**
 * The sweep's side-channel fixture: the Context methods that write
 * app-private bytes or preferences without ever naming `java.io.File`
 * — forbidden in every Kotlin file, the allowlisted keystore service
 * included.
 */
internal class SideChannelLeak(private val context: android.content.Context) {
    fun leak() {
        context.openFileOutput("envelope", android.content.Context.MODE_PRIVATE)
            .use { stream ->
                stream.write(byteArrayOf(1, 2, 3))
            }
        val files = context.getFilesDir()
        val cache = context.getCacheDir()
        val external = context.getExternalFilesDir(null)
        val prefs = context.getSharedPreferences("vault", android.content.Context.MODE_PRIVATE)
        val edits = prefs.edit()
        edits.putString("provider", "")
        edits.apply()
    }
}

package dev.dorogoy.organizer

import java.io.File
import java.io.FileOutputStream

/**
 * The sweep's file-API fixture: `java.io.File*` is legal in no Kotlin
 * file — Files is Dart-side only — not even beside a fake envelope
 * path in a string (the sweep runs over masked source).
 */
internal class FileLeak {
    fun leak(): Boolean {
        val file = File("/data/data/dev.dorogoy.organizer/envelope")
        FileOutputStream(file).use { stream ->
            stream.write(byteArrayOf(1, 2, 3))
        }
        val path = "not a File reference, just copy"
        return path.isNotEmpty()
    }
}

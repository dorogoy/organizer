package dev.dorogoy.organizer

import java.nio.file.Files
import java.nio.file.Paths

/**
 * The sweep's NIO fixture: `java.nio.file.Files`/`Paths` write files
 * while looking like nothing the `java.io` rule polices — imported
 * and fully qualified usages both.
 */
internal class NioFilesLeak {
    fun leak(): Boolean {
        val path = Paths.get("/data/data/dev.dorogoy.organizer/files/envelope")
        Files.write(path, byteArrayOf(1, 2, 3))
        val all = java.nio.file.Files.readAllBytes(path)
        return all.isNotEmpty()
    }
}

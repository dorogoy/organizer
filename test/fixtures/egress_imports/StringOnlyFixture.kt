// The egress import seal's false-positive fixture: banned tokens in
// comments and string literals only — masked, never findings.

package dev.dorogoy.organizer.fixture

class StringOnlyFixture {
    // java.net.Socket in a comment is not an import.
    val text = "System.currentTimeMillis and okhttp3 and java.time.Instant"

    fun greet(): String = "url: http://127.0.0.1"
}

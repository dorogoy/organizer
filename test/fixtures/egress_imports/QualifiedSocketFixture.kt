// The egress import seal's Kotlin fully-qualified-usage fixture:
// java.net.Socket reached without any import line — the qualified-usage
// sweep is what catches it (AD-7, AD-11).

package dev.dorogoy.organizer.fixture

class QualifiedSocketFixture {
    fun dial(): java.net.Socket = java.net.Socket("127.0.0.1", 8080)
}

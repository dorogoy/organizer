// The egress import seal's Kotlin star-import fixture: importing a
// whole date API package is already the violation — no specific class
// is named (AD-4, AD-11).

package dev.dorogoy.organizer.fixture

import java.time.*

class StarImportFixture {
    fun tick(): Unit = Unit
}

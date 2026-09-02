// The egress import seal's Kotlin date fixture: System.currentTime-
// Millis, java.util.Date and Calendar usage, and a java.time import —
// all banned in the app's Kotlin (AD-4, AD-11).

package dev.dorogoy.organizer.fixture

import java.time.Instant

class DateFixture {
    fun now(): Long = System.currentTimeMillis()

    fun when_(): java.util.Date = java.util.Date()

    fun month(c: Calendar): Int = c.get(2)
}

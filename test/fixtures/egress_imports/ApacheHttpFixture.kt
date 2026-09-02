// The egress import seal's Kotlin Apache-HTTP fixture: the legacy
// client's import is as banned as okhttp's (AD-7, AD-11).

package dev.dorogoy.organizer.fixture

import org.apache.http.impl.client.DefaultHttpClient

class ApacheHttpFixture {
    fun client() = DefaultHttpClient()
}

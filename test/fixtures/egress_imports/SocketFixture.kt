// The egress import seal's Kotlin socket fixture: a java.net socket
// import and usage, plus an HttpURLConnection — all banned in the
// app's Kotlin (AD-7, AD-11).

package dev.dorogoy.organizer.fixture

import java.net.Socket
import java.net.HttpURLConnection

class SocketFixture {
    fun open(): Socket = Socket("127.0.0.1", 8080)

    fun connect(url: HttpURLConnection) = url.connect()
}

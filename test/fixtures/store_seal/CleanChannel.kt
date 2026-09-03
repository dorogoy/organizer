package dev.dorogoy.organizer

import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * The sweep's ordinary-channel fixture: no Keystore/crypto API, no
 * file API — a hand-written channel's Kotlin is clean by default,
 * and only the wrapping key's own service may differ.
 */
internal class CleanChannel(messenger: io.flutter.plugin.common.BinaryMessenger) {
    private val methodChannel = MethodChannel(messenger, "dev.dorogoy.organizer/clean")

    init {
        methodChannel.setMethodCallHandler(::onMethodCall)
    }

    private fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "probe" -> result.success("ok")
            else -> result.notImplemented()
        }
    }

    fun destroy() {
        methodChannel.setMethodCallHandler(null)
    }
}

// The egress import seal's clean Kotlin fixture: the shape of the
// repo's real channels — platform APIs only, no socket, no date.

package dev.dorogoy.organizer.fixture

import android.content.Intent
import io.flutter.embedding.engine.FlutterEngine

class CleanFixture(engine: FlutterEngine) {
    fun handle(intent: Intent): Boolean = intent.action != null
}

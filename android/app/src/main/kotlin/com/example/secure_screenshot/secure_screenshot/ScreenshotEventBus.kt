package com.example.secure_screenshot.secure_screenshot

import android.os.Handler
import android.os.Looper
import io.flutter.plugin.common.EventChannel

/**
 * In-process bridge from native components (service, receivers, activities - all of
 * which run in the app's single default process) to the Flutter EventChannel, when a
 * Flutter engine happens to be alive and listening. Detection/scheduling/deletion never
 * depend on this being attached; it only drives live UI refreshes.
 */
object ScreenshotEventBus {
    private val mainHandler = Handler(Looper.getMainLooper())
    @Volatile
    private var sink: EventChannel.EventSink? = null

    fun attach(newSink: EventChannel.EventSink?) {
        sink = newSink
    }

    fun notifyChanged() {
        val currentSink = sink ?: return
        mainHandler.post {
            try {
                currentSink.success(mapOf("type" to "changed"))
            } catch (_: Exception) {
                // Sink detached between the null check and the post; safe to ignore.
            }
        }
    }
}

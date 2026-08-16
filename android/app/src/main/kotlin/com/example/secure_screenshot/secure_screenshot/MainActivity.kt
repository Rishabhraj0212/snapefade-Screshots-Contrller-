package com.example.secure_screenshot.secure_screenshot

import android.content.Intent
import android.graphics.Bitmap
import android.net.Uri
import android.os.Handler
import android.os.Looper
import android.util.Size
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream

/** Below this remaining time, extending a scheduled deletion is refused - too close
 * to the alarm actually firing to safely race a reschedule against it. */
private const val EXTEND_CUTOFF_MILLIS = 15_000L

class MainActivity : FlutterActivity() {
    private val methodChannelName = "secure_screenshot/monitor"
    private val eventChannelName = "secure_screenshot/monitor/events"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, methodChannelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "startMonitoring" -> {
                        Prefs.setMonitoringEnabled(this, true)
                        ContextCompat.startForegroundService(
                            this, Intent(this, ScreenshotDetectionService::class.java)
                        )
                        result.success(null)
                    }
                    "stopMonitoring" -> {
                        Prefs.setMonitoringEnabled(this, false)
                        stopService(Intent(this, ScreenshotDetectionService::class.java))
                        result.success(null)
                    }
                    "isMonitoringEnabled" -> result.success(Prefs.isMonitoringEnabled(this))
                    "getManagedScreenshots" -> {
                        val list = ManagedScreenshotStore.get(this).getAll().map { it.toMap() }
                        result.success(list)
                    }
                    "cancelScheduledDeletion" -> {
                        val id = (call.argument<String>("id"))?.toLongOrNull()
                        if (id == null) {
                            result.error("bad_id", "Missing or invalid id", null)
                            return@setMethodCallHandler
                        }
                        ManagedScreenshotStore.get(this).remove(id)
                        AlarmScheduler.cancel(this, id)
                        ScreenshotEventBus.notifyChanged()
                        result.success(null)
                    }
                    "getDefaultDurationMillis" -> result.success(Prefs.getDefaultDurationMillis(this))
                    "setDefaultDurationMillis" -> {
                        val millis = call.argument<Number>("millis")?.toLong()
                        Prefs.setDefaultDurationMillis(this, millis)
                        result.success(null)
                    }
                    "canScheduleExactAlarms" -> result.success(AlarmScheduler.canScheduleExact(this))
                    "getThumbnail" -> loadImageBytes(call.argument<String>("id"), Size(256, 256), result)
                    "getPreview" -> loadImageBytes(call.argument<String>("id"), Size(1024, 1024), result)
                    "extendScheduledDeletion" -> {
                        val id = call.argument<String>("id")?.toLongOrNull()
                        val additionalMillis = call.argument<Number>("additionalMillis")?.toLong()
                        if (id == null || additionalMillis == null || additionalMillis <= 0) {
                            result.error("bad_args", "Missing or invalid id/additionalMillis", null)
                            return@setMethodCallHandler
                        }
                        val store = ManagedScreenshotStore.get(this)
                        val current = store.getById(id)
                        val deleteAt = current?.deleteAtMillis
                        if (current == null || current.status != ScreenshotStatus.SCHEDULED || deleteAt == null) {
                            result.error("not_scheduled", "This item is no longer scheduled", null)
                            return@setMethodCallHandler
                        }
                        if (deleteAt - System.currentTimeMillis() <= EXTEND_CUTOFF_MILLIS) {
                            result.error("too_late", "Too close to the scheduled time to extend", null)
                            return@setMethodCallHandler
                        }
                        val newDeleteAt = deleteAt + additionalMillis
                        store.setChoice(id, ScreenshotStatus.SCHEDULED, newDeleteAt)
                        AlarmScheduler.schedule(this, id, newDeleteAt)
                        ScreenshotEventBus.notifyChanged()
                        result.success(newDeleteAt)
                    }
                    else -> result.notImplemented()
                }
            }

        EventChannel(flutterEngine.dartExecutor.binaryMessenger, eventChannelName)
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink) {
                    ScreenshotEventBus.attach(events)
                }

                override fun onCancel(arguments: Any?) {
                    ScreenshotEventBus.attach(null)
                }
            })
    }

    /** Never written to disk - decoded fresh each call straight into memory, purely
     * so the Flutter UI can show a preview. */
    private fun loadImageBytes(idArg: String?, size: Size, result: MethodChannel.Result) {
        val id = idArg?.toLongOrNull()
        val screenshot = id?.let { ManagedScreenshotStore.get(this).getById(it) }
        if (screenshot == null) {
            result.success(null)
            return
        }
        Thread {
            val bytes = try {
                val bitmap = MediaThumbnails.load(this, Uri.parse(screenshot.mediaUri), size)
                bitmap?.let {
                    ByteArrayOutputStream().use { stream ->
                        it.compress(Bitmap.CompressFormat.JPEG, 85, stream)
                        stream.toByteArray()
                    }
                }
            } catch (e: Exception) {
                null
            }
            Handler(Looper.getMainLooper()).post { result.success(bytes) }
        }.start()
    }
}

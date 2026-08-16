package com.example.secure_screenshot.secure_screenshot

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import androidx.core.content.ContextCompat

/**
 * AlarmManager alarms and the detection service both die on reboot. This restarts
 * monitoring (if the user had it enabled) and re-arms every still-SCHEDULED deletion -
 * anything already overdue is deleted immediately instead of silently slipping.
 */
class BootCompletedReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != Intent.ACTION_BOOT_COMPLETED) return

        if (Prefs.isMonitoringEnabled(context)) {
            ContextCompat.startForegroundService(context, Intent(context, ScreenshotDetectionService::class.java))
        }

        val store = ManagedScreenshotStore.get(context)
        val now = System.currentTimeMillis()
        val scheduled = store.getAllScheduled()
        val overdue = scheduled.filter { (it.deleteAtMillis ?: Long.MAX_VALUE) <= now }
        val upcoming = scheduled - overdue.toSet()

        for (item in upcoming) {
            AlarmScheduler.schedule(context, item.id, item.deleteAtMillis!!)
        }
        if (overdue.isNotEmpty()) {
            val pendingResult = goAsync()
            Thread {
                try {
                    SilentDeleter.deleteDueNow(context)
                } finally {
                    pendingResult.finish()
                }
            }.start()
        }
    }
}

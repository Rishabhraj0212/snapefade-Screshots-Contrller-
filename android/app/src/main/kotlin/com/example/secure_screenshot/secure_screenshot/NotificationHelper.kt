package com.example.secure_screenshot.secure_screenshot

import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Context
import androidx.core.app.NotificationCompat

/**
 * Android requires every foreground service to show a notification - that one can't be
 * avoided. Everything else (the screenshot prompt, delete confirmation) now happens
 * without any notification: the prompt is a direct overlay (ScreenshotOverlayController)
 * and deletion is silent (SilentDeleter), both gated on one-time special permissions
 * instead.
 */
object NotificationHelper {
    const val SERVICE_CHANNEL_ID = "screenshot_monitor_service"
    const val SERVICE_NOTIFICATION_ID = 1001

    fun ensureChannels(context: Context) {
        val manager = context.getSystemService(NotificationManager::class.java)
        manager.createNotificationChannel(
            NotificationChannel(
                SERVICE_CHANNEL_ID,
                "Screenshot monitoring",
                NotificationManager.IMPORTANCE_MIN,
            ).apply { description = "Shows while the app is watching for new screenshots" }
        )
    }

    fun buildServiceNotification(context: Context): android.app.Notification {
        return NotificationCompat.Builder(context, SERVICE_CHANNEL_ID)
            .setContentTitle("Watching for screenshots")
            .setContentText("New screenshots will prompt for a keep/delete choice")
            .setSmallIcon(android.R.drawable.ic_menu_camera)
            .setOngoing(true)
            .setPriority(NotificationCompat.PRIORITY_MIN)
            .build()
    }
}

package com.example.secure_screenshot.secure_screenshot

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build

/**
 * One exact alarm per scheduled screenshot, keyed by its DB row id so it can be
 * individually cancelled. AlarmManager alarms don't survive reboot - BootCompletedReceiver
 * re-arms every still-SCHEDULED row on startup.
 */
object AlarmScheduler {
    private fun pendingIntent(context: Context, id: Long): PendingIntent {
        val intent = Intent(context, DeletionAlarmReceiver::class.java)
        return PendingIntent.getBroadcast(
            context,
            id.toInt(),
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
    }

    /** True if the exact alarm will fire at (close to) the requested time. */
    fun canScheduleExact(context: Context): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.S) return true
        val alarmManager = context.getSystemService(AlarmManager::class.java)
        return alarmManager.canScheduleExactAlarms()
    }

    fun schedule(context: Context, id: Long, atMillis: Long) {
        val alarmManager = context.getSystemService(AlarmManager::class.java)
        val pending = pendingIntent(context, id)
        if (canScheduleExact(context)) {
            alarmManager.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, atMillis, pending)
        } else {
            // Falls back to an inexact-but-Doze-aware alarm; UI should surface this as
            // "approximate timing" when SCHEDULE_EXACT_ALARM isn't granted.
            alarmManager.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, atMillis, pending)
        }
    }

    fun cancel(context: Context, id: Long) {
        val alarmManager = context.getSystemService(AlarmManager::class.java)
        alarmManager.cancel(pendingIntent(context, id))
    }
}

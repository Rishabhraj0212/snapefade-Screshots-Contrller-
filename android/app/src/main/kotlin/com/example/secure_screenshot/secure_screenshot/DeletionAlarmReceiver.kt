package com.example.secure_screenshot.secure_screenshot

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

/** Fired by AlarmManager when a scheduled screenshot's timer runs out. */
class DeletionAlarmReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
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

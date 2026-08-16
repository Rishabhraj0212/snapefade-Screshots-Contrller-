package com.example.secure_screenshot.secure_screenshot

import android.content.Context

/** Small wrapper around the app's SharedPreferences for monitor settings. */
object Prefs {
    private const val FILE_NAME = "screenshot_monitor_prefs"
    private const val KEY_MONITORING_ENABLED = "monitoring_enabled"
    private const val KEY_DEFAULT_DURATION_MILLIS = "default_duration_millis"
    private const val KEY_LAST_CHECKED_SEC = "last_checked_sec"

    private fun prefs(context: Context) =
        context.getSharedPreferences(FILE_NAME, Context.MODE_PRIVATE)

    fun isMonitoringEnabled(context: Context): Boolean =
        prefs(context).getBoolean(KEY_MONITORING_ENABLED, false)

    fun setMonitoringEnabled(context: Context, enabled: Boolean) {
        prefs(context).edit().putBoolean(KEY_MONITORING_ENABLED, enabled).apply()
    }

    /** Null means "keep permanently" is the default action. */
    fun getDefaultDurationMillis(context: Context): Long? {
        val value = prefs(context).getLong(KEY_DEFAULT_DURATION_MILLIS, -1L)
        return if (value < 0) null else value
    }

    fun setDefaultDurationMillis(context: Context, millis: Long?) {
        prefs(context).edit().putLong(KEY_DEFAULT_DURATION_MILLIS, millis ?: -1L).apply()
    }

    /** MediaStore DATE_ADDED is in whole seconds since epoch. */
    fun getLastCheckedSec(context: Context): Long =
        prefs(context).getLong(KEY_LAST_CHECKED_SEC, System.currentTimeMillis() / 1000L)

    fun setLastCheckedSec(context: Context, seconds: Long) {
        prefs(context).edit().putLong(KEY_LAST_CHECKED_SEC, seconds).apply()
    }
}

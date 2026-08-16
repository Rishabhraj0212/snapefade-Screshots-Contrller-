package com.example.secure_screenshot.secure_screenshot

import android.app.Service
import android.content.ContentUris
import android.content.Intent
import android.database.ContentObserver
import android.net.Uri
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.provider.MediaStore
import android.util.Log

/**
 * Foreground service that owns the MediaStore ContentObserver. This is the only reliable
 * way for a third-party app to learn about images (including screenshots) added by other
 * apps/system UI - there is no public "screenshot taken" broadcast. The observer only
 * fires while this process is alive, which is why this must run as a foreground service
 * rather than a plain background isolate/Dart Timer.
 */
class ScreenshotDetectionService : Service() {
    private val handler = Handler(Looper.getMainLooper())
    private var observer: ContentObserver? = null
    private var pendingScan = false

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onCreate() {
        super.onCreate()
        NotificationHelper.ensureChannels(this)
        startForeground(NotificationHelper.SERVICE_NOTIFICATION_ID, NotificationHelper.buildServiceNotification(this))

        // Baseline so a freshly (re)started service never reacts to images already on
        // disk - only genuinely new inserts from this point on are considered.
        Prefs.setLastCheckedSec(this, System.currentTimeMillis() / 1000L)

        val contentObserver = object : ContentObserver(handler) {
            override fun onChange(selfChange: Boolean, uri: Uri?) {
                scheduleScan()
            }
        }
        observer = contentObserver
        contentResolver.registerContentObserver(
            MediaStore.Images.Media.EXTERNAL_CONTENT_URI,
            true,
            contentObserver,
        )
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        return START_STICKY
    }

    override fun onDestroy() {
        observer?.let { contentResolver.unregisterContentObserver(it) }
        observer = null
        super.onDestroy()
    }

    /** Coalesces bursts of MediaStore change notifications into a single scan. */
    private fun scheduleScan() {
        if (pendingScan) return
        pendingScan = true
        handler.postDelayed({
            pendingScan = false
            scanForNewScreenshots()
        }, SCAN_DEBOUNCE_MS)
    }

    private fun scanForNewScreenshots() {
        val store = ManagedScreenshotStore.get(this)
        val lastCheckedSec = Prefs.getLastCheckedSec(this)
        val nowSec = System.currentTimeMillis() / 1000L

        val projection = mutableListOf(
            MediaStore.Images.Media._ID,
            MediaStore.Images.Media.DISPLAY_NAME,
            MediaStore.Images.Media.DATE_ADDED,
        )
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            projection.add(MediaStore.Images.Media.RELATIVE_PATH)
        } else {
            @Suppress("DEPRECATION")
            projection.add(MediaStore.Images.Media.DATA)
        }

        var maxDateSeen = lastCheckedSec
        try {
            contentResolver.query(
                MediaStore.Images.Media.EXTERNAL_CONTENT_URI,
                projection.toTypedArray(),
                "${MediaStore.Images.Media.DATE_ADDED} >= ?",
                arrayOf(lastCheckedSec.toString()),
                "${MediaStore.Images.Media.DATE_ADDED} DESC",
            )?.use { cursor ->
                val idIdx = cursor.getColumnIndexOrThrow(MediaStore.Images.Media._ID)
                val nameIdx = cursor.getColumnIndexOrThrow(MediaStore.Images.Media.DISPLAY_NAME)
                val dateIdx = cursor.getColumnIndexOrThrow(MediaStore.Images.Media.DATE_ADDED)
                val pathColumn = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                    MediaStore.Images.Media.RELATIVE_PATH
                } else {
                    MediaStore.Images.Media.DATA
                }
                val pathIdx = cursor.getColumnIndexOrThrow(pathColumn)

                while (cursor.moveToNext()) {
                    val rowId = cursor.getLong(idIdx)
                    val displayName = cursor.getString(nameIdx) ?: ""
                    val dateAddedSec = cursor.getLong(dateIdx)
                    val rawPath = cursor.getString(pathIdx)
                    if (dateAddedSec > maxDateSeen) maxDateSeen = dateAddedSec

                    val relativePath = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                        rawPath
                    } else {
                        // Pre-scoped-storage: DATA is a full path like
                        // /storage/emulated/0/Pictures/Screenshots/Screenshot_1.png
                        rawPath?.substringAfter("/storage/emulated/0/", "")
                            ?.substringBeforeLast('/', "")
                    }

                    if (!ScreenshotHeuristics.isLikelyScreenshot(relativePath, displayName, dateAddedSec, nowSec)) {
                        continue
                    }

                    val contentUri = ContentUris.withAppendedId(
                        MediaStore.Images.Media.EXTERNAL_CONTENT_URI, rowId
                    )
                    val newId = store.insertDetected(contentUri.toString(), displayName, dateAddedSec)
                    if (newId != null) {
                        val screenshot = store.getById(newId) ?: continue
                        ScreenshotEventBus.notifyChanged()
                        val thumbnail = MediaThumbnails.load(this@ScreenshotDetectionService, contentUri)
                        ScreenshotOverlayController.show(this@ScreenshotDetectionService, screenshot, thumbnail)
                        // Owned by the service (not the overlay) so it fires correctly
                        // even if multiple screenshots arrive close together or the
                        // overlay permission was never granted.
                        handler.postDelayed({ applyDefaultIfStillPending(newId) }, PENDING_CHOICE_TIMEOUT_MS)
                    }
                }
            }
        } catch (e: Exception) {
            Log.e(TAG, "Failed to scan MediaStore for new screenshots", e)
        }

        if (maxDateSeen > lastCheckedSec) {
            Prefs.setLastCheckedSec(this, maxDateSeen)
        }
    }

    /**
     * If the user never responds to the prompt, apply their configured default action
     * (Settings > default duration) rather than leaving it in limbo. Configured default
     * is null ("keep") unless the user explicitly set one, so the safe behavior - never
     * auto-deleting without some explicit signal from the user - still holds by default.
     */
    private fun applyDefaultIfStillPending(id: Long) {
        Thread {
            val store = ManagedScreenshotStore.get(this)
            val current = store.getById(id) ?: return@Thread
            if (current.status != ScreenshotStatus.PENDING_CHOICE) return@Thread

            val defaultDurationMillis = Prefs.getDefaultDurationMillis(this)
            if (defaultDurationMillis == null) {
                store.remove(id)
            } else {
                val deleteAt = System.currentTimeMillis() + defaultDurationMillis
                store.setChoice(id, ScreenshotStatus.SCHEDULED, deleteAt)
                AlarmScheduler.schedule(this, id, deleteAt)
            }
            ScreenshotOverlayController.dismissIfShowing(this, id)
            ScreenshotEventBus.notifyChanged()
        }.start()
    }

    companion object {
        private const val TAG = "ScreenshotDetection"
        private const val SCAN_DEBOUNCE_MS = 400L
        private const val PENDING_CHOICE_TIMEOUT_MS = 30_000L
    }
}

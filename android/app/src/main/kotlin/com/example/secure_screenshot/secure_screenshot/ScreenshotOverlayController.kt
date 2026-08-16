package com.example.secure_screenshot.secure_screenshot

import android.content.Context
import android.graphics.Bitmap
import android.graphics.PixelFormat
import android.net.Uri
import android.os.Handler
import android.os.Looper
import android.provider.Settings
import android.view.ContextThemeWrapper
import android.view.Gravity
import android.view.LayoutInflater
import android.view.View
import android.view.WindowManager
import android.widget.Button
import android.widget.ImageView
import android.widget.NumberPicker
import android.widget.TextView
import java.text.SimpleDateFormat
import java.util.Calendar
import java.util.Locale

/**
 * Draws the 4-option prompt directly on screen via TYPE_APPLICATION_OVERLAY - no
 * notification involved. Requires the user to have granted "display over other apps"
 * (SYSTEM_ALERT_WINDOW) once; without it this silently no-ops and the item just sits as
 * PENDING_CHOICE until the service's no-response timeout applies the configured default.
 * Owned by the (single, foreground) detection service, so it works with the Flutter UI
 * never having been opened.
 */
object ScreenshotOverlayController {
    private val mainHandler = Handler(Looper.getMainLooper())
    private var windowManager: WindowManager? = null
    private var currentView: View? = null
    private var currentId: Long? = null
    private val queue = ArrayDeque<Long>()

    fun show(context: Context, screenshot: ManagedScreenshot, thumbnail: Bitmap?) {
        val appContext = context.applicationContext
        if (!Settings.canDrawOverlays(appContext)) return

        mainHandler.post {
            if (currentView != null) {
                if (currentId != screenshot.id && !queue.contains(screenshot.id)) {
                    queue.addLast(screenshot.id)
                }
            } else {
                displayNow(appContext, screenshot, thumbnail)
            }
        }
    }

    /** Called by the service's no-response timeout so a stale overlay never lingers. */
    fun dismissIfShowing(context: Context, id: Long) {
        mainHandler.post {
            if (currentId == id) {
                removeCurrent(context.applicationContext)
            } else {
                queue.remove(id)
            }
        }
    }

    private fun displayNow(context: Context, screenshot: ManagedScreenshot, thumbnail: Bitmap?) {
        val wm = context.getSystemService(Context.WINDOW_SERVICE) as WindowManager
        val themedContext = ContextThemeWrapper(context, android.R.style.Theme_Material_Light)
        val root = LayoutInflater.from(themedContext).inflate(R.layout.overlay_screenshot_prompt, null)

        val params = WindowManager.LayoutParams(
            WindowManager.LayoutParams.MATCH_PARENT,
            WindowManager.LayoutParams.MATCH_PARENT,
            WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY,
            WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN,
            PixelFormat.TRANSLUCENT,
        )
        params.gravity = Gravity.TOP or Gravity.START

        try {
            wm.addView(root, params)
        } catch (e: Exception) {
            return
        }

        windowManager = wm
        currentView = root
        currentId = screenshot.id

        applyThumbnail(root, thumbnail)
        wireButtons(context, root, screenshot.id)
    }

    private fun applyThumbnail(root: View, thumbnail: Bitmap?) {
        if (thumbnail != null) {
            root.findViewById<ImageView>(R.id.thumbnail).setImageBitmap(thumbnail)
        }
    }

    private fun wireButtons(context: Context, root: View, id: Long) {
        root.findViewById<Button>(R.id.btnKeep).setOnClickListener { resolveKeep(context, id) }
        root.findViewById<Button>(R.id.btnDelete1Min).setOnClickListener { resolveSchedule(context, id, 60_000L) }
        root.findViewById<Button>(R.id.btnDelete3Min).setOnClickListener { resolveSchedule(context, id, 180_000L) }
        root.findViewById<Button>(R.id.btnCustom).setOnClickListener { showCustomPicker(root) }
        root.findViewById<Button>(R.id.btnCustomCancel).setOnClickListener { hideCustomPicker(root) }
        root.findViewById<Button>(R.id.btnCustomConfirm).setOnClickListener {
            val durationMillis = customDurationMillis(root)
            if (durationMillis > 0) resolveSchedule(context, id, durationMillis)
        }
    }

    private fun showCustomPicker(root: View) {
        root.findViewById<View>(R.id.choiceButtons).visibility = View.GONE
        root.findViewById<View>(R.id.customPicker).visibility = View.VISIBLE

        val hours = root.findViewById<NumberPicker>(R.id.pickerHours).apply { minValue = 0; maxValue = 23; value = 0 }
        val minutes = root.findViewById<NumberPicker>(R.id.pickerMinutes).apply { minValue = 0; maxValue = 59; value = 5 }
        val seconds = root.findViewById<NumberPicker>(R.id.pickerSeconds).apply { minValue = 0; maxValue = 59; value = 0 }

        val listener = NumberPicker.OnValueChangeListener { _, _, _ -> updateDeletesAtPreview(root) }
        hours.setOnValueChangedListener(listener)
        minutes.setOnValueChangedListener(listener)
        seconds.setOnValueChangedListener(listener)
        updateDeletesAtPreview(root)
    }

    private fun hideCustomPicker(root: View) {
        root.findViewById<View>(R.id.customPicker).visibility = View.GONE
        root.findViewById<View>(R.id.choiceButtons).visibility = View.VISIBLE
    }

    private fun customDurationMillis(root: View): Long {
        val hours = root.findViewById<NumberPicker>(R.id.pickerHours).value
        val minutes = root.findViewById<NumberPicker>(R.id.pickerMinutes).value
        val seconds = root.findViewById<NumberPicker>(R.id.pickerSeconds).value
        return (hours * 3600L + minutes * 60L + seconds) * 1000L
    }

    private fun updateDeletesAtPreview(root: View) {
        val durationMillis = customDurationMillis(root)
        val preview = root.findViewById<TextView>(R.id.deletesAtPreview)
        if (durationMillis <= 0) {
            preview.text = "Pick a duration above 0 seconds"
            return
        }
        val calendar = Calendar.getInstance().apply { timeInMillis = System.currentTimeMillis() + durationMillis }
        preview.text = "Deletes at ${SimpleDateFormat("h:mm:ss a", Locale.getDefault()).format(calendar.time)}"
    }

    private fun resolveKeep(context: Context, id: Long) {
        Thread {
            // Kept screenshots aren't tracked at all - nothing left for this app to do
            // with them, so there's no reason to keep a row (or show one) for it.
            ManagedScreenshotStore.get(context).remove(id)
            ScreenshotEventBus.notifyChanged()
        }.start()
        removeCurrent(context)
    }

    private fun resolveSchedule(context: Context, id: Long, durationMillis: Long) {
        val deleteAt = System.currentTimeMillis() + durationMillis
        Thread {
            ManagedScreenshotStore.get(context).setChoice(id, ScreenshotStatus.SCHEDULED, deleteAt)
            AlarmScheduler.schedule(context, id, deleteAt)
            ScreenshotEventBus.notifyChanged()
        }.start()
        removeCurrent(context)
    }

    private fun removeCurrent(context: Context) {
        val wm = windowManager
        val view = currentView
        if (wm != null && view != null) {
            try {
                wm.removeView(view)
            } catch (e: Exception) {
                // View already detached (e.g. permission revoked mid-display); safe to ignore.
            }
        }
        currentView = null
        currentId = null
        showNextFromQueue(context)
    }

    private fun showNextFromQueue(context: Context) {
        val nextId = queue.removeFirstOrNull() ?: return
        val store = ManagedScreenshotStore.get(context)
        Thread {
            val screenshot = store.getById(nextId)
            if (screenshot == null || screenshot.status != ScreenshotStatus.PENDING_CHOICE) {
                mainHandler.post { showNextFromQueue(context) }
                return@Thread
            }
            val thumbnail = MediaThumbnails.load(context, Uri.parse(screenshot.mediaUri))
            mainHandler.post { displayNow(context, screenshot, thumbnail) }
        }.start()
    }
}

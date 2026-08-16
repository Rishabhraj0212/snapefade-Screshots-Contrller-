package com.example.secure_screenshot.secure_screenshot

import android.content.Context
import android.net.Uri
import android.util.Log

/**
 * Deletes everything currently due, with no notification and no per-item confirmation
 * dialog. This only works because the app holds MANAGE_EXTERNAL_STORAGE ("All files
 * access") - without it, ContentResolver.delete() on a file this app doesn't own (the
 * screenshot was inserted by System UI, not by this app) throws, since Android normally
 * requires a user-confirmed MediaStore.createDeleteRequest() for that. If that permission
 * hasn't been granted, deletion here simply fails and the item is left as
 * NEEDS_CONFIRMATION so it's visible in the app rather than silently stuck.
 */
object SilentDeleter {
    private const val TAG = "SilentDeleter"

    fun deleteDueNow(context: Context) {
        val store = ManagedScreenshotStore.get(context)
        val due = store.getDue(System.currentTimeMillis())
        if (due.isEmpty()) return

        val deleted = mutableListOf<Long>()
        val failed = mutableListOf<Long>()
        for (item in due) {
            try {
                context.contentResolver.delete(Uri.parse(item.mediaUri), null, null)
                deleted.add(item.id)
            } catch (e: Exception) {
                Log.e(TAG, "Failed to delete screenshot ${item.id} - is MANAGE_EXTERNAL_STORAGE granted?", e)
                failed.add(item.id)
            }
        }
        // Successfully deleted rows are dropped outright - nothing left to show for
        // them. Failures are kept (and flagged) since they still need the user's
        // attention (most likely: MANAGE_EXTERNAL_STORAGE isn't granted).
        if (deleted.isNotEmpty()) store.removeAll(deleted)
        if (failed.isNotEmpty()) store.markStatus(failed, ScreenshotStatus.NEEDS_CONFIRMATION)
        ScreenshotEventBus.notifyChanged()
    }
}

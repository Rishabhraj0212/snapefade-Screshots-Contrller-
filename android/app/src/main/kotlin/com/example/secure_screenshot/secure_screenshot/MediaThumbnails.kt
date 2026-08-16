package com.example.secure_screenshot.secure_screenshot

import android.content.Context
import android.graphics.Bitmap
import android.net.Uri
import android.os.Build
import android.util.Size

object MediaThumbnails {
    /** Never persisted to disk - decoded fresh on demand purely to show on screen. */
    fun load(context: Context, uri: Uri, size: Size = Size(256, 256)): Bitmap? {
        return try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                context.contentResolver.loadThumbnail(uri, size, null)
            } else {
                null
            }
        } catch (e: Exception) {
            null
        }
    }
}

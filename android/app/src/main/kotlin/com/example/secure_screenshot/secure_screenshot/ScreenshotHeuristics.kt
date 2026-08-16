package com.example.secure_screenshot.secure_screenshot

/**
 * Android has no public "screenshot taken" event. This is the same heuristic every
 * third-party screenshot-utility app uses: a newly-inserted MediaStore image row whose
 * relative path or display name matches the conventional screenshot locations/names,
 * and which was added within [recentWindowSec] of when we observed the change. The
 * recency check is what stops us from reacting to bulk imports, gallery restores, or
 * pre-existing photos - only genuinely new rows are ever considered.
 */
object ScreenshotHeuristics {
    private const val DEFAULT_RECENT_WINDOW_SEC = 15L

    // AOSP default is "Pictures/Screenshots"; Samsung and several OEMs use "DCIM/Screenshots".
    private val SCREENSHOT_PATH_PREFIXES = listOf(
        "Pictures/Screenshots",
        "DCIM/Screenshots",
    )

    fun isLikelyScreenshot(
        relativePath: String?,
        displayName: String?,
        dateAddedSec: Long,
        nowSec: Long,
        recentWindowSec: Long = DEFAULT_RECENT_WINDOW_SEC,
    ): Boolean {
        val isRecent = (nowSec - dateAddedSec) in 0..recentWindowSec
        if (!isRecent) return false

        val pathMatches = relativePath != null && SCREENSHOT_PATH_PREFIXES.any {
            relativePath.startsWith(it, ignoreCase = true)
        }
        // Some OEMs (e.g. some MIUI builds) drop screenshots straight into DCIM/Pictures
        // root instead of a Screenshots subfolder, only distinguishable by file name.
        val nameMatches = displayName != null && displayName.startsWith("Screenshot", ignoreCase = true)

        return pathMatches || nameMatches
    }
}

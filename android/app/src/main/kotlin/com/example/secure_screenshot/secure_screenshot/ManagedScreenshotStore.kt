package com.example.secure_screenshot.secure_screenshot

import android.content.ContentValues
import android.content.Context
import android.database.sqlite.SQLiteDatabase
import android.database.sqlite.SQLiteOpenHelper

enum class ScreenshotStatus {
    PENDING_CHOICE,
    SCHEDULED,
    KEPT,
    DELETED,
    NEEDS_CONFIRMATION;

    companion object {
        fun fromDb(value: String): ScreenshotStatus = valueOf(value)
    }
}

data class ManagedScreenshot(
    val id: Long,
    val mediaUri: String,
    val displayName: String,
    val dateAddedSec: Long,
    val status: ScreenshotStatus,
    val deleteAtMillis: Long?,
) {
    fun toMap(): Map<String, Any?> = mapOf(
        "id" to id.toString(),
        "mediaUri" to mediaUri,
        "displayName" to displayName,
        "dateAddedMillis" to dateAddedSec * 1000L,
        "status" to status.name,
        "deleteAtMillis" to deleteAtMillis,
    )
}

/** Durable source of truth for detected screenshots and their scheduled deletion state. */
class ManagedScreenshotStore private constructor(context: Context) :
    SQLiteOpenHelper(context.applicationContext, DB_NAME, null, DB_VERSION) {

    override fun onCreate(db: SQLiteDatabase) {
        db.execSQL(
            """
            CREATE TABLE $TABLE (
                $COL_ID INTEGER PRIMARY KEY AUTOINCREMENT,
                $COL_URI TEXT NOT NULL UNIQUE,
                $COL_NAME TEXT NOT NULL,
                $COL_DATE_ADDED INTEGER NOT NULL,
                $COL_STATUS TEXT NOT NULL,
                $COL_DELETE_AT INTEGER
            )
            """.trimIndent()
        )
    }

    override fun onUpgrade(db: SQLiteDatabase, oldVersion: Int, newVersion: Int) {
        db.execSQL("DROP TABLE IF EXISTS $TABLE")
        onCreate(db)
    }

    /** Returns the row id, or null if this URI is already tracked. */
    fun insertDetected(mediaUri: String, displayName: String, dateAddedSec: Long): Long? {
        val values = ContentValues().apply {
            put(COL_URI, mediaUri)
            put(COL_NAME, displayName)
            put(COL_DATE_ADDED, dateAddedSec)
            put(COL_STATUS, ScreenshotStatus.PENDING_CHOICE.name)
        }
        val id = writableDatabase.insertWithOnConflict(
            TABLE, null, values, SQLiteDatabase.CONFLICT_IGNORE
        )
        return if (id == -1L) null else id
    }

    fun setChoice(id: Long, status: ScreenshotStatus, deleteAtMillis: Long?) {
        val values = ContentValues().apply {
            put(COL_STATUS, status.name)
            if (deleteAtMillis != null) put(COL_DELETE_AT, deleteAtMillis) else putNull(COL_DELETE_AT)
        }
        writableDatabase.update(TABLE, values, "$COL_ID = ?", arrayOf(id.toString()))
    }

    fun markStatus(ids: List<Long>, status: ScreenshotStatus) {
        if (ids.isEmpty()) return
        val db = writableDatabase
        db.beginTransaction()
        try {
            val values = ContentValues().apply { put(COL_STATUS, status.name) }
            for (id in ids) {
                db.update(TABLE, values, "$COL_ID = ?", arrayOf(id.toString()))
            }
            db.setTransactionSuccessful()
        } finally {
            db.endTransaction()
        }
    }

    /**
     * Drops the row entirely rather than marking it KEPT/DELETED. Once a screenshot is
     * resolved either way there's nothing left to track or show - the app only ever
     * lists what's still pending a choice, currently scheduled, or needs attention.
     */
    fun remove(id: Long) {
        writableDatabase.delete(TABLE, "$COL_ID = ?", arrayOf(id.toString()))
    }

    fun removeAll(ids: List<Long>) {
        if (ids.isEmpty()) return
        val db = writableDatabase
        db.beginTransaction()
        try {
            for (id in ids) {
                db.delete(TABLE, "$COL_ID = ?", arrayOf(id.toString()))
            }
            db.setTransactionSuccessful()
        } finally {
            db.endTransaction()
        }
    }

    fun getById(id: Long): ManagedScreenshot? {
        readableDatabase.query(
            TABLE, null, "$COL_ID = ?", arrayOf(id.toString()), null, null, null
        ).use { cursor ->
            return if (cursor.moveToFirst()) cursor.toManagedScreenshot() else null
        }
    }

    fun getAll(): List<ManagedScreenshot> {
        val result = mutableListOf<ManagedScreenshot>()
        readableDatabase.query(
            TABLE, null, null, null, null, null, "$COL_DATE_ADDED DESC"
        ).use { cursor ->
            while (cursor.moveToNext()) result.add(cursor.toManagedScreenshot())
        }
        return result
    }

    /** Everything currently scheduled and due at or before [nowMillis]. */
    fun getDue(nowMillis: Long): List<ManagedScreenshot> {
        val result = mutableListOf<ManagedScreenshot>()
        readableDatabase.query(
            TABLE, null,
            "$COL_STATUS = ? AND $COL_DELETE_AT <= ?",
            arrayOf(ScreenshotStatus.SCHEDULED.name, nowMillis.toString()),
            null, null, null
        ).use { cursor ->
            while (cursor.moveToNext()) result.add(cursor.toManagedScreenshot())
        }
        return result
    }

    /** Everything still scheduled, due or not - used to re-arm alarms after boot. */
    fun getAllScheduled(): List<ManagedScreenshot> {
        val result = mutableListOf<ManagedScreenshot>()
        readableDatabase.query(
            TABLE, null, "$COL_STATUS = ?", arrayOf(ScreenshotStatus.SCHEDULED.name),
            null, null, null
        ).use { cursor ->
            while (cursor.moveToNext()) result.add(cursor.toManagedScreenshot())
        }
        return result
    }

    private fun android.database.Cursor.toManagedScreenshot(): ManagedScreenshot {
        val deleteAtIdx = getColumnIndexOrThrow(COL_DELETE_AT)
        return ManagedScreenshot(
            id = getLong(getColumnIndexOrThrow(COL_ID)),
            mediaUri = getString(getColumnIndexOrThrow(COL_URI)),
            displayName = getString(getColumnIndexOrThrow(COL_NAME)),
            dateAddedSec = getLong(getColumnIndexOrThrow(COL_DATE_ADDED)),
            status = ScreenshotStatus.fromDb(getString(getColumnIndexOrThrow(COL_STATUS))),
            deleteAtMillis = if (isNull(deleteAtIdx)) null else getLong(deleteAtIdx),
        )
    }

    companion object {
        private const val DB_NAME = "managed_screenshots.db"
        private const val DB_VERSION = 1
        private const val TABLE = "managed_screenshots"
        private const val COL_ID = "id"
        private const val COL_URI = "media_uri"
        private const val COL_NAME = "display_name"
        private const val COL_DATE_ADDED = "date_added_sec"
        private const val COL_STATUS = "status"
        private const val COL_DELETE_AT = "delete_at_millis"

        @Volatile
        private var instance: ManagedScreenshotStore? = null

        fun get(context: Context): ManagedScreenshotStore =
            instance ?: synchronized(this) {
                instance ?: ManagedScreenshotStore(context).also { instance = it }
            }
    }
}

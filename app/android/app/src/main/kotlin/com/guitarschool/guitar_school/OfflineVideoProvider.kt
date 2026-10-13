package com.guitarschool.guitar_school

import android.content.ContentProvider
import android.content.ContentValues
import android.database.Cursor
import android.net.Uri
import android.os.Build
import android.os.Handler
import android.os.HandlerThread
import android.os.ParcelFileDescriptor
import android.os.ProxyFileDescriptorCallback
import android.os.storage.StorageManager
import android.system.ErrnoException
import android.system.OsConstants
import androidx.annotation.RequiresApi
import java.io.File
import java.io.FileNotFoundException
import java.io.RandomAccessFile
import javax.crypto.Cipher
import javax.crypto.SecretKey

/**
 * Отдаёт плееру сохранённое видео: content://<applicationId>.offline/v/<id урока>.
 * Провайдер не экспортирован — открыть его может только само приложение.
 * Плеер получает «виртуальный» файл: каждый прочитанный кусок расшифровывается
 * в памяти, расшифрованная копия на диск не пишется.
 */
class OfflineVideoProvider : ContentProvider() {
    override fun onCreate() = true

    override fun openFile(uri: Uri, mode: String): ParcelFileDescriptor {
        if (mode != "r" || Build.VERSION.SDK_INT < Build.VERSION_CODES.O) throw FileNotFoundException()
        return open(uri)
    }

    @RequiresApi(Build.VERSION_CODES.O)
    private fun open(uri: Uri): ParcelFileDescriptor {
        val context = context ?: throw FileNotFoundException()
        val lessonId = uri.lastPathSegment ?: throw FileNotFoundException()
        val file = try {
            OfflineVideos.file(context, lessonId)
        } catch (e: IllegalArgumentException) {
            throw FileNotFoundException()
        }
        if (!file.exists()) throw FileNotFoundException()
        val reader = try {
            DecryptingReader(file, OfflineVideos.dataKey(context))
        } catch (e: Exception) {
            throw FileNotFoundException()
        }
        val storage = context.getSystemService(StorageManager::class.java)
        return storage.openProxyFileDescriptor(ParcelFileDescriptor.MODE_READ_ONLY, reader, handler)
    }

    override fun getType(uri: Uri): String = "video/*"

    override fun query(
        uri: Uri,
        projection: Array<out String>?,
        selection: String?,
        selectionArgs: Array<out String>?,
        sortOrder: String?,
    ): Cursor? = null

    override fun insert(uri: Uri, values: ContentValues?): Uri? = null

    override fun delete(uri: Uri, selection: String?, selectionArgs: Array<out String>?) = 0

    override fun update(
        uri: Uri,
        values: ContentValues?,
        selection: String?,
        selectionArgs: Array<out String>?,
    ) = 0

    companion object {
        /** Поток, в котором расшифровываются куски для плеера. */
        private val handler by lazy {
            Handler(HandlerThread("offline-video").apply { start() }.looper)
        }
    }
}

@RequiresApi(Build.VERSION_CODES.O)
private class DecryptingReader(file: File, private val key: SecretKey) : ProxyFileDescriptorCallback() {
    private val raf = RandomAccessFile(file, "r")
    private val iv = OfflineVideos.readIv(raf) ?: run {
        raf.close()
        throw IllegalStateException("not an offline video")
    }
    private val videoSize = file.length() - OfflineVideos.HEADER
    private var buf = ByteArray(0)

    // Плеер обычно читает подряд — тогда шифр продолжает с того же места.
    private var cipher: Cipher? = null
    private var next = -1L

    override fun onGetSize() = videoSize

    override fun onRead(offset: Long, size: Int, data: ByteArray): Int {
        val n = minOf(size.toLong(), videoSize - offset).toInt()
        if (n <= 0) return 0
        try {
            if (buf.size < n) buf = ByteArray(n)
            raf.seek(OfflineVideos.HEADER + offset)
            raf.readFully(buf, 0, n)
            val c = cipher.takeIf { offset == next }
                ?: OfflineVideos.ctrCipher(key, iv, offset).also { cipher = it }
            c.update(buf, 0, n, data, 0)
            next = offset + n
            return n
        } catch (e: Exception) {
            cipher = null
            next = -1
            throw ErrnoException("onRead", OsConstants.EIO)
        }
    }

    override fun onRelease() {
        raf.close()
    }
}

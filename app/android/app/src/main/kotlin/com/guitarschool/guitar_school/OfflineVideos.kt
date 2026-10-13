package com.guitarschool.guitar_school

import android.content.Context
import android.os.Build
import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyProperties
import android.util.Base64
import androidx.annotation.RequiresApi
import java.io.File
import java.io.IOException
import java.io.RandomAccessFile
import java.net.HttpURLConnection
import java.net.URL
import java.security.KeyStore
import java.security.SecureRandom
import javax.crypto.Cipher
import javax.crypto.KeyGenerator
import javax.crypto.SecretKey
import javax.crypto.spec.GCMParameterSpec
import javax.crypto.spec.IvParameterSpec
import javax.crypto.spec.SecretKeySpec

/**
 * Видео уроков, сохранённые для просмотра без интернета.
 *
 * Файлы лежат в noBackupFilesDir/offline: закрытая папка приложения — её не видно
 * в галерее, в «Файлах» и по USB, в резервные копии она не попадает.
 * Видео зашифровано AES-256-CTR. Ключ данных случайный и хранится зашифрованным
 * ключом из Android Keystore, который не покидает телефон: скопированные файлы
 * на другом устройстве не расшифровать. Расшифровка — только кусками в памяти,
 * во время просмотра (см. [OfflineVideoProvider]); CTR позволяет начать с любого
 * места, поэтому перемотка не требует расшифровки всего файла.
 *
 * Формат файла: "GSV1" + IV (16 байт) + зашифрованное видео.
 */
@RequiresApi(Build.VERSION_CODES.O)
object OfflineVideos {
    const val HEADER = 20
    private const val MAGIC = "GSV1"
    private const val KEYSTORE_ALIAS = "guitar_school_offline"
    private const val PREFS = "offline_videos"
    private const val PREF_DATA_KEY = "data_key"

    /** Сколько места оставлять свободным на телефоне. */
    private const val RESERVE_BYTES = 200L * 1024 * 1024
    private val LESSON_ID = Regex("^[A-Za-z0-9_-]{1,64}$")

    @Volatile
    private var cachedKey: SecretKey? = null

    private fun dir(context: Context) = File(context.noBackupFilesDir, "offline").apply { mkdirs() }

    fun file(context: Context, lessonId: String): File {
        require(LESSON_ID.matches(lessonId)) { "bad lesson id" }
        return File(dir(context), "$lessonId.gsv")
    }

    private fun partFile(context: Context, lessonId: String): File {
        require(LESSON_ID.matches(lessonId)) { "bad lesson id" }
        return File(dir(context), "$lessonId.part")
    }

    /** Сохранённые уроки: id → размер видео в байтах. */
    fun saved(context: Context): Map<String, Long> =
        dir(context).listFiles { f -> f.name.endsWith(".gsv") }
            ?.associate { it.name.removeSuffix(".gsv") to (it.length() - HEADER) }
            ?: emptyMap()

    fun delete(context: Context, lessonId: String) {
        file(context, lessonId).delete()
        partFile(context, lessonId).delete()
    }

    fun deleteAll(context: Context) {
        dir(context).listFiles()?.forEach { it.delete() }
    }

    /**
     * Скачивает видео по временной ссылке и сохраняет зашифрованным.
     * Прерванная загрузка продолжается с того же места.
     */
    fun download(context: Context, lessonId: String, url: String, onProgress: (Long, Long) -> Unit) {
        val done = file(context, lessonId)
        if (done.exists()) return
        val part = partFile(context, lessonId)
        val key = dataKey(context)

        var iv: ByteArray? = null
        var have = 0L
        if (part.length() >= HEADER) {
            RandomAccessFile(part, "r").use { raf ->
                val head = ByteArray(HEADER)
                raf.readFully(head)
                if (String(head, 0, 4, Charsets.US_ASCII) == MAGIC) {
                    iv = head.copyOfRange(4, HEADER)
                    have = part.length() - HEADER
                }
            }
        }

        val conn = URL(url).openConnection() as HttpURLConnection
        conn.connectTimeout = 20_000
        conn.readTimeout = 30_000
        if (have > 0) conn.setRequestProperty("Range", "bytes=$have-")
        try {
            when (conn.responseCode) {
                HttpURLConnection.HTTP_PARTIAL -> if (have == 0L) throw IOException("unexpected 206")
                HttpURLConnection.HTTP_OK -> { // сервер отдаёт файл целиком — начинаем заново
                    have = 0
                    iv = null
                }
                416 -> { // недокачанный кусок не совпал с файлом на сервере
                    part.delete()
                    throw IOException("HTTP 416")
                }
                else -> throw IOException("HTTP ${conn.responseCode}")
            }
            val remaining = conn.contentLengthLong
            val total = if (remaining >= 0) have + remaining else -1L
            if (remaining > 0 && dir(context).usableSpace < remaining + RESERVE_BYTES) {
                throw IOException("no_space")
            }

            val ivBytes = iv ?: newIv()
            RandomAccessFile(part, "rw").use { raf ->
                if (have == 0L) {
                    raf.setLength(0)
                    raf.write(MAGIC.toByteArray(Charsets.US_ASCII))
                    raf.write(ivBytes)
                } else {
                    raf.setLength(HEADER + have)
                    raf.seek(HEADER + have)
                }
                val cipher = ctrCipher(key, ivBytes, have)
                val buf = ByteArray(256 * 1024)
                val out = ByteArray(buf.size)
                var reported = have
                conn.inputStream.use { input ->
                    while (true) {
                        val n = input.read(buf)
                        if (n < 0) break
                        val m = cipher.update(buf, 0, n, out, 0)
                        raf.write(out, 0, m)
                        have += n
                        if (have - reported >= 1_000_000) {
                            onProgress(have, total)
                            reported = have
                        }
                    }
                }
            }
            if (total >= 0 && have != total) throw IOException("incomplete")
            if (!part.renameTo(done)) throw IOException("rename failed")
            onProgress(have, have)
        } finally {
            conn.disconnect()
        }
    }

    /** Заголовок сохранённого файла: IV или null, если файл не наш. */
    fun readIv(raf: RandomAccessFile): ByteArray? {
        val head = ByteArray(HEADER)
        raf.seek(0)
        raf.readFully(head)
        if (String(head, 0, 4, Charsets.US_ASCII) != MAGIC) return null
        return head.copyOfRange(4, HEADER)
    }

    /**
     * AES-CTR, начиная с байта [offset] видео. IV — 8 случайных байт и 8 нулевых:
     * счётчик блоков живёт в младших 8 байтах и не переполняется.
     */
    fun ctrCipher(key: SecretKey, iv: ByteArray, offset: Long): Cipher {
        val counter = iv.copyOf()
        var carry = offset / 16
        var i = 15
        while (carry != 0L && i >= 0) {
            val sum = (counter[i].toLong() and 0xFF) + (carry and 0xFF)
            counter[i] = sum.toByte()
            carry = (carry ushr 8) + (sum ushr 8)
            i--
        }
        val cipher = Cipher.getInstance("AES/CTR/NoPadding")
        cipher.init(Cipher.ENCRYPT_MODE, key, IvParameterSpec(counter))
        val skip = (offset % 16).toInt()
        if (skip > 0) cipher.update(ByteArray(skip))
        return cipher
    }

    private fun newIv() = ByteArray(16).also { SecureRandom().nextBytes(it); it.fill(0, 8, 16) }

    /** Ключ данных; создаётся при первом скачивании. */
    @Synchronized
    fun dataKey(context: Context): SecretKey {
        cachedKey?.let { return it }
        val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        prefs.getString(PREF_DATA_KEY, null)?.let { stored ->
            try {
                val bytes = Base64.decode(stored, Base64.NO_WRAP)
                val cipher = Cipher.getInstance("AES/GCM/NoPadding")
                cipher.init(Cipher.DECRYPT_MODE, keystoreKey(), GCMParameterSpec(128, bytes, 0, 12))
                val raw = cipher.doFinal(bytes, 12, bytes.size - 12)
                return SecretKeySpec(raw, "AES").also { cachedKey = it }
            } catch (e: Exception) {
                // Данные приложения попали на другой телефон или ключ Keystore сброшен:
                // старые файлы уже не расшифровать — удаляем и начинаем заново.
                deleteAll(context)
            }
        }
        val raw = ByteArray(32).also { SecureRandom().nextBytes(it) }
        val cipher = Cipher.getInstance("AES/GCM/NoPadding")
        cipher.init(Cipher.ENCRYPT_MODE, keystoreKey())
        val wrapped = cipher.iv + cipher.doFinal(raw)
        prefs.edit().putString(PREF_DATA_KEY, Base64.encodeToString(wrapped, Base64.NO_WRAP)).apply()
        return SecretKeySpec(raw, "AES").also { cachedKey = it }
    }

    private fun keystoreKey(): SecretKey {
        val keyStore = KeyStore.getInstance("AndroidKeyStore").apply { load(null) }
        (keyStore.getKey(KEYSTORE_ALIAS, null) as? SecretKey)?.let { return it }
        val generator = KeyGenerator.getInstance(KeyProperties.KEY_ALGORITHM_AES, "AndroidKeyStore")
        generator.init(
            KeyGenParameterSpec.Builder(
                KEYSTORE_ALIAS,
                KeyProperties.PURPOSE_ENCRYPT or KeyProperties.PURPOSE_DECRYPT,
            )
                .setBlockModes(KeyProperties.BLOCK_MODE_GCM)
                .setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_NONE)
                .setKeySize(256)
                .build(),
        )
        return generator.generateKey()
    }
}

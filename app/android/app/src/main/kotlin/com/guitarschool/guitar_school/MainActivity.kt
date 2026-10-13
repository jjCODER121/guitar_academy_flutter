package com.guitarschool.guitar_school

import android.os.Build
import android.os.Handler
import android.os.Looper
import android.provider.Settings
import android.view.WindowManager
import androidx.annotation.RequiresApi
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.Executors

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val messenger = flutterEngine.dartExecutor.binaryMessenger
        MethodChannel(messenger, "guitar_school/device")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    // Android ID: постоянный номер устройства для этого приложения.
                    // Серийный номер и IMEI с Android 10 приложениям недоступны.
                    "androidId" -> result.success(
                        Settings.Secure.getString(contentResolver, Settings.Secure.ANDROID_ID)
                    )
                    // Запрет скриншотов и записи экрана на экранах с видео и PDF.
                    "setSecure" -> {
                        val on = call.arguments as? Boolean ?: false
                        runOnUiThread {
                            if (on) {
                                window.addFlags(WindowManager.LayoutParams.FLAG_SECURE)
                            } else {
                                window.clearFlags(WindowManager.LayoutParams.FLAG_SECURE)
                            }
                        }
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }

        val offline = MethodChannel(messenger, "guitar_school/offline")
        offline.setMethodCallHandler { call, result ->
            // Видео без интернета — с Android 8 (нужен «виртуальный» файл для плеера).
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                handleOffline(offline, call, result)
            } else if (call.method == "supported") {
                result.success(false)
            } else {
                result.notImplemented()
            }
        }
    }

    @RequiresApi(Build.VERSION_CODES.O)
    private fun handleOffline(channel: MethodChannel, call: MethodCall, result: MethodChannel.Result) {
        val lessonId = call.argument<String>("lessonId")
        when (call.method) {
            "supported" -> result.success(true)
            "saved" -> io.execute {
                val saved = OfflineVideos.saved(applicationContext)
                main.post { result.success(saved) }
            }
            "uri" -> result.success("content://$packageName.offline/v/$lessonId")
            "download" -> {
                val url = call.argument<String>("url")!!
                downloads.execute {
                    try {
                        OfflineVideos.download(applicationContext, lessonId!!, url) { received, total ->
                            main.post {
                                channel.invokeMethod(
                                    "progress",
                                    mapOf("lessonId" to lessonId, "received" to received, "total" to total),
                                )
                            }
                        }
                        main.post { result.success(null) }
                    } catch (e: Exception) {
                        main.post { result.error("download_failed", e.message, null) }
                    }
                }
            }
            "delete" -> io.execute {
                OfflineVideos.delete(applicationContext, lessonId!!)
                main.post { result.success(null) }
            }
            "deleteAll" -> io.execute {
                OfflineVideos.deleteAll(applicationContext)
                main.post { result.success(null) }
            }
            else -> result.notImplemented()
        }
    }

    companion object {
        private val main = Handler(Looper.getMainLooper())

        /** Загрузки — по одной, чтобы не делить канал между несколькими видео. */
        private val downloads = Executors.newSingleThreadExecutor()
        private val io = Executors.newSingleThreadExecutor()
    }
}

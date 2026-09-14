package com.able.app.able_app

import android.content.ContentValues
import android.content.Intent
import android.media.MediaScannerConnection
import android.net.Uri
import android.os.Build
import android.os.Environment
import android.provider.MediaStore
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity: FlutterActivity() {
    private val CHANNEL = "com.able.app/gallery"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "scanFile", "saveToGallery" -> {
                    val path = call.argument<String>("path")
                    val isVideo = call.argument<Boolean>("isVideo") ?: true
                    if (path != null) {
                        try {
                            val file = File(path)
                            if (file.exists()) {
                                saveToMediaStore(file, isVideo)
                                MediaScannerConnection.scanFile(
                                    context,
                                    arrayOf(file.absolutePath),
                                    null
                                ) { scannedPath, uri -> }
                                result.success(true)
                            } else {
                                result.success(false)
                            }
                        } catch (e: Exception) {
                            result.error("SCAN_ERROR", e.message, null)
                        }
                    } else {
                        result.error("INVALID_PATH", "Path cannot be null", null)
                    }
                }
                "openInGallery" -> {
                    val path = call.argument<String>("path")
                    val isVideo = call.argument<Boolean>("isVideo") ?: true
                    try {
                        var launched = false
                        if (path != null) {
                            val file = File(path)
                            if (file.exists()) {
                                try {
                                    val uri = FileProvider.getUriForFile(
                                        context,
                                        "${context.packageName}.fileprovider",
                                        file
                                    )
                                    val intent = Intent(Intent.ACTION_VIEW).apply {
                                        setDataAndType(uri, if (isVideo) "video/*" else "audio/*")
                                        addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                                        addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                                    }
                                    context.startActivity(intent)
                                    launched = true
                                } catch (_: Exception) {
                                    try {
                                        val uri = Uri.fromFile(file)
                                        val intent = Intent(Intent.ACTION_VIEW).apply {
                                            setDataAndType(uri, if (isVideo) "video/*" else "audio/*")
                                            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                                            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                                        }
                                        context.startActivity(intent)
                                        launched = true
                                    } catch (_: Exception) {}
                                }
                            }
                        }

                        if (!launched) {
                            val galleryIntent = Intent(Intent.ACTION_VIEW).apply {
                                type = if (isVideo) "video/*" else "audio/*"
                                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                            }
                            context.startActivity(galleryIntent)
                        }
                        result.success(true)
                    } catch (e: Exception) {
                        try {
                            val appGalleryIntent = Intent(Intent.ACTION_MAIN).apply {
                                addCategory(Intent.CATEGORY_APP_GALLERY)
                                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                            }
                            context.startActivity(appGalleryIntent)
                            result.success(true)
                        } catch (e2: Exception) {
                            result.error("LAUNCH_FAILED", e2.message, null)
                        }
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun saveToMediaStore(file: File, isVideo: Boolean) {
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                val values = ContentValues().apply {
                    put(MediaStore.MediaColumns.DISPLAY_NAME, file.name)
                    put(MediaStore.MediaColumns.MIME_TYPE, if (isVideo) "video/mp4" else "audio/mpeg")
                    put(
                        MediaStore.MediaColumns.RELATIVE_PATH,
                        if (isVideo) Environment.DIRECTORY_MOVIES + "/Able" else Environment.DIRECTORY_MUSIC + "/Able"
                    )
                    put(MediaStore.MediaColumns.IS_PENDING, 1)
                }
                val collection = if (isVideo) {
                    MediaStore.Video.Media.getContentUri(MediaStore.VOLUME_EXTERNAL_PRIMARY)
                } else {
                    MediaStore.Audio.Media.getContentUri(MediaStore.VOLUME_EXTERNAL_PRIMARY)
                }
                val uri = context.contentResolver.insert(collection, values)
                if (uri != null) {
                    context.contentResolver.openOutputStream(uri)?.use { out ->
                        file.inputStream().use { input ->
                            input.copyTo(out)
                        }
                    }
                    values.clear()
                    values.put(MediaStore.MediaColumns.IS_PENDING, 0)
                    context.contentResolver.update(uri, values, null, null)
                }
            }
        } catch (_: Exception) {}
    }
}

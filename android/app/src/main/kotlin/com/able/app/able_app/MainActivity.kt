package com.able.app.able_app

import android.content.ContentValues
import android.media.MediaScannerConnection
import android.net.Uri
import android.os.Build
import android.os.Environment
import android.provider.MediaStore
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileInputStream
import java.io.FileOutputStream

class MainActivity: FlutterActivity() {
    private val CHANNEL = "com.able.app/gallery"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "scanFile" -> {
                    val path = call.argument<String>("path")
                    if (path != null) {
                        MediaScannerConnection.scanFile(
                            context,
                            arrayOf(path),
                            null
                        ) { scannedPath, uri -> }
                        result.success(true)
                    } else {
                        result.error("INVALID_PATH", "Path cannot be null", null)
                    }
                }
                "saveToGallery" -> {
                    val path = call.argument<String>("path")
                    val isVideo = call.argument<Boolean>("isVideo") ?: true
                    if (path != null) {
                        try {
                            val sourceFile = File(path)
                            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                                val values = ContentValues().apply {
                                    put(MediaStore.MediaColumns.DISPLAY_NAME, sourceFile.name)
                                    put(MediaStore.MediaColumns.MIME_TYPE, if (isVideo) "video/mp4" else "image/jpeg")
                                    put(MediaStore.MediaColumns.RELATIVE_PATH, if (isVideo) "${Environment.DIRECTORY_MOVIES}/Able" else "${Environment.DIRECTORY_PICTURES}/Able")
                                    put(MediaStore.MediaColumns.IS_PENDING, 1)
                                }
                                val collection = if (isVideo) {
                                    MediaStore.Video.Media.getContentUri(MediaStore.VOLUME_EXTERNAL_PRIMARY)
                                } else {
                                    MediaStore.Images.Media.getContentUri(MediaStore.VOLUME_EXTERNAL_PRIMARY)
                                }
                                val itemUri = contentResolver.insert(collection, values)
                                if (itemUri != null) {
                                    contentResolver.openOutputStream(itemUri)?.use { out ->
                                        FileInputStream(sourceFile).use { input ->
                                            input.copyTo(out)
                                        }
                                    }
                                    values.clear()
                                    values.put(MediaStore.MediaColumns.IS_PENDING, 0)
                                    contentResolver.update(itemUri, values, null, null)
                                }
                            } else {
                                val targetDir = File(Environment.getExternalStoragePublicDirectory(if (isVideo) Environment.DIRECTORY_MOVIES else Environment.DIRECTORY_PICTURES), "Able")
                                if (!targetDir.exists()) targetDir.mkdirs()
                                val targetFile = File(targetDir, sourceFile.name)
                                sourceFile.copyTo(targetFile, overwrite = true)
                                MediaScannerConnection.scanFile(context, arrayOf(targetFile.absolutePath), null, null)
                            }
                            MediaScannerConnection.scanFile(context, arrayOf(path), null, null)
                            result.success(true)
                        } catch (e: Exception) {
                            MediaScannerConnection.scanFile(context, arrayOf(path), null, null)
                            result.success(true)
                        }
                    } else {
                        result.error("INVALID_PATH", "Path is null", null)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }
}

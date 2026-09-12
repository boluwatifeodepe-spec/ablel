package com.able.app.able_app

import android.content.Intent
import android.media.MediaScannerConnection
import android.net.Uri
import android.os.Build
import android.os.Environment
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
                    if (path != null) {
                        try {
                            val file = File(path)
                            if (file.exists()) {
                                // Scan the single downloaded file so it appears immediately in the Gallery without creating duplicates
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
                                    // Try opening file via FileProvider or file URI
                                    val uri = Uri.fromFile(file)
                                    val intent = Intent(Intent.ACTION_VIEW).apply {
                                        setDataAndType(uri, if (isVideo) "video/*" else "image/*")
                                        addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                                        addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                                    }
                                    context.startActivity(intent)
                                    launched = true
                                } catch (_: Exception) {}
                            }
                        }

                        if (!launched) {
                            // Launch the phone's default Gallery / Photos application
                            val galleryIntent = Intent(Intent.ACTION_VIEW).apply {
                                type = if (isVideo) "video/*" else "image/*"
                                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                            }
                            context.startActivity(galleryIntent)
                        }
                        result.success(true)
                    } catch (e: Exception) {
                        try {
                            // Fallback to gallery intent category
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
}

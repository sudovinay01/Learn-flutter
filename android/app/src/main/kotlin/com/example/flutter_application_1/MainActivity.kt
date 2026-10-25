package com.example.flutter_application_1

import android.app.ActivityManager
import android.content.Context
import android.net.Uri
import android.os.Environment
import android.os.StatFs
import android.os.storage.StorageManager
import android.provider.DocumentsContract
import android.util.Log
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "mp4_title_cleaner/processing_resources"
        ).setMethodCallHandler { call, result ->
            if (call.method != "getResources") {
                result.notImplemented()
                return@setMethodCallHandler
            }

            val folderUri = call.argument<String>("folderUri")
            if (folderUri == null) {
                result.error("missing_folder", "A selected folder URI is required.", null)
                return@setMethodCallHandler
            }

            try {
                val activityManager =
                    getSystemService(Context.ACTIVITY_SERVICE) as ActivityManager
                val memoryInfo = ActivityManager.MemoryInfo()
                activityManager.getMemoryInfo(memoryInfo)

                result.success(
                    mapOf(
                        "availableProcessors" to Runtime.getRuntime().availableProcessors(),
                        "availableMemoryBytes" to memoryInfo.availMem,
                        "cacheAvailableBytes" to availableBytes(cacheDir),
                        "folderAvailableBytes" to availableBytesForFolder(Uri.parse(folderUri))
                    )
                )
            } catch (error: Exception) {
                result.error("resource_probe_failed", error.message, null)
            }
        }
    }

    private fun availableBytes(directory: java.io.File): Long? =
        try {
            if (directory.exists()) StatFs(directory.absolutePath).availableBytes else null
        } catch (error: Exception) {
            Log.w("Mp4ResourceProbe", "Could not determine free space.", error)
            null
        }

    private fun availableBytesForFolder(uri: Uri): Long? {
        if (uri.authority != "com.android.externalstorage.documents" ||
            !DocumentsContract.isTreeUri(uri)
        ) {
            return null
        }

        val documentId = DocumentsContract.getTreeDocumentId(uri)
        val volumeId = documentId.substringBefore(':')
        val storageManager = getSystemService(Context.STORAGE_SERVICE) as StorageManager
        val volumeDirectory = getExternalFilesDirs(null)
            .filterNotNull()
            .firstOrNull { appDirectory ->
                val volume = storageManager.getStorageVolume(appDirectory)
                if (volumeId.equals("primary", ignoreCase = true)) {
                    volume?.isPrimary == true
                } else {
                    volume?.uuid?.equals(volumeId, ignoreCase = true) == true
                }
            }

        val directory = volumeDirectory ?: if (
            volumeId.equals("primary", ignoreCase = true)
        ) {
            Environment.getExternalStorageDirectory()
        } else {
            return null
        }

        return availableBytes(directory)
    }
}

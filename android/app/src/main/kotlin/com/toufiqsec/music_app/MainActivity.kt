package com.toufiqsec.music_app

import android.app.DownloadManager
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.database.Cursor
import android.net.Uri
import android.os.Build
import android.os.Environment
import android.provider.Settings
import androidx.core.content.FileProvider
import com.ryanheise.audioservice.AudioServicePlugin
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.toufiqsec.music_app/installer"

    override fun provideFlutterEngine(context: Context): FlutterEngine? {
        return AudioServicePlugin.getFlutterEngine(context)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "getAppVersion" -> {
                    try {
                        @Suppress("DEPRECATION")
                        val pInfo = packageManager.getPackageInfo(packageName, 0)
                        val versionCode = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                            pInfo.longVersionCode
                        } else {
                            @Suppress("DEPRECATION")
                            pInfo.versionCode.toLong()
                        }
                        result.success(mapOf(
                            "versionName" to (pInfo.versionName ?: "1.0.0"),
                            "versionCode" to versionCode
                        ))
                    } catch (e: Exception) {
                        result.error("VERSION_ERROR", e.localizedMessage, null)
                    }
                }
                "canRequestPackageInstalls" -> {
                    val canInstall = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                        packageManager.canRequestPackageInstalls()
                    } else {
                        true
                    }
                    result.success(canInstall)
                }
                "openInstallPermissionSettings" -> {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                        val intent = Intent(Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES).apply {
                            data = Uri.parse("package:$packageName")
                            flags = Intent.FLAG_ACTIVITY_NEW_TASK
                        }
                        startActivity(intent)
                        result.success(true)
                    } else {
                        result.success(true)
                    }
                }
                "openUrl" -> {
                    val url = call.argument<String>("url")
                    if (url != null) {
                        try {
                            val intent = Intent(Intent.ACTION_VIEW, Uri.parse(url)).apply {
                                flags = Intent.FLAG_ACTIVITY_NEW_TASK
                            }
                            startActivity(intent)
                            result.success(true)
                        } catch (e: Exception) {
                            result.error("OPEN_ERROR", e.localizedMessage, null)
                        }
                    } else {
                        result.error("INVALID_URL", "URL cannot be null", null)
                    }
                }
                "startDownload" -> {
                    val url = call.argument<String>("url")
                    val fileName = call.argument<String>("fileName") ?: "music-app-update.apk"
                    val title = call.argument<String>("title") ?: "Music App Update"
                    val description = call.argument<String>("description") ?: "Downloading latest update..."

                    if (url == null) {
                        result.error("INVALID_URL", "URL cannot be null", null)
                        return@setMethodCallHandler
                    }

                    try {
                        val downloadManager = getSystemService(Context.DOWNLOAD_SERVICE) as DownloadManager
                        val destinationFile = File(getExternalFilesDir(Environment.DIRECTORY_DOWNLOADS), fileName)
                        if (destinationFile.exists()) {
                            destinationFile.delete()
                        }

                        val request = DownloadManager.Request(Uri.parse(url)).apply {
                            setTitle(title)
                            setDescription(description)
                            setNotificationVisibility(DownloadManager.Request.VISIBILITY_VISIBLE_NOTIFY_COMPLETED)
                            setDestinationInExternalFilesDir(this@MainActivity, Environment.DIRECTORY_DOWNLOADS, fileName)
                            setAllowedOverMetered(true)
                            setAllowedOverRoaming(true)
                        }

                        val downloadId = downloadManager.enqueue(request)
                        result.success(mapOf(
                            "downloadId" to downloadId,
                            "filePath" to destinationFile.absolutePath
                        ))
                    } catch (e: Exception) {
                        result.error("DOWNLOAD_ERROR", e.localizedMessage, null)
                    }
                }
                "getDownloadProgress" -> {
                    val downloadId = call.argument<Number>("downloadId")?.toLong()
                    if (downloadId == null) {
                        result.error("INVALID_ID", "Download ID cannot be null", null)
                        return@setMethodCallHandler
                    }

                    val downloadManager = getSystemService(Context.DOWNLOAD_SERVICE) as DownloadManager
                    val query = DownloadManager.Query().setFilterById(downloadId)
                    var cursor: Cursor? = null
                    try {
                        cursor = downloadManager.query(query)
                        if (cursor != null && cursor.moveToFirst()) {
                            val status = cursor.getInt(cursor.getColumnIndexOrThrow(DownloadManager.COLUMN_STATUS))
                            val bytesDownloaded = cursor.getLong(cursor.getColumnIndexOrThrow(DownloadManager.COLUMN_BYTES_DOWNLOADED_SO_FAR))
                            val bytesTotal = cursor.getLong(cursor.getColumnIndexOrThrow(DownloadManager.COLUMN_TOTAL_SIZE_BYTES))
                            val reason = cursor.getInt(cursor.getColumnIndexOrThrow(DownloadManager.COLUMN_REASON))

                            val statusStr = when (status) {
                                DownloadManager.STATUS_PENDING -> "pending"
                                DownloadManager.STATUS_RUNNING -> "running"
                                DownloadManager.STATUS_PAUSED -> "paused"
                                DownloadManager.STATUS_SUCCESSFUL -> "successful"
                                DownloadManager.STATUS_FAILED -> "failed"
                                else -> "unknown"
                            }

                            result.success(mapOf(
                                "status" to statusStr,
                                "bytesDownloaded" to bytesDownloaded,
                                "bytesTotal" to bytesTotal,
                                "reason" to reason
                            ))
                        } else {
                            result.success(mapOf("status" to "not_found"))
                        }
                    } catch (e: Exception) {
                        result.error("QUERY_ERROR", e.localizedMessage, null)
                    } finally {
                        cursor?.close()
                    }
                }
                "cancelDownload" -> {
                    val downloadId = call.argument<Number>("downloadId")?.toLong()
                    if (downloadId != null) {
                        val downloadManager = getSystemService(Context.DOWNLOAD_SERVICE) as DownloadManager
                        downloadManager.remove(downloadId)
                        result.success(true)
                    } else {
                        result.success(false)
                    }
                }
                "installApk" -> {
                    val filePath = call.argument<String>("filePath")
                    if (filePath != null) {
                        val success = installApk(filePath)
                        result.success(success)
                    } else {
                        result.error("INVALID_PATH", "File path cannot be null", null)
                    }
                }
                "deleteFile" -> {
                    val filePath = call.argument<String>("filePath")
                    if (filePath != null) {
                        try {
                            val file = File(filePath)
                            if (file.exists()) {
                                file.delete()
                            }
                            result.success(true)
                        } catch (e: Exception) {
                            result.success(false)
                        }
                    } else {
                        result.success(false)
                    }
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }

    private fun installApk(filePath: String): Boolean {
        return try {
            val file = File(filePath)
            if (!file.exists()) return false

            val context = applicationContext
            val uri: Uri = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
                FileProvider.getUriForFile(
                    context,
                    "${context.packageName}.fileprovider",
                    file
                )
            } else {
                Uri.fromFile(file)
            }

            val intent = Intent(Intent.ACTION_VIEW).apply {
                setDataAndType(uri, "application/vnd.android.package-archive")
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_GRANT_READ_URI_PERMISSION
            }

            startActivity(intent)
            true
        } catch (e: Exception) {
            e.printStackTrace()
            false
        }
    }
}

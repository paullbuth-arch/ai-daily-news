package com.ipadboss.ipad_boss_app

import android.content.ContentUris
import android.content.ContentValues
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.os.Environment
import android.provider.MediaStore
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileOutputStream

class MainActivity : FlutterActivity() {
    private val CHANNEL = "ipad_boss_app/gallery"

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        requestHighRefreshRate()
    }

    override fun onResume() {
        super.onResume()
        requestHighRefreshRate()
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "installApk" -> {
                        val path = call.argument<String>("path") ?: ""
                        if (path.isEmpty()) {
                            result.error("empty", "APK路径为空", null)
                            return@setMethodCallHandler
                        }
                        try {
                            result.success(installApk(path))
                        } catch (e: Exception) {
                            result.error("install_failed", e.message, null)
                        }
                    }
                    "saveImagesToGallery" -> {
                        val paths = call.argument<List<String>>("paths") ?: emptyList()
                        val albumName = call.argument<String>("albumName") ?: "货脉"
                        if (paths.isEmpty()) {
                            result.error("empty", "文件路径列表为空", null)
                            return@setMethodCallHandler
                        }
                        try {
                            val saved = ArrayList<String>()
                            for (p in paths) {
                                val src = File(p)
                                if (!src.exists()) continue
                                val dest = saveImageToGallery(this, src, albumName)
                                if (dest != null) saved.add(dest)
                            }
                            if (saved.isEmpty()) {
                                result.error("save_failed", "未能保存任何图片", null)
                            } else {
                                result.success(mapOf("success" to true, "saved" to saved.size))
                            }
                        } catch (e: Exception) {
                            result.error("exception", e.message, null)
                        }
                    }
                    "saveVideosToGallery" -> {
                        val paths = call.argument<List<String>>("paths") ?: emptyList()
                        val albumName = call.argument<String>("albumName") ?: "货脉"
                        if (paths.isEmpty()) {
                            result.error("empty", "文件路径列表为空", null)
                            return@setMethodCallHandler
                        }
                        try {
                            val saved = ArrayList<String>()
                            for (p in paths) {
                                val src = File(p)
                                if (!src.exists()) continue
                                val dest = saveVideoToGallery(this, src, albumName)
                                if (dest != null) saved.add(dest)
                            }
                            if (saved.isEmpty()) {
                                result.error("save_failed", "未能保存任何视频", null)
                            } else {
                                result.success(mapOf("success" to true, "saved" to saved.size))
                            }
                        } catch (e: Exception) {
                            result.error("exception", e.message, null)
                        }
                    }
                    "canSaveToGallery" -> {
                        result.success(true)
                    }
                    "openUrl" -> {
                        val url = call.argument<String>("url") ?: ""
                        if (url.isEmpty()) {
                            result.error("empty", "URL为空", null)
                            return@setMethodCallHandler
                        }
                        try {
                            val intent = Intent(Intent.ACTION_VIEW, Uri.parse(url)).apply {
                                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                            }
                            context.startActivity(intent)
                            result.success(mapOf("success" to true))
                        } catch (e: Exception) {
                            result.success(mapOf("success" to false, "reason" to (e.message ?: "open_failed")))
                        }
                    }
                    "openXianyu" -> {
                        // 优先用包名 Intent 拉起闲鱼，失败则尝试 scheme，再失败提示
                        try {
                            val pm = context.packageManager
                            val pkg = "com.taobao.idlefish"
                            val intent = pm.getLaunchIntentForPackage(pkg)
                            if (intent != null) {
                                intent.addFlags(android.content.Intent.FLAG_ACTIVITY_NEW_TASK)
                                context.startActivity(intent)
                                result.success(mapOf("success" to true))
                            } else {
                                // 兜底：尝试 scheme
                                val scheme = android.content.Intent(android.content.Intent.ACTION_VIEW, android.net.Uri.parse("fleamarket://"))
                                scheme.addFlags(android.content.Intent.FLAG_ACTIVITY_NEW_TASK)
                                if (scheme.resolveActivity(pm) != null) {
                                    context.startActivity(scheme)
                                    result.success(mapOf("success" to true))
                                } else {
                                    // 闲鱼未安装，返回标记让 Flutter 引导去应用商店
                                    result.success(mapOf("success" to false, "reason" to "not_installed"))
                                }
                            }
                        } catch (e: Exception) {
                            result.error("exception", e.message, null)
                        }
                    }
                    "exportBackupToDocuments" -> {
                        val srcPath = call.argument<String>("srcPath") ?: ""
                        val fileName = call.argument<String>("fileName") ?: ""
                        if (srcPath.isEmpty() || fileName.isEmpty()) {
                            result.error("empty", "源路径或文件名为空", null)
                            return@setMethodCallHandler
                        }
                        val src = File(srcPath)
                        if (!src.exists()) {
                            result.error("missing", "源文件不存在: $srcPath", null)
                            return@setMethodCallHandler
                        }
                        try {
                            val saved = exportBackup(this, src, fileName)
                            if (saved == null) {
                                result.error("save_failed", "写入公共目录失败", null)
                            } else {
                                result.success(mapOf("success" to true, "uri" to saved))
                            }
                        } catch (e: Exception) {
                            result.error("exception", e.message, null)
                        }
                    }
                    "listBackupDocuments" -> {
                        try {
                            result.success(listBackups(this))
                        } catch (e: Exception) {
                            result.error("exception", e.message, null)
                        }
                    }
                    "deleteBackupDocument" -> {
                        val target = call.argument<String>("uri") ?: ""
                        if (target.isEmpty()) {
                            result.error("empty", "uri 为空", null)
                            return@setMethodCallHandler
                        }
                        try {
                            result.success(deleteBackup(this, target))
                        } catch (e: Exception) {
                            result.error("exception", e.message, null)
                        }
                    }
                    "copyBackupToCache" -> {
                        val target = call.argument<String>("uri") ?: ""
                        val fileName = call.argument<String>("fileName") ?: "restore.zip"
                        if (target.isEmpty()) {
                            result.error("empty", "uri 为空", null)
                            return@setMethodCallHandler
                        }
                        try {
                            val path = copyBackupToCache(this, target, fileName)
                            if (path == null) {
                                result.error("copy_failed", "读取备份文件失败", null)
                            } else {
                                result.success(path)
                            }
                        } catch (e: Exception) {
                            result.error("exception", e.message, null)
                        }
                    }
                    else -> result.notImplemented()
                }
            }
    }

    @Suppress("DEPRECATION")
    private fun requestHighRefreshRate() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) return

        val modes = windowManager.defaultDisplay.supportedModes
        var bestRate = 0f
        var bestModeId = 0
        for (mode in modes) {
            if (mode.refreshRate > bestRate) {
                bestRate = mode.refreshRate
                bestModeId = mode.modeId
            }
        }
        if (bestRate <= 60f) return

        val attrs = window.attributes
        attrs.preferredRefreshRate = bestRate
        attrs.preferredDisplayModeId = bestModeId
        window.attributes = attrs
    }

    /// 把单张图片保存到系统相册 Pictures/<albumName> 目录
    private fun saveImageToGallery(context: Context, src: File, albumName: String): String? {
        val resolver = context.contentResolver
        val ext = imageExtension(src)
        val mimeType = imageMimeType(ext)
        val name = "ipadboss_${System.currentTimeMillis()}_${kotlin.math.abs(src.absolutePath.hashCode())}.$ext"
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            // Android 10+ : 走 MediaStore，无需存储权限
            val values = ContentValues().apply {
                put(MediaStore.Images.Media.DISPLAY_NAME, name)
                put(MediaStore.Images.Media.MIME_TYPE, mimeType)
                put(MediaStore.Images.Media.RELATIVE_PATH, "Pictures/$albumName")
                put(MediaStore.Images.Media.IS_PENDING, 1)
            }
            val collection = MediaStore.Images.Media.getContentUri(MediaStore.VOLUME_EXTERNAL_PRIMARY)
            val uri = resolver.insert(collection, values) ?: return null
            resolver.openOutputStream(uri)?.use { out ->
                src.inputStream().use { it.copyTo(out) }
            } ?: return null
            values.clear()
            values.put(MediaStore.Images.Media.IS_PENDING, 0)
            resolver.update(uri, values, null, null)
            uri.toString()
        } else {
            // Android 9 及以下：直接写文件到外部存储 Pictures 目录
            val dir = File(Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_PICTURES), albumName)
            if (!dir.exists()) dir.mkdirs()
            val dest = File(dir, name)
            FileOutputStream(dest).use { out ->
                src.inputStream().use { it.copyTo(out) }
            }
            // 通知媒体库扫描
            val intent = android.content.Intent(android.content.Intent.ACTION_MEDIA_SCANNER_SCAN_FILE)
            intent.data = android.net.Uri.fromFile(dest)
            context.sendBroadcast(intent)
            dest.absolutePath
        }
    }

    private fun imageExtension(src: File): String {
        val ext = src.extension.lowercase()
        return when (ext) {
            "jpg", "jpeg", "png", "webp", "gif" -> ext
            else -> "jpg"
        }
    }

    private fun imageMimeType(ext: String): String {
        return when (ext) {
            "png" -> "image/png"
            "webp" -> "image/webp"
            "gif" -> "image/gif"
            else -> "image/jpeg"
        }
    }

    private fun saveVideoToGallery(context: Context, src: File, albumName: String): String? {
        val resolver = context.contentResolver
        val ext = videoExtension(src)
        val mimeType = videoMimeType(ext)
        val name = "ipadboss_${System.currentTimeMillis()}_${kotlin.math.abs(src.absolutePath.hashCode())}.$ext"
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            val values = ContentValues().apply {
                put(MediaStore.Video.Media.DISPLAY_NAME, name)
                put(MediaStore.Video.Media.MIME_TYPE, mimeType)
                put(MediaStore.Video.Media.RELATIVE_PATH, "Movies/$albumName")
                put(MediaStore.Video.Media.IS_PENDING, 1)
            }
            val collection = MediaStore.Video.Media.getContentUri(MediaStore.VOLUME_EXTERNAL_PRIMARY)
            val uri = resolver.insert(collection, values) ?: return null
            resolver.openOutputStream(uri)?.use { out ->
                src.inputStream().use { it.copyTo(out) }
            } ?: return null
            values.clear()
            values.put(MediaStore.Video.Media.IS_PENDING, 0)
            resolver.update(uri, values, null, null)
            uri.toString()
        } else {
            val dir = File(Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_MOVIES), albumName)
            if (!dir.exists()) dir.mkdirs()
            val dest = File(dir, name)
            FileOutputStream(dest).use { out ->
                src.inputStream().use { it.copyTo(out) }
            }
            val intent = android.content.Intent(android.content.Intent.ACTION_MEDIA_SCANNER_SCAN_FILE)
            intent.data = android.net.Uri.fromFile(dest)
            context.sendBroadcast(intent)
            dest.absolutePath
        }
    }

    private fun videoExtension(src: File): String {
        val ext = src.extension.lowercase()
        return when (ext) {
            "mp4", "mov", "m4v", "webm" -> ext
            else -> "mp4"
        }
    }

    private fun videoMimeType(ext: String): String {
        return when (ext) {
            "mov" -> "video/quicktime"
            "m4v" -> "video/x-m4v"
            "webm" -> "video/webm"
            else -> "video/mp4"
        }
    }

    /// 安装 APK（应用内更新）
    private fun installApk(apkPath: String): Map<String, Any> {
        val file = File(apkPath)
        if (!file.exists()) throw Exception("APK 文件不存在: $apkPath")
        
        // Android 8+ 需要检查安装未知应用权限
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            if (!packageManager.canRequestPackageInstalls()) {
                // 自动打开权限设置页
                val intent = Intent(android.provider.Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES).apply {
                    data = android.net.Uri.parse("package:${packageName}")
                    flags = Intent.FLAG_ACTIVITY_NEW_TASK
                }
                startActivity(intent)
                return mapOf(
                    "success" to false,
                    "permissionRequired" to true,
                    "message" to "请在弹出的设置页中开启安装未知应用权限"
                )
            }
        }
        
        val uri: Uri = FileProvider.getUriForFile(this, "${packageName}.fileprovider", file)
        val intent = Intent(Intent.ACTION_INSTALL_PACKAGE).apply {
            data = uri
            flags = Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_ACTIVITY_NEW_TASK
            putExtra(Intent.EXTRA_NOT_UNKNOWN_SOURCE, true)
            putExtra(Intent.EXTRA_RETURN_RESULT, true)
        }
        startActivity(intent)
        return mapOf("success" to true)
    }

    // ══════ 自动备份：写入公共目录（卸载 App 不会被清除） ══════

    /// 备份的候选落点。Download 对任意类型文件最宽松，优先用；
    /// 个别 ROM 拒绝时再退回 Documents。两者都在公共目录下，卸载不会被清。
    private fun backupTargets(): List<Pair<Uri, String>> =
        listOf(
            MediaStore.Downloads.EXTERNAL_CONTENT_URI to
                "${Environment.DIRECTORY_DOWNLOADS}/$BACKUP_DIR_NAME",
            MediaStore.Files.getContentUri(MediaStore.VOLUME_EXTERNAL_PRIMARY) to
                "${Environment.DIRECTORY_DOCUMENTS}/$BACKUP_DIR_NAME",
        )

    /// 把 [src] 复制到公共目录。成功返回目标 uri（API 29+）或绝对路径。
    @Suppress("DEPRECATION")
    private fun exportBackup(context: Context, src: File, fileName: String): String? {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) {
            val dir =
                File(
                    Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_DOCUMENTS),
                    BACKUP_DIR_NAME,
                )
            if (!dir.exists() && !dir.mkdirs()) return null
            val dest = File(dir, fileName)
            FileOutputStream(dest).use { out -> src.inputStream().use { it.copyTo(out) } }
            return dest.absolutePath
        }

        val resolver = context.contentResolver
        for ((collection, relativePath) in backupTargets()) {
            val values =
                ContentValues().apply {
                    put(MediaStore.MediaColumns.DISPLAY_NAME, fileName)
                    put(MediaStore.MediaColumns.MIME_TYPE, "application/zip")
                    put(MediaStore.MediaColumns.RELATIVE_PATH, relativePath)
                    put(MediaStore.MediaColumns.IS_PENDING, 1)
                }
            val uri =
                try {
                    resolver.insert(collection, values)
                } catch (e: Exception) {
                    null
                } ?: continue

            try {
                val out =
                    resolver.openOutputStream(uri)
                        ?: throw Exception("openOutputStream 返回 null")
                out.use { sink -> src.inputStream().use { it.copyTo(sink) } }
            } catch (e: Exception) {
                // 写失败要回收占位记录，否则公共目录里会留下空文件
                try {
                    resolver.delete(uri, null, null)
                } catch (_: Exception) {}
                continue
            }

            values.clear()
            values.put(MediaStore.MediaColumns.IS_PENDING, 0)
            resolver.update(uri, values, null, null)
            return uri.toString()
        }
        return null
    }

    /// 列出公共目录里的备份，按修改时间倒序。
    @Suppress("DEPRECATION")
    private fun listBackups(context: Context): List<Map<String, Any>> {
        val out = ArrayList<Map<String, Any>>()

        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) {
            val dir =
                File(
                    Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_DOCUMENTS),
                    BACKUP_DIR_NAME,
                )
            dir.listFiles()?.forEach { f ->
                if (f.isFile && f.name.endsWith(BACKUP_SUFFIX)) {
                    out.add(
                        mapOf(
                            "name" to f.name,
                            "uri" to f.absolutePath,
                            "size" to f.length(),
                            "dateModified" to f.lastModified(),
                        ),
                    )
                }
            }
            return out.sortedByDescending { it["dateModified"] as Long }
        }

        val resolver = context.contentResolver
        val projection =
            arrayOf(
                MediaStore.MediaColumns._ID,
                MediaStore.MediaColumns.DISPLAY_NAME,
                MediaStore.MediaColumns.SIZE,
                MediaStore.MediaColumns.DATE_MODIFIED,
            )
        for ((collection, relativePath) in backupTargets()) {
            try {
                resolver
                    .query(
                        collection,
                        projection,
                        "${MediaStore.MediaColumns.RELATIVE_PATH} LIKE ?",
                        arrayOf("$relativePath%"),
                        "${MediaStore.MediaColumns.DATE_MODIFIED} DESC",
                    )
                    ?.use { cursor ->
                        while (cursor.moveToNext()) {
                            val name = cursor.getString(1) ?: continue
                            if (!name.endsWith(BACKUP_SUFFIX)) continue
                            val uri =
                                ContentUris.withAppendedId(collection, cursor.getLong(0))
                            out.add(
                                mapOf(
                                    "name" to name,
                                    "uri" to uri.toString(),
                                    "size" to cursor.getLong(2),
                                    "dateModified" to cursor.getLong(3) * 1000L,
                                ),
                            )
                        }
                    }
            } catch (_: Exception) {
                // 该落点不可用，跳过
            }
        }
        return out.sortedByDescending { it["dateModified"] as Long }
    }

    /// 删除一个备份。[target] 为 content uri 字符串或绝对路径。
    private fun deleteBackup(context: Context, target: String): Boolean =
        if (target.startsWith("content://")) {
            try {
                context.contentResolver.delete(Uri.parse(target), null, null) > 0
            } catch (e: Exception) {
                false
            }
        } else {
            File(target).delete()
        }

    /// 把公共目录里的备份复制回应用缓存，返回本地绝对路径。
    /// Dart 侧的 File 读不了 content:// uri，恢复前必须先落到本地。
    private fun copyBackupToCache(context: Context, target: String, fileName: String): String? {
        val dir = File(context.cacheDir, "restore")
        if (!dir.exists() && !dir.mkdirs()) return null
        val dest = File(dir, fileName)

        if (target.startsWith("content://")) {
            val input =
                try {
                    context.contentResolver.openInputStream(Uri.parse(target))
                } catch (e: Exception) {
                    null
                } ?: return null
            input.use { src -> FileOutputStream(dest).use { out -> src.copyTo(out) } }
        } else {
            val src = File(target)
            if (!src.exists()) return null
            src.inputStream().use { s -> FileOutputStream(dest).use { out -> s.copyTo(out) } }
        }
        return dest.absolutePath
    }

    private companion object {
        const val BACKUP_DIR_NAME = "货脉备份"
        const val BACKUP_SUFFIX = ".zip"
    }
}

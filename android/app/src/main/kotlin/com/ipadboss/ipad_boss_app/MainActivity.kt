package com.ipadboss.ipad_boss_app

import android.content.ContentValues
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
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
                            installApk(path)
                            result.success(mapOf("success" to true))
                        } catch (e: Exception) {
                            result.error("install_failed", e.message, null)
                        }
                    }
                    "saveImagesToGallery" -> {
                        val paths = call.argument<List<String>>("paths") ?: emptyList()
                        val albumName = call.argument<String>("albumName") ?: "机掌柜"
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
                    "canSaveToGallery" -> {
                        result.success(true)
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
                    else -> result.notImplemented()
                }
            }
    }

    /// 把单张图片保存到系统相册 Pictures/<albumName> 目录
    private fun saveImageToGallery(context: Context, src: File, albumName: String): String? {
        val resolver = context.contentResolver
        val ts = System.currentTimeMillis()
        val name = "ipadboss_$ts.jpg"
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            // Android 10+ : 走 MediaStore，无需存储权限
            val values = ContentValues().apply {
                put(MediaStore.Images.Media.DISPLAY_NAME, name)
                put(MediaStore.Images.Media.MIME_TYPE, "image/jpeg")
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

    /// 安装 APK（应用内更新）
    private fun installApk(apkPath: String) {
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
                throw Exception("请在弹出的设置页中开启安装未知应用权限")
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
    }
}

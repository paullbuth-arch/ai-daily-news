package com.example.voskasr.audio

import android.content.Context
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import org.vosk.Model
import org.vosk.Recognizer
import java.io.File
import java.io.IOException

class VoskRecognizer(private val context: Context) {

    private var model: Model? = null
    private var recognizer: Recognizer? = null
    private var ready = false

    suspend fun initModel(): Boolean = withContext(Dispatchers.IO) {
        try {
            val modelDir = copyModelFromAssetsIfNeeded()
            if (modelDir == null) {
                return@withContext false
            }
            model = Model(modelDir.absolutePath)
            recognizer = Recognizer(model, 16000.0f)
            ready = true
            true
        } catch (e: Exception) {
            e.printStackTrace()
            false
        }
    }

    fun feedPcm(pcmData: ByteArray): Pair<Boolean, String> {
        if (!ready || pcmData.isEmpty()) return Pair(false, "")

        val rec = recognizer ?: return Pair(false, "")
        return try {
            val final = rec.acceptWaveForm(pcmData, pcmData.size)
            if (final) {
                Pair(true, rec.result)
            } else {
                Pair(false, rec.partialResult)
            }
        } catch (e: Exception) {
            e.printStackTrace()
            Pair(false, "")
        }
    }

    fun getPartialResult(): String {
        if (!ready) return ""
        return try {
            recognizer?.partialResult ?: ""
        } catch (e: Exception) {
            ""
        }
    }

    fun destroy() {
        ready = false
        try {
            recognizer?.close()
        } catch (e: Exception) {
            e.printStackTrace()
        }
        try {
            model?.close()
        } catch (e: Exception) {
            e.printStackTrace()
        }
        recognizer = null
        model = null
    }

    private fun copyModelFromAssetsIfNeeded(): File? {
        val modelDir = File(context.filesDir, "model")
        val stamp = File(modelDir, ".copied")
        if (stamp.exists()) {
            return modelDir
        }

        val assetManager = context.assets
        val assets = try {
            assetManager.list("model") ?: emptyArray()
        } catch (e: IOException) {
            e.printStackTrace()
            return null
        }

        if (assets.isEmpty()) {
            return null
        }

        copyAssetDirectory("model", modelDir)
        stamp.createNewFile()
        return modelDir
    }

    private fun copyAssetDirectory(assetPath: String, destDir: File) {
        val assetManager = context.assets
        val list = assetManager.list(assetPath) ?: return

        if (!destDir.exists()) {
            destDir.mkdirs()
        }

        for (name in list) {
            val srcPath = if (assetPath.isEmpty()) name else "$assetPath/$name"
            val dstFile = File(destDir, name)
            val children = assetManager.list(srcPath)
            if (children.isNullOrEmpty()) {
                assetManager.open(srcPath).use { input ->
                    dstFile.outputStream().use { output ->
                        input.copyTo(output)
                    }
                }
            } else {
                copyAssetDirectory(srcPath, dstFile)
            }
        }
    }
}

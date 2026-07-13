package com.example.voskasr.audio

import android.content.Context
import android.util.Log
import java.io.File
import java.io.RandomAccessFile
import java.nio.ByteBuffer
import java.nio.ByteOrder
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import java.util.concurrent.atomic.AtomicBoolean
import java.util.concurrent.locks.ReentrantLock

class PcmWavRecorder(private val context: Context) {

    private val lock = ReentrantLock()
    private var wavFile: File? = null
    private var raf: RandomAccessFile? = null
    private var dataBytesWritten: Long = 0
    private var firstFrameLogged = false
    private val isRecording = AtomicBoolean(false)

    @Volatile var sampleRate = 16000

    fun start(): String? {
        if (isRecording.get()) stop()

        val baseDir = context.getExternalFilesDir(null) ?: context.filesDir
        val dir = File(baseDir, "VoskAsr/recordings")
        if (!dir.exists()) dir.mkdirs()

        val timestamp = SimpleDateFormat("yyyyMMdd_HHmmss", Locale.getDefault()).format(Date())
        val file = File(dir, "record_$timestamp.wav")

        lock.lock()
        return try {
            raf = RandomAccessFile(file, "rw").apply {
                setLength(0)
                write(ByteArray(WAV_HEADER_SIZE))
            }
            wavFile = file
            dataBytesWritten = 0
            firstFrameLogged = false
            isRecording.set(true)
            Log.i(TAG, "Recording started (${sampleRate}Hz): ${file.absolutePath}")
            file.absolutePath
        } catch (e: Exception) {
            Log.e(TAG, "Failed to start recording: ${e.message}")
            isRecording.set(false)
            null
        } finally {
            lock.unlock()
        }
    }

    fun feed(pcm: ByteArray) {
        if (!isRecording.get() || pcm.isEmpty()) return
        lock.lock()
        try {
            raf?.write(pcm)
            dataBytesWritten += pcm.size
            if (!firstFrameLogged) {
                firstFrameLogged = true
                Log.i(TAG, "First PCM frame written: ${pcm.size} bytes")
            }
        } catch (e: Exception) {
            Log.e(TAG, "Failed to write PCM: ${e.message}")
        } finally {
            lock.unlock()
        }
    }

    fun stop(): String? {
        if (!isRecording.get()) return null
        isRecording.set(false)

        lock.lock()
        try {
            val file = wavFile
            raf?.apply {
                seek(0)
                writeWavHeader(dataBytesWritten)
                close()
            }
            Log.i(TAG, "Recording stopped: ${dataBytesWritten} bytes → ${file?.absolutePath}")
            return file?.absolutePath
        } catch (e: Exception) {
            Log.e(TAG, "Failed to finalize WAV: ${e.message}")
            return null
        } finally {
            raf = null
            wavFile = null
            dataBytesWritten = 0
            lock.unlock()
        }
    }

    fun isRecording(): Boolean = isRecording.get()

    private fun RandomAccessFile.writeWavHeader(dataBytes: Long) {
        val byteRate = sampleRate * BLOCK_ALIGN
        val riffChunkSize = dataBytes + WAV_HEADER_SIZE - 8
        val header = ByteBuffer.allocate(WAV_HEADER_SIZE).apply {
            order(ByteOrder.LITTLE_ENDIAN)
            put("RIFF".toByteArray())
            putInt((riffChunkSize and 0xFFFFFFFFL).toInt())
            put("WAVE".toByteArray())
            put("fmt ".toByteArray())
            putInt(16)           // PCM
            putShort(1)          // format = 1 (PCM)
            putShort(CHANNELS.toShort())
            putInt(sampleRate)
            putInt(byteRate)
            putShort(BLOCK_ALIGN.toShort())
            putShort(BITS_PER_SAMPLE.toShort())
            put("data".toByteArray())
            putInt((dataBytes and 0xFFFFFFFFL).toInt())
        }
        write(header.array())
    }

    companion object {
        private const val TAG = "PcmWavRecorder"
        private const val CHANNELS = 1
        private const val BITS_PER_SAMPLE = 16
        private const val BLOCK_ALIGN = CHANNELS * BITS_PER_SAMPLE / 8 // 2
        private const val WAV_HEADER_SIZE = 44
    }
}

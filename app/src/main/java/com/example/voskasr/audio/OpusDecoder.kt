package com.example.voskasr.audio

import android.util.Log
import java.nio.ByteBuffer
import java.nio.ByteOrder

class OpusDecoder {

    private var handle: Long = 0L
    private var outputBuffer: ByteBuffer? = null
    private var initReported: Boolean = false
    private var count = 0
    private var nativeLoaded = false
    private var loadError: String? = null

    init {
        try {
            System.loadLibrary("opus_jni")
            nativeLoaded = true
        } catch (e: UnsatisfiedLinkError) {
            loadError = e.message
            Log.e(TAG, "Failed to load opus_jni: ${e.message}")
        }
    }

    @Synchronized
    fun init(): Boolean {
        if (handle != 0L && outputBuffer != null) {
            return true
        }
        if (!nativeLoaded) {
            Log.e(TAG, "opus_jni is not loaded: ${loadError.orEmpty()}")
            return false
        }
        return try {
            handle = nativeCreate(SAMPLE_RATE, CHANNELS)
            if (handle == 0L) {
                Log.e(TAG, "opus_decoder_create failed")
                return false
            }
            outputBuffer = ByteBuffer.allocateDirect(MAX_PCM_BYTES).apply {
                order(ByteOrder.nativeOrder())
            }
            count = 0
            initReported = false
            true
        } catch (e: UnsatisfiedLinkError) {
            loadError = e.message
            Log.e(TAG, "native opus init failed: ${e.message}")
            false
        }
    }

    fun decode(opusData: ByteArray, debugCb: ((String) -> Unit)? = null): ByteArray? {
        if (opusData.isEmpty()) {
            return null
        }

        if (handle == 0L || outputBuffer == null) {
            if (!init()) {
                val suffix = loadError?.let { ": $it" }.orEmpty()
                debugCb?.invoke("[opus] native decoder init failed$suffix")
                return null
            }
        }

        val pcmBuf = outputBuffer ?: return null
        pcmBuf.clear()

        val decodedSamples = nativeDecode(handle, opusData, pcmBuf)
        if (decodedSamples <= 0) {
            debugCb?.invoke("[opus] decode error=$decodedSamples")
            return null
        }

        val pcmBytes = decodedSamples * CHANNELS * BYTES_PER_SAMPLE
        val out = ByteArray(pcmBytes)
        pcmBuf.position(0)
        pcmBuf.limit(pcmBytes)
        pcmBuf.get(out)

        count++
        if (!initReported) {
            initReported = true
            debugCb?.invoke("[opus] native decoder initialised (libopus)")
        }
        if (count <= 5 || count % 200 == 0) {
            debugCb?.invoke("[opus] #$count in=${opusData.size}B pcm=${out.size}B samples=$decodedSamples")
        }

        return out
    }

    fun release() {
        if (handle != 0L) {
            nativeDestroy(handle)
            handle = 0L
        }
        outputBuffer = null
        count = 0
        initReported = false
    }

    private external fun nativeCreate(sampleRate: Int, channels: Int): Long
    private external fun nativeDecode(handle: Long, opusData: ByteArray, pcmBuffer: ByteBuffer): Int
    private external fun nativeDestroy(handle: Long)

    companion object {
        private const val TAG = "OpusDecoder"
        private const val SAMPLE_RATE = 16000
        private const val CHANNELS = 1
        private const val BYTES_PER_SAMPLE = 2
        private const val MAX_SAMPLES_PER_FRAME = 320
        private const val MAX_PCM_BYTES = MAX_SAMPLES_PER_FRAME * CHANNELS * BYTES_PER_SAMPLE
    }
}

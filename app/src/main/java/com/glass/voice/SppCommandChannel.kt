package com.glass.voice

import android.bluetooth.BluetoothDevice
import android.bluetooth.BluetoothSocket
import android.util.Log
import kotlinx.coroutines.*
import java.io.InputStream
import java.io.OutputStream
import java.util.UUID

/**
 * SPP channel to WQ7036A.
 * Receives commands from WQ (KEY_1 click → "VOICE_START") and sends results back.
 */
class SppCommandChannel(private val scope: CoroutineScope) {

    companion object {
        private const val TAG = "SppChannel"
        private val SPP_UUID = UUID.fromString("0000FF10-0000-1000-8000-00805F9B34FB")
        private const val CMD_VOICE_START: Byte = 0x01
        private const val CMD_VOICE_STOP: Byte = 0x02
    }

    @Volatile var onVoiceStart: (() -> Unit)? = null
    @Volatile var onVoiceStop: (() -> Unit)? = null

    private var socket: BluetoothSocket? = null
    private var input: InputStream? = null
    private var output: OutputStream? = null
    private var listenJob: Job? = null

    suspend fun connect(device: BluetoothDevice): Boolean = withContext(Dispatchers.IO) {
        try {
            @Suppress("MissingPermission")
            val s = device.createInsecureRfcommSocketToServiceRecord(SPP_UUID)
            s.connect()
            socket = s
            input = s.inputStream
            output = s.outputStream
            Log.i(TAG, "SPP connected to ${device.address}")
            startListening()
            true
        } catch (e: Exception) {
            Log.e(TAG, "SPP connect failed: ${e.message}")
            false
        }
    }

    private fun startListening() {
        val inp = input ?: return
        listenJob = scope.launch(Dispatchers.IO) {
            val buf = ByteArray(64)
            while (isActive) {
                try {
                    val len = inp.read(buf)
                    if (len > 0) handleCommand(buf[0])
                } catch (_: Exception) { break }
            }
        }
    }

    private fun handleCommand(cmd: Byte) {
        Log.i(TAG, "SPP cmd: 0x${cmd.toString(16)}")
        when (cmd) {
            CMD_VOICE_START -> onVoiceStart?.invoke()
            CMD_VOICE_STOP -> onVoiceStop?.invoke()
        }
    }

    fun sendResult(text: String) {
        try {
            val data = text.toByteArray(Charsets.UTF_8)
            output?.write(data)
            Log.i(TAG, "SPP sent result: $text (${data.size}B)")
        } catch (e: Exception) {
            Log.e(TAG, "SPP send failed: ${e.message}")
        }
    }

    fun disconnect() {
        listenJob?.cancel()
        try { input?.close() } catch (_: Exception) {}
        try { output?.close() } catch (_: Exception) {}
        try { socket?.close() } catch (_: Exception) {}
        socket = null; input = null; output = null
    }
}
